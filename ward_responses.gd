extends RefCounted
## Publishes the single response selected by PlayerProtection. The claim owner
## has already consumed native protection; this bridge owns no mutable state.
const Protection = preload("res://player_protection.gd")


static func block(game: Node, consumed: Protection.Block, recipient_id: int, position: Vector3, now: int) -> RefCounted:
	var event := consumed.response
	if event != null and event.publish(game, "actual_block", "ward", event.block_scope(recipient_id, consumed.adapter), now,
			{"adapter": consumed.adapter.id, "recipient": recipient_id, "center": position}):
		return event
	return null
