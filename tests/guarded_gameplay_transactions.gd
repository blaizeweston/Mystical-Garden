extends SceneTree

const Tx = preload("res://game_transaction.gd")
const Batch = preload("res://save_batch.gd")
const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Owner = preload("res://guarded_title_session.gd")
const Ops = preload("res://persistence_operations.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Growth = preload("res://garden_growth_service.gd")
const Conduit = preload("res://garden_conduit.gd")
const CleanupNotice := "Saved. Recovery cleanup is pending. Further saves are blocked."
const G := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
const PEER := 9021
const SUFFIXES = ["", ".pre-content-v2.bak", ".pre-content-v2.bak.tmp"]
var failed := false

func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func disk() -> Dictionary:
 var result := {}
 for path in [G, C]:
  for suffix: String in SUFFIXES + Plan.ARTIFACTS:
   result[path + suffix] = Slots._save_digest(path + suffix)
 return result

func record(id: String, before: Dictionary, result := {}) -> void:
 print("CASE ", JSON.stringify({"case": id, "run_id": OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "before": before, "after": disk(), "result": result}))

func final(boundary: Dictionary) -> Batch.Finalization:
 return boundary.value.get("outcome") if boundary.get("value") is Dictionary else null

func verify(id: String, boundary: Dictionary, expected: Batch.Outcome, before: Dictionary) -> void:
 var outcome := final(boundary)
 check(outcome != null and outcome.outcome == expected, id + " typed outcome")
 if outcome == null:
  record(id, before, boundary)
  return
 record(id, before, {"outcome": Batch.Outcome.keys()[outcome.outcome], "phase": outcome.phase,
  "attempt": outcome.attempt_id, "paths": outcome.paths, "original_error": outcome.original_error,
  "recovery_error": outcome.recovery_error, "cleanup_error": outcome.cleanup_error,
  "write_blocked": outcome.write_blocked, "verification": outcome.verification})

func start(slots: RefCounted, roster: RefCounted, garden: bool) -> Node:
 var world = load("res://world.tscn").instantiate()
 world.progress.path = G
 world.local_character.path = C
 world.guest_character.path = C
 world.joined_from_title = not garden
 world.slot_claimed = garden
 var owner := Owner.new()
 var result := owner.start(world, slots if garden else null, 0, Slots._save_digest(G) if garden else "",
  roster, 0, Slots._save_digest(C))
 check(Owner.completed(result), "guarded launch " + str(result))
 if not Owner.completed(result):
  world.free()
  quit(1)
  return null
 root.add_child(world)
 world.set_process(false)
 world.set_physics_process(false)
 world.get_node("GardenInteractions/GrowthScenes").set_process(false)
 return world

func marker(path: String, pid: int, age: float) -> void:
 var cfg := ConfigFile.new()
 cfg.set_value("session", "process_id", pid)
 cfg.set_value("session", "updated", Time.get_unix_time_from_system() - age)
 check(cfg.save(path) == OK, "disposable lease marker")

func refuse_action() -> Variant:
 check(false, "refused transaction entered its action")
 return null

func seed_save_set() -> Dictionary:
 var slots := Slots.new()
 var roster := Roster.new()
 check(Owner.completed(Owner.prepare(slots, roster, false)), "prepare isolated roots")
 check(Owner.completed(Owner.outcome(slots.new_world_guarded(0))), "Garden created")
 check(Owner.completed(Owner.outcome(roster.create_guarded(0, "Test Wanderer", 0, []))), "roster profile created")
 return {"slots": slots, "roster": roster}

func run() -> void:
 var mode := OS.get_environment("MYSTICAL_GROUP3B1_MODE")
 if not mode.is_empty():
  interrupted(mode)
  return

 var stores := seed_save_set()
 var world := start(stores.slots, stores.roster, true)
 if world == null: return
 check(world.has_meta(Tx.SESSION) and world.progress.require_guarded_access, "real session and raw save refusal enabled")
 var before := disk()
 var garden := Tx.run_gameplay(world, Tx.Scope.GARDEN, func(): world.progress.knowledge = 21; return false)
 verify("garden_false_business_commit", garden.persistence, Batch.Outcome.COMMITTED, before)
 check(garden.completed and garden.value == false and disk()[G] != before[G] and disk()[C] == before[C], "false callback value independent of Garden-only commit")
 before = disk()
 world.garden_action(world.HOST, "look_0")
 check(disk()[G] == before[G] and disk()[C] != before[C], "actual appearance action writes only local profile")
 record("appearance_profile_only", before, {"appearance": world.local_character.data.appearance})
 before = disk()
 world.progress.garden_interactions.growth.seen.erase(world.local_character.identity)
 check(Growth.register(world, world.HOST) and disk()[G] != before[G], "actual growth receipt transaction commits")
 record("growth_registration", before)
 before = disk()
 var host: Dictionary = world.players[world.HOST]
 host.pos = world.Stage.PLOTS[0]
 world.seed_reserve(host).stock[0] = 1
 world.show_planting_picker(world.HOST,0)
 check(world.planting_menu.visible,"ordinary planting starts with an open picker")
 world.garden_action(world.HOST, "plant_at_0_0")
 check(world.progress.plots[0].species == 0 and world.seed_reserve(host).stock[0] == 0
  and disk()[G] != before[G] and disk()[C] == before[C] and world.status.ends_with("planted.")
  and not world.planting_menu.visible, "ordinary planting commits, reports success and closes the picker")
 record("planting", before)
 before = disk()
 host.pos = world.Stage.ALTAR
 world.seed_reserve(host).unknown.append(1)
 world.garden_action(world.HOST, "altar_identify")
 check(world.seed_reserve(host).unknown.is_empty() and world.status.begins_with("Identified ")
  and disk()[G] != before[G] and disk()[C] == before[C], "identification uses a Garden-only commit before feedback")
 record("altar_identification", before)

 before = disk()
 var pair := Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  world.progress.knowledge = 22
  var nested := Tx.run_guarded(world, func():
   world.players[world.HOST].character.name = "Nested success"
   return world.local_character.save_profile(), Callable(), Tx.Scope.PROFILE)
  check(nested.get("nested", false) and nested.value == OK, "nested profile reused owning context")
  return null)
 verify("pair_null_business_commit", pair.persistence, Batch.Outcome.COMMITTED, before)
 check(pair.completed and pair.value == null and disk()[G] != before[G] and disk()[C] != before[C], "null callback value independent of paired commit")
 before = disk()
 var old_rng: int = world.rng.state
 var unrelated = preload("res://character_profile.gd").new()
 unrelated.path = "user://saves/characters/slot_2/character.cfg"
 var aborted := Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  world.progress.knowledge = 31
  world.players[world.HOST].character.name = "Rejected"
  world.rng.randi()
  var nested := Tx.run_guarded(world, func():
   check(unrelated.save_profile() == ERR_UNAUTHORIZED, "foreign nested serializer rejected")
   check(world.progress.save_garden() == OK, "later serializer can stage without clearing the first error"), Callable(), Tx.Scope.PROFILE)
  check(nested.get("nested", false), "nested business callback executed")
  return true)
 verify("nested_first_error", aborted.persistence, Batch.Outcome.ABORTED_RESTORED, before)
 check(not aborted.completed and aborted.value == null and aborted.notice.contains("original state was verified"),
  "verified abort reports rollback without exposing the successful callback value")
 check(final(aborted.persistence).original_error == ERR_UNAUTHORIZED and disk() == before and world.progress.knowledge == 22
  and world.players[world.HOST].character.name == "Nested success" and world.rng.state == old_rng, "verified abort restores Garden, profile and RNG")
 var refused := Tx.run_guarded(world, func():
  check(not Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.PROFILE).ran, "nested cannot expand participant set")
  return true, Callable(), Tx.Scope.GARDEN)
 verify("scope_expansion_aborts", refused, Batch.Outcome.ABORTED_RESTORED, before)
 check(disk() == before, "nested scope refusal preserves bytes")
 check(world.progress.save_garden() == ERR_UNAUTHORIZED and world.local_character.save_profile() == ERR_UNAUTHORIZED
  and world.progress.load_garden() == ERR_UNAUTHORIZED and disk() == before, "no standalone legacy fallback")
 var retry := Tx.run_guarded(world, func(): world.progress.knowledge = 23, Callable(), Tx.Scope.GARDEN)
 check(Tx.committed(retry), "retry after verified abort")

 before = disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_receipt)
 var cleaned := Tx.run_gameplay(world, Tx.Scope.GARDEN, func():
  world.progress.knowledge = 44
  return "ordinary success")
 world.remove_meta(&"guarded_gameplay_test_fault")
 verify("cleanup_pending", cleaned.persistence, Batch.Outcome.COMMITTED_CLEANUP_PENDING, before)
 check(Tx.committed(cleaned.persistence) and cleaned.completed and cleaned.value == "ordinary success"
  and cleaned.notice == CleanupNotice, "gameplay result preserves success alongside cleanup pending")
 var cleanup := disk()
 check(world.progress.knowledge == 44 and not Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.GARDEN).ran
  and disk() == cleanup, "cleanup pending retains committed state and blocks new writes")
 check(Ops.recover(PackedStringArray([G])).value.verified and disk()[G] == cleanup[G], "B2 cleans confirmed commit")
 world.free()
 world = start(stores.slots, stores.roster, true)
 if world == null: return

 before = disk()
 world.set_meta(&"guarded_gameplay_test_fault", func(phase, path):
  if phase == "replace" and path == G: return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase == "restore" else OK)
 var unsure := Tx.run_gameplay(world, Tx.Scope.PAIR, func():
  world.progress.knowledge = 51
  world.players[world.HOST].character.name = "Tentative"
  return "ordinary success")
 world.remove_meta(&"guarded_gameplay_test_fault")
 verify("uncertain_pair", unsure.persistence, Batch.Outcome.UNCERTAIN, before)
 check(not unsure.completed and unsure.value == null and unsure.notice.begins_with("Save state is uncertain"),
  "uncertain outcome withholds the callback value and ordinary success")
 world.tell(world.HOST,"later message")
 world.receive_message("later notification")
 world.refresh_feedback()
 check(world.feedback.text.contains(unsure.notice),"uncertain feedback remains visible")
 var split := disk()
 check(world.progress.knowledge == 51 and split[G] == before[G] and split[C] != before[C]
  and not Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.PAIR).ran and disk() == split, "uncertain keeps memory and evidence without automatic replay")
 check(Ops.recover(PackedStringArray([C])).value.verified and disk() == before, "B2 reverse recovery restores original pair")
 world.free()
 world = start(stores.slots, stores.roster, true)
 if world == null: return

 var cfg := ConfigFile.new()
 cfg.set_value("transaction", "entries", {G: {"exists": true, "bytes": FileAccess.get_file_as_bytes(G)}})
 cfg.set_value("transaction", "committed", false)
 check(cfg.save(G + ".transaction") == OK, "disposable pending journal")
 before = disk()
 var pending := Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.GARDEN)
 check(not pending.ran and pending.state == "pending_recovery" and disk() == before, "pending journal is passive")
 record("pending_recovery", before, pending)
 check(Ops.recover(PackedStringArray([G])).value.verified, "remove pending journal via dedicated recovery")
 world.free()

 world = start(stores.slots, stores.roster, true)
 if world == null: return
 world.session = "Host"
 world.add_player(PEER)
 world.players[PEER].seed_owner = "departing-peer"
 world.players[PEER].profile_ready = true
 world.players[PEER].safe_items = [{"item": "unidentified_seed", "quantity": 1, "seeds": [0]}]
 before = disk()
 world.multiplayer.peer_disconnected.emit(PEER)
 check(not world.players.has(PEER) and world.progress.character_records.has("departing-peer")
  and disk()[G] != before[G], "owned disconnect settles safe pouch and character record")
 record("owned_host_disconnect", before)
 world.add_player(PEER)
 var peer: Dictionary = world.players[PEER]
 peer.seed_owner = "late-peer"
 peer.profile_ready = true
 peer.wild = true
 peer.safe_items = [{"item": "unidentified_seed", "quantity": 1, "seeds": [0]}]
 world.pending_kill_rewards = [{"key":"late", "rewards":[{"id":PEER}]}]
 var memory: Dictionary = world.progress.character_records.duplicate(true)
 var receipts: Dictionary = world.progress.garden_interactions.duplicate(true)
 var lease := G.get_base_dir().path_join("session.cfg")
 marker(lease, OS.get_process_id() + 1, 0)
 before = disk()
 var refused_feedback := Tx.run_gameplay(world, Tx.Scope.PAIR, refuse_action)
 var foreign: Dictionary = refused_feedback.persistence
 check(not refused_feedback.completed and refused_feedback.value == null, "authorization refusal has no gameplay completion")
 world.multiplayer.peer_disconnected.emit(PEER)
 check(not foreign.ran and not world.players.has(PEER) and world.pending_kill_rewards.size() == 1
  and world.progress.character_records == memory and world.progress.garden_interactions == receipts and disk() == before, "late host disconnect only cleans network state after lease loss")
 record("late_host_disconnect_foreign_lease", before, foreign)
 marker(lease, OS.get_process_id(), 60)
 var expired := Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.GARDEN)
 check(not expired.ran and disk() == before, "expired same-process lease refused")
 record("expired_lease", before, expired)
 world.free()
 check(DirAccess.remove_absolute(lease) == OK, "dispose injected expired lease")

 world = start(stores.slots, stores.roster, false)
 if world == null: return
 world.session = "Guest"
 before = disk()
 var unclaimed := Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.GARDEN)
 check(not unclaimed.ran and disk() == before, "guest cannot write unclaimed Garden")
 var incoming: Dictionary = world.guest_character.data.duplicate(true)
 incoming.name = "Guest update"
 var projection = load("res://guest_profile_projection.gd")
 var origin := "1556b13a059b48c0ac2483f2591daa60"
 world.set_meta(&"guest_projection_origin",origin)
 var descriptor: Dictionary = projection.build(incoming,1,{"revision":0,"digest":projection.digest(world.guest_character.data)})
 world.receive_character({"profile":incoming,"origin":origin,"projection":descriptor})
 check(world.guest_character.data.name == incoming.name and disk()[G] == before[G] and disk()[C] != before[C], "guest RPC persists only its claimed profile")
 record("guest_profile_rpc", before)
 var profile_lease := C.get_base_dir().path_join("session.cfg")
 marker(profile_lease, OS.get_process_id(), 60)
 before = disk()
 incoming.name = "Delayed stale RPC"
 descriptor = projection.build(incoming,2,{"revision":1,"digest":descriptor.digest})
 world.receive_character({"profile":incoming,"origin":origin,"projection":descriptor})
 check(world.guest_character.data.name == "Guest update" and not world.character_dirty and disk() == before, "delayed guest RPC does not mutate memory or disk")
 record("delayed_guest_rpc", before)
 world.free()
 check(DirAccess.remove_absolute(profile_lease) == OK, "dispose injected expired profile lease")
 verify_cleanup_feedback(stores)
 check(not preload("res://persistence_writer_integration.gd").activation_status().allowed, "production gate disabled")
 if not failed: print("PASS: guarded gameplay transactions")
 quit(1 if failed else 0)

func fail_receipt(phase: String, _path: String) -> Error:
 return ERR_CANT_CREATE if phase == "publish_receipt" else OK

func verify_cleanup_feedback(stores: Dictionary) -> void:
 for feature in ["planting", "altar", "conduit", "watering", "explicit_garden"]:
  var world := start(stores.slots, stores.roster, true)
  if world == null: return
  var host: Dictionary = world.players[world.HOST]
  var before := disk()
  var previous_event: int = world.combat_event_serial
  var attempts := {"receipts":0, "replacements":0}
  world.set_meta(&"guarded_gameplay_test_fault",func(phase, path):
   if phase == "publish_receipt": attempts.receipts += 1
   if phase == "replace": attempts.replacements += 1
   return fail_receipt(phase,path))
  var ordinary := ""
  match feature:
   "planting":
    host.pos = world.Stage.PLOTS[1]
    world.seed_reserve(host).stock[0] = 1
    world.show_planting_picker(world.HOST,1)
    var seed_button: Button = world.planting_view.grid.get_child(0)
    seed_button.pressed.emit()
    world.planting_view.confirm.pressed.emit()
    world.refresh_feedback()
    check(world.progress.plots[1].species == 0 and world.seed_reserve(host).stock[0] == 0, "cleanup-pending plant and spent seed are retained")
    ordinary = "%s planted." % world.Progress.PLANT_NAMES[0]
    check(not world.overlay.visible and not world.planting_menu.visible,
     "confirmed cleanup-pending planting closes the picker normally")
    check(world.feedback.text.contains(CleanupNotice) and world.toast_panel.visible,
     "cleanup pending is visible after the picker closes")
   "altar":
    host.pos = world.Stage.ALTAR
    world.seed_reserve(host).unknown.append(1)
    world.garden_action(world.HOST, "altar_identify")
    ordinary = "Identified %s." % world.Seeds.NAMES[1]
    check(world.seed_reserve(host).unknown.is_empty() and host.altar_message == ordinary,
     "Altar retains the identification result")
   "conduit":
    for tech in ["clearing_1","clearing_2","irrigation","plot_4","living_conduit"]:
     world.progress.heart.complete(world.progress,tech)
    host.pos = Conduit.Layout.Catalog.point(Conduit.POINT).position
    var result := Conduit.command(world,world.HOST,{"point":Conduit.POINT,"revision":0,"mode":"deep"})
    ordinary = "Deep pulse will shape newly planted terrace crops. Existing crops keep their care choice."
    check(Conduit.state(world.progress).mode == "deep" and result.changed and result.revision == 1,
     "conduit retains the committed business result")
   "watering":
    host.pos = world.Stage.PLOTS[1]
    host.spring_water = true
    var bed: Dictionary = world.progress.plots[1]
    var result := preload("res://garden_crop_service.gd").command(world,world.HOST,{"point":"bed_2","cycle":bed.care.cycle,
     "revision":bed.care.revision,"stage":bed.stage,"action":"water_crop"})
    ordinary = "Spring water nourishes this crop. Growth is 25% faster until harvest."
    check(bed.care.get("watered",false) and not host.spring_water and result.changed
     and world.combat_event_serial == previous_event + 1,"watering consumes the charge and emits its cue once")
   "explicit_garden":
    world.progress.knowledge += 9
    ordinary = "Ordinary save success"
    world.save_progress(world.HOST,ordinary)
  var committed_disk := disk()
  var saved := ConfigFile.new()
  check(saved.load(G) == OK, feature + " has readable canonical Garden bytes")
  match feature:
   "planting":
    check(saved.get_value("garden","plots_v2")[1].species == 0 and saved.get_value("garden","stock_0") == 0,
     "canonical planting stores the crop and spent seed")
   "altar":
    check(saved.get_value("garden","unknown").is_empty() and saved.get_value("garden","seed_discoveries")[1],
     "canonical Altar stores the identification")
   "conduit":
    check(saved.get_value("garden_interactions","state").conduit.mode == "deep"
     and saved.get_value("garden_interactions","state").conduit.revision == 1,
     "canonical conduit stores the selected mode and revision")
  var proof := Plan.discover(PackedStringArray([G]))
  var journal := ConfigFile.new()
  check(journal.load(G + ".transaction") == OK and journal.get_value("transaction","committed",false),
   feature + " retains the committed journal")
  world.refresh_feedback()
  check(proof.state == "pending_recovery" and committed_disk[G] != before[G] and Tx.pending_notice(world) == CleanupNotice
   and world.status == ordinary and world.feedback.text.contains(ordinary) and world.feedback.text.contains(CleanupNotice)
   and world.toast_panel.visible, feature + " committed bytes, ordinary feedback and persistent warning")
  var journal_log = preload("res://diagnostic_journal.gd").current
  var event_path: String = journal_log.directory.path_join("events-%06d.jsonl" % journal_log.chunk)
  var event_rows := FileAccess.get_file_as_string(event_path).split("\n", false)
  var typed_outcome := ""
  for index in range(event_rows.size() - 1, -1, -1):
   var row: Variant = JSON.parse_string(event_rows[index])
   if row is Dictionary and row.get("event") == "guarded_gameplay_result":
    typed_outcome = row.data.get("outcome", "")
    break
  check(typed_outcome == "COMMITTED_CLEANUP_PENDING", feature + " reports the exact typed outcome")
  var committed_memory := Tx.snapshot(world.progress)
  var committed_rng: int = world.rng.state
  var committed_events: int = world.combat_event_serial
  var replacement_count: int = attempts.replacements
  var retry := Tx.run_gameplay(world, Tx.Scope.GARDEN, refuse_action)
  world.garden_action(world.HOST, "plant_at_1_0")
  world.garden_action(world.HOST, "altar_identify")
  check(not retry.completed and retry.persistence.state == "pending_recovery" and not retry.persistence.ran
   and retry.notice == CleanupNotice and disk() == committed_disk and Tx.snapshot(world.progress) == committed_memory
   and world.rng.state == committed_rng and world.combat_event_serial == committed_events
   and attempts.receipts == 1 and attempts.replacements == replacement_count,
   feature + " refuses later actions without another write, resource change, random draw or effect")
  world.remove_meta(&"guarded_gameplay_test_fault")
  world.tell(world.HOST,"later ordinary success")
  world.receive_message("later network notification")
  world.refresh_feedback()
  check(world.feedback.text.contains("later network notification") and world.feedback.text.contains(CleanupNotice),
   feature + " received notification retains warning")
  world.status = "later direct notification"
  world.refresh_feedback()
  check(world.feedback.text.contains("later direct notification") and world.feedback.text.contains(CleanupNotice),
   feature + " later messages share the channel with the warning")
  world.toggle_overlay(world.session_menu)
  world.toast_until = 0
  world.refresh_feedback()
  check(world.menu_notice.visible and world.menu_notice.text == CleanupNotice,
   feature + " warning survives toast expiry in the session menu")
  world.toggle_overlay(null)
  world.refresh_feedback()
  check(world.toast_panel.visible and world.feedback.text == CleanupNotice,
   feature + " warning remains after panel closure")
  record("cleanup_feedback_"+feature,before,{"success":ordinary,"notice":world.feedback.text,"outcome":typed_outcome,
   "journal_committed":journal.get_value("transaction","committed",false),"retry_state":retry.persistence.state,
   "retry_ran":retry.persistence.ran,"replacements":attempts.replacements,"receipt_attempts":attempts.receipts,
   "rng_unchanged_on_refusal":world.rng.state == committed_rng})
  var recovered := Ops.recover(PackedStringArray([G]))
  check(recovered.ran and recovered.value.verified and disk()[G] == committed_disk[G] and not FileAccess.file_exists(G+".transaction"),
   feature + " cleanup preserves committed bytes")
  check(not Tx.pending_notice(world).is_empty(),"old session remains blocked until reconciliation by reopening")
  world.free()
  var reconciled := start(stores.slots, stores.roster, true)
  if reconciled == null: return
  check(Tx.pending_notice(reconciled).is_empty() and Tx.session_writable(reconciled)
   and reconciled.status != ordinary and reconciled.combat_event_serial == 0 and disk()[G] == committed_disk[G],
   feature + " reopening permits writes without replaying success, audio or the action")
  reconciled.free()

 for value in [false, null]:
  var business_world := start(stores.slots, stores.roster, true)
  if business_world == null: return
  var business_before := disk()
  business_world.set_meta(&"guarded_gameplay_test_fault", fail_receipt)
  var business := Tx.run_gameplay(business_world, Tx.Scope.GARDEN, func():
   business_world.progress.knowledge += 1
   return value)
  verify("cleanup_pending_business_" + str(value),business.persistence,Batch.Outcome.COMMITTED_CLEANUP_PENDING,business_before)
  check(business.completed and business.value == value and business.notice == CleanupNotice and disk()[G] != business_before[G],
   "cleanup pending preserves legitimate business " + str(value))
  check(Ops.recover(PackedStringArray([G])).value.verified,"cleanup after business value check")
  business_world.free()

 var profile_world := start(stores.slots, stores.roster, true)
 if profile_world == null: return
 var profile_before := disk()
 profile_world.players[profile_world.HOST].character.name = "Cleanup profile"
 profile_world.character_dirty = true
 profile_world.set_meta(&"guarded_gameplay_test_fault",fail_receipt)
 check(profile_world.save_local_character() and not profile_world.character_dirty and Tx.pending_notice(profile_world) == CleanupNotice,
  "profile cleanup retains committed completion and clears the dirty flag")
 profile_world.remove_meta(&"guarded_gameplay_test_fault")
 var profile_after := disk()
 var profile_read := preload("res://character_profile.gd").new()
 profile_read.path = C
 check(profile_read.load_profile(false) == OK and profile_read.data.name == "Cleanup profile"
  and profile_after[C] != profile_before[C] and profile_after[G] == profile_before[G]
  and Plan.discover(PackedStringArray([C])).state == "pending_recovery","profile bytes committed with evidence")
 record("cleanup_feedback_explicit_profile",profile_before,{"notice":Tx.pending_notice(profile_world)})
 check(Ops.recover(PackedStringArray([C])).value.verified and disk()[C] == profile_after[C],"profile cleanup preserves new bytes")
 profile_world.free()

 var resumed := start(stores.slots, stores.roster, true)
 if resumed == null: return
 var before := disk()
 var result := Tx.run_gameplay(resumed,Tx.Scope.GARDEN,func():
  resumed.progress.knowledge += 1
  return "Ordinary save success")
 check(result.completed and result.value == "Ordinary save success" and result.notice.is_empty()
  and Tx.pending_notice(resumed).is_empty() and disk()[G] != before[G],
  "fresh authorized session resumes after cleanup")
 verify("feedback_resumed_after_cleanup",result.persistence,Batch.Outcome.COMMITTED,before)
 resumed.free()

func interrupted(mode: String) -> void:
 if mode == "owner":
  var stores := seed_save_set()
  var world := start(stores.slots, stores.roster, true)
  if world == null: return
  var before := disk()
  Tx._run_guarded(world, func():
   world.progress.knowledge = 91
   world.players[world.HOST].character.name = "Interrupted", Callable(), func(phase, path):
    if phase == "replace" and path == G:
     record("interruption_barrier", before)
     while true: OS.delay_msec(100)
    return OK, Tx.Scope.PAIR)
  check(false, "owner must be terminated at barrier")
 elif mode == "recover":
  var before := disk()
  var outcome := Ops.recover(PackedStringArray([C]))
  check(outcome.ran and outcome.value.verified, "fresh process recovers interrupted gameplay transaction")
  record("restart_recovery", before, {"verified": outcome.ran and outcome.value.verified})
 else:
  check(false, "unexpected interruption mode")
 if not failed: print("PASS: guarded gameplay restart recovery")
 quit(1 if failed else 0)
