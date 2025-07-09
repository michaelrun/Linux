#!/bin/bash

# mysql_server_management.sh
# This script contains functions to manage MySQL instances and monitoring tools
# on the server host. These functions are designed to be called remotely via SSH
# by the sysbench_client_orchestrator.sh script.

# --- Global Configuration (Server Specific) ---
# It's crucial that these paths and configurations match your server environment.
curr_datetime="" # This will be set by the client orchestrator for consistency

# --- Hardware Information (Server Specific) ---
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
total_numa_nodes=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')
numa_per_socket=$((total_numa_nodes/total_sockets))
physical_cores_per_numa=$(( $cores_per_socket / $(( ${total_numa_nodes} / ${total_sockets} )) ))

# --- Benchmark Configuration (Shared - Keep in sync with client script) ---
# This 'maindir' is for server-side logs and data.
# The actual directory will be created with a run_tag passed from client.
HOME_DIR=/home/guoqing/sysbench
BASE_SERVER_OUTPUT_DIR="${HOME_DIR}/RunOutput_Server"
maindir="" # Will be set dynamically based on client input


servernameprefix="mysqld_instance"
memSize="16G"
bufferPoolSize="8G"

# --- Core/NUMA Assignments (Server Specific) ---
# These define where MySQL instances will run.
memNumaNode=("0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0")
mntdir=("/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2")
serverCpuCores=("0-3,192-195" "4-7,196-199" "8-11,200-203" "12-15,204-207" "16-19,208-211" "20-23,212-215" "24-27,216-219" "28-31,220-223" "32-35,224-227" "36-39,228-231" "40-43,232-235" "44-47,236-239" "48-51,240-243" "52-55,244-247" "56-59,248-251" "60-63,252-255" "64-67,256-259" "68-71,260-263" "72-75,264-267" "76-79,268-271" "80-83,272-275" "84-87,276-279" "88-91,280-283" "92-95,284-287")
serverCpuList="0-95,192-287" # Combined list of all server CPU cores

# These define where monitoring tools will run (on cores on the *server* machine that are designated for client-like tasks).
# This is to isolate monitoring overhead from the MySQL workload cores.
clientCpuCores=("96-99,288-291" "100-103,292-295" "104-107,296-299" "108-111,300-303" "112-115,304-307" "116-119,308-311" "120-123,312-315" "124-127,316-319" "128-131,320-323" "132-135,324-327" "136-139,328-331" "140-143,332-335" "144-147,336-339" "148-151,340-343" "152-155,344-347" "156-159,348-351" "160-163,352-355" "164-167,356-359" "168-171,360-363" "172-175,364-367" "176-179,368-371" "180-183,372-375" "184-187,376-379" "188-191,380-383")
clientCpuList="96-191,288-383" # Combined list of all client CPU cores (on server host, for monitoring tools)


# --- Global Variables for MySQL (Shared - Keep in sync with client script) ---
MYSQL_ROOT_PASSWORD="MyNewPass4!" # REMEMBER TO CHANGE THIS!
MYSQL_BENCH_USER="sbtest"
MYSQL_BENCH_PASSWORD="sysbench_password" # REMEMBER TO CHANGE THIS!
MYSQL_DATABASE="sbtest"
MYSQL_PORT_BASE=13060 # Starting port for MySQL instances (e.g., 33060, 33061, ...)
MYSQL_BASEDIR="/usr" # Adjust this to your actual MySQL installation base directory
MYSQL_DATADIR_PREFIX="mysql_data" # Subdirectory within mntdir for instance data
MYSQL_PIDFILE_PREFIX="/var/run/mysqld" # Common prefix for PID files
MYSQL_SOCKET_PREFIX="/var/run/mysqld" # Common prefix for socket files (not used for TCP/IP, but for internal tools)

# Paths to MySQL binaries (adjust if different on your system)
MYSQLD_PATH="${MYSQL_BASEDIR}/sbin/mysqld" # Path to the mysqld server binary
MYSQL_CLIENT_PATH="${MYSQL_BASEDIR}/bin/mysql" # Path to the mysql client binary

# --- Monitoring Configuration ---
MONITOR_DURATION=20 # seconds - Duration for which monitoring tools will collect data
declare -A MONITOR_PIDS # Associative array to store PIDs of monitoring tools

# IMPORTANT: Set this to the actual path of your FlameGraph repository on the SERVER HOST
FLAMEGRAPH_PATH="/path/to/FlameGraph" # <<< SET THIS PATH ON THE SERVER HOST

# --- Functions ---

# Function to set the maindir based on the run_tag from the client
set_maindir() {
    local run_tag=$1
    maindir="${BASE_SERVER_OUTPUT_DIR}/${total_sockets}s-c${cores_per_socket}-vu64-${run_tag}"
    mkdir -p "${maindir}"
    echo "Server output directory set to: ${maindir}"
}

# Function to check if a command exists
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Command '$cmd' not found. Please install it to collect metrics."
        return 1
    fi
    return 0
}

# Initialize monitoring tools availability
initialize_monitoring_status() {
    MONITORING_ENABLED=true
    if ! check_command "mpstat"; then MONITORING_ENABLED=false; fi
    if ! check_command "iostat"; then MONITORING_ENABLED=false; fi
    if ! check_command "sar"; then MONITORING_ENABLED=false; fi
    if ! check_command "perf"; then MONITORING_ENABLED=false; fi # Check for perf

    MONITORING_EMON_ENABLED=true
    source /opt/intel/sep/sep_vars.sh
    if ! check_command "emon"; then
        echo "WARNING: 'emon' command not found. Emon collection will be skipped."
        MONITORING_EMON_ENABLED=false
    fi

    if ! $MONITORING_ENABLED; then
        echo "WARNING: One or more core monitoring tools (mpstat, iostat, sar, perf) are missing. Metric collection will be skipped for these."
    fi
}


# Function to start monitoring tools
# These tools run on clientCpuList (on the server host) but target serverCpuList for metrics.
start_monitoring_tools() {
    local benchmark_type=$1 # e.g., oltp_read_only, oltp_write_only, oltp_read_write
    local run_timestamp=$2 # Timestamp from client for consistent log naming
    local monitor_exec_cores=$clientCpuList # Cores on which the monitoring tools themselves will run (on server host)
    local output_dir="${maindir}/metrics" # Dedicated directory for metrics
    mkdir -p "${output_dir}" # Ensure metrics directory exists
    local log_prefix="${output_dir}/metrics_${benchmark_type}_${run_timestamp}"
    source /opt/intel/sep/sep_vars.sh

    echo "Starting monitoring for ${benchmark_type} (tools executing on cores ${monitor_exec_cores}) targeting server cores ${serverCpuList}) at ${run_timestamp}..."

    # mpstat
    if command -v mpstat &> /dev/null && $MONITORING_ENABLED; then
        taskset -c "$monitor_exec_cores" mpstat -P "$serverCpuList" 1 "${MONITOR_DURATION}" > "${log_prefix}_mpstat.log" 2>&1 &
        MONITOR_PIDS["mpstat_${benchmark_type}"]=$!
        echo "  mpstat started (PID: ${MONITOR_PIDS["mpstat_${benchmark_type}"]})"
    fi

    # iostat
    if command -v iostat &> /dev/null && $MONITORING_ENABLED; then
        taskset -c "$monitor_exec_cores" iostat -x 1 "${MONITOR_DURATION}" > "${log_prefix}_iostat.log" 2>&1 &
        MONITOR_PIDS["iostat_${benchmark_type}"]=$!
        echo "  iostat started (PID: ${MONITOR_PIDS["iostat_${benchmark_type}"]})"
    fi

    # sar
    if command -v sar &> /dev/null && $MONITORING_ENABLED; then
        taskset -c "$monitor_exec_cores" sar -P "$serverCpuList" -u -r -b -n DEV 1 "${MONITOR_DURATION}" > "${log_prefix}_sar.log" 2>&1 &
        MONITOR_PIDS["sar_${benchmark_type}"]=$!
        echo "  sar started (PID: ${MONITOR_PIDS["sar_${benchmark_type}"]})"
    fi

    # emon
    if command -v emon &> /dev/null && $MONITORING_EMON_ENABLED; then
        # Explicitly source SEP variables for this command if needed in non-interactive shell
        # This is often necessary for emon to find its libraries/environment.
        sudo -E bash -c "source /opt/intel/sep/sep_vars.sh &> /dev/null && taskset -c \"$monitor_exec_cores\" emon -collect-edp -f \"${log_prefix}_emon.dat\" -i 1 -t \"${MONITOR_DURATION}\" > \"${log_prefix}_emon.log\" 2>&1 & echo \$!" &
        MONITOR_PIDS["emon_${benchmark_type}"]=$(wait) # Capture PID from the subshell
        echo "  emon started (PID: ${MONITOR_PIDS["emon_${benchmark_type}"]})"
    fi

    # perf record
    if command -v perf &> /dev/null && $MONITORING_ENABLED; then
        # Disable NMI watchdog if needed for perf (often helps with sampling stability)
        echo 1 | sudo tee /proc/sys/kernel/nmi_watchdog > /dev/null
        # perf record will run on monitor_exec_cores but profile system-wide (-a) or specific CPUs (-C)
        # -F 99: Sample at 99Hz to avoid lock contention
        # -g: Enable call-graph (stack trace) recording
        # -o: Specify output file for perf.data
        # sleep "${MONITOR_DURATION}": perf record will run for this duration and then exit
        sudo taskset -c "$monitor_exec_cores" perf record -F 99 -C "$serverCpuList" -g -o "${log_prefix}_perf.data" sleep "${MONITOR_DURATION}" > "${log_prefix}_perf_record.log" 2>&1 &
        MONITOR_PIDS["perf_${benchmark_type}"]=$!
        echo "  perf record started (PID: ${MONITOR_PIDS["perf_${benchmark_type}"]})"
    fi
}

# Function to stop monitoring tools
stop_monitoring_tools() {
    local benchmark_type=$1

    echo "Stopping monitoring for ${benchmark_type}..."

    local tools=("mpstat" "iostat" "sar" "perf" "emon")
    local graceful_wait_time=5 # seconds to wait for graceful shutdown

    for tool in "${tools[@]}"; do
        local pid_key="${tool}_${benchmark_type}"
        local pid="${MONITOR_PIDS[$pid_key]}"
        if [[ -n "$pid" ]]; then
            if ps -p "$pid" > /dev/null; then
                echo "  Attempting to stop ${tool} (PID: ${pid})..."
                if [[ "$tool" == "emon" ]]; then
                    sudo emon -stop >/dev/null 2>&1
                    # Give emon a moment to stop gracefully
                    local emon_stop_attempts=$((graceful_wait_time * 2)) # Check every 0.5 seconds
                    local emon_attempt=0
                    while ps -p "$pid" > /dev/null && [ "$emon_attempt" -lt "$emon_stop_attempts" ]; do
                        sleep 0.5
                        emon_attempt=$((emon_attempt + 1))
                    done
                    if ps -p "$pid" > /dev/null; then
                        echo "  Warning: emon (PID: ${pid}) did not stop gracefully. Sending SIGKILL."
                        sudo kill -9 "$pid" >/dev/null 2>&1
                    fi
                elif [[ "$tool" == "perf" ]]; then
                    # perf record with sleep duration should have exited already.
                    # This is a fallback in case it's still running.
                    kill "$pid" >/dev/null 2>&1 # Send SIGTERM
                    # Wait for a short period for graceful shutdown
                    local start_time=$(date +%s)
                    while ps -p "$pid" > /dev/null && (( $(date +%s) - start_time < graceful_wait_time )); do
                        sleep 0.1
                    done
                    if ps -p "$pid" > /dev/null; then
                        echo "  Warning: ${tool} (PID: ${pid}) did not stop gracefully. Sending SIGKILL."
                        sudo kill -9 "$pid" >/dev/null 2>&1
                    fi
                else
                    kill "$pid" >/dev/null 2>&1 # Send SIGTERM
                    # Wait for a short period for graceful shutdown
                    local start_time=$(date +%s)
                    while ps -p "$pid" > /dev/null && (( $(date +%s) - start_time < graceful_wait_time )); do
                        sleep 0.1
                    done

                    if ps -p "$pid" > /dev/null; then
                        echo "  Warning: ${tool} (PID: ${pid}) did not stop gracefully. Sending SIGKILL."
                        kill -9 "$pid" >/dev/null 2>&1
                    fi
                fi
                echo "  ${tool} stopped."
            else
                echo "  ${tool} (PID: ${pid}) already stopped or not found."
            fi
            unset MONITOR_PIDS["$pid_key"] # Remove from array
        fi
    done
}

# Function to generate a my.cnf for a specific instance
generate_my_cnf() {
    local instance_idx=$1
    local config_file="$2"
    local data_dir="$3"
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local socket_file="${MYSQL_SOCKET_PREFIX}/mysqld_${instance_idx}.sock" # For local tools if needed
    local pid_file="${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
    local log_error_file="${data_dir}/mysqld_${instance_idx}.err"
    local general_log_file="${data_dir}/mysqld_${instance_idx}.log"
    local slow_query_log_file="${data_dir}/mysqld_${instance_idx}_slow.log"

    cat <<EOF > "${config_file}"
[mysqld]
# Basic server settings
port=${mysql_port}
# Explicitly enable TCP/IP connections and listen on all interfaces
bind-address=0.0.0.0
skip-networking=0
socket=${socket_file} # Keep for local mysql client if needed on server
pid-file=${pid_file}
datadir=${data_dir}/data
basedir=${MYSQL_BASEDIR}
user=mysql # Ensure mysqld runs as mysql user
mysqlx=0
default_authentication_plugin=mysql_native_password

# Benchmarking only.  To be removed for production configuration.
# innodb_flush_log_at_trx_commit=0 # Consider setting this for benchmarks
# innodb_flush_method=O_DIRECT_NO_FSYNC # Consider setting this for benchmarks
# innodb_doublewrite=0 # Consider setting this for benchmarks

# general
max_connections=4000
table_open_cache=8000
table_open_cache_instances=16
back_log=1500
max_prepared_stmt_count=128000
performance_schema=OFF
innodb_open_files=4000

# buffers
innodb_buffer_pool_size=${bufferPoolSize} # Using the variable directly
innodb_log_buffer_size=64M
innodb_log_file_size=1024M
innodb_buffer_pool_instances=16
innodb_log_files_in_group=32

# Logging
log_error=${log_error_file}
general_log=0
general_log_file=${general_log_file}
slow_query_log=1
slow_query_log_file=${slow_query_log_file}
long_query_time=1


[client]
port=${mysql_port}
socket=${socket_file}
user=root

[mysql]
prompt="MySQL instance ${instance_idx}> "
EOF

    # Set appropriate permissions for the config file
    chmod 600 "${config_file}"
    chown mysql:mysql "${config_file}"
    echo "Server: Generated config for instance ${instance_idx}: ${config_file}"
}

# Function to initialize a single MySQL data directory
initialize_mysql_data_dir() {
    local instance_idx=$1
    local data_dir=$2
    local config_file="$3"
    local error_log_file="${data_dir}/mysqld_init_${instance_idx}.err" # Define error log path for this instance

    echo "Server: Initializing MySQL data directory for instance ${instance_idx} in ${data_dir}/data..."
    mkdir -p "${data_dir}/data"
    chown -R mysql:mysql "${data_dir}" # Ensure mysql user owns data dir before initialization

    # The actual initialization command
    # Redirect output to the instance's specific error log for debugging
    sudo -u mysql "${MYSQLD_PATH}" \
        --defaults-file="${config_file}" \
        --initialize-insecure \
        --datadir="${data_dir}/data" \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_0900_ai_ci \
        --skip-log-bin \
        --default-authentication-plugin=mysql_native_password \
        > "${error_log_file}" 2>&1 # Redirect stdout/stderr to error log

    if [ $? -ne 0 ]; then
        echo "Server: Error initializing data directory for instance ${instance_idx}. Check logs at ${error_log_file}."
        return 1
    fi

    echo "Server: MySQL data directory for instance ${instance_idx} initialized."
    return 0
}


# Function to start a single MySQL instance
start_mysql_instance() {
    local instance_idx=$1
    local server_core_set=${serverCpuCores[$instance_idx]}
    local numa_node=${memNumaNode[$instance_idx]}
    local config_file="$maindir/my_${instance_idx}.cnf"
    local data_dir="${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}"
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local pid_file="${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
    local error_log_file="${data_dir}/mysqld_${instance_idx}.err" # Error log for runtime

    echo "Server: Starting MySQL instance ${instance_idx} on cores ${server_core_set}, NUMA ${numa_node}..."

    # Ensure pidfile directory exists and is owned by mysql user (already done globally, but harmless here)
    sudo mkdir -p "${MYSQL_PIDFILE_PREFIX}"
    sudo chown mysql:mysql "${MYSQL_PIDFILE_PREFIX}"

    # Use numactl for NUMA node binding, taskset for CPU affinity
    # Run mysqld as the 'mysql' user
    sudo numactl -m "$numa_node" -C "$server_core_set" "${MYSQLD_PATH}" \
        --defaults-file="$config_file" \
        --user=mysql \
        > "${error_log_file}" 2>&1 & # Redirect output to error log, run in background

    echo "Server: MySQL instance ${instance_idx} started with PID $!"
    echo "$!" > "$maindir/${servernameprefix}_${instance_idx}.pid" # Store PID for later waiting

    # Wait for the PID file to appear, indicating mysqld started
    local max_attempts=30
    local attempt=0
    while [ ! -f "${pid_file}" ] && [ "$attempt" -lt "$max_attempts" ]; do
        sleep 2
        attempt=$((attempt + 1))
    done
    if [ ! -f "${pid_file}" ]; then
        echo "Server: ERROR: mysqld PID file for instance ${instance_idx} not found. Check logs: ${error_log_file}"
        return 1
    fi
    return 0
}

# Function to wait for a MySQL instance to be ready (server side)
wait_for_mysql_server_ready() {
    local instance_idx=$1
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local max_attempts=12 # 12 * 5 seconds = 1 minute timeout
    local attempt=0

    echo "Server: Waiting for MySQL instance ${instance_idx} on port ${mysql_port} to be ready..."
    while ! "${MYSQL_CLIENT_PATH}" -h 127.0.0.1 -P "${mysql_port}" -u root -e "SELECT 1;" >/dev/null 2>&1; do
        sleep 5
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Server: Error: MySQL instance ${instance_idx} did not become ready after ${max_attempts} attempts."
            echo "Server: Check its error log: ${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}/mysqld_${instance_idx}.err"
            return 1
        fi
        echo "Server: Attempt $attempt: Waiting for MySQL instance ${instance_idx}..."
    done
    echo "Server: MySQL instance ${instance_idx} is ready."
    return 0
}

# Function to grant remote access to the root user
grant_root_remote_access() {
    local instance_idx=$1
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local config_file="$maindir/my_${instance_idx}.cnf"

    echo "Server: Granting remote access to 'root' user for instance ${instance_idx}..."
    "${MYSQL_CLIENT_PATH}" --defaults-file="${config_file}" -h 127.0.0.1 -P "${mysql_port}" -u root -e "
        -- Drop existing root@'%' if it exists to ensure clean state
        DROP USER IF EXISTS 'root'@'%';
        -- Create root user with remote access from any host ('%')
        CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
        -- Grant all privileges to the root user from any host
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
    "
    if [ $? -ne 0 ]; then
        echo "Server: Error granting remote access to 'root' user for instance ${instance_idx}."
        return 1
    fi
    echo "Server: 'root'@'%' access granted for instance ${instance_idx}."
    return 0
}


# Function to stop a single MySQL instance
stop_mysql_instance() {
    local instance_idx=$1
    local config_file="$maindir/my_${instance_idx}.cnf"
    local pid_file="${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"

    echo "Server: Stopping MySQL instance ${instance_idx}..."
    # Check if PID file exists and process is running
    if [ -f "${pid_file}" ]; then
        local pid=$(cat "${pid_file}")
        if ps -p "$pid" > /dev/null; then
            echo "Server: Attempting graceful shutdown for instance ${instance_idx} (PID: ${pid})..."
            # Use mysql client to send SHUTDOWN command (connecting locally)
            "${MYSQL_CLIENT_PATH}" --defaults-file="${config_file}" -h 127.0.0.1 -P $((MYSQL_PORT_BASE + instance_idx)) -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHUTDOWN;" >/dev/null 2>&1

            # Wait for the PID file to disappear
            local max_attempts=1
            local attempt=0
            while [ -f "${pid_file}" ] && [ "$attempt" -lt "$max_attempts" ]; do
                sleep 1
                attempt=$((attempt + 1))
            done

            if [ -f "${pid_file}" ]; then
                echo "Server: Warning: MySQL instance ${instance_idx} did not stop cleanly (PID file still exists). Sending SIGTERM."
                sudo kill "$pid" >/dev/null 2>&1
                sleep 5
                if [ -f "${pid_file}" ]; then
                    echo "Server: Warning: MySQL instance ${instance_idx} still running. Sending SIGKILL."
                    sudo kill -9 "$pid" >/dev/null 2>&1
                fi
            else
                echo "Server: MySQL instance ${instance_idx} gracefully shut down."
            fi
        else
            echo "Server: PID file ${pid_file} exists, but process ${pid} is not running. Cleaning up PID file."
            rm -f "${pid_file}"
        fi
    else
        echo "Server: PID file ${pid_file} not found for instance ${instance_idx}. Might already be stopped or failed to start."
    fi
}

# Clean up instance data and config files
cleanup_instance_data() {
    local instance_idx=$1
    local config_file="$maindir/my_${instance_idx}.cnf"
    local data_dir="${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}"

    echo "Server: Removing data directory and config file for instance ${instance_idx}..."
    sudo rm -rf "${data_dir}"
    rm -f "${config_file}"
    rm -f "${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
}

# Wait for background processes and check their status
wait_for_processes() {
    local process_name=$1
    local -n pids_array=$2 # Use nameref to pass array by reference
    local all_success=true

    echo "Server: Waiting for all ${process_name} processes to complete..."
    for pid in "${pids_array[@]}"; do
        if ! wait "$pid"; then
            echo "Server: WARNING: ${process_name} process ${pid} failed or had non-zero exit."
            all_success=false
        fi
    done

    if ! $all_success; then
        echo "Server: ERROR: One or more ${process_name} processes failed. Check logs."
        return 1
    fi
    return 0
}

# Function to generate flamegraph reports from perf.data files - called remotely via SSH
generate_flamegraph_report() {
    local run_timestamp=$1 # Timestamp from client for consistent log naming
    local output_dir="${maindir}/metrics" # Metrics directory on server

    echo "Server: --- Generating Flamegraph Reports for run ${run_timestamp} ---"

    if [ -z "$FLAMEGRAPH_PATH" ] || [ ! -d "$FLAMEGRAPH_PATH" ]; then
        echo "Server: ERROR: FLAMEGRAPH_PATH is not set or invalid. Cannot generate flamegraphs."
        echo "Server: Please set FLAMEGRAPH_PATH to your FlameGraph directory (e.g., /opt/FlameGraph)."
        return 1
    fi

    if ! command -v perf &> /dev/null; then
        echo "Server: WARNING: 'perf' command not found. Cannot generate flamegraphs."
        return 1
    fi

    if [ ! -f "${FLAMEGRAPH_PATH}/stackcollapse-perf.pl" ] || [ ! -f "${FLAMEGRAPH_PATH}/flamegraph.pl" ]; then
        echo "Server: WARNING: FlameGraph scripts (stackcollapse-perf.pl or flamegraph.pl) not found in ${FLAMEGRAPH_PATH}."
        echo "Server: Please ensure FlameGraph repository is cloned and FLAMEGRAPH_PATH points to it."
        return 1
    fi

    local benchmark_types=("oltp_read_only" "oltp_write_only" "oltp_read_write")

    for btype in "${benchmark_types[@]}"; do
        local perf_data_file="${output_dir}/metrics_${btype}_${run_timestamp}_perf.data"
        local folded_file="${output_dir}/metrics_${btype}_${run_timestamp}_out.perf-folded"
        local svg_file="${output_dir}/metrics_${btype}_${run_timestamp}_perf-kernel.svg"

        if [[ -f "$perf_data_file" ]]; then
            echo "Server:   Generating flamegraph for server, type ${btype}..."
            # Change to flamegraph directory to run scripts
            (cd "$FLAMEGRAPH_PATH" && \
             sudo perf script -i "$perf_data_file" | "./stackcollapse-perf.pl" > "$folded_file" && \
             "./flamegraph.pl" "$folded_file" > "$svg_file")
            
            if [ $? -eq 0 ]; then
                echo "Server:     Generated: $svg_file"
            else
                echo "Server:     ERROR: Failed to generate flamegraph for server, type ${btype}. Check logs."
            fi
        else
            echo "Server:   perf.data file not found for server, type ${btype}: $perf_data_file"
        fi
    done
    echo "Server: --- Flamegraph Report Generation Complete ---"
}


# --- Main Execution Logic for Server Script ---
# This allows the script to be called with specific commands from the client.

# Initialize monitoring tool availability checks
initialize_monitoring_status

# Ensure necessary directories for MySQL PID/Socket files exist and have correct permissions
# This is done here as part of the server management script's initialization,
# as these are global system paths needed by MySQL.
sudo mkdir -p $MYSQL_PIDFILE_PREFIX
sudo chown mysql:mysql $MYSQL_PIDFILE_PREFIX
sudo mkdir -p $MYSQL_SOCKET_PREFIX
sudo chown mysql:mysql $MYSQL_SOCKET_PREFIX


case "$1" in
    "set_run_tag")
        set_maindir "$2"
        ;;
    "cleanup_all_server")
        set_maindir "$2" # Need run_tag to find maindir for cleanup
        echo "Server: Performing initial cleanup for run tag '$2'..."
        # Clean up all files related to the run tag in the maindir
        rm -rf "${maindir}"/*.pid "${maindir}"/*.log "${maindir}"/*.dat "${maindir}"/*.perf.data "${maindir}"/*.perf-folded "${maindir}"/*.svg
        rm -rf "${maindir}/metrics" # Clean up metrics directory
        for i in "${!serverCpuCores[@]}"; do
            data_dir="${mntdir[$i]}/${MYSQL_DATADIR_PREFIX}_${i}"
            echo "Server: Stopping and cleaning up potential leftover MySQL instance ${i}..."
            stop_mysql_instance "$i" # Attempt to stop any running instances
            sudo rm -rf "${data_dir}/data" # Clean data directory
            rm -f "${maindir}/my_${i}.cnf" # Explicitly remove old config files
        done
        echo "Server: Initial cleanup complete."
        ;;
    "init_and_start_mysql")
        set_maindir "$2" # run_tag
        echo "Server: Generating my.cnf files and initializing MySQL data directories..."
        declare -a init_pids
        for i in "${!serverCpuCores[@]}"; do
            config_file="$maindir/my_${i}.cnf"
            data_dir="${mntdir[$i]}/${MYSQL_DATADIR_PREFIX}_${i}"
            generate_my_cnf "$i" "${config_file}" "${data_dir}"
            initialize_mysql_data_dir "$i" "${data_dir}" "${config_file}" &
            init_pids+=("$!")
        done
        wait_for_processes "MySQL initialization" init_pids || exit 1

        echo "Server: Starting all MySQL instances..."
        declare -a mysqld_start_pids
        for i in "${!serverCpuCores[@]}"; do
            start_mysql_instance "$i" &
            mysqld_start_pids+=("$!")
        done
        wait_for_processes "mysqld launch" mysqld_start_pids || exit 1
        echo "Server: All mysqld processes have launched."

        echo "Server: Waiting for all MySQL instances to become ready and granting root remote access..."
        declare -a wait_db_pids
        for i in "${!serverCpuCores[@]}"; do
            # Wait for instance to be ready first
            wait_for_mysql_server_ready "$i" &
            wait_db_pids+=("$!")
        done
        wait_for_processes "MySQL server readiness" wait_db_pids || exit 1

        # Now grant root remote access for each instance
        declare -a grant_root_pids
        for i in "${!serverCpuCores[@]}"; do
            grant_root_remote_access "$i" &
            grant_root_pids+=("$!")
        done
        wait_for_processes "Root remote access grant" grant_root_pids || exit 1
        echo "Server: All MySQL instances are ready and 'root'@'%' access has been granted."
        ;;
    "start_monitoring")
        set_maindir "$3" # run_tag
        # The curr_datetime needs to be consistent, so pass it from client
        curr_datetime="$4" # Set curr_datetime for this execution context
        start_monitoring_tools "$2" "$curr_datetime" # benchmark_type, run_timestamp
        ;;
    "stop_monitoring")
        set_maindir "$3" # run_tag
        # The curr_datetime needs to be consistent, so pass it from client
        curr_datetime="$4" # Set curr_datetime for this execution context
        stop_monitoring_tools "$2" # benchmark_type
        ;;
    "generate_flamegraph")
        set_maindir "$2" # run_tag
        # The curr_datetime needs to be consistent, so pass it from client
        curr_datetime="$3" # Set curr_datetime for this execution context
        generate_flamegraph_report "$curr_datetime" # run_timestamp
        ;;
    "stop_and_cleanup_mysql")
        set_maindir "$2" # run_tag
        echo "Server: Stopping and removing all MySQL instances and their data..."
        declare -a stop_pids
        for i in "${!serverCpuCores[@]}"; do
            stop_mysql_instance "$i" &
            stop_pids+=("$!")
        done
        wait_for_processes "MySQL stop" stop_pids
        echo "Server: All MySQL instances stopped."

        for i in "${!serverCpuCores[@]}"; do
            cleanup_instance_data "$i"
        done
        echo "Server: MySQL data cleanup complete."
        ;;
    *)
        echo "Usage: $0 {set_run_tag <run_tag> | cleanup_all_server <run_tag> | init_and_start_mysql <run_tag> | start_monitoring <benchmark_type> <run_tag> <run_timestamp> | stop_monitoring <benchmark_type> <run_tag> <run_timestamp> | generate_flamegraph <run_tag> <run_timestamp> | stop_and_cleanup_mysql <run_tag>}"
        exit 1
        ;;
esac
