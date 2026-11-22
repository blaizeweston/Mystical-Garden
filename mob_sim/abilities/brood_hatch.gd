extends "res://mob_sim/abilities/ability_handler.gd"
## Broodmother: hatches juveniles at safe sites around itself, as EnemySupport.brood_sites and
## resolve_brood do. Scattered hatch splits two juveniles to opposite sides and skips any site a player
## stands near at release. A Broodmother keeps at most two hatchlings out.

const LIMIT := 2
const SITES := [Vector2(1.9, 0.8), Vector2(-1.9, 0.8), Vector2(0.0, -2.3), Vector2(0.0, 2.3)]
const SCATTER_AXES := [Vector2(1, 0), Vector2(0, 1), Vector2(0.70710678, 0.70710678), Vector2(0.70710678, -0.70710678)]
const SCATTER_DISTANCE := 3.35
const PLAYER_CLEARANCE := 1.5


func plan(port: Port, release: Release) -> bool:
	var memory := port.memory(release.slot)
	var room := LIMIT - int(memory.get("summons", 0))
	if room <= 0:
		return false
	var origin := port.position(release.slot)
	var sites := PackedVector2Array()
	if release.legacy == "scattered_hatch":
		for axis: Vector2 in SCATTER_AXES:
			var first := origin + axis * SCATTER_DISTANCE
			var second := origin - axis * SCATTER_DISTANCE
			if _open(port, origin, first) and _open(port, origin, second):
				sites = PackedVector2Array([first, second])
				break
	else:
		var wanted := mini(room, 2 if release.legacy == "split_nursery" else 1)
		for offset: Vector2 in SITES:
			if _open(port, origin, origin + offset):
				sites.append(origin + offset)
				if sites.size() >= wanted:
					break
	if sites.is_empty():
		return false
	release.data.sites = sites
	release.data.presentation = {"hatch": sites}
	return true


func resolve(port: Port, release: Release) -> bool:
	var memory := port.memory(release.slot)
	for site in release.data.get("sites", PackedVector2Array()):
		if int(memory.get("summons", 0)) >= LIMIT:
			break
		if release.legacy == "scattered_hatch" and _player_near(port, site):
			continue
		if port.hatch_safe(site) and port.hatch(release.slot, site):
			memory.summons = int(memory.get("summons", 0)) + 1
	return false


func _open(port: Port, origin: Vector2, site: Vector2) -> bool:
	return port.line_clear(origin, site, 0.45) and port.hatch_safe(site)


func _player_near(port: Port, site: Vector2) -> bool:
	for player in 4:
		var at := port.player_position(player)
		if at.is_finite() and at.distance_to(site) < PLAYER_CLEARANCE:
			return true
	return false
