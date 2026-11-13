extends SceneTree
const Boundary = preload("res://persistence_authorization.gd")
const SENTINEL = "user://.mystical-garden-persistence.lock"
var failed := false

func check(ok: bool, description: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: persistence authorization: "+description)

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var garden := "user://cp1-garden.cfg"
 var profile := "user://cp1-character.cfg"
 var original_path := "user://cp1-original.cfg"
 var original := FileAccess.open(original_path,FileAccess.WRITE)
 check(original != null,"disposable fixture can be written")
 if original == null:
  quit(1)
  return
 original.store_string("unchanged")
 original.close()

 var captured := []
 var performed := []
 var outer := Boundary.run(PackedStringArray([garden,profile,original_path]), func(token):
  captured.append(token)
  var nested := Boundary.run_nested(token,PackedStringArray([profile]),func(child):
   check(child == token,"authorized nested callback reuses the token")
   performed.append("nested")
   return "nested value")
  check(nested.error == OK and nested.ran and nested.value == "nested value","authorized nesting")
  var refused := Boundary.run_nested(token,PackedStringArray(["user://undeclared.cfg"]),func(_child): performed.append("unauthorized"))
  check(refused.error == ERR_UNAUTHORIZED and not refused.ran,"participant set cannot expand")
  var foreign := Boundary.run_nested(RefCounted.new(),PackedStringArray([garden]),func(_child): performed.append("foreign"))
  check(foreign.error == ERR_UNAUTHORIZED and not foreign.ran,"unrelated token is refused")
  var fresh := Boundary.run(PackedStringArray([garden]),func(_child): performed.append("reentrant"))
  check(fresh.error == ERR_BUSY and not fresh.ran,"unrelated reentrant operation is refused")
  return ERR_CANT_CREATE)
 check(outer.error == OK and outer.ran and outer.value == ERR_CANT_CREATE,"callback failure value survives release")
 check(performed == ["nested"],"refused callbacks did not run")
 if not captured.is_empty():
  var expired := Boundary.run_nested(captured[0],PackedStringArray([garden]),func(_child): performed.append("expired"))
  check(expired.error == ERR_UNAUTHORIZED and not expired.ran,"token expires with the outer operation")
 else:
  check(false,"outer callback provided a token")
 var reacquired := Boundary.run(PackedStringArray([garden]),func(_token): return true)
 check(reacquired.error == OK and reacquired.ran and reacquired.value == true,"acquire after callback returns an error")
 for path in ["", "garden.cfg", "C:/temp/garden.cfg", "//server/share/garden.cfg", "res://garden.cfg",
              "user://../garden.cfg", "user://a/../garden.cfg", "user://a//garden.cfg", "user://a/./garden.cfg",
              "user://cp1-garden.cfg:stream", "user://CP1~1.cfg", "user://NUL.cfg", "user://trailing. ",
              "user://missing-parent/garden.cfg", SENTINEL, SENTINEL.to_upper()]:
  var invalid := Boundary.run(PackedStringArray([path]),func(_token): performed.append("invalid"))
  check(invalid.error == ERR_INVALID_PARAMETER and not invalid.ran,"unsupported path: "+path)
 check(performed == ["nested"],"no unsupported path authorized a callback")
 check(FileAccess.get_file_as_string(original_path) == "unchanged","fixture bytes preserved")
 check(not FileAccess.file_exists(garden) and not FileAccess.file_exists(profile),"lock does not create participant files")
 check(FileAccess.file_exists(SENTINEL),"sentinel remains after release")
 if not failed:
  print("PASS: persistence authorization scopes nesting, rejects ambiguous paths, and releases on callback error")
 quit(1 if failed else 0)
