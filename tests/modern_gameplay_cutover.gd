extends SceneTree
## Cutover invariants and explicit historical refunds; all saves are runner fixtures.
const Profile = preload("res://character_profile.gd")
const Experience = preload("res://class_experience.gd")
const Classes = preload("res://class_catalog.gd")
const Build = preload("res://affinity_build.gd")
const Rules = preload("res://combat_ruleset.gd")
const Plants = preload("res://plant_affinities.gd")
const Parts = preload("res://weapon_parts.gd")
const Cards = preload("res://affinity_cards.gd")
const Grafts = preload("res://expedition_grafts.gd")
var failed := false
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failed = true
  printerr("FAIL modern cutover: ",label)

func conversions() -> void:
 var historical := Profile.blank()
 historical.erase(Experience.VERSION_KEY)
 historical.xp = [5,15,35,140,260]
 historical.xp_tenths = [1,2,3,4,5]
 historical.upgrades = [1,1,1,1,1]
 historical.loadouts[2] = {"weapon":2,"parts":[Parts.THORN,Parts.MOSS,Parts.VEIL]}
 var normalized := Profile.normalize(historical)
 check(normalized.xp==[51,152,353,1404,2605] and Profile.normalize(normalized)==normalized,"old whole/fractional XP converts once for every class")
 check(normalized.loadouts[2]==historical.loadouts[2] and normalized.upgrades==historical.upgrades,"ordinary load preserves loadouts and historical investments")
 var before := normalized.duplicate(true)
 for c in 5:
  var tree := Classes.connected_tree(c)
  check(not tree.eligible(normalized) and not Build.resolve(c,0,[0,0,0],normalized).capabilities.class_actions,"unconverted historical nodes cannot execute old gameplay")
  var result := Profile.refund_historical_class(normalized,c)
  check(result.error==OK and result.changed and normalized==before,"refund returns detached candidate without silently changing source")
  var converted: Dictionary = result.profile
  check(converted.xp==normalized.xp and converted.upgrades[c]==0 and tree.eligible(converted) and tree.path(converted).is_empty(),"refund retains XP and restores earned connected choices")
  check(int(converted.quarantine.learned_class_masks[tree.class_key])==1 and Profile.normalize(converted)==converted,"historical node bits archived and conversion survives normal load")
  var retry := Profile.refund_historical_class(converted,c)
  check(retry.error==OK and not retry.changed and retry.profile==converted,"repeated conversion cannot multiply XP or refund twice")
  for tier in tree.level(converted):
   check(tree.learn(converted,tree.REQUEST_OFFSET+tier*3+1).is_empty(),"each converted level authorizes one connected choice")
  check(tree.path(converted).size()==tree.level(converted) and not tree.learn(converted,tree.REQUEST_OFFSET).is_empty(),"no backfill or extra refunded selections")
 var future := historical.duplicate(true)
 future[Experience.VERSION_KEY]=99
 check(Profile.refund_historical_class(future,0).error!=OK,"unknown XP versions refuse conversion")
 future=normalized.duplicate(true)
 future[Classes.connected_tree(0).profile_key]={"version":99,"path":[]}
 check(Profile.refund_historical_class(future,0).error!=OK,"unknown tree versions refuse conversion")
 future=normalized.duplicate(true)
 future["connected_class_migrations"]={"warden":99}
 check(Profile.refund_historical_class(future,0).error!=OK,"unknown migration versions refuse conversion")

func run() -> void:
 conversions()
 var game: Node = load("res://world.tscn").instantiate()
 game.progress.path="user://release-fixtures/modern-cutover-garden.cfg"
 game.local_character.path="user://release-fixtures/modern-cutover-character.cfg"
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 var player: Dictionary=game.players[1]
 check(not game.has_meta(&"combat_affinity_ruleset") and not Rules.network_identity(game).is_empty(),"modern gameplay needs no mode flag")
 for name in ["buy_upgrade","_buy_upgrade","attempt_graft","_attempt_graft","checkpoint_offer_ids","choose_checkpoint_card"]:
  check(not game.has_method(name),"retired purchase and install methods are absent")
 for key in ["run_upgrades","checkpoint_offers","offer_floor","power","technique","graft_part","graft_floor","graft_choice","rift_hook"]:
  check(not player.has(key),"no duplicate legacy actor state: "+key)
 for c in 5:
  player.character=Profile.blank()
  player.character.active_class=c
  game.restore_class_loadout(player)
  var tree:=Classes.connected_tree(c)
  check(tree.level(player.character)==1 and not Build.departure_refusal(player).is_empty(),"zero XP requires an explicit focus")
  check(tree.learn(player.character,tree.REQUEST_OFFSET+1).is_empty(),"starting focus is free at zero XP")
  var build:=Build.for_player(player)
  check(Build.departure_refusal(player).is_empty() and build.capabilities.class_actions and build.class_skills.size()==2,"native Q/R supported without parts,graft or cards")
  check(build.core.state=="empty" and build.form.state=="empty" and build.catalyst.state=="empty","native kit does not invent affinity parts")
 var material_count:=0
 for part in Parts.DEFINITIONS.size():
  var identity:=Plants.for_part(part)
  if identity.is_empty():continue
  material_count+=1
  var build:=Build.resolve(0,0,[part,part,part],player.character)
  check(build.core.executable and build.form.executable and build.catalyst.executable,"every approved material resolves executable baseline slots")
 check(material_count==48 and Cards.Catalog.DEFINITIONS.size()==28,"48 materials and unchanged28-card catalog")
 # Exercise the actual Heart command, not only the conversion helper.
 player.character=Profile.blank()
 player.character.upgrades[0]=1
 player.character.xp[0]=350
 player.pos=game.Stage.HEART
 game.handle_loadout_action(1,player,"respec_0")
 check(Classes.connected_tree(0).eligible(player.character) and player.character.upgrades[0]==0 and player.character.xp[0]==350,"Heart refund uses validated host path")
 game.handle_loadout_action(1,player,"learn_0_65")
 check(Classes.connected_tree(0).focus(player.character)=="rootkeeper","refunded player chooses a modern focus")
 game.queue_free()
 await process_frame
 if not failed:print("PASS: modern gameplay cutover ",checks," checks")
 quit(1 if failed else 0)
