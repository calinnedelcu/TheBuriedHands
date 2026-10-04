@tool
@icon("res://assets/editor/route.svg")
class_name PatrolRoute
extends Node3D
## A guard's beat: its Marker3D children in order. A marker can carry metadata
## `wait` (seconds to pause) and `look` (true = look around while paused).
## In the editor the route is drawn as a line so it is easy to tweak.

@export var loop := true
@export var default_wait := 1.5

var _debug_mesh: MeshInstance3D

func points() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in get_children():
		if c is Marker3D:
			out.append(c)
	return out

func wait_at(index: int) -> float:
	var pts := points()
	if index < 0 or index >= pts.size():
		return default_wait
	return float(pts[index].get_meta(&"wait", default_wait))

func looks_at(index: int) -> bool:
	var pts := points()
	return index >= 0 and index < pts.size() and bool(pts[index].get_meta(&"look", false))

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	_draw_debug()

func _draw_debug() -> void:
	var pts := points()
	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 0.4, 0.2)
		mat.no_depth_test = true
		_debug_mesh.material_override = mat
		add_child(_debug_mesh)
	var im := ImmediateMesh.new()
	if pts.size() >= 2:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in pts:
			im.surface_add_vertex(p.position + Vector3.UP * 0.2)
		if loop:
			im.surface_add_vertex(pts[0].position + Vector3.UP * 0.2)
		im.surface_end()
	_debug_mesh.mesh = im
