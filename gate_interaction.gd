extends RefCounted
# Ground distance from the gate center; one rule for prompts and authority.
const RANGE:=2.75
const READY_MARGIN:=.5
static func travel_range(game: Node,kind: String) -> float:
 return 1.7 if kind=="depart" and game.destination==game.Campaign.HEART else RANGE


static func shrine_preferred(field: RefCounted, at: Vector3) -> bool:
 var gate_distance: float=field.advance.distance_to(at)
 return gate_distance>RANGE or field.graft.distance_to(at)<gate_distance
