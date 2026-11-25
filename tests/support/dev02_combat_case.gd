extends RefCounted
const Outgoing = preload("res://outgoing_hits.gd")
const Incoming = preload("res://incoming_player_hit.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

static func verify(arena: Node) -> String:
	var actor: Dictionary=arena.players[1]
	if not arena.spawn_selection("Target",0,3,"Line",true).is_empty(): return "target arrangement"
	var before: int=arena.encounter.hp(0)
	var hit:=Outgoing.hit_world(arena,1,0,actor.pos,{"damage":1.0,"knockback":-.35},arena.CombatClock.now())
	if hit.applied_hp<=0 or arena.encounter.hp(0)!=before or arena.round_stats().party.damage!=hit.applied_hp: return "real damage and inexhaustible target"
	arena.set_control("invincible",true)
	var life := Lifecycle.generation(actor)
	var incoming:=Incoming.resolve_world(arena,1,life,arena.CombatClock.now(),1)
	if incoming.applied_hp!=0 or arena.round_stats().players[0].prevented!=0: return "invincibility manufactured prevention"
	arena.set_control("invincible",false)
	incoming=Incoming.resolve_world(arena,1,life,arena.CombatClock.now(),1)
	if incoming.applied_hp<=0: return "real incoming damage"
	arena.restore_health()
	if actor[arena.PlayerVitals.STATE].hp()!=arena.PlayerVitals.maximum_hp(actor): return "restore health"
	actor[Cooldowns.STATE]=actor[Cooldowns.STATE].with_deadline(Cooldowns.Q,9999999)
	actor.core_cast_until=500
	actor.card_active_state={"actions":{"singularity":{"sequence":11,"ready":1234}}}
	arena.set_control("no_cooldowns",true)
	if actor[Cooldowns.STATE].deadline(Cooldowns.Q)!=0 or actor.core_cast_until!=500 or actor.card_active_state.actions.singularity!={"sequence":11,"ready":0}: return "cooldown isolation"
	arena.reset_statistics()
	if arena.round_stats().party.damage!=0: return "statistics reset"
	if not arena.spawn_selection("Enemy",0,2,"Ring",false).is_empty(): return "ordinary roster"
	arena.set_control("movement",false)
	arena.set_control("attacks",false)
	var point: Vector3=arena.encounter.position(0)
	arena.tick_enemies(0.1,arena.CombatClock.now())
	if arena.encounter.position(0)!=point or arena.encounter.scout(0).windup!=0: return "enemy controls"
	arena.set_control("movement",true)
	arena.set_control("attacks",true)
	if not arena.spawn_selection("Elite",0,1,"Single",false).is_empty() or not arena.encounter.leader_tactics().get("gate_elite",false): return "elite owner"
	for row in arena.PracticeEncounter.entries():
		if row.type=="Boss":
			if not arena.spawn_selection("Boss",row.kind,1,"Single",false).is_empty() or arena.tactics.boss_kind!=row.kind: return "dedicated boss setup"
	arena.clear_enemies()
	if not arena.encounter.cleared(): return "clear roster"
	return ""
