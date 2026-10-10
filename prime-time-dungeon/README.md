# PRIME TIME DUNGEON

3D-Dungeon-Crawler mit Reality-Show-Mechanik, gebaut in **Godot 4.7** (GDScript, statisch typisiert).
Dieses Verzeichnis enthält den **Vertical Slice von Etage 1**: Spiel (`game/`), Design- und Technik-Dokumente (`docs/`) und
Prüfwerkzeuge (`tools/`).

![Kampf mit Sponsor-Geschenk](docs/screenshots/11_battle_sponsor_gift.png)

---

## 1. Was es ist

- **Prämisse:** Das Medienkonglomerat NOVA SYNDIKAT hat die Erdoberfläche „zurückgebaut“ und macht aus dem Dungeon darunter
  die Reality-Show **DUNGEON PRIME TIME**. Kai, Tierpfleger:in, und **Graf Mopsula**, ein sprechender Mops mit Adelsallüren,
  kämpfen sich Etage für Etage nach unten. Jede Etage bricht nach einem Countdown zusammen. Moderiert wird alles von der
  sarkastischen System-KI **M.O.D.**
- **Look:** stilisiertes Low-Poly mit Toon-Shading (Option B). Figuren, Räume und Effekte entstehen prozedural aus Primitiven
  und Shadern, ohne externe Assets. glTF-Modelle aus Blender sollen die Platzhalter später 1:1 ersetzen (03_ART Kap. 10).
- **Spiel:** Echtzeit-Erkundung in 3D mit sichtbaren Gegnern (wie FF12) und rundenbasierte **CTB-Kämpfe** mit sichtbarer
  Zugreihenfolge (wie FF10). Befehle: Angriff, Fähigkeit, Item, Stunt, Verteidigen, Flucht.
- **Die Show ist das UI:** Zuschauer, Follower, Hype, Sponsor-Geschenke mitten im Kampf, Achievements, Lootboxen,
  M.O.D.-Kommentare und Graf-Mopsula-Szenen im Safe Room.
- **SHOWRUN-Kern (Live-Modus, Stufe S0):** Offline-Event-Läufe mit festem Seed, Quest und lokaler Bestenliste. Jeder Lauf
  wird als Befehls-Log aufgezeichnet und lässt sich deterministisch nachspielen (Run-Log, Replay, `StateHash`).
  Zuschauer-Geschenke kommen nur in **Sponsor-Fenstern** an (05_LIVE_MODUS Kap. 6.13).

**IP-Hinweis:** PRIME TIME DUNGEON ist eine eigenständige IP und nur vom Genre von *Dungeon Crawler Carl* (Matt Dinniman)
**inspiriert**. Namen, Figuren, Orte und Texte aus DCC werden nicht verwendet (00_BRIEF, 04 Kap. 2).

**Verbindliche Entscheidungen** (00_BRIEF Kap. 5):

- **Lootboxen werden nur im Spiel verdient und nie für Echtgeld verkauft.** Spieler:innen kaufen sich nichts Zufälliges.
- **Echtgeld von Zuschauer:innen fließt ausschließlich an das Spiel bzw. den Betreiber**, nie an Spieler:innen und nie an
  Streamer:innen.
- Zuschauer:innen können nur begrenzt oft und nur zu bestimmten Zeiten helfen (Sponsor-Fenster).
- Im Vertical Slice gibt es weder Netzwerk noch Echtgeld. Geschenke stammen aus dem Spiel selbst oder aus dem
  QA-Werkzeug (Debug-Build).

## 2. Status

*Stand: 2026-10-10, Branch `ptd/final-a`. Die genaue Version ergibt sich aus `git log -1` in diesem Verzeichnis.*

**Läuft:**

- Etage 1 ist von Titel bis Abspann spielbar: Intro, Tutorial-Kampf und 14 weitere Gegnergruppen, Streuner, 5 Events,
  16 Truhen, 3 Safe Rooms (Heilen, Speichern, Automat, Lootboxen, Mopsula-Szenen), der Quartier-Boss **Der Hausmeister**
  und der Etagenboss **Die Rattenkönigin von Gleis 9**, danach Etagen-Bilanz, Autosave und Abspann.
- **Figurenwahl** (06 Paket A): Zu Beginn wählt man, wen man steuert — Kai (Feldschlag) oder Graf Mopsula (Bellen: verdutzt
  Gegnergruppen, die man dann von jeder Seite zuerst erwischt); die andere Figur folgt. „Figur wechseln“ im Safe Room,
  „Partner automatisch“ in den Optionen, auf Etage 1 eine Kulissenwand und drei Regie-Notizen als Geheimnisse.
- **Talent-Show** (06 Paket B): Ab Level 3 bringt jedes ungerade Level jeder Figur eine Talentwahl (1 aus 2, gewählt im
  Safe Room über den goldenen Knopf „TALENT-SHOW“). Feld-Talente wirken für die Figur, die gerade führt. Spezies und
  Spezialisierung ab Etage 3 sind als geprüftes Datenmodell angelegt (`species.json`, Command `casting`); die
  Casting-Oberfläche folgt mit Etage 3.
- Etage 2 ist nur angelegt (`floors.json`: `playable = false`). Wer abgestiegen ist, landet nach „Fortsetzen“ im Abspann.
- 3 Speicherslots (JSON in `user://saves/`), Einstellungen, Pausemenü, Touch-Steuerung.
- **M.O.D.-Marotten & Unterhosen-Liga** (06 Kap. 4): M.O.D. verrät je Etage, was sie heute mag (Show-Wetten mit Herzen,
  Fanpost-Paket bei drei Treffern); wer ohne Rüstung & ohne Accessoire kämpft, spielt in der Liga und bekommt mehr Hype und
  Follower. Show-Chip im Overlay, Pausemenü-Reiter „Show“, Achievement-Kette „Ohne alles“.
- SHOWRUN S0: 2 Offline-Events (`evt_offline_gleis9`, `evt_offline_pacifist`), Event-Lobby, Ergebnis-Screen, lokale Bestenliste,
  Replay-Prüfung.
- Qualitätssicherung: rund 950 automatische Tests, Autoplay-Smoke-Test (`AUTOPLAY: OK`), Full-Run-Bot, der Etage 1 mit
  drei Strategien und als Graf Mopsula durchspielt, Performance-Probe (`PERF: OK`) und der CI-Workflow `ptd-check`.

**Bekannte Lücken:**

- keine komponierte Musik und keine echten Sounds (nur prozedural erzeugte Platzhalter-Loops und -SFX), keine glTF-Modelle
- Ausrüstung ist an den Figuren nicht sichtbar (Antrag 03_ART A8)
- kein Netzwerk, kein Server, kein Echtgeld (SHOWRUN S1 und später)
- Plattform-Matrix der Stufe S0 noch nicht gemessen (05 Kap. 2), Budgets noch nicht auf einem echten Android-Gerät geprüft
- noch keine externen Playtests

## 3. Öffnen und starten

1. **Godot 4.7.x** (Standard-Build, nicht .NET) installieren. Getestet ist **4.7.2-stable**.
2. Im Projektmanager **Importieren** wählen und `prime-time-dungeon/game/project.godot` öffnen. Der erste Import dauert
   einen Moment, weil Godot die Shader und Ressourcen importiert.
3. **F5** startet die Hauptszene `res://scenes/boot/boot.tscn`. Nach der Karte „NOVA SYNDIKAT präsentiert“ kommt der Titel.

Renderer ist **Mobile** (Vulkan). Ohne Vulkan fällt Godot automatisch auf **Compatibility** (OpenGL 3) zurück. Alle Shader
funktionieren in beiden Renderern (02_TECH §2, §12.2).

Von der Kommandozeile aus dem Repo-Wurzelverzeichnis:

```bash
godot --path prime-time-dungeon/game                         # Spiel starten
godot --path prime-time-dungeon/game -- --goto=battle:enc_f1_boss_hausmeister   # mit Entwickler-Argumenten
```

Alles nach `--` sind Argumente für das Spiel (Abschnitt 5). Im Editor trägt man sie unter
**Projekt → Projekteinstellungen → Editor → Run → Main Run Args** ein (Einstellung `editor/run/main_run_args`;
falls sie fehlt, oben „Erweiterte Einstellungen“ einschalten).

## 4. Steuerung

Tasten sind als physische Tasten belegt und funktionieren daher auch mit QWERTZ. Alle Menüs lassen sich mit Tastatur,
Gamepad und Touch bedienen (02_TECH §2.2, §10).

| Aktion | Tastatur / Maus | Gamepad (SDL-Layout) | Touch |
|---|---|---|---|
| Bewegen | WASD oder Pfeiltasten | linker Stick | schwebender Stick in den linken 40 % des Bildschirms |
| Kamera drehen | Q / E, rechte Maustaste gedrückt ziehen | rechter Stick | auf der freien rechten Fläche ziehen |
| Kamera zoomen | – | – | zwei Finger (Pinch) |
| Schleichen (halten) | Shift | LT oder L3 | Stick nur wenig auslenken (≤ 60 %) |
| Aktion: Interagieren oder Feldschlag | F, Leertaste, Enter | A | runder Aktions-Button rechts |
| Pause | Esc, P | Start | Pause-Button oben rechts |
| Karte | M, Tab | Back | Karten-Button |
| Menü-Reiter wechseln | Q / E, Bild↑ / Bild↓ | LB / RB | Reiter antippen |
| Bestätigen / Zurück | Enter, Leertaste / Esc | A / B | Button antippen |
| Kampf: Auto-Kampf an/aus | T | Y | AUTO-Button |
| Kampf: Tempo ×1 / ×2 | R | R3 | Tempo-Button |
| Kampf: Befehle und Ziele | Pfeiltasten + Enter | Steuerkreuz / Stick + A | Befehls-Buttons (2 × 3), Gegner antippen wählt das Ziel, erneut antippen oder „OK“ führt aus; die Zugfolge-Leiste zeigt 10 Einträge |
| Vollbild | F11 | – | – |
| Debug-Overlay (nur Debug-Build) | F3 | – | – |
| QA: Test-Geschenk / Sponsor-Fenster öffnen (Debug-Build, Overlay offen) | F4 / F5 | – | Buttons im Overlay |

Interagieren hat Vorrang: Zeigt die Erkundung einen Prompt (Truhe, Tür, Event in 1,5 m vor Kai), löst die Aktionstaste
die Interaktion aus, sonst einen Feldschlag. Trifft der Feldschlag eine Gruppe, die noch nicht jagt (oder ihren Rücken),
beginnt der Kampf mit Präventivschlag; dasselbe gilt, wenn Kai eine Gruppe von hinten berührt (01_GDD Kap. 2.4).

## 5. Entwickler-Argumente

Argumente stehen nach `--` (CLI) bzw. in den Main Run Args (Editor). Quelle: `scenes/boot/boot.gd`, 02_TECH §11.4.

| Argument | Wirkung |
|---|---|
| `--seed=<int>` | Seed für „Neues Spiel“ und für die `--goto`-Ziele (sonst Standard-Spielstand) |
| `--goto=explore` | überspringt den Titel und startet die Erkundung von Etage 1 am Startpunkt |
| `--goto=safe_room` | wie `explore`, betritt danach den ersten Safe Room |
| `--goto=battle:<enc_id>` | startet direkt einen Kampf, z. B. `--goto=battle:enc_f1_boss_hausmeister` oder `battle:enc_f1_boss_rattenkoenigin` (IDs in `game/data/floors.json`) |
| `--goto=title` | Titel (Standard) |
| `--goto=credits` | Abspann |
| `--goto=lobby` | SHOWRUN-Event-Lobby |
| `--goto=game_over` | Game-Over-Screen (Grund: Timer) |
| `--autoplay` | Smoke-Test: spielt Titel → Neues Spiel → Erkundung → Kampf → Safe Room automatisch, schneller Zeitablauf, flüchtige Einstellungen, es werden keine Spielstände geschrieben; endet mit `AUTOPLAY: OK` und beendet das Spiel mit Exit-Code 0 |
| `--autoplay=full` | Full-Run-Bot: spielt Etage 1 von Titel bis Abspann (02_TECH §11.4.1), mit echten Spielständen in eigenem Verzeichnis |
| `--strategy=thorough\|rush\|dawdle\|typical` | Strategie des Full-Run-Bots: alles / nur Safe Rooms, Tore, Bosse / trödeln bis zum Etagenkollaps / typische:r Erstspieler:in |
| `--pace=fast\|human` | Takt des Full-Run-Bots: ohne Wartezeit oder mit dem Modell eines aufmerksamen Menschen |

Beispiel: `godot --path prime-time-dungeon/game -- --autoplay=full --strategy=typical --pace=human`

## 6. Werkzeuge

Alle Skripte liegen in `tools/` und brauchen die Umgebungsvariable `GODOT=<Pfad zur Godot-4.7-Binary>` (Standard: `godot`
im `PATH`). `check.sh`, `fullrun.sh` und `perf.sh` arbeiten in einer **isolierten Temp-Kopie** des Projekts mit eigenem
`user://`: Mehrere Läufe können parallel laufen, und eigene Spielstände bleiben unberührt. `make_icons.sh` baut ebenfalls in
einer Temp-Kopie, schreibt die Icons aber nach `game/art/icons/` zurück. `--shot` und `perf.sh` brauchen `xvfb-run`
(außer `perf.sh --headless`).

| Skript | Zweck | Erfolg |
|---|---|---|
| `tools/check.sh` | Import, alle Tests, Autoplay-Smoke-Test | letzte Zeile `check.sh: OK` |
| `tools/check.sh --tests-only [--filter=<teil>]` | Import und Tests (optional nur Testdateien, deren Name `<teil>` enthält) | `check.sh: OK` |
| `tools/check.sh --shot <res://szene.tscn> <out.png> [frames] [BxH] [--touch] [--recipe=<name>] [--params=<json>] [--no-global-ui]` | rendert eine Szene unter Xvfb (`xvfb-run` nötig) im Compatibility-Renderer und speichert ein PNG | `saved <pfad>` |
| `tools/fullrun.sh [--strategy=thorough\|rush\|dawdle\|typical\|all] [--seed=<int>] [--pace=fast\|human] [--log-dir=<dir>]` | Full-Run-Bot headless mit festem 60-fps-Takt; `all` = thorough, rush und dawdle nach einem Import (wie in CI) | `fullrun.sh: OK` |
| `tools/perf.sh [--driver=opengl3\|vulkan] [--quality=high\|low] [--only=startup,explore,battle,safe_room,leak] [--cycles=20] [--out=<datei.md>] [--shots=<dir>] [--cells] [--headless]` | Performance-Probe unter Xvfb: Budget-Tabelle aus 02_TECH §12.1 (Draw Calls, Primitive, Lichter, Speicher, Ladezeiten) und Leak-Schleife über Szenenwechsel; Ergebnisse in `docs/PERFORMANCE.md` | `PERF: OK`, `perf.sh: exit 0` |
| `tools/make_icons.sh` | erzeugt die Launcher-Icons in `game/art/icons/` aus `game/icon.svg` neu | Zeilen `ICON: …`, Exit 0 |

**Exit-Codes:** `0` = bestanden. `1` = Fehler: Import, Test, Smoke-Test, Screenshot, Bot-Lauf, Budget-Überschreitung oder
Speicherwachstum. Jede Zeile mit `SCRIPT ERROR`, `Assertion failed`, `ERROR:` usw. zählt als Fehler, auch bei Exit 0 des
Godot-Prozesses. `2` = Aufruffehler (Godot-Binary nicht gefunden; bei `fullrun.sh` auch ein unbekanntes Argument). Der Test-Runner wertet auch
übersprungene Tests als Fehler, sofern sie nicht ausdrücklich zugelassen sind. Zeitbudgets in Tests werden nur mit
`PTD_PERF_ASSERTS=1` geprüft (CI-Check-Job).

```bash
GODOT=~/godot/godot prime-time-dungeon/tools/check.sh
GODOT=~/godot/godot prime-time-dungeon/tools/fullrun.sh --strategy=all
```

## 7. Ordner

```
prime-time-dungeon/
├── README.md            diese Datei
├── docs/                Design- und Technik-Dokumente (Abschnitt 8), docs/screenshots/
├── tools/               check.sh, fullrun.sh, perf.sh, make_icons.sh
└── game/                Godot-Projekt (= res://), project.godot, export_presets.cfg, icon.svg
    ├── autoload/        Events, DB, Game, Show, Save, Router, Sfx (+ private Helfer wie game_replay.gd)
    ├── core/            reine Logik (RefCounted, headless testbar, ohne Autoloads)
    │   ├── data/        GameData, Defs, DataValidator (+ validators/ je neuer Tabelle), SeedUtil, JsonUtil
    │   ├── stats/       StatBlock, Elemente, Balance-Konstanten, FixedMath
    │   ├── battle/      CTB-Kampf: BattleState, CTB-Queue, Schadensformeln, Status, Gegner-KI, ActionEvent
    │   ├── show/        ShowModel (Hype, Zuschauer, Follower), Achievements, Sponsoren, M.O.D.-Ansagen, Marotten/Liga
    │   ├── loot/        LootRoller (Lootboxen, Truhen, Pools)
    │   ├── progression/ GameState, FloorRun, Party, Inventar, EXP, Shop, BattleBridge, SaveCodec, Talents, Casting, HeroRules
    │   ├── dungeon/     FloorLayout, DungeonGenerator, Spawns, Etagen-Events, ExploreEvent
    │   └── live/        SHOWRUN: RunLog, RunSim, RunRules, StateHash, Gift, GiftPolicy, Sponsor-Fenster, Quest, Bestenliste
    ├── data/            17 JSON-Dateien: 16 GameData-Tabellen + events.json (SHOWRUN-Events)
    ├── art/             shaders/, materials/, kit/ (prozedurale Figuren, Räume, Props, VFX), gallery/, icons/
    ├── scenes/          boot/, title/, exploration/, battle/, safe_room/, ui/
    └── tests/           run_tests.gd, test_*.gd, lib/, fixtures/, perf/, tools/, capture.gd, capture_recipes.gd
```

Außerhalb dieses Verzeichnisses: der CI-Workflow `.github/workflows/ptd-check.yml` im Repo-Wurzelverzeichnis (Import,
Tests, Smoke-Test, Full-Run-Bot, Screenshots, Desktop-Exports). Export-Ausgaben landen in `build/` bzw. `export/`; beide
Ordner stehen in `.gitignore`.

## 8. Dokumente

Bei Widersprüchen gilt die Rangfolge aus 00_BRIEF: **00_BRIEF > 07_ECHTZEITKAMPF (alles Kampfrelevante) > 06 (neue
Systeme) > 01_GDD / 02_TECH / 03_ART / 05 (je nach Thema) > 04**.

| Dokument | Inhalt |
|---|---|
| [`docs/00_BRIEF.md`](docs/00_BRIEF.md) | Leitentscheidungen, verbindlich: Prämisse, Design-Säulen, Systeme, Technik, Nutzerentscheidungen zu Echtgeld und Sponsor-Fenstern |
| [`docs/02_TECH.md`](docs/02_TECH.md) | Technik-Vertrag: Dateibaum und Modulbesitz, Autoloads, Datenschemas, APIs, Tests, Capture, Autoplay, Performance-Budgets, CI |
| [`docs/01_GDD.md`](docs/01_GDD.md) | Game Design: Regeln, Formeln, Inhalte und Zahlen von Etage 1, Balancing (Kap. 13) |
| [`docs/03_ART.md`](docs/03_ART.md) | Art Direction Option B: Farben, Shader, prozedurale Figuren und Umgebung, VFX, UI-Look |
| [`docs/04_STRATEGIE_ROADMAP.md`](docs/04_STRATEGIE_ROADMAP.md) | Strategie: Positionierung, IP und Recht, Phasenplan 0–7, Team, Finanzierung, Monetarisierung |
| [`docs/05_LIVE_MODUS.md`](docs/05_LIVE_MODUS.md) | Live-Modus SHOWRUN: Stufen S0–S5, Determinismus, Protokoll, Geschenke, Sponsor-Fenster, Wirtschaft, Recht |
| [`docs/06_PROGRESSION_MAROTTEN_KI_ADMIN.md`](docs/06_PROGRESSION_MAROTTEN_KI_ADMIN.md) | Neue Systeme in Paketen A–D: Figurenwahl (Paket A, umgesetzt), Talent-Show und Spezies (Paket B, umgesetzt), M.O.D.-Marotten, KI-Admin |
| [`docs/07_ECHTZEITKAMPF.md`](docs/07_ECHTZEITKAMPF.md) | Echtzeitkampf „WoW-light“ direkt in der Welt (ersetzt den CTB-Kampf ab R5): Vertrag, Phasen R1–R5 |
| [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md) | Messergebnisse der Performance-Probe gegen die Budgets aus 02_TECH §12.1 |

## 9. Screenshots

Alle Bilder stammen aus dem Spiel selbst (Compatibility-Renderer unter Xvfb, 1280 × 720; Bild 18 im Handy-Format
2400 × 1080 und Bild 26 im Handy-Format 1600 × 720, beide mit Touch-Steuerung).

| | |
|---|---|
| ![Titel](docs/screenshots/01_title_menu.png) **01** Titelmenü | ![Intro](docs/screenshots/02_intro_mod_studio.png) **02** Intro im Studio von M.O.D. |
| ![U-Bahn-Gleise](docs/screenshots/03_explore_ubahn_gleise_enemy_group.png) **03** Erkundung, Zone U-Bahn-Gleise mit Gegnergruppe (rechts der Show-Chip) | ![Kanalisation](docs/screenshots/04_explore_kanalisation_enemy_group.png) **04** Erkundung, Zone Kanalisation mit Gegnergruppe |
| ![Keller](docs/screenshots/05_explore_keller_chest_prompt.png) **05** Zone Keller: Kai vor einer Truhe mit Prompt | ![Karte](docs/screenshots/06_explore_floor_map.png) **06** Etagenkarte |
| ![Pausemenü](docs/screenshots/07_pause_menu_equipment.png) **07** Pausemenü, Reiter Ausrüstung (mit Liga-Zeile) | ![Befehlsmenü](docs/screenshots/08_battle_command_menu.png) **08** Kampf: Befehlsmenü und Zugfolge-Leiste |
| ![Rattenkönigin](docs/screenshots/09_battle_boss_intro_rattenkoenigin.png) **09** Boss-Intro: Die Rattenkönigin von Gleis 9 | ![Hausmeister](docs/screenshots/10_battle_boss_phase_hausmeister.png) **10** Phasenwechsel des Hausmeisters |
| ![Sponsor-Geschenk](docs/screenshots/11_battle_sponsor_gift.png) **11** Sponsor-Geschenk mitten im Kampf | ![Sieg](docs/screenshots/12_battle_victory_results.png) **12** Sieg und Ergebnis-Screen |
| ![Mopsula](docs/screenshots/13_safe_room_mopsula_scene.png) **13** Safe Room: Szene mit Graf Mopsula | ![Lootbox](docs/screenshots/14_safe_room_lootbox_reveal_odds.png) **14** Lootbox-Öffnung mit veröffentlichten Wahrscheinlichkeiten |
| ![Event-Lobby](docs/screenshots/15_event_run_lobby.png) **15** SHOWRUN-Event-Lobby mit lokaler Bestenliste | ![Cast](docs/screenshots/16_gallery_cast_floor1.png) **16** Galerie: Besetzung von Etage 1 |
| ![VFX](docs/screenshots/17_gallery_vfx.png) **17** Galerie: Effekte | ![Handy](docs/screenshots/18_phone_battle_skill_list_touch.png) **18** Handy-Format: Fähigkeitenliste mit Touch-Steuerung |
| ![Figurenwahl](docs/screenshots/19_hero_select.png) **19** Figurenwahl: Kai oder Graf Mopsula (06 Paket A) | ![Bellen](docs/screenshots/20_explore_mopsula_bark.png) **20** Graf Mopsula führt und bellt eine Gruppe an |
| ![Figur wechseln](docs/screenshots/21_safe_room_hero_switch.png) **21** Safe Room nach „Figur wechseln“ | ![Partner automatisch](docs/screenshots/22_battle_partner_auto.png) **22** Kampf mit „Partner automatisch“ (DU / AUTO) |
| ![Kulissenwand](docs/screenshots/23_secret_wall.png) **23** Kulissenwand (E1-Geheimnis) | ![Wand fällt](docs/screenshots/24_secret_wall_falls.png) **24** Der Graf bellt die Kulissenwand um |
| ![Regie-Notiz](docs/screenshots/25_regie_notiz.png) **25** Regie-Notiz mit Prompt | ![Handy Safe Room](docs/screenshots/26_safe_room_hero_talents_phone.png) **26** Handy-Format: Safe Room mit TALENT-SHOW-Knopf und M.O.D.-Kasten |
| ![Show](docs/screenshots/27_pause_show_unterhosen_liga.png) **27** Pausemenü, Reiter Show: M.O.D.s Vorliebe und Unterhosen-Liga (06 Paket C) | ![Show-Wette](docs/screenshots/28_battle_results_show_bet_won.png) **28** Kampfergebnis: dritter Herz-Treffer, Show-Wette gewonnen (Fanpost-Paket) |
| ![Talent-Show](docs/screenshots/talent_show.png) **Talent-Show** (06 Paket B): zwei Karten je Wahl | ![TALENT-SHOW](docs/screenshots/safe_talents_menu.png) **Safe Room** mit offener Talentwahl |
| ![Sponsor-Fenster](docs/screenshots/overlay_sponsor_window.png) **Overlay** Show-Overlay (Demo-Werte): Sponsor-Fenster offen mit Platz-Punkten, Show-Chip „M.O.D. mag heute“ mit Herzen und Liga-Stufe | ![Party](docs/screenshots/talents_party.png) **Party-Seite** mit Talenten und offener Wahl |

**Neu erzeugen:** `tools/check.sh --shot` rendert eine Szene. Zustände, die man nur durch Spielen erreicht, stellen die
Capture-Rezepte in `game/tests/capture_recipes.gd` her (02_TECH §11.3). Beispiele:

```bash
T=prime-time-dungeon/tools/check.sh
GODOT=… $T --shot res://scenes/title/title.tscn shot.png 120 1280x720
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=explore_platform   # 03 (sewer: 04)
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=prompt_cellar      # 05
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=bigmap             # 06
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=pause_equipment    # 07
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=battle_menu                  # 08
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=boss_intro \
  '--params={"encounter": "enc_f1_boss_rattenkoenigin", "capture": false, "speed": 1.0}'                     # 09
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=boss_phase \
  '--params={"encounter": "enc_f1_boss_hausmeister"}'                                                        # 10
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=battle_gift                  # 11
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=battle_results \
  '--params={"capture_turns": 99}'                                                                           # 12
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_mopsula           # 13
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_lootbox_open      # 14
GODOT=… $T --shot res://scenes/ui/event_lobby.tscn shot.png 120 1280x720                                     # 15
GODOT=… $T --shot res://art/gallery/character_gallery.tscn shot.png 120 1280x720                             # 16
GODOT=… $T --shot res://art/gallery/vfx_gallery.tscn shot.png 120 1280x720                                   # 17
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 2400x1080 --touch --recipe=battle_skills       # 18
GODOT=… $T --shot res://scenes/ui/show_overlay.tscn shot.png 120 1280x720                                    # Overlay
GODOT=… $T --shot res://scenes/title/hero_select.tscn shot.png 60 1280x720                                  # 19
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=bark_platform      # 20
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_hero_switch       # 21
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=battle_partner_auto          # 22
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=secret_wall        # 23 (24: secret_open, 25: secret_note)
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1600x720 --touch --recipe=safe_hero_talents  # 26
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=pause_show         # 27
GODOT=… $T --shot res://scenes/battle/battle.tscn shot.png 5 1280x720 --recipe=battle_results_show          # 28
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_talent_show       # Talent-Show
```

## 10. Nächste Schritte

Nach dem Phasenplan in 04 Kap. 3.4 fehlen für den Abschluss von Phase 2 (Meilenstein M-P2, Go/No-Go):

1. **15 externe Playtests** mit der Zielgruppe (nicht Freunde oder Familie). Zielwerte: ≥ 70 % erreichen den Hausmeister,
   Median-Spielzeit 22–28 min, ≥ 60 % „würde weiterspielen“, ≥ 50 % nennen ungefragt Show, M.O.D. oder Mopsula,
   0 Abstürze in 20 Durchläufen.
2. **Performance-Budgets auf echter Hardware** prüfen: PC mit iGPU und ein Android-Mittelklassegerät (02_TECH §12.1).
3. **Distanz-Review** (04 Kap. 2.3, Entscheidung E2) und **Titel-Entscheidung** mit Markenrecherche (Kap. 2.5, E3).
4. **Gameplay-Video** (2–3 min) und **Android-Debug-APK** für den Slice-Build.
5. **Sichtbare Ausrüstung** an den Figuren (03_ART Antrag A8).
6. **Plattform-Matrix für SHOWRUN S0** messen (05 Kap. 2): gleicher Seed und gleiche Befehle ergeben auf allen Zielplattformen
   denselben `StateHash`.
7. Danach **Phase 3 (Pre-Production)**: Art-Upgrade mit glTF-Pipeline, Steam-Seite, Finanzierung, Team (04 Kap. 3.5).
