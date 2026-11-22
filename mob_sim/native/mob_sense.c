#include "mob_sense.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define SIGHT_STRIDE 5
#define MAX_NEIGHBOURS 32
/* A cell counts as lit at a quarter light or more. */
#define LIT_THRESHOLD 0.25f
/* Darkness distance for cells with no lit cell anywhere. */
#define NO_LIGHT 1.0e9f
#define SQRT2_F 1.41421356f

static const MsKind config_kinds[SC_COUNT] = {
    [SC_DIMS] = SK_INTS, [SC_REALS] = SK_FLOATS, [SC_VISION] = SK_FLOATS, [SC_DARKVISION] = SK_FLOATS,
    [SC_HEARING] = SK_FLOATS, [SC_SMELL] = SK_FLOATS,
};

static const MsKind input_kinds[SI_COUNT] = {
    [SI_TICK] = SK_INTS, [SI_SLOTS] = SK_INTS, [SI_ACTIVE] = SK_INTS, [SI_ALIVE] = SK_BYTES, [SI_GENERATION] = SK_INTS,
    [SI_SPECIES] = SK_INTS, [SI_LEADER] = SK_INTS, [SI_LEADER_GENERATION] = SK_INTS, [SI_XZ] = SK_FLOATS,
    [SI_ENGAGED] = SK_BYTES, [SI_LAST_SENSED] = SK_INTS, [SI_VISIBLE] = SK_BYTES, [SI_SEEN_X] = SK_FLOATS,
    [SI_SEEN_Z] = SK_FLOATS, [SI_SEEN_TICK] = SK_INTS, [SI_ALLIES] = SK_INTS, [SI_ALLY_GENERATION] = SK_INTS,
    [SI_ALLY_AWAY_SINCE] = SK_INTS, [SI_PARTY_PRESENT] = SK_BYTES, [SI_PARTY_ALIVE] = SK_BYTES,
    [SI_PARTY_X] = SK_FLOATS, [SI_PARTY_Z] = SK_FLOATS, [SI_NOISES] = SK_FLOATS, [SI_LIGHTS] = SK_FLOATS,
    [SI_AMBIENT] = SK_FLOATS,
};

MsKind ms_config_kind(int index) { return config_kinds[index]; }
MsKind ms_input_kind(int index) { return input_kinds[index]; }

struct MobSense {
    int dim[SD_COUNT];
    float real[SR_COUNT];
    float *vision, *darkvision, *hearing, *smell;
    /* Scratch for one update, sized for the worst case. */
    float *queries, *nearest, *slot_floats;
    int *owners, *pairs, *newly;
    uint8_t *clear;
    /* Senses state. */
    float *light, *scent, *light_key;
    /* Distance in world units from each cell to the nearest lit cell. Zero inside light. */
    float *darkness;
    int64_t light_key_length;
    float light_key_ambient;
    int light_ready;
    int last_decay_tick;
};

typedef struct {
    MobSense *s;
    MobNav *nav;
    int tick, capacity, players, allies;
    const int *active, *generation, *species, *leader, *leader_generation, *slots;
    const uint8_t *alive, *party_present, *party_alive;
    const float *xz, *party_x, *party_z, *noises, *lights;
    int64_t active_count, slot_count, noise_count, light_count;
    float ambient;
    /* Outputs, starting as copies of the inputs. */
    uint8_t *visible, *engaged;
    float *seen_x, *seen_z;
    int *seen_tick, *last_sensed, *ally, *ally_generation, *ally_away_since;
} Pass;

static void *copy_table(const void *source, int64_t length, size_t size) {
    void *table = malloc((size_t)(length > 0 ? length : 1) * size);
    if (table != NULL && length > 0) memcpy(table, source, (size_t)length * size);
    return table;
}

void ms_destroy(MobSense *s) {
    if (s == NULL) return;
    free(s->vision); free(s->darkvision); free(s->hearing); free(s->smell);
    free(s->queries); free(s->nearest); free(s->slot_floats); free(s->owners); free(s->pairs); free(s->newly); free(s->clear);
    free(s->light); free(s->scent); free(s->light_key); free(s->darkness);
    free(s);
}

MsResult ms_create(const void *const *items, const int64_t *lengths, MobSense **out) {
    *out = NULL;
    if (lengths[SC_DIMS] != SD_COUNT || lengths[SC_REALS] != SR_COUNT) return SK_ERR_ARGUMENT;
    MobSense *s = calloc(1, sizeof(MobSense));
    if (s == NULL) return SK_ERR_MEMORY;
    memcpy(s->dim, items[SC_DIMS], sizeof(s->dim));
    memcpy(s->real, items[SC_REALS], sizeof(s->real));
    int capacity = s->dim[SD_CAPACITY], players = s->dim[SD_PLAYERS], species = s->dim[SD_SPECIES];
    int alert = s->dim[SD_ALERT_NEIGHBOURS], nearest = s->dim[SD_NEAREST_LIMIT];
    int64_t cells = (int64_t)s->dim[SD_GRID_WIDTH] * s->dim[SD_GRID_HEIGHT];
    if (capacity < 1 || players < 1 || species < 1 || s->dim[SD_REFRESH_TICKS] < 1 || alert < 1 || alert > MAX_NEIGHBOURS
            || nearest < 1 || nearest > MAX_NEIGHBOURS || cells < 1 || s->dim[SD_SCENT_DECAY_TICKS] < 1 || s->real[SR_GRID_CELL] <= 0.0f
            || lengths[SC_VISION] != species || lengths[SC_DARKVISION] != species || lengths[SC_HEARING] != species
            || lengths[SC_SMELL] != species) {
        free(s);
        return SK_ERR_ARGUMENT;
    }
    int neighbours = alert > nearest ? alert : nearest;
    s->vision = copy_table(items[SC_VISION], species, sizeof(float));
    s->darkvision = copy_table(items[SC_DARKVISION], species, sizeof(float));
    s->hearing = copy_table(items[SC_HEARING], species, sizeof(float));
    s->smell = copy_table(items[SC_SMELL], species, sizeof(float));
    s->queries = malloc((size_t)capacity * (players > neighbours ? players : neighbours) * SIGHT_STRIDE * sizeof(float));
    s->nearest = malloc((size_t)capacity * neighbours * sizeof(float));
    s->slot_floats = malloc((size_t)capacity * sizeof(float));
    s->owners = malloc((size_t)capacity * players * sizeof(int));
    s->pairs = malloc((size_t)capacity * neighbours * 2 * sizeof(int));
    s->newly = malloc((size_t)capacity * sizeof(int));
    s->clear = malloc((size_t)capacity * (players > neighbours ? players : neighbours));
    s->light = malloc((size_t)cells * sizeof(float));
    s->darkness = malloc((size_t)cells * sizeof(float));
    s->scent = calloc((size_t)cells * players, sizeof(float));
    if (!s->vision || !s->darkvision || !s->hearing || !s->smell || !s->queries || !s->nearest || !s->slot_floats
            || !s->owners || !s->pairs || !s->newly || !s->clear || !s->light || !s->darkness || !s->scent) {
        ms_destroy(s);
        return SK_ERR_MEMORY;
    }
    s->last_decay_tick = -1;
    *out = s;
    return SK_OK;
}

int64_t ms_update_size(const MobSense *s) {
    int64_t sensed = (int64_t)s->dim[SD_CAPACITY] * s->dim[SD_PLAYERS];
    return sensed + sensed * 4 * 3 + s->dim[SD_CAPACITY] + (int64_t)s->dim[SD_CAPACITY] * 4;
}

int64_t ms_allies_size(const MobSense *s) {
    return (int64_t)s->dim[SD_CAPACITY] * s->dim[SD_ALLIES] * 4 * 3;
}

static int bind(Pass *p, MobSense *s, MobNav *nav, const void *const *items, const int64_t *lengths) {
    int capacity = s->dim[SD_CAPACITY], players = s->dim[SD_PLAYERS], allies = s->dim[SD_ALLIES];
    int64_t sensed = (int64_t)capacity * players, slotted = (int64_t)capacity * allies;
    if (nav == NULL || lengths[SI_TICK] != 1 || lengths[SI_ALIVE] != capacity || lengths[SI_XZ] != (int64_t)capacity * 2
            || lengths[SI_ENGAGED] != capacity || lengths[SI_LAST_SENSED] != capacity || lengths[SI_VISIBLE] != sensed
            || lengths[SI_SEEN_X] != sensed || lengths[SI_SEEN_Z] != sensed || lengths[SI_SEEN_TICK] != sensed
            || lengths[SI_ALLIES] != slotted || lengths[SI_ALLY_GENERATION] != slotted || lengths[SI_ALLY_AWAY_SINCE] != slotted
            || lengths[SI_PARTY_X] != players || lengths[SI_PARTY_Z] != players || lengths[SI_PARTY_PRESENT] != players
            || lengths[SI_PARTY_ALIVE] != players || lengths[SI_NOISES] % MS_NOISE_STRIDE != 0
            || lengths[SI_LIGHTS] % MS_LIGHT_STRIDE != 0 || lengths[SI_AMBIENT] != 1) {
        return 0;
    }
    memset(p, 0, sizeof(*p));
    p->s = s;
    p->nav = nav;
    p->capacity = capacity;
    p->players = players;
    p->allies = allies;
    p->tick = ((const int *)items[SI_TICK])[0];
    p->active = items[SI_ACTIVE];
    p->active_count = lengths[SI_ACTIVE];
    p->slots = items[SI_SLOTS];
    p->slot_count = lengths[SI_SLOTS];
    p->alive = items[SI_ALIVE];
    p->generation = items[SI_GENERATION];
    p->species = items[SI_SPECIES];
    p->leader = items[SI_LEADER];
    p->leader_generation = items[SI_LEADER_GENERATION];
    p->xz = items[SI_XZ];
    p->party_present = items[SI_PARTY_PRESENT];
    p->party_alive = items[SI_PARTY_ALIVE];
    p->party_x = items[SI_PARTY_X];
    p->party_z = items[SI_PARTY_Z];
    p->noises = items[SI_NOISES];
    p->noise_count = lengths[SI_NOISES] / MS_NOISE_STRIDE;
    p->lights = items[SI_LIGHTS];
    p->light_count = lengths[SI_LIGHTS] / MS_LIGHT_STRIDE;
    p->ambient = ((const float *)items[SI_AMBIENT])[0];
    for (int64_t i = 0; i < p->active_count; i++) if (p->active[i] < 0 || p->active[i] >= capacity) return 0;
    for (int64_t i = 0; i < p->slot_count; i++) if (p->slots[i] < 0 || p->slots[i] >= capacity) return 0;
    return 1;
}

static inline int targetable(const Pass *p, int player) { return p->party_present[player] != 0 && p->party_alive[player] != 0; }
static inline double distance_to(const Pass *p, int slot, double x, double z) {
    double dx = (double)p->xz[slot * 2] - x, dz = (double)p->xz[slot * 2 + 1] - z;
    return sqrt(dx * dx + dz * dz);
}
static inline int leader_of(const Pass *p, int slot) {
    int chosen = p->leader[slot];
    return chosen >= 0 && p->alive[chosen] != 0 && p->generation[chosen] == p->leader_generation[slot] ? chosen : -1;
}

static inline void remember(Pass *p, int at, int player) {
    p->seen_x[at] = p->party_x[player];
    p->seen_z[at] = p->party_z[player];
    p->seen_tick[at] = p->tick;
}

/* ---- Senses: light, scent and hearing ---- */

static inline int grid_cell(const MobSense *s, float x, float z) {
    int cx = (int)floorf((x - s->real[SR_GRID_ORIGIN_X]) / s->real[SR_GRID_CELL]);
    int cz = (int)floorf((z - s->real[SR_GRID_ORIGIN_Z]) / s->real[SR_GRID_CELL]);
    if (cx < 0 || cz < 0 || cx >= s->dim[SD_GRID_WIDTH] || cz >= s->dim[SD_GRID_HEIGHT]) return -1;
    return cx + cz * s->dim[SD_GRID_WIDTH];
}

/* Rebuilds the light grid only when the light sources or the ambient level change. */
static int refresh_light(Pass *p) {
    MobSense *s = p->s;
    int64_t length = p->light_count * MS_LIGHT_STRIDE;
    if (s->light_ready && length == s->light_key_length && p->ambient == s->light_key_ambient
            && (length == 0 || memcmp(s->light_key, p->lights, (size_t)length * sizeof(float)) == 0)) {
        return 1;
    }
    float *key = realloc(s->light_key, (size_t)(length > 0 ? length : 1) * sizeof(float));
    if (key == NULL) return 0;
    s->light_key = key;
    if (length > 0) memcpy(s->light_key, p->lights, (size_t)length * sizeof(float));
    s->light_key_length = length;
    s->light_key_ambient = p->ambient;
    int w = s->dim[SD_GRID_WIDTH], h = s->dim[SD_GRID_HEIGHT];
    float cell = s->real[SR_GRID_CELL];
    for (int cz = 0; cz < h; cz++) {
        for (int cx = 0; cx < w; cx++) {
            float x = s->real[SR_GRID_ORIGIN_X] + ((float)cx + 0.5f) * cell, z = s->real[SR_GRID_ORIGIN_Z] + ((float)cz + 0.5f) * cell;
            float level = p->ambient;
            for (int64_t i = 0; i < p->light_count; i++) {
                const float *light = p->lights + i * MS_LIGHT_STRIDE;
                float dx = x - light[0], dz = z - light[1], radius = light[2];
                float distance = sqrtf(dx * dx + dz * dz);
                if (radius > 0.0f && distance < radius) level += light[3] * (1.0f - distance / radius);
            }
            s->light[cx + cz * w] = level < 0.0f ? 0.0f : (level > 1.0f ? 1.0f : level);
        }
    }
    /* Two-pass chamfer distance to the nearest lit cell, with straight and diagonal steps. */
    float straight = cell, diagonal = cell * SQRT2_F;
    float *dark = s->darkness;
    for (int i = 0; i < w * h; i++) dark[i] = s->light[i] >= LIT_THRESHOLD ? 0.0f : NO_LIGHT;
    for (int cz = 0; cz < h; cz++) {
        for (int cx = 0; cx < w; cx++) {
            float *d = dark + cx + cz * w;
            if (cx > 0 && d[-1] + straight < *d) *d = d[-1] + straight;
            if (cz > 0) {
                if (d[-w] + straight < *d) *d = d[-w] + straight;
                if (cx > 0 && d[-w - 1] + diagonal < *d) *d = d[-w - 1] + diagonal;
                if (cx < w - 1 && d[-w + 1] + diagonal < *d) *d = d[-w + 1] + diagonal;
            }
        }
    }
    for (int cz = h - 1; cz >= 0; cz--) {
        for (int cx = w - 1; cx >= 0; cx--) {
            float *d = dark + cx + cz * w;
            if (cx < w - 1 && d[1] + straight < *d) *d = d[1] + straight;
            if (cz < h - 1) {
                if (d[w] + straight < *d) *d = d[w] + straight;
                if (cx < w - 1 && d[w + 1] + diagonal < *d) *d = d[w + 1] + diagonal;
                if (cx > 0 && d[w - 1] + diagonal < *d) *d = d[w - 1] + diagonal;
            }
        }
    }
    s->light_ready = 1;
    return 1;
}

float ms_darkness_at(const MobSense *s, float x, float z) {
    if (!s->light_ready) return 0.0f;
    int cell = grid_cell(s, x, z);
    if (cell < 0) return s->light_key_ambient >= LIT_THRESHOLD ? 0.0f : NO_LIGHT;
    return s->darkness[cell];
}

float ms_light_at(const MobSense *s, float x, float z) {
    if (!s->light_ready) return 1.0f;
    int cell = grid_cell(s, x, z);
    return cell < 0 ? s->light_key_ambient : s->light[cell];
}

float ms_scent_at(const MobSense *s, int player, float x, float z) {
    int cell = grid_cell(s, x, z);
    if (player < 0 || player >= s->dim[SD_PLAYERS] || cell < 0) return 0.0f;
    return s->scent[(int64_t)player * s->dim[SD_GRID_WIDTH] * s->dim[SD_GRID_HEIGHT] + cell];
}

static void lay_scent(Pass *p) {
    MobSense *s = p->s;
    int64_t cells = (int64_t)s->dim[SD_GRID_WIDTH] * s->dim[SD_GRID_HEIGHT];
    if (s->last_decay_tick < 0) s->last_decay_tick = p->tick;
    while (p->tick - s->last_decay_tick >= s->dim[SD_SCENT_DECAY_TICKS]) {
        for (int64_t i = 0; i < cells * p->players; i++) s->scent[i] *= s->real[SR_SCENT_DECAY];
        s->last_decay_tick += s->dim[SD_SCENT_DECAY_TICKS];
    }
    for (int player = 0; player < p->players; player++) {
        if (!targetable(p, player)) continue;
        int cell = grid_cell(s, p->party_x[player], p->party_z[player]);
        if (cell >= 0) s->scent[player * cells + cell] = 1.0f;
    }
}

/* Follows the freshest scent within smell range. Returns 1 and the cell centre when one is strong enough. */
static int sniff(const Pass *p, int slot, int player, double range, float *out_x, float *out_z) {
    const MobSense *s = p->s;
    int w = s->dim[SD_GRID_WIDTH], h = s->dim[SD_GRID_HEIGHT];
    int64_t cells = (int64_t)w * h;
    float cell = s->real[SR_GRID_CELL], x = p->xz[slot * 2], z = p->xz[slot * 2 + 1];
    int reach = (int)ceil(range / cell);
    int centre = grid_cell(s, x, z);
    if (centre < 0) return 0;
    int ox = centre % w, oz = centre / w;
    float best = s->real[SR_SCENT_THRESHOLD];
    int found = -1;
    for (int cz = oz - reach; cz <= oz + reach; cz++) {
        if (cz < 0 || cz >= h) continue;
        for (int cx = ox - reach; cx <= ox + reach; cx++) {
            if (cx < 0 || cx >= w) continue;
            double dx = (double)(cx - ox) * cell, dz = (double)(cz - oz) * cell;
            if (dx * dx + dz * dz > range * range) continue;
            float value = s->scent[player * cells + cx + cz * w];
            if (value > best) {
                best = value;
                found = cx + cz * w;
            }
        }
    }
    if (found < 0) return 0;
    *out_x = s->real[SR_GRID_ORIGIN_X] + ((float)(found % w) + 0.5f) * cell;
    *out_z = s->real[SR_GRID_ORIGIN_Z] + ((float)(found / w) + 0.5f) * cell;
    return 1;
}

/* Noises reach every mob whose hearing covers them, even through walls. */
static int hear(Pass *p, int newly_count) {
    const MobSense *s = p->s;
    for (int64_t n = 0; n < p->noise_count; n++) {
        const float *noise = p->noises + n * MS_NOISE_STRIDE;
        int player = (int)noise[3];
        if (player < 0 || player >= p->players || !targetable(p, player)) continue;
        for (int64_t i = 0; i < p->active_count; i++) {
            int slot = p->active[i];
            double range = (double)s->hearing[p->species[slot]] * (double)noise[2];
            if (range <= 0.0 || distance_to(p, slot, noise[0], noise[1]) > range) continue;
            int at = slot * p->players + player;
            p->seen_x[at] = noise[0];
            p->seen_z[at] = noise[1];
            p->seen_tick[at] = p->tick;
            p->last_sensed[slot] = p->tick;
            if (p->engaged[slot] == 0) {
                p->engaged[slot] = 1;
                p->s->newly[newly_count++] = slot;
            }
        }
    }
    return newly_count;
}

/* ---- Sight and alerts, matching MobPerception.update_reference ---- */

static MsResult alert_neighbours(Pass *p, int newly_count) {
    MobSense *s = p->s;
    int k = s->dim[SD_ALERT_NEIGHBOURS];
    for (int i = 0; i < newly_count; i++) s->slot_floats[i] = (float)s->newly[i];
    if (mn_nearest_batch(p->nav, s->slot_floats, newly_count, s->real[SR_ALERT_RADIUS], k, s->nearest) != MN_OK) return SK_ERR_STATE;
    int pair_count = 0;
    for (int index = 0; index < newly_count; index++) {
        int source = s->newly[index];
        for (int n = 0; n < k; n++) {
            int other = (int)s->nearest[index * k + n];
            if (other < 0) break;
            if (p->engaged[other] != 0) continue;
            float *query = s->queries + pair_count * SIGHT_STRIDE;
            query[0] = p->xz[source * 2];
            query[1] = p->xz[source * 2 + 1];
            query[2] = p->xz[other * 2];
            query[3] = p->xz[other * 2 + 1];
            query[4] = 0.0f;
            s->pairs[pair_count * 2] = source;
            s->pairs[pair_count * 2 + 1] = other;
            pair_count++;
        }
    }
    if (pair_count == 0) return SK_OK;
    mn_sight_clear_batch(p->nav, s->queries, pair_count, s->clear);
    for (int index = 0; index < pair_count; index++) {
        if (s->clear[index] == 0) continue;
        int source = s->pairs[index * 2], other = s->pairs[index * 2 + 1];
        p->engaged[other] = 1;
        p->last_sensed[other] = p->tick;
        for (int player = 0; player < p->players; player++) {
            if (p->seen_tick[source * p->players + player] >= 0) {
                p->seen_x[other * p->players + player] = p->seen_x[source * p->players + player];
                p->seen_z[other * p->players + player] = p->seen_z[source * p->players + player];
                p->seen_tick[other * p->players + player] = p->seen_tick[source * p->players + player];
            }
        }
    }
    return SK_OK;
}

MsResult ms_update(MobSense *s, MobNav *nav, const void *const *items, const int64_t *lengths, uint8_t *out) {
    Pass p;
    if (!bind(&p, s, nav, items, lengths)) return SK_ERR_ARGUMENT;
    int capacity = p.capacity, players = p.players;
    int64_t sensed = (int64_t)capacity * players;
    /* Four-byte arrays first so every pointer stays aligned. */
    p.seen_x = (float *)out;
    p.seen_z = p.seen_x + sensed;
    p.seen_tick = (int *)(p.seen_z + sensed);
    p.last_sensed = p.seen_tick + sensed;
    p.visible = (uint8_t *)(p.last_sensed + capacity);
    p.engaged = p.visible + sensed;
    memcpy(p.visible, items[SI_VISIBLE], (size_t)sensed);
    memcpy(p.seen_x, items[SI_SEEN_X], (size_t)sensed * 4);
    memcpy(p.seen_z, items[SI_SEEN_Z], (size_t)sensed * 4);
    memcpy(p.seen_tick, items[SI_SEEN_TICK], (size_t)sensed * 4);
    memcpy(p.engaged, items[SI_ENGAGED], (size_t)capacity);
    memcpy(p.last_sensed, items[SI_LAST_SENSED], (size_t)capacity * 4);
    int senses = s->dim[SD_SENSES] != 0;
    if (senses) {
        if (!refresh_light(&p)) return SK_ERR_MEMORY;
        lay_scent(&p);
    }
    int query_count = 0, newly_count = 0;
    double awareness = s->real[SR_AWARENESS];
    for (int64_t i = 0; i < p.active_count; i++) {
        int slot = p.active[i];
        if ((p.tick + slot) % s->dim[SD_REFRESH_TICKS] != 0) continue;
        double x = p.xz[slot * 2], z = p.xz[slot * 2 + 1];
        int kind = p.species[slot];
        for (int player = 0; player < players; player++) {
            int at = slot * players + player;
            p.visible[at] = 0;
            if (!targetable(&p, player)) continue;
            double dx = (double)p.party_x[player] - x, dz = (double)p.party_z[player] - z;
            double distance = sqrt(dx * dx + dz * dz);
            int seeable = distance <= (double)s->vision[kind];
            if (senses && seeable) {
                /* Darkvision counts as light within its range of the mob, and extends past the edge of
                 * any lit area by the same range. A lit player is seen at full sight range. */
                double darkvision = s->darkvision[kind];
                seeable = distance <= darkvision || (double)ms_darkness_at(s, p.party_x[player], p.party_z[player]) <= darkvision;
            }
            if (seeable) {
                float *query = s->queries + query_count * SIGHT_STRIDE;
                query[0] = (float)x;
                query[1] = (float)z;
                query[2] = p.party_x[player];
                query[3] = p.party_z[player];
                query[4] = 0.0f;
                s->owners[query_count++] = at;
            } else if (!senses && p.engaged[slot] != 0 && distance <= awareness) {
                /* Without senses, an engaged mob keeps tracking anyone within its awareness radius. */
                remember(&p, at, player);
                p.last_sensed[slot] = p.tick;
            }
        }
    }
    if (query_count > 0) {
        mn_sight_clear_batch(nav, s->queries, query_count, s->clear);
        for (int index = 0; index < query_count; index++) {
            int at = s->owners[index], slot = at / players, player = at % players;
            if (s->clear[index] != 0) {
                p.visible[at] = 1;
                remember(&p, at, player);
                p.last_sensed[slot] = p.tick;
                if (p.engaged[slot] == 0) {
                    p.engaged[slot] = 1;
                    s->newly[newly_count++] = slot;
                }
            } else if (!senses && p.engaged[slot] != 0) {
                /* Without senses, an engaged mob tracks a player even behind cover. With senses on,
                 * hearing and smell must earn that knowledge instead. */
                remember(&p, at, player);
                p.last_sensed[slot] = p.tick;
            }
        }
    }
    if (senses) {
        newly_count = hear(&p, newly_count);
        for (int64_t i = 0; i < p.active_count; i++) {
            int slot = p.active[i];
            double range = s->smell[p.species[slot]];
            if ((p.tick + slot) % s->dim[SD_REFRESH_TICKS] != 0 || range <= 0.0 || p.engaged[slot] == 0) continue;
            for (int player = 0; player < players; player++) {
                int at = slot * players + player;
                float x, z;
                if (p.visible[at] != 0 || !targetable(&p, player) || !sniff(&p, slot, player, range, &x, &z)) continue;
                p.seen_x[at] = x;
                p.seen_z[at] = z;
                p.seen_tick[at] = p.tick;
                p.last_sensed[slot] = p.tick;
            }
        }
    }
    if (newly_count > 0) return alert_neighbours(&p, newly_count);
    return SK_OK;
}

/* ---- Ally slots, matching MobPerception.refresh_allies_reference ---- */

static int is_slotted(const Pass *p, int base, int other) {
    for (int index = 0; index < p->allies; index++) if (p->ally[base + index] == other) return 1;
    return 0;
}

static void refresh_one(Pass *p, int slot, const float *nearest, int k) {
    const MobSense *s = p->s;
    int base = slot * p->allies;
    int leader = leader_of(p, slot);
    double radius = s->real[SR_ALLY_RADIUS];
    for (int index = 0; index < p->allies; index++) {
        int other = p->ally[base + index];
        if (other < 0) continue;
        if (p->alive[other] == 0 || p->generation[other] != p->ally_generation[base + index] || other == leader) {
            p->ally[base + index] = -1;
            p->ally_away_since[base + index] = -1;
        } else if (distance_to(p, slot, p->xz[other * 2], p->xz[other * 2 + 1]) <= radius) {
            p->ally_away_since[base + index] = -1;
        } else if (p->ally_away_since[base + index] < 0) {
            p->ally_away_since[base + index] = p->tick;
        } else if (p->tick - p->ally_away_since[base + index] >= s->dim[SD_RELEASE_TICKS]) {
            p->ally[base + index] = -1;
            p->ally_away_since[base + index] = -1;
        }
    }
    int candidate = 0;
    for (int index = 0; index < p->allies; index++) {
        if (p->ally[base + index] >= 0) continue;
        while (candidate < k) {
            int other = (int)nearest[candidate];
            candidate++;
            if (other < 0) return;
            if (other != leader && !is_slotted(p, base, other)) {
                p->ally[base + index] = other;
                p->ally_generation[base + index] = p->generation[other];
                p->ally_away_since[base + index] = -1;
                break;
            }
        }
    }
}

MsResult ms_allies(MobSense *s, MobNav *nav, const void *const *items, const int64_t *lengths, uint8_t *out) {
    Pass p;
    if (!bind(&p, s, nav, items, lengths)) return SK_ERR_ARGUMENT;
    int64_t slotted = (int64_t)p.capacity * p.allies;
    p.ally = (int *)out;
    p.ally_generation = p.ally + slotted;
    p.ally_away_since = p.ally_generation + slotted;
    memcpy(p.ally, items[SI_ALLIES], (size_t)slotted * 4);
    memcpy(p.ally_generation, items[SI_ALLY_GENERATION], (size_t)slotted * 4);
    memcpy(p.ally_away_since, items[SI_ALLY_AWAY_SINCE], (size_t)slotted * 4);
    if (p.slot_count == 0) return SK_OK;
    int k = s->dim[SD_NEAREST_LIMIT];
    for (int64_t i = 0; i < p.slot_count; i++) s->slot_floats[i] = (float)p.slots[i];
    if (mn_nearest_batch(nav, s->slot_floats, (int)p.slot_count, s->real[SR_ALLY_RADIUS], k, s->nearest) != MN_OK) return SK_ERR_STATE;
    for (int64_t i = 0; i < p.slot_count; i++) refresh_one(&p, p.slots[i], s->nearest + i * k, k);
    return SK_OK;
}
