extends Node
## Dev test: plays the whole main quest by driving interactions directly
## (teleport next to things, use them, walk into triggers) and checks that
## every step advances. Catches broken wiring, not feel.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/quest_bot_runner.gd

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
	_expect(&"talk_apprentice")

	await _use("Rooms/01_TerracottaWorkshop/Apprentice/TalkBody/Usable")
	await _wait_dialogue()
	_expect(&"take_lamp")

	await _tap("Rooms/01_TerracottaWorkshop/LampStand_W/Body/Usable")
	_expect(&"fetch_slip")
	_check("lamp in hand", player.inventory.lamp() != null)

	await _use("Rooms/01_TerracottaWorkshop/SlipBowl/Usable")
	_expect(&"place_bowl")

	await _use("Rooms/01_TerracottaWorkshop/ClayStatue/Body/Usable")
	_expect(&"apply_slip")

	await _hold("Rooms/01_TerracottaWorkshop/ClayStatue/Body/Usable")
	_expect(&"find_chisel")

	await _use("Rooms/01_TerracottaWorkshop/FallenChisel/Usable")
	_expect(&"finish_statue")

	for i in 3:
		await _use("Rooms/01_TerracottaWorkshop/ClayStatue/Body/Usable")
	_expect(&"sealing")
	# The sealing scene plays out by itself (gate, guards' talk, they leave).
	var t := 0.0
	while not Quest.is_at(&"answer_apprentice") and t < 120.0:
		Dialogue.skip_line()
		await _wait(0.5)
		t += 0.5
	_expect(&"answer_apprentice")
	_check("guards hostile after the sealing", Game.get_flag(&"guards_hostile"))

	# Give the apprentice the lamp (choice 0).
	Dialogue.choice_requested.connect(func(_o): Dialogue.choose_option.call_deferred(0), CONNECT_ONE_SHOT)
	await _use("Rooms/01_TerracottaWorkshop/Apprentice/TalkBody/Usable")
	t = 0.0
	while not Quest.is_at(&"find_liang") and t < 60.0:
		Dialogue.skip_line()
		await _wait(0.4)
		t += 0.4
	_expect(&"find_liang")
	_check("gave lamp flag", Game.get_flag(&"gave_lamp"))
	_check("lamp gone from hand", player.inventory.lamp() == null)
	await _tap("Rooms/01_TerracottaWorkshop/LampStand_E2/Body/Usable")
	_check("took a second lamp", player.inventory.lamp() != null)

	# Make the walk to Liang safe for the bot.
	Game.set_flag(&"guards_hostile", false)
	await _use("Register/Usable")
	_check("evidence flag", Game.get_flag(&"has_evidence"))
	await _enter("Story/LiangRoomEnter")
	_expect(&"talk_liang")
	var apprentice := level.get_node("Rooms/01_TerracottaWorkshop/Apprentice") as Node3D
	_check("Wei's men took the apprentice from the kiln", Game.get_flag(&"apprentice_taken") and not apprentice.visible)
	await _use("Liang/TalkBody/Usable")
	await _wait_dialogue()
	# He came without Wei's half: Liang says where it lies; the gate's way
	# needs it, so back for it from the desk.
	_expect(&"descend")
	await _use("WeiTally/Usable")
	await _wait(0.3)
	_check("Wei's half in hand", player.inventory.has_item(&"tally_wei"))

	# Tools, stone, and down to the pits.
	for p in level.find_children("Tool_*", "", false, false):
		await _use(String(level.get_path_to(p)) + "/Usable")
	_check("has wedge + hammer", player.inventory.has_item(&"wedge") and player.inventory.has_item(&"hammer"))
	for i in 4:
		await _hold("ShaftStone/Body/Usable")
	_check("stone broken", level.get_node("ShaftStone").get("broken"))
	await _enter("UnderTheMountain/PitsReached")
	_expect(&"past_wall")
	# The commander's half, then the whole tiger in the inner gate.
	await _use("UnderTheMountain/CommanderPost/PitTally/Usable")
	await _wait(0.3)
	_check("the commander's half in hand", player.inventory.has_item(&"tally_pit"))
	await _use("UnderTheMountain/InnerGate/Sockets/Usable")
	await _wait(0.3)
	_check("the inner gate opened", (level.get_node("UnderTheMountain/InnerGate") as TallyGate).opened)
	_expect(&"reach_mechanism")

	await _enter("Story/MechanismEnter")
	_expect(&"inspect_balance")
	await _use("Mechanism/Counterweight/Body/Usable")
	await _wait_dialogue()
	_expect(&"get_vase")
	print("  slots before jar: ", player.inventory.slots, " keys: ", player.inventory.key_items)
	await _use("Mechanism/Jar/Usable")
	await _use("Mechanism/Cloth/Usable")
	await _wait(0.2)
	print("  slots after jar: ", player.inventory.slots, " keys: ", player.inventory.key_items)
	_expect(&"fill_vase")
	await _hold("MercuryHall/FillPoint1/UseBody/Usable")
	_expect(&"pour_mercury")
	await _hold("Mechanism/Counterweight/Body/Usable")
	await _wait(6.0)
	_expect(&"find_drain")

	# The drain.
	player.global_position = (level.get_node("Drain/EntryBody") as Node3D).global_position + Vector3(2, 0, 0)
	player._set_stance(Player.Stance.CRAWL, true)
	await _wait(0.6)
	for i in 6:
		await _use("Drain/EntryBody/Usable")
	_expect(&"crawl_out")
	await _enter("Drain/ExitTrigger")
	t = 0.0
	while not Quest.is_at(&"escape") and t < 20.0:
		Dialogue.skip_line()
		await _wait(0.3)
		t += 0.3
	_expect(&"escape")
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit()

# --- Helpers -----------------------------------------------------------------------------

func _usable(path: String) -> Usable:
	var u := level.get_node_or_null(path) as Usable
	if u == null:
		_check("node exists: " + path, false)
	return u

func _near(u: Usable) -> void:
	var body := u.get_node(u.body_path) as Node3D
	var to := body.global_position
	player.global_position = to + Vector3(1.2, 0.0, 1.2)
	player.velocity = Vector3.ZERO
	await _wait(0.15)

func _use(path: String) -> void:
	var u := _usable(path)
	if u == null:
		return
	await _near(u)
	if not u.can_use(player):
		_check("can use %s (prompt '%s')" % [path, u.get_prompt(player)], false)
		return
	u.use(player)
	await _wait(0.3)

func _tap(path: String) -> void:
	var u := _usable(path)
	if u == null:
		return
	await _near(u)
	u.tap(player)
	await _wait(0.3)

func _hold(path: String) -> void:
	var u := _usable(path)
	if u == null:
		return
	await _near(u)
	if not u.can_use(player):
		_check("can hold %s (prompt '%s')" % [path, u.get_prompt(player)], false)
		return
	for i in 10:
		u.hold_tick(player, (i + 1) / 10.0)
	u.complete_hold(player)
	await _wait(0.3)

func _enter(path: String) -> void:
	var area := level.get_node_or_null(path) as Area3D
	if area == null:
		_check("trigger exists: " + path, false)
		return
	var at := area.global_position
	for c in area.get_children():
		if c is CollisionShape3D:
			at = (c as CollisionShape3D).global_position
			break
	player.global_position = at - Vector3.UP * 0.4
	await _wait(0.4)

func _wait_dialogue() -> void:
	var t := 0.0
	while Dialogue.is_busy() and t < 90.0:
		Dialogue.skip_line()
		await _wait(0.3)
		t += 0.3

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _expect(step: StringName) -> void:
	_check("quest at %s (actual %s)" % [step, Quest.current()], Quest.is_at(step))

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
