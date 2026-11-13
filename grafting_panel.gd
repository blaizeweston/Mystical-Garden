extends VBoxContainer
# Specialized fourth-slot workbench. Preview data and attempt validation come from the host.
var game: Node
var data: Dictionary={}
var part_pick: OptionButton
var current: RichTextLabel
var preview: RichTextLabel
var component: Label
var warning: Label
var notice: Label
var attempt: Button
var selected: int=0
var busy:=false
func _ready() -> void:
 var heading:=Label.new();heading.text="GRAFTING ALTAR";heading.add_theme_font_size_override("font_size",23);add_child(heading)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",20);add_child(row)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=350;row.add_child(left)
 var current_title:=Label.new();current_title.text="Weapon";current_title.add_theme_font_size_override("font_size",18);left.add_child(current_title)
 current=RichTextLabel.new();current.bbcode_enabled=true;current.custom_minimum_size=Vector2(350,390);current.scroll_active=true;left.add_child(current)
 var right:=VBoxContainer.new();right.custom_minimum_size.x=450;row.add_child(right)
 var choice_title:=Label.new();choice_title.text="Monster part";choice_title.add_theme_font_size_override("font_size",18);right.add_child(choice_title)
 part_pick=OptionButton.new();part_pick.fit_to_longest_item=false;part_pick.custom_minimum_size.x=450;right.add_child(part_pick)
 part_pick.item_selected.connect(func(index): selected=part_pick.get_item_id(index);update_selection())
 component=Label.new();component.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;component.custom_minimum_size.x=450;right.add_child(component)
 preview=RichTextLabel.new();preview.bbcode_enabled=true;preview.custom_minimum_size=Vector2(450,260);preview.scroll_active=true;right.add_child(preview)
 warning=Label.new();warning.custom_minimum_size.x=820;warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;warning.add_theme_color_override("font_color",Color("#e3c58f"));add_child(warning)
 attempt=Button.new();add_child(attempt)
 attempt.pressed.connect(func():
  if selected<=0 or busy: return
  busy=true;attempt.disabled=true
  game.send_garden_action("graft_install_%d"%selected))
 notice=Label.new();notice.custom_minimum_size.x=820;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.add_theme_font_size_override("font_size",13);add_child(notice)
 var close:=Button.new();close.text="Close · Esc";close.pressed.connect(func(): game.toggle_overlay(null));add_child(close)
func set_data(value: Dictionary) -> void:
 data=value;busy=false
 part_pick.clear()
 for entry in data.get("options",[]): part_pick.add_item("%s · %d carried"%[entry.name,entry.count],int(entry.part))
 part_pick.disabled=part_pick.item_count==0
 var index:=part_pick.get_item_index(selected)
 if index<0: index=0
 if part_pick.item_count>0:
  part_pick.select(index);selected=part_pick.get_item_id(index)
 else: selected=0
 var body: String=""
 var slots: Array=data.get("slots",[0,0,0])
 for slot in 3: body+="%s: %s\n"%[game.Weapons.SLOT_NAMES[slot],game.Parts.part_name(int(slots[slot]))]
 body+="\n[b]Monster graft: %s[/b]\n\n%s"%[game.Parts.part_name(int(data.get("installed",0))),data.get("current","")]
 current.text=body
 update_selection()
func update_selection() -> void:
 var entry: Dictionary={}
 for option in data.get("options",[]):
  if int(option.part)==selected: entry=option;break
 var installed:=int(data.get("installed",0))
 warning.text="Uses one monster part, even on failure. Enemies remain active."
 if installed!=0: warning.text="Uses one new part. Success replaces %s. Failure keeps the current graft."%game.Parts.part_name(installed)
 if entry.is_empty():
  component.text="No monster parts carried. Find one or pack one at the Garden gate."
  preview.text="Graft a monster part into the fourth slot."
  attempt.text="No monster parts";attempt.disabled=true
 else:
  component.text="Tags: %s\nSuccess chance: %d%% · Cost: 1 carried component"%[", ".join(entry.tags),roundi(float(entry.chance)*100)]
  preview.text="[b]After grafting[/b]\n\n"+str(entry.preview)
  var reason:=str(entry.get("reason",""))
  if not reason.is_empty(): warning.text=reason+"\n"+warning.text
  attempt.text=("Replace graft" if installed!=0 else "Graft")+" · 1 %s"%entry.name
  attempt.disabled=busy or not reason.is_empty() or not game.at_graft_altar(game.players.get(game.local_player_id(),{}))
 notice.text=str(data.get("status",""))
func _process(_delta: float) -> void:
 if not is_visible_in_tree(): return
 if not game.at_graft_altar(game.players.get(game.local_player_id(),{})):
  game.toggle_overlay(null)
  return
