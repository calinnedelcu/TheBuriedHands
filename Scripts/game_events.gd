extends Node

signal player_failed(reason: String)
signal player_succeeded(ending_id: String)
signal dialogue_changed(text: String, duration: float)

## One-shot tutorial guards. Set true when the corresponding sequence has been
## played so it cannot replay across multiple lamp instances or playthroughs.
var lamp_empty_tutorial_played: bool = false

func fail(reason: String) -> void:
	player_failed.emit(reason)

func succeed(ending_id: String) -> void:
	player_succeeded.emit(ending_id)

func show_dialogue(text: String, duration: float = 5.5) -> void:
	dialogue_changed.emit(text, duration)

func clear_dialogue() -> void:
	dialogue_changed.emit("", 0.0)
