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
	var denied:=OS.has_feature("template_release") and not Developer.authorized_build() and Developer.open_garden(forged,false)==ERR_UNAUTHORIZED and not Developer.enter_arena(forged) and not Developer.toggle_workbench(forged)
	var manifest_claim:={"playtest_version":"0.0.1-playtest.1","git_commit":"1".repeat(40),"save_root":"Mystical Garden Playtest 0.0.1-playtest.1","developer_tools":true}
	denied=denied and preload("res://playtest_storage.gd").inspect(manifest_claim).contains("developer build identity") and not Developer.authorized_build()
	denied=denied and preload("res://developer_settings.gd").stock_test_garden(forged).begins_with("Developer tools")
	denied=denied and Developer.grant_resources(forged).begins_with("Developer tools") and Developer.stock_materials(forged).begins_with("Developer tools") and Developer.test_unlock(forged,"flowering").begins_with("Developer tools") and not Developer.can_edit(forged)
	var unchanged: Dictionary={}
	denied=denied and Developer._grant_resources(forged,unchanged)=="Developer session required." and Developer._stock_materials(forged,unchanged)=="Developer session required." and Developer._test_unlock(forged,"irrigation",unchanged)=="Developer session required." and unchanged.is_empty()
	var tune:=preload("res://developer_arena/tuning.gd").new()
	denied=denied and not tune.attach(forged) and not tune.request(forged,tune.SUN,3.0) and not tune.request(forged,"rupture.size",1.65) and not tune.apply(forged,[tune.WATER]) and not tune.replace(forged,{tune.SPEAR:6.0}) and not tune.replay(forged)
	var store:=preload("res://developer_arena/tuning_presets.gd").new(forged)
	denied=denied and not store.save_new("Leak").is_empty() and not store.load_named("Leak").is_empty() and not store.remove("Leak",true).is_empty() and store.export_review()=="Developer session required."
	denied=denied and not store._new_file(project_data,{"name":"Leak"}).is_empty() and store._write(project_data.path_join("unexpected.txt"),"blocked")==ERR_UNAUTHORIZED
	var scenarios:=preload("res://developer_arena/scenarios.gd").new(forged)
	denied=denied and not scenarios.start({}).is_empty() and not scenarios.save_record({"name":"Leak"}).is_empty() and scenarios.names().is_empty()
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
