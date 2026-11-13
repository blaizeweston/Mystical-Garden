# AC-06 Stage A1 · Serializer failure integrity and migration state

## Verified baseline

The clean branch was `ac06/persistence` at Group 3C commit `bd71090b8ab580343f0972c2e3ac15c748d21141`, whose parent is `24a1e9b37b48019b3945bcced5b0ba78f1b7dff8`. All 1,251 committed inputs matched the worktree and Group 3C manifest after Git line-ending normalization. The audit rechecked the 123 stored structured verdicts, 171 process exits, four-peer packaged smoke and both controlled interruption/recovery runs.

## Serializer inventory and behavior

| Entry point and callers | Participating failures and disposition |
|---|---|
| `progress.gd::save_garden/save_garden_guarded/_serialize_save`. World lifecycle, registration and character records, growth/research, altar, planting, inventory, expedition travel and settlement, `SaveSlots._initialize_guarded`, and Developer Garden. Direct legacy callers also include `HeartProgress`, `InventoryModel.transfer`, `AltarService` and `Progress.pay_shortcut`. | Backup validation or IO can fail before staging. Serialization submits the canonical bytes through the live stage or legacy `SaveBatch.write`. A participating failure latches even when a caller ignores the individual return. Direct opted-in saves without the exact object/path/stage fail before serialization. |
| `character_profile.gd::save_profile/save_profile_guarded/_serialize_save`. `GameTransaction`, `game.gd::publish_character/save_local_character/receive_character`, character selection and appearance, `SaveSlots.ensure_character/_initialize_guarded`, and `CharacterSlots.create/update/_edit_guarded/_import_guarded`. | Same first-error and authorization boundary. The host owns its local profile and the Garden's guest record. The guest owns the canonical guest profile. Ordinary roster edit/import serializers run under their own management operation with an exact scope. |
| `persistence_operations.gd::commit_serializers/stage_serializer/authorizes_serializer/backup_serializer`. Guarded gameplay, standalone maintenance, slot creation/reset and roster edit/import. | The native context owns the complete participant and auxiliary scope. Wrong stage, foreign serializer, changed path, failed nested authorization, backup failure and stage rejection feed the same attempt's first-error field. A later serializer can return its own success and stage bytes in memory. The attempt still cannot install any of those bytes. |
| `game_transaction.gd::run/run_gameplay/_run_guarded` and `save_batch.gd::record_serializer_error/commit/cancel`. Legacy or opted-in gameplay and nested saves. | Legacy pre-stage failures previously escaped the batch, and a later write failure could replace the first. The batch now records only the first error, discards its staged files and returns failure before legacy journal publication. The legacy wrapper exposes completion separately from the business value. A verified serializer abort restores gameplay, serializer state and RNG. Guarded finalization retains B1/B2 outcomes. |
| `save_slots.gd::prepare/prepare_guarded` and guarded roster import. | Legacy world/guest import copies bytes. The guarded world import copies checked bytes through `commit_bytes`; the original format persists until a subsequent serializer migration. Roster import normalizes the destination in its own guarded commit and preserves the source. Raw byte copying has no migration flag to finalize. |

Guarded `ABORTED_RESTORED` restores the captured state. `UNCERTAIN` preserves tentative memory and evidence, and refuses another affected write. Both committed outcomes clear the migration flags for the exact serialized objects under the owning lock. `COMMITTED_CLEANUP_PENDING` retains the new bytes, warning and write restriction. A legitimate `false` or `null` business return is independent of the verdict. Application settings, network preferences and diagnostic/metrics outputs remain separate from canonical serialization.

## Migration inventory

| File | Flag and on-disk trigger | Reserved original backup |
|---|---|---|
| Garden | `needs_plot_backup`, no valid `garden.plots_v2` array | `.pre-plots-v2.bak` |
| Garden | `needs_growth_backup`, missing modern plots or planted entries with `growth_rules` below 2 | `.pre-tier-growth-v2.bak` |
| Garden | `needs_heart_backup`, `heart.state.version` neither 1 nor 2 | `.pre-heart-v1.bak` |
| Garden | `needs_research_backup`, `heart.state.version == 1`; current writer emits 2 | `.pre-timed-research-v2.bak` |
| Garden | `needs_content_backup`, missing `content` section; current writer emits the content manifest and quarantine | `.pre-content-v2.bak` |
| Garden | `needs_inventory_backup`, missing `inventory` section | `.pre-inventory-v1.bak` |
| Garden | `needs_altar_backup`, missing `altar` section | `.pre-altar-v1.bak` |
| Character | `needs_content_backup`, missing `content` section; current writer emits the content manifest | `.pre-content-v2.bak` |

`Progress._read_garden`, `HeartProgress.load_state` and `CharacterProfile._read_profile` derive the flags from canonical bytes on load. Previously legacy serializers cleared them immediately after the copy, before either staging or replacement, and guarded saves kept flags set until reload. The new confirmation boundary clears them at verified guarded commitment, or after the successful legacy write/commit marker on the legacy route. Before that boundary the flags remain due. The new code preserves migration source bytes in published backups. Matching interrupted backup scratch may be published on an explicit retry. A contradictory existing backup or unresolved scratch is preserved and blocks guarded migration. A historical backup whose bytes differ from the still-legacy canonical source needs review, even if it was once valid. Backups are deliberately outside the canonical commit and survive abort or restart.

## Verification

Godot `4.7.2.stable.official.ed1daf0bf`. The focused planner preview listed 115 of 162 suites and no unmatched scope declarations. The checkpoint ran relevant persistence, settings, gameplay and network suites, including Groups 1 through 3C. All 53 planner self-tests passed. The final index contains 125 passing structured verdicts across 62 source and 63 packaged runs, with 173 successful process exits. The separate packaged smoke passed with four peers. No verdict or engine-error check changed.

- `a1-{source,pack}-serializer-integrity-verified-unit` tested both serializer orders, nested ownership, raw authorization refusal, abort and uncertainty, cleanup-pending, matching and contradictory backup evidence, timed research conversion, current-format reload, legacy first-error propagation, and isolated auxiliary IO failure.
- `a1-{source,pack}-migration-{before,partial}-{owner,recover}` terminated the owner before the first replacement and after only the character replacement, respectively. Owners exited 1 without a verdict by design. All four recovery processes exited 0 with current structured PASS. Canonical originals were verified before migration retry. Backup hashes remained identical, flags were still due after restoring originals, and cleared after retry. This is process-interruption evidence.
- `a1-{source,pack}-guarded-gameplay-transactions-nested-final` supersedes an earlier assertion that expected every later serializer to echo the first error. The final assertion checks later staging success and still requires the same first-error abort, original bytes and restored runtime. Early fixture probes also exposed that title startup can commit growth registration before a test injects a migration fault. The final fixture installs and reloads controlled legacy bytes after that initialization in its disposable root.
- `a1-pack-supplied-network-smoke` passed. Guarded lifecycle, Garden actions and expedition host/guest regressions also passed with source and packaged binaries. Garden growth verifies offline-before-detach on both peers.
- [Exact structured verdicts and restart evidence](<C:/Users/sutte/Documents/Codex/ac06-stage-a1/VERIFIED_RUNS.json>) and [canonical and backup digests, flags and notices](<C:/Users/sutte/Documents/Codex/ac06-stage-a1/ACTION_EVIDENCE.json>).
- [Tested-input manifest](<C:/Users/sutte/Documents/Codex/ac06-stage-a1/TESTED_INPUTS.sha256>) contains 1,252 inputs. SHA-256 `0f755ff83deb85ffceb63bb44983a2988051aaf09e3114e0c432653bea24701c`.
- Windows EXE SHA-256 `30830da5459ddec145f90d6c5c3e02dcc8d8ac57c8032aad95bf0567b094bafe`. Native DLL SHA-256 `ad827586970b7d701af85007185fa2ef31213666add81674d47c3dab96370379`.

## Remaining cutover blockers

The production flag remains disabled and `VERIFIED_WRITERS` remains empty. Default title, slots, roster, Developer Garden, legacy recovery and gameplay still need production migration and cutover validation. The legacy Error-only route still lacks B1's distinction for a late failure after marker publication, and legacy backups retain their existing direct-copy policy. This checkpoint changes pre-commit serializer integrity on that route. The guarded path handles typed outcomes. Legacy direct slot copies and legacy immediate feedback/RPCs remain listed in the Group 3C inventory.

Stage A2 still owns guest success publication and acknowledgment. Host persistence does not establish guest receipt or guest-profile persistence. Older builds must be kept away from migrated roots before activation. Ambiguous evidence, including contradictory migration backup bytes, still requires explicit review. No live saves or installed binaries were used. This checkpoint is focused verification, with full release acceptance pending.
