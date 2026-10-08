@tool
class_name StatueRanks
extends Node3D
## Ranks of clay soldiers standing in a trench, as in the pits of the
## terracotta army: drawn as one multimesh per kind of figure, each figure
## with its own collider, and over them an area where a player who stands
## still with no flame is one more figure to a guard's eye
## (Player.camouflaged()). The craftsman is grey with clay dust from his work.
##
## No two alike, as in the real pits: infantrymen with clasped hands and
## armoured warriors mixed in the ranks, each fired a little lighter or
## darker, a taller officer at the head of the trench, and here and there one
## broken off at the hips, his head fallen beside him.
##
## The grid is centred on the origin, `columns` across (x) and `rows` along
## (z); the figures face -z. Cells listed in `gaps` (column, row) stay empty:
## a broken figure, a way through.

const SOLDIER := preload("res://TripoModels/statue1-idle.glb")
const ARMOURED := preload("res://assets/models/props/figures/warrior_armored.glb")
const LEGS := preload("res://assets/models/props/figures/figure_legs.glb")
const HEAD := preload("res://assets/models/props/figures/figure_head.glb")
## [scene, height against a whole figure]
const KINDS := [[SOLDIER, 1.0], [ARMOURED, 1.0], [LEGS, 0.55]]
const SOLDIER_SHARE := 0.6

@export_range(1, 12) var columns := 3:
	set(v):
		columns = v
		_queue_build()
@export_range(1, 40) var rows := 10:
	set(v):
		rows = v
		_queue_build()
## Between figures: across (x) and along (z).
@export var spacing := Vector2(1.8, 2.4):
	set(v):
		spacing = v
		_queue_build()
## Height of a figure in level units (the tomb is built at 1.75 times life).
@export var figure_height := 3.2:
	set(v):
		figure_height = v
		_queue_build()
@export var gaps: PackedVector2Array = PackedVector2Array():
	set(v):
		gaps = v
		_queue_build()
@export var variation_seed := 1:
	set(v):
		variation_seed = v
		_queue_build()
## How many of them broke, out of one.
@export_range(0.0, 0.5) var broken := 0.08:
	set(v):
		broken = v
		_queue_build()
## A taller officer at the head of the trench (the first rank, middle).
@export var officer := true:
	set(v):
		officer = v
		_queue_build()

var _queued := false
static var _tinted_mats := {}

func _ready() -> void:
	_build()

func _queue_build() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_build.call_deferred()

func _cells() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in rows:
		for c in columns:
			if not gaps.has(Vector2(c, r)):
				out.append(Vector2(c, r))
	return out

func cell_position(c: int, r: int) -> Vector3:
	return Vector3((c - (columns - 1) * 0.5) * spacing.x, 0.0, (r - (rows - 1) * 0.5) * spacing.y)

func _build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"generated"):
			remove_child(c)
			c.queue_free()
	var cells := _cells()
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	# [kind, yaw, height, place, tint] for every figure, and the heads that fell.
	var placed: Array = []
	var heights: Array[float] = []
	for cell in cells:
		var kind := 0 if rng.randf() < SOLDIER_SHARE else 1
		var tall := rng.randf_range(0.97, 1.03)
		if officer and int(cell.y) == 0 and int(cell.x) == columns / 2:
			kind = 1
			tall = 1.08
		elif rng.randf() < broken:
			kind = 2
		# Tripo figures face +x; a quarter turn more faces them down -z.
		var yaw := PI * 0.5 + deg_to_rad(rng.randf_range(-4.0, 4.0))
		var at := cell_position(int(cell.x), int(cell.y))
		placed.append([kind, yaw, tall, at, _tint(rng)])
		heights.append(figure_height * float(KINDS[kind][1]) * tall)
		if kind == 2:
			# His head lies at his feet, on its side.
			var fall := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.9, -0.4))
			placed.append([3, rng.randf_range(-PI, PI), 1.0, at + fall, _tint(rng)])
	var inverse := global_transform.affine_inverse()
	var scenes := [SOLDIER, ARMOURED, LEGS, HEAD]
	for kind in scenes.size():
		var parts := _parts(scenes[kind] as PackedScene, inverse)
		var top: float = parts[0]
		var unit := figure_height / maxf(top, 0.01)
		var xforms: Array[Transform3D] = []
		var tints := PackedColorArray()
		for p in placed:
			if p[0] != kind:
				continue
			var basis: Basis
			if kind == 3:
				# A head (as tall as a sixth of a figure), on its side.
				var s := figure_height * 0.17 / maxf(top, 0.01)
				basis = Basis(Vector3.UP, p[1]) * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * s)
				var lie: Vector3 = p[3]
				lie.y = parts[2] * s
				xforms.append(Transform3D(basis, lie))
			else:
				var s := unit * float(KINDS[kind][1]) * float(p[2])
				basis = Basis(Vector3.UP, p[1]).scaled(Vector3.ONE * s)
				xforms.append(Transform3D(basis, p[3]))
			tints.append(p[4])
		if xforms.is_empty():
			continue
		for part in parts[1]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = part[0]
			mm.instance_count = xforms.size()
			for k in xforms.size():
				mm.set_instance_transform(k, xforms[k] * part[1])
				mm.set_instance_color(k, tints[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = part[2]
			mmi.set_meta(&"generated", true)
			add_child(mmi)
	# A collider per figure.
	var body := StaticBody3D.new()
	body.name = "Figures"
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body)
	for i in cells.size():
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.36
		cyl.height = heights[i]
		shape.shape = cyl
		shape.position = cell_position(int(cells[i].x), int(cells[i].y)) + Vector3.UP * heights[i] * 0.5
		body.add_child(shape)
	# Where standing still makes you one of them.
	if Engine.is_editor_hint():
		return
	var area := Area3D.new()
	area.name = "Ranks"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	area.set_meta(&"generated", true)
	var zone := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(columns * spacing.x + 0.6, figure_height, rows * spacing.y + 0.6)
	zone.shape = box
	zone.position = Vector3.UP * figure_height * 0.5
	area.add_child(zone)
	add_child(area)
	area.body_entered.connect(func(b: Node3D):
		if b is Player:
			(b as Player).ranks += 1)
	area.body_exited.connect(func(b: Node3D):
		if b is Player:
			(b as Player).ranks = maxi(0, (b as Player).ranks - 1))

## A figure's meshes in this node's space with the materials to draw them
## tinted, and how tall it stands and how wide it lies: [top, [[mesh,
## transform, material], ...], half width].
func _parts(scene: PackedScene, inverse: Transform3D) -> Array:
	var model := scene.instantiate() as Node3D
	add_child(model)
	var top := 0.0
	var half_width := 0.0
	var out: Array = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y - model.global_position.y)
		half_width = maxf(half_width, box.size.z * 0.5)
		var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
		out.append([mi.mesh, inverse * mi.global_transform, _tinted(mat)])
	remove_child(model)
	model.free()
	return [top, out, half_width]

## The figure's own material, drawn in each figure's colour (fired a little
## lighter or darker, a few with traces of paint).
static func _tinted(mat: Material) -> Material:
	if not (mat is BaseMaterial3D):
		return mat
	if not _tinted_mats.has(mat):
		var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = true
		_tinted_mats[mat] = copy
	return _tinted_mats[mat]

func _tint(rng: RandomNumberGenerator) -> Color:
	var v := rng.randf_range(0.84, 1.06)
	var c := Color(v, v * rng.randf_range(0.95, 1.0), v * rng.randf_range(0.9, 1.0))
	# Now and then a trace of the lacquer and paint they were finished in.
	if rng.randf() < 0.12:
		c = c * Color(1.06, 0.9, 0.84)
	return c
