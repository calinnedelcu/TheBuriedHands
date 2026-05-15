extends RayCast3D

signal prompt_changed(text: String, key: String)

@export var player_path: NodePath
@export var prompt_linger_time: float = 0.08
@onready var _player: Node = get_node_or_null(player_path) if not player_path.is_empty() else get_parent()

var _current: Interactable = null
var _current_text: String = ""
var _current_key: String = ""
var _linger_timer: float = 0.0

func _physics_process(delta: float) -> void:
	force_raycast_update()
	var found: Interactable = _find_interactable()
	var candidate: Interactable = found
	if found != null:
		_linger_timer = prompt_linger_time
	elif _current != null and _linger_timer > 0.0 and _current.can_interact(_player):
		_linger_timer -= delta
		candidate = _current
	else:
		_linger_timer = 0.0

	var prompt: String = ""
	var key: String = ""
	if candidate != null:
		prompt = candidate.get_prompt(_player)
		if candidate.is_pickup:
			key = "F"
		else:
			key = "E"
	else:
		prompt = _fallback_prompt()
		if prompt != "":
			key = "X"
	if candidate != _current or prompt != _current_text or key != _current_key:
		_current = candidate
		_emit_prompt(prompt, key)

## E apasat — interactiune press normala (lever, switch, etc).
## Returneaza false daca interactabilul curent e pickup sau hold-only.
func try_interact() -> bool:
	if _current == null or not _current.can_interact(_player):
		return false
	if _current.is_pickup:
		return false
	if _current.hold_action:
		return false
	_current.interact(_player)
	return true

## F apasat — pickup. Functioneaza doar daca interactabilul curent este pickup.
func try_pickup() -> bool:
	if _current == null or not _current.can_interact(_player):
		return false
	if not _current.is_pickup:
		return false
	_current.interact(_player)
	return true

## Apelat in fiecare frame cat timp tasta `interact` este tinuta apasata.
## Are efect doar daca interactiunea curenta are `hold_action = true`.
func try_interact_hold(dt: float) -> void:
	if _current == null or not _current.hold_action:
		return
	if not _current.can_interact(_player):
		return
	_current.interact_held(_player, dt)

func current_debug_text() -> String:
	if _current != null:
		return "%s [%s]" % [_current.name, _current_text]
	if _current_text != "":
		return "fallback [%s]" % _current_text
	return "-"

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

func _emit_prompt(t: String, key: String) -> void:
	_current_text = t
	_current_key = key
	prompt_changed.emit(t, key)

func _fallback_prompt() -> String:
	if _player != null and _player.has_method("get_fallback_interaction_prompt"):
		return _player.get_fallback_interaction_prompt()
	return ""
