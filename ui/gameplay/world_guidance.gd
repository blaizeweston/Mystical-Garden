extends RefCounted
## Pure world-facing guidance. Receives display facts, never Game or actors.
## These strings and warning margins cannot authorize an interaction or a hit.
const Enemies = preload("res://enemy_catalog.gd")
const Seeds = preload("res://seed_catalog.gd")
const Campaign = preload("res://campaign.gd")
const Encounter = preload("res://encounter_config.gd")
const Gate = preload("res://gate_interaction.gd")
const WARNING_MARGIN_METERS := 0.7
const CHARGE_MARGIN_METERS := 0.4
const SCOUT_FORM_OFFSET := 19 # Existing compact presentation layout.

static func project(facts: Dictionary) -> Dictionary:
	var result := {"prompt":"","details":"","session_text":""}
	if facts.wild: _wild(facts,result)
	else: _garden(facts.garden,result)
	if facts.root_access: result.prompt="E  Returning Root · secure a carried resource"
	if not facts.garden_prompt.is_empty(): result.prompt=facts.garden_prompt
	if not facts.rescue.is_empty():
		result.prompt="E  Revive %s · costs them %d maximum HP"%[facts.rescue.name,facts.rescue.cost] if facts.rescue.allowed else "This ally has too little maximum health to revive."
	if facts.fallen and facts.wild: result.prompt="Fallen · awaiting revival"
	if facts.pickup and facts.rescue.is_empty() and not facts.fallen: result.prompt="E  Pick up item"
	if facts.wild:
		result.session_text="%s  ·  %d player(s)"%[facts.role,facts.party_size]
	else:
		result.session_text="%s  |  %d player(s)"%[facts.role,facts.party_size]
		result.session_text+="\nDeepest clear %d  ·  Best extraction %d"%[facts.garden.deepest_clear,facts.garden.best_extraction]
	if facts.role=="Host": result.session_text+="\nHosting on UDP %d"%facts.host_port
	return result

static func _wild(facts: Dictionary, result: Dictionary) -> void:
	if not facts.cleared:
		var warning := attack_warning(facts.position,facts.leader,facts.scouts,facts.campaign,facts.warnings)
		result.prompt="Dodge out of the marked attack!" if warning.danger else "Stand at a hatch site to block it." if warning.hatching else ""
	elif facts.depth<Encounter.BIOME_LENGTH: result.prompt="E  Continue"
	else: result.prompt="Continue to %s"%Campaign.NAMES[(facts.route+1)%Campaign.BIOME_COUNT]
	if facts.upgrade_open and facts.offer_floor!=facts.floor:
		result.prompt="E  Choose an upgrade" if facts.gate_distance<=Gate.RANGE else "Upgrades await at the gate"
	if facts.extraction_open and facts.gate_distance<=Gate.RANGE:
		result.prompt="E  Continue    ·    T  Extract to the Garden"
		result.details="Extract or continue."
		if facts.offer_floor!=facts.floor: result.details+="\nE  Choose an upgrade   ·   %d Essence"%facts.wallet
	if facts.flora_near and (facts.cleared or result.prompt.is_empty()):
		result.prompt="E  Harvest wild specimen"
		result.details=facts.get("harvest_benefits","")
	if facts.cache_near: result.prompt="E  Search the abandoned clearing"
	if facts.graft_near:
		result.prompt="E  Grafting Altar"
		result.details="Altar used" if facts.improvements.get("used",false) else "Spend a carried trophy on an expedition improvement."
		if facts.improvements.has("remaining"): result.details+=" · %d remaining"%int(facts.improvements.remaining)

static func _garden(garden: Dictionary, result: Dictionary) -> void:
	var bed: Dictionary=garden.bed
	if not bed.is_empty():
		if bed.species>=0:
			result.prompt="E  Harvest %s"%("seed" if bed.flowering else "crafting parts") if bed.stage==3 else "%s · %s"%[Seeds.NAMES[bed.species],["Seed","Sprout","Young","Mature"][bed.stage]]
			if bed.flowering and bed.stage<3: result.prompt+=" · Seed crop"
			if not bed.flowering:
				result.prompt+="  |  F  Harvest seeds instead" if int(bed.stage)==3 else "  |  Seeds can be harvested when mature"
		else: result.prompt="E  Choose a seed to plant"
	elif garden.near_altar:
		result.prompt="E  Altar";result.details="Identify seeds · Combine seeds or plant parts"
	elif garden.near_gate: result.prompt="E  Wilds Gate"
	elif garden.near_heart:
		result.prompt="E  Heart"
		if garden.development: result.prompt+="   ·   B  Garden development"

## Existing leader, scout and charge warning tests; display margins only.
# Guidance indexes whole stride groups.
@warning_ignore_start("integer_division")
static func attack_warning(at: Vector3, leader: Dictionary, pack: PackedFloat32Array, campaign: PackedInt32Array, hints: Array) -> Dictionary:
	var hatching: bool=leader.boss_kind==22 and hints.any(func(hint):return hint.role=="nursery_exit")
	var warning: bool=not hatching and leader.winding_up and (leader.landing if leader.attack_mode=="vault" else leader.position).distance_to(at)<float(leader.radius)+WARNING_MARGIN_METERS
	for offset in range(2,pack.size(),Encounter.PACK_STRIDE):
		var impact:=Vector3(pack[offset+4],0,pack[offset+5])
		var slot: int=(offset-2)/Encounter.PACK_STRIDE
		var code: int=campaign[SCOUT_FORM_OFFSET+slot] if campaign.size()>SCOUT_FORM_OFFSET+slot else 0
		var form:=Enemies.decode(code)
		var radius:=Enemies.radius(int(form.kind),int(form.mask))
		warning=warning or (Enemies.get_kind(form.kind).role!="chant" and pack[offset]>0.0 and pack[offset+1]>0.0 and impact.distance_to(at)<radius+WARNING_MARGIN_METERS)
	for hint in hints:
		if hint.role=="charge":
			var start:=Vector3(hint.from[0],0,hint.from[2]);var finish:=Vector3(hint.to[0],0,hint.to[2])
			warning=warning or at.distance_to(Geometry3D.get_closest_point_to_segment(at,start,finish))<=float(hint.width)+CHARGE_MARGIN_METERS
	return {"danger":warning,"hatching":hatching}
@warning_ignore_restore("integer_division")
