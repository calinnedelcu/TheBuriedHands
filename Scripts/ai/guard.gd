class_name Guard
extends CharacterBody3D
## A Qin guard. Sees by light (the player's exposure, distance and view cone),
## hears noises, and moves on the navmesh through these states:
##   PATROL -> SUSPICIOUS (stops, looks) -> INVESTIGATE (walks to the stimulus)
##   -> CHASE (runs, calls others) -> ATTACK, and back via SEARCH / RETURN.
## Before the sealing (flag `guards_hostile`) guards only go about their beat.
##
## Co-op: guards think on the host and watch both players, chasing whichever
## they saw; on the apprentice's machine they only follow what the host sends.

signal state_changed(state: State)
signal scripted_arrived

enum State { PATROL, SUSPICIOUS, INVESTIGATE, CHASE, ATTACK, SEARCH, RETURN, SCRIPTED }

## Clips of qin_guard.glb (tools/blender/build_guard.py builds it). A guard
## with a torch plays the torch_* version of each, torch held up in his left.
const ANIM := {
	&"idle": &"idle",
	&"idle_alt": &"idle_alt",
	&"walk": &"walk",
	&"run": &"run",
	&"talk": &"talk",
	&"listen": &"idle",
	&"ready": &"ready",
	&"advance": &"advance",
	&"attack": &"attack",
}
const ONE_SHOT := [&"attack"]
const THRUST := preload("res://audio/sfx/impacts/drawKnife1.ogg")

@export var route_path: NodePath
@export var walk_speed := 2.2
@export var run_speed := 5.4
@export var turn_speed := 5.0

@export_group("Senses")
@export var sight_range := 30.0
## Half-angle of the sharp central cone; outside it, out to `peripheral_angle`,
## the guard notices only half as well.
@export var sight_angle := 55.0
@export var peripheral_angle := 100.0
@export var sight_gain := 2.4
@export var hearing_scale := 1.0
@export var awareness_decay := 0.11
@export var eye_height := 2.75

@export_group("Combat")
## The ji reaches: guards thrust from a little further than arm's length.
@export var attack_range := 2.8
@export var attack_damage := 2.0
@export var attack_windup := 0.45
## After the thrust lands, the guard recovers before moving again.
@export var attack_recover := 0.45
@export var attack_cooldown := 1.2
@export var call_radius := 22.0

@export_group("Look")
## A burning torch in the right hand: it lights the guard's surroundings
## (making the player visible there) and shows where the guard is.
@export var carries_torch := false
## Where the fist is, in the hand bone's space (metres); the torch keeps
## itself upright.
@export var torch_offset := Vector3(0.0, 0.07, 0.02)
## Multiplies the armour's colour: lacquer and dye varied from man to man,
## and an officer's armour is red.
@export var armor_tint := Color(1, 1, 1)

const TORCH := preload("res://scenes/ai/guard_torch.tscn")

@onready var _agent: NavigationAgent3D = $Agent
@onready var _model: Node3D = $Model
@onready var _icon: Label3D = $AwarenessIcon
@onready var _footsteps: AudioStreamPlayer3D = $FootstepAudio

var state := State.PATROL
var awareness := 0.0

var _route: PatrolRoute
var _route_index := 0
var _wait_timer := 0.0
var _anim: AnimationPlayer
var _current_anim: StringName = &""
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: Player
var _stimulus := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _seen_timer := 0.0
var _lost_timer := 0.0
var _search_points: Array[Vector3] = []
var _look_timer := 0.0
var _look_base_yaw := 0.0
var _attack_timer := 0.0
var _struck := false
var _cooldown := 0.0
var _perception_timer := 0.0
var _step_distance := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector3.ZERO
var _home := Vector3.ZERO
var _desired_yaw := 0.0
var _bark_cooldown := 0.0
var _scripted_target := Vector3.INF
var _scripted_run := false
var _anim_key: StringName = &""
var _net_pos := Vector3.INF
var _net_yaw := 0.0

func _ready() -> void:
	add_to_group(&"guards")
	add_to_group(&"persistent")
	_home = global_position
	_desired_yaw = rotation.y
	_anim = _first_anim_player()
	if _anim != null:
		for clip in _anim.get_animation_list():
			var base := String(clip).trim_prefix("torch_")
			_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE if StringName(base) in ONE_SHOT else Animation.LOOP_LINEAR
	_route = get_node_or_null(route_path) as PatrolRoute
	Stealth.register_guard(self)
	Stealth.noise_made.connect(_on_noise)
	_agent.velocity_computed.connect(_on_velocity_computed)
	_play(&"idle")
	_icon.visible = false
	if carries_torch:
		_attach_torch()
	if armor_tint != Color(1, 1, 1):
		_tint_armor()

func _exit_tree() -> void:
	Stealth.unregister_guard(self)

func _tint_armor() -> void:
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.name == &"Ji" or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var tinted := mat.duplicate() as StandardMaterial3D
			tinted.albedo_color = mat.albedo_color * armor_tint
			mi.set_surface_override_material(i, tinted)

func _attach_torch() -> void:
	# The model has a grip in the left hand for it.
	var grip := _model.find_child("TorchGrip", true, false) as Node3D
	if grip != null:
		var held := TORCH.instantiate() as Node3D
		grip.add_child(held)
		held.set(&"side_out", 0.0)
		return
	var skeleton := _model.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var hand := BoneAttachment3D.new()
	hand.name = "TorchHand"
	hand.bone_name = "R_Hand"
	(skeleton[0] as Node).add_child(hand)
	var torch := TORCH.instantiate() as Node3D
	hand.add_child(torch)
	# The skeleton is scaled with the model; the offset is in real metres.
	var s := 1.0 / maxf((skeleton[0] as Node3D).global_transform.basis.get_scale().x, 0.001)
	torch.set(&"grip_offset", torch_offset * s)

func awareness_level() -> float:
	return clampf(awareness, 0.0, 1.0) if state != State.SCRIPTED else 0.0

func is_hostile() -> bool:
	return bool(Game.get_flag(&"guards_hostile")) and state != State.SCRIPTED

## Hands control to a cutscene (walk to points, play animations) or back.
func set_scripted(active: bool) -> void:
	_scripted_target = Vector3.INF
	_set_state(State.SCRIPTED if active else State.RETURN)

## Cutscene walk: resolves when the guard reaches `point` (SCRIPTED state only).
func scripted_walk_to(point: Vector3, run := false) -> void:
	_scripted_target = point
	_scripted_run = run
	_agent.target_position = point
	await scripted_arrived

## Cutscene: turn to face a point.
func scripted_face(point: Vector3) -> void:
	_face(point)

## Teleports onto the patrol route (used after a cutscene, out of sight).
func warp_to_route(index := 0) -> void:
	if _route == null or _route.points().is_empty():
		return
	_route_index = index % _route.points().size()
	global_position = _route.points()[_route_index].global_position
	_wait_timer = 0.0

func play_animation(key: StringName) -> void:
	_play(key)

## Another guard raised the alarm nearby.
func hear_alarm(position: Vector3) -> void:
	if not is_hostile() or state == State.CHASE or state == State.ATTACK:
		return
	_stimulus = position
	awareness = maxf(awareness, 0.75)
	_set_state(State.INVESTIGATE)

# --- Main loop ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Net.is_client():
		_net_tick(delta)
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	_cooldown = maxf(0.0, _cooldown - delta)
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = 0.1
		_perceive(0.1)
	match state:
		State.PATROL:
			_tick_patrol(delta)
		State.SUSPICIOUS:
			_tick_suspicious(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.SEARCH:
			_tick_search(delta)
		State.RETURN:
			_tick_return(delta)
		State.SCRIPTED:
			_tick_scripted(delta)
	if not is_on_floor():
		velocity.y -= _gravity * 1.6 * delta
	else:
		velocity.y = -0.5
	rotation.y = lerp_angle(rotation.y, _desired_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	move_and_slide()
	_update_footsteps(delta)
	_update_icon()

# --- Perception ---------------------------------------------------------------------

func _perceive(dt: float) -> void:
	if not is_hostile() or _player == null or Game.is_dead():
		awareness = move_toward(awareness, 0.0, dt * 0.5)
		return
	# Whoever shows more: in co-op the guard turns on the one he sees best.
	var seen := 0.0
	for p in Net.players():
		# Co-op: a man on the floor is left for dead.
		if p.downed:
			continue
		var f := _sight_factor(p)
		if f > seen:
			seen = f
			_player = p
	if seen > 0.0:
		awareness = minf(awareness + dt * sight_gain * seen, 1.25)
		_last_seen = _player.global_position
		_stimulus = _last_seen
		_seen_timer = 0.0
	else:
		_seen_timer += dt
		var decay := awareness_decay * (0.35 if state in [State.CHASE, State.SEARCH] else 1.0)
		awareness = maxf(0.0, awareness - dt * decay)
	_react()

## How clearly the guard sees player `p` right now (0 = not at all).
func _sight_factor(p: Player) -> float:
	var eyes := global_position + Vector3.UP * eye_height
	var target := p.chest_position()
	var to := target - eyes
	var dist := to.length()
	if dist > sight_range:
		return 0.0
	var forward := -global_basis.z
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var angle := rad_to_deg(acos(clampf(forward.dot(flat), -1.0, 1.0)))
	var cone := 1.0 if angle <= sight_angle else (0.45 if angle <= peripheral_angle else 0.0)
	if cone == 0.0:
		return 0.0
	if not _has_line_of_sight(eyes, target) and not _has_line_of_sight(eyes, p.eye_position()):
		return 0.0
	var light_term := p.exposure * sqrt(1.0 - dist / sight_range)
	# Up close, a guard makes out a shape even in the dark.
	var stance_size := 0.45 if p.is_crawling() else (0.7 if p.is_crouching() else 1.0)
	var near_term := clampf(1.0 - dist / 4.5, 0.0, 1.0) * 0.9 * stance_size
	var f := maxf(light_term, near_term) * cone
	return f if f > 0.05 else 0.0

func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var params := PhysicsRayQueryParameters3D.create(from, to, 1)
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(params).is_empty()

func _on_noise(position: Vector3, radius: float, source: Node) -> void:
	if Net.is_client() or not is_hostile() or source == self or source is Guard:
		return
	if state == State.CHASE or state == State.ATTACK:
		return
	var eff := radius * hearing_scale
	var d := global_position.distance_to(position)
	if d > eff:
		return
	if not _has_line_of_sight(global_position + Vector3.UP * eye_height, position + Vector3.UP * 0.5):
		eff *= 0.55
		if d > eff:
			return
	var strength := 1.0 - d / eff
	awareness = minf(awareness + 0.25 + strength * 0.55, 0.95)
	_stimulus = position
	if not (source is Player) and _bark_cooldown <= 0.0:
		_bark(&"noise")
	_react()

## Moves between states from the awareness level.
func _react() -> void:
	match state:
		State.PATROL, State.RETURN, State.SEARCH:
			if awareness >= 1.0:
				_start_chase()
			elif awareness >= 0.5:
				_set_state(State.INVESTIGATE)
			elif awareness >= 0.2 and state != State.SEARCH:
				_set_state(State.SUSPICIOUS)
		State.SUSPICIOUS:
			if awareness >= 1.0:
				_start_chase()
			elif awareness >= 0.5:
				_set_state(State.INVESTIGATE)
		State.INVESTIGATE:
			if awareness >= 1.0:
				_start_chase()

func _start_chase() -> void:
	if state == State.CHASE or state == State.ATTACK:
		return
	_set_state(State.CHASE)
	_bark(&"spotted", true)
	for g in Stealth.guards():
		if g != self and is_instance_valid(g) and g.global_position.distance_to(global_position) < call_radius:
			g.call(&"hear_alarm", _last_seen)

# --- States -----------------------------------------------------------------------

func _set_state(s: State) -> void:
	if s == state:
		return
	var prev := state
	state = s
	match s:
		State.PATROL:
			_agent.target_position = _route_point()
		State.SUSPICIOUS:
			_stop()
			_look_timer = randf_range(1.6, 2.6)
			_face(_stimulus)
			if prev == State.PATROL:
				_bark(&"suspicious")
		State.INVESTIGATE:
			_agent.target_position = _stimulus
			if prev != State.SEARCH:
				_bark(&"investigate")
		State.CHASE:
			_lost_timer = 0.0
		State.SEARCH:
			_plan_search()
		State.RETURN:
			_agent.target_position = _route_point() if _route != null else _home
			if prev == State.SEARCH:
				_bark(&"calm")
		State.ATTACK:
			_struck = false
			_play(&"attack", true)
			Sfx.play_at(THRUST, global_position + Vector3.UP * 1.5, -2.0, 0.1)
		State.SCRIPTED:
			_stop()
			awareness = 0.0
	state_changed.emit(s)

func _tick_patrol(delta: float) -> void:
	if _route == null or _route.points().is_empty():
		_stop()
		_play(&"idle")
		return
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_stop()
		if _route.looks_at(_route_index):
			_desired_yaw = _look_base_yaw + sin(_wait_timer * 1.4) * 0.9
		_play(&"idle_alt" if _route.looks_at(_route_index) else &"idle")
		if _wait_timer <= 0.0:
			_route_index = (_route_index + 1) % _route.points().size()
			_agent.target_position = _route_point()
		return
	if _move_along(walk_speed, delta):
		_wait_timer = _route.wait_at(_route_index)
		_look_base_yaw = rotation.y

func _tick_suspicious(delta: float) -> void:
	_stop()
	_play(&"ready")
	_face(_stimulus)
	_look_timer -= delta
	if _look_timer <= 0.0 and awareness < 0.5:
		awareness = 0.0
		_set_state(State.RETURN)

func _tick_investigate(delta: float) -> void:
	_agent.target_position = _stimulus
	if _move_along(walk_speed * 1.25, delta, &"advance"):
		_set_state(State.SEARCH)

func _tick_chase(delta: float) -> void:
	if _target_down():
		return
	if _seen_timer < 0.15:
		_agent.target_position = _last_seen
		_lost_timer = 0.0
		var d := global_position.distance_to(_player.global_position)
		if d <= attack_range:
			if _cooldown <= 0.0:
				_set_state(State.ATTACK)
				_attack_timer = attack_windup
				return
			# In reach but not ready to strike again: keep the ji between
			# you, levelled, instead of walking into your face.
			_stop()
			_face(_player.global_position)
			_play(&"ready")
			return
	else:
		_lost_timer += delta
		if _lost_timer > 4.0:
			_bark(&"lost")
			_stimulus = _last_seen
			_set_state(State.SEARCH)
			return
	if _move_along(run_speed, delta, &"run") and _seen_timer >= 0.15:
		_set_state(State.SEARCH)

## A thrust of the ji: wind up (still turning to follow), strike, recover.
func _tick_attack(delta: float) -> void:
	_stop()
	if _target_down():
		return
	_attack_timer -= delta
	if not _struck:
		_face(_player.global_position)
		if _attack_timer > 0.0:
			return
		_struck = true
		_attack_timer = attack_recover
		var to := _player.global_position - global_position
		var in_front := (-global_basis.z).dot(Vector3(to.x, 0, to.z).normalized()) > 0.4
		if to.length() <= attack_range + 0.5 and in_front and not Game.is_dead():
			_player.apply_damage(attack_damage, self, "DEATH_GUARD")
			_player.push(Vector3(to.x, 0, to.z).normalized() * 6.0)
			Sfx.play_at(preload("res://audio/sfx/impacts/impactPunch_medium_000.ogg"), _player.global_position, 2.0)
		return
	if _attack_timer <= 0.0:
		_cooldown = attack_cooldown
		_set_state(State.CHASE)

## Co-op: the one he was after went down; he looks about him for the other.
func _target_down() -> bool:
	if _player == null or not _player.downed:
		return false
	_stimulus = _player.global_position
	_set_state(State.SEARCH)
	return true

func _tick_search(delta: float) -> void:
	if _look_timer > 0.0:
		_look_timer -= delta
		_stop()
		_play(&"idle_alt")
		_desired_yaw = _look_base_yaw + sin(_look_timer * 1.8) * 1.1
		return
	if _search_points.is_empty():
		awareness = minf(awareness, 0.15)
		_set_state(State.RETURN)
		return
	_agent.target_position = _search_points[0]
	if _move_along(walk_speed * 1.15, delta, &"advance"):
		_search_points.pop_front()
		_look_timer = randf_range(1.5, 2.5)
		_look_base_yaw = rotation.y

func _tick_return(delta: float) -> void:
	if _move_along(walk_speed, delta):
		_set_state(State.PATROL)

func _tick_scripted(delta: float) -> void:
	if _scripted_target == Vector3.INF:
		_stop()
		return
	if _move_along(run_speed if _scripted_run else walk_speed, delta, &"run" if _scripted_run else &"walk"):
		_scripted_target = Vector3.INF
		_play(&"idle")
		scripted_arrived.emit()

func _plan_search() -> void:
	_search_points.clear()
	var map := get_world_3d().navigation_map
	_search_points.append(NavigationServer3D.map_get_closest_point(map, _stimulus))
	for i in 3:
		var offset := Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		_search_points.append(NavigationServer3D.map_get_closest_point(map, _stimulus + offset))
	_look_timer = 0.0

# --- Movement -----------------------------------------------------------------------

## Walks toward the agent target. Returns true on arrival.
func _move_along(speed: float, delta: float, anim := &"walk") -> bool:
	if _agent.is_navigation_finished():
		_stop()
		return true
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return false
	dir = dir.normalized()
	_desired_yaw = atan2(-dir.x, -dir.z)
	var desired := dir * speed
	if _agent.avoidance_enabled:
		_agent.velocity = desired
	else:
		velocity.x = desired.x
		velocity.z = desired.z
	_play(anim)
	# Unstick: if barely moving while trying to, skip ahead.
	if global_position.distance_to(_last_pos) < speed * delta * 0.15:
		_stuck_timer += delta
		if _stuck_timer > 1.5:
			_stuck_timer = 0.0
			return true
	else:
		_stuck_timer = 0.0
	_last_pos = global_position
	return false

func _on_velocity_computed(safe: Vector3) -> void:
	velocity.x = safe.x
	velocity.z = safe.z

func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		_desired_yaw = atan2(-to.x, -to.z)

func _route_point() -> Vector3:
	if _route == null or _route.points().is_empty():
		return _home
	return _route.points()[_route_index % _route.points().size()].global_position

func _play(key: StringName, restart := false) -> void:
	if _anim == null:
		return
	var anim_name: StringName = ANIM.get(key, key)
	if carries_torch and _anim.has_animation(StringName("torch_" + String(anim_name))):
		anim_name = StringName("torch_" + String(anim_name))
	if (anim_name == _current_anim and not restart) or not _anim.has_animation(anim_name):
		return
	_anim_key = key
	_current_anim = anim_name
	if restart:
		_anim.stop()
	_anim.play(anim_name, 0.12 if key == &"attack" else 0.25, 1.15 if key == &"run" else 1.0)

func _update_footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.3 or _footsteps == null:
		return
	_step_distance += speed * delta
	if _step_distance >= 2.4:
		_step_distance = 0.0
		_footsteps.pitch_scale = randf_range(0.9, 1.05)
		_footsteps.volume_db = -6.0 if speed > walk_speed * 1.5 else -11.0
		_footsteps.play()

func _update_icon() -> void:
	var a := awareness_level()
	if a < 0.15 or state == State.SCRIPTED:
		_icon.visible = false
		return
	_icon.visible = true
	var alarmed := state == State.CHASE or state == State.ATTACK
	_icon.text = "!" if alarmed else "?"
	_icon.modulate = Color(1.0, 0.25, 0.15) if alarmed else Color(1.0, 0.82, 0.4, clampf(a * 1.4, 0.3, 1.0))
	_icon.scale = Vector3.ONE * (1.0 + (0.25 if alarmed else a * 0.3))

func _bark(kind: StringName, force := false) -> void:
	if _bark_cooldown > 0.0 and not force:
		return
	var near := false
	for p in Net.players():
		near = near or global_position.distance_to(p.global_position) <= 26.0
	if not near:
		return
	_bark_cooldown = 6.0
	var key := DialogueDB.random_bark(kind)
	if key != "":
		Dialogue.say(&"guard", key, Dialogue.Priority.AMBIENT)

# --- Co-op ---------------------------------------------------------------------------

## What the apprentice's machine needs to show this guard.
func net_state() -> Array:
	return [global_position, rotation.y, _anim_key, awareness, int(state)]

func net_apply(data: Array) -> void:
	_net_pos = data[0]
	_net_yaw = float(data[1])
	awareness = float(data[3])
	var s := int(data[4])
	if s != int(state):
		state = s as State
		if state == State.ATTACK:
			_play(&"attack", true)
			Sfx.play_at(THRUST, global_position + Vector3.UP * 1.5, -2.0, 0.1)
		state_changed.emit(state)
	if state != State.ATTACK:
		_play(data[2])

func _net_tick(delta: float) -> void:
	if _net_pos == Vector3.INF:
		return
	var before := global_position
	var to := _net_pos - global_position
	if to.length() > 6.0:
		global_position = _net_pos
	else:
		global_position += to * clampf(delta * 10.0, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, _net_yaw, clampf(delta * 10.0, 0.0, 1.0))
	velocity = (global_position - before) / maxf(delta, 0.001)
	_update_footsteps(delta)
	_update_icon()

# --- Persistence ---------------------------------------------------------------------

func persist_save() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "route": _route_index}

func persist_load(data: Dictionary) -> void:
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(data.get("yaw", rotation.y))
	_desired_yaw = rotation.y
	_route_index = int(data.get("route", 0))
	awareness = 0.0
	_set_state(State.RETURN)

func _first_anim_player() -> AnimationPlayer:
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
