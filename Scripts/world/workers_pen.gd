class_name WorkersPen
extends Node3D
## Where the guards keep the craftsmen they rounded up, behind a timber gate,
## until the last seal. A lever across the yard raises the gate; it groans
## (the guards come to look) and the workers bolt for the stairs, past the
## guards' backs. In single-player the apprentice is among them once Wei's
## men have taken him from the kiln (with the lamp his master left him, if he
## did), and says a word to his master on his way out. Built in code: the
## fence, the gate, the prisoners and the lever.
##
## The pen's inside is `size` (x across, z along) around the origin; the gate
## is in the -z side.

const TIMBER := preload("res://assets/materials/level/timber.tres")
const CRAFTSMAN := preload("res://assets/models/characters/craftsman.glb")
const APPRENTICE := preload("res://assets/models/characters/apprentice.glb")
const LAMP := preload("res://scenes/world/oil_lamp_prop.tscn")
const GATE_SOUND := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")
const CREAK := preload("res://audio/sfx/impacts/creak2.ogg")

@export var size := Vector2(6.0, 9.0)
@export var height := 2.8
@export var gate_width := 2.6
## A Node3D (a Marker3D) where the lever stands.
@export var lever_path: NodePath
## A Node3D whose Marker3D children are the way out, in order.
@export var flee_path: NodePath
@export var prisoners := 4
@export var noise_radius := 24.0

var opened := false
var _gate: Node3D
var _gate_shape: CollisionShape3D
var _people: Array[Node3D] = []
var _apprentice: Node3D

func _ready() -> void:
	add_to_group(&"persistent")
	_build()

func usable_prompt(_user: Node) -> String:
	return "" if opened else tr("PROMPT_PEN_LEVER")

func usable_can_use(_user: Node) -> bool:
	return not opened

func usable_use(_user: Node) -> void:
	open(true)

func open(animate: bool) -> void:
	if opened:
		return
	opened = true
	_gate_shape.set_deferred(&"disabled", true)
	if not animate:
		_gate.position.y = height
		for p in _people:
			p.queue_free()
		_people.clear()
		_apprentice = null
		return
	Sfx.play_at(GATE_SOUND, global_position, 0.0, 0.05, &"Tomb", 40.0)
	Sfx.play_at(CREAK, global_position, 2.0, 0.1, &"Tomb", 40.0)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_gate, "position:y", height, 2.2)
	if not Net.is_client():
		Stealth.make_noise(global_position, noise_radius, self)
	Game.set_flag(&"workers_freed")
	if _apprentice != null and _apprentice.visible:
		Game.set_flag(&"apprentice_freed")
		Dialogue.play(&"apprentice_freed")
	var points := _flee_points()
	for i in _people.size():
		_flee(_people[i], points, 0.35 + i * 0.45)
	_people.clear()

func _flee_points() -> Array[Vector3]:
	var out: Array[Vector3] = [global_position + global_basis * Vector3(0, 0, -size.y * 0.5 - 1.5)]
	var path := get_node_or_null(flee_path)
	if path != null:
		for c in path.get_children():
			if c is Node3D:
				out.append((c as Node3D).global_position)
	return out

## Out of the gate and along the way out at a run, then gone.
func _flee(person: Node3D, points: Array[Vector3], delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(person):
		return
	_play(person, &"walk", 1.6)
	var at := person.global_position
	for p in points:
		var to := Vector3(p.x, at.y if absf(p.y - at.y) < 0.6 else p.y, p.z)
		var d := to - at
		if Vector2(d.x, d.z).length() > 0.05:
			person.rotation.y = atan2(-d.z, d.x)
		var t := create_tween()
		t.tween_property(person, "global_position", to, maxf(d.length() / 4.2, 0.1))
		await t.finished
		if not is_instance_valid(person):
			return
		at = to
	person.queue_free()

func _play(person: Node3D, clip: StringName, speed := 1.0) -> void:
	var anims := person.find_children("*", "AnimationPlayer", true, false)
	if anims.is_empty():
		return
	var ap := anims[0] as AnimationPlayer
	if ap.has_animation(clip):
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		ap.play(clip, 0.2, speed)

func persist_save() -> Dictionary:
	return {"opened": opened}

func persist_load(data: Dictionary) -> void:
	if bool(data.get("opened", false)):
		open(false)
	else:
		_show_apprentice()

# --- Building ---------------------------------------------------------------------------

func _build() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var fence := StaticBody3D.new()
	fence.name = "Fence"
	fence.collision_mask = 0
	add_child(fence)
	# Posts all round, two rails; the -z side leaves room for the gate.
	var sides := [
		[Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz)], [Vector3(hx, 0, -hz), Vector3(hx, 0, hz)],
		[Vector3(-hx, 0, hz), Vector3(hx, 0, hz)],
		[Vector3(-hx, 0, -hz), Vector3(-gate_width * 0.5, 0, -hz)], [Vector3(gate_width * 0.5, 0, -hz), Vector3(hx, 0, -hz)],
	]
	for side in sides:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var length := a.distance_to(b)
		var n := maxi(1, int(ceil(length / 1.1)))
		for k in n + 1:
			_part(self, Vector3(0.18, height, 0.18), a.lerp(b, float(k) / n) + Vector3.UP * height * 0.5)
		var mid := (a + b) * 0.5
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		for y in [height * 0.35, height * 0.8]:
			_part(self, Vector3(length, 0.12, 0.12) if along_x else Vector3(0.12, 0.12, length), mid + Vector3.UP * y)
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, height, 0.3) if along_x else Vector3(0.3, height, length)
		wall.shape = box
		wall.position = mid + Vector3.UP * height * 0.5
		fence.add_child(wall)
	# The gate: upright bars in a frame, lifted straight up.
	_gate = Node3D.new()
	_gate.name = "Gate"
	_gate.position = Vector3(0, 0, -hz)
	add_child(_gate)
	for k in 7:
		_part(_gate, Vector3(0.12, height, 0.12), Vector3(-gate_width * 0.5 + gate_width * k / 6.0, height * 0.5, 0))
	_part(_gate, Vector3(gate_width, 0.16, 0.16), Vector3(0, height - 0.15, 0))
	_part(_gate, Vector3(gate_width, 0.16, 0.16), Vector3(0, 0.3, 0))
	var gate_body := StaticBody3D.new()
	gate_body.collision_mask = 0
	_gate.add_child(gate_body)
	_gate_shape = CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(gate_width, height, 0.3)
	_gate_shape.shape = gb
	_gate_shape.position = Vector3(0, height * 0.5, 0)
	gate_body.add_child(_gate_shape)
	# The prisoners, kneeling; the apprentice curled up among them (alone).
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in prisoners:
		var man := CRAFTSMAN.instantiate() as Node3D
		man.scale = Vector3.ONE * 3.1
		man.position = Vector3(rng.randf_range(-hx + 1.0, hx - 1.0), 0, -hz + 2.0 + (size.y - 3.0) * float(i) / maxf(prisoners - 1, 1))
		man.rotation.y = rng.randf_range(0.0, TAU)
		add_child(man)
		var tool := man.find_child("Tool", true, false) as Node3D
		if tool != null:
			tool.visible = false
		_play(man, &"kneel")
		_people.append(man)
	if not Net.active:
		_apprentice = APPRENTICE.instantiate() as Node3D
		_apprentice.scale = Vector3.ONE * 2.75
		_apprentice.position = Vector3(hx - 1.2, 0, hz - 1.4)
		_apprentice.rotation.y = PI * 0.75
		add_child(_apprentice)
		_play(_apprentice, &"cower")
		_people.insert(0, _apprentice)
		_show_apprentice()
		Game.flag_changed.connect(func(flag: StringName, _value: Variant):
			if flag == &"apprentice_taken":
				_show_apprentice())
	# The lever, across the yard.
	var spot := get_node_or_null(lever_path) as Node3D
	if spot == null:
		return
	var lever := Node3D.new()
	lever.name = "Lever"
	spot.add_child(lever)
	_part(lever, Vector3(0.25, 1.1, 0.25), Vector3(0, 0.55, 0))
	var arm := _part(lever, Vector3(0.09, 1.2, 0.09), Vector3(0, 1.4, 0.2))
	arm.rotation.x = deg_to_rad(-25.0)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16
	body.collision_mask = 0
	lever.add_child(body)
	var shape := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(0.8, 2.2, 0.8)
	shape.shape = hb
	shape.position = Vector3(0, 1.1, 0)
	body.add_child(shape)
	var usable := DelegateUsable.new()
	usable.name = "Usable"
	body.add_child(usable)
	# The lever stands across the yard, not under the pen: point it here.
	usable.delegate_path = usable.get_path_to(self)
	usable.set(&"_delegate", self)
	# A rope from the top of its post to the top of the gate, over a pulley
	# on the fence: which lever does what, at a glance.
	var pulley := Vector3(hx * 0.5, height + 0.2, -hz)
	_part(self, Vector3(0.35, 0.35, 0.35), pulley)
	var from := lever.global_position + Vector3.UP * 1.05
	_rope_between(from, to_global(pulley))
	_rope_between(to_global(pulley), to_global(Vector3(0, height, -hz)))

## Here once he has been taken; the lamp beside him goes where he goes.
func _show_apprentice() -> void:
	if _apprentice == null or not is_instance_valid(_apprentice):
		return
	var taken := bool(Game.get_flag(&"apprentice_taken"))
	_apprentice.visible = taken
	if taken and Game.get_flag(&"gave_lamp") and _apprentice.get_node_or_null("Lamp") == null:
		var lamp := LAMP.instantiate() as Node3D
		lamp.name = "Lamp"
		lamp.scale = Vector3.ONE / _apprentice.scale.x
		lamp.position = Vector3(0.25, 0.0, 0.2)
		_apprentice.add_child(lamp)

func _rope_between(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 1.0
	cyl.radial_segments = 6
	mi.mesh = cyl
	mi.material_override = TIMBER
	add_child(mi)
	var span := b - a
	var length := maxf(span.length(), 0.05)
	mi.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, span / length)) * Basis.from_scale(Vector3(1, length, 1)), (a + b) * 0.5)

func _part(parent: Node3D, part_size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = part_size
	mi.mesh = mesh
	mi.material_override = TIMBER
	mi.position = pos
	parent.add_child(mi)
	return mi
