extends Node
## Dev test: plays Act I with real input. Walks the navmesh with the move
## keys, turns to look at things, presses/holds/taps the use key, answers the
## apprentice, and saves a frame every few seconds. Catches what teleporting
## bots can't: blocked paths, unreachable or untargetable objects, prompts.
## godot --path . --resolution 1280x720 -s res://tools/dev/run.gd -- --runner=res://tools/dev/autopilot_runner.gd --out=/abs/dir

const WS := "Rooms/01_TerracottaWorkshop/"

var player: Player
var level: Node3D
var out := ""
var failures := 0
var _shot_timer := 0.0
var _shots := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

func _process(delta: float) -> void:
	if out == "" or player == null:
		return
	_shot_timer -= delta
	if _shot_timer <= 0.0:
		_shot_timer = 2.5
		_shot("%03d_%s" % [_shots, Quest.current()])

func _run() -> void:
	Game.new_game()
	await Game.level_ready
	level = Game.level as Node3D
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(1.0)
	await _skip_dialogue()
	_expect(&"talk_apprentice")

	await _use(WS + "Apprentice/TalkBody")
	await _skip_dialogue()
	_expect(&"take_lamp")
	await _use(WS + "LampStand_W/Body", "tap")
	_check("holding a lit lamp", player.inventory.lamp() != null and player.inventory.lamp().is_lit)
	await _skip_dialogue()
	_expect(&"fetch_slip")
	await _use(WS + "SlipBowl")
	await _skip_dialogue()
	_expect(&"place_bowl")
	await _use(WS + "ClayStatue/Body")
	_expect(&"apply_slip")
	await _use(WS + "ClayStatue/Body", "hold")
	await _skip_dialogue()
	_expect(&"find_chisel")
	await _use(WS + "FallenChisel")
	await _skip_dialogue()
	_expect(&"finish_statue")
	for i in 3:
		await _use(WS + "ClayStatue/Body")
		await _wait(0.4)
	_expect(&"sealing")
	var t := 0.0
	while not Quest.is_at(&"answer_apprentice") and t < 150.0:
		_press(&"skip_line")
		await _wait(0.5)
		t += 0.5
	_expect(&"answer_apprentice")
	await _use(WS + "Apprentice/TalkBody")
	t = 0.0
	while not Quest.is_at(&"find_liang") and t < 60.0:
		if Dialogue.is_busy():
			_press(&"skip_line")
		_press(&"slot_1")
		await _wait(0.5)
		t += 0.5
	_expect(&"find_liang")
	_check("apprentice has the lamp", Game.get_flag(&"gave_lamp"))
	await _use(WS + "LampStand_E2/Body", "tap")
	_check("took a second lamp", player.inventory.lamp() != null)
	# Out of the workshop toward the archives.
	var walked := await _walk_to(Vector3(6.0, 0.0, -6.0), 1.5)
	_check("walked to the archives (%s)" % player.global_position.snapped(Vector3.ONE * 0.1), walked)
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

# --- Walking ---------------------------------------------------------------------------------

## Follows the navmesh to `target` with the move keys. Stops early when
## `until` (a Callable returning bool) says so, like a player who stops once
## the thing is within reach. When stuck it hops and sidesteps, then re-paths.
func _walk_to(target: Vector3, stop_dist := 1.8, until := Callable()) -> bool:
	var map := player.get_world_3d().navigation_map
	for attempt in 4:
		var from := NavigationServer3D.map_get_closest_point(map, player.global_position)
		# Aim at the floor under the target: table tops and chair seats are
		# walkable islands in the navmesh, and snapping to one sends us into
		# the furniture.
		var to := NavigationServer3D.map_get_closest_point(map, Vector3(target.x, player.global_position.y, target.z))
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		if path.is_empty():
			_check("nav path to %s" % target, false)
			return false
		var result := await _follow(path, target, stop_dist, until)
		if result != "stuck":
			Input.action_release(&"move_forward")
			await _wait(0.2)
			return true
		print("  stuck at ", player.global_position.snapped(Vector3.ONE * 0.1), ", detouring")
		await _detour(target, attempt)
	Input.action_release(&"move_forward")
	return false

## Something the navmesh doesn't know about (a seated NPC, a prop) is in the
## way: step around it — back off, then walk sideways toward whichever side is
## open — before asking for a new path.
func _detour(target: Vector3, attempt: int) -> void:
	var to := target - player.global_position
	to.y = 0.0
	var fwd := to.normalized()
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var space := player.get_world_3d().direct_space_state
	var options: Array[Vector3] = [side, -side, (side - fwd).normalized(), (-side - fwd).normalized()]
	if attempt % 2 == 1:
		options = [-side, side, (-side - fwd).normalized(), (side - fwd).normalized()]
	var go := -fwd
	for dir in options:
		var free := true
		for h in [0.5, 1.5]:
			var from: Vector3 = player.global_position + Vector3.UP * h
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.8, 1 | 4)
			q.exclude = [player.get_rid()]
			if not space.intersect_ray(q).is_empty():
				free = false
		if free:
			go = dir
			break
	Input.action_press(&"move_backward")
	await _wait(0.3)
	Input.action_release(&"move_backward")
	_face_flat(player.global_position + go)
	Input.action_press(&"move_forward")
	await _wait(0.9)
	Input.action_release(&"move_forward")

## "done", "stopped" (the `until` condition) or "stuck".
func _follow(path: PackedVector3Array, target: Vector3, stop_dist: float, until: Callable) -> String:
	var i := 1
	var best := INF
	var stuck_t := 0.0
	while i < path.size():
		if until.is_valid() and until.call():
			return "stopped"
		var goal := target - player.global_position
		goal.y = 0.0
		if goal.length() < stop_dist:
			return "done"
		var flat := path[i] - player.global_position
		flat.y = 0.0
		if flat.length() < 0.6:
			i += 1
			best = INF
			continue
		_face_flat(path[i])
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		var d := flat.length()
		if d < best - 0.05:
			best = d
			stuck_t = 0.0
		else:
			stuck_t += get_physics_process_delta_time()
			if stuck_t > 2.0:
				Input.action_release(&"move_forward")
				return "stuck"
	return "done"

func _face_flat(p: Vector3) -> void:
	var to := p - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)

## Turns body and head toward a world point, like the mouse would.
func _look_at(p: Vector3) -> void:
	var eye := player.camera.global_position
	var to := p - eye
	player.rotation.y = atan2(-to.x, -to.z)
	var flat := Vector2(to.x, to.z).length()
	player._set_pitch(atan2(to.y, flat))

# --- Using things ----------------------------------------------------------------------------

func _use(path: String, how := "press") -> void:
	var body := level.get_node_or_null(path) as Node3D
	if body == null:
		_check("exists: " + path, false)
		return
	var aim := _aim_point(body)
	var reachable := func() -> bool: return _can_target(body, aim)
	await _walk_to(aim, 1.6, reachable)
	if not _can_target(body, aim):
		# Things under benches need a crouch, like a player would.
		player._set_stance(Player.Stance.CROUCH)
		await _wait(0.4)
		if not _can_target(body, aim):
			await _walk_to(aim, 1.0, reachable)
	_look_at(aim)
	await _wait(0.25)
	var target := player.interactor.target
	var ok := target != null and target.get_node(target.body_path) == body
	_check("targets %s (prompt: %s)" % [path.get_file(), player.interactor._prompt_cache], ok)
	if ok:
		match how:
			"press":
				_press(&"interact")
			"tap":
				_press_hold(&"interact", 0.08)
			"hold":
				await _hold(&"interact", target.hold_time + 0.3)
		await _wait(0.5)
	if player.is_crouching():
		player._set_stance(Player.Stance.STAND)

## Within reach and in plain sight from the eyes (what the interaction ray sees).
func _can_target(body: Node3D, aim: Vector3) -> bool:
	var eye := player.camera.global_position
	if eye.distance_to(aim) > 3.3:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, aim, player.interactor.collision_mask)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == body

func _aim_point(body: Node3D) -> Vector3:
	for c in body.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return body.global_position

func _press(action: StringName) -> void:
	_send(action, true)
	_send.call_deferred(action, false)

func _press_hold(action: StringName, seconds: float) -> void:
	_send(action, true)
	get_tree().create_timer(seconds).timeout.connect(_send.bind(action, false))

func _hold(action: StringName, seconds: float) -> void:
	_send(action, true)
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)
	_send(action, false)

func _send(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

# --- Helpers ---------------------------------------------------------------------------------

func _skip_dialogue() -> void:
	var t := 0.0
	while Dialogue.is_busy() and t < 60.0:
		_press(&"skip_line")
		await _wait(0.4)
		t += 0.4

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _expect(step: StringName) -> void:
	_check("quest at %s (actual %s)" % [step, Quest.current()], Quest.is_at(step))

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _shot(name: String) -> void:
	_shots += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
