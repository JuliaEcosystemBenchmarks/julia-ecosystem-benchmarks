using Logging

struct DataRow
    package_name::String
    date::String
    julia_version::String
    hostname::String
    hash::String
    precompile_time::Union{Float64, Nothing}
    filepath::String
end

function parse_filename(filename)
    # Remove .precompile extension first
    base_name = replace(filename, r"\.precompile$" => "")
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

function extract_package_name_from_path(filepath)
    path_parts = split(filepath, "/")
    julia_ttfx_idx = findfirst(x -> x == "Julia-TTFX-Snippets", path_parts)
    if julia_ttfx_idx !== nothing && julia_ttfx_idx + 2 <= length(path_parts)
        return path_parts[julia_ttfx_idx + 2]
    end
    @warn "Unable to extract package name from path: Julia-TTFX-Snippets not found or insufficient path depth" filepath=filepath path_parts=path_parts
    return "Unknown"
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
    
    for (i, filepath) in enumerate(precompile_files)
        if i % 100 == 0
            println("Processing file $i/$(length(precompile_files))")
        end
        
        filename = basename(filepath)
        parsed = parse_filename(filename)
        
        if parsed === nothing
            @warn "Skipping file due to filename parsing failure" filepath=filepath filename=filename
            continue
        end
        
        package_name = extract_package_name_from_path(filepath)
        
        # Read the file content from git
        try
            content = read(`git show jeb_logs:$filepath`, String)
            lines = split(content, "\n")
            precompile_time = nothing
            
            for line in lines
                if occursin("seconds", line) && occursin("compilation time", line)
                    m = match(r"([0-9.]+)\s+seconds", line)
                    if m !== nothing
                        precompile_time = parse(Float64, m.captures[1])
                        break
                    else
                        @warn "Found compilation time line but could not parse timing value" filepath=filepath line=line
                    end
                end
            end
            
            if precompile_time === nothing
                @warn "No precompile timing information found in file" filepath=filepath
            end
            
            push!(data, DataRow(
                package_name,
                parsed.date,
                parsed.julia_version,
                parsed.hostname,
                parsed.hash,
                precompile_time,
                filepath
            ))
        catch e
            @warn "Error reading or processing file content" filepath=filepath exception=e
            continue
        end
    end
    
    println("\nData collected with $(length(data)) rows")
    
    # Display sample data
    println("\nSample data (first 10 rows):")
    println("Package Name | Date | Julia Version | Hostname | Precompile Time | File Path")
    println("-" ^ 90)
    for (i, row) in enumerate(data[1:min(10, length(data))])
        time_str = row.precompile_time === nothing ? "N/A" : string(row.precompile_time)
        println("$(row.package_name) | $(row.date) | $(row.julia_version) | $(row.hostname) | $(time_str) | $(basename(row.filepath))")
    end
    
    # Summary by package
    println("\nSummary by package:")
    package_counts = Dict{String, Int}()
    package_valid_times = Dict{String, Int}()
    
    for row in data
        package_counts[row.package_name] = get(package_counts, row.package_name, 0) + 1
        if row.precompile_time !== nothing
            package_valid_times[row.package_name] = get(package_valid_times, row.package_name, 0) + 1
        end
    end
    
    sorted_packages = sort(collect(package_counts), by=x->x[2], rev=true)
    println("Package | Total Files | Valid Times")
    println("-" ^ 40)
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
        if row.precompile_time !== nothing
            version_valid_times[row.julia_version] = get(version_valid_times, row.julia_version, 0) + 1
        end
    end
    
    sorted_versions = sort(collect(version_counts), by=x->x[1])
    println("Julia Version | Total Files | Valid Times")
    println("-" ^ 45)
    for (ver, count) in sorted_versions
        valid = get(version_valid_times, ver, 0)
        println("$ver | $count | $valid")
    end
    
    return data
end

# Run the analysis
data = analyze_precompile_logs()