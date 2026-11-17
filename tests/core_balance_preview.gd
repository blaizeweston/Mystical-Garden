extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
const Effects = preload("res://core_skill_effects.gd")
const Upgrades = preload("res://run_upgrade_catalog.gd")
const Summary = preload("res://run_summary_panel.gd")
const Mark = preload("res://core_strike_mark.gd")
const Preview = preload("res://combat_balance_preview.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL CB-05: ",detail)


func run() -> void:
	Preview.enabled=true
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/cb05-core-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1)
	game.battlefield.procedural=false
	player=game.players[1]
	roster()
	burn_and_trap()
	marks_and_links()
	wave_and_drain()
	checkpoint()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: CB-05 24 Core skills, 70 slot interactions, 166 cards, exact preview HP, pulse caps, party healing and aggregate checkpoint stats")
	quit(1 if failed else 0)


func part(id: String) -> int:
	return game.Parts.index_of("plant:"+id)


func arena(species: String) -> void:
	Core.reset(game)
	game.combat_epoch+=1
	game.enemy_hp=800
	game.enemy_pos=Vector3(0,0,-2)
	game.enemy_kind=0
	game.boss_kind=-1
	game.enemy_mutations=0
	game.enemy_winding_up=false
	game.rooted_until=0
	game.enemy_traits.clear()
	game.scouts.clear()
	game.combat_events.clear()
	game.trait_events.clear()
	game.leader_brain.clear()
	game.battlefield.barriers.clear()
	player.merge({"pos":Vector3.ZERO,"facing":Vector3.FORWARD,"frame":0,"weapon_kind":0,
		"wild":true,PlayerVitals.STATE:PlayerVitals.Health.new(25,100),"fallen":false,"weapon":part(species),"secondary":0,"catalyst":0,
		"graft_part":0,"power":0,"technique":0,"run_upgrades":{},"core_ready_at":0,"core_cast_until":0,
		"cast_until":0,"guard_charges":0,"guard_until":0},true)


func cast(distance: float=2.0) -> Dictionary:
	game.garden_action(1,Core.request(game,player,Vector2.UP,distance))
	var live: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	check(not live.is_empty(),"Core commits through the normal cast request")
	return live


func foe(at: Vector3) -> Dictionary:
	var scout: Dictionary=game.make_scout(0,at,game.scouts.size()+1)
	scout.hp=800
	game.scouts.append(scout)
	return scout


func modifier_loadout(rule: Dictionary, parts_by_skill: Dictionary) -> Dictionary:
	var slot: int=["secondary","form","catalyst","graft"].find(rule.slot)
	for core_part in parts_by_skill[rule.skill]:
		for weapon_id in Rules.WEAPON_FORMS:
			if rule.has("forms") and not rule.forms.has(Rules.WEAPON_FORMS[weapon_id]):
				continue
			for candidate in range(1,game.Parts.DEFINITIONS.size()):
				if slot==0 and candidate!=core_part:
					continue
				if game.Parts.is_monster(candidate)!=(slot==3) or not Rules.tags(candidate).has(rule.tag):
					continue
				var slots: Array=[core_part,candidate if slot==1 else 0,candidate if slot==2 else 0]
				var build: Dictionary=Rules.resolve(weapon_id,slots,candidate if slot==3 else 0)
				if build.skill.modifiers.any(func(entry):return entry.id==rule.id):
					return build
	return {}


func roster() -> void:
	var by_skill: Dictionary={}
	for index in range(1,game.Parts.DEFINITIONS.size()):
		if not game.Parts.is_plant(index):
			continue
		var signature: Dictionary=Rules.signature_for(index)
		if not by_skill.has(signature.skill): by_skill[signature.skill]=[]
		by_skill[signature.skill].append(index)
		for weapon_id in Rules.WEAPON_FORMS:
			var profile: Dictionary=Rules.resolve(weapon_id,[index],0).skill
			var tip:=Rules.describe(profile)
			check(profile.id==signature.skill and tip.begins_with(profile.name),"Core delivery resolves for "+weapon_id+" / "+signature.skill)
	check(by_skill.size()==24 and Rules.MODIFIERS.size()==70 and Upgrades.all().size()==166,"audited roster counts")
	for rule in Rules.MODIFIERS:
		var build:=modifier_loadout(rule,by_skill)
		check(not build.is_empty(),"slot-qualified modifier is reachable: "+rule.id)
		if build.is_empty(): continue
		check(rule.values.keys().all(func(key):return build.skill[key]==rule.values[key]),"applied values match the modifier: "+rule.id)
	for entry in Upgrades.all():
		var lines:=Upgrades.effect_text(entry)
		check(int(entry.cost)>0 and int(entry.max_rank)>=0 and Upgrades.core_errors(entry).is_empty(),"valid card: "+entry.id)
		for key in entry.effects:
			if Preview.COMPONENT_HP_LABELS.has(key):
				check(lines.contains("%d HP"%Preview.effect_hp(float(entry.effects[key]))),"absolute per-rank HP text: "+entry.id+" / "+key)
	var trap: Dictionary=Rules.skill_by_id("moon_snare")
	check(Rules.valid_phase({"delay":850,"enemy":{"damage":.35,"windup_damage":.45}}),"phase supports fractional authored amounts")
	check(not Rules.valid_phase({"delay":850,"enemy":{"damage":1},"siphon":1.5}),"siphon target counts are integers")
	check(Rules.valid_tuning(trap,{"heal_bonus":.45}) and not Rules.valid_tuning(trap,{"siphon_cap":1.5}),"fractional potency is independent of contact limits")


func burn_and_trap() -> void:
	arena("ember_fern")
	player.run_upgrades={"core_ember_wake":1}
	var live:=cast()
	if live.is_empty(): return
	for delta in [0,200,850,1700,2550,2750]:
		Core.tick(game,int(live.armed)+delta)
	check(game.enemy_hp==760,"Banked Coals hits four times for 10 HP with a per-target timer")
	var core: Dictionary=game.weapon_stats(player).core_build.skill
	check(Rules.describe(core).contains("10 HP damage") and Rules.describe(core).contains("0.85s"),"field tooltip shows actual pulse potency and cadence")
	arena("moon_lotus")
	game.enemy_winding_up=true
	live=cast()
	if live.is_empty(): return
	live.skill=live.skill.duplicate(true)
	live.skill.phases[0].enemy.damage=1.15
	live.skill.phases[0].enemy.windup_damage=.45
	check(Rules.describe(live.skill).contains("16 HP total against enemies winding up"),"one rounding boundary for base plus wind-up damage")
	Core.tick(game,live.armed)
	check(game.enemy_hp==800,"trap waits for its arming window")
	Core.tick(game,int(live.armed)+650)
	Core.tick(game,int(live.armed)+1050)
	check(game.enemy_hp==784 and game.rooted_until>int(live.armed)+650,"a fractional trap applies 16 HP and roots its entrant only once")


func marks_and_links() -> void:
	arena("whispervine")
	var live:=cast()
	if live.is_empty(): return
	live.skill.mark_damage=.45
	Core.tick(game,live.armed)
	var now:=int(live.armed)+1
	check(game.enemy_hp==800 and Rules.describe(live.skill).contains("5 HP damage"),"mark is setup only and shows its HP payoff")
	game.apply_weapon_hit(player,-1,player.pos,{"damage":1.2,"knockback":-.35},now)
	check(game.enemy_hp==783 and not game.enemy_traits.has(Mark.STATE),"weapon contact consumes the fractional mark once")
	arena("crownroot")
	player.run_upgrades={"core_crownlink":1}
	var other:=foe(Vector3(.1,0,-2.7))
	live=cast()
	if live.is_empty(): return
	Core.tick(game,live.armed)
	check(game.enemy_traits.has(Mark.STATE) and other.traits.has(Mark.STATE),"Crownlink pairs two visible targets")
	game.apply_weapon_hit(player,-1,player.pos,{"damage":1,"knockback":-.35},int(live.armed)+1)
	check(game.enemy_hp==790 and other.hp==780 and int(other.rooted_until)>int(live.armed),"one linked contact applies 20 HP and the card's root to the partner")


func wave_and_drain() -> void:
	arena("tide_lily")
	player.catalyst=part("dewcap")
	game.add_player(2)
	var ally: Dictionary=game.players[2]
	ally.merge({"profile_ready":true,"wild":true,"fallen":false,PlayerVitals.STATE:PlayerVitals.Health.new(90,100),"pos":Vector3(0,0,-1)},true)
	player.run_upgrades={"core_riptide":1}
	var live:=cast(2.6)
	if live.is_empty(): return
	Core.tick(game,live.armed)
	Core.tick(game,int(live.armed)+700)
	check(PlayerVitals.current_hp(player)==25 and PlayerVitals.current_hp(ally)==90,"outbound wave does not heal")
	Core.tick(game,int(live.armed)+1400)
	Core.tick(game,int(live.armed)+1500)
	check(int(PlayerVitals.current_hp(player))-25 in range(18,23) and PlayerVitals.current_hp(ally)==100,"return heals each ally once for 18–22 HP before overheal clamp")
	check(Rules.describe(Core.equipped(player)).contains("Returning wave · Restores 18–22 HP"),"Catalyst is included in the resolved return heal")
	arena("worldseed")
	ally.pos=Vector3(0,0,1)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(20)
	live=cast()
	if live.is_empty(): return
	player.pos=live.center
	Core.tick(game,live.armed)
	Core.tick(game,int(live.armed)+850)
	var canopy := int(PlayerVitals.current_hp(player))-25
	check(canopy in range(18,23) and PlayerVitals.current_hp(ally)==20,"canopy opens and heals only its first entrant")
	ally.pos=live.center
	Core.tick(game,int(live.armed)+1400)
	Core.tick(game,int(live.armed)+1750)
	check(int(PlayerVitals.current_hp(player))-25==canopy and int(PlayerVitals.current_hp(ally))-20==canopy,"late entrant receives the same canopy roll once")

	arena("bloodbriar")
	player.catalyst=part("gravemoss")
	foe(Vector3(.1,0,-1.55))
	foe(Vector3(-.1,0,-2.35))
	live=cast()
	if live.is_empty(): return
	Core.tick(game,live.armed)
	var cap: int=live.skill.get("siphon_cap",2)
	check(int(PlayerVitals.current_hp(player))-25 in range(cap*6-1,cap*6+2) and Rules.describe(live.skill).contains("%d–%d HP at the target cap"%[cap*6-1,cap*6+1]),"siphon rolls once around the cap based on damaged contacts")


func checkpoint() -> void:
	arena("mirror_mint")
	game.encounter_number=3
	game.enemy_hp=0
	player.pos=game.battlefield.advance
	player[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(500)
	player.last_offer=0
	player.offer_floor=3
	player.checkpoint_offers=["core_mirror_bloom","power","reach"]
	var offer: Dictionary=game.checkpoint_card_data(player)[0]
	check(offer.enabled and offer.cost==Upgrades.get_upgrade(offer.id).cost and offer.description.contains("10 HP damage"),"live checkpoint offers the quantified phase at its original cost")
	check(game.buy_upgrade(1,player,0),"purchase applies the third reflection")
	check(Core.equipped(player).has("extra_phase") and not game.buy_upgrade(1,player,0),"purchase applies once")
	for floor_number in [6,9]:
		game.encounter_number=floor_number
		player.offer_floor=floor_number
		player.checkpoint_offers=["power","reach","technique"]
		check(game.buy_upgrade(1,player,0),"repeatable strike rank purchases at a later gate")
	var stats: Dictionary=game.weapon_stats(player)
	var view:=Summary.project(game,player,stats)
	check(player.power==2 and view.totals[0]==["Damage",Preview.range_label(Vector2i(stats.damage_min,stats.damage_max))],"stacked ranks appear in one final strike total")
	check(view.cards.any(func(card):return card.title.ends_with("×2") and card.tooltip.contains("+10 HP strike damage")),"rank and per-rank amount appear in the card tooltip")
	check(view.bonuses.contains("Mirror Bloom") and view.bonuses.contains("10 HP damage per target"),"Tab includes the purchased phase in the active skill totals")
