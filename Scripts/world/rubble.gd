@tool
class_name Rubble
extends Node3D
## A cave-in for building the tomb: broken rock heaped from wall to wall and
## up to the roof, its slope spilling forward onto the floor, with the pit
## props that held the roof snapped in it. It fills the tunnel where it
## stands and stops whoever walks into it.
##
## The origin is on the floor, in the middle across the tunnel, where the
## roof came down: the heap stands full height behind it (+z, `size.z` deep)
## and spills `spill` forward (-z). Local x runs across the tunnel. Rebuilt
## from its settings; nothing generated is saved.

const ROCK := preload("res://assets/materials/level/tunnel_rock.tres")
const TIMBER := preload("res://assets/materials/level/timber.tres")
## Distinct rock shapes, shared by every heap.
const SHAPES := 7

## Across the tunnel, up to its roof, and how deep the full-height mass goes.
@export var size := Vector3(3.5, 3.4, 2.5):
	set(v):
		size = v.max(Vector3(0.5, 0.5, 0.2))
		_queue_build()
## How far the slope runs out in front, onto the floor.
@export var spill := 3.0:
	set(v):
		spill = maxf(v, 0.5)
		_queue_build()
## Broken props lying in the heap.
@export_range(0, 4) var props := 2:
	set(v):
		props = v
		_queue_build()
@export var material: Material:
	set(v):
		material = v
		_queue_build()
@export var pattern_seed := 0:
	set(v):
		pattern_seed = v
		_queue_build()

static var _shapes: Array[ArrayMesh] = []

var _queued := false

func _ready() -> void:
	_build()

func _queue_build() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_build.call_deferred()

## Height of the heap's surface at (x, z): the roof behind the fall, a slope
## in front of it, piled a little higher against the walls.
func surface(x: float, z: float) -> float:
	if z >= 0.0:
		return size.y
	var t := clampf((z + spill) / spill, 0.0, 1.0)
	var walls := pow(clampf(absf(x) / (size.x * 0.5), 0.0, 1.0), 2.0) * 0.35
	return minf(size.y, size.y * pow(t, 1.25) + walls * t)

func _build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"generated"):
			remove_child(c)
			c.queue_free()
	var mat: Material = material if material != null else ROCK
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name)) ^ pattern_seed
	_add_core(mat)
	var batch := Masonry.Batch.new()
	var shapes := rock_shapes()
	var hx := size.x * 0.5
	# The slope, rock by rock: the big ones rolled furthest, to the toe.
	var step := 0.42
	var z := -spill
	while z < 0.6:
		var x := -hx + 0.1
		while x < hx - 0.05:
			var px := x + rng.randf_range(-0.2, 0.2)
			var pz := z + rng.randf_range(-0.18, 0.18)
			var t := clampf((pz + spill) / spill, 0.0, 1.0)
			# Across, in metres.
			var d := lerpf(0.75, 0.42, t) * rng.randf_range(0.7, 1.35)
			var top := surface(px, pz)
			var y := top - d * rng.randf_range(0.05, 0.35)
			if pz > 0.0:
				# Where the heap meets the roof: wedged up into it.
				y = size.y - d * rng.randf_range(0.0, 0.4)
			_rock(batch, shapes, rng, Vector3(clampf(px, -hx + d * 0.25, hx - d * 0.25), maxf(y, d * 0.2), pz), d)
			x += step * rng.randf_range(0.75, 1.15)
		z += step * rng.randf_range(0.7, 1.0)
	# Smaller stones packed into the upper slope, where the roof let go.
	for i in int(size.x * spill * 9.0):
		var d := rng.randf_range(0.22, 0.42)
		var pz := rng.randf_range(-spill * 0.5, 0.3)
		var px := rng.randf_range(-hx + 0.15, hx - 0.15)
		_rock(batch, shapes, rng, Vector3(px, surface(px, pz) - d * rng.randf_range(0.05, 0.3), pz), d)
	# A few big blocks that rolled down to the foot.
	for i in 3:
		var d := rng.randf_range(0.9, 1.3)
		var pz := rng.randf_range(-spill * 0.8, -spill * 0.45)
		var px := rng.randf_range(-hx + d * 0.4, hx - d * 0.4)
		_rock(batch, shapes, rng, Vector3(px, maxf(surface(px, pz) - d * 0.35, d * 0.22), pz), d)
	# Stones that bounced out across the floor.
	for i in 16:
		var d := rng.randf_range(0.1, 0.32)
		var pz := -spill - rng.randf_range(-0.2, 1.4)
		var px := rng.randf_range(-hx + 0.2, hx - 0.2)
		_rock(batch, shapes, rng, Vector3(px, d * 0.15, pz), d)
	batch.build(self)
	for c in get_children():
		if c is MultiMeshInstance3D and c.has_meta(&"generated"):
			(c as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_props(rng)
	_add_collision()

## One stone `d` metres across, turned any which way.
func _rock(batch: Masonry.Batch, shapes: Array[ArrayMesh], rng: RandomNumberGenerator, at: Vector3, d: float) -> void:
	var basis := Basis(Quaternion.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))))
	var mat: Material = material if material != null else ROCK
	batch.add(mat, Transform3D(basis.scaled(Vector3.ONE * d), at), rng.randf_range(0.72, 1.05), shapes[rng.randi() % shapes.size()])

## A wedge of plain rock under the loose stones, so nothing behind shows
## between them: the slope set back a little, then full height to the back.
func _add_core(mat: Material) -> void:
	var hx := size.x * 0.5 - 0.04
	var toe := -spill + 0.55
	var crest := 0.15
	var top := size.y - 0.02
	var back := size.z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slope_n := Vector3(0.0, crest - toe, -top).normalized()
	_quad(st, [Vector3(-hx, 0.0, toe), Vector3(hx, 0.0, toe), Vector3(hx, top, crest), Vector3(-hx, top, crest)], slope_n)
	_quad(st, [Vector3(-hx, top, crest), Vector3(hx, top, crest), Vector3(hx, top, back), Vector3(-hx, top, back)], Vector3.UP)
	_quad(st, [Vector3(-hx, 0.0, back), Vector3(hx, 0.0, back), Vector3(hx, top, back), Vector3(-hx, top, back)], Vector3.BACK)
	for sx in [-1.0, 1.0]:
		var n := Vector3(sx, 0.0, 0.0)
		_quad(st, [Vector3(sx * hx, 0.0, toe), Vector3(sx * hx, 0.0, back), Vector3(sx * hx, top, back), Vector3(sx * hx, top, crest)], n)
	var mi := MeshInstance3D.new()
	mi.name = "Core"
	mi.mesh = st.commit()
	mi.material_override = Masonry.joints(mat)
	mi.set_meta(&"generated", true)
	add_child(mi)

## The props that held the roof, snapped and lying in the heap: one fallen
## along the slope, one sticking out near the top.
func _add_props(rng: RandomNumberGenerator) -> void:
	var hx := size.x * 0.5
	var spots := [
		[Vector3(-hx + 0.45, 0.0, -spill + 0.5), Vector3(hx - 0.7, 0.0, -0.3), 0.08],
		[Vector3(hx * 0.35, 0.0, 0.4), Vector3(-hx * 0.2, 0.0, -spill * 0.5), 0.02],
		[Vector3(hx - 0.4, 0.0, -spill * 0.85), Vector3(hx * 0.1, 0.0, -spill - 0.6), 0.0],
		[Vector3(-hx * 0.6, 0.0, -0.2), Vector3(-hx + 0.3, 0.0, -spill * 0.6), 0.05],
	]
	for i in mini(props, spots.size()):
		var spot: Array = spots[i]
		var a: Vector3 = spot[0]
		var b: Vector3 = spot[1]
		# Resting on the slope, a little sunk into it.
		a.y = surface(a.x, a.z) - 0.12 + float(spot[2])
		b.y = surface(b.x, b.z) - 0.05
		if i == 2:
			a.y = 0.12
			b.y = 0.1
		var length := a.distance_to(b)
		var beam := MeshInstance3D.new()
		beam.name = "Prop%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.22, length)
		beam.mesh = box
		beam.material_override = TIMBER
		beam.set_meta(&"generated", true)
		add_child(beam)
		var mid := (a + b) * 0.5
		beam.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP).rotated((b - a).normalized(), rng.randf_range(-0.4, 0.4)), mid)
		# Its splintered end: a short piece kinked off it.
		var stub := MeshInstance3D.new()
		var stub_box := BoxMesh.new()
		stub_box.size = Vector3(0.16, 0.18, 0.5)
		stub.mesh = stub_box
		stub.material_override = TIMBER
		stub.set_meta(&"generated", true)
		add_child(stub)
		var kink := Basis.looking_at(b - a, Vector3.UP).rotated(Vector3.UP, rng.randf_range(0.35, 0.7) * (1.0 if rng.randf() < 0.5 else -1.0))
		stub.transform = Transform3D(kink, b + (b - a).normalized() * 0.18 + Vector3.UP * 0.04)

## A box from a little way up the slope to the back: whoever walks in stops
## on the stones at its foot (a slope would be climbed, step by step).
func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var front := -spill * 0.7
	box.size = Vector3(size.x, size.y, size.z - front)
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, (size.z + front) * 0.5)
	body.add_child(shape)

## Rough lumps of broken rock, about a unit across: noisy spheres cut flat
## by a few fracture planes, faceted.
static func rock_shapes() -> Array[ArrayMesh]:
	if not _shapes.is_empty():
		return _shapes
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var sphere := _icosphere(2)
	var base: Array[Vector3] = sphere[0]
	var tris: Array = sphere[1]
	for k in SHAPES:
		var noise := FastNoiseLite.new()
		noise.seed = rng.randi()
		noise.frequency = 0.9
		noise.fractal_octaves = 3
		var squash := Vector3(rng.randf_range(0.85, 1.2), rng.randf_range(0.5, 0.78), rng.randf_range(0.7, 1.05))
		var planes: Array[Plane] = []
		for i in rng.randi_range(3, 5):
			var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			planes.append(Plane(n, rng.randf_range(0.5, 0.8)))
		var verts: Array[Vector3] = []
		for v in base:
			var p := v * (1.0 + noise.get_noise_3dv(v * 1.7) * 0.32)
			for pl in planes:
				var d := pl.distance_to(p)
				if d > 0.0:
					p -= pl.normal * d
			verts.append(p * squash * 0.5)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri in tris:
			var a := verts[tri[0]]
			var b := verts[tri[1]]
			var c := verts[tri[2]]
			var n := (c - a).cross(b - a)
			if n.length_squared() < 1e-10:
				continue
			# Faces point away from the middle.
			if n.dot((a + b + c) / 3.0) < 0.0:
				var t := b
				b = c
				c = t
				n = -n
			n = n.normalized()
			for p in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(p)
		_shapes.append(st.commit())
	return _shapes

## An icosahedron split `subdiv` times, on the unit sphere: [points, triangles].
static func _icosphere(subdiv: int) -> Array:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var pts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in pts.size():
		pts[i] = pts[i].normalized()
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s in subdiv:
		var mids := {}
		var next := []
		for f in faces:
			var ab := _midpoint(pts, mids, f[0], f[1])
			var bc := _midpoint(pts, mids, f[1], f[2])
			var ca := _midpoint(pts, mids, f[2], f[0])
			next.append([f[0], ab, ca])
			next.append([f[1], bc, ab])
			next.append([f[2], ca, bc])
			next.append([ab, bc, ca])
		faces = next
	return [pts, faces]

static func _midpoint(pts: Array[Vector3], mids: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if mids.has(key):
		return mids[key]
	pts.append(((pts[a] + pts[b]) * 0.5).normalized())
	mids[key] = pts.size() - 1
	return pts.size() - 1

## A quad facing `n`, wound for Godot's clockwise front faces.
static func _quad(st: SurfaceTool, pts: Array, n: Vector3) -> void:
	for k in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = pts[k[0]]
		var b: Vector3 = pts[k[1]]
		var c: Vector3 = pts[k[2]]
		if (b - a).cross(c - a).dot(n) > 0.0:
			var t := b
			b = c
			c = t
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)
