extends RigidBody3D

@export var impact_noise: float = 2.4
@export var lifetime_after_impact: float = 1.4
@export var max_lifetime: float = 8.0

var _has_impacted: bool = false
var _t_total: float = 0.0
var _t_post: float = 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_t_total += delta
	if _t_total >= max_lifetime:
		queue_free()
		return
	if _has_impacted:
		_t_post += delta
		if _t_post >= lifetime_after_impact:
			queue_free()

func _on_body_entered(_body: Node) -> void:
	if _has_impacted:
		return
	_has_impacted = true
	if has_node("/root/NoiseBus"):
		get_node("/root/NoiseBus").emit_noise(global_position, impact_noise, self)
	var sfx: AudioStreamPlayer3D = get_node_or_null("ImpactAudio")
	if sfx:
		sfx.pitch_scale = randf_range(0.92, 1.1)
		sfx.play()
