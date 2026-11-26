extends VBoxContainer
const AffinityBuild = preload("res://affinity_build.gd")
const Seeds = preload("res://seed_catalog.gd")
const Growth = preload("res://cultivation_growth.gd")
signal requested(command: String, data: Dictionary)
var selection_enabled := true
var slot:=-1
var selected:=-1
var counts: Array=[]
var communal: Array=[]
var source_pick: OptionButton
var grid: GridContainer
var details: Label
var confirm: Button
var title: Label
func _ready():
 title=Label.new();title.add_theme_font_size_override("font_size",23);add_child(title)
 var hint:=Label.new();hint.text="Choose a seed. Planting uses one.";add_child(hint)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(700,280);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
 grid=GridContainer.new();grid.columns=7;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 details=Label.new();details.custom_minimum_size=Vector2(700,76);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(details)
 source_pick=OptionButton.new();source_pick.fit_to_longest_item=false;source_pick.hide();add_child(source_pick)
 confirm=Button.new();confirm.text="Plant";confirm.disabled=true;add_child(confirm)
 confirm.pressed.connect(func():
  if selection_enabled and selected>=0 and source_pick.selected>=0:
   requested.emit("garden_action",{"action":"plant_at_%d_%d_%s"%[slot,selected,source_pick.get_selected_metadata()]}))
 var close:=Button.new();close.text="Cancel · Esc";add_child(close);close.pressed.connect(func(): requested.emit("close",{}))
func begin(bed: int,stock: Array,shared: Array=[]):
 slot=bed;counts=stock.duplicate();communal=shared.duplicate()
 if communal.size()!=counts.size():communal=Seeds.counts()
 selected=-1;source_pick.hide();source_pick.clear();title.text="Planting bed %d"%(slot+1);confirm.disabled=true
 for child in grid.get_children(): grid.remove_child(child);child.queue_free()
 var available:=0
 var selection_group:=ButtonGroup.new()
 for species in counts.size():
  if int(counts[species])+int(communal[species])<=0: continue
  available+=1
  var species_name: Dictionary=Seeds.DEFINITIONS[species]
  var plant_description := AffinityBuild.planting_description(species).get_slice("\nSupporting affinities",0)
  var button:=Button.new();button.toggle_mode=true;button.button_group=selection_group;button.custom_minimum_size=Vector2(90,96);button.tooltip_text="%s · %s\n%s"%[species_name.name,species_name.rarity,plant_description];button.disabled=not selection_enabled;grid.add_child(button)
  var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_theme_constant_override("separation",0)
  var icon:=TextureRect.new();icon.texture=load("res://assets/ui/seeds/"+str(species_name.id)+".png");icon.custom_minimum_size=Vector2(55,55);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(icon)
  var caption:=Label.new();caption.text=str(species_name.name);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  caption.clip_text=true;caption.add_theme_font_size_override("font_size",11);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(caption)
  var quantity:=Label.new();quantity.text="P %d · G %d"%[counts[species],communal[species]];quantity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;quantity.mouse_filter=Control.MOUSE_FILTER_IGNORE;quantity.add_theme_font_size_override("font_size",11);content.add_child(quantity)
  var inspect:=func():details.text="%s · %s\nPersonal %d · Shared %d · Base growth %s (2× during expeditions)\n%s"%[species_name.name,species_name.rarity,counts[species],communal[species],Growth.time_text(float(species_name.grow_seconds)),plant_description.get_slice("\n",0)]
  button.focus_entered.connect(func():
   if selected<0 or selected==species:inspect.call())
  button.pressed.connect(func():
   if not selection_enabled:return
   selected=species;inspect.call();source_pick.clear()
   if communal[species]>0:
    source_pick.add_item("Use shared Garden seed · %d available"%communal[species]);source_pick.set_item_metadata(source_pick.item_count-1,"shared")
   if counts[species]>0:
    source_pick.add_item("Use personal seed · %d available"%counts[species]);source_pick.set_item_metadata(source_pick.item_count-1,"stash")
   source_pick.select(0);source_pick.show();confirm.disabled=false)
 details.text="Choose a seed." if available>0 else "No seeds available. Bring home a wild plant’s seed or identify a mystery seed at the altar."


func set_selection_enabled(allowed: bool) -> void:
 if selection_enabled==allowed: return
 selection_enabled=allowed
 confirm.disabled=not allowed or selected<0
 source_pick.disabled=not allowed
 for button in grid.get_children(): button.disabled=not allowed
