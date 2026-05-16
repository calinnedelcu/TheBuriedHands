extends RayCast3D

signal prompt_changed(text: String, key: String)

@export var player_path: NodePath
@export var prompt_linger_time: float = 0.08
@onready var _player: Node = get_node_or_null(player_path) if not player_path.is_empty() else get_parent()

var _current_interact: Interactable = null
var _current_pickup: Interactable = null
var _current_text: String = ""
var _current_key: String = ""
var _linger_timer: float = 0.0
var _lingering_for_interact: bool = true

func _physics_process(delta: float) -> void:
	force_raycast_update()
	var result: Dictionary = _find_interactables()
	var found_interact: Interactable = result.get("interact", null)
	var found_pickup: Interactable = result.get("pickup", null)

	if found_interact != null or found_pickup != null:
		_linger_timer = prompt_linger_time
	elif _linger_timer > 0.0:
		var linger_target := _current_interact if _lingering_for_interact else _current_pickup
		if linger_target != null and linger_target.can_interact(_player):
			_linger_timer -= delta
			if _lingering_for_interact:
				_current_pickup = null
			else:
				_current_interact = null
		else:
			_linger_timer = 0.0
	else:
		_linger_timer = 0.0

	_current_interact = found_interact
	_current_pickup = found_pickup
	_lingering_for_interact = (found_interact != null)

	var prompt: String = ""
	var key: String = ""
	var candidate: Interactable = null
	if _current_pickup != null:
		prompt = _current_pickup.get_prompt(_player)
		key = "F"
		candidate = _current_pickup
	elif _current_interact != null:
		prompt = _current_interact.get_prompt(_player)
		key = "E"
		candidate = _current_interact
	else:
		prompt = _fallback_prompt()
		if prompt != "":
			key = "X"
	if prompt != _current_text or key != _current_key:
		_current_text = prompt
		_current_key = key
		_emit_prompt(prompt, key)

func try_interact() -> bool:
	if _current_interact == null or not _current_interact.can_interact(_player):
		return false
	if _current_interact.hold_action:
		return false
	_current_interact.interact(_player)
	return true

func try_pickup() -> bool:
	if _current_pickup == null or not _current_pickup.can_interact(_player):
		return false
	_current_pickup.interact(_player)
	return true

func try_interact_hold(dt: float) -> void:
	if _current_interact == null or not _current_interact.hold_action:
		return
	if not _current_interact.can_interact(_player):
		return
	_current_interact.interact_held(_player, dt)

func current_debug_text() -> String:
	if _current_pickup != null:
		return "%s [%s]" % [_current_pickup.name, _current_text]
	if _current_interact != null:
		return "%s [%s]" % [_current_interact.name, _current_text]
	if _current_text != "":
		return "fallback [%s]" % _current_text
	return "-"

func _find_interactables() -> Dictionary:
	if not is_colliding():
		return {}
	var hit: Object = get_collider()
	if hit == null:
		return {}
	var result := {}
	if hit is Node:
		var n: Node = hit
		var found_pickup: Interactable = null
		var found_interact: Interactable = null
		while n != null:
			for c in n.get_children():
				if c is Interactable and (c as Interactable).can_interact(_player):
					var ia := c as Interactable
					if ia.is_pickup:
						if found_pickup == null:
							found_pickup = ia
					else:
						if found_interact == null:
							found_interact = ia
			n = n.get_parent()
		if found_pickup != null:
			result["pickup"] = found_pickup
		if found_interact != null:
			result["interact"] = found_interact
	return result

func _emit_prompt(t: String, key: String) -> void:
	prompt_changed.emit(t, key)

func _fallback_prompt() -> String:
	if _player != null and _player.has_method("get_fallback_interaction_prompt"):
		return _player.get_fallback_interaction_prompt()
	return ""
