extends SceneTree

const Battlefield := preload("res://battlefield.gd")

func _initialize() -> void:
	# Cross an overlapping clearing junction from both sides without detouring
	# through either clearing's center.
	var junction := Battlefield.new()
	junction.procedural = true
	junction.clearings.assign([Vector3(-1.5, 0, 2.0), Vector3(1.5, 0, 2.0)])
	for direction in [-1.0, 1.0]:
		var start := Vector3(-0.8 * direction, 0, 0.9)
		var finish := Vector3(0.8 * direction, 0, 0.9)
		if junction.dash(start, finish).distance_to(finish) > 0.01:
			fail("a visually merged clearing junction blocks a side crossing")
			return
	var wall := Battlefield.new()
	wall.barriers = [Rect2(0, -2, 2, 4)]
	var edge := Vector3(-0.35, 0, 0)
	var along := wall.slide(edge, edge + Vector3(0.1, 0, 0.2))
	if along.z < 0.1 or wall.occupied(along, Battlefield.CLEARANCE):
		fail("movement catches on a wall instead of sliding along it")
		return
	var signatures := {}
	var bent_routes := 0
	for site in 3:
		for sample in 16:
			var seed_value := 91247 + site * 7919 + sample * 37
			var a := Battlefield.new()
			var b := Battlefield.new()
			a.configure(site, sample + 1, seed_value)
			b.configure(site, sample + 1, seed_value)
			if a.clearings != b.clearings or a.links != b.links or a.barriers != b.barriers:
				fail("same seed produced different geometry")
				return
			if a.clearings.size() < a.main_count + 2 or a.links.size() < a.main_count + 2:
				fail("map is missing its flank or side clearing")
				return
			if not a.connected():
				fail("generated exploration destinations are disconnected")
				return
			for target in [a.entry, a.extraction, a.advance, a.graft, a.cache, a.leader]:
				if a.occupied(target, Battlefield.CLEARANCE):
					fail("an exploration destination intersects cover or the forest edge")
					return
			var walkable := 0
			for x in range(-25, 26, 2):
				for z in range(-23, 24, 2):
					walkable += int(a.inside_floor(Vector3(x, 0, z)))
			if walkable < 140 or walkable > 440:
				fail("walkable space lacks clearings and connecting paths")
				return
			if not a.clear_line(a.entry, a.advance, Battlefield.CLEARANCE):
				bent_routes += 1
			if sample < 2:
				var position := a.entry
				for destination in [a.cache, a.graft, a.advance, a.extraction]:
					for step in 900:
						if position.distance_to(destination) < 0.5:
							break
						var next := a.navigate(position, destination, 0.22)
						if not a.clear_line(position, next, Battlefield.CLEARANCE):
							fail("path following crossed a forest boundary")
							return
						position = next
					if position.distance_to(destination) >= 0.5:
						var route := a.navigation.get_point_path(a.free_cell(position), a.free_cell(destination))
						printerr("Route starts ", route.slice(0, mini(5, route.size())))
						if route.size() > 1:
							var next := Vector3(route[1].x, 0, route[1].y)
							printerr("Margin ", a.floor_distance(position), " next ", a.floor_distance(next),
								" lines ", a.clear_line(position, next, 0.0), " / ", a.clear_line(position, next, 0.34), " / ",
								a.clear_line(position, next, 0.44), " occupied ", a.occupied(next, 0.51))
						fail("path following stalled at %s toward %s, site %d seed %d" % [position, destination, site, seed_value])
						return
			signatures[str(a.clearings)] = true
	if signatures.size() != 48 or bent_routes < 32:
		fail("maps do not vary enough or routes are too straight")
		return
	print("PASS: 48 reproducible connected exploration maps")
	quit(0)


func fail(reason: String) -> void:
	printerr("FAIL exploration maps: ", reason)
	quit(1)
