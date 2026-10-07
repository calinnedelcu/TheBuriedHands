extends Node
## Dev test: two copies of the game play Act I together over the network,
## one hosting (the master), one joined (the apprentice), each driving its own
## player and checking that the other side sees the same world: uses go
## through the host and run on both, inventories and the quest stay in step,
## guards move on the apprentice's machine, his noises reach the host's
## guards, a death ends the run for both and the retry brings both back.
## Run the two at once:
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/coop_bot_runner.gd --role=host
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/coop_bot_runner.gd --role=client

const WS := "Rooms/01_TerracottaWorkshop/"

var role := "host"
var me: Player
var level: Node
var failures := 0
var _noises_from_apprentice := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.substr(7)
	_run.call_deferred()

func _run() -> void:
	if role == "host":
		await _host()
	else:
		await _client()
	print("[%s] RESULT: %d failure(s)" % [role, failures])
	get_tree().quit(1 if failures > 0 else 0)

# --- The master ---------------------------------------------------------------------------

func _host() -> void:
	_check("hosting", Net.host())
	if not await _until(func(): return Net.has_partner(), 40.0):
		_check("apprentice joined", false)
		return
	_log("apprentice joined")
	Net.begin()
	await Game.level_ready
	await _settle_level()
	_check("master is local", me.name == Net.MASTER_BODY and me.is_local)
	var apprentice := Net.body(Net.APPRENTICE_BODY)
	_check("apprentice body on the host is a puppet", apprentice != null and not apprentice.is_local)
	_check("the apprentice at his bench is gone", level.get_node_or_null(WS + "Apprentice") == null)
	Stealth.noise_made.connect(_on_noise)
	_expect(&"talk_apprentice")

	# The master talks to the apprentice (the second player).
	await _wait(1.0)
	await _use("Apprentice/UseBody/Usable", &"use")
	await _wait_dialogue()
	_expect(&"take_lamp")

	# The apprentice takes a lamp, fetches the slip and sets the bowl.
	_check("apprentice took a lamp (seen on the host)", await _until(func(): return Quest.has_reached(&"fetch_slip"), 30.0))
	_check("the apprentice's puppet holds the lamp", apprentice.inventory.lamp() != null)
	await _use(WS + "LampStand_E/Body/Usable", &"tap")
	_check("master has his own lamp", me.inventory.lamp() != null)
	_check("apprentice set the bowl", await _until(func(): return Quest.has_reached(&"apply_slip"), 40.0))

	# The master binds the legs with slip.
	await _use(WS + "ClayStatue/Body/Usable", &"hold")
	# (The apprentice may have found the chisel already.)
	_check("slip applied", Quest.has_reached(&"find_chisel"))
	# The apprentice finds the chisel and hands it over.
	_check("master was handed the chisel", await _until(func(): return me.inventory.has_item(&"chisel"), 40.0))
	for i in 3:
		await _use(WS + "ClayStatue/Body/Usable", &"use")
	_expect(&"sealing")
	_log("sealing...")
	_check("sealing played out together", await _until(func():
		Dialogue.skip_line()
		return Quest.has_reached(&"find_liang"), 150.0, 0.4))
	_expect(&"find_liang")
	_check("guards hostile", Game.get_flag(&"guards_hostile"))

	# The apprentice makes some noise, is knocked down and helped up, then dies.
	_check("the apprentice's noise reached the host", await _until(func(): return _noises_from_apprentice > 0, 30.0))
	var apprentice_now := Net.body(Net.APPRENTICE_BODY)
	_check("the apprentice went down (seen on the host)", await _until(func(): return apprentice_now.downed, 30.0))
	_check("still playing while one is down", not Game.is_dead())
	await _wait(1.0)
	await _use("Apprentice/UseBody/Usable", &"hold")
	_check("helped him up", await _until(func(): return not apprentice_now.downed, 5.0))
	var died := [false]
	Game.failed.connect(func(_r): died[0] = true, CONNECT_ONE_SHOT)
	_check("the apprentice's death ended the run", await _until(func(): return died[0], 30.0))
	await _wait(2.0)
	Game.retry_from_checkpoint()
	await Game.level_ready
	await _settle_level()
	_check("retry: back at find_liang", Quest.has_reached(&"find_liang"))
	_check("retry: the apprentice is back", Net.has_partner() and Net.body(Net.APPRENTICE_BODY) != null)
	# Give the apprentice time to check his side, then leave.
	await _until(func(): return false, 8.0)
	_log("leaving")
	Net.leave()
	await _wait(1.0)

# --- The apprentice -----------------------------------------------------------------------

func _client() -> void:
	await _wait(1.0)
	_check("joining", Net.join("127.0.0.1"))
	# The master may begin at once: the lobby can come and go between checks.
	if not await _until(func(): return Net.phase in [Net.Phase.LOBBY, Net.Phase.PLAYING], 30.0):
		_check("joined the master", false)
		return
	_log("in the lobby")
	await Game.level_ready
	await _settle_level()
	_check("apprentice is local", me.name == Net.APPRENTICE_BODY and me.is_local)
	var master := Net.body(Net.MASTER_BODY)
	_check("master body is a puppet here", master != null and not master.is_local)
	_check("quest came from the host", Quest.current() != &"")
	_expect(&"talk_apprentice")

	_check("the master talked to us", await _until(func(): return Quest.has_reached(&"take_lamp"), 40.0))
	_check("the talk's lines were shown here", _lines_seen > 0)
	await _use(WS + "LampStand_W/Body/Usable", &"tap")
	_check("lamp in our hand", await _until(func(): return me.inventory.lamp() != null, 5.0))
	_expect(&"fetch_slip")
	await _use(WS + "SlipBowl/Usable", &"use")
	_check("we carry the bowl", await _until(func(): return me.inventory.has_item(&"clay_bowl"), 5.0))
	_expect(&"place_bowl")
	await _use(WS + "ClayStatue/Body/Usable", &"use")
	_check("bowl set", await _until(func(): return Quest.has_reached(&"apply_slip"), 5.0))
	var statue := level.get_node(WS + "ClayStatue")
	_check("the bowl shows on the bench here", bool(statue.get("bowl_placed")))

	_check("the master applied the slip", await _until(func(): return Quest.has_reached(&"find_chisel"), 40.0))
	_check("the slip shows here", bool(statue.get("slip_applied")))
	_check("the master's lamp shows here", master.inventory.lamp() != null)
	await _use(WS + "FallenChisel/Usable", &"use")
	_check("we found the chisel", await _until(func(): return me.inventory.has_item(&"chisel"), 5.0))
	for i in me.inventory.SLOTS:
		if me.inventory.slot_item(i) != null and me.inventory.slot_item(i).id == &"chisel":
			me.inventory.select(i)
			Net.inventory_action(me, &"select", [i])
	await _wait(0.5)
	await _use("Player/UseBody/Usable", &"use")
	_check("chisel handed over", await _until(func(): return not me.inventory.has_item(&"chisel"), 5.0))
	_check("the master has it here too", await _until(func(): return master.inventory.has_item(&"chisel"), 5.0))

	_check("the statue was finished", await _until(func(): return Quest.has_reached(&"sealing"), 40.0))
	_check("the guards come in (seen here)", await _guards_move(25.0))
	_check("sealing done together", await _until(func(): return Quest.has_reached(&"find_liang"), 150.0))
	_check("flags came over", Game.get_flag(&"guards_hostile"))

	# Some noise for the host's guards, a blow that knocks us down, then a death.
	for i in 3:
		Stealth.make_noise(me.global_position, 12.0, me)
		await _wait(0.3)
	await _wait(2.0)
	me.apply_damage(100.0, null, "DEATH_GUARD")
	_check("knocked down, not dead", me.downed and not Game.is_dead())
	_check("the master helped us up", await _until(func(): return not me.downed, 30.0))
	_check("up again with some health", me.health > 0.0 and not me.controls_locked())
	await _wait(2.0)
	var died := [false]
	Game.failed.connect(func(_r): died[0] = true, CONNECT_ONE_SHOT)
	me.kill("DEATH_SPIKES")
	_check("our death ended the run here too", await _until(func(): return died[0], 15.0))
	await Game.level_ready
	await _settle_level()
	_check("retry: back at find_liang here", Quest.has_reached(&"find_liang"))
	_check("retry: our body is ours again", me.is_local and me.name == Net.APPRENTICE_BODY)
	_check("the master leaves: back to the menu", await _until(func(): return not Net.active, 30.0))

# --- Helpers -------------------------------------------------------------------------------

var _lines_seen := 0

func _on_noise(_position: Vector3, _radius: float, source: Node) -> void:
	if is_instance_valid(source) and source.name == Net.APPRENTICE_BODY and source is Player and not (source as Player).is_local:
		_noises_from_apprentice += 1

func _settle_level() -> void:
	level = Game.level
	me = Net.local_body()
	if not Dialogue.line_started.is_connected(_on_line):
		Dialogue.line_started.connect(_on_line)
	await _wait(1.0)

func _on_line(_s, _n, _t, _d, _e) -> void:
	_lines_seen += 1

func _guards_move(seconds: float) -> bool:
	var start := {}
	for g in Stealth.guards():
		start[g] = (g as Node3D).global_position
	var t := 0.0
	while t < seconds:
		await _wait(0.5)
		t += 0.5
		for g in start:
			if is_instance_valid(g) and (g as Node3D).global_position.distance_to(start[g]) > 1.0:
				return true
	return false

func _use(path: String, mode: StringName) -> void:
	var u := level.get_node_or_null(path) as Usable
	if u == null:
		_check("usable exists: " + path, false)
		return
	var body := u.get_node(u.body_path) as Node3D
	if not path.begins_with("Player/") and not path.begins_with("Apprentice/"):
		me.global_position = body.global_position + Vector3(1.2, 0.0, 1.2)
		me.velocity = Vector3.ZERO
		await _wait(0.3)
	if not u.can_use(me):
		_check("can use %s (prompt '%s')" % [path, u.get_prompt(me)], false)
		return
	Net.use(u, me, mode)
	await _wait(0.6)

func _wait_dialogue() -> void:
	await _wait(0.5)
	var t := 0.0
	while Dialogue.is_busy() and t < 60.0:
		Dialogue.skip_line()
		await _wait(0.3)
		t += 0.3

func _until(condition: Callable, seconds: float, step := 0.2) -> bool:
	var t := 0.0
	while t < seconds:
		if condition.call():
			return true
		await _wait(step)
		t += step
	return bool(condition.call())

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _expect(step: StringName) -> void:
	_check("quest at %s (actual %s)" % [step, Quest.current()], Quest.is_at(step))

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("[%s] %s %s" % [role, "PASS" if ok else "FAIL", label])

func _log(text: String) -> void:
	print("[%s] %s" % [role, text])
