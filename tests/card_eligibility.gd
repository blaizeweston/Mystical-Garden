extends SceneTree
## CE01: real-content migration equivalence and the small predicate vocabulary.
## Future requirements use fixture dictionaries only; no new offer definitions.
const Eligibility = preload("res://card_eligibility.gd")
const Requires = preload("res://card_requirements.gd")
const Catalog = preload("res://affinity_card_catalog.gd")
const Ledger = preload("res://affinity_card_ledger.gd").Ledger
const Build = preload("res://affinity_build.gd")
const Resolved = preload("res://resolved_combat_build.gd")
const Classes = preload("res://class_catalog.gd")
const Profile = preload("res://character_profile.gd")
const Preview = preload("res://combat_balance_preview.gd")
const Grafts = preload("res://expedition_grafts.gd")
const Wallet = preload("res://expedition_wallet.gd")
const Cores := {"frost":"rime_opening", "fire":"ember_impact", "water":"dewfall_impact", "vital":"vital_bloom_time",
	"thorn":"thorn_line_bleed", "wood":"ironbark_time", "storm":"chain_spark_power", "spirit":"phantom_stride_time", "void":"gravity_collapse"}
const Forms := {"fire":"burning_strikes_heat", "wood":"splinter_sharpness", "storm":"arc_recharge", "void":"drawing_pressure"}
const Catalysts := {"fire":"catalyst_ember_heat", "water":"catalyst_drench_time", "vital":"catalyst_vital_regen", "wood":"catalyst_bark_time"}
const Native := ["quake_impact", "nova_impact", "snare_root_time", "siphon_impact", "chime_ward_time"]
const General := ["ordinary_weapon_damage", "ordinary_weapon_interval", "run_health", "run_dodge_recovery"]
const BASELINE_VALUES := {
	"rime_opening": {"title": "Sharpened Petals", "scope": "core", "policy": "stackable", "parameter": "opening_bonus_hp", "values": [2, 3, 4, 5], "limit": 4},
	"ember_impact": {"title": "Emberfront", "scope": "core", "policy": "stackable", "parameter": "impact_hp", "values": [2, 3, 4, 5], "limit": 4},
	"dewfall_impact": {"title": "Driving Rain", "scope": "core", "policy": "stackable", "parameter": "impact_hp", "values": [2, 3, 4, 5], "limit": 4},
	"vital_bloom_time": {"title": "Lingering Blossom", "scope": "core", "policy": "stackable", "parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "limit": 4},
	"thorn_line_bleed": {"title": "Sawtooth Briars", "scope": "core", "policy": "stackable", "parameter": "tick_hp", "values": [1, 2, 3, 4], "limit": 4},
	"ironbark_time": {"title": "Seasoned Ironbark", "scope": "core", "policy": "stackable", "parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "limit": 4},
	"chain_spark_power": {"title": "Gathered Thunder", "scope": "core", "policy": "stackable", "parameter": "initial", "values": [2, 3, 4, 5], "limit": 4},
	"phantom_stride_time": {"title": "Lingering Footfall", "scope": "core", "policy": "stackable", "parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "limit": 4},
	"gravity_collapse": {"title": "Crushing Center", "scope": "core", "policy": "stackable", "parameter": "collapse", "values": [2, 3, 4, 5], "limit": 4},
	"burning_strikes_heat": {"title": "Hotter Embers", "scope": "form", "policy": "stackable", "parameter": "stack_bonus", "values": [1, 2, 3, 4], "limit": 4},
	"splinter_sharpness": {"title": "Jagged Splinters", "scope": "form", "policy": "stackable", "parameter": "fragment_hp", "values": [1, 2, 3, 4], "limit": 4},
	"arc_recharge": {"title": "Quick Conduction", "scope": "form", "policy": "stackable", "parameter": "interval_reduction_ms", "values": [80, 120, 160, 200], "limit": 4},
	"drawing_pressure": {"title": "Heavy Compression", "scope": "form", "policy": "stackable", "parameter": "form_hp", "values": [2, 3, 4, 5], "limit": 4},
	"catalyst_ember_heat": {"title": "Heart of Cinders", "scope": "catalyst", "policy": "stackable", "parameter": "stack_bonus", "values": [1, 2, 3, 4], "limit": 4},
	"catalyst_drench_time": {"title": "Clinging Dew", "scope": "catalyst", "policy": "stackable", "parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "limit": 4},
	"catalyst_vital_regen": {"title": "Greening Chime", "scope": "catalyst", "policy": "stackable", "parameter": "regen_per_second", "values": [1, 2, 3, 4], "limit": 4},
	"catalyst_bark_time": {"title": "Enduring Bark", "scope": "catalyst", "policy": "stackable", "parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "limit": 4},
	"quake_impact": {"title": "Deep Fault", "scope": "class", "policy": "stackable", "parameter": "damage", "values": [2, 3, 4, 5], "limit": 4},
	"nova_impact": {"title": "Heavy Spores", "scope": "class", "policy": "stackable", "parameter": "damage", "values": [2, 3, 4, 5], "limit": 4},
	"snare_root_time": {"title": "Clinging Brambles", "scope": "class", "policy": "stackable", "parameter": "bind", "values": [150, 250, 350, 450], "limit": 4},
	"siphon_impact": {"title": "Harvest Edge", "scope": "class", "policy": "stackable", "parameter": "damage", "values": [2, 3, 4, 5], "limit": 4},
	"chime_ward_time": {"title": "Lasting Resonance", "scope": "class", "policy": "stackable", "parameter": "ward_ms", "values": [100, 200, 300, 400], "limit": 4},
	"ordinary_weapon_damage": {"title": "Honed Strikes", "scope": "weapon", "policy": "stackable", "parameter": "strike_damage", "values": [1, 2, 3, 4], "limit": 4},
	"ordinary_weapon_interval": {"title": "Light Grip", "scope": "weapon", "policy": "stackable", "parameter": "strike_interval", "values": [20, 35, 50, 65], "limit": 4},
	"run_health": {"title": "Hardy Frame", "scope": "general", "policy": "stackable", "parameter": "max_hp", "values": [3, 5, 7, 9], "limit": 4},
	"run_dodge_recovery": {"title": "Quick Footing", "scope": "general", "policy": "stackable", "parameter": "dodge_interval", "values": [45, 70, 95, 120], "limit": 4},
	"dew_shelter": {"title": "Dew Shelter", "scope": "core", "policy": "unique", "parameter": "shelter_ward_ms", "fixed": 1200, "limit": 1},
	"echoing_growth": {"title": "Echoing Growth", "scope": "class", "policy": "unique", "parameter": "bloom_echo_hp", "fixed": 10, "limit": 1},
}

var failed := false
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed = true; printerr("FAIL CE01: ", message)

func part(family: String) -> int:
	for index in range(1, Build.Materials.DEFINITIONS.size()):
		if Build.Affinities.for_part(index).get("primary_affinity") == family: return index
	return 0

func build(class_id := 0, focus_index := 0, slots: Array = [0,0,0], weapon := 0) -> Dictionary:
	var profile := Profile.blank()
	var tree: RefCounted = Classes.connected_tree(class_id)
	profile[tree.profile_key] = tree.state([tree.nodes[focus_index].id])
	return Build.resolve(class_id, weapon, slots, profile)

func stats(source: Dictionary) -> Dictionary:
	return Resolved.Snapshot.from_build(source, {}).weapon_base_stats()

func allowed(expression: Dictionary, source: Dictionary, counts: Dictionary = {}) -> bool:
	return Requires.refusal(expression, Eligibility.facts(source, counts), Eligibility.schema()).is_empty()

func copy(id: String, serial: int, grade := 0) -> Dictionary:
	var definition: Dictionary = Catalog.DEFINITIONS[id]
	return {"id":id, "amount":definition.fixed if definition.policy == "unique" else definition.values[grade],
		"rarity":"" if definition.policy == "unique" else Catalog.RARITIES[grade], "floor":3, "acquisition_id":serial}

func run() -> void:
	check(Eligibility.catalog_errors().is_empty(), "all 28 current declarations and consumers validate")
	verify_migration()
	verify_tags()
	verify_capabilities()
	verify_identity_and_ownership()
	verify_grants()
	verify_short_offers()
	if not failed: print("PASS: CE01 ", checks, " checks; 28-card migration, unordered tags, capabilities, grants, ownership, headroom and short offers")
	quit(int(failed))

func verify_migration() -> void:
	check(Catalog.DEFINITIONS.size() == 28 and Catalog.PLAYTEST.acquisition_limit == 12 and Grafts.PLAYTEST.purchase_limit == 6,
		"catalog and acquisition budgets are preserved")
	for id: String in BASELINE_VALUES:
		for field: String in BASELINE_VALUES[id]:
			check(Catalog.DEFINITIONS[id][field] == BASELINE_VALUES[id][field], id + " unchanged " + field)
	for class_id in Classes.DEFINITIONS.size():
		for focus_index in 3:
			for weapon in 3:
				for family: String in Cores:
					var plant := part(family)
					var source := build(class_id, focus_index, [plant, plant, plant], weapon)
					var expected: Array = General + [Native[class_id], Cores[family]]
					if Forms.has(family): expected.append(Forms[family])
					if Catalysts.has(family): expected.append(Catalysts[family])
					if family == "water": expected.append("dew_shelter")
					if class_id == 1 and focus_index == 1: expected.append("echoing_growth")
					var actual := Ledger.new().eligible(stats(source), 2200)
					expected.sort(); actual.sort()
					check(actual == expected, "baseline eligibility preserved: %d/%d/%d/%s" % [class_id,focus_index,weapon,family])
	var mixed := build(1,1,[part("frost"),part("fire"),part("wood")])
	var available := Ledger.new().eligible(stats(mixed),2200)
	check(available.has("rime_opening") and available.has("burning_strikes_heat") and available.has("catalyst_bark_time")
		and not available.has("ember_impact") and not available.has("ironbark_time"), "mixed slots remain independent")
	var capped := stats(mixed)
	capped.interval = 230; capped.dodge_cooldown = 2200 - 350
	check(not Ledger.new().eligible(capped,2200).has("ordinary_weapon_interval")
		and not Ledger.new().eligible(capped,2200).has("run_dodge_recovery"), "existing effective floors still exclude zero-value choices")
	var partial := stats(mixed)
	partial.interval = 240
	var saw_partial := false
	for seed_value in 20:
		for option: Dictionary in Ledger.new().roll(seed_value,3,partial,2200):
			if option.id == "ordinary_weapon_interval": saw_partial = true; check(option.amount == 10, "partial timing headroom is preserved")
	check(saw_partial, "partial-headroom identity was actually observed")
	var previous := Ledger.new([copy("ordinary_weapon_damage",1),copy("ordinary_weapon_damage",2),copy("ordinary_weapon_damage",3,3)])
	check(previous.amount("ordinary_weapon_damage") == 6 and previous.counts().ordinary_weapon_damage == 3,
		"Common + Common + Epic are 1 + 1 + 4; ownership count differs from potency")

func verify_tags() -> void:
	var source := build(0,0,[part("thorn"),part("storm"),0])
	check(not allowed({"plant":{"tags_all":["thorn","storm"]}},source), "separate plants are not a same-plant hybrid")
	check(allowed({"distinct_slots":[{"tags_all":["thorn"]},{"tags_all":["storm"]}]},source), "separate slots bind distinct plants")
	var worldseed := 0
	# Resolve through the published species table instead of inventing a hybrid.
	for index in range(1,Build.Materials.DEFINITIONS.size()):
		if Build.Affinities.for_part(index).get("species_id") == "worldseed": worldseed = index; break
	var hybrid := build(0,0,[worldseed,0,0])
	check(allowed({"plant":{"slot":"core","primary_affinity":"wood","supporting_affinities":["vital","force"],"tags_all":["wood","vital","force"]}},hybrid),
		"primary and multiple unordered supporting tags match one actual plant")
	check(not allowed({"plant":{"supporting_affinities":["wood"]}},hybrid), "primary is not a supporting identity")
	check(not allowed({"distinct_slots":[{"tags_all":["wood"]},{"tags_all":["vital"]}]},hybrid), "one hybrid cannot fill two distinct slots")
	check(allowed({"plant":{"tags_any":["thorn","vital"]}},hybrid), "any-tag alternatives stay inside the matched plant")
	check(not allowed({"plant":{"slot":"form","tags_all":["vital"]}},hybrid), "slot constraints are respected")
	var reordered := hybrid.duplicate(true)
	reordered.core.supporting_affinities.reverse()
	check(allowed({"plant":{"supporting_affinities":["force","vital"]}},reordered), "supporting order has no rank or gameplay meaning")
	for bad in [{"plant":{"secondary":"vital"}}, {"plant":{"tags_any":[]}}, {"plant":{"tags_all":["unknown_tag"]}},
			{"all":[{"all":[]},{"unknown":true}]}, {"any":[{"all":[]},{"capability":{"producer":"core","id":"unsupported"}}]}]:
		check(not allowed(bad,hybrid), "malformed/unknown alternatives fail closed: " + str(bad))

func verify_capabilities() -> void:
	var frost := build(0,0,[part("frost"),0,0])
	check(allowed({"capability":{"producer":"core","id":"rime_bloom","slot":"core"}},frost), "actual Frost Core produces Rime Bloom")
	var supporting := build(0,0,[0,part("frost"),0])
	check(not allowed({"capability":{"producer":"core","id":"dewfall"}},supporting), "Frost's Water support does not grant Dewfall")
	var wood_form := build(0,0,[0,part("wood"),0])
	check(allowed({"capability":{"producer":"form","id":"splintering_strikes"}},wood_form)
		and not allowed({"capability":{"producer":"core","id":"ironbark"}},wood_form)
		and not allowed({"capability":{"producer":"catalyst","id":"self_bark"}},wood_form), "Wood Form grants splinters, not Bark generation")
	var warden := build(0,0,[0,0,part("wood")])
	check(allowed({"capability":{"producer":"catalyst","id":"self_bark","slot":"catalyst","target_scope":"affected_enemies"}},warden),
		"Catalyst facts retain the real adapter trigger footprint")
	check(not allowed({"capability":{"producer":"catalyst","id":"self_bark","recipient":"affected_enemies"}},warden),
		"an enemy trigger footprint is not falsely described as the Bark recipient")
	check(not allowed({"capability":{"producer":"catalyst","id":"recipient_bark"}},warden), "a heal-recipient response is not fabricated from a Wood tag")
	var empty := build()
	check(allowed({"capability":{"producer":"weapon","id":"strike"}},empty), "zero plant parts retain ordinary attack eligibility")
	var bloom := build(1,1)
	check(Eligibility.requirement(Catalog.DEFINITIONS.echoing_growth,bloom).is_empty()
		and not Eligibility.requirement(Catalog.DEFINITIONS.echoing_growth,build(1,0)).is_empty(), "Bloomcaller and its real Q/R are required")
	var broken := bloom.duplicate(true)
	broken.class_skills[0].native_skill.field = "sanctuary"
	check(not Eligibility.requirement(Catalog.DEFINITIONS.echoing_growth,broken).is_empty(), "focus identity alone cannot fake the required growth field")
	var facts := Eligibility.facts(warden)
	var detached := facts.duplicate(true)
	detached.capabilities.clear(); detached.plants.clear()
	check(not Eligibility.facts(warden).capabilities.is_empty() and not warden.catalyst.is_empty(), "inspection cannot mutate build facts")
	# No HP, current Bark, ability deadline or enemy-status state enters facts.
	check(not facts.has("hp") and not facts.has("bark") and not facts.has("cooldowns"), "depletion and cooldown readiness do not gate offers")

func verify_identity_and_ownership() -> void:
	var source := build(1,1)
	var tree: RefCounted = Classes.connected_tree(1)
	var profile := Profile.blank()
	profile.xp[1] = 50
	profile[tree.profile_key] = tree.state(["bloomcaller","patient_spore"])
	source = Build.resolve(1,0,[0,0,0],profile)
	var expression := {"all":[{"class":"weaver"},{"focus":"bloomcaller"},{"weapon":source.weapon_id},
		{"node":{"class":"weaver","id":"patient_spore"}}]}
	check(allowed(expression,source), "class, focus, weapon and actually selected stable node match")
	check(not allowed({"node":{"class":"weaver","id":"twining_reach"}},source), "earned level is not an unselected node")
	check(not allowed({"focus":"thornbinder"},source) and not allowed({"weapon":"0_0"},source), "cross-identity predicates reject mismatches")
	check(not allowed({"owned":{"kind":"card","id":"ordinary_weapon_damage"}},source), "candidate does not count itself as already acquired")
	check(allowed({"owned":{"kind":"card","id":"ordinary_weapon_damage","count":2}},source,{"ordinary_weapon_damage":2})
		and not allowed({"owned":{"kind":"card","id":"ordinary_weapon_damage","count":3}},source,{"ordinary_weapon_damage":2}), "per-copy ownership counts are exact")
	var improved := source.duplicate(true)
	improved.improvements = {"bonuses":{},"adaptations":["silken_link"],"owned":{"silken_link":1,"strike":2}}
	check(allowed({"owned":{"kind":"graft","id":"silken_link"}},improved)
		and allowed({"owned":{"kind":"graft","id":"strike","count":2}},improved)
		and allowed({"capability":{"producer":"graft","id":"silken_link"}},improved), "real graft IDs and receipt-derived reinforcement counts are available")
	check(not allowed({"owned":{"kind":"graft","id":"silken_link"}},source), "carried material or botanical tag does not imply acquired graft")
	check(not allowed({"class":"not_a_class"},source) and not allowed({"owned":{"kind":"card","id":"harvest"}},source), "unknown class and unimplemented transformation IDs fail closed")
	check(allowed({"any":[{"focus":"thornbinder"},{"all":[{"class":"weaver"},{"focus":"bloomcaller"}]}]},source),
		"valid nested AND/OR alternatives work without per-card code")
	# Actual owner receipts, not a second acquisition counter.
	var owner := Grafts.Ledger.new(41)
	var carried: Array = Build.Materials.empty_counts()
	var trophy: int = Build.Materials.monster_part(0)
	carried[trophy] = 2
	for index in 2:
		var floor_number := (index + 1) * 8
		var resolved := Resolved.Snapshot.from_build(source, {})
		var plan := owner.plan_purchase({"run":41,"floor":floor_number,"revision":index,"id":"strike","item":"monster_0"},
			floor_number,carried,resolved.graft_value_resolver(100,0,0))
		check(plan.has("ledger"), "real graft purchase admits reinforcement before eligibility projection")
		if plan.has("ledger"): owner = plan.ledger; carried[trophy] -= int(plan.cost)
	improved.improvements = owner.resolution()
	check(allowed({"owned":{"kind":"graft","id":"strike","count":2}},improved)
		and carried[trophy] == 0 and owner.details(16).copies.size() == 2, "graft counts derive from the actual two accepted receipts")

func verify_grants() -> void:
	var source := build(1,1,[part("water"),0,0])
	var definition: Dictionary = Catalog.DEFINITIONS.dew_shelter
	check(Eligibility.requirement(definition,source).is_empty(), "a valid candidate grants a missing Ward feature without already owning it")
	check(not allowed({"capability":{"producer":"card","id":"dew_shelter"}},source), "unacquired grant is not an existing capability")
	check(allowed({"capability":{"producer":"card","id":"dew_shelter"}},source,{"dew_shelter":1}), "actual acquisition enables a consumer-verified grant")
	check(not allowed({"capability":{"producer":"card","id":"dew_shelter"}},build(1,1),{"dew_shelter":1}), "ownership cannot bypass a grant's external Dewfall prerequisite")
	var self_required := definition.duplicate(true)
	self_required.requires = {"owned":{"kind":"card","id":"dew_shelter"}}
	check(not Eligibility.requirement(self_required,source).is_empty(), "a candidate cannot satisfy its own acquired-card prerequisite")
	var invalid := definition.duplicate(true)
	invalid.grants = ["harvest"]
	check(not Eligibility.verified_grants(invalid).get("error", "").is_empty(), "a named declaration cannot invent an unimplemented capability")
	var texture_path := "res://assets/ui/seeds/dewcap.png"
	var missing_path := "res://tests/ce01_missing_consumer.gd"
	check(ResourceLoader.exists(texture_path), "non-Script regression uses an existing texture")
	check(not ResourceLoader.exists(missing_path), "missing-resource regression uses an absent path")
	for consumer: Array in [[texture_path,"on_event"], [missing_path,"on_event"], ["res://water_combat.gd","missing_consumer"]]:
		for declared_grants: Array in [definition.grants, []]:
			invalid = definition.duplicate(true)
			invalid.consumer = consumer
			invalid.grants = declared_grants.duplicate()
			var verification := Eligibility.verified_grants(invalid)
			var error := str(verification.get("error", ""))
			var context := str(consumer) + " grants=" + str(declared_grants)
			check(not error.is_empty() and verification.get("capabilities", []).is_empty(),
				"invalid consumers authorize no capabilities: " + context)
			check(not error.is_empty() and Eligibility.requirement(invalid,source) == error,
				"invalid consumers consistently refuse requirements: " + context)
			check(not error.is_empty() and Eligibility.catalog_errors({"dew_shelter":invalid}).get("dew_shelter", "") == error,
				"catalog diagnostics retain the consumer failure: " + context)
	var no_grants: Dictionary = Catalog.DEFINITIONS.dewfall_impact
	var verified := Eligibility.verified_grants(no_grants)
	check(not verified.has("error") and verified.has("capabilities") and verified.capabilities.is_empty(),
		"a valid numerical card explicitly verifies without granting a capability")
	check(Eligibility.requirement(no_grants,source).is_empty(), "a valid card with no grants remains eligible")
	check(Eligibility.catalog_errors({"dewfall_impact":no_grants}).is_empty(), "a valid card with no grants has no consumer diagnostic")
	var cyclic := {"dew_shelter":definition.duplicate(true), "echoing_growth":Catalog.DEFINITIONS.echoing_growth.duplicate(true)}
	cyclic.dew_shelter.requires = {"capability":{"producer":"card","id":"echoing_growth"}}
	cyclic.echoing_growth.requires = {"capability":{"producer":"card","id":"dew_shelter"}}
	check(Eligibility.catalog_errors(cyclic).size() == 2, "circular capability grants cannot bootstrap each other")
	var odd := definition.duplicate(true)
	odd.requires = {"any":[{"all":[]},{"owned":{"kind":"card","id":"not_a_card"}}]}
	check(not Eligibility.requirement(odd,source).is_empty(), "an invalid OR branch cannot hide behind an unconditional alternative")
	var zero := definition.duplicate(true)
	zero.fixed = 0
	check(not Eligibility.catalog_errors({"dew_shelter":zero}).is_empty(), "a zero-value capability grant cannot enter offers")
	var malformed := definition.duplicate(true)
	var nested := {"all":[]}
	var current: Dictionary = nested
	for _index in Requires.MAX_DEPTH + 1:
		var next := {"all":[]}
		current.all.append(next); current = next
	malformed.requires = nested
	check(not Eligibility.catalog_errors({"dew_shelter":malformed}).is_empty(), "excessively nested content fails without unbounded dependency traversal")

func remaining_pool(size: int, base_stats: Dictionary) -> Ledger:
	var records: Array[Dictionary] = []
	# Timing floors reduce a legitimate zero-part Warden pool to exactly three.
	base_stats.interval = 230; base_stats.dodge_cooldown = 2200 - 350
	for id: String in ["ordinary_weapon_damage","run_health","quake_impact"].slice(size):
		for index in 4: records.append(copy(id,records.size()+1))
	var ledger := Ledger.new(records)
	check(ledger.eligible(base_stats,2200).size() == size, "fixture has exactly %d remaining useful identities" % size)
	return ledger

func verify_short_offers() -> void:
	for size in 4:
		var base_stats := stats(build())
		var ledger := remaining_pool(size,base_stats)
		var opened := ledger.open_offer(3,101,7,base_stats,2200)
		check(opened.offer().cards.size() == size, "offers contain only the %d useful identities" % size)
		check(is_same(opened,opened.open_offer(3,999,17,base_stats,2200)), "reopening cannot reroll a short offer")
		var refused := opened.plan_choice(3,101,"reroll",102,7,99,base_stats,2200)
		check(not refused.has("ledger") and not refused.has("cost"), "no different identity means no debit or replacement")
		check(opened.plan_choice(3,101,"skip",102,7,0,base_stats,2200).ready, "empty and short offers permit continuation")
	var unavailable := stats(build())
	unavailable.affinity_build.capabilities.strike = false
	unavailable.affinity_build.capabilities.class_actions = false
	unavailable.dodge_cooldown = 2200 - 350
	var health_copies: Array[Dictionary] = []
	for index in 4: health_copies.append(copy("run_health",index+1))
	var empty := Ledger.new(health_copies).open_offer(3,151,7,unavailable,2200)
	check(not empty.exhausted() and empty.offer().cards.is_empty()
		and empty.plan_choice(3,151,"skip",152,7,0,unavailable,2200).ready, "zero supported choices can continue independently of acquisition-budget exhaustion")
	# An already opened one-card offer and a newly eligible second identity.
	var base_stats := stats(build())
	var ledger := remaining_pool(2,base_stats)
	var options := ledger.roll(7,3,base_stats,2200)
	var first: Dictionary = options[0]
	var opened := Ledger.new(ledger.copies(),{"floor":3,"revision":201,"rerolls":0,"cards":[first]})
	var before := Wallet.Wallet.new(20)
	var plan := opened.plan_choice(3,201,"reroll",202,7,before.balance(0,1),base_stats,2200)
	check(plan.has("ledger") and plan.cost == 2 and plan.ledger.offer().cards.size() == 2
		and plan.ledger.offer().cards.any(func(option):return option.id != first.id), "a genuine short replacement is valid without three identities")
	if plan.has("ledger"):
		check(not plan.ledger.plan_choice(3,201,"0",203,7,20,base_stats,2200).has("ledger"), "old short-offer revision cannot acquire a replacement")
	var stale := base_stats.duplicate(true)
	stale.affinity_build.capabilities.strike = false
	var weapon := copy("ordinary_weapon_damage",1)
	var reject := Ledger.new([], {"floor":3,"revision":301,"rerolls":0,"cards":[weapon]})
	check(not reject.plan_choice(3,301,"0",302,7,0,stale,2200).has("ledger"), "selection revalidates actual capabilities")
