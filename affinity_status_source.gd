extends RefCounted
## Shared identity/fixed-point utilities, not a universal stacking policy.
## Family handlers own their one enemy/recipient record and accumulation rules.
const Life = preload("res://player_lifecycle.gd")
const UNITS_PER_HP := 1000
# Machine representation only; not a gameplay power ceiling.
const MAX_INTEGER := 9223372036854775807
const VERSION := 1

static func capture(event: RefCounted) -> Dictionary:
	return {"actor":event.actor,"binding":event.connection_binding,"life":event.life_generation,
		"epoch":event.epoch,"activation":event.identity,"slot":event.source,
		"quality":event.quality,"item":event.material_id}

static func key(source: Dictionary) -> String:
	return "%d/%d/%d" % [source.actor,source.binding,source.life]

static func current(game: Node, source: Dictionary) -> bool:
	return int(source.epoch)==game.participation.epoch() \
		and game.network_session.matches(int(source.actor),int(source.binding)) \
		and Life.matches(game.players.get(int(source.actor),{}),int(source.life))

static func target_current(game: Node, target: int, status: Dictionary) -> bool:
	return int(status.get("epoch",-1))==game.participation.epoch() \
		and game.encounter.alive(target,int(status.get("token",-1)))

static func units(hp: float) -> int:
	return roundi(maxf(0.0,hp)*UNITS_PER_HP)

## One aggregate hit retains deterministic credit. Greatest contribution wins;
## ties use ascending peer ID then binding, never dictionary iteration order.
static func dominant(contributors: Dictionary, amount: String) -> Dictionary:
	var best := {}
	for row: Dictionary in contributors.values():
		if best.is_empty() or int(row[amount])>int(best[amount]) \
				or (int(row[amount])==int(best[amount]) and (int(row.actor)<int(best.actor) or (int(row.actor)==int(best.actor) and int(row.binding)<int(best.binding)))):
			best=row
	return best

## Fractional DOT damage is carried by the shared effect, not rounded per source.
static func whole_tick(status: Dictionary, damage_units: int) -> int:
	var total := damage_units+int(status.get("remainder",0))
	status.remainder=total%UNITS_PER_HP
	return int(total/UNITS_PER_HP)


## Reject unrepresentable arithmetic instead of wrapping or clipping a build.
static func sum_fits(current: int, added: int) -> bool:
	return current>=0 and added>=0 and current<=MAX_INTEGER-added
