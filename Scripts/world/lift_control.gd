class_name LiftControl
extends Node
## One of the lift's controls (the brake, the ballast box): passes what its
## DelegateUsable asks on to the lift's methods of the same kind, e.g.
## usable_use -> brake_use.

var lift: Node
var prefix: StringName

func usable_prompt(user: Node) -> String:
	return _ask(&"prompt", user, "")

func usable_can_use(user: Node) -> bool:
	return _ask(&"can_use", user, false)

func usable_use(user: Node) -> void:
	_ask(&"use", user, null)

func usable_tap(user: Node) -> void:
	_ask(&"tap", user, null)

func usable_hold_done(user: Node) -> void:
	_ask(&"hold_done", user, null)

func _ask(what: StringName, user: Node, fallback: Variant) -> Variant:
	var method := StringName("%s_%s" % [prefix, what])
	return lift.call(method, user) if lift != null and lift.has_method(method) else fallback
