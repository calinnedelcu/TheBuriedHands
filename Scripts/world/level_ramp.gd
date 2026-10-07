@tool
class_name LevelRamp
extends Node3D
## Stairs or a ramp between two floor heights. The origin is the middle of
## its foot; it climbs `rise` over `run` toward -z. Steps are only how it
## looks: the collider is a smooth slope, so walking up and down is even.
## Rebuilt from its settings; nothing generated is saved. With `masonry`
## every step is dressed stone, two or three to a step, on a dark core.

const ROCK := preload("res://assets/materials/level/tunnel_rock.tres")

@export var width := 3.0:
	set(v):
		width = maxf(v, 0.1)
		_queue_build()
@export var rise := 2.0:
	set(v):
		rise = maxf(v, 0.05)
		_queue_build()
@export var run := 4.0:
	set(v):
		run = maxf(v, 0.1)
		_queue_build()
## 0 for a smooth ramp.
@export_range(0, 64) var steps := 8:
	set(v):
		steps = v
		_queue_build()
@export var material: Material:
	set(v):
		material = v
		_queue_build()
@export var masonry := false:
	set(v):
		masonry = v
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
	var hw := width * 0.5
	if steps > 0 and masonry:
		_dress(mat)
	elif steps > 0:
		var tread := run / steps
		for i in steps:
			var h := rise * float(i + 1) / steps
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(width, h, tread)
			mi.mesh = box
			mi.material_override = mat
			mi.position = Vector3(0, h * 0.5, -tread * (i + 0.5))
			mi.set_meta(&"generated", true)
			add_child(mi)
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-hw, 0, 0)
		var b := Vector3(hw, 0, 0)
		var c := Vector3(hw, rise, -run)
		var d := Vector3(-hw, rise, -run)
		var n := (b - a).cross(d - a).normalized()
		if n.y < 0.0:
			n = -n
		for p in [a, c, b, a, d, c]:
			st.set_normal(n)
			st.set_uv(LevelBox.planar_uv(p, n))
			st.add_vertex(p)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.set_meta(&"generated", true)
		add_child(mi)
	_collider()

## Each step a row of stones on a dark core below it.
func _dress(mat: Material) -> void:
	var batch := Masonry.Batch.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name)) ^ hash(Vector3i(position.round())) ^ pattern_seed
	var tread := run / steps
	var riser := rise / steps
	var hw := width * 0.5
	var core := Masonry.joints(mat)
	for i in steps:
		var top := riser * (i + 1)
		var z := -tread * (i + 0.5)
		if top - riser > 0.01:
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(width - 0.06, top - riser, tread)
			mi.mesh = box
			mi.material_override = core
			mi.position = Vector3(0, (top - riser) * 0.5, z)
			mi.set_meta(&"generated", true)
			add_child(mi)
		# Two or three stones across, their joints not in line with the last.
		var x := -hw
		while x < hw - 0.001:
			var l := minf(rng.randf_range(1.0, 1.9), hw - x)
			if hw - (x + l) < 0.5:
				l = hw - x
			var centre := Vector3(x + l * 0.5, top - riser * 0.5 + 0.01, z + 0.01)
			batch.add(mat, Masonry.piece(centre, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3(l - 0.04, riser + 0.02, tread + 0.02), rng.randf_range(-0.006, 0.006)), rng.randf_range(0.84, 1.1))
			x += l
	batch.build(self)

func _collider() -> void:
	var hw := width * 0.5
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(-hw, 0, -run), Vector3(hw, 0, -run),
		Vector3(-hw, rise, -run), Vector3(hw, rise, -run)])
	shape.shape = wedge
	body.add_child(shape)
