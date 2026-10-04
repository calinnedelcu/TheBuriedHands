class_name DeathScreen
extends CanvasLayer
## Shown by Game.failed: the cause of death, a line about the thousands who
## never left, and a way back to the last checkpoint.

const STING := preload("res://audio/sfx/impacts/impactPunch_medium_001.ogg")

var _root: Control
var _reason: Label

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.modulate.a = 0.0
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.01, 0.008, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "DEATH_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.22))
	v.add_child(title)
	_reason = Label.new()
	_reason.theme_type_variation = &"BodyText"
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(_reason)
	var sub := Label.new()
	sub.theme_type_variation = &"QuoteText"
	sub.text = "DEATH_SUBTITLE"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size = Vector2(800, 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	var retry := Button.new()
	retry.text = "MENU_RETRY"
	retry.pressed.connect(func(): Game.retry_from_checkpoint())
	v.add_child(retry)
	var menu := Button.new()
	menu.text = "MENU_MAIN_MENU"
	menu.pressed.connect(func(): Game.return_to_menu())
	v.add_child(menu)
	Game.failed.connect(_on_failed)

func _on_failed(reason_key: String) -> void:
	_reason.text = tr(reason_key)
	await get_tree().create_timer(1.4).timeout
	Sfx.play_ui(STING, -4.0)
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_root, "modulate:a", 1.0, 1.2)
	await tween.finished
	get_tree().paused = true
	(_root.get_child(1).get_child(0).get_child(4) as Button).grab_focus()
