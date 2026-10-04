@tool
class_name WallCrossbow
extends Node3D
## A bronze crossbow set in a wall niche, fired by linked pressure plates.
## One shot. The bolt flies level at the crossbow's height, so crouching or
## crawling lets it pass overhead. Cut its string with a chisel to disarm it.

const FIRE_SOUND := preload("res://audio/sfx/trap/crossbow_shot.mp3")
const HIT_WALL := [preload("res://audio/sfx/impacts/impactPlank_medium_001.ogg"), preload("res://audio/sfx/impacts/impactPlank_medium_002.ogg")]
const CUT_SOUND := preload("res://audio/sfx/impacts/drawKnife1.ogg")

@export var damage := 3.0
@export var bolt_speed := 42.0
@export var max_range := 40.0

var armed := true
var _bolt: Node3D
var _string: MeshInstance3D

func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	var usable := $Body/Usable as DelegateUsable
	usable.hold_time = 2.0

# --- Firing --------------------------------------------------------------------------

func fire() -> void:
	if not armed:
		return
	armed = false
	_string.visible = false
	Sfx.play_at(FIRE_SOUND, global_position, 4.0, 0.05, &"Tomb", 50.0)
	Stealth.make_noise(global_position, 20.0, self)
	var bolt := _make_bolt()
	get_tree().current_scene.add_child(bolt)
	bolt.global_transform = Transform3D(global_basis, global_position + (-global_basis.z) * 0.5)
	_fly(bolt)

func _fly(bolt: Node3D) -> void:
	var dir := -global_basis.z
	var travelled := 0.0
	var space := get_world_3d().direct_space_state
	while travelled < max_range and is_instance_valid(bolt):
		await get_tree().physics_frame
		var step := bolt_speed * get_physics_process_delta_time()
		var from := bolt.global_position
		var to := from + dir * step
		var params := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
		var hit := space.intersect_ray(params)
		if not hit.is_empty():
			bolt.global_position = hit.position - dir * 0.15
			if hit.collider is Player:
				(hit.collider as Player).apply_damage(damage, self, "DEATH_CROSSBOW")
				(hit.collider as Player).add_shake(0.6)
				bolt.queue_free()
			else:
				Sfx.play_random_at(HIT_WALL, hit.position, 0.0, 0.08, &"Tomb", 30.0)
				Stealth.make_noise(hit.position, 10.0, self)
			return
		bolt.global_position = to
		travelled += step
	if is_instance_valid(bolt):
		bolt.queue_free()

# --- Usable delegate: cut the string --------------------------------------------------------

func usable_prompt(user: Node) -> String:
	if not armed:
		return ""
	var p := user as Player
	return tr("PROMPT_DISARM") if p != null and p.inventory.has_item(&"chisel") else tr("PROMPT_NEED_CHISEL_DISARM")

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return armed and p != null and p.inventory.has_item(&"chisel")

func usable_show_blocked(_user: Node) -> bool:
	return armed

func usable_hold_done(user: Node) -> void:
	armed = false
	_string.visible = false
	Sfx.play_at(CUT_SOUND, global_position, -2.0)
	var p := user as Player
	if p != null:
		p.viewmodel.call(&"play_use")

func persist_save() -> Dictionary:
	return {"armed": armed}

func persist_load(data: Dictionary) -> void:
	armed = bool(data.get("armed", true))
	if _string != null:
		_string.visible = armed

# --- Visuals (built in code so the scene stays tiny) ----------------------------------------

func _build_visual() -> void:
	var root := get_node_or_null("Visual")
	if root != null:
		root.free()
	root = Node3D.new()
	root.name = "Visual"
	add_child(root)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.42, 0.32, 0.18)
	bronze.metallic = 0.7
	bronze.roughness = 0.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.19, 0.11)
	wood.roughness = 0.85
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.75, 0.68, 0.55)
	_part(root, _box(Vector3(0.12, 0.1, 0.9)), wood, Vector3(0, 0, 0.1))
	_part(root, _box(Vector3(0.16, 0.14, 0.18)), bronze, Vector3(0, 0, 0.3))
	var arm_l := _part(root, _box(Vector3(0.55, 0.05, 0.06)), wood, Vector3(-0.26, 0, -0.28))
	arm_l.rotation_degrees.y = -14
	var arm_r := _part(root, _box(Vector3(0.55, 0.05, 0.06)), wood, Vector3(0.26, 0, -0.28))
	arm_r.rotation_degrees.y = 14
	_string = _part(root, _box(Vector3(1.04, 0.012, 0.012)), cord, Vector3(0, 0, -0.08))
	_string.visible = armed
	_bolt = _part(root, _box(Vector3(0.025, 0.025, 0.6)), wood, Vector3(0, 0.05, -0.15))
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _make_bolt() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _box(Vector3(0.025, 0.025, 0.65))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.12)
	mi.material_override = mat
	n.add_child(mi)
	var tip := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.05, 0.1, 0.03)
	tip.mesh = prism
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.5, 0.4, 0.22)
	bronze.metallic = 0.7
	tip.material_override = bronze
	tip.rotation_degrees.x = -90
	tip.position.z = -0.37
	n.add_child(tip)
	return n

func _part(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
