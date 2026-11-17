extends RefCounted

const Catalog = preload("res://enemy_catalog.gd")
const Journal = preload("res://diagnostic_journal.gd")
const STATE := &"wilds_skill_tactics"
const CAST_DENIAL := "cast_denial"
const AREA_PRESSURE := "area_pressure"
const ROUTE_DENIAL := "route_denial"
const SHELTER_BREAK := "shelter_break"
const REGULAR_RESPONSES := {
	0: {"id": "rooted_sweep", "tactic": ROUTE_DENIAL, "floor": 6, "mode": "swipe", "cue": "Bark sweep"},
	1: {"id": "echo_bud", "tactic": CAST_DENIAL, "floor": 7, "mode": "volley", "cue": "Echo bud"},
	2: {"id": "antler_hook", "tactic": ROUTE_DENIAL, "floor": 7, "mode": "charge", "cue": "Antler hook"},
	5: {"id": "forked_roots", "tactic": CAST_DENIAL, "floor": 8, "mode": "snare", "cue": "Forked roots"},
	6: {"id": "spore_fan", "tactic": CAST_DENIAL, "floor": 9, "mode": "artillery", "cue": "Spore fan"},
	7: {"id": "fault_front", "tactic": CAST_DENIAL, "floor": 9, "mode": "stomp", "cue": "Fault front"},
	8: {"id": "side_sting", "tactic": ROUTE_DENIAL, "floor": 7, "mode": "skirmish", "cue": "Side sting"},
	11: {"id": "canopy_shift", "tactic": SHELTER_BREAK, "floor": 8, "mode": "stomp", "cue": "Canopy shift"},
	12: {"id": "low_lantern", "tactic": CAST_DENIAL, "floor": 9, "mode": "lure", "cue": "Low lantern"},
	13: {"id": "deep_seam", "tactic": ROUTE_DENIAL, "floor": 8, "mode": "charge", "cue": "Deep seam"},
	14: {"id": "web_pockets", "tactic": CAST_DENIAL, "floor": 9, "mode": "snare", "cue": "Web pockets"},
	16: {"id": "hooked_grab", "tactic": ROUTE_DENIAL, "floor": 9, "mode": "trophy_grab", "cue": "Hooked grab"},
	17: {"id": "ember_fork", "tactic": ROUTE_DENIAL, "floor": 9, "mode": "charge", "cue": "Ember fork"},
	18: {"id": "glass_crossfire", "tactic": CAST_DENIAL, "floor": 9, "mode": "volley", "cue": "Glass crossfire"},
}
const RELAY := "relay_order"
const SCATTER := "scattered_hatch"
const ECHO_TOLL := "echo_toll"
const SPARE_TETHER := "spare_tether"
const ANTIPHON := "antiphon"
const RELAY_WINDUP := 1150
const SUPPORT_RITES := {3: "chant", 9: "brood", 10: "shepherd", 15: "chant", 19: "shepherd"}
const RESPONSES := {
	RELAY: {"kind": 10, "tactic": CAST_DENIAL, "floor": 7, "cue": "Relay order", "windup": RELAY_WINDUP},
	SCATTER: {"kind": 9, "tactic": AREA_PRESSURE, "floor": 10, "cue": "Scattered hatch"},
	ECHO_TOLL: {"kind": 3, "tactic": CAST_DENIAL, "floor": 7, "cue": "Echo toll", "windup": 1300},
	SPARE_TETHER: {"kind": 15, "tactic": CAST_DENIAL, "floor": 8, "cue": "Spare tether", "windup": 1250},
	ANTIPHON: {"kind": 19, "tactic": CAST_DENIAL, "floor": 9, "cue": "Antiphon", "windup": 1350},
}


static func evidence(game: Node) -> Dictionary:
	var state: Dictionary = game.get_meta(STATE, {})
	return state.get("counts", {}) if int(state.get("epoch", -1)) == game.combat_epoch else {}


static func record(game: Node, tactic: String, detail: Dictionary) -> void:
	if not game.multiplayer.is_server():
		return
	var counts := evidence(game)
	counts[tactic] = int(counts.get(tactic, 0)) + 1
	game.set_meta(STATE, {"epoch": game.combat_epoch, "counts": counts})
	detail.merge({"tactic": tactic, "floor": game.encounter_number})
	Journal.event("combat", "wilds_skill_evidence", detail)


static func interrupted(game: Node, actor: Dictionary, source: String) -> void:
	if not game.multiplayer.is_server() or actor.is_empty() or actor.get("summoned", false):
		return
	var kind: int = actor.kind
	var attack: Dictionary = actor.get("attack", {})
	var profile: Dictionary = REGULAR_RESPONSES.get(kind, {})
	var regular_cast: String = profile.get("mode", "") if profile.get("tactic") == CAST_DENIAL else ""
	var expected: String = SUPPORT_RITES.get(kind, regular_cast)
	var hp: int = game.encounter.hp_for(actor)
	if expected.is_empty() or hp <= 0 or attack.get("mode") != expected or attack.get("interruption_observed", false):
		return
	# Empty rituals do not teach the Wilds. There has to be an actual hatch, escort, or corpse.
	if kind == 9 and attack.get("hatch", []).is_empty():
		return
	if kind == 10 and attack.get("escorts", []).is_empty():
		return
	if kind in [3, 19] and not attack.get("rite_has_ally", false):
		return
	if kind == 15:
		var corpse: Dictionary = attack.get("corpse", {})
		if corpse.is_empty():
			return
		actor.disrupted_corpse = corpse.token
	attack.interruption_observed = true
	actor.rite_disrupted_epoch = game.combat_epoch
	if kind == 1:
		actor.denied_aim = attack.to
	record(game, CAST_DENIAL, {"source": source, "species": Catalog.get_kind(kind).id,
		"target_token": game.encounter.token_for(actor), "move": attack.get("variant", "") if not str(attack.get("variant", "")).is_empty() else expected})


static func eligible(game: Node, actor: Dictionary, response: String) -> bool:
	var kind: int = actor.kind
	var profile: Dictionary = RESPONSES.get(response, REGULAR_RESPONSES.get(kind, {}))
	if profile.is_empty() or profile.get("kind", kind) != kind or profile.get("id", response) != response or game.encounter_number < int(profile.floor) or actor.get("skill_response_used", false) or actor.get("summoned", false) or Catalog.get_kind(kind).get("boss", false):
		return false
	var strength: int = game.progress.wilds_memory.score.get(profile.tactic, 0)
	var roll := posmod(int(game.map_seed) + int(actor.route) * 37 + int(actor.kind) * 19 + int(game.encounter_number) * 11, 10)
	return strength >= 6 and roll < mini(7, 3 + floori(strength / 6.0))


static func retry_available(game: Node, actor: Dictionary, response: String) -> bool:
	return int(actor.get("rite_disrupted_epoch", -1)) == game.combat_epoch and eligible(game, actor, response)


static func response_windup(attack: Dictionary, ordinary: int) -> int:
	return int(RESPONSES.get(attack.get("variant", ""), {}).get("windup", ordinary))


static func root_denied(game: Node, target: int, now: int) -> void:
	if not game.multiplayer.is_server() or (target == -1 and game.tactics.boss_kind >= 0) or not game.Traits.valid_target(game, target):
		return
	var actor: Dictionary = game.encounter.scout(target) if target >= 0 else game.encounter.leader_tactics()
	if actor.is_empty() or actor.get("summoned", false) or actor.get("route_denied_epoch", -1) == game.combat_epoch:
		return
	if REGULAR_RESPONSES.get(actor.kind, {}).get("tactic") != ROUTE_DENIAL:
		return
	var engaged: bool = game.tactics.engaged if target == -1 else actor.engaged
	var winding: bool = game.tactics.winding_up if target == -1 else int(actor.windup) > 0
	var until: int = game.tactics.rooted_until if target == -1 else actor.rooted_until
	if not engaged or winding or until > now:
		return
	var point: Vector3 = game.enemy_position(target)
	var peer: int = game.nearest_wild_player(point)
	if peer == 0 or point.distance_squared_to(game.players[peer].pos) < 1.35 * 1.35:
		return
	actor.route_denied_epoch = game.combat_epoch
	record(game, ROUTE_DENIAL, {"species": Catalog.get_kind(actor.kind).id, "target_token": game.encounter.token_for(actor)})


static func regular_ready(game: Node, actor: Dictionary, profile: Dictionary) -> bool:
	if not game.multiplayer.is_server() or not eligible(game, actor, profile.id):
		return false
	match profile.tactic:
		CAST_DENIAL: return actor.get("rite_disrupted_epoch", -1) == game.combat_epoch
		ROUTE_DENIAL: return actor.get("route_denied_epoch", -1) == game.combat_epoch
		SHELTER_BREAK: return actor.get("shelter_break_epoch", -1) == game.combat_epoch
	return false


static func lock_response(game: Node, actor: Dictionary, attack: Dictionary) -> void:
	var response: String = attack.get("variant", "")
	var regular: Dictionary = REGULAR_RESPONSES.get(actor.kind, {})
	var profile: Dictionary = RESPONSES.get(response, regular if regular.get("id") == response else {})
	if profile.is_empty():
		return
	actor.skill_response_used = true
	Journal.event("combat", "wilds_skill_response", {"response": response, "species": Catalog.get_kind(int(actor.kind)).id,
		"tactic": profile.tactic, "target_token": game.encounter.token_for(actor), "floor": game.encounter_number})
