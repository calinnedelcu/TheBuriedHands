class_name PauseMenu
extends CanvasLayer
## Esc pauses the game behind a blurred, darkened view of the tomb.

const BLUR_SHADER := preload("res://assets/shaders/ui/blur.gdshader")
const CLICK := preload("res://audio/sfx/ui/click_001.ogg")

var _root: Control
var _menu: VBoxContainer
var _options: OptionsMenu
var _blur_mat: ShaderMaterial
var _was_captured := true

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var blur := ColorRect.new()
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = BLUR_SHADER
	blur.material = _blur_mat
	_root.add_child(blur)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	center.add_child(_menu)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "MENU_PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	_menu.add_child(spacer)
	_button("MENU_RESUME", func(): set_paused(false))
	_button("MENU_OPTIONS", _show_options)
	_button("MENU_MAIN_MENU", func(): Game.return_to_menu())
	_button("MENU_QUIT", func(): Game.quit_game())

	_options = OptionsMenu.new()
	_options.visible = false
	_options.closed.connect(_hide_options)
	center.add_child(_options)

func _button(key: String, action: Callable) -> void:
	var b := Button.new()
	b.text = key
	b.pressed.connect(func():
		Sfx.play_ui(CLICK, -8.0)
		action.call())
	_menu.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or Game.is_over():
		return
	get_viewport().set_input_as_handled()
	if _options.visible:
		_hide_options()
	else:
		set_paused(not _root.visible)

func set_paused(value: bool) -> void:
	# Co-op: the tomb doesn't stop for one of you; only your hands do.
	if Net.active:
		var me := Net.local_body()
		if me != null:
			if value:
				me.lock_controls(&"pause")
			else:
				me.unlock_controls(&"pause")
	else:
		get_tree().paused = value
	_root.visible = value
	if value:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hide_options()
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(func(v: float): _blur_mat.set_shader_parameter(&"amount", v), 0.0, 1.0, 0.25)
		(_menu.get_child(2) as Button).grab_focus.call_deferred()
	elif _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_options() -> void:
	_menu.visible = false
	_options.visible = true

func _hide_options() -> void:
	_options.visible = false
	_menu.visible = true
