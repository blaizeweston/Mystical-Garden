extends RefCounted
const FieldRig = preload("res://field_traveller.gd")

static func build(parent: Node) -> Dictionary:
	var model := Node3D.new()
	parent.add_child(model)
	var actor := {"model":model, "phase":0.0, "pace":0.0, "last":Vector3.INF}
	swap(actor, 0)
	return actor

static func swap(actor: Dictionary, kind: int) -> void:
	for key in ["visual_weapon", "secondary_weapon"]:
		if actor.has(key):
			actor[key].free()
			actor.erase(key)
	actor.erase("weapon_key")
	if actor.has("field_rig"):
		actor.field_rig.scene.free()
	actor.rig_kind = clampi(kind, 0, FieldRig.MODELS.size() - 1)
	actor.look_key = ""
	actor.field_rig = FieldRig.build(actor.model, actor.rig_kind)

static func animate(actor: Dictionary, active: bool, phase: float, form: String, motion: Dictionary = {}, delta: float = 1.0/60.0) -> void:
	actor.idle_time = float(actor.get("idle_time", 0.0)) + delta
	FieldRig.animate(actor, active, phase, form, motion, delta)
