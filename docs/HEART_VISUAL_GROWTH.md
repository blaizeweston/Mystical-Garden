# Per-technology Heart growth — 2026-11-10

Every completed, enabled Knowledge technology now earns one permanent visual growth step. The initial seed-organ gains shoots, develops into a sapling, and becomes a larger branching tree with a fuller canopy. All 23 currently available technologies produce distinct growth steps; completing them produces the large tree without enabling Perfect Recollection or the deferred ending. The initial organ, folded sepals and original veining shrink away during the first sapling transition. Later forms use a ground-connected trunk and their own buttress roots, without an overlapping seed body.

## Ownership

`heart_growth_visuals.gd` derives completed count from unique enabled IDs in the existing host-owned research list. It builds cosmetic shoots, a winding trunk, incremental branches and instanced pointed leaves; its pose function interpolates the earned growth. It does not spend Knowledge, unlock technologies, grant items, modify the Garden's movement footprint or trigger an ending. The old restoration phase remains available to existing mechanics and save compatibility.

`heart_visuals.gd` attaches this growth to the existing organ. `stage.gd` synchronizes the visual count from the ordinary Heart snapshot. Geometry rebuilds on count/legacy-form changes, not every frame; the first part of a reveal changes existing transforms and unfolds the new branch. Independent height, crown width and branch additions make growth persist beyond the short pulse animation.

## Cutscenes and old worlds

Knowledge reveal events record `from_growth` and `to_growth`. During the initial Heart-focused shot, height and width interpolate and a new shoot/branch physically unfurls. The camera frames the growing Heart, then follows the existing travelling root to the feature. The existing destination-formation timing is retained. Events completed together receive successive counts, so queued scenes do not all jump to the final tree.

Each viewer retains their existing queue and acknowledgments. A local hold prevents the full researched tree flashing between queued scenes. Skipping retains the earned result; disabling cinematics presents it immediately after acknowledgment. Old queued events without these new fields infer their counts from the remaining enabled research events. A Garden whose research was already completed reconstructs the corresponding tree on load without repeating research or paying again. Watching growth cannot generate gameplay rewards or consume gameplay RNG.

`heart_foliage.gdshader` provides gentle motion and local transparency where leaves obscure the player. Garden ambience supplies the viewer position and existing motion preference, including to newly rebuilt materials. The canopy does not block interaction or introduce a collider. Shader coordinate references follow [Godot's spatial shader documentation](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html).

## Verification

`tests/heart_growth_visual.gd` completes every available technology in an isolated world. It verifies one growth step per scene, previous/intermediate/final poses, an initially hidden new shoot, physical half-scale unfurling, increasing height, real tree geometry, persistent completion, reduced motion, viewer input for canopy fading, no steady-frame rebuilds, gameplay RNG isolation, old event inference, saved-world reconstruction and the ending remaining disabled.

The host/guest growth suite checks transmitted growth steps and restored totals after reconnect. Existing Garden formation, skipping, return-discovery, cleanup and Heart research checks cover adjacent consumers. Test selection is scoped under `heart_growth_visual` in the mechanics map; unrelated runtime evidence remains reusable.

In-engine forms were reviewed at `.godot/heart-growth-0.png`, `.godot/heart-growth-3.png`, `.godot/heart-growth-12.png` and `.godot/heart-growth-23.png` using the same framing. These are procedural game assets and remain replaceable by an artist-authored model behind the same research/pose interface.

## Verified release — 2026-11-10

Initial linked validation passed 11 affected suites and reused 92 unchanged results. The final physical-unfurling assertion reran one affected suite and reused 102 current results in `20261110-193529-00d23c51`; all 103 registered suites have current passing evidence. All 39 planner self-tests passed. Packaged validation passed eight selected checks and reused 62 unchanged packaged results, plus startup/catalog checks and a real host/three-guest connect-and-play smoke. Source and packaged growth host/guest checks passed. Full-suite mode was not used.

Updated only `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.2.exe`; installed SHA256 `747771773b83ae002fbbab6c54dd56621047ab57d8b74d4081a85a3bf0ca53c1` matches the verified package. Previous EXE retained at `.godot/release/backup-20261110-193627-Mystical Garden v0.5.2.2.exe`. Protected pre-cleanup backup untouched.

## Overlapping old-form correction — 2026-11-10

The original implementation retained the old seed-organ beneath every grown form. That overlapping representation was not the intended transformation. The old meshes now belong to a SeedForm group: fully visible for initial growth, shrinking during growth step 2→3, and hidden for sapling/tree stages. The trunk starts at ground level and supplies its own roots while retaining the previous total height. Existing stage references to the hidden core remain valid for compatibility.

Regression checks cover physical shrinking, hidden core/sepals at every grown stage, ground contact, reload and guest presentation. The linked pass reran eleven suites; an unrelated randomized weapon-range smoke fixture needed a fixed unobstructed position, no scouts and an explicit cooldown reset. No runtime combat rule changed. Final run `20261110-194851-e51c7866` passed the corrected smoke with 102 current results reused; all 103 suites have current passing evidence. Packaged validation passed eight selected checks with 62 reused, startup checks and real host/three-guest connect-and-play smoke. Full-suite mode was not used.

Installed only `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.2.exe`; SHA256 `b7443f0a7a3ac11f6bfc90f28e72852ca63df64e75b45e338ad0e90fbeb0d638`. Prior EXE: `.godot/release/backup-20261110-195004-Mystical Garden v0.5.2.2.exe`. New sapling and mature screenshots were visually reviewed at the existing preview paths. The protected pre-cleanup backup was not accessed.
