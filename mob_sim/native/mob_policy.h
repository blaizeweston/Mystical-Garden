#ifndef MOB_POLICY_H
#define MOB_POLICY_H
/* Engine-free runner for the exported mob policy: Linear, ReLU and GRU layers in batches. */

#include <stddef.h>
#include <stdint.h>

#define MP_HASH_LENGTH 64
#define MP_MAX_SELF_RANGES 16

typedef enum {
    MP_OK = 0,
    MP_ERR_ARGUMENT = 1,
    MP_ERR_MEMORY = 2,
    MP_ERR_FILE = 3,
    MP_ERR_SCHEMA = 4,
    MP_ERR_LAYOUT = 5
} MpResult;

typedef struct {
    int observation_size;
    int self_range_count;
    int self_offset[MP_MAX_SELF_RANGES];
    int self_size[MP_MAX_SELF_RANGES];
    int enemy_offset, enemy_stride, enemy_repeat;
    int ally_offset, ally_stride, ally_repeat;
    int leader_offset, leader_stride;
    int logits;
    int hidden;
    int capacity;
} MobPolicyLayout;

typedef struct MobPolicy MobPolicy;

/* Refuses a model whose embedded schema hash differs from expected_hash. */
MpResult mp_load(const uint8_t *bytes, size_t size, const char *expected_hash, const MobPolicyLayout *layout, MobPolicy **out);
void mp_destroy(MobPolicy *policy);

int mp_logits(const MobPolicy *policy);
int mp_hidden(const MobPolicy *policy);
int mp_observation_size(const MobPolicy *policy);

/* Stateless run: reads rows of obs and hidden, writes rows of logits and next hidden. */
void mp_forward(MobPolicy *policy, const float *obs, const float *hidden, int rows, float *logits, float *next_hidden);
/* Stateful run: each row uses and updates the recurrent memory stored for its slot. */
MpResult mp_step(MobPolicy *policy, const float *obs, const float *slots, int rows, float *logits);
void mp_reset_slot(MobPolicy *policy, int slot);
uint64_t mp_memory_hash(const MobPolicy *policy);

#endif
