extends Node
const Journal=preload("res://diagnostic_journal.gd")
const Playtest=preload("res://playtest_storage.gd")
var journal: Logger
var clock:=0.0
func _init() -> void:
 if Playtest.retail():
  Playtest.refusal=Playtest.inspect(Playtest.build())
  if not Playtest.refusal.is_empty():
   print("PLAYTEST BLOCKED: "+Playtest.refusal)
   return
 journal=Journal.new();journal.start();Journal.current=journal;OS.add_logger(journal)
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
