extends Node3D

signal oil_changed(level: float, max_level: float)
signal lit_changed(is_lit: bool)
signal extinguished()

@export var oil_max: float = 100.0
@export var oil_level: float = 100.0
@export var oil_drain_rate: float = 0.6
## Multiplicator pentru rata de consum cand lampa e pe jos (not equipped).
## 0.25 = tine de 4 ori mai mult pe jos decat in mana.
@export var dropped_drain_multiplier: float = 0.25
@export_group("Movement Oil Spill")
## Compat legacy: extra spill folosit pentru mers normal, dar sprint/jump au
## multiplicatori dedicati mai jos.
@export var walking_drain_extra: float = 1.0
@export var idle_drain_multiplier: float = 0.25
@export var careful_walk_drain_multiplier: float = 0.72
@export var crouch_drain_multiplier: float = 0.48
@export var crawl_drain_multiplier: float = 0.35
@export var walk_drain_multiplier: float = 1.0
@export var sprint_drain_multiplier: float = 3.4
@export var airborne_drain_multiplier: float = 2.4
@export var jump_spill_drain_multiplier: float = 3.1
@export var movement_spill_curve: float = 1.35
@export var movement_drain_lerp_speed: float = 7.0
@export_group("Light")
@export var base_energy: float = 5.0
@export var base_range: float = 20.0
@export var spot_base_energy: float = 4.2
@export var spot_base_range: float = 32.0
@export var raised_energy_multiplier: float = 1.6
@export var raised_range_multiplier: float = 1.35
@export var selected_energy_multiplier: float = 1.25
@export var selected_range_multiplier: float = 1.12
@export var low_oil_warning_threshold_pct: float = 0.14
@export var low_oil_min_light_multiplier: float = 0.34
@export var low_oil_min_range_multiplier: float = 0.58
@export var low_oil_flicker_boost: float = 0.42
@export var low_oil_min_flame_scale: float = 0.45
@export var flicker_range: float = 0.32
@export var flicker_speed: float = 6.0
@export var flicker_position_amount: float = 0.012
@export var start_lit: bool = true
## false = lampa apare in lume ca pickup (collider activ, pot apasa E).
## true = lampa apare deja in mana (default, pentru lampa din LampSocket).
@export var start_equipped: bool = true
@export var pickup_prompt_text: String = "Ia lampa"

@onready var light: OmniLight3D = $FlameSocket/Light
@onready var spot: SpotLight3D = _find_lamp_spot()
@onready var flame: MeshInstance3D = $FlameSocket/Flame
@onready var smoke: GPUParticles3D = get_node_or_null("FlameSocket/Smoke")
@onready var pickup_body: StaticBody3D = get_node_or_null("PickupBody")
var _cached_player: CharacterBody3D = null
@onready var pickup_collider: CollisionShape3D = get_node_or_null("PickupBody/PickupCollider")
@onready var pickup_interactable: Interactable = get_node_or_null("PickupBody/Interactable")

var is_lit: bool = true
var is_raised: bool = false
var is_selected: bool = false
var equipped: bool = true
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _flame_base_scale: Vector3
var _flame_base_pos: Vector3
var _raise_blend: float = 0.0
var _selected_blend: float = 0.0
var _movement_drain_mult: float = 1.0

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.55
	_flame_base_scale = flame.scale
	_flame_base_pos = flame.position
	is_lit = start_lit and oil_level > 0.0
	if pickup_interactable != null:
		pickup_interactable.prompt_text = pickup_prompt_text
		pickup_interactable.interacted.connect(_on_pickup_interacted)
	# Sane default. Lampa de start (din LampSocket) este equipped si inventarul
	# preia ownership ulterior. Lampile din lume au start_equipped = false.
	set_equipped(start_equipped)
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

func set_selected(active: bool) -> void:
	is_selected = active

func set_equipped(active: bool) -> void:
	equipped = active
	_cached_player = null  # re-detect dupa reparent
	_movement_drain_mult = 1.0
	if pickup_interactable != null:
		pickup_interactable.enabled = not equipped
	if pickup_collider != null:
		pickup_collider.disabled = equipped
	if pickup_body != null:
		pickup_body.collision_layer = 0 if equipped else 1
		pickup_body.collision_mask = 0
	if equipped:
		set_raised(false)
		set_selected(false)
	_refresh()

func is_equipped() -> bool:
	return equipped

## Parked in the inventory: no pickup collider, not raised. Visibility and
## process are handled by the inventory's hidden storage node, and the lit
## state is preserved so the lamp comes back exactly as it was put away.
func set_stored() -> void:
	equipped = false
	if pickup_interactable != null:
		pickup_interactable.enabled = false
	if pickup_collider != null:
		pickup_collider.disabled = true
	if pickup_body != null:
		pickup_body.collision_layer = 0
		pickup_body.collision_mask = 0
	set_raised(false)
	set_selected(false)
	_refresh()

func refill(amount: float) -> void:
	oil_level = clamp(oil_level + amount, 0.0, oil_max)
	oil_changed.emit(oil_level, oil_max)

func current_oil_drain_multiplier() -> float:
	var equipped_mult: float = 1.0 if equipped else dropped_drain_multiplier
	var movement_mult: float = _movement_drain_mult if equipped else 1.0
	return (1.0 + _raise_blend * 0.6) * equipped_mult * movement_mult

func current_oil_drain_per_second() -> float:
	if not is_lit:
		return 0.0
	return oil_drain_rate * current_oil_drain_multiplier()

func current_movement_oil_multiplier() -> float:
	return _movement_drain_mult if equipped else 1.0

func current_oil_light_strength() -> float:
	return _oil_light_strength()

func _process(delta: float) -> void:
	_time += delta
	_raise_blend = lerp(_raise_blend, 1.0 if is_raised else 0.0, clamp(delta * 8.0, 0.0, 1.0))
	_selected_blend = lerp(_selected_blend, 1.0 if is_selected else 0.0, clamp(delta * 8.0, 0.0, 1.0))
	if is_lit:
		var equipped_mult: float = 1.0 if equipped else dropped_drain_multiplier
		var movement_mult: float = 1.0
		if equipped:
			movement_mult = _movement_oil_multiplier(delta)
		var drain := oil_drain_rate * delta * (1.0 + _raise_blend * 0.6) * equipped_mult * movement_mult
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
	energy_mult *= lerp(1.0, selected_energy_multiplier, _selected_blend)
	range_mult *= lerp(1.0, selected_range_multiplier, _selected_blend)
	var oil_strength := _oil_light_strength()
	var oil_range_strength: float = lerp(low_oil_min_range_multiplier, 1.0, oil_strength)
	var low_oil_instability: float = 1.0 - oil_strength
	var spill_jitter: float = clamp((_movement_drain_mult - 1.0) / 2.4, 0.0, 1.0)
	var flicker := 1.0 + n * (flicker_range + spill_jitter * 0.1 + low_oil_instability * low_oil_flicker_boost)
	light.light_energy = base_energy * energy_mult * flicker * oil_strength * (2.2 if not equipped else 1.0)
	light.light_volumetric_fog_energy = base_energy * energy_mult * flicker * oil_strength * 0.65 * (2.2 if not equipped else 1.0)
	light.omni_range = base_range * range_mult * oil_range_strength * (0.9 + n * 0.1) * (1.6 if not equipped else 1.0)
	if spot and equipped:
		spot.light_energy = spot_base_energy * energy_mult * flicker * oil_strength
		spot.light_volumetric_fog_energy = spot_base_energy * energy_mult * flicker * oil_strength * 1.2
		spot.spot_range = spot_base_range * range_mult * oil_range_strength * (0.92 + n * 0.08)
	var s := 1.0 + _noise.get_noise_1d(_time * flicker_speed + 100.0) * (0.18 + low_oil_instability * 0.16)
	flame.scale = _flame_base_scale * s * lerp(low_oil_min_flame_scale, 1.0, oil_strength)
	flame.position = _flame_base_pos + Vector3(
		_noise.get_noise_1d(_time * 3.0 + 5.0) * flicker_position_amount * (1.0 + spill_jitter + low_oil_instability),
		_noise.get_noise_1d(_time * 3.5 + 15.0) * flicker_position_amount * 0.4 * (1.0 + spill_jitter + low_oil_instability),
		_noise.get_noise_1d(_time * 3.2 + 25.0) * flicker_position_amount * (1.0 + spill_jitter + low_oil_instability)
	)

func _refresh() -> void:
	light.visible = is_lit
	if spot:
		spot.visible = is_lit and equipped
	flame.visible = is_lit
	if smoke:
		smoke.emitting = is_lit

func _on_pickup_interacted(by: Node) -> void:
	var player_node := _resolve_player(by)
	if player_node != null and player_node.has_method("equip_lamp"):
		player_node.equip_lamp(self)

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null

## Consum in mana: atent/crouch/crawl = lent, sprint/jump = spill puternic.
func _movement_oil_multiplier(delta: float) -> float:
	var target: float = _target_movement_oil_multiplier()
	_movement_drain_mult = lerp(_movement_drain_mult, target, clamp(delta * movement_drain_lerp_speed, 0.0, 1.0))
	return _movement_drain_mult

func _target_movement_oil_multiplier() -> float:
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = _find_player()
	if _cached_player == null:
		return 1.0
	var hv := _cached_player.velocity
	hv.y = 0.0
	var horizontal_speed: float = hv.length()
	var moving: bool = horizontal_speed > 0.12

	if not _cached_player.is_on_floor():
		var air_mult: float = jump_spill_drain_multiplier if _cached_player.velocity.y > 0.15 else airborne_drain_multiplier
		return maxf(air_mult, 1.0 + walking_drain_extra * _speed_spill_factor(horizontal_speed))
	if not moving:
		return idle_drain_multiplier

	if _player_flag("is_crawling"):
		return crawl_drain_multiplier
	if _player_flag("is_crouching"):
		return crouch_drain_multiplier
	if _player_flag("is_sprinting"):
		return sprint_drain_multiplier

	var walk_speed: float = maxf(_player_float("walk_speed", 3.0), 0.1)
	if horizontal_speed < walk_speed * 0.65:
		return careful_walk_drain_multiplier
	return lerp(walk_drain_multiplier, 1.0 + walking_drain_extra, _speed_spill_factor(horizontal_speed))

func _speed_spill_factor(horizontal_speed: float) -> float:
	var sprint_speed: float = maxf(_player_float("sprint_speed", 5.5), 0.1)
	return pow(clamp(horizontal_speed / sprint_speed, 0.0, 1.0), movement_spill_curve)

func _player_flag(method_name: String) -> bool:
	return _cached_player != null and _cached_player.has_method(method_name) and bool(_cached_player.call(method_name))

func _player_float(property_name: String, fallback: float) -> float:
	if _cached_player == null:
		return fallback
	var value = _cached_player.get(property_name)
	return float(value) if value != null else fallback

func _oil_light_strength() -> float:
	if oil_max <= 0.0:
		return 1.0
	var pct: float = clamp(oil_level / oil_max, 0.0, 1.0)
	var threshold := maxf(0.001, low_oil_warning_threshold_pct)
	if pct >= threshold:
		return 1.0
	return lerp(low_oil_min_light_multiplier, 1.0, pct / threshold)

func _find_player() -> CharacterBody3D:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterBody3D:
			return n as CharacterBody3D
		n = n.get_parent()
	return null

func _find_lamp_spot() -> SpotLight3D:
	var camera := get_viewport().get_camera_3d()
	if camera:
		return camera.get_node_or_null("LampSpot") as SpotLight3D
	return null
