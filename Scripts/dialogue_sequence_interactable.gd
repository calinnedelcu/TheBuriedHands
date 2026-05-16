class_name DialogueSequenceInteractable
extends Interactable

@export var required_objective_id: String = ""
@export var dialogue_lines: PackedStringArray = []
@export var dialogue_line_duration: float = 5.5
@export var complete_objective_id: String = ""
@export var objective_after_id: String = ""
@export_multiline var objective_after_text: String = ""
@export var disable_when_started: bool = true

var _playing: bool = false

func can_interact(by: Node) -> bool:
	if _playing:
		return false
	if not super.can_interact(by):
		return false
	if dialogue_lines.is_empty():
		return false
	if required_objective_id == "":
		return true
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null or not objectives.has_method("current_id"):
		return false
	return str(objectives.call("current_id")) == required_objective_id

func interact(by: Node) -> void:
	if not can_interact(by):
		return
	_used = true
	_playing = true
	interacted.emit(by)
	if disable_when_started:
		enabled = false
	_play_sequence()

func _play_sequence() -> void:
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("show_dialogue"):
		for line in dialogue_lines:
			events.show_dialogue(str(line), dialogue_line_duration)
			if dialogue_line_duration > 0.0:
				await _dialogue_wait(dialogue_line_duration)
	_apply_objective_after_sequence()
	_playing = false

func _dialogue_wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var t0 := Time.get_ticks_msec()
	var dur_ms := seconds * 1000.0
	while Time.get_ticks_msec() - t0 < dur_ms:
		var events_node := get_node_or_null("/root/GameEvents")
		if events_node != null and events_node.has_method("is_dialogue_skip_pending") and events_node.call("is_dialogue_skip_pending"):
			if events_node.has_method("consume_dialogue_skip"):
				events_node.call("consume_dialogue_skip")
			return
		await get_tree().process_frame

func _apply_objective_after_sequence() -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null:
		return
	if complete_objective_id != "" and objectives.has_method("complete_objective"):
		objectives.complete_objective(complete_objective_id)
	if objective_after_text != "" and objectives.has_method("set_objective"):
		objectives.set_objective(objective_after_id, objective_after_text)
