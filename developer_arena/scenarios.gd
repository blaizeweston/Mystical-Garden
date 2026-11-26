extends "res://developer_arena/named_files.gd"
## A scenario is a recipe for a clean practice world. It contains no runtime actors.
const Plan = preload("res://developer_arena/build_plan.gd")
const Encounters = preload("res://developer_arena/practice_encounter.gd")
const Field = preload("res://battlefield.gd")
const Campaign = preload("res://campaign.gd")
const FORMAT := 1
const CONTROL_DEFAULTS := {"invincible":false,"no_cooldowns":false,"movement":true,"attacks":true}
const FOCUS_CASES := ["Vanguard practice", "Rootkeeper practice", "Bastion practice", "Thornbinder practice", "Bloomcaller practice", "Silkwarden practice", "Wildstalker practice", "Snarekeeper practice", "Wayfarer practice", "Blood Harvester practice", "Veilwalker practice", "Gravekeeper practice", "Omenreader practice", "Leykeeper practice", "Lifekeeper practice"]
# Species is equipped in all three affinity sockets. Every acquisition is replayed by Plan.
const BUILD_CASES := {
	"Bloodletting practice":["thorn_bloom",["bloodletting"]],
	"Avalanche practice":["frostbell",["avalanche","shatterwave"]],
	"Wildfire practice":["ember_fern",["wildfire"]],
	"Monsoon practice":["dewcap",["monsoon"]],
	"Splinterburst practice":["ironroot",["splinterburst"]],
	"Harvest practice":["lantern_moss",["harvest"]],
	"Conductor practice":["storm_reed",["conductor"]],
	"Mirrorstep practice":["ghost_fern",["mirrorstep"]],
	"Wraithcast practice":["ghost_fern",["wraithcast"]],
	"Singularity practice":["void_willow",["singularity","rift_shear"]],
	"Dew Shelter practice":["dewcap",["dew_shelter"]],
	"Echoing Growth practice":["empty",["echoing_growth"]],
	"Graft responses":["empty",["strike","silken_link","prismatic_echo","chorus_pulse"]]
}
static var STARTERS:Array= ["Stationary target","Sustained damage","Pilgrim cluster","Area attack ring","Spirit echoes"]+FOCUS_CASES+BUILD_CASES.keys()
var catalog_digest := ""

func _prefix() -> String: return "scenario-"
func _dir() -> String:
	if not preload("res://developer_mode.gd").authorized_build() or not is_instance_valid(world) or not world.has_method("is_practice_world") or not world.is_practice_world(): return ""
	var tuning: String=world.developer_tuning.directory(world)
	return "" if tuning.is_empty() else tuning.get_base_dir().path_join("scenarios")

func fingerprint() -> String:
	if catalog_digest.is_empty():
		var data := [Plan.Classes.DEFINITIONS,Plan.Parts.DEFINITIONS,Plan.Catalog.DEFINITIONS,Plan.Grafts.ADAPTATIONS,
			Plan.Grafts.REINFORCEMENTS,Encounters.Catalog.all(),Encounters.FORMATIONS,Encounters.Roster.Config.MAX_SCOUTS]
		for index in Plan.Classes.DEFINITIONS.size(): data.append(Plan.Classes.connected_tree(index).nodes)
		for path in ["res://developer_arena/build_plan.gd","res://developer_arena/practice_encounter.gd","res://card_eligibility.gd","res://plant_affinities.gd","res://battlefield.gd"]:
			if FileAccess.file_exists(path): data.append(FileAccess.get_sha256(path))
		catalog_digest=JSON.stringify(data).sha256_text()
	return catalog_digest

static func encode_build(spec: Dictionary) -> Dictionary:
	var frame: Dictionary=Plan.Classes.DEFINITIONS[spec.frame]
	var parts := []
	for index in spec.parts: parts.append(Plan.Parts.DEFINITIONS[index].id)
	return {"slot":"P1","class_id":frame.id,"weapon_id":frame.weapons[spec.weapon].id,"path":spec.path.duplicate(),
		"parts":parts,"upgrades":spec.upgrades.duplicate(true)}

static func decode_build(owner: Node, row: Dictionary) -> Dictionary:
	if not row.get("parts") is Array or row.parts.size()!=3 or not row.get("path") is Array or not row.get("upgrades") is Array:
		return {"error":"Invalid component, progression or upgrade list."}
	var frames: Array=Plan.Classes.DEFINITIONS
	var frame:=frames.find_custom(func(d):return d.id==row.get("class_id"))
	if frame<0: return {"error":"Unavailable class: "+str(row.get("class_id"))}
	var weapon: int=frames[frame].weapons.find_custom(func(d):return d.id==row.get("weapon_id"))
	if weapon<0: return {"error":"Unavailable weapon for this class: "+str(row.get("weapon_id"))}
	var parts := []
	for id in row.parts:
		if not id is String or Plan.Parts.index_of(id)<0: return {"error":"Unavailable component: "+str(id)}
		parts.append(Plan.Parts.index_of(id))
	if row.upgrades.size()>256: return {"error":"Invalid upgrade list length."}
	var spec:={"frame":frame,"weapon":weapon,"parts":parts,"path":row.path.duplicate(),"upgrades":row.upgrades.duplicate(true)}
	var checked:=Plan.plan(owner,spec)
	if not checked.error.is_empty(): return {"error":checked.error}
	if not checked.removed.is_empty():
		var reasons:=PackedStringArray()
		for item in checked.removed: reasons.append("%s — %s"%[item.entry.id,item.reason])
		return {"error":"Unavailable upgrades: "+"; ".join(reasons)}
	spec.upgrades=checked.accepted.duplicate(true)
	return {"build":spec,"error":""}

static func vector_pair(v: Vector3) -> Array: return [v.x,v.z]
static func numeric(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func integer(v: Variant,low: int,high: int) -> bool:
	return numeric(v) and v>=low and v<=high and v==floor(v)

func current(title: String, description: String, preferred: String, seed: int, depth: int) -> Dictionary:
	if _dir().is_empty(): return {}
	var encounter := {}
	var selection: Dictionary=world.encounter_selection
	if not selection.is_empty():
		encounter={"type":selection.type,"enemy":("training_target" if selection.type=="Target" else Encounters.Catalog.get_kind(selection.kind).id),
			"count":selection.count,"formation":selection.formation,"endless":selection.endless}
		if seed==world.session.terrain_seed and depth==world.session.encounter_depth and selection.type not in ["Elite","Boss"]:
			encounter.origin=vector_pair(selection.origin)
			encounter.facing=vector_pair(selection.facing)
	return {"format":FORMAT,"name":title,"description":description,"environment":"testing_arena","terrain":{"seed":seed,"depth":depth},
		"participants":[encode_build(world.session.build)],"encounter":encounter,"controls":world.session.settings.duplicate(),
		"preferred_preset":preferred,"fingerprint":fingerprint(),"commit":git_commit()}

func builtin(title: String) -> Dictionary:
	if _dir().is_empty() or not title in STARTERS: return {}
	var ix:=STARTERS.find(title)
	var defs:=["One finite target for hit confirmation.","One inexhaustible target for sustained attacks.","Three Rootbound Pilgrims in a cluster.","Six Rootbound Pilgrims around the player.","Spirit Ranger with Mirrorstep, Wraithcast and Lingering Echoes."]
	var row:={"slot":"P1","class_id":"warden","weapon_id":"0_0","parts":["empty","empty","empty"],"path":[],"upgrades":[]}
	if ix==4:
		row={"slot":"P1","class_id":"ranger","weapon_id":"2_0","parts":["plant:ghost_fern","rare:mirror_mint","plant:ghost_fern"],"path":["wildstalker"],
			"upgrades":[{"id":"mirrorstep","rarity":""},{"id":"wraithcast","rarity":""},{"id":"lingering_echoes","rarity":"Rare"}]}
	if title in FOCUS_CASES:
		var focus_index:=FOCUS_CASES.find(title)
		@warning_ignore("integer_division")
		var frame:Dictionary=Plan.Classes.DEFINITIONS[focus_index/3]
		row.class_id=frame.id
		row.weapon_id=frame.weapons[0].id
		row.path=[title.trim_suffix(" practice").to_snake_case().replace(" ","_")]
	var group_case:=title in FOCUS_CASES or title in BUILD_CASES
	if title in BUILD_CASES:
		var setup:Array=BUILD_CASES[title]
		row.path=["vanguard"]
		row.parts.fill("empty" if setup[0]=="empty" else "plant:"+setup[0])
		if title=="Echoing Growth practice":
			row.class_id="weaver"
			row.weapon_id=Plan.Classes.DEFINITIONS[1].weapons[0].id
			row.path=["bloomcaller"]
		for id:String in setup[1]:
			row.upgrades.append({"id":id,"rarity":"Rare" if id in ["shatterwave","rift_shear"] else ""})
	var target:=ix in [0,1,4] or group_case
	var description:String
	if title in FOCUS_CASES:
		description="Use Q and R against three lasting targets."
	elif title=="Echoing Growth practice":
		description="Place Cultivate Bloom beneath the finite targets, then hit them with Spore Nova."
	elif title in BUILD_CASES:
		description="Test "+", ".join(BUILD_CASES[title][1])+" against three lasting targets."
	else:
		description=defs[ix]
	return {"format":FORMAT,"name":title,"description":description,"environment":"testing_arena","terrain":{"seed":0,"depth":1},
		"participants":[row],"encounter":{"type":"Target" if target else "Enemy","enemy":"training_target" if target else "rootbound",
		"count":3 if group_case else 1 if target else 3 if ix==2 else 6,"formation":"Cluster" if group_case else "Single" if target else "Cluster" if ix==2 else "Ring","endless":ix in [1,4] or (group_case and title!="Echoing Growth practice")},
		"controls":CONTROL_DEFAULTS.duplicate(),"preferred_preset":"","fingerprint":fingerprint(),"commit":""}

func get_record(title: String) -> Dictionary:
	return builtin(title) if title in STARTERS else read(title)

func inspect(record: Dictionary) -> Dictionary:
	if _dir().is_empty(): return {"error":"An authorized practice session is required."}
	if record.get("format")!=FORMAT or record.get("environment")!="testing_arena": return {"error":"Unsupported scenario format or environment."}
	if not record.get("name") is String or not safe_name(record.name) or not record.get("description") is String or record.description.length()>512 or not record.get("preferred_preset") is String or (not record.preferred_preset.is_empty() and not safe_name(record.preferred_preset)):
		return {"error":"Invalid scenario description, name or preset reference."}
	if not record.get("fingerprint") is String or not record.get("commit") is String: return {"error":"Scenario provenance is missing."}
	var terrain: Variant=record.get("terrain")
	if not terrain is Dictionary or not integer(terrain.get("seed"),0,2147483647) or not integer(terrain.get("depth"),1,600):
		return {"error":"Practice terrain needs a seed from 0 to 2147483647 and a depth from 1 to 600."}
	if not record.get("controls") is Dictionary or record.controls.size()!=CONTROL_DEFAULTS.size(): return {"error":"Unsupported practice controls."}
	for key in CONTROL_DEFAULTS:
		if not record.controls.get(key) is bool: return {"error":"Invalid control: "+key}
	if not record.get("participants") is Array or record.participants.size()!=1 or not record.participants[0] is Dictionary or record.participants[0].get("slot")!="P1":
		return {"error":"Solo practice requires the P1 participant configuration."}
	var result:=decode_build(world,record.participants[0])
	if not result.error.is_empty(): return result
	var selection: Variant=record.get("encounter")
	if not selection is Dictionary: return {"error":"Missing encounter configuration."}
	var info:={"error":"","record":record.duplicate(true),"build":result.build,"encounter":{},"changed":record.fingerprint!=fingerprint()}
	if selection.is_empty(): return info
	var type: Variant=selection.get("type")
	var kind:=0 if type=="Target" and selection.get("enemy")=="training_target" else Encounters.Catalog.all().find_custom(func(d):return d.id==selection.get("enemy"))
	if not type is String or (type=="Target" and selection.get("enemy")!="training_target") or kind<0 or not integer(selection.get("count"),1,Encounters.Roster.Config.MAX_SCOUTS) or not selection.get("formation") is String or not selection.get("endless") is bool:
		return {"error":"Unavailable enemy, formation or target configuration."}
	var err:=Encounters.selection_error(type,kind,int(selection.count),selection.formation)
	if not err.is_empty(): return {"error":err}
	info.encounter={"kind":kind,"type":type,"count":int(selection.count),"formation":selection.formation,"endless":selection.endless}
	if type in ["Boss","Elite"]: return info
	var field:=Field.new()
	@warning_ignore("integer_division")
	var route: int=((int(terrain.depth)-1)/world.ROUTE_ROOMS)%Campaign.BIOME_COUNT
	field.configure(route,1+(int(terrain.depth)-1)%world.ROUTE_ROOMS,int(terrain.seed))
	var origin: Vector3=Vector3.ZERO if terrain.seed==0 else field.entry
	var facing:=Vector3.FORWARD
	for key in ["origin","facing"]:
		if not selection.has(key): continue
		var coords: Variant=selection[key]
		if not coords is Array or coords.size()!=2 or not numeric(coords[0]) or not numeric(coords[1]): return {"error":"Invalid spawn "+key}
		var v:=Vector3(coords[0],0,coords[1])
		if key=="origin": origin=v
		else: facing=v.normalized()
	if facing.is_zero_approx() or not field.can_spawn(origin) or Encounters.formation_points(field,origin,facing,int(selection.count),selection.formation).is_empty():
		return {"error":"The saved formation does not fit on reachable terrain."}
	info.encounter.origin=origin
	info.encounter.facing=facing
	return info

func start(record: Dictionary, confirm_changed := false) -> String:
	var plan:=inspect(record)
	if not plan.error.is_empty(): return plan.error
	if plan.changed and not confirm_changed: return "Content has changed. Review the validated scenario before loading."
	if world.session.replacing: return "A practice reset is already in progress."
	world.session.next_scenario=plan
	world.session.rebuild("scenario")
	return ""

func save_record(record: Dictionary) -> String:
	if _dir().is_empty() or record.get("name","") in STARTERS: return "Choose an unused personal scenario name."
	var result:=inspect(record)
	return result.error if not result.error.is_empty() else _new_file(_dir(),record)

func copy_scenario(source: String,target: String,rename: bool) -> String:
	if _dir().is_empty() or target in STARTERS: return "Choose an unused personal scenario name."
	if source not in STARTERS: return copy_named(source,target,rename)
	if rename: return "Built-in scenarios can be duplicated."
	var copy:=builtin(source)
	copy.name=target
	return _new_file(_dir(),copy)
