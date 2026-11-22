extends "res://mob_sim/abilities/ability_handler.gd"
## Root Shepherd: orders visible escorts onto its target, as EnemySupport.resolve_shepherd does.
## Flank order sends the first escort with a clear bend route around the target. Relay order sends
## only that flanking escort. An order makes the escort's rules allow only that target while it lasts.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")

const ORDER_MS := 2600


func plan(port: Port, release: Release) -> bool:
	var radius := _radius(release)
	var origin := port.position(release.slot)
	var escorts: PackedInt32Array = port.fighters(release.slot, origin, radius)
	if escorts.is_empty():
		return false
	release.data.escorts = escorts
	release.data.radius = radius
	if release.legacy in ["flank_command", "relay_order"]:
		var victim := port.player_position(release.player)
		for escort in escorts:
			var via := Geometry.seam(port, port.position(escort), victim, escort)
			if via.is_finite():
				release.data.flank = {"slot": escort, "via": via}
				break
		if release.legacy == "relay_order" and release.data.has("flank"):
			release.data.escorts = PackedInt32Array([int(release.data.flank.slot)])
	return true


func resolve(port: Port, release: Release) -> bool:
	var origin := port.position(release.slot)
	var flank: Dictionary = release.data.get("flank", {})
	for escort in release.data.get("escorts", PackedInt32Array()):
		var at := port.position(escort)
		if not port.alive(escort) or at.distance_to(origin) > float(release.data.radius) or not port.line_clear(origin, at):
			continue
		var via: Vector2 = flank.via if not flank.is_empty() and int(flank.slot) == escort else Vector2.INF
		if via.is_finite() and not port.line_clear(at, via, Geometry.BODY_CLEARANCE):
			via = Vector2.INF
		port.command(escort, release.player, ORDER_MS, via)
	return true


static func _radius(release: Release) -> float:
	return release.areas[0].radius if not release.areas.is_empty() else 4.5
