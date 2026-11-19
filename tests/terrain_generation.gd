extends SceneTree
const Field = preload("res://battlefield.gd")
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok: failed=true;printerr("FAIL terrain generation: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var signatures := {}
	var began := Time.get_ticks_msec()
	for index in 6:
		var field := Field.new()
		field.configure(index%3,index+1,91247+index)
		check(field.connected(),"destinations have certified routes on the finished modern surface")
		check(field.entry.distance_to(field.advance)>=12,"entry/exit remain well separated")
		check(field.generated.layout.get("layout_kind", "generated") != "practice","a seeded expedition cannot use the practice floor")
		for point in [field.entry,field.extraction,field.advance,field.leader,field.graft]+field.spawn_points:
			check(not field.occupied(point,Field.CLEARANCE),"landmarks have clearance in finished terrain")
		var peer := Field.new()
		peer.configure(index%3,index+1,91247+index)
		check(peer.generated==field.generated and peer.entry==field.entry and peer.advance==field.advance,
			"same seed reproduces geometry, cover roles and gates")
		signatures[var_to_bytes(field.generated).hex_encode().sha256_text()]=true
	check(signatures.size()==6,"distinct seeds produce distinct floors")
	print("Terrain generation milliseconds: ",Time.get_ticks_msec()-began)
	if not failed:print("PASS: six deterministic modern biome floors, certified landmarks, supported spawn points and shared geometry")
	quit(int(failed))
