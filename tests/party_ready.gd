extends SceneTree
var game: Node
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL party ready: ",message)
func _initialize(): call_deferred("run")
func setup_guest():
 game.add_player(2);game.players[2].profile_ready=true;game.players[2].seed_owner="b".repeat(32)
 game.players[1].character.name="Rowan";game.players[2].character.name="Fern"
 for p in game.players.values(): p.pos=game.Stage.GATE
func cleared(floor_number: int):
 game.encounter_number=floor_number;game.deepest_milestone=floor_number;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
 for p in game.players.values(): p.pos=game.battlefield.advance
func run():
 game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/party_ready_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 setup_guest()
 # This fixture has two players without sockets; suppress presentation RPCs only.
 game.set_multiplayer_authority(1)
 var host: Dictionary=game.players[1];var guest: Dictionary=game.players[2]
 game.enter_wilds(1,host)
 check(not host.wild and not guest.wild and game.travel_votes.has(1),"one player cannot start expedition alone")
 game._process(.016)
 check(game.travel_panel.get_combined_minimum_size().x<600 and game.travel_panel.get_combined_minimum_size().y<200,"ready HUD stays compact")
 var epoch: int=game.travel_epoch
 game.garden_action(1,"travel_unready:"+str(epoch))
 check(game.travel_votes.is_empty(),"ready can be withdrawn")
 game.enter_wilds(1,host);host.pos+=Vector3(4,0,0);game.PartyTravel.validate(game)
 check(not game.travel_votes.has(1),"moving away clears readiness")
 host.pos=game.Stage.GATE;game.progress.parts[0]=2;host.prepared=1;guest.prepared=1
 game.enter_wilds(1,host);host.prepared=0;game.PartyTravel.validate(game)
 check(not game.travel_votes.has(1),"loadout changes clear readiness")
 host.prepared=1;game.enter_wilds(1,host)
 var path: String=game.progress.path;game.progress.path="res://.godot/missing-party-dir/fail.cfg"
 game.enter_wilds(2,guest)
 check(not host.wild and not guest.wild and game.progress.parts[0]==2 and host.prepared==1 and guest.prepared==1,"failed party departure restores both loadouts and shared resources")
 game.progress.path=path
 game.enter_wilds(1,host);game.enter_wilds(2,guest)
 check(host.wild and guest.wild and game.progress.parts[0]==0 and host.weapon==1 and guest.weapon==1,"all ready departs together and consumes each loadout once")
 var floor_before: int=game.encounter_number
 cleared(1);game.use_checkpoint(1,true)
 check(game.encounter_number==floor_before and game.travel_votes.size()==1,"ordinary stage waits for every confirmation")
 var stale: int=game.travel_epoch
 game.use_checkpoint(2,true)
 check(game.encounter_number==2 and host.pos.distance_to(guest.pos)<2,"party advances together")
 game.garden_action(1,"travel_ready:"+str(stale))
 check(game.encounter_number==2 and game.travel_kind.is_empty(),"old ready messages cannot advance another stage")
 cleared(6);game.use_checkpoint(1,true)
 check(game.checkpoint_pending and game.encounter_number==6,"sixth-stage cards hold travel")
 game.choose_checkpoint_card(1,host,-1);game.choose_checkpoint_card(2,guest,-1)
 check(game.encounter_number==6 and game.travel_votes.is_empty(),"card choices never substitute for party readiness")
 game.use_checkpoint(1,true);game.use_checkpoint(2,true)
 check(game.encounter_number==7 and host.wild and guest.wild,"explicit confirmations advance after cards")
 cleared(12);host.carried_seeds=[0];guest.carried_seeds=[1]
 game.use_checkpoint(1,false)
 check(host.wild and guest.wild,"one player cannot extract the whole party")
 game.use_checkpoint(2,false)
 check(not host.wild and not guest.wild and game.progress.unknown.has(0) and game.seed_reserve(guest).unknown.has(1),"extraction consensus banks each player's loot")
 # Shared costs cannot be paid twice or consume another player's reserved parts.
 for p in game.players.values(): p.pos=game.Stage.GATE;p.prepared=1
 game.progress.parts[0]=1
 game.enter_wilds(1,host);game.enter_wilds(2,guest)
 check(not host.wild and not guest.wild and game.progress.parts[0]==1,"competing loadouts fail atomically without consuming resources")
 host.prepared=0;guest.prepared=0;game.enter_wilds(1,host)
 game.remove_player(2)
 check(not host.wild and game.travel_kind.is_empty(),"disconnect clears ready check without automatic departure")
 # A shared shortcut payment must reserve both players' components, not only the initiator's.
 setup_guest();guest=game.players[2];game.progress.campaign.cleared[0]=true;game.destination=game.Campaign.MIRE
 game.progress.parts.fill(0);game.progress.parts[0]=3;game.progress.parts[1]=1
 for p in game.players.values(): p.prepared=1
 game.enter_wilds(1,host);game.enter_wilds(2,guest)
 check(host.wild and guest.wild and game.progress.parts[0]==0 and game.progress.parts[1]==0,"shortcut pays once while preserving the complete party reservation")
 game.abandon_run(1,host);game.abandon_run(2,guest)
 # Restored legacy worlds must not start the deferred finale for either party member.
 setup_guest();guest=game.players[2]
 game.progress.flowering_unlocked=true;game.progress.veilcap_discovered=true;game.progress.rift_hook_discovered=true;game.progress.knowledge=game.Campaign.FULL_KNOWLEDGE
 game.progress.campaign.memories.assign(game.Campaign.MEMORY_REQUIREMENTS);game.progress.campaign.offshoots.fill(game.Campaign.MATURE)
 for technology in game.HeartCatalog.required_core(): game.progress.heart.unlock_direct(technology)
 for technology in ["memory_grove","memory_mire","memory_hollow","perfect_recollection"]: game.progress.heart.unlock_direct(technology)
 for p in game.players.values(): p.pos=game.Stage.HEART
 game.awaken_heart(1,host)
 check(not host.wild and not guest.wild and game.destination!=game.Campaign.HEART and game.travel_kind.is_empty(),"host cannot queue the deferred finale")
 game.awaken_heart(2,guest)
 check(not host.wild and not guest.wild and game.travel_kind.is_empty(),"guest cannot confirm a retired finale request")
 game.queue_free();await process_frame
 if not failed: print("PASS: party consent, invalidation, stale votes, atomic costs/rollback, upgrades, extraction and disconnect safety")
 quit(1 if failed else 0)
