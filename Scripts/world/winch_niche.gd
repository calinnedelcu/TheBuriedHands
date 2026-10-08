@tool
class_name WinchNiche
extends Node3D
## A pillar of dressed stone against the corridor wall, one of several
## alike. The real one is hollow: Bai's masons wound the battery's winch
## from inside it, and they closed it with a face of loose stones. Air from
## the shafts behind the wall breathes through its joints: a lit lamp held
## near it gutters, and only then does a closer look find the loose stones
## (`felt`). With a chisel the face comes away (`opened`); inside, the winch:
##   held (use to take hold, again to let go), its brake keeps the battery
##   slack and the floor's slabs level while someone else crosses (co-op);
##   held long with a chisel, the chisel goes into the pawl and stays there
##   (it's gone from your hand): the battery never winds again (`jammed`).
## Decoys (`real` off) are the same pillar, solid.
##
## The origin is the foot of the pillar against the wall, in the middle;
## it stands out along +z into the corridor.

const WALL := preload("res://assets/materials/level/walls.tres")
const TIMBER := preload("res://assets/materials/level/timber.tres")
const BRONZE := preload("res://assets/materials/props/bronze.tres")
const FLUTTER := preload("res://audio/sfx/lamp/wall_lamp_fire.mp3")
const PRY := preload("res://audio/sfx/tunnel/gravel_slide.mp3")
const GEARS := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")
const JAMB := 0.45
const LINTEL := 0.7

@export var real := false:
	set(v):
		real = v
		if is_node_ready():
			_build()
@export var width := 2.2:
	set(v):
		width = maxf(v, 1.4)
		if is_node_ready():
			_build()
@export var height := 2.8:
	set(v):
		height = maxf(v, 2.0)
		if is_node_ready():
			_build()
@export var depth := 0.9:
	set(v):
		depth = maxf(v, 0.5)
		if is_node_ready():
			_build()
@export var field_path: NodePath

var felt := false
var opened := false
var jammed := false
var _brace: Player = null
var _panel: LevelSolid
var _panel_body: StaticBody3D
var _winch: Node3D
var _chisel: Node3D
var _gust := 0.0
var _flutter_cool := 0.0

func _ready() -> void:
	_build()
	if Engine.is_editor_hint() or not real:
		return
	add_to_group(&"persistent")

func field() -> TrapField:
	return get_node_or_null(field_path) as TrapField

# --- Looks ----------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		if c.has_meta(&"generated"):
			c.free()
	var opening := width - JAMB * 2.0
	_solid("JambWest", Vector3(-width * 0.5 + JAMB * 0.5, 0.0, depth * 0.5), Vector3(JAMB, height, depth))
	_solid("JambEast", Vector3(width * 0.5 - JAMB * 0.5, 0.0, depth * 0.5), Vector3(JAMB, height, depth))
	_solid("Lintel", Vector3(0.0, height - LINTEL, depth * 0.5), Vector3(opening, LINTEL, depth))
	# The face: a hand's depth of loose stones on the real one; solid through
	# on the others (from outside the same).
	var face_depth := 0.25 if real else depth
	_panel = _solid("Face", Vector3(0.0, 0.0, depth - face_depth * 0.5), Vector3(opening, height - LINTEL, face_depth))
	if not real:
		return
	_build_winch(opening)
	if Engine.is_editor_hint():
		return
	_panel_body = StaticBody3D.new()
	_panel_body.name = "FaceBody"
	_panel_body.collision_layer = 16
	_panel_body.collision_mask = 0
	_panel_body.set_meta(&"generated", true)
	var ps := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(opening, height - LINTEL, 0.06)
	ps.shape = pb
	ps.position = Vector3(0.0, (height - LINTEL) * 0.5, depth + 0.03)
	_panel_body.add_child(ps)
	var pu := DelegateUsable.new()
	pu.name = "Usable"
	pu.delegate_path = ^"../.."
	pu.highlight = false
	pu.hold_time = 2.0
	_panel_body.add_child(pu)
	add_child(_panel_body)

func _solid(solid_name: String, bottom_centre: Vector3, size: Vector3) -> LevelSolid:
	var s := LevelSolid.new()
	s.name = solid_name
	s.set_meta(&"generated", true)
	s.size = size
	s.material = WALL
	s.masonry = true
	s.position = bottom_centre
	add_child(s)
	return s

## Inside: a timber drum wound with the battery's cord, a bronze ratchet and
## its pawl, and the brake's bar reaching out to the hand.
func _build_winch(opening: float) -> void:
	_winch = Node3D.new()
	_winch.name = "Winch"
	_winch.set_meta(&"generated", true)
	add_child(_winch)
	var cav_z := (depth - 0.25) * 0.5
	var drum := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = opening - 0.25
	drum.mesh = cyl
	drum.material_override = TIMBER
	drum.rotation.z = PI * 0.5
	drum.position = Vector3(0.0, 0.95, cav_z)
	_winch.add_child(drum)
	var cord := MeshInstance3D.new()
	var coil := CylinderMesh.new()
	coil.top_radius = 0.235
	coil.bottom_radius = 0.235
	coil.height = (opening - 0.25) * 0.55
	cord.mesh = coil
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.46, 0.38, 0.26)
	hemp.roughness = 1.0
	cord.material_override = hemp
	cord.rotation.z = PI * 0.5
	cord.position = Vector3(-0.1, 0.95, cav_z)
	_winch.add_child(cord)
	var wheel := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.05
	wheel.mesh = disc
	wheel.material_override = BRONZE
	wheel.rotation.z = PI * 0.5
	wheel.position = Vector3(opening * 0.5 - 0.15, 0.95, cav_z)
	_winch.add_child(wheel)
	var pawl := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.05, 0.28, 0.06)
	pawl.mesh = bar
	pawl.material_override = BRONZE
	pawl.rotation.x = 0.5
	pawl.position = Vector3(opening * 0.5 - 0.15, 1.3, cav_z + 0.1)
	_winch.add_child(pawl)
	var brake := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.035
	rod.height = 0.7
	brake.mesh = rod
	brake.material_override = BRONZE
	brake.name = "Brake"
	brake.rotation.x = deg_to_rad(70.0)
	brake.position = Vector3(-opening * 0.5 + 0.2, 1.05, cav_z + 0.3)
	_winch.add_child(brake)
	_chisel = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.03, 0.03, 0.3)
	(_chisel as MeshInstance3D).mesh = blade
	(_chisel as MeshInstance3D).material_override = BRONZE
	_chisel.position = Vector3(opening * 0.5 - 0.15, 1.18, cav_z + 0.18)
	_chisel.rotation.x = -0.4
	_chisel.visible = false
	_winch.add_child(_chisel)
	if Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.name = "WinchBody"
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(opening - 0.1, 1.6, depth - 0.3)
	cs.shape = box
	cs.position = Vector3(0.0, 1.0, cav_z)
	body.add_child(cs)
	var wu := DelegateUsable.new()
	wu.name = "Usable"
	wu.delegate_path = ^"../../.."
	wu.highlight = false
	wu.hold_time = 1.5
	wu.tap_enabled = true
	body.add_child(wu)
	_winch.add_child(body)

# --- The draught ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not real or opened:
		return
	_gust -= delta
	_flutter_cool -= delta
	if _gust > 0.0:
		return
	_gust = 0.45
	var front := global_position + global_basis.z * (depth + 0.6) + Vector3.UP * 1.2
	for p in Net.players():
		if not p.is_local or not p.has_lamp_lit():
			continue
		var lamp := p.inventory.lamp()
		if lamp == null:
			continue
		if lamp.global_position.distance_to(front) < 1.7:
			lamp.gust(0.6)
			if not felt:
				felt = true
			if _flutter_cool <= 0.0:
				_flutter_cool = 3.0
				Sfx.play_at(FLUTTER, lamp.global_position, -14.0, 0.1, &"Tomb", 6.0)

# --- The face -------------------------------------------------------------------------

func _on_face(user: Node) -> bool:
	return user is Player and not opened and felt

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null:
		return ""
	if not opened:
		if not felt:
			return ""
		return tr("PROMPT_NICHE_PRY") if p.inventory.has_item(&"chisel") else tr("PROMPT_NICHE_NEED_CHISEL")
	if jammed:
		return ""
	if _brace == p:
		return tr("PROMPT_LET_GO")
	if _brace != null:
		return ""
	var text := tr("PROMPT_WINCH_BRAKE")
	if p.inventory.has_item(&"chisel"):
		text += "  ·  %s: %s" % [tr("HUD_HOLD"), tr("PROMPT_WINCH_JAM")]
	return text

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if p == null:
		return false
	if not opened:
		# The draught is felt at the holder's own machine: the host takes a
		# partner's word for it.
		return (felt or not p.is_local) and p.inventory.has_item(&"chisel")
	return not jammed and (_brace == null or _brace == p)

func usable_show_blocked(user: Node) -> bool:
	var p := user as Player
	return p != null and not opened and felt and not p.inventory.has_item(&"chisel")

## The face asks a long pull with the chisel; the winch's brake a press, its
## pawl a long one (with a chisel to leave in it).
func usable_is_hold(user: Node) -> bool:
	var p := user as Player
	if p == null:
		return false
	if not opened:
		return true
	return _brace == null and p.inventory.has_item(&"chisel")

func usable_hold_done(user: Node) -> void:
	var p := user as Player
	if p == null:
		return
	if not opened:
		_open()
	elif not jammed and p.inventory.has_item(&"chisel"):
		_jam(p)

func usable_tap(user: Node) -> void:
	var p := user as Player
	if p == null or not opened or jammed:
		return
	if _brace == p:
		_release(p)
	elif _brace == null:
		_brace = p
		p.brace(self, false)
		var f := field()
		if f != null:
			f.set_slack(true)
		Sfx.play_at(GEARS, global_position + Vector3.UP, -8.0, 0.05, &"Tomb", 18.0)

## A press with no hold asked: the brake.
func usable_use(user: Node) -> void:
	usable_tap(user)

func brace_usable() -> Usable:
	return _winch.get_node("WinchBody/Usable") as Usable if _winch != null else null

func _process_brace() -> void:
	if _brace != null and (not is_instance_valid(_brace) or _brace.downed):
		_release(_brace if is_instance_valid(_brace) else null)

func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_process_brace()

func _release(p: Player) -> void:
	_brace = null
	if p != null:
		p.unbrace()
	var f := field()
	if f != null and not f.locked:
		f.set_slack(false)

func _open() -> void:
	opened = true
	Sfx.play_at(PRY, global_position + Vector3.UP, -2.0, 0.05, &"Tomb", 20.0)
	Stealth.make_noise(global_position + global_basis.z, 8.0, self)
	if _panel_body != null:
		_panel_body.collision_layer = 0
	_lay_face_down(true)

## The loose stones come away and lie at the foot of the pillar.
func _lay_face_down(animate: bool) -> void:
	if _panel == null:
		return
	_panel.collision = false
	var to_pos := _panel.position + Vector3(0.0, 0.0, 0.55)
	var to_rot := Vector3(deg_to_rad(84.0), 0.0, 0.0)
	if animate:
		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_panel, "position", to_pos, 0.5)
		t.tween_property(_panel, "rotation", to_rot, 0.5)
	else:
		_panel.position = to_pos
		_panel.rotation = to_rot

func _jam(p: Player) -> void:
	if not p.inventory.remove(&"chisel"):
		return
	jammed = true
	if _brace != null:
		_release(_brace)
	_chisel.visible = true
	var f := field()
	if f != null:
		f.lock()
	Sfx.play_at(GEARS, global_position + Vector3.UP, -2.0, 0.05, &"Tomb", 25.0)
	p.notice("NOTICE_WINCH_JAMMED")

func persist_save() -> Dictionary:
	return {"felt": felt, "opened": opened, "jammed": jammed}

func persist_load(data: Dictionary) -> void:
	felt = bool(data.get("felt", felt))
	if bool(data.get("opened", false)) and not opened:
		opened = true
		if _panel_body != null:
			_panel_body.collision_layer = 0
		_lay_face_down(false)
	if bool(data.get("jammed", false)) and not jammed:
		jammed = true
		if _chisel != null:
			_chisel.visible = true
		var f := field()
		if f != null:
			f.lock()
