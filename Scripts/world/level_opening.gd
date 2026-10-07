@tool
class_name LevelOpening
extends Resource
## A hole in one face of a LevelBox: a doorway, the mouth of a tunnel, a
## shaft through a floor. On a wall, `offset.x` is the centre along the wall
## (from its middle) and `offset.y` the height of the bottom edge above the
## floor; on the floor or ceiling, `offset` is the centre in x and z.

enum Face { FLOOR, CEILING, WEST, EAST, NORTH, SOUTH }

@export var face := Face.NORTH:
	set(v):
		face = v
		emit_changed()
@export var offset := Vector2.ZERO:
	set(v):
		offset = v
		emit_changed()
@export var size := Vector2(2.4, 3.0):
	set(v):
		size = v
		emit_changed()

static func make(on: Face, at: Vector2, extent: Vector2) -> LevelOpening:
	var o := LevelOpening.new()
	o.face = on
	o.offset = at
	o.size = extent
	return o
