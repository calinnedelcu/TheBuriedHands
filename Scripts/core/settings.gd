extends Node
## Player-facing settings: persisted to user://settings.cfg, applied live.
## Systems read values with `Settings.get_value()` and react to `changed`.

signal changed(key: StringName, value: Variant)

const FILE := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS := {
	# General
	&"language": "auto",          # "auto" | "ro" | "en"
	&"subtitles": true,
	&"subtitle_scale": 1.0,       # 0.8 .. 1.4
	&"show_hints": true,
	# Controls
	&"mouse_sensitivity": 1.0,    # multiplier, 0.2 .. 3.0
	&"invert_y": false,
	&"crouch_toggle": true,
	&"fov": 75.0,                 # 60 .. 100
	&"head_bob": 1.0,             # 0 .. 1
	# Audio (linear 0..1)
	&"volume_master": 1.0,
	&"volume_music": 0.8,
	&"volume_sfx": 1.0,
	&"volume_dialogue": 1.0,
	# Video
	&"fullscreen": true,
	&"vsync": true,
	&"render_scale": 1.0,         # 0.5 .. 1.0 (FSR 2 when < 1)
	&"quality": 2,                # 0 low, 1 medium, 2 high, 3 ultra
	&"brightness": 1.0,           # 0.6 .. 1.6, exposure multiplier
}

## Volume sliders map onto these buses; the base offsets keep the jam-era mix.
const _BUS_FOR_SETTING := {
	&"volume_master": [&"Master"],
	&"volume_music": [&"Music"],
	&"volume_sfx": [&"SFX", &"Tomb"],
	&"volume_dialogue": [&"Dialogue"],
}
const _BUS_BASE_DB := {&"Master": 0.0, &"Music": -10.0, &"SFX": 0.0, &"Tomb": -2.0, &"Dialogue": 0.0}

var _values: Dictionary = DEFAULTS.duplicate()
var _bindings: Dictionary = {}  # action -> physical keycode / mouse button, user overrides only

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply_all()

func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))

func set_value(key: StringName, value: Variant, save := true) -> void:
	if not DEFAULTS.has(key):
		push_warning("Unknown setting: %s" % key)
		return
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	if save:
		_save()
	changed.emit(key, value)

func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()
	_bindings.clear()
	InputMap.load_from_project_settings()
	apply_all()
	_save()
	for key in _values:
		changed.emit(key, _values[key])

func apply_all() -> void:
	for key in _values:
		# Window mode is left alone when running from the editor so dev runs
		# (and the capture tools) keep their requested window size.
		if key == &"fullscreen" and OS.has_feature("editor"):
			continue
		_apply(key)
	_apply_bindings()

# --- Input remapping ----------------------------------------------------------

## Rebinds `action` to a single key or mouse button (replacing keyboard/mouse
## events, keeping any gamepad events).
func rebind(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	_bindings[action] = _serialize_event(event)
	_apply_binding(action, event)
	_save()
	changed.emit(&"bindings", action)

func binding_label(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key := ev as InputEventKey
			if key.physical_keycode == KEY_NONE:
				return OS.get_keycode_string(key.keycode)
			# Show the key printed on the user's layout (AZERTY shows A for the Q position).
			if DisplayServer.get_name() != "headless":
				return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode))
			return OS.get_keycode_string(key.physical_keycode)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return tr("KEY_MOUSE_LEFT")
				MOUSE_BUTTON_RIGHT: return tr("KEY_MOUSE_RIGHT")
				MOUSE_BUTTON_MIDDLE: return tr("KEY_MOUSE_MIDDLE")
				MOUSE_BUTTON_WHEEL_UP: return tr("KEY_WHEEL_UP")
				MOUSE_BUTTON_WHEEL_DOWN: return tr("KEY_WHEEL_DOWN")
	return "?"

func _apply_bindings() -> void:
	for action in _bindings:
		var ev := _deserialize_event(_bindings[action])
		if ev != null and InputMap.has_action(action):
			_apply_binding(action, ev)

func _apply_binding(action: StringName, event: InputEvent) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			InputMap.action_erase_event(action, ev)
	InputMap.action_add_event(action, event)

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {"type": "key", "code": key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}
	return {}

func _deserialize_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data["code"]) as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data["button"]) as MouseButton
			return mouse
	return null

# --- Applying values ------------------------------------------------------------

func _apply(key: StringName) -> void:
	var value: Variant = _values[key]
	if _BUS_FOR_SETTING.has(key):
		for bus in _BUS_FOR_SETTING[key]:
			_set_bus_volume(bus, float(value))
		return
	match key:
		&"language":
			TranslationServer.set_locale(resolved_language())
		&"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		&"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		&"render_scale":
			var viewport := get_viewport()
			viewport.scaling_3d_scale = clampf(float(value), 0.5, 1.0)
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if float(value) < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		&"quality":
			_apply_quality(clampi(int(value), 0, 3))

## Renderer-wide part of the quality preset. The level's Atmosphere switches
## the environment effects (SSAO, SSIL, SSR) for the same setting.
func _apply_quality(q: int) -> void:
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.positional_shadow_atlas_size = [2048, 4096, 4096, 8192][q]
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 1.0][q]
	var filters := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
	RenderingServer.positional_soft_shadow_filter_set_quality(filters[q])
	RenderingServer.directional_soft_shadow_filter_set_quality(filters[q])
	RenderingServer.environment_set_volumetric_fog_volume_size([64, 96, 128, 160][q], [48, 64, 64, 96][q])

## "auto" follows the OS language: Romanian systems get Romanian, everyone else English.
func resolved_language() -> String:
	var lang := String(_values.get(&"language", "auto"))
	if lang == "auto":
		return "ro" if OS.get_locale_language() == "ro" else "en"
	return lang

func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, v <= 0.001)
	AudioServer.set_bus_volume_db(index, float(_BUS_BASE_DB.get(bus, 0.0)) + linear_to_db(maxf(v, 0.001)))

# --- Persistence ----------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	for key in DEFAULTS:
		if cfg.has_section_key(SECTION, String(key)):
			var stored: Variant = cfg.get_value(SECTION, String(key))
			if typeof(stored) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and stored is int):
				_values[key] = stored
	if cfg.has_section("bindings"):
		for action in cfg.get_section_keys("bindings"):
			_bindings[StringName(action)] = cfg.get_value("bindings", action)

func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value(SECTION, String(key), _values[key])
	for action in _bindings:
		cfg.set_value("bindings", String(action), _bindings[action])
	cfg.save(FILE)
