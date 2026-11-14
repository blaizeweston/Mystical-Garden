extends RefCounted
## Upload the logical axial labels as a compact, unfiltered lookup texture.

const Catalog = preload("res://assets/terrain_m02/terrain_catalog.gd")
const NO_CELL := 255

static func bake(cells: Dictionary) -> Dictionary:
	assert(not cells.is_empty())
	var first: Vector2i = cells.keys()[0]
	var origin := first
	var end := first
	for cell: Vector2i in cells:
		origin = origin.min(cell)
		end = end.max(cell)
	var size := end - origin + Vector2i.ONE
	var labels := PackedByteArray()
	labels.resize(size.x * size.y)
	labels.fill(NO_CELL)
	for cell: Vector2i in cells:
		var offset := cell - origin
		var label := Catalog.IDS.find(cells[cell])
		assert(label != -1)
		labels[offset.y * size.x + offset.x] = label
	return {"origin": origin, "size": size, "labels": labels}

static func material(field: Dictionary, spacing: float, seed_value: int, catalog: Catalog) -> ShaderMaterial:
	var image := Image.create_from_data(field.size.x, field.size.y, false, Image.FORMAT_R8, field.labels)
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://assets/terrain_m02/terrain_natural.gdshader")
	ground.set_shader_parameter("cell_labels", ImageTexture.create_from_image(image))
	ground.set_shader_parameter("label_origin", field.origin)
	ground.set_shader_parameter("center_spacing", spacing)
	# The integer seed offsets cosmetic detail, independently of the generator.
	ground.set_shader_parameter("seed_offset", Vector2(seed_value & 1023, (seed_value >> 10) & 1023) * 0.618)
	ground.set_shader_parameter("leafy_ground", preload("res://assets/garden/field/leafy_grass.jpg"))
	ground.set_shader_parameter("forest_ground", preload("res://assets/garden/field/forest_soil.jpg"))
	for id in Catalog.IDS:
		var terrain := catalog.definition(id)
		ground.set_shader_parameter(str(id) + "_color", terrain.color)
		ground.set_shader_parameter(str(id) + "_shade", terrain.shade)
	return ground
