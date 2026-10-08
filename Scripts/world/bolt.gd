class_name Bolt
extends Node3D
## A crossbow bolt in flight, straight on at its speed until it hits
## something: a player is hurt (in co-op the bolt flies on both machines and
## each hurts its own player) unless he wears stone armour, off which it
## glances; a thing that answers bolt_hit (a gong, a hanging lamp) is told;
## anything else takes it with a thud the guards can hear.

const HIT_WALL := [preload("res://audio/sfx/impacts/impactPlank_medium_001.ogg"), preload("res://audio/sfx/impacts/impactPlank_medium_002.ogg")]
const GLANCE := preload("res://audio/sfx/impacts/impactPlate_light_001.ogg")

var damage := 3.0
var speed := 42.0
var max_range := 40.0
## Whoever loosed it: the death screen's culprit, and a crossbowman who sees
## it glance off stone says so.
var source: Node
## Bodies it flies through (the man who loosed it, standing at the stand).
var ignore: Array[RID] = []

## Looses a bolt from `from` along `dir`, into `parent`.
static func launch(parent: Node, from: Vector3, dir: Vector3, bolt_speed: float, bolt_damage: float, bolt_range: float, by: Node, through: Array[RID] = []) -> Bolt:
	var b := Bolt.new()
	b.speed = bolt_speed
	b.damage = bolt_damage
	b.max_range = bolt_range
	b.source = by
	b.ignore = through
	b._build()
	parent.add_child(b)
	b.global_transform = Transform3D(Basis.looking_at(dir), from)
	b._fly(dir.normalized())
	return b

func _fly(dir: Vector3) -> void:
	var travelled := 0.0
	var space := get_world_3d().direct_space_state
	while travelled < max_range and is_inside_tree():
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		var step := speed * get_physics_process_delta_time()
		var from := global_position
		var to := from + dir * step
		var params := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
		params.exclude = ignore
		var hit := space.intersect_ray(params)
		if not hit.is_empty():
			global_position = hit.position - dir * 0.15
			_hit(hit.collider as Node, hit.position)
			return
		global_position = to
		travelled += step
	queue_free()

func _hit(collider: Node, at: Vector3) -> void:
	if collider is Player:
		var p := collider as Player
		if p.wears_stone_armor():
			# It glances off the stone plaques.
			Sfx.play_at(GLANCE, at, 2.0, 0.08, &"Tomb", 30.0)
			if p.is_local:
				p.add_shake(0.25)
			if is_instance_valid(source) and source.has_method(&"bolt_glanced"):
				source.call(&"bolt_glanced")
		elif p.is_local:
			p.apply_damage(damage, source, "DEATH_CROSSBOW")
			p.add_shake(0.6)
		queue_free()
		return
	# A target of its own (the body, or a node it belongs to).
	var target := collider
	for i in 3:
		if target != null and target.has_method(&"bolt_hit"):
			target.call(&"bolt_hit", at)
			return
		target = target.get_parent() if target != null else null
	Sfx.play_random_at(HIT_WALL, at, 0.0, 0.08, &"Tomb", 30.0)
	Stealth.make_noise(at, 10.0, source)

func _build() -> void:
	var mi := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.025, 0.025, 0.65)
	mi.mesh = shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.12)
	mi.material_override = mat
	add_child(mi)
	var tip := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.05, 0.1, 0.03)
	tip.mesh = prism
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.5, 0.4, 0.22)
	bronze.metallic = 0.7
	tip.material_override = bronze
	tip.rotation_degrees.x = -90
	tip.position.z = -0.37
	add_child(tip)
