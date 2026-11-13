extends RefCounted
## Preferences are independent of canonical save batches and recovery journals.

static func write(path: String, config: ConfigFile, network := false) -> Error:
 var leaf := path.get_file()
 if network:
  if leaf != "network.cfg": return ERR_INVALID_PARAMETER
 elif not (leaf == "settings.cfg" or leaf.ends_with("-settings.cfg") or leaf.ends_with(".settings")):
  return ERR_INVALID_PARAMETER
 var target := ProjectSettings.globalize_path(path)
 if target.contains("\\"):
  target = target.replace("\\","/")
 for component in target.split("/",false):
  if component in [".",".."] or component.ends_with(".") or component.ends_with(" "):
   return ERR_INVALID_PARAMETER
 if target.substr(2).contains(":"): return ERR_INVALID_PARAMETER
 var scratch := target + "." + Crypto.new().generate_random_bytes(12).hex_encode() + ".tmp"
 var output := FileAccess.open(scratch,FileAccess.WRITE)
 if output == null: return FileAccess.get_open_error()
 output.store_buffer(config.encode_to_text().to_utf8_buffer())
 output.flush()
 var error := output.get_error()
 output.close()
 if error == OK and not DirAccess.dir_exists_absolute(target):
  error=DirAccess.rename_absolute(scratch,target)
 elif error == OK:
  error=ERR_ALREADY_EXISTS
 if error != OK and FileAccess.file_exists(scratch): DirAccess.remove_absolute(scratch)
 return error
