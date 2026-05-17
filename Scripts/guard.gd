class_name Guard
extends CharacterBody3D

signal state_changed(state: int)

enum State { PATROL, SUSPICIOUS, ALERT, DETECT }

@export var waypoints_path: NodePath
@export var patrol_speed: float = 1.2
@export var alert_speed: float = 3.0
@export var vision_range: float = 14.0
@export var vision_angle_deg: float = 65.0
@export var detect_seconds: float = 0.45
@export var pause_at_waypoint: float = 1.5
@export var suspicion_decay: float = 0.35
@export var suspicion_to_alert: float = 0.7
@export var noise_threshold_suspicious: float = 0.45
@export var noise_threshold_alert: float = 1.0
## Cat de tare trebuie sa fie un zgomot ca sa rupa gardianul din CHASE.
## Cu impact_noise=4.5 al uneltelor: 0.9 ≈ raza 10m, 0.6 ≈ 15m.
@export var noise_threshold_chase_break: float = 0.9
@export var step_distance: float = 1.4
@export var player_group: String = "player"

@export_group("Attack")
@export var attack_range: float = 1.6
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.0
@export var lose_sight_seconds: float = 4.0
@export var debug_attacks: bool = false
## Daca e true: gardianul nu te vede, nu te aude, nu te urmareste — doar patruleaza.
@export var peaceful_patrol: bool = false

@export_group("Animations")
@export var walk_animation: StringName = &""
@export var idle_animation: StringName = &""
@export var chase_animation: StringName = &"NlaTrack_Armature_001"
@export var chase_animation_speed: float = 1.35
@export var animation_walk_threshold: float = 0.15

@export_group("Audio")
@export var danger_stream: AudioStream
@export var danger_volume_db: float = -2.0
@export var danger_bus: StringName = &"SFX"

@onready var _vision_origin: Node3D = (get_node_or_null("VisionOrigin") as Node3D) if has_node("VisionOrigin") else self
@onready var _footstep_audio: AudioStreamPlayer3D = get_node_or_null("FootstepAudio")
@onready var _alert_audio: AudioStreamPlayer3D = get_node_or_null("AlertAudio")
@warning_ignore("unused_private_class_variable")
@onready var _ambient_audio: AudioStreamPlayer3D = get_node_or_null("AmbientAudio")
@onready var _danger_audio: AudioStreamPlayer3D = get_node_or_null("DangerAudio")
@onready var _vision_indicator: MeshInstance3D = get_node_or_null("VisionOrigin/VisionIndicator")
@onready var _animation_player: AnimationPlayer = _find_animation_player(self)

var _waypoints: Array[Node3D] = []
var _waypoint_index: int = 0
var _state: int = State.PATROL
var _pause_timer: float = 0.0
var _suspicion: float = 0.0
var _last_known_position: Vector3
var _player: Node3D = null
var _detect_timer: float = 0.0
var _distance_since_step: float = 0.0
var _current_animation: StringName = &""
var _attack_cooldown_timer: float = 0.0
var _lost_sight_timer: float = 0.0
var _debug_vision_cooldown: float = 0.0
var _debug_last_reason: String = ""
var _stuck_timer: float = 0.0
var _last_patrol_position: Vector3 = Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("guards")
	_collect_waypoints()
	_last_known_position = global_position
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").noise_emitted.connect(_on_noise)
	call_deferred("_find_player")
	_setup_danger_audio()
	if debug_attacks:
		print("[guard %s] READY at %s waypoints=%d" % [name, global_position, _waypoints.size()])

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
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
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
			_tick_chase(delta)

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

	_update_animation(horizontal)
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
			_advance_waypoint()
		return
	# Detectie de stuck: daca a stat practic pe loc 2s incercand sa mearga,
	# trece la urmatorul waypoint ca sa nu ramana blocat intr-un perete.
	var moved := global_position.distance_to(_last_patrol_position)
	if moved < 0.05:
		_stuck_timer += delta
		if _stuck_timer >= 2.0:
			_advance_waypoint()
			_stuck_timer = 0.0
			return
	else:
		_stuck_timer = 0.0
	_last_patrol_position = global_position
	var dir := to_target.normalized()
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	_face_direction(dir)

func _advance_waypoint() -> void:
	_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
	_pause_timer = pause_at_waypoint

func _tick_chase(delta: float) -> void:
	if _player == null or _player_is_cinematic_locked() or peaceful_patrol:
		_set_state(State.PATROL)
		velocity.x = 0
		velocity.z = 0
		return
	# Daca avem line-of-sight, actualizam ultima pozitie cunoscuta si resetam timer-ul.
	if _can_see_player_now():
		_last_known_position = _player.global_position
		_lost_sight_timer = 0.0
	else:
		_lost_sight_timer += delta
		if _lost_sight_timer >= lose_sight_seconds:
			# A pierdut urma — degradeaza la ALERT si merge la ultima pozitie cunoscuta.
			_set_state(State.ALERT)
			_pause_timer = 3.0
			_lost_sight_timer = 0.0
			return
	var to_target := _last_known_position - global_position
	to_target.y = 0
	var dist := to_target.length()
	if dist <= attack_range:
		velocity.x = 0
		velocity.z = 0
		_face_toward_player()
		_try_attack_player()
		return
	var dir := to_target.normalized()
	velocity.x = dir.x * alert_speed
	velocity.z = dir.z * alert_speed
	_face_direction(dir)

func _can_see_player_now() -> bool:
	if _player == null:
		return false
	var origin: Vector3 = _vision_origin.global_position
	var to_player := _player.global_position - origin
	if to_player.length() > vision_range * 1.6:
		return false
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, _player.global_position + Vector3.UP * 0.4)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return true
	return hit.get("collider") == _player

func _try_attack_player() -> void:
	if _attack_cooldown_timer > 0.0 or _player == null:
		return
	if not _player.has_method("apply_damage"):
		if debug_attacks:
			print("[guard %s] in range but player has NO apply_damage method (script cache stale? restart editor)" % name)
		return
	_attack_cooldown_timer = attack_cooldown
	if debug_attacks:
		print("[guard %s] ATTACK player dmg=%d" % [name, attack_damage])
	_player.call("apply_damage", attack_damage, self)
	if _alert_audio:
		_alert_audio.pitch_scale = randf_range(0.92, 1.05)
		_alert_audio.play()

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
	_debug_vision_cooldown = maxf(0.0, _debug_vision_cooldown - delta)
	if _player == null:
		_vision_debug("no_player")
		return
	# Pacifist: nu detecteaza vizual, dar lasam state-ul sa-l influenteze zgomotul.
	if peaceful_patrol:
		_detect_timer = 0.0
		_vision_debug("peaceful")
		return
	if _player_is_cinematic_locked():
		_detect_timer = 0.0
		if _state != State.PATROL:
			_set_state(State.PATROL)
		_vision_debug("cinematic_locked")
		return
	var origin: Vector3 = _vision_origin.global_position
	var to_player := _player.global_position - origin
	var distance := to_player.length()
	if distance > vision_range:
		_detect_timer = maxf(0.0, _detect_timer - delta * 2.0)
		_vision_debug("out_of_range dist=%.1f" % distance)
		return
	# `_face_direction` foloseste atan2(dir.x, dir.z) deci basis.z = dir (forward = +Z, nu -Z).
	var forward: Vector3 = _vision_origin.global_transform.basis.z
	var forward_h := Vector3(forward.x, 0, forward.z).normalized()
	var to_player_h := Vector3(to_player.x, 0, to_player.z).normalized()
	var dot := forward_h.dot(to_player_h)
	if dot < cos(deg_to_rad(vision_angle_deg)):
		_detect_timer = maxf(0.0, _detect_timer - delta * 2.0)
		_vision_debug("out_of_cone dot=%.2f need=%.2f" % [dot, cos(deg_to_rad(vision_angle_deg))])
		return
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, _player.global_position + Vector3.UP * 0.4)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	if not hit.is_empty():
		var collider := hit.get("collider") as Node
		if collider != _player:
			_detect_timer = maxf(0.0, _detect_timer - delta * 2.0)
			var col_name: String = String(collider.name) if collider != null else "null"
			_vision_debug("ray_blocked_by=%s dist=%.1f" % [col_name, distance])
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
	_vision_debug("SEEING player dist=%.1f detect=%.2f/%.2f" % [distance, _detect_timer, detect_seconds])
	if _state == State.PATROL:
		_set_state(State.SUSPICIOUS)
		_pause_timer = 2.0
	if _detect_timer >= detect_seconds:
		_trigger_detect()

func _vision_debug(reason: String) -> void:
	if not debug_attacks:
		return
	# Logam doar cand motivul s-a schimbat sau o data la 0.5s
	if reason == _debug_last_reason and _debug_vision_cooldown > 0.0:
		return
	_debug_last_reason = reason
	_debug_vision_cooldown = 0.5
	print("[guard %s] vision: %s" % [name, reason])

func _on_noise(noise_pos: Vector3, loudness: float, source: Node) -> void:
	if source == self:
		return
	# Pacifist: aude zgomotele si se duce sa investigheze (SUSPICIOUS), dar
	# niciodata nu intra in ALERT/CHASE. Iesim cu un comportament redus mai jos.
	if peaceful_patrol:
		_on_noise_peaceful(noise_pos, loudness)
		return
	if _player_is_cinematic_locked():
		return
	var distance := global_position.distance_to(noise_pos)
	var heard := loudness / maxf(1.0, distance * 0.5)
	if heard < noise_threshold_suspicious:
		return
	# Zgomotul cu sursa identificata ca player (footsteps) nu trebuie sa il rupa
	# din chase — doar zgomotele venite de la alte obiecte (cioburi aruncate) au
	# voie sa-l distraga.
	var source_is_player := source != null and source == _player
	if _state == State.DETECT:
		if source_is_player:
			return
		# Folosim un prag dedicat pentru distragere — calibrat pentru raza ~10m
		# cu impact_noise=4.5 al uneltelor aruncate.
		if heard < noise_threshold_chase_break:
			return
		# Distragere reusita: paraseste chase-ul si pleaca spre zgomot.
		_last_known_position = noise_pos
		_detect_timer = 0.0
		_set_state(State.ALERT)
		_pause_timer = 4.0
		if _alert_audio:
			_alert_audio.play()
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

func _on_noise_peaceful(noise_pos: Vector3, loudness: float) -> void:
	pass

func _trigger_detect() -> void:
	if _state == State.DETECT:
		return
	if _player_is_cinematic_locked():
		_detect_timer = 0.0
		return
	_set_state(State.DETECT)
	_lost_sight_timer = 0.0
	if debug_attacks:
		print("[guard %s] DETECT → entering chase" % name)
	if _alert_audio:
		_alert_audio.play()

func _player_is_cinematic_locked() -> bool:
	# Lock global (conversatie nestiintita / cinematic activ). Pacifistii NU sunt
	# inclusi aici — ei ignora vederea/atacul, dar pot fi distrasi de zgomot.
	if has_node("/root/GameEvents"):
		var events := get_node("/root/GameEvents")
		if "guards_alerted" in events and not bool(events.guards_alerted):
			return true
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
	if debug_attacks:
		var names := ["PATROL", "SUSPICIOUS", "ALERT", "DETECT"]
		print("[guard %s] state %s → %s" % [name, names[_state], names[s]])
	var was_detect := _state == State.DETECT
	_state = s
	state_changed.emit(s)
	if not was_detect and s == State.DETECT:
		_play_danger_audio()
	elif was_detect and s != State.DETECT:
		_stop_danger_audio()

func _setup_danger_audio() -> void:
	if _danger_audio == null:
		print("[guard %s] _setup_danger_audio: DangerAudio node missing" % name)
		return
	if danger_stream != null:
		_danger_audio.stream = danger_stream
		print("[guard %s] danger stream from inspector, bus=%s vol=%s" % [name, _danger_audio.bus, _danger_audio.volume_db])
		return
	if _danger_audio.stream == null:
		_danger_audio.stream = _load_wav_skip_import("res://audio/sfx/GuardianDanger.wav")
	if _danger_audio.stream != null:
		_danger_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		print("[guard %s] danger stream loaded: %s" % [name, _danger_audio.stream])
	else:
		print("[guard %s] danger stream FAILED to load" % name)
	_danger_audio.volume_db = danger_volume_db
	_danger_audio.bus = danger_bus

func _load_wav_skip_import(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		push_warning("[guard] danger wav not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[guard] cannot open danger wav: %s" % path)
		return null
	var riff := file.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF":
		push_warning("[guard] not a valid WAV: %s" % path)
		return null
	file.get_32() # file size - 8, skip
	var wave := file.get_buffer(4).get_string_from_ascii()
	if wave != "WAVE":
		push_warning("[guard] missing WAVE marker in: %s" % path)
		return null
	# Parse chunks to find fmt and data
	var fmt_found := false
	var data_found := false
	var format_tag := 0
	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var data_bytes: PackedByteArray
	while file.get_position() < file.get_length():
		var chunk_id := file.get_buffer(4).get_string_from_ascii()
		var chunk_size := file.get_32()
		if chunk_id == "fmt ":
			format_tag = file.get_16()
			channels = file.get_16()
			sample_rate = file.get_32()
			file.get_32() # byte rate
			file.get_16() # block align
			bits_per_sample = file.get_16()
			# Skip any extra fmt bytes
			var fmt_read := 16
			if chunk_size > fmt_read:
				file.get_buffer(chunk_size - fmt_read)
			fmt_found = true
		elif chunk_id == "data":
			data_bytes = file.get_buffer(chunk_size)
			data_found = true
		else:
			file.get_buffer(chunk_size)
		if fmt_found and data_found:
			break
	if not fmt_found or not data_found:
		push_warning("[guard] WAV missing fmt/data chunks: %s" % path)
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.data = data_bytes
	return stream

func _play_danger_audio() -> void:
	print("[guard %s] _play_danger_audio called, audio=%s stream=%s playing=%s" % [
		name,
		_danger_audio,
		_danger_audio.stream if _danger_audio else null,
		_danger_audio.playing if _danger_audio else "n/a"
	])
	if _danger_audio == null or _danger_audio.stream == null:
		print("[guard %s] _play_danger_audio: skipped (null audio or stream)" % name)
		return
	if not _danger_audio.playing:
		_danger_audio.play()
		print("[guard %s] _play_danger_audio: play() called, now playing=%s" % [name, _danger_audio.playing])

func _stop_danger_audio() -> void:
	if _danger_audio == null:
		return
	_danger_audio.stop()

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

func _update_animation(horizontal_speed: float) -> void:
	if _animation_player == null:
		return
	var target: StringName
	var speed: float = 1.0
	if _state == State.DETECT and chase_animation != &"":
		target = chase_animation
		speed = chase_animation_speed
	elif horizontal_speed > animation_walk_threshold:
		target = walk_animation
	else:
		target = idle_animation
	if target == &"":
		return
	if not _animation_player.has_animation(target):
		return
	_animation_player.speed_scale = speed
	if _current_animation == target:
		return
	var anim := _animation_player.get_animation(target)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(target)
	_current_animation = target

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
