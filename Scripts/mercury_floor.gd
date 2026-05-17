class_name MercuryFloor
extends Node3D

@export var player_group: String = "player"
@export var hud_damage_group: String = "hud_damage"
@export var fail_reason: String = "Ai cazut in mercur"
@export var lethal_damage_steps: int = 8
@export_node_path("Area3D") var kill_area_path: NodePath = NodePath("KillArea")

@onready var _kill_area: Area3D = get_node_or_null(kill_area_path)

var _triggered: bool = false


func _ready() -> void:
	if _kill_area != null and not _kill_area.body_entered.is_connected(_on_body_entered):
		_kill_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or body == null:
		return
	if player_group != "" and not body.is_in_group(player_group):
		return
	_triggered = true
	_apply_damage(lethal_damage_steps)
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("fail"):
		events.call("fail", fail_reason)


func _apply_damage(steps: int) -> void:
	var hud := get_tree().get_first_node_in_group(hud_damage_group)
	if hud != null and hud.has_method("apply_damage"):
		hud.call("apply_damage", steps)
