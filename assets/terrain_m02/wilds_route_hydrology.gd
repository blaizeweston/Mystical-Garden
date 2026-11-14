extends RefCounted
## Hydrology is selected independently of routes, using the blended biome weights.

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")

static func build(random: RandomNumberGenerator, extent: float, weights: Vector3, floor_number: int) -> Dictionary:
	var frame := random.randf_range(-PI, PI)
	var offset := random.randf_range(-0.20, 0.20) * extent
	var frequency := random.randf_range(0.15, 0.27)
	var amplitude := random.randf_range(0.09, 0.24) * extent
	var phase := random.randf_range(-PI, PI) + floor_number * 0.036
	var roll := random.randf()
	var dry_chance := weights.dot(Vector3(0.48, 0.0, 0.79))
	var wetland_chance := weights.dot(Vector3(0.06, 0.92, 0.02))
	var profile := {"frame": frame, "offset": offset, "frequency": frequency, "amplitude": amplitude,
		"phase": phase, "scale": extent / 24.5, "width": weights.dot(Vector3(1.07, 2.18, 0.76))}
	if roll < dry_chance:
		return {"kind": "dry", "water": [], "island": {}}
	if roll < dry_chance + wetland_chance:
		var basin := random.randf_range(-0.20, 0.20) * extent
		var waters := [_strip(profile, -extent * 1.20, extent * 1.20, basin, 1.0, false, "wetland")]
		var island := _island(profile, basin, random)
		waters[0]["holes"] = [island.outline]
		return {"kind": "wetland", "water": waters, "island": island}
	if random.randf() < 0.56:
		# Two flooded reaches terminate in the same valley, with firm ground between them.
		var ford := random.randf_range(-0.30, 0.30) * extent
		return {"kind": "reaches", "water": [
			_strip(profile, -extent * 0.92, ford - 1.9, -extent * 0.33, 0.40, true, "upper_reach"),
			_strip(profile, ford + 1.9, extent * 0.92, extent * 0.33, 0.46, true, "lower_reach")],
			"island": {}, "dry_crossing": Vector2(_center(ford, profile), ford).rotated(frame)}
	return {"kind": "stream", "water": [
		_strip(profile, -extent * 1.20, extent * 1.20, extent * 0.13, 0.18, false, "stream")], "island": {}}

static func _center(z: float, profile: Dictionary) -> float:
	var t: float = z / profile.scale
	return profile.offset + profile.amplitude * (0.71 * sin(t * profile.frequency + profile.phase)
		+ 0.29 * sin(t * profile.frequency * 1.93 - profile.phase * 0.53))

static func _strip(profile: Dictionary, low: float, high: float, basin: float, depth: float,
		taper: bool, id: String) -> Dictionary:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var count := maxi(10, ceili((high - low) / 0.43))
	for i in count + 1:
		var t := float(i) / count
		var z := lerpf(low, high, t)
		var x := _center(z, profile)
		var pool := exp(-pow((z - basin) / (3.5 * profile.scale), 2.0))
		var shape := sqrt(maxf(0.007, sin(PI * t))) if taper else 1.0
		var width: float = profile.width * (1.0 + depth * pool * 1.45 + 0.11 * sin(z * 0.40)) * shape
		left.append(Vector2(x - width, z).rotated(profile.frame))
		right.append(Vector2(x + width, z).rotated(profile.frame))
	right.reverse()
	left.append_array(right)
	return Shape.shape(id, "watercourse", left)

static func _island(profile: Dictionary, basin: float, random: RandomNumberGenerator) -> Dictionary:
	var points := PackedVector2Array()
	var length := (2.03 + random.randf() * 0.36) * sqrt(profile.scale)
	for i in 30:
		var angle := i * TAU / 30.0
		var warp := 1.0 + 0.08 * sin(angle * 3.0 + profile.phase)
		var z := basin + sin(angle) * length * warp
		var x := _center(z, profile) + cos(angle) * 1.57 * warp
		points.append(Vector2(x, z).rotated(profile.frame))
	var island := Shape.shape("island_room", "optional", points)
	island["center"] = Vector2(_center(basin, profile), basin).rotated(profile.frame)
	return island
