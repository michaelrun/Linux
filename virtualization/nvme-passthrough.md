# NvME Passthrough
## mount nvme
`mount /dev/nvme0n3p1 /mnt/nvme0`

## check nvme device
`lsblk`
## check nvme device id
`lspci |grep -i nvme`\
`nvme --list -vv`

## Hide/ unhide SSD driver for NVME device on host vfio-pci.sh
### Hide nvme device to vfio-pci
`./vfio-pci.sh -h 3b:00.0`

### optionally, if you want unhide or use nvme normally on host
`./vfio-pci.sh -u 3b:00.0 -d nvme`

## check if nvme device switch to vfio-pci driver
`lspci -s 3b:00.0 -k`

![image](https://github.com/michaelrun/Linux/assets/19384327/1a31757a-de69-43ac-a62e-35b944caa499)



## start qemu
```
/usr/bin/qemu-system-x86_64 -accel kvm -name process=tdxvm,debug-threads=on -m 2G -vga none -monitor pty -no-hpet -nodefaults -device virtio-blk-pci,drive=hd0,bootindex=1 -drive if=none,id=hd0,file=nvme://0000:3b:00.0/1,format=qcow2  -monitor telnet:127.0.0.1:9001,server,nowait -bios ${VM_EFI_DIR}/OVMF.fd -object tdx-guest,sept-ve-disable,id=tdx -cpu host,-kvm-steal-time,pmu=off -machine q35,kernel_irqchip=split,confidential-guest-support=tdx -device virtio-net-pci,netdev=mynet0 -smp 1 -netdev user,id=mynet0,hostfwd=tcp::10026-:22 -kernel /${VM_KERNEL_DIR}/vmlinuz-jammy -append "root=/dev/vda1 rw console=hvc0" -chardev stdio,id=mux,mux=on,logfile=/home/intel/TDXww01/tdx-tools-2023ww01.rdc/vm_log_nvme_pt.log -device virtio-serial,romfile= -device virtconsole,chardev=mux -monitor chardev:mux -serial chardev:mux -nographic
```





