class_name BreakableInteractable
extends Interactable

## Interactable de tip hold (E tinut) care sparge un blocaj (piatra) cand
## player-ul are toate uneltele cerute in inventar. La completare, ascunde
## nodul-parinte (Node3D) si dezactiveaza coliziile recursiv.
##
## Se ataseaza ca node copil (Node + script) sub blocaj. La break, emite
## semnalul `broken` pentru sfx/vfx externe.

signal broken(blocker: Node)

@export var required_items: PackedStringArray = PackedStringArray(["wedge", "hammer"])
@export var break_time: float = 3.0
## Obiectiv setat dupa spargere.
@export var objective_after_id: String = ""
@export var objective_after_text: String = ""
## Daca true, ascunde nodul-parinte si dezactiveaza toate coliziile din el.
@export var hide_blocker_on_break: bool = true
## Daca true, free-uieste tot subarborele parintelui dupa break (1s delay).
@export var free_blocker_on_break: bool = true
@export var prompt_ready: String = "Ține E ca să spargi piatra"
@export var prompt_missing: String = "Ai nevoie de pană și ciocan"
@export var prompt_progress: String = "Spargi piatra... %d%%"

var _progress: float = 0.0
var _broken: bool = false

func _ready() -> void:
	hold_action = true
	prompt_text = prompt_ready
	held.connect(_on_held)

func get_prompt(by: Node) -> String:
	if _broken:
		return ""
	if not _has_all_required(by):
		return prompt_missing
	if _progress > 0.0:
		var pct: int = int(clamp(_progress / max(0.001, break_time), 0.0, 1.0) * 100.0)
		return prompt_progress % pct
	return prompt_ready

func can_interact(by: Node) -> bool:
	if _broken:
		return false
	return super.can_interact(by)

func interact_held(by: Node, dt: float) -> void:
	if _broken or not can_interact(by) or not hold_action:
		return
	if not _has_all_required(by):
		return
	held.emit(by, dt)

func _on_held(_by: Node, dt: float) -> void:
	if _broken:
		return
	_progress += dt
	if _progress >= break_time:
		_break_now()

func _has_all_required(by: Node) -> bool:
	var inv := _get_inventory(by)
	if inv == null or not inv.has_method("has_item"):
		return false
	for id in required_items:
		if not inv.has_item(id):
			return false
	return true

func _get_inventory(by: Node) -> Node:
	if by == null:
		return null
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			break
		n = n.get_parent()
	if n == null:
		var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		return p.get_node_or_null("Inventory") if p != null else null
	return n.get_node_or_null("Inventory")

func _break_now() -> void:
	_broken = true
	enabled = false
	var blocker := get_parent()
	broken.emit(blocker)
	# Set next objective if configured.
	if objective_after_id != "":
		var objectives := get_node_or_null("/root/Objectives")
		if objectives and objectives.has_method("set_objective"):
			objectives.set_objective(objective_after_id, objective_after_text)
	if not hide_blocker_on_break:
		return
	if blocker is Node3D:
		(blocker as Node3D).visible = false
	_disable_all_colliders_in(blocker)
	if free_blocker_on_break and blocker != null:
		var tree := get_tree()
		if tree != null:
			tree.create_timer(1.0).timeout.connect(func() -> void:
				if is_instance_valid(blocker):
					blocker.queue_free())

func _disable_all_colliders_in(root: Node) -> void:
	if root == null:
		return
	if root is CollisionShape3D:
		(root as CollisionShape3D).set_deferred("disabled", true)
	elif root is CollisionObject3D:
		(root as CollisionObject3D).set_deferred("collision_layer", 0)
		(root as CollisionObject3D).set_deferred("collision_mask", 0)
	for c in root.get_children():
		_disable_all_colliders_in(c)
