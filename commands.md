# git checkout from pull request
```
git clone https://github.com/redis/redis.git
git fetch origin pull/13139/head:upstream
git checkout upstream
```

# check netowrk card speed/usage/description
```
nload -m
ethtool enp1s0
sar -n DEV --iface eno1
```
![image](https://github.com/michaelrun/Linux/assets/19384327/f98000c3-adcf-47d7-8a3d-318d129e19ef)


# check distribution of ubuntu
Change the "Distribution" to the codename of the version of Ubuntu you're using, e.g. focal in Ubuntu 20.04 or it's displayed by `lsb_release -sc`

# Find the Largest Top 10 Files and Directories On a Linux
`du -hsx * | sort -rh | head -10` 
1. du command -h option : Display sizes in human readable format (e.g., 1K, 234M, 2G).
2. du command -s option : It shows only a total for each argument (summary).
3. du command -x option : Skip directories on different file systems.
4. sort command -r option : Reverse the result of comparisons.
5. sort command -h option : It compares human readable numbers. This is GNU sort specific option only.
6. head command -10 OR -n 10 option : It shows the first 10 lines.

# caculate start and end time
```
#include <unistd.h>
#include <sys/time.h>

#define time_sec() ({struct timeval tp; gettimeofday(&tp, 0); tp.tv_sec + tp. tv_usec * 1.e-6;})
...
int start = time_sec();
...
int end = time_sec();
```

# get thread id
`printf("=====getpid: %d tid:%lu, qat =====\n", getpid(), syscall(SYS_gettid));`
