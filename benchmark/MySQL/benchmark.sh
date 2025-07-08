#!/bin/bash
curr_datetime=`date '+%Y%m%d%H%M%S'`

# --- Hardware Information ---
threads_per_core=$(lscpu | awk '/Thread\(s\) per core:/{print $NF}')
total_sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
cores_per_socket=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
total_numa_nodes=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')
numa_per_socket=$((total_numa_nodes/total_sockets))
physical_cores_per_numa=$(( $cores_per_socket / $(( ${total_numa_nodes} / ${total_sockets} )) ))

# --- Benchmark Configuration ---
maindir="RunOutput/${total_sockets}s-c${cores_per_socket}-vu64-$1"
mkdir -p ${maindir}

servernameprefix="mysqld_instance"
clientnameprefix="sysbench_client"
warehouse=100
vu=64
memSize="16G"
bufferPoolSize="8G"

# --- Core/NUMA Assignments ---
clientNumaNode=("1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1" "1")
clientCpuCores=("96-99,288-291" "100-103,292-295" "104-107,296-299" "108-111,300-303" "112-115,304-307" "116-119,308-311" "120-123,312-315" "124-127,316-319" "128-131,320-323" "132-135,324-327" "136-139,328-331" "140-143,332-335" "144-147,336-339" "148-151,340-343" "152-155,344-347" "156-159,348-351" "160-163,352-355" "164-167,356-359" "168-171,360-363" "172-175,364-367" "176-179,368-371" "180-183,372-375" "184-187,376-379" "188-191,380-383")

memNumaNode=("0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0" "0")
mntdir=("/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data1" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2" "/mnt/data2")
serverCpuCores=("0-3,192-195" "4-7,196-199" "8-11,200-203" "12-15,204-207" "16-19,208-211" "20-23,212-215" "24-27,216-219" "28-31,220-223" "32-35,224-227" "36-39,228-231" "40-43,232-235" "44-47,236-239" "48-51,240-243" "52-55,244-247" "56-59,248-251" "60-63,252-255" "64-67,256-259" "68-71,260-263" "72-75,264-267" "76-79,268-271" "80-83,272-275" "84-87,276-279" "88-91,280-283" "92-95,284-287")

serverCpuList="0-95,192-287"
clientCpuList="96-191,288-383"

# --- Global Variables for MySQL & Sysbench ---
MYSQL_ROOT_PASSWORD="MyNewPass4!"
MYSQL_BENCH_USER="sbtest"
MYSQL_BENCH_PASSWORD="sysbench_password"
MYSQL_DATABASE="sbtest"
MYSQL_PORT_BASE=13060
MYSQL_BASEDIR="/usr"
MYSQL_DATADIR_PREFIX="mysql_data"
MYSQL_PIDFILE_PREFIX="/var/run/mysqld"
MYSQL_SOCKET_PREFIX="/var/run/mysqld"
MYSQL_RAND_TYPE="uniform"

MYSQLD_PATH="${MYSQL_BASEDIR}/sbin/mysqld"
MYSQL_CLIENT_PATH="${MYSQL_BASEDIR}/bin/mysql"

sudo mkdir -p $MYSQL_PIDFILE_PREFIX
sudo mkdir -p $MYSQL_SOCKET_PREFIX
sudo chown mysql:mysql $MYSQL_PIDFILE_PREFIX
sudo chown mysql:mysql $MYSQL_SOCKET_PREFIX

SYSBENCH_SCRIPT="/usr/share/sysbench/oltp_read_write.lua"
SYSBENCH_TABLES=16
SYSBENCH_TABLE_SIZE=1000000
SYSBENCH_TIME=60
SYSBENCH_REPORT_INTERVAL=10

# --- Monitoring Configuration ---
MONITOR_DURATION=20
declare -A MONITOR_PIDS

# --- Functions ---

# Function to check if a command exists
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Command '$cmd' not found. Please install it to collect metrics."
        return 1
    fi
    return 0
}

# Initialize monitoring tools
initialize_monitoring() {
    MONITORING_ENABLED=true
    if ! check_command "mpstat"; then MONITORING_ENABLED=false; fi
    if ! check_command "iostat"; then MONITORING_ENABLED=false; fi
    if ! check_command "sar"; then MONITORING_ENABLED=false; fi

    MONITORING_EMON_ENABLED=true
    if ! check_command "emon"; then
        echo "WARNING: 'emon' command not found. Emon collection will be skipped."
        MONITORING_EMON_ENABLED=false
    fi

    if ! $MONITORING_ENABLED; then
        echo "WARNING: One or more core monitoring tools are missing. Metric collection will be skipped for these."
    fi
}

# Start monitoring tools
start_monitoring_tools() {
    local benchmark_type=$1
    local monitor_exec_cores=$clientCpuList
    output_dir="./metrics"
    mkdir -p ${output_dir}
    local log_prefix="${output_dir}/metrics_${benchmark_type}_${curr_datetime}"

    echo "Starting monitoring for ${benchmark_type} (tools executing on cores ${monitor_exec_cores})..."

    # mpstat
    if command -v mpstat &> /dev/null && $MONITORING_ENABLED; then
        taskset -c "$monitor_exec_cores" mpstat -P $serverCpuList 1 "${MONITOR_DURATION}" > "${log_prefix}_mpstat.log" 2>&1 &
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
        taskset -c "$monitor_exec_cores" sar -P $serverCpuList -u -r -b -n DEV 1 "${MONITOR_DURATION}" > "${log_prefix}_sar.log" 2>&1 &
        MONITOR_PIDS["sar_${benchmark_type}"]=$!
        echo "  sar started (PID: ${MONITOR_PIDS["sar_${benchmark_type}"]})"
    fi

    # perf
    if command -v perf &> /dev/null && $MONITORING_ENABLED; then
        echo 1 > /proc/sys/kernel/nmi_watchdog
        taskset -c "$monitor_exec_cores" perf record -C $serverCpuList -a -g -o "${log_prefix}_perf.data" -- sleep $interval 2>&1 &
        MONITOR_PIDS["perf_${benchmark_type}"]=$!
        echo "  perf started (PID: ${MONITOR_PIDS["perf_${benchmark_type}"]})"
    fi

    # emon
    source /opt/intel/sep/sep_vars.sh
    if command -v emon &> /dev/null && $MONITORING_EMON_ENABLED; then
        taskset -c "$monitor_exec_cores" emon -collect-edp -f "${log_prefix}_emon.dat" > "${log_prefix}_emon.log" 2>&1 &
        MONITOR_PIDS["emon_${benchmark_type}"]=$!
        echo "  emon started (PID: ${MONITOR_PIDS["emon_${benchmark_type}"]})"
    fi
}

# Stop monitoring tools
stop_monitoring_tools() {
    local benchmark_type=$1
    echo "Stopping monitoring for ${benchmark_type}..."

    local tools=("mpstat" "iostat" "sar" "emon" "perf")
    local graceful_wait_time=5

    for tool in "${tools[@]}"; do
        local pid_key="${tool}_${benchmark_type}"
        local pid="${MONITOR_PIDS[$pid_key]}"
        if [[ -n "$pid" ]]; then
            if ps -p "$pid" > /dev/null; then
                echo "  Attempting to stop ${tool} (PID: ${pid})..."
                if [[ "$tool" == "emon" ]]; then
                    sudo emon -stop >/dev/null 2>&1
                    local emon_stop_attempts=$((graceful_wait_time * 2))
                    local emon_attempt=0
                    while ps -p "$pid" > /dev/null && [ "$emon_attempt" -lt "$emon_stop_attempts" ]; do
                        sleep 0.5
                        emon_attempt=$((emon_attempt + 1))
                    done
                    if ps -p "$pid" > /dev/null; then
                        echo "  Warning: emon (PID: ${pid}) did not stop gracefully. Sending SIGKILL."
                        sudo kill -9 "$pid" >/dev/null 2>&1
                    fi
                else
                    kill "$pid" >/dev/null 2>&1
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
            unset MONITOR_PIDS["$pid_key"]
        fi
    done
}

# Generate MySQL configuration file
generate_my_cnf() {
    local instance_idx=$1
    local config_file="$2"
    local data_dir="$3"
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local socket_file="${MYSQL_SOCKET_PREFIX}/mysqld_${instance_idx}.sock"
    local pid_file="${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
    local log_error_file="${data_dir}/mysqld_${instance_idx}.err"
    local general_log_file="${data_dir}/mysqld_${instance_idx}.log"
    local slow_query_log_file="${data_dir}/mysqld_${instance_idx}_slow.log"

    cat <<EOF > "${config_file}"
[mysqld]
port=${mysql_port}
socket=${socket_file}
pid-file=${pid_file}
datadir=${data_dir}/data
basedir=${MYSQL_BASEDIR}
user=mysql
mysqlx=0
default_authentication_plugin=mysql_native_password

max_connections=4000
table_open_cache=8000
table_open_cache_instances=16
back_log=1500
max_prepared_stmt_count=128000
performance_schema=OFF
innodb_open_files=4000

innodb_buffer_pool_size=${bufferPoolSize}
innodb_log_buffer_size=64M
innodb_log_file_size=1024M
innodb_buffer_pool_instances=16
innodb_log_files_in_group=32

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

    chmod 600 "${config_file}"
    chown mysql:mysql "${config_file}"
    echo "Generated config for instance ${instance_idx}: ${config_file}"
}

# Initialize MySQL data directory
initialize_mysql_data_dir() {
    local instance_idx=$1
    local data_dir=$2
    local config_file="$3"
    local error_log_file="${data_dir}/mysqld_init_${instance_idx}.err"

    echo "Initializing MySQL data directory for instance ${instance_idx} in ${data_dir}/data..."
    mkdir -p "${data_dir}/data"
    chown -R mysql:mysql "${data_dir}"

    sudo -u mysql "${MYSQLD_PATH}" \
        --defaults-file="${config_file}" \
        --initialize-insecure \
        --datadir="${data_dir}/data" \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_0900_ai_ci \
        --skip-log-bin \
        --default-authentication-plugin=mysql_native_password \
        > "${error_log_file}" 2>&1

    if [ $? -ne 0 ]; then
        echo "Error initializing data directory for instance ${instance_idx}. Check logs at ${error_log_file}."
        return 1
    fi

    echo "MySQL data directory for instance ${instance_idx} initialized."
    return 0
}

# Start MySQL instance
start_mysql_instance() {
    local instance_idx=$1
    local server_core_set=${serverCpuCores[$instance_idx]}
    local numa_node=${memNumaNode[$instance_idx]}
    local config_file="$maindir/my_${instance_idx}.cnf"
    local data_dir="${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}"
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local pid_file="${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
    local error_log_file="${data_dir}/mysqld_${instance_idx}.err"

    echo "Starting MySQL instance ${instance_idx} on cores ${server_core_set}, NUMA ${numa_node}..."

    sudo mkdir -p "${MYSQL_PIDFILE_PREFIX}"
    sudo chown mysql:mysql "${MYSQL_PIDFILE_PREFIX}"

    sudo numactl -m "$numa_node" -C "$server_core_set" "${MYSQLD_PATH}" \
        --defaults-file="$config_file" \
        --user=mysql \
        > "${error_log_file}" 2>&1 &

    echo "MySQL instance ${instance_idx} started with PID $!"
    echo "$!" > "$maindir/${servernameprefix}_${instance_idx}.pid"

    local max_attempts=30
    local attempt=0
    while [ ! -f "${pid_file}" ] && [ "$attempt" -lt "$max_attempts" ]; do
        sleep 2
        attempt=$((attempt + 1))
    done
    if [ ! -f "${pid_file}" ]; then
        echo "ERROR: mysqld PID file for instance ${instance_idx} not found. Check logs: ${error_log_file}"
        return 1
    fi
    return 0
}

# Wait for MySQL to be ready and setup benchmark user
wait_for_mysql() {
    local instance_idx=$1
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local config_file="$maindir/my_${instance_idx}.cnf"
    local max_attempts=5
    local attempt=0

    echo "Waiting for MySQL instance ${instance_idx} on port ${mysql_port} to be ready and setting up user/db..."
    
    cmd="${MYSQL_CLIENT_PATH} --defaults-file=${config_file} -h 127.0.0.1 -P ${mysql_port} -u root -e \"SELECT 1;\" >/dev/null 2>&1;"
    echo $cmd
    eval $cmd
    ret=$?
    
    while [ "${ret}" -ne 0 ]; do
        sleep 5
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Error: MySQL instance ${instance_idx} did not become ready after ${max_attempts} attempts."
            echo "Check its error log: ${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}/mysqld_${instance_idx}.err"
            return 1
        fi
        echo "Attempt $attempt: Waiting for MySQL instance ${instance_idx}..."
    done
    
    echo "MySQL instance ${instance_idx} is ready. Creating benchmark user and database..."

    "${MYSQL_CLIENT_PATH}" --defaults-file="${config_file}" -h 127.0.0.1 -P "${mysql_port}" -u root -e "
        CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
        CREATE USER IF NOT EXISTS '${MYSQL_BENCH_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_BENCH_PASSWORD}';
        GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_BENCH_USER}'@'localhost';
        FLUSH PRIVILEGES;
    "
    
    if [ $? -ne 0 ]; then
        echo "Error setting up user/db for instance ${instance_idx}."
        echo "Check its error log: ${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}/mysqld_${instance_idx}.err"
        return 1
    fi
    
    echo "Benchmark user and database created for instance ${instance_idx}."
    return 0
}

# Run sysbench operation (prepare, run, cleanup)
run_sysbench_operation() {
    local instance_idx=$1
    local operation=$2
    local sysbench_type=${3:-""}
    local client_core_set=${clientCpuCores[$instance_idx]}
    local mysql_port=$((MYSQL_PORT_BASE + instance_idx))
    local client_name="${clientnameprefix}_${instance_idx}"
    local log_file="$maindir/${client_name}_${operation}.log"
    
    if [[ "$operation" == "run" ]]; then
        log_file="$maindir/${client_name}_${sysbench_type}_benchmark.log"
    fi

    echo "Running Sysbench ${operation} for MySQL instance ${instance_idx} on client cores ${client_core_set} port ${mysql_port}..."
    
    local cmd="taskset -c \"${client_core_set}\" sysbench"
    
    if [[ "$operation" == "run" ]]; then
        cmd+=" ${sysbench_type}"
    else
        cmd+=" ${SYSBENCH_SCRIPT}"
    fi
    
    cmd+=" --db-driver=mysql"
    cmd+=" --mysql-host=127.0.0.1"
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
    
    echo "Sysbench ${operation} for instance ${instance_idx} started with PID $pid"
}

# Stop MySQL instance
stop_mysql_instance() {
    local instance_idx=$1
    local config_file="$maindir/my_${instance_idx}.cnf"
    local pid_file="${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
    local error_log_file="${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}/mysqld_${instance_idx}.err"

    echo "Stopping MySQL instance ${instance_idx}..."
    
    if [ -f "${pid_file}" ]; then
        local pid=$(cat "${pid_file}")
        if ps -p "$pid" > /dev/null; then
            echo "Attempting graceful shutdown for instance ${instance_idx} (PID: ${pid})..."
            "${MYSQL_CLIENT_PATH}" --defaults-file="${config_file}" -h 127.0.0.1 -P $((MYSQL_PORT_BASE + instance_idx)) -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHUTDOWN;" >/dev/null 2>&1

            local max_attempts=3
            local attempt=0
            while [ -f "${pid_file}" ] && [ "$attempt" -lt "$max_attempts" ]; do
                sleep 2
                attempt=$((attempt + 1))
            done

            if [ -f "${pid_file}" ]; then
                echo "Warning: MySQL instance ${instance_idx} did not stop cleanly. Sending SIGTERM."
                sudo kill "$pid" >/dev/null 2>&1
                sleep 5
                if [ -f "${pid_file}" ]; then
                    echo "Warning: MySQL instance ${instance_idx} still running. Sending SIGKILL."
                    sudo kill -9 "$pid" >/dev/null 2>&1
                fi
            else
                echo "MySQL instance ${instance_idx} gracefully shut down."
            fi
        else
            echo "PID file ${pid_file} exists, but process ${pid} is not running. Cleaning up PID file."
            rm -f "${pid_file}"
        fi
    else
        echo "PID file ${pid_file} not found for instance ${instance_idx}. Might already be stopped or failed to start."
    fi
}

# Clean up instance data and config files
cleanup_instance() {
    local instance_idx=$1
    local config_file="$maindir/my_${instance_idx}.cnf"
    local data_dir="${mntdir[$instance_idx]}/${MYSQL_DATADIR_PREFIX}_${instance_idx}"

    echo "Removing data directory and config file for instance ${instance_idx}..."
    sudo rm -rf "${data_dir}"
    rm -f "${config_file}"
    rm -f "${MYSQL_PIDFILE_PREFIX}/mysqld_${instance_idx}.pid"
}

# Wait for background processes and check their status
wait_for_processes() {
    local process_name=$1
    local pids=("${!2}")
    local all_success=true

    echo "Waiting for all ${process_name} processes to complete..."
    wait "${pids[@]}"
    
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            echo "WARNING: ${process_name} process ${pid} failed or had non-zero exit."
            all_success=false
        fi
    done

    if ! $all_success; then
        echo "ERROR: One or more ${process_name} processes failed. Check logs."
        return 1
    fi
    return 0
}

# Run benchmark for a specific type
run_benchmark() {
    local benchmark_type=$1
    declare -a run_pids

    echo "Starting all Sysbench benchmark ${benchmark_type} runs..."
    for i in "${!serverCpuCores[@]}"; do
        run_sysbench_operation "$i" "run" "$benchmark_type"
        run_pids+=($(cat "$maindir/${clientnameprefix}_${i}_run.pid"))
    done

    sleep 5
    if $MONITORING_ENABLED; then
        start_monitoring_tools "$benchmark_type"
    fi

    if $MONITORING_ENABLED; then
        echo "Waiting ${MONITOR_DURATION} seconds to stop monitoring for ${benchmark_type}..."
        sleep "${MONITOR_DURATION}"
        stop_monitoring_tools "$benchmark_type"
    fi

    echo "Waiting for all Sysbench benchmark ${benchmark_type} runs to complete..."
    wait_for_processes "${benchmark_type}" run_pids[@]
}

# Gather sysbench results
gather_sysbench_results() {
    echo "--- Benchmark Results Summary ---"
    local benchmark_types=("oltp_read_only" "oltp_write_only" "oltp_read_write")

    for i in "${!serverCpuCores[@]}"; do
        local instance_idx=$i
        local client_name="${clientnameprefix}_${instance_idx}"
        echo "Results for ${client_name} (MySQL instance ${instance_idx}):"
        echo "--------------------------------------------------------------------"

        for btype in "${benchmark_types[@]}"; do
            local log_file="$maindir/${client_name}_${btype}_benchmark.log"

            echo "  Type: ${btype}"
            if [[ -f "$log_file" ]]; then
                local transactions_line=$(grep "transactions:" "$log_file" | tail -1)
                local queries_line=$(grep "queries:" "$log_file" | tail -1)
                local events_per_second_line=$(grep "events/s (eps):" "$log_file" | tail -1)
                local min_latency_line=$(grep -E "^\s*min:" "$log_file" | tail -1)
                local avg_latency_line=$(grep -E "^\s*avg:" "$log_file" | tail -1)
                local max_latency_line=$(grep -E "^\s*max:" "$log_file" | tail -1)
                local p95_latency_line=$(grep -E "^\s*95th percentile:" "$log_file" | tail -1)

                [[ -n "$transactions_line" ]] && echo "    Transactions: ${transactions_line}" || echo "    Transactions: N/A"
                [[ -n "$queries_line" ]] && echo "    Queries: ${queries_line}" || echo "    Queries: N/A"
                [[ -n "$events_per_second_line" ]] && echo "    Events/s: ${events_per_second_line}" || echo "    Events/s: N/A"
                
                echo "    Latency (ms):"
                [[ -n "$min_latency_line" ]] && echo "      ${min_latency_line}" || echo "      min: N/A"
                [[ -n "$avg_latency_line" ]] && echo "      ${avg_latency_line}" || echo "      avg: N/A"
                [[ -n "$max_latency_line" ]] && echo "      ${max_latency_line}" || echo "      max: N/A"
                [[ -n "$p95_latency_line" ]] && echo "      ${p95_latency_line}" || echo "      95th percentile: N/A"
            else
                echo "    Log file not found: $log_file"
            fi
            echo "  ---"
        done
        echo "--------------------------------------------------------------------"
    done
}

# --- Main Script Execution ---

initialize_monitoring
mkdir -p "$maindir"

echo "--- Starting MySQL Benchmarking Setup ---"
echo "Main output directory: $maindir"
echo "Total MySQL instances: ${#serverCpuCores[@]}"
echo "Virtual Users per client: ${vu}"
echo "Benchmark duration: ${SYSBENCH_TIME} seconds"

# Clean up from previous runs
echo "Cleaning up any old PIDs, logs, and ensuring data directories are clear..."
rm -rf "$maindir"/*.pid "$maindir"/*.log

for i in "${!serverCpuCores[@]}"; do
    data_dir="${mntdir[$i]}/${MYSQL_DATADIR_PREFIX}_${i}"
    echo "Stopping and cleaning up potential leftover MySQL instance ${i}..."
    stop_mysql_instance "$i"
    sudo rm -rf "${data_dir}/data"
    rm -f "$maindir/my_${i}.cnf"
done

# Initialize MySQL instances
echo "Generating my.cnf files and initializing MySQL data directories..."
declare -a init_pids
for i in "${!serverCpuCores[@]}"; do
    config_file="$maindir/my_${i}.cnf"
    data_dir="${mntdir[$i]}/${MYSQL_DATADIR_PREFIX}_${i}"

    generate_my_cnf "$i" "${config_file}" "${data_dir}"
    initialize_mysql_data_dir "$i" "${data_dir}" "${config_file}" &
    init_pids+=("$!")
done

wait_for_processes "MySQL initialization" init_pids[@] || exit 1

# Start MySQL instances
echo "Starting all MySQL instances..."
declare -a mysqld_start_pids
for i in "${!serverCpuCores[@]}"; do
    start_mysql_instance "$i" &
    mysqld_start_pids+=("$!")
done

wait "${mysqld_start_pids[@]}"
echo "All mysqld processes have launched."

# Wait for MySQL instances to be ready
echo "Waiting for all MySQL instances to become ready and setting up bench user/db..."
declare -a wait_db_pids
for i in "${!serverCpuCores[@]}"; do
    wait_for_mysql "$i" &
    wait_db_pids+=("$!")
done

wait_for_processes "MySQL readiness check" wait_db_pids[@] || exit 1
echo "All MySQL instances are ready and configured."

export LUA_PATH="/usr/local/share/sysbench/?.lua;;"

# Prepare Sysbench data
echo "Preparing Sysbench data for all instances..."
declare -a prepare_pids
for i in "${!serverCpuCores[@]}"; do
    run_sysbench_operation "$i" "prepare"
    prepare_pids+=($(cat "$maindir/${clientnameprefix}_${i}_prepare.pid"))
done

wait_for_processes "Sysbench prepare" prepare_pids[@] || exit 1
echo "All Sysbench data prepared."

# Run benchmarks
run_benchmark "oltp_read_only"
run_benchmark "oltp_write_only"
run_benchmark "oltp_read_write"

# Gather and display results
gather_sysbench_results

# Clean up Sysbench data
echo "Cleaning up Sysbench data from all instances..."
declare -a cleanup_pids
for i in "${!serverCpuCores[@]}"; do
    run_sysbench_operation "$i" "cleanup"
    cleanup_pids+=($(cat "$maindir/${clientnameprefix}_${i}_cleanup.pid"))
done

wait_for_processes "Sysbench cleanup" cleanup_pids[@]
echo "All Sysbench data cleaned up."

# Stop and remove MySQL instances
echo "Stopping and removing all MySQL instances and their data..."
declare -a stop_pids
for i in "${!serverCpuCores[@]}"; do
    stop_mysql_instance "$i" &
    stop_pids+=("$!")
done

wait "${stop_pids[@]}"
echo "All MySQL instances stopped."

# Clean up data directories and config files
for i in "${!serverCpuCores[@]}"; do
    cleanup_instance "$i"
done

echo "--- Benchmarking Complete ---"
