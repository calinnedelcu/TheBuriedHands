extends Node
## Dev test: Act V's last door (WeiLastDoor), one way it can go per run.
## Wei and his men are at the door from the start of the act, the Wei of the
## archives' desk put away; the craftsman walks up the walkway and Wei
## speaks; then, by --way=:
##   register  Wei reads his own name; his men leave, then he does; the door
##             is left clear.
##   tiger     thrown into the mercury, it floats; the three of them out on
##             the causeway after it, the door left clear.
##   run       the men give chase, lose him and keep watch, the door no
##             post of theirs; Wei watches from the causeway.
## Each ends with the epilogue's word on Wei. He comes down the west walkway
## (the short way round), or with --from=east along the south one, where
## they pass him in the narrow strip.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/wei_door_runner.gd --way=register|tiger|run [--from=east]

## The door's opening, between its jambs.
const DOOR := Vector3(-15.75, 7.55, 130.6)
const ENDINGS := {"register": "turned", "tiger": "tricked", "run": "fled"}
const CHOICES := {"register": "CHOICE_WEI_REGISTER", "tiger": "CHOICE_WEI_TIGER", "run": "CHOICE_WEI_RUN"}

var failures := 0
var level: Node3D
var player: Player
var door: WeiLastDoor
var wei: Guard
var men: Array[Guard] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var way := "register"
	var from := "west"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--way="):
			way = arg.substr(6)
		elif arg.begins_with("--from="):
			from = arg.substr(7)
	Game.new_game()
	await Game.level_ready
	level = Game.level as Node3D
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(0.5)
	Dialogue.stop()
	# Act V as the counterweight leaves it, with what this way needs in hand.
	Game.set_flag(&"guards_hostile")
	Game.advance_sealing(1)
	Game.advance_sealing(2)
	player.inventory.take_lamp(100.0, true)
	if way == "register":
		Game.set_flag(&"has_evidence")
		player.inventory.add(&"register")
	elif way == "tiger":
		Game.set_flag(&"has_tally_wei")
		player.inventory.add(&"tally_wei")
	Quest.start_at(&"find_drain")
	level.get_node("Mechanism/Counterweight").call(&"persist_load", {"tipped": true})
	await _wait(0.6)
	door = level.get_node("WeiLastDoor") as WeiLastDoor
	wei = level.get_node("Guards/WeiLast") as Guard
	men = [level.get_node("Guards/WeiLastManA") as Guard, level.get_node("Guards/WeiLastManB") as Guard]
	_check("Wei at the last door", wei.visible and _off(wei, "Post") < 0.8)
	_check("his men at the wall they've begun", men[0].visible and men[1].visible and _off(men[0], "Work0") < 0.8 and _off(men[1], "Work1") < 0.8)
	_check("the Wei of the desk put away", not (level.get_node("Guards/Wei") as Node3D).visible)
	var hand := wei.find_child("HeldHand", true, false) as Node3D
	_check("his register in his hand unless it was taken", hand != null and hand.visible == (way != "register"))
	# Up the walkway to the door: Wei speaks, and the answers are offered.
	var offered: Array[String] = []
	Dialogue.choice_requested.connect(func(texts: PackedStringArray) -> void:
		for t in texts:
			offered.append(t)
		Dialogue.choose_option.call_deferred(maxi(0, Array(texts).find(tr(CHOICES[way])))), CONNECT_ONE_SHOT)
	if from == "east":
		player.global_position = Vector3(-4.0, 7.6, 130.0)
		await _wait(0.4)
		player.global_position = Vector3(-9.0, 7.6, 130.0)
	else:
		player.global_position = Vector3(-19.6, 7.6, 119.0)
		await _wait(0.4)
		player.global_position = Vector3(-19.6, 7.6, 124.3)
	await _wait(0.4)
	_check("he walked into Wei's sight", door.met)
	_check("his controls held while Wei speaks", player.controls_locked())
	var t := 0.0
	while offered.is_empty() and t < 30.0:
		Dialogue.skip_line()
		await _wait(0.3)
		t += 0.3
	print("  offered: ", offered)
	_check("offered the way '%s'" % way, offered.has(tr(CHOICES[way])))
	_check("running is always offered", offered.has(tr("CHOICE_WEI_RUN")))
	_check("nothing offered he doesn't have", offered.size() == 1 + (1 if way == "register" else 0) + (1 if way == "tiger" else 0))
	t = 0.0
	while player.controls_locked() and t < 30.0:
		Dialogue.skip_line()
		await _wait(0.3)
		t += 0.3
	_check("controls back after it", not player.controls_locked())
	_check("it went '%s' (%s)" % [ENDINGS[way], door.outcome], door.outcome == StringName(ENDINGS[way]) and Game.get_flag(StringName("wei_" + ENDINGS[way])))
	match way:
		"register":
			await _register()
		"tiger":
			await _tiger()
		"run":
			await _run_for_it()
	_check("the epilogue's word on Wei: %s" % Game.epilogue().get("wei"), Game.epilogue().get("wei") == ENDINGS[way])
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

## His men go up the walkway and out of sight; then he does.
func _register() -> void:
	_check("the register handed back", player.inventory.has_item(&"register") and Game.get_flag(&"has_evidence"))
	var t := 0.0
	while (men[0].visible or men[1].visible) and t < 40.0:
		await _wait(0.5)
		t += 0.5
	_check("his men gone up (after %.1f s)" % t, not men[0].visible and not men[1].visible)
	t = 0.0
	while wei.visible and t < 40.0:
		await _wait(0.5)
		t += 0.5
	_check("and Wei after them (after %.1f s)" % t, not wei.visible)
	_check("the door left clear", _door_clear())

## Out of his hand and onto the mercury; the three of them out on the
## causeway over it.
func _tiger() -> void:
	_check("the tiger gone from his hand", not player.inventory.has_item(&"tally_wei"))
	await _wait(2.0)
	var tiger := door.get_node_or_null("Tiger") as Node3D
	_check("it floats on the mercury", tiger != null and tiger.global_position.distance_to(door.get_node("Float").global_position) < 0.3)
	var t := 0.0
	while t < 20.0 and (_off(wei, "Edge0") > 1.5 or _off(men[0], "Edge1") > 1.5 or _off(men[1], "Edge2") > 1.5):
		await _wait(0.5)
		t += 0.5
	_check("Wei and his men out on the causeway after it (%.1f, %.1f, %.1f m off)" % [_off(wei, "Edge0"), _off(men[0], "Edge1"), _off(men[1], "Edge2")], _off(wei, "Edge0") < 1.5 and _off(men[0], "Edge1") < 1.5 and _off(men[1], "Edge2") < 1.5)
	_check("the door left clear", _door_clear())

## The men give chase; out of their sight they lose him, and keep watch;
## Wei watches from the causeway.
func _run_for_it() -> void:
	_check("the men give chase", men[0].state == Guard.State.CHASE and men[1].state == Guard.State.CHASE)
	var rings: Array[PatrolRoute] = []
	for i in 2:
		rings.append(level.get_node("Routes/LastDoor%s" % ["Strip", "Causeway"][i]) as PatrolRoute)
		_check("man %d keeps watch after on %s" % [i, rings[i].name], men[i].get(&"_route") == rings[i])
	# Gone: far off, round the corner and up in the mechanism's chamber.
	player.global_position = Vector3(0.5, 7.7, 44.5)
	var t := 0.0
	while t < 90.0 and not (men[0].state == Guard.State.PATROL and men[1].state == Guard.State.PATROL):
		await _wait(0.5)
		t += 0.5
	_check("they lost him and keep watch (after %.1f s)" % t, men[0].state == Guard.State.PATROL and men[1].state == Guard.State.PATROL)
	_check("Wei watching from the causeway (%.1f m off)" % _off(wei, "Watch"), _off(wei, "Watch") < 1.5)
	for ring in rings:
		var nearest := INF
		for m in ring.points():
			nearest = minf(nearest, m.global_position.distance_to(DOOR))
		_check("%s makes no post of the door (nearest %.1f m)" % [ring.name, nearest], nearest > 4.0)
	# Their beats walk end to end on the navmesh.
	var map := level.get_world_3d().navigation_map
	for ring in rings:
		var points := ring.points()
		for i in points.size():
			var a := points[i].global_position
			var b := points[(i + 1) % points.size()].global_position
			var path := NavigationServer3D.map_get_path(map, a, b, true)
			var end := path[path.size() - 1] if not path.is_empty() else a
			_check("%s %d->%d walkable (ends %.1f m off)" % [ring.name, i, (i + 1) % points.size(), end.distance_to(b)], end.distance_to(b) < 1.0)

func _off(g: Guard, mark: String) -> float:
	var at := (door.get_node(mark) as Node3D).global_position
	return Vector2(g.global_position.x - at.x, g.global_position.z - at.z).length()

func _door_clear() -> bool:
	for g in [wei] + men:
		if (g as Guard).visible and (g as Guard).global_position.distance_to(DOOR) < 2.5:
			return false
	return true

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
