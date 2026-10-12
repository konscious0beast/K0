# PRIME TIME DUNGEON — Performance (Phase C)

Stand: 2026-10-10, Branch `ptd/final-a` (komplett nachgemessen nach Boss-Balancing, Sponsor-Fenster und Abschluss-Review, §3.5),
Godot 4.7.2. Erste Fassung: Branch `ptd/int-perf` (Phase C). Budgets: 02_TECH §12.1, Messwerkzeug: `tools/perf.sh` (02_TECH §12.5).
Dieses Dokument hält fest, **was** gemessen wurde, **wie**, was vorher/nachher herauskam und welche Abweichungen bewusst bleiben.

> **Stand R5b-2b (2026-10-12, Branch `ptd/r5b2b`) — Nachmessung fällig.** Der CTB-Kampf der Kampagne ist entfernt (07 §12.6,
> 10 SD1): `scenes/battle/**` und der Abschnitt `battle` von `tools/perf.sh` gibt es nicht mehr. Die Zeilen „Kampf: …“ in §1
> und die Kampfmessungen in §3.2, §3.4, §3.5, §4.5 beschreiben die gelöschte CTB-Kampfszene und bleiben als Verlauf stehen.
> Der Kampf der Kampagne ist der Echtzeitkampf in der Welt (§3.6, `--only=combat`; in 2b nachgemessen: `PERF: OK`, Werte wie
> R5b-1, §3.6 „Nachmessung R5b-2b“); die Router-Zyklen (§5.1) spielen einen Echtzeitkampf und messen seit 2b auf der Etage,
> die das nächste `goto` neu gebaut hat. **Neu zu messen** auf der Referenz-Hardware und mit allen drei Profilen
> (Compatibility high/low, Mobile): `tools/perf.sh` vollständig — Start, Erkundung, Safe Rooms, Kampf, Router-Zyklen — mit den
> gebackenen Daten; §1 bekommt dann die Echtzeit-Kampfzeilen statt der CTB-Szene. [zu messen]
>
> **Stand ST1-C1 (2026-10-12, Branch `ptd/st1c1`):** die Etagen 2–6 der Basis-Staffel gemessen (§3.9, `--only=season`):
> jede Größe im Budget, die größte Etage (48 Räume, ganz gebaut) warm 408 ms im Median (Probe 428 ms). Die Türstürze kommen
> vor dem Eintritt in die Welt in den Etagen-Körper (§4.10: −14 ms auf Etage 1, −32–52 ms auf Etage 6).

---

## 1. Ergebnis auf einen Blick

Maximum über alle gemessenen Ansichten bzw. Frames (Methode §2). „vorher“ = Stand vor Phase C (`799f92c`), Compatibility high;
„heute“ = Nachmessung 2026-10-10 (§3.5) mit dem Boss-Lauf bis zum Sieg (§2).

| Größe (02_TECH §12.1) | Budget | vorher | **heute** Compat. high | Compat. low | Mobile (Vulkan) high |
|---|---|---:|---:|---:|---:|
| Erkundung: Draw Calls 3D | 150 | 112 | **112** | 58 | 68 (32 + 36 Schatten) |
| Erkundung: Draw Calls UI | 100 | 198 ✗ | **85** | 85 | 85 |
| Erkundung: Omni aktiv | 4 + 1 Neon (low 2) | 4 + 1 | **4 + 1** | 2 | 4 + 1 |
| Erkundung: Lichter pro Mesh | 3 | 4–5 ✗ | **2** | 1 | 2 |
| Erkundung: Physik-Körper (ohne Areas) | 40 | 95 ✗ | **23** | 23 | 23 |
| Erkundung: Materialien | 24 | 20 | **21** | 21 | 21 |
| Kampf: Draw Calls 3D | 150 | 130 | **133** | 96 | 118 (88 + 30 Schatten) |
| Kampf: Draw Calls UI | 180 | 204 ✗ | **158** | 170 | 158 |
| Kampf: Omni / Show-Spots | 2 / 2 (nur high) | 2 / 2 | **2 / 2** | 2 / 0 | 2 / 2 |
| Kampf: Materialien (Bosse) | 24 | 28 ✗ | **20** | 21 | 20 |
| Echtzeitkampf in der Welt (§3.6, mit Effekten): Draw Calls 3D, schlechtester Fall zwei Gruppen | 150 | – | **141** | 96 | 83 (59 + 24 Schatten) |
| Echtzeitkampf: Draw Calls UI (mit R3-HUD) | 180 | – | **42–62** | 41–59 | 42–59 |
| Echtzeitkampf: Materialien · Physik-Körper (Kollisionsring +1) | 24 · 40 | – | **21 · 25** | 22 · 25 | 21 · 25 |
| Echtzeitkampf: `RtSim.step` mit echten Daten (07 §3.15; R5b-1, §3.8), Median | 250 µs Desktop (R5b-Ziel 180) | 206,5 µs | **177 µs** | – | – |
| Safe Room: Draw Calls 3D / UI | 120 / 100 | 75 / 95 | **74 / 87** | 44 / 88 | 43 / 87 |
| Persona-Look (Casting K2, §3.7): Kai im schwersten Look, Tris / MeshInstances | 3 000 / 7 | 2 492 / 7 (Kanon) | **2 940 / 7**, Draw Calls aller Szenen unverändert | – | – |
| Safe Room: Physik-Körper | 0 | 3 ✗ | **0** | 0 | 0 |
| RAM (Godot, Spitze im Kampf) | 400 MB | 255 MB | **218 MB** | 262 MB | 230 MB (VRAM 251 MB) |
| Etage 1 bauen, warm | 500 ms | 181 ms | **242 ms** | – | – |
| Staffel-Etagen 2–6 (§3.9, ST1-C1): Draw Calls 3D / UI · Körper | 150 / 100 · 40 | – | **109 / 94 · 27** | – | – |
| Staffel-Etage 6 bauen (48 Räume, ganze Etage), warm: Median aus 9 · Probe | 500 ms | – | **408 · 428 ms** | – | – |
| Stempelduell (§3.10, 10 §6.10): Draw Calls UI · 3D, Tisch gegen den Stempelmeister mit Durchsage | 120 · 0 | – | **101 · 0** | – | – |
| Stempelduell: Zug · Vorschau (Mittel) · Tisch aufbauen, warm | 2 · 3 · 300 ms | – | **0,50 · 1,02 · 7 ms** | – | – |
| Router-Zyklen (20×), Wachstum | 0 | – | **0 Nodes, 0 Ressourcen** | | |
| „ObjectDB instances leaked at exit“ | 0 | 6 (sporadisch) ✗ | **0** | | |
| Erstes Bild nach Prozessstart (llvmpipe) | – | 3,0–3,1 s | 2,0–2,4 s (Phase C); heute 5,2–5,4 s auf einer anderen, geteilten Maschine — Basisstand gleich schnell, §3.5 | | |

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
     (meiste Gegner, Party Lv 4) und **beide Bosse** (Hausmeister, Rattenkönigin) als kompletter Auto-Kampf, jeder Frame. Die
     Boss-Läufe sollen die späten Phasen messen (Phasenwechsel, Zug der Königin, Haste) und müssen deshalb gewonnen werden: Party
     Lv 10 mit der Vor-Boss-Ausrüstung des Full-Run-Bots (`perf_runner.BOSS_KIT`/`BOSS_ITEMS`: Feuerwehraxt, Warnweste,
     Glücks-Fahrschein bzw. Siegel-Halsband, Samtcape, Glücks-Fahrschein; Werbepflaster, Riechsalz, KRAWUMM-Dose, Elixier).
     Die Probe **verlangt VICTORY**: jeder andere Ausgang ist eine Überschreitung (`PERF: OVER BUDGET … kein Sieg — die späten
     Phasen sind nicht gemessen`). Seit dem Boss-Balancing (`ce2f980`, Königin STR 26 → 52) verlor die alte Probe (Lv 7 ohne
     Ausrüstung) die Königin nach 91 Frames und maß ihre späten Phasen nicht mehr.
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

## 3. Messwerte (Nachmessung 2026-10-10)

Alle Werte: Maximum über die gemessenen Frames. „DC 3D“ = sichtbarer Pass + Schattenpass (Compatibility rendert die Sonnen-
Schatten im selben Pass, daher „+ 0“; Mobile zählt ihn getrennt, §3.4). Status gegen 02_TECH §12.1: überall **OK**.

### 3.1 Erkundung — Compatibility, Quality high

| Zone (Zellen) | meiste DC in | DC gesamt max (Ø) | DC 3D | DC UI | Primitive | Omni aktiv (≤ 24 m) | Lichter/Mesh | Materialien | Körper stat./kin. (Areas) | RAM MB |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| zone_cellar (7) | (4, 0) normal, 2 Gegner | 168 (139) | 83 | 81 | 41 310 | 4 (5) | 2 | 14 | 4 / 19 (27) | 136 |
| zone_office (1) | (5, 0) Viertelboss, 1 Gegner | 162 (153) | 77 | 80 | 41 086 | 2 (2) | 1 | 10 | 4 / 19 (27) | 136 |
| zone_platform (8) | (1, 3) normal, 3 Gegner | 194 (137) | 112 | 81 | 47 412 | 4 (5) | 2 | 16 | 4 / 19 (27) | 136 |
| zone_sewer (9) | (3, 3) normal, 1 Gegner | 163 (135) | 88 | 81 | 43 374 | 4 (5) | 2 | 18 | 4 / 19 (27) | 136 |
| zone_throne (1) | (0, 0) Etagenboss, 1 Gegner | 155 (140) | 72 | 78 | 47 412 | 2 (3) | 2 | 15 | 4 / 19 (27) | 135 |
| zone_track9 (5) | (1, 0) Treppe, 3 Gegner | 188 (156) | 101 | 85 | 47 868 | 4 + 1 Neon | 2 | 21 | 4 / 19 (27) | 136 |
| **Schlechteste Einzelansicht** | (1, 3) normal, 3 Gegner | **194** (166) | 108 | 81 | 42 270 | 3 (3) | 2 | 16 | 4 / 19 (27) | 136 |
| **Etage gesamt** | | 194 | **112** / 150 | **85** / 100 | 47 868 / 120 000 | 4 + 1 Neon / 4 + 1 | **2** / 3 | **21** / 24 | **23** / 40 | 136 / 400 |

Je-Zelle-Tabelle: `tools/perf.sh --cells`. Schlechteste Zelle in jeder Größe ist ein Raum mit 3 sichtbaren Gegnern; die Treppe
(1, 0) hat zusätzlich das Neon-Akzentlicht (§8; die Probe zählt es als fünftes Omni der Zone).

### 3.2 Kampf — Compatibility, Quality high

Eröffnung aller 17 normalen Begegnungen von Etage 1 (Frames 20–30): DC gesamt 183–263, **DC 3D 55–126**, **DC UI 124–158**,
Primitive 32 009–48 171, Omni 2 + 2 Show-Spots, Lichter/Mesh 4 (Arena-Geometrie in Fill + Back + 2 Spots, §8), Materialien 14–20,
Label3D ≤ 7, Partikel ≤ 57 in ≤ 5 Emittern, keine Körper.

| Kompletter Auto-Kampf | Frames | Ausgang | DC gesamt max (Ø) | DC 3D | DC UI | Primitive | Omni / Spot | Lichter/Mesh | Materialien | Partikel (Emitter) | RAM MB |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| enc_f1_d2 (größte Begegnung, 4 Gegner, Party Lv 4) | 132 | VICTORY | 278 (205) | 131 | 148 | 56 114 | 2 / 2 | 4 | 18 | 42 (4) | 215 |
| enc_f1_boss_hausmeister (Party Lv 10 + Kit) | 74 | VICTORY | 236 (201) | 105 | 145 | 51 940 | 2 / 2 | 4 | 17 | 40 (3) | 215 |
| enc_f1_boss_rattenkoenigin (Party Lv 10 + Kit) | 82 | VICTORY | 284 (184) | 133 | 158 | 66 533 | 2 / 2 | 4 | 20 | 40 (3) | 217 |
| **Budget** | | VICTORY | | 150 | 180 | 120 000 | 2 / 2 | 3 (+1 Spots) | 24 | 400 (6) | 400 |

### 3.3 Safe Room — Compatibility, Quality high

| Raum | DC gesamt max (Ø) | DC 3D | DC UI | Primitive | Omni | Lichter/Mesh | Materialien | Körper |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| sr_kiosk | 165 (155) | 73 | 87 | 27 912 | 3 | 3 | 14 | 0 |
| sr_pumphouse | 147 (144) | 73 | 69 | 27 792 | 3 | 3 | 14 | 0 |
| sr_signalbox | 146 (145) | 74 | 68 | 29 758 | 3 | 3 | 15 | 0 |
| **Budget** | | 120 | 100 | 60 000 | 3 | 3 | 16 | 0 |

### 3.4 Quality low (Mobil-Standard) und Mobile-Renderer

| | Compatibility low | Mobile (Vulkan) high | Budget |
|---|---|---|---|
| Erkundung: DC 3D / UI max | 58 / 85 | 32 + 36 Schatten / 85 | 150 / 100 |
| Erkundung: Primitive max | 28 120 | 48 760 | 120 000 |
| Erkundung: Omni aktiv / Lichter pro Mesh | 2 / 1 | 4 + 1 Neon / 2 | low 2 · high 4 + 1 / 3 |
| Erkundung: Materialien / Körper | 21 / 23 | 21 / 23 | 24 / 40 |
| Kampf-Eröffnungen (17): DC 3D / UI | 38–72 / 134–170 | 35–76 / 124–156 | 150 / 180 |
| Kampf komplett (größte¹, Hausmeister, Königin): DC 3D | 58 / 60 / 96 | 88 + 30 / 37 + 30 / 73 + 33 | 150 |
| … Frames, Ausgang | 42 / 76 / 88, alle VICTORY | 43 / 74 / 82, alle VICTORY | VICTORY |
| … DC UI | 143 / 155 / 158 | 134 / 142 / 158 | 180 |
| … Omni / Spot · Lichter pro Mesh | 2 / 0 · 2 | 2 / 2 · 4 | 2 / 2 (high) · 3 (high Arena 4) |
| … Materialien | 19 / 18 / 21 | 17 / 17 / 20 | 24 |
| … Partikel (Emitter) | ≤ 78 (4) | ≤ 58 (5) | 400 (6) |
| Safe Room: DC 3D / UI · Omni · Lichter pro Mesh | 43–44 / 86–88 · 2 · 2 | 26–27 + 16 / 69–87 · 3 · 3 | 120 / 100 · 3 · 3 |
| RAM max | 262 MB | 230 MB (VRAM 251 MB) | 400 MB |

¹ „größte Begegnung“ = meiste Gegner, bei Gleichstand die meisten Draw Calls der Eröffnung — je Lauf neu bestimmt: high
`enc_f1_d2`, low `enc_f1_b1`, Mobile `enc_f1_a2`. Aufbauzeiten low/Mobile: Phase-C-Werte in §6 (heute nicht erneut gemessen).

Mobile zählt den Sonnen-Schattenpass getrennt (Compatibility rendert ihn im Hauptpass); die 3D-Draw-Calls liegen dort in der
Erkundung trotzdem bei weniger als der Hälfte des Budgets, im Kampf bei ≤ 118 von 150. Quality low (Mobil-Standard) halbiert die Primitive (keine Schatten, kein Glow, Skalierung 0,7).

### 3.5 Nachmessungen

**2026-10-10, Branch `ptd/final-a`** (nach Boss-Balancing `ce2f980`, Sponsor-Fenster und Abschluss-Review): `tools/perf.sh`
Compatibility high (alle Abschnitte), Compatibility low und Mobile/Vulkan (Erkundung, Kampf, Safe Room) — überall **`PERF: OK`**,
`LEAK: OK`. Die Tabellen in §1 und §3.1–§3.4 sind diese Messung. Unterschiede zur Phase-C-Messung:
- **Boss-Läufe:** Die Probe spielt die Bosse jetzt mit Lv 10 und der Vor-Boss-Ausrüstung des Full-Run-Bots und verlangt VICTORY
  (§2). Hausmeister 74 Frames, Königin 82 Frames, beide gewonnen (high; low 76 / 88, Mobile 74 / 82). Vorher (Lv 7 ohne
  Ausrüstung) endete die Königin seit dem Boss-Balancing nach 91 Frames mit DEFEAT, die späten Phasen fehlten unbemerkt. Die
  Königin bleibt die teuerste Kampfansicht: DC 3D 133 / 150, UI 158 / 180, Primitive 66 533, Materialien 20 / 24.
- **Kampf-UI:** Eröffnungen high UI 124–158 (Phase C 122–165), low bis 170 (Phase C 179) — Abstand zum Budget 180 größer.
- **RAM-Spitze** high 218 MB (Phase C 265 MB): weniger komplette Kampf-Frames, da die Bosse schneller fallen.
- **Startzeiten:** Erstes Bild 5,2–5,4 s, Titel interaktiv 9,7 s (Phase C 2,0–2,4 s / 4,6–4,9 s). Die Messmaschine ist eine andere,
  geteilte Container-Instanz (Last ≈ 3–4,5 auf 4 Kernen durch parallele Läufe); der Basisstand ohne die Änderungen dieses Branches
  misst dort gleich (erstes Bild 5,2 s, Titel 9,9 s), also keine Regression. Zeiten sind nur auf derselben Maschine vergleichbar (§2).
- **Aufbau** (high): Etage 1 kalt / warm 285 / 242 ms, Arena 175 / 49 ms, Boss-Arena 157 ms, Safe Room 80 / 14 ms — alle im Budget.
- **Router-Zyklen** (20, high): Objekte +1 (ohne Cache-Einträge +0), Nodes +0, Ressourcen +0, RAM +0,2 MB.

**Nach dem Zusammenführen mit dem Visual-Pass und dem Full-Run-Bot** (Phase C + `ptd/int-visual` + int-cr / int-play): `PERF: OK`,
`LEAK: OK`; Erkundung DC 3D max 112, UI 83; Kampf-Eröffnungen DC 3D 55–126, UI 122–167; komplette Kämpfe DC 3D ≤ 131, UI ≤ 151,
Primitive max 66 493 (die Publikumstribüne des Visual-Pass liegt in der einen Arena-Geometrie: +≈ 2 500 Tris, kein zusätzlicher
Draw Call); Safe Rooms DC 3D 73–74 / UI 64–84; erstes Bild 2,3 s; Etage 1 bauen 281 ms warm. Der Full-Run-Bot (`--autoplay=full`)
wird wie der Smoke-Treiber erst mit dem Argument geladen (§4.6).

### 3.6 Echtzeitkampf in der Welt (07 §8.10, R2)

Stand 2026-10-11, Branch `ptd/r2` (R2 auf R1b-I2 + R3), `tools/perf.sh --only=combat`. Szenarien `combat_regular`,
`combat_two_groups`, `combat_boss_queen` (07 §8.10, §12.3): Etage 1 (Seed 4242) als neues Echtzeit-Spiel (HP-Skala), der Kampf
läuft in der Erkundung (kein Szenenwechsel) mit dem Kampf-HUD von R3. Gespielt wird er von der Welt-Fixture
`tests/fixtures/rt_world/world_stream.gd` (echte Daten, echte Set-Zelle; Schwünge, Treffer, Zonen, bei der Königin die
Zuglinie, Pfützen und alle fünf beschworenen Ratten), der `CombatDirector` tickt in Echtzeit; Erst-Hinweiskarten aus (sie hielten
die Ticks an). **Mit Effekten:** Der Telegraph-Pool hält alle 10 Quads (alle vier Formen), dazu Treffer-Funken (≤ 3 Emitter),
Komparsen-Rigs und Adds. Maximum über 4 Kamerarichtungen × 16 Frames (Kampfkamera 8 m, Boss 9 m); „Erkundung → Kampf“ misst
dieselbe Stelle vorher mit denselben 4 Richtungen.

| Compatibility high | Gegner (Komparsen/Adds) | DC 3D Erkundung → Kampf | DC UI¹ | Primitive | Materialien | Partikel (Emitter) | `Label3D` | Körper² | Omni / Lichter pro Mesh |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| combat_regular — (1, 3), eine Gruppe | 3 (2) | 100 → 113 | 81 → 42 | 40 865 | 16 → 19 | 28 (2) | 3 | 24 → 25 | 3 / 2 |
| **combat_two_groups** — (1, 3), zwei Gruppen | 6 (4) | 113 → **141** | 81 → 42 | 50 669 | 16 → 19 | 28 (2) | 3 | 24 → 25 | 3 / 2 |
| combat_boss_queen — (0, 0), Königin + 5 Ratten, Boss-Set | 6 (5) | 70 → 113 | 84 → 62 | 56 836 | 15 → 21 | 30 (3) | 3 | 24 → 25 | 3 / 2 |
| **Budget** (07 §8.10, 02_TECH §12.1) | ≤ 6 | 150 | 180 | 120 000 | 24 | 400 (6) | 12 | 40 | 4 + 1 / 3 |

¹ Mit dem Kampf-HUD von R3 (Rahmen, Aktionsleiste, Plaketten, Banner) und dem ShowOverlay im Kampfmodus; Minimap und
Erkundungshinweise blenden im Kampf aus (07 §2.8). Die echten Daten haben vor R4 keine `rt.bar`: Die Fixture gibt der Party eine
Leiste aus der Lernliste (Stufe 1: Slot 1 + SHOW), volle Leisten misst R3 (`rt_drawcalls`).
² Static + Character ohne Areas; +1 = der Kollisionsring (ein `StaticBody3D`, nur während des Kampfes).

| DC 3D Erkundung → Kampf (in Klammern: Prototyp 07 §8.10 ohne Effekte) | Compatibility high | Compatibility low | Mobile (Vulkan) high |
|---|---:|---:|---:|
| combat_regular | 100 → **113** (147 / 132³) | 54 → **73** (84) | 60 → **69** = 48 + 21 Schatten (74) |
| combat_two_groups | 113 → **141** (180 / 147³) | 61 → **96** (99) | 64 → **83** = 59 + 24 Schatten (82) |
| combat_boss_queen | 70 → **113** (138 / 112³) | 40 → **84** (82) | 38 → **67** = 52 + 15 Schatten (65) |
| DC UI · Materialien · Partikel (Emitter) · `Label3D` · Körper · Omni | 42–62 · 19–21 · ≤ 30 (3) · 3 · 25 · 3 | 41–59 · 19–22 · ≤ 44 (4) · ≤ 5 · 25 · 1 | 42–59 · 19–21 · ≤ 44 (4) · ≤ 4 · 25 · 3 |

³ Prototyp mit / ohne Echtzeitschatten der Komparsen (07 legt „ohne“ fest, so ist es gebaut). Alle drei Profile `PERF: OK`.

**Nachmessung R5b-1** (2026-10-11, Branch `ptd/r5b`, `tools/perf.sh --only=combat`, gleiche Szenarien und Welt-Fixture, das
heutige HUD mit Persona-Gesicht im Rahmen): DC 3D `combat_regular` / `combat_two_groups` / `combat_boss_queen` Compatibility
high **113 / 141 / 112**, low 74 / 96 / 82, Mobile (Vulkan, lavapipe) high 68 / 82 / 69 (inkl. Schatten); DC UI 43–61;
Materialien 19–22; Körper 26 (Kollisionsring +1); alle drei Profile `PERF: OK` — gleich zum Stand R2/R3 (Königin high 113 → 112).

**Nachmessung R5b-2b** (2026-10-12, Branch `ptd/r5b2b`, `tools/perf.sh --only=combat`, Compatibility high; gebackene Daten, die
Welt-Fixture baut die Leiste aus `rt.bar`, ohne CTB-Kampagne): DC 3D **113 / 141 / 113** (Erkundung → Kampf 100 → 113,
113 → 141, 72 → 113), DC UI 43 / 43 / 61, Primitive 40 938 / 50 706 / 57 707, Materialien 19 / 19 / 21, Partikel 28–30 (2–3
Emitter), Körper 26; `PERF: OK`. Director Ø 0,26–0,56 ms, p95 1,3–4,2 ms, Spitze ≤ 7,9 ms je Frame (llvmpipe, nur relativ).
low und Mobile in 2b nicht nachgemessen (keine Änderung an Kampfszene oder Rendering) [zu messen].

- **Schlechtester Fall `combat_two_groups`: DC 3D 141 von 150 mit Effekten** (Compatibility high; low 96, Mobile 83). Das
  Rig-LOD der Komparsen (Reserve aus 07 §8.10) ist nicht nötig; der Funken-Deckel (≤ 3 gleichzeitige Emitter) ist ohnehin
  umgesetzt (`scenes/combat/puppets.gd`). Komparsen und Beschwörungen werfen keine Echtzeitschatten, Akteure anderer Räume sind
  ausgeblendet, die 10 Telegraph-Quads teilen ein Material (Instanz-Uniforms), der Ring ist 1 Draw Call. Die Königin mit fünf
  Ratten bleibt mit 113 unter dem Fall mit zwei Gruppen (low 84 und Mobile 67 knapp über dem Prototyp: Adds + Zonen + Effekte).
- **Materialien:** +3 bis +6 im Kampf (Telegraph +1 und Ring +1 wie 07 §8.10, dazu Effekte); die Königin mit Rolltoren,
  Zuglinie, Pfützen-Zonen, Rauch und Adds erreicht 21–22 von 24.
- **Zeit** (llvmpipe auf der geteilten Maschine, Last ≈ 3–4 auf 4 Kernen; nur relativ, §2): Frame Ø (max) Erkundung → Kampf an
  derselben Stelle, Compatibility high: 201 (281) → 196 (283) ms (eine Gruppe), 264 (404) → 226 (307) ms (zwei Gruppen),
  210 (373) → 166 (252) ms (Königin) — kein Mehraufwand, die Software-Rasterung bestimmt die Zeit; Physik ≤ 7,3 ms je Frame.
  Der Director-Frame (`CombatDirector.cost_us`: Tick-Schleife samt Sim-Schritt und allen synchron angehängten Ereignis-Hörern —
  Show, HUD, Sfx, Puppen, Telegraphen) kostet Ø 0,18–0,49 ms, p95 0,4–3,9 ms (Frames mit Treffern), Spitze ≤ 6,7 ms — im Mittel
  ≤ 3 % eines 16,7-ms-Frames (low und Mobile gleich, Spitzen unter mehr Last bis 12 ms). Die Sim-Zeit je Tick (07 §3.15,
  ≤ 0,25 ms Desktop) misst R1b an der echten Sim; hier spielt die Fixture.

### 3.7 Persona-Look (Casting 08 §6.2, K2)

Stand 2026-10-11, Branch `ptd/k2`, Compatibility high. `tools/perf.sh --only=explore,battle,safe_room,combat --look=worst`
spielt jeden Abschnitt mit einer Kandidat:in im schwersten Look (Locken + Dreitagebart + Brille, Haarfarbe Schwarz, Ton 7,
Blaumann): Kai **2 940 statt 2 492 Tris (+448, +18 %), weiterhin 7 MeshInstances** — Haare, Bart und Brille liegen im
`Head`-Mesh (03_ART §5.3), es kommt kein Draw Call dazu. Vergleich mit der Basis `main` (`6a6d4da`, Kanon-Kai); die
Kampf-Eröffnungen zusätzlich mit dem Kanon-Kai auf demselben Stand (`--only=battle`, ohne Look).

| Abschnitt (Maximum) | DC 3D Basis → Look | DC UI Basis → Look | Primitive Basis → Look |
|---|---:|---:|---:|
| Erkundung, je Zone und Etage gesamt (6 Zonen × Zellen × 4 Richtungen) | 112 → **112** (jede Zone gleich: 89/77/112/88/72/101) | 88 → 88 | 48 804 → 50 596 (+1 792 je Ansicht) |
| Kampf-Eröffnungen (17 Begegnungen) | 55–126 → **55–126** | 129–167 → 129–167 | 49 305 → 50 893 |
| Komplette Kämpfe `enc_f1_d2` / Hausmeister / Königin | 130 / 105 / 133 → **130 / 105 / 133** | 153 / 150 / 161 → 153 / 150 / 163 | 57 034 / 52 864 / 67 335 → 59 716 / 55 554 / 69 369 |
| Safe Rooms Kiosk / Pumpenhaus / Stellwerk | 73 / 73 / 74 → **73 / 73 / 74** | 103 / 84 / 84 → 101 / 84 / 84 | 29 396 / 29 394 / 31 240 → 31 114 / 31 090 / 33 108 |
| Echtzeitkampf eine Gruppe / zwei Gruppen / Königin | 113 / 141 / 113 → **113 / 141 / 113** | 42 / 42 / 62 → 43 / 43 / 60 | 40 891 / 50 645 / 56 804 → 42 785 / 52 445 / 58 586 |
| **Budget** (02_TECH §12.1) | 150 / 150 / 120 | 100 / 180 / 100 | 120 000 / 120 000 / 60 000 |

- **Draw Calls 3D unverändert** in jeder deterministischen Zeile (Erkundung je Zone, komplette Kämpfe, Safe Rooms,
  Echtzeitkampf). Die Kampf-Eröffnungen (Frames 20–30 der Eröffnungs-Kamera) schwanken je Begegnung um ±1 zwischen zwei Läufen
  desselben Stands (Kanon-Kai: a3 95, c2 98; Look: 96, 97); `enc_f1_a_rare` 69 auf `main`, 73 auf K2 mit **und** ohne Look —
  Stichprobe der Kamerafahrt, nicht die Figur.
- **Primitive** +1 792 je Erkundungsansicht (die +448 Tris werden in mehreren Durchgängen gezählt: Farbe, Umriss-Hülle,
  Schatten), im Kampf bis +2 682 (dazu das HUD-Porträt); weit unter 120 000 bzw. 60 000.
- **UI-Draw-Calls** schwanken nur mit Text und Effekten (±2); der Safe Room Kiosk liegt schon auf `main` bei **103 > 100**
  (vorbestehend; mit dem Look 101) — nicht durch K2, offen in §8.2.
- **Materialien, Lichter, Körper, RAM** gleich (Haare, Kopftuch und Bart sind Vertex-Farben im Toon-Material der Figur;
  RAM-Spitze 247 MB).


### 3.8 Sim-Zeit je Tick (07 §3.15, R5b-1)

Stand 2026-10-11, Branch `ptd/r5b`. Gemessen wird nur `RtSim.step()` (headless, keine Darstellung), auf der geteilten
4-Kern-Maschine in einer ruhigen Phase (Last < 1); vorher = `88595ab` (vor der Optimierung), nachher = R5b-1. Die Läufe sind
kurz (600 Schritte ≈ 0,1 s) und streuen stark (einzelne Läufe +30–50 % durch Nachbarlast): je Variante 10 Läufe **abwechselnd**,
bewertet wird der Median der Lauf-Mediane.

| Messung | vorher | nachher |
|---|---:|---:|
| `rt_harness_main.gd --perf` (echte Daten: 2 Party + 6 Gegner der Zonen C/D mit ihren Regeln, 10 Formen), Median der 10 Lauf-Mediane (Spanne) | 206,5 µs (190–250) | **177 µs** (161–260) |
| `test_r1_rt_perf` / Benchmark-Szenario (Fixtures: 6 Gegner, 10 Füllformen), Median von 15 Läufen | ≈ 277 µs | 204–250 µs (zwei Durchgänge) |
| Zwei-Gruppen-Kampf mit Befehlen (`canned`) | – | 130 µs |
| CI-Balance-Test `test_r4_rt_balance` (40 Bosskämpfe + Regulär + Show-Boss), Summe der vier Tests im `check.sh`-Lauf | 72–75 s | ≈ 57 s (zwei Gate-Läufe) |

**Was sich geändert hat** (Commit `4a8a266`, ohne Verhaltensänderung — Benchmark-Hash `7de0245a…`, `canned`-Hash `e64961ae…` und
die vier Boss-Endstände gleich): Balance-Werte, Set-Geometrie (Ringradius, „schlichtes Set“, Zellhälfte) und Skill-Flächen als
Caches der Sim statt Dictionary-Zugriffe je Tick; ausstehende Treffer tragen ihren Fälligkeits-Tick; `targetable`/`may_act`
eingebettet; die KI-Regelwahl prüft über eine Meta-Tabelle je Skill vor (GCD als häufigste Absage zuerst) und fragt den
Fluchtzustand nur, wenn eine Regel ihn braucht; `escape_point` mit vorberechneter Versatz-Tabelle über nur die Gefahrenformen der
eigenen Seite; Bewegung mit Schnellpfaden für schlichte Sets (ein Punkt im Kreis |p| ≤ r − Radius ist begehbar); der Bot liest
die Sim über dieselben Helfer.

**Wohin die Zeit geht** (Fixture-Szenario, Phasen-Zeitmesser in einer Profil-Kopie, Anteile): KI-Denken ≈ 44 % (Regelwahl und
Aktionen der Gegner ≈ 11 %, ihre Zielwahl ≈ 5 %, Regelwahl der KI-Partnerin ≈ 7 %, ihre Reaktion auf Formen in jedem Tick
≈ 9 %), Bewegung ≈ 18 % (Abstoßen der Gegner ≈ 8 %), Treffer/Zauber, Auto-Angriffe und Zonen/Einschläge je 6–8 %,
Spielerpositionen, Status, Formen-Tracking je 3–4 %. Geprüft und verworfen: das Abstoßen über gepackte Arrays (gleich schnell —
die Kosten liegen im Schleifen-Overhead von GDScript, nicht im Feldzugriff); `DetMath.yaw_of` und `isqrt` (1,3 bzw. 4,3 Aufrufe
je Tick, zusammen < 3 µs). Nächster Hebel, falls nötig: die Formen als gepackte Arrays je Seite (Reaktion, Fluchtpunkt,
Zonen-Test und `safe_point` laufen jeden Tick über dieselben Felder).

### 3.9 Staffel-Etagen 2–6 (09 ST1-C1)

Stand 2026-10-12, Branch `ptd/st1c1`, Compatibility high, `tools/perf.sh --only=startup,explore,season` → `PERF: OK`. Der
Abschnitt `season` startet eine Basis-Staffel „Am Stück“ (Seed 4242, fester Start), nimmt mit `Game.season_debug_descend`
die Treppen bis zur gemessenen Etage und baut dort die **ganze** Etage — Viertel-Streaming gibt es erst mit ST1-C2 (09 C-18),
das Budget ist das der Erkundung (500 ms am PC). Danach jede Zelle × 4 Kamerarichtungen wie §3.1, je Viertel das Maximum.
Die geteilte 4-Kern-Maschine war während des Laufs belastet (Last 1 → 7,5); Etage 1 im selben Lauf als Bezug.

**Aufbau** (`ExplorationScene._ready`: Layout, Räume, Tore, Kisten, Events, Akteure, HUD). „Median“ = 9 warme Neubauten je
Etage in einer Mess-Kopie des Abschnitts (gleich danach, Last 3–4,6):

| Etage (Räume, Viertel) | kalt | warm | Median warm (min–max) | davon Layout | Budget |
|---|---:|---:|---:|---:|---:|
| 1 U-Bahn (31, handgebaut) | 405 ms | 304 ms | 305 ms (277–365) | 2 ms | 500 ms |
| 2 Passage Ewiger Rabatt (27, 2) | 265 ms | 275 ms | 245 ms (215–360) | 8 ms | 500 ms |
| 3 Der Fundus (32, 3) | 314 ms | 275 ms | 276 ms (254–378) | 9 ms | 500 ms |
| 4 Paketzentrum, Halle 4 (40, 3) | 415 ms | 372 ms | 362 ms (296–460) | 14 ms | 500 ms |
| 5 Paketzentrum, Halle 5 (41, 3) | 433 ms | 436 ms | 375 ms (332–452) | 13 ms | 500 ms |
| 6 Paketzentrum, Halle 6 (48, 4) | 418 ms | 428 ms | **408 ms** (350–525) | 16 ms | 500 ms |

- **Wohin die Zeit geht** (Phasen-Zeitmesser in einer Profil-Kopie, Etage 6 warm ≈ 416 ms): die Räume aus dem Bau-Kit
  (Meshes je Raum zusammenführen) ≈ 75 % — ≈ 6,5 ms je Raum, auf Etage 1 genauso —, Layout 13–27 ms, Events 16 ms, Tore und
  Kisten zusammen ≈ 25 ms, Akteure 20–30 ms, HUD ≈ 9 ms. Die Zeit wächst linear mit der Raumzahl. Die Türstürze wuchsen
  quadratisch (Etage 6: 32–52 ms) und sind behoben (§4.10); vorher lag Etage 6 warm in vier Läufen bei 466–585 ms, zweimal
  über 500. Die Raumzahl hängt am Seed (09 C-2: Etage 6 44–52 Räume über 200 Seeds); der gemessene hat 48, die größte
  Etage 6 kostet also ≈ 26 ms mehr (≈ 435 ms im Median).
- Der kalte Bau einer Staffel-Etage ist kaum teurer als der warme (Skripte und Shader kennt der Prozess schon von Etage 1);
  einzelne Neubauten unter Last bis 538 ms kalt (Etage 5) bzw. 525 ms warm (Etage 6).
- Das Layout (`ZoneGenerator.generate`, jeder Versuch eingeschlossen) braucht 8–16 ms; `test_09_zone_generator` misst es über
  200 Seeds je Etage (Mittel 9–24 ms, Höchstwert unter 250 ms).
- **Daten:** `GameData.load_dir` lädt mit den Etagen 2–6 ≈ 80 ms länger (headless, je 18 Ladungen abwechselnd mit dem
  Basisstand `187d2ed`: 280–490 ms → 350–515 ms). Der Start bleibt gleich: Boot-Timer abwechselnd, je drei Läufe —
  Autoloads 3,6–3,9 s → 3,6–3,7 s, Titel → Erkundung 2,5–5,1 s → 2,6–3,0 s (beides auf dieser Maschine langsamer als §6).

**Darstellung** (Etage gesamt, Maximum über alle Zellen × 4 Richtungen; ohne M.O.D.-Kasten und Toasts, s. u.):

| Etage | DC gesamt max | DC 3D | DC UI | Primitive | Omni aktiv | Lichter/Mesh | Materialien | Label3D | Partikel (Emitter) | Körper stat./kin. (Areas) | RAM MB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 (Bezug, gleicher Stand) | 203 | 112 | 94 | 50 644 | 4 + 1 Neon | 2 | 24 | 4 | 12 (2) | 5 / 20 (31) | 229 |
| 2 Passage | 193 | 104 | 94 | 46 811 | 4 | 2 | 14 | 6 | 6 (1) | 7 / 13 (26) | 204 |
| 3 Fundus | 197 | 108 | 94 | 48 413 | 4 | 2 | 16 | 5 | 6 (1) | 7 / 16 (25) | 213 |
| 4 Paketzentrum | 191 | 105 | 91 | 49 182 | 4 | 2 | 14 | 7 | 0 | 7 / 16 (26) | 215 |
| 5 Paketzentrum | 185 | 98 | 94 | 47 267 | 4 + 1 Neon | 2 | 15 | 4 | 6 (1) | 7 / 18 (27) | 213 |
| 6 Paketzentrum | 196 | 109 | 94 | 46 464 | 4 | 2 | 15 | 3 | 6 (1) | 7 / 20 (30) | 223 |
| **Budget** (02_TECH §12.1) | – | 150 | 100 | 120 000 | 4 + 1 | 3 | 24 | 12 | 400 (6) | 40 | 400 |

Die Staffel-Etagen liegen in jeder Größe auf oder unter Etage 1 (gleiche Raumteile, Lichter und HUD; 14–16 statt bis zu
24 Materialien). Statisch 7 Körper statt 5: die Tore (Schlüsseltor und die noch geschlossenen Programmtüren) behalten ihren
eigenen Blocker (§4.2). Zellen mit den meisten Draw Calls: Räume mit 2–3 sichtbaren Gruppen und Bossräume mit Bühne.

**M.O.D.-Kasten und Toasts.** Die Probe steigt in einem Zug von Etage 1 hinunter, ohne zu kämpfen; die Wett-Auflösungen und
Erfolge dieser Abstiege („Wette gewonnen!“ der Vorliebe „Friedliche Runde“, bis zu drei Toasts) stehen dann beim Abtasten
im Bild. Zusammen kosten sie ≈ 25–30 UI-Draw-Calls über der Erkundungs-UI: gemessen **102–125 > 100** auf den Etagen 2–6
(zwei Läufe vor dem Ausblenden), unabhängig von der Etage — es ist der Overlay-Stapel der Show, den ein Mensch nach einem
Abstieg ebenso sieht. Der Abschnitt `season` blendet beide Ebenen beim Abtasten aus und misst die Etagen; der Stapel steht
in §8.2.

### 3.10 Stempelduell (10 §6.10, SD2-G)

Stand 2026-10-12, Branch `ptd/sd2ui` (nach dem Merge des Staffel-Kerns ST1-B), Compatibility-Renderer unter Xvfb,
1280 × 720, `tools/perf.sh --only=stempel` → `PERF: OK`. Die Probe `tests/perf/sd_perf_probe.gd` spielt den Tisch gegen
den Stempelmeister in Phase 2 mit der Durchsage an zweiter Stelle, im echten `GlobalUi` und mit der Beispiel-Sammlung
(10 U-33). Die Werte standen bis hierher nur in 10 Kap. 7.3 (U-34) und sind von dort übernommen.

| Größe | Wert | Ziel (10 §6.10) |
|---|---:|---:|
| Regelbuch laden (bester von 3; das erste Mal mit Kompilieren der Skripte 33 ms) | 25,4 ms | ≤ 50 ms |
| Zug (Mittel, 63 Züge in 6 Duellen gegen den Stempelmeister) | 0,50 ms | ≤ 2 ms |
| Vorschau (Mittel, 315 Probeläufe) | 1,02 ms | ≤ 3 ms |
| Tisch aufbauen (warm; kalt mit Skripten und der Wartezimmer-Schleife 492 ms) | 7 ms | ≤ 300 ms |
| UI-Draw-Calls (ganzes Bild mit M.O.D.-Zeile, Höchstwert über 60 Frames) | 101 | ≤ 120 |
| 3D-Draw-Calls (die Duell-Box hat keine Drohne, 10 U-21) | 0 | 0 |
| `_process` im Leerlauf | keiner | keiner |
| Partikel-Emitter | 0 | ≤ 1 |

Die Tabelle ist der Lauf auf ruhiger Maschine. Über die Läufe der SD2-Sitzung (llvmpipe, teils neben zwei anderen
Full-Runs): Regelbuch 25–45 ms, Zug 0,5–0,9 ms, Vorschau 1,0–1,9 ms, Tisch warm 5–7 ms, UI-Draw-Calls 101 — immer
`PERF: OK`. Ohne `--only` läuft das Szenario `stempel` zuerst und bricht `perf.sh` bei einer Überschreitung ab. Auf den
mobilen Referenzgeräten (60 FPS, Quality `low`) ist das Duell noch nicht gemessen [zu messen].

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

### 4.10 Etagen-Aufbau: Türstürze vor dem Eintritt in die Welt (ST1-C1)

**Befund.** Phasen-Zeitmesser in einer Profil-Kopie von `ExplorationScene._ready` (Staffel-Etagen, §3.9): die Türsturz-Boxen
(§4.2) kosteten auf Etage 1 **14 ms**, auf Etage 6 der Basis-Staffel (48 Räume) **32–52 ms**. Jede Box kam in den Körper
„FloorCollision“, als er schon in der Welt war — Jolt baut dann die ganze Form des Körpers neu, je Tür einmal über alle Boxen
der Etage (wächst quadratisch mit der Raumzahl).

**Maßnahme.** `FloorBuilder.build_rooms` legt die Türstürze in den Körper, **bevor** er in die Welt kommt;
`build_door_lintels` gibt ihn dann nur zurück (ohne `build_rooms` baut es wie bisher einen eigenen Körper „DoorLintels“).
Dieselben Boxen in derselben Reihenfolge, ein Körper wie vorher.

**Wirkung.** Türstürze 14 → **0,1 ms** (Etage 1), 32–52 → **0,1 ms** (Etage 6). Verhalten unverändert: die Full-Runs
`--strategy=all`, `--hero=mopsula`, `--liga=1` und `--liga=2` gleichen dem Basisstand in jeder Ereigniszeile und Statistik.
(`test_perf_router_cycles`: ein Körper für Raumboxen und Stürze, ≤ 40 Körper; `test_m3_exploration_scene`: die Kamera
taucht vor einer Tür nicht unter den Sturz.)


---

## 5. Speicher und Lecks

### 5.1 Router-Zyklen

20 Zyklen Erkundung (jedes Mal neu gebaut) → Kampf (`enc_f1_a1_tutorial`, Auto-Kampf) → Safe Room → zurück, über den echten Router,
nach vorherigem Durchlauf aller Etagen-Ansichten. Je Zyklus nach 4 Frames: Objekte, davon Einträge der begrenzten Art-Caches
(Materialien, Figuren-Meshes ≤ 96 Modelle, getönte Effekt-Quads ≤ 64), Nodes, Ressourcen, verwaiste Nodes, RAM.

**Seit R5b-2b** ist der Kampf eines Zyklus der Echtzeitkampf in der Welt (Tutorial-Gruppe, Autopilot; die besiegten Gruppen
werden je Zyklus zurückgesetzt) und gemessen wird auf der Etage, die das `goto` des **nächsten** Zyklus neu gebaut hat: Die
Effekt-Pools eines Kampfes (`Vfx`, je Art höchstens 4 Knoten) hängen an der Etage, die sie erzeugt hat, und ihre Größe wechselt
mit jedem Kampf (in `test_perf_router_cycles` nach der Safe-Room-Rückkehr gemessen: 1 625–1 647 Nodes je Zyklus, ein
Schein-Wachstum von +4 Nodes zwischen den Fenstern; auf der neu gebauten Etage flach). Die Tabelle unten stammt aus dem
CTB-Stand [neu zu messen].

| Lauf | Objekte (ohne Caches) | Nodes | Ressourcen | verwaiste Nodes | RAM |
|---|---:|---:|---:|---:|---:|
| Compatibility high, Minimum Zyklen 2–6 → 16–20 (2026-10-10) | +1 (+0) | **+0** | **+0** | 0 | +0,2 MB |
| Compatibility high, Minimum Zyklen 2–6 → 16–20 (Phase C) | +22 (+11) | **+0** | **+0** | 0 | +4,5 MB (bis Zyklus 4, danach +0,3 MB über 16 Zyklen) |
| headless, Minimum Zyklen 2–6 → 16–20 | +18 (+7) | **+0** | **+0** | 0 | +8,4 MB (bis Zyklus 6, danach +0,3 MB) |

Urteil `LEAK: OK` in allen Läufen. Die Node-Zahl schwankt nur um Toasts und Ticker-Einträge der Show-Leiste (`--leak-diff`: je Zyklus
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
- **RAM je neuer Begegnung** im gerenderten Lauf ≈ +4 MB (renderer-seitig, §5.1, vor Phase C ebenso). Spitze 218–278 MB nach 20
  verschiedenen Kämpfen (2026-10-10: high 218, low 262, Mobile 230 MB) ist unter 400 MB; ein Lauf über beide Etagen auf dem Gerät sollte das bestätigen.
- **Kampf-UI nahe am Budget:** Eröffnungen auf low bis 170 von 180 Canvas-DC (Phase C: Tutorial 179; Tutorial-Hinweis +
  Befehlsmenü + Show-Leiste).
  Nächster Hebel: Ticker/Chat-Zeilen der Show-Leiste ohne Outline oder als ein Label.
- **Materialien im Kampf:** Spitzen 20–21 von 24 (Phase C 21–23), wenn Sponsor-Drop, Status- und Skill-Effekte zusammenfallen. Nächster Hebel:
  Status-Effekte (Glow/Hologramm je Status-Farbe) ebenfalls über Vertex-Farbe oder Instanz-Uniform tönen.
- **Erste Erkundung** kompiliert jetzt hinter „Neues Spiel“ (+0,5 s, verdeckt von der Blende); auf langsamen Geräten ggf. eine
  Lade-Animation in der Blende oder das Kompilieren während der Logo-Karte im Hintergrund (`ResourceLoader.load_threaded_request`).
- **Etage kalt im Mobile-Renderer 520 ms** (lavapipe, erste Pipeline-Erzeugung); warm 222 ms. Auf Geräten mit Pipeline-Cache
  prüfen.
- **Export:** Nur `--export-pack "Linux"` vollständig geprüft; Android/iOS/Windows/macOS brauchen Templates, SDK/Keystore bzw. Xcode
  (02_TECH §12.3) und einen Lauf auf echter Hardware. Bundle-ID ist ein Platzhalter.
- **Safe Room Kiosk, UI 101–103 Canvas-DC > 100** (Stand `main` `6a6d4da`, 2026-10-11; 2026-10-10 noch 87): kam mit den
  Zusammenführungen nach `ptd/final-a` dazu (Ursache noch nicht untersucht); unabhängig vom Persona-Look (§3.7).
- **Echtzeitkampf in der Welt (§3.6):** gemessen mit der Welt-Fixture (die echten Daten haben vor R4 keine `rt`-Blöcke).
  Die Sim-Zeit je Tick mit den echten Daten steht in §3.8 (R5b-1); die Darstellungs-Szenarien spielen weiterhin die Fixture
  (volle Last: 10 Formen, Komparsen, Adds) — R5b-1 hat sie mit dem heutigen HUD nachgemessen (§3.6, „Nachmessung R5b-1“).
- **Staffel-Etagen ganz gebaut (§3.9, ST1-C1):** ≈ 6,5 ms je Raum; Etage 6 (48 Räume) warm 408 ms im Median, einzelne
  Neubauten unter Last bis 525 ms. Die Etagen 7–18 haben dieselbe Größe (09 Kap. 3.6 Nr. 6: 36–48 Räume); das
  Viertel-Streaming (ST1-C2, 09 C-18) baut nur das aktuelle und die angrenzenden Viertel — Reserve am PC, auf Mobilgeräten
  (Richtwert 1,5 s) auf den Referenzgeräten zu messen. Nicht gemessen: Kämpfe auf den Etagen 2–6 (der Abschnitt `combat`
  spielt die Welt-Fixture); ihre Gegner nutzen die Archetypen und Fähigkeiten-Bausätze von Etage 1 (03_ART §2.5,
  09 C-14), die Bosse die von Hausmeister und Rattenkönigin (09 C-13).
- **Overlay-Stapel nach einem Abstieg (§3.9):** M.O.D.-Kasten („Wette gewonnen!“) und bis zu drei Toasts über der
  Erkundungs-UI ergeben 102–125 Canvas-DC > 100, solange sie stehen (wenige Sekunden). Hebel: Toasts zu einer Zeile bündeln
  oder nacheinander zeigen, solange der M.O.D.-Kasten offen ist.

---

## 9. Reproduzieren

```bash
GODOT=/pfad/zu/godot-4.7.2 tools/perf.sh --out=perf_gl_high.md --cells            # Compatibility, high, alles
GODOT=… tools/perf.sh --quality=low --only=startup,explore,battle,safe_room          # Compatibility, low (Mobil-Standard)
GODOT=… tools/perf.sh --driver=vulkan --only=startup,explore,battle,safe_room        # Mobile-Renderer (Vulkan-ICD nötig)
GODOT=… tools/perf.sh --headless --only=startup,leak --cycles=20                     # Zeiten + Router-Zyklen ohne Rendering
GODOT=… tools/perf.sh --only=combat                  # Echtzeitkampf in der Welt (07 §8.10): combat_regular, _two_groups, _boss_queen
GODOT=… tools/perf.sh --only=season                  # Staffel-Etagen 2–6 (09 ST1-C1): Aufbau je Etage, Layout, jede Zelle × 4
GODOT=… tools/perf.sh --only=stempel                 # Stempelduell (10 §6.10): Regelbuch, Zug, Vorschau, Tisch, DC
# Diagnose: --mat-dump (Materialien des Spitzen-Frames), --leak-diff (Node-Arten je Zyklus), --full=<enc,…>, --shots=<dir>
```

Exit-Code 1 bei Budget- oder Leck-Überschreitung. `check.sh` bleibt die einzige CI-Prüfquelle; dort sichern
`tests/test_perf_router_cycles.gd` (8 Router-Zyklen ohne Wachstum, Etagen-Aufbau ≤ 1,5 s, ≤ 40 Körper, Licht-Layer, Quality-low-
Raumlicht) und `tests/test_perf_platform.gd` (Mobil-Einstellungen, Export-Presets, Icons, Boot ohne Screen-Klassen) die Ergebnisse.
