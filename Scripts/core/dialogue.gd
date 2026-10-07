extends Node
## Subtitled dialogue: plays single lines and scripted sequences from DialogueDB.
## Text is always a translation key, resolved when the line is shown so a
## language switch mid-game takes effect on the next line. Timing uses
## pausable timers, so dialogue freezes with the pause menu.

signal line_started(speaker_id: StringName, speaker: String, text: String, duration: float, extras: Dictionary)
signal line_ended
signal sequence_started(id: StringName)
signal sequence_finished(id: StringName)
## The HUD shows the options and answers through `choose_option()`.
signal choice_requested(options: PackedStringArray)
signal choice_made(index: int)
signal _line_done

enum Priority { AMBIENT, HINT, STORY }

## Reading speed used for automatic line duration.
const SECONDS_PER_CHAR := 0.058
const MIN_LINE_SECONDS := 2.4
const MAX_LINE_SECONDS := 9.5
const GAP_SECONDS := 0.28

var _running_id: StringName = &""
var _running_priority := -1
var _run_token := 0
var _line_token := 0
var _line_active := false

func is_busy() -> bool:
	return _running_id != &""

func current_sequence() -> StringName:
	return _running_id

## Plays a sequence from DialogueDB and returns when it ends or is interrupted.
## A request with lower priority than the running sequence is dropped; equal or
## higher priority interrupts it. Returns true if the sequence played to the end.
func play(sequence_id: StringName, priority := Priority.STORY) -> bool:
	# Co-op: the host tells the story; the apprentice's machine shows its lines.
	if not Net.story_allowed():
		return false
	var lines: Array = DialogueDB.sequence(sequence_id).filter(_for_this_game)
	if lines.is_empty():
		push_warning("Dialogue sequence '%s' is empty or missing" % sequence_id)
		return false
	return await _run(sequence_id, lines, priority)

## Lines marked {"only": &"solo"} or {"only": &"coop"} play only in that kind
## of game; {"if": &"flag"} / {"unless": &"flag"} only when the flag is set
## or isn't.
func _for_this_game(entry: Array) -> bool:
	if entry.size() < 3:
		return true
	var extras := entry[2] as Dictionary
	var only: StringName = extras.get("only", &"")
	if only != &"" and only != (&"coop" if Net.active else &"solo"):
		return false
	if extras.has("if") and not Game.get_flag(extras["if"]):
		return false
	if extras.has("unless") and Game.get_flag(extras["unless"]):
		return false
	return true

## Plays one line as its own tiny sequence.
func say(speaker_id: StringName, text_key: String, priority := Priority.HINT) -> bool:
	if not Net.story_allowed():
		return false
	return await _run(StringName("line:" + text_key), [[speaker_id, text_key]], priority)

## Skips the line currently on screen; the rest of the sequence continues.
func skip_line() -> void:
	if Net.is_client():
		Net.request_skip_line()
		return
	if _line_active:
		_line_token += 1
		_line_done.emit()

## Stops whatever is playing without showing further lines.
func stop() -> void:
	if _running_id == &"":
		return
	_run_token += 1
	_line_token += 1
	var id := _running_id
	_running_id = &""
	_running_priority = -1
	Net.send_dialogue(&"stop", [id])
	if _line_active:
		_line_active = false
		line_ended.emit()
	_line_done.emit()
	sequence_finished.emit(id)

## Asks the player to pick one of `option_keys` (translation keys).
## Returns the chosen index once the HUD reports it.
func choose(option_keys: PackedStringArray) -> int:
	var texts := PackedStringArray()
	for key in option_keys:
		texts.append(tr(key))
	choice_requested.emit(texts)
	return await choice_made

func choose_option(index: int) -> void:
	choice_made.emit(index)

static func line_duration(text: String) -> float:
	return clampf(0.9 + text.length() * SECONDS_PER_CHAR, MIN_LINE_SECONDS, MAX_LINE_SECONDS)

func _run(id: StringName, lines: Array, priority: int) -> bool:
	if _running_id != &"":
		if priority < _running_priority:
			return false
		stop()
	_run_token += 1
	var token := _run_token
	_running_id = id
	_running_priority = priority
	Net.send_dialogue(&"start", [id, priority])
	sequence_started.emit(id)
	for entry in lines:
		var speaker_id: StringName = entry[0]
		var text := tr(String(entry[1]))
		var extras: Dictionary = entry[2] if entry.size() > 2 else {}
		var duration: float = extras.get("duration", line_duration(text))
		_line_token += 1
		var line_token := _line_token
		_line_active = true
		Net.send_dialogue(&"line", [speaker_id, String(entry[1]), duration, extras])
		line_started.emit(speaker_id, DialogueDB.speaker_name(speaker_id), text, duration, extras)
		get_tree().create_timer(duration, false).timeout.connect(_on_line_timeout.bind(line_token), CONNECT_ONE_SHOT)
		await _line_done
		if token != _run_token:
			return false
		_line_active = false
		Net.send_dialogue(&"line_end")
		line_ended.emit()
		await get_tree().create_timer(GAP_SECONDS, false).timeout
		if token != _run_token:
			return false
	_running_id = &""
	_running_priority = -1
	Net.send_dialogue(&"end", [id])
	sequence_finished.emit(id)
	return true

## Co-op, on the apprentice's machine: the host's dialogue as it plays there
## (sequence start and end, each line with its own timing).
func apply_remote(kind: StringName, data: Array) -> void:
	match kind:
		&"start":
			if _running_id != &"":
				_end_shown_sequence()
			_running_id = data[0]
			_running_priority = int(data[1])
			sequence_started.emit(_running_id)
		&"line":
			var speaker_id: StringName = data[0]
			_line_active = true
			line_started.emit(speaker_id, DialogueDB.speaker_name(speaker_id), tr(String(data[1])), float(data[2]), data[3])
		&"line_end":
			if _line_active:
				_line_active = false
				line_ended.emit()
		&"end", &"stop":
			_end_shown_sequence()

func _end_shown_sequence() -> void:
	var id := _running_id
	_running_id = &""
	_running_priority = -1
	if _line_active:
		_line_active = false
		line_ended.emit()
	if id != &"":
		sequence_finished.emit(id)

func _on_line_timeout(line_token: int) -> void:
	if line_token == _line_token and _line_active:
		_line_token += 1
		_line_done.emit()
