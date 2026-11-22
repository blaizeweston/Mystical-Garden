#ifndef MOB_EXEC_H
#define MOB_EXEC_H
/* Native behaviour executors. Each tick turns every mob's current intent into a movement command
 * and, for mobs whose attack passes every rule that depends only on simulation state, an attempt.
 * The script then calls MobAbilities.begin for each attempt in order, because a host may add
 * checks of its own, and applies the attempt's fallback movement row when begin refuses. It mirrors mob_executors_reference.gd
 * exactly, including where that script uses single precision (Vector2) and double precision (float). */

#include <stdint.h>

#include "mob_nav.h"

typedef enum { ME_BYTES, ME_INTS, ME_FLOATS } MeKind;

typedef enum { ME_OK = 0, ME_ERR_ARGUMENT = 1, ME_ERR_MEMORY = 2 } MeResult;

/* What each behaviour does, in the order mob_executors.gd sends them. */
typedef enum { MX_HOLD, MX_IDLE, MX_SEARCH, MX_APPROACH, MX_ATTACK, MX_FLEE, MX_COVER, MX_DEFEND, MX_BLOCK, MX_KIND_COUNT } MeExecutor;

/* Fixed configuration tables, sent once. */
typedef enum {
    EC_DIMS, EC_EXECUTOR, EC_ATTACK_SLOT,
    EC_PREFERRED_RANGE, EC_MAX_RANGE, EC_SUPPORT,
    EC_ATTACK_EXISTS, EC_ATTACK_MUTATION, EC_ATTACK_RANGE, EC_ATTACK_MIN_RANGE, EC_ATTACK_SIGHT, EC_ATTACK_ESCORT,
    EC_COUNT
} MeConfig;

/* Values inside EC_DIMS. */
typedef enum {
    ED_CAPACITY, ED_PLAYERS, ED_ALLIES, ED_ATTACKS, ED_SPECIES, ED_BEHAVIOURS, ED_GOAL_FIELDS, ED_GOAL_REFRESH,
    ED_CIRCLE_LEFT, ED_CIRCLE_RIGHT, ED_GET_BEHIND, ED_KEEP_RANGE,
    ED_COUNT
} MeDim;

/* Live arrays, sent every tick. */
typedef enum {
    EI_CLOCK, EI_ACTIVE, EI_ALIVE, EI_GENERATION, EI_SPECIES, EI_MUTATIONS, EI_LEADER, EI_LEADER_GENERATION,
    EI_XZ, EI_SPAWN_X, EI_SPAWN_Z, EI_REACH_BONUS,
    EI_BEHAVIOUR, EI_BEHAVIOUR_SINCE, EI_ENEMY_TARGET, EI_ALLY_TARGET, EI_MANOEUVRE,
    EI_WINDUP_UNTIL, EI_STUN_UNTIL, EI_READY_AT, EI_COOLDOWN_UNTIL,
    EI_VISIBLE, EI_SEEN_X, EI_SEEN_Z, EI_SEEN_TICK, EI_ALLIES,
    EI_PARTY_PRESENT, EI_PARTY_ALIVE, EI_PARTY_X, EI_PARTY_Z, EI_PARTY_VX, EI_PARTY_VZ,
    EI_COMMANDS, EI_TARGETS,
    EI_COUNT
} MeInput;

/* Values inside EI_CLOCK: this tick, and the tick locomotion last stepped (it stamps goal fields). */
typedef enum { EK_TICK, EK_GOAL_TICK, EK_COUNT } MeClock;

/* Movement command layout, shared with mob_locomotion.gd. */
#define ME_STRIDE 7
enum { ME_AT_ACTIVE, ME_AT_SPEED, ME_AT_STOP, ME_AT_TARGET, ME_AT_MODE, ME_AT_OFFSET_X, ME_AT_OFFSET_Z };
/* Movement modes, shared with mob_nav_world.gd. */
enum { ME_MODE_HOLD, ME_MODE_SEEK, ME_MODE_FLEE, ME_MODE_DIRECT };
/* Each attempt is slot, attack, player, then the movement row to use if begin refuses it. */
#define ME_REQUEST_STRIDE (3 + ME_STRIDE)

/* Inputs for me_speeds, which fills the speed column of the movement commands. */
typedef enum {
    EV_TICK, EV_ACTIVE, EV_SPEED, EV_WINDUP_UNTIL, EV_STUN_UNTIL, EV_ROOT_UNTIL, EV_SLOW_UNTIL, EV_SLOW_SCALE, EV_HASTE_UNTIL, EV_COMMANDS,
    EV_COUNT
} MeSpeedInput;

typedef struct MobExec MobExec;

MeKind me_config_kind(int index);
MeKind me_input_kind(int index);
MeKind me_speed_input_kind(int index);
/* items and lengths hold EC_COUNT entries. */
MeResult me_create(const void *const *items, const int64_t *lengths, MobExec **out);
void me_destroy(MobExec *exec);
/* Total floats written by me_run: commands, then targets, then the attempt count and the attempts. */
int64_t me_output_size(const MobExec *exec);
/* items and lengths hold EI_COUNT entries. */
MeResult me_run(MobExec *exec, const MobNav *nav, const void *const *items, const int64_t *lengths, float *out);

/* Writes the commands with each active mob's speed after wind-ups, stuns, roots, slows and haste,
 * matching MobLocomotion.speeds_reference. Writes capacity * ME_STRIDE floats. */
MeResult me_speeds(const MobExec *exec, const void *const *items, const int64_t *lengths, float *out);

#endif
