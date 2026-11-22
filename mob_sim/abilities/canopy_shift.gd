extends "res://mob_sim/abilities/ability_handler.gd"
## Hollowback's canopy shift: after a player slips out of its shelter, it moves to cover that ally
## again, as EnemySkillResponses.plan_canopy and resolve_canopy do. The leap carries it to the goal.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")

const MAX_STEP := 2.7
const KEEP_GAP := 1.1
const MIN_STEP := 0.9
## The mob must still be near where it planned the shift, as EnemySkillResponses.move_still_valid checks.
const STILL_THERE := 0.65


func plan(port: Port, release: Release) -> bool:
	var ally := port.shelter_escort(release.slot)
	if ally < 0 or not port.alive(ally):
		return false
	var origin := port.position(release.slot)
	var at := port.position(ally)
	var radius := port.shelter_radius()
	if origin.distance_to(at) <= radius and port.line_clear(origin, at):
		return false
	var goal := origin.move_toward(at, minf(MAX_STEP, origin.distance_to(at) - KEEP_GAP))
	if origin.distance_to(goal) < MIN_STEP or goal.distance_to(at) > radius:
		return false
	if not port.line_clear(origin, goal, Geometry.BODY_CLEARANCE) or not port.line_clear(goal, at):
		return false
	release.data.ally = ally
	release.aim = goal
	release.landing = goal
	release.data.presentation = {"role": "canopy", "to": goal}
	return true


func resolve(port: Port, release: Release) -> bool:
	var ally := int(release.data.get("ally", -1))
	return ally >= 0 and port.alive(ally)
