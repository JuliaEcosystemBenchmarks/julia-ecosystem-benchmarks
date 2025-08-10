using CSV
using DataFrames
using AlgebraOfGraphics
using CairoMakie
using Dates

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
            axislegend(ax, position = :rt)
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

function main()
    """Main function to create all visualizations."""
    println("TTFX Snippets Visualization Script")
    println("==================================")
    
    # Load data
    data = load_ttfx_data()
    
    # Create all plots
    create_package_task_plots(data)
    
    println("\nVisualization complete! Check the plots/Julia-TTFX-Snippets/ directory.")
end

# Run the visualization
main()
