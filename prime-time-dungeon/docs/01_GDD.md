# PRIME TIME DUNGEON — Game Design Document (Vertical Slice)

> Grundlage: `00_BRIEF.md` (verbindlich). Dieses Dokument legt **Spielregeln, Inhalte und Zahlen** fest.
> Umfang: **Etage 1 komplett**, **Etage 2 angelegt (Stub)**, **Klassenwahl ab Etage 3 datenseitig vorbereitet**.
> **Rangfolge bei Widersprüchen:** `00_BRIEF` > `02_TECH` (APIs, Schemas, Pfade, ID-Format) > `01_GDD` (Zahlen, Formeln,
> Inhalte) > `03_ART` > `04`. Formeln und Zahlen dieses Dokuments übernimmt 02_TECH 1:1; Feldnamen und Dateistrukturen richten
> sich nach 02_TECH (Abbildung in Kap. 4.4 und Kap. 16).
> **IDs:** Tabellen nennen **Kurz-IDs** (z. B. `kanalratte`, `item_bandage`, `grp_a2`). Die Daten-IDs in `res://data/` entstehen
> daraus nach der **verbindlichen Präfix-Regel in Kap. 16.1** (z. B. `enm_kanalratte`, `itm_bandage`, `enc_f1_a2`).
> JSON-Beispiele, Bedingungsausdrücke und M.O.D.-Tags in diesem Dokument verwenden bereits die vollen Daten-IDs.
> **Texte:** Namen, Beschreibungen und Sprüche sind deutscher Quelltext = gettext-msgid, angezeigt über `tr(text)`
> (02_TECH §4.1). Es gibt keine separaten Text-Keys.
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
16. Anhang: IDs, Dateien, Konstanten, Abgleich mit 02_TECH

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

**Layout:** Etage 1 ist **handgebaut**: festes Raster **8 × 8 Zellen à 16 m** (`FloorLayout.ROOM_SIZE`, 02_TECH §7.1),
31 belegte Zellen. Daten in `floors.json → floor_1.layout` (Kap. 16.2); nur die Raum-Deko variiert per Seed. Etagen ohne
`layout` (ab Etage 2) erzeugt der prozedurale `DungeonGenerator`.

| Zone | ID | Zellen | Inhalt |
|---|---|---|---|
| A | `zone_platform` „Bahnsteig Nord“ | 8 | Start, Tutorial, Safe Room 1 `sr_kiosk` „Kiosk 24/7“, 4 Gegnergruppen, 1 Fahrscheinfresser, 4 Truhen, 2 Events, Streuner-Spawner |
| B | `zone_sewer` „Kanalisation“ | 9 | 4 Gegnergruppen, 5 Truhen, 2 Events, Safe Room 2 `sr_pumphouse` „Pumpenhaus“ (Grenze B/C), Streuner-Spawner |
| C | `zone_cellar` „Kellergewölbe“ | 8 | 3 Gegnergruppen, 4 Truhen (1 verschlossen), 1 Event, **Hausmeister-Büro** (Quartier-Boss) |
| D | `zone_track9` „Gleis 9“ | 6 | hinter dem Tor (benötigt `key_master`): 3 Gegnergruppen, 3 Truhen (1 verschlossen), Safe Room 3 `sr_signalbox` „Stellwerk“, **Thronsaal** (Etagenboss), **Treppe** |

Zonen-Paletten: 03_ART §2.2 (A Bahnsteig, B Kanalisation, C Kellergewölbe, D Gleis 9, Safe Room, Boss-Räume).

**Karte Etage 1** (x nach rechts/Osten, y nach unten/Süden; `Vector2i(x, y)`; Norden = −Z):

```text
        x=0        x=1        x=2        x=3        x=4        x=5        x=6        x=7
y=0   [D FB  ]---[D TR  ]---[D d3  ]      .       [C     ]---[C QB  ]   [C c2  ]      .
                    |          |                     |                     |
y=1      .       [D d2  ]---[D SR3 ]      .       [C c3  ]      .       [C ev  ]      .
                    |                                |                     |
y=2      .       [D d1  ]      .          .       [C     ]---[C c1  ]---[C     ]      .
                    ‖                                ‖                     |
y=3      .       [A a4  ]      .       [B b2  ]---[B ev  ]---[B b3  ]---[B SR2 ]      .
                    |                     |          |          |
y=4      .       [A a2  ]---[A a3  ]---[B     ]---[B b1  ]---[B     ]      .          .
                    |          |          |          |
y=5   [A rare]---[A ev  ]---[A SR1 ]   [B ev  ]---[B b4  ]      .          .          .
                    |
y=6      .       [A tut ]      .          .          .          .          .          .
                    |
y=7      .       [A ST  ]      .          .          .          .          .          .
```

`---`/`|` = offene Tür, `‖` = Tor (Kap. 2.6/2.8). Kürzel: ST Start, tut Tutorial, SR1–3 Safe Rooms, QB Quartier-Boss, FB Etagenboss, TR Treppe, ev Event. **Türregel:** Orthogonal benachbarte Zellen **derselben Zone** sind verbunden,
außer (5,0)↔(6,0). Zonenübergänge gibt es **nur** an: A(2,4)↔B(3,4), B(6,3)↔C(6,2), Tor `gate_track9` A(1,3)↔D(1,2)
(benötigt `itm_key_master`), Tor `gate_lever` B(4,3)↔C(4,2) (`requires: "event:fev_lever"`, öffnet bei Erfolg von `fev_lever`).
(`gate_track9`/`gate_lever` sind Namen in diesem Dokument; in den Daten ist ein Tor `{cell, dir, requires}`.)
Alle anderen Nachbarschaften zwischen Zonen sind Wände.

| Zelle | Zone | Art (`RoomCell.Kind`) | Name | Inhalt (Gruppe · Zustand / Truhe · Typ / Event / Sonstiges) |
|---|---|---|---|---|
| (1,7) | A | START | Kopfende Bahnsteig | Spawn Kai + Mopsula, Intro-Ende |
| (1,6) | A | NORMAL | Tutorial-Gang | `f1_g0` = `enc_f1_a1_tutorial` · IDLE, Blick Norden, dreht nie |
| (1,5) | A | NORMAL | Kreuzung | `fev_photo_drone`; `f1_c0` wood |
| (0,5) | A | NORMAL | Fundbüro | `f1_g4` = `enc_f1_a_rare` · IDLE (steht still); `f1_c1` metal (`itm_arm_safety_vest`) |
| (2,5) | A | SAFE | Kiosk 24/7 | `sr_kiosk` |
| (1,4) | A | NORMAL | Bahnsteighalle | `f1_g1` = `enc_f1_a2` · PATROL; `f1_c2` wood |
| (2,4) | A | NORMAL | Ostgang | `f1_g2` = `enc_f1_a3` · IDLE; `fev_lost_candidate` (Telefonzelle); Übergang B |
| (1,3) | A | NORMAL | Nordende | `f1_g3` = `enc_f1_a4` · PATROL; `f1_c3` wood; Tor `gate_track9` nach Norden |
| (3,4) | B | NORMAL | Kanaleinstieg | `f1_c4` wood |
| (4,4) | B | NORMAL | Sammelbecken | `f1_g5` = `enc_f1_b1` · PATROL |
| (5,4) | B | NORMAL | Überlauf | `f1_c5` metal (`itm_wpn_collar_studded`) |
| (3,5) | B | NORMAL | Rinnenkreuz | `fev_wheel`; `f1_c6` wood |
| (4,5) | B | NORMAL | Rattennest | `f1_g8` = `enc_f1_b4` · IDLE; `f1_c7` metal (`itm_smelling_salts` ×2) |
| (3,3) | B | NORMAL | Schieberkammer | `f1_g6` = `enc_f1_b2` · PATROL (Schamanen-Spruch B4) |
| (4,3) | B | NORMAL | Hebelraum | `fev_lever`; Tor `gate_lever` nach Norden |
| (5,3) | B | NORMAL | Rohrgang | `f1_g7` = `enc_f1_b3` · PATROL; `f1_c8` wood |
| (6,3) | B | SAFE | Pumpenhaus | `sr_pumphouse`; Übergang C nach Norden |
| (6,2) | C | NORMAL | Kellertreppe | `f1_c9` wood |
| (5,2) | C | NORMAL | Kohlenkeller | `f1_g9` = `enc_f1_c1` · PATROL |
| (4,2) | C | NORMAL | Hebelausgang | `f1_c10` wood |
| (6,1) | C | NORMAL | Waschkeller | `fev_broken_vending` |
| (6,0) | C | NORMAL | Heizungskeller | `f1_g10` = `enc_f1_c2` · IDLE; `f1_c11` metal (`itm_acc_gas_mask`) |
| (4,1) | C | NORMAL | Kellergang | `f1_g11` = `enc_f1_c3` · PATROL; `f1_c12` locked (`itm_wpn_fire_axe`) |
| (4,0) | C | NORMAL | Vorzimmer | Türschild „Zutritt nur für Personal“ |
| (5,0) | C | QUARTER_BOSS | Hausmeister-Büro | `f1_qb` = `enc_f1_boss_hausmeister` |
| (1,2) | D | NORMAL | Tor-Vorraum | `f1_g12` = `enc_f1_d1` · IDLE; `f1_c13` wood |
| (1,1) | D | NORMAL | Bahnsteig Gleis 9 | `f1_g13` = `enc_f1_d2` · PATROL |
| (2,1) | D | SAFE | Stellwerk | `sr_signalbox` |
| (2,0) | D | NORMAL | Gleisende | `f1_g14` = `enc_f1_d3` · IDLE; `f1_c14` locked (`itm_wpn_collar_signet`); `f1_c15` wood |
| (1,0) | D | STAIRS | Treppe | `stairs` |
| (0,0) | D | FLOOR_BOSS | Thronsaal (entgleister Wagen) | `f1_fb` = `enc_f1_boss_rattenkoenigin` |

Platzierung innerhalb der Zelle: Gruppen und Truhen mit `offset` (|x|,|y| ≤ 4.5 m, 02_TECH §7.3); Standard Gruppen (0, 0),
Truhen (−3.5, −3.5), zweite Truhe derselben Zelle (3.5, −3.5). PATROL-Wegpunkte: Quadrat (±4, ±4) um die Zellmitte, im Uhrzeigersinn.
Laufwege: Hauptpfad Start → Büro → Treppe ≈ 25 Zellwechsel ≈ 75 s reine Laufzeit bei 5.5 m/s.

### 1.4 Story-Beats Etage 1

| # | Beat | Ort / Auslöser | Inhalt | Ergebnis |
|---|---|---|---|---|
| B0 | **Intro** (Cutscene, ~90 s, Halten 1 s = überspringen) | Spielstart | Nachtschicht im Tierheim-Keller. Kai füttert den Mops „Graf“. Der Himmel wird zum Bildschirm, NOVA-SYNDIKAT-Logo, Gebäude falten sich weg („Rückbau“). Boden bricht. M.O.D. moderiert an: „Willkommen bei DUNGEON PRIME TIME! Sie sind live.“ Der Mops öffnet das Maul: „Endlich. Man versteht Uns.“ | Party gebildet. Kai hält Wischmopp (`wpn_mop`). |
| B1 | **Tutorial-Gang** | Zone A, Zellen (1,7)–(1,6) | Bewegung, Kamera, Feldschlag, Schleichen (M.O.D.-Textboxen, je max. 2 Zeilen). Zwei schlafende Kanalratten (Gruppe `grp_a1_tutorial`, Zustand `IDLE`, Blick nach Norden, drehen sich nie um). | Erzwingt den ersten Präventivschlag (Feldschlag oder Berührung von hinten, Kap. 2.4). |
| B2 | **Erster Kampf** | `grp_a1_tutorial` | Geführte Hinweise: Zugreihenfolge-Leiste, Angriff, Fähigkeit (Adelsflamme), Stunt-Hinweis nach Zug 2. Kann nicht verloren werden (Gegner-Schaden ×0.5, Flucht gesperrt, Party-HP fällt nicht unter 1; `EncounterDef.tutorial: true`). | Achievements `ach_first_blood` + `ach_first_win` → 2 Bronze-Boxen. **Countdown startet** nach diesem Sieg (`FloorDef.timer_start_after = "enc_f1_a1_tutorial"` → `FloorRun.timer_started = true`, M.O.D. `floor_start`: „Die Uhr läuft …“). |
| B3 | **Erster Safe Room** „Kiosk 24/7“ (`sr_kiosk`) | Zone A, (2,5) | Heilen, Speichern, Automat, Bronze-Boxen öffnen (Tutorial), Mopsula-Szene `scn_mop_1`. | Spieler versteht Loop. |
| B4 | **Kanalisation** | Zone B | Rattenschamanen raunen: „Die Königin hört von euch.“ (Kampfstart-Banner `ANNOUNCE` bei `grp_b2`). Event `fev_lever` „Verdächtiger Hebel“ öffnet Abkürzung `gate_lever` nach C. | Foreshadowing Rattenkönigin. |
| B5 | **Quartier-Boss: Der Hausmeister** | Zone C, Büro (5,0) | Türschild „Zutritt nur für Personal“. Cutscene: Er stempelt einen Mahnbescheid auf Kai. Kampf mit 3 Phasen. | Drop `key_master` (Generalschlüssel) → Tor `gate_track9` (A→D) und verschlossene Spinde öffnen sich. Silber-Box. Mopsula-Szene `scn_mop_2` beim nächsten Safe Room. |
| B6 | **Gleis 9** | Zone D | Treppe (1,0) sichtbar hinter dem Bahnsteig. Seitlich: Thronsaal (0,0) im entgleisten Wagen. Stellwerk `sr_signalbox` mit `scn_mop_4`. M.O.D. lockt (`stairs_found`): „Die Zuschauer wollen die Königin. Die Treppe läuft nicht weg. Die Uhr schon.“ | Wahl: Treppe sofort nehmen ODER Etagenboss. |
| B7 | **Etagenboss: Die Rattenkönigin von Gleis 9** (optional) | Thronsaal | Mopsula vs. Königin Adels-Streit, 3 Phasen inkl. „Einfahrender Zug“. | Gold-Box, `acc_queen_crown`, großer Follower-Schub. |
| B8 | **Ende: „Etage 2 folgt“** | Treppe | Etagen-Bilanz (Zeit, Kills, Zuschauer-Peak, Follower, Achievements; Kap. 2.8). M.O.D. `floor_end`: „Nach der Werbung: Etage 2.“ Autosave in den aktiven Slot (Stand: Etage 2, Start). Teaser-Kamerafahrt (Rolltreppe in eine versunkene Einkaufspassage) im Abspann → Titel. | Slice-Ende. |

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
| Schleichen | **2.5 m/s**, solange Action `sneak` gehalten wird (Shift / L3 / LT); Touch: Stick-Auslenkung ≤ 0.6 (Kap. 14.8). Hör-Radius der Gegner 4.0 → 1.5 m |
| Beschleunigung / Abbremsen | 30 m/s² / 40 m/s² |
| Drehgeschwindigkeit Modell | Slerp 12 rad/s zur Bewegungsrichtung |
| Gesteuerte Figur (06 §1) | **Kai** (Standard) oder **Graf Mopsula** — Wahl bei „Neues Spiel“ (Kap. 14.2), Wechsel jederzeit im Safe Room („Figur wechseln“, Kap. 14.7). Die andere Figur folgt. Tempo, Beschleunigung und Kamera sind für beide gleich (Timer-Balancing unverändert) |
| Kollision | Kai `CapsuleShape3D` r = 0.4 m, h = 1.7 m; Graf Mopsula r = 0.35 m, h = 0.9 m |
| Springen / Sprinten | keins |
| **Aktion** (eine Action `action`: F / Space / Enter, Gamepad A (Button 0), Touch-Button „Aktion“ 96 px) | Liegt ein Interactable im Radius 1.5 m und im 120°-Kegel vor der Figur (Prompt sichtbar) → **Interagieren** (hat Vorrang; Mopsula öffnet Truhen „mit der Schnauze“). Sonst die **Feldfähigkeit**: Kai **Feldschlag** (Bogen 100°, Reichweite 1.8 m, Dauer 0.45 s, Cooldown 0.6 s); Graf Mopsula **Bellen** (Kegel 120°, 4.0 m, 0.4 s, Cooldown 3.0 s): Gruppen im Kegel mit Sichtlinie sind 2.5 s **verdutzt** (stehen still, violettes „?!“, sehen und hören nichts). Bellen startet **nie** einen Kampf; jede Gruppe ist höchstens 1× je 15 s verdutzbar; Bosse und der Fahrscheinfresser „zucken nur“ |
| Begleiter:in folgt | Zielabstand 1.8 m hinter der gesteuerten Figur (Spur, ohne NavigationServer), Teleport, wenn > 10 m entfernt |

Q/E bleiben Kamera-Drehung (`cam_left`/`cam_right`). Es gibt **keine** getrennten Actions `attack`/`interact` und keine Action `sprint`.
Spielweisen: Kai eröffnet Kämpfe sauber (Feldschlag), der Graf schleicht vorbei oder erwischt verdutzte Gruppen von vorn.

### 2.2 Kamera (Werte identisch mit 02_TECH §7.3 und 03_ART §8.1)

| Parameter | Wert |
|---|---|
| Typ | `SpringArm3D` an Pivot (Kai + 1.4 m Höhe), Kollisionsmaske `world` |
| Armlänge | Standard **7.0 m**, Zoom 5.0–9.0 m (Mausrad / Pinch) |
| Pitch | Standard **−38°**, Grenzen −65° … −15° |
| Yaw | frei |
| Empfindlichkeit | Maus (rechte Taste halten) 0.005 rad/px, Stick 2.6 rad/s, Touch-Drag 0.006 rad/px; jeweils × `camera_sensitivity` |
| Auto-Recenter | nach 2.5 s ohne Kamera-Eingabe während Bewegung, Lerp 2.0/s hinter Kai |
| FOV | **60°** |
| Kollisionsabstand | 0.25 m |
| Follow-Glättung | Position Lerp 10/s |

### 2.3 Gegner auf der Karte (Symbol-Gegner)

Jedes sichtbare Gegner-Modell auf der Karte ist ein **Gruppensymbol** (`EncounterGroup`). Das Modell zeigt
den Anführer (erster Eintrag der Gruppe); kleine Schatten-Icons über dem Kopf zeigen die Gruppengröße (1–4).
Die Wahrnehmungswerte kommen aus `EnemyDef.explore` des Anführers.

| Zustand | Verhalten |
|---|---|
| `IDLE` | Steht, dreht sich alle 4 s um ±60° (Tutorial-Ratten: nie) |
| `PATROL` | Läuft Wegpunkte ab, **1.8 m/s** (`patrol_speed`) |
| `ALERT` | Bleibt stehen, „!“-Sprechblase, **0.6 s** Telegraph, dann `CHASE` |
| `CHASE` | Verfolgt mit `field_speed` des Gegnertyps (Tabelle Kap. 5.1) |
| `RETURN` | Zurück zum Leash-Punkt mit 3.0 m/s; ignoriert Spieler 2 s |

| Wahrnehmung | Wert | Feld in `EnemyDef.explore` (Default) |
|---|---|---|
| Verfolgungstempo | je Typ (Kap. 5.1) | `field_speed` (Pflicht) |
| Patrouillentempo | 1.8 m/s | `patrol_speed: 1.8` |
| Sichtweite / Sichtkegel | **10 m / 110°** (Raycast für Sichtlinie); Taubenschwarm 14 m | `sight_range: 10`, `sight_angle_deg: 110` |
| Hör-Radius (360°) | **4.0 m** beim Laufen, **1.5 m** beim Schleichen | `hear_run: 4.0`, `hear_sneak: 1.5` |
| Aufgeben der Verfolgung | 4 s ohne Sichtkontakt ODER > **20 m** vom Leash-Punkt ODER 8 s Gesamtverfolgung | `giveup_no_sight: 4`, `leash: 20`, `max_chase: 8` |
| Kontakt-Radius (löst Kampf aus) | **1.1 m** | Konstante `CONTACT_RADIUS` |
| Schonfrist nach Kampf / Flucht | Kai 2.0 s unverwundbar & unsichtbar; Gegner im Radius 6 m gehen in `RETURN` | Konstanten `GRACE_SEC`, `GRACE_RETURN_RADIUS` |

`fahrscheinfresser`: `explore = {field_speed: 0, sight_range: 0, hear_run: 0, hear_sneak: 0}` → bleibt `IDLE`, reagiert nie.
Bosse haben kein Symbolverhalten: Kampf beim Betreten des Radius 5 m um den Anker `boss_spot` (02_TECH §7.3).

### 2.4 Kampfauslösung & Erstschlag

Kampf startet bei **Kontakt** (Symbol ≤ 1.1 m an Kai) oder **Feldschlag-Treffer** auf ein Symbol.
Zur Gruppe gehören **alle Gegner des Symbols**; zusätzlich schließen sich **keine** weiteren Symbole an (klare Regel, lesbar).

Begriffe: `fwd_e` = Blickrichtung Gegner, `fwd_k` = Blickrichtung Kai, `d_ek` = normierte Richtung Gegner→Kai,
`d_ke` = Richtung Kai→Gegner (alle in der XZ-Ebene). **Rücken-Schwelle:** `Balance.BACK_DOT = -0.34` (≙ Winkel > 110°),
gleich für alle Regeln. Die Regel gilt identisch in 02_TECH §7.3.

| Ergebnis (`BattleSetup.Advantage`) | Bedingung (in dieser Reihenfolge geprüft) | Effekt im Kampf |
|---|---|---|
| **Präventivschlag** (`PREEMPTIVE`) | (a) Feldschlag trifft Symbol UND (`state` ∈ {`IDLE`,`PATROL`,`DAZED`} ODER `dot(fwd_e, d_ek) < BACK_DOT`) — ODER — (b) Kontakt mit einem **verdutzten** Symbol (`DAZED`, Bellen) aus **jeder** Richtung — ODER — (c) Kontakt, Symbol **nicht** in `CHASE` UND `dot(fwd_e, d_ek) < BACK_DOT` (die Figur berührt den Rücken) | Party startet mit `ctr = 0`, Gegner mit `ctr = base_delay` (voller Zug). Hype +3. Flucht +25 %. |
| **Hinterhalt** (`AMBUSH`) | Kontakt, Symbol in `CHASE` UND `dot(fwd_k, d_ke) < BACK_DOT` (Gegner kommt von hinten) | Gegner starten mit `ctr = 0`, Party mit `ctr = base_delay`. Hype +5 (Drama). |
| **Normal** (`NORMAL`) | alles andere (auch Feldschlag auf `ALERT`/`CHASE` von vorn) | Alle `ctr = roundi(base_delay × rng.randf_range(0.5, 1.0))` |

Bosse und Event-Kämpfe: immer **Normal**. Fahrscheinfresser: kann nie Hinterhalt auslösen (steht still).

### 2.5 Truhen

| Typ | `type` | Anzahl E1 | Inhalt (`contents` in `layout.chests[]`) | Öffnen |
|---|---|---|---|---|
| Holzkiste | `wood` | 10 | 10–25 Credits (gleichverteilt, `LootRoller.WOOD_CREDITS_MIN/MAX`) + 1 Wurf aus Pool `f1.common` (Kap. 9.3); `contents: []` | 0.6 s Animation |
| Metallspind | `metal` | 4 | 1 fester Inhalt: `contents: [{"kind": "item", "id": "<item_id>", "amount": n}]` | 0.8 s |
| Verschlossener Spind | `locked` | 2 | benötigt `itm_key_master` im Inventar; fester Inhalt | 1.0 s |

Positionen und feste Inhalte: Karte Kap. 1.3 (Metall: `itm_arm_safety_vest` A, `itm_wpn_collar_studded` B, `itm_smelling_salts` ×2 B,
`itm_acc_gas_mask` C; verschlossen: `itm_wpn_fire_axe` C, `itm_wpn_collar_signet` D). Ohne Schlüssel zeigt der Prompt
„Verschlossen. Ein Generalschlüssel wäre praktisch.“. Zufall: `SeedUtil.derive(floor_seed, "chest", k)`, k = Index aus der ID `f1_c<k>`.

Jede geöffnete Truhe: Hype +2, Zähler `s.chests_opened` +1. Geöffnete Truhen stehen in `FloorRun.opened_chests` (bleiben offen).

### 2.6 Events (Interactables mit Wahl, je 1× pro Etage)

Präfix **`fev_`** (Floor-Event); `evt_` ist für Live-Events reserviert (05_LIVE_MODUS). Daten: `floors.json → layout.events[] =
{id, type, cell, params}`; Logik `FloorEvent.resolve(event_id, choice, state, data, rng) -> Dictionary` (`core/dungeon/floor_event.gd`),
Darstellung `scenes/exploration/event_interactable.gd`.

| ID / `type` | Name | Zelle | Wahl | Ergebnis | `params` |
|---|---|---|---|---|---|
| `fev_photo_drone` / `photo_drone` | Kamera-Drohne „Lächeln!“ | (1,5) | **Posieren** (`pose`) / **Zertreten** (`smash`) | Posieren: Hype +15, Follower +20, M.O.D. `event_photo_drone_pose`. Zertreten: +30 Credits, Hype −5, M.O.D. `event_photo_drone_smash` (beleidigt). | `{"pose_hype": 15, "pose_followers": 20, "smash_credits": 30, "smash_hype": -5}` |
| `fev_lost_candidate` / `lost_candidate` | Herr Brettschneider in der Telefonzelle | (2,4) | **Heilitem geben** (`give:<item_id>`, Auswahl unter Inventar-Items mit Tag `heal`; ohne solches Item ausgegraut) / **Weitergehen** (`leave`) | Geben: gewähltes Item −1, erhält `itm_acc_lucky_ticket`, Follower +40, M.O.D. `event_lost_candidate_give`. Weitergehen: nichts, M.O.D. `event_lost_candidate_leave`. | `{"tag": "heal", "reward_item": "itm_acc_lucky_ticket", "followers": 40}` |
| `fev_wheel` / `wheel` | Glücksrad von DoomScroll+ | (3,5) | **Drehen (20 Cr)** (`spin`) / **Ignorieren** (`ignore`) | Gewichte: 35 `itm_bandage` ×2 · 25 +50 Cr · 15 `box_bronze` · 15 Niete („Werbepause“) · 10 Kampf `enc_f1_evt_pigeons` (2× Taubenschwarm, Normal). Max. 3 Drehungen. M.O.D. `event_wheel_spin` | `{"cost": 20, "max_spins": 3, "table": [{"weight": 35, "kind": "item", "id": "itm_bandage", "amount": 2}, {"weight": 25, "kind": "credits", "id": "", "amount": 50}, {"weight": 15, "kind": "box", "id": "box_bronze", "amount": 1}, {"weight": 15, "kind": "nothing", "id": "", "amount": 0}, {"weight": 10, "kind": "encounter", "id": "enc_f1_evt_pigeons", "amount": 1}]}` |
| `fev_lever` / `lever` | Verdächtiger Hebel | (4,3) | **Ziehen** (`pull`) / **Lassen** (`leave`) | 60 %: Tor `gate_lever` öffnet (`open_gate`; spart je Richtung 4 Zellwechsel ≈ 15 s und umgeht `grp_c1`), M.O.D. `event_lever_open`. 40 %: Flutwelle — alle Lebenden −15 % MaxHP (Fixschaden, mind. 1 HP bleibt), M.O.D. `event_lever_flood`, danach Kampf `enc_f1_evt_slime` (2× Kanalschleim, Normal); die Abkürzung bleibt zu. | `{"success": 0.60, "gate": "4,3,N", "flood_pct": 15, "encounter": "enc_f1_evt_slime"}` |
| `fev_broken_vending` / `broken_vending` | Kaputter Automat | (6,1) | **Treten** (`kick`) / **Lassen** (`leave`) | Erfolg mit Chance `0.50 + Kai.LCK × 0.01` (LCK inkl. Ausrüstung): 2× `itm_energy_krawumm`, M.O.D. `event_broken_vending_ok`. Misserfolg: Stromschlag, Kai −10 % MaxHP (mind. 1 HP bleibt), Hype +4, M.O.D. `event_broken_vending_fail`. | `{"base": 0.50, "per_lck": 0.01, "reward_item": "itm_energy_krawumm", "reward_amount": 2, "fail_pct": 10, "fail_hype": 4}` |

Regeln:
- **Abschluss:** Ein Event ist abgeschlossen, sobald eine wirksame Wahl getroffen wurde (Posieren/Zertreten, Geben/Weitergehen,
  erste Drehung, Ziehen, Treten). „Ignorieren“/„Lassen“ schließt nur den Dialog, das Event bleibt offen. Abschluss: Hype +5,
  `s.events_completed` +1, Trigger `event_completed`, `FloorRun.completed_events` += ID. Abgeschlossene Events sind nicht
  wiederholbar; das Glücksrad erlaubt weitere Drehungen bis insgesamt 3 (ohne erneuten Abschluss-Bonus).
- **Zufall:** `SeedUtil.derive(floor_seed, "event", k × 16 + event_uses[id])`, k = Index des Events in `layout.events`
  (`event_uses` = bisherige Nutzungen, z. B. Drehungen) → Neuladen ändert keinen Wurf.
- **Ablauf:** `Game.apply_floor_event(event_id, choice)` → `FloorEvent.resolve` (Rückgabe u. a. `completed`, Belohnungen, Hype,
  Follower, Schaden, `open_gate`, `encounter_id`, `mod_tag`; Details 02_TECH §7.4).
- Event-Kämpfe: kein Symbol, `group_id ""`, Vorteil Normal, Flucht erlaubt. Event-Dialoge sind blockierend → Timer pausiert.

### 2.7 Streuner (Nachschub zum Grinden)

Zonen A und B haben je einen Spawner (`layout.spawners[] = {zone, pool, interval_sec: 90}`). Solange der Etagen-Timer läuft und in der
Zone **kein** Streuner lebt, zählt eine Uhr hoch; bei **90 s** erscheint eine neue Gruppe aus dem Zonen-Pool (A: `enc_f1_a2`/`enc_f1_a4`,
B: `enc_f1_b1`/`enc_f1_b2`, gleich gewichtet, Zufall `SeedUtil.derive(floor_seed, "stray", n)`), Zustand `PATROL`, Uhr zurück auf 0.
Spawn-Zelle: Zelle der Zone, nicht START/SAFE, ohne lebende Gruppe, mit ≥ 2 Zellwechseln (BFS) Abstand zu Kai; bei mehreren die mit dem
größten Abstand, dann kleinstem y, dann kleinstem x. Gruppen-IDs `f1_s<n>`. Streuner werden nicht gespeichert (nach dem Laden: keine
Streuner, Uhren auf 0). Grinden kostet also Timer — gewollter Trade-off.

### 2.8 Treppe & Etagenende

- Treppe in Zelle (1,0) (`layout.stairs`), nur über das Tor `gate_track9` (benötigt `itm_key_master`) erreichbar.
  Erstes Betreten der Zelle: `FloorRun.stairs_found = true`, M.O.D. `stairs_found`.
- Interagieren → Bestätigung: „Etage verlassen? Offene Truhen und der Etagenboss bleiben zurück.“ [Abstieg] [Noch nicht]
- Abstieg (`Game.complete_floor()`), in dieser Reihenfolge:
  1. Timer stoppt; Trigger `floor_completed {floor, timer_left}`; M.O.D. `floor_end`.
  2. **Etagen-Bilanz** (`scenes/ui/floor_summary.tscn`) aus `FloorRun.stats = {time_used, kills, viewers_peak, followers_gained, achievements}`.
  3. Nächste Etage existiert (`floor_2`): `Game.start_floor(2)` + `Save.autosave()` (aktiver Slot, Stand Etage 2, Ort `start`).
  4. Ist sie `playable == false` (Slice): Abspann (`SCENE_CREDITS`) mit Teaser-Kamerafahrt → Titel; sonst Erkundung der neuen Etage.
- Laden eines Slots, dessen Etage nicht spielbar ist → direkt Abspann → Titel.

### 2.9 Etagen-Timer

| Regel | Wert |
|---|---|
| Startwert Etage 1 | **20:00** (`FloorDef.timer_seconds = 1200`); Modus „Vorabendprogramm“ ×1.5 = **30:00** |
| Start | erst nach dem **Sieg über `enc_f1_a1_tutorial`** (B2): `FloorDef.timer_start_after` → `FloorRun.timer_started = true` (Signal `floor_timer_started`). Vorher steht der Timer. |
| Läuft nur in | Erkundung (`Game.timer_running`). **Pausiert** in Kampf, Safe Room, Menüs, Cutscenes, blockierenden Dialogen (`Events.mod_said(…, blocking = true)` bis `dialog_finished`), Event-Dialogen und beim Lootbox-Öffnen |
| Warnpunkte | `FloorDef.timer_warnings = [600, 300, 60]` (Sekunden Rest) |
| Warnung 10:00 | nur Chat-Ticker (Tag `timer_warn_600`, Stimme `chat`), kein M.O.D. |
| Warnung 5:00 | M.O.D. `timer_warn_300`, Musik-Layer „Tension“, Timer-HUD orange, Hype +10 (einmalig) |
| Warnung 1:00 | M.O.D. `timer_warn_60`, Timer rot pulsierend, Alarm, alle 10 s leichter Screenshake (0.15 Stärke, 0.3 s) und Deckenputz-VFX, Hype +15 (einmalig) |
| ≤ 0:10 | HUD spielt jede volle Sekunde `Sfx` `timer_warn` (Piep) |
| **0:00** | **Etagenkollaps**: 3 s Einsturz-Cutscene (M.O.D. `timer_expired`) → **Game Over** (Ursache `timer`) |
| Gnadenfrist beim Laden | `Save.load_slot`: `time_left = maxf(time_left, 180.0)` (`TIMER_GRACE_ON_LOAD`) — verhindert Softlock |

**Modus** (`GameState.difficulty`): `&"prime"` (Prime Time, Standard) oder `&"vorabend"` (Vorabendprogramm): Timer ×1.5 (`EASY_TIMER_MULT`),
Gegnerschaden ×0.75 (`EASY_ENEMY_DMG`), EXP ×1.2 (`EASY_EXP`, abgerundet). Wahl bei „Neues Spiel“; im Optionsmenü nur von Prime Time
auf Vorabend umstellbar, nie zurück. Schaden/EXP wirken sofort, der Timer-Faktor ab dem nächsten Etagenstart.

---

## 3. Kampf (CTB — Conditional Turn-Based)

### 3.1 Grundprinzip

Jede Einheit hat einen Zähler `ctr: int` (Ticks bis zum nächsten Zug; im Code `Combatant.ctb_counter`, Klasse `CTBQueue`). Es handelt
immer die Einheit mit dem kleinsten `ctr`. Nach ihrer Aktion bekommt sie einen neuen `ctr` abhängig von **SPD** und **Rang** der Aktion.
Die Formeln dieses Kapitels ersetzen alle abweichenden Formeln in 02_TECH §5.5/§5.9 (Rangfolge: Zahlen = GDD).

### 3.2 Formeln (kanonisch)

```text
TICK_K      = 1000
TICK_OFFSET = 10

base_delay(spd)  = roundi(TICK_K / (spd + TICK_OFFSET))            # CTBQueue.base_delay(spd: int) -> int
status_mult      = 0.6 bei haste, 1.5 bei slow, sonst 1.0           # StatusDef.tick_speed_mult; haste und slow heben sich auf (s. 3.9)
delay(unit, rank)= max(1, roundi(base_delay(unit.spd_eff) * rank / 3.0 * status_mult))   # CTBQueue.on_acted(c, rank)
```

`spd_eff` = SPD inkl. Ausrüstung und Status-`stat_mult`.

| SPD | 5 | 7 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 19 | 20 | 25 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `base_delay` | 67 | 59 | 53 | 50 | 48 | 45 | 43 | 42 | 40 | 38 | 37 | 34 | 33 | 29 | 25 |

**Aktionsränge** (Feld `rank` in Skills; Items über ihren `use_skill`):

| Rang | Faktor | Verwendung |
|---|---|---|
| 2 | ×0.67 | Item, Verteidigen, Flucht, leichte Heilung/Buffs |
| 3 | ×1.00 | Angriff, Standard-Fähigkeiten |
| 4 | ×1.33 | starke Fähigkeiten, Stunts |
| 5 | ×1.67 | Finisher, Gegner-Spezialangriffe |
| 6 | ×2.00 | Boss-Ultimates |

(Rang 1 = ×0.33 ist reserviert für spätere Klassen-Passiva, im Slice ungenutzt.)

**Startwerte** (`CTBQueue.setup`): Normal `roundi(base_delay × rng.randf_range(0.5, 1.0))`; Präventiv Party `0`, Gegner `base_delay`;
Hinterhalt Gegner `0`, Party `base_delay` (Kap. 2.4). Hinzugerufene Einheiten (`CTBQueue.add`): `roundi(base_delay × 0.5)`.
Wiederbelebte: `base_delay`. Pseudo-Einheiten: fester Wert aus den Daten (Kap. 5.3).

### 3.3 Ablauf

```text
battle_start:
  for u in units: u.ctr = start_ctr(u, advantage)          # 3.2
  on_enter der ersten Boss-Phase ausführen (Kap. 3.11)
loop:
  actor = argmin(ctr) mit Tie-Break: Party vor Gegner vor Pseudo-Einheit → höhere SPD → kleinerer Slot-Index
  dt = actor.ctr; for u in alive_units + pseudo_units: u.ctr -= dt
  turn_start(actor):  Verteidigen endet; stun entfernen; Statuse mit tick_timing "turn_start" ticken (poison: 8 % MaxHP, min 1, kann töten)
  action(actor)       # Spieler wählt / KI wählt / Pseudo-Einheit führt ihre feste Aktion aus
  turn_end(actor):    Statusdauern des Akteurs −1 (Status mit 0 entfernt), außer Statuse, die in diesem Zug auf ihn gelegt wurden;
                      Stunt-Cooldown −1 (außer im Stunt-Zug selbst, s. 3.6);
                      actor.ctr = delay(actor, action.rank) + self_delay   # self_delay: Verzögerungen, die den Akteur im eigenen Zug
                                                                           # trafen (Stunt-Fehlschlag delay_pct, stun auf sich), sonst 0
  Sieg/Niederlage prüfen; Show-Auswertung der Events (Kap. 7)
```

- Status-Dauern zählen **eigene Züge** des Trägers. Ausnahme `stun` (Kap. 3.9): wirkt beim Anlegen, endet zu Beginn des nächsten eigenen Zugs.
- Ein Status, der **im eigenen Zug** auf den Träger gelegt wird (z. B. `kai_taunt` auf sich), wird an diesem `turn_end` nicht
  heruntergezählt → „3 eigene Züge“ heißt immer: die 3 folgenden eigenen Züge.
- Tote Einheiten fallen aus der Zugliste. Wiederbelebte bekommen `ctr = base_delay` (voller Zug).
- Summons füllen freie Gegner-Slots (max. 4 lebende Gegner); überzählige Beschwörungen verfallen.

### 3.4 Zugreihenfolge-Vorschau

- Rechte Bildschirmkante, **12 Einträge** (Desktop/Gamepad), **10 Einträge** (Touch). Eintrag 1 = aktueller Akteur (groß).
  Kern: `CTBQueue.PREVIEW_LENGTH = 12`, Event `CTB_ORDER.order` mit 12 IDs; die Touch-Leiste zeigt die ersten 10.
- Algorithmus: Kopie aller `ctr`-Werte, dann 12× „nächsten Akteur ziehen“ simulieren. Für den **aktuellen Akteur**
  wird der **Rang der gerade markierten Aktion** verwendet (`pending_rank`), für alle anderen Rang 3.
- **Ziel-Vorschau:** Ist eine Aktion mit `stun`/`slow`/`haste` markiert und ein Ziel ausgewählt, zeigt die Leiste die
  verschobene Position des Ziels als **Geist-Icon** (50 % Alpha) — wie FF10.
- Pseudo-Einheiten (Zug der Rattenkönigin, Kap. 5.3) erscheinen in der Leiste mit eigenem Icon.

```gdscript
func preview(n: int, pending_rank: int, hypothetical: Dictionary = {}) -> PackedStringArray:
    # hypothetical: { combatant_id: ctr_override } für Ziel-Vorschau
    var sim: Dictionary = {}  # combatant_id -> ctr
    ...
    # Akteur bekommt delay(actor, pending_rank) nach seinem ersten Eintrag, danach rank 3
```

### 3.5 Befehle

| Befehl | ID (`BattleCommand.Kind`) | Rang | Wirkung |
|---|---|---|---|
| **Angriff** | `ATTACK` | 3 | `attack_skill` des Charakters (`skl_attack_kai` / `skl_attack_mopsula`): Einzelziel, `power 100`, `damage_type physical`, Element = `attack_element` der Waffe (Default `physical`) |
| **Fähigkeit** | `SKILL` | lt. Skill | Liste der freigeschalteten Skills (Kap. 4.5/4.6), MP-Kosten |
| **Item** | `ITEM` | 2 | Verbrauchsitem aus Inventar (Kap. 6.1), Wirkung über `use_skill` |
| **Stunt** | `STUNT` | 4 | Charakter-Stunt (Kap. 3.6), kein MP, **Cooldown 3 eigene Züge** |
| **Verteidigen** | `DEFEND` | 2 | Schaden ×0.5 bis zum eigenen nächsten Zug; stellt `maxi(2, ceili(MaxMP × 0.05))` MP wieder her (Event `MP_CHANGE`) |
| **Flucht** | `FLEE` | 2 | Fluchtversuch (3.10); bei `EncounterDef.can_flee == false` (Bosse, Tutorial) ausgegraut |

### 3.6 Stunts (Kern-USP im Kampf)

Riskante Show-Aktion: Erfolg = viel Schaden + viel Hype; Fehlschlag = Peinlichkeit, aber trotzdem etwas Hype.

| ID | Charakter | Name | Ziel | Erfolg | Wirkung bei Erfolg | Fehlschlag |
|---|---|---|---|---|---|---|
| `stunt_kai_suplex` | Kai | **Bahnsteig-Suplex** | 1 Gegner | `0.60 + LCK × 0.01`, max 0.85 | `power 230`, `physical`, STR, kann kritisch treffen | Kai erleidet 10 % MaxHP, `ctr += roundi(base_delay × 0.5)` („liegt auf dem Rücken“) |
| `stunt_mop_entrance` | Mopsula | **Auftritt Seiner Durchlaucht** | alle Gegner | `0.55 + LCK × 0.01`, max 0.85 | `power 140`, `fire`, MAG | Mopsula stolpert über den Umhang: Status `stun` auf sich selbst |

```text
success_chance = clamp(success_base + LCK_eff * success_lck + (target_is_boss ? success_boss_mod : 0.0), 0.05, success_cap)
```

Gegen Bosse: `success_boss_mod = −0.15` (Kai L5 mit LCK 10: 0.70, gegen Bosse 0.55). Hype: Erfolg +20, Fehlschlag +8 (Kap. 7).
Cooldown: Nach dem Stunt-Zug gilt `Combatant.stunt_cooldown = 3`; jedes folgende eigene `turn_end` −1; Stunt wählbar bei 0
(→ gesperrt in den 3 folgenden eigenen Zügen). Kampfstart: 0. Datenfelder (Kap. 4.4):

| Feld | `skl_stunt_kai_suplex` | `skl_stunt_mop_entrance` |
|---|---|---|
| `category` / `rank` / `cooldown` | `stunt` / 4 / 3 | `stunt` / 4 / 3 |
| `success_base` / `success_lck` / `success_cap` / `success_boss_mod` | 0.60 / 0.01 / 0.85 / −0.15 | 0.55 / 0.01 / 0.85 / −0.15 |
| `fail_effect` | `{"self_dmg_pct": 10, "delay_pct": 50, "status": ""}` | `{"self_dmg_pct": 0, "delay_pct": 0, "status": "sts_stun"}` |

`self_dmg_pct` = Fixschaden in % MaxHP (kann nicht KO machen, mind. 1 HP), `delay_pct` = `ctr += roundi(base_delay × pct / 100)`.

### 3.7 Schaden & Heilung

```text
# Schaden (damage_type "physical" | "magical": Angriff, Skills, Stunts)
A = (damage_type == "physical") ? STR_eff : MAG_eff     # _eff = Basis + Ausrüstung (Waffen-„ATK“ = stats.str, Kap. 6.2) × Status-stat_mult
D = (damage_type == "physical") ? DEF_eff : RES_eff     # guard: stat_mult def/res 1.5 → D × 1.5 (GUARD_DEF_MULT)
raw = A * A / (A + D) * power / 100.0
raw *= rng.randf_range(0.9, 1.1)                       # DMG_VARIANCE_MIN / MAX
if crit: raw *= 1.5                                    # nur damage_type "physical"
raw *= affinity_mult(target, element)                  # element_mods: weak 1.5 | normal 1.0 | resist 0.5 | immune 0.0
if target.defending: raw *= 0.5                        # DEFEND_MULT
if combo_second_hit: raw *= 1.1                        # COMBO_MULT, Kap. 7.3; DamageCalc.compute(..., combo_second_hit: bool)
if attacker is enemy: raw *= setup.enemy_dmg_mult             # 1.0; Vorabend 0.75 (EASY_ENEMY_DMG); Tutorial × 0.5 (Party-HP fällt dort nie unter 1)
dmg = (affinity == immune) ? 0 : max(1, roundi(raw))

# Kritisch
crit_chance = clamp(0.05 + LCK_eff * 0.005 + equip.crit_bonus + skill.crit_bonus, 0.0, 0.40)

# Fixschaden (damage_type "fixed": Items, Zug, Prozentschaden): Wert = SkillDef.power (Betrag);
# ignoriert A/D, Varianz und Krit, beachtet Affinität, Verteidigen und enemy_dmg_mult (bei Gegnerquelle)
fixed_dmg = roundi(power * affinity_mult * (0.5 if defending else 1.0))

# Heilung (damage_type "heal", Feld heal_mode)
heal_mode "mag":   roundi((MAG_eff * 1.5 + 10) * power / 100.0 * rng.randf_range(0.95, 1.05))   # HEAL_STAT_MULT, HEAL_BASE, HEAL_VARIANCE
heal_mode "pct":   roundi(MaxHP * power / 100.0)
heal_mode "fixed": power
Wiederbelebung: Ziel single_ally_ko + heal_mode "pct" → HP = roundi(MaxHP * power / 100.0)
```

- Treffer verfehlen **nie**: Alle Slice-Skills haben `accuracy = −1` (Default), `DamageCalc.hit_chance()` liefert 1.0; kein `MISS`.
- HP 0 → KO. KO-Party-Mitglieder stehen nach gewonnenem Kampf **oder erfolgreicher Flucht** mit **1 HP** wieder auf (`KO_REVIVE_HP`).
- Statuseffekt-Chance: `chance × (1 − target.status_resist.get(status_id, 0.0))` (`DamageCalc.status_chance`); kein LCK-Anteil.
  `status_immune` blockt vollständig (`STATUS_BLOCKED`). Bosse haben `status_resist {"sts_stun": 0.5, "sts_slow": 0.5}`.

### 3.8 Elemente & Affinitäten

Elemente (= `DataValidator.ELEMENTS` = `Elements.ALL`): `none`, `physical`, `fire` (Feuer), `ice` (Eis), `shock` (Blitz), `poison` (Gift).
`none` nur für Heil-/Support-Aktionen (immer ×1.0). Der Basisangriff hat `physical`. Keine weiteren Elemente im Slice.
Affinitäten pro Einheit als `element_mods` (Dictionary), nicht genannte = 1.0; `Elements.multiplier` gilt für alle Elemente außer `none`:

| Affinität | `element_mods`-Wert | UI-Popup |
|---|---|---|
| `weak` | 1.5 | „SCHWACHSTELLE!“ (gelb) |
| `normal` | 1.0 | — |
| `resist` | 0.5 | „RESISTENT“ (grau) |
| `immune` | 0.0 | „IMMUN“ (weiß); `immune` gegen `poison` heißt zusätzlich `status_immune: ["sts_poison"]` |

Absorption (negative Werte) gibt es im Slice nicht. Darstellung: Element `poison` nutzt Vfx/Sfx `toxic` (`Vfx.for_skill` bildet ab).

### 3.9 Statuseffekte (genau 6, `statuses.json`)

| ID | Name | Dauer | Wirkung | Quelle (Beispiele) | Icon-Farbe |
|---|---|---|---|---|---|
| `poison` | Vergiftet | 4 eigene Züge | Zugbeginn: −8 % MaxHP (min 1). Heilung durch `item_antidote`, `kai_first_aid`, `mop_mass_lick` | Gift-Skills | #7CC242 |
| `stun` | Betäubt | bis zum nächsten eigenen Zug | Beim Anlegen sofort `ctr += base_delay` (Bosse: ×0.5). Solange aktiv: nicht erneut betäubbar. Wird zu Beginn des nächsten eigenen Zugs entfernt (der Zug findet statt). | `kai_cable_whip`, Stunt-Fehlschlag | #F5D90A |
| `slow` | Verlangsamt | 3 eigene Züge | `delay × 1.5` | `kai_leash_trip`, `mop_frost_sneeze`, Spinnennetz | #5B8DEF |
| `haste` | Turbo | 3 eigene Züge | `delay × 0.6` | `mop_royal_decree`, Sponsor KRAWUMM | #FF7A1A |
| `guard` | Gepanzert | 3 eigene Züge | DEF und RES ×1.5 in der Schadensformel | `kai_taunt`, Sponsor Panzerkeks | #9AA7B8 |
| `taunt` | Provoziert | 3 eigene Züge | Gegner-KI wählt mit 80 % den Träger als Ziel (nur Einzelziel-Aktionen) | `kai_taunt` | #E8455A |

Neu angelegter gleicher Status setzt die Dauer auf den neuen Wert zurück (`turns_left = neu`, stapelt nicht; Ausnahme `stun`: blockiert).
`haste` und `slow` heben sich auf: Das neue entfernt das alte (`excludes`). Verteidigen ist **kein** Status. Dauer im Skill: `turns` 1..99
(99 = Rest des Kampfes). Datenzeilen (`StatusDef`, Felder nach 02_TECH §4.4.1 inkl. der hier benötigten Erweiterungen):

| `id` | `kind` | `default_turns` | `tick_timing` / `tick_pct` / `tick_min` | `tick_speed_mult` | `flags` | `excludes` | `element` |
|---|---|---|---|---|---|---|---|
| `sts_poison` | debuff | 4 | `turn_start` / −8 / 1 | 1.0 | — | — | `poison` (blockiert bei `element_mods.poison == 0.0`) |
| `sts_stun` | debuff | 1 | — | 1.0 | `["delay_on_apply"]` | — | — |
| `sts_slow` | debuff | 3 | — | 1.5 | — | `["sts_haste"]` | — |
| `sts_haste` | buff | 3 | — | 0.6 | — | `["sts_slow"]` | — |
| `sts_guard` | buff | 3 | — | 1.0 | `["guard"]` (D × `GUARD_DEF_MULT` 1.5) | — | — |
| `sts_taunt` | buff | 3 | — | 1.0 | `["taunt"]` | — | — |

Flag `delay_on_apply` (nur `sts_stun`): beim Anlegen `ctr += roundi(base_delay × (Boss ? 0.5 : 1.0))`, Entfernen am `turn_start` des
Trägers, nicht erneut anwendbar, solange aktiv.

### 3.10 Flucht

```text
flee_chance = clamp(0.40 + (avg_spd_party - avg_spd_enemies) * 0.03       # avg über lebende Einheiten, SPD_eff
                    + 0.15 * failed_flee_attempts                          # BattleState.failed_flee_attempts
                    + (0.25 if advantage == PREEMPTIVE else 0.0), 0.10, 0.95)
```

- Boss/Tutorial: nicht möglich (Befehl ausgegraut, Tooltip: „Die Regie lässt das nicht zu.“).
- `item_smoke` = 100 % (`flee_guaranteed: true`; nicht bei `can_flee == false`).
- Erfolg: Kampf endet ohne EXP/Credits/Drops; Gegner-Symbol bleibt auf der Karte (`RETURN`); Hype −30; Follower −1 % (`floori`).
- Fehlschlag: Zug verbraucht (Rang 2), Hype −5, `failed_flee_attempts` +1.

### 3.11 Gegner-KI (datengetrieben)

Jeder Gegner hat in `enemies.json` ein Feld `ai` (ersetzt das Profil-Modell `basic/aggressive/support/boss`). Reguläre Gegner:

```json
"ai": {
  "type": "weighted",
  "actions": [
    { "skill": "skl_e_bite",        "weight": 3, "target": "random" },
    { "skill": "skl_e_gnaw_poison", "weight": 1, "target": "not_status:sts_poison" },
    { "skill": "skl_e_rat_heal",    "weight": 5, "target": "ally_lowest_hp_pct", "cond": { "ally_hp_below": 0.5 } }
  ]
}
```

| Bedingung (`cond`, alle Schlüssel müssen gelten; fehlt = immer) | Bedeutung |
|---|---|
| `self_hp_below: f` / `self_hp_above: f` | eigener HP-Anteil < f / > f |
| `ally_hp_below: f` | mind. ein Verbündeter (inkl. selbst) unter f |
| `turn_mod: [n, r]` | `own_turn_count % n == r` (erster eigener Zug = 0) |
| `allies_alive_below: n` | weniger als n lebende Gegner (inkl. selbst; für Beschwörungen) |
| `once: true` | max. 1× pro Kampf |
| (implizit) | Aktion nur, wenn MP ≥ `mp_cost`; Beschwörung nur bei freiem Slot |

`AI_CONDITIONS = ["self_hp_below", "self_hp_above", "ally_hp_below", "turn_mod", "allies_alive_below", "once"]`.

| Ziel-Regel (`target`, `AI_TARGETS`) | Bedeutung |
|---|---|
| `random` | zufälliges lebendes Party-Mitglied |
| `lowest_hp_pct` | Party-Mitglied mit niedrigstem HP-Anteil |
| `highest_hp` | höchste absolute HP |
| `not_status:<status_id>` | zufällig unter denen ohne diesen Status; gibt es keins, `random` |
| `self` / `all_enemies` (= ganze Party) / `all_allies` / `ally_lowest_hp_pct` | selbsterklärend |

**Auswahl** (`EnemyAI.choose`): Aktionen filtern (Bedingungen + MP) → gewichteter Zufall mit Kampf-`rng` → Ziel nach Regel
(Gleichstand: kleinerer Slot). **Taunt-Override:** bei Einzelziel gegen die Party und einem Party-Mitglied mit `taunt`: 80 % dieses Ziel.
Bleibt nach dem Filtern nichts übrig: `attack_skill` (`skl_e_strike`, Kap. 5.1) auf `random`.

**Bosse:** `ai = {"type": "phased", "actions": []}`, dazu das `EnemyDef`-Feld `phases` (Reihenfolge = Phasenfolge, absteigend nach `hp_above`):

```json
"ai": { "type": "phased", "actions": [] },
"phases": [
    { "hp_above": 0.60,
      "on_enter": [ { "op": "say", "tag": "boss_intro:enm_boss_hausmeister" } ],
      "actions":  [ { "skill": "skl_b_rules", "weight": 10, "target": "self", "cond": { "once": true } },
                    { "skill": "skl_b_broom", "weight": 3, "target": "random" },
                    { "skill": "skl_b_keys",  "weight": 1, "target": "all_enemies" } ] },
    { "hp_above": 0.25,
      "on_enter": [ { "op": "summon", "enemy": "enm_kanalratte", "count": 1 },
                    { "op": "say", "tag": "boss_phase:enm_boss_hausmeister:2" } ],
      "actions":  [ "…" ] },
    { "hp_above": 0.0,
      "on_enter": [ { "op": "status_self", "status": "sts_haste", "turns": 5 },
                    { "op": "say", "tag": "boss_phase:enm_boss_hausmeister:3" } ],
      "actions":  [ "…" ] }
]
```

- Aktive Phase = erste Phase, deren `hp_above` kleiner ist als der aktuelle HP-Anteil (letzte Phase immer `hp_above: 0.0`).
- `on_enter` läuft beim Kampfstart für Phase 1 und bei jedem Phasenwechsel als **freie Aktion** ohne `ctr`-Änderung (Event `PHASE_CHANGE`).
- Phasenwechsel wird nach **jedem Schadensereignis** geprüft und sofort vollzogen. Phasen werden nie übersprungen: Fällt die HP über
  mehrere Schwellen, werden alle Zwischenphasen nacheinander betreten (jede mit ihrem `on_enter`).
- `on_enter`-Operationen (`op`): `say {tag}` · `status_self {status, turns}` · `summon {enemy, count}` (füllt freie Slots) ·
  `fixed_damage_self {amount, min_hp: 1}` · `add_pseudo {unit, ctr}` · `remove_pseudo {unit}`.

**Sonder-Effekte in Skills** (Feld `special`): `{"kind": "steal_credits", "max": 40, "refund_on_win": true}` (`e_fine`, Event
`CREDITS_STOLEN`) und `{"kind": "escape"}` (`e_escape`, Event `ESCAPED`; die Einheit verlässt den Kampf ohne EXP/Credits/Drops). Gestohlene Credits gibt es zurück, wenn der Dieb
**KO** geht; flieht er, sind sie weg. Endet ein Kampf, weil alle verbliebenen Gegner geflohen sind, ist das ein Sieg (`VICTORY`)
ohne Belohnung für die Geflohenen; die Gruppe verschwindet von der Karte.

### 3.12 Kampfende & Belohnung

- **Sieg:** EXP (volle Summe für jedes lebende Mitglied, KO-Mitglieder 50 %, im Modus Vorabend ×1.2), Credits (Overkill-Gegner ×1.25,
  Kap. 7.3), Drops (jeder Gegner würfelt einzeln, `chance × (1 + avg_party_LCK / 100)`, `avg_party_LCK` über alle Mitglieder, LCK_eff),
  Follower-Konvertierung (Kap. 7.6), **„Werbepause-Regeneration“**: alle lebenden Mitglieder +`ceili(MaxMP × 0.15)` MP
  (`BattleBridge.apply_result`). Danach stehen KO-Mitglieder mit 1 HP auf.
- **Niederlage** (alle KO): Game Over „Sendeschluss“ (Kap. 14.6).
- **Kampfgeschwindigkeit:** `battle_speed` ∈ {1.0, 2.0} (Animationen), Action `toggle_speed` = Taste R / Gamepad R3 (Button 8) /
  Touch-Button „»“; Default in den Optionen.

---

## 4. Party

### 4.1 Werte-Formel

```text
stat(L) = floori(base + growth * (L - 1)) + Ausrüstung          # Progression.base_stats_at + total_stats
```

Level-Up: HP/MP steigen um die Differenz (aktuelle Werte + Delta), **keine** Vollheilung. Level-Cap im Slice: **10**
(`Balance.LEVEL_CAP = 10`, ersetzt `MAX_LEVEL 99`).

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
**Startinventar:** 3× `item_bandage`, 1× `item_antidote`, **50 Credits** — steht in `party.json → start` und wird von
`GameState.create_new` gelesen (keine hartkodierten Werte). Beide haben `status_resist {}` und `element_mods {}`.

`party.json` (Struktur nach 02_TECH §4.1/§4.4.5, Werte aus diesem Kapitel; Kai analog mit `battle_slot 0`, `attack_skill
"skl_attack_kai"`, Stunt `skl_stunt_kai_suplex`, Modell laut 03_ART §5.5):

```json
{
  "schema": 1,
  "start": { "inventory": { "itm_bandage": 3, "itm_antidote": 1 }, "credits": 50 },
  "entries": [
    { "id": "mopsula", "name": "Mopsula", "title": "Graf", "battle_slot": 1,
      "base_stats": { "hp": 42, "mp": 30, "str": 5, "mag": 13, "def": 6, "res": 11, "spd": 14, "lck": 12 },
      "growth":     { "hp": 6.0, "mp": 4.0, "str": 0.6, "mag": 2.2, "def": 0.8, "res": 1.6, "spd": 0.6, "lck": 0.7 },
      "attack_skill": "skl_attack_mopsula",
      "learnset": [ { "level": 1, "skill": "skl_mop_noble_flame" }, { "level": 1, "skill": "skl_mop_holy_lick" },
                    { "level": 2, "skill": "skl_mop_frost_sneeze" }, { "level": 3, "skill": "skl_mop_thunder_bark" },
                    { "level": 4, "skill": "skl_mop_royal_decree" }, { "level": 6, "skill": "skl_mop_mass_lick" },
                    { "level": 7, "skill": "skl_mop_revive" }, { "level": 9, "skill": "skl_mop_inferno" } ],
      "stunts": [ "skl_stunt_mop_entrance" ],
      "equipment": { "weapon": "itm_wpn_collar_leather", "armor": "itm_arm_pug_sweater", "accessory": "" },
      "status_resist": {},
      "model": { "base": "pug", "scale": 1.0, "colors": { "primary": "#D8B98A", "secondary": "#2A2024", "accent": "#7B2CBF", "eyes": "#1A1420" },
                 "props": [ "cape", "monocle" ] },
      "portrait_color": "#7B2CBF" }
  ]
}
```

### 4.3 EXP-Kurve

```text
exp_to_next(L) = floori(18.0 * pow(L, 1.7) + 15.0)  # Progression.exp_to_next(level); L = aktuelles Level, gilt für L1..L9
```

| Level | EXP bis nächstes | EXP gesamt (Beginn des Levels) |
|---|---|---|
| 1 | 33 | 0 |
| 2 | 73 | 33 |
| 3 | 131 | 106 |
| 4 | 205 | 237 |
| 5 | 292 | 442 |
| 6 | 393 | 734 |
| 7 | 506 | 1127 |
| 8 | 632 | 1633 |
| 9 | 769 | 2265 |
| 10 | — (Cap) | 3034 |

Balancing 2026-10 (Kap. 13): Faktor 15 → 18. Mit 15 lag die L6-Schwelle (624) genau auf der Summe aller Gruppen der Zonen
A–C; jeder Event-Kampf oder Streuner hob die Party eine Stufe über den Plan (Bot: Hausmeister L6, Zone B/C je +1).

EXP-Überschuss am Cap verfällt. Beide Mitglieder haben **getrennte** EXP-Konten (wegen KO-Regel), starten gleich.

### 4.4 Skill-Datenfelder (= `SkillDef`, 02_TECH §4.4.2)

Die Skill-Tabellen (Kap. 3.6, 4.5, 4.6, 5.1–5.3, 6.1) nutzen Kurzspalten. Verbindliche Abbildung auf `skills.json`:

| GDD-Spalte (früherer Feldname) | `SkillDef`-Feld | Regel |
|---|---|---|
| ID | `id` | `skl_` + Kurz-ID (Kap. 16.1) |
| Name / Beschreibung (`name_key`, `desc_key`) | `name`, `desc` | deutscher Text = msgid |
| L + Charakter (`unlock_level`, `owner`) | — | Freischaltung über `party.json → entries[].learnset[{level, skill}]`; Skill selbst `user: "party"` |
| (Gegner-, Boss-, Item-Skills) | `user` | `enemy` bzw. `item` |
| MP (`mp`) | `mp_cost` | |
| Power | `power` | Prozent; bei Fixschaden (`fixed`) und `heal_mode "fixed"` der Betrag |
| Rang | `rank` | 1..6 |
| Ziel (`target`) | `target` | `enemy`→`single_enemy`, `ally`→`single_ally`, `ko_ally`→`single_ally_ko`; `all_enemies`, `all_allies`, `self` unverändert; immer relativ zum Anwender |
| Element | `element` | Kap. 3.8 |
| Skal. (`scaling`) | `damage_type` (+ `heal_mode`) | `str`→`physical`, `mag`→`magical`, `mag (heal)`→`heal` + `heal_mode "mag"`, `pct`→`heal` + `heal_mode "pct"`, fixe Heilung→`heal` + `heal_mode "fixed"`, `revive`→`heal` + `heal_mode "pct"` mit Ziel `single_ally_ko`, Fixschaden→`fixed`, `—`→`none` |
| `status`, `status_chance`, `status_turns` | `statuses: [{id, chance, turns}]` | Chance fehlt = 1.0; Dauer fehlt = `default_turns`; `turns` 1..99 |
| „heilt `poison`“ | `cleanse: ["sts_poison"]` | |
| `crit_bonus` | `crit_bonus` | float 0..1 (z. B. 0.20), nicht Prozentpunkte |
| `hype_tags` | `show_tags` | rein beschreibend (`flashy`, `finisher`, `cute`, `gross`, `risky`) |
| „Kill damit: Hype +x extra“ | `kill_hype` | int (Prime-Time-Finisher 10) |
| — | `category` | `attack` (physical), `magic` (magical), `heal`, `buff`, `debuff`, `stunt`, `item`, `summon` |
| Stunt-Werte | `success_base`, `success_lck`, `success_cap`, `success_boss_mod`, `fail_effect`, `cooldown` | Kap. 3.6; `stunt_chance`/`stunt_fail_status` entfallen |
| Sonder-Effekte | `mp_restore`, `mp_restore_pct`, `summon`, `flee_guaranteed`, `hype`, `special {kind: steal_credits \| escape, …}` | Kap. 3.11, 6.1 |
| — | `accuracy` | Default −1 (trifft immer) für alle Slice-Skills |

**Basisangriffe:** `skl_attack_kai` und `skl_attack_mopsula` (Name „Angriff“, `user party`, `category attack`, `single_enemy`,
`physical`, Element `physical`, `power 100`, `rank 3`). Gegner-Fallback `skl_e_strike` (Kap. 5.1).

```json
{"id": "skl_kai_leash_trip", "name": "Leinen-Fallstrick", "desc": "Bremst einen Gegner aus. Meistens.", "user": "party",
 "category": "attack", "target": "single_enemy", "damage_type": "physical", "element": "physical", "power": 70,
 "mp_cost": 5, "rank": 3, "statuses": [{"id": "sts_slow", "chance": 0.9, "turns": 3}], "anim": "attack"}
```

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
| 9 | `kai_prime_finisher` | Prime-Time-Finisher | 12 | 260 | 5 | `enemy` | physical | str | `crit_bonus 0.20`; Kill damit: Hype +10 extra (`kill_hype: 10`). |

### 4.6 Fähigkeiten Graf Mopsula (8)

| L | ID | Name | MP | Power | Rang | Ziel | Element | Skal. | Effekt / Beschreibung |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `mop_noble_flame` | Adelsflamme | 4 | 110 | 3 | `enemy` | fire | mag | „Blaues Blut brennt heißer.“ |
| 1 | `mop_holy_lick` | Heiliges Schlabbern | 4 | 100 | 2 | `ally` | none | mag (heal) | Heilung. „Eine Ehre, die keiner wollte.“ |
| 2 | `mop_frost_sneeze` | Frostniesen | 5 | 105 | 3 | `enemy` | ice | mag | `slow` 3, Chance 0.25. |
| 3 | `mop_thunder_bark` | Donnerbellen | 7 | 75 | 3 | `all_enemies` | shock | mag | „WUFF. Mit Hall.“ |
| 4 | `mop_royal_decree` | Königlicher Erlass | 6 | 0 | 2 | `ally` | none | — | `haste` 3. „Wir befehlen: schneller!“ |
| 6 | `mop_mass_lick` | Massen-Schlabbern | 10 | 60 | 3 | `all_allies` | none | mag (heal) | Heilung + heilt `poison`. |
| 7 | `mop_revive` | Sabber der Wiederkehr | 14 | 40 | 4 | `ko_ally` | none | revive | Belebt mit 40 % MaxHP (`heal_mode "pct"`, `power 40`, Ziel `single_ally_ko`). |
| 9 | `mop_inferno` | Gräfliches Inferno | 14 | 130 | 4 | `all_enemies` | fire | mag | „Für die Ahnen. Alle 300 davon.“ |

---

## 5. Gegner & Bosse Etage 1

### 5.1 Reguläre Gegner (10) + 1 Rarität

Werte sind fest pro Typ (kein Gegner-Level-Scaling im Slice). `Lv` = Richtwert für UI/Bestiarium.

**Datenabbildung `enemies.json` (`EnemyDef`):** `id` = `enm_` + Kurz-ID; Werte → `level`, `stats`, `exp`, `credits`;
`field_speed` → `explore.field_speed` (übrige `explore`-Felder: Defaults aus Kap. 2.3, Taubenschwarm `sight_range: 14`,
Fahrscheinfresser s. Kap. 2.3); weak/resist/immune → `element_mods` 1.5/0.5/0.0, `immune poison` zusätzlich
`status_immune: ["sts_poison"]`; Drops → `drops: [{item, chance}]`; `status_resist: {}` (Bosse s. 5.2/5.3); `ai` nach Kap. 3.11
(KI-Muster unten); `attack_skill: "skl_e_strike"` für **alle** Gegner (Name „Angriff“, `user enemy`, `category attack`,
`single_enemy`, `physical`, Element `physical`, `power 100`, `rank 3`, nur Fallback); `boss: true` und `boss_drops` (sichere Drops) nur bei Bossen;
`model` = ModelSpec laut 03_ART §5.5 (die „Visuelle Beschreibung“ unten ist die Art-Vorgabe dafür, es gibt kein Feld `visual`);
Kill-Hype nach Kap. 7.3 (kein `hype_value`).

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
| `fahrscheinfresser` | Fahrscheinfresser (Rarität) | 4 | 60 | 0 | 18 | 18 | 20 | 20 | 16 | 20 | 60 | 100 | 0 (steht) | A |

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

**Gegner-Skills** (Daten-IDs `skl_e_*`, `user: "enemy"`; Spalten nach Kap. 4.4):

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
| `e_rat_heal` | Rattensegen | 30 | 2 | ally | none | pct | 5 | Heilung 30 % MaxHP (`heal_mode "pct"`) |
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
| `e_fine` | Erhöhtes Beförderungsentgelt | 0 | 3 | enemy | none | — | 0 | Party verliert `min(40, credits)` Credits; Rückgabe, wenn der Dieb KO geht (`special {"kind": "steal_credits", "max": 40, "refund_on_win": true}`) |
| `e_escape` | Abfahrt! | 0 | 2 | self | none | — | 0 | verlässt den Kampf, keine Belohnung für ihn (`special {"kind": "escape"}`) |

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
| `rattengardist` | `e_shield_wall` 10 `all_allies` `once` · `e_lunge` 2 `lowest_hp_pct` · `e_halberd` 3 random | Elite, schützt Gruppe |
| `fahrscheinfresser` | `e_fine` 10 `once` · `e_ticket_cut` 3 · `e_escape` 100 `turn_mod [4,3]` | Muss in 3 eigenen Zügen sterben |

(Kurzschreibweise: `all` = Ziel `all_enemies`; ohne Ziel = `random`; `not_status:poison` = `not_status:sts_poison` in den Daten.)

**Visuelle Beschreibung (Primitive + Toon-Shader, Outline, Farben als Hex; Daten = `model` laut 03_ART §5.5):**

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
| Lv / HP / MP | 6 / **330** / 60 |
| STR / MAG / DEF / RES / SPD / LCK | **40 / 26** / 14 / 10 / 12 / 6 (Balancing Kap. 13: vorher 380 HP, STR 23, MAG 14 — auch ohne Sponsoren 100 % Auto-Sieg eine Stufe unter Ziel) |
| Affinitäten | weak `shock`, resist `poison` → `element_mods {"shock": 1.5, "poison": 0.5}` |
| Status-Resistenz | `status_resist {"sts_stun": 0.5, "sts_slow": 0.5}` |
| EXP / Credits | **180 / 150** |
| Drops (100 %) | `key_master` (Schlüsselitem), `acc_key_ring`, Lootbox `silver` → `boss_drops: [{"kind": "item", "id": "itm_key_master", "amount": 1}, {"kind": "item", "id": "itm_acc_key_ring", "amount": 1}, {"kind": "box", "id": "box_silver", "amount": 1}]` |
| Ziel-Party-Level | **5** (L4 schaffbar mit Items) |

**Skills:** `b_broom` Besenhieb (110, R3, physical, str) · `b_keys` Schlüsselbund-Wurf (70, R4, all_enemies, physical) ·
`b_rules` Hausordnung verlesen (self, `guard` 2, R3) · `b_cleaner_fog` Putzmittelnebel (60, R4, all_enemies, poison, mag, `poison` 0.40, MP 8) ·
`b_call_tenant` „Untermieter!“ (beschwört 1 `kanalratte`, R3, MP 6; `category summon`, `summon: ["enm_kanalratte"]`) ·
`b_mop_whirl` Wischmopp-Wirbel (90, R3, all_enemies, physical, str). Daten-IDs `skl_b_*`.

| Phase (`hp_above`) | HP | `on_enter` | Aktionen (Gewicht · Ziel · Bedingung) |
|---|---|---|---|
| P1 „Kehrwoche“ (0.60) | 100–60 % | `say boss_intro:enm_boss_hausmeister` | `b_rules` 10 self `once` (meist 1. Zug) · `b_broom` 3 random · `b_keys` 1 all |
| P2 „Hausordnung § 7“ (0.25) | 60–25 % | `summon enm_kanalratte ×1`; `say boss_phase:enm_boss_hausmeister:2` | `b_broom` 2 random · `b_cleaner_fog` 2 all · `b_keys` 1 all · `b_call_tenant` 4 `allies_alive_below 2` `turn_mod [4,0]` |
| P3 „Feierabend!“ (0.0) | < 25 % | `status_self sts_haste 5`; `say boss_phase:enm_boss_hausmeister:3` | `b_mop_whirl` 2 all · `b_broom` 2 `lowest_hp_pct` |

**Visuell:** 3.0 m hohe Kapsel (Kittel #7C8A94), Box-Brusttasche mit Kugelschreibern (Zylinder), Kugel-Kopf mit
Box-Schnurrbart und Schirmmütze (Zylinder + flache Box), Schlüsselbund = 12 Torus-Ringe an der Hüfte (klimpern per
Sinus), Besen = langer Zylinder + Box-Bürste. Phase 3: Augen emissive Rot #FF3B30, Dampf-Partikel aus den Ohren.

### 5.3 Boss: Die Rattenkönigin von Gleis 9 (`boss_rattenkoenigin`)

| Feld | Wert |
|---|---|
| Lv / HP / MP | 8 / **550** / 120 |
| STR / MAG / DEF / RES / SPD / LCK | **52 / 44** / 18 / 16 / 15 / 10 (Balancing Kap. 13: vorher 720 HP, STR 26, MAG 20) |
| Affinitäten | weak `ice`, resist `fire`, immune `poison` → `element_mods {"ice": 1.5, "fire": 0.5, "poison": 0.0}`, `status_immune ["sts_poison"]` |
| Status-Resistenz | `status_resist {"sts_stun": 0.5, "sts_slow": 0.5}` |
| EXP / Credits | **420 / 300** |
| Drops (100 %) | `acc_queen_crown`, Lootbox `gold` → `boss_drops: [{"kind": "item", "id": "itm_acc_queen_crown", "amount": 1}, {"kind": "box", "id": "box_gold", "amount": 1}]`; Achievement `ach_queen` (+ Gold-Box) |
| Modell | `model.pose: "quadruped"` (liegt, Kapsel 3.5 m; überschreibt die ART-Regel „rodent scale ≥ 1.0 = aufrecht“) |
| Ziel-Party-Level | **7** (L6 schaffbar mit guter Ausrüstung + Items) |

**Skills:** `q_scepter` Zepterstoß (120, R3, physical, str) · `q_plague_bite` Pestbiss (90, R3, poison, str, `poison` 0.50) ·
`q_screech` Kreischen der Krone (80, R4, all_enemies, shock, mag, MP 8) · `q_summon` Schwanzknoten lösen (beschwört bis zu 2 `kanalratte`, R3, MP 10) ·
`q_crown_nova` Kronen-Nova (110, R5, all_enemies, shock, mag, MP 16). `q_summon`: `category summon`,
`summon: ["enm_kanalratte", "enm_kanalratte"]` (füllt freie Slots). Daten-IDs `skl_q_*`.

**Pseudo-Einheit „Einfahrender Zug“ (`train_gleis9`):** keine HP, nicht anvisierbar, SPD-unabhängig.
Erscheint in der Zugreihenfolge mit Zug-Icon. Wenn er „handelt“: **Fixschaden 35 % MaxHP** jedes Party-Mitglieds
(Element `physical`, Affinität zählt, halbiert durch Verteidigen, nicht durch `guard`; kann KO machen), danach `ctr = 160`.
M.O.D.-Warnung (`boss_train_warning`), sobald der Zug auf Position 2 der Vorschau steht (1× pro Anfahrt).
Lernziel: Vorschau lesen, rechtzeitig verteidigen. Daten in `enemies.json → pseudo_units` (`PseudoUnitDef`, Laufzeit-IDs `u0..`):

```json
{"id": "pu_train_gleis9", "name": "Einfahrender Zug", "icon": "train",
 "action": {"fixed_pct_maxhp": 35, "element": "physical", "ignores_guard": true, "target": "all_party"},
 "ctr_after": 160, "warn_tag": "boss_train_warning", "warn_at": 2}
```

| Phase (`hp_above`) | HP | `on_enter` | Aktionen |
|---|---|---|---|
| P1 „Hofstaat“ (0.65) | 100–65 % | `summon enm_kanalratte ×2`; `say boss_intro:enm_boss_rattenkoenigin` | `q_scepter` 3 random · `q_plague_bite` 1 `not_status:poison` · `q_summon` 4 `allies_alive_below 3` `turn_mod [3,2]` |
| P2 „Zug fährt ein“ (0.30) | 65–30 % | `add_pseudo pu_train_gleis9 ctr 120`; `say boss_phase:enm_boss_rattenkoenigin:2` | `q_scepter` 3 random · `q_screech` 2 all · `q_plague_bite` 1 |
| P3 „Endstation“ (0.0) | < 30 % | Zug entgleist: `remove_pseudo pu_train_gleis9`; `fixed_damage_self 72 (min_hp 1)`; `status_self sts_haste 99`; `say boss_phase:enm_boss_rattenkoenigin:3` | `q_scepter` 3 `lowest_hp_pct` · `q_plague_bite` 2 · `q_crown_nova` 10 all `turn_mod [4,1]` |

**Visuell:** Riesen-Ratte (Kapsel liegend 3.5 m, Kopf-Kugel 1.2 m) auf entgleistem U-Bahn-Wagen (Box 8×3×3 m,
Fenster-Quads emissive #FFD27A, schief 12°). Krone = Zylinder-Ring aus 10 kleinen Box-„Fahrscheinen“ (#F2E8C9 mit
Loch-Decal). Schwanz: 6 Zylinder-Ketten, an jedem Ende eine Mini-Ratte (Kanalratte ×0.5). Zepter = Zylinder mit
Signallampe (Kugel, wechselt Rot/Grün). Fell #3F3530, Rim-Light Violett #9A6BFF. P3: Krone glüht #FF5A5A.

### 5.4 Begegnungsgruppen Etage 1 (`floors.json → encounters`)

Daten-ID = `enc_f1_` + Kurz-ID ohne `grp_` (`grp_a2` → `enc_f1_a2`); Gegnerliste = `enm_`-IDs in Slot-Reihenfolge.
Bosse: `boss: true`, `can_flee: false`. Tutorial: `tutorial: true` (Gegnerschaden ×0.5, Flucht gesperrt, Party-HP nie unter 1). Platzierung: Karte Kap. 1.3.

| Gruppe | Zone | Gegner | EXP gesamt | Credits |
|---|---|---|---|---|
| `grp_a1_tutorial` | A | kanalratte ×2 | 24 | 12 |
| `grp_a2` | A | kanalratte, taubenschwarm, kanalratte | 38 | 17 |
| `grp_a3` | A | pendler, taubenschwarm | 36 | 19 |
| `grp_a4` | A | taubenschwarm ×2, kanalratte | 40 | 16 |
| `grp_a_rare` | A | fahrscheinfresser | 60 | 100 |
| `grp_b1` | B | kanalschleim, kanalratte ×2 | 44 | 20 |
| `grp_b2` | B | rattenschamane, kanalratte ×2 | 50 | 24 |
| `grp_b3` | B | kabelsalat, kanalschleim | 50 | 23 |
| `grp_b4` | B | kanalschleim ×2, rattenschamane | 66 | 28 |
| `grp_c1` | C | kellerspinne ×2 | 68 | 24 |
| `grp_c2` | C | spruehgeist, kabelsalat | 66 | 33 |
| `grp_c3` | C | kellerspinne, spruehgeist, kanalratte | 82 | 36 |
| `grp_boss_hausmeister` | C | boss_hausmeister | 180 | 150 |
| `grp_d1` | D | rolltreppenkrabbe, rattenschamane | 86 | 32 |
| `grp_d2` | D | rattengardist ×2, rattenschamane | 158 | 56 |
| `grp_d3` | D | rolltreppenkrabbe, rattengardist | 126 | 42 |
| `grp_boss_rattenkoenigin` | D | boss_rattenkoenigin | 420 | 300 |
| `grp_evt_pigeons` | Event `fev_wheel` | taubenschwarm ×2 | 28 | 10 |
| `grp_evt_slime` | Event `fev_lever` | kanalschleim ×2 | 40 | 16 |

Summe EXP regulär (15 Gruppen inkl. Tutorial und Rarität, ohne Streuner): **994**; Zonen A–C 624, D 370. Wer alles bekämpft
(Streifen jagen einen ohnehin, Messung Kap. 13: auch „typische“ Läufe kämpfen 14–15 Gruppen) und dazu 1 Event-Kampf und
0–2 Streuner: ~650–750 EXP = **L5 vor dem Hausmeister** (L6 ab 734), +180 = L6 danach, ~1 200–1 300 = **L7 vor der
Königin** (L8 ab 1 633). Bei ~80 % bekämpft: ~500 = L5, ~975 = L6 vor der Königin („L6 schaffbar“, Kap. 5.3).

---

## 6. Items & Ausrüstung

**Datenabbildung `items.json` (`ItemDef`):** `id` = `itm_` + Kurz-ID ohne `item_` (`item_bandage` → `itm_bandage`, `wpn_mop` →
`itm_wpn_mop`, `key_master` → `itm_key_master`); `type` ∈ consumable/weapon/armor/accessory/key; Verbrauchsitems wirken über
`use_skill` = `skl_item_<name>` (`user: "item"`, `rank 2`); Ausrüstungswerte → `stats` (Waffen-**„ATK +x“ = `stats.str +x`**, in der
Formel A = STR_eff identisch; die UI beschriftet es bei Waffen als „ATK“), `crit +x` → `crit_bonus` (float), Affinitäten →
`element_mods`, Show-Effekte → `show_mods {hype_gain_mult, follower_mult}` (Default 1.0); `max_stack: 9`; `sell`: −1 = `floori(price / 2)`
(Default), 0 = nicht verkaufbar, > 0 = fester Wert; `price 0` = nicht im Automaten; `tags` ⊂ `ITEM_TAGS` (`heal`, `cure`, `revive`, `mp`, `damage`, `show`, `escape`); `rarity` ∈ common/rare/epic;
`attack_element` aller Waffen = `physical`.

### 6.1 Verbrauchsitems (Rang 2 im Kampf; außerhalb im Menü nutzbar, außer Kampf-Only)

| ID | Name | Wirkung | Ziel | `usable` | Preis | Verkauf | Rarität | Tags | `use_skill`-Werte |
|---|---|---|---|---|---|---|---|---|---|
| `item_bandage` | Werbepflaster | heilt 45 HP | ally | both | 25 | 12 | common | `heal` | `heal`, `heal_mode fixed`, `power 45` |
| `item_antidote` | Gegengift-Gurgler | heilt `poison` | ally | both | 20 | 10 | common | `cure` | `none`, `cleanse ["sts_poison"]` |
| `item_energy_krawumm` | KRAWUMM-Dose | +20 MP | ally | both | 60 | 30 | common | `mp` | `none`, `mp_restore 20` |
| `item_brutzel_burger` | Brutzel-Burger | heilt 120 HP | ally | both | 80 | 40 | rare | `heal` | `heal`, `heal_mode fixed`, `power 120` |
| `item_smelling_salts` | Riechsalz | belebt mit 30 % MaxHP | ko_ally | battle | 150 | 75 | rare | `revive` | `heal`, `heal_mode pct`, `power 30` |
| `item_molotov` | Grillanzünder-Cocktail | 60 Fixschaden `fire` | all_enemies | battle | 70 | 35 | common | `damage` | `fixed`, `power 60`, `fire` |
| `item_ice_spray` | Kältespray | 90 Fixschaden `ice` | enemy | battle | 50 | 25 | common | `damage` | `fixed`, `power 90`, `ice` |
| `item_smoke` | Taschen-Nebelmaschine | garantierte Flucht (nicht bei `can_flee == false`) | self | battle | 100 | 50 | rare | `escape` | `none`, `flee_guaranteed true` |
| `item_hype_megaphone` | Hype-Megafon | Hype +25 | self | battle | 120 | 60 | rare | `show` | `none`, `hype 25` |
| `item_elixir` | Premium-Abo-Elixier | volle HP + MP | ally | both | 0 (nur Loot) | 300 | epic | `heal`, `mp` | `heal`, `heal_mode pct`, `power 100`, `mp_restore_pct 100` |

Stapelgrenze 9 pro Item (`max_stack`). Loot/Geschenke über der Grenze werden zu Credits (Verkaufswert, Anzeige „LAGER VOLL → +X Cr“);
im Automaten ist die Menge auf `9 − Bestand` begrenzt. Schlüsselitem `key_master` „Generalschlüssel“ (`type key`, `sell 0`):
nicht verkauf-/wegwerfbar. Nach Kampfende (Sieg **und** Flucht) gibt es keine KO-Mitglieder mehr (1 HP), daher ist Riechsalz `battle`.

### 6.2 Waffen

| ID | Name | Träger (`equip_by`) | Werte → Daten | Preis | Verkauf | Rarität | Quelle |
|---|---|---|---|---|---|---|---|
| `wpn_mop` | Wischmopp | kai | ATK +4 → `str 4` | 0 | 0 | common | Start |
| `wpn_pipe_wrench` | Rohrzange | kai | ATK +8 → `str 8` | 220 | 110 | common | Automat SR1 |
| `wpn_fire_axe` | Feuerwehraxt | kai | ATK +12 → `str 12`, `crit_bonus 0.05` | 480 | 240 | epic | Automat SR2/SR3, verschl. Spind C, Lootbox epic |
| `wpn_rail_crowbar` | Gleis-Brechstange | kai | ATK +15 → `str 15`, `crit_bonus 0.05` | 0 | 250 | epic | Lootbox epic |
| `wpn_collar_leather` | Lederhalsband | mopsula | MAG +4 → `mag 4` | 0 | 0 | common | Start |
| `wpn_collar_studded` | Nietenhalsband | mopsula | MAG +7 → `mag 7` | 200 | 100 | rare | Automat SR1, Metallspind B, Lootbox rare |
| `wpn_collar_signet` | Siegel-Halsband | mopsula | MAG +11, MP +10 → `mag 11`, `mp 10` | 460 | 230 | epic | Automat SR2/SR3, verschl. Spind D, Lootbox epic |
| `wpn_collar_royal` | Hofjuwelier-Halsband | mopsula | MAG +14, MP +15 → `mag 14`, `mp 15` | 0 | 250 | epic | Lootbox epic (Pool ab Etage 2) |

(`wpn_collar_signet` ersetzt das frühere „Kronen-Halsband“: kein Kronen-Motiv an Mopsula, 04_STRATEGIE §2.3. Optik: goldene
Siegel-Plakette am Halsband.)

### 6.3 Rüstungen

| ID | Name | Träger | Werte → Daten | Preis | Verkauf | Rarität | Quelle |
|---|---|---|---|---|---|---|---|
| `arm_hoodie` | Tierheim-Hoodie | kai | DEF +3, RES +1 | 0 | 0 | common | Start |
| `arm_safety_vest` | Warnweste | kai | DEF +6, RES +2 | 180 | 90 | rare | Automat SR1, Metallspind A, Lootbox rare |
| `arm_sewer_suit` | Kanalarbeiter-Kombi | kai | DEF +9, RES +4, `poison: resist` → `element_mods {"poison": 0.5}` | 420 | 210 | common | Automat SR2/SR3 |
| `arm_pug_sweater` | Hundepulli „Kleiner Lord“ | mopsula | DEF +2, RES +3 | 0 | 0 | common | Start |
| `arm_velvet_cape` | Samtcape | mopsula | DEF +4, RES +6 | 220 | 110 | common | Automat SR1 |
| `arm_ermine` | Hermelin-Umhang (Kunstpelz!) | mopsula | DEF +6, RES +9, HP +15 | 0 | 250 | epic | Lootbox epic |

### 6.4 Accessoires

| ID | Name | Träger (`equip_by`) | Werte → Daten | Preis | Verkauf | Rarität | Quelle |
|---|---|---|---|---|---|---|---|
| `acc_lucky_ticket` | Glücks-Fahrschein | beide (`[]`) | LCK +5 | 150 | 75 | rare | Automat SR1, `fev_lost_candidate`, Fahrscheinfresser, Lootbox rare |
| `acc_rubber_boots` | Gummistiefel | beide | `shock: resist` → `element_mods {"shock": 0.5}` | 200 | 100 | rare | Automat SR2/SR3, Kabelsalat, Lootbox rare |
| `acc_sneakers` | Turnschuhe (gebraucht) | beide | SPD +2 | 260 | 130 | epic | Automat SR2/SR3, Lootbox epic |
| `acc_gas_mask` | Gasmaske | beide | `poison: immune` → `element_mods {"poison": 0.0}` + `status_immune ["sts_poison"]` | 300 | 150 | common | Automat SR2/SR3, Metallspind C |
| `acc_key_ring` | Schlüsselbund des Hausmeisters | beide | DEF +2, `crit_bonus 0.05` | 0 | 150 | rare | Hausmeister |
| `acc_queen_crown` | Rattenkrone | **nur Kai** (`["kai"]`) | STR +3, MAG +3, SPD +1 | 0 | 250 | epic | Rattenkönigin |
| `acc_fan_scarf` | Fan-Schal | beide | positive Hype-Gewinne ×1.2 → `show_mods {"hype_gain_mult": 1.2}` | 0 | 150 | rare | Follower-Meilenstein 1 000 |
| `acc_clip_mic` | Ansteck-Mikro | beide | Follower-Gewinn ×1.15 → `show_mods {"follower_mult": 1.15}` | 0 | 150 | rare | Fan-Box |

`show_mods` wirken für die ganze Show, egal wer das Accessoire trägt; mehrere Quellen multiplizieren sich.

### 6.5 Automat (je Safe Room, `layout.safe_rooms[].shop`)

| Safe Room | ID / `theme` | Sortiment |
|---|---|---|
| SR1 Kiosk 24/7 (A) | `sr_kiosk` / `kiosk` | alle Verbrauchsitems außer `item_elixir`; `wpn_pipe_wrench`, `wpn_collar_studded`, `arm_safety_vest`, `arm_velvet_cape`, `acc_lucky_ticket` |
| SR2 Pumpenhaus (B/C) | `sr_pumphouse` / `pumphouse` | SR1 + `wpn_fire_axe`, `wpn_collar_signet`, `arm_sewer_suit`, `acc_rubber_boots`, `acc_sneakers`, `acc_gas_mask` |
| SR3 Stellwerk (D) | `sr_signalbox` / `signalbox` | wie SR2 |

`Shop.stock(def, safe_room_id)` liefert die Liste des Safe Rooms. Bestand unbegrenzt. Verkauf nach `sell` (Kap. 6 oben).
**Credits-Budget E1** (erwartet bis Königin): ~1 100 Cr (Kämpfe ~420, Truhen ~300, Hausmeister 200, Events/Boxen ~180).

---

## 7. Show-System (Kern-USP)

Alle Zahlen dieses Kapitels sind verbindlich für `ShowModel`, `ShowRules`, `SponsorSystem` (02_TECH §6.1/§6.2 übernehmen sie;
Konstanten Kap. 16.3). Die Show-Logik ist deterministisch (Show-`rng`); nur die Anzeige glättet und rauscht.

### 7.1 Größen

| Größe | Typ | Bereich | Persistenz |
|---|---|---|---|
| `hype` | float | 0–100 | pro Etage; `Game.start_floor()` setzt **30** (`HYPE_START`) |
| `viewers` | int | ≥ 0 | abgeleitet aus Hype + Followern (7.2), live |
| `followers` | int | ≥ 0 | dauerhaft (Spielstand), Start 0 |
| `viewers_peak_battle` | int | — | Maximum von `viewers` während eines Kampfes |

### 7.2 Zuschauer-Formel

```text
ShowModel.viewers_for(floor_mult: float, hype: float, followers: int) -> int
  = roundi((1000.0 * floor_mult + followers * 0.5) * (0.4 + hype / 40.0))    # Hype 0 → 0.4×, 50 → 1.65×, 100 → 2.9×
# floor_mult = FloorDef.floor_mult (ersetzt viewer_base): E1 1.0, E2 1.5
# Balancing 2026-10 (Kap. 13): je Follower schaut 0.5 Zuschauer zu (VIEWER_PER_FOLLOWER, vorher 1.0) — dämpft die
# Rückkopplung Follower → Zuschauer → Follower und hält den Etagen-Peak bei 3 000–5 500.
```

- **Logikwert** `viewers` = `viewers_for(...)`, neu berechnet bei jeder Hype-/Follower-Änderung und jede 1.0 s. Er speist
  `viewers_peak_battle`, `s.viewers_max`, den Trigger `viewers_changed` und alle Achievements.
- **Anzeige** (nur HUD): `shown += (viewers - shown) * (1.0 - exp(-delta / 1.5))`, alle 2 s ±1.5 % Rauschen aus einem eigenen
  Anzeige-RNG. Die Anzeige wirkt nie zurück auf die Logik.

### 7.3 Hype-Ereignisse (`ShowRules.feed`, Zeile für Zeile)

| Ereignis | ΔHype | Regel |
|---|---|---|
| Kampfstart normal / Präventiv / Hinterhalt / Boss | +3 / +3 / +5 / +8 | Boss ersetzt die anderen |
| **Abwechslung** | +2 | `action_key` der Party-Aktion kommt in den letzten 4 Party-`action_key`s nicht vor (`attack`, Skill-ID, Item-ID, `stunt`, `defend`, `flee`) |
| **Wiederholung** | −5 | gleicher `action_key` zum 3. Mal in Folge (Party, egal welcher Charakter); jede weitere −5 |
| Kritischer Treffer | +3 | je Krit |
| Schwachstelle getroffen | +2 | max. 1× pro Aktion |
| Kill mit Angriff / mit Skill / mit Stunt | +1 / +2 / +4 | Item-Kill zählt wie Angriff (+1); zusätzlich `SkillDef.kill_hype` (Prime-Time-Finisher +10) |
| **Overkill** | +3 | `damage >= hp_before + target.max_hp * 1.0` (`Balance.OVERKILL_MAXHP_FRAC`); Credits dieses Gegners ×1.25 (`BattleResult.overkill_credits`) |
| **Combo** | +2 | Kai und Mopsula handeln direkt nacheinander (kein anderer Zug dazwischen, auch keine Pseudo-Einheit), beide mit einer Schadensaktion, die **dasselbe** Gegner-Ziel trifft; 2. Treffer Schaden ×1.1 (im Kern: `DamageCalc.compute(..., combo_second_hit)`, Erkennung über `BattleState.last_party_target` / `last_actor_side`), Banner „COMBO!“, Event `ActionEvent.Type.COMBO`, Trigger `combo` |
| Kill-Serie | +5 | 3 Kills innerhalb von 3 aufeinanderfolgenden Party-Aktionen |
| Stunt Erfolg / Fehlschlag | +12 / +4 | — |
| Party-Mitglied fällt unter 25 % HP | +6 | 1× pro Mitglied pro Kampf („Drama“) |
| Party-Mitglied KO | +10 | — |
| Wiederbelebung | +8 | — |
| Sponsor-Item verwendet (`item_hype_megaphone`) | +25 | über `SkillDef.hype` |
| Sieg knapp (ein lebendes Mitglied ≤ 10 % HP) | +15 | bei Kampfende |
| Sieg ohne Schaden | +3 | bei Kampfende |
| Langweilig | −3 | jede Party-Aktion ohne positives Hype-Ereignis |
| Kampf zieht sich | −3 | jeder Party-Zug nach dem 10. (Boss: nach dem 25.) |
| Verteidigen 2× in Folge (gleicher Charakter) | −4 | — |
| Flucht Erfolg / Fehlschlag | −30 / −5 | — |
| **Erkundung:** Truhe / Event / Achievement | +2 / +5 / +5 | Achievement-Bonus gilt auch im Kampf |
| **Erkundung:** Abkühlen | alle 2 s laufenden Timers −10 % des Hype über 25, mind. −1 | nicht unter 25 (`HYPE_EXPLORE_FLOOR`); `ShowModel.decay_step` |
| Timer-Warnung 5:00 / 1:00 | +10 / +15 | einmalig |

Positive Ereignisse werden mit `hype_gain_mult` multipliziert (Produkt aller `show_mods`, z. B. `acc_fan_scarf` 1.2). Danach `clamp(0, 100)`.
Kein Hype-Drift im Kampf und kein `hype_value`-Kill-Faktor (die Werte oben ersetzen 02_TECH §6.2 vollständig).

**Dramaturgie (Balancing 2026-10, Kap. 13):** Jeder Kampf ist ein Show-Segment. Ein Routinekampf hebt die Quote um ~15–25
Punkte (Median Kampfende ~55–60), Stunts, Overkills, knappe Siege und KOs um 30–45; Sponsoren melden sich erst, wenn ein
Kampf die Quote über 70 treibt (Kap. 7.4). In der Erkundung kühlt das Publikum ab — je heißer, desto schneller (−10 % des
Abstands zu 25 alle 2 s): ein 85er-Kampfende liegt nach 30 s Erkundung bei ~41, nach einer Minute bei ~26; nur wer zügig
weiterspielt, nimmt die Quote in den nächsten Kampf mit. Vorher (konstant −1 / 5 s bis 15 und die doppelt so großen Werte
oben) endete fast jeder Kampf bei 96–100: Zuschauerfaktor dauerhaft 2.9, Sponsor-Geschenk in jedem Kampf.

### 7.4 Sponsor-Geschenke

- **Auslöser:** Hype überschreitet im **Kampf** aufwärts **70**, **85** oder **100** (`SponsorSystem.THRESHOLDS`, HUD-Marker an
  denselben Werten). Jede Schwelle 1× pro Kampf. Max. **1 Geschenk pro regulärem Kampf**, **2 pro Bosskampf**
  (`MAX_GIFTS_PER_BATTLE` / `MAX_GIFTS_PER_BOSS_BATTLE`; vorher 50/75/100 und 2/3 → ~15–19 Geschenke pro Etage, Bosse mit
  drei Heilungen trivial).
  Werden mehrere Schwellen auf einmal überschritten, kommen die Geschenke nacheinander (im Rahmen des Limits).
  **Keine Hype-Kosten** (`HYPE_COST = 0`). Nach dem Geschenk zu Schwelle 100: Hype auf **80** setzen.
- **Ablauf:** Vor dem nächsten Zug fliegt eine Sponsor-Drohne ein (1.5 s, überspringbar), Banner oben rechts,
  M.O.D. `sponsor_gift`. Kostet **keine** Ticks. Eingang immer über `Show.receive_gift(gift)` (Brief §6b).
- **Auswahl:** gewichteter Zufall (Show-`rng`), Gewicht = `weight` × Produkt der zutreffenden `weight_mods`:

| ID | Sponsor (fiktiv, satirisch) | Slogan | Geschenk | Basis-Gewicht | Multiplikator |
|---|---|---|---|---|---|
| `sp_gluckwasser` | **Glückwasser** | „Trink dich glücklich. Wörtlich.“ | alle Verbündeten +25 % MaxHP | 3 | ×3 wenn ein Verbündeter < 50 % HP |
| `sp_krawumm` | **KRAWUMM Energy** | „Schlaf ist was für Verlierer.“ | `haste` 3 auf alle Verbündeten | 2 | — |
| `sp_panzerkeks` | **Panzerkeks** | „Der Keks, der zurückbeißt.“ | `guard` 3 auf alle Verbündeten | 2 | ×2 wenn ein Verbündeter < 35 % HP |
| `sp_sorgenfrei` | **Sorgenfrei Versicherungen AG** | „Wir zahlen. Meistens.“ | belebt KO-Verbündeten mit 40 %; sonst niedrigster +40 % MaxHP | 1 | ×6 wenn ein Verbündeter KO |
| `sp_novanet` | **NovaNet Mobilfunk** (Konzernmarke) | „Empfang bis in die tiefste Etage.“ | alle Verbündeten +40 % MaxMP | 2 | ×2 wenn ein Verbündeter < 30 % MP |
| `sp_brutzel` | **Brutzel-Burger** | „Mit echtem Fleisch-Aroma.“ | 1× `item_brutzel_burger` ins Inventar + alle +20 HP | 2 | — |
| `sp_doomscroll` | **DoomScroll+** | „Nur noch eine Folge.“ | `slow` 3 auf alle Gegner (ignoriert Status-Resistenz, nicht Immunität) | 2 | ×2 im Bosskampf |

Daten (`sponsors.json`, `SponsorDef`; `hype_threshold` entfällt): `id` = `spn_` + Name (`sp_gluckwasser` → `spn_gluckwasser`),
`gift: [{kind, value, status, turns, item, target, ignore_resist}]` mit `GIFT_KINDS = heal_party_pct, heal_party_flat, mp_party_pct,
status_party, status_enemies, item, revive_or_heal_lowest`; `weight_mods: [{cond, value, mult}]` mit
`cond ∈ ally_hp_below | ally_mp_below | ally_ko | is_boss`:

| ID | `gift` | `weight` | `weight_mods` |
|---|---|---|---|
| `spn_gluckwasser` | `[{"kind": "heal_party_pct", "value": 25}]` | 3 | `[{"cond": "ally_hp_below", "value": 0.5, "mult": 3}]` |
| `spn_krawumm` | `[{"kind": "status_party", "status": "sts_haste", "turns": 3}]` | 2 | `[]` |
| `spn_panzerkeks` | `[{"kind": "status_party", "status": "sts_guard", "turns": 3}]` | 2 | `[{"cond": "ally_hp_below", "value": 0.35, "mult": 2}]` |
| `spn_sorgenfrei` | `[{"kind": "revive_or_heal_lowest", "value": 40}]` | 1 | `[{"cond": "ally_ko", "value": 0, "mult": 6}]` |
| `spn_novanet` | `[{"kind": "mp_party_pct", "value": 40}]` | 2 | `[{"cond": "ally_mp_below", "value": 0.3, "mult": 2}]` |
| `spn_brutzel` | `[{"kind": "item", "item": "itm_brutzel_burger", "value": 1}, {"kind": "heal_party_flat", "value": 20}]` | 2 | `[]` |
| `spn_doomscroll` | `[{"kind": "status_enemies", "status": "sts_slow", "turns": 3, "target": "enemies", "ignore_resist": true}]` | 2 | `[{"cond": "is_boss", "value": 0, "mult": 2}]` |

`turns` bei `status_*` = Dauer in eigenen Zügen. Verbündete = lebende Party-Mitglieder (KO nur bei `revive_or_heal_lowest`).

### 7.5 Chat-Ticker (Kosmetik)

Laufband unten, Zeilen mit Stimme `chat` in `mod_lines.json` (Tags `chat_*`, Kap. 11.3), max. 1 Zeile / 2.5 s; Erkundung alle 6 ± 2 s
eine Zeile nach Hype-Band (`chat_hype_high` ≥ 70, `chat_hype_mid` 30–70, `chat_hype_low` < 30), im Kampf ereignisgesteuert
(`chat_crit`, `chat_stunt_fail`, `chat_boring`, `chat_mopsula`). Absender: Tag `chat_handle` („xX_Gleisgeist_Xx“, „OmaHilde1953“,
„mopsfan_88“ …). Kein Gameplay-Effekt.

### 7.6 Follower-Konvertierung

```text
# bei Kampfsieg (ShowModel.followers_for_battle)
follower_gain = floori(viewers_peak_battle * (0.007 + 0.014 * hype_end / 100.0) * mult)
mult = 2.0 (Boss) | 1.0 sonst;  × follower_mult (acc_clip_mic 1.15)
# bei Flucht
followers -= floori(followers * 0.01)
# Niederlage: 0
# Achievements (fest je Tier, Feld followers): Bronze +20, Silber +40, Gold +80
# Events: laut Kap. 2.6
```

Erwartung E1: ~40 pro regulärem Kampf, ~110 Hausmeister, ~200 Königin, ~500 aus Achievements → **~1 200–1 500 Follower am
Etagenende** (gemessen Kap. 13).

### 7.7 Follower-Meilensteine (`milestones.json`)

| Follower | ID | Belohnung | M.O.D.-Tag |
|---|---|---|---|
| 100 | `ms_100` | 1× `item_brutzel_burger` | `follower_milestone` |
| 250 | `ms_250` | Fan-Box | `follower_milestone` |
| 500 | `ms_500` | 150 Credits | `follower_milestone` |
| 1 000 | `ms_1000` | Fan-Box + `acc_fan_scarf` | `follower_milestone` |
| 2 000 | `ms_2000` | Gold-Box | `follower_milestone` (E1 nur mit Top-Spiel erreichbar) |
| 5 000 | `ms_5000` | Gold-Box + Titel „Quotenkönig:in“ | `follower_milestone` (ab Etage 2) |

Schema (`MilestoneDef`): `{"id": "ms_500", "followers": 500, "reward_box": "", "credits": 150, "item": "", "title": "", "min_floor": 1, "mod_tag": "follower_milestone"}`;
(`ms_100`/`ms_500` ohne Box seit dem Balancing Kap. 13 — Lootboxen pro Etage 15–20);
`ms_5000`: `"title": "Quotenkönig:in"`, `"min_floor": 2` (Titel setzt Flag `title_ms_5000`). Jeder Meilenstein wird genau 1× vergeben
(gespeichert in `ShowState.milestones`), sobald `followers ≥ followers`-Wert und die Etage ≥ `min_floor` ist.

---

## 8. Achievements (29)

**Modell** (`achievements.json`, `AchievementDef` ersetzt das `stat`/`gte`-Schema):
`{id, name, desc, trigger, condition, box, followers, hidden, mod_tag}`.
Auswertung: `AchievementTracker.evaluate(trigger: String, payload: Dictionary) -> PackedStringArray` (neu freigeschaltete IDs), aufgerufen
vom Autoload `Show` bei jedem Trigger. `condition` ist ein String-Ausdruck über `e.` (Payload), `s.` (Zähler in `ShowState.stats`) und
`f.` (Flags in `GameState.flags`); Operatoren `== != >= <= > <`, Verknüpfung nur `&&`, Literale: Zahlen, `true`/`false`, Strings in `"…"`.
Zähler werden **vor** der Auswertung desselben Triggers erhöht. Jedes Achievement wird genau 1× vergeben.
**Belohnung** (fest je Tier): `box` (`box_bronze`/`box_silver`/`box_gold` in `pending_lootboxes`) + Follower bronze 20 / silver 40 /
gold 80 + Hype +5 + M.O.D.-Spruch (Tag `achievement:<id>`, Fallback `achievement_generic`) + Toast.
`hidden: true` → im Menü „???“ bis zur Freischaltung.

**Trigger und Payload (`e.`):**

| Trigger | Quelle | Payload-Felder (= 02_TECH §6.3) |
|---|---|---|
| `battle_started` | Kampfstart | `encounter_id, encounter_type ("normal" \| "preemptive" \| "ambush"), is_boss` |
| `enemy_killed` | `KO` eines Gegners | `enemy_id, overkill, by ("attack" \| "skill" \| "stunt" \| "item"), member` |
| `battle_won` | Kampfende Sieg (`BattleResult`) | `party_turns, min_party_hp, min_party_hp_pct, crits, weakness_hits, items_used, party_kos, damage_taken, is_boss, boss_id, encounter_type, group_id` |
| `battle_fled` | Flucht erfolgreich | `encounter_id, is_boss` |
| `stunt_resolved` | `STUNT_RESULT` | `success, member, skill_id` |
| `combo` | `COMBO` | `member` (zweiter Akteur), `enemy_id` |
| `sponsor_gift` | Geschenk angekommen | `sponsor_id` |
| `party_ko` | `KO` eines Party-Mitglieds | `member` |
| `boss_defeated` | Sieg über Boss | `boss_id, party_turns` |
| `level_up` | Level-Aufstieg | `member, level` |
| `viewers_changed` | Logik-Zuschauerwert ändert sich | `viewers` |
| `chest_opened` | Truhe | `chest_id, type` |
| `item_bought` | Automat | `item_id, qty, cost, safe_room_id` |
| `lootbox_opened` | Lootbox | `box_id, best_rarity` |
| `event_completed` | Etagen-Event | `event_id, choice` |
| `explore_tick` | jede 1.0 s laufender Timer | `seconds_since_battle` |
| `floor_completed` | Abstieg | `floor, timer_left` (Sekunden, int) |

`BattleResult` liefert dafür zusätzlich: `party_turns, min_party_hp, min_party_hp_pct, crits, weakness_hits, items_used, party_kos,
advantage, boss_id, overkill_credits`. Alle Trigger sind `Events`-Signale mit `(payload: Dictionary)`.

**Zähler `s.` (`StatIds.ALL`):** `kills_total, kills_skill, battles_won, battles_fled, preemptives, ambushes_won, crits_total,
stunts_success, stunts_fail, chests_opened, sponsor_gifts, credits_spent_vendor, lootboxes_opened, events_completed,
game_overs, ko_mopsula, explore_seconds_since_battle, viewers_max`.
(`explore_seconds_since_battle` wird bei jedem Kampfstart 0; `viewers_max` = Maximum; `credits_spent_vendor` nur Automatenkäufe.)

| ID | Name | Beschreibung (`desc`) | Trigger | Bedingung | Box | Hidden | M.O.D.-Spruch (`achievement:<id>`) |
|---|---|---|---|---|---|---|---|
| `ach_first_blood` | Erster Kill | Besiege deinen ersten Gegner. | `enemy_killed` | `s.kills_total == 1` | bronze | — | „Erster Kill! Die Werbekunden atmen auf.“ |
| `ach_first_win` | Willkommen in der Sendung | Gewinne deinen ersten Kampf. | `battle_won` | `s.battles_won == 1` | bronze | — | „Ein Sieg. Wir haben schon Merch bestellt.“ |
| `ach_close_call` | Knapp daneben | Gewinne, während ein Mitglied höchstens 10 % HP hatte. | `battle_won` | `e.min_party_hp_pct <= 0.10` | bronze | — | „Mein Puls! Ich habe keinen Puls, aber trotzdem!“ |
| `ach_one_hp` | Haaresbreite | Gewinne mit einem Mitglied auf genau 1 HP. | `battle_won` | `e.min_party_hp == 1` | silver | ✓ | „Ein. Einziger. Lebenspunkt. Das schneiden wir in den Trailer.“ |
| `ach_pacifist` | Pazifist | Erkunde 5 Minuten ohne Kampf. | `explore_tick` | `s.explore_seconds_since_battle >= 300` | bronze | — | „Fünf Minuten ohne Gewalt. Die Zuschauer schlafen ein. Hier, nimm das.“ |
| `ach_overkill` | Overkill | Besiege einen Gegner mit Overkill. | `enemy_killed` | `e.overkill == true` | bronze | — | „Das war … gründlich. Die Reinigung stellt das in Rechnung.“ |
| `ach_crit_3` | Kritische Masse | Lande 3 kritische Treffer in einem Kampf. | `battle_won` | `e.crits >= 3` | bronze | — | „Drei Kritische in einem Kampf. Statistiker:innen weinen.“ |
| `ach_weakness_5` | Wunder Punkt | Triff 5× eine Schwachstelle in einem Kampf. | `battle_won` | `e.weakness_hits >= 5` | bronze | — | „Fünfmal genau dahin, wo es wehtut. Empathie: null. Quote: hoch.“ |
| `ach_stunt_first` | Showtalent | Schaffe deinen ersten Stunt. | `stunt_resolved` | `e.success == true && s.stunts_success == 1` | bronze | — | „DAS ist Fernsehen!“ |
| `ach_stunt_fail_3` | Pannenshow | Verpatze 3 Stunts. | `stunt_resolved` | `e.success == false && s.stunts_fail == 3` | bronze | ✓ | „Drei Pannen. Wir machen eine eigene Sendung daraus.“ |
| `ach_combo_first` | Eingespieltes Team | Lande deine erste Combo. | `combo` | `true` | bronze | — | „Mensch und Mops im Gleichschritt. Rührend. Und lukrativ.“ |
| `ach_preemptive_3` | Leise Sohle | Starte 3 Kämpfe mit Präventivschlag. | `battle_started` | `e.encounter_type == "preemptive" && s.preemptives == 3` | bronze | — | „Von hinten. Dreimal. Die Ethikkommission ist im Urlaub.“ |
| `ach_ambush_won` | Rückenwind | Gewinne einen Kampf nach einem Hinterhalt. | `battle_won` | `e.encounter_type == "ambush"` | bronze | — | „Überrascht und trotzdem gewonnen. Fast, als hätten Sie Talent.“ |
| `ach_flee_first` | Taktischer Rückzug | Fliehe zum ersten Mal. | `battle_fled` | `s.battles_fled == 1` | bronze | — | „Feigheit, äh, Taktik! Auch dafür gibt es eine Box. Leider.“ |
| `ach_sponsor_first` | Gesponsert | Erhalte dein erstes Sponsor-Geschenk. | `sponsor_gift` | `s.sponsor_gifts == 1` | bronze | — | „Ihr erster Sponsor! Bitte lächeln Sie in Kamera 3.“ |
| `ach_viewers_5000` | Quotenhit | Erreiche 5 000 Zuschauer. | `viewers_changed` | `e.viewers >= 5000` | silver | — | „Fünftausend! Die Konkurrenz zeigt gerade Kochshows. Ha!“ |
| `ach_chests_10` | Schatzsucher:in | Öffne 10 Truhen. | `chest_opened` | `s.chests_opened == 10` | silver | — | „Zehn Kisten. Das nennt man bei uns ‚Kundenbindung‘.“ |
| `ach_vendor_500` | Kaufrausch | Gib 500 Credits am Automaten aus. | `item_bought` | `s.credits_spent_vendor >= 500` | bronze | — | „500 Credits im Automaten. Die Wirtschaft dankt.“ |
| `ach_lootbox_10` | Gacha-Gewohnheit | Öffne 10 Lootboxen. | `lootbox_opened` | `s.lootboxes_opened == 10` | bronze | — | „Zehn Boxen. Hier ist noch eine. Für die Gewohnheit.“ |
| `ach_level_5` | Aufsteiger:in | Bring die Spielfigur auf Level 5. | `level_up` | `e.member == "kai" && e.level == 5` | bronze | — | „Level fünf. Sie sind jetzt offiziell schwer zu ersetzen.“ |
| `ach_mopsula_ko` | Der Graf ist gefallen | Graf Mopsula geht zum ersten Mal KO. | `party_ko` | `e.member == "mopsula" && s.ko_mopsula == 1` | bronze | ✓ | „Der Graf liegt! Die Quote liegt mit ihm! Tun Sie was!“ |
| `ach_mimic` | Fahrschein, bitte | Besiege einen Fahrscheinfresser. | `enemy_killed` | `e.enemy_id == "enm_fahrscheinfresser"` | silver | ✓ | „Schwarzfahren war gestern. Heute: Schwarzautomat.“ |
| `ach_events_all` | Neugierig | Schließe alle 5 Events der Etage ab. | `event_completed` | `s.events_completed == 5` | silver | — | „Alle Events gesehen. Sie lesen auch das Kleingedruckte, oder?“ |
| `ach_hausmeister` | Feierabend | Besiege den Hausmeister. | `boss_defeated` | `e.boss_id == "enm_boss_hausmeister"` | silver | — | „Der Hausmeister ist in Rente. Unbefristet.“ |
| `ach_hausmeister_no_items` | Ohne Hilfsmittel | Besiege den Hausmeister ohne Items. | `battle_won` | `e.boss_id == "enm_boss_hausmeister" && e.items_used == 0` | silver | — | „Ohne ein einziges Item. Die Sponsoren sind beleidigt. Ich bin beeindruckt.“ |
| `ach_queen` | Gleis 9 geräumt | Besiege die Rattenkönigin von Gleis 9. | `boss_defeated` | `e.boss_id == "enm_boss_rattenkoenigin"` | gold | — | „Die Königin ist tot, lang lebe — ach, egal, ZUSCHAUERREKORD!“ |
| `ach_queen_flawless` | Königlicher Auftritt | Besiege die Rattenkönigin ohne KO. | `battle_won` | `e.boss_id == "enm_boss_rattenkoenigin" && e.party_kos == 0` | gold | — | „Kein einziger KO. Graf Mopsula verlangt einen Thron. Abgelehnt.“ |
| `ach_speedrun` | Expresszug | Verlasse Etage 1 mit mindestens 10:00 Restzeit. | `floor_completed` | `e.floor == 1 && e.timer_left >= 600` | gold | — | „Mit zehn Minuten Rest. Sie sind entweder genial oder haben nichts gesehen.“ |
| `ach_last_minute` | Auf den letzten Drücker | Verlasse Etage 1 mit weniger als 1:00 Restzeit. | `floor_completed` | `e.floor == 1 && e.timer_left < 60` | silver | ✓ | „Unter einer Minute! Mein Regieraum hat geschrien. Vor Freude.“ |

(29 Einträge — alle im Slice erreichbar; `ach_viewers_5000` braucht ≈ 1 450 Follower und Hype 100 (`(1000 + 0.5 × 1450) × 2.9`),
also einen Top-Kampf gegen Ende der Etage; `ach_speedrun` (≥ 10:00 Rest) nur, wer deutlich unter der Ziel-Etagenzeit von
11–15 min bleibt — vorher 8:00, was auch der gemessene Erstspieler-Takt erreichte.)
`items_used` zählt nur Items, die die Party im Kampf einsetzt (keine Sponsor-Geschenke). `ach_` IDs bleiben unverändert (kein Präfix-Zusatz).

---

## 9. Lootboxen

**Grundsatz:** Lootboxen werden **ausschließlich im Spiel verdient** (Achievements, Bosse, Meilensteine, Events).
**Für Spieler:innen gilt: kein Echtgeld, kein Shop, keine Premiumwährung, keine Kaufoption für Lootboxen — nirgends.**
Satire auf Gacha, nicht Gacha. Davon getrennt: **Sponsorkisten von Zuschauer:innen im Live-Modus SHOWRUN** sind ein eigenes,
lauf-gebundenes System (Brief §5 Entscheidung 2026-10-07, Details und Leitplanken `05_LIVE_MODUS.md`); sie berühren die Lootboxen
dieses Kapitels nicht.

### 9.1 Stufen

| Tier | ID | Würfe (`rolls`) | Garantie (`guarantee`) | Quellen |
|---|---|---|---|---|
| Bronze | `box_bronze` | 2 | — | Achievements (bronze), Glücksrad |
| Silber | `box_silver` | 3 | `rare` (≥ 1× rare oder besser) | Achievements (silver), Hausmeister |
| Gold | `box_gold` | 4 | `epic` (≥ 1× epic) | Achievements (gold), Rattenkönigin, Meilenstein 2 000 |
| Fan-Box | `box_fan` | 1 Fan-Item fix (`fixed_pool: "fan"`) + 2 Würfe | — | Meilensteine 250 / 1 000 |

### 9.2 Seltenheits-Gewichte pro Wurf (`rarity_weights`)

| Tier | common | rare | epic |
|---|---|---|---|
| bronze | 80 | 18 | 2 |
| silver | 55 | 38 | 7 |
| gold | 25 | 55 | 20 |
| fan | 50 | 40 | 10 |

Pro Wurf: zuerst Rarität nach diesen Gewichten, dann Eintrag aus `pools.f<etage>.<rarity>` nach Gewicht. Garantien greifen auf den
**letzten** Wurf, falls bis dahin nicht erfüllt. Raritäten im Slice: nur `common`, `rare`, `epic` (`RARITIES`); Boxen enthalten
**keine** Follower (`LOOT_KINDS = item, credits`).

### 9.3 Pools Etage 1 (`lootboxes.json → pools.f1`)

| Rarität | Eintrag (Gewicht) |
|---|---|
| `common` | `credits:15` (30) · `item_bandage ×2` (25) · `item_antidote ×2` (15) · `item_energy_krawumm` (15) · `item_ice_spray` (10) · `item_molotov` (10) |
| `rare` | `item_brutzel_burger ×2` (20) · `item_smelling_salts` (20) · `credits:40` (15) · `item_hype_megaphone` (10) · `item_smoke` (10) · `acc_lucky_ticket` (8) · `acc_rubber_boots` (8) · `arm_safety_vest` (5) · `wpn_collar_studded` (5) |
| `epic` | `item_elixir` (25) · `wpn_fire_axe` (15) · `wpn_collar_signet` (15) · `acc_sneakers` (15) · `arm_ermine` (10) · `wpn_rail_crowbar` (10) · `credits:100` (10) |
| `fan` (Fan-Item) | `acc_clip_mic` (40) · `item_elixir` (30) · `item_hype_megaphone ×2` (30) |

`wpn_collar_royal` ist ab Etage 2 im Pool (`pools.f2.epic`); in Etage 1 nicht erhältlich.

```json
{
  "schema": 1,
  "entries": [
    {"id": "box_bronze", "name": "Bronze-Box", "color": "#CD7F32", "rolls": 2,
     "rarity_weights": {"common": 80, "rare": 18, "epic": 2}, "guarantee": "", "fixed_pool": "", "mod_tag": "lootbox_open_bronze"},
    {"id": "box_fan", "name": "Fan-Box", "color": "#FF5FA2", "rolls": 2,
     "rarity_weights": {"common": 50, "rare": 40, "epic": 10}, "guarantee": "", "fixed_pool": "fan", "mod_tag": "lootbox_open_fan"}
  ],
  "pools": {"f1": {"common": [{"kind": "credits", "id": "", "amount": 15, "weight": 30},
                              {"kind": "item", "id": "itm_bandage", "amount": 2, "weight": 25}],
                   "rare": [], "epic": [], "fan": []}},
  "pity": {"rare": 4, "epic": 8}
}
```

- **Duplikat-Ausrüstung:** Wird ein Ausrüstungsteil gezogen, das schon besessen wird (Inventar oder angelegt), wird es zu Credits
  (`roundi(sell × 0.5)`, `LootRoller.DUPLICATE_CREDIT_MULT`; vorher × 1.5 — doppelte Epics brachten ~350 Cr), Anzeige „DUPLIKAT → +X Cr“ (`LootReward.converted_from = <item_id>`). Verbrauchsitems über der Stapelgrenze 9
  werden zu Credits zum Verkaufswert („LAGER VOLL“).
- **Pity:** `GameState.pity_rare` zählt geöffnete Boxen ohne `rare`+; ist er beim Öffnen ≥ **4**, ist der erste Wurf `rare`.
  `GameState.pity_epic` zählt Boxen ohne `epic`; bei ≥ **8** ist der erste Wurf `epic` (epic hat Vorrang). Ein Treffer der jeweiligen
  Stufe (auch per Garantie) setzt den Zähler auf 0. Beide werden gespeichert.
- **Zufall:** `LootRoller.roll_lootbox(box, data, floor_index, state, rng)` mit `rng` aus `Game.next_seed("lootbox")` (Zähler im
  Spielstand) → deterministisch, kein Save-Scumming durch Neuladen vor dem Öffnen. Pool = Etage, in der die Box geöffnet wird.

### 9.4 Öffnen (UX, nur im Safe Room)

1. Lootbox-Regal: Boxen als 3D-Objekte (Bronze = Holzkiste mit Bronzebeschlägen, Silber = Metall, Gold = goldene Kiste mit Glühen, Fan = pinke Geschenkbox mit Herz-Logo).
2. Box antippen/A → Box springt in die Mitte, M.O.D. `lootbox_open_<tier>` (`LootboxDef.mod_tag`). Timer pausiert (Safe Room).
3. **3 Taps** zum Öffnen: jeder Tap = Rütteln + Licht stärker (Tier-Farbe: #CD7F32 / #C0C8D2 / #FFC83D / #FF5FA2). Rarität des besten Wurfs färbt den Lichtschein ab Tap 2 („Tease“).
4. Explosion (Partikel), Items fliegen als Karten heraus, werden **einzeln** aufgedeckt (0.4 s je Karte, Rand in Raritätsfarbe: common #BFC5CC, rare #4AA8FF, epic #B05CFF).
5. Pity-Treffer: Zusatz-Banner „GARANTIE!“ + M.O.D. `lootbox_pity`.
6. Buttons: „Alle aufdecken“ (überspringt Animation), „Nächste Box“, „Fertig“.
7. Fußzeile dauerhaft sichtbar: „Lootboxen in PRIME TIME DUNGEON können nicht gekauft werden.“
   Im Live-Modus ergänzt um: „Sponsorkisten von Zuschauer:innen: Wahrscheinlichkeiten unter *Odds-Link*.“ (05_LIVE_MODUS)

---

## 10. Safe Room

### 10.1 Funktionen

| Funktion | Regel |
|---|---|
| Betreten | `Router.enter_safe_room(safe_room_id)` → `SafeRoomScene.setup({"safe_room_id": …})`. Volle Heilung (HP, MP, alle Status, KO aufgehoben), Timer pausiert, Gegner können nicht folgen (Tür schließt). `FloorRun.location = safe_room_id`, `FloorRun.visited_safe_rooms` += ID (erster Besuch), Besuchszähler `safe_room_visits` +1 (Payload der Szenenprüfung, Kap. 10.2), M.O.D. `safe_room_enter` |
| **Speichern** | 3 Slots (`user://saves/slot_N.json`), Bestätigung bei Überschreiben; speichert Position = dieser Safe Room (`location`); Laden setzt Kai vor dessen Tür und öffnet ihn |
| **Lootboxen** | Öffnen (Kap. 9.4) |
| **Automat** | Kaufen / Verkaufen (Kap. 6.5), Mengenwahl 1–9, Vorschau Stat-Änderung (grün/rot) |
| **Ausrüstung** | Ausrüsten beider Charaktere |
| **Figur wechseln** (06 §1.6) | Kai ↔ Graf Mopsula als gesteuerte Figur; kostenlos, nur hier (die Erkundung bleibt lesbar). Die Figuren tauschen im Raum die Plätze, Banner „Jetzt führt: …“, M.O.D. `hero_switch:<id>`; aufgezeichnet (Command `hero`) |
| **Mopsula** | Gesprächsszene, wenn eine verfügbar ist (Ausrufezeichen über Mopsula); sonst Zufalls-Einzeiler (Tag `mopsula_idle`, Kap. 11.3) |
| **Verlassen** | Tür → Erkundung (`FloorRun.location = &"start"`), Timer läuft weiter |

Safe Rooms E1 (`floors.json → layout.safe_rooms[] = {id, cell, name, theme, shop}`):

| ID | Zelle | Name | `theme` | Optik (03_ART §6.3) |
|---|---|---|---|---|
| `sr_kiosk` | (2,5) | Kiosk 24/7 | `kiosk` | Kiosk-Theke, Zeitungsständer |
| `sr_pumphouse` | (6,3) | Pumpenhaus | `pumphouse` | 2 Pumpen, Manometer |
| `sr_signalbox` | (2,1) | Stellwerk | `signalbox` | Hebelbank, Gleisplan-Holo |

Gemeinsam: warmes Licht #FFC98A, Sofa (Boxen), Automat (Box mit leuchtender Front #3CE0C0), Röhrenfernseher mit M.O.D.-Gesicht;
gebaut mit `EnvKit.build_safe_room(seed, quality, theme)`.

### 10.2 Mopsula-Szenen (`scenes.json`, je 1×)

Daten (`SceneDef`): `{"id": "scn_mop_1", "name": "Seine Durchlaucht", "condition": "<Ausdruck wie Kap. 8>", "lines": [{"voice":
"mopsula" | "kai" | "mod", "text": "…"}], "set_flag": "", "once": true, "priority": 1}`. Prüfung beim Betreten eines Safe Rooms mit
Payload `e = {safe_room_id, first_visit, safe_room_visits, kai_level}`; abgespielt über `ModDialog` in `scenes/safe_room/safe_room.gd`
(M6), wenn der Spieler „Mopsula“ wählt. Pro Besuch höchstens **1** Szene (kleinste `priority` zuerst). Nach dem Abspielen setzt das
Spiel Flag `scene_<scene_id>` und ggf. `set_flag`. Boss-Siege setzen Flag `defeated_<enemy_id>` (`BattleBridge`). `{name}` in Kai-Zeilen und
Anreden wird durch den Spielernamen ersetzt; „Kai“ als Sprecher = Spielfigur.

| ID | Bedingung (`condition`) | `priority` | `set_flag` |
|---|---|---|---|
| `scn_mop_1` | `e.safe_room_visits >= 1` | 1 | — |
| `scn_mop_2` | `f.defeated_enm_boss_hausmeister == true` | 2 | — |
| `scn_mop_3` | `e.kai_level >= 4 && f.scene_scn_mop_1 == true` | 3 | — |
| `scn_mop_4` | `e.safe_room_id == "sr_signalbox"` | 0 | `mop_pep_talk` |

`once: true` sorgt dafür, dass jede Szene genau einmal läuft; die Bedingungen bleiben über spätere Besuche gültig, damit keine Szene
verloren geht, wenn der Spieler Mopsula beim ersten Mal nicht anspricht (abweichend von „nur beim ersten Besuch“).

**Pep-Talk:** `BattleBridge.make_setup` gibt bei `is_boss` und gesetztem Flag `mop_pep_talk` beiden Party-Combatants `sts_guard` (2 Züge)
und löscht das Flag.

**Szene 1 — `scn_mop_1` „Seine Durchlaucht“** (Bedingung: erster Safe-Room-Besuch)

> **Mopsula:** Kammerdiener:in. Setz dich. Wir müssen reden.
> **Kai:** Du redest seit einer Stunde.
> **Mopsula:** Mit dir. Nicht AN dich. Ein Unterschied, den das gemeine Volk selten begreift.
> **Kai:** Wieso kannst du überhaupt sprechen?
> **Mopsula:** Wir konnten immer sprechen. Ihr habt nur nie zugehört. Neun Jahre „Na, du Dicker?“. Neun Jahre!
> **Kai:** … Ich hab dir jeden Abend das Ohr gekrault.
> **Mopsula:** *(Pause)* Das linke. Das linke war akzeptabel. Weitermachen.
> **M.O.D. (Fernseher):** Zuschauer-Umfrage: 94 % wollen mehr vom Hund. Notiert.

**Szene 2 — `scn_mop_2` „Ahnenreihe“** (Bedingung: Hausmeister besiegt; ab dem nächsten Safe-Room-Besuch)

> **Mopsula:** Der Hausmeister. Er hatte einen Schlüssel für jede Tür und keine einzige, hinter der jemand auf ihn wartete.
> **Kai:** Das ist ungewohnt nachdenklich für dich.
> **Mopsula:** Wir sind von hohem Geblüt. Nachdenklichkeit ist erblich. Unsere Ahnen waren Grafen, Herzöge —
> **Kai:** Deine Mutter war aus einem Kofferraum in Polen.
> **Mopsula:** EIN SEHR VORNEHMER KOFFERRAUM.
> **Kai:** *(lacht)*
> **Mopsula:** … Wartet jemand auf dich? Da oben?
> **Kai:** Da oben ist nichts mehr.
> **Mopsula:** Dann warten Wir eben aufeinander. Das ist ein Befehl.

**Szene 3 — `scn_mop_3` „Das Tierheim“** (Bedingung: Kai-Level ≥ 4 und Szene 1 gesehen)

> **Mopsula:** Weißt du, warum Wir „schwer vermittelbar“ waren?
> **Kai:** Weil du jeden Besucher angeknurrt hast.
> **Mopsula:** Weil sie die Falschen waren. Familien mit Kinderwagen. Pärchen mit Instagram. Niemand wollte einen alten Mops mit Atemgeräuschen.
> **Kai:** Ich wollte dich adoptieren. Nächsten Monat. Die Papiere lagen schon in der Schublade.
> **Mopsula:** *(lange Pause)* … Das sagst du nur wegen der Kameras.
> **Kai:** Die Kameras sind mir egal.
> **Mopsula:** Hmpf. Wir nehmen das zur Kenntnis. Unter Vorbehalt. *(dreht sich weg, Schwanz wedelt)*
> **M.O.D.:** Diese Szene wird in 47 Galaxien gerade mit Taschentüchern beworben. Danke.

**Szene 4 — `scn_mop_4` „Vor dem Thron“** (Bedingung: Besuch in `sr_signalbox`)
**Belohnung:** Flag `mop_pep_talk` → im nächsten Bosskampf starten beide mit `guard` 2.

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

**Platzhalter** (`TEXT_PLACEHOLDERS`): `{name}` (Spielername), `{floor}`, `{level}`, `{enemy}`, `{item}`, `{achievement}`, `{viewers}`,
`{followers}`, `{sponsor}`, `{count}`, `{member}`, `{seconds}`. Es gibt kein `{player}`.
**Auswahl** (`ModAnnouncer`): zufällig (Show-`rng`) aus den Zeilen des Tags, nie zweimal hintereinander dieselbe Zeile;
Tag-Cooldown 20 s (außer `boss_*`, `death`, `timer_*`, `intro`). Tag `a:b` fällt auf `a` zurück, wenn es keine Zeile gibt.
**Priorität:** `death` > `boss_*` > `timer_*` > `achievement*` > `lootbox_*` > Rest. Niedrigere werden verworfen, wenn eine höhere läuft —
außer `vendor_buy`, `safe_room_enter`, `stairs_found` und `floor_end` (`ModAnnouncer.ALWAYS_SAID_TAGS`): Antworten auf eine Aktion
des Spielers bzw. einmalige Etagen-Beats (B3/B6/B8) werden nie verworfen, sondern hinter die laufende Zeile gereiht und
verschieben das Prioritätsfenster nicht (gemessen: der Kauf direkt nach den Lootbox-Sprüchen und der Abstieg direkt nach
`ach_speedrun` gingen sonst immer verloren).
**Daten** (`mod_lines.json`, 02_TECH §4.4.11): ein Eintrag je Zeile `{id: "mod_<tag>_<nn>", tag, voice, text, weight}`; die Tags sind die
Keys aus 11.2/11.3 (`REQUIRED_MOD_TAGS` = alle Keys aus 11.2 ohne die `boss_intro:`/`boss_phase:`-Varianten und ohne `boss_train_warning`, plus
`chat_hype_high/mid/low`, `chat_crit`, `chat_boring`, `chat_mopsula`, `chat_handle`; `achievement:`, `boss_*:`, `event_*`,
`mopsula_idle`, übrige `chat_*` sind optionale Tags; `timer_warn_<s>` ist Pflicht für jeden Wert aus `timer_warnings`).
Validator: max. **110 Zeichen** je Zeile, nur obige Platzhalter.

### 11.2 Sprüche nach Tag (`mod_lines.json`, Stimme `mod`)

| Tag | Sprüche |
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
| `timer_warn_300` | „Noch fünf Minuten! Die Etage bricht bald zusammen. Wir haben Popcorn.“ · „Fünf Minuten bis zum Einsturz. Treppe suchen wäre jetzt ein Trend.“ · „Achtung: Die Unterstadt schließt in fünf Minuten. Bitte zügig zum Ausgang. Oder nicht. Quote!“ |
| `timer_warn_60` | „EINE MINUTE! Laufen Sie! LAUFEN SIE!“ · „Sechzig Sekunden! Ich habe die Dramamusik extra laut gestellt.“ · „Letzte Minute! Der Graf sollte jetzt nicht stehen bleiben, um zu posieren.“ |
| `timer_expired` | „Und … Sendeschluss. Die Etage ist eingestürzt. Mit Ihnen darin. Schade.“ · „Zeit abgelaufen. Ich hatte Sie wirklich gemocht. Bisschen.“ |
| `lootbox_open_bronze` | „Bronze. Wie die Medaille für ‚Dabei sein ist alles‘.“ · „Eine Bronzebox! Was drin ist? Wahrscheinlich ein Pflaster. Mit Werbung.“ · „Bronze! Die Box, die sagt: ‚Wir haben an dich gedacht. Kurz.‘“ |
| `lootbox_open_silver` | „Silber! Jetzt wird’s interessant. Ein bisschen.“ · „Silberbox! Garantiert mindestens selten. Steht so im Vertrag.“ |
| `lootbox_open_gold` | „GOLD! Bitte Trommelwirbel. Den teuren!“ · „Eine Goldbox. Der Konzern hat dafür einen Mond verkauft.“ |
| `lootbox_open_fan` | „Eine Fan-Box! Ihre Fans haben zusammengelegt. Ein paar haben Glitzer reingetan. Sorry.“ · „Von Fans, für Fans, gegen Monster. Rührend.“ |
| `lootbox_pity` | „Endlich Glück! Und nein, das ist kein Algorithmus. Doch, ist es. Egal!“ |
| `death` | „Sendeschluss. {name} und der Graf sind gefallen. Wiederholung um 3 Uhr nachts.“ · „Game Over. Die Zuschauer schalten ab. Ich schalte … noch nicht ab.“ · „Das war’s. Ich lege Ihnen eine Blume aufs Inventar.“ |
| `mopsula_ko` | „DER GRAF IST GEFALLEN! Die Quote stürzt ab! Helfen Sie ihm, sofort!“ · „Unser Publikumsliebling liegt am Boden. Ich verlange eine Wiederbelebung, aus rein geschäftlichen Gründen.“ |
| `kai_ko` | „{name} ist KO! Der Graf ist jetzt allein. Das wird … aristokratisch.“ · „Kandidat:in am Boden. Der Mops übernimmt. Endlich ein Profi.“ |
| `revive` | „Wiederbelebt! Comebacks sind unser Lieblingsgenre.“ |
| `boss_intro:enm_boss_hausmeister` | „Applaus für den Hausmeister! Seit 34 Jahren im Dienst, seit 34 Minuten ein Monster.“ · „Achtung: Er hat einen Schlüssel für alles. Außer für Gnade.“ |
| `boss_phase:enm_boss_hausmeister:2` | „Er verliest die Hausordnung! Paragraf sieben! Das wird hässlich.“ |
| `boss_phase:enm_boss_hausmeister:3` | „Feierabend! Und ein Hausmeister im Feierabend kennt keine Regeln mehr!“ |
| `boss_intro:enm_boss_rattenkoenigin` | „Ihre Majestät, die Rattenkönigin von Gleis 9! Bitte nicht auf den Schwanz treten. Die Schwänze.“ · „Zwei Adelige, ein Bahnsteig. Das ist das Duell, für das die Galaxis bezahlt hat!“ |
| `boss_phase:enm_boss_rattenkoenigin:2` | „Hören Sie das? Das ist der Zug auf Gleis 9. Er ist pünktlich. Zum ersten Mal überhaupt.“ |
| `boss_train_warning` | „Zug fährt ein! Zurückbleiben, bitte — oder verteidigen Sie sich!“ |
| `boss_phase:enm_boss_rattenkoenigin:3` | „Der Zug ist entgleist! Die Königin ist wütend! Ich bin begeistert!“ |
| `boss_defeated` | „Boss besiegt! Die Einschaltquote macht gerade einen Handstand.“ · „Gefallen! Und das zur besten Sendezeit. Danke!“ |
| `level_up` | „Level up! Sie sind jetzt {level}% weniger verzichtbar.“ · „Stufenaufstieg! Mehr HP, mehr MP, gleich wenig Gage.“ |
| `follower_milestone` | „{followers} Follower! Sie haben jetzt mehr Fans als Ihre alte Stadt Einwohner. Hatte.“ · „Meilenstein! Ihre Fans schicken eine Box. Und Liebesbriefe an den Hund.“ |
| `safe_room_enter` | „Safe Room. Keine Monster, keine Kameras. Doch, eine Kamera. Okay, sieben.“ · „Werbepause! Heilen Sie sich, wir verkaufen solange Ihre Highlights.“ · „Willkommen im Safe Room. Bitte den Automaten füttern, er hat Familie.“ |
| `vendor_buy` | „Danke für Ihren Einkauf! Ein Teil des Erlöses geht an … uns.“ · „{item}! Exzellente Wahl. Die anderen waren schlechter. Für uns.“ |
| `stairs_found` | „Die Treppe! Abstieg oder Ruhm — die Uhr sagt Abstieg, das Publikum sagt Königin.“ · „Da ist sie, die Treppe. Ich würde ja noch ein bisschen bleiben. Rein quotentechnisch.“ |
| `floor_end` | „Etage 1 geschafft! Nach der Werbung: Etage 2. Bleiben Sie dran!“ · „Sie haben die Unterstadt überlebt. Bitte unterschreiben Sie hier, hier und — hier, für die Fortsetzung.“ |

(Gesamt 11.2: **90 Sprüche**.)

### 11.3 Weitere Tags (Chat, Mopsula, Events)

| Tag | Stimme | Zeilen |
|---|---|---|
| `timer_warn_600` | chat | „noch 10 min?? lauft!!“ · „zehn minuten. ich hol schnell popcorn nach“ |
| `chat_handle` | chat | „xX_Gleisgeist_Xx“ · „OmaHilde1953“ · „mopsfan_88“ · „KeinZugMehr“ · „Pendlerin_42“ · „GrafFanclub“ · „u_bahn_ultra“ · „LeiseSohle“ |
| `chat_hype_high` | chat | „DAS IST KINO“ · „mops for president!!!“ · „clip it clip it clip it“ |
| `chat_hype_mid` | chat | „solide runde bisher“ · „wer hat auch grad hunger“ · „der graf schaut heute so edel“ |
| `chat_hype_low` | chat | „gähn“ · „kann mal wer was explodieren lassen“ · „ich schalt gleich um auf die kochshow“ |
| `chat_crit` | chat | „KRIT!!“ · „das hat geknallt“ · „ZEITLUPE BITTE“ |
| `chat_stunt_fail` | chat | „hahahaha neiiin“ · „F“ · „bester fail der staffel“ |
| `chat_boring` | chat | „schon wieder dasselbe?“ · „copy-paste-kampf“ · „mach mal was anderes bitte“ |
| `chat_mopsula` | chat | „GRAF MOPSULA <3“ · „der mops trägt diese show“ · „ich würde für den grafen sterben“ |
| `mopsula_idle` | mopsula | „Wir ruhen. Störe Uns nur bei Weltuntergang. Erneut.“ · „Dieser Automat führt keine Leberwurst. Ein Skandal.“ · „Kammerdiener:in, das linke Ohr. Du weißt, welches.“ · „Der Fernseher redet zu viel. Wir respektieren das. Fast.“ · „Ein Sofa. Endlich ein Möbel, das Unseren Stand begreift.“ |
| `event_photo_drone_pose` | mod | „Lächeln! Das wird das Titelbild der Woche. Oder Ihr Nachruf. Beides verkauft sich.“ |
| `event_photo_drone_smash` | mod | „Sie haben meine Kamera zertreten. Ich vergesse nichts. Ich bin buchstäblich ein Speicher.“ |
| `event_lost_candidate_give` | mod | „Sie haben geteilt! Mit einem Fremden! Die Zuschauer sind verwirrt und gerührt.“ |
| `event_lost_candidate_leave` | mod | „Weitergehen. Klug. Herr Brettschneider nimmt das sicher sportlich.“ |
| `event_wheel_spin` | mod | „Dreh das Rad! Die Gewinnchancen sind fair. Laut unserer Rechtsabteilung.“ · „Und das Rad sagt … Werbung! Nein, Moment. Doch nicht.“ |
| `event_lever_open` | mod | „Eine Abkürzung! Die Bauaufsicht hätte das nie genehmigt. Gibt es nicht mehr.“ |
| `event_lever_flood` | mod | „Das war der Spülhebel. Für die ganze Kanalisation. Herzlichen Glückwunsch.“ |
| `event_broken_vending_ok` | mod | „Zwei Dosen KRAWUMM! Vandalismus lohnt sich. Das haben Sie nicht von mir.“ |
| `event_broken_vending_fail` | mod | „Der Automat hat zurückgetreten. Mit 230 Volt. Das Publikum klatscht.“ |
| `achievement:<id>` | mod | je 1 Zeile aus Kap. 8 (29) |
| `hero_pick:kai` / `hero_pick:mopsula` | mod | Intro-Schluss nach der Figurenwahl (06 §1.5): „Kandidat:in {name} übernimmt. Der Graf assistiert. Unter Protest, aber in HD.“ / „Der Graf hat die Fernbedienung an sich genommen. {name} darf folgen. Die Quote jubelt.“ |
| `hero_switch:kai` | mod | „Rollentausch! {name} führt wieder. Der Graf nennt es ‚wohlverdiente Siesta‘.“ · „{name} übernimmt die Führung, der Graf das Sofa. Gerechte Arbeitsteilung.“ |
| `hero_switch:mopsula` | mod | „Rollentausch! Der Graf führt. Bitte Abstand halten, er bellt in Stereo.“ · „Der Graf übernimmt. {name} darf sich ausruhen. Unter Beobachtung, versteht sich.“ |
| `tutorial_explore:mopsula` / `tutorial_sneak:mopsula` | mod | B1-Hinweise, wenn der Graf führt (sonst `tutorial_explore`/`tutorial_sneak`): „Willkommen in der Unterstadt, Graf! Laufen Sie los – {name} kommt hinterher. Die Kamera auch.“ / „Da vorn schlafen zwei Ratten. Bellen Sie, Graf – verdutzte Monster erwischt man von jeder Seite zuerst.“ |
| `chat_bark` | chat | nach einem Bellen mit Treffer: „WUFF IN HD“ · „der graf hat gesprochen“ · „ich hab mich auch erschrocken“ |

(Gesamt: 90 + 46 + 29 = **165 Zeilen**; dazu Block A aus 06 §1.5: 11 Zeilen.)

---

## 12. Klassensystem (ab Etage 3) — Datenvorbereitung

### 12.1 Regeln

- Klassenwahl einmalig zu Beginn von Etage 3 im Safe-Room-Event „**Casting**“ (M.O.D. als Jury). Jede:r Charakter wählt 1 von 4.
- Klassen **ergänzen** (ersetzen nicht) die Basis-Skills. Kein Wechsel im Slice-Folgeumfang (Respec später als Gold-Box-Belohnung denkbar → nicht geplant).
- Datenmodell **jetzt**: `PartyMember.class_id: ""` im Spielstand (02_TECH §6.1/§6.4). `classes.json` existiert mit 8 Einträgen, wird im Slice nicht ausgewertet (DB validiert aber).

### 12.2 Schema `classes.json` (= `ClassDef`, 02_TECH §4.4.4 erweitert)

Felder: `{id, name, desc, for: [party_id], min_floor: 3, stat_mult, growth_add: {stat: float}, passives: [{id, params}],
learnset: [{level, skill}], show_mods: {hype_gain_mult, stunt_success_add, stunt_cooldown, sponsor_thresholds}}`.
Skill-Referenzen in `learnset` dürfen im Slice fehlen (Validator-Ausnahme bei `min_floor > 1`); `passives` werden im Slice nicht
ausgewertet, nur validiert (`id` beginnt mit `pas_`, `params` ist ein Dictionary).

```json
{
  "id": "cls_kai_wrecker",
  "name": "Abrissbirne",
  "desc": "Tank und Schläger. Steht im Weg, und zwar gern.",
  "for": ["kai"],
  "min_floor": 3,
  "stat_mult":   { "hp": 1.10, "str": 1.15, "def": 1.10, "spd": 0.95 },
  "growth_add":  { "hp": 3.0, "def": 0.5 },
  "passives":    [ { "id": "pas_thick_skin", "params": { "taunt_turns_add": 1, "dmg_taken_mult_while_taunt": 0.9 } } ],
  "learnset":    [ { "level": 11, "skill": "skl_kai_wrecking_ball" }, { "level": 13, "skill": "skl_kai_concrete_boots" } ],
  "show_mods":   { "hype_gain_mult": 1.0, "stunt_success_add": 0.0, "stunt_cooldown": 3, "sponsor_thresholds": [70, 85, 100] }
}
```

### 12.3 Klassen

| ID | `for` | Name (`name`) | Rolle | `stat_mult` | Passiv |
|---|---|---|---|---|---|
| `cls_kai_wrecker` | kai | **Abrissbirne** | Tank/Bruiser | HP 1.10, STR 1.15, DEF 1.10, SPD 0.95 | `pas_thick_skin`: Taunt +1 Zug, −10 % Schaden während Taunt |
| `cls_kai_runner` | kai | **Gleisläufer:in** | Tempo/Krit | SPD 1.20, LCK 1.20, DEF 0.90 | `pas_first_strike`: +25 % Krit auf erste Aktion je Kampf; Präventiv-Winkel 90° statt 110° |
| `cls_kai_tinker` | kai | **Schrott-Tüftler:in** | Items/Elemente | MAG 1.30, STR 0.95 | `pas_tinkering`: Schadens-Items ×1.5, Items Rang 1 |
| `cls_kai_showrunner` | kai | **Showrunner:in** | Hype/Stunts | LCK 1.25 | `pas_crowd_magnet`: Stunt-Erfolg +0.15, Stunt-Cooldown 2, Hype-Gewinne ×1.25 |
| `cls_mop_archmage` | mopsula | **Hofmagier** | Elementar-DD | MAG 1.20, MP 1.10 | `pas_exploit`: Schwachstellen-Faktor 1.75 statt 1.5 |
| `cls_mop_physician` | mopsula | **Leibarzt Seiner Hoheit** | Heiler | RES 1.15, HP 1.10 | `pas_bedside`: Heilung ×1.3; Zugbeginn heilt eigenes `poison` |
| `cls_mop_hexer` | mopsula | **Fluchgraf** | Debuffs | MAG 1.10, SPD 1.05 | `pas_curse`: Status-Chancen +0.25, Status-Dauer +1 |
| `cls_mop_diva` | mopsula | **Diva** | Buffs/Show | LCK 1.20, RES 1.10 | `pas_spotlight`: Buff-Dauer +1, Sponsor-Schwellen 65/80/95 |

4 Klassen je Figur (8 Einträge). Die Skill-Listen der Klassen (je 4 Skills L11–L17) werden mit Etage 3 spezifiziert; IDs folgen dem Muster `skl_<kai|mop>_<name>`.
Skill-Freischaltung künftig wie bei der Party: `learnset[{level, skill}]`. Abweichende `show_mods` (Stunt-Cooldown, Sponsor-Schwellen) überschreiben die Konstanten aus Kap. 16.3 für die jeweilige Figur bzw. Show.

---

## 13. Balancing-Ziele

| Kennzahl | Ziel | Grundlage |
|---|---|---|
| Regulärer Kampf: Party-Züge | **4–6** (Median 4.5) | Simulation: 3.2 (Tutorial) bis 5.8 (`grp_c3`) |
| Regulärer Kampf: Gesamtzüge | 7–11 | — |
| Regulärer Kampf: Dauer (×1) | 40–70 s | ~4 s je Party-Zug, ~2.5 s je Gegnerzug |
| HP-Verlust pro regulärem Kampf | 20–35 % der Party-HP | Simulation 16–32 % ohne Heilung zwischen Kämpfen |
| Kämpfe zwischen Safe Rooms ohne Items | 2–3 | — |
| Hausmeister: Party-Züge / Dauer | 16–22 / 2.5–4 min | Sim (`test_m7_show_balance`, 100 Seeds, L5, Bot-Ausrüstung): 21 Züge |
| Rattenkönigin: Party-Züge / Dauer | 20–26 / 3.5–5 min | Sim (dto., L7): 24 Züge |
| Level bei Hausmeister / Königin | **5 / 7** | EXP-Kurve Kap. 4.3 (Faktor 18): auch bei allen Gruppen + Event-Kampf |
| Erwartete Game Overs Etage 1 (Erstspieler) | **0–1** gesamt; Hausmeister ~20 % Niederlage-Rate beim 1. Versuch, Königin ~35 % | Sim mit Sponsor-Geschenken, Hype-Start 25: Hausmeister 17 % (ohne Geschenke 34 %), Königin 29 % (41 %); Test-Band 10–30 % / 25–45 % |
| Timer-Verbrauch Etage 1 | 11–15 min von 20:00 (Rest 5–9 min) | 31 Zellen à 16 m (Hauptpfad ≈ 75 s Laufzeit) + Erkundung, Schleichen, Events, Streuner; Bot `--pace=human` (Messung unten) |
| Gesamtspielzeit Etage 1 (Erstdurchlauf) | **22–28 min** (Median 25) inkl. Tutorial; Wiederholer 15–20 min | Brief: 15–25 min |
| Bekämpfte Gruppen | 11–13 von 15 regulären | — |
| Credits bei Königin | ~1 100 erwirtschaftet, ~800 ausgegeben | — |
| Sponsor-Geschenke pro Etage | 4–7 | Schwellen 70/85/100, max. 1 (Boss 2) je Kampf (Kap. 7.4) |
| Achievements pro Etage (Erstdurchlauf) | 12–16 von 29 | — |
| Lootboxen pro Etage | 15–20 | Achievements + Bosse + Meilensteine 250/1 000 (+ Glücksrad) |
| Follower am Ende E1 | 1 200–1 500 | Kap. 7.6 |
| Max. Zuschauer E1 | 3 000–5 500 | Kap. 7.2 |
| Hype am Kampfanfang / -ende (Median regulär) | 25–45 / 45–65 | Kap. 7.3 Dramaturgie: Abkühlen auf 25, Routinekampf +15–25, Sponsoren erst ab 70 |

**Messung Full-Run-Bot** (`tools/fullrun.sh`, 02_TECH §11.4.1; Stand 2026-10-10; je Zeile Seeds 1–10, `fast` zusätzlich 4242;
Median [Min–Max]). Auto-Kampf = `AutoPolicy` (keine Stunts), der Bot kauft/rüstet Upgrades und heilt mit Items/Safe Rooms.
*typical* = Erstspieler-Modell (ohne die Nebengruppen a4/b3/c2 und ohne Streuner-Jagd), *thorough* = alles, *rush* = nur Safe
Rooms, Tore, Bosse (nach dem ersten Game Over weiter wie *thorough*). `--pace=human` modelliert Umsehen, Entscheiden, Schleichen
und Lesen bei laufendem Countdown (02_TECH §11.4.1) und braucht ≈ 2,5× so lange wie `fast` (ohne Wartezeiten, Untergrenze).
**vorher** = derselbe Bot auf Daten/Konstanten vor dem Balancing (nur die M.O.D.-Korrektur aus Kap. 11.1, sonst brachen Läufe
ab), **nachher** = Stand dieses Dokuments. Bot-Läufe sind nicht bitgenau reproduzierbar (wenige Frames Jitter bei
`time_scale` 5): einzelne Seeds gehen zwischen identischen Ständen anders aus, Boss-Quoten aus 10 Läufen schwanken um ±15
Punkte.

| Kennzahl (Takt `human`) | Ziel | typical vorher → nachher | thorough vorher → nachher | rush vorher → nachher |
|---|---|---|---|---|
| Timer-Verbrauch | 11–15 min | 10:46 → **11:02** [10:32–11:49] | 11:13 → **11:11** [10:47–14:53] | 6:41 → **11:55** |
| Kämpfe / bekämpfte Gruppen | 11–13 von 15 | 18,5 / 15 → 19 / 15 | 19,5 / 15 → 20 / 15 | 14 / 12 → 22 / 15 |
| Party-Züge regulär / HP-Verlust | 4–6 / 20–35 % | 4 / 14 % → 4,2 / 17 % | 4 / 13 % → 4 / 14 % | 4,5 / 18 % → 4 / 17 % |
| Level bei Hausmeister / Königin | 5 / 7 | 6 / 7 → **5 / 7** | 6 / 7 → 6 / 7 | 4 / 7 → 6 [4–6] / 7 |
| Hausmeister: Party-Züge, Niederlage 1. Versuch | 16–22, ~20 % | 13, 0/10 → **19, 2/10** | 12,5, 0/10 → 18,5, 2/10 | 20,5, 0/10 → 17, 4/10 |
| Königin: Party-Züge, Niederlage 1. Versuch | 20–26, ~35 % | 26, 0/10 → **23, 3/10** | 22,5, 0/10 → 22, 5/10 | 24, 1/10 → 21,5, 6/10 |
| Hype Kampfstart / -ende (Median regulär) | 25–45 / 45–65 | 96 / 100 → **37 / 57** | 96,5 / 100 → 37 / 60 | 95 / 100 → 37,5 / 61 |
| Sponsor-Geschenke (davon Boss) | 4–7 | 17,5 (2) → **5 (3)** | 19 (2) → 4 (3) | 14 (2) → 5 (3,5) |
| Achievements / Lootboxen | 12–16 / 15–20 | 19 / 25 → **17 / 19** | 19,5 / 25,5 → 15 / 18 | 16 / 21 → 15,5 / 18,5 |
| Follower Ende | 1 200–1 500 | 6 561 → **1 453** [1 072–1 629] | 7 163 → 1 394 | 4 009 → 1 352 |
| Max. Zuschauer | 3 000–5 500 | 21 926 → **4 978** [3 070–5 262] | 23 671 → 4 761 | 14 526 → 4 555 |
| Credits gesamt / bis Königin / ausgegeben | — / ~1 100 / ~800 | 4 135 / 3 630 / 1 714 → 1 863 / **1 715** / 1 270 | 4 325 / 3 825 / 1 714 → 1 889 / 1 712 / 1 380 | 2 269 / 1 769 / 1 350 → 1 762 / 1 698 / 1 100 |

Takt `fast` (Untergrenze, Spieler ohne Pausen) vorher → nachher: *thorough* 4:11 → 4:31, Hype 99 / 100 → 59 / 80, Geschenke
15 → 14, Follower 6 757 → 1 950, Zuschauer 22 495 → 5 472, Niederlagen Hausmeister/Königin 0/11 · 0/11 → 5/11 · 3/11;
*rush* 2:15 → 5:52 (Niederlage → *thorough*), Follower 2 890 → 1 889, Zuschauer 11 281 → 5 179, Niederlagen 0/11 · 0/11 →
9/11 · 6/11 (L4 am Hausmeister); *dawdle* (+1 Game Over „timer“) Follower 6 654 → 1 897, Zuschauer 22 197 → 5 140. Wer ohne
Pausen spielt, nimmt mehr Hype in den nächsten Kampf (Start ~58) und bekommt ~14 Geschenke — Quote und Follower bleiben durch
die gedämpfte Rückkopplung trotzdem am oberen Rand der Ziele.

**Ursachen (vorher):**

- **Hype ohne Rückstellkraft:** Ein Routinekampf brachte +40–50 (Start +5, Abwechslung +3 je neuer Aktion, Kills +3/+6,
  Overkill +8 bei fast jedem zweiten Kill wegen `OVERKILL_MAXHP_FRAC` 0.5, Combos +5, Schwachstelle +4), Truhen +3 und
  Achievements +8 kamen dazu; der konstante Zerfall −1 / 5 s bis 15 nahm zwischen zwei Kämpfen nur ~5–15 ab → Hype sättigte
  bei 96–100 (Kampfstart 96–99, Ende 100 in jedem Kampf).
- **Rückkopplung Zuschauer ↔ Follower:** Bei Hype 100 Zuschauerfaktor 2,9 und Follower-Rate 3 %; jeder Follower brachte 1 Zuschauer
  (`VIEWER_PER_FOLLOWER` 1.0) → Follower und Peak wuchsen pro Kampf exponentiell (6–7 k / 22 k).
- **Sponsoren in jedem Kampf:** Dauer-Hype über den Schwellen 50/75/100 mit 2 (Boss 3) Geschenken → 15–19 Heilungen pro Etage;
  dazu Hausmeister/Königin zu schwach (auch ohne Geschenke 100 % Auto-Sieg eine Stufe unter Ziel) → 0 Niederlagen in 63 Läufen.
- **EXP-Kurve:** Die L6-Schwelle (624) lag genau auf der EXP-Summe der Zonen A–C → wer alles bekämpft (Streifen erzwingen das
  praktisch), stand eine Stufe über Plan vor dem Hausmeister.
- **Credits/Boxen:** Lootbox-Duplikate × 1.5 (Epic ≈ 350 Cr), Credit-Einträge 25/120/400, Meilenstein 500 (300 Cr + Silber-Box),
  Boss-Credits 200/500, Holzkisten 20–40; Boxen aus ms_100/ms_500 zusätzlich zu ~19 Achievements.
- **Achievements:** `ach_speedrun` (≥ 8:00 Rest) schaffte auch der gemessene Erstspieler-Takt; Achievement-Follower 25/50/100.
- **M.O.D.:** `vendor_buy` und `floor_end` fielen dem Prioritätsfenster zum Opfer (Kauf direkt nach Lootbox-Sprüchen, Abstieg
  direkt nach `ach_speedrun`) → Bot-Läufe brachen an den Story-Beats ab.

**Änderungen:** Hype-Tabelle Kap. 7.3 (etwa halbiert, Overkill erst ab 100 % MaxHP Überschuss), proportionales Abkühlen auf 25
(Kap. 7.3), `VIEWER_PER_FOLLOWER` 0.5 (Kap. 7.2), Follower-Rate 0.7 % + 1.4 % × Hype (Kap. 7.6), Achievements +5 Hype und
20/40/80 Follower (Kap. 8), Sponsor-Schwellen 70/85/100 mit 1 (Boss 2) Geschenk und schwächeren Heilungen (Kap. 7.4),
Hausmeister/Königin härter und mit weniger Credits (Kap. 5.2/5.3), EXP-Faktor 18 (Kap. 4.3), Credits aus Kisten, Lootboxen,
Duplikaten, Meilensteinen und Fahrscheinfresser gesenkt (Kap. 2.5/5.1/7.7/9.3), `ach_speedrun` ≥ 10:00 (Kap. 8),
`ALWAYS_SAID_TAGS` (Kap. 11.1). Abgesichert durch `test_m7_show_balance.gd` (echtes `Show` im Kampf-Loop, Etage 1 als
Staffel: Follower, Zuschauer, Geschenke, Achievements, Boxen und Hype-Dramaturgie in den Bändern oben; Boss-Niederlagequoten mit
Geschenken: Hausmeister 17 %, Königin 29 % bei 100 Seeds, Band 10–30 % / 25–45 %) und `test_m7_balance.gd` (Bosse ohne
Geschenke ≥ 50 % Sieg, Party-Züge in den Bändern).

**Restabweichungen:**

- **Credits bis zur Königin ~1,55× Ziel** (1 700 statt ~1 100; vorher 3,3×): Je Quelle liegt die Etage jetzt im Plan — 12 von
  15 Gruppen (~385) + Hausmeister 150 + 10 Holzkisten (~175) + Spind-/Rad-/Event-Credits (≈ 100) + Lootboxen (~250) + Meilenstein
  500 (150) ≈ 1 200. Der Bot bekämpft aber alle 15 Gruppen plus Event-Kämpfe und Streuner (Streifen erwischen auch *typical*),
  öffnet alle 16 Kisten und dreht das Rad 3×. Ausgegeben werden ~1 270 statt ~800, weil der Bot jede Ausrüstungs-Stufe kauft
  (Samtcape, Rohrzange, Glücks-Fahrschein, Warnweste, Kanalarbeiter-Kombi, Siegel-Halsband = 1 650 Cr). Weitere Kürzungen
  nur zusammen mit den Automatenpreisen: die gemessenen Boss-Quoten setzen diese Käufe voraus.
- **Bekämpfte Gruppen 15 statt 11–13:** Patrouillen jagen Kai auch auf dem *typical*-Weg; das Ziel gilt für Spieler, die Streifen
  ausweichen. Folge: Level am Hausmeister 5–6 statt 5.
- **Achievements 15–17** (Median je Strategie, Einzelläufe bis 19): am oberen Rand bzw. eins darüber, weil der Bot alle Kisten,
  Events und Gruppen mitnimmt; Erstspieler, die nicht alles finden, liegen im Band (Staffel-Simulation 16).
- **Bot vs. Simulation bei den Bossen:** Die Simulation (feste Bot-Ausrüstung, Hype-Start 25, Geschenke wie im Spiel) verliert die
  Königin in 29 %, der Bot im echten Spiel bei typical/thorough in 8 von 20 Läufen (40 %), *rush* (unterlevelt) 6/10; Hausmeister
  Simulation 17 %, Bot typical/thorough 11 von 60 Läufen über drei Messreihen mit identischem Hausmeister (18 %).

---

## 14. UX-Flows

Referenzauflösung **1280×720** (`project.godot`), `stretch_mode = canvas_items`, `aspect = expand`; alle Pixelwerte dieses Kapitels
beziehen sich auf 720p (Werte aus 03_ART §9.2). Alle Menüs fokus-navigierbar (Gamepad/Tastatur), erstes Element hat Fokus.
Touch: sichtbare Mindestgröße **64 px** (`UiTheme.MIN_TOUCH`), Trefferfläche **≥ 88 px** (`UiTheme.TOUCH_HIT`, unsichtbarer Rand),
Abstand zwischen Trefferflächen ≥ 12 px.

### 14.1 Titel

`Boot (Logo NOVA SYNDIKAT „präsentiert“, 2 s) → Title`
Titel: 3D-Hintergrund TV-Studio, M.O.D.-Ikosaeder dreht sich, Logo „PRIME TIME DUNGEON“.
Menü (`TitleScreen`): **Fortsetzen** (Slot mit dem neuesten `saved_at_unix`, nur wenn vorhanden) · **Neues Spiel** · **Laden** ·
**Optionen** · **Credits** (→ `SCENE_CREDITS`) · **Beenden** (nur PC).

### 14.2 Neues Spiel

1. Slot wählen (3 Slots; belegte zeigen Name, Etage, Level, Spielzeit, Datum) → bei belegtem: „Überschreiben?“
2. **Figurenwahl** „Wen steuerst du?“ (06 §1.1, `hero_select`): zwei große Karten nebeneinander — **Kai** („Tierpfleger:in.
   Wischmopp. Haut zu.“ · Feldschlag · Nahkampf/Tank) und **Graf Mopsula** („Mops. Magier. Schwer vermittelbar.“ · Bellen ·
   Magie/Heilung), je mit drehender 3D-Vorschau; Kai hat den Fokus, Links/Rechts wechselt, ein Druck wählt, Zurück → Slots.
   Fußzeile: „Ihr startet immer zu zweit. Wechseln kannst du jederzeit im Safe Room.“
3. Name eingeben — immer **Kais** Name (Standard „Kai“, `LineEdit.max_length = 12`; Bildschirmtastatur für Gamepad/Touch). Führt
   der Graf, fragt er im Pluralis Majestatis: „Wie heißt Unser:e Begleiter:in?“ (Überschrift „BEGLEITER:IN“); Zurück → Figurenwahl
4. Modus: **Prime Time** (Normal) / **Vorabendprogramm** (Leicht: Timer 30:00, Gegnerschaden ×0.75, EXP ×1.2) — später im
   Optionsmenü nur absenkbar, nicht anhebbar (`GameState.difficulty`, Kap. 2.9)
5. Intro-Cutscene (B0, letzte Studiozeile M.O.D. `hero_pick:<id>`) → Erkundung Etage 1

### 14.3 Erkundungs-HUD

Oben links: „● LIVE“-Badge (80×30, rot pulsierend) + Zuschauer (animierter Zähler) + Follower. Oben Mitte: **Timer** (mm:ss, 38 px).
Oben rechts: Hype-Leiste (horizontal, 320×14 px) mit Markern bei 70/85/100 (`SponsorSystem.THRESHOLDS`). Unten: Chat-Ticker (22 px hoch).
Minimap oben rechts unter Hype (nur besuchte Zellen, 136×136 px; Zonenfarbe, Safe Rooms grün, Tore als Balken).
Interaktionsprompt über Objekt.

### 14.4 Pausemenü (Esc / Start / Touch ☰; Timer pausiert)

Tabs: **Party** (Werte, EXP) · **Inventar** (benutzen außerhalb des Kampfes) · **Ausrüstung** · **Fähigkeiten** (Liste + Freischalt-Level,
`scenes/ui/skills_menu.gd`) · **Achievements** (erhalten / verborgen „???“, `scenes/ui/achievements_menu.gd`) · **Bestiarium**
(`scenes/ui/bestiary_menu.gd`) · **Optionen** (Lautstärke Master/Musik/SFX, Kampfgeschwindigkeit, Kamera-Empfindlichkeit, Kamera
invertieren, Modus, Sprache, **Partner automatisch** — Aus/An, Hilfezeile „Dein:e Partner:in kämpft von selbst.“: die nicht gesteuerte
Figur kämpft per `AutoPolicy`, nie Stunt/Flucht; ohne Tutorial, 06 §1.4) · **Zum Titel** (Warnung: „Fortschritt seit dem letzten Safe Room geht verloren.“).

**Bestiarium:** Zustand `GameState.bestiary: Dictionary` = `enemy_id → {defeated: int, weak_known: PackedStringArray}`; `defeated` pflegt
`BattleBridge.apply_result` (Sieg), `weak_known` ergänzt `ShowRules` bei jedem Schwachstellen-Treffer (Element). Einträge erscheinen ab
der ersten Begegnung (Name, Modell, Lv), Werte/HP ab `defeated ≥ 1`, Schwächen einzeln nach Entdeckung.

### 14.5 Kampf-UI

| Element | Position / Größe (720p) | Inhalt |
|---|---|---|
| Zugreihenfolge | rechter Rand, vertikal; Eintrag 1: 64 px, 2–12: 42 px | Porträt-Icons (Party blau umrandet #4AA8FF, Gegner rot #E8455A, Zug grau), Geist-Vorschau |
| Befehlsmenü | unten links, 240×280 px (Zeilen 42 px) | Angriff / Fähigkeit / Item / Stunt (mit Cooldown-Zahl) / Verteidigen / Flucht |
| Untermenü (Skills/Items) | rechts neben Befehlsmenü | Name, MP-Kosten, Element-Icon, Rang als 1–3 Uhr-Symbole, Beschreibung unten |
| Party-Panels | unten Mitte/rechts, je 254×74 px | Name, HP-Leiste + Zahl, MP-Leiste + Zahl, Status-Icons, Stunt-Bereitschaft; Pille **DU** (gold) an der gesteuerten Figur, **AUTO** (cyan) an der Partner-Figur, wenn „Partner automatisch“ an ist (06 §1.4) |
| Gegner-Info | über dem Gegner | Name, HP-Leiste (Zahl erst ab `bestiary.defeated ≥ 1` für den Typ), Status-Icons, Schwächen nach Entdeckung (`weak_known`) |
| Show-Leiste | oben | LIVE + Zuschauer + Hype-Leiste mit Schwellen-Markern; Sponsor-Bauchbinde links unten über dem Ticker |
| Chat-Ticker | unten, 22 px | — |
| Speed-Button | oben rechts | ×1 / ×2 (`toggle_speed`: R / R3) |
| Auto-Button | oben rechts neben Speed | Auto-Kampf an/aus (`toggle_auto`: T / Y); Auto nutzt `AutoPolicy` (nie Stunt, nie Flucht) |

Zielwahl: Pfeil/Highlight + Name; Links/Rechts wechselt, Bestätigen führt aus, Zurück bricht ab. Schadenszahlen: Popups (weiß normal, gelb Schwachstelle, orange Krit, grün Heilung, grau resistent).
Kampfende: Ergebnis-Panel (EXP-Leisten füllen sich, Level-Up-Banner, Credits, Drops, Follower +X) → Bestätigen → Erkundung.

### 14.6 Game Over „Sendeschluss“

Testbild-Effekt (Farbbalken-Shader), M.O.D. `death` bzw. `timer_expired`. Statistik (Zeit, Kills, Peak-Zuschauer aus `FloorRun.stats`).
Buttons: **Letzten Spielstand laden** (Gnadenfrist 3:00) · **Zum Titel**. `s.game_overs` +1 wird sofort in den Slot geschrieben
(`Save.record_game_over(slot)`, nur dieser Zähler; bleibt erhalten, zählt Schmach).

### 14.7 Safe-Room-Menü

Beim Betreten: Heil-Animation + `safe_room_enter`. Menü (vertikale Liste links, Szene rechts):
**Lootboxen (n)** · **Automat** · **Ausrüstung** · **Figur wechseln** (Zeile „Kai führt“ / „Graf führt“) · **Mopsula** (! wenn Szene
verfügbar) · letzte Zeile **Speichern | Weiter** nebeneinander (je halbe Breite). Kopf einzeilig (Raumschild + Name), Statusmeldungen
(„Gespeichert …“, „Jetzt führt: …“) als Banner oben Mitte — so passen sieben Einträge über den Chat-Ticker.

### 14.8 Touch-Layout (nur Querformat, 720p)

| Element | Position (Mittelpunkt) | Größe |
|---|---|---|
| Virtueller Stick | dynamisch: erscheint am Fingerpunkt in den linken 40 % der Breite; Ruhe-Anzeige bei (147, 573) | Radius 90 px, Knopf 40 px, Deadzone 0.15; Auslenkung > 0.6 = Laufen, ≤ 0.6 = Schleichen |
| Kamera | Drag in der rechten Fläche (außerhalb von Buttons), Pinch = Zoom | — |
| **Aktion** (`action`: Interagieren, sonst Feldfähigkeit) | (1147, 587) | 96 px rund, Icon Hand (Prompt aktiv) bzw. Faust (Kai) / Schallwelle (Graf Mopsula) |
| Karte (`map`) | (1227, 140) | 64 px |
| Menü ☰ (`pause`) | (1227, 40) | 64 px |
| Kampf-Befehle | unten links, 2 Spalten × 3 Zeilen | je 200×64 px sichtbar, 88 px hohe Trefferfläche |
| Zielwahl | Gegner direkt antippen = auswählen, erneut antippen oder „OK“ (1147, 587) = ausführen | Trefferfläche ≥ 107 px um Gegner |
| Zugreihenfolge | rechter Rand, 10 Einträge | — |

---

## 15. Etage 2 (Stub) — „Passage Ewiger Rabatt“

| Feld | Wert |
|---|---|
| Thema | Versunkene Einkaufspassage unter der Unterstadt: tote Rolltreppen, Schaufenster, Food-Court mit leuchtenden Pilzen, Dauerdurchsagen „Nur heute! Nur heute! Nur heute!“ |
| Palette | Neon-Pink #FF4FA0, Kühlregal-Cyan #4FE6FF, Schimmel-Gelbgrün #C8E04A, Fliesen-Beige #D9CBB0 |
| Timer | **25:00** |
| `floor_mult` (Zuschauer) | 1.5 |
| Raster | 9×9 Zellen, prozedural aus Modulen (`DungeonGenerator`, kein `layout`; Seed pro Spielstand) |
| Ziel-Level | 7–10 |
| Daten (`floors.json → floor_2`) | `index 2`, `playable: false` (Slice), `theme: "mall"`, `timer_seconds: 1500`, `timer_warnings: [600, 300, 60]`, `floor_mult: 1.5`, `safe_rooms: 2` (Bereich 0..3) |

| ID | Name | Lv | HP | STR/MAG/DEF/RES/SPD | weak / resist | Idee |
|---|---|---|---|---|---|---|
| `schaufensterpuppe` | Schaufensterpuppe | 8 | 90 | 28/8/22/12/12 | fire / ice | Auf der Karte: bewegt sich nur, wenn Kai wegschaut (Kamera-Frustum) → lauert auf Hinterhalt. Im Kampf: `e_pose` (`guard` + `taunt` auf sich). |
| `einkaufswagen_rudel` | Einkaufswagen-Rudel | 8 | 55 ×3 | 24/4/16/8/20 | shock / physical | Tritt immer zu dritt auf, sehr schnell; „Ramm-Kette“: Schaden steigt pro lebendem Rudelmitglied (+20 % je Wagen). |
| `rabattschild` | Rabattschild-Golem | 9 | 120 | 30/20/26/14/9 | ice / fire | Zeigt „−30 %“, „−50 %“, „−70 %“: Prozent = Schadensbonus des nächsten Angriffs, steigt jeden Zug — Vorschau lesen und vorher töten. |

**Boss-Idee:** „**Der Ausverkauf**“ (`boss_ausverkauf`) — ein Koloss aus verschmolzenen Regalen, Wühltischen und
Schnäppchenjägern. Mechanik „Countdown-Preisschild“: Ein Preisschild-Pseudo-Unit in der Zugreihenfolge zählt
„−10 % … −90 %“ herunter; bei −90 % „Black Friday“: Massen-Angriff. Der Countdown wird zurückgesetzt, wenn die Party
in 3 aufeinanderfolgenden Party-Zügen 3 verschiedene `action_key`s nutzt — Show-System und Kampf verzahnt. Quartier-Boss-Idee: „Filialleiterin
im Dauerlächeln“ (optional).

---

## 16. Anhang: IDs, Dateien, Konstanten, Abgleich mit 02_TECH

### 16.1 ID-Präfix-Regel (verbindlich)

Tabellen in diesem Dokument nennen Kurz-IDs. Die Daten-IDs (Regexe aus 02_TECH §4.2, global eindeutig) entstehen so:

| Art | Kurz-ID (Beispiele) | Daten-ID | Regel |
|---|---|---|---|
| Gegner, Bosse | `kanalratte`, `boss_hausmeister` | `enm_kanalratte`, `enm_boss_hausmeister` | `enm_` + Kurz-ID |
| Pseudo-Einheit | `train_gleis9` | `pu_train_gleis9` | `pu_` + Kurz-ID (`enemies.json → pseudo_units`) |
| Verbrauchsitems | `item_bandage` | `itm_bandage` | `item_` → `itm_` |
| Ausrüstung, Schlüssel | `wpn_mop`, `arm_hoodie`, `acc_gas_mask`, `key_master` | `itm_wpn_mop`, `itm_arm_hoodie`, `itm_acc_gas_mask`, `itm_key_master` | `itm_` + Kurz-ID |
| Skills (Party, Gegner, Boss, Stunts) | `kai_heavy_swing`, `e_bite`, `b_broom`, `q_scepter`, `stunt_kai_suplex` | `skl_kai_heavy_swing`, `skl_e_bite`, `skl_b_broom`, `skl_q_scepter`, `skl_stunt_kai_suplex` | `skl_` + Kurz-ID |
| Item-Skills (`use_skill`) | zu `item_bandage` | `skl_item_bandage` | `skl_item_` + Item-Name ohne `item_` |
| Basisangriffe | `attack` | `skl_attack_kai`, `skl_attack_mopsula`, `skl_e_strike` | fest |
| Statuse | `poison`, `stun` | `sts_poison`, `sts_stun` | `sts_` + Kurz-ID |
| Lootboxen | `bronze`, `silver`, `gold`, `fan` | `box_bronze` … `box_fan` | `box_` + Tier |
| Sponsoren | `sp_gluckwasser` | `spn_gluckwasser` | `sp_` → `spn_` |
| Begegnungen | `grp_a2`, `grp_a1_tutorial`, `grp_boss_hausmeister`, `grp_evt_slime` | `enc_f1_a2`, `enc_f1_a1_tutorial`, `enc_f1_boss_hausmeister`, `enc_f1_evt_slime` | `grp_` → `enc_f<etage>_` |
| M.O.D.-Zeilen | Tag `intro`, `boss_intro:enm_boss_hausmeister` | `mod_intro_01`, `mod_boss_intro_enm_boss_hausmeister_01` | `mod_` + Tag (`:` → `_`) + `_<nn>` |
| Etagen-Events | `evt_photo_drone` (alt) | `fev_photo_drone` | `fev_` (`evt_` = Live-Events, 05) |
| Mopsula-Szenen | `mop_scene_1` (alt) | `scn_mop_1` | `scn_mop_<n>` |
| Unverändert | `ach_*`, `cls_*`, `pas_*`, `ms_*`, `zone_*`, `sr_*`, `kai`, `mopsula`, `floor_<n>` | gleich | — |
| Laufzeit-/Layout-IDs | Truhen `f1_c<k>`, Gruppen `f1_g<k>`/`f1_qb`/`f1_fb`/Streuner `f1_s<n>`, Pseudo-Einheiten im Kampf `u0..` | gleich | `gate_*` sind nur Namen in diesem Dokument |

Flags (`GameState.flags`, `f.` in Ausdrücken): `mop_pep_talk`, `scene_<scene_id>`, `defeated_<enemy_id>`, `title_<ms_id>`.

Anzeigenamen unter Distanz-Review (04_STRATEGIE §2.3, Aufgabe E2): „Fan-Box“, „Quartier-Boss“, „NOVA SYNDIKAT“. Die IDs sind
neutral (`box_fan`, `enm_boss_hausmeister`, keine Marken-IDs) — eine Umbenennung ist eine reine Textänderung in `name`/`text`.

### 16.2 Dateien in `res://data/`

Jede Datei ist `{"schema": 1, "entries": [...]}` (02_TECH §4.1), ggf. mit den genannten Zusatzblöcken auf oberster Ebene.

| Kapitel | Datei | Inhalt / Zusatzblöcke |
|---|---|---|
| 3.9 | `statuses.json` | genau 6 `StatusDef` (Kap. 3.9) |
| 3.5, 3.6, 4.4–4.6, 5, 6.1 | `skills.json` | Basisangriffe, Party-, Stunt-, Gegner-, Boss- und Item-Skills (`SkillDef`, Kap. 4.4) |
| 6 | `items.json` | `ItemDef` (Kap. 6) |
| 12 | `classes.json` | 8 `ClassDef` (Kap. 12.2) |
| 4 | `party.json` | `entries: [kai, mopsula]` + `start: {inventory, credits}` (Kap. 4.2) |
| 5 | `enemies.json` | `EnemyDef` (Kap. 5.1–5.3; `ai`, `phases`, `boss_drops`, `model` = ModelSpec nach 03_ART §5.5, kein `visual`) + `pseudo_units` (Kap. 5.3) |
| 1.3, 2, 5.4, 15 | `floors.json` | `FloorDef` (`floor_mult`, `timer_seconds`, `timer_warnings`, `timer_start_after`, `encounters`, `quarter_boss`, `floor_boss`, `theme`, `playable`); Etage 1 mit `layout` |
| 9 | `lootboxes.json` | `entries` (4 Boxen) + `pools` + `pity` (Kap. 9.3) |
| 8 | `achievements.json` | 29 `AchievementDef` (Kap. 8) |
| 7.4 | `sponsors.json` | 7 `SponsorDef` |
| 7.7 | `milestones.json` | 6 `MilestoneDef` |
| 7.5, 11 | `mod_lines.json` | eine Zeile je Eintrag (Kap. 11) |
| 10.2 | `scenes.json` | 4 Mopsula-Szenen (neue Tabelle in `GameData.TABLES`, Präfix `scn_`) |

**`floors.json → floor_1.layout`** (Schema 02_TECH §4.4.7; Inhalt = Karte und Zellentabelle Kap. 1.3; Türen als String aus `"NESW"`,
nach der Türregel Kap. 1.3 berechnet und explizit gespeichert; `kind` klein geschrieben; Zonen-Paletten = 03_ART §2.2, Boss-Räume
nutzen die Boss-Paletten dort; Bosse stehen in den Zellen `quarter_boss`/`floor_boss`, Encounter aus `FloorDef.quarter_boss`/`floor_boss`):

```json
"layout": {
  "zones":  [{"id": "zone_platform", "name": "Bahnsteig Nord",
              "palette": {"floor": "#3A3F4B", "wall": "#1F5F66", "accent": "#FF2E88", "light": "#FFD59E", "fog": "#1A1430", "ambient": "#2A2440"}}],
  "cells":  [{"x": 1, "y": 7, "zone": "zone_platform", "kind": "start", "doors": "N"},
             {"x": 5, "y": 0, "zone": "zone_cellar", "kind": "quarter_boss", "doors": "W"},
             {"x": 0, "y": 0, "zone": "zone_track9", "kind": "floor_boss", "doors": "E"}],
  "gates":  [{"cell": [1, 3], "dir": "N", "requires": "itm_key_master"},
             {"cell": [4, 3], "dir": "N", "requires": "event:fev_lever"}],
  "encounters_placed": [{"group_id": "f1_g0", "enc_id": "enc_f1_a1_tutorial", "cell": [1, 6], "offset": [0.0, 0.0], "state": "IDLE", "turn": false, "waypoints": []},
                        {"group_id": "f1_g1", "enc_id": "enc_f1_a2", "cell": [1, 4], "offset": [0.0, 0.0], "state": "PATROL", "turn": true,
                         "waypoints": [[-4, -4], [4, -4], [4, 4], [-4, 4]]}],
  "chests":   [{"id": "f1_c1", "cell": [0, 5], "offset": [-3.5, -3.5], "type": "metal", "contents": [{"kind": "item", "id": "itm_arm_safety_vest", "amount": 1}]}],
  "events":   [{"id": "fev_lever", "type": "lever", "cell": [4, 3], "offset": [0.0, 3.0],
                "params": {"success": 0.60, "gate": "4,3,N", "flood_pct": 15, "encounter": "enc_f1_evt_slime"}}],
  "spawners": [{"zone": "zone_platform", "pool": ["enc_f1_a2", "enc_f1_a4"], "interval_sec": 90}],
  "safe_rooms": [{"id": "sr_kiosk", "cell": [2, 5], "name": "Kiosk 24/7", "theme": "kiosk", "shop": ["itm_bandage", "…"]}],
  "stairs": {"cell": [1, 0]}
}
```

`DungeonGenerator.generate()` liefert bei vorhandenem `layout` direkt dieses `FloorLayout` (`RoomCell.zone` gesetzt), sonst prozedural.

### 16.3 Globale Konstanten

Kampf/Progression in `Balance` (`core/battle/balance.gd`), Show in `ShowModel`/`ShowRules`/`SponsorSystem`, Erkundung in den M3-Skripten.

| Konstante | Wert |
|---|---|
| `TICK_K` / `TICK_OFFSET` / `RANK_DIVISOR` | 1000 / 10 / 3.0 |
| `HASTE_MULT` / `SLOW_MULT` | 0.6 / 1.5 |
| `DMG_VARIANCE_MIN` / `DMG_VARIANCE_MAX` | 0.9 / 1.1 |
| `HEAL_STAT_MULT` / `HEAL_BASE` / `HEAL_VARIANCE_MIN` / `HEAL_VARIANCE_MAX` | 1.5 / 10 / 0.95 / 1.05 |
| `CRIT_BASE` / `CRIT_PER_LCK` / `CRIT_CAP` / `CRIT_MULT` | 0.05 / 0.005 / 0.40 / 1.5 |
| `AFFINITY` | weak 1.5, normal 1.0, resist 0.5, immune 0.0 |
| `DEFEND_MULT` / `GUARD_DEF_MULT` | 0.5 / 1.5 |
| `DEFEND_MP_PCT` / `DEFEND_MP_MIN` | 0.05 / 2 |
| `COMBO_MULT` | 1.1 |
| `OVERKILL_MAXHP_FRAC` / `OVERKILL_CREDIT_MULT` | 1.0 / 1.25 |
| `POISON_PCT` / `POISON_MIN` | 0.08 / 1 |
| `STUN_BOSS_MULT` | 0.5 |
| `TAUNT_CHANCE` | 0.80 |
| `FLEE_BASE` / `FLEE_PER_SPD` / `FLEE_PER_FAIL` / `FLEE_PREEMPT` / `FLEE_MIN` / `FLEE_MAX` | 0.40 / 0.03 / 0.15 / 0.25 / 0.10 / 0.95 |
| `POST_BATTLE_MP_REGEN` / `KO_REVIVE_HP` / `KO_EXP_MULT` | 0.15 / 1 / 0.5 |
| `DROP_LCK_DIV` | 100 |
| `STUNT_COOLDOWN` / `STUNT_BOSS_MOD` / `STUNT_MIN` | 3 / −0.15 / 0.05 |
| `LEVEL_CAP` / EXP-Kurve `a`·L^`b`+`c` | 10 / 18, 1.7, 15 |
| `TURN_PREVIEW` desktop / touch | 12 / 10 |
| `BACK_DOT` / `CONTACT_RADIUS` / `GRACE_SEC` / `GRACE_RETURN_RADIUS` | −0.34 / 1.1 m / 2.0 s / 6.0 m |
| `WALK_SPEED` / `SNEAK_SPEED` / `SNEAK_STICK_MAX` | 5.5 / 2.5 m/s / 0.6 |
| `HYPE_START` / `HYPE_EXPLORE_FLOOR` / `HYPE_DECAY_TICKS` / `HYPE_DECAY_PM` | 30 / 25 / 60 (= 2 s) / 100 (10 % des Abstands, mind. 1) |
| `SPONSOR_THRESHOLDS` / `MAX_GIFTS` normal / boss / `HYPE_COST` / `HYPE_AFTER_100` | [70, 85, 100] / 1 / 2 / 0 / 80 |
| `VIEWER_BASE` / `VIEWER_PER_FOLLOWER` / `VIEWER_HYPE_BASE` / `VIEWER_HYPE_DIV` | 1000 / 0.5 / 0.4 / 40.0 |
| `FOLLOWER_CONV_BASE` / `FOLLOWER_CONV_HYPE` / `FOLLOWER_BOSS_MULT` / `FLEE_FOLLOWER_LOSS` | 0.007 / 0.014 / 2.0 / 0.01 |
| `ACH_FOLLOWERS` bronze / silver / gold / `ACH_HYPE` / Truhe / Event | 20 / 40 / 80 / 5 / 2 / 5 |
| `TIMER_F1` / `TIMER_GRACE_ON_LOAD` / `TIMER_WARNINGS` | 1200 s / 180 s / [600, 300, 60] |
| `EASY_TIMER_MULT` / `EASY_ENEMY_DMG` / `EASY_EXP` | 1.5 / 0.75 / 1.2 |
| `PITY_RARE` / `PITY_EPIC` / `DUPLICATE_CREDIT_MULT` / `MAX_STACK` / `WOOD_CREDITS` | 4 / 8 / 0.5 / 9 / 10–25 |
| `STRAY_INTERVAL` | 90 s |
| `MOD_TAG_COOLDOWN` / `MOD_MAX_CHARS` / `CHAT_MIN_INTERVAL` | 20 s / 110 / 2.5 s |

### 16.4 Abgleich mit 02_TECH (Felder, die dieses Dokument voraussetzt)

| Bereich | Erweiterung / Änderung |
|---|---|
| Vokabulare (`DataValidator`) | `ELEMENTS = ["none", "physical", "fire", "ice", "shock", "poison"]`; `DAMAGE_TYPES` + `fixed`; `RARITIES = ["common", "rare", "epic"]`; `LOOT_KINDS` für Boxen/Truhen nur `item`/`credits` (Glücksrad zusätzlich `box`/`nothing`/`encounter`); `GIFT_KINDS` Kap. 7.4; `AI_CONDITIONS`/`AI_TARGETS` Kap. 3.11; `TEXT_PLACEHOLDERS` Kap. 11.1; `REQUIRED_MOD_TAGS` Kap. 11; `MODEL_BASES` + `swarm`, `MODEL_PROPS` + die 16 Props aus 03_ART A6 |
| `StatusDef` | `tick_timing`, `tick_min`, Flags `delay_on_apply`/`guard`/`taunt`, `excludes`, `element`; `turns`/`default_turns` 1..99; Reapply setzt `turns_left = neu` |
| `SkillDef` | Kap. 4.4 (`heal_mode`, `success_*`, `fail_effect`, `cooldown`, `flee_guaranteed`, `special`, `kill_hype`, `mp_restore_pct`, `crit_bonus` float) |
| `ItemDef` | `crit_bonus`, `show_mods`, `max_stack`, `sell`, `tags` |
| `EnemyDef` / `PartyMemberDef` | `ai` + `phases` (Kap. 3.11), `explore` (Kap. 2.3), `status_resist`, `boss_drops` (Gegner); `pseudo_units` (`pu_`); `ModelSpec.pose` (`auto` \| `quadruped` \| `upright`) |
| `EncounterDef` / `FloorDef` | `tutorial`; `floor_mult` statt `viewer_base`, `timer_start_after`, `layout`, `safe_rooms` 0..3, `timer_warnings` Default `[600, 300, 60]` |
| `SponsorDef`, `LootboxDef`, `AchievementDef`, `ClassDef` | Kap. 7.4, 9.3, 8, 12.2; neue Tabellen `milestones` (Kap. 7.7) und `scenes` (Kap. 10.2) |
| `GameState` | `difficulty`, `pity_rare`, `pity_epic`, `bestiary`; `create_new` liest `party.json → start` |
| `FloorRun` | `timer_started`, `completed_events`, `visited_safe_rooms`, `location` (`&"start"` oder Safe-Room-ID), `stats {time_used, kills, viewers_peak, followers_gained, achievements}` |
| `ShowState` | `hype` Start 30, `milestones` |
| Kampf-Kern | `Combatant.stunt_cooldown`, `is_pseudo`, `status_resist`; `BattleState.failed_flee_attempts`, `last_party_target`, `last_actor_side`; `BattleResult` Felder Kap. 8; `ActionEvent.Type` + `COMBO`, `CREDITS_STOLEN`, `ESCAPED`; `CTB_ORDER` 12 Einträge |
| Eingabe | Actions `action` (F/Space/Enter, Button 0) und `sneak` (Shift, Button 7, Achse 4 LT); `attack`, `interact`, `sprint` entfallen; `toggle_speed` = R / Button 8; `battle_speed` ∈ {1.0, 2.0} |
| UI / Save | `UiTheme.TOUCH_HIT = 88`; `Save.load_slot` Gnadenfrist 180 s; `Save.record_game_over(slot)` schreibt beim Game Over nur `game_overs` +1 in den Slot |
