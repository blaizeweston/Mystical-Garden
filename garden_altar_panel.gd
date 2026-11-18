extends VBoxContainer
const RootUI=preload("res://root_ui.gd")
const Items=preload("res://item_catalog.gd")
const Slot=preload("res://altar_input_slot.gd")
var game: Node
var tabs: TabBar
var recipe_pick: OptionButton
var identify_all_button: Button
var identify_button: Button
var storage_pick: OptionButton
var rarity_pick: OptionButton
var sort_button: Button
var grid: GridContainer
var inputs: Array[Control]=[]
var result_holder: HBoxContainer
var preview_text: Label
var details: RichTextLabel
var combine_button: Button
var clear_button: Button
var message: Label
var data: Dictionary={}
var draft: Array=[{},{}]
var revision:=0
var busy:=false
var sort_by_rarity:=false
var elapsed:=0.0
var pending_data: Dictionary={}
func _ready() -> void:
 var title:=Label.new();title.text="ALTAR";title.add_theme_font_size_override("font_size",23);add_child(title)
 var navigation:=HBoxContainer.new();add_child(navigation)
 tabs=TabBar.new();tabs.add_tab("Seeds · discover plants");tabs.add_tab("Plant parts · rarer materials");tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;navigation.add_child(tabs)
 tabs.tab_changed.connect(func(_index):
  if busy: return
  draft=[{},{}];request("preview"))
 identify_button=Button.new();navigation.add_child(identify_button)
 identify_button.pressed.connect(func(): request("identify"))
 identify_all_button=Button.new();identify_all_button.text="Identify all";navigation.add_child(identify_all_button);identify_all_button.pressed.connect(func(): request("identify_all"))
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);add_child(row)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=375;row.add_child(left)
 var hint:=Label.new();hint.text="Drag one ingredient into each slot.";hint.add_theme_font_size_override("font_size",14);left.add_child(hint)
 recipe_pick=OptionButton.new();recipe_pick.custom_minimum_size.x=370;left.add_child(recipe_pick)
 recipe_pick.item_selected.connect(func(index):
  if index<=0 or busy: return
  var recipe: Dictionary=recipe_pick.get_item_metadata(index)
  draft=[{"item":recipe.inputs[0],"source":source()},{"item":recipe.inputs[1],"source":source()}]
  request("preview"))
 var offerings:=HBoxContainer.new();offerings.alignment=BoxContainer.ALIGNMENT_CENTER;left.add_child(offerings)
 for index in 2:
  var holder:=VBoxContainer.new();offerings.add_child(holder);inputs.append(holder)
  if index==0:
   var plus:=Label.new();plus.text=" + ";plus.add_theme_font_size_override("font_size",28);offerings.add_child(plus)
 var result_title:=Label.new();result_title.text="Result";result_title.add_theme_font_size_override("font_size",14);left.add_child(result_title)
 var result_row:=HBoxContainer.new();left.add_child(result_row)
 result_holder=HBoxContainer.new();result_row.add_child(result_holder)
 preview_text=Label.new();preview_text.custom_minimum_size.x=270;preview_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;preview_text.add_theme_font_size_override("font_size",14);result_row.add_child(preview_text)
 details=RichTextLabel.new();details.bbcode_enabled=true;details.custom_minimum_size=Vector2(375,85);details.scroll_active=true;left.add_child(details)
 var right:=VBoxContainer.new();right.custom_minimum_size.x=446;row.add_child(right)
 var toolbar:=HBoxContainer.new();right.add_child(toolbar)
 storage_pick=OptionButton.new();storage_pick.add_item("Personal stash");storage_pick.add_item("Shared Garden");toolbar.add_child(storage_pick)
 storage_pick.item_selected.connect(func(_index): render())
 rarity_pick=OptionButton.new();rarity_pick.add_item("All rarities");toolbar.add_child(rarity_pick)
 for rarity in Items.RARITIES: rarity_pick.add_item(rarity)
 rarity_pick.item_selected.connect(func(_index): render())
 sort_button=Button.new();sort_button.text="Sort: Name";toolbar.add_child(sort_button)
 sort_button.pressed.connect(func(): sort_by_rarity=not sort_by_rarity;render())
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(446,300);right.add_child(scroll)
 grid=GridContainer.new();grid.columns=7;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
 var note:=Label.new();note.text="Uses one item per slot when confirmed. Failed combinations return materials and a clue.";note.custom_minimum_size.x=840;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_font_size_override("font_size",12);add_child(note)
 var actions:=HBoxContainer.new();add_child(actions)
 combine_button=Button.new();combine_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(combine_button);combine_button.pressed.connect(func(): request("combine"))
 clear_button=Button.new();clear_button.text="Clear slots";actions.add_child(clear_button);clear_button.pressed.connect(func(): draft=[{},{}];request("preview"))
 message=Label.new();message.custom_minimum_size=Vector2(840,34);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.add_theme_font_size_override("font_size",13);add_child(message)
 var close:=Button.new();close.text="Close · Esc";close.pressed.connect(func(): game.ui.close_panels());add_child(close)
func begin(value: Dictionary) -> void:
 revision=0;draft=[{},{}];busy=false;pending_data={};set_data(value)
func set_data(value: Dictionary) -> void:
 if int(value.get("revision",0))<revision: return
 if get_viewport().gui_is_dragging(): pending_data=value;return
 revision=int(value.get("revision",0));data=value;draft=value.get("draft",[{},{}]).duplicate(true);busy=false
 render()
func request(operation: String) -> void:
 if busy: return
 revision+=1
 if operation!="preview": busy=true
 game.send_altar_action(operation,draft.duplicate(true),revision)
 if is_instance_valid(combine_button): combine_button.disabled=busy or not data.get("preview",{}).get("can_combine",false)
func clear_children(node: Node) -> void:
 for child in node.get_children(): node.remove_child(child);child.queue_free()
func mode() -> String:
 return "seeds" if tabs.current_tab==0 else "parts"
func source() -> String:
 return "stash" if tabs.current_tab==0 or storage_pick.selected==0 else "shared"
func available(item: String,bucket: String,ignore_index: int=-1) -> int:
 var count:=0
 for stack in data.get(bucket,[]):
  if stack.item==item: count+=int(stack.quantity)
 for index in 2:
  if index==ignore_index: continue
  if draft[index].get("item","")==item and draft[index].get("source","")==bucket: count-=1
 return count
func render() -> void:
 if grid==null or get_viewport().gui_is_dragging(): return
 recipe_pick.clear();recipe_pick.add_item("Recorded recipes · %d / %d species"%[int(data.get("species_known",0)),int(data.get("species_total",Items.Seeds.DEFINITIONS.size()))])
 for recipe in data.get("recipes",[]):
  if recipe.mode!=mode(): continue
  recipe_pick.add_item(str(recipe.name));recipe_pick.set_item_metadata(recipe_pick.item_count-1,recipe)
 recipe_pick.disabled=busy or recipe_pick.item_count==1
 storage_pick.disabled=mode()=="seeds" or busy
 identify_all_button.disabled=busy or int(data.get("unknown",0))<=0
 identify_button.text="Identify · %d seeds"%int(data.get("unknown",0));identify_button.disabled=busy or int(data.get("unknown",0))<=0
 clear_button.disabled=busy
 sort_button.text="Sort: Rarity" if sort_by_rarity else "Sort: Name"
 for index in 2:
  clear_children(inputs[index])
  var entry: Dictionary={}
  if not draft[index].is_empty(): entry={"item":draft[index].item,"quantity":1,"origin":draft[index].source,"offering_index":index}
  var slot:=Slot.new();slot.offering_index=index;inputs[index].add_child(slot);slot.setup(self,entry,"offering_%d"%index,88)
  var text:=Label.new();text.text="Offering %d"%(index+1);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.add_theme_font_size_override("font_size",12);inputs[index].add_child(text)
 var entries: Array=[];var seen: Array=[]
 for stack in data.get(source(),[]):
  var item:=Items.get_item(stack.item)
  if item.category!=("seed" if mode()=="seeds" else "plant_part") or stack.item in ["unidentified_seed","boss_mystery_seed"]: continue
  if mode()=="seeds" and not item.has("legacy_seed"): continue
  if rarity_pick.selected>0 and item.rarity!=Items.RARITIES[rarity_pick.selected-1]: continue
  if seen.has(stack.item): continue
  seen.append(stack.item)
  var remaining:=available(stack.item,source())
  while remaining>0:
   var amount:=mini(remaining,int(item.stack_limit));entries.append({"item":stack.item,"quantity":amount,"bucket":source(),"key":source()+"|"+stack.item});remaining-=amount
 entries.sort_custom(func(a,b):
  var first:=Items.get_item(a.item);var second:=Items.get_item(b.item)
  if sort_by_rarity and first.rarity!=second.rarity: return Items.RARITIES.find(first.rarity)>Items.RARITIES.find(second.rarity)
  return str(first.name)<str(second.name))
 clear_children(grid)
 for entry in entries:
  var slot:=Slot.new();grid.add_child(slot);slot.setup(self,entry,source(),56)
 for index in maxi(0,28-entries.size()):
  var slot:=Slot.new();grid.add_child(slot);slot.setup(self,{},source(),56)
 var preview: Dictionary=data.get("preview",{})
 clear_children(result_holder)
 if preview.get("known",false) and not str(preview.get("item","")).is_empty():
  var result:=Slot.new();result_holder.add_child(result);result.setup(self,{"item":preview.item,"quantity":1},"equipment",80)
 else:
  var box:=PanelContainer.new();box.custom_minimum_size=Vector2(80,80);box.add_theme_stylebox_override("panel",RootUI.flat_style(Color("#142118"),Color("#8c8353"),2,4,4));result_holder.add_child(box)
  var question:=Label.new();question.text="?";question.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;question.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;question.add_theme_font_size_override("font_size",40);box.add_child(question)
 preview_text.text=str(preview.get("text","Place ingredients to preview the result."))
 combine_button.text="Sacrifice 2 seeds" if mode()=="seeds" else "Sacrifice 2 plant parts"
 combine_button.disabled=busy or not bool(preview.get("can_combine",false))
 message.text=str(data.get("message",""))
func can_accept(bucket: String,payload) -> bool:
 if busy or not payload is Dictionary or payload.get("type","")!="garden_item_stack": return false
 var origin:=str(payload.get("source",""));var item:=Items.get_item(str(payload.get("item","")))
 if origin not in ["stash","shared"] or item.is_empty() or item.category!=("seed" if mode()=="seeds" else "plant_part") or payload.get("item","") in ["unidentified_seed","boss_mystery_seed"]: return false
 if bucket in ["stash","shared"]: return payload.has("offering_index")
 if not bucket.begins_with("offering_"): return false
 var index:=int(bucket.trim_prefix("offering_"))
 if index not in [0,1]: return false
 if payload.has("offering_index"): return true
 return available(str(payload.item),origin,index)>0
func move_stack(bucket: String,payload: Dictionary,_target_key: String="") -> void:
 if not can_accept(bucket,payload): return
 if bucket in ["stash","shared"]: clear_input(int(payload.offering_index));return
 var index:=int(bucket.trim_prefix("offering_"))
 if payload.has("offering_index"):
  var previous:=int(payload.offering_index);var held: Dictionary=draft[index];draft[index]=draft[previous];draft[previous]=held
 else: draft[index]={"item":str(payload.item),"source":str(payload.source)}
 request("preview")
func clear_input(index: int) -> void:
 if busy or index not in [0,1]: return
 draft[index]={};request("preview")
func select_entry(entry: Dictionary) -> void:
 var item:=Items.get_item(str(entry.get("item","")))
 if item.is_empty(): return
 details.text="[b]%s[/b] · %s\n%s"%[item.name,item.rarity,item.description]
 if entry.has("offering_index"): details.text+="\nDouble-click this offering to remove it."
func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 if not pending_data.is_empty() and not get_viewport().gui_is_dragging():
  var pending:=pending_data;pending_data={};set_data(pending)
 if not game.at_garden_altar(game.players.get(game.local_player_id(),{})): game.ui.close_panels();return
 elapsed+=delta
 if elapsed>=.8 and not busy and not get_viewport().gui_is_dragging(): elapsed=0;request("preview")
