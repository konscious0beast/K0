# PRIME TIME DUNGEON — Echtzeitkampf „WoW-light“ (verbindlich ab R1)

> Status: **verbindlicher Vertrag** für die Umstellung vom CTB-Kampf (01_GDD §3, 02_TECH §5) auf Echtzeitkampf direkt in der
> Welt (Nutzerentscheidung „Variante 3 — WoW-light direkt in der Welt“). Gilt für die Umsetzungsphasen R1–R5 (§12).
> Vorrang: `00_BRIEF` > **dieses Dokument** (für alles Kampfrelevante: APIs, Schemas, Befehle, Pfade, Zahlenstruktur) >
> `02_TECH` > `01_GDD` > `03_ART` > `04`/`05`. Bis zum Abschluss von R5 bleibt der CTB-Kampf hinter dem Schalter
> `combat_mode` (§12.1) unverändert lauffähig; mit R5 ersetzen §2–§11 dieses Dokuments 01_GDD §3 und 02_TECH §5.
> Engine: Godot **4.7.2-stable (official)**. Engine-Fakten mit **(geprüft)** wurden am installierten Binary gemessen
> (Headless + Xvfb, Renderer Compatibility/OpenGL 3.3 und Mobile/Vulkan; Protokoll in Anhang A).
> Sprache: Prosa Deutsch. Bezeichner, Pfade, JSON-Keys, Signal-/Methodennamen Englisch. Pfade relativ zu
> `prime-time-dungeon/game/` (= `res://`). Stand: 2026-10-10.

---

## Inhalt

0. [Kurzfassung](#0-kurzfassung)
1. [Ziele und Prinzipien](#1-ziele-und-prinzipien)
2. [Kampffluss in der Welt](#2-kampffluss-in-der-welt)
3. [Simulation (Kern)](#3-simulation-kern)
4. [Fähigkeiten](#4-fähigkeiten)
5. [Partner-KI](#5-partner-ki)
6. [Gegner-KI und Bosse](#6-gegner-ki-und-bosse)
7. [Steuerung und UX](#7-steuerung-und-ux)
8. [HUD (TV-Overlay)](#8-hud-tv-overlay)
9. [Show-System und Marotten](#9-show-system-und-marotten)
10. [Live, Replay und Netz](#10-live-replay-und-netz)
11. [Balancing-Ziele](#11-balancing-ziele)
12. [Migrations- und Umsetzungsplan](#12-migrations--und-umsetzungsplan)
13. [Risiken und offene Punkte](#13-risiken-und-offene-punkte)
- [Anhang A: Engine-Prüfprotokoll](#anhang-a-engine-prüfprotokoll)
- [Anhang B: Glossar](#anhang-b-glossar)

---

## 0. Kurzfassung

| Thema | Entscheidung |
|---|---|
| Ort | Gekämpft wird in dem Raum, in dem man sich trifft (das **Set**). Keine Kampfszene, kein Szenenwechsel, kein Swirl. |
| Start | Spieler greift an (Feldschlag, Fähigkeit auf ein Ziel) **oder** eine Gruppe bemerkt ihn (bestehende Wahrnehmung, ALERT 0,6 s). Erstschlag/Hinterhalt bleiben als „Überrumpelt“-Zustand erhalten (§2.2). |
| Bedienung | Ziel wählen (Tab / Klick / Antippen), Auto-Angriff läuft automatisch, Aktionsleiste: 4 Fähigkeiten + **SHOW**-Taste + **Trank** (PC-Tasten 1–6). |
| Ressource | **MP für beide** („Energie“, eine blaue Leiste). Kai lädt MP durch eigene Treffer, Graf Mopsula über Zeit (§3.10). |
| Partner | Die nicht gesteuerte Figur spielt die KI mit 3 Taktiken (Angriff/Unterstützen/Vorsichtig) und 3 Schaltern (Unterbrechen/Show-Einlagen/Tränke). Die **Heldenwahl** bestimmt, wen man steuert; bei K.O. der gesteuerten Figur wechselt die Steuerung zur lebenden (§5). |
| Gegner | Bedrohungsliste, sichtbare Zauberleisten, unterbrechbare Zauber, Boden-**Telegraphen** (Kreis, Kegel, Ring, Linie) mit Warnzeit; jede Gegnerfamilie hat genau eine Signatur-Mechanik (§6). |
| Bosse | Drei Phasen mit je einer neuen Mechanik, weiches Enrage; Rattenkönigin mit einfahrendem Zug als Linien-Telegraph quer über den Bahnsteig (§6.7). |
| Determinismus | `RtSim` (`core/rt/`, RefCounted) mit 30 Ticks/s, nur Ganzzahlen (HP, MP, cm, Ticks, ‰), Zufall pro Ereignis aus `SeedUtil.derive`. **Spielerbewegung** geht als aufgezeichnete Positionsproben mit Schwellen in die Sim (Client-autoritativ wie in WoW); Gegner, KI-Partner, Status, Schaden rechnet nur die Sim, die Szene stellt dar (§3.5). |
| Show | Neue Hype-Anlässe (Unterbrechen, Ausweichen, perfekte Bossphase), Sponsor-Geschenke landen ohne Pause mit kurzem Banner, M.O.D. kommentiert als Untertitel (§9). |
| Uhr | Der Etagen-Timer steht im Kampf („die Uhr steht“, Brief); im Kampf öffnet kein Sponsor-Fenster (§2.10). |
| Umsetzung | R1 Kern → danach parallel R2 Welt, R3 HUD+Eingabe, R4 Inhalte+Balance → R5 Integration, Show, Live/Replay, Bot, CTB-Entfernung (§12). |

---

## 1. Ziele und Prinzipien

1. **WoW-light, nicht WoW.** Übernommen werden die lesbaren Kernideen: Ziel wählen, Auto-Angriff, Aktionsleiste mit
   Abklingzeiten, globale Abklingzeit (GCD), Zauberleisten, Unterbrechen, Bedrohung (Aggro) und Spott, Buffs/Debuffs mit Timern,
   Boden-Telegraphen, Bossphasen, Tränke mit eigener Abklingzeit. **Nicht** übernommen: Blickrichtungs-Pflicht, Springen,
   Freies Zielen/Skillshots des Spielers, Kombopunkte, zweite Ressource, Eigenbeschuss (Friendly Fire), Rüstungsklassen,
   Trefferchance-Würfe (alles trifft; Würfel nur für Varianz, Krit, Status, Stunt-Erfolg).
2. **Einfach und sofort verständlich.** Höchstens 5 Fähigkeiten pro Figur (4 + SHOW) plus Trank. Die Leiste **wächst mit dem
   Level** (Stufe 1: Kai 1 Fähigkeit + SHOW, Mopsula 2 + SHOW; ab Stufe 4 voll). Pro Gegnerfamilie genau **eine** neue Mechanik,
   pro Bossphase genau **eine** neue Mechanik. Jede gefährliche Aktion ist dreifach angekündigt: Bodenform + Ton + Zauberleiste
   mit Namen.
3. **Auf einen Blick lesbar.** Formen statt Zahlen: rot-weiß gestreifte Bodenflächen = „raus da“, goldener Rand an einer
   Zauberleiste = „unterbrechbar“, Punkt über dem Gegner in Partyfarbe = „wen er angreift“. Schadenszahlen klein und kurz,
   Wichtiges groß (UNTERBROCHEN!, AUSGEWICHEN).
4. **Mobile zuerst.** Alles mit zwei Daumen erreichbar: linker Stick, rechte Daumen-Gruppe (§7.3). Auto-Angriff ohne Taste,
   automatische Zielwahl (nächster Gegner, „Smart-Heilung“ auf den schwächsten Verbündeten), Eingabepuffer von 300 ms
   (Queue-Fenster, §3.6), alle Trefferflächen ≥ 88 px. PC und Gamepad nutzen dasselbe Modell mit Tasten.
5. **Deterministisch.** Alles Spielrelevante steckt in `RtSim` (core, RefCounted, keine Szene, keine Autoloads, keine Uhr):
   feste 30 Ticks/s, Ganzzahl-Arithmetik, Zufall nur über pro Ereignis abgeleitete Seeds, Eingaben nur als aufgezeichnete Befehle.
   Ein Lauf ist aus Seed + Befehlen bitgenau reproduzierbar (Brief §6b, 05 §3.3).
6. **Das Show-System ist erstklassig.** Jede Mechanik erzeugt Show-Ereignisse (Unterbrechung, knappes Ausweichen, perfekte Phase,
   Zug-Kill), die Hype, Chat, M.O.D. und Sponsoren füttern. Geschenke kommen ohne Pause im laufenden Kampf an.
7. **MMO-lite-fähig.** Die Sim kennt 1–4 Party-Einheiten und bis zu 6 Gegner (Raids später mehr), keine „Kai ist immer p0“-
   Annahmen, Befehle tragen die Einheit. Später läuft dieselbe Sim server-autoritativ mit 30 Hz (§10.8).
8. **Humor und Abwechslung.** Jede Mechanik hat einen Witz (die Rattenkönigin wird vom eigenen Zug erwischt, der Hausmeister
   verliest die Hausordnung, der Pendler schaut auf die Uhr). Kein Inhalt verwendet Namen oder Eigenheiten fremder Werke.

---

## 2. Kampffluss in der Welt

### 2.1 Begriffe

| Begriff | Bedeutung |
|---|---|
| **Set** | Die Raumzelle (`FloorLayout`-Zelle, 16 × 16 m), in der der Kampf stattfindet: die Zelle der gesteuerten Figur beim Start. |
| **Kampf** | Eine `RtSim`-Instanz. Es läuft höchstens ein Kampf gleichzeitig. |
| **ct** | Kampf-Tick (0, 1, 2, …), 30 pro Sekunde, zählt ab Kampfstart. Die Lauf-Uhr `k` (RunSim) steht währenddessen (§2.10). |
| **Teilnehmer** | Party-Einheiten (`p0`…`p3`) und Gegner-Einheiten (`e0`…), die beim Start im Set stehen, plus Beschwörungen. |
| **Telegraph** | Angekündigte Bodenfläche (Kreis, Kegel, Ring, Linie), die nach der Warnzeit einschlägt (§6.3). |
| **Zone** | Bleibende Bodenfläche nach einem Einschlag (z. B. Giftpfütze), wirkt periodisch. |

### 2.2 Auslöser und Erstschlag

Die Wahrnehmung der Erkundung bleibt unverändert (GDD §2.3: Sichtkegel mit Sichtlinien-Raycast, Hören, ALERT 0,6 s, Patrouille,
Verfolgung, Rückkehr; Bosse bei 5 m um `boss_spot`). Neu ist nur, **wann** daraus ein Kampf wird und welcher Vorteil gilt.
Der Kontakt bei 1,1 m entfällt als Auslöser.

| Auslöser | Ergebnis (`BattleSetup.Advantage`) |
|---|---|
| Spieler trifft eine Gruppe mit dem Feldschlag (Bogen 100°, 1,8 m, unverändert) oder setzt eine Fähigkeit/einen Gegenstand auf einen Gegner im eigenen Raum ein („Pull“), Gruppe in IDLE/PATROL **oder** Spieler steht hinter dem Anführer (`dot(fwd_e, d_ek) < BACK_DOT`) | `PREEMPTIVE` („Erstschlag!“) |
| wie oben, Gruppe ist ALERT/CHASE und sieht den Spieler | `NORMAL` |
| ALERT einer Gruppe läuft ab, während Anführer und Spieler im selben Raum sind, und der Spieler kehrt ihr den Rücken zu (`dot(fwd_k, d_ke) < BACK_DOT`) | `AMBUSH` („Hinterhalt!“) |
| ALERT läuft ab, sonst | `NORMAL` |
| Gruppe verfolgt aus einem Nachbarraum und betritt den Raum des Spielers | wie „ALERT läuft ab“ (Rückenregel zum Zeitpunkt des Betretens) |
| Boss (5 m um `boss_spot`), Etagen-Event-Kampf, Tutorial | `NORMAL` |

Wirkung des Vorteils (ersetzt den CTB-Vorsprung):

- `PREEMPTIVE`: alle Gegner erhalten `sts_dazed` („Überrumpelt“) für 3,0 s — keine Angriffe, keine Fähigkeiten, 50 % Tempo.
  Bosse sind immun. Hype wie bisher (+3, ShowRules `HYPE_START_PREEMPTIVE`).
- `AMBUSH`: alle Party-Einheiten erhalten `sts_dazed` für 1,5 s. Hype +5 (Drama, `HYPE_START_AMBUSH`).
- Die Warnphase ALERT (0,6 s, „!“-Blase + Ton) ist die faire Vorwarnung: Wer sich in dieser Zeit zur Gruppe dreht, wird nicht
  überrascht.

Ein Pull mit Fähigkeit/Gegenstand außerhalb des Kampfes startet den Kampf und führt die Fähigkeit als **Eröffnung** bei `ct = 0`
aus (`RtSetup.opener`, §3.4). Der Feldschlag als Eröffnung wird bei `ct = 0` zum ersten Auto-Angriff-Schwung auf den getroffenen
Gegner (Treffer bei `ct = 9`). Außerhalb des Kampfes sind Fähigkeiten nur als Pull nutzbar; Heilen außerhalb des Kampfes geht
über Gegenstände, Regeneration (§2.7) und Safe Rooms.

### 2.3 Aggro, Sichtlinie und Mitziehen (Social Pull)

- **Sichtlinie in der Sim** (`RtGeo.los`, §3.5): zwei Punkte sehen sich, wenn sie in derselben Zelle liegen oder in
  Nachbarzellen und die Verbindungsstrecke die gemeinsame Türöffnung (4 m breit, Wandmitte) kreuzt. Requisiten blockieren nichts
  (sie stehen nur im Randstreifen, §3.5.4). Die Erkundungs-Wahrnehmung (Raycast gegen Layer `world`) bleibt Grad B (05 §3.3);
  ihr Ergebnis geht über den aufgezeichneten `encounter`-Befehl in den Lauf ein.
- **Mitziehen:** Am Kampf nehmen alle Gruppen teil, deren Anführer beim Start im Set steht (höchstens 2 Gruppen, höchstens
  6 Gegner-Einheiten; weitere Gruppen bleiben außen vor). Gruppen außerhalb des Sets **frieren ein** (die Uhr steht) und spielen
  ihre Idle-Animation („Ruhe am Set!“ — M.O.D.-Zeile `combat_set_quiet`, höchstens einmal pro Etage).
- **Komparsen-Auftritt:** In der Erkundung zeigt jede Gruppe nur ihren Anführer (+ Pips, unverändert). Beim Kampfstart springen
  die übrigen Mitglieder in Formation neben den Anführer (0,5 s Rauchwolke, 15 Ticks handlungsunfähig, §3.5.5). Die Formation
  ist deterministisch (`RtGeo.formation`), aufgezeichnet wird nur die Position des Anführers.

### 2.4 Kampfzustand pro Raum

- Es läuft höchstens ein Kampf. Das Set ist die Zelle der gesteuerten Figur beim Start (`FloorLayout.world_to_cell`).
- Gegner-Einheiten bleiben immer im Set (begehbare Fläche §3.5.4); sie verlassen es nie.
- Im Kampf sind **alle Interaktionen gesperrt** (Truhen, Hebel, Etagen-Events, Tore, Treppe, Safe-Room-Tür); die Aktionstaste hat
  Kampfbedeutung (§7).
- Türen: bleiben offen bei regulären Kämpfen (Flucht möglich); schließen sich (sichtbar + Kollision) bei Bossen, im Tutorial und
  bei `EncounterDef.can_flee == false` („Die Tür ist zu — die Show muss weitergehen!“).
- Nach `VICTORY` ist das Set geräumt (besiegte Gruppen verschwinden wie bisher, `defeated_groups`).

### 2.5 Flucht, Rücksetzen (Leash/Reset)

- **Flucht** = die gesteuerte Figur steht **60 aufeinanderfolgende Ticks (2,0 s)** außerhalb der Set-Zelle. Ab Tick 15 außerhalb
  zeigt das HUD „Zurück ans Set! 2… 1…“ (`FLEE_WARNING`, M.O.D. `combat_flee_warn`). Der KI-Partner folgt der gesteuerten Figur
  automatisch, sobald sie den Raum verlässt.
- Die **Taschen-Nebelmaschine** (`itm_smoke`) löst die Flucht sofort aus (nicht bei Bossen/`can_flee == false`).
- Ergebnis `FLED`: Hype −30 (`FLEE_RESULT`), Follower −1 % (bestehende Regeln), K.O.-Mitglieder → 1 HP, 2 s Schonfrist
  (`GRACE_SEC`). Die Gegner **setzen zurück**: volle HP, Status gelöscht, zurück an ihre Startpositionen, Exploration-Zustand
  `RETURN` (ignoriert den Spieler 2 s). Ein Leash über Entfernung gibt es im Kampf nicht mehr — die Raumgrenze ist die Leine.
- Bei Bossen, im Tutorial und bei `can_flee == false` ist das Set verschlossen: Proben außerhalb werden auf die Türöffnung
  zurückgesetzt (`POS_CORRECTED`), eine Flucht gibt es nicht.

### 2.6 K.O., Wiederbelebung, Niederlage

- Eine Einheit mit 0 HP ist **K.O.**: liegt am Boden, wird nicht angegriffen, verliert alle Status, regeneriert nicht.
- Fällt die **gesteuerte** Figur, wechselt die Steuerung sofort zur lebenden Partnerfigur („Steuerung folgt dem Leben“,
  `CONTROL_CHANGED`, Banner „Kai ist K.O. — du spielst jetzt Graf Mopsula!“). Die Heldenwahl gilt ab dem nächsten Kampf wieder.
  Voraussetzung ist die Laufzeit-Umschaltung der Heldenwahl (`ExplorationScene.control(member_id)`, §5.1); bis sie vorliegt,
  greift die Ersatzregel „Zuschauermodus“ (Partner spielt auf Autopilot, Kamera folgt ihm).
- **Wiederbelebung im Kampf:** Mopsula ab Stufe 7 (Slot 2 wird auf einem K.O.-Ziel automatisch zu „Sabber der Wiederkehr“,
  §4.3) oder Riechsalz (`itm_smelling_salts`). Wiederbelebte erhalten `sts_guard` für 3,0 s („Comeback“).
- Nach `VICTORY`/`FLED`: K.O.-Mitglieder stehen mit 1 HP auf (bestehende Regel `KO_REVIVE_HP`).
- **Niederlage** (alle Party-Einheiten K.O.): `DEFEAT` → bestehender Sendeschluss/Game-Over-Ablauf mit Neuladen (unverändert).
  Sterben Party und letzter Gegner im selben Tick, zählt es als **Sieg** („Doppel-K.O. — die Show liebt Drama“).
- Tutorial: Party-HP fallen nie unter 1 (bestehende Regel), Gegnerschaden × 0,5.

### 2.7 Regeneration außerhalb des Kampfes

- Neuer Schritt 6 in `RunSim._tick_once` (nur Erkundungs-Ticks, Uhr läuft): **90 Ticks nach Kampfende** und dann alle **90 Ticks**
  erhält jedes Party-Mitglied mit HP > 0 `max(1, div_round(max_hp × 10, 1000))` HP (1 %) und `max(1, div_round(max_mp × 20, 1000))`
  MP (2 %), gedeckelt auf das Maximum. Zähler: `floor_run.regen_ticks` (gespeichert, gehasht), wird bei Kampfende auf 0 gesetzt.
- Werbepause (+15 % Max-MP nach jedem Sieg, `POST_BATTLE_MP_REGEN`) und Safe Rooms (Vollheilung) bleiben.
- Die Startwerte (`RtBalance.REGEN_*`) stellt R4 mit dem Harness ein (§11).

### 2.8 Kampfstart-Präsentation (ersetzt Swirl und Szenenwechsel)

| Zeit | Was passiert |
|---|---|
| 0,0 s | `ct = 0`: Sim läuft sofort. Kurzer Broadcast-Stinger (0,4 s Weißblitz 15 %, „KAMPF!“-Bauchbinde 1,2 s), Musik-Überblendung 0,5 s auf `battle`/`boss`, ShowOverlay-Modus `&"combat"`, Kampf-HUD blendet ein (0,25 s), Minimap und Erkundungshinweise blenden aus. |
| 0,0–0,5 s | Komparsen-Auftritt (Rauchwolke), Kamera zoomt auf 8 m (Boss 9 m), §7.5. |
| ab 1,0 s | Erste Gegner-Angriffe (`FIRST_SWING_TICKS = 30`), bei `PREEMPTIVE` erst nach 3,0 s. |

`Router` ist nicht beteiligt (kein `start_battle`, kein Szenenstapel). `Events.battle_started` / `Events.battle_ended` feuern wie
bisher (gleiche Bedeutung für Show, Achievements, Musik).

### 2.9 Bosse: Intro im Bossraum

1. Auslöser: die gesteuerte Figur kommt 5 m an `boss_spot` (unverändert). Die Erkundung friert ein, Eingabe gesperrt.
2. Türen schließen (0,3 s, Ton „Rolltor“), Kamerafahrt „Boss-Kran“ 2,5 s (03_ART §8: `boss_intro`) **in der Welt**, Banner
   „BOSS: Der Hausmeister“ mit Titelzeile, blockierende M.O.D.-Zeile `boss_intro:<enemy_id>` (die einzige blockierende Zeile im
   Kampfkontext).
3. Danach `ct = 0` mit `NORMAL`. Während des Intros tickt die Sim **nicht** (es gibt noch keine `RtSim`; sie wird erst nach dem
   Intro erzeugt, und erst dann wird der `encounter`-Befehl aufgezeichnet). Die Erkundungsuhr steht während des Intros wie bei
   jedem blockierenden Dialog.
4. Nach dem Sieg: Abspann-Panel (§8.9), Türen öffnen, `Events.boss_defeated` wie bisher.

### 2.10 Etagen-Timer und Sponsor-Fenster im Kampf

- **Die Uhr steht** (Brief; GDD §2.9; 05 §6.13): Während eines Kampfes läuft `RunSim` nicht (`is_clock_running() == false` solange
  `combat != null`), weder Etagen-Timer noch Hype-Verfall, Streuner-Spawns oder Fenster-Uhr. Anzeige: Timer grau mit Zusatz
  „Uhr steht“.
- **Im Kampf öffnet kein Sponsor-Fenster.** Ein vor dem Kampf geöffnetes Fenster bleibt mit seiner Restzeit eingefroren und nimmt
  weiter Geschenke an (bestehende Regel). Angenommene externe Geschenke werden an der **nächsten Tick-Grenze** angewendet
  (§9.2): kurzer Banner 1,5 s (Sponsor-Bauchbinde, verkürzt), Drohnen-Effekt am Ziel, **keine** Pause.
- System-Geschenke (Hype-Schwellen 70/85/100, höchstens 1 pro regulärem Kampf / 2 pro Bosskampf) werden nach jedem Tick
  geprüft und am Anfang des nächsten Ticks angewendet.
- Im Live-Modus `timer_mode: realtime` (05 S4) liefe die Lauf-Uhr auch im Kampf; dieses Dokument hängt nicht davon ab
  (§10.2: `k` würde dann mit `ct` mitlaufen).

### 2.11 Kampfende

- `VICTORY`: alle Gegner-Einheiten K.O. oder entkommen (`ESCAPED`, z. B. Fahrscheinfresser); die Sim setzt `result`.
- Reguläre Kämpfe: **nicht blockierende** Bilanz „Applaus!“ (3,0 s, §8.9) mit EXP, Credits, Funden; Stufenaufstiege als Banner.
  Modale Dialoge (z. B. die parallel entstehende **Talentwahl**) öffnen erst **nach** Kampfende und nur außerhalb eines Kampfes.
- Bosskämpfe: Abspann-Panel (pausiert, wie das bisherige Ergebnisbild), danach Türen auf.
- Danach unverändert: `Game.end_combat(result)` → `Game.apply_battle_result` (BattleBridge, §12.6) → `Show.end_battle` →
  `Events.battle_ended`. Die Sim-Instanz wird verworfen; Komparsen-Rigs bleiben unsichtbar im Pool (§8.10).

### 2.12 Ablaufbeispiel (Zone A, Stufe 2)

1. Kai schleicht von hinten an eine patrouillierende Gruppe (Kanalratte, Taubenschwarm, Kanalratte) und drückt `1` mit der Ratte
   im Visier → Pull, `PREEMPTIVE`, `ct = 0`: Wuchtschlag startet (GCD 1,5 s), alle Gegner 3 s überrumpelt, Komparsen springen
   ins Bild.
2. `ct = 9`: Wuchtschlag trifft (20 Schaden, Kanalratte 96 → 76). Auto-Angriff läuft seitdem alle 2,0 s.
3. Graf Mopsula (KI, „Unterstützen“) niest Kais Ziel mit Frostniesen an und zaubert danach Adelsflamme (1,5 s).
4. `ct ≈ 190` (6 s + Slot-Versatz): Der Taubenschwarm kündigt „Sturzflug“ an — roter Kreis unter Mopsula (die Tauben hacken auf
   die Schwächste), 1,2 s. Mopsula weicht nach 12 Ticks aus (Reaktionszeit Unterstützen). `TELEGRAPH_DODGED` → Hype +2.
5. Ratten fallen, die Tauben zuletzt; nach ~15 s `VICTORY`, Bilanz-Bauchbinde, weiter geht's.

---

## 3. Simulation (Kern)

### 3.1 Modul, Schichten, Dateien

Neues Kern-Modul **RT** unter `core/rt/` (Eigentum R1, §12.3). Alle Klassen `extends RefCounted` (bzw. erben von M1-Klassen),
keine Nodes, keine Autoloads, kein `await`, keine Uhr, kein globaler Zufall (02_TECH §0.4, Lint §3.14).

```
core/data ← core/stats ← core/battle (M1) ← core/rt (RT) ← core/live (M8: RunSim, StateHash, Command)
core/progression (M2: BattleBridge.make_rt_setup) → core/rt   (BattleBridge baut RtSetup; core/rt kennt BattleBridge nicht)
scenes/combat (R2/R3), autoload/game.gd, autoload/show.gd → core/rt   (nie umgekehrt)
```

| Datei | `class_name` | Zweck |
|---|---|---|
| `core/rt/rt_sim.gd` | `RtSim` | Ein Kampf: Befehle annehmen, Ticks rechnen, Ereignisse liefern, Ergebnis (§3.4) |
| `core/rt/rt_setup.gd` | `RtSetup` (extends `BattleSetup`) | Startdaten eines Kampfes |
| `core/rt/rt_unit.gd` | `RtUnit` (extends `Combatant`) | Einheit mit Position, Timern, Zauber, Bedrohung |
| `core/rt/rt_status.gd` | `RtStatus` (extends `StatusEffect`) | Status mit Tick-Ende, Periode, Stapeln |
| `core/rt/rt_telegraph.gd` | `RtTelegraph` | Telegraph oder Zone (Form, Anker, Zeiten) |
| `core/rt/rt_rules.gd` | `RtRules` | Regel-Engine für Gegner-KI, Partner-KI, Autopilot, Assist (§5.3, §6.2) |
| `core/rt/rt_command.gd` | `RtCommand` | Schema-Prüfung und Bauhelfer der Kampfbefehle (§10.1) |
| `core/rt/rt_geo.gd` | `RtGeo` | Begehbare Fläche, Sichtlinie, Formen-Test, Formation, Ausweichpunkte |
| `core/rt/det_math.gd` | `DetMath` | Ganzzahl-Trigonometrie (Tabellen), `isqrt`, Gier-Winkel (u8) |
| `core/rt/rt_balance.gd` | `RtBalance` | Konstanten (§3.16); Werte per Balancing änderbar, Struktur nicht |
| `core/rt/rt_mods.gd` | `RtMods` | Modifikatoren aus Talentwahl, Marotten, Spezies, Spezialisierung, Ausrüstung, Twists (§9.5) |
| `core/rt/rt_ability.gd` | — (privat) | Fähigkeiten/Gegenstände: Prüfung, Kosten, Zauber, Kanal, Wirkung |
| `core/rt/rt_damage.gd` | — (privat) | Echtzeit-Multiplikatoren um `DamageCalc` herum |
| `core/rt/rt_threat.gd` | — (privat) | Bedrohungslisten, Spott, Zielwechsel |
| `core/rt/rt_movement.gd` | — (privat) | Positionsproben, Koppelnavigation, Lenkung, Abstoßung |
| `core/rt/rt_result.gd` | — (privat) | `BattleResult`-Bilanz, Beute-Würfe |

### 3.2 Einheiten und Umrechnungen

| Größe | Einheit (Ganzzahl) | Regeln |
|---|---|---|
| Zeit in der Sim | Tick (1/30 s) | `ct` ab 0; `TICKS_PER_SEC = 30` |
| Zeit in Daten | ms | Vielfache von 100 → `ticks = ms * 3 / 100` (exakt). Validator prüft `ms % 100 == 0`. |
| Strecken | cm, raumlokal | Ursprung = Zellmitte (`FloorLayout.cell_to_world(cell)`), +x Ost, +z Süd (Godot-Achsen), Boden y = 0 |
| Geschwindigkeit in Daten | cm/s | Vielfache von 30 → cm/Tick exakt (`cm_s / 30`). Validator prüft `% 30 == 0`. |
| Geschwindigkeit in Proben | mm/Tick | `vx`, `vz` der Positionsproben (§3.5.1), je Achse \|v\| ≤ 400 (Schema) |
| Blickrichtung | Gier `yaw` ∈ 0…255 | 0 = −Z (Godot vorwärts), 64 = −X, 128 = +Z, 192 = +X (gegen den Uhrzeigersinn von oben, wie `rotation.y`). Szene → Sim: `posmod(roundi(rotation.y * 256.0 / TAU), 256)` |
| Richtungsvektor | ×1024 | `DetMath.dir(yaw) = (−SIN1024[yaw], −COS1024[yaw])` aus Tabellen |
| Winkel in Daten | ganze Grad 0…180 | `DetMath.cos_deg1024(deg)` aus 91-Einträge-Tabelle + Symmetrie |
| Anteile | ‰ (`pm`, 1000 = 100 %) oder bp (10000) | Würfe in bp (`FixedMath.roll_bp`), Multiplikatoren in ‰ |
| HP, MP, Schaden, Bedrohung | ganze Zahlen | Multiplikation vor Division, Runden mit `FixedMath.div_round` (halb weg von 0) |

GDScript-Fakten, auf die sich `DetMath` stützt (geprüft): `int` ist 64 Bit und läuft bei Überlauf um; `/` auf `int` schneidet
Richtung 0 ab (`-7 / 2 == -3`), `%` übernimmt das Vorzeichen des Dividenden (`-7 % 2 == -1`), `posmod(-1, 256) == 255`;
`const T: PackedInt32Array = [...]` ist als Konstante erlaubt; `sqrt(float(n))` + ganzzahlige Korrekturschleife liefert die exakte
Ganzzahlwurzel (geprüft für 15, 2 147 395 600, 10¹² + 1). **Regel:** Nie `/` auf negativen Zwischenwerten ohne `FixedMath.div_round`
oder `posmod` — alle Rundungen sind explizit.

### 3.3 Tick-Ablauf (exakte Reihenfolge)

`RtSim.step()` rechnet den Tick `c = tick()` und erhöht danach `tick()` um 1. Einheiten-Reihenfolge überall: Party nach Slot
(`p0`, `p1`, …), dann Gegner nach Nummer (`e0`, `e1`, …, Beschwörungen zählen weiter, Nummern werden nie wiederverwendet).
Innerhalb einer Liste gilt die Erzeugungsreihenfolge (Telegraphen, Zonen, ausstehende Treffer, Status).

| Schritt | Inhalt | Ereignisse |
|---|---|---|
| 1 Befehle | Alle mit `submit()` für `ct == c` eingereihten Befehle in Aufzeichnungsreihenfolge anwenden: `move_sample`, `target_change`, `auto_attack`, `autopilot`, `partner_preset`, `ability_use`, `combat_item`. Dynamische Prüfungen (GCD, MP, Reichweite, Abklingzeit) erst hier; abgelehnte Befehle erzeugen `ACTION_REFUSED`. Geschenke/Twists wurden schon an der Tick-Grenze angewendet (§9.2). | `ACTION_REFUSED`, `TARGET_CHANGED`, `PRESET_CHANGED`, `ACTION_START`, `CAST_START` |
| 2 Status-Ticks | Für jede Einheit, jeden Status (Anwendungsreihenfolge): periodische Wirkung, wenn `next_tick_at == c`; dann Ablauf, wenn `ends_at == c`. | `DAMAGE`/`HEAL` (mit `status_id`), `STATUS_REMOVED`, `KO` |
| 3 Zonen | Für jede Zone: periodische Wirkung auf gegnerische Einheiten in der Fläche, wenn fällig; Ende, wenn `ends_at == c`. | `DAMAGE`, `STATUS_ADDED`, `ZONE_END` |
| 4 Telegraph-Einschläge | Für jeden Telegraphen mit `impact_at == c`: Treffermenge bestimmen (§6.3), Wirkung je Einheit, Ausweicher melden, ggf. Zone erzeugen. | `TELEGRAPH_IMPACT`, `TELEGRAPH_DODGED`, `DAMAGE`, `ZONE_START`, `KO` |
| 5 Ausstehende Treffer | Sofort-Fähigkeiten, Auto-Angriffe, Gegenstände mit `at == c` (Wirkzeitpunkt §3.6.7). Verfällt, wenn der Verursacher K.O. ist. | `DAMAGE`, `HEAL`, `STATUS_*`, `COMBO`, `KO`, `REVIVE` |
| 6 Zauber-/Kanalende | Für jede Einheit mit `cast.end == c`: Wirkung (Nicht-Telegraph-Zauber); Kanal-Ticks, wenn fällig. | `DAMAGE`, `HEAL`, `STATUS_*`, `ACTION_END` |
| 7 Warteschlange + KI | Für jede Einheit: zuerst gepufferte Fähigkeit (Queue) starten, wenn GCD/Zauber frei; dann KI für sim-gesteuerte Einheiten (Gegner, KI-Partner, Autopilot) über `RtRules` (§5.3, §6.2): Fähigkeit starten oder Bewegungsziel setzen. | `ACTION_START`, `CAST_START`, `TELEGRAPH_START`, `TARGET_CHANGED` |
| 8 Auto-Angriffe | Für jede Einheit: wenn Auto an, Ziel feindlich und lebend, in Reichweite, nicht zaubernd/betäubt/überrumpelt und `swing_ready <= c` → Treffer bei `c + 9` einreihen, `swing_ready = c + swing_ticks`. | `SWING` |
| 9 Bewegung | Spieler-Einheiten: Koppelnavigation aus der letzten Probe (§3.5.1). Sim-Einheiten: Lenkung, dann Abstoßung, dann Klemmen auf die begehbare Fläche (§3.5.3). Flucht-Zähler der gesteuerten Einheit. | `POS_CORRECTED`, `FLEE_WARNING` |
| 10 Phasen, Enrage, Ende | Boss-Schwellen (`PHASE_CHANGE` + `on_enter`), Enrage-Zeiten, Kampfende prüfen: alle Gegner K.O./entkommen → `VICTORY` (auch wenn die Party im selben Tick fiel), alle Party K.O. → `DEFEAT`, Flucht → `FLED`, `ct ≥ MAX_COMBAT_TICKS` → `FLED` („Sendezeit überzogen!“). | `PHASE_CHANGE`, `MOD_LINE`, `ENRAGE`, `SUMMON`, `BATTLE_END` |
| 11 Takt | MP-Regeneration über Zeit (§3.10), alle 30 Ticks `SECOND` (Wert = volle Kampfsekunden). | `MP_CHANGE`, `SECOND` |

K.O. tritt **sofort** ein, wenn HP in Schritt 2–6 auf 0 fallen: spätere Wirkungen desselben Ticks treffen die Einheit nicht mehr,
ihre eigenen ausstehenden Treffer, Zauber und Telegraphen verfallen (`TELEGRAPH_CANCELLED`, `CAST_FAILED`).

### 3.4 Datenmodell und API

```gdscript
class_name RtSetup extends BattleSetup
## Start data of one real-time combat. Built by BattleBridge.make_rt_setup (R1) from the recorded encounter command.
## Inherited and still used: encounter_id, group_id (first group), enemy_ids (first group), party (Combatant snapshots),
## items, credits_available, advantage, seed, is_boss, can_flee, tutorial, enemy_dmg_mult, exp_mult, show_mods,
## theme_id, palette, floor_index. Not used: auto_battle (→ presets/autopilot).
var cell: Vector2i = Vector2i.ZERO          # Set cell
var doors: int = 0                          # RoomCell door bits of the Set (N 1, E 2, S 4, W 8), from the floor layout
var room_kind: int = 0                      # RoomCell.Kind
var units: Array[RtUnit] = []               # party (slot order), then enemies (group order, formation order)
var groups: Array[Dictionary] = []          # [{"group_id", "encounter_id", "enemy_ids": PackedStringArray, "lead": [x, z, yaw], "state": String}]
var controlled_id: String = "p0"            # unit id the player controls (hero choice, §5.1)
var presets: Dictionary = {}                # unit id → {"preset": "attack"|"support"|"careful", "tog": {"interrupt": bool, "show": bool, "potions": bool}}
var auto_attack: bool = true                # initial auto-attack switch of the controlled unit (GameSettings.auto_attack_default)
var auto_retarget: bool = true              # pick the next target when the current one falls (GameSettings.auto_retarget)
var opener: Dictionary = {}                 # {} | {"kind": "strike", "target": "e0"} | {"kind": "skill", "u": "p0", "skill": id, "target": "e0"} | {"kind": "item", "u", "item", "target"}
var mods: Array[Dictionary] = []            # RtMods entries (§9.5), canonical
var rules: Dictionary = {}                  # combat-relevant run rules (§10.7), canonical
var difficulty: StringName = &"prime"       # &"vorabend": telegraph warn times × RtBalance.EASY_WARN_PM

func to_dict() -> Dictionary                 # canonical (BattleSetup.to_dict() + the fields above; units as snapshots)
```

```gdscript
class_name RtUnit extends Combatant
## A combatant with position, timers, cast, threat. Ids, stats, hp/mp, statuses (RtStatus), element mods, rewards:
## inherited from Combatant (02_TECH §5.4). max_hp() is already scaled (§3.9.4).
enum Driver { PLAYER, AI, AUTOPILOT }      # not "Control": would shadow the global Control class
var driver: RtUnit.Driver = Driver.AI
var x: int = 0                              # cm, room-local
var z: int = 0
var yaw: int = 0                            # 0..255
var radius: int = 40                        # cm
var move_cm_tick: int = 18                  # base speed (data cm/s / 30)
var stationary: bool = false
var keep_cm: int = 0                        # ranged: preferred distance to the target (0 = melee)
var follow_cm: int = 0                      # AI partner: max distance to the controlled unit while idle
var sample: Array[int] = []                 # PLAYER: last move sample [ct, x, z, vx, vz, yaw] (vx/vz mm per tick)
var goal: Array[int] = []                   # sim-driven: [x, z] movement goal of this tick ([] = stand)
var target_id: String = ""
var auto_on: bool = true
var auto_skill: String = ""                 # auto-attack skill id ("" = none)
var auto_ranged_skill: String = ""          # fallback auto-attack when the target is out of reach (§6.2)
var swing_ticks: int = 60
var reach: int = 250                        # auto-attack reach in cm
var swing_ready: int = 0                    # ct of the next possible swing
var gcd_until: int = 0
var cast: Dictionary = {}                   # {} | {"skill", "target", "x", "z", "start", "end", "interruptible": bool, "moving_cancels": bool, "channel": bool, "next_tick": int, "tele": int, "kind": "ability"|"item", "item": String}
var queued: Dictionary = {}                 # {} | {"skill"|"item", "target", "at": ct of the press}
var cooldowns: Dictionary = {}              # skill id → ct when ready again
var item_cd_until: int = 0
var lockout_until: int = 0                  # interrupted: no new casts before this ct
var threat: Dictionary = {}                 # enemies: unit id → int
var fixate_id: String = ""                  # enemies: forced target (taunt) …
var fixate_until: int = 0                   # … until this ct
var rules: Array[Dictionary] = []           # compiled RtRules of the current phase / preset
var rule_ready: Dictionary = {}             # rule key → ct when the rule may fire again
var follow_up: Dictionary = {}              # {} | {"skill", "target", "at"}: queued "then" skill of a rule (§5.3)
var preset: String = ""                     # party AI preset
var toggles: Dictionary = {}                # party AI switches
var react_at: int = -1                      # AI: ct at which the pending telegraph reaction starts
var mp_regen: Dictionary = {}               # {"mode": "hit"|"time", "amount", "crit_bonus", "every_ticks"}
var mp_regen_next: int = 0
var threat_pm: int = 1000                   # unit threat multiplier (Kai 1500)
var dmg_pm: int = 1000                      # enemies: RtBalance-independent damage knob (EnemyDef.rt.dmg_pm)
var ko_at: int = -1
var outside_since: int = -1                 # controlled unit: first ct outside the Set (flight), -1 inside
var pop_in_until: int = 0                   # formation members: no actions before this ct
var phase_perfect: bool = true              # bosses: no telegraph hit on the party during the current phase
var bar: Dictionary = {}                    # party: slot (1..5) → skill id (current loadout, level-filtered)

func snapshot() -> Dictionary               # canonical, all fields above + Combatant.to_dict()
```

```gdscript
class_name RtStatus extends StatusEffect
## Real-time status: ends at a tick, optional period, stacks. turns_left/fresh (CTB) stay 0/false.
var ends_at: int = -1                       # ct of expiry (-1 = until combat end)
var period: int = 0                         # ticks between periodic effects (0 = none)
var next_tick_at: int = -1
var stacks: int = 1
var applied_at: int = 0
func to_dict() -> Dictionary                # {"id", "source_id", "ends_at", "period", "next_tick_at", "stacks", "applied_at"}
```

```gdscript
class_name RtTelegraph extends RefCounted
## Announced ground shape (telegraph) or lingering zone. Geometry in room-local cm; read by the TelegraphLayer.
enum Shape { CIRCLE, CONE, RING, LINE }
var id: int = 0                             # unique per combat, increasing
var source_id: String = ""
var skill_id: String = ""
var side: int = 0                           # Combatant.Side that gets hit
var shape: RtTelegraph.Shape = Shape.CIRCLE
var x: int = 0                              # center (circle/ring), apex (cone), start (line)
var z: int = 0
var yaw: int = 0                            # cone/line direction
var r: int = 0                              # radius (circle/ring outer/cone length) or line length
var r2: int = 0                             # ring inner radius or line width
var half_deg: int = 0                       # cone half angle
var start: int = 0                          # ct of the announcement
var impact_at: int = 0                      # ct of the impact (telegraph) / -1 for zones
var is_zone: bool = false
var ends_at: int = -1                       # zones
var period: int = 0                         # zones
var next_tick_at: int = -1                  # zones
var status_id: String = ""                  # zones: status applied per period
var tick_skill: String = ""                 # zones: skill applied per period
var inside_last: Dictionary = {}            # unit id → last ct inside (dodge detection, §6.3)
func contains(px: int, pz: int) -> bool     # DetMath shape test, center point only ("Fußpunkt-Regel")
func to_dict() -> Dictionary
```

```gdscript
class_name RtSim extends RefCounted
## One real-time combat (07 §3). Deterministic: same RtSetup + same submitted commands (with ct) → same events, same
## snapshot hashes. No autoloads, no SceneTree, no clock: the caller decides when a tick passes.
const TICKS_PER_SEC: int = 30
var setup: RtSetup = null
var result: BattleResult = null             # set when finished

func _init(p_setup: RtSetup, p_data: GameData) -> void
func start() -> Array[ActionEvent]          # ct 0 prelude: BATTLE_START, ANNOUNCE, STATUS_ADDED (dazed), PHASE_CHANGE (bosses), opener queued
func submit(cmd: Dictionary) -> String      # schema + static checks (RtCommand.validate, unit exists/controllable, ct >= tick(), skill on the unit's bar/unlocked); "" = queued for cmd.ct
func step() -> Array[ActionEvent]           # processes tick(), returns its events (§3.3)
func tick() -> int                          # index of the next tick to process (= processed ticks)
func is_finished() -> bool
func controlled_id() -> String              # may change on KO (CONTROL_CHANGED)
func unit(id: String) -> RtUnit             # null if unknown
func units() -> Array[RtUnit]               # stable order (§3.3); read-only for callers
func telegraphs() -> Array[RtTelegraph]     # active telegraphs and zones, creation order; read-only
func apply_gift(g: Dictionary) -> Array[ActionEvent]    # at a tick boundary (before step), §9.2
func apply_twist(t: Dictionary) -> Array[ActionEvent]   # at a tick boundary, whitelisted effects only, §9.5
func can_use(unit_id: String, skill_id: String, target_id: String) -> String   # "" or refusal reason (HUD states), no side effects
func cooldown_left(unit_id: String, skill_id: String) -> int     # ticks (shared SHOW/FINALE cooldown included)
func gcd_left(unit_id: String) -> int
func suggest(unit_id: String) -> String     # Assist (§5.6): skill id of the next suggested ability or ""
func run_to_end(max_ticks: int) -> Array[ActionEvent]   # headless: step until finished or max_ticks (RunSim, harness)
func snapshot() -> Dictionary               # canonical, complete (StateHash.of_rt, §10.4)
```

Ablehnungsgründe (`submit` und `ACTION_REFUSED.text`, feste Liste `RtCommand.REASONS`): `schema`, `past_tick`, `finished`,
`unknown_unit`, `not_controlled`, `dead`, `not_learned`, `stunned`, `casting`, `gcd`, `cooldown`, `mp`, `range`, `los`,
`target`, `item_cd`, `no_item`, `forbidden`, `locked`.

**Zwei Prüfstufen:** `submit()` prüft nur Schema und statische Bedingungen (vor dem Tick); alles Dynamische (GCD, MP, Reichweite,
Abklingzeit, Ziel lebt) prüft Schritt 1 des Ticks. Dadurch ist die Annahme eines Befehls unabhängig davon, ob noch andere Befehle
im selben Tick folgen, und das Replay entscheidet identisch. Aufgezeichnet wird jeder von `submit()` angenommene Befehl (§10.2).

### 3.5 Bewegung und Positionen

#### 3.5.1 Spielerbewegung: Positionsproben (Client-autoritativ mit Schwellen)

**Entscheidung:** Die gesteuerte Figur bewegt sich wie bisher mit `CharacterBody3D.move_and_slide` in der Szene (Physik, Wände,
Requisiten). Die Sim erhält ihre Position als **aufgezeichnete Proben** `move_sample` und rechnet zwischen zwei Proben mit
Koppelnavigation (Dead Reckoning) in geschlossener Form:

```
pos(c) = (s.x + div_round(s.vx * (c − s.ct), 10),  s.z + div_round(s.vz * (c − s.ct), 10))   # mm/Tick → cm, ohne Drift
```

Begründung: (1) Physik/Jolt ist plattformübergreifend nicht deterministisch (05 §3.3; nicht prüfbar, also nicht verwenden),
(2) direkte, verzögerungsfreie Steuerung auf Mobilgeräten, (3) Replay und späterer Server sehen exakt dieselben Positionen wie
die Sim, (4) bewährtes MMO-Muster. Gegner und KI-Partner bewegt ausschließlich die Sim.

Der `MoveSampler` (Szene, R2) erzeugt pro Kampf-Tick, **vor** `submit`/`step`, eine neue Probe, wenn eine Bedingung gilt:

| Bedingung | Schwelle (`RtBalance`) |
|---|---|
| Abweichung tatsächliche Position ↔ Koppelnavigation | > `DR_THRESHOLD_CM = 15` cm |
| Geschwindigkeitsänderung (je Achse) | > `DR_VEL_THRESHOLD = 15` mm/Tick (≈ 0,45 m/s) |
| Blickrichtung ändert sich im Stand | > `DR_YAW_THRESHOLD = 8` Stufen (≈ 11°) |
| Herzschlag in Bewegung | ≥ `HEARTBEAT_TICKS = 15` seit der letzten Probe |
| Stillstand erreicht | einmal mit `vx = vz = 0` |
| **Pflichtprobe vor Einschlag:** ein gegnerischer Telegraph schlägt bei `c + 1` ein | Abweichung > `FORCE_SAMPLE_CM = 2` cm |

Probenwerte: `x, z` = gerundete raumlokale cm der Fußposition; `vx, vz = roundi(v_m_s * 1000 / 30)` (mm/Tick); `yaw` u8.
Damit ist die Sim-Position nie mehr als 15 cm von der gezeigten entfernt und beim Einschlag eines Telegraphen exakt (±2 cm).

#### 3.5.2 Prüfung der Proben

- Geschwindigkeit: `|v| ≤ max_v` mit `max_v = ceil(PLAYER_RUN_CM_S × 10 / 30 × move_pm / 1000 × SPEED_TOLERANCE_PM / 1000)`
  (`PLAYER_RUN_CM_S = 550`, `SPEED_TOLERANCE_PM = 1250`, `move_pm` aus Status/Mods).
- Sprung: Abstand neue Probe ↔ Koppelnavigation zum selben `ct` ≤ `MOVE_TOLERANCE_CM (40) + (c − s.ct) × ceil(max_v / 10)`.
- Raum: im Set gilt `|x|, |z| ≤ 760` oder Türkorridor (`|quer| ≤ 200` bei vorhandener Tür); außerhalb der Set-Zelle (Flucht) nur
  Geschwindigkeitsprüfung. Verschlossene Sets (§2.5): Positionen außerhalb werden geklemmt.
- Betäubt, überrumpelt (`no_move`) oder K.O.: Proben mit Bewegung werden auf die Haltposition gesetzt.
- Verletzung → Position wird geklemmt/zurückgesetzt, Ereignis `POS_CORRECTED` (`target_id`, `rt.x`, `rt.z`); die Szene setzt die
  Figur im selben Frame dorthin (`player.teleport`). Im ehrlichen Einzelspieler-Lauf tritt das nur bei Fehlern auf.

#### 3.5.3 Sim-gesteuerte Bewegung (Gegner, KI-Partner, Autopilot)

- Tempo pro Tick: `move_cm_tick × move_pm / 1000` (Status: Verlangsamt 600, Turbo 1200, Überrumpelt 500; Mods).
- Ziel (`goal`), gesetzt von der KI in Schritt 7: Nahkampf → Punkt auf der Verbindungslinie im Abstand `reach + r_ziel −
  MELEE_STOP_CM (30)`; Fernkampf (`keep_cm > 0`) → näher heran, wenn Abstand > `keep_cm + 200`, zurück, wenn < `keep_cm − 200`;
  Ausweichen → `RtGeo.escape_point` (§5.5); Folgen → bis `follow_cm` an die gesteuerte Figur; sonst stehen.
- Schritt: geradlinig Richtung `RtGeo.project_walkable(goal)`, Länge `min(tempo, Abstand)`, Komponenten per
  `div_round(d × tempo, abstand)`.
- Abstoßung (nur Gegner untereinander): für jedes Paar `i < j` mit Abstand `< r_i + r_j` beide um die halbe Überlappung entlang
  der Verbindung auseinander; bei identischer Position `i` nach −x, `j` nach +x. Danach erneut klemmen. Party und Gegner
  blockieren sich **nicht** (kein Body-Blocking; die Spielerphysik kollidiert nur mit `world`, Maske 1).
- Ausrichtung: beim Angreifen/Zaubern zum Ziel (`DetMath.yaw_of`), sonst in Laufrichtung.
- **Unerreichbar-Regel:** Steht das Ziel eines Nahkämpfers ≥ `UNREACHABLE_TICKS = 90` außerhalb der Reichweite, während der
  Nahkämpfer am Rand der begehbaren Fläche steht, wirft er Gegenstände (`skl_e_throw`: 60 Kraft, 1500 cm, alle 3 s) bis das Ziel
  wieder erreichbar ist. („Er wirft mit Dosen!“) Bosse besitzen eigene Fernangriffe.

#### 3.5.4 Begehbare Fläche, Sichtlinie

Aus dem Raumbau bekannt: Raum 16 × 16 m, Wand-Innenseite bei 7,5 m, Türen 4 m breit mittig, Requisiten nur bei ≥ 5,4 m Abstand
von der Mitte und außerhalb der 3,6 m tiefen Türkorridore (`RoomBuilder._slot_free`). Daraus:

```
walkable(p) = |p| ≤ WALK_R_CM (480)
           ∨ für jede vorhandene Tür d: |quer_d(p)| ≤ DOOR_HALF_CM (160) ∧ 0 ≤ längs_d(p) ≤ CORRIDOR_END_CM (710)
```

`RtGeo.project_walkable(p)` liefert den nächstgelegenen begehbaren Punkt (Kandidaten: Kreisprojektion und je Korridor die
Rechteck-Projektion; kleinster Abstand, Gleichstand in Reihenfolge Kreis, N, E, S, W). `RtGeo.los(a, b, layout)` gilt nach §2.3.

#### 3.5.5 Formation und Startpositionen

`RtGeo.formation(slot)` (Anführerraum, +dz = hinter dem Anführer, cm): Slot 0 `(0, 0)`, Slot 1 `(−130, 90)`, Slot 2 `(130, 90)`,
Slot 3 `(0, 180)`; gedreht mit der Gier des Anführers, dann `project_walkable`. Party: gesteuerte Figur aus ihrer ersten Probe,
Partner aus seiner aufgezeichneten Position. Nicht-Anführer haben `pop_in_until = 15`.

#### 3.5.6 Darstellung

Die Szene liest `RtSim.units()` nach jedem Tick und interpoliert sim-gesteuerte Einheiten zwischen vorigem und aktuellem Tick
(Anteil = Rest des Tick-Akkumulators; Gier über den kürzeren Bogen). Die gesteuerte Figur zeigt immer ihre Physikposition.
Umrechnung cm → m: `room_origin + Vector3(x / 100.0, 0, z / 100.0)` (nur in der Szene).

### 3.6 Kampf-Timing

1. **GCD:** Fähigkeiten mit `rt.gcd == true` setzen `gcd_until = c + GCD_TICKS (45)`. Turbo: × 750 ‰ (= 34), nie unter
   `GCD_MIN_TICKS = 30`. Verlangsamt: × 1250 ‰ (= 56). Gegenstände, Spott, Unterbrecher sind GCD-frei.
2. **Auto-Angriff:** Schwungtakt `swing_ticks = swing_ms × 3 / 100` × Tempo-Faktor (Turbo 750, Verlangsamt 1250, Mods). Der
   Schwungtimer läuft unabhängig von Fähigkeiten; während Zauber/Kanal wartet er (Schwung erst danach). Kein Ziel / außer
   Reichweite → kein Schwung, `swing_ready` bleibt (sofortiger Schwung, sobald in Reichweite). Erster Gegner-Schwung frühestens
   bei `ct = 30`.
3. **Zauberzeit:** `cast_ms > 0` → `CAST_START`, Wirkung bei `start + cast_ticks` (Tempo-Faktor wie GCD, Minimum 15 Ticks).
   Während des Zaubers: kein weiterer Zauber, keine GCD-Fähigkeit, kein Auto-Schwung; GCD-freie Fähigkeiten und Gegenstände
   erlaubt (beenden den Zauber nicht).
4. **Kanal:** `channel_ms > 0` → Wirkung alle `period_ms` während des Kanals (erster Tick nach `period`), Ende nach `channel_ms`.
5. **Bewegung bricht:** Hat die Fähigkeit `moving_cancels` (Standard `true` für Zauber/Kanäle der Party) und meldet eine
   `move_sample` mit `vx ≠ 0 ∨ vz ≠ 0` während des Zaubers, endet er sofort (`CAST_FAILED`, `text = "moved"`); MP werden erst bei
   Wirkung abgezogen, die Abklingzeit startet nicht, der GCD läuft weiter. Sim-gesteuerte Einheiten bewegen sich nie während
   eines eigenen Zaubers.
6. **Queue-Fenster:** Ein `ability_use`, der in Schritt 1 auf GCD oder Zauber mit ≤ `QUEUE_TICKS = 9` Restzeit trifft, wird
   gepuffert (eine Fähigkeit; eine neue ersetzt die alte) und startet in Schritt 7 des Ticks, in dem GCD/Zauber frei werden.
   Mehr Restzeit → `ACTION_REFUSED` (`gcd` bzw. `casting`).
7. **Wirkzeitpunkt sofortiger Aktionen:** Treffer werden nach `impact_ms` (Standard nach Animation: `attack` 300 ms = 9 Ticks,
   `stunt` 800 ms = 24, `item` 300 ms = 9, Zauber 0 = bei Zauberende) als ausstehender Treffer eingereiht. Ziel und Wirkung
   stehen beim Start fest (auch wenn das Ziel sich entfernt). Die Darstellung darf Trefferanzeigen um ≤ 200 ms verzögern
   (Projektilflug), die Sim nicht.
8. **Unterbrechen:** Fähigkeiten mit `rt.interrupt` und jede Betäubung brechen einen laufenden **unterbrechbaren** Zauber/Kanal
   des Ziels ab: `CAST_INTERRUPTED` (Täter, Opfer, Zauber), der Zauber geht in seine Abklingzeit bzw. Regelwartezeit, Sperre
   `lockout_until = c + INTERRUPT_LOCKOUT_TICKS (60)` für neue Zauber; ein zugehöriger Telegraph verschwindet
   (`TELEGRAPH_CANCELLED`). Nicht unterbrechbare Zauber (`interruptible: false`) laufen weiter, auch unter Betäubung.
9. **Reichweite:** Abstand Mitte–Mitte ≤ `range_cm + r_ziel` (Nahkampf `reach + r_ziel`). Flächen um ein Ziel brauchen das Ziel in
   Reichweite, Flächen um sich selbst keine.
10. **Sichtlinie:** `RtGeo.los` (im Set praktisch immer gegeben).
11. **Ausrichtung:** Es gibt keine Blickrichtungs-Pflicht. Kegel der Party zeigen zum Ziel; die Darstellung dreht die Figur.
12. **Abklingzeiten:** `cooldowns[skill] = c_start + cooldown_ticks` beim Wirkungsbeginn (Sofort) bzw. bei Zauberende. SHOW und
    FINALE teilen sich eine Abklingzeit (Schlüssel `"show"`).

### 3.7 Bedrohung (Threat)

| Quelle | Bedrohung auf Gegner `e` |
|---|---|
| Schaden von `u` an `e` | `div_round(amount × threat_pm(u) × skill.rt.threat_pm, 1 000 000)`; `threat_pm(u)`: Kai 1500, Mopsula 1000 (party.json `rt.threat_pm`), Mods |
| Heilung durch `u` (Menge `h`) | jeder lebende Gegner im Kampf: `max(1, div_round(h × HEAL_THREAT_PM (500), 1000 × n_gegner))` |
| Debuff von `u` auf `e` | +`DEBUFF_THREAT = 10` |
| Spott „Hier spielt die Musik!“ (Radius 10 m) | `threat[kai] = max(threat[kai], top × TAUNT_TOP_PM (1100) / 1000 + 1)` + `sts_taunted` 4 s (Fixierung auf Kai) |
| Start | Auslöser (Eröffner bzw. bei `AMBUSH` die nächste Party-Einheit) bekommt 1 auf allen Gegnern; Beschwörungen 1 auf der nächsten Party-Einheit |

- Zielwahl eines Gegners für Auto-Angriff und Regeln mit Ziel `threat_top`: Fixierung aktiv → Fixierungsquelle; sonst behält er
  sein Ziel, bis eine andere Einheit `> aktuell × THREAT_SWITCH_PM (1100) / 1000` hat; Gleichstand → kleinerer Slot.
- K.O. setzt die Bedrohung der Einheit auf allen Gegnern auf 0 (nach Wiederbelebung neu ab 0).
- Partner-KI und Spieler wählen Ziele **nicht** nach Bedrohung (§5).
- Anzeige: Namensplaketten zeigen einen Punkt in der Farbe des angegriffenen Party-Mitglieds; Party-Rahmen zeigen „×2“ für die
  Zahl der Gegner, die gerade dieses Mitglied angreifen (§8.4).

### 3.8 Status-Effekte in Echtzeit

- Anwenden: Immunität (`status_immune`, `rt.immune`) → `STATUS_BLOCKED`; Widerstand (`status_resist`, Wurf in bp) →
  `STATUS_BLOCKED`; Chance des Skills (`rt.statuses[].chance_pm`) gewürfelt. Dauer: `rt.statuses[].ms` oder
  `StatusDef.rt.default_ms`, auf Bossen × `boss_ms_pm` (Betäubung 500).
- Erneut anwenden (`stack_mode`): `refresh` → Dauer neu, Stapel +1 bis `max_stacks`; `replace` (Standard) → Dauer neu, Stapel 1;
  `ignore` → keine Wirkung, solange aktiv. `excludes` entfernt die ausgeschlossenen Status (`STATUS_REMOVED`) wie bisher.
- Periodisch (`period_ms > 0`): erster Tick `applied_at + period`, dann je `period`. Wirkung `tick_pct` (negativ = Schaden in %
  der Max-HP, positiv = Heilung) × Stapel, Betrag mindestens `tick_min` × Stapel; Schaden mit Element (`StatusDef.element`,
  Element-Multiplikatoren gelten, Immunität → 0), kein Krit, keine Varianz.
- Stapel wirken wie n Kopien: `dmg_dealt_pm`, `dmg_taken_pm`, `move_pm`, `haste_pm` werden je Stapel multipliziert.
- Flags (`StatusDef.flags` + RT-Flags): `no_act` (keine Fähigkeiten, keine Auto-Angriffe), `no_move`, `no_cast` (keine Zauber/
  Kanäle), `fixate` (Träger muss die Quelle angreifen), `interrupt_on_apply` (bricht unterbrechbare Zauber), `hidden` (kein
  Symbol), `guard` (bestehend: DEF/RES-Faktor über `stat_mult` und DamageCalc).
- Entfernen: Ablauf, `cleanse`-Listen von Fähigkeiten/Gegenständen, K.O. (alle), Flucht/Ende (alle).

| Status | Dauer | Periode | Wirkung | Stapel | Sonstiges |
|---|---|---|---|---|---|
| `sts_poison` Vergiftet | 8,0 s | 2,0 s | −2 % Max-HP (min 1) je Stapel | 3, `refresh` | Element Gift |
| `sts_stun` Betäubt | 2,0 s | — | `no_act`, `no_move`, `interrupt_on_apply` | 1, `ignore` | Bosse × 0,5 |
| `sts_slow` Verlangsamt | 4,0 s | — | `move_pm` 600, `haste_pm` 1250 | 1 | schließt Turbo aus |
| `sts_haste` Turbo | 10,0 s | — | `move_pm` 1200, `haste_pm` 750 | 1 | schließt Verlangsamt aus |
| `sts_guard` Gepanzert | 6,0 s | — | DEF/RES × 1,5 (bestehend) | 1 | |
| `sts_taunt` Blickfang | 4,0 s | — | Gegnerseitig: KI und Auto-Ziel der Party bevorzugen den Träger | 1 | nur Schaufensterpose |
| **neu** `sts_taunted` Provoziert | 4,0 s | — | `fixate` auf die Quelle | 1, `replace` | auf Gegnern |
| **neu** `sts_dazed` Überrumpelt | 3,0 s (Party 1,5 s) | — | `no_act`, `move_pm` 500 | 1, `ignore` | Bosse immun |
| **neu** `sts_regen` Erholung | 10,0 s | 2,0 s | +3 % Max-HP | 1 | Massen-Schlabbern |
| **neu** `sts_burn` Brennt | 6,0 s | 1,0 s | −1 % Max-HP (min 1) | 1, `refresh` | Element Feuer |
| **neu** `sts_admonished` Ermahnt | 12,0 s | — | `dmg_dealt_pm` 800 | 1 | Hausmeister |
| **neu** `sts_dizzy` Schwindelig | 3,0 s | — | `no_act`, `no_move`, `dmg_taken_pm` 1250 | 1 | Hausmeister |
| **neu** `sts_enrage` Feierabend! | bis Kampfende | — | `dmg_dealt_pm` 1500 je Stapel | 9, `refresh` | Enrage |

### 3.9 Schaden, Heilung, Krit, Varianz, Zufall

#### 3.9.1 Formel (GDD §3.7 unverändert pro Treffer)

Jeder Treffer nutzt **unverändert** `DamageCalc.compute` (A²/(A+D) × Kraft/100 × Varianz 900–1100 ‰ × Krit 1,5 bei physisch ×
Element (schwach 1,5 / resistent 0,5 / immun 0) × Gepanzert-Faktor × Gegner-Schadensfaktor `enemy_dmg_mult`, mindestens 1).
Echtzeit entsteht über die **Taktung** (Auto-Angriff 2,0–3,0 s, Fähigkeiten mit GCD/Abklingzeit), nicht über eine neue Formel.
Danach wendet `rt_damage.gd` die Echtzeit-Faktoren in ‰ an (Produkt, dann einmal `div_round`, Ergebnis ≥ 1 außer bei Immunität):

```
amount = div_round(base × Π(dmg_dealt_pm des Verursachers) × Π(dmg_taken_pm des Ziels) × dmg_pm(Gegner-Verursacher)
                   × combo_pm × mods_pm, 1000^n)
```

- `Kraft` = `rt.power` falls gesetzt, sonst `power` (R4 darf Echtzeit-Kräfte getrennt einstellen; nach der CTB-Entfernung wird
  `rt.power` in `power` gebacken).
- **Combo:** Treffen beide Party-Mitglieder dasselbe Ziel mit schadenden Fähigkeiten (keine Auto-Angriffe) innerhalb von
  `COMBO_WINDOW_TICKS = 30`, ist der zweite Treffer ein Combo: × `COMBO_PM (1100)` und Ereignis `COMBO` (höchstens eines je
  `COMBO_COOLDOWN_TICKS = 150`).
- **Krit:** Chance unverändert `clamp(0,05 + LCK × 0,005 + Boni, 0, 0,40)`, nur physischer Schaden (wie bisher).
- **Fester Schaden** (`damage_type: fixed`, z. B. Molotow) und **feste Heilung** (Werbepflaster, Burger, Geschenk
  `heal_party_flat`) werden mit `FIXED_SCALE_PM (4000)` skaliert (§3.9.4). Prozentwerte (z. B. Zug 35 % Max-HP) bleiben.
- **Overkill:** Todesstoß ≥ `OVERKILL_PM (500)` ‰ der Max-HP des Ziels → `KO.value = 1` (ShowRules unverändert, +3 Hype,
  Credits × 1,25 wie bisher). Grund: Mit Echtzeit-HP und kleineren Einzeltreffern wäre die CTB-Schwelle (Treffer ≥ Rest-HP +
  Anteil der Max-HP, `Balance.OVERKILL_*`) praktisch unerreichbar.

#### 3.9.2 Heilung

`DamageCalc.heal_amount` unverändert: `mag` (MAG × 1,5 + 10) × Kraft/100 × Varianz 950–1050 ‰, `pct`, `fixed` (skaliert). Heilung
wird **nicht** mit dem HP-Faktor skaliert: Sie wird in Echtzeit häufiger gewirkt (Zauber alle 1,5 s), begrenzt nur durch MP.
`dmg_taken_pm` wirkt nicht auf Heilung.

#### 3.9.3 Zufall

Jeder Wurf (Varianz, Krit, Status-Chance, Widerstand, Stunt-Erfolg, zufällige Ziele/Punkte, Beute) erzeugt seinen eigenen
Generator:

```gdscript
rng_n += 1
var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(setup.seed, "rt", rng_n))
```

`rng_n` ist Teil des Snapshots. Reihenfolge der Würfe = Verarbeitungsreihenfolge §3.3 → deterministisch. Beute bei `VICTORY`:
`SeedUtil.derive(setup.seed, "drops", 0)` wie bisher.

#### 3.9.4 HP-Skala und lesbare Zahlen

| Wert | Faktor (bis R5 zur Laufzeit, ab R5 in die Daten gebacken) |
|---|---|
| Party Max-HP (Basis + Wachstum) | × 4 (`PartyMember.hp_scale_pm = 4000`, angewendet in `Progression.total_stats`) |
| Reguläre Gegner Max-HP | × 4 (`EnemyDef.rt.hp_pm`, Standard 4000) |
| Bosse Max-HP | absolut (`EnemyDef.rt.hp`), Startwerte §6.6–6.7 |
| Feste Heilung/fester Schaden | × 4 (`FIXED_SCALE_PM`) |
| Schaden pro Treffer, `mag`-Heilung, Prozentwerte, MP | unverändert |

Rechenbeispiele (Stufe 1, Startausrüstung): Kai (STR 12 + Mopp 4 = 16) Wuchtschlag auf Kanalratte (DEF 5):
16²/21 × 1,6 = 19,5 → 18–21 (Krit 27–32); Kanalratte 96 HP → 5 Wuchtschläge oder 8 Auto-Treffer à ~12. Adelsflamme (MAG 17,
RES 3, Feuer schwach): 17²/20 × 1,1 × 1,5 = 23,8. Kanalratten-Biss auf Kai (DEF 12): 13²/25 = 6,8 → 2,6 % von Kais 256 HP.
Hausmeister-Besenhieb auf Kai Stufe 5 (DEF 18): 40²/58 × 1,1 = 30 → 7,6 % von 400 HP alle 2,8 s.

### 3.10 Ressource: MP für beide

**Entscheidung:** Beide Figuren nutzen **MP** („Energie“, eine blaue Leiste); keine Wut als zweite Ressource. Begründung:
(1) eine Leiste, eine Regel — sofort verständlich, auch beim Heldenwechsel; (2) alle bestehenden Systeme bleiben gültig
(KRAWUMM-Dose +20 MP, Elixier, Werbepause +15 %, Sponsor `mp_party_pct`, Stufen-Wachstum); (3) der Wut-Rhythmus entsteht trotzdem:
Kai lädt durch Treffen.

| Figur | Laden im Kampf | Außerhalb |
|---|---|---|
| Kai | +1 MP je gelandetem Auto-Angriff (Krit +1 zusätzlich), keine Zeit-Regeneration | §2.7 |
| Graf Mopsula | +1 MP alle 1,5 s (45 Ticks, ab `ct = 0`, auch beim Zaubern) | §2.7 |
| Gegner | MP werden im Echtzeitkampf **nicht** verwendet (Regel-Wartezeiten steuern das Tempo) | — |

Kosten werden bei **Wirkung** abgezogen (Sofort: beim Start; Zauber: bei Zauberende, nach Prüfung). Reicht MP bei Zauberende
nicht mehr (z. B. durch einen Gegenstand verbraucht), schlägt der Zauber fehl (`CAST_FAILED`, `mp`).

### 3.11 Tränke und Gegenstände im Kampf

- Befehl `combat_item` (Inventar der Party), GCD-frei, sofort (Wirkung nach 300 ms), Bewegung erlaubt.
- **Gemeinsame Gegenstand-Abklingzeit pro Einheit:** `ITEM_CD_TICKS = 600` (20 s) für alle Verbrauchsgüter.
- Die Leistentaste **Trank** wählt automatisch: der kleinste Heilgegenstand (Tag `heal`), dessen Heilung die fehlenden HP des
  Ziels deckt, sonst der größte; Ziel = aktuelles freundliches Ziel, sonst die gesteuerte Figur. Weitere Gegenstände über das
  Gegenstandsrad (§7).
- Gegenstand-Wirkungen kommen aus dem `use_skill` (skills.json `rt`, §4.5); `itm_smoke` → Flucht (§2.5); `itm_hype_megaphone` →
  nur Show (+25 Hype über `SkillDef.hype`, wie bisher).
- Die KI-Partner nutzen Gegenstände nur mit Schalter **Tränke** (§5.2).

### 3.12 Beschwörungen, entkommende Gegner, Kampfende

- Beschwörung (`summon` in Regeln/Phasen): höchstens `MAX_ENEMIES = 6` lebende Gegner; Ort `door` (Korridor-Ende der nächsten
  Tür zur Party-Mitte, Gleichstand N, E, S, W) oder `near` (Formation um den Beschwörer); `is_summon = true` (keine EXP/Beute),
  `pop_in_until = c + 15`, Bedrohung 1 auf der nächsten Party-Einheit. Ereignis `SUMMON` (bestehend).
- Entkommen (`special.kind == "escape"`): Einheit verlässt den Kampf (`ESCAPED`, bestehend), zählt für `VICTORY` nicht mehr.
- `BattleResult` wird wie bisher gefüllt (EXP, Credits, Overkill-Credits, Diebstahl/Erstattung, Beute, Boss-Belohnungen, Party-HP/
  -MP, `item_delta`, Kills, Bestiarium, Schwächen, Schaden, Krits, Schwächetreffer, Gegenstände, Party-K.O.) und ergänzt um
  `group_ids` (alle beteiligten Gruppen), `duration_ticks`, `interrupts`, `dodges`, `telegraph_hits`; `turns`/`party_turns` =
  Zahl der `ACTION_START` aller Einheiten bzw. der Party (Auto-Angriffe zählen nicht).

### 3.13 Ereignisstrom (Kampf-Log)

Die Sim liefert `ActionEvent`s (02_TECH §5.3). Wiederverwendet, damit ShowRules, Achievements und Darstellung möglichst viel
behalten: `BATTLE_START` (`value` = Vorteil, `target_ids` = alle Einheiten), `ACTION_START` (`command` = `BattleCommand.Kind`
SKILL/STUNT/ITEM, `skill_id`, `item_id`, `target_ids`, `text`), `COMBO`, `DAMAGE`, `HEAL`, `MP_CHANGE`, `STATUS_ADDED` (`value` =
Dauer in Ticks, `rt.stacks`), `STATUS_REMOVED`, `STATUS_BLOCKED`, `KO` (`command`: ATTACK für Auto-Angriffe, SKILL, STUNT, ITEM,
−1 für Status/Zonen/Telegraphen), `REVIVE`, `SUMMON`, `ESCAPED`, `CREDITS_STOLEN`, `CREDITS_GAINED`, `STUNT_RESULT`,
`FLEE_RESULT` (`success = true` bei Flucht), `ITEM_GAINED`, `SPONSOR_GIFT`, `PHASE_CHANGE` (`value` = Phase ab 1, `success` =
vorige Phase perfekt), `MOD_LINE`, `ANNOUNCE`, `BATTLE_END` (`value` = Ergebnis, `success` = letzte Bossphase perfekt).
Im Echtzeitkampf **nicht** benutzt: `TURN_START`, `TURN_END`, `CTB_ORDER`, `DEFEND`, `PSEUDO_REMOVED`.

Neue Felder an `ActionEvent` (nur serialisiert, wenn ≠ Standard): `tick: int = -1` (ct), `rt: Dictionary = {}` (Ganzzahlen).
Neue Typen werden **am Ende** des Enums angehängt (bestehende Werte bleiben stabil):

| Typ | Felder | Bedeutung / Verbraucher |
|---|---|---|
| `SWING` | `actor_id`, `target_id`, `skill_id` | Auto-Angriff beginnt (Animation); Treffer folgt als `DAMAGE` |
| `ACTION_END` | `actor_id`, `skill_id`/`item_id` | schließt eine Aktion (ShowRules: ersetzt `TURN_END` für Aktionsklammern) |
| `ACTION_REFUSED` | `actor_id`, `skill_id`/`item_id`, `text` = Grund | HUD-Rückmeldung („Nicht genug MP“) |
| `CAST_START` | `actor_id`, `skill_id`, `target_id`, `value` = Ticks, `success` = unterbrechbar, `rt.end` | Zauberleisten |
| `CAST_INTERRUPTED` | `actor_id` = Unterbrecher, `target_id` = Zaubernder, `skill_id` | Show +3 (Party als Täter) |
| `CAST_FAILED` | `actor_id`, `skill_id`, `text` (`moved`, `target`, `mp`, `stunned`, `dead`) | HUD, Animation |
| `TELEGRAPH_START` | `actor_id`, `skill_id`, `value` = Telegraph-Id, `rt` = `{shape, x, z, yaw, r, r2, half, start, impact}` | TelegraphLayer, Ton |
| `TELEGRAPH_IMPACT` | `actor_id`, `skill_id`, `value`, `target_ids` = getroffene Einheiten | Show (perfekte Phase), Effekte |
| `TELEGRAPH_DODGED` | `target_id`, `value`, `success` = knapp (≤ 9 Ticks vor Einschlag noch drin) | Show +2/+4 |
| `TELEGRAPH_CANCELLED` | `value` | TelegraphLayer |
| `ZONE_START` | `actor_id`, `skill_id`, `status_id`, `value` = Zonen-Id, `rt` = Geometrie + `end` | TelegraphLayer |
| `ZONE_END` | `value` | TelegraphLayer |
| `TARGET_CHANGED` | `actor_id`, `target_id` (`""` = keins) | HUD, Plaketten |
| `CONTROL_CHANGED` | `actor_id` = vorher, `target_id` = jetzt gesteuert | Szene (Heldenwechsel), M.O.D. |
| `POS_CORRECTED` | `target_id`, `rt.x`, `rt.z` | Szene setzt Figur |
| `FLEE_WARNING` | `actor_id`, `value` = Rest-Ticks | HUD-Countdown |
| `ENRAGE` | `actor_id`, `value` = Stapel | Show +5 (einmal), M.O.D. |
| `PRESET_CHANGED` | `actor_id`, `text` = Taktik, `rt.tog` | HUD, M.O.D. |
| `SECOND` | `value` = volle Kampfsekunden | ShowRules (Langeweile, Schleppen) |

Pro Tick ist die Ereignisreihenfolge die Verarbeitungsreihenfolge (§3.3); `beat` bleibt 0.

### 3.14 Determinismus-Regeln (Pflicht für `core/rt/`)

1. Keine Gleitkommazahlen in spielrelevanten Werten: in `core/rt/` sind `float`, `sqrt(`, `pow(`, Dezimal-Literale verboten,
   einzige Ausnahme `DetMath.isqrt` (eine Zeile mit `# det-ok: exact integer sqrt with correction`). Datenwerte mit
   Gleitkomma (bestehende `chance`, `element_mods`, `crit_bonus`, `stat_mult`) werden beim Laden einmal mit `FixedMath.pm`/`bp`
   umgerechnet (wie im CTB-Kern).
2. Bestehender Lint `test_m8_no_global_rng` gilt für `core/**` automatisch (kein globaler Zufall, keine Uhr, keine Autoloads, keine
   `sin/cos/atan2/pow/exp/lerp`); `core/rt/` braucht wie `core/live/` keine `det-ok`-Ausnahme außer der obigen. Neuer Test
   `test_r1_rt_int_only.gd` prüft Regel 1.
3. Keine Iteration über `Dictionary` ohne Sortierung der Schlüssel (Einfügereihenfolge ist zwar stabil — geprüft —, hängt aber
   vom Verlauf ab); Listen in fester Reihenfolge (§3.3).
4. Kein Zugriff auf `Time`, `OS`, Frame-Delta; die Zeit kommt nur über `step()`.
5. Alle Würfe über `SeedUtil.derive(seed, "rt", rng_n)` (§3.9.3).
6. Snapshots sind kanonisches JSON (02_TECH `CanonicalJson`; nur Ganzzahlen, Strings, Bools, Listen, sortierte Dictionaries).

### 3.15 Leistungsbudget der Sim

| Messgröße | Budget |
|---|---|
| `RtSim.step()` mit 2 Party, 6 Gegnern, 10 Telegraphen/Zonen | ≤ 0,25 ms Desktop, ≤ 1,0 ms Profil `low` |
| Harness: ein regulärer Kampf (≈ 900 Ticks) headless | ≤ 0,3 s |
| Nachholen pro Frame (Hänger) | höchstens 4 Ticks; danach wird Zeit verworfen (Zeitlupe, kein Spiralen) |

### 3.16 Konstanten `RtBalance` (Startwerte)

```gdscript
class_name RtBalance extends RefCounted
const TICKS_PER_SEC: int = 30
const GCD_TICKS: int = 45
const GCD_MIN_TICKS: int = 30
const CAST_MIN_TICKS: int = 15
const QUEUE_TICKS: int = 9
const IMPACT_TICKS: Dictionary = {"attack": 9, "cast": 0, "stunt": 24, "item": 9}
const INTERRUPT_LOCKOUT_TICKS: int = 60
const ITEM_CD_TICKS: int = 600
const FIRST_SWING_TICKS: int = 30
const POP_IN_TICKS: int = 15
const AI_SLOT_OFFSET_TICKS: int = 9          # enemy rule timers start offset by slot × 9 (desync)
const REACT_TICKS: Dictionary = {"attack": 18, "support": 12, "careful": 6}   # party AI telegraph reaction (§5.5)
const ESCAPE_MARGIN_CM: int = 60
const RANDOM_POINT_MIN_CM: int = 300         # anchor "random": min distance between points
const FLEE_TICKS: int = 60
const FLEE_WARN_TICKS: int = 15
const DR_THRESHOLD_CM: int = 15
const DR_VEL_THRESHOLD: int = 15             # mm per tick
const DR_YAW_THRESHOLD: int = 8
const HEARTBEAT_TICKS: int = 15
const FORCE_SAMPLE_CM: int = 2
const MOVE_TOLERANCE_CM: int = 40
const SPEED_TOLERANCE_PM: int = 1250
const PLAYER_RUN_CM_S: int = 550
const CELL_HALF_CM: int = 800
const ROOM_INNER_CM: int = 750
const WALK_R_CM: int = 480
const DOOR_HALF_CM: int = 160
const CORRIDOR_END_CM: int = 710
const MELEE_STOP_CM: int = 30
const UNREACHABLE_TICKS: int = 90
const THREAT_SWITCH_PM: int = 1100
const TAUNT_TOP_PM: int = 1100
const TAUNT_RADIUS_CM: int = 1000
const FIXATE_TICKS: int = 120
const HEAL_THREAT_PM: int = 500
const DEBUFF_THREAT: int = 10
const COMBO_WINDOW_TICKS: int = 30
const COMBO_COOLDOWN_TICKS: int = 150
const COMBO_PM: int = 1100
const OVERKILL_PM: int = 500
const CLOSE_DODGE_TICKS: int = 9
const MAX_PARTY: int = 4
const MAX_ENEMIES: int = 6
const MAX_TELEGRAPHS: int = 10               # beyond: the oldest zone ends early (ZONE_END)
const MAX_COMBAT_TICKS: int = 18000          # 10 min → FLED ("Sendezeit überzogen!")
const CHECKPOINT_TICKS: int = 300            # combat checkpoints in the run log (§10.2)
const HP_SCALE_PM: int = 4000
const FIXED_SCALE_PM: int = 4000
const ENEMY_HP_PM: int = 4000
const STUN_BOSS_PM: int = 500
const EASY_WARN_PM: int = 1250               # Vorabendprogramm: telegraph warn times × 1.25
const REVIVE_GUARD_MS: int = 3000
const REGEN_DELAY_TICKS: int = 90
const REGEN_PERIOD_TICKS: int = 90
const REGEN_HP_PM: int = 10
const REGEN_MP_PM: int = 20
```

---

## 4. Fähigkeiten

### 4.1 Aktionsleiste, Freischaltung, Varianten

| Slot | Inhalt | Taste PC / Gamepad (§7) |
|---|---|---|
| 1 | Hauptfähigkeit (oft drücken, keine Abklingzeit) | `1` / A |
| 2 | Schutz bzw. Heilung | `2` / X |
| 3 | Kontrolle (Kai: Unterbrecher) | `3` / Y |
| 4 | Fläche bzw. Unterbrecher | `4` / B |
| 5 | **SHOW** (Stunt; wird ab Stufe 9 bei Hype ≥ 85 zum **FINALE**) | `5` / RB |
| 6 | **Trank** (automatische Wahl, §3.11; Gegenstandsrad per Rechtsklick/Halten) | `6` / LB |

- **Die Leiste wächst mit dem Level:** Slots ohne freigeschaltete Fähigkeit werden nicht angezeigt (Stufe 1: Kai Slot 1 + 5 + 6,
  Mopsula Slot 1 + 2 + 5 + 6; ab Stufe 4 sind alle Slots belegt). Die Freischaltung steht in `party.json` → `rt.bar` (unabhängig
  von der CTB-Lernliste, §4.8), sodass CTB bis zur Entfernung unverändert bleibt.
- **Varianten:** Ab Stufe 4–7 erhalten Slots 2–4 je eine Alternative. Die Belegung wählt man außerhalb des Kampfes im
  Fähigkeiten-Menü (`PartyMember.rt_loadout`, Standard = Grundfähigkeit). Talentwahl, Spezies und Spezialisierung (parallel)
  dürfen weitere Varianten freischalten (§9.5).
- **Kontext-Variante:** Mopsulas Slot 2 wird auf einem K.O.-Ziel automatisch zu „Sabber der Wiederkehr“ (ab Stufe 7).
- **FINALE:** Die SHOW-Taste zeigt das FINALE, wenn Stufe ≥ 9 **und** Hype ≥ 85 (Show-Wert). Die Hype-Bedingung prüft der
  Client (HUD) und beim Nachspielen `Game.replay_log` (Fehler „finale below hype“); die Sim prüft nur die Stufe, weil der Hype
  außerhalb des Kerns entsteht (§10.6).

### 4.2 Kai (Nahkampf, Beschützer)

Auto-Angriff „Mopp-Schlag“ (`skl_attack_kai`): physisch 100, alle 2,0 s, Reichweite 250 cm, Treffer nach 0,3 s.
MP: Stufe 1 = 12 (+2 je Stufe), Laden +1 je Auto-Treffer (+1 bei Krit).

| Slot | Fähigkeit (`id`) | ab Stufe | MP | Abklingzeit | Zauber-/Wirkzeit | Reichweite | Ziel | Wirkung | Bedrohung | GCD | Show-Tag | Symbol-Idee |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Wuchtschlag (`skl_kai_heavy_swing`) | 1 | 3 | — | sofort, Treffer +0,3 s | 250 | Gegner | 160 physisch | × 2,0 | ja | flashy | Mopp mit Bewegungslinien |
| 2 | Hier spielt die Musik! (`skl_kai_taunt`) | 2 | 2 | 15 s | sofort | Radius 1000 um Kai | alle Gegner im Radius | `sts_taunted` 4 s (Fixierung auf Kai, Bedrohung Spitze +10 %), Kai `sts_guard` 6 s | Spott | nein | risky | Megafon mit Noten |
| 2 V | Erste Hilfe (Tierarzt-Edition) (`skl_kai_first_aid`) | 4 | 4 | 12 s | sofort | 800 | Verbündeter (Smart) | Heilung 30 % Max-HP, entfernt Gift + Brand | Heil-Bedrohung | ja | cute | Pflaster mit Pfotenabdruck |
| 3 | Leinen-Fallstrick (`skl_kai_leash_trip`) | 3 | 5 | 12 s | sofort, Treffer +0,3 s | 800 | Gegner | 70 physisch, **unterbricht**, `sts_slow` 4 s (90 %) | × 1,0 | nein | — | Hundeleine als Lasso |
| 3 V | Kabelpeitsche (`skl_kai_cable_whip`) | 7 | 8 | 18 s | sofort, Treffer +0,3 s | 600 | Gegner | 120 Schock, **unterbricht**, `sts_stun` 1,5 s (100 %; Boss 0,75 s, Widerstand gilt) | × 1,0 | nein | flashy | Kabel mit Funken |
| 4 | Rundumfeger (`skl_kai_sweep`) | 4 | 5 | 8 s | sofort, Treffer +0,4 s | Radius 350 um Kai | alle Gegner im Radius | 80 physisch | × 1,5 | ja | flashy | Mopp im Kreis |
| 4 V | Deo-Flammenwerfer (`skl_kai_deo_torch`) | 6 | 7 | 14 s | **Kanal** 2,0 s (4 × alle 0,5 s), Bewegung bricht | Kegel 500 cm / 60° zum Ziel | Gegner im Kegel | je Tick 40 Feuer, `sts_burn` 6 s | × 1,0 | ja | flashy, risky | Spraydose mit Flamme |
| 5 | **SHOW:** Bahnsteig-Suplex (`skl_stunt_kai_suplex`) | 1 | 0 | 20 s (geteilt) | Stunt, Treffer +0,8 s | 250 | Gegner | Erfolg (60 % + LCK × 1 %, max 85 %, Boss −15 %): 230 physisch + `sts_stun` 2 s; Fehlschlag: 10 % eigene Max-HP Schaden + Kai `sts_stun` 1,5 s | × 1,0 | ja | risky, flashy | Ringer-Silhouette mit Sternchen |
| 5 F | **FINALE:** Prime-Time-Finisher (`skl_kai_prime_finisher`) | 9 + Hype ≥ 85 | 12 | 20 s (geteilt) | Stunt, Treffer +0,8 s | 250 | Gegner | 260 physisch, Krit +20 %, `kill_hype` 10, kein Fehlschlag | × 1,0 | ja | finisher, flashy | Studiokamera mit Blitz |
| 6 | Trank | — | — | 20 s (Gegenstände) | sofort | — | Smart | §3.11 | — | nein | — | Flasche mit Pflaster |

### 4.3 Graf Mopsula (Magier, Heiler)

Auto-Angriff „Monokel-Funkeln“ (**neu** `skl_rt_auto_mopsula`): magisch 60, Element `none`, alle 2,4 s, Reichweite 1000 cm,
Wirkung beim Schwung (Lichtstrahl aus dem Monokel). MP: Stufe 1 = 30 (+4 je Stufe), Laden +1 alle 1,5 s.

| Slot | Fähigkeit (`id`) | ab Stufe | MP | Abklingzeit | Zauber-/Wirkzeit | Reichweite | Ziel | Wirkung | Bedrohung | GCD | Show-Tag | Symbol-Idee |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Adelsflamme (`skl_mop_noble_flame`) | 1 | 4 | — | Zauber 1,5 s, Bewegung bricht | 2000 | Gegner | 110 magisch Feuer | × 1,0 | ja | flashy | Flamme mit Krönchen |
| 2 | Heiliges Schlabbern (`skl_mop_holy_lick`) | 1 | 4 | — | Zauber 1,5 s, Bewegung bricht | 2000 | Verbündeter (Smart) | Heilung `mag` 100 | Heil-Bedrohung | ja | cute, gross | Zunge mit Glitzer |
| 2 K | Sabber der Wiederkehr (`skl_mop_revive`) | 7 (auf K.O.-Ziel) | 14 | 30 s | Zauber 3,0 s, Bewegung bricht | 2000 | K.O.-Verbündeter | Wiederbelebung 40 % + `sts_guard` 3 s | — | ja | gross | Sabbertropfen mit Heiligenschein |
| 2 V | Massen-Schlabbern (`skl_mop_mass_lick`) | 6 | 10 | 20 s | Zauber 2,0 s, Bewegung bricht | ganzes Set | alle Verbündeten | Heilung `mag` 60 + `sts_regen` 10 s, entfernt Gift | Heil-Bedrohung | ja | cute, gross | Zwei Zungen |
| 3 | Frostniesen (`skl_mop_frost_sneeze`) | 2 | 5 | 6 s | sofort | 1500 | Gegner | 105 magisch Eis, `sts_slow` 4 s (100 %) | × 1,0 | ja | gross | Mopsnase mit Eiskristall |
| 3 V | Königlicher Erlass (`skl_mop_royal_decree`) | 4 | 6 | 25 s | sofort | 2000 | Verbündeter (Smart: gesteuerte Figur, sonst Kai) | `sts_haste` 10 s | — | ja | — | Schriftrolle mit Siegel |
| 4 | Donnerbellen (`skl_mop_thunder_bark`) | 3 | 7 | 15 s | sofort | Radius 600 um Mopsula | alle Gegner im Radius | 75 magisch Schock, **unterbricht alle** unterbrechbaren Zauber im Radius | × 1,0 | nein | flashy | Bellender Mops mit Blitz |
| 5 | **SHOW:** Auftritt Seiner Durchlaucht (`skl_stunt_mop_entrance`) | 1 | 0 | 20 s (geteilt) | Zauber 1,0 s, Bewegung bricht | Radius 800 um Mopsula | alle Gegner im Radius | Erfolg (55 % + LCK × 1 %, max 85 %, Boss −15 %): 140 magisch Feuer; Fehlschlag: Mopsula `sts_stun` 2 s | × 1,0 | ja | risky, flashy, cute | Mops mit Umhang im Scheinwerfer |
| 5 F | **FINALE:** Gräfliches Inferno (`skl_mop_inferno`) | 9 + Hype ≥ 85 | 14 | 20 s (geteilt) | Zauber 2,0 s, Bewegung bricht | 2000, Radius 600 um das Ziel | Gegner im Radius | 130 magisch Feuer + `sts_burn` 6 s | × 1,0 | ja | flashy, finisher | Krone in Flammen |
| 6 | Trank | — | — | 20 s (Gegenstände) | sofort | — | Smart | §3.11 | — | nein | — | Flasche mit Pflaster |

Herkunft: Jede der 8 bisherigen Fähigkeiten pro Figur und jeder Stunt hat einen Platz (Kern, Variante, Kontext oder FINALE);
der Stunt ist die SHOW-Taste mit hohem Risiko und hohem Hype.

### 4.4 Smart-Zielwahl der Fähigkeiten

| Zielart (`target` in skills.json) | Echtzeit-Bedeutung |
|---|---|
| `single_enemy` | aktuelles feindliches Ziel; ohne Ziel: nächster Gegner im Bereich ±60° der Blickrichtung in Reichweite, sonst nächster in Reichweite (wird aktuelles Ziel, `TARGET_CHANGED`); keiner → `ACTION_REFUSED target` |
| `all_enemies` | alle Gegner in der Fläche `rt.aoe` (Radius 0 = ganzes Set) |
| `random_enemy` | zufälliger Gegner (Wurf §3.9.3) |
| `single_ally` | aktuelles freundliches Ziel; sonst Verbündeter mit dem kleinsten HP-Anteil (Gleichstand: gesteuerte Figur, dann Slot) |
| `all_allies` | alle lebenden Verbündeten in der Fläche (Radius 0 = ganzes Set) |
| `self` | Wirkende selbst |
| `single_ally_ko` | aktuelles freundliches K.O.-Ziel, sonst K.O.-Verbündeter mit dem kleinsten Slot |
| `none` | kein Ziel |

### 4.5 Verbrauchsgüter

Alle teilen die Gegenstand-Abklingzeit 20 s pro Einheit, sind GCD-frei, wirken nach 0,3 s, Bewegung erlaubt.

| Gegenstand | Echtzeit-Wirkung | Ziel | Änderung ggü. CTB |
|---|---|---|---|
| `itm_bandage` Werbepflaster | Heilung fest 45 × 4 = 180 | Verbündeter | Skala |
| `itm_brutzel_burger` Brutzel-Burger | Heilung fest 120 × 4 = 480 | Verbündeter | Skala |
| `itm_antidote` Gegengift-Gurgler | entfernt Gift und Brand | Verbündeter | + `sts_burn` |
| `itm_energy_krawumm` KRAWUMM-Dose | +20 MP | Verbündeter | — |
| `itm_smelling_salts` Riechsalz | Wiederbelebung 30 % + `sts_guard` 3 s | K.O.-Verbündeter | + Comeback |
| `itm_molotov` Grillanzünder-Cocktail | fest 60 × 4 = 240 Feuer, Radius 400 um das Ziel | Gegner | Fläche statt „alle“ |
| `itm_ice_spray` Kältespray | fest 90 × 4 = 360 Eis + `sts_slow` 4 s | Gegner | + Verlangsamt |
| `itm_smoke` Taschen-Nebelmaschine | sofortige Flucht (§2.5) | — | nicht im verschlossenen Set (`forbidden`) |
| `itm_hype_megaphone` Hype-Megafon | +25 Hype (Show) | — | — |
| `itm_elixir` Premium-Abo-Elixier | 100 % HP + 100 % MP | Verbündeter | — |

### 4.6 Datenschema: `skills.json` → `rt`

Optionaler Block je Skill. Pflicht für jeden Skill, der im Echtzeitkampf vorkommt (Party-Leiste, Auto-Angriffe, Gegner-`rt`,
`use_skill` kampftauglicher Gegenstände). Alle Zahlen sind Ganzzahlen.

| Feld | Typ | Standard | Bedeutung / Regel |
|---|---|---|---|
| `icon` | String | `""` | Symbol-Id der Aktionsleiste (`^[a-z0-9_]+$`; Pflicht für Leisten-Skills; Existenz prüft R3-Test) |
| `cast_ms` | int | 0 | Zauberzeit (0 = sofort); bei Telegraphen = Warnzeit (≥ 600) |
| `channel_ms` | int | 0 | Kanaldauer (0 = kein Kanal); Vielfaches von `period_ms` |
| `period_ms` | int | 0 | Kanal-/Zonen-Takt |
| `cooldown_ms` | int | 0 | Abklingzeit; SHOW/FINALE teilen sich die Abklingzeit über `"show"` (Stunt-Kategorie oder `finale` in der Leiste) |
| `gcd` | bool | `true` | löst GCD aus / braucht freien GCD |
| `range_cm` | int | 0 | Reichweite (0 = selbst bzw. Auto-Reichweite) |
| `aoe` | Dictionary | `{}` | `{"center": "self"\|"target", "radius_cm": int, "cone_deg": int, "max_targets": int}` |
| `moving_cancels` | bool | `true` bei `cast_ms`/`channel_ms` > 0 | Bewegung bricht (§3.6.5) |
| `interrupt` | bool | `false` | unterbricht unterbrechbare Zauber der getroffenen Ziele |
| `interruptible` | bool | `true` | dieser Zauber/Kanal ist unterbrechbar |
| `threat_pm` | int | 1000 | Bedrohungs-Faktor |
| `impact_ms` | int | nach `anim` (§3.6.7) | Wirkzeitpunkt sofortiger Aktionen |
| `power` | int | top-level `power` | Echtzeit-Kraft (überschreibt) |
| `mp` | int | top-level `mp_cost` | Echtzeit-Kosten (überschreibt) |
| `statuses` | Array | `[]` | `[{"id": String, "chance_pm": 1..1000, "ms": int (−1 = bis Kampfende), "to": "target"\|"self"\|"all_enemies"\|"all_allies"}]` (`target` = jede getroffene Einheit; `all_*` relativ zum Wirker, ganzes Set); ersetzt im Echtzeitkampf die CTB-`statuses` |
| `cleanse` | Array | top-level `cleanse` | zu entfernende Status-Ids |
| `telegraph` | Dictionary | `{}` | `{"shape": "circle"\|"cone"\|"ring"\|"line", "anchor": "self"\|"target_pos"\|"each_enemy"\|"random"\|"lane", "radius_cm", "inner_cm", "angle_deg", "length_cm", "width_cm", "count": 1..4, "lanes": [int, …]}` (§6.3) |
| `zone` | Dictionary | `{}` | `{"ms": int, "period_ms": int, "status": String, "skill": String}` (genau eins von `status`/`skill`) |
| `dash` | bool | `false` | Linien-Telegraph: Wirker springt beim Einschlag ans Linienende |
| `pct_maxhp` | int | 0 | fester Schaden in % der Max-HP (ersetzt die Formel; z. B. Zug 35) |
| `ignore_guard` | bool | `false` | `sts_guard` wirkt nicht |
| `kill_adds` | bool | `false` | trifft auch die eigene Seite und setzt getroffene Beschwörungen sofort K.O. (Zug) |
| `fail_ms` | int | 0 | Stunt: Dauer der Selbst-Betäubung bei Fehlschlag (überschreibt `fail_effect.status`-Dauer) |

### 4.7 Datenschema: `statuses.json` → `rt`

| Feld | Typ | Standard | Regel |
|---|---|---|---|
| `default_ms` | int | 3000 | −1 = bis Kampfende, sonst ≥ 100, `% 100` |
| `period_ms` | int | 0 | 0 oder ≥ 500, `% 100` |
| `tick_pct` | int | 0 | −100…100 (negativ = Schaden, positiv = Heilung) je Periode und Stapel |
| `tick_min` | int | 0 | 0…999, Mindestbetrag je Stapel |
| `max_stacks` | int | 1 | 1…9 |
| `stack_mode` | String | `"replace"` | `replace` \| `refresh` \| `ignore` |
| `move_pm`, `haste_pm`, `dmg_dealt_pm`, `dmg_taken_pm` | int | 1000 | 0…5000 |
| `boss_ms_pm` | int | 1000 | 0…1000 (Dauerfaktor auf Bossen) |
| `flags` | Array | `[]` | ⊆ `RT_STATUS_FLAGS` (`no_act`, `no_move`, `no_cast`, `fixate`, `interrupt_on_apply`, `hidden`); bestehende `STATUS_FLAGS` gelten weiter (`guard`) |

### 4.8 Datenschema: `party.json` → `rt` und `items.json` → `rt`

```json
"rt": {
  "radius_cm": 40, "move_cm_s": 540, "threat_pm": 1500,
  "auto_skill": "skl_attack_kai", "swing_ms": 2000, "reach_cm": 250,
  "mp_regen": {"mode": "hit", "amount": 1, "crit_bonus": 1},
  "keep_cm": {"attack": 0, "support": 0, "careful": 0}, "follow_cm": 600,
  "bar": [
    {"slot": 1, "skill": "skl_kai_heavy_swing", "level": 1},
    {"slot": 2, "skill": "skl_kai_taunt", "level": 2},
    {"slot": 2, "skill": "skl_kai_first_aid", "level": 4, "variant": true},
    {"slot": 3, "skill": "skl_kai_leash_trip", "level": 3},
    {"slot": 3, "skill": "skl_kai_cable_whip", "level": 7, "variant": true},
    {"slot": 4, "skill": "skl_kai_sweep", "level": 4},
    {"slot": 4, "skill": "skl_kai_deo_torch", "level": 6, "variant": true},
    {"slot": 5, "skill": "skl_stunt_kai_suplex", "level": 1},
    {"slot": 5, "skill": "skl_kai_prime_finisher", "level": 9, "finale": true}
  ],
  "context": [],
  "presets": {"attack": [], "support": [], "careful": []},
  "default_preset": "attack",
  "assist_preset": "attack"
}
```

Mopsula: `radius_cm` 30, `threat_pm` 1000, `auto_skill` `skl_rt_auto_mopsula`, `swing_ms` 2400, `reach_cm` 1000,
`mp_regen` `{"mode": "time", "amount": 1, "every_ms": 1500}`, `keep_cm` `{"attack": 700, "support": 1200, "careful": 1400}`
(bevorzugter Abstand zum Ziel je Taktik; 0 = Nahkampf), `follow_cm` 800, `bar` nach §4.3,
`context` `[{"slot": 2, "skill": "skl_mop_revive", "when": "target_ko", "level": 7}]`, `default_preset` `support`,
`assist_preset` `support`. Die Regel-Listen der Presets stehen in §5.4.

`items.json` → `rt` (optional): `{"wheel": int}` = Sortierung im Gegenstandsrad (0…99, Standard: Datenreihenfolge).
Kampftaugliche Gegenstände (`usable` `battle`/`both`) brauchen einen `use_skill` mit `rt`-Block.

### 4.9 Datenschema: `enemies.json` → `rt` und `floors.json` → `encounters[].rt`

```json
"rt": {
  "hp": 0, "hp_pm": 4000,
  "radius_cm": 30, "move_cm_s": 360, "stationary": false, "keep_cm": 0,
  "auto_skill": "skl_e_bite", "auto_ranged_skill": "", "swing_ms": 2400, "reach_cm": 220,
  "auto_target": "threat_top",
  "dmg_pm": 1000,
  "immune": [],
  "rules": [
    {"skill": "skl_e_gnaw_poison", "first_ms": 3000, "every_ms": 10000, "target": "threat_top"}
  ],
  "phases": [],
  "enrage": {}
}
```

- `hp` > 0 setzt die Echtzeit-Max-HP absolut (Pflicht für Bosse), sonst `stats.hp × hp_pm / 1000`.
- `auto_target` ∈ `RT_TARGETS` (Standard `threat_top`; Taubenschwarm `lowest_hp_pct_enemy` — die Tauben ignorieren Bedrohung).
- Regel (`RtRule`, §6.2): `{"skill", "target", "cond": {…}, "first_ms", "every_ms", "once": bool, "then": {"skill", "delay_ms"}}`.
- Phase: `{"hp_above_pm": int, "on_enter": [Op, …], "rules": [RtRule, …]}`; Ops (`RT_PHASE_OPS`): `say {"tag"}`,
  `status_self {"status", "ms"}`, `summon {"enemy", "count", "at": "door"|"near"}`, `fixed_damage_self {"pct_pm"}`,
  `set {"stationary": bool}`, `clear_zones {}`, `telegraph {"skill"}`.
- `enrage`: `{"at_ms": int, "every_ms": int, "status": "sts_enrage"}`.
- `floors.json` → `encounters[].rt` (optional): `{"enemies": [ids], "music": String}` überschreibt im Echtzeitkampf die
  Gegnerliste (Tutorial: `["enm_kanalratte_azubi", "enm_kanalratte"]`, §6.5).

### 4.10 Validator-Regeln (`DataValidator`, R4)

Neue Vokabulare (Konstanten in `DataValidator`, verbindlich):
`RT_TARGETS`, `RT_CONDITIONS` (§5.3), `RT_PHASE_OPS`, `TELEGRAPH_SHAPES` (`circle`, `cone`, `ring`, `line`), `TELEGRAPH_ANCHORS`
(`self`, `target_pos`, `each_enemy`, `random`, `lane`), `AOE_CENTERS` (`self`, `target`), `STATUS_TO` (`target`, `self`,
`all_enemies`, `all_allies`), `STACK_MODES`,
`RT_STATUS_FLAGS`, `RT_PRESETS` (`attack`, `support`, `careful`), `RT_TOGGLES` (`interrupt`, `show`, `potions`), `MP_REGEN_MODES`
(`hit`, `time`), `RT_ITEM_KINDS` (`heal`, `revive`, `mp`, `cure`), `SUMMON_AT` (`door`, `near`).

| Nr. | Regel |
|---|---|
| V1 | Jede Zahl in einem `rt`-Block ist ganzzahlig (JSON-Zahl ohne Nachkommaanteil). |
| V2 | Alle `*_ms`-Felder ≥ 0 und `% 100 == 0` (Ausnahme: −1 bei `default_ms`/`statuses[].ms`/`status_self.ms` = bis Kampfende). Alle `move_cm_s` `% 30 == 0`. |
| V3 | Wertebereiche: `cast_ms` ≤ 5000, `channel_ms` ≤ 5000 und `% period_ms == 0`, `cooldown_ms` ≤ 120000, `impact_ms` ≤ 1500, `range_cm` ≤ 3000, `aoe.radius_cm` ≤ 1600, `aoe.cone_deg` ≤ 180, `max_targets` ≤ 8, `threat_pm` ≤ 10000, `power` ≤ 500, `mp` ≤ 99, `pct_maxhp` ≤ 100. |
| V4 | Referenzen: `statuses[].id`, `cleanse[]`, `zone.status`, `immune[]`, `enrage.status`, `status_self.status` sind Status-Ids; `zone.skill`, `auto_skill`, `auto_ranged_skill`, Regel-`skill`, `then.skill`, `telegraph`-Op-`skill`, Leisten-/Kontext-Skills sind Skill-Ids mit `rt`-Block; `summon.enemy` ist eine Gegner-Id mit `rt`. |
| V5 | Telegraph: Form/Anker aus den Vokabularen; Geometrie vollständig (Kreis: `radius_cm`; Kegel: `radius_cm`, `angle_deg` 1…180; Ring: `radius_cm` > `inner_cm` ≥ 0; Linie: `length_cm`, `width_cm`); `count` 1…4; `lanes` nur bei `lane`; `cast_ms` ≥ 600; nur Skills mit `user` `enemy`/`any`. |
| V6 | Zone: `ms` 1000…30000, `period_ms` 500…5000, genau eins von `status`/`skill`. |
| V7 | Status-`rt`: Bereiche §4.7; `flags` ⊆ `RT_STATUS_FLAGS` ∪ `STATUS_FLAGS`. |
| V8 | Party-`rt`: alle Felder vorhanden; `bar` hat Slot 1 und Slot 5 mit `level` 1; jeder Slot 1…5 hat höchstens eine Grundfähigkeit (ohne `variant`/`finale`); `finale` nur in Slot 5; Skills haben `user` `party`; `presets` hat genau `attack`, `support`, `careful`; `default_preset`/`assist_preset` ∈ `RT_PRESETS`. |
| V9 | Regeln: `target` ∈ `RT_TARGETS`; `cond`-Schlüssel ∈ `RT_CONDITIONS` mit Werttypen nach §5.3; Party-Regeln referenzieren nur Skills ihrer Leiste/Kontexte oder `item` ∈ `RT_ITEM_KINDS`; Gegner-Regeln `every_ms` ≥ 1000. |
| V10 | Gegner-`rt`: Pflicht für jeden Gegner in einer Begegnung einer Etage mit `playable: true`; Bosse brauchen `hp` > 0 und `phases`; Phasen streng absteigend nach `hp_above_pm` (1…999), letzte Phase `hp_above_pm` 0; `swing_ms` 1000…5000 bei gesetztem `auto_skill`; `reach_cm` 100…600; `radius_cm` 20…150; `dmg_pm` 100…5000. |
| V11 | `encounters[].rt.enemies`: 1…4 Gegner-Ids mit `rt`. |
| V12 | Kampftaugliche Gegenstände haben einen `use_skill` mit `rt`. |

### 4.11 Migration der bestehenden Daten

| Bestehend (CTB) | Echtzeit | Ab R5 (CTB entfernt) |
|---|---|---|
| `skills[].rank` | ignoriert (Taktung über `rt`) | gelöscht |
| `skills[].statuses[].turns`, `chance` (Kommazahl) | `rt.statuses[].ms`, `chance_pm` (Tabellen §4.2/4.3, §6) | `rt.statuses` ersetzt `statuses` |
| `skills[].cooldown` (Stunt, Züge) | `rt.cooldown_ms` 20000 | gelöscht |
| `skills[].power`, `mp_cost` | gelten, solange `rt.power`/`rt.mp` fehlen | `rt`-Werte gebacken |
| `skills[].target` | Bedeutung nach §4.4 | bleibt |
| `skills[].fail_effect.delay_pct` | ignoriert | gelöscht |
| `statuses[].default_turns`, `tick_timing`, `tick_speed_mult`, Flag `delay_on_apply` | ignoriert | gelöscht |
| `enemies[].ai` (`weighted`/`phased`), `phases[].actions`, Gewichte | ignoriert; `rt.rules`/`rt.phases` | gelöscht |
| `enemies.pseudo_units` (Zug) | ignoriert; Zug = `skl_q_train` | gelöscht |
| `party[].learnset` | ignoriert; `rt.bar` | gelöscht (Fähigkeiten-Menü liest `rt.bar`) |
| `party[].base_stats.hp`, `growth.hp`; feste Heilungen/Schäden; `enemies[].stats.hp` | Laufzeit-Skala × 4 (§3.9.4) | × 4 in die Daten gebacken, Skala-Code entfernt |
| `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN` | ungenutzt | gelöscht |

Neue Einträge (R4): Skills `skl_rt_auto_mopsula`, `skl_e_throw`, `skl_e_azubi_hop`, `skl_q_train`, `skl_q_spit`, `skl_q_puddles`,
`skl_tw_rat_rain` (Twist, §9.5);
Status `sts_taunted`, `sts_dazed`, `sts_regen`, `sts_burn`, `sts_admonished`, `sts_dizzy`, `sts_enrage`; Gegner
`enm_kanalratte_azubi`; M.O.D.-Tags (§9.3).

---

## 5. Partner-KI

### 5.1 Steuerung, Heldenwahl, Autopilot

- `RtSetup.controlled_id` kommt aus der **Heldenwahl** (parallel entwickelt). Schnittstelle: `Game.controlled_member_id() ->
  String` (Standard `"kai"`, solange die Heldenwahl fehlt); `BattleBridge.make_rt_setup` bildet die Mitglieds-Id auf die
  Einheiten-Id (`p<battle_slot>`) ab. Die gesteuerte Einheit hat `driver = PLAYER` (Bewegung aus Proben, Fähigkeiten aus
  Befehlen), alle anderen Party-Einheiten `AI`.
- **Steuerung folgt dem Leben** (§2.6): K.O. der gesteuerten Einheit → die erste lebende Party-Einheit (Slot-Reihenfolge) wird
  `PLAYER`, die bisherige bleibt liegen; `CONTROL_CHANGED`. Ab da kommen Proben und Befehle für die neue Einheit. Die Szene
  wechselt Körper und Kamera über `ExplorationScene.control(member_id: String)` (Pflicht-Schnittstelle der Heldenwahl,
  zur Laufzeit aufrufbar; Ersatz bis dahin: Zuschauermodus).
- **Autopilot** (Taste `toggle_auto`, Befehl `autopilot`): die gesteuerte Einheit wird `AUTOPILOT` und von der Sim mit ihrer
  Taktik gespielt (Bewegung, Fähigkeiten, Ausweichen). Proben werden ignoriert; die Szene zeigt die Sim-Position (Körper folgt
  der Sim wie eine Puppe). Für Barrierefreiheit, Bots und Captures. Beim Abschalten steht der Körper genau an der Sim-Position;
  ab dem nächsten Tick gelten wieder Proben (normale Prüfung, §3.5.2).
- Das **FINALE** nutzt die KI nie („Das Finale gehört dem Publikum — und dir.“).

### 5.2 Taktiken (Presets) und Schalter

| Taktik (`preset`) | UI-Name | Ausweich-Reaktion | Abstand Mopsula | Heil-Schwelle (Mopsula) | Trank-Schwelle (eigene HP) | SHOW |
|---|---|---|---|---|---|---|
| `attack` | Angriff | 18 Ticks (0,6 s) | 700 cm | Verbündeter < 35 % | — | ja (Schalter) |
| `support` | Unterstützen | 12 Ticks (0,4 s) | 1200 cm | Verbündeter < 60 % | < 35 % | ja, sparsam |
| `careful` | Vorsichtig | 6 Ticks (0,2 s) | 1400 cm | Verbündeter < 75 % | < 50 % | nein |

| Schalter (`tog`) | Standard | Wirkung |
|---|---|---|
| `interrupt` Unterbrechen | an | Regeln mit `cond.toggle == "interrupt"` aktiv (Fallstrick, Kabelpeitsche, Donnerbellen auf Zaubernde) |
| `show` Show-Einlagen | an | SHOW-Regeln aktiv |
| `potions` Tränke | an | Gegenstands-Regeln aktiv (Party-Inventar!) |

Standard: Kai als Partner `attack`, Mopsula als Partner `support` (`party.json` `rt.default_preset`). Die Wahl wird je Mitglied
gespeichert (`PartyMember.rt_preset`, `rt_toggles`) und im Kampf mit dem Befehl `partner_preset` geändert (§7: Taste `G`,
Steuerkreuz rechts, Antippen des Taktik-Chips).

### 5.3 Regel-Engine `RtRules` (gemeinsam für Partner-KI, Autopilot, Assist und Gegner-KI)

Regel (`RtRule`, JSON in `party.json` → `rt.presets` bzw. `enemies.json` → `rt.rules`/`phases[].rules`):

```json
{"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle": "interrupt"},
 "first_ms": 0, "every_ms": 0, "once": false, "then": {}}
```

oder für Gegenstände (nur Party): `{"item": "heal"|"revive"|"mp"|"cure", "target": …, "cond": {…}}` — die Sim wählt den
Gegenstand wie die Trank-Taste (§3.11; `revive` → Riechsalz, `mp` → KRAWUMM-Dose, `cure` → Gegengift).

Auswertung in Schritt 7 (§3.3) für jede sim-gesteuerte Einheit, die handeln darf (lebt, kein `no_act`, kein laufender Zauber,
`pop_in_until ≤ c`):

1. Regeln der aktuellen Phase (Gegner) bzw. der Taktik (Party) in Listenreihenfolge.
2. Überspringen, wenn: Regel-Timer nicht bereit (`rule_ready[key] > c`; Schlüssel `"<phase>:<index>"` bzw.
   `"<preset>:<index>"`), `once` schon benutzt, eine Bedingung falsch, Schalter aus, Fähigkeit nicht nutzbar (`can_use`:
   Abklingzeit, GCD bei GCD-Fähigkeiten, MP, Sperre, kein gültiges Ziel).
3. Scheitert eine Regel **nur** an der Reichweite, setzt sie (falls noch keins gesetzt) das Bewegungsziel zum Regelziel; die
   Auswertung geht weiter (spätere Regeln dürfen aus der aktuellen Position feuern).
4. Die erste nutzbare Regel feuert: Fähigkeit starten; `rule_ready[key] = c + every_ticks`; `then` reiht die Folgefähigkeit für
   `c + delay` ein (ohne Bedingungen, nur Nutzbarkeit).
5. Feuert keine Regel: Auto-Angriff auf das Ziel (Party: `assist`; Gegner: `threat_top`), Bewegungsziel nach §3.5.3.

Erste Bereitschaft: `first_ms` + (Gegner) Slot × `AI_SLOT_OFFSET_TICKS`, damit gleiche Gegner nicht gleichzeitig zaubern.

**Bedingungen** (`RT_CONDITIONS`, alle in einer Regel müssen gelten; „Verbündete“/„Gegner“ relativ zur Einheit):

| Schlüssel | Wert | Wahr, wenn … |
|---|---|---|
| `self_hp_below_pm` / `self_hp_above_pm` | int | eigener HP-Anteil in ‰ < / > Wert |
| `ally_hp_below_pm` | int | ein lebender Verbündeter (einschließlich selbst) < Wert |
| `allies_below_pm` | `{"pm": int, "min": int}` | mindestens `min` lebende Verbündete < `pm` |
| `ally_ko` | bool | ein Verbündeter ist K.O. (bzw. keiner, bei `false`) |
| `target_hp_above_pm` / `target_hp_below_pm` | int | HP-Anteil des Regelziels |
| `target_no_status` / `self_no_status` | String | Status fehlt beim Regelziel / bei sich |
| `self_mp_min` | int | eigene MP ≥ Wert |
| `self_mp_above_pm` | int | eigener MP-Anteil > Wert |
| `enemies_in_radius` | `{"r_cm": int, "min": int}` | mindestens `min` lebende Gegner im Radius um die Einheit |
| `enemy_on_ally` | bool | ein Gegner, nicht auf die Einheit fixiert, greift einen anderen Verbündeten an |
| `caster_within_cm` | int | ein Gegner wirkt einen unterbrechbaren Zauber innerhalb des Radius |
| `target_casting` | bool | das Regelziel wirkt einen unterbrechbaren Zauber |
| `adds_below` | int | lebende Verbündete außer sich selbst < Wert (Gegner: Adds) |
| `phase` | int | aktuelle Bossphase (ab 1) == Wert |
| `after_ms` | int | Kampfzeit ≥ Wert |
| `boss_fight` | bool | Kampf ist ein Bosskampf |
| `toggle` | String | Partner-Schalter an (nur Party) |

**Ziele** (`RT_TARGETS`):

| Ziel | Bedeutung |
|---|---|
| `threat_top` | Gegner-KI: Bedrohungsziel (§3.7) |
| `current` | aktuelles Ziel der Einheit |
| `assist` | Party-KI: feindliches Ziel der gesteuerten Figur, sonst eigenes, sonst nächster Gegner (Gleichstand Nummer) |
| `self` | sich selbst (Flächen um sich) |
| `random_enemy` | zufälliger lebender Gegner (Wurf §3.9.3) |
| `nearest_enemy` / `farthest_enemy` | nach Abstand, Gleichstand kleinere Nummer |
| `lowest_hp_pct_enemy` / `lowest_hp_pct_ally` | kleinster HP-Anteil, Gleichstand Slot/Nummer (Verbündete: gesteuerte Figur zuerst) |
| `ko_ally` | K.O.-Verbündeter mit kleinstem Slot |
| `controlled` | die gesteuerte Figur |
| `caster` | Gegner mit unterbrechbarem Zauber in Reichweite der Fähigkeit, kürzeste Restzeit zuerst |
| `none` | ohne Ziel |

### 5.4 Prioritätslisten (Startwerte, `party.json` → `rt.presets`)

Kai:

```json
"attack": [
  {"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_cable_whip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_taunt", "target": "self", "cond": {"enemy_on_ally": true}},
  {"skill": "skl_stunt_kai_suplex", "target": "assist", "cond": {"toggle": "show", "target_hp_above_pm": 300}},
  {"skill": "skl_kai_sweep", "target": "self", "cond": {"enemies_in_radius": {"r_cm": 350, "min": 2}}},
  {"skill": "skl_kai_deo_torch", "target": "assist", "cond": {"enemies_in_radius": {"r_cm": 500, "min": 2}}},
  {"skill": "skl_kai_heavy_swing", "target": "assist", "cond": {"self_mp_min": 3}}
],
"support": [
  {"item": "heal", "target": "self", "cond": {"toggle": "potions", "self_hp_below_pm": 350}},
  {"item": "revive", "target": "ko_ally", "cond": {"toggle": "potions", "ally_ko": true}},
  {"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_cable_whip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_taunt", "target": "self", "cond": {"enemy_on_ally": true}},
  {"skill": "skl_kai_first_aid", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 500}},
  {"skill": "skl_kai_sweep", "target": "self", "cond": {"enemies_in_radius": {"r_cm": 350, "min": 3}}},
  {"skill": "skl_stunt_kai_suplex", "target": "assist", "cond": {"toggle": "show", "target_hp_above_pm": 500}},
  {"skill": "skl_kai_heavy_swing", "target": "assist", "cond": {"self_mp_min": 6}}
],
"careful": [
  {"item": "heal", "target": "self", "cond": {"toggle": "potions", "self_hp_below_pm": 500}},
  {"item": "revive", "target": "ko_ally", "cond": {"toggle": "potions", "ally_ko": true}},
  {"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_cable_whip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_taunt", "target": "self", "cond": {"enemy_on_ally": true, "ally_hp_below_pm": 500}},
  {"skill": "skl_kai_first_aid", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 600}},
  {"skill": "skl_kai_heavy_swing", "target": "assist", "cond": {"self_mp_min": 8}}
]
```

Graf Mopsula:

```json
"support": [
  {"skill": "skl_mop_revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"item": "revive", "target": "ko_ally", "cond": {"toggle": "potions", "ally_ko": true}},
  {"skill": "skl_mop_holy_lick", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 600}},
  {"skill": "skl_mop_mass_lick", "target": "self", "cond": {"allies_below_pm": {"pm": 700, "min": 2}}},
  {"item": "heal", "target": "self", "cond": {"toggle": "potions", "self_hp_below_pm": 350}},
  {"skill": "skl_mop_thunder_bark", "target": "self", "cond": {"toggle": "interrupt", "caster_within_cm": 600}},
  {"skill": "skl_mop_royal_decree", "target": "controlled", "cond": {"boss_fight": true, "target_no_status": "sts_haste"}},
  {"skill": "skl_stunt_mop_entrance", "target": "self", "cond": {"toggle": "show", "enemies_in_radius": {"r_cm": 800, "min": 3}}},
  {"skill": "skl_mop_frost_sneeze", "target": "assist"},
  {"skill": "skl_mop_noble_flame", "target": "assist", "cond": {"self_mp_above_pm": 500}}
],
"attack": [
  {"skill": "skl_mop_revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"skill": "skl_mop_holy_lick", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 350}},
  {"skill": "skl_mop_thunder_bark", "target": "self", "cond": {"toggle": "interrupt", "caster_within_cm": 600}},
  {"skill": "skl_stunt_mop_entrance", "target": "self", "cond": {"toggle": "show", "enemies_in_radius": {"r_cm": 800, "min": 2}}},
  {"skill": "skl_mop_frost_sneeze", "target": "assist"},
  {"skill": "skl_mop_noble_flame", "target": "assist", "cond": {"self_mp_min": 4}}
],
"careful": [
  {"skill": "skl_mop_revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"item": "revive", "target": "ko_ally", "cond": {"toggle": "potions", "ally_ko": true}},
  {"skill": "skl_mop_holy_lick", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 750}},
  {"item": "heal", "target": "self", "cond": {"toggle": "potions", "self_hp_below_pm": 500}},
  {"skill": "skl_mop_thunder_bark", "target": "self", "cond": {"toggle": "interrupt", "caster_within_cm": 600}},
  {"skill": "skl_mop_noble_flame", "target": "assist", "cond": {"self_mp_above_pm": 700}}
]
```

Regeln für nicht ausgerüstete Varianten sind einfach nicht nutzbar und werden übersprungen.

### 5.5 Bewegung und Ausweichen der KI

- **Ausweichen:** Beginnt ein gegnerischer Telegraph (`TELEGRAPH_START`), dessen Form die Einheit (mit `ESCAPE_MARGIN_CM = 60`
  aufgeblasen) enthält, setzt sie `react_at = start + REACT_TICKS[preset]`. Ab `react_at` ist ihr Bewegungsziel
  `RtGeo.escape_point(unit, telegraphs)`: Kandidaten = 16 Richtungen (`yaw = k × 16`) × Abstände 100/200/300/450/600 cm; der
  erste Kandidat (sortiert nach Abstand, dann nach Winkelnähe zur bevorzugten Richtung — Nahkampf: zum Ziel, Fernkampf: weg vom
  nächsten Gegner —, dann `k`), der begehbar ist und außerhalb aller aufgeblasenen gegnerischen Formen liegt, die in den nächsten
  60 Ticks einschlagen, und außerhalb aller Zonen. Kein Kandidat → stehen bleiben. Läuft ein eigener Zauber mit `moving_cancels`
  und endet er nicht vor dem Einschlag minus Laufzeit, bricht die KI ihn ab (`CAST_FAILED moved`).
- **Zonen** meidet die KI immer (Bewegungsziele in Zonen werden auf `escape_point` umgelenkt).
- **Abstand:** Mopsula hält `keep_cm[preset]` zum Ziel und bleibt ≤ `follow_cm` von der gesteuerten Figur, wenn kein Ziel
  besteht; Kai geht in Nahkampf. Verlässt die gesteuerte Figur das Set, folgt der Partner (Flucht, §2.5).
- Der Autopilot nutzt dieselben Regeln (Taktik der gesteuerten Figur, Reaktion nach Taktik).

### 5.6 Assist-Modus

`GameSettings.combat_assist` (Standard: an bei Touch, aus sonst). Das HUD fragt pro Frame `RtSim.suggest(controlled_id)`: erste
Regel der `assist_preset`-Liste, die für die gesteuerte Einheit jetzt nutzbar wäre (ohne Gegenstände, ohne Bewegung). Der
vorgeschlagene Slot pulsiert mit goldenem Ring (§8.2). Assist führt nichts aus; er ist reine Anzeige (kein Befehl, nicht im Log).

### 5.7 Bot-Profile (nur Balancing-Harness und Full-Run-Bot)

Der `RtBotPlayer` (`tests/tools/rt_bot_player.gd`, R4) spielt die gesteuerte Figur **über echte Befehle** (Proben, Fähigkeiten,
Ziele), damit der Harness den Live-Pfad prüft. Entscheidungen wie der Assist (Regeln `assist_preset`), plus Fehlerprofil mit
eigenem Zufallsstrom `SeedUtil.derive(seed, "bot", n)`:

| Profil | Reaktion auf Telegraphen | Verpasst Ausweichen | Unterbricht unterbrechbare Zauber | Trank unter | SHOW |
|---|---|---|---|---|---|
| `perfect` | 0 Ticks | 0 % | 100 % | 35 % | ja |
| `typical` | 9 Ticks | 15 % | 70 % | 35 % | ja |
| `sloppy` | 18 Ticks | 40 % | 30 % | 20 % | nein |

Der Full-Run-Bot (`scenes/boot/fullrun.gd`) nutzt im Echtzeitkampf den **Autopilot** (schnell, robust); die Bossverlust-Quoten
misst der Harness mit `typical` (§11).

---

## 6. Gegner-KI und Bosse

### 6.1 Ablauf eines Gegners

| Phase | Verhalten |
|---|---|
| Erkundung | Unverändert: IDLE/PATROL (1,8 m/s), ALERT 0,6 s, CHASE (`field_speed`), RETURN (3 m/s, ignoriert den Spieler 2 s); Sicht 10 m/110° (Tauben 14 m), Hören 4,0/1,5 m; Aufgabe nach 4 s ohne Sicht / 20 m Leine / 8 s Verfolgung. Neu: ALERT-Ende im Raum des Spielers startet den Kampf (§2.2), Kontakt bei 1,1 m entfällt. |
| Kampfstart | Puppe der Sim (keine Physik); Komparsen springen ins Bild; Bedrohung 1 auf dem Auslöser. |
| Kampf | Regeln (§5.3), Auto-Angriff auf `threat_top`, Bewegung im Set (§3.5.3). Verlässt das Set nie. |
| Flucht der Party | Rücksetzen: volle HP, Status weg, zurück zur Startposition, Erkundung `RETURN`. |
| Niederlage des Gegners | K.O.-Animation (`die`), Auflösen (`set_dissolve`), Gruppe gilt als besiegt, wenn alle Mitglieder fielen. |

### 6.2 Zielwahl, Fähigkeiten, Zauberleisten

- Ziel = `rt.auto_target` (Standard `threat_top`, §3.7), Fixierung durch Spott hat immer Vorrang. Regeln mit eigenem Ziel (z. B.
  `lowest_hp_pct_enemy`) gelten nur für diese Fähigkeit; das Auto-Ziel bleibt.
- Auto-Angriff: `auto_skill` mit `swing_ms`, `reach_cm`. Ist das Ziel außer Reichweite und `auto_ranged_skill` gesetzt, schwingt
  der Gegner stattdessen diesen Fernangriff (Reichweite aus dessen `range_cm`). `stationary` → bewegt sich nie.
- Jede Fähigkeit mit `cast_ms > 0` zeigt eine **Zauberleiste** mit Namen über dem Gegner, im Zielrahmen und (Boss) im Bossrahmen.
  `interruptible` = goldener Rand + Signalton „Ding“; nicht unterbrechbar = grauer Rand mit Schloss-Symbol.
- Unterbrechen: §3.6.8. Unterbrochene Regeln warten `every_ms` (der Gegner versucht es später erneut).

### 6.3 Telegraphen und Zonen

| Form | Parameter | Treffertest (Mittelpunkt der Einheit, „Fußpunkt-Regel“) |
|---|---|---|
| Kreis | `radius_cm` | Abstand ≤ r |
| Kegel | `radius_cm` (Länge), `angle_deg` (Öffnung) | Abstand ≤ r und dot(dir, d) ≥ cos(halber Winkel) × Abstand (alles ×1024) |
| Ring | `inner_cm`, `radius_cm` | inner ≤ Abstand ≤ r |
| Linie | `length_cm`, `width_cm` | 0 ≤ längs ≤ L und Betrag(quer) ≤ W/2 |

| Anker | Lage |
|---|---|
| `self` | Mitte/Spitze/Start = Wirker beim Zauberstart; Kegel und Linien zeigen zum Regelziel |
| `target_pos` | Mitte = Position des Regelziels beim Zauberstart (danach fest) |
| `each_enemy` | je gegnerischer Einheit (bis `count`) eine Form an ihrer Position beim Zauberstart |
| `random` | `count` gewürfelte Punkte im Kreis r ≤ 420 cm, Mindestabstand 300 cm (bis 8 Würfe je Punkt, sonst weglassen) |
| `lane` | Linie quer durch das Set entlang der x-Achse (Länge 1600, Breite `width_cm`), Versatz in z aus `lanes`, abwechselnd beginnend mit dem ersten Eintrag |

- **Warnzeit = Zauberzeit** (`cast_ms`; Vorabendprogramm × 1,25). Der Telegraph erscheint beim Zauberstart, schlägt beim
  Zauberende ein; Unterbrechen/K.O. des Wirkers entfernt ihn (`TELEGRAPH_CANCELLED`).
- **Ausweichfenster** = die ganze Warnzeit; geprüft wird nur im Einschlag-Tick. Nach jedem Tick (Schritt 9) merkt sich der
  Telegraph für jede Einheit der getroffenen Seite den letzten Tick „drin“. Wer irgendwann drin war und beim Einschlag draußen ist,
  ist **ausgewichen** (`TELEGRAPH_DODGED`); `success = true` (knapp), wenn er ≤ `CLOSE_DODGE_TICKS = 9` vor dem Einschlag noch drin
  war.
- Wirkung beim Einschlag: die Fähigkeit trifft jede Einheit der Zielseite in der Form (Formel §3.9 je Einheit), danach optional
  Zone (`zone`) und Sprung des Wirkers (`dash`).
- **Zonen** liegen weiter (`zone.ms`) und wenden alle `period_ms` ihren Status/Skill auf Einheiten der Zielseite in der Fläche an
  (erster Takt eine Periode nach dem Einschlag).
- Höchstens `MAX_TELEGRAPHS = 10` gleichzeitig (Telegraphen + Zonen); darüber endet die älteste Zone vorzeitig.

### 6.4 Adds, Enrage, perfekte Phase

- Adds kommen über Regeln/Phasen-Ops `summon` (§3.12), standardmäßig an der nächsten Tür („durch die Tür gestürmt“).
- **Enrage** (`rt.enrage`): bei `at_ms` `ENRAGE`-Ereignis, M.O.D. `boss_enrage:<enemy_id>`, `sts_enrage` 1 Stapel; danach alle
  `every_ms` ein weiterer (× 1,5 Schaden je Stapel). Weich: Ein guter Kampf endet vorher (§11).
- **Perfekte Phase:** Trifft während einer Bossphase kein Telegraph-Einschlag ein Party-Mitglied, trägt der nächste
  `PHASE_CHANGE` (bzw. `BATTLE_END`) `success = true` → Hype +8 (§9.1). Zonen-Takte zählen nicht als Treffer.

### 6.5 Etage 1: reguläre Gegner

HP = CTB-HP × 4 (`hp_pm` 4000). Regeln: `first_ms` / `every_ms`. Ziel ohne Angabe = `threat_top`. Telegraphen erben Schaden,
Element und Status ihres Skills (Zahlen aus skills.json, `rt.statuses` nach Spalte „Status“).

| Gegner (`id`) | HP | Radius / Tempo | Auto-Angriff | Signatur-Mechanik | Status | Witz |
|---|---|---|---|---|---|---|
| Kanalratte (`enm_kanalratte`) | 96 | 30 / 360 | Biss `skl_e_bite`, 2,4 s, 220 | Seuchennagen `skl_e_gnaw_poison`: sofort, 3 s / 10 s | Gift 50 %, 8 s | nagt am Sendekabel (Bild flackert kurz) |
| Kanalratte (Azubi) (**neu** `enm_kanalratte_azubi`, nur Tutorial) | 96 | 30 / 300 | Biss, 2,8 s | Azubi-Sprung `skl_e_azubi_hop` (**neu**, 60 phys.): Kreis r 200 am Ziel, Warnung 2,0 s, 6 s / 12 s | — | trägt ein „Lehrling“-Schild; Tutorial-Hinweis „Rote Fläche? Raus da!“ |
| Taubenschwarm (`enm_taubenschwarm`) | 80 | 40 / 450 | Picken `skl_e_peck`, 1,8 s, 220, Ziel `lowest_hp_pct_enemy` | Sturzflug-Bombardement `skl_e_dive_bomb`: Kreis r 250 am Regelziel `lowest_hp_pct_enemy` (`target_pos`), Warnung 1,2 s, 6 s / 12 s | — | „Gurr-Formation!“ |
| Pendler (`enm_pendler`) | 192 | 40 / 240 | Aktentaschen-Hieb `skl_e_briefcase`, 2,8 s, 220 | Verspätungswut `skl_e_delay_rage`: Kegel 400 cm / 90° vor sich (`self`), Warnung 1,8 s, **nicht** unterbrechbar, 7 s / 10 s | — | schaut beim Aufladen auf die Uhr: „Ich hab noch einen Anschluss!“ |
| Kanalschleim (`enm_kanalschleim`) | 160 | 45 / 180 | Klatscher `skl_e_slam`, 3,0 s, 220 | Giftspritzer `skl_e_toxic_splash`: Zauber 1,5 s unterbrechbar, 1200 cm, Ziel `random_enemy` mit `target_no_status` Gift, 4 s / 9 s | Gift 100 % | schluckt Schläge (physisch ×0,5, bestehend) |
| Rattenschamane (`enm_rattenschamane`) | 136 | 30 / 300, hält 800 | — (kein Nahkampf) | Funkenrute `skl_e_zap` als Hauptangriff: Zauber 1,5 s unterbrechbar, 1500 cm, 1 s / 3 s; Rattensegen `skl_e_rat_heal`: Zauber 2,0 s unterbrechbar, Ziel `lowest_hp_pct_ally`, `ally_hp_below_pm` 500, 5 s / 8 s | — | „Heiler zuerst!“ (M.O.D. beim ersten Segen) |
| Kabelsalat (`enm_kabelsalat`) | 184 | 45 / 270 | Kabelhieb `skl_e_lash`, 2,6 s, 250 | Kurzschluss `skl_e_short_circuit`: Kreis r 500 um sich (`self`), Warnung 2,0 s, nicht unterbrechbar, 8 s / 12 s | — | „Bitte nicht berühren“-Schild glüht |
| Kellerspinne (`enm_kellerspinne`) | 200 | 40 / 420 | Giftbiss `skl_e_venom_bite`, 2,0 s, 220 | Netzschuss `skl_e_web`: sofort, 1500 cm, `once`, 4 s, Ziel `farthest_enemy` | Biss: Gift 50 %; Netz: Verlangsamt 5 s | „Spinnt total“ |
| Sprühgeist (`enm_spruehgeist`) | 176 | 35 / 300, hält 900 | — | Farbflamme `skl_e_spray_flame`: Zauber 1,5 s unterbrechbar, 1500 cm, 1 s / 3,5 s; Lackdämpfe `skl_e_fumes`: Kreis r 300 am Ziel, Warnung 1,2 s, Zone 6 s (Gift alle 2 s), 6 s / 14 s | Zone: Gift-Stapel | hinterlässt Graffiti-Tags auf dem Boden |
| Rolltreppenkrabbe (`enm_rolltreppenkrabbe`) | 288 | 60 / 240 | Zwicken `skl_e_pinch`, 3,0 s, 250 | „Stufen fahren hoch“ `skl_e_brace` (selbst `sts_guard` 4 s), 5 s / 15 s, `then` nach 1,5 s Stufen-Stampfer `skl_e_step_crush`: Kreis r 300 um sich, Warnung 1,5 s | — | Durchsage „Bitte rechts stehen, links gehen“ |
| Rattengardist (Elite) (`enm_rattengardist`) | 312 | 45 / 300 | Hellebarde `skl_e_halberd`, 2,6 s, 300 | Schildwall `skl_e_shield_wall`: Zauber 2,0 s unterbrechbar, `once` bei 3 s und `once` bei `self_hp_below_pm` 500, alle Verbündeten `sts_guard` 8 s; Ausfall `skl_e_lunge`: Linie 800 × 150 zum `lowest_hp_pct_enemy` (`self`), Warnung 1,0 s, `dash`, 6 s / 11 s | — | „Für die Krone!“ |
| Fahrscheinfresser (selten) (`enm_fahrscheinfresser`) | 240 | 50 / 0 (`stationary`) | Entwerter-Biss `skl_e_ticket_cut`, 2,4 s, 250 | Erhöhtes Beförderungsentgelt `skl_e_fine`: Zauber 2,5 s unterbrechbar, `once` bei 2 s (stiehlt bis 40 Cr, Erstattung bei Sieg); Abfahrt! `skl_e_escape`: Zauber 3,0 s **unterbrechbar**, 25 s / 10 s → entkommt mit Beute | — | „Fahrschein, bitte!“; jede Unterbrechung der Abfahrt kauft 10 s |
| alle Nahkämpfer | | | | Unerreichbar-Regel `skl_e_throw` (§3.5.3) | — | „Er wirft mit Dosen!“ |

### 6.6 Boss: Der Hausmeister (`enm_boss_hausmeister`)

Stufe 6 (Zielstufe der Party 5), Echtzeit-HP **2 600** (Start), Radius 90 cm, Tempo 240 cm/s, Auto Besenhieb (`skl_b_broom`, 110)
alle 2,8 s, Reichweite 320. Schwäche Schock, Gift ×0,5, Betäubung/Verlangsamt 50 % Widerstand (bestehend), immun gegen
`sts_dazed`. Enrage „Feierabend ist Feierabend!“ bei 4:30, danach alle 30 s.

| Phase | HP | Beim Eintritt | Mechaniken (Zeiten ab Phasenbeginn: erste / Wiederholung) |
|---|---|---|---|
| P1 „Kehrwoche“ | > 60 % | Boss-Intro (§2.9) | **Hausordnung verlesen** (`skl_b_rules`): Zauber 3,0 s, **unterbrechbar**, 8 s / 25 s. Nicht unterbrochen → Hausmeister `sts_guard` 12 s **und** ganze Party `sts_admonished` 12 s („Ermahnt: −20 % Schaden. Das kommt in die Akte.“). **Schlüsselbund-Wurf** (`skl_b_keys`, 70): Linie 1400 × 150 vom Boss zu `random_enemy`, Warnung 1,2 s, 5 s / 12 s. |
| P2 „Hausordnung § 7“ | 60–25 % | M.O.D. `boss_phase:enm_boss_hausmeister:2`, 1 Kanalratte durch die Tür | **Putzmittelnebel** (`skl_b_cleaner_fog`, 60 Gift): je ein Kreis r 250 unter jedem Party-Mitglied (`each_enemy`, `count` 2), Warnung 1,0 s, danach Zone 12 s (Gift-Stapel alle 2 s), 4 s / 15 s. **„Untermieter!“** (`skl_b_call_tenant`): Zauber 2,0 s unterbrechbar, `adds_below` 2, 10 s / 20 s → 1 Kanalratte an der nächsten Tür. Schlüsselbund-Wurf weiter alle 12 s. |
| P3 „Feierabend!“ | < 25 % | M.O.D. `boss_phase:…:3`, `status_self sts_haste` bis Kampfende (rote Augen, 03_ART) | **Wischmopp-Wirbel** (`skl_b_mop_whirl`, 90): Kreis r 400 um sich, Warnung 1,8 s (dreht sich auf), 3 s / 14 s; danach **Schwindelig** (`sts_dizzy` 3 s auf sich: +25 % Schaden genommen, keine Aktionen) — das Belohnungsfenster („Jetzt draufhauen!“). Putzmittelnebel alle 20 s. |

Lernkurve: P1 lehrt Unterbrechen (Kai Stufe 3 / Mopsula Stufe 3), P2 lehrt Ausweichen und Adds, P3 lehrt „raus — rein“.

### 6.7 Boss: Die Rattenkönigin von Gleis 9 (`enm_boss_rattenkoenigin`)

Stufe 8 (Zielstufe 7), Echtzeit-HP **4 000** (Start), Radius 110 cm; P1/P2 `stationary` auf dem entgleisten Waggon in der
Raummitte (R4 setzt den Boss-Spot auf z = 0), Auto Zepterstoß (`skl_q_scepter`, 120) alle 3,0 s, Reichweite 350;
außer Reichweite Pestspucke (**neu** `skl_q_spit`, 80 Gift, 1500 cm) als `auto_ranged_skill`. Schwäche Eis, Feuer ×0,5, immun
gegen Gift und `sts_dazed`, 50 % Widerstand gegen Betäubung/Verlangsamt. Enrage „Betriebsschluss!“ bei 5:00, dann alle 30 s.

Bühnenbau (R4, Art-Kit): zwei Gleise entlang der x-Achse bei z = −400 („Gleis 9a“) und z = +400 („Gleis 9b“), je 4 m breit;
dazwischen der 4 m breite Bahnsteig-Mittelstreifen mit dem Waggon; Tunnelportale an den Wänden (dekorativ).

| Phase | HP | Beim Eintritt | Mechaniken |
|---|---|---|---|
| P1 „Hofstaat“ | > 65 % | Boss-Intro; 2 Kanalratten | **Pestbiss** (`skl_q_plague_bite`, 90 Gift): sofort, Nahkampf 350, 4 s / 8 s, Gift-Stapel 50 %. **Schwanzknoten lösen** (`skl_q_summon`): Zauber 2,5 s unterbrechbar, `adds_below` 3, 12 s / 25 s → 2 Kanalratten. |
| P2 „Zug fährt ein“ | 65–30 % | Durchsage-M.O.D. `boss_phase:…:2` („Auf Gleis 9 fährt ein: ein Zug. Bitte zurückbleiben.“) | **Zug** (**neu** `skl_q_train`): Linie entlang einer Gleisspur (`lane`, `lanes` [−400, 400], Breite 400), abwechselnd 9a/9b, Warnung **3,0 s** (Hupe, Scheinwerfer im Tunnel, Schienen glühen), 6 s / 20 s, nicht unterbrechbar; Treffer: Party 35 % Max-HP fest (`pct_maxhp` 35, `ignore_guard`), **Adds sofort K.O.** (`kill_adds`, „Zug-Kill“ +4 Hype). **Kreischen der Krone** (`skl_q_screech`, 80 Schock, ganzes Set, kein Telegraph): Zauber 2,0 s **unterbrechbar**, 10 s / 16 s. **Pestpfützen** (**neu** `skl_q_puddles`, 40 Gift): 3 Kreise r 200 (`random`), Warnung 1,5 s, Zone 10 s (Gift alle 2 s), 8 s / 18 s. Pestbiss weiter. |
| P3 „Endstation“ | < 30 % | M.O.D. `boss_phase:…:3`; der letzte Zug entgleist (Effekt), `fixed_damage_self` 50 ‰ („vom eigenen Zug erwischt“), `clear_zones`, `set stationary false` (Tempo 300 cm/s), `status_self sts_haste` bis Kampfende | **Kronen-Nova** (`skl_q_crown_nova`, 110 Schock): Ring 300–1200 cm um sich, Warnung 3,0 s, 5 s / 18 s — sicher ist es **nah an der Königin**. Pestbiss 8 s, Kreischen 20 s (unterbrechbar), Pestpfützen 20 s. |

### 6.8 Etage 2 (Entwurf, gebaut erst mit Etage 2)

Nicht Teil von R1–R5 (Etage 2 ist `playable: false`); die Sim muss dafür nur die allgemeinen Bausteine bieten, die schon
existieren, plus „Zähler“ (unten).

| Gegner | Echtzeit-Idee |
|---|---|
| Schaufensterpuppe (`enm_schaufensterpuppe`) | Bewegt sich und greift nur an, solange sie **niemandes Ziel** ist; „Schaufensterpose“ alle 9 s (`sts_guard` + `sts_taunt`: Blickfang). |
| Einkaufswagen-Rudel (`enm_einkaufswagen_rudel`) | Rammkette: jeder Wagen eine Linie 1000 × 150 zu seinem Ziel, Warnung 0,8 s, um Slot × 0,5 s versetzt, alle 9 s, `dash`. |
| Rabattschild-Golem (`enm_rabattschild`) | „Rabattstufe“: jeder Auto-Treffer +10 % Schaden (bis 5 Stapel); jede Unterbrechung/Betäubung setzt zurück. Preissturz: Kreis r 300 um sich, Warnung 1,5 s, alle 12 s. |
| **Boss „Der Ausverkauf“** (`enm_boss_ausverkauf`, neu, HP ~6 000) | Riesiges Preisschild auf einem Schaufensterpuppen-Körper. **Zähler** „Rabatt“: alle 5 s −10 % mehr (−10 % … −90 %); bei −90 % „BLACK FRIDAY“ — ganzes Set 60 % Max-HP fest, Zähler zurück. **Kassensturz:** Treffen die Party den Boss innerhalb von 6 s mit **3 verschiedenen** Fähigkeiten, springt der Zähler auf 0 und der Boss ist 2 s überrumpelt (Hype +6, Abwechslung belohnt). Adds „Wühltisch-Kundschaft“ alle 30 s; „Preisregen“ 4 Kreise r 200 (`random`), Warnung 1,2 s, alle 15 s. |

Neuer Baustein für Etage 2: `rt.counter` = `{"every_ms", "max", "at_max_skill", "reset": {"distinct_skills", "within_ms"},
"reset_status"}` mit Ereignis `COUNTER_CHANGED` (wird dann am Enum-Ende angehängt).

---

## 7. Steuerung und UX

### 7.1 PC (Tastatur + Maus)

| Aktion | Erkundung | Kampf |
|---|---|---|
| Bewegen | WASD / Pfeile (kamerarelativ, unverändert) | gleich; immer Lauftempo (Schleichen wirkungslos) |
| Kamera | Q/E, rechte Maustaste ziehen, Mausrad = Zoom (unverändert) | gleich |
| Ziel wählen | `Tab` = nächster Gegner im Raum (Zielrahmen erscheint), Linksklick auf Gegner | `Tab` / `Shift+Tab` (vor/zurück), Linksklick auf Gegner oder Plakette; Linksklick auf Party-Rahmen = freundliches Ziel; Linksklick auf freien Boden = Ziel löschen |
| Auto-Angriff | — | automatisch; `F`/`Leertaste`/`Enter` = „Angriff!“ (kein Ziel → nächster Gegner; Auto an); Klick auf das Schwert im Zielrahmen oder `V` = Auto an/aus |
| Fähigkeiten | `1`–`5` mit Ziel = Pull (§2.2) | `1`–`5` (Klick auf Slot ebenso) |
| Trank | — (Feldnutzung im Menü wie bisher) | `6`; Rechtsklick auf Slot 6 = Gegenstandsrad |
| Partner-Taktik | — | `G` (zyklisch Angriff → Unterstützen → Vorsichtig), Klick auf den Taktik-Chip öffnet Taktik + Schalter |
| Autopilot | — | `T` (`toggle_auto`) |
| Interagieren / Feldschlag | `F`/`Leertaste`/`Enter` (unverändert) | gesperrt |
| Karte | `M` (Tab entfällt) | gesperrt (Hinweis „Nicht während der Aufnahme!“) |
| Pause | `Esc`/`P` | `Esc`/`P` (offline: Sim tickt nicht; Live: §13) |

### 7.2 Gamepad

| Aktion | Erkundung | Kampf |
|---|---|---|
| Bewegen / Kamera | linker / rechter Stick | gleich |
| A | `action` (Interagieren; mit gewähltem Ziel in Reichweite von Slot 1: Pull mit Slot 1; sonst Feldschlag) | Slot 1 |
| X / Y / B | X, Y: Pull mit Slot 2/3 (wenn Ziel); B = `ui_cancel` in Menüs | Slot 2 / 3 / 4 |
| RB / LB | `tab_next`/`tab_prev` in Menüs | RB = SHOW (Slot 5), LB = Trank (Slot 6; 0,4 s halten = Gegenstandsrad, Auswahl mit rechtem Stick, loslassen = benutzen) |
| RT | nächstes Ziel | nächstes Ziel |
| LT | Schleichen (unverändert) | vorheriges Ziel |
| Steuerkreuz | oben = Autopilot | oben = Autopilot, rechts = Taktik wechseln, unten = Auto-Angriff an/aus |
| Start / Back | Pause / Karte | Pause / gesperrt |

Hinweis: Y war bisher `toggle_auto`; das wandert auf Steuerkreuz oben (Y ist im Kampf Slot 3). Kontexttrennung: Die Erkundung
wertet `bar_*` nur als Pull aus, der Kampf wertet `action`, `sneak`, `map` nicht aus.

### 7.3 Touch

Erkundung: unverändert (schwebender Stick links, Aktionsknopf, Karte, Pause). Ist außerhalb des Kampfes ein Gegner als Ziel
gewählt (Antippen), zeigt der Aktionsknopf das Symbol von Slot 1 und zieht damit (Pull).

Kampf (Referenz 1280 × 720, Zentren in px, verschieben sich mit den Safe-Area-Insets wie bisher, §10.4 02_TECH):

| Knopf | Zentrum | sichtbar / Trefferfläche | Inhalt |
|---|---|---|---|
| Slot 1 (Hauptfähigkeit) | (1147, 587) | 96 / 104 px | ersetzt im Kampf den Aktionsknopf an derselben Stelle (Daumen-Ruheposition) |
| Slot 2 | (1019, 634) | 72 / 88 | Bogen um Slot 1, Radius 136 px, 200° |
| Slot 3 | (1024, 530) | 72 / 88 | 155° |
| Slot 4 | (1100, 459) | 72 / 88 | 110° |
| SHOW (Slot 5) | (1206, 460) | 80 / 96 | 65°, Radius 140 px, goldener Rahmen |
| Trank (Slot 6) | (907, 650) | 64 / 88 | halten = Gegenstandsrad |
| Ziel wechseln | (1227, 360) | 64 / 88 | wie `target_next`; halten = vorheriges |
| Pause | (1227, 40) | 64 / 88 | unverändert |
| Karte | — | — | im Kampf ausgeblendet |

Geprüfte Abstände (Mittelpunkte ≥ Summe der halben Trefferflächen): Slot1–Slot2/3/4 = 136, Slot1–SHOW = 140 (≥ 100); Slot2–Slot3 =
104, Slot3–Slot4 = 104, Slot4–SHOW = 106, SHOW–Ziel = 102, Slot2–Trank = 113 (je ≥ 92/88). Alle Zentren liegen ≤ 250 px vom
Slot-1-Zentrum (Daumenradius). Gesten im Kampf: Antippen eines Gegners (Trefferfläche ≥ 107 px Durchmesser um den projizierten
Fußpunkt bzw. die Plakette, 03_ART §9) = Ziel; Antippen eines Party-Rahmens = freundliches Ziel; langes Drücken auf einen Slot =
Tooltip (Name, Kosten, Abklingzeit, Kurztext), kein Auslösen; Ziehen auf der freien rechten Fläche = Kamera; zwei Finger = Zoom.
Auto-Angriff ist immer automatisch.

### 7.4 Zielwahl

- **Tab-Reihenfolge** (Client, ergibt `target_change`): lebende Gegner im Set; zuerst die im Sichtkegel der Kamera (±60° um die
  Kamera-Vorwärtsrichtung) nach Abstand zur gesteuerten Figur, dann die übrigen nach Abstand; Start nach dem aktuellen Ziel.
  Außerhalb des Kampfes: Gegner-Anführer im aktuellen Raum mit Sichtlinie bis 25 m.
- **Klick/Tippen**: projizierte Fußpunkte und Plaketten; nächster Treffer gewinnt (`target_change`).
- **Automatisch (Sim-Regeln, kein Befehl nötig):** fällt das Ziel und ist `auto_retarget` an, wählt die Sim den Gegner, der die
  gesteuerte Figur angreift (sonst den nächsten; Gleichstand Nummer) → `TARGET_CHANGED`. Fähigkeiten ohne Ziel: §4.4.
- **Smart-Heilung:** Heilfähigkeiten ohne freundliches Ziel heilen den Verbündeten mit dem kleinsten HP-Anteil.
- `Shift+Tab` erfüllt ohne exakten Abgleich **auch** `target_next` (geprüft: `InputEvent.is_action(&"target_next", false)` ist
  für Shift+Tab `true`); `CombatInput` prüft daher mit `exact_match = true`.

### 7.5 Kamera im Kampf

- Gleiche Orbit-Kamera wie in der Erkundung (`camera_rig.gd`). Im Kampf: Zoom weich (0,5 s) auf 8,0 m (Boss 9,0 m), sofern der
  Spieler in diesem Kampf nicht selbst gezoomt hat; nach dem Kampf zurück. `LOOK_AHEAD` 2,5 m → 1,0 m. Automatisches
  Zurückdrehen hinter die Figur ist im Kampf **aus** (der Spieler behält die Kamera).
- Kein Ziel-Lock (die Kamera dreht nicht zum Ziel); Boss-Intro-Kranfahrt §2.9.
- Steuerungswechsel (§2.6): Kamera-Pivot gleitet in 0,4 s zur neuen Figur.
- Leichtes Kamerawackeln bei Einschlägen auf die Party (0,15 s, 0,08 m), abschaltbar.
- Wände: bestehende Regeln (Pitch anheben, Arm kürzen, Durchblick-Ausblenden) gelten unverändert.

### 7.6 Barrierefreiheit

| Einstellung (`GameSettings`) | Werte | Wirkung |
|---|---|---|
| `combat_speed_pm` „Spieltempo“ | 1000 / 850 / 700 | Echtzeit pro Tick (Darstellung + Eingabe), die Sim bleibt identisch. In Event-/Liga-Läufen fest 1000, außer die Regeln erlauben weniger (`rules.combat.speed_pm_min`). |
| `combat_assist` „Assist“ | an/aus (Touch: an) | Vorschlag-Ring auf der Leiste (§5.6) |
| `telegraph_contrast` „Kontrast-Telegraphen“ | normal / hoch | hoch: Füllung Weiß 35 % + schwarze Streifen + doppelt breiter Rand |
| `auto_attack_default` | an/aus | Auto-Angriff zu Kampfbeginn |
| `auto_retarget` | an/aus | automatische Zielwahl nach einem Kill |
| `floating_text_scale` | 100 / 125 / 150 % | Kampftext-Größe |
| `camera_shake` | an/aus | Kamerawackeln |
| `combat_mode` | `realtime` / `ctb` | nur bis R5; neue Spielstände (§12.1) |

Farbenblind-sicher: Telegraphen tragen ihre Bedeutung über **Form, Streifen und Rand**, nicht über Farbe; Zauberleisten
unterscheiden unterbrechbar/nicht unterbrechbar über Rand + Schloss-Symbol; Status-Symbole haben Formen (03_ART-Paletten bleiben
Zusatz). Untertitel für M.O.D. sind immer an. Autopilot und Vorabendprogramm (Warnzeiten × 1,25) ergänzen.

### 7.7 Input-Map-Änderungen (`project.godot`, R3)

| Aktion | Ereignisse | Status |
|---|---|---|
| `target_next` | Taste Tab; Joypad-Achse RT (5, +) | neu |
| `target_prev` | Taste Tab mit Shift; Joypad-Achse LT (4, +) | neu |
| `bar_1` … `bar_6` | Tasten 1…6 (`KEY_1` = 49 … `KEY_6` = 54); Joypad A (0), X (2), Y (3), B (1), RB (10), LB (9) | neu |
| `partner_preset` | Taste G (71); Joypad Steuerkreuz rechts (14) | neu |
| `auto_attack_toggle` | Taste V (86); Joypad Steuerkreuz unten (12) | neu |
| `map` | Taste M, Joypad Back (4) — **ohne** Tab | geändert |
| `toggle_auto` | Taste T, Joypad Steuerkreuz oben (11) — **ohne** Y | geändert |

Alle Konstanten geprüft (Anhang A). Deadzone der Achsen-Aktionen Standard 0,2 (geprüft). Bestehende Aktionen bleiben sonst
unverändert (02_TECH §2.2).

### 7.8 Neue Felder `GameSettings` (R3)

`combat_mode: StringName = &"ctb"` (gilt für neue Spielstände; R5 stellt den Standard auf `&"realtime"` um, §12.1),
`combat_speed_pm: int = 1000`, `combat_assist: int = -1`
(−1 = automatisch: an bei Touch), `telegraph_contrast: StringName = &"normal"`, `auto_attack_default: bool = true`,
`auto_retarget: bool = true`, `floating_text_scale: int = 100`, `camera_shake: bool = true`. Schlüssel in `settings.cfg` unter
`[combat]`. `battle_speed` und `auto_battle_default` bleiben bis zur CTB-Entfernung.

---

## 8. HUD (TV-Overlay)

### 8.1 Layout PC/Gamepad (Referenz 1280 × 720, innerhalb des Safe-Frames wie das bestehende HUD)

| Element | Anker / Lage | Größe | Inhalt |
|---|---|---|---|
| LIVE, Zuschauer, Follower | oben links (24, 24) | bestehend | ShowOverlay |
| Etagen-Timer | oben Mitte | bestehend | grau, Zusatz „Uhr steht“; Etagenname und Quest-Zeile im Kampf ausgeblendet |
| Hype-Meter | oben rechts | 320 × 14 | bestehend, Marken 70/85/100 |
| Party-Rahmen (gesteuert) | (24, 88) | 240 × 56 | Symbol 48, Name + Stufe, HP 176 × 14 mit Zahl, MP 176 × 8, Aggro-Zähler |
| Status-Reihe (gesteuert) | (24, 148) | bis 6 × 22 | Symbole 20 px, Restsekunden, Stapel |
| Party-Rahmen (Partner) | (24, 176) | 220 × 48 | wie oben kleiner, HP 156 × 12, MP 156 × 6 |
| Status-Reihe (Partner) | (24, 228) | bis 6 × 22 | |
| Taktik-Chip | (24, 254) | 168 × 28 | „Taktik: Unterstützen [G]“ |
| Boss-Rahmen (nur Boss) | oben Mitte, y 76 | 520 × 36 | Name, Phasen-Rauten, HP-Leiste + %, Enrage-Countdown in der letzten Minute; Zauberleiste 520 × 10 darunter |
| Zielrahmen | oben Mitte, y 76 (Bosskampf: y 136, nur wenn Ziel ≠ Boss) | 300 × 56 | Symbol 40, Name + Stufe, HP 240 × 12, Zauberleiste 240 × 8, Schwert (Auto an/aus); Status-Reihe darunter |
| M.O.D.-Untertitel | unten Mitte, Unterkante −130 | 600 × 56 | höchstens 2 Zeilen, 18 px |
| Spieler-Zauberleiste | unten Mitte, Unterkante −108 | 240 × 14 | nur beim Zaubern/Kanal |
| Aktionsleiste | unten Mitte, Unterkante −36 | 436 × 64 | 6 Slots à 64, Abstand 8, vor Slot 6 (Trank) zusätzlich 12 |
| Flucht-Countdown | Mitte, y 300 | 36 px Text | „Zurück ans Set! 2… 1…“ |
| Sponsor-Bauchbinde | unten links | im Kampf 380 × 64 | sonst 480 (überdeckt die Leiste nicht) |
| Chat-Ticker | ganz unten, 22 px | bestehend | |
| Minimap, Erkundungs-Hinweise, Mini-Party | — | ausgeblendet | |

Touch: gleiche Oberkante; Aktionsleiste entfällt (Daumen-Gruppe §7.3), Spieler-Zauberleiste unten Mitte bei x = 590, Unterkante
−100; M.O.D.-Untertitel 520 × 56 zwischen x 330 und 850, Unterkante −36, `mouse_filter = IGNORE` (der Stick-Bereich bleibt
bedienbar).

### 8.2 Aktionsleiste

| Zustand | Darstellung |
|---|---|
| bereit | dunkler Slot (Panel-Farbe), Symbol 44 px, Taste oben links (12 px, `InputGlyph`) |
| Abklingzeit | dunkle Radialfläche im Uhrzeigersinn ab 12 Uhr, Restsekunden mittig (20 px, ab 1 s ganzzahlig) |
| GCD | dünner weißer Außenring (Radius 0,86–1,0) als Sweep |
| zu wenig MP | Symbol entsättigt + Blau-Tönung (`MANA` #60A5FA, 50 %), MP-Kosten klein unten links |
| außer Reichweite | Rot-Tönung (`DANGER` #FF4D4D, 60 %) |
| kein gültiges Ziel | Symbol 40 % gedimmt |
| gepuffert (Queue) | goldener Rand 3 px (`HYPE_GOLD` #FFC93C) |
| wieder bereit | Weißblitz 0,15 s |
| Assist-Vorschlag | pulsierender goldener Ring (1,2 Hz) |
| SHOW | goldener Rahmen, bereit = langsamer Schimmer; FINALE = Rahmen Magenta (#FF2E88) ↔ Gold animiert + Schriftzug „FINALE“ |
| Trank | Anzahl unten rechts, Gegenstand-Abklingzeit als Sweep |
| abgelehnt | Rütteln 0,2 s + Kurztext über der Leiste („Nicht genug MP“, „Zu weit weg“, „Abklingzeit“, „Kein Ziel“, „Gesperrt“) |

Zustände liest das HUD jedes Frame aus `RtSim.can_use`, `cooldown_left`, `gcd_left`, `RtUnit.queued` und `suggest` (keine
Ereignis-Buchhaltung im HUD). Ladungen (Feld `charges`) sind reserviert, Anzeige unten rechts.

**Umsetzung (gemessen, geprüft):** Slot-Rahmen und Symbole als **ein** `RenderingServer.canvas_item_add_triangle_array`
(1 Draw Call für alle Slots; per `draw_colored_polygon` wären es 6, per `TextureProgressBar` radial 6); Sweeps als 6
`ColorRect` mit **einem gemeinsamen** `ShaderMaterial` (`art/shaders/ui_cooldown_sweep.gdshader`) und Instanz-Uniforms
`cd_left`, `gcd_left` — 1 Draw Call für alle 6, in Compatibility und Mobile; Beschriftungen als `Label` **ohne** Outline auf
dunklem Grund (6 Sweeps + 12 Labels = 2 Draw Calls; mit Outline 4 px kostet jedes Label ≈ 2 Draw Calls). Shader (geprüft in
beiden Renderern: bei `cd_left` 0,5 ist die linke Slot-Hälfte abgedunkelt, die rechte unverändert, GCD-Ring weiß, Ruhezustand
transparent; Hintergrund + 6 Instanzen = 2 Draw Calls):

```glsl
shader_type canvas_item;
instance uniform float cd_left = 0.0;    // 0..1 remaining cooldown (clockwise from 12 o'clock)
instance uniform float gcd_left = 0.0;   // 0..1 remaining GCD (thin outer ring)
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.x, -p.y);
	float t = (ang < 0.0 ? ang + 6.2831853 : ang) / 6.2831853;
	float dark = step(1.0 - cd_left, t) * step(0.0001, cd_left);
	float r = length(p);
	float ring = step(0.86, r) * step(r, 1.0) * step(1.0 - gcd_left, t) * step(0.0001, gcd_left);
	COLOR = vec4(mix(vec3(0.05, 0.03, 0.08), vec3(1.0), ring), max(dark * 0.65, ring * 0.8));
}
```

### 8.3 Zauberleisten

| Ort | Größe | Inhalt |
|---|---|---|
| Spieler | 240 × 14 | Füllung `MANA`, Name links, Restzeit rechts; Bewegung bricht → kurzes Rot + „Abgebrochen“ |
| Plakette | 64 × 4 | nur während des Zaubers |
| Zielrahmen | 240 × 8 + Name 12 px | |
| Bossrahmen | 520 × 10 + Name 14 px | |

Unterbrechbar: goldener Rand + Ton „Ding“ beim Start; nicht unterbrechbar: grauer Rand + Schloss-Symbol. Unterbrochen: Leiste
blitzt Gold, Kampftext „UNTERBROCHEN!“ über dem Gegner, Ton „Plattennadel-Kratzer“.

### 8.4 Einheitenrahmen und Status-Symbole

- Party: HP-Leiste in Partyfarbe (`ui_party` #4AA8FF) mit nachlaufendem roten Schadensstück (0,4 s) und grünem Heil-Aufblitzen;
  MP in `MANA`; K.O. = grau + „K.O.“; **Aggro-Zähler** (rotes Abzeichen „×2“ = so viele Gegner greifen dieses Mitglied an).
- Ziel: HP in Gegnerfarbe (`ui_enemy` #E8455A), Elite/Boss-Marke, Schwert-Schalter für Auto-Angriff.
- Boss: Phasen-Rauten (gefüllt = erreicht), HP-Prozent, in der letzten Minute vor dem Enrage „Feierabend in 0:42“.
- Status-Symbole: 20 px (Ziel 18 px), Buffs vor Debuffs, nach Restzeit; Restsekunden als Ganzzahl darunter, Stapel unten rechts;
  mehr als 6 → „+n“. Symbole kommen aus `StatusDef.icon` (icon_mesh), Farben aus 03_ART (Gift #7CC242, Betäubt #F5D90A,
  Verlangsamt #5B8DEF, Turbo #FF7A1A, Gepanzert #9AA7B8, Provoziert #E8455A); neue Status bekommen in R3 Symbole.
- Keine Live-Porträts (SubViewport) im Kampf-HUD — statische Symbole sparen 3D-Draw-Calls.

### 8.5 Namensplaketten

2D, projiziert über `Camera3D.unproject_position` (geprüft) auf Kopfhöhe + 0,4 m, für alle Gegner im Kampf: HP-Leiste 64 × 6,
Zauberleiste 64 × 4 (nur beim Zaubern), bis zu 3 Statuspunkte in Statusfarbe, links ein **Zielpunkt** in der Farbe des
angegriffenen Party-Mitglieds (`party.json` `portrait_color`). Name nur für das aktuelle Ziel, Elite und Boss. Ausgeblendet hinter
der Kamera/außerhalb des Bildes, ab 20 m ausgeblendet. Umsetzung (geprüft): alle Leisten/Punkte in **einem** Dreiecks-Array
(1 Draw Call) + höchstens 8 Labels ohne Outline (≈ 1 Draw Call): 8 Plaketten = 2 Draw Calls (als `PanelContainer` +
`ProgressBar` gemessen: 24). **Keine `Label3D`-Plaketten** (geprüft: je Billboard-`Label3D` mit Outline 2 Draw Calls in
Compatibility, 1 in Mobile).

### 8.6 Kampftext

`Vfx.damage_number` (2D-Zwilling auf CanvasLayer 4, bestehend) mit Echtzeit-Stilen (R3 ergänzt in `art/kit/vfx.gd`):
`rt_dealt` (weiß; Krit gelb 130 % mit „!“), `rt_taken` (rot), `rt_heal` (grün), `rt_partner` (75 %, Partner-Auto-Angriffe),
`rt_word` (Wörter: „UNTERBROCHEN!“ Gold 26 px, „AUSGEWICHEN“ Cyan, „KNAPP!“, „IMMUN“, „WIDERSTAND“, „SCHWACH!“). Höchstens 10
gleichzeitig (älteste fällt weg), Lebensdauer 0,6 s, Größe × `floating_text_scale`. Nur ASCII + deutsche Buchstaben (03_ART F8:
keine ★ ↑ → usw.).

### 8.7 Telegraph-Darstellung

**Engine-Befund (geprüft):** `Decal` wird im Renderer **Compatibility nicht** gezeichnet (Mitte der Decal-Fläche = reine
Bodenfarbe #969696), in Mobile schon. Telegraphen sind deshalb **flache Quads mit Shader**: `MeshInstance3D` + `QuadMesh`,
flach auf y = 0,02 m, ein gemeinsames `ShaderMaterial` (`art/shaders/rt_telegraph.gdshader`) mit zwei Instanz-Uniforms —
in beiden Renderern sichtbar und korrekt maskiert (geprüft: gefüllter Bereich, ungefüllter Ring, Außenbereich unterscheidbar);
Quad + Boden = 2 Draw Calls in der Messung.

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// x = shape (0 circle, 1 cone, 2 ring, 3 line), y = fill progress 0..1, z = inner ratio (ring), w = cos(half angle) (cone)
instance uniform vec4 tg_params = vec4(0.0, 0.0, 0.0, -1.0);
instance uniform vec4 tg_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = tg_params.x;
	float prog = clamp(tg_params.y, 0.0, 1.0);
	float r = length(p);
	float inside = 0.0; float edge = 0.0; float fill = 0.0;
	if (shape < 0.5) {                      // circle
		inside = step(r, 1.0);
		edge = inside * smoothstep(0.90, 0.97, r);
		fill = inside * step(r, prog);
	} else if (shape < 1.5) {               // cone, apex at the quad centre, forward = -V
		vec2 d = normalize(p + vec2(0.0, 1e-5));
		float c = dot(d, vec2(0.0, -1.0));
		inside = step(r, 1.0) * step(tg_params.w, c);
		edge = inside * max(smoothstep(0.90, 0.97, r), 1.0 - smoothstep(0.0, 0.04, c - tg_params.w));
		fill = inside * step(r, prog);
	} else if (shape < 2.5) {               // ring
		inside = step(r, 1.0) * step(tg_params.z, r);
		edge = inside * max(smoothstep(0.90, 0.97, r), 1.0 - smoothstep(tg_params.z, tg_params.z + 0.04, r));
		fill = inside * step(r, tg_params.z + (1.0 - tg_params.z) * prog);
	} else {                                // line: whole quad, fills along -V
		inside = 1.0;
		edge = max(1.0 - smoothstep(0.0, 0.06, 1.0 - abs(p.x)), 1.0 - smoothstep(0.0, 0.03, 1.0 - abs(p.y)));
		fill = step(1.0 - UV.y, prog);
	}
	float stripes = step(0.5, fract((p.x + p.y) * 4.0 - TIME * 0.6));
	float a = inside * (0.18 + 0.10 * stripes) + fill * 0.30 + edge * 0.85;
	ALBEDO = mix(tg_color.rgb, vec3(1.0), edge * 0.5);
	ALPHA = clamp(a, 0.0, 0.95) * tg_color.a;
}
```

- Quad-Größen: Kreis/Ring 2r × 2r um die Mitte; Kegel 2r × 2r um die Spitze (Shader maskiert); Linie W × L, Pivot am Start.
  `tg_params.y` = (ct − start) / (impact − start) (Füllung wächst bis zum Einschlag), Rand pulsiert in den letzten 0,3 s,
  Einschlag = Weißblitz 0,15 s, danach Quad zurück in den Pool.
- Farben: gegnerische Telegraphen `DANGER` #FF4D4D mit weißem Rand und wandernden Streifen; Zonen in Elementfarbe (Gift #7CC242,
  Feuer #FF7A1A) mit α 0,35 und langsameren Streifen, letzte Sekunde ausblenden; Kontrastmodus §7.6. Freundliche Bodenmarken
  (nur Darstellung, z. B. Inferno-Zielkreis) `C_ACCENT_2` #22D3EE.
- Pool von 10 Quads (`MAX_TELEGRAPHS`), ein Material → +1 Material im 3D-Budget (Messwert bisher 21–23 von 24).
- Tiefentest bleibt an (Requisiten dürfen Teile verdecken; Requisiten stehen nur am Rand, §3.5.4).

### 8.8 ShowOverlay, M.O.D.-Untertitel, Banner

- `Events.overlay_mode_requested(&"combat")` (neuer Modus): wie `&"explore"`, aber Minimap-Freiraum entfällt, Sponsor-Bauchbinde
  380 px breit und 1,5 s im Kampf.
- ModDialog im Kampf als **Untertitel**: neues Signal `Events.dialog_layout_requested(mode: StringName, layout: Dictionary)` mit
  `{"bottom": float, "width": float, "max_lines": int, "blocking": bool, "mouse_filter_ignore": bool}`; im Kampf
  `{"bottom": 130, "width": 600, "max_lines": 2, "blocking": false, "mouse_filter_ignore": true}` (Touch: 36/520). Blockierende
  Zeilen werden im Kampf nicht blockierend angezeigt (Ausnahme Boss-Intro, §2.9). Höchstens eine Zeile je 6 s (§9.3).
- Banner (Kampfbeginn „KAMPF!“, „Erstschlag!“, „Hinterhalt!“, Phasenwechsel, Steuerungswechsel, Enrage): Bauchbinde oben Mitte
  unter dem Ziel-/Bossrahmen, 1,2 s, nicht blockierend.

### 8.9 Ergebnis-Anzeigen

- Regulärer Sieg: Bauchbinde „Applaus!“ unten links (380 × 64), 3,0 s: „+36 EXP · +12 Cr · Werbepflaster“; Stufenaufstieg als
  zweite Bauchbinde. Nicht blockierend; Erkundung läuft sofort weiter.
- Boss-Sieg: Abspann-Panel (bestehendes Ergebnisbild als Overlay auf Layer 60, Baum pausiert) mit EXP-Leisten und Boss-Beute.
- Flucht: Bauchbinde „Taktischer Rückzug“ (−Hype sichtbar im Meter).
- Niederlage: bestehender Sendeschluss.

### 8.10 Leistungsbudgets im Kampf (PERFORMANCE.md, 02_TECH §12.1)

| Messgröße | Budget Kampf | Bisher gemessen | Echtzeit-Anteil (Plan) |
|---|---|---|---|
| 3D-Draw-Calls | ≤ 150 | Erkundung ≤ 112, CTB-Kampf ≤ 130 | Raum wie Erkundung + ≤ 6 Gegner-Rigs + 2 Party + ≤ 10 Telegraph-Quads |
| UI-Draw-Calls | ≤ 180 | CTB-Kampf 122–167 | ShowOverlay ≈ 45, Leiste ≈ 4, Rahmen ≈ 10, Plaketten 2, Kampftext ≤ 20, Untertitel ≈ 4, Touch ≈ 4 |
| Materialien | ≤ 24 | 21–23 | +1 (Telegraph), Sweep ist Canvas |
| `Label3D` | ≤ 12 | ≤ 8 | +0 (keine 3D-Plaketten) |
| Partikel | ≤ 400 / 6 Emitter | — | Treffer-Funken je Einheit höchstens alle 0,2 s, Pool |
| Physik-Körper | ≤ 40 | 23 | Puppen ohne Körper (Kollision im Kampf aus) |
| Sim | §3.15 | — | ≤ 0,25 ms/Tick Desktop |

Umsetzungsregeln aus den Messungen: (1) gleiche Shader-Instanzen mit Instanz-Uniforms statt eigener Materialien; (2) Rahmen,
Leisten, Symbole als Dreiecks-Arrays (`icon_mesh.gd`); (3) Labels ohne Outline auf dunklem Grund; (4) keine `TextureProgressBar`-
Radialanzeigen, keine `PanelContainer`-Plaketten, keine `Label3D`-Plaketten, keine SubViewport-Porträts im Kampf;
(5) Komparsen-Rigs werden beim Betreten eines Raums unsichtbar vorgebaut (kein Hänger beim Kampfstart), unsichtbar kosten sie
keine Draw Calls. R2/R3 messen mit `tools/perf.sh` (neue Szenarien `combat_regular`, `combat_boss_queen`, §12.4).

---

## 9. Show-System und Marotten

### 9.1 Kampf-Log → Hype (ShowRules-Profil `rt`)

`ShowRules` erhält ein Profil (`profile: StringName`, `&"ctb"` | `&"rt"`), gesetzt von `Show.begin_battle(setup)` über
`setup is RtSetup`. Das CTB-Profil bleibt unverändert, bis CTB entfernt wird. Startwerte des Echtzeit-Profils (Konstanten
`RT_*` in `show_rules.gd`, per Balancing änderbar, R5):

| Anlass | CTB | Echtzeit |
|---|---|---|
| Kampfstart normal / Erstschlag / Hinterhalt / Boss | +3 / +3 / +5 / +8 | gleich |
| Abwechslung (Fähigkeit nicht unter den letzten 4 Party-Aktionen) | +2 | +1 |
| Wiederholung | −5 (3 × gleich) | −3 (4 × gleiche Fähigkeit in Folge) |
| Krit der Party | +3 | +2 |
| Schwäche (einmal je Aktion) | +2 | +1 |
| Kill durch Auto-Angriff / Fähigkeit / Stunt | +1 / +2 / +4 (+`kill_hype`) | gleich |
| Overkill | +3 | +3 (Schwelle §3.9.1) |
| Serie | +5 (3 Kills in 3 Aktionen) | +5 (3 Kills in 6 s) |
| Combo | +2 | +2 (höchstens alle 5 s, Sim-Regel) |
| Stunt Erfolg / Fehlschlag | +12 / +4 | gleich |
| **Unterbrechung** durch die Party (`CAST_INTERRUPTED`) | — | +3 |
| **Ausgewichen** / **knapp ausgewichen** (`TELEGRAPH_DODGED`, Party) | — | +2 / +4 je Telegraph und Einheit |
| **Zug-Kill** (Add stirbt durch einen gegnerischen Telegraphen) | — | +4 |
| **Perfekte Bossphase** (`PHASE_CHANGE`/`BATTLE_END` mit `success`) | — | +8 |
| **Enrage beginnt** (`ENRAGE`, einmal) | — | +5 |
| Party-Mitglied < 25 % HP (einmal je Mitglied und Kampf) | +6 | gleich |
| Party-K.O. / Wiederbelebung | +10 / +8 | gleich |
| Flucht | −30 | gleich |
| Langeweile | −3 bei `TURN_END` ohne positives Ereignis | −2 je 6 s (über `SECOND`) ohne positives Ereignis |
| Zweimal Verteidigen | −4 | entfällt |
| Schleppen | −3 nach 10 (Boss 25) Party-Aktionen | −3 je 10 s ab 45 s Kampfdauer (Boss ab 4:00) |
| Knapper Sieg (≤ 10 % HP) / Makellos | +15 / +3 | gleich |

- **Aktion** = Party-`ACTION_START` (Fähigkeit, Stunt, Gegenstand) bis `ACTION_END`; Auto-Angriffe sind keine Aktionen
  (zählen nicht für Abwechslung, Wiederholung, Serie), ihre Kills zählen +1.
- Kill-Zuordnung für Status-, Zonen- und Telegraph-Kills wie bisher über `KO.actor_id`/`command = −1`.
- `hype_gain_mult` der Ausrüstung, Sponsor-Schwellen 70/85/100 und Hype-Verfall (nur Erkundung) bleiben unverändert.

### 9.2 Sponsor-Geschenke im Kampf

Ablauf an **jeder Tick-Grenze** (live im `CombatDirector`, im Replay in `Game.replay_log`, identisch):

```gdscript
# before RtSim.step() of tick c = sim.tick(); live: once per tick, before submitting the player's commands of tick c
var g: Dictionary = Show.take_pending_gift_rt(sim)     # external first, then system thresholds (SponsorSystem.pick)
if not g.is_empty():
	var ev: Array[ActionEvent] = sim.apply_gift(g)       # SPONSOR_GIFT + HEAL / MP_CHANGE / STATUS_ADDED / REVIVE / ITEM_GAINED / CREDITS_GAINED
	for e: ActionEvent in ev:
		Show.on_battle_event(e)
	Show.note_battle_gift(g, ev)
	if Gift.is_external(g):
		Game.record({"t": "gift", "gift": g, "ct": c})     # cmd id 0 (05 §10.6: recorded at application)
```

- Wirkungen (`GIFT_KINDS`) im Echtzeitkampf: `heal_party_pct`, `heal_party_flat` (× `FIXED_SCALE_PM`), `mp_party_pct`,
  `status_party` / `status_enemies` (Dauer aus dem Geschenk `ms` oder `StatusDef.rt.default_ms`), `item` (ins Inventar),
  `revive_or_heal_lowest` (K.O. → Wiederbelebung 30 %, sonst Heilung des Schwächsten).
- `Show.take_pending_gift_rt(sim: RtSim) -> Dictionary` (neu, R5) entspricht `take_pending_gift(state)`, liest die
  Gewichtungsbedingungen (`ally_hp_below`, `ally_mp_below`, `ally_ko`, `is_boss`) aus `sim.units()`.
- Grenzen unverändert: System-Geschenke höchstens 1 pro regulärem Kampf, 2 pro Bosskampf; externe höchstens
  `rules.gifts.max_per_battle`; Fenster öffnen im Kampf nicht (§2.10).
- Darstellung: Sponsor-Bauchbinde 1,5 s (380 px), Drohne fliegt zum Ziel, Effekt am Ziel, Chat-Jubel; keine Pause, keine
  Eingabesperre.

### 9.3 M.O.D.-Zeilen im Kampf

- Neue Tags (`mod_lines.json`, R4): `combat_set_quiet`, `combat_interrupt`, `combat_dodge_close`, `combat_telegraph_hit`,
  `combat_flee_warn`, `control_switch:kai`, `control_switch:mopsula`, `partner_preset:attack`, `partner_preset:support`,
  `partner_preset:careful`, `boss_enrage:<enemy_id>`, `train_kill`, `rt_tutorial_target`, `rt_tutorial_bar`,
  `rt_tutorial_show`, `rt_tutorial_dodge`, `rt_tutorial_interrupt`. Bestehende Tags (`boss_intro:*`, `boss_phase:*`,
  `first_fight`, `kai_ko`, `mopsula_ko`, `revive`, `stunt_success`, `kill_streak`, `crit`, `overkill`, `low_hp`, …) gelten weiter.
- Ratenbegrenzung im Kampf: höchstens eine nicht blockierende Zeile je 6 s; Vorrang: `boss_phase`/`boss_enrage` > K.O. >
  `control_switch` > Unterbrechung/knappes Ausweichen/Zug-Kill > Rest. Verdrängte Zeilen entfallen (keine Warteschlange im Kampf).
- **KI-Admin** (KI-generierte Kommentare, parallel): im Kampfkontext höchstens 70 Zeichen („Kampf-Untertitel“), gleiche
  Ratenbegrenzung, nie blockierend; kommt eine Generierung zu spät (> 1,5 s nach dem Anlass), fällt die Zeile auf
  `mod_lines.json` zurück. M.O.D.-Zeilen sind Darstellung (nicht im Log, keine Sim-Wirkung).
- Tonbeispiele: `combat_interrupt` „Und da wird ihm das Wort abgeschnitten — live und in Farbe!“; `combat_dodge_close`
  „Zentimeterarbeit! Unsere Versicherung atmet auf.“; `combat_flee_warn` „Wo willst du hin? Das Set ist HIER!“;
  `control_switch:mopsula` „Der Graf übernimmt. Möge der Adel mit uns sein.“; `boss_enrage:enm_boss_hausmeister` „Es ist
  17 Uhr. Ab jetzt macht der Hausmeister Überstunden — an euch.“; `train_kill` „Bitte zurückbleiben! … Zu spät.“;
  `partner_preset:careful` (Mopsula) „Vorsichtig? Ich bin ein Graf, kein Hasenfuß. Nun gut.“

### 9.4 Achievements und Trigger-Payloads

- `battle_won.party_turns` und `boss_defeated.party_turns` = Zahl der Party-`ACTION_START` im Kampf; `encounter_type` aus dem
  Vorteil; `min_party_hp`, `min_party_hp_pct`, `crits`, `weakness_hits`, `items_used`, `party_kos`, `damage_taken` aus
  `BattleResult` (unverändert). Alle bestehenden Achievements bleiben erreichbar (Prüfliste §12.5 Nr. 7).
- Neue Payload-Schlüssel (additiv, R5, `DataValidator.TRIGGER_PAYLOAD_KEYS`): `battle_won.duration_sec`, `.interrupts`,
  `.dodges`, `.telegraph_hits`.
- Vorschlag neuer Achievements (R4, optional): `ach_interrupt_10` „Wort abgeschnitten“ (10 Unterbrechungen), `ach_dodge_25`
  „Tanz auf dem Bahnsteig“ (25 Ausweicher), `ach_train_adds` „Bitte zurückbleiben!“ (3 Zug-Kills in einem Kampf),
  `ach_perfect_phase` „Fehlerfrei auf Sendung“ (eine perfekte Bossphase). Neue `StatIds`: `interrupts_total`, `dodges_total`,
  `train_kills`.

### 9.5 Hooks: Talentwahl, Marotten, Spezies/Spezialisierung, Twists (`RtMods`)

Die parallel entstehenden Systeme wirken auf den Kampf **nur** über eine geschlossene Liste von Modifikatoren in
`RtSetup.mods` (statisch beim Aufbau) bzw. über Ereignis-Reaktionen der Sim. So bleibt die Sim deterministisch und testbar.

```json
{"src": "perk:<id>" | "quirk:<id>" | "species:<id>" | "spec:<id>" | "equip:<id>" | "twist:<id>",
 "op": "<OP>", "unit": "p0" | "party" | "enemies" | "all", "...": "op-specific"}
```

| `op` | Felder | Wirkung |
|---|---|---|
| `stat_pm` | `stat` (`str`, `mag`, `def`, `res`, `spd`, `lck`, `max_hp`, `max_mp`), `pm` | Wert × pm/1000 beim Aufbau |
| `skill_pm` | `skill` (Id, `*` oder `tag:<show_tag>`), `field` (`power`, `cooldown`, `cast`, `mp`), `pm` | Fähigkeitswerte |
| `move_pm`, `swing_pm`, `threat_pm`, `dmg_dealt_pm`, `dmg_taken_pm`, `heal_taken_pm` | `pm` | Multiplikatoren |
| `on` | `event` (`kill`, `interrupt`, `dodge`, `crit`, `ko_ally`, `combat_start`, `show_success`), `effect` (`{"heal_pct": int}` \| `{"mp": int}` \| `{"status": id, "ms": int}`) | Reaktion der Sim auf Ereignisse der Einheit |
| `forbid_skill` | `skill` | Fähigkeit gesperrt (`ACTION_REFUSED forbidden`) |
| `forbid_items` | `tag` | Gegenstände mit Tag gesperrt |
| `unlock_variant` | `slot`, `skill` | schaltet eine Leisten-Variante frei (wirkt auf die Belegung außerhalb der Sim) |

- `RtMods.validate(mods: Array) -> PackedStringArray` (Fehlerliste), `RtMods.apply_static(setup)`, `RtMods.on_event(sim, e)`.
  Nur Ganzzahlen. Show-Wirkungen von Marotten (z. B. Hype-Bonus der „Unterhosen-Liga“) bleiben im Show-System;
  Ausrüstungsregeln (keine Rüstung/Stiefel/Hose) gelten in `Progression`, nicht in der Sim.
- Beispiele: Talentwahl „Tierpfleger-Instinkt“ `{"src": "perk:p_vet_instinct", "op": "on", "unit": "p0", "event": "interrupt",
  "effect": {"mp": 2}}`; Spezialisierung (ab Etage 3) `{"src": "spec:s_janitor", "op": "skill_pm", "unit": "p0", "skill":
  "skl_kai_sweep", "field": "cooldown", "pm": 750}`; Marotte `{"src": "quirk:q_underpants", "op": "dmg_taken_pm", "unit":
  "party", "pm": 1100}`.
- **Twists im Kampf** (KI-Admin, 05 §6.2): kommen als externe Befehle (`id` 0) mit `ct`, werden an der nächsten Tick-Grenze
  angewendet (`RtSim.apply_twist`). Wirkung über `RtMods.TWIST_EFFECTS` (Twist-Id → Ops; Zusatz-Ops `spawn {enemy, count, at}`,
  `telegraph {skill}`, `status_all {side, status, ms}`); nicht gelistete Twists wirken im Kampf nur in der Darstellung.

| Twist | Wirkung im Kampf |
|---|---|
| `tw_lights_out` | Darstellung (dunkler; Plaketten und Telegraphen bleiben voll sichtbar) |
| `tw_double_trouble` | `spawn` 1 × erster Gegnertyp der Begegnung an einer Tür (nur wenn < 6 Gegner, nicht im Bosskampf) |
| `tw_rat_rain` | `telegraph` `skl_tw_rat_rain`: 4 Kreise r 200 (`random`), Warnung 1,5 s, 5 % Max-HP fest |
| `tw_boss_mood` | `status_all` Gegner-Boss `sts_haste` 15 s |
| `tw_sponsor_rush`, `tw_fog_of_fame`, `tw_mopsula_monologue`, `tw_costume`, `tw_mod_mood` | keine Sim-Wirkung (Show/Darstellung) |

---

## 10. Live, Replay und Netz

### 10.1 Befehle

Alle Werte Ganzzahlen bzw. Strings; Positionen raumlokal in cm; `u` = Einheiten-Id; `target` = Einheiten-Id oder `""`.

| `t` | Form | Bemerkung |
|---|---|---|
| `encounter` (erweitert) | `{"t": "encounter", "enc", "adv", "group", "rt": {"v": 1, "cell": [cx, cy], "ctl": "p0", "party": [{"u": "p0", "p": [x, z, yaw]}, {"u": "p1", "p": [x, z, yaw]}], "groups": [{"group": "f1_g3", "enc": "enc_f1_a2", "lead": [x, z, yaw], "state": "PATROL"}], "presets": {"p1": {"preset": "support", "tog": {"interrupt": true, "show": true, "potions": true}}}, "auto": true, "retarget": true, "open": {} }}` | ohne `rt` = CTB-Kampf (bis R5) |
| `ability_use` | `{"t": "ability_use", "ct", "u", "skill", "target"}` | |
| `target_change` | `{"t": "target_change", "ct", "u", "target"}` | |
| `move_sample` | `{"t": "move_sample", "ct", "u", "p": [x, z, vx, vz, yaw]}` | `vx`/`vz` mm/Tick |
| `combat_item` | `{"t": "combat_item", "ct", "u", "item", "target"}` | Auftragsname „item_use“; umbenannt, um Verwechslung mit dem Feldbefehl `use_item` zu vermeiden |
| `partner_preset` | `{"t": "partner_preset", "ct", "u", "preset", "tog": {...}}` | |
| `auto_attack` | `{"t": "auto_attack", "ct", "u", "on": bool}` | |
| `autopilot` | `{"t": "autopilot", "ct", "u", "on": bool}` | |
| `gift`, `twist` (im Kampf) | bestehend + `"ct"` | extern, `id` 0 |
| `move_batch` | `{"t": "move_batch", "u", "id0", "s": [[dct, x, z, vx, vz, yaw], …]}` | nur in gespeicherten Logs (§10.3) |

`RtCommand.validate(d) -> String`: Typ bekannt, Pflichtfelder, Ganzzahlen, `ct ≥ 0`, `|x|, |z| ≤ 2400`, `|vx|, |vz| ≤ 400`,
`yaw` 0…255, Einheiten-Id `^p[0-3]$` bzw. `^e[0-9]+$`, `preset` ∈ `RT_PRESETS`, `tog`-Schlüssel ∈ `RT_TOGGLES`.
`Command.TYPES` wird um die neuen Typen erweitert und delegiert ihre Prüfung an `RtCommand.validate` (R1).

### 10.2 Aufzeichnung und Reihenfolge

- Lauf-Tick `k` aller Kampf-Befehle = `k` des `encounter` (die Uhr steht, `explore_only`). Reihenfolge im Kampf: `ct`
  nicht fallend, dann Befehls-Id. `RunLog.validate` prüft das zusätzlich (zwischen `encounter` mit `rt` und Kampfende).
- Alle Kampf-Befehle (auch Proben) erhalten fortlaufende Ids; externe (`gift`, `twist`) Id 0.
- Aufgezeichnet wird jeder von `RtSim.submit` angenommene Befehl (§3.4); abgelehnte nicht.
- **Kampf-Prüfpunkte:** alle `CHECKPOINT_TICKS = 300` Kampf-Ticks und beim Kampfende `{"k": k, "ct": ct, "h":
  StateHash.of_rt(sim)}` (`RunLog.add_checkpoint(k, h, ct = -1)`, additiv); danach wie bisher ein Zustands-Prüfpunkt nach dem
  Kampf.
- Kopf: `"combat_mode": "realtime"`, `"rt_version": 1`; `sim_version` wird erhöht.
- Das Kampfende ist **kein** Befehl: die Sim bestimmt es. Replays rechnen den Kampf vor dem nächsten Nicht-Kampf-Befehl (bzw.
  am Log-Ende) mit `run_to_end` zu Ende; ein Kampf-Befehl nach dem Ende ist ein Replay-Fehler. Der End-Prüfpunkt bestätigt
  Tick und Zustand.
- `timer_mode: realtime` (05 S4, später): `k = k_encounter + ct`.

### 10.3 Kompaktierung

`move_sample` macht 60–70 % der Kampfeinträge aus. Schätzung: ≈ 70 Byte je Eintrag, ≈ 4 Proben/s in Bewegung → 4-min-Bosskampf
≈ 960 Einträge ≈ 67 KB, eine Etage (≈ 12 min Kampf) ≈ 200 KB roh, ≈ 30 KB gzip. `RunLog.compact()` fasst **aufeinanderfolgende**
`move_sample`-Einträge derselben Einheit ohne andere Einträge dazwischen zu `move_batch` zusammen (Ids fortlaufend ab `id0`,
`ct` als Differenzen); `RunLog.expand()` stellt die Einträge bitgenau wieder her. Prüfung und Replay arbeiten auf der expandierten
Form; Hashes sind unabhängig davon. Live-Streams übertragen unkompaktierte Einträge.

### 10.4 StateHash-Abdeckung

`StateHash.of_rt(sim: RtSim) -> String` = Hash über `CanonicalJson` von `sim.snapshot()`:

- Kampf: `ct`, `rng_n`, nächste Einheiten-/Telegraph-Nummer, `controlled_id`, Ende/Ergebnis, Combo-/Serien-Zähler, Bilanzzähler.
- Je Einheit: alle Felder aus §3.4 (`RtUnit`) plus `Combatant`-Felder (HP, MP, Werte, Status als `RtStatus.to_dict`, Phase,
  `used_once`, Belohnungen); Wörterbücher (`threat`, `cooldowns`, `rule_ready`) mit sortierten Schlüsseln.
- Telegraphen/Zonen (alle Felder, `inside_last` sortiert), ausstehende Treffer, eingereihte Befehle (nach `ct`, Reihenfolge).
- Nichts Spielrelevantes ist ausgenommen (die Sim enthält keine Darstellungsdaten).

`StateHash.of(GameState)` bleibt; neue Felder (`GameState.combat_mode`, `FloorRun.regen_ticks`, `PartyMember.hp_scale_pm`,
`rt_preset`, `rt_toggles`, `rt_loadout`) werden **nur serialisiert, wenn sie vom Standard abweichen** — bestehende
Golden-Hashes der CTB-Tests bleiben gültig.

### 10.5 RunSim-Integration (R5; Regeneration R1)

```gdscript
var combat: RtSim = null                    # running real-time combat (RunSim-driven runs)
# apply({"t": "encounter", ..., "rt": {...}}):
#   setup = BattleBridge.make_rt_setup(state, data, c, next_seed("battle")); next_seed("show")  # same streams as CTB
#   combat = RtSim.new(setup, data); last_action_events = combat.start(); quest feed
# apply(<combat command>):  _advance_combat_to(int(c["ct"])); var r := combat.submit(c)  (r != "" → rejected_cmds, warning)
# apply(<any other command>) and replay end:  _finish_combat()  (run_to_end(MAX_COMBAT_TICKS - tick), apply_result,
#   checkpoint due, regen_ticks = 0)
# is_clock_running(): false while combat != null
# _tick_once(): new step 6 regeneration (§2.7)
```

Externe Geschenke im Kampf: `combat.apply_gift(g)` an ihrem `ct`. RunSim-Kernläufe enthalten wie bisher keine System-Geschenke
und keine Show-Reaktionen (05 §11.4); vollständige Live-Läufe reproduziert `Game.replay_log`.

### 10.6 `Game.replay_log`-Äquivalenz

`Game` (R2) bietet `make_rt_setup(params: Dictionary) -> RtSetup` (zeichnet `encounter` auf, zieht die Seeds, ruft
`Show.begin_battle`), `combat_submit(cmd: Dictionary) -> String` (`RtSim.submit` + `record`), `combat_step() ->
Array[ActionEvent]` (ein Tick, speist jedes Ereignis in `Show.on_battle_event`, schreibt Kampf-Prüfpunkte) und
`end_combat() -> BattleRewards`. Der Live-`CombatDirector` und das Replay benutzen **genau diese** Funktionen:

```
für jeden Kampf-Eintrag e (Log-Reihenfolge):
    solange sim.tick() < e.ct:  Tick-Grenze(ohne Log-Geschenk); Game.combat_step()
    wenn e ein gift ist: Tick-Grenze(e.gift)   # Show.receive_gift(e.gift), dann take_pending_gift_rt → apply_gift
    sonst:               Game.combat_submit(e.c)
nach dem letzten Kampf-Eintrag: solange nicht beendet: Tick-Grenze(ohne); Game.combat_step()
Game.end_combat()
```

Live ruft die Tick-Grenze genau einmal pro Tick vor den Spielerbefehlen dieses Ticks auf (§9.2). Pflichttest (R5): ein
geskripteter Live-Lauf über die `Game`-API (headless, mit externen Geschenken und Twists) und sein `Game.replay_log` liefern
identische GameState-Hashes, identische Kampf-Prüfpunkte und identische Show-Zahlen (Hype, Follower, Zuschauermodell,
Achievements). Das Replay prüft zusätzlich die FINALE-Bedingung (Hype ≥ 85 beim `ability_use`).

### 10.7 Pur-Liga und Event-Regeln

- Pur-Liga: keine externen Geschenke (GiftPolicy unverändert), keine Twists (Event-Regel).
- Neue optionale Regeln `rules.combat`: `speed_pm_min` (Standard 1000: kein langsameres Spieltempo), `autopilot` (Standard
  `false` in Ligen → `submit` lehnt mit `forbidden` ab), `assist` (Standard `true`), `max_enemies` (Standard 6).
- Bestenlisten: Replay muss bitgenau sein; Positionsproben sind Client-autoritativ → Plausibilitätsprüfung im Verifier
  (Sprung-/Tempo-Ablehnungen = 0; Ausreißer-Statistik „perfekte Ausweicher“ markiert, lehnt nicht ab), §13.

### 10.8 Später: Koop (2–4) und MMO-lite, server-autoritativ

- Dieselbe `RtSim` läuft auf dem Server (Godot headless, 05 §3.2) mit 30 Hz. Jede menschliche Person steuert eine Party-Einheit
  (`u`); freie Plätze spielt die Partner-KI.
- Clients senden `move_sample` (gleiche Schwellen) und Befehle; der Server stempelt `ct` = Server-Tick beim Eingang
  (+ 2 Ticks Eingangspuffer), prüft und wendet an. Kein Rollback.
- Server sendet Ereignisse (zuverlässig, geordnet) und Schnappschüsse mit 15 Hz (Position, Gier, HP, MP, Zauber, Ziel ≈ 14 Byte
  je Einheit; 10 Einheiten ≈ 2,1 KB/s je Client).
- Clients sagen **nur die eigene Bewegung** voraus (lokaler `CharacterBody3D`) und gleichen bei Abweichung > 25 cm ab (05 §3.5);
  andere Einheiten 100 ms verzögert interpoliert; eigene Tastendrücke zeigen sofort die Animation, Wirkung nach Bestätigung.
- Latenzbudget: RTT ≤ 150 ms „gut“; das Queue-Fenster (300 ms) deckt das ab; Telegraph-Warnzeiten ≥ 1,0 s (≥ 6 × RTT).
- Lag-Kompensation für Telegraph-Treffer: Der Server prüft die Position einer Person zum Tick `impact − min(rtt/2, 6 Ticks)` aus
  ihrem Probenverlauf (höchstens 200 ms zurück).
- Raids: Obergrenzen werden Regeln (`max_enemies`); Kosten pro Tick linear in Einheiten + Telegraphen.

---

## 11. Balancing-Ziele

### 11.1 Zielwerte (Etage 1, Profil `typical`, Erstspieler-Modell GDD §13)

| Größe | Ziel | Herkunft |
|---|---|---|
| Kampfdauer regulär (TTK der Gruppe) | 15–35 s, Median 20–25 s | Auftrag |
| Kampfdauer Der Hausmeister | 2:30–3:30 | Auftrag 2,5–4 min, GDD §13 |
| Kampfdauer Die Rattenkönigin | 3:00–4:00 | Auftrag 2,5–4 min (GDD §13 nannte 3,5–5 für CTB) |
| HP-Verlust der Party je regulärem Kampf (ohne Tränke, in % der Summe Max-HP) | 20–35 % | GDD §13 |
| Kämpfe zwischen zwei Safe Rooms ohne Tränke | 2–3 | GDD §13 (mit Regeneration §2.7 neu messen) |
| Verbrauchte Heilgegenstände je Etage | 3–6 | neu |
| Erstversuch-Niederlage Hausmeister / Königin | ≈ 20 % (10–30 %) / ≈ 35 % (25–45 %) | GDD §13 |
| Stufe bei Hausmeister / Königin | 5 / 7 | GDD §13 |
| Etagenzeit Timer-Nutzung (Erkundung) / gesamt | 11–15 min / 22–28 min | GDD §13 |
| Unterbrochene unterbrechbare Boss-Zauber | ≥ 60 % | neu |
| Party-Treffer durch Boss-Telegraphen | ≤ 25 % der Einschläge, die ein Mitglied hätten treffen können | neu |
| Hype Start/Ende der Etage, Geschenke je Etage, Follower, Spitzen-Zuschauer | 25–45 / 45–65, 4–7, 1 200–1 500, 3 000–5 500 | GDD §13 |

### 11.2 Stellschrauben (Reihenfolge der Anpassung)

1. Gegner-HP (`rt.hp_pm`, Boss `rt.hp`) → Kampfdauer.
2. Gegner-Takt (`swing_ms`), `rt.dmg_pm`, Regel-Wiederholung (`every_ms`) → HP-Verlust.
3. Telegraph-Warnzeiten, Zonen-Dauer → Fairness, Ausweichquote.
4. Party: `rt.power`/`rt.mp`/`cooldown_ms` einzelner Fähigkeiten, MP-Laderaten, `HP_SCALE_PM`.
5. `RtBalance.REGEN_*`, `ITEM_CD_TICKS` → Tränke je Etage.
6. Enrage-Zeit (weich), Boss-Phasenschwellen.
7. ShowRules-`RT_*` → Hype/Geschenke/Follower.

Formeln (GDD §3.7) und Krit/Varianz bleiben fest.

### 11.3 Startwerte und Überschlag

Party-DPS (Einzelziel, nachhaltig, ohne Schwäche, Startausrüstung, typische Rotation): Stufe 1 Kai ≈ 9,5 (Auto 6,1 +
Wuchtschlag 3,3), Mopsula ≈ 6,3 (Auto 3,6 + Adelsflamme 2,7) → Party ≈ 16 + Anfangsschub (Kai 12 MP = 4 Wuchtschläge, Mopsula
30 MP = 7 Flammen). Stufe 5 ≈ 24 roh, Stufe 7 ≈ 31 roh; im Bosskampf ≈ 65–70 % Wirkzeit (Ausweichen, Unterbrechen, Heilen).

| Begegnung (Stufe) | Echtzeit-HP gesamt | geschätzte Dauer |
|---|---|---|
| `enc_f1_a1_tutorial` (1) | 192 | ≈ 12 s |
| `enc_f1_a2` (2) | 272 | ≈ 14–16 s |
| `enc_f1_b1` (3; Schleim physisch × 0,5) | 352 | ≈ 20–24 s |
| `enc_f1_c3` (4–5) | 472 | ≈ 20–25 s |
| `enc_f1_d2` (6–7) | 760 | ≈ 26–30 s |
| Hausmeister (5) | 2 600 | ≈ 2:35–2:50 |
| Rattenkönigin (7) | 4 000 | ≈ 3:15–3:30 |

Schadensbeispiel `enc_f1_a2`: zwei Ratten (je ≈ 2,7 DPS) + Tauben (≈ 3 DPS auf den Schwächsten) ≈ 8,4 DPS × 14 s ≈ 118 von
424 Party-HP ≈ 28 % (im Band). Diese Zahlen sind Überschläge für den Start; maßgeblich sind die Harness-Messwerte (§11.5).

### 11.4 Messmethode

- **Harness** `tests/tools/rt_harness.gd` (R4), gestartet über `tools/rt_balance.sh` (`godot --headless -s
  res://tests/tools/rt_harness_main.gd -- …`; das `-s`-Skript lädt die Harness per `load()`, weil `-s`-Skripte Klassen/Autoloads
  nicht direkt referenzieren): baut für jede Begegnung der Etage 1 ein `RtSetup` mit Party auf der Zielstufe der Zone (A 1–2,
  B 3, C 4–5, D 6–7, Bosse 5/7) und der Ausrüstung des Zonen-Kaufplans, spielt N Seeds (Standard 200) mit `RtBotPlayer`
  (§5.7, Profile `perfect`/`typical`/`sloppy`) und dem Partner auf Standard-Taktik, rein über `RtSim` (keine Szene).
- Ausgabe je Begegnung und Profil: Median/P10/P90 der Dauer, HP-Verlust, Tränke, K.O.s, Niederlagen-Quote, Unterbrechungsquote,
  Ausweichquote, Hype-relevante Ereignisse/Minute; Tabelle auf stdout + JSON (`--out=<datei>`).
- **CI-Test** `test_r4_rt_balance.gd`: 20 Seeds `typical` je Begegnung (Laufzeit < 60 s), prüft die Bänder §11.1 mit Toleranz
  (Dauer ± 20 %, Bossverlust-Bänder ± 5 Prozentpunkte).
- **Full-Run** (`tools/fullrun.sh --combat=realtime --strategy=typical --pace=human`, R5): Etagenzeit, Stufen, Show-Zahlen;
  10 Seeds lokal, 1 Seed in CI.
- Determinismus der Messung: Harness-Seeds fest (`SeedUtil.derive(4242, "harness", n)`), Ergebnisse reproduzierbar.

### 11.5 Messwerte (füllt R4, aktualisiert R5)

| Begegnung | Profil | Dauer Median | HP-Verlust | Tränke | Niederlagen | Stand |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | noch nicht gemessen |

---

## 12. Migrations- und Umsetzungsplan

### 12.1 Schalter (Feature-Flag)

- `GameSettings.combat_mode: StringName` (`&"ctb"` | `&"realtime"`). **Standard bis R5: `&"ctb"`**; Entwicklung/QA schalten über
  das Einstellungsmenü (nur Debug-Builds) oder `--combat=realtime` (Boot-Argument, auch für `check.sh --shot`, Autoplay,
  `fullrun.sh`). R5 stellt den Standard auf `&"realtime"` und entfernt danach CTB.
- `GameState.combat_mode` (gespeichert, gehasht wenn ≠ `ctb`): neue Spiele übernehmen die Einstellung, geladene Spielstände
  behalten ihren Modus (keine Umrechnung vor R5). RunLog-Kopf trägt `combat_mode`.
- Verzweigungspunkte (einzige): `ExplorationScene` (Kampfstart: `Router.start_battle` vs. `CombatDirector`), `Progression.total_stats`
  (HP-Skala über `PartyMember.hp_scale_pm`), `RunSim.apply` (`encounter` mit/ohne `rt`), `Show.begin_battle` (Profil).
- CTB-Tests bleiben während R1–R4 grün (Gate jeder Phase).

### 12.2 Phasen

| Phase | Agent | Inhalt | Ergebnis / Gate |
|---|---|---|---|
| **R1a** Stubs | A „Kern“ | alle öffentlichen R1-Dateien als Stubs (exakte `class_name`, Signaturen, Standardrückgaben; erste Zeile `# STUB(R1) — owned by R1. Replace completely, keep the public API.`), additive Änderungen an geteilten Dateien (Felder, Enum-Werte, Signaturen), Fixture-Daten `tests/fixtures/rt_min/` | `check.sh --tests-only` grün; danach starten R2, R3, R4, R5a |
| **R1b** Kern | A | Implementierung in Stufen: I1 Bewegung/Proben, Auto-Angriff, Fähigkeiten, Gegenstände, Ergebnis; I2 Status, Bedrohung, Partner-KI, Autopilot, Assist; I3 Gegner-KI, Telegraphen, Zonen, Phasen, Enrage, Beschwörungen, Mods, Twists | Tests §12.4 R1, Golden-Hash fest, Lint grün |
| **R2** Welt | B „Welt“ | Kampf in der Welt (Director, Puppen, Proben, Telegraph-Layer, Boss-Intro, Flucht, Türen, Kamera, Game-API) | Szenentests grün; Fixture-Kampf spielbar; Perf-Szenario gemessen |
| **R3** HUD + Eingabe | C „HUD“ | HUD, Input-Map, Touch, Einstellungen, Untertitel-Modus, Overlay-Modus, Fähigkeiten-Menü (Leiste/Varianten/Taktik) | HUD-Tests grün; Captures 1280 × 720, 1920 × 1080, Touch, Notch |
| **R4** Inhalte + Balance | D „Inhalt“ | `rt`-Daten aller Etage-1-Inhalte, neue Status/Skills/Gegner, Bosse, Validator, Gleis-9-Bühne, Harness + Bot, Abstimmung | Validator grün, Harness-Bänder §11.1 erreicht, §11.5 ausgefüllt |
| **R5a** Show + Live | E „Integration“ | ab R1a parallel: ShowRules-Profil `rt`, `take_pending_gift_rt`, RunLog/Command/RunSim-RT, `Game.replay_log`-RT, Kompaktierung | Show-/Replay-Tests mit Fixtures grün |
| **R5b** Integration | E (+ Rückfragen an A–D) | Full-Run-Bot RT, Autoplay-Smoke, Performance, Doku, Parität (§12.5), Standard `realtime`, CTB-Entfernung, Datenbacken, Save v2 | §12.5 erfüllt; `check.sh` + `fullrun.sh` grün |

### 12.3 Dateieigentum je Phase

Regel (wie 02_TECH §0.2): Jede Datei hat pro Phase genau einen Eigentümer. Geteilte Bestandsdateien werden **nur additiv**
geändert (neue Felder/Funktionen/Enum-Werte am Ende, keine Umbenennung, kein Entfernen) und in einem markierten Abschnitt
(`# --- Echtzeitkampf (07, R<n>) ---`). Brauchen zwei Phasen dieselbe Datei, arbeitet die spätere erst nach dem Merge der
früheren oder in einem eigenen Abschnitt (unten jeweils angegeben).

**R1 (Agent A) — neu**

| Datei | Zweck |
|---|---|
| `core/rt/rt_sim.gd`, `rt_setup.gd`, `rt_unit.gd`, `rt_status.gd`, `rt_telegraph.gd`, `rt_rules.gd`, `rt_command.gd`, `rt_geo.gd`, `det_math.gd`, `rt_balance.gd`, `rt_mods.gd` | öffentliche Klassen (§3.1) |
| `core/rt/rt_ability.gd`, `rt_damage.gd`, `rt_threat.gd`, `rt_movement.gd`, `rt_result.gd` | private Helfer (ohne `class_name`, per `preload`) |
| `tests/test_r1_det_math.gd`, `test_r1_rt_timing.gd`, `test_r1_rt_threat.gd`, `test_r1_rt_status.gd`, `test_r1_rt_ai.gd`, `test_r1_rt_telegraph.gd`, `test_r1_rt_move.gd`, `test_r1_rt_result.gd`, `test_r1_rt_mods.gd`, `test_r1_rt_golden.gd`, `test_r1_rt_int_only.gd`, `test_r1_regen.gd` | Tests §12.4 |
| `tests/fixtures/rt_min/*.json` | Fixture-Daten (Kopie von `data_min` + `rt`-Blöcke, zwei Testgegner, ein Testboss) |

**R1 (Agent A) — geändert (additiv)**

| Datei (Bestandsmodul) | Änderung |
|---|---|
| `core/battle/action_event.gd` (M1) | neue `Type`-Werte am Enum-Ende (§3.13), Felder `tick`, `rt`; `to_dict`/`from_dict` (nur Nicht-Standard) |
| `core/battle/battle_result.gd` (M1) | `group_ids`, `duration_ticks`, `interrupts`, `dodges`, `telegraph_hits` (+ Serialisierung, nur Nicht-Standard) |
| `core/data/defs/skill_def.gd`, `status_def.gd`, `enemy_def.gd`, `item_def.gd`, `party_member_def.gd`, `encounter_def.gd` (M0) | Feld `rt: Dictionary`, Normalisierung mit Standards (§4.6–4.9) |
| `core/progression/battle_bridge.gd` (M2) | `make_rt_setup(state, data, cmd, seed) -> RtSetup`; `apply_result` verarbeitet `group_ids` |
| `core/progression/party_member.gd`, `game_state.gd`, `floor_run.gd`, `progression.gd` (M2) | `hp_scale_pm`, `rt_preset`, `rt_toggles`, `rt_loadout`, `combat_mode`, `regen_ticks`; Skala in `total_stats` und fester Feldheilung |
| `core/live/command.gd`, `state_hash.gd`, `run_log.gd` (M8) | neue Typen + Delegation an `RtCommand`; `of_rt`; `add_checkpoint(k, h, ct = -1)`, `ct`-Ordnung in `validate` |
| `core/live/run_sim.gd` (M8) | nur Schritt 6 Regeneration (RT-Kampf folgt in R5, eigener Abschnitt) |
| `tests/test_m8_no_global_rng.gd` (M8) | `core/rt/` ohne `det-ok` außer `DetMath.isqrt` |

**R2 (Agent B) — neu / geändert**

| Datei | Änderung |
|---|---|
| `scenes/combat/combat_director.gd` (neu) | Lebenszyklus: Start (Auslöser, Formation, `Game.make_rt_setup`), Tick-Akkumulator × `combat_speed_pm`, max. 4 Ticks/Frame, Tick-Grenze (§9.2), Proben, `Game.combat_step`, Ereignisverteilung, Ende (`Game.end_combat`), Flucht/Türen, Steuerungswechsel; Signale `combat_started(sim)`, `combat_event(e)`, `combat_finished(result)` |
| `scenes/combat/unit_puppet.gd` (neu) | stellt eine Sim-Einheit dar (Interpolation, Animationen aus Zustand/Ereignissen) für `EnemyActor`, Begleiter und Autopilot |
| `scenes/combat/move_sampler.gd` (neu) | Proben nach §3.5.1 |
| `scenes/combat/telegraph_layer.gd` (neu) | Quad-Pool, Instanz-Uniforms (§8.7) |
| `scenes/combat/combat_fx.gd` (neu) | Ereignisse → `Vfx`, `Sfx`, Kamerawackeln, Kampftext-Aufrufe |
| `scenes/combat/boss_intro.gd` (neu) | §2.9 |
| `art/shaders/rt_telegraph.gdshader` (neu) | §8.7 |
| `scenes/exploration/exploration.gd`, `enemy_actor.gd`, `player_controller.gd`, `companion_follower.gd`, `camera_rig.gd`, `encounter_rules.gd`, `interactable.gd` (M3) | Auslöser §2.2, Puppenmodus, Kampfsperren, Formation/Komparsen-Pool, Kamera §7.5, `control(member_id)`-Aufruf der Heldenwahl |
| `autoload/game.gd` (M0), Abschnitt „Echtzeitkampf (07, R2)“ | `in_combat`, `combat`, `make_rt_setup`, `combat_submit`, `combat_step`, `end_combat`, `controlled_member_id`; `is_timer_ticking()` false im Kampf |
| `art/kit/character_rig.gd` (M4) | Animationen `channel` (Schleife), `stunned` (Schleife), `interrupted` (0,4 s) |
| `autoload/sfx_synth.gd` (M0) | Klänge `rt_cast_ding`, `rt_interrupt_scratch`, `rt_dodge_ooh`, `rt_telegraph_warn`, `rt_train_horn`, `rt_show_ready`, `rt_door_shut` |
| `tests/test_r2_combat_world.gd`, `test_r2_move_sampler.gd`, `test_r2_telegraph_layer.gd`, `test_r2_boss_intro.gd` (neu) | Tests §12.4 |
| `tests/perf/perf_runner.gd` (M0, additiv) | Szenarien `combat_regular`, `combat_boss_queen` |

**R3 (Agent C) — neu / geändert**

| Datei | Änderung |
|---|---|
| `scenes/combat/ui/combat_hud.gd` + `combat_hud.tscn`, `action_bar.gd`, `unit_frames.gd`, `nameplates.gd`, `cast_bar.gd`, `status_row.gd`, `combat_input.gd`, `target_picker.gd`, `combat_touch.gd`, `item_wheel.gd`, `combat_results.gd` (neu) | HUD und Eingabe (§7, §8); `CombatInput` erzeugt Befehle und übergibt sie an `CombatDirector.submit(cmd)` |
| `art/shaders/ui_cooldown_sweep.gdshader` (neu) | §8.2 |
| `project.godot` (M0), nur `[input]` | §7.7 |
| `autoload/game_settings.gd` (M0) | §7.8 |
| `autoload/events.gd` (M0) | `signal dialog_layout_requested(mode: StringName, layout: Dictionary)`; Kommentar Modus `&"combat"` |
| `scenes/ui/mod_dialog.gd`, `show_overlay.gd`, `exploration_hud.gd`, `touch_controls.gd`, `settings_menu.gd`, `input_glyph.gd`, `skills_menu.gd`, `ui_icon.gd`, `icon_mesh.gd` (M6) | Untertitel-Modus, Overlay `combat`, Ausblenden im Kampf, Touch-Kampfmodus, Einstellungen, Glyphen, Leisten-/Varianten-/Taktik-Menü, Fähigkeits- und Status-Symbole |
| `art/kit/vfx.gd` (M4) | Kampftext-Stile `rt_*` (§8.6) |
| `tests/test_r3_action_bar.gd`, `test_r3_combat_input.gd`, `test_r3_touch_layout.gd`, `test_r3_hud_layout.gd` (neu) | Tests §12.4 |

**R4 (Agent D) — neu / geändert**

| Datei | Änderung |
|---|---|
| `data/skills.json`, `statuses.json`, `enemies.json`, `items.json`, `party.json`, `floors.json`, `mod_lines.json` (M7) | `rt`-Blöcke, neue Einträge (§4.11), Tutorial-Override, Boss-Spot Königin |
| `core/data/data_validator.gd` (M0) | Vokabulare + Regeln §4.10 (R5 ergänzt danach nur `TRIGGER_PAYLOAD_KEYS`) |
| `core/rt/rt_balance.gd` (R1) | nur Konstantenwerte |
| `art/kit/set_builder.gd` (M4) | Gleis-9-Bühne (Gleise, Waggon, Tunnelportale) |
| `tests/tools/rt_harness_main.gd`, `rt_harness.gd`, `rt_bot_player.gd`, `../tools/rt_balance.sh` (neu) | §11.4, §5.7 |
| `tests/test_r4_rt_data.gd`, `test_r4_rt_balance.gd` (neu) | §12.4 |
| `docs/07_ECHTZEITKAMPF.md` §11.5 | Messwerte |

**R5 (Agent E) — neu / geändert**

| Datei | Änderung |
|---|---|
| `core/show/show_rules.gd`, `sponsor_system.gd`, `stat_ids.gd`, `achievement_tracker.gd` (M2) | Profil `rt` (§9.1), Gewichtungs-Adapter, neue StatIds/Payloads |
| `autoload/show.gd` (M2) | `take_pending_gift_rt`, Profilwahl, Kampfzeilen-Rate (§9.3) |
| `core/live/run_sim.gd`, `run_log.gd` (M8) | RT-Kampf (§10.5), `compact`/`expand` (§10.3) |
| `autoload/game.gd` (M0), Abschnitt `replay_log` | §10.6 |
| `core/data/data_validator.gd` (M0) | `TRIGGER_PAYLOAD_KEYS` (nach R4-Merge) |
| `data/achievements.json` (M7) | optionale neue Achievements (§9.4) |
| `scenes/boot/autoplay.gd`, `fullrun.gd`, `../tools/fullrun.sh`, `../tools/perf.sh` | Autoplay-Schritte, Full-Run im Echtzeitmodus, Perf-Szenarien |
| `tests/test_r5_show_rt.gd`, `test_r5_rt_replay.gd`, `test_r5_gifts_in_combat.gd`, `test_r5_rt_live_equivalence.gd` (neu) | §12.4 |
| `docs/01_GDD.md` §3, `docs/02_TECH.md` §5, `docs/05_LIVE_MODUS.md`, `docs/PERFORMANCE.md`, dieses Dokument | Verweise/Ersatz nach CTB-Entfernung, Messwerte |
| Löschliste §12.5 | CTB-Entfernung (R5b) |

### 12.4 Tests je Phase

| Phase | Test | Prüft |
|---|---|---|
| R1 | `test_r1_det_math` | Tabellen-Symmetrie, `isqrt` exakt (0…10⁶ Stichprobe + Grenzwerte), `yaw_of` für alle 256 Richtungen ±1, Formen-Tests gegen Gleitkomma-Referenz (im Test erlaubt), Rundungsregeln |
| R1 | `test_r1_rt_timing` | GCD 45 / Turbo 34 / Minimum 30, Schwungtakt 60/72, Zauber 45 + Bewegungsabbruch, Queue-Fenster 9, GCD-freie Aktionen, Gegenstand-Abklingzeit 600, Wirkzeitpunkte, Unterbrechungs-Sperre 60, SHOW/FINALE geteilte Abklingzeit |
| R1 | `test_r1_rt_threat` | Kai × 1,5, Wuchtschlag × 2, Heil-Bedrohung geteilt, Spott Spitze × 1,1 + Fixierung 120, Wechsel bei 110 %, Gleichstand, K.O. löscht |
| R1 | `test_r1_rt_status` | Gift-Stapel (3, Periode 60, min 1), `refresh`/`replace`/`ignore`, Ausschlüsse, Betäubung unterbricht, Boss-Betäubung × 0,5, Überrumpelt blockiert, Erholung, `cleanse`, Immunität/Widerstand (geseedet), Stapel als Kopien |
| R1 | `test_r1_rt_ai` | Regelreihenfolge, `first_ms`/`every_ms`, Bedingungen, Ziele (zufällige reproduzierbar), Slot-Versatz, Phasen + Ops, Enrage, Unerreichbar-Regel, alle Presets (Heilschwelle, Unterbrechen-Schalter), Autopilot, `suggest` |
| R1 | `test_r1_rt_telegraph` | alle Formen/Anker, Einschlag nur im Einschlag-Tick, Ausweichen + knapp, Pflichtprobe-Semantik (Sim-Seite), Zonen-Takte, Unterbrechen entfernt Telegraph, `MAX_TELEGRAPHS` |
| R1 | `test_r1_rt_move` | Koppelnavigation geschlossen, Prüfung + `POS_CORRECTED`, `project_walkable`, Abstoßung, Formation, Flucht nach 60 Ticks, Rauch, verschlossenes Set |
| R1 | `test_r1_rt_result` | `BattleResult` (EXP, Credits, Overkill neu, Beute, Diebstahl/Erstattung, Party-HP, Kills, K.O.s, `group_ids`, Zähler), Doppel-K.O. = Sieg, Tutorial-HP ≥ 1 |
| R1 | `test_r1_rt_mods` | Vokabular-Prüfung, statische Mods, `on`-Reaktionen, Twist-Tabelle |
| R1 | `test_r1_rt_golden` | festes Setup + ~200 geskriptete Befehle → `StateHash.of_rt` und Ereignisanzahl gleich festen Golden-Werten; zweimal laufen = gleich; geänderte Golden-Werte nur mit Begründung im Commit |
| R1 | `test_r1_rt_int_only` | §3.14 Regel 1 |
| R1 | `test_r1_regen` | RunSim-Schritt 6, Zähler-Reset, Hash-Abdeckung |
| R2 | `test_r2_combat_world` | Pull/ALERT-Start im Raum, Vorteil-Tabelle, Puppen = Sim-Positionen (±1 cm nach Interpolation 1,0), eingefrorene Fremdgruppen, Interaktionssperre, Bosstüren, Flucht 2 s, Sieg entfernt Gruppe, Flucht setzt zurück, Steuerungswechsel/Zuschauermodus |
| R2 | `test_r2_move_sampler` | Schwellen 15 cm / 15 mm/Tick / 8 Stufen / 15 Ticks, Stopp-Probe, Pflichtprobe vor Einschlag |
| R2 | `test_r2_telegraph_layer` | Pool ≤ 10, Instanz-Uniform-Werte je Form, Fortschritt, Farben/Kontrastmodus |
| R2 | `test_r2_boss_intro` | Ablauf, Sim startet erst danach, blockierende Zeile nur hier |
| R3 | `test_r3_action_bar` | Zustände aus der Sim (Abklingzeit, GCD, MP, Reichweite, Queue, Assist, SHOW → FINALE bei Stufe 9 + Hype 85), Leiste wächst mit dem Level |
| R3 | `test_r3_combat_input` | Tasten/Gamepad/Touch → Befehle (inkl. `exact_match` für Shift+Tab), Tab-Reihenfolge, Klick-Auswahl, Kontexttrennung Erkundung/Kampf |
| R3 | `test_r3_touch_layout` | Positionen §7.3, Trefferflächen ≥ 88 px, keine Überlappungen, Safe-Area-Verschiebung, Ticker-Freiraum |
| R3 | `test_r3_hud_layout` | keine Überlappung von Rahmen, Untertitel, Leiste, Bauchbinde bei 1280 × 720 und 1920 × 1080 |
| R4 | `test_r4_rt_data` | Validator-Regeln §4.10 positiv/negativ, alle Etage-1-Inhalte haben `rt` |
| R4 | `test_r4_rt_balance` | Harness-Bänder §11.1 (20 Seeds `typical`) |
| R5 | `test_r5_show_rt` | Hype-Tabelle §9.1 (Unterbrechung, Ausweichen, Langeweile per `SECOND`, Schleppen, perfekte Phase, Combo, Serie, Zug-Kill), CTB-Profil unverändert |
| R5 | `test_r5_rt_replay` | `RunSim.replay` eines RT-Laufs bitgenau, Kampf-Prüfpunkte, Abbruch bei Abweichung, Befehl nach Kampfende = Fehler, `compact`/`expand` verlustfrei |
| R5 | `test_r5_gifts_in_combat` | eingefrorenes Fenster nimmt an, Anwendung an der nächsten Tick-Grenze, Id 0 + `ct`, System-Geschenke ≤ 1/2, Pur-Liga lehnt ab |
| R5 | `test_r5_rt_live_equivalence` | geskripteter Live-Lauf ≡ `Game.replay_log` (Hashes, Prüfpunkte, Show-Zahlen, FINALE-Prüfung) |
| R5 | `test_m6_autoplay` (angepasst) | Schritte `force_battle` → `force_combat` (60 Frames), `battle` → `combat` (900 Frames, Autopilot, `Events.battle_ended` VICTORY) |
| R5 | `test_m6_fullrun` + `tools/fullrun.sh --combat=realtime` | Etage 1 vollständig mit Autopilot (alle Strategien), Zeitbänder |

### 12.5 Parität und CTB-Entfernung

CTB wird entfernt, wenn **alle** Kriterien erfüllt sind:

1. Full-Run Etage 1 im Echtzeitmodus (`thorough`, `rush`, `dawdle`, `typical`) besteht auf 50 Seeds ≥ 95 % (Bossniederlagen mit
   anschließendem Erfolg zählen als bestanden).
2. Harness: alle Bänder §11.1 erreicht (200 Seeds `typical`), Bossverlust-Quoten in 10–30 % bzw. 25–45 %.
3. Show-Zahlen der Full-Runs (Hype, Geschenke, Follower, Zuschauer) in den GDD-§13-Bändern.
4. 20 aufgezeichnete Echtzeit-Läufe (mit Geschenken, Twists, Flucht, Niederlage) werden von `RunSim.replay` (Kernläufe) bzw.
   `Game.replay_log` (Live-Läufe) bitgenau reproduziert.
5. Performance: Budgets §8.10 in `combat_regular` und `combat_boss_queen` auf Profil `high` und `low`; Sim §3.15.
6. Touch-Layout in Captures geprüft (1280 × 720, 1920 × 1080, Notch-Insets); Gamepad- und Tastaturbelegung vollständig.
7. Jedes Achievement der Etage 1 ist im Echtzeitmodus erreichbar (Bot-Lauf oder gezielter Test je Achievement).
8. Spielstände: neue Saves im Echtzeitmodus; Migration v1 (`ctb`) → v2 (HP × 4, `combat_mode` entfällt) getestet.
9. Keine offenen P1-Fehler; Nutzerfreigabe nach Probespiel.

Danach (R5b), in dieser Reihenfolge, je ein Commit:

1. Standard `combat_mode = realtime`; Einstellungseintrag entfernt.
2. **Daten backen:** `party.json` Basis-HP/HP-Wachstum × 4, feste Heilungen/Schäden × 4, `enemies.json` `stats.hp` = Echtzeit-HP,
   `rt.power`/`rt.mp`/`rt.statuses` → Hauptfelder; Skala-Code (`hp_scale_pm`, `FIXED_SCALE_PM`, `ENEMY_HP_PM`) entfernt;
   `SaveCodec.VERSION = 2` mit Migration (v1: HP × 4).
3. **Löschen:** `core/battle/ctb_queue.gd`, `battle_state.gd`, `action_resolver.gd`, `enemy_ai.gd`, `auto_policy.gd`,
   `battle_command.gd`; `scenes/battle/` vollständig (`battle.tscn`, `battle_scene.gd`, `battle_controller.gd`, `battle_player.gd`,
   `battle_stage.gd`, `battle_camera.gd`, `status_fx.gd`, `portrait_gallery.*`, `ui/*`; `train_fx.gd` vorher nach
   `scenes/combat/` übernehmen, falls die Zug-Darstellung ihn nutzt); `Router.start_battle`/`end_battle` + Swirl-Kampfübergang;
   `Events.battle_turn_started`; CTB-Datenfelder (§4.11) samt Validator-Regeln; `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN`;
   `GameSettings.battle_speed`, `auto_battle_default` (→ Autopilot); CTB-Tests (`test_m1_ctb`, `test_m1_battle_flow`,
   `test_m1_ai`, `test_m1_battle_snapshot`, `test_m5_*`, CTB-Teile von `test_m6_*`, `test_m8_replay`, `test_m8_run_sim`)
   durch Echtzeit-Varianten ersetzt; `StateHash.of_battle`; `ShowRules`-Profil `ctb`.
4. **Doku:** 01_GDD §3 und 02_TECH §5 durch Verweise auf 07 ersetzen; 05 §3.4 (CTB-Lockstep) und §10.6 (Kampf-Commands) auf
   07 §10 umstellen; PERFORMANCE.md neu messen.

### 12.6 Unverändert wiederverwendet

Schadensformel (`DamageCalc`, GDD §3.7), `Elements`, `StatBlock`, Krit/Varianz/Element-Konstanten in `Balance`, EXP-Kurve,
Stufenwachstum (außer HP-Skala), `Combatant` (Basisklasse), `StatusEffect` (Basisklasse), `HitResult`, `BattleSetup`
(Basisklasse), `BattleResult` (erweitert), `BattleBridge.apply_result`, Beute (`LootRoller`, Drops), Show (ShowModel,
SponsorSystem-Schwellen, Gifts, GiftPolicy, GiftApplier, SponsorWindows, Achievements, M.O.D.-Ansager), Save (additiv),
Erkundung (Wahrnehmung, Patrouillen, Streuner, Kamera), Art-Kit (`CharacterRig` + neue Animationen, `CharacterBuilder`,
`Vfx`, `icon_mesh`), `Sfx`, `RunSim`/`RunLog`/`StateHash`/`Command` (erweitert), `SeedUtil`, `FixedMath`, `CanonicalJson`, alle
Datentabellen (um `rt` erweitert).

### 12.7 Änderungen an bestehenden Verträgen (Übersicht)

| Dokument | Abschnitt | Änderung |
|---|---|---|
| 02_TECH | §2.2 Input-Map | §7.7 |
| 02_TECH | §3.2 Events | `dialog_layout_requested`; Overlay-Modus `combat` |
| 02_TECH | §3.4 Game | Echtzeit-API §10.6, `controlled_member_id` |
| 02_TECH | §3.5 Show | `take_pending_gift_rt`, ShowRules-Profil |
| 02_TECH | §4 Daten | `rt`-Blöcke §4.6–4.9, Validator §4.10 |
| 02_TECH | §5 Kampf-Kern | ersetzt durch 07 §3 (mit R5) |
| 02_TECH | §6.4 Save | additive Felder; v2 mit R5 |
| 02_TECH | §7.3 Erkundung | Auslöser/Vorteil §2.2 |
| 02_TECH | §11 Autoplay/Full-Run | §12.4 |
| 02_TECH | §12 Budgets | §8.10 (unverändert, neue Szenarien) |
| 01_GDD | §2.3/2.4 | Kampfauslöser, Vorteil §2.2 |
| 01_GDD | §3 Kampf | ersetzt durch 07 (mit R5) |
| 01_GDD | §4.2 | HP × 4 nach dem Backen |
| 01_GDD | §5 Gegner/Bosse | Echtzeit-Fassung §6 |
| 01_GDD | §7 Show | Hype-Tabelle §9.1 |
| 05_LIVE | §3.4, §10.6 | Echtzeit-Befehle mit `ct`, Kampf-Prüfpunkte (§10) |
| 03_ART | §8, §9 | Telegraph-Farben, Kampf-HUD-Elemente, Decal-Befund |

---

## 13. Risiken und offene Punkte

### 13.1 Risiken

| Nr. | Risiko | Gegenmaßnahme |
|---|---|---|
| 1 | Client-autoritative Bewegung erlaubt in Ligen Manipulation (z. B. „perfektes“ Ausweichen per Tool) | Tempo-/Sprungprüfung in der Sim, Ausreißer-Statistik im Verifier, später server-autoritativ (§10.8) |
| 2 | Lesbarkeit auf kleinen Bildschirmen: Telegraphen unter Figuren/Requisiten, Kamera im Weg | Fußpunkt-Regel, Kontrastmodus, Kamera-Zoom im Kampf, Requisiten nur am Rand, Capture-Reviews; Gerätetest |
| 3 | Mobile-Leistung mit 6 Rigs + 10 Quads + HUD | Budgets §8.10, Perf-Szenarien ab R2, Komparsen-Pool, Rig-LOD als Reserve |
| 4 | Balance-Verschiebung durch HP-Skala, Regeneration, Taktung | Harness mit Bändern als CI-Test, Stellschrauben §11.2 |
| 5 | Partner-KI wirkt dumm oder übermächtig | einfache, datengetriebene Regeln; Reaktionszeiten je Taktik; Probespiel |
| 6 | Abhängigkeit von der Heldenwahl (Laufzeit-Umschaltung) | Schnittstelle `control(member_id)` früh festlegen; Ersatz Zuschauermodus |
| 7 | Zwei Kampfpfade bis R5 | ein Schalter, wenige Verzweigungspunkte (§12.1), CTB-Tests als Gate |
| 8 | Log-Größe durch Proben | Schwellen, Kompaktierung, gzip (§10.3) |
| 9 | Hype-Ökonomie: mehr Ereignisse pro Minute | kleinere RT-Werte, Messung gegen GDD §13 in R5 |
| 10 | Determinismus-Lücken (Dictionary-Reihenfolge, Gleitkomma aus Daten, Iteration) | Lint, Int-only-Test, Golden-Hash, Replay-Tests |
| 11 | Parallele Agenten an geteilten Dateien | Eigentümer je Phase, additive Abschnitte, Merge-Reihenfolge §12.3 |
| 12 | Plattformgleichheit von `RandomNumberGenerator` (PCG32) — hier nicht prüfbar (nur Linux-Binary) | Replay-Test plattformübergreifend in CI, sobald Windows/Android-Läufer existieren; Golden-Werte (Anhang A) als Referenz |
| 13 | Spieler steht in Requisiten-Ecken außerhalb der Sim-Fläche | Unerreichbar-Regel (§3.5.3) |

### 13.2 Offene Punkte (Entscheidungen der Nutzerin/des Nutzers bzw. Probespiel)

| Nr. | Frage | Vorschlag dieses Dokuments |
|---|---|---|
| O1 | Spieltempo unter 100 % in Liga-/Event-Läufen erlauben? | Nein (Regel `speed_pm_min` 1000), Kampagne frei |
| O2 | Pause im Kampf bei Live-Läufen | Offline ja (Sim tickt nicht); Live-Läufe: keine Pause im Kampf (05 `realtime`-Logik), vor 05 S4 entscheiden |
| O3 | Regeneration außerhalb des Kampfes (1 % HP / 2 % MP je 3 s) | Startwert, Probespiel |
| O4 | FINALE-Bedingung Hype ≥ 85 im Client statt in der Sim | so lassen (Hype entsteht außerhalb des Kerns); Replay prüft |
| O5 | „Steuerung folgt dem Leben“ vs. Zuschauermodus bei K.O. | Steuerungswechsel; nach Probespiel bestätigen |
| O6 | Etage-2-Boss „Der Ausverkauf“ mit Zähler-Mechanik | Entwurf bestätigen, bevor Etage 2 gebaut wird |
| O7 | Neue Achievements (Unterbrechen, Ausweichen, Zug-Kill, perfekte Phase) | aufnehmen |
| O8 | Tiefentest der Telegraphen (Requisiten verdecken Teile) | an lassen; Capture-Review in R2 |
| O9 | Koop: Eingangspuffer 2 Ticks, Lag-Kompensation 200 ms | erst mit 05 S4 festlegen |
| O10 | Musikwechsel bei sehr kurzen Kämpfen | Kampfmusik erst nach 3 s Kampf oder bei Bossen sofort; Probespiel |

---

## Anhang A: Engine-Prüfprotokoll

Binary: `Godot Engine v4.7.2.stable.official` (Ausgabe `Engine.get_version_info()["string"]` = `4.7.2-stable (official)`).
Umgebung: Linux, Xvfb; Compatibility = OpenGL 3.3-Pfad auf llvmpipe (GL 4.5, Mesa 25.2.8); Mobile = Vulkan 1.4 lavapipe
(Forward Mobile). Wegwerf-Projekte nur im Scratchpad (`rt-design-probe/`), nicht im Repository.

| Nr. | Fakt | Methode | Ergebnis (geprüft) |
|---|---|---|---|
| A1 | `Decal` in Compatibility | Boden + Decal (rote Textur), Pixel in der Decal-Mitte gelesen | **nicht gezeichnet** (#969696 = Bodenfarbe); Mobile: gezeichnet (#bd1919), kein zusätzlicher Draw Call |
| A2 | Spatial-Shader-Quad mit `instance uniform vec4` × 2 | Telegraph-Shader §8.7 auf `QuadMesh`, Pixel gefüllt/ungefüllt/außen | beide Renderer korrekt (Compatibility #d3734c / #b38572 / #969696; Mobile #c25c48 / #8f5f58 / #606060); Boden + Quad = 2 Draw Calls |
| A3 | Canvas-Instanz-Uniforms (`CanvasItem.set_instance_shader_parameter`) | zwei `ColorRect` mit einem gemeinsamen `ShaderMaterial`, verschiedene Werte | korrekt in beiden Renderern, **1** Draw Call |
| A2b | Shader-Texte dieses Dokuments (§8.2, §8.7) | wörtlich aus dem Dokument extrahiert, kompiliert, Quad (Kreis, Fortschritt 0,5) über grauem Boden + Sweep (`cd_left` 0,5) gerendert | beide Renderer fehlerfrei; Telegraph-Mitte #b95252 (Compatibility) / #cf5252 (Mobile) gegen Boden #595959; Sweep links abgedunkelt, rechts unverändert |
| A3b | Produktions-Sweep-Shader (§8.2, transparente Basis) | 6 `ColorRect` mit geteiltem Material über hellem Hintergrund, `cd_left` 0,5 / `gcd_left` 1,0 | beide Renderer: linke Hälfte #58555d (abgedunkelt), rechte Hälfte #e6e6e6 (= Hintergrund), Ring #fafafa, Ruhezustand transparent; Canvas-Draw-Calls 2 |
| A4 | Draw Calls HUD-Bausteine (`RenderingServer.viewport_get_render_info`, Canvas) | Messszenen, beide Renderer gleich | leer 0; 6 Sweeps (geteiltes Material) 1; + 6 Labels ohne Outline 2; + 6 Labels Outline 4 px 13; 6 Sweeps + 12 Labels ohne Outline 2; 6 `TextureProgressBar` radial 6; 6 × `draw_colored_polygon` 6; 1 × `canvas_item_add_triangle_array` für 6 Slots 1; 8 Plaketten `PanelContainer`+`ProgressBar` 24; 8 Plaketten als Dreiecks-Array + 8 Labels 2 |
| A5 | `Label3D` (Billboard, Outline 8) | 8 Stück | Compatibility 16 Draw Calls, Mobile 8 |
| A6 | Klassen/Methoden vorhanden | Headless `ClassDB`/`has_method` | `Decal`, `TextureProgressBar`, `Label3D`, `MultiMeshInstance3D`, `AnimationTree`, `InputEventScreenTouch/Drag`, `InputEventMagnifyGesture`, `SubViewport`, `CPUParticles3D`; `CanvasItem.set_instance_shader_parameter`, `GeometryInstance3D.set_instance_shader_parameter`, `RenderingServer.canvas_item_add_triangle_array`, `RenderingServer.viewport_get_render_info`, `CharacterBody3D.move_and_slide`, `Camera3D.unproject_position`, `Camera3D.project_ray_origin`, `Input.get_vector`, `Input.action_press`, `Input.parse_input_event`, `DisplayServer.is_touchscreen_available`, `PhysicsDirectSpaceState3D.intersect_ray`, `CanvasItem.draw_colored_polygon`, `CanvasItem.draw_arc` |
| A7 | Tasten-/Gamepad-Konstanten | Ausgabe der Enums | `KEY_1`…`KEY_6` = 49…54, `KEY_TAB` = 4194306, `KEY_G` = 71, `KEY_V` = 86, `KEY_ESCAPE` = 4194305, `KEY_SHIFT` = 4194325; Maus links 1 / rechts 2 / Mitte 3 / Rad 4, 5, `MOUSE_BUTTON_MASK_RIGHT` = 2; Joypad A 0, B 1, X 2, Y 3, Back 4, Guide 5, Start 6, L3 7, R3 8, LB 9, RB 10, Steuerkreuz oben 11 / unten 12 / links 13 / rechts 14; Achsen LX 0, LY 1, RX 2, RY 3, LT 4, RT 5 |
| A8 | Shift+Tab gegen Aktion nur mit Tab | `InputEvent.is_action(action, exact_match)` | `target_next` (Tab): Shift+Tab → `true` ohne, `false` mit `exact_match`; `target_prev` (Shift+Tab) → `true` in beiden; Achsen-Deadzone Standard 0,2; LT 0,8 löst Achsen-Aktion aus |
| A9 | Ganzzahl-Semantik | Skript | `int` 64 Bit mit Überlauf-Wrap; `-7 / 2 == -3`; `-7 % 2 == -1`; `posmod(-7, 2) == 1`, `posmod(-1, 256) == 255`; `const T: PackedInt32Array = [...]` zulässig; `isqrt` per `sqrt(float)` + Korrektur exakt (15 → 3, 2 147 395 600 → 46 340, 10¹² + 1 → 10⁶); `Dictionary.keys()` in Einfügereihenfolge |
| A10 | `RandomNumberGenerator` | `seed = 12345`, 5 × `randi_range(0, 9999)` | `[6956, 9747, 8241, 8820, 3406]` (Golden-Referenz für plattformübergreifende Prüfung, Risiko 12) |
| A11 | Physik-Takt | `ProjectSettings` | `physics/common/physics_ticks_per_second` Standard 60 |
| A12 | Nicht prüfbar hier | — | Plattformgleichheit von Jolt/`CharacterBody3D` (wird nicht in der Sim verwendet), echte Mobil-GPUs und Touch-Geräte, Windows/macOS/Android-Binaries |

## Anhang B: Glossar

| Begriff | Bedeutung |
|---|---|
| Set | Raumzelle des Kampfes |
| ct | Kampf-Tick (30/s) |
| GCD | globale Abklingzeit (1,5 s) nach Fähigkeiten mit `gcd` |
| Queue-Fenster | 300 ms, in denen ein Tastendruck vorgemerkt wird |
| Telegraph | angekündigte Bodenfläche mit Warnzeit |
| Zone | bleibende Bodenfläche mit periodischer Wirkung |
| Fixierung | erzwungenes Ziel eines Gegners (Spott) |
| Komparsen | Gruppenmitglieder, die beim Kampfstart ins Bild springen |
| Probe | aufgezeichnete Position/Geschwindigkeit der gesteuerten Figur |
| Koppelnavigation | Fortschreiben der Position aus der letzten Probe |
| Pull | Kampfbeginn durch eine Fähigkeit auf ein Ziel |
| Assist | Vorschlags-Anzeige der nächsten sinnvollen Fähigkeit |
| Autopilot | die Sim spielt die gesteuerte Figur |
| SHOW / FINALE | Stunt-Taste mit Risiko und Hype / ihre Stufe-9-Form ab Hype 85 |
