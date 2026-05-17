extends Node3D

@export var speed: float = 18.0
@export var lifetime: float = 1.5

var velocity: Vector3 = Vector3.ZERO
var damage_steps: int = 1
var player_group: String = "player"
var hud_damage_group: String = "hud_damage"
var high_bolt_duckable: bool = true
var crouch_safe_hit_height: float = 0.7
var crawl_safe_hit_height: float = 0.38

var _t: float = 0.0
var _hit_applied: bool = false

func _ready() -> void:
	for c in get_children():
		if c is Area3D:
			(c as Area3D).body_entered.connect(_on_body_entered)
			break

func _process(delta: float) -> void:
	if not _hit_applied:
		global_position += velocity * delta
	_t += delta
	if _t >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _hit_applied:
		return
	var n: Node = body
	var depth := 4
	while n != null and depth > 0:
		if n.is_in_group(player_group):
			if _player_ducked_under(n):
				return
			_hit_applied = true
			if n.has_method("apply_damage"):
				n.call("apply_damage", damage_steps, self)
			else:
				var hud := get_tree().get_first_node_in_group(hud_damage_group)
				if hud and hud.has_method("apply_damage"):
					hud.apply_damage(damage_steps)
			queue_free()
			return
		n = n.get_parent()
		depth -= 1

func _player_ducked_under(collider: Node) -> bool:
	if not high_bolt_duckable:
		return false
	if not (collider is Node3D):
		return false
	var rel_y := global_position.y - (collider as Node3D).global_position.y
	if collider.has_method("is_crawling") and bool(collider.call("is_crawling")):
		return rel_y >= crawl_safe_hit_height
	if collider.has_method("is_crouching") and bool(collider.call("is_crouching")):
		return rel_y >= crouch_safe_hit_height
	return false
