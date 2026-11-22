extends "res://mob_sim/abilities/ability_handler.gd"
## Aim changes made at the wind-up:
## cutoff_aim (Ashen Hart's cutoff charge) aims beside the target to cut off its escape;
## denied_aim (Nightbloom's echo bud) aims where its last volley was stopped;
## side_anchor (Lantern Lure) pulls from a lantern set beside it, or partway toward the target for
## the low lantern, when both lines are clear.

const Geometry = preload("res://mob_sim/abilities/handler_geometry.gd")

const SIDE_LANTERN := 1.7
const LOW_LANTERN_ALONG := 0.35
const LOW_LANTERN_SIDE := 1.65


func plan(port: Port, release: Release) -> bool:
	var origin := port.position(release.slot)
	match release.ability:
		"ashen_hart_cutoff_charge":
			var aim := Geometry.cutoff(port, origin, release.aim, release.slot)
			release.aim = aim
			release.landing = aim
		"nightbloom_echo_bud":
			var denied := port.denied_aim(release.slot)
			if denied.is_finite():
				release.aim = denied
		"lantern_lure_side_lantern", "lantern_lure_low_lantern":
			var low: bool = release.ability == "lantern_lure_low_lantern"
			var base := origin.lerp(release.aim, LOW_LANTERN_ALONG) if low else origin
			var anchor := base + Geometry.side(origin, release.aim, release.slot) * (LOW_LANTERN_SIDE if low else SIDE_LANTERN)
			if port.line_clear(origin, anchor, 0.5) and port.line_clear(anchor, release.aim):
				release.data.lantern = anchor
				release.data.presentation = {"anchor": anchor}
	return true


func resolve(_port: Port, release: Release) -> bool:
	# The pull area is rebuilt after plan(), so the lantern anchor is applied here, just before the hits.
	if release.data.has("lantern"):
		for area in release.areas:
			if area.part == Release.Part.PULL:
				area.anchor = release.data.lantern
	return true
