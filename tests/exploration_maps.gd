extends SceneTree
const Field = preload("res://battlefield.gd")
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok: failed=true;printerr("FAIL exploration maps: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for site in 3:
		var field := Field.new()
		field.configure(site,site+1,91247+site*7919)
		check(field.connected(),"arrival and exit belong to one certified route network")
		for destination: Vector3 in [field.graft,field.advance,field.extraction]+field.spawn_points:
			var origin := Field.planar(field.entry)
			var route := field.navigation_graph.route(origin,Field.planar(destination))
			check(not route.is_empty(),"landmark has an attached route")
			for waypoint: Vector2 in route:
				check(field.navigation_graph.traversable(origin,waypoint),"every routed segment respects modern terrain and actor clearance")
				origin=waypoint
			check(origin.distance_to(Field.planar(destination))<.01,"route terminates at the requested landmark")
	if not failed:print("PASS: three modern biomes with continuous actor-clearance routes to every encounter and travel landmark")
	quit(int(failed))
