class_name FlickerLight
extends OmniLight3D
## A static flame light (sconce, brazier) that flickers and counts for stealth:
## standing in its glow makes the player visible to guards.

@export var flicker_amount := 0.16
@export var flicker_speed := 4.5
@export var counts_for_stealth := true

var _noise := FastNoiseLite.new()
var _t := 0.0
var _base_energy := 1.0
var _base_range := 8.0
var _gust := 0.0

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.6
	_t = randf() * 50.0
	_base_energy = light_energy
	_base_range = omni_range
	add_to_group(&"wall_lamps")
	if counts_for_stealth:
		Stealth.register_light(self)

func _exit_tree() -> void:
	Stealth.unregister_light(self)

func gust(strength := 1.0) -> void:
	_gust = maxf(_gust, strength)

func _process(delta: float) -> void:
	_t += delta
	_gust = maxf(0.0, _gust - delta * 0.8)
	var n := _noise.get_noise_1d(_t * flicker_speed)
	var dip := 1.0 - _gust * 0.65 * absf(_noise.get_noise_1d(_t * 21.0))
	light_energy = _base_energy * (1.0 + n * flicker_amount) * dip
	omni_range = _base_range * (1.0 + n * 0.04)
