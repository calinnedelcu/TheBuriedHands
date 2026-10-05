class_name ClayStatue
extends Node3D
## The unfinished terracotta soldier in the workshop: the tutorial's work.
## Steps: set the bowl on the bench (place_bowl), bind the legs with slip by
## holding the key (apply_slip) — the clay darkens, wet, as it goes on — then,
## once the chisel is found, strike the joint three times (finish_statue).
## Each strike throws clay chips; the last one leaves the soldier standing
## whole on the plinth (the loose parts on the bench are gone).

const STRIKE_SOUNDS := [
	preload("res://audio/sfx/impacts/impactMining_000.ogg"),
	preload("res://audio/sfx/impacts/impactMining_001.ogg"),
	preload("res://audio/sfx/impacts/impactMining_002.ogg"),
]
const SLIP_SOUND := preload("res://audio/sfx/impacts/impactSoft_medium_000.ogg")
const STRIKES_NEEDED := 3

@export var bowl_spot_path: NodePath
@export var placed_bowl_path: NodePath
@export var slip_visual_path: NodePath
## The legs on the plinth (they get the wet slip look) and any loose parts
## waiting on the bench; all hidden once the soldier is whole.
@export var unfinished_paths: Array[NodePath] = []
## The whole soldier, hidden until the last strike.
@export var finished_path: NodePath

@onready var _bowl_spot: Node3D = get_node_or_null(bowl_spot_path)
@onready var _placed_bowl: Node3D = get_node_or_null(placed_bowl_path)
@onready var _slip_visual: Node3D = get_node_or_null(slip_visual_path)
@onready var _usable: DelegateUsable = get_node_or_null("Body/Usable")

var bowl_placed := false
var slip_applied := false
var strikes := 0

var _wet: StandardMaterial3D
var _wetness := 0.0

func _ready() -> void:
	add_to_group(&"persistent")
	_wet = StandardMaterial3D.new()
	_wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wet.albedo_color = Color(0.13, 0.07, 0.04, 0.0)
	_wet.roughness = 0.12
	_wet.metallic_specular = 0.9
	var legs := _legs()
	if legs != null:
		legs.material_overlay = _wet
	_refresh()

func _legs() -> GeometryInstance3D:
	return get_node_or_null(unfinished_paths[0]) as GeometryInstance3D if not unfinished_paths.is_empty() else null

func _set_wetness(value: float) -> void:
	_wetness = clampf(value, 0.0, 1.0)
	if _wet != null:
		_wet.albedo_color.a = _wetness * 0.72

func _refresh() -> void:
	if _placed_bowl != null:
		_placed_bowl.visible = bowl_placed and strikes < STRIKES_NEEDED
	if _slip_visual != null:
		_slip_visual.visible = slip_applied
	if slip_applied and _wetness < 1.0:
		_set_wetness(1.0)
	var done := strikes >= STRIKES_NEEDED
	for path in unfinished_paths:
		var n := get_node_or_null(path) as Node3D
		if n != null:
			n.visible = not done
	var whole := get_node_or_null(finished_path) as Node3D
	if whole != null:
		whole.visible = done
	if _usable != null:
		_usable.hold_time = 1.6 if bowl_placed and not slip_applied else 0.0

# --- Usable delegate (the statue itself) -----------------------------------------------

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if Quest.is_at(&"place_bowl"):
		return tr("PROMPT_PLACE_BOWL") if p != null and p.inventory.has_item(&"clay_bowl") else ""
	if Quest.is_at(&"apply_slip"):
		return tr("PROMPT_APPLY_SLIP")
	if Quest.is_at(&"finish_statue"):
		return tr("PROMPT_SET_JOINT") if p != null and p.inventory.has_item(&"chisel") else tr("PROMPT_NEED_CHISEL")
	return ""

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if p == null:
		return false
	if Quest.is_at(&"place_bowl"):
		return p.inventory.has_item(&"clay_bowl")
	if Quest.is_at(&"apply_slip"):
		return bowl_placed
	if Quest.is_at(&"finish_statue"):
		return p.inventory.has_item(&"chisel")
	return false

func usable_show_blocked(_user: Node) -> bool:
	return Quest.is_at(&"finish_statue")

func usable_use(user: Node) -> void:
	var p := user as Player
	if Quest.is_at(&"place_bowl"):
		p.inventory.remove(&"clay_bowl")
		bowl_placed = true
		_refresh()
		Sfx.play_at(SLIP_SOUND, global_position, -4.0)
		Quest.complete(&"place_bowl")
	elif Quest.is_at(&"finish_statue"):
		_strike(p)

func usable_hold_tick(_user: Node, progress: float) -> void:
	if Quest.is_at(&"apply_slip"):
		_set_wetness(progress)
	if int(progress * 10.0) % 3 == 0 and randf() < 0.15:
		Sfx.play_at(SLIP_SOUND, global_position + Vector3.UP, -14.0, 0.15)

func usable_hold_cancelled(_user: Node) -> void:
	if not slip_applied:
		create_tween().tween_method(_set_wetness, _wetness, 0.0, 0.6)

func usable_hold_done(user: Node) -> void:
	if not Quest.is_at(&"apply_slip"):
		return
	slip_applied = true
	_refresh()
	var p := user as Player
	# The chisel "rolls off the bench" — it's under the table now.
	if p != null and p.inventory.has_item(&"chisel"):
		Quest.complete(&"apply_slip")
		Quest.complete(&"find_chisel")
	else:
		Quest.complete(&"apply_slip")
	Dialogue.play(&"slip_applied")

func _strike(p: Player) -> void:
	strikes += 1
	p.viewmodel.call(&"play_use")
	Sfx.play_random_at(STRIKE_SOUNDS, global_position + Vector3.UP * 1.2, -2.0, 0.08)
	Stealth.make_noise(global_position, 6.0, p)
	var legs := _legs()
	var joint := (legs.global_transform * legs.get_aabb()).get_center() + Vector3.UP * 0.6 if legs != null else global_position + Vector3.UP * 1.5
	_burst(joint, 14 if strikes < STRIKES_NEEDED else 40, strikes >= STRIKES_NEEDED)
	p.add_shake(0.12)
	if strikes >= STRIKES_NEEDED:
		_refresh()
		Dialogue.play(&"statue_done")
		Quest.complete(&"finish_statue")

## Clay chips (and on the last strike a cloud of dust) from the joint.
func _burst(at: Vector3, amount: int, dust: bool) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 2.2 if dust else 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 1.2 if dust else 1.8
	pm.initial_velocity_max = 2.6 if dust else 3.6
	pm.gravity = Vector3(0, -2.0 if dust else -9.8, 0)
	pm.damping_min = 1.5 if dust else 0.0
	pm.damping_max = 3.0 if dust else 0.5
	pm.scale_min = 0.6
	pm.scale_max = 1.6 if dust else 1.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.45 if dust else 0.07)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.42, 0.28, 0.3 if dust else 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if dust else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	p.draw_pass_1 = quad
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)

func persist_save() -> Dictionary:
	return {"bowl": bowl_placed, "slip": slip_applied, "strikes": strikes}

func persist_load(data: Dictionary) -> void:
	bowl_placed = bool(data.get("bowl", false))
	slip_applied = bool(data.get("slip", false))
	strikes = int(data.get("strikes", 0))
	_refresh()
