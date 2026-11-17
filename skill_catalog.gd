extends RefCounted
# Data-only skill kit. Mode handlers live in game.gd; append classes by stable ID.
const Classes=preload("res://class_catalog.gd")
const Balance=preload("res://class_skill_balance.gd")
static var DEFINITIONS: Array=make_definitions()
static func make_definitions() -> Array:
	var result: Array=[]
	for entry in Classes.DEFINITIONS:
		result.append(entry.skills)
	return result

static func resolve_in_world(game: Node, class_id: int, slot: int, profile: Dictionary) -> Dictionary:
	return resolve(class_id, slot, profile, Classes.connected_in_world(game,class_id,profile) != null)


static func resolve(class_id: int,slot: int,profile: Dictionary,connected := false) -> Dictionary:
	class_id=clampi(class_id,0,DEFINITIONS.size()-1)
	slot=clampi(slot,0,1)
	var upgrades: Array=profile.get("upgrades",[])
	var mask:=int(upgrades[class_id]) if class_id<upgrades.size() else 0
	var replaced:=false
	var augmented:=false
	var mastery:=false
	var power:=0
	var cooldown_bonus:=0
	var modifications: Dictionary={}
	var nodes: Array=Classes.DEFINITIONS[class_id].nodes
	for i in nodes.size():
		if not (mask & (1 << i)): continue
		var change: Dictionary=nodes[i].get("skill_change",{})
		var applies: bool=int(change.get("slot",0))==slot
		match str(change.get("kind","")):
			"modify":
				if applies: modifications.merge(change.get("values",{}),true)
			"replace":
				if applies: replaced=true
			"augment":
				if applies: augmented=true;power+=int(change.get("amount",1))
			"master":
				if applies: mastery=true;power+=int(change.get("amount",1))
			"power": power+=int(change.get("amount",1))
			"efficient": cooldown_bonus+=int(change.get("cooldown",800))
	var result: Dictionary=DEFINITIONS[class_id]["replace" if replaced else "base"][slot].duplicate(true)
	result.merge(modifications,true)
	if class_id==0:
		result=Classes.Warden.skill(profile,slot,result,connected)
	elif class_id>0:
		result=Classes.Subclasses.skill(profile,class_id,slot,result,connected)
	result["specialized"]=not modifications.is_empty() or result.has("warden_focus") or result.has("subclass_focus")
	result["variant"]="replacement" if replaced else "base"
	result["augmented"]=augmented
	if power>0:
		for key in ["damage","heal","charges"]:
			if result.has(key):
				result[key]=(float(result[key]) if Balance.Preview.enabled and key!="charges" else int(result[key]))+power
		for key in ["duration","bind"]:
			if result.has(key): result[key]=int(result[key])+power*350
		if result.has("radius"): result.radius=float(result.radius)+power*.3
		if result.has("range"): result.range=float(result.range)+power*.4
	if augmented: result.cooldown=roundi(int(result.cooldown)*.85)
	result.cooldown=maxi(1800,int(result.cooldown)-cooldown_bonus)
	result["power"]=power
	result["mastered"]=mastery
	result["slot"]=slot
	return result

static func change_text(class_id: int,change: Dictionary) -> String:
	if change.is_empty(): return ""
	var slot:=int(change.get("slot",0))
	var key: String="Q" if slot==0 else "R"
	match str(change.get("kind","")):
		"modify": return "Specializes %s as %s. %s"%[key,change.get("values",{}).get("name","skill"),change.get("values",{}).get("description","")]
		"augment": return "Improve %s · %s. Increases strength, reach or duration and reduces cooldown."%[key,DEFINITIONS[class_id].base[slot].name]
		"replace": return "Replaces %s with %s. %s"%[key,DEFINITIONS[class_id]["replace"][slot].name,DEFINITIONS[class_id]["replace"][slot].description]
		"master": return "Improve your current %s skill, including replacements."%key
		"efficient": return "Both skills recover %.1f seconds sooner."%(float(change.get("cooldown",800))/1000.0)
		"power": return "Increase both skills’ strength and status durations."
	return ""


static func describe(skill: Dictionary,modifiers: Dictionary={},ranks: Dictionary={}) -> String:
	if Balance.Preview.enabled:
		return describe_preview(skill,modifiers,ranks)
	var lines: Array[String]=[str(skill.name),str(skill.description)]
	var cooldown:=maxi(1800,int(skill.cooldown)-int(modifiers.get("skill_cooldown",0)))
	lines.append("Cooldown: %.1fs"% (cooldown/1000.0))
	for key in ["damage","heal","charges","range","radius","duration","bind"]:
		if not skill.has(key): continue
		var value: float=skill[key]
		if key in ["duration","bind"]: value+=float(modifiers.get("skill_duration",0))
		if key=="heal": value+=float(modifiers.get("skill_heal",0))
		if key in ["duration","bind"]: lines.append("%s: %.1fs"%[key.capitalize(),value/1000.0])
		else: lines.append("%s: %s"%[key.capitalize(),str(value).trim_suffix(".0")])
	if skill.augmented: lines.append("Augmented.")
	if skill.mastered: lines.append("Mastered.")
	return "\n".join(lines)

static func describe_preview(source: Dictionary, stats: Dictionary, ranks: Dictionary) -> String:
	var skill := preload("res://combat_traits.gd").tune_skill(source,stats)
	var lines: Array[String]=[str(skill.name),str(skill.description),"Cooldown: %s" % Balance.seconds(Balance.cooldown(skill,stats))]
	var mode := str(skill.mode)
	var subclass := mode=="subclass"
	var connected_weaver := skill.has("weaver_nodes")
	var connected_reaper := skill.has("reaper_nodes")
	var card_data: Dictionary=skill.get("card",{})
	var card: Dictionary=card_data.get("effect",{}) if int(ranks.get(card_data.get("id",""),0))>0 else {}
	var damage := float(skill.get("damage",0))
	if damage>0.0:
		lines.append("Damage per target: %s" % Balance.hp_text(damage+float(stats.get("class_power",0))))
	if mode in ["volley","reap"]:
		var burst := Balance.burst_points(skill)
		if stats.has("damage"):
			var strike := stats.duplicate()
			strike.damage += burst
			var range_hp := Balance.Preview.weapon_range(strike,int(stats.get("class_power",0)))
			lines.append("Empowered strike: %s HP damage" % Balance.Preview.range_label(range_hp))
		else:
			lines.append("Empowered strike: +%s damage" % Balance.hp_text(burst))
	var punish := float(skill.get("punish",0)) + float(card.get("punish",0))
	if punish>0.0:
		lines.append("Against enemies winding up: +%s damage" % Balance.hp_text(punish))
	var heal_bonus := Balance.healing_bonus(stats)
	if mode in ["heal","sanctuary"] or (subclass and skill.has("heal")):
		lines.append("Heal living allies: %s" % Balance.Preview.heal_label(Balance.direct_heal(skill,stats)))
	elif heal_bonus>0.0:
		lines.append("Heal yourself on cast: %s" % Balance.Preview.heal_label(heal_bonus))
	if mode in ["siphon","bloodmoon"] or skill.get("leech",false):
		var spread := Balance.Preview.HEAL_DRAIN_SPREAD_HP
		var single := Balance.Preview.heal_label(Balance.drain_amount(skill,1),spread)
		if mode=="siphon":
			lines.append("Drain: %s on hit" % single)
		else:
			lines.append("Drain: %s with one enemy hit · %s at the target cap" % [single,Balance.Preview.heal_label(Balance.drain_amount(skill,99),spread)])
		lines.append("Drains from regular enemies, elites and bosses.")
	if mode in ["heal","sanctuary"]:
		var band := Balance.Preview.heal_band(Balance.Preview.RENEWAL_HP,Balance.Preview.HEAL_TICK_SPREAD_HP)
		lines.append("Renewal: %s HP every second for %s" % [Balance.Preview.range_label(band),Balance.seconds(Balance.duration(skill,stats))])
	if skill.has("charges"):
		var key := "ward_duration" if mode=="sanctuary" else "duration"
		lines.append("Guard: %d hit(s) for %s" % [Balance.guard_charges(int(skill.charges)),Balance.seconds(Balance.duration(skill,stats,key))])
	elif mode in ["reap","harvest"]:
		lines.append("Guard: 1 hit for %s" % Balance.seconds(Balance.duration(skill,stats)))
	elif subclass and (skill.get("ward",false) or skill.get("hit_ward",false) or int(skill.get("first",-1))==2 or card.get("ward",false) or card.get("landing_ward",false) or card.get("party_hit_ward",false)):
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
		var base := Balance.subclass_bind(skill,card)
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
	if mode in ["snare","snare_field"] or (subclass and skill.visual in ["snare","retreat"]):
		lines.append("Trap persists for %s" % Balance.seconds(Balance.trap_duration(skill,stats)))
	if mode in ["volley","windstep"]:
		lines.append("Gale Focus: %s" % Balance.seconds(Balance.duration(skill,stats)))
	if skill.has("marks"):
		lines.append("Mark: +%s damage when consumed" % Balance.hp_text(Balance.MARK_POINTS))
	if subclass and int(skill.get("second",-1))==0 and not skill.has("ranger_nodes") and not connected_reaper:
		var damage_text := "%d HP" % Classes.Weaver.BRANCHING_HP if connected_weaver else Balance.hp_text(Balance.FOLLOWUP_POINTS)
		lines.append("Chained hit: %s damage" % damage_text)
	if not connected_weaver and int(skill.get("subclass_follow_lane",-1))==0:
		lines.append("Prepared follow-up: %s damage to a nearby foe" % Balance.hp_text(Balance.FOLLOWUP_POINTS))
	if skill.has("range"):
		lines.append("%s: %.2f m" % ["Range" if subclass else "Base range",float(skill.range)])
	if skill.has("radius"):
		lines.append("Radius: %.2f m" % float(skill.radius))
	if skill.get("augmented",false): lines.append("Augmented.")
	if skill.get("mastered",false): lines.append("Mastered.")
	return "\n".join(lines)


static func wild_tooltips(game: Node, player: Dictionary, skills: Array) -> Array:
	var stats: Dictionary = player.get("weapon_stats",{})
	var rules = preload("res://combat_ruleset.gd")
	var ranks: Dictionary = rules.legacy_ranks(player) if not rules.active(game) else {}
	if game.multiplayer.is_server():
		# Only resolve the equipped build again when inputs to the class effects change.
		var key := [rules.active(game),player.frame,player.character.get("upgrades",[]),
			player.character.get(Classes.Warden.Connected.PROFILE_KEY),
			player.character.get(Classes.Weaver.PROFILE_KEY), player.character.get(Classes.Ranger.PROFILE_KEY), player.character.get(Classes.Reaper.PROFILE_KEY),
			player.weapon_kind,player.weapon,
			player.secondary,player.catalyst,player.graft_part,player.technique,player.power,ranks]
		var cached: Dictionary = game.get_meta("class_skill_tooltip_stats",{})
		if cached.get("key",[]) != key:
			stats=game.weapon_stats(player)
			cached={"key":key.duplicate(true),"tips":resolved_tooltips(skills,stats,ranks)}
			game.set_meta("class_skill_tooltip_stats",cached)
		return cached.tips.duplicate()
	return resolved_tooltips(skills,stats,ranks)


static func resolved_tooltips(skills: Array, stats: Dictionary, ranks: Dictionary) -> Array:
	var adapters: Array = stats.get("affinity_build", {}).get("class_skills", [])
	var tips := []
	for slot in skills.size():
		var adapter: Dictionary = adapters[slot] if slot < adapters.size() else {}
		tips.append(describe(adapter.get("native_skill", skills[slot]), stats, ranks))
	return tips
