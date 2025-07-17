#!/bin/bash

# --- Script Usage ---
# This script launches multiple redis-benchmark instances, each on a specified CPU core,
# connecting to incrementally increasing Redis server ports.
# It accepts two command-line arguments:
#   1. parallelism: The number of parallel connections and threads for each benchmark instance (-c and --threads).
#   2. operation: The Redis command to benchmark (e.g., 'set', 'get', 'lpush').
#
# Usage: ./redis-benchmark-custom-script.sh <parallelism> <operation>
# Example: ./redis-benchmark-custom-script.sh 32 get

# --- Configuration ---
# Define the path to your Redis benchmark executable.
# IMPORTANT: Replace this with the actual path to your redis-benchmark binary.
REDIS_BENCHMARK_PATH="./vip-redis-6.2.5.2.1-vip/src/redis-benchmark"

# Define the CPU cores to use for running benchmark instances.
# Each element in this array corresponds to a redis-benchmark instance.
# Example: If you want to use cores 16-31, you might use (16 17 18 ... 31)
# Make sure these CPU cores exist on your system.
CPU_BENCHMARK_ARRAY=(32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47)
#CPU_BENCHMARK_ARRAY=(32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127)


# Define the base port for Redis servers that the benchmarks should connect to.
# Each benchmark instance will connect to a port incremented from this base.
PORT_BASE=9000

# --- Parameter Handling ---
# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <parallelism> <operation>"
    echo "Example: $0 32 get"
    exit 1
fi

# Assign command-line arguments to variables
parallelism="$1"
operation="$2"

# Validate parallelism (optional, but good practice)
if ! [[ "$parallelism" =~ ^[0-9]+$ ]]; then
    echo "Error: Parallelism must be a positive integer."
    exit 1
fi

# --- Benchmark Command Line Arguments (dynamic based on parameters) ---
# -c <parallelism>: Number of parallel connections
# -d 1024: Data size of 1024 bytes
# --threads <parallelism>: Use <parallelism> threads for the benchmark client
# -r 5000000: Random keys space of 5 million
# -n 5000000: Total number of requests (changed to 5,000,000 as per your example)
# --precision 3: Output precision of 3 decimal places
# -t <operation>: Benchmark the specified Redis command (e.g., 'set', 'get')
# -P 64: Pipeline 64 requests
#BENCHMARK_ARGS="-c $parallelism -d 1024 --threads $parallelism -r 5000000 -n 5000000 --precision 3 -t $operation -P 1"
BENCHMARK_ARGS="-c $parallelism -d 1024 --threads $parallelism -r 5000000 -n 5000000 --precision 3 -t $operation -P 1"

# --- Script Logic ---

echo "Starting Redis benchmark instances with parallelism=$parallelism and operation=$operation..."
echo "--------------------------------------------------------"

log_file_base="redis_benchmark" # Base name for individual benchmark log files
num_benchmarks=${#CPU_BENCHMARK_ARRAY[@]}

# Ensure there are CPU cores defined for benchmarks
if [ "$num_benchmarks" -eq 0 ]; then
    echo "Error: CPU_BENCHMARK_ARRAY is empty. Please define CPU cores to use."
    exit 1
fi

# Array to store PIDs of background benchmark processes
declare -a benchmark_pids

# Loop through each CPU core and calculate the corresponding Redis server port
for i in $(seq 0 $((num_benchmarks - 1))); do
    cpu_core="${CPU_BENCHMARK_ARRAY[$i]}"
    redis_port=$((PORT_BASE + i)) # Calculate port based on PORT_BASE and index

    # Construct the log file name for the current benchmark instance
    log_file="${log_file_base}_port${redis_port}_cpu${cpu_core}_${operation}_p${parallelism}.log"

    echo "Launching Redis benchmark on CPU Core: $cpu_core, Connecting to Port: $redis_port, Log: $log_file"
    
    # Execute the Redis benchmark command using numactl
    # nohup: Prevents the command from being terminated when the shell exits.
    # numactl -m 0 -C <cpu_core>: Binds the process to NUMA node 0 and a specific CPU core.
    # > $log_file 2>&1 &: Redirects stdout and stderr to a specific log file and runs in background.
    #cmd="nohup numactl -m 1 -C \"$cpu_core\" \"$REDIS_BENCHMARK_PATH\" -p \"$redis_port\" $BENCHMARK_ARGS > \"$log_file\" 2>&1 &"
    cmd="nohup numactl -m 1 -N 1 \"$REDIS_BENCHMARK_PATH\" -p \"$redis_port\" $BENCHMARK_ARGS > \"$log_file\" 2>&1 &"
    echo $cmd
    eval $cmd
    benchmark_pids+=($!)

    # Check if the command was successful
    if [ $? -eq 0 ]; then
        echo "  -> Redis benchmark started successfully (PID: $!)."
    else
        echo "  -> Failed to start Redis benchmark on CPU Core $cpu_core, Port $redis_port."
        echo "     Please check the path to redis-benchmark and numactl configuration."
    fi
    echo "--------------------------------------------------------"
done

echo "All Redis benchmark instances launched (or attempted to launch)."
echo "You can check their status using 'ps aux | grep redis-benchmark' or by checking the log files."
echo ""
echo "Waiting for all benchmark processes to finish..."

# Wait for all background benchmark processes to complete
for pid in "${benchmark_pids[@]}"; do
    wait "$pid"
    echo "  -> Process $pid finished."
done
echo "All benchmark processes have completed."




# --- Function to calculate and display summary statistics ---
calculate_and_display_summary() {
    local total_throughput=0.0
    local total_avg_latency=0.0
    local instance_count=0
    local current_port_for_summary=$PORT_BASE # Start from the base port for summary calculation

    echo ""
    echo "--- Benchmark Results Summary ---"
    echo "--------------------------------------------------------"

    for i in $(seq 0 $((num_benchmarks - 1))); do
        local cpu_core="${CPU_BENCHMARK_ARRAY[$i]}"
        local redis_port=$((current_port_for_summary + i))
        local log_file="${log_file_base}_port${redis_port}_cpu${cpu_core}_${operation}_p${parallelism}.log"

        if [ -f "$log_file" ]; then
            echo "Processing log file: $log_file"
            # Extract throughput
            throughput=$(grep "throughput summary:" "$log_file" | awk '{print $3}')
            # Extract avg latency
            avg_latency=$(grep "avg" "$log_file" -A 1 | tail -n 1 | awk '{print $1}')

            if [[ -n "$throughput" && -n "$avg_latency" ]]; then
                echo "  Instance on CPU $cpu_core (Port $redis_port): Throughput = $throughput req/s, Avg Latency = $avg_latency msec"
                total_throughput=$(awk "BEGIN {print $total_throughput + $throughput}")
                total_avg_latency=$(awk "BEGIN {print $total_avg_latency + $avg_latency}")
                instance_count=$((instance_count + 1))
            else
                echo "  Could not extract data from $log_file. Benchmark might not have completed or log format is different."
            fi
        else
            echo "  Log file not found: $log_file. Benchmark might not have started or completed."
        fi
        echo "--------------------------------------------------------"
    done

    if [ "$instance_count" -gt 0 ]; then
        average_throughput_per_instance=$(awk "BEGIN {print $total_throughput / $instance_count}")
        average_avg_latency=$(awk "BEGIN {print $total_avg_latency / $instance_count}")

        echo ""
        echo "--- Overall Summary ---"
        echo "Total Redis Benchmark Instances Processed: $instance_count"
        echo "Average Throughput per Instance: $(printf "%.2f" "$average_throughput_per_instance") requests/second"
        echo "Average 'Avg' Latency per Instance: $(printf "%.3f" "$average_avg_latency") msec"
        echo "Total Throughput of All Instances: $(printf "%.2f" "$total_throughput") requests/second"
    else
        echo "No successful benchmark results found to summarize."
    fi
    echo "--------------------------------------------------------"
}

# Call the summary function after a delay to allow benchmarks to complete
# Adjust the sleep duration based on how long your benchmarks typically run
echo ""
echo "Waiting for benchmarks to complete before summarizing results (sleeping for 60 seconds)..."

calculate_and_display_summary
