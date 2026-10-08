class_name DelegateUsable
extends Usable
## A Usable whose behaviour lives on another node (by default its parent's
## parent, i.e. the object root above the body). The delegate implements any of:
##   usable_prompt(user) -> String        usable_can_use(user) -> bool
##   usable_show_blocked(user) -> bool    usable_use(user)
##   usable_tap(user)                     usable_hold_tick(user, progress)
##   usable_hold_done(user)               usable_hold_cancelled(user)
##   usable_is_hold(user) -> bool         (whether holding does anything for them now)

@export var delegate_path: NodePath = ^"../.."

var _delegate: Node

func _ready() -> void:
	super._ready()
	_delegate = get_node_or_null(delegate_path)

func get_prompt(user: Node) -> String:
	if _delegate != null and _delegate.has_method(&"usable_prompt"):
		return _delegate.call(&"usable_prompt", user)
	return super.get_prompt(user)

func can_use(user: Node) -> bool:
	if not super.can_use(user):
		return false
	if _delegate != null and _delegate.has_method(&"usable_can_use"):
		return _delegate.call(&"usable_can_use", user)
	return true

func is_hold_for(user: Node) -> bool:
	if not is_hold():
		return false
	if _delegate != null and _delegate.has_method(&"usable_is_hold"):
		return bool(_delegate.call(&"usable_is_hold", user))
	return true

func shows_when_blocked(user: Node) -> bool:
	if _delegate != null and _delegate.has_method(&"usable_show_blocked"):
		return _delegate.call(&"usable_show_blocked", user)
	return false

func _on_use(user: Node) -> void:
	if _delegate != null and _delegate.has_method(&"usable_use"):
		_delegate.call(&"usable_use", user)

func _on_tap(user: Node) -> void:
	if _delegate != null and _delegate.has_method(&"usable_tap"):
		_delegate.call(&"usable_tap", user)

func hold_tick(user: Node, progress: float) -> void:
	if _delegate != null and _delegate.has_method(&"usable_hold_tick"):
		_delegate.call(&"usable_hold_tick", user, progress)

func hold_cancelled(user: Node) -> void:
	if _delegate != null and _delegate.has_method(&"usable_hold_cancelled"):
		_delegate.call(&"usable_hold_cancelled", user)

func _on_hold_completed(user: Node) -> void:
	if _delegate != null and _delegate.has_method(&"usable_hold_done"):
		_delegate.call(&"usable_hold_done", user)
