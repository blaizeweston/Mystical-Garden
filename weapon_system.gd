extends RefCounted
const Parts=preload("res://weapon_parts.gd")
const Traits=preload("res://combat_traits.gd")
const Classes=preload("res://class_catalog.gd")
const Preview=preload("res://combat_balance_preview.gd")
const MONSTER_CARGO_LIMIT := 6
const SLOT_NAMES := ["Core","Form","Catalyst","Monster graft"]
# Ordered first matching tag selects a slot rule. New rules require no combat edits
# when they use an existing effect or target pattern.
const RULES := [
	{"brace":{"stagger":50},"mark":{"reach":0.15},"echo":{"reach":0.15},"grave":{"death_charge":1},"tide":{"pool_radius":0.3},"hush":{"recovery":200},"dream":{"dodge_cooldown":80},"link":{"link_damage":0.5},"frost":{"shatter_damage":1},"piercing":{"reach":0.25},"vital":{"recovery":150},"arcane":{"windup_damage":1},"fire":{"damage":0.5,"cooldown":-80},"water":{"recovery":250},"blood":{"heal_on_kill":1},"spirit":{"reach":0.3},"storm":{"knockback":0.25},"lunar":{"windup_damage":1},"radiant":{"damage":0.5},"void":{"pull":0.4},"ancient":{"stagger":60},"wood":{"knockback":0.25}},
	{"brace":{"stagger":80},"mark":{"pattern":"line","targets":1},"echo":{"echo_redirect":1},"grave":{"pattern":"sweep","targets":1},"tide":{"pool_radius":0.6},"hush":{"suppress":0.5},"dream":{"dodge_cooldown":100},"link":{"link":1},"frost":{"pattern":"splash","targets":1},"piercing":{"pattern":"line","targets":1},"vital":{"recovery":250},"arcane":{"pattern":"chain","targets":1},"fire":{"pattern":"splash","targets":1},"water":{"pattern":"splash","recovery":200},"blood":{"heal_on_kill":1},"spirit":{"dodge_cooldown":90},"storm":{"pattern":"chain","targets":2},"lunar":{"pattern":"splash","targets":1},"radiant":{"pattern":"sweep","targets":1},"void":{"pull":0.5},"ancient":{"pattern":"sweep","targets":1},"wood":{"stagger":60}},
	{"brace":{"max_health":2},"mark":{"skill_cooldown":250},"echo":{"echo":0.5},"grave":{"skill_heal":1},"tide":{"pool_ward":1},"hush":{"skill_cooldown":300},"dream":{"decoy_duration":600},"link":{"link_brittle":1},"frost":{"shatter_damage":1,"skill_duration":200},"piercing":{"cooldown":40},"vital":{"skill_heal":1},"arcane":{"skill_cooldown":700},"fire":{"windup_damage":1},"water":{"skill_duration":350},"blood":{"heal_on_kill":1},"spirit":{"dodge_cooldown":100},"storm":{"cooldown":65},"lunar":{"skill_duration":450},"radiant":{"skill_heal":1},"void":{"skill_cooldown":500},"ancient":{"graft_chance":0.04},"wood":{"max_health":2}}
]
const INTERACTIONS := [
	{"name":"Steam Bloom","tags":["fire","water"],"effects":{"recovery":250}},
	{"name":"Eclipse Wake","tags":["void","lunar"],"effects":{"windup_damage":1}},
	{"name":"Sanguine Cycle","tags":["vital","blood"],"effects":{"heal_on_kill":1}},
	{"name":"Storm Needle","tags":["piercing","storm"],"effects":{"reach":0.3}}
]
static func add_effects(result: Dictionary,effects: Dictionary,scale: float=1.0) -> void:
	for key in effects:
		if key=="pattern":
			result.pattern=effects[key]
		elif effects[key] is int or effects[key] is float:
			result[key]=float(result.get(key,0))+float(effects[key])*scale

static func resolve(class_id: int,weapon_id: int,slots: Array,graft: int,technique: int,profile: Dictionary) -> Dictionary:
	class_id=clampi(class_id,0,Classes.DEFINITIONS.size()-1)
	weapon_id=clampi(weapon_id,0,Classes.DEFINITIONS[class_id].weapons.size()-1)
	var weapon: Dictionary=Classes.DEFINITIONS[class_id].weapons[weapon_id]
	var result: Dictionary=weapon.duplicate(true)
	result["cooldown"]=0.0
	result["tags"]=[]
	result["interactions"]=[]
	result["core_build"]=preload("res://core_skill_rules.gd").resolve(weapon.id,slots,graft)
	var component_keys: Array=["reach","damage","windup_damage","cooldown","recovery","pull","knockback","stagger","heal_on_kill"]+Traits.KEYS
	if Preview.enabled:
		component_keys.append_array(["max_health","skill_heal"])
	for slot in mini(3,slots.size()):
		var part:=int(slots[slot])
		if part==0:
			if slot==0: result.cooldown+=140*technique
			continue
		if not Parts.is_plant(part): continue
		var entry: Dictionary=Parts.DEFINITIONS[part]
		for tag in entry.tags:
			if not result.tags.has(tag): result.tags.append(tag)
		# Raw plant effects are strongest in the Core.
		for key in component_keys:
			var value: float=entry.get(key,0)
			if slot==0: value+=float(entry.get(key+"_step",0))*technique
			result[key]=float(result.get(key,0))+value*[1.0,0.5,0.35][slot]
		for tag in entry.tags:
			if RULES[slot].has(tag):
				add_effects(result,RULES[slot][tag])
				break
	if Parts.is_monster(graft):
		var entry: Dictionary=Parts.DEFINITIONS[graft]
		add_effects(result,entry)
		for tag in entry.tags:
			if not result.tags.has(tag): result.tags.append(tag)
	add_effects(result,Classes.bonuses(profile,class_id))
	for interaction in INTERACTIONS:
		var matches:=true
		for tag in interaction.tags:
			matches=matches and result.tags.has(tag)
		if matches:
			result.interactions.append(interaction.name)
			add_effects(result,interaction.effects)
	for key in ["cooldown","recovery","stagger","skill_cooldown","skill_duration","dodge_cooldown","windup_damage"]:
		if result.has(key) and (key!="windup_damage" or not Preview.enabled): result[key]=roundi(float(result[key]))
	if float(result.get("pierce",0))>0: result.pattern="line"
	result.targets=clampi(int(result.targets),1,5)
	if result.targets>1 and result.pattern=="single":
		result.pattern="sweep" if class_id in [0,3] else "chain"
	result.damage=maxf(1.0,float(result.damage)) if Preview.enabled else maxi(1,roundi(float(result.damage)))
	result["heal_on_kill"]=Preview.capped_amount(float(result.get("heal_on_kill",0)),2)
	result["skill_heal"]=Preview.capped_amount(float(result.get("skill_heal",0)),3)
	result["max_health"]=Preview.capped_amount(float(result.get("max_health",0)),4)
	result["interval"]=maxi(230,int(result.strike_ms)-int(result.cooldown))
	return result

static func describe(stats: Dictionary) -> String:
	var damage := str(stats.damage)
	if stats.has("damage_min"):
		damage=preload("res://combat_balance_preview.gd").range_label(Vector2i(stats.damage_min,stats.damage_max))
	var text: String="%s\n%s · %d target(s)\n%s damage · %.1fm reach · %dms strikes" % [stats.name,str(stats.pattern).capitalize(),stats.targets,damage,stats.reach,stats.interval]
	for key in ["recovery","pull","knockback","stagger","heal_on_kill","windup_damage","skill_heal","skill_cooldown","skill_duration","dodge_cooldown"]:
		if float(stats.get(key,0))!=0:
			var amount=stats[key]
			if stats.has("damage_min") and key=="heal_on_kill":
				var limit: int=preload("res://expedition_sustain.gd").KILL_BUDGET_HP
				text+="\n"+Preview.heal_label(float(amount))+" per eligible kill · %d HP per floor"%limit
			else:
				text+="\n"+Classes.effect_text({key:amount},stats.has("damage_min"))
	if stats.has("damage_min") and float(stats.get("max_health",0))>0:
		text+="\n+%d maximum HP"%Preview.effect_hp(float(stats.max_health))
	if not stats.interactions.is_empty():
		text+="\n\nInteractions: "+", ".join(stats.interactions)
	var behavior:=Traits.describe(stats,true)
	if not behavior.is_empty(): text+="\n"+behavior
	var skill_text:=core_description(stats.get("core_build",{}))
	if not skill_text.is_empty(): text+="\n\n"+skill_text
	return text


static func core_description(build: Dictionary) -> String:
	var core: Dictionary=build.get("skill",{})
	return preload("res://core_skill_rules.gd").describe(core,core.get("cards",[]))
