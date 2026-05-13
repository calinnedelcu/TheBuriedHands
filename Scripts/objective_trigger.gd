class_name ObjectiveTrigger
extends Area3D

enum Mode { SET, COMPLETE }

@export var mode: Mode = Mode.SET
@export var objective_id: String = ""
@export_multiline var objective_text: String = ""
@export var only_once: bool = true
@export var require_player_group: String = "player"

var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _used and only_once:
		return
	if require_player_group != "" and not body.is_in_group(require_player_group):
		return
	_used = true
	var bus: Node = get_node_or_null("/root/Objectives")
	if bus == null:
		return
	match mode:
		Mode.SET:
			bus.set_objective(objective_id, objective_text)
		Mode.COMPLETE:
			bus.complete_objective(objective_id)
