@tool
class_name WeiDesk
extends Node3D
## Overseer Wei's desk at the far end of the archives, before the sealed door.
## His half of the tiger tally and the workers' register lie on it, and he
## stands behind it reading out the names on his list and striking them off.
## Only a noise makes him look up and go to see; then he comes back to it.
## Built in code: the lacquered desk, black with red, an inkstone and brush.
## The pickups on it and Wei's post (a route of one point) are in the level.
##
## The desk's front (local +z) faces the room; Wei stands behind it (-z).

const BLACK := preload("res://assets/materials/props/lacquer_black.tres")
const RED := preload("res://assets/materials/props/lacquer_red.tres")
const TOP := 0.93

## Who reads at it.
@export var wei_path: NodePath
## Seconds between names while he's at it and someone is near enough to hear.
@export var read_every := Vector2(9.0, 15.0)
@export var hear_range := 22.0

const LINES := ["WEI_READ_1", "WEI_READ_2", "WEI_READ_3", "WEI_READ_4", "WEI_READ_5", "WEI_READ_6"]

var _wei: Guard
var _timer := 5.0
var _next := 0

func _ready() -> void:
	_build()
	_wei = get_node_or_null(wei_path) as Guard

func _process(delta: float) -> void:
	# Co-op: the host's lines; the other machine is told.
	if Engine.is_editor_hint() or _wei == null or Net.is_client():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(read_every.x, read_every.y)
	if not reading():
		return
	var near := false
	for p in Net.players():
		near = near or p.global_position.distance_to(global_position) < hear_range
	if near:
		Dialogue.say(&"wei", LINES[_next % LINES.size()], Dialogue.Priority.AMBIENT)
		_next += 1

## Whether Wei stands at his desk, reading (not off looking for a noise).
func reading() -> bool:
	return _wei != null and _wei.visible and _wei.state == Guard.State.PATROL \
		and _wei.global_position.distance_to(global_position) < 2.6

func _build() -> void:
	# The top, black, edged in red at the front; two side panels; an apron
	# in red under the front edge; a bar between the feet.
	_box(Vector3(1.9, 0.07, 0.8), Vector3(0.0, TOP - 0.035, 0.0), BLACK)
	_box(Vector3(1.9, 0.014, 0.035), Vector3(0.0, TOP + 0.002, 0.385), RED)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, TOP - 0.07, 0.72), Vector3(sx * 0.84, (TOP - 0.07) * 0.5, 0.0), BLACK)
	_box(Vector3(1.6, 0.2, 0.035), Vector3(0.0, TOP - 0.17, 0.37), RED)
	_box(Vector3(1.6, 0.05, 0.05), Vector3(0.0, 0.12, 0.0), BLACK)
	# An inkstone and a brush for striking names off.
	_box(Vector3(0.15, 0.03, 0.11), Vector3(-0.62, TOP + 0.015, 0.12), BLACK)
	var brush := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.007
	stick.bottom_radius = 0.009
	stick.height = 0.24
	brush.mesh = stick
	brush.material_override = RED
	brush.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, 0.4), Vector3(-0.5, TOP + 0.01, -0.06))
	add_child(brush)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, TOP, 0.8)
	shape.shape = box
	shape.position = Vector3(0.0, TOP * 0.5, 0.0)
	body.add_child(shape)

func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	add_child(mi)
