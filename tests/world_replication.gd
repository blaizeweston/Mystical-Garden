extends SceneTree
const Publisher = preload("res://world_replication.gd")
const Source = preload("res://world_replication_source.gd")
const Codec = preload("res://world_snapshot.gd")
const Clock = preload("res://combat_clock.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
var failed := false

class Fixture extends Source:
	var targets := PackedInt32Array([2,3,4])
	var state := {}
	var key := "floor-one"
	var throttle := 32
	var captures := 0
	var common_captures := 0
	var private_captures := 0
	var observations := 0
	var refused := 0
	var fast: Array[Dictionary] = []
	var details: Array[Dictionary] = []
	var on_send: Callable
	var withhold_fast := false

	func _init(): super(null)
	func observe_health() -> void: observations+=1
	func peers() -> PackedInt32Array: return targets.duplicate()
	func state_key() -> String: return key
	func observer() -> Callable: return Callable()
	func world_state(_now: int) -> Dictionary:
		captures+=1
		return state.duplicate(true)
	func garden() -> Array: return ["shared-garden"]
	func roster() -> Dictionary: return {1:"Host",2:"Two",3:"Three",4:"Four"}
	func diagnostics() -> Dictionary: return {"host":"host-session","world":"world-session"}
	func recipient(peer: int) -> Dictionary:
		return {"carried":100+peer,"dropped":peer==2,"pouch":peer==3}
	func owner_binding(peer: int) -> Dictionary:
		return {"connection":"binding-"+str(peer),"action_identity":"action-"+str(peer)}
	func common_details() -> Dictionary:
		common_captures+=1
		return {"combat_events":[{"id":7}]}
	func owner_details(peer: int, common: Dictionary) -> Dictionary:
		private_captures+=1
		return {"owner":peer,"combat_events":common.combat_events.duplicate(true)}
	func inventory(peer: int) -> Array: return [peer]
	func transport_stats(_peer: int) -> Dictionary: return {"throttle":throttle,"counter":0}
	func send_fast(peer: int, frame: PackedByteArray) -> Error:
		if not withhold_fast: fast.append({"peer":peer,"frame":frame.duplicate()})
		if on_send.is_valid(): on_send.call()
		return OK
	func send_details(peer: int, payload: PackedByteArray, garden_bytes: PackedByteArray, inventory_data: Array, floor_key: String) -> Error:
		details.append({"peer":peer,"payload":payload.duplicate(),"garden":garden_bytes.duplicate(),"inventory":inventory_data.duplicate(),"key":floor_key})
		return OK
	func refuse_frame() -> void: refused+=1

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL publication: ",description)
func decoded(row: Dictionary) -> Dictionary:
	return bytes_to_var(row.payload.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))

func run() -> void:
	Clock.begin_stepped(100000)
	var world=load("res://world.tscn").instantiate()
	var base="res://.godot/publication-"+str(OS.get_process_id())
	world.progress.path=base+".garden";world.local_character.path=base+".profile";world.guest_character.path=base+".guest";world.settings_path=base+".settings"
	root.add_child(world);world.set_process(false);world.set_physics_process(false)
	var template: Dictionary=world.player_snapshot(1,false)[1]
	var fixture:=Fixture.new()
	var people: Dictionary={}
	for peer in range(1,5):
		people[peer]=template.duplicate(true);people[peer].party_slot=peer-1;people[peer].wallet=peer
	var scouts:=PackedFloat32Array()
	for index in 20:scouts.append_array(PackedFloat32Array([index,0,0,0,0,0,0,0]))
	fixture.state={"people":people,"campaign":world.campaign_snapshot(),"scouts":scouts,
		"enemy":Vector3.ZERO,"hp":99,"maximum":100,"drop":Vector3(111,0,0),"depth":1,"flags":0}
	var publisher:=Publisher.new()
	publisher.publish(fixture,0)
	check(publisher.sequence()==1 and fixture.captures==1 and fixture.fast.size()==3 and fixture.details.size()==3,"one shared fast capture and exactly one send per eligible peer")
	check(fixture.common_captures==1 and fixture.private_captures==3,"details inspect shared event queues once and only each requested owner")
	for row in fixture.fast:
		var state:=Codec.decode(row.frame)
		check(row.frame.size()==1196 and row.frame.size()<=Codec.PAYLOAD_BUDGET and state.sequence==1 and state.scouts==scouts,"full occupancy remains the exact protocol-41 payload")
		check(state.carried==100+int(row.peer) and bool(state.flags&2)==(row.peer==2) and bool(state.flags&4)==(row.peer==3),"fast recipient fields never leak between peers")
	for row in fixture.details:
		var data:=decoded(row)
		check(data.owner==row.peer and data.session_binding=="binding-"+str(row.peer) and not data.has("snapshot_recovery") and row.inventory==[row.peer],"owner-only details and accepted binding remain distinct")
	publisher.publish(fixture,.01)
	check(publisher.sequence()==1 and fixture.observations==2,"health observation is independent of publication cadence")
	publisher.publish(fixture,.041)
	check(publisher.sequence()==2 and fixture.details.size()==3,"20 Hz fast state does not promote details to the fast channel")
	publisher.publish(fixture,.6)
	check(publisher.sequence()==3 and fixture.details.size()==6,"a late tick produces one replacement per channel instead of a catch-up burst")
	fixture.throttle=0;fixture.withhold_fast=true;fixture.state.drop=Vector3(222,0,0)
	publisher.publish(fixture,0,true)
	var recovery: Dictionary=decoded(fixture.details.back())
	var restored:=Codec.decode(recovery.snapshot_recovery)
	check(publisher.sequence()==4 and restored.sequence==4 and restored.drop.x==222 and restored.carried==104,"controlled missed fast delivery recovers the latest bounded replacement")
	fixture.state.people[5]=template.duplicate(true);fixture.key="floor-two"
	var sequence:=publisher.sequence()
	publisher.publish(fixture,0,true)
	check(fixture.refused==1 and publisher.sequence()==sequence and not decoded(fixture.details.back()).has("snapshot_recovery"),"invalid occupancy cannot advance the sequence or recover a previous floor")
	fixture.state.people.erase(5);fixture.withhold_fast=false
	publisher.publish(fixture,0,true)
	check(publisher.sequence()==sequence+1 and Codec.decode(decoded(fixture.details.back()).snapshot_recovery).sequence==sequence+1,"valid publication resumes without a skipped authority sequence")
	fixture.targets=PackedInt32Array();sequence=publisher.sequence()
	publisher.publish(fixture,10)
	check(publisher.sequence()==sequence,"no eligible transport means no publication")
	fixture.targets=PackedInt32Array([2,3,4]);fixture.on_send=func():publisher.publish(fixture,0,true)
	publisher.publish(fixture,0,true)
	check(publisher.sequence()==sequence+1,"recursive callback cannot duplicate an active publication")
	fixture.on_send=func():publisher.clear_session()
	var sent:=fixture.fast.size();var details_sent:=fixture.details.size()
	publisher.publish(fixture,0,true)
	check(publisher.sequence()==0 and fixture.fast.size()==sent+1 and fixture.details.size()==details_sent,"session invalidation stops the old recipient batch and details")
	fixture.on_send=Callable();fixture.state.people[5]=template.duplicate(true)
	publisher.publish(fixture,0,true)
	check(not decoded(fixture.details.back()).has("snapshot_recovery"),"cleared sessions cannot restore an earlier recovery frame")
	fixture.state.people.erase(5)
	publisher.publish(fixture,0,true)
	check(publisher.sequence()==1,"new session begins its own authority sequence")
	# Real read projections must not expose actor arrays, profiles or ledgers.
	var actor: Dictionary=world.players[1]
	var public: Dictionary=world.player_snapshot(1,false)[1]
	var private: Dictionary=world.replication_source.owner_details(1,world.replication_source.common_details())
	public.skill_fx.test=999;private.carried_parts[0]=999;private.weapon_stats.damage=999
	check(actor.get("skill_fx",{}).get("test",0)!=999 and actor.carried_parts[0]!=999 and world.weapon_stats(actor).damage!=999,"public and owner inspections are detached from authoritative state")
	check(not world.replication_source.owner_details(999,{}).has("bag"),"unknown recipients cannot receive another owner's inventory")
	world.free();Clock.end_stepped()
	if not failed:print("PASS: host publication ownership, protocol budget, cadence, selective details, controlled recovery, session invalidation and detached projections")
	quit(1 if failed else 0)
