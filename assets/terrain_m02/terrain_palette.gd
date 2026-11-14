extends Resource

@export var id: StringName
@export var display_name: String
@export var forest_bias: float
@export var stone_bias: float
@export var soil_bias: float
@export var clearing_radius: float
@export_range(0.2, 2.2) var water_width: float = 1.0
@export var water_is_stream := false
@export var tree_at_origin := false