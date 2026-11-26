extends VBoxContainer
const Items=preload("res://item_catalog.gd")
const Builds=preload("res://affinity_build.gd")
const Slot=preload("res://inventory_slot.gd")
const Weapons = preload("res://weapon_system.gd")
const Parts = preload("res://weapon_parts.gd")
signal refresh_requested
signal requested(command: String, data: Dictionary)
var heading: Label
var storage_pick: OptionButton
var filter_pick: OptionButton
var rarity_pick: OptionButton
var sort_pick: OptionButton
var sort_button: Button
var search: LineEdit
var grid: GridContainer
var grid_scroll: ScrollContainer
var empty_hint: Label
var pouch_row: VBoxContainer
var pouch_holder: HBoxContainer
var equipment: HBoxContainer
var core_skill: Label
var transfer_button: Button
var transfer_quantity: SpinBox
var quantity_row: HBoxContainer
var select_all: Button
var withdrawal_toggle: CheckButton
var details: RichTextLabel
var notice: Label
var state: Dictionary={}
var shown: Array=[]
var selected: Dictionary={}
var order: Dictionary={}
var ascending:=true
var key: String=""
var grid_key: String=""
var equipment_key: String=""
var pouch_key: String=""
var quantity_key: String=""
var elapsed:=0.0
const PAGE_SIZE:=40
var page:=0
var page_label: Label
var previous_page: Button
var next_page: Button
func _ready() -> void:
 add_theme_constant_override("separation",8)
 var header:=HBoxContainer.new();add_child(header)
 heading=Label.new();heading.add_theme_font_size_override("font_size",22);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading)
 withdrawal_toggle=CheckButton.new();withdrawal_toggle.text="Allow guest withdrawals";header.add_child(withdrawal_toggle)
 withdrawal_toggle.toggled.connect(func(allowed: bool):
  if not state.get("can_manage_withdrawals",false):return
  requested.emit("inventory_withdrawals",{"allowed":allowed});key="";refresh())
 var tools:=HBoxContainer.new();tools.add_theme_constant_override("separation",8);add_child(tools)
 storage_pick=OptionButton.new();tools.add_child(storage_pick)
 filter_pick=OptionButton.new();tools.add_child(filter_pick)
 for text in ["All items","Seeds","Plant parts","Trophies","Other items"]: filter_pick.add_item(text)
 search=LineEdit.new();search.placeholder_text="Search items";search.clear_button_enabled=true;search.custom_minimum_size.x=220
 search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(search)
 search.text_changed.connect(func(_text):page=0;selected={};key="";refresh())
 var navigation:=HBoxContainer.new();navigation.add_theme_constant_override("separation",8);add_child(navigation)
 rarity_pick=OptionButton.new();navigation.add_child(rarity_pick)
 rarity_pick.add_item("All rarities")
 for rarity in Items.RARITIES: rarity_pick.add_item(rarity)
 sort_pick=OptionButton.new();navigation.add_child(sort_pick)
 for text in ["Name","Rarity","Type","Quantity"]: sort_pick.add_item(text)
 sort_button=Button.new();sort_button.text="Sort ↑";navigation.add_child(sort_button)
 sort_button.pressed.connect(func(): ascending=not ascending;order.clear();key="";refresh())
 for option in [storage_pick,filter_pick,rarity_pick,sort_pick]: option.item_selected.connect(func(_index): page=0;selected={};key="";refresh())
 var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;navigation.add_child(spacer)
 previous_page=Button.new();previous_page.text="Previous";navigation.add_child(previous_page)
 page_label=Label.new();navigation.add_child(page_label)
 next_page=Button.new();next_page.text="Next";navigation.add_child(next_page)
 previous_page.pressed.connect(func():page=maxi(0,page-1);selected={};key="";refresh())
 next_page.pressed.connect(func():page+=1;selected={};key="";refresh())
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);add_child(row)
 var storage_area:=VBoxContainer.new();row.add_child(storage_area)
 grid_scroll=ScrollContainer.new();grid_scroll.custom_minimum_size=Vector2(570,350);grid_scroll.follow_focus=true;storage_area.add_child(grid_scroll)
 grid=GridContainer.new();grid.columns=8;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);grid_scroll.add_child(grid)
 empty_hint=Label.new();empty_hint.custom_minimum_size=Vector2(570,350);empty_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 empty_hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;empty_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 storage_area.add_child(empty_hint);empty_hint.hide()
 var side:=VBoxContainer.new();side.custom_minimum_size.x=240;side.add_theme_constant_override("separation",7);row.add_child(side)
 var label:=Label.new();label.text="Equipped / prepared";side.add_child(label)
 equipment=HBoxContainer.new();side.add_child(equipment)
 core_skill=Label.new();core_skill.add_theme_color_override("font_color",Color("#c8df99"));core_skill.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;side.add_child(core_skill)
 pouch_row=VBoxContainer.new();side.add_child(pouch_row)
 var pouch_label:=Label.new();pouch_label.text="Safe pouch · 1 stack";pouch_row.add_child(pouch_label)
 pouch_holder=HBoxContainer.new();pouch_row.add_child(pouch_holder)
 details=RichTextLabel.new();details.bbcode_enabled=true;details.custom_minimum_size=Vector2(240,156);details.scroll_active=true
 details.size_flags_vertical=Control.SIZE_EXPAND_FILL;side.add_child(details)
 quantity_row=HBoxContainer.new();side.add_child(quantity_row)
 var amount_label:=Label.new();amount_label.text="Quantity";quantity_row.add_child(amount_label)
 transfer_quantity=SpinBox.new();transfer_quantity.min_value=1;transfer_quantity.max_value=1;transfer_quantity.step=1
 transfer_quantity.custom_minimum_size.x=76;transfer_quantity.size_flags_horizontal=Control.SIZE_EXPAND_FILL;quantity_row.add_child(transfer_quantity)
 select_all=Button.new();select_all.text="All";quantity_row.add_child(select_all)
 select_all.pressed.connect(func():transfer_quantity.value=transfer_quantity.max_value)
 transfer_button=Button.new();side.add_child(transfer_button)
 transfer_button.pressed.connect(func():
  if selected.is_empty() or transfer_button.disabled:return
  var amount:=int(transfer_quantity.value)
  if amount<=0 or amount>transfer_limit():return
  requested.emit("inventory_transfer",{"source":str(selected.bucket),"target":transfer_target(),"item":str(selected.item),"quantity":amount});key="";refresh())
 notice=Label.new();notice.custom_minimum_size.x=820;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.add_theme_font_size_override("font_size",12);add_child(notice)
 refresh()
func _restore_focus(cell: Control) -> void:
 if is_instance_valid(cell) and cell.is_inside_tree() and cell.is_visible_in_tree():
  cell.grab_focus()

func clear_children(node: Node) -> void:
 for child in node.get_children(): node.remove_child(child);child.queue_free()
func source() -> String:
 return "carry" if bool(state.get("wild",false)) else "all" if storage_pick.selected==0 else "shared" if storage_pick.selected==2 else "stash"
func refresh() -> void:
 if grid==null or get_viewport().gui_is_dragging(): return
 refresh_requested.emit()

func present(fresh: Dictionary) -> void:
 if grid==null or get_viewport().gui_is_dragging(): return
 fresh=fresh.duplicate(true)
 if fresh.is_empty(): return
 var next_key:=str(fresh)+str([storage_pick.selected,filter_pick.selected,rarity_pick.selected,sort_pick.selected,search.text,ascending,order,page])
 if next_key==key: return
 var changed_mode: bool=state.get("wild",null)!=fresh.wild
 state=fresh
 if changed_mode: selected={};page=0
 if changed_mode or storage_pick.item_count==0:
  storage_pick.clear()
  if state.wild: storage_pick.add_item("Backpack")
  else: storage_pick.add_item("All Garden storage");storage_pick.add_item("Personal stash");storage_pick.add_item("Shared Garden")
 storage_pick.disabled=bool(state.wild)
 key=str(fresh)+str([storage_pick.selected,filter_pick.selected,rarity_pick.selected,sort_pick.selected,search.text,ascending,order,page])
 sort_button.text="Sort ↑" if ascending else "Sort ↓"
 heading.text="Backpack" if state.wild else "Garden inventory"
 withdrawal_toggle.visible=not state.wild and state.get("can_manage_withdrawals",false)
 withdrawal_toggle.set_pressed_no_signal(bool(state.get("guest_withdrawals",true)))
 shown=[]
 for entry in (state.get("stash",[])+state.get("shared",[]) if source()=="all" else state.get(source(),[])):
  var item:=Items.get_item(str(entry.item))
  var categories: Array=["","seed","plant_part","monster_part","other"]
  var wanted: String=categories[filter_pick.selected]
  if wanted=="other" and item.category in ["seed","plant_part","monster_part"]: continue
  if wanted!="" and wanted!="other" and wanted!=item.category: continue
  if rarity_pick.selected>0 and item.rarity!=Items.RARITIES[rarity_pick.selected-1]: continue
  var query:=search.text.strip_edges().to_lower()
  if not query.is_empty() and query not in str(item.name).to_lower() and query not in " ".join(item.tags).to_lower():continue
  shown.append(entry)
 shown.sort_custom(compare_entries)
 var pages:=maxi(1,ceili(shown.size()/float(PAGE_SIZE)));page=clampi(page,0,pages-1)
 page_label.text="%d / %d · %d stacks"%[page+1,pages,shown.size()];previous_page.disabled=page==0;next_page.disabled=page>=pages-1
 var visible_entries: Array=shown.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE)
 grid_scroll.visible=not visible_entries.is_empty()
 empty_hint.visible=visible_entries.is_empty()
 empty_hint.text="No items match these filters." if not search.text.is_empty() or filter_pick.selected>0 or rarity_pick.selected>0 else "This storage is empty."
 var new_grid_key:=str([source(),visible_entries])
 if new_grid_key!=grid_key:
  var focused:=get_viewport().gui_get_focus_owner()
  var focus_key: String=focused.entry.get("key","") if focused is Slot and focused.get_parent()==grid else ""
  clear_children(grid)
  var restored_focus: Control
  for entry in visible_entries:
   var cell:=add_slot(grid,entry,str(entry.bucket))
   if entry.key==focus_key:restored_focus=cell
  for empty in maxi(0,PAGE_SIZE-visible_entries.size()):add_slot(grid,{},source())
  grid_key=new_grid_key
  if restored_focus!=null:_restore_focus.call_deferred(restored_focus)
  elif not focus_key.is_empty():_restore_focus.call_deferred(storage_pick)
 var equipment_entries: Array=[]
 var build: Dictionary=state.get("affinity_build",{})
 var core: Dictionary=Builds.core_skill(build) if not build.is_empty() else {}
 var core_name: String=core.get("name","")
 var summary: String=slot_description(0)
 core_skill.visible=not core_name.is_empty()
 core_skill.text="Core skill · "+core_name
 core_skill.tooltip_text=summary
 core_skill.mouse_filter=Control.MOUSE_FILTER_PASS
 var new_equipment_key:=str([state.equipment,build])
 if new_equipment_key!=equipment_key:clear_children(equipment)
 for index in state.equipment.size():
  var part:=int(state.equipment[index])
  var entry: Dictionary={"item":Items.part_id(part),"quantity":1,"bucket":"equipment","key":"equipment:%d"%index,"slot":index} if part>0 else {}
  if not entry.is_empty(): equipment_entries.append(entry)
  if new_equipment_key!=equipment_key:
   var slot:=add_slot(equipment,entry,"equipment",48)
   slot.tooltip_text=Weapons.SLOT_NAMES[index]+": "+Parts.part_name(part)
   var slot_text:=slot_description(index)
   if not slot_text.is_empty(): slot.tooltip_text+="\n\n"+slot_text
 equipment_key=new_equipment_key
 pouch_row.visible=bool(state.wild)
 details.custom_minimum_size.y=106 if state.wild else 156
 var new_pouch_key:=str([state.wild,state.get("pouch",[])])
 if new_pouch_key!=pouch_key:
  clear_children(pouch_holder);pouch_key=new_pouch_key
 if state.wild and pouch_holder.get_child_count()==0:
  var held: Array=state.get("pouch",[])
  add_slot(pouch_holder,held[0] if not held.is_empty() else {},"pouch")
  var tip:=Label.new();tip.text="Drag a stack here\nto protect it.";tip.add_theme_font_size_override("font_size",12);pouch_holder.add_child(tip)
 notice.text="Drag outside to drop · Shift + drag for one item."
 if not state.wild: notice.text+=" · R = reserved for equipment or cargo."
 if not state.wild and not state.get("may_withdraw",true):notice.text+=" Guest withdrawals from shared storage are disabled."
 if not str(fresh.get("notice","")).is_empty():notice.text+="\n"+str(fresh.get("notice",""))
 var candidates: Array=visible_entries.duplicate()
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
 for holder in [grid,equipment,pouch_holder]:
  for item in holder.get_children():
   if item is Slot:item.set_selected(not selected.is_empty() and item.entry.get("key","") == selected.get("key",""))
 if selected.get("bucket","")=="equipment":
  transfer_button.hide()
  quantity_row.hide()
  var slot: int=selected.slot
  var selected_item:=Items.get_item(str(selected.item))
  var summary: String=slot_description(slot)
  details.text="[b]%s[/b]\n%s"%[selected_item.name,Weapons.SLOT_NAMES[slot]]
  if not selected_item.tags.is_empty(): details.text+=" · "+", ".join(selected_item.tags)
  if not summary.is_empty(): details.text+="\n\n"+summary
  return
 transfer_button.show()
 quantity_row.show()
 var target:=transfer_target()
 transfer_button.text={"stash":"Move to personal stash","shared":"Move to shared Garden","carry":"Move to backpack","pouch":"Protect in safe pouch"}.get(target,"Move item")
 var maximum:=transfer_limit()
 var previous:=int(transfer_quantity.value) if quantity_key==selected.get("key","") else 1
 quantity_key=str(selected.get("key",""))
 transfer_quantity.min_value=0 if maximum==0 else 1
 transfer_quantity.max_value=maximum
 transfer_quantity.set_value_no_signal(clampi(previous,int(transfer_quantity.min_value),maximum))
 transfer_quantity.editable=maximum>0
 select_all.disabled=maximum<=1
 transfer_button.disabled=maximum<=0
 if selected.is_empty():
  details.text="No matching items." if shown.is_empty() else "Select an item."
  return
 var item:=Items.get_item(str(selected.get("item","")))
 if item.is_empty(): return
 var description:=Items.describe(item)
 if item.category=="monster_part":
  description="A trophy that can fund an expedition improvement at a Grafting Altar."
 var owned:=int(selected.quantity)
 var free:=int(selected.get("free",owned))
 var location: String={"stash":"Personal stash","shared":"Shared Garden","carry":"Backpack","pouch":"Safe pouch"}.get(selected.bucket,"")
 details.text="[b]%s[/b]\n%s · %s\n%s · %d in stack"%[item.name,item.rarity,item.category.replace("_"," ").capitalize(),location,owned]
 if free<owned:details.text+="\n%d available · %d reserved"%[free,owned-free]
 details.text+="\n\n"+description
 if not item.tags.is_empty():details.text+="\n\nAffinities: "+", ".join(item.tags)
 if not item.monster_tags.is_empty():details.text+="\nMonster traits: "+", ".join(item.monster_tags)

func transfer_target() -> String:
 var bucket: String=selected.get("bucket","")
 if bucket=="stash":return "shared"
 if bucket=="shared":return "stash"
 if bucket=="carry":return "pouch"
 if bucket=="pouch":return "carry"
 return ""

func transfer_limit() -> int:
 if selected.is_empty() or selected.get("bucket","")=="equipment":return 0
 var item:=Items.get_item(str(selected.item))
 var amount:=int(selected.get("free",selected.quantity))
 var target:=transfer_target()
 if target=="pouch":
  if not item.get("pouch_allowed",true):return 0
  var protected: Array=state.get("pouch",[])
  if not protected.is_empty():
   if protected[0].item!=selected.item:return 0
   amount=mini(amount,int(item.stack_limit)-int(protected[0].quantity))
 if target=="stash" and selected.get("bucket","")=="shared" and not state.get("may_withdraw",true):return 0
 if target=="shared" and not (item.has("legacy_part") or item.get("category","")=="seed"):return 0
 return maxi(0,amount)
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
 if bucket=="stash" and payload.get("source","")=="shared" and not state.get("may_withdraw",true):return false
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
  requested.emit("inventory_transfer",{"source":str(payload.source),"target":bucket,"item":str(payload.item),"quantity":int(payload.quantity)});key="";refresh()
func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 elapsed+=delta
 if elapsed>=.25: elapsed=0;refresh()
