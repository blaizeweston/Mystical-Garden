extends RefCounted

const FLAG := "--experimental-terrain"
const PROFILE_ENV := "MYSTICAL_TERRAIN_PROFILE"
const ROOT_NAME := "Mystical Garden Prototype"
const Auth = preload("res://persistence_authorization.gd")

static func requested() -> bool:
	return OS.has_feature("editor") and FLAG in OS.get_cmdline_user_args()

static func verified() -> bool:
	if not requested():
		return false
	var root := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	var profile := OS.get_environment(PROFILE_ENV).replace("\\", "/").trim_suffix("/")
	var folder := profile.get_file()
	if not RegEx.create_from_string("^mg-terrain-[0-9a-f]{32}$").search(folder):
		return false
	if root.nocasecmp_to(profile.path_join(ROOT_NAME)) != 0:
		return false
	var scope := Auth._root()
	if scope.error != OK or not Auth.replacement_available():
		return false
	return FileAccess.get_file_as_string(profile.path_join("terrain-session.marker")) == folder

static func active(node: Node) -> bool:
	return node.has_meta(&"experimental_terrain")
