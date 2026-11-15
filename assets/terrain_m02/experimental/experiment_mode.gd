extends RefCounted

const FLAG := "--experimental-terrain"
const PROFILE_ENV := "MYSTICAL_TERRAIN_PROFILE"
const ROOT_NAME := "Mystical Garden Prototype"
const Auth = preload("res://persistence_authorization.gd")
const Playtest = preload("res://playtest_storage.gd")
const NETWORK_VERSION := "integrated-terrain-coop-1"

static func requested() -> bool:
	if Playtest.retail():
		return Playtest.build().get("terrain_mode", "") == NETWORK_VERSION
	return OS.has_feature("editor") and FLAG in OS.get_cmdline_user_args()

static func verified() -> bool:
	if not requested():
		return false
	if Playtest.retail():
		return Playtest.inspected
	var root := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	var profile := OS.get_environment(PROFILE_ENV).replace("\\", "/").trim_suffix("/")
	var folder := profile.get_file()
	if not RegEx.create_from_string("^mg-terrain-[0-9a-f]{32}$").search(folder):
		return false
	var name: String = Playtest.build().get("save_root", ROOT_NAME)
	if root.nocasecmp_to(profile.path_join(name)) != 0:
		return false
	var scope := Auth._root()
	if scope.error != OK or not Auth.replacement_available():
		return false
	return FileAccess.get_file_as_string(profile.path_join("terrain-session.marker")) == folder

static func active(node: Node) -> bool:
	return node.has_meta(&"experimental_terrain")

static func network_identity(node: Node) -> String:
	if not active(node):
		return ""
	return NETWORK_VERSION + "/" + str(Playtest.build().get("git_commit", "")) if Playtest.retail() else NETWORK_VERSION
