extends Node
## Session flow and persistent state: new game / continue, checkpoints, the
## save file, death and retry, endings, and scene transitions with a fade.
##
## World nodes that must survive a checkpoint reload join the "persistent"
## group and implement `persist_save() -> Dictionary` and
## `persist_load(data: Dictionary)`. They are keyed by their path inside the
## level, so their names must stay stable.

signal flag_changed(flag: StringName, value: Variant)
signal sealing_advanced(stage: int)
signal checkpoint_saved(step_id: StringName)
signal failed(reason_key: String)
signal finished(ending: Dictionary)
signal level_ready(level: Node)
signal chapter_started(number: int)

const LEVEL_SCENE := "res://scenes/level/mausoleum.tscn"
const MENU_SCENE := "res://scenes/menu/title.tscn"
const SAVE_FILE := "user://savegame.json"
## Shown while the level loads: what history says of the place, and how to
## stay alive in it.
const LOADING_NOTES := ["LOAD_FACT_1", "LOAD_FACT_2", "LOAD_FACT_3", "LOAD_FACT_4", "LOAD_FACT_5", "LOAD_FACT_6",
	"LOAD_TIP_1", "LOAD_TIP_2", "LOAD_TIP_3", "LOAD_TIP_4", "LOAD_TIP_5", "LOAD_TIP_6"]
const SAVE_VERSION := 1

var flags: Dictionary = {}
var sealing_stage := 0
var level: Node = null

var _checkpoint: Dictionary = {}
var _pending_restore: Dictionary = {}
var _has_pending_restore := false
var _is_dead := false
var _finished := false
var _transition: CanvasLayer
var _fade: ColorRect
var _loading_label: Label
var _note: Label
var _note_index := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_transition_layer()

# --- Flags ----------------------------------------------------------------------

func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return flags.get(flag, default)

func set_flag(flag: StringName, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)

## Shows a chapter's title card the first time the story gets there.
func start_chapter(number: int) -> void:
	var flag := StringName("chapter_%d" % number)
	if get_flag(flag):
		return
	set_flag(flag)
	chapter_started.emit(number)

func advance_sealing(stage: int) -> void:
	if stage <= sealing_stage:
		return
	sealing_stage = stage
	sealing_advanced.emit(stage)

# --- Session flow ---------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)

func new_game() -> void:
	_reset_session()
	_has_pending_restore = false
	await _change_scene(LEVEL_SCENE)

func continue_game() -> void:
	var data := _read_save()
	if data.is_empty():
		await new_game()
		return
	_reset_session()
	_checkpoint = data
	_pending_restore = data
	_has_pending_restore = true
	await _change_scene(LEVEL_SCENE)

func retry_from_checkpoint() -> void:
	if _checkpoint.is_empty():
		await new_game()
		return
	_reset_session()
	_pending_restore = _checkpoint
	_has_pending_restore = true
	await _change_scene(LEVEL_SCENE)

func return_to_menu() -> void:
	Dialogue.stop()
	await _change_scene(MENU_SCENE)

func quit_game() -> void:
	await _fade_to(1.0, 0.4)
	get_tree().quit()

## Called by the level root once its nodes are ready.
func register_level(level_root: Node) -> void:
	level = level_root
	_is_dead = false
	_finished = false
	if _has_pending_restore:
		_has_pending_restore = false
		_apply_snapshot(_pending_restore)
		_pending_restore = {}
	elif Quest.current() == &"":
		# Fresh start (also when running the level scene directly from the editor).
		Quest.start_at(QuestDB.STEPS[0]["id"])
	level_ready.emit(level_root)

func is_dead() -> bool:
	return _is_dead

## Dead, or walked out into the ending: the run can't be paused any more.
func is_over() -> bool:
	return _is_dead or _finished

## Ends the run with a death screen. `reason_key` is a translation key.
func fail(reason_key: String) -> void:
	if _is_dead:
		return
	_is_dead = true
	Dialogue.stop()
	failed.emit(reason_key)

func finish() -> void:
	var ending := {
		"evidence": bool(get_flag(&"has_evidence")),
		"apprentice": bool(get_flag(&"gave_lamp")),
		"names": NamesDB.found(),
	}
	_finished = true
	_delete_save()
	finished.emit(ending)

# --- Checkpoints ----------------------------------------------------------------

func request_checkpoint(step_id: StringName) -> void:
	if level == null or _is_dead:
		return
	# Let the frame that triggered the step settle (pickups freed, doors moved).
	await get_tree().process_frame
	_checkpoint = _take_snapshot(step_id)
	_write_save(_checkpoint)
	checkpoint_saved.emit(step_id)

func _take_snapshot(step_id: StringName) -> Dictionary:
	var nodes := {}
	for node in get_tree().get_nodes_in_group(&"persistent"):
		if level != null and level.is_ancestor_of(node) and node.has_method("persist_save"):
			nodes[str(level.get_path_to(node))] = node.call("persist_save")
	return {
		"version": SAVE_VERSION,
		"step": String(step_id),
		"flags": _encode_flags(),
		"sealing": sealing_stage,
		"nodes": nodes,
		"time": Time.get_unix_time_from_system(),
	}

func _apply_snapshot(data: Dictionary) -> void:
	flags = _decode_flags(data.get("flags", {}))
	sealing_stage = int(data.get("sealing", 0))
	# Quest first, so nodes restoring themselves can ask where the story is.
	Quest.start_at(StringName(data.get("step", QuestDB.STEPS[0]["id"])))
	var saved_nodes: Dictionary = data.get("nodes", {})
	for path in saved_nodes:
		var node := level.get_node_or_null(NodePath(path))
		if node != null and node.has_method("persist_load"):
			node.call("persist_load", saved_nodes[path])

func _encode_flags() -> Dictionary:
	var out := {}
	for key in flags:
		out[String(key)] = flags[key]
	return out

func _decode_flags(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		out[StringName(key)] = data[key]
	return out

func _reset_session() -> void:
	flags.clear()
	sealing_stage = 0
	_is_dead = false
	_finished = false
	Quest.reset()
	Dialogue.stop()

# --- Save file --------------------------------------------------------------------

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))

func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != SAVE_VERSION:
		return {}
	return parsed

func _delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

# --- Transitions --------------------------------------------------------------------

func _change_scene(path: String) -> void:
	get_tree().paused = false
	await _fade_to(1.0, 0.45)
	_loading_label.visible = true
	var notes := path == LEVEL_SCENE
	if notes:
		_show_note()
	level = null
	ResourceLoader.load_threaded_request(path)
	var shown := Time.get_ticks_msec()
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# A long first load (shaders compiling) gets a second note.
		if notes and Time.get_ticks_msec() - shown > 9000:
			shown = Time.get_ticks_msec()
			_show_note()
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	_loading_label.visible = false
	if notes:
		var out := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		out.tween_property(_note, "modulate:a", 0.0, 0.35)
	if packed == null:
		push_error("Failed to load scene %s" % path)
		await _fade_to(0.0, 0.3)
		return
	get_tree().change_scene_to_packed(packed)
	# Two frames: one for the swap, one for _ready() chains and the first draw.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, 0.8)

func _show_note() -> void:
	var pick := randi() % LOADING_NOTES.size()
	if pick == _note_index:
		pick = (pick + 1) % LOADING_NOTES.size()
	_note_index = pick
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _note.modulate.a > 0.0:
		t.tween_property(_note, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): _note.text = InputHint.format(tr(LOADING_NOTES[pick])))
	t.tween_property(_note, "modulate:a", 1.0, 0.8)

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished

func _build_transition_layer() -> void:
	_transition = CanvasLayer.new()
	_transition.layer = 120
	add_child(_transition)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition.add_child(_fade)
	_loading_label = Label.new()
	_loading_label.text = "LOADING"
	_loading_label.visible = false
	_loading_label.theme_type_variation = &"LoadingLabel"
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_loading_label.offset_left = -260
	_loading_label.offset_top = -80
	_loading_label.offset_right = -48
	_loading_label.offset_bottom = -40
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_transition.add_child(_loading_label)
	_note = Label.new()
	_note.theme_type_variation = &"QuoteText"
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override(&"font_size", 27)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_note.offset_left = -470
	_note.offset_right = 470
	_note.offset_top = -80
	_note.offset_bottom = 80
	_note.modulate.a = 0.0
	_transition.add_child(_note)
