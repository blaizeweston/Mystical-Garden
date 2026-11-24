# Garden expansion scenes

Choosing a frontier and confirming growth in the Build menu starts the expansion. Reaching Roots unlocks that purchase. Completing research updates the Heart and plays its completion sound without taking the camera.

## What each player sees

The forest edge recedes and a permanent root grows toward the purchased frontier. Each Garden player’s camera follows that root, pauses at the newly opened ground, then returns to their character. A side root may grow from an older root. The direction in the caption matches the frontier selected in Build.

The host and guests watch independently. A player in a menu sees the camera sequence after closing it. The shot waits during expedition travel. Escape or the on-screen Skip button dismisses it for that viewer. The Garden cinematics and ambient motion settings control local playback. The physical expansion remains visible in the shared Garden.

A new visitor starts at the existing layout. A returning character can see a pending expansion, while an acknowledged expansion stays dismissed. The shared presentation history retains the latest 64 events. Loading a developed Garden does not replay the terrain reveal.

## Editing and verification

- `assets/terrain_m02/experimental/experiment_garden.gd` validates the purchase, commits the land and scene together, and plays the same frontier reveal on the host and guests. `assets/terrain_m02/garden_heart_roots.gd` defines the root route. Building relocation and ordinary layout snapshots produce no new scene.
- `garden_growth_state.gd` records the expansion number and direction in the existing Garden history. `garden_growth_service.gd` projects pending events per character and accepts an acknowledgement for the first pending event. Historical research entries still support the research sound. Return discoveries keep their own queue entries and visual behavior.
- `garden_presentation_world.gd` supplies local settings, menu and travel state. `garden_growth_view.gd` waits for the matching generated geometry, then drives the camera, caption, glow and skip. `stage.gd` applies the camera target. Watching a scene grants no land, rewards or research.
- `tests/experimental_terrain_coop.gd` covers the purchased frontier on independent host and guest clients, independent skipping and reconnect. `tests/garden_layout_persistence.gd` verifies rollback and a single saved event on reload. `tests/garden_cinematic_view.gd` covers the research cue, camera ownership, local settings and acknowledgement retry.
