# Generate flame graph
```
numactl -N 1 -m 1 perf record -F 999 -p $1 -g -- sleep 60
numactl -N 1 -m 1 perf script | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl > mongo_zstd.svg
```
# check current load libraries:
```
ldconfig -p
```
