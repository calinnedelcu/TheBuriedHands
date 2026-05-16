class_name SpikeTrap
extends Node3D

## Viteza minima de cadere (m/s, pozitiv = in jos) pentru kill instant.
@export var instant_kill_velocity: float = 2.5
@export var continuous_damage_steps: int = 2
@export var continuous_damage_interval: float = 1.0
@export var player_group: String = "player"
@export var hud_damage_group: String = "hud_damage"

@onready var _area: Area3D = $DamageArea

var _bodies_on_spikes: Array[Node] = []
var _damage_timer: float = 0.0
var _fail_triggered: bool = false

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if _bodies_on_spikes.is_empty():
		return
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = continuous_damage_interval
		_apply_damage(continuous_damage_steps)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(player_group):
		return
	var fall_speed := 0.0
	if "velocity" in body:
		fall_speed = -(body.velocity as Vector3).y

	if fall_speed >= instant_kill_velocity:
		_apply_damage(8)
		if not _fail_triggered and has_node("/root/GameEvents"):
			_fail_triggered = true
			get_node("/root/GameEvents").fail("Ai căzut în tepe")
	else:
		if not _bodies_on_spikes.has(body):
			_bodies_on_spikes.append(body)
		_apply_damage(continuous_damage_steps)
		_damage_timer = continuous_damage_interval

func _on_body_exited(body: Node) -> void:
	_bodies_on_spikes.erase(body)

func _apply_damage(steps: int) -> void:
	var hud := get_tree().get_first_node_in_group(hud_damage_group)
	if hud and hud.has_method("apply_damage"):
		hud.apply_damage(steps)
