### What is MG-LRU?

**Multi-Gen LRU (MG-LRU)** is a modern page-reclamation algorithm in the Linux kernel designed to improve memory management performance, especially under high memory pressure. It's a significant improvement over the traditional two-list (active/inactive) LRU implementation. Instead of just two lists, MG-LRU organizes pages into multiple "generations" based on their access recency. The "youngest" generation contains the most recently accessed pages, while the "oldest" generation contains the least recently accessed pages. When the system needs to reclaim memory, it evicts pages from the oldest generation first.

----------------------------------------------------------------

### How MG-LRU Improves Performance

MG-LRU improves page cache performance, particularly in heavily used scenarios, by making smarter, more efficient page-reclamation decisions. This reduces the number of "refaults" (pages being reloaded from disk shortly after being evicted) and lowers CPU overhead. Here's a detailed breakdown of how it works:

#### Finer-Grained Recency Tracking
The core of MG-LRU's advantage is its use of multiple generations. The traditional two-list LRU mechanism often struggles with workloads that have large working sets. A page could be accessed once, put on the inactive list, and then evicted even if it was accessed fairly recently. With MG-LRU's multi-generational approach, the kernel has a much more accurate representation of a page's "hotness" or age. Pages are moved to younger generations when accessed and gradually "age" to older generations over time. This makes the eviction choices more intelligent, preventing useful pages from being prematurely swapped out.

#### Reduced CPU Overhead
The traditional LRU implementation relies on a system daemon, `kswapd`, which frequently scans memory to find pages to reclaim. This process can be CPU-intensive and cache-unfriendly. MG-LRU uses a more efficient approach that significantly reduces this overhead.

* **Efficient Scans:** Instead of scanning all of physical memory, MG-LRU walks through process page tables. This method is more efficient because it focuses on the pages actually mapped and in use by processes.
* **Bloom Filters:** To further optimize the scans, MG-LRU uses **Bloom filters** to quickly identify which parts of the page tables are likely to contain recently accessed pages. This avoids wasting time scanning sparse or cold memory regions.
* **Parallelism:** The design is more scalable and lock-efficient, allowing it to perform better on systems with many CPUs, as multiple processes can walk their page tables in parallel.



#### Intelligent Decision-Making
MG-LRU incorporates advanced heuristics and feedback loops to optimize its behavior.

* **Refault Monitoring:** MG-LRU tracks when a page it has evicted is quickly brought back into memory (a refault). This information is fed into a **PID controller** (Proportional-Integral-Derivative) that adjusts the page-reclamation policy. If a certain type of page (e.g., file-backed or anonymous memory) is being refaulted too often, the algorithm will adjust its strategy to be less aggressive in evicting those pages. This self-correcting mechanism helps it learn and adapt to different workloads.
* **Working Set Protection:** MG-LRU can protect the "working set" of an application from eviction for a specific time, preventing lags and "jank" (stuttering) by ensuring that the most-used pages remain in memory.

In summary, MG-LRU improves performance in heavy-use scenarios by:

* **Organizing pages into multiple generations** for more precise tracking of access recency.
* **Reducing CPU overhead** with efficient page table scans and Bloom filters.
* **Making smarter eviction choices** with a PID controller that learns from refaults.

Both traditional two-list LRU (Least Recently Used) and the more modern Multi-Gen LRU (MG-LRU) are page-reclamation algorithms in the Linux kernel. They are designed to decide which memory pages to keep in the RAM and which to evict (swap to disk or discard). The primary difference is that traditional LRU uses a simple two-list system to approximate recency, while MG-LRU uses multiple generations and a more sophisticated feedback-based approach to make smarter eviction decisions.

***

### Comparison Table: MG-LRU vs. Traditional LRU

| Feature | Traditional Active/Inactive LRU | Multi-Gen LRU (MG-LRU) |
| :--- | :--- | :--- |
| **Data Structure** | Two lists: "Active" (frequently used pages) and "Inactive" (less-frequently used pages). | Multiple "generations" (or lists) that represent a spectrum of access recency. A page's generation number indicates its age. |
| **Recency Tracking** | Coarse-grained. Pages are either considered "hot" or "cold." Pages are moved between lists based on access flags. | Fine-grained. Pages are moved between multiple generations based on access frequency. This provides a much more accurate picture of a page's "hotness." |
| **Eviction Policy** | Pages are reclaimed from the "Inactive" list. If a page in the inactive list is accessed, it gets moved back to the "Active" list. This can be prone to "refaults" (evicting pages that are soon needed again). | Pages are reclaimed from the oldest generation first. The algorithm uses a **PID controller** to learn from its mistakes and prevent refaults.  It adjusts its behavior dynamically based on real-world performance. |
| **CPU Overhead** | Can be high under memory pressure. The kernel's `kswapd` process must frequently scan memory and walk the LRU lists, which can be inefficient and cause performance "jank." | Significantly lower CPU usage. The algorithm uses **Bloom filters** to quickly identify "hot" areas of memory, allowing it to skip large portions of uninteresting pages during scans. |
| **Performance in High-Pressure Scenarios** | Often struggles with large, memory-intensive workloads. It can make poor eviction choices, leading to performance degradation and thrashing (constant swapping). | Excels in these scenarios. Its intelligent and adaptable policy leads to fewer evictions of useful pages, lower refault rates, and better overall system responsiveness. It's especially beneficial for systems like Android and ChromeOS. |

The main takeaway is that while traditional LRU is a simple and serviceable solution, MG-LRU represents a significant advancement by making page management decisions based on richer, more precise data, resulting in a more efficient and responsive system under demanding conditions.

The video provides a high-level overview of the benefits and concepts behind MG-LRU in the Linux kernel.

[Multi-Gen LRU: Current Status & Next Steps - Jesse Barnes, Rom Lemarchand - YouTube](https://www.youtube.com/watch?v=K4w1QVygRbI)
http://googleusercontent.com/youtube_content/0
