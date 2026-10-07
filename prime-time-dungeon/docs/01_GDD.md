# PRIME TIME DUNGEON — Game Design Document (Vertical Slice)

> Grundlage: `00_BRIEF.md` (verbindlich). Dieses Dokument legt **Spielregeln und Zahlen** fest.
> Umfang: **Etage 1 komplett**, **Etage 2 angelegt (Stub)**, **Klassenwahl ab Etage 3 datenseitig vorbereitet**.
> Alle IDs, JSON-Keys, Signal- und Methodennamen sind Englisch und hier **kanonisch**: Die Dateien in `res://data/`
> verwenden exakt diese IDs. Spieltexte (Namen, Beschreibungen, Sprüche) sind Deutsch und laufen über `tr()`-Keys.
> Alle Zahlen sind simuliert (Monte-Carlo, 400 Kämpfe je Gruppe, einfache KI) und als Startwerte für Playtests gesetzt.

---

## Inhalt

1. Story & Figuren
2. Erkundung
3. Kampf (CTB)
4. Party: Werte, Wachstum, EXP, Fähigkeiten
5. Gegner & Bosse Etage 1
6. Items & Ausrüstung
7. Show-System
8. Achievements
9. Lootboxen
10. Safe Room
11. M.O.D. — Stimme & Sprüche
12. Klassensystem (ab Etage 3)
13. Balancing-Ziele
14. UX-Flows
15. Etage 2 (Stub)
16. Anhang: Datei-Zuordnung & Konstanten

---

## 1. Story & Figuren

### 1.1 Prämisse (Kurzfassung)

Das galaktische Medienkonglomerat **NOVA SYNDIKAT** „baut“ die Erdoberfläche zurück, um Platz für seine
Erfolgsshow **DUNGEON PRIME TIME** zu schaffen. Wer überlebt, fällt in den Dungeon und wird **Kandidat:in**.
Jede Etage hat einen Countdown; wer die Treppe nicht rechtzeitig findet, fliegt raus — endgültig.

### 1.2 Figuren

| ID | Name | Rolle | Kern | Sprechweise |
|---|---|---|---|---|
| `kai` | **Kai** (frei benennbar, max. 12 Zeichen) | Spielfigur, Nahkampf/Tank | Tierpfleger:in im Tierheim „Pfotenglück“, Nachtschicht. Pragmatisch, trocken, kümmert sich zuerst um andere. Kämpft mit Improvisiertem (Wischmopp, Rohrzange). | Kurze Sätze, lakonisch. Flucht nie, Witze manchmal. |
| `mopsula` | **Graf Mopsula** | Begleiter, Magier/Heiler | Mops, 9 Jahre, Zwingerschild: „Graf — schwer vermittelbar“. Kann im Dungeon sprechen, hält sich für Hochadel, entpuppt sich als Magier. Arrogant, eitel, loyal bis in die Knochen. Publikumsliebling. | Gestelzt, Pluralis Majestatis („Wir sind not amused“), nennt Kai „Kammerdiener:in“. |
| `mod` | **M.O.D.** (Mediale Omnipräsente Direktorin) | System-KI, Moderatorin | Quotengeil, regelversessen, sarkastisch, heimlich sentimental. Kommentiert alles. Nie direkt grausam zu Kai, aber gnadenlos ehrlich über die Quote. | Moderationston, Werbeunterbrechungen, Paragrafen. Siehe Kap. 11. |
| — | **NOVA SYNDIKAT** | Konzern, unsichtbar | Tritt nur über Logos, Sponsor-Drohnen, Kleingedrucktes und Werbeplakate auf. Kein Gesicht im Slice. | Corporate-Sprech, Disclaimer. |
| `boss_hausmeister` | **Der Hausmeister** | Quartier-Boss | Ehemaliger Hausmeister des U-Bahn-Komplexes, vom Dungeon „übernommen“: 3 m groß, grauer Kittel, Schlüsselbund, besessen von der Hausordnung. Hält Kandidat:innen für Mieter mit Rückständen. | „§ 7 Absatz 2: Kein Lärm nach 22 Uhr!“ |
| `boss_rattenkoenigin` | **Die Rattenkönigin von Gleis 9** | Etagenboss (optional) | Riesenratte auf einem Thron aus einem entgleisten U-Bahn-Wagen. Ihr Schwanz ist mit sechs kleineren Ratten verknotet (echter „Rattenkönig“). Krone aus gelochten Fahrscheinen. Herrscht über die Unterstadt. | Hochmütig, spricht von „Wir“ — Mopsula fühlt sich provoziert („Es kann nur EINEN Adel geben“). |

### 1.3 Etage 1 — „Die Unterstadt“

**Thema:** verlassene unterirdische Stadtschicht. U-Bahn-Bahnsteige, Kanalisation, Kellergewölbe.
Natriumdampf-Orange, Notausgangs-Grün, nasse Fliesen in Petrol, Graffiti in Magenta.

**Layout:** festes Raster **8 × 8 Zellen à 12 m** (Daten in `floors.json`, Modul-Deko per Seed). 31 belegte Zellen.

| Zone | ID | Zellen | Inhalt |
|---|---|---|---|
| A | `zone_platform` „Bahnsteig Nord“ | 8 | Start, Tutorial, Safe Room 1 „Kiosk“, 4 Gegnergruppen, 1 Fahrscheinfresser, 4 Truhen, 2 Events |
| B | `zone_sewer` „Kanalisation“ | 9 | 4 Gegnergruppen, 5 Truhen, 2 Events, Safe Room 2 „Pumpenhaus“ (Grenze B/C) |
| C | `zone_cellar` „Kellergewölbe“ | 8 | 3 Gegnergruppen, 4 Truhen (1 verschlossen), 1 Event, **Hausmeister-Büro** (Quartier-Boss) |
| D | `zone_track9` „Gleis 9“ | 6 | Tor (benötigt `key_master`), 3 Gegnergruppen, 3 Truhen (1 verschlossen), Safe Room 3 „Stellwerk“, **Thronsaal** (Etagenboss), **Treppe** |

### 1.4 Story-Beats Etage 1

| # | Beat | Ort / Auslöser | Inhalt | Ergebnis |
|---|---|---|---|---|
| B0 | **Intro** (Cutscene, ~90 s, Halten 1 s = überspringen) | Spielstart | Nachtschicht im Tierheim-Keller. Kai füttert den Mops „Graf“. Der Himmel wird zum Bildschirm, NOVA-SYNDIKAT-Logo, Gebäude falten sich weg („Rückbau“). Boden bricht. M.O.D. moderiert an: „Willkommen bei DUNGEON PRIME TIME! Sie sind live.“ Der Mops öffnet das Maul: „Endlich. Man versteht Uns.“ | Party gebildet. Kai hält Wischmopp (`wpn_mop`). |
| B1 | **Tutorial-Gang** | Zone A, Zellen 1–2 | Bewegung, Kamera, Feldschlag, Schleichen (M.O.D.-Textboxen, je max. 2 Zeilen). Zwei schlafende Kanalratten (Gruppe `grp_a1_tutorial`, Zustand `IDLE`, drehen sich nie um). | Erzwingt den ersten Präventivschlag. |
| B2 | **Erster Kampf** | `grp_a1_tutorial` | Geführte Hinweise: Zugreihenfolge-Leiste, Angriff, Fähigkeit (Adelsflamme), Stunt-Hinweis nach Zug 2. Kann nicht verloren werden (Gegner-Schaden ×0.5, Flucht gesperrt). | Achievements `ach_first_blood` + `ach_first_win` → 2 Bronze-Boxen. **Countdown startet** nach diesem Kampf („Die Uhr läuft!“). |
| B3 | **Erster Safe Room** „Kiosk 24/7“ | Zone A | Heilen, Speichern, Automat, Bronze-Boxen öffnen (Tutorial), Mopsula-Szene 1. | Spieler versteht Loop. |
| B4 | **Kanalisation** | Zone B | Rattenschamanen raunen: „Die Königin hört von euch.“ Event „Verdächtiger Hebel“ öffnet Abkürzung nach C. | Foreshadowing Rattenkönigin. |
| B5 | **Quartier-Boss: Der Hausmeister** | Zone C, Büro | Türschild „Zutritt nur für Personal“. Cutscene: Er stempelt einen Mahnbescheid auf Kai. Kampf mit 3 Phasen. | Drop `key_master` (Generalschlüssel) → Tor zu Gleis 9 offen. Silber-Box. Mopsula-Szene 2 beim nächsten Safe Room. |
| B6 | **Gleis 9** | Zone D | Treppe sichtbar hinter dem Bahnsteig. Seitlich: Thronsaal im entgleisten Wagen. M.O.D. lockt: „Die Zuschauer wollen die Königin. Die Treppe läuft nicht weg. Die Uhr schon.“ | Wahl: Treppe sofort nehmen ODER Etagenboss. |
| B7 | **Etagenboss: Die Rattenkönigin von Gleis 9** (optional) | Thronsaal | Mopsula vs. Königin Adels-Streit, 3 Phasen inkl. „Einfahrender Zug“. | Gold-Box, `acc_queen_crown`, großer Follower-Schub. |
| B8 | **Ende: „Etage 2 folgt“** | Treppe | Etagen-Bilanz (Zeit, Kills, Zuschauer-Peak, Follower, Achievements). M.O.D.: „Nach der Werbung: Etage 2.“ Teaser-Kamerafahrt (Rolltreppe in eine versunkene Einkaufspassage). Autosave in neuen Etagen-Save. Abspann → Titel. | Slice-Ende. |

**Hinweis Optionalität:** Der Hausmeister ist **Pflicht** (Generalschlüssel). Die Rattenkönigin ist **optional**,
aber M.O.D. bewirbt sie aggressiv; ohne sie fehlen Gold-Box, Krone und ~250 Follower.

### 1.5 Etage 2 — Thema (Stub, Details Kap. 15)

„**Passage Ewiger Rabatt**“: versunkene Einkaufspassage unter der Unterstadt. Rolltreppen ins Nichts,
Schaufensterpuppen, Food-Court mit Pilzbewuchs, Dauer-Durchsagen „Nur heute!“.

---

## 2. Erkundung

### 2.1 Spielfigur & Begleiter

| Parameter | Wert |
|---|---|
| Laufgeschwindigkeit (Standard) | **5.5 m/s** |
| Schleichen (halten: Shift / LT / Touch-Toggle) | **2.5 m/s**, Hör-Radius der Gegner ×0.375 (4.0 → 1.5 m) |
| Beschleunigung / Abbremsen | 30 m/s² / 40 m/s² |
| Drehgeschwindigkeit Modell | Slerp 12 rad/s zur Bewegungsrichtung |
| Kollision | `CapsuleShape3D` r = 0.4 m, h = 1.7 m |
| Springen | keins |
| **Feldschlag** (Taste E / X-Button / Touch „A“) | Bogen 100°, Reichweite 1.8 m, Dauer 0.45 s, Cooldown 0.6 s |
| Interagieren | dieselbe Taste, wenn ein Interactable im Radius 1.5 m und im 120°-Kegel liegt (Interact hat Vorrang vor Schlag) |
| Mopsula folgt | Zielabstand 1.8 m hinter Kai (NavigationAgent3D), Teleport, wenn > 10 m entfernt |

### 2.2 Kamera

| Parameter | Wert |
|---|---|
| Typ | `SpringArm3D` an Pivot (Kai + 1.4 m Höhe) |
| Armlänge | Standard **6.0 m**, Zoom 4.0–9.0 m (Mausrad / Pinch) |
| Pitch | Standard −22°, Grenzen −55° … −5° |
| Yaw | frei |
| Empfindlichkeit | Maus 0.15°/px, Stick 150°/s, Touch-Drag 0.25°/px |
| Auto-Recenter | nach 2.5 s ohne Kamera-Eingabe während Bewegung, Lerp 2.0/s hinter Kai |
| FOV | 65° |
| Kollisionsabstand | 0.25 m |
| Follow-Glättung | Position Lerp 10/s |

### 2.3 Gegner auf der Karte (Symbol-Gegner)

Jedes sichtbare Gegner-Modell auf der Karte ist ein **Gruppensymbol** (`EncounterGroup`). Das Modell zeigt
den Anführer (erster Eintrag der Gruppe); kleine Schatten-Icons über dem Kopf zeigen die Gruppengröße (1–4).

| Zustand | Verhalten |
|---|---|
| `IDLE` | Steht, dreht sich alle 4 s um ±60° |
| `PATROL` | Läuft Wegpunkte ab, **1.8 m/s** |
| `ALERT` | Bleibt stehen, „!“-Sprechblase, **0.6 s** Telegraph, dann `CHASE` |
| `CHASE` | Verfolgt mit `field_speed` des Gegnertyps (Tabelle Kap. 5) |
| `RETURN` | Zurück zum Leash-Punkt mit 3.0 m/s; ignoriert Spieler 2 s |

| Wahrnehmung | Wert |
|---|---|
| Sichtweite / Sichtkegel | **10 m / 110°** (Raycast für Sichtlinie), Taubenschwarm 14 m |
| Hör-Radius | **4.0 m** beim Laufen, **1.5 m** beim Schleichen (360°) |
| Aufgeben der Verfolgung | 4 s ohne Sichtkontakt ODER > **20 m** vom Leash-Punkt ODER 8 s Gesamtverfolgung |
| Kontakt-Radius (löst Kampf aus) | **1.1 m** |
| Schonfrist nach Kampf / Flucht | Kai 2.0 s unverwundbar & unsichtbar; Gegner im Radius 6 m gehen in `RETURN` |

### 2.4 Kampfauslösung & Erstschlag

Kampf startet bei Kontakt (Symbol berührt Kai) oder Feldschlag-Treffer auf ein Symbol.
Zur Gruppe gehören **alle Gegner des Symbols**; zusätzlich schließen sich **keine** weiteren Symbole an (klare Regel, lesbar).

Begriffe: `fwd_e` = Blickrichtung Gegner, `fwd_k` = Blickrichtung Kai, `d_ek` = normierte Richtung Gegner→Kai,
`d_ke` = Richtung Kai→Gegner. **Rücken-Schwelle:** `dot < -0.34` (≙ Winkel > 110°).

| Ergebnis | Bedingung (in dieser Reihenfolge geprüft) | Effekt im Kampf |
|---|---|---|
| **Präventivschlag** (`preemptive`) | Feldschlag trifft Symbol UND (`state` ∈ {`IDLE`,`PATROL`} ODER `dot(fwd_e, d_ek) < -0.34`) | Party startet mit `ctr = 0`, Gegner mit `ctr = base_delay` (voller Zug). Hype +5. Flucht +25 %. |
| **Hinterhalt** (`ambush`) | Symbol berührt Kai, Symbol im `CHASE` UND `dot(fwd_k, d_ke) < -0.34` (Gegner kommt von hinten) | Gegner starten mit `ctr = 0`, Party mit `ctr = base_delay`. Hype +8 (Drama). |
| **Normal** | alles andere | Alle `ctr = roundi(base_delay × rng.randf_range(0.5, 1.0))` |

Bosse: immer **Normal** (Cutscene-Start). Fahrscheinfresser: kann nie Hinterhalt auslösen (steht still).

### 2.5 Truhen

| Typ | ID | Anzahl E1 | Inhalt | Öffnen |
|---|---|---|---|---|
| Holzkiste | `chest_wood` | 10 | 20–40 Credits (gleichverteilt) + 1 Wurf aus Lootbox-Pool `common` | 0.6 s Animation |
| Metallspind | `chest_metal` | 4 | 1 fester Inhalt (in `floors.json`): Ausrüstung oder 2× Verbrauchsitem `rare` | 0.8 s |
| Verschlossener Spind | `chest_locked` | 2 | benötigt `key_master`; fester Inhalt: `wpn_fire_axe` (Zone C) und `wpn_collar_crown` (Zone D) | 1.0 s |

Jede geöffnete Truhe: Hype +3, Zähler `s.chests_opened` +1. Truhen bleiben im Spielstand geöffnet (`floor_flags`).

Feste Metallspind-Inhalte E1: `arm_safety_vest` (A), `wpn_collar_studded` (B), `item_smelling_salts` ×2 (B), `acc_gas_mask` (C).

### 2.6 Events (Interactables mit Wahl, je 1× pro Etage)

| ID | Name | Zone | Wahl / Ablauf | Ergebnis |
|---|---|---|---|---|
| `evt_photo_drone` | Kamera-Drohne „Lächeln!“ | A | **Posieren** / **Zertreten** | Posieren: Hype +15, Follower +20. Zertreten: +30 Credits, Hype −5, M.O.D. beleidigt. |
| `evt_lost_candidate` | Herr Brettschneider in der Telefonzelle | A | **Heilitem geben** (beliebiges `heal`-Item) / **Weitergehen** | Geben: erhält `acc_lucky_ticket`, Follower +40. Weitergehen: nichts, M.O.D.-Spruch. |
| `evt_wheel` | Glücksrad von DoomScroll+ | B | **Drehen (20 Cr)** / **Ignorieren** | Gewichte: 35 `item_bandage`×2 · 25 +50 Cr · 15 Bronze-Box · 15 Niete („Werbepause“) · 10 Kampf `grp_evt_pigeons` (2× Taubenschwarm, normal). Mehrfach drehbar, max. 3×. |
| `evt_lever` | Verdächtiger Hebel | B | **Ziehen** / **Lassen** | 60 %: Abkürzung B→C öffnet (spart ~90 s Laufweg). 40 %: Flutwelle, alle 15 % MaxHP Schaden, danach Kampf `grp_evt_slime` (2× Kanalschleim). |
| `evt_broken_vending` | Kaputter Automat | C | **Treten** / **Lassen** | Erfolg `0.50 + Kai.LCK × 0.01`: 2× `item_energy_krawumm`. Misserfolg: Stromschlag, Kai −10 % MaxHP, Hype +4. |

Event abgeschlossen: Hype +5, `s.events_completed` +1.

### 2.7 Streuner (Nachschub zum Grinden)

Zonen A und B haben je einen Spawner `spawn_stray`: Wenn in der Zone **kein** Streuner lebt, erscheint nach
**90 s Erkundungszeit** eine neue Gruppe aus dem Zonen-Pool (A: `grp_a2`/`grp_a4`, B: `grp_b1`/`grp_b2`) an
einem Spawnpunkt außerhalb der Sichtweite von Kai. Grinden kostet also Timer — gewollter Trade-off.

### 2.8 Treppe & Etagenende

- Treppe `stairs_f1` steht in Zone D hinter dem Tor (benötigt `key_master`).
- Interagieren → Bestätigung: „Etage verlassen? Offene Truhen und der Etagenboss bleiben zurück.“ [Abstieg] [Noch nicht]
- Abstieg: Timer stoppt → Etagen-Bilanz → Autosave in neuen Datensatz (Etage 2, Kap. 15) → Slice: Abspann.

### 2.9 Etagen-Timer

| Regel | Wert |
|---|---|
| Startwert Etage 1 | **20:00** (Modus „Vorabendprogramm“: 30:00) |
| Start | nach Tutorial-Kampf (B2) |
| Läuft nur in | Erkundung. **Pausiert** in Kampf, Safe Room, Menüs, Cutscenes, Dialogen, Lootbox-Öffnen |
| Warnung 10:00 | Chat-Ticker-Meldung, kein M.O.D. |
| Warnung 5:00 | M.O.D. `timer_warning_5`, Musik-Layer „Tension“, Timer-HUD orange, Hype +10 (einmalig) |
| Warnung 1:00 | M.O.D. `timer_warning_1`, Timer rot pulsierend, Alarm, alle 10 s leichter Screenshake (0.15 Stärke, 0.3 s) und Deckenputz-VFX, Hype +15 (einmalig) |
| 0:10 | Piep pro Sekunde |
| **0:00** | **Etagenkollaps**: 3 s Einsturz-Cutscene (M.O.D. `timer_zero`) → **Game Over** (Ursache `timer`) |
| Gnadenfrist beim Laden | Beim Laden eines Spielstands gilt `timer = max(timer_saved, 180 s)` — verhindert Softlock |

---

## 3. Kampf (CTB — Conditional Turn-Based)

### 3.1 Grundprinzip

Jede Einheit hat einen Zähler `ctr: int` (Ticks bis zum nächsten Zug). Es handelt immer die Einheit mit dem
kleinsten `ctr`. Nach ihrer Aktion bekommt sie einen neuen `ctr` abhängig von **SPD** und **Rang** der Aktion.

### 3.2 Formeln (kanonisch)

```text
TICK_K      = 1000
TICK_OFFSET = 10

base_delay(spd)  = roundi(TICK_K / (spd + TICK_OFFSET))
status_mult      = 0.6 bei haste, 1.5 bei slow, sonst 1.0   (haste und slow schließen sich aus: neues ersetzt altes)
delay(unit, rank)= max(1, roundi(base_delay(unit.spd_eff) * rank / 3.0 * status_mult))
```

| SPD | 5 | 7 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 19 | 20 | 25 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `base_delay` | 67 | 59 | 53 | 50 | 48 | 45 | 43 | 42 | 40 | 38 | 37 | 34 | 33 | 29 | 25 |

**Aktionsränge** (Feld `rank` in Skills/Items):

| Rang | Faktor | Verwendung |
|---|---|---|
| 2 | ×0.67 | Item, Verteidigen, Flucht, leichte Heilung/Buffs |
| 3 | ×1.00 | Angriff, Standard-Fähigkeiten |
| 4 | ×1.33 | starke Fähigkeiten, Stunts |
| 5 | ×1.67 | Finisher, Gegner-Spezialangriffe |
| 6 | ×2.00 | Boss-Ultimates |

(Rang 1 = ×0.33 ist reserviert für spätere Klassen-Passiva, im Slice ungenutzt.)

### 3.3 Ablauf

```text
battle_start:
  for u in units: u.ctr = start_ctr(u, encounter_type)        # 2.4
loop:
  actor = argmin(ctr) mit Tie-Break: Party vor Gegner → höhere SPD → kleinerer Slot-Index
  dt = actor.ctr; for u in alive_units: u.ctr -= dt
  turn_start(actor):  Verteidigen endet; poison tickt (8 % MaxHP, min 1, kann töten); Phasenprüfung Boss
  action(actor)       # Spieler wählt / KI wählt
  turn_end(actor):    Statusdauern des Akteurs −1 (Status mit 0 entfernt); actor.ctr = delay(actor, action.rank)
  check victory/defeat; Show.evaluate(action_result)
```

- Status-Dauern zählen **eigene Züge** des Trägers (Ausnahme `stun`, s. 3.8).
- Tote Einheiten fallen aus der Zugliste. Wiederbelebte bekommen `ctr = base_delay` (voller Zug).
- Hinzugerufene Einheiten (Summons) bekommen `ctr = roundi(base_delay × 0.5)`.

### 3.4 Zugreihenfolge-Vorschau

- Rechte Bildschirmkante, **12 Einträge** (Desktop/Gamepad), **10 Einträge** (Touch). Eintrag 1 = aktueller Akteur (groß).
- Algorithmus: Kopie aller `ctr`-Werte, dann 12× „nächsten Akteur ziehen“ simulieren. Für den **aktuellen Akteur**
  wird der **Rang der gerade markierten Aktion** verwendet (`pending_rank`), für alle anderen Rang 3.
- **Ziel-Vorschau:** Ist eine Aktion mit `stun`/`slow`/`haste` markiert und ein Ziel ausgewählt, zeigt die Leiste die
  verschobene Position des Ziels als **Geist-Icon** (50 % Alpha) — wie FF10.
- Pseudo-Einheiten (Zug der Rattenkönigin, Kap. 5.3) erscheinen in der Leiste mit eigenem Icon.

```gdscript
func preview(n: int, pending_rank: int, hypothetical: Dictionary = {}) -> Array[StringName]:
    # hypothetical: { unit_id: ctr_override } für Ziel-Vorschau
    var sim: Dictionary = {}  # unit_id -> ctr
    ...
    # Akteur bekommt delay(actor, pending_rank) nach seinem ersten Eintrag, danach rank 3
```

### 3.5 Befehle

| Befehl | ID | Rang | Wirkung |
|---|---|---|---|
| **Angriff** | `attack` | 3 | Einzelziel, `power 100`, `physical`, Skalierung STR |
| **Fähigkeit** | `skill` | lt. Skill | Liste der freigeschalteten Skills (Kap. 4.5), MP-Kosten |
| **Item** | `item` | 2 | Verbrauchsitem aus Inventar (Kap. 6.1) |
| **Stunt** | `stunt` | 4 | Charakter-Stunt (Kap. 3.6), kein MP, **Cooldown 3 eigene Züge** |
| **Verteidigen** | `defend` | 2 | Schaden ×0.5 bis zum eigenen nächsten Zug; stellt `max(2, ceili(MaxMP × 0.05))` MP wieder her |
| **Flucht** | `flee` | 2 | Fluchtversuch (3.10), bei Bossen ausgegraut |

### 3.6 Stunts (Kern-USP im Kampf)

Riskante Show-Aktion: Erfolg = viel Schaden + viel Hype; Fehlschlag = Peinlichkeit, aber trotzdem etwas Hype.

| ID | Charakter | Name | Ziel | Erfolg | Wirkung bei Erfolg | Fehlschlag |
|---|---|---|---|---|---|---|
| `stunt_kai_suplex` | Kai | **Bahnsteig-Suplex** | 1 Gegner | `0.60 + LCK × 0.01`, max 0.85 | `power 230`, `physical`, STR, kann kritisch treffen | Kai erleidet 10 % MaxHP, `ctr += roundi(base_delay × 0.5)` („liegt auf dem Rücken“) |
| `stunt_mop_entrance` | Mopsula | **Auftritt Seiner Durchlaucht** | alle Gegner | `0.55 + LCK × 0.01`, max 0.85 | `power 140`, `fire`, MAG | Mopsula stolpert über den Umhang: Status `stun` auf sich selbst |

Gegen Bosse: Erfolgschance −0.15. Hype: Erfolg +20, Fehlschlag +8 (Kap. 7).

### 3.7 Schaden & Heilung

```text
# Schaden (Angriff, Skills, Stunts)
A = (scaling == "str") ? STR + weapon.atk : MAG + weapon.mag
D = (scaling == "str") ? DEF + armor.def  : RES + armor.res
if target.has(guard): D *= 1.5
raw = A * A / (A + D) * power / 100.0
raw *= rng.randf_range(0.9, 1.1)
if crit: raw *= 1.5                      # nur scaling "str"
raw *= affinity_mult(target, element)    # weak 1.5 | normal 1.0 | resist 0.5 | immune 0.0
if target.defending: raw *= 0.5
if combo_second_hit: raw *= 1.1          # Kap. 7.3
dmg = (affinity == immune) ? 0 : max(1, roundi(raw))

# Kritisch
crit_chance = clamp(0.05 + LCK * 0.005 + equip.crit_bonus + skill.crit_bonus, 0.0, 0.40)

# Fixschaden (Items, Zug, Prozentschaden): ignoriert A/D und Varianz, beachtet Affinität und Verteidigen
fixed_dmg = roundi(value * affinity_mult * (0.5 if defending else 1.0))

# Heilung
heal_mode "mag":   roundi((MAG * 1.5 + 10) * power / 100.0 * rng.randf_range(0.95, 1.05))
heal_mode "pct":   roundi(MaxHP * power / 100.0)
heal_mode "fixed": power
revive:            HP = roundi(MaxHP * power / 100.0)  (nur auf KO-Ziele)
```

- Treffer verfehlen **nie** (keine Ausweichwerte im Slice).
- HP 0 → KO. KO-Party-Mitglieder stehen nach gewonnenem Kampf mit **1 HP** wieder auf.
- Statuseffekt-Chance: `chance × (1 − target.status_resist[status])`; Bosse haben `stun 0.5`, `slow 0.5`.

### 3.8 Elemente & Affinitäten

Elemente: `physical`, `fire` (Feuer), `ice` (Eis), `shock` (Blitz), `poison` (Gift). Heil-/Support-Aktionen: `none`.
Affinitäten pro Einheit als Dictionary, nicht genannte = `normal`:

| Affinität | Faktor | UI-Popup |
|---|---|---|
| `weak` | 1.5 | „SCHWACHSTELLE!“ (gelb) |
| `normal` | 1.0 | — |
| `resist` | 0.5 | „RESISTENT“ (grau) |
| `immune` | 0.0 | „IMMUN“ (weiß); `immune` gegen `poison` blockt auch den Status `poison` |

### 3.9 Statuseffekte (genau 6)

| ID | Name | Dauer | Wirkung | Quelle (Beispiele) | Icon-Farbe |
|---|---|---|---|---|---|
| `poison` | Vergiftet | 4 eigene Züge | Zugbeginn: −8 % MaxHP (min 1). Heilung durch `item_antidote`, `kai_first_aid`, `mop_mass_lick` | Gift-Skills | #7CC242 |
| `stun` | Betäubt | bis zum nächsten eigenen Zug | Beim Anlegen sofort `ctr += base_delay` (Bosse: ×0.5). Solange aktiv: nicht erneut betäubbar. | `kai_cable_whip`, Stunt-Fehlschlag | #F5D90A |
| `slow` | Verlangsamt | 3 eigene Züge | `delay × 1.5` | `kai_leash_trip`, `mop_frost_sneeze`, Spinnennetz | #5B8DEF |
| `haste` | Turbo | 3 eigene Züge | `delay × 0.6` | `mop_royal_decree`, Sponsor KRAWUMM | #FF7A1A |
| `guard` | Gepanzert | 3 eigene Züge | DEF und RES ×1.5 in der Schadensformel | `kai_taunt`, Sponsor Panzerkeks | #9AA7B8 |
| `taunt` | Provoziert | 3 eigene Züge | Gegner-KI wählt mit 80 % den Träger als Ziel (nur Einzelziel-Aktionen) | `kai_taunt` | #E8455A |

Neu angelegter gleicher Status setzt die Dauer zurück (stapelt nicht). Verteidigen ist **kein** Status.

### 3.10 Flucht

```text
flee_chance = clamp(0.40 + (avg_spd_party - avg_spd_enemies) * 0.03
                    + 0.15 * failed_flee_attempts_this_battle
                    + (0.25 if preemptive else 0.0), 0.10, 0.95)
```

- Boss: 0 (Befehl ausgegraut, Tooltip: „Die Regie lässt das nicht zu.“).
- `item_smoke` = 100 % (nicht bei Bossen).
- Erfolg: Kampf endet ohne EXP/Credits/Drops; Gegner-Symbol bleibt auf der Karte (`RETURN`); Hype −30; Follower −1 %.
- Fehlschlag: Zug verbraucht (Rang 2), Hype −5.

### 3.11 Gegner-KI (datengetrieben)

Jeder Gegner hat in `enemies.json` ein Feld `ai` mit gewichteten Aktionen:

```json
"ai": {
  "type": "weighted",
  "actions": [
    { "skill": "e_bite",        "weight": 3, "target": "random" },
    { "skill": "e_gnaw_poison", "weight": 1, "target": "not_status:poison" },
    { "skill": "e_rat_heal",    "weight": 5, "target": "ally_lowest_hp_pct", "cond": { "ally_hp_below": 0.5 } }
  ]
}
```

| Bedingung (`cond`) | Bedeutung |
|---|---|
| `self_hp_below: f` / `self_hp_above: f` | eigener HP-Anteil |
| `ally_hp_below: f` | mind. ein Verbündeter (inkl. selbst) darunter |
| `turn_mod: [n, r]` | `own_turn_count % n == r` (erster eigener Zug = 0) |
| `allies_alive_below: n` | weniger als n lebende Gegner (für Beschwörungen) |
| `once: true` | max. 1× pro Kampf |
| `mp_min` | implizit: Aktion nur, wenn MP ≥ Kosten |

| Ziel-Regel (`target`) | Bedeutung |
|---|---|
| `random` | zufälliges lebendes Party-Mitglied |
| `lowest_hp_pct` | Party-Mitglied mit niedrigstem HP-Anteil |
| `highest_hp` | höchste absolute HP |
| `not_status:<id>` | zufällig unter denen ohne Status; sonst `random` |
| `self` / `all_enemies` (=Party) / `all_allies` / `ally_lowest_hp_pct` | selbsterklärend |

**Auswahl:** Aktionen filtern (Bedingungen + MP) → gewichteter Zufall mit Kampf-`RandomNumberGenerator`.
**Taunt-Override:** Bei Einzelziel und Party-Mitglied mit `taunt`: 80 % dieses Ziel.
**Bosse:** `ai.type = "phased"`, Liste `phases` mit `hp_above` (Phase gilt, solange HP-Anteil > Wert),
eigenem `actions`-Array und `on_enter` (freie Aktion ohne `ctr`-Änderung: Spruch-Key, Buff, Beschwörung).
Phasenwechsel wird nach **jedem Schadensereignis** geprüft und sofort vollzogen (max. 1 Wechsel pro Ereignis).

### 3.12 Kampfende & Belohnung

- **Sieg:** EXP (volle Summe für jedes lebende Mitglied, KO-Mitglieder 50 %), Credits, Drops (jeder Gegner würfelt
  einzeln, `chance × (1 + avg_party_LCK / 100)`), Follower-Konvertierung (Kap. 7.6), **„Werbepause-Regeneration“**:
  alle lebenden Mitglieder +15 % MaxMP (`ceili`).
- **Niederlage** (alle KO): Game Over „Sendeschluss“ (Kap. 14.6).
- **Kampfgeschwindigkeit:** Option ×1 / ×2 (Animationen), Taste Tab / R3 / Touch-Button „»“.

---

## 4. Party

### 4.1 Werte-Formel

```text
stat(L) = floori(base + growth * (L - 1)) + Ausrüstung
```

Level-Up: HP/MP steigen um die Differenz (aktuelle Werte + Delta), **keine** Vollheilung. Level-Cap im Slice: **10**.

### 4.2 Basiswerte L1 & Wachstum

| Stat | Kai Basis | Kai Wachstum | Mopsula Basis | Mopsula Wachstum |
|---|---|---|---|---|
| HP | 64 | 9.0 | 42 | 6.0 |
| MP | 12 | 2.0 | 30 | 4.0 |
| STR | 12 | 2.0 | 5 | 0.6 |
| MAG | 5 | 0.6 | 13 | 2.2 |
| DEF | 9 | 1.5 | 6 | 0.8 |
| RES | 6 | 0.8 | 11 | 1.6 |
| SPD | 11 | 0.5 | 14 | 0.6 |
| LCK | 8 | 0.5 | 12 | 0.7 |

Ergebniswerte (ohne Ausrüstung):

| L | Kai HP/MP/STR/MAG/DEF/RES/SPD/LCK | Mopsula HP/MP/STR/MAG/DEF/RES/SPD/LCK |
|---|---|---|
| 1 | 64/12/12/5/9/6/11/8 | 42/30/5/13/6/11/14/12 |
| 3 | 82/16/16/6/12/7/12/9 | 54/38/6/17/7/14/15/13 |
| 5 | 100/20/20/7/15/9/13/10 | 66/46/7/21/9/17/16/14 |
| 7 | 118/24/24/8/18/10/14/11 | 78/54/8/26/10/20/17/16 |
| 8 | 127/26/26/9/19/11/14/11 | 84/58/9/28/11/22/18/16 |
| 10 | 145/30/30/10/22/13/15/12 | 96/66/10/32/13/25/19/18 |

**Startausrüstung:** Kai `wpn_mop`, `arm_hoodie`, kein Accessoire. Mopsula `wpn_collar_leather`, `arm_pug_sweater`.
**Startinventar:** 3× `item_bandage`, 1× `item_antidote`, **50 Credits**.

### 4.3 EXP-Kurve

```text
exp_to_next(L) = floori(15 * pow(L, 1.7) + 15)      # L = aktuelles Level, gilt für L1..L9
```

| Level | EXP bis nächstes | EXP gesamt (Beginn des Levels) |
|---|---|---|
| 1 | 30 | 0 |
| 2 | 63 | 30 |
| 3 | 112 | 93 |
| 4 | 173 | 205 |
| 5 | 246 | 378 |
| 6 | 330 | 624 |
| 7 | 424 | 954 |
| 8 | 529 | 1378 |
| 9 | 643 | 1907 |
| 10 | — (Cap) | 2550 |

EXP-Überschuss am Cap verfällt. Beide Mitglieder haben **getrennte** EXP-Konten (wegen KO-Regel), starten gleich.

### 4.4 Skill-Datenfelder

`id, name_key, desc_key, owner, unlock_level, mp, power, rank, target, element, scaling, heal_mode, status, status_chance, status_turns, crit_bonus, hype_tags`

`target` ∈ `enemy`, `all_enemies`, `ally`, `all_allies`, `self`, `ko_ally`.

### 4.5 Fähigkeiten Kai (8)

| L | ID | Name | MP | Power | Rang | Ziel | Element | Skal. | Effekt / Beschreibung |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `kai_heavy_swing` | Wuchtschlag | 3 | 160 | 4 | `enemy` | physical | str | „Mit voller Wucht. Und schlechter Haltung.“ |
| 2 | `kai_taunt` | Hier spielt die Musik! | 2 | 0 | 2 | `self` | none | — | `taunt` 3 + `guard` 3 auf sich. „Kai zieht alle Blicke auf sich.“ |
| 3 | `kai_sweep` | Rundumfeger | 5 | 80 | 3 | `all_enemies` | physical | str | „Einmal durchwischen, bitte.“ |
| 4 | `kai_first_aid` | Erste Hilfe (Tierarzt-Edition) | 4 | 30 | 2 | `ally` | none | pct | Heilt 30 % MaxHP, heilt `poison`. |
| 5 | `kai_leash_trip` | Leinen-Fallstrick | 5 | 70 | 3 | `enemy` | physical | str | `slow` 3, Chance 0.9. |
| 6 | `kai_deo_torch` | Deo-Flammenwerfer | 7 | 130 | 3 | `enemy` | fire | str | „Gesponsert von niemandem. Bitte nicht nachmachen.“ |
| 7 | `kai_cable_whip` | Kabelpeitsche | 8 | 120 | 3 | `enemy` | shock | str | `stun`, Chance 0.35. |
| 9 | `kai_prime_finisher` | Prime-Time-Finisher | 12 | 260 | 5 | `enemy` | physical | str | `crit_bonus +0.20`; Kill damit: Hype +10 extra. |

### 4.6 Fähigkeiten Graf Mopsula (8)

| L | ID | Name | MP | Power | Rang | Ziel | Element | Skal. | Effekt / Beschreibung |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `mop_noble_flame` | Adelsflamme | 4 | 110 | 3 | `enemy` | fire | mag | „Blaues Blut brennt heißer.“ |
| 1 | `mop_holy_lick` | Heiliges Schlabbern | 4 | 100 | 2 | `ally` | none | mag (heal) | Heilung. „Eine Ehre, die keiner wollte.“ |
| 2 | `mop_frost_sneeze` | Frostniesen | 5 | 105 | 3 | `enemy` | ice | mag | `slow` 3, Chance 0.25. |
| 3 | `mop_thunder_bark` | Donnerbellen | 7 | 75 | 3 | `all_enemies` | shock | mag | „WUFF. Mit Hall.“ |
| 4 | `mop_royal_decree` | Königlicher Erlass | 6 | 0 | 2 | `ally` | none | — | `haste` 3. „Wir befehlen: schneller!“ |
| 6 | `mop_mass_lick` | Massen-Schlabbern | 10 | 60 | 3 | `all_allies` | none | mag (heal) | Heilung + heilt `poison`. |
| 7 | `mop_revive` | Sabber der Wiederkehr | 14 | 40 | 4 | `ko_ally` | none | revive | Belebt mit 40 % MaxHP. |
| 9 | `mop_inferno` | Gräfliches Inferno | 14 | 130 | 4 | `all_enemies` | fire | mag | „Für die Ahnen. Alle 300 davon.“ |

---

## 5. Gegner & Bosse Etage 1

### 5.1 Reguläre Gegner (10) + 1 Rarität

Werte sind fest pro Typ (kein Gegner-Level-Scaling im Slice). `Lv` = Richtwert für UI/Bestiarium.

| ID | Name | Lv | HP | MP | STR | MAG | DEF | RES | SPD | LCK | EXP | Cr | `field_speed` | Zone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `kanalratte` | Kanalratte | 1 | 24 | 0 | 13 | 3 | 5 | 3 | 13 | 5 | 12 | 6 | 4.8 | A, B |
| `taubenschwarm` | Taubenschwarm | 2 | 20 | 0 | 12 | 4 | 3 | 6 | 19 | 8 | 14 | 5 | 6.2 | A |
| `pendler` | Pendler (ewig verspätet) | 2 | 48 | 0 | 17 | 2 | 8 | 4 | 7 | 3 | 22 | 14 | 3.5 | A |
| `kanalschleim` | Kanalschleim | 2 | 40 | 10 | 12 | 12 | 10 | 4 | 9 | 3 | 20 | 8 | 3.0 | B |
| `rattenschamane` | Rattenschamane | 3 | 34 | 30 | 9 | 16 | 6 | 12 | 12 | 6 | 26 | 12 | 4.5 | B, D |
| `kabelsalat` | Kabelsalat | 3 | 46 | 20 | 14 | 17 | 12 | 10 | 14 | 5 | 30 | 15 | 4.0 | B, C |
| `kellerspinne` | Kellerspinne | 4 | 50 | 10 | 22 | 6 | 10 | 8 | 17 | 10 | 34 | 12 | 5.8 | C |
| `spruehgeist` | Sprühgeist | 4 | 44 | 40 | 8 | 23 | 18 | 10 | 15 | 8 | 36 | 18 | 5.0 | C |
| `rolltreppenkrabbe` | Rolltreppenkrabbe | 5 | 72 | 0 | 25 | 4 | 24 | 8 | 10 | 4 | 60 | 20 | 3.8 | D |
| `rattengardist` | Rattengardist | 6 | 78 | 10 | 27 | 6 | 17 | 10 | 14 | 8 | 66 | 22 | 5.0 | D |
| `fahrscheinfresser` | Fahrscheinfresser (Rarität) | 4 | 60 | 0 | 18 | 18 | 20 | 20 | 16 | 20 | 60 | 150 | 0 (steht) | A |

**Affinitäten & Drops:**

| ID | weak | resist | immune | Drops (`item: chance`) |
|---|---|---|---|---|
| `kanalratte` | fire | — | — | `item_bandage: 0.25`, `item_antidote: 0.10` |
| `taubenschwarm` | shock | — | — | `item_bandage: 0.20` |
| `pendler` | fire | poison | — | `item_energy_krawumm: 0.15` |
| `kanalschleim` | fire | physical | poison | `item_antidote: 0.30` |
| `rattenschamane` | fire | shock | — | `item_energy_krawumm: 0.25`, `item_smelling_salts: 0.05` |
| `kabelsalat` | ice | fire | shock | `item_energy_krawumm: 0.15`, `acc_rubber_boots: 0.05` |
| `kellerspinne` | fire | — | poison | `item_antidote: 0.30`, `item_bandage: 0.20` |
| `spruehgeist` | ice | physical | poison | `item_ice_spray: 0.20`, `item_hype_megaphone: 0.05` |
| `rolltreppenkrabbe` | shock | physical, ice | — | `item_brutzel_burger: 0.20`, `arm_safety_vest: 0.05` |
| `rattengardist` | fire, ice | — | — | `item_brutzel_burger: 0.20`, `item_smelling_salts: 0.10` |
| `fahrscheinfresser` | shock | physical | poison | `acc_lucky_ticket: 0.50` |

**Gegner-Skills:**

| ID | Name | Power | Rang | Ziel | Element | Skal. | MP | Effekt |
|---|---|---|---|---|---|---|---|---|
| `e_bite` | Biss | 100 | 3 | enemy | physical | str | 0 | — |
| `e_gnaw_poison` | Seuchennagen | 80 | 3 | enemy | poison | str | 0 | `poison` 0.35 |
| `e_peck` | Picken | 90 | 3 | enemy | physical | str | 0 | — |
| `e_dive_bomb` | Sturzflug-Bombardement | 60 | 4 | all_enemies | physical | str | 0 | — |
| `e_briefcase` | Aktentaschen-Hieb | 100 | 3 | enemy | physical | str | 0 | — |
| `e_delay_rage` | Verspätungswut | 150 | 5 | enemy | physical | str | 0 | — |
| `e_slam` | Klatscher | 100 | 3 | enemy | physical | str | 0 | — |
| `e_toxic_splash` | Giftspritzer | 90 | 3 | enemy | poison | mag | 2 | `poison` 0.50 |
| `e_zap` | Funkenrute | 100 | 3 | enemy | shock | mag | 3 | — |
| `e_rat_heal` | Rattensegen | 30 | 2 | ally | none | pct | 5 | Heilung 30 % MaxHP |
| `e_lash` | Kabelhieb | 100 | 3 | enemy | physical | str | 0 | — |
| `e_short_circuit` | Kurzschluss | 80 | 4 | all_enemies | shock | mag | 6 | — |
| `e_venom_bite` | Giftbiss | 90 | 3 | enemy | poison | str | 0 | `poison` 0.50 |
| `e_web` | Netzschuss | 0 | 3 | enemy | none | — | 2 | `slow` 0.80 |
| `e_spray_flame` | Farbflamme | 110 | 3 | enemy | fire | mag | 4 | — |
| `e_fumes` | Lackdämpfe | 60 | 4 | all_enemies | poison | mag | 6 | `poison` 0.30 |
| `e_pinch` | Zwicken | 100 | 3 | enemy | physical | str | 0 | — |
| `e_brace` | Stufen fahren hoch | 0 | 2 | self | none | — | 0 | `guard` 2 |
| `e_step_crush` | Stufen-Stampfer | 170 | 5 | enemy | physical | str | 0 | — |
| `e_halberd` | Hellebarde | 100 | 3 | enemy | physical | str | 0 | — |
| `e_shield_wall` | Schildwall | 0 | 3 | all_allies | none | — | 4 | `guard` 3 |
| `e_lunge` | Ausfall | 140 | 4 | enemy | physical | str | 0 | — |
| `e_ticket_cut` | Entwerter-Biss | 120 | 3 | enemy | physical | str | 0 | — |
| `e_fine` | Erhöhtes Beförderungsentgelt | 0 | 3 | enemy | none | — | 0 | Party verliert `min(40, credits)` Credits; Rückgabe bei Sieg |
| `e_escape` | Abfahrt! | 0 | 2 | self | none | — | 0 | verlässt den Kampf (keine Belohnung für ihn) |

**KI-Muster:**

| Gegner | Aktionen (Gewicht, Ziel, Bedingung) | Spielidee |
|---|---|---|
| `kanalratte` | `e_bite` 3 random · `e_gnaw_poison` 1 `not_status:poison` | Lernziel: Gift & Gegengift |
| `taubenschwarm` | `e_peck` 3 `lowest_hp_pct` · `e_dive_bomb` 1 all | Schnell, fokussiert Schwache → Blitz nutzen |
| `pendler` | `e_briefcase` 3 random · `e_delay_rage` 10 random `turn_mod [3,2]` | Telegraph: jeder 3. Zug hart → Verteidigen lernen |
| `kanalschleim` | `e_slam` 2 random · `e_toxic_splash` 2 `not_status:poison` | Physisch resistent → Feuer lernen |
| `rattenschamane` | `e_bite` 1 · `e_zap` 2 random · `e_rat_heal` 6 `ally_lowest_hp_pct` `ally_hp_below 0.5` | Heiler → zuerst töten |
| `kabelsalat` | `e_lash` 2 random · `e_short_circuit` 10 all `turn_mod [3,1]` | Flächenschaden alle 3 Züge |
| `kellerspinne` | `e_venom_bite` 3 `not_status:poison` · `e_bite` 1 · `e_web` 2 `not_status:slow` `once` | Schnell + Debuff |
| `spruehgeist` | `e_spray_flame` 3 random · `e_fumes` 1 all · `e_slam` 1 | Physisch resistent → Mopsula Eis |
| `rolltreppenkrabbe` | `e_brace` 10 self `turn_mod [3,0]` · `e_step_crush` 10 `highest_hp` `turn_mod [3,1]` · `e_pinch` 3 random | Rhythmus: Panzern → Stampfen → Zwicken |
| `rattengardist` | `e_shield_wall` 10 `once` (wenn ≥ 2 Gegner leben) · `e_lunge` 2 `lowest_hp_pct` · `e_halberd` 3 random | Elite, schützt Gruppe |
| `fahrscheinfresser` | `e_fine` 10 `once` · `e_ticket_cut` 3 · `e_escape` 100 `turn_mod [4,3]` | Muss in 3 eigenen Zügen sterben |

**Visuelle Beschreibung (Primitive + Toon-Shader, Outline, Farben als Hex):**

| ID | Aufbau | Farben | Animation |
|---|---|---|---|
| `kanalratte` | Kapsel-Körper (0.6 m lang, liegend), Kugel-Kopf mit Kegel-Schnauze, 2 Kugel-Ohren, Zylinder-Schwanz (3 Segmente, gebogen), rote Kugel-Augen emissive | #6B5B4E Fell, #E88A9A Ohren/Schwanz, Augen #FF3030 | Hoppel-Bob 4 Hz, Schwanz-Sinus |
| `taubenschwarm` | 5 kleine Tauben (Kugel-Körper + Kegel-Schnabel + 2 flache Box-Flügel), kreisen um gemeinsamen Pivot | #8C93A6, Hals #5FA38E metallic, Schnabel #E0A040 | Orbit 1.2 rad/s, Flügel-Flap 8 Hz |
| `pendler` | Hohe Kapsel (1.9 m) leicht vornübergebeugt, Box-Aktentasche, Kopf = Box (Zeitung gefaltet) mit Kreis-Uhr-Decal, Zylinder-Krawatte | Anzug #4A4F5A, Hemd #D9D9D9, Krawatte #B33A3A, Uhr #FFFFFF | Schlurfen, alle 3 s auf Armbanduhr schauen |
| `kanalschleim` | Deformierte Kugel (Vertex-Shader Wobble), darin 2–3 Müllteile (Dose = Zylinder, Box) halbtransparent | #6FBF4A Alpha 0.75, Rim #C8FF7A | Squash & Stretch 1.5 Hz |
| `rattenschamane` | Kanalratte aufrecht (Kapsel stehend 0.9 m), Umhang = Kegel, Stab = Zylinder mit emissive Kugel (Glühbirne), Kronkorken-Kette (Torus-Reihe) | Fell #5A4A40, Umhang #3E2F5B, Glühbirne #FFE66B emissive | Stab-Glühen pulsiert |
| `kabelsalat` | Knäuel aus 8 Zylinder-Segment-Ketten um Kugel-Kern, Kern = Steckdose (Box mit 2 Löchern), Funken-Partikel | Kabel #1E1E1E/#D93B3B/#3B6FD9, Kern #CFCFCF, Funken #9FE8FF | Kabel peitschen (Sinus pro Segment) |
| `kellerspinne` | Kugel-Hinterleib (0.8 m), Kugel-Kopf, 8 Beine aus je 2 Zylindern, 6 Augen-Kugeln emissive | #2B2B33, Muster #C2453A, Augen #FFB000 | Prozeduraler Gang (Bein-Paare phasenversetzt) |
| `spruehgeist` | Schwebende Sprühdose (Zylinder + Kugel-Kappe) mit Gesicht, Schweif aus 6 Quad-Partikeln „Farbnebel“ | Dose #E23E9B, Kappe #FFFFFF, Nebel Gradient #E23E9B→#4AD9D9 | Schweben ±0.15 m, Dreh 0.5 rad/s |
| `rolltreppenkrabbe` | Breite Box-Körper aus 5 gestaffelten Stufen-Boxen (Rolltreppe), 2 Scheren aus Kegel-Paaren, 6 Zylinder-Beine | Stufen #8A8F96 mit gelben Kanten #F2C230, Scheren #B84A2E | Stufen laufen (UV-Scroll), Scheren klappen |
| `rattengardist` | Kanalratte aufrecht 1.4 m, Helm = halbe Kugel + Kegel-Spitze, Schild = Box mit Kronen-Decal, Hellebarde = Zylinder + Box-Klinge | Fell #4D3F36, Rüstung #A8B0B8 metallic, Wappen #7A1F9E | Wache-Idle, Schild-Klopfen |
| `fahrscheinfresser` | Fahrkartenautomat (hohe Box, Display-Quad emissive, Schlitz) — klappt im Kampf Box-Kiefer mit Zahn-Kegeln auf | Gehäuse #2F6FB3, Display #9AF2FF, Zähne #F5F5F0 | Display flackert, Kiefer schnappt |

### 5.2 Boss: Der Hausmeister (`boss_hausmeister`)

| Feld | Wert |
|---|---|
| Lv / HP / MP | 6 / **380** / 60 |
| STR / MAG / DEF / RES / SPD / LCK | 23 / 14 / 14 / 10 / 12 / 6 |
| Affinitäten | weak `shock`, resist `poison` |
| Status-Resistenz | `stun 0.5`, `slow 0.5` |
| EXP / Credits | **180 / 200** |
| Drops (100 %) | `key_master`, `acc_key_ring`, Lootbox `silver` |
| Ziel-Party-Level | **5** (L4 schaffbar mit Items) |

**Skills:** `b_broom` Besenhieb (110, R3, physical, str) · `b_keys` Schlüsselbund-Wurf (70, R4, all_enemies, physical) ·
`b_rules` Hausordnung verlesen (self, `guard` 2, R3) · `b_cleaner_fog` Putzmittelnebel (60, R4, all_enemies, poison, mag, `poison` 0.40, MP 8) ·
`b_call_tenant` „Untermieter!“ (beschwört 1 `kanalratte`, R3, MP 6) · `b_mop_whirl` Wischmopp-Wirbel (90, R3, all_enemies, physical).

| Phase | HP | `on_enter` | Aktionen (Gewicht · Ziel · Bedingung) |
|---|---|---|---|
| P1 „Kehrwoche“ | 100–60 % | Spruch `boss_intro_hausmeister` | `b_rules` 10 self `once` (1. Zug) · `b_broom` 3 random · `b_keys` 1 all |
| P2 „Hausordnung § 7“ | 60–25 % | beschwört 1 `kanalratte`; Spruch `boss_phase_hausmeister_2` | `b_broom` 2 random · `b_cleaner_fog` 2 all · `b_keys` 1 all · `b_call_tenant` 4 `allies_alive_below 2` `turn_mod [4,0]` |
| P3 „Feierabend!“ | < 25 % | `haste` 5 auf sich; Spruch `boss_phase_hausmeister_3` | `b_mop_whirl` 2 all · `b_broom` 2 `lowest_hp_pct` |

**Visuell:** 3.0 m hohe Kapsel (Kittel #7C8A94), Box-Brusttasche mit Kugelschreibern (Zylinder), Kugel-Kopf mit
Box-Schnurrbart und Schirmmütze (Zylinder + flache Box), Schlüsselbund = 12 Torus-Ringe an der Hüfte (klimpern per
Sinus), Besen = langer Zylinder + Box-Bürste. Phase 3: Augen emissive Rot #FF3B30, Dampf-Partikel aus den Ohren.

### 5.3 Boss: Die Rattenkönigin von Gleis 9 (`boss_rattenkoenigin`)

| Feld | Wert |
|---|---|
| Lv / HP / MP | 8 / **720** / 120 |
| STR / MAG / DEF / RES / SPD / LCK | 26 / 20 / 18 / 16 / 15 / 10 |
| Affinitäten | weak `ice`, resist `fire`, immune `poison` |
| Status-Resistenz | `stun 0.5`, `slow 0.5` |
| EXP / Credits | **420 / 500** |
| Drops (100 %) | `acc_queen_crown`, Lootbox `gold`; Achievement `ach_queen` (+ Gold-Box) |
| Ziel-Party-Level | **7** (L6 schaffbar mit guter Ausrüstung + Items) |

**Skills:** `q_scepter` Zepterstoß (120, R3, physical, str) · `q_plague_bite` Pestbiss (90, R3, poison, str, `poison` 0.50) ·
`q_screech` Kreischen der Krone (80, R4, all_enemies, shock, mag, MP 8) · `q_summon` Schwanzknoten lösen (beschwört bis zu 2 `kanalratte`, R3, MP 10) ·
`q_crown_nova` Kronen-Nova (110, R5, all_enemies, shock, mag, MP 16).

**Pseudo-Einheit „Einfahrender Zug“ (`train_gleis9`):** keine HP, nicht anvisierbar, SPD-unabhängig.
Erscheint in der Zugreihenfolge mit Zug-Icon. Wenn er „handelt“: **Fixschaden 35 % MaxHP** jedes Party-Mitglieds
(Element `physical`, halbiert durch Verteidigen, nicht durch `guard`), danach `ctr = 160`. M.O.D.-Warnung
(`boss_train_warning`), sobald der Zug auf Position 2 der Vorschau steht. Lernziel: Vorschau lesen, rechtzeitig verteidigen.

| Phase | HP | `on_enter` | Aktionen |
|---|---|---|---|
| P1 „Hofstaat“ | 100–65 % | beschwört 2 `kanalratte`; Spruch `boss_intro_rattenkoenigin` | `q_scepter` 3 random · `q_plague_bite` 1 `not_status:poison` · `q_summon` 4 `allies_alive_below 3` `turn_mod [3,2]` |
| P2 „Zug fährt ein“ | 65–30 % | `train_gleis9` mit `ctr = 120` einfügen; Spruch `boss_phase_rattenkoenigin_2` | `q_scepter` 3 random · `q_screech` 2 all · `q_plague_bite` 1 |
| P3 „Endstation“ | < 30 % | Zug entgleist: `train_gleis9` entfernt, Königin erleidet 72 Fixschaden (kann sie nicht töten, min 1 HP), `haste` 99 auf sich; Spruch `boss_phase_rattenkoenigin_3` | `q_scepter` 3 `lowest_hp_pct` · `q_plague_bite` 2 · `q_crown_nova` 10 all `turn_mod [4,1]` |

**Visuell:** Riesen-Ratte (Kapsel liegend 3.5 m, Kopf-Kugel 1.2 m) auf entgleistem U-Bahn-Wagen (Box 8×3×3 m,
Fenster-Quads emissive #FFD27A, schief 12°). Krone = Zylinder-Ring aus 10 kleinen Box-„Fahrscheinen“ (#F2E8C9 mit
Loch-Decal). Schwanz: 6 Zylinder-Ketten, an jedem Ende eine Mini-Ratte (Kanalratte ×0.5). Zepter = Zylinder mit
Signallampe (Kugel, wechselt Rot/Grün). Fell #3F3530, Rim-Light Violett #9A6BFF. P3: Krone glüht #FF5A5A.

### 5.4 Begegnungsgruppen Etage 1 (`floors.json → encounters`)

| Gruppe | Zone | Gegner | EXP gesamt | Credits |
|---|---|---|---|---|
| `grp_a1_tutorial` | A | kanalratte ×2 | 24 | 12 |
| `grp_a2` | A | kanalratte, taubenschwarm, kanalratte | 38 | 17 |
| `grp_a3` | A | pendler, taubenschwarm | 36 | 19 |
| `grp_a4` | A | taubenschwarm ×2, kanalratte | 40 | 16 |
| `grp_a_rare` | A | fahrscheinfresser | 60 | 150 |
| `grp_b1` | B | kanalschleim, kanalratte ×2 | 44 | 20 |
| `grp_b2` | B | rattenschamane, kanalratte ×2 | 50 | 24 |
| `grp_b3` | B | kabelsalat, kanalschleim | 50 | 23 |
| `grp_b4` | B | kanalschleim ×2, rattenschamane | 66 | 28 |
| `grp_c1` | C | kellerspinne ×2 | 68 | 24 |
| `grp_c2` | C | spruehgeist, kabelsalat | 66 | 33 |
| `grp_c3` | C | kellerspinne, spruehgeist, kanalratte | 82 | 36 |
| `grp_boss_hausmeister` | C | boss_hausmeister | 180 | 200 |
| `grp_d1` | D | rolltreppenkrabbe, rattenschamane | 86 | 32 |
| `grp_d2` | D | rattengardist ×2, rattenschamane | 158 | 56 |
| `grp_d3` | D | rolltreppenkrabbe, rattengardist | 126 | 42 |
| `grp_boss_rattenkoenigin` | D | boss_rattenkoenigin | 420 | 500 |

Summe EXP regulär (15 Gruppen inkl. Tutorial und Rarität, ohne Streuner): **994**. Bei ~80 % bekämpft: ~500 EXP = **L5 vor dem Hausmeister**, ~680 = L6 danach, ~975 = **L7 vor der Königin**.

---

## 6. Items & Ausrüstung

### 6.1 Verbrauchsitems (Rang 2 im Kampf; außerhalb im Menü nutzbar, außer Kampf-Only)

| ID | Name | Wirkung | Ziel | Preis Automat | Verkauf |
|---|---|---|---|---|---|
| `item_bandage` | Werbepflaster | heilt 45 HP (fixed) | ally | 25 | 12 |
| `item_antidote` | Gegengift-Gurgler | heilt `poison` | ally | 20 | 10 |
| `item_energy_krawumm` | KRAWUMM-Dose | +20 MP | ally | 60 | 30 |
| `item_brutzel_burger` | Brutzel-Burger | heilt 120 HP | ally | 80 | 40 |
| `item_smelling_salts` | Riechsalz | belebt mit 30 % MaxHP | ko_ally | 150 | 75 |
| `item_molotov` | Grillanzünder-Cocktail | 60 Fixschaden `fire` | all_enemies (nur Kampf) | 70 | 35 |
| `item_ice_spray` | Kältespray | 90 Fixschaden `ice` | enemy (nur Kampf) | 50 | 25 |
| `item_smoke` | Taschen-Nebelmaschine | garantierte Flucht (kein Boss) | — (nur Kampf) | 100 | 50 |
| `item_hype_megaphone` | Hype-Megafon | Hype +25 | — (nur Kampf) | 120 | 60 |
| `item_elixir` | Premium-Abo-Elixier | volle HP + MP | ally | — (nur Loot) | 300 |

Stapelgrenze: 9 pro Item. Schlüsselitems (`key_master` „Generalschlüssel“) nicht verkauf-/wegwerfbar.

### 6.2 Waffen

| ID | Name | Träger | Werte | Preis | Quelle |
|---|---|---|---|---|---|
| `wpn_mop` | Wischmopp | Kai | ATK +4 | — | Start |
| `wpn_pipe_wrench` | Rohrzange | Kai | ATK +8 | 220 | Automat SR1 |
| `wpn_fire_axe` | Feuerwehraxt | Kai | ATK +12, crit +0.05 | 480 | Automat SR2, verschl. Spind C |
| `wpn_rail_crowbar` | Gleis-Brechstange | Kai | ATK +15, crit +0.05 | — | Lootbox epic |
| `wpn_collar_leather` | Lederhalsband | Mopsula | MAG +4 | — | Start |
| `wpn_collar_studded` | Nietenhalsband | Mopsula | MAG +7 | 200 | Automat SR1, Metallspind B |
| `wpn_collar_crown` | Kronen-Halsband | Mopsula | MAG +11, MP +10 | 460 | Automat SR2, verschl. Spind D |
| `wpn_collar_royal` | Hofjuwelier-Halsband | Mopsula | MAG +14, MP +15 | — | Lootbox epic |

### 6.3 Rüstungen

| ID | Name | Träger | Werte | Preis | Quelle |
|---|---|---|---|---|---|
| `arm_hoodie` | Tierheim-Hoodie | Kai | DEF +3, RES +1 | — | Start |
| `arm_safety_vest` | Warnweste | Kai | DEF +6, RES +2 | 180 | Automat SR1, Metallspind A |
| `arm_sewer_suit` | Kanalarbeiter-Kombi | Kai | DEF +9, RES +4, `poison: resist` | 420 | Automat SR2 |
| `arm_pug_sweater` | Hundepulli „Kleiner Lord“ | Mopsula | DEF +2, RES +3 | — | Start |
| `arm_velvet_cape` | Samtcape | Mopsula | DEF +4, RES +6 | 220 | Automat SR1 |
| `arm_ermine` | Hermelin-Umhang (Kunstpelz!) | Mopsula | DEF +6, RES +9, HP +15 | — | Lootbox epic |

### 6.4 Accessoires (beide Träger)

| ID | Name | Werte | Preis | Quelle |
|---|---|---|---|---|
| `acc_lucky_ticket` | Glücks-Fahrschein | LCK +5 | 150 | Automat SR1, Event, Fahrscheinfresser |
| `acc_rubber_boots` | Gummistiefel | `shock: resist` | 200 | Automat SR2 |
| `acc_sneakers` | Turnschuhe (gebraucht) | SPD +2 | 260 | Automat SR2 |
| `acc_gas_mask` | Gasmaske | `poison: immune` | 300 | Automat SR2, Metallspind C |
| `acc_key_ring` | Schlüsselbund des Hausmeisters | DEF +2, crit +0.05 | — | Hausmeister |
| `acc_queen_crown` | Rattenkrone | STR +3, MAG +3, SPD +1 | — | Rattenkönigin |
| `acc_fan_scarf` | Fan-Schal | positive Hype-Gewinne ×1.2 | — | Follower-Meilenstein 1 000 |
| `acc_clip_mic` | Ansteck-Mikro | Follower-Gewinn ×1.15 | — | Fan-Box |

### 6.5 Automat („Automat“, `vendor_f1`)

| Safe Room | Sortiment |
|---|---|
| SR1 Kiosk (A) | alle Verbrauchsitems außer `item_elixir`; `wpn_pipe_wrench`, `wpn_collar_studded`, `arm_safety_vest`, `arm_velvet_cape`, `acc_lucky_ticket` |
| SR2 Pumpenhaus (B/C) | SR1 + `wpn_fire_axe`, `wpn_collar_crown`, `arm_sewer_suit`, `acc_rubber_boots`, `acc_sneakers`, `acc_gas_mask` |
| SR3 Stellwerk (D) | wie SR2 |

Bestand unbegrenzt. Verkauf = 50 % des Preises (abgerundet); Loot-only-Ausrüstung verkauft sich für 150/250 Cr (rare/epic).
**Credits-Budget E1** (erwartet bis Königin): ~1 100 Cr (Kämpfe ~420, Truhen ~300, Hausmeister 200, Events/Boxen ~180).

---

## 7. Show-System (Kern-USP)

### 7.1 Größen

| Größe | Typ | Bereich | Persistenz |
|---|---|---|---|
| `hype` | float | 0–100 | pro Etage; Start jeder Etage **30** |
| `viewers` | int | ≥ 0 | abgeleitet aus Hype + Followern, live |
| `followers` | int | ≥ 0 | dauerhaft (Spielstand), Start 0 |
| `viewers_peak_battle` | int | — | Maximum während eines Kampfes |

### 7.2 Zuschauer-Formel

```text
baseline        = 1000 * floor_mult + followers * 1.0           # floor_mult: E1 1.0, E2 1.5
viewers_target  = roundi(baseline * (0.4 + hype / 40.0))         # Hype 0 → 0.4×, 50 → 1.65×, 100 → 2.9×
viewers        += (viewers_target - viewers) * (1.0 - exp(-delta / 1.5))   # Anzeige glättet
Rauschen: alle 2 s ±1.5 % (Show-RNG, nur Anzeige)
```

### 7.3 Hype-Ereignisse

| Ereignis | ΔHype | Regel |
|---|---|---|
| Kampfstart normal / Präventiv / Hinterhalt / Boss | +5 / +5 / +8 / +10 | — |
| **Abwechslung** | +3 | `action_key` der Party-Aktion kommt in den letzten 4 Party-`action_key`s nicht vor (`attack`, Skill-ID, Item-ID, `stunt`, `defend`) |
| **Wiederholung** | −5 | gleicher `action_key` zum 3. Mal in Folge (Party, egal welcher Charakter); jede weitere −5 |
| Kritischer Treffer | +5 | — |
| Schwachstelle getroffen | +4 | max. 1× pro Aktion |
| Kill mit Angriff / mit Skill / mit Stunt | +3 / +6 / +10 | — |
| **Overkill** | +8 | `damage >= hp_before + target.max_hp * 0.5`; Credits dieses Gegners ×1.25 |
| **Combo** | +5 | Kai und Mopsula handeln direkt nacheinander (kein Gegnerzug dazwischen) auf **dasselbe** Ziel; 2. Treffer Schaden ×1.1, Banner „COMBO!“ |
| Kill-Serie | +6 | 3 Kills innerhalb von 3 aufeinanderfolgenden Party-Aktionen |
| Stunt Erfolg / Fehlschlag | +20 / +8 | — |
| Party-Mitglied fällt unter 25 % HP | +6 | 1× pro Mitglied pro Kampf („Drama“) |
| Party-Mitglied KO | +10 | — |
| Wiederbelebung | +8 | — |
| Sponsor-Item verwendet (`item_hype_megaphone`) | +25 | — |
| Sieg knapp (ein lebendes Mitglied ≤ 10 % HP) | +15 | bei Kampfende |
| Sieg ohne Schaden | +5 | bei Kampfende |
| Langweilig | −2 | jede Party-Aktion ohne positives Hype-Ereignis |
| Kampf zieht sich | −3 | jeder Party-Zug nach dem 10. (Boss: nach dem 25.) |
| Verteidigen 2× in Folge (gleicher Charakter) | −4 | — |
| Flucht Erfolg / Fehlschlag | −30 / −5 | — |
| **Erkundung:** Truhe / Event / Achievement | +3 / +5 / +8 | — |
| **Erkundung:** Zerfall | −1 pro 5 s | nicht unter 15 |
| Timer-Warnung 5:00 / 1:00 | +10 / +15 | einmalig |

Positive Ereignisse werden mit `hype_gain_mult` multipliziert (`acc_fan_scarf` 1.2). Danach `clamp(0, 100)`.

### 7.4 Sponsor-Geschenke

- **Auslöser:** Hype überschreitet im **Kampf** aufwärts **50**, **75** oder **100**. Jede Schwelle 1× pro Kampf.
  Max. **2 Geschenke pro regulärem Kampf**, **3 pro Bosskampf**. Nach Schwelle 100: Hype auf 80 setzen.
- **Ablauf:** Vor dem nächsten Zug fliegt eine Sponsor-Drohne ein (1.5 s, überspringbar), Banner oben rechts,
  M.O.D. `sponsor_gift`. Kostet **keine** Ticks.
- **Auswahl:** gewichteter Zufall (Show-RNG) mit Situations-Multiplikatoren:

| ID | Sponsor (fiktiv, satirisch) | Slogan | Geschenk | Basis-Gewicht | Multiplikator |
|---|---|---|---|---|---|
| `sp_gluckwasser` | **Glückwasser** | „Trink dich glücklich. Wörtlich.“ | alle Verbündeten +35 % MaxHP | 3 | ×3 wenn ein Verbündeter < 50 % HP |
| `sp_krawumm` | **KRAWUMM Energy** | „Schlaf ist was für Verlierer.“ | `haste` 3 auf alle Verbündeten | 2 | — |
| `sp_panzerkeks` | **Panzerkeks** | „Der Keks, der zurückbeißt.“ | `guard` 3 auf alle Verbündeten | 2 | ×2 wenn ein Verbündeter < 35 % HP |
| `sp_sorgenfrei` | **Sorgenfrei Versicherungen AG** | „Wir zahlen. Meistens.“ | belebt KO-Verbündeten mit 50 %; sonst niedrigster +50 % | 1 | ×6 wenn ein Verbündeter KO |
| `sp_novanet` | **NovaNet Mobilfunk** (Konzernmarke) | „Empfang bis in die tiefste Etage.“ | alle Verbündeten +40 % MaxMP | 2 | ×2 wenn ein Verbündeter < 30 % MP |
| `sp_brutzel` | **Brutzel-Burger** | „Mit echtem Fleisch-Aroma.“ | 1× `item_brutzel_burger` ins Inventar + alle +20 HP | 2 | — |
| `sp_doomscroll` | **DoomScroll+** | „Nur noch eine Folge.“ | `slow` 3 auf alle Gegner (ignoriert Status-Resistenz) | 2 | ×2 im Bosskampf |

### 7.5 Chat-Ticker (Kosmetik)

Laufband unten, Keys in `mod_lines.json → chat_*` (z. B. `chat_crit`, `chat_boring`, `chat_mopsula`), max. 1 Zeile / 2.5 s.
Absender sind generierte Fan-Namen („xX_Gleisgeist_Xx“, „OmaHilde1953“, „mopsfan_88“). Kein Gameplay-Effekt.

### 7.6 Follower-Konvertierung

```text
# bei Kampfsieg
follower_gain = floori(viewers_peak_battle * (0.01 + 0.02 * hype_end / 100.0) * mult)
mult = 2.0 (Boss) | 1.0 sonst;  × 1.15 mit acc_clip_mic
# bei Flucht
followers -= floori(followers * 0.01)
# Achievements
Bronze +25, Silber +50, Gold +100 Follower
# Events: laut Kap. 2.6
```

Erwartung E1: ~40 pro regulärem Kampf, ~110 Hausmeister, ~250 Königin → **~1 200–1 500 Follower am Etagenende**.

### 7.7 Follower-Meilensteine

| Follower | ID | Belohnung | M.O.D.-Key |
|---|---|---|---|
| 100 | `ms_100` | Bronze-Box | `follower_milestone` |
| 250 | `ms_250` | Fan-Box | `follower_milestone` |
| 500 | `ms_500` | 300 Credits + Silber-Box | `follower_milestone` |
| 1 000 | `ms_1000` | Fan-Box + `acc_fan_scarf` | `follower_milestone` |
| 2 000 | `ms_2000` | Gold-Box | `follower_milestone` (E1 nur mit Top-Spiel erreichbar) |
| 5 000 | `ms_5000` | Gold-Box + Titel „Quotenkönig:in“ | ab Etage 2 |

---

## 8. Achievements (29)

**Prüfung:** Der Autoload `Show` lauscht auf `Events`-Signale. Bedingung = Ausdruck über `e.` (Event-Payload),
`s.` (persistente Zähler in `Game.stats`) und `f.` (Flags). Operatoren: `== != >= <= > <`, Verknüpfung nur `&&`.
Jedes Achievement wird genau 1× vergeben. Belohnung: Lootbox + Follower (Kap. 7.6) + Hype +8 + M.O.D.-Spruch.

**Zähler `Game.stats`:** `kills_total, kills_skill, battles_won, battles_fled, preemptives, ambushes_won, crits_total,
stunts_success, stunts_fail, chests_opened, sponsor_gifts, credits_spent_vendor, lootboxes_opened, events_completed,
game_overs, ko_mopsula, explore_seconds_since_battle, viewers_max`.

**Payload `enemy_killed`:** `enemy_id, overkill, by (attack|skill|stunt|item), member`.
**Payload `battle_won`:** `party_turns, min_party_hp, min_party_hp_pct, crits, weakness_hits, items_used, party_kos,
damage_taken, is_boss, boss_id, encounter_type, group_id`.

| ID | Name | Trigger (Signal) | Bedingung | Box | M.O.D.-Spruch |
|---|---|---|---|---|---|
| `ach_first_blood` | Erster Kill | `enemy_killed` | `s.kills_total == 1` | bronze | „Erster Kill! Die Werbekunden atmen auf.“ |
| `ach_first_win` | Willkommen in der Sendung | `battle_won` | `s.battles_won == 1` | bronze | „Ein Sieg. Wir haben schon Merch bestellt.“ |
| `ach_close_call` | Knapp daneben | `battle_won` | `e.min_party_hp_pct <= 0.10` | bronze | „Mein Puls! Ich habe keinen Puls, aber trotzdem!“ |
| `ach_one_hp` | Haaresbreite | `battle_won` | `e.min_party_hp == 1` | silver | „Ein. Einziger. Lebenspunkt. Das schneiden wir in den Trailer.“ |
| `ach_pacifist` | Pazifist | `explore_tick` | `s.explore_seconds_since_battle >= 300` | bronze | „Fünf Minuten ohne Gewalt. Die Zuschauer schlafen ein. Hier, nimm das.“ |
| `ach_overkill` | Overkill | `enemy_killed` | `e.overkill == true` | bronze | „Das war … gründlich. Die Reinigung stellt das in Rechnung.“ |
| `ach_crit_3` | Kritische Masse | `battle_won` | `e.crits >= 3` | bronze | „Drei Kritische in einem Kampf. Statistiker:innen weinen.“ |
| `ach_weakness_5` | Wunder Punkt | `battle_won` | `e.weakness_hits >= 5` | bronze | „Fünfmal genau dahin, wo es wehtut. Empathie: null. Quote: hoch.“ |
| `ach_stunt_first` | Showtalent | `stunt_resolved` | `e.success == true && s.stunts_success == 1` | bronze | „DAS ist Fernsehen!“ |
| `ach_stunt_fail_3` | Pannenshow | `stunt_resolved` | `e.success == false && s.stunts_fail == 3` | bronze | „Drei Pannen. Wir machen eine eigene Sendung daraus.“ |
| `ach_combo_first` | Eingespieltes Team | `combo` | `true` | bronze | „Mensch und Mops im Gleichschritt. Rührend. Und lukrativ.“ |
| `ach_preemptive_3` | Leise Sohle | `battle_started` | `e.encounter_type == "preemptive" && s.preemptives == 3` | bronze | „Von hinten. Dreimal. Die Ethikkommission ist im Urlaub.“ |
| `ach_ambush_won` | Rückenwind | `battle_won` | `e.encounter_type == "ambush"` | bronze | „Überrascht und trotzdem gewonnen. Fast, als hätten Sie Talent.“ |
| `ach_flee_first` | Taktischer Rückzug | `battle_fled` | `s.battles_fled == 1` | bronze | „Feigheit, äh, Taktik! Auch dafür gibt es eine Box. Leider.“ |
| `ach_sponsor_first` | Gesponsert | `sponsor_gift` | `s.sponsor_gifts == 1` | bronze | „Ihr erster Sponsor! Bitte lächeln Sie in Kamera 3.“ |
| `ach_viewers_5000` | Quotenhit | `viewers_changed` | `e.viewers >= 5000` | silver | „Fünftausend! Die Konkurrenz zeigt gerade Kochshows. Ha!“ |
| `ach_chests_10` | Schatzsucher:in | `chest_opened` | `s.chests_opened == 10` | silver | „Zehn Kisten. Das nennt man bei uns ‚Kundenbindung‘.“ |
| `ach_vendor_500` | Kaufrausch | `item_bought` | `s.credits_spent_vendor >= 500` | bronze | „500 Credits im Automaten. Die Wirtschaft dankt.“ |
| `ach_lootbox_10` | Gacha-Gewohnheit | `lootbox_opened` | `s.lootboxes_opened == 10` | bronze | „Zehn Boxen. Hier ist noch eine. Für die Gewohnheit.“ |
| `ach_level_5` | Aufsteiger:in | `level_up` | `e.member == "kai" && e.level == 5` | bronze | „Level fünf. Sie sind jetzt offiziell schwer zu ersetzen.“ |
| `ach_mopsula_ko` | Der Graf ist gefallen | `party_ko` | `e.member == "mopsula" && s.ko_mopsula == 1` | bronze | „Der Graf liegt! Die Quote liegt mit ihm! Tun Sie was!“ |
| `ach_mimic` | Fahrschein, bitte | `enemy_killed` | `e.enemy_id == "fahrscheinfresser"` | silver | „Schwarzfahren war gestern. Heute: Schwarzautomat.“ |
| `ach_events_all` | Neugierig | `event_completed` | `s.events_completed == 5` | silver | „Alle Events gesehen. Sie lesen auch das Kleingedruckte, oder?“ |
| `ach_hausmeister` | Feierabend | `boss_defeated` | `e.boss_id == "boss_hausmeister"` | silver | „Der Hausmeister ist in Rente. Unbefristet.“ |
| `ach_hausmeister_no_items` | Ohne Hilfsmittel | `battle_won` | `e.boss_id == "boss_hausmeister" && e.items_used == 0` | silver | „Ohne ein einziges Item. Die Sponsoren sind beleidigt. Ich bin beeindruckt.“ |
| `ach_queen` | Gleis 9 geräumt | `boss_defeated` | `e.boss_id == "boss_rattenkoenigin"` | gold | „Die Königin ist tot, lang lebe — ach, egal, ZUSCHAUERREKORD!“ |
| `ach_queen_flawless` | Königlicher Auftritt | `battle_won` | `e.boss_id == "boss_rattenkoenigin" && e.party_kos == 0` | gold | „Kein einziger KO. Graf Mopsula verlangt einen Thron. Abgelehnt.“ |
| `ach_speedrun` | Expresszug | `floor_completed` | `e.floor == 1 && e.timer_left >= 480` | gold | „Mit acht Minuten Rest. Sie sind entweder genial oder haben nichts gesehen.“ |
| `ach_last_minute` | Auf den letzten Drücker | `floor_completed` | `e.floor == 1 && e.timer_left < 60` | silver | „Unter einer Minute! Mein Regieraum hat geschrien. Vor Freude.“ |

(29 Einträge — alle im Slice erreichbar.)

---

## 9. Lootboxen

**Grundsatz:** Lootboxen werden **ausschließlich im Spiel verdient** (Achievements, Bosse, Meilensteine, Events).
**Kein Echtgeld, kein Shop, keine Premiumwährung, keine Kaufoption — nirgends.** Satire auf Gacha, nicht Gacha.

### 9.1 Stufen

| Tier | ID | Würfe | Garantie | Quellen |
|---|---|---|---|---|
| Bronze | `bronze` | 2 | — | Achievements (bronze), Meilenstein 100, Glücksrad |
| Silber | `silver` | 3 | ≥ 1× `rare` oder besser | Achievements (silver), Hausmeister, Meilenstein 500 |
| Gold | `gold` | 4 | ≥ 1× `epic` | Achievements (gold), Rattenkönigin, Meilenstein 2 000 |
| Fan-Box | `fan` | 1 Fan-Item + 2 Würfe | 1 Fan-Item fix | Meilensteine 250 / 1 000 |

### 9.2 Seltenheits-Gewichte pro Wurf

| Tier | common | rare | epic |
|---|---|---|---|
| bronze | 80 | 18 | 2 |
| silver | 55 | 38 | 7 |
| gold | 25 | 55 | 20 |
| fan | 50 | 40 | 10 |

Garantien greifen auf den **letzten** Wurf, falls bis dahin nicht erfüllt.

### 9.3 Pools Etage 1 (`lootboxes.json → pools.f1`)

| Rarität | Eintrag (Gewicht) |
|---|---|
| `common` | `credits:25` (30) · `item_bandage ×2` (25) · `item_antidote ×2` (15) · `item_energy_krawumm` (15) · `item_ice_spray` (10) · `item_molotov` (10) |
| `rare` | `item_brutzel_burger ×2` (20) · `item_smelling_salts` (20) · `credits:120` (15) · `item_hype_megaphone` (10) · `item_smoke` (10) · `acc_lucky_ticket` (8) · `acc_rubber_boots` (8) · `arm_safety_vest` (5) · `wpn_collar_studded` (5) |
| `epic` | `item_elixir` (25) · `wpn_fire_axe` (15) · `wpn_collar_crown` (15) · `acc_sneakers` (15) · `arm_ermine` (10) · `wpn_rail_crowbar` (10) · `credits:400` (10) |
| `fan` (Fan-Item) | `acc_clip_mic` (40) · `item_elixir` (30) · `item_hype_megaphone ×2` (30) |

- **Duplikat-Ausrüstung:** Wenn das Ausrüstungsteil schon besessen wird → wird zu Credits (Verkaufswert ×1.5), Anzeige „DUPLIKAT → +X Cr“.
- **Pity:** `pity_rare` zählt geöffnete Boxen ohne `rare`+; bei **4** ist der erste Wurf der nächsten Box `rare`.
  `pity_epic` zählt Boxen ohne `epic`; bei **8** ist der erste Wurf der nächsten Box `epic`. Zähler werden bei Treffer 0. Persistiert im Spielstand.
- **RNG:** eigener `RandomNumberGenerator` `loot_rng`, Seed im Spielstand → deterministisch, kein Save-Scumming durch Neuladen vor dem Öffnen.

### 9.4 Öffnen (UX, nur im Safe Room)

1. Lootbox-Regal: Boxen als 3D-Objekte (Bronze = Holzkiste mit Bronzebeschlägen, Silber = Metall, Gold = goldene Kiste mit Glühen, Fan = pinke Geschenkbox mit Herz-Logo).
2. Box antippen/A → Box springt in die Mitte, M.O.D. `lootbox_open_<tier>`.
3. **3 Taps** zum Öffnen: jeder Tap = Rütteln + Licht stärker (Tier-Farbe: #CD7F32 / #C0C8D2 / #FFC83D / #FF5FA2). Rarität des besten Wurfs färbt den Lichtschein ab Tap 2 („Tease“).
4. Explosion (Partikel), Items fliegen als Karten heraus, werden **einzeln** aufgedeckt (0.4 s je Karte, Rand in Raritätsfarbe: common #BFC5CC, rare #4AA8FF, epic #B05CFF).
5. Pity-Treffer: Zusatz-Banner „GARANTIE!“ + M.O.D. `lootbox_pity`.
6. Buttons: „Alle aufdecken“ (überspringt Animation), „Nächste Box“, „Fertig“.
7. Fußzeile dauerhaft sichtbar: „Lootboxen in PRIME TIME DUNGEON können nicht gekauft werden.“

---

## 10. Safe Room

### 10.1 Funktionen

| Funktion | Regel |
|---|---|
| Betreten | Volle Heilung (HP, MP, alle Status, KO aufgehoben), Timer pausiert, Gegner können nicht folgen (Tür schließt) |
| **Speichern** | 3 Slots (`user://saves/slot_N.json`), Bestätigung bei Überschreiben; speichert Position = dieser Safe Room |
| **Lootboxen** | Öffnen (Kap. 9.4) |
| **Automat** | Kaufen / Verkaufen (Kap. 6.5), Mengenwahl 1–9, Vorschau Stat-Änderung (grün/rot) |
| **Ausrüstung** | Ausrüsten beider Charaktere |
| **Mopsula** | Gesprächsszene, wenn eine verfügbar ist (Ausrufezeichen über Mopsula); sonst Zufalls-Einzeiler |
| **Verlassen** | Tür → Erkundung, Timer läuft weiter |

Safe Rooms E1: `sr_kiosk` (A), `sr_pumphouse` (B/C), `sr_signalbox` (D). Optik: warmes Licht #FFC98A, Sofa (Boxen), Kiosk-Theke, Automat (Box mit leuchtender Front #3CE0C0), Röhrenfernseher mit M.O.D.-Gesicht.

### 10.2 Mopsula-Szenen (je 1×, in `mod_lines.json → scenes`)

**Szene 1 — `mop_scene_1` „Seine Durchlaucht“** (Bedingung: erster Safe-Room-Besuch)

> **Mopsula:** Kammerdiener:in. Setz dich. Wir müssen reden.
> **Kai:** Du redest seit einer Stunde.
> **Mopsula:** Mit dir. Nicht AN dich. Ein Unterschied, den das gemeine Volk selten begreift.
> **Kai:** Wieso kannst du überhaupt sprechen?
> **Mopsula:** Wir konnten immer sprechen. Ihr habt nur nie zugehört. Neun Jahre „Na, du Dicker?“. Neun Jahre!
> **Kai:** … Ich hab dir jeden Abend das Ohr gekrault.
> **Mopsula:** *(Pause)* Das linke. Das linke war akzeptabel. Weitermachen.
> **M.O.D. (Fernseher):** Zuschauer-Umfrage: 94 % wollen mehr vom Hund. Notiert.

**Szene 2 — `mop_scene_2` „Ahnenreihe“** (Bedingung: `f.boss_hausmeister_defeated` und nächster Safe-Room-Besuch)

> **Mopsula:** Der Hausmeister. Er hatte einen Schlüssel für jede Tür und keine einzige, hinter der jemand auf ihn wartete.
> **Kai:** Das ist ungewohnt nachdenklich für dich.
> **Mopsula:** Wir sind von hohem Geblüt. Nachdenklichkeit ist erblich. Unsere Ahnen waren Grafen, Herzöge —
> **Kai:** Deine Mutter war aus einem Kofferraum in Polen.
> **Mopsula:** EIN SEHR VORNEHMER KOFFERRAUM.
> **Kai:** *(lacht)*
> **Mopsula:** … Wartet jemand auf dich? Da oben?
> **Kai:** Da oben ist nichts mehr.
> **Mopsula:** Dann warten Wir eben aufeinander. Das ist ein Befehl.

**Szene 3 — `mop_scene_3` „Das Tierheim“** (Bedingung: Kai-Level ≥ 4 und Szene 1 gesehen)

> **Mopsula:** Weißt du, warum Wir „schwer vermittelbar“ waren?
> **Kai:** Weil du jeden Besucher angeknurrt hast.
> **Mopsula:** Weil sie die Falschen waren. Familien mit Kinderwagen. Pärchen mit Instagram. Niemand wollte einen alten Mops mit Atemgeräuschen.
> **Kai:** Ich wollte dich adoptieren. Nächsten Monat. Die Papiere lagen schon in der Schublade.
> **Mopsula:** *(lange Pause)* … Das sagst du nur wegen der Kameras.
> **Kai:** Die Kameras sind mir egal.
> **Mopsula:** Hmpf. Wir nehmen das zur Kenntnis. Unter Vorbehalt. *(dreht sich weg, Schwanz wedelt)*
> **M.O.D.:** Diese Szene wird in 47 Galaxien gerade mit Taschentüchern beworben. Danke.

**Szene 4 — `mop_scene_4` „Vor dem Thron“** (Bedingung: erster Besuch in `sr_signalbox`)
**Belohnung:** Flag `f.mop_pep_talk` → im nächsten Bosskampf starten beide mit `guard` 2.

> **Mopsula:** Sie nennt sich Königin. Eine RATTE. Mit einer Krone aus Fahrscheinen.
> **Kai:** Wir müssen nicht gegen sie kämpfen. Die Treppe ist gleich da.
> **Mopsula:** Es gibt Dinge, die ein Adeliger nicht dulden kann. Hochstapelei ist eines davon.
> **Kai:** Du bist ein Mops aus dem Tierheim.
> **Mopsula:** Und du bist ein:e Tierpfleger:in mit einem Wischmopp. Und doch stehen wir hier. Lebend. Im Fernsehen.
> **Kai:** … Okay. Zusammen.
> **Mopsula:** Zusammen. Aber Wir gehen voraus. Wegen der Optik.

---

## 11. M.O.D. — Stimme & Sprüche

### 11.1 Tonfall-Leitfaden

| Regel | Beispiel |
|---|---|
| **Moderationston**, immer „live“, spricht Publikum UND Kai an | „Liebe Zuschauer:innen, sehen Sie das?“ |
| **Quote über alles** — misst Gefühle in Zuschauerzahlen | „Ihr Schmerz: +300 Zuschauer.“ |
| **Regelversessen**: zitiert erfundene Paragrafen (§ der Showordnung) | „Gemäß § 12b ist Weinen erlaubt, aber nur in HD.“ |
| **Werbung als Satzzeichen**: unterbricht sich für Sponsoren | „Das war knapp! — präsentiert von Panzerkeks.“ |
| **Heimlich sentimental**: max. 1 von 10 Sprüchen zeigt Wärme, sofort relativiert | „Ich war nicht besorgt. Meine Server laufen nur heiß.“ |
| **Nie grausam gegenüber Menschen als solchen** — Spott gilt Situation, Konzern, Kapitalismus, nicht Opfern | — |
| Länge: max. **110 Zeichen** pro Spruch (2 Zeilen im HUD) | — |
| Siezt Kai, nennt Mopsula „der Graf“ oder „unser Publikumsliebling“ | — |

**Platzhalter:** `{name}` (Kai-Name), `{floor}`, `{level}`, `{enemy}`, `{item}`, `{achievement}`, `{viewers}`, `{followers}`, `{sponsor}`.
**Auswahl:** zufällig aus dem Key, nie zweimal hintereinander derselbe; Key-Cooldown 20 s (außer `boss_*`, `death`, `timer_*`, `intro`).
**Priorität:** `death` > `boss_*` > `timer_*` > `achievement_*` > `lootbox_*` > Rest. Niedrigere werden verworfen, wenn eine höhere läuft.

### 11.2 Sprüche nach Trigger-Key (`mod_lines.json`)

| Key | Sprüche |
|---|---|
| `intro` | „Guten Abend, Galaxis! Willkommen bei DUNGEON PRIME TIME — der Show, die Ihren Planeten gekostet hat!“ · „Kandidat:in {name}, Sie sind live. Bitte nicht in die Kamera weinen, das spiegelt.“ · „Ich bin M.O.D., Ihre Moderatorin, Ihre Regie, Ihr Schicksal. Lächeln!“ |
| `floor_start` | „Etage {floor}! Neuer Countdown, neue Monster, gleiche Gage: keine.“ · „Die Uhr läuft. Die Kameras laufen. Laufen Sie auch.“ |
| `first_fight` | „Ihr erster Kampf! Die Leiste rechts zeigt, wer dran ist. Die Leiste links zeigt, wie sehr Sie verlieren.“ · „Tipp der Regie: Monster hassen es, wenn man sie trifft.“ |
| `achievement_generic` | „Achievement freigeschaltet: {achievement}! Applaus vom Band, bitte.“ · „{achievement}! Ihre Mutter wäre stolz, wenn sie noch Empfang hätte.“ · „Eine Lootbox für Sie! Öffnen nur im Safe Room. Vorfreude ist Content.“ · „Neues Achievement. Die Juristen prüfen noch, ob es zählt. Es zählt.“ |
| `low_hp` | „Ihre HP sind niedrig! Die Quote ist hoch! Ein Dilemma!“ · „Kandidat:in in Lebensgefahr — Kamera 2, Nahaufnahme!“ · „Bitte jetzt nicht sterben, der Werbeblock ist noch nicht verkauft.“ |
| `kill_streak` | „Drei auf einen Streich! Das Studiopublikum tobt. Das Studiopublikum ist eine Tonspur, aber trotzdem!“ · „Kill-Serie! Jemand bringe {name} einen Vertrag.“ · „Das nennt man bei uns ‚Programmgestaltung‘.“ |
| `crit` | „KRITISCH! Das hat sogar mir wehgetan, und ich bin Software.“ · „Volltreffer! Zeitlupe, bitte. Nochmal. Nochmal!“ |
| `weakness` | „Schwachstelle gefunden. Wie bei meinen Ex-Producern.“ · „Genau da! Sie haben das Handbuch gelesen. Es gibt kein Handbuch.“ |
| `overkill` | „Das war … mehr als nötig. Wunderbar!“ · „Overkill! Die Jugendschutz-Abteilung hat gekündigt.“ |
| `stunt_success` | „WAS FÜR EIN STUNT! Das kommt in die Jahresrückschau!“ · „Ich hätte es nie für möglich gehalten. Ich habe dagegen gewettet. Egal!“ · „Das, liebe Galaxis, ist Prime Time!“ |
| `stunt_fail` | „Autsch. Aber Schadenfreude ist auch Quote.“ · „Der Stunt ist misslungen. Die Wiederholung läuft in Dauerschleife.“ · „Gemäß § 4 der Showordnung: Lachen ist ausdrücklich erlaubt.“ |
| `boring_fight` | „Zum dritten Mal dasselbe. Die Zuschauer wechseln zu einer Kochshow.“ · „Gähn. Haben Sie es mal mit … Abwechslung versucht?“ · „Ich bekomme gerade Beschwerden. Von meinen eigenen Untertiteln.“ |
| `flee` | „Flucht! Mutig ist anders. Klug manchmal auch.“ · „Und weg sind sie. Die Kamera bleibt beim Monster. Es wirkt einsam.“ · „Rückzug notiert. Die Zuschauer auch. Sie entfolgen.“ |
| `flee_fail` | „Fluchtversuch gescheitert. Das Monster hat Sie freundlich zurückgebeten.“ · „Nö. Die Tür ist dekorativ.“ |
| `sponsor_gift` | „Dieser Moment wird Ihnen präsentiert von {sponsor}!“ · „Ein Geschenk von {sponsor}! Bitte das Logo in die Kamera halten.“ · „Die Zuschauer lieben Sie, also liebt {sponsor} Sie. Vorläufig.“ |
| `timer_warning_5` | „Noch fünf Minuten! Die Etage bricht bald zusammen. Wir haben Popcorn.“ · „Fünf Minuten bis zum Einsturz. Treppe suchen wäre jetzt ein Trend.“ · „Achtung, Achtung: Die Unterstadt schließt in fünf Minuten. Bitte beeilen Sie sich zum Ausgang. Oder nicht. Quote!“ |
| `timer_warning_1` | „EINE MINUTE! Laufen Sie! LAUFEN SIE!“ · „Sechzig Sekunden! Ich habe die Dramamusik extra laut gestellt.“ · „Letzte Minute! Der Graf sollte jetzt nicht stehen bleiben, um zu posieren.“ |
| `timer_zero` | „Und … Sendeschluss. Die Etage ist eingestürzt. Mit Ihnen darin. Schade.“ · „Zeit abgelaufen. Ich hatte Sie wirklich gemocht. Bisschen.“ |
| `lootbox_open_bronze` | „Bronze. Wie die Medaille für ‚Dabei sein ist alles‘.“ · „Eine Bronzebox! Was drin ist? Wahrscheinlich ein Pflaster. Mit Werbung.“ · „Bronze! Die Box, die sagt: ‚Wir haben an dich gedacht. Kurz.‘“ |
| `lootbox_open_silver` | „Silber! Jetzt wird’s interessant. Ein bisschen.“ · „Silberbox! Garantiert mindestens selten. Steht so im Vertrag.“ |
| `lootbox_open_gold` | „GOLD! Bitte Trommelwirbel. Den teuren!“ · „Eine Goldbox. Der Konzern hat dafür einen Mond verkauft.“ |
| `lootbox_open_fan` | „Eine Fan-Box! Ihre Fans haben zusammengelegt. Ein paar haben Glitzer reingetan. Sorry.“ · „Von Fans, für Fans, gegen Monster. Rührend.“ |
| `lootbox_pity` | „Endlich Glück! Und nein, das ist kein Algorithmus. Doch, ist es. Egal!“ |
| `death` | „Sendeschluss. {name} und der Graf sind gefallen. Wiederholung um 3 Uhr nachts.“ · „Game Over. Die Zuschauer schalten ab. Ich schalte … noch nicht ab.“ · „Das war’s. Ich lege Ihnen eine Blume aufs Inventar.“ |
| `mopsula_ko` | „DER GRAF IST GEFALLEN! Die Quote stürzt ab! Helfen Sie ihm, sofort!“ · „Unser Publikumsliebling liegt am Boden. Ich verlange eine Wiederbelebung, aus rein geschäftlichen Gründen.“ |
| `kai_ko` | „{name} ist KO! Der Graf ist jetzt allein. Das wird … aristokratisch.“ · „Kandidat:in am Boden. Der Mops übernimmt. Endlich ein Profi.“ |
| `revive` | „Wiederbelebt! Comebacks sind unser Lieblingsgenre.“ |
| `boss_intro_hausmeister` | „Applaus für den Hausmeister! Seit 34 Jahren im Dienst, seit 34 Minuten ein Monster.“ · „Achtung: Er hat einen Schlüssel für alles. Außer für Gnade.“ |
| `boss_phase_hausmeister_2` | „Er verliest die Hausordnung! Paragraf sieben! Das wird hässlich.“ |
| `boss_phase_hausmeister_3` | „Feierabend! Und ein Hausmeister im Feierabend kennt keine Regeln mehr!“ |
| `boss_intro_rattenkoenigin` | „Meine Damen und Herren: Ihre Majestät, die Rattenkönigin von Gleis 9! Bitte nicht auf den Schwanz treten. Die Schwänze.“ · „Zwei Adelige, ein Bahnsteig. Das ist das Duell, für das die Galaxis bezahlt hat!“ |
| `boss_phase_rattenkoenigin_2` | „Hören Sie das? Das ist der Zug auf Gleis 9. Er ist pünktlich. Zum ersten Mal überhaupt.“ |
| `boss_train_warning` | „Zug fährt ein! Zurückbleiben, bitte — oder verteidigen Sie sich!“ |
| `boss_phase_rattenkoenigin_3` | „Der Zug ist entgleist! Die Königin ist wütend! Ich bin begeistert!“ |
| `boss_defeated` | „Boss besiegt! Die Einschaltquote macht gerade einen Handstand.“ · „Gefallen! Und das zur besten Sendezeit. Danke!“ |
| `level_up` | „Level up! Sie sind jetzt {level}% weniger verzichtbar.“ · „Stufenaufstieg! Mehr HP, mehr MP, gleich wenig Gage.“ |
| `follower_milestone` | „{followers} Follower! Sie haben jetzt mehr Fans als Ihre alte Stadt Einwohner. Hatte.“ · „Meilenstein! Ihre Fans schicken eine Box. Und Liebesbriefe an den Hund.“ |
| `safe_room_enter` | „Safe Room. Keine Monster, keine Kameras. Doch, eine Kamera. Okay, sieben.“ · „Werbepause! Heilen Sie sich, wir verkaufen solange Ihre Highlights.“ · „Willkommen im Safe Room. Bitte den Automaten füttern, er hat Familie.“ |
| `vendor_buy` | „Danke für Ihren Einkauf! Ein Teil des Erlöses geht an … uns.“ · „{item}! Exzellente Wahl. Die anderen waren schlechter. Für uns.“ |
| `stairs_found` | „Die Treppe! Abstieg oder Ruhm — die Uhr sagt Abstieg, das Publikum sagt Königin.“ · „Da ist sie, die Treppe. Ich würde ja noch ein bisschen bleiben. Rein quotentechnisch.“ |
| `floor_end` | „Etage 1 geschafft! Nach der Werbung: Etage 2. Bleiben Sie dran!“ · „Sie haben die Unterstadt überlebt. Bitte unterschreiben Sie hier, hier und — hier, für die Fortsetzung.“ |

(Gesamt: **90 Sprüche**.)

---

## 12. Klassensystem (ab Etage 3) — Datenvorbereitung

### 12.1 Regeln

- Klassenwahl einmalig zu Beginn von Etage 3 im Safe-Room-Event „**Casting**“ (M.O.D. als Jury). Jede:r Charakter wählt 1 von 4.
- Klassen **ergänzen** (ersetzen nicht) die Basis-Skills. Kein Wechsel im Slice-Folgeumfang (Respec später als Gold-Box-Belohnung denkbar → nicht geplant).
- Datenmodell **jetzt**: `party.json` Feld `class_id: ""` je Mitglied, Save-Format enthält `class_id`. `classes.json` existiert mit 8 Einträgen, wird im Slice nicht ausgewertet (DB validiert aber).

### 12.2 Schema `classes.json`

```json
{
  "id": "cls_kai_wrecker",
  "owner": "kai",
  "name_key": "CLASS_KAI_WRECKER",
  "stat_mult":   { "hp": 1.10, "str": 1.15, "def": 1.10, "spd": 0.95 },
  "growth_add":  { "hp": 3.0, "def": 0.5 },
  "passives":    [ { "id": "pas_thick_skin", "params": { "taunt_turns_add": 1, "dmg_taken_mult_while_taunt": 0.9 } } ],
  "skills":      [ { "skill": "kai_wrecking_ball", "level": 11 }, { "skill": "kai_concrete_boots", "level": 13 } ],
  "show_mods":   { "hype_gain_mult": 1.0, "stunt_success_add": 0.0, "stunt_cooldown": 3, "sponsor_thresholds": [50, 75, 100] }
}
```

### 12.3 Klassen

| ID | Owner | Name | Rolle | `stat_mult` | Passiv |
|---|---|---|---|---|---|
| `cls_kai_wrecker` | kai | **Abrissbirne** | Tank/Bruiser | HP 1.10, STR 1.15, DEF 1.10, SPD 0.95 | `pas_thick_skin`: Taunt +1 Zug, −10 % Schaden während Taunt |
| `cls_kai_runner` | kai | **Gleisläufer:in** | Tempo/Krit | SPD 1.20, LCK 1.20, DEF 0.90 | `pas_first_strike`: +25 % Krit auf erste Aktion je Kampf; Präventiv-Winkel 90° statt 110° |
| `cls_kai_tinker` | kai | **Schrott-Tüftler:in** | Items/Elemente | MAG 1.30, STR 0.95 | `pas_tinkering`: Schadens-Items ×1.5, Items Rang 1 |
| `cls_kai_showrunner` | kai | **Showrunner:in** | Hype/Stunts | LCK 1.25 | `pas_crowd_magnet`: Stunt-Erfolg +0.15, Stunt-Cooldown 2, Hype-Gewinne ×1.25 |
| `cls_mop_archmage` | mopsula | **Hofmagier** | Elementar-DD | MAG 1.20, MP 1.10 | `pas_exploit`: Schwachstellen-Faktor 1.75 statt 1.5 |
| `cls_mop_physician` | mopsula | **Leibarzt Seiner Hoheit** | Heiler | RES 1.15, HP 1.10 | `pas_bedside`: Heilung ×1.3; Zugbeginn heilt eigenes `poison` |
| `cls_mop_hexer` | mopsula | **Fluchgraf** | Debuffs | MAG 1.10, SPD 1.05 | `pas_curse`: Status-Chancen +0.25, Status-Dauer +1 |
| `cls_mop_diva` | mopsula | **Diva** | Buffs/Show | LCK 1.20, RES 1.10 | `pas_spotlight`: Buff-Dauer +1, Sponsor-Schwellen 45/70/95 |

Die Skill-Listen der Klassen (je 4 Skills L11–L17) werden mit Etage 3 spezifiziert; IDs folgen dem Muster `<owner>_<name>`.

---

## 13. Balancing-Ziele

| Kennzahl | Ziel | Grundlage |
|---|---|---|
| Regulärer Kampf: Party-Züge | **4–6** (Median 4.5) | Simulation: 3.2 (Tutorial) bis 5.8 (`grp_c3`) |
| Regulärer Kampf: Gesamtzüge | 7–11 | — |
| Regulärer Kampf: Dauer (×1) | 40–70 s | ~4 s je Party-Zug, ~2.5 s je Gegnerzug |
| HP-Verlust pro regulärem Kampf | 20–35 % der Party-HP | Simulation 16–32 % ohne Heilung zwischen Kämpfen |
| Kämpfe zwischen Safe Rooms ohne Items | 2–3 | — |
| Hausmeister: Party-Züge / Dauer | 16–22 / 2.5–4 min | Sim: L5 18 Züge, 100 % Sieg (einfache KI) |
| Rattenkönigin: Party-Züge / Dauer | 20–26 / 3.5–5 min | Sim: L7 23 Züge |
| Level bei Hausmeister / Königin | **5 / 7** | EXP-Kurve Kap. 4.3, 80 % der Gruppen bekämpft |
| Erwartete Game Overs Etage 1 (Erstspieler) | **0–1** gesamt; Hausmeister ~20 % Niederlage-Rate beim 1. Versuch, Königin ~35 % | — |
| Timer-Verbrauch Etage 1 | 11–15 min von 20:00 (Rest 5–9 min) | Laufwege ~31 Zellen + Erkundung |
| Gesamtspielzeit Etage 1 (Erstdurchlauf) | **22–28 min** (Median 25) inkl. Tutorial; Wiederholer 15–20 min | Brief: 15–25 min |
| Bekämpfte Gruppen | 11–13 von 15 regulären | — |
| Credits bei Königin | ~1 100 erwirtschaftet, ~800 ausgegeben | — |
| Sponsor-Geschenke pro Etage | 4–7 | Hype-Tabelle |
| Achievements pro Etage (Erstdurchlauf) | 12–16 von 29 | — |
| Lootboxen pro Etage | 15–20 | Achievements + Bosse + Meilensteine |
| Follower am Ende E1 | 1 200–1 500 | Kap. 7.6 |
| Max. Zuschauer E1 | 3 000–5 500 | Kap. 7.2 |

---

## 14. UX-Flows

Referenzauflösung **1920×1080**, `stretch_mode = canvas_items`, `aspect = expand`. Alle Menüs fokus-navigierbar
(Gamepad/Tastatur), erstes Element hat Fokus. Mindest-Touchziel **88 px** (Referenz).

### 14.1 Titel

`Boot (Logo NOVA SYNDIKAT „präsentiert“, 2 s) → Title`
Titel: 3D-Hintergrund TV-Studio, M.O.D.-Ikosaeder dreht sich, Logo „PRIME TIME DUNGEON“.
Menü: **Fortsetzen** (neuester Slot, nur wenn vorhanden) · **Neues Spiel** · **Laden** · **Optionen** · **Credits** · **Beenden** (nur PC).

### 14.2 Neues Spiel

1. Slot wählen (3 Slots; belegte zeigen Name, Etage, Level, Spielzeit, Datum) → bei belegtem: „Überschreiben?“
2. Name eingeben (Standard „Kai“, max. 12 Zeichen; Bildschirmtastatur für Gamepad/Touch)
3. Modus: **Prime Time** (Normal) / **Vorabendprogramm** (Leicht: Timer 30:00, Gegnerschaden ×0.75, EXP ×1.2) — jederzeit im Optionsmenü absenkbar, nicht anhebbar
4. Intro-Cutscene (B0) → Erkundung Etage 1

### 14.3 Erkundungs-HUD

Oben links: „● LIVE“-Badge (rot pulsierend) + Zuschauer (animierter Zähler) + Follower. Oben Mitte: **Timer** (mm:ss).
Oben rechts: Hype-Leiste (horizontal, 480 px) mit Markern bei 50/75/100. Unten: Chat-Ticker (32 px).
Minimap oben rechts unter Hype (nur besuchte Zellen, 200×200 px). Interaktionsprompt über Objekt.

### 14.4 Pausemenü (Esc / Start / Touch ☰; Timer pausiert)

Tabs: **Party** (Werte, EXP) · **Inventar** (benutzen außerhalb des Kampfes) · **Ausrüstung** · **Fähigkeiten** (Liste + Freischalt-Level) · **Achievements** (erhalten/verborgen „???“) · **Bestiarium** · **Optionen** (Lautstärke Master/Musik/SFX, Kampfgeschwindigkeit, Kamera-Empfindlichkeit, Kamera invertieren, Modus, Sprache) · **Zum Titel** (Warnung: „Fortschritt seit dem letzten Safe Room geht verloren.“).

### 14.5 Kampf-UI

| Element | Position / Größe | Inhalt |
|---|---|---|
| Zugreihenfolge | rechter Rand, vertikal; Eintrag 1: 96 px, 2–12: 64 px | Porträt-Icons (Party blau umrandet #4AA8FF, Gegner rot #E8455A, Zug grau), Geist-Vorschau |
| Befehlsmenü | unten links, 360×420 px | Angriff / Fähigkeit / Item / Stunt (mit Cooldown-Zahl) / Verteidigen / Flucht |
| Untermenü (Skills/Items) | rechts neben Befehlsmenü | Name, MP-Kosten, Element-Icon, Rang als 1–3 Uhr-Symbole, Beschreibung unten |
| Party-Panels | unten Mitte/rechts, je 380×110 px | Name, HP-Leiste + Zahl, MP-Leiste + Zahl, Status-Icons, Stunt-Bereitschaft |
| Gegner-Info | über dem Gegner | Name, HP-Leiste (Zahl erst nach erstem Sieg über den Typ), Status-Icons, Schwächen nach Entdeckung |
| Show-Leiste | oben | LIVE + Zuschauer + Hype-Leiste mit Schwellen-Markern; Sponsor-Banner oben rechts |
| Chat-Ticker | unten 32 px | — |
| Speed-Button | oben rechts | ×1 / ×2 |

Zielwahl: Pfeil/Highlight + Name; Links/Rechts wechselt, Bestätigen führt aus, Zurück bricht ab. Schadenszahlen: Popups (weiß normal, gelb Schwachstelle, orange Krit, grün Heilung, grau resistent).
Kampfende: Ergebnis-Panel (EXP-Leisten füllen sich, Level-Up-Banner, Credits, Drops, Follower +X) → Bestätigen → Erkundung.

### 14.6 Game Over „Sendeschluss“

Testbild-Effekt (Farbbalken-Shader), M.O.D. `death` bzw. `timer_zero`. Statistik (Zeit, Kills, Peak-Zuschauer).
Buttons: **Letzten Spielstand laden** (Gnadenfrist 3:00) · **Zum Titel**. `s.game_overs` +1 (bleibt im Slot erhalten, zählt Schmach).

### 14.7 Safe-Room-Menü

Beim Betreten: Heil-Animation + `safe_room_enter`. Menü (vertikale Liste links, Szene rechts):
**Speichern** · **Lootboxen (n)** · **Automat** · **Ausrüstung** · **Mopsula** (! wenn Szene verfügbar) · **Weiter**.

### 14.8 Touch-Layout (nur Querformat)

| Element | Position (Referenz 1920×1080) | Größe |
|---|---|---|
| Virtueller Stick | dynamisch: erscheint am Fingerpunkt in linker Bildhälfte; Ruhe-Anzeige bei (220, 860) | Radius 140 px, Deadzone 0.15; Auslenkung > 0.6 = Laufen, ≤ 0.6 = Schleichen |
| Kamera | Drag in rechter Bildhälfte (außerhalb von Buttons), Pinch = Zoom | — |
| Aktion (Schlag/Interagieren) | (1720, 880) | 150 px rund |
| Menü ☰ | (1840, 60) | 96 px |
| Kampf-Befehle | unten links, 2 Spalten × 3 Zeilen | je 300×96 px |
| Zielwahl | Gegner direkt antippen = auswählen, erneut antippen oder „OK“ (1720, 880) = ausführen | Trefferfläche ≥ 160 px um Gegner |
| Zugreihenfolge | rechter Rand, 10 Einträge | — |

---

## 15. Etage 2 (Stub) — „Passage Ewiger Rabatt“

| Feld | Wert |
|---|---|
| Thema | Versunkene Einkaufspassage unter der Unterstadt: tote Rolltreppen, Schaufenster, Food-Court mit leuchtenden Pilzen, Dauerdurchsagen „Nur heute! Nur heute! Nur heute!“ |
| Palette | Neon-Pink #FF4FA0, Kühlregal-Cyan #4FE6FF, Schimmel-Gelbgrün #C8E04A, Fliesen-Beige #D9CBB0 |
| Timer | **25:00** |
| `floor_mult` (Zuschauer) | 1.5 |
| Raster | 9×9 Zellen, prozedural aus Modulen (Seed pro Spielstand) |
| Ziel-Level | 7–10 |

| ID | Name | Lv | HP | STR/MAG/DEF/RES/SPD | weak / resist | Idee |
|---|---|---|---|---|---|---|
| `schaufensterpuppe` | Schaufensterpuppe | 8 | 90 | 28/8/22/12/12 | fire / ice | Auf der Karte: bewegt sich nur, wenn Kai wegschaut (Kamera-Frustum) → lauert auf Hinterhalt. Im Kampf: `e_pose` (`guard` + `taunt` auf sich). |
| `einkaufswagen_rudel` | Einkaufswagen-Rudel | 8 | 55 ×3 | 24/4/16/8/20 | shock / physical | Tritt immer zu dritt auf, sehr schnell; „Ramm-Kette“: Schaden steigt pro lebendem Rudelmitglied (+20 % je Wagen). |
| `rabattschild` | Rabattschild-Golem | 9 | 120 | 30/20/26/14/9 | ice / fire | Zeigt „−30 %“, „−50 %“, „−70 %“: Prozent = Schadensbonus des nächsten Angriffs, steigt jeden Zug — Vorschau lesen und vorher töten. |

**Boss-Idee:** „**Der Ausverkauf**“ (`boss_ausverkauf`) — ein Koloss aus verschmolzenen Regalen, Wühltischen und
Schnäppchenjägern. Mechanik „Countdown-Preisschild“: Ein Preisschild-Pseudo-Unit in der Zugreihenfolge zählt
„−10 % … −90 %“ herunter; bei −90 % „Black Friday“: Massen-Angriff. Der Countdown wird zurückgesetzt, wenn die Party
in einem Zug ≥ 3 verschiedene `action_key`s nutzt — Show-System und Kampf verzahnt. Quartier-Boss-Idee: „Filialleiterin
im Dauerlächeln“ (optional).

---

## 16. Anhang: Datei-Zuordnung & globale Konstanten

| Kapitel | Datei in `res://data/` | Top-Level-Struktur |
|---|---|---|
| 4 | `party.json` | `{ "kai": {base, growth, start_equipment, skills[]}, "mopsula": {...}, "start_inventory": [...], "start_credits": 50, "exp_curve": {"a": 15, "b": 1.7, "c": 15}, "level_cap": 10 }` |
| 3.5/3.6/4.5/4.6/5.1 | `skills.json` | Array von Skills (Party, Stunts, Gegner, Boss) — Felder Kap. 4.4, zusätzlich `success_base`, `success_lck`, `success_cap`, `fail_effect` für Stunts |
| 5 | `enemies.json` | Array: `id, name_key, level, stats{}, affinities{}, status_resist{}, exp, credits, drops[], field_speed, ai{}, visual{kit, colors}` |
| 5.4 / 2 | `floors.json` | `floor_1: { timer_sec: 1200, grid, zones, encounters{}, chests[], events[], safe_rooms[], spawners[], stairs }` |
| 6 | `items.json` | Array: `id, type (consumable|weapon|armor|accessory|key), equip_by[], stats{}, effect{}, price, sell` |
| 7.4 / 7.7 | `sponsors.json` | Array Sponsoren + `milestones[]` |
| 8 | `achievements.json` | Array: `id, name_key, trigger, condition, box, followers, mod_line` |
| 9 | `lootboxes.json` | `{ tiers{}, rarity_weights{}, pools{f1{}}, pity{rare: 4, epic: 8} }` |
| 10 / 11 / 7.5 | `mod_lines.json` | `{ "<key>": [ "<text>", ... ], "scenes": { "mop_scene_1": [ {speaker, text} ] } }` |
| 12 | `classes.json` | Array (Kap. 12.2) |

**Globale Konstanten** (`core/battle/battle_constants.gd` bzw. `core/show/show_constants.gd`):

| Konstante | Wert |
|---|---|
| `TICK_K` / `TICK_OFFSET` | 1000 / 10 |
| `RANK_DIVISOR` | 3.0 |
| `HASTE_MULT` / `SLOW_MULT` | 0.6 / 1.5 |
| `DMG_VARIANCE` | 0.9 – 1.1 |
| `CRIT_BASE` / `CRIT_PER_LCK` / `CRIT_CAP` / `CRIT_MULT` | 0.05 / 0.005 / 0.40 / 1.5 |
| `AFFINITY` | weak 1.5, normal 1.0, resist 0.5, immune 0.0 |
| `DEFEND_MULT` / `GUARD_DEF_MULT` | 0.5 / 1.5 |
| `POISON_PCT` | 0.08 |
| `TAUNT_CHANCE` | 0.80 |
| `FLEE_BASE` / `FLEE_PER_SPD` / `FLEE_PER_FAIL` / `FLEE_PREEMPT` / `FLEE_MIN` / `FLEE_MAX` | 0.40 / 0.03 / 0.15 / 0.25 / 0.10 / 0.95 |
| `POST_BATTLE_MP_REGEN` | 0.15 |
| `STUNT_COOLDOWN` | 3 |
| `TURN_PREVIEW` desktop / touch | 12 / 10 |
| `HYPE_START` / `HYPE_EXPLORE_FLOOR` / `HYPE_DECAY_INTERVAL` | 30 / 15 / 5.0 s |
| `SPONSOR_THRESHOLDS` / `MAX_GIFTS` normal / boss | [50, 75, 100] / 2 / 3 |
| `VIEWER_BASE` / `VIEWER_PER_FOLLOWER` | 1000 / 1.0 |
| `FOLLOWER_CONV_BASE` / `FOLLOWER_CONV_HYPE` | 0.01 / 0.02 |
| `TIMER_F1` / `TIMER_GRACE_ON_LOAD` | 1200 s / 180 s |
| `PITY_RARE` / `PITY_EPIC` | 4 / 8 |
