extends RefCounted
## The fourth slot owns these effects. Raw plant tags and run cards never
## select a handler or supply potency.
const Parts = preload("res://weapon_parts.gd")
const Preview = preload("res://combat_balance_preview.gd")
const CONTEXT = "native_graft_contact"
const STATE = "native_graft_state"
const REVISION = "native_graft_revision"
const STAT_KEYS := ["reach", "damage", "cooldown", "recovery", "pull", "knockback",
	"stagger", "windup_damage", "targets", "heal_on_kill", "max_health", "skill_cooldown",
	"loot_attract", "pierce"]
const SPECIAL := {
	"monster:spore_widow": ["link"],
	"monster:pallbearer": ["death_charge"],
	"monster:ashen_hart": ["cinder_trail"],
	"monster:glasscap": ["echo", "echo_redirect"],
	"monster:root_choir": ["chorus_pulse"],
	"monster:orchard": ["brace"],
	"monster:drowned": ["tide_pool", "pool_radius"],
	"monster:matriarch": ["link", "spread_bind"],
}
const UNSUPPORTED := {
	"monster:nameless": "Nameless Stigma requires a decision on whether its Mark shares consumption with native class Marks. It cannot be installed in affinity mode.",
}
const TIMING := {"link": 120, "cinder": 4000, "tide": 4500, "brace": 4000}


static func describe(graft: Dictionary) -> String:
	if graft.is_empty(): return ""
	if not graft.refusal.is_empty(): return graft.refusal
	var text: String = {
		"monster:seamroot": "Piercing contacts follow the native attack line, up to the resolved target limit.",
		"monster:spore_widow": "Direct contact links once to a nearby enemy in clear sight.",
		"monster:pallbearer": "An eligible killing strike earns one Death Charge (max 3). Direct contact spends one for bonus damage.",
		"monster:graft_thief": "Attracts available loose loot within 3.5 m.",
		"monster:ashen_hart": "Direct contact ignites a short damaging field. 4 s between fields.",
		"monster:glasscap": "Every third direct contact echoes to another nearby enemy in clear sight.",
		"monster:root_choir": "Every fourth direct contact pulses to other nearby enemies in clear sight.",
		"monster:orchard": "After 0.5 s stationary, brace adds weapon damage and can absorb an incoming hit once every 4 s.",
		"monster:drowned": "Direct contact creates a healing pool. 4.5 s between pools.",
		"monster:matriarch": "Direct contact links to a nearby enemy. A compatible Bind can spread to one nearby enemy.",
	}.get(graft.component_id, "")
	return text


static func resolve(part: int) -> Dictionary:
	if not Parts.is_monster(part): return {}
	var entry: Dictionary = Parts.DEFINITIONS[part]
	var id: String = entry.id
	var effects: Dictionary = Parts.MONSTER_DEFINITIONS[int(entry.monster)].effects
	var accepted_procs: Array = SPECIAL.get(id, [])
	var native := {}
	var procs := {}
	var pending := {}
	for key in effects:
		if id in UNSUPPORTED:
			pending[key] = effects[key]
		elif key in STAT_KEYS:
			native[key] = effects[key]
		elif key in accepted_procs:
			procs[key] = effects[key]
		else:
			pending[key] = effects[key]
	var refusal: String = UNSUPPORTED.get(id, "")
	if refusal.is_empty() and not pending.is_empty():
		refusal = "%s has an unsupported native graft effect in affinity mode." % entry.name
	return {"item_id": entry.item_id, "component_id": id, "native_effects": native,
		"procs": procs, "pending_effects": pending, "refusal": refusal}


static func capture(player: Dictionary, graft: Dictionary) -> Dictionary:
	return {"item_id": graft.item_id, "component_id": graft.component_id, "effects": graft.procs,
		"revision": player.get(REVISION, 0), "life": player.get("lost_health", 0)}


static func equipped(player: Dictionary, source: Dictionary) -> bool:
	var part := int(player.get("graft_part", 0))
	return Parts.is_monster(part) and Parts.DEFINITIONS[part].id == source.component_id \
		and int(player.get(REVISION, 0)) == int(source.revision) and player.get("lost_health", 0) == source.life


static func replace(player: Dictionary) -> void:
	player[REVISION] = int(player.get(REVISION, 0)) + 1
	clear(player)


static func clear(player: Dictionary) -> void:
	player.erase(STATE)


static func ready(state: Dictionary, kind: String, now: int) -> bool:
	if now < int(state.get(kind, 0)): return false
	state[kind] = now + TIMING[kind]
	return true


static func next_count(state: Dictionary, kind: String, threshold: int) -> bool:
	state[kind] = (int(state.get(kind, 0)) + 1) % threshold
	return int(state[kind]) == 0


static func start_contact(game: Node, player: Dictionary, stats: Dictionary, target: int, now: int) -> Dictionary:
	var source: Dictionary = stats.get(CONTEXT, {})
	if source.is_empty() or stats.get("trait_secondary", false) or stats.get("core_hit", false) \
			or not game.multiplayer.is_server() or not game.Life.alive(player) or not equipped(player, source):
		return {}
	var event: RefCounted = stats.get("cr02_action")
	if event == null or event.epoch != game.combat_epoch or now >= event.expires_at:
		return {}
	var token := "leader" if target == -1 else str(game.scouts[target].get("spawn_token", target))
	if not event.take_response("native_graft/" + token): return {}
	var state: Dictionary = player.get(STATE, {})
	player[STATE] = state
	return {"source": source, "state": state, "point": game.enemy_position(target), "attack": event.identity}


static func bonus(game: Node, player: Dictionary, contact: Dictionary, now: int) -> float:
	var effects: Dictionary = contact.source.effects
	var state: Dictionary = contact.state
	var point: Vector3 = contact.point
	var damage := 0.0
	if effects.has("brace") and now - int(player.get("still_since", now)) >= 500:
		damage += minf(2, float(effects.brace))
		load("res://combat_status.gd").proc(game, "brace", player.pos, point)
	if effects.has("death_charge") and int(state.get("grave_charges", 0)) > 0:
		state.grave_charges -= 1
		damage += 1
		load("res://combat_status.gd").proc(game, "momentum", player.pos, point)
	return damage


static func finish_contact(game: Node, player: Dictionary, target: int, stats: Dictionary,
		contact: Dictionary, now: int, killed: bool) -> void:
	var source: Dictionary = contact.source.duplicate()
	source.attack = contact.attack
	var effects: Dictionary = source.effects
	var state: Dictionary = contact.state
	var point: Vector3 = contact.point
	var followup := {"damage": stats.damage}
	if stats.has("preview_strike_hp"): followup.preview_strike_hp = stats.preview_strike_hp
	if killed and effects.has("death_charge") and (target == -1 or not game.scouts[target].get("summoned", false)):
		state.grave_charges = mini(3, int(state.get("grave_charges", 0)) + int(effects.death_charge))
	if effects.has("link") and ready(state,"link",now):
		var recipient: int = game.Traits.other_target(game,target,point)
		followup.link = effects.link
		game.Traits.queue_hit(game,player,recipient,followup,now,140,true,point,"link",source)
	if effects.has("echo") and next_count(state,"echo_charge",3):
		var recipient: int = game.Traits.other_target(game,target,point)
		game.Traits.queue_hit(game,player,recipient,followup,now,240,false,point,"echo",source)
	if effects.has("chorus_pulse") and next_count(state,"chorus_contacts",4):
		for candidate in game.skill_area_targets(point,3.2,point):
			if candidate != target:
				var pulse := {"damage": Preview.proc_amount(float(effects.chorus_pulse),1,3)}
				game.Traits.queue_hit(game,player,candidate,pulse,now,180,false,point,"chorus",source)
	if effects.has("cinder_trail") and ready(state,"cinder",now):
		game.Traits.zone(game,player,"cinder",point,1.8,2600,Preview.proc_amount(float(effects.cinder_trail),1,3),now,false,null,source)
	if effects.has("tide_pool") and ready(state,"tide",now):
		var power: float = game.Life.Sustain.pool_points(Preview.proc_amount(float(effects.tide_pool),1,2))
		game.Traits.zone(game,player,"tide",point,1.6+float(effects.pool_radius),2400,power,now,float(stats.get("pool_ward",0))>0,null,source)


static func brace_block(player: Dictionary, now: int) -> bool:
	var graft := resolve(int(player.get("graft_part",0)))
	if not graft.get("procs",{}).has("brace") or now - int(player.get("still_since",now)) < 500:
		return false
	var state: Dictionary = player.get(STATE,{})
	player[STATE] = state
	return ready(state,"brace",now)
