# Inhaltspaket „Testbild“

Test- und Anschauungspaket aus PTDs **eigenen** Inhalten (`docs/11_SPRACHEN_UND_INHALTSPAKETE.md` Kap. 3.14, SP-19).
Es benutzt jede Paket-Funktion einmal und läuft in den Tests (`test_11_pack_testbild`, `test_11_pack_records`) — später
auch in der CI (`tools/pack_check.sh game/packs/testbild`, Paket 11-PB). Es gelangt nie in einen Grund-Build.

| Datei | Inhalt |
|---|---|
| `pack.json` | Steckbrief (Kap. 3.3), `licence: null`; `touches`: Namen der Gegner, Text und Abschalten von Zeilen, neue Looks |
| `data/enemies.json` | `patch`: die Rattenkönigin heißt „Die Testbild-Königin von Gleis 9“ |
| `data/mod_lines.json` | `patch` der zweiten `boss_intro`-Zeile der Königin (Sendestörung), `disable` der dritten `chat_bark`-Zeile |
| `data/looks.json` | `add`: Outfit `lk_outfit_testbild` „Testbildstreifen“ in Testbild-Grau (Namen von Looks: höchstens 16 Zeichen) |
| `art.json` | Graf Mopsula in den Testbild-Farben (nur `colors`; nicht im Paket-Hash) |
| `locale/en.po` | Englisch (11-L1): die drei neuen Texte des Pakets (Bossname, Bossansage, Look) und ein Override eines Basis-Eintrags, der Untertitel des Titelbildschirms — Paket-PO > Basis-PO > msgid |
| `locale/de.po` | ein deutscher Override eines Codetexts: die Bootkarte „präsentiert“ → „präsentiert im Testbild“ |

`languages` in `pack.json` ist `["de", "en"]`: `PackLoader.read` verlangt zu jeder Sprache außer `source_lang` ihre
`locale/<sprache>.po`. Die PO-Dateien prüft `test_11_po_rules` mit denselben Regeln wie die Basis-PO (Längen der
Basis-Einträge gelten auch für ihre Overrides); `tools/i18n.sh check` prüft sie zusätzlich mit `msgfmt`.

Starten (Debug): `godot --path game -- --pack=testbild`. Die Spielstände liegen dann unter `user://packs/testbild/`.

Ansprechpartner: das Team von Paket 11-P1 (`docs/11` Kap. 5.3).
