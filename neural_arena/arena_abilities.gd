extends "res://mob_sim/mob_abilities.gd"
## Runs the framework's ability kits against the real game in the Neural Arena.
## Geometry and effects come from the kits (mob_release.gd). Hits go through the game's own player-hit
## rules (incoming_player_hit.gd), with line of sight through the real battlefield, and hazards go through
## the game's hazard system. Each wind-up also locks a legacy-shaped attack plan on the real enemy, so the
## game's warnings, poses, audio, Oracle omens and staggers keep working. A dedicated framework view
## replaces that presentation plan in Phase 5.

const ArenaPort = preload("res://neural_arena/arena_handler_port.gd")
const Attacks = preload("res://enemy_attack.gd")
const CombatClock = preload("res://combat_clock.gd")
const EnemyBehaviors = preload("res://enemy_behaviors.gd")
const Glasscap = preload("res://glasscap_feint.gd")
const Hits = preload("res://enemy_attack_hits.gd")
const IncomingHit = preload("res://incoming_player_hit.gd")
const Life = preload("res://expedition_life.gd")
const Frost = preload("res://frost_combat.gd")
const Omens = preload("res://oracle_omens.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const ScoutBehavior = preload("res://scout_behavior.gd")
const Support = preload("res://enemy_support.gd")

const MS_PER_TICK := 1000.0 / Clock.TICKS_PER_SECOND
const HASTED_RECOVERY := 0.82
## Legacy cap on how many hatchlings one Broodmother may have out.
const BROOD_LIMIT := 2


## Line of sight through the real battlefield, in the form mob_release.gd expects.
class FieldSight extends RefCounted:
	var field: RefCounted
	var combat := false

	func _init(battlefield: RefCounted, combat_sight: bool) -> void:
		field = battlefield
		combat = combat_sight

	func line_clear(x0: float, z0: float, x1: float, z1: float, _radius: float) -> int:
		var from := Vector3(x0, 0.0, z0)
		var to := Vector3(x1, 0.0, z1)
		return int(field.combat_sight(from, to) if combat else field.clear_line(from, to))


var game: Node
var bridge: RefCounted
## Extra pulses: Release, pulses left, interval ms, due ms, damage.
var _pulses: Array = []
## Releases per ability id this round, and hazards placed, for checks and tuning.
var used := {}
var hazards_placed := 0


func connect_game(world: Node, mob_bridge: RefCounted) -> void:
	game = world
	bridge = mob_bridge
	port = ArenaPort.new(world, mob_bridge)


## Breaks the link back to the bridge so a finished round can be freed.
func disconnect_game() -> void:
	game = null
	bridge = null
	port = null
	_pending.clear()
	_pulses.clear()


static func _v3(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y)


func begin(slot: int, attack: int, player: int, tick: int) -> bool:
	if tick < pool.stun_until[slot] or not party.targetable(player) or not rules.attack_ready(slot, attack, tick):
		return false
	if not in_reach(slot, attack, player) or not rules.can_claim_attacker(player):
		return false
	var at := pool.species[slot] * Species.ATTACKS + attack
	var row: int = species.attack_row[at]
	var peer: int = bridge.peer_of(player)
	var scout: Dictionary = game.encounter.scout(slot)
	if row < 0 or peer == 0 or scout.is_empty() or int(scout.windup) > 0:
		return false
	var tables = species.tables
	var victim: Vector3 = game.players[peer].pos
	if species.attack_sight[at] != 0:
		var sight := FieldSight.new(game.battlefield, tables.row_sight[row] == Enums.Sight.COMBAT)
		if sight.line_clear(scout.pos.x, scout.pos.z, victim.x, victim.z, 0.0) == 0:
			return false
	var definition: Dictionary = game.Enemies.get_kind(int(scout.kind))
	var release := _preview(slot, attack, player, row, scout, tick)
	if release == null:
		return false
	var now := CombatClock.now()
	var windup_ms := maxi(int(tables.row_min_windup_ms[row]), int(game.Director.windup(game, int(tables.row_windup_ms[row]))))
	var mode := _mode(slot, definition, row)
	var plan := _presentation(release, mode, row)
	var observation := ScoutBehavior.attack_observation(slot, game.encounter.token(slot), game.participation.epoch(), peer, scout.pos,
		victim, mode, species.attack_range[at] + pool.reach_bonus[slot], int(scout.ready), now, PlayerLifecycle.generation(game.players[peer]))
	scout.cast_target = peer
	Attacks.lock(game, scout, mode, _v3(release.aim), now + windup_ms, plan, observation)
	scout.erase("approach_done")
	scout.erase("approach")
	scout.erase("approach_used")
	EnemyBehaviors.telegraph(game, scout, now)
	_pending[slot] = release
	if rules.actions != null:
		rules.actions.spend(slot, attack)
	party.attackers[player] += 1
	pool.windup_until[slot] = tick + maxi(MIN_WINDUP_TICKS, ceili((int(scout.windup) - now) / MS_PER_TICK))
	pool.windup_attack[slot] = attack
	pool.aim_player[slot] = player
	pool.aim_x[slot] = release.aim.x
	pool.aim_z[slot] = release.aim.y
	locomotion.hold(slot)
	return true


## Locks the release geometry at the wind-up, as the game's own attacks do. The ability's handler may
## step aside first or refuse, in which case this returns null.
func _preview(slot: int, attack: int, player: int, row: int, scout: Dictionary, tick: int) -> Release:
	var tables = species.tables
	var release := preview(slot, attack, player)
	release.origin = Vector2(scout.pos.x, scout.pos.z)
	if not gate(release, tick):
		return null
	release.landing = release.origin
	if tables.row_delivery[row] == Enums.Delivery.LEAP:
		var landed: Vector3 = game.battlefield.dash(scout.pos, _v3(release.aim))
		release.landing = Vector2(landed.x, landed.z)
	if not release.data.get("locked", false):
		release.build(tables, FieldSight.new(game.battlefield, false), _radius_growth(slot), pool.flags[slot] & Pool.FLAG_ELITE != 0, slot % 2 == 1)
	return release


func _mode(slot: int, definition: Dictionary, row: int) -> String:
	if row == species.tables.fallback_row[pool.species[slot]]:
		return "desperate"
	return str(definition.role)


## A legacy-shaped attack plan, used only for the game's warnings, poses, audio and guards.
func _presentation(release: Release, mode: String, row: int) -> Dictionary:
	var tables = species.tables
	var ability = Loader.shared().abilities[tables.row_ability[row]]
	var radius: float = tables.row_radius[row] + (_radius_growth(release.slot) if tables.row_flags[row] & tables.ROW_RADIUS_GROWS else 0.0)
	var spots: Array[Vector3] = []
	for point in release.points:
		spots.append(_v3(point))
	var no_spots: Array[Vector3] = []
	var no_trail: Array[Vector3] = []
	var no_patches: Array[Vector3] = []
	var plan := {"mode": mode, "variant": "", "from": _v3(release.origin), "face": _v3(release.aim), "to": _v3(release.aim),
		"via": Vector3.INF, "radius": radius, "width": tables.row_width[row], "spots": no_spots,
		"spot_radius": tables.row_spot_radius[row], "trail": no_trail, "patches": no_patches,
		"role": mode, "span": 0.0, "recovery_bonus": 0, "cue": ability.cue, "pulse": 0}
	for index in tables.row_effect_count[row]:
		if tables.effect_kind[tables.row_effect_start[row] + index] == Enums.Effect.REPEAT:
			plan.pulse = 1
	match int(tables.row_shape[row]):
		Enums.Shape.SECTOR:
			plan.role = "enemy_sweep"
			plan.span = tables.row_span[row]
			plan.to = _v3(release.origin)
		Enums.Shape.CIRCLE:
			if tables.row_anchor[row] == Enums.Anchor.SELF:
				plan.to = _v3(release.origin)
			elif tables.row_anchor[row] == Enums.Anchor.LANDING:
				plan.to = _v3(release.landing)
		Enums.Shape.LINE:
			plan.role = "burrow" if ability.legacy == "burrow" else "charge"
			plan.to = _v3(release.landing)
		Enums.Shape.BENT_LINE:
			plan.variant = "antler_hook"
			plan.via = _v3(release.areas[0].to)
			plan.to = _v3(release.landing)
		Enums.Shape.SPOTS:
			if mode == "snare":
				plan.spots = spots
			else:
				plan.patches = spots
				plan.radius = tables.row_spot_radius[row]
		Enums.Shape.TRAIL:
			plan.trail = spots
			plan.to = _v3(release.landing)
	if tables.row_delivery[row] == Enums.Delivery.PULL:
		plan.anchor = _v3(release.pull_anchor())
	if ability.legacy in ["bark_guard", "planted_canopy"]:
		# The game guards and shelters during these wind-ups when it sees the legacy variant.
		plan.variant = ability.legacy
	var extra: Dictionary = release.data.get("presentation", {})
	for key in extra:
		plan[key] = _to_world(extra[key])
	return plan


## Converts handler presentation values from the ground plane into world positions.
static func _to_world(value: Variant) -> Variant:
	if value is Vector2:
		return _v3(value)
	if value is PackedVector2Array:
		var points: Array[Vector3] = []
		for point in value:
			points.append(_v3(point))
		return points
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[key] = _to_world(value[key])
		return copy
	return value


## Releases every wind-up whose telegraph has finished, using the real game's rules.
func tick_windups(tick: int) -> void:
	releases.clear()
	var now := CombatClock.now()
	for slot in pool.active.duplicate():
		var scout: Dictionary = game.encounter.scout(slot)
		var release: Release = _pending.get(slot)
		if scout.is_empty() or not game.encounter.alive(slot):
			_pending.erase(slot)
			continue
		if int(scout.windup) <= 0:
			if release != null:
				# The game ended the wind-up early, for example with a stagger.
				_pending.erase(slot)
				interrupt(slot, 0, tick)
			continue
		if now < int(scout.windup):
			continue
		if release == null:
			# A move the game itself started, such as a Graft Thief's loot grab, releases through the game.
			var definition: Dictionary = game.Enemies.get_kind(int(scout.kind))
			Frost.with_attacker(game, slot, ScoutBehavior.release.bind(game, scout, definition, now, scout.get("attack", {}), int(scout.windup)))
			if not game.participation.active():
				return
			if not Vector2(scout.pos.x, scout.pos.z).is_equal_approx(Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])):
				bridge.place(slot, scout.pos)
			continue
		var attack: Dictionary = Attacks.claim_scout_attack(game.encounter, scout, game.participation.epoch(), now,
			scout.get("attack", {}), int(scout.windup))
		_pending.erase(slot)
		_settle(slot, release, tick, now, scout, attack)
		if attack.is_empty():
			continue
		_resolve(release, now, scout, attack)
		releases.append(release)
		var ability_id: String = Loader.shared().abilities[species.tables.row_ability[release.row]].id
		used[ability_id] = int(used.get(ability_id, 0)) + 1
		hazards_placed += release.hazards.size()
		if not game.participation.active():
			return
	if not _pulses.is_empty():
		_tick_pulses(now)


## Recovery and cooldown. The bridge copies the real enemy's ready time into the simulation each tick.
func _settle(slot: int, release: Release, tick: int, now: int, scout: Dictionary, attack: Dictionary) -> void:
	var tables = species.tables
	var at := pool.species[slot] * Species.ATTACKS + release.attack
	_finish_windup(slot)
	var recovery := roundi(game.Director.recovery(game, int(tables.row_recovery_ms[release.row])) * (HASTED_RECOVERY if now < int(scout.get("haste_until", 0)) else 1.0))
	scout.ready = Omens.release_attack(scout, attack, now + recovery)
	pool.ready_at[slot] = tick + ceili((int(scout.ready) - now) / MS_PER_TICK)
	pool.cooldown_until[slot * pool.attacks + release.attack] = maxi(pool.ready_at[slot], tick + species.attack_cooldown[at])


func _resolve(release: Release, now: int, scout: Dictionary, attack: Dictionary) -> void:
	var tables = species.tables
	var row := release.row
	var definition: Dictionary = game.Enemies.get_kind(int(scout.kind))
	var base_damage := float(game.Director.Balance.scout_hit(game, definition, scout))
	var commitment: Dictionary = attack.get(Attacks.SCOUT_COMMIT, {})
	if tables.row_delivery[row] == Enums.Delivery.LEAP and Attacks.landing_is_clear(game, scout, attack, now):
		scout.pos = _v3(release.landing)
		bridge.place(release.slot, scout.pos)
	var handler: Handler = handlers.for_row(tables, row)
	var generic := handler == null or port == null or handler.resolve(port, release)
	for follow in release.follow_ups:
		_pulses.append([follow, 1, 0, now + int(follow.data.get("delay_ms", 0)), base_damage * _damage_scale(row)])
	if not generic:
		return
	preload("res://event_audio.gd").enemy(game, attack, true)
	var damage_scale := -1.0
	var root_ms := 0
	var pull := 0.0
	for index in tables.row_effect_count[row]:
		var effect: int = tables.row_effect_start[row] + index
		match int(tables.effect_kind[effect]):
			Enums.Effect.DAMAGE:
				damage_scale = tables.effect_scale[effect]
			Enums.Effect.ROOT:
				root_ms = tables.effect_duration_ms[effect]
			Enums.Effect.PULL:
				pull = tables.effect_distance[effect]
			Enums.Effect.HAZARD:
				_place_hazards(release, effect, 0)
			Enums.Effect.HASTE_ALLIES:
				_haste_scouts(release, tables.effect_radius[effect] if tables.effect_radius[effect] > 0.0 else tables.row_radius[row],
					tables.effect_duration_ms[effect], now)
			Enums.Effect.SUMMON:
				_summon(release, scout, int(tables.effect_count[effect]))
			Enums.Effect.DECOY:
				Glasscap.release(game, scout, now)
			Enums.Effect.REPEAT:
				_pulses.append([release, int(tables.effect_count[effect]), int(tables.effect_interval_ms[effect]),
					now + int(tables.effect_interval_ms[effect]), base_damage * maxf(damage_scale, 0.0)])
	for hazard in release.hazards:
		game.Bosses.hazard(game, _v3(hazard.point), hazard.radius, now, hazard.duration_ms, Enums.HAZARD_NAMES[hazard.kind],
			hazard.delay_ms, 1.0, "", commitment)
	if damage_scale >= 0.0 or pull > 0.0:
		_strike(release, base_damage * maxf(damage_scale, 0.0), root_ms, pull, now, commitment)


func _damage_scale(row: int) -> float:
	var tables = species.tables
	for index in tables.row_effect_count[row]:
		var effect: int = tables.row_effect_start[row] + index
		if tables.effect_kind[effect] == Enums.Effect.DAMAGE:
			return tables.effect_scale[effect]
	return 0.0


## Hits every living player inside the release, once each, through the game's player-hit rules.
func _strike(release: Release, damage: float, root_ms: int, pull: float, now: int, commitment: Dictionary) -> void:
	var sight := FieldSight.new(game.battlefield, species.tables.row_sight[release.row] == Enums.Sight.COMBAT)
	var before: PackedFloat32Array = bridge.party_health()
	var anchor := _v3(release.pull_anchor())
	for peer: int in game.players.keys():
		var actor: Dictionary = game.players[peer]
		var life := PlayerLifecycle.generation(actor)
		if life <= 0 or not Life.alive(actor) or not release.hits(Vector2(actor.pos.x, actor.pos.z), sight):
			continue
		if not commitment.is_empty() and not Hits.commitment_is_current(game, commitment):
			break
		if damage > 0.0:
			IncomingHit.resolve_world(game, peer, life, now, damage, root_ms, anchor, true)
		var survivor: Dictionary = game.players.get(peer, {})
		if pull > 0.0 and Life.alive(survivor) and PlayerLifecycle.matches(survivor, life):
			survivor.pos = game.battlefield.dash(survivor.pos, survivor.pos.move_toward(anchor, pull))
	bridge.credit_hits(release.slot, before)


## Hastes fighting enemies within reach and sight, in the game and in the simulation.
func _haste_scouts(release: Release, radius: float, duration_ms: int, now: int) -> void:
	var origin := _v3(release.origin)
	for slot in game.encounter.scout_count():
		var other: Dictionary = game.encounter.scout(slot)
		if slot == release.slot or not game.encounter.alive(slot) or game.Enemies.is_support(int(other.get("kind", 0))):
			continue
		if other.pos.distance_to(origin) <= radius and game.battlefield.clear_line(origin, other.pos):
			other.haste_until = now + duration_ms


func _summon(release: Release, scout: Dictionary, count: int) -> void:
	var room := BROOD_LIMIT - int(scout.get("summons", 0))
	if room <= 0:
		return
	for at in Support.brood_sites(game, _v3(release.origin), mini(count, room)):
		if Support.spawn_brood_at(game, at, true) >= 0:
			scout.summons = int(scout.get("summons", 0)) + 1


func _tick_pulses(now: int) -> void:
	var kept: Array = []
	for entry in _pulses:
		var release: Release = entry[0]
		if not game.encounter.alive(release.slot) or pool.generation[release.slot] != release.generation:
			continue
		if now < int(entry[3]):
			kept.append(entry)
			continue
		_strike(release, float(entry[4]), 0, 0.0, now, {})
		if int(entry[1]) > 1:
			kept.append([release, int(entry[1]) - 1, int(entry[2]), now + int(entry[2]), float(entry[4])])
	_pulses = kept
