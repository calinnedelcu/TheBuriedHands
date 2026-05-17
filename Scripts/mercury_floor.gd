extends Node3D

@export var player_group: String = "player"
@export_node_path("Area3D") var area_path: NodePath = NodePath("Area")

var _area: Area3D = null

func _ready() -> void:
	add_to_group("mercury_floor")
	_area = get_node_or_null(area_path) as Area3D
	if _area != null and not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if player_group != "" and not body.is_in_group(player_group):
		return
	if body.has_method("max_health_value") and body.has_method("apply_damage"):
		var max_hp: int = int(body.call("max_health_value"))
		body.call("apply_damage", max_hp, self)
