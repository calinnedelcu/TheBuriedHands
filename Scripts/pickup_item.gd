@tool
class_name PickupItem
extends Node3D

const ToolVisualsLib = preload("res://Scripts/tool_visuals.gd")

enum PickupKind { SLOT, LAMP_OIL }

signal picked_up(kind: int, value: int)

@export var kind: PickupKind = PickupKind.SLOT
@export var item_id: String = "chisel"
@export var stack: int = 1
@export var oil_amount: float = 35.0
@export_multiline var custom_prompt: String = ""

@onready var _interactable: Interactable = get_node_or_null("Interactable")
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")
@onready var _glow: OmniLight3D = get_node_or_null("Glow")

var _editor_preview_signature: String = ""

const ITEM_LABELS := {
	"chisel": "Ridică dalta",
	"wedge": "Ridică pana de lemn",
	"ceramic": "Ridică cioburile de ceramică",
	"hammer": "Ridică ciocanul",
	"wax_tablet": "Ridică tăblița de ceară",
	"lamp": "Ridică lampa",
}

func _ready() -> void:
	_refresh_visual()
	if _interactable == null:
		return
	_interactable.prompt_text = _resolve_prompt()
	if Engine.is_editor_hint():
		return
	_interactable.interacted.connect(_on_interacted)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		if kind == PickupKind.LAMP_OIL and _interactable != null:
			_interactable.prompt_text = _resolve_lamp_oil_prompt_runtime()
		return
	var signature: String = "%d:%s:%d" % [kind, item_id, stack]
	if signature == _editor_preview_signature:
		return
	_editor_preview_signature = signature
	_refresh_visual()
	if _interactable != null:
		_interactable.prompt_text = _resolve_prompt()

func _resolve_prompt() -> String:
	if custom_prompt != "":
		return custom_prompt
	match kind:
		PickupKind.SLOT:
			return ITEM_LABELS.get(item_id, ToolVisualsLib.pickup_prompt_for_item_id(item_id))
		PickupKind.LAMP_OIL:
			return "Reumple lampa cu ulei"
	return "Ridică"

func _resolve_lamp_oil_prompt_runtime() -> String:
	if custom_prompt != "":
		return custom_prompt
	var player_node := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player_node == null:
		return "Reumple lampa cu ulei"
	var inv: Node = player_node.get_node_or_null("Inventory")
	var active_lamp: Node = inv.call("active_lamp") if inv != null and inv.has_method("active_lamp") else null
	if active_lamp == null:
		var held_lamp: Node = inv.call("find_lamp") if inv != null and inv.has_method("find_lamp") else _find_player_lamp(player_node)
		return "Selectează lampa cu Z" if held_lamp != null else "Ai nevoie de o lampă"
	var current_oil = active_lamp.get("oil_level")
	var max_oil = active_lamp.get("oil_max")
	if current_oil != null and max_oil != null and float(current_oil) >= float(max_oil) - 0.01:
		return "Lampă plină"
	return "Reumple lampa cu ulei"

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return by.get_tree().get_first_node_in_group("player") if by else null

func _on_interacted(by: Node) -> void:
	var player_node: Node = _resolve_player(by)
	if player_node == null:
		return
	var inv: Node = player_node.get_node_or_null("Inventory")
	match kind:
		PickupKind.SLOT:
			if inv != null and inv.has_method("add_item"):
				var idx: int = inv.add_item(item_id, null, stack)
				if idx < 0:
					return  # inventory full — leave the pickup in the world
			if player_node.has_method("play_feedback_sfx"):
				player_node.call("play_feedback_sfx", "pickup")
			picked_up.emit(kind, stack)
		PickupKind.LAMP_OIL:
			var lamp: Node = inv.call("active_lamp") if inv != null and inv.has_method("active_lamp") else null
			if lamp == null and inv == null:
				lamp = _find_player_lamp(player_node)
			if lamp == null or not lamp.has_method("refill"):
				return
			lamp.refill(oil_amount)
			if player_node.has_method("play_feedback_sfx"):
				player_node.call("play_feedback_sfx", "refill")
			picked_up.emit(kind, int(oil_amount))
	queue_free()

func _refresh_visual() -> void:
	_clear_preview_visual()
	if kind != PickupKind.SLOT:
		if _mesh != null:
			_mesh.visible = true
		return
	var visual := ToolVisualsLib.build_for_item_id(item_id, false)
	if visual == null:
		if _mesh != null:
			_mesh.visible = true
		return
	if _mesh != null:
		_mesh.visible = false
	visual.name = "PickupVisual"
	visual.set_meta("pickup_preview_visual", true)
	add_child(visual)
	if _glow != null:
		_glow.light_color = ToolVisualsLib.glow_color_for_item_id(item_id)

func _clear_preview_visual() -> void:
	for child in get_children():
		if child.name == "PickupVisual" or child.has_meta("pickup_preview_visual"):
			child.free()

func _find_player_lamp(player_node: Node) -> Node:
	if player_node == null:
		return null
	var lamp_node := player_node.get_node_or_null("CameraPivot/Camera3D/ViewmodelRig/LampSocket/OilLamp")
	if lamp_node != null:
		return lamp_node
	return player_node.get_tree().get_first_node_in_group("lamp") if player_node.is_inside_tree() else null
