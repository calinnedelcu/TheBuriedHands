extends Node3D

@export var player_group: String = "player"
@export var hud_vapor_group: String = "hud_vapors"
@export var hud_damage_group: String = "hud_damage"
@export var area_path: NodePath = NodePath("Area")
@export var source_path: NodePath = NodePath("Source")
@export var sources_parent_path: NodePath = NodePath("Sources")
@export var particles_path: NodePath = NodePath("VaporParticles")

@export var max_effect_radius: float = 7.0
@export var full_intensity_radius: float = 1.2
@export_range(0.0, 1.0, 0.01) var ambient_intensity_in_area: float = 0.50
@export var falloff_power: float = 2.4
@export_range(0.0, 1.0, 0.01) var half_damage_threshold: float = 0.50
@export_range(0.0, 1.0, 0.01) var full_damage_threshold: float = 0.625
@export var half_damage_interval: float = 5.0
@export var full_damage_interval: float = 3.0
@export var half_damage_steps: int = 1
@export var full_damage_steps: int = 2
@export var reset_vapors_on_exit: bool = true
@export var protective_item_id: String = "vapor_mask"
@export_range(0.0, 1.0, 0.01) var protected_ambient_intensity_in_area: float = 0.375

var _area: Area3D = null
var _source: Node3D = null
var _sources_parent: Node = null
var _particles: CPUParticles3D = null
var _player: Node3D = null
var _half_damage_timer: float = 0.0
var _full_damage_timer: float = 0.0


func _ready() -> void:
	add_to_group("mercury_vapor_zone")
	_area = get_node_or_null(area_path) as Area3D
	_source = get_node_or_null(source_path) as Node3D
	_sources_parent = get_node_or_null(sources_parent_path)
	_particles = get_node_or_null(particles_path) as CPUParticles3D

	if _area != null:
		if not _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.connect(_on_body_entered)
		if not _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.connect(_on_body_exited)

	if _particles != null:
		_particles.emitting = true


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var intensity: float = _vapor_intensity_at(_player.global_position)
	_apply_vapor_hud(intensity)
	_apply_vapor_damage(delta, intensity)


func _on_body_entered(body: Node3D) -> void:
	if player_group != "" and not body.is_in_group(player_group):
		return
	_player = body
	_half_damage_timer = half_damage_interval
	_full_damage_timer = full_damage_interval


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player = null
	_half_damage_timer = 0.0
	_full_damage_timer = 0.0
	if reset_vapors_on_exit:
		_reset_vapor_hud()


func _vapor_intensity_at(world_position: Vector3) -> float:
	var source_positions: Array[Vector3] = _source_positions()
	var usable_radius: float = maxf(0.01, max_effect_radius - full_intensity_radius)
	var strongest_source_intensity: float = 0.0
	for source_position in source_positions:
		var distance: float = source_position.distance_to(world_position)
		var linear: float = 1.0 - clampf((distance - full_intensity_radius) / usable_radius, 0.0, 1.0)
		var source_intensity: float = pow(linear, maxf(0.01, falloff_power))
		strongest_source_intensity = maxf(strongest_source_intensity, source_intensity)
	var ambient_intensity: float = protected_ambient_intensity_in_area if _player_has_protection() else ambient_intensity_in_area
	return clampf(maxf(ambient_intensity, strongest_source_intensity), 0.0, 1.0)


func _player_has_protection() -> bool:
	if protective_item_id == "" or _player == null:
		return false
	var inventory: Node = _player.get_node_or_null("Inventory")
	return inventory != null and inventory.has_method("has_item") and bool(inventory.call("has_item", protective_item_id))


func _source_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if _sources_parent != null:
		for child in _sources_parent.get_children():
			if child is Node3D:
				positions.append((child as Node3D).global_position)
	if positions.is_empty() and _source != null:
		positions.append(_source.global_position)
	if positions.is_empty():
		positions.append(global_position)
	return positions


func _apply_vapor_hud(intensity: float) -> void:
	var hud: Node = get_tree().get_first_node_in_group(hud_vapor_group)
	if hud == null:
		return
	if hud.has_method("set_vapor_fraction"):
		hud.call("set_vapor_fraction", intensity)
	elif hud.has_method("set_vapor_level"):
		hud.call("set_vapor_level", roundi(intensity * 8.0))


func _reset_vapor_hud() -> void:
	var hud: Node = get_tree().get_first_node_in_group(hud_vapor_group)
	if hud == null:
		return
	if hud.has_method("reset_vapors"):
		hud.call("reset_vapors")
	elif hud.has_method("set_vapor_fraction"):
		hud.call("set_vapor_fraction", 0.0)


func _apply_vapor_damage(delta: float, intensity: float) -> void:
	if intensity >= full_damage_threshold:
		_full_damage_timer -= delta
		_half_damage_timer = half_damage_interval
		if _full_damage_timer <= 0.0:
			_full_damage_timer = full_damage_interval
			_damage_player(full_damage_steps)
	elif intensity >= half_damage_threshold:
		_half_damage_timer -= delta
		_full_damage_timer = full_damage_interval
		if _half_damage_timer <= 0.0:
			_half_damage_timer = half_damage_interval
			_damage_player(half_damage_steps)
	else:
		_half_damage_timer = half_damage_interval
		_full_damage_timer = full_damage_interval

func _damage_player(damage_steps: int) -> void:
	if damage_steps <= 0:
		return

	var hud: Node = get_tree().get_first_node_in_group(hud_damage_group)
	if hud != null and hud.has_method("apply_damage"):
		hud.call("apply_damage", damage_steps)
