extends SceneTree
## Checks the ability handlers in the training simulation: the registry, corpse tethers, shepherd orders,
## anchored tolls, hatching, approach steps, learned landings, the choir's second beat and lantern anchors.

const Battlefield = preload("res://battlefield.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Loader = preload("res://mob_sim/definitions/definition_loader.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Registry = preload("res://mob_sim/abilities/handler_registry.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")

const BASIC := 0
const SIGNATURE := 1
const COUNTER := 2

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_registry()
	test_corpse_tether()
	test_shepherd()
	test_echo_toll()
	test_hatch()
	test_side_approach()
	test_cover_first()
	test_side_sting()
	test_second_beat()
	test_lantern()
	test_elite_kit()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_sim(slots := 8) -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [])
	var sim := Sim.new(slots)
	sim.configure(field)
	return sim


func add_mob(sim: Sim, label: String, at: Vector2, hp := 60.0) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = hp
	request.damage = 2.0
	return sim.spawn(request)


## Places player 0 and makes the given mobs know and see it.
func place_player(sim: Sim, at: Vector2, watchers: Array) -> void:
	sim.party.set_player(0, at, Vector2.ZERO, 100.0, 100.0)
	for slot in watchers:
		var row: int = int(slot) * sim.contract.players
		sim.perception.seen_tick[row] = sim.clock.tick
		sim.perception.visible[row] = 1
		sim.perception.seen_x[row] = at.x
		sim.perception.seen_z[row] = at.y
	sim.perception.refresh_allies(PackedInt32Array(watchers), sim.clock.tick)


## Advances only the clock and the abilities layer until the mob's wind-up releases.
func release(sim: Sim, slot: int) -> void:
	for step in 400:
		if sim.pool.windup_until[slot] <= 0:
			return
		sim.clock.advance()
		sim.abilities.tick_windups(sim.clock.tick)


func advance(sim: Sim, ticks: int) -> void:
	for step in ticks:
		sim.clock.advance()
		sim.abilities.tick_windups(sim.clock.tick)


func test_registry() -> void:
	var listed := PackedStringArray(Loader.HANDLERS)
	var registered := PackedStringArray(Registry.SCRIPTS.keys())
	listed.sort()
	registered.sort()
	check(listed == registered, "every handler the data names has a registered class, and no other")


func test_corpse_tether() -> void:
	var sim := make_sim()
	var bearer := add_mob(sim, "pallbearer", Vector2(0, 5))
	var escort := add_mob(sim, "rootbound", Vector2(1.5, 5))
	place_player(sim, Vector2(0, 8), [bearer])
	check(not sim.abilities.begin(bearer, BASIC, 0, sim.clock.tick), "with no corpse in reach, the tether is not cast")
	check(sim.pool.ready_at[bearer] > sim.clock.tick, "a refused tether waits before trying again")
	var fallen := add_mob(sim, "rootbound", Vector2(-2, 5))
	sim.damage_mob(fallen, 1000.0)
	sim.pool.hp[bearer] = 20.0
	sim.pool.ready_at[bearer] = 0
	place_player(sim, Vector2(0, 8), [bearer])
	check(sim.abilities.begin(bearer, BASIC, 0, sim.clock.tick), "a corpse in reach lets the tether start")
	release(sim, bearer)
	check(sim.pool.hp[bearer] > 20.0, "the tether heals the Pallbearer (%.1f)" % sim.pool.hp[bearer])
	check(sim.pool.haste_until[escort] > sim.clock.tick, "a successful tether hastes nearby fighters")
	sim.pool.ready_at[bearer] = 0
	sim.pool.cooldown_until[bearer * sim.pool.attacks] = 0
	check(not sim.abilities.begin(bearer, BASIC, 0, sim.clock.tick), "a consumed corpse cannot be tethered again")


func test_shepherd() -> void:
	var sim := make_sim()
	var shepherd := add_mob(sim, "root_shepherd", Vector2(0, 5))
	var escort := add_mob(sim, "rootbound", Vector2(2, 5))
	place_player(sim, Vector2(0, 9), [shepherd])
	check(sim.abilities.begin(shepherd, BASIC, 0, sim.clock.tick), "a shepherd with an escort starts its rally")
	release(sim, shepherd)
	check(sim.pool.command_player[escort] == 0 and sim.pool.command_until[escort] > sim.clock.tick, "the rally orders the escort onto the target")
	sim.party.set_player(1, Vector2(4, 9), Vector2.ZERO, 100.0, 100.0)
	sim.perception.seen_tick[escort * sim.contract.players + 1] = sim.clock.tick
	sim.perception.seen_tick[escort * sim.contract.players] = sim.clock.tick
	var batch = sim._awake_batch
	batch.prepare(PackedInt32Array([escort]))
	sim.rules.build_masks(batch, sim.clock.tick)
	var enemy: int = sim.contract.head_offsets[Contract.Head.ENEMY_TARGET]
	check(batch.masks[enemy + 1] == 1 and batch.masks[enemy + 2] == 0, "an ordered escort may only target the commanded player")
	var flanker_sim := make_sim()
	var flank_shepherd := add_mob(flanker_sim, "root_shepherd", Vector2(0, 5))
	var flanker := add_mob(flanker_sim, "rootbound", Vector2(2, 5))
	place_player(flanker_sim, Vector2(0, 10), [flank_shepherd])
	check(flanker_sim.abilities.begin(flank_shepherd, SIGNATURE, 0, flanker_sim.clock.tick), "a flank order starts")
	release(flanker_sim, flank_shepherd)
	check(flanker_sim.pool.command_via[flanker] == 1, "a flank order sends the escort along a bend route")


func test_echo_toll() -> void:
	var sim := make_sim()
	var bell := add_mob(sim, "bellcap", Vector2(0, 5))
	var near := add_mob(sim, "rootbound", Vector2(1.2, 5))
	var far := add_mob(sim, "thornmaw", Vector2(3.2, 5))
	place_player(sim, Vector2(0, 9), [bell])
	check(sim.abilities.begin(bell, COUNTER, 0, sim.clock.tick), "the echo toll anchors on a visible fighter")
	release(sim, bell)
	check(sim.pool.haste_until[far] > sim.clock.tick, "the toll hastes allies around its anchor")


func test_hatch() -> void:
	var sim := make_sim()
	var mother := add_mob(sim, "broodmother", Vector2(0, 5))
	place_player(sim, Vector2(0, 8), [mother])
	check(sim.abilities.begin(mother, SIGNATURE, 0, sim.clock.tick), "split nursery finds hatch sites")
	release(sim, mother)
	var hatched := 0
	for slot in sim.pool.active:
		hatched += int(sim.pool.flags[slot] & Pool.FLAG_SUMMONED != 0)
	check(hatched == 2, "split nursery hatches two juveniles (%d)" % hatched)
	sim.pool.ready_at[mother] = 0
	sim.pool.cooldown_until[mother * sim.pool.attacks + SIGNATURE] = 0
	check(not sim.abilities.begin(mother, SIGNATURE, 0, sim.clock.tick), "a Broodmother with two hatchlings out stops hatching")
	var juvenile := -1
	for slot in sim.pool.active:
		if sim.pool.flags[slot] & Pool.FLAG_SUMMONED != 0:
			juvenile = slot
	sim.damage_mob(juvenile, 1000.0)
	var corpses: Array = sim.abilities.port.corpses(mother, 20.0)
	check(corpses.is_empty(), "a hatchling leaves no corpse")


func test_side_approach() -> void:
	var sim := make_sim()
	var stag := add_mob(sim, "gallhorn", Vector2(0, 5))
	place_player(sim, Vector2(0, 8.5), [stag])
	check(not sim.abilities.begin(stag, SIGNATURE, 0, sim.clock.tick), "an angled charge steps aside before winding up")
	check(sim.pool.approach_until[stag] > sim.clock.tick and absf(sim.pool.approach_x[stag]) > 1.0, "the approach step goes to the side")
	sim.pool.approach_until[stag] = 0
	check(sim.abilities.begin(stag, SIGNATURE, 0, sim.clock.tick), "after the step, the charge winds up")


func test_cover_first() -> void:
	var sim := make_sim()
	var bell := add_mob(sim, "bellcap", Vector2(0, 5))
	var guard := add_mob(sim, "rootbound", Vector2(0, 6.5))
	place_player(sim, Vector2(0, 10), [bell])
	check(not sim.abilities.begin(bell, SIGNATURE, 0, sim.clock.tick), "a covered bell first steps behind an ally")
	var goal := Vector2(sim.pool.approach_x[bell], sim.pool.approach_z[bell])
	check(goal.y < sim.pool.xz[guard * 2 + 1], "the cover step goes behind the ally, away from the target")
	sim.pool.approach_until[bell] = 0
	check(sim.abilities.begin(bell, SIGNATURE, 0, sim.clock.tick), "the cover step happens only once")


func test_side_sting() -> void:
	var sim := make_sim()
	var wasp := add_mob(sim, "wasp", Vector2(0, 5))
	place_player(sim, Vector2(0, 7.5), [wasp])
	check(sim.abilities.begin(wasp, COUNTER, 0, sim.clock.tick), "a side sting starts within its range band")
	check(absf(sim.pool.aim_x[wasp]) > 1.0, "the side sting lands beside the target, not on it")


func test_second_beat() -> void:
	var sim := make_sim()
	sim.abilities.resolve_hits = true
	var choir := add_mob(sim, "root_choir", Vector2(0, 5))
	add_mob(sim, "rootbound", Vector2(1.5, 5))
	place_player(sim, Vector2(0, 7.5), [choir])
	var cursor := sim.events.head
	check(sim.abilities.begin(choir, SIGNATURE, 0, sim.clock.tick), "a split chorus with an escort starts")
	release(sim, choir)
	advance(sim, 60)
	var releases := sim.events.read_since(cursor).filter(func(event: Dictionary) -> bool: return event.kind == Events.Kind.RELEASE)
	check(releases.size() == 2, "the split chorus strikes a second beat (%d releases)" % releases.size())


func test_lantern() -> void:
	var sim := make_sim()
	sim.abilities.resolve_hits = true
	var lure := add_mob(sim, "lantern_lure", Vector2(0, 5))
	place_player(sim, Vector2(0, 9), [lure])
	var cursor := sim.events.head
	check(sim.abilities.begin(lure, SIGNATURE, 0, sim.clock.tick), "a side lantern starts")
	release(sim, lure)
	var hits := sim.events.read_since(cursor).filter(func(event: Dictionary) -> bool: return event.kind == Events.Kind.HIT)
	check(hits.size() == 1 and absf(float(hits[0].from_x)) > 1.0, "the pull comes from the lantern set beside the Lure")


## Elites use their species' kit with the elite size bonuses: a wider sweep for an elite Rootbound.
func test_elite_kit() -> void:
	var sim := make_sim()
	var plain := add_mob(sim, "rootbound", Vector2(0, 0))
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find("rootbound")
	request.at = Vector2(4, 0)
	request.hp = 60.0
	request.damage = 2.0
	request.flags = Pool.FLAG_ELITE | Pool.FLAG_LEADER
	var elite := sim.spawn(request)
	place_player(sim, Vector2(0, 2), [plain, elite])
	var spans := []
	for slot in [plain, elite]:
		var release = sim.abilities.preview(slot, BASIC, 0)
		release.build(sim.species.tables, sim.locomotion.world, 0.0, sim.pool.flags[slot] & Pool.FLAG_ELITE != 0, false)
		spans.append(release.areas[0].span)
	check(sim.pool.is_leader(elite) and spans[1] > spans[0], "an elite's sweep is wider than its species' (%.2f against %.2f)" % [spans[1], spans[0]])
