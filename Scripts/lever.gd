class_name Lever
extends Node3D

signal pulled()

@export var target_gate_path: NodePath
@export var one_shot: bool = true
@export var lever_arc_deg: float = 70.0
@export var anim_duration: float = 0.35

@onready var _handle: Node3D = $Handle if has_node("Handle") else null
@onready var _interactable: Interactable = get_node_or_null("Interactable")
@onready var _audio: AudioStreamPlayer3D = get_node_or_null("LeverAudio")

var _pulled: bool = false
var _initial_handle_rotation: Vector3

func _ready() -> void:
	if _handle:
		_initial_handle_rotation = _handle.rotation
	if _interactable:
		_interactable.interacted.connect(_on_interacted)

func _on_interacted(_by: Node) -> void:
	if _pulled and one_shot:
		return
	_pulled = true
	if _audio:
		_audio.play()
	_animate_handle()
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(global_position, 0.8, self)
	if not target_gate_path.is_empty():
		var gate: Node = get_node_or_null(target_gate_path)
		if gate and gate.has_method("open"):
			gate.open()
	pulled.emit()
	if one_shot and _interactable:
		_interactable.enabled = false

func _animate_handle() -> void:
	if _handle == null:
		return
	var target := _initial_handle_rotation + Vector3(deg_to_rad(lever_arc_deg), 0, 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_handle, "rotation", target, anim_duration)
