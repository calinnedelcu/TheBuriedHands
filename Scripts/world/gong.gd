@tool
class_name Gong
extends Node3D
## A bronze gong hung in a timber frame. Struck by a bolt (bolt_hit, through
## its BoltTarget) it booms through the hall and swings: the guards whose
## post it is come to look at it, wherever they are in the hall, and any
## other guard in earshot turns to it.
##
## The origin is on the floor between the frame's feet; the disc faces +z.
## Built in code; nothing generated is saved.

const BRONZE := preload("res://assets/materials/props/bronze.tres")
const TIMBER := preload("res://assets/materials/level/timber.tres")
const BOOM := preload("res://audio/sfx/treasure/bell.wav")

## The disc's diameter, and how high its middle hangs.
@export var diameter := 1.5:
	set(v):
		diameter = v
		_rebuild()
@export var hang_height := 1.8:
	set(v):
		hang_height = v
		_rebuild()
## How far its stroke carries to any guard's ear.
@export var noise_radius := 45.0
## The guards whose post it is: struck, it calls them to it.
@export var listener_paths: Array[NodePath] = []

var struck := false
var _disc: Node3D
var _audio: AudioStreamPlayer3D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	var r := diameter * 0.5
	var span := diameter + 0.5
	# The frame: two posts on feet, a crossbar, cords to the disc.
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(0.16, hang_height + r + 0.55, 0.16), Vector3(sx * span * 0.5, (hang_height + r + 0.55) * 0.5, 0.0), TIMBER)
		_box(self, Vector3(0.2, 0.14, 0.9), Vector3(sx * span * 0.5, 0.07, 0.0), TIMBER)
	_box(self, Vector3(span + 0.3, 0.16, 0.18), Vector3(0.0, hang_height + r + 0.47, 0.0), TIMBER)
	_disc = Node3D.new()
	_disc.name = "Disc"
	# It swings from the crossbar.
	_disc.position = Vector3(0.0, hang_height + r + 0.4, 0.0)
	add_child(_disc)
	for sx in [-0.35, 0.35]:
		_box(_disc, Vector3(0.025, 0.4, 0.025), Vector3(sx * r, -0.2, 0.0), TIMBER)
	var face := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.05
	cyl.radial_segments = 40
	face.mesh = cyl
	face.material_override = BRONZE
	face.rotation.x = PI * 0.5
	face.position = Vector3(0.0, -0.4 - r, 0.0)
	_disc.add_child(face)
	# A raised rim and the boss in the middle, where it's struck.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.06
	torus.outer_radius = r
	torus.rings = 40
	rim.mesh = torus
	rim.material_override = BRONZE
	rim.rotation.x = PI * 0.5
	rim.position = face.position
	_disc.add_child(rim)
	var boss := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = r * 0.22
	dome.height = r * 0.22
	boss.mesh = dome
	boss.material_override = BRONZE
	boss.position = face.position + Vector3(0.0, 0.0, 0.02)
	_disc.add_child(boss)
	if Engine.is_editor_hint():
		return
	# What a bolt hits; the frame stands in the way of whoever walks into it.
	var target := StaticBody3D.new()
	target.name = "BoltTarget"
	target.collision_layer = 1
	target.collision_mask = 0
	_disc.add_child(target)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(diameter, diameter, 0.12)
	shape.shape = box
	shape.position = face.position
	target.add_child(shape)
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	frame.collision_layer = 1
	frame.collision_mask = 0
	add_child(frame)
	for sx in [-1.0, 1.0]:
		var post := CollisionShape3D.new()
		var post_box := BoxShape3D.new()
		post_box.size = Vector3(0.2, hang_height + r + 0.55, 0.9)
		post.shape = post_box
		post.position = Vector3(sx * span * 0.5, (hang_height + r + 0.55) * 0.5, 0.0)
		frame.add_child(post)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = BOOM
	_audio.pitch_scale = 0.42
	_audio.volume_db = 8.0
	_audio.max_distance = 70.0
	_audio.unit_size = 14.0
	_audio.bus = &"Tomb"
	_audio.position = face.position + _disc.position
	add_child(_audio)

## Where to aim at it: the middle of its face.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * hang_height

## A bolt struck it (on both co-op machines; the guards hear it on the host).
func bolt_hit(_at: Vector3) -> void:
	struck = true
	_audio.play()
	var at := aim_point()
	Stealth.make_noise(at, noise_radius, self)
	if not Net.is_client():
		for path in listener_paths:
			var g := get_node_or_null(path) as Guard
			if g != null:
				g.hear_alarm(at)
	var swing := create_tween().set_trans(Tween.TRANS_SINE)
	for k in 5:
		var a := 0.22 * pow(0.55, k) * (1.0 if k % 2 == 0 else -1.0)
		swing.tween_property(_disc, "rotation:x", a, 0.32)
	swing.tween_property(_disc, "rotation:x", 0.0, 0.3)

func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
