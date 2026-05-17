extends RigidBody3D

## Unealta aruncata cu G. La primul impact emite zgomot (distragere gardieni).
## Cand se opreste, se converteste in pickup_item normal ca sa o poti ridica inapoi.

const _PICKUP_SCENE := preload("res://scenes/items/pickup_item.tscn")
const _DROP_STREAM := preload("res://audio/sfx/tools/tool_drop.mp3")
const _DROP_PITCH_VARIATIONS: Array[float] = [0.9, 1.0, 1.12]

@export var item_id: String = ""
@export var impact_noise: float = 4.5
@export var impact_sfx_volume_db: float = 8.0
@export var rest_speed_threshold: float = 0.35
@export var rest_time_required: float = 0.7

var _has_impacted: bool = false
var _rest_timer: float = 0.0
var _converted: bool = false

func _ready() -> void:
	add_to_group("trap_trigger")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _converted or not _has_impacted:
		return
	var v := linear_velocity.length()
	var w := angular_velocity.length()
	if v < rest_speed_threshold and w < 1.0:
		_rest_timer += delta
		if _rest_timer >= rest_time_required:
			_convert_to_pickup()
	else:
		_rest_timer = 0.0

func _on_body_entered(_body: Node) -> void:
	if _has_impacted:
		return
	_has_impacted = true
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(global_position, impact_noise, self)
	_play_drop_sfx()

func _play_drop_sfx() -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = _DROP_STREAM
	# Busul "Tomb" are reverb (predelay 45ms, room 0.85, wet 0.32) — da senzatia
	# de ecou de cavernă pentru obiectele care cad pe piatra.
	sfx.bus = &"Tomb"
	sfx.volume_db = impact_sfx_volume_db
	# unit_size mic = sunetul scade rapid cu distanta, sunete mai positional.
	sfx.unit_size = 2.5
	sfx.max_distance = 30.0
	sfx.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	sfx.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	sfx.pitch_scale = _DROP_PITCH_VARIATIONS[randi() % _DROP_PITCH_VARIATIONS.size()] * randf_range(0.96, 1.04)
	add_child(sfx)
	# Forteaza pozitia globala sa fie cea a body-ului in momentul redarii
	# (ca sa nu fie ambigua daca body-ul s-a miscat intre add_child si play).
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _convert_to_pickup() -> void:
	_converted = true
	if item_id == "":
		queue_free()
		return
	var pickup := _PICKUP_SCENE.instantiate()
	if "kind" in pickup:
		pickup.kind = 0
	if "item_id" in pickup:
		pickup.item_id = item_id
	if "stack" in pickup:
		pickup.stack = 1
	var world := get_tree().current_scene
	if world == null:
		queue_free()
		return
	var landed_position := global_position
	world.add_child(pickup)
	# Asezam pickup-ul pe sol cu yaw pastrat din ultima orientare, dar fara
	# inclinare (pitch/roll = 0) ca sa nu para ca pluteste pe-o latura.
	var yaw := global_rotation.y
	pickup.global_position = landed_position
	pickup.rotation = Vector3(0.0, yaw, 0.0)
	queue_free()
