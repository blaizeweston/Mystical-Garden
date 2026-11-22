#ifndef MOB_DECIDE_H
#define MOB_DECIDE_H
/* Native decision helpers: legal-action masks (mob_rules.gd build_masks_reference) and the scripted
 * brain (mob_scripted_brain_reference.gd). Both read the caller's arrays and write fresh outputs. */

#include <stdint.h>

typedef enum { DK_BYTES, DK_INTS, DK_FLOATS } MdKind;

typedef enum { DK_OK = 0, DK_ERR_ARGUMENT = 1, DK_ERR_MEMORY = 2 } MdResult;

typedef enum {
    DC_DIMS, DC_HEAD_OFFSETS, DC_AVAILABLE, DC_LEADER_ONLY, DC_TARGET_KIND, DC_ATTACK_SLOT, DC_DELIVERY,
    DC_SUPPORT, DC_SKIRMISHER, DC_MAX_RANGE, DC_ATTACK_EXISTS, DC_ATTACK_MUTATION, DC_ATTACK_ESCORT, DC_ATTACK_DELIVERY,
    DC_ATTACK_RANGE, DC_ATTACK_MIN_RANGE,
    DC_COUNT
} MdConfig;

/* Values inside DC_DIMS. Behaviour and manoeuvre ids are -1 when the contract lacks them. */
typedef enum {
    DD_CAPACITY, DD_PLAYERS, DD_ALLIES, DD_ATTACKS, DD_SPECIES, DD_BEHAVIOURS, DD_MANOEUVRES, DD_SYMBOLS,
    DD_MESSAGES_ENABLED, DD_MASK_SIZE, DD_LEADER_FLAGS,
    DD_IDLE, DD_SEARCH, DD_APPROACH, DD_MELEE, DD_RANGED, DD_ABILITY_1, DD_ABILITY_2, DD_ABILITY_3, DD_DEFEND,
    DD_CIRCLE_LEFT, DD_CIRCLE_RIGHT, DD_KEEP_RANGE,
    DD_COUNT
} MdDim;

typedef enum {
    DI_TICK, DI_SLOTS, DI_ACTIVE, DI_ALIVE, DI_GENERATION, DI_SPECIES, DI_MUTATIONS, DI_FLAGS, DI_LEADER, DI_LEADER_GENERATION,
    DI_XZ, DI_ENEMY_TARGET, DI_READY_AT, DI_COOLDOWN_UNTIL, DI_WINDUP_UNTIL,
    DI_VISIBLE, DI_SEEN_X, DI_SEEN_Z, DI_SEEN_TICK, DI_ALLIES,
    DI_PARTY_PRESENT, DI_PARTY_ALIVE, DI_PARTY_X, DI_PARTY_Z,
    DI_MASKS,
    DI_COUNT
} MdInput;

/* Contract enums mirrored from mob_contract.gd. */
enum { DK_TARGET_NONE, DK_TARGET_ENEMY, DK_TARGET_ALLY, DK_TARGET_ABILITY };
enum { DK_DELIVERY_ANY, DK_DELIVERY_MELEE, DK_DELIVERY_RANGED };
enum { DK_HEAD_BEHAVIOUR, DK_HEAD_ENEMY, DK_HEAD_ALLY, DK_HEAD_MANOEUVRE, DK_HEAD_MESSAGE_A, DK_HEAD_MESSAGE_B, DK_HEAD_COUNT };

typedef struct MobDecide MobDecide;

MdKind md_config_kind(int index);
MdKind md_input_kind(int index);
MdResult md_create(const void *const *items, const int64_t *lengths, MobDecide **out);
void md_destroy(MobDecide *decide);
int md_mask_size(const MobDecide *decide);
/* Writes mask_size bytes per entry in DI_SLOTS. DI_MASKS is ignored. */
MdResult md_masks(const MobDecide *decide, const void *const *items, const int64_t *lengths, uint8_t *out);
/* Writes DK_HEAD_COUNT bytes per entry in DI_SLOTS, using the masks in DI_MASKS. */
MdResult md_scripted(MobDecide *decide, const void *const *items, const int64_t *lengths, uint8_t *out);

#endif
