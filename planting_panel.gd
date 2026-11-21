extends VBoxContainer
const AffinityBuild = preload("res://affinity_build.gd")
const Seeds = preload("res://seed_catalog.gd")
const Growth = preload("res://cultivation_growth.gd")
signal requested(command: String, data: Dictionary)
var selection_enabled := true
var slot:=-1
var selected:=-1
var counts: Array=[]
var grid: GridContainer
var details: Label
var confirm: Button
var title: Label
func _ready():
 title=Label.new();title.add_theme_font_size_override("font_size",23);add_child(title)
 var hint:=Label.new();hint.text="Choose a seed. Planting uses one.";add_child(hint)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(700,280);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
 grid=GridContainer.new();grid.columns=7;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 details=Label.new();details.custom_minimum_size=Vector2(700,76);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(details)
 confirm=Button.new();confirm.text="Plant";confirm.disabled=true;add_child(confirm)
 confirm.pressed.connect(func():
  if selection_enabled and selected>=0: requested.emit("garden_action",{"action":"plant_at_%d_%d"%[slot,selected]}))
 var close:=Button.new();close.text="Cancel · Esc";add_child(close);close.pressed.connect(func(): requested.emit("close",{}))
func begin(bed: int,stock: Array):
 slot=bed;counts=stock.duplicate();selected=-1;title.text="PLANTING BED %d"%(slot+1);confirm.disabled=true
 for child in grid.get_children(): grid.remove_child(child);child.queue_free()
 var available:=0
 var selection_group:=ButtonGroup.new()
 for species in counts.size():
  if int(counts[species])<=0: continue
  available+=1
  var species_name: Dictionary=Seeds.DEFINITIONS[species]
  var plant_description := AffinityBuild.planting_description(species)
  var button:=Button.new();button.toggle_mode=true;button.button_group=selection_group;button.custom_minimum_size=Vector2(90,96);button.tooltip_text="%s · %s\n%s"%[species_name.name,species_name.rarity,plant_description];button.disabled=not selection_enabled;grid.add_child(button)
  var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_theme_constant_override("separation",0)
  var icon:=TextureRect.new();icon.texture=load("res://assets/ui/seeds/"+str(species_name.id)+".png");icon.custom_minimum_size=Vector2(68,68);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(icon)
  var quantity:=Label.new();quantity.text="×%d"%int(counts[species]);quantity.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;quantity.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(quantity)
  button.pressed.connect(func():
   if not selection_enabled:return
   selected=species;details.text="%s · %s · %d available\nBase growth: %s · 2× in the Wilds, plus Knowledge and watering bonuses\n%s"%[species_name.name,species_name.rarity,counts[species],Growth.time_text(float(species_name.grow_seconds)),plant_description];confirm.disabled=false)
 details.text="Choose a seed." if available>0 else "No seeds available. Identify mysterious seeds at the Altar."


func set_selection_enabled(allowed: bool) -> void:
 if selection_enabled==allowed: return
 selection_enabled=allowed
 confirm.disabled=not allowed or selected<0
 for button in grid.get_children(): button.disabled=not allowed
