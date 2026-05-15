extends Light3D

# Flicker / breath pentru lumini statice (OmniLight3D / SpotLight3D).
# Capturează valorile de bază în _ready si moduleaza energy, fog_energy si range.
# Fiecare lampa ar trebui să primeasca seed_offset diferit ca să nu pulseze sincron.

@export var flicker_amount: float = 0.18
@export var flicker_speed: float = 4.5
@export var range_flicker_amount: float = 0.05
@export var seed_offset: int = 0

@export_group("Slow Breath")
## 0 = fara breath. 0.1-0.2 = pulsatie lenta sub flicker.
@export var breath_amount: float = 0.0
@export var breath_period: float = 6.0

var _base_energy: float = 0.0
var _base_fog_energy: float = 0.0
var _base_omni_range: float = -1.0
var _has_omni_range: bool = false
var _noise := FastNoiseLite.new()
var _t: float = 0.0
var _oil_light_strength: float = 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_noise.seed = seed_offset if seed_offset != 0 else randi()
	_noise.frequency = 0.6
	_base_energy = light_energy
	_base_fog_energy = light_volumetric_fog_energy
	# OmniLight3D nu e detectabil cu `is` din script extends Light3D (clase-soră);
	# detectam runtime dupa proprietate.
	if "omni_range" in self:
		_has_omni_range = true
		_base_omni_range = self.omni_range
	# offset temporal ca aceeasi seed sa nu inceapa toate cu n=0
	_t = float(seed_offset) * 0.137

func set_oil_light_strength(strength: float) -> void:
	_oil_light_strength = clamp(strength, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	var n: float = _noise.get_noise_1d(_t * flicker_speed)
	var breath: float = 1.0
	if breath_amount > 0.0:
		breath = 1.0 + sin(_t * TAU / max(0.1, breath_period)) * breath_amount
	var low_oil_instability: float = 1.0 - _oil_light_strength
	var em_mult: float = (1.0 + n * (flicker_amount + low_oil_instability * 0.28)) * breath * _oil_light_strength
	light_energy = _base_energy * em_mult
	light_volumetric_fog_energy = _base_fog_energy * em_mult
	if _has_omni_range:
		self.omni_range = _base_omni_range * lerp(0.55, 1.0, _oil_light_strength) * (1.0 + n * range_flicker_amount)
