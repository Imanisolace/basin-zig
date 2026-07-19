#include "basin.h"
#include <stdlib.h>
#include <pthread.h>
#include <string.h>

#define HASHES_PER_THREAD 1000
#define OUTPUT_SIZE 32

typedef struct {
    const uint8_t* data;
    size_t len;
    uint8_t* output_base;
    size_t thread_id;
} ThreadArg;

static void* hash_thread(void* arg) {
    ThreadArg* t = (ThreadArg*)arg;
    uint8_t* out = t->output_base + t->thread_id * HASHES_PER_THREAD * OUTPUT_SIZE;
    
    for(size_t i = 0; i < HASHES_PER_THREAD; i++) {
        // hash the same input multiple times to simulate workload
        basin_poseidon_hash(t->data, t->len, out + i * OUTPUT_SIZE);
    }
    return NULL;
}

int basin_parallel_process(const uint8_t* data, size_t len, int threads) {
    if(!data || threads <= 0) return -1;
    
    pthread_t* tids = malloc(sizeof(pthread_t) * threads);
    ThreadArg* args = malloc(sizeof(ThreadArg) * threads);
    if(!tids ||!args) return -1;
    
    // output buffer so we don't write to NULL
    size_t total_out = (size_t)threads * HASHES_PER_THREAD * OUTPUT_SIZE;
    uint8_t* outputs = malloc(total_out);
    if(!outputs) { free(tids); free(args); return -1; }
    memset(outputs, 0, total_out);
    
    for(int i = 0; i < threads; i++) {
        args[i].data = data;
        args[i].len = len;
        args[i].output_base = outputs;
        args[i].thread_id = i;
        pthread_create(&tids[i], NULL, hash_thread, &args[i]);
    }
    for(int i = 0; i < threads; i++) {
        pthread_join(tids[i], NULL);
    }
    
    free(tids); 
    free(args); 
    free(outputs);
    return 0;
}