extends RefCounted
# Native connected skill kit. Historical profile nodes never select runtime skills.
const Classes=preload("res://class_catalog.gd")
const Balance=preload("res://class_skill_balance.gd")
static var DEFINITIONS: Array=make_definitions()
static func make_definitions() -> Array:
	var result: Array=[]
	for entry in Classes.DEFINITIONS:
		result.append(entry.skills)
	return result

static func resolve_in_world(_game: Node, class_id: int, slot: int, profile: Dictionary) -> Dictionary:
	return resolve(class_id,slot,profile)


static func resolve(class_id: int, slot: int, profile: Dictionary) -> Dictionary:
	class_id=clampi(class_id,0,DEFINITIONS.size()-1)
	slot=clampi(slot,0,1)
	var result: Dictionary=DEFINITIONS[class_id].base[slot].duplicate(true)
	result=Classes.Warden.skill(profile,slot,result) if class_id==0 else Classes.Subclasses.skill(profile,class_id,slot,result)
	result.specialized=result.has("warden_focus") or result.has("subclass_focus")
	result.slot=slot
	return result


static func describe(skill: Dictionary, modifiers: Dictionary = {}, _ranks: Dictionary = {}) -> String:
	return describe_preview(skill,modifiers,{})


static func describe_preview(source: Dictionary, stats: Dictionary, _ranks: Dictionary) -> String:
	var skill := source.duplicate(true)
	var lines: Array[String]=[str(skill.name),str(skill.description),"Cooldown: %s" % Balance.seconds(Balance.cooldown(skill,stats))]
	var mode := str(skill.mode)
	var subclass := mode=="subclass"
	var connected_weaver := skill.has("weaver_nodes")
	var connected_reaper := skill.has("reaper_nodes")
	var damage := float(skill.get("damage",0))
	if damage>0.0:
		lines.append("Damage per target: %s" % Balance.hp_text(damage+float(stats.get("class_power",0))))
	var punish := float(skill.get("punish",0))
	if punish>0.0:
		lines.append("Against enemies winding up: +%s damage" % Balance.hp_text(punish))
	var heal_bonus := Balance.healing_bonus(stats)
	if subclass and skill.has("heal"):
		lines.append("Heal living allies: %s" % Balance.Preview.heal_label(Balance.direct_heal(skill,stats)))
	elif heal_bonus>0.0:
		lines.append("Heal yourself on cast: %s" % Balance.Preview.heal_label(heal_bonus))
	if mode == "siphon" or skill.get("leech",false):
		var spread := Balance.Preview.HEAL_DRAIN_SPREAD_HP
		var single := Balance.Preview.heal_label(Balance.drain_amount(skill,1),spread)
		if mode=="siphon":
			lines.append("Drain: %s on hit" % single)
		else:
			lines.append("Drain: %s with one enemy hit · %s at the target cap" % [single,Balance.Preview.heal_label(Balance.drain_amount(skill,99),spread)])
		lines.append("Drains from regular enemies, elites and bosses.")
	if skill.has("charges"):
		lines.append("Guard: %d hit(s) for %s" % [Balance.guard_charges(int(skill.charges)),Balance.seconds(Balance.protection_ms(skill,stats))])
	elif subclass and (skill.get("ward",false) or skill.get("hit_ward",false) or int(skill.get("first",-1))==2):
		if connected_weaver and skill.subclass_focus=="silkwarden" and int(skill.first)==2:
			lines.append("Ward: 1 hit for %s per ally, extended to %s for the lowest HP ratio" %
				[Balance.seconds(Balance.WARD_MS),Balance.seconds(Balance.WARD_MS+Classes.Weaver.GIFT_EXTENSION_MS)])
		elif connected_reaper and skill.subclass_focus=="gravekeeper":
			if skill.reaper_nodes.has("grave_ward"):
				lines.append("Ward: 1.4 s · two hits after damage, one on an empty sweep")
			else:
				var extension := Classes.Reaper.WARD_EXTENSION_MS if skill.reaper_nodes.has("lingering_veil") else 0
				lines.append("Ward: 1 hit for %s after damage" % Balance.seconds(Balance.WARD_MS+extension))
		else:
			lines.append("Ward: 1 hit for %s" % Balance.seconds(Balance.WARD_MS))
	if mode=="counter_guard":
		lines.append("Counter: +%s damage within %s after blocking" % [Balance.hp_text(Balance.counter_points(stats)),Balance.seconds(Balance.COUNTER_WINDOW_MS+int(skill.get("counter_window_bonus",0)))])
	var bind := Balance.bind_ms(skill,stats)
	if subclass:
		var base := Balance.subclass_bind(skill,{})
		bind=base+int(stats.get("skill_duration",0)) if base>0 else 0
	if bind>0:
		lines.append("Root: %s" % Balance.seconds(bind))
	if skill.has("field"):
		var kind := str(skill.field)
		var field_ms := Balance.duration(skill,stats,"duration" if subclass else "field_duration",2400)
		lines.append("%s: %s" % [kind.capitalize()+" field",Balance.seconds(field_ms)])
		var pulse := Balance.field_power(skill)
		if pulse>0.0 and kind in ["growth","tide"]:
			var amount := Balance.Preview.heal_label(pulse,Balance.Preview.HEAL_TICK_SPREAD_HP) if kind=="tide" else Balance.hp_text(pulse)
			lines.append("Base pulse: %s %s each second" % [amount,"healing" if kind=="tide" else "damage"])
	if mode == "snare" or (subclass and skill.visual in ["snare","retreat"]):
		lines.append("Trap persists for %s" % Balance.seconds(Balance.trap_duration(skill,stats)))
	if subclass and int(skill.get("second",-1))==0 and not skill.has("ranger_nodes") and not connected_reaper:
		var damage_text := "%d HP" % Classes.Weaver.BRANCHING_HP if connected_weaver else Balance.hp_text(Balance.FOLLOWUP_POINTS)
		lines.append("Chained hit: %s damage" % damage_text)
	if skill.has("range"):
		lines.append("%s: %.2f m" % ["Range" if subclass else "Base range",float(skill.range)])
	if skill.has("radius"):
		lines.append("Radius: %.2f m" % float(skill.radius))
	return "\n".join(lines)


static func resolved_tooltips(skills: Array, stats: Dictionary, ranks: Dictionary) -> Array:
	var tips := []
	for skill: Dictionary in skills:
		tips.append(describe(skill,stats,ranks) if not skill.is_empty() else "")
	return tips
