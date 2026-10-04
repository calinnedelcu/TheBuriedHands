class_name ItemDB
extends RefCounted
## Looks up ItemData resources by id from res://data/items.

const DIR := "res://data/items"

static var _cache: Dictionary = {}

static func get_item(id: StringName) -> ItemData:
	if _cache.is_empty():
		_load_all()
	return _cache.get(id)

static func all() -> Array:
	if _cache.is_empty():
		_load_all()
	return _cache.values()

static func _load_all() -> void:
	for file in ResourceLoader.list_directory(DIR):
		if not file.ends_with(".tres"):
			continue
		var item := load(DIR.path_join(file)) as ItemData
		if item != null and item.id != &"":
			_cache[item.id] = item
