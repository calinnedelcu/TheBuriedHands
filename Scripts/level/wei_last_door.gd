class_name WeiLastDoor
extends Area3D
## Act V: Overseer Wei waits at the last door out of the burial chamber, the
## way to Liang's drain, while two of his men brick it up.
## Every name on his list is struck off but the craftsman's. When he comes
## near, Wei speaks, and what was taken on the way decides the answers:
##  - Wei's own register, from his desk: its last slip, under Zhao Gao's
##    seal, puts Wei himself in the tomb when the last name is struck off.
##    He sends his men up, lets the craftsman go and leaves by the outer
##    passage before its gate comes down.
##  - Wei's half of the tiger tally, still in hand (the gallery way past the
##    inner wall keeps it): thrown far out into the mercury, where bronze
##    floats. Wei and his men go out on the causeway after it, and the door
##    is left.
##  - Nothing, or not those: he runs. The men hunt him among the statues
##    and, once they lose him, keep watch: one up and down the strip past
##    the door, one between the causeway and the strip's east end; Wei
##    watches from the causeway. He slips back to the door behind their
##    backs.
## The area is the stretch of walkway before the door, where Wei sees him.
## Wei and his men are nowhere until the treasury (find_drain); then the Wei
## of the archives' desk is put away.

const SPOTTED := preload("res://audio/sfx/stingers/spotted.wav")
const TROWEL := [preload("res://audio/sfx/impacts/impactMining_000.ogg"), preload("res://audio/sfx/impacts/impactMining_001.ogg"), preload("res://audio/sfx/impacts/impactMining_002.ogg")]
const PLOP := preload("res://audio/sfx/impacts/impactSoft_medium_000.ogg")
const TIGER := preload("res://scenes/items/visuals/tally_wei.tscn")

@export var wei_path: NodePath
@export var men_paths: Array[NodePath] = []
## The Wei of the archives, put away when this one comes.
@export var desk_wei_path: NodePath
## Marker3Ds: Wei in the doorway, and where he watches from in the hunt.
@export var post_path: NodePath
@export var watch_path: NodePath
## Marker3Ds where the men brick up the door, in order.
@export var work_paths: Array[NodePath] = []
## The wall they've begun across it.
@export var wall_path: NodePath
## Marker3Ds out on the causeway, Wei's then the men's, over the tiger.
@export var edge_paths: Array[NodePath] = []
## Where the thrown tiger comes down on the mercury.
@export var float_path: NodePath
## A Node3D whose Marker3D children are the way up the walkway to the
## outer passage, the men's and then Wei's.
@export var leave_path: NodePath
## A Node3D whose Marker3D children are the way from the strip by the door
## out onto the causeway.
@export var gap_path: NodePath
## The beats the men keep once they've lost him, in order.
@export var ring_paths: Array[NodePath] = []

## Whether Wei has had his say, and how it ended: &"turned", &"tricked" or
## &"fled" (the ending reads it from the flags of the same names).
var met := false
var outcome: StringName = &""

var _wei: Guard
var _men: Array[Guard] = []
var _trowel_timer := 2.0
var _tiger: Node3D
var _floating := false
var _bob := 0.0

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
	# Once Wei has had his say, the scene moves them itself.
	Quest.step_changed.connect(func(_id: StringName) -> void:
		if not met:
			_arrange())
	_arrange.call_deferred()

func _process(delta: float) -> void:
	if _floating:
		_bob += delta
		_tiger.global_position.y = _spot(float_path).y + sin(_bob * 1.7) * 0.012
		_tiger.rotation.y += delta * 0.05
	# The men at work: the tap of brick on brick at the door.
	if met or not _here():
		return
	_trowel_timer -= delta
	if _trowel_timer <= 0.0:
		_trowel_timer = randf_range(1.4, 3.2)
		Sfx.play_at(TROWEL.pick_random(), _spot(wall_path), -6.0, 0.12, &"SFX", 24.0)

func _here() -> bool:
	return Quest.has_reached(&"find_drain")

## Puts everyone where the story has them now (on both machines: each one's
## quest moves on its own, the host's choice comes over by net_resolve).
func _arrange() -> void:
	if _wei == null or _men.size() < 2:
		return
	var actors: Array[Guard] = [_wei]
	actors.append_array(_men)
	if not _here():
		for g in actors:
			g.set_scripted(true)
			_show(g, false)
		return
	var desk := get_node_or_null(desk_wei_path) as Guard
	if desk != null:
		desk.set_scripted(true)
		_show(desk, false)
	# His register in his hand, unless it was taken from his desk.
	net_held(not Game.get_flag(&"has_evidence"))
	match outcome:
		&"turned":
			for g in actors:
				_show(g, false)
		&"tricked":
			_place(_wei, _spot(edge_paths[0]), _spot(float_path))
			for i in _men.size():
				_place(_men[i], _spot(edge_paths[i + 1]), _spot(float_path))
			_float_tiger()
		&"fled":
			_place(_wei, _spot(watch_path), _spot(watch_path) + Vector3.FORWARD * 10.0)
			for i in _men.size():
				_show(_men[i], true)
				var route := get_node_or_null(ring_paths[i]) as PatrolRoute
				if route != null:
					_men[i].set_route(route, int(_men[i].get(&"_route_index")))
				if not Net.is_client():
					_men[i].set_scripted(false)
		_:
			var wall := _spot(wall_path)
			_place(_wei, _spot(post_path), wall)
			for i in _men.size():
				_place(_men[i], _spot(work_paths[i]), wall)
				_men[i].play_animation(&"ready")

## Stands a guard at `at`, turned toward `facing`, in the cutscene's hands.
func _place(g: Guard, at: Vector3, facing: Vector3) -> void:
	_show(g, true)
	g.set_scripted(true)
	g.global_position = at
	g.scripted_face(facing)
	g.rotation.y = atan2(-(facing.x - at.x), -(facing.z - at.z))

func _show(g: Guard, on: bool) -> void:
	g.visible = on
	g.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	g.collision_layer = 4 if on else 0

func _spot(path: NodePath) -> Vector3:
	var n := get_node_or_null(path) as Node3D
	return n.global_position if n != null else global_position

func _points(path: NodePath) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var holder := get_node_or_null(path)
	if holder != null:
		for c in holder.get_children():
			if c is Node3D:
				out.append((c as Node3D).global_position)
	return out

# --- The meeting ------------------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if met or not (body is Player) or not Net.story_allowed() or not Quest.is_at(&"find_drain"):
		return
	met = true
	Net.mirror(self, &"net_met")
	_meet(body as Player)

func _meet(player: Player) -> void:
	var everyone := Net.players()
	for p in everyone:
		p.lock_controls(&"wei", false)
	net_spotted()
	Net.mirror(self, &"net_spotted")
	var head := _wei.global_position + Vector3.UP * 2.5
	for p in everyone:
		p.look_at_point(head, 0.9)
	_wei.scripted_face(player.global_position)
	Dialogue.line_started.connect(_on_line)
	await Dialogue.play(&"wei_last")
	var options := PackedStringArray()
	if Game.get_flag(&"has_evidence"):
		options.append("CHOICE_WEI_REGISTER")
	if _tiger_carrier() != null:
		options.append("CHOICE_WEI_TIGER")
	options.append("CHOICE_WEI_RUN")
	var pick := options[await Dialogue.choose(options)]
	match pick:
		"CHOICE_WEI_REGISTER":
			await _turn()
		"CHOICE_WEI_TIGER":
			await _trick(_tiger_carrier())
		_:
			await _flee(player)
	if Dialogue.line_started.is_connected(_on_line):
		Dialogue.line_started.disconnect(_on_line)
	for p in everyone:
		p.unlock_controls(&"wei")

## The register: Wei reads his own name on the sealed last slip, sends his
## men up and goes after them, to be out before the outer gate comes down.
func _turn() -> void:
	_held(true)
	await Dialogue.play(&"wei_register")
	# He hands it back, and calls his men off.
	_held(false)
	await Dialogue.play(&"wei_register_back")
	_resolve(&"turned")
	var way := _points(leave_path)
	_leave(_men[0], way, 0.0)
	_leave(_men[1], way, 0.8)
	await Dialogue.play(&"wei_register_go")
	_leave(_wei, way, 0.0)

func _held(on: bool) -> void:
	net_held(on)
	Net.mirror(self, &"net_held", [on])

## Up the walkway, gone once nobody sees them go.
func _leave(g: Guard, way: Array[Vector3], delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	await _walk(g, way, false)
	while is_inside_tree() and _seen(g.global_position):
		await get_tree().create_timer(0.5, false).timeout
	_show(g, false)
	Net.mirror(self, &"net_gone", [_index_of(g)])

func _seen(at: Vector3) -> bool:
	for p in Net.players():
		if p.global_position.distance_to(at) < 30.0 and p.camera.is_position_in_frustum(at + Vector3.UP * 1.5):
			return true
	return false

func _index_of(g: Guard) -> int:
	return 0 if g == _wei else _men.find(g) + 1

## The tiger: thrown into the mercury, where it floats out of reach; Wei and
## his men go out on the causeway after it.
func _trick(carrier: Player) -> void:
	await Dialogue.play(&"wei_tiger")
	net_throw(String(carrier.name))
	Net.mirror(self, &"net_throw", [String(carrier.name)])
	await get_tree().create_timer(1.3, false).timeout
	_resolve(&"tricked")
	var target := _spot(float_path)
	for i in _men.size():
		_go_to_edge(_men[i], _spot(edge_paths[i + 1]), target, true, 0.0)
	# He follows once they're by him, in the narrow strip.
	_go_to_edge(_wei, _spot(edge_paths[0]), target, false, 2.2)
	await Dialogue.play(&"wei_tiger_after")

func _go_to_edge(g: Guard, at: Vector3, target: Vector3, run: bool, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	await _walk(g, _points(gap_path) + [at], run)
	g.scripted_face(target)
	g.play_animation(&"ready" if g != _wei else &"talk")

## No answer: "Seize him!" The men hunt him, then keep watch; Wei watches
## the chamber from the causeway.
func _flee(player: Player) -> void:
	await Dialogue.play(&"wei_seize")
	_resolve(&"fled")
	for i in _men.size():
		var route := get_node_or_null(ring_paths[i]) as PatrolRoute
		if route != null:
			_men[i].set_route(route)
		_men[i].chase(player)
	player.notice("NOTICE_WEI_RUN")
	_to_watch()

func _to_watch() -> void:
	await _walk(_wei, _points(gap_path) + [_spot(watch_path)], false)
	_wei.scripted_face(_spot(watch_path) + Vector3.FORWARD * 10.0)

func _resolve(how: StringName) -> void:
	outcome = how
	Game.set_flag(StringName("wei_" + String(how)))
	Net.mirror(self, &"net_resolve", [String(how)])

func _tiger_carrier() -> Player:
	for p in Net.players():
		if p.inventory.has_item(&"tally_wei"):
			return p
	return null

## Walks a guard through `points`; resolves at the last. One who can't get
## through is set down where he was going (see ApprenticeTaken._walk). The
## strip behind the treasures is narrow: on his way he passes through the
## craftsman rather than wait on him.
func _walk(g: Guard, points: Array, run: bool) -> void:
	var map := g.get_world_3d().navigation_map
	# Close round corners: the treasures' corners are near the path.
	var agent := g.get_node("Agent") as NavigationAgent3D
	var desired := agent.path_desired_distance
	agent.path_desired_distance = 0.35
	g.set_collision_mask_value(2, false)
	for target in points:
		var p := NavigationServer3D.map_get_closest_point(map, target)
		var speed := g.run_speed if run else g.walk_speed
		var limit := _path_length(map, g.global_position, p) / speed * 2.0 + 3.0
		var t := 0.0
		# A guard who stops short (stuck on a corner, he gives up and calls it
		# arrived) is sent on again.
		while g.global_position.distance_to(p) > 1.0 and t < limit:
			var arrived := [false]
			var on_arrival := func() -> void: arrived[0] = true
			g.scripted_arrived.connect(on_arrival, CONNECT_ONE_SHOT)
			g.scripted_walk_to(p, run)
			while not arrived[0] and t < limit:
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
			if not arrived[0]:
				g.scripted_arrived.disconnect(on_arrival)
		if g.global_position.distance_to(p) > 1.0:
			g.global_position = p
	g.set_collision_mask_value(2, true)
	agent.path_desired_distance = desired

func _path_length(map: RID, from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return maxf(length, from.distance_to(to))

## Wei talks with his hands; his men listen.
func _on_line(speaker: StringName, _name: String, _text: String, _d: float, _x: Dictionary) -> void:
	if outcome == &"" or outcome == &"turned":
		_wei.play_animation(&"talk" if speaker == &"wei" else &"listen")

# --- The tiger on the mercury, on both machines ------------------------------------------------

## Out of the carrier's hand in an arc, onto the mercury, where it floats.
func net_throw(carrier_name: String) -> void:
	var carrier := Net.body(StringName(carrier_name))
	var from := global_position
	if carrier != null:
		carrier.inventory.remove(&"tally_wei")
		from = carrier.camera.global_position + Vector3.DOWN * 0.3
	var to := _spot(float_path)
	_make_tiger()
	_tiger.global_position = from
	var arc := func(t: float) -> void:
		_tiger.global_position = from.lerp(to, t) + Vector3.UP * (8.0 * t * (1.0 - t))
		_tiger.rotation = Vector3(t * 9.0, t * 4.0, 0.0)
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 1.2)
	tw.tween_callback(func() -> void:
		_tiger.rotation = Vector3.ZERO
		_floating = true
		Sfx.play_at(PLOP, to, 0.0, 0.1, &"SFX", 30.0))

func _float_tiger() -> void:
	_make_tiger()
	_tiger.global_position = _spot(float_path)
	_floating = true

func _make_tiger() -> void:
	if _tiger != null:
		return
	_tiger = TIGER.instantiate() as Node3D
	_tiger.name = "Tiger"
	add_child(_tiger)
	# Its gold inlay catches the light, a glint on the dark mercury.
	var glint := OmniLight3D.new()
	glint.light_color = Color(1.0, 0.78, 0.45)
	glint.light_energy = 0.9
	glint.omni_range = 1.6
	glint.position = Vector3.UP * 0.25
	_tiger.add_child(glint)

func net_held(on: bool) -> void:
	var hand := _wei.find_child("HeldHand", true, false) as Node3D
	if hand != null:
		hand.visible = on

func net_met() -> void:
	met = true

func net_spotted() -> void:
	Sfx.play_ui(SPOTTED, -4.0)

func net_resolve(how: String) -> void:
	met = true
	outcome = StringName(how)

func net_gone(index: int) -> void:
	var g := _wei if index == 0 else _men[index - 1]
	_show(g, false)

func persist_save() -> Dictionary:
	return {"met": met, "outcome": String(outcome)}

func persist_load(data: Dictionary) -> void:
	met = bool(data.get("met", false))
	outcome = StringName(data.get("outcome", ""))
	_arrange()
