# PRIME TIME DUNGEON — Performance (Phase C)

Stand: Branch `ptd/int-perf`, Godot 4.7.2. Budgets: 02_TECH §12.1, Messwerkzeug: `tools/perf.sh` (02_TECH §12.5).
Dieses Dokument hält fest, **was** gemessen wurde, **wie**, was vorher/nachher herauskam und welche Abweichungen bewusst bleiben.

---

## 1. Ergebnis auf einen Blick

Maximum über alle gemessenen Ansichten bzw. Frames (Methode §2). „vorher“ = Stand vor Phase C (`799f92c`), Compatibility high.

| Größe (02_TECH §12.1) | Budget | vorher | **nachher** Compat. high | Compat. low | Mobile (Vulkan) high |
|---|---|---:|---:|---:|---:|
| Erkundung: Draw Calls 3D | 150 | 112 | **112** | 54 | 68 (32 + 36 Schatten) |
| Erkundung: Draw Calls UI | 100 | 198 ✗ | **83** | 83 | 81 |
| Erkundung: Omni aktiv | 4 + 1 Neon (low 2) | 4 + 1 | **4 + 1** | 2 | 4 + 1 |
| Erkundung: Lichter pro Mesh | 3 | 4–5 ✗ | **2** | 1 | 2 |
| Erkundung: Physik-Körper (ohne Areas) | 40 | 95 ✗ | **23** | 23 | 23 |
| Erkundung: Materialien | 24 | 20 | **21** | 20 | 21 |
| Kampf: Draw Calls 3D | 150 | 130 | **130** | 118 | 84 |
| Kampf: Draw Calls UI | 180 | 204 ✗ | **165** | 179 | 165 |
| Kampf: Omni / Show-Spots | 2 / 2 (nur high) | 2 / 2 | **2 / 2** | 2 / 0 | 2 / 2 |
| Kampf: Materialien (Bosse) | 24 | 28 ✗ | **21** | 23 | 22 |
| Safe Room: Draw Calls 3D / UI | 120 / 100 | 75 / 95 | **76 / 84** | 46 / 86 | 44 / 84 |
| Safe Room: Physik-Körper | 0 | 3 ✗ | **0** | 0 | 0 |
| RAM (Godot, Spitze im Kampf) | 400 MB | 255 MB | **265 MB** | 278 MB | 271 MB |
| Etage 1 bauen, warm | 500 ms | 181 ms | **≈ 200 ms** | 229 ms | 222 ms |
| Router-Zyklen (20×), Wachstum | 0 | – | **0 Nodes, 0 Ressourcen** | | |
| „ObjectDB instances leaked at exit“ | 0 | 6 (sporadisch) ✗ | **0** | | |
| Erstes Bild nach Prozessstart (llvmpipe) | – | 3,0–3,1 s | **2,0–2,4 s** | | |

✗ = über Budget. Dazu: Kampf-Lichter pro Mesh 4 auf der Arena-Geometrie (Fill + Back + 2 Show-Spots, nur high) und das Neon-
Akzentlicht sind bewusst im Budget verankert (§8). Etagen-Aufbau „warm“ = Median aus 12 Neubauten (headless, `bench`), vorher/nachher
188–192 ms / 194–211 ms; in den Probe-Läufen 181–343 ms je nach Last.

---

## 2. Methode

**Umgebung.** Linux-Container, 4 CPU-Kerne, Xvfb 1280×720×24, kein GPU-Treiber:
- Compatibility-Renderer (`--rendering-driver opengl3`, wie CI-Screenshots): Mesa **llvmpipe** (LLVM 20, Software-GL);
- Mobile-Renderer (`--rendering-driver vulkan`, Standard des Projekts auf Mobilgeräten): Mesa **lavapipe** (Software-Vulkan,
  `apt install mesa-vulkan-drivers`).

Draw Calls, Primitive, Lichter, Materialien, Körper, Nodes und Objektzahlen sind **GPU-unabhängig** und gelten 1:1 für echte
Geräte. Zeiten sind CPU-gebunden (Software-Rendering, parallel laufende Prozesse) und nur **relativ** (vorher/nachher, gleiche
Maschine, nacheinander gemessen) aussagekräftig; FPS werden nicht bewertet. RAM = `Performance.MEMORY_STATIC` (Godot-Speicher,
ohne Treiber), VRAM = `RENDER_VIDEO_MEM_USED`.

**Ablauf** (`tools/perf.sh`, kopiert das Projekt wie `check.sh`, importiert, startet zwei Prozesse):
1. `tests/perf/boot_timer.gd` — der **echte** Boot (Main Scene `boot.tscn`) bis zum interaktiven Titel, dann „Neues Spiel“
   (Seed 4242, ohne Intro) bis zur interaktiven Erkundung; Zeiten ab Prozessstart. Das Skript nennt keine Screen-Klassen, damit
   nichts vorab kompiliert wird, was der echte Boot nicht kompiliert.
2. `tests/perf/perf_probe.gd` → `perf_runner.gd`:
   - **Erkundung**: jede der 31 Zellen von Etage 1 (Seed 4242), je 4 Kamerarichtungen (0/90/180/270°), je 2 gerenderte Frames
     nach 3 Physik-Frames; je Zone das Maximum jeder Größe, die schlechteste Einzelansicht und das Etagen-Maximum; `--cells`
     zusätzlich je Zelle.
   - **Kampf**: jede Begegnung von Etage 1 (Frames 20–30 nach Szenenstart = Eröffnung mit Kamerafahrt), danach die größte Begegnung
     (meiste Gegner, Party Lv 4) und **beide Bosse** (Hausmeister, Rattenkönigin; Party Lv 7) als kompletter Auto-Kampf, jeder Frame.
   - **Safe Room**: die drei Safe Rooms von Etage 1, je 30 Frames.
   - **Router-Zyklen** (`leak`): 20 × Erkundung (neu gebaut) → Kampf → Safe Room → zurück über den echten `Router`.
3. Je Zeile Status gegen 02_TECH §12.1; letzte Zeilen `PERF: OK|OVER BUDGET (…)` und `LEAK: OK|GROWTH …`.

**Definitionen** (wie 02_TECH §12.1):

| Größe | Messung |
|---|---|
| DC 3D | `viewport_get_render_info(VISIBLE + SHADOW, DRAW_CALLS)` des Hauptviewports |
| DC 2D (UI) | `viewport_get_render_info(CANVAS, DRAW_CALLS)`; Summe 3D + 2D = Monitor `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` |
| Omni aktiv | sichtbar, Energie > 0, nicht per Distance-Fade aus, ≤ 24 m von der Kamera, Reichweiten-Kugel schneidet das Sichtfeld (in Klammern: alle ≤ 24 m) |
| Lichter/Mesh | je sichtbarem Mesh die Zahl der aktiven Omni/Spot, deren Reichweite (Kugel / Kegel) die AABB trifft **und** deren `light_cull_mask` den Layer des Meshes enthält; Maximum |
| Materialien | eindeutige Material-Instanzen aller sichtbaren Geometrien inkl. `next_pass` (Outline) |
| Körper | `StaticBody3D` / Character- und Rigid-Bodies; Areas getrennt (zählen nicht) |

**Vorher** = Commit `799f92c` (Stand vor Phase C), mit demselben Probe gemessen (frühere Probe-Version: Draw Calls gesamt mit
3D/Schatten/2D-Aufteilung, Spots als Omni gezählt, Körper inkl. Areas; die Zahlen unten sind auf die heutigen Definitionen
umgerechnet, wo das möglich ist).

---

## 3. Messwerte nachher

Alle Werte: Maximum über die gemessenen Frames. „DC 3D“ = sichtbarer Pass + Schattenpass (Compatibility rendert die Sonnen-
Schatten im selben Pass, daher „+ 0“; Mobile zählt ihn getrennt, §3.4). Status gegen 02_TECH §12.1: überall **OK**.

### 3.1 Erkundung — Compatibility, Quality high

| Zone (Zellen) | meiste DC in | DC gesamt max (Ø) | DC 3D | DC UI | Primitive | Omni aktiv (≤ 24 m) | Lichter/Mesh | Materialien | Körper stat./kin. (Areas) | RAM MB |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| zone_cellar (7) | (4, 0) normal, 2 Gegner | 166 (133) | 83 | 79 | 41 112 | 4 (5) | 2 | 14 | 4 / 19 (27) | 134 |
| zone_office (1) | (5, 0) Viertelboss, 1 Gegner | 160 (152) | 77 | 78 | 40 888 | 2 (2) | 1 | 10 | 4 / 19 (27) | 134 |
| zone_platform (8) | (1, 4) normal, 3 Gegner | 181 (132) | 112 | 69 | 47 332 | 4 (5) | 2 | 16 | 4 / 19 (27) | 135 |
| zone_sewer (9) | (3, 4) normal, 3 Gegner | 153 (129) | 84 | 69 | 40 452 | 4 (5) | 2 | 18 | 4 / 19 (27) | 135 |
| zone_throne (1) | (0, 0) Etagenboss, 1 Gegner | 155 (138) | 72 | 78 | 47 330 | 2 (3) | 2 | 15 | 4 / 19 (27) | 134 |
| zone_track9 (5) | (1, 0) Treppe, 3 Gegner | 186 (155) | 101 | 83 | 47 690 | 4 + 1 Neon | 2 | 21 | 4 / 19 (27) | 134 |
| **Schlechtester Raum mit Gegnern** | (1, 0) Treppe, 3 Gegner | **186** (149) | 98 | 83 | 47 690 | 4 + 1 Neon | 2 | 21 | 4 / 19 (27) | 134 |
| **Etage gesamt** | | 186 | **112** / 150 | **83** / 100 | 47 690 / 120 000 | 4 + 1 Neon / 4 + 1 | **2** / 3 | **21** / 24 | **23** / 40 | 135 / 400 |

Je-Zelle-Tabelle: `tools/perf.sh --cells`. Schlechteste Zelle in jeder Größe ist ein Raum mit 3 sichtbaren Gegnern; die Treppe
(1, 0) hat zusätzlich das Neon-Akzentlicht (§8).

### 3.2 Kampf — Compatibility, Quality high

Eröffnung aller 17 normalen Begegnungen von Etage 1 (Frames 20–30): DC gesamt 188–270, **DC 3D 61–128**, **DC UI 122–165**,
Primitive 29 087–45 855, Omni 2 + 2 Show-Spots, Lichter/Mesh 4 (Arena-Geometrie in Fill + Back + 2 Spots, §8), Materialien 14–19,
Label3D ≤ 8, Partikel ≤ 56 in ≤ 5 Emittern, keine Körper.

| Kompletter Auto-Kampf | Frames | DC gesamt max (Ø) | DC 3D | DC UI | Primitive | Omni / Spot | Lichter/Mesh | Materialien | Partikel (Emitter) | RAM MB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| enc_f1_d2 (größte Begegnung, 4 Gegner) | 132 | 279 (205) | 130 | 148 | 53 446 | 2 / 2 | 4 | 18 | 42 (4) | 256 |
| enc_f1_boss_hausmeister | 155 | 242 (192) | 105 | 140 | 49 174 | 2 / 2 | 4 | 20 | 50 (4) | 258 |
| enc_f1_boss_rattenkoenigin | 298 | 255 (173) | 120 | 152 | 54 798 | 2 / 2 | 4 | 21 | 34 (3) | 265 |
| **Budget** | | | 150 | 180 | 120 000 | 2 / 2 | 3 (+1 Spots) | 24 | 400 (6) | 400 |

### 3.3 Safe Room — Compatibility, Quality high

| Raum | DC gesamt max (Ø) | DC 3D | DC UI | Primitive | Omni | Lichter/Mesh | Materialien | Körper |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| sr_kiosk | 164 (157) | 75 | 84 | 27 976 | 3 | 3 | 14 | 0 |
| sr_pumphouse | 144 (143) | 75 | 64 | 27 896 | 3 | 3 | 14 | 0 |
| sr_signalbox | 145 (144) | 76 | 64 | 29 774 | 3 | 3 | 15 | 0 |
| **Budget** | | 120 | 100 | 60 000 | 3 | 3 | 16 | 0 |

### 3.4 Quality low (Mobil-Standard) und Mobile-Renderer

| | Compatibility low | Mobile (Vulkan) high | Budget |
|---|---|---|---|
| Erkundung: DC 3D / UI max | 54 / 83 | 32 + 36 Schatten / 81 | 150 / 100 |
| Erkundung: Primitive max | 27 982 | 47 654 | 120 000 |
| Erkundung: Omni aktiv / Lichter pro Mesh | 2 / 1 | 4 + 1 Neon / 2 | low 2 · high 4 + 1 / 3 |
| Erkundung: Materialien / Körper | 20 / 23 | 21 / 23 | 24 / 40 |
| Kampf-Eröffnungen (17): DC 3D / UI | 20–88 / 131–179 | 37–81 / 122–165 | 150 / 180 |
| Kampf komplett (größte, Hausmeister, Königin): DC 3D | 118 / 62 / 99 | 84 / 69 / 101 | 150 |
| … DC UI | 156 / 140 / 156 | 148 / 140 / 152 | 180 |
| … Omni / Spot · Lichter pro Mesh | 2 / 0 · 2 | 2 / 2 · 4 | 2 / 2 (high) · 3 (high Arena 4) |
| … Materialien | 17 / 21 / 23 | 18 / 19 / 22 | 24 |
| … Partikel (Emitter) | ≤ 83 (6) | ≤ 66 (3) | 400 (6) |
| Safe Room: DC 3D / UI · Omni · Lichter pro Mesh | 45–46 / 82–86 · 2 · 2 | 43–44 / 64–84 · 3 · 3 | 120 / 100 · 3 · 3 |
| RAM max | 278 MB | 271 MB (VRAM 290 MB) | 400 MB |
| Etage 1 bauen kalt / warm | 300 / 229 ms | 520 / 222 ms (kalt = erste Pipeline-Kompilierung in lavapipe) | 500 ms |

Mobile zählt den Sonnen-Schattenpass getrennt (Compatibility rendert ihn im Hauptpass); die 3D-Draw-Calls liegen dort trotzdem bei
weniger als der Hälfte des Budgets. Quality low (Mobil-Standard) halbiert die Primitive (keine Schatten, kein Glow, Skalierung 0,7).

---

## 4. Optimierungen

Reihenfolge nach Wirkung. Jede Maßnahme ist durch Tests abgesichert (in Klammern) und in 02_TECH / 03_ART beschrieben.

### 4.1 UI-Draw-Calls: Vektor-Icons, Minimap und Hype-Leiste als **ein** Dreiecks-Array

**Befund.** Die UI kostete mehr Draw Calls als das 3D-Bild: Erkundung 118–198 Canvas-DC, Kampf bis 204 (3D: ≤ 130). Gemessen in
4.7.2 (beide Renderer): Canvas-Items bündeln nur bei gleicher Textur und Befehlsart; jedes `draw_colored_polygon`, `draw_circle`,
`draw_polyline` und jede breite `draw_line` ist ein eigener Draw Call, eine `StyleBoxFlat` 1, ein Label mit Outline 2 (Outline-Glyphen
in eigener Font-Textur). Die Vektor-Icons (`UiIcon`, `HudStyle.Icon`) bestehen aus 4–8 Primitiven → 6–11 DC je Icon; die Minimap
zeichnete jede aufgedeckte Zelle als eigenes Polygon (wuchs beim Erkunden auf ≈ 150 DC).

**Maßnahme.** `scenes/ui/icon_mesh.gd` sammelt die Primitive eines Icons/Widgets in Zeichenreihenfolge und übergibt sie mit
`RenderingServer.canvas_item_add_triangle_array` als **ein** Dreiecks-Array: gleiche Formen, Farben und Überdeckung; Kreise, Linien
und Outlines bekommen den 1-px-Alpha-Saum der Godot-`antialiased`-Varianten. Die Minimap cacht ihr Zellen-Mesh und baut es nur bei
Änderung (Zelle aufgedeckt, Raumwechsel) neu. `DebugOverlay` (F3) zeigt Draw Calls jetzt als „gesamt (3D · UI)“.

**Wirkung.** Erkundung UI 118–198 → **69–83** DC je Zone, Kampf UI 148–204 → **122–165**; Minimap unabhängig vom Erkundungsstand 1 DC. Bild
unverändert (Screenshots vorher/nachher). (`test_m6_*`, `test_m5_*`: Icons/Minimap zeichnen; `test_m6_overlay`: F3-Zeile.)

### 4.2 Physik: ein Körper pro Etage statt einer pro Raum und Prop

**Befund.** Etage 1: 76 `StaticBody3D` (je Raum „Collision“, je Truhe/Event-Prop ein doppelter Körper + Blocker, Türstürze) + 19
`CharacterBody3D` = 95 Körper (Budget 40); Safe Room 3 Körper (Budget 0).

**Maßnahme.** `FloorBuilder.build_rooms` zieht die Boxen aller Raum-„Collision“-Körper und der Türstürze in **einen** Körper
„FloorCollision“ (Etagen-Koordinaten); die dauerhaften Blocker von Truhen und Events liegen in **einem** Körper „PropBlockers“ (die
Kamera ignoriert ihn wie vorher die Einzel-Blocker); Interactables entfernen den doppelten „Collision“-Körper ihres Art-Props; Tore
behalten ihren eigenen Blocker (wird beim Öffnen freigegeben). Safe Room und Kampfbühne (Wrack) haben keine Körper mehr
(`SetBuilder.strip_collision`): dort läuft niemand, die Kamera ist fest.

**Wirkung.** Etage 1: 95 → **23** Körper (4 statisch + 19 kinematisch; 27 Areas unverändert); Safe Room 3 → 0. Verhalten unverändert.
(`test_perf_router_cycles`: FloorCollision/PropBlockers, keine Einzelkörper, ≤ 40; `test_m3_*`: Kollision, Kamera, Tore.)

### 4.3 Lichter pro Mesh: Schachbrett-Render-Layer der Räume

**Befund.** Raumlichter haben 9 m Reichweite und reichen durch die Türen: Boden/Wände eines Raums bekamen das eigene Licht + bis zu
3 Nachbarlichter → 4–5 Lichter pro Mesh (Budget 3).

**Maßnahme.** Raum-Meshes liegen auf Render-Layer 11 oder 12 nach der Parität von x + y ihrer Zelle (per Tür verbundene Zellen haben
immer unterschiedliche Parität); jedes Raumlicht maskiert die andere Parität aus (`light_cull_mask`). Figuren, Props und Effekte
bleiben auf Layer 1 und werden von jedem Licht in Reichweite beleuchtet wie bisher.

**Wirkung.** Lichter/Mesh in der Erkundung 4–5 → **≤ 2**. Optisch: kein Durchscheinen fremder Raumlichter auf Nachbarwände mehr.
(`test_perf_router_cycles`: Layer und Cull-Masken aller Räume.)

### 4.4 Quality „low“: nur der aktuelle Raum hat sein Raumlicht

**Befund.** „low“ erlaubt 2 aktive Omni-Lichter; sichtbar sind aber der aktuelle Raum und alle per Tür verbundenen (3–5 Raumlichter).

**Maßnahme.** Auf „low“ behält nur der Raum, in dem Kai steht, sein OmniLight; die sichtbaren Nachbarräume stehen im Umgebungs- und
Sonnenlicht; beim Raumwechsel blendet das Licht in 0,4 s vom alten in den neuen Raum über (`ExplorationScene._set_room_light`).
„high“ bleibt unverändert. Verworfen: kürzere Distance-Fades (18/2 m bzw. 10/4 m) — sie schalteten den Raum ab, in den die Kamera
blickt (≈ 22 m entfernt), oder hingen vom Kamerawinkel ab.

**Wirkung.** „low“: Omni aktiv **≤ 2** in jeder Ansicht. (`test_perf_router_cycles`: nur der aktuelle Raum leuchtet, das Licht folgt.)

### 4.5 Materialien im Kampf

**Befund.** Spitzen von 27–29 eindeutigen Materialien in Bosskämpfen (Budget 24), wenn Sponsor-Drop, Zug der Rattenkönigin, Status-
und Skill-Effekte zusammenfallen. `--mat-dump` zeigte die Quellen: ein eigenes toon-Material je Sponsorfarbe und 6 Einzel-Meshes
mit 3 Materialien im Sponsor-Paket, eigene Materialien für Gleis und Signalmasten, ein `vfx_additive` je Effektfarbe.

**Maßnahme.** Sponsor-Paket = ein vertex-farbiges Mesh (Box in Sponsorfarbe + Fallschirm) mit dem Figuren-`toon_vc` + Bänder und
Leinen als ein Mesh mit dem Konfetti-Material; Gleis = PropKit-Dekor-`env` (dieselbe Instanz wie das Wrack), Signalmasten =
Figuren-`toon_vc`; Effekt-Quads (Ringe, Hiebe, Hologramm, Frost) tragen ihre Farbe als Vertex-Farbe (`VfxNode._tint_quad`) und
teilen das weiße `vfx_additive` ihrer Form. Optisch gleich (VFX-Galerie vorher/nachher); Paket-Outline 0,02 → 0,025, Signalmast-Rim
0,3 → 0,45.

**Wirkung.** Rattenkönigin 28 → **21** (high) bzw. 29 → **23** (low), Hausmeister 19 → 20/21, Eröffnungen ≤ 23 → ≤ 19 (high) /
≤ 21 (low). `--mat-dump` meldet Überschreitungen jetzt mit Frame-Zahl.

### 4.6 Start: keine Screen-Klassen vor dem ersten Bild

**Befund.** Vom Prozessstart bis zum ersten Bild 3,0–3,1 s (llvmpipe), davon 1,1 s für das Kompilieren **aller** Screens: `GlobalUi`
(lädt vor dem ersten Bild) prüfte `Router.current is ExplorationScene/BattleScene/SafeRoomScene`, und `boot.gd` preloadete
`autoplay.gd` — beides kompiliert die Klassen samt Abhängigkeitsbaum.

**Maßnahme.** `GlobalUi.initial_mode()` vergleicht `scene_file_path` mit `Router.SCENE_*`; `autoplay.gd` wird nur mit `--autoplay`
per `load()` geholt (ebenso der später dazugekommene Full-Run-Bot `fullrun.gd` nur mit `--autoplay=full`). Als Regel 02_TECH §13.2 Nr. 6.

**Wirkung.** Erstes Bild 3,0–3,1 → **2,0–2,4 s**, Titel interaktiv 5,6–5,8 → **4,6–4,9 s** (Compatibility, llvmpipe; headless
Boot-`_ready` 2,4 → 1,2 s). Das Kompilieren der Erkundungs-Skripte fällt jetzt hinter „Neues Spiel“ (verdeckt von der 0,5-s-Blende,
+0,5 s dort); Prozessstart → interaktive Erkundung insgesamt −0,1…−0,3 s (§6). (`test_perf_platform`: Boot/GlobalUi nennen keine Screen-Klasse, Autoplay lazy.)

### 4.7 „ObjectDB instances leaked at exit“

**Befund.** `check.sh` meldete sporadisch „6 ObjectDB instances were leaked at exit“ (`AudioStreamPlaybackWAV`, `AudioStreamWAV`).
Ursache: der AudioServer gibt gestoppte Playbacks erst einen Mix-Schritt später auf seinem Thread frei und wird direkt nach dem
Szenenbaum abgebaut — ein beim Beenden laufender Sound blieb registriert.

**Maßnahme.** `Sfx._exit_tree()`: `stop_all()` (Musik + alle Player, ohne Fade) und, falls etwas lief, 120 ms warten
(`SHUTDOWN_DRAIN_MS`). Sfx ist das letzte Autoload, alle Screens sind dann schon weg.

**Wirkung.** 0 von 12 Prüfläufen mit Leck-Meldung (vorher sporadisch, u. a. im Gate-Lauf vor Phase C); Gate-Lauf ohne Meldung. (`test_perf_router_cycles`:
`stop_all` gibt jedes Playback frei.)

### 4.8 Zug-Stirnlicht nur auf „high“

Der Zug der Rattenkönigin brachte ein drittes Omni-Licht in den Kampf (Budget 2). Auf „low“ entfällt es (emissive Stirnlampen
bleiben), auf „high“ leuchtet es nur während der ≈ 1 s Durchfahrt und ist als Akzentlicht dokumentiert (§8).

### 4.9 Geprüft und verworfen

| Idee | Ergebnis |
|---|---|
| Label-Outlines weglassen / MSDF-Fonts | −1 DC je Label, aber schlechter lesbar über dem 3D-Bild → nicht übernommen |
| Neon-Licht der Treppe entfernen | Gold-Lichtpool der Treppe fehlt sichtbar → bleibt als Akzentlicht (§8) |
| Kürzere Distance-Fades der Raumlichter | s. 4.4 |
| MultiMesh / weiteres Mesh-Merging | Raum-Props sind je Raum bereits **ein** gemergtes Mesh, Figuren je Teil 1 Mesh; 3D-DC lagen schon im Budget |
| `visibility_range` | unsichtbare Räume sind ohnehin aus (nur aktueller + Nachbarräume sichtbar, M3); kein messbarer Gewinn |


---

## 5. Speicher und Lecks

### 5.1 Router-Zyklen

20 Zyklen Erkundung (jedes Mal neu gebaut) → Kampf (`enc_f1_a1_tutorial`, Auto-Kampf) → Safe Room → zurück, über den echten Router,
nach vorherigem Durchlauf aller Etagen-Ansichten. Je Zyklus nach 4 Frames: Objekte, davon Einträge der begrenzten Art-Caches
(Materialien, Figuren-Meshes ≤ 96 Modelle, getönte Effekt-Quads ≤ 64), Nodes, Ressourcen, verwaiste Nodes, RAM.

| Lauf | Objekte (ohne Caches) | Nodes | Ressourcen | verwaiste Nodes | RAM |
|---|---:|---:|---:|---:|---:|
| Compatibility high, Minimum Zyklen 2–6 → 16–20 | +22 (+11) | **+0** | **+0** | 0 | +4,5 MB (bis Zyklus 4, danach +0,3 MB über 16 Zyklen) |
| headless, Minimum Zyklen 2–6 → 16–20 | +18 (+7) | **+0** | **+0** | 0 | +8,4 MB (bis Zyklus 6, danach +0,3 MB) |

Urteil `LEAK: OK` in beiden Läufen. Die Node-Zahl schwankt nur um Toasts und Ticker-Einträge der Show-Leiste (`--leak-diff`: je Zyklus
±2–12 Nodes unter `GlobalUi/Toasts` und `…/Ticker`), Ressourcen bleiben exakt gleich. Der RAM-Anstieg in den ersten Zyklen ist das
einmalige Füllen der Caches (Sfx-Streams werden beim ersten Abspielen synthetisiert, Figuren-Meshes, Materialien), danach flach.

Zwei Befunde der Messung sind **kein** Leck und wurden im Werkzeug berücksichtigt:
- **Streuner:** Ein Zone-Spawner (RunSim, 90 s Erkundungszeit) setzte im gerenderten Lauf in Zyklus 12 zwei Streuner-Gruppen ab
  (+43 Nodes, danach flach) — Spielzustand, max. 1 je Zone. Probe und `test_perf_router_cycles` setzen die Spawner-Ticks je Zyklus
  zurück, damit jeder Zyklus dieselbe Etage baut.
- **Caches:** Begegnungen mit neuen Effektfarben oder Gegnermodellen füllen die begrenzten Caches einmalig (+10…+20 Objekte); das
  Urteil rechnet deren Einträge heraus (`perf_runner.cache_objects()`).

Mit verschiedenen Begegnungen nacheinander (17 Eröffnungen + 3 komplette Kämpfe) steigt der RAM im gerenderten Lauf um ≈ 4 MB je
**neuer** Begegnung (Compatibility high 176 → 265 MB; vorher 180 → 255 MB, also unverändert), headless dagegen nicht (154 MB flach):
renderer-seitige Daten neuer Meshes/Materialien/Glyphen. Bei Wiederholung derselben Begegnung (Router-Zyklen) bleibt er flach.

### 5.2 Beim Beenden

Vor Phase C meldete `check.sh` sporadisch `WARNING: 6 ObjectDB instances were leaked at exit` (Tests und Autoplay; Ursache und
Maßnahme §4.7). Nachher: 0 Meldungen in 12 Smoke-/Testläufen und im abschließenden Gate-Lauf (`RESULT: … 0 failed`,
`AUTOPLAY: OK`, ohne „leaked“).

---

## 6. Start- und Aufbauzeiten

Zeiten ab Prozessstart, `tests/perf/boot_timer.gd` (echter Boot; Titel inkl. fester 2,0-s-Logo-Karte + 0,5-s-Blende),
Compatibility unter Xvfb/llvmpipe bzw. headless, nacheinander auf derselben Maschine gemessen.

| Messpunkt | vorher (Compat.) | nachher (Compat.) | vorher (headless) | nachher (headless) |
|---|---:|---:|---:|---:|
| Engine + Autoloads (Skripte, DB) | 1,2 s | 1,2–1,4 s | 1,1 s | 0,9–1,0 s |
| Boot-Szene `_ready` (GlobalUi, Logo, Shader-Prewarm) | 2,7 s | **1,4–1,6 s** | 2,4 s | **1,2–1,3 s** |
| erstes Bild | 3,0–3,1 s | **2,0–2,4 s** | – | – |
| Titel interaktiv | 5,6–5,8 s | **4,6–4,9 s** | 4,7 s | **3,9–4,0 s** |
| Titel → „Neues Spiel“ → Erkundung interaktiv | 1,1 s | 1,6–1,8 s | 0,7 s | 1,2 s |
| Prozessstart → Erkundung interaktiv | 6,7 s | **6,3–6,6 s** | 5,4 s | **5,1 s** |

Der Titel ist früher bedienbar, weil die Screens nicht mehr vor dem ersten Bild kompiliert werden (§4.6); der Weg Titel → Erkundung
trägt dafür das Kompilieren der Erkundung (hinter der Blende). Fester Anteil: 2,5 s Logo-Karte + Blende (Design, 03_ART).

**Aufbauzeiten** (02_TECH §12.1, Budget PC: Etage 500 ms, Arena/Safe Room 300 ms):

| Aufbau | Compat. high kalt / warm | Compat. low | Mobile (Vulkan) | vorher (Compat.) |
|---|---:|---:|---:|---:|
| Etage 1 (Layout + 31 Räume + Akteure + HUD, `ExplorationScene._ready`) | 339 / 259 ms | 300 / 229 ms | 520 / 222 ms | 342 / 181 ms |
| davon Layout (`DungeonGenerator.generate`) | 1 ms | 2 ms | 2 ms | 1 ms |
| Kampf-Arena + Rigs + HUD, normale Begegnung | 143 / 40 ms | 142 / 39 ms | 133 / 39 ms | – |
| Kampf-Arena Boss | 138 ms | 152 ms | 126 ms | – |
| Safe Room | 76 / 15 ms | 91 / 18 ms | 96 / 20 ms | 59 / 14 ms |

„kalt“ = erster Bau im Prozess (Skripte bereits kompiliert, erste Shader-/Pipeline-Erzeugung), „warm“ = späterer Neubau. Die Werte
schwanken unter Last um ±50 ms; der gezielte Vergleich (14 Neubauten headless, Median der letzten 12, je 3 Läufe abwechselnd) ergibt
Etage 1 warm **188–192 ms vorher / 194–211 ms nachher**: Zusammenlegen der Kollision und Schachbrett-Layer kosten ≈ 10 ms, weit
unter dem Budget. Auch der Mobil-Richtwert 1,5 s (Etage) ist mit Abstand eingehalten; `test_perf_router_cycles` prüft ≤ 1,5 s in CI.

---

## 7. Mobil-Bereitschaft und Export

| Punkt | Stand | Gesichert durch |
|---|---|---|
| Querformat | `display/window/handheld/orientation = 4` (Sensor Landscape) | `test_perf_platform` |
| Safe Area | `SafeAreaContainer` um HUD, Menüs und Touch-Steuerung (M6); Kerbe/Gestenleiste werden ausgespart | `test_m6_*` |
| Touch | `emulate_touch_from_mouse = false` (Desktop bleibt Maus), `emulate_mouse_from_touch = true` (Buttons reagieren auf Touch) | `test_perf_platform` |
| V-Sync / FPS | V-Sync an; **neu** `application/run/max_fps.mobile = 60` (90/120-Hz-Panels würden sonst mit Panelrate rendern: Akku/Wärme); PC ungedrosselt | `test_perf_platform` |
| Renderer | `rendering_method = mobile` (+ `.mobile`), `fallback_to_opengl3 = true`; gemessen in beiden (§3) | `test_perf_platform` |
| Texturen | `import_etc2_astc = true`; keine Texturen > 512 px (Vektor-/Prozedural-Art) | `test_perf_platform` |
| Laufzeit | `keep_screen_on = true`; `quit_on_go_back = false` (Android-Zurück → `ui_cancel`) | `test_perf_platform` |
| Export-Presets | 5 Presets (Windows, Linux, macOS, Android arm64 + immersive, iOS), Filter `all_resources` + `data/*.json`, ohne `tests/*`, `art/gallery/*`, Ziel `build/` | `test_perf_platform` |
| Export geprüft | `--export-pack "Linux"` (ohne Templates möglich) erzeugt eine lauffähige `.pck`: Autoplay aus der `.pck` → `AUTOPLAY: OK`, Skripte als Binär-Tokens, `data/*.json` enthalten. Übrige Presets scheitern nur an fehlenden Export-Templates bzw. Android-SDK, nicht an der Konfiguration | manuell (02_TECH §12.3) |
| App-Icon | Desktop: `icon.svg` (`config/icon`). **Neu:** Android `launcher_icons/main_192x192` + Adaptive Vorder-/Hintergrund 432 px, iOS `icons/icon_1024x1024` (deckend) → `art/icons/*.png`, erzeugt aus `icon.svg` mit `tools/make_icons.sh` | `test_perf_platform` (Pfade, Größen, iOS ohne Alpha) |


---

## 8. Bewusste Abweichungen und offene Punkte

### 8.1 Bewusst im Budget verankert (02_TECH §12.1 angepasst)

| Punkt | Begründung |
|---|---|
| **Draw Calls getrennt in 3D und UI** (vorher eine Zeile „≤ 150“) | Der Monitor zählt 3D und Canvas zusammen; die alte Zahl war als 3D-Budget gerechnet (Asset-Tabelle). Die UI hat eigene Grenzen (≤ 100 / 180 / 100), weil Text-Outlines und Panels prinzipbedingt je 1–2 DC kosten. |
| **Neon-Akzentlicht** (+1 Omni an Treppe und Safe-Room-Tür, nur high) | Trägt das Signal (Gold-Lichtpool der Treppe); ohne es fehlt der Orientierungspunkt sichtbar. Kurzer Fade (12/4 m), max. 1. |
| **Kampf high: Lichter pro Mesh 4 auf der Arena-Geometrie** | Fill + Back + 2 Show-Spots (03_ART §5). Figuren ≤ 4, auf low ≤ 2. |
| **Zug-Stirnlicht** (+1 Omni, nur high, ≈ 1 s je Durchfahrt) | Kurzer Show-Effekt der Rattenkönigin; auf low entfällt das Licht. |
| **Physik: Areas zählen nicht** | 27 `Area3D` = Interaktionsbereiche (Truhen, Etagen-Events, Tore, Safe-Room-Türen, Treppe; Layer `interact`) — reine Überlappungs-Tests, keine Körper der Kollisionslösung. |

### 8.2 Offen / Beobachten

- **Nur Software-Renderer gemessen.** FPS, Thermik, Akku und Shader-/Pipeline-Kompilierruckler (erste Effekte, erster Kampf) müssen
  auf den Referenzgeräten (Adreno 610 / Mali-G57, iPhone 11) gemessen werden; die Zählgrößen hier gelten 1:1, die Zeiten nicht.
- **RAM je neuer Begegnung** im gerenderten Lauf ≈ +4 MB (renderer-seitig, §5.1, vor Phase C ebenso). Spitze 265–278 MB nach 20
  verschiedenen Kämpfen ist unter 400 MB; ein Lauf über beide Etagen auf dem Gerät sollte das bestätigen.
- **Kampf-UI nahe am Budget:** Tutorial-Kampf auf low bis 179 von 180 Canvas-DC (Tutorial-Hinweis + Befehlsmenü + Show-Leiste).
  Nächster Hebel: Ticker/Chat-Zeilen der Show-Leiste ohne Outline oder als ein Label.
- **Materialien im Kampf:** Spitzen 21–23 von 24, wenn Sponsor-Drop, Status- und Skill-Effekte zusammenfallen. Nächster Hebel:
  Status-Effekte (Glow/Hologramm je Status-Farbe) ebenfalls über Vertex-Farbe oder Instanz-Uniform tönen.
- **Erste Erkundung** kompiliert jetzt hinter „Neues Spiel“ (+0,5 s, verdeckt von der Blende); auf langsamen Geräten ggf. eine
  Lade-Animation in der Blende oder das Kompilieren während der Logo-Karte im Hintergrund (`ResourceLoader.load_threaded_request`).
- **Etage kalt im Mobile-Renderer 520 ms** (lavapipe, erste Pipeline-Erzeugung); warm 222 ms. Auf Geräten mit Pipeline-Cache
  prüfen.
- **Export:** Nur `--export-pack "Linux"` vollständig geprüft; Android/iOS/Windows/macOS brauchen Templates, SDK/Keystore bzw. Xcode
  (02_TECH §12.3) und einen Lauf auf echter Hardware. Bundle-ID ist ein Platzhalter.

---

## 9. Reproduzieren

```bash
GODOT=/pfad/zu/godot-4.7.2 tools/perf.sh --out=perf_gl_high.md --cells            # Compatibility, high, alles
GODOT=… tools/perf.sh --quality=low --only=startup,explore,battle,safe_room          # Compatibility, low (Mobil-Standard)
GODOT=… tools/perf.sh --driver=vulkan --only=startup,explore,battle,safe_room        # Mobile-Renderer (Vulkan-ICD nötig)
GODOT=… tools/perf.sh --headless --only=startup,leak --cycles=20                     # Zeiten + Router-Zyklen ohne Rendering
# Diagnose: --mat-dump (Materialien des Spitzen-Frames), --leak-diff (Node-Arten je Zyklus), --full=<enc,…>, --shots=<dir>
```

Exit-Code 1 bei Budget- oder Leck-Überschreitung. `check.sh` bleibt die einzige CI-Prüfquelle; dort sichern
`tests/test_perf_router_cycles.gd` (8 Router-Zyklen ohne Wachstum, Etagen-Aufbau ≤ 1,5 s, ≤ 40 Körper, Licht-Layer, Quality-low-
Raumlicht) und `tests/test_perf_platform.gd` (Mobil-Einstellungen, Export-Presets, Icons, Boot ohne Screen-Klassen) die Ergebnisse.
