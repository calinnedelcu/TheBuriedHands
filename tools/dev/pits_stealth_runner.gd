extends Node
## Dev test for stealth in the army pits: the lift's creaking brings the guard
## on the hall's ring to see what moved in the shaft; a man standing still
## with no flame among the clay soldiers stays one more figure to a guard a
## few steps away, while the same man with his lamp lit, or standing out in
## the corridor, is soon noticed. (A torch held close lights him up: that
## guard grows suspicious, slowly.)
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/pits_stealth_runner.gd

var player: Player
var level: Node
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	level = Game.level
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(0.5)
	Dialogue.stop()
	Quest.start_at(&"reach_mechanism")
	Game.set_flag(&"guards_hostile")
	player.inventory.take_lamp(100.0, true)
	var ring := level.get_node("Guards/PitGuardRing") as Guard
	var yard := level.get_node("Guards/PitGuardYard") as Guard
	yard.set_scripted(true)

	# The lift creaks on its way down; the guard on the ring, by the door to
	# the shaft, hears it.
	var lift := level.get_node("UnderTheMountain/ShaftLift") as CounterweightLift
	_hold_still(ring, Vector3(44.0, -26.0, -9.5), Vector3(44.0, -26.0, 0.0))
	player.global_position = Vector3(42.8, -8.4, -20.0)
	player.velocity = Vector3.ZERO
	player.inventory.lamp().snuff()
	await _wait(0.6)
	lift.ballast_hold_done(player)
	lift.brake_use(player)
	_check("the lift goes down with a stone", lift.moving == 1)
	var t := 0.0
	while t < 14.0 and ring.state == Guard.State.PATROL:
		await _wait(0.25)
		t += 0.25
	var stimulus: Vector3 = ring.get(&"_stimulus")
	_check("the ring guard heard it after %.1f s (%s)" % [t, Guard.State.keys()[ring.state]], ring.state != Guard.State.PATROL)
	_check("and turns to the foot of the shaft (%s)" % stimulus.snapped(Vector3.ONE * 0.1), Vector2(stimulus.x - 42.8, stimulus.z + 20.0).length() < 2.0 and stimulus.y < -24.0)
	# Out of the way, torch and all.
	ring.set_scripted(true)
	ring.global_position = Vector3(68.0, -26.0, 27.0)

	# Among the ranks, still and dark: a guard four paces off, looking at him.
	var spot := Vector3(43.75, -26.0, 9.0)
	player.global_position = spot
	player.velocity = Vector3.ZERO
	_hold_still(yard, Vector3(43.75, -26.0, 12.6), spot)
	await _wait(0.4)
	_check("in the ranks (%d), still, in the dark" % player.ranks, player.ranks > 0 and player.camouflaged())
	var peak := await _watch(yard, 4.0)
	_check("one more statue: the guard never wonders (awareness up to %.2f)" % peak, peak < 0.2 and yard.state == Guard.State.PATROL)
	# The lamp gives him away.
	player.inventory.lamp().toggle()
	peak = await _watch(yard, 4.0, 0.5)
	_check("lamp lit: noticed (awareness %.2f, %s)" % [peak, Guard.State.keys()[yard.state]], peak >= 0.5)
	player.inventory.lamp().snuff()
	# The same four paces out in the corridor, no soldiers round him.
	yard.set_scripted(true)
	player.global_position = Vector3(52.0, -26.0, -9.0)
	player.velocity = Vector3.ZERO
	_hold_still(yard, Vector3(52.0, -26.0, -5.4), player.global_position)
	await _wait(0.4)
	peak = await _watch(yard, 4.0, 0.2)
	_check("out of the ranks he is a shape in the dark (awareness %.2f)" % peak, player.ranks == 0 and peak >= 0.2)
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit()

## A guard stands at `at`, looking toward `look`, perceiving but not moving.
func _hold_still(guard: Guard, at: Vector3, look: Vector3) -> void:
	guard.walk_speed = 0.0
	guard.run_speed = 0.0
	guard.turn_speed = 0.0
	guard.global_position = at
	guard.look_at(Vector3(look.x, at.y, look.z), Vector3.UP)
	guard.set(&"_desired_yaw", guard.rotation.y)
	guard.awareness = 0.0
	guard.call(&"_set_state", Guard.State.PATROL)

## The guard's highest awareness over `seconds` (stops early past `enough`).
func _watch(guard: Guard, seconds: float, enough := INF) -> float:
	var peak := 0.0
	var t := 0.0
	while t < seconds and peak < enough:
		peak = maxf(peak, guard.awareness)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return peak

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
