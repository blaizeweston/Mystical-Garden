extends RefCounted
## The one interface every mob brain implements. Scripted and neural brains are interchangeable.

const Batch = preload("res://mob_sim/mob_decision_batch.gd")


## Clears anything the brain remembers about a slot, such as recurrent state, when a new mob spawns there.
func reset_slot(_slot: int) -> void:
	pass


## Fills batch.intents for every mob in batch.slots. Illegal choices are refused by the rules.
func decide(_batch: Batch) -> void:
	push_error("A mob brain must implement decide().")
