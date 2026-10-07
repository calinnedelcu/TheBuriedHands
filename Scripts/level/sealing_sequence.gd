class_name SealingSequence
extends Node
## End of Act I. The statue is finished; a bronze gate slams somewhere deep in
## the mountain. Two guards walk into the workshop and, not noticing the
## craftsman, talk about the order: nobody who has seen the tomb leaves it.
## They head off to round people up, and from then on guards are hostile.

const BOOM := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")

@export var guard_a_path: NodePath
@export var guard_b_path: NodePath
@export var talk_spot_a_path: NodePath
@export var talk_spot_b_path: NodePath
## Marker3D children: the way out of the workshop, toward the archives.
@export var exit_path: NodePath
@export var dust_path: NodePath
## Where the guards come in (looked at as they enter).
@export var door_look_path: NodePath
@export var after_route_a := 0
@export var after_route_b := 0

var _guard_a: Guard
var _guard_b: Guard

func _ready() -> void:
	_guard_a = get_node_or_null(guard_a_path) as Guard
	_guard_b = get_node_or_null(guard_b_path) as Guard
	Quest.step_changed.connect(_on_step)
	Dialogue.line_started.connect(_on_line)
	# Before the sealing the two speakers wait out of sight.
	if not Quest.has_reached(&"sealing"):
		for g in [_guard_a, _guard_b]:
			if g != null:
				g.set_scripted.call_deferred(true)

func _on_step(step: StringName) -> void:
	# Co-op: the host runs the scene; the apprentice's machine is shown it.
	if step == &"sealing" and not Net.is_client():
		_run()

func _run() -> void:
	await get_tree().create_timer(1.4, false).timeout
	Net.mirror(self, &"net_gate_slams")
	net_gate_slams()
	Game.advance_sealing(1)
	await get_tree().create_timer(1.6, false).timeout
	await Dialogue.play(&"sealing_first")
	# The guards come in.
	var spot_a := get_node_or_null(talk_spot_a_path) as Node3D
	var spot_b := get_node_or_null(talk_spot_b_path) as Node3D
	if _guard_a != null and _guard_b != null and spot_a != null and spot_b != null:
		# Turn to the door as they come in.
		var door := get_node_or_null(door_look_path) as Node3D
		if door != null:
			for player in Net.players():
				player.look_at_point(door.global_position, 1.4)
		_guard_a.scripted_walk_to(spot_a.global_position)
		await get_tree().create_timer(0.6, false).timeout
		await _guard_b.scripted_walk_to(spot_b.global_position)
		_guard_a.scripted_face(spot_b.global_position)
		_guard_b.scripted_face(spot_a.global_position)
		for player in Net.players():
			player.look_at_point((spot_a.global_position + spot_b.global_position) * 0.5 + Vector3.UP * 2.4, 1.0)
	await Dialogue.play(&"guards_talk")
	Game.set_flag(&"guards_hostile")
	_leave()
	await Dialogue.play(&"guards_aftermath")
	Quest.complete(&"sealing")

## The gate, deep in the mountain. The workshop's music dies with it.
func net_gate_slams() -> void:
	Music.stop(0.4)
	Sfx.play_ui(BOOM, 4.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.add_shake(1.0)
	var dust := get_node_or_null(dust_path) as GPUParticles3D
	if dust != null:
		dust.restart()
		dust.emitting = true
	for lamp in get_tree().get_nodes_in_group(&"wall_lamps"):
		lamp.call(&"gust")

func _leave() -> void:
	var exit := get_node_or_null(exit_path)
	if exit == null or _guard_a == null or _guard_b == null:
		return
	var points: Array[Vector3] = []
	for c in exit.get_children():
		if c is Node3D:
			points.append((c as Node3D).global_position)
	_walk_out(_guard_a, points, after_route_a, 0.0)
	_walk_out(_guard_b, points, after_route_b, 0.8)

func _walk_out(g: Guard, points: Array[Vector3], route_index: int, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	for p in points:
		await g.scripted_walk_to(p)
	g.warp_to_route(route_index)
	g.set_scripted(false)

func _on_line(speaker: StringName, _name: String, _text: String, _d: float, _x: Dictionary) -> void:
	if _guard_a == null or _guard_b == null or Dialogue.current_sequence() != &"guards_talk":
		return
	_guard_a.play_animation(&"talk" if speaker == &"guard_a" else &"listen")
	_guard_b.play_animation(&"talk" if speaker == &"guard_b" else &"listen")
