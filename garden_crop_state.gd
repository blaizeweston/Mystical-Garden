extends RefCounted
const Catalog=preload("res://garden_crop_catalog.gd")
const Seeds=preload("res://seed_catalog.gd")
const ROLL_SCALE:=1000000
static func new_cycle(species: int) -> Dictionary:
 return {"version":1,"cycle":Crypto.new().generate_random_bytes(16).hex_encode(),"species":str(Seeds.DEFINITIONS[species].id),"revision":0,"opportunity":"patient_bud","choice":""}
static func restore(value,species: int) -> Dictionary:
 if not value is Dictionary or value.is_empty():return new_cycle(species)
 var result: Dictionary=value.duplicate(true)
 if result.get("version",0)!=1:return result
 if result.get("species","")!=str(Seeds.DEFINITIONS[species].id):return new_cycle(species)
 return result
static func compatible(bed: Dictionary) -> bool:
 var state=bed.get("care",{})
 if int(bed.get("species",-1))<0 or not state is Dictionary or state.get("version",0)!=1:return false
 if state.get("species","")!=str(Seeds.DEFINITIONS[int(bed.species)].id):return false
 if not state.get("cycle") is String or state.cycle.length()!=32 or not state.cycle.is_valid_hex_number(false):return false
 if not state.get("revision") is int or state.revision<0 or state.get("choice","") not in ["","preserve","leave","flower"]:return false
 if Catalog.definition(str(state.get("opportunity",""))).is_empty():return false
 if state.get("choice")=="preserve":
  var random_draw=state.get("roll")
  if not random_draw is int or random_draw<0 or random_draw>=ROLL_SCALE:return false
 return true
static func ensure(bed: Dictionary) -> bool:
 if int(bed.get("species",-1))<0 or bed.has("care"):return false
 bed.care=new_cycle(int(bed.species));return true
static func bump(bed: Dictionary) -> void:
 if compatible(bed):bed.care.revision+=1
static func preserved(bed: Dictionary) -> bool:
 return compatible(bed) and not bed.get("flowering",false) and bed.care.choice=="preserve"
static func available(bed: Dictionary) -> bool:
 return compatible(bed) and not bed.get("flowering",false) and bed.care.choice=="" and int(bed.get("stage",0))==int(Catalog.definition(bed.care.opportunity).stage)
static func duration(bed: Dictionary,base: float) -> float:
 return base*(1.0+float(Catalog.definition(bed.care.opportunity).delay_fraction)) if preserved(bed) else base
static func chance(bed: Dictionary,base: float) -> float:
 if not preserved(bed):return base
 var policy:=Catalog.definition(bed.care.opportunity)
 return minf(float(policy.rare_cap),base+float(policy.rare_bonus))
static func choose(bed: Dictionary,choice: String,random_draw: float) -> void:
 if not available(bed) or choice not in ["preserve","leave"]:return
 bed.care.choice=choice
 if choice=="preserve":bed.care.roll=clampi(floori(random_draw*ROLL_SCALE),0,ROLL_SCALE-1)
 bump(bed)
static func roll(bed: Dictionary) -> float:
 return int(bed.care.roll)/float(ROLL_SCALE)
