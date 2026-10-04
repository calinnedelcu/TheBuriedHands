class_name FurnaceFire
extends Node3D
## A kiln or hearth fire: the oil-flame shader on several crossed teardrop
## meshes for volume, a light breathing on noise, and a looping crackle that
## starts at a random point so neighbouring fires don't sound in sync.
## Its glow counts for stealth, and draughts make it gutter like the lamps.

@export_group("Flicker")
@export var flicker_speed: float = 7.5
@export var flicker_range: float = 0.32
@export var flame_jitter: float = 0.22

@export_group("Light")
@export var base_energy: float = 10.0
@export var base_range: float = 12.0
@export var volumetric_fog_energy: float = 3.6
@export var light_color: Color = Color(1.0, 0.55, 0.18, 1.0)

@export_group("Sound")
@export var sound_enabled: bool = true
@export var sound_volume_db: float = 6.0
@export var sound_bus: StringName = &"Tomb"
## Random pitch offset per fire.
@export var sound_pitch_random: float = 0.08

@onready var _light: OmniLight3D = $Light
@onready var _flames: Array[MeshInstance3D] = [
	$FlameCore,
	$FlameCrossA,
	$FlameCrossB,
	$FlameSide1,
	$FlameSide2,
	$FlameInnerGlow,
]
@onready var _sfx: AudioStreamPlayer3D = $CrackleSFX

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _flame_base_scales: Array[Vector3] = []
var _base_energy_runtime: float = 0.0
var _base_range_runtime: float = 0.0

var _gust := 0.0

func _ready() -> void:
	add_to_group(&"wall_lamps")
	Stealth.register_light(_light)
	_noise.seed = randi()
	_noise.frequency = 0.5
	for f in _flames:
		_flame_base_scales.append(f.scale)
	_base_energy_runtime = base_energy
	_base_range_runtime = base_range
	_light.light_color = light_color
	_light.light_volumetric_fog_energy = volumetric_fog_energy
	if sound_enabled and _sfx.stream != null:
		_sfx.volume_db = sound_volume_db
		_sfx.bus = sound_bus
		_sfx.pitch_scale = 1.0 + randf_range(-sound_pitch_random, sound_pitch_random)
		var start_pos: float = 0.0
		if _sfx.stream is AudioStreamMP3 or _sfx.stream is AudioStreamOggVorbis:
			var length: float = _sfx.stream.get_length() if _sfx.stream.has_method("get_length") else 0.0
			if length > 0.5:
				start_pos = randf() * length
		_sfx.play(start_pos)

func _exit_tree() -> void:
	Stealth.unregister_light(_light)

## A draught (the gates slamming) makes the fire duck for a moment.
func gust(strength := 1.0) -> void:
	_gust = maxf(_gust, strength)

func _process(delta: float) -> void:
	_time += delta
	_gust = maxf(0.0, _gust - delta * 0.6)
	var n: float = _noise.get_noise_1d(_time * flicker_speed)
	var energy_mult: float = (1.0 + n * flicker_range) * (1.0 - _gust * 0.4)
	_light.light_energy = _base_energy_runtime * energy_mult
	_light.omni_range = _base_range_runtime * (0.94 + n * 0.06)
	for i in _flames.size():
		var f: MeshInstance3D = _flames[i]
		var jit: float = _noise.get_noise_1d(_time * (flicker_speed * 0.6) + float(i) * 13.0)
		var s: float = 1.0 + jit * flame_jitter
		f.scale = _flame_base_scales[i] * Vector3(s * 0.96, s * 1.06, s * 0.96)
