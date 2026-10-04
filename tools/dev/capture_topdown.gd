extends SceneTree
## Dev tool: renders orthographic top-down "floor plan" slices of the level.
## Usage: godot --path . --resolution 2000x2000 -s res://tools/dev/capture_topdown.gd -- --out=/abs/dir
## Each slice puts the camera at a given height so geometry above it (ceilings,
## upper floors) is clipped away by the near plane.

const LEVEL := "res://scenes/tomb_layout.tscn"
# name, camera height, near clip
const SLICES := [
	["plan_ground", 4.5, 0.05],
	["plan_upper", 15.0, 0.05],
	["plan_basement", -2.5, 0.05],
]
const CENTER := Vector3(-20.0, 0.0, 65.0)
const ORTHO_SIZE := 270.0

var _out_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	if _out_dir == "":
		_out_dir = OS.get_user_data_dir().path_join("topdown")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()

func _run() -> void:
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	get_root().add_child(level)
	current_scene = level
	for i in 20:
		await process_frame
	# Flat, readable lighting: no fog, bright ambient, one sun from above.
	var env_node := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null:
		var env := env_node.environment.duplicate() as Environment
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.55, 0.55)
		env.ambient_light_energy = 1.0
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = 1.0
		env_node.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 30, 0)
	sun.light_energy = 1.2
	level.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_SIZE
	cam.far = 400.0
	level.add_child(cam)
	cam.make_current()
	# Hide HUD layers so the plan is clean.
	for node in level.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	for slice in SLICES:
		cam.near = slice[2]
		cam.global_position = Vector3(CENTER.x, slice[1], CENTER.z)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		var path := _out_dir.path_join(String(slice[0]) + ".png")
		img.save_png(path)
		print("[topdown] saved ", path, " ortho_size=", ORTHO_SIZE, " center=", CENTER)
	quit()
