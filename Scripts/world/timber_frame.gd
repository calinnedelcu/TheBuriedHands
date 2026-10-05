@tool
class_name TimberFrame
extends Node3D
## A pit-prop frame holding up a dug tunnel: two posts against the walls, a
## cap beam under the roof and knee braces, sized to the tunnel (local x
## across it, y up from the floor). Optionally a small oil lamp hangs from it.

const TIMBER := preload("res://assets/materials/level/timber.tres")
const FLAME_MESH := preload("res://scenes/items/flame_teardrop.obj")
const FLAME_SHADER := preload("res://scenes/items/oil_flame.gdshader")
const FLICKER := preload("res://Scripts/world/flicker_light.gd")

@export var width := 4.0:
	set(v):
		width = v
		_build()
@export var height := 3.4:
	set(v):
		height = v
		_build()
@export var with_lamp := false:
	set(v):
		with_lamp = v
		_build()

func _ready() -> void:
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"built"):
			remove_child(c)
			c.queue_free()
	var post := 0.24
	var x := width * 0.5 - post * 0.5 - 0.04
	var cap := 0.26
	var top := height - cap * 0.5 - 0.02
	var body := StaticBody3D.new()
	body.collision_mask = 0
	body.set_meta(&"built", true)
	add_child(body)
	for s in [-1.0, 1.0]:
		_beam(Vector3(post, top - cap * 0.5, post), Vector3(s * x, (top - cap * 0.5) * 0.5, 0.0), Basis(), body)
		# Knee brace from post to cap.
		var brace_len := 0.9
		var b := Basis(Vector3.BACK, s * deg_to_rad(45.0))
		_beam(Vector3(0.12, brace_len, 0.12), Vector3(s * (x - 0.35), top - cap * 0.5 - 0.32, 0.0), b, null)
	_beam(Vector3(width - 0.06, cap, cap + 0.04), Vector3(0.0, top, 0.0), Basis(), body)
	if with_lamp:
		_lamp(Vector3(0.0, top - cap * 0.5, 0.18))

func _beam(size: Vector3, pos: Vector3, basis: Basis, body: StaticBody3D) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = TIMBER
	mi.transform = Transform3D(basis, pos)
	mi.set_meta(&"built", true)
	add_child(mi)
	if body != null:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.transform = Transform3D(basis, pos)
		body.add_child(cs)

func _lamp(at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.set_meta(&"built", true)
	add_child(holder)
	var cord := MeshInstance3D.new()
	var c := BoxMesh.new()
	c.size = Vector3(0.015, 0.3, 0.015)
	cord.mesh = c
	cord.position = Vector3(0.0, -0.15, 0.0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.08, 0.05)
	cord.material_override = dark
	holder.add_child(cord)
	var dish := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.06
	cyl.height = 0.05
	dish.mesh = cyl
	dish.position = Vector3(0.0, -0.32, 0.0)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.4, 0.24, 0.14)
	dish.material_override = clay
	holder.add_child(dish)
	var flame := MeshInstance3D.new()
	flame.mesh = FLAME_MESH
	var fm := ShaderMaterial.new()
	fm.shader = FLAME_SHADER
	fm.set_shader_parameter(&"outer_color", Color(1, 0.3, 0.05, 0.75))
	fm.set_shader_parameter(&"core_color", Color(1, 0.84, 0.32, 0.95))
	fm.set_shader_parameter(&"tip_color", Color(1, 0.55, 0.1, 0.55))
	fm.set_shader_parameter(&"emission_strength", 3.6)
	fm.set_shader_parameter(&"alpha_scale", 0.8)
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0.06, -0.3, 0.0)
	flame.scale = Vector3.ONE * 0.8
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.set_script(FLICKER)
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.1
	light.omni_range = 7.0
	light.omni_attenuation = 1.4
	light.position = Vector3(0.06, -0.15, 0.0)
	holder.add_child(light)
