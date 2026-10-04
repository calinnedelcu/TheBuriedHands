class_name ClayStatue
extends Node3D
## The unfinished terracotta soldier in the workshop: the tutorial's work.
## Steps: set the bowl on the bench (place_bowl), bind the legs with slip by
## holding the key (apply_slip), then — once the chisel is found — strike the
## joint three times (finish_statue). Each strike is a short tap with a small
## sound and dust puff; the soldier's legs darken as the slip goes on.

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

@onready var _bowl_spot: Node3D = get_node_or_null(bowl_spot_path)
@onready var _placed_bowl: Node3D = get_node_or_null(placed_bowl_path)
@onready var _slip_visual: Node3D = get_node_or_null(slip_visual_path)
@onready var _usable: DelegateUsable = get_node_or_null("Body/Usable")

var bowl_placed := false
var slip_applied := false
var strikes := 0

func _ready() -> void:
	add_to_group(&"persistent")
	_refresh()

func _refresh() -> void:
	if _placed_bowl != null:
		_placed_bowl.visible = bowl_placed
	if _slip_visual != null:
		_slip_visual.visible = slip_applied
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
	if int(progress * 10.0) % 3 == 0 and randf() < 0.15:
		Sfx.play_at(SLIP_SOUND, global_position + Vector3.UP, -14.0, 0.15)

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
	if strikes >= STRIKES_NEEDED:
		Dialogue.play(&"statue_done")
		Quest.complete(&"finish_statue")

func persist_save() -> Dictionary:
	return {"bowl": bowl_placed, "slip": slip_applied, "strikes": strikes}

func persist_load(data: Dictionary) -> void:
	bowl_placed = bool(data.get("bowl", false))
	slip_applied = bool(data.get("slip", false))
	strikes = int(data.get("strikes", 0))
	_refresh()
