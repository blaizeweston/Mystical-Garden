extends "res://mob_sim/mob_brain.gd"
## Scripted baseline brain, run natively by native/mob_decide.c. It follows the current enemy priorities.
## mob_scripted_brain_reference.gd holds the same logic in GDScript for the parity test.

const Contract = preload("res://mob_sim/mob_contract.gd")


func decide(batch: Batch) -> void:
	var chosen: PackedByteArray = batch.world.decide_scripted(batch.native_inputs(batch.masks))
	if chosen.size() != batch.slots.size() * Contract.HEAD_COUNT:
		push_error("The native scripted brain refused this decision's input.")
		return
	batch.intents = chosen
