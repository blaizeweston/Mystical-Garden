#include "mob_policy.h"

#include <math.h>
#include <cpuid.h>
#include <stdlib.h>
#include <string.h>

#define MAGIC "MOBW"
#define FORMAT_VERSION 1u

typedef struct {
    int rows;
    int cols;
    float *columns; /* cols * rows values, one column after another. */
    float *bias;
} Dense;

struct MobPolicy {
    MobPolicyLayout layout;
    Dense self_encoder, enemy_encoder, ally_encoder, leader_encoder, trunk_a, trunk_b, heads;
    Dense gate_input, gate_hidden;
    int self_input;
    int joined_size;
    int trunk_size;
    float *scratch;
    float *self_row, *joined, *trunk_mid, *trunk, *gates_i, *gates_h, *head_input, *next;
    float *memory;
};

typedef void (*AddScaled)(float *out, const float *column, float scale, int count);

/* The same element-wise additions run at either width, so both give identical results. */
static void add_scaled_base(float *out, const float *column, float scale, int count) {
    for (int i = 0; i < count; i++) out[i] += column[i] * scale;
}

__attribute__((target("avx2")))
static void add_scaled_avx2(float *out, const float *column, float scale, int count) {
    for (int i = 0; i < count; i++) out[i] += column[i] * scale;
}

static AddScaled add_scaled = add_scaled_base;

/* Query CPU and OS vector support directly. This avoids a hidden dependency
 * on libgcc's __cpu_model when building the extension with another Clang driver. */
static int supports_avx2(void) {
    unsigned int eax, ebx, ecx, edx;
    if (__get_cpuid_max(0, NULL) < 7) return 0;
    __cpuid(1, eax, ebx, ecx, edx);
    if ((ecx & (1u << 27)) == 0 || (ecx & (1u << 28)) == 0) return 0;
    unsigned int xcr0_low, xcr0_high;
    __asm__ volatile ("xgetbv" : "=a"(xcr0_low), "=d"(xcr0_high) : "c"(0));
    if ((xcr0_low & 6u) != 6u) return 0;
    __cpuid_count(7, 0, eax, ebx, ecx, edx);
    return (ebx & (1u << 5)) != 0;
}

static void choose_kernel(void) {
    add_scaled = supports_avx2() ? add_scaled_avx2 : add_scaled_base;
}

static void dense_apply(const Dense *layer, const float *input, float *out) {
    memcpy(out, layer->bias, (size_t)layer->rows * sizeof(float));
    for (int c = 0; c < layer->cols; c++) {
        float value = input[c];
        if (value != 0.0f) add_scaled(out, layer->columns + (size_t)c * (size_t)layer->rows, value, layer->rows);
    }
}

static inline void relu(float *values, int count) {
    for (int i = 0; i < count; i++) {
        if (values[i] < 0.0f) values[i] = 0.0f;
    }
}

static inline float sigmoid(float value) { return 1.0f / (1.0f + expf(-value)); }

typedef struct {
    const uint8_t *cursor;
    const uint8_t *end;
    int failed;
} Reader;

static uint32_t read_u32(Reader *reader) {
    if (reader->end - reader->cursor < 4) {
        reader->failed = 1;
        return 0;
    }
    uint32_t value;
    memcpy(&value, reader->cursor, 4);
    reader->cursor += 4;
    return value;
}

typedef struct {
    const uint8_t *name;
    uint32_t name_length;
    uint32_t rows;
    uint32_t cols;
    const uint8_t *data;
} Tensor;

#define MAX_TENSORS 32

static const Tensor *find_tensor(const Tensor *tensors, uint32_t count, const char *name) {
    size_t length = strlen(name);
    for (uint32_t i = 0; i < count; i++) {
        if (tensors[i].name_length == length && memcmp(tensors[i].name, name, length) == 0) return &tensors[i];
    }
    return NULL;
}

static MpResult dense_load(Dense *layer, const Tensor *tensors, uint32_t count, const char *weight_name, const char *bias_name,
                           int rows, int cols) {
    const Tensor *weight = find_tensor(tensors, count, weight_name);
    const Tensor *bias = find_tensor(tensors, count, bias_name);
    if (weight == NULL || bias == NULL) return MP_ERR_LAYOUT;
    if ((int)weight->rows != rows || (int)weight->cols != cols || (int)bias->rows != rows || bias->cols != 1) return MP_ERR_LAYOUT;
    size_t cells = (size_t)rows * (size_t)cols;
    layer->rows = rows;
    layer->cols = cols;
    layer->columns = malloc(cells * sizeof(float));
    layer->bias = malloc((size_t)rows * sizeof(float));
    if (layer->columns == NULL || layer->bias == NULL) return MP_ERR_MEMORY;
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            memcpy(&layer->columns[(size_t)c * (size_t)rows + (size_t)r],
                   weight->data + ((size_t)r * (size_t)cols + (size_t)c) * sizeof(float), sizeof(float));
        }
    }
    memcpy(layer->bias, bias->data, (size_t)rows * sizeof(float));
    return MP_OK;
}

static void dense_free(Dense *layer) {
    free(layer->columns);
    free(layer->bias);
}

void mp_destroy(MobPolicy *policy) {
    if (policy == NULL) return;
    dense_free(&policy->self_encoder);
    dense_free(&policy->enemy_encoder);
    dense_free(&policy->ally_encoder);
    dense_free(&policy->leader_encoder);
    dense_free(&policy->trunk_a);
    dense_free(&policy->trunk_b);
    dense_free(&policy->heads);
    dense_free(&policy->gate_input);
    dense_free(&policy->gate_hidden);
    free(policy->scratch);
    free(policy->memory);
    free(policy);
}

static int layout_valid(const MobPolicyLayout *layout) {
    if (layout == NULL || layout->observation_size <= 0 || layout->logits <= 0 || layout->hidden <= 0 || layout->capacity <= 0 ||
        layout->self_range_count <= 0 || layout->self_range_count > MP_MAX_SELF_RANGES ||
        layout->enemy_stride <= 0 || layout->enemy_repeat <= 0 || layout->ally_stride <= 0 || layout->ally_repeat <= 0 ||
        layout->leader_stride <= 0) {
        return 0;
    }
    for (int i = 0; i < layout->self_range_count; i++) {
        if (layout->self_offset[i] < 0 || layout->self_size[i] <= 0 ||
            layout->self_offset[i] + layout->self_size[i] > layout->observation_size) {
            return 0;
        }
    }
    return layout->enemy_offset >= 0 && layout->enemy_offset + layout->enemy_stride * layout->enemy_repeat <= layout->observation_size &&
           layout->ally_offset >= 0 && layout->ally_offset + layout->ally_stride * layout->ally_repeat <= layout->observation_size &&
           layout->leader_offset >= 0 && layout->leader_offset + layout->leader_stride <= layout->observation_size;
}

static MpResult build_layers(MobPolicy *p, const Tensor *t, uint32_t n) {
    const Tensor *enemy = find_tensor(t, n, "enemy_encoder.weight");
    const Tensor *ally = find_tensor(t, n, "ally_encoder.weight");
    const Tensor *leader = find_tensor(t, n, "leader_encoder.weight");
    const Tensor *self = find_tensor(t, n, "self_encoder.weight");
    const Tensor *first = find_tensor(t, n, "trunk_a.weight");
    if (enemy == NULL || ally == NULL || leader == NULL || self == NULL || first == NULL) return MP_ERR_LAYOUT;
    const MobPolicyLayout *l = &p->layout;
    p->joined_size = (int)self->rows + l->enemy_repeat * (int)enemy->rows + l->ally_repeat * (int)ally->rows + (int)leader->rows;
    p->trunk_size = (int)first->rows;
    MpResult r;
    if ((r = dense_load(&p->self_encoder, t, n, "self_encoder.weight", "self_encoder.bias", (int)self->rows, p->self_input)) != MP_OK) return r;
    if ((r = dense_load(&p->enemy_encoder, t, n, "enemy_encoder.weight", "enemy_encoder.bias", (int)enemy->rows, l->enemy_stride)) != MP_OK) return r;
    if ((r = dense_load(&p->ally_encoder, t, n, "ally_encoder.weight", "ally_encoder.bias", (int)ally->rows, l->ally_stride)) != MP_OK) return r;
    if ((r = dense_load(&p->leader_encoder, t, n, "leader_encoder.weight", "leader_encoder.bias", (int)leader->rows, l->leader_stride)) != MP_OK) return r;
    if ((r = dense_load(&p->trunk_a, t, n, "trunk_a.weight", "trunk_a.bias", p->trunk_size, p->joined_size)) != MP_OK) return r;
    if ((r = dense_load(&p->trunk_b, t, n, "trunk_b.weight", "trunk_b.bias", p->trunk_size, p->trunk_size)) != MP_OK) return r;
    if ((r = dense_load(&p->gate_input, t, n, "recurrent.weight_ih", "recurrent.bias_ih", 3 * l->hidden, p->trunk_size)) != MP_OK) return r;
    if ((r = dense_load(&p->gate_hidden, t, n, "recurrent.weight_hh", "recurrent.bias_hh", 3 * l->hidden, l->hidden)) != MP_OK) return r;
    return dense_load(&p->heads, t, n, "heads.weight", "heads.bias", l->logits, p->trunk_size + l->hidden);
}

static MpResult allocate_scratch(MobPolicy *p) {
    const MobPolicyLayout *l = &p->layout;
    size_t total = (size_t)p->self_input + (size_t)p->joined_size + 2 * (size_t)p->trunk_size + 6 * (size_t)l->hidden +
                   (size_t)p->trunk_size + (size_t)l->hidden + (size_t)l->hidden;
    p->scratch = malloc(total * sizeof(float));
    p->memory = calloc((size_t)l->capacity * (size_t)l->hidden, sizeof(float));
    if (p->scratch == NULL || p->memory == NULL) return MP_ERR_MEMORY;
    float *cursor = p->scratch;
    p->self_row = cursor; cursor += p->self_input;
    p->joined = cursor; cursor += p->joined_size;
    p->trunk_mid = cursor; cursor += p->trunk_size;
    p->trunk = cursor; cursor += p->trunk_size;
    p->gates_i = cursor; cursor += 3 * l->hidden;
    p->gates_h = cursor; cursor += 3 * l->hidden;
    p->head_input = cursor; cursor += p->trunk_size + l->hidden;
    p->next = cursor;
    return MP_OK;
}

MpResult mp_load(const uint8_t *bytes, size_t size, const char *expected_hash, const MobPolicyLayout *layout, MobPolicy **out) {
    if (bytes == NULL || expected_hash == NULL || out == NULL || !layout_valid(layout)) return MP_ERR_ARGUMENT;
    *out = NULL;
    choose_kernel();
    Reader reader = {bytes, bytes + size, 0};
    if (size < 4 || memcmp(bytes, MAGIC, 4) != 0) return MP_ERR_FILE;
    reader.cursor += 4;
    if (read_u32(&reader) != FORMAT_VERSION || reader.failed) return MP_ERR_FILE;
    if (reader.end - reader.cursor < MP_HASH_LENGTH) return MP_ERR_FILE;
    if (memcmp(reader.cursor, expected_hash, MP_HASH_LENGTH) != 0) return MP_ERR_SCHEMA;
    reader.cursor += MP_HASH_LENGTH;
    uint32_t count = read_u32(&reader);
    if (reader.failed || count == 0 || count > MAX_TENSORS) return MP_ERR_FILE;
    Tensor tensors[MAX_TENSORS];
    for (uint32_t i = 0; i < count; i++) {
        tensors[i].name_length = read_u32(&reader);
        tensors[i].rows = read_u32(&reader);
        tensors[i].cols = read_u32(&reader);
        if (reader.failed || tensors[i].name_length > 128 || tensors[i].rows > 65536 || tensors[i].cols > 65536) return MP_ERR_FILE;
        size_t payload = (size_t)tensors[i].rows * (size_t)tensors[i].cols * sizeof(float);
        if ((size_t)(reader.end - reader.cursor) < (size_t)tensors[i].name_length + payload) return MP_ERR_FILE;
        tensors[i].name = reader.cursor;
        reader.cursor += tensors[i].name_length;
        tensors[i].data = reader.cursor;
        reader.cursor += payload;
    }
    MobPolicy *policy = calloc(1, sizeof(*policy));
    if (policy == NULL) return MP_ERR_MEMORY;
    policy->layout = *layout;
    for (int i = 0; i < layout->self_range_count; i++) policy->self_input += layout->self_size[i];
    MpResult result = build_layers(policy, tensors, count);
    if (result == MP_OK) result = allocate_scratch(policy);
    if (result != MP_OK) {
        mp_destroy(policy);
        return result;
    }
    *out = policy;
    return MP_OK;
}

int mp_logits(const MobPolicy *policy) { return policy->layout.logits; }
int mp_hidden(const MobPolicy *policy) { return policy->layout.hidden; }
int mp_observation_size(const MobPolicy *policy) { return policy->layout.observation_size; }

/* Matches torch.nn.GRUCell: reset gate, update gate, then the new hidden value. */
static void gru_step(MobPolicy *p, const float *input, const float *hidden, float *next) {
    int size = p->layout.hidden;
    dense_apply(&p->gate_input, input, p->gates_i);
    dense_apply(&p->gate_hidden, hidden, p->gates_h);
    for (int i = 0; i < size; i++) {
        float reset = sigmoid(p->gates_i[i] + p->gates_h[i]);
        float update = sigmoid(p->gates_i[size + i] + p->gates_h[size + i]);
        float value = tanhf(p->gates_i[2 * size + i] + reset * p->gates_h[2 * size + i]);
        next[i] = (1.0f - update) * value + update * hidden[i];
    }
}

static void run_row(MobPolicy *p, const float *obs, const float *hidden, float *logits, float *next) {
    const MobPolicyLayout *l = &p->layout;
    float *cursor = p->self_row;
    for (int i = 0; i < l->self_range_count; i++) {
        memcpy(cursor, obs + l->self_offset[i], (size_t)l->self_size[i] * sizeof(float));
        cursor += l->self_size[i];
    }
    float *joined = p->joined;
    dense_apply(&p->self_encoder, p->self_row, joined);
    relu(joined, p->self_encoder.rows);
    joined += p->self_encoder.rows;
    for (int i = 0; i < l->enemy_repeat; i++) {
        dense_apply(&p->enemy_encoder, obs + l->enemy_offset + i * l->enemy_stride, joined);
        relu(joined, p->enemy_encoder.rows);
        joined += p->enemy_encoder.rows;
    }
    for (int i = 0; i < l->ally_repeat; i++) {
        dense_apply(&p->ally_encoder, obs + l->ally_offset + i * l->ally_stride, joined);
        relu(joined, p->ally_encoder.rows);
        joined += p->ally_encoder.rows;
    }
    dense_apply(&p->leader_encoder, obs + l->leader_offset, joined);
    relu(joined, p->leader_encoder.rows);
    dense_apply(&p->trunk_a, p->joined, p->trunk_mid);
    relu(p->trunk_mid, p->trunk_size);
    dense_apply(&p->trunk_b, p->trunk_mid, p->trunk);
    relu(p->trunk, p->trunk_size);
    gru_step(p, p->trunk, hidden, next);
    memcpy(p->head_input, p->trunk, (size_t)p->trunk_size * sizeof(float));
    memcpy(p->head_input + p->trunk_size, next, (size_t)l->hidden * sizeof(float));
    dense_apply(&p->heads, p->head_input, logits);
}

void mp_forward(MobPolicy *policy, const float *obs, const float *hidden, int rows, float *logits, float *next_hidden) {
    const MobPolicyLayout *l = &policy->layout;
    for (int row = 0; row < rows; row++) {
        run_row(policy, obs + row * l->observation_size, hidden + row * l->hidden, logits + row * l->logits, next_hidden + row * l->hidden);
    }
}

MpResult mp_step(MobPolicy *policy, const float *obs, const float *slots, int rows, float *logits) {
    const MobPolicyLayout *l = &policy->layout;
    for (int row = 0; row < rows; row++) {
        if (!(slots[row] >= 0.0f && slots[row] < (float)l->capacity)) return MP_ERR_ARGUMENT;
    }
    for (int row = 0; row < rows; row++) {
        float *memory = policy->memory + (size_t)slots[row] * (size_t)l->hidden;
        run_row(policy, obs + row * l->observation_size, memory, logits + row * l->logits, policy->next);
        memcpy(memory, policy->next, (size_t)l->hidden * sizeof(float));
    }
    return MP_OK;
}

void mp_reset_slot(MobPolicy *policy, int slot) {
    if (policy == NULL || slot < 0 || slot >= policy->layout.capacity) return;
    memset(policy->memory + (size_t)slot * (size_t)policy->layout.hidden, 0, (size_t)policy->layout.hidden * sizeof(float));
}

uint64_t mp_memory_hash(const MobPolicy *policy) {
    uint64_t hash = 14695981039346656037ULL;
    if (policy == NULL) return hash;
    const uint8_t *bytes = (const uint8_t *)policy->memory;
    size_t count = (size_t)policy->layout.capacity * (size_t)policy->layout.hidden * sizeof(float);
    for (size_t i = 0; i < count; i++) {
        hash ^= bytes[i];
        hash *= 1099511628211ULL;
    }
    return hash;
}
