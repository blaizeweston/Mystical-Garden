extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Hud=preload("res://party_hud.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Gates=preload("res://gate_interaction.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL party HUD/gates: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/party-ui-"+str(Time.get_ticks_usec());game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true)
 var fallen: Dictionary=p.duplicate(true);fallen.character.name="Fallen Friend";fallen[PlayerVitals.STATE]=fallen[PlayerVitals.STATE].with_hp(0);fallen[PlayerLifecycle.STATE]=fallen[PlayerLifecycle.STATE].fall();ExpeditionCase.install_actor(game, 19, fallen)
 var other: Dictionary=p.duplicate(true);other.character.name="Friend\nName";other[PlayerVitals.STATE]=PlayerVitals.Health.new(70,100);ExpeditionCase.install_actor(game, 42, other)
 var rows:=Hud.members(game.players,1)
 check(rows.size()==2 and rows[0].id==19 and rows[1].id==42,"only other players, in stable party-slot order")
 check(rows[0].fallen and rows[1].hp==70 and rows[1].max_hp==100 and not rows[1].name.contains("\n"),"real health, fallen flag and safe names")
 game._process(.016);var panel=UIFixture.control(game,"player_hud").party_panel
 check(panel.visible and panel.rows.size()==2 and panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Wilds-only non-interactive HUD")
 check(panel.size.x<=190 and panel.size.y<=150,"bounded compact footprint")
 # Readiness follows peer identity even when two voters have the same name and the vote order differs.
 other.character.name=p.character.name
 var voting_rows:=Hud.members(game.players,1,[{"id":42,"ready":false},{"id":1,"ready":true}])
 panel.update_party(voting_rows,false)
 check(panel.visible and panel.rows.size()==3,"Garden shows the party during an active ready check")
 var self_row: Dictionary=voting_rows.filter(func(row):return row.id==1).front()
 var other_row: Dictionary=voting_rows.filter(func(row):return row.id==42).front()
 var fallen_row: Dictionary=voting_rows.filter(func(row):return row.id==19).front()
 check(self_row.name==other_row.name and self_row.local and self_row.ready and not other_row.local and not other_row.ready,
  "voters with identical names have independent indicators and the viewer can identify their own row")
 check(not fallen_row.has("ready"),"a teammate outside the vote has no readiness indicator")
 panel.loadout_left=123.0
 panel.update_party(voting_rows,false)
 check(panel.visible and panel.get_rect().end.x<panel.loadout_left and panel.z_index>0,"voters fit beside the open workbench and remain readable above its shade")
 panel.loadout_left=INF
 fallen[PlayerVitals.STATE]=PlayerVitals.Health.new(40,80);fallen[PlayerLifecycle.STATE]=PlayerLifecycle.start_life();game._process(.016)
 check(not panel.rows[0].fallen and panel.rows[0].max_hp==80,"revival clears skull and respects reduced maximum health")
 ExpeditionCase.set_membership(game, p, false);game._process(.016);check(not panel.visible and panel.rows.all(func(row):return not row.has("ready")),"hidden in Garden with previous vote indicators cleared")
 ExpeditionCase.remove_actor(game, 42);ExpeditionCase.remove_actor(game, 19);ExpeditionCase.set_membership(game, p, true);game._process(.016);check(not panel.visible,"hidden when alone")
 ExpeditionCase.set_membership(game, p, false);p.pos=game.stage.gate_position()+Vector3(2.65,0,0)
 check(game.at_weapon_gate(p),"gate crafting accepts visually adjacent player")
 game._act(1,false);check(UIFixture.control(game,"loadout_menu").visible,"actual interaction opens the gate workbench at extended range")
 p.pos=game.stage.gate_position()+Vector3(Gates.RANGE+.1,0,0);check(not game.at_weapon_gate(p),"distant crafting remains rejected")
 check(Gates.travel_range(game,"depart")==Gates.RANGE,"party departure uses same range")
 ExpeditionCase.set_world(game, {"destination": game.Campaign.HEART});check(Gates.travel_range(game,"depart")==1.7,"Heart interaction range remains appropriate");ExpeditionCase.set_world(game, {"destination": 0})
 game.ui.close_panels();ExpeditionCase.set_membership(game, p, true);game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();ExpeditionCase.set_world(game, {"encounter_number": 1});ExpeditionCase.set_world(game, {"depth": 1})
 p.pos=game.battlefield.advance+Vector3(Gates.RANGE+.1,0,0);game.expedition_transitions.commit_checkpoint(1,true);check(game.participation.floor()==1,"distant onward gate rejected")
 p.pos=game.battlefield.advance+Vector3(2.65,0,0);game.expedition_transitions.commit_checkpoint(1,true);check(game.participation.floor()==2,"actual cleared onward gate accepts extended range")
 game.queue_free();await process_frame
 if not failed:print("PASS: compact teammate portraits/names/vitals, skull/revival, Garden/solo/disconnect visibility and shared gate boundaries")
 quit(1 if failed else 0)
