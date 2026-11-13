extends VBoxContainer
const Journal=preload("res://diagnostic_journal.gd")
var status: Label
var note: LineEdit
func _ready() -> void:
 name="Diagnostics";add_theme_constant_override("separation",12)
 var explanation=Label.new();add_child(explanation);explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;explanation.text="Diagnostic logs are saved automatically on this computer. They include gameplay events, network state and engine errors. Nothing is uploaded automatically. These tools take effect immediately. Export a report after a problem; ask the host and affected guests to export theirs too."
 var detail=CheckBox.new();add_child(detail);detail.text="Detailed tracing for this session (more combat events)";detail.button_pressed=Journal.current.detail if is_instance_valid(Journal.current) else false
 detail.toggled.connect(func(value):
  if is_instance_valid(Journal.current):Journal.current.detail=value;Journal.event("diagnostics","detail_changed",{"enabled":value}))
 note=LineEdit.new();add_child(note);note.placeholder_text="Optional note: what just went wrong?";note.max_length=300
 var row=HBoxContainer.new();add_child(row)
 button(row,"Mark issue",mark_issue);button(row,"Open logs",open_logs);button(row,"Export report",export_report)
 status=Label.new();add_child(status);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.text="Logs: "+ProjectSettings.globalize_path("user://diagnostics")
 var limit=Label.new();add_child(limit);limit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;limit.text="Logs rotate automatically. Reports include the current session and up to two recent inactive sessions, helping after a restart. A hard crash or power loss may leave breadcrumbs without an error stack."
func button(parent: Node,title: String,action: Callable) -> void:
 var b=Button.new();parent.add_child(b);b.text=title;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(action)
func mark_issue() -> void:
 var seq=Journal.event("diagnostics","user_issue",{"note":note.text})
 status.text="Issue marked at event %d. Export a report to keep or share it."%seq if seq>0 else "Logging is unavailable. Check available disk space."
func open_logs() -> void:
 var path=ProjectSettings.globalize_path("user://diagnostics")
 status.text="Logs: "+path if OS.shell_open(path)==OK else "Could not open the folder: "+path
func export_report() -> void:
 if not is_instance_valid(Journal.current):status.text="Logging is unavailable.";return
 var path: String=Journal.current.export_report()
 status.text="Report saved: "+path if not path.is_empty() else "Could not export the report. Check available disk space."
 if not path.is_empty():DisplayServer.clipboard_set(path)
