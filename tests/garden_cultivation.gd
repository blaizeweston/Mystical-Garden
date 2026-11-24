extends SceneTree
## Pure cultivation contracts: no Game, persistence owner or random generator.
const Rules=preload("res://garden_cultivation.gd")
const Care=preload("res://garden_crop_state.gd")
const Growth=preload("res://cultivation_growth.gd")
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
var failed:=false

func check(ok:bool,message:String)->void:
	if not ok:failed=true;printerr("FAIL cultivation rules: ",message)

func _initialize():
	for pair in [[0,.05],[5,.25],[25,.35],[45,.45],[9999,.45]]:
		check(is_equal_approx(Rules.rare_harvest_chance(int(pair[0])),float(pair[1])),"unchanged native rare chance "+str(pair[0]))
	check(Rules.familiarity_after(2,1)==3 and Rules.familiarity_after(2,2)==4 and Rules.familiarity_after(9999,3)==9999,"native and nursery familiarity preserve their cap")
	for species in Seeds.DEFINITIONS.size():
		var care:=Care.new_cycle(species)
		var bed:=Rules.planted_bed(species,care)
		care.revision=99
		check(bed.care.revision==0 and bed.growth_rules==Growth.VERSION and bed.growth_base==Seeds.DEFINITIONS[species].grow_seconds,"new bed uses canonical definitions and detached care "+str(species))
		check(Rules.harvest_yield(bed,0,0).is_empty(),"immature crop pays nothing")
		bed.stage=3;var before:=bed.duplicate(true)
		var ordinary:=Rules.harvest_yield(bed,0,.99)
		var refined:=Rules.harvest_yield(bed,0,0.0)
		check(ordinary.parts==1 and ordinary.seeds==0 and ordinary.rare_part==0,"ordinary harvest "+str(species))
		check(refined.rare_part==Parts.rare_part(species) and refined.parts==1,"one native refined outcome "+str(species))
		check(bed==before,"outcome queries do not clear a bed or advance care")
		bed.flowering=true
		var seed_yield:=Rules.harvest_yield(bed,9999,0.0)
		check(seed_yield.seeds==2 and seed_yield.parts==0 and seed_yield.rare_part==0,"Flowering pays two seeds without parts "+str(species))
	var bed:=Rules.planted_bed(0,Care.new_cycle(0));bed.stage=2
	var request={"point":"bed_1","cycle":bed.care.cycle,"revision":0,"stage":2,"action":"preserve_bud"}
	var initial:=bed.duplicate(true)
	check(Rules.care_request(request,true,bed,true,true)=={"operation":"choose","choice":"preserve"},"care has an explicit accepted outcome")
	check(bed==initial,"admission never mutates crop state")
	var stale:=request.duplicate();stale.cycle="old"
	check(Rules.care_request(stale,true,bed,true,true).operation=="reject","old crop cycle is refused")
	stale=request.duplicate();stale.revision=1
	check(Rules.care_request(stale,true,bed,true,true).operation=="reject","wrong revision is refused")
	stale=request.duplicate();stale.point="bed_01"
	check(Rules.care_request(stale,true,bed,true,true).operation=="reject","noncanonical bed identity is refused")
	check(Rules.care_request(request,false,bed,true,true).operation=="reject","ineligible recipient cannot tend")
	Care.choose(bed,"preserve",.15)
	check(Rules.care_request(request,true,bed,true,true)=={"operation":"noop","revision":1},"duplicate preservation is idempotent before revision rejection")
	bed.stage=3
	check(Rules.harvest_yield(bed,0,.99).rare_part==Parts.rare_part(0),"frozen care roll wins over the supplied ordinary roll")
	var shown:=Rules.bed_projection(0,bed,0,{"garden":1.0,"wild":2.0,"current":2.0},true,true)
	check(not shown.has("care") and not shown.has("roll") and shown.preserved and is_equal_approx(shown.chance,.20),"preview conceals the frozen outcome and preserves its contribution")
	bed=Rules.planted_bed(0,Care.new_cycle(0));bed.stage=2
	request={"point":"bed_1","cycle":bed.care.cycle,"revision":0,"stage":2,"action":"water_crop"}
	check(Rules.care_request(request,true,bed,false,true).operation=="reject","water availability is independent of actor access")
	check(Rules.care_request(request,true,bed,true,false).operation=="reject","a vessel is required")
	check(Rules.care_request(request,true,bed,true,true).operation=="water","valid watering is admitted")
	Growth.water(bed)
	check(Rules.care_request(request,true,bed,false,false)=={"operation":"noop","revision":1},"duplicate watering cannot consume another vessel")
	shown=Rules.bed_projection(0,bed,0,{"garden":1.25,"wild":2.5,"current":2.5},true,false)
	check(shown.watered and not shown.water_available and is_equal_approx(shown.growth_rate,2.5) and is_equal_approx(shown.garden_remaining/2,shown.wild_remaining),"the preview uses supplied canonical growth rates")
	if not failed:print("PASS: pure cultivation admission, all species harvests, exact yields, rarity caps, frozen rolls, cycle/revision idempotence, watering and concealed projections")
	quit(1 if failed else 0)
