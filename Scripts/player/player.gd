class_name Player
extends CharacterBody3D
## First-person craftsman. The level is built at roughly 1.75x human scale,
## so heights and speeds below are tuned to that world, not to real metres.
##
## Owns movement, stances, the camera rig, health, breath and mercury
## toxicity, footstep noise and the light-based visibility used by guards.
##
## Co-op: the same scene is the master (the level's "Player") and his
## apprentice ("Apprentice", smaller, quicker, lighter on his feet). The body
## played on this machine is local; the other is a puppet that follows the
## network, wears its character's model and passes what happens to it (a
## guard's blow, the story turning its head) on to its owner's machine.

signal stance_changed(stance: Stance)
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal toxicity_changed(value: float)
signal breath_changed(value: float, holding: bool)

enum Stance { STAND, CROUCH, CRAWL }

const FOOTSTEP_SURFACES := ["stone", "wood", "clay"]
## The characters as the other player sees them (tools/blender builds both).
const PUPPET_MODELS := {
	&"master": ["res://assets/models/characters/craftsman.glb", 3.1],
	&"apprentice": ["res://assets/models/characters/apprentice.glb", 2.75],
}
## Clips for each pose, best first (the first one the model has is played).
const PUPPET_CLIPS := {
	&"idle": [&"idle", &"hands_on_hips"],
	&"walk": [&"walk"],
	&"run": [&"run", &"walk"],
	&"crouch": [&"crouch_idle", &"kneel", &"cower"],
	&"crouch_walk": [&"crouch_walk", &"walk"],
	&"crawl": [&"crawl", &"crouch_walk", &"walk"],
	&"crawl_idle": [&"crawl_idle", &"crouch_idle", &"kneel", &"cower"],
	&"climb": [&"climb", &"walk"],
	&"down": [&"downed", &"collapse", &"cower"],
}

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
var _auto_ducked := false
var _duck_clear := 0.0
var _cinematic_tween: Tween
var _walk_target := Vector3.INF
var _walk_speed := 0.0
var _visibility_timer := 0.0
var _occlusion_cache: Dictionary = {}

var _footsteps: Dictionary = {}
var _jump_sounds: Array = []
var _land_sounds: Array = []
var _hurt_sounds: Array = []

## Co-op: &"master" or &"apprentice" (from the body's name).
var role: StringName = &"master"
## Played on this machine (always, alone).
var is_local := true
## How exposed this body is to guards: light on it, stance, movement (0..1).
var exposure := 0.0

var _net_seen := false
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_vel := Vector3.ZERO
var _net_bits := 0
var _puppet_model: Node3D
var _puppet_anim: AnimationPlayer
var _puppet_clip: StringName = &""
var _puppet_steps: AudioStreamPlayer3D
var _puppet_step_distance := 0.0
var _puppet_tag: Label3D
var _held_socket: Node3D
var _held_visual: Node3D
var _held_id: StringName = &""
var _use_body: StaticBody3D
var _use_usable: DelegateUsable
var _inventory_dirty := false
var _talking := false

## Co-op: knocked down rather than killed. The partner can help you up before
## you bleed out; if you both go down, it's over.
var downed := false
const BLEED_OUT_SECONDS := 40.0
const REVIVE_HOLD := 2.4
var _bleed := 0.0
var _down_reason := ""
var _notice_second := -1
## Co-op: what this player is holding in place (a wedge in a crack, the brake
## by the counterweight); rooted there until they let go.
var bracing: Node = null
var _heavy_told := false

func _ready() -> void:
	role = &"apprentice" if name == Net.APPRENTICE_BODY else &"master"
	is_local = Net.is_local_body(self)
	add_to_group(&"players")
	add_to_group(&"persistent")
	if role == &"apprentice":
		_apprentice_build()
	_capsule = (collision.shape as CapsuleShape3D).duplicate()
	collision.shape = _capsule
	health = max_health
	breath = breath_capacity
	_eye_height = stand_eye
	_apply_shape(stand_height)
	head.position.y = _eye_height
	camera.fov = float(Settings.get_value(&"fov"))
	_load_sounds()
	_build_use_body()
	if not is_local:
		_become_puppet()
		return
	add_to_group(&"player")
	camera.make_current()
	Settings.changed.connect(_on_setting_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	inventory.changed.connect(_on_inventory_changed)
	health_changed.emit(health, max_health)

## The apprentice: a head shorter, quicker, and lighter on his feet; he takes
## a beating less well.
func _apprentice_build() -> void:
	stand_height = 2.55
	stand_eye = 2.3
	crouch_height = 1.55
	crouch_eye = 1.32
	walk_speed = 3.6
	sprint_speed = 6.7
	crouch_speed = 2.05
	crawl_speed = 1.1
	for key in [&"noise_walk", &"noise_sprint", &"noise_crouch", &"noise_crawl", &"noise_land"]:
		set(key, float(get(key)) * 0.7)
	max_health = 5.0

# --- Public API ---------------------------------------------------------------

## Blocks movement (and optionally look) until the matching unlock.
func lock_controls(reason: StringName, lock_look := true) -> void:
	if _for_owner(&"lock_controls", [reason, lock_look]):
		return
	_locks[reason] = true
	if lock_look:
		_look_locks[reason] = true

func unlock_controls(reason: StringName) -> void:
	if _for_owner(&"unlock_controls", [reason]):
		return
	_locks.erase(reason)
	_look_locks.erase(reason)

func controls_locked() -> bool:
	return not _locks.is_empty()

func is_crouching() -> bool:
	return stance == Stance.CROUCH

func is_crawling() -> bool:
	return stance == Stance.CRAWL

func is_sprinting() -> bool:
	if not is_local:
		return _net_bits & 4 != 0
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
	if _for_owner(&"hurt", [amount, death_reason]):
		return
	if Game.is_dead() or amount <= 0.0 or downed:
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
		# Co-op: a blow knocks you down; your partner can still help you up.
		if Net.active:
			_go_down(death_reason)
		else:
			_die(death_reason)

## A line at the top of this player's screen (co-op: the host's story may
## have something to tell the apprentice).
func notice(text_key: String) -> void:
	if _for_owner(&"notice", [text_key]):
		return
	Net.show_notice(InputHint.format(tr(text_key)), 4.0)

## A blow that landed on this body on the host's machine (co-op).
func hurt(amount: float, death_reason: String) -> void:
	apply_damage(amount, null, death_reason)

## A shove (a guard's thrust): added to the body's velocity.
func push(impulse: Vector3) -> void:
	if _for_owner(&"push", [impulse]):
		return
	velocity += impulse

func kill(death_reason: String) -> void:
	if _for_owner(&"kill", [death_reason]):
		return
	health = 0.0
	health_changed.emit(health, max_health)
	_die(death_reason)

## Mercury vapour exposure for this physics frame (0..1 intensity).
func add_vapor(intensity: float) -> void:
	if is_local:
		_vapor_intake = maxf(_vapor_intake, intensity)

func add_shake(amount: float) -> void:
	if _for_owner(&"add_shake", [amount]):
		return
	_shake = clampf(_shake + amount, 0.0, 1.0)

func force_stand() -> void:
	if _for_owner(&"force_stand"):
		return
	_set_stance(Stance.STAND, true)

## Smoothly turns the view toward `target`, optionally holding controls.
func look_at_point(target: Vector3, duration := 0.6, fov := -1.0) -> void:
	if _for_owner(&"look_at_point", [target, duration, fov]):
		return
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

## Walks the body to `target` on its own (for cutscenes, with the controls
## locked), at `speed` m/s; the view stays wherever it is turned.
func walk_to(target: Vector3, speed := 1.2) -> void:
	if _for_owner(&"walk_to", [target, speed]):
		return
	_walk_target = target
	_walk_speed = speed

func stop_walking() -> void:
	if _for_owner(&"stop_walking"):
		return
	_walk_target = Vector3.INF

func reset_fov(duration := 0.5) -> void:
	if _for_owner(&"reset_fov", [duration]):
		return
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
		if bracing != null and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"crouch")):
			_let_go()
		elif event.is_action_pressed(&"skip_line") or (event.is_action_pressed(&"interact") and Dialogue.is_busy()):
			Dialogue.skip_line()
		return
	if event.is_action_pressed(&"skip_line"):
		Dialogue.skip_line()
	elif event.is_action_pressed(&"ping") and Net.active:
		_ping()
	elif event.is_action_pressed(&"crouch"):
		_auto_ducked = false
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
	if not is_local:
		_puppet_tick(delta)
		return
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
	if Net.active:
		_check_heavy()
	if downed:
		_bleed_out(delta)
	_use_usable.hold_time = REVIVE_HOLD if downed else 0.0
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
	var speed := _target_speed()
	if _walk_target != Vector3.INF:
		var to := _walk_target - global_position
		to.y = 0.0
		if to.length() < 0.2:
			_walk_target = Vector3.INF
		else:
			dir = to.normalized()
			speed = minf(_walk_speed, to.length() * 2.0 + 0.3)
	if _locks.is_empty():
		_auto_duck(dir, delta)
	var target := dir * speed
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
	# Co-op: the full jar is heavy going.
	var load_factor := 0.7 if carries_heavy() else 1.0
	match stance:
		Stance.CRAWL:
			return crawl_speed * load_factor
		Stance.CROUCH:
			return crouch_speed * load_factor
	if _wants_sprint() and not carries_heavy():
		return sprint_speed
	return walk_speed * load_factor

func _wants_sprint() -> bool:
	return _locks.is_empty() and Input.is_action_pressed(&"sprint") and Input.is_action_pressed(&"move_forward")

## Climbs small ledges (stairs, thresholds) the capsule would otherwise stop
## at: probe up, forward and back down for a walkable top, then lift the body
## onto it. The camera eases up afterwards instead of popping.
func _try_step_up(from: Vector3, dir: Vector3, _delta: float) -> void:
	var probe_forward := dir * (_capsule.radius + 0.12)
	# Find the step's top by looking down onto it, then lift by just that much
	# (lifting by the full step height fails under stairs overhead).
	var space := get_world_3d().direct_space_state
	var look_from := from + probe_forward + Vector3.UP * (max_step_height + 0.05)
	var q := PhysicsRayQueryParameters3D.create(look_from, look_from + Vector3.DOWN * (max_step_height + 0.1), collision_mask & 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
		return
	var rise: float = (hit.position as Vector3).y - from.y
	if rise < 0.04 or rise > max_step_height:
		return
	var up := Vector3.UP * (rise + 0.03)
	var xform := Transform3D(global_basis, from)
	if test_move(xform, up):
		return
	xform.origin += up
	if test_move(xform, probe_forward * 0.6):
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

## Ducking under a low lintel or through a low passage happens by itself:
## walking into a gap that is open at the body but too low for the head
## crouches, and the player straightens up once there is room again.
func _auto_duck(dir: Vector3, delta: float) -> void:
	if stance == Stance.STAND and dir != Vector3.ZERO and is_on_floor() and _low_passage_ahead(dir):
		_set_stance(Stance.CROUCH)
		_auto_ducked = true
		_duck_clear = 0.0
	elif _auto_ducked:
		if stance != Stance.CROUCH:
			_auto_ducked = false
		elif _ceiling_blocks(stand_height) or (dir != Vector3.ZERO and _low_passage_ahead(dir)):
			_duck_clear = 0.0
		else:
			_duck_clear += delta
			if _duck_clear > 0.3:
				_auto_ducked = false
				_set_stance(Stance.STAND)

## Something at head height ahead while the way is open lower down — unlike a
## table or a wall, which block below the waist too.
func _low_passage_ahead(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var flat := Vector3(dir.x, 0.0, dir.z).normalized() * (_capsule.radius + 0.6)
	for h in [0.5, 1.2, crouch_height - 0.15]:
		if _ray_hits(space, global_position + Vector3.UP * h, flat):
			return false
	var ahead := global_position + flat
	return _ray_hits(space, global_position + Vector3.UP * (stand_height - 0.15), flat) \
		or _ray_hits(space, ahead + Vector3.UP * (crouch_height - 0.05), Vector3.UP * (stand_height - crouch_height + 0.1))

func _ray_hits(space: PhysicsDirectSpaceState3D, from: Vector3, by: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + by, collision_mask & 1)
	q.exclude = [get_rid()]
	q.hit_back_faces = true
	return not space.intersect_ray(q).is_empty()

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
	if downed:
		return
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
	# Co-op: standing in your partner's lamplight shows you as well.
	for other in Net.players():
		if other == self or not other.has_lamp_lit():
			continue
		var reach := 13.0 if not other.inventory.lamp().is_raised else 17.0
		var d := other.chest_position().distance_to(chest)
		if d < reach:
			light += pow(1.0 - d / reach, 2.0) * 0.8
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
	exposure = clampf(visibility * stance_factor * motion_factor, 0.0, 1.0)
	Stealth.player_visibility = visibility
	Stealth.player_exposure = exposure

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

# --- Co-op ------------------------------------------------------------------------------------

## A call meant for this body's own machine: on the host, a puppet passes it
## on (the story turning the apprentice's head, a guard's blow); on the
## apprentice's machine, the master's puppet leaves it to the host. True when
## the call was handled that way.
func _for_owner(method: StringName, args: Array = []) -> bool:
	if is_local:
		return false
	Net.to_owner(self, method, args)
	return true

## The other player's body on this machine: no input, no HUD, no first-person
## arms; it follows the network and wears its character's model.
func _become_puppet() -> void:
	camera.current = false
	set_process_unhandled_input(false)
	interactor.enabled = false
	interactor.set_physics_process(false)
	interactor.set_process_unhandled_input(false)
	inventory.set_process_unhandled_input(false)
	viewmodel.visible = false
	viewmodel.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
		hud.queue_free()
	_build_puppet_model()
	_puppet_steps = AudioStreamPlayer3D.new()
	_puppet_steps.name = "PuppetSteps"
	_puppet_steps.bus = &"Tomb"
	_puppet_steps.unit_size = 5.0
	_puppet_steps.max_distance = 45.0
	add_child(_puppet_steps)
	_puppet_tag = Label3D.new()
	_puppet_tag.name = "Tag"
	_puppet_tag.text = tr("COOP_MASTER" if role == &"master" else "COOP_APPRENTICE")
	_puppet_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_puppet_tag.font = load("res://assets/ui/fonts/title.tres") as Font
	_puppet_tag.font_size = 48
	_puppet_tag.outline_size = 10
	_puppet_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_puppet_tag.fixed_size = true
	_puppet_tag.pixel_size = 0.001
	_puppet_tag.no_depth_test = true
	_puppet_tag.modulate = Color(0.95, 0.84, 0.62, 0.6)
	_puppet_tag.outline_modulate = Color(0, 0, 0, 0.55)
	_puppet_tag.position = Vector3(0, stand_height + 0.5, 0)
	add_child(_puppet_tag)

func _build_puppet_model() -> void:
	var entry: Array = PUPPET_MODELS[role]
	var scene := load(entry[0]) as PackedScene
	if scene == null:
		return
	_puppet_model = scene.instantiate() as Node3D
	_puppet_model.name = "PuppetModel"
	_puppet_model.scale = Vector3.ONE * float(entry[1])
	# Tripo characters face +x; the player looks down -z.
	_puppet_model.rotation.y = PI * 0.5
	add_child(_puppet_model)
	for n in _puppet_model.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var found := _puppet_model.find_children("*", "AnimationPlayer", true, false)
	_puppet_anim = found[0] as AnimationPlayer if not found.is_empty() else null
	if _puppet_anim != null:
		for clip in _puppet_anim.get_animation_list():
			# A fall plays once and stays down.
			var once := clip == &"collapse"
			_puppet_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE if once else Animation.LOOP_LINEAR
	# The craftsman model's modelling tool stays at his bench.
	var tool := _puppet_model.find_child("Tool", true, false) as Node3D
	if tool != null:
		tool.visible = false
	inventory.set_lamp_socket(_hand("L_Hand", "LampHand", -1.0))
	# What they hold in the right hand shows there too.
	_held_socket = _hand("R_Hand", "ItemHand", 1.0)
	inventory.selection_changed.connect(func(_i: int): _show_held())
	inventory.changed.connect(_show_held)

## A socket at one of the puppet's hands, following the bone (kept upright in
## `_puppet_tick`), or at the hip if the model has no such bone.
func _hand(bone: String, socket_name: String, side: float) -> Node3D:
	var socket := Node3D.new()
	socket.name = socket_name
	var skeletons := _puppet_model.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if skeleton == null or skeleton.find_bone(bone) < 0:
		socket.position = Vector3(0.4 * side, stand_height * 0.5, -0.35)
		add_child(socket)
		return socket
	var attach := BoneAttachment3D.new()
	attach.name = socket_name + "Bone"
	attach.bone_name = bone
	skeleton.add_child(attach)
	attach.add_child(socket)
	return socket

## The item the partner holds, in their model's right hand.
func _show_held() -> void:
	var item := inventory.selected_item()
	var id: StringName = item.id if item != null else &""
	if id == _held_id:
		return
	_held_id = id
	if _held_visual != null:
		_held_visual.queue_free()
		_held_visual = null
	if item == null or item.world_scene == null:
		return
	_held_visual = item.world_scene.instantiate() as Node3D
	_held_socket.add_child(_held_visual)

## Lets the other player use this body (talk to it, hand it things). Built on
## both bodies so a use has the same path on both machines; only a puppet's
## can be aimed at.
func _build_use_body() -> void:
	_use_body = StaticBody3D.new()
	_use_body.name = "UseBody"
	_use_body.collision_layer = 0 if is_local else 16
	_use_body.collision_mask = 0
	add_child(_use_body)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = stand_height
	shape.shape = cap
	shape.position.y = stand_height * 0.5
	_use_body.add_child(shape)
	_use_usable = DelegateUsable.new()
	_use_usable.name = "Usable"
	_use_usable.delegate_path = ^"../.."
	_use_usable.highlight = false
	_use_body.add_child(_use_usable)

func _puppet_tick(delta: float) -> void:
	if not _net_seen:
		return
	var follow := clampf(delta * 14.0, 0.0, 1.0)
	var to := _net_pos - global_position
	if to.length() > 5.0:
		global_position = _net_pos
	else:
		global_position += to * follow
	rotation.y = lerp_angle(rotation.y, _net_yaw, follow)
	_set_pitch(lerpf(_pitch, _net_pitch, follow))
	velocity = _net_vel
	_update_stance_shape(delta)
	head.position.y = _eye_height
	_use_body.get_child(0).position.y = _capsule.height * 0.5
	var lamp := inventory.lamp()
	if lamp != null:
		var lit := _net_bits & 8 != 0
		if lamp.is_lit != lit and not lamp.relighting:
			lamp.set_state(maxf(lamp.oil, 1.0), lit)
		lamp.is_raised = _net_bits & 16 != 0
		# Upright in the swinging hand, a little higher when held up.
		var socket := lamp.get_parent() as Node3D
		if socket != null:
			socket.global_basis = global_basis
			socket.position = Vector3(0, -0.02 + (0.08 if lamp.is_raised else 0.0), 0)
	if _held_socket != null:
		_held_socket.global_basis = global_basis
	_animate_puppet()
	_puppet_footsteps(delta)

func _animate_puppet() -> void:
	if _puppet_anim == null:
		return
	var speed := Vector2(_net_vel.x, _net_vel.z).length()
	var pose := &"idle"
	if downed:
		pose = &"down"
	else:
		pose = _pose_for(speed)
	var clip := _clip_for(pose)
	if clip != _puppet_clip and clip != &"":
		_puppet_clip = clip
		_puppet_anim.play(clip, 0.25)
	var pace := 1.0
	if pose in [&"walk", &"run"]:
		pace = clampf(speed / walk_speed, 0.6, 1.9)
	elif pose == &"crouch_walk":
		pace = clampf(speed / crouch_speed, 0.5, 1.6)
	elif pose == &"crawl":
		pace = clampf(speed / crawl_speed, 0.5, 1.6)
	_puppet_anim.speed_scale = pace
	# Without crouching or crawling clips the figure sinks instead.
	var sink := 0.0
	if not downed and stance != Stance.STAND and not String(clip).begins_with("crouch") and not String(clip).begins_with("crawl") \
			and clip not in [&"kneel", &"cower"]:
		sink = stand_height - _capsule.height
	_puppet_model.position.y = lerpf(_puppet_model.position.y, -sink * 0.55, 0.2)

func _pose_for(speed: float) -> StringName:
	var pose := &"idle"
	match stance:
		Stance.CRAWL:
			pose = &"crawl" if speed > 0.2 else &"crawl_idle"
		Stance.CROUCH:
			pose = &"crouch_walk" if speed > 0.3 else &"crouch"
		_:
			if _net_bits & 2 != 0:
				pose = &"climb"
			elif speed > walk_speed * 1.3:
				pose = &"run"
			elif speed > 0.3:
				pose = &"walk"
	return pose

func _clip_for(pose: StringName) -> StringName:
	for clip in PUPPET_CLIPS.get(pose, [pose]):
		if _puppet_anim.has_animation(clip):
			return clip
	return _puppet_clip

func _puppet_footsteps(delta: float) -> void:
	var speed := Vector2(_net_vel.x, _net_vel.z).length()
	if speed < 0.3 or _net_bits & 1 == 0:
		return
	_puppet_step_distance += speed * delta
	var stride := step_distance * (0.75 if _net_bits & 4 != 0 else 1.0) * (0.7 if stance == Stance.CRAWL else 1.0)
	if _puppet_step_distance < stride:
		return
	_puppet_step_distance = 0.0
	var options: Array = _footsteps.get(_surface_under(), [])
	if options.is_empty():
		return
	_puppet_steps.stream = options.pick_random()
	_puppet_steps.pitch_scale = randf_range(0.92, 1.08)
	match stance:
		Stance.CRAWL:
			_puppet_steps.volume_db = -16.0
		Stance.CROUCH:
			_puppet_steps.volume_db = -12.0
		_:
			_puppet_steps.volume_db = -3.0 if _net_bits & 4 != 0 else -7.0
	_puppet_steps.play()

## What the other machine needs to show this body (sent ~20 times a second).
func net_state() -> Array:
	var bits := 0
	if is_on_floor():
		bits |= 1
	if _ladder != null:
		bits |= 2
	if is_sprinting():
		bits |= 4
	var lamp := inventory.lamp()
	if lamp != null and lamp.is_lit:
		bits |= 8
	if lamp != null and lamp.is_raised:
		bits |= 16
	if downed:
		bits |= 32
	return [global_position, rotation.y, _pitch, int(stance), velocity, bits, exposure, health]

func net_apply(state: Array) -> void:
	if state.size() < 8:
		return
	_net_pos = state[0]
	_net_yaw = float(state[1])
	_net_pitch = float(state[2])
	var s := int(state[3])
	if s != int(stance):
		stance = s as Stance
		stance_changed.emit(stance)
	_net_vel = state[4]
	_net_bits = int(state[5])
	var was_down := downed
	downed = _net_bits & 32 != 0
	if downed != was_down:
		_on_partner_down_changed()
	exposure = float(state[6])
	health = float(state[7])
	if not _net_seen:
		_net_seen = true
		global_position = _net_pos
		rotation.y = _net_yaw

func _on_inventory_changed() -> void:
	if not Net.has_partner() or _inventory_dirty:
		return
	# Several changes in one moment go over as one.
	_inventory_dirty = true
	await get_tree().create_timer(0.25).timeout
	_inventory_dirty = false
	Net.send_inventory(self)

## Marks the spot (or the guard) under the crosshair for the partner.
func _ping() -> void:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 80.0, 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var guard: Node = null
	var n := hit.collider as Node
	while n != null:
		if n is Guard:
			guard = n
			break
		n = n.get_parent()
	Net.ping(hit.position, guard)

# --- Usable delegate: the partner's body -------------------------------------------------------

func usable_prompt(user: Node) -> String:
	var other := user as Player
	if other == null or other == self or other.downed:
		return ""
	if downed:
		return tr("PROMPT_REVIVE")
	if Quest.is_at(&"talk_apprentice"):
		return "" if _talking else tr("PROMPT_TALK")
	var item := other.inventory.selected_item()
	if item != null and inventory.has_room_for(item.id):
		return tr("PROMPT_GIVE_ITEM").format({"item": item.display_name()})
	if other.inventory.lamp() != null and inventory.lamp() == null:
		return tr("PROMPT_GIVE_LAMP")
	return ""

func usable_can_use(user: Node) -> bool:
	return usable_prompt(user) != ""

func usable_hold_done(user: Node) -> void:
	if downed and user != self:
		revive()

func usable_use(user: Node) -> void:
	var other := user as Player
	if other == null or downed:
		return
	if Quest.is_at(&"talk_apprentice"):
		_talk_task()
		return
	var item := other.inventory.selected_item()
	if item != null and inventory.has_room_for(item.id):
		other.inventory.remove(item.id, 1)
		inventory.add(item.id, 1)
		Sfx.play_at(preload("res://audio/sfx/impacts/cloth2.ogg"), global_position + Vector3.UP * 1.4, -8.0)
		return
	if other.inventory.lamp() != null and inventory.lamp() == null:
		var lamp_state := other.inventory.give_lamp()
		inventory.take_lamp(float(lamp_state.get("oil", 50.0)), bool(lamp_state.get("lit", true)))
		Sfx.play_at(preload("res://audio/sfx/impacts/handleSmallLeather.ogg"), global_position + Vector3.UP * 1.4, -6.0)

## Co-op: down, not dead: controls go (you can still look about), the view
## sinks to the floor, and the partner has BLEED_OUT_SECONDS to help you up.
func _go_down(reason: String) -> void:
	if downed:
		return
	downed = true
	_down_reason = reason
	_bleed = BLEED_OUT_SECONDS
	_notice_second = -1
	health = 0.0
	health_changed.emit(health, max_health)
	if bracing != null:
		_let_go()
	lock_controls(&"downed", false)
	_set_stance(Stance.CRAWL, true)
	velocity = Vector3.ZERO
	Net.player_downed(self)

## Co-op: takes hold of `spot` (both machines run this through the spot's
## use), down on one knee for low work or standing to bear on a lever.
func brace(spot: Node, low := true) -> void:
	bracing = spot
	if is_local:
		velocity = Vector3.ZERO
		_set_stance(Stance.CROUCH if low else Stance.STAND, true)
		lock_controls(&"brace", false)

func unbrace() -> void:
	bracing = null
	if is_local:
		unlock_controls(&"brace")

## Lets go of what this player holds, through the same use that took hold.
func _let_go() -> void:
	if bracing == null or not bracing.has_method(&"brace_usable"):
		bracing = null
		unlock_controls(&"brace")
		return
	Net.use(bracing.call(&"brace_usable") as Usable, self, &"use")

## Co-op: the full jar of mercury takes both hands, so no lamp while carried.
func carries_heavy() -> bool:
	return Net.active and inventory.has_item(&"vase_full")

func _check_heavy() -> void:
	if not carries_heavy():
		_heavy_told = false
		return
	if has_lamp_lit():
		inventory.lamp().snuff()
		Net.inventory_action(self, &"lamp_snuff")
	if not _heavy_told:
		_heavy_told = true
		var hud := get_node_or_null("HUD")
		if hud != null and hud.has_method(&"toast"):
			hud.call(&"toast", tr("COOP_JAR_BOTH_HANDS"))

func down_reason() -> String:
	return _down_reason if _down_reason != "" else "DEATH_GUARD"

func _bleed_out(delta: float) -> void:
	_bleed -= delta
	var second := ceili(_bleed)
	if second != _notice_second:
		_notice_second = second
		Net.show_notice(tr("COOP_DOWNED") % maxi(second, 0), 1.2)
	if _bleed <= 0.0:
		downed = false
		_die(_down_reason)

## Helped up by the partner (both machines run this; only the owner's counts).
func revive() -> void:
	if not downed:
		return
	downed = false
	Sfx.play_at(preload("res://audio/sfx/impacts/handleSmallLeather.ogg"), global_position + Vector3.UP, -4.0)
	if not is_local:
		return
	health = max_health * 0.5
	health_changed.emit(health, max_health)
	unlock_controls(&"downed")
	_set_stance(Stance.CROUCH, true)
	Net.hide_notice()
	_last_damage_time = Time.get_ticks_msec() / 1000.0

func _on_partner_down_changed() -> void:
	_use_usable.hold_time = REVIVE_HOLD if downed else 0.0
	if _puppet_tag != null:
		_puppet_tag.modulate = Color(0.95, 0.3, 0.2, 0.95) if downed else Color(0.95, 0.84, 0.62, 0.6)
	if downed:
		Net.show_notice(InputHint.format(tr("COOP_PARTNER_DOWN") % _puppet_tag.text), 6.0)
		Net.player_downed(self)

## Co-op's first step: the apprentice tells his master about the cracked
## legs, as the apprentice at his bench does alone.
func _talk_task() -> void:
	if _talking:
		return
	_talking = true
	await Dialogue.play(&"apprentice_task")
	_talking = false
	Quest.complete(&"talk_apprentice")

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
	_net_pos = global_position
	_net_yaw = rotation.y
