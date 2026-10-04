class_name EndingScreen
extends CanvasLayer
## Fades the world to white, then tells what became of the evidence and the
## apprentice, quotes Sima Qian, and rolls into the credits.

var _bg: ColorRect
var _box: VBoxContainer

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(1, 1, 1, 0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 26)
	_box.custom_minimum_size = Vector2(1100, 0)
	center.add_child(_box)
	Game.finished.connect(_on_finished)

func _on_finished(ending: Dictionary) -> void:
	await get_tree().create_timer(3.5).timeout
	var t := create_tween()
	t.tween_property(_bg, "color", Color(1, 0.98, 0.94, 1), 3.0)
	await t.finished
	await get_tree().create_timer(1.5).timeout
	var t2 := create_tween()
	t2.tween_property(_bg, "color", Color(0.05, 0.035, 0.03, 1), 3.0)
	await t2.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _card("END_TITLE", "TitleLabel", 2.0)
	await _card("END_BASE", "BodyText", 6.5)
	await _card("END_EVIDENCE" if ending.get("evidence", false) else "END_NO_EVIDENCE", "BodyText", 6.0)
	await _card("END_APPRENTICE" if ending.get("apprentice", false) else "END_NO_APPRENTICE", "BodyText", 7.0)
	await _card("END_HISTORY", "QuoteText", 8.0)
	await _credits()
	await _card("END_THANKS", "TitleLabel", 3.0, 0.0)
	Game.return_to_menu()

## Shows one centred line, holds it, fades it out (unless `hold_after` is 0).
func _card(key: String, variation: String, seconds: float, hold_after := 0.9) -> void:
	for c in _box.get_children():
		c.queue_free()
	var l := Label.new()
	l.theme_type_variation = StringName(variation)
	l.text = key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(1100, 0)
	l.modulate.a = 0.0
	_box.add_child(l)
	var t := create_tween()
	t.tween_property(l, "modulate:a", 1.0, 1.2)
	t.tween_interval(seconds)
	if hold_after > 0.0:
		t.tween_property(l, "modulate:a", 0.0, 1.0)
		t.tween_interval(hold_after * 0.5)
	await t.finished

func _credits() -> void:
	for c in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "GAME_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	for entry in CreditsDB.ENTRIES:
		var head := Label.new()
		head.theme_type_variation = &"HeaderLabel"
		head.text = entry[0]
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(head)
		if entry[1] != "":
			var body := Label.new()
			body.theme_type_variation = &"BodyText"
			body.text = entry[1]
			body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_box.add_child(body)
	_box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_box, "modulate:a", 1.0, 1.5)
	t.tween_interval(9.0)
	t.tween_property(_box, "modulate:a", 0.0, 1.5)
	await t.finished
	_box.modulate.a = 1.0
