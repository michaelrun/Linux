# Network interface virtualization and passthrough
## Check current netowrk card
` lspci |grep -i eth `
![image](https://github.com/michaelrun/Linux/assets/19384327/3161fa5f-d5f0-4921-b269-f1b7ea2d5a8f)

## Check current netowrk interface information
` ls -lrt /sys/class/net/ `
![image](https://github.com/michaelrun/Linux/assets/19384327/a481d4f9-4803-4e0a-81b5-f52311209a88)

## Check netowrk card on which numanode
`  lspci -vms 0000:b8:00 `
![image](https://github.com/michaelrun/Linux/assets/19384327/5adb85dd-b60a-42d3-922c-a3e7d822706e)

## Set VF numbers per PF
` echo 2 > devices/pci0000:b7/0000:b7:01.0/0000:b8:00.1/sriov_numvfs`
