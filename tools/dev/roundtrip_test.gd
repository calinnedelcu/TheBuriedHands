extends SceneTree
## Dev test: load a scene with editor state, repack it and save to a temp path,
## to check that programmatic scene edits round-trip without losing data.

func _initialize() -> void:
	var src := "res://scenes/tomb_layout.tscn"
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/roundtrip.tscn"
	var packed: PackedScene = load(src)
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var repacked := PackedScene.new()
	var err := repacked.pack(root)
	print("pack err=", err)
	err = ResourceSaver.save(repacked, out)
	print("save err=", err, " -> ", out)
	root.free()
	quit()
