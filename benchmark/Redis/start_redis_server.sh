#!/bin/bash

# --- Configuration ---
# Define the base port for Redis servers. Each subsequent server will use an incremented port.
PORT_BASE=9000

# Define the path to your Redis server executable.
# IMPORTANT: Replace this with the actual path to your redis-server binary.
REDIS_SERVER_PATH="/home/redis/src/redis-server"

# Define the CPU cores to use.
# Each element in this array corresponds to a Redis instance.
# Example: If you have 16 cores (0-15), you might use (0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
# Make sure these CPU cores exist on your system.
# For demonstration, I'm using a smaller array. Adjust as needed.
CPU_ARRAY=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
#CPU_ARRAY=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95)


# --- Script Logic ---

echo "Starting Redis servers..."
echo "--------------------------------------------------------"

current_port=$PORT_BASE
log_file_base="redis_server" # Base name for individual Redis log files

# Loop through each CPU core defined in the CPU_ARRAY
for cpu_core in "${CPU_ARRAY[@]}"; do
    # Construct the log file name for the current Redis instance
    log_file="${log_file_base}_port${current_port}_cpu${cpu_core}.log"

    echo "Launching Redis on CPU Core: $cpu_core, Port: $current_port, Log: $log_file"
    
    # Execute the Redis server command using numactl
    # nohup: Prevents the command from being terminated when the shell exits.
    # numactl -m 0 -C <cpu_core>: Binds the process to NUMA node 0 and a specific CPU core.
    # --appendonly no --save '': Disables AOF and RDB persistence for a clean start (adjust if needed).
    # > $log_file 2>&1 &: Redirects stdout and stderr to a specific log file and runs in background.
    nohup numactl -m 0 -C "$cpu_core" "$REDIS_SERVER_PATH" --port "$current_port" --appendonly no --save '' > "$log_file" 2>&1 &

    # Check if the command was successful
    if [ $? -eq 0 ]; then
        echo "  -> Redis server started successfully (PID: $!)."
    else
        echo "  -> Failed to start Redis server on CPU Core $cpu_core, Port $current_port."
        echo "     Please check the path to redis-server and numactl configuration."
    fi

    # Increment the port for the next Redis instance
    current_port=$((current_port + 1))
    echo "--------------------------------------------------------"
done

echo "All Redis servers launched (or attempted to launch)."
echo "You can check their status using 'ps aux | grep redis-server' or by checking the log files."
echo "To stop them, you might need to kill the processes by their PIDs or use 'killall redis-server'."

