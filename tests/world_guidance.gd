extends SceneTree
const Guidance=preload("res://ui/gameplay/world_guidance.gd")
const Enemies=preload("res://enemy_catalog.gd")
const Seeds=preload("res://seed_catalog.gd")
var failed:=false
func check(ok: bool, message: String) -> void:
	if not ok:failed=true;printerr("FAIL world guidance: ",message)
func facts() -> Dictionary:
	return {"wild":false,"position":Vector3.ZERO,"fallen":false,"floor":3,"depth":1,"route":0,
		"role":"Solo","party_size":1,"host_port":24576,"cleared":true,"flora_near":false,
		"leader":{"boss_kind":-1,"winding_up":false,"landing":Vector3(20,0,20),"attack_mode":"","position":Vector3(20,0,20),"radius":1.0},
		"scouts":PackedFloat32Array(),"campaign":PackedInt32Array(),"warnings":[],"gate_distance":20.0,"upgrade_open":false,
		"extraction_open":false,"offer_floor":3,"wallet":8,"cache_near":false,"graft_near":false,"improvements":{},
		"garden":{"bed":{},"flowering_unlocked":false,"near_altar":false,"near_gate":false,"near_heart":false,"development":false,
			"deepest_clear":6,"best_extraction":3},"root_access":false,"garden_prompt":"","rescue":{},"pickup":false}
func _initialize():call_deferred("run")
func run() -> void:
	var f:=facts()
	check(Guidance.project(f).prompt=="" and Guidance.project(f).session_text=="Solo  |  1 player(s)\nDeepest clear 6  ·  Best extraction 3","Garden session and empty guidance")
	f.garden.near_gate=true;f.garden.near_altar=true
	check(Guidance.project(f).prompt=="E  Altar","Garden altar precedes the gate")
	f.garden.bed={"species":0,"stage":3,"flowering":false};f.garden.flowering_unlocked=true
	check(Guidance.project(f).prompt=="E  Harvest crafting parts  |  F  Harvest seeds instead","mature bed precedes nearby stations and retains seed alternative")
	f.garden.bed={"species":0,"stage":1,"flowering":true}
	check(Guidance.project(f).prompt==Seeds.NAMES[0]+" · Sprout · Seed crop","seed-crop stage wording comes from the canonical plant name")
	f.garden.bed={"species":-1}
	check(Guidance.project(f).prompt=="E  Choose a seed to plant","empty bed guidance")
	f.garden.bed={};f.garden.near_altar=false;f.garden.near_gate=false;f.garden.near_heart=true;f.garden.development=true
	check(Guidance.project(f).prompt=="E  Heart   ·   B  Garden development","Heart construction hint remains conditional")
	f.wild=true
	check(Guidance.project(f).prompt=="E  Continue","cleared Wilds continuation")
	f.flora_near=true
	check(Guidance.project(f).prompt=="E  Harvest wild specimen","a nearby unpicked specimen takes priority over floor continuation")
	f.cleared=false
	check(Guidance.project(f).prompt=="E  Harvest wild specimen","flora can be harvested before the encounter clears")
	f.leader.winding_up=true;f.leader.position=Vector3.ZERO
	check(Guidance.project(f).prompt=="Dodge out of the marked attack!","nearby flora does not mask a danger warning")
	f.leader.winding_up=false;f.flora_near=false
	check(Guidance.project(f).prompt=="","no beacon or prompt for a distant or locally picked specimen")
	f.cleared=true
	f.upgrade_open=true;f.offer_floor=2
	check(Guidance.project(f).prompt=="Upgrades await at the gate","unclaimed offer at a distant gate")
	f.gate_distance=2.0
	check(Guidance.project(f).prompt=="E  Choose an upgrade","near gate exposes earned choice")
	f.extraction_open=true
	check(Guidance.project(f).prompt=="E  Continue    ·    T  Extract to the Garden" and Guidance.project(f).details=="Extract or continue.\nE  Choose an upgrade   ·   8 Essence","extraction and unclaimed upgrade retain distinct details")
	f.cache_near=true
	check(Guidance.project(f).prompt=="E  Search the abandoned clearing","near cache retains existing prompt priority")
	f.graft_near=true;f.improvements={"used":true,"remaining":0}
	check(Guidance.project(f).prompt=="E  Grafting Altar" and Guidance.project(f).details=="Altar used · 0 remaining","native graft usage is displayed without owning the ledger")
	f.root_access=true
	check(Guidance.project(f).prompt.contains("Returning Root"),"nearby root offers a deposit")
	f.garden_prompt="Inspect living roots"
	check(Guidance.project(f).prompt=="Inspect living roots","Garden override retains priority")
	f.rescue={"name":"Ally","allowed":true,"cost":20};f.pickup=true
	check(Guidance.project(f).prompt=="E  Revive Ally · costs them 20 maximum HP","revival takes priority over pickup and Garden prompts")
	f.rescue.allowed=false
	check(Guidance.project(f).prompt=="This ally has too little maximum health to revive.","unavailable revival stays explicit")
	f.fallen=true
	check(Guidance.project(f).prompt=="Fallen · awaiting revival","fallen guidance suppresses pickup")
	f.rescue={};f.fallen=false
	check(Guidance.project(f).prompt=="E  Pick up item","eligible pickup retains final priority")
	var before:=f.duplicate(true);var rendered:=Guidance.project(f);rendered.prompt="Changed by view"
	check(f==before and Guidance.project(f).prompt=="E  Pick up item","projection has no mutable state and cannot change its facts")
	f=facts();f.wild=true;f.cleared=false;f.leader.winding_up=true;f.leader.position=Vector3.ZERO
	check(Guidance.project(f).prompt=="Dodge out of the marked attack!","leader warning at the player")
	f.leader.attack_mode="vault";f.leader.landing=Vector3(20,0,20)
	check(Guidance.project(f).prompt=="","vault warning uses the committed landing")
	f.leader.boss_kind=22;f.warnings=[{"role":"nursery_exit"}]
	check(Guidance.project(f).prompt=="Stand at a hatch site to block it.","hatch blocking guidance avoids a false leader attack warning")
	f.leader.winding_up=false;f.leader.boss_kind=-1;f.warnings=[]
	f.scouts=PackedFloat32Array([0,0,100,1,0,0,0,0]);f.campaign.resize(20)
	check(Guidance.project(f).prompt=="Dodge out of the marked attack!","living committed scout warning")
	for kind in Enemies.all().size():
		if Enemies.get_kind(kind).role=="chant":
			f.campaign[19]=Enemies.encode(kind,0,0)
			check(Guidance.project(f).prompt=="","native support chant does not become a hit warning")
			break
	f.scouts[2]=0
	check(Guidance.project(f).prompt=="","dead scout cannot warn")
	f.warnings=[{"role":"charge","from":[-2,0,0],"to":[2,0,0],"width":0.3}];f.position=Vector3(0,0,0.6)
	check(Guidance.project(f).prompt=="Dodge out of the marked attack!","charge uses segment distance and existing margin")
	f.position=Vector3(0,0,2)
	check(Guidance.project(f).prompt=="","outside charge corridor has no warning")
	f.role="Host";f.party_size=4
	check(Guidance.project(f).session_text=="Host  ·  4 player(s)\nHosting on UDP 24576","host port remains host-only presentation")
	f.role="Guest"
	check(not Guidance.project(f).session_text.contains("UDP"),"guest label does not claim to host")
	if not failed:print("PASS: pure world guidance, native warning geometry, prompt priorities, Garden crops, checkpoint, graft, Returning Root and revival hints and detached facts")
	quit(1 if failed else 0)
