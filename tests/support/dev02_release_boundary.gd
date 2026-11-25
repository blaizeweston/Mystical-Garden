extends Node
const Developer=preload("res://developer_mode.gd")

func _ready() -> void:
	var project_data:=OS.get_environment("MYSTICAL_DEV02_PROBE_ROOT").replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if not project_data.contains("/.godot/vd/") or not OS.get_user_data_dir().replace("\\","/").simplify_path().begins_with(project_data) or DisplayServer.get_name()!="headless" or OS.get_environment("MYSTICAL_VALIDATION_FIXTURE")!="dev02_release_boundary":
		printerr("Disposable packaged fixture required.")
		get_tree().quit(1)
		return
	var forged:=Node.new()
	forged.set_meta(Developer.WORLD_META,{"slot":0})
	var denied:=OS.has_feature("template_release") and not Developer.authorized_build() and Developer.open_garden(forged,false)==ERR_UNAUTHORIZED and not Developer.enter_arena(forged)
	denied=denied and Developer.grant_resources(forged).begins_with("Developer tools") and Developer.stock_materials(forged).begins_with("Developer tools") and Developer.test_unlock(forged,"flowering").begins_with("Developer tools") and not Developer.can_edit(forged)
	var unchanged: Dictionary={}
	denied=denied and Developer._grant_resources(forged,unchanged)=="Developer session required." and Developer._stock_materials(forged,unchanged)=="Developer session required." and Developer._test_unlock(forged,"irrigation",unchanged)=="Developer session required." and unchanged.is_empty()
	forged.free()
	if denied:
		var marker:=FileAccess.open(project_data.path_join("passed.txt"),FileAccess.WRITE)
		if marker==null:
			get_tree().quit(1)
			return
		marker.store_line("Packaged developer commands refused.")
		marker.close()
		print("PASS: packaged runtime refused developer entry and mutations")
	else: printerr("FAIL: build authorization")
	get_tree().quit(0 if denied else 1)
