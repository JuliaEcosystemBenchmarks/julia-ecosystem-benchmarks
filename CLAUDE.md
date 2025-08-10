# Julia Ecosystem Benchmarks - Claude Context

## Repository Overview
This repository contains bash scripts for benchmarking various features of the Julia language ecosystem across different Julia versions and registry states. The benchmarks are designed to measure Time-To-First-X (TTFX) performance metrics.

## Key Scripts
- `run_all.sh`: Main orchestration script that runs benchmarks across multiple Julia versions
- `run_julia_ttfx_snippets.sh`: Runs TTFX benchmarks using the Julia-TTFX-Snippets repository
- `run_all_between_dates.sh`: Runs benchmarks for specific date ranges
- `timetravel_setup.sh`: Sets up registry time-travel functionality
- `hostdescription.sh`: Captures host system information

## Environment Variables
- `JEB_JULIA_VERSION`: Julia version being tested
- `JEB_REGISTRY_START_DATE` / `JEB_REGISTRY_END_DATE`: Registry date range
- `JEB_REGISTRY_DATE`: Specific registry date
- `JEB_HOSTNAME`: Host system identifier
- `JULIA_DEPOT_PATH`: Set to `$PWD/depot`
- `JULIA_PKG_PRECOMPILE_AUTO=0`: Disables automatic precompilation
- `JULIA_CI=true`: Enables CI mode
- `JULIA_NUM_THREADS=4`: Sets thread count

## Log Storage
- Benchmark results are stored in the `jeb_logs` branch (remote: `origin/jeb_logs`)
- Logs are organized by benchmark type and contain detailed timing information
- Log files include: `.instantiate.log`, `.precompile`, `.precompile.log`, `.task`, `.task.log`

## Julia Versions Tracked
Currently benchmarks Julia versions from 1.8.0 through 1.11.6, with corresponding registry date ranges for each version.

## Typical Workflow
1. Host description is captured
2. For each Julia version, the registry is set to the appropriate time period
3. TTFX snippets are cloned and executed
4. Timing data is collected for instantiation, precompilation, and task execution
5. Results are logged with detailed system information

## Testing Commands
No specific test commands found. Benchmarks are run directly via the shell scripts.

## Julia Version Management with juliaup

This repository uses `juliaup` (Julia Version Manager) to handle multiple Julia versions for benchmarking.

### Key juliaup Commands:
- `julia +{version}`: Launch specific Julia version (e.g. `julia +1.10.5`)  
- `julia`: Use default Julia version (currently 1.11.6)
- `juliaup list`: Show all available Julia channels/versions
- `juliaup status`: Show installed versions and current default
- `juliaup add {version}`: Install a specific Julia version
- `juliaup default {version}`: Set default Julia version

### Available Versions:
The system has extensive Julia version coverage from 0.3.x through 1.11.x, including:
- All major releases (1.0, 1.1, 1.2, ..., 1.11)  
- Patch releases (e.g. 1.10.0 through 1.10.10)
- Pre-release versions (alpha, beta, rc)
- Architecture variants (x64, x86)

### Benchmark Usage:
The benchmarking scripts use `julia +$JEB_JULIA_VERSION` to run tests with specific Julia versions as defined in the `VERSIONS` variable in `run_all.sh`.

## Julia Analysis Scripts

The repository includes Julia analysis scripts for processing benchmark logs:

### Project Structure
- `Project.toml`: Local Julia project configuration with dependencies
- `analyze_precompile_logs.jl`: Script to analyze *.precompile and *.task files from jeb_logs branch

### Dependencies
- DataFrames.jl: For data manipulation and tabular display
- Printf.jl: For formatted output
- Logging.jl: Built-in logging capabilities (standard library)

### Running Julia Scripts
Use the local project environment to ensure proper dependencies:
```bash
julia --project analyze_precompile_logs.jl
```

Or enter Julia REPL with project:
```bash
julia --project
```

### Adding New Dependencies
```bash
julia --project -e "using Pkg; Pkg.add(\"PackageName\")"
```

## Build/Lint Commands
No build or lint commands identified. This is primarily a bash-based benchmarking suite.