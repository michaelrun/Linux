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

# check file system type
`blkid` output like:
```
/dev/mapper/cs_spr177-home: UUID="4be5cf91-21de-49e1-a6f7-f0559fad3ccc" TYPE="ext4"
/dev/nvme0n1: UUID="9a797e29-8d17-4049-8914-1868e6223ff3" TYPE="xfs"
/dev/nvme3n1: UUID="d6c1eb23-42c4-4c30-ba8c-1493e1117ac2" TYPE="ext4"
/dev/nvme2n1: UUID="290ff7ed-dd5a-4cb8-9b43-69a0401e6665" TYPE="xfs"
/dev/mapper/cs_spr177-work: UUID="aabccbfd-963f-492c-b447-2775b45b8ba9" TYPE="ext4"
/dev/mapper/cs_spr177-root: UUID="1a8f7f6a-30f1-403b-b966-3a8f435b59ad" TYPE="ext4"
/dev/nvme1n1p1: UUID="cf66f841-8e9d-4a2b-8685-407ce783e4ea" TYPE="ext4" PARTUUID="fb58c8f1-926e-334f-af68-2770c457cff2"
/dev/sda2: UUID="03b842bd-be40-44fe-a14c-eed8831172d2" TYPE="ext2" PARTUUID="4eba4af5-1785-4c43-bc8d-357fe67155db"
/dev/sda3: UUID="MBeki2-mqrH-zEKm-OPBf-i6Ha-0cKW-xluUVx" TYPE="LVM2_member" PARTUUID="c55c2789-b036-4fe6-bca2-23e8c759da07"
/dev/sda1: UUID="B4E5-BADE" TYPE="vfat" PARTLABEL="EFI System Partition" PARTUUID="1a5594b6-aafa-44d1-9a53-0d8526cbc843"
/dev/nvme4n1: UUID="89dbc82b-f800-43e7-a9f9-6007dcb6d61f" TYPE="ext4"
```
`lsblk -o NAME,FSTYPE,LABEL,MOUNTPOINT,SIZE,MODEL` output like:
```
NAME               FSTYPE      LABEL MOUNTPOINT     SIZE MODEL
sda                                                 1.5T MR9361-24i
├─sda1             vfat              /boot/efi      600M
├─sda2             ext2              /boot           10G
└─sda3             LVM2_member                      1.5T
  ├─cs_spr177-root ext4              /              200G
  ├─cs_spr177-home ext4              /home          800G
  └─cs_spr177-work ext4              /work          200G
nvme0n1            xfs               /mnt/nvme1n1 931.5G INTEL SSDPE2KX010T8
nvme1n1                                           931.5G INTEL SSDPE2KX010T7
└─nvme1n1p1        ext4              /mnt/nvme3n1 931.5G
nvme3n1            ext4              /data        931.5G INTEL SSDPE2KX010T8
nvme4n1            ext4              /mnt/nvme4n1 931.5G INTEL SSDPE2KX010T8
nvme2n1            xfs               /mnt/nvme2n1 931.5G INTEL SSDPE2KX010T8
```
`df -hT` output like:
```
Filesystem                 Type      Size  Used Avail Use% Mounted on
devtmpfs                   devtmpfs  4.0M     0  4.0M   0% /dev
tmpfs                      tmpfs     504G     0  504G   0% /dev/shm
tmpfs                      tmpfs     202G   12M  202G   1% /run
/dev/mapper/cs_spr177-root ext4      196G  164G   23G  88% /
/dev/sda2                  ext2      9.9G  761M  8.6G   8% /boot
/dev/nvme3n1               ext4      916G  613G  257G  71% /data
/dev/sda1                  vfat      599M  7.5M  592M   2% /boot/efi
/dev/mapper/cs_spr177-home ext4      787G  576G  171G  78% /home
/dev/mapper/cs_spr177-work ext4      196G   38G  148G  21% /work
tmpfs                      tmpfs     101G   36K  101G   1% /run/user/0
/dev/nvme0n1               xfs       932G   73G  859G   8% /mnt/nvme1n1
/dev/nvme2n1               xfs       932G  251G  681G  27% /mnt/nvme2n1
/dev/nvme4n1               ext4      916G   88K  870G   1% /mnt/nvme4n1
/dev/nvme1n1p1             ext4      916G   14G  857G   2% /mnt/nvme3n1
```
mount file system at system start, edit /etc/fstab
```
#
# /etc/fstab
# Created by anaconda on Fri Aug  4 06:31:44 2023
#
# Accessible filesystems, by reference, are maintained under '/dev/disk/'.
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info.
#
# After editing this file, run 'systemctl daemon-reload' to update systemd
# units generated from this file.
#
/dev/mapper/cs_spr177-root /                       ext4    defaults        1 1
UUID=03b842bd-be40-44fe-a14c-eed8831172d2 /boot                   ext2    defaults        1 2
UUID=B4E5-BADE          /boot/efi               vfat    umask=0077,shortname=winnt 0 2
/dev/mapper/cs_spr177-home /home                   ext4    defaults        1 2
/dev/mapper/cs_spr177-work /work                   ext4    defaults        1 2
UUID=d6c1eb23-42c4-4c30-ba8c-1493e1117ac2 /data    ext4    defaults        1 2
```

