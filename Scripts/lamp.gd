extends Node3D

signal oil_changed(level: float, max_level: float)
signal lit_changed(is_lit: bool)
signal extinguished()

@export var oil_max: float = 200.0
@export var oil_level: float = 200.0
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
## false = lampa apare in lume ca pickup (collider activ, pot apasa F).
## true = lampa apare deja in mana (default, pentru lampa din LampSocket).
@export var start_equipped: bool = true
@export var pickup_prompt_text: String = "Ia lampa"

@export_group("Objective On Pickup")
@export var pickup_required_objective_id: String = ""
@export var pickup_objective_after_id: String = ""
@export_multiline var pickup_objective_after_text: String = ""
@export_multiline var pickup_dialogue_text: String = ""

@export_group("Pickup Focus Cinematic")
@export var pickup_focus_enabled: bool = false
@export var pickup_focus_target_path: NodePath = NodePath("")
@export var pickup_focus_target_search_name: String = ""
@export var pickup_focus_target_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var pickup_focus_delay: float = 0.45
@export var pickup_focus_pan_duration: float = 0.85
@export var pickup_focus_hold_time: float = 1.2
@export var pickup_focus_zoom_fov: float = 40.0
@export var pickup_focus_zoom_return_duration: float = 0.6

@export_group("Tutorial Sequences")
## Multi-line monologue played the first time THIS lamp is picked up.
## Pure character speech only — control hints belong on the objective bar.
@export var pickup_tutorial_lines: PackedStringArray = []
## Multi-line monologue played the first time ANY lamp runs out of oil
## (gated globally via GameEvents.lamp_empty_tutorial_played).
@export var empty_tutorial_lines: PackedStringArray = []
@export var tutorial_line_duration: float = 5.0
## Transient objective shown for the duration of the empty monologue
## (e.g. "Reumple lampa la o sconcă (ține apăsat E)"). Prior objective is saved
## and restored at the end if it hasn't been overwritten by another system.
@export var empty_tutorial_objective_id: String = "lamp_refill_hint"
@export_multiline var empty_tutorial_objective_text: String = ""
## Dialogue bubble shown once when the refill tutorial starts (before the objective hint).
@export_multiline var empty_tutorial_dialogue: String = ""

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
var _has_been_collected: bool = false
var _pickup_tutorial_played: bool = false

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.55
	_flame_base_scale = flame.scale
	_flame_base_pos = flame.position
	is_lit = start_lit and oil_level > 0.0
	if pickup_interactable != null:
		pickup_interactable.prompt_text = pickup_prompt_text
		pickup_interactable.interacted.connect(_on_pickup_interacted)
	var objectives := get_node_or_null("/root/Objectives")
	if objectives != null and objectives.has_signal("objective_changed"):
		objectives.objective_changed.connect(_on_objective_changed)
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_signal("lamp_tutorial_requested"):
		events.lamp_tutorial_requested.connect(_on_lamp_tutorial_requested)
	add_to_group("lamp")
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
	_refresh_pickup_availability()
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
		_has_been_collected = true
		player_node.equip_lamp(self)
		_advance_pickup_objective(player_node)

func _on_objective_changed(_id: String, _text: String) -> void:
	_refresh_pickup_availability()

func _refresh_pickup_availability() -> void:
	var available := not equipped and _pickup_allowed_by_objective()
	if pickup_interactable != null:
		pickup_interactable.enabled = available
	if pickup_collider != null:
		pickup_collider.disabled = not available
	if pickup_body != null:
		pickup_body.collision_layer = 1 if available else 0
		pickup_body.collision_mask = 0

func _pickup_allowed_by_objective() -> bool:
	if _has_been_collected:
		return true
	if pickup_required_objective_id == "":
		return true
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null or not objectives.has_method("current_id"):
		return false
	return str(objectives.call("current_id")) == pickup_required_objective_id

func _advance_pickup_objective(player_node: Node) -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null:
		return
	if pickup_required_objective_id != "" and objectives.has_method("current_id"):
		if str(objectives.call("current_id")) != pickup_required_objective_id:
			return
	if pickup_dialogue_text != "":
		var events := get_node_or_null("/root/GameEvents")
		if events != null and events.has_method("show_dialogue"):
			events.show_dialogue(pickup_dialogue_text, 4.0)
	if pickup_objective_after_text != "" and objectives.has_method("set_objective"):
		objectives.set_objective(pickup_objective_after_id, pickup_objective_after_text)
	if pickup_focus_enabled:
		_trigger_pickup_focus_cinematic(player_node)
	_play_pickup_tutorial()

func _trigger_pickup_focus_cinematic(player_node: Node) -> void:
	if player_node == null or not player_node.has_method("play_cinematic_focus"):
		return
	var target_node := _resolve_pickup_focus_target()
	if target_node == null:
		return
	var target_pos := target_node.global_position + pickup_focus_target_offset
	if pickup_focus_delay > 0.0:
		await get_tree().create_timer(pickup_focus_delay).timeout
	if not is_instance_valid(player_node):
		return
	player_node.call(
		"play_cinematic_focus",
		target_pos,
		pickup_focus_pan_duration,
		pickup_focus_hold_time,
		pickup_focus_zoom_fov,
		pickup_focus_zoom_return_duration
	)

func _resolve_pickup_focus_target() -> Node3D:
	var target: Node = null
	if not pickup_focus_target_path.is_empty():
		target = get_node_or_null(pickup_focus_target_path)
	if target == null and pickup_focus_target_search_name != "":
		var scene_root := get_tree().current_scene if is_inside_tree() else null
		if scene_root != null:
			target = scene_root.find_child(pickup_focus_target_search_name, true, false)
	return target as Node3D

func _play_pickup_tutorial() -> void:
	if _pickup_tutorial_played or pickup_tutorial_lines.is_empty():
		return
	_pickup_tutorial_played = true
	_play_tutorial_sequence(pickup_tutorial_lines, pickup_dialogue_text != "")

func _on_lamp_tutorial_requested() -> void:
	var events := get_node_or_null("/root/GameEvents")
	if events != null and "lamp_empty_tutorial_played" in events and bool(events.get("lamp_empty_tutorial_played")):
		return
	_play_empty_tutorial()

func _play_lamp_tutorial() -> void:
	_play_empty_tutorial()

func _play_empty_tutorial() -> void:
	var events := get_node_or_null("/root/GameEvents")
	if events == null:
		return
	if "lamp_empty_tutorial_played" in events and bool(events.get("lamp_empty_tutorial_played")):
		return
	if "lamp_empty_tutorial_played" in events:
		events.set("lamp_empty_tutorial_played", true)
	if empty_tutorial_dialogue != "" and events.has_method("show_dialogue"):
		events.show_dialogue(empty_tutorial_dialogue, 5.0)
	var objectives := get_node_or_null("/root/Objectives")
	var saved_id: String = ""
	var saved_text: String = ""
	if objectives != null and empty_tutorial_objective_text != "":
		if objectives.has_method("current_id"):
			saved_id = str(objectives.call("current_id"))
		if objectives.has_method("current_text"):
			saved_text = str(objectives.call("current_text"))
		if objectives.has_method("set_objective"):
			objectives.call("set_objective", empty_tutorial_objective_id, empty_tutorial_objective_text)
	if not empty_tutorial_lines.is_empty():
		await _play_tutorial_sequence(empty_tutorial_lines, false)
	if objectives == null or empty_tutorial_objective_text == "" or not objectives.has_method("current_id"):
		return
	var refill_threshold: float = oil_max * 0.5
	while oil_level < refill_threshold:
		if str(objectives.call("current_id")) != empty_tutorial_objective_id:
			return
		await oil_changed
	if str(objectives.call("current_id")) == empty_tutorial_objective_id and objectives.has_method("set_objective"):
		objectives.call("set_objective", saved_id, saved_text)

func _play_tutorial_sequence(lines: PackedStringArray, skip_first_delay: bool) -> void:
	var events := get_node_or_null("/root/GameEvents")
	if events == null or not events.has_method("show_dialogue"):
		return
	if skip_first_delay:
		await get_tree().create_timer(4.0).timeout
	# Wait for any unrelated dialogue (guards, NPCs, dropped-bowl prompts) to
	# clear so the tutorial doesn't talk over them.
	await _await_dialogue_clear(events)
	for line in lines:
		events.show_dialogue(str(line), tutorial_line_duration)
		await get_tree().create_timer(tutorial_line_duration).timeout

func _await_dialogue_clear(events: Node) -> void:
	if events == null or not events.has_method("is_dialogue_active"):
		return
	while bool(events.call("is_dialogue_active")):
		await get_tree().create_timer(0.3).timeout
	# Grace window so we don't slip in between two consecutive lines from a
	# sequence (e.g. guard reveal). If another line landed meanwhile, wait again.
	await get_tree().create_timer(0.5).timeout
	if bool(events.call("is_dialogue_active")):
		await _await_dialogue_clear(events)

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
