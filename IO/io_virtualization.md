# to check devices that supports SR-IOV
`lspci -v`
![image](https://github.com/michaelrun/Linux/assets/19384327/01fed3f0-4f55-42df-9740-823b393ce29c)

# types of virtualized IO
`virtio` is a virtualized driver that lives in the KVM Hypervisor.\
An `emulated-IO` is for example the virtual Ethernet Controller that you will find in a Virtual Machine.\
`direct I/O` is the concept of having a direct I/O operation inside a VM. An example can be a Direct Memory Access to the memory space of a VM.\
`I/O passthrough`, or PCI-passthrough, is the technology to expose a physical device inside a VM, bypassing the management of the Hypervisor. The VM will see the physical hardware directly. For that the corresponding driver should be installed in the guest OS. As the hypervisor will be bypassed, the performance with this device inside the VM is way better than with an emulated device.

`SR-IOV` for Single Root-I/O Virtualization is a technology where you can expose a physical device in several copies, which can be used individualy. For example with a NIC (Network Interface Card), using SR-IOV you can create several copies of the same device. Therefore, you can use all those copies inside different VMs as if you had several physical device. The performance are increased as with a PCI-Passthrough. \
It's not exactly a copy of the same device.\
The goal of the PCI-SIG SR-IOV specification is to standardize on a way of bypassing the VMM’s involvement in data movement by providing independent memory space, interrupts, and DMA streams for each virtual machine. SR-IOV architecture is designed to allow a device to support multiple Virtual Functions (VFs) and much attention was placedon minimizing the hardware cost of each additional function. SR-IOV introduces two new function types:\
`Physical Functions (PFs)`:These are full PCIe functions that include the SR-IOV Extended Capability. The capability is used to configure and manage the SR-IOV functionality.\
`Virtual Functions (VFs)`: These are ‘lightweight’ PCIe functions that contain the resources necessary for data movement but have a carefully minimized set of configuration resources.\
