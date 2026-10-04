class_name MercuryPool
extends Area3D
## Wading into mercury: slows you down and floods you with vapour. Stay in and
## it kills you. With a UseBody/Usable child it is also where the jar is
## filled: hold the use key while looking at the mercury.

const FILL_SOUND := preload("res://audio/sfx/mercury/fill.mp3")

@export var vapor := 1.0
@export var drag := 0.55

var _player: Player

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var usable := get_node_or_null("UseBody/Usable") as DelegateUsable
	if usable != null:
		usable.hold_time = 2.6

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_player.add_vapor(vapor)
	_player.velocity.x *= drag
	_player.velocity.z *= drag

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null:
		return ""
	if p.inventory.has_item(&"vase"):
		return tr("PROMPT_FILL_VASE")
	if p.inventory.has_item(&"vase_full"):
		return tr("PROMPT_VASE_FULL")
	return tr("PROMPT_NEED_VASE") if Quest.has_reached(&"fill_vase") else ""

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return p != null and p.inventory.has_item(&"vase")

func usable_show_blocked(user: Node) -> bool:
	return Quest.has_reached(&"fill_vase")

func usable_hold_tick(user: Node, _progress: float) -> void:
	var p := user as Player
	if p != null:
		p.add_vapor(0.9)

func usable_hold_done(user: Node) -> void:
	var p := user as Player
	if p == null:
		return
	p.inventory.replace(&"vase", &"vase_full")
	Sfx.play_at(FILL_SOUND, p.global_position, -2.0)
	Story.fire(&"fill_vase", &"vase_filled")
