@tool
class_name LevelSolid
extends Node3D
## A solid block for building the tomb: a landing, a ledge, a pillar, an
## earthen wall between trenches, a plinth. Seen from outside, textured with
## a level material and given a box collider. The origin is the middle of its
## bottom face. Rebuilt from its settings; nothing generated is saved.

const ROCK := preload("res://assets/materials/level/tunnel_rock.tres")

@export var size := Vector3(2.0, 1.0, 2.0):
	set(v):
		size = v.max(Vector3(0.05, 0.05, 0.05))
		_queue_build()
@export var material: Material:
	set(v):
		material = v
		_queue_build()
@export var collision := true:
	set(v):
		collision = v
		_queue_build()
@export_flags_3d_physics var collision_layer := 1:
	set(v):
		collision_layer = v
		_queue_build()

var _queued := false

func _ready() -> void:
	_build()

func _queue_build() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_build.call_deferred()

func _build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"generated"):
			remove_child(c)
			c.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material if material != null else ROCK
	mi.position = Vector3(0, size.y * 0.5, 0)
	mi.set_meta(&"generated", true)
	add_child(mi)
	if not collision:
		return
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = collision_layer
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = size
	shape.shape = hit
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
