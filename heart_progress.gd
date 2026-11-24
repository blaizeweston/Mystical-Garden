extends RefCounted
const Batch = preload("res://save_batch.gd")
const Catalog=preload("res://heart_catalog.gd")
const Seeds=preload("res://seed_catalog.gd")
var unlocked: Array=["heart"]
var paid: Array=[]
var progress: Dictionary={}
var natural: Dictionary={}
var infused: Dictionary={}
var material_choice: String=""
var active: String=""
var work: Dictionary={}
const SECONDS_PER_POINT:=120.0
# Partial research joins other Garden saves and checkpoints every 30 work-seconds.
const SAVE_WORK_SECONDS := 30.0
const WILDS_RATE:=3.0
const MIN_DURATION:=60.0
const OFFER_SECONDS:=60.0
const OFFER_PARTS:=2
var spent: int=0
var offered: Array=[]
var recollection_seen:=false

func has(id: String) -> bool:
	return unlocked.has(id)

func serialize() -> Dictionary:
	return {"version":2,"work":work.duplicate(),"material_choice":material_choice,"unlocked":unlocked.duplicate(),"paid":paid.duplicate(),"progress":progress.duplicate(),"natural":natural.duplicate(),"infused":infused.duplicate(),"active":active,"spent":spent,"offered":offered.duplicate(),"recollection_seen":recollection_seen}

func restore(data: Dictionary) -> void:
	work=data.get("work",{}).duplicate()
	unlocked=data.unlocked.duplicate()
	paid=data.paid.duplicate()
	progress=data.progress.duplicate()
	natural=data.natural.duplicate()
	infused=data.infused.duplicate()
	material_choice=str(data.get("material_choice",""))
	active=str(data.active)
	spent=int(data.spent)
	offered=data.offered.duplicate()
	recollection_seen=bool(data.recollection_seen)

func load_state(file: ConfigFile,owner: RefCounted) -> bool:
	var data=file.get_value("heart","state",{})
	owner.needs_research_backup=data is Dictionary and data.get("version",0)==1
	unlocked=["heart"];paid=[];progress={};natural={};infused={};active="";work={};spent=0;offered=[];recollection_seen=false
	var legacy: bool=not (data is Dictionary and data.get("version",0) in [1,2])
	if not legacy:
		for field in ["unlocked","paid"]:
			var values=data.get(field,[])
			if values is Array:
				for id in values:
					if id is String and not Catalog.get_node(id).is_empty() and not get(field).has(id): get(field).append(id)
		for field in ["progress","natural","infused"]:
			var values=data.get(field,{})
			if values is Dictionary:
				for id in values:
					var node:=Catalog.get_node(str(id))
					if not node.is_empty() and values[id] is int:
						get(field)[str(id)]=clampi(values[id],0,int(node.research) if field=="progress" else 1000000)
		var saved_work=data.get("work",{})
		if saved_work is Dictionary:
			for id in saved_work:
				if not Catalog.get_node(str(id)).is_empty() and (saved_work[id] is int or saved_work[id] is float) and is_finite(float(saved_work[id])): work[id]=clampf(float(saved_work[id]),0,duration(str(id)))
		material_choice=str(data.get("material_choice",""))
		active=str(data.get("active",""))
		if not paid.has(active) or has(active) or not Catalog.enabled(active): active=""
		spent=maxi(0,int(data.get("spent",0))) if data.get("spent",0) is int else 0
		# Pre-tree conversions could mark Rift Hook funded without charging for it.
		# Preserve other purchases and refund at most the historical six-point price.
		if data.get("paid") is Array and data.paid.has("rift_hook"):
			var other_costs:=0
			for id in paid: other_costs+=int(Catalog.get_node(id).insight)
			spent-=clampi(spent-other_costs,0,6)
		var gifts=data.get("offered",[])
		if gifts is Array:
			for part in gifts:
				if part is int and owner.Parts.is_monster(part) and not offered.has(part): offered.append(part)
		recollection_seen=data.get("recollection_seen",false)==true
	if legacy:
		for count in range(4,owner.plots.size()+1): unlock_direct("plot_%d"%count)
		# Preserve an already-earned legacy finale and completed endings.
		var old_discovery: bool=file.get_value("garden","rift_hook_discovered",false)==true
		var restored: bool=owner.flowering_unlocked and old_discovery and owner.veilcap_discovered and owner.knowledge>=owner.Campaign.FULL_KNOWLEDGE and owner.campaign.memories_complete()
		if restored or owner.campaign.ending!=owner.Campaign.UNFINISHED:
			for id in Catalog.required_core(): unlock_direct(id)
			for id in ["memory_grove","memory_mire","memory_hollow","perfect_recollection"]: unlock_direct(id)
			recollection_seen=owner.campaign.ending!=owner.Campaign.UNFINISHED
	sync_legacy(owner)
	return legacy

func unlock_direct(id: String) -> void:
	if not has(id) and not Catalog.get_node(id).is_empty(): unlocked.append(id)

func sync_legacy(owner: RefCounted) -> void:
	if not Catalog.enabled(active): active=""
	for count in range(4,owner.plots.size()+1): unlock_direct("plot_%d"%count)
	if owner.flowering_unlocked: unlock_direct("flowering")
	if owner.studying_flowering and not has("flowering") and not paid.has("flowering"):
		paid.append("flowering")
		progress.flowering=owner.research_points
		natural.flowering=owner.research_points
		if active.is_empty(): active="flowering"
	for id in progress:
		if not work.has(id): work[id]=float(progress[id])*SECONDS_PER_POINT
	if has(active): active=""
	sync_memories(owner)
	mirror(owner)

func mirror(owner: RefCounted) -> void:
	owner.flowering_unlocked=owner.flowering_unlocked or has("flowering")
	owner.studying_flowering=active=="flowering" and not has("flowering")
	owner.research_points=owner.FLOWERING_COST if has("flowering") else int(progress.get("flowering",0))

func sync_memories(owner: RefCounted) -> void:
	if not has("living_archive"): return
	for node in Catalog.DEFINITIONS:
		if node.has("memory") and int(owner.campaign.memories[int(node.memory)])>=int(owner.Campaign.MEMORY_REQUIREMENTS[int(node.memory)]):
			unlock_direct(node.id)

func available_insight(owner: RefCounted) -> int:
	return maxi(0,int(owner.knowledge)-spent)

func total_materials(owner: RefCounted) -> int:
	var total:=0
	for count in owner.parts: total+=int(count)
	return total

func requirements(owner: RefCounted,id: String) -> String:
	var node:=Catalog.get_node(id)
	if node.is_empty(): return "Unknown memory."
	if not Catalog.enabled(id): return "The final ending is deferred. Other Garden research remains available."
	if has(id): return "Already restored."
	if node.has("memory"): return "Restore this memory through repeated guardian expeditions."
	for parent in node.parents:
		if not has(parent): return "Requires "+str(Catalog.get_node(parent).name)+"."
	if owner.knowledge<int(node.knowledge): return "Requires %d lifetime Knowledge."%int(node.knowledge)
	if node.get("fact","")=="offshoots" and (owner.campaign.offshoots.has(owner.Campaign.PENDING) or owner.campaign.offshoots.has(owner.Campaign.DORMANT)): return "Resolve pending offshoot choices in Heart → Garden care."
	if not paid.has(id):
		if available_insight(owner)<int(node.insight): return "Need %d available Knowledge."%int(node.insight)
	return ""

func material_plan(owner: RefCounted,amount: int) -> Dictionary:
	return plan_materials(owner.parts,material_choice,amount)

static func plan_materials(parts: Array,choice: String,amount: int) -> Dictionary:
	var plan: Dictionary={};var order: Array=[]
	for i in parts.size():
		if choice.is_empty() or str(Seeds.DEFINITIONS[i].id)==choice: order.append(i)
	order.sort_custom(func(a,b): return int(Seeds.DEFINITIONS[a].tier)<int(Seeds.DEFINITIONS[b].tier) if int(Seeds.DEFINITIONS[a].tier)!=int(Seeds.DEFINITIONS[b].tier) else a<b)
	var left:=amount
	for i in order:
		var take:=mini(maxi(0,int(parts[i])),left)
		if take>0: plan[str(Seeds.DEFINITIONS[i].id)]=take;left-=take
	return {"parts":plan,"missing":left}
func spend_materials(owner: RefCounted,amount: int) -> bool:
	var plan:=material_plan(owner,amount)
	if int(plan.missing)>0: return false
	for id in plan.parts: owner.parts[owner.Seeds.index_of(id)]-=int(plan.parts[id])
	return true
func capture(owner: RefCounted) -> Dictionary:
	var flags: Dictionary={}
	for field in ["knowledge","flowering_unlocked","studying_flowering","research_points"]:
		flags[field]=owner.get(field)
	return {"state":serialize(),"parts":owner.parts.duplicate(),"plots":owner.plots.duplicate(true),"flags":flags}

func rollback(owner: RefCounted,before: Dictionary) -> void:
	restore(before.state)
	owner.parts.assign(before.parts)
	owner.plots.assign(before.plots)
	for field in before.flags: owner.set(field,before.flags[field])

func start(owner: RefCounted,id: String) -> String:
	sync_legacy(owner)
	var error:=requirements(owner,id)
	if not error.is_empty(): return error
	var before:=capture(owner)
	var node:=Catalog.get_node(id)
	if not paid.has(id):
		spent+=int(node.insight)
		paid.append(id)
	active=id
	mirror(owner)
	if not Batch.guarded_active() and owner.save_garden()!=OK:
		rollback(owner,before)
		return "Could not save the upgrade. Knowledge was returned."
	return "%s restored."%node.name if has(id) else "Researching %s. It advances naturally, three times faster in the Wilds. Plant offerings speed it up; switching focus preserves progress."%node.name

func complete(owner: RefCounted,id: String) -> void:
	var node:=Catalog.get_node(id)
	if node.is_empty(): return
	unlock_direct(id)
	progress[id]=int(node.research)
	work[id]=duration(id)
	if active==id: active=""
	if node.has("plots") and not owner.get("player_placed_beds"):
		while owner.plots.size()<int(node.plots): owner.plots.append(owner.empty_plot())
	mirror(owner)
	sync_memories(owner)

func duration(id: String) -> float:
	return maxf(MIN_DURATION,float(Catalog.get_node(id).get("research",0))*SECONDS_PER_POINT)

func add_work(owner: RefCounted,seconds: float) -> String:
	sync_legacy(owner)
	if active.is_empty() or seconds<=0:return ""
	var id=active;var node=Catalog.get_node(id)
	work[id]=minf(duration(id),float(work.get(id,0))+seconds)
	progress[id]=mini(int(node.research),floori(float(work[id])/SECONDS_PER_POINT))
	if float(work[id])>=duration(id):
		complete(owner,id);return "%s restored."%node.name
	mirror(owner)
	return ""

func advance(owner: RefCounted,points: int) -> String:
	sync_legacy(owner)
	if active.is_empty() or points<=0:return ""
	natural[active]=int(natural.get(active,0))+points
	return add_work(owner,points*SECONDS_PER_POINT)

static func progression_work(seconds: float, in_wilds: bool) -> float:
	return seconds * (WILDS_RATE if in_wilds else 1.0)

func checkpoint_due(seconds: float,in_wilds: bool) -> bool:
	if active.is_empty() or seconds <= 0: return false
	var current := float(work.get(active, 0.0))
	var next := current + progression_work(seconds, in_wilds)
	# Floor settlement writes all partial work. During combat, only an actual
	# unlock needs its own transaction.
	return next >= duration(active) or (not in_wilds and floori(current / SAVE_WORK_SECONDS) != floori(next / SAVE_WORK_SECONDS))

func tick(owner: RefCounted,seconds: float,in_wilds: bool) -> String:
	if active.is_empty() or seconds<=0:return ""
	if Batch.guarded_active() or not checkpoint_due(seconds, in_wilds):
		return add_work(owner, progression_work(seconds, in_wilds))
	var before=capture(owner)
	var message=add_work(owner,progression_work(seconds,in_wilds))
	if owner.save_garden()!=OK:
		rollback(owner,before);return "Research could not be saved; progress will retry."
	return message

func infuse(owner: RefCounted) -> String:
	sync_legacy(owner)
	if active.is_empty():return "Choose a research project in the Heart tree."
	var id=active;var node=Catalog.get_node(id);var before=capture(owner)
	if not spend_materials(owner,OFFER_PARTS):return "Need two shared plant parts in the selected offering."
	infused[id]=int(infused.get(id,0))+1
	var message=add_work(owner,OFFER_SECONDS*(2.0 if has("infusion") else 1.0))
	if not Batch.guarded_active() and owner.save_garden()!=OK:
		rollback(owner,before);return "Could not save the offering. Materials were returned."
	return message if not message.is_empty() else "%s: %ds remaining."%[node.name,ceili(duration(id)-float(work.get(id,0)))]

func clearing_bonus() -> int:
	var result:=0
	for id in ["clearing_1","clearing_2","clearing_3"]:
		result+=int(has(id))
	return result

func growth_multiplier() -> float:
	return 1.4 if has("nursery") else 1.2 if has("irrigation") else 1.0

# Recollection milestones use whole completed memories.
@warning_ignore_start("integer_division")
func phase(owner: RefCounted) -> int:
	if has("perfect_recollection"): return 5 if owner.Campaign.LEGACY_ENDING_ENABLED else 4
	var memories:=0
	var total:=0
	for count in owner.campaign.memories: memories+=int(count)
	for count in owner.Campaign.MEMORY_REQUIREMENTS: total+=int(count)
	if has("living_archive") and memories>=total/2: return 4
	if unlocked.size()>=8 and owner.knowledge>=50: return 3
	if unlocked.size()>=4 and owner.knowledge>=20: return 2
	if has("flowering") or owner.plots.size()>3 or owner.knowledge>=8: return 1
	return 0

@warning_ignore_restore("integer_division")
func snapshot(owner: RefCounted) -> Dictionary:
	sync_legacy(owner)
	var result:=serialize()
	result["phase"]=phase(owner)
	result["insight"]=available_insight(owner)
	result["knowledge_available"]=available_insight(owner)
	result["remaining_seconds"]=maxf(0,duration(active)-float(work.get(active,0))) if not active.is_empty() else 0.0
	result["wilds_rate"]=WILDS_RATE
	result["seconds_per_point"]=SECONDS_PER_POINT
	result["minimum_seconds"]=MIN_DURATION
	result["offering_seconds"]=OFFER_SECONDS*(2.0 if has("infusion") else 1.0)
	result["offering_cost"]=OFFER_PARTS
	result["clearing"]=clearing_bonus()
	return result

func matches_plan(proposed,expected: Dictionary) -> bool:
	if not proposed is Dictionary or proposed.size()!=expected.size(): return false
	for id in expected:
		if not proposed.has(id): return false
		var amount=proposed[id]
		if not (amount is int or amount is float) or not is_finite(float(amount)): return false
		if float(amount)!=float(int(amount)) or int(amount)!=int(expected[id]): return false
	return true
