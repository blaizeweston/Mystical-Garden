extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
## Capture each acquired adaptation at basic attack launch. Each source
## owns its own counters, and secondaries use the bounded native effect queue.
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Parts = preload("res://weapon_parts.gd")
const Preview = preload("res://combat_balance_preview.gd")
const CONTEXT = "native_graft_contact"
const STATE = "native_graft_state"
const Expedition = preload("res://expedition_grafts.gd")
# Only the contact adaptations authored in ExpeditionGrafts can enter this
# execution path. Monster material identities remain in weapon_parts.gd.
const PROC_KEYS := {
	"monster:spore_widow": ["link"],
	"monster:pallbearer": ["death_charge"],
	"monster:ashen_hart": ["cinder_trail"],
	"monster:glasscap": ["echo", "echo_redirect"],
	"monster:root_choir": ["chorus_pulse"],
}
const TIMING := {"link":120, "cinder":4000}
const DELAYS := {"link":140, "echo":240, "chorus":180}
const ECHO_CONTACTS := 3
const CHORUS_CONTACTS := 4
const MAX_GRAFT_RECORDS := 16
const VERSION_DATA := [DELAYS,ECHO_CONTACTS,CHORUS_CONTACTS,MAX_GRAFT_RECORDS]
const DEATH_CHARGE_CAP := 3


static func grave_count(player: Dictionary) -> int:
	return int(player.get("grave_charges",0)) + graft_charges(player)


static func capture(player: Dictionary, adaptation_ids: Array) -> Dictionary:
	var run_id := Expedition.run_identity(player)
	if run_id < 0 or adaptation_ids.is_empty():
		return {}
	var sources: Array = []
	for component: String in adaptation_ids:
		if not PROC_KEYS.has(component):
			continue
		var part := Parts.index_of(component)
		if not Parts.is_monster(part):
			continue
		var entry: Dictionary = Parts.DEFINITIONS[part]
		var authored: Dictionary = Parts.MONSTER_DEFINITIONS[int(entry.monster)].effects
		var effects := {}
		for key: String in PROC_KEYS[component]:
			effects[key] = authored[key]
		sources.append({"component_id":component, "item_id":entry.item_id, "effects":effects})
	return {} if sources.is_empty() else {"sources":sources, "run":run_id, "life":PlayerLifecycle.generation(player)}


static func clear(player: Dictionary) -> void:
	player.erase(STATE)


static func counters(player: Dictionary, component: String) -> Dictionary:
	return player.get(STATE, {}).get(component, {})


static func graft_charges(player: Dictionary) -> int:
	return int(counters(player, "monster:pallbearer").get("grave_charges", 0))


static func start_contact(game: Node, player: Dictionary, stats: Dictionary, target: int, now: int) -> Dictionary:
	var snapshot: Dictionary = stats.get(CONTEXT, {})
	if snapshot.is_empty() or stats.get("trait_secondary", false) or stats.get("core_hit", false) \
			or not game.multiplayer.is_server() or not game.Life.alive(player) \
			or int(snapshot.run) != Expedition.run_identity(player) or not PlayerLifecycle.matches(player,int(snapshot.life)):
		return {}
	var action: RefCounted = stats.get("cr02_action")
	if action == null or not action.source in ["form","native_weapon"] or action.epoch != game.participation.epoch() or now >= action.expires_at:
		return {}
	var token := "leader" if target == -1 else str(game.encounter.token(target))
	if not action.take_response("native_graft/" + token):
		return {}
	return {"sources":snapshot.sources, "life":snapshot.life, "run":snapshot.run, "point":game.enemy_position(target),
		"attack":action.identity, "class_charge":int(player.get("grave_charges",0)) > 0}


static func bonus(game: Node, player: Dictionary, contact: Dictionary, _now: int) -> float:
	if contact.class_charge or not contact.sources.any(func(source): return source.effects.has("death_charge")):
		return 0.0
	var state := counters(player,"monster:pallbearer")
	if int(state.get("grave_charges",0)) <= 0:
		return 0.0
	state.grave_charges -= 1
	load("res://combat_status.gd").proc(game,"momentum",player.pos,contact.point)
	return 1.0


static func nearby(game: Node, exclude: int, point: Vector3, reach: float) -> Array[int]:
	var result: Array[int] = []
	for target in range(-1, game.encounter.scout_count()):
		if target == exclude or not game.Traits.valid_target(game,target):
			continue
		var at: Vector3 = game.enemy_position(target)
		if point.distance_to(at) <= reach and game.battlefield.combat_sight(point,at):
			result.append(target)
	result.sort_custom(func(a: int,b: int):
		var da: float = point.distance_squared_to(game.enemy_position(a))
		var db: float = point.distance_squared_to(game.enemy_position(b))
		return a < b if da == db else da < db)
	return result


static func has_room(game: Node) -> bool:
	# Reserve part of the shared 24-record queue for native spells and traps.
	return game.effect_timeline.native_count(true) < MAX_GRAFT_RECORDS


static func secondary_stats(points: float) -> Dictionary:
	return {"damage":points, "affinity_hp":Preview.effect_hp(points),
		"trait_secondary":true, "core_hit":true, "knockback":-.35}


static func queue_hits(game: Node, player: Dictionary, targets: Array[int], stats: Dictionary, contact: Dictionary,
		source: Dictionary, now: int, kind: String) -> bool:
	if targets.is_empty() or not has_room(game):
		return false
	var first := targets[0]
	var row: Dictionary=game.Traits.queue_hit(game,player,first,stats,now,int(DELAYS[kind]),kind=="link",contact.point,kind,source)
	if row.is_empty():return false
	row.stats = secondary_stats(float(row.stats.damage))
	if targets.size() > 1:
		# One bounded queue record for the entire pulse. Each victim keeps its
		# own spawn token and must still be visible and alive at impact.
		row.graft_targets = []
		for target in targets:
			var token: int = -1 if target == -1 else game.encounter.token(target)
			row.graft_targets.append({"target":target,"token":token})
	return game.effect_timeline.update_native(row)


static func resolve_queued(game: Node, player: Dictionary, row: Dictionary, now: int) -> void:
	var victims: Array = row.get("graft_targets",[{"target":row.target,"token":row.token}])
	for victim: Dictionary in victims:
		var target: int = victim.target
		if not game.Traits.valid_target(game,target,int(victim.token)):
			continue
		var point: Vector3 = game.enemy_position(target)
		if game.battlefield.combat_sight(row.origin,point):
			load("res://combat_status.gd").proc(game,row.visual,row.origin,point,target,0.0,"adaptation")
			OutgoingHits.hit_world(game, HitSession.peer_for(player), target, row.origin, row.stats, now)
	if game.encounter_cleared():
		game.finish_combat(int(row.owner),row.origin)


static func finish_contact(game: Node, player: Dictionary, target: int, stats: Dictionary,
		contact: Dictionary, now: int, killed: bool) -> void:
	var states: Dictionary = player.get(STATE,{})
	player[STATE] = states
	for captured: Dictionary in contact.sources:
		var component: String = captured.component_id
		var state: Dictionary = states.get_or_add(component,{})
		var source := captured.merged({"attack":contact.attack,"life":contact.life,"run":contact.run})
		match component:
			"monster:pallbearer":
				if killed and game.Life.Sustain.eligible(game,target) and grave_count(player) < DEATH_CHARGE_CAP:
					state.grave_charges = int(state.get("grave_charges",0)) + int(captured.effects.death_charge)
			"monster:spore_widow":
				if now >= int(state.get("ready_at",0)):
					var targets := nearby(game,target,contact.point,3.0)
					if not targets.is_empty() and queue_hits(game,player,[targets[0]],stats,contact,source,now,"link"):
						state.ready_at = now + TIMING.link
			"monster:glasscap":
				state.echo_charge = mini(ECHO_CONTACTS,int(state.get("echo_charge",0)) + 1)
				if state.echo_charge == ECHO_CONTACTS:
					var targets := nearby(game,target,contact.point,3.0)
					if not targets.is_empty() and queue_hits(game,player,[targets[0]],stats,contact,source,now,"echo"):
						state.echo_charge = 0
			"monster:root_choir":
				state.chorus_contacts = mini(CHORUS_CONTACTS,int(state.get("chorus_contacts",0)) + 1)
				if state.chorus_contacts == CHORUS_CONTACTS:
					var targets := nearby(game,target,contact.point,3.2)
					var pulse := {"damage":Preview.proc_amount(float(captured.effects.chorus_pulse),1,3)}
					if queue_hits(game,player,targets,pulse,contact,source,now,"chorus"):
						state.chorus_contacts = 0
			"monster:ashen_hart":
				if now >= int(state.get("ready_at",0)) and has_room(game):
					var field: Dictionary = game.Traits.zone(game,player,"cinder",contact.point,1.8,2600,
						Preview.proc_amount(float(captured.effects.cinder_trail),1,3),now,false,null,source)
					if not field.is_empty():
						state.ready_at = now + TIMING.cinder
