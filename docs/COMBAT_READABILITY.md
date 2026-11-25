# Wilds combat readability and hit geometry

Attack phases now advance locally between 20 Hz movement snapshots instead of holding a pose until the next packet. Anticipation, contact and recovery have a smoother envelope; upper-body attacks blend over locomotion. Ability casts receive their own short pose, and ordinary strikes can take priority without changing attack speed or skill cooldowns.

Six reusable visual families distinguish guarding, restoration, control roots, movement, directed casts and area bursts. Events carry the resolved ability name. Legacy generic rings are suppressed for these event-driven casts. Hostile lanes use stronger contrast and a closing progress arc where the existing wind-up deadline is available. Projectiles stay bright during flight; non-piercing cursor shots explicitly end their visual on contact. Piercing/chain target counts retain their existing rules.

Confirmed contacts emit actual applied HP loss, with capped overkill and mitigation already accounted for. Outgoing damage uses warm ivory, incoming damage uses coral and a minus sign, and blocked hits have a separate gold BLOCK label. Short whole-model flashes accompany contact. Text has an outline and an elevated camera-facing position; fog-distance checks prevent revealing unseen contacts. There is no global hit-stop, camera shake or simulation slowdown.

All 24 enemy entries now have a reusable `hitbox` object with `shape: body_circle`, `radius` and `projectile_padding`. These are 2.5D body footprints, not triangle-accurate collisions on decorative tendrils or antlers. The shared enemy_hurtbox service applies the same leader/boss, juvenile and growth scale as the renderer. Melee contact selection and both projectile paths use it. Melee sectors, thrust lanes and area patterns intersect the whole footprint, including a visible flank beyond the center-angle cutoff. Each profile is checked against the actual EnemyCore mesh bounds; the Matriarch required a substantially larger footprint than its old 1.1 radius. Swept segment tests return the first body-edge contact and check terrain both before contact and between the edge and body center; a fast projectile cannot tunnel through a body or hit through cover. New species can copy this object, with a conservative fallback for older definitions.

Damage feedback is part of the existing reliable combat-event stream and the snapshot fallback. IDs deduplicate both delivery paths. Transactional events publish only after commit; failed saves restore damage and its pending events together. Detailed diagnostic tracing records presentation-event IDs, endpoints, target identity and applied amounts; normal logs avoid this per-hit traffic.

Cosmetic work is bounded: 80 effects, 40 text labels, short-lived flashes with original material overlays restored, a capped seen-event history, and cleanup on floor changes. Sound is stopped and released on scene transitions. Attack, damage, movement, save formats and the existing network RPC signatures remain authoritative and compatible; use the updated EXE on all co-op machines.

New tests cover every scaled species footprint, swept edge hits/misses, cover, frontmost contact, visual projectile termination, exact damage amounts, blocked hits, duplicate network delivery, fog, ability families, render-clock phase continuity, cleanup and save rollback. A real host/guest suite checks committed feedback and ability labels. `combat-readability-preview.png` is a posed rendering check rather than a gameplay capture.

## Contact prototypes and visual review

In Settings, open the Developer Garden and enter the Testing Arena. Open the Workbench with F4 or controller Start and select **Tuning → Visuals**. Choose melee contact, projectile contact or Brittle rupture. Use one reference target, a three-target cluster or a six-target ring. Play, pause or step the preview in increments of 1/60 s. Choose a parameter under **Tune** to keep its controls near the preview. Search and Modified only can display multiple matching controls. Switching between Production baseline and Experimental preserves the current time, orientation and cosmetic seed. Repeat reuses the fixture. An edit applies on the next replay. The equipped-skill option retains the existing class-cue replay in the scene. Presets and review exports use the ordinary Workbench controls.

The production Rootblade contact scatters six warm splinters off the struck surface and briefly highlights the body at 32% strength. Projectiles use a narrower fan. Three small glint fragments mark the onset. Brittle rupture ejects nine faceted shards, three glint fragments and four pale dust flecks from the victim. The three-stack owner determines the rupture. Each victim still receives its own damage number. Only the first nearby rupture label appears in a 200 ms window by default. The large opening or closing footprint of Rime Bloom remains visible independently of these shards.

| Control | Weapon impact default (range) | Brittle rupture default (range) |
|---|---|---|
| Splinters / shards | 6 (2–14) | 9 (3–18) |
| Size | 1× (0.45–2×) | 1× (0.45–1.8×) |
| Initial velocity | 3.8 m/s (1–7) | 3 m/s (0.8–6) |
| Lifetime | 0.19 s (0.08–0.40) | 0.34 s (0.14–0.50) |
| Flash strength | 0.32 (0–1), glint and body highlight | 0.70 (0–1.5), localized glint |
| Tint hue | 39° (0–360°) | 195° (0–360°) |
| Additional controls | Impact emission 0.65 (0–4×) | Show every nearby rupture label, off or on, live combat |

All geometry and facet motion were authored procedurally in this project. The two effects share the splinter primitive and shader. They use no external artwork, particle textures or dynamic lights. Each burst uses one draw surface. The production impact submits 54 triangles and the rupture submits 96. The color picker sets hue directly and preserves the material's saturation and value.

For live review, load **Sustained damage**, select the Rootblade or Vine Bow through Build, close the Workbench and strike the target. Equip Frostbell in Core, spawn three stationary targets in a cluster and cast Rime Bloom toward their center. Evaluate the target silhouettes, hostile warning edges and timing at normal zoom. The neutral preview provides a frame-matched comparison for one, three or six simultaneous effects. A rendered frame-time sample on a capped system measures the experienced cadence. It cannot establish GPU headroom.

### Rendered prototype measurements

Godot 4.7.2, GL Compatibility, RTX 5080, 1100 × 720, VSync on and 120 FPS limit. Each sample ran for 6.5 s after setup. The ordinary single-target attack measured 8.75 ms p95 and three targets with Ember Wake and basic attacks measured 8.83 ms p95. VFX01 recorded 8.77 and 8.84 ms respectively. The new runs included occasional 26–27 ms frames. Whole-process draw calls on the final sample frames were 1,022 and 1,050, compared with 750 and 790 in VFX01. These include the parked Garden, arena, other effects and interface. A separate same-scene check found the hidden lab viewport already disabled, with 1,046–1,053 total draw calls across disabled and detached conditions. That check does not explain the cross-run difference. These short, capped measurements cannot identify the cause of the occasional slow frame or separate GPU time from CPU time.

The following stress samples fed confirmed-event-shaped receipts directly to the ordinary renderer in the solo arena. Separate real attacks verified admission, damage and shared Frost outcomes. Peak triangle counts cover the prototype geometry only.

| Presentation workload | Median | p95 | p99 | Peak bursts / triangles |
|---|---:|---:|---:|---:|
| One impact every 1.25 s | 8.57 ms | 8.76 ms | 9.03 ms | 1 / 54 |
| Three ruptures every 1.25 s | 8.00 ms | 8.72 ms | 8.91 ms | 3 / 288 |
| Six ruptures every 1.25 s | 8.01 ms | 8.81 ms | 9.05 ms | 6 / 576 |
| One impact every 90 ms | 8.21 ms | 8.76 ms | 9.04 ms | 3 / 162 |
| Six impacts and six ruptures every 120 ms | 8.26 ms | 8.72 ms | 8.87 ms | 30 / 2,376 |

The [gameplay comparison](vfx02-contact-gameplay.png) uses normal-camera frames from separate VFX01 and VFX02 fights. The [frame-matched Laboratory playback](vfx02-contact-playback.gif) shows the production prototypes beside a larger experimental treatment at the same presentation times. The experimental weapon contact uses 1.6× size, 5 m/s and a 32° hue. The experimental Frost rupture uses 1.55× size, 4.1 m/s and a 211° hue.

The three-target Rime Bloom capture shows one rupture caption and three damage numbers. The six-target ring shows one caption and six numbers. Each visual remains centered at its own victim. Rime Bloom's opening and closing labels can still overlap the numbers. The main artistic review questions are contact brightness on dark and pale targets, shard size at gameplay zoom, and legibility beside a hostile telegraph. Lower-end hardware and four-player rendering need separate measurements.

## Ordinary weapon motion and contact

The finished animation pose supplies two points on the distal edge of each supported prop. A short ribbon joins successive samples in world space. Anticipation starts up to 0.23 of a clip before release and sampling ends 0.19 after release. The prop owns its mesh and uses the shared `weapon_edge.gdshader`. Recovery fades the samples. A new weapon, interrupted strike, floor transition or large position correction clears them.

| Equipment | What the player sees |
|---|---|
| Rootblade and Harvest Scythe | The outer edge follows each reviewed forehand, backhand or crossing cut. |
| Briar Spear | The thrust leaves a fine line at the point. The alternating sweep shows the distal blade moving sideways. |
| Heartwood Maul | The overhead and lateral follow-through carry a broader edge and a short, heavier contact burst. |
| Graft Knives and Root Lash | Only the striking knife paints a shortened wake. The lash tracks its final moving link. |
| Vine Bow and Bark Arbalest | The arrow has a long shaft and fletching. The bolt has a shorter, heavier head. Both release at the reviewed socket. |
| Spore Staff, Thorn Wand, Seed Focus, Thorn Ring and Petal Fan | Each projectile keeps its own profile. The held seed and ring become flying models, the fan releases edged petals, and each receives a short directional wake. |
| Bloom Bell and Spore Censer | The existing rings and suspended bowl with its directional smoke communicate their radial and sweeping delivery. |

Travelling heads use the captured floor-local flight segment and elapsed time. The handoff uses the frozen weapon socket. Termination immediately hides the flying visual and remembers its ID against delayed duplicate releases. The existing confirmed-hit burst uses the projectile intersection recorded by the sweep. For a melee hit, which resolves against a body footprint, it uses the incoming face of that footprint before displacement. Damage text can continue to follow the displaced target. Ground contact outlines still use the resolved attack pattern.

An accepted dodge kicks six fading earth-colored flecks from the starting foot. Repeated nearby proc captions show their occurrence count. Numeric damage and active stack indicators remain individually visible. Short two-tone ticks lie inside the ordinary sweep, stomp, swipe, artillery and snare warnings. Existing authored boss warnings keep their own presentation.

### Reviewing and tuning ordinary attacks

From the Developer Garden enter the Testing Arena. Open **F4 → Tuning → Visuals → Reviewed weapon sequence**, choose the weapon and first attack or follow-up, and play, pause or step. Switch **Production baseline / Experimental** at the same elapsed time. The reference shot travels three metres in the private viewport. Use **Dodge foot scuff** for movement-only playback. For applied damage, load **Sustained damage** or **Spirit echoes**, spawn a single target or a cluster and attack in the arena. The live round and the private preview use the same weapon poses, edge shader and flight drawing.

| Workbench control | Production default | Range |
|---|---:|---:|
| Edge width | 1× | 0.3–1.6× |
| Edge persistence | 105 ms | 40–200 ms |
| Edge opacity | 0.68 | 0–1 |
| Flight wake opacity | 0.55 | 0–1 |
| Dodge foot scuff opacity | 0.65 | 0–1 |
| Show every repeated proc caption | Off | Off / On |

Knives use 66% of the selected persistence. Each active hand reuses one mesh, samples up to 120 times per second and retains up to 24 points (46 triangles). The wake, fletching, foot scuffs and warning ticks share their existing event surfaces. The edge shader and geometry are project-authored. Contact particle count, hue, speed and body-flash controls remain in **Weapon contact**. The ordinary client uses production values. An authorized solo developer session can save, reset and export differences through the existing presets.

### VFX04 rendered comparison

[Before and after at the gameplay camera](vfx04-weapon-comparison.jpg) · [Side-by-side motion study](vfx04-weapon-motion.webp). The recordings use separate live fights on VFX03 and VFX04, with the same camera, formation and weapon. The motion study crops the original frames and plays at half speed. The private Laboratory supplies fixed-phase comparisons when matching the frame exactly matters.

[Rootbound Pilgrim sweep at encounters 2, 10 and 16](vfx04-sweep-warnings.jpg). The inside-edge ticks distinguish the danger arc from the player's plain footprint on all three surfaces. Foreground foliage still obscures part of the encounter-10 arc. The short knife wake and dodge dust are deliberately quiet at ordinary zoom. Their prominence during dense fights remains an artistic review decision.

Each frame-time sample ran for 6.5 seconds in the solo Testing Arena at 1100 × 720 on an RTX 5080, Godot 4.7.2 GL Compatibility, with VSync off. The baseline used VFX03. A 120 FPS limit was applied for the capped column, then removed. Numbers are milliseconds per whole rendered frame.

| Workload | Capped p95, before → after | Uncapped p95, before → after | VFX04 uncapped median / worst | VFX04 peak simultaneous combat effects |
|---|---:|---:|---:|---:|
| Single-target Rootblade | 8.65 → 8.65 | 3.54 → 3.57 | 3.18 / 26.36 | 2 |
| Repeated Graft Knives | 8.66 → 8.66 | 3.78 → 3.83 | 3.40 / 26.28 | 2 |
| Three targets, Frost Core and ordinary strikes | 8.76 → 8.79 | 3.93 → 3.98 | 3.47 / 26.55 | 7 |

VFX02 reported 8.75 ms capped p95 for single-target combat and 8.83 ms for its overlapping-effects workload with VSync on. VFX03's Garden measurements describe a different scene. The peaks above count active combat receipts, excluding actor-owned edge strips and floating captions. The warmed camera recordings peaked at 13 edge samples for the Rootblade, spear and maul (24 triangles per strip) and nine for a knife (16 triangles). Weapon contact retains six splinters and three glints (54 triangles). The dodge uses six triangles. Short runs on this machine leave the 26 ms outliers, GPU headroom, lower-end devices and four-player rendering open for review.

## Reviewing the three affinity families

Enter the solo Developer Testing Arena from the Developer Garden. Open **F4 → Tuning → Visuals** to play Ember Wake, both Rime Bloom phases, Thorn Line, the circular Thorn patch, or each target status. **Brittle rupture** retains its separate contact preview. Choose one, three or six instances. Pause, step by 1/60 second, or switch between baseline and experimental settings at the same time and seed. Save the preferred differences in **Presets** and use the existing review export.

For actual combat, load **Sustained damage** and place Ember Fern, Frostbell or Thorn Bloom in the Core and Form slots. Try an Ember Wake lengthwise along a row of targets, a Frost cast centered on a cluster, or a Rootblade hit alongside an existing Thorn Line. In the **Build** and **Upgrades** tabs, a Vanguard Warden with Thorn Core, Frost Form, Fire Catalyst and Shatterwave can combine a bramble field, Brittle weapon hits and Burning from Root Quake. A Frost Core with Shatterwave makes the difference between target fracture and area damage easier to see.

| Family | Workbench controls | Ordinary combat cue |
|---|---|---|
| Fire | Flame height and flicker, ember lift speed, smoke opacity | Rooted fire persists over the admitted lane. The smaller body flame and stack count follow Burning. |
| Frost | Petal height, frost mist opacity, existing fragment count, size, speed, lifetime, hue and flash | Two opening stacks, then an ordinary closing stack at 625 ms. Three shared stacks fracture on the affected target. |
| Thorn | Bramble girth and thorn height | The Core draws a transverse capsule. Form and Catalyst patches grow from their confirmed positions. Bleed persists on the body after leaving the patch. |
| All three | Target-marking opacity and the existing detailed captions setting | The compact status icons and counts remain available at zero decorative opacity. |

The Fire Form applies Burning on direct weapon contact. Its Catalyst uses supported offensive applications, actual blocks or a single-use response to incoming damage. Ordinary Burning ticks every 250 ms on the combat owner’s clock. Frost Form and mapped Catalyst contacts add Brittle, which expires after 3.6 seconds without refreshing. The remaining one or two crystals show this shared stack count. Thorn Form can create a 1.25 m patch for 4.6 seconds. Catalyst growth lasts four seconds with a 1.85 m ordinary or 2.4 m ward radius. Ordinary Bleed lasts 4.5 seconds after application and ticks every 900 ms. Art follows the confirmed status and field boundaries, including changes from legal upgrades.

### VFX05A rendered evidence

The [moving comparison](vfx05a-affinity-motion.webp) pairs independent VFX04 and VFX05A fights at the same camera and sampling interval. Each panel shows the whole viewport above an original-scale detail. The [stress recording](vfx05a-affinity-stress.webp) includes six confirmed ruptures in one cluster, three enemies burning along the same trail, overlapping families, Shatterwave and Flashover.

Measurements used the solo Testing Arena, an RTX 5080, Godot 4.7.2 GL Compatibility, 1100 × 720 and VSync disabled. Each sample covers 6.5 seconds of whole-frame time. The recordings use a separate run so image readback stays outside the timing samples.

| Core and Rootblade workload | Capped p95, VFX04 → VFX05A | Uncapped p95, VFX04 → VFX05A |
|---|---:|---:|
| Ember Wake | 8.83 → 8.81 ms | 4.01 → 3.97 ms |
| Rime Bloom | 8.74 → 8.80 ms | 4.12 → 3.87 ms |
| Thorn Line | 8.74 → 8.76 ms | 3.74 → 3.74 ms |

| VFX05A stress scene | 120 FPS median / p95 / worst (ms) | Uncapped median / p95 / worst (ms) | Sampled peak affinity batches / triangles |
|---|---:|---:|---:|
| Three burning targets in one trail | 8.52 / 8.95 / 46.92 | 3.62 / 4.21 / 10.40 | 4 / 566 |
| Six clustered ruptures | 8.32 / 8.87 / 14.64 | 3.63 / 4.29 / 8.85 | 19 / 836 |
| Three overlapping bramble fields | 8.07 / 8.80 / 9.41 | 3.43 / 3.95 / 8.87 | 4 / 2,170 |
| Three families on a Vanguard Warden | 8.07 / 8.74 / 10.31 | 3.46 / 4.01 / 9.74 | 4 / 542 |

The stress capture sampled visible affinity meshes every 100 ms. Counts include target marks and fracture fragments, and exclude ordinary captions and the footprint outlines. One Fire field shares a single batch for 25 flame masks, 19 ember masks, eight smoke masks and its charred roots. Overlapping translucent layers still incur overdraw. Three Thorn fields submitted the most triangles, while simultaneous ruptures required the most separate batches. These short samples do not isolate GPU cost. Lower-end graphics and rendered multiplayer performance remain unmeasured.

The reported stress samples used a fresh disposable save root and logged zero engine errors. Reopening an unusually long disposable path produced 14 OpenGL shader-cache initialization errors at startup. A blank project with no game scripts reproduced all 14 on its second launch in that path. The same blank project logged zero on both launches in a short disposable path. The engine initializes its cache directories in this routine. [Godot GL Compatibility cache initialization](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/shader_gles3.cpp)

The focused planner still reports both pre-existing Garden layout mismatches in `experiment_garden.gd`, identified as `saved_garden_layout_3` and `saved_garden_layout_15`. VFX05A ran the scoped affinity, status, developer-session, expedition accounting and ordinary multiplayer fixtures directly. Their results are independent of the Garden layout evidence.

At normal zoom, the flame reads along the length of the field and the radial Frost petals leave gaps through which enemies remain visible. The six-target case still crowds the overhead stack counts. Review the contrast of those counts and of the burgundy Bleed motes on dark enemies before increasing density or emission.

## Installed verification

Updated the highest desktop revision, `Mystical Garden v0.5.2.0.exe`. All 73 source suites have current passing evidence (28 executed and 45 reused in the final connected run, following the focused run). All 40 selected packaged suites passed, plus startup/catalog and real host/three-guest connection smoke. The installed file matches the verified package SHA-256: `590ba2d95469db81347c121a6846ca81ac2cafc925a49ad0a3e24efcc1326dd7`.

The previous EXE is preserved at `.godot/release/backup-20261110-002313-Mystical Garden v0.5.2.0.exe`. Source notes and original changed files are in `docs/change-backups/20261110-combat-readability`. Use the updated EXE on every co-op machine so all players receive the new visual feedback.

## Water, Wood and Vital visual review

In the Developer Garden, enter the Testing Arena and open **F4 → Visuals**. Choose Dewfall, either direction of Tidal Return, Drenched, Ironbark, Bark Armor, absorption, a splinter, Vital Bloom, Vitality or applied regeneration. Pause a playback and switch between baseline and experimental at the same frame. The formations, frame step, individual resets, named presets and review export work with all eleven entries.

| Family | Live tuning | What to look for in combat |
|---|---|---|
| Water | Water opacity 0.15–1.00 and crest height 0.5–1.6× | Dewfall folds a translucent sheet across the sweep. The return has a lower crest, softer tint and opposite direction. Drenched droplets follow published Saturation. Monsoon rings stay radial. |
| Wood | Grain contrast 0–1 and bark or splinter girth 0.6–1.4× | The plates sit beside the torso. A real absorption flicks chips off the armor while ordinary expiry retires it quietly. Splinterburst consumes the armor and sends fragments outward. Short wood fibres connect a confirmed secondary hit to its actual source. |
| Vital | Petal lift 0.55–1.5× and pollen visibility 0–1 | Rounded petals unfold near the ground. Small leaves identify recipients who still have Vitality. Applied regeneration shows a modest amount and a few rising motes. A maximum-HP grant alone produces neither. |

For an actual fight, load **Sustained damage**, equip Dewcap, Ironroot or Lantern Moss in Core, Form and Catalyst, then cast and strike. Use missing HP to see an applied restoration. Disable practice invincibility to see Bark absorb a real hit. A Vanguard Warden with Ironroot Core, Lantern Moss Form and Dewcap Catalyst can show all three families at once. Monsoon and Splinterburst can be added through the ordinary eligibility-aware editor.

[Before and after](vfx05b-comparison.jpg) · [Three Core abilities in motion](vfx05b-affinity-motion.webp) · [Monsoon, armor expenditure and overlapping affinities through expiry](vfx05b-mixed-affinities.webp)

The before-and-after recording pairs independent solo fights with the same build, arena setup, camera and sampling interval. The full viewport and the original-scale detail show how much of the character remains visible. Wood occupies the sides, Vital sits near the feet and Water crosses the ground or follows a wet target. Dense fights can still overlap the compact status counts and damage numbers. Returning ring captions move behind detailed captions and repeated nearby outbound captions share a count. All healing and damage numbers retain their own receipts.

### Render measurements

Godot 4.7.2, GL Compatibility, RTX 5080, 1100 × 720, VSync off. Each row uses 6.5 seconds per cap. The camera recordings were taken outside the timing windows. In the ordinary Water, Wood and Vital trials, capped p95 changed from 8.86, 8.74 and 8.66 ms on VFX05A to 8.90, 8.71 and 8.67 ms. The corresponding uncapped p95 values changed from 3.85, 3.82 and 3.70 ms to 4.05, 3.74 and 3.71 ms. Independent fights vary in contact count and timing.

| Stress workload | 120 FPS median / p95 / worst (ms) | Uncapped median / p95 / worst (ms) | Peak new art batches / triangles |
|---|---:|---:|---:|
| Six concurrent Water wave or ring phases, final captions | 8.33 / 9.01 / 33.59 | 3.75 / 4.48 / 8.37 | 11 / 800 |
| Protection, absorption, splinters and Splinterburst | 8.38 / 8.71 / 10.18 | 3.53 / 4.04 / 10.05 | 3 / 56 |
| Bark, Vital regeneration and Water restoration | 8.13 / 8.85 / 9.85 | 3.60 / 4.17 / 9.27 | 10 / 600 |
| Ember Wake with Wood and Vital | 8.32 / 9.04 / 29.80 | 3.78 / 4.39 / 10.55 | 4 / 158 |
| Dewfall with Brittle and Bleed | 8.09 / 8.89 / 9.65 | 3.67 / 4.24 / 8.39 | 4 / 224 |

An earlier capped Monsoon run had a 263.17 ms frame. Two fresh-process follow-ups had first-run maxima of 32.96 and 33.59 ms and same-process warm maxima of 9.61 and 9.55 ms. The original spike remains unexplained. GPU and CPU costs were not separately profiled. Peaks were sampled every 45 ms and count only the new affinity batches. Each silhouette shares geometry and each active receipt owns one material and instance. Overlapping translucent water surfaces still blend on the same pixels. All five extended capture scenes finished with zero transient combat effects and zero remaining Water, Wood or Vital body marks.

### Verification and review limits

Focused checks covered baseline and upgraded abilities, real HP changes, split Water contributions, recipient-based mitigation, expenditure, expedition statistics and Archive settlement. The developer lifecycle check exercised the eleven previews, six-target playback, same-frame tuning, presets, isolation and cleanup. Ordinary two-player Wood and Vital fixtures verified that guests received their own body art. Two- and four-player Water fixtures rendered a source-owned tide's positive healing on the receiving guests. The check correlates new host and guest receipts by serial because a later enemy hit can change the recipient's HP before inspection. Multiplayer checks ran headlessly. The graphical measurements and recordings are solo.

The two previously recorded Garden layout mismatches and the long-path OpenGL startup evidence remain documented above. Artistic review should focus on Bark contrast against brown terrain, the resting leaves at ordinary zoom, and legibility of overlapping amounts in a Monsoon.
