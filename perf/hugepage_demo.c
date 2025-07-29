#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h> // For mmap, munmap, madvise
#include <string.h>   // For memset
#include <errno.h>    // For errno

// Define the size of the memory block to allocate (e.g., 256 MB)
#define MEMORY_SIZE (256 * 1024 * 1024) // 256 MB

// Function to check and print HugePages_Free from /proc/meminfo
void print_hugepages_free() {
    FILE *fp;
    char line[256];

    fp = fopen("/proc/meminfo", "r");
    if (fp == NULL) {
        perror("Error opening /proc/meminfo");
        return;
    }

    while (fgets(line, sizeof(line), fp) != NULL) {
        if (strstr(line, "HugePages_Free:") != NULL) {
            printf("Current %s", line);
            break;
        }
    }
    fclose(fp);
}

int main() {
    void *addr;
    int ret;

    printf("--- Huge Page Allocation Demo ---\n");

    // 1. Print initial HugePages_Free
    printf("\n--- Before allocation ---\n");
    print_hugepages_free();

    // 2. Allocate a large block of memory
    // MAP_ANONYMOUS: The mapping is not backed by any file.
    // MAP_PRIVATE: Create a private copy-on-write mapping.
    // PROT_READ | PROT_WRITE: Memory is readable and writable.
    addr = mmap(NULL, MEMORY_SIZE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (addr == MAP_FAILED) {
        perror("mmap failed");
        return EXIT_FAILURE;
    }
    printf("\nAllocated %lu bytes of memory at address %p\n", (unsigned long)MEMORY_SIZE, addr);

    // Write to the allocated memory to ensure pages are faulted in (important for THP)
    // Accessing the memory forces the kernel to allocate physical pages.
    printf("Writing to allocated memory to fault in pages...\n");
    memset(addr, 0, MEMORY_SIZE);
    printf("Memory written.\n");

    // 3. Advise the kernel to use huge pages for this memory region
    // MADV_HUGEPAGE: Request that the specified pages be backed by huge pages.
    // This is a hint; the kernel may or may not fulfill the request.
    ret = madvise(addr, MEMORY_SIZE, MADV_HUGEPAGE);
    if (ret == -1) {
        perror("madvise(MADV_HUGEPAGE) failed. THP might not be enabled or available.");
        printf("Check /sys/kernel/mm/transparent_hugepage/enabled. It should be 'always' or 'madvise'.\n");
        // Continue even if madvise fails, to still demonstrate munmap
    } else {
        printf("madvise(MADV_HUGEPAGE) successful. Kernel will attempt to use huge pages.\n");
    }

    // 4. Pause and allow user to check system status
    printf("\n--- After allocation and madvise ---\n");
    printf("Please check 'HugePages_Free' in /proc/meminfo in another terminal.\n");
    printf("Example command: 'cat /proc/meminfo | grep HugePages_Free'\n");
    printf("Press Enter to unmap the memory and exit...\n");
    getchar(); // Wait for user input

    // 5. Unmap the memory
    ret = munmap(addr, MEMORY_SIZE);
    if (ret == -1) {
        perror("munmap failed");
        return EXIT_FAILURE;
    }
    printf("\nUnmapped %lu bytes of memory from address %p\n", (unsigned long)MEMORY_SIZE, addr);

    // 6. Print final HugePages_Free
    printf("\n--- After unmapping ---\n");
    print_hugepages_free();

    printf("\nDemo finished.\n");

    return EXIT_SUCCESS;
}
