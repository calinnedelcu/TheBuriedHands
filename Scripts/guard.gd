class_name Guard
extends CharacterBody3D

signal state_changed(state: int)

enum State { PATROL, SUSPICIOUS, ALERT, DETECT }

@export var waypoints_path: NodePath
@export var patrol_speed: float = 1.2
@export var alert_speed: float = 2.6
@export var vision_range: float = 8.0
@export var vision_angle_deg: float = 55.0
@export var detect_seconds: float = 0.8
@export var pause_at_waypoint: float = 1.5
@export var suspicion_decay: float = 0.4
@export var suspicion_to_alert: float = 1.0
@export var noise_threshold_suspicious: float = 0.6
@export var noise_threshold_alert: float = 1.4
@export var step_distance: float = 1.4
@export var player_group: String = "player"

@onready var _vision_origin: Node3D = (get_node_or_null("VisionOrigin") as Node3D) if has_node("VisionOrigin") else self
@onready var _footstep_audio: AudioStreamPlayer3D = get_node_or_null("FootstepAudio")
@onready var _alert_audio: AudioStreamPlayer3D = get_node_or_null("AlertAudio")
@warning_ignore("unused_private_class_variable")
@onready var _ambient_audio: AudioStreamPlayer3D = get_node_or_null("AmbientAudio")
@onready var _vision_indicator: MeshInstance3D = get_node_or_null("VisionOrigin/VisionIndicator")

var _waypoints: Array[Node3D] = []
var _waypoint_index: int = 0
var _state: int = State.PATROL
var _pause_timer: float = 0.0
var _suspicion: float = 0.0
var _last_known_position: Vector3
var _player: Node3D = null
var _detect_timer: float = 0.0
var _distance_since_step: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("guards")
	_collect_waypoints()
	_last_known_position = global_position
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").noise_emitted.connect(_on_noise)
	# Defer player lookup until the scene is fully ready
	call_deferred("_find_player")

func _find_player() -> void:
	var nodes := get_tree().get_nodes_in_group(player_group)
	if nodes.size() > 0:
		_player = nodes[0]

func _collect_waypoints() -> void:
	_waypoints.clear()
	if waypoints_path.is_empty():
		return
	var n := get_node_or_null(waypoints_path)
	if n == null:
		return
	for c in n.get_children():
		if c is Node3D:
			_waypoints.append(c)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_update_vision(delta)
	_suspicion = maxf(0.0, _suspicion - suspicion_decay * delta)
	_update_vision_indicator()

	match _state:
		State.PATROL:
			_tick_patrol(delta)
		State.SUSPICIOUS:
			_tick_move_to(_last_known_position, patrol_speed, delta, State.PATROL)
			_face_toward_player()
		State.ALERT:
			_tick_move_to(_last_known_position, alert_speed, delta, State.PATROL)
			_face_toward_player()
		State.DETECT:
			velocity.x = 0
			velocity.z = 0
			_face_toward_player()

	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.1:
		_distance_since_step += horizontal * delta
		if _distance_since_step >= step_distance:
			_distance_since_step = 0.0
			if _footstep_audio:
				_footstep_audio.pitch_scale = randf_range(0.92, 1.08)
				_footstep_audio.play()
			if has_node("/root/NoiseBus"):
				get_node("/root/NoiseBus").emit_noise(global_position, 0.4, self)

	move_and_slide()

func _tick_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		velocity.x = 0
		velocity.z = 0
		return
	var target := _waypoints[_waypoint_index].global_position
	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() < 0.25:
		velocity.x = 0
		velocity.z = 0
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_pause_timer = pause_at_waypoint
		return
	var dir := to_target.normalized()
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	_face_direction(dir)

func _tick_move_to(target: Vector3, speed: float, delta: float, on_arrive: int) -> void:
	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() < 0.6:
		velocity.x = 0
		velocity.z = 0
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_suspicion = 0.0
			_set_state(on_arrive)
			_pause_timer = pause_at_waypoint
		return
	var dir := to_target.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_direction(dir)

func _face_direction(dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.08)

func _face_toward_player() -> void:
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0
	if to_player.length() < 0.01:
		return
	_face_direction(to_player.normalized())

func _update_vision(delta: float) -> void:
	if _player == null:
		return
	if _player_is_cinematic_locked():
		_detect_timer = 0.0
		if _state != State.PATROL:
			_set_state(State.PATROL)
		return
	var origin: Vector3 = _vision_origin.global_position
	var to_player := _player.global_position - origin
	var distance := to_player.length()
	if distance > vision_range:
		_detect_timer = maxf(0.0, _detect_timer - delta * 2.0)
		return
	var forward: Vector3 = -_vision_origin.global_transform.basis.z
	var forward_h := Vector3(forward.x, 0, forward.z).normalized()
	var to_player_h := Vector3(to_player.x, 0, to_player.z).normalized()
	var dot := forward_h.dot(to_player_h)
	if dot < cos(deg_to_rad(vision_angle_deg)):
		_detect_timer = maxf(0.0, _detect_timer - delta * 2.0)
		return
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, _player.global_position + Vector3.UP * 0.4)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	if not hit.is_empty():
		var collider := hit.get("collider") as Node
		if collider != _player:
			_detect_timer = maxf(0.0, _detect_timer - delta * 2.0)
			return
	# Crouch/crawl reduces detection speed
	var stealth_mult := 1.0
	if _player.has_method("is_crawling") and _player.is_crawling():
		stealth_mult = 0.35
	elif _player.has_method("is_crouching") and _player.is_crouching():
		stealth_mult = 0.6
	var rate: float = 1.0 - clampf(distance / vision_range, 0.0, 0.95)
	_detect_timer += delta * (0.5 + rate) * stealth_mult
	_last_known_position = _player.global_position
	if _state == State.PATROL:
		_set_state(State.SUSPICIOUS)
		_pause_timer = 2.0
	if _detect_timer >= detect_seconds:
		_trigger_detect()

func _on_noise(noise_pos: Vector3, loudness: float, source: Node) -> void:
	if source == self:
		return
	if _player_is_cinematic_locked():
		return
	if _state == State.DETECT:
		return
	var distance := global_position.distance_to(noise_pos)
	var heard := loudness / maxf(1.0, distance * 0.5)
	if heard < noise_threshold_suspicious:
		return
	_last_known_position = noise_pos
	_suspicion += heard
	if heard >= noise_threshold_alert or _suspicion >= suspicion_to_alert:
		_set_state(State.ALERT)
		_pause_timer = 4.0
		if _alert_audio:
			_alert_audio.play()
	elif _state == State.PATROL:
		_set_state(State.SUSPICIOUS)
		_pause_timer = 2.0

func _trigger_detect() -> void:
	if _state == State.DETECT:
		return
	if _player_is_cinematic_locked():
		_detect_timer = 0.0
		return
	_set_state(State.DETECT)
	if _alert_audio:
		_alert_audio.play()
	if has_node("/root/GameEvents"):
		get_node("/root/GameEvents").fail("Ai fost descoperit.")

func _player_is_cinematic_locked() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_guard_detection_suppressed") and bool(_player.call("is_guard_detection_suppressed")):
		return true
	if _player.has_method("is_cinematic_active") and bool(_player.call("is_cinematic_active")):
		return true
	return false

func _set_state(s: int) -> void:
	if _state == s:
		return
	_state = s
	state_changed.emit(s)

func _update_vision_indicator() -> void:
	if _vision_indicator == null:
		return
	var mat := _vision_indicator.get_active_material(0)
	if mat == null:
		return
	var color := Color(0.85, 0.85, 0.6, 0.18)
	match _state:
		State.SUSPICIOUS:
			color = Color(1.0, 0.75, 0.3, 0.28)
		State.ALERT:
			color = Color(1.0, 0.45, 0.2, 0.38)
		State.DETECT:
			color = Color(1.0, 0.15, 0.1, 0.55)
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = color
