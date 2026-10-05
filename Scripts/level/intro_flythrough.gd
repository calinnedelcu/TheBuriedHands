class_name IntroFlythrough
extends Node3D
## The first seconds of a new game: the camera drifts back through the
## workshop, over the craftsmen at work, and settles into the craftsman's own
## eyes. Skippable (it then hurries to the landing instead of cutting).

signal finished

## The drift, from first to last point (the landing is the player's eyes).
@export var points: Array[Vector3] = [Vector3(-44.0, 4.6, -19.5), Vector3(-52.0, 4.1, -21.0), Vector3(-62.0, 3.7, -22.8), Vector3(-70.0, 3.2, -24.0)]
## Where the camera looks along the way (spread evenly over the drift).
@export var looks: Array[Vector3] = [Vector3(-38.0, 1.4, -25.0), Vector3(-46.0, 1.5, -22.0), Vector3(-52.0, 1.6, -20.0)]
@export var duration := 12.0
@export var start_fov := 58.0

var _cam: Camera3D
var _player: Player
var _curve: Curve3D
var _t := 0.0

func play(player: Player) -> void:
	_player = player
	player.lock_controls(&"intro")
	_curve = Curve3D.new()
	for i in points.size():
		# Catmull-Rom handles: a smooth glide through every point.
		var prev := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, points.size() - 1)]
		var h := (next - prev) / 6.0
		_curve.add_point(points[i], -h, h)
	_cam = Camera3D.new()
	_cam.fov = start_fov
	_cam.near = 0.05
	add_child(_cam)
	_cam.make_current()
	_place(0.0)

func _process(delta: float) -> void:
	if _player == null:
		return
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	_place(k)
	if k >= 1.0:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed(&"skip_line") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump"):
		_t = maxf(_t, duration * 0.82)
		get_viewport().set_input_as_handled()

func _place(k: float) -> void:
	var e := smoothstep(0.0, 1.0, k)
	var pos := _curve.sample_baked(e * _curve.get_baked_length(), true)
	var look := _look(e)
	var xf := Transform3D(Basis.looking_at(look - pos), pos)
	# The last stretch eases into the player's own view.
	var land := smoothstep(0.62, 1.0, k)
	var eye := _player.camera.global_transform
	_cam.global_transform = xf.interpolate_with(eye, land)
	_cam.fov = lerpf(start_fov, _player.camera.fov, land)

func _look(e: float) -> Vector3:
	var x := e * float(looks.size() - 1)
	var i := mini(int(x), looks.size() - 2)
	return looks[i].lerp(looks[i + 1], smoothstep(0.0, 1.0, x - float(i)))

func _finish() -> void:
	_player.camera.make_current()
	_player.unlock_controls(&"intro")
	_player = null
	finished.emit()
	queue_free()
