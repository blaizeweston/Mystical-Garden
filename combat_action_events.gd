extends RefCounted

const Ruleset = preload("res://combat_ruleset.gd")

const RECORD = &"cr02_record_combat_event"
const CONTEXT = "cr02_action"
const WARD = "cr02_ward"
const CHANNELS := ["weapon_contact", "core_action", "class_action", "class_contact",
	"actual_block", "armor_break", "periodic", "secondary"]

var identity: int
var epoch: int
var actor: int
var source: String
var affinity: String
var quality: String
var material_id: String
var expires_at: int
var charges: int
var _potency: Dictionary
var _permitted: Array
var _seen := {}


static func begin(game: Node, actor_id: int, origin: String, material: Dictionary,
		potency: Dictionary, permitted: Array, until: int, charge_limit := -1) -> RefCounted:
	if not Ruleset.active(game) or not game.multiplayer.is_server() or permitted.is_empty():
		return null
	for channel in permitted:
		if channel not in CHANNELS:
			return null
	var event := new()
	event.identity = int(game.get_meta(&"cr02_activation_serial", 0)) + 1
	game.set_meta(&"cr02_activation_serial", event.identity)
	event.epoch = game.combat_epoch
	event.actor = actor_id
	event.source = origin
	event.affinity = material.get("primary_affinity", "")
	event.quality = material.get("quality", "")
	event.material_id = material.get("item_id", "")
	event.expires_at = until
	event.charges = charge_limit
	event._potency = potency.duplicate(true)
	event._permitted = permitted.duplicate()
	return event


func publish(game: Node, channel: String, contact_id: String, target: String, now: int, details: Dictionary = {}) -> bool:
	if not Ruleset.active(game) or not game.multiplayer.is_server() or game.combat_epoch != epoch:
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
	return true


static func class_start(game: Node, actor_id: int, adapter: Dictionary, now: int) -> RefCounted:
	var channels := {"activation": ["class_action"], "contact": ["class_contact"], "block": ["actual_block"]}
	return begin(game, actor_id, "native_class", {}, {},
		channels.get(adapter.get("trigger"), []), now + 30000)


static func class_complete(game: Node, event: RefCounted, adapter: Dictionary, start: Vector3, center: Vector3,
		targets: Array, recipients: Array, now: int) -> void:
	if event == null or adapter.trigger != "activation":
		return
	event.publish(game, "class_action", "cast", "", now,
		{"adapter": adapter.id, "start": start, "center": center, "enemies": targets, "recipients": recipients})


static func contact(game: Node, stats: Dictionary, target: int, now: int, secondary := false) -> void:
	var event: RefCounted = stats.get(CONTEXT)
	if event == null:
		return
	var channel := "secondary" if secondary else "class_contact" if event.source == "native_class" else "weapon_contact"
	var token := "leader" if target == -1 else str(game.scouts[target].get("spawn_token", target))
	event.publish(game, channel, "contact", token, now)


static func grant_ward(game: Node, recipient: Dictionary, until: int, charges: int,
		event: RefCounted, adapter: Dictionary, now: int) -> void:
	var before_until := int(recipient.get("guard_until", 0))
	var before_charges := int(recipient.get("guard_charges", 0))
	game.grant_guard(recipient, until, charges)
	if event == null or adapter.trigger != "block":
		return
	# Native Guard uses a max-duration/max-charge merge. Attach ownership only
	# when this grant is independently attributable. Mixed overlapping grants
	# need an explicit depletion policy before Catalyst Ward effects ship.
	if before_until > now and (until <= before_until or charges < before_charges):
		return
	recipient[WARD] = {"event": event, "expires": until, "adapter": adapter.id, "limit": adapter.limit}


static func blocked(game: Node, recipient_id: int, recipient: Dictionary, now: int) -> void:
	var ward: Dictionary = recipient.get(WARD, {})
	recipient.erase(WARD)
	if ward.is_empty() or now >= int(ward.expires):
		return
	var target := str(recipient_id)
	var dedup := target if ward.limit == "recipient" else ""
	ward.event.publish(game, "actual_block", "ward", dedup, now,
		{"adapter": ward.adapter, "recipient": recipient_id, "center": recipient.pos})
