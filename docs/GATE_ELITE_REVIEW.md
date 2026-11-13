# Gate elite diversity — 2026-11-10

The leader at the onward gate was always species 0 (Rootbound Pilgrim), and the leader controller used one generic melee attack. Replaced both in mechanics dependency order: eligible content → deterministic encounter choice → shared species behavior → empowered sequence → warnings/model growth → network/loot regression checks.

## Selection

`elite_enemy.gd` selects from normal species by biome and unlock floor. It excludes rare bosses, all support-flagged species, chanters/shepherds, and the Lantern Lure (not a self-sufficient solo threat). Fifteen species are available across the full progression. Early floors draw from the smaller unlocked pool. A new encounter avoids the previous elite when alternatives exist; resetting the same seeded encounter retains its choice. Selection uses a separate deterministic RNG and does not alter loot RNG. Rare boss scheduling and the deferred Heart finale remain separate.

## Empowered species

| Species | Elite behavior |
|---|---|
| Rootbound Pilgrim | Two committed swipes |
| Nightbloom | Three telegraphed salvos |
| Gallhorn Stag | Swept charge plus delayed root trail |
| Thornmaw Hound | Two telegraphed pounces |
| Mourning Willow | Repeated entanglement attacks |
| Carrion Orchid | Three-part bombardment |
| Gravebud Colossus | Repeated stomp/aftershock sequence |
| Wicker Wasp | Flanking movement and two-contact sequence |
| Mycelial Broodmother | Two-child waves; maximum four living elite children, replenishable after deaths |
| Hollowback Grazer | Stomp/aftershock sequence and retained ally-protection aura |
| Seamroot Burrower | Native raking charge plus delayed web trail |
| Spore Widow | Repeated native web lines; each pending web point has its own warning |
| Graft Thief | Flanking sequence and native trophy theft/flight; stolen loot returns on death |
| Ashen Hart | Native burning charge and delayed dangerous trail |
| Glasscap Watcher | Native false silhouettes and three salvos |

Each follow-up has its own wind-up and recovery. Elites use ordinary species damage/resolution hooks rather than a separate reward/damage system. Movement, roots, stagger, adaptive mutations and support-granted haste remain applicable. Summons still use existing capacity limits and summoned-loot/XP exclusion rules. Standard leader durability scaling is retained.

## Appearance and readability

The existing scale differences remain, but no new enlargement is used to define elites. Runtime decorations add connected root ribs/horn forks, or swollen casting/brood sacs for the relevant families. Decorations are cached per imported model and excluded from rare boss/finale forms. Labels name the actual species and empowered attack family rather than substituting an unrelated fixed biome-guardian name. Longlimb remains an optional learned adaptation, not the identity of every elite.

Ordinary elites use synchronized attack hints from their actual move, including charge corridors, pounce destinations, salvo/snare impact positions and web points. Removed the old extra caster-centered ring for these elites. Burrower and Ashen Hart charge warnings use the native swept widths/landing radii. Delayed hazards retain their existing activation warnings.

## Verification

`gate_elites.gd` covers every eligible species, biome/unlock restrictions, deterministic selection, no immediate species repetition, same-floor identity, native move modes, extended sequences, telegraphs, four-child brood cap/replenishment, retained Grazer protection and Thief loot recovery, and cached model growth. `gate_elites_coop.gd` checks real host/guest species models, warnings and summoned brood. Existing enemy/monster-reward/combat tests passed during implementation.

The old playable smoke assumed that every floor's leader would be the same Pilgrim and therefore would receive the same mutation roll. Its adaptation assertions now inspect availability of the learned counter across the varied pool; the wider-hit-area fixture explicitly isolates Longlimb. The complete solo sequence passes. Production selection is not special-cased for tests.

No save format or protocol layout changed. Final source/package results are appended after export.
Release verification: 79 source suites passed with stable inputs and complete release evidence. All 46 selected packaged suites, startup/catalog checks and the four-player connection smoke passed. Installed only Mystical Garden v0.5.2.0.exe; previous copy was backed up. Installed SHA256 matches the verified package: 8B7A91812B236ADE97D3F80A4DAC1F643FFDE2BA6625654A5DC0E4A893CC6E2A. Source fingerprint: BD3AE02628F2F04EDC10E9A03BC5744A0859A6F4554082AA66DDF7ED0DAB38F8.
