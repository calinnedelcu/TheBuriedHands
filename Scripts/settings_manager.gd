extends Node

signal setting_changed(key: String, value: float)
signal settings_applied()

const SETTINGS_FILE := "user://settings.cfg"

const DEFAULT_SETTINGS := {
	"sensitivity_x": 0.27272728,
	"sensitivity_y": 0.27272728,
	"zoom_sensitivity": 0.42307693,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"effects_volume": 1.0,
	"dialogue_volume": 1.0,
}

const _AUDIO_BUSES := {
	"master_volume": [&"Master"],
	"music_volume": [&"Music"],
	"effects_volume": [&"SFX", &"Tomb"],
	"dialogue_volume": [&"Dialogue"],
}

const _BUS_BASE_VOLUME_DB := {
	&"Master": 0.0,
	&"Music": -16.0,
	&"SFX": 0.0,
	&"Tomb": -2.0,
	&"Dialogue": 0.0,
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()

func _ready() -> void:
	load_settings()
	apply_audio_settings()

func default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate()

func get_all_settings() -> Dictionary:
	var values := DEFAULT_SETTINGS.duplicate()
	for key: String in _settings.keys():
		values[key] = _settings[key]
	return values

func get_setting(key: String, fallback: float = 1.0) -> float:
	return float(_settings.get(key, DEFAULT_SETTINGS.get(key, fallback)))

func set_setting(key: String, value: float, save_after: bool = true) -> void:
	_settings[key] = clampf(value, 0.0, 1.0)
	if _AUDIO_BUSES.has(key):
		apply_audio_settings()
	if save_after:
		save_settings()
	setting_changed.emit(key, float(_settings[key]))

func set_settings(values: Dictionary, save_after: bool = true) -> void:
	for key: String in DEFAULT_SETTINGS.keys():
		if values.has(key):
			_settings[key] = clampf(float(values[key]), 0.0, 1.0)
	apply_audio_settings()
	if save_after:
		save_settings()
	settings_applied.emit()

func load_settings() -> void:
	_settings = DEFAULT_SETTINGS.duplicate()
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return
	for key: String in DEFAULT_SETTINGS.keys():
		if config.has_section_key("settings", key):
			_settings[key] = clampf(float(config.get_value("settings", key)), 0.0, 1.0)

func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in DEFAULT_SETTINGS.keys():
		config.set_value("settings", key, float(_settings.get(key, DEFAULT_SETTINGS[key])))
	config.save(SETTINGS_FILE)

func apply_audio_settings() -> void:
	_ensure_audio_bus(&"Tomb")
	_ensure_audio_bus(&"Music")
	_ensure_audio_bus(&"SFX")
	_ensure_audio_bus(&"Dialogue")
	for key: String in _AUDIO_BUSES.keys():
		var value := float(_settings.get(key, DEFAULT_SETTINGS.get(key, 1.0)))
		for bus_name: StringName in _AUDIO_BUSES[key]:
			_set_bus_linear_volume(bus_name, value)
	settings_applied.emit()

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
