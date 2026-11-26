extends SceneTree
const Port=preload("res://actor_presentation_world.gd")
const Spectator=preload("res://spectator_view.gd")
const Drops=preload("res://inventory_drop_visuals.gd")
const Motion=preload("res://weapon_motion.gd")
const WeaponActions=preload("res://player_weapon_actions.gd")
const Life=preload("res://expedition_life.gd")
const ExpeditionCase=preload("res://tests/support/expedition_case.gd")
var failed:=false

class Shell extends Node:
	var overlay:=true
	var closes:=0
	func is_overlay_open()->bool:return overlay
	func panel_is_open(_kind:String)->bool:return false
	func close_panels()->void:overlay=false;closes+=1

class DisplayStage extends Node3D:
	const WILD_OFFSET=Vector3(80,0,0)
	func sphere(at:Vector3,_radius:float,tint:Color)->MeshInstance3D:
		var model:=MeshInstance3D.new();model.mesh=SphereMesh.new()
		model.material_override=StandardMaterial3D.new();model.material_override.albedo_color=tint
		add_child(model);model.position=at;return model
	func marker(at:Vector3,text:String,parent:Node3D)->Label3D:
		var label:=Label3D.new();label.text=text;parent.add_child(label);label.position=at;return label

func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok:failed=true;printerr("FAIL actor presentation: ",message)
func values_only(value:Variant)->bool:
	if value is Object:return false
	if value is Dictionary:
		for child in value.values():
			if not values_only(child):return false
	if value is Array:
		for child in value:
			if not values_only(child):return false
	return true

func run():
	# The two views work without Game, a player record or a gameplay owner.
	var shell:=Shell.new();root.add_child(shell)
	var watch:=Spectator.new();watch.configure(shell);root.add_child(watch)
	var facts={"fallen":true,"revive_cost":20,"living":[{"id":2,"name":"Birch","hp":7.8,"max_hp":80},{"id":4,"name":"Ash","hp":40,"max_hp":100}]}
	watch.present(facts);facts.living[0].name="mutated"
	check(watch.focus_id(1)==2 and shell.closes==1 and not watch.panel.visible,"first fall closes an overlay once, preserving panel order")
	check(watch.caption.text.contains("Birch · 7 / 80 HP") and watch.caption.text.contains("20 maximum HP"),"detached spectator names, HP and revival cost")
	check(watch.focus_id(1)==2 and watch.panel.visible and watch.next_button.visible,"next frame shows multiple living choices")
	watch.cycle();check(watch.focus_id(1)==4,"cycle selects the next supplied living ally")
	watch.present({"fallen":true,"living":[],"revive_cost":20})
	check(watch.focus_id(1)==1 and watch.target_peer()==0 and not watch.next_button.visible,"no living allies falls back to the local camera")
	watch.present({"fallen":false});check(watch.focus_id(1)==1 and not watch.panel.visible,"revival or Garden return clears selection")
	var stage:=DisplayStage.new();root.add_child(stage)
	var drops:=Drops.new();drops.configure(stage);root.add_child(drops);drops.set_process(false)
	var item:=preload("res://item_catalog.gd").part_id(preload("res://weapon_parts.gd").HOOK)
	var frame={"wild":true,"drops":[{"id":"one","item":item,"quantity":2,"position":[1.0,0.0,0.0]}],"observer":Vector3.ZERO,"sight_radius":2.0}
	drops.present(frame);frame.drops[0].quantity=9;drops._process(.2)
	var model:Node3D=drops.models.one
	check(model.position==Vector3(81,0,0) and model.visible,"loot uses the Wilds offset and observer radius")
	check(model.find_children("*","Label3D",true,false)[0].text.ends_with("×2"),"loot facts are detached before rendering")
	frame.drops[0].quantity=2;frame.observer=Vector3(10,0,0);drops.present(frame);drops._process(.2)
	check(drops.models.one==model and not model.visible,"observer travel changes visibility without rebuilding an unchanged drop")
	drops.present({"wild":false,"drops":[],"observer":Vector3.ZERO,"sight_radius":2.0});drops._process(.2)
	check(drops.models.is_empty() and model.is_queued_for_deletion(),"floor or Garden drop replacement retires old models")
	drops.free();stage.queue_free();watch.queue_free();shell.queue_free();await process_frame
	var world=load("res://world.tscn").instantiate()
	var base="res://.godot/actor-views-"+str(Time.get_ticks_usec())
	world.progress.path=base+".garden";world.local_character.path=base+".character";world.guest_character.path=base+".guest";world.settings_path=base+".settings"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var actor:Dictionary=world.players[1]
	var port:RefCounted=world.actor_presentation
	var now:=preload("res://combat_clock.gd").now()
	for kind in 5:
		for weapon in 3:
			actor.frame=kind;actor.weapon_kind=weapon
			var view:Dictionary=port.avatar(1,now)
			check(view.weapon_form==Motion.form(actor) and view.attack_anim==world.attack_animation_snapshot(actor,now),"canonical weapon and animation for "+str([kind,weapon]))
			check(values_only(view) and not view.has("character") and not view.has(WeaponActions.STATE),"no mutable actor or owner leaves the visual port")
	var appearance:Array=Array(actor.character.appearance).duplicate()
	var detached:Dictionary=port.avatar(1,now);detached.appearance[0]=99;detached.attack_anim.active=true
	check(Array(actor.character.appearance)==appearance and port.avatar(1,now).attack_anim!=detached.attack_anim,"returned visual values cannot change live appearance or timing")
	actor.cast_until=now+400
	check(port.avatar(1,now).attack_anim.form=="cast","class casting uses the canonical animation source")
	# Guest-shaped public facts have no owner objects. Falling must not edit their wire animation.
	world.players[91]={"pos":Vector3(2,0,3),"pose":90,"frame":1,"weapon_kind":0,"wild":true,"fallen":true,"attack_anim":{"active":true,"phase":.5},"appearance":[0,0,0,0,0]}
	var received:Dictionary=port.avatar(91,now)
	check(not received.attack_anim.active and world.players[91].attack_anim.active and absf(received.yaw-PI/2)<.0001,"fallen presentation preserves received source state and packed facing")
	world.players.erase(91);world.add_player(2)
	for peer in [1,2]:ExpeditionCase.set_membership(world,world.players[peer],true)
	var people:Dictionary=port.people(1,now)
	check(people.size()==2 and values_only(people),"host roster is projected into detached visual facts")
	var living:Array=port.spectator_frame(1).living
	check(living.map(func(person):return int(person.id))==Life.living_ids(world),"spectator eligibility and host ordering remain canonical")
	var fallback:=Vector3(9,0,9)
	check(port.position(999,fallback)==fallback,"unknown camera target uses the requested fallback")
	world.free()
	check(port.people(1,now).is_empty() and port.spectator_frame(1).is_empty() and port.drop_frame(0,3.0).is_empty(),"expired integration port cannot read a departed world")
	await process_frame
	if not failed:print("PASS: detached avatar facts, all fifteen weapon deliveries, class casting, standalone spectator and loot views, selection fallback, life presentation and world teardown")
	quit(1 if failed else 0)
