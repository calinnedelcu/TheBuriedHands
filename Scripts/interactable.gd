class_name Interactable
extends Node

@export var prompt_text: String = "Folosește"
@export var enabled: bool = true
@export var one_shot: bool = false

signal interacted(by: Node)

var _used: bool = false

func get_prompt(_by: Node) -> String:
	return prompt_text

func can_interact(_by: Node) -> bool:
	return enabled and not (one_shot and _used)

func interact(by: Node) -> void:
	if not can_interact(by):
		return
	_used = true
	interacted.emit(by)
