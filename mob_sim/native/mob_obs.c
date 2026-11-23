#include "mob_obs.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define TAU_D 6.283185307179586
#define COVER_ANGLES 8
#define COVER_RADII 2
#define MAX_COVER_POINTS (COVER_ANGLES * COVER_RADII)

static const float cover_radius[COVER_RADII] = {3.0f, 6.0f};

static const MoKind config_kinds[MC_COUNT] = {
    [MC_DIMS] = MO_INTS, [MC_FIELDS] = MO_INTS, [MC_STRIDES] = MO_INTS, [MC_SCALE_KIND] = MO_BYTES, [MC_SCALE_INVERSE] = MO_FLOATS,
    [MC_REALS] = MO_FLOATS, [MC_VISION] = MO_FLOATS, [MC_HIT_RADIUS] = MO_FLOATS, [MC_MAX_RANGE] = MO_FLOATS, [MC_SUPPORT] = MO_BYTES,
    [MC_ROLE] = MO_INTS, [MC_ATTACK_EXISTS] = MO_BYTES, [MC_ATTACK_MUTATION] = MO_INTS, [MC_ATTACK_SHAPE] = MO_BYTES,
    [MC_ATTACK_RANGE] = MO_FLOATS, [MC_ATTACK_AREA] = MO_FLOATS, [MC_ATTACK_WINDUP] = MO_INTS, [MC_ATTACK_RECOVERY] = MO_INTS,
    [MC_HOLD_TICKS] = MO_INTS, [MC_TARGET_KIND] = MO_BYTES, [MC_TRAITS] = MO_FLOATS,
};

static const MoKind input_kinds[MI_COUNT] = {
    [MI_CLOCK] = MO_INTS, [MI_SLOTS] = MO_INTS, [MI_ACTIVE] = MO_INTS, [MI_ALIVE] = MO_BYTES, [MI_GENERATION] = MO_INTS,
    [MI_SPECIES] = MO_INTS, [MI_FLAGS] = MO_BYTES, [MI_MUTATIONS] = MO_INTS, [MI_LEADER] = MO_INTS, [MI_LEADER_GENERATION] = MO_INTS,
    [MI_XZ] = MO_FLOATS, [MI_HP] = MO_FLOATS, [MI_MAX_HP] = MO_FLOATS, [MI_SPEED] = MO_FLOATS, [MI_DAMAGE] = MO_FLOATS,
    [MI_REACH_BONUS] = MO_FLOATS, [MI_INTELLIGENCE] = MO_FLOATS, [MI_BEHAVIOUR] = MO_BYTES, [MI_ENEMY_TARGET] = MO_BYTES,
    [MI_ALLY_TARGET] = MO_BYTES, [MI_MESSAGE_A] = MO_BYTES, [MI_MESSAGE_B] = MO_BYTES, [MI_BEHAVIOUR_SINCE] = MO_INTS,
    [MI_READY_AT] = MO_INTS, [MI_COOLDOWN_UNTIL] = MO_INTS, [MI_STUN_UNTIL] = MO_INTS, [MI_ROOT_UNTIL] = MO_INTS,
    [MI_SLOW_UNTIL] = MO_INTS, [MI_HASTE_UNTIL] = MO_INTS, [MI_VISIBLE] = MO_BYTES, [MI_SEEN_X] = MO_FLOATS, [MI_SEEN_Z] = MO_FLOATS,
    [MI_SEEN_TICK] = MO_INTS, [MI_ALLIES] = MO_INTS, [MI_PARTY_PRESENT] = MO_BYTES, [MI_PARTY_ALIVE] = MO_BYTES, [MI_PARTY_HP] = MO_FLOATS,
    [MI_PARTY_MAX_HP] = MO_FLOATS, [MI_PARTY_VX] = MO_FLOATS, [MI_PARTY_VZ] = MO_FLOATS, [MI_TAKEN] = MO_FLOATS, [MI_DEALT] = MO_FLOATS,
    [MI_TAKEN_FROM] = MO_FLOATS, [MI_DEALT_TO] = MO_FLOATS, [MI_ENGAGED_AT] = MO_INTS,
    [MI_MANA] = MO_FLOATS, [MI_CHANNEL_UNTIL] = MO_INTS, [MI_DODGE_UNTIL] = MO_INTS, [MI_DODGE_READY] = MO_INTS,
    [MI_DOT_UNTIL] = MO_INTS, [MI_ARMOUR] = MO_BYTES, [MI_FIELD_X] = MO_FLOATS, [MI_FIELD_Z] = MO_FLOATS,
    [MI_FIELD_RADIUS] = MO_FLOATS, [MI_FIELD_ACTIVATE] = MO_INTS, [MI_FIELD_UNTIL] = MO_INTS, [MI_FIELD_OWNER] = MO_BYTES,
    [MI_FIELD_FLAGS] = MO_BYTES, [MI_PARTY_STATS] = MO_FLOATS, [MI_PARTY_TIMERS] = MO_INTS,
};

MoKind mo_config_kind(int index) { return config_kinds[index]; }
MoKind mo_input_kind(int index) { return input_kinds[index]; }

struct MobObs {
    int dim[MD_COUNT];
    int field[MF_COUNT];
    int stride[MS_COUNT];
    float real[MR_COUNT];
    uint8_t *scale_kind;
    float *scale_inverse;
    float *vision, *hit_radius, *max_range, *attack_range, *attack_area;
    uint8_t *support, *attack_exists, *attack_shape, *target_kind;
    int *role, *attack_mutation, *attack_windup, *attack_recovery, *hold_ticks;
    float *traits;
    float *seen_hp, *seen_max_hp, *seen_vx, *seen_vz;
    int *last_visible;
};

typedef struct {
    MobObs *o;
    const MobNav *nav;
    const MobSense *sense;
    float *out;
    int base;
    double vision;
    int tick;
    int bucket;
    const int *active;
    int active_count;
    const uint8_t *alive, *flags, *behaviour, *enemy_target, *ally_target, *message_a, *message_b, *visible;
    const uint8_t *party_present, *party_alive;
    const int *generation, *species, *mutations, *leader, *leader_generation, *behaviour_since, *ready_at, *cooldown_until;
    const int *stun_until, *root_until, *slow_until, *haste_until, *seen_tick, *allies, *engaged_at;
    const float *xz, *hp, *max_hp, *speed, *damage, *reach_bonus, *intelligence, *seen_x, *seen_z;
    const float *party_hp, *party_max_hp, *party_vx, *party_vz, *taken, *dealt, *taken_from, *dealt_to;
    const float *mana, *field_x, *field_z, *field_radius, *party_stats;
    const int *channel_until, *dodge_until, *dodge_ready, *dot_until, *field_activate, *field_until, *party_timers;
    const uint8_t *armour, *field_owner, *field_flags;
    int field_count;
    int targeting[8];
} Ctx;

void mo_destroy(MobObs *obs) {
    if (obs == NULL) return;
    free(obs->scale_kind);
    free(obs->scale_inverse);
    free(obs->vision);
    free(obs->hit_radius);
    free(obs->max_range);
    free(obs->attack_range);
    free(obs->attack_area);
    free(obs->support);
    free(obs->attack_exists);
    free(obs->attack_shape);
    free(obs->target_kind);
    free(obs->role);
    free(obs->attack_mutation);
    free(obs->attack_windup);
    free(obs->attack_recovery);
    free(obs->hold_ticks);
    free(obs->traits);
    free(obs->seen_hp);
    free(obs->seen_max_hp);
    free(obs->seen_vx);
    free(obs->seen_vz);
    free(obs->last_visible);
    free(obs);
}

static void *copy_table(const void *source, int64_t count, size_t width) {
    void *copy = malloc((size_t)count * width + 1);
    if (copy != NULL && count > 0) memcpy(copy, source, (size_t)count * width);
    return copy;
}

MoResult mo_create(const void *const *items, const int64_t *lengths, MobObs **out) {
    if (items == NULL || lengths == NULL || out == NULL || lengths[MC_DIMS] != MD_COUNT || lengths[MC_FIELDS] != MF_COUNT ||
        lengths[MC_STRIDES] != MS_COUNT || lengths[MC_REALS] != MR_COUNT) {
        return MO_ERR_ARGUMENT;
    }
    const int *dim = items[MC_DIMS];
    int capacity = dim[MD_CAPACITY], players = dim[MD_PLAYERS], species = dim[MD_SPECIES], attacks = dim[MD_ATTACKS];
    int size = dim[MD_OBSERVATION];
    if (capacity <= 0 || players <= 0 || players > 7 || species <= 0 || attacks <= 0 || size <= 0 || dim[MD_ALLIES] <= 0 ||
        dim[MD_BUCKETS] <= 0 || dim[MD_ONE_SECOND] <= 0 || dim[MD_ONE_SECOND] > dim[MD_BUCKETS] || dim[MD_COVER_SLOTS] <= 0 ||
        dim[MD_ABILITIES] <= 0 || dim[MD_ABILITIES] >= attacks) {
        return MO_ERR_ARGUMENT;
    }
    int attack_cells = species * attacks;
    if (lengths[MC_SCALE_KIND] != size || lengths[MC_SCALE_INVERSE] != size || lengths[MC_VISION] != species ||
        lengths[MC_HIT_RADIUS] != species || lengths[MC_MAX_RANGE] != species || lengths[MC_SUPPORT] != species ||
        lengths[MC_ROLE] != species || lengths[MC_ATTACK_EXISTS] != attack_cells || lengths[MC_ATTACK_MUTATION] != attack_cells ||
        lengths[MC_ATTACK_SHAPE] != attack_cells || lengths[MC_ATTACK_RANGE] != attack_cells || lengths[MC_ATTACK_AREA] != attack_cells ||
        lengths[MC_ATTACK_WINDUP] != attack_cells || lengths[MC_ATTACK_RECOVERY] != attack_cells ||
        lengths[MC_HOLD_TICKS] != dim[MD_BEHAVIOURS] || lengths[MC_TARGET_KIND] != dim[MD_BEHAVIOURS] ||
        lengths[MC_TRAITS] != (int64_t)species * MT_COUNT || dim[MD_HAZARD_SLOTS] <= 0 || dim[MD_CLASSES] < 0 ||
        dim[MD_CLASSES] > MO_MAX_CLASSES) {
        return MO_ERR_ARGUMENT;
    }
    const int *fields = items[MC_FIELDS];
    for (int i = 0; i < MF_COUNT; i++) {
        if (fields[i] < 0 || fields[i] >= size) return MO_ERR_ARGUMENT;
    }
    if (fields[MF_PARTY_CLASSES] + dim[MD_CLASSES] > size) return MO_ERR_ARGUMENT;
    MobObs *o = calloc(1, sizeof(*o));
    if (o == NULL) return MO_ERR_MEMORY;
    memcpy(o->dim, dim, sizeof(o->dim));
    memcpy(o->field, fields, sizeof(o->field));
    memcpy(o->stride, items[MC_STRIDES], sizeof(o->stride));
    memcpy(o->real, items[MC_REALS], sizeof(o->real));
    o->scale_kind = copy_table(items[MC_SCALE_KIND], size, 1);
    o->scale_inverse = copy_table(items[MC_SCALE_INVERSE], size, sizeof(float));
    o->vision = copy_table(items[MC_VISION], species, sizeof(float));
    o->hit_radius = copy_table(items[MC_HIT_RADIUS], species, sizeof(float));
    o->max_range = copy_table(items[MC_MAX_RANGE], species, sizeof(float));
    o->support = copy_table(items[MC_SUPPORT], species, 1);
    o->role = copy_table(items[MC_ROLE], species, sizeof(int));
    o->attack_exists = copy_table(items[MC_ATTACK_EXISTS], attack_cells, 1);
    o->attack_mutation = copy_table(items[MC_ATTACK_MUTATION], attack_cells, sizeof(int));
    o->attack_shape = copy_table(items[MC_ATTACK_SHAPE], attack_cells, 1);
    o->attack_range = copy_table(items[MC_ATTACK_RANGE], attack_cells, sizeof(float));
    o->attack_area = copy_table(items[MC_ATTACK_AREA], attack_cells, sizeof(float));
    o->attack_windup = copy_table(items[MC_ATTACK_WINDUP], attack_cells, sizeof(int));
    o->attack_recovery = copy_table(items[MC_ATTACK_RECOVERY], attack_cells, sizeof(int));
    o->hold_ticks = copy_table(items[MC_HOLD_TICKS], dim[MD_BEHAVIOURS], sizeof(int));
    o->target_kind = copy_table(items[MC_TARGET_KIND], dim[MD_BEHAVIOURS], 1);
    o->traits = copy_table(items[MC_TRAITS], (int64_t)species * MT_COUNT, sizeof(float));
    size_t sensed = (size_t)capacity * (size_t)players;
    o->seen_hp = calloc(sensed, sizeof(float));
    o->seen_max_hp = calloc(sensed, sizeof(float));
    o->seen_vx = calloc(sensed, sizeof(float));
    o->seen_vz = calloc(sensed, sizeof(float));
    o->last_visible = malloc((size_t)capacity * sizeof(int));
    if (!o->scale_kind || !o->scale_inverse || !o->vision || !o->hit_radius || !o->max_range || !o->support || !o->role ||
        !o->attack_exists || !o->attack_mutation || !o->attack_shape || !o->attack_range || !o->attack_area || !o->attack_windup ||
        !o->attack_recovery || !o->hold_ticks || !o->target_kind || !o->traits || !o->seen_hp || !o->seen_max_hp || !o->seen_vx || !o->seen_vz ||
        !o->last_visible) {
        mo_destroy(o);
        return MO_ERR_MEMORY;
    }
    for (int i = 0; i < capacity; i++) o->last_visible[i] = -1;
    *out = o;
    return MO_OK;
}

void mo_reset_slot(MobObs *obs, int slot) {
    if (obs != NULL && slot >= 0 && slot < obs->dim[MD_CAPACITY]) obs->last_visible[slot] = -1;
}

int mo_observation_size(const MobObs *obs) { return obs->dim[MD_OBSERVATION]; }

/* Scale kinds match ai/mob_schema.gd: none, divide, log1p, vision. */
static inline void put(Ctx *c, int field, double value) {
    const MobObs *o = c->o;
    int kind = o->scale_kind[field];
    if (kind == 3) value /= c->vision;
    else if (kind == 1) value *= (double)o->scale_inverse[field];
    else if (kind == 2) value = log(1.0 + (value > 0.0 ? value : 0.0)) * (double)o->scale_inverse[field];
    double clip = (double)o->real[MR_CLIP];
    c->out[c->base + field] = (float)(value < -clip ? -clip : (value > clip ? clip : value));
}

static inline void flag(Ctx *c, int field) { c->out[c->base + field] = 1.0f; }

static inline double seconds(const Ctx *c, int ticks) { return (double)ticks / (double)c->o->real[MR_TICK_RATE]; }

static inline int non_negative(int value) { return value > 0 ? value : 0; }

static double window_sum(const Ctx *c, const float *table, int row, int buckets) {
    int size = c->o->dim[MD_BUCKETS];
    double total = 0.0;
    for (int back = 0; back < buckets; back++) {
        int at = (c->bucket - back) % size;
        if (at < 0) at += size;
        total += (double)table[(size_t)row * (size_t)size + (size_t)at];
    }
    return total;
}

static inline int has_attack(const MobObs *o, int kind, int attack, int mutations) {
    int at = kind * o->dim[MD_ATTACKS] + attack;
    return o->attack_exists[at] != 0 && (o->attack_mutation[at] == 0 || (mutations & o->attack_mutation[at]) != 0);
}

static inline int targetable(const Ctx *c, int player) { return c->party_present[player] != 0 && c->party_alive[player] != 0; }

static int leader_of(const Ctx *c, int slot) {
    int chosen = c->leader[slot];
    return chosen >= 0 && c->alive[chosen] != 0 && c->generation[chosen] == c->leader_generation[slot] ? chosen : -1;
}

static void write_capabilities(Ctx *c, int slot, int kind) {
    const MobObs *o = c->o;
    const int *f = o->field;
    put(c, f[MF_WALK_SPEED], c->speed[slot]);
    put(c, f[MF_SIZE], o->hit_radius[kind]);
    put(c, f[MF_MAX_HP], c->max_hp[slot]);
    put(c, f[MF_VISION_RANGE], o->vision[kind]);
    if (has_attack(o, kind, 0, c->mutations[slot])) {
        int at = kind * o->dim[MD_ATTACKS];
        put(c, f[MF_AUTO_DAMAGE], c->damage[slot]);
        put(c, f[MF_AUTO_RANGE], (double)o->attack_range[at] + (double)c->reach_bonus[slot]);
        put(c, f[MF_AUTO_COOLDOWN], seconds(c, o->attack_recovery[at]));
    }
}

static void write_abilities(Ctx *c, int slot, int kind) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int attacks = o->dim[MD_ATTACKS];
    for (int ability = 0; ability < o->dim[MD_ABILITIES]; ability++) {
        int attack = ability + 1;
        if (!has_attack(o, kind, attack, c->mutations[slot])) continue;
        int shift = ability * o->stride[MS_ABILITY];
        int row = kind * attacks + attack;
        int shape = o->attack_shape[row];
        int helpful = shape == o->dim[MD_SHAPE_BUFF] || shape == o->dim[MD_SHAPE_SUMMON];
        int cooldown = c->cooldown_until[slot * attacks + attack];
        int ready = c->ready_at[slot] > cooldown ? c->ready_at[slot] : cooldown;
        put(c, f[MF_AB_EXISTS] + shift, 1.0);
        put(c, f[MF_AB_DAMAGE] + shift, helpful ? 0.0 : (double)c->damage[slot]);
        put(c, f[MF_AB_RANGE] + shift, (double)o->attack_range[row] + (double)c->reach_bonus[slot]);
        put(c, f[MF_AB_COOLDOWN_TOTAL] + shift, seconds(c, o->attack_recovery[row]));
        put(c, f[MF_AB_COOLDOWN_REMAINING] + shift, seconds(c, non_negative(ready - c->tick)));
        put(c, f[MF_AB_SIGN] + shift, helpful ? 1.0 : -1.0);
        put(c, f[MF_AB_AREA] + shift, o->attack_area[row]);
        put(c, f[MF_AB_WINDUP] + shift, seconds(c, o->attack_windup[row]));
    }
}

static void write_enemies(Ctx *c, int slot) {
    MobObs *o = c->o;
    const int *f = o->field;
    int players = o->dim[MD_PLAYERS], buckets = o->dim[MD_BUCKETS];
    double x = c->xz[slot * 2], z = c->xz[slot * 2 + 1];
    int sees_any = 0;
    for (int player = 0; player < players; player++) {
        int row = slot * players + player;
        if (c->party_present[player] == 0 || c->seen_tick[row] < 0) continue;
        int shift = player * o->stride[MS_ENEMY];
        int sees = c->visible[row] != 0 && targetable(c, player);
        if (sees) {
            sees_any = 1;
            o->seen_hp[row] = c->party_hp[player];
            o->seen_max_hp[row] = c->party_max_hp[player];
            o->seen_vx[row] = c->party_vx[player];
            o->seen_vz[row] = c->party_vz[player];
        }
        double dx = (double)c->seen_x[row] - x, dz = (double)c->seen_z[row] - z;
        put(c, f[MF_E_PRESENT] + shift, 1.0);
        put(c, f[MF_E_VISIBLE] + shift, sees);
        put(c, f[MF_E_SINCE_SEEN] + shift, seconds(c, c->tick - c->seen_tick[row]));
        put(c, f[MF_E_DX] + shift, dx);
        put(c, f[MF_E_DY] + shift, dz);
        put(c, f[MF_E_DISTANCE] + shift, sqrt(dx * dx + dz * dz));
        put(c, f[MF_E_VX] + shift, o->seen_vx[row]);
        put(c, f[MF_E_VY] + shift, o->seen_vz[row]);
        double most = o->seen_max_hp[row] > 1.0f ? (double)o->seen_max_hp[row] : 1.0;
        put(c, f[MF_E_HP] + shift, (double)o->seen_hp[row] / most);
        put(c, f[MF_E_MAX_HP] + shift, o->seen_max_hp[row]);
        put(c, f[MF_E_DOWNED] + shift, c->party_alive[player] == 0);
        float ax = (float)-dx, az = (float)-dz, bx = o->seen_vx[row], bz = o->seen_vz[row];
        float la = ax * ax + az * az, lb = bx * bx + bz * bz;
        if (la != 0.0f) { la = sqrtf(la); ax /= la; az /= la; }
        if (lb != 0.0f) { lb = sqrtf(lb); bx /= lb; bz /= lb; }
        put(c, f[MF_E_FACING] + shift, sees && (double)(ax * bx + az * bz) >= (double)o->real[MR_FACING_DOT]);
        put(c, f[MF_E_SIGHT] + shift, sees);
        put(c, f[MF_E_DEALT_ME] + shift, window_sum(c, c->taken_from, row, buckets));
        put(c, f[MF_E_I_DEALT] + shift, window_sum(c, c->dealt_to, row, buckets));
        put(c, f[MF_E_TARGETING] + shift, c->targeting[player + 1] - (c->enemy_target[slot] == player + 1));
    }
    if (sees_any) o->last_visible[slot] = c->tick;
}

static void write_dynamic(Ctx *c, int slot, int kind) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int one = o->dim[MD_ONE_SECOND], all = o->dim[MD_BUCKETS];
    double max_hp = c->max_hp[slot];
    put(c, f[MF_HP_FRACTION], (double)c->hp[slot] / max_hp);
    put(c, f[MF_HP_CHANGE_1S], -window_sum(c, c->taken, slot, one) / max_hp);
    put(c, f[MF_HP_CHANGE_3S], -window_sum(c, c->taken, slot, all) / max_hp);
    put(c, f[MF_DEALT_1S], window_sum(c, c->dealt, slot, one));
    put(c, f[MF_DEALT_3S], window_sum(c, c->dealt, slot, all));
    if (has_attack(o, kind, 0, c->mutations[slot])) put(c, f[MF_AUTO_REMAINING], seconds(c, non_negative(c->ready_at[slot] - c->tick)));
    int since = c->tick - c->behaviour_since[slot];
    put(c, f[MF_SINCE_BEHAVIOUR], seconds(c, since));
    int hold = o->hold_ticks[c->behaviour[slot]];
    if (hold < 1) hold = 1;
    double progress = (double)since / (double)hold;
    put(c, f[MF_BEHAVIOUR_PROGRESS], progress < 1.0 ? progress : 1.0);
    if (c->engaged_at[slot] >= 0) put(c, f[MF_TIME_IN_COMBAT], seconds(c, c->tick - c->engaged_at[slot]));
    int last = o->last_visible[slot];
    put(c, f[MF_SINCE_SIGHT], last >= 0 ? seconds(c, c->tick - last) : (double)o->real[MR_NEVER_SEEN]);
    put(c, f[MF_IS_LEADER], (c->flags[slot] & o->dim[MD_LEADER_FLAGS]) != 0);
    put(c, f[MF_INTELLIGENCE], c->intelligence[slot]);
}

static void write_status(Ctx *c, int slot) {
    const int *f = c->o->field;
    put(c, f[MF_STUNNED], c->tick < c->stun_until[slot]);
    put(c, f[MF_SLOWED], c->tick < c->slow_until[slot]);
    put(c, f[MF_ROOTED], c->tick < c->root_until[slot]);
    put(c, f[MF_BUFFED], c->tick < c->haste_until[slot]);
}

static void write_intent(Ctx *c, int slot, int kind) {
    const MobObs *o = c->o;
    int behaviour = c->behaviour[slot];
    flag(c, o->field[MF_BEHAVIOUR] + behaviour);
    int target = c->enemy_target[slot];
    if (o->target_kind[behaviour] == o->dim[MD_TARGET_ALLY]) target = c->ally_target[slot] > 0 ? o->dim[MD_PLAYERS] + c->ally_target[slot] : 0;
    flag(c, o->field[MF_TARGET] + target);
    if (o->role[kind] >= 0) flag(c, o->field[MF_ARCHETYPE] + o->role[kind]);
}

/* The ally and leader field ranges share one order, so one writer serves both. */
static void write_mate(Ctx *c, int shift, MoField first, int slot, int other) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int kind = c->species[other];
    int one = o->dim[MD_ONE_SECOND];
    double dx = (double)c->xz[other * 2] - (double)c->xz[slot * 2];
    double dz = (double)c->xz[other * 2 + 1] - (double)c->xz[slot * 2 + 1];
    double max_hp = c->max_hp[other];
#define MATE(name) (f[first + (MF_A_##name - MF_A_PRESENT)] + shift)
    put(c, MATE(PRESENT), 1.0);
    put(c, MATE(DX), dx);
    put(c, MATE(DY), dz);
    put(c, MATE(DISTANCE), sqrt(dx * dx + dz * dz));
    put(c, MATE(HP), (double)c->hp[other] / max_hp);
    put(c, MATE(HP_LOST), window_sum(c, c->taken, other, one) / max_hp);
    put(c, MATE(DEALT), window_sum(c, c->dealt, other, one));
    put(c, MATE(ELITE), (c->flags[other] & o->dim[MD_LEADER_FLAGS]) != 0);
    int support = o->support[kind] != 0;
    int ranged = (double)o->max_range[kind] > (double)o->real[MR_RANGED_ROLE];
    put(c, MATE(MELEE), !support && !ranged);
    put(c, MATE(RANGED), !support && ranged);
    put(c, MATE(SUPPORT), support);
    flag(c, MATE(BEHAVIOUR) + c->behaviour[other]);
    flag(c, MATE(TARGET) + c->enemy_target[other]);
    flag(c, MATE(MESSAGE) + c->message_a[other]);
    flag(c, MATE(MESSAGE) + o->dim[MD_SYMBOLS] + c->message_b[other]);
#undef MATE
}

static void write_mates(Ctx *c, int slot) {
    const MobObs *o = c->o;
    int count = o->dim[MD_ALLIES];
    for (int index = 0; index < count; index++) {
        int other = c->allies[slot * count + index];
        if (other >= 0 && c->alive[other] != 0) write_mate(c, index * o->stride[MS_ALLY], MF_A_PRESENT, slot, other);
    }
    int leader = leader_of(c, slot);
    if (leader < 0) return;
    write_mate(c, 0, MF_L_PRESENT, slot, leader);
    for (int ability = 0; ability < o->dim[MD_ABILITIES]; ability++) {
        int ready = c->cooldown_until[leader * o->dim[MD_ATTACKS] + ability + 1];
        put(c, o->field[MF_L_COOLDOWN] + ability, seconds(c, non_negative(ready - c->tick)));
    }
}

static void write_counts(Ctx *c, int slot) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int allies = 0, enemies = 0, players = o->dim[MD_PLAYERS], count = o->dim[MD_ALLIES];
    double ally_hp = c->hp[slot], ally_max = c->max_hp[slot], enemy_hp = 0.0, enemy_max = 0.0;
    for (int index = 0; index < count; index++) {
        int other = c->allies[slot * count + index];
        if (other >= 0 && c->alive[other] != 0) {
            allies++;
            ally_hp += (double)c->hp[other];
            ally_max += (double)c->max_hp[other];
        }
    }
    for (int player = 0; player < players; player++) {
        int row = slot * players + player;
        if (c->seen_tick[row] >= 0 && c->party_present[player] != 0) {
            enemies++;
            enemy_hp += (double)o->seen_hp[row];
            enemy_max += (double)o->seen_max_hp[row];
        }
    }
    put(c, f[MF_ALLIES_NEARBY], allies);
    put(c, f[MF_ENEMIES_NEARBY], enemies);
    put(c, f[MF_ENEMY_TOTAL_HP], enemy_hp);
    put(c, f[MF_ENEMY_HP_FRACTION], enemy_max > 0.0 ? enemy_hp / enemy_max : 0.0);
    put(c, f[MF_ALLY_TOTAL_HP], ally_hp);
    put(c, f[MF_ALLY_HP_FRACTION], ally_hp / ally_max);
}

static void write_cover_slot(Ctx *c, int index, float dx, float dz, int blocks) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int shift = index * o->stride[MS_COVER];
    put(c, f[MF_COVER_PRESENT] + shift, 1.0);
    put(c, f[MF_COVER_DX] + shift, dx);
    put(c, f[MF_COVER_DY] + shift, dz);
    put(c, f[MF_COVER_DISTANCE] + shift, sqrtf(dx * dx + dz * dz));
    put(c, f[MF_COVER_BLOCKS] + shift, blocks);
}

/* Reports the two closest open spots, preferring those the mob's current target cannot see. */
static void write_cover(Ctx *c, int slot) {
    const MobObs *o = c->o;
    float origin_x = c->xz[slot * 2], origin_z = c->xz[slot * 2 + 1];
    float points_x[MAX_COVER_POINTS], points_z[MAX_COVER_POINTS];
    uint8_t blocked[MAX_COVER_POINTS];
    int count = 0;
    for (int r = 0; r < COVER_RADII; r++) {
        for (int step = 0; step < COVER_ANGLES; step++) {
            float angle = (float)((double)step * TAU_D / (double)COVER_ANGLES);
            float x = origin_x + cosf(angle) * cover_radius[r], z = origin_z + sinf(angle) * cover_radius[r];
            if ((double)mn_clearance(c->nav, x, z) >= (double)o->real[MR_COVER_CLEARANCE]) {
                points_x[count] = x;
                points_z[count] = z;
                blocked[count] = 0;
                count++;
            }
        }
    }
    if (count == 0) return;
    int player = c->enemy_target[slot] - 1;
    if (player >= 0 && c->seen_tick[slot * o->dim[MD_PLAYERS] + player] >= 0 && targetable(c, player)) {
        int row = slot * o->dim[MD_PLAYERS] + player;
        for (int i = 0; i < count; i++) {
            blocked[i] = (uint8_t)(mn_sight_clear(c->nav, c->seen_x[row], c->seen_z[row], points_x[i], points_z[i], 0.0f) == 0);
        }
    }
    int chosen = 0;
    for (int wanted = 1; wanted >= 0; wanted--) {
        for (int i = 0; i < count && chosen < o->dim[MD_COVER_SLOTS]; i++) {
            if (blocked[i] == wanted) {
                write_cover_slot(c, chosen, points_x[i] - origin_x, points_z[i] - origin_z, wanted);
                chosen++;
            }
        }
    }
}

static inline float trait(const MobObs *o, int kind, MoTrait which) { return o->traits[kind * MT_COUNT + which]; }

static inline double light_at(const Ctx *c, float x, float z) { return c->sense != NULL ? (double)ms_light_at(c->sense, x, z) : 1.0; }

/* Traits, mana, dodge, light and flight: the mechanics the simulation added for schema v2. */
static void write_mechanics(Ctx *c, int slot, int kind) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int flies = trait(o, kind, MT_FLY) != 0.0f;
    put(c, f[MF_FLY_SPEED], flies ? (double)c->speed[slot] : 0.0);
    put(c, f[MF_ARMOUR], c->armour[slot] != 0);
    put(c, f[MF_HEARING], trait(o, kind, MT_HEARING));
    put(c, f[MF_SMELL], trait(o, kind, MT_SMELL));
    put(c, f[MF_DARKVISION], trait(o, kind, MT_DARKVISION));
    put(c, f[MF_EVASION], trait(o, kind, MT_EVASION));
    put(c, f[MF_CAN_DODGE], trait(o, kind, MT_CAN_DODGE) != 0.0f);
    float pool = trait(o, kind, MT_MANA_POOL);
    put(c, f[MF_USES_MANA], pool > 0.0f);
    put(c, f[MF_GLOW], trait(o, kind, MT_GLOW));
    put(c, f[MF_RESOURCE], pool > 0.0f ? (double)c->mana[slot] / (double)pool : 1.0);
    if (trait(o, kind, MT_CAN_DODGE) != 0.0f) put(c, f[MF_DODGE_COOLDOWN], seconds(c, non_negative(c->dodge_ready[slot] - c->tick)));
    put(c, f[MF_CHANNELING], c->tick < c->channel_until[slot]);
    put(c, f[MF_DODGING], c->tick < c->dodge_until[slot]);
    put(c, f[MF_LIGHT], light_at(c, c->xz[slot * 2], c->xz[slot * 2 + 1]));
    put(c, f[MF_AIRBORNE], flies);
    put(c, f[MF_DOT], c->tick < c->dot_until[slot]);
}

/* The nearest ground areas that have not ended, closest edge first, ties by index, as MobFields.nearest. Distances
 * use single precision like Godot's Vector2, so the GDScript reference picks the same areas. */
static void write_hazards(Ctx *c, int slot, int kind) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int wanted = o->dim[MD_HAZARD_SLOTS];
    int chosen[8];
    double edge[8];
    int found = 0;
    if (wanted > 8) wanted = 8;
    float mx = c->xz[slot * 2], mz = c->xz[slot * 2 + 1];
    for (int index = 0; index < c->field_count; index++) {
        if (c->tick >= c->field_until[index]) continue;
        float dx = mx - c->field_x[index], dz = mz - c->field_z[index];
        double distance = (double)sqrtf(dx * dx + dz * dz) - (double)c->field_radius[index];
        int at = found < wanted ? found++ : wanted;
        if (at == wanted) {
            if (distance >= edge[wanted - 1]) continue;
            at = wanted - 1;
        }
        while (at > 0 && edge[at - 1] > distance) {
            edge[at] = edge[at - 1];
            chosen[at] = chosen[at - 1];
            at--;
        }
        edge[at] = distance;
        chosen[at] = index;
    }
    int flies = trait(o, kind, MT_FLY) != 0.0f;
    for (int i = 0; i < found; i++) {
        int index = chosen[i];
        int shift = i * o->stride[MS_HAZARD];
        float dx = c->field_x[index] - mx, dz = c->field_z[index] - mz;
        float radius = c->field_radius[index];
        int ground = (c->field_flags[index] & o->dim[MD_FIELD_GROUND]) != 0;
        put(c, f[MF_H_PRESENT] + shift, 1.0);
        put(c, f[MF_H_DX] + shift, dx);
        put(c, f[MF_H_DY] + shift, dz);
        put(c, f[MF_H_RADIUS] + shift, radius);
        put(c, f[MF_H_IMPACT] + shift, seconds(c, non_negative(c->field_activate[index] - c->tick)));
        put(c, f[MF_H_HOSTILE] + shift, c->field_owner[index] == o->dim[MD_OWNER_PLAYERS] && !(ground && flies));
        put(c, f[MF_H_INSIDE] + shift, (double)dx * dx + (double)dz * dz <= (double)radius * radius);
    }
}

/* Player combat stats, which a mob knows once it has sensed the player; wind-ups, dodges and effects (speed
 * change, guard, bark armour) only while in sight. The party's classes are counted for every mob, as a share of the
 * player slots. */
static void write_player_stats(Ctx *c, int slot) {
    const MobObs *o = c->o;
    const int *f = o->field;
    int players = o->dim[MD_PLAYERS];
    int classes = o->dim[MD_CLASSES];
    int counts[MO_MAX_CLASSES] = {0};
    for (int player = 0; player < players; player++) {
        int number = (int)c->party_stats[player * MP_COUNT + MP_CLASS];
        if (c->party_present[player] != 0 && number >= 1 && number <= classes) counts[number - 1]++;
    }
    for (int index = 0; index < classes; index++) {
        if (counts[index] > 0) put(c, f[MF_PARTY_CLASSES] + index, (double)counts[index] / players);
    }
    for (int player = 0; player < players; player++) {
        int row = slot * players + player;
        if (c->party_present[player] == 0 || c->seen_tick[row] < 0) continue;
        int shift = player * o->stride[MS_ENEMY];
        const float *stat = c->party_stats + player * MP_COUNT;
        const int *timer = c->party_timers + player * MPT_COUNT;
        int sees = c->visible[row] != 0 && targetable(c, player);
        put(c, f[MF_E_MELEE_DAMAGE] + shift, stat[MP_MELEE_DAMAGE]);
        put(c, f[MF_E_RANGED_DAMAGE] + shift, stat[MP_RANGED_DAMAGE]);
        put(c, f[MF_E_MELEE_RANGE] + shift, stat[MP_MELEE_RANGE]);
        put(c, f[MF_E_RANGED_RANGE] + shift, stat[MP_RANGED_RANGE]);
        put(c, f[MF_E_SPEED] + shift, stat[MP_SPEED]);
        put(c, f[MF_E_ATTACK_SPEED] + shift, stat[MP_ATTACK_SPEED]);
        put(c, f[MF_E_ARMOUR] + shift, stat[MP_ARMOUR]);
        put(c, f[MF_E_DODGE_COOLDOWN] + shift, seconds(c, non_negative(timer[MPT_DODGE_READY] - c->tick)));
        put(c, f[MF_E_WINDING] + shift, sees && c->tick < timer[MPT_WINDUP_UNTIL]);
        put(c, f[MF_E_DODGING] + shift, sees && c->tick < timer[MPT_DODGE_UNTIL]);
        put(c, f[MF_E_LIGHT] + shift, light_at(c, c->seen_x[row], c->seen_z[row]));
        if (sees) {
            put(c, f[MF_E_SPEED_CHANGE] + shift, stat[MP_SPEED_SCALE] - 1.0);
            put(c, f[MF_E_GUARDED] + shift, stat[MP_GUARD]);
            put(c, f[MF_E_BARK] + shift, stat[MP_BARK]);
        }
    }
}

MoResult mo_build(MobObs *o, const MobNav *nav, const MobSense *sense, const void *const *items, const int64_t *lengths, float *out) {
    if (o == NULL || nav == NULL || items == NULL || lengths == NULL) return MO_ERR_STATE;
    int capacity = o->dim[MD_CAPACITY], players = o->dim[MD_PLAYERS], attacks = o->dim[MD_ATTACKS], allies = o->dim[MD_ALLIES];
    int buckets = o->dim[MD_BUCKETS];
    int64_t cells = capacity, sensed = (int64_t)capacity * players;
    static const int per_slot[] = {
        MI_ALIVE, MI_GENERATION, MI_SPECIES, MI_FLAGS, MI_MUTATIONS, MI_LEADER, MI_LEADER_GENERATION, MI_HP, MI_MAX_HP, MI_SPEED, MI_DAMAGE,
        MI_REACH_BONUS, MI_INTELLIGENCE, MI_BEHAVIOUR, MI_ENEMY_TARGET, MI_ALLY_TARGET, MI_MESSAGE_A, MI_MESSAGE_B, MI_BEHAVIOUR_SINCE,
        MI_READY_AT, MI_STUN_UNTIL, MI_ROOT_UNTIL, MI_SLOW_UNTIL, MI_HASTE_UNTIL, MI_ENGAGED_AT,
        MI_MANA, MI_CHANNEL_UNTIL, MI_DODGE_UNTIL, MI_DODGE_READY, MI_DOT_UNTIL, MI_ARMOUR,
    };
    for (size_t i = 0; i < sizeof(per_slot) / sizeof(per_slot[0]); i++) {
        if (lengths[per_slot[i]] != cells) return MO_ERR_ARGUMENT;
    }
    static const int per_player[] = {MI_PARTY_PRESENT, MI_PARTY_ALIVE, MI_PARTY_HP, MI_PARTY_MAX_HP, MI_PARTY_VX, MI_PARTY_VZ};
    for (size_t i = 0; i < sizeof(per_player) / sizeof(per_player[0]); i++) {
        if (lengths[per_player[i]] != players) return MO_ERR_ARGUMENT;
    }
    if (lengths[MI_CLOCK] != 2 || lengths[MI_XZ] != cells * 2 || lengths[MI_COOLDOWN_UNTIL] != cells * attacks ||
        lengths[MI_VISIBLE] != sensed || lengths[MI_SEEN_X] != sensed || lengths[MI_SEEN_Z] != sensed || lengths[MI_SEEN_TICK] != sensed ||
        lengths[MI_ALLIES] != cells * allies || lengths[MI_TAKEN] != cells * buckets || lengths[MI_DEALT] != cells * buckets ||
        lengths[MI_TAKEN_FROM] != sensed * buckets || lengths[MI_DEALT_TO] != sensed * buckets || lengths[MI_ACTIVE] > cells ||
        lengths[MI_PARTY_STATS] != (int64_t)players * MP_COUNT || lengths[MI_PARTY_TIMERS] != (int64_t)players * MPT_COUNT) {
        return MO_ERR_ARGUMENT;
    }
    int64_t fields = lengths[MI_FIELD_X];
    if (lengths[MI_FIELD_Z] != fields || lengths[MI_FIELD_RADIUS] != fields || lengths[MI_FIELD_ACTIVATE] != fields ||
        lengths[MI_FIELD_UNTIL] != fields || lengths[MI_FIELD_OWNER] != fields || lengths[MI_FIELD_FLAGS] != fields) {
        return MO_ERR_ARGUMENT;
    }
    const int *slots = items[MI_SLOTS];
    int rows = (int)lengths[MI_SLOTS];
    for (int i = 0; i < rows; i++) {
        if (slots[i] < 0 || slots[i] >= capacity) return MO_ERR_ARGUMENT;
    }
    const int *clock = items[MI_CLOCK];
    Ctx c = {.o = o, .nav = nav, .sense = sense, .out = out, .tick = clock[0], .bucket = clock[1], .active = items[MI_ACTIVE], .active_count = (int)lengths[MI_ACTIVE],
             .alive = items[MI_ALIVE], .flags = items[MI_FLAGS], .behaviour = items[MI_BEHAVIOUR], .enemy_target = items[MI_ENEMY_TARGET],
             .ally_target = items[MI_ALLY_TARGET], .message_a = items[MI_MESSAGE_A], .message_b = items[MI_MESSAGE_B], .visible = items[MI_VISIBLE],
             .party_present = items[MI_PARTY_PRESENT], .party_alive = items[MI_PARTY_ALIVE], .generation = items[MI_GENERATION],
             .species = items[MI_SPECIES], .mutations = items[MI_MUTATIONS], .leader = items[MI_LEADER],
             .leader_generation = items[MI_LEADER_GENERATION], .behaviour_since = items[MI_BEHAVIOUR_SINCE], .ready_at = items[MI_READY_AT],
             .cooldown_until = items[MI_COOLDOWN_UNTIL], .stun_until = items[MI_STUN_UNTIL], .root_until = items[MI_ROOT_UNTIL],
             .slow_until = items[MI_SLOW_UNTIL], .haste_until = items[MI_HASTE_UNTIL], .seen_tick = items[MI_SEEN_TICK], .allies = items[MI_ALLIES],
             .engaged_at = items[MI_ENGAGED_AT], .xz = items[MI_XZ], .hp = items[MI_HP], .max_hp = items[MI_MAX_HP], .speed = items[MI_SPEED],
             .damage = items[MI_DAMAGE], .reach_bonus = items[MI_REACH_BONUS], .intelligence = items[MI_INTELLIGENCE], .seen_x = items[MI_SEEN_X],
             .seen_z = items[MI_SEEN_Z], .party_hp = items[MI_PARTY_HP], .party_max_hp = items[MI_PARTY_MAX_HP], .party_vx = items[MI_PARTY_VX],
             .party_vz = items[MI_PARTY_VZ], .taken = items[MI_TAKEN], .dealt = items[MI_DEALT], .taken_from = items[MI_TAKEN_FROM],
             .dealt_to = items[MI_DEALT_TO], .mana = items[MI_MANA], .channel_until = items[MI_CHANNEL_UNTIL],
             .dodge_until = items[MI_DODGE_UNTIL], .dodge_ready = items[MI_DODGE_READY], .dot_until = items[MI_DOT_UNTIL],
             .armour = items[MI_ARMOUR], .field_x = items[MI_FIELD_X], .field_z = items[MI_FIELD_Z], .field_radius = items[MI_FIELD_RADIUS],
             .field_activate = items[MI_FIELD_ACTIVATE], .field_until = items[MI_FIELD_UNTIL], .field_owner = items[MI_FIELD_OWNER],
             .field_flags = items[MI_FIELD_FLAGS], .party_stats = items[MI_PARTY_STATS], .party_timers = items[MI_PARTY_TIMERS],
             .field_count = (int)fields};
    memset(out, 0, (size_t)rows * (size_t)o->dim[MD_OBSERVATION] * sizeof(float));
    for (int i = 0; i < c.active_count; i++) {
        int target = c.enemy_target[c.active[i]];
        if (target <= players) c.targeting[target]++;
    }
    int rays = MN_WALL_RAYS;
    float walls[MN_WALL_RAYS];
    for (int row = 0; row < rows; row++) {
        int slot = slots[row];
        int kind = c.species[slot];
        c.base = row * o->dim[MD_OBSERVATION];
        c.vision = o->vision[kind];
        write_capabilities(&c, slot, kind);
        write_abilities(&c, slot, kind);
        write_enemies(&c, slot);
        write_dynamic(&c, slot, kind);
        write_status(&c, slot);
        write_intent(&c, slot, kind);
        write_mates(&c, slot);
        write_counts(&c, slot);
        write_mechanics(&c, slot, kind);
        write_hazards(&c, slot, kind);
        write_player_stats(&c, slot);
        float query = (float)slot;
        mn_wall_rays(nav, &query, 1, o->real[MR_WALL_RANGE], walls);
        for (int ray = 0; ray < rays; ray++) put(&c, o->field[MF_WALLS] + ray, walls[ray]);
        write_cover(&c, slot);
    }
    return MO_OK;
}
