# Garden structure reveal audit — 2026-11-10

The Reclamation Altar existed during its reveal but disappeared afterwards. `stage.gd::update_heart_progress` created all three Heart station models with `visible=false`, including researched ones. The reveal temporarily showed the model while forming, then correctly restored its original visibility—which was incorrectly hidden.

Permanent visibility now follows the host's researched technology (`unlocked.has(id)`). The reveal still conceals/scales pending structures temporarily and restores the committed scene when it ends. Already-unlocked saves recover their models immediately on load; replaying research or cutscenes is unnecessary. No save migration, economy change, extra interaction, research cost or new RPC is introduced. Existing reclamation/research menus remain their service authorities.

| Reveal | Persistent scene source | Audit outcome |
|---|---|---|
| Reclamation Altar (`seed_archive`) | `Stage.HEART_STATIONS` / `heart_visuals.station` | Fixed forced-hidden permanent model |
| Offering Altar (`monster_studies`) | Same station template | Fixed same bug |
| Living Archive (`living_archive`) | Same station template | Fixed same bug |
| Planting beds | Saved researched plot count / `garden_beds` | Existing visible model restored; covered by formation and reload checks |
| Sheltered spring | Layout prerequisites / dedicated `assets/garden/sheltered_spring.tscn` | Replaced generic pond appearance with a dry sealed site that awakens into a root crown, stone source, basin, cascade and pads; entire asset forms together |
| Clearing expansions | Researched clearing level / rebuilt Garden extent | Existing authoritative extent remains; no forced-hidden building |
| Cultivation terrace and conduit | Layout zone prerequisites / terrace view | Persistent zone and researched channels use existing projection; no forced-hidden station flag |
| Return discoveries | Available observation points / return view | Existing point availability owns persistence, not temporary cutscene meshes |

Expanded `tests/garden_growth.gd` covers every station through locked state, actual reveal destination, root-arrival concealment, partial formation, normal completion/acknowledgment, interruption, skipping, subsequent scenery rebuild, Wilds/Garden view change and a new world instance loaded from an isolated saved fixture. It also checks persistent researched beds and spring water after reload. `tests/garden_growth_coop.gd` now checks all three researched models and their reveal restoration on a real guest. Existing Garden/spring/return/presentation suites cover the other reveal families.

The existing scoped `stage.gd` cinematic region and mechanics map were updated together. Validation uses affected suites and matching cached evidence, not a full-suite rerun. The retained pre-cleanup backup remains untouched.

## Spring visual identity correction

The user clarified that the unlocked spring looked like water that already existed on the map. Although the zone prerequisites gated a third pond, its renderer was identical to ordinary Garden ponds, making the reveal unconvincing. The spring now has its own reusable scene and a visual-only configuration adapter (`garden_spring_visuals.gd`). Before research it is a small dry sealed stone/root site, without a basin, water, pads or flow. Research replaces that dormant site with the complete awakened landmark; its `garden_water_position` groups the source, roots, basin and cascade under the existing reveal animation. Generic ambient pools remain separate, and scenery is excluded from the spring site even before unlock.

The authored scene, adapter and flow shader are classified under the existing Garden layout boundary. They use a local cosmetic RNG and the existing motion preference, research prerequisites, interaction point and save/network projections. They add no new watering rule or gameplay authority. Existing unlocked saves show the awakened scene immediately. Tests assert actual scene identity and required basin/cascade children, not only a water-position marker. In-engine preview: `.godot/spring-landmark-preview.png`.

## Verified combined release — 2026-11-10

Connected run `20261110-182434-7d2bf5d9` passed 29 affected suites and reused 69 unchanged results; all 39 planner self-tests passed. Packaged validation passed 27 selected checks with 38 unchanged packaged results reused, plus startup/catalog checks and real host/three-guest connect-and-play checks. Both source and packaged Garden growth/spring host/guest tests passed. The full suite was not run.

Updated only `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.2.exe`; installed SHA256 `363f465d8616a88c9cd2d7c28ca79576aea9f0018bc4f34de71e2f6cf67237ad` matches the tested staged artifact. The prior EXE is backed up by the release tool under `.godot/release/`. Previously researched structures recover automatically on world load. The protected pre-cleanup backup was not accessed.

## Using unlocked landmarks

Walk up to a researched Reclamation Altar, Offering Altar or Living Archive and press the interact key. Reclamation and trophy offerings use their existing costs and rewards. The archive displays the Garden’s guardian-memory record. The Heart’s Garden stories tab is read-only. Press Interact at the Sheltered Spring to fill an empty watering vessel. When the vessel is full, Interact opens the spring observation. At a growing bed, select the Water plant button in the Garden view to use the vessel. The vessel is personal to the current session and a failed watering save leaves it full. The Cultivation Terrace continues to host its observation and conduit controls.
