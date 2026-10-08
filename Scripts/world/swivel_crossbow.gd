@tool
class_name SwivelCrossbow
extends Node3D
## A crossbow on a turning stand, one bolt in its groove. Tap the use key to
## turn it on its next mark, hold it to loose at the one it is on. In the
## crossbow gallery its marks are the gong (whose stroke draws the
## crossbowmen on the walkways to look) and the lamp hanging over the way
## out (shot down, the way out is dark): one bolt, one or the other.
##
## The origin is on the floor at the stand's foot. Built in code; nothing
## generated is saved.

const MODEL := preload("res://assets/models/props/crossbow.glb")
const BRONZE := preload("res://assets/materials/props/bronze.tres")
const TIMBER := preload("res://assets/materials/level/timber.tres")
const TURN_SOUND := preload("res://audio/sfx/impacts/creak1.ogg")
const LOOSE_SOUND := preload("res://audio/sfx/trap/crossbow_shot.mp3")
const HEIGHT := 1.55

## What it can be turned on, in turn, and what each is called (translation
## keys for the prompt), in the same order.
@export var target_paths: Array[NodePath] = []
@export var target_names: Array[String] = []
@export var bolt_speed := 42.0
@export var damage := 3.0

var aim := 0
var loosed := false
var _pivot: Node3D
var _string: Node3D
var _bolt: Node3D
var _usable: DelegateUsable

func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	_point(false)

# --- Usable delegate --------------------------------------------------------------------

func usable_prompt(_user: Node) -> String:
	if loosed or target_paths.is_empty():
		return ""
	var parts: Array[String] = []
	if target_paths.size() > 1:
		parts.append(tr("PROMPT_SWIVEL_TURN") % tr(_name_of((aim + 1) % target_paths.size())))
	parts.append("%s: %s" % [tr("HUD_HOLD"), tr("PROMPT_SWIVEL_LOOSE") % tr(_name_of(aim))])
	return "  ·  ".join(parts)

func usable_can_use(_user: Node) -> bool:
	return not loosed and not target_paths.is_empty()

func usable_tap(_user: Node) -> void:
	if loosed or target_paths.size() < 2:
		return
	aim = (aim + 1) % target_paths.size()
	Sfx.play_at(TURN_SOUND, _pivot.global_position, -4.0, 0.1)
	_point(true)

func usable_hold_done(user: Node) -> void:
	if loosed:
		return
	loosed = true
	_show_loaded()
	Sfx.play_at(LOOSE_SOUND, _pivot.global_position, 2.0, 0.05, &"Tomb", 30.0)
	# A well-kept stand: the twang carries less than a trap's.
	Stealth.make_noise(_pivot.global_position, 6.0, self)
	var dir := -_pivot.global_basis.z
	# Whoever stands at it, wherever, isn't in its way.
	var through: Array[RID] = []
	if user is CollisionObject3D:
		through.append((user as CollisionObject3D).get_rid())
	Bolt.launch(get_tree().current_scene, _pivot.global_position + dir * 0.6, dir, bolt_speed, damage, 70.0, self, through)

func _name_of(i: int) -> String:
	return target_names[i] if i < target_names.size() else ""

# --- Aiming ------------------------------------------------------------------------------

## Turns the crossbow on its mark (at once, or turning on its stand).
func _point(animate: bool) -> void:
	if target_paths.is_empty():
		return
	var target := get_node_or_null(target_paths[aim]) as Node3D
	if target == null:
		return
	# A mark may say where on it to aim (a gong's face, not its feet).
	var at: Vector3 = target.call(&"aim_point") if target.has_method(&"aim_point") else target.global_position
	var look := Basis.looking_at((at - _pivot.global_position).normalized())
	if not animate:
		_pivot.global_basis = look
		return
	var from := _pivot.global_basis.get_rotation_quaternion()
	var to := look.get_rotation_quaternion()
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void: _pivot.global_basis = Basis(from.slerp(to, t)), 0.0, 1.0, 0.9)

func _show_loaded() -> void:
	if _string != null:
		_string.visible = not loosed
	if _bolt != null:
		_bolt.visible = not loosed

# --- Build ------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	# The stand: a squared post on a cross of feet, a bronze cap it turns on.
	_box(self, Vector3(0.2, HEIGHT - 0.1, 0.2), Vector3(0.0, (HEIGHT - 0.1) * 0.5, 0.0), TIMBER)
	_box(self, Vector3(0.9, 0.12, 0.16), Vector3(0.0, 0.06, 0.0), TIMBER)
	_box(self, Vector3(0.16, 0.12, 0.9), Vector3(0.0, 0.06, 0.0), TIMBER)
	var cap := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.15
	cyl.height = 0.1
	cap.mesh = cyl
	cap.material_override = BRONZE
	cap.position = Vector3(0.0, HEIGHT - 0.05, 0.0)
	add_child(cap)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = Vector3(0.0, HEIGHT + 0.08, 0.0)
	add_child(_pivot)
	# The same Qin crossbow as the walls' (it shoots along its -z).
	var model := MODEL.instantiate() as Node3D
	model.name = "Visual"
	model.scale = Vector3.ONE * 1.5
	_pivot.add_child(model)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "Bronze":
				mi.set_surface_override_material(i, BRONZE)
	_string = model.find_child("String", true, false) as Node3D
	_bolt = model.find_child("Bolt", true, false) as Node3D
	_show_loaded()
	if Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.6, 0.9)
	shape.shape = box
	shape.position = Vector3(0.0, HEIGHT, 0.0)
	body.add_child(shape)
	_usable = DelegateUsable.new()
	_usable.name = "Usable"
	_usable.prompt_key = "PROMPT_SWIVEL_LOOSE"
	_usable.tap_enabled = true
	_usable.hold_time = 1.2
	body.add_child(_usable)
	# The stand itself is in the way.
	var post := StaticBody3D.new()
	post.name = "Stand"
	post.collision_layer = 1
	post.collision_mask = 0
	add_child(post)
	var post_shape := CollisionShape3D.new()
	var post_box := BoxShape3D.new()
	post_box.size = Vector3(0.5, HEIGHT, 0.5)
	post_shape.shape = post_box
	post_shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	post.add_child(post_shape)

func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)

func persist_save() -> Dictionary:
	return {"aim": aim, "loosed": loosed}

func persist_load(data: Dictionary) -> void:
	aim = int(data.get("aim", 0))
	loosed = bool(data.get("loosed", false))
	_show_loaded()
	_point(false)
