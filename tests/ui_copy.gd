extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed := false
func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL UI copy: ", message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var upgrades = preload("res://affinity_card_catalog.gd")
 var classes = preload("res://class_catalog.gd")
 var heart = preload("res://heart_catalog.gd")
 for id: String in upgrades.DEFINITIONS:
  var entry: Dictionary=upgrades.DEFINITIONS[id]
  for phrase in ["weighted", "committed contact", "bounded echo", "a living technique shaped", "draw a stronger expression", "refine the living form"]:
   check(not str(entry.description).to_lower().contains(phrase), "upgrade copy avoids implementation wording " + id)
 check(classes.effect_text({"windup_damage": 1}).contains("during enemy wind-up"), "wind-up damage identifies the enemy's attack phase")
 check(heart.get_node("pollination_bloom").description.contains("mature"), "Pollination Bloom describes its mature harvest benefit")
 var game = load("res://world.tscn").instantiate()
 var base := "res://.godot/ui-copy-" + Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path = base + ".cfg"
 game.local_character.path = base + ".character"
 game.guest_character.path = base + ".guest"
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 var player: Dictionary = game.players[1]
 game.progress.heart.unlock_direct("clearing_1")
 game._process(0.016)
 player.pos = game.Stage.HEART
 game._process(0.016)
 check(UIFixture.control(game,"guide").text.begins_with("E  Heart") and UIFixture.control(game,"guide").text.contains("Garden development"), "Heart prompt names the interaction and existing development shortcut")
 player.pos = game.stage.altar_position()
 game._process(0.016)
 check(UIFixture.control(game,"guide").text == "E  Altar", "Altar prompt omits the service list")
 ExpeditionCase.set_world(game, {"encounter_number": 3})
 game.encounter.set_hp(-1, 0)
 game.encounter.clear_scouts()
 ExpeditionCase.set_membership(game, player, true)
 player.pos = Vector3(0,0,-9)
 var tree=game.Classes.connected_tree(0)
 player.character[tree.profile_key]=tree.state(["vanguard"])
 # The host-created envelope retains one earned choice and the exact card prose.
 var offers: Array = game.checkpoint_card_data(player)
 check(offers.size()==1 and offers[0].get("affinity_offer",false),"checkpoint displays the modern offer envelope")
 if not offers.is_empty():
  var cards: Array=offers[0].get("choices",[])
  check(cards.size()==3,"checkpoint displays three eligible card identities")
  for card: Dictionary in cards:
   check(not str(card.description).contains("weighted"), "card text excludes weighting terminology")
   check(not str(card.description).ends_with("\n\n"), "empty descriptions leave no trailing paragraph")
   check(not str(card.scope).is_empty() and int(card.cost)==0,"card scope and free choice are explicit")
 game.queue_free()
 await process_frame
 if not failed:
  print("PASS: concise interaction prompts, upgrade copy, wind-up labels and current Flowering description")
 quit(1 if failed else 0)
