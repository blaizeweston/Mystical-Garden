# Learned player party: plan (draft, 2026-11-28)

The mob net is the product. The player net is its sparring partner: it should be good, varied, and play by
exactly the rules the scripted party plays by. Nothing here changes mob training until stage 2.

## Stages

| Stage | What trains | Opponent | Ends when |
|---|---|---|---|
| 0 (now) | mobs | scripted party, hunting (`episodes.party_hunt`) | mob benchmark edge flat for about 3 milestones (6 h) |
| 1 (build, in parallel) | nothing new | none | the player side passes its checks and a short proof run |
| 2 | players only; mobs frozen at their best milestone | a pool of mob checkpoints plus scripted mobs | the learned party beats the scripted party against the best mob brain on the player benchmark, for 2 milestones |
| 3 | both at once | each side plays a pool: about 50% the other side's latest, 30% its older checkpoints, 20% scripted | ongoing; roll back a side whose benchmark against scripted falls |

The mob benchmark against the scripted party stays the mob yardstick in every stage, so forgetting shows up.

## Stage 1 work

1. **Shared party mechanics.** Split `ai/stand_in_party.gd` into the mechanics (movement and routing, attacks,
   dodges, guard, heal, root, bark, hits taken, lights) and the scripted tactics (targets, goals, hunting). The
   scripted party keeps playing the same way; checks show identical fights before and after the split.
2. **Player observation** (`ai/player_schema.json`, new). It mirrors the mob layout so matching inputs keep their
   meaning:
   - self: class stats, health, weapon, dodge and skill cooldowns, guard and bark state, status;
   - enemy block = mobs: 8 slots (nearest known, weighted by threat), with the mob block's fields where they apply
     (species role, winding up, aim on me, health), plus a summary: mobs known, mobs remembered but unseen,
     supports known, and the party's last lead;
   - ally block = party mates: 3 slots;
   - context: walls, cover, mob telegraph areas (as hazards), light.
3. **Player actions.**
   - behaviour: attack target, close in, keep range, retreat, dodge, class skill, regroup, hunt the last lead,
     search or patrol;
   - enemy_target: one of the mob slots;
   - manoeuvre: direction for dodges and keeping range.

   Each class's kit is masked, as species are for mobs.
4. **Player executor** (`ai/player_executor.gd`, new). It turns intents into the shared mechanics from step 1.
5. **Player rewards** (`rewards.json` player_bot, which exists).
   - It already has: damage taken -1 per bar, downed -3, wipe -10, mob killed +0.05 per value, team mix 0.8.
   - Proposed: add damage dealt, raise kills, add a clear bonus, and keep timeouts neutral.

   These weights need your approval.
6. **Trainer: two policies.** Separate networks, optimizers, KL controllers, critics, checkpoints and dashboard
   series. Shards are tagged by side, and workers play learned party against frozen mob pools.
7. **Seeding** (`seed_player_net.py`, new). It copies the mob trunk's weights for the inputs that match; new
   inputs start at zero and the heads start fresh, so players begin knowing how to move and use cover.
8. **Player benchmark.** The learned party against fixed mob brains (scripted mobs and the best milestone),
   compared with the scripted party on the same 600 frozen fights.

## Decisions for you

- How many mob slots players see: 8 is my recommendation (parties face 4-16 mobs).
- The player reward weights in step 5.
- Whether the player net could ever run in the game, for example as companions. If so, the quality bar rises
  and its inputs must be things the game can provide.

## Order and size

Steps 1, 2, 3 and 4 come first and are the largest part. Then 5 and 7, then 6, then 8 and a short proof run.
Several sessions of work in all. Stage 1 never touches the live mob run; only stage 2 changes what PC2 trains.
