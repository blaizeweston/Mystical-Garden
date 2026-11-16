extends RefCounted
static var values: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content/balance.json"))
static func get_value(id: String,fallback): return values.get(id,fallback)
static func levels() -> Array: return values.get("class_xp",[0,50,150,350,700])
