extends CanvasLayer

const VITALITY_SOURCES: Array[Texture2D] = [
	preload("res://scenes/ui/Vitalitate/vitality_0_full.png"),
	preload("res://scenes/ui/Vitalitate/vitality_1.png"),
	preload("res://scenes/ui/Vitalitate/vitality_2.png"),
	preload("res://scenes/ui/Vitalitate/vitality_3.png"),
	preload("res://scenes/ui/Vitalitate/vitality_4.png"),
	preload("res://scenes/ui/Vitalitate/vitality_5.png"),
	preload("res://scenes/ui/Vitalitate/vitality_6.png"),
	preload("res://scenes/ui/Vitalitate/vitality_7.png"),
	preload("res://scenes/ui/Vitalitate/vitality_8_empty.png"),
]

const VITALITY_REGIONS: Array[Rect2] = [
	Rect2(20, 143, 545, 102),
	Rect2(20, 143, 545, 102),
	Rect2(20, 143, 545, 102),
	Rect2(20, 142, 545, 102),
	Rect2(20, 157, 545, 101),
	Rect2(20, 144, 545, 102),
	Rect2(20, 144, 545, 101),
	Rect2(20, 142, 545, 103),
	Rect2(20, 142, 545, 102),
]

@export var vitality_path: NodePath = NodePath("")
@export var vitality_search_name: String = "Vitality"

var vitality_step := 0
var vitality_textures: Array[AtlasTexture] = []
var vitality: TextureRect = null
var vitality_base_position := Vector2.ZERO
var damage_tween: Tween


func _ready() -> void:
	add_to_group("hud_damage")
	for i in VITALITY_SOURCES.size():
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = VITALITY_SOURCES[i]
		atlas_texture.region = VITALITY_REGIONS[i]
		vitality_textures.append(atlas_texture)

	vitality = _resolve_vitality_node()
	if vitality == null:
		push_warning("[hud_debug] Nu am gasit TextureRect-ul de vitalitate. Damage HUD dezactivat pana apare nodul.")
		return
	_set_vitality_step(0)
	vitality_base_position = vitality.position


func apply_damage(steps: int = 1) -> void:
	if not _ensure_vitality_node() or vitality_textures.is_empty():
		return
	var next_step: int = mini(vitality_step + steps, vitality_textures.size() - 1)
	if next_step == vitality_step:
		return

	_play_damage_feedback(next_step)


func _set_vitality_step(step: int) -> void:
	if not _ensure_vitality_node() or vitality_textures.is_empty():
		return
	vitality_step = clampi(step, 0, vitality_textures.size() - 1)
	vitality.texture = vitality_textures[vitality_step]


func _play_damage_feedback(next_step: int) -> void:
	if not _ensure_vitality_node():
		return
	if damage_tween:
		damage_tween.kill()

	vitality.position = vitality_base_position
	vitality.modulate = Color.WHITE

	damage_tween = create_tween()
	damage_tween.tween_property(vitality, "modulate", Color(0.78, 0.38, 0.28, 1.0), 0.05)
	damage_tween.parallel().tween_property(vitality, "position", vitality_base_position + Vector2(-3.0, 1.0), 0.05)
	damage_tween.tween_property(vitality, "position", vitality_base_position + Vector2(3.0, -1.0), 0.04)
	damage_tween.tween_callback(_set_vitality_step.bind(next_step))
	damage_tween.tween_property(vitality, "position", vitality_base_position, 0.05)
	damage_tween.parallel().tween_property(vitality, "modulate", Color.WHITE, 0.14)


func _ensure_vitality_node() -> bool:
	if vitality != null and is_instance_valid(vitality):
		return true
	vitality = _resolve_vitality_node()
	if vitality == null:
		return false
	vitality_base_position = vitality.position
	return true


func _resolve_vitality_node() -> TextureRect:
	if not vitality_path.is_empty():
		var explicit_node := get_node_or_null(vitality_path) as TextureRect
		if explicit_node != null:
			return explicit_node
	var scene_root := get_tree().current_scene if is_inside_tree() else null
	if scene_root == null or vitality_search_name == "":
		return null
	return scene_root.find_child(vitality_search_name, true, false) as TextureRect
