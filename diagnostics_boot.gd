extends Node
const Journal=preload("res://diagnostic_journal.gd")
const Playtest=preload("res://playtest_storage.gd")
const Experiment=preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
var journal: Logger
var clock:=0.0
func _init() -> void:
 # Validate the separately deployed root before diagnostics can create files.
 if not preload("res://persistence_writer_integration.gd").startup_refusal().is_empty():
  return
 if Playtest.retail():
  Playtest.refusal=Playtest.inspect(Playtest.build())
  if not Playtest.refusal.is_empty():
   print("PLAYTEST BLOCKED: "+Playtest.refusal)
   return
  Playtest.inspected=true
 elif Experiment.requested():
  return
 journal=Journal.new();journal.start();Journal.current=journal;OS.add_logger(journal)
func _ready() -> void:
 add_child(FrameMeter.new())
func _process(delta: float) -> void:
 if journal==null: return
 clock+=delta
 if clock>=5:
  clock=0;Journal.event("session","heartbeat",{"fps":Engine.get_frames_per_second()});journal.status_file()
func _notification(what: int) -> void:
 if journal!=null and what==NOTIFICATION_CRASH:Journal.event("session","crash_notification",{},"error");journal.status_file()
func _exit_tree() -> void:
 if journal==null: return
 OS.remove_logger(journal);journal.finish();Journal.current=null


class FrameMeter extends CanvasLayer:
 const REFRESH_USEC := 250_000
 const PEAK_WINDOWS := 20
 var label: Label
 var previous := 0
 var elapsed := 0
 var count := 0
 var peak := 0
 var peaks: Array[int] = []

 func _ready() -> void:
  name = "FrameMeter"
  layer = 20
  process_mode = Node.PROCESS_MODE_ALWAYS
  label = Label.new()
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.add_theme_color_override("font_color", Color("#f5e9c7"))
  label.add_theme_color_override("font_outline_color", Color("#11100d"))
  label.add_theme_constant_override("outline_size", 6)
  add_child(label)
  label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
  label.offset_left = -235.0
  label.offset_right = -16.0
  label.offset_top = 58.0
  label.hide()
  set_process(false)

 func _input(event: InputEvent) -> void:
  if not event is InputEventKey or not event.pressed or event.echo:
   return
  if event.keycode != KEY_F3 and event.physical_keycode != KEY_F3:
   return
  if label.visible:
   label.hide()
   set_process(false)
  else:
   elapsed = 0
   count = 0
   peak = 0
   peaks.clear()
   previous = Time.get_ticks_usec()
   label.text = "Measuring frame time…"
   label.show()
   set_process(true)
  get_viewport().set_input_as_handled()

 func _process(_delta: float) -> void:
  var now := Time.get_ticks_usec()
  var frame := now - previous
  previous = now
  elapsed += frame
  count += 1
  peak = maxi(peak, frame)
  if elapsed < REFRESH_USEC:
   return
  peaks.append(peak)
  if peaks.size() > PEAK_WINDOWS:
   peaks.remove_at(0)
  label.text = "%d FPS · %.1f ms avg\nWorst ~5 s: %.1f ms" % [
   roundi(count * 1_000_000.0 / elapsed), elapsed / (1000.0 * count), int(peaks.max()) / 1000.0]
  elapsed = 0
  count = 0
  peak = 0
