extends SceneTree
const Appearance = preload("res://character_appearance.gd")
const Avatar = preload("res://traveller_avatar.gd")
const Codec = preload("res://world_snapshot.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL customization: ",message)
func run() -> void:
	for style in 3:
		var legacy := [3,2,1,style,2,1,0,100,37,83,75,41,98]
		var normalized := Appearance.normalize(legacy)
		check(normalized.slice(0,13)==legacy and legacy.size()==13, "legacy fields and caller data are preserved")
		check(normalized[Appearance.HOOD]==(1 if style==0 else 0) and normalized.slice(14)==[1,1,1], "legacy hood and accessory defaults retain the existing look")
		check(Appearance.normalize(normalized)==normalized, "normalization is stable")
	for mask in 16:
		var packed_look := Appearance.DEFAULT.duplicate()
		for bit in 4: packed_look[13+bit]=(mask >> bit) & 1
		var bytes := PackedByteArray(packed_look)
		check(Codec._unpack_appearance(Codec._pack_appearance(bytes))==bytes, "all accessory combinations round-trip through the existing 64 bits")
	var old := PackedByteArray([0,0,0,2,0,1,100,50,50,50,50,50,50])
	check(Codec._unpack_appearance(Codec._pack_appearance(old))==PackedByteArray(Appearance.normalize(old)), "short legacy input is normalized before wire encoding")
	var invalid := Appearance.DEFAULT.duplicate()
	invalid[Appearance.HOOD]=-2; invalid[Appearance.BRACERS]=99
	check(Appearance.normalize(invalid)[Appearance.HOOD]==0 and Appearance.normalize(invalid)[Appearance.BRACERS]==1, "optional flags retain bounded integer values")
	check(Appearance.option_field(-1)==-1 and Appearance.option_field(9)==-1, "unknown option indices cannot reach body or slider fields")
	var holder := Node3D.new()
	root.add_child(holder)
	for body in 2:
		var actor := Avatar.build(holder)
		for style in 3:
			for mask in 16:
				var visual_look := Appearance.DEFAULT.duplicate()
				visual_look[5]=body; visual_look[3]=style
				for bit in 4: visual_look[13+bit]=(mask >> bit) & 1
				Appearance.apply(actor,visual_look)
				var field: Node3D = actor.field_rig.scene
				for hair in 3:
					check(field.find_child("FieldHair%d"%hair,true,false).visible==((mask & 1)==0 and hair==style), "hood covers hair while retaining the selected style")
				for choice: int in Appearance.MESH_OPTIONS:
					var matches := 0
					for mesh in field.find_children("*","MeshInstance3D",true,false):
						if Appearance.MESH_OPTIONS[choice] in str(mesh.name):
							matches+=1
							check(mesh.visible==(visual_look[choice]==1), "each accessory toggles only its matching mesh")
					check(matches==(2 if choice==Appearance.BELTS else 1), "both body models contain the supported accessory meshes")
				for suffix in ["Ranger_Body","Ranger_Arms","Ranger_Legs"]:
					check(field.find_children("*"+suffix,"MeshInstance3D",true,false)[0].visible, "main clothing and body coverage remain visible")
				check(field.find_children("*Ranger_Feet*","MeshInstance3D",true,false)[0].visible, "footwear remains attached")
		actor.model.free()
	holder.free()
	var creator := preload("res://character_creator.gd").new()
	root.add_child(creator)
	var form_look := Appearance.DEFAULT.duplicate()
	form_look[5]=1; form_look[3]=2; form_look[6]=83; form_look[7]=37; form_look[Appearance.HOOD]=0; form_look[Appearance.BELTS]=0
	creator.begin({"name":"Custom fixture","appearance":form_look,"active_class":2})
	check(creator.options.size()==9 and creator.sliders.size()==7 and creator.appearance()==form_look, "creator restores independent options without shifting any proportion slider")
	creator.options[5].select(1); creator.update_preview()
	check(creator.appearance()[Appearance.HOOD]==1 and creator.appearance()[3]==2 and creator.appearance().slice(5,13)==form_look.slice(5,13), "hood editing preserves hairstyle, body and proportions")
	creator.dismiss(); creator.free()
	var ui := preload("res://ui/gameplay/gameplay_ui.tscn").instantiate()
	root.add_child(ui)
	var requests: Array = []
	ui.requested.connect(func(command,data): requests.append([command,data]))
	var state := {"session_text":"Solo","role":"Solo","can_host":true,"can_join":true,"can_leave":false,"can_save":false,"can_bank":false,"wild":false,"look":form_look}
	ui.present_menu(state)
	check(ui.find_child("HairStyleOption",true,false).text=="Hair style: Long" and ui.find_child("BeltsOption",true,false).text=="Extra belts: Off", "Garden controls use shared labels and saved field mapping")
	ui.find_child("HoodOption",true,false).pressed.emit()
	check(requests.back()==["appearance",{"index":5}], "Garden hood control emits the authorized option index")
	state.wild=true; ui.present_menu(state)
	for node in ["HoodOption","ShoulderArmorOption","BracersOption","BeltsOption"]:
		check(ui.find_child(node,true,false).disabled, "new choices remain locked during an expedition")
	ui.free()
	if not failed: print("PASS: legacy appearance conversion, 64-bit cosmetics, 96 model configurations, accessory coverage and both customization screens")
	quit(1 if failed else 0)
