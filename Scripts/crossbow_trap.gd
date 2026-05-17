class_name CrossbowTrap
extends Node3D

signal armed_changed(armed: bool)
signal fired(at: Vector3)

@export var bolt_speed: float = 45.0
@export var bolt_damage_steps: int = 3
@export var max_distance: float = 12.0
@export var armed: bool = true
@export var one_shot: bool = true
@export var fire_delay: float = 0.0
@export var noise_on_fire: float = 1.8
@export var player_group: String = "player"
@export var hud_damage_group: String = "hud_damage"
@export var trigger_player: bool = true
@export var trigger_thrown_objects: bool = true
@export var thrown_trigger_group: String = "trap_trigger"
@export var trigger_min_mass: float = 0.25
@export var linked_trap_paths: Array[NodePath] = []
@export var plate_drop_distance: float = 0.06
@export var plate_drop_time: float = 0.12
@export var reset_plate_after_fire: bool = true
@export var high_bolt_duckable: bool = true
@export var crouch_safe_hit_height: float = 0.7
@export var crawl_safe_hit_height: float = 0.38
@export_range(-45.0, 45.0, 1.0) var fire_downward_angle_degrees: float = 5.0
@export_node_path("Area3D") var pressure_plate_path
@export_node_path("Node3D") var muzzle_path
@export var bolt_scene: PackedScene

var _used: bool = false
var _firing: bool = false
var _plate_origin_y: float = 0.0

@onready var _plate: Area3D = $PressurePlate
@onready var _muzzle: Node3D = $Housing/Muzzle
@onready var _housing: StaticBody3D = $Housing
@onready var _fire_sfx: AudioStreamPlayer3D = $Housing/FireAudio
@onready var _loaded_bolt: Node3D = $Housing/Muzzle/LoadedBolt

func _ready() -> void:
	add_to_group("crossbow_trap")
	# Editable Children can break @onready resolution in Godot 4 instanced scenes.
	if not _plate:
		_plate = get_node_or_null("PressurePlate") as Area3D
	if not _muzzle:
		_muzzle = get_node_or_null("Housing/Muzzle") as Node3D
	if not _housing:
		_housing = get_node_or_null("Housing") as StaticBody3D
	if not _fire_sfx:
		_fire_sfx = get_node_or_null("Housing/FireAudio") as AudioStreamPlayer3D
	if not _loaded_bolt:
		_loaded_bolt = get_node_or_null("Housing/Muzzle/LoadedBolt") as Node3D
	if _plate:
		_plate_origin_y = _plate.position.y
		_plate.body_entered.connect(_on_plate_entered)
	for c in get_children():
		if c is Interactable:
			(c as Interactable).interacted.connect(_on_interactable.bind(c))

func disarm() -> void:
	if not armed:
		return
	armed = false
	_firing = false
	_set_interactables_enabled(false)
	armed_changed.emit(false)

func arm() -> void:
	if armed:
		return
	armed = true
	_used = false
	_set_interactables_enabled(true)
	armed_changed.emit(true)

func _on_interactable(_by: Node, source: Interactable) -> void:
	# Any successful interaction (disarm with chisel or block with wedge) disables the trap.
	disarm()
	source.enabled = false

func _set_interactables_enabled(value: bool) -> void:
	for c in get_children():
		if c is Interactable:
			(c as Interactable).enabled = value

func _on_plate_entered(body: Node) -> void:
	if _can_body_trigger(body):
		trigger(body)

func trigger(by: Node = null, include_links: bool = true) -> void:
	if not armed:
		return
	if _firing:
		return
	if _used and one_shot:
		return
	_used = true
	_firing = true
	_press_plate()
	if include_links:
		_trigger_linked(by)
	if fire_delay > 0.0:
		await get_tree().create_timer(fire_delay).timeout
	if not armed:
		_firing = false
		return
	_fire()
	_firing = false
	if reset_plate_after_fire and (not one_shot or armed):
		_release_plate()

func _can_body_trigger(body: Node) -> bool:
	if body == null:
		return false
	if trigger_player and player_group != "" and body.is_in_group(player_group):
		return true
	if not trigger_thrown_objects:
		return false
	if thrown_trigger_group != "" and body.is_in_group(thrown_trigger_group):
		return _body_has_enough_weight(body)
	var body_name := String(body.name)
	if body is RigidBody3D and (body_name.begins_with("Thrown_") or body_name == "CeramicShard" or "item_id" in body):
		return _body_has_enough_weight(body)
	return false

func _body_has_enough_weight(body: Node) -> bool:
	if body is RigidBody3D:
		return (body as RigidBody3D).mass >= trigger_min_mass
	return true

func _trigger_linked(by: Node) -> void:
	for path in linked_trap_paths:
		var trap := get_node_or_null(path)
		if trap == null or trap == self:
			continue
		if trap.has_method("trigger"):
			trap.call("trigger", by, false)

func _press_plate() -> void:
	if _plate == null:
		return
	var tween := create_tween()
	tween.tween_property(_plate, "position:y", _plate_origin_y - plate_drop_distance, plate_drop_time)

func _release_plate() -> void:
	if _plate == null:
		return
	var tween := create_tween()
	tween.tween_property(_plate, "position:y", _plate_origin_y, plate_drop_time * 1.5)

func _fire() -> void:
	if _muzzle == null:
		return
	# Spawn at the loaded-bolt wrapper position (so the visual is continuous
	# with where the arrow was sitting in the muzzle); fall back to muzzle pivot.
	var origin: Vector3 = _loaded_bolt.global_position if _loaded_bolt else _muzzle.global_position
	var forward: Vector3 = (-_muzzle.global_transform.basis.z).normalized()
	# Apply downward pitch so the bolt arcs toward player height even when
	# the trap (and its decorative crossbow) is mounted high on the wall.
	if absf(fire_downward_angle_degrees) > 0.01:
		# Use UP × forward so positive angle rotates forward DOWNWARD (toward -Y).
		var pitch_axis := Vector3.UP.cross(forward).normalized()
		if pitch_axis.length_squared() > 0.001:
			forward = forward.rotated(pitch_axis, deg_to_rad(fire_downward_angle_degrees)).normalized()
	_spawn_bolt(origin, forward)
	if _fire_sfx:
		_fire_sfx.play()
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(origin, noise_on_fire, self)
	# Damage now happens on collision (see bolt.gd + Area3D added in _spawn_bolt),
	# so the bolt hits whoever walks into its path during flight — not just whoever
	# happened to be in line at fire time.
	fired.emit(origin + forward * max_distance)

func _spawn_bolt(origin: Vector3, forward: Vector3) -> void:
	var bolt: Node3D
	if _loaded_bolt:
		bolt = _loaded_bolt.duplicate() as Node3D
		bolt.visible = true
		for child in bolt.get_children():
			if child is Node3D:
				(child as Node3D).visible = true
	elif bolt_scene:
		bolt = bolt_scene.instantiate() as Node3D
	else:
		bolt = _build_default_bolt()

	bolt.set_script(load("res://Scripts/bolt.gd"))
	bolt.set("speed", bolt_speed)
	bolt.set("lifetime", max_distance / bolt_speed + 0.1)
	bolt.set("velocity", forward * bolt_speed)
	bolt.set("damage_steps", bolt_damage_steps)
	bolt.set("player_group", player_group)
	bolt.set("hud_damage_group", hud_damage_group)
	bolt.set("high_bolt_duckable", high_bolt_duckable)
	bolt.set("crouch_safe_hit_height", crouch_safe_hit_height)
	bolt.set("crawl_safe_hit_height", crawl_safe_hit_height)

	# Attach an Area3D so the bolt damages whatever it physically touches
	# during flight (not just whoever was in line at fire time).
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 5  # player layer 1 + thrown-object layer 3
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# Slightly oversized vs the visible arrow so small height mismatches
	# between trap muzzle and player capsule still register a hit.
	capsule.radius = 0.10
	capsule.height = 0.60
	shape.shape = capsule
	# Capsule default axis is Y; rotate so it lies along the bolt's local Z
	# (which becomes the flight direction after the spawn-time basis is applied).
	shape.transform = Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), Vector3.ZERO)
	area.add_child(shape)
	bolt.add_child(area)

	get_tree().current_scene.add_child(bolt)
	# Build a basis whose local -Z matches `forward` (which already includes
	# any downward pitch from _fire). Done manually instead of look_at to
	# avoid quirks when forward is near-vertical.
	var bz := -forward.normalized()
	var bx := Vector3.UP.cross(bz).normalized()
	if bx.length_squared() < 0.001:
		bx = Vector3.RIGHT
	var by := bz.cross(bx).normalized()
	var basis := Basis(bx, by, bz)
	bolt.global_transform = Transform3D(basis, origin)

func _build_default_bolt() -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://Scripts/bolt.gd"))
	root.set("speed", bolt_speed)
	root.set("lifetime", max_distance / bolt_speed + 0.1)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.45
	mesh.mesh = cyl
	mesh.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.4, 0.25)
	mat.roughness = 0.85
	mesh.material_override = mat
	root.add_child(mesh)
	return root


