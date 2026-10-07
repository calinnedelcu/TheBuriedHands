extends Node
## Dev capture: two windowed copies of the game in a co-op session, standing
## in the workshop facing each other, each with a lamp, to see the partner as
## the other player sees him (model, lamp in hand, name, a ping). Run both:
## godot --path . --resolution 800x450 --fixed-fps 30 -s res://tools/dev/run.gd -- --runner=res://tools/dev/coop_shots_runner.gd --role=host --out=/abs/dir
## godot --path . --resolution 800x450 --fixed-fps 30 -s res://tools/dev/run.gd -- --runner=res://tools/dev/coop_shots_runner.gd --role=client --out=/abs/dir
## Add --scene=causeway to both for the brake and the pin over the balance pit.

const WS := "Rooms/01_TerracottaWorkshop/"

var role := "host"
var scene := "workshop"
var out := "/tmp"
var me: Player

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.substr(7)
		elif arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--scene="):
			scene = arg.substr(8)
	_run.call_deferred()

func _run() -> void:
	if role == "host":
		Net.host()
		while not Net.has_partner():
			await _wait(0.2)
		Net.begin()
	else:
		await _wait(1.5)
		Net.join("127.0.0.1")
	await Game.level_ready
	me = Net.local_body()
	if scene == "causeway":
		await _causeway()
		return
	var level := Game.level
	# The apprentice stays at his bench; the master stands a few steps in
	# front of him. Both take a lamp.
	var apprentice := Net.body(Net.APPRENTICE_BODY)
	var bench := apprentice.global_position
	var front := -apprentice.global_basis.z
	var stand := WS + ("LampStand_E/Body/Usable" if role == "host" else "LampStand_W/Body/Usable")
	Net.use(level.get_node(stand) as Usable, me, &"tap")
	if role == "host":
		me.global_position = _floor(bench + front * 4.5)
	# Let the chapter card and the opening line go by.
	await _wait(9.0)
	Dialogue.stop()
	var other := Net.partner_body()
	me.look_at_point(other.global_position + Vector3.UP * 1.7, 0.3)
	await _wait(1.0)
	await _shot("%s_partner" % role)
	# The apprentice crouches; the master holds his lamp up.
	if role == "client":
		me._set_stance(Player.Stance.CROUCH, true)
	else:
		me.inventory.lamp().is_raised = true
		Net.inventory_action(me, &"lamp_raise", [true])
	await _wait(2.5)
	me.look_at_point(other.global_position + Vector3.UP * 1.2, 0.3)
	await _wait(0.8)
	await _shot("%s_partner_pose" % role)
	# The apprentice points out a figure behind the master.
	var mark := bench + front * 9.0 + Vector3.UP * 1.5
	if role == "client":
		Net.ping(mark, null)
	await _wait(1.5)
	me.look_at_point(mark, 0.3)
	await _wait(0.8)
	await _shot("%s_ping" % role)
	await _wait(1.0)
	if role == "host":
		# Wait for the apprentice to finish before closing the session.
		var t := 0.0
		while Net.has_partner() and t < 60.0:
			await _wait(0.5)
			t += 0.5
	Net.leave()
	get_tree().quit()

## The master bears on the brake by the counterweight while the apprentice,
## across the pit, waits by the pin.
func _causeway() -> void:
	var level := Game.level
	var causeway := level.get_node("Mechanism/Causeway") as Causeway
	var brake := level.get_node("Mechanism/CoopBrake") as Node3D
	var pin := level.get_node("Mechanism/CoopPin") as Node3D
	if role == "host":
		Game.set_flag(&"guards_hostile", false)
		Quest.start_at(&"find_drain")
		Net.mirror(causeway, &"net_open")
		causeway.net_open()
		me.global_position = brake.global_position + Vector3(0, 0, -1.4)
	else:
		me.global_position = pin.global_position + Vector3(-0.8, 0, 0.9)
	await _wait(3.0)
	Dialogue.stop()
	await _wait(5.0)
	if role == "host":
		Net.use(level.get_node("Mechanism/CoopBrake/Body/Usable") as Usable, me, &"use")
	await _wait(1.0)
	if role == "host":
		me.look_at_point(brake.global_position + Vector3.UP * 1.2, 0.3)
	else:
		me.look_at_point(brake.global_position + Vector3.UP * 1.0, 0.3)
	await _wait(6.0)
	await _shot("%s_causeway" % role)
	if role == "client":
		me.look_at_point(pin.global_position + Vector3.UP * 0.8, 0.3)
		await _wait(0.8)
		await _shot("client_pin")
		Net.use(level.get_node("Mechanism/CoopPin/Body/Usable") as Usable, me, &"use")
		await _wait(1.5)
		me.look_at_point(causeway.global_position + Vector3(0, 7.0, -4.0), 0.3)
		await _wait(0.8)
		await _shot("client_pinned")
	else:
		await _wait(4.0)
		me.look_at_point(causeway.global_position + Vector3(0, 7.0, 4.0), 0.3)
		await _wait(0.8)
		await _shot("host_after_pin")
	await _wait(1.0)
	if role == "host":
		var t := 0.0
		while Net.has_partner() and t < 60.0:
			await _wait(0.5)
			t += 0.5
	Net.leave()
	get_tree().quit()

func _floor(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, 1)
	var hit := me.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("[%s] shot %s" % [role, shot_name])

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
