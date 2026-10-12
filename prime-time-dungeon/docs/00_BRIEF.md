# PRIME TIME DUNGEON — Leitentscheidungen (Brief)

> Arbeitstitel. Eigenständige IP, **inspiriert** von *Dungeon Crawler Carl* (Matt Dinniman).
> Keine Namen, Figuren, Orte oder Texte aus DCC. Wir übernehmen nur Genre-Ideen
> (Dungeon als galaktische Reality-Show, Zuschauer/Sponsoren, Lootboxen, Etagen-Timer, sarkastische System-KI),
> die nicht urheberrechtlich geschützt sind. Lizenz-Option bleibt offen (siehe Strategie).

Dieses Dokument ist die **verbindliche Grundlage**. Alle anderen Dokumente und der Code richten sich danach.
Änderungen hier nur bewusst und mit Begründung.

**Vorrang bei Widersprüchen:** dieses Dokument > `07_ECHTZEITKAMPF.md` (alles Kampfrelevante) > `09_STAFFELN.md` (Staffel,
Sendeplan, Tod und Modi, Stufen, Talente, Berufe, Schläfer, KI-Besetzung; CR-25) >
`06_PROGRESSION_MAROTTEN_KI_ADMIN.md` (Progression, Marotten, KI-Admin, Twists) > `08_CASTING.md` (Casting, Persona,
Vorleben, persönlicher Erzählstrang) > `01_GDD` / `02_TECH` / `03_ART` / `05_LIVE_MODUS` (je nach Thema).

---

## 1. Prämisse (eigene Welt)

- Das galaktische Medienkonglomerat **NOVA SYNDIKAT** hat die Erdoberfläche „zurückgebaut“, um Platz für
  seine Erfolgsshow **DUNGEON PRIME TIME** zu schaffen. Überlebende Menschen werden zu **„Kandidat:innen“**.
- Der Dungeon hat **Etagen**. Jede Etage **stürzt ein** — in einer Staffel zu ihrem festen Termin im Sendeplan, am Stück
  nach ihrem **Countdown** (`09_STAFFELN.md`). Wer dann keine **Treppe** genommen hat, wird **Mit Netz** von der Regie
  gerettet (gegen Gebühr) und ist **Ohne Netz** raus; nur Event-Läufe (Kap. 6b) enden wie bisher mit Game Over.
- Moderiert wird alles von **M.O.D.** (Mediale Omnipräsente Direktorin) — die Show-KI. Sarkastisch,
  quotengeil, regelversessen, heimlich etwas sentimental. Sie kommentiert Achievements, Loot und Tode.
- Spielfigur: die **Kandidat:in der Spieler:in** („Persona“), ein Mensch wie alle Kandidat:innen — Name, Beruf und Hobby legt
  man vor dem ersten Lauf im **Casting** fest (Nutzeridee 2026-10-10, Kap. 5; Vertrag `08_CASTING.md`). Standard und Kanon
  ist **Kai**, Pfleger:in aus einem Tierheim, pragmatisch, trocken; jede Persona kennt Mopsula aus diesem Tierheim.
- Begleiter: **Graf Mopsula**, ein Mops aus dem Tierheim, der durch den Dungeon sprechen kann, sich für
  einen gelehrten Grafen hält und sich als Magier entpuppt. Belehrend (mit Fußnoten), pathetisch um Mitternacht,
  loyal bis in die Knochen.
- Ton: schwarzer Humor + echte Gefahr + Satire auf Streaming-/Werbe-/Gacha-Kultur. Nicht zynisch gegenüber den Menschen.

## 2. Design-Säulen

1. **Überleben UND unterhalten** — Jede Entscheidung bezahlt man in Sicherheit oder in Show.
2. **FF12-Welt, Kampf „WoW-light“ direkt in der Welt** — Erkundung in Echtzeit-3D mit sichtbaren Gegnern (FF12); gekämpft
   wird **in Echtzeit im selben Raum**, ohne Szenenwechsel: Ziel wählen, Auto-Angriff, kleine Aktionsleiste mit Abklingzeiten,
   Zauberleisten, Boden-Telegraphen (Entscheidung 2026-10-10, Kap. 5; Vertrag `07_ECHTZEITKAMPF.md`). Der bisherige
   rundenbasierte **CTB**-Kampf (Conditional Turn-Based, FF10) ist seit R5b aus der Kampagne verschwunden und lebt als Kern
   des optionalen Minispiels **„Stempelduell“** weiter (`10_MINISPIEL_STEMPELDUELL.md`).
3. **Kurze Sessions, lange Motivation** — Eine Sitzung 15–60 min; eine Etage über Tage (Staffel) — oder am Stück.
   Ausloggen geht überall außerhalb des Kampfes (`09_STAFFELN.md`).
4. **Die Show ist das UI** — HUD wie eine TV-Übertragung: Live-Zuschauerzahl, Chat-Ticker, Sponsor-Banner.
5. **Lesbarer Stil** — stilisiertes Low-Poly mit Toon-Shading (Option B), klare Silhouetten, starke Farben.

## 3. Kern-Spielschleife

```
Etage betreten → Erkunden (Gegner sichtbar, Truhen, Events, Safe Room)
   → Kampf (Echtzeit in der Welt) → Zuschauer ↑ → Follower/EXP/Loot
   → Safe Room (Heilen, Speichern, Lootboxen öffnen, Automat-Shop)
   → Treppe finden (Einsturztermin bzw. Countdown!) → optional Etagenboss → nächste Etage
   ↺ jederzeit Ausloggen (außer im Kampf): die Figur bleibt als Schläfer — im Safe Room sicher und ausgeruht (09)
```

## 4. Systeme (Umfang Vertical Slice = Etage 1 komplett, Etage 2 angelegt)

| System | Kurzbeschreibung |
|---|---|
| Erkundung | Third-Person, Kamera hinter der Figur (orbit). Etage 1 ist handgebaut (Layout-Daten in `floors.json`), ab Etage 2 prozedural aus Raum-Modulen auf Raster (`DungeonGenerator`). Gegner patrouillieren sichtbar; ein Kampf beginnt per Pull (Schlag, Fähigkeit oder Gegenstand auf einen Gegner), wenn ein verfolgender Gegner zuschlagen kann oder nach 4 s Verfolgung (07 §2.2). Vorteil/Nachteil je nach Anlauf (Rücken = Präventivschlag). |
| Kampf | **Echtzeit in der Welt** („WoW-light“, `07_ECHTZEITKAMPF.md`): Party (Kai + Graf Mopsula; gesteuert wird die gewählte Figur, die andere spielt die KI) vs. 1–6 Gegner im Raum, markiert durch einen Studio-Lichtring. Auto-Angriff, 4 Fähigkeiten + **SHOW** (Stunt) + Trank, eine Taste für den Partner, Unterbrechen, Ausweichen, Bossphasen. **Bis R5** zusätzlich der bisherige CTB-Kampf (Zugreihenfolge aus SPD + Aktionsgewicht wie FF10; Befehle Angriff, Fähigkeit, Item, Stunt, Verteidigen, Flucht) hinter dem Schalter `combat_mode`. |
| Show-System | **Zuschauer** (live, pro Kampf/Erkundung schwankend) und **Follower** (dauerhaft). Abwechslungsreiche Aktionen, knappe Siege, Stunts, Combos, Kills mit Fähigkeiten erhöhen den Hype. Schwellenwerte → **Sponsor-Geschenk** (Heilung/Buff/Item) mitten im Kampf. |
| Lootboxen | Bronze/Silber/Gold/Fanpost-Paket aus Achievements und Bossen. Nur im Spiel verdient, **niemals Echtgeld**. Öffnen nur im Safe Room, mit M.O.D.-Kommentar. |
| Achievements | Vom Spiel live vergeben („Erster Kill“, „Mit 1 HP gewonnen“, „Pazifist (5 min ohne Kampf)“ …) → Lootbox + M.O.D.-Spruch. |
| Etagen-Timer / Sendeplan | In Staffeln stürzt jede Etage zu ihrem Termin ein (Sendeplan: 2, 3, 4, dann je 5 Tage; 09 §2.4). Am Stück und in Event-Läufen läuft der Countdown nur in der Erkundung: Etage 1 20:00 min, Warnungen bei 5:00 / 1:00. |
| Safe Room | Volle Heilung, Speichern, Lootboxen, Automat (Shop), Gespräch mit Mopsula (Charaktermomente). Keine Gegner. |
| Progression | Stufe/EP, Stats (HP, MP, STR, MAG, DEF, RES, SPD, LCK), Ausrüstung (Waffe, Rüstung, Accessoire), Fähigkeiten nach Stufe. **Klassenwahl ab Etage 3** (Datenmodell jetzt schon vorbereitet). In Staffeln (09 §8): Höchststufe 50 mit Stufen-Bändern, **Fähigkeitenbuch**, **Talentbaum** (ersetzt „1 aus 2“, auch in Event-Läufen) und **Berufe** (zwei Hauptberufe, dazu Kochen und Erste Hilfe für alle). |
| Casting | Vor dem ersten Lauf in unter einer Minute: Name, Vorleben (der echte Beruf), Hobby/Talent (oder „Rest automatisch“ = Kai). Kampfwerte ändert das nicht: das Vorleben bringt in Staffeln einen **Vorsprung in einem Beruf** (+50), das Hobby ein Rezept (`09_STAFFELN.md` §8.6, 08 CR-33); die Kandidatenkarte und ein persönlicher Erzählstrang (Rival:in, Grüße von zu Hause, Sponsor, Running Gag) kommen aus festen Katalogen — nie im Kampf. Angaben bleiben auf dem Gerät; **KI-Casting** nur als Opt-in ab 16; kein Foto in V1 (`08_CASTING.md`). |
| Bosse | Etage 1: **„Der Hausmeister“** (Quartier-Boss) + Etagenboss **„Die Rattenkönigin von Gleis 9“**. |
| Speichern | Ein Spielstand pro Slot (3 Slots), JSON in `user://`. Nur im Safe Room + Autosave bei Etagenwechsel. In Staffeln (09 §9.1): **Dauerspeicherstand mit Command-Journal** (kein Zurückladen), Ausloggen überall außerhalb des Kampfes. |
| Tod und Einsturz | Mit Netz: Wiederbelebung im Safe Room bzw. Rettung durch die Regie (Gebühr höchstens einmal je 7 Tage); Ohne Netz: raus (Studiogast); Etage 1 ist die Generalprobe (09 §7). **Game Over** gibt es nur Ohne Netz und in Event-Läufen. |
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

- **Entscheidung (Nutzer, 2026-10-10), verbindlich — Kampf** — Wortlaut:
  > „Variante 3 bitte“

  Gewählt aus drei vorgelegten Kampf-Varianten; Variante 3 = **„WoW-light direkt in der Welt“**. Die Detailentscheidungen hat
  der Nutzer an das Team delegiert (Maßstab: gute UX, Spaß, Witz, ein einfaches, sofort verständliches Konzept); sie stehen in
  `07_ECHTZEITKAMPF.md` §0.1. Folgen:
  - Gekämpft wird in Echtzeit in dem Raum, in dem man sich trifft (Studio-Lichtring als Kampffläche, keine Kampfszene, kein
    Szenenwechsel). Die Etagen-Uhr steht im Kampf wie bisher; im Kampf öffnet kein Sponsor-Fenster.
  - Der Kern bleibt deterministisch (Kap. 6b): eigene Simulation mit 30 Ticks/s, nur Ganzzahlen, jeder Kampf-Befehl trägt
    seinen Kampf-Tick; Replays und Verifier rechnen bitgenau nach.
  - Der CTB-Kampf (FF10) lief bis R5 hinter dem Schalter `combat_mode`; seit R5b (07 §12.6, 2026-10-12) kämpft die
    Kampagne nur in Echtzeit, alte Spielstände werden auf Echtzeit umgestellt (Spielstand v2), und die CTB-Engine lebt
    eingefroren als Kern des Minispiels „Stempelduell“ weiter (`10_MINISPIEL_STEMPELDUELL.md`, SD1). Umgesetzt in den
    Phasen R1–R5 (07 §12).

- **Nutzeridee (2026-10-10), übernommen und verbindlich — Casting** — Wortlaut:
  > „wie wäre es, wenn der spieler bei der charakter-auswahl seine eigenen daten angibt, beruf, talent, charakter
  > eigentschaften…und ggfs ein foto. daraus erschliesst die KI Anfangs-talente und baut so den erzählstrang aug“

  Die Details hat der Nutzer an das Team delegiert (Maßstab: gute UX, Spaß, Witz, Abwechslung, ein simples, sofort
  verständliches Konzept); sie stehen in `08_CASTING.md` §0.2 und §0.3. Rahmenentscheidungen (Orchestrator):
  - Die Spielfigur wird zur **Persona** der Spieler:in: eine menschliche Kandidat:in wie bisher Kai. Graf
    Mopsula bleibt fest, die Figurenwahl aus 06 bleibt.
  - Vorleben-Vorsprung und Erzählstrang kommen **offline aus festen Katalogen und Vorlagen**; die KI ist ein **optionaler** Zusatz
    (KI-Casting: Opt-in ab 16 mit Einwilligung, nur Katalog-IDs und gefilterte Zeilen, jeder Fehler → offline).
  - **Kein Foto in V1**; ein „Avatar aus Foto“ kommt frühestens nach einer Rechtsprüfung (08 §6.4).
  - Der Kern bleibt deterministisch (Kap. 6b): Aufgezeichnet werden nur Katalog-IDs (Command `persona`); Name und
    persönliche Angaben liegen in einer eigenen Datei je Slot, nie in Run-Log, Replay, Bestenliste oder Cloud-Spielstand.
    Event-Läufe spielen ohne Persona (Kanon-Kai).

- **Nutzeridee (2026-10-11), übernommen und verbindlich — Staffeln** (CR-25) — Wortlaut:
  > „die neue spezies und beruf ab ebene 3, nicht dem 3ten level. wie in der geschichte zu dungeon crawler carl halt. ebenso:
  > können wir einbauen, dass zb jeweils ein spielzyklus gestartet wird, der maximal 18 ebenen zulässt und ca 2-3 monate
  > dauert? so ein wenig, wie in dem Buch. die erste ebene dauert dann 2 Tage - die zweite 3 - die dritte 4 etc. Den zyklus
  > kann man jederzeit starten sobald man eine mindestanzahl an crawlern hat. sonst werden diese an den Computer gegeben, der
  > die restlichen crawler selbst simuliert und steuert. der crawler kann jederzeit ausloggen. Bleibt dann aber da als spieler
  > stehen und ist der situation ausgeliefert, wo er ausgeloggt wird. d.h. im dungeon kommen dann monster und andere spieler
  > ggfs vorbei. am besten daher im saferoom, wenn man erholung und sicherheit will. etc. macht sinn? wie würdest du das ganze
  > umsetzen? Die skills sollten realistisch vergeben werden. Wie in den typischen Spielen, wie world of warcraft.“

  Die Details hat der Nutzer an das Team delegiert (Maßstab: gute UX, Spaß, Witz, Abwechslung, Wohlbefinden, ein simples,
  sofort verständliches Konzept); sie stehen in `09_STAFFELN.md` (Kap. 0.3, Review-Entscheidungen Kap. 0.4). Die
  Entscheidungen S-1 … S-12 in Kurzform:
  - **S-1 Begriffe:** Vorleben = der echte Job aus dem Casting, **Klasse** = die Wahl auf Etage 3, **Berufe** = Handwerke wie
    in WoW; in UI und Texten heißt es immer **Etage** und **Stufe**, nie „Level“ oder „Ebene“.
  - **S-2 Staffel:** ein Zyklus = eine **Staffel** im Format **6, 12 oder 18 Etagen** (nach Kauf); Dauer je Etage 2, 3, 4,
    dann je 5 Tage → 24, 54 oder 84 Tage; jede Etage hat einen festen Einsturztermin.
  - **S-3 Treppenregel:** Etagen 1–3 sind sofort offen, ab Etage 4 höchstens eine Etage Vorlauf.
  - **S-4 Einsturz:** **Mit Netz** rettet die Regie (Gebühr höchstens einmal je 7 Tage, Schläfer im Safe Room gratis),
    **Ohne Netz** ist man raus (Studiogast); **Etage 1 ist die Generalprobe** ohne Verluste.
  - **S-5 Tod:** Mit Netz Wiederbelebung im Safe Room (sonst am Etageneingang), Ohne Netz endgültig ab Etage 2.
  - **S-6 Besetzung:** 100 Plätze; freie Plätze spielen **KI-Kandidat:innen**, überall als KI gekennzeichnet.
  - **S-7 Ausloggen:** überall außerhalb des Kampfes; die Figur bleibt als **Schläfer** — im Safe Room sicher und
    ausgeruht, im Gang mit bis zu drei Begegnungen und der Taktik aus dem Ausloggen-Dialog; deterministisch aufgezeichnet.
  - **S-8 Andere Spieler:innen:** sehen, bewachen, heilen, wecken, handeln — **nie Angriffe auf Schläfer**; PvP nur als
    Opt-in in Show-Arenen.
  - **S-9 Fertigkeiten wie in WoW:** Fähigkeiten auf festen Stufen, ein Talentbaum mit Reihen, Berufe 1–300 mit Farben.
  - **S-10 Vorleben:** +50 in einem Beruf und ein Hobby-Rezept statt der Starttalente (08 CR-33).
  - **S-11 Phasen:** ST1 Offline-Staffel → ST2 Online-Staffeln asynchron → ST3 Echtzeit-Präsenz; der Echtzeitkampf (07)
    kommt zuerst.
  - **S-12 IP:** Jede Mechanik ist frei, die Summe ist nah am Buch: Namen, Begriffe, Figuren und Texte bleiben eigen, das
    Anwalts-Memo prüft die Staffel-Struktur vor jeder öffentlichen Erwähnung, kein Marketing mit „18 Etagen“; im Spiel
    heißen Teilnehmende **Kandidat:innen**.

  Folgen: Jede Staffel-Regel hängt an `state.season != null`; bis „Sendung starten“ Standard wird (der eine
  `SIM_VERSION`-Sprung, 09 Kap. 11.1), gibt es Staffeln nur in Debug-Builds und im Harness, alle anderen Läufe bleiben
  bitgleich. SHOWRUN-Event-Läufe bleiben ein eigener Modus mit Countdown und Game Over. Der Vertrags-Durchgang ST0 ist
  gelandet (02_TECH §0.8).

## 6. Verbindliche Architektur-Verträge (Kurzform — Details in 02_TECH.md)

Autoloads (Reihenfolge):

| Name | Datei | Aufgabe |
|---|---|---|
| `Events` | `res://autoload/events.gd` | Globaler Signal-Bus (nur Signale, keine Logik) |
| `DB` | `res://autoload/db.gd` | Lädt & validiert JSON-Daten, Getter wie `DB.enemy(id)` |
| `Game` | `res://autoload/game.gd` | Laufzeit-Spielstand (Party, Inventar, Etage, Timer, Show-Stats, Flags) |
| `Show` | `res://autoload/show.gd` | Zuschauer/Follower/Hype, Achievements, Sponsor-Trigger, M.O.D.-Ansagen |
| `Save` | `res://autoload/save.gd` | Serialisierung `Game` ↔ JSON in `user://saves/slot_N.json` |
| `Router` | `res://autoload/router.gd` | Szenenwechsel mit Übergängen (Fade) — der Echtzeitkampf läuft ohne Szenenwechsel in der Erkundung (07 §2.8) |
| `Sfx` | `res://autoload/sfx.gd` | Prozedurale Sounds (Platzhalter), Lautstärke-Busse |

Ordner unter `res://`:

```
autoload/      Singletons (oben)
core/          reine Logik (RefCounted): data/, stats/, battle/, show/, loot/, progression/, dungeon/, live/ (SHOWRUN),
               season/ (Staffeln, 09), stempel/ (Stempelduell, 10)
data/          JSON: die 23 GameData-Tabellen (statuses, skills, items, classes, party, enemies, floors, lootboxes,
               achievements, sponsors, milestones, mod_lines, scenes, talents, species, marotten, twists, origins,
               looks, seasons, professions, cast, themes) + rt_balance.json + events.json (SHOWRUN, geladen von
               EventCatalog) + mod_filter.json (Wortfilter für „M.O.D. live“, ModLineFilter)
art/           shaders/, materials/, kit/ (prozedurale Mesh-Bauer: Figuren, Umgebung, Props, VFX)
scenes/        boot/, title/, exploration/, combat/ (Echtzeitkampf, 07), stempel/ (Stempelduell, 10), safe_room/, ui/
               (wiederverwendbare UI)
tests/         run_tests.gd + test_*.gd
```

Außerhalb von `res://`: `prime-time-dungeon/docs/` (Dokumente), `prime-time-dungeon/tools/` (check.sh, fullrun.sh, perf.sh,
make_icons.sh), `prime-time-dungeon/README.md` (Einstieg).

Szenenfluss: `Boot → Title → (Neues Spiel | Laden) → Exploration(Etage N) ⇄ SafeRoom → … → Credits/GameOver`; gekämpft wird
in der Exploration.

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
   egal ob sie vom Spiel selbst (Hype-Schwelle) oder später von echten Zuschauern kommen. Ebenso ist die **Staffel-Uhr**
   ein externer Eingang (CR-25): Der Client zeichnet die Wanduhr als Commands `clock` / `away` auf (cmd id 0 wie Geschenke,
   09 §9.1); der Kern kennt keine Uhr.
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
Titel → Intro (M.O.D.) → Etage 1 erkunden → mehrere Kämpfe (Echtzeit in der Welt, 07) →
Show-System + Achievements → Safe Room mit Lootboxen + Speichern → Quartier-Boss → Treppe/Etagenboss →
„Etage 2 folgt“-Abspann.
Läuft auf PC (Tastatur/Gamepad) und ist für Touch vorbereitet (On-Screen-Steuerung).
