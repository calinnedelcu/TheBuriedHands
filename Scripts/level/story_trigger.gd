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
## A hint (a string key) shown once as a note on screen, if hints are on.
@export var hint := ""
## Saves a checkpoint where it fires (mid-step: the start of a hard stretch).
@export var checkpoint := false
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
	if hint != "" and Settings.get_value(&"show_hints"):
		var player := get_tree().get_first_node_in_group(&"player") as Player
		var hud := player.get_node_or_null("HUD") if player != null else null
		if hud != null and hud.has_method(&"toast"):
			hud.call(&"toast", InputHint.format(tr(hint)))
	if checkpoint:
		Game.request_checkpoint(Quest.current())

func persist_save() -> Dictionary:
	return {"fired": fired}

func persist_load(data: Dictionary) -> void:
	fired = bool(data.get("fired", false))
