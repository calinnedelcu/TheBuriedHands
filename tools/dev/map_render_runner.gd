extends Node
## Dev runner: top-down orthographic cut-away maps of the level with the
## gameplay nodes drawn on top (spawn, guards and their routes, NPCs, pickups,
## triggers, traps, lamps, ladders). For checking placements at a glance.
## godot --path . --resolution 1400x1400 -s res://tools/dev/run.gd -- --runner=res://tools/dev/map_render_runner.gd --out=/abs/dir [--only=workshop,archives] [--nav] [--region="name;cx,cy,cz;size;depth"]

# name, centre (x, cut height, z), ortho size, depth below the cut
const REGIONS := [
	["workshop", Vector3(-55.0, 4.6, -18.0), 56.0, 9.0],
	["archives", Vector3(14.0, 4.6, -28.0), 64.0, 9.0],
	["liang", Vector3(36.0, 4.6, -36.0), 34.0, 9.0],
	["corridor", Vector3(-12.0, 4.6, 14.0), 70.0, 9.0],
	["tunnels", Vector3(30.0, -1.5, -40.0), 50.0, 8.0],
	["mechanism", Vector3(0.0, 14.0, 46.0), 40.0, 12.0],
	["mercury", Vector3(-62.0, 9.0, 62.0), 60.0, 12.0],
	["treasury", Vector3(0.0, 13.0, 100.0), 44.0, 9.0],
	["drain", Vector3(-6.0, 12.0, 150.0), 50.0, 8.0],
	["overview", Vector3(-10.0, 30.0, 50.0), 230.0, 50.0],
]

var _overlay: Control
var _cam: Camera3D
var _nav := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := ""
	var only: PackedStringArray = []
	var custom := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",")
		elif arg == "--nav":
			_nav = true
		elif arg.begins_with("--region="):
			# name;cx,cy,cz;size;depth — a custom close-up instead of the presets
			var parts := arg.substr(9).split(";")
			var c := parts[1].split(",")
			custom.append([parts[0], Vector3(float(c[0]), float(c[1]), float(c[2])), float(parts[2]), float(parts[3])])
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().change_scene_to_file("res://scenes/level/mausoleum.tscn")
	await Game.level_ready
	var level := Game.level as Node3D
	var player := get_tree().get_first_node_in_group(&"player") as Player
	Dialogue.stop()
	player.lock_controls(&"map", true)
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.set(&"visible", false)
	for lamp in get_tree().get_nodes_in_group(&"wall_lamps"):
		(lamp as Node3D).visible = true
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	var env := get_viewport().world_3d.environment if get_viewport().world_3d != null else null
	if env != null:
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	level.add_child(_cam)
	_cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)
	for region in (custom if not custom.is_empty() else REGIONS):
		if not only.is_empty() and not only.has(region[0]):
			continue
		var c: Vector3 = region[1]
		_cam.size = region[2]
		_cam.near = 0.05
		_cam.far = region[3]
		_cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)), c)
		for i in 4:
			await get_tree().process_frame
		_draw_markers(level, c.y, c.y - float(region[3]))
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join(String(region[0]) + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("map ", path)
	get_tree().quit()

# --- Markers -----------------------------------------------------------------------------

func _draw_markers(level: Node3D, top: float, bottom: float) -> void:
	for c in _overlay.get_children():
		c.free()
	if _nav:
		_draw_navmesh(level, top, bottom)
	var in_slice := func(p: Vector3) -> bool: return p.y <= top + 1.0 and p.y >= bottom - 1.0
	for n in level.find_children("*", "", true, false):
		if not (n is Node3D):
			continue
		var node := n as Node3D
		var p := node.global_position
		if not in_slice.call(p):
			continue
		if node is Player:
			_dot(p, Color.LIME, 9, "PLAYER")
		elif node is Guard:
			_dot(p, Color.RED, 8, String(node.name))
			var route := node.get_node_or_null((node as Guard).route_path) as Node3D
			if route != null:
				_route(route, Color(1, 0.3, 0.3, 0.8))
		elif node is Npc:
			_dot(p, Color.DODGER_BLUE, 8, String(node.name))
		elif node is Pickup:
			_dot(p, Color.YELLOW, 6, String((node as Pickup).item_id))
		elif node is StoryTrigger or node is ExitLight:
			_area(node as Area3D, Color(0.8, 0.4, 1.0, 0.9), String(node.name))
		elif node is VaporZone or node is MercuryPool:
			_area(node as Area3D, Color(0.5, 0.9, 1.0, 0.8), String(node.name))
		elif node is PressurePlate:
			_dot(p, Color.WHITE, 5, "plate")
		elif node is WallCrossbow:
			_dot(p, Color.ORANGE_RED, 5, "xbow")
			var dir := -node.global_transform.basis.z
			_line(p, p + dir * 4.0, Color.ORANGE_RED)
		elif node is CollapsingTile:
			_dot(p, Color.SANDY_BROWN, 5, "tile")
		elif node is KillZone:
			_dot(p, Color.DARK_RED, 5, "spikes")
		elif node is ClimbLadder:
			_dot(p, Color.CYAN, 6, "ladder")
		elif node is WallLamp:
			_dot(p, Color(1, 0.6, 0.2), 3, "")
		elif node is LampStand:
			_dot(p, Color.GOLD, 6, "lampstand")
		elif node is BreakableStone or node is Counterweight or node is ClayStatue or node is DrainCrawl:
			_dot(p, Color.MAGENTA, 7, String(node.name))
		elif node is Marker3D and node.get_parent() != null and String(node.get_parent().name) == "SealingMarks":
			_dot(p, Color.PINK, 5, String(node.name))

func _screen(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)

func _dot(p: Vector3, color: Color, size: float, text: String) -> void:
	var s := _screen(p)
	var r := ColorRect.new()
	r.color = color
	r.size = Vector2(size, size)
	r.position = s - r.size * 0.5
	_overlay.add_child(r)
	if text != "":
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override(&"font_size", 17)
		l.add_theme_color_override(&"font_color", color)
		l.add_theme_color_override(&"font_outline_color", Color.BLACK)
		l.add_theme_constant_override(&"outline_size", 4)
		l.position = s + Vector2(6, -8)
		_overlay.add_child(l)

func _line(a: Vector3, b: Vector3, color: Color) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.points = PackedVector2Array([_screen(a), _screen(b)])
	_overlay.add_child(line)

func _route(route: Node3D, color: Color) -> void:
	var pts := PackedVector2Array()
	for c in route.get_children():
		if c is Node3D:
			pts.append(_screen((c as Node3D).global_position))
	if pts.size() < 2:
		return
	pts.append(pts[0])
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = color
	line.points = pts
	_overlay.add_child(line)

func _area(area: Area3D, color: Color, text: String) -> void:
	for c in area.get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var aabb := cs.shape.get_debug_mesh().get_aabb()
		var corners := [aabb.position, aabb.position + Vector3(aabb.size.x, 0, 0), aabb.position + Vector3(aabb.size.x, 0, aabb.size.z), aabb.position + Vector3(0, 0, aabb.size.z)]
		var pts := PackedVector2Array()
		for k in corners:
			pts.append(_screen(cs.global_transform * (k as Vector3)))
		pts.append(pts[0])
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = color
		line.points = pts
		_overlay.add_child(line)
	if text != "":
		_dot(area.global_position, color, 4, text)

## Outlines every navmesh polygon in the slice (green), to spot gaps and
## islands (e.g. table tops) the walkers could snap to.
func _draw_navmesh(level: Node3D, top: float, bottom: float) -> void:
	for r in level.find_children("*", "NavigationRegion3D", true, false):
		var nm := (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var verts := nm.get_vertices()
		var xf := (r as Node3D).global_transform
		for i in nm.get_polygon_count():
			var poly := nm.get_polygon(i)
			var pts := PackedVector2Array()
			var y := 0.0
			for vi in poly:
				var w := xf * verts[vi]
				y += w.y
				pts.append(_screen(w))
			y /= maxf(poly.size(), 1)
			if y > top + 1.0 or y < bottom - 1.0:
				continue
			pts.append(pts[0])
			var line := Line2D.new()
			line.width = 1.0
			line.default_color = Color(0.2, 1.0, 0.3, 0.55)
			line.points = pts
			_overlay.add_child(line)
