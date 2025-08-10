using Logging
using Printf
using DataFrames
using CSV

# We'll use DataFrames directly instead of a custom struct

function parse_filename(filename)
    # Remove file extension first
    base_name = replace(filename, r"\.(precompile|task)$" => "")
    parts = split(base_name, "_")
    
    if length(parts) >= 4
        hash = parts[1]
        date_str = parts[2]  # Already in YYYY-MM-DD format
        julia_version = parts[3]
        hostname = parts[4]
        return (hash=hash, date=date_str, julia_version=julia_version, hostname=hostname)
    else
        @warn "Incorrectly formatted filename: expected at least 4 underscore-separated parts, got $(length(parts))" filename=filename parts=parts
        return nothing
    end
end

function extract_package_and_task_from_path(filepath)
    path_parts = split(filepath, "/")
    julia_ttfx_idx = findfirst(x -> x == "Julia-TTFX-Snippets", path_parts)
    if julia_ttfx_idx !== nothing && julia_ttfx_idx + 3 <= length(path_parts)
        package_name = path_parts[julia_ttfx_idx + 2]
        task_name = path_parts[julia_ttfx_idx + 3]
        return (package_name, task_name)
    end
    @warn "Unable to extract package and task names from path: Julia-TTFX-Snippets not found or insufficient path depth" filepath=filepath path_parts=path_parts
    return ("Unknown", "Unknown")
end

function parse_precompile_content(filepath, content)
    lines = split(content, "\n")
    
    for line in lines
        if occursin("seconds", line) && occursin("compilation time", line)
            m = match(r"([0-9.]+)\s+seconds", line)
            if m !== nothing
                return parse(Float64, m.captures[1])
            else
                @warn "Found compilation time line but could not parse timing value" filepath=filepath line=line
                return nothing
            end
        end
    end
    
    @warn "No precompile timing information found in file" filepath=filepath
    return nothing
end

function parse_task_content(filepath, content)
    content = strip(content)
    
    # Handle empty files
    if isempty(content)
        @warn "Task file is empty" filepath=filepath
        return (nothing, nothing)
    end
    
    # Look for the timing data at the end of the file
    # Expected format: "loading_time, task_time, total_time seconds"
    lines = split(content, "\n")
    
    # Look for the last line that contains "seconds"
    timing_line = nothing
    for line in reverse(lines)
        line = strip(line)
        if occursin(" seconds", line)
            timing_line = line
            break
        end
    end
    
    if timing_line === nothing
        @warn "Task file does not contain expected 'seconds' suffix in any line" filepath=filepath content_preview=content[1:min(200, length(content))]
        return (nothing, nothing)
    end
    
    # Parse the timing line
    time_part = replace(timing_line, " seconds" => "")
    times = split(time_part, ",")
    
    if length(times) >= 2
        try
            loading_time = parse(Float64, strip(times[1]))
            task_time = parse(Float64, strip(times[2]))
            return (loading_time, task_time)
        catch e
            @warn "Error parsing task timing values from timing line" filepath=filepath timing_line=timing_line exception=e
            return (nothing, nothing)
        end
    else
        @warn "Timing line does not contain expected format: expected at least 2 comma-separated values" filepath=filepath timing_line=timing_line times_found=length(times)
        return (nothing, nothing)
    end
end

function get_corresponding_task_file(precompile_filepath)
    return replace(precompile_filepath, r"\.precompile$" => ".task")
end

function get_corresponding_log_files(precompile_filepath)
    precompile_log = replace(precompile_filepath, r"\.precompile$" => ".precompile.log")
    task_log = replace(precompile_filepath, r"\.precompile$" => ".task.log")
    return (precompile_log, task_log)
end

function parse_time_command_output(filepath, content)
    content = strip(content)
    
    # Handle empty files
    if isempty(content)
        @warn "Log file is empty" filepath=filepath
        return (nothing, nothing)
    end
    
    # Use grep-like functionality to find lines with the metrics we want
    cpu_percent = nothing
    max_rss = nothing
    
    lines = split(content, "\n")
    
    for line in lines
        line = strip(line)
        
        # Look for "Percent of CPU this job got"
        if occursin("Percent of CPU this job got", line)
            # Expected format: "Percent of CPU this job got: 99%"
            m = match(r"Percent of CPU this job got:\s*([0-9.]+)%", line)
            if m !== nothing
                try
                    cpu_percent = parse(Float64, m.captures[1])
                catch e
                    @warn "Error parsing CPU percentage" filepath=filepath line=line exception=e
                end
            else
                @warn "Found CPU percentage line but could not parse value" filepath=filepath line=line
            end
        end
        
        # Look for "Maximum resident set size"
        if occursin("Maximum resident set size", line)
            # Expected format: "Maximum resident set size (kbytes): 1234567"
            m = match(r"Maximum resident set size \(kbytes\):\s*([0-9]+)", line)
            if m !== nothing
                try
                    max_rss = parse(Int64, m.captures[1])
                catch e
                    @warn "Error parsing maximum resident set size" filepath=filepath line=line exception=e
                end
            else
                @warn "Found maximum resident set size line but could not parse value" filepath=filepath line=line
            end
        end
    end
    
    # Generate warnings if metrics were not found
    if cpu_percent === nothing
        @warn "No CPU percentage information found in log file" filepath=filepath
    end
    if max_rss === nothing
        @warn "No maximum resident set size information found in log file" filepath=filepath
    end
    
    return (cpu_percent, max_rss)
end

function analyze_precompile_logs()
    println("Fetching jeb_logs branch...")
    run(`git fetch origin jeb_logs:jeb_logs`)
    
    println("Finding all .precompile files...")
    result = read(`git ls-tree -r --name-only jeb_logs`, String)
    all_files = split(strip(result), "\n")
    precompile_files = filter(f -> endswith(f, ".precompile"), all_files)
    
    println("Found $(length(precompile_files)) .precompile files")
    
    # Collect data in vectors for DataFrame construction
    package_names = String[]
    task_names = String[]
    dates = String[]
    julia_versions = String[]
    hostnames = String[]
    hashes = String[]
    precompile_times = Union{Float64, Missing}[]
    loading_times = Union{Float64, Missing}[]
    task_times = Union{Float64, Missing}[]
    precompile_cpus = Union{Float64, Missing}[]
    task_cpus = Union{Float64, Missing}[]
    precompile_residents = Union{Int64, Missing}[]
    task_residents = Union{Int64, Missing}[]
    skipped_count = 0
    
    for (i, precompile_filepath) in enumerate(precompile_files)
        if i % 100 == 0
            println("Processing file $i/$(length(precompile_files))")
        end
        
        filename = basename(precompile_filepath)
        parsed = parse_filename(filename)
        
        if parsed === nothing
            @warn "Skipping file due to filename parsing failure" filepath=precompile_filepath filename=filename
            skipped_count += 1
            continue
        end
        
        package_name, task_name = extract_package_and_task_from_path(precompile_filepath)
        task_filepath = get_corresponding_task_file(precompile_filepath)
        precompile_log_filepath, task_log_filepath = get_corresponding_log_files(precompile_filepath)
        
        # Read precompile, task, and log files
        precompile_time = nothing
        loading_time = nothing
        task_time = nothing
        precompile_cpu = nothing
        precompile_resident = nothing
        task_cpu = nothing
        task_resident = nothing
        
        # Process precompile file
        try
            precompile_content = read(`git show jeb_logs:$precompile_filepath`, String)
            precompile_time = parse_precompile_content(precompile_filepath, precompile_content)
        catch e
            @warn "Error reading or processing precompile file content" filepath=precompile_filepath exception=e
            skipped_count += 1
            continue
        end
        
        # Process corresponding task file
        try
            task_content = read(`git show jeb_logs:$task_filepath`, String)
            loading_time, task_time = parse_task_content(task_filepath, task_content)
        catch e
            @warn "Error reading or processing task file content" filepath=task_filepath exception=e
            skipped_count += 1
            continue
        end
        
        # Process precompile log file
        try
            precompile_log_content = read(`git show jeb_logs:$precompile_log_filepath`, String)
            precompile_cpu, precompile_resident = parse_time_command_output(precompile_log_filepath, precompile_log_content)
        catch e
            @warn "Error reading or processing precompile log file content" filepath=precompile_log_filepath exception=e
            # Don't skip the entry for log file issues, just set values to nothing
        end
        
        # Process task log file
        try
            task_log_content = read(`git show jeb_logs:$task_log_filepath`, String)
            task_cpu, task_resident = parse_time_command_output(task_log_filepath, task_log_content)
        catch e
            @warn "Error reading or processing task log file content" filepath=task_log_filepath exception=e
            # Don't skip the entry for log file issues, just set values to nothing
        end
        
        # Only add entry if we have valid data from both main files
        # Log files are optional - missing log data won't skip the entry
        if precompile_time !== nothing && loading_time !== nothing && task_time !== nothing
            push!(package_names, package_name)
            push!(task_names, task_name)
            push!(dates, parsed.date)
            push!(julia_versions, parsed.julia_version)
            push!(hostnames, parsed.hostname)
            push!(hashes, parsed.hash)
            push!(precompile_times, precompile_time)
            push!(loading_times, loading_time)
            push!(task_times, task_time)
            push!(precompile_cpus, precompile_cpu)
            push!(task_cpus, task_cpu)
            push!(precompile_residents, precompile_resident)
            push!(task_residents, task_resident)
        else
            @warn "Skipping entry due to missing timing data from either precompile or task file" precompile_filepath=precompile_filepath task_filepath=task_filepath precompile_time=precompile_time loading_time=loading_time task_time=task_time
            skipped_count += 1
        end
    end
    
    # Create DataFrame from collected data
    data = DataFrame(
        package_name = package_names,
        task_name = task_names,
        date = dates,
        julia_version = julia_versions,
        hostname = hostnames,
        hash = hashes,
        precompile_time = precompile_times,
        loading_time = loading_times,
        task_time = task_times,
        precompile_cpu = precompile_cpus,
        task_cpu = task_cpus,
        precompile_resident = precompile_residents,
        task_resident = task_residents
    )
    
    println("\nData collected with $(nrow(data)) rows")
    println("Skipped $(skipped_count) entries due to issues")
    
    # Display sample data using DataFrame's built-in display
    println("\nSample data (first 10 rows):")
    println(first(data, 10))
    
    # Summary by package using DataFrames groupby
    println("\nSummary by package:")
    package_summary = combine(groupby(data, :package_name), nrow => :total_files)
    package_summary = sort(package_summary, :total_files, rev=true)
    println(first(package_summary, 10))
    
    # Summary by Julia version using DataFrames groupby  
    println("\nSummary by Julia version:")
    version_summary = combine(groupby(data, :julia_version), nrow => :total_files)
    version_summary = sort(version_summary, :julia_version)
    println(version_summary)
    
    return data
end

# Run the analysis and save to CSV
data = analyze_precompile_logs()

# Save the data to CSV file
output_file = "ttfx_snippets_data.csv"
println("\nSaving data to $output_file...")
CSV.write(output_file, data)
println("Data saved successfully to $output_file")