extends SceneTree
## test_11_locale (11 §1.9): the language stands before the first screen. Run as a child process with
## `-- --lang=<code>`: in the main loop's first callback — no scene exists yet — it prints what Game._init applied
## (no class_name / autoload identifiers in an -s script, 02_TECH §13.2 rule 4: the classes come per load()).


func _initialize() -> void:
	var tx: GDScript = load("res://core/data/tx.gd") as GDScript
	var game: Node = root.get_node_or_null("Game")
	print("BOOT_LANG: game=%s tx=%s locale=%s root_auto=%d scenes=%d" % [game != null, str(tx.call("lang")),
		TranslationServer.get_locale(), root.auto_translate_mode, root.get_child_count()])
	await process_frame
	print("BOOT_LANG_READY: root_auto=%d translated=%s" % [root.auto_translate_mode,
		str(tx.call("t", "Gift"))])
	quit(0)
