class_name Atmosphere
extends Node
## Owns the level's Environment at runtime: blends fog, ambient light and
## grading toward the AtmosphereZone the player is in, and applies the
## environment side of the quality preset and the brightness setting.

@export var environment_path: NodePath
## Seconds to settle into a new zone's air.
@export var blend_time := 2.5

var _env: Environment
var _base := {}
var _current := {}
var _target := {}
var _player: Node3D
var _check := 0.0
var _zone: AtmosphereZone = null
var _zone_music: StringName = &""

func _ready() -> void:
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we == null or we.environment == null:
		set_process(false)
		return
	_env = we.environment
	_base = _read()
	_current = _base.duplicate()
	_target = _base
	_apply_quality()
	_write(_current)
	Music.set_ambience(&"tomb")
	Settings.changed.connect(_on_setting)
	Game.level_ready.connect(func(_l): snap.call_deferred(), CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		_target = _pick_target()
	var k := 1.0 - exp(-delta / maxf(blend_time * 0.4, 0.01))
	for key in _current:
		_current[key] = _lerp(_current[key], _target[key], k)
	_write(_current)

## Jumps straight to the air of wherever the player is (after a teleport or
## a checkpoint load) instead of blending.
func snap() -> void:
	if _env == null:
		return
	_target = _pick_target()
	_current = _target.duplicate()
	_write(_current)

func _pick_target() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return _base
	var best: AtmosphereZone = null
	for z in get_tree().get_nodes_in_group(&"atmosphere_zones"):
		var zone := z as AtmosphereZone
		if zone.overlaps_body(_player) and (best == null or zone.zone_priority > best.zone_priority):
			best = zone
	_update_sound(best)
	return best.profile() if best != null else _base

## Music and ambience follow the zone too (a zone's music can change while
## the player stands in it, when its flag gets set).
func _update_sound(zone: AtmosphereZone) -> void:
	var music := zone.music_track() if zone != null else &""
	if zone != _zone:
		_zone = zone
		Music.set_ambience(zone.ambience if zone != null and zone.ambience != &"" else &"tomb")
	if music != _zone_music:
		_zone_music = music
		if music == &"silence":
			Music.stop(3.0)
		elif music != &"":
			Music.play(music, 4.0)

func _lerp(a: Variant, b: Variant, k: float) -> Variant:
	if a is Color:
		return (a as Color).lerp(b, k)
	return lerpf(float(a), float(b), k)

func _read() -> Dictionary:
	return {
		"fog_color": _env.fog_light_color,
		"fog_density": _env.fog_density,
		"volumetric_density": _env.volumetric_fog_density,
		"volumetric_albedo": _env.volumetric_fog_albedo,
		"volumetric_emission": _env.volumetric_fog_emission,
		"volumetric_emission_energy": _env.volumetric_fog_emission_energy,
		"ambient_color": _env.ambient_light_color,
		"ambient_energy": _env.ambient_light_energy,
		"saturation": _env.adjustment_saturation,
		"exposure": _env.tonemap_exposure,
	}

func _write(p: Dictionary) -> void:
	_env.fog_light_color = p["fog_color"]
	_env.fog_density = p["fog_density"]
	_env.volumetric_fog_density = p["volumetric_density"]
	_env.volumetric_fog_albedo = p["volumetric_albedo"]
	_env.volumetric_fog_emission = p["volumetric_emission"]
	_env.volumetric_fog_emission_energy = p["volumetric_emission_energy"]
	_env.ambient_light_color = p["ambient_color"]
	_env.ambient_light_energy = p["ambient_energy"]
	_env.adjustment_saturation = p["saturation"]
	_env.tonemap_exposure = float(p["exposure"]) * float(Settings.get_value(&"brightness"))

func _on_setting(key: StringName, _value: Variant) -> void:
	if key == &"quality":
		_apply_quality()
	elif key == &"brightness":
		_write(_current)

func _apply_quality() -> void:
	var q := int(Settings.get_value(&"quality"))
	_env.ssao_enabled = q >= 1
	_env.ssil_enabled = q >= 2
	_env.ssr_enabled = q >= 2
	_env.glow_enabled = true
	_env.volumetric_fog_enabled = true
