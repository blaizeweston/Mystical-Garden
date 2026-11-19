extends SceneTree
const Case = preload("res://tests/support/guest_replication_case.gd")
const Receiver = preload("res://guest_replication.gd")
const Clock = preload("res://combat_clock.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok: failed=true;printerr("FAIL guest replication: ",description)
func compressed(value: Variant) -> PackedByteArray:
	return var_to_bytes(value).compress(FileAccess.COMPRESSION_DEFLATE)
func run() -> void:
	Clock.begin_stepped(100000)
	var receiver:=Receiver.new(3)
	var world:=Case.World.new()
	var garden: Array=Receiver.initial_garden()
	var details: Dictionary={"session_binding":world.binding,"snapshot_roster":{1:"Recovered",2:"Ally"},
		"diagnostic_host":"host","diagnostic_world":"world","weapon_stats":{"damage":2},"bag":{"items":[7]}}
	receiver.receive_frame(world,Case.frame(10,{1:Case.person(),2:Case.person()},10))
	var stale_details: Dictionary=details.duplicate(true);stale_details.session_binding="old-binding"
	receiver.receive_details(world,compressed(stale_details),compressed(garden),[99],"old-floor")
	check(not receiver.has_details() and world.details_applied==0 and receiver.sequence()==10,"old connection cannot replace details or recover state")
	world.require_layout=true
	receiver.receive_details(world,compressed(details),compressed(garden),[99],"missing-layout")
	check(not receiver.has_details() and world.layouts.is_empty(),"required terrain envelope is validated before state application")
	while garden.size()<17:garden.append({})
	garden.append({"revision":5,"points":[Vector2.ONE]})
	details.snapshot_recovery=Case.frame(12,{1:Case.person(),2:Case.person()},12)
	receiver.receive_details(world,compressed(details),compressed(garden),[7,[2,3]],"floor-one")
	check(receiver.sequence()==12 and receiver.gap_count()==1 and world.last_world.drop.x==12
		and world.people[1].display_name=="Recovered" and world.people[2].display_name=="Ally","missed fast state recovers once with public names and owner-only details")
	world.last_world.campaign[9]=999
	check(receiver.campaign_word(9)==1,"projecting a world cannot expose the private received campaign buffer")
	check(world.people[1].has("bag") and not world.people[2].has("bag") and world.layouts.size()==1,"private details stay local while layout is delivered to its owner")
	check(receiver.details_age_ms(100050)==50 and receiver.details_key()=="floor-one","receipt time and floor key have one explicit owner")
	var inspected: Dictionary=receiver.details();inspected.bag.items[0]=999
	var inventory: Array=receiver.inventory();inventory[1][0]=999
	var progress: Array=receiver.garden_progress();progress[3][0]=true
	world.layouts[0].points[0]=Vector2.INF
	check(receiver.details().bag.items[0]==7 and receiver.inventory()[1][0]==2 and not receiver.garden_progress()[3][0]
		and receiver.garden_progress().size()==17,"inspection and terrain consumers cannot mutate private received buffers")
	receiver.receive_frame(world,Case.frame(11,{1:Case.person()},11))
	receiver.receive_frame(world,Case.frame(12,{1:Case.person()},12),true)
	check(receiver.sequence()==12 and receiver.rejected_count()==1 and world.last_world.drop.x==12,"older fast and duplicate recovery cannot undo a current projection")
	var event: Dictionary={"id":44,"duration":1.0,"kind":"ability","shape":"test","age":0.0}
	receiver.receive_event(event,"floor-one");event.id=999
	check(receiver.events("floor-one",100000,[])[0].id==44 and receiver.events("floor-two",100000,[]).is_empty(),"transient application is detached and floor-filtered")
	var events: Array=receiver.received_events();events[0].event.id=999
	check(receiver.received_events()[0].event.id==44 and receiver.events("floor-one",101201,[]).is_empty(),"event inspection is detached and expiry does not replay gameplay")
	for index in 130:
		receiver.receive_event({"id":index,"duration":1.0,"age":0.0},"floor-one")
	check(receiver.received_events().size()==Receiver.EVENT_LIMIT and receiver.received_events()[0].event.id==30,"transient queue retains its existing bounded newest-event policy")
	receiver.clear_session()
	check(not receiver.has_details() and receiver.sequence()==-1 and receiver.gap_count()==0 and receiver.rejected_count()==0
		and receiver.received_events().is_empty() and receiver.scouts().is_empty() and receiver.enemy_hp()==3
		and receiver.details_age_ms(102000)==0,"teardown clears every received channel without preserving a stale wallet, status or receipt")
	receiver.receive_frame(world,Case.frame(1,{1:Case.person()},1))
	check(not world.people[1].has("bag") and world.people[1].display_name=="Wanderer","new connection cannot inherit old private details or names")
	Clock.end_stepped()
	if not failed:print("PASS: guest state ownership, bounded receive/recovery, binding validation, detachment, channel cleanup and event lifetime")
	quit(1 if failed else 0)
