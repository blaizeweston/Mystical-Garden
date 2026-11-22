extends "res://mob_sim/abilities/ability_handler.gd"
## Pallbearer: tethers a fallen ally's corpse and heals from it, as EnemySupport.tether_target and
## resolve_corpse do. Long tether reaches farther. Spare tether skips the corpse a player last
## disrupted. Without a corpse in reach the rite is not cast. The kit's haste applies only on success.

const REACH := 5.0
const LONG_REACH := 7.0
## The tether breaks when the corpse is farther than this at release.
const HOLD_REACH := 7.0


func plan(port: Port, release: Release) -> bool:
	var exclude := -1
	var radius := REACH
	if release.legacy == "spare_tether":
		exclude = int(port.memory(release.slot).get("disrupted_corpse", -1))
		radius = LONG_REACH
	var found: Array = port.corpses(release.slot, radius, exclude)
	if found.is_empty() and release.legacy == "long_tether":
		found = port.corpses(release.slot, LONG_REACH, exclude)
	if found.is_empty():
		return false
	release.data.corpse = found[0]
	release.aim = found[0].point
	release.data.presentation = {"role": "corpse_tether", "to": found[0].point}
	return true


func resolve(port: Port, release: Release) -> bool:
	var corpse: Dictionary = release.data.get("corpse", {})
	var origin := port.position(release.slot)
	if corpse.is_empty() or not port.corpse_still_there(int(corpse.id), corpse.point) \
			or origin.distance_to(corpse.point) > HOLD_REACH or not port.line_clear(origin, corpse.point):
		return false
	port.consume_corpse(release.slot, int(corpse.id))
	port.heal_from_corpse(release.slot, release.legacy == "spare_tether")
	return true
