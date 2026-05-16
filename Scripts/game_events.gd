extends Node

signal player_failed(reason: String)
signal player_succeeded(ending_id: String)
signal dialogue_changed(text: String, duration: float)
signal intro_finished
signal lamp_tutorial_requested

## One-shot tutorial guards. Set true when the corresponding sequence has been
## played so it cannot replay across multiple lamp instances or playthroughs.
var lamp_empty_tutorial_played: bool = false

## Flag pentru monologul de la inceputul scenei. Devine true cand toate replicile
## din scene_intro_dialogue s-au terminat. Quest-urile care vor sa apara abia
## dupa intro pot astepta `intro_finished` sau pot verifica acest flag.
var intro_done: bool = false

func notify_intro_finished() -> void:
	if intro_done:
		return
	intro_done = true
	intro_finished.emit()

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

func request_lamp_tutorial() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var inv := player.get_node_or_null("Inventory")
	if inv == null:
		return
	var lamp = null
	if inv.has_method("active_lamp"):
		lamp = inv.active_lamp()
	if lamp == null and inv.has_method("find_lamp"):
		lamp = inv.find_lamp()
	if lamp == null:
		for node in get_tree().get_nodes_in_group("lamp"):
			if node.get("equipped") == true:
				lamp = node
				break
	if lamp == null:
		for node in get_tree().get_nodes_in_group("lamp"):
			lamp = node
			break
	if lamp != null and lamp.has_method("_play_lamp_tutorial"):
		lamp._play_lamp_tutorial()
