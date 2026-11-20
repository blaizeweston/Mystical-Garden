extends RefCounted
## Reachable banks of the water actually drawn in the current Garden.
## Terrain keeps its movement authority; these read-only queries never move actors.
const Shape=preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Layout=preload("res://garden_layout.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
const BANK_CLEARANCE:=0.40 # metres; leaves room for the existing 0.34 m actor
const ACTOR_RADIUS:=0.34
const CONTRACT:="garden-water-banks-1"

# Owned by one generated Garden. This is a derived presentation hint, never an
# authorization cache: nearby() always rechecks current water and actor clearance.
var _anchor_key: String=""
var _bank_hint:=Vector3.INF

static func _features(stage: Node3D) -> Array:
	var garden=stage.get("experimental_garden")
	if garden==null:return []
	var result: Array=[]
	for feature in garden.state.layout.water:result.append(feature)
	# These authored pools use the same cached outlines as their renderer.
	for pool in Layout.ponds(stage,stage.garden_extent):result.append(pool.shape)
	return result

static func available(stage: Node3D) -> bool:
	return not _features(stage).is_empty()

static func center(stage: Node3D) -> Vector3:
	var features:=_features(stage)
	if features.is_empty():return Vector3.INF
	var at: Vector2=features[0].bounds.get_center()
	return Vector3(at.x,0,at.y)

static func _candidates(features: Array, origin: Vector2, reach: float) -> Array:
	var candidates: Array=[]
	for feature in features:
		if is_finite(reach) and not feature.bounds.grow(reach+BANK_CLEARANCE).has_point(origin):continue
		var boundary:=Shape.boundary(feature)
		for i in boundary.size():
			var shore:=Geometry2D.get_closest_point_to_segment(origin,boundary[i],boundary[(i+1)%boundary.size()])
			var toward:=origin-shore
			if toward.is_zero_approx():toward=(boundary[(i+1)%boundary.size()]-boundary[i]).orthogonal()
			var bank:=shore+toward.normalized()*BANK_CLEARANCE
			var distance:=bank.distance_to(origin)
			if distance>reach:continue
			candidates.append({"id":str(feature.id),"edge":i,"bank":bank,"shore":shore,"distance":distance})
	# Geometry order cannot decide equal-distance source ownership.
	candidates.sort_custom(func(a,b):
		if a.distance!=b.distance:return a.distance<b.distance
		if a.id!=b.id:return a.id<b.id
		return a.edge<b.edge)
	return candidates

static func _valid_bank(stage: Node3D, features: Array, bank: Vector2) -> bool:
	return not Shape.in_any(features,bank,ACTOR_RADIUS) and stage.experimental_garden.barrier.walkable(bank)

static func anchor(stage: Node3D) -> Vector3:
	var garden=stage.get("experimental_garden")
	return garden.water_sources._anchor_for(stage) if garden!=null else Vector3.INF

func _anchor_for(stage: Node3D) -> Vector3:
	var features:=_features(stage)
	if features.is_empty():return Vector3.INF
	var garden=stage.experimental_garden
	var key:=str([stage.garden_tier,stage.garden_extent,stage.active_plots,stage.heart_unlocked,garden.layout_revision,garden.state.revision])
	if _anchor_key==key and _bank_hint.is_finite() and _valid_bank(stage,features,Vector2(_bank_hint.x,_bank_hint.z)):return _bank_hint
	_anchor_key=key;_bank_hint=Vector3.INF
	for candidate in _candidates(features,Vector2.ZERO,INF):
		if _valid_bank(stage,features,candidate.bank):
			_bank_hint=Vector3(candidate.bank.x,0,candidate.bank.y)
			break
	return _bank_hint

static func nearby(stage: Node3D, position: Vector3) -> Dictionary:
	if not position.is_finite() or absf(position.y)>.2:return {}
	var features:=_features(stage)
	if features.is_empty():return {}
	var at:=Vector2(position.x,position.z)
	if not _valid_bank(stage,features,at):return {}
	var reach:=float(Catalog.point("spring_water").range)
	for candidate in _candidates(features,at,reach):
		if not _valid_bank(stage,features,candidate.bank):continue
		# Fill from the same dry, unobstructed approach an actor can occupy.
		var arrived: Vector2=stage.experimental_garden.barrier.move(at,candidate.bank-at)
		if arrived.distance_to(candidate.bank)>.025:continue
		return {"source":candidate.id,"position":Vector3(candidate.bank.x,0,candidate.bank.y),
			"water_position":Vector3(candidate.shore.x,0,candidate.shore.y),"distance":candidate.distance}
	return {}
