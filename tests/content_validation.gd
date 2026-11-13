extends SceneTree
func _initialize():
 var errors: Array=load("res://content_validator.gd").validate()
 for error in errors: printerr(error)
 print("Catalog validation errors: ",errors.size());quit(0 if errors.is_empty() else 1)
