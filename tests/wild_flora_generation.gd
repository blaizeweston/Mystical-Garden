extends SceneTree

const Field = preload("res://battlefield.gd")
const Flora = preload("res://wild_flora_generation.gd")
const Seeds = preload("res://seed_catalog.gd")
const BANDS := [[1, 5], [6, 15], [16, 30], [31, 50], [51, 59], [60, 90]]
var failures := 0

func _initialize() -> void:
	var field := Field.new()
	check(field.generate_flora(1, 0).is_empty(), "unconfigured practice floor")
	field.configure(0, 6, 241, 20)
	check(field.generate_flora(1, 0).is_empty() and not field.generate_returning_root(61,true,[],Vector3.INF).is_finite(), "authored boss lair")
	field.configure(1, 1, 0)
	check(field.generate_flora(1, 0).is_empty(), "configured practice floor")
	verify_species()
	verify_introductory_placement()
	# Standard suite stays small. The same fixture can sample more independent maps.
	var per_band_and_biome := maxi(2, OS.get_environment("MYSTICAL_FLORA_SAMPLE_SIZE").to_int())
	sample_terrain(per_band_and_biome)
	if failures == 0:
		print("PASS: deterministic wild flora, species pools, reachability, spacing and independent cache")
	quit(int(failures > 0))

func verify_species() -> void:
	# Authoritative probabilities at both ends of each band.
	var expected := [[100,0,0,0,0],[65,35,0,0,0],[45,35,20,0,0],
		[25,30,35,10,0],[15,25,35,20,5],[10,20,35,25,10]]
	for band in BANDS.size():
		for depth: int in BANDS[band]:
			check(Flora.weights_at_depth(depth) == PackedFloat32Array(expected[band]), "weights at encounter %d" % depth)
	var random := RandomNumberGenerator.new()
	random.seed = 933561
	for depth in range(1, 62):
		var eligible := {}
		for species in Seeds.DEFINITIONS.size():
			if Seeds.DEFINITIONS[species].wild_min <= depth:
				eligible[species] = true
		var seen := {}
		for attempt in 1500:
			var selected := Flora.roll_species(depth, attempt % 3, random)
			seen[selected] = true
		check(seen.size() == eligible.size(), "all eligible plants represented at encounter %d" % depth)
		for species: int in seen:
			check(eligible.has(species), "no early species %d at encounter %d" % [species, depth])
	# At depth one there are exactly two species. Preferred weights are 1.5:1.
	for biome in 3:
		var thorn := 0
		for attempt in 5000:
			thorn += int(Flora.roll_species(1, biome, random) == 0)
		check(absf(thorn / 5000.0 - [0.6, 0.4, 0.5][biome]) < 0.03, "within-tier biome weighting %d" % biome)

func verify_introductory_placement() -> void:
	for depth in [1, 2]:
		var crowded := Field.new()
		crowded.configure(1, depth, 161231)
		var specimen := crowded.generate_flora(depth, depth - 1)
		check(not specimen.is_empty() and specimen.species == depth - 1 and specimen.position.distance_to(crowded.cache) >= 3.25
			and specimen.position.distance_to(crowded.graft) >= 3.25
			and not crowded.navigation_graph.route(Field.planar(crowded.entry), Field.planar(specimen.position)).is_empty(),
			"crowded Mire starter finds reachable dry ground beyond standard shoulders")
	for biome in 3:
		for depth in [1, 2]:
			var field := Field.new()
			field.configure(biome, depth, 91301383 + biome)
			var specimen := field.generate_flora(depth, depth - 1)
			check(specimen.get("species", -1) == depth - 1, "forced starter regardless of biome and ordinary chance")
			if specimen.is_empty():
				continue
			var reserved: Array = [specimen.position]
			var alternate := field.generate_flora(depth, depth - 1, reserved)
			check(not alternate.is_empty() and alternate.position.distance_to(specimen.position) >= 2.0, "respects actual enemy positions")
			check(field.generate_flora(depth, depth - 1) == specimen, "placement does not depend on earlier queries")

func sample_terrain(per_band_and_biome: int) -> void:
	var results := []
	var roots := {"floors":0,"base_roll":0,"base_placed":0,"improved_roll":0,"improved_placed":0,"base_with_plant":0,"improved_with_plant":0}
	var bonus_seeds := 0
	var bonus_parts := 0
	for i in 10000:
		var identity := "floor-%d" % (i / 4)
		var actor := "participant-%d" % (i % 4)
		bonus_seeds += int(preload("res://wild_flora.gd").bonus_roll(identity,actor,"seed") < 0.25)
		bonus_parts += int(preload("res://wild_flora.gd").bonus_roll(identity,actor,"refined") < 0.15)
	print("GATHERING_SAMPLE claims=10000 extra_seeds=",bonus_seeds," refined_parts=",bonus_parts)
	var species_totals := Seeds.counts()
	for band in BANDS.size():
		var low: int = BANDS[band][0]
		var high: int = BANDS[band][1]
		var summary := {"depths": BANDS[band], "floors": 0, "rolled": 0, "placed": 0,
			"by_biome": [0, 0, 0], "by_rarity": [0, 0, 0, 0, 0]}
		for biome in 3:
			var field := Field.new()
			for sample in per_band_and_biome:
				var map_seed := 46337 + 1013 * sample + 709 * biome + 100003 * band
				var depth := low + sample % (high - low + 1)
				field.configure(biome, 1 + sample % 6, map_seed)
				var flora_random := Flora.floor_random(field.configured_key, depth)
				var rolled := flora_random.randf() < Flora.SPAWN_CHANCE
				var before := [field.has_seed_cache(), field.cache, field.spawn_points.duplicate(), field.entry, field.advance]
				var specimen := field.generate_flora(depth)
				var origin: Vector3 = specimen.get("position",Vector3.INF)
				var draw := field.root_random(field.configured_key,depth).randf()
				var base := field.generate_returning_root(depth,false,[],origin)
				var improved := field.generate_returning_root(depth,true,[],origin)
				roots.floors += 1
				roots.base_roll += int(draw < 0.25)
				roots.improved_roll += int(draw < 0.40)
				roots.base_placed += int(base.is_finite())
				roots.improved_placed += int(improved.is_finite())
				roots.base_with_plant += int(base.is_finite() and origin.is_finite())
				roots.improved_with_plant += int(improved.is_finite() and origin.is_finite())
				check(not base.is_finite() or (base==improved and draw<0.25),"upgrade preserves existing root sites")
				check(improved==field.generate_returning_root(depth,true,[],origin),"repeatable root placement")
				if improved.is_finite():
					check(draw<0.40 and not field.navigation_graph.route(Field.planar(field.entry),Field.planar(improved)).is_empty(),"reachable Returning Root")
					check(not origin.is_finite() or improved.distance_to(origin)>3.15,"flora and root interactions do not overlap")
				check(specimen == field.generate_flora(depth), "same floor identity repeats")
				check(before == [field.has_seed_cache(), field.cache, field.spawn_points, field.entry, field.advance], "no terrain/spawn/cache mutation")
				summary.floors += 1
				summary.rolled += int(rolled)
				if specimen.is_empty():
					continue
				var position: Vector3 = specimen.position
				var species: int = specimen.species
				var planar := Field.planar(position)
				check(rolled and Seeds.DEFINITIONS[species].wild_min <= depth, "placement only from eligible roll")
				check(not field.ground.Shape.in_any(field.ground.water, planar, Field.Navigation.RADIUS)
					and field.ground.walkable(planar, Field.Navigation.RADIUS), "dry walkable specimen")
				check(not field.navigation_graph.route(Field.planar(field.entry), planar).is_empty(), "entrance can reach plant")
				check(position.distance_to(field.entry) >= 5.0 and position.distance_to(field.advance) >= 5.0
					and position.distance_to(field.graft) >= 3.25
					and (not field.has_seed_cache() or position.distance_to(field.cache) >= 3.25), "gate, graft and cache interaction disks stay disjoint")
				for spawn: Vector3 in field.spawn_points:
					check(position.distance_to(spawn) >= 2.0, "enemy spawn clearance")
				species_totals[species] += 1
				summary.placed += 1
				summary.by_biome[biome] += 1
				summary.by_rarity[Flora.RARITIES.find(Seeds.DEFINITIONS[species].rarity)] += 1
		results.append(summary)
	var species_counts := {}
	for i in species_totals.size():
		species_counts[Seeds.DEFINITIONS[i].id] = species_totals[i]
	print("ROOT_SAMPLE ",JSON.stringify(roots))
	print("FLORA_SAMPLE ", JSON.stringify({"bands": results, "species": species_counts}))

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", description)
