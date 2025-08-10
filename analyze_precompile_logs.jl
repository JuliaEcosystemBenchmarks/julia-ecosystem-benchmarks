using Logging
using Printf

struct DataRow
    package_name::String
    task_name::String
    date::String
    julia_version::String
    hostname::String
    hash::String
    precompile_time::Union{Float64, Nothing}
    loading_time::Union{Float64, Nothing}
    task_time::Union{Float64, Nothing}
end

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

function analyze_precompile_logs()
    println("Fetching jeb_logs branch...")
    run(`git fetch origin jeb_logs:jeb_logs`)
    
    println("Finding all .precompile files...")
    result = read(`git ls-tree -r --name-only jeb_logs`, String)
    all_files = split(strip(result), "\n")
    precompile_files = filter(f -> endswith(f, ".precompile"), all_files)
    
    println("Found $(length(precompile_files)) .precompile files")
    
    data = DataRow[]
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
        
        # Read both precompile and task files
        precompile_time = nothing
        loading_time = nothing
        task_time = nothing
        
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
        
        # Only add entry if we have valid data from both files
        if precompile_time !== nothing && loading_time !== nothing && task_time !== nothing
            push!(data, DataRow(
                package_name,
                task_name,
                parsed.date,
                parsed.julia_version,
                parsed.hostname,
                parsed.hash,
                precompile_time,
                loading_time,
                task_time
            ))
        else
            @warn "Skipping entry due to missing timing data from either precompile or task file" precompile_filepath=precompile_filepath task_filepath=task_filepath precompile_time=precompile_time loading_time=loading_time task_time=task_time
            skipped_count += 1
        end
    end
    
    println("\nData collected with $(length(data)) rows")
    println("Skipped $(skipped_count) entries due to issues")
    
    # Display sample data
    println("\nSample data (first 10 rows):")
    println("Package | Task | Date | Julia Ver | Hash | Precompile | Loading | Task Time")
    println("-" ^ 90)
    for (i, row) in enumerate(data[1:min(10, length(data))])
        precompile_str = row.precompile_time !== nothing ? @sprintf("%.3f", row.precompile_time) : "N/A"
        loading_str = row.loading_time !== nothing ? @sprintf("%.3f", row.loading_time) : "N/A"
        task_time_str = row.task_time !== nothing ? @sprintf("%.3f", row.task_time) : "N/A"
        println("$(row.package_name) | $(row.task_name) | $(row.date) | $(row.julia_version) | $(row.hash) | $(precompile_str) | $(loading_str) | $(task_time_str)")
    end
    
    # Summary by package
    println("\nSummary by package:")
    package_counts = Dict{String, Int}()
    package_valid_times = Dict{String, Int}()
    
    for row in data
        package_counts[row.package_name] = get(package_counts, row.package_name, 0) + 1
        if row.precompile_time !== nothing && row.loading_time !== nothing && row.task_time !== nothing
            package_valid_times[row.package_name] = get(package_valid_times, row.package_name, 0) + 1
        end
    end
    
    sorted_packages = sort(collect(package_counts), by=x->x[2], rev=true)
    println("Package | Total Files | Valid Complete Entries")
    println("-" ^ 50)
    for (pkg, count) in sorted_packages[1:min(10, length(sorted_packages))]
        valid = get(package_valid_times, pkg, 0)
        println("$pkg | $count | $valid")
    end
    
    # Summary by Julia version
    println("\nSummary by Julia version:")
    version_counts = Dict{String, Int}()
    version_valid_times = Dict{String, Int}()
    
    for row in data
        version_counts[row.julia_version] = get(version_counts, row.julia_version, 0) + 1
        if row.precompile_time !== nothing && row.loading_time !== nothing && row.task_time !== nothing
            version_valid_times[row.julia_version] = get(version_valid_times, row.julia_version, 0) + 1
        end
    end
    
    sorted_versions = sort(collect(version_counts), by=x->x[1])
    println("Julia Version | Total Files | Valid Complete Entries")
    println("-" ^ 55)
    for (ver, count) in sorted_versions
        valid = get(version_valid_times, ver, 0)
        println("$ver | $count | $valid")
    end
    
    return data
end

# Run the analysis
data = analyze_precompile_logs()