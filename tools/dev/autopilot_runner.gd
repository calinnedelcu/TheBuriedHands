extends Node
## Dev test: plays the game with real input. Walks the navmesh with the move
## keys, turns to look at things, presses/holds/taps the use key, climbs
## ladders, crawls, answers the apprentice. Catches what teleporting bots
## can't: blocked paths, unreachable or untargetable objects, prompts.
## Guards are made harmless from Act II on (this tests the route, not stealth).
## Act III goes through the service tunnels, or with --route=pits down the
## workers' shaft and through the army pits (the lift, the pen, the stairs).
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/autopilot_runner.gd [--from=act2|act3|act4|act5] [--route=pits] [--out=/abs/dir for frames, needs a window]

const WS := "Rooms/01_TerracottaWorkshop/"

var player: Player
var level: Node3D
var out := ""
var failures := 0
var _shot_timer := 0.0
var _shots := 0
var _from := "act1"
var _route := "tunnels"
var _nav_map: RID
var _verbose := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--from="):
			_from = arg.substr(7)
		elif arg.begins_with("--route="):
			_route = arg.substr(8)
		elif arg == "--verbose":
			_verbose = true
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
	Game.failed.connect(func(reason: String): print("  DIED at %s: %s (toxicity %.0f)" % [player.global_position.snapped(Vector3.ONE * 0.1), reason, player.toxicity]))
	await _bake_player_nav()
	await _wait(1.0)
	var acts := ["act1", "act2", "act3", "act4", "act5"]
	var start := acts.find(_from)
	if start > 0:
		_setup(acts[start])
		await _wait(0.5)
	for i in range(start, acts.size()):
		print("--- ", acts[i])
		var ok: bool = await call("_" + acts[i])
		if not ok:
			print("  (stopping: %s did not finish)" % acts[i])
			break
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

## Jump-starts a later act: the state it would be in, standing where it begins.
func _setup(act: String) -> void:
	Dialogue.stop()
	Game.set_flag(&"guards_hostile")
	Game.advance_sealing(1)
	player.inventory.take_lamp(100.0, true)
	match act:
		"act2":
			Quest.start_at(&"find_liang")
			player.global_position = Vector3(6.0, 0.2, -6.0)
		"act3":
			Quest.start_at(&"reach_mechanism")
			# Wei's men took the apprentice while his master was with Liang.
			Game.set_flag(&"apprentice_taken")
			player.inventory.add(&"wedge")
			player.inventory.add(&"hammer")
			player.global_position = Vector3(37.8, 0.4, -27.5)
		"act4":
			Quest.start_at(&"inspect_balance")
			player.global_position = Vector3(0.5, 7.7, 44.5)
		"act5":
			Quest.start_at(&"find_drain")
			Game.advance_sealing(2)
			var cw := level.get_node("Mechanism/Counterweight")
			cw.call(&"persist_load", {"tipped": true})
			player.global_position = Vector3(0.5, 7.7, 44.5)

func _act1() -> bool:
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
	var walked := await _walk_to(Vector3(6.0, 0.0, -6.0), 1.5)
	_check("walked to the archives (%s)" % player.global_position.snapped(Vector3.ONE * 0.1), walked)
	return Quest.is_at(&"find_liang")

func _act2() -> bool:
	# This run tests the route, not stealth.
	for g in get_tree().get_nodes_in_group(&"guards"):
		(g as Guard).sight_range = 0.0
		(g as Guard).hearing_scale = 0.0
	await _use("Register")
	_check("evidence taken", Game.get_flag(&"has_evidence"))
	await _skip_dialogue()
	await _walk_to(Vector3(37.8, 0.2, -26.2), 1.2)
	await _wait(0.5)
	_expect(&"talk_liang")
	await _use("Liang/TalkBody")
	await _skip_dialogue()
	_expect(&"reach_mechanism")
	return Quest.is_at(&"reach_mechanism")

func _act3() -> bool:
	for g in get_tree().get_nodes_in_group(&"guards"):
		(g as Guard).sight_range = 0.0
		(g as Guard).hearing_scale = 0.0
	if not player.inventory.has_item(&"wedge"):
		await _use("Tool_Workbench_Wedge_W2")
	if not player.inventory.has_item(&"hammer"):
		await _use("Tool_Workbench_Hammer_W")
	_check("wedge and mallet", player.inventory.has_item(&"wedge") and player.inventory.has_item(&"hammer"))
	for i in 4:
		await _use("ShaftStone/Body", "hold")
		await _wait(0.3)
	_check("stone broken", bool(level.get_node("ShaftStone").get("broken")))
	await _skip_dialogue()
	await _climb("Mechanism/Ladder1", false)
	if _route == "pits":
		if not await _pits():
			return false
	else:
		await _walk_to(Vector3(31.8, -8.4, -40.0), 1.5)
	await _walk_to(Vector3(0.5, -7.4, 41.0), 1.2)
	await _climb("Mechanism/Ladder3", true)
	await _walk_to(Vector3(0.0, 7.7, 45.6), 1.0)
	await _wait(0.5)
	await _skip_dialogue()
	_expect(&"inspect_balance")
	return Quest.is_at(&"inspect_balance")

func _act4() -> bool:
	await _climb("Mechanism/Ladder2", true)
	await _use("Mechanism/Counterweight/Body", "tap")
	await _skip_dialogue()
	_expect(&"get_vase")
	await _climb("Mechanism/Ladder2", false)
	await _use("Mechanism/Jar")
	await _use("Mechanism/Cloth")
	await _skip_dialogue()
	_expect(&"fill_vase")
	# Down the stairs from the balcony; fill at the mercury's edge by their foot.
	await _walk_to(Vector3(-54.6, 0.2, 84.0), 0.8)
	await _use("MercuryHall/FillPoint1/UseBody", "hold", Vector3(-55.9, -0.05, 84.0))
	await _skip_dialogue()
	_expect(&"pour_mercury")
	await _walk_to(Vector3(2.0, 7.7, 46.0), 1.5)
	await _climb("Mechanism/Ladder2", true)
	await _use("Mechanism/Counterweight/Body", "hold")
	var t := 0.0
	while not Quest.is_at(&"find_drain") and t < 30.0:
		_press(&"skip_line")
		await _wait(0.5)
		t += 0.5
	_expect(&"find_drain")
	return Quest.is_at(&"find_drain")

func _act5() -> bool:
	# The tipped balance changes the room (its collision is rebuilt when it
	# settles): plan routes on the room as it is now.
	await _wait(9.0)
	await _bake_player_nav()
	if player.global_position.y > 12.0:
		await _climb("Mechanism/Ladder2", false)
	await _walk_to(Vector3(0.6, 7.7, 86.1), 1.5)
	await _skip_dialogue()
	var entry := level.get_node("Drain/EntryBody") as Node3D
	await _walk_to(entry.global_position, 2.5)
	player._set_stance(Player.Stance.CRAWL)
	await _wait(0.6)
	for i in 6:
		await _use("Drain/EntryBody")
	_skip_dialogue()
	var exit := level.get_node("Drain/ExitTrigger") as Node3D
	await _walk_to(_aim_point(exit), 0.6)
	var t := 0.0
	while not Quest.is_at(&"escape") and t < 30.0:
		_press(&"skip_line")
		await _wait(0.5)
		t += 0.5
	_check("crawled out (quest %s)" % Quest.current(), Quest.has_reached(&"escape") or Quest.is_at(&"crawl_out"))
	player._set_stance(Player.Stance.STAND)
	var light := level.get_node("Story/ExitLight") as Node3D
	await _walk_to(light.global_position, 1.0)
	await _wait(1.0)
	_expect(&"escape")
	_check("walked out into the ending", Game.is_over() and not Game.is_dead())
	# The walk-out takes over: the craftsman goes on toward the mouth by himself.
	var from := player.global_position
	await _wait(3.0)
	_check("walking out on his own (%.1f m)" % from.distance_to(player.global_position), from.distance_to(player.global_position) > 1.5)
	return true

## Act III the long way: the workers' shaft and its lift (too light alone,
## down with a stone in the ballast box), the ranks of clay soldiers, the
## pen's lever across the yard, and the stairs up to the mechanism's tunnel.
func _pits() -> bool:
	const LIFT := "UnderTheMountain/ShaftLift/"
	var lift := level.get_node(LIFT) as CounterweightLift
	var pen := level.get_node("UnderTheMountain/WorkersPen") as WorkersPen
	await _walk_to(Vector3(32.65, -8.6, -20.0), 1.5)
	var on := await _walk_to(Vector3(42.8, -8.6, -20.0), 0.6)
	await _wait(0.3)
	_check("on the lift (%s, load %.1f)" % [player.global_position.snapped(Vector3.ONE * 0.1), lift.load_weight()], on and lift.load_weight() >= 0.99)
	await _use(LIFT + "Platform/BrakeBody")
	await _wait(0.6)
	_check("alone he is too light: it stays", lift.moving == 0 and lift.level == 0.0)
	await _use(LIFT + "Platform/BallastBody", "hold")
	_check("a stone in the ballast box (%d)" % lift.ballast, lift.ballast == 1)
	await _use(LIFT + "Platform/BrakeBody")
	await _wait(0.6)
	_check("going down", lift.moving == 1)
	var t := 0.0
	while lift.level < 1.0 and t < 25.0:
		await _wait(0.5)
		t += 0.5
	await _wait(0.6)
	_check("down in the pits after %.1f s (at %s)" % [t, player.global_position.snapped(Vector3.ONE * 0.1)], lift.level >= 1.0 and absf(player.global_position.y + 26.0) < 0.7)
	await _skip_dialogue()
	# The guards' beats down here are on their navmesh, end to end.
	var guard_map := level.get_world_3d().navigation_map
	for route in ["Routes/PitsRing", "Routes/PitsYard"]:
		var points := (level.get_node(route) as PatrolRoute).points()
		for i in points.size():
			var a := points[i].global_position
			var b := points[(i + 1) % points.size()].global_position
			var path := NavigationServer3D.map_get_path(guard_map, a, b, true)
			var end := path[path.size() - 1] if not path.is_empty() else a
			_check("%s %d->%d walkable (ends %.1f m off)" % [route.get_file(), i, (i + 1) % points.size(), end.distance_to(b)], end.distance_to(b) < 1.0)
	await _bake_player_nav()
	# Among the ranks, standing still with no flame, he is one of them.
	var back := player.global_position
	player.global_position = Vector3(43.75, -26.0, 9.0)
	player.velocity = Vector3.ZERO
	await _wait(0.8)
	_check("in the ranks (%d)" % player.ranks, player.ranks > 0)
	_check("a lit lamp gives him away", player.has_lamp_lit() and not player.camouflaged())
	player.inventory.lamp().snuff()
	await _wait(0.3)
	_check("dark and still: one more statue (exposure %.2f)" % player.exposure, player.camouflaged())
	player.inventory.lamp().toggle()
	player.global_position = back
	await _wait(1.5)
	await _use("UnderTheMountain/PenLever/Lever/Body")
	_check("the pen's gate is up", pen.opened)
	_check("the apprentice is free", Game.get_flag(&"apprentice_freed"))
	await _skip_dialogue()
	await _walk_to(Vector3(33.0, -26.0, 38.0), 1.5)
	var up := await _walk_to(Vector3(4.8, -8.5, 35.0), 1.2)
	_check("up the stairs (%s)" % player.global_position.snapped(Vector3.ONE * 0.1), up and player.global_position.y > -9.0)
	await _walk_to(Vector3(0.3, -8.5, 35.0), 1.0)
	return player.global_position.y > -9.0

# --- Ladders ---------------------------------------------------------------------------------

## Walks to the near end of a ladder, grabs it and climbs to the other end.
func _climb(path: String, up: bool) -> void:
	var ladder := level.get_node_or_null(path) as Node3D
	if ladder == null:
		_check("ladder exists: " + path, false)
		return
	var bottom := (ladder.get_node("Bottom") as Node3D).global_position
	var top := (ladder.get_node("Top") as Node3D).global_position
	# From below, walk to the foot; from above, just head for the top: the walk
	# stops at the edge as soon as the ladder can be grabbed.
	if up:
		await _walk_to(bottom + ladder.global_basis.z * 1.2, 1.2)
	# Grab the rungs at chest height on this end, not the middle of a tall ladder.
	# Aim at the grab volume itself (it sits proud of the rungs), at chest
	# height from below or just above the top from above.
	var vol := (ladder.get_node("Body/Shape") as Node3D).global_position
	var grab := Vector3(vol.x, bottom.y + 1.2, vol.z) if up else Vector3(vol.x, top.y + 0.8, vol.z)
	await _use(path + "/Body", "press", grab)
	_check("on %s" % path.get_file(), player.on_ladder())
	if not player.on_ladder():
		return
	player._set_pitch(0.0)
	var action := &"move_forward" if up else &"move_backward"
	var t := 0.0
	Input.action_press(action)
	while player.on_ladder() and t < 30.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release(action)
	var end := top if up else bottom
	_check("climbed %s %s (%.1f m off)" % ["up" if up else "down", path.get_file(), absf(player.global_position.y - end.y)], not player.on_ladder() and absf(player.global_position.y - end.y) < 1.5)

# --- Walking ---------------------------------------------------------------------------------

## The level's navmesh is baked for guards (3 m tall). The player can crouch,
## so routes are planned on a navmesh baked here for a crouching body; the
## player ducks under low spots by itself.
func _bake_player_nav() -> void:
	if _nav_map.is_valid():
		NavigationServer3D.free_rid(_nav_map)
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 45.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, level)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	_nav_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_nav_map, 0.25)
	NavigationServer3D.map_set_cell_height(_nav_map, 0.25)
	NavigationServer3D.map_set_active(_nav_map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, _nav_map)
	NavigationServer3D.region_set_navigation_mesh(region, nm)
	var frames := 0
	while frames < 120 and NavigationServer3D.map_get_closest_point(_nav_map, player.global_position) == Vector3.ZERO:
		await get_tree().physics_frame
		frames += 1
	print("player navmesh: %d polygons (ready after %d frames)" % [nm.get_polygon_count(), frames])

## Follows the navmesh to `target` with the move keys. Stops early when
## `until` (a Callable returning bool) says so, like a player who stops once
## the thing is within reach. When stuck it hops and sidesteps, then re-paths.
func _walk_to(target: Vector3, stop_dist := 1.8, until := Callable()) -> bool:
	var map := _nav_map
	for attempt in 4:
		var from := NavigationServer3D.map_get_closest_point(map, player.global_position)
		var to := _floor_point(map, target)
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		if _verbose:
			var pts := []
			for q in path:
				pts.append(q.snapped(Vector3.ONE * 0.1))
			print("  path to %s: %s" % [target.snapped(Vector3.ONE * 0.1), pts])
		if path.is_empty():
			_check("nav path to %s" % target, false)
			return false
		var result := await _follow(path, target, stop_dist, until)
		if result != "stuck":
			Input.action_release(&"move_forward")
			await _wait(0.2)
			var off := player.global_position.distance_to(target)
			if result == "done" and off > stop_dist + 2.0:
				# The navmesh had no way there (it links neither drops nor tight
				# low spots the player can duck through): if the target is
				# near, walk straight at it and let the body find the way.
				var flat := Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
				if flat < 15.0 and absf(target.y - player.global_position.y) < 12.0 and attempt < 3:
					print("  heading straight for %s" % target.snapped(Vector3.ONE * 0.1))
					var t := 0.0
					while t < 6.0 and Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length() > stop_dist:
						_face_flat(target)
						Input.action_press(&"move_forward")
						await get_tree().physics_frame
						t += get_physics_process_delta_time()
					Input.action_release(&"move_forward")
					await _wait(0.5)
					continue
				print("  could not reach %s: ended at %s (%.1f m away; path end %s)" % [target.snapped(Vector3.ONE * 0.1), player.global_position.snapped(Vector3.ONE * 0.1), off, path[path.size() - 1].snapped(Vector3.ONE * 0.1)])
				return false
			return true
		print("  stuck at %s (hp %.1f dead %s locked %s floor %s stance %d), detouring" % [player.global_position.snapped(Vector3.ONE * 0.1), player.health, Game.is_dead(), player.controls_locked(), player.is_on_floor(), player.stance])
		await _detour(target, attempt)
	Input.action_release(&"move_forward")
	return false

## Something the navmesh doesn't know about (a seated NPC, a prop) is in the
## way: step around it — back off, then walk sideways toward whichever side is
## open — before asking for a new path.
func _detour(target: Vector3, attempt: int) -> void:
	if attempt == 0:
		# A lip or a bump the step-up can't take: hop over it first.
		_face_flat(target)
		Input.action_press(&"move_forward")
		_press(&"jump")
		await _wait(0.7)
		Input.action_release(&"move_forward")
		return
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

## Where on the navmesh to walk to for a target: the lowest navmesh point
## under it within a couple of metres. Table tops and chair seats are
## walkable islands in the navmesh, and snapping to one leads into furniture.
func _floor_point(map: RID, target: Vector3) -> Vector3:
	var best := NavigationServer3D.map_get_closest_point(map, target)
	if best.distance_to(target) < 1.2:
		return best
	for drop in [1.0, 2.0, 3.0]:
		var p := NavigationServer3D.map_get_closest_point(map, target + Vector3.DOWN * drop)
		var flat := Vector2(p.x - target.x, p.z - target.z).length()
		if p.y < best.y - 0.3 and target.y - p.y < 3.2 and flat < 2.5:
			best = p
	return best

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

func _use(path: String, how := "press", aim_at := Vector3.INF) -> void:
	var body := level.get_node_or_null(path) as Node3D
	if body == null:
		_check("exists: " + path, false)
		return
	var aim := _aim_point(body) if aim_at == Vector3.INF else aim_at
	var reachable := func() -> bool: return _can_target(body, aim)
	if _verbose:
		var eye := player.camera.global_position
		var q := PhysicsRayQueryParameters3D.create(eye, aim + (aim - eye).normalized() * 0.5, player.interactor.collision_mask)
		q.exclude = [player.get_rid()]
		var h := player.get_world_3d().direct_space_state.intersect_ray(q)
		print("  use %s from %s (reachable now: %s; ray hits %s at %.1f m)" % [path, player.global_position.snapped(Vector3.ONE * 0.1), _can_target(body, aim), level.get_path_to(h.collider) if not h.is_empty() else "nothing", eye.distance_to(h.position) if not h.is_empty() else 0.0])
	var flat := Vector2(aim.x - player.global_position.x, aim.z - player.global_position.z).length()
	if flat < 4.5:
		# Close already: step straight toward it, like leaning over an edge.
		await _step_toward(aim, reachable)
	else:
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

func _step_toward(aim: Vector3, until: Callable) -> void:
	var t := 0.0
	while t < 1.5 and not until.call():
		_face_flat(aim)
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var flat := Vector2(aim.x - player.global_position.x, aim.z - player.global_position.z).length()
		if flat < 0.9:
			break
	Input.action_release(&"move_forward")
	await _wait(0.15)

## Within reach and in plain sight from the eyes (what the interaction ray sees).
func _can_target(body: Node3D, aim: Vector3) -> bool:
	var eye := player.camera.global_position
	if eye.distance_to(aim) > 3.5:
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
