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
	await _spare_tools()
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
	# The sit clip's feet are 0.49 above his origin, his hips 1.45: feet on
	# the room's floor, seat a hand under his hips, a stool there to take him.
	var space := level.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(liang.global_position.x, 0.7, liang.global_position.z), Vector3(liang.global_position.x, -2.0, liang.global_position.z), 1))
	var feet_y := liang.global_position.y + 0.49
	_check("Liang's feet on the floor (feet %.2f, floor %.2f)" % [feet_y, floor_hit.position.y], absf(feet_y - floor_hit.position.y) < 0.04)
	var seat := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(liang.global_position.x + 0.2, liang.global_position.y + 1.45, liang.global_position.z), Vector3(liang.global_position.x + 0.2, liang.global_position.y, liang.global_position.z), 1))
	_check("a stool seat right under his hips (%.2f below)" % (liang.global_position.y + 1.45 - seat.position.y if not seat.is_empty() else 9.9), not seat.is_empty() and absf(liang.global_position.y + 1.45 - seat.position.y - 0.12) < 0.08)
	# His room's door: walking in at the south end already finds him.
	var t := level.get_node("Story/LiangRoomEnter") as Area3D
	var box := (t.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	var door := t.to_local(Vector3(42.0, 0.5, -3.0))
	var inside := t.to_local(Vector3(37.8, 0.5, -26.2))
	var far := t.to_local(Vector3(55.0, 0.5, -50.0))
	_check("the room's trigger takes in its south door, the middle and the far end", absf(door.x) < box.size.x * 0.5 and absf(door.z) < box.size.z * 0.5 and absf(inside.z) < box.size.z * 0.5 and absf(far.z) < box.size.z * 0.5 and absf(far.x) < box.size.x * 0.5)

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
	await _wait(1.0)
	_check("and no piece of it is left standing in the way", not rock.visible)

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
	_check("and it raised no alert in him (awareness %.2f)" % near.awareness, near.awareness < 0.35)
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

## No tool is the only one: each place that needs them has a set lying on
## the floor, takeable once the sealing has begun, and not before.
func _spare_tools() -> void:
	var holder := level.get_node("SpareTools")
	var count := {&"chisel": 0, &"hammer": 0, &"wedge": 0}
	for p in holder.get_children():
		if p is Pickup:
			count[(p as Pickup).item_id] += 1
	_check("spare tools: %d each of chisel, hammer, wedge" % count[&"hammer"], count[&"chisel"] >= 4 and count[&"hammer"] >= 4 and count[&"wedge"] >= 4)
	# On the benches, not the floor: each a good way up from the ground.
	var space := level.get_world_3d().direct_space_state
	var on_floor := 0
	for p in holder.get_children():
		if p is Pickup:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create((p as Node3D).global_position + Vector3.DOWN * 0.15, (p as Node3D).global_position + Vector3.DOWN * 3.0, 1))
			if not hit.is_empty() and (p as Node3D).global_position.y - hit.position.y < 0.6:
				on_floor += 1
	_check("the spare tools lie on benches, none on the floor (%d on it)" % on_floor, on_floor == 0)
	var shards := level.get_node("Shards").get_child_count()
	_check("shards of porcelain lie about the floors (%d)" % shards, shards >= 10)
	var set_in_workshop := holder.get_node("Spare_Masons_hammer") as Pickup
	var usable := set_in_workshop.get_node("Usable") as Usable
	# The hammer is lost: another can be taken (but not while you have one).
	for id in [&"hammer"]:
		player.inventory.remove(id, 99)
	_check("lost your hammer: a spare can be taken", usable.can_use(player))
	player.inventory.add(&"hammer")
	_check("with one in hand it can't be taken twice", not usable.can_use(player))
	player.inventory.remove(&"hammer", 99)

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
