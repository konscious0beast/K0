# PRIME TIME DUNGEON — Echtzeitkampf „WoW-light“ (verbindlich ab R1)

> Status: **verbindlicher Vertrag** für die Umstellung vom CTB-Kampf (01_GDD §3, 02_TECH §5) auf Echtzeitkampf direkt in der
> Welt (Nutzerentscheidung 2026-10-10: „Variante 3 bitte“ = „WoW-light direkt in der Welt“, festgehalten in 00_BRIEF Kap. 2
> und 5). Gilt für die Umsetzungsphasen R1–R5 (§12). **Überarbeitet nach einem unabhängigen Review (2026-10-10):** Die
> Entscheidungen dazu stehen gesammelt in §0.1 und sind in die Kapitel eingearbeitet.
> **Vorrang:** `00_BRIEF` > **dieses Dokument** (alles Kampfrelevante: APIs, Schemas, Befehle, Pfade, Zahlenstruktur) >
> `06_PROGRESSION_MAROTTEN_KI_ADMIN` (Progression, Marotten, KI-Admin, Twists — einschließlich ihres Verhältnisses zum Kampf:
> Twists und KI-Zeilen gibt es im Kampf nicht) > `01_GDD` / `02_TECH` / `03_ART` / `05_LIVE_MODUS` (je nach Thema; Bestands-APIs
> aus 02_TECH gelten, soweit 07 oder 06 sie nicht ändern). Bis zum Abschluss von R5 bleibt der CTB-Kampf hinter dem Schalter
> `combat_mode` (§12.1) unverändert lauffähig; mit R5 ersetzen §2–§11 dieses Dokuments 01_GDD §3 und 02_TECH §5.
> **Reihenfolge:** Die 06-Pakete A–D (Heldenwahl, Talent-Show/Spezies, Marotten, KI-Admin) werden **vor** jeder 07-Umsetzung
> nach `claude/prime-time-dungeon` gemergt. R1a ist danach der **zweite Vertrags-Commit** (§12.2); Dateieigentum und
> Merge-Regeln je Datei stehen in §12.3.
> Engine: Godot **4.7.2-stable (official)**. Engine-Fakten mit **(geprüft)** wurden am installierten Binary gemessen
> (Headless + Xvfb, Renderer Compatibility/OpenGL 3.3 und Mobile/Vulkan; Protokoll in Anhang A).
> Sprache: Prosa Deutsch. Bezeichner, Pfade, JSON-Keys, Signal-/Methodennamen Englisch. Pfade relativ zu
> `prime-time-dungeon/game/` (= `res://`). Stand: 2026-10-10.

---

## Inhalt

0. [Kurzfassung](#0-kurzfassung) — [0.1 Entscheidungen 2026-10-10 (nach Review)](#01-entscheidungen-2026-10-10-nach-review)
1. [Ziele und Prinzipien](#1-ziele-und-prinzipien)
2. [Kampffluss in der Welt](#2-kampffluss-in-der-welt)
3. [Simulation (Kern)](#3-simulation-kern)
4. [Fähigkeiten](#4-fähigkeiten)
5. [Partner-KI](#5-partner-ki)
6. [Gegner-KI und Bosse](#6-gegner-ki-und-bosse)
7. [Steuerung und UX](#7-steuerung-und-ux)
8. [HUD (TV-Overlay)](#8-hud-tv-overlay)
9. [Show-System, Marotten und 06-Abbildung](#9-show-system-marotten-und-06-abbildung)
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
| Ort | Gekämpft wird in dem Raum, in dem man sich trifft. Ein leuchtender Studio-Klebeband-Ring (LED) markiert das **Kampf-Set** (Radius 4,8 m, Bossräume 6,0 m); verlassen kann man es nur durch die Türgassen (= Fluchtversuch). Keine Kampfszene, kein Szenenwechsel, kein Swirl (§2). |
| Start | **Pull** (Feldschlag, Fähigkeit oder Gegenstand auf einen Anführer), ein verfolgender Anführer erreicht dich (**Waffenreichweite**), oder **4 s Verfolgung** im selben Raum. Gesehen werden allein startet keinen Kampf — Schleichen und Entkommen bleiben möglich. Erstschlag/Hinterhalt bleiben (§2.2). |
| Bedienung | Ziel wählen (Tab / Klick / Antippen), Auto-Angriff läuft automatisch, Aktionsleiste: 4 Fähigkeiten + **SHOW** + **Trank** (PC-Tasten 1–6), dazu **eine** Taste **Partner-Spezial** (`R`). |
| Ressource | **MP für beide** („Energie“, eine blaue Leiste). Kai lädt durch eigene Auto-Treffer **und** erlittene Treffer, Graf Mopsula über Zeit; Kais Hauptfähigkeit kostet 2 MP (§3.10). |
| Partner | Gesteuert wird die gewählte Figur (`GameState.hero`, 06 §1). Die andere spielt die KI mit 3 Taktiken und 3 Schaltern; „Partner-Spezial“ befiehlt ihre Signatur sofort (Kai: Spott, Mopsula: Heiliges Schlabbern). Bei K.O. der gesteuerten Figur wechselt die Steuerung vorübergehend zur lebenden (§5). |
| Gegner | Bedrohungsliste, sichtbare Zauberleisten, **markierte** unterbrechenswerte Zauber, Boden-**Telegraphen** (Kreis, Kegel, Ring, Linie), die 15–30 % der Max-HP kosten; jede Gegnerfamilie hat genau eine Signatur-Mechanik (§6). |
| Bosse | Drei Phasen mit je einer neuen Mechanik, weiches Enrage; Rattenkönigin mit einfahrendem Zug als Linien-Telegraph über ebenerdige Gleise (§6.7). |
| Determinismus | `RtSim` (`core/rt/`, RefCounted) mit 30 Ticks/s, nur Ganzzahlen (HP, MP, cm, Ticks, ‰), Zufall pro Ereignis aus `SeedUtil.derive`. **Spielerbewegung** geht als aufgezeichnete Positionsproben mit Plausibilitätsgrenzen in die Sim (Grad A, 05 §3.3); Gegner, KI-Partner, Status, Schaden rechnet nur die Sim, die Szene stellt dar (§3.5). |
| Show | Neue Hype-Anlässe: Unterbrechen und Ausweichen (angerechnet nur der gesteuerten Figur), perfekte Bossphase, Zug-Kill; Sponsor-Geschenke ohne Pause mit kurzem Banner; M.O.D. kommentiert mit geschriebenen Untertiteln; Talente, Marotten, Show-Boss und Twists sind abgebildet (§9). |
| Uhr | Der Etagen-Timer steht im Kampf („die Uhr steht“, Brief); im Kampf öffnet kein Sponsor-Fenster, kein Twist, keine KI-Zeile (§2.10, §9.3, §9.5). |
| Einstieg | Tutorial-Kampf in vier Schritten (Ziel → Taste 1 → SHOW → Ausweichen), die Sim wartet während jeder Hinweiskarte; Unterbrechen lernt man später beim ersten passenden Gegner (§2.13). |
| Umsetzung | 06 zuerst gemergt → R1a Vertrags-Commit → R1b Kern in Stufen → parallel R2 Welt, R3 HUD+Eingabe, R4 Inhalte+Balance, R5a Show/Live → R5b Integration, CTB-Entfernung (§12). |

### 0.1 Entscheidungen 2026-10-10 (nach Review)

Die Nutzerin/der Nutzer hat Detailentscheidungen delegiert (Maßstab: gute UX, Spaß, Witz, **einfaches, sofort verständliches**
Konzept; Grundsatzentscheidung „Variante 3 — WoW-light direkt in der Welt“). Ein unabhängiges Review fand 33 Punkte; so sind sie
entschieden (Nummern = Review-Punkte):

| Nr. | Thema (Review) | Entscheidung | Wo |
|---|---|---|---|
| E1 | Eigentum, Reihenfolge (1, 13, 31) | 06 A–D werden vor 07 gemergt; **R1a = zweiter Vertrags-Commit** nach dem 06-Merge mit allen phasenübergreifenden Signaturen, Fake-Sim und vorgefertigten Ereignisströmen; Datei-Eigentum je Datei mit 06-Paket und Merge-Regel; RT-Validierung in `core/data/validators/rt.gd`, Vokabulare in `rt_vocab.gd` (beide R1a); eigener Anker-Block in `mod_lines.json`; Stellwerte in `data/rt_balance.json` (Eigentum R4); Merge-Stufen: R1b-I1 öffnet die Gates von R2/R3, R1b-I3 die von R4/R5a | §12.2, §12.3 |
| E2 | Twists, KI-Zeilen (2) | 06 regelt: Twists nur in der Erkundung, nie im Kampf; Kampf-Twists werden beim `make_rt_setup` zu statischen `RtMods`. Kein `RtSim.apply_twist`, kein `skl_tw_rat_rain`, kein `ct` an `twist`. Im Kampf keine KI-generierten Zeilen (nur geschriebene M.O.D.-Untertitel), danach geht „M.O.D. live“ weiter | §9.3, §9.5 |
| E3 | Begehbare Fläche (3, 27, 33) | **Kampf-Set:** LED-Klebeband-Ring, Radius nach Raumart (regulär 4,8 m, Boss 6,0 m), weicher Kollisionsring, Verlassen nur durch Türgassen (= Fluchtversuch); keine Requisiten im Set (Bossräume halten 6,2 m frei); Treppenraum ohne Set; Waggon und Gleise der Königin als Sperrfläche bzw. ebenerdig in `RtGeo`; Telegraphen auf das Set beschnitten; `keep_cm` ≤ 700; Anführer außerhalb laufen sichtbar herein („Auftritt“); Akteure anderer Räume ausgeblendet; schlechtester Fall gemessen | §2.1–2.4, §3.5.4, §8.10 |
| E4 | Schadensrechnung (4) | Faktoren einzeln mit `FixedMath.mul_pm` falten, neutrale 1000 überspringen, Gesamtfaktor deckeln (0…8000 ‰); Überlauftest mit Höchst-Stapeln | §3.9.1 |
| E5 | Replay-Schleife (5) | je Tick `c`: Tick-Grenze(c, Log-Geschenk bei c) → alle Einträge mit `ct == c` in Log-Reihenfolge → `step()`; höchstens ein Geschenk je Grenze; Test: externes + System-Geschenk im selben Tick | §9.2, §10.6 |
| E6 | Brief (6) | Brief-Änderung mit Wortlaut („Variante 3 bitte“), CTB-Nennungen „bis R5“; Voraussetzung für R1a | 00_BRIEF |
| E7 | 06-Abbildung (7) | Man steuert `GameState.hero`; Partner = KI mit Taktik + **Partner-Spezial**-Taste (Touch: 88 px neben dem Party-Rahmen); Steuerung folgt dem Leben vorübergehend (CombatDirector); Bellen → `DAZED` → Pull = Erstschlag; Talent- und Marotten-Abbildung, Show-Boss „alle 8 s“; 06-ID-Präfixe; Talentwahl nur im Safe Room; Kai 550 cm/s, Mopsula Radius 35 cm | §5.1, §9.6 |
| E8 | IP (8) | kein Kronen-Motiv an Mopsula (Siegel-Plakette, Monokel); Liga-Wortlaut nur „ohne Rüstung & ohne Accessoire“, kein Kampfabzug als Beispiel | §4.3, §9.5 |
| E9 | Tick-Ablauf, Reinheit (9, 10) | Spielerposition in Schritt 1 des Ticks; jede Sofortwirkung frühestens 1 Tick nach dem Start; Refresh behält die Periodenphase; `can_use`/`suggest` rein (kein Wurf, keine Schreibzugriffe) + Hash-Invarianz-Test | §3.3, §3.4 |
| E10 | FINALE (11, 19) | Bedingung in der Sim: ab Stufe 6, nur wenn das Ziel unter 30 % HP hat (echter Finisher); Hype nur Darstellung | §4.1 |
| E11 | Bewegungsvertrauen (12) | Verschiebung zwischen zwei Proben ≤ Lauftempo × Δ + langsam auffüllendes Toleranzbudget; Kampfbewegung ist **Grad A**; Befehl `move_input` für **Grad B** (Server rechnet Bewegung) reserviert; 05 angepasst | §3.5.2, §10.1 |
| E12 | Regeneration (14) | nur bei `combat_mode = realtime`; MP 2 % je 3 s außerhalb des Kampfes, HP 0,5 % je 3 s erst nach 5 s ohne Schaden; Prüfung im Etagenfolge-Gate | §2.7 |
| E13 | MP-Ökonomie (15) | Kai +1 MP je Auto-Treffer **und** +1 je erlittenem Treffer (höchstens 1/s); Slot 1 kostet 2 MP; KI-Füller halten die Kosten ihrer Unterbrechung zurück | §3.10, §5.3 |
| E14 | Telegraph-Schaden (16) | vermeidbare Treffer 15–30 % der Max-HP (Zug 35 %); Auto-Angriffe bleiben klein | §6.3, §6.5–6.7 |
| E15 | DoTs (17) | Party-DoTs ticken mit Kraft (Formel), Gegner-%-DoTs mit Deckel je Tick, Boss-Tick-Faktor | §3.8 |
| E16 | Tränke (18) | gemeinsame Gegenstand-Abklingzeit der Party 15 s, höchstens 3 Verbrauchsgüter je Kampf, 0,5 s Trinkpause; KI nur mit „Vorsichtig“ oder Trank-Schalter, nie den letzten | §3.11, §5.2 |
| E17 | Hype-Zuordnung (19) | SHOW-Abklingzeit 30 s für die ganze Party; `ActionEvent.by_ai`; Abwechslung, Ausweichen, Unterbrechen und neue Achievements zählen nur für die gesteuerte Figur; Slot 1 ohne Wiederholungsabzug | §9.1, §9.4 |
| E18 | Unterbrechen (20) | `interrupt_worthy` an Gegnerfähigkeiten; Füller nicht unterbrechbar; Gold-Rand, Ton und KI nur für markierte Zauber | §6.2, §6.5 |
| E19 | Touch (21) | Stick-Zone im Kampf nur unten links; Tippen ≠ Ziehen; alle Ziele ≥ 88 px; weiche Zielführung der Kamera auf Touch standardmäßig an | §7.3, §7.5 |
| E20 | Zauberabbruch (22) | Bewegung bricht einen Zauber erst ab 25 % Lauftempo oder > 40 cm seit Zauberbeginn | §3.6 |
| E21 | Einstieg (23) | Tutorial in Schritten (Ziel → Slot 1 → SHOW → Ausweichen); Unterbrechen später als Kontext-Hinweis; CombatDirector pausiert die Sim während Hinweiskarten (aufgezeichnet); mehr Tutorial-HP; GDD-B1-Erstschlag über eine schlafende (`DAZED`) Tutorial-Gruppe | §2.13 |
| E22 | Sichtung (24) | CHASE bleibt; Kampf ab Waffenreichweite, per Pull oder nach 4 s Verfolgung im selben Raum | §2.2 |
| E23 | Kleinere Punkte (25–30, 32) | Flächen der Party: Radius + Zielradius; HUD schrittweise (Bedrohungspunkte nach dem ersten Spott, Taktik-Chip nach dem ersten Safe Room, Restsekunden per langem Druck); Koop-Hinweise in §10.8; CI 5 Seeds je regulärer Begegnung, 10 je Boss, nachts 200; Etagen-Bänder im R5-Full-Run plus Etagenfolge-Harness, `typical` aus Replays kalibriert; zweite Gruppe nur bis 6 Einheiten insgesamt, fester Anker für gruppenlose Kämpfe | §2.3, §6.3, §8.1, §10.8, §11.4 |
| E24 | Offene Punkte | O1–O10 entschieden (Zeitlupe überall erlaubt mit Kennzeichnung, Pause nur offline, Regeneration nach E12, FINALE in der Sim, …) | §13.2 |

---

## 1. Ziele und Prinzipien

1. **WoW-light, nicht WoW.** Übernommen werden die lesbaren Kernideen: Ziel wählen, Auto-Angriff, Aktionsleiste mit
   Abklingzeiten, globale Abklingzeit (GCD), Zauberleisten, Unterbrechen, Bedrohung (Aggro) und Spott, Buffs/Debuffs mit Timern,
   Boden-Telegraphen, Bossphasen, Tränke mit eigener Abklingzeit. **Nicht** übernommen: Blickrichtungs-Pflicht, Springen,
   Freies Zielen/Skillshots des Spielers, Kombopunkte, zweite Ressource, Eigenbeschuss (Friendly Fire), Rüstungsklassen,
   Trefferchance-Würfe (alles trifft; Würfel nur für Varianz, Krit, Status, Stunt-Erfolg).
2. **Einfach und sofort verständlich.** Höchstens 5 Fähigkeiten pro Figur (4 + SHOW) plus Trank, dazu eine Taste für den
   Partner. Die Leiste **wächst mit dem Level** (Stufe 1: Kai 1 Fähigkeit + SHOW, Mopsula 2 + SHOW; ab Stufe 4 voll). Pro
   Gegnerfamilie genau **eine** neue Mechanik, pro Bossphase genau **eine** neue Mechanik. Jede gefährliche Aktion ist dreifach
   angekündigt: Bodenform + Ton + Zauberleiste mit Namen. Der Kampfort ist sichtbar begrenzt (LED-Ring des Sets, §2.1).
3. **Auf einen Blick lesbar.** Formen statt Zahlen: rot-weiß gestreifte Bodenflächen = „raus da“, goldener Rand an einer
   Zauberleiste = „jetzt unterbrechen lohnt sich“, Punkt über dem Gegner in Partyfarbe = „wen er angreift“. Schadenszahlen klein
   und kurz, Wichtiges groß (UNTERBROCHEN!, AUSGEWICHEN). Das HUD zeigt Neues erst, wenn es gebraucht wird (§8.1).
4. **Mobile zuerst.** Alles mit zwei Daumen erreichbar: linker Stick (nur unten links), rechte Daumen-Gruppe, Partner-Spezial
   neben dem Party-Rahmen (§7.3). Auto-Angriff ohne Taste, automatische Zielwahl (nächster Gegner, „Smart-Heilung“ auf den
   schwächsten Verbündeten), weiche Zielführung der Kamera, Eingabepuffer von 300 ms (Queue-Fenster, §3.6), alle Trefferflächen
   ≥ 88 px. PC und Gamepad nutzen dasselbe Modell mit Tasten.
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
| **Set** („Kampf-Set“) | Die Kampffläche in der Raumzelle (`FloorLayout`-Zelle, 16 × 16 m) der gesteuerten Figur beim Start: ein **Kreis** um die Raummitte, auf dem Boden markiert durch einen leuchtenden **Studio-Klebeband-Ring** (LED-Tape, Show-Licht), Radius `SET_R_CM` nach Raumart (§2.4: regulär 480, Bossräume 600), plus die **Türgassen** — Lücken im Ring vor jeder offenen Tür (4 m breit wie die Tür). Requisiten stehen nie im Set. |
| **Kampf** | Eine `RtSim`-Instanz. Es läuft höchstens ein Kampf gleichzeitig. |
| **ct** | Kampf-Tick (0, 1, 2, …), 30 pro Sekunde, zählt ab Kampfstart. Die Lauf-Uhr `k` (RunSim) steht währenddessen (§2.10). |
| **Teilnehmer** | Party-Einheiten (`p0`…`p3`) und Gegner-Einheiten (`e0`…) der beteiligten Gruppen (§2.3), plus Beschwörungen. |
| **Auftritt** | Steht ein Anführer beim Start außerhalb des Rings, läuft er sichtbar ins Set (≤ 1 s, ohne Aktionen); seine Komparsen springen am Eintrittspunkt ins Bild (§2.3). |
| **Gesteuerte Figur** | Die Held:innen-Wahl `GameState.hero` (06 §1: `"kai"` oder `"mopsula"`); bei deren K.O. vorübergehend die lebende Partnerfigur (§2.6). |
| **Telegraph** | Angekündigte Bodenfläche (Kreis, Kegel, Ring, Linie), die nach der Warnzeit einschlägt (§6.3). Sichtbar und wirksam nur innerhalb des Rings. |
| **Zone** | Bleibende Bodenfläche nach einem Einschlag (z. B. Giftpfütze), wirkt periodisch. |

### 2.2 Auslöser und Erstschlag

Die Wahrnehmung der Erkundung bleibt unverändert (GDD §2.3: Sichtkegel mit Sichtlinien-Raycast, Hören, ALERT 0,6 s, Patrouille,
CHASE, RETURN; Bosse bei 5 m um `boss_spot`; 06 §1.3: Bellen → `DAZED`). **Gesehen werden allein startet keinen Kampf**: Wer
entdeckt wird, kann sich wegschleichen, durch eine Tür entkommen (die Verfolgung bricht unverändert nach 4 s ohne Sicht, 20 m
Leine oder 8 s ab) oder die Gruppe anbellen. Ein Kampf beginnt nur so:

| Auslöser | Ergebnis (`BattleSetup.Advantage`) |
|---|---|
| **Pull:** Feldschlag trifft eine Gruppe (Kai: Bogen 100°, 1,8 m, unverändert) oder eine Fähigkeit/ein Gegenstand der gesteuerten Figur auf einen Anführer im eigenen Raum — und die Gruppe ist IDLE, PATROL oder **DAZED** (angebellt, 06 §1.3), oder die Figur steht hinter dem Anführer (`dot(fwd_e, d_ek) < BACK_DOT`) | `PREEMPTIVE` („Erstschlag!“) |
| Pull auf eine Gruppe in ALERT/CHASE, die die Figur sieht | `NORMAL` |
| **Waffenreichweite:** der Anführer einer verfolgenden Gruppe (CHASE) kommt der gesteuerten Figur auf `reach_cm` + beide Radien nahe (Werte aus `enemies.json → rt`, z. B. Kanalratte 220 + 30 + 40 = 2,9 m) | `AMBUSH` („Hinterhalt!“), wenn die Figur ihm den Rücken zukehrt (`dot(fwd_k, d_ke) < BACK_DOT`), sonst `NORMAL` |
| **4 s Verfolgung:** ein Anführer verfolgt ohne Unterbrechung `CHASE_COMBAT_SEC` = 4,0 s und steht dabei mit der Figur in derselben Zelle (Raumwechsel setzt den Zähler auf 0) | `NORMAL` („Die Kamera hat euch!“) |
| Boss (5 m um `boss_spot`), Etagen-Event-Kampf | `NORMAL` |
| Tutorial-Gruppe: schläft (`DAZED` ohne Ablauf, nimmt nichts wahr, 06-`is_asleep_spawn`) — nur ein Pull weckt sie | immer `PREEMPTIVE` (GDD B1 „Erstschlag“ bleibt erhalten) |

- Der Kontakt bei 1,1 m (`CONTACT_RADIUS`) entfällt als Auslöser im Echtzeitmodus.
- Mopsula als Held:in: Bellen startet nie einen Kampf (06 §1.3); ihr Pull ist eine Fähigkeit auf einen Anführer (Slot 1
  Adelsflamme, Slot 3 Frostniesen) oder ein Gegenstand. Eine `DAZED`-Gruppe ist aus jeder Richtung `PREEMPTIVE`
  (06-Regel `EncounterRules.advantage_for_contact`, auch für Pulls).
- Erkennung und Vorteil sind Szenenlogik (Grad A, 05 §3.3); aufgezeichnet wird wie bisher nur das Ergebnis (`encounter`).

Wirkung des Vorteils:

- `PREEMPTIVE`: alle Gegner erhalten `sts_dazed` („Überrumpelt“) für 3,0 s — keine Angriffe, keine Fähigkeiten, 50 % Tempo.
  Bosse sind immun. Hype wie bisher (+3, ShowRules `HYPE_START_PREEMPTIVE`). Talent „Erster Eindruck“ (`preemptive_dmg_pm`)
  wirkt auf den Eröffnungstreffer und auf Treffer gegen überrumpelte Ziele (§9.6).
- `AMBUSH`: alle Party-Einheiten erhalten `sts_dazed` für 1,5 s. Hype +5 (Drama, `HYPE_START_AMBUSH`).

Ein Pull mit Fähigkeit/Gegenstand startet den Kampf und führt die Fähigkeit als **Eröffnung** bei `ct = 0` aus
(`RtSetup.opener`, §3.4). Der Feldschlag als Eröffnung wird bei `ct = 0` zum ersten Auto-Angriff-Schwung auf den getroffenen
Gegner (Treffer bei `ct = 9`). Außerhalb des Kampfes sind Fähigkeiten nur als Pull nutzbar; Heilen außerhalb des Kampfes geht
über Gegenstände, Regeneration (§2.7) und Safe Rooms.

### 2.3 Sichtlinie, Mitziehen, Auftritt

- **Sichtlinie in der Sim** (`RtGeo.los`, §3.5.4): Im Set gibt es keine Requisiten; zwei Punkte im Set sehen sich immer. Die
  Erkundungs-Wahrnehmung (Raycast gegen Layer `world`) bleibt Szenenlogik.
- **Mitziehen:** Am Kampf nehmen die Gruppen teil, deren Anführer beim Start in der Set-Zelle steht — aber nur, solange die Summe
  ≤ `MAX_ENEMIES` = 6 Gegner-Einheiten bleibt. Reihenfolge: Auslöser-Gruppe zuerst, dann nach Abstand des Anführers zur
  Raummitte (Gleichstand: Gruppen-Id). Eine Gruppe, die die Grenze überschreiten würde, macht nicht mit: Ihr Anführer bleibt am
  Ring stehen (eingefroren, sichtbar), M.O.D. sagt „Ruhe am Set! Ihr seid später dran.“ (`rt_set_quiet`, höchstens einmal je
  Etage); nach dem Kampf geht sie in RETURN.
- **Auftritt:** Jeder Anführer startet an seiner aufgezeichneten Position. Liegt sie außerhalb des Rings, läuft er mit eigenem
  Tempo zum nächsten Ringpunkt (`RtGeo.project_walkable`) — höchstens `ENTER_MAX_TICKS` = 30, danach steht er dort — und
  handelt erst nach der Ankunft. Seine Komparsen erscheinen am Eintrittspunkt in Formation (Rauchwolke 0,5 s,
  `pop_in_until` = Ankunft + 15 Ticks, §3.5.5). Kein Springen, kein Aufploppen mitten im Raum.
- **Gruppenlose Kämpfe** (Etagen-Events wie `enc_f1_evt_pigeons`, Story-Kämpfe ohne Kartensymbol): Anker ist das Ende der
  Türgasse der Tür mit dem größten Abstand zur gesteuerten Figur (Gleichstand N, E, S, W); ohne offene Tür der Ringpunkt
  gegenüber der Figur. Von dort Auftritt und Formation wie oben.
- **Andere Räume:** Gegner-Akteure außerhalb der Set-Zelle werden für die Kampfdauer ausgeblendet (die Uhr steht, sie frieren
  ohnehin ein; Ausnahme: am Ring wartende Gruppen). Das hält das Draw-Call-Budget (§8.10).

### 2.4 Kampfzustand pro Raum, das Set

- Es läuft höchstens ein Kampf. Die Set-Zelle ist die Zelle der gesteuerten Figur beim Start (`FloorLayout.world_to_cell`).
- **Radius nach Raumart** (`RtGeo.set_radius(kind)`, Werte in `data/rt_balance.json`): `NORMAL`, `START`, `GATE`, `SAFE` →
  480 cm; `QUARTER_BOSS`, `FLOOR_BOSS` → 600 cm. Herleitung: Requisiten und Kollisionen halten heute einen Freiradius von 5,0 m
  (`EnvKit.CLEAR_RADIUS`, geprüft durch `test_m4_env`), Gleisgraben/Kanal beginnen erst bei 5,1 m bzw. 5,9 m, Türkorridore sind
  frei — der 4,8-m-Ring liegt also immer auf freiem, ebenem Boden. Bossräume (nur 2 Requisiten + Schreibtisch/Wrack an der
  Wand) halten künftig **6,2 m** frei (`EnvKit.CLEAR_RADIUS_BOSS`, R4 rückt Schreibtisch und Wrack an die Wand, `test_m4_env`
  prüft es), damit Bosskämpfe Platz haben.
- **Treppenraum** (`STAIRS`): Die Treppe belegt die Raummitte — dort gibt es kein Set. Gegner betreten den Treppenraum nicht (eine
  Verfolgung endet an seiner Tür mit RETURN), also beginnt dort kein Kampf.
- **Darstellung:** Beim Start leuchtet der Ring auf (0,3 s „Studio-Licht an“, Farbe `C_ACCENT_2` #22D3EE, eine `MeshInstance3D`
  mit Lücken an den Türen, 1 Draw Call, geprüft A13); bei Sieg oder Flucht blendet er in 0,5 s aus.
- **Kollisionsring:** ein `StaticBody3D` (Layer `world`) mit Box-Segmenten entlang des Rings, ausgenommen die Türgassen: Die
  gesteuerte Figur gleitet am Rand entlang (weiche Begrenzung, kein Wandgefühl). Er existiert nur während des Kampfes.
- Gegner-Einheiten bleiben immer im Ring; sie betreten keine Türgasse.
- Im Kampf sind **alle Interaktionen gesperrt** (Truhen, Hebel, Etagen-Events, Tore, Safe-Room-Tür); die Aktionstaste hat
  Kampfbedeutung (§7).
- Türen: bleiben offen bei regulären Kämpfen (Flucht möglich); schließen sich (sichtbar + Kollision) bei Bossen, im Tutorial und
  bei `EncounterDef.can_flee == false` („Die Tür ist zu — die Show muss weitergehen!“). Dann ist auch der Ring geschlossen
  (keine Lücken).
- Nach `VICTORY` ist das Set geräumt (besiegte Gruppen verschwinden wie bisher, `defeated_groups`).

### 2.5 Flucht, Rücksetzen

- **Flucht** = die gesteuerte Figur steht **60 aufeinanderfolgende Ticks (2,0 s)** außerhalb des Rings (in einer Türgasse oder
  dahinter). Ab Tick 15 außerhalb zeigt das HUD „Zurück ans Set! 2… 1…“ (`FLEE_WARNING`, M.O.D. `rt_flee_warn`). Der
  KI-Partner folgt automatisch, sobald die Figur den Ring verlässt.
- Die **Taschen-Nebelmaschine** (`itm_smoke`) löst die Flucht sofort aus (nicht bei geschlossenem Set).
- Ergebnis `FLED`: Hype −30 (`FLEE_RESULT`), Follower −1 % (bestehende Regeln), K.O.-Mitglieder → 1 HP, 2 s Schonfrist
  (`GRACE_SEC`). Die Gegner **setzen zurück**: volle HP, Status gelöscht, zurück an ihre Startpositionen, Erkundungs-Zustand
  `RETURN` (ignoriert die Figur 2 s). Die Raumgrenze ist die Leine.
- Geschlossenes Set (Boss, Tutorial, `can_flee == false`): Es gibt keine Lücken; eine Flucht gibt es nicht.

### 2.6 K.O., Wiederbelebung, Niederlage

- Eine Einheit mit 0 HP ist **K.O.**: liegt am Boden, wird nicht angegriffen, verliert alle Status, regeneriert nicht.
- **Steuerung folgt dem Leben:** Fällt die gesteuerte Einheit, wechselt die Steuerung sofort zur ersten lebenden,
  KI-gesteuerten Party-Einheit (Slot-Reihenfolge; nie zu einer Einheit, die ein anderer Mensch steuert, §10.8) —
  `CONTROL_CHANGED`, Banner „Kai ist K.O. — du spielst jetzt Graf Mopsula!“. Das ist **vorübergehend**: `GameState.hero`
  ändert sich nicht. Der `CombatDirector` (R2) tauscht in der Szene die Körperrollen (`ExplorationScene.control_temporarily
  (member_id)`, R2-Block in `exploration.gd`: der Spielerkörper wird zur lebenden Figur, die gefallene liegt als Puppe) und stellt
  beim Kampfende mit `ExplorationScene.refresh_hero()` (06 A) die Held:innen-Wahl wieder her. Lebt keine KI-Einheit mehr:
  Niederlage.
- **Wiederbelebung im Kampf:** Mopsula ab Stufe 7 (Slot 2 wird auf einem K.O.-Ziel automatisch zu „Sabber der Wiederkehr“,
  §4.3) oder Riechsalz (`itm_smelling_salts`). Wiederbelebte erhalten `sts_guard` für 3,0 s („Comeback“).
- Nach `VICTORY`/`FLED`: K.O.-Mitglieder stehen mit 1 HP auf (bestehende Regel `KO_REVIVE_HP`).
- **Niederlage** (alle Party-Einheiten K.O.): `DEFEAT` → bestehender Sendeschluss/Game-Over-Ablauf mit Neuladen (unverändert).
  Sterben Party und letzter Gegner im selben Tick, zählt es als **Sieg** („Doppel-K.O. — die Show liebt Drama“).
- Tutorial: Party-HP fallen nie unter 1 (bestehende Regel), Gegnerschaden × 0,5.

### 2.7 Regeneration außerhalb des Kampfes

- **Nur im Echtzeitmodus** (`GameState.combat_mode == &"realtime"`); CTB-Läufe bleiben bitgleich. Die Regel steht in `RunSim`
  und gilt damit identisch live, im Replay und im Verifier.
- Neuer Schritt 6 in `RunSim._tick_once` (nur Erkundungs-Ticks bei laufender Uhr): Der Zähler `floor_run.regen_ticks`
  (gespeichert, gehasht wenn ≠ 0) zählt die Ticks seit dem letzten Kampfende **oder** dem letzten Schaden außerhalb des Kampfes
  (Etagen-Events, Fallen setzen ihn auf 0). Alle `REGEN_PERIOD_TICKS` = 90 (3 s) erhält jedes Party-Mitglied mit HP > 0
  `max(1, div_round(max_mp × 20, 1000))` MP (2 %) und — erst wenn `regen_ticks ≥ REGEN_HP_DELAY_TICKS` = 150 (5 s ohne
  Schaden) — `max(1, div_round(max_hp × 5, 1000))` HP (0,5 %), gedeckelt auf das Maximum.
- Größenordnung: MP ≈ 40 %/min, HP ≈ 10 %/min. Zwischen zwei Kämpfen (≈ 45–60 s Weg) kommen ≈ 7–9 % HP zurück — genug für
  „2–3 Kämpfe zwischen zwei Safe Rooms ohne Tränke“ (GDD §13), zu wenig, um Heilung überflüssig zu machen. Geprüft im
  Etagenfolge-Gate (§11.4).
- Werbepause (+15 % Max-MP nach jedem Sieg, `POST_BATTLE_MP_REGEN`, plus Talent `post_battle_mp_pm`, 06 B) und Safe Rooms
  (Vollheilung) bleiben.

### 2.8 Kampfstart-Präsentation (ersetzt Swirl und Szenenwechsel)

| Zeit | Was passiert |
|---|---|
| 0,0 s | `ct = 0`: Sim läuft sofort. Der LED-Ring leuchtet auf, Broadcast-Stinger (0,4 s Weißblitz 15 %, „KAMPF!“-Bauchbinde 1,2 s), ShowOverlay-Modus `&"combat"`, Kampf-HUD blendet ein (0,25 s), Minimap und Erkundungshinweise blenden aus, Akteure anderer Räume werden ausgeblendet. Musik: Stinger; die Kampfmusik (`battle`, Überblendung 0,5 s) setzt erst ein, wenn der Kampf 5 s läuft — Bosse sofort (`boss`). |
| 0,0–1,0 s | Auftritt (Anführer laufen herein), Komparsen springen ins Bild (Rauchwolke), Kamera zoomt auf 8 m (Boss 9 m), §7.5. |
| ab 1,0 s | Erste Gegner-Angriffe (`FIRST_SWING_TICKS = 30`), bei `PREEMPTIVE` erst nach 3,0 s. |

`Router` ist nicht beteiligt (kein `start_battle`, kein Szenenstapel). `Events.battle_started` / `Events.battle_ended` feuern wie
bisher (gleiche Bedeutung für Show, Achievements, Musik).

### 2.9 Bosse: Intro im Bossraum

1. Auslöser: die gesteuerte Figur kommt 5 m an `boss_spot` (unverändert). Die Erkundung friert ein, Eingabe gesperrt.
2. Türen schließen (0,3 s, Ton „Rolltor“), der geschlossene 6-m-Ring leuchtet auf, Kamerafahrt „Boss-Kran“ 2,5 s (03_ART §8:
   `boss_intro`) **in der Welt**, Banner „BOSS: Der Hausmeister“ mit Titelzeile, blockierende M.O.D.-Zeile
   `boss_intro:<enemy_id>` (die einzige blockierende Zeile im Kampfkontext).
3. Danach `ct = 0` mit `NORMAL`. Während des Intros tickt die Sim **nicht** (es gibt noch keine `RtSim`; sie wird erst nach dem
   Intro erzeugt, und erst dann wird der `encounter`-Befehl aufgezeichnet). Die Erkundungsuhr steht während des Intros wie bei
   jedem blockierenden Dialog.
4. Nach dem Sieg: Abspann-Panel (§8.9), Türen öffnen, `Events.boss_defeated` wie bisher.

### 2.10 Etagen-Timer und Sponsor-Fenster im Kampf

- **Die Uhr steht** (Brief; GDD §2.9; 05 §6.13): Während eines Kampfes läuft `RunSim` nicht, weder Etagen-Timer noch
  Hype-Verfall, Streuner-Spawns, Twist-Laufzeiten oder Fenster-Uhr. Weil die Erkundungsszene im Kampf aktiv bleibt (anders als
  beim CTB-Szenenwechsel), liefert `Game.is_timer_ticking()` und `Game.is_idle_ticking()` `false`, solange `Game.in_battle`
  (R2, §12.9). Anzeige: Timer grau mit Zusatz „Uhr steht“ (§8.1).
- **Im Kampf öffnet kein Sponsor-Fenster.** Ein vor dem Kampf geöffnetes Fenster bleibt mit seiner Restzeit eingefroren und nimmt
  weiter Geschenke an (bestehende Regel). `Game.in_battle` ist für die ganze Kampfdauer `true`; `Show.receive_gift` reiht
  angenommene Geschenke deshalb wie heute ein, angewendet werden sie an der **nächsten Tick-Grenze** (§9.2): kurzer Banner 1,5 s
  (Sponsor-Bauchbinde, verkürzt), Drohnen-Effekt am Ziel, **keine** Pause.
- System-Geschenke (Hype-Schwellen 70/85/100, höchstens 1 pro regulärem Kampf / 2 pro Bosskampf) entstehen aus den Ereignissen
  eines Ticks und werden an der nächsten Tick-Grenze angewendet; je Grenze höchstens ein Geschenk (§9.2).
- Im Live-Modus `timer_mode: realtime` (05 S4) liefe die Lauf-Uhr auch im Kampf; dieses Dokument hängt nicht davon ab
  (§10.2: `k` würde dann mit `ct` mitlaufen).

### 2.11 Kampfende

- `VICTORY`: alle Gegner-Einheiten K.O. oder entkommen (`ESCAPED`, z. B. Fahrscheinfresser); die Sim setzt `result`.
- Reguläre Kämpfe: **nicht blockierende** Bilanz „Applaus!“ (3,0 s, §8.9) mit EXP, Credits, Funden; Stufenaufstiege als Banner,
  bei einer neuen Talentwahl der Chip „TALENT BEREIT · im Safe Room wählen“ (06 B). Gewählt wird nie nach dem Kampf, sondern nur
  in der Talent-Show im Safe Room (06 §2.2).
- Bosskämpfe: Abspann-Panel (pausiert, wie das bisherige Ergebnisbild), danach Türen auf.
- Danach unverändert: `Game.end_combat()` → `Game.apply_battle_result` (BattleBridge, §12.7) → `Show.end_battle` →
  `Events.battle_ended`. Die Sim-Instanz wird verworfen; Komparsen-Rigs bleiben unsichtbar im Pool (§8.10), ausgeblendete
  Akteure werden wieder sichtbar.

### 2.12 Ablaufbeispiel (Zone A, Stufe 2, Held:in Kai)

1. Kai schleicht von hinten an eine patrouillierende Gruppe (Kanalratte, Taubenschwarm, Kanalratte), wählt die Ratte (Tab) und
   drückt `1` → Pull, `PREEMPTIVE`, `ct = 0`. Der Anführer steht bei (4 m, 4 m) außerhalb des Rings und läuft herein; die
   Komparsen erscheinen am Eintrittspunkt; alle Gegner sind 3 s überrumpelt. Wuchtschlag startet (2 MP, GCD 1,5 s).
2. `ct = 9`: Wuchtschlag trifft (≈ 22 Schaden, + 15 % mit „Erster Eindruck“; Kanalratte 168 → 146). Auto-Angriff läuft seitdem
   alle 2,0 s; jeder Auto-Treffer und jeder erlittene Biss bringt Kai 1 MP.
3. Graf Mopsula (KI, „Unterstützen“) niest Kais Ziel mit Frostniesen an und zaubert danach Adelsflamme (1,5 s).
4. `ct ≈ 190`: Der Taubenschwarm kündigt „Sturzflug“ an — roter Kreis unter Mopsula, 1,2 s. Mopsula weicht nach 12 Ticks aus.
   Ein Treffer hätte sie 15 % ihrer Max-HP gekostet. Kai drückt `R` (Partner-Spezial): Mopsula schlabbert ihn sofort heil.
5. Ratten fallen, die Tauben zuletzt; nach ≈ 16 s `VICTORY`, der Ring blendet aus, „Applaus!“-Bauchbinde, weiter geht's.

### 2.13 Einstieg: Tutorial-Kampf und Erst-Hinweise

Ziel: Niemand muss vor dem ersten Kampf etwas lesen; jede Regel kommt in dem Moment, in dem sie gebraucht wird (06 L-1/L-2).

- **Tutorial-Begegnung** `enc_f1_a1_tutorial` (Echtzeit-Fassung über `floors.json → encounters[].rt`): zwei Azubi-Kanalratten
  (`enm_kanalratte_azubi`, je 280 HP — mehr als eine normale Ratte, damit alle Schritte Platz haben), Gruppe schläft (§2.2,
  immer `PREEMPTIVE`), Set geschlossen, Gegnerschaden × 0,5, Party-HP ≥ 1.
- **Vier Schritte** (`floors.json → encounters[].rt.tutorial` = `["target", "bar1", "show", "dodge"]`), jeweils als Hinweiskarte
  (Untertitel-Box mit Bild der Taste/Geste, M.O.D.-Zeile `rt_tutorial_<schritt>`):
  1. `target` bei `ct = 0`: „Wähle ein Ziel — antippen oder Tab.“ Weiter, sobald ein `target_change` angenommen ist.
  2. `bar1`: „Drück 1 (Touch: der große Knopf).“ Weiter mit dem ersten angenommenen `ability_use` aus Slot 1.
  3. `show` nach dem ersten Party-Treffer: „SHOW: riskant, aber das Publikum liebt es.“ Weiter mit SHOW oder „Später“.
  4. `dodge` beim ersten `TELEGRAPH_START` (Azubi-Sprung, Warnzeit 2,0 s): „Rote Fläche? Raus da!“ Weiter mit einer beliebigen
     Eingabe; die volle Warnzeit bleibt danach erhalten.
- **Pause ohne Determinismus-Risiko:** Während eine Karte steht, ruft der `CombatDirector` kein `combat_step()` auf — es vergeht
  kein Tick, die Sim ändert sich nicht. Eingaben in dieser Zeit tragen den angehaltenen `ct`. Jede gezeigte Karte wird als
  `{"t": "combat_hint", "ct", "id"}` aufgezeichnet (§10.1); `RunSim` und `GameReplay` setzen damit
  `GameState.flags["rt_hints"][id] = true`, die Sim ignoriert den Befehl. So sehen Live-Zuschauer:innen und Replays die Karte am
  selben `ct`, und „schon gezeigt“ übersteht Speichern/Laden.
- **Unterbrechen** wird nicht im Tutorial gelehrt (auf Stufe 1 hat niemand einen Unterbrecher), sondern als **Kontext-Hinweis**:
  beim ersten `interrupt_worthy`-Zauber eines Gegners, sobald die gesteuerte Figur einen Unterbrecher gelernt hat (Stufe 3, Zone B:
  Rattenschamane): „Goldener Rand = jetzt unterbrechen! Drück 3.“ (`rt_hint_interrupt`).
- **Weitere Erst-Hinweise** (je einmal je Spielstand, höchstens eine Karte je Kampf, gleiche Pausen-Mechanik): `zone` (erste
  Pfütze), `partner_special` (erster Kampf mit verfügbarem Partner-Spezial), `finale` (FINALE erstmals nutzbar), `flee` (erstmals
  den Ring verlassen), `enrage` (erstes Enrage).
- Einstellung „Kampf-Hinweise“ (`GameSettings.combat_hints`, Standard an): aus → keine Karten, keine Pausen, keine
  `combat_hint`-Befehle. Event-/Liga-Läufe zeigen keine Karten (Regel `rules.combat.hints`, Standard `false` in Ligen).

---

## 3. Simulation (Kern)

### 3.1 Modul, Schichten, Dateien

Neues Kern-Modul **RT** unter `core/rt/` (Eigentum R1, §12.3). Alle Klassen `extends RefCounted` (bzw. erben von M1-Klassen),
keine Nodes, keine Autoloads, kein `await`, keine Uhr, kein globaler Zufall (02_TECH §0.4, Lint §3.14).

```
core/data ← core/stats ← core/battle (M1) ← core/rt (RT) ← core/live (M8: RunSim, StateHash, Command)
core/progression (M2: BattleBridge.make_rt_setup) → core/rt   (BattleBridge baut RtSetup; core/rt kennt BattleBridge nicht)
scenes/combat (R2/R3), autoload/game.gd, autoload/show.gd → core/rt   (nie umgekehrt)
core/data/validators/rt.gd, rt_vocab.gd (R1a) ← DataValidator (eine Hook-Zeile), RtCommand, RtMods (Vokabulare)
```

| Datei | `class_name` | Zweck |
|---|---|---|
| `core/rt/rt_sim.gd` | `RtSim` | Ein Kampf: Befehle annehmen, Ticks rechnen, Ereignisse liefern, Ergebnis (§3.4) |
| `core/rt/rt_setup.gd` | `RtSetup` (extends `BattleSetup`) | Startdaten eines Kampfes |
| `core/rt/rt_unit.gd` | `RtUnit` (extends `Combatant`) | Einheit mit Position, Timern, Zauber, Bedrohung |
| `core/rt/rt_status.gd` | `RtStatus` (extends `StatusEffect`) | Status mit Tick-Ende, Periode, Stapeln, eingefrorenem Tick-Betrag |
| `core/rt/rt_telegraph.gd` | `RtTelegraph` | Telegraph oder Zone (Form, Anker, Zeiten) |
| `core/rt/rt_rules.gd` | `RtRules` | Regel-Engine für Gegner-KI, Partner-KI, Autopilot, Assist (§5.3, §6.2) — reine Auswahlfunktionen |
| `core/rt/rt_command.gd` | `RtCommand` | Schema-Prüfung und Bauhelfer der Kampfbefehle (§10.1) |
| `core/rt/rt_geo.gd` | `RtGeo` | Set-Geometrie (Ring, Türgassen, Sperrflächen), Sichtlinie, Formen-Test, Formation, Auftritt-Anker, Ausweichpunkte |
| `core/rt/det_math.gd` | `DetMath` | Ganzzahl-Trigonometrie (Tabellen), `isqrt`, Gier-Winkel (u8) |
| `core/rt/rt_balance.gd` | `RtBalance` | typisierte Stellwerte: Schlüssel, Typen, Bereiche, Startwerte (R1); die Werte selbst stehen in `data/rt_balance.json` (Eigentum R4, §3.16) |
| `core/rt/rt_mods.gd` | `RtMods` | statische Modifikatoren aus Spezies, Spezialisierung, Ausrüstung, Show-Boss und Kampf-Twists (§9.5); Talente wirken über `talent_mods` (§9.6) |
| `core/rt/rt_ability.gd` | — (privat) | Fähigkeiten/Gegenstände: Prüfung, Kosten, Zauber, Kanal, Wirkung, Partner-Spezial |
| `core/rt/rt_damage.gd` | — (privat) | Echtzeit-Faktoren um `DamageCalc` herum (Faltung §3.9.1), Prozent-Treffer, Eröffnungsbonus |
| `core/rt/rt_threat.gd` | — (privat) | Bedrohungslisten, Spott, Zielwechsel |
| `core/rt/rt_movement.gd` | — (privat) | Positionsproben, Plausibilitätsgrenzen, Koppelnavigation, Lenkung, Abstoßung, Auftritt |
| `core/rt/rt_result.gd` | — (privat) | `BattleResult`-Bilanz, Beute-Würfe |
| `core/data/validators/rt_vocab.gd` | `RtVocab` | alle Echtzeit-Vokabulare (§4.10) und die Symbol-Ids (§8.2) als Konstanten — eine Quelle für Validator, `RtCommand`, `RtMods`, HUD |
| `core/data/validators/rt.gd` | — (preload in `DataValidator`) | Validator-Regeln der `rt`-Blöcke und von `rt_balance.json` (§4.10) |

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
oder `posmod` — alle Rundungen sind explizit. `FixedMath` ist ein privater Helfer (`const FixedMath :=
preload("res://core/stats/fixed_math.gd")`, 02_TECH §0.3).

### 3.3 Tick-Ablauf (exakte Reihenfolge)

`RtSim.step()` rechnet den Tick `c = tick()` und erhöht danach `tick()` um 1. Vor jedem `step()` liegt die **Tick-Grenze**
(§9.2: höchstens ein Geschenk). Einheiten-Reihenfolge überall: Party nach Slot (`p0`, `p1`, …), dann Gegner nach Nummer (`e0`,
`e1`, …, Beschwörungen zählen weiter, Nummern werden nie wiederverwendet). Innerhalb einer Liste gilt die Erzeugungsreihenfolge
(Telegraphen, Zonen, ausstehende Treffer, Status).

| Schritt | Inhalt | Ereignisse |
|---|---|---|
| 1a Spielerpositionen | Für jede `PLAYER`-Einheit: Position des Ticks `pos(c)` = Probe mit `ct == c` (geprüft nach §3.5.2), sonst Koppelnavigation aus der letzten Probe (§3.5.1). Diese Position gilt für **alle** weiteren Schritte von `c`. | `POS_CORRECTED` |
| 1b Befehle | Alle übrigen mit `submit()` für `ct == c` eingereihten Befehle in Aufzeichnungsreihenfolge anwenden: `target_change`, `auto_attack`, `autopilot`, `partner_preset`, `partner_special` (puffert), `ability_use`, `combat_item`. Dynamische Prüfungen (GCD, MP, Reichweite, Abklingzeit, Trinkpause) erst hier; abgelehnte Befehle erzeugen `ACTION_REFUSED`. Geschenke wurden schon an der Tick-Grenze angewendet. | `ACTION_REFUSED`, `TARGET_CHANGED`, `PRESET_CHANGED`, `ACTION_START`, `CAST_START` |
| 2 Status-Ticks | Für jede Einheit, jeden Status (Anwendungsreihenfolge): periodische Wirkung, wenn `next_tick_at == c` (danach `next_tick_at += period`); dann Ablauf, wenn `ends_at == c`. Fällt ein Takt auf `ends_at`, wirkt er vor dem Ablauf. | `DAMAGE`/`HEAL` (mit `status_id`), `STATUS_REMOVED`, `KO` |
| 3 Zonen | Für jede Zone: periodische Wirkung auf gegnerische Einheiten in der Fläche (und im Ring), wenn fällig; Ende, wenn `ends_at == c`. | `DAMAGE`, `STATUS_ADDED`, `ZONE_END` |
| 4 Telegraph-Einschläge | Für jeden Telegraphen mit `impact_at == c`: Treffermenge bestimmen (§6.3), Wirkung je Einheit, Ausweicher melden, ggf. Zone erzeugen. | `TELEGRAPH_IMPACT`, `TELEGRAPH_DODGED`, `DAMAGE`, `ZONE_START`, `KO` |
| 5 Ausstehende Treffer | Sofort-Fähigkeiten, Auto-Angriffe, Gegenstände mit `at == c`. Jede Sofortwirkung liegt mindestens 1 Tick nach ihrem Start (§3.6.7) — auch Aktionen, die in Schritt 7 beginnen, wirken also sicher in einem späteren Schritt 5. Verfällt, wenn der Verursacher K.O. ist. | `DAMAGE`, `HEAL`, `STATUS_*`, `COMBO`, `KO`, `REVIVE` |
| 6 Zauber-/Kanalende | Für jede Einheit mit `cast.end == c`: Wirkung (Nicht-Telegraph-Zauber, Gegenstände nach der Trinkpause); Kanal-Ticks, wenn fällig. | `DAMAGE`, `HEAL`, `STATUS_*`, `ACTION_END` |
| 7 Warteschlange + KI | Für jede Einheit: zuerst gepufferte Fähigkeit (Queue) starten, wenn GCD/Zauber frei; dann ein gepuffertes Partner-Spezial (§3.6.13); dann KI für sim-gesteuerte Einheiten (Gegner, KI-Partner, Autopilot) über `RtRules` (§5.3, §6.2): Fähigkeit starten oder Bewegungsziel setzen. | `ACTION_START`, `CAST_START`, `TELEGRAPH_START`, `TARGET_CHANGED` |
| 8 Auto-Angriffe | Für jede Einheit: wenn Auto an, Ziel feindlich und lebend, in Reichweite, nicht zaubernd/trinkend/betäubt/überrumpelt und `swing_ready <= c` → Treffer bei `c + 9` einreihen, `swing_ready = c + swing_ticks`. | `SWING` |
| 9 Bewegung | Nur sim-gesteuerte Einheiten (Gegner, KI-Partner, Autopilot): Auftritt, Lenkung, Abstoßung, Klemmen auf die begehbare Fläche (§3.5.3). Danach merkt sich jeder aktive Telegraph, welche Einheiten jetzt darin stehen (`inside_last`). Flucht-Zähler der gesteuerten Einheit. | `POS_CORRECTED`, `FLEE_WARNING` |
| 10 Phasen, Enrage, Ende | Boss-Schwellen (`PHASE_CHANGE` + `on_enter`), Enrage-Zeiten, Kampfende prüfen: alle Gegner K.O./entkommen → `VICTORY` (auch wenn die Party im selben Tick fiel), alle Party K.O. → `DEFEAT`, Flucht → `FLED`, `ct ≥ MAX_COMBAT_TICKS` → `FLED` („Sendezeit überzogen!“). | `PHASE_CHANGE`, `MOD_LINE`, `ENRAGE`, `SUMMON`, `BATTLE_END` |
| 11 Takt | MP-Regeneration über Zeit (§3.10; Kais Treffer-MP werden sofort beim Treffer gutgeschrieben), alle 30 Ticks `SECOND` (Wert = volle Kampfsekunden). | `MP_CHANGE`, `SECOND` |

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
var room_kind: int = 0                      # RoomCell.Kind
var geo: Dictionary = {}                    # RtGeo: {"r": int cm, "doors": int (N 1, E 2, S 4, W 8), "closed": bool, "blockers": [[x0, z0, x1, z1], …]}
var units: Array[RtUnit] = []               # party (slot order), then enemies (group order, formation order)
var groups: Array[Dictionary] = []          # [{"group_id", "encounter_id", "enemy_ids": PackedStringArray, "lead": [x, z, yaw], "state": String, "entry": [x, z]}]
var controlled_id: String = "p0"            # unit id of GameState.hero (§5.1)
var presets: Dictionary = {}                # unit id → {"preset": "attack"|"support"|"careful", "tog": {"interrupt": bool, "show": bool, "potions": bool}}
var auto_attack: bool = true                # initial auto-attack switch of the controlled unit (GameSettings.auto_attack_default)
var auto_retarget: bool = true              # pick the next target when the current one falls (GameSettings.auto_retarget)
var opener: Dictionary = {}                 # {} | {"kind": "strike", "target": "e0"} | {"kind": "skill", "u": "p0", "skill": id, "target": "e0"} | {"kind": "item", "u", "item", "target"}
var mods: Array[Dictionary] = []            # RtMods entries (§9.5), canonical, static for the whole combat
var rules: Dictionary = {}                  # combat-relevant run rules (§10.7), canonical
var difficulty: StringName = &"prime"       # &"vorabend": telegraph warn times × balance.easy_warn_pm
var tutorial_steps: PackedStringArray = []  # §2.13; presentation only (the sim never reads it), part of to_dict()
var balance: RtBalance = null               # data/rt_balance.json (§3.16); pinned by the data hash, not serialized

func to_dict() -> Dictionary                 # canonical (BattleSetup.to_dict() + the fields above; units as snapshots)
```

```gdscript
class_name RtUnit extends Combatant
## A combatant with position, timers, cast, threat. Ids, stats, hp/mp, statuses (RtStatus), element mods, rewards and
## talent_mods (06 B): inherited from Combatant (02_TECH §5.4). max_hp() is already scaled (§3.9.4).
enum Driver { PLAYER, AI, AUTOPILOT }      # not "Control": would shadow the global Control class
var driver: RtUnit.Driver = Driver.AI
var x: int = 0                              # cm, room-local
var z: int = 0
var yaw: int = 0                            # 0..255
var radius: int = 40                        # cm
var move_cm_tick: int = 18                  # base speed (data cm/s / 30)
var stationary: bool = false
var keep_cm: int = 0                        # ranged: preferred distance to the target (0 = melee), ≤ 700
var follow_cm: int = 0                      # AI partner: max distance to the controlled unit while idle
var sample: Array[int] = []                 # PLAYER: last accepted move sample [ct, x, z, vx, vz, yaw] (vx/vz mm per tick)
var move_budget: int = 600                  # PLAYER: tolerance budget in mm (§3.5.2)
var goal: Array[int] = []                   # sim-driven: [x, z] movement goal of this tick ([] = stand)
var entry: Array[int] = []                  # enemies: [x, z] Auftritt goal ([] = inside); no actions before arrival
var target_id: String = ""
var auto_on: bool = true
var auto_skill: String = ""                 # auto-attack skill id ("" = none)
var auto_ranged_skill: String = ""          # fallback auto-attack when the target is out of reach (§6.2)
var swing_ticks: int = 60
var reach: int = 250                        # auto-attack reach in cm
var swing_ready: int = 0                    # ct of the next possible swing
var gcd_until: int = 0
var gcd_len: int = 0                        # ticks of the running GCD (gcd_total)
var cast: Dictionary = {}                   # {} | {"skill", "target", "x", "z", "start", "end", "interruptible": bool, "worthy": bool, "moving_cancels": bool, "channel": bool, "next_tick": int, "tele": int, "kind": "ability"|"item", "item": String}
var queued: Dictionary = {}                 # {} | {"skill"|"item", "target", "at": ct of the press}
var partner_order: Dictionary = {}          # {} | {"skill", "until": ct}: buffered Partner-Spezial (§3.6.13)
var cooldowns: Dictionary = {}              # skill id → [ct ready again, cooldown length]
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
var mp_regen: Dictionary = {}               # {"mode": "hit"|"time", "amount", "taken", "taken_every_ticks", "every_ticks"}
var mp_regen_next: int = 0
var mp_hit_ready: int = 0                   # "hit" mode: ct from which a taken hit gives MP again
var threat_pm: int = 1000                   # unit threat multiplier (Kai 1500)
var dmg_pm: int = 1000                      # enemies: RT damage knob for formula hits (EnemyDef.rt.dmg_pm)
var ko_at: int = -1
var outside_since: int = -1                 # controlled unit: first ct outside the ring (flight), -1 inside
var pop_in_until: int = 0                   # formation members: no actions before this ct
var phase_perfect: bool = true              # bosses: no telegraph hit on the party during the current phase
var opener_done: bool = false               # party: first damaging hit of the combat already dealt (opener bonus, §9.6)
var bar: Dictionary = {}                    # party: slot (1..5) → skill id (current loadout, level-filtered)

func snapshot() -> Dictionary               # canonical, all fields above + Combatant.to_dict()
```

```gdscript
class_name RtStatus extends StatusEffect
## Real-time status: ends at a tick, optional period, stacks. turns_left/fresh (CTB) stay 0/false.
var ends_at: int = -1                       # ct of expiry (-1 = until combat end)
var period: int = 0                         # ticks between periodic effects (0 = none)
var next_tick_at: int = -1                  # phase is kept on refresh (§3.8)
var stacks: int = 1
var applied_at: int = 0
var amount: int = 0                         # tick_power statuses: damage per tick and stack, frozen at application (§3.8)
func to_dict() -> Dictionary                # {"id", "source_id", "ends_at", "period", "next_tick_at", "stacks", "applied_at", "amount"}
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
func contains(px: int, pz: int) -> bool     # DetMath shape test, center point only ("Fußpunkt-Regel"), and inside the ring
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
func run_to_end(max_ticks: int) -> Array[ActionEvent]   # headless: step until finished or max_ticks (RunSim, harness)
func snapshot() -> Dictionary               # canonical, complete (StateHash.of_rt, §10.4)
# --- pure queries: no RNG draw, no state change, no events (test_r1_rt_pure) -----------------------------------------
func can_use(unit_id: String, skill_id: String, target_id: String) -> String   # "" or refusal reason (HUD states)
func can_use_item(unit_id: String, item_id: String, target_id: String) -> String
func suggest(unit_id: String) -> String     # Assist (§5.6): skill id of the next suggested ability or ""
func bar(unit_id: String) -> Dictionary     # slot (1..6) → skill/item id shown right now (FINALE, context variants, potion pick)
func partner_special_skill(unit_id: String) -> String   # skill the Partner-Spezial would order now ("" = none)
func cooldown_left(unit_id: String, skill_id: String) -> int     # ticks (SHOW/FINALE: party-shared "show" cooldown)
func cooldown_total(unit_id: String, skill_id: String) -> int    # length of the running cooldown in ticks (0 = none)
func gcd_left(unit_id: String) -> int
func gcd_total(unit_id: String) -> int
func cast_progress(unit_id: String) -> Vector2i                  # (elapsed, total) ticks; (0, 0) = no cast
func item_cd_left() -> int                                       # party-shared consumable cooldown (§3.11)
func item_cd_total() -> int
func items_left() -> int                                         # consumables still allowed in this combat (0..3)
```

Ablehnungsgründe (`submit` und `ACTION_REFUSED.text`, feste Liste `RtCommand.REASONS`): `schema`, `past_tick`, `finished`,
`unknown_unit`, `not_controlled`, `dead`, `not_learned`, `stunned`, `casting`, `drinking`, `gcd`, `cooldown`, `mp`, `range`,
`los`, `target`, `target_hp` (FINALE: Ziel nicht unter 30 %), `item_cd`, `items_max`, `no_item`, `forbidden`, `locked`,
`not_available` (Partner-Spezial ohne Fähigkeit), `grade_b` (`move_input` ist reserviert, §10.1).

**Zwei Prüfstufen:** `submit()` prüft nur Schema und statische Bedingungen (vor dem Tick); alles Dynamische (GCD, MP, Reichweite,
Abklingzeit, Ziel lebt, Trinkpause) prüft Schritt 1 des Ticks. Dadurch ist die Annahme eines Befehls unabhängig davon, ob noch
andere Befehle im selben Tick folgen, und das Replay entscheidet identisch. Aufgezeichnet wird jeder von `submit()` angenommene
Befehl (§10.2).

**Reinheit:** `can_use`, `can_use_item`, `suggest`, `bar`, `partner_special_skill` und alle Getter ändern nichts — kein Wurf
(zufällige Ziele wie `random_enemy` werden nur auf „es gibt einen gültigen“ geprüft), kein Schreibzugriff (auch kein
`target_id`, `rng_n`, Cache), keine Ereignisse. `test_r1_rt_pure`: 1 000 Aufrufe aller Abfragen in einem laufenden Kampf lassen
`StateHash.of_rt` unverändert, und ein Lauf mit Abfragen nach jedem Tick hat denselben End-Hash wie ohne.

**Phasenübergreifende Signaturen** (R1a legt sie als Stubs an, §12.2): `RtCommand.ability(ct, u, skill, target)`, `.target(ct,
u, target)`, `.move(ct, u, x, z, vx, vz, yaw)`, `.item(ct, u, item, target)`, `.preset(ct, u, preset, tog)`, `.auto_attack(ct,
u, on)`, `.autopilot(ct, u, on)`, `.partner_special(ct, u)`, `.hint(ct, id)` (alle `-> Dictionary`), `RtCommand.validate(d) ->
String`; `RtGeo.set_radius(room_kind: int, bal: RtBalance) -> int`, `.make_geo(cell_kind: int, doors: int, closed: bool, bal:
RtBalance) -> Dictionary`, `.in_set(geo, x, z) -> bool`, `.walkable(geo, x, z, r, party: bool) -> bool`,
`.project_walkable(geo, x, z, r, party: bool) -> Vector2i`, `.los(geo, ax, az, bx, bz) -> bool`, `.formation(slot: int, ax: int,
az: int, yaw: int) -> Vector2i`, `.group_anchor(geo, cx: int, cz: int) -> Vector2i`, `.escape_point(sim: RtSim, u: RtUnit) ->
Vector2i`; `RtRules.compile(rules: Array, key_prefix: String) -> Array[Dictionary]`, `.choose(sim: RtSim, u: RtUnit) ->
Dictionary` (rein: `{}` oder `{"skill"|"item", "target", "goal"}`), `.eval_cond(sim: RtSim, u: RtUnit, cond: Dictionary,
target_id: String) -> bool`; `RtBalance.from_data(data: GameData) -> RtBalance`; `RtMods.validate`, `.apply_static`, `.on_event`,
`.from_twists(state: GameState, data: GameData) -> Array[Dictionary]`, `.from_show_boss(enc: EncounterDef) -> Array[Dictionary]`
(§9.5).

### 3.5 Bewegung und Positionen

#### 3.5.1 Spielerbewegung: Positionsproben (Grad A)

**Entscheidung:** Die gesteuerte Figur bewegt sich wie bisher mit `CharacterBody3D.move_and_slide` in der Szene (Physik, Wände,
Kollisionsring des Sets). Die Sim erhält ihre Position als **aufgezeichnete Proben** `move_sample` und rechnet zwischen zwei Proben
mit Koppelnavigation (Dead Reckoning) in geschlossener Form:

```
pos(c) = (s.x + div_round(s.vx * n, 10),  s.z + div_round(s.vz * n, 10))   mit n = min(c − s.ct, DR_MAX_TICKS)   # mm/Tick → cm
```

Nach `DR_MAX_TICKS` = 30 ohne neue Probe steht die Einheit (kein endloses Weiterrutschen bei verlorenen Proben). Das ist
**Grad A** im Sinne von 05 §3.3: Die Bewegung rechnet der Client, die Sim prüft sie auf Plausibilität (§3.5.2). Begründung:
(1) Physik/Jolt ist plattformübergreifend nicht deterministisch (05 §3.3; nicht prüfbar, also nicht verwenden), (2) direkte,
verzögerungsfreie Steuerung auf Mobilgeräten, (3) Replay und späterer Server sehen exakt dieselben Positionen wie die Sim, (4)
bewährtes MMO-Muster. Gegner und KI-Partner bewegt ausschließlich die Sim. **Grad B** (die Sim rechnet auch die Spielerbewegung
aus Eingaben) ist mit dem Befehl `move_input` reserviert (§10.1) und wird im Kampf einfach, weil das Set requisitenfrei ist (Kreis
+ Türgassen, §3.5.4).

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

#### 3.5.2 Prüfung der Proben (Plausibilitätsgrenzen)

Für jede Probe `s` einer `PLAYER`-Einheit `u` mit vorheriger angenommener Probe `p` (`Δ = s.ct − p.ct` Ticks):

```
step_max  = div_ceil(PLAYER_RUN_CM_S × move_pm(u) × Δ, 30 × 1000)          # cm, die ein Läufer in Δ Ticks schafft
d         = DetMath.isqrt((s.x − p.x)² + (s.z − p.z)²)                       # cm
u.move_budget = min(MOVE_BUDGET_MM, u.move_budget + Δ × MOVE_REFILL_MM_TICK) # füllt 3 mm je Tick nach, höchstens 600 mm
excess_mm = max(0, d − step_max) × 10
excess_mm ≤ u.move_budget → angenommen, u.move_budget −= excess_mm
sonst                      → Position auf der Strecke p → s auf step_max + u.move_budget / 10 gekürzt, u.move_budget = 0,
                             POS_CORRECTED
```

- Dauertempo höchstens Lauftempo (`PLAYER_RUN_CM_S` = 550, `move_pm` aus Status/Mods) plus 9 cm/s Nachfüllung; ein einmaliger
  „Sprung“ höchstens 60 cm. Teleport-Ausweichen (früher bis ≈ 19 m/s möglich) ist damit ausgeschlossen. Ehrliche Läufe stoßen nie
  an die Grenze (Physik-Rundung, Kollisionsgleiten: < 5 cm; Prüftest `test_r2_move_sampler`).
- Geschwindigkeitsfelder `|vx|, |vz|` über `max_v = ceil(PLAYER_RUN_CM_S × 10 / 30 × move_pm / 1000 × SPEED_TOLERANCE_PM / 1000)`
  (`SPEED_TOLERANCE_PM = 1250`) werden auf `max_v` gekürzt (sie wirken nur auf die Koppelnavigation).
- Ort: im Set gilt `RtGeo.walkable(geo, x, z, r, party = true)` (Ring + offene Türgassen, Sperrflächen ausgenommen, §3.5.4);
  außerhalb der Set-Zelle (Flucht) gelten nur die Tempo- und Verschiebungsgrenzen. Unzulässige Punkte → nächster zulässiger
  Punkt (`RtGeo.project_walkable`), `POS_CORRECTED`.
- Betäubt, Trinkpause (`no_move`) oder K.O.: Proben mit Bewegung werden auf die Haltposition gesetzt (die Szene hält die Figur
  in dieser Zeit ohnehin an, §3.11).
- Verletzung → Ereignis `POS_CORRECTED` (`target_id`, `rt.x`, `rt.z`); die Szene setzt die Figur im selben Frame dorthin
  (`player.teleport`, bei ≤ 60 cm als 0,1-s-Gleiten). Im ehrlichen Einzelspieler-Lauf tritt das nur bei Fehlern auf.
- Der Liga-Verifier zählt Korrekturen (§10.7); Ligen und gewertete Bestenlisten mit Echtzeitkampf bleiben bis Grad B
  „plausibilitätsgeprüft“ (05 §3.3).

#### 3.5.3 Sim-gesteuerte Bewegung (Gegner, KI-Partner, Autopilot)

- Tempo pro Tick: `move_cm_tick × move_pm / 1000` (Status: Verlangsamt 600, Turbo 1200, Überrumpelt 500; Mods).
- Ziel (`goal`), gesetzt von der KI in Schritt 7: Nahkampf → Punkt auf der Verbindungslinie im Abstand `reach + r_ziel −
  MELEE_STOP_CM (30)`; Fernkampf (`keep_cm > 0`) → näher heran, wenn Abstand > `keep_cm + 200`, zurück, wenn < `keep_cm − 200`
  (am Ring: so weit es geht); Ausweichen → `RtGeo.escape_point` (§5.5); Folgen → bis `follow_cm` an die gesteuerte Figur; sonst
  stehen.
- **Auftritt:** Gegner mit `entry` laufen zuerst dorthin (gleiche Lenkung, Abstoßung aus), handeln nicht und werden nicht von
  Flächen der Party getroffen (Show: „noch hinter der Kamera“); bei Ankunft oder nach `ENTER_MAX_TICKS` = 30 wird `entry`
  geleert.
- Schritt: geradlinig Richtung `RtGeo.project_walkable(goal)`, Länge `min(tempo, Abstand)`, Komponenten per
  `div_round(d × tempo, abstand)`.
- Abstoßung (nur Gegner untereinander): für jedes Paar `i < j` mit Abstand `< r_i + r_j` beide um die halbe Überlappung entlang
  der Verbindung auseinander; bei identischer Position `i` nach −x, `j` nach +x. Danach erneut klemmen. Party und Gegner
  blockieren sich **nicht** (kein Body-Blocking; die Spielerphysik kollidiert nur mit `world`, Maske 1).
- Gegner betreten nie eine Türgasse (`walkable(…, party = false)`); KI-Partner nur, wenn sie der fliehenden gesteuerten Figur
  folgen.
- Ausrichtung: beim Angreifen/Zaubern zum Ziel (`DetMath.yaw_of`), sonst in Laufrichtung.
- Weil Spieler das Set nur durch eine Türgasse verlassen können (und dort nach 2 s fliehen), gibt es keine unerreichbaren Positionen
  mehr; die frühere Unerreichbar-Regel (`skl_e_throw`) entfällt.

#### 3.5.4 Set-Geometrie, Sichtlinie

```
geo.r                         = RtGeo.set_radius(room_kind): 480 (NORMAL, START, GATE, SAFE) | 600 (QUARTER_BOSS, FLOOR_BOSS)
in_set(p)                     = |p| ≤ geo.r                                          # Telegraph-Wirkung und -Darstellung
walkable(p, r_u, party=false) = |p| ≤ geo.r − r_u  ∧  p liegt nicht in einer um r_u vergrößerten Sperrfläche
walkable(p, r_u, party=true)  = walkable(p, r_u, false)  ∨  in_gap(p, r_u)
in_gap(p, r_u)                = ¬geo.closed ∧ ∃ Tür d in geo.doors: |quer_d(p)| ≤ DOOR_HALF_CM (200) − r_u
                                ∧ geo.r − r_u < längs_d(p) ≤ CELL_HALF_CM (800)
```

`längs_d` misst von der Raummitte in Richtung der Tür (Tür bei 750, Zellrand bei 800), `quer_d` quer dazu. Grundlage sind die
geprüften Raumbau-Regeln (§2.4): Requisiten und Kollisionen ab 5,0 m (Bossräume künftig 6,2 m), Türkorridore frei, Gleisgraben
ab 5,1 m, Kanal ab 5,9 m — der Ring liegt immer auf freiem, ebenem Boden. Der Treppenraum hat kein Set.

- **Sperrflächen** (`geo.blockers`, achsparallele Rechtecke in cm) kommen aus festen Aufbauten im Set. Auf Etage 1 gibt es genau
  eine: den entgleisten Waggon der Rattenkönigin `[-160, -80, 160, 80]` (§6.7); niemand läuft hindurch, die Königin steht in
  P1/P2 darauf (ihr Mittelpunkt liegt in der Fläche, `stationary`). Sperrflächen sind niedrig und blockieren keine Sichtlinie.
- `RtGeo.project_walkable(geo, x, z, r, party)` liefert den nächstgelegenen begehbaren Punkt (Kandidaten: Kreisprojektion,
  Rechteck-Projektion je Türgasse, Rand je Sperrfläche; kleinster Abstand, Gleichstand in Reihenfolge Kreis, N, E, S, W,
  Sperrflächen in Listenreihenfolge).
- `RtGeo.los(geo, a, b)` ist im Set immer `true`; für Punkte außerhalb (Flucht) gilt die gemeinsame Türöffnung wie zuvor.
- **Telegraphen wirken nur im Ring:** `RtTelegraph.contains` verlangt zusätzlich `in_set(p)`; eine Figur in der Türgasse wird
  nicht getroffen (sie flieht aber nach 2 s). Die Darstellung beschneidet die Flächen am Ring (Shader-Uniforms, §8.7, geprüft
  A13) — nichts ragt über Gräben, Wände oder in Nachbarräume.

#### 3.5.5 Formation, Auftritt, Startpositionen

- `RtGeo.formation(slot, ax, az, yaw)` (+dz = hinter dem Anker, cm): Slot 0 `(0, 0)`, Slot 1 `(−130, 90)`, Slot 2 `(130, 90)`,
  Slot 3 `(0, 180)`; gedreht mit der Gier, dann `project_walkable`.
- Gegner: Der Anführer startet an `groups[].lead`; liegt der Punkt außerhalb des Rings, ist `entry = project_walkable(lead)`
  (Auftritt). Die Komparsen stehen in Formation um den Eintrittspunkt mit `pop_in_until = Ankunft + POP_IN_TICKS (15)`;
  aufgezeichnet wird nur die Anführerposition.
- Gruppenlose Kämpfe: Anker `RtGeo.group_anchor(geo, ctl_x, ctl_z)` (§2.3), erster Gegner = Slot 0 mit `entry` vom Ankerpunkt.
- Party: die gesteuerte Figur aus ihrer ersten Probe, der Partner aus seiner aufgezeichneten Position. Steht eine Party-Einheit
  außerhalb des Rings (Raumecke), setzt die Sim sie bei `ct = 0` auf den nächsten Ringpunkt (`POS_CORRECTED`); die Szene lässt
  sie in 0,3 s dorthin gleiten.

#### 3.5.6 Darstellung

Die Szene liest `RtSim.units()` nach jedem Tick und interpoliert sim-gesteuerte Einheiten zwischen vorigem und aktuellem Tick
(Anteil = Rest des Tick-Akkumulators; Gier über den kürzeren Bogen). Die gesteuerte Figur zeigt immer ihre Physikposition.
Umrechnung cm → m: `room_origin + Vector3(x / 100.0, 0, z / 100.0)` (nur in der Szene). Akteure anderer Räume sind während des
Kampfes ausgeblendet (§2.3).

### 3.6 Kampf-Timing

1. **GCD:** Fähigkeiten mit `rt.gcd == true` setzen `gcd_until = c + GCD_TICKS (45)`. Turbo: × 750 ‰ (= 34), nie unter
   `GCD_MIN_TICKS = 30`. Verlangsamt: × 1250 ‰ (= 56). Gegenstände, Spott, Unterbrecher sind GCD-frei.
2. **Auto-Angriff:** Schwungtakt `swing_ticks = swing_ms × 3 / 100` × Tempo-Faktor (Turbo 750, Verlangsamt 1250, Mods). Der
   Schwungtimer läuft unabhängig von Fähigkeiten; während Zauber/Kanal/Trinkpause wartet er (Schwung erst danach). Kein Ziel /
   außer Reichweite → kein Schwung, `swing_ready` bleibt (sofortiger Schwung, sobald in Reichweite). Erster Gegner-Schwung
   frühestens bei `ct = 30`.
3. **Zauberzeit:** `cast_ms > 0` → `CAST_START`, Wirkung bei `start + cast_ticks` (Tempo-Faktor wie GCD, Minimum 15 Ticks).
   Während des Zaubers: kein weiterer Zauber, keine GCD-Fähigkeit, kein Auto-Schwung; GCD-freie Fähigkeiten erlaubt (beenden den
   Zauber nicht). Gegenstände sind selbst eine kurze Aktion (Trinkpause, §3.11) und deshalb während eines Zaubers nicht möglich.
4. **Kanal:** `channel_ms > 0` → Wirkung alle `period_ms` während des Kanals (erster Tick nach `period`), Ende nach `channel_ms`.
5. **Bewegung bricht Zauber — mit Schwelle:** Hat die Fähigkeit `moving_cancels` (Standard `true` für Zauber/Kanäle der Party),
   endet der Zauber nur, wenn eine Probe während des Zaubers ein Tempo über `CAST_CANCEL_SPEED_PM` = 250 ‰ des Lauftempos meldet
   (`|v| > 46` mm/Tick bei `move_pm` 1000) **oder** die Position mehr als `CAST_CANCEL_CM` = 40 cm von `cast.x/z` (Zauberbeginn)
   entfernt ist: `CAST_FAILED`, `text = "moved"`; MP werden erst bei Wirkung abgezogen, die Abklingzeit startet nicht, der GCD
   läuft weiter. Stick-Drift und kleine Korrekturen brechen nichts. Sim-gesteuerte Einheiten bewegen sich nie während eines
   eigenen Zaubers.
6. **Queue-Fenster:** Ein `ability_use`, der in Schritt 1 auf GCD oder Zauber mit ≤ `QUEUE_TICKS = 9` Restzeit trifft, wird
   gepuffert (eine Fähigkeit; eine neue ersetzt die alte) und startet in Schritt 7 des Ticks, in dem GCD/Zauber frei werden.
   Mehr Restzeit → `ACTION_REFUSED` (`gcd` bzw. `casting`).
7. **Wirkzeitpunkt sofortiger Aktionen:** Treffer werden nach `impact_ms` (Standard nach Animation: `attack` 300 ms = 9 Ticks,
   `stunt` 800 ms = 24, Zauber 0 = bei Zauberende) als ausstehender Treffer eingereiht — **frühestens 1 Tick** nach dem Start
   (`max(1, impact_ticks)`), damit jede Sofortwirkung in Schritt 5 eines späteren Ticks landet, egal ob sie in Schritt 1 oder 7
   begann. Ziel und Wirkung stehen beim Start fest (auch wenn das Ziel sich entfernt). Die Darstellung darf Trefferanzeigen um
   ≤ 200 ms verzögern (Projektilflug), die Sim nicht.
8. **Unterbrechen:** Fähigkeiten mit `rt.interrupt` und jede Betäubung brechen einen laufenden **unterbrechbaren** Zauber/Kanal
   des Ziels ab: `CAST_INTERRUPTED` (Täter, Opfer, Zauber), der Zauber geht in seine Abklingzeit bzw. Regelwartezeit, Sperre
   `lockout_until = c + INTERRUPT_LOCKOUT_TICKS (60)` für neue Zauber; ein zugehöriger Telegraph verschwindet
   (`TELEGRAPH_CANCELLED`). Nicht unterbrechbare Zauber (`interruptible: false`) laufen weiter, auch unter Betäubung. Welche
   Zauber das Unterbrechen **lohnen** (`interrupt_worthy`), zeigt §6.2.
9. **Reichweite:** Abstand Mitte–Mitte ≤ `range_cm + r_ziel` (Nahkampf `reach + r_ziel`). Flächen um ein Ziel brauchen das Ziel in
   Reichweite, Flächen um sich selbst keine.
10. **Sichtlinie:** `RtGeo.los` (im Set immer gegeben).
11. **Ausrichtung:** Es gibt keine Blickrichtungs-Pflicht. Kegel der Party zeigen zum Ziel; die Darstellung dreht die Figur.
12. **Abklingzeiten:** `cooldowns[skill] = [c_start + cooldown_ticks, cooldown_ticks]` beim Wirkungsbeginn (Sofort) bzw. bei
    Zauberende. **SHOW und FINALE** teilen sich eine Abklingzeit **für die ganze Party** (`SHOW_CD_TICKS` = 900, 30 s, am Kampf
    gespeichert, nicht je Einheit): Wer zündet, sperrt sie für beide.
13. **Partner-Spezial:** Der Befehl `partner_special` (Einheit = Partner) setzt `partner_order = {"skill": rt.partner_special,
    "until": c + PARTNER_ORDER_TICKS (45)}`. In Schritt 7 startet der Partner diese Fähigkeit, sobald er frei ist (kein Zauber,
    GCD frei falls nötig, in Reichweite — sonst läuft er zuerst heran); mit normalen Prüfungen (Abklingzeit, MP) und
    `ACTION_START.by_ai = false`. Läuft `until` ab oder scheitert eine Prüfung, kommt `ACTION_REFUSED` mit Grund (HUD rüttelt den
    Knopf). Eine neue Anordnung ersetzt die alte.

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
- Anzeige (ab dem ersten Spott, §8.1): Namensplaketten zeigen einen Punkt in der Farbe des angegriffenen Party-Mitglieds;
  Party-Rahmen zeigen „×2“ für die Zahl der Gegner, die gerade dieses Mitglied angreifen (§8.4).

### 3.8 Status-Effekte in Echtzeit

- Anwenden: Immunität (`status_immune`, `rt.immune`) → `STATUS_BLOCKED`; Widerstand (`status_resist`, Wurf in bp) →
  `STATUS_BLOCKED`; Chance des Skills (`rt.statuses[].chance_pm`) gewürfelt. Dauer: `rt.statuses[].ms` oder
  `StatusDef.rt.default_ms`, auf Bossen × `boss_ms_pm` (Betäubung 500).
- Erneut anwenden (`stack_mode`): `refresh` → Dauer neu, Stapel +1 bis `max_stacks`, **Periodenphase bleibt** (`next_tick_at`
  unverändert); `replace` (Standard) → Dauer neu, Stapel 1, Phase bleibt; `ignore` → keine Wirkung, solange aktiv. Neue
  Anwendung (Status nicht vorhanden): `next_tick_at = c + period`. `excludes` entfernt die ausgeschlossenen Status
  (`STATUS_REMOVED`) wie bisher.
- **Periodische Wirkung je Takt und Stapel** — zwei Arten, nie beide:
  - **Kraft-Ticks** (`tick_power` am anwendenden Skill, `rt.statuses[].tick_power`; für alle DoTs, die die Party verteilt, z. B.
    Brennt): Betrag einmal bei der Anwendung = `DamageCalc`-Formel (Wert des Anwenders gegen DEF/RES des Ziels nach
    `damage_type`, Element des Status, ohne Krit und Varianz), in `RtStatus.amount` eingefroren. Skaliert mit Werten, nicht mit
    den Max-HP des Ziels.
  - **Prozent-Ticks** (`tick_pct` des Status; Gegner-Gifte, Heilung über Zeit): `max(tick_min, div_round(max_hp × |tick_pct|,
    100))`, **höchstens `tick_max`** (wenn > 0).
  - Auf Bossen jeweils × `boss_tick_pm` des Status (Standard 1000). Schaden mit Element (Element-Multiplikatoren gelten,
    Immunität → 0), kein Krit, keine Varianz, `dmg_taken_pm` gilt (§3.9.1).
- Stapel wirken wie n Kopien: `dmg_dealt_pm`, `dmg_taken_pm`, `move_pm`, `haste_pm` werden je Stapel gefaltet (§3.9.1).
- Flags (`StatusDef.flags` + RT-Flags): `no_act` (keine Fähigkeiten, keine Auto-Angriffe), `no_move`, `no_cast` (keine Zauber/
  Kanäle), `fixate` (Träger muss die Quelle angreifen), `interrupt_on_apply` (bricht unterbrechbare Zauber), `hidden` (kein
  Symbol), `guard` (bestehend: DEF/RES-Faktor über `stat_mult` und DamageCalc).
- Entfernen: Ablauf, `cleanse`-Listen von Fähigkeiten/Gegenständen, K.O. (alle), Flucht/Ende (alle).

| Status | Dauer | Periode | Wirkung | Stapel | Sonstiges |
|---|---|---|---|---|---|
| `sts_poison` Vergiftet | 8,0 s | 2,0 s | −2 % Max-HP je Stapel (min 1, max 12) | 3, `refresh` | Element Gift, `boss_tick_pm` 500 |
| `sts_stun` Betäubt | 2,0 s | — | `no_act`, `no_move`, `interrupt_on_apply` | 1, `ignore` | Bosse × 0,5 |
| `sts_slow` Verlangsamt | 4,0 s | — | `move_pm` 600, `haste_pm` 1250 | 1 | schließt Turbo aus |
| `sts_haste` Turbo | 10,0 s | — | `move_pm` 1200, `haste_pm` 750 | 1 | schließt Verlangsamt aus |
| `sts_guard` Gepanzert | 6,0 s | — | DEF/RES × 1,5 (bestehend); Prozent-Treffer × 2/3 (§3.9.1) | 1 | |
| `sts_taunt` Blickfang | 4,0 s | — | Gegnerseitig: KI und Auto-Ziel der Party bevorzugen den Träger | 1 | nur Schaufensterpose |
| **neu** `sts_taunted` Provoziert | 4,0 s | — | `fixate` auf die Quelle | 1, `replace` | auf Gegnern |
| **neu** `sts_dazed` Überrumpelt | 3,0 s (Party 1,5 s) | — | `no_act`, `move_pm` 500 | 1, `ignore` | Bosse immun |
| **neu** `sts_regen` Erholung | 10,0 s | 2,0 s | +3 % Max-HP | 1 | Massen-Schlabbern |
| **neu** `sts_burn` Brennt | 6,0 s | 1,0 s | Kraft-Tick `tick_power` 20 (vom anwendenden Skill) | 1, `refresh` | Element Feuer |
| **neu** `sts_admonished` Ermahnt | 12,0 s | — | `dmg_dealt_pm` 800 | 1 | Hausmeister |
| **neu** `sts_dizzy` Schwindelig | 3,0 s | — | `no_act`, `no_move`, `dmg_taken_pm` 1250 | 1 | Hausmeister |
| **neu** `sts_enrage` Feierabend! | bis Kampfende | — | `dmg_dealt_pm` 1500 je Stapel (Gesamtfaktor ≤ 8000 ‰) | 9, `refresh` | Enrage |

Größenordnung (Startausrüstung des Bots): Brennt aus Kais Deo-Flammenwerfer (Stufe 6, STR 34) tickt gegen den Hausmeister
(DEF 14) mit ≈ 4 je Sekunde, gegen eine Kanalratte (DEF 5, Feuer × 1,5) mit ≈ 7 — vorher (1 % Max-HP) waren es 26 gegen den Boss
und 1 gegen die Ratte. Gift auf einem Boss (2 % von 5 000 = 100) wird auf 12 gedeckelt und halbiert: 6 je Takt.

### 3.9 Schaden, Heilung, Krit, Varianz, Zufall

#### 3.9.1 Formel (GDD §3.7 unverändert pro Treffer) und Faltung der Echtzeit-Faktoren

Jeder Formel-Treffer nutzt **unverändert** `DamageCalc.compute` (A²/(A+D) × Kraft/100 × Varianz 900–1100 ‰ × Krit 1,5 bei
physisch × Element (schwach 1,5 / resistent 0,5 / immun 0) × Gepanzert-Faktor × Gegner-Schadensfaktor `enemy_dmg_mult`,
mindestens 1). Echtzeit entsteht über die **Taktung** (Auto-Angriff 2,0–3,0 s, Fähigkeiten mit GCD/Abklingzeit), nicht über eine
neue Formel. Danach faltet `rt_damage.gd` die Echtzeit-Faktoren in ‰ **einzeln** zu einem gedeckelten Gesamtfaktor:

```
f = 1000
für x in [dmg_dealt_pm des Verursachers (je Status, je Stapel, Anwendungsreihenfolge),
          dmg_taken_pm des Ziels (ebenso), dmg_pm (nur Gegner als Verursacher), opener_pm (§9.6), combo_pm, mods_pm (RtMods)]:
    wenn x != 1000:  f = clampi(FixedMath.mul_pm(f, x), 0, DMG_FACTOR_MAX_PM)      # 8000 ‰
amount = base                                 wenn f == 1000
amount = 0                                    wenn base == 0 (Immunität) oder f == 0
amount = max(1, FixedMath.mul_pm(base, f))    sonst
```

- Kein Produkt über alle Faktoren mit einer Division durch `1000^n` mehr: Jeder Schritt bleibt klein (`f ≤ 8000`, Faktoren ≤ 5000
  laut Validator → Zwischenwert ≤ 4 · 10⁷), es gibt keinen Überlauf und keine stillen Vorzeichenfehler. Die Reihenfolge ist fest,
  deshalb sind Rundungen reproduzierbar.
- Pflichttest `test_r1_rt_damage_fold`: Grundwert 50 mit Enrage 1/2/3/4 Stapeln → 75 / 113 / 169 / 253; alle Faktoren am
  Validator-Maximum plus 9 Enrage-Stapel → `f = 8000`, Betrag `mul_pm(base, 8000)`, ohne Überlauf; neutrale Faktoren ändern
  nichts (kein Rundungsschritt).
- **Prozent-Treffer** (`rt.pct_maxhp`, gegnerische Telegraphen §6.3, Zug, „Kreischen“): `base = div_round(max_hp(Ziel) × pct,
  100)`, ohne Formel, Element, Krit, Varianz und ohne `dmg_pm`; gefaltet werden nur die `dmg_taken_pm`-Faktoren des Ziels und
  Gepanzert als 667 ‰ (außer `ignore_guard`). Ein Treffer kostet so immer denselben, lesbaren Anteil („ein Viertel deiner HP“).
- `Kraft` = `rt.power` falls gesetzt, sonst `power` (R4 darf Echtzeit-Kräfte getrennt einstellen; nach der CTB-Entfernung wird
  `rt.power` in `power` gebacken).
- **Combo:** Treffen beide Party-Mitglieder dasselbe Ziel mit schadenden Fähigkeiten (keine Auto-Angriffe) innerhalb von
  `COMBO_WINDOW_TICKS = 30`, ist der zweite Treffer ein Combo: × `COMBO_PM (1100)` und Ereignis `COMBO` (höchstens eines je
  `COMBO_COOLDOWN_TICKS = 150`).
- **Krit:** Chance unverändert `clamp(0,05 + LCK × 0,005 + Boni, 0, 0,40)`, nur physischer Schaden (wie bisher).
- **Fester Schaden** (`damage_type: fixed`, z. B. Molotow) und **feste Heilung** (Werbepflaster, Burger, Geschenk
  `heal_party_flat`) werden mit `FIXED_SCALE_PM (4000)` skaliert (§3.9.4).
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

`rng_n` ist Teil des Snapshots. Reihenfolge der Würfe = Verarbeitungsreihenfolge §3.3 → deterministisch. Abfragen (`can_use`,
`suggest`) würfeln nie (§3.4). Beute bei `VICTORY`: `SeedUtil.derive(setup.seed, "drops", 0)` wie bisher. Online liefert der
Server die Würfe aus dem geheimen Server-Seed (§10.8).

#### 3.9.4 HP-Skala und lesbare Zahlen

| Wert | Faktor (bis R5b zur Laufzeit, ab R5b in die Daten gebacken) |
|---|---|
| Party Max-HP | × 4 (`PartyMember.hp_scale_pm = 4000`, letzter Schritt von `Progression.total_stats`, nach Klasse und Spezies) |
| Reguläre Gegner Max-HP | × 7 (`EnemyDef.rt.hp_pm`, Standard `ENEMY_HP_PM` = 7000 aus `rt_balance.json`; Kanalschleim 4800, Azubi absolut 280) |
| Bosse Max-HP | absolut (`EnemyDef.rt.hp`): Hausmeister 5 000, Rattenkönigin 7 600 (Startwerte §6.6–6.7) |
| Feste Heilung/fester Schaden | × 4 (`FIXED_SCALE_PM`) |
| Schaden pro Treffer, `mag`-Heilung, Prozentwerte, MP | unverändert |

Warum Gegner stärker skaliert werden als die Party: Mit der neuen MP-Ökonomie (§3.10) nutzt Kai seine Hauptfähigkeit auf den
meisten GCDs; die Party macht deshalb mehr Schaden pro Sekunde als im ersten Entwurf. × 7 trifft die Ziel-Kampfdauer (§11.3).

Rechenbeispiele (Stufe 1, Startausrüstung): Kai (STR 12 + Mopp 4 = 16) Wuchtschlag auf Kanalratte (DEF 5):
16²/21 × 1,6 = 19,5 → 18–21 (Krit 27–32); Kanalratte 168 HP (24 × 7) → 9 Wuchtschläge oder 14 Auto-Treffer à ~12. Adelsflamme
(MAG 17, RES 3, Feuer schwach): 17²/20 × 1,1 × 1,5 = 23,8. Kanalratten-Biss auf Kai (DEF 12): 13²/25 = 6,8 → 2,6 % von Kais
256 HP. Hausmeister-Besenhieb auf Kai Stufe 5 (DEF 21 mit Warnweste): 40²/61 × 1,1 = 28,9 → 7,2 % von 400 HP alle 2,8 s.
Ein verpasster Schlüsselbund-Wurf kostet dagegen 20 % (80 HP), der Zug 35 %.

### 3.10 Ressource: MP für beide

**Entscheidung:** Beide Figuren nutzen **MP** („Energie“, eine blaue Leiste); keine Wut als zweite Ressource. Begründung:
(1) eine Leiste, eine Regel — sofort verständlich, auch beim Heldenwechsel; (2) alle bestehenden Systeme bleiben gültig
(KRAWUMM-Dose +20 MP, Elixier, Werbepause +15 %, Sponsor `mp_party_pct`, Stufen-Wachstum, Talente); (3) der Wut-Rhythmus entsteht
trotzdem: Kai lädt durch Treffen und Getroffenwerden.

| Figur | Laden im Kampf | Außerhalb |
|---|---|---|
| Kai | +1 MP je eigenem gelandeten Auto-Angriff; **+1 MP je erlittenem Treffer** (Auto-Angriff, Fähigkeit, Telegraph — keine Status- oder Zonen-Takte), höchstens 1 je `HIT_MP_EVERY_TICKS` = 30; keine Zeit-Regeneration | §2.7 |
| Graf Mopsula | +1 MP alle 1,5 s (45 Ticks, ab `ct = 0`, auch beim Zaubern) | §2.7 |
| Gegner | MP werden im Echtzeitkampf **nicht** verwendet (Regel-Wartezeiten steuern das Tempo) | — |

- **Kais Hauptfähigkeit kostet 2 MP** (Wuchtschlag, Slot 1). Als Ziel von 2–3 Gegnern lädt Kai ≈ 1,2–1,5 MP/s und kann fast jeden
  GCD (1,5 s) drücken; im Bosskampf (ein Boss, gelegentlich Adds) ≈ 0,9–1,1 MP/s — genug für Wuchtschlag auf zwei von drei GCDs
  plus Spott und Unterbrechen. Startmenge (12 MP auf Stufe 1, +2 je Stufe) erlaubt einen kräftigen Auftakt.
- **Unterbrecher sind billig** (Kai 3 MP, Mopsula 5 MP, §4.2/4.3), damit sie immer bezahlbar sind.
- **KI-Reserve:** Regeln mit `filler: true` (Füller wie Wuchtschlag, Adelsflamme, Frostniesen) feuern bei KI-gesteuerten Einheiten
  nur, wenn danach noch die MP des eigenen Unterbrechers übrig bleiben (falls gelernt und Schalter „Unterbrechen“ an) — die KI
  hat das Unterbrechen also immer im Köcher (§5.3).
- Kosten werden bei **Wirkung** abgezogen (Sofort: beim Start; Zauber: bei Zauberende, nach Prüfung). Reicht MP bei Zauberende
  nicht mehr (z. B. weil während des Zaubers ein GCD-freier Unterbrecher MP verbraucht hat), schlägt der Zauber fehl
  (`CAST_FAILED`, `mp`).

### 3.11 Tränke und Gegenstände im Kampf

- Befehl `combat_item` (Inventar der Party). Jede Benutzung ist eine **Trinkpause** von `DRINK_TICKS` = 15 (0,5 s): kein
  Bewegen (`no_move`), keine Fähigkeit, kein Auto-Angriff, nicht während eines Zaubers; die Wirkung kommt am Ende der Pause
  (Schritt 6). GCD-frei. Die Szene hält die Figur ab dem angenommenen Befehl an (keine Korrekturen nötig).
- **Gemeinsame Abklingzeit der Party:** `ITEM_CD_TICKS` = 450 (15 s) für alle Verbrauchsgüter, am Kampf gespeichert (nicht je
  Einheit). **Höchstens `ITEM_MAX_PER_COMBAT` = 3 Verbrauchsgüter je Kampf** (Party gesamt; Grund `items_max`). Bosskämpfe
  werden so nicht zur Inventarfrage: ein Bandage-Paket (3 × 180 HP) ist das Maximum an Fremdheilung je Kampf neben Mopsula und
  Sponsoren.
- Die Leistentaste **Trank** wählt automatisch: der kleinste Heilgegenstand (Tag `heal`), dessen Heilung die fehlenden HP des
  Ziels deckt, sonst der größte; Ziel = aktuelles freundliches Ziel, sonst die gesteuerte Figur. Weitere Gegenstände über das
  Gegenstandsrad (§7). Die Taste zeigt die Restanzahl im Kampf („2/3“).
- Gegenstand-Wirkungen kommen aus dem `use_skill` (skills.json `rt`, §4.5); `itm_smoke` → Flucht (§2.5); `itm_hype_megaphone` →
  nur Show (+25 Hype über `SkillDef.hype`, wie bisher).
- **KI-Partner** benutzen Gegenstände nur in der Taktik **„Vorsichtig“** oder mit eingeschaltetem Schalter **Tränke** (Standard
  aus, §5.2), **nie den letzten** Gegenstand einer Art im Party-Inventar.

### 3.12 Beschwörungen, entkommende Gegner, Kampfende

- Beschwörung (`summon` in Regeln/Phasen): höchstens `MAX_ENEMIES = 6` lebende Gegner; Ort `door` (Ende der Türgasse der nächsten
  Tür zur Party-Mitte, Gleichstand N, E, S, W; im geschlossenen Set der Ringpunkt vor dieser Tür) oder `near` (Formation um den
  Beschwörer); mit Auftritt; `is_summon = true` (keine EXP/Beute), Bedrohung 1 auf der nächsten Party-Einheit. Ereignis `SUMMON`
  (bestehend).
- Entkommen (`special.kind == "escape"`): Einheit verlässt den Kampf (`ESCAPED`, bestehend), zählt für `VICTORY` nicht mehr.
- `BattleResult` wird wie bisher gefüllt (EXP, Credits, Overkill-Credits, Diebstahl/Erstattung, Beute, Boss-Belohnungen, Party-HP/
  -MP, `item_delta`, Kills, Bestiarium, Schwächen, Schaden, Krits, Schwächetreffer, Gegenstände, Party-K.O.) und ergänzt um
  `group_ids` (alle beteiligten Gruppen), `duration_ticks`, `interrupts`, `dodges`, `telegraph_hits` (die drei nur für die
  gesteuerte Figur, §9.1), `train_kills`, `perfect_phases`, `potions_used`, `flee_attempts` (jeder Beginn einer Fluchtwarnung —
  0,5 s außerhalb des Rings — und jeder Nebel); `turns` = Zahl der `ACTION_START` aller
  Einheiten, `party_turns` = Zahl der `ACTION_START` mit `by_ai == false` (Aktionen der Person: eigene Figur und Partner-Spezial;
  Auto-Angriffe zählen nicht).

### 3.13 Ereignisstrom (Kampf-Log)

Die Sim liefert `ActionEvent`s (02_TECH §5.3). Wiederverwendet, damit ShowRules, Achievements und Darstellung möglichst viel
behalten: `BATTLE_START` (`value` = Vorteil, `target_ids` = alle Einheiten), `ACTION_START` (`command` = `BattleCommand.Kind`
SKILL/STUNT/ITEM, `skill_id`, `item_id`, `target_ids`, `text`), `COMBO`, `DAMAGE`, `HEAL`, `MP_CHANGE`, `STATUS_ADDED` (`value` =
Dauer in Ticks, `rt.stacks`), `STATUS_REMOVED`, `STATUS_BLOCKED`, `KO` (`command`: ATTACK für Auto-Angriffe, SKILL, STUNT, ITEM,
−1 für Status/Zonen/Telegraphen), `REVIVE`, `SUMMON`, `ESCAPED`, `CREDITS_STOLEN`, `CREDITS_GAINED`, `STUNT_RESULT`,
`FLEE_RESULT` (`success = true` bei Flucht), `ITEM_GAINED`, `SPONSOR_GIFT`, `PHASE_CHANGE` (`value` = Phase ab 1, `success` =
vorige Phase perfekt), `MOD_LINE`, `ANNOUNCE`, `BATTLE_END` (`value` = Ergebnis, `success` = letzte Bossphase perfekt).
Im Echtzeitkampf **nicht** benutzt: `TURN_START`, `TURN_END`, `CTB_ORDER`, `DEFEND`, `PSEUDO_REMOVED`.

Neue Felder an `ActionEvent` (nur serialisiert, wenn ≠ Standard): `tick: int = -1` (ct), `rt: Dictionary = {}` (Ganzzahlen),
**`by_ai: bool = false`** — `true` an `ACTION_START`, `CAST_START`, `STUNT_RESULT`, `CAST_INTERRUPTED` und `KO`, wenn die
auslösende Aktion von der KI gewählt wurde (Gegner, KI-Partner, Autopilot), und an `TELEGRAPH_DODGED`, wenn die ausweichende
Einheit sim-gesteuert ist; `false` für Aktionen aus Befehlen der Person (eigene Figur, gepufferte Eingaben, Partner-Spezial). Show
und Marotten zählen Spieler-Leistungen über dieses Feld (§9.1, §9.6). Neue Typen werden **am Ende** des Enums angehängt
(bestehende Werte bleiben stabil):

| Typ | Felder | Bedeutung / Verbraucher |
|---|---|---|
| `SWING` | `actor_id`, `target_id`, `skill_id` | Auto-Angriff beginnt (Animation); Treffer folgt als `DAMAGE` |
| `ACTION_END` | `actor_id`, `skill_id`/`item_id` | schließt eine Aktion (ShowRules: ersetzt `TURN_END` für Aktionsklammern) |
| `ACTION_REFUSED` | `actor_id`, `skill_id`/`item_id`, `text` = Grund | HUD-Rückmeldung („Nicht genug MP“) |
| `CAST_START` | `actor_id`, `skill_id`, `target_id`, `value` = Ticks, `success` = unterbrechbar, `rt.end`, `rt.worthy` (1 = unterbrechenswert) | Zauberleisten, Hinweis-Ton, KI |
| `CAST_INTERRUPTED` | `actor_id` = Unterbrecher, `target_id` = Zaubernder, `skill_id` | Show +3 (gesteuerte Figur als Täter) |
| `CAST_FAILED` | `actor_id`, `skill_id`, `text` (`moved`, `target`, `mp`, `stunned`, `dead`) | HUD, Animation |
| `TELEGRAPH_START` | `actor_id`, `skill_id`, `value` = Telegraph-Id, `rt` = `{shape, x, z, yaw, r, r2, half, start, impact}` | TelegraphLayer, Ton |
| `TELEGRAPH_IMPACT` | `actor_id`, `skill_id`, `value`, `target_ids` = getroffene Einheiten | Show (perfekte Phase), Effekte |
| `TELEGRAPH_DODGED` | `target_id`, `value`, `success` = knapp (≤ 9 Ticks vor Einschlag noch drin) | Show +2/+4 (gesteuerte Figur) |
| `TELEGRAPH_CANCELLED` | `value` | TelegraphLayer |
| `ZONE_START` | `actor_id`, `skill_id`, `status_id`, `value` = Zonen-Id, `rt` = Geometrie + `end` | TelegraphLayer |
| `ZONE_END` | `value` | TelegraphLayer |
| `TARGET_CHANGED` | `actor_id`, `target_id` (`""` = keins) | HUD, Plaketten |
| `CONTROL_CHANGED` | `actor_id` = vorher, `target_id` = jetzt gesteuert | Szene (vorübergehender Körpertausch), M.O.D. |
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
5. Alle Würfe über `SeedUtil.derive(seed, "rt", rng_n)` (§3.9.3); Abfragen würfeln nie (§3.4).
6. Snapshots sind kanonisches JSON (02_TECH `CanonicalJson`; nur Ganzzahlen, Strings, Bools, Listen, sortierte Dictionaries).

### 3.15 Leistungsbudget der Sim

| Messgröße | Budget |
|---|---|
| `RtSim.step()` mit 2 Party, 6 Gegnern, 10 Telegraphen/Zonen | ≤ 0,25 ms Desktop, ≤ 1,0 ms Profil `low` |
| Harness: ein regulärer Kampf (≈ 600 Ticks) headless | ≤ 0,3 s |
| Harness: ein Bosskampf (≈ 6 000 Ticks) headless | ≤ 2,0 s |
| Nachholen pro Frame (Hänger) | höchstens 4 Ticks; danach wird Zeit verworfen (Zeitlupe, kein Spiralen) |

### 3.16 Stellwerte: `data/rt_balance.json` und `RtBalance`

Alle Zahlen, die Balancing verändern darf, stehen in **`data/rt_balance.json`** (`{"schema": 1, "values": {…}}`, Eigentum R4,
Teil von `DB.data_hash()` und damit jedes Run-Log-Kopfs). `core/rt/rt_balance.gd` (`RtBalance`, Eigentum R1) definiert Schlüssel,
Typen, erlaubte Bereiche und dieselben Startwerte als Standard; `RtBalance.from_data(data)` liest die Datei einmal je Kampf,
`validators/rt.gd` prüft sie (fehlende/unbekannte Schlüssel, Bereiche). So ändert R4 Werte ohne Code, und niemand ändert die
Struktur ohne R1. Startwerte:

```json
{"schema": 1, "values": {
 "TICKS_PER_SEC": 30, "GCD_TICKS": 45, "GCD_MIN_TICKS": 30, "CAST_MIN_TICKS": 15, "QUEUE_TICKS": 9,
 "IMPACT_TICKS": {"attack": 9, "cast": 0, "stunt": 24, "item": 9},
 "INTERRUPT_LOCKOUT_TICKS": 60, "ITEM_CD_TICKS": 450, "ITEM_MAX_PER_COMBAT": 3, "DRINK_TICKS": 15,
 "SHOW_CD_TICKS": 900, "AI_SHOW_GRACE_TICKS": 150, "PARTNER_ORDER_TICKS": 45, "FINALE_TARGET_BELOW_PM": 300,
 "FIRST_SWING_TICKS": 30, "POP_IN_TICKS": 15, "ENTER_MAX_TICKS": 30, "AI_SLOT_OFFSET_TICKS": 9,
 "REACT_TICKS": {"attack": 18, "support": 12, "careful": 6}, "AI_INTERRUPT_REACT_TICKS": 0,
 "ESCAPE_MARGIN_CM": 60, "RANDOM_POINT_MIN_CM": 300, "FLEE_TICKS": 60, "FLEE_WARN_TICKS": 15,
 "DR_THRESHOLD_CM": 15, "DR_VEL_THRESHOLD": 15, "DR_YAW_THRESHOLD": 8, "DR_MAX_TICKS": 30, "HEARTBEAT_TICKS": 15,
 "FORCE_SAMPLE_CM": 2, "MOVE_BUDGET_MM": 600, "MOVE_REFILL_MM_TICK": 3, "SPEED_TOLERANCE_PM": 1250, "PLAYER_RUN_CM_S": 550,
 "CAST_CANCEL_SPEED_PM": 250, "CAST_CANCEL_CM": 40,
 "CELL_HALF_CM": 800, "ROOM_INNER_CM": 750, "SET_R_CM": {"regular": 480, "boss": 600}, "DOOR_HALF_CM": 200,
 "MELEE_STOP_CM": 30, "THREAT_SWITCH_PM": 1100, "TAUNT_TOP_PM": 1100, "TAUNT_RADIUS_CM": 1000, "FIXATE_TICKS": 120,
 "HEAL_THREAT_PM": 500, "DEBUFF_THREAT": 10, "COMBO_WINDOW_TICKS": 30, "COMBO_COOLDOWN_TICKS": 150, "COMBO_PM": 1100,
 "OVERKILL_PM": 500, "DMG_FACTOR_MAX_PM": 8000, "PCT_GUARD_PM": 667, "CLOSE_DODGE_TICKS": 9, "HIT_MP_EVERY_TICKS": 30,
 "MAX_PARTY": 4, "MAX_ENEMIES": 6, "MAX_TELEGRAPHS": 10, "MAX_COMBAT_TICKS": 18000, "CHECKPOINT_TICKS": 300,
 "HP_SCALE_PM": 4000, "FIXED_SCALE_PM": 4000, "ENEMY_HP_PM": 7000, "STUN_BOSS_PM": 500, "EASY_WARN_PM": 1250,
 "REVIVE_GUARD_MS": 3000, "REGEN_PERIOD_TICKS": 90, "REGEN_HP_DELAY_TICKS": 150, "REGEN_HP_PM": 5, "REGEN_MP_PM": 20,
 "CHASE_COMBAT_SEC_X10": 40
}}
```

Strukturkonstanten, die keine Balance sind (`TICKS_PER_SEC`, Enum-Werte, Vokabulare), bleiben Code; `TICKS_PER_SEC` steht nur zur
Prüfung in der Datei (muss 30 sein). `CHASE_COMBAT_SEC_X10` liest die Erkundung (Szenenlogik) als 4,0 s.

---

## 4. Fähigkeiten

### 4.1 Aktionsleiste, Freischaltung, Varianten, SHOW/FINALE, Partner-Spezial

| Slot | Inhalt | Taste PC / Gamepad (§7) |
|---|---|---|
| 1 | Hauptfähigkeit (oft drücken, keine Abklingzeit, kein Wiederholungsabzug im Hype) | `1` / A |
| 2 | Schutz bzw. Heilung | `2` / X |
| 3 | Kontrolle (Unterbrecher) | `3` / Y |
| 4 | Fläche bzw. Unterbrecher | `4` / B |
| 5 | **SHOW** (Stunt); wird zum **FINALE**, wenn die Bedingung erfüllt ist (unten) | `5` / RB |
| 6 | **Trank** (automatische Wahl, §3.11; Gegenstandsrad per Rechtsklick/Halten) | `6` / LB |
| — | **Partner-Spezial** (eigener Knopf neben dem Party-Rahmen, §7.3, §8.4) | `R` / Steuerkreuz links |

- **Die Leiste wächst mit dem Level:** Slots ohne freigeschaltete Fähigkeit werden nicht angezeigt (Stufe 1: Kai Slot 1 + 5 + 6,
  Mopsula Slot 1 + 2 + 5 + 6; ab Stufe 4 sind alle Slots belegt). Die Freischaltung steht in `party.json` → `rt.bar` (unabhängig
  von der CTB-Lernliste, §4.8), sodass CTB bis zur Entfernung unverändert bleibt.
- **Varianten:** Ab Stufe 4–7 erhalten Slots 2–4 je eine Alternative. Die Belegung wählt man außerhalb des Kampfes im
  Fähigkeiten-Menü (`PartyMember.rt_loadout`, Standard = Grundfähigkeit). Spezies und Spezialisierung (06, ab Etage 3) dürfen
  weitere Varianten freischalten (`unlock_variant`, §9.5).
- **Kontext-Variante:** Mopsulas Slot 2 wird auf einem K.O.-Ziel automatisch zu „Sabber der Wiederkehr“ (ab Stufe 7).
- **SHOW:** Stunt mit Risiko und viel Hype; **eine Abklingzeit für die ganze Party** (30 s, §3.6.12). Der KI-Partner zündet seine
  eigene SHOW nur, wenn die SHOW schon `AI_SHOW_GRACE_TICKS` = 150 (5 s) bereitliegt und der Schalter „Show-Einlagen“ an ist — die
  Person hat immer den ersten Zugriff („Lässt du die Show liegen, macht es dein Partner.“).
- **FINALE** (Bedingung **in der Sim**): Der SHOW-Slot zeigt und wirkt das FINALE, wenn die Figur **mindestens Stufe 6** ist
  (`bar`-Eintrag mit `finale: true`, `level` 6 — vor der Rattenkönigin erreichbar) **und** ihr aktuelles feindliches Ziel **unter
  30 % HP** hat (`FINALE_TARGET_BELOW_PM` = 300). Es ist ein echter Finisher; `can_use` meldet sonst `target_hp`. FINALE teilt die
  SHOW-Abklingzeit, die KI nutzt es nie („Das Finale gehört dem Publikum — und dir.“). Der Hype spielt **keine** Rolle für die
  Regel; er steuert nur die Darstellung (M.O.D.-Reaktion, bei Hype ≥ 85 großes Konfetti).
- **Partner-Spezial:** befiehlt dem KI-Partner sofort seine Signatur (`party.json` → `rt.partner_special`): Kai „Hier spielt die
  Musik!“ (Spott, ab Stufe 2), Graf Mopsula „Heiliges Schlabbern“ (Heilung, Smart-Ziel, ab Stufe 1) — mit deren normaler
  Abklingzeit und MP (§3.6.13). Der Knopf erscheint, sobald der Partner die Fähigkeit hat, und zeigt deren Abklingzeit.

### 4.2 Kai (Nahkampf, Beschützer)

Auto-Angriff „Mopp-Schlag“ (`skl_attack_kai`): physisch 100, alle 2,0 s, Reichweite 250 cm, Treffer nach 0,3 s.
MP: Stufe 1 = 12 (+2 je Stufe); Laden +1 je Auto-Treffer, +1 je erlittenem Treffer (höchstens 1/s, §3.10).
Partner-Spezial (wenn Kai der Partner ist): Slot-2-Grundfähigkeit „Hier spielt die Musik!“.

| Slot | Fähigkeit (`id`) | ab Stufe | MP | Abklingzeit | Zauber-/Wirkzeit | Reichweite | Ziel | Wirkung | Bedrohung | GCD | Show-Tag | Symbol-Idee |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Wuchtschlag (`skl_kai_heavy_swing`) | 1 | 2 | — | sofort, Treffer +0,3 s | 250 | Gegner | 160 physisch | × 2,0 | ja | flashy | Mopp mit Bewegungslinien |
| 2 | Hier spielt die Musik! (`skl_kai_taunt`) | 2 | 2 | 15 s | sofort (+1 Tick) | Radius 1000 um Kai | alle Gegner im Radius | `sts_taunted` 4 s (Fixierung auf Kai, Bedrohung Spitze +10 %), Kai `sts_guard` 6 s | Spott | nein | risky | Megafon mit Noten |
| 2 V | Erste Hilfe (Tierarzt-Edition) (`skl_kai_first_aid`) | 4 | 4 | 12 s | sofort | 800 | Verbündeter (Smart) | Heilung 30 % Max-HP, entfernt Gift + Brand | Heil-Bedrohung | ja | cute | Pflaster mit Pfotenabdruck |
| 3 | Leinen-Fallstrick (`skl_kai_leash_trip`) | 3 | 3 | 12 s | sofort, Treffer +0,3 s | 800 | Gegner | 70 physisch, **unterbricht**, `sts_slow` 4 s (90 %) | × 1,0 | nein | — | Hundeleine als Lasso |
| 3 V | Kabelpeitsche (`skl_kai_cable_whip`) | 7 | 6 | 18 s | sofort, Treffer +0,3 s | 600 | Gegner | 120 Schock, **unterbricht**, `sts_stun` 1,5 s (100 %; Boss 0,75 s, Widerstand gilt) | × 1,0 | nein | flashy | Kabel mit Funken |
| 4 | Rundumfeger (`skl_kai_sweep`) | 4 | 5 | 8 s | sofort, Treffer +0,4 s | Radius 350 um Kai (+ Zielradius) | alle Gegner im Radius | 80 physisch | × 1,5 | ja | flashy | Mopp im Kreis |
| 4 V | Deo-Flammenwerfer (`skl_kai_deo_torch`) | 6 | 7 | 14 s | **Kanal** 2,0 s (4 × alle 0,5 s), Bewegung bricht (Schwelle §3.6.5) | Kegel 500 cm / 60° zum Ziel (+ Zielradius) | Gegner im Kegel | je Tick 40 Feuer, `sts_burn` 6 s (Kraft-Tick 20) | × 1,0 | ja | flashy, risky | Spraydose mit Flamme |
| 5 | **SHOW:** Bahnsteig-Suplex (`skl_stunt_kai_suplex`) | 1 | 0 | 30 s (Party) | Stunt, Treffer +0,8 s | 250 | Gegner | Erfolg (60 % + LCK × 1 %, max 85 %, Boss −15 %; Talent-Faktor §9.6): 230 physisch + `sts_stun` 2 s; Fehlschlag: 10 % eigene Max-HP Schaden + Kai `sts_stun` 1,5 s | × 1,0 | ja | risky, flashy | Ringer-Silhouette mit Sternchen |
| 5 F | **FINALE:** Prime-Time-Finisher (`skl_kai_prime_finisher`) | 6, Ziel < 30 % HP | 8 | 30 s (Party, mit SHOW geteilt) | Stunt, Treffer +0,8 s | 250 | Gegner | 260 physisch, Krit +20 %, `kill_hype` 10, kein Fehlschlag | × 1,0 | ja | finisher, flashy | Studiokamera mit Blitz |
| 6 | Trank | — | — | 15 s (Party), ≤ 3 je Kampf | Trinkpause 0,5 s | — | Smart | §3.11 | — | nein | — | Flasche mit Pflaster |

### 4.3 Graf Mopsula (Magier, Heiler)

Auto-Angriff „Monokel-Funkeln“ (**neu** `skl_rt_auto_mopsula`): magisch 60, Element `none`, alle 2,4 s, Reichweite 1000 cm,
Wirkung beim Schwung (Lichtstrahl aus dem Monokel). MP: Stufe 1 = 30 (+4 je Stufe), Laden +1 alle 1,5 s. Partner-Spezial (wenn
Mopsula der Partner ist): „Heiliges Schlabbern“. Symbole und Optik ohne Kronen-Motiv (06 §3.2, 04 Kap. 2.3): Mopsulas Zeichen sind
Monokel, Siegel-Plakette, Umhang und Zunge.

| Slot | Fähigkeit (`id`) | ab Stufe | MP | Abklingzeit | Zauber-/Wirkzeit | Reichweite | Ziel | Wirkung | Bedrohung | GCD | Show-Tag | Symbol-Idee |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Adelsflamme (`skl_mop_noble_flame`) | 1 | 4 | — | Zauber 1,5 s, Bewegung bricht (Schwelle) | 2000 | Gegner | 110 magisch Feuer | × 1,0 | ja | flashy | Flamme über einer Siegel-Plakette |
| 2 | Heiliges Schlabbern (`skl_mop_holy_lick`) | 1 | 4 | — | Zauber 1,5 s, Bewegung bricht (Schwelle) | 2000 | Verbündeter (Smart) | Heilung `mag` 100 | Heil-Bedrohung | ja | cute, gross | Zunge mit Glitzer |
| 2 K | Sabber der Wiederkehr (`skl_mop_revive`) | 7 (auf K.O.-Ziel) | 14 | 30 s | Zauber 3,0 s, Bewegung bricht | 2000 | K.O.-Verbündeter | Wiederbelebung 40 % + `sts_guard` 3 s | — | ja | gross | Sabbertropfen mit Heiligenschein |
| 2 V | Massen-Schlabbern (`skl_mop_mass_lick`) | 6 | 10 | 20 s | Zauber 2,0 s, Bewegung bricht | ganzes Set | alle Verbündeten | Heilung `mag` 60 + `sts_regen` 10 s, entfernt Gift | Heil-Bedrohung | ja | cute, gross | Zwei Zungen |
| 3 | Frostniesen (`skl_mop_frost_sneeze`) | 2 | 5 | 6 s | sofort | 1500 | Gegner | 105 magisch Eis, `sts_slow` 4 s (100 %) | × 1,0 | ja | gross | Mopsnase mit Eiskristall |
| 3 V | Königlicher Erlass (`skl_mop_royal_decree`) | 4 | 6 | 25 s | sofort | 2000 | Verbündeter (Smart: gesteuerte Figur, sonst Kai) | `sts_haste` 10 s | — | ja | — | Schriftrolle mit Siegel |
| 4 | Donnerbellen (`skl_mop_thunder_bark`) | 3 | 5 | 15 s | sofort | Radius 600 um Mopsula (+ Zielradius) | alle Gegner im Radius | 75 magisch Schock, **unterbricht alle** unterbrechbaren Zauber im Radius | × 1,0 | nein | flashy | Bellender Mops mit Blitz |
| 5 | **SHOW:** Auftritt Seiner Durchlaucht (`skl_stunt_mop_entrance`) | 1 | 0 | 30 s (Party) | Zauber 1,0 s, Bewegung bricht | Radius 800 um Mopsula (+ Zielradius) | alle Gegner im Radius | Erfolg (55 % + LCK × 1 %, max 85 %, Boss −15 %; Talent-Faktor §9.6): 140 magisch Feuer; Fehlschlag: Mopsula `sts_stun` 2 s | × 1,0 | ja | risky, flashy, cute | Mops mit Umhang im Scheinwerfer |
| 5 F | **FINALE:** Gräfliches Inferno (`skl_mop_inferno`) | 6, Ziel < 30 % HP | 12 | 30 s (Party, mit SHOW geteilt) | Zauber 2,0 s, Bewegung bricht | 2000, Radius 600 um das Ziel (+ Zielradius) | Gegner im Radius | 130 magisch Feuer + `sts_burn` 6 s (Kraft-Tick 20) | × 1,0 | ja | flashy, finisher | Monokel, in dem Flammen tanzen |
| 6 | Trank | — | — | 15 s (Party), ≤ 3 je Kampf | Trinkpause 0,5 s | — | Smart | §3.11 | — | nein | — | Flasche mit Pflaster |

Herkunft: Jede der 8 bisherigen Fähigkeiten pro Figur und jeder Stunt hat einen Platz (Kern, Variante, Kontext oder FINALE);
der Stunt ist die SHOW-Taste mit hohem Risiko und hohem Hype.

### 4.4 Smart-Zielwahl und Flächen

| Zielart (`target` in skills.json) | Echtzeit-Bedeutung |
|---|---|
| `single_enemy` | aktuelles feindliches Ziel; ohne Ziel: nächster Gegner im Bereich ±60° der Blickrichtung in Reichweite, sonst nächster in Reichweite (wird aktuelles Ziel, `TARGET_CHANGED`); keiner → `ACTION_REFUSED target`. FINALE zusätzlich: Ziel unter 30 % HP, sonst `target_hp` |
| `all_enemies` | alle Gegner in der Fläche `rt.aoe` (Radius 0 = ganzes Set) |
| `random_enemy` | zufälliger Gegner (Wurf §3.9.3) |
| `single_ally` | aktuelles freundliches Ziel; sonst Verbündeter mit dem kleinsten HP-Anteil (Gleichstand: gesteuerte Figur, dann Slot) |
| `all_allies` | alle lebenden Verbündeten in der Fläche (Radius 0 = ganzes Set) |
| `self` | Wirkende selbst |
| `single_ally_ko` | aktuelles freundliches K.O.-Ziel, sonst K.O.-Verbündeter mit dem kleinsten Slot |
| `none` | kein Ziel |

**Flächen der Party treffen Körper, nicht Mittelpunkte:** Ein Gegner ist in einer Party-Fläche, wenn sein Kreis sie berührt —
Kreis: Abstand ≤ Radius + Zielradius; Kegel: Abstand ≤ Länge + Zielradius und Mittelpunkt im Öffnungswinkel. (Kais Rundumfeger
mit 350 cm trifft so auch die Königin, deren Mitte 360 cm entfernt ist.) Gegnerische Telegraphen dagegen nutzen die
**Fußpunkt-Regel** (nur der Mittelpunkt der Party-Einheit zählt, §6.3) — „die Füße raus“ ist leichter zu lesen.

### 4.5 Verbrauchsgüter

Alle teilen die Abklingzeit der Party (15 s), höchstens 3 je Kampf, je 0,5 s Trinkpause, GCD-frei (§3.11).

| Gegenstand | Echtzeit-Wirkung | Ziel | Änderung ggü. CTB |
|---|---|---|---|
| `itm_bandage` Werbepflaster | Heilung fest 45 × 4 = 180 | Verbündeter | Skala |
| `itm_brutzel_burger` Brutzel-Burger | Heilung fest 120 × 4 = 480 | Verbündeter | Skala |
| `itm_antidote` Gegengift-Gurgler | entfernt Gift und Brand | Verbündeter | + `sts_burn` |
| `itm_energy_krawumm` KRAWUMM-Dose | +20 MP | Verbündeter | — |
| `itm_smelling_salts` Riechsalz | Wiederbelebung 30 % + `sts_guard` 3 s | K.O.-Verbündeter | + Comeback |
| `itm_molotov` Grillanzünder-Cocktail | fest 60 × 4 = 240 Feuer, Radius 400 um das Ziel (+ Zielradius) | Gegner | Fläche statt „alle“ |
| `itm_ice_spray` Kältespray | fest 90 × 4 = 360 Eis + `sts_slow` 4 s | Gegner | + Verlangsamt |
| `itm_smoke` Taschen-Nebelmaschine | sofortige Flucht (§2.5) | — | nicht im geschlossenen Set (`forbidden`) |
| `itm_hype_megaphone` Hype-Megafon | +25 Hype (Show) | — | — |
| `itm_elixir` Premium-Abo-Elixier | 100 % HP + 100 % MP | Verbündeter | — |

### 4.6 Datenschema: `skills.json` → `rt`

Optionaler Block je Skill. Pflicht für jeden Skill, der im Echtzeitkampf vorkommt (Party-Leiste, Auto-Angriffe, Gegner-`rt`,
`use_skill` kampftauglicher Gegenstände). Alle Zahlen sind Ganzzahlen.

| Feld | Typ | Standard | Bedeutung / Regel |
|---|---|---|---|
| `icon` | String | `""` | Symbol-Id der Aktionsleiste (`RtVocab.ICON_IDS`; Pflicht für Leisten-Skills und Statussymbole; R3 zeichnet jede Id) |
| `cast_ms` | int | 0 | Zauberzeit (0 = sofort); bei Telegraphen = Warnzeit (≥ 600) |
| `channel_ms` | int | 0 | Kanaldauer (0 = kein Kanal); Vielfaches von `period_ms` |
| `period_ms` | int | 0 | Kanal-/Zonen-Takt |
| `cooldown_ms` | int | 0 | Abklingzeit; SHOW/FINALE nutzen die Party-Abklingzeit `"show"` (Stunt-Kategorie oder `finale` in der Leiste) |
| `gcd` | bool | `true` | löst GCD aus / braucht freien GCD |
| `range_cm` | int | 0 | Reichweite (0 = selbst bzw. Auto-Reichweite) |
| `aoe` | Dictionary | `{}` | `{"center": "self"\|"target", "radius_cm": int, "cone_deg": int, "max_targets": int}` — Party-Flächen mit Zielradius (§4.4) |
| `moving_cancels` | bool | `true` bei `cast_ms`/`channel_ms` > 0 | Bewegung bricht (Schwelle §3.6.5) |
| `interrupt` | bool | `false` | unterbricht unterbrechbare Zauber der getroffenen Ziele |
| `interruptible` | bool | `true` | dieser Zauber/Kanal ist unterbrechbar (Gegner-Füller: `false`, §6.2) |
| `interrupt_worthy` | bool | `false` | nur Gegner: Unterbrechen lohnt sich — goldener Rand, Ton, KI-Ziel (§6.2); verlangt `interruptible` |
| `threat_pm` | int | 1000 | Bedrohungs-Faktor |
| `impact_ms` | int | nach `anim` (§3.6.7) | Wirkzeitpunkt sofortiger Aktionen (mindestens 1 Tick) |
| `power` | int | top-level `power` | Echtzeit-Kraft (überschreibt) |
| `mp` | int | top-level `mp_cost` | Echtzeit-Kosten (überschreibt) |
| `statuses` | Array | `[]` | `[{"id": String, "chance_pm": 1..1000, "ms": int (−1 = bis Kampfende), "to": "target"\|"self"\|"all_enemies"\|"all_allies", "tick_power": 0..100}]` (`target` = jede getroffene Einheit; `all_*` relativ zum Wirker, ganzes Set; `tick_power` > 0 macht einen periodischen Status zum Kraft-Tick, §3.8); ersetzt im Echtzeitkampf die CTB-`statuses` |
| `cleanse` | Array | top-level `cleanse` | zu entfernende Status-Ids |
| `telegraph` | Dictionary | `{}` | `{"shape": "circle"\|"cone"\|"ring"\|"line", "anchor": "self"\|"target_pos"\|"each_enemy"\|"random"\|"lane", "radius_cm", "inner_cm", "angle_deg", "length_cm", "width_cm", "count": 1..4, "lanes": [int, …]}` (§6.3) |
| `zone` | Dictionary | `{}` | `{"ms": int, "period_ms": int, "status": String, "skill": String}` (genau eins von `status`/`skill`) |
| `dash` | bool | `false` | Linien-Telegraph: Wirker springt beim Einschlag ans Linienende |
| `pct_maxhp` | int | 0 | Prozent-Treffer: Schaden in % der Max-HP des Ziels statt Formel (§3.9.1); **Pflicht für jeden gegnerischen Telegraphen** (10…40; Zug 35) und für schadende unterbrechenswerte Zauber ohne Telegraph |
| `ignore_guard` | bool | `false` | `sts_guard` wirkt nicht |
| `kill_adds` | bool | `false` | trifft auch die eigene Seite und setzt getroffene Beschwörungen sofort K.O. (Zug) |
| `fail_ms` | int | 0 | Stunt: Dauer der Selbst-Betäubung bei Fehlschlag (überschreibt `fail_effect.status`-Dauer) |

### 4.7 Datenschema: `statuses.json` → `rt`

| Feld | Typ | Standard | Regel |
|---|---|---|---|
| `default_ms` | int | 3000 | −1 = bis Kampfende, sonst ≥ 100, `% 100` |
| `period_ms` | int | 0 | 0 oder ≥ 500, `% 100` |
| `tick_pct` | int | 0 | −100…100 (negativ = Schaden, positiv = Heilung) je Periode und Stapel — für Status ohne Kraft-Tick |
| `tick_min` | int | 0 | 0…999, Mindestbetrag je Stapel |
| `tick_max` | int | 0 | 0…999, Höchstbetrag je Stapel (0 = ohne Deckel); Pflicht > 0 für schädliche `tick_pct` |
| `boss_tick_pm` | int | 1000 | 0…1000, Faktor auf periodische Wirkung an Bossen |
| `max_stacks` | int | 1 | 1…9 |
| `stack_mode` | String | `"replace"` | `replace` \| `refresh` \| `ignore` |
| `move_pm`, `haste_pm`, `dmg_dealt_pm`, `dmg_taken_pm` | int | 1000 | 0…5000 |
| `boss_ms_pm` | int | 1000 | 0…1000 (Dauerfaktor auf Bossen) |
| `flags` | Array | `[]` | ⊆ `RT_STATUS_FLAGS` (`no_act`, `no_move`, `no_cast`, `fixate`, `interrupt_on_apply`, `hidden`); bestehende `STATUS_FLAGS` gelten weiter (`guard`) |

### 4.8 Datenschema: `party.json` → `rt` und `items.json` → `rt`

```json
"rt": {
  "radius_cm": 40, "move_cm_s": 550, "threat_pm": 1500,
  "auto_skill": "skl_attack_kai", "swing_ms": 2000, "reach_cm": 250,
  "mp_regen": {"mode": "hit", "amount": 1, "taken": 1, "taken_every_ms": 1000},
  "keep_cm": {"attack": 0, "support": 0, "careful": 0}, "follow_cm": 600,
  "partner_special": "skl_kai_taunt",
  "bar": [
    {"slot": 1, "skill": "skl_kai_heavy_swing", "level": 1},
    {"slot": 2, "skill": "skl_kai_taunt", "level": 2},
    {"slot": 2, "skill": "skl_kai_first_aid", "level": 4, "variant": true},
    {"slot": 3, "skill": "skl_kai_leash_trip", "level": 3},
    {"slot": 3, "skill": "skl_kai_cable_whip", "level": 7, "variant": true},
    {"slot": 4, "skill": "skl_kai_sweep", "level": 4},
    {"slot": 4, "skill": "skl_kai_deo_torch", "level": 6, "variant": true},
    {"slot": 5, "skill": "skl_stunt_kai_suplex", "level": 1},
    {"slot": 5, "skill": "skl_kai_prime_finisher", "level": 6, "finale": true}
  ],
  "context": [],
  "presets": {"attack": [], "support": [], "careful": []},
  "default_preset": "attack",
  "assist_preset": "attack"
}
```

Mopsula: `radius_cm` 35 (Kapsel 0,35 m, 06 §1.2), `move_cm_s` 550 (beide laufen gleich schnell, 06 §1.2), `threat_pm` 1000,
`auto_skill` `skl_rt_auto_mopsula`, `swing_ms` 2400, `reach_cm` 1000, `mp_regen` `{"mode": "time", "amount": 1, "every_ms":
1500}`, `keep_cm` `{"attack": 450, "support": 600, "careful": 700}` (bevorzugter Abstand zum Ziel je Taktik, höchstens 700 —
im 4,8-m-Set erreichbar), `follow_cm` 700, `partner_special` `skl_mop_holy_lick`, `bar` nach §4.3 (FINALE `level` 6),
`context` `[{"slot": 2, "skill": "skl_mop_revive", "when": "target_ko", "level": 7}]`, `default_preset` `support`,
`assist_preset` `support`. Die Regel-Listen der Presets stehen in §5.4.

`items.json` → `rt` (optional): `{"wheel": int}` = Sortierung im Gegenstandsrad (0…99, Standard: Datenreihenfolge).
Kampftaugliche Gegenstände (`usable` `battle`/`both`) brauchen einen `use_skill` mit `rt`-Block.

### 4.9 Datenschema: `enemies.json` → `rt` und `floors.json` → `encounters[].rt`

```json
"rt": {
  "hp": 0, "hp_pm": 7000,
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

- `hp` > 0 setzt die Echtzeit-Max-HP absolut (Pflicht für Bosse), sonst `stats.hp × hp_pm / 1000` (`hp_pm` fehlt → `ENEMY_HP_PM`).
- `auto_target` ∈ `RT_TARGETS` (Standard `threat_top`; Taubenschwarm `lowest_hp_pct_enemy` — die Tauben ignorieren Bedrohung).
- `dmg_pm` wirkt nur auf Formel-Treffer des Gegners (nicht auf Prozent-Treffer und Status-Takte, §3.9.1).
- Regel (`RtRule`, §6.2): `{"skill", "target", "cond": {…}, "first_ms", "every_ms", "once": bool, "filler": bool, "then":
  {"skill", "delay_ms"}}`.
- Phase: `{"hp_above_pm": int, "on_enter": [Op, …], "rules": [RtRule, …]}`; Ops (`RT_PHASE_OPS`): `say {"tag"}`,
  `status_self {"status", "ms"}`, `summon {"enemy", "count", "at": "door"|"near"}`, `fixed_damage_self {"pct_pm"}`,
  `set {"stationary": bool}`, `clear_zones {}`, `telegraph {"skill"}`.
- `enrage`: `{"at_ms": int, "every_ms": int, "status": "sts_enrage"}`.
- `floors.json` → `encounters[].rt` (optional): `{"enemies": [ids], "music": String, "tutorial": [Schritte]}` überschreibt im
  Echtzeitkampf die Gegnerliste und setzt die Tutorial-Schritte (Tutorial: `["enm_kanalratte_azubi", "enm_kanalratte_azubi"]`,
  `["target", "bar1", "show", "dodge"]`, §2.13).

### 4.10 Validator-Regeln (`core/data/validators/rt.gd`, Vokabulare `rt_vocab.gd`)

06 hat den Validator je Tabelle aufgeteilt (`core/data/validators/*.gd`, `data_validator.gd` danach eingefroren). Der
Echtzeitkampf folgt dem: **R1a** legt `core/data/validators/rt_vocab.gd` (`RtVocab`, alle Vokabulare und `ICON_IDS` als Konstanten
— R1 braucht sie in `RtCommand`/`RtMods`, R3 für Symbole, R4 für Daten) und `core/data/validators/rt.gd` (statisch, ohne
`class_name`, wie `validators/talents.gd`: `check(v: DataValidator) -> void`, im Stub leer) an und fügt in `data_validator.gd`
genau **eine** Hook-Zeile ein; **R4** füllt `rt.gd` mit den Regeln unten. Außerdem trägt R1a in `data_validator.gd` das Tag-Präfix
`rt_`, die neuen Payload-Schlüssel und StatIds ein (Konstanten, §9.4) — danach ändert niemand die Datei.

Vokabulare (`RtVocab`, verbindlich): `RT_TARGETS`, `RT_CONDITIONS` (§5.3), `RT_PHASE_OPS`, `TELEGRAPH_SHAPES` (`circle`, `cone`,
`ring`, `line`), `TELEGRAPH_ANCHORS` (`self`, `target_pos`, `each_enemy`, `random`, `lane`), `AOE_CENTERS` (`self`, `target`),
`STATUS_TO` (`target`, `self`, `all_enemies`, `all_allies`), `STACK_MODES`, `RT_STATUS_FLAGS`, `RT_PRESETS` (`attack`, `support`,
`careful`), `RT_TOGGLES` (`interrupt`, `show`, `potions`), `MP_REGEN_MODES` (`hit`, `time`), `RT_ITEM_KINDS` (`heal`, `revive`,
`mp`, `cure`), `SUMMON_AT` (`door`, `near`), `TUTORIAL_STEPS` (`target`, `bar1`, `show`, `dodge`), `HINT_IDS` (§2.13),
`MOD_OPS` (§9.5), `ICON_IDS`.

| Nr. | Regel |
|---|---|
| V1 | Jede Zahl in einem `rt`-Block und in `rt_balance.json` ist ganzzahlig (JSON-Zahl ohne Nachkommaanteil). |
| V2 | Alle `*_ms`-Felder ≥ 0 und `% 100 == 0` (Ausnahme: −1 bei `default_ms`/`statuses[].ms`/`status_self.ms` = bis Kampfende). Alle `move_cm_s` `% 30 == 0`. |
| V3 | Wertebereiche: `cast_ms` ≤ 5000, `channel_ms` ≤ 5000 und `% period_ms == 0`, `cooldown_ms` ≤ 120000, `impact_ms` ≤ 1500, `range_cm` ≤ 3000, `aoe.radius_cm` ≤ 1600, `aoe.cone_deg` ≤ 180, `max_targets` ≤ 8, `threat_pm` ≤ 10000, `power` ≤ 500, `mp` ≤ 99, `pct_maxhp` ≤ 100, `statuses[].tick_power` ≤ 100. |
| V4 | Referenzen: `statuses[].id`, `cleanse[]`, `zone.status`, `immune[]`, `enrage.status`, `status_self.status` sind Status-Ids; `zone.skill`, `auto_skill`, `auto_ranged_skill`, Regel-`skill`, `then.skill`, `telegraph`-Op-`skill`, Leisten-/Kontext-Skills, `partner_special` sind Skill-Ids mit `rt`-Block; `summon.enemy` ist eine Gegner-Id mit `rt`; `icon` ∈ `ICON_IDS`. |
| V5 | Telegraph: Form/Anker aus den Vokabularen; Geometrie vollständig (Kreis: `radius_cm`; Kegel: `radius_cm`, `angle_deg` 1…180; Ring: `radius_cm` > `inner_cm` ≥ 0; Linie: `length_cm`, `width_cm`); `count` 1…4; `lanes` nur bei `lane`; `cast_ms` ≥ 600; nur Skills mit `user` `enemy`/`any`; **`pct_maxhp` 10…40**. |
| V6 | Zone: `ms` 1000…30000, `period_ms` 500…5000, genau eins von `status`/`skill`. |
| V7 | Status-`rt`: Bereiche §4.7; `flags` ⊆ `RT_STATUS_FLAGS` ∪ `STATUS_FLAGS`; schädliches `tick_pct` (< 0) braucht `tick_max` > 0. |
| V8 | Party-`rt`: alle Felder vorhanden; `bar` hat Slot 1 und Slot 5 mit `level` 1; jeder Slot 1…5 hat höchstens eine Grundfähigkeit (ohne `variant`/`finale`); `finale` nur in Slot 5; Skills haben `user` `party`; `presets` hat genau `attack`, `support`, `careful`; `default_preset`/`assist_preset` ∈ `RT_PRESETS`; `keep_cm`-Werte 0…700; `partner_special` ist eine Leisten-Fähigkeit dieser Figur. |
| V9 | Regeln: `target` ∈ `RT_TARGETS`; `cond`-Schlüssel ∈ `RT_CONDITIONS` mit Werttypen nach §5.3; Party-Regeln referenzieren nur Skills ihrer Leiste/Kontexte oder `item` ∈ `RT_ITEM_KINDS`; Gegner-Regeln `every_ms` ≥ 1000. |
| V10 | Gegner-`rt`: Pflicht für jeden Gegner in einer Begegnung einer Etage mit `playable: true`; Bosse brauchen `hp` > 0 und `phases`; Phasen streng absteigend nach `hp_above_pm` (1…999), letzte Phase `hp_above_pm` 0; `swing_ms` 1000…5000 bei gesetztem `auto_skill`; `reach_cm` 100…600; `radius_cm` 20…150; `dmg_pm` 100…5000. |
| V11 | `encounters[].rt.enemies`: 1…4 Gegner-Ids mit `rt`; `tutorial` ⊆ `TUTORIAL_STEPS`. |
| V12 | Kampftaugliche Gegenstände haben einen `use_skill` mit `rt`. |
| V13 | Unterbrechen: `interrupt_worthy` nur mit `interruptible: true`; Gegner-Regeln mit `cast_ms` > 0, ohne Telegraph und `every_ms` ≤ 4000 (Füller) haben `interruptible: false`. |
| V14 | `rt_balance.json`: genau die Schlüssel von `RtBalance`, jeder Wert im Bereich von `RtBalance`, `TICKS_PER_SEC` = 30. |

### 4.11 Migration der bestehenden Daten

| Bestehend (CTB) | Echtzeit | Ab R5b (CTB entfernt) |
|---|---|---|
| `skills[].rank` | ignoriert (Taktung über `rt`) | gelöscht |
| `skills[].statuses[].turns`, `chance` (Kommazahl) | `rt.statuses[].ms`, `chance_pm` (Tabellen §4.2/4.3, §6) | `rt.statuses` ersetzt `statuses` |
| `skills[].cooldown` (Stunt, Züge) | Party-Abklingzeit `SHOW_CD_TICKS` | gelöscht |
| `skills[].power`, `mp_cost` | gelten, solange `rt.power`/`rt.mp` fehlen | `rt`-Werte gebacken |
| `skills[].target` | Bedeutung nach §4.4 | bleibt |
| `skills[].fail_effect.delay_pct` | ignoriert | gelöscht |
| `statuses[].default_turns`, `tick_timing`, `tick_speed_mult`, Flag `delay_on_apply` | ignoriert | gelöscht |
| `statuses[].tick_pct` (CTB: Gift −8 % je Zug) | `rt.tick_pct` (−2 % je 2 s) + `rt.tick_max` | `rt` gebacken |
| `enemies[].ai` (`weighted`/`phased`), `phases[].actions`, Gewichte | ignoriert; `rt.rules`/`rt.phases` | gelöscht |
| `enemies.pseudo_units` (Zug) | ignoriert; Zug = `skl_q_train` | gelöscht |
| `party[].learnset` | ignoriert; `rt.bar` | gelöscht (Fähigkeiten-Menü liest `rt.bar`) |
| `party[].base_stats.hp`, `growth.hp`; feste Heilungen/Schäden; `enemies[].stats.hp` | Laufzeit-Skala × 4 bzw. × 7 (§3.9.4) | in die Daten gebacken, Skala-Code entfernt |
| `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN` | ungenutzt | gelöscht |

Neue Einträge (R4): Skills `skl_rt_auto_mopsula`, `skl_e_azubi_hop`, `skl_q_train`, `skl_q_spit`, `skl_q_puddles`,
`skl_e_showboss_slow` (Show-Boss, §9.6); Status `sts_taunted`, `sts_dazed`, `sts_regen`, `sts_burn`, `sts_admonished`, `sts_dizzy`,
`sts_enrage`; Gegner `enm_kanalratte_azubi`; `data/rt_balance.json`; M.O.D.-Tags (§9.3). Entfallen gegenüber dem ersten Entwurf:
`skl_e_throw` (Unerreichbar-Regel, §3.5.3) und `skl_tw_rat_rain` (keine Twists im Kampf, §9.5).

---

## 5. Partner-KI

### 5.1 Steuerung: Held:in, Partner-Spezial, Steuerung folgt dem Leben, Autopilot

- **Man steuert die gewählte Figur** (06 §1): `RtSetup.controlled_id` = Einheit von `GameState.hero` (`"kai"` oder
  `"mopsula"`; `BattleBridge.make_rt_setup` bildet die Mitglieds-Id auf `p<battle_slot>` ab). Die gesteuerte Einheit hat
  `driver = PLAYER` (Bewegung aus Proben, Fähigkeiten aus Befehlen), die andere `AI`.
- **Der Partner ist immer KI** mit Taktik und Schaltern (§5.2) — und **einer** direkten Anordnung: **Partner-Spezial** (Taste
  `R`, Gamepad Steuerkreuz links, Touch-Knopf neben dem Party-Rahmen). Sie befiehlt sofort die Signatur des Partners mit deren
  normaler Abklingzeit (Kai: „Hier spielt die Musik!“ — Spott, ab Stufe 2; Mopsula: „Heiliges Schlabbern“ — Heilung auf das
  Smart-Ziel, ab Stufe 1), §3.6.13. Einfach, lesbar, und man hat den Partner im entscheidenden Moment in der Hand. Die so
  ausgelöste Aktion zählt als Aktion der Person (`by_ai = false`, §9.1).
- 06 „Partner automatisch“ (`GameSettings.partner_auto`) betrifft nur den CTB-Modus; im Echtzeitkampf ist der Partner immer KI.
  Die Optionszeile wird im Echtzeitmodus ausgeblendet und entfällt mit R5b (06 §1.4 wird dann nachgezogen, §12.8).
- **Steuerung folgt dem Leben** (§2.6): K.O. der gesteuerten Einheit → die erste lebende KI-Einheit wird `PLAYER`
  (`CONTROL_CHANGED`), vorübergehend und nur für diesen Kampf. Ab da kommen Proben und Befehle für die neue Einheit; der
  `CombatDirector` tauscht die Körperrollen in der Szene und stellt sie am Kampfende über `ExplorationScene.refresh_hero()` (06 A)
  zurück. `GameState.hero` bleibt unverändert.
- **Autopilot** (Taste `toggle_auto`, Befehl `autopilot`): die gesteuerte Einheit wird `AUTOPILOT` und von der Sim mit ihrer
  Taktik gespielt (Bewegung, Fähigkeiten, Ausweichen). Proben werden ignoriert; die Szene zeigt die Sim-Position (Körper folgt
  der Sim wie eine Puppe). Für Barrierefreiheit, Bots und Captures. Beim Abschalten steht der Körper genau an der Sim-Position;
  ab dem nächsten Tick gelten wieder Proben (normale Prüfung, §3.5.2). Autopilot-Aktionen tragen `by_ai = true`.
- Das **FINALE** nutzt die KI nie („Das Finale gehört dem Publikum — und dir.“).

### 5.2 Taktiken (Presets) und Schalter

| Taktik (`preset`) | UI-Name | Ausweich-Reaktion | Abstand Mopsula | Heil-Schwelle (Mopsula) | Tränke | SHOW |
|---|---|---|---|---|---|---|
| `attack` | Angriff | 18 Ticks (0,6 s) | 450 cm | Verbündeter < 35 % | nur mit Schalter | ja (Schalter) |
| `support` | Unterstützen | 12 Ticks (0,4 s) | 600 cm | Verbündeter < 60 % | nur mit Schalter (eigene HP < 35 %) | ja, sparsam |
| `careful` | Vorsichtig | 6 Ticks (0,2 s) | 700 cm | Verbündeter < 75 % | **immer** (eigene HP < 50 %) | nein |

| Schalter (`tog`) | Standard | Wirkung |
|---|---|---|
| `interrupt` Unterbrechen | an | Regeln mit `cond.toggle == "interrupt"` aktiv (Fallstrick, Kabelpeitsche, Donnerbellen auf **unterbrechenswerte** Zauber, §6.2); Füller halten die Reserve (§5.3) |
| `show` Show-Einlagen | an | SHOW-Regeln aktiv — die KI zündet ihre SHOW erst, wenn die Party-SHOW 5 s bereitliegt (§4.1) |
| `potions` Tränke | **aus** | Gegenstands-Regeln in „Angriff“/„Unterstützen“ aktiv; „Vorsichtig“ nutzt Tränke immer. Nie den letzten Gegenstand einer Art, höchstens 3 je Kampf (Party) |

Standard: Kai als Partner `attack`, Mopsula als Partner `support` (`party.json` `rt.default_preset`). Die Wahl wird je Mitglied
gespeichert (`PartyMember.rt_preset`, `rt_toggles`) und im Kampf mit dem Befehl `partner_preset` geändert (§7: Taste `G`,
Steuerkreuz rechts, Antippen des Taktik-Chips). Der Taktik-Chip erscheint im HUD erst nach dem ersten Safe-Room-Besuch (§8.1);
bis dahin gilt der Standard.

### 5.3 Regel-Engine `RtRules` (gemeinsam für Partner-KI, Autopilot, Assist und Gegner-KI)

Regel (`RtRule`, JSON in `party.json` → `rt.presets` bzw. `enemies.json` → `rt.rules`/`phases[].rules`):

```json
{"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle": "interrupt"},
 "first_ms": 0, "every_ms": 0, "once": false, "filler": false, "then": {}}
```

oder für Gegenstände (nur Party): `{"item": "heal"|"revive"|"mp"|"cure", "target": …, "cond": {…}}` — die Sim wählt den
Gegenstand wie die Trank-Taste (§3.11; `revive` → Riechsalz, `mp` → KRAWUMM-Dose, `cure` → Gegengift).

`RtRules.choose(sim, u)` ist **rein** (kein Wurf, kein Schreibzugriff): Sie liefert die gewählte Aktion, die Sim wendet sie in
Schritt 7 an (§3.3). Zufällige Ziele würfelt erst die Anwendung. Auswertung für jede sim-gesteuerte Einheit, die handeln darf
(lebt, kein `no_act`, kein laufender Zauber, keine Trinkpause, `pop_in_until ≤ c`, kein `entry`):

1. Regeln der aktuellen Phase (Gegner) bzw. der Taktik (Party) in Listenreihenfolge.
2. Überspringen, wenn: Regel-Timer nicht bereit (`rule_ready[key] > c`; Schlüssel `"<phase>:<index>"` bzw.
   `"<preset>:<index>"`), `once` schon benutzt, eine Bedingung falsch, Schalter aus, Fähigkeit nicht nutzbar (`can_use`:
   Abklingzeit, GCD bei GCD-Fähigkeiten, MP, Sperre, kein gültiges Ziel).
3. **Feste Regeln der Engine** (nicht abschaltbar): `filler: true` feuert bei KI-Einheiten nur, wenn danach noch die MP des eigenen
   Unterbrechers übrig sind (gelernt und Schalter `interrupt` an); SHOW-Regeln der Party erst nach `AI_SHOW_GRACE_TICKS`
   Bereitschaft der Party-SHOW; Gegenstandsregeln nie für den letzten Gegenstand einer Art und nur innerhalb der Party-Grenzen
   (§3.11); FINALE nie.
4. Scheitert eine Regel **nur** an der Reichweite, setzt sie (falls noch keins gesetzt) das Bewegungsziel zum Regelziel; die
   Auswertung geht weiter (spätere Regeln dürfen aus der aktuellen Position feuern).
5. Die erste nutzbare Regel feuert: Fähigkeit starten; `rule_ready[key] = c + every_ticks`; `then` reiht die Folgefähigkeit für
   `c + delay` ein (ohne Bedingungen, nur Nutzbarkeit).
6. Feuert keine Regel: Auto-Angriff auf das Ziel (Party: `assist`; Gegner: `threat_top`), Bewegungsziel nach §3.5.3.

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
| `enemies_in_radius` | `{"r_cm": int, "min": int}` | mindestens `min` lebende Gegner im Radius um die Einheit (Kreis + Zielradius) |
| `enemy_on_ally` | bool | ein Gegner, nicht auf die Einheit fixiert, greift einen anderen Verbündeten an |
| `caster_within_cm` | int | ein Gegner wirkt einen **unterbrechenswerten** Zauber (`interrupt_worthy`) innerhalb des Radius |
| `target_casting` | bool | das Regelziel wirkt einen unterbrechenswerten Zauber |
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
| `random_enemy` | zufälliger lebender Gegner (Wurf §3.9.3 bei der Anwendung) |
| `nearest_enemy` / `farthest_enemy` | nach Abstand, Gleichstand kleinere Nummer |
| `lowest_hp_pct_enemy` / `lowest_hp_pct_ally` | kleinster HP-Anteil, Gleichstand Slot/Nummer (Verbündete: gesteuerte Figur zuerst) |
| `ko_ally` | K.O.-Verbündeter mit kleinstem Slot |
| `controlled` | die gesteuerte Figur |
| `caster` | Gegner mit **unterbrechenswertem** Zauber in Reichweite der Fähigkeit, kürzeste Restzeit zuerst (Füller zählen nie) |
| `none` | ohne Ziel |

KI-gesteuerte Party-Einheiten (KI-Partner, Autopilot) sehen einen unterbrechenswerten Zauber (für `caster`, `caster_within_cm`,
`target_casting`) erst, wenn er seit `AI_INTERRUPT_REACT_TICKS` Ticks läuft (Startwert 0; Stellschraube gegen eine zu perfekte
Partner-KI, §11.3).

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
  {"skill": "skl_kai_heavy_swing", "target": "assist", "filler": true}
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
  {"skill": "skl_kai_heavy_swing", "target": "assist", "filler": true}
],
"careful": [
  {"item": "heal", "target": "self", "cond": {"self_hp_below_pm": 500}},
  {"item": "revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"skill": "skl_kai_leash_trip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_cable_whip", "target": "caster", "cond": {"toggle": "interrupt"}},
  {"skill": "skl_kai_taunt", "target": "self", "cond": {"enemy_on_ally": true, "ally_hp_below_pm": 500}},
  {"skill": "skl_kai_first_aid", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 600}},
  {"skill": "skl_kai_heavy_swing", "target": "assist", "filler": true}
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
  {"skill": "skl_mop_frost_sneeze", "target": "assist", "filler": true},
  {"skill": "skl_mop_noble_flame", "target": "assist", "filler": true, "cond": {"self_mp_above_pm": 500}}
],
"attack": [
  {"skill": "skl_mop_revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"skill": "skl_mop_holy_lick", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 350}},
  {"skill": "skl_mop_thunder_bark", "target": "self", "cond": {"toggle": "interrupt", "caster_within_cm": 600}},
  {"skill": "skl_stunt_mop_entrance", "target": "self", "cond": {"toggle": "show", "enemies_in_radius": {"r_cm": 800, "min": 2}}},
  {"skill": "skl_mop_frost_sneeze", "target": "assist", "filler": true},
  {"skill": "skl_mop_noble_flame", "target": "assist", "filler": true}
],
"careful": [
  {"skill": "skl_mop_revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"item": "revive", "target": "ko_ally", "cond": {"ally_ko": true}},
  {"skill": "skl_mop_holy_lick", "target": "lowest_hp_pct_ally", "cond": {"ally_hp_below_pm": 750}},
  {"item": "heal", "target": "self", "cond": {"self_hp_below_pm": 500}},
  {"skill": "skl_mop_thunder_bark", "target": "self", "cond": {"toggle": "interrupt", "caster_within_cm": 600}},
  {"skill": "skl_mop_noble_flame", "target": "assist", "filler": true, "cond": {"self_mp_above_pm": 700}}
]
```

Regeln für nicht ausgerüstete Varianten sind einfach nicht nutzbar und werden übersprungen. Heilungen sind keine Füller: Sie
dürfen die Unterbrecher-Reserve aufbrauchen.

### 5.5 Bewegung und Ausweichen der KI

- **Ausweichen:** Beginnt ein gegnerischer Telegraph (`TELEGRAPH_START`), dessen Form die Einheit (mit `ESCAPE_MARGIN_CM = 60`
  aufgeblasen) enthält, setzt sie `react_at = start + REACT_TICKS[preset]`. Ab `react_at` ist ihr Bewegungsziel
  `RtGeo.escape_point(sim, unit)`: Kandidaten = 16 Richtungen (`yaw = k × 16`) × Abstände 100/200/300/450/600 cm; der erste
  Kandidat (sortiert nach Abstand, dann nach Winkelnähe zur bevorzugten Richtung — Nahkampf: zum Ziel, Fernkampf: weg vom
  nächsten Gegner —, dann `k`), der begehbar ist (im Ring, nicht in einer Sperrfläche) und außerhalb aller aufgeblasenen
  gegnerischen Formen liegt, die in den nächsten 60 Ticks einschlagen, und außerhalb aller Zonen. Kein Kandidat → stehen bleiben.
  Läuft ein eigener Zauber mit `moving_cancels` und endet er nicht vor dem Einschlag minus Laufzeit, bricht die KI ihn ab
  (`CAST_FAILED moved`).
- **Zonen** meidet die KI immer (Bewegungsziele in Zonen werden auf `escape_point` umgelenkt).
- **Abstand:** Mopsula hält `keep_cm[preset]` (≤ 700) zum Ziel, so weit der Ring es zulässt, und bleibt ≤ `follow_cm` von der
  gesteuerten Figur, wenn kein Ziel besteht; Kai geht in Nahkampf. Verlässt die gesteuerte Figur den Ring, folgt der Partner
  (Flucht, §2.5).
- Der Autopilot nutzt dieselben Regeln (Taktik der gesteuerten Figur, Reaktion nach Taktik).

### 5.6 Assist-Modus

`GameSettings.combat_assist` (Standard: an bei Touch, aus sonst). Das HUD fragt pro Frame `RtSim.suggest(controlled_id)`: erste
Regel der `assist_preset`-Liste, die für die gesteuerte Einheit jetzt nutzbar wäre (ohne Gegenstände, ohne Bewegung, ohne
KI-Reserve). Der vorgeschlagene Slot pulsiert mit goldenem Ring (§8.2). Assist führt nichts aus; er ist reine Anzeige (kein
Befehl, nicht im Log) und rein (§3.4).

### 5.7 Bot-Profile (nur Balancing-Harness und Full-Run-Bot)

Der `RtBotPlayer` (`tests/tools/rt_bot_player.gd`, R4) spielt die gesteuerte Figur **über echte Befehle** (Proben, Fähigkeiten,
Ziele, Partner-Spezial), damit der Harness den Live-Pfad prüft. Entscheidungen wie der Assist (Regeln `assist_preset`), plus
Fehlerprofil mit eigenem Zufallsstrom `SeedUtil.derive(seed, "bot", n)`:

| Profil | Reaktion auf Telegraphen | Verpasst Ausweichen | Unterbricht unterbrechenswerte Zauber | GCDs genutzt | Trank unter | SHOW |
|---|---|---|---|---|---|---|
| `perfect` | 0 Ticks | 0 % | 100 % | 95 % | 35 % | ja |
| `typical` | 9 Ticks | 15 % | 70 % | 75 % | 35 % | ja |
| `sloppy` | 18 Ticks | 40 % | 30 % | 55 % | 20 % | nein |

`typical` ist ein Startwert. R5b **kalibriert** ihn an aufgezeichneten Probespiel-Läufen (Run-Logs echter Erstspieler:innen, §11.4):
Ausweichquote, Unterbrechungsquote, genutzte GCDs und Trank-Schwelle werden aus den Logs gemessen und als neue Profilwerte
eingetragen. Der Full-Run-Bot (`scenes/boot/fullrun.gd`) nutzt im Echtzeitkampf den **Autopilot** (schnell, robust); die
Bossverlust-Quoten misst der Harness mit `typical` für **beide** Held:innen (`--hero=kai|mopsula`, §11.4).

---

## 6. Gegner-KI und Bosse

### 6.1 Ablauf eines Gegners

| Phase | Verhalten |
|---|---|
| Erkundung | Unverändert: IDLE/PATROL (1,8 m/s), ALERT 0,6 s, CHASE (`field_speed`), RETURN (3 m/s, ignoriert die Figur 2 s), `DAZED` nach Bellen (06 §1.3); Sicht 10 m/110° (Tauben 14 m), Hören 4,0/1,5 m; Aufgabe nach 4 s ohne Sicht / 20 m Leine / 8 s Verfolgung. Neu: Kampfbeginn nur per Pull, Waffenreichweite des Anführers oder 4 s Verfolgung im selben Raum (§2.2); Kontakt bei 1,1 m entfällt; Treppenräume betreten Gegner nicht. |
| Kampfstart | Puppe der Sim (keine Physik); Anführer außerhalb des Rings laufen herein (Auftritt), Komparsen springen ins Bild; Bedrohung 1 auf dem Auslöser. |
| Kampf | Regeln (§5.3), Auto-Angriff auf `threat_top`, Bewegung im Ring (§3.5.3). Betritt nie eine Türgasse. |
| Flucht der Party | Rücksetzen: volle HP, Status weg, zurück zur Startposition, Erkundung `RETURN`. |
| Niederlage des Gegners | K.O.-Animation (`die`), Auflösen (`set_dissolve`), Gruppe gilt als besiegt, wenn alle Mitglieder fielen. |

### 6.2 Zielwahl, Fähigkeiten, Zauberleisten, Unterbrechen

- Ziel = `rt.auto_target` (Standard `threat_top`, §3.7), Fixierung durch Spott hat immer Vorrang. Regeln mit eigenem Ziel (z. B.
  `lowest_hp_pct_enemy`) gelten nur für diese Fähigkeit; das Auto-Ziel bleibt.
- Auto-Angriff: `auto_skill` mit `swing_ms`, `reach_cm`. Ist das Ziel außer Reichweite und `auto_ranged_skill` gesetzt, schwingt
  der Gegner stattdessen diesen Fernangriff (Reichweite aus dessen `range_cm`). `stationary` → bewegt sich nie.
- Jede Fähigkeit mit `cast_ms > 0` zeigt eine **Zauberleiste** mit Namen über dem Gegner, im Zielrahmen und (Boss) im Bossrahmen.
  Drei Stufen, auf einen Blick lesbar:

| Zauber | Rand der Zauberleiste | Ton | KI-Partner |
|---|---|---|---|
| **unterbrechenswert** (`interruptible` + `interrupt_worthy`): Heilungen, Beschwörungen, Schutzschilde, Boss-Großzauber | **Gold** + Funkeln | „Ding“ | unterbricht (Schalter `interrupt`) |
| unterbrechbar, aber nicht lohnend (selten, z. B. Giftspritzer des Schleims) | weiß | — | ignoriert ihn |
| nicht unterbrechbar (Füller wie Funkenrute/Farbflamme, Telegraph-Aufladungen) | grau + Schloss-Symbol | — | ignoriert ihn |

- **Füller** (Zauber, die ein Gegner alle ≤ 4 s als Hauptangriff wirkt) sind nie unterbrechbar (Validator V13) — so verpufft kein
  Unterbrecher am Dauerfeuer, und der goldene Rand bedeutet immer „jetzt!“.
- Unterbrechen: §3.6.8. Unterbrochene Regeln warten `every_ms` (der Gegner versucht es später erneut).

### 6.3 Telegraphen und Zonen

| Form | Parameter | Treffertest (Mittelpunkt der Party-Einheit, „Fußpunkt-Regel“; nur im Ring) |
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
| `random` | `count` gewürfelte Punkte im Ring (Abstand zur Mitte ≤ `geo.r` − 60 cm), Mindestabstand 300 cm (bis 8 Würfe je Punkt, sonst weglassen) |
| `lane` | Linie quer durch das Set entlang der x-Achse (Sehne des Rings, Länge 2 × `geo.r`), Versatz in z aus `lanes`, abwechselnd beginnend mit dem ersten Eintrag |

- **Schaden:** Jeder gegnerische Telegraph trifft als **Prozent-Treffer** (`rt.pct_maxhp`, §3.9.1): **15–30 % der Max-HP** des
  Getroffenen (leicht 15, mittel 20, schwer 25–30; der Zug 35). Zwei Fehler tun weh, einer ist verkraftbar — Ausweichen lohnt sich
  spürbar, und die Zahl ist für jede Figur und Ausrüstung gleich lesbar. Auto-Angriffe bleiben klein (≈ 2–8 % je Treffer,
  Formel).
- **Warnzeit = Zauberzeit** (`cast_ms`; Vorabendprogramm × 1,25). Der Telegraph erscheint beim Zauberstart, schlägt beim
  Zauberende ein; Unterbrechen/K.O. des Wirkers entfernt ihn (`TELEGRAPH_CANCELLED`).
- **Nur im Ring:** Treffer und Darstellung enden am Ring (§3.5.4). Wer in einer Türgasse steht, wird nicht getroffen — flieht aber
  nach 2 s (§2.5).
- **Ausweichfenster** = die ganze Warnzeit; geprüft wird nur im Einschlag-Tick. Nach jedem Tick (Schritt 9) merkt sich der
  Telegraph für jede Einheit der getroffenen Seite den letzten Tick „drin“. Wer irgendwann drin war und beim Einschlag draußen ist,
  ist **ausgewichen** (`TELEGRAPH_DODGED`); `success = true` (knapp), wenn er ≤ `CLOSE_DODGE_TICKS = 9` vor dem Einschlag noch drin
  war.
- Wirkung beim Einschlag: die Fähigkeit trifft jede Einheit der Zielseite in der Form, danach optional Zone (`zone`) und Sprung des
  Wirkers (`dash`).
- **Zonen** liegen weiter (`zone.ms`) und wenden alle `period_ms` ihren Status/Skill auf Einheiten der Zielseite in der Fläche an
  (erster Takt eine Periode nach dem Einschlag).
- Höchstens `MAX_TELEGRAPHS = 10` gleichzeitig (Telegraphen + Zonen); darüber endet die älteste Zone vorzeitig.
- **Party-Flächen** (Fähigkeiten, Gegenstände) treffen Gegner mit Zielradius (§4.4), nicht nach der Fußpunkt-Regel.

### 6.4 Adds, Enrage, perfekte Phase

- Adds kommen über Regeln/Phasen-Ops `summon` (§3.12), standardmäßig an der nächsten Tür („durch die Tür gestürmt“, mit Auftritt).
- **Enrage** (`rt.enrage`): bei `at_ms` `ENRAGE`-Ereignis, M.O.D. `rt_enrage:<enemy_id>`, `sts_enrage` 1 Stapel; danach alle
  `every_ms` ein weiterer (× 1,5 Schaden je Stapel, Gesamtfaktor höchstens 8000 ‰, §3.9.1). Weich: Ein guter Kampf endet vorher
  (§11).
- **Perfekte Phase:** Trifft während einer Bossphase kein Telegraph-Einschlag ein Party-Mitglied, trägt der nächste
  `PHASE_CHANGE` (bzw. `BATTLE_END`) `success = true` → Hype +8 (§9.1). Zonen-Takte zählen nicht als Treffer.

### 6.5 Etage 1: reguläre Gegner

HP = CTB-HP × 7 (`ENEMY_HP_PM` 7000; Kanalschleim `rt.hp_pm` 4800, weil er physischen Schaden halbiert). Regeln: `first_ms` /
`every_ms`. Ziel ohne Angabe = `threat_top`. Telegraphen erben Element und Status ihres Skills, Schaden als Prozent-Treffer
(Spalte „Treffer“). (U) = unterbrechenswert (Gold-Rand, §6.2).

| Gegner (`id`) | HP | Radius / Tempo | Auto-Angriff | Signatur-Mechanik | Treffer / Status | Witz |
|---|---|---|---|---|---|---|
| Kanalratte (`enm_kanalratte`) | 168 | 30 / 360 | Biss `skl_e_bite`, 2,4 s, 220 | Seuchennagen `skl_e_gnaw_poison`: sofort, 3 s / 10 s | Formel 80 / Gift 50 %, 8 s | nagt am Sendekabel (Bild flackert kurz) |
| Kanalratte (Azubi) (**neu** `enm_kanalratte_azubi`, nur Tutorial) | 280 (`rt.hp`) | 30 / 300 | Biss, 2,8 s | Azubi-Sprung `skl_e_azubi_hop` (**neu**): Kreis r 200 am Ziel, Warnung 2,0 s, 6 s / 12 s | 15 % | trägt ein „Lehrling“-Schild; Tutorial-Schritt „Rote Fläche? Raus da!“ |
| Taubenschwarm (`enm_taubenschwarm`) | 140 | 40 / 450 | Picken `skl_e_peck`, 1,8 s, 220, Ziel `lowest_hp_pct_enemy` | Sturzflug-Bombardement `skl_e_dive_bomb`: Kreis r 250 am Regelziel `lowest_hp_pct_enemy` (`target_pos`), Warnung 1,2 s, 6 s / 12 s | 15 % | „Gurr-Formation!“ |
| Pendler (`enm_pendler`) | 336 | 40 / 240 | Aktentaschen-Hieb `skl_e_briefcase`, 2,8 s, 220 | Verspätungswut `skl_e_delay_rage`: Kegel 400 cm / 90° vor sich (`self`), Warnung 1,8 s, **nicht** unterbrechbar, 7 s / 10 s | 20 % | schaut beim Aufladen auf die Uhr: „Ich hab noch einen Anschluss!“ |
| Kanalschleim (`enm_kanalschleim`) | 192 | 45 / 180 | Klatscher `skl_e_slam`, 3,0 s, 220 | Giftspritzer `skl_e_toxic_splash`: Zauber 1,5 s, unterbrechbar (nicht lohnend), 1200 cm, Ziel `random_enemy` mit `target_no_status` Gift, 4 s / 9 s | Formel 90 / Gift 100 % | schluckt Schläge (physisch ×0,5, bestehend) |
| Rattenschamane (`enm_rattenschamane`) | 238 | 30 / 300, hält 600 | — (kein Nahkampf) | Funkenrute `skl_e_zap` als Hauptangriff (**Füller**, nicht unterbrechbar): Zauber 1,5 s, 1500 cm, 1 s / 3,5 s; (U) Rattensegen `skl_e_rat_heal`: Zauber 2,0 s, Ziel `lowest_hp_pct_ally`, `ally_hp_below_pm` 500, 5 s / 8 s | Formel 100 | „Heiler zuerst!“ (M.O.D. `rt_healer_first` beim ersten Segen); erster Kontext-Hinweis zum Unterbrechen (§2.13) |
| Kabelsalat (`enm_kabelsalat`) | 322 | 45 / 270 | Kabelhieb `skl_e_lash`, 2,6 s, 250 | Kurzschluss `skl_e_short_circuit`: Kreis r 500 um sich (`self`), Warnung 2,0 s, nicht unterbrechbar, 8 s / 12 s | 20 % | „Bitte nicht berühren“-Schild glüht |
| Kellerspinne (`enm_kellerspinne`) | 350 | 40 / 420 | Giftbiss `skl_e_venom_bite`, 2,0 s, 220 | Netzschuss `skl_e_web`: sofort, 1500 cm, `once`, 4 s, Ziel `farthest_enemy` | Biss: Gift 50 %; Netz: Verlangsamt 5 s | „Spinnt total“ |
| Sprühgeist (`enm_spruehgeist`) | 308 | 35 / 300, hält 600 | — | Farbflamme `skl_e_spray_flame` (**Füller**, nicht unterbrechbar): Zauber 1,5 s, 1500 cm, 1 s / 3,5 s; Lackdämpfe `skl_e_fumes`: Kreis r 300 am Ziel, Warnung 1,2 s, Zone 6 s (Gift alle 2 s), 6 s / 14 s | Formel 110; Dämpfe 15 % + Gift-Zone | hinterlässt Graffiti-Tags auf dem Boden |
| Rolltreppenkrabbe (`enm_rolltreppenkrabbe`) | 504 | 60 / 240 | Zwicken `skl_e_pinch`, 3,0 s, 250 | „Stufen fahren hoch“ `skl_e_brace` (selbst `sts_guard` 4 s), 5 s / 15 s, `then` nach 1,5 s Stufen-Stampfer `skl_e_step_crush`: Kreis r 300 um sich, Warnung 1,5 s | 25 % | Durchsage „Bitte rechts stehen, links gehen“ |
| Rattengardist (Elite) (`enm_rattengardist`) | 546 | 45 / 300 | Hellebarde `skl_e_halberd`, 2,6 s, 300 | (U) Schildwall `skl_e_shield_wall`: Zauber 2,0 s, `once` bei 3 s und `once` bei `self_hp_below_pm` 500, alle Verbündeten `sts_guard` 8 s; Ausfall `skl_e_lunge`: Linie 800 × 150 zum `lowest_hp_pct_enemy` (`self`), Warnung 1,0 s, `dash`, 6 s / 11 s | Ausfall 20 % | „Für die Krone!“ |
| Fahrscheinfresser (selten) (`enm_fahrscheinfresser`) | 420 | 50 / 0 (`stationary`) | Entwerter-Biss `skl_e_ticket_cut`, 2,4 s, 250 | (U) Erhöhtes Beförderungsentgelt `skl_e_fine`: Zauber 2,5 s, `once` bei 2 s (stiehlt bis 40 Cr, Erstattung bei Sieg); (U) Abfahrt! `skl_e_escape`: Zauber 3,0 s, 25 s / 10 s → entkommt mit Beute | — | „Fahrschein, bitte!“; jede Unterbrechung der Abfahrt kauft 10 s |

### 6.6 Boss: Der Hausmeister (`enm_boss_hausmeister`)

Stufe 6 (Zielstufe der Party 5), Echtzeit-HP **5 000** (Start), `dmg_pm` 1000, Set-Radius 600 (geschlossen), Radius 90 cm, Tempo
240 cm/s, Auto Besenhieb (`skl_b_broom`, 110) alle 2,8 s, Reichweite 320. Schwäche Schock, Gift ×0,5, Betäubung/Verlangsamt
50 % Widerstand (bestehend), immun gegen `sts_dazed`. Enrage „Feierabend ist Feierabend!“ bei 4:30, danach alle 30 s.

| Phase | HP | Beim Eintritt | Mechaniken (Zeiten ab Phasenbeginn: erste / Wiederholung) |
|---|---|---|---|
| P1 „Kehrwoche“ | > 60 % | Boss-Intro (§2.9) | (U) **Hausordnung verlesen** (`skl_b_rules`): Zauber 3,0 s, 8 s / 25 s. Nicht unterbrochen → Hausmeister `sts_guard` 12 s **und** ganze Party `sts_admonished` 12 s („Ermahnt: −20 % Schaden. Das kommt in die Akte.“). **Schlüsselbund-Wurf** (`skl_b_keys`): Linie vom Boss bis zum Ring (≤ 1200) × 150 zu `random_enemy`, Warnung 1,2 s, **20 %**, 5 s / 12 s. |
| P2 „Hausordnung § 7“ | 60–25 % | M.O.D. `boss_phase:enm_boss_hausmeister:2`, 1 Kanalratte durch die Tür | **Putzmittelnebel** (`skl_b_cleaner_fog`): je ein Kreis r 250 unter jedem Party-Mitglied (`each_enemy`, `count` 2), Warnung 1,0 s, **15 %**, danach Zone 12 s (Gift-Stapel alle 2 s), 4 s / 15 s. (U) **„Untermieter!“** (`skl_b_call_tenant`): Zauber 2,0 s, `adds_below` 2, 10 s / 20 s → 1 Kanalratte an der nächsten Tür. Schlüsselbund-Wurf weiter alle 12 s. |
| P3 „Feierabend!“ | < 25 % | M.O.D. `boss_phase:…:3`, `status_self sts_haste` bis Kampfende (rote Augen, 03_ART) | **Wischmopp-Wirbel** (`skl_b_mop_whirl`): Kreis r 400 um sich, Warnung 1,8 s (dreht sich auf), **25 %**, 3 s / 14 s; danach **Schwindelig** (`sts_dizzy` 3 s auf sich: +25 % Schaden genommen, keine Aktionen) — das Belohnungsfenster („Jetzt draufhauen!“). Putzmittelnebel alle 20 s. |

Lernkurve: P1 lehrt Unterbrechen (Kai Stufe 3 / Mopsula Stufe 3), P2 lehrt Ausweichen und Adds, P3 lehrt „raus — rein“.

### 6.7 Boss: Die Rattenkönigin von Gleis 9 (`enm_boss_rattenkoenigin`)

Stufe 8 (Zielstufe 7), Echtzeit-HP **7 600** (Start), `dmg_pm` 500 (ihre Formel-Treffer sind auf Stufe 7 sonst nicht heilbar),
Set-Radius 600 (geschlossen), Radius 110 cm; P1/P2 `stationary` auf dem entgleisten Waggon in der Raummitte (R4 setzt den
Boss-Spot auf (0, 0)), Auto Zepterstoß (`skl_q_scepter`, 120) alle 3,0 s, Reichweite 350; außer Reichweite Pestspucke (**neu**
`skl_q_spit`, 80 Gift, 1500 cm) als `auto_ranged_skill`. Schwäche Eis, Feuer ×0,5, immun gegen Gift und `sts_dazed`, 50 %
Widerstand gegen Betäubung/Verlangsamt. Enrage „Betriebsschluss!“ bei 5:00, dann alle 30 s.

**Bühnenbau (R4, Art-Kit, Thronsaal):** zwei **ebenerdige** Gleisbänder entlang der x-Achse bei z = −330 („Gleis 9a“) und
z = +330 („Gleis 9b“), je 3 m breit — Schienen und Schwellen auf Bodenhöhe eingelassen, **keine Grube**, damit Telegraphen flach
auf dem Boden liegen; dazwischen der 3,6 m breite Bahnsteig-Mittelstreifen (|z| ≤ 180) mit dem Waggon (Sperrfläche
`[-160, -80, 160, 80]`, §3.5.4; die Königin steht darauf); außen schmale Bahnsteigkanten bis zum Ring. Tunnelportale an den Wänden
sind Dekoration außerhalb des Rings. Das heutige Wrack an der Rückwand weicht dem Waggon; der Raum hält 6,2 m frei (§2.4). Die
Kampfreichweite reicht: Kai erreicht die Königin vom Waggonrand (Mitte ≤ 120 cm entfernt, Reichweite 250 + 110).

| Phase | HP | Beim Eintritt | Mechaniken |
|---|---|---|---|
| P1 „Hofstaat“ | > 65 % | Boss-Intro; 2 Kanalratten | **Pestbiss** (`skl_q_plague_bite`, 90 Gift, Formel): sofort, Nahkampf 350, 4 s / 8 s, Gift-Stapel 50 %. (U) **Schwanzknoten lösen** (`skl_q_summon`): Zauber 2,5 s, `adds_below` 3, 12 s / 25 s → 2 Kanalratten. |
| P2 „Zug fährt ein“ | 65–30 % | Durchsage-M.O.D. `boss_phase:…:2` („Auf Gleis 9 fährt ein: ein Zug. Bitte zurückbleiben.“) | **Zug** (**neu** `skl_q_train`): Linie entlang einer Gleisspur (`lane`, `lanes` [−330, 330], Breite 300, Sehne des Rings), abwechselnd 9a/9b, Warnung **3,0 s** (Hupe, Scheinwerfer im Tunnel, Schienen glühen), 6 s / 20 s, nicht unterbrechbar; Treffer: Party **35 %** (`pct_maxhp` 35, `ignore_guard`), **Adds sofort K.O.** (`kill_adds`, „Zug-Kill“ +4 Hype). Sicher ist der Bahnsteig in der Mitte. (U) **Kreischen der Krone** (`skl_q_screech`, ganzes Set, kein Telegraph): Zauber 2,0 s, 10 s / 16 s; nicht unterbrochen → alle Party-Mitglieder **15 %** (`pct_maxhp`). **Pestpfützen** (**neu** `skl_q_puddles`): 3 Kreise r 200 (`random`), Warnung 1,5 s, **15 %**, Zone 10 s (Gift alle 2 s), 8 s / 18 s. Pestbiss weiter. |
| P3 „Endstation“ | < 30 % | M.O.D. `boss_phase:…:3`; der letzte Zug entgleist (Effekt), `fixed_damage_self` 50 ‰ („vom eigenen Zug erwischt“), `clear_zones`, `set stationary false` (Tempo 300 cm/s, sie steigt vom Waggon), `status_self sts_haste` bis Kampfende | **Kronen-Nova** (`skl_q_crown_nova`): Ring 300–1200 cm um sich (deckt das ganze Set außer 3 m um sie), Warnung 3,0 s, **25 %**, 5 s / 18 s — sicher ist es **nah an der Königin**. Pestbiss 8 s, Kreischen 20 s (U), Pestpfützen 20 s. |

### 6.8 Etage 2 (Entwurf, gebaut erst mit Etage 2 — Entscheidung O6 zurückgestellt)

Nicht Teil von R1–R5 (Etage 2 ist `playable: false`); die Sim muss dafür nur die allgemeinen Bausteine bieten, die schon
existieren, plus „Zähler“ (unten). Die Details entscheidet die Nutzerin/der Nutzer vor dem Bau von Etage 2 (O6).

| Gegner | Echtzeit-Idee |
|---|---|
| Schaufensterpuppe (`enm_schaufensterpuppe`) | Bewegt sich und greift nur an, solange sie **niemandes Ziel** ist; „Schaufensterpose“ alle 9 s (`sts_guard` + `sts_taunt`: Blickfang). |
| Einkaufswagen-Rudel (`enm_einkaufswagen_rudel`) | Rammkette: jeder Wagen eine Linie 1000 × 150 zu seinem Ziel, Warnung 0,8 s, um Slot × 0,5 s versetzt, alle 9 s, `dash`. |
| Rabattschild-Golem (`enm_rabattschild`) | „Rabattstufe“: jeder Auto-Treffer +10 % Schaden (bis 5 Stapel); jede Unterbrechung/Betäubung setzt zurück. Preissturz: Kreis r 300 um sich, Warnung 1,5 s, alle 12 s. |
| **Boss „Der Ausverkauf“** (`enm_boss_ausverkauf`, neu) | Riesiges Preisschild auf einem Schaufensterpuppen-Körper. **Zähler** „Rabatt“: alle 5 s −10 % mehr (−10 % … −90 %); bei −90 % „BLACK FRIDAY“ — ganzes Set 60 % Max-HP fest, Zähler zurück. **Kassensturz:** Trifft die gesteuerte Figur den Boss innerhalb von 6 s mit **3 verschiedenen** Fähigkeiten, springt der Zähler auf 0 und der Boss ist 2 s überrumpelt (Hype +6, Abwechslung belohnt). Adds „Wühltisch-Kundschaft“ alle 30 s; „Preisregen“ 4 Kreise r 200 (`random`), Warnung 1,2 s, alle 15 s. |

Neuer Baustein für Etage 2: `rt.counter` = `{"every_ms", "max", "at_max_skill", "reset": {"distinct_skills", "within_ms"},
"reset_status"}` mit Ereignis `COUNTER_CHANGED` (wird dann am Enum-Ende angehängt).

---

## 7. Steuerung und UX

### 7.1 PC (Tastatur + Maus)

| Aktion | Erkundung | Kampf |
|---|---|---|
| Bewegen | WASD / Pfeile (kamerarelativ, unverändert) | gleich; immer Lauftempo (Schleichen wirkungslos) |
| Kamera | Q/E, rechte Maustaste ziehen, Mausrad = Zoom (unverändert) | gleich |
| Ziel wählen | `Tab` = nächster Anführer im Raum (Zielrahmen erscheint), Linksklick auf Gegner | `Tab` / `Shift+Tab` (vor/zurück), Linksklick auf Gegner oder Plakette; Linksklick auf Party-Rahmen = freundliches Ziel; Linksklick auf freien Boden = Ziel löschen |
| Auto-Angriff | — | automatisch; `F`/`Leertaste`/`Enter` = „Angriff!“ (kein Ziel → nächster Gegner; Auto an); Klick auf das Schwert im Zielrahmen oder `V` = Auto an/aus |
| Fähigkeiten | `1`–`5` mit Ziel = Pull (§2.2) | `1`–`5` (Klick auf Slot ebenso) |
| Trank | — (Feldnutzung im Menü wie bisher) | `6`; Rechtsklick auf Slot 6 = Gegenstandsrad |
| **Partner-Spezial** | — | `R` (Klick auf den Knopf am Partner-Rahmen ebenso) |
| Partner-Taktik | — | `G` (zyklisch Angriff → Unterstützen → Vorsichtig), Klick auf den Taktik-Chip öffnet Taktik + Schalter |
| Autopilot | — | `T` (`toggle_auto`) |
| Interagieren / Feldfähigkeit | `F`/`Leertaste`/`Enter` (unverändert; Kai: Feldschlag, Mopsula: Bellen, 06 §1.3) | gesperrt |
| Karte | `M` (Tab entfällt) | gesperrt (Hinweis „Nicht während der Aufnahme!“) |
| Pause | `Esc`/`P` | `Esc`/`P` (Offline-Läufe: die Sim tickt nicht; Server-Läufe: keine Pause, §13.2 O2) |

### 7.2 Gamepad

| Aktion | Erkundung | Kampf |
|---|---|---|
| Bewegen / Kamera | linker / rechter Stick | gleich |
| A | `action` (Interagieren; mit gewähltem Ziel in Reichweite von Slot 1: Pull mit Slot 1; sonst Feldfähigkeit) | Slot 1 |
| X / Y / B | X, Y: Pull mit Slot 2/3 (wenn Ziel); B = `ui_cancel` in Menüs | Slot 2 / 3 / 4 |
| RB / LB | `tab_next`/`tab_prev` in Menüs | RB = SHOW (Slot 5), LB = Trank (Slot 6; 0,4 s halten = Gegenstandsrad, Auswahl mit rechtem Stick, loslassen = benutzen) |
| RT | nächstes Ziel | nächstes Ziel |
| LT | Schleichen (unverändert) | vorheriges Ziel |
| Steuerkreuz | oben = Autopilot | oben = Autopilot, rechts = Taktik wechseln, unten = Auto-Angriff an/aus, **links = Partner-Spezial** |
| Start / Back | Pause / Karte | Pause / gesperrt |

Hinweis: Y war bisher `toggle_auto`; das wandert auf Steuerkreuz oben (Y ist im Kampf Slot 3). Kontexttrennung: Die Erkundung
wertet `bar_*` nur als Pull aus, der Kampf wertet `action`, `sneak`, `map` nicht aus.

### 7.3 Touch

Erkundung: unverändert (schwebender Stick links, Aktionsknopf mit Faust bzw. Schallwellen für Mopsulas Bellen — 06 A, Karte,
Pause). Ist außerhalb des Kampfes ein Anführer als Ziel gewählt (Antippen), zeigt der Aktionsknopf das Symbol von Slot 1 und zieht
damit (Pull).

Kampf (Referenz 1280 × 720, Zentren in px, verschieben sich mit den Safe-Area-Insets wie bisher, §10.4 02_TECH):

| Knopf / Zone | Zentrum bzw. Fläche | sichtbar / Trefferfläche | Inhalt |
|---|---|---|---|
| **Stick-Zone** | links unten: x 0–512, y 320–720 | schwebend, Ruheposition (147, 573) | nur Bewegung; im Kampf hält der Stick **kein** `sneak` (immer Lauftempo ab der Totzone 0,15) |
| Slot 1 (Hauptfähigkeit) | (1147, 587) | 96 / 104 px | ersetzt im Kampf den Aktionsknopf an derselben Stelle (Daumen-Ruheposition) |
| Slot 2 | (1019, 634) | 72 / 88 | Bogen um Slot 1, Radius 136 px, 200° |
| Slot 3 | (1024, 530) | 72 / 88 | 155° |
| Slot 4 | (1100, 459) | 72 / 88 | 110° |
| SHOW (Slot 5) | (1206, 460) | 80 / 96 | 65°, Radius 140 px, goldener Rahmen; FINALE in Magenta/Gold |
| Trank (Slot 6) | (907, 650) | 64 / 88 | halten = Gegenstandsrad; Restanzahl „2/3“ |
| Ziel wechseln | (1227, 360) | 64 / 88 | wie `target_next`; halten = vorheriges |
| Pause | (1227, 40) | 64 / 88 | unverändert |
| **Partner-Spezial** | (300, 192) | 64 / **88** | neben dem Partner-Rahmen; Symbol der Signatur, Abklingzeit als Sweep |
| Taktik-Chip | (108, 268) | 168 × 36 / 168 × 88 | erst nach dem ersten Safe-Room-Besuch (§8.1); öffnet Taktik + Schalter |
| Karte | — | — | im Kampf ausgeblendet |

Geprüfte Abstände (Mittelpunkte ≥ Summe der halben Trefferflächen): Slot1–Slot2/3/4 = 136, Slot1–SHOW = 140 (≥ 100); Slot2–Slot3 =
104, Slot3–Slot4 = 104, Slot4–SHOW = 106, SHOW–Ziel = 102, Slot2–Trank = 113 (je ≥ 92/88). Alle Zentren der Daumen-Gruppe liegen
≤ 250 px vom Slot-1-Zentrum (Daumenradius). Linke Seite: Partner-Spezial (x 256–344, y 148–236) überschneidet weder den
Spieler-Rahmen (y 76–132) noch den Partner-Rahmen (x 24–244) noch den Taktik-Chip (x 24–192, y 224–312); die Stick-Zone beginnt
erst bei y 320 — Rahmen, Partner-Spezial und Chip bleiben antippbar. **Jedes** Touch-Ziel hat ≥ 88 px Trefferfläche.

**Tippen ≠ Ziehen:** Eine Berührung außerhalb der Stick-Zone und der Knöpfe ist ein **Tippen**, wenn sie innerhalb von 0,25 s endet
und sich weniger als 12 px bewegt hat → Zielwahl (projizierter Fußpunkt oder Plakette, Trefferfläche ≥ 107 px, 03_ART §9;
Party-Rahmen = freundliches Ziel); sonst ist sie ab dem Frame, in dem sie 12 px überschreitet, ein **Kamera-Ziehen**. Zwei Finger =
Zoom. Langes Drücken auf einen Slot = Tooltip (Name, Kosten, Abklingzeit, Kurztext), kein Auslösen; langes Drücken auf einen
Rahmen = Status mit Restsekunden (§8.4). Auto-Angriff ist immer automatisch.

**Weiche Zielführung** (Touch-Standard, §7.5): Die Kamera hält das aktuelle Ziel im Bild, ohne den Spieler zu bevormunden.

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
- **Weiche Zielführung** (`GameSettings.combat_camera_assist`, Standard: an bei Touch, aus sonst): Liegt das aktuelle feindliche
  Ziel mehr als ±40° neben der Kamera-Vorwärtsrichtung und hat der Spieler die Kamera 1,5 s nicht bewegt, dreht die Gier mit
  höchstens 90°/s, bis das Ziel innerhalb ±25° liegt. Kein Nicken, kein harter Ziel-Lock; jedes Ziehen hat Vorrang.
- Steuerungswechsel (§2.6): Kamera-Pivot gleitet in 0,4 s zur neuen Figur.
- Leichtes Kamerawackeln bei Einschlägen auf die Party (0,15 s, 0,08 m), abschaltbar.
- Wände: bestehende Regeln (Pitch anheben, Arm kürzen, Durchblick-Ausblenden) gelten unverändert.

### 7.6 Barrierefreiheit

| Einstellung (`GameSettings`) | Werte | Wirkung |
|---|---|---|
| `combat_speed_pm` „Spieltempo“ | 1000 / 850 / 700 | Echtzeit pro Tick (Darstellung + Eingabe), die Sim bleibt identisch. **Überall erlaubt** (auch Events/Ligen); jeder Wechsel wird als Befehl `combat_speed` aufgezeichnet, Bestenlisten-Einträge mit einem Wert unter 1000 tragen das Abzeichen „Zeitlupe“ und lassen sich getrennt filtern (§10.7, O1) |
| `combat_assist` „Assist“ | an/aus (Touch: an) | Vorschlag-Ring auf der Leiste (§5.6) |
| `combat_camera_assist` „Kamera folgt dem Ziel“ | an/aus (Touch: an) | weiche Zielführung (§7.5) |
| `combat_hints` „Kampf-Hinweise“ | an/aus | Tutorial- und Erst-Hinweiskarten (§2.13) |
| `telegraph_contrast` „Kontrast-Telegraphen“ | normal / hoch | hoch: Füllung Weiß 35 % + schwarze Streifen + doppelt breiter Rand |
| `auto_attack_default` | an/aus | Auto-Angriff zu Kampfbeginn |
| `auto_retarget` | an/aus | automatische Zielwahl nach einem Kill |
| `floating_text_scale` | 100 / 125 / 150 % | Kampftext-Größe |
| `camera_shake` | an/aus | Kamerawackeln |
| `combat_mode` | `realtime` / `ctb` | nur bis R5b; neue Spielstände (§12.1) |

Farbenblind-sicher: Telegraphen tragen ihre Bedeutung über **Form, Streifen und Rand**, nicht über Farbe; Zauberleisten
unterscheiden ihre drei Stufen über Rand + Schloss-Symbol + Ton; Status-Symbole haben Formen (03_ART-Paletten bleiben Zusatz).
Untertitel für M.O.D. sind immer an. Autopilot und Vorabendprogramm (Warnzeiten × 1,25) ergänzen.

### 7.7 Input-Map-Änderungen (`project.godot`, R3)

| Aktion | Ereignisse | Status |
|---|---|---|
| `target_next` | Taste Tab; Joypad-Achse RT (5, +) | neu |
| `target_prev` | Taste Tab mit Shift; Joypad-Achse LT (4, +) | neu |
| `bar_1` … `bar_6` | Tasten 1…6 (`KEY_1` = 49 … `KEY_6` = 54); Joypad A (0), X (2), Y (3), B (1), RB (10), LB (9) | neu |
| `partner_special` | Taste R (`KEY_R` = 82); Joypad Steuerkreuz links (13) | neu |
| `partner_preset` | Taste G (71); Joypad Steuerkreuz rechts (14) | neu |
| `auto_attack_toggle` | Taste V (86); Joypad Steuerkreuz unten (12) | neu |
| `map` | Taste M, Joypad Back (4) — **ohne** Tab | geändert |
| `toggle_auto` | Taste T, Joypad Steuerkreuz oben (11) — **ohne** Y | geändert |

Alle Konstanten geprüft (Anhang A7, A16). Deadzone der Achsen-Aktionen Standard 0,2 (geprüft). Bestehende Aktionen bleiben sonst
unverändert (02_TECH §2.2).

### 7.8 Neue Felder `GameSettings` (R1a als Felder, R3 im Menü)

`combat_mode: StringName = &"ctb"` (gilt für neue Spielstände; R5b stellt den Standard auf `&"realtime"` um, §12.1),
`combat_speed_pm: int = 1000`, `combat_assist: int = -1` (−1 = automatisch: an bei Touch), `combat_camera_assist: int = -1`,
`combat_hints: bool = true`, `telegraph_contrast: StringName = &"normal"`, `auto_attack_default: bool = true`,
`auto_retarget: bool = true`, `floating_text_scale: int = 100`, `camera_shake: bool = true`. Schlüssel in `settings.cfg` unter
`[combat]`. `battle_speed`, `auto_battle_default` und 06-`partner_auto` bleiben bis zur CTB-Entfernung (`partner_auto` wirkt nur
im CTB-Modus).

---

## 8. HUD (TV-Overlay)

### 8.1 Layout und schrittweises Aufdecken

Referenz 1280 × 720, innerhalb des Safe-Frames wie das bestehende HUD. Oben Mitte bleibt dem Kampf vorbehalten (Boss/Ziel,
Banner); der Etagen-Timer rückt im Kampf als kleiner Chip nach links oben.

| Element | Anker / Lage | Größe | Inhalt |
|---|---|---|---|
| LIVE, Zuschauer, Follower | oben links (24, 24) | bestehend | ShowOverlay |
| Etagen-Timer | im Kampf: Chip unter LIVE (24, 68) | 140 × 22 | grau, „Uhr steht · 12:34“; außerhalb des Kampfes wie bisher oben Mitte |
| Hype-Meter + Show-Chip (06 C) | oben rechts | bestehend | Marken 70/85/100; Vorliebe/Liga im Show-Chip |
| Boss-Rahmen (nur Boss) | oben Mitte, y 24 | 520 × 36 | Name, Phasen-Rauten, HP-Leiste + %, Enrage-Countdown in der letzten Minute; Zauberleiste 520 × 10 darunter |
| Zielrahmen | oben Mitte, y 24 (Bosskampf: y 84, nur wenn Ziel ≠ Boss) | 300 × 56 | Symbol 40, Name + Stufe, HP 240 × 12, Zauberleiste 240 × 8, Schwert (Auto an/aus); Status-Reihe darunter |
| Banner | oben Mitte, y 150 | 1,2 s | „KAMPF!“, „Erstschlag!“, Phasen, Steuerungswechsel, Enrage |
| Party-Rahmen (gesteuert) | (24, 96) | 240 × 56 | Pille **„DU“** (06 A), Symbol 48, Name + Stufe, HP 176 × 14 mit Zahl, MP 176 × 8, Aggro-Zähler |
| Status-Reihe (gesteuert) | (24, 156) | bis 6 × 22 | Symbole 20 px mit Radial-Sweep; Restsekunden nur per langem Druck/Mauszeiger |
| Party-Rahmen (Partner) | (24, 184) | 220 × 48 | wie oben kleiner, HP 156 × 12, MP 156 × 6 |
| **Partner-Spezial** | rechts neben dem Partner-Rahmen: PC (268, 208) 48 px; Touch §7.3 | 48 bzw. 64/88 | Symbol der Signatur (Megafon bzw. Zunge), Abklingzeit als Sweep, Taste `R` |
| Status-Reihe (Partner) | (24, 236) | bis 6 × 22 | |
| Taktik-Chip | (24, 266) | 168 × 28 (Touch 168 × 36, Trefferfläche 88) | „Taktik: Unterstützen [G]“ |
| M.O.D.-Untertitel | unten Mitte, Unterkante −130 | 600 × 56 | höchstens 2 Zeilen, 18 px; nur geschriebene Zeilen (§9.3) |
| Spieler-Zauberleiste | unten Mitte, Unterkante −108 | 240 × 14 | nur beim Zaubern/Kanal/Trinken |
| Aktionsleiste | unten Mitte, Unterkante −36 | 436 × 64 | 6 Slots à 64, Abstand 8, vor Slot 6 (Trank) zusätzlich 12 |
| Flucht-Countdown | Mitte, y 300 | 36 px Text | „Zurück ans Set! 2… 1…“ |
| Sponsor-Bauchbinde | unten links | im Kampf 380 × 64 | sonst 480 (überdeckt die Leiste nicht) |
| Chat-Ticker | ganz unten, 22 px | bestehend | |
| Minimap, Erkundungs-Hinweise, Mini-Party | — | ausgeblendet | |

Touch: gleiche Oberkante und linke Spalte; Aktionsleiste entfällt (Daumen-Gruppe §7.3), Spieler-Zauberleiste unten Mitte bei
x = 590, Unterkante −100; M.O.D.-Untertitel 520 × 56 zwischen x 330 und 850, Unterkante −36, `mouse_filter = IGNORE` (der
Stick-Bereich bleibt bedienbar).

**Schrittweises Aufdecken** (06 L-1/L-2: neue Elemente erst, wenn sie gebraucht werden — das Kampf-HUD ersetzt das CTB-HUD und ist
auf E1 nicht dichter als dieses):

| Element | erscheint |
|---|---|
| Party-Rahmen (HP/MP), Zielrahmen, Slot 1 + SHOW + Trank, Kampftext, Telegraphen, Zauberleisten | ab dem ersten Kampf |
| Slots 2–4 | mit der jeweiligen Stufe (die Leiste wächst, §4.1) |
| Partner-Spezial | sobald der Partner seine Signatur hat (Mopsula als Partner: Stufe 1; Kai als Partner: Stufe 2) |
| Bedrohungspunkte auf Plaketten, Aggro-Zähler „×2“ | nach dem ersten Spott der Party (StatId `taunts_total` > 0) |
| Taktik-Chip | nach dem ersten Safe-Room-Besuch |
| Restsekunden der Status | nur per langem Druck (Touch) bzw. Mauszeiger (PC) |
| Boss-Rahmen, Phasen-Rauten, Enrage-Countdown | nur in Bosskämpfen |

### 8.2 Aktionsleiste

| Zustand | Darstellung |
|---|---|
| bereit | dunkler Slot (Panel-Farbe), Symbol 44 px, Taste oben links (12 px, `InputGlyph`) |
| Abklingzeit | dunkle Radialfläche im Uhrzeigersinn ab 12 Uhr (`cooldown_left / cooldown_total`), Restsekunden mittig (20 px, ab 1 s ganzzahlig) |
| GCD | dünner weißer Außenring (Radius 0,86–1,0) als Sweep (`gcd_left / gcd_total`) |
| zu wenig MP | Symbol entsättigt + Blau-Tönung (`MANA` #60A5FA, 50 %), MP-Kosten klein unten links |
| außer Reichweite | Rot-Tönung (`DANGER` #FF4D4D, 60 %) |
| kein gültiges Ziel | Symbol 40 % gedimmt |
| gepuffert (Queue) | goldener Rand 3 px (`HYPE_GOLD` #FFC93C) |
| wieder bereit | Weißblitz 0,15 s |
| Assist-Vorschlag | pulsierender goldener Ring (1,2 Hz) |
| SHOW | goldener Rahmen, bereit = langsamer Schimmer; **FINALE** (Stufe ≥ 6 und Ziel < 30 %, `RtSim.bar`) = Rahmen Magenta (#FF2E88) ↔ Gold animiert + Schriftzug „FINALE“; bei Hype ≥ 85 zusätzlich Funkenkranz (nur Darstellung) |
| Trank | Restanzahl im Kampf „2/3“ unten rechts, Party-Abklingzeit als Sweep |
| abgelehnt | Rütteln 0,2 s + Kurztext über der Leiste („Nicht genug MP“, „Zu weit weg“, „Abklingzeit“, „Kein Ziel“, „Gesperrt“, „Ziel noch zu fit“) |

Zustände liest das HUD jedes Frame aus den reinen Abfragen `RtSim.bar`, `can_use`, `cooldown_left`/`cooldown_total`,
`gcd_left`/`gcd_total`, `item_cd_left`/`item_cd_total`, `items_left`, `RtUnit.queued` und `suggest` (keine Ereignis-Buchhaltung
im HUD). Ladungen (Feld `charges`) sind reserviert, Anzeige unten rechts.

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

Drei Stufen (§6.2): **unterbrechenswert** = goldener Rand + Funkeln + Ton „Ding“ beim Start; unterbrechbar = weißer Rand, kein Ton;
nicht unterbrechbar = grauer Rand + Schloss-Symbol. Unterbrochen: Leiste blitzt Gold, Kampftext „UNTERBROCHEN!“ über dem Gegner,
Ton „Plattennadel-Kratzer“.

### 8.4 Einheitenrahmen und Status-Symbole

- Party: HP-Leiste in Partyfarbe (`ui_party` #4AA8FF) mit nachlaufendem roten Schadensstück (0,4 s) und grünem Heil-Aufblitzen;
  MP in `MANA`; K.O. = grau + „K.O.“; Pille „DU“ an der gesteuerten Figur (06 A; nach einem Steuerungswechsel wandert sie mit);
  **Aggro-Zähler** (rotes Abzeichen „×2“ = so viele Gegner greifen dieses Mitglied an) ab dem ersten Spott (§8.1).
- Partner-Spezial-Knopf am Partner-Rahmen (§8.1, §7.3): Symbol, Abklingzeit-Sweep, bei Ablehnung Rütteln + Kurztext.
- Ziel: HP in Gegnerfarbe (`ui_enemy` #E8455A), Elite/Boss-Marke, Schwert-Schalter für Auto-Angriff.
- Boss: Phasen-Rauten (gefüllt = erreicht), HP-Prozent, in der letzten Minute vor dem Enrage „Feierabend in 0:42“.
- Status-Symbole: 20 px (Ziel 18 px), Buffs vor Debuffs, nach Restzeit; Restzeit als Radial-Sweep, Restsekunden als Ganzzahl nur
  per langem Druck/Mauszeiger, Stapel unten rechts; mehr als 6 → „+n“. Symbole kommen aus `StatusDef.icon` (icon_mesh), Farben aus
  03_ART (Gift #7CC242, Betäubt #F5D90A, Verlangsamt #5B8DEF, Turbo #FF7A1A, Gepanzert #9AA7B8, Provoziert #E8455A); neue Status
  bekommen in R3 Symbole (Ids aus `RtVocab.ICON_IDS`).
- Keine Live-Porträts (SubViewport) im Kampf-HUD — statische Symbole sparen 3D-Draw-Calls.

### 8.5 Namensplaketten

2D, projiziert über `Camera3D.unproject_position` (geprüft) auf Kopfhöhe + 0,4 m, für alle Gegner im Kampf: HP-Leiste 64 × 6,
Zauberleiste 64 × 4 (nur beim Zaubern), bis zu 3 Statuspunkte in Statusfarbe, links ein **Zielpunkt** in der Farbe des
angegriffenen Party-Mitglieds (`party.json` `portrait_color`, ab dem ersten Spott, §8.1). Name nur für das aktuelle Ziel, Elite und
Boss. Ausgeblendet hinter der Kamera/außerhalb des Bildes, ab 20 m ausgeblendet. Umsetzung (geprüft): alle Leisten/Punkte in
**einem** Dreiecks-Array (1 Draw Call) + höchstens 8 Labels ohne Outline (≈ 1 Draw Call): 8 Plaketten = 2 Draw Calls (als
`PanelContainer` + `ProgressBar` gemessen: 24). **Keine `Label3D`-Plaketten** (geprüft: je Billboard-`Label3D` mit Outline
2 Draw Calls in Compatibility, 1 in Mobile).

### 8.6 Kampftext

`Vfx.damage_number` (2D-Zwilling auf CanvasLayer 4, bestehend) mit Echtzeit-Stilen (R3 ergänzt in `art/kit/vfx.gd`):
`rt_dealt` (weiß; Krit gelb 130 % mit „!“), `rt_taken` (rot), `rt_heal` (grün), `rt_partner` (75 %, Partner-Auto-Angriffe),
`rt_word` (Wörter: „UNTERBROCHEN!“ Gold 26 px, „AUSGEWICHEN“ Cyan, „KNAPP!“, „IMMUN“, „WIDERSTAND“, „SCHWACH!“). Prozent-Treffer
zeigen zusätzlich kurz „−25 %“ am Party-Rahmen. Höchstens 10 gleichzeitig (älteste fällt weg), Lebensdauer 0,6 s, Größe ×
`floating_text_scale`. Nur ASCII + deutsche Buchstaben (03_ART F8: keine ★ ↑ → usw.).

### 8.7 Telegraph- und Set-Darstellung

**Engine-Befund (geprüft):** `Decal` wird im Renderer **Compatibility nicht** gezeichnet (Mitte der Decal-Fläche = reine
Bodenfarbe #969696), in Mobile schon. Telegraphen sind deshalb **flache Quads mit Shader**: `MeshInstance3D` + `QuadMesh`,
flach auf y = 0,04 m, ein gemeinsames `ShaderMaterial` (`art/shaders/rt_telegraph.gdshader`) mit zwei Instanz-Uniforms und
zwei Material-Uniforms für das Set — in beiden Renderern sichtbar, korrekt maskiert und **am Ring beschnitten** (geprüft A2, A13:
Pixel innerhalb des Rings in Telegraphfarbe, innerhalb der Form aber außerhalb des Rings = Bodenfarbe); jedes Quad und der Ring
kosten je 1 Draw Call.

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// x = shape (0 circle, 1 cone, 2 ring, 3 line), y = fill progress 0..1, z = inner ratio (ring), w = cos(half angle) (cone)
instance uniform vec4 tg_params = vec4(0.0, 0.0, 0.0, -1.0);
instance uniform vec4 tg_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
uniform vec2 set_center = vec2(0.0);   // world XZ of the Set centre (one Set per combat: per material)
uniform float set_radius = 4.8;        // m: nothing is drawn outside the Set ring (07 §3.5.4)
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
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
	float in_set = step(distance(world_xz, set_center), set_radius);
	ALBEDO = mix(tg_color.rgb, vec3(1.0), edge * 0.5);
	ALPHA = clamp(a, 0.0, 0.95) * tg_color.a * in_set;
}
```

- Quad-Größen: Kreis/Ring 2r × 2r um die Mitte; Kegel 2r × 2r um die Spitze (Shader maskiert); Linie W × L, Pivot am Start.
  `tg_params.y` = (ct − start) / (impact − start) (Füllung wächst bis zum Einschlag), Rand pulsiert in den letzten 0,3 s,
  Einschlag = Weißblitz 0,15 s, danach Quad zurück in den Pool. `set_center`/`set_radius` setzt der `TelegraphLayer` beim
  Kampfstart.
- Farben: gegnerische Telegraphen `DANGER` #FF4D4D mit weißem Rand und wandernden Streifen; Zonen in Elementfarbe (Gift #7CC242,
  Feuer #FF7A1A) mit α 0,35 und langsameren Streifen, letzte Sekunde ausblenden; Kontrastmodus §7.6. Freundliche Bodenmarken
  (nur Darstellung, z. B. Inferno-Zielkreis) `C_ACCENT_2` #22D3EE.
- Pool von 10 Quads (`MAX_TELEGRAPHS`), ein Material → +1 Material im 3D-Budget (Messwert bisher 21–23 von 24).
- **Tiefentest bleibt an** (O8); die Quads liegen auf 0,04 m über allen Bodenmarken (geprüft im Raumbau: Fugen und Randstreifen
  bis 0,012 m, Ticketschnipsel bis 0,017 m, gelbe Bahnsteigkante vor dem Gleisgraben bis 0,029 m — sie liegt bei 4,5–5,1 m, also
  unter dem Ring) und über dem LED-Ring (0,035 m) und haben `render_priority` 1, damit sie vor anderen transparenten Bodenflächen
  sortiert werden. Requisiten können sie nicht verdecken (keine Requisiten im Set).
- **LED-Ring des Sets:** eine `MeshInstance3D` (Band 12 cm breit auf y = 0,035 m, Lücken an offenen Türen, unshaded, Farbe
  `C_ACCENT_2`, wirft keinen Schatten) — 1 Draw Call, 1 Material (geprüft A13); dazu der unsichtbare Kollisionsring (§2.4).

### 8.8 ShowOverlay, M.O.D.-Untertitel, Banner

- `Events.overlay_mode_requested(&"combat")` (neuer Modus): wie `&"explore"`, aber Minimap-Freiraum entfällt, Timer als Chip
  (§8.1), Sponsor-Bauchbinde 380 px breit und 1,5 s im Kampf.
- ModDialog im Kampf als **Untertitel**: neues Signal `Events.dialog_layout_requested(mode: StringName, layout: Dictionary)` mit
  `{"bottom": float, "width": float, "max_lines": int, "blocking": bool, "mouse_filter_ignore": bool}`; im Kampf
  `{"bottom": 130, "width": 600, "max_lines": 2, "blocking": false, "mouse_filter_ignore": true}` (Touch: 36/520). Blockierende
  Zeilen werden im Kampf nicht blockierend angezeigt (Ausnahme Boss-Intro, §2.9). Höchstens eine Zeile je 6 s (§9.3).
  Hinweiskarten (§2.13) nutzen dieselbe Box mit Tasten-Bild.
- **Keine KI-generierten Zeilen im Kampf** (06 §5.3/5.8: „M.O.D. live“ arbeitet auf der Lauf-Uhr, die im Kampf steht): Die
  Untertitel sind ausschließlich geschriebene `mod_lines.json`-Zeilen; `Show.say_external` lehnt im Kampf ab, Antworten des
  Dienstes, die während eines Kampfes eintreffen, werden verworfen. Nach dem Kampf läuft „M.O.D. live“ normal weiter (§9.3).
- Banner (Kampfbeginn „KAMPF!“, „Erstschlag!“, „Hinterhalt!“, Phasenwechsel, Steuerungswechsel, Enrage): Bauchbinde oben Mitte
  unter dem Ziel-/Bossrahmen, 1,2 s, nicht blockierend.

### 8.9 Ergebnis-Anzeigen (Nachfolger des CTB-Ergebnisbilds)

Mit R5b wird `scenes/battle/ui/battle_results.gd` gelöscht. Nachfolger ist **`scenes/combat/ui/combat_results.gd`** (R3; R1a legt
den Stub mit der öffentlichen API an) — eine Komponente für beide Formen und mit **denselben 06-Andockpunkten**:

- `signal results_shown(result: BattleResult)` und `var show_slot: Control` (06 §8.0 Nr. 12; Paket C hängt `bets_results_fx.gd`
  daran: Herz-Flug in den Show-Chip, Toast),
- Chip „TALENT BEREIT · im Safe Room wählen“ bei einem Stufenaufstieg auf eine Talent-Stufe (06 B, `Talents.is_talent_level`) —
  nie eine Wahl im Kampfergebnis,
- `func present(result: BattleResult, rewards: BattleRewards) -> void`, Autoplay weiter nach 1,0 s (`auto_continue_sec`).

Formen:

- Regulärer Sieg: Bauchbinde „Applaus!“ unten links (380 × 64), 3,0 s: „+36 EXP · +12 Cr · Werbepflaster“; Stufenaufstieg und
  Talent-Chip als zweite Bauchbinde. Nicht blockierend; Erkundung läuft sofort weiter.
- Boss-Sieg: Abspann-Panel (Overlay auf Layer 60, Baum pausiert) mit EXP-Leisten, Boss-Beute, Talent-Chip und `show_slot`.
- Flucht: Bauchbinde „Taktischer Rückzug“ (−Hype sichtbar im Meter).
- Niederlage: bestehender Sendeschluss.

### 8.10 Leistungsbudgets im Kampf (PERFORMANCE.md, 02_TECH §12.1) — gemessen

Gemessen mit einem Prototyp in der echten Erkundung (Seed 4242, Etage 1; Anhang A15): Kampfansicht = Raum der Set-Zelle, Kamera-Arm
8 m (Boss 9 m), LED-Ring, 10 Telegraph-Quads, zusätzliche Gegner-Rigs neben den Anführern, Akteure anderer Räume ausgeblendet;
Maximum über 4 Kamerarichtungen.

| Ansicht | Compatibility high | … Komparsen ohne Echtzeitschatten | Mobile high | Compatibility low |
|---|---:|---:|---:|---:|
| (1,3) eine Gruppe, 3 Einheiten (2 Komparsen) | 147 | **132** | 74 | 84 |
| (1,3) zwei Gruppen, 6 Einheiten (4 Komparsen) | 180 ✗ | **147** | 82 | 99 |
| (1,1) Gardisten + Schamane | 150 | **128** | 74 | 73 |
| (4,4) Kreuzung mit 4 Türen, 6 Einheiten | 150 | **118** | 68 | 86 |
| (0,0) Königin + 5 Ratten, Boss-Set | 138 | **112** | 65 | 82 |
| (5,0) Hausmeister + 2 Ratten, Boss-Set | 112 | **100** | 58 | 66 |

Kosten je Baustein (Compatibility high): ein Rig ≈ 4 Draw Calls je Mesh-Teil (Farbe + Umriss, beide auch im Schattenpass) —
Kanalratte (3 Teile) +12, Taubenschwarm (5 Teile) +20; ohne Echtzeitschatten etwa die Hälfte; Mobile +7 / +9. Ring 1, jedes
Telegraph-Quad 1.

| Messgröße | Budget Kampf | Bisher (CTB) | Echtzeit-Regel |
|---|---|---|---|
| 3D-Draw-Calls | ≤ 150 | Erkundung ≤ 112, CTB-Kampf ≤ 133 | **Komparsen und Beschwörungen werfen keine Echtzeitschatten**; Akteure anderer Räume ausgeblendet; zweite Gruppe nur bis 6 Einheiten insgesamt (§2.3). Schlechtester gemessener Fall 147 — R2 misst ihn mit Effekten (Szenario `combat_two_groups`) früh nach; liegt er über 150, bekommen Komparsen ein zusammengefasstes Rig-Mesh (Rig-LOD, Reserve) und Treffer-Funken höchstens 3 gleichzeitige Emitter |
| UI-Draw-Calls | ≤ 180 | CTB-Kampf 122–167 | ShowOverlay ≈ 45, Leiste ≈ 4, Rahmen ≈ 10, Plaketten 2, Kampftext ≤ 20, Untertitel ≈ 4, Touch ≈ 6 |
| Materialien | ≤ 24 | 21–23 | +1 (Telegraph), +1 (Ring), Sweep ist Canvas |
| `Label3D` | ≤ 12 | ≤ 8 | +0 (keine 3D-Plaketten) |
| Partikel | ≤ 400 / 6 Emitter | — | Treffer-Funken je Einheit höchstens alle 0,2 s, Pool |
| Physik-Körper | ≤ 40 | 23 | +1 (Kollisionsring, ein `StaticBody3D`); Puppen ohne Körper (Kollision im Kampf aus) |
| Sim | §3.15 | — | ≤ 0,25 ms/Tick Desktop |

Umsetzungsregeln aus den Messungen: (1) gleiche Shader-Instanzen mit Instanz-Uniforms statt eigener Materialien; (2) Rahmen,
Leisten, Symbole als Dreiecks-Arrays (`icon_mesh.gd`); (3) Labels ohne Outline auf dunklem Grund; (4) keine `TextureProgressBar`-
Radialanzeigen, keine `PanelContainer`-Plaketten, keine `Label3D`-Plaketten, keine SubViewport-Porträts im Kampf;
(5) Komparsen-Rigs werden beim Betreten eines Raums unsichtbar vorgebaut (kein Hänger beim Kampfstart), unsichtbar kosten sie
keine Draw Calls; (6) Komparsen und Beschwörungen ohne Echtzeitschatten. R2/R3 messen mit `tools/perf.sh` (neue Szenarien
`combat_regular`, `combat_two_groups`, `combat_boss_queen`, §12.3).

---

## 9. Show-System, Marotten und 06-Abbildung

### 9.1 Kampf-Log → Hype (ShowRules-Profil `rt`)

`ShowRules` erhält ein Profil (`profile: StringName`, `&"ctb"` | `&"rt"`), gesetzt von `Show.begin_battle(setup)` über
`setup is RtSetup`. Das CTB-Profil bleibt unverändert, bis CTB entfernt wird. Die gesteuerte Einheit kennt ShowRules aus
`RtSetup.controlled_id` und aus `CONTROL_CHANGED`. Startwerte des Echtzeit-Profils (Konstanten `RT_*` in `show_rules.gd`, per
Balancing änderbar, R5a):

| Anlass | CTB | Echtzeit | zählt für |
|---|---|---|---|
| Kampfstart normal / Erstschlag / Hinterhalt / Boss | +3 / +3 / +5 / +8 | gleich | — |
| Abwechslung (Fähigkeit/Gegenstand nicht unter den letzten 4 eigenen Aktionen) | +2 | +1 | **nur Aktionen der Person** (`by_ai == false`: gesteuerte Figur und Partner-Spezial) |
| Wiederholung | −5 (3 × gleich) | −3 (4 × dieselbe Fähigkeit in Folge); die **Slot-1-Fähigkeit ist ausgenommen** (sie ist zum Oft-Drücken da) | nur Aktionen der Person |
| Krit der Party | +3 | +2 | ganze Party |
| Schwäche (einmal je Aktion) | +2 | +1 | ganze Party |
| Kill durch Auto-Angriff / Fähigkeit / Stunt | +1 / +2 / +4 (+`kill_hype`) | gleich | ganze Party |
| Overkill | +3 | +3 (Schwelle §3.9.1) | ganze Party |
| Serie | +5 (3 Kills in 3 Aktionen) | +5 (3 Kills in 6 s) | ganze Party |
| Combo | +2 | +2 (höchstens alle 5 s, Sim-Regel §3.9.1) | ganze Party |
| Stunt Erfolg / Fehlschlag (SHOW, FINALE) | +12 / +4 | gleich — die gemeinsame SHOW-Abklingzeit (30 s, Party) begrenzt beide Figuren zusammen | ganze Party (die KI zündet erst nach 5 s Vorlauf, §4.1) |
| **Unterbrechung** (`CAST_INTERRUPTED`) | — | +3 | **nur gesteuerte Figur** (`actor_id == controlled`, `by_ai == false`) |
| **Ausgewichen** / **knapp ausgewichen** (`TELEGRAPH_DODGED`) | — | +2 / +4 je Telegraph | **nur gesteuerte Figur** (`by_ai == false`; Autopilot-Ausweicher zählen nicht) |
| **Zug-Kill** (Add stirbt durch einen gegnerischen Telegraphen) | — | +4 | — |
| **Perfekte Bossphase** (`PHASE_CHANGE`/`BATTLE_END` mit `success`) | — | +8 | Party |
| **Enrage beginnt** (`ENRAGE`, einmal) | — | +5 | — |
| Party-Mitglied < 25 % HP (einmal je Mitglied und Kampf) | +6 | gleich | — |
| Party-K.O. / Wiederbelebung | +10 / +8 | gleich | — |
| Flucht | −30 | gleich | — |
| Langeweile | −3 bei `TURN_END` ohne positives Ereignis | −2 je 6 s (über `SECOND`) ohne positives Ereignis | — |
| Zweimal Verteidigen | −4 | entfällt | — |
| Schleppen | −3 nach 10 (Boss 25) Party-Aktionen | −3 je 10 s ab 45 s Kampfdauer (Boss ab 4:00) | — |
| Knapper Sieg (≤ 10 % HP) / Makellos | +15 / +3 | gleich | — |

- **Aktion** = `ACTION_START` (Fähigkeit, Stunt, Gegenstand) bis `ACTION_END`; Auto-Angriffe sind keine Aktionen (zählen nicht für
  Abwechslung, Wiederholung, Serie), ihre Kills zählen +1. Ob eine Aktion der Person gehört, sagt `ActionEvent.by_ai` (§3.13):
  KI-Partner, Autopilot und Gegner setzen `true`; eigene Eingaben, gepufferte Eingaben und das Partner-Spezial `false`.
- Grund der Zuordnung: Hype soll belohnen, was die Person tut. Krit, Kills und Combos entstehen gemeinsam und zählen für alle;
  Können-Ereignisse (Abwechslung, Ausweichen, Unterbrechen) und die neuen Achievements (§9.4) nur für die gesteuerte Figur. So
  lässt sich Hype weder durch eine fleißige KI noch durch Dauerdrücken der Hauptfähigkeit „farmen“, und niemand wird für das
  Oft-Drücken von Slot 1 bestraft.
- Kill-Zuordnung für Status-, Zonen- und Telegraph-Kills wie bisher über `KO.actor_id`/`command = −1`.
- `GameState.hype_gain_pm(data)` (Ausrüstung × Talente × Liga × Twist, 06 §8.0 Nr. 4, Ganzzahl-Promille), Sponsor-Schwellen
  70/85/100 und Hype-Verfall (nur Erkundung) bleiben unverändert.

### 9.2 Sponsor-Geschenke im Kampf: die Tick-Grenze

Vor jedem `RtSim.step()` liegt die **Tick-Grenze**. Sie wendet **höchstens ein** Geschenk an — zuerst ein extern angenommenes,
sonst ein fälliges System-Geschenk (Hype-Schwelle). Live (`CombatDirector`) und Replay (`GameReplay`) rufen dieselbe Funktion in
`Game` auf (§10.6):

```gdscript
# autoload/game.gd (R2 block): one tick boundary before combat tick c = combat.tick()
func combat_boundary() -> void:
	var g: Dictionary = Show.take_pending_gift_rt(combat)   # external first (records {"t": "gift", "gift": g, "ct": c}), then system
	if g.is_empty():
		return
	var ev: Array[ActionEvent] = combat.apply_gift(g)        # SPONSOR_GIFT + HEAL / MP_CHANGE / STATUS_ADDED / REVIVE / ITEM_GAINED / CREDITS_GAINED
	for e: ActionEvent in ev:
		Show.on_battle_event(e)
		Events.combat_event.emit(e)
	Show.note_battle_gift(g, ev)
```

Live-Reihenfolge je Tick `c` im `CombatDirector`: (1) `Game.combat_boundary()`, (2) die Probe des `MoveSampler` und alle Eingaben
mit `ct == c` über `Game.combat_submit(cmd)`, (3) `Game.combat_step()`. Ein Geschenk, das während des Ticks eintrifft, wartet in
der Warteschlange von `Show` auf die nächste Grenze; zwei fällige Geschenke gehen an zwei aufeinanderfolgende Grenzen. Das
Replay legt an der Grenze `c` das aufgezeichnete Geschenk mit `ct == c` per `Show.receive_gift` in dieselbe Warteschlange und ruft
dann dieselbe Grenze auf — System-Geschenke entstehen dabei aus denselben Ereignissen neu (nicht aufgezeichnet, 05 §10.6).

- Wirkungen (`GIFT_KINDS`) im Echtzeitkampf: `heal_party_pct`, `heal_party_flat` (× `FIXED_SCALE_PM`), `mp_party_pct`,
  `status_party` / `status_enemies` (Dauer aus dem Geschenk `ms` oder `StatusDef.rt.default_ms`), `item` (ins Inventar),
  `revive_or_heal_lowest` (K.O. → Wiederbelebung 30 %, sonst Heilung des Schwächsten). Gegenstände aus Geschenken zählen nicht
  gegen die 3 Verbrauchsgüter je Kampf (§3.11), solange sie niemand benutzt.
- `Show.take_pending_gift_rt(sim: RtSim) -> Dictionary` (neu, R5a) entspricht `take_pending_gift(battle)` (gleiche Reihenfolge,
  gleiche Grenzen, Aufzeichnung bei der Anwendung, zusätzlich `"ct"`), liest die Gewichtungsbedingungen (`ally_hp_below`,
  `ally_mp_below`, `ally_ko`, `is_boss`) aus `sim.units()`.
- Grenzen unverändert: System-Geschenke höchstens 1 pro regulärem Kampf, 2 pro Bosskampf; externe höchstens
  `rules.gifts.max_per_battle`; Sponsor-Fenster öffnen im Kampf nicht (§2.10).
- Pflichttest (`test_r5_gifts_in_combat`): ein externes und ein System-Geschenk werden im selben Tick fällig → extern an der
  Grenze `c`, System an `c + 1`; das Replay liefert dieselben Ticks, Ereignisse und Hashes.
- Darstellung: Sponsor-Bauchbinde 1,5 s (380 px), Drohne fliegt zum Ziel, Effekt am Ziel, Chat-Jubel; keine Pause, keine
  Eingabesperre.

### 9.3 M.O.D.-Zeilen im Kampf

- **Nur geschriebene Zeilen** (`mod_lines.json`). Im Kampf gibt es **keine KI-generierten Zeilen** und keine Twist-Zeilen (06 §5.7:
  Twists nie im Kampf; 06 §5.8: „M.O.D. live“ füllt Sendepausen auf der Lauf-Uhr, und die steht im Kampf). `Show.say_external`
  lehnt während `Game.in_battle` ab (Rückgabe `false`), Antworten des Dienstes, die im Kampf eintreffen, werden verworfen; nach
  dem Kampf arbeitet `ModLiveLink` normal weiter. Zeilen sind Darstellung (nicht im Log, keine Sim-Wirkung).
- **Eigenes Tag-Präfix `rt_`** (R1a trägt es in `OPTIONAL_MOD_TAG_PREFIXES` ein, §12.3) und **eigener Anker-Block**: R1a legt
  hinter dem Block D (Dateiende nach dem 06-Merge) den Anker `mod_rt_set_quiet_01` an; R4 fügt alle Echtzeit-Zeilen als Block
  direkt dahinter ein, nie hinter fremde Blöcke (Regel 06 §8.0 Nr. 8).
- Tags (R4): `rt_set_quiet`, `rt_flee_warn`, `rt_interrupt`, `rt_dodge_close`, `rt_telegraph_hit`, `rt_train_kill`,
  `rt_healer_first`, `rt_finale`, `rt_finale_hype` (FINALE bei Hype ≥ 85), `rt_enrage:<enemy_id>`,
  `rt_control_switch:kai`, `rt_control_switch:mopsula`, `rt_partner_preset:attack|support|careful`,
  `rt_tutorial_target|bar1|show|dodge`, `rt_hint_interrupt|zone|partner_special|finale|flee|enrage` (§2.13). Bestehende Tags
  (`boss_intro:*`, `boss_phase:*`, `first_fight`, `kai_ko`, `mopsula_ko`, `revive`, `stunt_success`, `stunt_fail`,
  `kill_streak`, `crit`, `weakness`, `overkill`, `low_hp`, `flee`, `boring_fight`, …) gelten weiter.
- Ratenbegrenzung im Kampf: höchstens eine nicht blockierende Zeile je 6 s; Vorrang `boss_phase`/`rt_enrage` > K.O. >
  `rt_control_switch` > Unterbrechung/knappes Ausweichen/Zug-Kill > Rest. Verdrängte Zeilen entfallen (keine Warteschlange im
  Kampf). Hinweiskarten (§2.13) haben Vorrang vor allem und zählen nicht gegen die Rate.
- Tonbeispiele: `rt_interrupt` „Und da wird ihm das Wort abgeschnitten — live und in Farbe!“; `rt_dodge_close` „Zentimeterarbeit!
  Unsere Versicherung atmet auf.“; `rt_flee_warn` „Wo willst du hin? Das Set ist HIER!“; `rt_control_switch:mopsula` „Der Graf
  übernimmt. Möge die Etikette mit uns sein.“; `rt_enrage:enm_boss_hausmeister` „Es ist 17 Uhr. Ab jetzt macht der Hausmeister
  Überstunden — an euch.“; `rt_train_kill` „Bitte zurückbleiben! … Zu spät.“; `rt_partner_preset:careful` (Mopsula) „Vorsichtig?
  Ich bin ein Graf, kein Hasenfuß. Nun gut.“; `rt_finale` „Das FINALE! Kamera drei, ganz nah ran!“

### 9.4 Achievements und Trigger-Payloads

- `battle_won.party_turns` und `boss_defeated.party_turns` = Zahl der `ACTION_START` mit `by_ai == false` im Kampf;
  `encounter_type` aus dem Vorteil; `min_party_hp`, `min_party_hp_pct`, `crits`, `weakness_hits`, `items_used`, `party_kos`,
  `damage_taken` aus `BattleResult` (Bedeutung unverändert). Alle bestehenden Achievements bleiben erreichbar (Prüfliste §12.6
  Nr. 7); `ach_crit_3` und `ach_weakness_5` werden mit mehr Treffern je Kampf leichter — R5a misst sie mit dem Bot und hebt die
  Schwellen in den Daten an, falls sie schon im ersten Kampf fallen.
- Neue Payload-Schlüssel (additiv; R1a trägt sie in `DataValidator.TRIGGER_PAYLOAD_KEYS` ein, §12.3): `battle_won.duration_sec`,
  `.interrupts`, `.dodges`, `.telegraph_hits` (diese drei nur für die gesteuerte Figur), `.train_kills`, `.perfect_phases`.
  Neue `StatIds` (R1a in `stat_ids.gd` und der Validator-Kopie): `interrupts_total`, `dodges_total` (gesteuerte Figur),
  `train_kills`.
- Neue Achievements (Entscheidung O7, R5a; Unterbrechen und Ausweichen zählen nur für die gesteuerte Figur): `ach_interrupt_10`
  „Wort abgeschnitten“ (`s.interrupts_total >= 10`), `ach_dodge_25` „Tanz auf dem Bahnsteig“ (`s.dodges_total >= 25`),
  `ach_train_adds` „Bitte zurückbleiben!“ (`e.train_kills >= 3`), `ach_perfect_phase` „Fehlerfrei auf Sendung“
  (`e.perfect_phases >= 1`); alle mit Trigger `battle_won`. Die Anzahl in `test_m7_data_content` steigt um 4.

### 9.5 `RtMods`: statische Modifikatoren

Systeme außerhalb des Kampfes (Talente, Spezies, Spezialisierung, Ausrüstung, Show-Boss, Kampf-Twists) wirken auf den Kampf
**nur** über Werte, die vor dem Kampf feststehen: über die Combatant-Werte (`Progression.total_stats`, `talent_mods`, §9.6) und
über eine geschlossene Liste von Modifikatoren in `RtSetup.mods`. `BattleBridge.make_rt_setup` (R1) sammelt sie in fester
Reihenfolge (Ausrüstung → Spezies → Spezialisierung → Show-Boss → Twists), kanonisch, Teil von `RtSetup.to_dict()` und damit
jedes Hashes. Während des Kampfes ändert sich die Liste nie — es gibt **keine Twists im Kampf** (06 §5.7) und kein
`RtSim.apply_twist`; ein Twist-Befehl trägt weiterhin nur den Erkundungs-Tick `tick` (kein `ct`).

```json
{"src": "species:<spc_id>" | "spec:<cls_id>" | "equip:<itm_id>" | "showboss:<enc_id>" | "twist:<tw_id>",
 "op": "<OP>", "unit": "p0" | "party" | "enemies" | "boss" | "all", "...": "op-specific"}
```

| `op` (`RtVocab.MOD_OPS`) | Felder | Wirkung | Erste Nutzung |
|---|---|---|---|
| `stat_pm` | `stat` (`str`, `mag`, `def`, `res`, `spd`, `lck`, `max_hp`, `max_mp`), `pm` | Wert × pm/1000 beim Aufbau | Show-Boss (Elite) |
| `skill_pm` | `skill` (Id, `*`, `tag:<show_tag>`, `element:<element>` oder `item:*` für alle Gegenstandswirkungen), `field` (`power`, `cooldown`, `cast`, `mp`), `pm` | Fähigkeitswerte der Einheit | Spezies (E3) |
| `move_pm`, `swing_pm`, `threat_pm`, `dmg_dealt_pm`, `dmg_taken_pm`, `heal_taken_pm` | `pm` | Multiplikatoren (Schaden über die Faltung §3.9.1) | Twists (später) |
| `first_hit_taken_pm` | `pm` | erster erlittener Schaden der Einheit im Kampf × pm | Spezies (E3) |
| `on` | `event` (`combat_start`, `kill`, `interrupt`, `dodge`, `crit`, `ko_ally`, `show_success`), `effect` (`{"heal_pct": int}` \| `{"mp": int}` \| `{"status": id, "ms": int}`) | Reaktion der Sim auf Ereignisse der Einheit | Spezies (E3) |
| `add_rule` | `rule` (`RtRule`, §5.3), `shared: bool` | hängt die Regel an jede betroffene Einheit (alle Phasen); `shared` = **ein** Regel-Timer für alle (der erste freie Gegner feuert, dann warten alle `every_ms`) | Show-Boss |
| `element_swap` | — | Schwächen (> 1000) ↔ Resistenzen (< 1000) der Element-Faktoren tauschen; Immunität bleibt | `tw_mirror_room` (später) |
| `extra_enemy` | `enemy` (`"first"` oder Id), `count` 1…2 | zusätzliche Gegner als Komparsen mit Auftritt, nur bis `MAX_ENEMIES`, nie im Bosskampf | `tw_double_trouble` (später) |
| `forbid_skill` | `skill` | Fähigkeit gesperrt (`ACTION_REFUSED forbidden`) | Event-Regeln |
| `forbid_items` | `tag` | Gegenstände mit Tag gesperrt | Event-Regeln |
| `unlock_variant` | `slot`, `skill` | schaltet eine Leisten-Variante frei (wirkt auf die Belegung außerhalb der Sim) | Spezialisierung (E3) |

- API (`core/rt/rt_mods.gd`, R1): `validate(mods: Array) -> PackedStringArray` (Fehlerliste, nur Ganzzahlen, Vokabulare aus
  `RtVocab`), `apply_static(setup: RtSetup, data: GameData) -> void` (alle Ops außer `on`, in Listenreihenfolge, beim Aufbau),
  `on_event(sim: RtSim, e: ActionEvent) -> Array[ActionEvent]` (nur `on`), `from_twists(state: GameState, data: GameData) ->
  Array[Dictionary]`, `from_show_boss(enc: EncounterDef) -> Array[Dictionary]`.
- Show-Wirkungen (Hype-, Follower-, Liga-Faktoren, Marotten) bleiben im Show-System. Die Unterhosen-Liga ist eine Ausrüstungsregel
  („ohne Rüstung & ohne Accessoire“, 06 §4.3) und wirkt nur über die Werte der Ausrüstung und über Show-Faktoren — nie über eine
  eigene Kampfregel.
- **Kampf-Twists** (06 §5.6, Bereich `battle`/`boss`): `RtMods.from_twists` liest beim Aufbau die aktiven Einträge in
  `GameState.flags["live"]["twist"]` mit `battles_left > 0`; heruntergezählt wird unverändert in `TwistApplier.on_battle_end`
  (über `Game.apply_battle_result`).

| Twist (06 §5.6) | Bereich | Wirkung im Echtzeitkampf | Slice |
|---|---|---|---|
| `tw_party_hats` | battle | nur Show: Hype-Gewinne × 1,2 über `TwistApplier.effect_pm` (unverändert); Hüte als Optik | ✓ |
| `tw_double_credits` | explore | Credits aus Kämpfen über `BattleBridge.apply_result` (unverändert); keine Sim-Wirkung | ✓ |
| `tw_lights_out`, `tw_quiet_please`, `tw_fog_of_fame`, `tw_confetti_gravity` | explore | keine (Wahrnehmung und Hype-Verfall der Erkundung) | ✓ |
| `tw_rat_rain` | instant | keine: eine Streuner-Gruppe in der Erkundung; zieht man sie, ist es ein normaler Kampf | ✓ |
| `tw_mirror_room` | battle | `element_swap` auf `enemies` | später |
| `tw_elite_guest` | battle | `stat_pm` `max_hp` 1200 und `str` 1200 auf `enemies`; EXP/Credits × 2 in `BattleBridge` | später |
| `tw_double_trouble` | battle | `extra_enemy` `first` 1 (nicht im Bosskampf, nur bis 6 Einheiten); EXP/Credits × 1,5 | später |
| `tw_sponsor_rush` | battle | nur Show (SponsorSystem) | später |
| `tw_boss_mood` | boss | `aggressive`: `swing_pm` 850 + `dmg_dealt_pm` 1100 auf `boss`; `vain`: `dmg_taken_pm` 1100 auf `boss` („posiert lieber“) | später |
| Präsentations-Twists (`tw_mopsula_*`, `tw_mod_mood`, `tw_costume`) | presentation | keine Sim-Wirkung; im Kampf erscheinen keine Twist-Zeilen | — |

### 9.6 06-Abbildung: Held:in, Talente, Marotten, Show-Boss, Spezies

**Held:in und Partner (06 §1, Paket A):**

| 06 | Echtzeitkampf |
|---|---|
| `GameState.hero` (`"kai"` \| `"mopsula"`) | gesteuerte Einheit `RtSetup.controlled_id`; der Partner ist immer KI mit Taktik und **Partner-Spezial** (§5.1) |
| Kapsel/Tempo je Figur (06 §1.2) | `party.json → rt`: Kai Radius 40 cm, Mopsula 35 cm; beide 550 cm/s |
| Feldschlag (Kai) / Bellen → `DAZED` (Mopsula, 06 §1.3) | Feldschlag ist ein Pull; Bellen startet nie einen Kampf, aber ein Pull auf eine angebellte Gruppe ist ein Erstschlag (§2.2) |
| „Partner automatisch“ (06 §1.4, nur CTB) | entfällt — im Echtzeitkampf ist der Partner immer KI; die Optionszeile ist im Echtzeitmodus ausgeblendet |
| Stern-Marker am Party-Panel (Paket A) | Pille „DU“ am Party-Rahmen der gesteuerten Figur (§8.4) |
| K.O. der Held:in | Steuerung folgt dem Leben, vorübergehend (`CONTROL_CHANGED`, `rt_control_switch:<member>`, §2.6); `GameState.hero` bleibt |
| Wechsel im Safe Room (06 §1.6) | wirkt ab dem nächsten Kampf |

**Talente (06 §2.2, Paket B) — jede Wirkungsart:**

| `kind` | CTB-Anwendung | Echtzeitkampf |
|---|---|---|
| `stat_flat`, `stat_pct`, `liga_stat_pct` | `Progression.total_stats` | gleich: Werte der `RtUnit` (HP-Skala §3.9.4 danach) |
| `crit_add_pm` | `Combatant.crit_bonus` | gleich: Krit-Formel §3.9.1 |
| `element_pm` | `Combatant.element_mods` | gleich: `DamageCalc`; Status-Takte mit Element §3.8 |
| `post_battle_mp_pm` | `BattleBridge.apply_result` | gleich: Werbepause nach jedem Sieg (§2.7) |
| `field_range_pm`, `field_cd_pm` | Feldschlag/Bellen (`EncounterRules`) | gleich; die Feldschlag-Reichweite gilt auch für den Pull per Feldschlag |
| `preemptive_dmg_pm` („Erster Eindruck“) → `talent_mods.preemptive_dmg_pm` | erster eigener Zug nach einem Präventivschlag | Faktor `opener_pm` in der Faltung (§3.9.1): bei Vorteil `PREEMPTIVE` auf alle Treffer der Einheit gegen Ziele mit `sts_dazed` (die 3 s des Überrumpelns) und auf ihren ersten schadenden Treffer im Kampf (`opener_done`) |
| `stunt_window_pm` („Taktgefühl“) → `talent_mods.stunt_pm` | Stunt-Chance × pm vor Boss-Abzug und Deckel | SHOW-Erfolgschance in bp in derselben Reihenfolge: `clampi(div_round((base + LCK × lck) × stunt_pm, 1000) + boss, STUNT_MIN, cap)` |
| `marotte_heart` | `MarottenRules` | gleich |
| `hype_gain_pm`, `follower_pm` | `GameState`-Promille-Produkt | gleich |

Die Talentwahl findet nur in der Talent-Show im Safe Room statt; das Kampfergebnis zeigt höchstens den Chip „TALENT BEREIT“
(§8.9). Talente brauchen keine `RtMods`-Einträge: `RtUnit` erbt `talent_mods` von `Combatant`.

**Marotten (06 §4, Paket C):** Der `MarottenTracker` bekommt im Echtzeitkampf denselben Ereignisstrom (über
`Show.on_battle_event`, live und im Replay identisch) und liest zusätzlich `by_ai` (R5a, additiv). Regel: **Zähler einer
Spielweise zählen nur Aktionen der Person** (`by_ai == false`); Zustände und Ergebnisse zählen für die ganze Party.

| Kontext-Schlüssel (06 §4.6) | Echtzeit-Quelle |
|---|---|
| `won`, `hero`, `is_boss`, `is_floor_boss`, `boss_id`, `encounter_type`, `kai_weapon`, `equip_all_common`, `hero_armor_empty`, `hero_acc_empty`, `party_armor_empty`, `party_acc_empty`, `liga_tier`, `min_party_hp_pct`, `party_kos`, `items_used`, `weakness_hits` | wie CTB aus `BattleResult` und Zustand (`items_used` = Verbrauchsgüter der Party, höchstens 3) |
| `party_turns` | `ACTION_START` mit `by_ai == false` |
| `distinct_actions` | verschiedene Fähigkeits-/Gegenstands-Ids der `ACTION_START` mit `by_ai == false` (gesteuerte Figur und Partner-Spezial); Auto-Angriffe zählen nicht |
| `stunts_success` | `STUNT_RESULT` mit `success` und `by_ai == false` |
| `defends` | immer 0 (es gibt kein Verteidigen) |
| `flee_attempts` | `BattleResult.flee_attempts`: jeder Beginn einer Fluchtwarnung (0,5 s außerhalb des Rings) und jeder Nebel |
| `last_kill_member` | Mitglied, dessen Treffer, Status oder Fläche den letzten Gegner-K.O. auslöste (auch als KI-Partner); Zug-Kills `""` |
| `gifts` | im Kampf angewendete Geschenke |
| **neu** `duration_sec` | `BattleResult.duration_ticks / 30` (R5a in `MarottenRules.battle_context`) |

| Marotte | Im Echtzeitkampf |
|---|---|
| `mar_mop_only`, `mar_secondhand`, `mar_pacifist` | unverändert (Ausrüstung bzw. Erkundung) |
| `mar_graf_finale` (Starter) | der letzte Gegner fällt durch Mopsula — gesteuert oder als KI-Partner |
| `mar_variety` (Starter) | 4 verschiedene eigene Aktionen; schon auf Stufe 1 möglich (Slot 1, SHOW, Trank, Partner-Spezial) |
| `mar_sneaky` (Starter) | Erstschlag: Pull von hinten oder auf eine angebellte Gruppe |
| `mar_stunt` | eine eigene SHOW gelingt |
| `mar_bio` | keine Verbrauchsgüter, keine Geschenke im Kampf |
| `mar_brave` | keine Fluchtwarnung, kein Nebel |
| `mar_gourmet` | 3 Schwächetreffer (Party, wie CTB) |
| `mar_speed` | kein Starter, auf Etage 1 nie aktiv; mit Etage 2 bekommt `marotten.json` die Echtzeit-Bedingung `e.duration_sec <= 15 && e.is_boss == false` („Kämpfe unter 15 Sekunden“) |
| Unterhosen-Liga (`mar_unterhose`) | Stufe zu Kampfbeginn wie bisher; wirkt über Hype-/Follower-Faktoren, im Kampf ohne eigene Regel |

**Show-Boss (06 §2.6, Paket C):** `ShowBossRules.apply` (CTB: Elite + Zusatzaktion „jeder 3. Gegnerzug“) hat im Echtzeitkampf
den Nachfolger `RtMods.from_show_boss(enc)`; er liest denselben `show_boss`-Block von `enc_e1_showboss`:

```json
[{"src": "showboss:enc_e1_showboss", "op": "stat_pm", "unit": "enemies", "stat": "max_hp", "pm": 1200},
 {"src": "showboss:enc_e1_showboss", "op": "stat_pm", "unit": "enemies", "stat": "str", "pm": 1200},
 {"src": "showboss:enc_e1_showboss", "op": "add_rule", "unit": "enemies", "shared": true,
  "rule": {"skill": "skl_e_showboss_slow", "target": "threat_top", "first_ms": 4000, "every_ms": 8000}}]
```

„Hausordnung verschärft“ heißt im Echtzeitkampf: **alle 8 s** verteilt die Gruppe einen Strafzettel (`skl_e_showboss_slow`, neu
R4: sofort, Reichweite 1500, kein Schaden, `sts_slow` 3 s zu 100 %, GCD-frei). Die Regel steht beim Kampfstart auf der
Bauchbinde („Hausordnung verschärft: alle 8 Sekunden ein Strafzettel“). Belohnung und Zeilen (`showboss_*`) bleiben bei 06.

**Spezies-Passive (06 §3.2, ab Etage 3 — Vorschlag, gebaut mit Etage 3):** `pas_authentic` → nur Show; `pas_grout` →
`first_hit_taken_pm` 700; `pas_lightdrunk` → Krit +10 % am Combatant, wenn der Hype **beim Kampfstart** ≥ 70 ist (statisch, weil
der Hype außerhalb der Sim entsteht); `pas_spores` → Gift-Immunität über `status_immune` und Element-Faktor wie bei Gegnern (beim
Aufbau des Combatants) + `on combat_start` mit einer schwachen `sts_regen`-Variante (+1 % alle 3 s, neuer Status in den Daten);
`pas_coin_slot` → `skill_pm` `item:*` `power` 1250; `pas_ember` → `skill_pm` `element:fire` `power` 1150; `pas_see_through` →
`first_hit_taken_pm` 500; `pas_court_flight` → `on combat_start` `sts_haste` 3 s (Bellen-Reichweite: Erkundung). Alles über
bestehende `MOD_OPS` und Combatant-Felder — Etage 3 braucht keine neue Sim-Funktion, nur Daten.

---

## 10. Live, Replay und Netz

### 10.1 Befehle

Alle Werte Ganzzahlen bzw. Strings; Positionen raumlokal in cm; `u` = Einheiten-Id; `target` = Einheiten-Id oder `""`. Bauhelfer
und Prüfung in `RtCommand` (§3.4).

| `t` | Form | Bemerkung |
|---|---|---|
| `encounter` (erweitert) | `{"t": "encounter", "enc", "adv", "group", "rt": {"v": 1, "cell": [cx, cy], "ctl": "p0", "party": [{"u": "p0", "p": [x, z, yaw]}, {"u": "p1", "p": [x, z, yaw]}], "groups": [{"group": "f1_g3", "enc": "enc_f1_a2", "lead": [x, z, yaw], "state": "PATROL"}], "presets": {"p1": {"preset": "support", "tog": {"interrupt": true, "show": true, "potions": false}}}, "auto": true, "retarget": true, "open": {}, "diff": "prime"}}` | ohne `rt` = CTB-Kampf (bis R5b) |
| `ability_use` | `{"t": "ability_use", "ct", "u", "skill", "target"}` | |
| `target_change` | `{"t": "target_change", "ct", "u", "target"}` | |
| `move_sample` | `{"t": "move_sample", "ct", "u", "p": [x, z, vx, vz, yaw]}` | Grad A (§3.5.1); `vx`/`vz` mm/Tick |
| `combat_item` | `{"t": "combat_item", "ct", "u", "item", "target"}` | heißt bewusst nicht `use_item` (Feldbefehl) |
| `partner_preset` | `{"t": "partner_preset", "ct", "u", "preset", "tog": {...}}` | |
| `partner_special` | `{"t": "partner_special", "ct", "u"}` | `u` = Partner-Einheit (§3.6.13) |
| `auto_attack` | `{"t": "auto_attack", "ct", "u", "on": bool}` | |
| `autopilot` | `{"t": "autopilot", "ct", "u", "on": bool}` | Regel `rules.combat.autopilot` (§10.7) |
| `combat_hint` | `{"t": "combat_hint", "ct", "id"}` | Hinweiskarte gezeigt (§2.13); die Sim ignoriert ihn, `RunSim`/`GameReplay` setzen `flags["rt_hints"][id]` |
| `move_input` | `{"t": "move_input", "ct", "u", "dir": [dx, dz], "run": bool}` (`dx`, `dz` −127…127) | **reserviert für Grad B** (Server rechnet die Spielerbewegung, §10.8); bis dahin lehnt `submit` mit `grade_b` ab |
| `gift` (im Kampf) | bestehend + `"ct"` | extern, Id 0, aufgezeichnet bei der Anwendung an der Tick-Grenze (§9.2) |
| `combat_speed` | `{"t": "combat_speed", "pm": 850}` | Spieltempo geändert (oder ≠ 1000 beim Laufstart); keine Sim-Wirkung, Kennzeichnung „Zeitlupe“ (§10.7) |
| `move_batch` | `{"t": "move_batch", "u", "id0", "s": [[dct, x, z, vx, vz, yaw], …]}` | nur in gespeicherten Logs (§10.3) |

Ein `twist`-Befehl kommt im Kampf nie vor (06 §5.7: Anwendung nur in der Erkundung); er trägt weiterhin nur `tick`, kein `ct`.

`RtCommand.validate(d) -> String`: Typ bekannt, Pflichtfelder, Ganzzahlen, `ct ≥ 0`, `|x|, |z| ≤ 2400`, `|vx|, |vz| ≤ 400`,
`yaw` 0…255, `|dx|, |dz| ≤ 127`, Einheiten-Id `^p[0-3]$` bzw. `^e[0-9]+$`, `preset` ∈ `RT_PRESETS`, `tog`-Schlüssel ∈
`RT_TOGGLES`, `id` ∈ `TUTORIAL_STEPS` ∪ `HINT_IDS`, `pm` ∈ {1000, 850, 700}. `Command.TYPES` wird um die neuen Typen erweitert und
delegiert ihre Prüfung an `RtCommand.validate` (R1a: Stub, R1b: Regeln).

### 10.2 Aufzeichnung und Reihenfolge

- Lauf-Tick `k` aller Kampf-Befehle = `k` des `encounter` (die Uhr steht, `explore_only`). Reihenfolge im Kampf: `ct`
  nicht fallend, dann Befehls-Id. `RunLog.validate` prüft das zusätzlich (zwischen `encounter` mit `rt` und Kampfende).
- Alle Kampf-Befehle (auch Proben und `combat_hint`) erhalten fortlaufende Ids; externe Geschenke Id 0.
- Aufgezeichnet wird jeder von `RtSim.submit` angenommene Befehl (§3.4); abgelehnte nicht. `combat_hint` und `combat_speed`
  zeichnet `Game` direkt auf.
- **Kampf-Prüfpunkte:** alle `CHECKPOINT_TICKS = 300` Kampf-Ticks und beim Kampfende `{"k": k, "ct": ct, "h":
  StateHash.of_rt(sim)}` (`RunLog.add_checkpoint(k, h, ct = -1)`, additiv); danach wie bisher ein Zustands-Prüfpunkt nach dem
  Kampf.
- Kopf: `"combat_mode": "realtime"`, `"rt_version": 1`; `sim_version` wird erhöht.
- Das Kampfende ist **kein** Befehl: die Sim bestimmt es. Ein Kampf-Befehl mit `ct` nach dem Ende ist ein Replay-Fehler
  (`combat_cmd_after_end`). Der End-Prüfpunkt bestätigt Tick und Zustand.
- `timer_mode: realtime` (05 S4, später): `k = k_encounter + ct`.

### 10.3 Kompaktierung

`move_sample` macht 60–70 % der Kampfeinträge aus. Schätzung: ≈ 70 Byte je Eintrag, ≈ 4 Proben/s in Bewegung → 3-min-Bosskampf
≈ 720 Einträge ≈ 50 KB, eine Etage (≈ 12 min Kampf) ≈ 200 KB roh, ≈ 30 KB gzip. `RunLog.compact()` fasst **aufeinanderfolgende**
`move_sample`-Einträge derselben Einheit ohne andere Einträge dazwischen zu `move_batch` zusammen (Ids fortlaufend ab `id0`,
`ct` als Differenzen); `RunLog.expand()` stellt die Einträge bitgenau wieder her. Prüfung und Replay arbeiten auf der expandierten
Form; Hashes sind unabhängig davon. Live-Streams übertragen unkompaktierte Einträge.

### 10.4 StateHash-Abdeckung

`StateHash.of_rt(sim: RtSim) -> String` = Hash über `CanonicalJson` von `sim.snapshot()`:

- Kampf: `ct`, `rng_n`, nächste Einheiten-/Telegraph-Nummer, `controlled_id`, Ende/Ergebnis, Party-Abklingzeiten (`show`,
  Verbrauchsgüter, Anzahl benutzt), Combo-/Serien-Zähler, Bilanzzähler.
- Je Einheit: alle Felder aus §3.4 (`RtUnit`) plus `Combatant`-Felder (HP, MP, Werte, Status als `RtStatus.to_dict`, Phase,
  `used_once`, Belohnungen, `talent_mods`); Wörterbücher (`threat`, `cooldowns`, `rule_ready`) mit sortierten Schlüsseln.
- Telegraphen/Zonen (alle Felder, `inside_last` sortiert), ausstehende Treffer, eingereihte Befehle (nach `ct`, Reihenfolge),
  `RtSetup.mods`.
- Nichts Spielrelevantes ist ausgenommen (die Sim enthält keine Darstellungsdaten).

`StateHash.of(GameState)` bleibt; neue Felder (`GameState.combat_mode`, `FloorRun.regen_ticks`, `PartyMember.hp_scale_pm`,
`rt_preset`, `rt_toggles`, `rt_loadout`, `flags["rt_hints"]`) werden **nur serialisiert, wenn sie vom Standard abweichen** —
bestehende Golden-Hashes der CTB-Tests bleiben gültig.

### 10.5 RunSim-Integration (R5a; Regeneration R1b)

```gdscript
var combat: RtSim = null                    # running real-time combat (RunSim-driven runs)
# apply({"t": "encounter", ..., "rt": {...}}):
#   setup = BattleBridge.make_rt_setup(state, data, c, next_seed("battle")); next_seed("show")  # same streams as CTB
#   combat = RtSim.new(setup, data); last_action_events = combat.start(); quest feed
# apply(<combat command with ct>):  _advance_combat_to(int(c["ct"]))   # step() until tick() == ct
#   gift:         combat.apply_gift(c["gift"])       # boundary of tick ct, before the commands of that tick
#   combat_hint:  state.flags["rt_hints"][id] = true # the sim ignores it
#   otherwise:    var r := combat.submit(c)          # r != "" → rejected_cmds, warning
# apply(<any other command>) and replay end:  _finish_combat()  (run_to_end(MAX_COMBAT_TICKS - tick), apply_result,
#   checkpoint due, regen_ticks = 0)
# is_clock_running(): false while combat != null
# _tick_once(): new step 6 regeneration (§2.7, only combat_mode == realtime)
```

RunSim-Kernläufe enthalten wie bisher keine System-Geschenke und keine Show-Reaktionen (05 §11.4); vollständige Live-Läufe
reproduziert `Game.replay_log`.

### 10.6 `Game.replay_log`-Äquivalenz: die exakte Schleife

`Game` (R2-Abschnitt) bietet `make_rt_setup(cmd: Dictionary) -> RtSetup` (zeichnet `encounter` auf, zieht die Seeds, ruft
`Show.begin_battle`), `combat_boundary() -> void` (§9.2), `combat_submit(cmd: Dictionary) -> String` (`RtSim.submit` + `record`),
`combat_hint(id: String) -> void`, `combat_step() -> Array[ActionEvent]` (ein Tick, speist jedes Ereignis in
`Show.on_battle_event` und `Events.combat_event`, schreibt Kampf-Prüfpunkte) und `end_combat() -> BattleRewards`. Der Live-
`CombatDirector` und `GameReplay` benutzen **genau diese** Funktionen:

```
Game.make_rt_setup(encounter)
c = 0
solange der Kampf nicht beendet ist:
    wenn das nächste Log-Element ein gift mit ct == c ist: Show.receive_gift(gift)   # höchstens eins je Tick
    Game.combat_boundary()                                                          # Grenze c: höchstens ein Geschenk
    für jedes weitere Log-Element mit ct == c (Log-Reihenfolge):
        combat_hint → Game.combat_hint(id)   sonst → Game.combat_submit(e)          # Ablehnung = Replay-Fehler
    Game.combat_step()                                                              # Tick c, danach c = c + 1
ein Log-Element mit ct < c oder ein Kampf-Element nach dem Ende → Replay-Fehler
Game.end_combat()
```

Live ruft der `CombatDirector` je Tick genau einmal `combat_boundary`, dann `combat_submit` für die Probe und alle Eingaben mit
diesem `ct`, dann `combat_step` (§9.2). Während einer Hinweiskarte ruft er nichts davon auf (§2.13). Pflichttest
(`test_r5_rt_live_equivalence`): ein geskripteter Live-Lauf über die `Game`-API (headless, mit externen Geschenken, einem
System-Geschenk im selben Tick, Hinweiskarten, Steuerungswechsel, Flucht und Niederlage) und sein `Game.replay_log` liefern
identische GameState-Hashes, identische Kampf-Prüfpunkte und identische Show-Zahlen (Hype, Follower, Zuschauermodell,
Achievements, Marotten-Strichliste). Die FINALE-Bedingung prüft die Sim selbst (§4.1), das Replay braucht dafür nichts.

### 10.7 Pur-Liga, Event-Regeln, Bestenlisten

- Pur-Liga: keine externen Geschenke (GiftPolicy unverändert), keine spielrelevanten Twists (06 §5.7).
- Neue optionale Regeln `rules.combat` (Teil von `rules_hash`): `autopilot` (Standard `false` in Ligen → `submit` lehnt mit
  `forbidden` ab), `assist` (Standard `true`), `hints` (Standard `false` in Ligen, §2.13), `max_enemies` (Standard 6).
- **Spieltempo (Entscheidung O1):** überall erlaubt. Jeder Wechsel wird als `combat_speed` aufgezeichnet; ein Lauf mit einem Wert
  < 1000 trägt auf Bestenlisten das Abzeichen „Zeitlupe“ und lässt sich getrennt filtern. Die Sim ist bei jedem Tempo gleich.
- Bestenlisten: Replay muss bitgenau sein. Die Spielerbewegung ist bis Grad B client-seitig mit Plausibilitätsgrenzen (§3.5.2):
  der Verifier zählt `POS_CORRECTED` (ehrliche Läufe: 0) und führt eine Ausreißer-Statistik („perfekte Ausweicher“), die markiert,
  aber nicht ablehnt. Gewertete Echtzeit-Bestenlisten heißen bis Grad B „plausibilitätsgeprüft“ (05 §3.3).

### 10.8 Später: Koop (2–4) und MMO-lite, server-autoritativ

- Dieselbe `RtSim` läuft auf dem Server (Godot headless, 05 §3.2) mit 30 Hz. Jede Person steuert eine Party-Einheit (`u`); freie
  Plätze spielt die Partner-KI.
- **Bewegung Grad B:** Clients senden `move_input` (Richtung + Laufen); der Server bewegt die Einheit mit derselben Lenkung wie
  KI-Einheiten (`move_cm_tick × move_pm`, `RtGeo.project_walkable`) — im requisitenfreien Set reichen Kreis, Türgassen und
  Sperrflächen, keine Physik. Clients sagen **nur die eigene Bewegung** voraus (lokaler `CharacterBody3D`) und gleichen bei
  Abweichung > 25 cm ab (05 §3.5); andere Einheiten 100 ms verzögert interpoliert.
- Der Server stempelt `ct` = Server-Tick beim Eingang (+ 2 Ticks Eingangspuffer), prüft und wendet an; kein Rollback. Er sendet
  Ereignisse (zuverlässig, geordnet) und Schnappschüsse mit 15 Hz (Position, Gier, HP, MP, Zauber, Ziel ≈ 14 Byte je Einheit;
  10 Einheiten ≈ 2,1 KB/s je Client). Eigene Tastendrücke zeigen sofort die Animation, die Wirkung nach Bestätigung.
- Latenzbudget: RTT ≤ 150 ms „gut“; das Queue-Fenster (300 ms) deckt das ab; die kürzeste Telegraph-Warnzeit (1,0 s) ist ≥ 6 × RTT.
  Lag-Kompensation für Telegraph-Treffer: Der Server prüft die Position zum Tick `impact − min(rtt/2, 6 Ticks)` aus dem
  Probenverlauf (höchstens 200 ms zurück).
- Regeln mit Personen: „Steuerung folgt dem Leben“ wechselt nur zu KI-Einheiten, nie zu einer Einheit einer anderen Person (fällt
  die eigene Figur, schaut man zu bis zur Wiederbelebung); das Partner-Spezial befiehlt nur KI-Einheiten (ohne KI-Partner gibt es
  keinen Knopf); SHOW-Abklingzeit und die 3 Verbrauchsgüter je Kampf gelten für die ganze Party („Wer zündet?“ ist Teamspiel);
  Können-Hype (§9.1) zählt für jede Person, die eine Einheit steuert. Keine Hinweiskarten, keine Pause.
- Raids: Obergrenzen werden Regeln (`max_enemies`); Kosten pro Tick linear in Einheiten + Telegraphen; mehr Spieler-Rigs brauchen
  das Rig-LOD aus §8.10.

---

## 11. Balancing-Ziele

### 11.1 Zielwerte (Etage 1, Profil `typical`, Erstspieler-Modell GDD §13)

| Größe | Ziel | Herkunft / Messung |
|---|---|---|
| Kampfdauer regulär (TTK der Gruppe) | 15–35 s, Median 20–25 s | Auftrag; Harness |
| Kampfdauer Der Hausmeister | 2:30–3:30 | Auftrag 2,5–4 min, GDD §13; Harness |
| Kampfdauer Die Rattenkönigin | 3:00–4:00 | Auftrag 2,5–4 min (GDD §13 nannte 3,5–5 für CTB); Harness |
| HP-Verlust der Party je regulärem Kampf (ohne Tränke, in % der Summe Max-HP) | 20–35 % | GDD §13; Harness |
| Kämpfe zwischen zwei Safe Rooms ohne Tränke | 2–3 | GDD §13; Etagenfolge-Harness (prüft die Regeneration §2.7) |
| Verbrauchte Heilgegenstände je Etage | 4–9 (Bosskämpfe je höchstens 3) | neu; Etagenfolge-Harness |
| Erstversuch-Niederlage Hausmeister / Königin, **je Held:in** | ≈ 20 % (10–30 %) / ≈ 35 % (25–45 %) | GDD §13; Harness `--hero=kai` und `--hero=mopsula` |
| … in der Unterhosen-Liga Stufe 1 / Stufe 2 | ≤ 40 % / ≤ 55 % bzw. ≤ 55 % / ≤ 70 % | 06 §4.10; Harness `--liga=1|2` |
| Stufe bei Hausmeister / Königin | 5 / 7 | GDD §13; R5-Full-Run |
| Etagenzeit Timer-Nutzung (Erkundung) / gesamt | 11–15 min / 22–28 min | GDD §13; R5-Full-Run |
| Unterbrochene unterbrechenswerte Boss-Zauber | ≥ 60 % | neu; Harness |
| Party-Treffer durch Boss-Telegraphen | ≤ 25 % der Einschläge, die ein Mitglied hätten treffen können | neu; Harness |
| Hype Start/Ende der Etage, Geschenke je Etage, Follower, Spitzen-Zuschauer | 25–45 / 45–65, 4–7, 1 200–1 500, 3 000–5 500 | GDD §13; R5-Full-Run |

### 11.2 Stellschrauben (Reihenfolge der Anpassung)

Alle Zahlen stehen in Daten — `data/rt_balance.json` (§3.16) und die `rt`-Blöcke (§4.6–4.9) —, Eigentum R4; Code ändert sich dafür
nicht.

1. Gegner-HP (`ENEMY_HP_PM`, je Gegner `rt.hp_pm`, Boss `rt.hp`) → Kampfdauer.
2. Gegner-Takt (`swing_ms`), `rt.dmg_pm`, Regel-Wiederholung (`every_ms`), `pct_maxhp` der Telegraphen (15–30 %) → HP-Verlust.
3. Telegraph-Warnzeiten, Zonen-Dauer → Fairness, Ausweichquote.
4. Party: `rt.power`/`rt.mp`/`cooldown_ms` einzelner Fähigkeiten, MP-Laden (`mp_regen`, `HIT_MP_EVERY_TICKS`), `HP_SCALE_PM`.
5. `REGEN_*`, `ITEM_CD_TICKS`, `ITEM_MAX_PER_COMBAT` → Tränke je Etage, Kämpfe zwischen Safe Rooms.
6. Partner-KI: `REACT_TICKS`, `AI_INTERRUPT_REACT_TICKS` (Startwert 0), Heil-Schwellen der Presets → Abstand zwischen den
   Held:innen (§11.3).
7. Enrage-Zeit (weich), Boss-Phasenschwellen.
8. ShowRules-`RT_*` → Hype/Geschenke/Follower.

Formeln (GDD §3.7) und Krit/Varianz bleiben fest.

### 11.3 Startwerte und Überschlag (Monte-Carlo-Modell)

Die Startwerte dieses Dokuments sind mit einem vereinfachten Modell nachgerechnet (Python, Wegwerf-Skript außerhalb des
Repositorys; ganzzahlige Formel GDD §3.7, Taktung, GCD, MP-Ökonomie §3.10, Telegraphen als Prozent-Treffer, DoT-Deckel, Tränke mit
Party-Abklingzeit und Deckel, Partner-KI nach §5.4, Bot-Profile §5.7; 200 Seeds je regulärer Begegnung, 400 je Boss und Profil).
Maßgeblich sind später die Harness-Messwerte (§11.5); die Tabelle zeigt, dass die Startwerte in den Bändern liegen.

| Begegnung (Stufe) | TTK Median [P10–P90] | HP-Verlust Median |
|---|---|---|
| `enc_f1_a1_tutorial` (1) | 22,0 s [19,5–24,0] (ohne Hinweiskarten) | 10 % (Gegnerschaden × 0,5) |
| `enc_f1_a2` / `a3` / `a4` (2) | 16,0 / 16,5 / 16,0 s | 20 / 16 / 20 % |
| `enc_f1_b1` / `b2` / `b3` / `b4` (3) | 19,5 / 18,1 / 20,0 / 33,3 s | 22 / 21 / 19 / 22 % |
| `enc_f1_c1` (4), `c2` / `c3` (5) | 15,7 / 18,0 / 24,0 s | 22 / 14 / 23 % |
| `enc_f1_d1` / `d3` (6), `d2` (7) | 20,2 / 28,5 / 22,5 s | 14 / 21 / 21 % |
| **alle regulären** | **Median 19,8 s (15,7–33,3 s)** | **Median 21 % (10–23 %)** |

Kai drückt den Wuchtschlag auf ≈ 75 % seiner GCDs (MP-Ökonomie §3.10 trägt). Ohne die eigene HP-Zahl des Kanalschleims
(`rt.hp_pm` 4800) dauerte `b4` (zwei Schleime + Schamane) 42 s — der Schleim halbiert physischen Schaden.

| Boss (Stufe), Profil | Niederlage | Dauer Median [P10–P90] | Tränke | unterbrochen | Telegraph-Treffer |
|---|---|---|---|---|---|
| Hausmeister (5), `typical`, Held:in Kai | **19 %** | **2:41** [2:33–2:51] | 3,0 | 94 % | 12 % |
| Hausmeister, `perfect` / `sloppy` | 0 % / 90 % | 2:28 / 3:10 | 3,0 / 3,0 | 96 / 62 % | 2 / 23 % |
| Hausmeister, `typical`, Held:in Mopsula | 3 % | 2:42 | 3,0 | 95 % | 11 % |
| Rattenkönigin (7), `typical`, Held:in Kai | **37 %** | **3:23** [3:14–3:33] | 3,0 | 86 % | 11 % |
| Rattenkönigin, `perfect` / `sloppy` | 2 % / 95 % | 3:06 / 3:56 | 3,0 / 2,9 | 93 / 64 % | 3 / 19 % |
| Rattenkönigin, `typical`, Held:in Mopsula | 3 % | 3:24 | 2,6 | 95 % | 12 % |

Lesart und Folgen für R4:

- `typical` mit Held:in Kai trifft die Ziele (≈ 20 % / ≈ 35 %, Dauer im Band); Unterbrechungen und Telegraph-Treffer liegen weit
  innerhalb der Grenzen. Bosskämpfe brauchen die erlaubten 3 Tränke — der Deckel wirkt, Tränke zählen, entscheiden aber nicht.
- Die Kurve zwischen `perfect` und `sloppy` ist steil (0–2 % gegen 90–95 %): Ein Bosskampf belohnt Können deutlich. R5b kalibriert
  `typical` an echten Probespiel-Läufen (§11.4), bevor die Bänder als hart gelten.
- **Held:in Mopsula ist im Modell deutlich leichter** (3 %): Dort spielt die KI den Kai und unterbricht ohne menschliche Verzögerung
  fast jeden Zauber, während die Person heilt. Der Harness misst deshalb **beide** Held:innen; liegt Mopsula unter 10 %, erhöht
  R4 zuerst `AI_INTERRUPT_REACT_TICKS` (KI-Unterbrechungen erst nach dieser Zauberzeit, §5.3) und danach die Heil-Schwellen —
  nicht die Boss-Werte, damit die Kai-Kurve bleibt.

### 11.4 Messmethode

- **Harness** `tests/tools/rt_harness.gd` (R4), gestartet über `tools/rt_balance.sh` (`godot --headless -s
  res://tests/tools/rt_harness_main.gd -- …`; das `-s`-Skript lädt die Harness per `load()`, weil `-s`-Skripte Klassen/Autoloads
  nicht direkt referenzieren): baut für jede Begegnung der Etage 1 ein `RtSetup` mit Party auf der Zielstufe der Zone (A 1–2,
  B 3, C 4–5, D 6–7, Bosse 5/7), der Ausrüstung des Zonen-Kaufplans und der Bot-Talentwahl (erstes Angebot, 06 §2.2), für
  `--hero=kai|mopsula` und `--liga=0|1|2`, spielt N Seeds mit `RtBotPlayer` (§5.7, Profile `perfect`/`typical`/`sloppy`) und dem
  Partner auf Standard-Taktik, rein über `RtSim` (keine Szene).
- Ausgabe je Begegnung und Profil: Median/P10/P90 der Dauer, HP-Verlust, Tränke, K.O.s, Niederlagen-Quote, Unterbrechungsquote,
  Ausweichquote, Hype-relevante Ereignisse/Minute; Tabelle auf stdout + JSON (`--out=<datei>`).
- **CI** (`test_r4_rt_balance.gd`, Laufzeit < 60 s): **5 Seeds** `typical` je regulärer Begegnung (Dauer ± 20 %, HP-Verlust ± 5
  Prozentpunkte gegen §11.1), **10 Seeds** je Boss und Held:in (Niederlagen-Quote grob 0–60 % bzw. 10–70 %, Dauer ± 20 %). Die
  engen Bänder prüft der **nächtliche** Lauf mit **200 Seeds** (`tools/rt_balance.sh --seeds=200`, CI-Job `nightly`).
- **Etagenfolge-Harness** (`--sequence`, R4): spielt die Begegnungen der Etage in Zonenreihenfolge zwischen den Safe Rooms, mit
  Regenerations-Ticks aus der gemessenen Laufzeit des Full-Run-Bots zwischen zwei Kämpfen (≈ 45–60 s), Werbepause und
  Safe-Room-Vollheilung; prüft „2–3 Kämpfe zwischen zwei Safe Rooms ohne Tränke“ und die Heilgegenstände je Etage. Gate für die
  Regenerationswerte (§2.7).
- **Etagen-Bänder** (Etagenzeit, Stufen bei den Bossen, Show-Zahlen) gelten erst im **R5-Full-Run** (`tools/fullrun.sh
  --combat=realtime --strategy=typical --pace=human`): 10 Seeds lokal, 1 Seed in CI.
- **`typical` aus Replays kalibriert** (R5b): Aus aufgezeichneten Probespiel-Läufen echter Erstspieler:innen werden
  Ausweichquote, Unterbrechungsquote, genutzte GCDs und Trank-Schwelle gemessen und als Profilwerte eingetragen; danach läuft der
  nächtliche Harness erneut.
- Determinismus der Messung: Harness-Seeds fest (`SeedUtil.derive(4242, "harness", n)`), Ergebnisse reproduzierbar.

### 11.5 Messwerte (füllt R4, aktualisiert R5b)

| Begegnung | Held:in | Profil | Dauer Median | HP-Verlust | Tränke | Niederlagen | Stand |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | noch nicht gemessen (Überschlag §11.3) |

---

## 12. Migrations- und Umsetzungsplan

### 12.1 Schalter (Feature-Flag)

- `GameSettings.combat_mode: StringName` (`&"ctb"` | `&"realtime"`). **Standard bis R5b: `&"ctb"`**; Entwicklung/QA schalten über
  das Einstellungsmenü (nur Debug-Builds) oder `--combat=realtime` (Boot-Argument, auch für `check.sh --shot`, Autoplay,
  `fullrun.sh`). R5b stellt den Standard auf `&"realtime"` und entfernt danach CTB.
- `GameState.combat_mode` (gespeichert, gehasht wenn ≠ `ctb`): neue Spiele übernehmen die Einstellung, geladene Spielstände
  behalten ihren Modus (keine Umrechnung vor R5b). Der RunLog-Kopf trägt `combat_mode`.
- Verzweigungspunkte (die einzigen): `ExplorationScene` (Kampfstart: `Router.start_battle` vs. `CombatDirector`),
  `BattleBridge` (`make_setup` vs. `make_rt_setup`), `Progression.total_stats` (HP-Skala über `PartyMember.hp_scale_pm`),
  `RunSim.apply` (`encounter` mit/ohne `rt`), `RunSim._tick_once` (Regeneration nur im Echtzeitmodus, §2.7),
  `Show.begin_battle` (Profil).
- CTB-Tests bleiben während R1–R5a grün (Gate jeder Phase); die 06-Tests auch.

### 12.2 Reihenfolge, Phasen, Merge-Stufen

**Voraussetzungen für R1a:** (1) Die 06-Pakete A–D sind nach `claude/prime-time-dungeon` gemergt (06 §8.0: Schritt 0, dann
A → B → C → D, Gate 06 §8.6 grün). (2) Der Brief trägt die Entscheidung im Wortlaut („Variante 3 bitte“), nennt CTB nur noch „bis
R5“ und die Vorrangregel (00_BRIEF, mit diesem Dokumentstand geändert, §12.8).

**R1a ist der zweite Vertrags-Commit** (der erste war 06 Schritt 0). Ihn macht der Integrator, bevor ein Echtzeit-Agent startet;
er enthält alles, was mehr als eine Phase braucht:

- **Stubs** aller öffentlichen Dateien aus §3.1 und der Szenen-Schnittstellen (`CombatDirector.submit(cmd)` und Signale,
  `CombatResults` mit `results_shown`/`show_slot`/`present`, `ExplorationScene.control_temporarily(member_id)`): exakte
  `class_name`, Signaturen aus §3.4, §9.5, §10.6, Standardrückgaben; erste Zeile `# STUB(R1a) — owned by <Phase>. Replace
  completely, keep the public API.`
- **Additive Änderungen an geteilten Dateien** (Tabelle §12.3): Felder, Enum-Werte am Ende, Signale, `Command.TYPES`, `Game`-API
  als Stubs, `GameSettings`-Felder (§7.8), in `data_validator.gd` die Hook-Zeile für `validators/rt.gd`, das Tag-Präfix `rt_`,
  die Payload-Schlüssel und StatIds aus §9.4 (die einzigen Änderungen an der seit 06 eingefrorenen Datei), der Ein-Zeilen-Wächter in
  `Show.say_external` (§9.3), der Anker `mod_rt_set_quiet_01` in `mod_lines.json`, `data/rt_balance.json` mit den Startwerten
  (§3.16), `core/data/validators/rt_vocab.gd` vollständig.
- **Fake-Sim und vorgefertigte Ereignisströme** in `tests/fixtures/rt_min/`: Fixture-Daten (Kopie von `data_min` + `rt`-Blöcke,
  zwei Testgegner, ein Testboss, `rt_balance.json`), `fake_rt_sim.gd` (`FakeRtSim extends RtSim`: spielt einen Strom ab —
  Einheiten-Schnappschüsse und Ereignisse je Tick, nimmt Befehle an und protokolliert sie) und die Ströme `regular_win.json`
  (Pull, Telegraph, Ausweichen, Unterbrechung, Kills, Sieg), `boss_phases.json` (Intro, Phasen, Adds, Zug-Kill, Enrage),
  `flee.json`, `ko_control_defeat.json` (K.O., Steuerungswechsel, Niederlage) und `gifts.json` (Geschenke an Tick-Grenzen); Format
  `{"setup": RtSetup.to_dict(), "ticks": [[ct, [ActionEvent.to_dict(), …], {unit_id: snapshot}], …]}`.
- Gate: `check.sh --tests-only` grün (CTB und 06 unverändert), `test_r1a_contract` grün (alle Signaturen per Reflexion, Fake-Sim
  spielt jeden Strom).

| Phase | Agent | Inhalt | Startet | Gate (Abnahme) |
|---|---|---|---|---|
| **R1a** Vertrag | Integrator | siehe oben | nach dem 06-Merge | `check.sh --tests-only`, `test_r1a_contract` |
| **R1b** Kern | A „Kern“ | Stufe **I1**: Proben/Plausibilität, Set-Geometrie, Auto-Angriff, Party-Fähigkeiten, Gegenstände, Schadens-Faltung, Ergebnis, Snapshot/Hash. **I2**: Status, Bedrohung, Partner-KI, Partner-Spezial, Autopilot, Assist, reine Abfragen. **I3**: Gegner-KI, Telegraphen, Zonen, Phasen, Enrage, Beschwörungen, `RtMods` (Show-Boss, Twists), `run_to_end`; Regeneration in `RunSim` | nach R1a | Tests §12.5 der Stufe, Golden-Hash fest, Lint grün |
| **R2** Welt | B „Welt“ | Kampf in der Welt: Director, Tick-Grenze, Puppen, Proben, Set-Ring + Kollision, Telegraph-Layer, Boss-Intro, Flucht, Türen, Kamera, Steuerungswechsel, Ausblenden, `Game`-Live-API, Perf-Szenarien | nach R1a (Fake-Sim) | Szenentests gegen die **echte Sim ab I1**; Fixture-Kampf spielbar; `combat_two_groups` gemessen |
| **R3** HUD + Eingabe | C „HUD“ | HUD (§8), Input-Map, Touch, Einstellungen, Untertitel-/Overlay-Modus, Hinweiskarten, Fähigkeiten-Menü (Leiste/Varianten/Taktik), `CombatResults` | nach R1a (Fake-Sim, Ströme) | HUD-Tests gegen die **echte Sim ab I1**; Captures 1280 × 720, 1920 × 1080, Touch, Notch |
| **R4** Inhalte + Balance | D „Inhalt“ | `rt`-Daten aller Etage-1-Inhalte, neue Status/Skills/Gegner, Bosse, Validator-Regeln (`validators/rt.gd`), `rt_balance.json`-Werte, Gleis-9-Bühne, Bossraum-Freiradius, M.O.D.-Block, Harness + Bot | nach R1a (Fixtures) | Validator grün; Harness-Bänder (CI) gegen die **echte Sim ab I3**; §11.5 ausgefüllt |
| **R5a** Show + Live | E „Integration“ | ShowRules-Profil `rt`, `take_pending_gift_rt`, Marotten-Anpassung, Achievements, RunLog/RunSim-RT, `Game.replay_log`-RT, Kompaktierung | nach R1a (Ströme) | Show-/Replay-Tests gegen die **echte Sim ab I3** |
| **R5b** Integration | E (+ Rückfragen an A–D) | Full-Run-Bot RT, Autoplay, Performance, Kalibrierung `typical`, Parität (§12.6), Standard `realtime`, CTB-Entfernung, Datenbacken, Save v2, Doku | nach allen Merges | §12.6 erfüllt; `check.sh` + `fullrun.sh` grün |

**Merge-Stufen:** 06 A–D → R1a → R1b-I1 → (R2, R3 in beliebiger Reihenfolge, jede nach ihrem Gate gegen I1) → R1b-I2 → R1b-I3 →
(R4, R5a, jede nach ihrem Gate gegen I3) → R5b. Nach jedem Merge läuft `check.sh --tests-only` auf dem Integrationszweig. Eine
Phase, die eine öffentliche Signatur ändern muss, stellt einen Änderungsantrag an den Integrator (02_TECH §0.2); er ändert Vertrag
und Stub in einem eigenen Commit vor dem Merge.

### 12.3 Dateieigentum je Datei (nach dem 06-Merge)

Regeln (wie 02_TECH §0.2 und 06 §8.1): Jede Datei hat je Phase genau einen Eigentümer. Bestandsdateien werden **nur additiv**
geändert — neue Felder, Funktionen und Enum-Werte am Ende, in einem markierten Abschnitt `# --- Echtzeitkampf (07, R<n>) ---`,
keine Umbenennung, kein Entfernen. Code der 06-Pakete bleibt unberührt; braucht eine Echtzeit-Phase dort eine Verhaltensänderung,
macht sie der Integrator in R1a oder per Änderungsantrag. Brauchen zwei Phasen dieselbe Datei, legt R1a beide Abschnitte an und
jede Phase schreibt nur in ihren.

| Datei / Bereich | 06-Eigentum | Echtzeit: wer ändert was | Merge-Regel |
|---|---|---|---|
| `core/rt/*.gd` (öffentlich + privat) | — | R1a Stubs der öffentlichen Klassen → R1b alles | neu |
| `core/data/validators/rt_vocab.gd` / `rt.gd` | — | R1a vollständig / R1a Stub → R4 Regeln (§4.10) | neu |
| `core/data/data_validator.gd` | Schritt 0, danach eingefroren | **nur R1a**: Hook-Zeile, `OPTIONAL_MOD_TAG_PREFIXES` += `rt_`, `TRIGGER_PAYLOAD_KEYS`, `STAT_IDS` (§9.4) | Vertrags-Commit |
| `data/rt_balance.json` | — | R1a Startwerte → **R4 besitzt die Werte**; Schlüssel und Bereiche ändert nur R1 (`rt_balance.gd`) | neu |
| `tests/fixtures/rt_min/**` | — | R1a; R1b ergänzt; andere lesen | neu |
| `core/battle/action_event.gd`, `battle_result.gd` | — | R1a: `Type`-Werte am Enum-Ende (§3.13), Felder `tick`, `rt`, `by_ai`; Ergebnisfelder §3.12 | additiv |
| `core/data/defs/{skill,status,enemy,item,party_member,encounter}_def.gd` | C: `show_boss` an Begegnungen | R1a: Feld `rt` + Normalisierung (§4.6–4.9) | additiv |
| `core/progression/battle_bridge.gd` | Schritt 0 (Twist-Zeile, Show-Boss-Hook), B (Talente) | R1a Stub `make_rt_setup` → R1b Implementierung (inkl. `RtMods.from_show_boss`/`from_twists`), `apply_result` mit `group_ids` | eigener Abschnitt |
| `core/progression/party_member.gd`, `game_state.gd`, `floor_run.gd` | Schritt 0 (Felder) | R1a: `hp_scale_pm`, `rt_preset`, `rt_toggles`, `rt_loadout`, `combat_mode`, `regen_ticks` | additiv |
| `core/progression/progression.gd` | B (Talente/Spezies in `total_stats`) | R1a: HP-Skala als letzter Schritt von `total_stats` (nach Klasse/Spezies) | eine Zeile, eigener Abschnitt |
| `core/live/command.gd`, `state_hash.gd` | Schritt 0 | R1a: `TYPES` + Delegation an `RtCommand`, `of_rt`-Stub → R1b | additiv |
| `core/live/run_log.gd` | — | R1a: `add_checkpoint(k, h, ct = -1)`, `ct`-Ordnung in `validate` → R5a: `compact`/`expand` | Abschnitte |
| `core/live/run_sim.gd` | Schritt 0 + D (Twist-Ticks, Replay-Puffer) | R1b: Schritt 6 Regeneration; R5a: Echtzeitkampf (§10.5) | je ein Abschnitt |
| `autoload/game.gd` | Schritt 0 (Fassaden) | R1a: Echtzeit-API als Stubs (§10.6) → R2 Live-Teil; R5a Replay-Zweig | Abschnitte |
| `autoload/game_replay.gd` | — | R5a: Schleife §10.6 | eigener Abschnitt |
| `autoload/show.gd` | Schritt 0 (Hooks), C (Marotten-Darstellung), D (`say_external`) | R1a: Wächter in `say_external`, Stub `take_pending_gift_rt` → R5a: Profilwahl, Geschenke, Zeilen-Rate | Abschnitt |
| `autoload/events.gd` | Schritt 0 | R1a: `combat_started(sim)`, `combat_event(e)`, `combat_finished(result)`, `dialog_layout_requested(mode, layout)` | additiv |
| `autoload/game_settings.gd` | Schritt 0 (`partner_auto`, …) | R1a: Felder §7.8 | additiv |
| `core/show/show_rules.gd`, `sponsor_system.gd`, `achievement_tracker.gd` | — | R5a | Abschnitte |
| `core/show/stat_ids.gd` | Schritt 0 | R1a: neue Ids (§9.4) | additiv |
| `core/show/marotten_tracker.gd`, `marotten_rules.gd` | C | R5a: `by_ai`, `flee_attempts` aus dem Ergebnis, Schlüssel `duration_sec` (§9.6) | eigener Abschnitt |
| `core/battle/show_boss_rules.gd` | C | — (nur CTB; Nachfolger `RtMods.from_show_boss`, §12.4) | R5b löscht |
| `data/mod_lines.json` | Anker A–D | R1a: Anker `mod_rt_set_quiet_01` hinter Block D → R4: Block direkt dahinter | Blöcke |
| `data/floors.json` | A (`layout.secrets`), C (`enc_e1_showboss`) | R4: `encounters[].rt`, Boss-Spot der Königin | eigene Schlüssel |
| `data/skills.json`, `statuses.json`, `enemies.json`, `items.json`, `party.json` | — | R4: `rt`-Blöcke, neue Einträge (§4.11) | additiv |
| `data/achievements.json`, `tests/test_m7_data_content.gd` | C (+6) | R5a: +4 (§9.4) | am Ende |
| `scenes/combat/*.gd`, `art/shaders/rt_telegraph.gdshader`, Set-Ring | — | R1a Stub `combat_director.gd` → R2 | neu |
| `scenes/combat/ui/*`, `art/shaders/ui_cooldown_sweep.gdshader` | — | R1a Stub `combat_results.gd` → R3 | neu |
| `scenes/exploration/exploration.gd` | A (Held:in/Partner, Geheimnisse) | R2: Kampfstart-Zweig, `control_temporarily`, Ausblenden | Abschnitt |
| `scenes/exploration/enemy_actor.gd` | A (`DAZED`), Schritt 0 (Twist-Zeile) | R2: Puppenmodus, Sperren | Abschnitt |
| `scenes/exploration/player_controller.gd`, `companion_follower.gd`, `encounter_rules.gd` | A | R2: Kampfmodus, Auslöser §2.2 (Pull, Reichweite, 4 s), Puppe | Abschnitte |
| `scenes/exploration/camera_rig.gd`, `interactable.gd` | — | R2 | additiv |
| `scenes/ui/settings_menu.gd` | A (+ Zeilen für C/D) | R3: Abschnitt Kampf; „Partner automatisch“ im Echtzeitmodus ausgeblendet | Abschnitt |
| `scenes/ui/show_overlay.gd` | C (Show-Chip, Sponsor-Badge) | R3: Overlay-Modus `combat` (Timer-Chip) | Abschnitt |
| `scenes/ui/touch_controls.gd` | A (Aktionssymbol) | R3: Kampfmodus | Abschnitt |
| `scenes/ui/mod_dialog.gd`, `exploration_hud.gd`, `input_glyph.gd`, `skills_menu.gd`, `ui_icon.gd`, `icon_mesh.gd` | — | R3 | additiv |
| `project.godot` (`[input]`) | — | R3 (§7.7) | additiv |
| `art/kit/character_rig.gd` / `vfx.gd` / `env_kit.gd` + Bühnenbau | — | R2 Animationen / R3 Kampftext-Stile / R4 `CLEAR_RADIUS_BOSS`, Gleis 9 | Abschnitte |
| `autoload/sfx_synth.gd` | — | R2 Klänge | additiv |
| `tests/perf/perf_runner.gd`, `tools/perf.sh` | — | R2: Szenarien `combat_regular`, `combat_two_groups`, `combat_boss_queen` | additiv |
| `scenes/boot/autoplay.gd`, `fullrun.gd`, `tools/fullrun.sh` | Schritt 0 + A/B/C (Hooks) | R5b: Autoplay-Schritte, `--combat=realtime` | Abschnitte |
| `tests/test_m8_no_global_rng.gd` | — | R1a: `core/rt/` ohne `det-ok` außer `DetMath.isqrt` | additiv |
| `scenes/battle/**`, `core/battle/{ctb_queue,battle_state,action_resolver,enemy_ai,auto_policy,battle_command}.gd` | A/B/C (Hooks) | niemand bis R5b; dann löschen (§12.6) | unberührt |
| `docs/07_ECHTZEITKAMPF.md` | — | R4 §11.5; R5b Endstand | Abschnitte |
| `docs/01_GDD.md`, `02_TECH.md`, `05_LIVE_MODUS.md`, `06_…`, `PERFORMANCE.md`, `README.md` | 06 | R5b (§12.8) | nach R5b |

### 12.4 Nachfolger der CTB-Andockpunkte (06 und Bestand)

R5b löscht den CTB-Kampf. Jeder Andockpunkt, den die 06-Pakete oder der Bestand am CTB-Kampf haben, braucht vorher einen
Echtzeit-Nachfolger mit Test:

| CTB-Andockpunkt (Eigentum) | Echtzeit-Nachfolger | Phase | Test |
|---|---|---|---|
| `battle_results.gd`: `results_shown`, `show_slot`, Chip „Talent bereit“ (B; C hängt `bets_results_fx.gd` an) | `scenes/combat/ui/combat_results.gd` mit derselben API (§8.9); `bets_results_fx.gd` hängt sich unverändert an | R1a Stub, R3 | `test_r3_combat_results` |
| `party_panel.gd` Stern-Marker der Held:in (A) | Pille „DU“ in `unit_frames.gd` (§8.4) | R3 | `test_r3_hud_layout` |
| `battle_controller.gd` „Partner automatisch“ (A) | keiner: Partner immer KI + Partner-Spezial (§5.1); Option im Echtzeitmodus ausgeblendet | R3, R5b | `test_r3_settings` |
| `action_resolver.gd` `_talent_first_strike` (B) | `opener_pm` in `rt_damage.gd` (§9.6) | R1b-I1 | `test_r1_rt_talents` |
| `battle_state.gd` `stunt_chance` × `stunt_pm` (B) | SHOW-Erfolgschance in `rt_ability.gd` (§9.6) | R1b-I1 | `test_r1_rt_talents` |
| `ShowBossRules.apply` + Hook in `BattleBridge.make_setup` (C) | `RtMods.from_show_boss` in `make_rt_setup` (§9.6) | R1b-I3 | `test_r1_rt_mods` |
| `MarottenTracker` über `Show.on_battle_event` (C) | derselbe Weg; `by_ai`, Flucht, `duration_sec` (§9.6) | R5a | `test_r5_marotten_rt` |
| `Show.take_pending_gift(battle)` (Bestand) | `Show.take_pending_gift_rt(sim)` + `Game.combat_boundary()` (§9.2) | R5a | `test_r5_gifts_in_combat` |
| `GameReplay._begin_battle`/`_play`/`_end_if_finished` (Bestand) | Schleife §10.6 | R5a | `test_r5_rt_live_equivalence` |
| `RunSim`-Kampfpfad (Bestand) | §10.5 | R5a | `test_r5_rt_replay` |
| `Router.start_battle`/`end_battle`, Swirl (Bestand) | `CombatDirector` in der Welt (§2.8) | R2 | `test_r2_combat_world` |
| `Events.battle_turn_started` (Bestand) | keiner (Echtzeit hat keine Züge) | R5b löscht | — |
| `test_06b_balance`, `test_06c_balance` (CTB-Bossbänder mit Talenten bzw. Liga) | Harness `--hero`, `--liga` (§11.4) | R4 | `test_r4_rt_balance` + nächtlich |
| Full-Run-Hooks `_apply_hero_choice`, `_pick_pending_talents`, `_apply_liga_strategy` (A/B/C) | unverändert; der Echtzeit-Full-Run spielt Kämpfe mit Autopilot | R5b | `test_m6_fullrun` |
| `TwistApplier.on_battle_end` über `Game.apply_battle_result` (D) | unverändert (das Kampfende läuft über `apply_battle_result`) | — | `test_r5_rt_live_equivalence` |
| `ModLiveLink` (D) | pausiert mit der Lauf-Uhr; `say_external` lehnt im Kampf ab (§9.3) | R1a | `test_r5_show_rt` |

### 12.5 Tests je Phase

| Phase | Test | Prüft |
|---|---|---|
| R1a | `test_r1a_contract` | alle Stubs mit exakten Signaturen (Reflexion), Fake-Sim spielt jeden Strom, neue Konstanten im Validator, `rt_balance.json` gültig |
| R1 | `test_r1_det_math` | Tabellen-Symmetrie, `isqrt` exakt (0…10⁶ Stichprobe + Grenzwerte), `yaw_of` für alle 256 Richtungen ±1, Formen-Tests gegen Gleitkomma-Referenz (im Test erlaubt), Rundungsregeln |
| R1 | `test_r1_rt_timing` | GCD 45 / Turbo 34 / Minimum 30, Schwungtakt, Zauber + Abbruch-Schwellen (25 % Lauftempo, 40 cm), Queue-Fenster 9, GCD-freie Aktionen, Trinkpause 15, Party-Abklingzeiten (Gegenstände 450, SHOW 900), Wirkzeitpunkt ≥ 1 Tick, Unterbrechungs-Sperre 60, Partner-Spezial-Puffer 45 |
| R1 | `test_r1_rt_threat` | Kai × 1,5, Wuchtschlag × 2, Heil-Bedrohung geteilt, Spott Spitze × 1,1 + Fixierung 120, Wechsel bei 110 %, Gleichstand, K.O. löscht |
| R1 | `test_r1_rt_status` | Gift-Stapel (3, Periode 60, min 1, max 12, Boss × 0,5), Kraft-Ticks eingefroren, `refresh`/`replace`/`ignore` mit erhaltener Periodenphase, Ausschlüsse, Betäubung unterbricht, Boss-Dauer × 0,5, Überrumpelt, Erholung, `cleanse`, Immunität/Widerstand (geseedet) |
| R1 | `test_r1_rt_damage_fold` | Enrage 1–4 Stapel → 75/113/169/253 bei Grundwert 50; Höchstwerte + 9 Stapel → `f = 8000` ohne Überlauf; neutrale Faktoren ändern nichts; Prozent-Treffer mit Gepanzert 667 ‰ |
| R1 | `test_r1_rt_ai` | Regelreihenfolge, `first_ms`/`every_ms`, Bedingungen, Ziele (zufällige reproduzierbar), Slot-Versatz, Phasen + Ops, Enrage, alle Presets (Heilschwelle, Schalter), KI-Reserve der Füller, Tränke nur mit „Vorsichtig“/Schalter und nie der letzte, SHOW nach 5 s Vorlauf, FINALE nie, `AI_INTERRUPT_REACT_TICKS`, Autopilot, `suggest` |
| R1 | `test_r1_rt_telegraph` | alle Formen/Anker, nur im Ring, Einschlag nur im Einschlag-Tick, Ausweichen + knapp, Pflichtprobe-Semantik (Sim-Seite), Zonen-Takte, Unterbrechen entfernt Telegraph, `MAX_TELEGRAPHS`, Zug tötet Adds |
| R1 | `test_r1_rt_move` | Koppelnavigation geschlossen, Plausibilität (Lauftempo × Δ + Budget 600 mm, Nachfüllung 3 mm/Tick), `POS_CORRECTED`, `walkable`/`project_walkable` (Ring, Türgassen, Waggon), Auftritt ≤ 30 Ticks, Abstoßung, Formation, Flucht nach 60 Ticks, Nebel, geschlossenes Set |
| R1 | `test_r1_rt_result` | `BattleResult` (EXP, Credits, Overkill neu, Beute, Diebstahl/Erstattung, Party-HP, Kills, K.O.s, `group_ids`, Zähler nur der gesteuerten Figur, `party_turns` ohne KI), Doppel-K.O. = Sieg, Tutorial-HP ≥ 1 |
| R1 | `test_r1_rt_mods` | Vokabular-Prüfung, statische Ops, `on`-Reaktionen, `add_rule` mit geteiltem Timer, Show-Boss-Abbildung, Twist-Tabelle |
| R1 | `test_r1_rt_talents` | „Erster Eindruck“ (überrumpelte Ziele, erster Treffer), „Taktgefühl“ (Reihenfolge vor Boss-Abzug und Deckel) |
| R1 | `test_r1_rt_pure` | 1 000 Aufrufe aller Abfragen ändern `StateHash.of_rt` nicht; Lauf mit Abfragen nach jedem Tick = Lauf ohne |
| R1 | `test_r1_rt_golden` | festes Setup + ~200 geskriptete Befehle → `StateHash.of_rt` und Ereignisanzahl gleich festen Golden-Werten; zweimal laufen = gleich; geänderte Golden-Werte nur mit Begründung im Commit |
| R1 | `test_r1_rt_int_only` | §3.14 Regel 1 |
| R1 | `test_r1_regen` | RunSim-Schritt 6 nur bei `realtime` (CTB-Lauf bitgleich), MP sofort, HP erst nach 150 Ticks, Zähler-Reset durch Kampf/Schaden, Hash-Abdeckung |
| R2 | `test_r2_combat_world` | Auslöser (Pull, Waffenreichweite, 4 s Verfolgung, Sichtung allein nicht), Vorteil-Tabelle inkl. `DAZED`, Auftritt, Mitziehen ≤ 6, ausgeblendete Akteure, Ring + Kollision + Türgassen, Puppen = Sim-Positionen (±1 cm nach Interpolation 1,0), Interaktionssperre, Bosstüren, Flucht 2 s, Sieg entfernt Gruppe, Rücksetzen, Steuerungswechsel mit Körpertausch und `refresh_hero` |
| R2 | `test_r2_tick_boundary` | Reihenfolge Grenze → Eingaben → `step`, höchstens ein Geschenk je Grenze, Hinweiskarte = kein Tick |
| R2 | `test_r2_move_sampler` | Schwellen 15 cm / 15 mm/Tick / 8 Stufen / 15 Ticks, Stopp-Probe, Pflichtprobe vor Einschlag, ehrliche Läufe ohne `POS_CORRECTED` |
| R2 | `test_r2_telegraph_layer` | Pool ≤ 10, Instanz-Uniforms je Form, Fortschritt, Set-Uniforms (Beschneiden), Farben/Kontrastmodus |
| R2 | `test_r2_boss_intro` | Ablauf, Sim startet erst danach, blockierende Zeile nur hier |
| R3 | `test_r3_action_bar` | Zustände aus der Sim (Abklingzeit, GCD, MP, Reichweite, Queue, Assist, SHOW → FINALE ab Stufe 6 bei Ziel < 30 %), Leiste wächst mit dem Level, Trank „2/3“ |
| R3 | `test_r3_combat_input` | Tasten/Gamepad/Touch → Befehle (inkl. `exact_match` für Shift+Tab, `R` = Partner-Spezial), Tab-Reihenfolge, Klick-Auswahl, Kontexttrennung Erkundung/Kampf |
| R3 | `test_r3_touch_layout` | Positionen §7.3, Trefferflächen ≥ 88 px, keine Überlappungen, Stick-Zone nur unten links, Tippen ≠ Ziehen (0,25 s, 12 px), Safe-Area-Verschiebung |
| R3 | `test_r3_hud_layout` | keine Überlappung bei 1280 × 720 und 1920 × 1080, schrittweises Aufdecken (§8.1), Pille „DU“ |
| R3 | `test_r3_combat_results`, `test_r3_settings` | API wie `battle_results` (Signal, Slot, Talent-Chip); Einstellungen §7.8, „Partner automatisch“ ausgeblendet |
| R4 | `test_r4_rt_data` | Validator-Regeln §4.10 positiv/negativ, alle Etage-1-Inhalte haben `rt`, `rt_balance.json` |
| R4 | `test_r4_rt_balance` | CI-Bänder (5 Seeds je reguläre Begegnung, 10 je Boss und Held:in, §11.4); nächtlich 200 Seeds und `--sequence` |
| R5a | `test_r5_show_rt` | Hype-Tabelle §9.1 inkl. Zuordnung (`by_ai`, gesteuerte Figur, Slot 1 ohne Abzug), Langeweile per `SECOND`, Schleppen, perfekte Phase, Combo, Serie, Zug-Kill; keine KI-Zeilen im Kampf; CTB-Profil unverändert |
| R5a | `test_r5_marotten_rt`, `test_r5_achievements_rt` | Kontext-Schlüssel §9.6, Starter-Marotten auf Stufe 1 erreichbar; neue Payloads, StatIds, Achievements |
| R5a | `test_r5_rt_replay` | `RunSim.replay` eines Echtzeit-Laufs bitgenau, Kampf-Prüfpunkte, Abbruch bei Abweichung, Befehl nach Kampfende = Fehler, `compact`/`expand` verlustfrei |
| R5a | `test_r5_gifts_in_combat` | eingefrorenes Fenster nimmt an, Anwendung an der nächsten Grenze, Id 0 + `ct`, System-Geschenke ≤ 1/2, extern + System im selben Tick (§9.2), Pur-Liga lehnt ab |
| R5a | `test_r5_rt_live_equivalence` | geskripteter Live-Lauf ≡ `Game.replay_log` (Hashes, Prüfpunkte, Show-Zahlen, Marotten-Strichliste) |
| R5b | `test_m6_autoplay` (angepasst) | Schritte `force_battle` → `force_combat` (60 Frames), `battle` → `combat` (900 Frames, Autopilot, `Events.battle_ended` VICTORY) |
| R5b | `test_m6_fullrun` + `tools/fullrun.sh --combat=realtime` | Etage 1 vollständig mit Autopilot (alle Strategien, beide Held:innen), Zeitbänder |

### 12.6 Parität und CTB-Entfernung

CTB wird entfernt, wenn **alle** Kriterien erfüllt sind:

1. Full-Run Etage 1 im Echtzeitmodus (`thorough`, `rush`, `dawdle`, `typical`; `--hero=kai|mopsula`) besteht auf 50 Seeds
   ≥ 95 % (Bossniederlagen mit anschließendem Erfolg zählen als bestanden).
2. Harness: alle Bänder §11.1 erreicht (nächtlich 200 Seeds `typical`, beide Held:innen, Liga 0/1/2), `typical` aus Probespiel-
   Läufen kalibriert (§11.4).
3. Show-Zahlen der Full-Runs (Hype, Geschenke, Follower, Zuschauer) in den GDD-§13-Bändern.
4. 20 aufgezeichnete Echtzeit-Läufe (mit Geschenken, Hinweiskarten, Flucht, Niederlage, Steuerungswechsel) werden von
   `RunSim.replay` (Kernläufe) bzw. `Game.replay_log` (Live-Läufe) bitgenau reproduziert.
5. Performance: Budgets §8.10 in `combat_regular`, `combat_two_groups` und `combat_boss_queen` auf Profil `high` und `low`,
   Compatibility und Mobile; Sim §3.15.
6. Touch-Layout in Captures geprüft (1280 × 720, 1920 × 1080, Notch-Insets); Gamepad- und Tastaturbelegung vollständig.
7. Jedes Achievement der Etage 1 (Bestand, 06 C, §9.4) ist im Echtzeitmodus erreichbar (Bot-Lauf oder gezielter Test).
8. Alle Nachfolger aus §12.4 existieren und sind getestet.
9. Spielstände: neue Saves im Echtzeitmodus; Migration v1 (`ctb`) → v2 (HP × 4, `combat_mode` entfällt) getestet; 06-Felder
   bleiben erhalten.
10. Keine offenen P1-Fehler; Nutzerfreigabe nach Probespiel.

Danach (R5b), in dieser Reihenfolge, je ein Commit:

1. Standard `combat_mode = realtime`; Einstellungseintrag entfernt.
2. **Daten backen:** `party.json` Basis-HP/HP-Wachstum × 4, feste Heilungen/Schäden × 4, `enemies.json` `stats.hp` = Echtzeit-HP,
   `rt.power`/`rt.mp`/`rt.statuses` → Hauptfelder; Skala-Code (`hp_scale_pm`, `FIXED_SCALE_PM`, `ENEMY_HP_PM`) entfernt;
   `SaveCodec.VERSION = 2` mit Migration (v1: HP × 4).
3. **Löschen:** `core/battle/ctb_queue.gd`, `battle_state.gd`, `action_resolver.gd`, `enemy_ai.gd`, `auto_policy.gd`,
   `battle_command.gd`, `show_boss_rules.gd`; `scenes/battle/` vollständig (`battle.tscn`, `battle_scene.gd`,
   `battle_controller.gd`, `battle_player.gd`, `battle_stage.gd`, `battle_camera.gd`, `status_fx.gd`, `portrait_gallery.*`, `ui/*`
   einschließlich `battle_results.gd` und `party_panel.gd`; `train_fx.gd` vorher nach `scenes/combat/` übernehmen, falls die
   Zug-Darstellung ihn nutzt); `Router.start_battle`/`end_battle` + Swirl-Kampfübergang; `Events.battle_turn_started`;
   CTB-Datenfelder (§4.11) samt Validator-Regeln; `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN`; `GameSettings.battle_speed`,
   `auto_battle_default` (→ Autopilot), `partner_auto` mit Einstellungszeile; CTB-Tests (`test_m1_ctb`, `test_m1_battle_flow`,
   `test_m1_ai`, `test_m1_battle_snapshot`, `test_m5_*`, CTB-Teile von `test_m6_*`, `test_m8_replay`, `test_m8_run_sim`,
   CTB-Teile von `test_06b_balance`/`test_06c_balance`/`test_06c_show_boss`) durch Echtzeit-Varianten ersetzt;
   `StateHash.of_battle`; `ShowRules`-Profil `ctb`.
4. **Doku:** §12.8.

### 12.7 Unverändert wiederverwendet

Schadensformel (`DamageCalc`, GDD §3.7), `Elements`, `StatBlock`, Krit/Varianz/Element-Konstanten in `Balance`, EXP-Kurve,
Stufenwachstum (außer HP-Skala), `Combatant` (Basisklasse, inkl. `talent_mods`), `StatusEffect` (Basisklasse), `HitResult`,
`BattleSetup` (Basisklasse), `BattleResult` (erweitert), `BattleBridge.apply_result`, Beute (`LootRoller`, Drops), Show
(ShowModel, SponsorSystem-Schwellen, Gifts, GiftPolicy, GiftApplier, SponsorWindows, Achievements, M.O.D.-Ansager), 06-Systeme
(HeroRules, Talents, Casting, MarottenRules, TwistApplier, RegieDirector, ModLiveLink), Save (additiv), Erkundung (Wahrnehmung,
Patrouillen, Streuner, Kamera, Bellen/`DAZED`), Art-Kit (`CharacterRig` + neue Animationen, `CharacterBuilder`, `Vfx`,
`icon_mesh`), `Sfx`, `RunSim`/`RunLog`/`StateHash`/`Command` (erweitert), `SeedUtil`, `FixedMath`, `CanonicalJson`, alle
Datentabellen (um `rt` erweitert).

### 12.8 Änderungen an bestehenden Verträgen (Übersicht)

| Dokument | Abschnitt | Änderung | Wann |
|---|---|---|---|
| 00_BRIEF | Kap. 2, 3, 4, 6, 7 + Entscheidungsblock | Entscheidung „Variante 3 bitte“ im Wortlaut, CTB „bis R5“, Kampf in der Welt, Vorrangregel | **mit diesem Dokumentstand** |
| 05_LIVE | §3.3 (Grad A/B), §3.7 | Kampfbewegung Grad A mit Plausibilität, `move_input` für Grad B reserviert; Echtzeit-Befehle mit `ct` | **mit diesem Dokumentstand** |
| 05_LIVE | §3.4, §10.6 | Echtzeit-Befehle mit `ct`, Kampf-Prüfpunkte (§10) statt CTB-Lockstep | R5b |
| 02_TECH | §2.2 Input-Map | §7.7 | R3 |
| 02_TECH | §3.2 Events, §3.4 Game, §3.5 Show | Signale §12.3, Echtzeit-API §10.6, `take_pending_gift_rt`, ShowRules-Profil | R5b |
| 02_TECH | §4 Daten | `rt`-Blöcke §4.6–4.9, `rt_balance.json`, Validator §4.10 | R5b |
| 02_TECH | §5 Kampf-Kern | ersetzt durch 07 §3 (der Hinweis „abgelöst durch 07“ steht schon) | R5b |
| 02_TECH | §6.4 Save, §7.3 Erkundung, §11 Autoplay/Full-Run, §12 Budgets | additive Felder und v2; Auslöser §2.2; §12.5; §8.10 | R5b |
| 01_GDD | §2.3/2.4, §3, §4.2, §5, §7, §13 | Kampfauslöser; §3 ersetzt durch 07 (Hinweis steht schon); HP × 4 nach dem Backen; Echtzeit-Gegner §6; Hype-Tabelle §9.1; Messwerte | R5b |
| 06 | §1.4, §2.2 (Spalte „Angewendet in“), §2.6, §4.4 `mar_speed`, §8 | „Partner automatisch“ entfällt; Talent-Anwendung §9.6; Show-Boss „alle 8 s“; Echtzeit-Bedingung mit Etage 2; Verweise auf die gelöschten CTB-Dateien | R5b |
| 03_ART | §8, §9 | Telegraph-Farben, Kampf-HUD-Elemente, LED-Ring, Decal-Befund | R3 |
| PERFORMANCE.md | alles | Neumessung mit Echtzeitkampf | R5b |

### 12.9 Restpunkte der Migration

| Nr. | Punkt | Regel | Wer |
|---|---|---|---|
| 1 | Etagen-Timer und Leerlauf in der Erkundungsszene | `Game.is_timer_ticking()` und `is_idle_ticking()` liefern `false`, solange `Game.in_battle` (die Szene bleibt im Kampf aktiv) | R2 |
| 2 | `Game.in_battle` | `true` vom `encounter` bis `end_combat` (Geschenk-Warteschlange, Sperren, Sponsor-Fenster) | R2 |
| 3 | Lauf-Uhr | `RunSim.is_clock_running()` = `false` mit laufendem Kampf: Hype-Verfall, Streuner, Twist-Laufzeiten, Fenster-Uhr stehen | R5a |
| 4 | `Events.battle_started`/`battle_ended` | gleiche Bedeutung wie bisher (Show, Achievements, Musik) | R2 |
| 5 | Musik | Kampfmusik nach 5 s, Bosse sofort (§2.8) | R2 |
| 6 | Speichern im Kampf | nicht möglich (Pausemenü ohne „Speichern“); ein Spielstand enthält nie eine `RtSim` | R3 |
| 7 | Niederlage | bestehender Sendeschluss/Game-Over-Ablauf | R2 |
| 8 | Streuner und Etagen-Events | Streuner stoßen nicht zu einem laufenden Kampf (die Uhr steht); Event-Kämpfe ohne Gruppe nutzen den festen Anker (§2.3) | R2 |
| 9 | Story-Banner | `story_battle:<encounter_id>` erscheint als Kampf-Banner (§8.8) | R3 |
| 10 | Karte, Interaktionen, Safe-Room-Tür | im Kampf gesperrt (§2.4, §7.1) | R2, R3 |
| 11 | Capture-Rezepte (`check.sh --shot`) | Kampf-Rezepte `combat_regular`, `combat_boss`, `combat_touch` ersetzen die CTB-Rezepte | R3 (+ R2) |
| 12 | Autoplay | Schritte `force_combat`, `combat` (§12.5) | R5b |
| 13 | Einstellungen | `battle_speed`, `auto_battle_default`, `partner_auto` im Echtzeitmodus ausgeblendet, mit R5b entfernt | R3, R5b |
| 14 | Seltene Begegnung `enc_f1_a_rare` | Fahrscheinfresser stationär, Flucht mit Beute als unterbrechenswerter Zauber (§6.5) | R4 |
| 15 | README, Screenshots, PERFORMANCE.md | Neuaufnahme mit Echtzeitkampf | R5b |

---

## 13. Risiken und offene Punkte

### 13.1 Risiken

| Nr. | Risiko | Gegenmaßnahme |
|---|---|---|
| 1 | Client-seitige Bewegung (Grad A) erlaubt in Bestenlisten Manipulation (z. B. „perfektes“ Ausweichen per Tool) | Verschiebungsgrenze Lauftempo × Δ + kleines Budget (§3.5.2), Korrektur-Zähler und Ausreißer-Statistik im Verifier, Kennzeichnung „plausibilitätsgeprüft“; Grad B mit `move_input` reserviert (§10.8) |
| 2 | Lesbarkeit auf kleinen Bildschirmen: Telegraphen unter Figuren, Kamera im Weg | requisitenfreies Set mit LED-Ring, Fußpunkt-Regel, am Ring beschnittene Flächen, Kontrastmodus, Kamera-Zoom, weiche Zielführung auf Touch, Capture-Reviews, Gerätetest |
| 3 | Draw Calls: schlechtester gemessener Fall 147 von 150 (Compatibility high, ohne Effekte) | Komparsen/Beschwörungen ohne Echtzeitschatten, Akteure anderer Räume ausgeblendet, höchstens 6 Einheiten, frühe Messung mit Effekten (R2), Rig-LOD und Funken-Deckel als Reserve (§8.10) |
| 4 | Balance-Verschiebung durch HP-Skala, Regeneration, Taktung, MP-Ökonomie | Harness in CI (5/10 Seeds) und nächtlich (200), Etagenfolge-Harness, alle Stellschrauben in Daten (§11.2) |
| 5 | Partner-KI zu stark oder zu schwach (im Modell ist Held:in Mopsula deutlich leichter, §11.3) | beide Held:innen messen, `AI_INTERRUPT_REACT_TICKS` und Heil-Schwellen als Stellschrauben, Probespiel |
| 6 | Steile Boss-Lernkurve (`perfect` 0–2 %, `sloppy` 90–95 % Niederlagen) | `typical` aus echten Läufen kalibrieren; Vorabendprogramm (Warnzeiten × 1,25), Autopilot, Comeback-Sponsor-Fenster (06 §6); Probespiel |
| 7 | Abhängigkeit von 06 (Heldenwahl, Talente, Marotten, Twists) und zwei Kampfpfade bis R5b | 06 zuerst gemergt, R1a-Vertrag, Nachfolger-Tabelle §12.4, ein Schalter mit wenigen Verzweigungspunkten, CTB- und 06-Tests als Gate |
| 8 | Log-Größe durch Proben | Schwellen, Kompaktierung, gzip (§10.3) |
| 9 | Hype-Ökonomie: mehr Ereignisse pro Minute, KI-„Farming“ | Zuordnung nach `by_ai` und gesteuerter Figur (§9.1), kleinere RT-Werte, Messung gegen GDD §13 im R5b-Full-Run |
| 10 | Determinismus-Lücken (Dictionary-Reihenfolge, Gleitkomma aus Daten, Iteration, Schreibzugriffe in Abfragen) | Lint, Int-only-Test, Reinheitstest, Golden-Hash, Replay-Tests |
| 11 | Parallele Agenten an geteilten Dateien | Dateieigentum je Datei (§12.3), R1a legt alle geteilten Abschnitte an, Merge-Stufen (§12.2) |
| 12 | Plattformgleichheit von `RandomNumberGenerator` (PCG32) — hier nicht prüfbar (nur Linux-Binary) | Replay-Test plattformübergreifend in CI, sobald Windows/Android-Läufer existieren; Golden-Werte (Anhang A10) als Referenz |
| 13 | Bossräume brauchen 6,2 m Freiradius (Schreibtisch, Wrack, Waggon) | R4 rückt Requisiten an die Wand, `test_m4_env` prüft `CLEAR_RADIUS_BOSS` (§2.4) |

### 13.2 Entschiedene Punkte (vormals offen, Entscheidung E24)

| Nr. | Frage | Entscheidung |
|---|---|---|
| O1 | Spieltempo unter 100 % in Liga-/Event-Läufen? | **Überall erlaubt.** Jeder Wechsel wird aufgezeichnet (`combat_speed`); Bestenlisten zeigen das Abzeichen „Zeitlupe“ und filtern getrennt (§10.7). |
| O2 | Pause im Kampf bei Live-Läufen | **Nur offline** (die Sim tickt nicht). Live- und Server-Läufe haben im Kampf keine Pause (§7.1). |
| O3 | Regeneration außerhalb des Kampfes | **Nur im Echtzeitmodus:** MP 2 % je 3 s, HP 0,5 % je 3 s erst nach 5 s ohne Schaden; Gate im Etagenfolge-Harness (§2.7, E12). |
| O4 | Wo prüft man die FINALE-Bedingung? | **In der Sim:** ab Stufe 6 und Ziel unter 30 % HP; der Hype steuert nur die Darstellung (§4.1, E10). |
| O5 | „Steuerung folgt dem Leben“ oder Zuschauermodus bei K.O.? | **Steuerung folgt dem Leben**, vorübergehend für diesen Kampf; `GameState.hero` bleibt (§2.6). Zuschauen nur im Koop (§10.8). |
| O6 | Etage-2-Boss „Der Ausverkauf“ mit Zähler-Mechanik | **Bewusst zurückgestellt** bis vor den Bau von Etage 2; §6.8 bleibt Entwurf, die Sim braucht dafür nur den Baustein `rt.counter`. |
| O7 | Neue Achievements (Unterbrechen, Ausweichen, Zug-Kill, perfekte Phase) | **Aufnehmen** — vier Stück, zählen nur Leistungen der gesteuerten Figur (§9.4). |
| O8 | Tiefentest der Telegraphen | **An lassen:** keine Requisiten im Set, Flächen auf 4 cm über allen Bodenmarken mit `render_priority` 1 (§8.7). |
| O9 | Koop: Eingangspuffer und Lag-Kompensation | **Startwerte** 2 Ticks und höchstens 200 ms; gemessen und bestätigt mit 05 S4 (§10.8). |
| O10 | Musikwechsel bei sehr kurzen Kämpfen | **Kampfmusik erst nach 5 s Kampf**, Bosse sofort (§2.8). |

Offen bleiben nur Punkte, die ein Probespiel braucht (Feinwerte der Partner-KI, `typical`-Kalibrierung) — sie sind Stellschrauben
in Daten, keine Vertragsfragen.

---

## Anhang A: Engine-Prüfprotokoll

Binary: `Godot Engine v4.7.2.stable.official` (Ausgabe `Engine.get_version_info()["string"]` = `4.7.2-stable (official)`).
Umgebung: Linux, Xvfb; Compatibility = OpenGL 3.3-Pfad auf llvmpipe (GL 4.5, Mesa 25.2.8); Mobile = Vulkan 1.4 lavapipe
(Forward Mobile). Wegwerf-Projekte nur im Scratchpad, nicht im Repository.

| Nr. | Fakt | Methode | Ergebnis (geprüft) |
|---|---|---|---|
| A1 | `Decal` in Compatibility | Boden + Decal (rote Textur), Pixel in der Decal-Mitte gelesen | **nicht gezeichnet** (#969696 = Bodenfarbe); Mobile: gezeichnet (#bd1919), kein zusätzlicher Draw Call |
| A2 | Spatial-Shader-Quad mit `instance uniform vec4` × 2 | Telegraph-Shader §8.7 auf `QuadMesh`, Pixel gefüllt/ungefüllt/außen | beide Renderer korrekt (Compatibility #d3734c / #b38572 / #969696; Mobile #c25c48 / #8f5f58 / #606060); Boden + Quad = 2 Draw Calls |
| A3 | Canvas-Instanz-Uniforms (`CanvasItem.set_instance_shader_parameter`) | zwei `ColorRect` mit einem gemeinsamen `ShaderMaterial`, verschiedene Werte | korrekt in beiden Renderern, **1** Draw Call |
| A2b | Shader-Texte dieses Dokuments (§8.2, §8.7) | wörtlich aus dem Dokument extrahiert, kompiliert, Quad (Kreis, Fortschritt 0,5) über grauem Boden + Sweep (`cd_left` 0,5) gerendert | beide Renderer fehlerfrei; Telegraph-Mitte #b95252 (Compatibility) / #cf5252 (Mobile) gegen Boden #595959; Sweep links abgedunkelt, rechts unverändert |
| A3b | Produktions-Sweep-Shader (§8.2, transparente Basis) | 6 `ColorRect` mit geteiltem Material über hellem Hintergrund, `cd_left` 0,5 / `gcd_left` 1,0 | beide Renderer: linke Hälfte #58555d (abgedunkelt), rechte Hälfte #e6e6e6 (= Hintergrund), Ring #fafafa, Ruhezustand transparent; Canvas-Draw-Calls 2 |
| A4 | Draw Calls HUD-Bausteine (`RenderingServer.viewport_get_render_info`, Canvas) | Messszenen, beide Renderer gleich | leer 0; 6 Sweeps (geteiltes Material) 1; + 6 Labels ohne Outline 2; + 6 Labels Outline 4 px 13; 6 Sweeps + 12 Labels ohne Outline 2; 6 `TextureProgressBar` radial 6; 6 × `draw_colored_polygon` 6; 1 × `canvas_item_add_triangle_array` für 6 Slots 1; 8 Plaketten `PanelContainer`+`ProgressBar` 24; 8 Plaketten als Dreiecks-Array + 8 Labels 2 |
| A5 | `Label3D` (Billboard, Outline 8) | 8 Stück | Compatibility 16 Draw Calls, Mobile 8 |
| A6 | Klassen/Methoden vorhanden | Headless `ClassDB`/`has_method`/Eigenschaftslisten | `Decal`, `TextureProgressBar`, `Label3D`, `MultiMeshInstance3D`, `AnimationTree`, `InputEventScreenTouch/Drag`, `InputEventMagnifyGesture`, `SubViewport`, `CPUParticles3D`, `StaticBody3D`, `BoxShape3D`, `SurfaceTool`; `CanvasItem.set_instance_shader_parameter`, `GeometryInstance3D.set_instance_shader_parameter`, `GeometryInstance3D.cast_shadow`, `Material.render_priority` (−128…127), `RenderingServer.canvas_item_add_triangle_array`, `RenderingServer.viewport_get_render_info` (Typ `SHADOW` = 1), `CharacterBody3D.move_and_slide`, `Camera3D.unproject_position`, `Camera3D.project_ray_origin`, `Input.get_vector`, `Input.action_press`, `Input.parse_input_event`, `DisplayServer.is_touchscreen_available`, `PhysicsDirectSpaceState3D.intersect_ray`, `CanvasItem.draw_colored_polygon`, `CanvasItem.draw_arc` |
| A7 | Tasten-/Gamepad-Konstanten | Ausgabe der Enums | `KEY_1`…`KEY_6` = 49…54, `KEY_TAB` = 4194306, `KEY_G` = 71, `KEY_V` = 86, `KEY_ESCAPE` = 4194305, `KEY_SHIFT` = 4194325; Maus links 1 / rechts 2 / Mitte 3 / Rad 4, 5, `MOUSE_BUTTON_MASK_RIGHT` = 2; Joypad A 0, B 1, X 2, Y 3, Back 4, Guide 5, Start 6, L3 7, R3 8, LB 9, RB 10, Steuerkreuz oben 11 / unten 12 / links 13 / rechts 14; Achsen LX 0, LY 1, RX 2, RY 3, LT 4, RT 5 |
| A8 | Shift+Tab gegen Aktion nur mit Tab | `InputEvent.is_action(action, exact_match)` | `target_next` (Tab): Shift+Tab → `true` ohne, `false` mit `exact_match`; `target_prev` (Shift+Tab) → `true` in beiden; Achsen-Deadzone Standard 0,2; LT 0,8 löst Achsen-Aktion aus |
| A9 | Ganzzahl-Semantik | Skript | `int` 64 Bit mit Überlauf-Wrap; `-7 / 2 == -3`; `-7 % 2 == -1`; `posmod(-7, 2) == 1`, `posmod(-1, 256) == 255`; `const T: PackedInt32Array = [...]` zulässig; `isqrt` per `sqrt(float)` + Korrektur exakt (15 → 3, 2 147 395 600 → 46 340, 10¹² + 1 → 10⁶); `Dictionary.keys()` in Einfügereihenfolge |
| A10 | `RandomNumberGenerator` | `seed = 12345`, 5 × `randi_range(0, 9999)` | `[6956, 9747, 8241, 8820, 3406]` (Golden-Referenz für plattformübergreifende Prüfung, Risiko 12) |
| A11 | Physik-Takt | `ProjectSettings` | `physics/common/physics_ticks_per_second` Standard 60 |
| A12 | Nicht prüfbar hier | — | Plattformgleichheit von Jolt/`CharacterBody3D` (wird nicht in der Sim verwendet), echte Mobil-GPUs und Touch-Geräte, Windows/macOS/Android-Binaries |
| A13 | Telegraph am Set-Ring beschnitten; LED-Ring als ein Mesh | Telegraph-Shader §8.7 **wörtlich aus dem Dokument**; Set-Mitte (0, 0), Radius 2 m; Kreis r 2 m um x = 1,5 m (Fortschritt 0,5); Ring als `ArrayMesh` (`SurfaceTool`, 64 Segmente, Lücken bei +X/−X, unshaded, `C_ACCENT_2`); orthografische Kamera von oben, Pixel gelesen | Compatibility: im Ring #b95252 (Telegraph), in der Form aber außerhalb des Rings #595959 (= Boden), Ring #1fd4ed, Türlücke #595959; Mobile: #cf5252 / #595959 / #1fd4ed / #595959. 3D-Draw-Calls: Boden + 1 Quad + Ring = 3, Boden + 10 Quads + Ring = 12 (je Quad 1, Ring 1) |
| A14 | Kosten je Baustein in der echten Erkundung | wie A15; Differenzmessungen mit/ohne zusätzliche Rigs und Schatten | Compatibility high: ein Rig ≈ 4 Draw Calls je Mesh-Teil (Farbe + Umriss, beide auch im Schattenpass) — Kanalratte (3 Teile) +12, Taubenschwarm (5 Teile) +20; ohne Echtzeitschatten etwa die Hälfte; Mobile +7 / +9; Ring 1, Telegraph-Quad 1 |
| A15 | 3D-Draw-Calls von Kampfansichten (Tabelle §8.10) | Kopie des Spielprojekts mit Mess-Skript: `Game.new_game(0, "Kai", 4242)`, Erkundungsszene Etage 1; je Fall die Set-Zelle mit LED-Ring (Radius 4,8 bzw. 6,0 m, Türlücken), 10 Telegraph-Quads (geteiltes Material, alle vier Formen), zusätzlichen Gegner-Rigs neben den Anführern (`CharacterBuilder.build`), Akteure anderer Zellen ausgeblendet; Kamera-Arm 8 m (Boss 9 m); Maximum über 4 Kamerarichtungen × 2 Frames von `VISIBLE` + `SHADOW` Draw Calls; zweiter Durchgang mit Komparsen ohne Schatten; Qualität `high`/`low` über `PTD_QUALITY`, Renderer über `--rendering-method` | Werte §8.10: Compatibility high schlechtester Fall 180 (mit Schatten) bzw. 147 (Komparsen ohne Schatten), Mobile high ≤ 82, Compatibility low ≤ 99 |
| A16 | Konstanten der neuen Eingaben | Ausgabe der Enums | `KEY_R` = 82 (Partner-Spezial), `KEY_C` = 67, `KEY_Q` = 81; `JOY_BUTTON_DPAD_LEFT` = 13, `JOY_BUTTON_LEFT_STICK` = 7, `JOY_BUTTON_RIGHT_STICK` = 8 |

## Anhang B: Glossar

| Begriff | Bedeutung |
|---|---|
| Set, Kampf-Set | Kampffläche in der Raumzelle: Kreis um die Raummitte (regulär 4,8 m, Boss 6,0 m), markiert durch den LED-Ring |
| Türgasse | Lücke im Ring vor einer offenen Tür; wer 2 s außerhalb des Rings steht, flieht |
| Auftritt | Anführer außerhalb des Rings laufen beim Kampfstart sichtbar herein; Komparsen erscheinen am Eintrittspunkt |
| Komparsen | Gruppenmitglieder, die beim Kampfstart ins Bild springen |
| ct | Kampf-Tick (30/s) |
| Tick-Grenze | Moment vor jedem Tick, an dem höchstens ein Sponsor-Geschenk angewendet wird |
| GCD | globale Abklingzeit (1,5 s) nach Fähigkeiten mit `gcd` |
| Queue-Fenster | 300 ms, in denen ein Tastendruck vorgemerkt wird |
| Telegraph | angekündigte Bodenfläche mit Warnzeit, wirkt nur im Ring |
| Zone | bleibende Bodenfläche mit periodischer Wirkung |
| Prozent-Treffer | Schaden in % der Max-HP des Ziels (gegnerische Telegraphen: 15–30 %, Zug 35 %) |
| Kraft-Tick | periodischer Schaden, beim Anwenden aus der Schadensformel berechnet und eingefroren |
| unterbrechenswert | Gegnerzauber mit goldenem Rand, Ton und KI-Reaktion; Füller sind nie unterbrechbar |
| Fixierung | erzwungenes Ziel eines Gegners (Spott) |
| Partner-Spezial | eine Taste, die dem KI-Partner seine Signatur befiehlt (Kai: Spott, Mopsula: Heiliges Schlabbern) |
| `by_ai` | Ereignisfeld: die auslösende Aktion stammt von der KI (Gegner, KI-Partner, Autopilot) |
| Probe | aufgezeichnete Position/Geschwindigkeit der gesteuerten Figur |
| Koppelnavigation | Fortschreiben der Position aus der letzten Probe |
| Grad A / Grad B | Bewegung rechnet der Client (mit Plausibilitätsprüfung) / der Server aus Eingaben (`move_input`, später) |
| Pull | Kampfbeginn durch Feldschlag, Fähigkeit oder Gegenstand auf einen Anführer |
| Assist | Vorschlags-Anzeige der nächsten sinnvollen Fähigkeit |
| Autopilot | die Sim spielt die gesteuerte Figur |
| SHOW / FINALE | Stunt-Taste mit Risiko und Hype / ihr Finisher ab Stufe 6 gegen Ziele unter 30 % HP |
| R1a | zweiter Vertrags-Commit: Stubs, geteilte Abschnitte, Fake-Sim und Ereignisströme vor jeder Echtzeit-Phase |
| Fake-Sim | `FakeRtSim` in `tests/fixtures/rt_min/`: spielt vorgefertigte Ereignisströme ab, damit Welt, HUD und Show ohne fertigen Kern entstehen |
