extends RefCounted
## Every inventoried production entry must be bound and verified before cutover.
## There is no settings, feature-flag or environment override for this checkpoint.

const PRODUCTION_CUTOVER_APPROVED := false
const REQUIRED_WRITERS = {
 "save_batch.gd::write_bytes/write": "raw writes, staging and standalone replacement",
 "save_batch.gd::begin/commit/cancel": "journal creation, replacement and staging cleanup",
 "save_batch.gd::recover": "linked recovery and artifact cleanup",
 "app_settings.gd::save_settings": "shared SaveBatch caller that can join an active batch",
 "game_transaction.gd::run": "transaction ownership and commit-outcome handling",
 "progress.gd::save_garden/load_garden": "Garden serialization, migration backups and recovery",
 "character_profile.gd::save_profile/load_profile": "profile serialization, migration backups and recovery",
 "save_slots.gd::prepare/ensure_character": "legacy import and per-world profile creation",
 "save_slots.gd::new_game/new_world": "world creation and replacement, including Developer Garden reset",
 "save_slots.gd::delete_save/archive_deleted_save/restore_deleted_save": "pair archive, tombstone and compensation",
 "save_slots.gd::delete_world": "world archive, tombstone and canonical removal",
 "save_slots.gd::claim/heartbeat/release": "world and roster session markers",
 "save_slots.gd::remember_slot": "world selection metadata",
 "character_slots.gd::prepare/summary": "roster import and recovery-capable browsing",
 "character_slots.gd::create/update": "roster serialization and leases",
 "character_slots.gd::set_capacity/remember": "roster catalog updates",
 "character_slots.gd::delete_character/remove_character": "profile recovery, archive, catalog and compensation",
}
# Record production entry points here only once the actual call sites enforce the
# scope and both source and packaged writer fixtures cover refusal and success.
const VERIFIED_WRITERS = []
# Group 1 adds guarded routes. Existing production callers still bypass them.
const GROUP_1_GUARDED_ROUTES = {
 "save_batch.gd::_run_guarded/_recover_guarded": "scoped stage, finalize and recovery",
 "game_transaction.gd::run_guarded": "typed outcomes and guarded nested actions",
 "progress.gd::save_garden_guarded/load_garden_guarded": "guarded Garden serialization and pending-aware load",
 "character_profile.gd::save_profile_guarded/load_profile_guarded": "guarded profile serialization and pending-aware load",
}

# Verified dormant routes. Production callers and occupied-slot archives remain open.
const GROUP_2A_GUARDED_ROUTES = {
 "save_slots.gd::prepare_guarded/ensure_character_guarded": "legacy import and profile creation",
 "save_slots.gd::new_game_guarded/new_world_guarded": "vacant-slot creation only",
 "save_slots.gd::claim_guarded/heartbeat_guarded/release_guarded/remember_slot_guarded": "scoped lease and preference writes",
 "character_slots.gd::prepare_guarded/create_guarded/update_guarded": "roster import and profile management",
 "character_slots.gd::set_capacity_guarded/remember_guarded": "locked catalog read-modify-write",
 "character_slots.gd::claim_guarded/heartbeat_guarded/release_guarded": "scoped roster lease writes",
}

static func activation_status() -> Dictionary:
 var blockers := PackedStringArray()
 for writer: String in REQUIRED_WRITERS:
  if not VERIFIED_WRITERS.has(writer):
   blockers.append(writer)
 if not PRODUCTION_CUTOVER_APPROVED:
  blockers.append("production_cutover_not_approved")
 blockers.sort()
 return {"allowed": blockers.is_empty(), "blockers": blockers}