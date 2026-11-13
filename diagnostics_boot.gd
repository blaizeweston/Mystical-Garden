extends Node
const Journal=preload("res://diagnostic_journal.gd")
var journal: Logger
var clock:=0.0
func _init() -> void:
 journal=Journal.new();journal.start();Journal.current=journal;OS.add_logger(journal)
func _process(delta: float) -> void:
 clock+=delta
 if clock>=5:
  clock=0;Journal.event("session","heartbeat",{"fps":Engine.get_frames_per_second()});journal.status_file()
func _notification(what: int) -> void:
 if what==NOTIFICATION_CRASH:Journal.event("session","crash_notification",{},"error");journal.status_file()
func _exit_tree() -> void:
 OS.remove_logger(journal);journal.finish();Journal.current=null
