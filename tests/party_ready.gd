extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var game: Node
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL party ready: ",message)
func _initialize(): call_deferred("run")
func setup_guest():
 game.add_player(2);SessionCase.set_ready(game, game.players[2], true);SessionCase.set_identity(game, game.players[2], "b".repeat(32))
 game.players[1].character.name="Rowan";game.players[2].character.name="Fern"
 for p in game.players.values():
  p.pos=game.Stage.GATE
  var tree=game.Classes.connected_tree(int(p.frame))
  p.character[tree.profile_key]=tree.state([tree.nodes[0].id])
func cleared(floor_number: int):
 ExpeditionCase.set_world(game, {"encounter_number": floor_number});game.deepest_milestone=floor_number;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
 for p in game.players.values(): p.pos=game.battlefield.advance
func run():
 game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/party_ready_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 setup_guest()
 # This fixture has two players without sockets; suppress presentation RPCs only.
 game.set_multiplayer_authority(1)
 var host: Dictionary=game.players[1];var guest: Dictionary=game.players[2]
 ExpeditionCase.Transitions.enter(game, 1,host)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest) and game.participation.has_vote(1),"one player cannot start expedition alone")
 game._process(.016)
 check(UIFixture.control(game,"travel_panel").get_combined_minimum_size().x<600 and UIFixture.control(game,"travel_panel").get_combined_minimum_size().y<200,"ready HUD stays compact")
 var epoch: int=game.participation.travel_epoch()
 game.garden_action(1,"travel_unready:"+str(epoch))
 check((game.participation.vote_count() == 0),"ready can be withdrawn")
 ExpeditionCase.Transitions.enter(game, 1,host);host.pos+=Vector3(4,0,0);game.PartyTravel.validate(game)
 check(not game.participation.has_vote(1),"moving away clears readiness")
 host.pos=game.Stage.GATE;game.progress.parts[0]=2;host.prepared=1;guest.prepared=1
 ExpeditionCase.Transitions.enter(game, 1,host);host.prepared=0;game.PartyTravel.validate(game)
 check(not game.participation.has_vote(1),"loadout changes clear readiness")
 host.prepared=1;ExpeditionCase.Transitions.enter(game, 1,host)
 var path: String=game.progress.path;game.progress.path="res://.godot/missing-party-dir/fail.cfg"
 ExpeditionCase.Transitions.enter(game, 2,guest)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest) and game.progress.parts[0]==2 and host.prepared==1 and guest.prepared==1,"failed party departure restores both loadouts and shared resources")
 game.progress.path=path
 ExpeditionCase.Transitions.enter(game, 1,host);ExpeditionCase.Transitions.enter(game, 2,guest)
 check(ExpeditionCase.is_wild(host) and ExpeditionCase.is_wild(guest) and game.progress.parts[0]==0 and host.weapon==1 and guest.weapon==1,"all ready departs together and consumes each loadout once")
 var floor_before: int=game.participation.floor()
 cleared(1);ExpeditionCase.Transitions.checkpoint(game, 1,true)
 check(game.participation.floor()==floor_before and game.participation.vote_count()==1,"ordinary stage waits for every confirmation")
 var stale: int=game.participation.travel_epoch()
 ExpeditionCase.Transitions.checkpoint(game, 2,true)
 check(game.participation.floor()==2 and host.pos.distance_to(guest.pos)<2,"party advances together")
 game.garden_action(1,"travel_ready:"+str(stale))
 check(game.participation.floor()==2 and game.participation.travel_kind().is_empty(),"old ready messages cannot advance another stage")
 cleared(6);ExpeditionCase.Transitions.checkpoint(game, 1,true)
 check(game.checkpoint_pending and game.participation.floor()==6,"sixth-stage cards hold travel")
 for peer in [1,2]:
  game.garden_action(peer,game.affinity_checkpoint_action(int(game.checkpoint_card_data(game.players[peer])[0].revision),"skip"))
 check(game.participation.floor()==6 and (game.participation.vote_count() == 0),"card choices never substitute for party readiness")
 ExpeditionCase.Transitions.checkpoint(game, 1,true);ExpeditionCase.Transitions.checkpoint(game, 2,true)
 check(game.participation.floor()==7 and ExpeditionCase.is_wild(host) and ExpeditionCase.is_wild(guest),"explicit confirmations advance after cards")
 cleared(12);host.carried_seeds=[0];guest.carried_seeds=[1]
 ExpeditionCase.Transitions.checkpoint(game, 1,false)
 check(ExpeditionCase.is_wild(host) and ExpeditionCase.is_wild(guest),"one player cannot extract the whole party")
 ExpeditionCase.Transitions.checkpoint(game, 2,false)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest) and game.progress.unknown.has(0) and game.seed_reserve(guest).unknown.has(1),"extraction consensus banks each player's loot")
 # Shared costs cannot be paid twice or consume another player's reserved parts.
 for p in game.players.values(): p.pos=game.Stage.GATE;p.prepared=1
 game.progress.parts[0]=1
 ExpeditionCase.Transitions.enter(game, 1,host);ExpeditionCase.Transitions.enter(game, 2,guest)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest) and game.progress.parts[0]==1,"competing loadouts fail atomically without consuming resources")
 host.prepared=0;guest.prepared=0;ExpeditionCase.Transitions.enter(game, 1,host)
 SessionCase.World.remove(game,2)
 check(not ExpeditionCase.is_wild(host) and game.participation.travel_kind().is_empty(),"disconnect clears ready check without automatic departure")
 # A shared shortcut payment must reserve both players' components, not only the initiator's.
 setup_guest();guest=game.players[2];game.progress.campaign.cleared[0]=true;ExpeditionCase.set_world(game, {"destination": game.Campaign.MIRE})
 game.progress.parts.fill(0);game.progress.parts[0]=3;game.progress.parts[1]=1
 for p in game.players.values(): p.prepared=1
 ExpeditionCase.Transitions.enter(game, 1,host);ExpeditionCase.Transitions.enter(game, 2,guest)
 check(ExpeditionCase.is_wild(host) and ExpeditionCase.is_wild(guest) and game.progress.parts[0]==0 and game.progress.parts[1]==0,"shortcut pays once while preserving the complete party reservation")
 ExpeditionCase.Transitions.abandon(game, 1,host);ExpeditionCase.Transitions.abandon(game, 2,guest)
 # Restored legacy worlds must not start the deferred finale for either party member.
 setup_guest();guest=game.players[2]
 game.progress.flowering_unlocked=true;game.progress.veilcap_discovered=true;game.progress.rift_hook_discovered=true;game.progress.knowledge=game.Campaign.FULL_KNOWLEDGE
 game.progress.campaign.memories.assign(game.Campaign.MEMORY_REQUIREMENTS);game.progress.campaign.offshoots.fill(game.Campaign.MATURE)
 for technology in game.HeartCatalog.required_core(): game.progress.heart.unlock_direct(technology)
 for technology in ["memory_grove","memory_mire","memory_hollow","perfect_recollection"]: game.progress.heart.unlock_direct(technology)
 for p in game.players.values(): p.pos=game.Stage.HEART
 game.awaken_heart(1,host)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest) and game.participation.route()!=game.Campaign.HEART and game.participation.travel_kind().is_empty(),"host cannot queue the deferred finale")
 game.awaken_heart(2,guest)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest) and game.participation.travel_kind().is_empty(),"guest cannot confirm a retired finale request")
 game.queue_free();await process_frame
 if not failed: print("PASS: party consent, invalidation, stale votes, atomic costs/rollback, upgrades, extraction and disconnect safety")
 quit(1 if failed else 0)
