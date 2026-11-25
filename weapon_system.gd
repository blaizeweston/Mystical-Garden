extends RefCounted
const Traits=preload("res://combat_traits.gd")
const Classes=preload("res://class_catalog.gd")
const Preview=preload("res://combat_balance_preview.gd")
const MONSTER_CARGO_LIMIT := 8
const SLOT_NAMES := ["Core","Form","Catalyst"]

static func add_effects(result: Dictionary,effects: Dictionary,scale: float=1.0) -> void:
	for key in effects:
		if key=="pattern":
			result.pattern=effects[key]
		elif effects[key] is int or effects[key] is float:
			result[key]=float(result.get(key,0))+float(effects[key])*scale

static func tune_affinity_basic(stats: Dictionary, cards: Dictionary = {}) -> void:
	preload("res://expedition_grafts.gd").tune_basic(stats)
	stats.damage = float(stats.damage) + float(cards.get("ordinary_weapon_damage", 0)) / Preview.scale()
	stats.interval = preload("res://affinity_cards.gd").attack_interval(int(stats.interval), int(cards.get("ordinary_weapon_interval", 0)))


static func describe(stats: Dictionary) -> String:
	var damage := str(stats.damage)
	if stats.has("damage_min"):
		damage = Preview.range_label(Preview.weapon_range(stats, int(stats.get("class_power", 0))))
	var text := "%s\n%s · %d target(s)\n%s damage · %.1f m reach\nAttack speed: %s attacks/sec" % [
		stats.name, str(stats.pattern).capitalize(), stats.targets, damage, stats.reach, Preview.attack_speed(int(stats.interval))]
	for key in ["recovery","pull","knockback","stagger","heal_on_kill","windup_damage","skill_heal","skill_cooldown","skill_duration","dodge_cooldown"]:
		if float(stats.get(key,0))!=0:
			var amount=stats[key]
			if stats.has("damage_min") and key=="heal_on_kill":
				var limit: int=preload("res://expedition_sustain.gd").KILL_BUDGET_HP
				text+="\n"+Preview.heal_label(float(amount))+" per eligible kill · %d HP per floor"%limit
			else:
				text+="\n"+Classes.effect_text({key:amount},stats.has("damage_min"))
	if stats.has("damage_min") and float(stats.get("max_health",0))>0:
		text+="\n+%d Max HP"%Preview.effect_hp(float(stats.max_health))
	if not stats.interactions.is_empty():
		text+="\n\nInteractions: "+", ".join(stats.interactions)
	var behavior:=Traits.describe(stats,true)
	if not behavior.is_empty(): text+="\n"+behavior
	return text
