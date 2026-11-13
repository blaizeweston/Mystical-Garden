# Character management, settings and cursor combat

Main Menu character deletion asks for confirmation, protects active/changed profiles, archives the profile in its slot backups, and leaves Garden worlds intact. A deleted identity cannot be reimported from old per-world profiles. Empty slots can immediately create new characters.

Settings are available in the Main Menu and pause menu. Primary/alternate keyboard or mouse bindings, fullscreen, VSync, frame-rate limit, master/effects volume and the aim indicator are saved locally in settings.cfg. Apply saves; Cancel discards. Escape always remains available for menu recovery.

Strike defaults to Space or left mouse. The cursor projects onto the player ground plane to determine facing, melee arcs and projectile paths. Hold Strike to repeat at the resolved weapon interval; installed parts, grafts, class traits and upgrade cards continue through the common hit pipeline. Projectiles collide along their flight path rather than snapping to a selected enemy. Menus, focus loss, death and stale guest input stop held attacks. Release Strike after closing a menu to resume.

Online combat input is host-authoritative, sent at 20 Hz with a 250 ms stale-input timeout. Protocol 15 requires the same new build on every peer.
