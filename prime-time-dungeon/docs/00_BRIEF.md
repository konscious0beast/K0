# PRIME TIME DUNGEON — Leitentscheidungen (Brief)

> Arbeitstitel. Eigenständige IP, **inspiriert** von *Dungeon Crawler Carl* (Matt Dinniman).
> Keine Namen, Figuren, Orte oder Texte aus DCC. Wir übernehmen nur Genre-Ideen
> (Dungeon als galaktische Reality-Show, Zuschauer/Sponsoren, Lootboxen, Etagen-Timer, sarkastische System-KI),
> die nicht urheberrechtlich geschützt sind. Lizenz-Option bleibt offen (siehe Strategie).

Dieses Dokument ist die **verbindliche Grundlage**. Alle anderen Dokumente und der Code richten sich danach.
Änderungen hier nur bewusst und mit Begründung.

---

## 1. Prämisse (eigene Welt)

- Das galaktische Medienkonglomerat **NOVA SYNDIKAT** hat die Erdoberfläche „zurückgebaut“, um Platz für
  seine Erfolgsshow **DUNGEON PRIME TIME** zu schaffen. Überlebende Menschen werden zu **„Kandidat:innen“**.
- Der Dungeon hat **Etagen** („Level“). Jede Etage bricht nach Ablauf eines **Countdowns** zusammen —
  wer bis dahin keine **Treppe** gefunden hat, ist raus (Game Over).
- Moderiert wird alles von **M.O.D.** (Mediale Omnipräsente Direktorin) — die System-KI. Sarkastisch,
  quotengeil, regelversessen, heimlich etwas sentimental. Sie kommentiert Achievements, Loot und Tode.
- Spielfigur: **Kai** (Name frei wählbar, Standard „Kai“), Pfleger:in aus einem Tierheim, pragmatisch, trocken.
- Begleiter: **Graf Mopsula**, ein Mops aus dem Tierheim, der durch den Dungeon sprechen kann, sich für
  Adel hält und sich als Magier entpuppt. Arrogant, eitel, loyal. Publikumsliebling.
- Ton: schwarzer Humor + echte Gefahr + Satire auf Streaming-/Werbe-/Gacha-Kultur. Nicht zynisch gegenüber den Menschen.

## 2. Design-Säulen

1. **Überleben UND unterhalten** — Jede Entscheidung bezahlt man in Sicherheit oder in Show.
2. **FF10-Kampf, FF12-Welt** — Erkundung in Echtzeit-3D mit sichtbaren Gegnern (FF12),
   Kämpfe als rundenbasiertes **CTB** (Conditional Turn-Based, FF10) mit sichtbarer Zugreihenfolge.
3. **Kurze Sessions, lange Motivation** — Eine Etage = ein Lauf (15–25 min). Speichern im Safe Room.
4. **Die Show ist das UI** — HUD wie eine TV-Übertragung: Live-Zuschauerzahl, Chat-Ticker, Sponsor-Banner.
5. **Lesbarer Stil** — stilisiertes Low-Poly mit Toon-Shading (Option B), klare Silhouetten, starke Farben.

## 3. Kern-Spielschleife

```
Etage betreten → Erkunden (Gegner sichtbar, Truhen, Events, Safe Room)
   → Kampf (CTB) → Zuschauer ↑ → Follower/EXP/Loot
   → Safe Room (Heilen, Speichern, Lootboxen öffnen, Automat-Shop)
   → Treppe finden (Countdown!) → optional Etagenboss → nächste Etage
```

## 4. Systeme (Umfang Vertical Slice = Etage 1 komplett, Etage 2 angelegt)

| System | Kurzbeschreibung |
|---|---|
| Erkundung | Third-Person, Kamera hinter der Figur (orbit). Etage 1 ist handgebaut (Layout-Daten in `floors.json`), ab Etage 2 prozedural aus Raum-Modulen auf Raster (`DungeonGenerator`). Gegner patrouillieren sichtbar; Berührung = Kampf. Vorteil/Nachteil je nach Anlauf (Rücken = Präventivschlag). |
| Kampf (CTB) | Party (Kai + Mopsula) vs. 1–4 Gegner. Zugreihenfolge aus SPD + Aktionsgewicht („Tick“-System wie FF10). Befehle: Angriff, Fähigkeit, Item, **Stunt**, Verteidigen, Flucht. Zugreihenfolge-Leiste rechts. |
| Show-System | **Zuschauer** (live, pro Kampf/Erkundung schwankend) und **Follower** (dauerhaft). Abwechslungsreiche Aktionen, knappe Siege, Stunts, Combos, Kills mit Fähigkeiten erhöhen den Hype. Schwellenwerte → **Sponsor-Geschenk** (Heilung/Buff/Item) mitten im Kampf. |
| Lootboxen | Bronze/Silber/Gold/Fan-Box aus Achievements und Bossen. Nur im Spiel verdient, **niemals Echtgeld**. Öffnen nur im Safe Room, mit M.O.D.-Kommentar. |
| Achievements | Vom Spiel live vergeben („Erster Kill“, „Mit 1 HP gewonnen“, „Pazifist (5 min ohne Kampf)“ …) → Lootbox + M.O.D.-Spruch. |
| Etagen-Timer | Läuft nur in der Erkundung. Etage 1: 20:00 min. Warnungen bei 5:00 / 1:00. |
| Safe Room | Volle Heilung, Speichern, Lootboxen, Automat (Shop), Gespräch mit Mopsula (Charaktermomente). Keine Gegner. |
| Progression | Level/EXP, Stats (HP, MP, STR, MAG, DEF, RES, SPD, LCK), Ausrüstung (Waffe, Rüstung, Accessoire), Fähigkeiten nach Level. **Klassenwahl ab Etage 3** (Datenmodell jetzt schon vorbereitet). |
| Bosse | Etage 1: **„Der Hausmeister“** (Quartier-Boss) + Etagenboss **„Die Rattenkönigin von Gleis 9“**. |
| Speichern | Ein Spielstand pro Slot (3 Slots), JSON in `user://`. Nur im Safe Room + Autosave bei Etagenwechsel. |
| Eingabe | Tastatur/Maus, Gamepad, Touch (virtueller Stick + Buttons). Alle Menüs fokus-navigierbar. |
| Sprache | UI-Texte Deutsch. Code/Kommentare Englisch. Texte über `tr()`-fähige Keys vorbereitet (später EN). |

## 5. Technische Leitentscheidungen

- **Engine:** Godot **4.7** (getestet mit 4.7.2-stable), **GDScript mit statischer Typisierung**.
- **Renderer:** `mobile` (Vulkan) als Standard für PC + Handy; **alle Shader müssen auch im
  `gl_compatibility`-Renderer funktionieren** (Fallback, ältere Geräte, Web, CI-Screenshots).
- **Projektpfad:** `prime-time-dungeon/game/` (= `res://`). Docs in `prime-time-dungeon/docs/`, Werkzeuge in `prime-time-dungeon/tools/`.
- **Keine externen Assets** in Phase 1: Figuren, Umgebung, Effekte werden **prozedural aus Primitiven** gebaut
  (Mesh-Kit im Code), verfeinert durch Toon-Shader, Outline (Inverted Hull), Rim-Light, Glow, Nebel.
  Pipeline ist so gebaut, dass später glTF-Modelle aus Blender 1:1 die Platzhalter ersetzen.
- **Daten getrieben:** Gegner, Fähigkeiten, Items, Achievements, Lootbox-Tabellen, M.O.D.-Sprüche, Etagen-Config
  als **JSON** in `res://data/`. Geladen vom Autoload `DB`.
- **Logik und Darstellung getrennt:** Kampf-, Show-, Loot-, Progressions-Logik sind reine `RefCounted`-Klassen
  ohne Szenenabhängigkeit → headless testbar.
- **Deterministisch testbar:** Jede Zufallsquelle nimmt einen `RandomNumberGenerator` mit Seed entgegen.
- **Tests:** eigener minimaler Test-Runner `res://tests/run_tests.gd` (headless, Exit-Code ≠ 0 bei Fehlern).
  Werkzeug: `tools/check.sh` (kopiert Projekt in Temp-Ordner → import → tests → smoke run).
- **Kein Pay-to-Win.** Spieler kaufen sich selbst **nichts Zufälliges** für Echtgeld. Monetarisierung Basis:
  Premium-Kauf (PC) / Free-Demo + Vollversion-Unlock (Mobile).
- **Entscheidung (Nutzer, 2026-10-07): Zuschauer-Geschenke mit Echtgeld (Variante B: Twitch Bits / C: eigener Shop)
  und mit Zufallsinhalt („wie WoW-Loot“) sind gewollt** — Umsetzung nur mit Leitplanken (Details `05_LIVE_MODUS.md`):
  veröffentlichte Wahrscheinlichkeiten, Pity-Garantie, **Inhalte sind lauf-gebunden** (verfallen nach dem Lauf, kein
  dauerhafter Wert, kein Handel, keine Auszahlung), Limits pro Spieler/Lauf, Sponsor-freie Wertung in der Liga,
  Altersprüfung für Käufer, Geo-Sperre wo verboten (z. B. Belgien), **beweisbar faire Server-Würfel** (Seed-Hash vor dem Event
  veröffentlicht). Rechtsprüfung vor Launch ist Pflicht.
- **Entscheidungen (Nutzer, 2026-10-08), verbindlich** — Wortlaut:
  > **(1)** „Echtgeld von Zuschauer:innen fließt **ausschließlich an das Spiel bzw. den Betreiber** — **nie** an die
  > Spielerin/den Spieler (Crawler) und **nie** an Streamer:innen.“
  >
  > **(2)** „Zuschauer:innen können **nur begrenzt oft** und **nur zu bestimmten Zeiten** helfen.“

  Folgen (Details `05_LIVE_MODUS.md` Kap. 0, 2, 6.13, 8, 9, 12):
  - zu (1): Die **Creator-Beteiligung ist gestrichen** (keine Auszahlung, keine Beteiligung, keine Auszahlungskonten an Personen).
    **Variante B (Twitch Bits)** ist nur noch **kostenlose Interaktion** (Votes, kostenlose Fan-Punkte „Applaus“) — Bits-Erlöse
    gehen nach unserem Kenntnisstand an die Broadcaster:in **[zu prüfen]**, das widerspricht (1); Bits-Geschenke mit Spielwirkung
    nur, falls ein Erlösmodell für Entwickler existiert, das (1) erfüllt **[zu prüfen]**. **Variante C (eigener Shop: Web-Shop +
    App-Store-IAP)** ist der primäre Echtgeld-Weg.
  - zu (2): **Sponsor-Fenster.** Geschenke von Zuschauer:innen werden nur angenommen, solange ein Fenster offen ist: periodisch in
    der Erkundung (Standard alle 300 s Laufzeit für 60 s), beim Betreten eines Safe Rooms (solange drinnen, höchstens 90 s) und als
    **Boss-Countdown** (45 s ab Betreten des Quartier-/Etagenboss-Raums). Je Fenster begrenzte Plätze (Standard 3, wer zuerst
    kommt) und 1 Geschenk je Zuschauer:in, zusätzlich die Lauf-Caps. Außerhalb: Ablehnung mit `E_WINDOW_CLOSED` bzw.
    `E_WINDOW_FULL`; die Oberfläche zeigt, wann das nächste Fenster öffnet. Im Kampf öffnet kein Fenster (die Uhr steht).

## 6. Verbindliche Architektur-Verträge (Kurzform — Details in 02_TECH.md)

Autoloads (Reihenfolge):

| Name | Datei | Aufgabe |
|---|---|---|
| `Events` | `res://autoload/events.gd` | Globaler Signal-Bus (nur Signale, keine Logik) |
| `DB` | `res://autoload/db.gd` | Lädt & validiert JSON-Daten, Getter wie `DB.enemy(id)` |
| `Game` | `res://autoload/game.gd` | Laufzeit-Spielstand (Party, Inventar, Etage, Timer, Show-Stats, Flags) |
| `Show` | `res://autoload/show.gd` | Zuschauer/Follower/Hype, Achievements, Sponsor-Trigger, M.O.D.-Ansagen |
| `Save` | `res://autoload/save.gd` | Serialisierung `Game` ↔ JSON in `user://saves/slot_N.json` |
| `Router` | `res://autoload/router.gd` | Szenenwechsel mit Übergängen (Fade/„Kampf-Swirl“), Kampf starten/beenden |
| `Sfx` | `res://autoload/sfx.gd` | Prozedurale Sounds (Platzhalter), Lautstärke-Busse |

Ordner unter `res://`:

```
autoload/      Singletons (oben)
core/          reine Logik (RefCounted): data/, stats/, battle/, show/, loot/, progression/, dungeon/, live/ (SHOWRUN)
data/          JSON: die 13 GameData-Tabellen (statuses, skills, items, classes, party, enemies, floors, lootboxes,
               achievements, sponsors, milestones, mod_lines, scenes) + events.json (SHOWRUN, geladen von EventCatalog)
art/           shaders/, materials/, kit/ (prozedurale Mesh-Bauer: Figuren, Umgebung, Props, VFX)
scenes/        boot/, title/, exploration/, battle/, safe_room/, ui/ (wiederverwendbare UI)
tests/         run_tests.gd + test_*.gd
```

Außerhalb von `res://`: `prime-time-dungeon/docs/` (Dokumente), `prime-time-dungeon/tools/` (check.sh, fullrun.sh, perf.sh,
make_icons.sh), `prime-time-dungeon/README.md` (Einstieg).

Szenenfluss: `Boot → Title → (Neues Spiel | Laden) → Exploration(Etage N) ⇄ Battle ⇄ SafeRoom → … → Credits/GameOver`.

## 6b. Live-Modus „SHOWRUN“ (geplant, Architektur muss ihn jetzt schon ermöglichen)

Spielmodus, den man **am Stück** spielt: Eine **Live-Etage** ist nur in einem festen **Zeitfenster X** geöffnet
(z. B. Sa 20:00–21:30). Alle Teilnehmer spielen denselben Seed mit einem **Quest-Ziel**, solo oder im **Koop (2–4)**.
**Zuschauer** können Läufe **in Echtzeit verfolgen** (mit Verzögerung) und Spielern **Sponsor-Pakete** (Gold, Kisten) schicken,
die im Spiel als Sponsor-Drop mit M.O.D.-Ansage ankommen. Details: `docs/05_LIVE_MODUS.md`.

Pflichten für den Code **schon im Vertical Slice** (damit der Modus später ohne Umbau kommt):
1. **Deterministischer Kern:** Gleicher Seed + gleiche Befehlsfolge ⇒ exakt gleiches Ergebnis. Kein `randf()`/`randi()` global,
   kein `Time`-abhängiges Verhalten in `core/`.
2. **Befehle rein, Ereignisse raus:** Spieler-Eingaben werden als serialisierbare **Commands** (Dictionary/JSON) an den Kern gegeben,
   der Kern liefert serialisierbare **Events** zurück (ActionEvents im Kampf, ExploreEvents in der Erkundung). Die Darstellung spielt
   nur Events ab. ⇒ Netzwerk, Zuschauer-Stream und Replays nutzen später genau diese Daten.
3. **Ein Run-Log:** `Game` kann einen Lauf als Liste (Seed, Commands, Zeitstempel) aufzeichnen und wieder abspielen.
4. **Externe Geschenke als Eingang:** Sponsor-Geschenke laufen über eine einzige Funktion (`Show.receive_gift(gift: Dictionary)`),
   egal ob sie vom Spiel selbst (Hype-Schwelle) oder später von echten Zuschauern kommen.
5. **Zeitfenster & Quest als Daten:** `floors.json` / `events.json` können `quest` (Ziel-Typ + Parameter) und `window`
   (open/close-Zeit, Dauer) enthalten. Offline gibt es diesen Modus als „Event-Lauf“ mit festem Seed + lokaler Bestenliste.
6. **Sponsor-Fenster (Entscheidung 2026-10-08 (2), siehe Kap. 5):** Wann Zuschauer:innen helfen dürfen, entscheidet der
   deterministische Kern in **Ticks** (`RunSim` + `SponsorWindows`, Regeln in `events.json → rules.sponsor_windows`, Standard
   für Kampagne/Offline) — aufgezeichnet im Run-Log, im Replay identisch, **autoritativ** geprüft in `GiftPolicy.check`
   (Server-Autorität, 05 Kap. 3). `Show.receive_gift()` bleibt der einzige Eingang; Fenster öffnen/schließen als Signale
   (`Events.sponsor_window_opened/closed`), das TV-Overlay zeigt den Zustand.
7. **Erlös nur an den Betreiber (Entscheidung 2026-10-08 (1)):** Kein Code-Pfad, kein Datenfeld und kein Ledger-Konto für
   Auszahlungen oder Beteiligungen an Spieler:innen/Streamer:innen.

## 7. Ziel dieses Repos (jetzt)

Ein **spielbarer Vertical Slice** von Etage 1 in Godot 4.7 mit Option-B-Optik:
Titel → Intro (M.O.D.) → Etage 1 erkunden → mehrere CTB-Kämpfe → Show-System + Achievements →
Safe Room mit Lootboxen + Speichern → Quartier-Boss → Treppe/Etagenboss → „Etage 2 folgt“-Abspann.
Läuft auf PC (Tastatur/Gamepad) und ist für Touch vorbereitet (On-Screen-Steuerung).
