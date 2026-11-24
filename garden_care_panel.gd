extends VBoxContainer
# Station controls submit intents through the existing Garden command route.
const Campaign=preload("res://campaign.gd")
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
signal refresh_requested(station: String)
signal requested(command: String, data: Dictionary)
var _ui: CanvasLayer
var _facts: Dictionary={}
func configure(ui: CanvasLayer) -> void:_ui=ui
func present(facts: Dictionary) -> void:_facts=facts.duplicate(true)
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
 close.pressed.connect(func():_ui.close_panels())
func open(id: String) -> void:
 station=id;signature=""
 title.text=label(id)
 var archive:=id=="living_archive"
 items.visible=not archive
 apply.visible=not archive
 apply.text="Reclaim seed" if id=="seed_archive" else "Offer trophy"
 refresh()
func refresh() -> void:
 refresh_requested.emit(station)
 if not _facts.get("present",false):return
 status.text=str(_facts.get("status",""))
 if station=="living_archive":
  var lines: Array[String]=["Guardian memories recorded in this Garden"]
  var campaign: PackedInt32Array=_facts.get("campaign",PackedInt32Array())
  for site in Campaign.BIOME_COUNT:
   var count: int=campaign[14+site]
   lines.append("%s · %d / %d"%[Campaign.NAMES[site],count,Campaign.MEMORY_REQUIREMENTS[site]])
  info.text="\n".join(lines)
  return
 if not _facts.has("discoveries"):return
 var known: Array=_facts.discoveries
 var counts: Array=_facts.counts
 var next:=str([station,counts,known])
 if next==signature:return
 signature=next
 var selected:=items.get_selected_id() if items.selected>=0 else -1
 items.clear()
 if station=="seed_archive":
  info.text="Trade matching plant parts for a seed of a species this Garden has discovered."
  for species in Seeds.NAMES.size():
   if not known[species]:continue
   var cost: int=int(_facts.reclamation_costs[species])
   var available: int=counts[int(Seeds.DEFINITIONS[species].part)]
   items.add_item("%s · %d / %d parts"%[Seeds.NAMES[species],available,cost],species)
   items.set_item_disabled(items.item_count-1,available<cost)
 else:
  info.text="Offer one stored monster trophy. A first offering grants 4 Knowledge. Repeat offerings grant 1."
  for part in range(1,counts.size()):
   if counts[part]>0 and Parts.is_monster(part):
    items.add_item("%s · %d stored"%[Parts.part_name(part),counts[part]],part)
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
 requested.emit("garden_action",{"action":"%s_%d"%[action,items.get_selected_id()]})
 refresh()
