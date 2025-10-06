#!/bin/bash
# ANSI escape codes for blinking red text
BLINKING_RED="\033[5;31m"
# ANSI escape code to reset text attributes
RESET="\033[0m"

# Print the message
echo -e "${BLINKING_RED}Several changes should be done before start, log_dir, read_benchmarks, value_size, db records number. Please check as the list requires!!!!${RESET}"
#exit


curr_datetime=$(date '+%Y%m%d%H%M%S')

export PATH=$PATH:/home/guoqing/benchmark/pcm/build/bin
sh /home/guoqing/benchmark/pcm/scripts/bhs-power-mode.sh --latency-optimized-mode

export FLAME_GRAPH_PATH=/home/guoqing/perf/FlameGraph

full_kernel_version=$(uname -r)
kernel_version=$(echo "$full_kernel_version" | cut -d'.' -f1,2)


disable_high_latency_cstates() {
    local threshold="${1:-1}"
    echo "Disabling C-states with latency > $threshold microseconds..."

    for state_dir in /sys/devices/system/cpu/cpu0/cpuidle/state*; do
        if [ -d "$state_dir" ]; then
            state_index=$(basename "$state_dir" | sed 's/state//')
            state_name=$(cat "$state_dir/name" 2>/dev/null)
            state_latency=$(cat "$state_dir/latency" 2>/dev/null)

            if [ "$state_name" != "POLL" ] && [ -n "$state_latency" ] && [ "$state_latency" -gt "$threshold" ]; then
                echo "Disabling $state_name (index: $state_index, latency: ${state_latency}μs)"
                cmd="cpupower idle-set -d $state_index 2>/dev/null"
                echo ${cmd}
                eval ${cmd}
            fi
        fi
    done

    echo "Done. Current status:"
    cpupower idle-info
}

disable_high_latency_cstates 1

swapoff -a
ulimit -n 1048576

export PATH=$PATH:/home/gangdeng/rocksdb-8.9.1/build:/home/gangdeng/rocksdb-8.9.1/build/tools

if [ "$#" -ne 1 ]; then
  echo "Error: This script requires exactly one parameter."
  exit 1
fi


if [ "$1" -eq 128 ] || [ "$1" -eq 8 ]; then
  echo "Success: The parameter is valid."
else
  echo "Error: The parameter must be 128 or 8."
  exit 1
fi

db_recs=0
val_sz=$1

if [ "$1" -eq 128 ]; then
        db_recs=200000
elif [ "$1" -eq 8 ]; then
        #db_recs=1600000
        db_recs=3200000
fi



# CPU configurations
monitoring_cpu="160-190"

declare -A serverCpuList
serverCpuList[8]="1-4,97-100"
serverCpuList[32]="1-16,97-112"

# Global variables
MGLRU_FILE="/sys/kernel/mm/lru_gen/enabled"
EXPECTED_VALUE="0x0007"
log_postfix=""

# Check if the file exists and is a regular file
if [[ -f "$MGLRU_FILE" ]]; then
    # File exists, now check its content
    ACTUAL_VALUE=$(< "$MGLRU_FILE")

    if [[ "$ACTUAL_VALUE" == "$EXPECTED_VALUE" ]]; then
        echo "Success: The file '$MGLRU_FILE' exists and its value is '$EXPECTED_VALUE'."

    else
        echo "Error: The file '$MGLRU_FILE' exists, but its value is '$ACTUAL_VALUE', not '$EXPECTED_VALUE'."
    fi
    log_postfix="mglru-$ACTUAL_VALUE"
else
    echo "Error: The file '$MGLRU_FILE' does not exist."
    log_postfix="mglru-off"
fi


log_dir="./rocksdb_perf_readrandom_${val_sz}k_lz4_32t_compact_kernel${full_kernel_version}_${log_postfix}_0.2M_cpu100_dhlst_pagepolicy_adaptive"
rdmsr -a 0x6d
rdmsr -a 0x1a4
MONITOR_DURATION=20
declare -A MONITOR_PIDS
declare -A MONITORING_LOGS=()

MEMORY_HOG_PID=""

# Create log directory
mkdir -p "${log_dir}"

# Function to start memory hog
start_memory_hog() {
    ./memory_hog &
    MEMORY_HOG_PID=$!
    echo "The memory hog program is running with PID: $MEMORY_HOG_PID"
}

# Function to stop memory hog
stop_memory_hog() {
    if [[ -n "$MEMORY_HOG_PID" ]]; then
        kill "$MEMORY_HOG_PID"
        echo "The memory hog program is killed..."
    fi
}

# Function to start monitoring tools
start_monitoring_tools() {
    local benchmark_type=$1
    local thread_num=$2
    local value_size=$3
    local direct_io=$4
    local serverCpuList=$5

    local monitor_exec_cores=$monitoring_cpu
    local metric_dir="${log_dir}/metrics"
    mkdir -p "${metric_dir}"
    local log_prefix="${metric_dir}/metrics_hex_${benchmark_type}_${thread_num}threads_${value_size}_direct_io_${direct_io}_${curr_datetime}"

    source /opt/intel/sep/sep_vars.sh

    echo "Starting monitoring for ${benchmark_type} (tools executing on cores ${monitor_exec_cores}) targeting server cores ${serverCpuList}..."

    # mpstat
    if command -v mpstat &> /dev/null; then
        taskset -c "$monitor_exec_cores" mpstat -P "$serverCpuList" 1 "${MONITOR_DURATION}" > "${log_prefix}_mpstat.log" 2>&1 &
        MONITOR_PIDS["mpstat_${benchmark_type}"]=$!
        MONITORING_LOGS["mpstat_${benchmark_type}"]="${log_prefix}_mpstat.log"
        echo "  mpstat started (PID: ${MONITOR_PIDS["mpstat_${benchmark_type}"]})"
    fi

    # iostat
    if command -v iostat &> /dev/null; then
        taskset -c "$monitor_exec_cores" iostat -x 1 "${MONITOR_DURATION}" > "${log_prefix}_iostat.log" 2>&1 &
        MONITOR_PIDS["iostat_${benchmark_type}"]=$!
        MONITORING_LOGS["iostat_${benchmark_type}"]="${log_prefix}_iostat.log"
        echo "  iostat started (PID: ${MONITOR_PIDS["iostat_${benchmark_type}"]})"
    fi

    # sar
    if command -v sar &> /dev/null; then
        taskset -c "$monitor_exec_cores" sar -P "$serverCpuList" -u -r -b -n DEV 1 "${MONITOR_DURATION}" > "${log_prefix}_sar.log" 2>&1 &
        MONITOR_PIDS["sar_${benchmark_type}"]=$!
        MONITORING_LOGS["sar_${benchmark_type}"]="${log_prefix}_sar.log"
        echo "  sar started (PID: ${MONITOR_PIDS["sar_${benchmark_type}"]})"
    fi

    # emon
    if command -v emon &> /dev/null; then
        taskset -c "$monitor_exec_cores" emon -collect-edp -f ${log_prefix}_emon.dat & sleep ${MONITOR_DURATION}; emon -stop  > "${log_prefix}_emon.log" 2>&1 &
        MONITOR_PIDS["emon_${benchmark_type}"]=$!
        MONITORING_LOGS["emon_${benchmark_type}"]="${log_prefix}_emon.dat"
        echo "  emon started (PID: ${MONITOR_PIDS["emon_${benchmark_type}"]})"
    fi

    # perf record
    if command -v perf &> /dev/null; then
        echo 1 | sudo tee /proc/sys/kernel/nmi_watchdog > /dev/null
        sudo taskset -c "$monitor_exec_cores" perf record -F 999 -C "$serverCpuList" -g -o "${log_prefix}_perf.data" sleep "${MONITOR_DURATION}" > "${log_prefix}_perf_record.log" 2>&1 &
        MONITOR_PIDS["perf_${benchmark_type}"]=$!
        MONITORING_LOGS["perf_${benchmark_type}"]="${log_prefix}_perf.data"
        echo "  perf record started (PID: ${MONITOR_PIDS["perf_${benchmark_type}"]})"
    fi
}

# Function to stop monitoring tools
stop_monitoring_tools() {
    local benchmark_type=$1
    echo "Stopping monitoring for ${benchmark_type}..."

    local tools=("mpstat" "iostat" "sar" "perf" "emon")
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
                elif [[ "$tool" == "perf" ]]; then
                    kill "$pid" >/dev/null 2>&1
                    local start_time=$(date +%s)
                    while ps -p "$pid" > /dev/null && (( $(date +%s) - start_time < graceful_wait_time )); do
                        sleep 0.1
                    done
                    if ps -p "$pid" > /dev/null; then
                        echo "  Warning: ${tool} (PID: ${pid}) did not stop gracefully. Sending SIGKILL."
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

# Function to generate performance results
gen_perf_result() {
    local perf_file=$1
    local benchmark_type=$2
    local summary_file="${log_dir}/summary_perf_${curr_datetime}.log"

    echo "perf result file: $perf_file" >> "$summary_file"
    tps=$(grep -Ei "${benchmark_type}.*ops/sec.*" "$perf_file" | awk '{print $5}')
    avg_latency=$(grep -Ei "Count.*Average.*.StdDev.*" "$perf_file" | awk '{print $4}')
    p99_latency=$(grep -Ei "Percentiles.*P99.*" "$perf_file" | awk -F'P99: ' '{print $2}' | awk '{print $1}')

    echo "performance result file: $perf_file" >> "${summary_file}"
    echo "Throughput: $tps" >> "${summary_file}"
    echo "Average Latency: $avg_latency" >> "${summary_file}"
    echo "p99_latency: $p99_latency" >> "${summary_file}"
}



gen_report() {

        source /opt/intel/sep/sep_vars.sh

        local benchmark_type=$1
        local monitor_exec_cores=$monitoring_cpu
        local metric_dir="${log_dir}/metrics"

        #generate flame graph
        echo "GENERATING flamegraph report..."
        perf_file=${MONITORING_LOGS["perf_${benchmark_type}"]}
        perf_svg_file=${perf_file/.data/.svg}

        cmd="perf script -i ${perf_file} | ${FLAME_GRAPH_PATH}/stackcollapse-perf.pl | ${FLAME_GRAPH_PATH}/flamegraph.pl > ${perf_svg_file}"
        echo "start to generate report:"
        echo ${cmd}
        eval ${cmd}
        echo "generated report: ${perf_svg_file}"
        echo "GENERATED flamegraph report"

        #generate emon summary report

        emon_file=${MONITORING_LOGS["emon_${benchmark_type}"]}
        emon_summary_file=${emon_file/.dat/.xlsx}
        echo "generated emon summary: ${emon_summary_file}"

        cp ${emon_file} ./${metric_dir}/emon.dat
        pushd ${metric_dir} > /dev/null
        cp /opt/intel/sep/config/edp/pyedp_config.txt .
        emon -process-pyedp ./pyedp_config.txt
        popd  > /dev/null
        mv ${metric_dir}/summary.xlsx ${emon_summary_file}
        rm -f ${metric_dir}/emon.dat
        rm -f ${metric_dir}/summary.xlsx

}


# Function to run benchmark
run_benchmark() {
    local cmd=$1
    local benchmark_type=$2
    local thread_num=$3
    local val_size=$4
    local io_type=$5
    local server_cpu_list=$6

    local result_file="${log_dir}/${benchmark_type}_${thread_num}threads_${val_size}value_size_direct_io_${io_type}_shards10_16gcache_size_${curr_datetime}.txt"
    local log_file="${log_dir}/${benchmark_type}_${thread_num}threads_${val_size}value_size_direct_io_${io_type}_shards10_16gcache_size${curr_datetime}.log"

    local local_cmd="$cmd 2>&1 > ${result_file} &"

    echo "${local_cmd}" >> "$log_file"
    eval "${local_cmd}"
    local db_bench_pid=$!

    sleep 90

    start_monitoring_tools "$benchmark_type" "$thread_num" "$val_size" "$io_type" "$server_cpu_list"

    echo "Waiting for db_bench ${db_bench_pid} for ${benchmark_type} threads: ${thread_num} value_size: ${val_size} to finish..." >> "$log_file"
    wait "$db_bench_pid"

    stop_monitoring_tools "$benchmark_type"
    gen_perf_result "$result_file" "$benchmark_type"
}

# Function to run compaction
run_compaction() {
    local log_file=$1
    local cmd="db_bench --benchmarks=compact --use_existing_db=1 --disable_wal=1 --sync=0 --threads=32 --num_multi_db=32 --max_background_jobs=64 --max_background_flushes=32 --max_background_compactions=56 --max_write_buffer_number=6 --allow_concurrent_memtable_write=true --level0_file_num_compaction_trigger=1000000 --level0_slowdown_writes_trigger=1000000 --level0_stop_writes_trigger=1000000 --db=/data2/db --wal_dir=/data2/wal --num=400000 --key_size=20 --value_size=32768 --block_size=8192 --cache_size=2147483648 --cache_numshardbits=5 --compression_type=none --bytes_per_sync=2097152 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --max_bytes_for_level_multiplier=8 --statistics=1 --histogram=1 --report_interval_seconds=1 --stats_interval_seconds=60 --subcompactions=4 --compaction_style=0 --num_levels=8 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=0 --open_files=65536 --seed=1755087265"

    echo "$cmd" >> "$log_file"
    eval "$cmd"
}

# Benchmark configurations
declare -A read_benchmarks=(
        ["readrandom_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --threads=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=12 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal  --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --compression_type=lz4 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=2 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --value_size=$((val_sz * 1024)) --num=${db_recs} --disable_auto_compactions=1"
        #["readrandom_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --threads=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=12 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal  --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --compression_type=lz4 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=2 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --value_size=$((val_sz * 1024)) --num=${db_recs} --disable_auto_compactions=1 -benchmark_read_rate_limit=70000"
        #["readseq_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --num=1600000 --value_size=8192 --threads=32 --compression_type=none"

)

#declare -A read_benchmarks=(
   #readrandom lz4+128K
    #["readrandom_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --threads=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=12 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal  --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --compression_type=lz4 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=2 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --value_size=$((128*1024)) --num=200000 --disable_auto_compactions=1"

    #["readseq_32_true"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=12 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=2 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=true --num=200000 --value_size=$((128*1024)) --threads=32 --compression_type=lz4 --disable_auto_compactions=1"

    #readrandom lz4+8K
    #["readrandom_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --threads=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=12 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal  --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --compression_type=lz4 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=2 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --value_size=$((8*1024)) --num=1600000 --disable_auto_compactions=1"

    #["readseq_32_true"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=12 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=2 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=true --num=1600000 --value_size=$((8*1024)) --threads=32 --compression_type=lz4 --disable_auto_compactions=1"



    #["readrandom_8_false"]="nohup numactl -C ${serverCpuList[8]} db_bench --benchmarks=readrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --threads=8 --compression_type=none --value_size=8192 --num=1600000"

    #["readrandom_32_false"]="nohup numactl -C ${serverCpuList[32]}  db_bench --benchmarks=readrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --threads=32 --compression_type=none --value_size=8192 --num=1600000"

    #["readseq_8_true"]="nohup numactl -C  ${serverCpuList[8]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=true --num=1600000 --value_size=8192 --threads=8 --compression_type=none"

    #["readseq_32_true"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=true --num=1600000 --value_size=8192 --threads=32 --compression_type=none"

    #["readseq_8_false"]="nohup numactl -C ${serverCpuList[8]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --num=1600000 --value_size=8192 --threads=8 --compression_type=none"

    #["readseq_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=10 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --num=1600000 --value_size=8192 --threads=32 --compression_type=none --max_auto_readahead_size=65536 "

    #["readseq_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=readseq,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seed=1755138680 --use_direct_reads=false --num=1600000 --value_size=8192 --threads=32 --compression_type=none"


    #["seekrandom_8_false"]="nohup numactl -C ${serverCpuList[8]} db_bench --benchmarks=seekrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --num=400000 --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seek_nexts=10 --reverse_iterator=false --seed=1755612279 --use_direct_reads=false --threads=8 --compression_type=none --value_size=8192"

    #["seekrandom_32_false"]="nohup numactl -C ${serverCpuList[32]} db_bench --benchmarks=seekrandom,stats --use_existing_db=1 --duration=240 --num_multi_db=32 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/data2/db --wal_dir=/data2/wal --num=400000 --key_size=20 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --seek_nexts=10 --reverse_iterator=false --seed=1755612279 --use_direct_reads=false --threads=32 --compression_type=none --value_size=8192"


#)



# Main execution
start_memory_hog


for key in "${!read_benchmarks[@]}"; do
        IFS='_' read -r benchmark_type thread_num io_type <<< "$key"
        run_benchmark "${read_benchmarks[$key]}" "$benchmark_type" "$thread_num" "$((val_sz * 1024))" "$io_type" "${serverCpuList[$thread_num]}"
done


# Clean up
stop_memory_hog

#generate profiling file
for key in "${!read_benchmarks[@]}"; do
        IFS='_' read -r benchmark_type thread_num io_type <<< "$key"
        gen_report "$benchmark_type"
done


echo "All benchmarks completed."
