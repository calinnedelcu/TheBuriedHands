@tool
class_name StatueRanks
extends Node3D
## Ranks of clay soldiers standing in a trench, as in the pits of the
## terracotta army: drawn as one multimesh per part of the model, each figure
## with its own collider, and over them an area where a player who stands
## still with no flame is one more figure to a guard's eye
## (Player.camouflaged()). The craftsman is grey with clay dust from his work.
##
## The grid is centred on the origin, `columns` across (x) and `rows` along
## (z); the figures face -z. Cells listed in `gaps` (column, row) stay empty:
## a broken figure, a way through.

const SOLDIER := preload("res://TripoModels/statue1-idle.glb")

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

var _queued := false

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
	var model := SOLDIER.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	add_child(model)
	var top := 0.0
	for mi in meshes:
		top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y - model.global_position.y)
	var scale_to := figure_height / maxf(top, 0.01)
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	var placements: Array[Transform3D] = []
	for cell in cells:
		# Tripo figures face +x; a quarter turn more faces them down -z.
		var yaw := PI * 0.5 + deg_to_rad(rng.randf_range(-4.0, 4.0))
		var s := scale_to * rng.randf_range(0.97, 1.03)
		placements.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), cell_position(int(cell.x), int(cell.y))))
	var inverse := global_transform.affine_inverse()
	for mi in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = placements.size()
		var local := inverse * mi.global_transform
		for k in placements.size():
			mm.set_instance_transform(k, placements[k] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mi.material_override != null:
			mmi.material_override = mi.material_override
		mmi.set_meta(&"generated", true)
		add_child(mmi)
	remove_child(model)
	model.queue_free()
	# A collider per figure.
	var body := StaticBody3D.new()
	body.name = "Figures"
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body)
	for cell in cells:
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.36
		cyl.height = figure_height
		shape.shape = cyl
		shape.position = cell_position(int(cell.x), int(cell.y)) + Vector3.UP * figure_height * 0.5
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
