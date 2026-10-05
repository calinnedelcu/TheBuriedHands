class_name Viewmodel
extends Node3D
## First-person arms. The left hand carries the lamp, the right hand the
## selected item; each arm slides into view only while it holds something.
## Adds mouse sway, walk bob, breathing and a small "use" strike animation;
## on a ladder the hands reach up for the rungs in turn, crawling they paw
## forward along the ground.

@export_group("Arm layout (camera space)")
## Where each hand grips, relative to the camera.
@export var left_grip := Vector3(-0.3, -0.26, -0.5)
@export var right_grip := Vector3(0.31, -0.28, -0.46)
## Direction from the hand back along the forearm (toward the elbow).
@export var left_forearm := Vector3(-0.35, -0.55, 0.76)
@export var right_forearm := Vector3(0.38, -0.55, 0.74)
## Twist of each arm around its forearm, degrees.
@export var left_roll := 0.0
@export var right_roll := 0.0
@export var arm_scale := 0.6
## Centre of each hand inside the arm meshes (mesh-local units).
@export var left_hand_center := Vector3(-0.17, 0.12, 0.23)
@export var right_hand_center := Vector3(0.17, 0.12, -0.23)
@export_group("Motion")
@export var sway_amount := 0.00045
@export var sway_max := 0.06
@export var bob_amount := 0.018
@export var breath_amount := 0.004
@export var hidden_drop := 0.55
@export var raise_offset := Vector3(0.06, 0.2, -0.08)
@export var crawl_drop := 0.12
## How far each hand reaches for the next rung, and drags forward crawling.
@export var climb_reach := 0.11
@export var crawl_reach := 0.07

@onready var _left: Node3D = $LeftArm
@onready var _right: Node3D = $RightArm
@onready var _item_socket: Node3D = $RightArm/ItemSocket

var _player: Player
var _left_rest: Transform3D
var _right_rest: Transform3D
var _left_show := 0.0
var _right_show := 0.0
var _raise := 0.0
var _use := 0.0
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _t := 0.0
var _item_visual: Node3D
var _climb := 0.0
var _climb_t := 0.0
var _crawl_t := 0.0
var _ready_done := false

func _ready() -> void:
	_player = owner as Player
	if not _player.is_node_ready():
		await _player.ready
	relayout()
	ViewmodelMaterial.apply(_left)
	ViewmodelMaterial.apply(_right)
	var inventory := _player.inventory
	inventory.selection_changed.connect(_on_selection_changed)
	inventory.changed.connect(_refresh_item)
	_on_selection_changed(inventory.selected)
	_ready_done = true

## A short forward strike, e.g. chisel taps or splitting stone.
func play_use() -> void:
	_use = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_done:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_sway += (event as InputEventMouseMotion).screen_relative * sway_amount

func _process(delta: float) -> void:
	if not _ready_done:
		return
	_t += delta
	var inventory := _player.inventory
	var lamp := inventory.lamp()
	var climbing := _player.on_ladder()
	_climb = move_toward(_climb, 1.0 if climbing else 0.0, delta * 4.0)
	_left_show = move_toward(_left_show, 1.0 if lamp != null else 0.0, delta * 3.0)
	# A free hand comes up for the rungs; what it held goes in the belt.
	_right_show = move_toward(_right_show, 1.0 if _item_visual != null or climbing else 0.0, delta * 4.0)
	if _item_visual != null:
		_item_visual.visible = _climb < 0.5
	_raise = lerpf(_raise, 1.0 if lamp != null and lamp.is_raised else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	_use = move_toward(_use, 0.0, delta * 3.5)
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	_sway = _sway.limit_length(sway_max)

	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if _player.is_on_floor() and speed > 0.3:
		_bob_t += delta * speed * 1.4
	var bob_scale := clampf(speed / _player.walk_speed, 0.0, 1.6) * float(Settings.get_value(&"head_bob"))
	var bob := Vector3(sin(_bob_t) * bob_amount, -absf(cos(_bob_t)) * bob_amount * 0.8, 0.0) * bob_scale
	var breath := Vector3(0.0, sin(_t * 1.7) * breath_amount, 0.0)
	var sway := Vector3(-_sway.x, _sway.y, 0.0)
	var stance_drop := Vector3.DOWN * crawl_drop if _player.is_crawling() else Vector3.ZERO
	var common := bob + breath + sway + stance_drop

	# Climbing: hand over hand, in step with the climb.
	if climbing:
		_climb_t += absf(_player.velocity.y) * delta * 3.2
	var reach_r := (sin(_climb_t) * 0.5 + 0.5) * _climb
	var reach_l := (sin(_climb_t + PI) * 0.5 + 0.5) * _climb
	var climb_r := Vector3(-0.04, 0.06 + climb_reach * reach_r, -0.06) * _climb
	var climb_l := Vector3(0.03, 0.04 + climb_reach * 0.6 * reach_l, -0.04) * _climb
	# Crawling: each hand drags forward in turn.
	var crawl_l := Vector3.ZERO
	var crawl_r := Vector3.ZERO
	if _player.is_crawling():
		var speed_c := Vector2(_player.velocity.x, _player.velocity.z).length()
		_crawl_t += speed_c * delta * 4.5
		var amount := clampf(speed_c / maxf(_player.crawl_speed, 0.01), 0.0, 1.0)
		crawl_l = Vector3(0.0, -absf(sin(_crawl_t)) * 0.02, -cos(_crawl_t) * crawl_reach) * amount
		crawl_r = Vector3(0.0, -absf(cos(_crawl_t)) * 0.02, cos(_crawl_t) * crawl_reach) * amount

	var left_offset := common + raise_offset * _raise + climb_l + crawl_l + Vector3.DOWN * hidden_drop * (1.0 - _ease(_left_show))
	_left.transform = Transform3D(_left_rest.basis, _left_rest.origin + left_offset)
	var strike := sin(_use * PI)
	var right_offset := common * 1.1 + Vector3(0.0, 0.03, -0.12) * strike + climb_r + crawl_r + Vector3.DOWN * hidden_drop * (1.0 - _ease(_right_show))
	var right_basis := _right_rest.basis.rotated(Vector3.RIGHT, -0.5 * strike + 0.6 * _climb * (0.4 + reach_r))
	_right.transform = Transform3D(right_basis, _right_rest.origin + right_offset)
	_left.visible = _left_show > 0.01
	_right.visible = _right_show > 0.01

## Recomputes both arms from the layout exports (also used by the tuning tool).
func relayout() -> void:
	_layout_arm(_left, $LeftArm/Mesh, left_grip, left_forearm, left_roll, left_hand_center)
	_layout_arm(_right, $RightArm/Mesh, right_grip, right_forearm, right_roll, right_hand_center)
	_left_rest = _left.transform
	_right_rest = _right.transform

## Places an arm so its hand sits at `grip` and the forearm runs along
## `forearm`. The arm node keeps the camera's orientation, so items held in
## its socket can be posed intuitively.
func _layout_arm(arm: Node3D, mesh: Node3D, grip: Vector3, forearm: Vector3, roll_deg: float, hand_center: Vector3) -> void:
	arm.transform = Transform3D(Basis(), grip)
	var y := forearm.normalized()
	var x := Vector3.UP.cross(y).normalized()
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	var z := x.cross(y).normalized()
	var b := Basis(x, y, z).rotated(y, deg_to_rad(roll_deg)) * Basis.from_scale(Vector3.ONE * arm_scale)
	mesh.transform = Transform3D(b, -(b * hand_center))

func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _on_selection_changed(_index: int) -> void:
	_refresh_item()

func _refresh_item() -> void:
	var item := _player.inventory.selected_item()
	var current_id: StringName = _item_visual.get_meta(&"item_id") if _item_visual != null else &""
	if item != null and item.id == current_id:
		return
	if _item_visual != null:
		_item_visual.queue_free()
		_item_visual = null
	if item == null:
		return
	var scene := item.hand_scene if item.hand_scene != null else item.world_scene
	if scene == null:
		return
	_item_visual = scene.instantiate() as Node3D
	_item_visual.set_meta(&"item_id", item.id)
	_item_visual.transform = item.hand_transform
	_item_socket.add_child(_item_visual)
	ViewmodelMaterial.apply(_item_visual)
	_right_show = minf(_right_show, 0.3)
