extends RefCounted
## Wilds preview climate. The six-floor gameplay bands are independent of these weights.

const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const FLOOR_COUNT := 18
const WINDOWS := [Vector2i(5, 8), Vector2i(11, 14)]
const PROFILES := [
	{"moisture": 0.27, "width": 1.15, "pools": 0.15, "river_offset": 1.4, "forest": 0.80,
		"stone_cover": 0.19, "ground_cover": 0.68, "sun_energy": 0.83, "ambient_energy": 0.67,
		"haze": 0.008, "air": Color("#28382d"), "floor": Color("#c3ba8e"), "wet": Color("#50766b"),
		"accent_density": 0.58},
	{"moisture": 0.90, "width": 2.48, "pools": 2.9, "river_offset": 0.4, "forest": 0.39,
		"stone_cover": 0.09, "ground_cover": 0.81, "sun_energy": 0.69, "ambient_energy": 0.70,
		"haze": 0.019, "air": Color("#35453c"), "floor": Color("#8eaa7f"), "wet": Color("#416855"),
		"accent_density": 0.79},
	{"moisture": 0.43, "width": 0.73, "pools": 0.04, "river_offset": 2.9, "forest": 0.15,
		"stone_cover": 0.62, "ground_cover": 0.30, "sun_energy": 0.48, "ambient_energy": 0.69,
		"haze": 0.016, "air": Color("#342d44"), "floor": Color("#ac9ebc"), "wet": Color("#4c4d74"),
		"accent_density": 0.90},
]

static func floor_biome(floor_number: int) -> int:
	return (clampi(floor_number, 1, FLOOR_COUNT) - 1) / 6

static func weights(floor_number: int, windows: Array = WINDOWS) -> Vector3:
	assert(windows.size() == PROFILES.size() - 1)
	for i in windows.size():
		var window: Vector2i = windows[i]
		assert(window.x < window.y and (i == 0 or windows[i - 1].y < window.x))
		if floor_number < window.x:
			return _basis(i)
		if floor_number <= window.y:
			var t := inverse_lerp(window.x, window.y, floor_number)
			var next := 0.5 - 0.5 * cos(PI * t)
			return _basis(i).lerp(_basis(i + 1), next)
	return Vector3(0, 0, 1)

static func _basis(index: int) -> Vector3:
	var value := Vector3.ZERO
	value[index] = 1.0
	return value

static func climate(floor_number: int, windows: Array = WINDOWS) -> Dictionary:
	var mix := weights(floor_number, windows)
	var profile := {"weights": mix, "biome": floor_biome(floor_number), "floor_number": clampi(floor_number, 1, FLOOR_COUNT)}
	for field in PROFILES[0]:
		profile[field] = _blend(PROFILES[0][field], PROFILES[1][field], PROFILES[2][field], mix)
	for field in ["sun", "ambient", "ground", "water"]:
		profile[field] = _blend(Art.PROFILES[1][field], Art.PROFILES[2][field], Art.PROFILES[3][field], mix)
	return profile

static func _blend(a: Variant, b: Variant, c: Variant, mix: Vector3) -> Variant:
	return a * mix.x + b * mix.y + c * mix.z

static func family(mix: Vector3, roll: float) -> int:
	if roll < mix.x:
		return 0
	return 1 if roll < mix.x + mix.y else 2
