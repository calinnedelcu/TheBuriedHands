@icon("res://assets/editor/route.svg")
class_name StoryTrigger
extends Area3D
## Fires once when the player walks in: plays a line or sequence, sets a flag
## and/or completes a quest step. Gate it with `quest_step` / `quest_from`.

signal triggered

@export var quest_step: StringName = &""
@export var quest_from: StringName = &""
@export var completes_step: StringName = &""
@export var dialogue: StringName = &""
@export var sets_flag: StringName = &""
## Opens this chapter (its title card) when fired; 0 = none.
@export var chapter := 0
@export var once := true

var fired := false

func _ready() -> void:
	add_to_group(&"persistent")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Co-op: the host's story; the apprentice's machine hears it has fired.
	if not (body is Player) or (once and fired) or Net.is_client():
		return
	if quest_step != &"" and not Quest.is_at(quest_step):
		return
	if quest_from != &"" and not Quest.has_reached(quest_from):
		return
	Net.mirror(self, &"net_fire")
	net_fire()

func net_fire() -> void:
	fired = true
	triggered.emit()
	if chapter > 0:
		Game.start_chapter(chapter)
	Story.fire(completes_step, dialogue, sets_flag)

func persist_save() -> Dictionary:
	return {"fired": fired}

func persist_load(data: Dictionary) -> void:
	fired = bool(data.get("fired", false))
