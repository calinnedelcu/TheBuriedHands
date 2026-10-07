class_name EndingScreen
extends CanvasLayer
## The walk into the light ends in white. The white settles into old paper and
## the epilogue is written on it in ink: what became of the craftsman, the
## register and the apprentice, then Sima Qian's line under a red seal, and
## the credits roll over the menu's theme. Holding a key speeds the credits
## up; Esc skips them.

const PAPER_SHADER := preload("res://assets/shaders/ui/paper.gdshader")
const STAMP_SOUND := preload("res://audio/sfx/impacts/impactSoft_medium_000.ogg")
const INK := Color(0.13, 0.095, 0.07)
const INK_SOFT := Color(0.33, 0.25, 0.18)
const VERMILION := SealStamp.VERMILION
## Credits scroll speed, in base-resolution pixels per second.
const ROLL_SPEED := 46.0

var _white: ColorRect
var _paper: ColorRect
var _page: Control
var _rolling := false
var _skip_roll := false
## The makers' names the player read on the way (NamesDB entries).
var _names: Array = []

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_white = ColorRect.new()
	_white.color = Color(1.0, 0.985, 0.95, 0.0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_white)
	_paper = ColorRect.new()
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.noise = noise
	mat.set_shader_parameter(&"noise", tex)
	_paper.material = mat
	_paper.modulate.a = 0.0
	_paper.visible = false
	add_child(_paper)
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	Game.finished.connect(_on_finished)

func _process(_delta: float) -> void:
	if _paper.visible:
		(_paper.material as ShaderMaterial).set_shader_parameter(&"aspect", _paper.size.x / maxf(_paper.size.y, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if _rolling and event.is_action_pressed(&"pause"):
		_skip_roll = true
		get_viewport().set_input_as_handled()

func _on_finished(ending: Dictionary) -> void:
	await _wait(3.2)
	var t := create_tween()
	t.tween_property(_white, "color:a", 1.0, 3.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	await _wait(1.4)
	# The white settles into paper.
	_paper.visible = true
	var p := create_tween()
	p.tween_property(_paper, "modulate:a", 1.0, 2.8).set_trans(Tween.TRANS_SINE)
	await p.finished
	_white.visible = false
	await _wait(0.6)
	await _epilogue_card()
	await _card("END_BASE")
	await _card("END_EVIDENCE" if ending.get("evidence", false) else "END_NO_EVIDENCE")
	if ending.get("together", false):
		await _card("END_TOGETHER")
	elif ending.get("apprentice", false):
		# Freed from the pen; and the lamp you left him, if you did.
		var line := tr("END_APPRENTICE")
		if ending.get("lamp", false):
			line += " " + tr("END_APPRENTICE_LAMP")
		await _card_text(line)
	else:
		await _card("END_NO_APPRENTICE")
	var names: Array = ending.get("names", [])
	_names = names
	if names.is_empty():
		await _card("END_NO_NAMES")
	else:
		await _card_text(tr("END_NAMES") % names.size())
	Music.set_ambience(&"", 10.0)
	Music.play(&"menu", 6.0)
	await _quote()
	await _credits()
	await _thanks()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.return_to_menu()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

## A label in ink. `key` is translated here: these labels are built at
## runtime and the text is set once.
func _ink(variation: StringName, key: String, color := INK) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = tr(key)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _column(width := 1000.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override(&"separation", 18)
	center.add_child(box)
	return box

func _rule(width: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(INK_SOFT, 0.55)
	rule.custom_minimum_size = Vector2(width, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule

## Writes a page in, holds it, lets it fade off the paper.
func _show_page(node: Control, hold: float) -> void:
	node.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_interval(hold)
	t.tween_property(node, "modulate:a", 0.0, 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.5)
	await t.finished
	node.get_parent().queue_free()

## The same shape as the chapter cards: this is the last one.
func _epilogue_card() -> void:
	var box := _column(1200.0)
	box.add_theme_constant_override(&"separation", 10)
	box.add_child(_ink(&"HeaderLabel", "END_EPILOGUE", VERMILION))
	box.add_child(_ink(&"TitleLabel", "END_TITLE"))
	box.add_child(_rule(260.0))
	box.add_child(_ink(&"QuoteText", "END_PLACE", INK_SOFT))
	await _show_page(box, 3.6)

func _card(key: String) -> void:
	await _card_text(tr(key))

func _card_text(line: String) -> void:
	var box := _column()
	var text := _ink(&"BodyText", "")
	text.text = line
	text.add_theme_font_size_override(&"font_size", 34)
	box.add_child(text)
	await _show_page(box, 5.6)

func _quote() -> void:
	var box := _column(1050.0)
	box.add_theme_constant_override(&"separation", 34)
	var line := _ink(&"QuoteText", "END_HISTORY")
	line.add_theme_font_size_override(&"font_size", 31)
	box.add_child(line)
	var seal := SealStamp.new()
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seal.modulate.a = 0.0
	box.add_child(seal)
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_interval(2.6)
	await t.finished
	# The seal is pressed under the line.
	seal.pivot_offset = seal.custom_minimum_size * 0.5
	seal.scale = Vector2.ONE * 1.35
	var s := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	s.tween_property(seal, "scale", Vector2.ONE, 0.16)
	s.tween_property(seal, "modulate:a", 0.93, 0.12)
	await _wait(0.12)
	Sfx.play_ui(STAMP_SOUND, -4.0)
	await _wait(5.5)
	var out := create_tween()
	out.tween_property(box, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	out.tween_interval(0.8)
	await out.finished
	box.get_parent().queue_free()

## The credits roll up the paper.
func _credits() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	_page.add_child(holder)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	box.custom_minimum_size = Vector2(1000, 0)
	holder.add_child(box)
	var seal := SealStamp.new()
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seal.modulate.a = 0.93
	box.add_child(seal)
	box.add_child(_spacer(18))
	box.add_child(_ink(&"TitleLabel", "GAME_TITLE"))
	box.add_child(_spacer(40))
	for entry in CreditsDB.ENTRIES:
		box.add_child(_ink(&"HeaderLabel", entry[0], VERMILION))
		if entry[1] != "":
			var body := _ink(&"BodyText", "")
			body.text = entry[1]
			box.add_child(body)
		box.add_child(_spacer(30))
	if not _names.is_empty():
		box.add_child(_ink(&"HeaderLabel", "CREDITS_REMEMBERED", VERMILION))
		for n in _names:
			box.add_child(_ink(&"QuoteText", String(n["key"]), INK_SOFT))
		box.add_child(_spacer(30))
	box.add_child(_ink(&"HeaderLabel", "CREDITS_HISTORY", VERMILION))
	box.add_child(_ink(&"QuoteText", "CREDITS_HISTORY_TEXT", INK_SOFT))
	await get_tree().process_frame
	var view := holder.size
	box.size = Vector2(1000, box.get_combined_minimum_size().y)
	box.position = Vector2((view.x - 1000.0) * 0.5, view.y + 20.0)
	_rolling = true
	_skip_roll = false
	while box.position.y + box.size.y > -20.0 and not _skip_roll:
		var fast := Input.is_action_pressed(&"jump") or Input.is_action_pressed(&"skip_line") or Input.is_action_pressed(&"interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		box.position.y -= ROLL_SPEED * (6.0 if fast else 1.0) * get_process_delta_time()
		await get_tree().process_frame
	_rolling = false
	if _skip_roll:
		var t := create_tween()
		t.tween_property(box, "modulate:a", 0.0, 0.8)
		await t.finished
	holder.queue_free()

func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _thanks() -> void:
	var box := _column()
	box.add_child(_ink(&"TitleLabel", "END_THANKS"))
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_interval(3.4)
	await t.finished
