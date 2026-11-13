extends RefCounted

const MODELS := {
	"crossbow": {"scene":preload("res://assets/weapons/bark_arbalest.glb"), "name":"BarkArbalestModel", "grip":Vector3(0,.2,0), "core":Vector3(-.051,.231,.04)},
	"knives": {"scene":preload("res://assets/weapons/graft_knives.glb"), "name":"GraftKnifeModel", "grip":Vector3.ZERO, "core":Vector3(.005,.126,.034)},
	"staff": {"scene":preload("res://assets/weapons/spore_staff.glb"), "name":"SporeStaffModel", "grip":Vector3.ZERO, "core":Vector3(.026,.64,.052)},
	"wand": {"scene":preload("res://assets/weapons/thorn_wand.glb"), "name":"ThornWandModel", "grip":Vector3.ZERO, "core":Vector3(.036,.573,.021)},
	"ring": {"scene":preload("res://assets/weapons/thorn_ring.glb"), "name":"ThornRingModel", "grip":Vector3.ZERO, "core":Vector3(.20,.12,.035)},
	"orb": {"scene":preload("res://assets/weapons/seed_focus.glb"), "name":"SeedFocusModel", "grip":Vector3(0,.3,0), "core":Vector3(0,.326,.165)},
	"bell": {"scene":preload("res://assets/weapons/bloom_bell.glb"), "name":"BloomBellModel", "grip":Vector3(0,.57,0), "core":Vector3(0,.21,.11)},
	"censer": {"scene":preload("res://assets/weapons/spore_censer.glb"), "name":"SporeCenserModel", "grip":Vector3(0,.77,0), "core":Vector3(0,.20,.144)},
	"fan": {"scene":preload("res://assets/weapons/petal_fan.glb"), "name":"PetalFanModel", "grip":Vector3.ZERO, "core":Vector3(0,.18,.046)},
	"whip": {"scene":preload("res://assets/weapons/root_lash.glb"), "name":"RootLashModel", "grip":Vector3.ZERO, "core":Vector3(.033,.079,.035)},
}
const LASH_SEGMENT := preload("res://assets/weapons/root_lash_segment.glb")
const ARBALEST_SUPPORT := Vector3(.045,-.04,.267)
const ARBALEST_NOCK := Vector3(0,.23,.30)
const ARBALEST_TIP := Vector3(.493,.209,.385)
const ARBALEST_TRACK := Vector3(0,.23,.655)
const SPELL_TIPS := {"staff":Vector3(.014,.845,.032), "wand":Vector3(.037,.604,.021)}


static func attach(root: Node3D, form: String) -> void:
	var definition: Dictionary = MODELS[form]
	var model: Node3D = definition.scene.instantiate()
	model.name = definition.name
	root.add_child(model)


static func in_flight(form: String, radius: float) -> Node3D:
	var root := Node3D.new()
	attach(root,form)
	var model: Node3D = root.get_child(0)
	var center := Vector3(0,.282,0) if form=="ring" else Vector3(0,.30,0)
	var scale_factor := radius/(.35 if form=="ring" else .174)
	var rotation := Basis(Vector3.RIGHT,PI*.5) if form=="ring" else Basis.IDENTITY
	var basis := rotation.scaled(Vector3.ONE*scale_factor)
	model.transform=Transform3D(basis,-(basis*center))
	return root
