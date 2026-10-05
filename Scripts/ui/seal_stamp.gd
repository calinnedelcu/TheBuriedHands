class_name SealStamp
extends Control
## A vermilion seal with characters cut in white, like the stamps pressed on
## scrolls: the chapter cards carry the chapter's numeral, the ending 工匠
## ("craftsmen"), the mark the nameless builders never got to leave.

const FONT := preload("res://assets/fonts/MaShanZheng-Seal.ttf")
const VERMILION := Color(0.7, 0.14, 0.09)
const PAPER := Color(0.93, 0.88, 0.79)

## Characters, stacked top to bottom (one or two).
@export var text := "工匠":
	set(value):
		text = value
		queue_redraw()
@export var side := 92.0:
	set(value):
		side = value
		custom_minimum_size = Vector2(side, side)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(side, side)

func _draw() -> void:
	var k := side / 92.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	# Slightly uneven edges, like a real impression.
	var pts := PackedVector2Array()
	var corners := [Vector2(0, 0), Vector2(side, 0), Vector2(side, side), Vector2(0, side)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for j in 8:
			pts.append(a.lerp(b, j / 8.0) + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)) * k)
	draw_colored_polygon(pts, VERMILION)
	draw_rect(Rect2(Vector2.ONE * 6.0 * k, Vector2.ONE * (side - 12.0 * k)), PAPER, false, maxf(1.0, 2.0 * k))
	var count := text.length()
	var size := int((38.0 if count > 1 else 60.0) * k)
	for i in count:
		var ch := text[i]
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var baseline := (44.0 + i * 36.0) * k if count > 1 else 66.0 * k
		draw_string(FONT, Vector2((side - w) * 0.5, baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, PAPER)
	# Specks where the ink didn't take.
	for j in 26:
		var at := Vector2(rng.randf_range(4.0, side - 4.0), rng.randf_range(4.0, side - 4.0))
		draw_circle(at, rng.randf_range(0.5, 1.6) * k, Color(PAPER, rng.randf_range(0.25, 0.7)))
