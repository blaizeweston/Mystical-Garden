extends VBoxContainer
const Items=preload("res://item_catalog.gd")
const Builds=preload("res://affinity_build.gd")
const Slot=preload("res://inventory_slot.gd")
var game: Node
var heading: Label
var storage_pick: OptionButton
var filter_pick: OptionButton
var rarity_pick: OptionButton
var sort_pick: OptionButton
var sort_button: Button
var grid: GridContainer
var pouch_row: VBoxContainer
var pouch_holder: HBoxContainer
var equipment: HBoxContainer
var core_skill: Label
var transfer_button: Button
var details: RichTextLabel
var notice: Label
var state: Dictionary={}
var shown: Array=[]
var selected: Dictionary={}
var order: Dictionary={}
var ascending:=true
var key: String=""
var elapsed:=0.0
const PAGE_SIZE:=40
var page:=0
var page_label: Label
var previous_page: Button
var next_page: Button
func _ready() -> void:
 heading=Label.new();heading.add_theme_font_size_override("font_size",19);add_child(heading)
 var tools:=HBoxContainer.new();tools.add_theme_constant_override("separation",8);add_child(tools)
 storage_pick=OptionButton.new();tools.add_child(storage_pick)
 filter_pick=OptionButton.new();tools.add_child(filter_pick)
 for text in ["All items","Seeds","Plant parts","Monster parts","Other items"]: filter_pick.add_item(text)
 rarity_pick=OptionButton.new();tools.add_child(rarity_pick)
 rarity_pick.add_item("All rarities")
 for rarity in Items.RARITIES: rarity_pick.add_item(rarity)
 sort_pick=OptionButton.new();tools.add_child(sort_pick)
 for text in ["Name","Rarity","Type","Quantity"]: sort_pick.add_item(text)
 sort_button=Button.new();sort_button.text="Sort ↑";tools.add_child(sort_button)
 sort_button.pressed.connect(func(): ascending=not ascending;order.clear();key="";refresh())
 for option in [storage_pick,filter_pick,rarity_pick,sort_pick]: option.item_selected.connect(func(_index): page=0;selected={};key="";refresh())
 var navigation:=HBoxContainer.new();add_child(navigation)
 previous_page=Button.new();previous_page.text="Previous";navigation.add_child(previous_page)
 page_label=Label.new();navigation.add_child(page_label)
 next_page=Button.new();next_page.text="Next";navigation.add_child(next_page)
 previous_page.pressed.connect(func():page=maxi(0,page-1);selected={};key="";refresh())
 next_page.pressed.connect(func():page+=1;selected={};key="";refresh())
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);add_child(row)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(570,350);row.add_child(scroll)
 grid=GridContainer.new();grid.columns=8;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
 var side:=VBoxContainer.new();side.custom_minimum_size.x=240;row.add_child(side)
 var label:=Label.new();label.text="Plant affinities";side.add_child(label)
 equipment=HBoxContainer.new();side.add_child(equipment)
 core_skill=Label.new();core_skill.add_theme_color_override("font_color",Color("#c8df99"));side.add_child(core_skill)
 pouch_row=VBoxContainer.new();side.add_child(pouch_row)
 var pouch_label:=Label.new();pouch_label.text="Safe pouch · 1 stack";pouch_row.add_child(pouch_label)
 pouch_holder=HBoxContainer.new();pouch_row.add_child(pouch_holder)
 details=RichTextLabel.new();details.bbcode_enabled=true;details.custom_minimum_size=Vector2(240,170);details.scroll_active=true;side.add_child(details)
 transfer_button=Button.new();side.add_child(transfer_button)
 transfer_button.pressed.connect(func():
  if selected.is_empty(): return
  game.send_inventory_action("transfer",str(selected.get("bucket",source())),"stash" if selected.get("bucket",source())=="shared" else "shared",str(selected.item),int(selected.quantity));key="";refresh())
 notice=Label.new();notice.custom_minimum_size.x=820;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.add_theme_font_size_override("font_size",12);add_child(notice)
 refresh()
func clear_children(node: Node) -> void:
 for child in node.get_children(): node.remove_child(child);child.queue_free()
func source() -> String:
 return "carry" if bool(state.get("wild",false)) else "all" if storage_pick.selected==0 else "shared" if storage_pick.selected==2 else "stash"
func refresh() -> void:
 if game==null or grid==null or get_viewport().gui_is_dragging(): return
 var fresh: Dictionary=game.inventory_ui_data()
 if fresh.is_empty(): return
 var next_key:=str(fresh)+str([storage_pick.selected,filter_pick.selected,rarity_pick.selected,sort_pick.selected,ascending,order,page,game.status])
 if next_key==key: return
 var changed_mode: bool=state.get("wild",null)!=fresh.wild
 state=fresh
 if changed_mode: selected={};page=0
 if changed_mode or storage_pick.item_count==0:
  storage_pick.clear()
  if state.wild: storage_pick.add_item("Backpack")
  else: storage_pick.add_item("All Garden storage");storage_pick.add_item("Personal stash");storage_pick.add_item("Shared Garden")
 storage_pick.disabled=bool(state.wild)
 key=str(fresh)+str([storage_pick.selected,filter_pick.selected,rarity_pick.selected,sort_pick.selected,ascending,order,page,game.status])
 sort_button.text="Sort ↑" if ascending else "Sort ↓"
 heading.text="BACKPACK" if state.wild else "GARDEN STASH"
 shown=[]
 for entry in (state.get("stash",[])+state.get("shared",[]) if source()=="all" else state.get(source(),[])):
  var item:=Items.get_item(str(entry.item))
  var categories: Array=["","seed","plant_part","monster_part","other"]
  var wanted: String=categories[filter_pick.selected]
  if wanted=="other" and item.category in ["seed","plant_part","monster_part"]: continue
  if wanted!="" and wanted!="other" and wanted!=item.category: continue
  if rarity_pick.selected>0 and item.rarity!=Items.RARITIES[rarity_pick.selected-1]: continue
  shown.append(entry)
 shown.sort_custom(compare_entries)
 clear_children(grid)
 var pages:=maxi(1,ceili(shown.size()/float(PAGE_SIZE)));page=clampi(page,0,pages-1)
 page_label.text="Page %d / %d · %d stacks"%[page+1,pages,shown.size()];previous_page.disabled=page==0;next_page.disabled=page>=pages-1
 var visible_entries: Array=shown.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE)
 for entry in visible_entries:add_slot(grid,entry,str(entry.bucket))
 for empty in maxi(0,PAGE_SIZE-visible_entries.size()):add_slot(grid,{},source())
 clear_children(equipment)
 var equipment_entries: Array=[]
 var build: Dictionary=state.get("affinity_build",{})
 var core: Dictionary=Builds.core_skill(build) if not build.is_empty() else {}
 var core_name: String=core.get("name","")
 var summary: String=slot_description(0)
 core_skill.visible=not core_name.is_empty()
 core_skill.text="Core skill · "+core_name
 core_skill.tooltip_text=summary
 core_skill.mouse_filter=Control.MOUSE_FILTER_PASS
 for index in state.equipment.size():
  var part:=int(state.equipment[index])
  var entry: Dictionary={"item":Items.part_id(part),"quantity":1,"bucket":"equipment","key":"equipment:%d"%index,"slot":index} if part>0 else {}
  var slot:=add_slot(equipment,entry,"equipment",48)
  slot.tooltip_text=game.Weapons.SLOT_NAMES[index]+": "+game.Parts.part_name(part)
  if not entry.is_empty(): equipment_entries.append(entry)
  var slot_text:=slot_description(index)
  if not slot_text.is_empty(): slot.tooltip_text+="\n\n"+slot_text
 pouch_row.visible=bool(state.wild)
 clear_children(pouch_holder)
 if state.wild:
  var held: Array=state.get("pouch",[])
  add_slot(pouch_holder,held[0] if not held.is_empty() else {},"pouch")
  var tip:=Label.new();tip.text="Drag a stack here\nto protect it.";tip.add_theme_font_size_override("font_size",12);pouch_holder.add_child(tip)
 notice.text="Drag outside to drop. Shift + drag for one item. %d stacks."%shown.size()
 if not state.wild: notice.text+=" Shared Garden seeds/parts and personal storage are labeled separately."
 if not game.status.is_empty():notice.text+="\n"+game.status
 var candidates: Array=shown.duplicate()
 candidates.append_array(state.get("pouch",[]))
 candidates.append_array(equipment_entries)
 var match_entry: Dictionary={}
 for candidate in candidates:
  if candidate.key==selected.get("key",""): match_entry=candidate;break
 selected=match_entry if not match_entry.is_empty() else visible_entries[0] if not visible_entries.is_empty() else {}
 show_details()
func compare_entries(a: Dictionary,b: Dictionary) -> bool:
 var manual: Array=order.get(source(),[])
 if not manual.is_empty():
  var ai:=manual.find(a.key);var bi:=manual.find(b.key)
  if ai!=bi: return (ai if ai>=0 else 99999)<(bi if bi>=0 else 99999)
 var first:=Items.get_item(a.item);var second:=Items.get_item(b.item)
 var left;var right
 match sort_pick.selected:
  1: left=Items.RARITIES.find(first.rarity);right=Items.RARITIES.find(second.rarity)
  2: left=first.category;right=second.category
  3: left=int(a.quantity);right=int(b.quantity)
  _: left=first.name;right=second.name
 if left==right: return str(a.key)<str(b.key)
 return left<right if ascending else left>right
func add_slot(parent: Node,entry: Dictionary,bucket: String,dimension: int=64) -> Control:
 var slot:=Slot.new();parent.add_child(slot);slot.setup(self,entry,bucket,dimension);return slot
func select_entry(entry: Dictionary) -> void:
 selected=entry;show_details()
# All equipment descriptions resolve the same live Core/Form/Catalyst build.
func slot_description(index: int) -> String:
 var build: Dictionary=state.get("affinity_build",{})
 var equipped: Array=state.get("equipment",[])
 if build.is_empty() or index<0 or index>=Builds.SLOTS.size() or index>=equipped.size(): return ""
 var preview: Dictionary=Builds.slot_preview(build,Builds.SLOTS[index],int(equipped[index]))
 var text: String=preview.summary
 if not str(preview.detail).is_empty(): text+="\n\n"+str(preview.detail)
 return text

func show_details() -> void:
 if selected.get("bucket","")=="equipment":
  transfer_button.hide()
  var slot: int=selected.slot
  var item:=Items.get_item(str(selected.item))
  var summary: String=slot_description(slot)
  details.text="[b]%s[/b]\n%s"%[item.name,game.Weapons.SLOT_NAMES[slot]]
  if not item.tags.is_empty(): details.text+=" · "+", ".join(item.tags)
  if not summary.is_empty(): details.text+="\n\n"+summary
  return
 transfer_button.visible=not bool(state.get("wild",false))
 transfer_button.text="Move to personal stash" if selected.get("bucket",source())=="shared" else "Move to Garden storage"
 transfer_button.disabled=selected.is_empty() or not (Items.get_item(str(selected.get("item",""))).has("legacy_part") or Items.get_item(str(selected.get("item",""))).get("category","")=="seed")
 if selected.is_empty(): details.text="Select an item.";return
 var item:=Items.get_item(str(selected.get("item","")))
 if item.is_empty(): return
 var description:=Items.describe(item)
 if item.category=="monster_part":
  description="A trophy that can fund an expedition improvement at a Grafting Altar."
 details.text="[b]%s[/b]\n%s · %s\n\n%s"%[item.name,item.rarity,item.category.replace("_"," ").capitalize(),description]
 if not item.tags.is_empty():details.text+="\n\nTags: "+", ".join(item.tags)
 if not item.monster_tags.is_empty():details.text+="\nMonster tags: "+", ".join(item.monster_tags)
 details.text+="\n\nStorage: "+("Shared Garden" if selected.get("bucket",source())=="shared" else "Personal stash" if not state.wild else "Backpack / pouch")
func can_accept(bucket: String,payload) -> bool:
 if not payload is Dictionary or payload.get("type","")!="garden_item_stack" or bucket=="equipment": return false
 if bucket=="all":bucket=str(payload.get("source",""))
 if not payload.get("quantity") is int or int(payload.quantity)<=0: return false
 var item:=Items.get_item(str(payload.get("item","")))
 if item.is_empty(): return false
 if bool(state.get("wild",false)):
  if payload.get("source","") not in ["carry","pouch"] or bucket not in ["carry","pouch"]: return false
  if bucket=="pouch":
   if not item.get("pouch_allowed",true): return false
   var held: Array=state.get("pouch",[])
   if not held.is_empty() and (held[0].item!=payload.item or int(held[0].quantity)+int(payload.quantity)>int(item.stack_limit)): return false
  return true
 return payload.get("source","") in ["stash","shared"] and bucket in ["stash","shared"] and (bucket!="shared" or item.has("legacy_part") or item.get("category","")=="seed")
func move_stack(bucket: String,payload: Dictionary,target_key: String="") -> void:
 if bucket=="all":bucket=str(payload.get("source",""))
 if not can_accept(bucket,payload): return
 if bucket==payload.source:
  var keys: Array=[]
  for entry in shown: keys.append(entry.key)
  var origin:=keys.find(payload.get("key",""));var target:=keys.find(target_key)
  if origin>=0:
   keys.remove_at(origin);keys.insert(clampi(target,0,keys.size()) if target>=0 else keys.size(),payload.key);order[source()]=keys;key="";refresh()
 else:
  game.send_inventory_action("transfer",str(payload.source),bucket,str(payload.item),int(payload.quantity));key="";refresh()
func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 elapsed+=delta
 if elapsed>=.25: elapsed=0;refresh()
