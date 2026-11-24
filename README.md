# Mystical Garden — current playable build

Use **Play Mystical Garden.cmd** to launch the highest numbered EXE in this folder. The launcher and release tool compare numeric revisions; they do not rename milestones or update older builds. To edit, open project.godot in Godot 4.7.2.

Choose a character and a Garden independently. New Garden creates a world, Continue opens a saved Garden with the chosen character, and Join by IP takes that character to a host. Replacing or deleting a Garden preserves the roster. Release builds use dedicated guarded storage, and numbered playtests use their own version-specific folders. Automatic migration from older save roots is disabled.

Hosting supports up to three guests. For LAN play, share the host’s LAN IP from the session menu. For internet play, allow the EXE through the host firewall, forward the chosen UDP port (default 24576), and share the host’s public IP. [Direct-IP setup](docs/ONLINE_COOP.md)

Move with WASD, attack with the mouse, use Q and R for class skills, and open inventory with I. F1 shows current controls. Use E near the Heart, Altar, a plant bed, or the Wilds Gate to open the relevant menu. Character abilities are hidden in the Garden.

At the Heart, select class choices and research Garden technologies and planting-bed expansions in the Knowledge tree. Research previews its Knowledge cost and optional plant offerings; choose a species if you want to protect other materials. At the Altar, identify seeds or combine two ingredients. Known combinations show their result; unknown combinations show a question mark and offer discovery clues. Plant beds open an available-seed picker. Harvesting empties the bed; flowering trades useful parts for seeds.

At the Wilds Gate, prepare a class weapon and equip plant parts in the Core, Form and Catalyst slots. Your class-tree choices and equipment stay fixed during the expedition. At grafting shrines, spend a compatible carried trophy to buy a reinforcement or a unique adaptation. Accepted purchases accumulate for that expedition.

Wilds expeditions continue through procedurally generated encounters. Interact with every third cleared gate for a free choice of up to three distinct, usable cards. Rerolls cost expedition Essence. Every sixth cleared gate offers extraction. Biome guardians occur every sixth encounter and grafting shrines every eighth. A wipe preserves the safe pouch. Voluntarily abandoning the expedition forfeits that run’s Class XP, monster familiarity and carried loot, including the safe pouch. Items already delivered to Garden storage through a discovered Returning Root stay there.

The backpack scrolls and has no ordinary stack-count limit. One safe-pouch slot protects one stack of up to 99 items. Hidden seeds retain their individual species even when stacked. These are current explicit rules, not promises of a 40-slot capacity.

See [current systems specification](DESIGN_BRIEF.md), [content authoring](docs/CONTENT_AUTHORING.md), and [review corrections and validation](docs/FOUNDATION_MILESTONE_2026-11-08.md). The original systems review is retained as historical evidence, not current instructions.

In co-op, each player confirms readiness at the Wilds gate before the party departs. Cleared onward gates and checkpoint extraction also require everyone's confirmation. The ready HUD shows who is waiting and lets you unready. Moving away or changing your prepared loadout clears your confirmation. Third-gate card choices are separate from the final travel confirmation. Solo travel keeps its existing flow.

Wilds balance now scales with total expedition depth and party size, including larger mixed packs. Enemies share local alerts, spread attention between players, approach from different angles and lead moving targets when committing ranged attacks. Telegraphs lock before impact; clustered hits have brief protection. Monster trophies use one probabilistic roll per player's cleared encounter rather than an every-third-stage guarantee. The host's mycelium remembers repeated ranged, burst, choke and moving-shot victories across saved sessions, with visible mutation budgets and gradual independent variation. This is an adaptive rules system; see [combat tuning](docs/COMBAT_BALANCE_2026-11-08.md).

Network connect-and-play smoke tests: see [test/README.md](test/README.md). The supplied bundle now supports isolated one-to-three-guest runs, mixed frame rates, exported-pack checks, separate Host/Guest launchers, and machine-readable reports.
