class_name NpcDialogueInteractable
extends Interactable

@export var continue_prompt_text: String = "Continuă"
@export var dialogue_lines: PackedStringArray = []
@export var dialogue_line_duration: float = 5.5
@export var disable_after_finished: bool = true

@export_group("Objective Gate")
@export var required_objective_id: String = ""

@export_group("Initial Objective")
@export var set_initial_objective_on_ready: bool = false
@export var initial_objective_id: String = ""
@export_multiline var initial_objective_text: String = ""

@export_group("Objective After Dialogue")
@export var complete_objective_id: String = ""
@export var objective_after_id: String = ""
@export_multiline var objective_after_text: String = ""
@export var objective_after_if_lamp_id: String = ""
@export_multiline var objective_after_if_lamp_text: String = ""

var _line_index: int = 0
var _finished: bool = false

func _ready() -> void:
	if not set_initial_objective_on_ready or initial_objective_text == "":
		return
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null or not objectives.has_method("set_objective"):
		return
	if objectives.has_method("current_id") and objectives.current_id() != "":
		return
	objectives.set_objective(initial_objective_id, initial_objective_text)

func get_prompt(_by: Node) -> String:
	if _finished and disable_after_finished:
		return ""
	if _line_index > 0 and _line_index < dialogue_lines.size():
		return continue_prompt_text
	return prompt_text

func can_interact(_by: Node) -> bool:
	if not super.can_interact(_by) or dialogue_lines.is_empty():
		return false
	if _finished and disable_after_finished:
		return false
	if required_objective_id != "":
		var objectives := get_node_or_null("/root/Objectives")
		if objectives == null or not objectives.has_method("current_id"):
			return false
		if str(objectives.call("current_id")) != required_objective_id:
			return false
	return true

func interact(by: Node) -> void:
	if not can_interact(by):
		return
	_used = true
	interacted.emit(by)
	_show_current_line()
	_line_index += 1
	if _line_index >= dialogue_lines.size():
		_finished = true
		_apply_objective_after_dialogue(by)
		if disable_after_finished:
			enabled = false

func reset_dialogue() -> void:
	_line_index = 0
	_finished = false
	enabled = true
	reset()

func _show_current_line() -> void:
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("show_dialogue"):
		events.show_dialogue(str(dialogue_lines[_line_index]), dialogue_line_duration)

func _apply_objective_after_dialogue(by: Node) -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null:
		return
	if complete_objective_id != "" and objectives.has_method("complete_objective"):
		objectives.complete_objective(complete_objective_id)
	var next_id := objective_after_id
	var next_text := objective_after_text
	if objective_after_if_lamp_text != "" and _player_has_lamp(by):
		next_id = objective_after_if_lamp_id
		next_text = objective_after_if_lamp_text
	if next_text != "" and objectives.has_method("set_objective"):
		objectives.set_objective(next_id, next_text)

func _player_has_lamp(by: Node) -> bool:
	var player_node := _resolve_player(by)
	if player_node == null:
		return false
	var inv: Node = player_node.get_node_or_null("Inventory")
	if inv != null and inv.has_method("find_lamp"):
		return inv.call("find_lamp") != null
	return false

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null
