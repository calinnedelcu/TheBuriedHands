class_name ExitWatch
extends Area3D
## Act I: a soldier keeps the craftsmen at their work. He stands in the
## workshop's south door, the way to the trap corridor and the archives;
## walk up to him and he sends you back to your statue, and the doorway
## behind him is closed to you. At the sealing he goes in with the captain
## (SealingSequence) and the way is open.
##
## The area is where he notices you (on the workshop side); `Blocker` is a
## body across the doorway on a layer of its own (players collide with it,
## guards, bolts and sight go through).

## The layer of the doorway's blocker: the player's mask has it (the guards'
## bodies are on it), the guards' and the bolts' masks don't.
const BLOCK_LAYER := 4

@export var guard_path: NodePath
@export var blocker_path: NodePath = ^"Blocker"
## The way opens once the quest reaches this step.
@export var until_step: StringName = &"sealing"
## Guard bark kind (DialogueDB.GUARD_BARKS) he answers with.
@export var bark: StringName = &"keep_in"

var _guard: Guard
var _cooldown := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	_guard = get_node_or_null(guard_path) as Guard
	body_entered.connect(_on_body_entered)
	Quest.step_changed.connect(func(_step: StringName) -> void: _refresh())
	_refresh()

func _process(delta: float) -> void:
	_cooldown -= delta

func is_open() -> bool:
	return Quest.has_reached(until_step)

func _refresh() -> void:
	var blocker := get_node_or_null(blocker_path) as CollisionObject3D
	if blocker != null:
		blocker.set_deferred(&"collision_layer", 0 if is_open() else BLOCK_LAYER)

func _on_body_entered(body: Node3D) -> void:
	# Co-op: the host's guards do the talking.
	if Net.is_client() or is_open() or not (body is Player) or _cooldown > 0.0:
		return
	_cooldown = 9.0
	if _guard == null or not _guard.is_inside_tree():
		return
	_guard.scripted_face(body.global_position)
	_guard.play_animation(&"talk")
	_guard.say(bark)
	await get_tree().create_timer(2.6, false).timeout
	if is_instance_valid(_guard) and not is_open():
		_guard.play_animation(&"idle")
