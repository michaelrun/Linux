
// libmy_pthread.c - ULTRA HIGH PERFORMANCE VERSION
#include "libmy_pthread.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/syscall.h>
#include <dlfcn.h>
#include <syslog.h>
#include <sys/time.h>

// Ultra-aggressive configuration for minimum latency
#define SPIN_CHECK_FREQUENCY 1  // Check EVERY iteration for absolute minimum latency
#define TARGET_SPIN_TIME_US 10  // Reduced to 50μs
#define MIN_SPIN_ITERATIONS 100
#define MAX_SPIN_ITERATIONS 50000

static uint32_t cached_spin_iterations = 0;

// Architecture-specific optimizations
#if defined(__x86_64__) || defined(__i386__)
    #define MEMORY_ORDER_RELAXED memory_order_relaxed  // x86 has strong memory model
    #define MEMORY_ORDER_ACQUIRE memory_order_relaxed
    #define MEMORY_ORDER_RELEASE memory_order_relaxed
    #define MEMORY_ORDER_ACQ_REL memory_order_relaxed
#else
    #define MEMORY_ORDER_RELAXED memory_order_relaxed
    #define MEMORY_ORDER_ACQUIRE memory_order_acquire
    #define MEMORY_ORDER_RELEASE memory_order_release
    #define MEMORY_ORDER_ACQ_REL memory_order_acq_rel
#endif

// Minimal pause instruction - architecture optimized
static inline void minimal_pause(void) {
#if defined(__x86_64__) || defined(__i386__)
    // On x86, just a compiler barrier is often enough due to strong memory model
    // Introduce a few pauses for better back-off and HT fairness
#if 0
    for (int i = 0; i < 4; i++) { // e.g., 4 pauses
        __asm__ __volatile__("pause" ::: "memory");
    }
#endif
    //__asm__ __volatile__("pause" ::: "memory");
    __asm__ __volatile__("" ::: "memory");

#elif defined(__aarch64__)
    __asm__ __volatile__("yield" ::: "memory");
#else
    __asm__ __volatile__("" ::: "memory");
#endif
}

// Ultra-fast CPU frequency detection
static uint64_t get_cpu_frequency_fast(void) {
#if 0
    static uint64_t cached_freq = 0;
    if (cached_freq != 0) {
        return cached_freq;
    }

    // Quick calibration using rdtsc
    struct timespec start, end;
    uint64_t tsc_start, tsc_end;

    clock_gettime(CLOCK_MONOTONIC, &start);
#if defined(__x86_64__) || defined(__i386__)
    __asm__ __volatile__("rdtsc" : "=A"(tsc_start));
#else
    tsc_start = 0;
#endif

    usleep(10000); // 10ms calibration

    clock_gettime(CLOCK_MONOTONIC, &end);
#if defined(__x86_64__) || defined(__i386__)
    __asm__ __volatile__("rdtsc" : "=A"(tsc_end));
#else
    tsc_end = 1;
#endif

    if (tsc_end > tsc_start) {
        uint64_t ns_elapsed = (end.tv_sec - start.tv_sec) * 1000000000ULL +
                             (end.tv_nsec - start.tv_nsec);
        uint64_t tsc_elapsed = tsc_end - tsc_start;
        cached_freq = (tsc_elapsed * 1000000000ULL) / ns_elapsed;
        fprintf(stderr, "====cached_freq: %d\n", cached_freq);
    } else {
        cached_freq = 3600000000ULL; // 3.6GHz fallback
    }
#endif
    static uint64_t cached_freq = 3600000000ULL; // 3.6GHz test

    return cached_freq;
}

// Calculate minimal spin iterations
static uint32_t calculate_minimal_spin_iterations(void) {
    static uint32_t cached_iterations = 0;
    if (cached_iterations != 0) {
        return cached_iterations;
    }

    uint64_t cpu_freq = get_cpu_frequency_fast();

    // Target: 10μs with minimal overhead
    // Assume 1 cycle per minimal pause (compiler barrier only)
    uint64_t target_cycles = (cpu_freq * TARGET_SPIN_TIME_US) / 1000000;
    cached_iterations = (uint32_t)target_cycles;

    // Bounds checking
    if (cached_iterations < MIN_SPIN_ITERATIONS) {
        cached_iterations = MIN_SPIN_ITERATIONS;
    }
    if (cached_iterations > MAX_SPIN_ITERATIONS) {
        cached_iterations = MAX_SPIN_ITERATIONS;
    }

    return cached_iterations;
}

// Ultra-minimal spinning state - optimized for cache efficiency
typedef struct {
    // Pack everything into single cache line (64 bytes)
    atomic_int signal_count;      // 4 bytes
    atomic_int waiting_threads;   // 4 bytes
    atomic_long successful_spins; // 8 bytes
    atomic_long failed_spins;     // 8 bytes
    atomic_long total_spins;      // 8 bytes
    char padding[32];             // Pad to 64 bytes
} __attribute__((aligned(64))) ultra_spin_state_t;

// Smaller hash table for better cache locality
#define ULTRA_HASH_SIZE 256
static ultra_spin_state_t spin_states[ULTRA_HASH_SIZE] __attribute__((aligned(64)));
static atomic_int initialized = ATOMIC_VAR_INIT(0);

// Initialize spinning states
void my_pthread_init_spin_states(void) {
    int expected = 0;

    if (atomic_compare_exchange_strong(&initialized, &expected, 1)) {
        for (int i = 0; i < ULTRA_HASH_SIZE; i++) {
            atomic_init(&spin_states[i].signal_count, 0);
            atomic_init(&spin_states[i].waiting_threads, 0);
            atomic_init(&spin_states[i].successful_spins, 0);
            atomic_init(&spin_states[i].failed_spins, 0);
            atomic_init(&spin_states[i].total_spins, 0);
        }
    }
    cached_spin_iterations = calculate_minimal_spin_iterations();
}

// Ultra-fast hash function
static inline int ultra_hash_cond(pthread_cond_t *cond) {
    uintptr_t addr = (uintptr_t)cond;
    return (int)((addr >> 6) & (ULTRA_HASH_SIZE - 1)); // Divide by 64 for cache line alignment
}

// Get spinning state
static inline ultra_spin_state_t* get_ultra_spin_state(pthread_cond_t *cond) {
    my_pthread_init_spin_states();
    return &spin_states[ultra_hash_cond(cond)];
}


// Ultra-fast signal consumption - absolute minimum overhead
static inline int ultra_fast_consume_signal(atomic_int *signal_count) {
    int current_val;

    // Use a CAS loop to atomically decrement the count only if it is positive.
    do {
        // 1. Load the current value (ACQUIRE ensures visibility of the signal)
        current_val = atomic_load_explicit(signal_count, MEMORY_ORDER_ACQUIRE);

        // 2. Check the value
        if (current_val <= 0) {
            return 0; // No signal, exit loop
        }

        // 3. Try to decrement the count using CAS
        // If successful, we consume the signal and exit the loop.
        // If failed (another thread modified it), we loop and try again.
    } while (!atomic_compare_exchange_weak_explicit(
        signal_count,              // Pointer to the atomic variable
        &current_val,              // Expected value (is updated on failure)
        current_val - 1,           // New value
        MEMORY_ORDER_ACQ_REL,      // Success ordering (Consume + Release)
        MEMORY_ORDER_RELAXED));    // Failure ordering (Relaxed retry)

    return 1; // Successfully consumed a signal
}


// Ultra-minimal spinning wait - absolute minimum latency
static int ultra_minimal_spin_wait(pthread_cond_t *cond, int *signal_consumed) {
    ultra_spin_state_t *state = get_ultra_spin_state(cond);

    // Register as waiting (minimal overhead)
    atomic_fetch_add_explicit(&state->waiting_threads, 1, MEMORY_ORDER_RELAXED);

    //uint32_t spin_iterations = calculate_minimal_spin_iterations();
    int got_signal = 0;
    //volatile uint32_t *signal_ptr = &state->signal_count;
    // ULTRA-TIGHT spinning loop - check EVERY iteration
    //old
    //for (uint32_t i = 0; i < cached_spin_iterations; i++) {
    for (uint32_t i = cached_spin_iterations; i > 0; i--) {
            if (ultra_fast_consume_signal(&state->signal_count)) {
                    got_signal = 1;
                    *signal_consumed = 1;
                    break;
            }
            //_mm_monitor(signal_ptr, 0, 0);
#if 0
            if ((cached_spin_iterations & 32) == 0) {  // Faster than modulo
                    // Check for signal EVERY iteration for absolute minimum latency
                    if (ultra_fast_consume_signal(&state->signal_count)) {
                            got_signal = 1;
                            *signal_consumed = 1;
                            break;
                    }
            }
#endif
            // Minimal pause - just compiler barrier on x86
            minimal_pause();
    }

    // Update statistics (minimal overhead)
    atomic_fetch_sub_explicit(&state->waiting_threads, 1, MEMORY_ORDER_RELAXED);
    if (got_signal) {
        atomic_fetch_add_explicit(&state->successful_spins, 1, MEMORY_ORDER_RELAXED);
    } else {
        atomic_fetch_add_explicit(&state->failed_spins, 1, MEMORY_ORDER_RELAXED);
    }

    atomic_fetch_add(&state->total_spins, cached_spin_iterations);

    //fprintf(stderr, "libmy_pthread: pure_spin_wait: tid: %ld, cond: %p, state->successful_spins: %ld, state->failed_spins: %ld, state->total_spins: %ld\n", pthread_self(), cond, state->successful_spins, state->failed_spins, state->total_spins);

    return got_signal ? 0 : ETIMEDOUT;
}

// Ultra-fast pthread_cond_wait
int my_pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex) {
    // Release mutex
    int unlock_result = pthread_mutex_unlock(mutex);
    if (unlock_result != 0) {
        return unlock_result;
    }

    // Minimal memory barrier
#if !defined(__x86_64__) && !defined(__i386__)
    atomic_thread_fence(memory_order_release);
#endif

    int signal_consumed = 0;
    ultra_minimal_spin_wait(cond, &signal_consumed);
#if 0
    if (!signal_consumed) {
        // If we timed out (didn't get a signal), yield the CPU
        // for better scheduling before attempting to re-lock.
        sched_yield();
    }
#endif

    // Minimal memory barrier
#if !defined(__x86_64__) && !defined(__i386__)
    atomic_thread_fence(memory_order_acquire);
#endif

    // Reacquire mutex
    pthread_mutex_lock(mutex);

    // Always return 0 for POSIX compliance
    return 0;
}

// Ultra-fast pthread_cond_timedwait
int my_pthread_cond_timedwait(pthread_cond_t *cond, pthread_mutex_t *mutex, const struct timespec *abstime) {
    struct timespec start_time;
    if (clock_gettime(CLOCK_REALTIME, &start_time) != 0) {
        return errno;
    }

    // Check if already timed out
    if (start_time.tv_sec > abstime->tv_sec ||
        (start_time.tv_sec == abstime->tv_sec && start_time.tv_nsec >= abstime->tv_nsec)) {
        return ETIMEDOUT;
    }

    // Release mutex
    int unlock_result = pthread_mutex_unlock(mutex);
    if (unlock_result != 0) {
        return unlock_result;
    }

#if !defined(__x86_64__) && !defined(__i386__)
    atomic_thread_fence(memory_order_release);
#endif

    // Calculate timeout in microseconds for faster comparison
    long long timeout_us = ((long long)(abstime->tv_sec - start_time.tv_sec)) * 1000000LL +
                          ((abstime->tv_nsec - start_time.tv_nsec) / 1000);

    // Spin with timeout checking
    while (timeout_us > 0) {
        int signal_consumed = 0;
        if (ultra_minimal_spin_wait(cond, &signal_consumed) == 0 && signal_consumed) {
#if !defined(__x86_64__) && !defined(__i386__)
            atomic_thread_fence(memory_order_acquire);
#endif
            pthread_mutex_lock(mutex);
            return 0;
        }

        // Quick timeout check (every 10μs)
        timeout_us -= TARGET_SPIN_TIME_US;
    }

#if !defined(__x86_64__) && !defined(__i386__)
    atomic_thread_fence(memory_order_acquire);
#endif
    pthread_mutex_lock(mutex);
    return ETIMEDOUT;
}

// Ultra-fast pthread_cond_broadcast
int my_pthread_cond_broadcast(pthread_cond_t *cond) {
    ultra_spin_state_t *state = get_ultra_spin_state(cond);
    // Add MAX_SIGNAL_COUNT to ensure all waiters are woken.
    atomic_fetch_add_explicit(&state->signal_count, MAX_SIGNAL_COUNT, MEMORY_ORDER_RELEASE);
    return 0;
}

// Ultra-fast pthread_cond_signal
int my_pthread_cond_signal(pthread_cond_t *cond) {
    ultra_spin_state_t *state = get_ultra_spin_state(cond);
    // Just add one signal, regardless of the waiter count.
    atomic_fetch_add_explicit(&state->signal_count, 1, MEMORY_ORDER_RELEASE);
    return 0;
}

// Library constructor
__attribute__((constructor))
static void library_init(void) {
    openlog("libmy_pthread", LOG_PID, LOG_USER);

    uint64_t cpu_freq = get_cpu_frequency_fast();
    cached_spin_iterations = calculate_minimal_spin_iterations();

    syslog(LOG_INFO, "libmy_pthread: ULTRA HIGH PERFORMANCE library loaded");
    syslog(LOG_INFO, "libmy_pthread: CPU frequency: %.2f GHz", cpu_freq / 1000000000.0);
    syslog(LOG_INFO, "libmy_pthread: Spin iterations: %u (target: %dμs)", cached_spin_iterations, TARGET_SPIN_TIME_US);
    syslog(LOG_INFO, "libmy_pthread: Check frequency: EVERY iteration (minimum latency)");

    my_pthread_init_spin_states();
}

// Performance statistics
void my_pthread_spin_destroy(void) {
    if (atomic_load(&initialized)) {
        long total_successful = 0, total_failed = 0;

        for (int i = 0; i < ULTRA_HASH_SIZE; i++) {
            total_successful += atomic_load(&spin_states[i].successful_spins);
            total_failed += atomic_load(&spin_states[i].failed_spins);
        }

        if (total_successful + total_failed > 0) {
            syslog(LOG_INFO, "libmy_pthread: Success rate: %.1f%% (%ld/%ld)",
                   (double)total_successful * 100.0 / (total_successful + total_failed),
                   total_successful, total_successful + total_failed);
        }
    }
}

__attribute__((destructor))
static void library_cleanup(void) {
    my_pthread_spin_destroy();
    syslog(LOG_INFO, "libmy_pthread: ULTRA HIGH PERFORMANCE library unloaded");
    closelog();
}
