#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h> // For mmap, munmap
#include <string.h>   // For memset
#include <errno.h>    // For errno

// Define the size of the memory block to allocate (e.g., 256 MB)
// This must be a multiple of the huge page size (e.g., 2MB)
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
        if (strstr(line, "HugePages_Total:") != NULL || strstr(line, "HugePages_Free:") != NULL) {
            printf("Current %s", line);
        }
    }
    fclose(fp);
}

int main() {
    void *addr;
    int ret;

    printf("--- Explicit Huge Page Allocation Demo ---\n");

    // 1. Print initial HugePages_Total and HugePages_Free
    printf("\n--- Before allocation ---\n");
    print_hugepages_free();

    // 2. Allocate a large block of memory using MAP_HUGETLB
    // MAP_ANONYMOUS: The mapping is not backed by any file.
    // MAP_PRIVATE: Create a private copy-on-write mapping.
    // MAP_HUGETLB: Request a huge page mapping.
    // PROT_READ | PROT_WRITE: Memory is readable and writable.
    // The -1 for fd and 0 for offset are for anonymous mappings.
    addr = mmap(NULL, MEMORY_SIZE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB, -1, 0);
    if (addr == MAP_FAILED) {
        perror("mmap with MAP_HUGETLB failed. Make sure explicit huge pages are configured and available.");
        printf("Possible reasons:\n");
        printf("1. No explicit huge pages configured (HugePages_Total is 0).\n");
        printf("2. Not enough free explicit huge pages (HugePages_Free is too low).\n");
        printf("3. Memory_Size is not a multiple of Hugepagesize (e.g., 2MB).\n");
        printf("4. Permissions issue.\n");
        return EXIT_FAILURE;
    }
    printf("\nAllocated %lu bytes of explicit huge page memory at address %p\n", (unsigned long)MEMORY_SIZE, addr);

    // Writing to the allocated memory to ensure pages are faulted in
    // This is less critical for MAP_HUGETLB as pages are typically reserved immediately,
    // but good practice to ensure they are accessible.
    printf("Writing to allocated memory...\n");
    memset(addr, 0, MEMORY_SIZE);
    printf("Memory written.\n");

    // 3. Pause and allow user to check system status
    printf("\n--- After allocation ---\n");
    printf("Please check 'HugePages_Free' in /proc/meminfo in another terminal.\n");
    printf("Example command: 'cat /proc/meminfo | grep HugePages_Free'\n");
    printf("Press Enter to unmap the memory and exit...\n");
    getchar(); // Wait for user input

    // 4. Unmap the memory
    ret = munmap(addr, MEMORY_SIZE);
    if (ret == -1) {
        perror("munmap failed");
        return EXIT_FAILURE;
    }
    printf("\nUnmapped %lu bytes of memory from address %p\n", (unsigned long)MEMORY_SIZE, addr);

    // 5. Print final HugePages_Total and HugePages_Free
    printf("\n--- After unmapping ---\n");
    print_hugepages_free();

    printf("\nDemo finished.\n");

    return EXIT_SUCCESS;
}
