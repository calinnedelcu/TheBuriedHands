class_name TrapLever
extends Node3D
## The builders' own controls for a trapped floor (TrapField), set in the
## wall where they armed it and walked out.
##   PIN (far end): driven home, it locks the floor for good: the battery's
##   strings slack, every tipping slab pinned. Crossing back, or behind you,
##   it's an ordinary corridor.
##   BRAKE (near end): a bronze bar on the winch. While someone bears on it
##   (use to take hold, use again to let go) the battery can't loose and the
##   slabs hold level; let go, and it winds again. Alone, holding it gets you
##   nowhere; with a partner, one holds and the other crosses to the pin.

enum Kind { BRAKE, PIN }

const BRONZE := preload("res://assets/materials/props/bronze.tres")
const STONE := preload("res://assets/materials/level/walls.tres")
const GRIP := preload("res://audio/sfx/impacts/impactPlank_medium_000.ogg")
const SLAM := preload("res://audio/sfx/impacts/impactMetal_light_000.ogg")

@export var kind := Kind.PIN
@export var field_paths: Array[NodePath] = []

var pulled := false
var _brace: Player = null
var _arm: Node3D
var _usable: DelegateUsable

func _ready() -> void:
	_build()
	if kind == Kind.PIN:
		add_to_group(&"persistent")
		_usable.hold_time = 1.6

func _process(_delta: float) -> void:
	# The brake lets go by itself if its holder falls.
	if _brace != null and (not is_instance_valid(_brace) or _brace.downed):
		_release(_brace if is_instance_valid(_brace) else null)

func fields() -> Array[TrapField]:
	var out: Array[TrapField] = []
	for path in field_paths:
		var f := get_node_or_null(path) as TrapField
		if f != null:
			out.append(f)
	return out

func _locked() -> bool:
	for f in fields():
		if not f.locked:
			return false
	return true

## The usable a bracing player lets go through.
func brace_usable() -> Usable:
	return _usable

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null or _locked():
		return ""
	if kind == Kind.PIN:
		return tr("PROMPT_TRAP_PIN")
	if _brace == p:
		return tr("PROMPT_LET_GO")
	return tr("PROMPT_TRAP_BRAKE") if _brace == null else ""

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if p == null or _locked():
		return false
	return kind == Kind.PIN or _brace == p or _brace == null

func usable_hold_done(_user: Node) -> void:
	if kind != Kind.PIN or pulled:
		return
	_pull()

func usable_use(user: Node) -> void:
	var p := user as Player
	if kind != Kind.BRAKE or p == null:
		return
	if _brace == p:
		_release(p)
	elif _brace == null:
		_brace = p
		p.brace(self, false)
		for f in fields():
			f.set_slack(true)
		Sfx.play_at(GRIP, global_position + Vector3.UP, -2.0)
		_swing(-0.7)

func _release(p: Player) -> void:
	_brace = null
	if p != null:
		p.unbrace()
	for f in fields():
		if not f.locked:
			f.set_slack(false)
	_swing(0.0)

func _pull() -> void:
	pulled = true
	for f in fields():
		f.lock()
	Sfx.play_at(SLAM, global_position + Vector3.UP, 2.0, 0.05, &"Tomb", 30.0)
	_swing(-1.1)

func _swing(angle: float) -> void:
	if _arm != null:
		create_tween().set_trans(Tween.TRANS_BACK).tween_property(_arm, "rotation:x", angle, 0.35)

## A block of dressed stone at the foot of the wall with a bronze bar set in
## it, reaching out into the corridor at the height of the hands (+z).
func _build() -> void:
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.9, 0.5)
	block.mesh = box
	block.material_override = STONE
	block.position = Vector3(0, 0.45, 0)
	add_child(block)
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0, 0.8, 0.2)
	add_child(_arm)
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.035
	rod.bottom_radius = 0.045
	rod.height = 0.95
	bar.mesh = rod
	bar.material_override = BRONZE
	bar.rotation.x = deg_to_rad(65.0)
	bar.position = Vector3(0, 0.2, 0.43)
	_arm.add_child(bar)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	knob.mesh = ball
	knob.material_override = BRONZE
	knob.position = Vector3(0, 0.4, 0.86)
	_arm.add_child(knob)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = Vector3(0.8, 1.5, 1.3)
	shape.shape = hit
	shape.position = Vector3(0, 0.75, 0.4)
	body.add_child(shape)
	_usable = DelegateUsable.new()
	_usable.name = "Usable"
	_usable.delegate_path = ^"../.."
	body.add_child(_usable)

func persist_save() -> Dictionary:
	return {"pulled": pulled}

func persist_load(data: Dictionary) -> void:
	if bool(data.get("pulled", false)) and not pulled:
		pulled = true
		for f in fields():
			f.lock()
		if _arm != null:
			_arm.rotation.x = -1.1
