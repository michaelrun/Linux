# How to review current kernels installed on Ubuntu 22.04
`./grub-menu.sh long` \
or \
`./grub-menu.sh short`

# Change virtual machine kernel version
If you boot virtual machine using qemu or libvirt, you installed some other versions of guest kernels, maybe you want to change to other kernel, only change /etc/default/grub, then update-grub, reboot is not enought, you have to update the image, then restart the vm domain by virsh create

```
#!/usr/bin/bash

set -ex
LEGCY_IMAGE="legcykernelintdximage.qcow2"

ARGS=" -a ${LEGCY_IMAGE} -x"

# Setup guest environments
ARGS+=" --edit '/etc/default/grub:s/GRUB_DEFAULT=0/GRUB_DEFAULT=1>2/'"
ARGS+=" --run-command 'update-grub'"
echo "${ARGS}"
eval virt-customize "${ARGS}"
```

