class_name KillZone
extends Area3D
## Instant death volume (spike pits, deep mercury, bottomless shafts).

@export var death_reason := "DEATH_SPIKES"

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	# Each co-op machine looks after its own player's life.
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player and (body as Player).is_local:
			(body as Player).kill(death_reason))
