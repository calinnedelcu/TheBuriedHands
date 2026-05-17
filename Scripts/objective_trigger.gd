class_name ObjectiveTrigger
extends Area3D

enum Mode { SET, COMPLETE }

@export var mode: Mode = Mode.SET
@export var objective_id: String = ""
@export_multiline var objective_text: String = ""
@export var only_once: bool = true
@export var require_player_group: String = "player"
## Optional dialogue shown before setting the objective.
@export_multiline var intro_dialogue: String = ""
@export var intro_dialogue_duration: float = 5.0
## Optional: camera pans to this node before showing dialogue.
@export var focus_target_path: NodePath
@export var focus_zoom_fov: float = 42.0
@export var focus_hold_time: float = 2.0

var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _used and only_once:
		return
	if require_player_group != "" and not body.is_in_group(require_player_group):
		return
	_used = true
	# Camera focus on target if configured.
	if not focus_target_path.is_empty():
		var focus_target := get_node_or_null(focus_target_path) as Node3D
		if focus_target and body.has_method("play_cinematic_focus"):
			body.call("play_cinematic_focus", focus_target.global_position, 0.7, focus_hold_time, focus_zoom_fov, 0.55)
	# Dialogue
	if intro_dialogue != "":
		var events := get_node_or_null("/root/GameEvents")
		if events and events.has_method("show_dialogue"):
			events.show_dialogue(intro_dialogue, intro_dialogue_duration)
			await get_tree().create_timer(0.6).timeout
	# Objective
	var bus: Node = get_node_or_null("/root/Objectives")
	if bus == null:
		return
	match mode:
		Mode.SET:
			bus.set_objective(objective_id, objective_text)
		Mode.COMPLETE:
			bus.complete_objective(objective_id)
