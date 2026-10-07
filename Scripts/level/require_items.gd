class_name RequireItems
extends Node
## Completes a quest step once the player carries all of `items`
## (e.g. "take the jar and the cloth").

@export var step: StringName = &""
@export var items: Array[StringName] = []

func _ready() -> void:
	_hook.call_deferred()

func _hook() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready
	player.inventory.changed.connect(_check.bind(player))
	# Deferred: completing the step from inside the step change would let the
	# outer change announce its (stale) objective after the new one.
	Quest.step_changed.connect(func(_s): _check.call_deferred(player))

func _check(player: Player) -> void:
	if not Quest.is_at(step):
		return
	for id in items:
		if not player.inventory.has_item(id):
			return
	Quest.complete(step)
