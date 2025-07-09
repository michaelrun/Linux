#!/bin/bash

# sysbench_client_orchestrator.sh
# This script orchestrates the sysbench benchmark from the client host,
# communicating with the MySQL server host via SSH.

# --- Configuration for Sysbench Client Host ---
# Ensure this script is run on the machine running sysbench clients.

# --- Command Line Arguments ---
# $1: run_tag (e.g., "my_test_run") - Used for naming output directories and logs.
# $2: mysql_server_ip (e.g., "192.168.1.100") - IP address of the MySQL server host.
# $3: server_ssh_user (e.g., "ubuntu") - SSH username on the MySQL server host.

RUN_TAG="$1"
MYSQL_SERVER_IP="$2"
SERVER_SSH_USER="$3"

if [ -z "$RUN_TAG" ] || [ -z "$MYSQL_SERVER_IP" ] || [ -z "$SERVER_SSH_USER" ]; then
    echo "Usage: $0 <run_tag> <mysql_server_ip> <server_ssh_user>"
    echo "Example: $0 testrun 192.168.1.100 ubuntu"
    exit 1
fi

# Generate a consistent timestamp for this run, used by both client and server logs
curr_datetime=`date '+%Y%m%d%H%M%S'`

# --- Benchmark Configuration (Shared - Keep in sync with server script) ---
# This 'maindir' is for client-side logs and results.
BASE_CLIENT_OUTPUT_DIR="/home/guoqing/sysbench/RunOutput_Client" # Assuming a similar HOME_DIR structure on client
maindir="${BASE_CLIENT_OUTPUT_DIR}/vu64-${RUN_TAG}" # Simplified client maindir
mkdir -p "${maindir}"

clientnameprefix="sysbench_client"
vu=64         # Virtual Users (Sysbench threads per client)

# --- Core/NUMA Assignments (Client Specific) ---
# These define where Sysbench clients will run on the client host.
clientNumaNode=("0" "0" "0" "0" "0" "0" "1" "1" "1" "1" "1" "1" "2" "2" "2" "2" "2" "2" "3" "3" "3" "3" "3" "3")
clientCpuCores=("0-3,96-99" "4-7,100-103" "8-11,104-107" "12-15,108-111" "16-19,112-115" "20-23,116-119" "24-27,120-123" "28-31,124-127" "32-35,128-131" "36-39,132-135" "40-43,136-139" "44-47,140-143" "48-51,144-147" "52-55,148-151" "56-59,152-155" "60-63,156-159" "64-67,160-163" "68-71,164-167" "72-75,168-171" "76-79,172-175" "80-83,176-179" "84-87,180-183" "88-91,184-187" "92-95,188-191")


# --- Global Variables for MySQL & Sysbench (Shared - Keep in sync with server script) ---
# These are client-side credentials to connect to the MySQL server.
MYSQL_ROOT_PASSWORD="MyNewPass4!" # Used for initial user/db setup from client
MYSQL_BENCH_USER="sbtest"
MYSQL_BENCH_PASSWORD="sysbench_password" # REMEMBER TO CHANGE THIS!
MYSQL_DATABASE="sbtest"
MYSQL_PORT_BASE=13060 # Starting port for MySQL instances (e.g., 33060, 33061, ...)
MYSQL_CLIENT_PATH="/usr/bin/mysql" # Path to the mysql client binary on the client host
MYSQL_RAND_TYPE="uniform"


SYSBENCH_SCRIPT="/usr/local/share/sysbench/oltp_read_write.lua"
SYSBENCH_TABLES=16
SYSBENCH_TABLE_SIZE=1000000
SYSBENCH_TIME=60 # seconds
SYSBENCH_REPORT_INTERVAL=10 # seconds

# --- Monitoring Configuration (Client Orchestration) ---
MONITOR_DURATION=20 # seconds - Duration for which monitoring tools will collect data

# --- Functions ---

# Function to execute a command on the remote server via SSH
remote_exec() {
    local command_to_run="$1"
    echo "Client: Executing remotely on ${SERVER_SSH_USER}@${MYSQL_SERVER_IP}:"
    echo "  $command_to_run"
    ssh "${SERVER_SSH_USER}@${MYSQL_SERVER_IP}" "bash -c '${command_to_run}'"
    local ssh_exit_code=$?
    if [ $ssh_exit_code -ne 0 ]; then
        echo "Client: ERROR: Remote command failed with exit code $ssh_exit_code."
        return 1
    fi
    return 0
}

# Wait for a remote MySQL instance to be ready and create bench user/database
wait_for_mysql_client_setup() {
    local instance_idx=$1
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local max_attempts=12 # 12 * 10 seconds = 2 minutes timeout
    local attempt=0

    echo "Client: Waiting for remote MySQL instance ${instance_idx} on ${MYSQL_SERVER_IP}:${mysql_port} to be ready and setting up user/db..."

    # Loop until MySQL is reachable
    while ! "${MYSQL_CLIENT_PATH}" -h "${MYSQL_SERVER_IP}" -P "${mysql_port}" -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; do
        sleep 10
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Client: Error: Remote MySQL instance ${instance_idx} at ${MYSQL_SERVER_IP}:${mysql_port} did not become ready after ${max_attempts} attempts."
            return 1
        fi
        echo "Client: Attempt $attempt: Waiting for remote MySQL instance ${instance_idx}..."
    done
    echo "Client: Remote MySQL instance ${instance_idx} is ready. Creating benchmark user and database..."

    # Create database and user for sysbench
    # Granting privileges for remote access via SQL statement
    echo "\"${MYSQL_CLIENT_PATH}\" -h \"${MYSQL_SERVER_IP}\" -P \"${mysql_port}\" -u root -p\"${MYSQL_ROOT_PASSWORD}\""
    "${MYSQL_CLIENT_PATH}" -h "${MYSQL_SERVER_IP}" -P "${mysql_port}" -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
        CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
        CREATE USER IF NOT EXISTS '${MYSQL_BENCH_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_BENCH_PASSWORD}';
        -- Grant remote access to the benchmark user from any host (%)
        GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_BENCH_USER}'@'%';
        FLUSH PRIVILEGES;
    "
    if [ $? -ne 0 ]; then
        echo "Client: Error setting up user/db for remote instance ${instance_idx}."
        return 1
    fi
    echo "Client: Benchmark user and database created and remote access granted for instance ${instance_idx}."
    return 0
}

# Run sysbench operation (prepare, run, cleanup) locally on client
run_sysbench_operation() {
    local instance_idx=$1
    local operation=$2
    local sysbench_type=${3:-""}
    local client_core_set=${clientCpuCores[$instance_idx]}
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local client_name="${clientnameprefix}_${instance_idx}"
    local log_file="$maindir/${client_name}_${operation}.log"
    export SYSBENCH_LUA_PATH=/usr/local/share/sysbench
    
    if [[ "$operation" == "run" ]]; then
        log_file="$maindir/${client_name}_${sysbench_type}_benchmark.log"
    fi

    echo "Client: Running Sysbench ${operation} for MySQL instance ${instance_idx} on client cores ${client_core_set} connecting to ${MYSQL_SERVER_IP}:${mysql_port}..."
    
    local cmd="taskset -c \"${client_core_set}\" sysbench"
    
    if [[ "$operation" == "run" ]]; then
        cmd+=" ${sysbench_type}"
    else
        cmd+=" ${SYSBENCH_SCRIPT}"
    fi
    
    cmd+=" --db-driver=mysql"
    cmd+=" --mysql-host=${MYSQL_SERVER_IP}" # Connect to remote IP
    cmd+=" --mysql-port=\"${mysql_port}\""
    cmd+=" --mysql-user=\"${MYSQL_BENCH_USER}\""
    cmd+=" --mysql-password=\"${MYSQL_BENCH_PASSWORD}\""
    cmd+=" --mysql-db=\"${MYSQL_DATABASE}\""
    cmd+=" --tables=\"${SYSBENCH_TABLES}\""
    cmd+=" --table_size=\"${SYSBENCH_TABLE_SIZE}\""
    
    if [[ "$operation" == "run" ]]; then
        cmd+=" --threads=\"${vu}\""
        cmd+=" --time=\"${SYSBENCH_TIME}\""
    elif [[ "$operation" == "prepare" ]]; then
        cmd+=" --threads=16"
    fi
    
    cmd+=" --rand-type=\"${MYSQL_RAND_TYPE}\""
    cmd+=" ${operation}"
    cmd+=" > \"${log_file}\" 2>&1 &"
    
    eval "$cmd"
    local pid=$!
    echo "$pid" > "$maindir/${client_name}_${operation}.pid"
    
    if [[ "$operation" == "run" ]]; then
        echo "$pid" > "$maindir/${client_name}_run.pid"
    fi
    
    echo "Client: Sysbench ${operation} for instance ${instance_idx} started with PID $pid"
}

# Wait for background processes (local to client) and check their status
wait_for_processes() {
    local process_name=$1
    local -n pids_array=$2 # Use nameref to pass array by reference
    local all_success=true

    echo "Client: Waiting for all local ${process_name} processes to complete..."
    for pid in "${pids_array[@]}"; do
        if ! wait "$pid"; then
            echo "Client: WARNING: Local ${process_name} process ${pid} failed or had non-zero exit."
            all_success=false
        fi
    done

    if ! $all_success; then
        echo "Client: ERROR: One or more local ${process_name} processes failed. Check logs."
        return 1
    fi
    return 0
}

# Run benchmark for a specific type
run_benchmark() {
    local benchmark_type=$1
    declare -a run_pids

    echo "Client: Starting all Sysbench benchmark ${benchmark_type} runs..."
    
    # Start monitoring on server side
    echo "Client: Instructing server to start monitoring for ${benchmark_type}..."
    remote_exec "${SERVER_SCRIPT_PATH} start_monitoring ${benchmark_type} ${RUN_TAG} ${curr_datetime}" || { echo "Client: Failed to start remote monitoring."; exit 1; }

    # Start sysbench clients locally
    for i in "${!clientCpuCores[@]}"; do # Iterate based on client instances
        run_sysbench_operation "$i" "run" "$benchmark_type"
        run_pids+=($(cat "$maindir/${clientnameprefix}_${i}_run.pid"))
    done

    # Wait for the monitoring duration, then stop monitoring on server
    echo "Client: Waiting ${MONITOR_DURATION} seconds for initial monitoring phase..."
    sleep "${MONITOR_DURATION}"
    echo "Client: Instructing server to stop monitoring for ${benchmark_type}..."
    remote_exec "${SERVER_SCRIPT_PATH} stop_monitoring ${benchmark_type} ${RUN_TAG}" || { echo "Client: Failed to stop remote monitoring."; } # Don't exit here, let benchmark finish

    # Wait for the sysbench run to complete its full duration
    echo "Client: Waiting for all local Sysbench benchmark ${benchmark_type} runs to complete..."
    wait_for_processes "${benchmark_type}" run_pids || exit 1
}


gather_sysbench_results() {
    local output_file="$maindir/sysbench_results_summary_${curr_datetime}.txt"

    echo "--- Benchmark Results Summary ---" | tee -a "$output_file"
    local benchmark_types=("oltp_read_only" "oltp_write_only" "oltp_read_write")

    # Arrays to store totals for calculating averages
    declare -A total_transactions
    declare -A total_queries
    declare -A total_eps
    declare -A total_min_latency
    declare -A total_avg_latency
    declare -A total_max_latency
    declare -A total_p95_latency
    declare -A instance_count

    # Function to clean numbers for bc
    clean_number() {
        local num="$1"
        # Remove commas and parentheses
        num=$(echo "$num" | tr -d ',()')
        # Ensure we have a valid number (default to 0 if not)
        [[ "$num" =~ ^[0-9.]+$ ]] || num=0
        echo "$num"
    }

    # Initialize arrays
    for btype in "${benchmark_types[@]}"; do
        total_transactions[$btype]=0
        total_queries[$btype]=0
        total_eps[$btype]=0
        total_min_latency[$btype]=0
        total_avg_latency[$btype]=0
        total_max_latency[$btype]=0
        total_p95_latency[$btype]=0
        instance_count[$btype]=0
    done

    # First pass: collect per-instance metrics and accumulate totals
    {
    for i in "${!clientCpuCores[@]}"; do # Iterate based on client instances
        local instance_idx=$i
        local client_name="${clientnameprefix}_${instance_idx}"
	local mysql_port=$(( MYSQL_PORT_BASE + instance_idx ))
	echo "Results for ${client_name} (Connecting to MySQL instance ${instance_idx} on ${MYSQL_SERVER_IP}:${mysql_port})"
        echo "--------------------------------------------------------------------"

        for btype in "${benchmark_types[@]}"; do
            local log_file="$maindir/${client_name}_${btype}_benchmark.log"

            echo "  Type: ${btype}"
            if [[ -f "$log_file" ]]; then
                # Extract metrics from log file
                local transactions_line=$(grep "transactions:" "$log_file" | tail -1)
                local queries_line=$(grep "queries:" "$log_file" | tail -1)
                local events_per_second_line=$(grep "events/s (eps):" "$log_file" | tail -1)
                local min_latency_line=$(grep -E "^\s*min:" "$log_file" | tail -1)
                local avg_latency_line=$(grep -E "^\s*avg:" "$log_file" | tail -1)
                local max_latency_line=$(grep -E "^\s*max:" "$log_file" | tail -1)
                local p95_latency_line=$(grep -E "^\s*95th percentile:" "$log_file" | tail -1)

                # Display instance metrics
                [[ -n "$transactions_line" ]] && echo "    Transactions: ${transactions_line}" || echo "    Transactions: N/A"
                [[ -n "$queries_line" ]] && echo "    Queries: ${queries_line}" || echo "    Queries: N/A"
                [[ -n "$events_per_second_line" ]] && echo "    Events/s: ${events_per_second_line}" || echo "    Events/s: N/A"

                echo "    Latency (ms):"
                [[ -n "$min_latency_line" ]] && echo "      ${min_latency_line}" || echo "      min: N/A"
                [[ -n "$avg_latency_line" ]] && echo "      ${avg_latency_line}" || echo "      avg: N/A"
                [[ -n "$max_latency_line" ]] && echo "      ${max_latency_line}" || echo "      max: N/A"
                [[ -n "$p95_latency_line" ]] && echo "      ${p95_latency_line}" || echo "      95th percentile: N/A"

                # Extract and clean numeric values
                if [[ -n "$transactions_line" ]]; then
                    local transactions=$(echo "$transactions_line" | awk '{print $3}')
                    transactions=$(clean_number "$transactions")
                    total_transactions[$btype]=$(echo "${total_transactions[$btype]} + $transactions" | bc)
                fi

                if [[ -n "$queries_line" ]]; then
                    local queries=$(echo "$queries_line" | awk '{print $3}')
                    queries=$(clean_number "$queries")
                    total_queries[$btype]=$(echo "${total_queries[$btype]} + $queries" | bc)
                fi

                if [[ -n "$events_per_second_line" ]]; then
                    local eps=$(echo "$events_per_second_line" | awk '{print $4}')
                    eps=$(clean_number "$eps")
                    total_eps[$btype]=$(echo "${total_eps[$btype]} + $eps" | bc)
                fi

                if [[ -n "$min_latency_line" ]]; then
                    local min_latency=$(echo "$min_latency_line" | awk '{print $2}')
                    min_latency=$(clean_number "$min_latency")
                    total_min_latency[$btype]=$(echo "${total_min_latency[$btype]} + $min_latency" | bc)
                fi

                if [[ -n "$avg_latency_line" ]]; then
                    local avg_latency=$(echo "$avg_latency_line" | awk '{print $2}')
                    avg_latency=$(clean_number "$avg_latency")
                    total_avg_latency[$btype]=$(echo "${total_avg_latency[$btype]} + $avg_latency" | bc)
                fi

                if [[ -n "$max_latency_line" ]]; then
                    local max_latency=$(echo "$max_latency_line" | awk '{print $2}')
                    max_latency=$(clean_number "$max_latency")
                    total_max_latency[$btype]=$(echo "${total_max_latency[$btype]} + $max_latency" | bc)
                fi

                if [[ -n "$p95_latency_line" ]]; then
                    local p95_latency=$(echo "$p95_latency_line" | awk '{print $3}')
                    p95_latency=$(clean_number "$p95_latency")
                    total_p95_latency[$btype]=$(echo "${total_p95_latency[$btype]} + $p95_latency" | bc)
                fi

                instance_count[$btype]=$((instance_count[$btype] + 1))
            else
                echo "    Log file not found: $log_file"
            fi
            echo "  ---"
        done
        echo "--------------------------------------------------------------------"
    done

    # Calculate and display averages
    echo ""
    echo "=== Average Metrics Across All Client Instances ==="
    echo "--------------------------------------------------------------------"

    for btype in "${benchmark_types[@]}"; do
        if [ "${instance_count[$btype]}" -gt 0 ]; then
            echo "Benchmark Type: ${btype}"

            # Calculate averages
            local avg_transactions=$(echo "scale=2; ${total_transactions[$btype]} / ${instance_count[$btype]}" | bc)
            local avg_queries=$(echo "scale=2; ${total_queries[$btype]} / ${instance_count[$btype]}" | bc)
            local avg_eps=$(echo "scale=2; ${total_eps[$btype]} / ${instance_count[$btype]}" | bc)
            local avg_min_latency=$(echo "scale=2; ${total_min_latency[$btype]} / ${instance_count[$btype]}" | bc)
            local avg_avg_latency=$(echo "scale=2; ${total_avg_latency[$btype]} / ${instance_count[$btype]}" | bc)
            local avg_max_latency=$(echo "scale=2; ${total_max_latency[$btype]} / ${instance_count[$btype]}" | bc)
            local avg_p95_latency=$(echo "scale=2; ${total_p95_latency[$btype]} / ${instance_count[$btype]}" | bc)

            # Display averages
            echo "  Average Transactions: ${avg_transactions}"
            echo "  Average Queries: ${avg_queries}"
            echo "  Average Events/s: ${avg_eps}"
            echo "  Average Latency (ms):"
            echo "    min: ${avg_min_latency}"
            echo "    avg: ${avg_avg_latency}"
            echo "    max: ${avg_max_latency}"
            echo "    95th percentile: ${avg_p95_latency}"
            echo "--------------------------------------------------------------------"
        else
            echo "No data available for ${btype}"
            echo "--------------------------------------------------------------------"
        fi
    done
    } | tee -a "$output_file"

    echo ""
    echo "Results have been saved to: $output_file"
}


# --- Main Script Execution (Client Orchestrator) ---

echo "--- Starting Sysbench Client Orchestration ---"
echo "Run Tag: ${RUN_TAG}"
echo "MySQL Server IP: ${MYSQL_SERVER_IP}"
echo "Server SSH User: ${SERVER_SSH_USER}"
echo "Client output directory: ${maindir}"
echo "Benchmark duration: ${SYSBENCH_TIME} seconds"
echo "Monitoring duration: ${MONITOR_DURATION} seconds"
echo "Current Run Timestamp: ${curr_datetime}"

# Path to the server management script on the remote host
SERVER_SCRIPT_PATH="/home/guoqing/sysbench/mysql_server_management.sh" # <<< SET THIS PATH ON CLIENT HOST

# 0. Initial Clean up on client side
echo "Client: Cleaning up any old PIDs and logs in client directory..."
rm -rf "${maindir}"/*.pid "${maindir}"/*.log

# 0. Initial Clean up on server side
echo "Client: Instructing server to perform initial cleanup..."
remote_exec "${SERVER_SCRIPT_PATH} set_run_tag ${RUN_TAG}" || exit 1 # Set maindir on server
remote_exec "${SERVER_SCRIPT_PATH} cleanup_all_server ${RUN_TAG}" || exit 1

# 1. Initialize and Start MySQL instances on the server
echo "Client: Instructing server to initialize and start MySQL instances..."
remote_exec "${SERVER_SCRIPT_PATH} init_and_start_mysql ${RUN_TAG}" || exit 1

# 2. Wait for remote MySQL instances to be ready and create database/user
echo "Client: Waiting for remote MySQL instances to become ready and setting up bench user/db..."
declare -a wait_db_pids
for i in "${!clientCpuCores[@]}"; do # Iterate based on client instances (each client instance connects to a MySQL instance)
    wait_for_mysql_client_setup "$i" & # Run in background for concurrent waiting
    wait_db_pids+=("$!")
done
wait_for_processes "Remote MySQL readiness and setup" wait_db_pids || exit 1
echo "Client: All remote MySQL instances are ready and configured for benchmarking."

export LUA_PATH="/usr/local/share/sysbench/?.lua;;"

# 3. Prepare Sysbench data for all instances concurrently
echo "Client: Preparing Sysbench data for all instances..."
declare -a prepare_pids
for i in "${!clientCpuCores[@]}"; do # Iterate based on client instances
    run_sysbench_operation "$i" "prepare"
    prepare_pids+=($(cat "$maindir/${clientnameprefix}_${i}_prepare.pid"))
done

wait_for_processes "Sysbench prepare" prepare_pids || exit 1
echo "Client: All Sysbench data prepared."

# 4. Run the benchmarks with remote monitoring orchestration
run_benchmark "oltp_read_only"
run_benchmark "oltp_write_only"
run_benchmark "oltp_read_write"

# 5. Gather and display results (client side)
gather_sysbench_results

# 6. Generate Flamegraph reports on the server
echo "Client: Instructing server to generate Flamegraph reports..."
remote_exec "${SERVER_SCRIPT_PATH} generate_flamegraph ${RUN_TAG} ${curr_datetime}" || { echo "Client: Failed to generate remote flamegraphs."; }

# 7. Cleanup Sysbench data (client side)
echo "Client: Cleaning up Sysbench data from all instances..."
declare -a cleanup_pids
for i in "${!clientCpuCores[@]}"; do # Iterate based on client instances
    run_sysbench_operation "$i" "cleanup"
    cleanup_pids+=($(cat "$maindir/${clientnameprefix}_${i}_cleanup.pid"))
done

wait_for_processes "Sysbench cleanup" cleanup_pids
echo "Client: All Sysbench data cleaned up."

# 8. Stop and remove all MySQL instance data on the server
echo "Client: Instructing server to stop and remove all MySQL instances and their data..."
remote_exec "${SERVER_SCRIPT_PATH} stop_and_cleanup_mysql ${RUN_TAG}" || exit 1

echo "--- Sysbench Client Orchestration Complete ---"

