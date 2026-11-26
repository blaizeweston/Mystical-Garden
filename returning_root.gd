extends RefCounted
## One physical root, one reviewed unit per request. The floor owner retains allowances;
## existing inventory and transaction owners move and persist the actual concealed stack.
const Identity = preload("res://network_action_identity.gd")
const Items = preload("res://item_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Inventory = preload("res://inventory_model.gd")
const Transactions = preload("res://game_transaction.gd")
const Returns = preload("res://garden_return_service.gd")
const Flora = preload("res://wild_flora.gd")
const COMMAND := "root_deposit|"

static func view(game, peer: int, actor: Dictionary) -> Dictionary:
	if not game.Participation.is_wild(actor): return {}
	if not game.multiplayer.is_server():
		if peer != game.local_player_id() or Identity.current_stamp(game,actor).is_empty(): return {}
		return actor.get("returning_root",{}).duplicate()
	var research: Array = game.progress.heart.unlocked
	if "checkpoint_deposit" not in research: return {}
	return game.wild_flora.root_view(game._kill_reward_identity(peer,actor), 2 if "deep_root_network" in research else 1)

static func nearby(root: Dictionary, actor: Dictionary, field) -> bool:
	if root.is_empty() or root.remaining <= 0 or not preload("res://expedition_life.gd").alive(actor): return false
	var position: Vector3 = actor.get("pos",Vector3.INF)
	return position.is_finite() and position.distance_to(root.position) <= Flora.HARVEST_REACH and field.clear_line(position,root.position)

static func eligible(item: String) -> bool:
	var definition := Items.get_item(item)
	return item in ["unidentified_seed",Items.Ancient.ITEM] or definition.has("legacy_seed") or Parts.is_plant(int(definition.get("legacy_part",-1)))

static func request(root: Dictionary, stamp: String, item: String) -> String:
	return COMMAND + "|".join([root.identity,stamp,str(root.used),item])

static func choices(bag: Array, root: Dictionary, stamp: String) -> Array:
	var quantities := {}
	for stack: Dictionary in bag:
		if eligible(stack.item):
			quantities[stack.item] = int(quantities.get(stack.item,0)) + int(stack.quantity)
	var result := []
	for item: String in quantities:
		result.append({"label":"%s  ×%d" % [Items.get_item(item).name,quantities[item]], "command":request(root,stamp,item)})
	return result

static func deposit(game, peer: int, actor: Dictionary, command: String) -> void:
	if not game.multiplayer.is_server() or not game.persistence_session.can_write() or not game.participation.contains(peer): return
	var stamp := Identity.current_stamp(game,actor)
	if stamp.is_empty() or game.Session.peer_for(actor) != peer: return
	var root := view(game,peer,actor)
	var item := command.get_slice("|",4)
	if not nearby(root,actor,game.battlefield) or not eligible(item) or command != request(root,stamp,item):
		game.tell(peer,"This Returning Root deposit is no longer available.")
		return
	if int(Inventory.counts(game,actor,"carry").get(item,0)) < 1:
		game.tell(peer,"That resource is no longer carried.")
		return
	var character: String = game._kill_reward_identity(peer,actor)
	var saved := Transactions.run_gameplay(game,Transactions.Scope.GARDEN,func() -> bool:
		var stack := Inventory.take(game,actor,"carry",item,1)
		if stack.is_empty(): return false
		var source := "root:%s:%d"%[root.identity,root.used]
		Inventory.bank_recovered_stack(game,actor,stack,source)
		if item in ["unidentified_seed",Items.Ancient.ITEM]:
			var member := Returns.Member.new(str(actor.get("garden_run_actor","")),str(actor.get("garden_run_id","")),true)
			game.garden_commands.credit_return(member,stack.get("seeds",[]),source,item==Items.Ancient.ITEM)
		game.wild_flora.record_deposit(character)
		game.Progress.Archive.activity(game.progress.archive,character,{"roots":1})
		game.record_character(peer,actor)
		return true)
	if Transactions.committed(saved.persistence) and saved.value == true:
		if peer != game.HOST and game.persistence_session.is_guarded(): game.send_committed_profile(peer)
		preload("res://diagnostic_journal.gd").event("expedition","returning_root_deposit",{"character":character,"root":root.identity,"unit":root.used+1,"item":item})
		game.tell(peer,Transactions.feedback_text(game,"Secured 1 %s in Garden storage."%Items.get_item(item).name))
	else:
		game.tell(peer,saved.notice if not saved.notice.is_empty() else "Deposit unavailable. Check your carried resources.")
