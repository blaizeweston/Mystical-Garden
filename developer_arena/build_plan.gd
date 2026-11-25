extends RefCounted
## Rebuild on detached ledgers. Only the owning practice world installs the result.
const Classes=preload("res://class_catalog.gd")
const Character=preload("res://character_profile.gd")
const Parts=preload("res://weapon_parts.gd")
const Affinities=preload("res://affinity_build.gd")
const Cards=preload("res://affinity_card_ledger.gd")
const Catalog=Cards.Catalog
const Grafts=preload("res://expedition_grafts.gd")

static func initial(actor: Dictionary) -> Dictionary:
	var frame:=int(actor.frame)
	return {"frame":frame,"weapon":int(actor.weapon_kind),"parts":[actor.prepared,actor.prepared_secondary,actor.prepared_catalyst],
		"path":Classes.connected_tree(frame).path(actor.character).duplicate(),"upgrades":[]}

static func title(id: String) -> String:
	if Catalog.DEFINITIONS.has(id): return Catalog.DEFINITIONS[id].title
	return Grafts.ADAPTATIONS.get(id,Grafts.REINFORCEMENTS.get(id,{})).get("name",id)

static func plan(world: Node, spec: Dictionary) -> Dictionary:
	if not world.is_practice_world(): return {"error":"Developer session required."}
	if not spec.get("frame") is int or not spec.get("weapon") is int: return {"error":"Select a class and weapon."}
	var frame: int=spec.get("frame",-1)
	var weapon: int=spec.get("weapon",-1)
	if frame<0 or frame>=Classes.DEFINITIONS.size() or weapon<0 or weapon>=Classes.DEFINITIONS[frame].weapons.size():
		return {"error":"Select a weapon supported by this class."}
	if not spec.get("parts") is Array or spec.parts.size()!=3: return {"error":"Select three component slots."}
	for i in 3:
		var part: Variant=spec.parts[i]
		if not part is int or (part!=0 and (not Parts.is_plant(part) or not Affinities.slot(Affinities.SLOTS[i],part).executable)):
			return {"error":"Invalid plant component."}
	if not spec.get("path") is Array or not spec.get("upgrades") is Array: return {"error":"Invalid build."}
	for item in spec.upgrades:
		if not item is Dictionary or not item.get("id") is String or not item.get("rarity","") is String: return {"error":"Invalid upgrade selection."}
	var profile:=Character.blank()
	var tree:=Classes.connected_tree(frame)
	profile.xp[frame]=tree.XP_THRESHOLDS.back()
	profile[tree.profile_key]=tree.state(spec.path.duplicate())
	profile.active_class=frame
	profile.loadouts[frame]={"weapon":weapon,"parts":spec.parts.duplicate()}
	if not tree.valid(profile): return {"error":"Select one connected node per tier, beginning with a focus."}
	var state:={"error":"","profile":profile,"cards":Cards.Ledger.new(),"grafts":Grafts.Ledger.new(world.participation.epoch()),"accepted":[],"removed":[]}
	var waiting: Array=spec.upgrades.duplicate(true)
	while not waiting.is_empty():
		var retry: Array=[]
		var reasons: Array=[]
		for entry in waiting:
			var quote:=acquire(world,spec,state,entry)
			if quote.has("ledger"):
				state[quote.owner]=quote.ledger
				state.accepted.append(entry)
			else:
				retry.append(entry)
				reasons.append({"entry":entry,"reason":quote.message})
		if retry.size()==waiting.size():
			state.removed=reasons
			break
		waiting=retry
	return state

static func acquire(world: Node,spec: Dictionary,state: Dictionary,entry: Dictionary) -> Dictionary:
	if not world.is_practice_world(): return {"message":"Developer session required."}
	var id: String=entry.get("id","")
	var grade: String=entry.get("rarity","")
	var build=world.combat_builds.resolve(spec.frame,spec.weapon,spec.parts,Classes.combat_profile(state.profile,spec.frame),state.cards,state.grafts,true)
	var sequence: int=state.accepted.size()+1
	if Catalog.DEFINITIONS.has(id):
		if state.cards.exhausted(): return {"message":"Expedition card capacity reached."}
		var stats: Dictionary=build.weapon_base_stats()
		var option: Dictionary=state.cards.option_for_grade(id,grade,stats,world.DODGE_COOLDOWN_MS)
		if option.is_empty(): return {"message":"Unsupported rarity for this card."}
		var reason: String=state.cards.option_refusal(option,stats,world.DODGE_COOLDOWN_MS)
		if not reason.is_empty(): return {"message":reason}
		var offer:={"floor":sequence,"revision":sequence,"rerolls":0,"cards":[option]}
		var selecting:=Cards.Ledger.new(state.cards.copies(),offer,state.cards.completed_floor())
		var accepted:=selecting.plan_choice(sequence,sequence,"0",sequence+1,0,0,stats,world.DODGE_COOLDOWN_MS)
		if accepted.has("ledger"): return {"owner":"cards","ledger":accepted.ledger}
		return {"message":accepted.get("message","Card refused.")}
	if not grade.is_empty() or (not Grafts.REINFORCEMENTS.has(id) and not Grafts.ADAPTATIONS.has(id)): return {"message":"Unknown graft or adaptation."}
	var item: String=Grafts.ADAPTATIONS.get(id,{}).get("item","monster_0")
	var supply:=Parts.empty_counts()
	var part:=Grafts.Ledger._material_part(item,not Grafts.ADAPTATIONS.has(id))
	if part<=0: return {"message":"Required trophy unavailable."}
	supply[part]=Grafts.PLAYTEST.cost
	var request: Dictionary=state.grafts.details(sequence)
	request.id=id
	request.item=item
	var accepted: Dictionary=state.grafts.plan_purchase(request,sequence,supply,build.graft_value_resolver(world.MAX_HEALTH,0,0))
	if accepted.has("ledger"): return {"owner":"grafts","ledger":accepted.ledger}
	return {"message":accepted.get("message","Graft refused.")}
