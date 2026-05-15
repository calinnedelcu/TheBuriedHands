extends Node

signal player_failed(reason: String)
signal player_succeeded(ending_id: String)
signal dialogue_changed(text: String, duration: float)

## One-shot tutorial guards. Set true when the corresponding sequence has been
## played so it cannot replay across multiple lamp instances or playthroughs.
var lamp_empty_tutorial_played: bool = false

## Timestamp (ms) until which the current dialogue bubble is considered "busy".
## Used so deferrable systems (tutorials, ambient barks) can wait their turn
## instead of overwriting a guard / NPC mid-sentence.
var _dialogue_active_until_ms: int = 0

func fail(reason: String) -> void:
	player_failed.emit(reason)

func succeed(ending_id: String) -> void:
	player_succeeded.emit(ending_id)

func show_dialogue(text: String, duration: float = 5.5) -> void:
	if text == "":
		_dialogue_active_until_ms = 0
	else:
		_dialogue_active_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	dialogue_changed.emit(text, duration)

func clear_dialogue() -> void:
	_dialogue_active_until_ms = 0
	dialogue_changed.emit("", 0.0)

func is_dialogue_active() -> bool:
	return Time.get_ticks_msec() < _dialogue_active_until_ms
