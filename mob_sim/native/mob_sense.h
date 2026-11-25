#ifndef MOB_SENSE_H
#define MOB_SENSE_H
/* Native mob perception. With senses off it reproduces mob_perception.gd's reference sight exactly.
 * With senses on, sight needs light: a player is seen in light, within darkvision of the mob, or within
 * darkvision of the edge of any lit area. Senses also add hearing from noise events and scent
 * tracking through walls. With senses on, an engaged mob no longer tracks unseen players for free;
 * it must see, hear or smell them. Outputs are written as raw bytes for the script to slice back into arrays. */

#include <stdint.h>

#include "mob_nav.h"

typedef enum { SK_BYTES, SK_INTS, SK_FLOATS } MsKind;

typedef enum { SK_OK = 0, SK_ERR_ARGUMENT = 1, SK_ERR_MEMORY = 2, SK_ERR_STATE = 3 } MsResult;

typedef enum { SC_DIMS, SC_REALS, SC_VISION, SC_DARKVISION, SC_HEARING, SC_SMELL, SC_COUNT } MsConfig;

typedef enum {
    SD_CAPACITY, SD_PLAYERS, SD_ALLIES, SD_SPECIES, SD_REFRESH_TICKS, SD_RELEASE_TICKS, SD_ALERT_NEIGHBOURS, SD_NEAREST_LIMIT,
    SD_GRID_WIDTH, SD_GRID_HEIGHT, SD_SENSES, SD_SCENT_DECAY_TICKS,
    SD_COUNT
} MsDim;

typedef enum {
    SR_AWARENESS, SR_ALLY_RADIUS, SR_ALERT_RADIUS, SR_GRID_ORIGIN_X, SR_GRID_ORIGIN_Z, SR_GRID_CELL,
    SR_SCENT_DECAY, SR_SCENT_THRESHOLD,
    SR_COUNT
} MsReal;

typedef enum {
    SI_TICK, SI_SLOTS, SI_ACTIVE, SI_ALIVE, SI_GENERATION, SI_SPECIES, SI_LEADER, SI_LEADER_GENERATION, SI_XZ,
    SI_ENGAGED, SI_LAST_SENSED, SI_VISIBLE, SI_SEEN_X, SI_SEEN_Z, SI_SEEN_TICK,
    SI_ALLIES, SI_ALLY_GENERATION, SI_ALLY_AWAY_SINCE,
    SI_PARTY_PRESENT, SI_PARTY_ALIVE, SI_PARTY_X, SI_PARTY_Z,
    SI_NOISES, SI_LIGHTS, SI_AMBIENT,
    SI_COUNT
} MsInput;

/* A noise is x, z, loudness and the player who made it. Hearing range is the species' hearing times loudness. */
#define MS_NOISE_STRIDE 4
/* A light is x, z, radius and intensity. */
#define MS_LIGHT_STRIDE 4

typedef struct MobSense MobSense;

MsKind ms_config_kind(int index);
MsKind ms_input_kind(int index);
MsResult ms_create(const void *const *items, const int64_t *lengths, MobSense **out);
void ms_destroy(MobSense *sense);
/* Bytes written by ms_update: seen_x, seen_z, seen_tick, last_sensed, visible, engaged, in that order. */
int64_t ms_update_size(const MobSense *sense);
/* Bytes written by ms_allies: allies, ally_generation, ally_away_since. */
int64_t ms_allies_size(const MobSense *sense);
MsResult ms_update(MobSense *sense, MobNav *nav, const void *const *items, const int64_t *lengths, uint8_t *out);
/* Refreshes ally slots for the mobs in SI_SLOTS. */
MsResult ms_allies(MobSense *sense, MobNav *nav, const void *const *items, const int64_t *lengths, uint8_t *out);
/* Light level from 0 to 1 at a point, from the most recent update. Senses must be on. */
float ms_light_at(const MobSense *sense, float x, float z);
/* Whether darkness senses are on (configured with SD_SENSES): players then see unlit mobs only when close. */
int ms_senses_on(const MobSense *sense);
/* Distance from a point to the nearest lit cell, zero inside light. */
float ms_darkness_at(const MobSense *sense, float x, float z);
float ms_scent_at(const MobSense *sense, int player, float x, float z);

#endif
