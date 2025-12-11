// libmy_pthread.h - CORRECTED PURE SPINNING VERSION
#ifndef LIBMY_PTHREAD_H
#define LIBMY_PTHREAD_H

#include <pthread.h>
#include <time.h>
#include <errno.h>

#ifdef __cplusplus
extern "C" {
#endif

// Public API - Override standard pthread condition variable functions
int my_pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex);
void my_pthread_init_spin_states();
int my_pthread_cond_timedwait(pthread_cond_t *cond, pthread_mutex_t *mutex, const struct timespec *abstime);
int my_pthread_cond_broadcast(pthread_cond_t *cond);
int my_pthread_cond_signal(pthread_cond_t *cond);

void my_pthread_spin_destroy();

#ifdef __cplusplus
}
#endif


// Configuration constants
#define TARGET_SPIN_CYCLES 180000
#define ADAPTIVE_HASH_SIZE 1024
#define MAX_SIGNAL_COUNT 1000

#endif /* LIBMY_PTHREAD_H */
