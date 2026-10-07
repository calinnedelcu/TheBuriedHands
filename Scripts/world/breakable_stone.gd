class_name BreakableStone
extends Node3D
## A boulder blocking a passage. With a wedge and a mallet you split it, but
## every blow rings through the halls: guards nearby will come to look.
##
## Co-op: a two-man job. The apprentice holds the wedge in the crack (use to
## take hold, again to let go) and the master swings the mallet; a blow with
## nobody holding the wedge does nothing.

const BLOWS := [
	preload("res://audio/sfx/impacts/impactMining_001.ogg"),
	preload("res://audio/sfx/impacts/impactMining_002.ogg"),
	preload("res://audio/sfx/impacts/impactMining_003.ogg"),
]
const SPLIT := preload("res://audio/sfx/tunnel/stones_falling.mp3")

@export var blows_needed := 4
@export var noise_radius := 26.0
@export var dialogue: StringName = &"stone_broken"
## Use an existing level mesh as the boulder instead of the built-in rock.
@export var external_rock_path: NodePath
## Its collision body (disabled when the stone splits).
@export var external_body_path: NodePath

@onready var _usable: DelegateUsable = $Body/Usable
@onready var _rock: Node3D = get_node_or_null(external_rock_path) if not external_rock_path.is_empty() else $Rock
@onready var _blocker: CollisionShape3D = $Blocker/Shape
@onready var _external_body: CollisionObject3D = get_node_or_null(external_body_path)

var blows := 0
var broken := false
## Co-op: whoever holds the wedge in the crack.
var _brace: Player = null

func _ready() -> void:
	add_to_group(&"persistent")
	_usable.hold_time = 1.1
	if not external_rock_path.is_empty():
		$Rock.visible = false
		_blocker.disabled = true
	_apply()

func _process(_delta: float) -> void:
	if not Net.active:
		return
	# A blow is a hold for the master; taking hold of the wedge is a press.
	var me := Net.local_body()
	_usable.hold_time = 1.1 if me != null and me.role == &"master" else 0.0
	if _brace != null and (not is_instance_valid(_brace) or _brace.downed or broken):
		_let_go(_brace if is_instance_valid(_brace) else null)

func brace_usable() -> Usable:
	return _usable

func usable_prompt(user: Node) -> String:
	if broken:
		return ""
	if Net.active:
		return _coop_prompt(user as Player)
	var p := user as Player
	if p != null and p.inventory.has_item(&"wedge") and p.inventory.has_item(&"hammer"):
		return "%s  (%d/%d)" % [tr("PROMPT_BREAK_STONE"), blows, blows_needed]
	return tr("PROMPT_NEED_WEDGE_HAMMER")

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if Net.active and p != null and not broken:
		if _brace == p:
			return true
		if p.role == &"apprentice":
			return _brace == null and p.inventory.has_item(&"wedge")
		return _brace != null and p.inventory.has_item(&"hammer")
	return not broken and p != null and p.inventory.has_item(&"wedge") and p.inventory.has_item(&"hammer")

func _coop_prompt(p: Player) -> String:
	if p == null:
		return ""
	if _brace == p:
		return tr("PROMPT_LET_GO")
	if p.role == &"apprentice":
		if _brace != null:
			return ""
		return tr("PROMPT_HOLD_WEDGE") if p.inventory.has_item(&"wedge") else tr("PROMPT_NEED_WEDGE")
	if not p.inventory.has_item(&"hammer"):
		return tr("PROMPT_NEED_HAMMER")
	if _brace == null:
		return tr("PROMPT_NEED_WEDGE_HELD")
	return "%s  (%d/%d)" % [tr("PROMPT_BREAK_STONE"), blows, blows_needed]

## Co-op: the apprentice takes hold of the wedge, or lets go.
func usable_use(user: Node) -> void:
	var p := user as Player
	if not Net.active or p == null:
		return
	if _brace == p:
		_let_go(p)
	elif _brace == null and p.role == &"apprentice":
		_brace = p
		p.brace(self)
		Sfx.play_at(BLOWS[0], global_position + Vector3.UP, -14.0, 0.1)

func _let_go(p: Player) -> void:
	_brace = null
	if p != null:
		p.unbrace()

func usable_show_blocked(_user: Node) -> bool:
	return not broken

func usable_hold_done(user: Node) -> void:
	if Net.active and _brace == null:
		return
	blows += 1
	var p := user as Player
	if p != null:
		p.viewmodel.call(&"play_use")
		p.add_shake(0.15)
	Sfx.play_random_at(BLOWS, global_position + Vector3.UP, 4.0, 0.06, &"Tomb", 60.0)
	Stealth.make_noise(global_position, noise_radius, p)
	var shake := create_tween()
	shake.tween_property(_rock, "position:x", 0.06, 0.05)
	shake.tween_property(_rock, "position:x", 0.0, 0.08)
	if blows >= blows_needed:
		_split()

func _split() -> void:
	broken = true
	Sfx.play_at(SPLIT, global_position, 3.0, 0.0, &"Tomb", 60.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_rock, "scale", Vector3(1.1, 0.25, 1.1), 0.5).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_rock, "position:y", -0.6, 0.5)
	_blocker.set_deferred(&"disabled", true)
	# The use volume goes too, or it hides whatever is behind it (the ladder
	# down the shaft) from the player's aim.
	($Body as CollisionObject3D).set_deferred(&"collision_layer", 0)
	if _external_body != null:
		_external_body.set_deferred(&"collision_layer", 0)
		_external_body.set_deferred(&"collision_mask", 0)
	Dialogue.play(dialogue)

func _apply() -> void:
	if broken:
		_rock.scale = Vector3(1.1, 0.25, 1.1)
		_rock.position.y = -0.6
		_blocker.disabled = true
		($Body as CollisionObject3D).collision_layer = 0
		if _external_body != null:
			_external_body.collision_layer = 0
			_external_body.collision_mask = 0

func persist_save() -> Dictionary:
	return {"blows": blows, "broken": broken}

func persist_load(data: Dictionary) -> void:
	blows = int(data.get("blows", 0))
	broken = bool(data.get("broken", false))
	_apply()
