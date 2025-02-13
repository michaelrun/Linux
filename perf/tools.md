# Generate flame graph
```
numactl -N 1 -m 1 perf record -F 999 -p $1 -g -- sleep 60
numactl -N 1 -m 1 perf script | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl > mongo_zstd.svg
```
# check current load libraries:
```
ldconfig -p
```
# yum
```
sudo dnf install yum-utils
yum repolist enabled
sudo dnf config-manager --set-enabled crb
dnf repolist
sudo dnf install epel-release
sudo dnf install epel-next-release

```


# Generate flame graph scripts
```
#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <process_id> <output_file>"
    exit 1
fi

# Assign input parameters to variables
PID=$1
OUTPUT_FILE=$2

# Check if the process with the given PID exists
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Process with PID $PID does not exist."
    exit 1
fi

# Record performance data using perf
echo "Recording performance data for PID $PID..."
numactl -N 1 -m 1 perf record -F 999 -p "$PID" -g -- sleep 60

# Check if perf record was successful
if [ $? -ne 0 ]; then
    echo "Failed to record performance data."
    exit 1
fi

# Generate flame graph
echo "Generating flame graph..."
perf script | /home/guoqing/FlameGraph/stackcollapse-perf.pl | /home/guoqing/FlameGraph/flamegraph.pl > "$OUTPUT_FILE"

# Check if flame graph generation was successful
if [ $? -ne 0 ]; then
    echo "Failed to generate flame graph."
    exit 1
fi

echo "Flame graph has been written to $OUTPUT_FILE."
```
