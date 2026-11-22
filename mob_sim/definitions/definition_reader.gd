extends RefCounted
## Reads typed fields from parsed JSON and records a precise error for each bad value.
## Every definition class parses through one reader, so all errors are collected in one pass.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")

## Marks a value that the compiler copies from the enemy catalog.
const CATALOG := "catalog"

var errors := PackedStringArray()
var _path := PackedStringArray()


func push(segment: String) -> void:
	_path.append(segment)


func pop() -> void:
	_path.resize(_path.size() - 1)


func fail(message: String) -> void:
	errors.append("%s: %s" % ["/".join(_path), message])


func has_errors() -> bool:
	return not errors.is_empty()


## Rejects fields the schema does not define, which catches misspelt keys.
func only(data: Dictionary, allowed: Array) -> void:
	for key in data:
		if not allowed.has(key):
			fail("unknown field '%s'" % key)


func text(data: Dictionary, key: String, fallback: String = "", required: bool = false) -> String:
	if not data.has(key):
		if required:
			fail("missing '%s'" % key)
		return fallback
	if typeof(data[key]) != TYPE_STRING:
		fail("'%s' must be text" % key)
		return fallback
	return data[key]


func flag(data: Dictionary, key: String, fallback: bool = false) -> bool:
	if not data.has(key):
		return fallback
	if typeof(data[key]) != TYPE_BOOL:
		fail("'%s' must be true or false" % key)
		return fallback
	return data[key]


func number(data: Dictionary, key: String, fallback: float, low: float, high: float, required: bool = false) -> float:
	if not data.has(key):
		if required:
			fail("missing '%s'" % key)
		return fallback
	var value = data[key]
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		fail("'%s' must be a number" % key)
		return fallback
	if value < low or value > high:
		fail("'%s' is %s, outside %s to %s" % [key, value, low, high])
		return fallback
	return float(value)


## A number, or the word "catalog" to inherit the species value. Returns NAN for "catalog".
func number_or_catalog(data: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	if data.get(key) is String and data[key] == CATALOG:
		return NAN
	return number(data, key, fallback, low, high)


func choice(data: Dictionary, key: String, names: Array, fallback: int = 0, required: bool = false) -> int:
	if not data.has(key):
		if required:
			fail("missing '%s'" % key)
		return fallback
	var value := Enums.value_of(names, str(data[key]))
	if value < 0:
		fail("'%s' is '%s', expected one of %s" % [key, data[key], ", ".join(PackedStringArray(names))])
		return fallback
	return value


func dictionary(data: Dictionary, key: String, required: bool = false) -> Dictionary:
	if not data.has(key):
		if required:
			fail("missing '%s'" % key)
		return {}
	if typeof(data[key]) != TYPE_DICTIONARY:
		fail("'%s' must be an object" % key)
		return {}
	return data[key]


func list(data: Dictionary, key: String, required: bool = false) -> Array:
	if not data.has(key):
		if required:
			fail("missing '%s'" % key)
		return []
	if typeof(data[key]) != TYPE_ARRAY:
		fail("'%s' must be a list" % key)
		return []
	return data[key]


## A list of [x, y] offsets. X runs sideways from the aim line and y runs along it.
func offsets(data: Dictionary, key: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	for entry in list(data, key):
		if typeof(entry) != TYPE_ARRAY or entry.size() != 2 or not (entry[0] is float or entry[0] is int) or not (entry[1] is float or entry[1] is int):
			fail("'%s' entries must be [x, y] number pairs" % key)
			continue
		if absf(entry[0]) > 12.0 or absf(entry[1]) > 12.0:
			fail("'%s' offset %s is more than 12 units away" % [key, entry])
			continue
		result.append(Vector2(entry[0], entry[1]))
	return result
