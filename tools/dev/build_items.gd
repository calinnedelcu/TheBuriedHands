extends SceneTree
## Writes the ItemData resources in res://data/items. Re-run after editing.

const ICONS := "res://scenes/ui/Slots/Icons/"
const VIS := "res://scenes/items/visuals/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/items"))
	var mining := _sounds(["impactMining_000", "impactMining_001", "impactMining_002"])
	var wood := _sounds(["impactPlank_medium_000", "impactPlank_medium_001", "impactPlank_medium_002"])
	var shards := _sounds(["impactGlass_light_000", "impactGlass_light_001", "impactGlass_light_002"])
	_item("chisel", "ITEM_CHISEL", "ITEM_DESC_CHISEL", ICONS + "icon_chisel.png", VIS + "chisel.tscn", 1, false, true, true, 14.0, 0.4, mining)
	_item("wedge", "ITEM_WEDGE", "ITEM_DESC_WEDGE", ICONS + "icon_wedge.png", VIS + "wedge.tscn", 1, false, true, true, 14.0, 0.5, wood)
	_item("hammer", "ITEM_HAMMER", "ITEM_DESC_HAMMER", ICONS + "icon_hammer.png", VIS + "hammer.tscn", 1, false, true, true, 18.0, 1.2, wood)
	_item("ceramic", "ITEM_CERAMIC", "ITEM_DESC_CERAMIC", ICONS + "icon_ceramic.png", VIS + "ceramic.tscn", 6, false, true, true, 20.0, 0.3, shards)
	_item("clay_bowl", "ITEM_CLAY_BOWL", "", ICONS + "icon_clay_bowl.png", "res://scenes/items/claybowl.glb", 1, false, false, false, 0.0, 1.0, [])
	_item("vase", "ITEM_VASE", "", "res://assets/ui/icons/icon_jar.png", "res://scenes/items/visuals/jar.tscn", 1, false, false, false, 0.0, 1.5, [])
	_item("vase_full", "ITEM_VASE_FULL", "", "res://assets/ui/icons/icon_jar_full.png", "res://scenes/items/visuals/jar_full.tscn", 1, false, false, false, 0.0, 6.0, [])
	_item("cloth", "ITEM_CLOTH", "ITEM_DESC_CLOTH", ICONS + "icon_wet_cloth.png", VIS + "cloth.tscn", 1, true, false, false, 0.0, 0.2, [])
	_item("register", "ITEM_REGISTER", "ITEM_DESC_REGISTER", "res://assets/ui/icons/icon_register.png", VIS + "register.tscn", 1, true, false, false, 0.0, 0.4, [])
	# The two halves of the tiger tally (tools/blender/build_tally.py).
	_item("tally_wei", "ITEM_TALLY_WEI", "ITEM_DESC_TALLY_WEI", "res://assets/ui/icons/icon_tally_wei.png", VIS + "tally_wei.tscn", 1, true, false, false, 0.0, 0.3, [])
	_item("tally_pit", "ITEM_TALLY_PIT", "ITEM_DESC_TALLY_PIT", "res://assets/ui/icons/icon_tally_pit.png", VIS + "tally_pit.tscn", 1, true, false, false, 0.0, 0.3, [])
	# Worn, not held (tools/blender/build_stone_armor.py).
	_item("stone_armor", "ITEM_STONE_ARMOR", "ITEM_DESC_STONE_ARMOR", "res://assets/ui/icons/icon_stone_armor.png", VIS + "stone_armor.tscn", 1, true, false, false, 0.0, 15.0, [])
	quit()

func _sounds(names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n in names:
		var path := "res://audio/sfx/impacts/%s.ogg" % n
		if ResourceLoader.exists(path):
			out.append(load(path))
	return out

func _item(id: String, name_key: String, desc_key: String, icon: String, scene: String, stack: int, key_item: bool, droppable: bool, throwable: bool, noise: float, mass: float, impacts: Array[AudioStream]) -> void:
	var item := ItemData.new()
	item.id = StringName(id)
	item.name_key = name_key
	item.description_key = desc_key
	if ResourceLoader.exists(icon):
		item.icon = load(icon)
	else:
		push_warning("missing icon " + icon)
	item.world_scene = load(scene)
	item.max_stack = stack
	item.key_item = key_item
	item.droppable = droppable
	item.throwable = throwable
	item.throw_noise_radius = noise
	item.mass = mass
	item.impact_sounds = impacts
	var path := "res://data/items/%s.tres" % id
	print(path, " err=", ResourceSaver.save(item, path))
