extends Node
## Dev test: the masons' song (MasonsSong), gathered as a player would, in
## story order, and the hollow pillar:
##   each floor's verse walks its way exactly (only safe stones, out at the
##   far edge) and reads in words, no raw keys;
##   Act I: Bai at his bench sings the start of the first floor's verse; the
##   bench (by a flame only) has its middle;
##   after the sealing: Bai speaks of his son; the son on the way has the
##   strip of bamboo (the rest of the first verse, the start of the second);
##   the mourner beside him the middle of the second; Bai, once he knows,
##   its end: both verses whole, and in the journal;
##   the hollow pillar: a lit lamp near it gutters (and only near the real
##   one), the chisel gets its face off.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/song_runner.gd

const WS := "Rooms/01_TerracottaWorkshop/"

var failures := 0
var level: Node3D
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _run() -> void:
	Game.new_game()
	Game.set_flag(&"intro_done")
	await Game.level_ready
	level = Game.level as Node3D
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(0.4)
	Dialogue.stop()
	Quest.start_at(&"fetch_slip")
	player.inventory.take_lamp(100.0, true)
	_verses_walk_their_ways()
	_the_walls_carry_the_bearings()
	# Act I: Bai at his bench, then the bench.
	var bai := level.get_node(WS + "Sculptor2") as TalkingWorker
	_check("Bai can be talked to", bai != null and MasonsSong.can_talk(&"bai"))
	await _talk(bai)
	var a := MasonsSong.part(&"west", 0)
	_check("Bai sang the first verse's start (%d lines)" % (a.y - a.x), _known(&"west", a))
	var bench := level.get_node(WS + "MasonsBench/Verse") as Readable
	player.inventory.lamp().snuff()
	_check("too dark to read the bench without a flame", not bench.usable_can_use(player) and bench.usable_prompt(player) == tr("PROMPT_TOO_DARK_TO_READ"))
	player.inventory.lamp().toggle()
	await _read(bench)
	_check("the bench has its middle", _known(&"west", MasonsSong.part(&"west", 1)))
	_check("the journal shows the song", MasonsSong.journal_text().contains(MasonsSong.line_text(&"west", 0)))
	# After the sealing.
	Game.set_flag(&"guards_hostile")
	Game.advance_sealing(1)
	Quest.start_at(&"find_liang")
	await _wait(0.5)
	var before := MasonsSong.known_count(&"east")
	await _talk(bai)
	_check("Bai, after: of his son, no lines yet", MasonsSong.known_count(&"east") == before and not Game.get_flag(MasonsSong.SON_FOUND))
	var son := level.get_node("TheFallen/ShotAtPlate3") as Node3D
	var west := level.get_node("CorridorTraps/FieldWest") as TrapField
	_check("the son lies on the first floor's way", west.kind_at(son.global_position + Vector3.UP * 0.1) == TrapField.Cell.SAFE)
	await _aim_at_slip(son)
	await _read(son.get_node("Slip") as Readable)
	_check("the strip: the rest of the first verse", _known(&"west", MasonsSong.part(&"west", 2)) and MasonsSong.known_count(&"west") == MasonsSong.line_count(&"west"))
	_check("and the start of the second", _known(&"east", MasonsSong.part(&"east", 0)) and Game.get_flag(MasonsSong.SON_FOUND))
	var mourner := level.get_node("TheFallen/Mourner") as TalkingWorker
	_check("the mourner kneels off the way, on a safe stone", west.kind_at(mourner.global_position + Vector3.UP * 0.1) == TrapField.Cell.SAFE and not Array(west.way).has(west.cell_at(mourner.global_position)))
	await _talk(mourner)
	_check("the mourner: the second verse's middle", _known(&"east", MasonsSong.part(&"east", 1)))
	await _talk(bai)
	_check("Bai, knowing: its end; both verses whole", MasonsSong.known_count(&"east") == MasonsSong.line_count(&"east"))
	await _the_hollow_pillar()
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

## Walking each verse's moves from its first stone treads only safe stones
## and leaves at the far edge.
func _verses_walk_their_ways() -> void:
	for floor in [&"west", &"east"]:
		var f := MasonsSong.field(floor)
		var moves := f.moves()
		var row: int = moves[0][1] - 1
		var col := 0
		var ok := f.kind(f.index_of(col, row)) == TrapField.Cell.SAFE
		for k in range(1, moves.size()):
			for n in int(moves[k][1]):
				match moves[k][0]:
					&"east":
						col += 1
					&"river":
						row -= 1
					&"mountain":
						row += 1
				ok = ok and f.kind(f.index_of(col, row)) == TrapField.Cell.SAFE
		_check("%s: the verse walks only safe stones and reaches the far edge (col %d of %d)" % [floor, col, f.columns], ok and col == f.columns - 1)
		var words := true
		for i in MasonsSong.line_count(floor):
			var t := MasonsSong.line_text(floor, i)
			words = words and t.length() > 8 and not t.contains("VERSE_")
		_check("%s: %d lines, all in words ('%s')" % [floor, MasonsSong.line_count(floor), MasonsSong.line_text(floor, 0)], words)

## The verse names no compass point: the corridor's own walls carry the
## bearings it uses (waves along the north wall, peaks along the south), and
## the verse's words are those.
func _the_walls_carry_the_bearings() -> void:
	var waves := level.get_node("CorridorTraps/FriezeWaves") as WallFrieze
	var peaks := level.get_node("CorridorTraps/FriezePeaks") as WallFrieze
	var west := MasonsSong.field(&"west")
	_check("waves on the north wall, peaks on the south, along the corridor", waves.motif == WallFrieze.Motif.WAVES and peaks.motif == WallFrieze.Motif.PEAKS and waves.global_position.z < west.global_position.z and peaks.global_position.z > west.global_position.z + west.rows * west.cell)
	var words := MasonsSong.line_text(&"west", 0) + MasonsSong.line_text(&"east", 1)
	_check("the verse speaks of the waves, the peaks, the archives (no sunrise, river or mountain)", not (words.contains("sunrise") or words.contains("răsărit") or words.contains("river") or words.contains("mountain")))

## Near the real pillar a lamp gutters; near the others, nothing.
func _the_hollow_pillar() -> void:
	var real := level.get_node("CorridorTraps/Winch") as WinchNiche
	var decoy := level.get_node("CorridorTraps/PillarSouth") as WinchNiche
	player.global_position = decoy.global_position + decoy.global_basis.z * 1.4 + Vector3.UP * 0.1
	await _wait(1.5)
	_check("a decoy pillar: no draught", not decoy.felt and not decoy.real)
	player.global_position = real.global_position + real.global_basis.z * 1.4 + Vector3.UP * 0.1
	player.look_at_point(real.global_position + Vector3.UP * 1.3, 0.01)
	await _wait(1.5)
	_check("the hollow pillar: the flame gutters (felt)", real.felt)
	_check("loose stones, but no chisel yet", real.usable_prompt(player) == tr("PROMPT_NICHE_NEED_CHISEL"))
	player.inventory.add(&"chisel")
	_check("with the chisel, they come out", real.usable_can_use(player))
	real.usable_hold_done(player)
	_check("the face is off", real.opened)

## As a player: standing by the body, looking at it, with a lit lamp.
func _aim_at_slip(son: Node3D) -> void:
	player.global_position = son.global_position + Vector3(1.0, 0.0, 0.4)
	player.look_at_point(son.global_position + Vector3.UP * 0.3, 0.01)
	for i in 20:
		await get_tree().physics_frame
	var t: Usable = player.interactor.target
	_check("the aim finds the strip on the body ('%s')" % (t.get_prompt(player) if t != null else ""), t != null and t.get_parent().name == &"Slip" and t.get_prompt(player) == tr("PROMPT_SEARCH_BODY"))

func _talk(w: TalkingWorker) -> void:
	await _until_quiet()
	w.usable_use(player)
	await _until_quiet()

func _read(r: Readable) -> void:
	await _until_quiet()
	r.usable_use(player)
	await _until_quiet()

func _until_quiet() -> void:
	await _wait(0.2)
	var t := 0.0
	while Dialogue.is_busy() and t < 60.0:
		Dialogue.skip_line()
		await _wait(0.1)
		t += 0.1

func _known(floor: StringName, r: Vector2i) -> bool:
	for i in range(r.x, r.y):
		if not MasonsSong.knows(floor, i):
			return false
	return r.y > r.x
