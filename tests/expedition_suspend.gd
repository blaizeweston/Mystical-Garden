extends SceneTree
## A real process boundary catches invalid saved object references and wall-clock deadlines.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("MYSTICAL_VALIDATION_FIXTURE")!="expedition_suspend" or not DirAccess.dir_exists_absolute("user://release-fixtures"):
		printerr("FAIL: isolated validation profile required")
		quit(1)
		return
	for phase in ["write","read","reopen"]:
		var output := []
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/support/suspended_process.gd","--quit-after","1500","--",phase])
		var code := OS.execute(OS.get_executable_path(),args,output,true)
		var log_text := "\n".join(output)
		if code!=0 or not ("verified "+phase in log_text) or "ERROR:" in log_text or "FAIL:" in log_text:
			printerr("FAIL: expedition restart ",phase," ",log_text)
			quit(1)
			return
	print("PASS: expedition saved, resumed and consumed across separate game processes")
	quit()
