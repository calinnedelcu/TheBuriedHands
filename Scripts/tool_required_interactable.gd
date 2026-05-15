class_name ToolRequiredInteractable
extends Interactable

## An interactable that is only usable while the player has a specific item
## selected as the active inventory slot.

@export var required_item_id: String = ""
@export var success_prompt: String = ""
@export var failure_prompt: String = ""

func get_prompt(by: Node) -> String:
	if required_item_id == "":
		return prompt_text
	var inv := _get_inventory(by)
	if inv == null:
		return prompt_text
	if _has_required_tool(inv):
		return success_prompt if success_prompt != "" else prompt_text
	return failure_prompt if failure_prompt != "" else prompt_text

func can_interact(by: Node) -> bool:
	if not super.can_interact(by):
		return false
	if required_item_id == "":
		return true
	var inv := _get_inventory(by)
	if inv == null:
		return false
	return _has_required_tool(inv)

func _has_required_tool(inv: Node) -> bool:
	return inv.has_method("current_item_id") and inv.current_item_id() == required_item_id

func _get_inventory(by: Node) -> Node:
	if by == null:
		return null
	var n: Node = by
	while n != null:
		var inv: Node = n.get_node_or_null("Inventory")
		if inv != null:
			return inv
		if n.is_in_group("player"):
			break
		n = n.get_parent()
	var player_node: Node = by.get_tree().get_first_node_in_group("player")
	return player_node.get_node_or_null("Inventory") if player_node else null
