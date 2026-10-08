@icon("res://assets/editor/usable.svg")
class_name Usable
extends Node
## Something the player can use while looking at it.
##
## Add as a child of the CollisionObject3D the interaction ray should hit (or
## point `body_path` at it). Instant uses emit `used`; with `hold_time` > 0 the
## player must hold the key and `hold_completed` fires at the end.
## Subclasses override `get_prompt()` / `can_use()` / `_on_use()`.

signal used(user: Node)
signal hold_completed(user: Node)

## Translation key shown next to the key glyph, e.g. PROMPT_TAKE.
@export var prompt_key := "PROMPT_TAKE"
@export var enabled := true
@export var single_use := false
## Seconds the key must be held. 0 = instant.
@export var hold_time := 0.0
## For hold usables: a quick tap (released early) calls `tap()` instead.
@export var tap_enabled := false
## Only usable while the quest is at exactly this step (empty = any).
@export var quest_step: StringName = &""
## Only usable once the quest has reached this step (empty = any).
@export var quest_from: StringName = &""
## Ahead of the story (`quest_step` / `quest_from` not reached yet), shows
## what to do first instead of nothing, so the aim doesn't slip past it.
@export var quest_hint := false
@export var body_path: NodePath = ^".."
## Root whose meshes get the rim highlight while looked at (default: body's parent).
@export var highlight_root_path: NodePath = ^""
@export var highlight := true

## Values substituted into the prompt text, e.g. {"item": "Daltă"}.
var prompt_args := {}
## Optional extra condition: called with the user, returns a translation key
## saying why the object can't be used right now ("" = fine). The reason is
## shown, dimmed, in place of the prompt.
var block_reason: Callable = Callable()
var _used_once := false

func _ready() -> void:
	var body := get_node_or_null(body_path)
	if body == null:
		push_warning("%s: Usable has no body at %s" % [get_path(), body_path])
		return
	var list: Array = body.get_meta(&"usables", [])
	list.append(self)
	body.set_meta(&"usables", list)

func _exit_tree() -> void:
	var body := get_node_or_null(body_path)
	if body != null and body.has_meta(&"usables"):
		var list: Array = body.get_meta(&"usables")
		list.erase(self)

## Localized prompt, or "" to show nothing (the object is ignored entirely).
func get_prompt(user: Node) -> String:
	if quest_hint and _ahead_of_story():
		return _first_this()
	var key := _blocked_by(user)
	if key == "":
		key = prompt_key
	return tr(key).format(prompt_args) if not prompt_args.is_empty() else tr(key)

func can_use(user: Node) -> bool:
	return _available() and _blocked_by(user) == ""

## Whether the prompt should show even when `can_use` is false (e.g. "You need a chisel").
func shows_when_blocked(user: Node) -> bool:
	if quest_hint and _ahead_of_story():
		return true
	return _available() and _blocked_by(user) != ""

## Only the story stands in the way: its step is still to come.
func _ahead_of_story() -> bool:
	if not enabled or (single_use and _used_once):
		return false
	return (quest_step != &"" and not Quest.has_reached(quest_step)) or (quest_from != &"" and not Quest.has_reached(quest_from))

## "First: <what the story asks now>".
func _first_this() -> String:
	var now := Net.objective_for(Quest.objective_key())
	return tr("PROMPT_FIRST") % tr(now) if now != "" else tr("PROMPT_NOT_YET")

func _available() -> bool:
	if not enabled or (single_use and _used_once):
		return false
	if quest_step != &"" and not Quest.is_at(quest_step):
		return false
	if quest_from != &"" and not Quest.has_reached(quest_from):
		return false
	return true

func _blocked_by(user: Node) -> String:
	return String(block_reason.call(user)) if block_reason.is_valid() else ""

func is_hold() -> bool:
	return hold_time > 0.0

## Whether this user must hold the key right now. A hold whose holding does
## nothing for them (a lamp stand, to a hand with no lamp to fill) acts on
## the press, as a tap: a long press must not swallow the only thing to do.
func is_hold_for(_user: Node) -> bool:
	return is_hold()

func use(user: Node) -> void:
	if not can_use(user):
		return
	_used_once = true
	_on_use(user)
	used.emit(user)

func complete_hold(user: Node) -> void:
	if not can_use(user):
		return
	_used_once = true
	_on_hold_completed(user)
	hold_completed.emit(user)

## Quick press on a hold usable that has `tap_enabled`.
func tap(user: Node) -> void:
	if can_use(user):
		_on_tap(user)

## Called every frame while the key is held (0..1). Override for feedback.
func hold_tick(_user: Node, _progress: float) -> void:
	pass

func hold_cancelled(_user: Node) -> void:
	pass

func _on_use(_user: Node) -> void:
	pass

func _on_hold_completed(_user: Node) -> void:
	pass

func _on_tap(_user: Node) -> void:
	pass

func highlight_root() -> Node:
	if not highlight_root_path.is_empty():
		return get_node_or_null(highlight_root_path)
	var body := get_node_or_null(body_path)
	return body.get_parent() if body != null else null
