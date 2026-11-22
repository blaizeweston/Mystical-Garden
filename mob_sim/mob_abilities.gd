extends RefCounted
## Runs telegraphed attacks from the framework's ability kits. Aim locks when the wind-up starts and the
## release uses that locked aim. Each release builds its areas (mob_release.gd) and applies its effects.
## With resolve_hits on, as in training, this layer resolves hits on the party and runs hazards itself.
## With it off, as in the Neural Arena, the host reads each tick's releases and resolves them with the
## game's own hit rules.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Handler = preload("res://mob_sim/abilities/ability_handler.gd")
const HandlerRegistry = preload("res://mob_sim/abilities/handler_registry.gd")
const Loader = preload("res://mob_sim/definitions/definition_loader.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Release = preload("res://mob_sim/mob_release.gd")
const Rules = preload("res://mob_sim/mob_rules.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const MAX_LEAD_SPEED := 6.0
const BUFF_NEIGHBOURS := 16
const MIN_WINDUP_TICKS := 1
## A player standing in a hazard is hit at most this often by it.
const HAZARD_HIT_TICKS := 30
const MUTATION_BITS := 5
## How long a mob waits after a handler refuses its attack, as the legacy rites do.
const REFUSE_TICKS := 24

## One placed hazard. Hosts that resolve their own hits read these from each release instead.
class Hazard extends RefCounted:
	var point := Vector2.ZERO
	var radius := 0.0
	var activate := 0
	var until := 0
	var kind := 0
	var damage := 0.0
	## Hosts that place their own hazards use these milliseconds.
	var delay_ms := 0
	var duration_ms := 0
	var slot := -1
	var generation := 0
	var next_hit := PackedInt32Array()

var pool: Pool
var party: Party
var species: Species
var rules: Rules
var events: Events
var locomotion: Locomotion
## When true this layer hits the party itself. Training and the synthetic arena use this.
var resolve_hits := false
## Releases made this tick, for a host that resolves hits with its own rules.
var releases: Array[Release] = []
var hazards: Array[Hazard] = []
## Pending extra pulses: Release, remaining pulses, interval ticks, due tick.
var _repeats: Array = []
## Ability handlers and the port they use to reach the world. MobSim sets the port.
var handlers := HandlerRegistry.new()
var port: RefCounted
## The release planned at each wind-up, by slot.
var _pending := {}


func _init(mob_pool: Pool, mob_party: Party, table: Species, game_rules: Rules, event_log: Events, mover: Locomotion) -> void:
	pool = mob_pool
	party = mob_party
	species = table
	rules = game_rules
	events = event_log
	locomotion = mover


func in_reach(slot: int, attack: int, player: int) -> bool:
	var at := pool.species[slot] * Species.ATTACKS + attack
	var distance := pool.distance_to(slot, party.x[player], party.z[player])
	return distance <= species.attack_range[at] + pool.reach_bonus[slot] and distance >= species.attack_min_range[at]


## Starts a wind-up if every rule allows it. The brain cannot skip any of these checks.
func begin(slot: int, attack: int, player: int, tick: int) -> bool:
	if tick < pool.stun_until[slot] or not party.targetable(player) or not rules.attack_ready(slot, attack, tick):
		return false
	if not in_reach(slot, attack, player) or not rules.can_claim_attacker(player):
		return false
	var at := pool.species[slot] * Species.ATTACKS + attack
	var x := pool.xz[slot * 2]
	var z := pool.xz[slot * 2 + 1]
	if species.attack_sight[at] != 0 and locomotion.world.line_clear(x, z, party.x[player], party.z[player], 0.0) == 0:
		return false
	var release := preview(slot, attack, player)
	if not gate(release, tick):
		return false
	_pending[slot] = release
	if rules.actions != null:
		rules.actions.spend(slot, attack)
	var aim := release.aim
	var ticks := maxi(maxi(MIN_WINDUP_TICKS, species.attack_min_windup[at]), roundi(species.attack_windup[at] * pool.windup_scale[slot]))
	party.attackers[player] += 1
	pool.windup_until[slot] = tick + ticks
	pool.windup_attack[slot] = attack
	pool.aim_player[slot] = player
	pool.aim_x[slot] = aim.x
	pool.aim_z[slot] = aim.y
	locomotion.hold(slot)
	events.push(Events.Kind.WINDUP, tick, slot, pool.generation[slot], attack, ticks, aim.x, aim.y,
		pool.damage[slot], species.attack_area[at], x, z)
	return true


## The release a wind-up would lock, before any handler adjusts it.
func preview(slot: int, attack: int, player: int) -> Release:
	var at := pool.species[slot] * Species.ATTACKS + attack
	var release := Release.new()
	release.slot = slot
	release.generation = pool.generation[slot]
	release.row = species.attack_row[at]
	release.attack = attack
	release.player = player
	release.origin = Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	release.aim = _aim(slot, at, player)
	var shape := species.attack_shape[at]
	release.landing = release.aim if shape == Species.Shape.DASH or shape == Species.Shape.LEAP else release.origin
	release.damage = pool.damage[slot]
	if release.row >= 0:
		var ability = Loader.shared().abilities[species.tables.row_ability[release.row]]
		release.ability = ability.id
		release.legacy = ability.legacy
	return release


## Runs the ability's handler before a wind-up: an approach step first, then its plan. Returns false
## when the wind-up should not start now.
func gate(release: Release, tick: int) -> bool:
	var handler: Handler = handlers.for_row(species.tables, release.row)
	if handler == null or port == null:
		return true
	var goal := handler.approach(port, release)
	if goal.is_finite():
		pool.approach_until[release.slot] = tick + Handler.APPROACH_TICKS
		pool.approach_x[release.slot] = goal.x
		pool.approach_z[release.slot] = goal.y
		return false
	if not handler.plan(port, release):
		pool.ready_at[release.slot] = maxi(pool.ready_at[release.slot], tick + REFUSE_TICKS)
		return false
	return true


## Leads the target by the ability's lead time. Charges and leaps stop at their reach.
func _aim(slot: int, at: int, player: int) -> Vector2:
	var origin := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	var velocity := Vector2(party.vx[player], party.vz[player]).limit_length(MAX_LEAD_SPEED)
	var point := Vector2(party.x[player], party.z[player]) + velocity * species.attack_lead[at]
	var shape := species.attack_shape[at]
	if shape == Species.Shape.DASH or shape == Species.Shape.LEAP:
		return origin + (point - origin).limit_length(species.attack_range[at] + pool.reach_bonus[slot])
	return point


func tick_windups(tick: int) -> void:
	releases.clear()
	for slot in pool.active:
		if pool.windup_until[slot] > 0 and tick >= pool.windup_until[slot]:
			_release(slot, tick)
	if not _repeats.is_empty():
		_tick_repeats(tick)
	if resolve_hits and not hazards.is_empty():
		_tick_hazards(tick)


func _release(slot: int, tick: int) -> void:
	var attack := pool.windup_attack[slot]
	var at := pool.species[slot] * Species.ATTACKS + attack
	var shape := species.attack_shape[at]
	var player := pool.aim_player[slot]
	var origin := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	_finish_windup(slot)
	pool.prompt_decision(slot, tick)
	pool.ready_at[slot] = tick + roundi(species.attack_recovery[at] * pool.recovery_scale[slot])
	pool.cooldown_until[slot * pool.attacks + attack] = maxi(pool.ready_at[slot], tick + species.attack_cooldown[at])
	if shape == Species.Shape.DASH or shape == Species.Shape.LEAP:
		locomotion.displace(slot, pool.aim_x[slot], pool.aim_z[slot])
	var release: Release = _pending.get(slot)
	_pending.erase(slot)
	if release == null or release.generation != pool.generation[slot]:
		release = preview(slot, attack, player)
	release.origin = origin
	release.landing = Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	if release.row >= 0 and not release.data.get("locked", false):
		release.areas.clear()
		release.points.clear()
		release.build(species.tables, locomotion.world, _radius_growth(slot), pool.flags[slot] & Pool.FLAG_ELITE != 0, slot % 2 == 1)
	events.push(Events.Kind.RELEASE, tick, slot, pool.generation[slot], attack, shape | (player << 8),
		release.aim.x, release.aim.y, pool.damage[slot], species.attack_area[at], origin.x, origin.y)
	releases.append(release)
	var handler: Handler = handlers.for_row(species.tables, release.row)
	var generic := handler == null or port == null or handler.resolve(port, release)
	if generic:
		_apply_effects(release, tick, true)
	for follow in release.follow_ups:
		var delay := Clock.from_ms(float(follow.data.get("delay_ms", 0)))
		_repeats.append([follow, 1, delay, tick + delay])


## Extra radius from mutations such as Reach and Spores.
func _radius_growth(slot: int) -> float:
	var grow := 0.0
	var mutations := pool.mutations[slot]
	for bit in MUTATION_BITS:
		if mutations & (1 << bit) != 0 and bit < species.tables.mutation_radius_bonus.size():
			grow += species.tables.mutation_radius_bonus[bit]
	return grow


func _apply_effects(release: Release, tick: int, first: bool) -> void:
	if release.row < 0:
		return
	var tables = species.tables
	var start: int = tables.row_effect_start[release.row]
	var root_ticks := 0
	var pull := 0.0
	var damage_scale := -1.0
	for index in tables.row_effect_count[release.row]:
		var effect: int = start + index
		match int(tables.effect_kind[effect]):
			Enums.Effect.DAMAGE:
				damage_scale = tables.effect_scale[effect]
			Enums.Effect.ROOT:
				root_ticks = Clock.from_ms(float(tables.effect_duration_ms[effect]))
			Enums.Effect.PULL:
				pull = tables.effect_distance[effect]
			Enums.Effect.HAZARD:
				_place_hazards(release, effect, tick)
			Enums.Effect.HASTE_ALLIES:
				var reach: float = tables.effect_radius[effect] if tables.effect_radius[effect] > 0.0 else tables.row_radius[release.row]
				_haste_allies(release.slot, reach, tick, Clock.from_ms(float(tables.effect_duration_ms[effect])))
			Enums.Effect.REPEAT:
				if first:
					_repeats.append([release, int(tables.effect_count[effect]), Clock.from_ms(float(tables.effect_interval_ms[effect])),
						tick + Clock.from_ms(float(tables.effect_interval_ms[effect]))])
	if resolve_hits and (damage_scale >= 0.0 or pull > 0.0):
		_hit_party(release, maxf(damage_scale, 0.0), root_ticks, pull, tick)


func _hit_party(release: Release, scale: float, root_ticks: int, pull: float, tick: int) -> void:
	for player in party.count:
		if not party.targetable(player):
			continue
		var at := Vector2(party.x[player], party.z[player])
		if release.hits(at, locomotion.world):
			events.push(Events.Kind.HIT, tick, release.slot, release.generation, player, root_ticks, at.x, at.y,
				release.damage * scale, pull, release.pull_anchor().x, release.pull_anchor().y)


func _place_hazards(release: Release, effect: int, tick: int) -> void:
	var tables = species.tables
	var forward := (release.aim - release.origin).normalized()
	var side := Vector2(-forward.y, forward.x) * (-1.0 if release.slot % 2 == 1 else 1.0)
	var spots := release.points
	var offset := Vector2(tables.effect_offset[effect * 2], tables.effect_offset[effect * 2 + 1])
	if not offset.is_zero_approx():
		spots = PackedVector2Array([release.origin + side * offset.x + forward * offset.y])
	var damage := release.damage * maxf(tables.effect_scale[effect], 0.0)
	for index in spots.size():
		var hazard := Hazard.new()
		hazard.point = spots[index]
		hazard.radius = tables.effect_radius[effect] if tables.effect_radius[effect] > 0.0 else tables.row_spot_radius[release.row]
		if hazard.radius <= 0.0:
			hazard.radius = tables.row_radius[release.row]
		hazard.activate = tick + Clock.from_ms(float(tables.effect_delay_ms[effect] + tables.effect_step_ms[effect] * index))
		hazard.until = hazard.activate + Clock.from_ms(float(tables.effect_duration_ms[effect]))
		hazard.delay_ms = tables.effect_delay_ms[effect] + tables.effect_step_ms[effect] * index
		hazard.duration_ms = tables.effect_duration_ms[effect]
		hazard.kind = tables.effect_hazard[effect]
		hazard.damage = damage
		hazard.slot = release.slot
		hazard.generation = release.generation
		hazard.next_hit.resize(party.count)
		hazard.next_hit.fill(0)
		release.hazards.append(hazard)
		if resolve_hits:
			hazards.append(hazard)


func _tick_hazards(tick: int) -> void:
	var kept: Array[Hazard] = []
	for hazard in hazards:
		if tick >= hazard.until:
			continue
		kept.append(hazard)
		if tick < hazard.activate:
			continue
		for player in party.count:
			if not party.targetable(player) or tick < hazard.next_hit[player]:
				continue
			var at := Vector2(party.x[player], party.z[player])
			if at.distance_to(hazard.point) <= hazard.radius \
					and locomotion.world.line_clear(hazard.point.x, hazard.point.y, at.x, at.y, 0.0) != 0:
				hazard.next_hit[player] = tick + HAZARD_HIT_TICKS
				events.push(Events.Kind.HIT, tick, hazard.slot, hazard.generation, player, 0, at.x, at.y, hazard.damage, 0.0,
					hazard.point.x, hazard.point.y)
	hazards = kept


func _tick_repeats(tick: int) -> void:
	var kept := []
	for entry in _repeats:
		var release: Release = entry[0]
		if pool.alive[release.slot] == 0 or pool.generation[release.slot] != release.generation:
			continue
		if tick < int(entry[3]):
			kept.append(entry)
			continue
		var pulse = release.copy()
		events.push(Events.Kind.RELEASE, tick, pulse.slot, pulse.generation, pulse.attack, 0, pulse.aim.x, pulse.aim.y,
			pulse.damage, 0.0, pulse.origin.x, pulse.origin.y)
		releases.append(pulse)
		_apply_effects(pulse, tick, false)
		if int(entry[1]) > 1:
			kept.append([release, int(entry[1]) - 1, int(entry[2]), tick + int(entry[2])])
	_repeats = kept


## Ends a wind-up early, for a stagger, without releasing the attack.
func interrupt(slot: int, delay_ticks: int, tick: int) -> void:
	if pool.windup_until[slot] <= 0:
		return
	_finish_windup(slot)
	_pending.erase(slot)
	pool.prompt_decision(slot, tick)
	pool.ready_at[slot] = maxi(pool.ready_at[slot], tick + delay_ticks)
	events.push(Events.Kind.INTERRUPT, tick, slot, pool.generation[slot])


## Clears attack state for a mob that died during a wind-up.
func cancel(slot: int) -> void:
	_pending.erase(slot)
	if pool.windup_until[slot] > 0:
		_finish_windup(slot)


func _finish_windup(slot: int) -> void:
	var player := pool.aim_player[slot]
	if player != Pool.NO_PLAYER:
		party.attackers[player] = maxi(0, party.attackers[player] - 1)
	pool.windup_until[slot] = 0
	pool.aim_player[slot] = Pool.NO_PLAYER


func _haste_allies(slot: int, radius: float, tick: int, ticks: int) -> void:
	var nearest: PackedFloat32Array = locomotion.world.nearest_batch(PackedFloat32Array([slot]), radius, BUFF_NEIGHBOURS)
	var x := pool.xz[slot * 2]
	var z := pool.xz[slot * 2 + 1]
	for index in BUFF_NEIGHBOURS:
		var other := int(nearest[index])
		if other < 0:
			return
		if species.support[pool.species[other]] == 0 \
				and locomotion.world.line_clear(x, z, pool.xz[other * 2], pool.xz[other * 2 + 1], 0.0) != 0:
			pool.haste_until[other] = tick + ticks
