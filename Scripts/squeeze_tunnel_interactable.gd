class_name SqueezeTunnelInteractable
extends Interactable

@export var mechanism_path: NodePath = NodePath("..")

func _ready() -> void:
	hold_action = false
	is_pickup = false

func get_prompt(by: Node) -> String:
	var mechanism := _mechanism()
	if mechanism != null and mechanism.has_method("get_squeeze_prompt"):
		return str(mechanism.call("get_squeeze_prompt", by))
	return prompt_text

func can_interact(by: Node) -> bool:
	var mechanism := _mechanism()
	if mechanism != null and mechanism.has_method("can_squeeze_interact"):
		return bool(mechanism.call("can_squeeze_interact", by))
	return super.can_interact(by)

func interact(by: Node) -> void:
	var mechanism := _mechanism()
	if mechanism != null and mechanism.has_method("squeeze_tap"):
		mechanism.call("squeeze_tap", by)
		return
	super.interact(by)

func _mechanism() -> Node:
	if mechanism_path.is_empty():
		return get_parent()
	return get_node_or_null(mechanism_path)
