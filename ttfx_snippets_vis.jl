using CSV
using DataFrames
using AlgebraOfGraphics
using CairoMakie
using Dates
using Statistics

function load_ttfx_data()
    """Load TTFX snippets data from CSV file."""
    println("Loading TTFX data from CSV...")
    data = CSV.read("ttfx_snippets_data.csv", DataFrame)
    
    # Convert date strings to Date objects for proper sorting
    data.date = Date.(data.date)
    
    # Convert julia_version strings to VersionNumber for proper semantic sorting
    data.julia_version_parsed = VersionNumber.(data.julia_version)
    
    println("Loaded $(nrow(data)) rows of data")
    return data
end

function create_package_task_plots(data)
    """Create plots for each package/task combination."""
    println("Creating plots for each package/task combination...")
    
    # Get unique package/task combinations
    package_task_combinations = unique(data, [:package_name, :task_name])
    println("Found $(nrow(package_task_combinations)) unique package/task combinations")
    
    # Create plots directory if it doesn't exist
    mkpath("plots/Julia-TTFX-Snippets")
    
    for row in eachrow(package_task_combinations)
        package = row.package_name
        task = row.task_name
        
        # Filter data for this specific package/task combination
        subset_data = filter(r -> r.package_name == package && r.task_name == task, data)
        
        if nrow(subset_data) == 0
            @warn "No data found for package: $package, task: $task"
            continue
        end
        
        println("Creating plot for $package / $task ($(nrow(subset_data)) data points)")
        
        try
            create_subplot_figure(subset_data, package, task)
        catch e
            @warn "Error creating plot for $package / $task: $e"
        end
    end
end

function create_subplot_figure(data, package_name, task_name)
    """Create a multi-subplot figure for a package/task combination."""
    
    # Sort data by date for proper line connections
    sort!(data, :date)
    
    # Create figure with subplots arranged vertically
    fig = Figure(size = (1200, 7*800))
    
    # Define the metrics to plot
    time_metrics = [
        (:precompile_time, "Precompile Time (s)", "Time (seconds)"),
        (:loading_time, "Loading Time (s)", "Time (seconds)"), 
        (:task_time, "Task Time (s)", "Time (seconds)")
    ]
    
    cpu_metrics = [
        (:precompile_cpu, "Precompile CPU Usage", "CPU (%)"),
        (:task_cpu, "Task CPU Usage", "CPU (%)")
    ]
    
    memory_metrics = [
        (:precompile_resident, "Precompile Memory Usage", "Memory (KB)"),
        (:task_resident, "Task Memory Usage", "Memory (KB)")
    ]
    
    all_metrics = [time_metrics; cpu_metrics; memory_metrics]
    
    # Create subplots
    for (i, (metric, title, ylabel)) in enumerate(all_metrics)
        ax = Axis(fig[i, 1], 
                  title = title,
                  xlabel = i == length(all_metrics) ? "Date" : "",
                  ylabel = ylabel)
        
        # Filter out missing values for this metric
        plot_data = filter(r -> !ismissing(r[metric]) && !isnothing(r[metric]), data)
        
        if nrow(plot_data) == 0
            # Show empty plot with message
            text!(ax, 0.5, 0.5, text = "No data available", 
                  align = (:center, :center), space = :relative)
            continue
        end
        
        # Group by Julia version and create separate lines
        # Sort by parsed version numbers for proper semantic ordering
        unique_versions = unique(plot_data, [:julia_version, :julia_version_parsed])
        sort!(unique_versions, :julia_version_parsed)
        julia_versions = unique_versions.julia_version
        colors = Makie.wong_colors()[1:min(length(julia_versions), 7)]
        
        for (j, version) in enumerate(julia_versions)
            version_data = filter(r -> r.julia_version == version, plot_data)
            
            if nrow(version_data) > 0
                # Sort by date for proper line connection
                sort!(version_data, :date)
                
                lines!(ax, version_data.date, version_data[!, metric], 
                       color = colors[((j-1) % length(colors)) + 1],
                       linewidth = 2,
                       label = "Julia $version")
                
                scatter!(ax, version_data.date, version_data[!, metric],
                        color = colors[((j-1) % length(colors)) + 1],
                        markersize = 6)
            end
        end
        
        # Add legend only to the first subplot
        if i == 1 && length(julia_versions) > 1
            axislegend(ax, position = :lt)
        end
        
        # Format x-axis for dates
        if i == length(all_metrics)
            ax.xticklabelrotation = π/4
        else
            hidexdecorations!(ax, ticks = false, ticklabels = true)
        end
    end
    
    # Add overall title
    Label(fig[0, 1], "$package_name / $task_name", fontsize = 20, font = :bold, tellwidth = false)
    
    # Save the plot
    safe_package = replace(package_name, r"[^a-zA-Z0-9]" => "_")
    safe_task = replace(task_name, r"[^a-zA-Z0-9]" => "_")
    filename = "plots/Julia-TTFX-Snippets/$(safe_package)_$(safe_task).png"
    
    save(filename, fig)
    println("  Saved plot: $filename")
end

function create_summary_plot(data)
    """Create a summary plot showing geometric means of normalized data across all project/task combinations."""
    println("Creating SUMMARY plot...")
    
    # Define the metrics to plot
    time_metrics = [
        (:precompile_time, "Precompile Time (Normalized)", "Relative Performance"),
        (:loading_time, "Loading Time (Normalized)", "Relative Performance"), 
        (:task_time, "Task Time (Normalized)", "Relative Performance")
    ]
    
    cpu_metrics = [
        (:precompile_cpu, "Precompile CPU Usage (Normalized)", "Relative Performance"),
        (:task_cpu, "Task CPU Usage (Normalized)", "Relative Performance")
    ]
    
    memory_metrics = [
        (:precompile_resident, "Precompile Memory Usage (Normalized)", "Relative Performance"),
        (:task_resident, "Task Memory Usage (Normalized)", "Relative Performance")
    ]
    
    all_metrics = [time_metrics; cpu_metrics; memory_metrics]
    
    # Normalize data by first entry for each project/task combination
    normalized_data = normalize_by_first_entry(data, all_metrics)
    
    if nrow(normalized_data) == 0
        @warn "No normalized data available for summary plot"
        return
    end
    
    # Create figure with subplots arranged vertically
    fig = Figure(size = (1200, 7*300))
    
    # Create subplots for each metric
    for (i, (metric, title, ylabel)) in enumerate(all_metrics)
        ax = Axis(fig[i, 1], 
                  title = title,
                  xlabel = i == length(all_metrics) ? "Date" : "",
                  ylabel = ylabel)
        
        # Filter out missing values for this metric
        plot_data = filter(r -> !ismissing(r[metric]) && !isnothing(r[metric]) && r[metric] > 0, normalized_data)
        
        if nrow(plot_data) == 0
            # Show empty plot with message
            text!(ax, 0.5, 0.5, text = "No data available", 
                  align = (:center, :center), space = :relative)
            continue
        end
        
        # Group by Julia version and date, then compute geometric means
        summary_data = compute_geometric_means(plot_data, metric)
        
        if nrow(summary_data) == 0
            text!(ax, 0.5, 0.5, text = "No summary data available", 
                  align = (:center, :center), space = :relative)
            continue
        end
        
        # Sort by parsed version numbers for proper semantic ordering
        unique_versions = unique(summary_data, [:julia_version, :julia_version_parsed])
        sort!(unique_versions, :julia_version_parsed)
        julia_versions = unique_versions.julia_version
        colors = Makie.wong_colors()[1:min(length(julia_versions), 7)]
        
        for (j, version) in enumerate(julia_versions)
            version_data = filter(r -> r.julia_version == version, summary_data)
            
            if nrow(version_data) > 0
                # Sort by date for proper line connection
                sort!(version_data, :date)
                
                lines!(ax, version_data.date, version_data[!, metric], 
                       color = colors[((j-1) % length(colors)) + 1],
                       linewidth = 2,
                       label = "Julia $version")
                
                scatter!(ax, version_data.date, version_data[!, metric],
                        color = colors[((j-1) % length(colors)) + 1],
                        markersize = 6)
            end
        end
        
        # Add legend only to the first subplot
        if i == 1 && length(julia_versions) > 1
            axislegend(ax, position = :lt)
        end
        
        # Add horizontal line at y=1 (baseline)
        hlines!(ax, [1.0], color = :gray, linestyle = :dash, alpha = 0.5)
        
        # Format x-axis for dates
        if i == length(all_metrics)
            ax.xticklabelrotation = π/4
        else
            hidexdecorations!(ax, ticks = false, ticklabels = true)
        end
    end
    
    # Add overall title
    Label(fig[0, 1], "SUMMARY - Geometric Mean of All Normalized Project/Task Combinations", 
          fontsize = 20, font = :bold, tellwidth = false)
    
    # Save the plot
    filename = "plots/Julia-TTFX-Snippets/SUMMARY.png"
    save(filename, fig)
    println("  Saved summary plot: $filename")
end

function normalize_by_first_entry(data, metrics)
    """Normalize each project/task combination by dividing by its first entry."""
    println("  Normalizing data by first entry for each project/task...")
    
    normalized_rows = DataFrame[]
    
    # Get unique package/task combinations
    combinations = unique(data, [:package_name, :task_name])
    
    for row in eachrow(combinations)
        package = row.package_name
        task = row.task_name
        
        # Get all data for this combination, sorted by date
        combo_data = filter(r -> r.package_name == package && r.task_name == task, data)
        sort!(combo_data, :date)
        
        if nrow(combo_data) == 0
            continue
        end
        
        # Find the first valid entry for each metric
        first_values = Dict()
        for (metric_col, _, _) in metrics
            first_valid_idx = findfirst(r -> !ismissing(r[metric_col]) && !isnothing(r[metric_col]) && r[metric_col] > 0, eachrow(combo_data))
            if first_valid_idx !== nothing
                first_values[metric_col] = combo_data[first_valid_idx, metric_col]
            end
        end
        
        # Normalize all entries for this combination
        for combo_row in eachrow(combo_data)
            normalized_row = copy(combo_row)
            
            for (metric_col, _, _) in metrics
                if haskey(first_values, metric_col) && 
                   !ismissing(combo_row[metric_col]) && 
                   !isnothing(combo_row[metric_col]) && 
                   combo_row[metric_col] > 0
                    normalized_row[metric_col] = combo_row[metric_col] / first_values[metric_col]
                else
                    normalized_row[metric_col] = missing
                end
            end
            
            push!(normalized_rows, normalized_row)
        end
    end
    
    if isempty(normalized_rows)
        return DataFrame()
    end
    
    result = vcat(normalized_rows...)
    println("    Normalized $(nrow(result)) rows across $(nrow(combinations)) project/task combinations")
    return result
end

function compute_geometric_means(data, metric)
    """Compute geometric means grouped by Julia version and date."""
    println("    Computing geometric means for $metric...")
    
    # Group by julia_version and date
    grouped = groupby(data, [:julia_version, :julia_version_parsed, :date])
    
    summary_rows = DataFrame[]
    
    for group in grouped
        # Filter out missing/invalid values
        valid_values = filter(x -> !ismissing(x) && !isnothing(x) && x > 0, group[!, metric])
        
        if length(valid_values) > 0
            # Compute geometric mean
            geom_mean = exp(mean(log.(valid_values)))
            
            summary_row = DataFrame(
                julia_version = [group.julia_version[1]],
                julia_version_parsed = [group.julia_version_parsed[1]],
                date = [group.date[1]]
            )
            summary_row[!, metric] = [geom_mean]
            
            push!(summary_rows, summary_row)
        end
    end
    
    if isempty(summary_rows)
        return DataFrame()
    end
    
    result = vcat(summary_rows...)
    println("      Found $(nrow(result)) date/version combinations")
    return result
end

function main()
    """Main function to create all visualizations."""
    println("TTFX Snippets Visualization Script")
    println("==================================")
    
    # Load data
    data = load_ttfx_data()
    
    # Create summary plot first
    create_summary_plot(data)
    
    # Create individual package/task plots
    create_package_task_plots(data)
    
    println("\nVisualization complete! Check the plots/Julia-TTFX-Snippets/ directory.")
end

# Run the visualization
main()
