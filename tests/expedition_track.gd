extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Track=preload("res://expedition_track.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL expedition track: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for width in [640,960,1280,1920,2560]:
  for floor_value in [1,2,3,6,7,18,19,99,1000,1000000]:
   var nodes:=Track.layout(floor_value,width);var selected: Array=nodes.filter(func(n):return n.current)
   check(selected.size()==1 and selected[0].floor==floor_value and selected[0].position.x==width*.5,"one exact centered authoritative floor")
   for node in nodes:
    check(node.floor>=1 and node.position.x>node.radius and node.position.x<width-node.radius,"nodes stay on-screen without fictional floor zero")
    check(node.radius<selected[0].radius or node.current,"current node is larger")
    check(node.label==(str(node.floor) if node.floor<=floor_value else "?"),"history stays numbered while future nodes hide numbers")
    check(node.upgrade==(node.floor%3==0) and node.extraction==(node.floor%6==0),"milestone icons match current checkpoint intervals")
 var game=load("res://world.tscn").instantiate();var base:="user://release-fixtures/floor-track-"+Crypto.new().generate_random_bytes(8).hex_encode();DirAccess.make_dir_recursive_absolute(base)
 game.progress.path=base+"/world";game.local_character.path=base+"/character";game.guest_character.path=base+"/guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];game._process(.016)
 var track: Control=game.player_hud.floor_track
 check(not track.visible and track.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Garden hides track and combat input passes through")
 ExpeditionCase.set_membership(game, p, true);ExpeditionCase.set_world(game, {"encounter_number": 6});game._process(.016)
 check(track.visible and track.floor_number==6 and not game.player_hud.state.encounter.contains("Encounter"),"game supplies floor and removes duplicated text counter")
 check(track.nodes.any(func(n):return n.floor==6 and n.current and n.upgrade and n.extraction),"current upgrade/extraction floor carries both icons")
 ExpeditionCase.set_world(game, {"encounter_number": 7});game._process(.016)
 check(track.nodes.any(func(n):return n.floor==6 and n.label=="6" and not n.current),"advancing retains the previous floor number")
 check(track.growth==0,"newly reached root grows once")
 track._process(.6);game._process(.016)
 check(track.growth==1 and not track.is_processing(),"ordinary repeated snapshots do not restart root animation")
 p[PlayerLifecycle.STATE] = p[PlayerLifecycle.STATE].fall();p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(0);game._process(.016)
 check(track.visible,"fallen spectator retains party expedition context")
 ExpeditionCase.set_membership(game, p, false);game._process(.016)
 check(not track.visible and not track.is_processing(),"returning to Garden clears animation and hides track")
 game.queue_free();await process_frame
 if not failed:print("PASS: centered responsive floor progression, hidden future labels, retained history, milestone icons, passive HUD and transition lifecycle")
 quit(1 if failed else 0)
