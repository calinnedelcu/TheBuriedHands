extends Control

const GAME_SCENE := "res://scenes/tomb_layout.tscn"
const MUSIC_TARGET_VOLUME_DB := -16.0
const MUSIC_FADE_SECONDS := 3.0
const PLAY_START_DELAY_SECONDS := 0.42
const SETTINGS_FILE := "user://settings.cfg"
const _BUS_BASE_VOLUME_DB := {
	&"Master": 0.0,
	&"Music": -16.0,
	&"SFX": 0.0,
	&"Tomb": -2.0,
	&"Dialogue": 0.0,
}

const _SETTINGS_BG := preload("res://scenes/ui/meniu-tbh.png")
const _SLIDER_GRABBER := preload("res://scenes/ui/slider_grabber_bronze.svg")
const _SLIDER_GRABBER_HOVER := preload("res://scenes/ui/slider_grabber_bronze_hover.svg")
const _SLIDER_GRABBER_DISABLED := preload("res://scenes/ui/slider_grabber_bronze_disabled.svg")

@onready var music: AudioStreamPlayer = $Music
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var play_start_sound: AudioStreamPlayer = $PlayStartSound
@onready var background: TextureRect = $MenuArea/Content/Background
@onready var flicker: ColorRect = $MenuArea/Content/FlickerOverlay
@onready var dust: CPUParticles2D = $MenuArea/Content/Dust
@onready var embers: CPUParticles2D = $MenuArea/Content/Embers
@onready var drift: CPUParticles2D = $MenuArea/Content/Drift
@onready var content: Control = $MenuArea/Content

var _button_glows: Dictionary = {}
var _is_starting_game := false
var _options_overlay: Control
var _options_settings_art: TextureRect
var _options_values: Dictionary = {}
var _options_sliders: Dictionary = {}
var _loading_options: bool = false
var _options_height_ratio: float = 0.95

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_saved_audio_settings()
	_start_music()

	_button_glows = {
		$MenuArea/Content/PlayButton: $MenuArea/Content/PlayGlow,
		$MenuArea/Content/ContinueButton: $MenuArea/Content/ContinueGlow,
		$MenuArea/Content/OptionsButton: $MenuArea/Content/OptionsGlow,
		$MenuArea/Content/QuitButton: $MenuArea/Content/QuitGlow,
	}

	for btn in _button_glows.keys():
		var glow: Panel = _button_glows[btn]
		btn.mouse_entered.connect(_on_button_hover.bind(glow, true))
		btn.mouse_exited.connect(_on_button_hover.bind(glow, false))
		btn.pressed.connect(_on_button_pressed.bind(glow))
		btn.resized.connect(_sync_glow.bind(btn, glow))
		_sync_glow(btn, glow)

	$MenuArea/Content/PlayButton.pressed.connect(_on_play)
	$MenuArea/Content/ContinueButton.pressed.connect(_on_continue)
	$MenuArea/Content/OptionsButton.pressed.connect(_on_options)
	$MenuArea/Content/QuitButton.pressed.connect(_on_quit)

	content.resized.connect(_on_content_resized)
	_on_content_resized()

	_animate_background()
	_animate_flicker()

	_build_options_overlay()
	_load_options_settings()
	resized.connect(_apply_options_scale)

func _start_music() -> void:
	if not music or not music.stream:
		return

	if music.stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = music.stream
		mp3_stream.loop = true

	music.volume_db = -48.0
	if not music.playing:
		music.play()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(music, "volume_db", MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_SECONDS)

func _apply_saved_audio_settings() -> void:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager != null and settings_manager.has_method("load_settings") and settings_manager.has_method("apply_audio_settings"):
		settings_manager.call("load_settings")
		settings_manager.call("apply_audio_settings")
		return
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return
	_set_bus_linear_volume(&"Master", float(config.get_value("settings", "master_volume", 1.0)))
	_set_bus_linear_volume(&"Music", float(config.get_value("settings", "music_volume", 1.0)))
	var effects_volume := float(config.get_value("settings", "effects_volume", 1.0))
	_set_bus_linear_volume(&"SFX", effects_volume)
	_set_bus_linear_volume(&"Tomb", effects_volume)
	_set_bus_linear_volume(&"Dialogue", float(config.get_value("settings", "dialogue_volume", 1.0)))

func _set_bus_linear_volume(bus_name: StringName, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped := clampf(linear_value, 0.0, 1.0)
	var base_volume_db := float(_BUS_BASE_VOLUME_DB.get(bus_name, 0.0))
	AudioServer.set_bus_volume_db(index, -80.0 if clamped <= 0.001 else base_volume_db + linear_to_db(clamped))

func _sync_glow(btn: Button, glow: Panel) -> void:
	# Match the glow to the button's actual rect, ignoring its own anchors.
	glow.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	glow.global_position = btn.global_position
	glow.size = btn.size
	glow.pivot_offset = glow.size * 0.5

func _on_content_resized() -> void:
	if background:
		background.pivot_offset = background.size * 0.5
	var w := content.size.x
	var h := content.size.y
	if dust:
		dust.position = Vector2(w * 0.5, h + 10.0)
		dust.emission_rect_extents = Vector2(w * 0.5, 6)
	if embers:
		embers.position = Vector2(w * 0.5, h + 4.0)
		embers.emission_rect_extents = Vector2(w * 0.5, 8)
	if drift:
		drift.position = Vector2(w * 0.5, h * 0.45)
		drift.emission_rect_extents = Vector2(w * 0.55, h * 0.35)
	for btn in _button_glows.keys():
		_sync_glow(btn, _button_glows[btn])

func _animate_background() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background, "scale", Vector2(1.022, 1.022), 16.0)
	tween.tween_property(background, "scale", Vector2(1.0, 1.0), 16.0)

func _animate_flicker() -> void:
	while is_inside_tree():
		var target_alpha: float = randf_range(0.02, 0.12)
		var duration: float = randf_range(0.18, 0.55)
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(flicker, "color:a", target_alpha, duration)
		await t.finished
		await get_tree().create_timer(randf_range(0.05, 0.35)).timeout

func _on_button_hover(glow: Panel, entered: bool) -> void:
	var target: float = 0.85 if entered else 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "modulate:a", target, 0.22)

func _on_button_pressed(glow: Panel) -> void:
	_play_click_sound()
	glow.modulate.a = 1.0
	glow.pivot_offset = glow.size * 0.5
	var t := create_tween()
	t.tween_property(glow, "scale", Vector2(1.03, 1.03), 0.08)
	t.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.12)

func _play_click_sound() -> void:
	if click_sound:
		click_sound.stop()
		click_sound.play()

func _on_play() -> void:
	if _is_starting_game:
		return

	_is_starting_game = true
	_set_buttons_disabled(true)
	if play_start_sound:
		play_start_sound.play()

	var music_fade := create_tween()
	music_fade.set_trans(Tween.TRANS_SINE)
	music_fade.set_ease(Tween.EASE_OUT)
	music_fade.tween_property(music, "volume_db", -28.0, PLAY_START_DELAY_SECONDS)

	await get_tree().create_timer(PLAY_START_DELAY_SECONDS).timeout
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _set_buttons_disabled(disabled: bool) -> void:
	for btn in _button_glows.keys():
		btn.disabled = disabled

func _on_options() -> void:
	if _options_overlay.visible:
		_close_options()
		return
	_load_options_settings()
	_apply_options_scale()
	_options_overlay.visible = true
	_set_buttons_disabled(true)

func _close_options() -> void:
	_play_click_sound()
	_options_overlay.visible = false
	_set_buttons_disabled(false)

func _apply_options_scale() -> void:
	if _options_settings_art == null:
		return
	if _options_settings_art.size.y <= 0.0:
		return
	var target_height: float = get_viewport().get_visible_rect().size.y * _options_height_ratio
	var texture_height: float = _displayed_texture_height(_options_settings_art)
	if texture_height <= 0.0:
		texture_height = _options_settings_art.size.y
	var scale_value: float = target_height / texture_height
	_options_settings_art.pivot_offset = _options_settings_art.size * 0.5
	_options_settings_art.scale = Vector2(scale_value, scale_value)

func _displayed_texture_height(texture_rect: TextureRect) -> float:
	if texture_rect.texture == null:
		return texture_rect.size.y
	var texture_size := Vector2(texture_rect.texture.get_width(), texture_rect.texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return texture_rect.size.y
	var texture_aspect: float = texture_size.x / texture_size.y
	var control_aspect: float = texture_rect.size.x / texture_rect.size.y
	if control_aspect > texture_aspect:
		return texture_rect.size.y
	return texture_rect.size.x / texture_aspect

func _build_options_overlay() -> void:
	_options_overlay = Control.new()
	_options_overlay.name = "OptionsOverlay"
	_options_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_overlay.visible = false
	add_child(_options_overlay)

	var dimmer := ColorRect.new()
	dimmer.name = "OptionsDimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.68)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_overlay.add_child(dimmer)

	var settings_art := TextureRect.new()
	settings_art.name = "OptionsSettingsArt"
	settings_art.texture = _SETTINGS_BG
	settings_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	settings_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	settings_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_art.set_anchors_preset(Control.PRESET_CENTER)
	settings_art.offset_left = -257
	settings_art.offset_top = -315
	settings_art.offset_right = 257
	settings_art.offset_bottom = 315
	_options_overlay.add_child(settings_art)
	_options_settings_art = settings_art

	var slider_defs := {
		"sensitivity_x": 123,
		"sensitivity_y": 140,
		"zoom_sensitivity": 157,
		"master_volume": 196,
		"music_volume": 211,
		"effects_volume": 226,
		"dialogue_volume": 241,
	}

	var track_style := StyleBoxFlat.new()
	track_style.content_margin_top = 1
	track_style.content_margin_bottom = 1
	track_style.bg_color = Color(0.19, 0.12, 0.055, 0.62)
	track_style.border_width_top = 1
	track_style.border_width_bottom = 1
	track_style.border_color = Color(0.48, 0.34, 0.17, 0.78)
	track_style.corner_radius_top_left = 1
	track_style.corner_radius_top_right = 1
	track_style.corner_radius_bottom_right = 1
	track_style.corner_radius_bottom_left = 1

	var fill_style := StyleBoxFlat.new()
	fill_style.content_margin_top = 1
	fill_style.content_margin_bottom = 1
	fill_style.bg_color = Color(0.62, 0.4, 0.18, 0.82)
	fill_style.border_width_top = 1
	fill_style.border_width_bottom = 1
	fill_style.border_color = Color(0.92, 0.68, 0.33, 0.82)
	fill_style.corner_radius_top_left = 1
	fill_style.corner_radius_top_right = 1
	fill_style.corner_radius_bottom_right = 1
	fill_style.corner_radius_bottom_left = 1

	var fill_hover_style := StyleBoxFlat.new()
	fill_hover_style.content_margin_top = 1
	fill_hover_style.content_margin_bottom = 1
	fill_hover_style.bg_color = Color(0.78, 0.5, 0.22, 0.94)
	fill_hover_style.border_width_top = 1
	fill_hover_style.border_width_bottom = 1
	fill_hover_style.border_color = Color(1, 0.78, 0.42, 0.95)
	fill_hover_style.corner_radius_top_left = 1
	fill_hover_style.corner_radius_top_right = 1
	fill_hover_style.corner_radius_bottom_right = 1
	fill_hover_style.corner_radius_bottom_left = 1

	for key: String in slider_defs:
		var y_pos: int = slider_defs[key]
		var slider := HSlider.new()
		slider.name = key.capitalize() + "Slider"
		slider.custom_minimum_size = Vector2(0, 8)
		slider.offset_left = 178
		slider.offset_top = y_pos
		slider.offset_right = 368
		slider.offset_bottom = y_pos + 12
		slider.step = 0.01
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slider.add_theme_icon_override("grabber", _SLIDER_GRABBER)
		slider.add_theme_icon_override("grabber_highlight", _SLIDER_GRABBER_HOVER)
		slider.add_theme_icon_override("grabber_disabled", _SLIDER_GRABBER_DISABLED)
		slider.add_theme_stylebox_override("slider", track_style)
		slider.add_theme_stylebox_override("grabber_area", fill_style)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill_hover_style)
		slider.value_changed.connect(_on_option_slider_changed.bind(key))
		settings_art.add_child(slider)
		_options_sliders[key] = slider

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.88, 0.58, 0.18, 0.22)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1, 0.75, 0.35, 0.65)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.75, 0.36, 0.12, 0.42)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.border_color = Color(1, 0.62, 0.28, 0.9)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.95, 0.68, 0.22, 0.34)
	btn_hover.border_width_left = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = Color(1, 0.86, 0.48, 0.85)

	var close_button := Button.new()
	close_button.name = "OptionsCloseButton"
	close_button.offset_left = 178
	close_button.offset_top = 550
	close_button.offset_right = 368
	close_button.offset_bottom = 582
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_color_override("font_color", Color(1, 0.9, 0.62, 0.95))
	close_button.add_theme_stylebox_override("normal", btn_normal)
	close_button.add_theme_stylebox_override("pressed", btn_pressed)
	close_button.add_theme_stylebox_override("hover", btn_hover)
	close_button.add_theme_stylebox_override("disabled", btn_normal)
	close_button.add_theme_stylebox_override("focus", btn_hover)
	close_button.pressed.connect(_close_options)
	settings_art.add_child(close_button)

func _load_options_settings() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm != null and sm.has_method("get_all_settings"):
		_options_values = sm.call("get_all_settings")
	else:
		_options_values = {
			"sensitivity_x": 0.27272728,
			"sensitivity_y": 0.27272728,
			"zoom_sensitivity": 0.42307693,
			"master_volume": 1.0,
			"music_volume": 1.0,
			"effects_volume": 1.0,
			"dialogue_volume": 1.0,
		}
		var config := ConfigFile.new()
		if config.load(SETTINGS_FILE) == OK:
			for k: String in _options_values.keys():
				_options_values[k] = clampf(float(config.get_value("settings", k, _options_values[k])), 0.0, 1.0)
	_loading_options = true
	for key: String in _options_sliders.keys():
		var slider: HSlider = _options_sliders[key]
		slider.value = float(_options_values.get(key, 1.0))
	_loading_options = false

func _on_option_slider_changed(value: float, key: String) -> void:
	if _loading_options:
		return
	_options_values[key] = clampf(value, 0.0, 1.0)
	_apply_options_audio()
	var sm := get_node_or_null("/root/SettingsManager")
	if sm != null and sm.has_method("set_settings"):
		sm.call("set_settings", _options_values, true)
	else:
		var config := ConfigFile.new()
		for k: String in _options_values.keys():
			config.set_value("settings", k, float(_options_values[k]))
		config.save(SETTINGS_FILE)

func _apply_options_audio() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm != null and sm.has_method("set_settings"):
		sm.call("set_settings", _options_values, false)
		return
	_set_bus_linear_volume(&"Master", float(_options_values.get("master_volume", 1.0)))
	_set_bus_linear_volume(&"Music", float(_options_values.get("music_volume", 1.0)))
	var effects_volume := float(_options_values.get("effects_volume", 1.0))
	_set_bus_linear_volume(&"SFX", effects_volume)
	_set_bus_linear_volume(&"Tomb", effects_volume)
	_set_bus_linear_volume(&"Dialogue", float(_options_values.get("dialogue_volume", 1.0)))

func _unhandled_input(event: InputEvent) -> void:
	if not _options_overlay.visible:
		return
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_close_options()

func _on_quit() -> void:
	get_tree().quit()
