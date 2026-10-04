@tool
class_name Pickup
extends StaticBody3D
## An item lying in the world. Taking it adds it to the inventory and can move
## the story along. Level-placed pickups are persistent: once taken they stay
## taken when a checkpoint is reloaded.

@export var item_id: StringName = &"chisel":
	set(value):
		item_id = value
		if is_node_ready():
			_build_visual()
@export_range(1, 12) var count := 1

@export_group("Story")
## Only takeable while the quest is at this step (empty = always).
@export var quest_step: StringName = &""
## Only takeable once the quest has reached this step.
@export var quest_from: StringName = &""
@export var completes_step: StringName = &""
@export var dialogue: StringName = &""
@export var sets_flag: StringName = &""

@onready var _usable: Usable = $Usable
@onready var _visual_root: Node3D = $Visual

var taken := false

func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	collision_layer = 16
	collision_mask = 0
	_usable.quest_step = quest_step
	_usable.quest_from = quest_from
	_usable.used.connect(_on_used)
	_usable.block_reason = _why_not
	var item := ItemDB.get_item(item_id)
	if item != null:
		_usable.prompt_args = {"item": item.display_name()}

## Tools are carried one of each, and a full pair of hands can't take more.
func _why_not(user: Node) -> String:
	var player := user as Player
	var item := ItemDB.get_item(item_id)
	if player == null or item == null or item.key_item:
		return ""
	if item.max_stack == 1 and player.inventory.has_item(item_id):
		return "PICKUP_ALREADY_HAVE"
	if not player.inventory.has_room_for(item_id, 1):
		return "PICKUP_HANDS_FULL"
	return ""

func _on_used(user: Node) -> void:
	var player := user as Player
	if player == null or taken:
		return
	if not player.inventory.add(item_id, count):
		return
	var item := ItemDB.get_item(item_id)
	if item != null and item.pickup_sound != null:
		Sfx.play_at(item.pickup_sound, global_position, -6.0)
	else:
		Sfx.play_at(preload("res://audio/sfx/impacts/cloth2.ogg"), global_position, -10.0)
	_set_taken(true)
	Story.fire(completes_step, dialogue, sets_flag)

func _set_taken(value: bool) -> void:
	taken = value
	visible = not value
	_usable.enabled = not value
	collision_layer = 0 if value else 16

func _build_visual() -> void:
	if _visual_root == null:
		_visual_root = get_node_or_null("Visual")
	if _visual_root == null:
		return
	for c in _visual_root.get_children():
		c.free()
	var item := ItemDB.get_item(item_id)
	if item == null or item.world_scene == null:
		return
	_visual_root.add_child(item.world_scene.instantiate())

func persist_save() -> Dictionary:
	return {"taken": taken}

func persist_load(data: Dictionary) -> void:
	_set_taken(bool(data.get("taken", false)))
