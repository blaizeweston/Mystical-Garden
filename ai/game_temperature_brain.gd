extends "res://ai/training_brain.gd"
## The training brain sampling as the game samples (ai/mob_neural_brain.gd): behaviour, targets and commitment
## at a temperature set by the mob's intelligence (schema "sampling": 1.5 for the dimmest, 0.3 for the
## brightest), manoeuvre and messages at 1. Used only to evaluate brains as players would meet them
## (ai/evaluate_policies.gd --game-temperature); its recorded probabilities are not the trainer's.

const SHARPENED_HEADS := [Contract.Head.BEHAVIOUR, Contract.Head.ENEMY_TARGET, Contract.Head.ALLY_TARGET, Contract.Head.COMMIT]


func _temperature_for(batch: Batch, index: int, head: int) -> float:
	if not SHARPENED_HEADS.has(head):
		return 1.0
	return lerpf(_temperature_dim, _temperature_smart, batch.pool.intelligence[batch.slots[index]])
