extends TestCase
## 11-L1 (11 §1.12, SP-8, R11): the lint against German texts outside Tx (tests/tools/i18n/literal_lint.gd — a literal
## that looks German: an umlaut, ß, „ or a word of a small stopword list; in player code; outside Tx.t / Tx.n / Tx.m,
## the developer calls and files, and lines with "# no-i18n: <reason>"). PENDING = the findings per file when 11-L1
## landed (911 in 91 files, with the texts 11-P1 brought): L2 moves its areas to Tx and lowers or removes their entries
## — the list only shrinks. A file outside PENDING must stay clean, a listed one at its exact count (fewer: lower the
## number; more: a new German text outside Tx — wrap it in Tx.t, R11). tools/i18n.sh lint prints the current table
## and, with --file, the lines.

const Lint := preload("res://tests/tools/i18n/literal_lint.gd")
## file → German literals outside Tx (only shrinks).
const PENDING: Dictionary = {
	"res://art/kit/damage_number.gd": 1,
	"res://art/kit/prop_kit.gd": 1,
	"res://autoload/game.gd": 8,
	"res://autoload/show.gd": 5,
	"res://core/live/run_sim.gd": 1,
	"res://core/progression/save_codec.gd": 3,
	"res://core/rt/rt_sim.gd": 1,
	"res://core/season/cast_sim.gd": 5,
	"res://core/season/season_rules.gd": 5,
	"res://core/season/sleep_text.gd": 68,
	"res://core/show/mod_line_filter.gd": 1,
	"res://core/show/persona_text.gd": 33,
	"res://core/stempel/sd_rulebook.gd": 3,
	"res://scenes/boot/boot.gd": 6,
	"res://scenes/combat/ui/combat_hud.gd": 9,
	"res://scenes/combat/ui/combat_input.gd": 1,
	"res://scenes/combat/ui/combat_results.gd": 9,
	"res://scenes/combat/ui/combat_style.gd": 12,
	"res://scenes/combat/ui/combat_view.gd": 1,
	"res://scenes/combat/ui/hint_cards.gd": 25,
	"res://scenes/combat/ui/item_wheel.gd": 2,
	"res://scenes/combat/ui/tactic_panel.gd": 6,
	"res://scenes/combat/ui/unit_frames.gd": 2,
	"res://scenes/exploration/chest_interactable.gd": 7,
	"res://scenes/exploration/event_interactable.gd": 22,
	"res://scenes/exploration/exploration.gd": 5,
	"res://scenes/exploration/gate_interactable.gd": 4,
	"res://scenes/exploration/pull_rules.gd": 4,
	"res://scenes/exploration/stairs_interactable.gd": 1,
	"res://scenes/safe_room/lootbox_opening.gd": 13,
	"res://scenes/safe_room/safe_room.gd": 11,
	"res://scenes/safe_room/vending_menu.gd": 12,
	"res://scenes/stempel/sd_akte.gd": 6,
	"res://scenes/stempel/sd_album.gd": 18,
	"res://scenes/stempel/sd_board.gd": 3,
	"res://scenes/stempel/sd_card_view.gd": 7,
	"res://scenes/stempel/sd_deck_builder.gd": 18,
	"res://scenes/stempel/sd_extras.gd": 2,
	"res://scenes/stempel/sd_hall.gd": 9,
	"res://scenes/stempel/sd_hall_akte.gd": 15,
	"res://scenes/stempel/sd_layout.gd": 4,
	"res://scenes/stempel/sd_menu.gd": 17,
	"res://scenes/stempel/sd_results.gd": 7,
	"res://scenes/stempel/sd_rules_page.gd": 2,
	"res://scenes/stempel/sd_screen.gd": 1,
	"res://scenes/stempel/sd_style.gd": 7,
	"res://scenes/stempel/sd_table.gd": 22,
	"res://scenes/stempel/sd_texts.gd": 39,
	"res://scenes/stempel/sd_tutorial.gd": 4,
	"res://scenes/title/credits.gd": 16,
	"res://scenes/title/game_over.gd": 8,
	"res://scenes/title/hero_select.gd": 5,
	"res://scenes/title/intro.gd": 14,
	"res://scenes/title/name_entry.gd": 12,
	"res://scenes/title/persona_casting.gd": 18,
	"res://scenes/title/slot_select.gd": 16,
	"res://scenes/title/title.gd": 5,
	"res://scenes/title/title_flow.gd": 2,
	"res://scenes/ui/achievements_menu.gd": 1,
	"res://scenes/ui/bestiary_menu.gd": 5,
	"res://scenes/ui/bets_menu.gd": 8,
	"res://scenes/ui/confirm_dialog.gd": 1,
	"res://scenes/ui/equipment_menu.gd": 6,
	"res://scenes/ui/event_info.gd": 15,
	"res://scenes/ui/event_lobby.gd": 8,
	"res://scenes/ui/exploration_hud.gd": 12,
	"res://scenes/ui/explore_target.gd": 2,
	"res://scenes/ui/floor_summary.gd": 7,
	"res://scenes/ui/input_glyph.gd": 1,
	"res://scenes/ui/inventory_menu.gd": 10,
	"res://scenes/ui/level_badge.gd": 1,
	"res://scenes/ui/logout_dialog.gd": 12,
	"res://scenes/ui/menu_base.gd": 1,
	"res://scenes/ui/mod_dialog.gd": 1,
	"res://scenes/ui/osk_keyboard.gd": 4,
	"res://scenes/ui/party_menu.gd": 8,
	"res://scenes/ui/pause_menu.gd": 6,
	"res://scenes/ui/persona_card.gd": 5,
	"res://scenes/ui/persona_picker.gd": 11,
	"res://scenes/ui/recall.gd": 36,
	"res://scenes/ui/run_result.gd": 4,
	"res://scenes/ui/settings_menu.gd": 32,
	"res://scenes/ui/show_overlay.gd": 13,
	"res://scenes/ui/skills_menu.gd": 39,
	"res://scenes/ui/talent_show.gd": 19,
	"res://scenes/ui/talent_text.gd": 13,
	"res://scenes/ui/talent_tree.gd": 24,
	"res://scenes/ui/toast_stack.gd": 3,
	"res://scenes/ui/twist_fx.gd": 3,
	"res://scenes/ui/ui_util.gd": 18,
	"res://scenes/ui/wake_summary.gd": 18,
}


func test_no_new_german_text_outside_tx() -> void:
	var problems: PackedStringArray = []
	var scanned: int = 0
	var total: int = 0
	for path: String in Lint.files():
		scanned += 1
		var found: PackedStringArray = Lint.findings(FileAccess.get_file_as_string(path))
		total += found.size()
		var want: int = int(PENDING.get(path, 0))
		if found.size() == want:
			continue
		if found.size() < want:
			problems.append("%s: %d German literals outside Tx, PENDING says %d — lower its entry (or take it out at 0)"
				% [path, found.size(), want])
		else:
			problems.append("%s: %d German literals outside Tx, PENDING allows %d — wrap the new text in Tx.t (or mark a "
				% [path, found.size(), want] + "line # no-i18n: <reason>):\n  " + "\n  ".join(found))
	assert_gt(scanned, 250, "the scripts of scenes / autoload / core / art")
	assert_eq(problems, PackedStringArray(), "11 §1.12 (tools/i18n.sh lint shows the table):\n" + "\n".join(problems))
	print("[INFO] %d German literals outside Tx in %d files (PENDING)" % [total, PENDING.size()])


func test_pending_lists_only_existing_files() -> void:
	for path: String in PENDING:
		assert_true(FileAccess.file_exists(path), path + " (a removed file leaves PENDING)")
		assert_gt(int(PENDING[path]), 0, path + ": an entry at 0 leaves PENDING")
		assert_eq(Lint.dev_reason(path), "", path + " is developer code, not linted")


func test_the_lint_sees_what_it_should() -> void:
	var src: String = "\n".join(PackedStringArray([
		"var a: String = Tx.t(\"Zurück\")",
		"var b: String = tr(\"Zurück\")",
		"var c: Label = UiUtil.label(\"Neues Spiel\")",
		"push_warning(\"Datei nicht gefunden: %s\" % p)",
		"assert(ok, \"Das darf nicht sein\")",
		"var d: String = \"Größe\"  # no-i18n: a key of the old save format",
		"var e: String = \"ui_cancel\"",
		"var f: String = Tx.t(\"Etage %d\") % n + \" · \" + str(\"Stufe\")",
		"var g: Dictionary = {\"common\": \"Gewöhnlich\"}",
		"var h: String = Tx.n(\"{count} Kampf\", \"{count} Kämpfe\", n)",
		"var i: String = \"ä\"",
		"var j: String = UiUtil.label(Tx.t(\"Der Graf\"), &\"LabelSmall\")",
	]))
	var found: PackedStringArray = Lint.findings(src)
	assert_eq(found, PackedStringArray(["2: Zurück", "3: Neues Spiel", "8: Stufe", "9: Gewöhnlich"]),
		"tr() is no Tx yet; developer calls, Tx and no-i18n lines are not findings")
	assert_true(Lint.looks_german("Weiße Weste") and Lint.looks_german("Der Graf") and Lint.looks_german("„x“"))
	assert_false(Lint.looks_german("dir") or Lint.looks_german("die") or Lint.looks_german("ui_cancel")
		or Lint.looks_german("ä"), "English homographs, ids and single characters are no German texts")
