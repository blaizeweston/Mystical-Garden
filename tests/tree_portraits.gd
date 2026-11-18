extends SceneTree
var failed:=false
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failed=true;printerr("FAIL portraits: ",message)
func run():
	var game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/portrait_check_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.progress.discoveries.fill(false)
	game.progress.discoveries[0]=true
	game.progress.discoveries[1]=true
	game.toggle_overlay(game.progression_menu)
	var panel=game.progression_view
	panel.refresh()
	var tree=panel.tree
	var node: Dictionary=tree.node_at("0")
	check(node.icon is Texture2D,"discovered species has its actual model portrait")
	check(tree.hit_node(node.position)=="0","circle center is clickable")
	check(tree.hit_node(node.position+Vector2(30,30))!="0","rectangular corner outside circle is not clickable")
	var motion:=InputEventMouseMotion.new()
	motion.position=node.position
	tree._gui_input(motion)
	check(panel.previewed=="0" and panel.details.text.contains("Thorn Bloom") and panel.details.text.contains("Thorn primary affinity") and panel.details.text.contains("Thorn Line (Core)"),"hover immediately shows name and explicit affinity/Core effect")
	check(tree._get_tooltip(node.position).contains("Thorn Bloom"),"native tooltip also provides name")
	var click:=InputEventMouseButton.new()
	click.position=node.position
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	tree._gui_input(click)
	check(tree.selected=="0" and panel.chosen=="0" and panel.details.text.contains("Growth:"),"selection pins full species entry")
	tree.set_hover("")
	check(panel.details.text.contains("Thorn Bloom"),"selection survives mouse exit")
	var mystery: Dictionary=tree.node_at("2")
	tree.set_hover("2")
	check(not panel.details.text.contains("Veilcap") and tree._get_tooltip(mystery.position).contains("Undiscovered"),"locked species retain discovery mystery")
	for species in game.Seeds.DEFINITIONS:
		var texture: Texture2D=panel.portrait(species.id)
		check(texture!=null and texture.get_width()==256,"portrait exists for "+species.name)
	panel.tabs.current_tab=1
	panel.refresh()
	tree.set_hover("heart_heart")
	check(panel.details.text.contains("Sheltered Heart"),"shared Heart nodes support hover descriptions")
	if not failed: print("PASS: circular hit targets, 24 model portraits, hover/selection descriptions and hidden discoveries")
	quit(1 if failed else 0)
