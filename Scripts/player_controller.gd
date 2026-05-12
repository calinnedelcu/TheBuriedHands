extends CharacterBody3D

signal stance_changed(stance: String)

@export_group("Movement")
@export var sneak_speed: float = 1.6
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.4
@export var crouch_speed: float = 1.3
@export var acceleration: float = 10.0
@export var deceleration: float = 20.0
@export var jump_velocity: float = 4.5
@export var air_control_factor: float = 0.3
@export var jump_apex_gravity_multiplier: float = 2.0
@export var coyote_time_duration: float = 0.1
@export var jump_buffer_duration: float = 0.15

@export_group("Look Settings")
@export var mouse_sensitivity: float = 0.002
@export var tilt_lower_limit: float = deg_to_rad(-90.0)
@export var tilt_upper_limit: float = deg_to_rad(90.0)

@export_group("Head Bob")
@export var bob_amplitude: float = 0.02
@export var bob_frequency: float = 10.0
@export var bob_speed_multiplier: float = 1.0

@export_group("Stance")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var stand_camera_y: float = 1.6
@export var crouch_camera_y: float = 0.85
@export var stance_lerp_speed: float = 10.0

@export_group("Lean")
@export var lean_angle_deg: float = 14.0
@export var lean_offset: float = 0.22
@export var lean_lerp_speed: float = 8.0

@export_group("Noise")
@export var step_distance: float = 1.4
@export var noise_sneak: float = 0.4
@export var noise_walk: float = 1.0
@export var noise_sprint: float = 2.2
@export var noise_crouch: float = 0.2

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collider: CollisionShape3D = get_node_or_null("Collider")
@onready var lamp: Node = get_node_or_null("CameraPivot/Camera3D/ViewmodelRig/LampSocket/OilLamp")
@onready var interaction: Node = get_node_or_null("CameraPivot/Camera3D/InteractionRay")
@onready var inventory: Node = get_node_or_null("Inventory")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _initial_camera_local_position: Vector3
var _bob_time: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jump_held: bool = false

var _is_crouching: bool = false
var _is_sprinting: bool = false
var _lean_axis: float = 0.0
var _lean_blend: float = 0.0
var _distance_since_step: float = 0.0
var _current_stance: String = "În picioare"
var _capsule_shape: CapsuleShape3D
var _initial_capsule_height: float

func _setup_input_actions() -> void:
	var actions := {
		"move_forward": [KEY_W],
		"move_backward": [KEY_S],
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"jump": [KEY_SPACE],
		"crouch": [KEY_CTRL],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_F],
		"lean_left": [KEY_Q],
		"lean_right": [KEY_E],
		"toggle_lamp": [KEY_L],
		"raise_lamp": [KEY_ALT],
		"slot_0": [KEY_0],
		"slot_1": [KEY_1],
		"slot_2": [KEY_2],
		"slot_3": [KEY_3],
		"slot_4": [KEY_4],
	}
	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for keycode in actions[action_name]:
			var key_event := InputEventKey.new()
			key_event.keycode = keycode
			var already_mapped := false
			for ev in InputMap.action_get_events(action_name):
				if ev is InputEventKey and (ev as InputEventKey).keycode == keycode:
					already_mapped = true
					break
			if not already_mapped:
				InputMap.action_add_event(action_name, key_event)

func _ready() -> void:
	_initial_camera_local_position = camera.position
	if camera_pivot != null:
		camera_pivot.position.y = stand_camera_y
		_initial_camera_local_position.y = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_input_actions()
	if collider != null and collider.shape is CapsuleShape3D:
		_capsule_shape = collider.shape as CapsuleShape3D
		_initial_capsule_height = _capsule_shape.height
	stance_changed.emit(_current_stance)

func is_crouching() -> bool:
	return _is_crouching

func is_sprinting() -> bool:
	return _is_sprinting

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_duration

	if event.is_action_pressed("crouch"):
		_set_crouch(not _is_crouching)

	if event.is_action_pressed("interact"):
		if interaction != null and interaction.has_method("try_interact"):
			interaction.try_interact()

	if event.is_action_pressed("toggle_lamp"):
		if lamp != null and lamp.has_method("toggle"):
			lamp.toggle()

	if event.is_action_pressed("raise_lamp"):
		if lamp != null and lamp.has_method("set_raised"):
			lamp.set_raised(true)
	elif event.is_action_released("raise_lamp"):
		if lamp != null and lamp.has_method("set_raised"):
			lamp.set_raised(false)

	for i in 5:
		if event.is_action_pressed("slot_%d" % i):
			if inventory != null and inventory.has_method("set_slot"):
				inventory.set_slot(i)

func _physics_process(delta: float) -> void:
	is_jump_held = Input.is_action_pressed("jump")
	_is_sprinting = Input.is_action_pressed("sprint") and not _is_crouching and is_on_floor()

	if is_on_floor():
		coyote_timer = coyote_time_duration
	else:
		coyote_timer -= delta
	jump_buffer_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y < 0 and not is_jump_held:
			velocity.y -= gravity * (jump_apex_gravity_multiplier - 1.0) * delta

	if jump_buffer_timer > 0 and coyote_timer > 0 and not _is_crouching:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
		_emit_noise(noise_walk * 1.5)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_speed := _current_speed()
	var target_vx := direction.x * target_speed
	var target_vz := direction.z * target_speed

	var accel_rate := acceleration
	var decel_rate := deceleration
	if not is_on_floor():
		accel_rate *= air_control_factor
		decel_rate *= air_control_factor

	if direction:
		velocity.x = lerp(velocity.x, target_vx, accel_rate * delta)
		velocity.z = lerp(velocity.z, target_vz, accel_rate * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, decel_rate * delta)
		velocity.z = move_toward(velocity.z, 0, decel_rate * delta)

	# Lean
	var lean_input := 0.0
	if Input.is_action_pressed("lean_left"):
		lean_input -= 1.0
	if Input.is_action_pressed("lean_right"):
		lean_input += 1.0
	_lean_axis = lean_input
	_lean_blend = lerp(_lean_blend, _lean_axis, clamp(delta * lean_lerp_speed, 0.0, 1.0))
	camera_pivot.rotation.z = -deg_to_rad(lean_angle_deg) * _lean_blend
	camera.position.x = _initial_camera_local_position.x + _lean_blend * lean_offset

	# Stance height lerp
	var target_cam_y := crouch_camera_y if _is_crouching else stand_camera_y
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_cam_y, clamp(delta * stance_lerp_speed, 0.0, 1.0))
	if _capsule_shape != null:
		var target_h := crouch_height if _is_crouching else _initial_capsule_height
		_capsule_shape.height = lerp(_capsule_shape.height, target_h, clamp(delta * stance_lerp_speed, 0.0, 1.0))

	# Head bob (Y), applied on top of stance height
	if is_on_floor() and input_dir.length() > 0:
		_bob_time += delta * target_speed * bob_speed_multiplier
		var bob_offset_y := sin(_bob_time * bob_frequency) * bob_amplitude
		camera.position.y = _initial_camera_local_position.y + bob_offset_y
	else:
		_bob_time = 0.0
		camera.position.y = lerp(camera.position.y, _initial_camera_local_position.y, delta * 10.0)

	# Footstep noise
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.2:
		_distance_since_step += Vector2(velocity.x, velocity.z).length() * delta
		if _distance_since_step >= step_distance:
			_distance_since_step = 0.0
			_emit_noise(_step_noise())

	_update_stance_label()
	move_and_slide()

func _current_speed() -> float:
	if _is_crouching:
		return crouch_speed
	if _is_sprinting:
		return sprint_speed
	return walk_speed

func _step_noise() -> float:
	if _is_crouching:
		return noise_crouch
	if _is_sprinting:
		return noise_sprint
	return noise_walk

func _emit_noise(loudness: float) -> void:
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(global_position, loudness, self)

func _set_crouch(active: bool) -> void:
	# Refuse to stand if blocked above (basic check)
	if not active and _is_blocked_above():
		return
	_is_crouching = active

func _is_blocked_above() -> bool:
	# Simple test: short ray up from head height
	var from := global_position + Vector3(0, crouch_height, 0)
	var to := global_position + Vector3(0, stand_height + 0.1, 0)
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	return not hit.is_empty()

func _update_stance_label() -> void:
	var s := "Ghemuit" if _is_crouching else ("Aleargă" if _is_sprinting else "În picioare")
	if s != _current_stance:
		_current_stance = s
		stance_changed.emit(s)
