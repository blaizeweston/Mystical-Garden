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
const PREY_DESCRIPTION := "Fire through up to three enemies. The first eligible survivor becomes Tracked Prey for 2.7 s. The next direct basic-attack hit or immediate class-ability hit by you or an ally deals +10 damage. Salvo itself and delayed effects do not consume it."
const ROWS := [
	[["wildstalker", "Wildstalker", "Learn Hunter’s Salvo."],
	 ["snarekeeper", "Snarekeeper", "Learn Luring Snare."],
	 ["wayfarer", "Wayfarer", "Learn Briar Retreat."]],
	[["wider_pattern", "Wider Pattern", "{focus} gains 0.24 m of line width for Hunter’s Salvo or 0.55 m of area radius for the other focuses. Hunter’s Salvo can still hit up to three enemies."],
	 ["long_draw", "Long Draw", "Increases {focus}'s reach, placement range, or maximum legal retreat distance by 1.25 m."],
	 ["trail_ward", "Trail Ward", "After casting {focus}, grant one 1.4 s Ward to the living ally with the lowest HP ratio within support range and in clear line of your final position. You can qualify."]],
	[["splinter_ambush", "Splinter Ambush", "{focus} deals +10 damage to the first enemy hit by Hunter’s Salvo or caught by your starting ability's trap, once per cast."],
	 ["briar_tread", "Briar Tread", "Extends the duration of {focus}'s roots by 0.65 s. Hunter’s Salvo instead roots surviving enemies it hits for 0.65 s."],
	 ["clear_trail", "Clear Trail", "After casting {focus}, remove ordinary Slow from living allies within support range and in clear line of your final position."]],
	[["barbed_snare", "Barbed Snare", "After {focus}, the first enemy caught by your next successfully placed Bramble Snare takes +10 damage."],
	 ["quick_reset", "Quick Reset", "After {focus}, the next successful Bramble Snare placement starts a cooldown 1.7 s shorter, with a 1.8 s minimum."],
	 ["safe_passage", "Safe Passage", "After {focus}, your next successfully placed Bramble Snare grants living allies within 3 m of the trap and in clear line one 1.4 s Ward."]],
	[["follow_through", "Follow-Through", "For 5 s after {focus} damages or traps an enemy, your next basic attack gains +10 damage on its first direct hit. Firing spends the bonus even if you miss."],
	 ["snarecraft", "Snarecraft", "Increases Bramble Snare's radius by 0.4 m and extends its duration by 1 s."],
	 ["fleetfoot", "Fleetfoot", "A successful cast of {focus} grants you +15% movement speed for 2 s. The strongest active speed bonus applies."]],
	[["double_draw", "Double Draw", "For 6 s after {focus} damages or traps an enemy, your next basic attack fires one extra projectile. Its first target takes 50% of the weapon damage roll. The extra shot cannot pierce, chain or trigger further effects."],
	 ["bramble_corridor", "Bramble Corridor", "Bramble Snare also traps along supported ground toward the trap, 0.75 m to either side of the path. It shares the trap's damage, roots and duration. Each enemy can be caught once across both areas."],
	 ["escape_route", "Escape Route", "Bramble Snare leaves a visible route along traversable ground for 3 s. Each living ally inside gains 20% movement speed for 2 s once per cast. Only the strongest active speed bonus applies."]],
]
const VERSION_DATA := [Model.VERSION, Model.XP_THRESHOLDS, ROWS, PREY_DESCRIPTION, PREY_MS, PREY_HP,
	AMBUSH_HP, BARBED_HP, RESET_MS, PASSAGE_RADIUS, FOLLOW_HP, FOLLOW_MS, CRAFT_RADIUS, CRAFT_MS,
	FLEETFOOT_SPEED, SPEED_MS, DOUBLE_MS, DOUBLE_SCALE, ROUTE_WIDTH, ESCAPE_MS, ESCAPE_SPEED]

static var TREE := Model.new(2, "ranger", "Ranger", PROFILE_KEY, ROWS)


static func description(node: Dictionary, focus: String, ability: String) -> String:
	if not focus.is_empty():
		var salvo := focus == "wildstalker"
		match node.id:
			"wider_pattern":
				return "Widens Hunter’s Salvo by 0.24 m. It still hits up to three enemies." if salvo else "Increases %s's area radius by 0.55 m." % ability
			"long_draw":
				var distance := {"wildstalker":"reach", "snarekeeper":"trap placement range", "wayfarer":"maximum legal retreat distance"}
				return "Increases %s's %s by 1.25 m." % [ability, distance[focus]]
			"splinter_ambush":
				return "Hunter’s Salvo deals +10 damage to its first damaged enemy, once per cast." if salvo else "The first enemy caught by %s's trap takes +10 damage, once per cast." % ability
			"briar_tread":
				return "Hunter’s Salvo roots surviving enemies it hits for 0.65 s." if salvo else "Extends the duration of roots from %s's trap by 0.65 s." % ability
	return Model.focus_text(node.description, ability)
