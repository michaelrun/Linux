# check or enable/disable hyper-threading

```
dmidecode -t processor | grep -E '(Core Count|Thread Count)'
lscpu -e
lscpu |grep "Thread(s) per core"
```
The easiest way to check if SMT (generic for HT, which is just Intel branding) is active just do:\
`cat /sys/devices/system/cpu/smt/active`\
gives you 0 for inactive or 1 for active.\
You can actually turn it on or off at runtime with:\
`echo [on|off] > /sys/devices/system/cpu/smt/control`

# check or enable/disable turbo
```
cat /sys/devices/system/cpu/intel_pstate/no_turbo
```
`0` if turbo is enabled;

`1` if turbo is disabled.
To disable:\
 `echo '1' >/sys/devices/system/cpu/intel_pstate/no_turbo`

# check all C-state
`turbostat --show sysfs --quiet sleep 10`
output like:\
```
10.029123 sec
POLL    C1      C1E     C6      POLL%   C1%     C1E%    C6%
12      55      4166    11084   0.00    0.00    0.12    99.82
0       0       163     392     0.00    0.00    1.49    98.13
0       0       13      121     0.00    0.00    0.09    99.90
0       3       13      133     0.00    0.00    0.07    99.90
0       0       14      61      0.00    0.00    0.07    99.93
0       1       10      42      0.00    0.00    0.10    99.90
0       0       10      50      0.00    0.00    0.09    99.90
0       0       10      29      0.00    0.00    0.09    99.91
0       0       11      32      0.00    0.00    0.10    99.90
0       0       12      30      0.00    0.00    0.10    99.89
0       0       11      30      0.00    0.00    0.09    99.91
```
