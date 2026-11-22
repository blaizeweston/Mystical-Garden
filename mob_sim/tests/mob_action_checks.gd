extends SceneTree
## Checks MobActions: mana costs and spending, channeling with its refill and extra damage, dodging with its
## sidestep, hit window and cooldown, and the scripted brain's use of both.

const Battlefield = preload("res://battlefield.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const BASIC := 0
const SIGNATURE := 1

var failures := 0
var checks := 0


func _initialize() -> void:
	if not NavWorld.ensure_loaded():
		print("FAIL native extension did not load")
		quit(2)
		return
	test_costs()
	test_spending()
	test_channel()
	test_dodge()
	test_scripted_dodge()
	test_scripted_channel()
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func make_sim(slots := 4) -> Sim:
	var field = Battlefield.new()
	field.configure(0, 1)
	preload("res://tests/support/terrain_case.gd").walls(field, [])
	var sim := Sim.new(slots)
	sim.configure(field)
	return sim


func add_mob(sim: Sim, label: String, at: Vector2) -> int:
	var request := Pool.Spawn.new()
	request.species = sim.species.ids.find(label)
	request.at = at
	request.hp = 100.0
	request.damage = 2.0
	return sim.spawn(request)


func place_player(sim: Sim, at: Vector2, watchers: Array) -> void:
	sim.party.set_player(0, at, Vector2.ZERO, 100.0, 100.0)
	for slot in watchers:
		var row: int = int(slot) * sim.contract.players
		sim.perception.seen_tick[row] = sim.clock.tick
		sim.perception.visible[row] = 1
		sim.perception.seen_x[row] = at.x
		sim.perception.seen_z[row] = at.y


func decide_now(sim: Sim, slot: int) -> void:
	sim.pool.next_decision[slot] = sim.clock.tick
	sim.pool.hold_until[slot] = 0
	sim._decide(sim.clock.tick)


func test_costs() -> void:
	var species := Species.new()
	var nightbloom := species.ids.find("nightbloom")
	var rootbound := species.ids.find("rootbound")
	check(species.mana_pool[nightbloom] == 100.0 and species.mana_pool[rootbound] == 0.0, "only mana species have a pool")
	check(species.attack_mana_cost[nightbloom * Species.ATTACKS + BASIC] == 25.0
		and species.attack_mana_cost[nightbloom * Species.ATTACKS + SIGNATURE] == 35.0, "a caster's basic costs 25 and its signature 35")
	check(species.attack_mana_cost[rootbound * Species.ATTACKS + BASIC] == 0.0, "a fighter's attacks are free")
	check(species.mana_low[nightbloom] == 35.0, "a caster runs low below its dearest cast")
	var thornmaw := species.ids.find("thornmaw")
	check(species.can_dodge[thornmaw] != 0 and species.can_dodge[nightbloom] == 0, "only agile species can dodge")


func test_spending() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "nightbloom", Vector2.ZERO)
	var tick := sim.clock.tick
	check(sim.pool.mana[slot] == 100.0, "a caster spawns with a full pool")
	sim.pool.ready_at[slot] = 0
	check(sim.rules.attack_ready(slot, BASIC, tick), "a full caster may cast")
	for cast in 4:
		sim.actions.spend(slot, BASIC)
	check(sim.pool.mana[slot] == 0.0, "four basic casts empty the pool")
	check(not sim.rules.attack_ready(slot, BASIC, tick), "an empty caster cannot cast")
	var fighter := add_mob(sim, "rootbound", Vector2(4, 0))
	sim.pool.ready_at[fighter] = 0
	check(sim.rules.attack_ready(fighter, BASIC, tick), "a fighter never needs mana")


func test_channel() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "nightbloom", Vector2.ZERO)
	var channel := sim.contract.id("channel")
	check(not sim.actions.can_channel(slot), "a full caster cannot channel")
	sim.pool.mana[slot] = 10.0
	check(sim.actions.can_channel(slot), "a caster below full can channel")
	var start := sim.clock.tick
	sim.actions.on_change(slot, sim.pool.behaviour[slot], channel, start)
	sim.pool.behaviour[slot] = channel
	check(sim.actions.channeling(slot, start), "choosing channel starts a channel")
	var before := sim.pool.hp[slot]
	sim.damage_mob(slot, 10.0, 0)
	check(is_equal_approx(before - sim.pool.hp[slot], 15.0), "a channeling caster takes half again as much damage")
	sim.actions.settle(slot, start + 60)
	check(is_equal_approx(sim.pool.mana[slot], 35.0), "a second of channel refills 25 mana")
	sim.actions.settle(slot, start + 600)
	check(sim.pool.mana[slot] == 100.0, "the refill stops at the pool size")
	sim.actions.on_change(slot, channel, sim.contract.id("flee"), start + 620)
	check(not sim.actions.channeling(slot, start + 620), "changing behaviour ends the channel")
	before = sim.pool.hp[slot]
	sim.damage_mob(slot, 10.0, 0)
	check(is_equal_approx(before - sim.pool.hp[slot], 10.0), "damage is normal once the channel ends")


func test_dodge() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "thornmaw", Vector2.ZERO)
	place_player(sim, Vector2(0, 3), [slot])
	var dodge := sim.contract.id("dodge")
	var tick := sim.clock.tick
	check(sim.actions.can_dodge(slot, tick), "an agile mob can dodge when ready")
	sim.pool.root_until[slot] = tick + 10
	check(not sim.actions.can_dodge(slot, tick), "a rooted mob cannot dodge")
	sim.pool.root_until[slot] = 0
	sim.actions.on_change(slot, 0, dodge, tick)
	var moved := Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])
	check(absf(moved.length() - 2.2) < 0.05 and absf(moved.y) < 0.05, "the dodge sidesteps across the threat by its distance")
	var cursor := sim.events.head
	var before := sim.pool.hp[slot]
	sim.damage_mob(slot, 10.0, 0)
	check(sim.pool.hp[slot] == before, "a hit inside the dodge window does nothing")
	var dodged := sim.events.read_since(cursor).any(func(event: Dictionary) -> bool: return event.kind == Events.Kind.DODGED)
	check(dodged, "the dodged hit is recorded")
	check(not sim.actions.can_dodge(slot, tick + 1), "the dodge has a cooldown")
	check(sim.actions.can_dodge(slot, sim.pool.dodge_ready_at[slot]), "the dodge is ready again after its cooldown")


func test_scripted_dodge() -> void:
	var sim := make_sim()
	var slot := add_mob(sim, "thornmaw", Vector2.ZERO)
	place_player(sim, Vector2(0, 1.5), [slot])
	sim.clock.advance()
	sim.pool.hurt_at[slot] = sim.clock.tick
	decide_now(sim, slot)
	check(sim.pool.behaviour[slot] == sim.contract.id("dodge"), "the scripted brain dodges right after a hit")
	var fighter := add_mob(sim, "rootbound", Vector2(5, 0))
	place_player(sim, Vector2(5, 1.5), [fighter])
	sim.pool.hurt_at[fighter] = sim.clock.tick
	decide_now(sim, fighter)
	check(sim.pool.behaviour[fighter] != sim.contract.id("dodge"), "a mob that cannot dodge does not")


func test_scripted_channel() -> void:
	var sim := make_sim()
	var near := add_mob(sim, "nightbloom", Vector2.ZERO)
	place_player(sim, Vector2(0, 4), [near])
	sim.pool.mana[near] = 0.0
	decide_now(sim, near)
	check(sim.pool.behaviour[near] == sim.contract.id("flee"), "an empty caster flees a close player before channeling")
	var far := add_mob(sim, "nightbloom", Vector2(0, -12))
	place_player(sim, Vector2(0, 4), [far])
	sim.pool.mana[far] = 0.0
	decide_now(sim, far)
	check(sim.pool.behaviour[far] == sim.contract.id("channel"), "an empty caster with room to spare channels")
	check(sim.actions.channeling(far, sim.clock.tick), "and its channel has started")
	var full := add_mob(sim, "nightbloom", Vector2(0, -16))
	place_player(sim, Vector2(0, 4), [full])
	decide_now(sim, full)
	check(sim.pool.behaviour[full] != sim.contract.id("channel"), "a full caster does not channel")
