class_name Gate
extends Node3D

signal opened()
signal closed()

@export var open_duration: float = 1.4
@export var start_open: bool = false
@export var slide_offset: Vector3 = Vector3(0, 3.4, 0)
@export var open_complete_objective: String = ""

@onready var _door: Node3D = $Door if has_node("Door") else null
@onready var _audio: AudioStreamPlayer3D = get_node_or_null("GateAudio")

var _is_open: bool = false
var _closed_position: Vector3
var _tween: Tween

func _ready() -> void:
	if _door:
		_closed_position = _door.position
		if start_open:
			_door.position = _closed_position + slide_offset
			_is_open = true

func is_open() -> bool:
	return _is_open

func open() -> void:
	if _is_open or _door == null:
		return
	_is_open = true
	_animate(_closed_position + slide_offset)
	if _audio:
		_audio.play()
	opened.emit()
	if open_complete_objective != "" and has_node("/root/Objectives"):
		get_node("/root/Objectives").complete_objective(open_complete_objective)

func close() -> void:
	if not _is_open or _door == null:
		return
	_is_open = false
	_animate(_closed_position)
	if _audio:
		_audio.play()
	closed.emit()

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func _animate(target: Vector3) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_door, "position", target, open_duration)
