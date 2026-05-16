class_name MercuryVase
extends Node3D

@export var pickup_prompt: String = "Ia vaza de mercur"
@export var body_visual_offset: Vector3 = Vector3(7.152364, -0.499749, -2.631718)
@export var equipped_transform: Transform3D = Transform3D(Basis(), Vector3(0.0, -0.02, -0.08))
@export var hide_when_equipped: bool = true

@onready var _body: Node3D = get_node_or_null("Body")
@onready var _pickup_body: StaticBody3D = get_node_or_null("PickupBody")
@onready var _pickup_collider: CollisionShape3D = get_node_or_null("PickupBody/PickupCollider")
@onready var _interactable: Interactable = get_node_or_null("PickupBody/Interactable")

var is_filled: bool = false
var is_held: bool = false
var _stored: bool = false

func _ready() -> void:
	add_to_group("mercury_vase")
	if _body != null:
		_body.position = body_visual_offset
	if _interactable != null:
		_interactable.prompt_text = pickup_prompt
		_interactable.is_pickup = true
		_interactable.interacted.connect(_on_pickup)

func _process(_delta: float) -> void:
	pass

func _on_pickup(by: Node) -> void:
	if is_held:
		return
	var player := _resolve_player(by)
	var inventory: Node = player.get_node_or_null("Inventory") if player != null else null
	if inventory != null and inventory.has_method("add_item"):
		var slot: int = inventory.call("add_item", "mercury_vase", self)
		if slot < 0:
			return
	else:
		set_equipped(true)
	if player != null and player.has_method("play_feedback_sfx"):
		player.play_feedback_sfx("pickup")

func fill() -> void:
	is_filled = true

func empty() -> void:
	is_filled = false

func drop_at(pos: Vector3) -> void:
	is_held = false
	_stored = false
	remove_from_group("mercury_vase_held")
	_reparent_to_world()
	global_position = pos
	visible = true
	call_deferred("_set_collision", true)

func drop_by_player(player: Node) -> bool:
	if not is_held and not _stored:
		return false
	is_held = false
	_stored = false
	remove_from_group("mercury_vase_held")
	if player != null and player.has_method("get_drop_transform"):
		global_transform = player.get_drop_transform(false)
	else:
		global_position += Vector3(0.6, 0.0, 0.0)
	visible = true
	call_deferred("_set_collision", true)
	return true

func set_equipped(equipped: bool) -> void:
	_stored = false
	is_held = equipped
	if equipped:
		_set_collision(false)
		add_to_group("mercury_vase_held")
		transform = equipped_transform
		visible = not hide_when_equipped
	else:
		remove_from_group("mercury_vase_held")
		_set_collision(true)

func set_stored() -> void:
	_stored = true
	is_held = false
	remove_from_group("mercury_vase_held")
	visible = false
	_set_collision(false)

func _set_collision(enabled: bool) -> void:
	if _pickup_body != null:
		_pickup_body.collision_layer = 1 if enabled else 0
		_pickup_body.collision_mask = 0
		_pickup_body.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if _pickup_collider != null:
		_pickup_collider.disabled = not enabled
	if _interactable != null:
		_interactable.enabled = enabled

func _reparent_to_world() -> void:
	if not is_inside_tree():
		return
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_parent()
	if world == null or get_parent() == world:
		return
	reparent(world, false)

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null
