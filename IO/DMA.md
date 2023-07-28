DMA
Daniel Aarno, Jakob Engblom, in Software and System Development using Virtual Platforms, 2015

DMA Device Description
The DMA device can act as a bus master and can read and write physical memory. The DMA device can be used to offload the software and processors from copying large chunks of data from one place in memory to another. This DMA device supports two modes of operation: contiguous transfer and scatter-gather lists. In contiguous transfer mode the DMA device copies a number of bytes sequentially, starting at one physical address and transferring the same number of bytes to another physical address. In scatter-gather mode the bytes are instead copied from a data structure known as a scatter-gather list into a contiguous area of memory starting at the destination address. The scatter-gather list is described later in this section.

The DMA device is controlled through a set of 32-bit memory-mapped registers described in Table 7.1. The device uses big-endian (network) byte order and little-endian bit order.

Table 7.1. Register Overview

Offset	Register	Documentation
00	DMA control	Control register
04	DMA source	Source address
08	DMA destination	Destination address
The DMA control register consists of the following fields, where the numbers in brackets indicate the bit or bit range in little-endian bit order:

•
EN[31]—Enable DMA. Enable the DMA device by writing a 1 to this field. If the device is not enabled, registers are still updated but no side effects occur.

•
SWT[30]—Software Transfer Trigger. Starts a DMA transaction if the EN bit is set. The result of writing a 1 to SWT when there is a transaction in progress is undefined.

•
ECI[29]—Enable Completion Interrupt. If set to 1, an interrupt is generated when a transfer completes. If set to 0, no interrupt is generated.

•
TC[28]—Transfer Complete. This bit is used to indicate whether a transfer has completed. This bit is set to 1 by the DMA device when a transfer is completed, and if the ECI bit is also set to 1, an interrupt is raised at this time. Software is only allowed to write a 0 to this bit to clear the status. Clearing the TC bit also lowers any interrupt that is currently active.

•
SG[27]—Scatter-Gather List Input. If set to 1, the DMA source register points to the first entry in a scatter-gather list and not a contiguous block of data.

•
ERR[26]—DMA Transfer Error. This bit is set by the DMA device if an error has occurred during the transfer—for example, if an incorrect scatter-gather data structure has been supplied to the device.

•
TS[15:0]—Transfer Size. The number of 32-bit words to transfer from the address (or scatter-gather list) pointed to by the DMA source register to the address pointed to by the DMA destination register.

Functional Description
To initiate a DMA copy operation, software first writes a physical address to the DMA source and DMA destination registers. The address in the DMA destination register is the start address where the data will be copied and is always a contiguous block. The DMA source register can hold the address to either a contiguous block or to a scatter-gather list. The SG bit in the DMA control register determines how the DMA device interprets the data at the source address.

To start the copy operation, the software writes the DMA control register with a nonzero value for the EN bit, the SWT bit, and the TS field. Upon completion the DMA controller sets the TC bit and, if the ECI bit is set, raises an interrupt.

If the device is configured in scatter-gather mode (SG bit set), the copy procedure works as follows. In a scatter-gather list, data is spread out over several blocks. These blocks can be of two types: data blocks and extension blocks. A data block is simply a chunk of application-specific data, while an extension block contains references to other blocks. Extension blocks can only be referenced from the last row in another extension block. An example of a scatter-gather data structure is shown in Figure 7.1.


Sign in to download full-size image
Figure 7.1. Scatter-gather list data structure.

The layout of an extension block is shown in Figure 7.2. The individual fields are as follows:


Sign in to download full-size image
Figure 7.2. Scatter-gather list block descriptor.

•
Address: Pointer to a block.

•
Length: The length of valid data at the address+offset.

•
Offset: Data begins at the address+offset.

•
Flags: If bit 0 is set, address points to an extension block. If bit 0 is not set, address points to a data block.

When using the scatter-gather mode, the DMA source register contains the address of a scatter-gather head block. The head block is illustrated in Figure 7.3. The head block points to the first scatter-gather block, which is always an extension block. The length field is the length of valid data in the first extension block.


Sign in to download full-size image

[DMA](https://www.sciencedirect.com/topics/computer-science/direct-memory-access)
