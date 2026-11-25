extends RefCounted
## Named JSON files in one authorized developer storage namespace.
var world: Node

func _init(context: Node) -> void: world = context

func _dir() -> String: return ""
func _prefix() -> String: return ""

static func safe_name(value: String) -> bool:
	if value.length() < 1 or value.length() > 64 or value != value.strip_edges(): return false
	for i in value.length():
		var c := value.unicode_at(i)
		if not ((c>=65 and c<=90) or (c>=97 and c<=122) or (c>=48 and c<=57) or c in [32,45,95]): return false
	return true

func _path(folder: String, name: String) -> String:
	return folder.path_join(_prefix() + name.sha256_text() + ".json")

func names() -> Array[String]:
	var result: Array[String] = []
	var folder := _dir()
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder): return result
	for file in DirAccess.get_files_at(folder):
		if not file.begins_with(_prefix()) or not file.ends_with(".json"): continue
		var record := _read(folder.path_join(file))
		var name: Variant = record.get("name")
		if name is String and safe_name(name) and _path(folder,name).get_file()==file: result.append(name)
	result.sort()
	return result

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 262144: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func read(name: String) -> Dictionary:
	var folder := _dir()
	if folder.is_empty() or not safe_name(name): return {}
	return _read(_path(folder,name))

static func git_commit() -> String:
	var root := ProjectSettings.globalize_path("res://")
	if not DirAccess.dir_exists_absolute(root.path_join(".git")) and not FileAccess.file_exists(root.path_join(".git")): return ""
	var output := []
	if OS.execute("git", ["-C",root,"rev-parse","--verify","HEAD"],output) != 0 or output.is_empty(): return ""
	var commit := str(output[0]).strip_edges()
	return commit if commit.length()==40 and commit.is_valid_hex_number() else ""

func _write(path: String, text: String) -> Error:
	var root := _dir()
	if root.is_empty() or not ProjectSettings.globalize_path(path).simplify_path().begins_with(ProjectSettings.globalize_path(root).simplify_path()+"/"): return ERR_UNAUTHORIZED
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var result := file.get_error()
	file.close()
	return result

func _new_file(folder: String, record: Dictionary) -> String:
	if folder.is_empty() or folder != _dir(): return "Developer session required."
	if not safe_name(record.name): return "Use 1–64 letters, numbers, spaces, hyphens or underscores."
	if DirAccess.make_dir_recursive_absolute(folder)!=OK: return "Could not create developer storage."
	var path := _path(folder,record.name)
	if FileAccess.file_exists(path): return "That name is already in use."
	var temporary := path+"."+Crypto.new().generate_random_bytes(8).hex_encode()+".tmp"
	if _write(temporary,JSON.stringify(record,"  "))!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
		return "Could not save the file."
	preload("res://diagnostic_journal.gd").event("developer","developer_configuration_saved",{"kind":_prefix().trim_suffix("-")})
	return ""

func copy_named(old: String, target: String, rename: bool) -> String:
	var folder := _dir()
	var record := read(old)
	if folder.is_empty() or record.is_empty(): return "Selection unavailable."
	record.name=target
	var error := _new_file(folder,record)
	if error.is_empty() and rename:
		if DirAccess.remove_absolute(_path(folder,old))!=OK: return "New copy saved. The original could not be removed."
	return error

func remove(name: String, confirmed: bool) -> String:
	var folder := _dir()
	if folder.is_empty() or not confirmed or not safe_name(name): return "Deletion requires a confirmed developer selection."
	return "" if DirAccess.remove_absolute(_path(folder,name))==OK else "Could not delete that file."
