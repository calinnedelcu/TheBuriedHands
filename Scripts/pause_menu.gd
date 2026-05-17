extends CanvasLayer

@export var main_menu_scene: String = "res://scenes/main_menu.tscn"
@export var pause_texture: Texture2D
@export var settings_texture: Texture2D
@export var show_click_zones: bool = true
@export_range(0.1, 1.0, 0.01) var settings_height_ratio: float = 0.95

const _CLICK_SFX = preload("res://audio/sfx/menu_click.wav")
const _SETTINGS_FILE := "user://settings.cfg"
const _LOOK_SENSITIVITY_MIN := 0.0005
const _LOOK_SENSITIVITY_MAX := 0.006
const _ZOOM_SENSITIVITY_MIN := 0.2
const _ZOOM_SENSITIVITY_MAX := 1.5
const _BUS_BASE_VOLUME_DB := {
	&"Master": 0.0,
	&"Music": -16.0,
	&"SFX": 0.0,
	&"Tomb": -2.0,
	&"Dialogue": 0.0,
}

@onready var _root: Control = $Root
@onready var _pause_art: TextureRect = $Root/PauseArt
@onready var _settings_art: TextureRect = $Root/SettingsArt
@onready var _continue_button: Button = $Root/PauseArt/ContinueButton
@onready var _main_menu_button: Button = $Root/PauseArt/MainMenuButton
@onready var _settings_button: Button = $Root/PauseArt/SettingsButton
@onready var _quit_button: Button = $Root/PauseArt/QuitButton
@onready var _settings_close_button: Button = $Root/SettingsArt.get_node_or_null("SettingsCloseButton")
@onready var _sensitivity_x_slider: HSlider = get_node_or_null("Root/SettingsArt/SensitivityXSlider") as HSlider
@onready var _sensitivity_y_slider: HSlider = get_node_or_null("Root/SettingsArt/SensitivityYSlider") as HSlider
@onready var _zoom_sensitivity_slider: HSlider = get_node_or_null("Root/SettingsArt/ZoomSensitivitySlider") as HSlider
@onready var _master_volume_slider: HSlider = get_node_or_null("Root/SettingsArt/MasterVolumeSlider") as HSlider
@onready var _music_volume_slider: HSlider = get_node_or_null("Root/SettingsArt/MusicVolumeSlider") as HSlider
@onready var _effects_volume_slider: HSlider = get_node_or_null("Root/SettingsArt/EffectsVolumeSlider") as HSlider
@onready var _dialogue_volume_slider: HSlider = get_node_or_null("Root/SettingsArt/DialogueVolumeSlider") as HSlider

var _button_glows: Dictionary = {}
var _settings_sliders: Dictionary = {}
var _settings_values: Dictionary = {}
var _click_sound: AudioStreamPlayer
var _is_paused: bool = false
var _was_mouse_captured: bool = true
var _showing_settings: bool = false
var _loading_settings: bool = false
var _blur_rect: ColorRect = null
var _blur_tween: Tween = null

const _BLUR_SHADER: String = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 2.5;
uniform float darken : hint_range(0.0, 1.0) = 0.25;
void fragment() {
	vec3 col = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	col *= (1.0 - darken);
	COLOR = vec4(col, 1.0);
}
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_build_blur_layer()
	_pause_art.pivot_offset = _pause_art.size * 0.5
	_settings_art.pivot_offset = _settings_art.size * 0.5
	_setup_settings_sliders()
	_load_settings()
	_apply_all_settings()
	_setup_click_sound()
	_setup_button_effects()
	_continue_button.pressed.connect(func(): _set_paused(false))
	_main_menu_button.pressed.connect(_on_main_menu)
	_settings_button.pressed.connect(_show_settings_view)
	_quit_button.pressed.connect(_on_quit)
	if _settings_close_button != null:
		_settings_close_button.pressed.connect(_show_pause_view)
	_root.resized.connect(_on_root_resized)
	_pause_art.resized.connect(_on_pause_art_resized)
	_settings_art.resized.connect(_on_settings_art_resized)
	_apply_click_zone_visibility()
	_show_pause_view()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_pause_toggle_event(event):
		return
	if _is_paused:
		_set_paused(false)
	else:
		_set_paused(true)
	get_viewport().set_input_as_handled()

func _is_pause_toggle_event(event: InputEvent) -> bool:
	if event.is_action_pressed("pause"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F6

func _set_paused(p: bool) -> void:
	_is_paused = p
	get_tree().paused = p
	_root.visible = p
	_animate_blur(p)
	if p:
		_was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_pause_view()
	else:
		if _was_mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _show_pause_view() -> void:
	_showing_settings = false
	if pause_texture != null:
		_pause_art.texture = pause_texture
	_pause_art.visible = true
	_settings_art.visible = false
	_settings_art.scale = Vector2.ONE
	_hide_all_glows()

func _show_settings_view() -> void:
	_showing_settings = true
	if settings_texture != null:
		_settings_art.texture = settings_texture
	_pause_art.visible = false
	_settings_art.visible = true
	_apply_settings_scale()
	_hide_all_glows()

func _on_root_resized() -> void:
	if _showing_settings:
		_apply_settings_scale()

func _on_pause_art_resized() -> void:
	_pause_art.pivot_offset = _pause_art.size * 0.5

func _on_settings_art_resized() -> void:
	_settings_art.pivot_offset = _settings_art.size * 0.5
	if _showing_settings:
		_apply_settings_scale()

func _apply_settings_scale() -> void:
	if _settings_art.size.y <= 0.0:
		return
	var target_height: float = get_viewport().get_visible_rect().size.y * settings_height_ratio
	var texture_height: float = _displayed_texture_height(_settings_art, _settings_art.size)
	if texture_height <= 0.0:
		texture_height = _settings_art.size.y
	var scale_value: float = target_height / texture_height
	_settings_art.scale = Vector2(scale_value, scale_value)

func _displayed_texture_height(texture_rect: TextureRect, control_size: Vector2) -> float:
	if texture_rect.texture == null:
		return control_size.y
	var texture_size := Vector2(texture_rect.texture.get_width(), texture_rect.texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return control_size.y
	var texture_aspect: float = texture_size.x / texture_size.y
	var control_aspect: float = control_size.x / control_size.y
	if control_aspect > texture_aspect:
		return control_size.y
	return control_size.x / texture_aspect

func _setup_settings_sliders() -> void:
	_settings_sliders = {
		"sensitivity_x": _sensitivity_x_slider,
		"sensitivity_y": _sensitivity_y_slider,
		"zoom_sensitivity": _zoom_sensitivity_slider,
		"master_volume": _master_volume_slider,
		"music_volume": _music_volume_slider,
		"effects_volume": _effects_volume_slider,
		"dialogue_volume": _dialogue_volume_slider,
	}
	for key: String in _settings_sliders.keys():
		var slider := _settings_sliders[key] as HSlider
		if slider == null:
			continue
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value_changed.connect(_on_setting_slider_changed.bind(key))

func _default_settings() -> Dictionary:
	return {
		"sensitivity_x": inverse_lerp(_LOOK_SENSITIVITY_MIN, _LOOK_SENSITIVITY_MAX, 0.002),
		"sensitivity_y": inverse_lerp(_LOOK_SENSITIVITY_MIN, _LOOK_SENSITIVITY_MAX, 0.002),
		"zoom_sensitivity": inverse_lerp(_ZOOM_SENSITIVITY_MIN, _ZOOM_SENSITIVITY_MAX, 0.75),
		"master_volume": 1.0,
		"music_volume": 1.0,
		"effects_volume": 1.0,
		"dialogue_volume": 1.0,
	}

func _load_settings() -> void:
	var settings_manager := _settings_manager()
	if settings_manager != null and settings_manager.has_method("get_all_settings"):
		_settings_values = settings_manager.call("get_all_settings")
	else:
		_settings_values = _default_settings()
		var config := ConfigFile.new()
		if config.load(_SETTINGS_FILE) == OK:
			for key: String in _settings_values.keys():
				if config.has_section_key("settings", key):
					_settings_values[key] = clampf(float(config.get_value("settings", key)), 0.0, 1.0)
	_loading_settings = true
	for key: String in _settings_sliders.keys():
		var slider := _settings_sliders[key] as HSlider
		if slider != null:
			slider.value = float(_settings_values.get(key, 1.0))
	_loading_settings = false

func _save_settings() -> void:
	var settings_manager := _settings_manager()
	if settings_manager != null and settings_manager.has_method("set_settings"):
		settings_manager.call("set_settings", _settings_values, true)
		return
	var config := ConfigFile.new()
	for key: String in _settings_values.keys():
		config.set_value("settings", key, float(_settings_values[key]))
	config.save(_SETTINGS_FILE)

func _on_setting_slider_changed(value: float, key: String) -> void:
	if _loading_settings:
		return
	_settings_values[key] = clampf(value, 0.0, 1.0)
	_apply_all_settings()
	_save_settings()

func _apply_all_settings() -> void:
	_apply_look_settings()
	_apply_audio_settings()

func _apply_look_settings() -> void:
	var sensitivity_x := lerpf(_LOOK_SENSITIVITY_MIN, _LOOK_SENSITIVITY_MAX, float(_settings_values.get("sensitivity_x", 0.27)))
	var sensitivity_y := lerpf(_LOOK_SENSITIVITY_MIN, _LOOK_SENSITIVITY_MAX, float(_settings_values.get("sensitivity_y", 0.27)))
	var zoom_multiplier := lerpf(_ZOOM_SENSITIVITY_MIN, _ZOOM_SENSITIVITY_MAX, float(_settings_values.get("zoom_sensitivity", 0.42)))
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_method("set_look_settings"):
		player.call("set_look_settings", sensitivity_x, sensitivity_y, zoom_multiplier)
	elif "mouse_sensitivity" in player:
		player.set("mouse_sensitivity", (sensitivity_x + sensitivity_y) * 0.5)

func _apply_audio_settings() -> void:
	var settings_manager := _settings_manager()
	if settings_manager != null and settings_manager.has_method("set_settings"):
		settings_manager.call("set_settings", _settings_values, false)
		return
	_ensure_audio_bus(&"Music")
	_ensure_audio_bus(&"SFX")
	_ensure_audio_bus(&"Dialogue")
	_set_bus_linear_volume(&"Master", float(_settings_values.get("master_volume", 1.0)))
	_set_bus_linear_volume(&"Music", float(_settings_values.get("music_volume", 1.0)))
	var effects_volume := float(_settings_values.get("effects_volume", 1.0))
	_set_bus_linear_volume(&"SFX", effects_volume)
	_set_bus_linear_volume(&"Tomb", effects_volume)
	_set_bus_linear_volume(&"Dialogue", float(_settings_values.get("dialogue_volume", 1.0)))

func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")

func _set_bus_linear_volume(bus_name: StringName, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped := clampf(linear_value, 0.0, 1.0)
	var base_volume_db := float(_BUS_BASE_VOLUME_DB.get(bus_name, 0.0))
	AudioServer.set_bus_volume_db(index, -80.0 if clamped <= 0.001 else base_volume_db + linear_to_db(clamped))

func _settings_manager() -> Node:
	return get_node_or_null("/root/SettingsManager")

func _apply_click_zone_visibility() -> void:
	var alpha := 1.0 if show_click_zones else 0.0
	for button: Button in _menu_buttons():
		button.modulate.a = alpha

func _setup_click_sound() -> void:
	_click_sound = AudioStreamPlayer.new()
	_click_sound.name = "ClickSound"
	_click_sound.stream = _CLICK_SFX
	_click_sound.volume_db = -8.0
	_click_sound.bus = &"SFX"
	_click_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_click_sound)

func _setup_button_effects() -> void:
	for button: Button in _menu_buttons():
		var glow := Panel.new()
		glow.name = "%sGlow" % button.name
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.modulate.a = 0.0
		glow.add_theme_stylebox_override("panel", _make_glow_style())
		var parent_control := button.get_parent() as Control
		parent_control.add_child(glow)
		parent_control.move_child(glow, button.get_index())
		_button_glows[button] = glow
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))
		button.pressed.connect(_on_button_pressed.bind(button))
		button.resized.connect(_sync_glow.bind(button))
		_sync_glow(button)

func _make_glow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.65, 0.3, 0.0)
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.82, 0.5, 0.75)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.shadow_color = Color(1.0, 0.55, 0.22, 0.18)
	style.shadow_size = 6
	return style

func _sync_glow(button: Button) -> void:
	var glow: Panel = _button_glows.get(button)
	if glow == null:
		return
	glow.position = button.position
	glow.size = button.size
	glow.pivot_offset = glow.size * 0.5

func _on_button_hover(button: Button, entered: bool) -> void:
	var glow: Panel = _button_glows.get(button)
	if glow == null:
		return
	_sync_glow(button)
	var target := 0.85 if entered else 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", target, 0.22)

func _on_button_pressed(button: Button) -> void:
	var glow: Panel = _button_glows.get(button)
	if glow == null:
		return
	_play_click_sound()
	_sync_glow(button)
	glow.modulate.a = 1.0
	glow.scale = Vector2.ONE
	glow.pivot_offset = glow.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(glow, "scale", Vector2(1.03, 1.03), 0.08)
	tween.tween_property(glow, "scale", Vector2.ONE, 0.12)

func _hide_all_glows() -> void:
	for glow: Panel in _button_glows.values():
		glow.modulate.a = 0.0
		glow.scale = Vector2.ONE

func _play_click_sound() -> void:
	if _click_sound == null:
		return
	_click_sound.stop()
	_click_sound.play()

func _menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = [
		_continue_button,
		_main_menu_button,
		_settings_button,
		_quit_button,
	]
	if _settings_close_button != null:
		buttons.append(_settings_close_button)
	return buttons

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func _on_quit() -> void:
	get_tree().quit()

func _build_blur_layer() -> void:
	_blur_rect = ColorRect.new()
	_blur_rect.name = "BlurOverlay"
	_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_rect.color = Color(1, 1, 1, 1)
	var shader := Shader.new()
	shader.code = _BLUR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("blur_lod", 0.0)
	mat.set_shader_parameter("darken", 0.0)
	_blur_rect.material = mat
	_blur_rect.visible = false
	add_child(_blur_rect)
	# Plasam blur-ul SUB Root (panoul de pauza), nu peste el.
	move_child(_blur_rect, _root.get_index())

func _animate_blur(active: bool) -> void:
	if _blur_rect == null:
		return
	if _blur_tween != null and _blur_tween.is_running():
		_blur_tween.kill()
	var mat: ShaderMaterial = _blur_rect.material as ShaderMaterial
	if mat == null:
		return
	if active:
		_blur_rect.visible = true
		mat.set_shader_parameter("blur_lod", 0.0)
		mat.set_shader_parameter("darken", 0.0)
		_blur_tween = create_tween()
		_blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_blur_tween.set_parallel(true)
		_blur_tween.tween_method(_set_blur_lod, 0.0, 2.6, 0.25).set_trans(Tween.TRANS_QUAD)
		_blur_tween.tween_method(_set_blur_darken, 0.0, 0.28, 0.25).set_trans(Tween.TRANS_QUAD)
	else:
		_blur_tween = create_tween()
		_blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_blur_tween.set_parallel(true)
		_blur_tween.tween_method(_set_blur_lod, mat.get_shader_parameter("blur_lod") as float, 0.0, 0.18).set_trans(Tween.TRANS_QUAD)
		_blur_tween.tween_method(_set_blur_darken, mat.get_shader_parameter("darken") as float, 0.0, 0.18).set_trans(Tween.TRANS_QUAD)
		_blur_tween.chain().tween_callback(func(): _blur_rect.visible = false)

func _set_blur_lod(v: float) -> void:
	if _blur_rect != null and _blur_rect.material is ShaderMaterial:
		(_blur_rect.material as ShaderMaterial).set_shader_parameter("blur_lod", v)

func _set_blur_darken(v: float) -> void:
	if _blur_rect != null and _blur_rect.material is ShaderMaterial:
		(_blur_rect.material as ShaderMaterial).set_shader_parameter("darken", v)
