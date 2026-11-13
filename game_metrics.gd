extends RefCounted
# Local gameplay metrics only: no names, identities or network transmission.
static var pending: Array=[]
static var path: String="user://metrics.jsonl"
static func record(event: String,fields: Dictionary={}) -> void:
 if preload("res://save_batch.gd").active: pending.append({"event":event,"fields":fields.duplicate(true)});return
 preload("res://diagnostic_journal.gd").event("gameplay",event,fields)
 if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size()>2097152:
  if FileAccess.file_exists(path+".previous"): DirAccess.remove_absolute(path+".previous")
  DirAccess.rename_absolute(path,path+".previous")
 var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
 if file==null: return
 file.seek_end();var data: Dictionary=fields.duplicate(true);data.event=event;data.time=Time.get_ticks_msec();file.store_line(JSON.stringify(data));file.close()

static func flush(success: bool) -> void:
 var events: Array=pending.duplicate();pending.clear()
 if success:
  for entry in events: record(entry.event,entry.fields)
