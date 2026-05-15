extends CharacterBody3D

const _FALLBACK_CLICK_SFX = preload("res://audio/sfx/menu_click.wav")
const _FALLBACK_ACTION_SFX = preload("res://audio/sfx/menu_play_start.wav")

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

@export_group("Movement Feel")
@export var sprint_acceleration_multiplier: float = 0.58
@export var sprint_deceleration_multiplier: float = 0.92
@export var crouch_acceleration_multiplier: float = 0.78
@export var crawl_acceleration_multiplier: float = 0.58
@export var direction_change_acceleration_multiplier: float = 0.72
@export var sprint_bob_multiplier: float = 1.18
@export var crouch_bob_multiplier: float = 0.42
@export var crawl_bob_multiplier: float = 0.24
@export var land_camera_kick: float = 0.035
@export var land_camera_recover_speed: float = 10.0

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

@export_group("Noise")
@export var step_distance: float = 1.4
@export var noise_sneak: float = 0.4
@export var noise_walk: float = 1.0
@export var noise_sprint: float = 2.2
@export var noise_crouch: float = 0.2
@export var noise_crawl: float = 0.08

@export_group("Throw")
@export var throw_speed: float = 11.0
@export var throw_arc_up: float = 1.5
@export var ceramic_shard_scene: PackedScene

@export_group("Lamp Drop")
@export var lamp_drop_distance: float = 1.1
@export var lamp_drop_probe_up: float = 1.1
@export var lamp_drop_probe_down: float = 2.4
@export var lamp_drop_surface_offset: float = 0.08
@export var lamp_drop_scale: float = 4.0

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

@export_group("Interaction Audio")
@export var interaction_audio_enabled: bool = true
@export var pickup_sfx_stream: AudioStream
@export var drop_sfx_stream: AudioStream
@export var lamp_toggle_sfx_stream: AudioStream
@export var lamp_select_sfx_stream: AudioStream
@export var refill_sfx_stream: AudioStream
@export var pickup_sfx_volume_db: float = -18.0
@export var drop_sfx_volume_db: float = -15.0
@export var lamp_toggle_sfx_volume_db: float = -19.0
@export var lamp_select_sfx_volume_db: float = -21.0
@export var refill_sfx_volume_db: float = -24.0
@export var refill_sfx_interval: float = 0.32

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collider: CollisionShape3D = get_node_or_null("Collider")
@onready var lamp_socket: Node3D = get_node_or_null("CameraPivot/Camera3D/ViewmodelRig/LampSocket")
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
var _distance_since_step: float = 0.0
var _current_stance: String = "În picioare"
var _camera_land_offset: float = 0.0
var _debug_accel_multiplier: float = 1.0
var _debug_decel_multiplier: float = 1.0
var _debug_head_bob_multiplier: float = 1.0
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
var _lamp_held_transform: Transform3D = Transform3D.IDENTITY
var _pickup_sfx_player: AudioStreamPlayer
var _drop_sfx_player: AudioStreamPlayer
var _lamp_toggle_sfx_player: AudioStreamPlayer
var _lamp_select_sfx_player: AudioStreamPlayer
var _refill_sfx_player: AudioStreamPlayer
var _refill_sfx_cooldown: float = 0.0

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
		"interact": [KEY_E],
		"pickup": [KEY_F],
		"drop": [KEY_X],
		"select_lamp": [KEY_Z],
		"toggle_lamp": [KEY_L],
		"raise_lamp": [KEY_ALT],
		"slot_0": [KEY_0],
		"slot_1": [KEY_1],
		"slot_2": [KEY_2],
		"slot_3": [KEY_3],
		"slot_4": [KEY_4],
		"throw": [KEY_G],
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
	add_to_group("player")
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
	if lamp is Node3D:
		_lamp_held_transform = (lamp as Node3D).transform
	_setup_interaction_audio()
	stance_changed.emit(_current_stance)

func is_crouching() -> bool:
	return _is_crouching

func is_crawling() -> bool:
	return _is_crawling

func is_sprinting() -> bool:
	return _is_sprinting

func current_stance_text() -> String:
	return _current_stance

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func current_target_speed() -> float:
	return _current_speed()

func current_step_noise() -> float:
	return _step_noise()

func current_surface_key() -> String:
	return _detect_surface_key()

func current_acceleration_multiplier() -> float:
	return _debug_accel_multiplier

func current_deceleration_multiplier() -> float:
	return _debug_decel_multiplier

func current_head_bob_multiplier() -> float:
	return _debug_head_bob_multiplier

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)

	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_duration

	if event.is_action_pressed("crouch"):
		_set_crouch(not _is_crouching)

	if event.is_action_pressed("crawl"):
		_set_crawl(not _is_crawling)

	if event.is_action_pressed("interact"):
		if interaction != null and interaction.has_method("try_interact"):
			interaction.try_interact()

	if event.is_action_pressed("pickup"):
		if interaction != null and interaction.has_method("try_pickup"):
			interaction.try_pickup()

	if event.is_action_pressed("drop"):
		_try_drop_active_item()

	if event.is_action_pressed("select_lamp"):
		if inventory != null and inventory.has_method("select_lamp"):
			if bool(inventory.call("select_lamp")):
				play_feedback_sfx("lamp_select")

	if event.is_action_pressed("toggle_lamp"):
		var l := _active_lamp()
		if l != null and l.has_method("toggle"):
			l.toggle()
			play_feedback_sfx("lamp_toggle")

	if event.is_action_pressed("raise_lamp"):
		var l := _active_lamp()
		if l != null and l.has_method("set_raised"):
			l.set_raised(true)
	elif event.is_action_released("raise_lamp"):
		var l := _active_lamp()
		if l != null and l.has_method("set_raised"):
			l.set_raised(false)

	# slot_0 = free hands, slot_1..slot_4 map to inventory slots 0..3.
	for i in 5:
		if event.is_action_pressed("slot_%d" % i):
			if inventory != null and inventory.has_method("set_slot"):
				inventory.set_slot(i - 1)

	if event.is_action_pressed("throw"):
		_try_throw_ceramic()

func _try_throw_ceramic() -> void:
	if inventory == null or ceramic_shard_scene == null:
		return
	if not inventory.has_method("current_item_id") or inventory.current_item_id() != "ceramic":
		return
	if not inventory.has_method("consume_current_stack") or not inventory.consume_current_stack():
		return
	var shard: RigidBody3D = ceramic_shard_scene.instantiate()
	get_tree().current_scene.add_child(shard)
	var spawn_origin: Vector3 = camera.global_position - camera.global_transform.basis.z * 0.3
	shard.global_position = spawn_origin
	var forward: Vector3 = -camera.global_transform.basis.z
	shard.linear_velocity = forward * throw_speed + Vector3.UP * throw_arc_up
	shard.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	_emit_noise(noise_walk * 0.4)

func get_fallback_interaction_prompt() -> String:
	if inventory != null and inventory.has_method("current_item_id") and inventory.current_item_id() != "":
		var item_name: String = inventory.current_name() if inventory.has_method("current_name") else ""
		return "Pune jos %s" % item_name if item_name != "" else "Pune jos"
	if inventory != null and inventory.has_method("active_lamp") and inventory.call("active_lamp") != null:
		return "Pune jos lampa"
	if inventory != null:
		return ""
	if _has_held_lamp():
		return "Pune jos lampa"
	return ""

## Called by lamp.gd when the player interacts with a lamp lying in the world.
func equip_lamp(lamp_node: Node) -> void:
	if lamp_node == null or not (lamp_node is Node3D):
		return
	if inventory == null or not inventory.has_method("add_item"):
		_equip_lamp_direct(lamp_node)
		return
	if inventory.add_item("lamp", lamp_node) < 0:
		return  # inventory full — the lamp stays in the world
	_emit_noise(noise_walk * 0.25)
	play_feedback_sfx("pickup")

func _active_lamp() -> Node:
	if inventory != null and inventory.has_method("active_lamp"):
		var inv_lamp: Node = inventory.call("active_lamp")
		if inv_lamp != null:
			return inv_lamp
	if inventory != null:
		return null
	if _has_held_lamp():
		return lamp
	return null

func _try_drop_active_item() -> bool:
	if inventory != null and inventory.has_method("drop_current") and bool(inventory.call("drop_current", self)):
		_emit_noise(noise_walk * 0.35)
		play_feedback_sfx("drop")
		return true
	if inventory != null:
		return false
	return _try_drop_held_lamp()

func _equip_lamp_direct(lamp_node: Node) -> void:
	if lamp_socket == null or not (lamp_node is Node3D):
		return
	lamp = lamp_node
	var lamp_3d := lamp_node as Node3D
	lamp_3d.reparent(lamp_socket)
	lamp_3d.transform = _lamp_held_transform
	if lamp_node.has_method("set_equipped"):
		lamp_node.set_equipped(true)
	_emit_noise(noise_walk * 0.25)
	play_feedback_sfx("pickup")

func _has_held_lamp() -> bool:
	return lamp != null and is_instance_valid(lamp) and lamp_socket != null and lamp.get_parent() == lamp_socket

func _try_drop_held_lamp() -> bool:
	if not _has_held_lamp() or not (lamp is Node3D):
		return false
	var world_parent := get_tree().current_scene
	if world_parent == null:
		world_parent = get_parent()
	if world_parent == null:
		return false
	if lamp.has_method("set_raised"):
		lamp.set_raised(false)
	var lamp_3d := lamp as Node3D
	lamp_3d.reparent(world_parent)
	lamp_3d.global_transform = get_drop_transform(true)
	if lamp.has_method("set_equipped"):
		lamp.set_equipped(false)
	_emit_noise(noise_walk * 0.35)
	play_feedback_sfx("drop")
	return true

## Where a dropped item lands: a floor-probed spot a short distance ahead.
## `scaled` applies lamp_drop_scale (the lamp's hand model is tiny otherwise).
func get_drop_transform(scaled: bool) -> Transform3D:
	var flat_forward := -global_transform.basis.z
	flat_forward.y = 0.0
	if flat_forward.length_squared() < 0.001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()

	var probe_center := global_position + flat_forward * lamp_drop_distance
	var from := probe_center + Vector3.UP * lamp_drop_probe_up
	var to := probe_center + Vector3.DOWN * lamp_drop_probe_down
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	var drop_position := probe_center + Vector3.DOWN * 0.9
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.get("position")
		var hit_normal: Vector3 = hit.get("normal")
		drop_position = hit_pos + hit_normal.normalized() * lamp_drop_surface_offset

	var scale_factor: float = lamp_drop_scale if scaled else 1.0
	var yaw_basis := Basis(Vector3.UP, rotation.y).scaled(Vector3.ONE * scale_factor)
	return Transform3D(yaw_basis, drop_position)

func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	_refill_sfx_cooldown = maxf(0.0, _refill_sfx_cooldown - delta)
	is_jump_held = Input.is_action_pressed("jump")
	_is_sprinting = Input.is_action_pressed("sprint") and not _is_crouching and not _is_crawling and is_on_floor()

	# Hold-action interact: cat timp E e tinut, transmitem dt catre Interactable curent.
	if interaction != null and Input.is_action_pressed("interact") and interaction.has_method("try_interact_hold"):
		interaction.try_interact_hold(delta)

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
	_debug_accel_multiplier = _movement_acceleration_multiplier(direction)
	_debug_decel_multiplier = _movement_deceleration_multiplier()
	accel_rate *= _debug_accel_multiplier
	decel_rate *= _debug_decel_multiplier
	if not is_on_floor():
		accel_rate *= air_control_factor
		decel_rate *= air_control_factor

	if direction:
		var accel_t: float = clamp(accel_rate * delta, 0.0, 1.0)
		velocity.x = lerp(velocity.x, target_vx, accel_t)
		velocity.z = lerp(velocity.z, target_vz, accel_t)
	else:
		velocity.x = move_toward(velocity.x, 0, decel_rate * delta)
		velocity.z = move_toward(velocity.z, 0, decel_rate * delta)

	# Stance height lerp
	var target_cam_y := _target_camera_y()
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_cam_y, clamp(delta * stance_lerp_speed, 0.0, 1.0))
	if _capsule_shape != null:
		var target_h := _target_capsule_height()
		var target_radius := _target_capsule_radius()
		_capsule_shape.height = lerp(_capsule_shape.height, target_h, clamp(delta * stance_lerp_speed, 0.0, 1.0))
		_capsule_shape.radius = lerp(_capsule_shape.radius, target_radius, clamp(delta * stance_lerp_speed, 0.0, 1.0))

	_camera_land_offset = lerp(_camera_land_offset, 0.0, clamp(delta * land_camera_recover_speed, 0.0, 1.0))

	# Head bob (Y), applied on top of stance height
	var bob_offset_y := 0.0
	_debug_head_bob_multiplier = _head_bob_multiplier()
	if is_on_floor() and input_dir.length() > 0:
		_bob_time += delta * target_speed * bob_speed_multiplier * _debug_head_bob_multiplier
		bob_offset_y = sin(_bob_time * bob_frequency) * bob_amplitude * _debug_head_bob_multiplier
		camera.position.y = _initial_camera_local_position.y + bob_offset_y - _camera_land_offset
	else:
		_bob_time = 0.0
		camera.position.y = lerp(camera.position.y, _initial_camera_local_position.y - _camera_land_offset, delta * 10.0)

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
		var impact: float = clamp(fall_speed_before_slide / hard_land_velocity, 0.0, 1.0)
		_camera_land_offset = maxf(_camera_land_offset, land_camera_kick * impact)
		_play_land_sound(fall_speed_before_slide)

func _current_speed() -> float:
	if _is_crawling:
		return crawl_speed
	if _is_crouching:
		return crouch_speed
	if _is_sprinting:
		return sprint_speed
	return walk_speed

func _movement_acceleration_multiplier(direction: Vector3) -> float:
	var mult := 1.0
	if _is_crawling:
		mult *= crawl_acceleration_multiplier
	elif _is_crouching:
		mult *= crouch_acceleration_multiplier
	elif _is_sprinting:
		mult *= sprint_acceleration_multiplier
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if direction != Vector3.ZERO and horizontal_velocity.length_squared() > 0.16:
		var current_dir := horizontal_velocity.normalized()
		if current_dir.dot(direction.normalized()) < -0.2:
			mult *= direction_change_acceleration_multiplier
	return mult

func _movement_deceleration_multiplier() -> float:
	if _is_sprinting:
		return sprint_deceleration_multiplier
	if _is_crawling:
		return crawl_acceleration_multiplier
	if _is_crouching:
		return crouch_acceleration_multiplier
	return 1.0

func _head_bob_multiplier() -> float:
	if _is_crawling:
		return crawl_bob_multiplier
	if _is_crouching:
		return crouch_bob_multiplier
	if _is_sprinting:
		return sprint_bob_multiplier
	return 1.0

func _step_noise() -> float:
	if _is_crawling:
		return noise_crawl
	if _is_crouching:
		return noise_crouch
	if _is_sprinting:
		return noise_sprint
	return noise_walk

func play_feedback_sfx(kind: String) -> void:
	if not interaction_audio_enabled:
		return
	match kind:
		"pickup":
			_play_feedback_player(_pickup_sfx_player, pickup_sfx_volume_db, 1.05)
		"drop":
			_play_feedback_player(_drop_sfx_player, drop_sfx_volume_db, 0.72)
		"lamp_toggle":
			_play_feedback_player(_lamp_toggle_sfx_player, lamp_toggle_sfx_volume_db, 1.18)
		"lamp_select":
			_play_feedback_player(_lamp_select_sfx_player, lamp_select_sfx_volume_db, 1.32)
		"refill":
			if _refill_sfx_cooldown > 0.0:
				return
			_refill_sfx_cooldown = refill_sfx_interval
			_play_feedback_player(_refill_sfx_player, refill_sfx_volume_db, 1.48)

func _setup_interaction_audio() -> void:
	if not interaction_audio_enabled:
		return
	_pickup_sfx_player = _make_feedback_player("PickupSFX", pickup_sfx_stream, _FALLBACK_CLICK_SFX, pickup_sfx_volume_db)
	_drop_sfx_player = _make_feedback_player("DropSFX", drop_sfx_stream, _FALLBACK_ACTION_SFX, drop_sfx_volume_db)
	_lamp_toggle_sfx_player = _make_feedback_player("LampToggleSFX", lamp_toggle_sfx_stream, _FALLBACK_CLICK_SFX, lamp_toggle_sfx_volume_db)
	_lamp_select_sfx_player = _make_feedback_player("LampSelectSFX", lamp_select_sfx_stream, _FALLBACK_CLICK_SFX, lamp_select_sfx_volume_db)
	_refill_sfx_player = _make_feedback_player("RefillSFX", refill_sfx_stream, _FALLBACK_CLICK_SFX, refill_sfx_volume_db)

func _make_feedback_player(player_name: String, stream: AudioStream, fallback: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream if stream != null else fallback
	player.volume_db = volume_db
	add_child(player)
	return player

func _play_feedback_player(player: AudioStreamPlayer, volume_db: float, pitch: float) -> void:
	if player == null or player.stream == null:
		return
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.96, 1.04)
	player.play()

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
	var current_height: float = crawl_height if _is_crawling else crouch_height
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
	var s: String = "Ghemuit" if _is_crouching else ("Aleargă" if _is_sprinting else "În picioare")
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
