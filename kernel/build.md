# kernel source code download
```https://cdn.kernel.org/pub/linux/kernel/v5.x/```

# build kernel of ubuntu
[KernelBuild](https://kernelnewbies.org/KernelBuild)
# build kernel

Let's take lts-v5.4.102-yocto as an example.

step1: Download the kernel.

          wget  -c  https://github.com/intel/linux-intel-lts/archive/refs/tags/lts-v5.4.102-yocto-210310T010318Z.tar.gz

step2: Extract and enter the directory.

          tar -zxvf lts-v5.4.102-yocto-210310T010318Z.tar.gz && cd linux-intel-lts-lts-v5.4.102-yocto-210310T010318Z/

step3: Copy the default kernel config file of Ubuntu.

          cp /boot/config-5.4.0-66-generic .config

step4: make oldconfig, in this step, select the default value for all the options.

          make oldconfig

step5: build kernel.

          make -j8

step6: make  modules_install ,this step must add the parameter "INSTALL_MOD_STRIP=1", otherwise it will cause too large "initrd" to boot kernel.

          sudo make INSTALL_MOD_STRIP=1 modules_install

step7: install kernel.

          sudo make install

Then edit the Linux kernel boot option and add “i915.force_probe=* i915.enable_guc=2” to force GPU module probe.
![image](https://github.com/michaelrun/Linux/assets/19384327/135091c7-c276-4dfe-815e-6761388049c6)
How to solve the problem of "No rule to make target 'debian/canonical-certs.pem', needed by 'certs/x509_certificate_list' " while make?
![image](https://github.com/michaelrun/Linux/assets/19384327/66ada88e-de67-4e57-b11c-5c266460ca62)
Solution: open the. Config file and comment out the line

             CONFIG_SYSTEM_TRUSTED_KEYS="debian/certs/benh@debian.org.cert.pem"
How to solve the problem of “can't allocate initrd" and "Unable to mount root fs on unknown-bolck", while the system booting on tgl ?
The problem is that your initrd file is too large. If you want to solve this problem, you must must add the parameter "INSTALL_MOD_STRIP=1" like step6.



# How to build kernel source from Joule branch of xenial repository.

## Step-by-step guide Ubuntu Distribution

### Kernel Source
Download the kernel source from the branch of a xenial repo: \
`git clone https://git.launchpad.net/~canonical-kernel/ubuntu/+source/linux-joule`

### Building the kernel
#### Build Environment:
    `sudo apt-get build-dep linux-image-$(uname -r)`
If above command doesn’t work for Joule kernel branch; manually install required build tools as below
```
sudo apt-get install build-essential git
sudo apt-get install kernel-wedge
sudo apt-get install libssl-dev ncurses-dev xz-utils kernel-package
````
#### Modify the Configuration:
```
    chmod a+x debian/rules
    chmod a+x debian/scripts/*
    chmod a+x debian/scripts/misc/*
    fakeroot debian/rules clean
    fakeroot debian/rules editconfigs # you need to go through each (Y, Exit, Y, Exit...) or get a complaint about config later
```
### Trigger the kernel build:
Change your working directory to the root of the kernel source tree and then type the following commands:
fakeroot debian/rules clean
## quicker build:
`fakeroot debian/rules binary-headers binary-joule binary-perarch`
If the build is successful, a set of five.deb binary package files will be produced in the directory above the build root directory. For example after building a kernel with version "4.4.0-1000.1" on an amd64
system, these five .deb packages would be produced:
```
cd ..
ls *.deb
linux-headers-4.4.0-1000-joule_4.4.0-1000.1_amd64.deb
linux-joule-headers-4.4.0-1000_4.4.0-1000.1_amd64.deb
linux-image-4.4.0-1000-joule_4.4.0-1000.1_amd64.deb
linux-tools-4.4.0-1000-joule_4.4.0-1000.1_amd64.deb
linux-joule-tools-4.4.0-1000_4.4.0-1000.1_amd64.deb
```
On later releases you will also find a linux-extra- package which you should also install if present.

#### Testing the new Kernel
Install the five-package set (on your Joule Platform) with dpkg -i and then reboot:
```
sudo dpkg -i linux*.deb
sudo reboot
```


# Build deb kernel

## Prerequisites
`sudo apt install kernel-package fakeroot libncurses5-dev build-essential libelf-dev libssl-dev bison flex`
## Get source code
Download source code from kernel.org and extract, e.g. 4.14.150 \
``
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.150.tar.xz
xz -cd linux-4.14.150.tar.xz | tar xvf -
``
## Configure
Copy current kernel configuration to be used for the new kernel
```
cp /boot/config-`uname -r` .config
make olddefconfig
```
And customize if you want

`make menuconfig`
Double check the result .config before going forward

## Build
`make -j `
Or build into .deb packages

`make -j LOCALVERSION=-custom bindeb-pkg` 
## Install
`sudo make modules_install install` 
Or install .deb packages

`sudo dpkg -i ../*.deb` 


# For VM usage

1. Overview
This guide introduce how to build AARCH64 CentOS initrd image using VM

2. Install CentOS VM
Please refer to the following wiki page on how to install CentOS VM

01: Install CentOS Virtual Machine

3. Build Kernel & IDPF Driver
Refer to the following wiki page on how to build kernel version 5.14.21+

ACC CentOS Bringup Guide

4. Copy Kernel Modules to VM
In kernel build directory, use following command to install 5.14.21+ kernel modules into directory $OUTGOING/modules/ \
`make INSTALL_MOD_PATH=$OUTGOING/modules/ modules_install -j144 `\
In idpf driver build directory, use following command to install idpf.ko into directory $OUTGOING/modules/ 
```
cp idpf.ko $OUTGOING/modules/lib/modules/5.14.21+/kernel/drivers/net/ethernet/intel/
depmod -ae -F $KERNEL_BUILD_DIR/System.map -b $OUTGOING/modules/
```
Use following command to pack kernel modules and copy it to CentOS VM:
```
cd $OUTGOING/modules/lib/modules
tar czf kernel-modules.tar.gz 5.14.21+/
scp kernel-modules.tar.gz root@<VM-IP>:/lib/modules/
```
Enter CentOS VM, do the following commands to install kernel modules.
```
cd /lib/modules
tar xzf kernel-modules.tar.gz
```
5. Install NFS Packages
Enter the CentOS VM, install following packages
```
# dnf install nfs-utils nfs4-acl-tools
```
6. Generate Initrd Image
In CentOS VM, use following command to generate initrd image for kernel version 5.14.21+:

`dracut -v -m "nfs network base" --add-drivers "nfs nfsv4" --force-drivers "mfd-core idpf" initrd.img 5.14.21+`


# build issues
[Compiling older Linux Kernels can fail with load BTF from vmlinux: invalid argument](https://devkernel.io/posts/pahole-error/) \
[FAILED: load BTF from vmlinux: Invalid argument](https://community.intel.com/t5/Intel-Edge-Software-Hub/FAILED-load-BTF-from-vmlinux-Invalid-argument/m-p/1519560) \


This article describes how to solve the error load BTF from vmlinux: invalid argument when compiling older kernels.

Problem
As a kernel developer it is not uncommon to bisect in which kernel release and with which git commit a problem first occured. However when compiling 5.x kernels with the current version of the build environment, the following error can happen:

  KSYMS   .tmp_vmlinux.kallsyms1.S
  AS      .tmp_vmlinux.kallsyms1.S
  LD      .tmp_vmlinux.kallsyms2
  KSYMS   .tmp_vmlinux.kallsyms2.S
  AS      .tmp_vmlinux.kallsyms2.S
  LD      vmlinux
  BTFIDS  vmlinux
FAILED: load BTF from vmlinux: Invalid argument
make: *** [Makefile:1187: vmlinux] Error 255
make: *** Deleting file 'vmlinux'
It turns out the problem is caused CONFIG_DEBUG_INFO_BTF configuration option and when the pahole utility has been updated to 1.24. If the version of the pahole utility is less than 1.24, the build is successful. The new pahole (version 1.24) generates by default the new BTF_KIND_ENUM64 BTF tag, which is not supported by stable kernel.

Solution
There are three ways to address the problem.

1. Disable the configuration setting
By disabling the `CONFIG_DEBUG_INFO_BTF` configuration option, the kernel will build successfully. However this has a downside, as BPF programs cannot be run.

2. Downgrade the pahole package
The pahole program is part of the pahole package. If your Linux distribution still provides an earlier version, it is the easiest to downgrade to the previous version.

2. Patch pahole-flags.sh
The new pahole provides the `--skip_encoding_btf_enum64` option to skip `BTF_KIND_ENUM64` generation. By specifying this option, a stable kernel will be created.
Applying the following patch to `scripts/pahole-flags.sh` will achieve enabling the new flag.
```
--- a/scripts/pahole-flags.sh
+++ b/scripts/pahole-flags.sh
@@ -14,4 +14,8 @@ if [ "${pahole_ver}" -ge "118" ] && [ "$
 	extra_paholeopt="${extra_paholeopt} --skip_encoding_btf_vars"
 fi
 
+if [ "${pahole_ver}" -ge "124" ]; then
+	extra_paholeopt="${extra_paholeopt} --skip_encoding_btf_enum64"
+fi
+
 echo ${extra_paholeopt}
```

# install kernel modules to location we specify
```
export STG_MYKMODS=../staging/rootfs/my_kernel_modules
make INSTALL_MOD_PATH=${STG_MYKMODS} modules_install
```

