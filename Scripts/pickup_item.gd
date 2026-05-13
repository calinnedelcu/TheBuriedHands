class_name PickupItem
extends Node3D

enum PickupKind { SLOT, CERAMIC_CHARGE, LAMP_OIL }

signal picked_up(kind: int, value: int)

@export var kind: PickupKind = PickupKind.SLOT
@export var grants_slot: int = 1
@export var ceramic_amount: int = 3
@export var oil_amount: float = 35.0
@export_multiline var custom_prompt: String = ""

@onready var _interactable: Interactable = get_node_or_null("Interactable")

const SLOT_LABELS := {
	1: "Ridică dalta",
	2: "Ridică pana de lemn",
	3: "Ridică cioburile de ceramică",
	4: "Ridică tăblița de ceară",
}

func _ready() -> void:
	if _interactable == null:
		return
	_interactable.prompt_text = _resolve_prompt()
	_interactable.interacted.connect(_on_interacted)

func _resolve_prompt() -> String:
	if custom_prompt != "":
		return custom_prompt
	match kind:
		PickupKind.SLOT:
			return SLOT_LABELS.get(grants_slot, "Ridică")
		PickupKind.CERAMIC_CHARGE:
			return "Ridică cioburi de ceramică"
		PickupKind.LAMP_OIL:
			return "Reumple lampa cu ulei"
	return "Ridică"

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return by.get_tree().get_first_node_in_group("player") if by else null

func _on_interacted(by: Node) -> void:
	var player_node: Node = _resolve_player(by)
	var inv: Node = player_node.get_node_or_null("Inventory") if player_node else null
	if player_node == null:
		return
	by = player_node
	match kind:
		PickupKind.SLOT:
			if inv and inv.has_method("acquire"):
				inv.acquire(grants_slot)
			picked_up.emit(kind, grants_slot)
		PickupKind.CERAMIC_CHARGE:
			if inv and inv.has_method("add_ceramic"):
				inv.add_ceramic(ceramic_amount)
			if inv and inv.has_method("acquire"):
				inv.acquire(3)
			picked_up.emit(kind, ceramic_amount)
		PickupKind.LAMP_OIL:
			var lamp: Node = by.get_node_or_null("CameraPivot/Camera3D/ViewmodelRig/LampSocket/OilLamp") if by else null
			if lamp and lamp.has_method("refill"):
				lamp.refill(oil_amount)
			picked_up.emit(kind, int(oil_amount))
	queue_free()
