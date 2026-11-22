extends "res://mob_sim/abilities/ability_handler.gd"
## Rites cast through an ally, as the legacy rite anchors are.
## Echo toll (Bellcap): the toll rings around the farthest visible fighter and hastes the two allies
## nearest it. Antiphon (Root Choir): a sector strikes from an ally near the target toward the target.
## If the anchoring ally dies, moves away or drops out of sight before release, nothing happens.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")

const TOLL_RADIUS := 2.35
const TOLL_HASTE_MS := 2200
const TOLL_ALLIES := 2
const ANTIPHON_RADIUS := 3.3
const ANTIPHON_SPAN := 2.05
const MIN_ANCHOR_GAP := 1.0


func plan(port: Port, release: Release) -> bool:
	var origin := port.position(release.slot)
	var allies: PackedInt32Array = port.fighters(release.slot, origin, port.reach(release.slot))
	if release.legacy == "antiphon":
		return _plan_antiphon(port, release, origin, allies)
	for index in range(allies.size() - 1, -1, -1):
		var point := port.position(allies[index])
		if origin.distance_to(point) >= MIN_ANCHOR_GAP:
			_anchor(release, allies[index], point)
			var toll: Array[Release.Area] = [Release.Area.circle(point, TOLL_RADIUS)]
			release.areas = toll
			release.data.locked = true
			return true
	return false


func _plan_antiphon(port: Port, release: Release, origin: Vector2, allies: PackedInt32Array) -> bool:
	var target := release.aim
	for ally in allies:
		var point := port.position(ally)
		var gap := point.distance_to(target)
		if origin.distance_to(point) < MIN_ANCHOR_GAP or gap < 0.4 or gap > ANTIPHON_RADIUS or not port.line_clear(point, target):
			continue
		_anchor(release, ally, point)
		var sweep := Release.Area.new()
		sweep.part = Release.Part.SECTOR
		sweep.from = point
		sweep.facing = (target - point).normalized()
		sweep.radius = ANTIPHON_RADIUS
		sweep.span = ANTIPHON_SPAN
		var sweeps: Array[Release.Area] = [sweep]
		release.areas = sweeps
		release.data.locked = true
		release.data.presentation.role = "enemy_sweep"
		release.data.presentation.span = ANTIPHON_SPAN
		release.data.presentation.radius = ANTIPHON_RADIUS
		return true
	return false


func _anchor(release: Release, ally: int, point: Vector2) -> void:
	release.data.anchor = {"slot": ally, "point": point}
	release.data.presentation = {"rite_anchor": {"point": point}}


func resolve(port: Port, release: Release) -> bool:
	if not Geometry.anchor_intact(port, release):
		return false
	if release.legacy != "echo_toll":
		return true
	var center: Vector2 = release.data.anchor.point
	var nearest: PackedInt32Array = port.fighters(release.slot, center, TOLL_RADIUS)
	for index in mini(TOLL_ALLIES, nearest.size()):
		port.haste(nearest[index], TOLL_HASTE_MS)
	return false
