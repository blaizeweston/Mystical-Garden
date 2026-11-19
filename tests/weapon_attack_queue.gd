extends SceneTree
## Ownership, cancellation and rollback; delivery integration lives in the retained
## weapon/terrain/class suites. All saves are disposable fixture paths.
const Case = preload("res://tests/support/weapon_attack_case.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
const Life = preload("res://player_lifecycle.gd")
const Actions = preload("res://player_weapon_actions.gd")
const Transactions = preload("res://game_transaction.gd")
const Events = preload("res://combat_action_events.gd")
var failed := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL weapon queue: ", label)

func run() -> void:
	var world: Node = load("res://world.tscn").instantiate()
	var base := "res://.godot/weapon-queue-" + str(OS.get_process_id())
	world.progress.path = base + ".garden"
	world.local_character.path = base + ".character"
	world.guest_character.path = base + ".guest"
	world.settings_path = base + ".settings"
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var actor: Dictionary = world.players[1]
	Expedition.set_membership(world, actor, true)
	actor.pos = Vector3.ZERO
	actor.facing = Vector3.BACK
	actor.mouse_aim = true
	actor.aim_direction = Vector3.BACK
	world.encounter.clear_scouts()
	preload("res://tests/support/terrain_case.gd").walls(world.battlefield, [])
	world.encounter.set_hp(-1, 1000)
	world.tactics.position = Vector3(0,0,3)
	var now := preload("res://combat_clock.gd").now()
	var stats := {"damage":1.0, "reach":6.0, "targets":1, "pattern":"single", "knockback":-.35}
	var first := Case.schedule(world, 1, actor.pos, stats, now, "bow", 300)
	stats.damage = 99
	var view: Dictionary = world.weapon_attacks.inspect(first)
	check(view.is_read_only() and view.stats.is_read_only() and view.hits.is_read_only() and float(view.stats.damage) == 1.0,
		"captured stats and detached views cannot mutate the owner")
	Case.advance(world, int(view.release) - 1)
	check(not world.weapon_attacks.inspect(first).emitted and world.enemy_health() == 1000, "release deadline enforced")
	Case.advance(world, int(view.release))
	view = world.weapon_attacks.inspect(first)
	Case.advance(world, int(view.due) + 1)
	check(world.enemy_health() == 990 and world.weapon_attacks.is_empty(), "one real hit completes and retires its record")
	Case.advance(world, int(view.due) + 1)
	check(world.enemy_health() == 990, "completed attack cannot replay")
	stats.damage = 1
	var old_life = actor[Life.STATE]
	var stale := Case.schedule(world, 1, actor.pos, stats, now, "bow", 300)
	actor[Life.STATE] = Life.start_life()
	Case.advance(world, now + 2000)
	check(world.weapon_attacks.inspect(stale).is_empty() and world.enemy_health() == 990, "previous life cancelled without damage")
	actor[Life.STATE] = old_life
	var participation: Dictionary = world.participation.savepoint()
	Case.schedule(world, 1, actor.pos, stats, now, "bow", 300)
	Expedition.set_world(world, {"combat_epoch":world.participation.epoch() + 1})
	Case.advance(world, now + 2000)
	check(world.weapon_attacks.is_empty() and world.enemy_health() == 990, "old floor cancelled without damage")
	world.participation.restore_savepoint(participation)
	# Freeze a real event, but never expose its mutable budget in queue views.
	var event := Events.begin(world,1,"native_weapon",{}, {},["weapon_contact"],now+5000)
	stats[Events.CONTEXT] = event
	var fan := Case.schedule(world, 1, actor.pos, stats, now, "fan", 300)
	check(world.weapon_attacks.inspect(fan).stats[Events.CONTEXT] is Dictionary, "views expose event identity rather than a mutable event object")
	var release: int = world.weapon_attacks.inspect(fan).release
	Case.advance(world, release)
	var snapshot: Dictionary = world.weapon_attacks.savepoint()
	var count: int = world.weapon_attacks.pending_count()
	check(count == 3, "fan creates its authored three lanes")
	var reserved := Case.schedule(world,1,actor.pos,stats,now,"bow",300)
	world.weapon_attacks.restore_savepoint(snapshot)
	check(world.weapon_attacks.pending_count() == count and world.weapon_attacks.inspect(reserved).is_empty(), "rollback removes only uncommitted queue records")
	# The restored petals still share the same hit budget. A wide body is swept by
	# multiple lanes; contact events and HP must show one hit, not one per copy.
	Case.advance(world, now + 2000)
	check(world.enemy_health() == 980 and world.weapon_attacks.is_empty(), "rollback preserves shared fan-hit exclusion")
	var next := Case.schedule(world,1,actor.pos,stats,now,"bow",300)
	check(next > reserved, "rollback never reuses a failed queue identity")
	var runtime: Dictionary = world.snapshot_expedition_runtime()
	world.weapon_attacks.clear()
	world.restore_expedition_runtime(runtime)
	check(world.weapon_attacks.inspect(next).queue_id == next, "guarded runtime savepoint restores the queue owner")
	var verdict := {}
	var result = Transactions.run(world, func():
		world.weapon_attacks.clear()
		Case.schedule(world,1,actor.pos,stats,now,"bow",300)
		preload("res://save_batch.gd").record_serializer_error(ERR_FILE_CANT_WRITE,world.progress.path)
		return true, verdict)
	check(not result and verdict.error != OK and world.weapon_attacks.pending_count() == 1
		and world.weapon_attacks.inspect(next).queue_id == next, "confirmed compatibility transaction rollback restores the original pending attack")
	world.weapon_attacks.clear()
	# Held input samples time at the request, as the former Game launch did;
	# stale-input validation may still use the earlier physics-stage observation.
	var clock = preload("res://combat_clock.gd")
	clock.begin_stepped(100000)
	var requested_at: Array = []
	world.mouse_controls.attack_requested.connect(func(_peer, _origin, at): requested_at.append(at))
	world.mouse_controls.receive(world,1,Vector2(0,1),true,clock.now())
	var input_observed_at: int = clock.now()
	clock.step()
	world.mouse_controls.tick(world,input_observed_at)
	check(requested_at == [clock.now()] and not world.weapon_attacks.is_empty()
		and int(world.weapon_attacks.views().front().release) >= clock.now(), "held-input admission retains fresh shared-clock timing")
	clock.end_stepped()
	world.weapon_attacks.clear()
	check(not world.has_method("strike_enemy") and not world.has_method("update_projectiles")
		and world.get("projectile_queue") == null, "old mutable Game queue and dispatch paths are retired")
	world.free()
	if not failed: print("PASS: private weapon queue, detached views, release/contact, stale life/floor, fan rollback, stable identity and runtime cleanup")
	quit(1 if failed else 0)
