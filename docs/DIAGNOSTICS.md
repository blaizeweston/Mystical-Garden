# Saved diagnostic logs

Logging starts with the application and stays active across menus and worlds. It is local to this computer, with a separate session directory for every running instance. No upload or external account is required.

## Player controls

Open Settings from the Main Menu or pause menu, then Diagnostics.

- Mark issue writes an event with an optional short note. Use it as soon as something looks wrong.
- Detailed tracing adds combat-sequence and ordinary engine-output events for this application session. It resets after restarting.
- Open logs opens the local diagnostic folder.
- Export report creates a ZIP and copies its path to the clipboard. It includes this session plus up to two recent inactive sessions, so a recent crash can be included after restarting. These diagnostic tools act immediately; Apply/Cancel still govern the normal control/display/audio settings.

For multiplayer, ask the host and affected guests to export separately. Keep the reports with the steps that caused the problem.

Windows default storage: `%APPDATA%/Mystical Garden Prototype/diagnostics`. Exported ZIPs are in the neighboring `diagnostic_reports` folder. The directory retains the existing application-data name to preserve save compatibility. Tests redirect APPDATA to isolated project fixtures.

## What is captured

Every JSONL record has a schema, application session, local event sequence, UTC timestamp, elapsed milliseconds, category and context. Host/world IDs, actor peer ID, biome, floor, procedural seed and combat epoch help correlate reports. UTC clocks can differ between computers; local sequences are ordered only within their own application. These are diagnostic correlation fields, not a replay or a deterministic simulation recording.

Events include transport/authentication/registration/disconnection, interaction begin/end and relevant item choices, class/familiarity state, crafting/grafting state, graft probability and the existing RNG roll, successful altar offerings, health/vitals revisions, progression metrics, and save commit/rollback. Instrumentation does not consume an extra random number. Interaction end means the handler returned; compare the resulting state and save outcome to determine whether the requested change succeeded. A damage event inside a later rolled-back transaction describes that attempted transaction, not permanent committed damage.

A small state observer runs at most four times per second, records changed state, and samples positions/health/sequences/projectiles/FPS/transport statistics every two seconds. Reliable ENet packet-loss estimates update on ENet's own interval and may still be zero before warmup; snapshot gaps are sequence gaps, not a measurement of total packet loss. Snapshot silence beyond three seconds is marked separately. Motion packets and held-strike input are not written individually.

In the combat balance preview, detailed tracing records player healing_applied events with the source, party slot, rolled HP, applied HP and resulting vitals. The difference between the rolled and applied amounts can include overheal or the per-floor kill healing limit. Damage records carry applied HP separately from the incoming amount, and presentation events identify confirmed heals. The offline analyzer writes both amounts to its damage and healing exports. When both perspectives log the same revision, it can also compare maximum HP, sealed HP and fallen state.

The combat balance preview records encounter_balance when the host spawns a Wilds floor. The event captures the locked party size, leader species and HP, scout budget, actual scout count and total scout HP.

Engine warnings and errors are captured through Godot's Logger with source/function/line and available script frames. Release builds enable call-stack tracking without capturing local variables. Normal output is captured only with detailed tracing.

## Storage and failure handling

Each application session has `session.json` and up to four rolling JSONL chunks, normally at most 1 MiB each. The newest events survive rotation; metadata keeps the build and latest heartbeat context. Eight prior inactive sessions are kept in addition to the current/other active sessions. The five newest exported reports are retained separately. Archives contain diagnostic files only, not Garden saves or character profiles.

Events are flushed after writing. The writer serializes concurrent callbacks, bounds event size and rate, and reserves a separate error/warning budget so routine floods cannot consume it. Reports take a consistent snapshot of the current files before compression. Logging uses direct file I/O independently of gameplay save transactions. If the folder is unwritable or disk writes fail, logging disables itself rather than consuming items, cancelling gameplay transactions or taking down the game.

A normal exit marks the session clean. A forced termination leaves it unclean; a later application points to recent inactive unclean sessions. An unclean flag is not proof of an engine crash: power loss, a forced kill or shutdown can all cause it. Early startup failures or native hard crashes may leave no script stack, and no logger can guarantee the last write survives power loss. Previously flushed breadcrumbs remain useful.

Structured fields omit character names, persistent identities, addresses and complete profiles. Ordinary home-directory and IPv4 text are redacted; notes and engine messages are still free text. Review a report before sharing it if it contains sensitive information entered in a note or emitted by another component. Nothing is sent automatically.

## Development

`diagnostic_journal.gd` provides a reusable static event API; `diagnostics_boot.gd` owns its application lifetime. `diagnostic_watch.gd` samples the current world, and `diagnostics_panel.gd` supplies the player tools. Existing gameplay metrics are mirrored into this journal after their transaction succeeds; the older metrics file remains for compatibility.

Protocol 17 adds sequenced movement commands and acknowledgements; protocol 16 introduced host/world correlation fields to public state. All co-op copies must be updated. The logging metadata is not stored in permanent character/world progression.

The diagnostics unit suite tests thread safety, redaction, file/rate bounds, active-session retention, ZIP contents, disk failures, real script errors (including nonempty release backtraces), and forced termination in child processes. The real host/guest suite tests shared correlation, authoritative damage, reliable vitals, transport measurements, and exported reports. Both are portable packaged release checks. Because initial instrumentation touches bootstrap, shared saves, networking and the dependency map, this setup requires a full validation once. Future changes follow the selective validation map.

API references: [Godot Logger](https://docs.godotengine.org/en/4.7/classes/class_logger.html), [ScriptBacktrace](https://docs.godotengine.org/en/4.7/classes/class_scriptbacktrace.html), and [ENetPacketPeer statistics](https://docs.godotengine.org/en/4.7/classes/class_enetpacketpeer.html).

## Movement timing (protocol 17)

Each two-second network sample includes `movement_timing`: maximum snapshot-arrival gap and count above 100 ms, maximum local prediction correction in world units and count above 0.25 units, pending input count, maximum host physics callback interval and count above 50 ms, and expired input-queue count. Interval maxima/counts reset after each sample; pending input count is instantaneous. The first callback/packet establishes the clock. Physics callback intervals use local monotonic wall time, so host stalls are visible even when Godot supplies a fixed simulation delta. These measurements require no synchronized computer clocks and do not log every packet.

A guest predicts at most 250 ms of unacknowledged movement, replays bounded input history against authoritative acknowledgements, and holds when that horizon is exhausted. The host limits simulation time and expires stale input. Remote player positions have a 100 ms presentation buffer; gameplay, damage and interactions still use host authority. Large correction values identify reconciliation work, not automatically cheating or a collision bug. The existing analyzer preserves these fields in its raw event output; older reports do not contain them.

## Thorn Line adaptation

The host records `wilds_thorn_armed` when a placed line becomes active and `wilds_thorn_crossing` when an ordinary enemy moves into it from outside. Both carry the cast ID. The committed `wilds_learning` summary includes `thorn_armed`, `thorn_crossings` and the world score. A successful floor contributes once, regardless of party size. The `core_trip` event records confirmed damage ticks and the separate Quake lash, along with any first-contact card effects. The host records `core_trap_contact` and `class_trap_contact` once per captured enemy. A `core_wave` event summarizes each Riptide pass.

The host emits `wilds_thorn_vault_locked` and `wilds_thorn_vault_landed` when a Thornmaw Hound commits to and completes the learned move. The warning and hit use the same landing, and a blocked landing or a root applied during the windup cancels it.

## Learned support responses

The host records `wilds_skill_evidence` with `cast_denial` for a canceled committed attack, `area_pressure` for a damaging cluster or a Broodmother seedling lost to a Core pulse, `route_denial` for a newly rooted pursuer, and `shelter_break` for a Core displacement out of a Grazer's canopy. Fields identify the species and affected actor when available. The committed `wilds_learning` summary includes per-floor `skill_evidence` counts. `wilds_skill_response` records the locked response ID, species, tactic and floor. The report pairs these events with warnings and encounter clears to measure response frequency.

## Garden observations

The `garden` category records `observation_recorded` only after the existing transaction commits, with actor, stable point/observation IDs and world revision. `interaction_rejected` records a rejected Garden intent and reason. These events neither mutate progression nor drive presentation; the committed versioned projection drives the view. No crop tick, creature motion or per-frame pulse is logged.

Garden expansion scenes record `growth_scene_started` (technology, sequence, kind), `growth_scene_finished` (sequence, whether acknowledgement was requested), and `growth_acknowledged` (actor and sequence, only after the save commits). An interrupted scene finishes without acknowledging; a requested acknowledgement is not itself proof the save succeeded. Compare it with the post-commit event. Character identity keys and per-frame root/camera positions are omitted.

Cultivation records `crop_care_chosen` after a committed choice and `crop_harvested` after a committed payout. These identify actor, bed/cycle and stable species, with choice/revision or seed/part/rare outcome. `crop_request_rejected` explains range, mode, stale-cycle/stage or unavailable-choice rejection. The pending rare roll and character identities are omitted; no growth tick or cosmetic bud pulse is logged. Existing save transaction events correlate failed decisions and harvest rollback.


Cultivation watering records `crop_watered` only after commit, with actor, bed/cycle, revision and the bounded multiplier. The growth-rate and maturity choice use the existing crop/save records; no per-second crop log is added. The pre-game compatibility payload also compares cultivation rules, rejecting missing/older fingerprints before gameplay.

The growth validation also exposed a client presentation edge case: a zero prediction substep could suppress the walking pose despite moving displayed positions. `avatar_motion_view.gd` now lets client gait use visible travel; simulation velocities and timing diagnostics remain intact. The real four-player smoke checks both position updates and joint excursion.

Garden homecomings record `return_discovery_received` after a committed discovery becomes newly visible in the read-only projection. Fields are stable discovery/point IDs and `host_world` or `host_snapshot`; initial/reconnected baselines do not replay this cue. This is receipt/presentation evidence, not the authority that grants a discovery. Existing save transaction and growth scene/ack events cover rollback and playback. No raw member identities, unidentified seed contents, bank-credit history, moth positions or water pulses are logged. Garden return catalog fingerprints are checked before co-op admission; all players need the same updated build.

Living conduit changes record `conduit_changed` only after the existing transaction commits: actor, stable zone/mode IDs and revision. Rejections use the existing `interaction_rejected` event; save failures retain transaction correlation. The event does not drive the crop policy or grant a reward. Existing `crop_care_chosen`, `crop_harvested` and growth-scene events cover later use. Mode color/root presentation sends no per-frame events or network requests.
