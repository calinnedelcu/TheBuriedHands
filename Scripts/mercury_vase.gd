class_name MercuryVase
extends Node3D

@export var pickup_prompt: String = "Ia vaza de mercur"

@onready var _body: Node3D = get_node_or_null("Body")
@onready var _pickup_body: StaticBody3D = get_node_or_null("PickupBody")
@onready var _pickup_collider: CollisionShape3D = get_node_or_null("PickupBody/PickupCollider")
@onready var _interactable: Interactable = get_node_or_null("PickupBody/Interactable")

var is_filled: bool = false
var is_held: bool = false

func _ready() -> void:
	add_to_group("mercury_vase")
	if _interactable != null:
		_interactable.prompt_text = pickup_prompt
		_interactable.is_pickup = true
		_interactable.interacted.connect(_on_pickup)

func _on_pickup(by: Node) -> void:
	if is_held:
		return
	if get_tree().get_nodes_in_group("mercury_vase_held").size() > 0:
		return
	is_held = true
	add_to_group("mercury_vase_held")
	_set_in_world(false)
	var player := _resolve_player(by)
	if player != null and player.has_method("play_feedback_sfx"):
		player.play_feedback_sfx("pickup")

func fill() -> void:
	is_filled = true

func empty() -> void:
	is_filled = false

func drop_at(pos: Vector3) -> void:
	is_held = false
	remove_from_group("mercury_vase_held")
	global_position = pos
	_set_in_world(true)

func _set_in_world(in_world: bool) -> void:
	if _body != null:
		_body.visible = in_world
	if _pickup_body != null:
		_pickup_body.collision_layer = 1 if in_world else 0
	if _pickup_collider != null:
		_pickup_collider.disabled = not in_world
	if _interactable != null:
		_interactable.enabled = in_world

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null
