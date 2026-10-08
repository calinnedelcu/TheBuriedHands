extends Node
## Dev test: two copies of the game play the whole story together over the
## network, one hosting (the master), one joined (the apprentice), each driving
## its own player by teleport and use, the way the quest bot does alone, and
## checking that the other side sees the same world. Covers: uses through the
## host on both machines, inventories and the quest in step, guards moving on
## the apprentice's machine, his noises reaching the host's guards, the
## co-op jobs (the apprentice fetches and hands over, the master works the
## clay; the wedge held while the master strikes; the full jar taking both
## hands; the brake held while the apprentice pins the causeway; the drain's
## bend only the apprentice fits; a half of the tiger tally each, set in the
## inner gate), a knock-down and a revive, a shared death and retry, and
## both walking out into the light. Losing each other while a
## level loads fails the run, and so does a script error anywhere.
## Run the two at once (add --from=causeway to both to start at the pour):
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/coop_bot_runner.gd --role=host
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/coop_bot_runner.gd --role=client

const WS := "Rooms/01_TerracottaWorkshop/"
## On the counterweight's platform; its default +x+z side hangs over the pit.
const COUNTERWEIGHT_STAND := Vector3(-1.5, -1.5, -1.0)

var role := "host"
var from := ""
var me: Player
var level: Node
var failures := 0
var _noises_from_apprentice := 0
var _lines_seen := 0
var _errors := ScriptErrors.new()

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.substr(7)
		elif arg.begins_with("--from="):
			from = arg.substr(7)
	OS.add_logger(_errors)
	_run.call_deferred()

func _run() -> void:
	if role == "host":
		await _host()
	else:
		await _client()
	OS.remove_logger(_errors)
	if _errors.count > 0:
		_check("no script errors (%d, the first: %s)" % [_errors.count, _errors.first], false)
	print("[%s] RESULT: %d failure(s)" % [role, failures])
	get_tree().quit(1 if failures > 0 else 0)

# --- The master -------------------------------------------------------------------------------

func _host() -> void:
	_check("hosting", Net.host())
	if not await _until(func(): return Net.has_partner(), 40.0):
		_check("apprentice joined", false)
		return
	_log("apprentice joined")
	Net.begin()
	await Game.level_ready
	if not await _settle_level():
		return
	_check("master is local", me.name == Net.MASTER_BODY and me.is_local)
	var apprentice := Net.body(Net.APPRENTICE_BODY)
	_check("apprentice body on the host is a puppet", apprentice != null and not apprentice.is_local)
	_check("the apprentice at his bench is gone", level.get_node_or_null(WS + "Apprentice") == null)
	Stealth.noise_made.connect(_on_noise)
	_expect(&"talk_apprentice")
	if from == "causeway":
		await _host_causeway(apprentice)
		return

	# Act I. The master talks to the apprentice (the second player).
	await _wait(1.0)
	await _use("Apprentice/UseBody/Usable", &"use")
	await _wait_dialogue()
	_expect(&"take_lamp")
	_check("apprentice took a lamp (seen on the host)", await _until(func(): return Quest.has_reached(&"fetch_slip"), 30.0))
	_check("the apprentice's puppet holds the lamp", apprentice.inventory.lamp() != null)
	await _use(WS + "LampStand_E/Body/Usable", &"tap")
	_check("master has his own lamp", me.inventory.lamp() != null)
	# The apprentice fetches the bowl and hands it over; the clay is the master's.
	_check("the apprentice handed over the bowl", await _until(func(): return me.inventory.has_item(&"clay_bowl"), 40.0))
	await _use(WS + "ClayStatue/Body/Usable", &"use")
	_expect(&"apply_slip")
	await _use(WS + "ClayStatue/Body/Usable", &"hold")
	_check("slip applied", Quest.has_reached(&"find_chisel"))
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
	_check("the apprentice went down (seen on the host)", await _until(func(): return apprentice.downed, 30.0))
	_check("still playing while one is down", not Game.is_dead())
	await _wait(1.0)
	await _use("Apprentice/UseBody/Usable", &"hold")
	_check("helped him up", await _until(func(): return not apprentice.downed, 5.0))
	var died := [false]
	Game.failed.connect(func(_r): died[0] = true, CONNECT_ONE_SHOT)
	_check("the apprentice's death ended the run", await _until(func(): return died[0], 30.0))
	await _wait(2.0)
	Game.retry_from_checkpoint()
	await Game.level_ready
	if not await _settle_level():
		return
	apprentice = Net.body(Net.APPRENTICE_BODY)
	_check("retry: back at find_liang", Quest.has_reached(&"find_liang"))
	_check("retry: the apprentice is back", Net.has_partner() and apprentice != null)

	# Act II. Guards stand down so the bots can walk where they please.
	Game.set_flag(&"guards_hostile", false)
	await _wait(2.0)
	await _enter("Story/LiangRoomEnter")
	_expect(&"talk_liang")
	await _use("Liang/TalkBody/Usable", &"use")
	await _wait_dialogue()
	# Neither of us took Wei's half on the way: the apprentice fetches it.
	_expect(&"take_tally")
	_check("the apprentice took Wei's half of the tally", await _until(func(): return Quest.has_reached(&"descend"), 40.0))

	# Act III, the tunnels: the apprentice holds the wedge, the master strikes.
	await _use("Tool_Workbench_Hammer_W/Usable", &"use")
	_check("master has the mallet", me.inventory.has_item(&"hammer"))
	var stone := level.get_node("ShaftStone")
	var u := level.get_node("ShaftStone/Body/Usable") as Usable
	_check("no blow without the wedge held", not u.can_use(me))
	_check("the apprentice holds the wedge (seen here)", await _until(func(): return apprentice.bracing != null, 40.0))
	for i in 4:
		await _use("ShaftStone/Body/Usable", &"hold")
	_check("the stone split", bool(stone.get("broken")))
	_check("the apprentice let go of the wedge", await _until(func(): return apprentice.bracing == null, 5.0))
	# Down in the pits the master takes the commander's half; at the inner
	# gate each of us sets his own, and a whole tiger opens it.
	await _enter("UnderTheMountain/PitsReached")
	_expect(&"pit_tally")
	await _use("UnderTheMountain/CommanderPost/PitTally/Usable", &"use")
	_expect(&"open_gate")
	var gate := level.get_node("UnderTheMountain/InnerGate") as TallyGate
	await _use("UnderTheMountain/InnerGate/Sockets/Usable", &"use")
	_check("half a tiger: the gate stays shut", gate.pit_set and not gate.opened)
	_check("the apprentice set Wei's half: the gate opened", await _until(func(): return gate.opened, 40.0))
	_expect(&"reach_mechanism")

	# Act IV, the balance.
	await _enter("Story/MechanismEnter")
	_expect(&"inspect_balance")
	await _use("Mechanism/Counterweight/Body/Usable", &"use", COUNTERWEIGHT_STAND)
	await _wait_dialogue()
	_expect(&"get_vase")
	await _use("Mechanism/Cloth/Usable", &"use")
	_check("the jar and the cloth between the two of us", await _until(func(): return Quest.has_reached(&"fill_vase"), 30.0))
	_check("the jar was filled and poured", await _until(func(): return Quest.has_reached(&"find_drain"), 60.0))
	await _host_causeway(apprentice)

## From the pour on: the brake and the pin, the drain, the light.
func _host_causeway(apprentice: Player) -> void:
	if from == "causeway":
		Game.set_flag(&"guards_hostile", false)
		Quest.start_at(&"find_drain")
		Net.mirror(level.get_node("Mechanism/Causeway"), &"net_open")
		(level.get_node("Mechanism/Causeway") as Causeway).net_open()
	var causeway := level.get_node("Mechanism/Causeway") as Causeway
	_check("the causeway rose", causeway.raised)
	_check("and sinks back with nobody on the brake", await _until(func(): return causeway.is_sinking(), 20.0))
	# Let it go well down, so the brake has something to bring back.
	await _until(func(): return float(causeway.get("_level")) < 0.5, 10.0)
	# On the counterweight's platform, behind the lever (not over the pit).
	await _use("Mechanism/CoopBrake/Body/Usable", &"use", Vector3(0, 0, -1.3))
	# (The apprentice may pin it as soon as it's up, which frees the brake.)
	_check("bearing on the brake", (me.bracing != null and causeway.held) or causeway.pinned)
	_check("the causeway comes back up", await _until(func(): return causeway.is_up(), 15.0))
	_check("the apprentice pinned it", await _until(func(): return causeway.pinned, 30.0))
	_check("let go of the brake by itself", await _until(func(): return me.bracing == null and not me.controls_locked(), 5.0))

	# Act V. The drain's bend is the apprentice's to squeeze through.
	var drain := level.get_node("Drain") as Node3D
	me.global_position = _drain_mouth()
	me._set_stance(Player.Stance.CRAWL, true)
	await _wait(0.6)
	_check("too tight for the master", not (level.get_node("Drain/EntryBody/Usable") as Usable).can_use(me))
	_check("the apprentice pushed through", await _until(func(): return bool(drain.get("opened")), 40.0))
	_check("the channel holds while only one is through", not bool(drain.get("collapsed")))
	await _enter("Drain/ExitTrigger")
	_check("it caves in once both are through", await _until(func(): return bool(drain.get("collapsed")), 30.0))
	_check("out of the drain", await _until(func():
		Dialogue.skip_line()
		return Quest.has_reached(&"escape"), 30.0, 0.3))
	await _enter("Story/ExitLight")
	var ok := await _until(func(): return Game.is_over() and not Game.is_dead(), 30.0)
	if not ok:
		var exit := level.get_node("Story/ExitLight") as Area3D
		_log("exit: arrived=%s done=%s overlapping=%s" % [exit.get("_arrived"), exit.get("_done"), exit.get_overlapping_bodies()])
		for p in Net.players():
			_log("  %s at %s local=%s" % [p.name, p.global_position, p.is_local])
		_log("  game: over=%s dead=%s finished=%s quest=%s player_group=%s" % [Game.is_over(), Game.is_dead(), Game.get("_finished"), Quest.current(), get_tree().get_nodes_in_group(&"player")])
	_check("out into the light together", ok)
	# Give the apprentice time to check his side, then leave.
	await _until(func(): return false, 6.0)
	_log("leaving")
	Net.leave()
	await _wait(1.0)

# --- The apprentice ---------------------------------------------------------------------------

func _client() -> void:
	await _wait(1.0)
	_check("joining", Net.join("127.0.0.1"))
	# The master may begin at once: the lobby can come and go between checks.
	if not await _until(func(): return Net.phase in [Net.Phase.LOBBY, Net.Phase.PLAYING], 30.0):
		_check("joined the master", false)
		return
	_log("in the lobby")
	await Game.level_ready
	if not await _settle_level():
		return
	_check("apprentice is local", me.name == Net.APPRENTICE_BODY and me.is_local)
	var master := Net.body(Net.MASTER_BODY)
	_check("master body is a puppet here", master != null and not master.is_local)
	_check("quest came from the host", Quest.current() != &"")
	if from != "causeway":
		_expect(&"talk_apprentice")
	if from == "causeway":
		await _client_causeway(master)
		return

	# Act I.
	_check("the master talked to us", await _until(func(): return Quest.has_reached(&"take_lamp"), 40.0))
	_check("the talk's lines were shown here", _lines_seen > 0)
	await _use(WS + "LampStand_W/Body/Usable", &"tap")
	_check("lamp in our hand", await _until(func(): return me.inventory.lamp() != null, 5.0))
	_expect(&"fetch_slip")
	await _use(WS + "SlipBowl/Usable", &"use")
	_check("we carry the bowl", await _until(func(): return me.inventory.has_item(&"clay_bowl"), 5.0))
	_expect(&"place_bowl")
	var statue := level.get_node(WS + "ClayStatue")
	_check("the clay is not ours to work", not (level.get_node(WS + "ClayStatue/Body/Usable") as Usable).can_use(me))
	# (The master sets the bowl down at once, so only our side is checked.)
	await _hand_over(&"clay_bowl", null)
	_check("the master set the bowl", await _until(func(): return Quest.has_reached(&"apply_slip"), 30.0))
	_check("the bowl shows on the bench here", bool(statue.get("bowl_placed")))
	_check("the master applied the slip", await _until(func(): return Quest.has_reached(&"find_chisel"), 40.0))
	_check("the slip shows here", bool(statue.get("slip_applied")))
	_check("the master's lamp shows here", master.inventory.lamp() != null)
	await _use(WS + "FallenChisel/Usable", &"use")
	_check("we found the chisel", await _until(func(): return me.inventory.has_item(&"chisel"), 5.0))
	await _hand_over(&"chisel", master)
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
	if not await _settle_level():
		return
	master = Net.body(Net.MASTER_BODY)
	_check("retry: back at find_liang here", Quest.has_reached(&"find_liang"))
	_check("retry: our body is ours again", me.is_local and me.name == Net.APPRENTICE_BODY)

	# The master talked to Liang; Wei's half is ours to fetch from his desk.
	_check("the master talked to Liang", await _until(func(): return Quest.has_reached(&"take_tally"), 60.0))
	await _use("WeiTally/Usable", &"use")
	_check("we carry Wei's half", await _until(func(): return me.inventory.has_item(&"tally_wei"), 5.0))

	# Act III: we hold the wedge while the master strikes.
	await _use("Tool_Workbench_Wedge_W2/Usable", &"use")
	_check("we have the wedge", me.inventory.has_item(&"wedge"))
	await _use("ShaftStone/Body/Usable", &"use")
	_check("holding the wedge in the crack", me.bracing != null and me.controls_locked())
	_check("the master split the stone", await _until(func(): return bool(level.get_node("ShaftStone").get("broken")), 40.0))
	_check("free to move again", await _until(func(): return me.bracing == null and not me.controls_locked(), 5.0))
	# At the inner gate the master sets the commander's half; we set Wei's.
	var gate := level.get_node("UnderTheMountain/InnerGate") as TallyGate
	_check("the master set the commander's half", await _until(func(): return gate.pit_set, 60.0))
	# Let him see half a tiger keep it shut first.
	await _wait(2.5)
	await _use("UnderTheMountain/InnerGate/Sockets/Usable", &"use")
	_check("a whole tiger: the gate opened (seen here)", await _until(func(): return gate.opened, 10.0))
	_check("Wei's half is in its socket", not me.inventory.has_item(&"tally_wei"))

	# Act IV: we take the jar, fill it (both hands: no lamp), and pour it.
	_check("the master examined the balance", await _until(func(): return Quest.has_reached(&"get_vase"), 60.0))
	await _use("Mechanism/Jar/Usable", &"use")
	_check("the jar and the cloth between the two of us", await _until(func(): return Quest.has_reached(&"fill_vase"), 30.0))
	await _use("MercuryHall/FillPoint1/UseBody/Usable", &"hold")
	_check("the jar is full", await _until(func(): return me.inventory.has_item(&"vase_full"), 5.0))
	await _wait(0.5)
	_check("the full jar takes both hands: the lamp is out", me.inventory.lamp() == null or not me.inventory.lamp().is_lit)
	_check("and it is heavy going", me.carries_heavy())
	await _use("Mechanism/Counterweight/Body/Usable", &"hold", COUNTERWEIGHT_STAND)
	_check("poured", await _until(func(): return Quest.has_reached(&"find_drain"), 20.0))
	await _client_causeway(master)

func _client_causeway(master: Player) -> void:
	if from == "causeway":
		_check("the host poured (skipped to)", await _until(func(): return Quest.has_reached(&"find_drain"), 30.0))
	var causeway := level.get_node("Mechanism/Causeway") as Causeway
	_check("we're too light for the brake", await _until(func():
		var brake := level.get_node("Mechanism/CoopBrake/Body/Usable") as Usable
		return causeway.raised and not brake.can_use(me), 20.0))
	_check("the master holds the brake (seen here)", await _until(func(): return master.bracing != null and causeway.held, 40.0))
	_check("the causeway is up", await _until(func(): return causeway.is_up(), 15.0))
	await _use("Mechanism/CoopPin/Body/Usable", &"use", Vector3(-0.6, 0, -0.6))
	_check("pinned", causeway.pinned)

	# Act V: we squeeze through the drain's bend.
	var drain := level.get_node("Drain") as Node3D
	me.global_position = _drain_mouth()
	me._set_stance(Player.Stance.CRAWL, true)
	await _wait(0.6)
	for i in 6:
		await _use("Drain/EntryBody/Usable", &"use")
	_check("the bend is open", bool(drain.get("opened")))
	await _enter("Drain/ExitTrigger")
	_check("it caved in behind us both", await _until(func(): return bool(drain.get("collapsed")), 30.0))
	_check("out of the drain", await _until(func(): return Quest.has_reached(&"escape"), 30.0))
	await _enter("Story/ExitLight")
	_check("out into the light together", await _until(func(): return Game.is_over() and not Game.is_dead(), 30.0))
	_check("the master leaves; the ending plays on", await _until(func(): return not Net.active, 40.0))
	await _wait(1.0)
	_check("still in the ending, not thrown to the menu", Game.is_over() and Game.level != null)

# --- Helpers ------------------------------------------------------------------------------------

## Takes the level that just loaded. False (a failed check) if the two of
## us didn't come through the loading together: the level then goes back to
## the menu, and our body with it.
func _settle_level() -> bool:
	level = Game.level
	me = Net.local_body()
	if not Game.failed.is_connected(_on_failed):
		Game.failed.connect(_on_failed)
	if not Dialogue.line_started.is_connected(_on_line):
		Dialogue.line_started.connect(_on_line)
	await _wait(1.0)
	var together := Net.has_partner() and Game.level == level and is_instance_valid(me) and me.name == Net.local_body_name()
	_check("still together once the level is in", together)
	return together

func _on_failed(reason: String) -> void:
	_log("run failed: %s (quest %s, me at %s, health %.1f, tox %.1f)" % [reason, Quest.current(), me.global_position if is_instance_valid(me) else Vector3.ZERO, me.health if is_instance_valid(me) else -1.0, me.toxicity if is_instance_valid(me) else -1.0])

func _on_line(_s, _n, _t, _d, _e) -> void:
	_lines_seen += 1

func _on_noise(_position: Vector3, _radius: float, source: Node) -> void:
	if is_instance_valid(source) and source.name == Net.APPRENTICE_BODY and source is Player and not (source as Player).is_local:
		_noises_from_apprentice += 1

## Selects `item` and hands it to `partner` (the apprentice's side).
func _hand_over(item: StringName, partner: Player) -> void:
	for i in me.inventory.SLOTS:
		if me.inventory.slot_item(i) != null and me.inventory.slot_item(i).id == item:
			me.inventory.select(i)
			Net.inventory_action(me, &"select", [i])
	await _wait(0.5)
	await _use("Player/UseBody/Usable", &"use")
	_check("%s handed over" % item, await _until(func(): return not me.inventory.has_item(item), 5.0))
	if partner != null:
		_check("the master has the %s here too" % item, await _until(func(): return partner.inventory.has_item(item), 5.0))

## In the channel, before the bend (the drain runs along its local -z).
func _drain_mouth() -> Vector3:
	var entry := level.get_node("Drain/EntryBody") as Node3D
	return entry.global_position + entry.global_basis.z * 2.2

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

## Uses the usable at `path`, standing first at its body + `stand` (most
## things), or where the player is (on the partner, at the drain, braced).
func _use(path: String, mode: StringName, stand := Vector3(1.2, 0.0, 1.2)) -> void:
	var u := level.get_node_or_null(path) as Usable
	if u == null:
		_check("usable exists: " + path, false)
		return
	var body := u.get_node(u.body_path) as Node3D
	var on_body := path.begins_with("Player/") or path.begins_with("Apprentice/")
	if not on_body and me.bracing == null and not path.begins_with("Drain/"):
		me.global_position = body.global_position + stand
		me.velocity = Vector3.ZERO
		await _wait(0.3)
	if not u.can_use(me):
		_check("can use %s (prompt '%s')" % [path, u.get_prompt(me)], false)
		return
	Net.use(u, me, mode)
	await _wait(0.6)

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
	me.global_position = at - Vector3.UP * 0.4
	me.velocity = Vector3.ZERO
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

## Counts script errors. One ends the function it happens in, and the bot
## would go on from where that was called as if nothing had gone wrong.
class ScriptErrors extends Logger:
	var count := 0
	var first := ""
	var _lock := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_lock.lock()
		count += 1
		if first == "":
			first = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]
		_lock.unlock()
