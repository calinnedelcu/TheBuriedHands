@tool
class_name LevelSolid
extends Node3D
## A solid block for building the tomb: a landing, a ledge, a pillar, an
## earthen wall between trenches, a plinth. Seen from outside, textured with
## a level material and given a box collider. The origin is the middle of its
## bottom face. Rebuilt from its settings; nothing generated is saved.
## With `masonry` its sides are dressed blocks in courses and its top is
## flagstones (`top_material`), like LevelBox.

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

@export_group("Masonry")
@export var masonry := false:
	set(v):
		masonry = v
		_queue_build()
@export var course_height := 0.72:
	set(v):
		course_height = maxf(v, 0.1)
		_queue_build()
@export var block_length := Vector2(0.9, 1.6):
	set(v):
		block_length = v
		_queue_build()
## Flagstones on top (none: the top stays plain).
@export var top_material: Material:
	set(v):
		top_material = v
		_queue_build()
@export var pattern_seed := 0:
	set(v):
		pattern_seed = v
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
	var mat: Material = material if material != null else ROCK
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	# Behind dressed stone the core sits back, so the joints are deep.
	if masonry:
		box.size = (size - Vector3(0.16, 0.08 if top_material != null else 0.0, 0.16)).max(Vector3.ONE * 0.02)
	mi.mesh = box
	mi.material_override = Masonry.joints(mat) if masonry else mat
	mi.position = Vector3(0, box.size.y * 0.5, 0)
	mi.set_meta(&"generated", true)
	add_child(mi)
	if masonry:
		_dress(mat)
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

## Blocks round the four sides, flagstones on top.
func _dress(mat: Material) -> void:
	var batch := Masonry.Batch.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name)) ^ hash(Vector3i(position.round())) ^ pattern_seed
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var lines := Masonry.course_lines(rng, size.y, course_height)
	# [corner, along, outward, length]
	var sides := [
		[Vector3(-hx, 0, -hz), Vector3.RIGHT, Vector3.FORWARD, size.x],
		[Vector3(-hx, 0, hz), Vector3.RIGHT, Vector3.BACK, size.x],
		[Vector3(-hx, 0, -hz), Vector3.BACK, Vector3.LEFT, size.z],
		[Vector3(hx, 0, -hz), Vector3.BACK, Vector3.RIGHT, size.z],
	]
	for side in sides:
		var o: Vector3 = side[0]
		var u: Vector3 = side[1]
		var n: Vector3 = side[2]
		for b in Masonry.courses(rng, side[3], 0.0, size.y, lines, block_length):
			var proud := rng.randf_range(0.01, 0.06)
			var depth := minf(0.4, minf(size.x, size.z) * 0.5)
			var along: float = b[0] + b[2] * 0.5
			var up: float = b[1] + b[3] * 0.5
			var centre := o + u * along + Vector3.UP * up + n * (proud - depth * 0.5)
			batch.add(mat, Masonry.piece(centre, u, Vector3.UP, n, Vector3(b[2] - 0.025, b[3] - 0.025, depth), rng.randf_range(-0.008, 0.008), Masonry.wobble(rng, 0.7)), rng.randf_range(0.82, 1.1))
	if top_material != null:
		for s in Masonry.rows(rng, size.x, size.z, Vector2(1.2, 2.0), Vector2(1.4, 2.6)):
			var centre := Vector3(-hx + s[0] + s[2] * 0.5, size.y + rng.randf_range(0.0, 0.02) - 0.1, -hz + s[1] + s[3] * 0.5)
			batch.add(top_material, Masonry.piece(centre, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3(s[2] - 0.04, 0.2, s[3] - 0.04), rng.randf_range(-0.01, 0.01), Masonry.wobble(rng, 0.35)), rng.randf_range(0.84, 1.1))
	batch.build(self)
