class_name QuestStepInteractable
extends Interactable

@export var required_objective_id: String = ""
@export var objective_after_id: String = ""
@export_multiline var objective_after_text: String = ""
@export_multiline var dialogue_text: String = ""
@export var dialogue_duration: float = 4.0
@export var disable_after_interact: bool = true
## Daca true, sterge nodul parinte (StaticBody3D) dupa interactiune — util cand un
## pickup inline trebuie sa dispara complet din lume (ex. re-ridicarea bolului).
@export var free_parent_on_interact: bool = false

@export_group("Visual Changes")
@export var hide_node_on_interact: NodePath
@export var show_node_on_interact: NodePath
@export var carried_scene: PackedScene
@export var carried_node_name: String = ""
@export var carried_transform: Transform3D = Transform3D.IDENTITY
@export var clear_carried_node_name: String = ""

@export_group("Inventory")
@export var inventory_add_id: String = ""
@export var inventory_remove_id: String = ""

func can_interact(by: Node) -> bool:
	if not super.can_interact(by):
		return false
	if required_objective_id == "":
		return true
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null or not objectives.has_method("current_id"):
		return false
	return str(objectives.call("current_id")) == required_objective_id

func interact(by: Node) -> void:
	if not can_interact(by):
		return
	_used = true
	interacted.emit(by)
	_apply_visual_changes(by)
	if dialogue_text != "":
		var events := get_node_or_null("/root/GameEvents")
		if events != null and events.has_method("show_dialogue"):
			events.show_dialogue(dialogue_text, dialogue_duration)
	if objective_after_text != "":
		var objectives := get_node_or_null("/root/Objectives")
		if objectives != null and objectives.has_method("set_objective"):
			objectives.set_objective(objective_after_id, objective_after_text)
	if disable_after_interact:
		enabled = false
	if free_parent_on_interact:
		var p := get_parent()
		if p != null:
			p.queue_free()

func _apply_visual_changes(by: Node) -> void:
	_set_node_visible(hide_node_on_interact, false)
	_set_node_visible(show_node_on_interact, true)
	var player_node := _resolve_player(by)
	if player_node != null:
		_clear_carried(player_node, clear_carried_node_name)
		_spawn_carried(player_node)
		_apply_inventory_changes(player_node)

func _apply_inventory_changes(player_node: Node) -> void:
	if inventory_add_id == "" and inventory_remove_id == "":
		return
	var inv := player_node.get_node_or_null("Inventory")
	if inv == null:
		return
	if inventory_remove_id != "" and inv.has_method("remove_item"):
		inv.call("remove_item", inventory_remove_id)
	if inventory_add_id != "" and inv.has_method("add_item"):
		inv.call("add_item", inventory_add_id)

func _set_node_visible(path: NodePath, is_visible: bool) -> void:
	if str(path) == "":
		return
	var node := get_node_or_null(path)
	if node is Node3D:
		(node as Node3D).visible = is_visible
	elif node is CanvasItem:
		(node as CanvasItem).visible = is_visible

func _spawn_carried(player_node: Node) -> void:
	if carried_scene == null or carried_node_name == "":
		return
	var socket := _find_tool_socket(player_node)
	if socket == null:
		return
	_clear_carried(player_node, carried_node_name)
	var visual := carried_scene.instantiate()
	if visual == null:
		return
	visual.name = carried_node_name
	socket.add_child(visual)
	if visual is Node3D:
		(visual as Node3D).transform = carried_transform

func _clear_carried(player_node: Node, node_name: String) -> void:
	if node_name == "":
		return
	var socket := _find_tool_socket(player_node)
	if socket == null:
		return
	var existing := socket.get_node_or_null(node_name)
	if existing != null:
		existing.queue_free()

func _find_tool_socket(player_node: Node) -> Node3D:
	var direct := player_node.get_node_or_null("CameraPivot/Camera3D/ViewmodelRig/ToolSocket") as Node3D
	if direct != null:
		return direct
	return _find_child_by_name(player_node, "ToolSocket") as Node3D

func _find_child_by_name(root: Node, wanted_name: String) -> Node:
	for child in root.get_children():
		if child.name == wanted_name:
			return child
		var nested := _find_child_by_name(child, wanted_name)
		if nested != null:
			return nested
	return null

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null
