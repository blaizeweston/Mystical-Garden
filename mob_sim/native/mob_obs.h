#ifndef MOB_OBS_H
#define MOB_OBS_H
/* Builds mob observation rows. Every offset is supplied from ai/schema.json at configure time. */

#include <stddef.h>
#include <stdint.h>

#include "mob_nav.h"

typedef enum { MO_BYTES, MO_INTS, MO_FLOATS } MoKind;

typedef enum {
    MO_OK = 0,
    MO_ERR_ARGUMENT = 1,
    MO_ERR_MEMORY = 2,
    MO_ERR_STATE = 3
} MoResult;

/* Fixed configuration tables, in the order ai/mob_native_runtime.gd sends them. */
typedef enum {
    MC_DIMS, MC_FIELDS, MC_STRIDES, MC_SCALE_KIND, MC_SCALE_INVERSE, MC_REALS,
    MC_VISION, MC_HIT_RADIUS, MC_MAX_RANGE, MC_SUPPORT, MC_ROLE,
    MC_ATTACK_EXISTS, MC_ATTACK_MUTATION, MC_ATTACK_SHAPE, MC_ATTACK_RANGE, MC_ATTACK_AREA,
    MC_ATTACK_WINDUP, MC_ATTACK_RECOVERY, MC_HOLD_TICKS, MC_TARGET_KIND,
    MC_COUNT
} MoConfig;

/* Values inside MC_DIMS. */
typedef enum {
    MD_CAPACITY, MD_PLAYERS, MD_ALLIES, MD_ATTACKS, MD_SPECIES, MD_BEHAVIOURS, MD_SYMBOLS, MD_OBSERVATION,
    MD_BUCKETS, MD_ONE_SECOND, MD_ABILITIES, MD_COVER_SLOTS, MD_SHAPE_BUFF, MD_SHAPE_SUMMON, MD_TARGET_ALLY, MD_LEADER_FLAGS,
    MD_COUNT
} MoDim;

/* Values inside MC_REALS. */
typedef enum { MR_CLIP, MR_WALL_RANGE, MR_COVER_CLEARANCE, MR_FACING_DOT, MR_NEVER_SEEN, MR_RANGED_ROLE, MR_TICK_RATE, MR_COUNT } MoReal;

/* Live simulation arrays, in the order ai/mob_native_runtime.gd sends them each decision. */
typedef enum {
    MI_CLOCK, MI_SLOTS, MI_ACTIVE, MI_ALIVE, MI_GENERATION, MI_SPECIES, MI_FLAGS, MI_MUTATIONS, MI_LEADER, MI_LEADER_GENERATION,
    MI_XZ, MI_HP, MI_MAX_HP, MI_SPEED, MI_DAMAGE, MI_REACH_BONUS, MI_INTELLIGENCE,
    MI_BEHAVIOUR, MI_ENEMY_TARGET, MI_ALLY_TARGET, MI_MESSAGE_A, MI_MESSAGE_B, MI_BEHAVIOUR_SINCE,
    MI_READY_AT, MI_COOLDOWN_UNTIL, MI_STUN_UNTIL, MI_ROOT_UNTIL, MI_SLOW_UNTIL, MI_HASTE_UNTIL,
    MI_VISIBLE, MI_SEEN_X, MI_SEEN_Z, MI_SEEN_TICK, MI_ALLIES,
    MI_PARTY_PRESENT, MI_PARTY_ALIVE, MI_PARTY_HP, MI_PARTY_MAX_HP, MI_PARTY_VX, MI_PARTY_VZ,
    MI_TAKEN, MI_DEALT, MI_TAKEN_FROM, MI_DEALT_TO, MI_ENGAGED_AT,
    MI_COUNT
} MoInput;

/* Repeating observation blocks whose stride is needed. */
typedef enum { MS_ABILITY, MS_ENEMY, MS_ALLY, MS_COVER, MS_COUNT } MoStride;

/* Field offsets inside one row, in the order ai/mob_native_runtime.gd resolves them. */
typedef enum {
    MF_WALK_SPEED, MF_SIZE, MF_MAX_HP, MF_VISION_RANGE, MF_AUTO_DAMAGE, MF_AUTO_RANGE, MF_AUTO_COOLDOWN,
    MF_AB_EXISTS, MF_AB_DAMAGE, MF_AB_RANGE, MF_AB_COOLDOWN_TOTAL, MF_AB_COOLDOWN_REMAINING, MF_AB_SIGN, MF_AB_AREA, MF_AB_WINDUP,
    MF_HP_FRACTION, MF_HP_CHANGE_1S, MF_HP_CHANGE_3S, MF_DEALT_1S, MF_DEALT_3S, MF_AUTO_REMAINING, MF_SINCE_BEHAVIOUR,
    MF_BEHAVIOUR_PROGRESS, MF_TIME_IN_COMBAT, MF_SINCE_SIGHT, MF_IS_LEADER, MF_INTELLIGENCE,
    MF_STUNNED, MF_SLOWED, MF_ROOTED, MF_BUFFED,
    MF_BEHAVIOUR, MF_TARGET, MF_ARCHETYPE,
    MF_ALLIES_NEARBY, MF_ENEMIES_NEARBY, MF_ENEMY_TOTAL_HP, MF_ENEMY_HP_FRACTION, MF_ALLY_TOTAL_HP, MF_ALLY_HP_FRACTION,
    MF_WALLS,
    MF_COVER_PRESENT, MF_COVER_DX, MF_COVER_DY, MF_COVER_DISTANCE, MF_COVER_BLOCKS,
    MF_E_PRESENT, MF_E_VISIBLE, MF_E_SINCE_SEEN, MF_E_DX, MF_E_DY, MF_E_DISTANCE, MF_E_VX, MF_E_VY, MF_E_HP, MF_E_MAX_HP,
    MF_E_DOWNED, MF_E_FACING, MF_E_SIGHT, MF_E_DEALT_ME, MF_E_I_DEALT, MF_E_TARGETING,
    MF_A_PRESENT, MF_A_DX, MF_A_DY, MF_A_DISTANCE, MF_A_HP, MF_A_HP_LOST, MF_A_DEALT, MF_A_ELITE, MF_A_MELEE, MF_A_RANGED,
    MF_A_SUPPORT, MF_A_BEHAVIOUR, MF_A_TARGET, MF_A_MESSAGE,
    MF_L_PRESENT, MF_L_DX, MF_L_DY, MF_L_DISTANCE, MF_L_HP, MF_L_HP_LOST, MF_L_DEALT, MF_L_ELITE, MF_L_MELEE, MF_L_RANGED,
    MF_L_SUPPORT, MF_L_BEHAVIOUR, MF_L_TARGET, MF_L_MESSAGE, MF_L_COOLDOWN,
    MF_COUNT
} MoField;

typedef struct MobObs MobObs;

/* items and lengths hold MC_COUNT entries. */
MoResult mo_create(const void *const *items, const int64_t *lengths, MobObs **out);
void mo_destroy(MobObs *obs);
void mo_reset_slot(MobObs *obs, int slot);
int mo_observation_size(const MobObs *obs);

MoKind mo_config_kind(int index);
MoKind mo_input_kind(int index);
/* items and lengths hold MI_COUNT entries. Writes one row per entry in MI_SLOTS. */
MoResult mo_build(MobObs *obs, const MobNav *nav, const void *const *items, const int64_t *lengths, float *out);

#endif
