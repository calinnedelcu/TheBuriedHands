class_name CausewayPin
extends Node3D
## Co-op: a bronze pin by the far end of the causeway. Dropped into its socket
## while the causeway is all the way up, it holds it there for good, and
## whoever bore on the brake can let go and cross. Added by the CoopDirector.

const BRONZE := preload("res://assets/materials/props/bronze.tres")
const CLANK := preload("res://audio/sfx/impacts/impactPlate_light_000.ogg")
const SETTLE := preload("res://audio/sfx/tunnel/rock_cinematic.mp3")

var causeway: Causeway
var _pin: Node3D
var _dropping := false

func _ready() -> void:
	_build()

func _process(_delta: float) -> void:
	# Back from a checkpoint the causeway may already be pinned.
	if causeway != null and causeway.pinned and not _dropping:
		_pin.position.y = 0.15

func usable_prompt(_user: Node) -> String:
	if causeway == null or causeway.pinned or not causeway.raised:
		return ""
	return tr("PROMPT_DROP_PIN") if causeway.is_up() else tr("PROMPT_PIN_WAIT")

func usable_can_use(_user: Node) -> bool:
	return causeway != null and not causeway.pinned and causeway.is_up()

func usable_show_blocked(_user: Node) -> bool:
	return causeway != null and causeway.raised and not causeway.pinned

func usable_use(_user: Node) -> void:
	_dropping = true
	causeway.pin()
	Sfx.play_at(CLANK, global_position + Vector3.UP * 0.5, 2.0)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_pin, "position:y", 0.15, 0.25)
	t.tween_callback(func():
		_dropping = false
		Sfx.play_at(SETTLE, global_position, -6.0, 0.1, &"Tomb", 40.0))

## A bronze pin standing in a stone socket, ready to drop.
func _build() -> void:
	var socket := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(0.5, 0.3, 0.5)
	socket.mesh = block
	socket.material_override = load("res://assets/materials/level/rockys.tres")
	socket.position = Vector3(0, 0.15, 0)
	add_child(socket)
	_pin = Node3D.new()
	_pin.name = "Pin"
	_pin.position = Vector3(0, 0.75, 0)
	add_child(_pin)
	var rod := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 0.9
	rod.mesh = cyl
	rod.material_override = BRONZE
	rod.position = Vector3(0, 0.45, 0)
	_pin.add_child(rod)
	var head := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.14
	head.mesh = ring
	head.material_override = BRONZE
	head.position = Vector3(0, 0.95, 0)
	head.rotation.x = PI * 0.5
	_pin.add_child(head)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = Vector3(0.7, 1.9, 0.7)
	shape.shape = hit
	shape.position = Vector3(0, 0.95, 0)
	body.add_child(shape)
	var usable := DelegateUsable.new()
	usable.name = "Usable"
	usable.delegate_path = ^"../.."
	body.add_child(usable)
