class_name ApprenticeTaken
extends Area3D
## Act I's last turn, played alone: on his way across the workshop to find
## Liang, the craftsman sees Overseer Wei come in with two of his men and a
## list, pull the apprentice out of the cold kiln and take him away to the
## army pits. He can only crouch and watch. If he leaves the workshop another
## way, he hears it from Liang instead (ApprenticeNpc). Together, the
## apprentice is the other player: nothing happens here.
##
## The area is a band across the workshop he must cross going east.

@export var wei_path: NodePath
@export var men_paths: Array[NodePath] = []
@export var apprentice_path: NodePath
## Marker3Ds where Wei and his two men stand at the kiln, in that order.
@export var stand_paths: Array[NodePath] = []
## Where they bring the apprentice once he's pulled out: before Wei.
@export var pull_spot_path: NodePath
## The kiln's mouth, where he hides.
@export var kiln_path: NodePath
## The men come round to the kiln this way (Wei's spot is in a narrow place
## between the cart and the benches, not to be passed).
@export var approach_path: NodePath
## A Node3D whose Marker3D children are their way in from the annex, the
## first out of sight; they leave the same way, back to it.
@export var way_path: NodePath
## What the craftsman watches: Wei and the boy, in the open.
@export var watch_path: NodePath

var fired := false
var _wei: Guard
var _men: Array[Guard] = []

func _ready() -> void:
	add_to_group(&"persistent")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	_wei = get_node_or_null(wei_path) as Guard
	for p in men_paths:
		var g := get_node_or_null(p) as Guard
		if g != null:
			_men.append(g)
	_away.call_deferred()

func _actors() -> Array[Guard]:
	var out: Array[Guard] = []
	if _wei != null:
		out.append(_wei)
	out.append_array(_men)
	return out

## Wei and his men are nowhere until their scene: not seen, not saved, not
## patrolling, not in the way.
func _away() -> void:
	for g in _actors():
		g.remove_from_group(&"persistent")
		g.set_scripted(true)
		_show(g, false)

func _show(g: Guard, on: bool) -> void:
	g.visible = on
	g.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	g.collision_layer = 4 if on else 0

func _on_body_entered(body: Node3D) -> void:
	if fired or Net.active or not (body is Player) or not Quest.is_at(&"find_liang"):
		return
	fired = true
	_run(body as Player)

func _points(path: NodePath) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var holder := get_node_or_null(path)
	if holder != null:
		for c in holder.get_children():
			if c is Node3D:
				out.append((c as Node3D).global_position)
	return out

func _spot(path: NodePath) -> Vector3:
	var n := get_node_or_null(path) as Node3D
	return n.global_position if n != null else global_position

func _run(player: Player) -> void:
	var apprentice := get_node_or_null(apprentice_path) as Node3D
	var way := _points(way_path)
	if _wei == null or _men.size() < 2 or apprentice == null or way.size() < 2 or stand_paths.size() < 3:
		return
	player.lock_controls(&"taken", false)
	player.velocity = Vector3.ZERO
	player._set_stance(Player.Stance.CROUCH, true)
	# Down, his lamp held low behind him.
	var hands_shown := player.viewmodel.visible
	player.viewmodel.visible = false
	# He is in the kiln by now, whatever the craftsman was looking at.
	apprentice.call(&"_snap_to_hide_spot")
	apprentice.set(&"_talking", true)
	Dialogue.line_started.connect(_on_line)
	await Dialogue.play(&"taken_warning")
	# They come in from the annex: Wei, then his men.
	for g in _actors():
		g.global_position = way[0]
		_show(g, true)
		g.set_scripted(true)
	player.look_at_point(way[1] + Vector3.UP * 2.2, 1.4)
	_walk(_wei, way.slice(1) + [_spot(stand_paths[0])])
	await get_tree().create_timer(0.8, false).timeout
	var approach := _spot(approach_path)
	_walk(_men[0], way.slice(1) + [approach, _spot(stand_paths[1])])
	await get_tree().create_timer(0.6, false).timeout
	await _walk(_men[1], way.slice(1) + [approach, _spot(stand_paths[2])])
	var kiln := _spot(kiln_path)
	for g in _actors():
		g.scripted_face(kiln)
	# His eyes fix on them: the view narrows.
	player.look_at_point(_spot(watch_path), 1.4, 42.0)
	await Dialogue.play(&"taken_list")
	# Out of the kiln, by the arm, and before Wei.
	var pull := _spot(pull_spot_path)
	apprentice.call(&"_turn_toward", pull)
	apprentice.call(&"play", &"walk")
	var t := create_tween()
	t.tween_property(apprentice, "global_position", pull, 2.2).set_trans(Tween.TRANS_SINE)
	_men[0].scripted_walk_to(pull + (kiln - pull).normalized() * 1.1)
	await t.finished
	apprentice.call(&"_turn_toward", _wei.global_position)
	apprentice.call(&"play", &"scared")
	_wei.scripted_face(pull)
	await Dialogue.play(&"taken_plea")
	# Away with him: the men either side, Wei ahead; round the benches
	# (east), then back the way they came.
	var out: Array[Vector3] = [_spot(approach_path)]
	for i in range(way.size() - 1, -1, -1):
		out.append(way[i])
	_escort(apprentice, out)
	await Dialogue.play(&"taken_after")
	Dialogue.line_started.disconnect(_on_line)
	Game.set_flag(&"saw_apprentice_taken")
	Game.set_flag(&"apprentice_taken")
	player.reset_fov(1.2)
	player.viewmodel.visible = hands_shown
	player.unlock_controls(&"taken")

## Walks a guard through `points`; resolves at the last. One who can't get
## through (a prop in the way) is set down where he was going: the scene
## must not hang with the player's controls held.
func _walk(g: Guard, points: Array) -> void:
	var map := g.get_world_3d().navigation_map
	for target in points:
		# Off the navmesh an agent can't arrive, or "arrives" without a step.
		var p := NavigationServer3D.map_get_closest_point(map, target)
		var arrived := [false]
		var on_arrival := func() -> void: arrived[0] = true
		g.scripted_arrived.connect(on_arrival, CONNECT_ONE_SHOT)
		g.scripted_walk_to(p)
		var limit := g.global_position.distance_to(p) / maxf(g.walk_speed, 0.5) * 2.0 + 3.0
		var t := 0.0
		while not arrived[0] and t < limit:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		if not arrived[0]:
			g.scripted_arrived.disconnect(on_arrival)
			g.global_position = p

func _escort(apprentice: Node3D, out: Array[Vector3]) -> void:
	_walk(_wei, out.slice(1))
	await get_tree().create_timer(0.9, false).timeout
	_walk(_men[0], out)
	# He goes between them, at their pace.
	var at := apprentice.global_position
	apprentice.call(&"play", &"walk")
	for p in out:
		apprentice.call(&"_turn_toward", p)
		var tw := create_tween()
		tw.tween_property(apprentice, "global_position", p, maxf(at.distance_to(p) / _men[0].walk_speed, 0.1))
		if p == out[0]:
			_walk(_men[1], out)
		await tw.finished
		at = p
	# Gone once nobody sees them go.
	var player := get_tree().get_first_node_in_group(&"player") as Player
	while player != null and is_inside_tree() and player.camera.is_position_in_frustum(at + Vector3.UP * 1.5) and player.global_position.distance_to(at) < 30.0:
		await get_tree().create_timer(0.5, false).timeout
	for g in _actors():
		_show(g, false)
	apprentice.set(&"_talking", false)
	apprentice.call(&"_taken")

## Wei and the man who found him talk with their hands; the others listen.
func _on_line(speaker: StringName, _name: String, _text: String, _d: float, _x: Dictionary) -> void:
	_wei.play_animation(&"talk" if speaker == &"wei" else &"listen")
	_men[1].play_animation(&"talk" if speaker == &"guard_b" else &"listen")

func persist_save() -> Dictionary:
	return {"fired": fired}

func persist_load(data: Dictionary) -> void:
	fired = bool(data.get("fired", false))
