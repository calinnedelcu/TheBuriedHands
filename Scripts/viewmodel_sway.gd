extends Node3D

@export var player_path: NodePath
@export var sway_amount: float = 0.012
@export var sway_smoothing: float = 8.0
@export var bob_amount: float = 0.008
@export var bob_speed: float = 8.0
@export var breath_amount: float = 0.0035
@export var breath_speed: float = 1.6
@export var crouch_offset: Vector3 = Vector3(0, -0.04, 0.02)
@export var land_kick: float = 0.05

@onready var _player: CharacterBody3D = get_node_or_null(player_path) if not player_path.is_empty() else _find_player()

var _base_pos: Vector3
var _sway_target: Vector3 = Vector3.ZERO
var _mouse_smoothed: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _breath_time: float = 0.0
var _was_on_floor: bool = true
var _land_blend: float = 0.0

func _find_player() -> CharacterBody3D:
	var n: Node = self
	while n != null:
		if n is CharacterBody3D:
			return n
		n = n.get_parent()
	return null

func _ready() -> void:
	_base_pos = position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var m := (event as InputEventMouseMotion).relative
		_mouse_smoothed = _mouse_smoothed.lerp(m, 0.4)

func _process(delta: float) -> void:
	# Sway from mouse motion (opposite direction, parallax)
	_sway_target = Vector3(-_mouse_smoothed.x * sway_amount, -_mouse_smoothed.y * sway_amount * 0.7, 0)
	_mouse_smoothed = _mouse_smoothed.lerp(Vector2.ZERO, clamp(delta * sway_smoothing, 0.0, 1.0))

	var bob := Vector3.ZERO
	if _player != null and _player.is_on_floor():
		var hv := Vector2(_player.velocity.x, _player.velocity.z).length()
		if hv > 0.2:
			_bob_time += delta * bob_speed * (hv / 5.0)
			bob.x = sin(_bob_time) * bob_amount
			bob.y = abs(sin(_bob_time * 2.0)) * bob_amount * 0.6
		else:
			_bob_time = lerp(_bob_time, 0.0, clamp(delta * 4.0, 0.0, 1.0))

	_breath_time += delta * breath_speed
	var breath := Vector3(0, sin(_breath_time) * breath_amount, 0)

	# Land kick
	if _player != null:
		var on_floor := _player.is_on_floor()
		if on_floor and not _was_on_floor:
			_land_blend = 1.0
		_was_on_floor = on_floor
	_land_blend = lerp(_land_blend, 0.0, clamp(delta * 6.0, 0.0, 1.0))
	var land := Vector3(0, -_land_blend * land_kick, 0)

	var crouch := crouch_offset if (_player != null and _player.has_method("is_crouching") and _player.is_crouching()) else Vector3.ZERO

	position = position.lerp(_base_pos + _sway_target + bob + breath + land + crouch, clamp(delta * sway_smoothing, 0.0, 1.0))
