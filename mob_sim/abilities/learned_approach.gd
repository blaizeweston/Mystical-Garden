extends "res://mob_sim/abilities/ability_handler.gd"
## Learned counter-moves that reshape an approach, as EnemySkillResponses.approach does.
## Antler hook and deep seam bend around the target (the kit's bent lane and range band cover this).
## Side sting leaps to a cut-off point beside the target. Ember fork lands two-thirds of the way and
## scatters embers to both sides of the landing.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")

const EMBER_ALONG := 0.68
const EMBER_SPOTS := [Vector2(-1.55, 0.45), Vector2(1.55, 0.45)]


func plan(port: Port, release: Release) -> bool:
	var origin := port.position(release.slot)
	match release.legacy:
		"antler_hook", "deep_seam":
			return Geometry.seam(port, origin, release.aim, release.slot).is_finite()
		"side_sting":
			var landing := Geometry.cutoff(port, origin, release.aim, release.slot)
			if landing.is_equal_approx(release.aim):
				return false
			release.aim = landing
			release.landing = landing
		"ember_fork":
			if not port.line_clear(origin, release.aim, Geometry.BODY_CLEARANCE):
				return false
			var landing := origin.lerp(release.aim, EMBER_ALONG)
			for offset: Vector2 in EMBER_SPOTS:
				var spot := landing + Geometry.side(origin, release.aim, release.slot) * offset.x + (release.aim - origin).normalized() * offset.y
				if not port.line_clear(origin, spot):
					return false
			release.aim = landing
			release.landing = landing
	return true
