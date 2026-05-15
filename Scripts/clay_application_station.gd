class_name ClayApplicationStation
extends Interactable

## Multi-cycle station where the player alternates between holding the
## clay_slip (apply, hold E) and the chisel (set the joint, tap E).
## After `total_cycles` complete cycles the station finishes and advances the
## quest objective to whatever is configured in `objective_after_id`.

@export_group("Objective")
@export var required_objective_id: String = ""
@export var objective_after_id: String = ""
@export_multiline var objective_after_text: String = ""
## Objective set after each chisel tap that completes a cycle, sending the
## player back to the bowl to scoop more slip (empty = no objective set).
@export var refill_objective_id: String = ""
@export_multiline var refill_objective_text: String = ""
## Objective set after the very first slip apply if the player does not yet
## have a chisel in inventory — sends them to fetch one before they can tap.
@export var chisel_retrieve_objective_id: String = "retrieve_chisel"
@export_multiline var chisel_retrieve_objective_text: String = ""

@export_group("Cycle")
@export var total_cycles: int = 3
@export var slip_hold_duration: float = 1.0

@export_group("Visual")
@export var applied_visual_path: NodePath

@export_group("Prompts")
@export var apply_slip_prompt: String = "Aplică barbotina (ține E)"
@export var tap_chisel_prompt: String = "Bate cu dalta (apasă E)"
@export var need_slip_hint: String = "Selectează barbotina"
@export var need_chisel_hint: String = "Selectează dalta"

@export_group("Dialogues")
@export_multiline var apply_dialogue: String = ""
@export_multiline var chisel_dialogue: String = ""
@export_multiline var done_dialogue: String = ""

var _cycle: int = 0
var _stage: int = 0  # 0 = needs slip apply, 1 = needs chisel tap
var _hold_progress: float = 0.0

func _ready() -> void:
	hold_action = true

func get_prompt(by: Node) -> String:
	if _cycle >= total_cycles:
		return ""
	var item := _current_item_id(by)
	if _stage == 0:
		return apply_slip_prompt if item == "clay_slip" else need_slip_hint
	return tap_chisel_prompt if item == "chisel" else need_chisel_hint

func can_interact(_by: Node) -> bool:
	if not enabled or (one_shot and _used):
		return false
	if _cycle >= total_cycles:
		return false
	if required_objective_id == "":
		return true
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null or not objectives.has_method("current_id"):
		return false
	return str(objectives.call("current_id")) == required_objective_id

func interact(by: Node) -> void:
	if not can_interact(by) or _stage != 1:
		return
	if _current_item_id(by) != "chisel":
		return
	_do_chisel_tap(by)

func interact_held(by: Node, dt: float) -> void:
	if not can_interact(by) or _stage != 0:
		_hold_progress = 0.0
		return
	if _current_item_id(by) != "clay_slip":
		_hold_progress = 0.0
		return
	_hold_progress += dt
	if _hold_progress >= slip_hold_duration:
		_hold_progress = 0.0
		_do_slip_apply(by)

func _do_slip_apply(by: Node) -> void:
	var inv := _inventory(by)
	if inv == null or not inv.has_method("remove_item"):
		return
	inv.call("remove_item", "clay_slip")
	_stage = 1
	hold_action = false
	_show_applied_visual()
	_show_dialogue(apply_dialogue)
	if chisel_retrieve_objective_text != "" and not _player_has_chisel(by):
		_set_objective(chisel_retrieve_objective_id, chisel_retrieve_objective_text)

func _player_has_chisel(by: Node) -> bool:
	var inv := _inventory(by)
	if inv == null or not inv.has_method("has_item"):
		return false
	return bool(inv.call("has_item", "chisel"))

func _do_chisel_tap(by: Node) -> void:
	_cycle += 1
	_stage = 0
	hold_action = true
	if _cycle >= total_cycles:
		_show_dialogue(done_dialogue)
		_finish()
		return
	_show_dialogue(chisel_dialogue)
	_set_objective(refill_objective_id, refill_objective_text)

func _finish() -> void:
	enabled = false
	_set_objective(objective_after_id, objective_after_text)

func _show_applied_visual() -> void:
	if applied_visual_path.is_empty():
		return
	var v := get_node_or_null(applied_visual_path)
	if v is Node3D:
		(v as Node3D).visible = true

func _show_dialogue(text: String) -> void:
	if text == "":
		return
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("show_dialogue"):
		events.call("show_dialogue", text, 3.5)

func _set_objective(id: String, text: String) -> void:
	if text == "":
		return
	var objectives := get_node_or_null("/root/Objectives")
	if objectives != null and objectives.has_method("set_objective"):
		objectives.call("set_objective", id, text)

func _current_item_id(by: Node) -> String:
	var inv := _inventory(by)
	if inv == null or not inv.has_method("current_item_id"):
		return ""
	return str(inv.call("current_item_id"))

func _inventory(by: Node) -> Node:
	var player_node := _resolve_player(by)
	return player_node.get_node_or_null("Inventory") if player_node != null else null

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null
