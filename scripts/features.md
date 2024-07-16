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
