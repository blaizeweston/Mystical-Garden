extends RefCounted
const Preferences=preload("res://preference_file.gd")
const ACTIONS: Dictionary={"up":"Move up","down":"Move down","left":"Move left","right":"Move right","attack":"Strike (hold to repeat)","interact":"Interact / collect","dodge":"Dodge","class_skill":"Class skill 1","class_skill_two":"Class skill 2","core_skill":"Core skill","card_active_one":"Card action 1","card_active_two":"Card action 2","card_active_three":"Card action 3","card_active_four":"Card action 4","extract":"Extract","pouch":"Safe pouch","flower":"Harvest seeds","graft":"Grafting altar","pack_menu":"Inventory","progression":"Progression trees","developer_workbench":"Developer Testing Arena","workbench":"Weapon workbench","field_guide":"Field guide","floor_map":"Expand floor map","run_summary":"Expedition summary","session_menu":"Pause / menu","upgrade_power":"Upgrade card 1","upgrade_technique":"Upgrade card 2","upgrade_synergy":"Upgrade card 3","upgrade_fourth":"Upgrade card 4"}
const KEYS: Dictionary={"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"attack":[KEY_SPACE],"interact":[KEY_E],"dodge":[KEY_SHIFT],"class_skill":[KEY_Q],"class_skill_two":[KEY_R],"core_skill":[KEY_B],"card_active_one":[KEY_Z],"card_active_two":[KEY_X],"card_active_three":[],"card_active_four":[],"extract":[KEY_T],"pouch":[KEY_P],"flower":[KEY_F],"graft":[KEY_G],"pack_menu":[KEY_I],"progression":[KEY_O],"developer_workbench":[KEY_F4],"workbench":[KEY_F2],"field_guide":[KEY_F1],"floor_map":[KEY_M],"run_summary":[KEY_TAB],"session_menu":[KEY_ESCAPE],"upgrade_power":[KEY_1],"upgrade_technique":[KEY_2],"upgrade_synergy":[KEY_3],"upgrade_fourth":[KEY_4]}
const LEGACY: Dictionary={"expand_plot":[],"research":[],"craft":[KEY_C],"experiment":[],"select_graft":[KEY_V],"frame":[],"trait":[],"donate":[],"select_donation":[],"destination":[],"catalyst":[]}
const FPS: Array=[0,60,120,144,165,240]
var path: String="user://settings.cfg"
var values: Dictionary=defaults()
static func defaults() -> Dictionary:
 var bindings: Dictionary={}
 for action in KEYS:
  bindings[action]=[]
  for code in KEYS[action]:bindings[action].append({"kind":"key","code":int(code)})
 bindings.attack.append({"kind":"mouse","code":MOUSE_BUTTON_LEFT})
 return {"bindings":bindings,"fullscreen":false,"vsync":true,"fps":120,"master":.5,"effects":.5,"music":.5,"ambience":.5,"aim_indicator":true,"ambient_motion":true,"garden_cinematics":true,"developer_mode":false}
static func binding(value) -> Dictionary:
 if not value is Dictionary:return {}
 var code=value.get("code",0)
 if not code is int or int(code)<=0:return {}
 if value.get("kind","")=="mouse" and int(code) in [1,2,3,8,9]:return {"kind":"mouse","code":int(code)}
 if value.get("kind","")=="key" and int(code)<=KEY_SPECIAL+65535:return {"kind":"key","code":int(code)}
 return {}
static func normalize(value) -> Dictionary:
 var result=defaults()
 if not value is Dictionary:return result
 for key in ["fullscreen","vsync","aim_indicator","ambient_motion","garden_cinematics","developer_mode"]:
  if value.get(key) is bool:result[key]=value[key]
 if value.get("fps") is int and FPS.has(int(value.fps)):result.fps=int(value.fps)
 for key in ["master","effects","music","ambience"]:
  if (value.get(key) is int or value.get(key) is float) and is_finite(float(value[key])):result[key]=clampf(float(value[key]),0,1)
 var source=value.get("bindings",{})
 if source is Dictionary:
  for action in ACTIONS:
   if not source.get(action) is Array:continue
   var clean: Array=[]
   for entry in source[action].slice(0,2):
    var item=binding(entry)
    if not item.is_empty() and (item.kind!="key" or item.code!=KEY_ESCAPE or action=="session_menu") and not clean.has(item):clean.append(item)
   result.bindings[action]=clean
 # Existing profiles may already use the new shortcut for another action.
 if source is Dictionary and not source.has("core_skill"):
  var assigned: Array = []
  for action in result.bindings:
   # Preserve established actions before assigning newly introduced card shortcuts.
   if action=="core_skill" or (action.begins_with("card_active_") and not source.has(action)):continue
   assigned.append_array(result.bindings[action])
  result.bindings.core_skill=[]
  for code in [KEY_B,KEY_X,KEY_Z]:
   var candidate: Dictionary={"kind":"key","code":int(code)}
   if not assigned.has(candidate):
    result.bindings.core_skill=[candidate]
    break
 if source is Dictionary and not source.has("run_summary"):
  var tab:= {"kind":"key","code":int(KEY_TAB)}
  for action in result.bindings:
   if action!="run_summary" and result.bindings[action].has(tab):
    result.bindings.run_summary=[]
    break
 # Newly available card bindings never take over an existing customized key.
 for action in ["card_active_one","card_active_two","card_active_three","card_active_four"]:
  if source is Dictionary and not source.has(action):
   for other in result.bindings:
    if other!=action and result.bindings[other].any(func(item):return result.bindings[action].has(item)):
     result.bindings[action]=[];break
 # Escape is an immutable recovery route, even if the pause shortcut is customized.
 if not result.bindings.session_menu.has({"kind":"key","code":KEY_ESCAPE}):result.bindings.session_menu.append({"kind":"key","code":KEY_ESCAPE})
 return result
func load_settings() -> Error:
 var file=ConfigFile.new();var error=file.load(path)
 values=normalize(file.get_value("settings","values",{})) if error==OK else defaults()
 return error
func save_settings(value: Dictionary) -> Error:
 var clean=normalize(value);var file=ConfigFile.new();file.set_value("settings","values",clean)
 var error=Preferences.write(path,file)
 if error==OK:values=clean;apply()
 return error
static func event_for(item: Dictionary) -> InputEvent:
 if item.kind=="mouse":
  var mouse=InputEventMouseButton.new();mouse.button_index=int(item.code);return mouse
 var key=InputEventKey.new();key.physical_keycode=int(item.code);return key
static func binding_text(item: Dictionary) -> String:
 if item.is_empty():return "Unbound"
 if item.kind=="mouse":return {1:"Left mouse",2:"Right mouse",3:"Middle mouse",8:"Mouse 4",9:"Mouse 5"}.get(int(item.code),"Mouse")
 return OS.get_keycode_string(int(item.code))
static func hint(action: String) -> String:
 if not InputMap.has_action(action):return "Unbound"
 var events=InputMap.action_get_events(action)
 if events.is_empty():return "Unbound"
 var event=events[0]
 return binding_text({"kind":"mouse","code":int(event.button_index)}) if event is InputEventMouseButton else OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
func apply() -> void:
 for action in LEGACY:
  if not InputMap.has_action(action):InputMap.add_action(action)
  InputMap.action_erase_events(action)
  for code in LEGACY[action]:InputMap.action_add_event(action,event_for({"kind":"key","code":int(code)}))
 for action in ACTIONS:
  if not InputMap.has_action(action):InputMap.add_action(action)
  InputMap.action_erase_events(action)
  for item in values.bindings[action]:InputMap.action_add_event(action,event_for(item))
 # Customized controls take priority over retired iteration shortcuts.
 for old in LEGACY:
  for event in InputMap.action_get_events(old):
   for action in ACTIONS:
    if InputMap.action_has_event(action,event):InputMap.action_erase_event(old,event);break
 for bus_name in ["SFX","Music","Ambience"]:
  if AudioServer.get_bus_index(bus_name)<0:
   AudioServer.add_bus()
   var bus := AudioServer.bus_count-1
   AudioServer.set_bus_name(bus,bus_name)
   AudioServer.set_bus_send(bus,"Master")
 for pair in [["Master",values.master],["SFX",values.effects],["Music",values.music],["Ambience",values.ambience]]:
  var index := AudioServer.get_bus_index(pair[0])
  AudioServer.set_bus_mute(index,float(pair[1])<=0.0)
  AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,float(pair[1]))))
 Engine.max_fps=int(values.fps)
 if DisplayServer.get_name()!="headless":
  # The editor owns an embedded play window; retain its saved fullscreen
  # preference for standalone launches without requesting an unsupported mode.
  if not Engine.is_embedded_in_editor():
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
