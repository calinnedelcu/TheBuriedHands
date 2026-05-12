extends Node3D

signal oil_changed(level: float, max_level: float)
signal lit_changed(is_lit: bool)
signal extinguished()

@export var oil_max: float = 100.0
@export var oil_level: float = 100.0
@export var oil_drain_rate: float = 0.6
@export var base_energy: float = 1.15
@export var base_range: float = 5.8
@export var raised_energy_multiplier: float = 1.6
@export var raised_range_multiplier: float = 1.35
@export var flicker_range: float = 0.32
@export var flicker_speed: float = 6.0
@export var flicker_position_amount: float = 0.012
@export var start_lit: bool = true

@onready var light: OmniLight3D = $Light
@onready var flame: MeshInstance3D = $Flame
@onready var smoke: GPUParticles3D = get_node_or_null("Smoke")

var is_lit: bool = true
var is_raised: bool = false
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _flame_base_scale: Vector3
var _flame_base_pos: Vector3
var _raise_blend: float = 0.0

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.55
	_flame_base_scale = flame.scale
	_flame_base_pos = flame.position
	is_lit = start_lit and oil_level > 0.0
	_refresh()
	oil_changed.emit(oil_level, oil_max)
	lit_changed.emit(is_lit)

func toggle() -> void:
	if oil_level <= 0.0:
		is_lit = false
	else:
		is_lit = not is_lit
	_refresh()
	lit_changed.emit(is_lit)

func set_raised(active: bool) -> void:
	is_raised = active

func refill(amount: float) -> void:
	oil_level = clamp(oil_level + amount, 0.0, oil_max)
	oil_changed.emit(oil_level, oil_max)

func _process(delta: float) -> void:
	_time += delta
	_raise_blend = lerp(_raise_blend, 1.0 if is_raised else 0.0, clamp(delta * 8.0, 0.0, 1.0))
	if is_lit:
		var drain := oil_drain_rate * delta * (1.0 + _raise_blend * 0.6)
		oil_level = max(0.0, oil_level - drain)
		oil_changed.emit(oil_level, oil_max)
		if oil_level <= 0.0:
			is_lit = false
			_refresh()
			extinguished.emit()
			lit_changed.emit(false)
			return
		_apply_flicker()

func _apply_flicker() -> void:
	var n := _noise.get_noise_1d(_time * flicker_speed)
	var energy_mult: float = lerp(1.0, raised_energy_multiplier, _raise_blend)
	var range_mult: float = lerp(1.0, raised_range_multiplier, _raise_blend)
	var flicker := 1.0 + n * flicker_range
	light.light_energy = base_energy * energy_mult * flicker
	light.light_volumetric_fog_energy = base_energy * energy_mult * flicker * 0.4
	light.omni_range = base_range * range_mult * (0.9 + n * 0.1)
	var s := 1.0 + _noise.get_noise_1d(_time * flicker_speed + 100.0) * 0.18
	flame.scale = _flame_base_scale * s
	flame.position = _flame_base_pos + Vector3(
		_noise.get_noise_1d(_time * 3.0 + 5.0) * flicker_position_amount,
		_noise.get_noise_1d(_time * 3.5 + 15.0) * flicker_position_amount * 0.4,
		_noise.get_noise_1d(_time * 3.2 + 25.0) * flicker_position_amount
	)

func _refresh() -> void:
	light.visible = is_lit
	flame.visible = is_lit
	if smoke:
		smoke.emitting = is_lit
