# Mystical Garden — current systems specification

Updated 2026-11-08. This specification supersedes retired shortcuts, replenishing-harvest wording, affinity bonuses, and plant grafting from older iteration notes.

## Intent
A challenging cooperative fantasy expedition game about nurturing, discovery and sacrifice. The safe, green Garden contrasts with increasingly unsettling eldritch Wilds. Plants produce meaningful weapon components rather than passive collection bonuses. Experienced characters gain more choices without bypassing the host Garden's resource economy. The Heart is an ancient ally whose returning memories make its eventual awakening ambiguous.

## Ownership and lifetimes
| State | Owner | Persistence |
| --- | --- | --- |
| Knowledge, technologies, recipes, planted beds, shared harvests, world adaptation, Heart restoration | Host Garden | Across expeditions |
| Class combat XP, learned class choices, plant and monster familiarity | Individual character | Across hosted sessions |
| Guest seeds and stored parts | Guest reserve within that host Garden | Host-world save; not portable seed transfer |
| Crafted weapon, installed graft, checkpoint purchases, carried loot and currency spending | Character's expedition | Ends on extraction, wipe or abandonment |
| Safe pouch | Character's expedition | Banked on wipe/extraction; lost on abandonment |

Stable string IDs identify content in save manifests. Runtime indices remain an internal compatibility layer. Unknown saved IDs are quarantined rather than converted into Thorn Bloom. Legacy level progression is migrated without removing earned ranks. The save directory remains `Mystical Garden Prototype` to preserve existing saves.

## Cultivation and discovery
Twenty-four authored seed species form tiered parent combinations and Wilds discovery pools. Every species supplies guaranteed ordinary material and a familiarity-scaled chance at a refined material. Tending that species develops personal familiarity. Harvesting empties the bed; once researched, flowering is the alternative mature harvest of two seeds instead of parts, without resetting growth. Base growth is 5/12/25/50/90 minutes by tier, accelerated 2× in the Wilds and by existing Knowledge bonuses. Unlocking the spring adds optional once-per-crop watering for 25% faster growth. Altar discoveries persist as recipes. Failed experiments return the described clue/material outcome. Component templates connect inventory identity, tags, effect values, crafting, refinement and progression eligibility.

## Classes and combat
Five classes currently offer three weapons and two skills each. Three plant slots determine the starting build. A monster-only fourth slot can be filled or replaced at a Wilds shrine; failure consumes the attempt. Checkpoint purchases remain active after replacement. Combat progression uses XP thresholds 0, 5, 15, 35, 70. These are tunable targets, not a validated promise of campaign length.

Attack geometry is shared by hit testing and weapon trails. Melee contact and ranged release are queued within the weapon animation; ranged shots use assisted targeting with limited motion tolerance, not fully simulated projectile collision. Spatial sounds reinforce swings, casts and impacts. Enemy hits and deaths provide reaction effects. Support enemies spawn with allies. Earned monster familiarity and trophy rolls use actual eligible killed species; summoned brood do not create repeatable rewards.

## Expedition schedule and loss
Upgrade spacing (3), extraction spacing (6), biome length (6), and graft interval (8) are independent values. Every third cleared gate offers weighted cards based on class, weapon, plant tags and graft. Equal currency earnings are individually spent. Extraction is available every sixth cleared gate beside the onward gate. Repeated guardian completions in a deep expedition each count when banked. Wipes and extraction advance qualifying research; abandonment does not. Already-awarded character progress remains even when carried loot is forfeited.

## Heart and endings
The host buys permanent research at the Heart between expeditions. Prerequisites and available Knowledge determine purchase eligibility. Selected research unlocks immediately. Contributing unreserved shared materials immediately grants both Growth Energy and Knowledge. Every completed enabled Knowledge technology permanently grows the Heart during its reveal, progressing from a pulsing plant growth through shoots and a sapling to a large tree when available research is completed. This visual progression is independent of the deferred ending. Cultivation Grounds grants a stored bed and unlocks further construction for Growth Energy. The old Pale Root / Lantern Bud / Hollow Seedling choices and concluding Heart encounter are deferred. Their save records and paid research are preserved, but they do not reserve beds, grant sacrifices, alter the Garden or trigger an ending. The final research node is hidden until this end-game direction is redesigned.

## Adaptation and future scope
The host's authored adaptation director remembers tactic pressure and applies visible mutations. It is rules based; there is no neural network or arbitrary learned counter generation. Four-player direct-IP hosting now listens on all interfaces and supports configured IPv4/IPv6 addresses and UDP ports. Reachable internet hosting requires suitable firewall/router access. Game protocol/content checks and duplicate-identity rejection precede gameplay; players join in the Garden. Matchmaking, relay/NAT traversal, host migration, seed-transfer traits, broader class tiers, physical projectiles and long-term economy balancing remain future milestones. Character profiles remain trusted player-supplied progression, not account-authenticated or cheat-proof. Retired affinity values are kept inert for save compatibility and documented for potential future class design.

## Independent character roster
The main menu has three initial character slots, independent of the three Garden/world slots. Character creation selects a name, starting class and appearance using the same appearance renderer as gameplay. A character can start or continue any Garden, or join a host, while retaining personal class XP, learned choices and familiarity. Seeds and materials remain governed by the host world's existing storage rules; character selection does not export them between worlds.

Character files live under saves/characters, with persistent identities. Legacy per-world profiles are copied once by identity while their original files remain intact. Deleting or replacing a Garden affects only its world file. Character and world session leases are separate; a character cannot be used in two sessions at once. A guest claims only its character and returns to the main menu when leaving or disconnecting, without writing to a selected local world. The roster capacity is data-driven and supports expanding beyond its initial three slots.

## Party travel consent
Ready checks are host-authoritative, temporary session state. Garden departure includes every registered connected party member; active-stage travel includes the surviving expedition members. Players must gather and personally confirm, and may withdraw. Changing a prepared build, moving away, or a party membership change invalidates confirmations. Disconnects never automatically launch the remaining player. Nonce-scoped votes cannot be reused on later stages.

The complete party's starting materials and one shortcut payment are validated together and committed through one transaction. Failure restores every loadout and shared resource. Ordinary stage advancement and checkpoint extraction require consensus too. At third-gate upgrade checkpoints, upgrade/skip choices are resolved first; each player then confirms travel separately. The deferred Heart finale is not an active travel option. Solo play retains direct entry and its existing post-card continuation.

## Combat pressure and persistent learning
The combat director owns encounter size, co-op health scaling, safer spawn separation, group alerts, stable threat targeting, predictive ranged aiming and varied melee approaches. Counts rise with global expedition depth and cap at twelve scouts plus the leader in solo and twenty scouts plus the leader in co-op. The initial solo floor starts with six scouts; each extra player adds four (up to four players total), with health scaling from 30% extra toward 60% deeper in a run. Health budgets are fixed when the encounter is created and replicated from the host. Baseline damage stays in half-heart increments; brief hit grace prevents a simultaneous pack from removing many hearts in one instant.

The actual naturally killed species and its mutation tags determine eligible monster loot. Every living expedition member receives equal essence and fractional class XP per natural kill, plus an independent personal part roll for that dead species: 4% base with small depth/adaptation bonuses and a leader-only guardian bonus, capped at 15%. Parts appear as owner-only ground pickups. There is no group monster-part roll; summoned brood grant no kill rewards. Seeds retain their existing acquisition loop.

Every successfully settled encounter updates the host's saved memory of repeatedly effective ranged, burst, choke and moving-ranged tactics. Evidence grows more quickly deeper in the Wilds. Quiet encounters slowly reduce active pressure but retain learned history. Mutation counts are capped by expedition depth; the opening is protected, counters remain authored and readable, and independent world variation appears after enough encounters even with varied tactics. This supplements the existing saved expedition pressure. It is not a neural model or invention of arbitrary enemy abilities.


## Expedition death and revival
Fallen characters remain in the Wilds while allies survive, spectating a living teammate. A nearby teammate may revive them by sacrificing one of the fallen character's maximum hearts (two health) for the rest of the expedition. The penalty is cumulative, represented by the permanently lost heart texture, and cannot consume the last full heart. Return to the Garden restores this capacity. A full party wipe ends the run; only the safe pouch survives. Fallen players do not block party gates and can be revived on later floors, but extract with only protected loot if still fallen. Monster-component pickups use a blue world glow and blue explored-map markers, while seed loot keeps its gold markers.


## Expanded botanical and class progression
The current roster has 24 seed species and five seven-level classes, each with 12 learned choices and two specialization directions. Frostbell was verified end-to-end before the remaining plants; Warden behavior and co-op upgrades were verified before extending the other classes. New plant identities include brittle/shatter, marks, echo/redirection, bracing, death charges, cleansing pools, interruption, decoys and bounded links. The altar has a remembered-recipe selector; all new lineages have portrait nodes. See docs/CONTENT_DEPTH_2026-11-08.md for the implemented roster, materials and validation gates.
