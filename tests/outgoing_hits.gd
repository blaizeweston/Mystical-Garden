extends SceneTree
## Real resolved contacts, member/life invalidation, mitigation and source scope.
const Outgoing = preload("res://outgoing_hits.gd")
const Context = preload("res://outgoing_hit_context.gd")
const Life = preload("res://player_lifecycle.gd")
const Protection = preload("res://player_protection.gd")
const Vitals = preload("res://player_vitals.gd")
const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const ArenaBridge = preload("res://neural_arena/arena_mob_bridge.gd")
var failed := false

class ContactWitness extends ArenaBridge:
	var notes: Array = []
	func note_hit(target: int, peer: int) -> void:
		notes.append([target,peer])

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL outgoing hits: ", text)

func run() -> void:
	var world: Node = load("res://world.tscn").instantiate()
	var path := "res://.godot/outgoing-hits-" + Crypto.new().generate_random_bytes(8).hex_encode()
	world.progress.path = path + ".garden"
	world.local_character.path = path + ".character"
	world.guest_character.path = path + ".guest"
	world.settings_path = path + ".settings"
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var actor: Dictionary = world.players[1]
	ExpeditionCase.set_membership(world, actor, true)
	actor.pos = Vector3.ZERO
	actor.facing = Vector3.RIGHT
	world.battlefield.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(world.battlefield, [])
	world.encounter.clear_scouts()
	world.encounter.set_hp(-1, 200)
	world.tactics.position = Vector3(2, 0, 0)
	world.tactics.winding_up = false
	world.tactics.boss_kind = -1
	world.enemy_mutations = 0
	var stats := {"damage":1.0, "knockback":-.35}
	var now := preload("res://combat_clock.gd").now()
	var observed: Array = []
	world.outgoing_contact_requested.connect(func(peer: int, target: int): observed.append([peer,target]))
	var source := Context.new(world, 1)
	var facts := source.target_facts(-1, stats, actor.pos, now)
	check(facts.is_read_only() and not facts.has("actor") and not facts.has("character"), "target facts expose no mutable actor or profile")
	var result := Outgoing.hit(source, -1, actor.pos, stats, now)
	check(result.applied_hp == 10 and world.encounter.hp(-1) == 190 and observed == [[1,-1]], "one native contact updates authoritative HP and notifies the arena hook once")
	check(not world.has_method("apply_weapon_hit") and not world.has_method("apply_skill_targets"), "the competing Game damage and class-batch implementations are retired")
	world.enemy_mutations = world.Enemies.BARK
	result = Outgoing.hit_world(world, 1, -1, actor.pos, {"damage":4.0,"knockback":-.35}, now)
	check(result.applied_hp == 30 and world.enemy_health() == 160, "native Bark retains its 25 percent mitigation")
	world.enemy_mutations = 0
	result = Outgoing.hit_world(world, 1, -1, actor.pos, {"damage":1.0,"preview_roll_delta":2,"native_bonus_hp":3,"knockback":-.35}, now)
	check(result.applied_hp == 15 and world.enemy_health() == 145, "weapon roll and an explicit native bonus retain their resolved HP values")
	actor[Protection.STATE] = actor[Protection.STATE].prepare_counter(now+1000, 2.0)
	result = Outgoing.hit_world(world, 1, -1, actor.pos, {"damage":0.0,"affinity_hp":7,"trait_secondary":true,"core_hit":true,"preview_power":99,"preview_roll_delta":99,"knockback":-.35}, now)
	check(result.applied_hp == 7 and actor[Protection.STATE].counter_ready(now), "secondary affinity HP neither spends a counter nor inherits weapon power/roll")
	Outgoing.hit_world(world, 1, -1, actor.pos, stats, now)
	check(world.enemy_health() == 108 and not actor[Protection.STATE].counter_ready(now), "the next native contact alone spends the 20-HP counter")
	var before: int = world.enemy_health()
	check(Outgoing.hit_world(world, 999, -1, actor.pos, stats, now).is_empty() and world.enemy_health() == before, "an unknown native source cannot apply damage")
	Outgoing.affinity_world(world, 999, -1, 7, now, Color.PURPLE)
	check(world.enemy_health() == before-7 and not world.combat_threat.has(999), "already-accepted departed-source affinity HP completes without a fake player or native credit")
	check(Outgoing.hit(Context.new(world, 999, true), -1, actor.pos, stats, now).is_empty(), "the departed-affinity exception cannot authorize an ordinary hit")
	var old_life := Context.new(world, 1)
	actor[Life.STATE] = Life.start_life()
	before = world.enemy_health()
	check(Outgoing.hit(old_life, -1, actor.pos, stats, now).is_empty() and world.enemy_health() == before, "previous-life contexts cannot damage an enemy")
	var old_floor := Context.new(world, 1)
	ExpeditionCase.set_world(world, {"combat_epoch":world.participation.epoch()+1})
	check(Outgoing.hit(old_floor, -1, actor.pos, stats, now).is_empty() and world.enemy_health() == before, "previous-floor contexts cannot damage the current roster")
	var replaced_actor := Context.new(world, 1)
	world.players[1] = actor.duplicate()
	check(Outgoing.hit(replaced_actor, -1, actor.pos, stats, now).is_empty() and world.enemy_health() == before, "a replaced actor cannot inherit the same-life context")
	world.players[1] = actor
	var first: Dictionary = world.make_scout(0, Vector3(1,0,0), 1)
	var second: Dictionary = world.make_scout(0, Vector3(2,0,0), 2)
	first.hp=100; second.hp=100
	world.encounter.register_scout(first)
	world.encounter.register_scout(second)
	var stale_token: int = world.encounter.spawn_identity(1)
	world.encounter.despawn(1)
	world.encounter.register_scout(world.make_scout(0, Vector3(2,0,0), 2), 1)
	before = world.encounter.hp(1)
	check(Outgoing.hit_world(world, 1, 1, actor.pos, stats, now, stale_token).is_empty() and world.encounter.hp(1) == before, "an old spawn token cannot damage the new occupant")
	# Model a synchronous death/observation hook replacing a later batch target.
	var replacing := func(_peer: int, target: int):
		if target == 0:
			world.encounter.despawn(1)
			var replacement: Dictionary = world.make_scout(0, Vector3(2,0,0), 3)
			replacement.hp = 100
			world.encounter.register_scout(replacement, 1)
	world.outgoing_contact_requested.connect(replacing)
	var targets: Array[int] = [0,1]
	var contacts := Outgoing.skill_world(world, 1, targets, {"mode":"nova","damage":1.0}, {"damage":1.0,"stagger":0,"recovery":0}, now)
	world.outgoing_contact_requested.disconnect(replacing)
	check(contacts == 1 and world.encounter.hp(0) == 90 and world.encounter.hp(1) == 100, "a native batch damages only its captured occupants and counts one real drain contact")
	var receipts: int = world.monster_rewards.pending_count()
	Outgoing.hit_world(world, 1, 0, actor.pos, {"damage":20.0,"knockback":-.35}, now)
	var killed_count: int = world.monster_rewards.pending_count()
	Outgoing.hit_world(world, 1, 0, actor.pos, {"damage":20.0,"knockback":-.35}, now)
	check(killed_count == receipts+1 and world.monster_rewards.pending_count() == killed_count, "a death is registered once and a repeated dead-target callback cannot add rewards")
	check(Vitals.current_hp(actor) == 100, "unadvertised healing is not added by the resolver")
	world.free()
	check(Outgoing.hit(source, -1, Vector3.ZERO, stats, now).is_empty(), "a released world invalidates captured contexts without touching freed nodes")
	await process_frame
	await arena_observer()
	if not failed: print("PASS: outgoing native/secondary damage, mitigation, source/floor/spawn identity, batch ownership and exactly-once death")
	quit(1 if failed else 0)


func arena_observer() -> void:
	var config = load("res://neural_arena/arena_config.gd").new()
	config.brain = config.SCRIPTED_BRAIN
	config.bots = 1
	config.enemies = {"rootbound":1}
	config.floor_number = 1
	config.generated_map = false
	config.auto_restart = false
	var arena: Node = load("res://world.tscn").instantiate()
	arena.set_script(load("res://neural_arena/arena_world.gd"))
	arena.config = config
	arena.headless_driver = true
	root.add_child(arena)
	arena.begin_session()
	check_arena_movement(arena, config)
	if arena.bridge != null:
		var now := preload("res://combat_clock.gd").now()
		arena.bridge.tick(now)
		var cursor: int = arena.bridge.sim.events.head
		var before: int = arena.encounter.hp(0)
		var result := Outgoing.hit_world(arena, 1, 0, arena.players[1].pos, {"damage":.1,"knockback":-.35}, now)
		arena.bridge.tick(now)
		var events: Array = arena.bridge.sim.events.read_since(cursor).filter(func(event):
			return event.kind == preload("res://mob_sim/mob_events.gd").Kind.DAMAGE_TAKEN)
		check(result.applied_hp == 1 and arena.encounter.hp(0) == before-1, "Arena uses the same authoritative outgoing damage once")
		check(events.size() == 1 and arena.bridge.peer_of(int(events[0].a)) == 1 and int(events[0].value) == 1,
			"the migrated observer retains one real simulation damage receipt with the correct player credit")
	else:
		# Source checkouts may omit the optional native navigation DLL. This
		# checks the actual Arena signal/override without claiming a sim run.
		var witness := ContactWitness.new(arena, config)
		arena.bridge = witness
		var before: int = arena.encounter.hp(0)
		var now := preload("res://combat_clock.gd").now()
		var result := Outgoing.hit_world(arena, 1, 0, arena.players[1].pos, {"damage":.1,"knockback":-.35}, now)
		check(result.applied_hp == 1 and arena.encounter.hp(0) == before-1 and witness.notes == [[0,1]],
			"actual Arena observer wiring keeps one hit and correct peer credit when the optional sim backend is absent")
		print("LIMIT: native Arena simulation unavailable; observer wiring verified without mob_sim/bin/mob_nav.dll")
	arena.free()
	await process_frame

## The speed adapter and simulation spawn table are testable without native nav.
func check_arena_movement(arena: Node, config: RefCounted) -> void:
	var catalog = preload("res://enemy_catalog.gd")
	var pool_script = preload("res://mob_sim/mob_pool.gd")
	var species = preload("res://mob_sim/mob_species.gd").new()
	var pool = pool_script.new(1, species.ATTACKS)
	var request = pool_script.Spawn.new()
	request.mutations = catalog.MOBILITY | catalog.JUVENILE
	check(pool.spawn_at(0,request,species,0,1)==0, "real simulation spawn uses the mutated ordinary species")
	check(is_equal_approx(pool.speed[0],species.speed[0]*1.18*1.15), "simulated spawn applies both permanent speed mutations once")
	var bridge := ArenaBridge.new(arena,config)
	var sample := {"kind":0,"mutations":request.mutations,"haste_until":1001}
	var base: float = arena.Director.speed(arena,float(catalog.get_kind(0).speed))
	check(is_equal_approx(bridge._speed(sample,1000),base*1.18*1.15), "arena mirrors permanent speed and leaves temporary haste to its simulation clock")
	check(is_equal_approx(catalog.movement_speed(base,request.mutations,true),base*1.18*1.22*1.15), "ordinary scout updates apply supported haste exactly once")
