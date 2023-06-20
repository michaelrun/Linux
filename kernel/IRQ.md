![image](https://github.com/michaelrun/Linux/assets/19384327/497e97ba-190c-4f8c-be57-0c9e9541c0f5)

## Page table
currently device and CPU are using the same page table, that is when iommu uses iotlb while mmu uses tlb, when they do flush, they all affect page table.
## DMA
device address convert \
dmar page fault (->handle page fault) \
mlockall( virtual maps to physical) \
In this case, DMA can use mlockall or memset  buffer to have pages have physical addresss in advance to avoid IRQ.
