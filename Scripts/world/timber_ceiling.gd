@tool
class_name TimberCeiling
extends Node3D
## A roof of boards on beams, as over the workshops: beams across the room
## every few metres, boards laid over them the other way and hung a little
## unevenly, a dark underlay above so no gap shows the void. Drawn only over
## the cells of `cover`, so it follows a room that isn't a rectangle. Built
## from its settings; nothing generated is saved. Only for looks: no collider.
##
## The origin is the corner of cell (0, 0) at the boards' undersides; cells
## run along +x and +z. Beams hang below the boards, along x.

const TIMBER := preload("res://assets/materials/level/timber.tres")

@export var cells := Vector2i(8, 8):
	set(v):
		cells = v.max(Vector2i.ONE)
		_queue_build()
@export var cell_size := 1.0:
	set(v):
		cell_size = maxf(v, 0.1)
		_queue_build()
## One byte per cell, row after row along x: 0 = no ceiling there. Empty =
## every cell.
@export var cover := PackedByteArray():
	set(v):
		cover = v
		_queue_build()
@export var beam_spacing := 3.6:
	set(v):
		beam_spacing = maxf(v, 0.8)
		_queue_build()
@export var beam_size := Vector2(0.42, 0.4):
	set(v):
		beam_size = v
		_queue_build()
@export var material: Material:
	set(v):
		material = v
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

func covered(ix: int, iz: int) -> bool:
	if ix < 0 or iz < 0 or ix >= cells.x or iz >= cells.y:
		return false
	if cover.is_empty():
		return true
	var k := iz * cells.x + ix
	return k < cover.size() and cover[k] != 0

## Runs of covered cells [from, to) along a line of cells.
func _runs(count: int, is_on: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start := -1
	for k in count + 1:
		var on: bool = k < count and is_on.call(k)
		if on and start < 0:
			start = k
		elif not on and start >= 0:
			out.append(Vector2i(start, k))
			start = -1
	return out

func _build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"generated"):
			remove_child(c)
			c.queue_free()
	var mat: Material = material if material != null else TIMBER
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name)) ^ hash(Vector3i(position.round())) ^ pattern_seed
	var batch := Masonry.Batch.new()
	var cs := cell_size
	# The underlay, row by row of covered cells.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in cells.y:
		for run in _runs(cells.x, func(ix: int) -> bool: return covered(ix, iz)):
			var a := Vector3(run.x * cs, 0.16, iz * cs)
			var b := Vector3(run.y * cs, 0.16, iz * cs)
			var c := Vector3(run.y * cs, 0.16, (iz + 1) * cs)
			var d := Vector3(run.x * cs, 0.16, (iz + 1) * cs)
			for p in [a, c, b, a, d, c]:
				st.set_normal(Vector3.DOWN)
				st.add_vertex(p)
	var under := MeshInstance3D.new()
	under.name = "Underlay"
	under.mesh = st.commit()
	under.material_override = Masonry.joints(mat)
	under.set_meta(&"generated", true)
	add_child(under)
	# Boards along z, in strips across x, over the covered runs.
	var x := 0.0
	var width := cells.x * cs
	while x < width - 0.001:
		var bw := minf(rng.randf_range(0.45, 0.7), width - x)
		var ix := int((x + bw * 0.5) / cs)
		for run in _runs(cells.y, func(iz: int) -> bool: return covered(ix, iz)):
			var z := run.x * cs
			var end := run.y * cs
			var l := rng.randf_range(0.4, 1.0) * 4.6
			while z < end - 0.001:
				l = minf(l, end - z)
				if end - (z + l) < 1.2:
					l = end - z
				var centre := Vector3(x + bw * 0.5, 0.06 + rng.randf_range(0.0, 0.04), z + l * 0.5)
				batch.add(mat, Masonry.piece(centre, Vector3.BACK, Vector3.UP, Vector3.RIGHT, Vector3(l - 0.04, 0.12, bw - 0.035), rng.randf_range(-0.006, 0.006)), rng.randf_range(0.8, 1.12))
				z += l
				l = rng.randf_range(2.6, 4.6)
		x += bw
	# Beams along x under them, every beam_spacing.
	var bz := beam_spacing * 0.5
	while bz < cells.y * cs:
		var iz := int(bz / cs)
		for run in _runs(cells.x, func(ix: int) -> bool: return covered(ix, iz)):
			var length := (run.y - run.x) * cs
			var centre := Vector3(run.x * cs + length * 0.5, -beam_size.y * 0.5, bz)
			batch.add(mat, Masonry.piece(centre, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3(length, beam_size.y, beam_size.x), rng.randf_range(-0.003, 0.003)), rng.randf_range(0.62, 0.78))
		bz += beam_spacing
	batch.build(self)
