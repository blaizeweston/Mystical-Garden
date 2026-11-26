extends VBoxContainer
# Station controls submit intents through the existing Garden command route.
const Offerings=preload("res://assets/terrain_m02/garden_offerings.gd")
const Items=preload("res://item_catalog.gd")
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
signal refresh_requested(station: String)
signal requested(command: String, data: Dictionary)
var _ui: CanvasLayer
var _facts: Dictionary={}
func configure(ui: CanvasLayer) -> void:_ui=ui
func present(facts: Dictionary) -> void:_facts=facts.duplicate(true)
var archive_view := preload("res://living_archive_view.gd").new()
var archive_refresh_at := 0
var station: String=""
var title: Label
var info: Label
var status: Label
var items: OptionButton
var source_pick: OptionButton
var apply: Button
var signature: String=""
static func label(id: String) -> String:
 return {"seed_archive":"Reclamation Altar","monster_studies":"Offering Altar","living_archive":"Living Archive"}.get(id,"")
func _ready() -> void:
 custom_minimum_size.x=500
 add_theme_constant_override("separation",12)
 title=Label.new();title.add_theme_font_size_override("font_size",23);add_child(title)
 info=Label.new();info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(info)
 add_child(archive_view);archive_view.hide()
 items=OptionButton.new();add_child(items)
 items.item_selected.connect(func(_index):update_button())
 source_pick=OptionButton.new();source_pick.fit_to_longest_item=false;add_child(source_pick)
 apply=Button.new();add_child(apply)
 apply.pressed.connect(submit)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
 var close:=Button.new();close.text="Close · Esc";add_child(close)
 close.pressed.connect(func():_ui.close_panels())
func open(id: String) -> void:
 station=id;signature=""
 title.text=label(id)
 var archive:=id=="living_archive"
 archive_view.visible=archive;info.visible=not archive
 archive_refresh_at=0
 if archive:archive_view.open()
 items.visible=not archive
 source_pick.visible=not archive
 apply.visible=not archive
 apply.text="Reclaim seed" if id=="seed_archive" else "Offer trophy"
 refresh()
func refresh() -> void:
 if station=="living_archive":
  if Time.get_ticks_msec()<archive_refresh_at:return
  archive_refresh_at=Time.get_ticks_msec()+1000
 refresh_requested.emit(station)
 if not _facts.get("present",false):return
 status.text=str(_facts.get("status",""))
 if station=="living_archive":
  archive_view.present(_facts.get("records",{}))
  return
 if not _facts.has("discoveries"):return
 var known: Array=_facts.discoveries
 var counts: Array=_facts.counts
 var studied: Array=_facts.get("studied",[])
 var next:=str([station,counts,known,studied,_facts.get("available",{})])
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
   if available<=0:continue
   items.add_item("%s · %d / %d parts"%[Seeds.NAMES[species],available,cost],species)
   items.set_item_disabled(items.item_count-1,available<cost)
 else:
  info.text="Offer one stored monster trophy. A first offering grants 4 Knowledge. Repeat offerings grant 1. At the Heart, shared trophies instead pay Knowledge and Growth Energy by rarity."
  for part in range(1,counts.size()):
   if counts[part]>0 and Parts.is_monster(part):
    var rarity: String=Items.get_item(Items.part_id(part)).rarity
    items.add_item("%s ×%d · Study %d K · Heart %d K + %d Energy"%[Parts.part_name(part),counts[part],
     1 if studied.has(part) else 4,Offerings.KNOWLEDGE_BY_RARITY[rarity],Offerings.GROWTH_BY_RARITY[rarity]],part)
 items.select(-1)
 items.disabled=items.item_count==0
 if items.item_count==0:
  info.text+="\nNo applicable stored materials."
 for index in items.item_count:
  if items.is_item_disabled(index):continue
  if items.selected<0 or items.get_item_id(index)==selected:items.select(index)
 update_button()
func update_button() -> void:
 var previous: Variant=source_pick.get_selected_metadata() if source_pick.selected>=0 else null
 source_pick.clear()
 if items.selected>=0 and not items.is_item_disabled(items.selected):
  var selection:=items.get_selected_id()
  var part:=int(Seeds.DEFINITIONS[selection].part) if station=="seed_archive" else selection
  var costs: Dictionary=_facts.get("available",{})
  var personal: int=costs.get("stash",Parts.empty_counts())[part]
  var shared: int=costs.get("shared",Parts.empty_counts())[part]
  var cost: int=int(_facts.reclamation_costs[selection]) if station=="seed_archive" else 1
  for personal_used in range(cost+1):
   var shared_used:=cost-personal_used
   if personal_used>personal or shared_used>shared:continue
   var text: String="Shared: %d/%d available"%[shared_used,shared] if personal_used==0 else "Personal: %d/%d available"%[personal_used,personal] if shared_used==0 else "%d personal + %d shared"%[personal_used,shared_used]
   if station=="seed_archive":
    text+=" · seed to "+("personal stash" if shared_used==0 else "shared Garden")
   source_pick.add_item(text)
   source_pick.set_item_metadata(source_pick.item_count-1,personal_used)
  for index in source_pick.item_count:
   if source_pick.get_item_metadata(index)==previous:source_pick.select(index)
  if source_pick.item_count>0 and source_pick.selected<0:source_pick.select(0)
 source_pick.disabled=source_pick.item_count==0
 apply.disabled=source_pick.item_count==0
func submit() -> void:
 if apply.disabled:return
 var action: String="care_reclaim" if station=="seed_archive" else "care_offer"
 var personal_used:=int(source_pick.get_selected_metadata())
 var source: String=str(personal_used) if station=="seed_archive" else "stash" if personal_used>0 else "shared"
 requested.emit("garden_action",{"action":"%s_%d_%s"%[action,items.get_selected_id(),source]})
 refresh()
