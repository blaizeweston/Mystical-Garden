extends "res://mob_sim/abilities/ability_handler.gd"
## Bellcap's covered bell: once per life, step behind the nearest fighting ally, away from the target,
## before the first chant, as EnemyBehaviors.support_target does.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")

const BEHIND := 1.6


func approach(port: Port, release: Release) -> Vector2:
	var memory := port.memory(release.slot)
	if memory.get("covered_once", false):
		return Vector2.INF
	memory.covered_once = true
	var origin := port.position(release.slot)
	var allies: PackedInt32Array = port.fighters(release.slot, origin, port.reach(release.slot))
	var victim := port.player_position(release.player)
	if allies.is_empty() or not victim.is_finite():
		return Vector2.INF
	var anchor := port.position(allies[0])
	var goal := anchor + (anchor - victim).normalized() * BEHIND
	return goal if port.line_clear(origin, goal, Geometry.BODY_CLEARANCE) else Vector2.INF
