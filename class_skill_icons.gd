extends RefCounted

const ATLAS = preload("res://assets/ui/class_skills.png")
static var cells: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/class_skill_icons.json"))
static var textures: Dictionary = {}


static func icon(skill_name: String) -> Texture2D:
	if not cells.has(skill_name):
		return null
	if not textures.has(skill_name):
		var cell: Array = cells[skill_name]
		var texture := AtlasTexture.new()
		texture.atlas = ATLAS
		texture.region = Rect2(cell[0], cell[1], cell[2], cell[3])
		texture.filter_clip = true
		textures[skill_name] = texture
	return textures[skill_name]
