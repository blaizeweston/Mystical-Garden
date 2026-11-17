extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed := false
func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL UI copy: ", message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var upgrades = preload("res://run_upgrade_catalog.gd")
 var classes = preload("res://class_catalog.gd")
 var heart = preload("res://heart_catalog.gd")
 for entry in upgrades.all():
  for phrase in ["weighted", "committed contact", "bounded echo", "a living technique shaped", "draw a stronger expression", "refine the living form"]:
   check(not str(entry.description).to_lower().contains(phrase), "upgrade copy avoids implementation wording " + entry.id)
 check(classes.effect_text({"windup_damage": 1}).contains("during enemy wind-up"), "wind-up damage identifies the enemy's attack phase")
 check(heart.get_node("flowering").description.contains("mature plant"), "Flowering describes the current harvest choice")
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
 check(game.guide.text == "E  Heart", "Heart prompt names the interaction")
 player.pos = game.Stage.ALTAR
 game._process(0.016)
 check(game.guide.text == "E  Altar", "Altar prompt omits the service list")
 ExpeditionCase.set_world(game, {"encounter_number": 3})
 game.encounter.set_hp(-1, 0)
 game.encounter.clear_scouts()
 ExpeditionCase.set_membership(game, player, true)
 player.pos = Vector3(0,0,-9)
 player.offer_floor = 3
 player.run_upgrades = {}
 player.checkpoint_offers = ["power"]
 player.last_offer = 0
 # Existing card rendering must retain the exact effects when generic prose is absent.
 var cards: Array = game.checkpoint_card_data(player)
 check(cards.size()==1,"checkpoint fixture displays one upgrade")
 if not cards.is_empty():
  check(not str(cards[0].description).contains("weighted"), "card text excludes weighting terminology")
  check(not str(cards[0].description).ends_with("\n\n"), "empty descriptions leave no trailing paragraph")
 game.queue_free()
 await process_frame
 if not failed:
  print("PASS: concise interaction prompts, upgrade copy, wind-up labels and current Flowering description")
 quit(1 if failed else 0)
