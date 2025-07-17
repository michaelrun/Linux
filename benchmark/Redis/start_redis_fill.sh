#!/bin/bash

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

# Benchmark command line arguments (common for all instances)
# -c 16: 16 parallel connections
# -d 1024: Data size of 1024 bytes
# --threads 16: Use 16 threads for the benchmark client
# -r 5000000: Random keys space of 5 million
# -n 150000000: Total number of requests
# --precision 3: Output precision of 3 decimal places
# -t set: Benchmark only the SET command
# -P 64: Pipeline 64 requests
#BENCHMARK_ARGS="-c 16 -d 1024 --threads 16 -r 5000000 -n 150000000 --precision 3 -t set -P 64"
#BENCHMARK_ARGS="-c 16 -d 1024 --threads 16 -r 2500000 -n 80000000 --precision 3 -t set -P 64"
BENCHMARK_ARGS="-c 16 -d 1024 --threads 16 -r 5000000 -n 100000000 --precision 3 -t set -P 64" 

# --- Script Logic ---

echo "Starting Redis benchmark instances..."
echo "--------------------------------------------------------"

log_file_base="redis_fill" # Base name for individual benchmark log files
num_benchmarks=${#CPU_BENCHMARK_ARRAY[@]}

# Ensure there are CPU cores defined for benchmarks
if [ "$num_benchmarks" -eq 0 ]; then
    echo "Error: CPU_BENCHMARK_ARRAY is empty. Please define CPU cores to use."
    exit 1
fi

# Loop through each CPU core and calculate the corresponding Redis server port
for i in $(seq 0 $((num_benchmarks - 1))); do
    cpu_core="${CPU_BENCHMARK_ARRAY[$i]}"
    redis_port=$((PORT_BASE + i)) # Calculate port based on PORT_BASE and index

    # Construct the log file name for the current benchmark instance
    log_file="${log_file_base}_port${redis_port}_cpu${cpu_core}.log"

    echo "Launching Redis benchmark on CPU Core: $cpu_core, Connecting to Port: $redis_port, Log: $log_file"
    
    # Execute the Redis benchmark command using numactl
    # nohup: Prevents the command from being terminated when the shell exits.
    # numactl -m 0 -C <cpu_core>: Binds the process to NUMA node 0 and a specific CPU core.
    # > $log_file 2>&1 &: Redirects stdout and stderr to a specific log file and runs in background.
    cmd="nohup numactl -m 0 -C \"$cpu_core\" \"$REDIS_BENCHMARK_PATH\" -p \"$redis_port\" $BENCHMARK_ARGS > \"$log_file\" 2>&1 &"
    echo $cmd
    eval $cmd

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
echo "To stop them, you might need to kill the processes by their PIDs or use 'killall redis-benchmark'."

