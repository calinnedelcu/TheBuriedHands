class_name LampStand
extends Node3D
## An oil lamp resting on a stand or table. Take it into your left hand, or —
## if you already carry one — hold the key to pour its oil into yours.

@export var oil := 100.0
@export var start_lit := false
@export_group("Story")
@export var completes_step: StringName = &""
@export var dialogue: StringName = &""

@onready var _flame: Node3D = $Flame
@onready var _light: OmniLight3D = $Light
@onready var _usable: DelegateUsable = $Body/Usable

var taken := false
var _last_progress := 0.0

func _ready() -> void:
	add_to_group(&"persistent")
	_usable.hold_time = 3.0
	_usable.tap_enabled = true
	_refresh()

func _refresh() -> void:
	visible = not taken
	_usable.enabled = not taken
	var lit := start_lit and oil > 0.0
	_flame.visible = lit
	_light.visible = lit
	if lit:
		Stealth.register_light(_light)
	else:
		Stealth.unregister_light(_light)

func _exit_tree() -> void:
	Stealth.unregister_light(_light)

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null:
		return ""
	if p.inventory.lamp() == null:
		return tr("PROMPT_TAKE_LAMP")
	if oil > 0.5 and not p.inventory.lamp().is_full():
		return "%s: %s" % [tr("HUD_HOLD"), tr("PROMPT_REFILL")]
	return ""

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return p != null and not taken and (p.inventory.lamp() == null or (oil > 0.5 and not p.inventory.lamp().is_full()))

func usable_is_hold(user: Node) -> bool:
	var p := user as Player
	return p != null and p.inventory.lamp() != null

func usable_tap(user: Node) -> void:
	var p := user as Player
	if p == null or p.inventory.lamp() != null:
		return
	p.inventory.take_lamp(oil, true)
	taken = true
	_refresh()
	Sfx.play_at(preload("res://audio/sfx/impacts/handleSmallLeather.ogg"), global_position, -6.0)
	Story.fire(completes_step, dialogue)

func usable_hold_tick(user: Node, progress: float) -> void:
	var p := user as Player
	if p == null or p.inventory.lamp() == null:
		return
	var dt := maxf(0.0, (progress - _last_progress) * _usable.hold_time)
	_last_progress = progress
	oil -= p.inventory.lamp().refill(minf(30.0 * dt, oil))

func usable_hold_cancelled(_user: Node) -> void:
	_last_progress = 0.0

func usable_hold_done(_user: Node) -> void:
	_last_progress = 0.0

func persist_save() -> Dictionary:
	return {"taken": taken, "oil": oil}

func persist_load(data: Dictionary) -> void:
	taken = bool(data.get("taken", taken))
	oil = float(data.get("oil", oil))
	_refresh()
