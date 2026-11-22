#include "mob_exec.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

/* Constants from mob_executors_reference.gd. GDScript float is double; Vector2 is float. */
#define GOLDEN_ANGLE 2.39996
#define RING_MIN 0.7
#define RING_SHARE 0.85
#define MAX_RANGE_SHARE 0.98
#define CIRCLE_ANGLE 0.9
#define SEEK_STOP 0.2
#define WANDER_TICKS 180
#define WANDER_RADIUS 3.5
#define WANDER_LEASH 8.0
#define WANDER_STOP 0.3
#define SEARCH_ARRIVAL 1.0
#define SEARCH_RING 3.0
#define SEARCH_TICKS 120
#define COVER_REFRESH_TICKS 30
#define COVER_ANGLES 12
#define COVER_RADII 2
#define COVER_CLEARANCE 0.6
#define COVER_STOP 0.3
#define DEFEND_DISTANCE 1.6
#define BLOCK_DISTANCE 1.5
#define STILL_SPEED 0.1
#define CLEAR_BODY 0.46f
#define GOAL_CELL 2.0
#define TAU_D 6.283185307179586
#define PI_D 3.141592653589793

static const double cover_radius[COVER_RADII] = {3.0, 6.0};

static const MeKind config_kinds[EC_COUNT] = {
    [EC_DIMS] = ME_INTS, [EC_EXECUTOR] = ME_BYTES, [EC_ATTACK_SLOT] = ME_INTS,
    [EC_PREFERRED_RANGE] = ME_FLOATS, [EC_MAX_RANGE] = ME_FLOATS, [EC_SUPPORT] = ME_BYTES,
    [EC_ATTACK_EXISTS] = ME_BYTES, [EC_ATTACK_MUTATION] = ME_INTS, [EC_ATTACK_RANGE] = ME_FLOATS,
    [EC_ATTACK_MIN_RANGE] = ME_FLOATS, [EC_ATTACK_SIGHT] = ME_BYTES, [EC_ATTACK_LONELY] = ME_BYTES,
};

static const MeKind input_kinds[EI_COUNT] = {
    [EI_CLOCK] = ME_INTS, [EI_ACTIVE] = ME_INTS, [EI_ALIVE] = ME_BYTES, [EI_GENERATION] = ME_INTS, [EI_SPECIES] = ME_INTS,
    [EI_MUTATIONS] = ME_INTS, [EI_LEADER] = ME_INTS, [EI_LEADER_GENERATION] = ME_INTS,
    [EI_XZ] = ME_FLOATS, [EI_SPAWN_X] = ME_FLOATS, [EI_SPAWN_Z] = ME_FLOATS, [EI_REACH_BONUS] = ME_FLOATS,
    [EI_BEHAVIOUR] = ME_BYTES, [EI_BEHAVIOUR_SINCE] = ME_INTS, [EI_ENEMY_TARGET] = ME_BYTES, [EI_ALLY_TARGET] = ME_BYTES,
    [EI_MANOEUVRE] = ME_BYTES, [EI_WINDUP_UNTIL] = ME_INTS, [EI_STUN_UNTIL] = ME_INTS, [EI_READY_AT] = ME_INTS,
    [EI_COOLDOWN_UNTIL] = ME_INTS, [EI_VISIBLE] = ME_BYTES, [EI_SEEN_X] = ME_FLOATS, [EI_SEEN_Z] = ME_FLOATS,
    [EI_SEEN_TICK] = ME_INTS, [EI_ALLIES] = ME_INTS, [EI_PARTY_PRESENT] = ME_BYTES, [EI_PARTY_ALIVE] = ME_BYTES,
    [EI_PARTY_X] = ME_FLOATS, [EI_PARTY_Z] = ME_FLOATS, [EI_PARTY_VX] = ME_FLOATS, [EI_PARTY_VZ] = ME_FLOATS,
    [EI_COMMANDS] = ME_FLOATS, [EI_TARGETS] = ME_FLOATS,
};

MeKind me_config_kind(int index) { return config_kinds[index]; }
MeKind me_input_kind(int index) { return input_kinds[index]; }

static const MeKind speed_kinds[EV_COUNT] = {
    [EV_TICK] = ME_INTS, [EV_ACTIVE] = ME_INTS, [EV_SPEED] = ME_FLOATS, [EV_WINDUP_UNTIL] = ME_INTS, [EV_STUN_UNTIL] = ME_INTS,
    [EV_ROOT_UNTIL] = ME_INTS, [EV_SLOW_UNTIL] = ME_INTS, [EV_SLOW_SCALE] = ME_FLOATS, [EV_HASTE_UNTIL] = ME_INTS, [EV_COMMANDS] = ME_FLOATS,
};

MeKind me_speed_input_kind(int index) { return speed_kinds[index]; }

struct MobExec {
    int dim[ED_COUNT];
    uint8_t *executor, *support, *attack_exists, *attack_sight, *attack_lonely;
    int *attack_slot, *attack_mutation;
    float *preferred_range, *max_range, *attack_range, *attack_min_range;
    int64_t *goal_key;
    int *goal_used;
    float *cover_x, *cover_z;
    uint8_t *cover_found;
    float *cover_queries;
    float cover_points[COVER_ANGLES * COVER_RADII * 2];
    uint8_t cover_clear[COVER_ANGLES * COVER_RADII];
};

/* The live view for one run. Pointers alias the caller's arrays, which are only read. */
typedef struct {
    MobExec *e;
    const MobNav *nav;
    int tick, goal_tick;
    const int *generation, *species, *mutations, *leader, *leader_generation, *behaviour_since;
    const int *windup_until, *stun_until, *ready_at, *cooldown_until, *seen_tick, *allies;
    const uint8_t *alive, *behaviour, *enemy_target, *ally_target, *manoeuvre, *visible, *party_present, *party_alive;
    const float *xz, *spawn_x, *spawn_z, *reach_bonus, *seen_x, *seen_z, *party_x, *party_z, *party_vx, *party_vz;
    float *commands, *targets, *requests;
    int request_count;
} Run;

static void *copy_table(const void *source, int64_t length, size_t size) {
    void *table = malloc((size_t)(length > 0 ? length : 1) * size);
    if (table != NULL && length > 0) memcpy(table, source, (size_t)length * size);
    return table;
}

void me_destroy(MobExec *e) {
    if (e == NULL) return;
    free(e->executor); free(e->support); free(e->attack_exists); free(e->attack_sight); free(e->attack_lonely);
    free(e->attack_slot); free(e->attack_mutation); free(e->preferred_range); free(e->max_range);
    free(e->attack_range); free(e->attack_min_range); free(e->goal_key); free(e->goal_used);
    free(e->cover_x); free(e->cover_z); free(e->cover_found); free(e->cover_queries);
    free(e);
}

MeResult me_create(const void *const *items, const int64_t *lengths, MobExec **out) {
    *out = NULL;
    if (lengths[EC_DIMS] != ED_COUNT) return ME_ERR_ARGUMENT;
    MobExec *e = calloc(1, sizeof(MobExec));
    if (e == NULL) return ME_ERR_MEMORY;
    memcpy(e->dim, items[EC_DIMS], sizeof(e->dim));
    int capacity = e->dim[ED_CAPACITY], species = e->dim[ED_SPECIES], attacks = e->dim[ED_ATTACKS];
    int behaviours = e->dim[ED_BEHAVIOURS], goals = e->dim[ED_GOAL_FIELDS];
    if (capacity < 1 || species < 1 || attacks < 1 || behaviours < 1 || goals < 1 || e->dim[ED_PLAYERS] < 1
            || e->dim[ED_GOAL_REFRESH] < 1 || lengths[EC_EXECUTOR] != behaviours || lengths[EC_ATTACK_SLOT] != behaviours
            || lengths[EC_PREFERRED_RANGE] != species || lengths[EC_MAX_RANGE] != species || lengths[EC_SUPPORT] != species
            || lengths[EC_ATTACK_EXISTS] != species * attacks || lengths[EC_ATTACK_MUTATION] != species * attacks
            || lengths[EC_ATTACK_RANGE] != species * attacks || lengths[EC_ATTACK_MIN_RANGE] != species * attacks
            || lengths[EC_ATTACK_SIGHT] != species * attacks || lengths[EC_ATTACK_LONELY] != species * attacks) {
        free(e);
        return ME_ERR_ARGUMENT;
    }
    e->executor = copy_table(items[EC_EXECUTOR], behaviours, 1);
    e->attack_slot = copy_table(items[EC_ATTACK_SLOT], behaviours, sizeof(int));
    e->preferred_range = copy_table(items[EC_PREFERRED_RANGE], species, sizeof(float));
    e->max_range = copy_table(items[EC_MAX_RANGE], species, sizeof(float));
    e->support = copy_table(items[EC_SUPPORT], species, 1);
    e->attack_exists = copy_table(items[EC_ATTACK_EXISTS], species * attacks, 1);
    e->attack_mutation = copy_table(items[EC_ATTACK_MUTATION], species * attacks, sizeof(int));
    e->attack_range = copy_table(items[EC_ATTACK_RANGE], species * attacks, sizeof(float));
    e->attack_min_range = copy_table(items[EC_ATTACK_MIN_RANGE], species * attacks, sizeof(float));
    e->attack_sight = copy_table(items[EC_ATTACK_SIGHT], species * attacks, 1);
    e->attack_lonely = copy_table(items[EC_ATTACK_LONELY], species * attacks, 1);
    e->goal_key = malloc((size_t)goals * sizeof(int64_t));
    e->goal_used = malloc((size_t)goals * sizeof(int));
    e->cover_x = calloc((size_t)capacity, sizeof(float));
    e->cover_z = calloc((size_t)capacity, sizeof(float));
    e->cover_found = calloc((size_t)capacity, 1);
    e->cover_queries = malloc((size_t)COVER_ANGLES * COVER_RADII * 5 * sizeof(float));
    if (!e->executor || !e->attack_slot || !e->preferred_range || !e->max_range || !e->support || !e->attack_exists
            || !e->attack_mutation || !e->attack_range || !e->attack_min_range || !e->attack_sight || !e->attack_lonely
            || !e->goal_key || !e->goal_used || !e->cover_x || !e->cover_z || !e->cover_found || !e->cover_queries) {
        me_destroy(e);
        return ME_ERR_MEMORY;
    }
    for (int i = 0; i < behaviours; i++) {
        if (e->executor[i] >= MX_KIND_COUNT || e->attack_slot[i] >= attacks) {
            me_destroy(e);
            return ME_ERR_ARGUMENT;
        }
    }
    for (int i = 0; i < goals; i++) {
        e->goal_key[i] = -1;
        e->goal_used[i] = -1;
    }
    *out = e;
    return ME_OK;
}

int64_t me_output_size(const MobExec *e) {
    int64_t commands = (int64_t)e->dim[ED_CAPACITY] * ME_STRIDE;
    int64_t targets = (int64_t)(e->dim[ED_PLAYERS] + e->dim[ED_GOAL_FIELDS]) * 2;
    return commands + targets + 1 + (int64_t)e->dim[ED_CAPACITY] * ME_REQUEST_STRIDE;
}

/* ---- Single-precision helpers that match Godot's Vector2 ---- */

typedef struct { float x, y; } V2;

static inline V2 v2(float x, float y) { V2 v = {x, y}; return v; }
static inline V2 v2_from_angle(double angle) { float a = (float)angle; return v2(cosf(a), sinf(a)); }
static inline V2 v2_scale(V2 v, double s) { float f = (float)s; return v2(v.x * f, v.y * f); }
static inline float v2_length_squared(V2 v) { return v.x * v.x + v.y * v.y; }
static inline float v2_length(V2 v) { return sqrtf(v.x * v.x + v.y * v.y); }
static inline float v2_angle(V2 v) { return atan2f(v.y, v.x); }
static inline float v2_distance_squared(V2 a, V2 b) { float dx = a.x - b.x, dy = a.y - b.y; return dx * dx + dy * dy; }
static inline V2 v2_normalized(V2 v) {
    float l = v.x * v.x + v.y * v.y;
    if (l != 0.0f) {
        l = sqrtf(l);
        v.x /= l;
        v.y /= l;
    }
    return v;
}

/* ---- Views that match mob_pool.gd, mob_party.gd and mob_perception.gd ---- */

static inline int targetable(const Run *r, int player) { return r->party_present[player] != 0 && r->party_alive[player] != 0; }
static inline int knows(const Run *r, int slot, int player) {
    return r->seen_tick[slot * r->e->dim[ED_PLAYERS] + player] >= 0 && targetable(r, player);
}
static inline int sees(const Run *r, int slot, int player) {
    return r->visible[slot * r->e->dim[ED_PLAYERS] + player] != 0 && targetable(r, player);
}
static inline int ally_of(const Run *r, int slot, int index) { return r->allies[slot * r->e->dim[ED_ALLIES] + index]; }
static inline double distance_to(const Run *r, int slot, double x, double z) {
    double dx = (double)r->xz[slot * 2] - x, dz = (double)r->xz[slot * 2 + 1] - z;
    return sqrt(dx * dx + dz * dz);
}
static inline int leader_of(const Run *r, int slot) {
    int chosen = r->leader[slot];
    return chosen >= 0 && r->alive[chosen] != 0 && r->generation[chosen] == r->leader_generation[slot] ? chosen : -1;
}

/* ---- Locomotion requests, matching mob_locomotion.gd ---- */

static inline float *command_row(const Run *r, int slot) { return r->commands + (size_t)slot * ME_STRIDE; }
static inline void hold(const Run *r, int slot) { command_row(r, slot)[ME_AT_MODE] = ME_MODE_HOLD; }
static inline int is_holding(const Run *r, int slot) { return command_row(r, slot)[ME_AT_MODE] == (float)ME_MODE_HOLD; }

static void seek_player(const Run *r, int slot, int player, V2 offset, double stop) {
    float *c = command_row(r, slot);
    c[ME_AT_STOP] = (float)stop;
    c[ME_AT_TARGET] = (float)player;
    c[ME_AT_MODE] = ME_MODE_SEEK;
    c[ME_AT_OFFSET_X] = offset.x;
    c[ME_AT_OFFSET_Z] = offset.y;
}

static void flee_from(const Run *r, int slot, int player) {
    float *c = command_row(r, slot);
    c[ME_AT_TARGET] = (float)player;
    c[ME_AT_MODE] = ME_MODE_FLEE;
}

static int goal_field(const Run *r, double x, double z) {
    MobExec *e = r->e;
    int64_t cx = (int64_t)floor(x / GOAL_CELL), cz = (int64_t)floor(z / GOAL_CELL);
    int64_t key = (cx + 32768) * 65536 + (cz + 32768);
    int oldest = 0;
    for (int index = 0; index < e->dim[ED_GOAL_FIELDS]; index++) {
        if (e->goal_key[index] == key) {
            e->goal_used[index] = r->goal_tick;
            return e->dim[ED_PLAYERS] + index;
        }
        if (e->goal_used[index] < e->goal_used[oldest]) oldest = index;
    }
    e->goal_key[oldest] = key;
    e->goal_used[oldest] = r->goal_tick;
    int field = e->dim[ED_PLAYERS] + oldest;
    r->targets[field * 2] = (float)(((double)cx + 0.5) * GOAL_CELL);
    r->targets[field * 2 + 1] = (float)(((double)cz + 0.5) * GOAL_CELL);
    return field;
}

static void go_to(const Run *r, int slot, double x, double z, double stop) {
    float *c = command_row(r, slot);
    c[ME_AT_STOP] = (float)stop;
    if (mn_line_clear(r->nav, r->xz[slot * 2], r->xz[slot * 2 + 1], (float)x, (float)z, CLEAR_BODY) != 0) {
        c[ME_AT_MODE] = ME_MODE_DIRECT;
        c[ME_AT_OFFSET_X] = (float)x;
        c[ME_AT_OFFSET_Z] = (float)z;
        return;
    }
    int field = goal_field(r, x, z);
    c[ME_AT_TARGET] = (float)field;
    c[ME_AT_MODE] = ME_MODE_SEEK;
    c[ME_AT_OFFSET_X] = (float)(x - (double)r->targets[field * 2]);
    c[ME_AT_OFFSET_Z] = (float)(z - (double)r->targets[field * 2 + 1]);
}

/* ---- Attack rules, matching mob_rules.gd and mob_abilities.gd ---- */

static int has_fighter_ally(const Run *r, int slot) {
    const MobExec *e = r->e;
    int leader = leader_of(r, slot);
    if (leader >= 0 && e->support[r->species[leader]] == 0) return 1;
    for (int index = 0; index < e->dim[ED_ALLIES]; index++) {
        int other = ally_of(r, slot, index);
        if (other >= 0 && r->alive[other] != 0 && e->support[r->species[other]] == 0) return 1;
    }
    return 0;
}

static int attack_ready(const Run *r, int slot, int attack) {
    const MobExec *e = r->e;
    int at = r->species[slot] * e->dim[ED_ATTACKS] + attack;
    if (e->attack_exists[at] == 0 || (e->attack_mutation[at] != 0 && (r->mutations[slot] & e->attack_mutation[at]) == 0)) return 0;
    if (r->tick < r->ready_at[slot] || r->tick < r->cooldown_until[slot * e->dim[ED_ATTACKS] + attack] || r->windup_until[slot] > 0) return 0;
    return e->attack_lonely[at] == 0 || !has_fighter_ally(r, slot);
}

/* The checks of MobAbilities.begin that depend only on simulation state. Attacker caps, sight and
 * any host checks stay with begin itself, which the script calls for each attempt in order. */
static int attack_possible(const Run *r, int slot, int attack, int player) {
    const MobExec *e = r->e;
    if (r->tick < r->stun_until[slot] || !targetable(r, player) || !attack_ready(r, slot, attack)) return 0;
    int at = r->species[slot] * e->dim[ED_ATTACKS] + attack;
    double distance = distance_to(r, slot, r->party_x[player], r->party_z[player]);
    double reach = (double)e->attack_range[at] + (double)r->reach_bonus[slot];
    return distance <= reach && distance >= (double)e->attack_min_range[at];
}

/* ---- Executors, matching mob_executors_reference.gd ---- */

static inline int due(const Run *r, int slot) {
    return r->behaviour_since[slot] == r->tick || (r->tick + slot) % r->e->dim[ED_GOAL_REFRESH] == 0 || is_holding(r, slot);
}

static V2 ring_offset(const Run *r, int slot, int player, double ring, double reach) {
    const MobExec *e = r->e;
    V2 away = v2((float)((double)r->xz[slot * 2] - (double)r->party_x[player]), (float)((double)r->xz[slot * 2 + 1] - (double)r->party_z[player]));
    double bearing = (double)v2_length_squared(away) > 0.0001 ? (double)v2_angle(away) : (double)slot * GOLDEN_ANGLE;
    int chosen = r->manoeuvre[slot];
    double radius = fmax(RING_MIN, ring);
    if (chosen == e->dim[ED_CIRCLE_LEFT]) {
        bearing += CIRCLE_ANGLE;
    } else if (chosen == e->dim[ED_CIRCLE_RIGHT]) {
        bearing -= CIRCLE_ANGLE;
    } else if (chosen == e->dim[ED_GET_BEHIND]) {
        V2 velocity = v2(r->party_vx[player], r->party_vz[player]);
        bearing = (double)v2_length(velocity) > STILL_SPEED ? (double)v2_angle(velocity) + PI_D : bearing + PI_D;
    } else if (chosen == e->dim[ED_KEEP_RANGE]) {
        radius = fmax(RING_MIN, reach * MAX_RANGE_SHARE);
    }
    return v2_scale(v2_from_angle(bearing), radius);
}

static void go_to_last_known(const Run *r, int slot, int player) {
    if (!due(r, slot)) return;
    int at = slot * r->e->dim[ED_PLAYERS] + player;
    double x = r->seen_x[at], z = r->seen_z[at];
    if (distance_to(r, slot, x, z) > SEARCH_ARRIVAL) {
        go_to(r, slot, x, z, SEEK_STOP);
        return;
    }
    V2 sweep = v2_scale(v2_from_angle((double)slot * GOLDEN_ANGLE + (double)(r->tick / SEARCH_TICKS) * GOLDEN_ANGLE), SEARCH_RING);
    go_to(r, slot, x + (double)sweep.x, z + (double)sweep.y, SEEK_STOP);
}

static void close_on(const Run *r, int slot, int player, double ring, double reach) {
    if (!sees(r, slot, player)) {
        go_to_last_known(r, slot, player);
    } else if (due(r, slot)) {
        seek_player(r, slot, player, ring_offset(r, slot, player, ring, reach), SEEK_STOP);
    }
}

static int target_player(const Run *r, int slot) {
    int player = (int)r->enemy_target[slot] - 1;
    return player >= 0 && knows(r, slot, player) ? player : -1;
}

static void do_attack(Run *r, int slot) {
    const MobExec *e = r->e;
    int player = target_player(r, slot);
    if (player < 0) {
        hold(r, slot);
        return;
    }
    int attack = e->attack_slot[r->behaviour[slot]];
    double reach = (double)e->attack_range[r->species[slot] * e->dim[ED_ATTACKS] + attack] + (double)r->reach_bonus[slot];
    if (sees(r, slot, player) && attack_possible(r, slot, attack, player)) {
        /* Leave the row alone. Begin holds the mob on success; otherwise the script copies this fallback,
         * which is what close_on writes for a mob that sees its target. */
        float *attempt = r->requests + (size_t)r->request_count * ME_REQUEST_STRIDE;
        float *fallback = attempt + 3;
        attempt[0] = (float)slot;
        attempt[1] = (float)attack;
        attempt[2] = (float)player;
        memcpy(fallback, command_row(r, slot), ME_STRIDE * sizeof(float));
        if (due(r, slot)) {
            V2 offset = ring_offset(r, slot, player, reach * RING_SHARE, reach);
            fallback[ME_AT_STOP] = (float)SEEK_STOP;
            fallback[ME_AT_TARGET] = (float)player;
            fallback[ME_AT_MODE] = ME_MODE_SEEK;
            fallback[ME_AT_OFFSET_X] = offset.x;
            fallback[ME_AT_OFFSET_Z] = offset.y;
        }
        r->request_count += 1;
        return;
    }
    close_on(r, slot, player, reach * RING_SHARE, reach);
}

static void do_idle(const Run *r, int slot) {
    if (r->behaviour_since[slot] != r->tick && (r->tick + slot * 7) % WANDER_TICKS != 0) return;
    int leader = leader_of(r, slot);
    double home_x = leader >= 0 ? (double)r->xz[leader * 2] : (double)r->spawn_x[slot];
    double home_z = leader >= 0 ? (double)r->xz[leader * 2 + 1] : (double)r->spawn_z[slot];
    if (distance_to(r, slot, home_x, home_z) > WANDER_LEASH) {
        go_to(r, slot, home_x, home_z, WANDER_STOP);
        return;
    }
    double turn = (double)slot * GOLDEN_ANGLE + (double)(r->tick / WANDER_TICKS) * GOLDEN_ANGLE;
    V2 step = v2_scale(v2_from_angle(turn), WANDER_RADIUS);
    V2 goal = v2((float)home_x + step.x, (float)home_z + step.y);
    if (mn_line_clear(r->nav, r->xz[slot * 2], r->xz[slot * 2 + 1], goal.x, goal.y, CLEAR_BODY) != 0) {
        go_to(r, slot, goal.x, goal.y, WANDER_STOP);
    } else {
        hold(r, slot);
    }
}

static void do_search(const Run *r, int slot) {
    int player = target_player(r, slot);
    if (player < 0) hold(r, slot);
    else go_to_last_known(r, slot, player);
}

static void do_approach(const Run *r, int slot) {
    int player = target_player(r, slot);
    if (player < 0) {
        hold(r, slot);
        return;
    }
    int kind = r->species[slot];
    close_on(r, slot, player, (double)r->e->preferred_range[kind], (double)r->e->max_range[kind] + (double)r->reach_bonus[slot]);
}

static void do_flee(const Run *r, int slot) {
    int player = target_player(r, slot);
    if (player < 0) hold(r, slot);
    else if (due(r, slot)) flee_from(r, slot, player);
}

/* Picks the closest open point within reach that the target cannot see. */
static void find_cover(const Run *r, int slot, int player) {
    MobExec *e = r->e;
    V2 origin = v2(r->xz[slot * 2], r->xz[slot * 2 + 1]);
    int count = 0;
    for (int ring = 0; ring < COVER_RADII; ring++) {
        for (int step = 0; step < COVER_ANGLES; step++) {
            V2 offset = v2_scale(v2_from_angle((double)step * TAU_D / COVER_ANGLES), cover_radius[ring]);
            V2 point = v2(origin.x + offset.x, origin.y + offset.y);
            if ((double)mn_clearance(r->nav, point.x, point.y) >= COVER_CLEARANCE) {
                float *query = e->cover_queries + count * 5;
                query[0] = r->party_x[player];
                query[1] = r->party_z[player];
                query[2] = point.x;
                query[3] = point.y;
                query[4] = 0.0f;
                e->cover_points[count * 2] = point.x;
                e->cover_points[count * 2 + 1] = point.y;
                count++;
            }
        }
    }
    e->cover_found[slot] = 0;
    if (count == 0) return;
    mn_line_clear_batch(r->nav, e->cover_queries, count, e->cover_clear);
    double best = INFINITY;
    for (int index = 0; index < count; index++) {
        V2 point = v2(e->cover_points[index * 2], e->cover_points[index * 2 + 1]);
        double distance = (double)v2_distance_squared(origin, point);
        if (e->cover_clear[index] == 0 && distance < best) {
            best = distance;
            e->cover_x[slot] = point.x;
            e->cover_z[slot] = point.y;
            e->cover_found[slot] = 1;
        }
    }
}

static void do_cover(const Run *r, int slot) {
    MobExec *e = r->e;
    int player = target_player(r, slot);
    if (player < 0) {
        hold(r, slot);
        return;
    }
    if (r->behaviour_since[slot] == r->tick || (r->tick + slot) % COVER_REFRESH_TICKS == 0) find_cover(r, slot, player);
    if (e->cover_found[slot] == 0) {
        if (due(r, slot)) flee_from(r, slot, player);
    } else if (due(r, slot)) {
        go_to(r, slot, e->cover_x[slot], e->cover_z[slot], COVER_STOP);
    }
}

static int chosen_ally(const Run *r, int slot) {
    int head = r->ally_target[slot];
    if (head == 0) return -1;
    if (head == r->e->dim[ED_ALLIES] + 1) return leader_of(r, slot);
    int ally = ally_of(r, slot, head - 1);
    return ally >= 0 && r->alive[ally] != 0 ? ally : -1;
}

static int nearest_known_player(const Run *r, int slot, V2 at) {
    double best = INFINITY;
    int chosen = -1;
    for (int player = 0; player < r->e->dim[ED_PLAYERS]; player++) {
        if (!knows(r, slot, player)) continue;
        int seen = slot * r->e->dim[ED_PLAYERS] + player;
        double distance = (double)v2_distance_squared(at, v2(r->seen_x[seen], r->seen_z[seen]));
        if (distance < best) {
            best = distance;
            chosen = player;
        }
    }
    return chosen;
}

static void do_defend(const Run *r, int slot) {
    if (!due(r, slot)) return;
    int ally = chosen_ally(r, slot);
    if (ally < 0) {
        hold(r, slot);
        return;
    }
    V2 at = v2(r->xz[ally * 2], r->xz[ally * 2 + 1]);
    int threat = nearest_known_player(r, slot, at);
    if (threat < 0) {
        go_to(r, slot, at.x, at.y, DEFEND_DISTANCE);
        return;
    }
    int seen = slot * r->e->dim[ED_PLAYERS] + threat;
    V2 toward = v2_normalized(v2(r->seen_x[seen] - at.x, r->seen_z[seen] - at.y));
    go_to(r, slot, (double)at.x + (double)toward.x * DEFEND_DISTANCE, (double)at.y + (double)toward.y * DEFEND_DISTANCE, SEEK_STOP);
}

static void do_block(const Run *r, int slot) {
    int player = target_player(r, slot);
    if (player < 0) {
        hold(r, slot);
    } else if (!sees(r, slot, player)) {
        go_to_last_known(r, slot, player);
    } else if (due(r, slot)) {
        V2 heading = v2(r->party_vx[player], r->party_vz[player]);
        if ((double)v2_length(heading) <= STILL_SPEED) {
            heading = v2((float)((double)r->xz[slot * 2] - (double)r->party_x[player]), (float)((double)r->xz[slot * 2 + 1] - (double)r->party_z[player]));
        }
        seek_player(r, slot, player, v2_scale(v2_normalized(heading), BLOCK_DISTANCE), SEEK_STOP);
    }
}

#define BIND(field, index, type) r.field = (const type *)items[index]

MeResult me_run(MobExec *e, const MobNav *nav, const void *const *items, const int64_t *lengths, float *out) {
    int capacity = e->dim[ED_CAPACITY], players = e->dim[ED_PLAYERS], attacks = e->dim[ED_ATTACKS];
    int64_t command_floats = (int64_t)capacity * ME_STRIDE, target_floats = (int64_t)(players + e->dim[ED_GOAL_FIELDS]) * 2;
    if (nav == NULL || lengths[EI_CLOCK] != EK_COUNT || lengths[EI_ALIVE] != capacity || lengths[EI_XZ] != capacity * 2
            || lengths[EI_COOLDOWN_UNTIL] != (int64_t)capacity * attacks || lengths[EI_VISIBLE] != (int64_t)capacity * players
            || lengths[EI_ALLIES] != (int64_t)capacity * e->dim[ED_ALLIES]
            || lengths[EI_PARTY_X] != players || lengths[EI_COMMANDS] != command_floats || lengths[EI_TARGETS] != target_floats) {
        return ME_ERR_ARGUMENT;
    }
    Run r;
    memset(&r, 0, sizeof(r));
    r.e = e;
    r.nav = nav;
    const int *clock = (const int *)items[EI_CLOCK];
    r.tick = clock[EK_TICK];
    r.goal_tick = clock[EK_GOAL_TICK];
    BIND(alive, EI_ALIVE, uint8_t); BIND(generation, EI_GENERATION, int); BIND(species, EI_SPECIES, int);
    BIND(mutations, EI_MUTATIONS, int); BIND(leader, EI_LEADER, int); BIND(leader_generation, EI_LEADER_GENERATION, int);
    BIND(xz, EI_XZ, float); BIND(spawn_x, EI_SPAWN_X, float); BIND(spawn_z, EI_SPAWN_Z, float); BIND(reach_bonus, EI_REACH_BONUS, float);
    BIND(behaviour, EI_BEHAVIOUR, uint8_t); BIND(behaviour_since, EI_BEHAVIOUR_SINCE, int); BIND(enemy_target, EI_ENEMY_TARGET, uint8_t);
    BIND(ally_target, EI_ALLY_TARGET, uint8_t); BIND(manoeuvre, EI_MANOEUVRE, uint8_t); BIND(windup_until, EI_WINDUP_UNTIL, int);
    BIND(stun_until, EI_STUN_UNTIL, int); BIND(ready_at, EI_READY_AT, int); BIND(cooldown_until, EI_COOLDOWN_UNTIL, int);
    BIND(visible, EI_VISIBLE, uint8_t); BIND(seen_x, EI_SEEN_X, float); BIND(seen_z, EI_SEEN_Z, float);
    BIND(seen_tick, EI_SEEN_TICK, int); BIND(allies, EI_ALLIES, int); BIND(party_present, EI_PARTY_PRESENT, uint8_t);
    BIND(party_alive, EI_PARTY_ALIVE, uint8_t); BIND(party_x, EI_PARTY_X, float); BIND(party_z, EI_PARTY_Z, float);
    BIND(party_vx, EI_PARTY_VX, float); BIND(party_vz, EI_PARTY_VZ, float);
    r.commands = out;
    r.targets = out + command_floats;
    r.requests = out + command_floats + target_floats + 1;
    memcpy(r.commands, items[EI_COMMANDS], (size_t)command_floats * sizeof(float));
    memcpy(r.targets, items[EI_TARGETS], (size_t)target_floats * sizeof(float));
    const int *active = (const int *)items[EI_ACTIVE];
    for (int64_t i = 0; i < lengths[EI_ACTIVE]; i++) {
        int slot = active[i];
        if (slot < 0 || slot >= capacity) return ME_ERR_ARGUMENT;
        if (r.windup_until[slot] > 0 || r.tick < r.stun_until[slot]) continue;
        switch (e->executor[r.behaviour[slot]]) {
            case MX_IDLE: do_idle(&r, slot); break;
            case MX_SEARCH: do_search(&r, slot); break;
            case MX_APPROACH: do_approach(&r, slot); break;
            case MX_ATTACK: do_attack(&r, slot); break;
            case MX_FLEE: do_flee(&r, slot); break;
            case MX_COVER: do_cover(&r, slot); break;
            case MX_DEFEND: do_defend(&r, slot); break;
            case MX_BLOCK: do_block(&r, slot); break;
            default: hold(&r, slot); break;
        }
    }
    out[command_floats + target_floats] = (float)r.request_count;
    return ME_OK;
}

#define HASTE_SCALE 1.22

MeResult me_speeds(const MobExec *e, const void *const *items, const int64_t *lengths, float *out) {
    int capacity = e->dim[ED_CAPACITY];
    int64_t floats = (int64_t)capacity * ME_STRIDE;
    if (lengths[EV_TICK] != 1 || lengths[EV_COMMANDS] != floats || lengths[EV_SPEED] != capacity || lengths[EV_WINDUP_UNTIL] != capacity
            || lengths[EV_STUN_UNTIL] != capacity || lengths[EV_ROOT_UNTIL] != capacity || lengths[EV_SLOW_UNTIL] != capacity
            || lengths[EV_SLOW_SCALE] != capacity || lengths[EV_HASTE_UNTIL] != capacity) {
        return ME_ERR_ARGUMENT;
    }
    int tick = ((const int *)items[EV_TICK])[0];
    const int *active = items[EV_ACTIVE], *windup = items[EV_WINDUP_UNTIL], *stun = items[EV_STUN_UNTIL], *root = items[EV_ROOT_UNTIL];
    const int *slow = items[EV_SLOW_UNTIL], *haste = items[EV_HASTE_UNTIL];
    const float *speed = items[EV_SPEED], *slow_scale = items[EV_SLOW_SCALE];
    memcpy(out, items[EV_COMMANDS], (size_t)floats * sizeof(float));
    for (int64_t i = 0; i < lengths[EV_ACTIVE]; i++) {
        int slot = active[i];
        if (slot < 0 || slot >= capacity) return ME_ERR_ARGUMENT;
        double scale;
        if (windup[slot] > 0 || tick < stun[slot] || tick < root[slot]) {
            scale = 0.0;
        } else {
            scale = tick < slow[slot] ? (double)slow_scale[slot] : 1.0;
            if (tick < haste[slot]) scale *= HASTE_SCALE;
        }
        out[(size_t)slot * ME_STRIDE + ME_AT_SPEED] = (float)((double)speed[slot] * scale);
    }
    return ME_OK;
}
