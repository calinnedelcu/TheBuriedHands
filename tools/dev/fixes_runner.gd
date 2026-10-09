extends Node
## Dev test: the playtest fixes of 8 October, in the order the story meets them.
##   hint     an item ahead of the story says what to do first (the bowl,
##            before the lamp).
##   lamp     the first lamp is taken with a long press too (nothing to fill).
##   door     Act I: the soldier in the workshop's south door keeps you in,
##            until the sealing.
##   kneel    after the sealing the craftsmen kneel on the floor, and the
##            fallen lie on it (not at hip height in the air).
##   liang    Liang sits on his stool, his feet on the floor.
##   stone    the shaft stone gives on the fourth blow, not the first.
##   thrown   a thrown shard: the nearest guard who heard it goes to look.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/fixes_runner.gd

const WS := "Rooms/01_TerracottaWorkshop/"

var failures := 0
var level: Node3D
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.new_game()
	Game.set_flag(&"intro_done")
	await Game.level_ready
	level = Game.level as Node3D
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(0.5)
	Dialogue.stop()
	Quest.start_at(&"take_lamp")
	await _hint()
	await _lamp()
	await _door()
	await _kneel()
	_liang()
	await _stone()
	await _thrown()
	_lift_box()
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

## Pressed and held half a second, as a hand does: the lamp comes.
func _lamp() -> void:
	var target := await _aim_at(WS + "LampStand_W")
	_check("aiming at the first lamp", target != null and target.get_parent().get_parent().name == &"LampStand_W")
	_check("no hold asked of an empty hand", target != null and not target.is_hold_for(player))
	_press(true)
	await _wait(0.5)
	_press(false)
	await _wait(0.3)
	_check("long press: the lamp is in hand", player.inventory.lamp() != null)
	_check("and the story moved on", Quest.has_reached(&"fetch_slip"))

## The bowl isn't for now: it says what is (the lamp).
func _hint() -> void:
	var target := await _aim_at(WS + "SlipBowl")
	var prompt := target.get_prompt(player) if target != null else ""
	var first := tr("PROMPT_FIRST").split("%")[0]
	_check("the bowl ahead of its step is seen (prompt '%s')" % prompt, target != null and target.get_parent().name == &"SlipBowl" and prompt.begins_with(first))
	_check("but can't be taken yet", target != null and not target.can_use(player))

## Up to the south door before the sealing: sent back, and no way through.
func _door() -> void:
	var watch := level.get_node("Story/ExitWatch") as ExitWatch
	var blocker := watch.get_node("Blocker") as Node3D
	# Beside the soldier, not into him: it's the doorway that must hold.
	var lane := blocker.global_position.x + 1.8
	player.global_position = Vector3(lane, 0.4, blocker.global_position.z - 3.0)
	await _wait(0.6)
	player.move_and_collide(Vector3(0.0, 0.0, 6.0))
	_check("the doorway holds before the sealing (z %.2f)" % player.global_position.z, player.global_position.z < blocker.global_position.z)
	Quest.start_at(&"find_liang")
	await _wait(0.3)
	player.global_position = Vector3(lane, 0.4, blocker.global_position.z - 3.0)
	await get_tree().physics_frame
	player.move_and_collide(Vector3(0.0, 0.0, 6.0))
	_check("open after it (z %.2f)" % player.global_position.z, player.global_position.z > blocker.global_position.z + 1.0)

## The sealing brings them down: on the floor, kneeling or lying.
func _kneel() -> void:
	Game.advance_sealing(1)
	await _wait(9.0)
	var worst := 0.0
	var lowered := 0
	var count := 0
	for w in level.find_children("*", "Node3D", true, false):
		if not (w is Worker):
			continue
		var model := w.get_node_or_null(^"Model") as Node3D
		var skeletons := w.find_children("*", "Skeleton3D", true, false)
		if model == null or skeletons.is_empty():
			continue
		var clip := ""
		var ap := w.find_children("*", "AnimationPlayer", true, false)
		if not ap.is_empty():
			clip = (ap[0] as AnimationPlayer).assigned_animation
		if clip not in ["kneel", "collapse"]:
			continue
		count += 1
		var sk := skeletons[0] as Skeleton3D
		var lowest := INF
		for b in sk.get_bone_count():
			if sk.get_bone_parent(b) >= 0:
				lowest = minf(lowest, (sk.global_transform * sk.get_bone_global_pose(b)).origin.y)
		var off := lowest - (w as Node3D).global_position.y
		worst = maxf(worst, absf(off - Worker.GROUND_CLEARANCE))
		if model.position.y < -0.05:
			lowered += 1
	_check("%d kneeling or fallen, all lowered onto the floor (%d)" % [count, lowered], count > 0 and lowered == count)
	_check("the lowest bone of each at the floor (worst off by %.2f m)" % worst, worst < 0.08)

func _liang() -> void:
	var liang := level.get_node("Liang") as Node3D
	_check("Liang's feet on the floor (y %.2f)" % liang.global_position.y, absf(liang.global_position.y - (-0.6)) < 0.05)

## Four blows: the stone stays put through three, gives on the fourth.
func _stone() -> void:
	var stone := level.get_node("ShaftStone")
	var rock := stone.get("_rock") as Node3D
	var at := rock.position
	for id in [&"wedge", &"hammer"]:
		player.inventory.add(id)
	var u := stone.get_node("Body/Usable") as Usable
	player.global_position = Vector3(46.0, 0.5, -44.0)
	for i in 4:
		for k in 10:
			u.hold_tick(player, (k + 1) / 10.0)
		u.complete_hold(player)
		await _wait(0.3)
		if i < 3:
			_check("blow %d: still whole, still where it was" % (i + 1), not stone.get("broken") and rock.position.distance_to(at) < 0.01)
	_check("the fourth blow splits it", stone.get("broken"))

## A shard thrown past a guard: he goes to see what fell; the farther one
## who heard it only turns.
func _thrown() -> void:
	Game.set_flag(&"guards_hostile")
	var guards: Array[Guard] = []
	for g in Stealth.guards():
		if is_instance_valid(g) and (g as Guard).is_hostile():
			guards.append(g as Guard)
	# Out of everyone's sight, high above the workshop roof, and kept there.
	player.set_physics_process(false)
	player.global_position = Vector3(-55.0, 40.0, -18.0)
	var near := level.get_node("Guards/ArchiveGuard1") as Guard
	await _wait(0.5)
	var spot := near.global_position + near.global_basis.x * 6.0
	var shard := RigidBody3D.new()
	shard.set_script(preload("res://Scripts/items/thrown_item.gd"))
	shard.set(&"item_id", &"ceramic")
	level.add_child(shard)
	shard.global_position = spot + Vector3.UP * 1.5
	await _wait(1.5)
	_check("the nearest guard goes to look (state %s)" % Guard.State.keys()[near.state], near.state == Guard.State.INVESTIGATE or near.state == Guard.State.SEARCH)
	var goers := 0
	for g in guards:
		if g.state == Guard.State.INVESTIGATE:
			goers += 1
	_check("only one goes (%d)" % goers, goers <= 1)
	var reached := false
	for i in 40:
		await _wait(0.5)
		if near.global_position.distance_to(spot) < 2.5:
			reached = true
			break
	_check("he gets to the spot", reached)

## The lift's ballast box: full, a long press takes a stone off at once (a
## hold has nothing to add); with room, holding adds.
func _lift_box() -> void:
	var lift := level.get_node("UnderTheMountain/ShaftLift") as CounterweightLift
	var usable := lift.get_node("Platform/BallastBody/Usable") as Usable
	lift.ballast = CounterweightLift.MAX_BALLAST
	_check("lift box full: a press acts at once (no hold)", not usable.is_hold_for(player))
	lift.ballast = 1
	_check("with room: holding adds a stone", usable.is_hold_for(player))

## Turns the player to look straight at `path` from a step away; the usable
## the aim settles on.
func _aim_at(path: String) -> Usable:
	var n := level.get_node(path) as Node3D
	var at := n.global_position
	player.global_position = at + Vector3(1.0, 0.0, 0.3).normalized() * 1.2 + Vector3.DOWN * 0.9
	player.velocity = Vector3.ZERO
	player.look_at_point(at + Vector3.UP * 0.1, 0.01)
	for i in 20:
		await get_tree().physics_frame
	return player.interactor.target

func _press(down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = down
	if down:
		Input.action_press(&"interact")
	else:
		Input.action_release(&"interact")
	Input.parse_input_event(ev)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
