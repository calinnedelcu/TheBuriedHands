class_name CrossbowTrap
extends Node3D

signal armed_changed(armed: bool)
signal fired(at: Vector3)

@export var bolt_speed: float = 18.0
@export var bolt_damage_steps: int = 3
@export var max_distance: float = 12.0
@export var armed: bool = true
@export var one_shot: bool = true
@export var noise_on_fire: float = 1.8
@export var player_group: String = "player"
@export var hud_damage_group: String = "hud_damage"
@export_node_path("Area3D") var pressure_plate_path
@export_node_path("Node3D") var muzzle_path
@export var bolt_scene: PackedScene

var _used: bool = false

@onready var _plate: Area3D = (get_node(pressure_plate_path) if pressure_plate_path else get_node_or_null("PressurePlate"))
@onready var _muzzle: Node3D = (get_node(muzzle_path) if muzzle_path else get_node_or_null("Muzzle"))
@onready var _fire_sfx: AudioStreamPlayer3D = get_node_or_null("FireAudio")

func _ready() -> void:
	if _plate:
		_plate.body_entered.connect(_on_plate_entered)
	# Wire interactables if present
	for c in get_children():
		if c is Interactable:
			(c as Interactable).interacted.connect(_on_interactable.bind(c))

func disarm() -> void:
	if not armed:
		return
	armed = false
	armed_changed.emit(false)

func arm() -> void:
	if armed:
		return
	armed = true
	_used = false
	armed_changed.emit(true)

func _on_interactable(_by: Node, source: Interactable) -> void:
	# Any successful interaction (disarm with chisel or block with wedge) disables the trap.
	disarm()
	source.enabled = false

func _on_plate_entered(body: Node) -> void:
	if not armed:
		return
	if _used and one_shot:
		return
	if player_group != "" and not body.is_in_group(player_group):
		return
	_used = true
	_fire()

func _fire() -> void:
	if _muzzle == null:
		return
	var origin: Vector3 = _muzzle.global_position
	var forward: Vector3 = -_muzzle.global_transform.basis.z
	_spawn_bolt(origin, forward)
	if _fire_sfx:
		_fire_sfx.play()
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(origin, noise_on_fire, self)
	# Damage via raycast (visual bolt is cosmetic only).
	var space := get_world_3d().direct_space_state
	var to := origin + forward * max_distance
	var params := PhysicsRayQueryParameters3D.create(origin, to)
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Node
	if collider == null:
		return
	if collider.is_in_group(player_group):
		_apply_damage()
	fired.emit(hit.get("position", to))

func _spawn_bolt(origin: Vector3, forward: Vector3) -> void:
	var bolt: Node3D
	if bolt_scene:
		bolt = bolt_scene.instantiate()
	else:
		bolt = _build_default_bolt()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = origin
	bolt.look_at(origin + forward, Vector3.UP)

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

func _apply_damage() -> void:
	var hud := get_tree().get_first_node_in_group(hud_damage_group)
	if hud and hud.has_method("apply_damage"):
		hud.apply_damage(bolt_damage_steps)
