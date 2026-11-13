extends SceneTree

const Tx = preload("res://game_transaction.gd")
const Batch = preload("res://save_batch.gd")
const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Owner = preload("res://guarded_title_session.gd")
const Ops = preload("res://persistence_operations.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Growth = preload("res://garden_growth_service.gd")
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
 var garden := Tx.run_guarded(world, func(): world.progress.knowledge = 21; return false, Callable(), Tx.Scope.GARDEN)
 verify("garden_false_business_commit", garden, Batch.Outcome.COMMITTED, before)
 check(garden.value.value == false and disk()[G] != before[G] and disk()[C] == before[C], "false callback value independent of Garden-only commit")
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
 world.garden_action(world.HOST, "plant_at_0_0")
 check(world.progress.plots[0].species == 0 and world.seed_reserve(host).stock[0] == 0
  and disk()[G] != before[G] and disk()[C] == before[C], "planting consumes the seed in a Garden-only commit")
 record("planting", before)
 before = disk()
 host.pos = world.Stage.ALTAR
 world.seed_reserve(host).unknown.append(1)
 world.garden_action(world.HOST, "altar_identify")
 check(world.seed_reserve(host).unknown.is_empty() and world.status.begins_with("Identified ")
  and disk()[G] != before[G] and disk()[C] == before[C], "identification uses a Garden-only commit before feedback")
 record("altar_identification", before)

 before = disk()
 var pair := Tx.run_guarded(world, func():
  world.progress.knowledge = 22
  var nested := Tx.run_guarded(world, func():
   world.players[world.HOST].character.name = "Nested success"
   return world.local_character.save_profile(), Callable(), Tx.Scope.PROFILE)
  check(nested.get("nested", false) and nested.value == OK, "nested profile reused owning context")
  return null, Callable(), Tx.Scope.PAIR)
 verify("pair_null_business_commit", pair, Batch.Outcome.COMMITTED, before)
 check(pair.value.value == null and disk()[G] != before[G] and disk()[C] != before[C], "pair saves both canonical files")
 before = disk()
 var old_rng: int = world.rng.state
 var unrelated = preload("res://character_profile.gd").new()
 unrelated.path = "user://saves/characters/slot_2/character.cfg"
 var aborted := Tx.run_guarded(world, func():
  world.progress.knowledge = 31
  world.players[world.HOST].character.name = "Rejected"
  world.rng.randi()
  var nested := Tx.run_guarded(world, func():
   check(unrelated.save_profile() == ERR_UNAUTHORIZED, "foreign nested serializer rejected")
   check(world.progress.save_garden() == ERR_UNAUTHORIZED, "later serializer retains first error"), Callable(), Tx.Scope.PROFILE)
  check(nested.get("nested", false), "nested business callback executed")
  return true, Callable(), Tx.Scope.PAIR)
 verify("nested_first_error", aborted, Batch.Outcome.ABORTED_RESTORED, before)
 check(final(aborted).original_error == ERR_UNAUTHORIZED and disk() == before and world.progress.knowledge == 22
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
 var cleaned := Tx._run_guarded(world, func(): world.progress.knowledge = 44, Callable(),
  func(phase, _path): return ERR_CANT_CREATE if phase == "publish_receipt" else OK, Tx.Scope.GARDEN)
 verify("cleanup_pending", cleaned, Batch.Outcome.COMMITTED_CLEANUP_PENDING, before)
 var cleanup := disk()
 check(world.progress.knowledge == 44 and not Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.GARDEN).ran
  and disk() == cleanup, "cleanup pending retains committed state and blocks new writes")
 check(Ops.recover(PackedStringArray([G])).value.verified and disk()[G] == cleanup[G], "B2 cleans confirmed commit")
 world.free()
 world = start(stores.slots, stores.roster, true)
 if world == null: return

 before = disk()
 var unsure := Tx._run_guarded(world, func():
  world.progress.knowledge = 51
  world.players[world.HOST].character.name = "Tentative", Callable(), func(phase, path):
   if phase == "replace" and path == G: return ERR_CANT_CREATE
   return ERR_FILE_CANT_WRITE if phase == "restore" else OK, Tx.Scope.PAIR)
 verify("uncertain_pair", unsure, Batch.Outcome.UNCERTAIN, before)
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
 var foreign := Tx.run_guarded(world, refuse_action, Callable(), Tx.Scope.PAIR)
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
 world.receive_character(incoming)
 check(world.guest_character.data.name == incoming.name and disk()[G] == before[G] and disk()[C] != before[C], "guest RPC persists only its claimed profile")
 record("guest_profile_rpc", before)
 var profile_lease := C.get_base_dir().path_join("session.cfg")
 marker(profile_lease, OS.get_process_id(), 60)
 before = disk()
 incoming.name = "Delayed stale RPC"
 world.receive_character(incoming)
 check(world.guest_character.data.name == "Guest update" and not world.character_dirty and disk() == before, "delayed guest RPC does not mutate memory or disk")
 record("delayed_guest_rpc", before)
 world.free()
 check(DirAccess.remove_absolute(profile_lease) == OK, "dispose injected expired profile lease")
 check(not preload("res://persistence_writer_integration.gd").activation_status().allowed, "production gate disabled")
 if not failed: print("PASS: guarded gameplay transactions")
 quit(1 if failed else 0)

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
