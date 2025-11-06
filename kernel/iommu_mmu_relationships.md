# IOMMU/MMU and VA/IOVA mappings #

* Application only knows VA - 0x7ffd50000000
*  Driver performs VA→IOVA translation - gets 0x3000
* GPU only sees IOVA - uses 0x3000 in its commands
* Both VA and IOVA map to same physical memory - 0x12345000

<img width="1792" height="3108" alt="deepseek_mermaid_20251106_9e064d" src="https://github.com/user-attachments/assets/ebedc1ad-8516-4688-9efa-7e082f22c9a6" />


# SVM enabled devices #
Key Changes with SVM
1. Eliminated Components
   
❌ IOVA space - No separate device address space

❌ VA→IOVA translation - Driver doesn't need to convert addresses

❌ IOMMU page tables for IOVA - IOMMU uses CPU page tables directly

2. New Components
   
✅ PASID in every transaction - Identifies which process's page tables to use

✅ ATS (Optional) - GPU can cache translations like CPU TLB

✅ Page Request Interface - GPU can handle page faults

## SVM-Enabled Architecture ##
<img width="2680" height="3171" alt="deepseek_mermaid_20251106_af3c7e (1)" src="https://github.com/user-attachments/assets/a828300e-fe1d-49da-ba44-ba8bf6e8e2ae" />

## Detailed SVM Data Flow ##

<img width="5434" height="3514" alt="deepseek_mermaid_20251106_7f2029" src="https://github.com/user-attachments/assets/32124890-306a-42ba-a6fe-5f4397b62453" />

