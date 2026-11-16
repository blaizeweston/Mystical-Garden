extends RefCounted
## Stable Ranger choices separate from historical class masks.
const Model = preload("res://connected_class_tree.gd")
const PROFILE_KEY := "ranger_connected"
const PREY_MS := 2700
const PREY_HP := 10
const AMBUSH_HP := 10
const BARBED_HP := 10
const RESET_MS := 1700
const PASSAGE_RADIUS := 3.0
const FOLLOW_HP := 10
const FOLLOW_MS := 5000
const CRAFT_RADIUS := 0.4
const CRAFT_MS := 1000
const FLEETFOOT_SPEED := 0.15
const SPEED_MS := 2000
const DOUBLE_MS := 6000
const DOUBLE_SCALE := 0.5
const ROUTE_WIDTH := 0.75
const ESCAPE_MS := 3000
const ESCAPE_SPEED := 0.20
const PREY_DESCRIPTION := "Fire through up to three enemies. The first eligible survivor becomes Tracked Prey for 2.7 s. The next direct weapon or immediate class hit by you or an ally gains 10 base HP. Salvo itself and delayed effects do not consume it."
const ROWS := [
	[["wildstalker", "Wildstalker", "Learn Hunter’s Salvo."],
	 ["snarekeeper", "Snarekeeper", "Learn Luring Snare."],
	 ["wayfarer", "Wayfarer", "Learn Briar Retreat."]],
	[["wider_pattern", "Wider Pattern", "Q gains 0.24 m of line width or 0.55 m of area radius. Salvo still hits up to three enemies."],
	 ["long_draw", "Long Draw", "Q gains 1.25 m of reach, placement range, or legal retreat distance."],
	 ["trail_ward", "Trail Ward", "After a successful Q, grant one 1.4 s Ward to the living ally with the lowest HP ratio within Q’s support radius of your final position and in clear line. You can qualify."]],
	[["splinter_ambush", "Splinter Ambush", "The first enemy damaged by Salvo or caught in your Q trap takes 10 extra base HP, once per Q."],
	 ["briar_tread", "Briar Tread", "Q roots last 0.65 s longer. Salvo roots surviving enemies it hits for 0.65 s."],
	 ["clear_trail", "Clear Trail", "After a successful Q, clear ordinary Slow from living allies in clear line within Q’s support radius of your final position."]],
	[["barbed_snare", "Barbed Snare", "Q prepares your next successfully placed Bramble Snare. Its first enemy caught takes 10 extra base HP."],
	 ["quick_reset", "Quick Reset", "Q prepares your next successfully placed Bramble Snare to recover 1.7 s sooner, down to a 1.8 s cooldown."],
	 ["safe_passage", "Safe Passage", "After Q, your next successfully placed Bramble Snare grants living allies within 3 m of the trap and in clear line one 1.4 s Ward."]],
	[["follow_through", "Follow-Through", "For 5 s after Q damages or traps an enemy, your next ordinary shot gains 10 base HP on its first direct hit. Launching spends the bonus, even on a miss."],
	 ["snarecraft", "Snarecraft", "Bramble Snare gains 0.4 m of radius and lasts 1 s longer."],
	 ["fleetfoot", "Fleetfoot", "A successful Q grants you 15% movement speed for 2 s. Only the strongest active speed bonus applies."]],
	[["double_draw", "Double Draw", "For 6 s after Q damages or traps an enemy, your next ordinary shot fires a second projectile. It deals half the weapon’s original damage roll to its first target, with no pierce, chain, or procs."],
	 ["bramble_corridor", "Bramble Corridor", "Bramble Snare also traps along a supported corridor with a 0.75 m half-width. It deals native Snare damage and roots. An enemy can be caught once across both areas."],
	 ["escape_route", "Escape Route", "Bramble Snare leaves a visible route along traversable ground for 3 s. Each living ally inside gains 20% movement speed for 2 s once per cast. Only the strongest active speed bonus applies."]],
]
const VERSION_DATA := [Model.VERSION, Model.XP_THRESHOLDS, ROWS, PREY_DESCRIPTION, PREY_MS, PREY_HP,
	AMBUSH_HP, BARBED_HP, RESET_MS, PASSAGE_RADIUS, FOLLOW_HP, FOLLOW_MS, CRAFT_RADIUS, CRAFT_MS,
	FLEETFOOT_SPEED, SPEED_MS, DOUBLE_MS, DOUBLE_SCALE, ROUTE_WIDTH, ESCAPE_MS, ESCAPE_SPEED]

static var TREE := Model.new(2, "ranger", "Ranger", PROFILE_KEY, ROWS)
