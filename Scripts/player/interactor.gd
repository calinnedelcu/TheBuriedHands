class_name Interactor
extends RayCast3D
## Finds the Usable the player is looking at, drives the prompt, the rim
## highlight and press/hold input. A thin ray is tried first; if it finds no
## usable, a short sphere cast makes small objects easier to target.

signal target_changed(usable: Usable)
signal prompt_changed(text: String, action: StringName, is_hold: bool, blocked: bool)
signal hold_progress_changed(progress: float)

const HIGHLIGHT_MATERIAL := preload("res://assets/materials/interact_highlight.tres")

@export var assist_radius := 0.14

## Releasing a hold usable faster than this counts as a tap.
const TAP_SECONDS := 0.3

var target: Usable = null
var _user: Node
var _holding := false
var _hold_elapsed := 0.0
var _prompt_cache := ""
var _highlighted: Array[GeometryInstance3D] = []
var _assist_shape := SphereShape3D.new()

func _ready() -> void:
	_user = owner
	add_exception(_user as CollisionObject3D)
	_assist_shape.radius = assist_radius

func _physics_process(delta: float) -> void:
	var found := _find_usable()
	if found != target:
		_set_target(found)
	_refresh_prompt()
	_update_hold(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _user.has_method("controls_locked") and _user.call("controls_locked"):
		return
	if event.is_action_pressed(&"interact"):
		if target == null or not target.can_use(_user):
			return
		get_viewport().set_input_as_handled()
		if target.is_hold_for(_user):
			_holding = true
			_hold_elapsed = 0.0
		else:
			# Through Net: in co-op the host checks the use and both run it.
			# A hold with nothing to hold for here is its tap, done at once.
			Net.use(target, _user, &"tap" if target.is_hold() and target.tap_enabled else &"use")
			_refresh_prompt(true)
	elif event.is_action_released(&"interact") and _holding:
		var was_tap := _hold_elapsed < TAP_SECONDS and target != null and target.tap_enabled
		var tapped := target
		_cancel_hold()
		if was_tap:
			Net.use(tapped, _user, &"tap")
			_refresh_prompt(true)

func _find_usable() -> Usable:
	force_raycast_update()
	if is_colliding():
		var u := _usable_on(get_collider())
		if u != null:
			return u
	# Assist: a short sphere sweep along the view ray for small props.
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _assist_shape
	params.transform = global_transform
	params.motion = global_transform.basis * target_position
	params.collision_mask = collision_mask
	params.exclude = [(_user as CollisionObject3D).get_rid()]
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(params)
	if fractions[1] >= 1.0:
		return null
	params.transform.origin += params.motion * fractions[1]
	params.motion = Vector3.ZERO
	for hit in space.intersect_shape(params, 4):
		var u := _usable_on(hit.collider)
		if u != null:
			# Never select something hidden behind a wall the thin ray hit first.
			if is_colliding() and global_position.distance_to(get_collision_point()) + 0.3 < global_position.distance_to((hit.collider as Node3D).global_position):
				continue
			return u
	return null

func _usable_on(collider: Object) -> Usable:
	if collider == null or not collider.has_meta(&"usables"):
		return null
	for u in collider.get_meta(&"usables"):
		var usable := u as Usable
		if usable == null or not is_instance_valid(usable):
			continue
		if usable.can_use(_user) or usable.shows_when_blocked(_user):
			if usable.get_prompt(_user) != "":
				return usable
	return null

func _set_target(usable: Usable) -> void:
	if _holding:
		_cancel_hold()
	_clear_highlight()
	target = usable
	if target != null and target.highlight:
		_apply_highlight(target.highlight_root())
	target_changed.emit(target)
	_refresh_prompt(true)

func _refresh_prompt(force := false) -> void:
	var text := ""
	var blocked := false
	if target != null:
		text = target.get_prompt(_user)
		blocked = not target.can_use(_user)
	if text == _prompt_cache and not force:
		return
	_prompt_cache = text
	prompt_changed.emit(text, &"interact", target != null and target.is_hold_for(_user), blocked)

func _update_hold(delta: float) -> void:
	if not _holding:
		return
	if target == null or not target.can_use(_user) or not Input.is_action_pressed(&"interact"):
		_cancel_hold()
		return
	_hold_elapsed += delta
	if target.tap_enabled and _hold_elapsed < TAP_SECONDS:
		return
	var progress := clampf(_hold_elapsed / target.hold_time, 0.0, 1.0)
	target.hold_tick(_user, progress)
	hold_progress_changed.emit(progress)
	if progress >= 1.0:
		_holding = false
		hold_progress_changed.emit(0.0)
		Net.use(target, _user, &"hold")
		_refresh_prompt(true)

func _cancel_hold() -> void:
	if target != null:
		target.hold_cancelled(_user)
	_holding = false
	_hold_elapsed = 0.0
	hold_progress_changed.emit(0.0)

func _apply_highlight(root: Node) -> void:
	if root == null:
		return
	var nodes: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.append(root)
	for n in nodes:
		var g := n as GeometryInstance3D
		if g is MeshInstance3D and g.is_visible_in_tree() and g.material_overlay == null:
			g.material_overlay = HIGHLIGHT_MATERIAL
			_highlighted.append(g)

func _clear_highlight() -> void:
	for g in _highlighted:
		if is_instance_valid(g) and g.material_overlay == HIGHLIGHT_MATERIAL:
			g.material_overlay = null
	_highlighted.clear()
