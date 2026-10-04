class_name ThrownItem
extends RigidBody3D
## An item thrown by the player. The first impact makes noise guards can hear
## (and can set off pressure plates); afterwards it settles and turns back into
## a pickup. Pottery shatters instead.

@export var item_id: StringName

var _item: ItemData
var _impacted := false
var _rest_time := 0.0

func _ready() -> void:
	_item = ItemDB.get_item(item_id)
	add_to_group(&"trap_trigger")
	collision_layer = 8
	collision_mask = 1 | 8
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	mass = _item.mass if _item != null else 0.5
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	shape.shape = sphere
	add_child(shape)
	if _item != null and _item.world_scene != null:
		add_child(_item.world_scene.instantiate())
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node) -> void:
	if _impacted:
		return
	_impacted = true
	var radius := _item.throw_noise_radius if _item != null else 12.0
	Stealth.make_noise(global_position, radius, self)
	if _item != null:
		Sfx.play_random_at(_item.impact_sounds, global_position, 2.0, 0.1, &"Tomb", 45.0)
	if item_id == &"ceramic":
		_shatter()

func _physics_process(delta: float) -> void:
	if not _impacted:
		return
	if linear_velocity.length() < 0.25 and angular_velocity.length() < 1.0:
		_rest_time += delta
		if _rest_time > 0.6:
			_settle()
	else:
		_rest_time = 0.0

func _shatter() -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14
	burst.lifetime = 0.9
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3(0, -16, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.01, 0.025)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.33, 0.2)
	mesh.material = mat
	burst.mesh = mesh
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.finished.connect(burst.queue_free)
	queue_free()

func _settle() -> void:
	set_physics_process(false)
	var pickup := preload("res://scenes/items/pickup.tscn").instantiate()
	pickup.set(&"item_id", item_id)
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3.DOWN * 0.08
	pickup.rotation.y = rotation.y
	queue_free()
