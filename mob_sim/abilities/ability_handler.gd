extends RefCounted
## Rules for an ability that data alone cannot express, such as choosing a corpse or ordering escorts.
## Handlers reach the world only through a HandlerPort, so one handler serves both the training
## simulation and the Neural Arena. Every hook is optional.

const Port = preload("res://mob_sim/abilities/handler_port.gd")
const Release = preload("res://mob_sim/mob_release.gd")

## Ticks an approach step may last before the wind-up starts anyway.
const APPROACH_TICKS := 43


## A point to walk to before the wind-up, or Vector2.INF for none. Called before plan().
## Handlers that approach must remember, in port.memory(), that the step was taken.
func approach(_port: Port, _release: Release) -> Vector2:
	return Vector2.INF


## Chooses targets and adjusts aim at the wind-up. Return false to refuse the attack this time.
## Set release.data.locked to keep the areas this handler built instead of the kit's.
func plan(_port: Port, _release: Release) -> bool:
	return true


## Applies extra effects at release. Return false to skip the kit's generic effects.
func resolve(_port: Port, _release: Release) -> bool:
	return true
