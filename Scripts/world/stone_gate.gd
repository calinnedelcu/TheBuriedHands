class_name StoneGate
extends Node3D
## A heavy gate that slides (up, or sideways) when opened, or slams shut when
## the tomb is sealed behind the player.

const GRIND := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")
const SLAM := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")

@export var open_offset := Vector3(0, 6.0, 0)
@export var start_open := false
@export var open_seconds := 5.0
## Close automatically when the sealing reaches this stage (0 = never).
@export var close_at_sealing_stage := 0

@onready var _door: Node3D = $Door
@onready var _blocker: CollisionShape3D = $Door/Blocker/Shape

var is_open := false
var _closed_pos := Vector3.ZERO

func _ready() -> void:
	add_to_group(&"persistent")
	_closed_pos = _door.position
	_set_open_instant(start_open)
	if close_at_sealing_stage > 0:
		Game.sealing_advanced.connect(_on_sealing)

func open(animate := true) -> void:
	if is_open:
		return
	is_open = true
	if animate:
		Sfx.play_at(GRIND, global_position, 2.0, 0.0, &"Tomb", 50.0)
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_door, "position", _closed_pos + open_offset, open_seconds)
		tween.tween_callback(func(): _blocker.disabled = true)
	else:
		_set_open_instant(true)

func close(animate := true) -> void:
	if not is_open:
		return
	is_open = false
	_blocker.disabled = false
	if animate:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(_door, "position", _closed_pos, 0.9)
		tween.tween_callback(func():
			Sfx.play_at(SLAM, global_position, 6.0, 0.0, &"Tomb", 80.0)
			var p := get_tree().get_first_node_in_group(&"player") as Player
			if p != null and p.global_position.distance_to(global_position) < 40.0:
				p.add_shake(0.8))
	else:
		_set_open_instant(false)

func _set_open_instant(value: bool) -> void:
	is_open = value
	_door.position = _closed_pos + (open_offset if value else Vector3.ZERO)
	_blocker.disabled = value

func _on_sealing(stage: int) -> void:
	if stage >= close_at_sealing_stage:
		close(true)

func persist_save() -> Dictionary:
	return {"open": is_open}

func persist_load(data: Dictionary) -> void:
	_set_open_instant(bool(data.get("open", start_open)))
