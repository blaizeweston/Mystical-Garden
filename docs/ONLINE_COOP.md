# Direct-IP co-op: first online milestone

Current build: protocol 16. All players must use the updated executable, even when its filename is unchanged. Cursor aim and held Strike are sent to the authoritative host at 20 Hz; stale input stops attacks after 250 ms. Settings and bindings stay local to each player. Historical protocol numbers in the implementation notes below describe earlier changes.


## Playing together
1. All players use the same updated game build.
2. Host: select a character and Garden. Open Network Settings to choose a UDP port, or keep 24576. Enable “Host this Garden for up to three friends”, then start or continue. Hosting can also be enabled from the Garden's session menu.
3. Guest: select your character, choose “Join by IP”, enter the host IP and matching UDP port, then Connect. Local Garden selection does not give the guest ownership of that world.
4. On one computer use 127.0.0.1; on the same network use the host's LAN IP displayed in its session menu. Over the internet use the host's public IP. The host must allow the game through its firewall and forward the chosen UDP port to its PC where the router requires it. Networks behind carrier-grade NAT or restrictive firewalls may not permit direct inbound hosting. The game does not change firewall or router settings automatically.
5. Join while the host is in the Garden. Sessions support one host and up to three guests (four players total). The same host IP and UDP port are used by all guests. Leave or disconnect, then reconnect with the same character when the party is back in the Garden. There is no mid-expedition resume or host migration.

The selected character retains its class progression and familiarity. The host owns world progression and guest reserves within that world. Dropping a connection ends the guest's expedition; protected pouch banking uses the existing loss rules. Character progress already acknowledged by the host is saved locally, and the host retains earned-progress recovery records. This is not a promise to recover packets that never reached the host.

## Foundation
ENet binds the host on all interfaces instead of loopback only. Address and port settings are validated before connecting; IPv4, IPv6 and localhost are supported. Connection/registration timeouts and cancellation return roster characters safely. Protocol/content mismatches, invalid identities, duplicate characters and late expedition joins are rejected before owner snapshots and gameplay requests. Remote action/motion rates are bounded. World authority, separate state channels, transaction boundaries and roster leases remain in use.

This is friend-hosted direct connection, with trusted player-supplied character progression. It has no accounts, password authentication, matchmaking, public lobby listing, encryption guarantee, relay, automatic NAT traversal or cheat prevention. The connection layer is intentionally separate from future transport/lobby services.

## Verification scope
Automated two-process tests exercise a non-loopback local network interface with a custom port, actual incompatible-protocol rejection, character progression saving, disconnect and reconnection. Existing co-op suites cover equipment, skills, crafting, seeds and menus. Unit checks cover IPv4/IPv6 parsing, ports, admission rules, timeouts, cancellation and character safety. IPv6 routing and a connection between two separate internet households have not been verified in this environment. A remote friend playtest is the next transport validation step, alongside latency/loss tuning.

Protocol details follow the official Godot [ENet API](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html) and [high-level multiplayer guidance](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html). Godot's ENet transport uses UDP, so a TCP-only router rule is insufficient.

## Ready checks
All party members confirm at the Wilds gate to enter together. Each cleared stage requires all active expedition players to ready again at its onward gate; third-gate card decisions do not automatically ready you. Extraction at every sixth cleared gate also needs agreement. The HUD names each player and shows readiness, with a Not Ready control. Moving away or editing a prepared build clears your confirmation. A disconnect cancels the pending check and requires a fresh choice from the remaining party. Defeated or voluntarily abandoned characters in the Garden do not block the survivors' expedition. The old Heart finale and offshoot feature are deferred; they do not create travel prompts or occupy beds. Use matching updated builds; the multiplayer protocol was advanced for this consent contract.


## Four-player expansion
The shared limit is Network.MAX_PLAYERS=4, with three ENet guest connections. Protocol 9 requires matching builds. Each connected player reserves a distinct reusable party slot, with separated Garden and Wilds arrivals. Public snapshots include character names and party colors while inventory details remain owner-only.

Enemy counts grow by four per additional active player (18 scouts plus the leader on the first four-player floor), capped at 20 in co-op; the solo scout limit stays 12. Health scales per additional player and is fixed for that encounter. If generation cannot safely place the full budget, spawn safety takes precedence. Ready checks, checkpoint cards, extraction and personal reserves continue to include all eligible players. A fifth connection is refused. A disconnect cancels pending travel and requires fresh confirmations. There is still no host migration.

The automated four-player suite runs a host and three independent guests plus a fifth-connection probe. It covers capacity, identities, distinct spawns, owner-only inventories, four-way departure and gate readiness, checkpoint cards, extraction to separate reserves, and disconnect/reconnect. The same test also runs against the exported game pack before the newest EXE is replaced. Internet latency and four separate household networks still require real-world playtesting.

Natural monster kills now grant each living expedition member the same essence and fractional class XP, independent of last hit. Each player gets an independent species-specific part roll and owner-only ground pickup. Summoned creatures give no kill rewards. The four-process suite verifies XP delivery, private pickup visibility, and persistence through reconnect.

## Guest presentation and research synchronization
Movement packets include authoritative velocity, so locomotion does not depend on the ratio between rendering FPS and snapshot rate. Foot cycles follow rendered distance. Movement snapshots carry increasing sequence numbers; health additionally has per-player authority revisions and reliable confirmations. Older packets cannot restore superseded HP, and damage feedback is deduplicated using a damage sequence. These are presentation/reconciliation improvements, not client-side hit authority or full movement prediction.

The host starts world-owned Knowledge projects. All players see the same saved research timer and may offer explicitly previewed shared plant parts at the Heart. Timers run while the hosted world is open and accelerate once, by 3x, when an expedition is active. Tests exercise a real moving guest, one half-heart monster hit and feedback, a zero-material Knowledge start, timed bed completion, and guest offerings. High-FPS/20Hz snapshot and stale-packet tests also run. Internet latency and jitter still need validation with separate household connections.

## Supplied connect-and-play harness
The adapted `test/` bundle complements `tests/`: `test/run_net_test.ps1` launches a coordinated host and 1–3 guests, defaults to mixed 60/240 FPS limits, and checks all-party movement, walking joints, reliable owner details, privacy and stable party membership. JSON results, logs and fixture saves are isolated under `.godot/network-tests/`. Manual Host/Guest modes coordinate only through RPCs and accept a reachable host IP. Pack mode uses the Godot engine with the exported EXE as its resource pack and an isolated resource root; shipping test resources are forbidden. The source smoke is required by validate_release.ps1, and release_latest.ps1 also runs the smoke against the staged pack before replacement. See `test/README.md` for commands, options and scope. Local checks do not establish latency/loss tolerance or prove separate-household routing.


## Warden cleared-floor report: compatibility hardening
The available host log recorded RPC checksum mismatches and guest requests being decoded as `receive_vitals`. This is evidence of incompatible method layouts between copies; it does not establish the exact cause of the reported guest process crash without that guest's crash log. The isolated Warden scenario also passed against the original world script with matching peers, so this remains a compatibility fix and a regression guard rather than a confirmed reproduction of the crash.

Connections now use SceneMultiplayer authentication before any scene RPC is permitted. Both peers compare protocol 8 and an automatically computed method-name/argument/return-type signature from the world script; this also works with compiled exports. Older peers that do not perform this exchange cannot enter gameplay. Character/content registration remains a separate check after compatibility. Connection failures during this phase explain that both copies must be updated. This is a compatibility check, not account authentication or protection against a deliberately modified client. Changes to wire behavior/channels still require a protocol bump.

Cleared-floor Q/R input is suppressed locally, while the host keeps its existing authoritative guard against late requests. `tests/network_warden_coop.gd` exercises mismatched layouts, old protocols, missing legacy handshakes, guest Guard/Root Quake and Living Bastion/Briar Charge, final primary/scout kills, repeated cleared-floor input and direct late RPC requests, and a working cast in the next encounter. It runs in source and packaged release checks using isolated profiles. Both players must replace their game copy with the latest EXE, even if the filename is unchanged.

The pre-RPC gate follows [Godot's SceneMultiplayer authentication lifecycle](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html). The Warden regression passed with OpenGL graphics enabled on both local peers as well as in headless checks.


## Visible monster loot and fallen teammates
Protocol 9 adds public fallen/lost-health state and reliable revision-checked updates for revival. All peers must update. Monster trophies remain personal drops; their glowing blue pickup model now uses the Wilds world offset, and explored-map icons and the map legend identify them in blue. Seed markers remain gold. Picking a part up removes the model and map entry.

At zero health, a player stays on the floor as a fallen body while any living party member remains. The camera, fog and map follow a living teammate. The spectator panel can cycle allies in larger parties and selects another living ally if its target falls or disconnects. Fallen players cannot move, attack, cast, loot, regenerate or vote at gates. Nearby living allies press E to revive them; the prompt states the cost. Revival restores health to the reduced maximum, deducts two maximum health (one full heart) cumulatively for the current expedition, and grants 1.5 seconds of hit protection. The fourth heart texture shows sacrificed capacity, including hearts previously added by upgrades. At least one full heart must remain; reviving again is refused if the exact two-point cost would leave less than two health. Health upgrades add capacity without cancelling previous sacrifices.

Fallen allies do not block gates or checkpoint cards. Their bodies travel with the party to the next floor without being healed. Extracting while still fallen keeps only their safe pouch; revived survivors extract their carried rewards normally. A party wipe or loss of the last living teammate ends the run, banks only protected contents and returns everyone to the Garden. Garden return restores sacrificed capacity. Individual abandonment still discards all run cargo, including the pouch. No death penalty is stored in permanent character progression.

Validation: `tests/loot_revival.gd` covers blue/private pickups, down-state restrictions, spectator cycling, repeated costs, health upgrades, travel, extraction, wipes and stale state. `tests/loot_revival_coop.gd` tests actual guest pickups, both directions of E revival, host/guest spectating, private drops and wipe replication. Both are required in source and packaged release checks; the co-op scenario also runs with graphics enabled for visual review.

Saved diagnostics: Settings > Diagnostics marks issues, opens logs and exports a local ZIP. Both host and affected guests should export after a multiplayer problem; host/world session IDs correlate their files. See DIAGNOSTICS.md.
