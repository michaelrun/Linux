# perf monitoring scripts
```
#!/bin/bash

# Duration of monitoring in seconds
duration=60

# Output directory
output_dir="performance_statistics"

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Function to capture statistics using sar -u
capture_sar_u_stats() {
    sar -u $duration > "$output_dir/sar_u_data.txt" &
}

# Function to capture statistics using sar -b
capture_sar_b_stats() {
    sar -b $duration > "$output_dir/sar_b_data.txt" &
}

# Function to capture statistics using sar -A
capture_sar_A_stats() {
    sar -A -o "$output_dir/sar_data" $duration >/dev/null 2>&1
}

# Function to capture statistics using sar -q
capture_sar_q_stats() {
    sar -q $duration > "$output_dir/sar_q_data.txt" &
}

# Function to capture statistics using pidstat
capture_pidstat_stats() {
    pidstat -urd -hl -h -d $duration > "$output_dir/pidstat_data.txt" &
}

# Function to capture statistics using dstat
capture_dstat_stats() {
    dstat -cdngy --output "$output_dir/dstat_data.csv" $duration >/dev/null 2>&1 &
}

# Function to capture statistics using nmon
capture_nmon_stats() {
    nmon -f -s $duration -c 1 -m "$output_dir/nmon_data" >/dev/null 2>&1 &
}

# Function to capture statistics using perf
capture_perf_stats() {
    perf stat -a -o "$output_dir/perf_data" sleep $duration >/dev/null 2>&1 &
}

# Function to capture statistics using vmstat
capture_vmstat_stats() {
    vmstat -w -t $duration > "$output_dir/vmstat_data.txt" &
}

# Function to capture statistics using iostat
capture_iostat_stats() {
    iostat -dx -t $duration > "$output_dir/iostat_data.txt" &
}

# Function to capture statistics using mpstat
capture_mpstat_stats() {
    mpstat -P ALL $duration > "$output_dir/mpstat_data.txt" &
}

# Function to capture statistics using uptime
capture_uptime_stats() {
    uptime > "$output_dir/uptime_data.txt"
}

# Function to capture statistics using netstat
capture_netstat_stats() {
    netstat -s > "$output_dir/netstat_data.txt"
}

# Function to capture statistics using tcpdump
capture_tcpdump_stats() {
    tcpdump -i any -c 1000 -nn -q -tttt > "$output_dir/tcpdump_data.txt" &
}

# Function to capture statistics using iotop
capture_iotop_stats() {
    iotop -botqqq -n $duration > "$output_dir/iotop_data.txt" &
}

# Function to capture statistics using htop
capture_htop_stats() {
    htop -d $duration --no-color > "$output_dir/htop_data.txt" &
}

# Function to capture statistics using iftop
capture_iftop_stats() {
    iftop -t -s $duration -n > "$output_dir/iftop_data.txt" &
}

# Function to capture statistics using strace
capture_strace_stats() {
    strace -c -o "$output_dir/strace_data.txt" sleep $duration &
}

# Function to capture statistics using sar -r
capture_sar_r_stats() {
    sar -r $duration > "$output_dir/sar_r_data.txt" &
}

# Function to capture statistics using sar -w
capture_sar_w_stats() {
    sar -w $duration > "$output_dir/sar_w_data.txt" &
}

# Function to capture statistics using sar -R
capture_sar_R_stats() {
    sar -R $duration > "$output_dir/sar_R_data.txt" &
}

# Function to capture statistics using sar -v
capture_sar_v_stats() {
    sar -v $duration > "$output_dir/sar_v_data.txt" &
}

# Function to capture statistics using nload
capture_nload_stats() {
    nload -t $duration > "$output_dir/nload_data.txt" &
}

# Start capturing statistics from all tools
echo "Capturing performance statistics for $duration seconds..."

capture_sar_u_stats
capture_sar_b_stats
capture_sar_A_stats
capture_sar_q_stats
capture_pidstat_stats
capture_dstat_stats
capture_nmon_stats
capture_perf_stats
capture_vmstat_stats
capture_iostat_stats
capture_mpstat_stats
capture_uptime_stats
capture_netstat_stats
capture_tcpdump_stats
capture_iotop_stats
capture_htop_stats
capture_iftop_stats
capture_strace_stats
capture_sar_r_stats
capture_sar_w_stats
capture_sar_R_stats
capture_sar_v_stats
capture_nload_stats

# Wait for all processes to finish
wait

echo "Performance statistics captured successfully."



```

# for process and system
```
#!/bin/bash

# Duration of monitoring in seconds
duration=60

# Process ID of the target process
target_process_pid=12345

# Output directory
output_dir="performance_statistics"

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Function to capture statistics using sar -u for a specific process
capture_sar_u_stats() {
    sar -P $target_process_pid 1 $duration > "$output_dir/sar_u_data.txt" &
}

# Function to capture statistics using sar -b for a specific process
capture_sar_b_stats() {
    sar -P $target_process_pid -b 1 $duration > "$output_dir/sar_b_data.txt" &
}

# Function to capture statistics using sar -A for a specific process
capture_sar_A_stats() {
    sar -P $target_process_pid -A -o "$output_dir/sar_data" 1 $duration >/dev/null 2>&1
}

# Function to capture statistics using sar -q for a specific process
capture_sar_q_stats() {
    sar -P $target_process_pid -q 1 $duration > "$output_dir/sar_q_data.txt" &
}

# Function to capture statistics using pidstat for a specific process
capture_pidstat_stats() {
    pidstat -urd -hl -h -d -p $target_process_pid 1 $duration > "$output_dir/pidstat_data.txt" &
}

# Function to capture statistics using dstat for a specific process
capture_dstat_stats() {
    dstat -cdngy --output "$output_dir/dstat_data.csv" --pid=$target_process_pid 1 $duration >/dev/null 2>&1 &
}

# Function to capture statistics using nmon for a specific process
capture_nmon_stats() {
    nmon -f -s 1 -c 1 -m -p $target_process_pid "$output_dir/nmon_data" >/dev/null 2>&1 &
}

# Function to capture statistics using perf for a specific process
capture_perf_stats() {
    perf stat -p $target_process_pid -o "$output_dir/perf_data" sleep $duration >/dev/null 2>&1 &
}

# Function to capture statistics using vmstat for the whole system
capture_vmstat_stats() {
    vmstat 1 $duration > "$output_dir/vmstat_data.txt" &
}

# Function to capture statistics using iostat for the whole system
capture_iostat_stats() {
    iostat -dx -t 1 $duration > "$output_dir/iostat_data.txt" &
}

# Function to capture statistics using mpstat for the whole system
capture_mpstat_stats() {
    mpstat -P ALL 1 $duration > "$output_dir/mpstat_data.txt" &
}

# Function to capture statistics using uptime for the whole system
capture_uptime_stats() {
    uptime > "$output_dir/uptime_data.txt" &
}

# Function to capture statistics using netstat for the whole system
capture_netstat_stats() {
    netstat -s > "$output_dir/netstat_data.txt" &
}

# Function to capture statistics using tcpdump for a specific process
capture_tcpdump_stats() {
    tcpdump -i any -c 1000 -nn -q -tttt "dst port $target_process_pid" > "$output_dir/tcpdump_data.txt" &
}

# Function to capture statistics using iotop for the whole system
capture_iotop_stats() {
    iotop -b -n 1 -k -o > "$output_dir/iotop_data.txt" &
}

# Function to capture statistics using htop for the whole system
capture_htop_stats() {
    htop -n 1 -C > "$output_dir/htop_data.txt" &
}

# Function to capture statistics using iftop for the whole system
capture_iftop_stats() {
    iftop -t -s 1 -n -N > "$output_dir/iftop_data.txt" &
}

# Function to capture statistics using strace for a specific process
capture_strace_stats() {
    strace -c -p $target_process_pid -o "$output_dir/strace_data.txt" sleep $duration &
}

# Function to capture statistics using sar -r for the whole system
capture_sar_r_stats() {
    sar -r 1 $duration > "$output_dir/sar_r_system_data.txt" &
}

# Function to capture statistics using sar -w for the whole system
capture_sar_w_stats() {
    sar -w 1 $duration > "$output_dir/sar_w_system_data.txt" &
}

# Function to capture statistics using sar -R for the whole system
capture_sar_R_stats() {
    sar -R 1 $duration > "$output_dir/sar_R_system_data.txt" &
}

# Function to capture statistics using sar -v for the whole system
capture_sar_v_stats() {
    sar -v 1 $duration > "$output_dir/sar_v_system_data.txt" &
}

# Function to capture statistics using nload for the whole system
capture_nload_stats() {
    nload -t 1 -o "$output_dir/nload_system_data.txt" &
}

# Start capturing statistics for the specified process
echo "Capturing performance statistics for process $target_process_pid for $duration seconds..."
capture_sar_u_stats
capture_sar_b_stats
capture_sar_A_stats
capture_sar_q_stats
capture_pidstat_stats
capture_dstat_stats
capture_nmon_stats
capture_perf_stats
capture_tcpdump_stats
capture_strace_stats

# Start capturing system-wide statistics
echo "Capturing system-wide performance statistics for $duration seconds..."
capture_vmstat_stats
capture_iostat_stats
capture_mpstat_stats
capture_uptime_stats
capture_netstat_stats
capture_iotop_stats
capture_htop_stats
capture_iftop_stats
capture_sar_r_stats
capture_sar_w_stats
capture_sar_R_stats
capture_sar_v_stats
capture_nload_stats

# Wait for all processes to finish
wait

echo "Performance statistics captured successfully."
```
