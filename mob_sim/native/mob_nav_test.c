/* Engine-free checks for the navigation core. Exits nonzero on the first summary failure. */
#include "mob_nav.h"
#include "mob_policy.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define W 80
#define H 60

static int failures = 0;

static void check(int condition, const char *name) {
    printf("%s %s\n", condition ? "PASS" : "FAIL", name);
    if (!condition) failures++;
}

/* A 40 x 30 unit room with a margin, split by a wall that has one gap near z = 12. */
static MobNav *make_room(int agents, int targets) {
    static uint8_t mask[W * H];
    memset(mask, 0, sizeof(mask));
    for (int z = 4; z < H - 4; z++) {
        for (int x = 4; x < W - 4; x++) mask[x + z * W] = 1;
    }
    const float rects[] = {19.5f, 0.0f, 20.5f, 10.0f, 19.5f, 14.0f, 20.5f, 30.0f};
    MobNav *nav = mn_create(agents, targets);
    if (nav == NULL || mn_bake(nav, W, H, 0.0f, 0.0f, mask, rects, 2) != MN_OK) {
        printf("FAIL room setup\n");
        exit(2);
    }
    return nav;
}

static void test_clearance(void) {
    MobNav *nav = make_room(1, 1);
    check(fabsf(mn_clearance(nav, 10.0f, 12.0f) - 6.0f) < 0.05f, "clearance is capped in open floor");
    check(fabsf(mn_clearance(nav, 18.5f, 5.0f) - 1.0f) < 0.05f, "clearance measures distance to a barrier");
    check(mn_clearance(nav, 20.0f, 5.0f) < 0.0f, "clearance is negative inside a barrier");
    check(fabsf(mn_clearance(nav, 3.0f, 12.0f) - 1.0f) < 0.05f, "clearance measures distance to the floor edge");
    check(mn_clearance(nav, 1.0f, 12.0f) < 0.0f, "clearance is negative outside the floor");
    mn_destroy(nav);
}

static void test_line_of_sight(void) {
    MobNav *nav = make_room(1, 1);
    check(mn_line_clear(nav, 5.0f, 5.0f, 15.0f, 25.0f, 0.34f), "open floor is clear");
    check(!mn_line_clear(nav, 15.0f, 5.0f, 25.0f, 5.0f, 0.0f), "the wall blocks a line");
    check(mn_line_clear(nav, 15.0f, 12.0f, 25.0f, 12.0f, 0.34f), "the gap admits a line");
    check(!mn_line_clear(nav, 15.0f, 12.0f, 25.0f, 12.0f, 2.5f), "a wide body does not fit the gap");
    mn_destroy(nav);
}

static void test_flow_field(void) {
    MobNav *nav = make_room(1, 1);
    const float target[] = {30.0f, 5.0f};
    mn_set_targets(nav, target, 1);
    const float agent[MN_AGENT_STRIDE] = {1, 10, 5, 3, 0.34f, 0.5f, 0, MN_MODE_SEEK, 0, 0};
    mn_agents_load(nav, agent, 1);
    mn_tick(nav, 1.0f / 60.0f);
    float cost = mn_path_cost(nav, 0, 10.0f, 5.0f);
    check(cost > 23.0f, "the route cost goes around the wall");
    float xz[2];
    int arrived = 0, clipped = 0;
    for (int i = 0; i < 1500 && !arrived; i++) {
        mn_tick(nav, 1.0f / 60.0f);
        mn_positions(nav, xz);
        clipped += mn_clearance(nav, xz[0], xz[1]) < 0.34f;
        arrived = hypotf(xz[0] - 30.0f, xz[1] - 5.0f) <= 0.55f;
    }
    check(clipped == 0, "the agent never clips a wall");
    check(arrived, "an agent walks through the gap to its target");
    mn_destroy(nav);
}

static uint64_t crowd_hash(void) {
    MobNav *nav = make_room(100, 2);
    const float targets[] = {30.0f, 5.0f, 30.0f, 25.0f};
    mn_set_targets(nav, targets, 2);
    float rows[100 * MN_AGENT_STRIDE];
    for (int i = 0; i < 100; i++) {
        float *row = rows + i * MN_AGENT_STRIDE;
        row[0] = 1;
        row[1] = 4.0f + (float)(i % 10) * 1.3f;
        row[2] = 4.0f + (float)(i / 10) * 2.1f;
        row[3] = 2.5f;
        row[4] = 0.34f;
        row[5] = 3.0f;
        row[6] = MN_TARGET_NEAREST;
        row[7] = MN_MODE_SEEK;
        row[8] = 0;
        row[9] = 0;
    }
    mn_agents_load(nav, rows, 100);
    float xz[200];
    int clipped = 0;
    for (int t = 0; t < 1800; t++) {
        mn_tick(nav, 1.0f / 60.0f);
        mn_positions(nav, xz);
        for (int i = 0; i < 100; i++) clipped += mn_clearance(nav, xz[i * 2], xz[i * 2 + 1]) < 0.34f;
    }
    check(clipped == 0, "a crowd of 100 never clips a wall");
    int crossed = 0;
    for (int i = 0; i < 100; i++) crossed += xz[i * 2] > 20.5f;
    check(crossed >= 95, "a crowd of 100 passes through a single gap");
    uint64_t hash = mn_state_hash(nav);
    mn_destroy(nav);
    return hash;
}

static void run_ticks(MobNav *nav, int ticks, int *clipped) {
    float xz[2];
    for (int i = 0; i < ticks; i++) {
        mn_tick(nav, 1.0f / 60.0f);
        mn_positions(nav, xz);
        *clipped += mn_clearance(nav, xz[0], xz[1]) < 0.34f;
    }
}

static void test_modes(void) {
    MobNav *nav = make_room(1, 1);
    const float target[] = {10.0f, 20.0f};
    mn_set_targets(nav, target, 1);
    const float agent[MN_AGENT_STRIDE] = {1, 5, 20, 3, 0.34f, 0.2f, 0, MN_MODE_SEEK, 3.0f, 0.0f};
    mn_agents_load(nav, agent, 1);
    int clipped = 0;
    float xz[2], held[2];
    run_ticks(nav, 400, &clipped);
    mn_positions(nav, xz);
    check(hypotf(xz[0] - 13.0f, xz[1] - 20.0f) <= 0.25f, "an offset goal stops beside the target");

    const float hold[MN_COMMAND_STRIDE] = {1, 3, 0.2f, 0, MN_MODE_HOLD, 0, 0};
    mn_agents_command(nav, hold, 1);
    mn_positions(nav, held);
    run_ticks(nav, 60, &clipped);
    mn_positions(nav, xz);
    check(xz[0] == held[0] && xz[1] == held[1], "a hold command keeps the agent still");

    const float inactive[MN_COMMAND_STRIDE] = {0, 3, 0.2f, 0, MN_MODE_SEEK, 0, 0};
    mn_agents_command(nav, inactive, 1);
    run_ticks(nav, 60, &clipped);
    mn_positions(nav, xz);
    check(xz[0] == held[0] && xz[1] == held[1], "an inactive slot does not move");

    float before = mn_path_cost(nav, 0, held[0], held[1]);
    const float flee[MN_COMMAND_STRIDE] = {1, 3, 0.2f, 0, MN_MODE_FLEE, 0, 0};
    mn_agents_command(nav, flee, 1);
    run_ticks(nav, 180, &clipped);
    mn_positions(nav, xz);
    check(mn_path_cost(nav, 0, xz[0], xz[1]) > before + 4.0f, "a flee command increases the route to the target");

    const float direct[MN_COMMAND_STRIDE] = {1, 3, 0.1f, 0, MN_MODE_DIRECT, 8.0f, 8.0f};
    mn_agents_command(nav, direct, 1);
    run_ticks(nav, 600, &clipped);
    mn_positions(nav, xz);
    check(hypotf(xz[0] - 8.0f, xz[1] - 8.0f) <= 0.15f, "a direct command walks to an absolute point");
    check(clipped == 0, "mode changes never clip a wall");
    mn_destroy(nav);
}

static void test_batches(void) {
    MobNav *nav = make_room(4, 1);
    float rows[4 * MN_AGENT_STRIDE] = {0};
    mn_agents_load(nav, rows, 4);
    const float places[] = {0, 10, 12, 0.34f, 1, 1, 12, 12, 0.34f, 1, 2, 11, 12, 0.34f, 1, 3, 11, 12, 0.34f, 0};
    check(mn_agents_place(nav, places, 4) == MN_OK, "agents can be placed by slot");
    const float bad_place[] = {9, 10, 12, 0.34f, 1};
    check(mn_agents_place(nav, bad_place, 1) == MN_ERR_ARGUMENT, "placing outside the pool is refused");

    const float slots[] = {0, 3};
    float nearest[6];
    check(mn_nearest_batch(nav, slots, 2, 5.0f, 3, nearest) == MN_OK, "nearest queries run");
    check(nearest[0] == 2.0f && nearest[1] == 1.0f && nearest[2] == -1.0f, "nearest lists active neighbours closest first");
    check(nearest[3] == -1.0f, "an inactive slot has no neighbours");

    const float queries[] = {15, 5, 25, 5, 0, 15, 12, 25, 12, 0.34f};
    uint8_t seen[2];
    mn_line_clear_batch(nav, queries, 2, seen);
    check(seen[0] == 0 && seen[1] == 1, "sight batches match single queries");

    const float dash[] = {1, 30, 5};
    const float start[] = {1, 18, 5, 0.34f, 1};
    mn_agents_place(nav, start, 1);
    check(mn_agents_displace(nav, dash, 1) == MN_OK, "displacement runs");
    float xz[8];
    mn_positions(nav, xz);
    check(xz[2] < 19.5f - 0.34f && xz[2] > 18.5f, "a dash stops at the first wall");

    const float ray_slot[] = {0};
    const float placed[] = {0, 17, 5, 0.34f, 1};
    mn_agents_place(nav, placed, 1);
    float rays[MN_WALL_RAYS];
    check(mn_wall_rays(nav, ray_slot, 1, 12.0f, rays) == MN_OK, "wall rays run");
    check(fabsf(rays[0] - 2.5f) < 0.15f, "a wall ray measures the distance to a barrier");
    check(rays[4] == 12.0f, "an open wall ray is capped at its range");
    mn_destroy(nav);
}

static void test_policy_refusals(void) {
    char hash[MP_HASH_LENGTH + 1];
    memset(hash, 'a', MP_HASH_LENGTH);
    hash[MP_HASH_LENGTH] = 0;
    MobPolicyLayout layout = {.observation_size = 10, .self_range_count = 1, .self_size = {4}, .enemy_offset = 4, .enemy_stride = 1,
                              .enemy_repeat = 1, .ally_offset = 5, .ally_stride = 1, .ally_repeat = 1, .leader_offset = 6,
                              .leader_stride = 1, .logits = 4, .hidden = 2, .capacity = 1};
    uint8_t file[128] = {'M', 'O', 'B', 'W', 1, 0, 0, 0};
    memset(file + 8, 'b', MP_HASH_LENGTH);
    MobPolicy *policy = NULL;
    check(mp_load(file, sizeof(file), hash, &layout, &policy) == MP_ERR_SCHEMA && policy == NULL, "a model for another schema is refused");
    memset(file + 8, 'a', MP_HASH_LENGTH);
    check(mp_load(file, 20, hash, &layout, &policy) == MP_ERR_FILE, "a truncated model is refused");
    check(mp_load(file, sizeof(file), hash, &layout, &policy) == MP_ERR_FILE, "a model with no tensors is refused");
    file[0] = 'X';
    check(mp_load(file, sizeof(file), hash, &layout, &policy) == MP_ERR_FILE, "an unknown file format is refused");
}

static void test_bad_input(void) {
    MobNav *nav = make_room(1, 1);
    const float bad_target[] = {NAN, 1.0f};
    check(mn_set_targets(nav, bad_target, 1) == MN_ERR_ARGUMENT, "non-finite targets are refused");
    const float bad_agent[MN_AGENT_STRIDE] = {1, 10, 5, 3, 0.34f, 0.5f, 0, 9, 0, 0};
    check(mn_agents_load(nav, bad_agent, 1) == MN_ERR_ARGUMENT, "unknown modes are refused");
    check(mn_agents_load(nav, bad_agent, 2) == MN_ERR_ARGUMENT, "agent overflow is refused");
    check(mn_tick(nav, -1.0f) == MN_ERR_ARGUMENT, "negative time steps are refused");
    mn_destroy(nav);
}

int main(void) {
    test_clearance();
    test_line_of_sight();
    test_flow_field();
    uint64_t first = crowd_hash();
    uint64_t second = crowd_hash();
    check(first == second, "identical runs produce identical state hashes");
    test_modes();
    test_batches();
    test_policy_refusals();
    test_bad_input();
    printf("%s: %d failure(s)\n", failures ? "FAILED" : "PASSED", failures);
    return failures ? 1 : 0;
}
