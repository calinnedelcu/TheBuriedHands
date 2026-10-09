@tool
class_name WallFrieze
extends Node3D
## A band carved along a wall, a hand and a half of stone course with a
## motif standing out of it: waves (the river) or peaks (the mountain).
## Along the great corridor the masons carved the Wei river's waves on one
## wall and Mount Li's peaks on the other, as the tomb lies under the one
## and beside the other, so a man can tell his sides in the dark. (Bai's
## song names them: "from the wall of waves", "toward the peaks".)
##
## Local space: x along the wall, y up, +z out of the wall into the room; the
## origin is at the wall's face, at the band's lower edge. Rebuilt from its
## settings; nothing generated is saved.

enum Motif { WAVES, PEAKS }

const STONE := preload("res://assets/materials/level/walls.tres")

@export var motif := Motif.WAVES:
	set(v):
		motif = v
		_queue_build()
@export var length := 40.0:
	set(v):
		length = maxf(v, 1.0)
		_queue_build()
@export var band_height := 0.55:
	set(v):
		band_height = maxf(v, 0.2)
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
	for c in get_children():
		if c.has_meta(&"generated"):
			c.free()
	# The course: a slab of the wall's own stone, standing a hand off it.
	var band := MeshInstance3D.new()
	band.name = "Band"
	var box := BoxMesh.new()
	box.size = Vector3(length, band_height, 0.16)
	band.mesh = box
	band.material_override = STONE
	band.position = Vector3(length * 0.5, band_height * 0.5, 0.0)
	band.set_meta(&"generated", true)
	add_child(band)
	# The motif on it, in a darker, redder stone, raised another hand's width.
	var mi := MeshInstance3D.new()
	mi.name = "Motif"
	mi.mesh = _motif_mesh()
	mi.set_meta(&"generated", true)
	add_child(mi)

func _motif_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := 0.08
	var z1 := 0.14
	var thick := 0.07
	match motif:
		Motif.WAVES:
			# Two rows of curling waves, a stroke of the chisel each.
			for row in 2:
				var y := band_height * (0.32 if row == 0 else 0.68)
				var phase := 0.0 if row == 0 else 0.5
				_ribbon(st, y, 0.12, 0.9, phase, z0, z1, thick, false)
		Motif.PEAKS:
			# Peaks like the range's, a tall one between two low.
			_ribbon(st, band_height * 0.18, 0.28, 1.5, 0.0, z0, z1, thick, true)
			_ribbon(st, band_height * 0.18, 0.18, 0.9, 0.35, z0, z1, thick, true)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.17, 0.11)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh

## A stroke along the wall: a sine wave (`zig` off) or a zigzag of peaks (on),
## `amp` high, one cycle `cycle` long, `thick` wide, between depths z0 and z1.
func _ribbon(st: SurfaceTool, y: float, amp: float, cycle: float, phase: float, z0: float, z1: float, thick: float, zig: bool) -> void:
	var step := cycle / 8.0
	var x := 0.15
	var prev := Vector3.ZERO
	var first := true
	while x < length - 0.15:
		var t := fposmod(x / cycle + phase, 1.0)
		var h := (1.0 - absf(t * 2.0 - 1.0)) if zig else (0.5 + 0.5 * sin(t * TAU))
		var p := Vector3(x, y + h * amp, 0.0)
		if not first:
			_stroke(st, prev, p, z0, z1, thick)
		prev = p
		first = false
		x += step

## A short raised bar from `a` to `b` (in the wall's plane), thick wide.
func _stroke(st: SurfaceTool, a: Vector3, b: Vector3, z0: float, z1: float, thick: float) -> void:
	var d := (b - a).normalized()
	var n := Vector3(-d.y, d.x, 0.0) * thick * 0.5
	var p0 := a + n
	var p1 := a - n
	var p2 := b - n
	var p3 := b + n
	# The face, and the two long sides, as a low ridge.
	for tri in [[p0, p1, p2], [p0, p2, p3]]:
		st.set_normal(Vector3.BACK)
		for v in tri:
			st.add_vertex(Vector3((v as Vector3).x, (v as Vector3).y, z1))
	for edge in [[p0, p3], [p1, p2]]:
		var u: Vector3 = edge[0]
		var w: Vector3 = edge[1]
		st.set_normal(Vector3.UP)
		for v in [Vector3(u.x, u.y, z0), Vector3(w.x, w.y, z0), Vector3(w.x, w.y, z1), Vector3(u.x, u.y, z0), Vector3(w.x, w.y, z1), Vector3(u.x, u.y, z1)]:
			st.add_vertex(v)
