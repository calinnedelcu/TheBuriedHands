class_name BrakeLever
extends Node3D
## Co-op: the brake by the counterweight. The master bears his weight on it
## (use to take hold, use again to let go) and the causeway stays up while he
## does; left alone, the balance lets it sink back into the mercury. The
## apprentice is too light to hold it. Added by the CoopDirector.

const TIMBER := preload("res://assets/materials/level/timber.tres")
const BRONZE := preload("res://assets/materials/props/bronze.tres")
const GRIP := preload("res://audio/sfx/impacts/impactPlank_medium_000.ogg")

var causeway: Causeway
var _brace: Player = null
var _arm: Node3D
var _usable: DelegateUsable

func _ready() -> void:
	_build()

func _process(_delta: float) -> void:
	# Let go by itself once the pin holds the causeway, or the holder falls.
	if _brace != null and (not is_instance_valid(_brace) or _brace.downed or (causeway != null and causeway.pinned)):
		_release(_brace if is_instance_valid(_brace) else null)

## The usable a bracing player lets go through.
func brace_usable() -> Usable:
	return _usable

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null or causeway == null or not causeway.raised or causeway.pinned:
		return ""
	if _brace == p:
		return tr("PROMPT_LET_GO")
	if _brace != null:
		return ""
	return tr("PROMPT_HOLD_BRAKE") if p.role == &"master" else tr("PROMPT_BRAKE_TOO_LIGHT")

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if p == null or causeway == null or not causeway.raised or causeway.pinned:
		return false
	return _brace == p or (_brace == null and p.role == &"master")

func usable_show_blocked(_user: Node) -> bool:
	return causeway != null and causeway.raised and not causeway.pinned and _brace == null

func usable_use(user: Node) -> void:
	var p := user as Player
	if p == null:
		return
	if _brace == p:
		_release(p)
	elif _brace == null:
		_brace = p
		p.brace(self, false)
		causeway.held = true
		Sfx.play_at(GRIP, global_position + Vector3.UP, -2.0)
		_swing(-0.55)

func _release(p: Player) -> void:
	_brace = null
	if p != null:
		p.unbrace()
	if causeway != null:
		causeway.held = false
	_swing(0.0)

func _swing(angle: float) -> void:
	create_tween().set_trans(Tween.TRANS_BACK).tween_property(_arm, "rotation:x", angle, 0.35)

## A low timber post with a bronze lever arm reaching back toward whoever
## works it, at the height of his hands; it doesn't hide the pit.
func _build() -> void:
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 1.0, 0.24)
	post.mesh = box
	post.material_override = TIMBER
	post.position = Vector3(0, 0.5, 0)
	add_child(post)
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0, 0.95, 0)
	add_child(_arm)
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.04
	rod.bottom_radius = 0.05
	rod.height = 1.3
	bar.mesh = rod
	bar.material_override = BRONZE
	# From the pivot up and back to the knob (+x rotation tips +y toward +z).
	bar.rotation.x = deg_to_rad(62.0)
	bar.position = Vector3(0, 0.305, 0.575)
	_arm.add_child(bar)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.08
	ball.height = 0.16
	knob.mesh = ball
	knob.material_override = BRONZE
	knob.position = Vector3(0, 0.61, 1.15)
	_arm.add_child(knob)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = Vector3(0.6, 1.9, 1.6)
	shape.shape = hit
	shape.position = Vector3(0, 0.95, 0.55)
	body.add_child(shape)
	_usable = DelegateUsable.new()
	_usable.name = "Usable"
	_usable.delegate_path = ^"../.."
	body.add_child(_usable)
