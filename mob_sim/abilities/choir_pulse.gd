extends "res://mob_sim/abilities/ability_handler.gd"
## Root Choir: the pulse needs a visible fighting ally, as EnemySupport.resolve_choir requires.
## Split chorus strikes a sector, then a second beat 730 ms later, turned 2.3 radians.

const SECOND_BEAT_MS := 730
const SECOND_BEAT_TURN := 2.3


func plan(port: Port, release: Release) -> bool:
	var origin := port.position(release.slot)
	return not port.fighters(release.slot, origin, port.reach(release.slot)).is_empty()


func resolve(port: Port, release: Release) -> bool:
	if port.fighters(release.slot, release.origin, port.reach(release.slot)).is_empty():
		return false
	if release.legacy == "split_chorus" and not release.data.get("second_beat", false) and not release.areas.is_empty():
		var beat = release.copy()
		var turned := Release.Area.new()
		var first: Release.Area = release.areas[0]
		turned.part = first.part
		turned.from = first.from
		turned.radius = first.radius
		turned.span = first.span
		turned.facing = first.facing.rotated(SECOND_BEAT_TURN)
		var beats: Array[Release.Area] = [turned]
		beat.areas = beats
		beat.data.second_beat = true
		beat.data.delay_ms = SECOND_BEAT_MS
		release.follow_ups.append(beat)
	return true
