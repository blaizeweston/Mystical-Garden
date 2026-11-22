#include "mob_decide.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

/* Scripted brain constants, from mob_scripted_brain_reference.gd. */
#define ASSIGNED_WEIGHT 1.4
#define ASSIGNED_LIMIT 3.0
#define UNSEEN_PENALTY 3.0
#define KEEP_TARGET_BONUS 1.1
#define LONG_RANGE 3.0
#define VAULT_ATTACK 2
#define HURT_DODGE_TICKS 12
#define SAFE_CHANNEL_DISTANCE 7.0

static const MdKind config_kinds[DC_COUNT] = {
    [DC_DIMS] = DK_INTS, [DC_HEAD_OFFSETS] = DK_INTS, [DC_AVAILABLE] = DK_BYTES, [DC_LEADER_ONLY] = DK_BYTES,
    [DC_TARGET_KIND] = DK_BYTES, [DC_ATTACK_SLOT] = DK_INTS, [DC_DELIVERY] = DK_BYTES,
    [DC_SUPPORT] = DK_BYTES, [DC_SKIRMISHER] = DK_BYTES, [DC_MAX_RANGE] = DK_FLOATS,
    [DC_ATTACK_EXISTS] = DK_BYTES, [DC_ATTACK_MUTATION] = DK_INTS, [DC_ATTACK_ESCORT] = DK_BYTES,
    [DC_ATTACK_DELIVERY] = DK_BYTES, [DC_ATTACK_RANGE] = DK_FLOATS, [DC_ATTACK_MIN_RANGE] = DK_FLOATS,
    [DC_MANA_POOL] = DK_FLOATS, [DC_MANA_LOW] = DK_FLOATS, [DC_CAN_DODGE] = DK_BYTES, [DC_ATTACK_MANA_COST] = DK_FLOATS,
};

static const MdKind input_kinds[DI_COUNT] = {
    [DI_TICK] = DK_INTS, [DI_SLOTS] = DK_INTS, [DI_ACTIVE] = DK_INTS, [DI_ALIVE] = DK_BYTES, [DI_GENERATION] = DK_INTS,
    [DI_SPECIES] = DK_INTS, [DI_MUTATIONS] = DK_INTS, [DI_FLAGS] = DK_BYTES, [DI_LEADER] = DK_INTS,
    [DI_LEADER_GENERATION] = DK_INTS, [DI_XZ] = DK_FLOATS, [DI_ENEMY_TARGET] = DK_BYTES, [DI_READY_AT] = DK_INTS,
    [DI_COOLDOWN_UNTIL] = DK_INTS, [DI_WINDUP_UNTIL] = DK_INTS, [DI_VISIBLE] = DK_BYTES, [DI_SEEN_X] = DK_FLOATS,
    [DI_SEEN_Z] = DK_FLOATS, [DI_SEEN_TICK] = DK_INTS, [DI_ALLIES] = DK_INTS, [DI_PARTY_PRESENT] = DK_BYTES,
    [DI_PARTY_ALIVE] = DK_BYTES, [DI_PARTY_X] = DK_FLOATS, [DI_PARTY_Z] = DK_FLOATS, [DI_MASKS] = DK_BYTES,
    [DI_COMMAND_PLAYER] = DK_BYTES, [DI_COMMAND_UNTIL] = DK_INTS, [DI_MANA] = DK_FLOATS, [DI_DODGE_READY] = DK_INTS,
    [DI_ROOT_UNTIL] = DK_INTS, [DI_STUN_UNTIL] = DK_INTS, [DI_HURT_AT] = DK_INTS,
};

MdKind md_config_kind(int index) { return config_kinds[index]; }
MdKind md_input_kind(int index) { return input_kinds[index]; }

struct MobDecide {
    int dim[DD_COUNT];
    int head_offset[DK_HEAD_COUNT];
    uint8_t *available, *leader_only, *target_kind, *delivery;
    int *attack_slot;
    uint8_t *support, *skirmisher, *attack_exists, *attack_escort, *attack_delivery, *can_dodge;
    int *attack_mutation;
    float *max_range, *attack_range, *attack_min_range, *mana_pool, *mana_low, *attack_mana_cost;
    int *assigned;
};

typedef struct {
    const MobDecide *d;
    int tick;
    const int *slots, *active, *generation, *species, *mutations, *leader, *leader_generation;
    const int *ready_at, *cooldown_until, *windup_until, *seen_tick, *allies;
    const uint8_t *alive, *flags, *enemy_target, *visible, *party_present, *party_alive, *masks, *command_player;
    const int *command_until, *dodge_ready, *root_until, *stun_until, *hurt_at;
    const float *xz, *seen_x, *seen_z, *party_x, *party_z, *mana;
    int64_t slot_count, active_count;
} View;

static void *copy_table(const void *source, int64_t length, size_t size) {
    void *table = malloc((size_t)(length > 0 ? length : 1) * size);
    if (table != NULL && length > 0) memcpy(table, source, (size_t)length * size);
    return table;
}

void md_destroy(MobDecide *d) {
    if (d == NULL) return;
    free(d->available); free(d->leader_only); free(d->target_kind); free(d->delivery); free(d->attack_slot);
    free(d->support); free(d->skirmisher); free(d->attack_exists); free(d->attack_escort); free(d->attack_delivery);
    free(d->attack_mutation); free(d->max_range); free(d->attack_range); free(d->attack_min_range); free(d->assigned);
    free(d->mana_pool); free(d->mana_low); free(d->can_dodge); free(d->attack_mana_cost);
    free(d);
}

MdResult md_create(const void *const *items, const int64_t *lengths, MobDecide **out) {
    *out = NULL;
    if (lengths[DC_DIMS] != DD_COUNT || lengths[DC_HEAD_OFFSETS] != DK_HEAD_COUNT) return DK_ERR_ARGUMENT;
    MobDecide *d = calloc(1, sizeof(MobDecide));
    if (d == NULL) return DK_ERR_MEMORY;
    memcpy(d->dim, items[DC_DIMS], sizeof(d->dim));
    memcpy(d->head_offset, items[DC_HEAD_OFFSETS], sizeof(d->head_offset));
    int behaviours = d->dim[DD_BEHAVIOURS], species = d->dim[DD_SPECIES], attacks = d->dim[DD_ATTACKS];
    int64_t pairs = (int64_t)species * attacks;
    if (behaviours < 1 || species < 1 || attacks <= VAULT_ATTACK || d->dim[DD_CAPACITY] < 1 || d->dim[DD_PLAYERS] < 1
            || d->dim[DD_MASK_SIZE] < 1 || lengths[DC_AVAILABLE] != behaviours || lengths[DC_LEADER_ONLY] != behaviours
            || lengths[DC_TARGET_KIND] != behaviours || lengths[DC_ATTACK_SLOT] != behaviours || lengths[DC_DELIVERY] != behaviours
            || lengths[DC_SUPPORT] != species || lengths[DC_SKIRMISHER] != species || lengths[DC_MAX_RANGE] != species
            || lengths[DC_ATTACK_EXISTS] != pairs || lengths[DC_ATTACK_MUTATION] != pairs || lengths[DC_ATTACK_ESCORT] != pairs
            || lengths[DC_ATTACK_DELIVERY] != pairs || lengths[DC_ATTACK_RANGE] != pairs || lengths[DC_ATTACK_MIN_RANGE] != pairs
            || lengths[DC_MANA_POOL] != species || lengths[DC_MANA_LOW] != species || lengths[DC_CAN_DODGE] != species
            || lengths[DC_ATTACK_MANA_COST] != pairs) {
        free(d);
        return DK_ERR_ARGUMENT;
    }
    d->available = copy_table(items[DC_AVAILABLE], behaviours, 1);
    d->leader_only = copy_table(items[DC_LEADER_ONLY], behaviours, 1);
    d->target_kind = copy_table(items[DC_TARGET_KIND], behaviours, 1);
    d->attack_slot = copy_table(items[DC_ATTACK_SLOT], behaviours, sizeof(int));
    d->delivery = copy_table(items[DC_DELIVERY], behaviours, 1);
    d->support = copy_table(items[DC_SUPPORT], species, 1);
    d->skirmisher = copy_table(items[DC_SKIRMISHER], species, 1);
    d->max_range = copy_table(items[DC_MAX_RANGE], species, sizeof(float));
    d->attack_exists = copy_table(items[DC_ATTACK_EXISTS], pairs, 1);
    d->attack_mutation = copy_table(items[DC_ATTACK_MUTATION], pairs, sizeof(int));
    d->attack_escort = copy_table(items[DC_ATTACK_ESCORT], pairs, 1);
    d->attack_delivery = copy_table(items[DC_ATTACK_DELIVERY], pairs, 1);
    d->attack_range = copy_table(items[DC_ATTACK_RANGE], pairs, sizeof(float));
    d->attack_min_range = copy_table(items[DC_ATTACK_MIN_RANGE], pairs, sizeof(float));
    d->mana_pool = copy_table(items[DC_MANA_POOL], species, sizeof(float));
    d->mana_low = copy_table(items[DC_MANA_LOW], species, sizeof(float));
    d->can_dodge = copy_table(items[DC_CAN_DODGE], species, 1);
    d->attack_mana_cost = copy_table(items[DC_ATTACK_MANA_COST], pairs, sizeof(float));
    d->assigned = calloc((size_t)d->dim[DD_PLAYERS] + 1, sizeof(int));
    if (!d->available || !d->leader_only || !d->target_kind || !d->attack_slot || !d->delivery || !d->support || !d->skirmisher
            || !d->max_range || !d->attack_exists || !d->attack_mutation || !d->attack_escort || !d->attack_delivery
            || !d->attack_range || !d->attack_min_range || !d->assigned || !d->mana_pool || !d->mana_low || !d->can_dodge
            || !d->attack_mana_cost) {
        md_destroy(d);
        return DK_ERR_MEMORY;
    }
    for (int i = 0; i < behaviours; i++) {
        if (d->attack_slot[i] >= attacks) {
            md_destroy(d);
            return DK_ERR_ARGUMENT;
        }
    }
    *out = d;
    return DK_OK;
}

int md_mask_size(const MobDecide *d) { return d->dim[DD_MASK_SIZE]; }

#define BIND(field, index, type) v->field = (const type *)items[index]

static int bind(View *v, const MobDecide *d, const void *const *items, const int64_t *lengths) {
    int capacity = d->dim[DD_CAPACITY], players = d->dim[DD_PLAYERS];
    if (lengths[DI_TICK] != 1 || lengths[DI_ALIVE] != capacity || lengths[DI_XZ] != (int64_t)capacity * 2
            || lengths[DI_COOLDOWN_UNTIL] != (int64_t)capacity * d->dim[DD_ATTACKS] || lengths[DI_SEEN_TICK] != (int64_t)capacity * players
            || lengths[DI_ALLIES] != (int64_t)capacity * d->dim[DD_ALLIES] || lengths[DI_PARTY_X] != players
            || lengths[DI_COMMAND_PLAYER] != capacity || lengths[DI_COMMAND_UNTIL] != capacity || lengths[DI_MANA] != capacity
            || lengths[DI_DODGE_READY] != capacity || lengths[DI_ROOT_UNTIL] != capacity || lengths[DI_STUN_UNTIL] != capacity
            || lengths[DI_HURT_AT] != capacity) {
        return 0;
    }
    memset(v, 0, sizeof(*v));
    v->d = d;
    v->tick = ((const int *)items[DI_TICK])[0];
    v->slot_count = lengths[DI_SLOTS];
    v->active_count = lengths[DI_ACTIVE];
    BIND(slots, DI_SLOTS, int); BIND(active, DI_ACTIVE, int); BIND(alive, DI_ALIVE, uint8_t); BIND(generation, DI_GENERATION, int);
    BIND(species, DI_SPECIES, int); BIND(mutations, DI_MUTATIONS, int); BIND(flags, DI_FLAGS, uint8_t); BIND(leader, DI_LEADER, int);
    BIND(leader_generation, DI_LEADER_GENERATION, int); BIND(xz, DI_XZ, float); BIND(enemy_target, DI_ENEMY_TARGET, uint8_t);
    BIND(ready_at, DI_READY_AT, int); BIND(cooldown_until, DI_COOLDOWN_UNTIL, int); BIND(windup_until, DI_WINDUP_UNTIL, int);
    BIND(visible, DI_VISIBLE, uint8_t); BIND(seen_x, DI_SEEN_X, float); BIND(seen_z, DI_SEEN_Z, float);
    BIND(seen_tick, DI_SEEN_TICK, int); BIND(allies, DI_ALLIES, int); BIND(party_present, DI_PARTY_PRESENT, uint8_t);
    BIND(party_alive, DI_PARTY_ALIVE, uint8_t); BIND(party_x, DI_PARTY_X, float); BIND(party_z, DI_PARTY_Z, float);
    BIND(masks, DI_MASKS, uint8_t); BIND(command_player, DI_COMMAND_PLAYER, uint8_t); BIND(command_until, DI_COMMAND_UNTIL, int);
    BIND(mana, DI_MANA, float); BIND(dodge_ready, DI_DODGE_READY, int); BIND(root_until, DI_ROOT_UNTIL, int);
    BIND(stun_until, DI_STUN_UNTIL, int); BIND(hurt_at, DI_HURT_AT, int);
    for (int64_t i = 0; i < v->slot_count; i++) {
        if (v->slots[i] < 0 || v->slots[i] >= capacity) return 0;
    }
    for (int64_t i = 0; i < v->active_count; i++) {
        if (v->active[i] < 0 || v->active[i] >= capacity) return 0;
    }
    return 1;
}

static inline int targetable(const View *v, int player) { return v->party_present[player] != 0 && v->party_alive[player] != 0; }
static inline int knows(const View *v, int slot, int player) {
    return v->seen_tick[slot * v->d->dim[DD_PLAYERS] + player] >= 0 && targetable(v, player);
}
static inline int sees(const View *v, int slot, int player) {
    return v->visible[slot * v->d->dim[DD_PLAYERS] + player] != 0 && targetable(v, player);
}
static inline int ally_of(const View *v, int slot, int index) { return v->allies[slot * v->d->dim[DD_ALLIES] + index]; }
static inline int leader_of(const View *v, int slot) {
    int chosen = v->leader[slot];
    return chosen >= 0 && v->alive[chosen] != 0 && v->generation[chosen] == v->leader_generation[slot] ? chosen : -1;
}
static inline double distance_to(const View *v, int slot, double x, double z) {
    double dx = (double)v->xz[slot * 2] - x, dz = (double)v->xz[slot * 2 + 1] - z;
    return sqrt(dx * dx + dz * dz);
}

/* ---- Masks, matching MobRules ---- */

static int has_fighter_ally(const View *v, int slot) {
    const MobDecide *d = v->d;
    int leader = leader_of(v, slot);
    if (leader >= 0 && d->support[v->species[leader]] == 0) return 1;
    for (int index = 0; index < d->dim[DD_ALLIES]; index++) {
        int other = ally_of(v, slot, index);
        if (other >= 0 && v->alive[other] != 0 && d->support[v->species[other]] == 0) return 1;
    }
    return 0;
}

static int attack_ready(const View *v, int slot, int attack) {
    const MobDecide *d = v->d;
    int at = v->species[slot] * d->dim[DD_ATTACKS] + attack;
    if (d->attack_exists[at] == 0 || (d->attack_mutation[at] != 0 && (v->mutations[slot] & d->attack_mutation[at]) == 0)) return 0;
    if (v->mana[slot] < d->attack_mana_cost[at]) return 0;
    if (v->tick < v->ready_at[slot] || v->tick < v->cooldown_until[slot * d->dim[DD_ATTACKS] + attack] || v->windup_until[slot] > 0) return 0;
    /* Escort rule: 0 any time, 1 only without a fighting ally, 2 only with one. */
    int escort = d->attack_escort[at];
    return escort == 0 || (escort == 1 ? !has_fighter_ally(v, slot) : has_fighter_ally(v, slot));
}

static int behaviour_legal(const View *v, int slot, int behaviour, int has_enemy, int has_ally) {
    const MobDecide *d = v->d;
    if (d->available[behaviour] == 0) return 0;
    if (d->leader_only[behaviour] != 0 && (v->flags[slot] & d->dim[DD_LEADER_FLAGS]) == 0) return 0;
    int kind = d->target_kind[behaviour];
    if ((kind == DK_TARGET_ENEMY || kind == DK_TARGET_ABILITY) && !has_enemy) return 0;
    if (kind == DK_TARGET_ALLY && !has_ally) return 0;
    if (behaviour == d->dim[DD_DODGE]) {
        return d->can_dodge[v->species[slot]] != 0 && v->tick >= v->dodge_ready[slot] && v->windup_until[slot] <= 0
            && v->tick >= v->stun_until[slot] && v->tick >= v->root_until[slot];
    }
    if (behaviour == d->dim[DD_CHANNEL]) {
        float full = d->mana_pool[v->species[slot]];
        return full > 0.0f && v->mana[slot] < full && v->windup_until[slot] <= 0;
    }
    int attack = d->attack_slot[behaviour];
    if (attack < 0) return 1;
    int wanted = d->delivery[behaviour];
    if (wanted != DK_DELIVERY_ANY && d->attack_delivery[v->species[slot] * d->dim[DD_ATTACKS] + attack] != wanted) return 0;
    return attack_ready(v, slot, attack);
}

static void mask_slot(const View *v, uint8_t *row, int slot) {
    const MobDecide *d = v->d;
    uint8_t *enemy = row + d->head_offset[DK_HEAD_ENEMY];
    uint8_t *ally = row + d->head_offset[DK_HEAD_ALLY];
    enemy[0] = 1;
    ally[0] = 1;
    int has_enemy = 0, has_ally = 0;
    /* A shepherd's order limits the target to the commanded player while it lasts and that player is known. */
    int commanded = v->tick < v->command_until[slot] && v->command_player[slot] < d->dim[DD_PLAYERS]
        && knows(v, slot, v->command_player[slot]) ? v->command_player[slot] : -1;
    for (int player = 0; player < d->dim[DD_PLAYERS]; player++) {
        if (knows(v, slot, player) && (commanded < 0 || player == commanded)) {
            enemy[1 + player] = 1;
            has_enemy = 1;
        }
    }
    for (int index = 0; index < d->dim[DD_ALLIES]; index++) {
        if (ally_of(v, slot, index) >= 0) {
            ally[1 + index] = 1;
            has_ally = 1;
        }
    }
    if (leader_of(v, slot) >= 0) {
        ally[1 + d->dim[DD_ALLIES]] = 1;
        has_ally = 1;
    }
    memset(row + d->head_offset[DK_HEAD_MANOEUVRE], 1, (size_t)d->dim[DD_MANOEUVRES]);
    for (int head = DK_HEAD_MESSAGE_A; head <= DK_HEAD_MESSAGE_B; head++) {
        uint8_t *message = row + d->head_offset[head];
        message[0] = 1;
        if (d->dim[DD_MESSAGES_ENABLED] != 0 && d->dim[DD_SYMBOLS] > 1) memset(message + 1, 1, (size_t)d->dim[DD_SYMBOLS] - 1);
    }
    uint8_t *behaviours = row + d->head_offset[DK_HEAD_BEHAVIOUR];
    for (int behaviour = 0; behaviour < d->dim[DD_BEHAVIOURS]; behaviour++) {
        behaviours[behaviour] = (uint8_t)behaviour_legal(v, slot, behaviour, has_enemy, has_ally);
    }
}

MdResult md_masks(const MobDecide *d, const void *const *items, const int64_t *lengths, uint8_t *out) {
    View v;
    if (!bind(&v, d, items, lengths)) return DK_ERR_ARGUMENT;
    int size = d->dim[DD_MASK_SIZE];
    memset(out, 0, (size_t)(v.slot_count * size));
    for (int64_t i = 0; i < v.slot_count; i++) mask_slot(&v, out + i * size, v.slots[i]);
    return DK_OK;
}

/* ---- Scripted brain, matching mob_scripted_brain_reference.gd ---- */

static inline int allowed(const View *v, int64_t index, int option) {
    return option >= 0 && v->masks[index * v->d->dim[DD_MASK_SIZE] + v->d->head_offset[DK_HEAD_BEHAVIOUR] + option] != 0;
}

static void write_intent(uint8_t *out, int64_t index, int behaviour, int enemy, int ally, int manoeuvre) {
    uint8_t *row = out + index * DK_HEAD_COUNT;
    row[DK_HEAD_BEHAVIOUR] = (uint8_t)behaviour;
    row[DK_HEAD_ENEMY] = (uint8_t)enemy;
    row[DK_HEAD_ALLY] = (uint8_t)ally;
    row[DK_HEAD_MANOEUVRE] = (uint8_t)manoeuvre;
    row[DK_HEAD_MESSAGE_A] = 0;
    row[DK_HEAD_MESSAGE_B] = 0;
}

static inline int enemy_allowed(const View *v, int64_t index, int player) {
    return v->masks[index * v->d->dim[DD_MASK_SIZE] + v->d->head_offset[DK_HEAD_ENEMY] + 1 + player] != 0;
}

static int pick_target(const View *v, int64_t index, int slot) {
    const MobDecide *d = v->d;
    double best = INFINITY;
    int chosen = -1;
    int current = (int)v->enemy_target[slot] - 1;
    for (int player = 0; player < d->dim[DD_PLAYERS]; player++) {
        if (!knows(v, slot, player) || !enemy_allowed(v, index, player)) continue;
        int at = slot * d->dim[DD_PLAYERS] + player;
        int assigned = d->assigned[player + 1] - (player == current ? 1 : 0);
        double score = distance_to(v, slot, v->seen_x[at], v->seen_z[at]) + fmin(ASSIGNED_LIMIT, (double)assigned * ASSIGNED_WEIGHT);
        if (!sees(v, slot, player)) score += UNSEEN_PENALTY;
        if (player == current) score -= KEEP_TARGET_BONUS;
        if (score < best) {
            best = score;
            chosen = player;
        }
    }
    return chosen;
}

static int choose_manoeuvre(const View *v, int slot, int kind) {
    const MobDecide *d = v->d;
    if (d->skirmisher[kind] != 0) return slot % 2 == 0 ? d->dim[DD_CIRCLE_LEFT] : d->dim[DD_CIRCLE_RIGHT];
    if ((double)d->max_range[kind] > LONG_RANGE) return d->dim[DD_KEEP_RANGE];
    int options[3] = {0, d->dim[DD_CIRCLE_LEFT], d->dim[DD_CIRCLE_RIGHT]};
    return options[slot % 3];
}

static int first_ally(const View *v, int slot) {
    for (int index = 0; index < v->d->dim[DD_ALLIES]; index++) {
        if (ally_of(v, slot, index) >= 0) return index + 1;
    }
    return 0;
}

static double nearest_seen(const View *v, int slot) {
    double nearest = INFINITY;
    for (int player = 0; player < v->d->dim[DD_PLAYERS]; player++) {
        if (sees(v, slot, player)) nearest = fmin(nearest, distance_to(v, slot, v->party_x[player], v->party_z[player]));
    }
    return nearest;
}

static void decide_slot(const View *v, uint8_t *out, int64_t index, int slot) {
    const MobDecide *d = v->d;
    if (allowed(v, index, d->dim[DD_DODGE]) && v->tick - v->hurt_at[slot] <= HURT_DODGE_TICKS) {
        write_intent(out, index, d->dim[DD_DODGE], 0, 0, 0);
        return;
    }
    int player = pick_target(v, index, slot);
    if (player < 0) {
        write_intent(out, index, allowed(v, index, d->dim[DD_CHANNEL]) ? d->dim[DD_CHANNEL] : d->dim[DD_IDLE], 0, 0, 0);
        return;
    }
    int head = player + 1;
    int kind = v->species[slot];
    if (v->mana[slot] < d->mana_low[kind] && allowed(v, index, d->dim[DD_CHANNEL])) {
        if (nearest_seen(v, slot) > SAFE_CHANNEL_DISTANCE) {
            write_intent(out, index, d->dim[DD_CHANNEL], 0, 0, 0);
            return;
        }
        if (allowed(v, index, d->dim[DD_FLEE])) {
            write_intent(out, index, d->dim[DD_FLEE], head, 0, 0);
            return;
        }
    }
    if (!sees(v, slot, player)) {
        write_intent(out, index, d->dim[DD_SEARCH], head, 0, 0);
        return;
    }
    int manoeuvre = choose_manoeuvre(v, slot, kind);
    double distance = distance_to(v, slot, v->party_x[player], v->party_z[player]);
    int vault_at = kind * d->dim[DD_ATTACKS] + VAULT_ATTACK;
    if (allowed(v, index, d->dim[DD_ABILITY_2]) && distance >= (double)d->attack_min_range[vault_at]
            && distance <= (double)d->attack_range[vault_at]) {
        write_intent(out, index, d->dim[DD_ABILITY_2], head, 0, manoeuvre);
        return;
    }
    int order[4] = {d->dim[DD_ABILITY_1], d->dim[DD_MELEE], d->dim[DD_RANGED], d->dim[DD_ABILITY_3]};
    for (int i = 0; i < 4; i++) {
        if (allowed(v, index, order[i])) {
            write_intent(out, index, order[i], head, 0, manoeuvre);
            return;
        }
    }
    int ally = first_ally(v, slot);
    if (d->support[kind] != 0 && ally > 0 && allowed(v, index, d->dim[DD_DEFEND])) {
        write_intent(out, index, d->dim[DD_DEFEND], head, ally, 0);
        return;
    }
    write_intent(out, index, d->dim[DD_APPROACH], head, 0, manoeuvre);
}

MdResult md_scripted(MobDecide *d, const void *const *items, const int64_t *lengths, uint8_t *out) {
    View v;
    if (!bind(&v, d, items, lengths) || lengths[DI_MASKS] != v.slot_count * d->dim[DD_MASK_SIZE]
            || lengths[DI_ENEMY_TARGET] != d->dim[DD_CAPACITY]) {
        return DK_ERR_ARGUMENT;
    }
    memset(d->assigned, 0, ((size_t)d->dim[DD_PLAYERS] + 1) * sizeof(int));
    for (int64_t i = 0; i < v.active_count; i++) {
        int target = v.enemy_target[v.active[i]];
        if (target <= d->dim[DD_PLAYERS]) d->assigned[target] += 1;
    }
    for (int64_t i = 0; i < v.slot_count; i++) decide_slot(&v, out, i, v.slots[i]);
    return DK_OK;
}
