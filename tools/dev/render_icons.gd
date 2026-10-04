extends SceneTree
## Renders inventory icons (transparent 512px PNGs) from item visual scenes,
## lit warmly to sit next to the painted icons.
## Usage: godot --path . -s res://tools/dev/render_icons.gd

const JOBS := [
	["res://scenes/items/visuals/jar.tscn", "res://assets/ui/icons/icon_jar.png", 25.0],
	["res://scenes/items/visuals/jar_full.tscn", "res://assets/ui/icons/icon_jar_full.png", 25.0],
	["res://scenes/items/visuals/register.tscn", "res://assets/ui/icons/icon_register.png", 35.0],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	get_root().add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.38, 0.32)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	# A sky only for reflections, so metal (bronze, mercury) doesn't render black.
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.5, 0.45)
	sky_mat.sky_horizon_color = Color(0.9, 0.8, 0.65)
	sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.1)
	sky.sky_material = sky_mat
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_color = Color(1.0, 0.82, 0.6)
	key.light_energy = 1.6
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	for job in JOBS:
		var model: Node3D = (load(job[0]) as PackedScene).instantiate()
		model.rotation_degrees.y = job[2]
		vp.add_child(model)
		await process_frame
		var box := _aabb(model)
		cam.size = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.25
		var dir := Vector3(0.0, 0.55, 1.0).normalized()
		cam.global_position = box.get_center() + dir * 10.0
		cam.look_at(box.get_center())
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(job[1]))
		print("icon ", job[1])
		model.free()
	quit()

func _aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		result = b if first else result.merge(b)
		first = false
	return result
