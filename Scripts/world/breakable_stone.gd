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
## The rock as it stands: blows shake it about here, the split squashes it
## from here (the rock can be a piece of the level, anywhere in its parent).
var _rock_rest: Transform3D

func _ready() -> void:
	add_to_group(&"persistent")
	_usable.hold_time = 1.1
	if not external_rock_path.is_empty():
		$Rock.visible = false
		_blocker.disabled = true
	_rock_rest = _rock.transform
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

## Holding the key draws the mallet back; the blow lands when the hold is full.
func usable_hold_tick(user: Node, progress: float) -> void:
	var p := user as Player
	if p != null and p.is_local and not (Net.active and _brace == null):
		p.viewmodel.call(&"swing_wind", &"hammer", progress)

func usable_hold_cancelled(user: Node) -> void:
	var p := user as Player
	if p != null and p.is_local:
		p.viewmodel.call(&"swing_end")

func usable_hold_done(user: Node) -> void:
	var p := user as Player
	if Net.active and _brace == null:
		if p != null and p.is_local:
			p.viewmodel.call(&"swing_end")
		return
	blows += 1
	if p != null:
		if p.is_local:
			p.viewmodel.call(&"swing_strike")
		p.add_shake(0.22)
	Sfx.play_random_at(BLOWS, global_position + Vector3.UP, 4.0, 0.06, &"Tomb", 60.0)
	Stealth.make_noise(global_position, noise_radius, p)
	_chips(_struck_at(p), 14, 0.9)
	var shake := create_tween()
	shake.tween_property(_rock, "position", _rock_rest.origin + Vector3(0.05, 0.0, 0.0), 0.05)
	shake.tween_property(_rock, "position", _rock_rest.origin, 0.08)
	if blows >= blows_needed:
		_split()

## Where the mallet met the stone: where the striker looks, on the stone.
func _struck_at(p: Player) -> Vector3:
	if p != null and p.camera != null:
		var from := p.camera.global_position
		var params := PhysicsRayQueryParameters3D.create(from, from - p.camera.global_basis.z * 3.0, 1 | 16)
		params.exclude = [p.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(params)
		if not hit.is_empty():
			return hit.position
	return global_position + Vector3.UP * 0.8

## Stone chips and grit off a blow (and many more off the split).
func _chips(at: Vector3, amount: int, speed: float) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = amount
	burst.lifetime = 1.1
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 1.0 * speed
	burst.initial_velocity_max = 3.2 * speed
	burst.gravity = Vector3(0, -14, 0)
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.6
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.025, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.39, 0.35)
	mat.roughness = 0.95
	mesh.material = mat
	burst.mesh = mesh
	get_parent().add_child(burst)
	burst.global_position = at
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

func _split() -> void:
	broken = true
	Sfx.play_at(SPLIT, global_position, 3.0, 0.0, &"Tomb", 60.0)
	_chips(global_position + Vector3.UP * 0.6, 40, 1.4)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_rock, "scale", _split_scale(), 0.5).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_rock, "position", _rock_rest.origin + Vector3.DOWN * 0.6, 0.5)
	_blocker.set_deferred(&"disabled", true)
	# The use volume goes too, or it hides whatever is behind it (the ladder
	# down the shaft) from the player's aim.
	($Body as CollisionObject3D).set_deferred(&"collision_layer", 0)
	if _external_body != null:
		_external_body.set_deferred(&"collision_layer", 0)
		_external_body.set_deferred(&"collision_mask", 0)
	Dialogue.play(dialogue)

## Split, the stone lies in pieces, low: its own scale, flattened.
func _split_scale() -> Vector3:
	return _rock_rest.basis.get_scale() * Vector3(1.1, 0.25, 1.1)

func _apply() -> void:
	if broken:
		_rock.scale = _split_scale()
		_rock.position = _rock_rest.origin + Vector3.DOWN * 0.6
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
