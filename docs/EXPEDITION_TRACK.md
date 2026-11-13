# Wilds floor progression HUD — 2026-11-10

`expedition_track.gd` is a passive, reusable view of the host-authoritative global `encounter_number`. The small upper-left encounter counter has been replaced by a top-center node track; the foes count stays at the upper left.

- Current floor remains exactly centered and larger. Reached nodes retain their actual floor numbers. Future nodes show `?` until reached, then gain their number and a growing root connection.
- The moving window shows three past/three future nodes on wide screens, two either side on medium screens and one either side on narrow screens. Before floor 1, space stays empty rather than inventing a floor zero. The layout stays bounded during endless runs; moving the window never renumbers earlier floors.
- Upgrade stars and extraction-gate icons read `EncounterConfig.UPGRADE_INTERVAL` and `EXTRACTION_INTERVAL`, currently every 3rd and 6th gate. Both icons can appear on one floor. Upcoming nodes show these schedule hints while keeping their numbers concealed. A small legend identifies the icons. Icons describe opportunities after clearing that floor, not an immediate right to extract.
- The track hides in the Garden, remains visible for fallen players observing their party, and ignores mouse input. Existing HUD/menu/minimap/party positions are preserved. Node layout is rebuilt only on floor/visibility/viewport changes; root animation redraws briefly on advancement, not on every repeated snapshot.

No RPC, save, discovery, readiness or checkpoint authority was added. Guests use the existing replicated global floor. The view has no progression side effects and consumes no gameplay RNG.

`tests/expedition_track.gd` checks responsive centering, floor 1, endless floor labels, unknown future nodes, retained history, both checkpoint intervals, Garden/Wilds/spectator visibility and animation reset. `tests/expedition_track_coop.gd` uses real admitted peers to check floor 6, advancing to 7 and returning to the Garden through the production snapshot/HUD path. The implementation and small integration hooks are scoped under `expedition_ui` in the mechanics map.

In-engine visual review: `.godot/floor-track-preview.png`.

## Verified release

Connected run `20261110-184043-fe49a882`: 4 affected suites passed, 96 unchanged suites reused, 100 registered; 39 planner self-tests passed. Packaged validation passed three selected checks with 64 unchanged packaged results reused, startup/catalog validation and real host/three-guest connect-and-play checks. Source and packaged floor-track host/guest tests passed. Full-suite validation was not run.

Updated only `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.2.exe`; installed SHA256 `a9e60b00d67146ad7a291081973a79290fa4148bf51ad7603717e989d4d541e0` matches the tested staged build. Previous EXE: `.godot/release/backup-20261110-184205-Mystical Garden v0.5.2.2.exe`. Protected pre-cleanup backup untouched.
