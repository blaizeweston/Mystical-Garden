extends VBoxContainer
# Station controls submit intents through the existing Garden command route.
var game: Node
var station: String=""
var title: Label
var info: Label
var status: Label
var items: OptionButton
var apply: Button
var signature: String=""
static func label(id: String) -> String:
 return {"seed_archive":"Reclamation Altar","monster_studies":"Offering Altar","living_archive":"Living Archive"}.get(id,"")
func _ready() -> void:
 custom_minimum_size.x=500
 add_theme_constant_override("separation",12)
 title=Label.new();title.add_theme_font_size_override("font_size",23);add_child(title)
 info=Label.new();info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(info)
 items=OptionButton.new();add_child(items)
 items.item_selected.connect(func(_index):update_button())
 apply=Button.new();add_child(apply)
 apply.pressed.connect(submit)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
 var close:=Button.new();close.text="Close · Esc";add_child(close)
 close.pressed.connect(func():game.ui.close_panels())
func open(id: String) -> void:
 station=id;signature=""
 title.text=label(id)
 var archive:=id=="living_archive"
 items.visible=not archive
 apply.visible=not archive
 apply.text="Reclaim seed" if id=="seed_archive" else "Offer trophy"
 refresh()
func refresh() -> void:
 var player: Dictionary=game.players.get(game.local_player_id(),{})
 if player.is_empty():return
 status.text=game.status
 if station=="living_archive":
  var lines: Array[String]=["Guardian memories recorded in this Garden"]
  var campaign: PackedInt32Array=game.campaign_snapshot() if game.multiplayer.is_server() else game.guest_replication.campaign()
  for site in game.Campaign.HEART:
   var count: int=campaign[14+site]
   lines.append("%s · %d / %d"%[game.Campaign.NAMES[site],count,game.Campaign.MEMORY_REQUIREMENTS[site]])
  info.text="\n".join(lines)
  return
 var garden: Array=game.garden_snapshot() if game.multiplayer.is_server() else game.guest_replication.garden_progress()
 if garden.size()<=13:return
 var counts: Array=game.stored_counts(player) if game.multiplayer.is_server() else player.get("stored_parts",game.Parts.empty_counts())
 var next:=str([station,counts,garden[13]])
 if next==signature:return
 signature=next
 var selected:=items.get_selected_id() if items.selected>=0 else -1
 items.clear()
 if station=="seed_archive":
  info.text="Trade matching plant parts for a seed of a species this Garden has discovered."
  for species in game.Seeds.NAMES.size():
   if not garden[13][species]:continue
   var cost: int=game.reclamation_cost(species)
   var available: int=counts[int(game.Seeds.DEFINITIONS[species].part)]
   items.add_item("%s · %d / %d parts"%[game.Seeds.NAMES[species],available,cost],species)
   items.set_item_disabled(items.item_count-1,available<cost)
 else:
  info.text="Offer one stored monster trophy. A first offering grants 4 Knowledge. Repeat offerings grant 1."
  for part in range(1,counts.size()):
   if counts[part]>0 and game.Parts.is_monster(part):
    items.add_item("%s · %d stored"%[game.Parts.part_name(part),counts[part]],part)
 items.select(-1)
 for index in items.item_count:
  if items.is_item_disabled(index):continue
  if items.selected<0 or items.get_item_id(index)==selected:items.select(index)
 update_button()
func update_button() -> void:
 apply.disabled=items.selected<0 or items.is_item_disabled(items.selected)
func submit() -> void:
 if apply.disabled:return
 var action: String="care_reclaim" if station=="seed_archive" else "care_offer"
 game.send_garden_action("%s_%d"%[action,items.get_selected_id()])
 refresh()
