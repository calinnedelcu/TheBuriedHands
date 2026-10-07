extends Node
## Main quest progression over QuestDB.STEPS.
## Nodes gate themselves with `is_at()` / `has_reached()` and move the story on
## with `complete(step)`; completing a step that is not the current one is a
## no-op, so triggers can fire more than once safely.

signal step_changed(step_id: StringName)
signal objective_changed(text_key: String, hint_key: String)

var _index := -1

func current() -> StringName:
	var data := QuestDB.step(_index)
	return data.get("id", &"")

func is_at(step_id: StringName) -> bool:
	return current() == step_id

## True once the quest has arrived at (or passed) `step_id`.
func has_reached(step_id: StringName) -> bool:
	var idx := QuestDB.index_of(step_id)
	return idx >= 0 and _index >= idx

func objective_key() -> String:
	return QuestDB.step(_index).get("text", "")

func hint_key() -> String:
	return QuestDB.step(_index).get("hint", "")

## Completes `step_id` if it is the current step and moves to the next one.
## Returns true when the quest advanced.
func complete(step_id: StringName) -> bool:
	if not is_at(step_id) or not Net.story_allowed():
		return false
	_go_to(_index + 1)
	return true

## Jumps straight to a step (new game, checkpoint restore, debug).
func start_at(step_id: StringName) -> void:
	if not Net.story_allowed():
		return
	var idx := QuestDB.index_of(step_id)
	if idx < 0:
		push_warning("Unknown quest step: %s" % step_id)
		return
	_go_to(idx)

func reset() -> void:
	_index = -1

func index() -> int:
	return _index

## Co-op: the apprentice's machine follows the host's quest.
func sync_index(to_index: int) -> void:
	if to_index != _index and to_index >= 0:
		_go_to(to_index)

func _go_to(to_index: int) -> void:
	_index = clampi(to_index, 0, QuestDB.STEPS.size() - 1)
	var data := QuestDB.step(_index)
	Net.send_quest(_index)
	step_changed.emit(data["id"])
	objective_changed.emit(data.get("text", ""), data.get("hint", ""))
	if data.get("checkpoint", false):
		Game.request_checkpoint.call_deferred(data["id"])
