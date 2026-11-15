extends RefCounted

# Provisional CR03 tuning. Movement values are fractions and damage is HP
# before the target's existing mitigation.
const STACKS_TO_RUPTURE := 3
const BRITTLE_MS := 3600
const ROOT_MS := 650
const BOSS_SLOW_SCALE := .5
const BLOOM_RADIUS := 2.25
const BLOOM_OPEN_HP := 9
const BLOOM_DELAY_MS := 625
const BLOOM_COOLDOWN_MS := 8000
const WARD_RADIUS := 2.4
const RESPONSE_MS := 4500
const QUALITY := {
	"ordinary": {"move_slow": .08, "rupture_hp": 4},
	"refined": {"move_slow": .13, "rupture_hp": 7},
}
const VERSION_DATA := [STACKS_TO_RUPTURE, BRITTLE_MS, ROOT_MS, BOSS_SLOW_SCALE,
	BLOOM_RADIUS, BLOOM_OPEN_HP, BLOOM_DELAY_MS, BLOOM_COOLDOWN_MS, WARD_RADIUS, RESPONSE_MS, QUALITY]


static func description(slot: String, quality: String) -> String:
	var line: String = {
		"core": "Rime Bloom · Opening petals deal %d HP and apply two stacks. Closing petals apply one stack after %.3f s within %.2f m. %.1f s cooldown." % [BLOOM_OPEN_HP, BLOOM_DELAY_MS / 1000.0, BLOOM_RADIUS, BLOOM_COOLDOWN_MS / 1000.0],
		"form": "Brittle Strikes · One stack per enemy per direct weapon attack.",
		"catalyst": "Frost Catalyst · One stack per mapped offensive contact or actual block burst (%.1f m). Healing and movement can grant a %.1f s single-use response to an unblocked enemy hit you survive." % [WARD_RADIUS, RESPONSE_MS / 1000.0],
	}[slot]
	var potency: Dictionary = QUALITY[quality]
	return line + "\nEach stack slows movement by %d%% and contributes %d HP to a three-stack rupture. Stacks expire after %.1f s. Rupture roots lesser enemies for %.2f s. Bosses take half the slow and resist roots." % [
		roundi(100 * potency.move_slow), potency.rupture_hp, BRITTLE_MS / 1000.0, ROOT_MS / 1000.0,
	]
