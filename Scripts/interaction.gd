extends RayCast3D

signal prompt_changed(text: String)

@export var player_path: NodePath
@onready var _player: Node = get_node_or_null(player_path) if not player_path.is_empty() else get_parent()

var _current: Interactable = null
var _current_text: String = ""

func _physics_process(_delta: float) -> void:
	force_raycast_update()
	var found: Interactable = _find_interactable()
	if found != _current:
		_current = found
		_emit_prompt(_current.get_prompt(_player) if _current else "")
	elif _current:
		var t := _current.get_prompt(_player)
		if t != _current_text:
			_emit_prompt(t)

func try_interact() -> bool:
	if _current == null or not _current.can_interact(_player):
		return false
	_current.interact(_player)
	return true

func _find_interactable() -> Interactable:
	if not is_colliding():
		return null
	var hit: Object = get_collider()
	if hit == null:
		return null
	if hit is Node:
		var n: Node = hit
		# Search self + ancestors for an Interactable child
		while n != null:
			for c in n.get_children():
				if c is Interactable and (c as Interactable).can_interact(_player):
					return c as Interactable
			n = n.get_parent()
	return null

func _emit_prompt(t: String) -> void:
	_current_text = t
	prompt_changed.emit(t)
