IOMMU/MMU and VA/IOVA mappings

1. Application only knows VA - 0x7ffd50000000
2. Driver performs VA→IOVA translation - gets 0x3000
3. GPU only sees IOVA - uses 0x3000 in its commands
4. Both VA and IOVA map to same physical memory - 0x12345000

![deepseek_mermaid_20251106_3f3ec3](https://github.com/user-attachments/assets/4660562b-aafc-487c-ac1d-73cb654adc4d)


<img width="1792" height="3108" alt="deepseek_mermaid_20251106_9e064d" src="https://github.com/user-attachments/assets/ebedc1ad-8516-4688-9efa-7e082f22c9a6" />



