@tool
class_name DaylightExit
extends Node3D
## The way out: the morning beyond the drain's mouth. A grassy shelf with
## rocks, the valley and hills painted on a sky box around it, a low sun whose
## light reaches down the tunnel (and a faint glow of it back where the drain
## comes out), and the forest growing louder as the craftsman walks toward it. It stays dark and silent until the drain has
## been opened, so it costs nothing before then.
##
## Local frame: the origin is the tunnel floor at the mouth's centre and +Z
## points out of the mountain. The node is not rotated.

## Render layer of everything outside: only the sun and the sky's fill light
## it, and those two light nothing in the tomb.
const OUTSIDE_LAYER := 1 << 10
const GRASS_SHADER := preload("res://assets/shaders/grass_blade.gdshader")
const SURFACE_SHADER := preload("res://assets/shaders/outside_surface.gdshader")
const GROUND_ALBEDO := preload("res://assets/textures/surfaces/concrete047a/albedo.jpg")
const GROUND_NORMAL := preload("res://assets/textures/surfaces/concrete047a/normal.jpg")
const ROCK_ALBEDO := preload("res://assets/textures/surfaces/rock030/albedo.jpg")
const ROCK_NORMAL := preload("res://assets/textures/surfaces/rock030/normal.jpg")

## Toward the sun: low, ahead and a little to the side, so a slanted shaft
## falls through the mouth onto the last stretch of the tunnel.
@export var sun_direction := Vector3(0.1685, 0.2419, 0.9556):
	set(value):
		sun_direction = value.normalized()
		if is_node_ready():
			_aim()
## Height of the mouth's centre above the floor (where the shaft is aimed).
@export var mouth_height := 3.0
## Tufts of grass on the shelf outside (each 8–22 blades).
@export var grass_tufts := 1300
@export var random_seed := 7
## The quest step from which the outside is shown (the drain being opened).
@export var shown_from_step: StringName = &"crawl_out"
@export var outside_volume_db := 12.0

@onready var _sun: DirectionalLight3D = $Sun
@onready var _fill: DirectionalLight3D = $SkyFill
@onready var _shaft: SpotLight3D = $Shaft
@onready var _dust: GPUParticles3D = $Dust
@onready var _sound: AudioStreamPlayer3D = $Outside

var shown := false
var _noise := FastNoiseLite.new()
var _built: Array[Node] = []
var _sound_tween: Tween

func _ready() -> void:
	add_to_group(&"daylight_exit")
	_noise.seed = random_seed
	_noise.frequency = 0.09
	_noise.fractal_octaves = 3
	_build()
	_aim()
	if Engine.is_editor_hint():
		return
	_show(false)
	Quest.step_changed.connect(func(_step: StringName): _check())
	_check.call_deferred()

## A point far off in the sun's direction, as seen from `from`.
func sun_point(from: Vector3) -> Vector3:
	return from + sun_direction * 200.0

## Where the walk out ends: just inside the mouth.
func threshold(inside := 1.6) -> Vector3:
	return to_global(Vector3(0.0, 0.0, -inside))

## Fades the forest out here while the ending's own bed takes over.
func hand_over_sound(seconds: float) -> void:
	_fade_sound(-60.0, seconds, true)

## Ground height of the outside, in local space.
func height(x: float, z: float) -> float:
	var out := maxf(z - 4.5, 0.0)
	var fall := -pow(out, 1.45) * 0.2
	var bank := pow(maxf(absf(x) - 2.4, 0.0), 1.3) * 0.5 * clampf(1.0 - out / 14.0, 0.25, 1.0)
	var bumps := _noise.get_noise_2d(x, z) * 0.45 * smoothstep(0.5, 4.0, z + absf(x) * 0.5)
	return fall + bank + bumps - 0.04

func _check() -> void:
	if not shown and Quest.has_reached(shown_from_step):
		_show(true)

func _show(on: bool) -> void:
	shown = on
	visible = on
	_dust.emitting = on
	if on:
		_sound.volume_db = -50.0
		_sound.play()
		_fade_sound(outside_volume_db, 8.0)
	else:
		_sound.stop()

func _fade_sound(db: float, seconds: float, stop_after := false) -> void:
	if _sound_tween != null:
		_sound_tween.kill()
	_sound_tween = create_tween()
	_sound_tween.tween_property(_sound, "volume_db", db, seconds)
	if stop_after:
		_sound_tween.tween_callback(_sound.stop)

func _aim() -> void:
	_sun.basis = Basis.looking_at(-sun_direction)
	_fill.basis = Basis.looking_at(Vector3(0.0, -0.55, 1.0))
	var mouth := Vector3(0.0, mouth_height, 0.0)
	_shaft.position = mouth + sun_direction * 36.0
	_shaft.basis = Basis.looking_at(-sun_direction)
	var sky := ($Sky as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	if sky != null:
		sky.set_shader_parameter(&"sun_dir", sun_direction)

# --- Generated scenery ---------------------------------------------------------------

func _build() -> void:
	for n in _built:
		n.queue_free()
	_built.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	_add(_ground())
	_add(_grass(rng))
	_add(_roots(rng))
	var stone := _surface(Color(0.46, 0.42, 0.37), ROCK_ALBEDO, ROCK_NORMAL, 0.45, 0.32)
	for rock in $Rocks.find_children("*", "MeshInstance3D", true, false):
		var mi := rock as MeshInstance3D
		mi.layers = OUTSIDE_LAYER
		mi.material_override = stone
	($Sky as MeshInstance3D).layers = OUTSIDE_LAYER

func _add(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_FRONT)
	_built.append(node)

func _surface(color: Color, albedo: Texture2D, normal: Texture2D, grass: float, scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter(&"base_color", color)
	m.set_shader_parameter(&"grass_amount", grass)
	m.set_shader_parameter(&"detail_albedo", albedo)
	m.set_shader_parameter(&"detail_normal", normal)
	m.set_shader_parameter(&"tex_scale", scale)
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.noise = _noise
	m.set_shader_parameter(&"noise", tex)
	return m

func _ground() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.5
	var nx := 96
	var nz := 76
	for iz in nz + 1:
		for ix in nx + 1:
			var x := -24.0 + ix * step
			var z := -1.5 + iz * step
			st.add_vertex(Vector3(x, height(x, z), z))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	mi.layers = OUTSIDE_LAYER
	mi.material_override = _surface(Color(0.26, 0.21, 0.15), GROUND_ALBEDO, GROUND_NORMAL, 0.9, 0.3)
	return mi

## One blade, 1 m tall: a tapered strip bending forward, UV.y 0 at the root.
func _blade_mesh(width: float, bend: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := [0.0, 0.3, 0.6, 0.85]
	for i in rows.size():
		var y: float = rows[i]
		var half := width * 0.5 * pow(1.0 - y, 0.7)
		var z := bend * y * y
		st.set_uv(Vector2(0.0, y))
		st.add_vertex(Vector3(-half, y, z))
		st.set_uv(Vector2(1.0, y))
		st.add_vertex(Vector3(half, y, z))
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(Vector3(0.0, 1.0, bend))
	for i in rows.size() - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	var top := (rows.size() - 1) * 2
	st.add_index(top)
	st.add_index(top + 1)
	st.add_index(top + 2)
	st.generate_normals()
	return st.commit()

func _blades(name: String, mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color], material: ShaderMaterial) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.layers = OUTSIDE_LAYER
	mmi.material_override = material
	return mmi

func _grass(rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for t in grass_tufts:
		var cx := rng.randf_range(-12.0, 12.0)
		var cz := rng.randf_range(0.5, 15.0) if rng.randf() < 0.6 else rng.randf_range(0.6, 6.0)
		# Sparse on the threshold and down the steep fall, thick on the banks.
		var keep := smoothstep(0.5, 2.4, cz) * (1.0 - smoothstep(8.0, 15.0, cz) * 0.6)
		if rng.randf() > keep:
			continue
		var tall := rng.randf_range(0.55, 1.1) * (1.3 if absf(cx) > 2.6 else 1.0)
		var dry := rng.randf()
		for k in rng.randi_range(8, 22):
			var x := cx + rng.randfn(0.0, 0.22)
			var z := cz + rng.randfn(0.0, 0.22)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
			b = b * Basis.from_scale(Vector3(rng.randf_range(0.7, 1.5), tall * rng.randf_range(0.6, 1.25), 1.0))
			xforms.append(Transform3D(b, Vector3(x, height(x, z) - 0.05, z)))
			var d := clampf(dry + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
			colors.append(Color(0.8, 0.8, 0.8).lerp(Color(1.0, 0.88, 0.52), d * d))
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	return _blades("Grass", _blade_mesh(0.08, 0.22), xforms, colors, m)

## Roots hanging through the last of the ceiling, dark against the sky.
func _roots(rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var top := mouth_height * 2.0
	for i in 40:
		var x := rng.randf_range(-1.45, 1.45)
		var z := rng.randf_range(-1.4, 0.3)
		var length := rng.randf_range(0.4, 2.3) * (1.0 - absf(x) * 0.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI + rng.randf_range(-0.12, 0.12))
		b = b * Basis.from_scale(Vector3(1.0, length, 1.0))
		xforms.append(Transform3D(b, Vector3(x, top + 0.05, z)))
		colors.append(Color(0.8, 0.8, 0.8) * rng.randf_range(0.8, 1.2))
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	m.set_shader_parameter(&"root_color", Color(0.12, 0.09, 0.06))
	m.set_shader_parameter(&"tip_color", Color(0.26, 0.2, 0.13))
	m.set_shader_parameter(&"translucency", Color(0.12, 0.08, 0.04))
	m.set_shader_parameter(&"wind_strength", 0.06)
	return _blades("Roots", _blade_mesh(0.025, 0.3), xforms, colors, m)
