extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Settings=preload("res://network_settings.gd")
var game: Node
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL direct IP: ",message)
func _initialize(): call_deferred("run")
func until(predicate: Callable) -> bool:
 var end:=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
 return predicate.call()
func run():
 var args:=OS.get_cmdline_user_args();var role: String=args[0];var token: String=args[1]
 var shared:="res://.godot/direct_ip_"+token+".cfg"
 game=load("res://world.tscn").instantiate();game.progress.path=shared+role+".garden";game.local_character.path=shared+role+".character";game.guest_character.path=shared+role+".guest";root.add_child(game)
 if role=="host":
  game.local_character.identity="d".repeat(32)
  check(SessionCase.World.host(game,Settings.DEFAULT_PORT+3)==OK,"host binds selected UDP port on all interfaces")
  var file:=ConfigFile.new();var addresses:=Settings.lan_addresses();file.set_value("network","address",addresses[0] if not addresses.is_empty() else "127.0.0.1");file.set_value("network","port",game.network_session.port());file.save(shared)
  check(await until(func():return game.players.size()==2 and game.players.values().any(func(p):return SessionCase.Session.inventory_owner(p)=="a".repeat(32) and SessionCase.Session.ready_for(p))),"guest registers over explicit interface")
  var id: int=game.players.keys()[1];game.players[id].character.xp[0]=5;game.publish_character(id)
  check(await until(func():return game.players.size()==1),"guest disconnect removed cleanly")
  check(await until(func():return game.players.size()==2 and game.players.values().any(func(p):return SessionCase.Session.inventory_owner(p)=="a".repeat(32) and SessionCase.Session.ready_for(p))),"same character reconnects after disconnect")
  await create_timer(.6).timeout
 else:
  var file:=ConfigFile.new();check(await until(func():return file.load(shared)==OK),"host endpoint available")
  game.guest_character.identity="a".repeat(32)
  game.guest_character.data.name="Fern";game.guest_character.save_profile()
  var host: String=file.get_value("network","address");var port: int=file.get_value("network","port")
  game.multiplayer.connected_to_server.disconnect(SessionCase.World.joined.bind(game))
  game.multiplayer.connected_to_server.connect(bad_handshake)
  check(SessionCase.World.join(game,host,port)==OK and await until(func():return game.network_session.role()=="Solo" and game.status.contains("versions")),"real incompatible peer rejected with explanation")
  check(game.guest_character.data.xp[0]==0,"rejected handshake cannot award or replace character progress")
  game.multiplayer.connected_to_server.disconnect(bad_handshake);game.multiplayer.connected_to_server.connect(SessionCase.World.joined.bind(game))
  await create_timer(.35).timeout
  check(SessionCase.World.join(game,host,port)==OK,"client connects to explicit address and custom port")
  check(await until(func():return game.network_session.role()=="Guest" and game.guest_character.data.xp[0]==5),"authoritative progress is saved to selected guest profile")
  SessionCase.World.leave(game,"Reconnect test")
  check(await until(func():return game.network_session.role()=="Solo"),"guest leaves to own offline state")
  await create_timer(.4).timeout
  check(SessionCase.World.join(game,host,port)==OK and await until(func():return game.network_session.role()=="Guest" and game.guest_replication.has_details()),"reconnection receives fresh owner snapshot")
  check(game.guest_character.data.xp[0]==5,"character progress survives reconnect")
 if not failed: print("PASS: direct-IP "+role+" custom port, interface connection, saved progress and reconnect")
 quit(1 if failed else 0)

func bad_handshake() -> void:
 game.register_character.rpc_id(1,game.guest_character.identity,game.guest_character.data,game.progress.ContentIDs.manifest(),Settings.PROTOCOL-1)
