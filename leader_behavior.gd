extends RefCounted
## Dispatches the floor leader and implements the Heart's Briar.
## Elite attacks share the scout release path. Boss plans remain in their own modules.

const Battlefield = preload("res://battlefield.gd")
const Bosses = preload("res://boss_encounters.gd")
const Campaign = preload("res://campaign.gd")
const Director = preload("res://combat_director.gd")
const Elite = preload("res://elite_enemy.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Frost = preload("res://frost_combat.gd")
const Omens = preload("res://oracle_omens.gd")
const Audio = preload("res://event_audio.gd")
const Spirit = preload("res://spirit_affinity.gd")

const BRIAR_STRIKE_RADIUS := 1.8
const LONGLIMB_STRIKE_RADIUS := 3.0


static func tick(game: Node, delta: float, now: int) -> void:
	if game.tactics.boss_kind >= 0:
		Bosses.tick(game, delta, now)
		return
	if not game.encounter.alive(-1):
		return
	if game.destination != Campaign.HEART:
		Elite.tick(game, delta, now)
		return
	if game.tactics.winding_up:
		if now >= game.tactics.strike_at:
			Frost.with_attacker(game, -1, resolve.bind(game, now))
		return
	if now < game.tactics.stagger_until:
		return
	var target := Director.target(game, game.tactics.position, game.tactics.memory, now)
	if target == 0:
		return
	var trace := Spirit.diversion(game, game.tactics.memory, target)
	if trace.is_finite():
		if now >= game.tactics.rooted_until:
			var speed := Director.speed(game, 2.0) * Frost.motion_scale(game.tactics.memory, now)
			game.tactics.position = Director.navigate(game, game.tactics.position, trace, speed * delta)
		return
	var victim: Vector3 = game.players[target].pos
	var distance: float = game.tactics.position.distance_to(victim)
	if not game.tactics.engaged and (distance > float(Director.config().aggro_radius) or not game.battlefield.clear_line(game.tactics.position, victim)):
		return
	if not game.tactics.memory.get("alerted", false):
		Director.alert(game, game.tactics.position)
		game.tactics.memory.alerted = true
	game.tactics.engaged = true
	var ready: bool = now >= game.tactics.ready_at
	var unrooted: bool = now >= game.tactics.rooted_until
	if game.enemy_mutations & Enemies.MOBILITY and ready and unrooted and distance > 1.5:
		var landing: Vector3 = game.tactics.position.move_toward(victim, minf(3.0, distance))
		if game.can_vault(game.tactics.position, landing):
			_begin_attack(game, "vault", landing, base_strike_radius(game), now + 1000, now)
			return
	if distance > base_strike_radius(game) - 0.45 or not game.battlefield.clear_line(game.tactics.position, victim):
		if unrooted:
			var affinity_motion := Frost.motion_scale(game.tactics.memory, now) if game.has_meta(&"combat_affinity_ruleset") else 1.0
			var speed := minf(float(Enemies.get_kind(game.enemy_kind).speed) + (game.depth - 1) * 0.30, 2.9) + 0.35 + minf(game.difficulty_cycle * 0.12, 0.72)
			if now < game.tactics.haste_until:
				speed *= 1.22
			var stride := Director.speed(game, speed + 0.55 if game.tactics.longlimb else speed)
			stride *= (1.18 if game.enemy_mutations & Enemies.MOBILITY else 1.0) * delta * affinity_motion
			game.tactics.position = Director.navigate(game, game.tactics.position, Director.pursuit(game, target, 0), stride)
	elif ready:
		game.tactics.attack_pattern += 1
		var heavy: bool = game.encounter.hp(-1) <= game.encounter_health() / 2.0 and game.tactics.attack_pattern % 2 == 0
		var radius := 3.65 if heavy else base_strike_radius(game)
		var windup := Director.windup(game, 950 if heavy else 540)
		_begin_attack(game, "", game.tactics.landing, radius, now + windup, now)


static func _begin_attack(game: Node, mode: String, landing: Vector3, radius: float, strike_at: int, now: int) -> void:
	game.tactics.landing = landing
	game.tactics.begin_attack(mode, strike_at, radius)
	Omens.begin_briar(game, now)
	Audio.enemy(game, {"mode": "vault" if mode == "vault" else "swipe", "from": game.tactics.position}, false)


static func base_strike_radius(game: Node) -> float:
	var radius: float = LONGLIMB_STRIKE_RADIUS if game.tactics.longlimb else [BRIAR_STRIKE_RADIUS, 2.1, 2.25, 2.45][game.destination]
	return radius + (0.35 if game.enemy_mutations & Enemies.SPORES else 0.0)


static func strike_radius(game: Node) -> float:
	return game.tactics.active_radius if game.tactics.active_radius > 0.0 else base_strike_radius(game)


static func resolve(game: Node, now: int) -> void:
	if game.tactics.boss_kind < 0 and not game.encounter.leader_tactics().is_empty():
		Elite.resolve(game, now)
		return
	var vault: bool = game.tactics.attack_mode == "vault"
	if not vault or not game.battlefield.occupied(game.tactics.landing, Battlefield.CLEARANCE):
		Audio.enemy(game, {"mode": "vault" if vault else "swipe", "from": game.tactics.position}, true)
	if vault and not game.battlefield.occupied(game.tactics.landing, Battlefield.CLEARANCE):
		game.tactics.position = game.tactics.landing
	game.tactics.stop_attack()
	var recovery := roundi((Director.recovery(game, 750) + game.tactics.recovery_bonus) * (0.82 if now < game.tactics.haste_until else 1.0))
	game.tactics.ready_at = now + recovery
	game.tactics.ready_at = Omens.release_attack(game.tactics.memory, game.tactics.memory.get(Omens.BRIAR_ATTACK, {}), game.tactics.ready_at)
	game.tactics.memory.erase(Omens.BRIAR_ATTACK)
	game.tactics.recovery_bonus = 0
	var damage := Director.Balance.scout_hit(game, Enemies.get_kind(game.enemy_kind), {"gate_elite": true})
	preload("res://enemy_attack_hits.gd").for_world(game, -1).area(game.tactics.position, strike_radius(game), now, damage)
	game.tactics.active_radius = 0.0
	game.abandon_if_empty()
