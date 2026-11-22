#include "mob_nav.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define FINE_CELL 0.25f
#define FLOW_CELL 0.5f
#define CLEAR_CAP 6.0f
/* Bilinear sampling slightly overestimates clearance beside sharp corners. */
#define SKIN 0.06f
#define PASS_CLEARANCE 0.42f
#define WALL_BAND 0.9f
#define WALL_COST 2.0f
#define SEPARATION 0.85f
#define SEPARATION_GAIN 0.65f
#define LOS_MARGIN 0.12f
#define LOS_REFRESH 4
#define HASH_CELL 1.0f
#define BUCKETS 64
#define BUCKET_WIDTH 0.125f
#define FIELD_BUDGET 1
#define FAR_OFFSET 16000
#define UNREACHED 1e30f
#define GOAL_SEARCH 12
#define FLOW_SEARCH 8

typedef struct {
    float *t;
    float *dx;
    float *dz;
    float x;
    float z;
    uint64_t solved_at;
    int goal;
    uint8_t solved;
    uint8_t dirty;
} Field;

typedef struct {
    float t;
    int cell;
    int next;
} Entry;

struct MobNav {
    int max_agents;
    int max_targets;
    int agent_count;
    int target_count;
    int floor_w;
    int floor_h;
    int fine_w;
    int fine_h;
    int flow_w;
    int flow_h;
    int hash_w;
    int hash_h;
    int baked;
    float origin_x;
    float origin_z;
    float *clear;
    float *flow_cost;
    float *rects;
    int rect_count;
    Field *fields;
    Entry *pool;
    int pool_size;
    int free_entry;
    int head[BUCKETS];
    float *x;
    float *z;
    float *next_x;
    float *next_z;
    float *speed;
    float *radius;
    float *stop;
    float *offset_x;
    float *offset_z;
    int *target;
    uint8_t *mode;
    uint8_t *active;
    uint8_t *sight;
    /* Per agent: nonzero flies on the air layer. */
    uint8_t *layer;
    /* The air layer's grids and fields. It holds no agents of its own. */
    struct MobNav *air;
    int *hash_start;
    int *hash_items;
    int hash_stale;
    uint64_t tick;
    uint64_t solves;
};

static inline int floor_int(float value) {
    int whole = (int)value;
    return whole - (value < (float)whole);
}

static inline float min_float(float a, float b) { return a < b ? a : b; }
static inline float max_float(float a, float b) { return a > b ? a : b; }
static inline int clamp_int(int v, int low, int high) { return v < low ? low : (v > high ? high : v); }

static void release_grids(MobNav *nav) {
    free(nav->clear);
    free(nav->flow_cost);
    free(nav->rects);
    free(nav->pool);
    free(nav->hash_start);
    nav->clear = NULL;
    nav->flow_cost = NULL;
    nav->rects = NULL;
    nav->rect_count = 0;
    nav->pool = NULL;
    nav->hash_start = NULL;
    for (int i = 0; i < nav->max_targets; i++) {
        free(nav->fields[i].t);
        free(nav->fields[i].dx);
        free(nav->fields[i].dz);
        nav->fields[i].t = nav->fields[i].dx = nav->fields[i].dz = NULL;
    }
    nav->baked = 0;
}

void mn_destroy(MobNav *nav) {
    if (nav == NULL) return;
    if (nav->fields != NULL) release_grids(nav);
    free(nav->fields);
    free(nav->x);
    free(nav->z);
    free(nav->next_x);
    free(nav->next_z);
    free(nav->speed);
    free(nav->radius);
    free(nav->stop);
    free(nav->offset_x);
    free(nav->offset_z);
    free(nav->target);
    free(nav->mode);
    free(nav->active);
    free(nav->sight);
    free(nav->layer);
    free(nav->hash_items);
    mn_destroy(nav->air);
    free(nav);
}

MobNav *mn_create(int max_agents, int max_targets) {
    if (max_agents <= 0 || max_targets <= 0) return NULL;
    MobNav *nav = calloc(1, sizeof(*nav));
    if (nav == NULL) return NULL;
    size_t n = (size_t)max_agents;
    nav->max_agents = max_agents;
    nav->max_targets = max_targets;
    nav->fields = calloc((size_t)max_targets, sizeof(*nav->fields));
    nav->x = calloc(n, sizeof(float));
    nav->z = calloc(n, sizeof(float));
    nav->next_x = calloc(n, sizeof(float));
    nav->next_z = calloc(n, sizeof(float));
    nav->speed = calloc(n, sizeof(float));
    nav->radius = calloc(n, sizeof(float));
    nav->stop = calloc(n, sizeof(float));
    nav->offset_x = calloc(n, sizeof(float));
    nav->offset_z = calloc(n, sizeof(float));
    nav->target = calloc(n, sizeof(int));
    nav->mode = calloc(n, 1);
    nav->active = calloc(n, 1);
    nav->sight = calloc(n, 1);
    nav->layer = calloc(n, 1);
    nav->hash_items = calloc(n, sizeof(int));
    if (!nav->fields || !nav->x || !nav->z || !nav->next_x || !nav->next_z || !nav->speed ||
        !nav->radius || !nav->stop || !nav->offset_x || !nav->offset_z || !nav->target ||
        !nav->mode || !nav->active || !nav->sight || !nav->layer || !nav->hash_items) {
        mn_destroy(nav);
        return NULL;
    }
    return nav;
}

/* Eight-point sequential signed distance transform storing the nearest seed offset. */
static inline void edt_compare(int16_t *ox, int16_t *oz, int cell, int other, int dx, int dz) {
    if (ox[other] == FAR_OFFSET) return;
    int cx = ox[other] + dx;
    int cz = oz[other] + dz;
    int candidate = cx * cx + cz * cz;
    int current = ox[cell] == FAR_OFFSET ? 2147483647 : ox[cell] * ox[cell] + oz[cell] * oz[cell];
    if (candidate < current) {
        ox[cell] = (int16_t)cx;
        oz[cell] = (int16_t)cz;
    }
}

static void edt_run(const uint8_t *blocked, uint8_t seed_value, int w, int h, int16_t *ox, int16_t *oz) {
    int total = w * h;
    for (int i = 0; i < total; i++) {
        int seed = blocked[i] == seed_value;
        ox[i] = seed ? 0 : FAR_OFFSET;
        oz[i] = seed ? 0 : FAR_OFFSET;
    }
    for (int z = 0; z < h; z++) {
        for (int x = 0; x < w; x++) {
            int i = x + z * w;
            if (x > 0) edt_compare(ox, oz, i, i - 1, 1, 0);
            if (z > 0) {
                edt_compare(ox, oz, i, i - w, 0, 1);
                if (x > 0) edt_compare(ox, oz, i, i - w - 1, 1, 1);
                if (x < w - 1) edt_compare(ox, oz, i, i - w + 1, -1, 1);
            }
        }
        for (int x = w - 2; x >= 0; x--) edt_compare(ox, oz, x + z * w, x + 1 + z * w, -1, 0);
    }
    for (int z = h - 1; z >= 0; z--) {
        for (int x = w - 1; x >= 0; x--) {
            int i = x + z * w;
            if (x < w - 1) edt_compare(ox, oz, i, i + 1, -1, 0);
            if (z < h - 1) {
                edt_compare(ox, oz, i, i + w, 0, -1);
                if (x > 0) edt_compare(ox, oz, i, i + w - 1, 1, -1);
                if (x < w - 1) edt_compare(ox, oz, i, i + w + 1, -1, -1);
            }
        }
        for (int x = 1; x < w; x++) edt_compare(ox, oz, x + z * w, x - 1 + z * w, 1, 0);
    }
}

/* Distance from a cell centre to the nearest edge of the cell at the stored offset. */
static inline float box_distance(int dx, int dz) {
    float ax = max_float((float)abs(dx) - 0.5f, 0.0f) * FINE_CELL;
    float az = max_float((float)abs(dz) - 0.5f, 0.0f) * FINE_CELL;
    return sqrtf(ax * ax + az * az);
}

static MnResult bake_clearance(MobNav *nav, const uint8_t *mask, const float *rects, int rect_count) {
    int w = nav->fine_w, h = nav->fine_h, total = w * h;
    uint8_t *blocked = malloc((size_t)total);
    int16_t *ox = malloc((size_t)total * sizeof(int16_t));
    int16_t *oz = malloc((size_t)total * sizeof(int16_t));
    if (!blocked || !ox || !oz) {
        free(blocked);
        free(ox);
        free(oz);
        return MN_ERR_MEMORY;
    }
    for (int z = 0; z < h; z++) {
        for (int x = 0; x < w; x++) {
            int edge = x == 0 || z == 0 || x == w - 1 || z == h - 1;
            blocked[x + z * w] = edge || mask[x / 2 + (z / 2) * nav->floor_w] == 0;
        }
    }
    edt_run(blocked, 1, w, h, ox, oz);
    for (int i = 0; i < total; i++) {
        nav->clear[i] = ox[i] == FAR_OFFSET ? CLEAR_CAP : min_float(box_distance(ox[i], oz[i]), CLEAR_CAP);
    }
    edt_run(blocked, 0, w, h, ox, oz);
    for (int i = 0; i < total; i++) {
        if (blocked[i]) nav->clear[i] = ox[i] == FAR_OFFSET ? -CLEAR_CAP : -min_float(box_distance(ox[i], oz[i]), CLEAR_CAP);
    }
    free(blocked);
    free(ox);
    free(oz);
    /* Barriers are exact: take the signed distance to each rectangle at the cell centre. */
    for (int r = 0; r < rect_count; r++) {
        float x0 = rects[r * 4], z0 = rects[r * 4 + 1], x1 = rects[r * 4 + 2], z1 = rects[r * 4 + 3];
        int ax = clamp_int(floor_int((x0 - CLEAR_CAP - nav->origin_x) / FINE_CELL), 0, w - 1);
        int bx = clamp_int(floor_int((x1 + CLEAR_CAP - nav->origin_x) / FINE_CELL), 0, w - 1);
        int az = clamp_int(floor_int((z0 - CLEAR_CAP - nav->origin_z) / FINE_CELL), 0, h - 1);
        int bz = clamp_int(floor_int((z1 + CLEAR_CAP - nav->origin_z) / FINE_CELL), 0, h - 1);
        for (int z = az; z <= bz; z++) {
            float pz = nav->origin_z + ((float)z + 0.5f) * FINE_CELL;
            float dz = max_float(z0 - pz, pz - z1);
            for (int x = ax; x <= bx; x++) {
                float px = nav->origin_x + ((float)x + 0.5f) * FINE_CELL;
                float dx = max_float(x0 - px, px - x1);
                float ox_d = max_float(dx, 0.0f), oz_d = max_float(dz, 0.0f);
                float signed_distance = sqrtf(ox_d * ox_d + oz_d * oz_d) + min_float(max_float(dx, dz), 0.0f);
                if (signed_distance < nav->clear[x + z * w]) nav->clear[x + z * w] = signed_distance;
            }
        }
    }
    return MN_OK;
}

static inline float clear_at(const MobNav *nav, float x, float z) {
    float fx = (x - nav->origin_x) / FINE_CELL - 0.5f;
    float fz = (z - nav->origin_z) / FINE_CELL - 0.5f;
    int ix = floor_int(fx), iz = floor_int(fz);
    if (ix < 0 || iz < 0 || ix >= nav->fine_w - 1 || iz >= nav->fine_h - 1) return -1.0f;
    float u = fx - (float)ix, v = fz - (float)iz;
    const float *c = nav->clear + ix + iz * nav->fine_w;
    const float *d = c + nav->fine_w;
    float top = c[0] + (c[1] - c[0]) * u;
    float bottom = d[0] + (d[1] - d[0]) * u;
    return top + (bottom - top) * v;
}

static inline void clear_gradient(const MobNav *nav, float x, float z, float *gx, float *gz) {
    const float e = FINE_CELL * 0.5f;
    float dx = clear_at(nav, x + e, z) - clear_at(nav, x - e, z);
    float dz = clear_at(nav, x, z + e) - clear_at(nav, x, z - e);
    float length = sqrtf(dx * dx + dz * dz);
    *gx = length > 1e-5f ? dx / length : 0.0f;
    *gz = length > 1e-5f ? dz / length : 0.0f;
}

float mn_clearance(const MobNav *nav, float x, float z) {
    return nav != NULL && nav->baked ? clear_at(nav, x, z) : -1.0f;
}

static inline int slab_clip(float start, float delta, float low, float high, float *enter, float *leave) {
    if (fabsf(delta) < 1e-7f) return start >= low && start <= high;
    float a = (low - start) / delta, b = (high - start) / delta;
    if (a > b) {
        float swap = a;
        a = b;
        b = swap;
    }
    *enter = max_float(*enter, a);
    *leave = min_float(*leave, b);
    return *enter <= *leave;
}

static inline int segment_hits_rect(float x0, float z0, float dx, float dz, const float *rect, float radius) {
    float enter = 0.0f, leave = 1.0f;
    return slab_clip(x0, dx, rect[0] - radius, rect[2] + radius, &enter, &leave) &&
           slab_clip(z0, dz, rect[1] - radius, rect[3] + radius, &enter, &leave);
}

/* Barriers are tested exactly. Floor edges are sphere traced along the clearance
 * field, so open space takes very few samples. */
int mn_line_clear(const MobNav *nav, float x0, float z0, float x1, float z1, float radius) {
    if (nav == NULL || !nav->baked) return 0;
    float dx = x1 - x0, dz = z1 - z0;
    for (int r = 0; r < nav->rect_count; r++) {
        if (segment_hits_rect(x0, z0, dx, dz, nav->rects + r * 4, radius)) return 0;
    }
    float length = sqrtf(dx * dx + dz * dz);
    if (length < 1e-5f) return clear_at(nav, x0, z0) >= radius;
    float ux = dx / length, uz = dz / length, t = 0.0f;
    for (;;) {
        float margin = clear_at(nav, x0 + ux * t, z0 + uz * t) - radius;
        if (margin < 0.0f) return 0;
        if (t >= length) return 1;
        t = min_float(t + max_float(margin, 0.06f), length);
    }
}

static inline int flow_index(const MobNav *nav, float x, float z) {
    int ix = floor_int((x - nav->origin_x) / FLOW_CELL);
    int iz = floor_int((z - nav->origin_z) / FLOW_CELL);
    if (ix < 0 || iz < 0 || ix >= nav->flow_w || iz >= nav->flow_h) return -1;
    return ix + iz * nav->flow_w;
}

static int nearest_passable(const MobNav *nav, float x, float z) {
    int ix = clamp_int(floor_int((x - nav->origin_x) / FLOW_CELL), 0, nav->flow_w - 1);
    int iz = clamp_int(floor_int((z - nav->origin_z) / FLOW_CELL), 0, nav->flow_h - 1);
    if (nav->flow_cost[ix + iz * nav->flow_w] > 0.0f) return ix + iz * nav->flow_w;
    for (int r = 1; r <= GOAL_SEARCH; r++) {
        int best = -1;
        float best_distance = UNREACHED;
        for (int cz = iz - r; cz <= iz + r; cz++) {
            for (int cx = ix - r; cx <= ix + r; cx++) {
                if (abs(cx - ix) != r && abs(cz - iz) != r) continue;
                if (cx < 0 || cz < 0 || cx >= nav->flow_w || cz >= nav->flow_h) continue;
                int i = cx + cz * nav->flow_w;
                if (nav->flow_cost[i] <= 0.0f) continue;
                float px = nav->origin_x + ((float)cx + 0.5f) * FLOW_CELL - x;
                float pz = nav->origin_z + ((float)cz + 0.5f) * FLOW_CELL - z;
                float distance = px * px + pz * pz;
                if (distance < best_distance) {
                    best_distance = distance;
                    best = i;
                }
            }
        }
        if (best >= 0) return best;
    }
    return -1;
}

static inline void queue_push(MobNav *nav, int bucket, int cell, float t) {
    int entry = nav->free_entry;
    if (entry < 0) return;
    nav->free_entry = nav->pool[entry].next;
    nav->pool[entry].t = t;
    nav->pool[entry].cell = cell;
    nav->pool[entry].next = nav->head[bucket % BUCKETS];
    nav->head[bucket % BUCKETS] = entry;
}

static inline float eikonal(const float *t, int i, int x, int z, int w, int h, float step) {
    float a = UNREACHED, b = UNREACHED;
    if (x > 0) a = t[i - 1];
    if (x < w - 1 && t[i + 1] < a) a = t[i + 1];
    if (z > 0) b = t[i - w];
    if (z < h - 1 && t[i + w] < b) b = t[i + w];
    if (a > b) {
        float swap = a;
        a = b;
        b = swap;
    }
    if (b >= UNREACHED || b - a >= step) return a + step;
    float gap = b - a;
    return 0.5f * (a + b + sqrtf(2.0f * step * step - gap * gap));
}

/* Fast marching over a bucket queue. Entries may be revisited when a value improves. */
static void field_solve(MobNav *nav, Field *field) {
    int w = nav->flow_w, h = nav->flow_h, total = w * h;
    for (int i = 0; i < total; i++) field->t[i] = UNREACHED;
    memset(field->dx, 0, (size_t)total * sizeof(float));
    memset(field->dz, 0, (size_t)total * sizeof(float));
    field->solved = 1;
    field->dirty = 0;
    field->solved_at = nav->tick;
    nav->solves++;
    if (field->goal < 0) return;

    /* The queue drains completely, so every entry is back on the free list here. */
    int cursor = 0, pending = 1;
    field->t[field->goal] = 0.0f;
    queue_push(nav, 0, field->goal, 0.0f);
    while (pending > 0) {
        while (nav->head[cursor % BUCKETS] < 0) cursor++;
        int entry = nav->head[cursor % BUCKETS];
        nav->head[cursor % BUCKETS] = nav->pool[entry].next;
        int cell = nav->pool[entry].cell;
        float value = nav->pool[entry].t;
        nav->pool[entry].next = nav->free_entry;
        nav->free_entry = entry;
        pending--;
        if (value > field->t[cell]) continue;
        int x = cell % w, z = cell / w;
        static const int dx[4] = {1, -1, 0, 0};
        static const int dz[4] = {0, 0, 1, -1};
        for (int k = 0; k < 4; k++) {
            int nx = x + dx[k], nz = z + dz[k];
            if (nx < 0 || nz < 0 || nx >= w || nz >= h) continue;
            int next = nx + nz * w;
            float cost = nav->flow_cost[next];
            if (cost <= 0.0f) continue;
            float candidate = eikonal(field->t, next, nx, nz, w, h, FLOW_CELL * cost);
            if (candidate + 1e-4f >= field->t[next]) continue;
            field->t[next] = candidate;
            int bucket = (int)(candidate / BUCKET_WIDTH);
            if (bucket < cursor) bucket = cursor;
            if (nav->free_entry >= 0) {
                queue_push(nav, bucket, next, candidate);
                pending++;
            }
        }
    }

    for (int z = 0; z < h; z++) {
        for (int x = 0; x < w; x++) {
            int i = x + z * w;
            float value = field->t[i];
            if (value >= UNREACHED || i == field->goal) continue;
            float left = x > 0 ? field->t[i - 1] : UNREACHED;
            float right = x < w - 1 ? field->t[i + 1] : UNREACHED;
            float up = z > 0 ? field->t[i - w] : UNREACHED;
            float down = z < h - 1 ? field->t[i + w] : UNREACHED;
            float gx = 0.0f, gz = 0.0f;
            if (min_float(left, right) < value) gx = right < left ? value - right : left - value;
            if (min_float(up, down) < value) gz = down < up ? value - down : up - value;
            float length = sqrtf(gx * gx + gz * gz);
            if (length > 1e-6f) {
                field->dx[i] = gx / length;
                field->dz[i] = gz / length;
            }
        }
    }
}

MnResult mn_bake(MobNav *nav, int floor_w, int floor_h, float origin_x, float origin_z,
                 const uint8_t *floor_mask, const float *rects, int rect_count) {
    if (nav == NULL || floor_mask == NULL || floor_w < 4 || floor_h < 4 || floor_w > 4096 || floor_h > 4096 ||
        rect_count < 0 || (rect_count > 0 && rects == NULL) || !isfinite(origin_x) || !isfinite(origin_z)) {
        return MN_ERR_ARGUMENT;
    }
    release_grids(nav);
    mn_destroy(nav->air);
    nav->air = NULL;
    nav->floor_w = floor_w;
    nav->floor_h = floor_h;
    nav->fine_w = floor_w * 2;
    nav->fine_h = floor_h * 2;
    nav->flow_w = floor_w;
    nav->flow_h = floor_h;
    nav->origin_x = origin_x;
    nav->origin_z = origin_z;
    nav->hash_w = (int)((float)floor_w * MN_FLOOR_CELL / HASH_CELL) + 2;
    nav->hash_h = (int)((float)floor_h * MN_FLOOR_CELL / HASH_CELL) + 2;
    size_t flow = (size_t)floor_w * (size_t)floor_h;
    nav->pool_size = (int)flow * 8;
    nav->clear = malloc((size_t)nav->fine_w * (size_t)nav->fine_h * sizeof(float));
    nav->flow_cost = malloc(flow * sizeof(float));
    nav->pool = malloc((size_t)nav->pool_size * sizeof(Entry));
    nav->hash_start = malloc(((size_t)nav->hash_w * (size_t)nav->hash_h + 1) * sizeof(int));
    nav->rects = malloc(((size_t)rect_count + 1) * 4 * sizeof(float));
    if (!nav->clear || !nav->flow_cost || !nav->pool || !nav->hash_start || !nav->rects) {
        release_grids(nav);
        return MN_ERR_MEMORY;
    }
    if (rect_count > 0) memcpy(nav->rects, rects, (size_t)rect_count * 4 * sizeof(float));
    nav->rect_count = rect_count;
    for (int i = 0; i < nav->max_targets; i++) {
        Field *field = &nav->fields[i];
        field->t = malloc(flow * sizeof(float));
        field->dx = malloc(flow * sizeof(float));
        field->dz = malloc(flow * sizeof(float));
        if (!field->t || !field->dx || !field->dz) {
            release_grids(nav);
            return MN_ERR_MEMORY;
        }
        field->solved = 0;
        field->dirty = 0;
        field->goal = -1;
    }
    for (int i = 0; i < BUCKETS; i++) nav->head[i] = -1;
    for (int i = 0; i < nav->pool_size; i++) nav->pool[i].next = i + 1 < nav->pool_size ? i + 1 : -1;
    nav->free_entry = 0;
    MnResult result = bake_clearance(nav, floor_mask, rects, rect_count);
    if (result != MN_OK) {
        release_grids(nav);
        return result;
    }
    nav->baked = 1;
    for (int z = 0; z < nav->flow_h; z++) {
        for (int x = 0; x < nav->flow_w; x++) {
            float c = clear_at(nav, origin_x + ((float)x + 0.5f) * FLOW_CELL, origin_z + ((float)z + 0.5f) * FLOW_CELL);
            float cost = 0.0f;
            if (c >= PASS_CLEARANCE) {
                float near_wall = max_float(0.0f, (WALL_BAND - c) / (WALL_BAND - PASS_CLEARANCE));
                cost = 1.0f + WALL_COST * min_float(near_wall, 1.0f);
            }
            nav->flow_cost[x + z * nav->flow_w] = cost;
        }
    }
    nav->target_count = 0;
    nav->hash_stale = 1;
    return MN_OK;
}

MnResult mn_set_targets(MobNav *nav, const float *xz, int count) {
    if (nav == NULL || !nav->baked) return MN_ERR_STATE;
    if (count < 0 || count > nav->max_targets || (count > 0 && xz == NULL)) return MN_ERR_ARGUMENT;
    for (int i = 0; i < count; i++) {
        float x = xz[i * 2], z = xz[i * 2 + 1];
        if (!isfinite(x) || !isfinite(z)) return MN_ERR_ARGUMENT;
    }
    for (int i = 0; i < count; i++) {
        Field *field = &nav->fields[i];
        field->x = xz[i * 2];
        field->z = xz[i * 2 + 1];
        int goal = nearest_passable(nav, field->x, field->z);
        if (goal != field->goal || i >= nav->target_count) {
            field->goal = goal;
            field->dirty = 1;
        }
    }
    nav->target_count = count;
    if (nav->air != NULL) mn_set_targets(nav->air, xz, count);
    return MN_OK;
}

MnResult mn_bake_air(MobNav *nav, const uint8_t *air_mask, int64_t length) {
    if (nav == NULL || !nav->baked) return MN_ERR_STATE;
    if (air_mask != NULL && length != (int64_t)nav->floor_w * nav->floor_h) return MN_ERR_ARGUMENT;
    mn_destroy(nav->air);
    nav->air = NULL;
    if (air_mask == NULL) return MN_OK;
    MobNav *air = mn_create(1, nav->max_targets);
    if (air == NULL) return MN_ERR_MEMORY;
    MnResult status = mn_bake(air, nav->floor_w, nav->floor_h, nav->origin_x, nav->origin_z, air_mask, nav->rects, nav->rect_count);
    if (status == MN_OK && nav->target_count > 0) {
        float *xz = malloc((size_t)nav->target_count * 2 * sizeof(float));
        if (xz == NULL) {
            status = MN_ERR_MEMORY;
        } else {
            for (int i = 0; i < nav->target_count; i++) {
                xz[i * 2] = nav->fields[i].x;
                xz[i * 2 + 1] = nav->fields[i].z;
            }
            status = mn_set_targets(air, xz, nav->target_count);
            free(xz);
        }
    }
    if (status != MN_OK) {
        mn_destroy(air);
        return status;
    }
    nav->air = air;
    return MN_OK;
}

MnResult mn_set_layers(MobNav *nav, const uint8_t *layers, int count) {
    if (nav == NULL) return MN_ERR_STATE;
    if (count < 0 || count > nav->max_agents || (count > 0 && layers == NULL)) return MN_ERR_ARGUMENT;
    for (int i = 0; i < count; i++) nav->layer[i] = layers[i] != 0;
    nav->hash_stale = 1;
    return MN_OK;
}

/* The grids an agent moves on: the air layer for a flyer when one is baked, otherwise the ground. */
static inline const MobNav *grid_for(const MobNav *nav, int slot) {
    return nav->layer[slot] != 0 && nav->air != NULL ? nav->air : nav;
}

static int valid_mode(float value) {
    return value == (float)MN_MODE_HOLD || value == (float)MN_MODE_SEEK || value == (float)MN_MODE_FLEE ||
           value == (float)MN_MODE_DIRECT;
}

static int valid_target(float value) {
    return value >= (float)MN_TARGET_NEAREST && value <= 65535.0f;
}

MnResult mn_agents_load(MobNav *nav, const float *data, int count) {
    if (nav == NULL) return MN_ERR_STATE;
    if (count < 0 || count > nav->max_agents || (count > 0 && data == NULL)) return MN_ERR_ARGUMENT;
    for (int i = 0; i < count * MN_AGENT_STRIDE; i++) {
        if (!isfinite(data[i])) return MN_ERR_ARGUMENT;
    }
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_AGENT_STRIDE;
        if (!valid_mode(row[7]) || !valid_target(row[6]) || row[3] < 0.0f || row[4] < 0.0f || row[5] < 0.0f) {
            return MN_ERR_ARGUMENT;
        }
    }
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_AGENT_STRIDE;
        nav->active[i] = row[0] != 0.0f;
        nav->x[i] = row[1];
        nav->z[i] = row[2];
        nav->speed[i] = row[3];
        nav->radius[i] = row[4];
        nav->stop[i] = row[5];
        nav->target[i] = (int)row[6];
        nav->mode[i] = (uint8_t)row[7];
        nav->offset_x[i] = row[8];
        nav->offset_z[i] = row[9];
        nav->sight[i] = 0;
    }
    nav->agent_count = count;
    nav->hash_stale = 1;
    return MN_OK;
}

MnResult mn_agents_place(MobNav *nav, const float *data, int count) {
    if (nav == NULL) return MN_ERR_STATE;
    if (count < 0 || (count > 0 && data == NULL)) return MN_ERR_ARGUMENT;
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_PLACE_STRIDE;
        for (int k = 0; k < MN_PLACE_STRIDE; k++) {
            if (!isfinite(row[k])) return MN_ERR_ARGUMENT;
        }
        if (row[0] < 0.0f || row[0] >= (float)nav->agent_count || row[3] < 0.0f) return MN_ERR_ARGUMENT;
    }
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_PLACE_STRIDE;
        int slot = (int)row[0];
        nav->x[slot] = row[1];
        nav->z[slot] = row[2];
        nav->radius[slot] = row[3];
        nav->active[slot] = row[4] != 0.0f;
        nav->sight[slot] = 0;
    }
    nav->hash_stale = 1;
    return MN_OK;
}

MnResult mn_agents_displace(MobNav *nav, const float *data, int count) {
    if (nav == NULL || !nav->baked) return MN_ERR_STATE;
    if (count < 0 || (count > 0 && data == NULL)) return MN_ERR_ARGUMENT;
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_DISPLACE_STRIDE;
        if (!isfinite(row[0]) || !isfinite(row[1]) || !isfinite(row[2])) return MN_ERR_ARGUMENT;
        if (row[0] < 0.0f || row[0] >= (float)nav->agent_count) return MN_ERR_ARGUMENT;
    }
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_DISPLACE_STRIDE;
        int slot = (int)row[0];
        if (!nav->active[slot]) continue;
        const MobNav *grid = grid_for(nav, slot);
        float x = nav->x[slot], z = nav->z[slot], dx = row[1] - x, dz = row[2] - z;
        float body = nav->radius[slot] + SKIN;
        int steps = 1 + (int)(sqrtf(dx * dx + dz * dz) / 0.1f);
        for (int s = 1; s <= steps; s++) {
            float t = (float)s / (float)steps;
            float nx = nav->x[slot] + dx * t, nz = nav->z[slot] + dz * t;
            if (clear_at(grid, nx, nz) < body) break;
            x = nx;
            z = nz;
        }
        nav->x[slot] = x;
        nav->z[slot] = z;
        nav->sight[slot] = 0;
    }
    nav->hash_stale = 1;
    return MN_OK;
}

MnResult mn_agents_command(MobNav *nav, const float *data, int count) {
    if (nav == NULL) return MN_ERR_STATE;
    if (count < 0 || count > nav->agent_count || (count > 0 && data == NULL)) return MN_ERR_ARGUMENT;
    for (int i = 0; i < count * MN_COMMAND_STRIDE; i++) {
        if (!isfinite(data[i])) return MN_ERR_ARGUMENT;
    }
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_COMMAND_STRIDE;
        if (!valid_mode(row[4]) || !valid_target(row[3]) || row[1] < 0.0f || row[2] < 0.0f) return MN_ERR_ARGUMENT;
    }
    for (int i = 0; i < count; i++) {
        const float *row = data + i * MN_COMMAND_STRIDE;
        nav->active[i] = row[0] != 0.0f;
        nav->speed[i] = row[1];
        nav->stop[i] = row[2];
        nav->target[i] = (int)row[3];
        nav->mode[i] = (uint8_t)row[4];
        nav->offset_x[i] = row[5];
        nav->offset_z[i] = row[6];
    }
    return MN_OK;
}

static void update_fields(MobNav *nav) {
    for (int i = 0; i < nav->target_count; i++) {
        if (!nav->fields[i].solved) field_solve(nav, &nav->fields[i]);
    }
    for (int budget = 0; budget < FIELD_BUDGET; budget++) {
        Field *oldest = NULL;
        for (int i = 0; i < nav->target_count; i++) {
            Field *field = &nav->fields[i];
            if (field->dirty && (oldest == NULL || field->solved_at < oldest->solved_at)) oldest = field;
        }
        if (oldest == NULL) return;
        field_solve(nav, oldest);
    }
}

static inline int hash_cell(const MobNav *nav, float x, float z) {
    int ix = clamp_int(floor_int((x - nav->origin_x) / HASH_CELL), 0, nav->hash_w - 1);
    int iz = clamp_int(floor_int((z - nav->origin_z) / HASH_CELL), 0, nav->hash_h - 1);
    return ix + iz * nav->hash_w;
}

static void rebuild_hash(MobNav *nav) {
    int cells = nav->hash_w * nav->hash_h;
    memset(nav->hash_start, 0, ((size_t)cells + 1) * sizeof(int));
    for (int i = 0; i < nav->agent_count; i++) {
        if (nav->active[i]) nav->hash_start[hash_cell(nav, nav->x[i], nav->z[i]) + 1]++;
    }
    for (int c = 0; c < cells; c++) nav->hash_start[c + 1] += nav->hash_start[c];
    /* Fill from the highest slot down so each cell lists slots in ascending order. */
    for (int i = nav->agent_count - 1; i >= 0; i--) {
        if (!nav->active[i]) continue;
        int c = hash_cell(nav, nav->x[i], nav->z[i]);
        nav->hash_items[nav->hash_start[c + 1] - 1] = i;
        nav->hash_start[c + 1]--;
    }
    /* The fill above shifted each start back into place at index c + 1. */
    memmove(nav->hash_start, nav->hash_start + 1, (size_t)cells * sizeof(int));
    nav->hash_start[cells] = 0;
    for (int i = 0; i < nav->agent_count; i++) nav->hash_start[cells] += nav->active[i];
    nav->hash_stale = 0;
}

MnResult mn_nearest_batch(MobNav *nav, const float *slots, int count, float radius, int k, float *out) {
    if (nav == NULL || !nav->baked) return MN_ERR_STATE;
    if (count < 0 || k < 1 || k > MN_NEAREST_MAX || !isfinite(radius) || radius < 0.0f ||
        (count > 0 && (slots == NULL || out == NULL))) {
        return MN_ERR_ARGUMENT;
    }
    if (nav->hash_stale) rebuild_hash(nav);
    float limit = radius * radius;
    for (int q = 0; q < count; q++) {
        float *row = out + q * k;
        for (int i = 0; i < k; i++) row[i] = -1.0f;
        int slot = isfinite(slots[q]) ? (int)slots[q] : -1;
        if (slot < 0 || slot >= nav->agent_count || !nav->active[slot]) continue;
        float x = nav->x[slot], z = nav->z[slot], found[MN_NEAREST_MAX];
        int ids[MN_NEAREST_MAX], used = 0;
        int ax = clamp_int(floor_int((x - radius - nav->origin_x) / HASH_CELL), 0, nav->hash_w - 1);
        int bx = clamp_int(floor_int((x + radius - nav->origin_x) / HASH_CELL), 0, nav->hash_w - 1);
        int az = clamp_int(floor_int((z - radius - nav->origin_z) / HASH_CELL), 0, nav->hash_h - 1);
        int bz = clamp_int(floor_int((z + radius - nav->origin_z) / HASH_CELL), 0, nav->hash_h - 1);
        for (int cz = az; cz <= bz; cz++) {
            for (int cx = ax; cx <= bx; cx++) {
                int c = cx + cz * nav->hash_w;
                for (int n = nav->hash_start[c]; n < nav->hash_start[c + 1]; n++) {
                    int other = nav->hash_items[n];
                    if (other == slot) continue;
                    float dx = nav->x[other] - x, dz = nav->z[other] - z, d2 = dx * dx + dz * dz;
                    if (d2 > limit) continue;
                    int at = used;
                    while (at > 0 && (d2 < found[at - 1] || (d2 == found[at - 1] && other < ids[at - 1]))) at--;
                    if (at >= k) continue;
                    int last = used < k ? used : k - 1;
                    for (int m = last; m > at; m--) {
                        found[m] = found[m - 1];
                        ids[m] = ids[m - 1];
                    }
                    found[at] = d2;
                    ids[at] = other;
                    if (used < k) used++;
                }
            }
        }
        for (int i = 0; i < used; i++) row[i] = (float)ids[i];
    }
    return MN_OK;
}

static void separation(const MobNav *nav, int slot, float *out_x, float *out_z) {
    float x = nav->x[slot], z = nav->z[slot], sum_x = 0.0f, sum_z = 0.0f;
    int cx = clamp_int(floor_int((x - nav->origin_x) / HASH_CELL), 0, nav->hash_w - 1);
    int cz = clamp_int(floor_int((z - nav->origin_z) / HASH_CELL), 0, nav->hash_h - 1);
    for (int iz = cz > 0 ? cz - 1 : 0; iz <= cz + 1 && iz < nav->hash_h; iz++) {
        for (int ix = cx > 0 ? cx - 1 : 0; ix <= cx + 1 && ix < nav->hash_w; ix++) {
            int c = ix + iz * nav->hash_w;
            for (int k = nav->hash_start[c]; k < nav->hash_start[c + 1]; k++) {
                int other = nav->hash_items[k];
                /* Flyers and walkers pass over each other. */
                if (other == slot || nav->layer[other] != nav->layer[slot]) continue;
                float dx = x - nav->x[other], dz = z - nav->z[other];
                float d2 = dx * dx + dz * dz;
                if (d2 >= SEPARATION * SEPARATION) continue;
                if (d2 < 1e-6f) {
                    float angle = (float)slot * 2.39996f;
                    sum_x += cosf(angle);
                    sum_z += sinf(angle);
                    continue;
                }
                float d = sqrtf(d2), push = (SEPARATION - d) / SEPARATION / d;
                sum_x += dx * push;
                sum_z += dz * push;
            }
        }
    }
    float length = sqrtf(sum_x * sum_x + sum_z * sum_z);
    if (length > 1.0f) {
        sum_x /= length;
        sum_z /= length;
    }
    *out_x = sum_x;
    *out_z = sum_z;
}

static int flow_sample(const MobNav *nav, const Field *field, float x, float z, float *out_x, float *out_z) {
    float fx = (x - nav->origin_x) / FLOW_CELL - 0.5f, fz = (z - nav->origin_z) / FLOW_CELL - 0.5f;
    int ix = floor_int(fx), iz = floor_int(fz);
    float u = fx - (float)ix, v = fz - (float)iz, sum_x = 0.0f, sum_z = 0.0f;
    for (int b = 0; b < 2; b++) {
        for (int a = 0; a < 2; a++) {
            int cx = ix + a, cz = iz + b;
            if (cx < 0 || cz < 0 || cx >= nav->flow_w || cz >= nav->flow_h) continue;
            int i = cx + cz * nav->flow_w;
            if (field->t[i] >= UNREACHED) continue;
            float weight = (a ? u : 1.0f - u) * (b ? v : 1.0f - v);
            sum_x += field->dx[i] * weight;
            sum_z += field->dz[i] * weight;
        }
    }
    float length = sqrtf(sum_x * sum_x + sum_z * sum_z);
    if (length > 1e-3f) {
        *out_x = sum_x / length;
        *out_z = sum_z / length;
        return 1;
    }
    int home = flow_index(nav, x, z);
    if (home >= 0 && field->t[home] < UNREACHED) return 0;
    /* Pushed off the field: head for the closest reached cell. */
    int hx = clamp_int(floor_int((x - nav->origin_x) / FLOW_CELL), 0, nav->flow_w - 1);
    int hz = clamp_int(floor_int((z - nav->origin_z) / FLOW_CELL), 0, nav->flow_h - 1);
    for (int r = 1; r <= FLOW_SEARCH; r++) {
        float best = UNREACHED, best_x = 0.0f, best_z = 0.0f;
        for (int cz = hz - r; cz <= hz + r; cz++) {
            for (int cx = hx - r; cx <= hx + r; cx++) {
                if (abs(cx - hx) != r && abs(cz - hz) != r) continue;
                if (cx < 0 || cz < 0 || cx >= nav->flow_w || cz >= nav->flow_h) continue;
                if (field->t[cx + cz * nav->flow_w] >= UNREACHED) continue;
                float px = nav->origin_x + ((float)cx + 0.5f) * FLOW_CELL - x;
                float pz = nav->origin_z + ((float)cz + 0.5f) * FLOW_CELL - z;
                float distance = px * px + pz * pz;
                if (distance < best) {
                    best = distance;
                    best_x = px;
                    best_z = pz;
                }
            }
        }
        if (best < UNREACHED) {
            float d = sqrtf(best);
            *out_x = d > 1e-5f ? best_x / d : 0.0f;
            *out_z = d > 1e-5f ? best_z / d : 0.0f;
            return 1;
        }
    }
    return 0;
}

static void resolve_move(const MobNav *nav, float radius, float *x, float *z, float vx, float vz) {
    float body = radius + SKIN;
    float start = clear_at(nav, *x, *z);
    float nx = *x + vx, nz = *z + vz;
    float c = clear_at(nav, nx, nz);
    if (c < body) {
        float gx, gz;
        clear_gradient(nav, nx, nz, &gx, &gz);
        float into = vx * gx + vz * gz;
        if (into < 0.0f) {
            nx = *x + vx - into * gx;
            nz = *z + vz - into * gz;
            c = clear_at(nav, nx, nz);
        }
        if (c < body) {
            clear_gradient(nav, nx, nz, &gx, &gz);
            nx += gx * (body - c);
            nz += gz * (body - c);
            c = clear_at(nav, nx, nz);
        }
    }
    if (c >= body - 1e-3f || c > start) {
        *x = nx;
        *z = nz;
    }
}

static int pick_target(const MobNav *nav, int slot) {
    int wanted = nav->target[slot];
    if (wanted >= 0) return wanted < nav->target_count ? wanted : -1;
    int best = -1;
    float best_distance = UNREACHED;
    for (int i = 0; i < nav->target_count; i++) {
        float dx = nav->fields[i].x - nav->x[slot], dz = nav->fields[i].z - nav->z[slot];
        float distance = dx * dx + dz * dz;
        if (distance < best_distance) {
            best_distance = distance;
            best = i;
        }
    }
    return best;
}

static void step_agent(MobNav *nav, int slot, float dt) {
    float x = nav->x[slot], z = nav->z[slot];
    nav->next_x[slot] = x;
    nav->next_z[slot] = z;
    if (nav->mode[slot] == MN_MODE_HOLD) return;
    const MobNav *grid = grid_for(nav, slot);
    const Field *field = NULL;
    if (nav->mode[slot] != MN_MODE_DIRECT) {
        int picked = pick_target(nav, slot);
        if (picked < 0) return;
        field = &grid->fields[picked];
    }
    float step = nav->speed[slot] * dt, dir_x = 0.0f, dir_z = 0.0f, travel = step;
    if (nav->mode[slot] == MN_MODE_DIRECT) {
        float dx = nav->offset_x[slot] - x, dz = nav->offset_z[slot] - z;
        float distance = sqrtf(dx * dx + dz * dz);
        if (distance <= nav->stop[slot]) return;
        travel = min_float(step, distance - nav->stop[slot]);
        dir_x = dx / distance;
        dir_z = dz / distance;
    } else if (nav->mode[slot] == MN_MODE_SEEK) {
        float goal_x = field->x + nav->offset_x[slot], goal_z = field->z + nav->offset_z[slot];
        float dx = goal_x - x, dz = goal_z - z;
        float distance = sqrtf(dx * dx + dz * dz);
        if (distance <= nav->stop[slot]) return;
        travel = min_float(step, distance - nav->stop[slot]);
        if ((nav->tick + (uint64_t)slot) % LOS_REFRESH == 0) {
            nav->sight[slot] = (uint8_t)mn_line_clear(grid, x, z, goal_x, goal_z, nav->radius[slot] + LOS_MARGIN);
        }
        if (nav->sight[slot] || !flow_sample(grid, field, x, z, &dir_x, &dir_z)) {
            dir_x = distance > 1e-5f ? dx / distance : 0.0f;
            dir_z = distance > 1e-5f ? dz / distance : 0.0f;
        }
    } else {
        if (flow_sample(grid, field, x, z, &dir_x, &dir_z)) {
            dir_x = -dir_x;
            dir_z = -dir_z;
        } else {
            float dx = x - field->x, dz = z - field->z;
            float distance = sqrtf(dx * dx + dz * dz);
            dir_x = distance > 1e-5f ? dx / distance : 0.0f;
            dir_z = distance > 1e-5f ? dz / distance : 0.0f;
        }
    }
    float push_x, push_z;
    separation(nav, slot, &push_x, &push_z);
    float vx = dir_x * travel + push_x * step * SEPARATION_GAIN;
    float vz = dir_z * travel + push_z * step * SEPARATION_GAIN;
    float length = sqrtf(vx * vx + vz * vz);
    int moves = 1 + (int)(length / FINE_CELL);
    for (int i = 0; i < moves; i++) {
        resolve_move(grid, nav->radius[slot], &x, &z, vx / (float)moves, vz / (float)moves);
    }
    nav->next_x[slot] = x;
    nav->next_z[slot] = z;
}

MnResult mn_tick(MobNav *nav, float dt) {
    if (nav == NULL || !nav->baked) return MN_ERR_STATE;
    if (!isfinite(dt) || dt < 0.0f || dt > 1.0f) return MN_ERR_ARGUMENT;
    update_fields(nav);
    if (nav->air != NULL) {
        /* The air layer's fields are kept current only while something flies. */
        for (int i = 0; i < nav->agent_count; i++) {
            if (nav->active[i] && nav->layer[i]) {
                update_fields(nav->air);
                break;
            }
        }
    }
    rebuild_hash(nav);
    for (int i = 0; i < nav->agent_count; i++) {
        if (nav->active[i]) step_agent(nav, i, dt);
    }
    for (int i = 0; i < nav->agent_count; i++) {
        if (!nav->active[i]) continue;
        nav->x[i] = nav->next_x[i];
        nav->z[i] = nav->next_z[i];
    }
    nav->tick++;
    nav->hash_stale = 1;
    return MN_OK;
}

MnResult mn_wall_rays(const MobNav *nav, const float *slots, int count, float max_distance, float *out) {
    static const float ray_x[MN_WALL_RAYS] = {1.0f, 0.70710678f, 0.0f, -0.70710678f, -1.0f, -0.70710678f, 0.0f, 0.70710678f};
    static const float ray_z[MN_WALL_RAYS] = {0.0f, 0.70710678f, 1.0f, 0.70710678f, 0.0f, -0.70710678f, -1.0f, -0.70710678f};
    if (nav == NULL || !nav->baked) return MN_ERR_STATE;
    if (count < 0 || !isfinite(max_distance) || max_distance <= 0.0f || (count > 0 && (slots == NULL || out == NULL))) {
        return MN_ERR_ARGUMENT;
    }
    for (int q = 0; q < count; q++) {
        int slot = isfinite(slots[q]) ? (int)slots[q] : -1;
        for (int ray = 0; ray < MN_WALL_RAYS; ray++) {
            float reached = max_distance;
            if (slot >= 0 && slot < nav->agent_count) {
                const MobNav *grid = grid_for(nav, slot);
                float t = 0.0f;
                while (t < max_distance) {
                    float c = clear_at(grid, nav->x[slot] + ray_x[ray] * t, nav->z[slot] + ray_z[ray] * t);
                    if (c <= 0.0f) {
                        reached = t;
                        break;
                    }
                    t += max_float(c, 0.05f);
                }
            }
            out[q * MN_WALL_RAYS + ray] = reached;
        }
    }
    return MN_OK;
}

void mn_line_clear_batch(const MobNav *nav, const float *queries, int count, uint8_t *out) {
    for (int i = 0; i < count; i++) {
        const float *q = queries + i * MN_SIGHT_STRIDE;
        out[i] = (uint8_t)mn_line_clear(nav, q[0], q[1], q[2], q[3], q[4]);
    }
}

float mn_air_clearance(const MobNav *nav, float x, float z) {
    return mn_clearance(nav != NULL && nav->air != NULL ? nav->air : nav, x, z);
}

int mn_sight_clear(const MobNav *nav, float x0, float z0, float x1, float z1, float radius) {
    return mn_line_clear(nav != NULL && nav->air != NULL ? nav->air : nav, x0, z0, x1, z1, radius);
}

void mn_sight_clear_batch(const MobNav *nav, const float *queries, int count, uint8_t *out) {
    mn_line_clear_batch(nav != NULL && nav->air != NULL ? nav->air : nav, queries, count, out);
}

int mn_agent_count(const MobNav *nav) { return nav != NULL ? nav->agent_count : 0; }

void mn_positions(const MobNav *nav, float *out_xz) {
    for (int i = 0; i < nav->agent_count; i++) {
        out_xz[i * 2] = nav->x[i];
        out_xz[i * 2 + 1] = nav->z[i];
    }
}

float mn_path_cost(const MobNav *nav, int target, float x, float z) {
    if (nav == NULL || !nav->baked || target < 0 || target >= nav->target_count) return -1.0f;
    const Field *field = &nav->fields[target];
    if (!field->solved) return -1.0f;
    int cell = nearest_passable(nav, x, z);
    if (cell < 0 || field->t[cell] >= UNREACHED) return -1.0f;
    return field->t[cell];
}

uint64_t mn_state_hash(const MobNav *nav) {
    uint64_t hash = 14695981039346656037ULL;
    if (nav == NULL) return hash;
    for (int i = 0; i < nav->agent_count; i++) {
        uint32_t words[3];
        memcpy(&words[0], &nav->x[i], sizeof(uint32_t));
        memcpy(&words[1], &nav->z[i], sizeof(uint32_t));
        words[2] = nav->active[i];
        const uint8_t *bytes = (const uint8_t *)words;
        for (size_t k = 0; k < sizeof(words); k++) {
            hash ^= bytes[k];
            hash *= 1099511628211ULL;
        }
    }
    return hash;
}

uint64_t mn_field_solves(const MobNav *nav) { return nav != NULL ? nav->solves : 0; }
