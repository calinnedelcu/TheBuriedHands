extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 20.0 # Renamed from friction for clarity and direct use
@export var jump_velocity: float = 4.5
@export var air_control_factor: float = 0.3 # How much horizontal movement is allowed in the air (0 to 1)
@export var jump_apex_gravity_multiplier: float = 2.0 # Gravity multiplier when jump button is released mid-air (e.g., 2.0 for faster fall)
@export var coyote_time_duration: float = 0.1 # Time in seconds after leaving ground during which a jump is still possible
@export var jump_buffer_duration: float = 0.15 # Time in seconds before landing during which a jump input is buffered

@export_group("Look Settings")
@export var mouse_sensitivity: float = 0.002
@export var tilt_lower_limit: float = deg_to_rad(-90.0)
@export var tilt_upper_limit: float = deg_to_rad(90.0)

@export_group("Head Bob")
@export var bob_amplitude: float = 0.02 # How much the camera moves up and down
@export var bob_frequency: float = 10.0 # How fast the bobbing occurs
@export var bob_speed_multiplier: float = 1.0 # Multiplier for bobbing speed based on character speed

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Internal state variables for fluid movement
var _initial_camera_local_position: Vector3 # Stores the camera's original local position
var _bob_time: float = 0.0 # Tracks time for head bobbing sine wave
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jump_held: bool = false # Track if jump button is currently pressed

func _setup_input_actions() -> void:
	# Define movement actions
	var movement_actions = {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE
	}

	for action_name in movement_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		
		var key_event = InputEventKey.new()
		key_event.keycode = movement_actions[action_name]
		
		# Check if the event is already mapped to avoid duplicates
		var already_mapped = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.keycode == key_event.keycode:
				already_mapped = true
				break
		
		if not already_mapped:
			InputMap.action_add_event(action_name, key_event)

func _ready() -> void:
	_initial_camera_local_position = camera.position # Store initial camera position for bobbing
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_input_actions() # Call the setup function

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

	# Set jump buffer when jump is just pressed
	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_duration

func _physics_process(delta: float) -> void:
	# Update jump held state
	is_jump_held = Input.is_action_pressed("jump")

	# Update coyote time
	if is_on_floor():
		coyote_timer = coyote_time_duration
	else:
		coyote_timer -= delta

	# Update jump buffer timer
	jump_buffer_timer -= delta

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		# Apply extra gravity for variable jump height if jump button is released and falling
		if velocity.y < 0 and not is_jump_held:
			velocity.y -= gravity * (jump_apex_gravity_multiplier - 1.0) * delta

	# Jump logic (with coyote time and jump buffer)
	# A jump is initiated if the jump button was pressed recently (buffer) AND
	# the player is on the floor or recently left it (coyote time).
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0 # Consume buffer
		coyote_timer = 0 # Consume coyote time

	# Using default UI actions for movement (Arrows/WASD usually mapped by default in Godot)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") # This is already correct
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_velocity_x = direction.x * walk_speed
	var target_velocity_z = direction.z * walk_speed

	var current_acceleration_rate = acceleration
	var current_deceleration_rate = deceleration

	# Adjust acceleration/deceleration for air control
	if not is_on_floor():
		current_acceleration_rate *= air_control_factor
		current_deceleration_rate *= air_control_factor # Also reduce air deceleration for a more floaty feel

	if direction:
		# Accelerate towards target speed
		velocity.x = lerp(velocity.x, target_velocity_x, current_acceleration_rate * delta)
		velocity.z = lerp(velocity.z, target_velocity_z, current_acceleration_rate * delta)
	else:
		# Decelerate to stop
		velocity.x = move_toward(velocity.x, 0, current_deceleration_rate * delta)
		velocity.z = move_toward(velocity.z, 0, current_deceleration_rate * delta)

	# Head Bobbing
	if is_on_floor() and input_dir.length() > 0:
		# Advance bob time based on speed
		_bob_time += delta * walk_speed * bob_speed_multiplier
		# Calculate vertical offset using a sine wave
		var bob_offset_y = sin(_bob_time * bob_frequency) * bob_amplitude
		# Apply offset to camera's local y position
		camera.position.y = _initial_camera_local_position.y + bob_offset_y
	else:
		# Reset bob time and smoothly return camera to initial position when not moving or in air
		_bob_time = 0.0
		camera.position.y = lerp(camera.position.y, _initial_camera_local_position.y, delta * 10.0)

	move_and_slide()
