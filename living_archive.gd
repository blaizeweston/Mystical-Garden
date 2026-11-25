extends RefCounted
## Absolute Garden and character totals. Only accepted host operations call these methods.
const VERSION := 1
const BEST := ["deepest", "cleared", "longest_ms"]
const COMBAT := ["damage", "kills", "elites", "bosses", "taken", "healing", "prevented", "revives", "falls"]
const AFFINITIES := ["Bleed", "Brittle rupture", "Burning", "Surge", "Bloodletting", "Flashover", "Shatterwave", "Hemorrhagic rupture"]
const ACTIVITY := ["plants", "seed_harvests", "seeds", "parts", "refined", "wild", "crosses", "roots", "runs", "extracts", "abandons", "wipes", "time_ms", "participant_ms", "energy", "built"]

static func fresh(origin := "") -> Dictionary:
	return {"version":VERSION, "origin":origin if not origin.is_empty() else Crypto.new().generate_random_bytes(16).hex_encode(), "garden":{}, "characters":{}}

static func valid_id(value: Variant) -> bool:
	return value is String and value.length() == 32 and value.is_valid_hex_number(false)

static func valid_totals(row: Variant) -> bool:
	if not row is Dictionary: return false
	for key in row:
		if key not in ACTIVITY and key not in COMBAT and key not in BEST and key not in AFFINITIES: return false
		var value: Variant = row[key]
		if not (value is int or value is float) or not is_finite(value) or value < 0: return false
	return true

static func valid_visits(visits: Variant) -> bool:
	if not visits is Dictionary: return false
	for origin in visits:
		if not valid_id(origin) or not valid_totals(visits[origin]): return false
	return true

static func valid(state: Variant) -> bool:
	return state is Dictionary and state.get("version") == VERSION and valid_id(state.get("origin")) and valid_totals(state.get("garden")) and valid_visits(state.get("characters"))

static func add(row: Dictionary, key: String, value: Variant) -> void:
	if value > 0: row[key] = row.get(key, 0) + value

static func join_totals(target: Dictionary, source: Dictionary) -> void:
	for key: String in source:
		if key in BEST: target[key] = maxi(target.get(key,0), source[key])
		else: add(target,key,source[key])

static func activity(state: Dictionary, identity: String, amounts: Dictionary) -> void:
	join_totals(state.garden,amounts)
	if not valid_id(identity): return
	if not state.characters.has(identity): state.characters[identity] = {}
	join_totals(state.characters[identity],amounts)

static func harvest(state: Dictionary, identity: String, result: Dictionary) -> void:
	activity(state,identity,{"plants":1,"seed_harvests":int(result.seeds>0),"seeds":result.seeds,
		"parts":result.parts,"refined":int(result.rare_part>0)})

## Each outgoing profile projection carries one authoritative Garden slice.
## The full collection of visited Gardens stays on the character owner's machine.
static func set_slice(profile: Dictionary, state: Dictionary, identity: String) -> void:
	var totals: Dictionary = state.characters.get(identity,{})
	if totals.is_empty(): profile.erase("archive_slice")
	else: profile.archive_slice = {"origin":state.origin,"totals":totals.duplicate()}

static func personal(visits: Dictionary, origin: String, current: Dictionary) -> Dictionary:
	var total := current.duplicate()
	for previous in visits:
		if previous != origin: join_totals(total,visits[previous])
	return total

## Use the existing bounded expedition return receipt. A disconnect may settle
## after its floor or run disappeared. Never borrow the current run's identity.
static func settle(progress: RefCounted, run_id: String, identity: String, report: Dictionary) -> bool:
	if report.is_empty() or run_id.is_empty() or not valid_id(identity): return false
	var returns: Dictionary = progress.garden_interactions.get("returns",{})
	var run: Dictionary = returns.get("active",{})
	if run.get("id") != run_id or run.get("closed",false):
		run = {}
		for previous in returns.get("history",[]):
			if previous.run == run_id:
				run = previous
				break
	if run.is_empty(): return false
	var receipt: Dictionary = run.get("archive",{})
	if receipt.get("complete",false): return false
	var members: Array = receipt.get("members",[])
	if identity in members: return false
	var row: Dictionary = report.players[report.personal_index]
	var state: Dictionary = progress.archive
	var individual := {"runs":1,"extracts":int(report.outcome=="Extraction"),"abandons":int(report.outcome=="Abandonment"),
		"time_ms":row.participation_ms,"longest_ms":row.participation_ms,"deepest":row.deepest,"cleared":row.cleared,"wild":row.get("wild",0)}
	for key in COMBAT: individual[key] = row.get(key,0)
	for key in AFFINITIES: add(individual,key,row.affinity.get(key,0))
	if not state.characters.has(identity): state.characters[identity] = {}
	join_totals(state.characters[identity],individual)

	var shared: Dictionary = state.garden
	if members.is_empty(): add(shared,"runs",1)
	members.append(identity)
	receipt.members = members
	for flag in ["extracts","wipes"]:
		var qualifies: bool = report.outcome == ("Extraction" if flag=="extracts" else "Party wipe")
		if qualifies and not receipt.get(flag,false):
			add(shared,flag,1)
			receipt[flag] = true
	add(shared,"participant_ms",row.participation_ms)
	for key in ["abandons","taken","prevented","revives","falls","wild"]: add(shared,key,individual[key])
	shared.deepest = maxi(shared.get("deepest",0),report.floor)
	shared.cleared = maxi(shared.get("cleared",0),report.cleared_floor)
	shared.longest_ms = maxi(shared.get("longest_ms",0),report.elapsed_ms)
	var cumulative := {"time_ms":report.elapsed_ms}
	for key in ["kills","elites","bosses","damage","healing"]: cumulative[key] = report.party[key]
	for key in AFFINITIES: cumulative[key] = report.party.get("affinity",{}).get(key,0)
	var previous: Dictionary = receipt.get("party",{})
	for key in cumulative:
		var increase: Variant = cumulative[key] - previous.get(key,0)
		if increase > 0:
			add(shared,key,increase)
			previous[key] = cumulative[key]
	receipt.party = previous
	var expected := 0
	for count in run.get("outcomes",{}).values(): expected += int(count)
	# A closed run with every row recorded only needs a single replay marker.
	run.archive = {"complete":true} if expected > 0 and members.size() == expected else receipt
	return true

static func station(progress: RefCounted, identity: String) -> Dictionary:
	var recipes := {"seed":[0,0], "synthesis":[0,0], "refinement":[0,0]}
	var active := {}
	for recipe in preload("res://altar_recipes.gd").all():
		var kind := "seed" if recipe.mode=="seeds" else ("refinement" if recipe.inputs[0]==recipe.inputs[1] else "synthesis")
		active[recipe.id] = true
		recipes[kind][1] += 1
		if progress.altar_recipes.get(recipe.id,{}).get("success",false): recipes[kind][0] += 1
	var retired := 0
	for key: String in progress.altar_recipes:
		var recorded: Dictionary = progress.altar_recipes[key]
		if key.begins_with("seeds|") and not active.has(key) and (recorded.success or recorded.get("historical_success",false)): retired += 1
	var placed := 0
	var beds := 0
	var cultivation := 0
	for entry in progress.structures.instances.values():
		placed += int(entry.placed)
		beds += int(entry.kind == "bed")
		cultivation += int(progress.Structures.Catalog.DEFINITIONS[entry.kind].has("effect"))
	var current := {"species":[progress.discoveries.count(true),progress.Seeds.DEFINITIONS.size()],
		"recipes":recipes,"retired":retired,"knowledge":progress.knowledge,"available":progress.heart.available_insight(progress),
		"research":[progress.heart.unlocked.size()-1,progress.heart.Catalog.DEFINITIONS.size()-1],
		"frontiers":progress.garden_development.get("revision",0),"land":progress.garden_development.get("reclaimed_cells",0),
		"beds":beds,"cultivation":cultivation,"placed":placed,"stored":progress.structures.instances.size()-placed,
		"stage":progress.heart.Catalog.phase_name(progress.heart.phase(progress)),
		"guardians":progress.campaign.memories.duplicate(),"decoded":progress.heart.decoded.duplicate(),
		"best_clear":progress.campaign.best_clear,"best_extraction":progress.campaign.best_extraction,"returns":[]}
	for entry in preload("res://garden_return_service.gd").projection(progress.garden_interactions).get("entries",[]):
		current.returns.append(entry.name if entry.has("name") else entry.description)
	return {"version":VERSION,"origin":progress.archive.origin,"garden":progress.archive.garden.duplicate(),
		"personal":progress.archive.characters.get(identity,{}).duplicate(),"current":current}
