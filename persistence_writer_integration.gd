extends RefCounted
## Every inventoried production entry must be bound and verified before cutover.
## There is no settings, feature-flag or environment override for this checkpoint.

const PRODUCTION_CUTOVER_APPROVED := false
const VALIDATION_ROUTE := &"persistence_production_route_validation"
const REQUIRED_WRITERS = {
 "save_batch.gd::write_bytes/write": "raw writes, staging and standalone replacement",
 "save_batch.gd::begin/commit/cancel": "journal creation, replacement and staging cleanup",
 "save_batch.gd::recover": "linked recovery and artifact cleanup",
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
 "main_menu.gd::_ready/launch": "candidate default title, passive selection and guarded Continue/Join",
 "developer_mode.gd::open_garden": "candidate Developer Garden creation, replacement and lease",
 "game.gd::_ready/_notification/return_to_main_menu/_exit_tree": "candidate guarded startup, close, title return and lease release",
 "game.gd::register_character/receive_character/remove_player": "candidate guarded admission, projection and disconnect",
 "persistence_operations.gd::recover_selected": "explicit recovery with confirmed evidence and idle participants",
}
const AUXILIARY_WRITERS = {
 "app_settings.gd::save_settings": "settings.cfg, standalone preferences",
 "network_settings.gd::save_settings": "network.cfg, standalone preferences",
 "diagnostic_journal.gd::record/status_file/export_report": "local diagnostics and report output",
 "game_metrics.gd::record/flush": "local metrics, published separately from canonical writes",
}
const CUTOVER_REQUIREMENTS = [
 "legacy_build_exclusion",
 "production_recovery_and_migration_validation",
 "stage_a_serializer_and_guest_acknowledgment",
]
# Record production entry points here only once the actual call sites enforce the
# scope and both source and packaged writer fixtures cover refusal and success.
const VERIFIED_WRITERS = []

static func default_route(tree: SceneTree) -> bool:
 if tree == null:
  return false
 if activation_status().allowed:
  return true
 # Internal fixture seam. No command line or player preference enables this.
 return (OS.has_feature("editor") or OS.has_feature("debug")) and DisplayServer.get_name() == "headless" and tree.has_meta(VALIDATION_ROUTE) \
  and not OS.get_environment("MYSTICAL_VALIDATION_RUN").is_empty() \
  and OS.get_user_data_dir().replace("\\", "/").contains("/.godot/vd/")
# Group 1 adds guarded routes. Existing production callers still bypass them.
const GROUP_1_GUARDED_ROUTES = {
 "save_batch.gd::_run_guarded/_recover_guarded": "scoped stage, finalize and recovery",
 "game_transaction.gd::run_guarded": "typed outcomes and guarded nested actions",
 "progress.gd::save_garden_guarded/load_garden_guarded": "guarded Garden serialization and pending-aware load",
 "character_profile.gd::save_profile_guarded/load_profile_guarded": "guarded profile serialization and pending-aware load",
}

# Verified dormant routes. Production callers remain open.
const GROUP_2A_GUARDED_ROUTES = {
 "save_slots.gd::prepare_guarded/ensure_character_guarded": "legacy import and profile creation",
 "save_slots.gd::new_game_guarded/new_world_guarded": "vacant-slot creation only",
 "save_slots.gd::claim_guarded/heartbeat_guarded/release_guarded/remember_slot_guarded": "scoped lease and preference writes",
 "character_slots.gd::prepare_guarded/create_guarded/update_guarded": "roster import and profile management",
 "character_slots.gd::set_capacity_guarded/remember_guarded": "locked catalog read-modify-write",
 "character_slots.gd::claim_guarded/heartbeat_guarded/release_guarded": "scoped roster lease writes",
}

const GROUP_2B_GUARDED_ROUTES = {
 "save_slots.gd::new_game_guarded/new_world_guarded": "verified occupied-slot backups and replacement, including Developer Garden",
 "save_slots.gd::delete_save_guarded/delete_world_guarded": "verified archives and journal-backed deletion with tombstone",
 "character_slots.gd::delete_character_guarded": "verified roster archive and journal-backed deletion with catalog",
 "save_batch.gd::_run_guarded/_recover_guarded": "canonical absence and deletion metadata compensation",
}

static func activation_status() -> Dictionary:
 var blockers := PackedStringArray()
 for writer: String in REQUIRED_WRITERS:
  if not VERIFIED_WRITERS.has(writer):
   blockers.append(writer)
 blockers.append_array(CUTOVER_REQUIREMENTS)
 if not PRODUCTION_CUTOVER_APPROVED:
  blockers.append("production_cutover_not_approved")
 blockers.sort()
 return {"allowed": blockers.is_empty(), "blockers": blockers}
