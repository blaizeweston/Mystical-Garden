extends RefCounted
const Protection = preload("res://player_protection.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Ruleset = preload("res://combat_ruleset.gd")

const RECORD = &"cr02_record_combat_event"
const CONTEXT = "cr02_action"
const Frost = preload("res://frost_combat.gd")
const CHANNELS := ["weapon_contact", "core_action", "class_action", "class_contact",
	"actual_block", "armor_break", "periodic", "secondary", "incoming_hit", "class_field_contact"]

var native_slot := -1
var card_potency_bonus := 0
var identity: int
var epoch: int
var actor: int
var life_generation: int
var connection_binding: int
var source: String
var affinity: String
var quality: String
var material_id: String
var expires_at: int
var charges: int
var _potency: Dictionary
var _permitted: Array
var _seen := {}
var _granted := {}
var _responses := {}


static func begin(game: Node, actor_id: int, origin: String, material: Dictionary,
		potency: Dictionary, permitted: Array, until: int, charge_limit := -1) -> RefCounted:
	if not game.multiplayer.is_server() or permitted.is_empty():
		return null
	for channel in permitted:
		if channel not in CHANNELS:
			return null
	var life := PlayerLifecycle.generation(game.players.get(actor_id,{}))
	if life < 1:
		return null
	var event := new()
	event.life_generation = life
	event.connection_binding = game.network_session.binding(actor_id)
	event.identity = int(game.get_meta(&"cr02_activation_serial", 0)) + 1
	game.set_meta(&"cr02_activation_serial", event.identity)
	event.epoch = game.participation.epoch()
	event.actor = actor_id
	event.source = origin
	event.affinity = material.get("primary_affinity", "")
	event.quality = material.get("quality", "")
	event.material_id = material.get("item_id", "")
	event.expires_at = until
	event.charges = charge_limit
	# Capture exactly the same scoped values exposed by the resolved build.
	# Past applications keep their captured potency after subsequent upgrades.
	event._potency = game.combat_build(game.players[actor_id]).affinity_potency(origin,material,potency)
	event._permitted = permitted.duplicate()
	return event


func publish(game: Node, channel: String, contact_id: String, target: String, now: int, details: Dictionary = {}) -> bool:
	if not game.multiplayer.is_server() or game.participation.epoch() != epoch:
		return false
	var owner: Dictionary = game.players.get(actor,{})
	if not PlayerLifecycle.matches(owner,life_generation):
		return false
	# Accepted defensive grants can still respond while their source is downed.
	if PlayerLifecycle.fallen(owner) and channel not in ["actual_block","incoming_hit"]:
		return false
	if now >= expires_at or charges == 0 or not channel in _permitted:
		return false
	var key := JSON.stringify([channel, contact_id, target])
	if _seen.has(key):
		return false
	_seen[key] = true
	if charges > 0:
		charges -= 1
	var record: Callable = game.get_meta(RECORD, Callable())
	if record.is_valid():
		record.call({
			"ruleset": Ruleset.ID, "epoch": epoch, "activation": identity,
			# An activation is a deduplication identity, never a stack identity.
			"stack_source": [actor, source], "source_actor": actor, "source": source,
			"primary_affinity": affinity, "quality": quality, "item_id": material_id,
			"potency": _potency.duplicate(true), "kind": channel, "contact": contact_id,
			"target": target, "expires_at": expires_at, "charges_remaining": charges,
			"details": details.duplicate(true),
		})
	if source in ["core", "form", "catalyst"]:
		match affinity:
			"frost": Frost.on_event(game, self, channel, details, now)
			"fire": Ruleset.Fire.on_event(game, self, channel, details, now)
			"water": Ruleset.Water.on_event(game, self, channel, details, now)
			"vital": Ruleset.Vital.on_event(game, self, channel, details, now)
			"thorn": Ruleset.Thorn.on_event(game, self, channel, details, now)
			"wood": Ruleset.Wood.on_event(game, self, channel, details, now)
			"storm": Ruleset.Storm.on_event(game, self, channel, details, now)
			"spirit": Ruleset.Spirit.on_event(game, self, channel, details, now)
			"void": Ruleset.Void.on_event(game, self, channel, details, now)
	return true


static func class_start(game: Node, actor_id: int, adapter: Dictionary, now: int, catalyst: Dictionary = {}) -> RefCounted:
	var channels := {"activation": ["class_action", "incoming_hit"], "contact": ["class_contact"], "block": ["actual_block"]}
	var ready: bool = catalyst.get("state") == "ready"
	var allowed: Array = channels.get(adapter.get("trigger"), [])
	if ready and catalyst.get("primary_affinity") in ["vital","wood"] and adapter.get("recipients") == "designated_area":
		allowed.append("class_field_contact")
	var event := begin(game, actor_id, "catalyst" if ready else "native_class", catalyst if ready else {},
		catalyst.potency_profile.values if ready else {}, allowed, now + 30000)
	if event != null: event.native_slot = int(adapter.get("slot",-1))
	return event


static func class_complete(game: Node, event: RefCounted, adapter: Dictionary, start: Vector3, center: Vector3,
		targets: Array, recipients: Array, now: int, radius := 0.0) -> void:
	if event == null or adapter.trigger != "activation":
		return
	event.publish(game, "class_action", "cast", "", now,
		{"adapter": adapter.id, "start": start, "center": center, "enemies": targets, "recipients": recipients,
			"response": adapter.get("response",""), "target_scope": adapter.recipients, "radius": radius,
			"native_displacement": float(adapter.get("native_displacement",{}).get("push",0))!=0.0 or float(adapter.get("native_displacement",{}).get("pull",0))!=0.0})


static func contact(game: Node, stats: Dictionary, target: int, now: int, secondary := false, point := Vector3.INF, forward := Vector3.ZERO) -> void:
	var event: RefCounted = stats.get(CONTEXT)
	if event == null:
		return
	var channel := "secondary" if secondary else "class_contact" if event.source in ["native_class", "catalyst"] else "weapon_contact"
	var token := "leader" if target == -1 else str(game.encounter.token(target))
	var details := {"enemy":target,"native_displacement":float(stats.get("pull",0.0))>0.0 or float(stats.get("knockback",0.0))>0.0}
	if point.is_finite():
		details.point = point
		details.forward = forward
	var charge: bool = channel=="weapon_contact" and game.players.get(event.actor,{}).has(Ruleset.Storm.CHARGE)
	if event.publish(game, channel, "contact", token, now, details) and channel=="weapon_contact":
		Ruleset.Spirit.contact(game,event,target,now)
		if charge:
			Ruleset.Storm.use_charge(game,event,target,point if point.is_finite() else game.enemy_position(target),now)


static func grant_ward(game: Node, recipient: Dictionary, until: int, charges: int,
		event: RefCounted, adapter: Dictionary, _now: int) -> void:
	var response: RefCounted = event if event != null and adapter.trigger == "block" else null
	var recipient_id: int = game.Traits.player_id(game, recipient)
	recipient[Protection.STATE] = recipient[Protection.STATE].grant(until, charges, Time.get_ticks_msec(),
		game.participation.epoch(), response, adapter, recipient_id)


func has_grants() -> bool:
	return not _granted.is_empty()


static func field_action(stats: Dictionary) -> RefCounted:
	var event: RefCounted = stats.get(CONTEXT)
	return event if event != null and "class_field_contact" in event._permitted else null


func take_response(key: String) -> bool:
	if _responses.has(key):
		return false
	_responses[key] = true
	return true


func potency() -> Dictionary:
	return _potency.duplicate(true)


func block_scope(recipient_id: int, adapter: Dictionary) -> String:
	return str(recipient_id) if adapter.limit == "recipient" else ""


func block_available(recipient_id: int, adapter: Dictionary, now: int) -> bool:
	return now < expires_at and charges != 0 and not _seen.has(JSON.stringify(["actual_block", "ward", block_scope(recipient_id, adapter)]))


func accept_grant(recipient_id: int) -> bool:
	if recipient_id <= 0 or _granted.has(recipient_id): return false
	_granted[recipient_id] = true
	return true
