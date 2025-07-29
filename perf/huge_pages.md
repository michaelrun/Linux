You've hit upon the core distinction that often causes confusion! Let's break it down:

You're right to be confused because the terminology and mechanisms can be tricky.

Here's the clarification:

1.  **`madvise(MADV_HUGEPAGE)` is indeed for Transparent Huge Pages (THP).**
    * When you use `madvise(MADV_HUGEPAGE)`, you are giving the kernel a *hint* that a particular region of *already allocated anonymous memory* (like memory obtained via `malloc` or `mmap` without `MAP_HUGETLB`) would benefit from being backed by huge pages.
    * The kernel then *transparently* tries to promote the 4KB pages backing that region into 2MB huge pages. This happens in the background, and the application doesn't need to know the physical page size.
    * The memory consumed by THP is reflected in `/proc/meminfo` under `AnonHugePages`.

2.  **Not using `madvise` does NOT automatically mean explicit huge pages.**
    * If you allocate anonymous memory (e.g., with `malloc` or `mmap(..., MAP_ANONYMOUS, ...)`) and *don't* call `madvise(MADV_HUGEPAGE)`, that memory is still eligible for THP if your system's `transparent_hugepage/enabled` setting is `always`. The kernel will just try to apply THP automatically.
    * To get **explicit huge pages**, you *must* use the `MAP_HUGETLB` flag with `mmap()`. This is the key difference.

3.  **Regarding `hugetlbfs` not being mounted:**
    * The `explicit_hugepage_demo.c` program uses `mmap(..., MAP_ANONYMOUS | MAP_HUGETLB, ...)`.
    * This specific combination (`MAP_ANONYMOUS | MAP_HUGETLB`) requests anonymous huge pages **directly from the pool of pre-allocated huge pages** that you set up using `sudo sysctl -w vm.nr_hugepages=...`.
    * **You do NOT need `hugetlbfs` to be mounted for this particular anonymous `MAP_HUGETLB` usage.**
    * `hugetlbfs` is a special filesystem that you would mount if you wanted to:
        * Create **file-backed huge page mappings** (e.g., for shared memory segments between processes).
        * Manage the huge page pool via file operations (e.g., creating files on `hugetlbfs` to reserve pages).

**In summary:**

* **Transparent Huge Pages (THP):**
    * Kernel-managed, automatic.
    * Hinted by `madvise(MADV_HUGEPAGE)` or automatic if `transparent_hugepage/enabled` is `always`.
    * Consumes `AnonHugePages`.
    * **No `MAP_HUGETLB` in `mmap`. No `hugetlbfs` mount needed.**

* **Explicit Huge Pages (hugetlbfs-backed or anonymous `MAP_HUGETLB`):**
    * Requires administrator pre-allocation (`vm.nr_hugepages`).
    * Application *explicitly requests* them using `mmap` with `MAP_HUGETLB`.
    * Consumes `HugePages_Free`.
    * **Can be anonymous (as in the `explicit_hugepage_demo`) or file-backed (if `hugetlbfs` is mounted and used).**

Your `explicit_hugepage_demo.c` program correctly demonstrates the consumption of explicit huge pages because it uses `MAP_HUGETLB`, which draws from the `HugePages_Free` pool, regardless of whether `hugetlbfs` is mounted for file-backed operations.
