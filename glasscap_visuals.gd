extends RefCounted
## Render each false body from the real actor's mesh, scale, growth and animated pose.

const Feint = preload("res://glasscap_feint.gd")
const POSITIONS := &"glasscap_positions"
const VIEWS := &"glasscap_views"


static func prepare(stage: Node3D, warnings: Array) -> void:
	var positions := {}
	for warning in warnings:
		if warning.role != Feint.ROLE:
			continue
		var source := source_node(stage,int(warning.slot))
		if source != null:
			positions[source.get_instance_id()] = warning
	stage.set_meta(POSITIONS,positions)


static func motion(stage: Node3D, root: Node3D, actor: Dictionary, target: Vector3) -> Vector3:
	if int(actor.kind)!=Feint.KIND:
		return target
	var formation: Dictionary = stage.get_meta(POSITIONS,{}).get(root.get_instance_id(),{})
	if formation.is_empty():
		actor.erase("glasscap_motion")
		return target
	var phase := str(formation.id) + (":release" if formation.released else ":cast")
	var at: Vector3 = stage.WILD_OFFSET+point(formation.real)
	var swapped: bool = actor.get("glasscap_motion","")!=phase and formation.released
	if swapped:
		root.position = at
		actor.last = at
		actor.speed = 0.0
		actor.pace = 0.0
	actor.glasscap_motion = phase
	return at if swapped or target.distance_to(at)>=Feint.SPACING*.8 else target


static func sync(stage: Node3D, observer: Vector3, sight: float) -> void:
	var views: Dictionary = stage.get_meta(VIEWS,{})
	var kept := {}
	for formation in stage.get_meta(POSITIONS,{}).values():
		var slot := int(formation.slot)
		var source := source_node(stage,slot)
		var actor: Dictionary = stage.foe_model if slot<0 else stage.scout_models[slot]
		var alive: bool = stage.last_foe_hp>0 if slot<0 else stage.support_hp[slot]>0
		if not alive or int(actor.kind)!=Feint.KIND:
			continue
		kept[formation.id] = true
		if not views.has(formation.id):
			var copies := []
			for index in formation.decoys.size():
				copies.append(copy_actor(stage,source))
			views[formation.id] = copies
		for index in formation.decoys.size():
			var copy: Dictionary = views[formation.id][index]
			var at := point(formation.decoys[index])
			copy.root.transform = Transform3D(source.basis,stage.WILD_OFFSET+at)
			copy.root.visible = observer.distance_to(at)<=sight
			for pair in copy.parts:
				if is_instance_valid(pair[0]):
					pair[1].transform = pair[0].transform
					pair[1].visible = pair[0].visible
	for id in views.keys():
		if kept.has(id):
			continue
		for copy in views[id]:
			copy.root.hide()
			copy.root.queue_free()
		views.erase(id)
	stage.set_meta(VIEWS,views)


static func copy_actor(stage: Node3D, source: Node3D) -> Dictionary:
	var clone := source.duplicate(0) as Node3D
	stage.add_child(clone)
	var parts := []
	for original in source.find_children("*","Node3D",true,false):
		var mirror := clone.get_node_or_null(source.get_path_to(original)) as Node3D
		if mirror != null:
			parts.append([original,mirror])
	return {"root":clone,"parts":parts}


static func source_node(stage: Node3D, slot: int) -> Node3D:
	if slot<0:
		return stage.foe
	return stage.support_models[slot] if slot<stage.support_models.size() else null


static func point(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
