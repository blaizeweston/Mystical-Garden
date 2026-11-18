extends RefCounted
## Builds temporary arena characters. They use real class data and never touch a saved character.

const Character = preload("res://character_profile.gd")
const Classes = preload("res://class_catalog.gd")


static func class_count() -> int:
	return Classes.DEFINITIONS.size()


static func class_name_of(class_id: int) -> String:
	return str(Classes.DEFINITIONS[clampi(class_id, 0, class_count() - 1)].name)


## Returns a level 1 character of the chosen class with its first starting focus selected.
static func make(class_id: int, display_name: String) -> Dictionary:
	var chosen := clampi(class_id, 0, class_count() - 1)
	var profile: Dictionary = Character.blank()
	profile.name = display_name
	profile.active_class = chosen
	var tree: RefCounted = Classes.connected_tree(chosen)
	if tree != null and tree.eligible(profile):
		for index in tree.nodes.size():
			if int(tree.nodes[index].tier) == 0 and str(tree.learn(profile, tree.REQUEST_OFFSET + index)).is_empty():
				break
	return Character.normalize(profile)
