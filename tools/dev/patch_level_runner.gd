extends Node
## Applies small, idempotent fixes to scenes/level/mausoleum.tscn in place, so
## edits made in the editor are kept. Add a patch function, call it from _run.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/patch_level_runner.gd

const LEVEL := "res://scenes/level/mausoleum.tscn"

var root: Node3D
var _log: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	root = (load(LEVEL) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	get_tree().root.add_child(root)
	await get_tree().physics_frame
	_localize_drain()
	get_tree().root.remove_child(root)
	var packed := PackedScene.new()
	packed.pack(root)
	print("save err=", ResourceSaver.save(packed, LEVEL))
	for line in _log:
		print("  ", line)
	root.free()
	get_tree().quit()

## Makes `node` part of the level itself instead of an instance of its scene
## (the editor's "Make Local"), so children removed from it stay removed.
func _make_local(node: Node) -> void:
	node.scene_file_path = ""
	for c in node.find_children("*", "", true, false):
		c.owner = root

## The drain was an instance of the jam's squeeze-tunnel scene; its old
## interactable and audio nodes kept coming back. Keep only what DrainCrawl uses.
func _localize_drain() -> void:
	var drain := root.get_node_or_null("Drain")
	if drain == null:
		return
	if drain.scene_file_path != "":
		_make_local(drain)
	for n in ["SqueezeAudio", "GravelAudio", "StonesAudio", "CinematicAudio", "PassageGate/GateVisual", "CollapseBlocker/CollisionShape3D", "EntryBody/Interactable", "SqueezeFocus", "CollapseFocus"]:
		var c := drain.get_node_or_null(n)
		if c != null:
			c.get_parent().remove_child(c)
			c.free()
			_log.append("drain: removed " + n)
	for c in drain.find_children("*", "", true, false):
		var s := c.get_script() as Script
		if s != null and not s.resource_path.begins_with("res://Scripts/world") and not s.resource_path.begins_with("res://Scripts/interaction"):
			_log.append("drain: WARNING old script on %s: %s" % [drain.get_path_to(c), s.resource_path])
