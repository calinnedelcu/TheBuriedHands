extends CharacterBody3D

signal stance_changed(stance: String)

@export_group("Movement")
@export var sneak_speed: float = 1.6
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.4
@export var crouch_speed: float = 1.3
@export var crawl_speed: float = 0.75
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
@export var crawl_height: float = 0.55
@export var stand_camera_y: float = 1.7
@export var crouch_camera_y: float = 0.85
@export var crawl_camera_y: float = 0.35
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
@export var noise_crawl: float = 0.08

@export_group("Movement Audio")
@export var movement_audio_enabled: bool = true
@export var footstep_audio_dir: String = "res://audio/sfx/player/footsteps"
@export var footstep_surface_dirs: Dictionary = {
	"clay": "res://audio/sfx/player/footsteps/clay",
	"stone": "res://audio/sfx/player/footsteps/stone",
	"wood": "res://audio/sfx/player/footsteps/wood",
	"wet_stone": "res://audio/sfx/player/footsteps/wet_stone",
}
@export var jump_audio_dir: String = "res://audio/sfx/player/jump"
@export var land_audio_dir: String = "res://audio/sfx/player/land"
@export var footstep_streams: Array[AudioStream] = []
@export var jump_streams: Array[AudioStream] = []
@export var land_streams: Array[AudioStream] = []
@export var footstep_volume_db: float = -13.0
@export var jump_volume_db: float = -15.0
@export var land_volume_db: float = -11.0
@export var hard_land_velocity: float = 8.0
@export var footstep_pitch_random: float = 1.06
@export var footstep_volume_random_db: float = 1.8
@export var jump_pitch_random: float = 1.04
@export var land_pitch_random: float = 1.04

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
var _is_crawling: bool = false
var _is_sprinting: bool = false
var _lean_axis: float = 0.0
var _lean_blend: float = 0.0
var _distance_since_step: float = 0.0
var _current_stance: String = "În picioare"
var _capsule_shape: CapsuleShape3D
var _initial_capsule_height: float
var _initial_capsule_radius: float
var _footstep_player: AudioStreamPlayer
var _jump_player: AudioStreamPlayer
var _land_player: AudioStreamPlayer
var _footstep_stream: AudioStreamRandomizer
var _footstep_streams_by_surface: Dictionary = {}
var _jump_stream: AudioStreamRandomizer
var _land_stream: AudioStreamRandomizer

func _setup_input_actions() -> void:
	var actions := {
		"move_forward": [KEY_W],
		"move_backward": [KEY_S],
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"jump": [KEY_SPACE],
		"crouch": [KEY_CTRL],
		"crawl": [KEY_C],
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
		_initial_capsule_radius = _capsule_shape.radius
	_setup_movement_audio()
	stance_changed.emit(_current_stance)

func is_crouching() -> bool:
	return _is_crouching

func is_crawling() -> bool:
	return _is_crawling

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

	if event.is_action_pressed("crawl"):
		_set_crawl(not _is_crawling)

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
	var was_on_floor := is_on_floor()
	is_jump_held = Input.is_action_pressed("jump")
	_is_sprinting = Input.is_action_pressed("sprint") and not _is_crouching and not _is_crawling and is_on_floor()

	if is_on_floor():
		coyote_timer = coyote_time_duration
	else:
		coyote_timer -= delta
	jump_buffer_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y < 0 and not is_jump_held:
			velocity.y -= gravity * (jump_apex_gravity_multiplier - 1.0) * delta

	if jump_buffer_timer > 0 and coyote_timer > 0 and not _is_crouching and not _is_crawling:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
		_emit_noise(noise_walk * 1.5)
		_play_jump_sound()

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
	var target_cam_y := _target_camera_y()
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_cam_y, clamp(delta * stance_lerp_speed, 0.0, 1.0))
	if _capsule_shape != null:
		var target_h := _target_capsule_height()
		var target_radius := _target_capsule_radius()
		_capsule_shape.height = lerp(_capsule_shape.height, target_h, clamp(delta * stance_lerp_speed, 0.0, 1.0))
		_capsule_shape.radius = lerp(_capsule_shape.radius, target_radius, clamp(delta * stance_lerp_speed, 0.0, 1.0))

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
			_play_footstep_sound()

	_update_stance_label()
	var fall_speed_before_slide := -velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor() and fall_speed_before_slide > 1.0:
		_play_land_sound(fall_speed_before_slide)

func _current_speed() -> float:
	if _is_crawling:
		return crawl_speed
	if _is_crouching:
		return crouch_speed
	if _is_sprinting:
		return sprint_speed
	return walk_speed

func _step_noise() -> float:
	if _is_crawling:
		return noise_crawl
	if _is_crouching:
		return noise_crouch
	if _is_sprinting:
		return noise_sprint
	return noise_walk

func _emit_noise(loudness: float) -> void:
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(global_position, loudness, self)

func _setup_movement_audio() -> void:
	if not movement_audio_enabled:
		return
	_footstep_stream = _make_randomizer(footstep_streams, footstep_audio_dir, footstep_pitch_random, footstep_volume_random_db)
	_footstep_streams_by_surface = _make_surface_randomizers()
	_jump_stream = _make_randomizer(jump_streams, jump_audio_dir, jump_pitch_random, 1.0)
	_land_stream = _make_randomizer(land_streams, land_audio_dir, land_pitch_random, 1.4)
	if _jump_stream == null:
		_jump_stream = _footstep_stream
	if _land_stream == null:
		_land_stream = _footstep_stream

	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.name = "FootstepAudio"
	_footstep_player.volume_db = footstep_volume_db
	_footstep_player.stream = _footstep_stream
	add_child(_footstep_player)

	_jump_player = AudioStreamPlayer.new()
	_jump_player.name = "JumpAudio"
	_jump_player.volume_db = jump_volume_db
	_jump_player.stream = _jump_stream
	add_child(_jump_player)

	_land_player = AudioStreamPlayer.new()
	_land_player.name = "LandAudio"
	_land_player.volume_db = land_volume_db
	_land_player.stream = _land_stream
	add_child(_land_player)

func _play_footstep_sound() -> void:
	if not movement_audio_enabled or _footstep_player == null or _footstep_stream == null:
		return
	var stance_gain := 1.0
	if _is_crawling:
		stance_gain = 0.35
	elif _is_crouching:
		stance_gain = 0.55
	elif _is_sprinting:
		stance_gain = 1.25
	var surface_stream := _get_footstep_stream_for_surface(_detect_surface_key())
	if surface_stream != null:
		_footstep_player.stream = surface_stream
	_footstep_player.volume_db = footstep_volume_db + linear_to_db(stance_gain)
	_footstep_player.play()

func _play_jump_sound() -> void:
	if not movement_audio_enabled or _jump_player == null or _jump_stream == null:
		return
	_jump_player.play()

func _play_land_sound(fall_speed: float) -> void:
	if not movement_audio_enabled or _land_player == null or _land_stream == null:
		return
	var impact: float = clamp(fall_speed / hard_land_velocity, 0.35, 1.35)
	_land_player.volume_db = land_volume_db + linear_to_db(impact)
	_land_player.play()

func _make_randomizer(manual_streams: Array[AudioStream], audio_dir: String, pitch_random: float, volume_random_db: float) -> AudioStreamRandomizer:
	var streams := _collect_audio_streams(manual_streams, audio_dir)
	if streams.is_empty():
		return null
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = pitch_random
	randomizer.random_volume_offset_db = volume_random_db
	for i in streams.size():
		randomizer.add_stream(i, streams[i], 1.0)
	return randomizer

func _make_surface_randomizers() -> Dictionary:
	var randomizers := {}
	var empty_streams: Array[AudioStream] = []
	for surface in footstep_surface_dirs:
		var audio_dir := str(footstep_surface_dirs[surface])
		var randomizer := _make_randomizer(empty_streams, audio_dir, footstep_pitch_random, footstep_volume_random_db)
		if randomizer != null:
			randomizers[str(surface)] = randomizer
	return randomizers

func _get_footstep_stream_for_surface(surface_key: String) -> AudioStreamRandomizer:
	if _footstep_streams_by_surface.has(surface_key):
		return _footstep_streams_by_surface[surface_key] as AudioStreamRandomizer
	return _footstep_stream

func _detect_surface_key() -> String:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.25, global_position + Vector3.DOWN * 1.35)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return "default"
	var collider_node := hit.get("collider") as Node
	return _surface_key_from_node(collider_node)

func _surface_key_from_node(node: Node) -> String:
	var text := ""
	var current := node
	var depth := 0
	while current != null and depth < 6:
		text += " " + current.name.to_lower()
		current = current.get_parent()
		depth += 1
	if "drainage" in text or "exitshaft" in text or "mercury" in text:
		return "wet_stone"
	if "workshop" in text or "storage" in text or "kiln" in text:
		return "clay"
	if "wood" in text or "plank" in text or "bridge" in text:
		return "wood"
	if "corridor" in text or "guardpost" in text or "gate" in text or "mechanism" in text:
		return "stone"
	return "default"

func _collect_audio_streams(manual_streams: Array[AudioStream], audio_dir: String) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for stream in manual_streams:
		if stream != null:
			streams.append(stream)
	if streams.is_empty():
		streams.append_array(_load_audio_streams_from_dir(audio_dir))
	return streams

func _load_audio_streams_from_dir(audio_dir: String) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	var dir := DirAccess.open(audio_dir)
	if dir == null:
		return streams
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_supported_audio_file(file_name):
			var file_path := audio_dir.path_join(file_name)
			var resource: Resource = ResourceLoader.load(file_path)
			if resource is AudioStream:
				streams.append(resource as AudioStream)
		file_name = dir.get_next()
	dir.list_dir_end()
	return streams

func _is_supported_audio_file(file_name: String) -> bool:
	var extension := file_name.get_extension().to_lower()
	return extension == "wav" or extension == "ogg" or extension == "mp3"

func _set_crouch(active: bool) -> void:
	if active and _is_crawling:
		_set_crawl(false)
	# Refuse to stand if blocked above (basic check)
	if not active and _is_blocked_above():
		return
	_is_crouching = active

func _set_crawl(active: bool) -> void:
	if active:
		_is_crouching = false
		_is_sprinting = false
	else:
		if _is_blocked_above():
			return
	_is_crawling = active

func _is_blocked_above() -> bool:
	# Simple test: short ray up from head height
	var current_height := crawl_height if _is_crawling else crouch_height
	var from := global_position + Vector3(0, current_height, 0)
	var to := global_position + Vector3(0, stand_height + 0.1, 0)
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	return not hit.is_empty()

func _update_stance_label() -> void:
	if _is_crawling:
		if _current_stance != "Taras":
			_current_stance = "Taras"
			stance_changed.emit(_current_stance)
		return
	var s := "Ghemuit" if _is_crouching else ("Aleargă" if _is_sprinting else "În picioare")
	if s != _current_stance:
		_current_stance = s
		stance_changed.emit(s)

func _target_camera_y() -> float:
	if _is_crawling:
		return crawl_camera_y
	if _is_crouching:
		return crouch_camera_y
	return stand_camera_y

func _target_capsule_height() -> float:
	if _is_crawling:
		return crawl_height
	if _is_crouching:
		return crouch_height
	return _initial_capsule_height

func _target_capsule_radius() -> float:
	if _is_crawling:
		return minf(_initial_capsule_radius, 0.28)
	return _initial_capsule_radius
