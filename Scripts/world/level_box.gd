@tool
class_name LevelBox
extends Node3D
## A room, a stretch of tunnel or a shaft, seen from inside: floor, walls and
## ceiling, with openings cut where other spaces join, textured with the
## level's triplanar materials (so pieces that meet match) and with a box
## collider behind every face. Built from its settings when it enters the
## tree and again whenever they change in the editor; nothing it generates is
## saved with the scene, only the settings.
##
## The origin is the middle of the floor. Inside, x runs across
## (-size.x/2..size.x/2), y up (0..size.y) and z along (-size.z/2..size.z/2).
## Faces: WEST at -x, EAST at +x, NORTH at -z, SOUTH at +z.
##
## With `masonry` it is built like the workshop: dressed blocks in courses on
## the walls, flagstones on the floor, boards under a timber ceiling (slabs
## under a stone one), the plain faces behind them dark in the joints.

const ROCK := preload("res://assets/materials/level/tunnel_rock.tres")
## How far the plain face sits behind dressed stone.
const BACKING := 0.08

@export var size := Vector3(3.5, 3.3, 12.0):
	set(v):
		size = v.max(Vector3(0.2, 0.2, 0.2))
		_queue_build()
@export_range(0.1, 4.0, 0.05) var thickness := 0.6:
	set(v):
		thickness = v
		_queue_build()
## Walls; also the floor and ceiling when those have none of their own.
@export var wall_material: Material:
	set(v):
		wall_material = v
		_queue_build()
@export var floor_material: Material:
	set(v):
		floor_material = v
		_queue_build()
@export var ceiling_material: Material:
	set(v):
		ceiling_material = v
		_queue_build()
## Faces left out entirely (a tunnel's open ends, a pit with no roof).
@export_flags("Floor", "Ceiling", "West", "East", "North", "South") var open_faces := 0:
	set(v):
		open_faces = v
		_queue_build()
@export var openings: Array[LevelOpening] = []:
	set(v):
		for o in openings:
			if o != null and o.changed.is_connected(_queue_build):
				o.changed.disconnect(_queue_build)
		openings = v
		for o in openings:
			if o != null and not o.changed.is_connected(_queue_build):
				o.changed.connect(_queue_build)
		_queue_build()
@export var collision := true:
	set(v):
		collision = v
		_queue_build()
## World layer bits of the collider (1 = level geometry).
@export_flags_3d_physics var collision_layer := 1:
	set(v):
		collision_layer = v
		_queue_build()

@export_group("Masonry")
@export var masonry := false:
	set(v):
		masonry = v
		_queue_build()
## Height of a course of blocks (rounded so a wall holds whole courses).
@export var course_height := 0.72:
	set(v):
		course_height = maxf(v, 0.1)
		_queue_build()
## Shortest and longest block in a course.
@export var block_length := Vector2(0.9, 1.6):
	set(v):
		block_length = v
		_queue_build()
## More stones for the floor, picked among with floor_material.
@export var floor_variants: Array[Material] = []:
	set(v):
		floor_variants = v
		_queue_build()
## Changes the pattern without moving anything.
@export var pattern_seed := 0:
	set(v):
		pattern_seed = v
		_queue_build()

var _queued := false
var _lines := PackedFloat32Array()

func _ready() -> void:
	_build()

func _queue_build() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_build.call_deferred()

## Face frames: corner origin, u and v axes (unit), extent, inward normal.
func _face(f: int) -> Dictionary:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	match f:
		LevelOpening.Face.FLOOR:
			return {"o": Vector3(-hx, 0, -hz), "u": Vector3.RIGHT, "v": Vector3.BACK, "w": size.x, "h": size.z, "n": Vector3.UP}
		LevelOpening.Face.CEILING:
			return {"o": Vector3(-hx, size.y, -hz), "u": Vector3.RIGHT, "v": Vector3.BACK, "w": size.x, "h": size.z, "n": Vector3.DOWN}
		LevelOpening.Face.WEST:
			return {"o": Vector3(-hx, 0, -hz), "u": Vector3.BACK, "v": Vector3.UP, "w": size.z, "h": size.y, "n": Vector3.RIGHT}
		LevelOpening.Face.EAST:
			return {"o": Vector3(hx, 0, -hz), "u": Vector3.BACK, "v": Vector3.UP, "w": size.z, "h": size.y, "n": Vector3.LEFT}
		LevelOpening.Face.NORTH:
			return {"o": Vector3(-hx, 0, -hz), "u": Vector3.RIGHT, "v": Vector3.UP, "w": size.x, "h": size.y, "n": Vector3.BACK}
		_:
			return {"o": Vector3(-hx, 0, hz), "u": Vector3.RIGHT, "v": Vector3.UP, "w": size.x, "h": size.y, "n": Vector3.FORWARD}

func _material_for(f: int) -> Material:
	var wall: Material = wall_material if wall_material != null else ROCK
	if f == LevelOpening.Face.FLOOR and floor_material != null:
		return floor_material
	if f == LevelOpening.Face.CEILING and ceiling_material != null:
		return ceiling_material
	return wall

func _build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"generated"):
			remove_child(c)
			c.queue_free()
	var tools := {}
	var body: StaticBody3D = null
	if collision:
		body = StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = collision_layer
		body.collision_mask = 0
		body.set_meta(&"generated", true)
		add_child(body)
	var batch: Masonry.Batch = Masonry.Batch.new() if masonry else null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name)) ^ hash(Vector3i(position.round())) ^ pattern_seed
	_lines = Masonry.course_lines(rng, size.y, course_height)
	for f in 6:
		if open_faces & (1 << f):
			continue
		var fr := _face(f)
		var face_rect := Rect2(0, 0, fr.w, fr.h)
		var holes: Array[Rect2] = []
		var lined: Array[Rect2] = []
		for o in openings:
			if o != null and o.face == f:
				var r := _hole_rect(o, fr)
				r = r.intersection(face_rect)
				if r.has_area():
					holes.append(r)
					if o.jambs:
						lined.append(r)
		var mat := _material_for(f)
		# Under masonry the plain face is the dark of the joints.
		var st := _tool(tools, Masonry.joints(mat) if batch != null else mat)
		for r in _subtract(face_rect, holes):
			# Behind dressed stone the face sits back, so the joints are deep.
			_quad(st, fr, r, BACKING if batch != null else 0.0)
			if body != null:
				_collider(body, fr, r)
			if batch != null:
				_dress(batch, rng, f, fr, r, mat)
		if not lined.is_empty():
			var edges := _tool(tools, mat)
			for h in lined:
				_jambs(edges, fr, h)
	var mesh := ArrayMesh.new()
	for mat in tools:
		var st: SurfaceTool = tools[mat]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.set_meta(&"generated", true)
	add_child(mi)
	if batch != null:
		batch.build(self)

func _tool(tools: Dictionary, mat: Material) -> SurfaceTool:
	if not tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[mat] = st
	return tools[mat]

## Lays the stones (or boards) over rectangle `r` of face `f`.
func _dress(batch: Masonry.Batch, rng: RandomNumberGenerator, f: int, fr: Dictionary, r: Rect2, mat: Material) -> void:
	var u: Vector3 = fr.u
	var v: Vector3 = fr.v
	var n: Vector3 = fr.n
	if f == LevelOpening.Face.FLOOR or (f == LevelOpening.Face.CEILING and not Masonry.is_timber(mat)):
		# Flagstones, a little uneven; under a stone ceiling, slabs.
		var stones: Array[Material] = [mat]
		if f == LevelOpening.Face.FLOOR:
			stones.append_array(floor_variants)
		for s in Masonry.rows(rng, r.size.x, r.size.y, Vector2(1.3, 2.1), Vector2(1.6, 2.8)):
			var proud := rng.randf_range(0.0, 0.025)
			var centre := _point(fr, r.position.x + s[0] + s[2] * 0.5, r.position.y + s[1] + s[3] * 0.5) + n * (proud - 0.1)
			var xf := Masonry.piece(centre, u, n, v, Vector3(s[2] - 0.035, 0.2, s[3] - 0.035), rng.randf_range(-0.01, 0.01), Masonry.wobble(rng, 0.3))
			batch.add(stones[rng.randi() % stones.size()], xf, rng.randf_range(0.84, 1.1))
	elif f == LevelOpening.Face.CEILING:
		# Boards along the longer side, hung a little unevenly.
		var along_u := r.size.x >= r.size.y
		var lu := u if along_u else v
		var lv := v if along_u else u
		var w := r.size.x if along_u else r.size.y
		var d := r.size.y if along_u else r.size.x
		for b in Masonry.rows(rng, w, d, Vector2(0.45, 0.7), Vector2(2.6, 4.6)):
			var cu: float = b[0] + b[2] * 0.5
			var cv: float = b[1] + b[3] * 0.5
			var at := _point(fr, r.position.x + (cu if along_u else cv), r.position.y + (cv if along_u else cu))
			var centre := at + n * (rng.randf_range(0.02, 0.06) - 0.06)
			batch.add(mat, Masonry.piece(centre, lu, n, lv, Vector3(b[2] - 0.03, 0.12, b[3] - 0.035), rng.randf_range(-0.006, 0.006)), rng.randf_range(0.8, 1.12))
	else:
		# Dressed blocks in courses, each standing a little proud of the wall.
		for b in Masonry.courses(rng, r.size.x, r.position.y, r.end.y, _lines, block_length):
			var proud := rng.randf_range(0.01, 0.07)
			var centre := _point(fr, r.position.x + b[0] + b[2] * 0.5, b[1] + b[3] * 0.5) + n * (proud - 0.2)
			batch.add(mat, Masonry.piece(centre, u, v, n, Vector3(b[2] - 0.025, b[3] - 0.025, 0.4), rng.randf_range(-0.008, 0.008), Masonry.wobble(rng, 0.8)), rng.randf_range(0.82, 1.1))

func _hole_rect(o: LevelOpening, fr: Dictionary) -> Rect2:
	var f := o.face
	if f == LevelOpening.Face.FLOOR or f == LevelOpening.Face.CEILING:
		var c := Vector2(o.offset.x + size.x * 0.5, o.offset.y + size.z * 0.5)
		return Rect2(c - o.size * 0.5, o.size)
	var u := float(fr.w) * 0.5 + o.offset.x - o.size.x * 0.5
	return Rect2(u, o.offset.y, o.size.x, o.size.y)

func _point(fr: Dictionary, u: float, v: float) -> Vector3:
	return fr.o + fr.u * u + fr.v * v

## The face minus its holes, as a few rectangles (a grid on the holes'
## edges, merged along rows).
func _subtract(face: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	if holes.is_empty():
		return [face]
	var xs := [face.position.x, face.end.x]
	var ys := [face.position.y, face.end.y]
	for h in holes:
		xs.append_array([h.position.x, h.end.x])
		ys.append_array([h.position.y, h.end.y])
	xs = _unique_sorted(xs)
	ys = _unique_sorted(ys)
	var out: Array[Rect2] = []
	for j in ys.size() - 1:
		var run_start := -1.0
		var run_end := -1.0
		for i in xs.size() - 1:
			var cell := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			var centre := cell.get_center()
			var cut := false
			for h in holes:
				if h.has_point(centre):
					cut = true
					break
			if not cut:
				if run_start < 0.0:
					run_start = cell.position.x
				run_end = cell.end.x
			elif run_start >= 0.0:
				out.append(Rect2(run_start, ys[j], run_end - run_start, ys[j + 1] - ys[j]))
				run_start = -1.0
		if run_start >= 0.0:
			out.append(Rect2(run_start, ys[j], run_end - run_start, ys[j + 1] - ys[j]))
	return out

func _unique_sorted(values: Array) -> Array:
	values.sort()
	var out := []
	for v in values:
		if out.is_empty() or absf(float(v) - float(out.back())) > 0.001:
			out.append(v)
	return out

## Two triangles facing `n`. Godot's front faces wind clockwise.
func _tri_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = d
		d = t
	for p in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(LevelBox.planar_uv(p, n))
		st.add_vertex(p)

## Texture coordinates projected along the face's axis, for materials that
## aren't triplanar (and for tangents).
static func planar_uv(p: Vector3, n: Vector3) -> Vector2:
	if absf(n.y) > 0.5:
		return Vector2(p.x, p.z) * 0.25
	if absf(n.x) > 0.5:
		return Vector2(p.z, p.y) * 0.25
	return Vector2(p.x, p.y) * 0.25

func _quad(st: SurfaceTool, fr: Dictionary, r: Rect2, inset := 0.0) -> void:
	var back: Vector3 = -fr.n * inset
	_tri_quad(st, _point(fr, r.position.x, r.position.y) + back, _point(fr, r.end.x, r.position.y) + back,
		_point(fr, r.end.x, r.end.y) + back, _point(fr, r.position.x, r.end.y) + back, fr.n)

## The cut edges of a hole, as deep as the wall is thick.
func _jambs(st: SurfaceTool, fr: Dictionary, h: Rect2) -> void:
	var out_dir: Vector3 = -fr.n * thickness
	if h.position.x > 0.001:
		var a := _point(fr, h.position.x, h.position.y)
		var b := _point(fr, h.position.x, h.end.y)
		_tri_quad(st, a, b, b + out_dir, a + out_dir, fr.u)
	if h.end.x < float(fr.w) - 0.001:
		var a := _point(fr, h.end.x, h.position.y)
		var b := _point(fr, h.end.x, h.end.y)
		_tri_quad(st, a, b, b + out_dir, a + out_dir, -fr.u)
	if h.position.y > 0.001:
		var a := _point(fr, h.position.x, h.position.y)
		var b := _point(fr, h.end.x, h.position.y)
		_tri_quad(st, a, b, b + out_dir, a + out_dir, fr.v)
	if h.end.y < float(fr.h) - 0.001:
		var a := _point(fr, h.position.x, h.end.y)
		var b := _point(fr, h.end.x, h.end.y)
		_tri_quad(st, a, b, b + out_dir, a + out_dir, -fr.v)

func _collider(body: StaticBody3D, fr: Dictionary, r: Rect2) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var u: Vector3 = fr.u
	var v: Vector3 = fr.v
	var n: Vector3 = fr.n
	box.size = (u * r.size.x + v * r.size.y + n * thickness).abs()
	shape.shape = box
	shape.position = _point(fr, r.get_center().x, r.get_center().y) - n * thickness * 0.5
	body.add_child(shape)
