extends SceneTree
## Dev tool: loads the level and saves a screenshot from a list of camera poses.
## Usage (needs a real renderer, not --headless):
##   godot --path . --resolution 1600x900 -s res://tools/dev/capture_tour.gd -- --out=/abs/dir [--only=name1,name2]
##
## Each pose spawns a free camera with a warm "lamp" light attached so the shot
## looks roughly like what the player sees while carrying the oil lamp.

const LEVEL := "res://scenes/tomb_layout.tscn"

# name, position, yaw (deg), pitch (deg)
const POSES_EXTRA := [
	["30_statue", Vector3(-63.0, 3.0, -2.5), 50.0, -18.0],
	["31_statue_close", Vector3(-65.5, 2.6, -4.5), 45.0, -25.0],
	["32_bowl_station", Vector3(-28.0, 3.0, -31.0), 135.0, -20.0],
	["33_liang", Vector3(34.0, 2.6, -29.0), -140.0, -12.0],
	["34_liang_shaft", Vector3(44.0, 3.0, -42.0), -50.0, -25.0],
	["35_mech_from_platform", Vector3(5.0, 15.5, 48.0), 160.0, -30.0],
	["36_mech_room", Vector3(0.0, 10.4, 42.0), 180.0, -10.0],
	["37_balance", Vector3(-3.8, 9.5, 50.0), 180.0, -35.0],
	["38_mercury_entry", Vector3(-47.0, 10.0, 70.0), 90.0, -20.0],
	["39_mercury_hall", Vector3(-55.0, 6.0, 58.0), 60.0, -25.0],
	["40_treasury", Vector3(0.6, 10.5, 84.0), 180.0, -8.0],
	["41_drain", Vector3(-3.0, 9.6, 128.0), 180.0, -5.0],
	["42_corridor_traps", Vector3(-30.0, 3.0, 12.0), -90.0, -15.0],
	["43_archives_door", Vector3(5.0, 3.0, 4.0), 0.0, -5.0],
]

const POSES := [
	["00_spawn", Vector3(-75.74, 4.38, -24.2), -90.6, -8.0],
	["01_workshop_center", Vector3(-60.0, 2.6, -20.0), -90.0, -6.0],
	["02_workshop_east", Vector3(-60.0, 2.6, -20.0), 90.0, -6.0],
	["03_apprentice", Vector3(-72.0, 2.6, -12.0), -30.0, -10.0],
	["04_tool_tables", Vector3(-45.0, 2.8, -27.0), 150.0, -20.0],
	["05_guard_talk_spot", Vector3(-57.8, 2.6, -10.0), 0.0, -5.0],
	["06_admin_area", Vector3(5.0, 2.6, -10.0), 180.0, -5.0],
	["07_admin_area_b", Vector3(14.0, 2.6, -40.0), 0.0, -5.0],
	["08_liang", Vector3(33.0, 1.6, -30.0), -130.0, -10.0],
	["09_crossbow_corridor", Vector3(-40.0, 2.6, 16.0), -90.0, -5.0],
	["10_trap_tiles", Vector3(-22.0, 3.5, 16.0), -90.0, -18.0],
	["11_tunnel_below", Vector3(48.0, -5.0, -40.0), 180.0, -5.0],
	["12_mechanism_room", Vector3(0.0, 10.5, 40.0), 0.0, -8.0],
	["13_mercury_room", Vector3(-60.0, 3.0, 60.0), 90.0, -8.0],
	["14_mercury_room_b", Vector3(-85.0, 3.0, 62.0), -90.0, -8.0],
	["15_balance", Vector3(-3.8, 4.5, 50.0), 0.0, -15.0],
	["16_treasure_entry", Vector3(0.5, 11.0, 90.0), 0.0, -5.0],
	["17_treasure_room", Vector3(-2.8, 12.0, 100.0), 0.0, -5.0],
	["18_squeeze_tunnel", Vector3(-12.0, 9.5, 143.0), -90.0, -5.0],
	["19_exit", Vector3(-2.0, 11.5, 170.0), 0.0, 0.0],
	["20_overview", Vector3(-10.0, 95.0, 80.0), 30.0, -60.0],
]

var _out_dir := ""
var _only: PackedStringArray = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",", false)
	if _out_dir == "":
		_out_dir = OS.get_user_data_dir().path_join("tour")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()

func _run() -> void:
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	get_root().add_child(level)
	current_scene = level
	# Hide gameplay UI noise from the shots that do not need it.
	var cam := Camera3D.new()
	cam.name = "TourCamera"
	cam.fov = 75.0
	level.add_child(cam)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.6, 0.26)
	lamp.light_energy = 3.0
	lamp.omni_range = 14.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(-0.3, -0.25, -0.4)
	cam.add_child(lamp)
	for i in 30:
		await process_frame
	cam.make_current()
	for pose in POSES + POSES_EXTRA:
		var pose_name: String = pose[0]
		if not _only.is_empty() and not _only.has(pose_name):
			continue
		cam.global_position = pose[1]
		cam.rotation = Vector3(deg_to_rad(pose[3]), deg_to_rad(pose[2]), 0.0)
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		var path := _out_dir.path_join(pose_name + ".png")
		img.save_png(path)
		print("[tour] saved ", path)
	quit()
