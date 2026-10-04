extends SceneTree
## Dev smoke test for the core autoloads (run headless).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var root := get_root()
	for name in ["Settings", "Sfx", "Dialogue", "Quest", "Stealth", "Game"]:
		print(name, " -> ", root.get_node_or_null(name) != null)
	TranslationServer.set_locale("ro")
	print("ro: ", tr("DLG_INTRO_1"))
	TranslationServer.set_locale("en")
	print("en: ", tr("DLG_INTRO_1"))
	var dlg := root.get_node("Dialogue")
	dlg.line_started.connect(func(_id, spk, text, dur, _x): print("  [line] ", spk, ": ", text, " (", snapped(dur, 0.1), "s)"))
	var t0 := Time.get_ticks_msec()
	var ok: bool = await dlg.play(&"intro")
	print("intro finished=", ok, " after ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	var quest := root.get_node("Quest")
	quest.start_at(&"talk_apprentice")
	print("quest at ", quest.current(), " objective=", tr(quest.objective_key()))
	print("complete wrong step -> ", quest.complete(&"take_lamp"))
	print("complete right step -> ", quest.complete(&"talk_apprentice"), " now ", quest.current())
	quit()
