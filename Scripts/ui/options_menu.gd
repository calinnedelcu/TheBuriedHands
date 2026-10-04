class_name OptionsMenu
extends PanelContainer
## Settings screen shared by the main menu and the pause menu. Every control
## writes straight into Settings, which applies and saves immediately.

signal closed

const BINDABLE := [
	&"move_forward", &"move_backward", &"move_left", &"move_right", &"sprint", &"jump",
	&"crouch", &"crawl", &"interact", &"toggle_lamp", &"raise_lamp", &"hold_breath",
	&"throw", &"drop", &"journal", &"skip_line",
]

var _binding_buttons: Dictionary = {}
var _waiting_action: StringName = &""

func _ready() -> void:
	theme_type_variation = &"LacquerPanel"
	custom_minimum_size = Vector2(980, 700)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 46)
	title.text = "MENU_OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_game_tab())
	tabs.add_child(_controls_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_video_tab())
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, ["OPT_TAB_GAME", "OPT_TAB_CONTROLS", "OPT_TAB_AUDIO", "OPT_TAB_VIDEO"][i])

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 40)
	var reset := Button.new()
	reset.theme_type_variation = &"SmallButton"
	reset.text = "OPT_RESET"
	reset.pressed.connect(_on_reset)
	var back := Button.new()
	back.theme_type_variation = &"SmallButton"
	back.text = "MENU_BACK"
	back.pressed.connect(func(): closed.emit())
	footer.add_child(reset)
	footer.add_child(back)
	v.add_child(footer)

# --- Tabs ---------------------------------------------------------------------------

func _page() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	return grid

func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	s.add_child(margin)
	return s

func _game_tab() -> Control:
	var g := _page()
	_option(g, "OPT_LANGUAGE", &"language", ["auto", "ro", "en"], ["OPT_LANG_AUTO", "OPT_LANG_RO", "OPT_LANG_EN"])
	_check(g, "OPT_SUBTITLES", &"subtitles")
	_slider(g, "OPT_SUBTITLE_SIZE", &"subtitle_scale", 0.8, 1.4, 0.05)
	_check(g, "OPT_HINTS", &"show_hints")
	var s := _scroll(g)
	s.name = "Game"
	return s

func _controls_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	var g := _page()
	_slider(g, "OPT_SENSITIVITY", &"mouse_sensitivity", 0.2, 3.0, 0.05)
	_check(g, "OPT_INVERT_Y", &"invert_y")
	_check(g, "OPT_CROUCH_TOGGLE", &"crouch_toggle")
	_slider(g, "OPT_FOV", &"fov", 60.0, 100.0, 1.0)
	_slider(g, "OPT_HEAD_BOB", &"head_bob", 0.0, 1.0, 0.05)
	v.add_child(g)
	var header := Label.new()
	header.theme_type_variation = &"HeaderLabel"
	header.text = "OPT_BINDINGS"
	v.add_child(header)
	var binds := _page()
	for action in BINDABLE:
		var l := Label.new()
		l.text = "ACTION_" + String(action).to_upper()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binds.add_child(l)
		var b := Button.new()
		b.theme_type_variation = &"SmallButton"
		b.custom_minimum_size = Vector2(240, 0)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(_begin_rebind.bind(action))
		binds.add_child(b)
		_binding_buttons[action] = b
	v.add_child(binds)
	_refresh_bindings()
	var s := _scroll(v)
	s.name = "Controls"
	return s

func _audio_tab() -> Control:
	var g := _page()
	_slider(g, "OPT_VOL_MASTER", &"volume_master", 0.0, 1.0, 0.01)
	_slider(g, "OPT_VOL_MUSIC", &"volume_music", 0.0, 1.0, 0.01)
	_slider(g, "OPT_VOL_SFX", &"volume_sfx", 0.0, 1.0, 0.01)
	_slider(g, "OPT_VOL_DIALOGUE", &"volume_dialogue", 0.0, 1.0, 0.01)
	var s := _scroll(g)
	s.name = "Audio"
	return s

func _video_tab() -> Control:
	var g := _page()
	_check(g, "OPT_FULLSCREEN", &"fullscreen")
	_check(g, "OPT_VSYNC", &"vsync")
	_option(g, "OPT_QUALITY", &"quality", [0, 1, 2, 3], ["OPT_QUALITY_0", "OPT_QUALITY_1", "OPT_QUALITY_2", "OPT_QUALITY_3"])
	_slider(g, "OPT_RENDER_SCALE", &"render_scale", 0.5, 1.0, 0.05)
	_slider(g, "OPT_BRIGHTNESS", &"brightness", 0.6, 1.6, 0.05)
	var s := _scroll(g)
	s.name = "Video"
	return s

# --- Control builders -------------------------------------------------------------------

func _row_label(grid: GridContainer, key: String) -> void:
	var l := Label.new()
	l.text = key
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)

func _slider(grid: GridContainer, key: String, setting: StringName, min_v: float, max_v: float, step: float) -> void:
	_row_label(grid, key)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(380, 0)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(Settings.get_value(setting))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.theme_type_variation = &"SmallLabel"
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var show := func(v: float) -> void:
		value_label.text = str(int(round(v))) if step >= 1.0 else ("%d%%" % int(round(v * 100.0)) if max_v <= 1.0 else "%.2f" % v)
	show.call(slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		show.call(v)
		Settings.set_value(setting, v))
	h.add_child(slider)
	h.add_child(value_label)
	grid.add_child(h)

func _check(grid: GridContainer, key: String, setting: StringName) -> void:
	_row_label(grid, key)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(setting))
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(setting, on))
	grid.add_child(c)

func _option(grid: GridContainer, key: String, setting: StringName, values: Array, labels: Array) -> void:
	_row_label(grid, key)
	var o := OptionButton.new()
	for i in labels.size():
		o.add_item(labels[i], i)
	o.select(maxi(0, values.find(Settings.get_value(setting))))
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(setting, values[i]))
	grid.add_child(o)

# --- Rebinding -------------------------------------------------------------------------

func _begin_rebind(action: StringName) -> void:
	_waiting_action = action
	(_binding_buttons[action] as Button).text = tr("OPT_PRESS_KEY")

func _input(event: InputEvent) -> void:
	if _waiting_action == &"" or not is_visible_in_tree():
		return
	var is_key: bool = event is InputEventKey and event.is_pressed() and not event.is_echo()
	var is_mouse: bool = event is InputEventMouseButton and event.is_pressed()
	if not (is_key or is_mouse):
		return
	get_viewport().set_input_as_handled()
	if is_key and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_waiting_action = &""
		_refresh_bindings()
		return
	Settings.rebind(_waiting_action, event)
	_waiting_action = &""
	_refresh_bindings()

func _refresh_bindings() -> void:
	for action in _binding_buttons:
		(_binding_buttons[action] as Button).text = Settings.binding_label(action)

func _on_reset() -> void:
	Settings.reset_to_defaults()
	# Rebuild to reflect defaults everywhere.
	for c in get_children():
		c.queue_free()
	_binding_buttons.clear()
	_ready.call_deferred()
