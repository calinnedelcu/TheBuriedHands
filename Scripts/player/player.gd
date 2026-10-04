class_name Player
extends CharacterBody3D
## First-person craftsman. The level is built at roughly 1.75x human scale,
## so heights and speeds below are tuned to that world, not to real metres.
##
## Owns movement, stances, the camera rig, health, breath and mercury
## toxicity, footstep noise and the light-based visibility used by guards.

signal stance_changed(stance: Stance)
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal toxicity_changed(value: float)
signal breath_changed(value: float, holding: bool)

enum Stance { STAND, CROUCH, CRAWL }

const FOOTSTEP_SURFACES := ["stone", "wood", "clay"]

@export_group("Movement")
@export var walk_speed := 3.3
@export var sprint_speed := 6.2
@export var crouch_speed := 1.8
@export var crawl_speed := 0.95
@export var ground_accel := 11.0
@export var ground_decel := 14.0
@export var air_control := 0.25
@export var jump_velocity := 6.2
@export var gravity_scale := 1.7
@export var max_step_height := 0.55

@export_group("Stances")
@export var stand_height := 2.9
@export var crouch_height := 1.75
@export var crawl_height := 0.95
@export var stand_eye := 2.65
@export var crouch_eye := 1.5
@export var crawl_eye := 0.62
@export var stance_speed := 9.0

@export_group("Look")
@export var base_mouse_sensitivity := 0.0022
@export var max_pitch_deg := 86.0
@export var bob_amount := 0.045
@export var bob_frequency := 1.65

@export_group("Health")
@export var max_health := 6.0
@export var invulnerability := 0.6
@export var regen_delay := 9.0
@export var regen_per_second := 0.12
## Health regenerates only up to this fraction of the maximum.
@export var regen_cap := 0.67

@export_group("Breath & toxicity")
@export var breath_capacity := 7.0
@export var breath_recovery := 1.4
@export var toxicity_decay := 1.5
## Mercury vapour intake is multiplied by this while the damp cloth is carried.
@export var cloth_protection := 0.45

@export_group("Noise (radius in metres)")
@export var noise_walk := 9.0
@export var noise_sprint := 18.0
@export var noise_crouch := 3.5
@export var noise_crawl := 1.6
@export var noise_land := 11.0
@export var step_distance := 2.1

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var collision: CollisionShape3D = $Collision
@onready var interactor: Interactor = $Head/Camera/Interactor
@onready var inventory: Inventory = $Inventory
@onready var viewmodel: Node3D = $Head/Camera/ViewModel
@onready var _footstep_player: AudioStreamPlayer = $FootstepAudio
@onready var _body_player: AudioStreamPlayer = $BodyAudio

var stance := Stance.STAND
var health := 6.0
var toxicity := 0.0
var breath := 7.0
var holding_breath := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _capsule: CapsuleShape3D
var _eye_height := 2.65
var _pitch := 0.0
var _bob_phase := 0.0
var _land_dip := 0.0
var _step_offset := 0.0
var _shake := 0.0
var _distance_since_step := 0.0
var _was_on_floor := true
var _last_damage_time := -100.0
var _vapor_intake := 0.0
var _locks: Dictionary = {}
var _look_locks: Dictionary = {}
var _ladder: Node3D = null
var _cinematic_tween: Tween
var _visibility_timer := 0.0
var _occlusion_cache: Dictionary = {}

var _footsteps: Dictionary = {}
var _jump_sounds: Array = []
var _land_sounds: Array = []
var _hurt_sounds: Array = []

func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"persistent")
	_capsule = (collision.shape as CapsuleShape3D).duplicate()
	collision.shape = _capsule
	health = max_health
	breath = breath_capacity
	_eye_height = stand_eye
	_apply_shape(stand_height)
	head.position.y = _eye_height
	camera.fov = float(Settings.get_value(&"fov"))
	Settings.changed.connect(_on_setting_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_load_sounds()
	health_changed.emit(health, max_health)

# --- Public API ---------------------------------------------------------------

## Blocks movement (and optionally look) until the matching unlock.
func lock_controls(reason: StringName, lock_look := true) -> void:
	_locks[reason] = true
	if lock_look:
		_look_locks[reason] = true

func unlock_controls(reason: StringName) -> void:
	_locks.erase(reason)
	_look_locks.erase(reason)

func controls_locked() -> bool:
	return not _locks.is_empty()

func is_crouching() -> bool:
	return stance == Stance.CROUCH

func is_crawling() -> bool:
	return stance == Stance.CRAWL

func is_sprinting() -> bool:
	return stance == Stance.STAND and is_on_floor() and _wants_sprint() and _horizontal_speed() > walk_speed * 0.8

func is_moving() -> bool:
	return _horizontal_speed() > 0.4

func chest_position() -> Vector3:
	return global_position + Vector3.UP * (_eye_height * 0.75)

func eye_position() -> Vector3:
	return camera.global_position

func has_lamp_lit() -> bool:
	var lamp := inventory.lamp()
	return lamp != null and lamp.is_lit

func apply_damage(amount: float, source: Node = null, death_reason := "DEATH_GENERIC") -> void:
	if Game.is_dead() or amount <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < invulnerability:
		return
	_last_damage_time = now
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit(amount, source)
	add_shake(0.35)
	_land_dip = maxf(_land_dip, 0.18)
	if not _hurt_sounds.is_empty():
		_body_player.stream = _hurt_sounds.pick_random()
		_body_player.pitch_scale = randf_range(0.9, 1.1)
		_body_player.play()
	if health <= 0.0:
		_die(death_reason)

func kill(death_reason: String) -> void:
	health = 0.0
	health_changed.emit(health, max_health)
	_die(death_reason)

## Mercury vapour exposure for this physics frame (0..1 intensity).
func add_vapor(intensity: float) -> void:
	_vapor_intake = maxf(_vapor_intake, intensity)

func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)

func force_stand() -> void:
	_set_stance(Stance.STAND, true)

## Smoothly turns the view toward `target`, optionally holding controls.
func look_at_point(target: Vector3, duration := 0.6, fov := -1.0) -> void:
	var to := target - camera.global_position
	if to.length_squared() < 0.0001:
		return
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var start_yaw := rotation.y
	var end_yaw := start_yaw + wrapf(yaw - start_yaw, -PI, PI)
	if _cinematic_tween != null:
		_cinematic_tween.kill()
	_cinematic_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.tween_property(self, "rotation:y", end_yaw, duration)
	_cinematic_tween.tween_method(_set_pitch, _pitch, clampf(pitch, -deg_to_rad(max_pitch_deg), deg_to_rad(max_pitch_deg)), duration)
	if fov > 0.0:
		_cinematic_tween.tween_property(camera, "fov", fov, duration)
	await _cinematic_tween.finished

func reset_fov(duration := 0.5) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "fov", float(Settings.get_value(&"fov")), duration)

func enter_ladder(ladder: Node3D) -> void:
	_ladder = ladder
	velocity = Vector3.ZERO
	_set_stance(Stance.STAND, true)

func exit_ladder(push := Vector3.ZERO) -> void:
	_ladder = null
	velocity = push

func on_ladder() -> bool:
	return _ladder != null

# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _look_locks.is_empty():
		var motion := (event as InputEventMouseMotion).screen_relative
		var sens := base_mouse_sensitivity * float(Settings.get_value(&"mouse_sensitivity")) * (camera.fov / 75.0)
		var invert := -1.0 if Settings.get_value(&"invert_y") else 1.0
		rotate_y(-motion.x * sens)
		_set_pitch(_pitch - motion.y * sens * invert)
		return
	if not _locks.is_empty():
		if event.is_action_pressed(&"skip_line") or (event.is_action_pressed(&"interact") and Dialogue.is_busy()):
			Dialogue.skip_line()
		return
	if event.is_action_pressed(&"skip_line"):
		Dialogue.skip_line()
	elif event.is_action_pressed(&"crouch"):
		if Settings.get_value(&"crouch_toggle"):
			_set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)
		else:
			_set_stance(Stance.CROUCH)
	elif event.is_action_released(&"crouch") and not Settings.get_value(&"crouch_toggle") and stance == Stance.CROUCH:
		_set_stance(Stance.STAND)
	elif event.is_action_pressed(&"crawl"):
		_set_stance(Stance.STAND if stance == Stance.CRAWL else Stance.CRAWL)
	elif event.is_action_pressed(&"jump") and _ladder != null:
		exit_ladder(-global_transform.basis.z * -3.0 + Vector3.UP * 2.0)

func _set_pitch(value: float) -> void:
	_pitch = clampf(value, -deg_to_rad(max_pitch_deg), deg_to_rad(max_pitch_deg))
	head.rotation.x = _pitch

# --- Simulation ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Game.is_dead():
		velocity = Vector3.ZERO
		return
	if _ladder != null:
		_ladder_move(delta)
	else:
		_move(delta)
	_update_stance_shape(delta)
	_update_camera(delta)
	_update_breath_and_toxicity(delta)
	_update_health(delta)
	_visibility_timer -= delta
	if _visibility_timer <= 0.0:
		_visibility_timer = 0.1
		_update_visibility()

func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= _gravity * gravity_scale * delta
		velocity.y = maxf(velocity.y, -40.0)
	var input := Vector2.ZERO
	if _locks.is_empty():
		input = Input.get_vector(&"move_left", "move_right", "move_forward", "move_backward")
		if Input.is_action_just_pressed(&"jump") and on_floor and stance == Stance.STAND:
			velocity.y = jump_velocity
			_play_jump()
			Stealth.make_noise(global_position, noise_walk * 0.8, self)
		elif Input.is_action_just_pressed(&"jump") and stance != Stance.STAND:
			_set_stance(Stance.STAND)
	var dir := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var target := dir * _target_speed()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ground_accel if dir != Vector3.ZERO else ground_decel
	if not on_floor:
		rate *= air_control
	horizontal = horizontal.lerp(target, clampf(rate * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var fall_speed := -velocity.y
	var pre_move_position := global_position
	move_and_slide()
	if on_floor and is_on_wall() and dir != Vector3.ZERO:
		_try_step_up(pre_move_position, dir, delta)
	if is_on_floor() and not _was_on_floor and fall_speed > 2.0:
		_on_landed(fall_speed)
	_was_on_floor = is_on_floor()
	_update_footsteps(delta)

func _target_speed() -> float:
	match stance:
		Stance.CRAWL:
			return crawl_speed
		Stance.CROUCH:
			return crouch_speed
	if _wants_sprint():
		return sprint_speed
	return walk_speed

func _wants_sprint() -> bool:
	return _locks.is_empty() and Input.is_action_pressed(&"sprint") and Input.is_action_pressed(&"move_forward")

## Climbs small ledges (stairs, thresholds) the capsule would otherwise stop
## at: probe up, forward and back down for a walkable top, then lift the body
## onto it. The camera eases up afterwards instead of popping.
func _try_step_up(from: Vector3, dir: Vector3, _delta: float) -> void:
	var up := Vector3.UP * max_step_height
	var probe_forward := dir * (_capsule.radius + 0.12)
	var xform := Transform3D(global_basis, from)
	if test_move(xform, up):
		return
	xform.origin += up
	if test_move(xform, probe_forward):
		return
	xform.origin += probe_forward
	var hit := KinematicCollision3D.new()
	if not test_move(xform, -up - Vector3.UP * 0.05, hit) or hit.get_normal().y < 0.7:
		return
	var rise := (xform.origin + hit.get_travel()).y - from.y
	if rise < 0.04 or rise > max_step_height:
		return
	global_position = Vector3(global_position.x, from.y + rise + 0.01, global_position.z)
	velocity.y = 0.0
	_step_offset += rise

func _ladder_move(delta: float) -> void:
	var input := Input.get_axis(&"move_backward", &"move_forward") if _locks.is_empty() else 0.0
	# Looking down while pressing forward climbs down, like most FPS ladders.
	if _pitch < -deg_to_rad(35.0):
		input = -input
	velocity = Vector3.UP * input * 2.6
	move_and_slide()
	if _ladder.has_method("climber_moved"):
		_ladder.call("climber_moved", self)
	_distance_since_step += absf(input) * 2.6 * delta
	if _distance_since_step > 1.1:
		_distance_since_step = 0.0
		_play_footstep("wood", 0.7)

func _set_stance(target: Stance, force := false) -> void:
	if target == stance:
		return
	var target_height := _height_for(target)
	if not force and target_height > _capsule.height + _capsule.radius * 0.1 and _ceiling_blocks(target_height):
		return
	stance = target
	stance_changed.emit(stance)

func _height_for(s: Stance) -> float:
	match s:
		Stance.CROUCH:
			return crouch_height
		Stance.CRAWL:
			return crawl_height
	return stand_height

func _eye_for(s: Stance) -> float:
	match s:
		Stance.CROUCH:
			return crouch_eye
		Stance.CRAWL:
			return crawl_eye
	return stand_eye

## True if standing up to `height` would hit something. Uses rays: shape
## overlap queries do not report trimesh level geometry under Jolt.
func _ceiling_blocks(height: float) -> bool:
	var space := get_world_3d().direct_space_state
	var top := global_position.y + height + 0.05
	var start := global_position.y + _capsule.height - 0.05
	var r := _capsule.radius * 0.75
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	for offset in offsets:
		var a: Vector3 = Vector3(global_position.x, start, global_position.z) + offset
		var b := Vector3(a.x, top, a.z)
		var params := PhysicsRayQueryParameters3D.create(a, b, collision_mask)
		params.exclude = [get_rid()]
		params.hit_back_faces = true
		if not space.intersect_ray(params).is_empty():
			return true
	return false

func _update_stance_shape(delta: float) -> void:
	var target_h := _height_for(stance)
	if not is_equal_approx(_capsule.height, target_h):
		var h := move_toward(_capsule.height, target_h, delta * stance_speed * 1.2)
		_apply_shape(h)
	_eye_height = lerpf(_eye_height, _eye_for(stance), clampf(delta * stance_speed, 0.0, 1.0))

func _apply_shape(height: float) -> void:
	_capsule.radius = minf(0.42, height * 0.5)
	_capsule.height = height
	# Keep the feet on the ground: the body origin is at the feet.
	collision.position.y = height * 0.5

func _update_camera(delta: float) -> void:
	var speed := _horizontal_speed()
	var bob_scale := float(Settings.get_value(&"head_bob"))
	var bob := Vector3.ZERO
	if is_on_floor() and speed > 0.3 and _ladder == null:
		_bob_phase += delta * bob_frequency * (speed / walk_speed) * TAU * 0.5
		var amp := bob_amount * bob_scale * clampf(speed / walk_speed, 0.4, 1.6)
		if stance == Stance.CRAWL:
			amp *= 0.5
		bob = Vector3(cos(_bob_phase) * amp * 0.5, absf(sin(_bob_phase)) * amp, 0.0)
	else:
		_bob_phase = 0.0
	_land_dip = lerpf(_land_dip, 0.0, clampf(delta * 7.0, 0.0, 1.0))
	_step_offset = lerpf(_step_offset, 0.0, clampf(delta * 12.0, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 1.2)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * _shake * 0.12
	head.position = Vector3(0.0, _eye_height - _land_dip - _step_offset, 0.0) + bob + shake
	# A slight FOV push while sprinting sells the speed without nausea.
	if _cinematic_tween == null or not _cinematic_tween.is_running():
		var base_fov := float(Settings.get_value(&"fov"))
		var target_fov := base_fov + (4.0 if is_sprinting() else 0.0)
		camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 5.0, 0.0, 1.0))

func _on_landed(fall_speed: float) -> void:
	var impact := clampf((fall_speed - 2.0) / 12.0, 0.0, 1.0)
	_land_dip = maxf(_land_dip, 0.06 + impact * 0.22)
	Stealth.make_noise(global_position, noise_land * (0.5 + impact), self)
	_play_land(impact)
	if fall_speed > 17.0:
		apply_damage((fall_speed - 17.0) * 0.6, null, "DEATH_FALL")

func _horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

# --- Footsteps & noise ------------------------------------------------------------

func _update_footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var speed := _horizontal_speed()
	if speed < 0.3:
		_distance_since_step = step_distance * 0.6
		return
	_distance_since_step += speed * delta
	var stride := step_distance * (0.75 if is_sprinting() else 1.0) * (0.7 if stance == Stance.CRAWL else 1.0)
	if _distance_since_step < stride:
		return
	_distance_since_step = 0.0
	var surface := _surface_under()
	var radius := noise_walk
	var volume := 0.0
	match stance:
		Stance.CRAWL:
			radius = noise_crawl
			volume = -12.0
		Stance.CROUCH:
			radius = noise_crouch
			volume = -8.0
		_:
			if is_sprinting():
				radius = noise_sprint
				volume = 3.0
	radius *= {"wood": 1.25, "clay": 0.8}.get(surface, 1.0)
	Stealth.make_noise(global_position, radius, self)
	_play_footstep(surface, db_to_linear(volume))

func _surface_under() -> String:
	var params := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.6, collision_mask)
	params.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return "stone"
	var node := hit.collider as Node
	while node != null:
		if node.has_meta(&"surface"):
			return String(node.get_meta(&"surface"))
		node = node.get_parent()
	return "stone"

# --- Breath, toxicity, health ----------------------------------------------------------

func _update_breath_and_toxicity(delta: float) -> void:
	var want_hold := _locks.is_empty() and Input.is_action_pressed(&"hold_breath")
	if want_hold and breath > 0.0:
		holding_breath = true
		breath = maxf(0.0, breath - delta)
		if breath <= 0.0:
			# Ran out: a loud gasp that also takes in a full lungful of whatever is around.
			holding_breath = false
			Stealth.make_noise(global_position, noise_walk, self)
			toxicity = minf(100.0, toxicity + _vapor_intake * 12.0)
	else:
		holding_breath = false
		breath = minf(breath_capacity, breath + breath_recovery * delta)
	breath_changed.emit(breath / breath_capacity, holding_breath)
	var intake := 0.0
	if _vapor_intake > 0.0 and not holding_breath:
		intake = _vapor_intake * 9.0 * (cloth_protection if inventory.has_item(&"cloth") else 1.0)
	_vapor_intake = 0.0
	var before := toxicity
	if intake > 0.0:
		toxicity = minf(100.0, toxicity + intake * delta)
	else:
		toxicity = maxf(0.0, toxicity - toxicity_decay * delta)
	if not is_equal_approx(before, toxicity):
		toxicity_changed.emit(toxicity)
	if toxicity >= 100.0:
		kill("DEATH_MERCURY")

func _update_health(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if health < max_health * regen_cap and now - _last_damage_time > regen_delay:
		health = minf(max_health * regen_cap, health + regen_per_second * delta)
		health_changed.emit(health, max_health)

func _die(reason: String) -> void:
	lock_controls(&"death")
	velocity = Vector3.ZERO
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(head, "position:y", 0.35, 1.1)
	tween.tween_property(head, "rotation:z", deg_to_rad(28.0), 1.1)
	Game.fail(reason)

# --- Visibility (light gem) ----------------------------------------------------------

func _update_visibility() -> void:
	var chest := chest_position()
	var light := 0.0
	var lamp := inventory.lamp()
	if lamp != null and lamp.is_lit:
		light += 0.55 + (0.3 if lamp.is_raised else 0.0)
	for l in Stealth.lights():
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy <= 0.05:
			continue
		var reach: float = l.get(&"omni_range") if l is OmniLight3D else l.get(&"spot_range")
		var d := l.global_position.distance_to(chest)
		if d >= reach:
			continue
		var contribution := pow(1.0 - d / reach, 2.0) * clampf(l.light_energy / 3.0, 0.0, 1.5)
		if contribution < 0.03 or _light_occluded(l, chest):
			continue
		light += contribution
	var visibility := clampf(light, 0.0, 1.0)
	var stance_factor: float = {Stance.STAND: 1.0, Stance.CROUCH: 0.62, Stance.CRAWL: 0.38}[stance]
	var motion_factor := 1.0 + (0.45 if is_sprinting() else (0.15 if is_moving() else 0.0))
	Stealth.player_visibility = visibility
	Stealth.player_exposure = clampf(visibility * stance_factor * motion_factor, 0.0, 1.0)

func _light_occluded(l: Light3D, chest: Vector3) -> bool:
	# Raycasts are cached per light for a few updates; lights rarely move.
	var key := l.get_instance_id()
	var cached: Array = _occlusion_cache.get(key, [])
	var now := Time.get_ticks_msec()
	if not cached.is_empty() and now - int(cached[0]) < 300 and chest.distance_to(cached[2]) < 0.6:
		return cached[1]
	var params := PhysicsRayQueryParameters3D.create(l.global_position, chest, 1)
	params.exclude = [get_rid()]
	var blocked := not get_world_3d().direct_space_state.intersect_ray(params).is_empty()
	_occlusion_cache[key] = [now, blocked, chest]
	return blocked

# --- Audio ------------------------------------------------------------------------------

func _load_sounds() -> void:
	for surface in FOOTSTEP_SURFACES:
		_footsteps[surface] = _load_dir("res://audio/sfx/player/footsteps/" + surface)
	if _footsteps["stone"].is_empty():
		_footsteps["stone"] = _load_dir("res://audio/sfx/player/footsteps")
	for surface in FOOTSTEP_SURFACES:
		if _footsteps[surface].is_empty():
			_footsteps[surface] = _footsteps["stone"]
	_jump_sounds = _load_dir("res://audio/sfx/player/jump")
	_land_sounds = _load_dir("res://audio/sfx/player/land")
	_hurt_sounds = _load_dir("res://audio/sfx/player/hurt")

## Loads every audio stream in a folder. Uses ResourceLoader.list_directory so
## it also works in exported builds, where the raw files are remapped.
func _load_dir(path: String) -> Array:
	var out: Array = []
	for file in ResourceLoader.list_directory(path):
		if file.ends_with("/"):
			continue
		var res := load(path.path_join(file))
		if res is AudioStream:
			out.append(res)
	return out

func _play_footstep(surface: String, volume_linear := 1.0) -> void:
	var options: Array = _footsteps.get(surface, [])
	if options.is_empty():
		return
	_footstep_player.stream = options.pick_random()
	_footstep_player.volume_db = -10.0 + linear_to_db(volume_linear)
	_footstep_player.pitch_scale = randf_range(0.92, 1.08)
	_footstep_player.play()

func _play_jump() -> void:
	if not _jump_sounds.is_empty():
		_body_player.stream = _jump_sounds.pick_random()
		_body_player.pitch_scale = randf_range(0.95, 1.05)
		_body_player.play()

func _play_land(impact: float) -> void:
	if not _land_sounds.is_empty():
		_footstep_player.stream = _land_sounds.pick_random()
		_footstep_player.volume_db = -12.0 + impact * 8.0
		_footstep_player.play()

# --- Settings & persistence ----------------------------------------------------------------

func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"fov":
		camera.fov = float(value)

func persist_save() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": _pitch,
		"health": health,
	}

func persist_load(data: Dictionary) -> void:
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(data.get("yaw", rotation.y))
	_set_pitch(float(data.get("pitch", 0.0)))
	health = maxf(float(data.get("health", max_health)), max_health * 0.5)
	health_changed.emit(health, max_health)
