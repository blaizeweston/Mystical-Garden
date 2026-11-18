extends "res://mob_sim/mob_abilities.gd"
## Turns neural attack requests into the game's real telegraphed attacks.
## Hit shapes, damage, status effects and species specials stay in the existing enemy code.

const Attacks = preload("res://enemy_attack.gd")
const CombatClock = preload("res://combat_clock.gd")
const EnemyBehaviors = preload("res://enemy_behaviors.gd")
const Frost = preload("res://frost_combat.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const ScoutBehavior = preload("res://scout_behavior.gd")

const VAULT_SLOT := 2
const MS_PER_TICK := 1000.0 / Clock.TICKS_PER_SECOND

var game: Node
var bridge: RefCounted


func connect_game(world: Node, mob_bridge: RefCounted) -> void:
	game = world
	bridge = mob_bridge


## Breaks the link back to the bridge so a finished round can be freed.
func disconnect_game() -> void:
	game = null
	bridge = null


func begin(slot: int, attack: int, player: int, tick: int) -> bool:
	if tick < pool.stun_until[slot] or not party.targetable(player) or not rules.attack_ready(slot, attack, tick):
		return false
	if not in_reach(slot, attack, player) or not rules.can_claim_attacker(player):
		return false
	var peer: int = bridge.peer_of(player)
	var scout: Dictionary = game.encounter.scout(slot)
	if peer == 0 or scout.is_empty() or int(scout.windup) > 0:
		return false
	var definition: Dictionary = game.Enemies.get_kind(int(scout.kind))
	var victim: Vector3 = game.players[peer].pos
	var mode := _attack_mode(slot, attack, str(definition.role))
	if species.attack_sight[pool.species[slot] * Species.ATTACKS + attack] != 0 \
			and not Attacks.attack_sight(game.battlefield, scout.pos, victim, mode):
		return false
	var aim: Vector3 = Attacks.vault_target(game, scout, victim) if attack == VAULT_SLOT else Attacks.aim(game, scout, mode, peer)
	if not aim.is_finite():
		return false
	var now := CombatClock.now()
	var reach: float = species.attack_range[pool.species[slot] * Species.ATTACKS + attack] + pool.reach_bonus[slot]
	var windup_ms: int = Attacks.VAULT_WINDUP if attack == VAULT_SLOT else game.Director.windup(game, int(definition.windup))
	var observation := ScoutBehavior.attack_observation(slot, game.encounter.token(slot), game.participation.epoch(), peer, scout.pos, victim,
		mode, reach, int(scout.ready), now, PlayerLifecycle.generation(game.players[peer]))
	scout.cast_target = peer
	Attacks.lock(game, scout, mode, aim, now + windup_ms, {}, observation)
	scout.erase("approach_done")
	scout.erase("approach")
	scout.erase("approach_used")
	EnemyBehaviors.telegraph(game, scout, now)
	scout.repeat = 1 if int(scout.kind) == 1 and mode == "volley" else 0
	party.attackers[player] += 1
	pool.windup_until[slot] = tick + maxi(MIN_WINDUP_TICKS, ceili((int(scout.windup) - now) / MS_PER_TICK))
	pool.windup_attack[slot] = attack
	pool.aim_player[slot] = player
	locomotion.hold(slot)
	return true


func _attack_mode(slot: int, attack: int, role: String) -> String:
	if attack == VAULT_SLOT:
		return "vault"
	return "desperate" if attack == 0 and species.support[pool.species[slot]] != 0 else role


## Releases every attack whose telegraph has finished, through the game's own release code.
func tick_windups(_tick: int) -> void:
	var now := CombatClock.now()
	for slot in pool.active.duplicate():
		var scout: Dictionary = game.encounter.scout(slot)
		if scout.is_empty() or int(scout.windup) <= 0 or now < int(scout.windup) or not game.encounter.alive(slot):
			continue
		var before: PackedFloat32Array = bridge.party_health()
		var start: Vector3 = scout.pos
		var definition: Dictionary = game.Enemies.get_kind(int(scout.kind))
		Frost.with_attacker(game, slot, ScoutBehavior.release.bind(game, scout, definition, now, scout.get("attack", {}), int(scout.windup)))
		if not game.participation.active():
			return
		bridge.credit_hits(slot, before)
		if not start.is_equal_approx(scout.pos):
			bridge.place(slot, scout.pos)
