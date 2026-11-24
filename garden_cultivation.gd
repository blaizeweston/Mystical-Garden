extends RefCounted
## Native crop rules. Inputs are detached bed/recipient facts, never Game,
## actors, save owners or RNG. GardenCultivationWorld applies accepted outcomes.
const Care=preload("res://garden_crop_state.gd")
const Catalog=preload("res://garden_crop_catalog.gd")
const Growth=preload("res://cultivation_growth.gd")
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")

# Unchanged native harvest values; probabilities are fractions, HP is unrelated.
const HARVEST_SEEDS:=2
const HARVEST_PARTS:=1
const FAMILIARITY_LIMIT:=9999
const RARE_BASE:=0.05
const RARE_EARLY_GAIN:=0.04
const RARE_EARLY_LEVELS:=5
const RARE_LATE_GAIN:=0.005
const RARE_LIMIT:=0.45

static func rare_harvest_chance(familiarity: int) -> float:
	return minf(RARE_LIMIT,RARE_BASE+RARE_EARLY_GAIN*mini(familiarity,RARE_EARLY_LEVELS)+RARE_LATE_GAIN*maxi(0,familiarity-RARE_EARLY_LEVELS))

static func familiarity_after(before: int, gain: int) -> int:
	return mini(FAMILIARITY_LIMIT,before+gain)

static func planted_bed(species: int, care: Dictionary) -> Dictionary:
	return {"species":species,"age":0.0,"stage":0,"flowering":false,"growth_rules":Growth.VERSION,
		"growth_base":float(Seeds.DEFINITIONS[species].grow_seconds),"care":care.duplicate(true)}

static func harvest_yield(bed: Dictionary, familiarity: int, ordinary_roll: float, local := {}) -> Dictionary:
	var species:=int(bed.species)
	if species<0 or int(bed.stage)<3:return {}
	if bool(bed.flowering):
		return {"species":species,"seeds":int(local.get("seeds",HARVEST_SEEDS)),"parts":0,"rare_part":0,
			"message":"Harvested %d %s seeds. The bed is ready to replant."%[local.get("seeds",HARVEST_SEEDS),Seeds.NAMES[species]]}
	# Historical preserved draws remain authoritative. Coverage changes the threshold.
	var roll:=Care.roll(bed) if Care.preserved(bed) else ordinary_roll
	var rare:=Parts.rare_part(species) if roll<minf(1.0,Care.chance(bed,rare_harvest_chance(familiarity))+float(local.get("refinement",0))) else 0
	var message: String="Harvested a %s part. Replant this bed with any identified seed."%Seeds.NAMES[species]
	if rare>0:message+=" Rare harvest: "+Parts.part_name(rare)+"."
	return {"species":species,"seeds":0,"parts":HARVEST_PARTS,"rare_part":rare,"message":message}

static func bed_slot(point: String) -> int:
	var number:=point.trim_prefix("bed_")
	return int(number)-1 if number.is_valid_int() else -1

static func _reject(message: String) -> Dictionary:
	return {"operation":"reject","error":message}

static func care_request(request: Dictionary, can_tend: bool, bed: Dictionary, spring_ready: bool, water_carried: bool, enhanced := false) -> Dictionary:
	var point:=str(request.get("point",""));var number:=point.trim_prefix("bed_")
	if not number.is_valid_int():return _reject("Unknown planting bed.")
	var slot:=int(number)-1
	if point!="bed_"+str(slot+1) or not can_tend:return _reject("Move closer to a Garden bed before tending it.")
	if not Care.compatible(bed):return _reject("This crop cannot be tended by this game version.")
	if request.get("cycle","")!=bed.care.cycle:return _reject("This bed contains a different crop. Inspect it again.")
	var action:=str(request.get("action",""));var chosen: String={"preserve_bud":"preserve","enhance_bud":"preserve","leave_bud":"leave"}.get(action,"")
	if action=="enhance_bud" and not enhanced:return _reject("Research Bud Sanctuary Effectiveness first.")
	# An already applied identical choice is a no-op even with its old revision.
	if (action=="water_crop" and Growth.watered(bed)) or (not chosen.is_empty() and bed.care.choice==chosen):
		return {"operation":"noop","revision":bed.care.revision}
	if request.get("revision",-1)!=bed.care.revision or request.get("stage",-1)!=int(bed.stage):return _reject("This crop has changed. Review it before choosing.")
	match action:
		"inspect_crop":return {"operation":"focus"}
		"flower_crop":return {"operation":"seeds"}
		"water_crop":
			if int(bed.stage)>=3 or not Growth.supported(bed) or not spring_ready:return _reject("Garden water is unavailable for this crop.")
			if not water_carried:return _reject("Fill your watering vessel at Garden water first.")
			return {"operation":"water"}
		"harvest_crop":
			if int(bed.stage)!=3:return _reject("This crop is still growing.")
			return {"operation":"parts"}
	if chosen.is_empty() or not Care.available(bed):return _reject("That bud is no longer available. The crop will keep growing.")
	return {"operation":"choose","choice":chosen}

static func bed_projection(slot: int, bed: Dictionary, familiarity: int, rates: Dictionary, spring_ready: bool, enhanced: bool) -> Dictionary:
	var species:=int(bed.species);var care: Dictionary=bed.get("care",{})
	var base:=float(Seeds.DEFINITIONS[species].grow_seconds)
	var policy:=Catalog.definition(str(care.get("opportunity","")))
	var chance:=rare_harvest_chance(familiarity)
	var local: Dictionary = rates.get("effects",{})
	var bonus := float(local.get("refinement",0.0))
	var work:=maxf(0,Care.duration(bed,base)-float(bed.age))
	return {"slot":slot,"species":species,"stage":int(bed.stage),"flowering":bool(bed.flowering),
		"cycle":care.get("cycle",""),"revision":care.get("revision",0),"choice":care.get("choice",""),
		"compatible":Care.compatible(bed),"available":Care.available(bed),"preserved":Care.preserved(bed),
		"remaining":work/float(rates.current),"garden_remaining":work/float(rates.garden),"wild_remaining":work/float(rates.wild),"growth_rate":rates.current,
		"base_chance":minf(1,chance+bonus),"chance":minf(1,Care.chance(bed,chance)+bonus),"preserve_chance":minf(1,minf(float(policy.get("rare_cap",1)),chance+float(policy.get("rare_bonus",0)))+bonus),
		"seeds":int(local.get("seeds",HARVEST_SEEDS)), "familiarity":int(local.get("familiarity",1)), "vital":local.get("growth",1.0), "water_rate":rates.get("water_rate",Growth.WATER_RATE),"auto_care":int(local.get("care",0)),
		"extra_seconds":base*float(policy.get("delay_fraction",0))/float(rates.current),"flower_enabled":true,"enhanced":enhanced,
		"opportunity":care.get("opportunity","patient_bud"),"watered":Growth.watered(bed),"sprinkler":rates.get("sprinkler",false),
		"water_available":Growth.supported(bed) and Care.compatible(bed) and int(bed.stage)<3 and spring_ready and not Growth.watered(bed),"spring_ready":spring_ready}
