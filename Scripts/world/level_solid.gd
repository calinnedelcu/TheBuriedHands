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
@export var course_height := 0.85:
	set(v):
		course_height = maxf(v, 0.1)
		_queue_build()
@export var block_length := Vector2(0.9, 1.6):
	set(v):
		block_length = v
		_queue_build()
## The workshop's own stones (else plain bevelled blocks, e.g. rammed earth).
@export var stones := true:
	set(v):
		stones = v
		_queue_build()
## Sides that get stones (others are against a wall: no one sees them).
@export_flags("North", "South", "West", "East") var dressed_sides := 15:
	set(v):
		dressed_sides = v
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

## Stones round the four sides, flagstones on top.
func _dress(mat: Material) -> void:
	var batch := Masonry.Batch.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name)) ^ hash(Vector3i(position.round())) ^ pattern_seed
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var lines := Masonry.course_lines(rng, size.y, course_height)
	var blocks := Masonry.stones("wall") if stones else []
	# [corner, along, outward, length]
	var sides := [
		[Vector3(-hx, 0, -hz), Vector3.RIGHT, Vector3.FORWARD, size.x],
		[Vector3(-hx, 0, hz), Vector3.RIGHT, Vector3.BACK, size.x],
		[Vector3(-hx, 0, -hz), Vector3.BACK, Vector3.LEFT, size.z],
		[Vector3(hx, 0, -hz), Vector3.BACK, Vector3.RIGHT, size.z],
	]
	for k in sides.size():
		if not dressed_sides & (1 << k):
			continue
		var side: Array = sides[k]
		var o: Vector3 = side[0]
		var u: Vector3 = side[1]
		var n: Vector3 = side[2]
		var deepest := minf(size.x, size.z) * 0.5
		if blocks.is_empty():
			for b in Masonry.courses(rng, side[3], 0.0, size.y, lines, block_length):
				var depth := minf(0.4, deepest)
				var along: float = b[0] + b[2] * 0.5
				var up: float = b[1] + b[3] * 0.5
				var centre := o + u * along + Vector3.UP * up + n * (rng.randf_range(0.01, 0.06) - depth * 0.5)
				batch.add(mat, Masonry.piece(centre, u, Vector3.UP, n, Vector3(b[2] - 0.025, b[3] - 0.025, depth), rng.randf_range(-0.008, 0.008), Masonry.wobble(rng, 0.7)), rng.randf_range(0.82, 1.1))
			continue
		for b in Masonry.stone_courses(rng, side[3], 0.0, size.y, lines, blocks):
			var pick: Array = blocks[b[4]]
			var native: Vector3 = pick[1]
			var depth := minf(native.z * b[3] / native.y, deepest)
			var along: float = b[0] + b[2] * 0.5
			var up: float = b[1] + b[3] * 0.5
			var centre := o + u * along + Vector3.UP * up + n * (rng.randf_range(0.0, 0.04) - depth * 0.5)
			var scale := Vector3(b[2] - 0.02, b[3] - 0.02, depth) / native
			batch.add(mat, Masonry.piece(centre, u, Vector3.UP, n, scale, rng.randf_range(-0.01, 0.01), Masonry.wobble(rng, 0.5)), rng.randf_range(0.84, 1.1), pick[0])
	if top_material != null:
		var slabs := Masonry.stones("floor")
		for s in Masonry.rows(rng, size.x, size.z, Vector2(1.5, 2.2), Vector2(1.8, 3.2)):
			var centre := Vector3(-hx + s[0] + s[2] * 0.5, size.y + rng.randf_range(0.0, 0.02) - 0.18, -hz + s[1] + s[3] * 0.5)
			var slab := Vector3(s[2] - 0.03, 0.36, s[3] - 0.03)
			var shade := rng.randf_range(0.86, 1.1)
			if slabs.is_empty():
				batch.add(top_material, Masonry.piece(centre, Vector3.RIGHT, Vector3.UP, Vector3.BACK, slab, rng.randf_range(-0.01, 0.01), Masonry.wobble(rng, 0.3)), shade)
			else:
				var pick: Array = slabs[rng.randi() % slabs.size()]
				var turn := 1.0 if rng.randf() < 0.5 else -1.0
				batch.add(top_material, Masonry.piece(centre, Vector3.RIGHT * turn, Vector3.UP, Vector3.BACK * turn, slab / (pick[1] as Vector3), rng.randf_range(-0.01, 0.01), Masonry.wobble(rng, 0.3)), shade, pick[0])
	batch.build(self)
