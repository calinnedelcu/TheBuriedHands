extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var acceleration: float = 10.0
@export var friction: float = 8.0
@export var jump_velocity: float = 4.5

@export_group("Look Settings")
@export var mouse_sensitivity: float = 0.002
@export var tilt_lower_limit: float = deg_to_rad(-90.0)
@export var tilt_upper_limit: float = deg_to_rad(90.0)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Using default UI actions for movement (Arrows/WASD usually mapped by default in Godot)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = lerp(velocity.x, direction.x * walk_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * walk_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * walk_speed * delta)
		velocity.z = move_toward(velocity.z, 0, friction * walk_speed * delta)

	move_and_slide()
