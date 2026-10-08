@tool
class_name PropMaterials
extends Node3D
## Gives an imported prop the game's own materials, matched by the names
## its Blender build gave them (tools/blender/build_treasures.py,
## build_tally.py, build_stone_armor.py): bronze gets the patina shader,
## gold, gold inlay, jade and limestone their tuned looks.

const MAP := {
	"Bronze": preload("res://assets/materials/props/bronze.tres"),
	"Gold": preload("res://assets/materials/props/gold.tres"),
	"GoldInlay": preload("res://assets/materials/props/gold_inlay.tres"),
	"Jade": preload("res://assets/materials/props/jade.tres"),
	"Limestone": preload("res://assets/materials/props/limestone.tres"),
}

func _ready() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and MAP.has(m.resource_name):
				mi.set_surface_override_material(i, MAP[m.resource_name])
