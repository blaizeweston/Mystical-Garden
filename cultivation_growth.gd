extends RefCounted
# Shared work/time policy. Only the host advances growth; all viewers use this rate.
const Seeds=preload("res://seed_catalog.gd")
const Care=preload("res://garden_crop_state.gd")
const Layout=preload("res://garden_layout.gd")
const VERSION:=2
const WILDS_RATE:=2.0
const WATER_RATE:=1.25
const SAVE_WORK_INTERVAL:=30.0
static var signature: String=var_to_str([VERSION,WILDS_RATE,WATER_RATE,"spring_vessel",Care.Catalog.signature,Seeds.DEFINITIONS.map(func(s):return [s.id,s.grow_seconds])]).sha256_text()
static func supported(bed: Dictionary) -> bool:return int(bed.get("growth_rules",VERSION))<=VERSION
static func base(bed: Dictionary) -> float:return float(Seeds.DEFINITIONS[int(bed.species)].grow_seconds)
static func duration(bed: Dictionary) -> float:return Care.duration(bed,base(bed))
static func spring_ready(owner: RefCounted) -> bool:
 var zone:=Layout.zone("sheltered_spring")
 return not zone.is_empty() and Layout.enabled(zone,owner.heart.unlocked)
static func watered(bed: Dictionary) -> bool:return Care.compatible(bed) and bed.care.get("watered",false)==true
static func rate(owner: RefCounted,bed: Dictionary,in_wilds: bool=false) -> float:
 return owner.heart.growth_multiplier()*(WILDS_RATE if in_wilds else 1.0)*(WATER_RATE if watered(bed) else 1.0)
static func restore(saved: Dictionary,bed: Dictionary) -> void:
 var rules:=int(saved.get("growth_rules",1))
 if rules>VERSION:
  bed.growth_rules=rules;bed.growth_base=saved.get("growth_base",base(bed));return
 var definition: Dictionary=Seeds.DEFINITIONS[int(bed.species)]
 var old_base:=maxf(1,float(saved.get("growth_base",definition.get("legacy_grow_seconds",definition.grow_seconds))))
 var old_total:=Care.duration(bed,old_base)
 var fraction:=clampf(float(bed.age)/old_total,0,1)
 if int(saved.get("stage",0))>=3:fraction=1.0
 bed.growth_rules=VERSION;bed.growth_base=base(bed);bed.flowering=false
 # Old saves selected a seed-growing mode. It is now a choice at harvest.
 if Care.compatible(bed) and bed.care.choice=="flower":bed.care.choice="leave"
 bed.age=fraction*duration(bed)
static func initialize(bed: Dictionary) -> void:
 if not bed.has("growth_rules"):bed.growth_rules=VERSION;bed.growth_base=base(bed)
static func water(bed: Dictionary) -> void:
 if not Care.compatible(bed) or watered(bed):return
 bed.care.watered=true;Care.bump(bed)
# Displayed hours and minutes omit fractional units.
@warning_ignore_start("integer_division")
static func time_text(seconds: float) -> String:
 var value:=maxi(0,ceili(seconds))
 if value<60:return "%ds"%value
 if value<3600:return "%dm %02ds"%[value/60,value%60]
 return "%dh %02dm"%[value/3600,(value%3600)/60]
@warning_ignore_restore("integer_division")
