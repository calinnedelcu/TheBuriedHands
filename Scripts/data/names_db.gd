class_name NamesDB
extends RefCounted
## The makers' names pressed into the clay of the figures, as on the real
## terracotta army (where the palace workshops stamped "Gong" and the
## Xianyang potters their city and name). Each: id, the characters, and the
## translation key of the line read.

const NAMES := [
	{"id": &"gong_jiang", "han": "宫疆", "key": "NAME_GONG_JIANG"},
	{"id": &"xianyang_yi", "han": "咸阳衣", "key": "NAME_XIANYANG_YI"},
	{"id": &"gong_de", "han": "宫得", "key": "NAME_GONG_DE"},
	{"id": &"xianyang_ye", "han": "咸阳野", "key": "NAME_XIANYANG_YE"},
	{"id": &"gong_cang", "han": "宫藏", "key": "NAME_GONG_CANG"},
	{"id": &"xianyang_qing", "han": "咸阳庆", "key": "NAME_XIANYANG_QING"},
	{"id": &"gong_shui", "han": "宫水", "key": "NAME_GONG_SHUI"},
	{"id": &"xianyang_ci", "han": "咸阳赐", "key": "NAME_XIANYANG_CI"},
]

static func find(id: StringName) -> Dictionary:
	for n in NAMES:
		if n["id"] == id:
			return n
	return {}

static func flag(id: StringName) -> StringName:
	return StringName("name_" + String(id))

## The names read so far, in the order of NAMES.
static func found() -> Array:
	return NAMES.filter(func(n): return bool(Game.get_flag(flag(n["id"]))))
