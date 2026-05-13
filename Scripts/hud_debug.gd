extends CanvasLayer

const VITALITY_SOURCES: Array[Texture2D] = [
	preload("res://scenes/ui/vitality_0_full.png"),
	preload("res://scenes/ui/vitality_1.png"),
	preload("res://scenes/ui/vitality_2.png"),
	preload("res://scenes/ui/vitality_3.png"),
	preload("res://scenes/ui/vitality_4.png"),
	preload("res://scenes/ui/vitality_5.png"),
	preload("res://scenes/ui/vitality_6.png"),
	preload("res://scenes/ui/vitality_7.png"),
	preload("res://scenes/ui/vitality_8_empty.png"),
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

@onready var vitality: TextureRect = $Vitality

var vitality_step := 0
var vitality_textures: Array[AtlasTexture] = []
var vitality_base_position := Vector2.ZERO
var damage_tween: Tween


func _ready() -> void:
	add_to_group("hud_damage")
	for i in VITALITY_SOURCES.size():
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = VITALITY_SOURCES[i]
		atlas_texture.region = VITALITY_REGIONS[i]
		vitality_textures.append(atlas_texture)

	_set_vitality_step(0)
	vitality_base_position = vitality.position


func apply_damage(steps: int = 1) -> void:
	var next_step: int = mini(vitality_step + steps, vitality_textures.size() - 1)
	if next_step == vitality_step:
		return

	_play_damage_feedback(next_step)


func _set_vitality_step(step: int) -> void:
	vitality_step = clampi(step, 0, vitality_textures.size() - 1)
	vitality.texture = vitality_textures[vitality_step]


func _play_damage_feedback(next_step: int) -> void:
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
