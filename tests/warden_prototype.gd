extends SceneTree

const Cooldowns = preload("res://player_cooldowns.gd")

const Warden = preload("res://warden_tree.gd")
const Combat = preload("res://warden_combat.gd")
const Aim = preload("res://ability_aim.gd")
const Core = preload("res://core_combat.gd")
const Status = preload("res://combat_status.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Warden prototype: ",message)


func select_nodes(indices: Array[int], xp: int) -> Dictionary:
	var profile: Dictionary = game.Character.blank()
	profile.xp[0] = xp
	for index in indices:
		check(game.Classes.can_learn(profile,0,index,game.Character.level(xp)), "available node "+str(index))
		profile.upgrades[0] |= 1 << index
	return profile


func tree() -> void:
	player.pos = game.Stage.HEART
	game.local_character.data = game.Character.blank()
	player.character = game.local_character.data
	player.wild = false
	check(game.Classes.points(player.character,0,1)==1, "level one grants a subclass choice")
	check(not game.Classes.can_learn(player.character,0,0,1), "new profiles cannot purchase a retired bit")
	game.progression_view.inspected_class = 0
	var nodes: Array = game.progression_view.class_nodes()
	check(nodes.size()==13 and nodes.filter(func(node): return node.get("available",false)).size()==3, "three visible level-one choices")
	var bridge: Dictionary = nodes.filter(func(node): return node.id=="class_0_16")[0]
	check(bridge.parents==["class_0_12","class_0_13","class_0_14"], "Control branch draws all adjacent parent links")
	game.garden_action(1,"learn_0_12")
	check(Warden.focus(player.character)=="vanguard" and game.Classes.points(player.character,0,1)==0, "the Heart teaches Thorn Counter at level one")
	game.garden_action(1,"learn_0_14")
	check(Warden.focus(player.character)=="vanguard", "another focus in the same row cannot be bought")
	player.character.xp[0]=350
	check(not game.Classes.can_learn(player.character,0,17,4), "a direct jump across the middle lane is locked")
	game.garden_action(1,"learn_0_16")
	game.garden_action(1,"learn_0_20")
	var skill: Dictionary = game.Skills.resolve(0,0,player.character)
	check(skill.name=="Thorn Counter" and skill.counter_window_bonus==1250 and skill.description.contains("Clear the Way"), "diagonal growth modifies the original subclass skill")
	var profile=game.Character.new()
	profile.path=game.local_character.path
	check(profile.load_profile()==OK and profile.data.upgrades[0]==player.character.upgrades[0], "the new tree round-trips via stable content IDs")
	var old: Dictionary = game.Character.blank()
	old.xp[0]=2600
	for bit in [0,2,4,6,8,10]:old.upgrades[0]|=1<<bit
	var old_manifest: Dictionary=game.Character.ContentIDs.manifest()
	old_manifest.nodes.warden=old_manifest.nodes.warden.slice(0,Warden.OFFSET)
	var loaded: Dictionary=game.Character.normalize(game.Character.ContentIDs.profile(old,old_manifest))
	check(loaded.upgrades[0]==old.upgrades[0] and game.Skills.resolve(0,1,loaded).name=="Sanctuary Quake","older Warden saves preserve skills and earned choices")
	player.character=loaded
	game.garden_action(1,"respec_0")
	check(game.Classes.points(player.character,0,7)==4 and player.character.xp[0]==2600,"refund opens all earned prototype tiers without spending XP")


func arena(indices: Array[int], card: String) -> void:
	Core.reset(game)
	game.combat_epoch+=1
	player.character=select_nodes(indices,2600)
	player.frame=0
	player.wild=true
	player.fallen=false
	player.hp=10
	player.max_hp=10
	player.pos=Vector3.ZERO
	player.facing=Vector3.FORWARD
	player.weapon=game.Parts.index_of("plant:thorn_bloom")
	player.catalyst=0
	player.graft_part=0
	player.run_upgrades={card:1} if not card.is_empty() else {}
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
	for key in ["guard_until","front_guard_until","counter_guard_until","counter_until","hurt_until","core_cast_until","core_ready_at","cast_until"]:
		player[key]=0
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.enemy_hp=100
	game.enemy_pos=Vector3(0,0,-1.4)
	game.enemy_traits.clear()
	game.rooted_until=0
	game.enemy_winding_up=false
	game.scouts.clear()
	game.combat_events.clear()
	game.encounter_number=1
	game.encounter_rewarded=false


func scout(at: Vector3) -> Dictionary:
	var actor: Dictionary=game.make_scout(0,at,game.scouts.size()+1)
	actor.hp=50
	game.scouts.append(actor)
	return actor


func offense() -> void:
	arena([12,15,18,21],"vanguard_briar_wake")
	var far := scout(Vector3(3.8,0,0))
	var near := scout(Vector3(1.2,0,0))
	game.use_class_skill(1,player,0)
	var now := Time.get_ticks_msec()
	check(Combat.prepared_until(game,player,now)==0, "pressing Q alone does not prepare Quake")
	game.apply_enemy_hit(1,player,now,1,0,game.enemy_pos)
	check(player.hp==10 and player.counter_until>now and near.pos.x>1.9, "a real counter block repels nearby enemies")
	Status.sync(game,now)
	check(Status.snapshot(game,now).any(func(e): return e.shape=="warden_quake_ready" and e.combo==1), "prepared Quake has a visible player status")
	game.use_class_skill(1,player,1)
	check(game.enemy_hp<98 and near.rooted_until>now and game.rooted_until>now, "the bridged Quake uses the counter and roots actual contacts")
	check(far.hp<50 and game.combat_events.any(func(e): return e.shape=="Briar Wake"), "the branch card strikes once outside the ordinary Quake")
	check(Combat.prepared_until(game,player,now)==0, "real Quake consumes the preparation")


func neutral() -> void:
	arena([13,16,19,22],"rootkeeper_second_growth")
	game.use_class_skill(1,player,0)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, Time.get_ticks_msec()+2500)
	game.apply_enemy_hit(1,player,Time.get_ticks_msec(),1,0,game.enemy_pos)
	check(player[Cooldowns.STATE].deadline(Cooldowns.DODGE)<=Time.get_ticks_msec(), "Ready Footing restores a recovering dodge on block")
	player.pos=Vector3(0,0,5.5)
	var view:=Aim.footprint(game,player,game.battlefield,1,Vector3.FORWARD,5.5)
	check(view.shapes.any(func(shape): return shape.kind=="area" and shape.at==Vector3.ZERO), "neutral node extends anchor range in the release preview")
	game.battlefield.barriers.append(Rect2(-1,2,2,.5))
	view=Aim.footprint(game,player,game.battlefield,1,Vector3.FORWARD,5.5)
	check(view.shapes.any(func(shape): return shape.kind=="area" and shape.at==player.pos), "blocked anchor makes the Quake preview fall back to the caster")
	game.battlefield.barriers.clear()
	var q_before: int=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	game.garden_action(1,Aim.request(game,player,1,Vector2.UP))
	check(game.enemy_hp<100 and player.pos.z==5.5 and player.warden_anchor.uses==1, "remote release hits at the anchor and the card preserves one use")
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)<q_before,"Living Rhythm refunds only after contact")
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	game.use_class_skill(1,player,1)
	check(Combat.anchor(game,player,Time.get_ticks_msec()).is_empty(),"the second use consumes the same anchor")
	game.use_class_skill(1,player,0)
	game.combat_epoch+=1
	check(Combat.anchor(game,player,Time.get_ticks_msec()).is_empty(),"a floor change expires the anchor")


func support() -> void:
	arena([14,17,20,23],"")
	var ally: Dictionary=game.players[2]
	ally.wild=true
	ally.fallen=false
	ally.hp=6
	ally.pos=Vector3(1.2,0,-3.0)
	ally.guard_until=0
	player.catalyst=game.Parts.index_of("plant:storm_reed")
	var card: Dictionary=game.RunUpgrades.get_upgrade("bastion_thorn_shelter")
	check(game.RunUpgrades.requirement(card,player).is_empty(),"Thorn Shelter qualifies with Force in Catalyst")
	player.secondary=player.catalyst
	player.catalyst=0
	check(not game.RunUpgrades.requirement(card,player).is_empty(),"a Force Form cannot substitute for a Catalyst")
	player.catalyst=player.secondary
	player.secondary=0
	game.enemy_hp=0
	game.encounter_number=3
	player.pos=game.battlefield.advance
	player[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(player).spent_essence())
	player.last_offer=0
	player.offer_floor=0
	var offers: Array=game.checkpoint_offer_ids(player)
	check(offers.size() in [3,4] and offers[0]==card.id and game.RunUpgrades.get_upgrade(offers[1]).has("core"), "Warden checkpoint shows branch and Core choices when affordable")
	check(game.buy_upgrade(1,player,0), "Thorn Shelter buys through the normal checkpoint")
	game.encounter_number=4
	game.enemy_hp=100
	game.enemy_pos=Vector3(0,0,-3.25)
	player.pos=Vector3.ZERO
	game.garden_action(1,Core.request(game,player,Vector2.UP,2.5))
	var line: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	if line.is_empty():
		check(false,"real Thorn Line arms")
		return
	Core.tick(game,line.armed)
	player.core_cast_until=0
	player.cast_until=0
	game.use_class_skill(1,player,0)
	var now:=Time.get_ticks_msec()
	check(ally.guard_until==0,"ally outside the initial shield has no ward")
	game.apply_enemy_hit(1,player,now,1,0,Vector3.BACK)
	check(Combat.prepared_until(game,player,now)==0,"a rear hit cannot prime Thorn Shelter")
	player.hurt_until=0
	game.apply_enemy_hit(1,player,now,1,0,Vector3.FORWARD)
	check(Combat.prepared_until(game,player,now)>0,"Rootshield block prepares the linked card")
	# Clear the shorter Shared Bark ward before verifying the remote ward source.
	ally.guard_until=0
	game.use_class_skill(1,player,1)
	check(game.rooted_until>now and ally.guard_until>now and player.warden_block.line_used, "Quake trips the actual Thorn Line and wards beside it")
	check(game.combat_events.any(func(e): return e.kind=="enemy_release" and is_equal_approx(e.reach,Combat.WARD_RADIUS)), "Thorn Shelter has a visible ward circle")


func run() -> void:
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/warden-prototype-"+str(Time.get_ticks_usec())
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player=game.players[1]
	game.add_player(2)
	game.players[2].profile_ready=true
	tree()
	offense()
	neutral()
	support()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Warden subclass bridges, save migration, confirmed blocks, anchor previews and three checkpoint behaviors")
	quit(1 if failed else 0)
