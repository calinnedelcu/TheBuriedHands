class_name RequireItems
extends Node
## Completes a quest step once the player carries all of `items`
## (e.g. "take the jar and the cloth"); in co-op, once the two of you do.

@export var step: StringName = &""
@export var items: Array[StringName] = []

func _ready() -> void:
	_hook.call_deferred()

func _hook() -> void:
	# Co-op: the host's story.
	if Net.is_client():
		return
	for player in Net.players():
		if not player.is_node_ready():
			await player.ready
		player.inventory.changed.connect(_check)
	# Deferred: completing the step from inside the step change would let the
	# outer change announce its (stale) objective after the new one.
	Quest.step_changed.connect(func(_s): _check.call_deferred())

func _check() -> void:
	if not Quest.is_at(step):
		return
	for id in items:
		var carried := false
		for player in Net.players():
			carried = carried or player.inventory.has_item(id)
		if not carried:
			return
	Quest.complete(step)
