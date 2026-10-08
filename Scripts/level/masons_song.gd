class_name MasonsSong
extends RefCounted
## Old Bai's crew of masons laid the great corridor's trapped floors, and
## walked out of them by their work song: a verse for each floor, counting
## the stones of the way across ("begin on the second stone from the river
## wall; three toward the sunrise; one toward the mountain..."), facing the
## sunrise as they worked, the Wei river on the left, Mount Li on the right.
## Nobody alive has it whole. The player gathers it a few lines at a time:
## Bai himself at his bench in the workshop, the lines his crew cut into the
## bench's edge, the strip of bamboo his son carried into the corridor, the
## craftsman who watched the son die on it, and Bai again once he knows.
##
## Each verse is its floor's way (TrapField.moves()) two moves to a line,
## the start with the first; each source gives about a third of a verse.
## What is known shows in the journal (held Tab). "@verse/<floor>/<line>"
## stands for a line in dialogue, so each machine says it in its own tongue.
## Alone, what you learn is kept with the game (flags, saved); in co-op, only
## the one who heard or read it knows it: he has to tell the other.

const FLOORS := {&"west": "CorridorTraps/FieldWest", &"east": "CorridorTraps/FieldEast"}
## Where the son lies (his strip of bamboo) and who mourns him; the bench.
const SON_FOUND := &"song_son_found"

## Co-op: this machine's player's own knowledge (not the story's).
static var _coop_known := {}

static func field(floor: StringName) -> TrapField:
	if Game.level == null or not FLOORS.has(floor):
		return null
	return Game.level.get_node_or_null(String(FLOORS[floor])) as TrapField

## The verse's lines, each a list of moves.
static func lines(floor: StringName) -> Array:
	var f := field(floor)
	if f == null:
		return []
	var moves := f.moves()
	var out: Array = []
	if moves.is_empty():
		return out
	var first: Array = [moves[0]]
	if moves.size() > 1:
		first.append(moves[1])
	out.append(first)
	var k := 2
	while k < moves.size():
		var line: Array = [moves[k]]
		if k + 1 < moves.size():
			line.append(moves[k + 1])
		out.append(line)
		k += 2
	return out

static func line_count(floor: StringName) -> int:
	return lines(floor).size()

## A line as the masons sang it, in this game's language.
static func line_text(floor: StringName, index: int) -> String:
	var all := lines(floor)
	if index < 0 or index >= all.size():
		return "…"
	var parts := PackedStringArray()
	for move in all[index]:
		var n: int = move[1]
		match move[0]:
			&"start":
				parts.append(TranslationServer.translate("VERSE_START") % _ordinal(n))
			&"east":
				parts.append(TranslationServer.translate("VERSE_EAST") % _stones(n))
			&"river":
				parts.append(TranslationServer.translate("VERSE_RIVER") % _stones(n))
			&"mountain":
				parts.append(TranslationServer.translate("VERSE_MOUNTAIN") % _stones(n))
	var text := "; ".join(parts)
	if index == all.size() - 1:
		text += TranslationServer.translate("VERSE_END")
	return text.substr(0, 1).to_upper() + text.substr(1) + "."

static func _ordinal(n: int) -> String:
	var key := "VERSE_ORD_%d" % n
	var t := TranslationServer.translate(key)
	return t if t != key else str(n)

static func _stones(n: int) -> String:
	var key := "VERSE_N_%d" % n
	var t := TranslationServer.translate(key)
	return t if t != key else TranslationServer.translate("VERSE_N_MANY") % n

## A dialogue key standing for one line: "@verse/west/2".
static func key(floor: StringName, index: int) -> String:
	return "@verse/%s/%d" % [floor, index]

## The text of a dialogue key, if it stands for a verse line ("" if not).
static func resolve(text_key: String) -> String:
	if not text_key.begins_with("@verse/"):
		return ""
	var p := text_key.split("/")
	if p.size() != 3:
		return ""
	return "« %s »" % line_text(StringName(p[1]), int(p[2]))

## The lines a source gives: one of three parts of a verse.
static func part(floor: StringName, which: int) -> Vector2i:
	var n := line_count(floor)
	@warning_ignore("integer_division")
	var a := (n * which + 2) / 3
	@warning_ignore("integer_division")
	var b := (n * (which + 1) + 2) / 3
	return Vector2i(mini(a, n), mini(b, n))

static func _flag(floor: StringName, index: int) -> StringName:
	return StringName("song_%s_%d" % [floor, index])

static func knows(floor: StringName, index: int) -> bool:
	var f := _flag(floor, index)
	return _coop_known.has(f) if Net.active else Game.get_flag(f)

static func known_count(floor: StringName) -> int:
	var n := 0
	for i in line_count(floor):
		if knows(floor, i):
			n += 1
	return n

## `user` learns lines [from, to) of a floor's verse (only the player at this
## machine: in co-op the other one heard nothing he can keep). Returns how
## many were new to him.
static func learn(floor: StringName, lines_range: Vector2i, user: Node) -> int:
	var p := user as Player
	if p == null or not p.is_local:
		return 0
	var fresh := 0
	for i in range(lines_range.x, lines_range.y):
		if knows(floor, i):
			continue
		fresh += 1
		var f := _flag(floor, i)
		if Net.active:
			_coop_known[f] = true
		else:
			Game.set_flag(f)
	if fresh > 0:
		p.notice("NOTICE_SONG_LEARNED")
	return fresh

static func forget_coop() -> void:
	_coop_known.clear()

## The lines of `floor` for `user`'s source, as dialogue entries.
static func say_part(speaker: StringName, floor: StringName, which: int) -> Array:
	var out: Array = []
	var r := part(floor, which)
	for i in range(r.x, r.y):
		out.append([speaker, key(floor, i)])
	return out

## What the journal shows of the song: per floor, the known lines and "…"
## for the rest ("" while nothing is known).
static func journal_text() -> String:
	var any := false
	var out := PackedStringArray()
	for floor in [&"west", &"east"]:
		var n := line_count(floor)
		if n == 0:
			continue
		var rows := PackedStringArray()
		for i in n:
			if knows(floor, i):
				any = true
				rows.append(line_text(floor, i))
			else:
				rows.append("…")
		out.append(TranslationServer.translate("SONG_FLOOR_" + String(floor).to_upper()))
		out.append_array(rows)
	return "\n".join(out) if any else ""

# --- Who tells it ----------------------------------------------------------------------

## Whether `talker` has anything to say now.
static func can_talk(talker: StringName) -> bool:
	match talker:
		&"bai":
			return true
		&"mourner":
			return Quest.has_reached(&"find_liang")
	return false

## Talking to Bai or to the craftsman by his son: lines of the song, by what
## has happened. `user` learns what is sung to him.
static func talk(talker: StringName, worker: Node3D, user: Node) -> void:
	var p := user as Player
	if p == null:
		return
	var lines_: Array = []
	match talker:
		&"bai":
			if not Quest.has_reached(&"sealing"):
				# At his bench: the start of the first floor's verse, how it's
				# counted, and where his crew put the rest.
				lines_ = [[&"bai", "DLG_BAI_WORK_1"], [&"craftsman", "DLG_BAI_WORK_2"], [&"bai", "DLG_BAI_WORK_3"]]
				lines_.append_array(say_part(&"bai", &"west", 0))
				lines_.append([&"bai", "DLG_BAI_WORK_4"])
				learn(&"west", part(&"west", 0), user)
			elif not Game.get_flag(SON_FOUND):
				lines_ = [[&"bai", "DLG_BAI_AFTER_1"], [&"bai", "DLG_BAI_AFTER_2"]]
				# Not heard from him at his bench: how it starts, at least.
				var start := part(&"west", 0)
				var heard := true
				for i in range(start.x, start.y):
					heard = heard and knows(&"west", i)
				if not heard:
					lines_.append([&"bai", "DLG_BAI_AFTER_START"])
					lines_.append_array(say_part(&"bai", &"west", 0))
					learn(&"west", start, user)
				lines_.append([&"bai", "DLG_BAI_AFTER_3"])
			else:
				# He knows. The end of the second floor's verse, for nobody
				# else to die on his stones.
				lines_ = [[&"bai", "DLG_BAI_GRIEF_1"], [&"bai", "DLG_BAI_GRIEF_2"]]
				lines_.append_array(say_part(&"bai", &"east", 2))
				lines_.append([&"bai", "DLG_BAI_GRIEF_3"])
				learn(&"east", part(&"east", 2), user)
		&"mourner":
			lines_ = [[&"mourner", "DLG_MOURNER_1"], [&"mourner", "DLG_MOURNER_2"]]
			lines_.append_array(say_part(&"mourner", &"east", 1))
			lines_.append([&"mourner", "DLG_MOURNER_3"])
			learn(&"east", part(&"east", 1), user)
	if not lines_.is_empty():
		Dialogue.play_lines(StringName("talk_" + String(talker)), lines_)

## Reading what the masons wrote: the edge of Bai's bench, his son's strip of
## bamboo. Too dark without a flame.
static func read(source: StringName, user: Node) -> void:
	var p := user as Player
	if p == null:
		return
	var lines_: Array = []
	match source:
		&"bench":
			lines_ = [[&"craftsman", "DLG_BENCH_1"]]
			lines_.append_array(say_part(&"craftsman", &"west", 1))
			learn(&"west", part(&"west", 1), user)
		&"slip":
			Game.set_flag(SON_FOUND)
			lines_ = [[&"craftsman", "DLG_SLIP_1"]]
			lines_.append_array(say_part(&"craftsman", &"west", 2))
			lines_.append_array(say_part(&"craftsman", &"east", 0))
			lines_.append([&"craftsman", "DLG_SLIP_2"])
			learn(&"west", part(&"west", 2), user)
			learn(&"east", part(&"east", 0), user)
	if not lines_.is_empty():
		Dialogue.play_lines(StringName("read_" + String(source)), lines_)
