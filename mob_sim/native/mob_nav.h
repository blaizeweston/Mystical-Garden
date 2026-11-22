#ifndef MOB_NAV_H
#define MOB_NAV_H
/* Engine-free mob navigation core: baked clearance, shared flow fields,
 * line-of-sight queries and crowd locomotion. All state lives in fixed slots
 * and a tick is deterministic for identical inputs. */

#include <stddef.h>
#include <stdint.h>

#define MN_FLOOR_CELL 0.5f
#define MN_TARGET_NEAREST (-1)

/* active, x, z, speed, radius, stop, target, mode, offset_x, offset_z */
#define MN_AGENT_STRIDE 10
/* active, speed, stop, target, mode, offset_x, offset_z */
#define MN_COMMAND_STRIDE 7
/* slot, x, z, radius, active */
#define MN_PLACE_STRIDE 5
/* slot, x, z */
#define MN_DISPLACE_STRIDE 3
/* x0, z0, x1, z1, radius */
#define MN_SIGHT_STRIDE 5
#define MN_NEAREST_MAX 16
#define MN_WALL_RAYS 8

typedef enum {
    MN_OK = 0,
    MN_ERR_ARGUMENT = 1,
    MN_ERR_MEMORY = 2,
    MN_ERR_STATE = 3
} MnResult;

typedef enum {
    MN_MODE_HOLD = 0,
    MN_MODE_SEEK = 1,
    MN_MODE_FLEE = 2,
    /* Walks straight to the absolute point stored in offset_x, offset_z. */
    MN_MODE_DIRECT = 3
} MnMode;

typedef struct MobNav MobNav;

MobNav *mn_create(int max_agents, int max_targets);
void mn_destroy(MobNav *nav);

/* floor_mask holds floor_w * floor_h bytes at MN_FLOOR_CELL resolution, nonzero
 * for walkable floor. rects holds rect_count entries of x0, z0, x1, z1. */
MnResult mn_bake(MobNav *nav, int floor_w, int floor_h, float origin_x, float origin_z,
                 const uint8_t *floor_mask, const float *rects, int rect_count);

/* Bakes the air layer from a second floor mask of the same size, sharing the barriers. Flying agents step,
 * route and displace on it while staying in the shared crowd for neighbour queries. A NULL mask removes it.
 * Rebaking the ground removes it too. */
MnResult mn_bake_air(MobNav *nav, const uint8_t *air_mask, int64_t length);
/* Lazy fields: a route field is solved only while an agent of its layer seeks or flees with it, and the
 * solve stops a margin beyond the farthest such agent. It is solved again when one of them nears that
 * edge. Off by default, which keeps every field complete for mn_path_cost at any point. */
MnResult mn_set_lazy_fields(MobNav *nav, int enabled);
/* One byte per agent slot: 0 walks on the ground layer, 1 flies on the air layer. */
MnResult mn_set_layers(MobNav *nav, const uint8_t *layers, int count);

MnResult mn_set_targets(MobNav *nav, const float *xz, int count);
MnResult mn_agents_load(MobNav *nav, const float *data, int count);
MnResult mn_agents_command(MobNav *nav, const float *data, int count);
/* Puts agents at exact positions, for spawning. */
MnResult mn_agents_place(MobNav *nav, const float *data, int count);
/* Sweeps agents toward a point and stops them at the first wall, for dashes and pulls. */
MnResult mn_agents_displace(MobNav *nav, const float *data, int count);
MnResult mn_tick(MobNav *nav, float dt);

/* Writes one byte per query. */
void mn_line_clear_batch(const MobNav *nav, const float *queries, int count, uint8_t *out);
/* Sight lines: like mn_line_clear, but on the air layer when one is baked, so sight crosses water and low
 * obstacles and only tall cover blocks it, as in the game's combat sight. */
int mn_sight_clear(const MobNav *nav, float x0, float z0, float x1, float z1, float radius);
void mn_sight_clear_batch(const MobNav *nav, const float *queries, int count, uint8_t *out);
/* Writes k slots per query, nearest first, padded with -1. Ties resolve by slot. */
MnResult mn_nearest_batch(MobNav *nav, const float *slots, int count, float radius, int k, float *out);
/* Writes MN_WALL_RAYS distances per slot to the first blocked point, capped at max_distance. */
MnResult mn_wall_rays(const MobNav *nav, const float *slots, int count, float max_distance, float *out);

int mn_agent_count(const MobNav *nav);
void mn_positions(const MobNav *nav, float *out_xz);

int mn_line_clear(const MobNav *nav, float x0, float z0, float x1, float z1, float radius);
float mn_clearance(const MobNav *nav, float x, float z);
/* Clearance on the air layer, or on the ground when no air layer is baked. */
float mn_air_clearance(const MobNav *nav, float x, float z);
/* Remaining route length from a point to a target, or a negative value when unreachable. */
float mn_path_cost(const MobNav *nav, int target, float x, float z);

uint64_t mn_state_hash(const MobNav *nav);
uint64_t mn_field_solves(const MobNav *nav);

#endif
