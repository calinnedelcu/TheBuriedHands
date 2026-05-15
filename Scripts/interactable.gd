class_name Interactable
extends Node

@export var prompt_text: String = "Folosește"
@export var enabled: bool = true
@export var one_shot: bool = false
## Daca true, interactiunea se face tinand apasata tasta E. `interact()` devine no-op;
## se foloseste `interact_held(by, dt)` apelat per frame din interaction.gd.
@export var hold_action: bool = false
## Daca true, interactiunea este de tip pickup si necesita tasta F (nu E).
@export var is_pickup: bool = false

signal interacted(by: Node)
signal held(by: Node, dt: float)

var _used: bool = false

func get_prompt(_by: Node) -> String:
	return prompt_text

func can_interact(_by: Node) -> bool:
	return enabled and not (one_shot and _used)

func interact(by: Node) -> void:
	if not can_interact(by):
		return
	if hold_action:
		return  # hold-type — se foloseste interact_held
	_used = true
	interacted.emit(by)

func interact_held(by: Node, dt: float) -> void:
	if not can_interact(by) or not hold_action:
		return
	held.emit(by, dt)

# Re-arms a one_shot interactable, e.g. when a pickup was refused (inventory full).
func reset() -> void:
	_used = false
