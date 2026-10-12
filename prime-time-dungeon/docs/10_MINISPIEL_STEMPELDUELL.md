# PRIME TIME DUNGEON — Mini-Spiel „Stempelduell“ (Spieleshow in der Show, Etage 8)

> **Grundlage:** Nutzerwunsch vom **2026-10-11**, Wortlaut:
> „kannst den irgendwo als anderen spielmodus speichern - vielleicht sowas wie ein mini-spiel , wie ein simuliertes
> kartenspiel auf ebene 8😃“
>
> „den“ ist der bisherige rundenbasierte **CTB-Kampf** (Conditional Turn-Based wie FF10: Zugreihenfolge aus SPD und
> Aktionsgewicht; Befehle Angriff, Fähigkeit, Item, Stunt, Verteidigen, Flucht; 01_GDD §3, 02_TECH §5), den die Kampagne mit
> 07 R5b durch den Echtzeitkampf ersetzt. Die Details hat die Nutzerin/der Nutzer an das Team delegiert (Maßstab: gute UX,
> Spaß, Witz, Abwechslung, **ein simples, sofort verständliches Konzept**).
>
> **Rahmen des Orchestrators (verbindlich, der Nutzerin/dem Nutzer mitgeteilt):** (R-1) Name **„Stempelduell“**, optionale
> Nebenattraktion („Spieleshow in der Show“), nie Pflicht, keine Kampfkraft als Belohnung, nichts käuflich; (R-2) Ort
> **Etage 8** im „Amt für Etagenwesen“ (09 Kap. 3.1), bis dahin **Titel → Extras → Stempelduell (Vorschau)**; (R-3) Kern ist
> die **bestehende CTB-Engine, unverändert** — die Zugreihenfolge wird zur **Wartenummern-Anzeige**, Aktionen werden zu
> **Karten** mit sichtbarer **Bearbeitungszeit** (= Aktionsgewicht), Hand aus 5 Karten, eine Karte je Zug; Gegner
> Sachbearbeiter:in, Abteilungsleiter:in, Endgegner „Der Stempelmeister“, später KI-Kandidat:innen; (R-4) Regeln in fünf
> Sätzen, erstes Duell ist Tutorial, Bürokratie-Witz ohne Sexuelles, ohne Spott über echte Berufe oder Personen, ohne Politik,
> IP-sicher; (R-5) Phasen M1 Extraktion, M2 Mini-Spiel, M3 Etage 8. Alles Weitere sind Detailentscheidungen dieses Dokuments.
>
> **Abgestimmt auf** `00_BRIEF.md` (Kap. 2, 5, 6b), `01_GDD.md` (§3 CTB, §11.1 M.O.D.-Ton, §13, §14 UX), `02_TECH.md` (§0.4
> Schichten, §1 Dateibaum, §5 Kampf-Kern, §9 Router, §11 Tests, §12.1 Budgets), `03_ART.md` (§2.4, §9 TV-Look, F8 Glyphen),
> `04_STRATEGIE_ROADMAP.md` (§2.2/2.3 IP, §6.2 Geld), `05_LIVE_MODUS.md` (Determinismus, `rules_hash`), `06` (L-1 … L-7, §2.7,
> §4.5, §4.8), `07_ECHTZEITKAMPF.md` (§4.11, §12.3–12.8: R5b), `08_CASTING.md` (Persona, Privatsphäre) und `09_STAFFELN.md`
> (Kap. 1.2 Sprachregel, 2.4, 2.8, 3.1, 4.3, 9.1, 11). Code-Stand: `claude/prime-time-dungeon` @ `62a6a95` (R1–R4, R5a, K0–K2
> gelandet; **R5b und 09 ST0 offen**); gegen diesen Stand ist das Review vom 2026-10-11 geprüft (Kasten unten).
>
> **Status:** Design-Vertrag für die Phasen **SD1–SD3** (Kap. 7). Für alles rund um das Mini-Spiel gilt dieses Dokument; die
> Kampagne ändert es nur über die Änderungsanträge **CR-34 … CR-38** (Kap. 7.6). Die Vorrangklausel des Briefs bleibt
> unberührt.
>
> **Stand SD1 (2026-10-12, mit 07 R5b-2b, Branch `ptd/r5b2b`):** SD1 ist umgesetzt — Kap. 6.2 Zeilen 0–5; Zeile 6, der
> Stub für den Befehl `sd`, bleibt bei ST0 bzw. SD3. Die Kampagne kämpft nur noch in Echtzeit und nennt die Engine nirgends
> mehr (`test_sd_boundaries`); die Engine liegt — bis auf die herausgelöste Beuteregel unverändert — eingefroren in
> `core/stempel/ctb/` (`test_sd_engine_golden`).
> Einzelheiten und Abweichungen: Kap. 6.2 „Umgesetzt“; was SD2 vorfindet und braucht: Kap. 7.3 „Stand nach SD1“; Bericht mit
> Gates: 07 §12.6 „Stand R5b-2b“.
>
> **Stand SD2-A/B (2026-10-12, Branch `ptd/sd2`):** Regelbuch und Duell-Kern sind umgesetzt — rein, headless, noch ohne
> Bildschirm: `data/stempel/*.json` (24 Karten, 4 Gegner, 4 Zustände, Durchsage, Lernduell-Drehbuch, 101 Zeilen, 12
> Kosmetik-Einträge, 10 Dienstauszeichnungen), `SdRulebook` mit eigenem Validator, `SdSetup`, `SdDuel`, `SdEvent`, `SdAi`,
> `SdLog`, `SdCollection` und sieben neue Testdateien. Die Engine ist unverändert (`test_sd_engine_golden` grün). Was beim
> Umsetzen entschieden wurde (U-1 … U-16), die Gates und was SD2-C … F vorfinden: Kap. 7.3 „Stand SD2-A/B“; Messwerte und
> die geänderte Band-Grenze des Stempelmeisters: Kap. 6.9.
>
> **Namen der Phasen:** Der Orchestrator nennt sie M1–M3. Weil „M0–M8“ schon die Module aus 02_TECH sind — und **M1 genau der
> CTB-Kampf-Kern ist, um den es hier geht** —, heißen sie hier **SD1–SD3** (Stempelduell-Phasen): SD1 = M1, SD2 = M2,
> SD3 = M3, gleicher Inhalt.
>
> **Konventionen:** Prosa Deutsch; IDs, Pfade (relativ zu `prime-time-dungeon/game/` = `res://`), JSON-Keys, Klassen- und
> Methodennamen Englisch. Spielertexte folgen der Sprachregel aus 09 Kap. 1.2 („Etage“, „Stufe“, „Kandidat:in“). Alle Zahlen
> sind **Startwerte** für Harness und Playtests (Kap. 6.9). **[zu prüfen]** = reale Fakten (Recht, Marken), **[zu messen]** =
> Zielwert, den ein Gate misst.

---

## Review 2026-10-11 (unabhängige Prüfung, eingearbeitet)

Geprüft gegen den Code und mit einem Wegwerf-Prototyp: Regelbuch als Engine-Daten über `GameData.load_from_dicts`, Hand als
Fähigkeitenliste um den **unveränderten** `BattleState`, drei Spieler-Bots (Heuristik „gut“, `AutoPolicy`, Zufall), 200–300
Seeds je Zelle. Ergebnis: Der Adapter trägt (die Gegner-KI wählte nie eine Karte außerhalb der Hand, kein ungültiger Befehl,
der Probelauf der Vorschau ändert den Hash nicht, Schnappschüsse spielen identisch weiter, Dienstschluss in 0 % der
Duelle). Die Funde und was dieses Dokument daraufhin ändert:

| # | Schwere | Fund | Entscheidung (Kap.) |
|---|---|---|---|
| 1 | Blocker | `skl_sd_none` mit `damage_type none` scheitert an der Grundangriffs-Regel des Validators — kein Gegner lädt | formal gültiger physischer Grundangriff, wird nie ausgeführt (6.4, 6.5) |
| 2 | Blocker | Der Echtzeitkampf braucht `BattleCommand.Kind` und `BattleState.roll_drops` — der Grenztest wäre ab Tag 1 rot (07 §12.6 Schritt 3 hat dieselbe Lücke) | **fünf** Engine-Klassen umziehen; `battle_command.gd` bleibt geteilt; `roll_drops` vorher nach `BattleResult` (6.2, CR-34, Hinweis in 07) |
| 3 | Major | Grenztest: `state_hash.gd` und Kommentare schlagen an; grün erst, wenn R5b die CTB-Teile von heute 27 weiteren Testdateien ersetzt hat; `test_m1_stats` zählt die Dateien in `core/battle` | Positivliste + nur Code-Zeilen; Abhängigkeit und Aufwand genannt; `test_m1_stats` bekommt den neuen Ordner (6.2, 6.3, 7.2) |
| 4 | Major | Endgegner unschlagbar: Geduld 72, Tempo 12, 2 × Großer Amtsstempel — im Prototyp 1 Sieg in 1 200 Duellen (passende Mappe 0,3 %, sonst 0 %) | Startwerte Geduld 50, Tempo 10, Deck mit 1 × Großem Amtsstempel; Prototyp: passende Mappe 50–66 % (3.4, 6.9) |
| 5 | Major | Drei Sonderregeln für einen Gegner (Tempo 12, Wiedervorlage halb, Show-Karten −15); gegen ihn war die Wiedervorlage ein Minusgeschäft | gleiche Regeln für alle: Tempo 10, kein Engine-`boss` (SD-14) |
| 6 | Major | Credits und Fanpost-Paket sind mittelbar Kampfkraft (Automat, Beute-Pool mit Ausrüstung) — widerspricht R-1 | Staffel-Belohnung nur Follower (5.3) |
| 7 | Major | „Die Vorschau ist exakt“ stimmt nicht: Die Engine rechnet alle späteren Karten mit 3 Werktagen; Nummern auf künftigen Zetteln würden umspringen | Nummer nur auf „JETZT“, Prognose ehrlich benannt (1.2, 4.3) |
| 8 | Major | Telefon: 15 px auf 720p ≈ 8 pt; keine Schriftgröße, kein Kontrastziel; „STEMPELMEISTER“ passt nicht auf einen 88-px-Zettel | ≥ 16 / Touch ≥ 20 px, Schriftgröße 100–150 %, WCAG AA, Kurznamen (2.2, 4.3, 4.8) |
| 9 | Major | Kleingedrucktes (6 % der Geduld) 4–7 Ärger je Werktag, stärkste Karte gegen viel Geduld; Kältespray schlägt Stempel überall außer gegen den Grafen | Kleingedrucktes fest 2 je Zug; Kältespray 2 Ärger (1.6, 2.3) |
| 10 | Minor | Dienstschluss mit Prozentvergleich belohnt Mauern (Heilung 4–5 je Werktag > Ärger 3) | Dienstschluss = vertagt (1.8) |
| 11 | Minor | „Endgegner 5–7 min“ passt nicht zum eigenen Band (24–34 Nummern) | 2–4 min, Endgegner 3–5; 5–10 min = zwei, drei Duelle mit Revanche (0.2) |
| 12 | Minor | Wiedervorlage stapelt nicht, die Karte sagt es nicht; „Kenn ich schon“ nutzt kein Gegner; Doppeltippen auf die Pfote schaltet heimlich Auto | Kartentext „Nicht doppelt“; Zeile gestrichen; Auto nur über Menü/Taste (1.5, 1.6, 4.6) |
| 13 | Minor | Requisit „Nummernautomat“ heißt wie der Etagenboss von Etage 9 (09 Kap. 3.1); Gegnernamen landen im Duell-Hash; Stempelalbum fehlt in 09 S-20 | „Wartemarken-Spender“; Engine-Namen = IDs; CR-36 ergänzt (1.9, 6.4, 7.6) |

Unverändert bestätigt: Regeln in fünf Sätzen genügen (Weiteres steht auf den Karten oder kommt mit dem nächsten Gegner);
Zustands-Zeitpunkte, Gleichstand, Abheften (auch gegen die Durchsage), Lernduell-Untergrenze, Patzer nie tödlich, Elemente auf
festem Ärger, RNG-Lint deckt `core/stempel/**`, `DB.data_hash()` sieht den Unterordner nicht, `Router.push` hängt die 3D-Szene
aus, Export-Filter `data/*.json` erfasst `data/stempel/*.json`; IP und Ton (keine DCC-Begriffe, keine Signatur-Mechanik von
Triple Triad, Gwent oder Hearthstone, Mopsula ohne Königsmotive — „Adelsflamme“ ist der bestehende Name).

---

## Inhalt

0. Kurzfassung (fünf Sätze, Spielidee, Entscheidungen SD-1 …, Ein-Satz-Erklärung)
1. Spielregeln (Ablauf, Wartenummern, Karten, Abheften, Formular-Arten, Zustände, Show-Karten, Ende, Lernduell, Hilfen,
   Abbildung auf die CTB-Engine)
2. Karten & Deck (Deckregeln, Kartenaufbau, Kartenliste, Grundakte, Freischaltung, Aktenschrank, Datenformat)
3. Gegner & Kampagne im Amt (Gegner, Spielweise, Etage 8, KI-Kandidat:innen, Ton und IP)
4. Präsentation & UX (Entscheidung, Bildschirme, Wartenummern-Anzeige, Ablauf eines Zugs, M.O.D. und der Graf, Bedienung,
   Menüs, Barrierefreiheit, Ton)
5. Belohnungen & Ökonomie
6. Technik (Engine-Bestand, Extraktion, Module, Regelbuch, Duell-Adapter, Determinismus, Speichern, Kampagnen-Anbindung,
   Tests, Performance)
7. Umsetzung SD1–SD3 (Reihenfolge gegenüber 07 R5b und 09 ST, Pakete, Dateien, Aufwand, Eigentum, Änderungsanträge, Risiken)
8. Offene Fragen mit Empfehlung

---

## 0. Kurzfassung

### 0.1 Für Spieler:innen in fünf Sätzen

1. Ziel: Bringen Sie die **Geduld** Ihres Gegenübers auf 0, bevor Ihre eigene aufgebraucht ist.
2. Wer dran ist, zeigt die **Wartenummern-Anzeige** — manchmal sind Sie mehrmals hintereinander dran.
3. Sind Sie dran, spielen Sie **eine Karte** aus Ihrer Hand von fünf und ziehen sofort eine neue.
4. Jede Karte hat eine **Bearbeitungszeit** in Werktagen: Je länger sie dauert, desto später kommt Ihre nächste Nummer.
5. Statt einer Karte dürfen Sie **abheften**: Sie tauschen eine Karte, sind schnell wieder dran und nehmen bis dahin nur
   halben Ärger.

Mehr muss man zum Anfangen nicht wissen. Alles Weitere (Formular-Arten, Zustände, Show-Karten) steht auf den Karten selbst
oder kommt mit dem nächsten Gegner dazu — **eine neue Regel je Gegner**, wie 06 L-2 es für Etagen verlangt.

### 0.2 Die Spielidee in einem Absatz

Der alte CTB-Kampf hatte eine Stärke, die im Echtzeitkampf verloren geht: das **Spiel mit der Zeit**. Ein schwerer Schlag
kostet einen späteren nächsten Zug; eine schnelle Aktion schiebt einen noch vor den Gegner; eine Betäubung schiebt ihn nach
hinten. Das Stempelduell macht genau das zum Kern eines kleinen Kartenspiels am Amtsschalter: **Karten kosten nichts außer
Zeit.** Jede Karte ist sofort spielbar, nur ihre **Bearbeitungszeit** entscheidet, wie lange man danach wartet — und die
**Wartenummern-Anzeige** über dem Tisch zeigt beim Antippen einer Karte sofort, wo die eigene nächste Nummer dann landet.
Das ist in einem Satz erklärt, auf einen Blick lesbar und trotzdem taktisch: lange Formulare für viel Ärger, kurze für
Tempo, Wiedervorlagen gegen die Nummer des Gegenübers, Abheften gegen die Durchsage. Die Bürokratie-Satire liefert die
Sprache gratis dazu („Bearbeitungszeit: 3 Werktage“, „Dafür ist sie nicht zuständig“, „Bei Gleichstand geht die Kundschaft
vor“). Ein Duell dauert **2–4 Minuten** (Endgegner 3–5) **[zu messen]** — zwei, drei Duelle mit „Revanche“ sind eine
Runde von 5–10 Minuten —, nichts geht verloren, und M.O.D. moderiert es als Spieleshow in ihrer eigenen Show.

### 0.3 Entscheidungen

Herkunft: **R** = Rahmen des Orchestrators, **D** = Detailentscheidung dieses Dokuments.

| Nr. | Thema | Entscheidung | Herkunft | Kap. |
|---|---|---|---|---|
| SD-1 | Name | **„Stempelduell“**; zwei Alternativen stehen als offene Frage F-1 | R | 8 |
| SD-2 | Rolle | Optionale Nebenattraktion („Spieleshow in der Show“), nie Pflicht für den Fortschritt, nie Kampfkraft für die Kampagne | R | 5 |
| SD-3 | Ort | **Etage 8**, Kulisse „Amt für Etagenwesen“: **Schalter 3 im Wartezimmer** (= Safe Room der Etage). Bis es Etage 8 gibt: **Titel → Extras → Stempelduell (Vorschau)**; danach bleibt der Eintrag als „Freies Spiel“ | R · D | 3.7 |
| SD-4 | Kern | Die **CTB-Engine bleibt unverändert** (`BattleState`, `ActionResolver`, `CTBQueue`, Zustände, `EnemyAI`, `AutoPolicy`, `StateHash.of_battle`, Replay) und wird die Engine des Mini-Spiels: Wartenummern = Zugreihenfolge, Karte = Fähigkeit, Bearbeitungszeit = Rang | R | 1.12, 6 |
| SD-5 | Format | **1 gegen 1.** Ihr Duo ist **ein** Platz mit gemeinsamer Geduld; Graf Mopsula sitzt als **Beistand** daneben (Fußnoten, Tipps) und liefert Karten | D | 1.1 |
| SD-6 | Karten | Deck aus **20 Karten**, höchstens **2 gleiche** (Show-Karten 1), **Hand 5**, eine Karte je Zug, **sofort nachziehen**, leerer Stapel → Ablage neu mischen; Karten kosten **nur Zeit** | R · D | 2.1 |
| SD-7 | Zusatzzug | **Abheften** = Verteidigen der Engine (halber Ärger bis zum eigenen nächsten Zug, 2 Werktage) **plus 1 Karte tauschen** | D | 1.4 |
| SD-8 | Zufall | Nur beim **Mischen**, bei der **Startnummer**, bei **Show-Karten** (Prozentzahl steht auf der Karte) und in der gewichteten **Kartenwahl der Gegner**. Ärger, Heilung und alle Zeit-Effekte wirken **immer genau so**, wie es die Karte sagt | D | 1.2 |
| SD-9 | Gegner | Lernduell + **Ferdi Durchschlag** (Sachbearbeiter:in), **Ulla Umlauf** (Abteilungsleiter:in), **Der Stempelmeister** (Endgegner), **Graf Mopsula** (Übungsduell); ab SD3 **KI-Kandidat:innen** aus 09 | R · D | 3 |
| SD-10 | Präsentation | **2D-Kartentisch im TV-Look** (ShowOverlay, M.O.D. als Moderatorin); **keine** 3D-Kampfbühne — die günstigste Lösung, die gut aussieht (Begründung Kap. 4.1) | R · D | 4 |
| SD-11 | Belohnungen | **Konto:** Karten, Stempelheft, Kosmetik, Titel, Dienstauszeichnungen. **Staffel (nur Etage 8):** je Gegner **einmal** ein paar **Follower** (10/15/25) — Show-Währung wie eine Regie-Notiz, **keine Credits, keine Box** (Review). Nichts käuflich, eine Niederlage kostet nichts | R · D | 5 |
| SD-12 | Technik | Eigene Regelbuch-Daten (`res://data/stempel/`), eigener **`rules_hash`**, aufgezeichnete Züge, bitgenaues Replay; die Kampagne berührt das Duell nur über den Command **`sd`** (`start`/`end`) | R · D | 6 |
| SD-13 | Phasen | **SD1** Extraktion der Engine (statt Löschung, in 07 R5b) → **SD2** Mini-Spiel als Extras-Vorschau → **SD3** Etage 8 mit dem 09-Staffelinhalt | R | 7 |
| SD-14 | Gleiche Regeln | **Alle haben Tempo 10** (ein Werktag ist überall gleich lang), und **kein Gegner ist für die Engine ein `boss`** — keine versteckten Endgegner-Ausnahmen. Der Stempelmeister ist schwer durch Phasen, Durchsage und Feierabend-Eilvermerk (Review) | D | 3.4 |

### 0.4 Ein-Satz-Erklärung (UX-Vertrag, 06 L-1)

| System | Ein Satz (so sagt es M.O.D. beim ersten Mal, ≤ 110 Zeichen) | Erstes Auftreten |
|---|---|---|
| Stempelduell | „Stempelduell an Schalter 3! Lange Formulare, lange Wartezeit. Wer zuerst die Geduld verliert, verliert.“ | Titel → Extras (erstes Öffnen) bzw. erstes Wartezimmer auf Etage 8 |

Auf Etage 8 ist das Stempelduell **keine neue Regel** im Sinne von 09 Kap. 0.6, sondern ein Angebot „zum Entdecken“: ein
Schild, eine M.O.D.-Zeile, keine Tutorial-Karte in der Erkundung.

---

## 1. Spielregeln

### 1.1 Ablauf eines Duells

1. **Gegenüber wählen** (in der Schalterhalle eine Wartemarke ziehen, Kap. 4.7) und **Mappe wählen** (eines von drei
   gespeicherten Decks). Vor dem Duell zeigt die **Akte des Gegenübers** dessen Geduld, Zuständigkeiten und Eigenheiten.
2. **Beide mischen** ihr Deck aus 20 Karten und ziehen 5 Karten auf die Hand. Die Hand des Gegenübers liegt verdeckt; man
   sieht nur, wie viele Karten in Hand, Stapel und Ablage liegen.
3. **Nummern ziehen:** Der Wartemarken-Spender druckt die Startnummern (Kap. 1.9). Die Anzeige ruft die erste Nummer auf.
4. **Wer aufgerufen wird, ist dran:** eine Karte spielen (Kap. 1.3) oder abheften (Kap. 1.4). Die Wirkung tritt sofort ein;
   dann wird nachgezogen, und die Anzeige ruft die nächste Nummer auf.
5. Das geht so lange, bis eine Geduld auf 0 fällt, der **Dienstschluss** kommt oder jemand aufgibt (Kap. 1.8).
6. **Ergebnis:** großer Stempel „BEWILLIGT“ oder „ABGELEHNT“, Belohnungen (Kap. 5), Knöpfe „Revanche“, „Andere Mappe“,
   „Zurück“.

**Wer sitzt am Tisch?** Auf Ihrer Seite **ein** Platz für das Duo: Plakette „{Name} & der Graf“ (Name aus der Persona, nur
Anzeige; im Titel-Extras immer Kanon-Kai), **eine** Geduld-Leiste, **eine** Hand. Der Graf ist Beistand: Er kommentiert mit
Fußnoten, gibt auf Wunsch einen Tipp und steuert Karten bei (Kap. 2.3). Ob in der Kampagne Kai oder der Graf führt, ändert
nur die Reihenfolge der Namen auf der Plakette. Gegenüber sitzt immer **eine** Figur. Kein Zielen, keine Kombos, keine
zweite Einheit — jede Karte trifft das Gegenüber oder Sie selbst.

| Wert | Sie | Bedeutung |
|---|---|---|
| **Geduld** | 50 | Lebenspunkte. Fällt sie auf 0, ist das Duell verloren. |
| **Ärger** | — | Schaden. „9 Ärger“ = 9 Geduld weniger. |

Ein Werktag ist für alle gleich lang — es gibt keinen Tempo-Wert, den man kennen müsste (SD-14).

### 1.2 Wartenummern und Bearbeitungszeit

Jede Seite hat eine **Wartezeit** (in der Engine: `ctb_counter`, Ticks). Aufgerufen wird immer, wessen Wartezeit zuerst
abläuft. Wer gehandelt hat, bekommt eine neue Wartezeit:

```text
Wartezeit nach einer Karte = 50 Ticks × Werktage / 3 × Zustands-Faktor      (CTBQueue.delay_for, GDD §3.2; SPD 10 für alle)
```

| Bearbeitungszeit (Werktage = Rang) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Wartezeit (Ticks) | 17 | 33 | 50 | 67 | 83 | 100 |
| … mit **Eilvermerk** (× 0,6) | 10 | 20 | 30 | 40 | 50 | 60 |
| … mit **Dienst nach Vorschrift** (× 1,5) | 25 | 50 | 75 | 100 | 125 | 150 |

**Ticks sieht niemand.** Die Spieler:in sieht nur die Reihenfolge der nächsten Nummern (Kap. 4.3) und, sobald eine Karte
markiert ist, die **Vorschau**: Wo landet meine nächste Nummer, wenn ich diese Karte spiele? Die Vorschau ist ein Probelauf
auf einer Kopie (Kap. 6.5) und **sicher für alles, was feststeht**: wer als Nächstes dran ist, ob Ihre nächste Nummer vor
der nächsten des Gegenübers kommt und wo die Durchsage steht. Weiter hinten ist sie eine **Prognose**: Für Karten, die noch
niemand gespielt hat, rechnet sie wie die alte CTB-Leiste mit 3 Werktagen — die Anzeige kann sich nach dem nächsten Zug des
Gegenübers also noch verschieben. Show-Karten bekommen keinen Probelauf (er würde ihren Würfel verraten).

**Werktage sind relativ.** Hat das Gegenüber gerade eine Karte mit 3 Werktagen gespielt und Sie antworten mit einer
1-Werktag-Karte, sind Sie oft zweimal dran, bevor es wieder an der Reihe ist. Das ist der ganze Trick des Spiels.

### 1.3 Karten spielen, nachziehen, mischen

- **Eine Karte je Zug.** Jede Handkarte ist jederzeit spielbar — es gibt keine Kosten außer der Bearbeitungszeit. Ziele
  wählt niemand: Ärger trifft das Gegenüber, Heilung und Eilvermerke treffen Sie selbst.
- **Nachziehen:** Die gespielte Karte geht auf die **Ablage**, sofort danach wird eine Karte vom **Stapel** gezogen; die Hand
  hat also nach jedem Zug wieder 5 Karten.
- **Leerer Stapel:** Die Ablage wird gemischt und ist der neue Stapel („Die Ablage wird neu sortiert“). Ein Duell geht nie
  wegen fehlender Karten zu Ende.
- **Umlaufmappe** (Karte 8) ist die einzige Karte, die die Hand selbst verändert: ganze Hand auf die Ablage, 5 neue ziehen.
- Für das Gegenüber gelten **dieselben Regeln** (20 Karten, Hand 5, nachziehen, mischen). Das Amt mogelt nicht. Einzige
  Ausnahme: Es spielt keine Show-Karten (Kap. 1.7).

### 1.4 Abheften

Statt einer Karte darf man **abheften** — Knopf „Abheften“ oder eine Karte auf die Ablage ziehen:

1. Eine Handkarte wählen; sie geht auf die Ablage, eine neue wird gezogen.
2. **Bis zu Ihrem nächsten Zug nehmen Sie nur halben Ärger** (gerundet; die Anzeige zeigt immer die echte Zahl).
3. Die Bearbeitungszeit ist **2 Werktage** — Sie sind also schnell wieder dran.

Abheften ist das Werkzeug gegen eine schlechte Hand, gegen eine angekündigte **Durchsage** (Kap. 3.4) und für das Gefühl
„jetzt erst mal tief durchatmen“. In der Engine ist es der Befehl `DEFEND` (Rang 2, Schaden × 0,5, GDD §3.5); der
Kartentausch ist die einzige Zutat des Mini-Spiels. Auch das Gegenüber heftet ab — immer dann, wenn ihm keine Karte passt
(Kap. 3.6).

### 1.5 Formular-Arten und Zuständigkeiten

Jede Karte hat eine **Formular-Art** (Farbe, Symbol und Name auf der Karte):

| Formular-Art | Farbe / Symbol | Engine-Element | Beispiel |
|---|---|---|---|
| **Stempel** | Grau, Stempel | `physical` | Formular 27b, Wuchtschlag |
| **Eilt** | Rot, Flamme | `fire` | Adelsflamme |
| **Eiskalt** | Blau, Schneeflocke | `ice` | Ablehnungsbescheid, Frostniesen |
| **Rohrpost** | Gelb, Kapsel mit Blitz | `shock` | Kabelpeitsche, Bellen in Stereo |
| **Papierkram** | Grün, Lupe | `poison` | Kleingedrucktes |
| **Verwaltung** | Weiß, Ordner | `none` | Heilung, Eilvermerk, Wiedervorlage — nie verstärkt oder geschwächt |

Gegner haben **Zuständigkeiten** (in der Engine `element_mods`), die auf ihrer Plakette stehen, bevor man die Mappe wählt:

| Zuständigkeit | Faktor | Popup | Sinn |
|---|---|---|---|
| **Wunder Punkt** | × 1,5 | „WUNDER PUNKT!“ (gelb) | Diese Art trifft besonders. |
| **Nicht zuständig** | × 0,5 | „NICHT ZUSTÄNDIG“ (grau) | Diese Art prallt halb ab. |

Sie selbst haben keine Zuständigkeiten. Die Karte rechnet beim Markieren die echte Zahl aus („14 statt 9 · Wunder Punkt“) —
niemand muss multiplizieren.

### 1.6 Vier Zustände

Die Engine kennt sechs Zustände (GDD §3.9); das Duell nutzt vier davon, alle mit **100 % Wirkung** (keine Würfel). „Gepanzert“
und „Provoziert“ entfallen: Gepanzert wirkt nicht gegen festen Ärger, Provoziert ist 1 gegen 1 sinnlos.

| Zustand | Engine | Wirkung (so steht es auf der Karte) | Farbe / Symbol |
|---|---|---|---|
| **Wiedervorlage** | `sts_sd_wiedervorlage` (wie `stun`, Flag `delay_on_apply`) | Die nächste Nummer des Gegenübers rutscht **3 Werktage** nach hinten. Endet bei seiner nächsten Nummer. **Nicht doppelt:** Liegt schon eine vor, zeigt die markierte Karte „keine Wirkung“. | Gelb, Uhr mit Pfeil |
| **Dienst nach Vorschrift** | `sts_sd_vorschrift` (wie `slow`, × 1,5, 3 Züge) | Die **nächsten 2 Nummern** des Gegenübers dauern 50 % länger. | Blau, Schnecke |
| **Eilvermerk** | `sts_sd_eilvermerk` (wie `haste`, × 0,6) | **Diese und Ihre nächste(n) Karte(n)** sind 40 % schneller bearbeitet (Anzahl steht auf der Karte). | Orange, rotes Ausrufezeichen-Siegel |
| **Kleingedrucktes** | `sts_sd_kleingedrucktes` (wie `poison`, `tick_timing turn_start`, `tick_pct −1` + `tick_min 2` = immer 2, 3 Züge) | Zu Beginn seiner **nächsten 3 Züge** verliert das Gegenüber je **2 Geduld** — eine feste Zahl statt Prozent, niemand muss rechnen. | Grün, Lupe |

Eilvermerk und Dienst nach Vorschrift heben sich auf (`excludes`, wie Turbo/Verlangsamt). Ein neuer gleicher Zustand setzt
die Dauer zurück und stapelt nicht. Die Texte nennen bewusst **Nummern** statt „Züge“: Ein Zustand, den man sich in der
eigenen Runde selbst gibt, wirkt schon auf diese Karte (`fresh`, GDD §3.3); einer, den das Gegenüber bekommt, erst ab seiner
nächsten — so stimmt der Kartentext mit der Engine exakt überein.

### 1.7 Show-Karten

Show-Karten (goldener Rahmen) sind die Stunts des alten Kampfs: **großer Ärger mit sichtbarer Erfolgschance**, bei einem
**Patzer** eine gedruckte Peinlichkeit (Kap. 2.3, Karten 13 und 18). Regeln:

- Die Prozentzahl steht auf der Karte und ist die echte Chance (`BattleState.stunt_chance`; ohne Engine-`boss` gibt es keinen
  Abzug, SD-14) — gegen jeden Gegner dieselbe Zahl.
- Je Deck nur **ein** Exemplar jeder Show-Karte; keine Abklingzeit (`cooldown 0`).
- **Nur Kandidat:innen spielen Show-Karten.** In der Engine gibt es `STUNT` nur für die Party (`available_commands`); im
  Spiel heißt das: „Das Amt hat keinen Sinn für Show.“ Gegnerdecks enthalten keine Show-Karten.
- Show-Karten sind der einzige Würfel, den man selbst auslöst — und das einzige, was M.O.D. wirklich begeistert.

### 1.8 Sieg, Niederlage, Dienstschluss, Aufgeben

| Ende | Bedingung | Ergebnis |
|---|---|---|
| **Bewilligt** (Sieg) | Geduld des Gegenübers 0 | Belohnungen nach Kap. 5 |
| **Abgelehnt** (Niederlage) | Ihre Geduld 0 | nichts verloren; „Revanche“ steht schon im Fokus |
| **Dienstschluss** | Nummer **80** ist aufgerufen (beide zusammen, auch die Durchsage zieht Nummern) | **Vertagt** — unentschieden, keine Belohnung, nichts verloren. Ab Nummer 60 zeigt die Anzeige „Dienstschluss bei Nummer 80“. Sicherheitsnetz gegen Endlos-Duelle; kein Prozentvergleich, damit sich Mauern mit Heilkarten nie lohnt. Prototyp: 0 % der Duelle; Harness < 1 % **[zu messen]** |
| **Aufgegeben** | Menü → „Antrag zurückziehen“ (mit Bestätigung) | zählt als Niederlage, kostet nichts |

Beide Geduld-Werte können nicht gleichzeitig auf 0 fallen: Patzer kosten nie die letzte Geduld (Engine: Selbstschaden nie
tödlich), Kleingedrucktes tickt nur am Zugbeginn des Trägers, die Durchsage trifft nur Sie.

### 1.9 Gleichstand und erste Nummer

- **Gleichstand:** Laufen zwei Wartezeiten gleichzeitig ab, gilt die Reihenfolge der Engine (GDD §3.3): **Sie vor dem
  Gegenüber vor der Durchsage.** Im Spiel heißt die Regel **„Bei Gleichstand geht die Kundschaft vor“** — sie steht in der
  Hilfe und als Fußnote des Grafen, und die Anzeige zeigt sie ohnehin richtig an. Weil alle Tempo 10 haben, kommt das oft
  vor; das ist ein bewusster kleiner Vorteil für die Kandidat:in, den Geduld und Spielweise der Gegner ausgleichen
  (Harness-Band Kap. 6.9; im Prototyp ≤ 4 Punkte Unterschied mit und ohne erste Nummer).
- **Erste Nummer:** Beide Startwartezeiten würfelt die Engine zwischen 50 und 100 % von 3 Werktagen
  (`CTBQueue.setup`, Start „normal“, Strom `ctb`). Im **Lernduell** sind Sie zuerst dran (Start „Präventivschlag“: Sie 0,
  Gegner 3 Werktage). Präsentiert wird das als **„Nummern ziehen“**: Der Wartemarken-Spender druckt zwei Zettel, der
  kleinere wird zuerst aufgerufen. (Nicht „Nummernautomat“ — so heißt der Etagenboss von Etage 9, 09 Kap. 3.1.)

### 1.10 Das Lernduell (erstes Duell = Tutorial)

Beim ersten Öffnen startet das Stempelduell direkt mit dem **Lernduell gegen Ferdi Durchschlag** (überspringbar: „Ich kenne
mich aus“). Technisch ein normales Duell mit drei Besonderheiten: `BattleSetup.tutorial = true` und
`enemy_dmg_mult = 0,5` (Ihre Geduld fällt nie unter 1, Ferdis Ärger halbiert — man kann nicht verlieren), feste
Kartenreihenfolge statt Mischen, und Ferdis Spielweise ist ein **Drehbuch** aus `turn_mod`-Bedingungen der Engine
(GDD §3.11), sodass jede Lektion zur richtigen Nummer kommt. Jede Lektion ist eine kleine Hinweiskarte; das Duell wartet,
bis sie weggetippt ist (keine Uhr läuft). Die Texte unten sind die Touch-Fassung; mit Tastatur oder Gamepad nennen sie die
passenden Tasten (`input_glyph.gd`).

| Schritt | Lektion | Was passiert |
|---|---|---|
| 1 | Karte spielen | „Ihre Hand: fünf Karten. Tippen Sie den Stempel an — und noch einmal zum Spielen.“ Nur der Stempel ist hervorgehoben. |
| 2 | Wartenummern | „Kurze Karte: Sie sind gleich wieder dran.“ Die Anzeige zeigt zweimal hintereinander SIE. Fußnote 1 des Grafen. |
| 3 | Bearbeitungszeit | Formular 27b markieren → die eigene nächste Nummer rutscht sichtbar nach hinten (Geist-Zettel). Spielen. |
| 4 | Wiedervorlage | Ferdi spielt eine Wiedervorlage auf Sie. „Fußnote 3: Ihre Nummer rutscht. Ärgerlich, aber rechtmäßig.“ |
| 5 | Abheften | M.O.D. (das Drehbuch kennt Ferdis nächste Karte): „Ferdi hält einen Ablehnungsbescheid bereit!“ — Abheften halbiert den Ärger; man tauscht dabei eine Karte. |
| 6 | Wunder Punkt | Die Hand hält die Adelsflamme, Ferdis Plakette zeigt „Wunder Punkt: Eilt“. „Fußnote 4: Papier mag kein Feuer.“ Sieg. |

Dauer ≈ 3 Minuten **[zu messen]**. Danach: Grundakte und Startmappe (Kap. 2.4), M.O.D. erklärt die Schalterhalle in einem
Satz. „Lernduell wiederholen“ steht unter „Regeln“.

### 1.11 Hilfen (ändern nie das Ergebnis der Engine)

| Hilfe | Wirkung | Standard |
|---|---|---|
| **Tipps des Grafen** | die empfohlene Karte trägt eine kleine Pfote; der Pfoten-Knopf (Touch) bzw. die Großansicht sagt in einer Fußnote, warum („Kurz und schmerzhaft: Doppelstempel. Danach sind Sie vor Ferdi dran.“) | an |
| **Der Graf übernimmt** (Auto) | spielt Ihre Züge mit derselben Empfehlung, bis Sie wieder tippen | aus |
| **Gegnerhand offen** | zeigt die Hand des Gegenübers (Lernhilfe) | im Übungsduell gegen den Grafen an, sonst aus |
| **Tempo × 2** | halbiert alle Animationszeiten | aus |
| **Animationen reduzieren** | kein Wackeln, keine fliegenden Karten (Überblendungen) | aus, folgt der Systemeinstellung |

Hilfen sind reine Anzeige bzw. erzeugen normale Züge; Siege mit Hilfen zählen voll — es gibt keine Bestenliste, die man
schützen müsste.

### 1.12 Was davon die CTB-Engine ist

| Stempelduell | CTB-Engine (unverändert) | Anmerkung |
|---|---|---|
| Geduld | HP (`Combatant.hp`, `stats.hp`) | |
| Ärger | Fixschaden (`damage_type "fixed"`, `power`, `hits`) | keine Varianz, kein Krit → jede Zahl ist exakt |
| Heilung | `damage_type "heal"`, `heal_mode "fixed"` bzw. `"pct"` | |
| Werktag | SPD 10 für alle → `CTBQueue.base_delay` 50 Ticks = 3 Werktage | kein Tempo-Wert für Spieler:innen (SD-14) |
| Bearbeitungszeit 1–6 Werktage | `SkillDef.rank` 1–6 | Rang 1 (× 0,33) ist im Slice ungenutzt, die Formel kann ihn |
| Wartenummern-Anzeige | `BattleState.preview_order` / Event `CTB_ORDER` | 12 berechnet, 10 (Touch 8) gezeigt; spätere Aktionen mit Rang 3 (Prognose) |
| Karte spielen | `BattleCommand.skill` (Show-Karte: `stunt`) | die **Hand ist die Fähigkeitenliste** (`Combatant.skills`/`stunts`, Kap. 6.5) |
| Abheften | `BattleCommand.defend` + Kartentausch | |
| Formular-Art / Zuständigkeit | Element / `element_mods` | |
| Vier Zustände | `stun`/`slow`/`haste`/`poison`-Mechanik mit eigenen Datenzeilen | `statuses.json` des Regelbuchs |
| Show-Karte, Patzer | Stunt mit `success_base`, `fail_effect`, `cooldown 0` | nur Party-Seite |
| Durchsage | Pseudo-Einheit (`pseudo_units`, `fixed_pct_maxhp`, `ctr_after`, `warn_at`) | wie der Zug der Rattenkönigin |
| Phasen des Stempelmeisters | `phases[]` mit `on_enter` (`say`, `status_self`, `add_pseudo`) | |
| Spielweise der Gegner | `ai` (gewichtet, Bedingungen) → `EnemyAI.choose` | die Hand filtert, weil `EnemyAI` nur benutzbare Fähigkeiten wählt |
| Auto für die Spieler:in | `AutoPolicy` (Harness „einfach“) bzw. `SdAi.suggest` (Tipp, Auto) | Kap. 3.6 |
| Lernduell | `BattleSetup.tutorial`, Start `PREEMPTIVE` | |
| Gleichstand | Tie-Break Party → Gegner → Pseudo | „Kundschaft geht vor“ |

**Nicht genutzt:** `ATTACK` (spielbar gibt es keinen Grundangriff; die Engine-Daten tragen nur einen formalen, Kap. 6.4 —
wählt die KI ihn als Notlösung, wird daraus Abheften), `ITEM`
(Gegenstände sind Karten), `FLEE` (Aufgeben ist ein Menüpunkt), Sponsor-Geschenke (`apply_gift`), EXP, Credits und Beute
der Engine, Kombos (nur eine Einheit je Seite), Beschwörungen, das Engine-Flag `boss` (Wiedervorlage halb, Show-Abzug —
SD-14).

---

## 2. Karten & Deck

### 2.1 Deckregeln

| Regel | Wert |
|---|---|
| Deckgröße | genau **20** Karten |
| Gleiche Karten | höchstens **2**; Show-Karten höchstens **1** |
| Besitz | Wer eine Karte besitzt, darf sie bis zum Höchstwert ins Deck legen — es gibt **keine Exemplare** zu sammeln |
| Hand | **5**; nach jedem Zug sofort auf 5 nachgezogen |
| Mappen | **3** gespeicherte Decks („Mappe A/B/C“), eine ist aktiv; „Automatisch füllen“ baut aus dem Besitz ein spielbares Deck |
| Gegnerdecks | dieselben Regeln, fest in den Daten, keine Show-Karten |

Ein Deck, das die Regeln verletzt, kann man nicht wählen; der Aktenschrank sagt in einem Satz, warum („Noch 3 Karten bis 20.“,
„Höchstens 2 × Doppelstempel.“).

### 2.2 Aufbau einer Karte

```text
 ┌──────────────────────────────┐   Rahmen: Farbe der Formular-Art; Show-Karten Goldrahmen
 │ Formular 27b      [Uhr]  3   │   Name (18 px fett) · Bearbeitungszeit: gezeichnete Sanduhr + Zahl (Werktage)
 │ STEMPEL · Formular-Nr. 027   │   Formular-Art (Symbol + Wort) · kleine Formularnummer (Deko, Monospace)
 │                              │
 │            9 ÄRGER           │   Hauptwirkung groß (30 px); markiert: „14 statt 9 · WUNDER PUNKT“
 │                              │
 │ Bitte in dreifacher Ausfer-  │   Spruch (16 px, gedimmt; auf Touch nur in der Großansicht)
 │ tigung. Die dritte schreddern│
 │ wir sofort.                  │
 │ [Amt]                        │   Herkunft: Amt · Kandidat:in · Graf · Gegenstand · Talent · Trophäe
 └──────────────────────────────┘
```

Alle Symbole sind gezeichnet (03_ART F8: keine Schrift-Glyphen wie Sanduhr-Emoji oder →; die Zeichen oben sind nur
Skizze). Größe auf dem Tisch 150 × 210 px (720p), auf Touch 170 × 236 px; langes Drücken, Tab oder Select zeigt die Karte
doppelt so groß. **Auf dem Telefon** sind 720 px Höhe nur gut 6 cm: 15 px wären dort ≈ 8 pt. Deshalb zeigt die Touch-Karte nur
Name (20 px), Werktage und Hauptwirkung (34 px); Spruch, Formularnummer und Volltext stehen in der Großansicht. Die Option
„Schriftgröße“ (Kap. 4.8) vergrößert alles weiter.

### 2.3 Kartenliste (24 Karten, Startwerte)

WT = Werktage (Rang). „Diese und n Karten“ = Eilvermerk für die gespielte Karte und Ihre n nächsten (Kap. 1.6).

| Nr. | ID | Karte | Herkunft | Art | WT | Wirkung | Spruch |
|---|---|---|---|---|---|---|---|
| 1 | `sdc_stempel` | Stempel | Amt | Stempel | 1 | 2 Ärger | „Rums. Gilt als zugestellt.“ |
| 2 | `sdc_doppelstempel` | Doppelstempel | Amt | Stempel | 2 | 2 × 3 Ärger | „Doppelt hält besser. Dreifach wäre Verschwendung.“ |
| 3 | `sdc_formular_27b` | Formular 27b | Amt | Stempel | 3 | 9 Ärger | „Bitte in dreifacher Ausfertigung. Die dritte schreddern wir sofort.“ |
| 4 | `sdc_ablehnung` | Ablehnungsbescheid | Amt | Eiskalt | 3 | 9 Ärger | „Leider nein. Mit freundlichen Grüßen, ohne Freude.“ |
| 5 | `sdc_wiedervorlage` | Wiedervorlage | Amt | Verwaltung | 2 | Wiedervorlage beim Gegenüber (+3 WT, nicht doppelt) | „Bitte noch einmal vorlegen. Persönlich. Mit Termin.“ |
| 6 | `sdc_kleingedrucktes` | Kleingedrucktes | Amt | Papierkram | 2 | 2 Ärger + Kleingedrucktes (3 Züge je 2 Ärger) | „Steht alles drin. Seite 214, hellgrau auf weiß.“ |
| 7 | `sdc_durchatmen` | Tief durchatmen | Amt | Verwaltung | 2 | +8 Geduld | „Ein. Aus. Nicht in die Wartemarke pusten.“ |
| 8 | `sdc_umlaufmappe` | Umlaufmappe | Amt | Verwaltung | 1 | ganze Hand ablegen, 5 neue ziehen | „Alles einmal im Kreis. Vielleicht kommt was Besseres zurück.“ |
| 9 | `sdc_wuchtschlag` | Wuchtschlag | Kandidat:in | Stempel | 4 | 13 Ärger | „Mit voller Wucht. Und schlechter Haltung.“ |
| 10 | `sdc_leinen` | Leinen-Fallstrick | Kandidat:in | Stempel | 3 | 3 Ärger + Dienst nach Vorschrift | „Bremst aus. Diesmal mit Dienstanweisung.“ |
| 11 | `sdc_erste_hilfe` | Erste Hilfe | Kandidat:in | Verwaltung | 2 | +10 Geduld, entfernt Kleingedrucktes | „Pflaster drauf, Puste drüber, weiter im Text.“ |
| 12 | `sdc_kabelpeitsche` | Kabelpeitsche | Kandidat:in | Rohrpost | 4 | 6 Ärger + Wiedervorlage | „Starkstrom am Schalter. Bitte Abstand halten.“ |
| 13 | `sdc_suplex` | Bahnsteig-Suplex | Kandidat:in · **Show** | Stempel | 4 | **60 %:** 26 Ärger · **Patzer:** −10 % eigene Geduld, nächste Nummer +2 WT | „Live, ungeprobt, ungepolstert.“ |
| 14 | `sdc_adelsflamme` | Adelsflamme | Graf | Eilt | 3 | 10 Ärger | „Flamma nobilis! Fußnote 1: Brandschutzordnung beachten.“ |
| 15 | `sdc_schlabbern` | Heiliges Schlabbern | Graf | Verwaltung | 3 | +12 Geduld | „Eine Ehre, die keiner wollte.“ |
| 16 | `sdc_frostniesen` | Frostniesen | Graf | Eiskalt | 2 | 6 Ärger | „Hatschi! Gesundheit gibt es an Schalter 5.“ |
| 17 | `sdc_gutachten` | Gräfliches Gutachten | Graf | Verwaltung | 2 | Eilvermerk: diese und 2 Karten | „Tempus fugit! Laut Gutachten sind Sie zu langsam.“ |
| 18 | `sdc_auftritt` | Auftritt um Mitternacht | Graf · **Show** | Eilt | 4 | **55 %:** 24 Ärger · **Patzer:** Wiedervorlage für Sie selbst | „Umhang, Nebel, Pathos — und ein Teppichrand, den keiner gesehen hat.“ |
| 19 | `sdc_werbepflaster` | Werbepflaster | Gegenstand | Verwaltung | 1 | +5 Geduld | „Heilt 5 Geduld. Zeigt dabei drei Werbespots.“ |
| 20 | `sdc_gegengift` | Gegengift-Gurgler | Gegenstand | Verwaltung | 1 | entfernt Kleingedrucktes, +3 Geduld | „Gurgeln, schlucken, unterschreiben.“ |
| 21 | `sdc_kaeltespray` | Kältespray | Gegenstand | Eiskalt | 1 | 2 Ärger | „Kurz, kalt, quittiert.“ |
| 22 | `sdc_kaffee` | Automatenkaffee | Talent (Kandidat:in) | Verwaltung | 1 | +3 Geduld, Eilvermerk: diese und 1 Karte | „Schmeckt nach Pappe. Wirkt nach Turbo.“ |
| 23 | `sdc_stereo` | Bellen in Stereo | Talent (Graf) | Rohrpost | 2 | 2 × 3 Ärger | „WUFF links, WUFF rechts. Fußnote 8: zählt doppelt.“ |
| 24 | `sdc_amtsstempel` | Großer Amtsstempel | Trophäe (Stempelmeister) | Stempel | 6 | 22 Ärger | „Wiegt drei Kilo. Die Verantwortung mehr.“ |

**Wie die Zahlen gedacht sind:** Normaler Ärger liegt bei **≈ 3 je Werktag** (Stempel und Kältespray 2/WT als schnelle
Füllkarten — gleich stark, nur die Formular-Art entscheidet; Wuchtschlag 3,25, Großer Amtsstempel 3,7 als langsamer
Abschluss). Längere Karten sind etwas effizienter, kurze geben Tempo und Reaktionsmöglichkeit. Zeit-Karten werden in Werktagen
bewertet, 1 WT des Gegenübers ≈ 3 Ärger. Die Erwartungswerte (Review 2026-10-11, „netto“ = Gewinn gegenüber einer schlichten
3-Ärger-je-WT-Karte gleicher Dauer):

| Gruppe | Karten (netto je Einsatz) | Lesart |
|---|---|---|
| reiner Ärger | Stempel, Kältespray −1 · Doppelstempel, 27b, Ablehnung, Frostniesen, Bellen 0 · Wuchtschlag, Adelsflamme +1 · Großer Amtsstempel +4 | die Trophäe ist die beste Ärger-Karte, aber 6 WT lang (das Gegenüber ist dazwischen meist zweimal dran) |
| Zeit | Wiedervorlage +3 (2 WT gegen 3 WT Verzug) · Leinen-Fallstrick +3 · Kabelpeitsche +3 (gegen Ulla −6: immun) · Gutachten +3,6 · Automatenkaffee +4,8 · Umlaufmappe −3 + bessere Hand | Eilvermerke gehören zu den stärksten Karten — sie stapeln nicht, und Dienst nach Vorschrift hebt sie auf |
| Kleingedrucktes | +2 (2 + 3 × 2 Ärger, verzögert, heilbar) | fest statt 6 %: mit Prozent waren es gegen 72 Geduld +8 |
| Heilung | Gegengift 0 (+ bis 6 durch das Gegenmittel) · Werbepflaster, Tief durchatmen +2 · Schlabbern +3 · Erste Hilfe +4 (+ Gegenmittel) | effizienter als Ärger, zählt aber nur, wenn Geduld fehlt; Mauern lohnt nicht (Dienstschluss = vertagt) |
| Show | Suplex −0,8 (60 % × 26 = 15,6 roh) · Auftritt −2,8 (55 % × 24 = 13,2 roh; gegen Ferdi 36 = alles) | etwas schlechterer Erwartungswert, größter Ausschlag — wie gewollt |

Erste Hilfe ist eine bewusste Verbesserung von Tief durchatmen; sonst ist keine Karte anderen strikt überlegen. Der Harness
stellt alles nach (Kap. 6.9).

**Herkunft und Abstand:** Die Karten 9–23 sind Parodien der Fähigkeiten, Gegenstände und Talente des Duos (IDs in Kap. 2.5);
Namen und Sprüche sind eigene Texte. Spielertexte nennen die Kandidat:in nie „Kai“ oder „Tierpfleger:in“, damit jede Persona
passt (08 K1). Mopsula-Karten: Ich-Form, Fußnoten, Pseudolatein, keine Königs-, Kronen- oder „Blaues Blut“-Motive (06 §0.3,
`validators/ip_words.gd` prüft das auch hier).

### 2.4 Grundakte und Startmappe

Nach dem Lernduell besitzt man die **Grundakte** — 12 Karten: die acht Amt-Karten (1–8), Werbepflaster (19), Kältespray (21)
und die ersten Fähigkeiten des Duos, **Wuchtschlag** (9) und **Adelsflamme** (14). Daraus ist die **Startmappe** gebaut:

| Karte | Anzahl | | Karte | Anzahl |
|---|---|---|---|---|
| Stempel | 2 | | Kleingedrucktes | 2 |
| Doppelstempel | 2 | | Tief durchatmen | 2 |
| Formular 27b | 2 | | Umlaufmappe | 1 |
| Ablehnungsbescheid | 2 | | Werbepflaster | 2 |
| Wiedervorlage | 2 | | Kältespray | 1 |
| Wuchtschlag | 1 | | Adelsflamme | 1 |

Summe 20. Die Startmappe gewinnt gegen Ferdi und den Grafen sicher und gegen Ulla manchmal; wer Ulla regelmäßig schlagen
will, baut um (sie ist für Stempel nicht zuständig) — das ist die erste Deckbau-Lektion, ganz ohne Tutorial. Gegen den
Stempelmeister gewinnt die Startmappe fast nie: Er ist die Deckbau-Prüfung (Bänder Kap. 6.9).

### 2.5 Woher Karten kommen

Drei Quellen, **alle sichtbar und ohne Zufall** (keine Kartenpackungen, keine Seltenheitswürfel):

1. **Gegner:** Der erste Sieg gegen jedes Gegenüber bringt feste Karten (die Akte zeigt vorher, welche): Ferdi →
   Gegengift-Gurgler (20), Heiliges Schlabbern (15); Graf → Gräfliches Gutachten (17), Bellen in Stereo (23); Ulla →
   Leinen-Fallstrick (10), Kabelpeitsche (12); Stempelmeister → Großer Amtsstempel (24).
2. **Stempelheft:** Jeder Sieg stempelt ein Feld im Stempelheft; **je 3 Stempel** gibt es die nächste Karte aus einer festen,
   sichtbaren Reihenfolge — Frostniesen (16) → Erste Hilfe (11) → Automatenkaffee (22) → Bahnsteig-Suplex (13) → Auftritt um
   Mitternacht (18) — danach Kosmetik (Kap. 5.2). Bereits besessene Karten werden übersprungen.
3. **Kampagne („Karriere“):** Beim Öffnen des Stempelduells liest das Spiel aus allen Speicherplätzen nur IDs — gelernte
   Fähigkeiten, je besessene Gegenstände, gewählte Talente — und schaltet passende Karten **dauerhaft** frei:

| Karte | Quelle (ID) | | Karte | Quelle (ID) |
|---|---|---|---|---|
| Wuchtschlag | `skl_kai_heavy_swing` | | Adelsflamme | `skl_mop_noble_flame` |
| Leinen-Fallstrick | `skl_kai_leash_trip` | | Heiliges Schlabbern | `skl_mop_holy_lick` |
| Erste Hilfe | `skl_kai_first_aid` | | Frostniesen | `skl_mop_frost_sneeze` |
| Kabelpeitsche | `skl_kai_cable_whip` | | Gräfliches Gutachten | `skl_mop_expert_opinion` |
| Bahnsteig-Suplex | `skl_stunt_kai_suplex` | | Auftritt um Mitternacht | `skl_stunt_mop_entrance` |
| Gegengift-Gurgler | `itm_antidote` | | Automatenkaffee | `tal_kai_kaffee` |
| Werbepflaster, Kältespray | `itm_bandage`, `itm_ice_spray` (ohnehin Grundakte) | | Bellen in Stereo | `tal_mop_stereo` |

Wer nie Kampagne spielt, bekommt jede Karte über Gegner und Stempelheft: alle 24 nach **≈ 15–20 gewonnenen Duellen**
(≈ 1 Stunde) **[zu messen]**. Wer Kampagne spielt, hat sie schneller. Die Richtung ist eine Einbahnstraße: **Kampagne → Mini-
Spiel, nie zurück** (Kap. 5.1). Die Freischaltung über Fähigkeiten folgt den IDs, nicht der Leiste — nach 07 R5b und 09
(Fähigkeitenbuch, Klassen) bleibt die Abfrage „hat die Figur diese Fähigkeit freigeschaltet“ gleich.

### 2.6 Aktenschrank (Deckbau)

- **Links** der Besitz als Raster (Filter: Formular-Art, Herkunft, Werktage), **rechts** die Mappe (20 Plätze, Zähler,
  **Bearbeitungszeit-Kurve** als kleines Säulendiagramm 1–6 WT — so sieht man, ob die Mappe zu langsam ist).
- Antippen/A fügt hinzu, in der Mappe antippen/X entfernt, langes Drücken/Y vergrößert.
- **„Automatisch füllen“** ergänzt bis 20 nach einer festen Regel (erst fehlende Grundakte, dann nach Ärger je Werktag, je
  Art höchstens 6 Karten, Heilung mindestens 3) — es gibt nie ein unspielbares Deck.
- **„Passend zur Akte“**: Vor einem Duell schlägt der Graf eine Änderung vor („Fußnote 6: Ulla ist für Stempel nicht
  zuständig. Zwei Ablehnungsbescheide mehr?“) — ein Knopf übernimmt sie in eine Kopie der Mappe.
- Ohne Bestätigung wird nichts überschrieben; jede Änderung speichert sofort (Kap. 6.7).

### 2.7 Datenformat (Beispiele)

`res://data/stempel/cards.json` (Präfix `sdc_`) — Anzeige- und Freischaltfelder plus ein `skill`-Block mit den Feldern von
`SkillDef` (02_TECH §4.4.2) in **CTB-Bedeutung**; das Regelbuch macht daraus `skl_sdc_<name>` (Kap. 6.4):

```json
{"id": "sdc_wiedervorlage", "name": "Wiedervorlage", "art": "verwaltung", "origin": "amt", "max_copies": 2,
 "text": "Die nächste Nummer des Gegenübers rutscht 3 Werktage nach hinten. Nicht doppelt.",
 "quip": "Bitte noch einmal vorlegen. Persönlich. Mit Termin.", "unlock": {"kind": "grundakte"},
 "skill": {"category": "debuff", "target": "single_enemy", "damage_type": "none", "element": "none", "power": 0,
           "rank": 2, "statuses": [{"id": "sts_sd_wiedervorlage", "chance": 1.0}]}}
```

```json
{"id": "sdc_suplex", "name": "Bahnsteig-Suplex", "art": "stempel", "origin": "kandidat", "max_copies": 1, "show": true,
 "text": "60 %: 26 Ärger. Patzer: Sie verlieren 10 % Geduld, Ihre nächste Nummer kommt 2 Werktage später.",
 "quip": "Live, ungeprobt, ungepolstert.", "unlock": {"kind": "skill", "id": "skl_stunt_kai_suplex"},
 "skill": {"category": "stunt", "target": "single_enemy", "damage_type": "fixed", "element": "physical", "power": 26,
           "rank": 4, "success_base": 0.60, "success_lck": 0.0, "success_cap": 0.85,
           "fail_effect": {"self_dmg_pct": 10, "delay_pct": 66}, "cooldown": 0}}
```

Show-Karten setzen `cooldown` **ausdrücklich auf 0** — ohne Angabe ergänzt der Validator 3 (Stunt-Standard, 02_TECH §4.4.2).
`success_lck 0` macht die Chance unabhängig vom Glück (das Duell hat keine LCK-Werte); `delay_pct 66` sind bei Tempo 10
genau 2 Werktage (33 Ticks).

`res://data/stempel/opponents.json` (Präfix `sdo_`) — Werte, Zuständigkeiten, Deck, Spielweise im `ai`-Format der Engine,
Belohnungen:

```json
{"id": "sdo_ferdi", "name": "Ferdi Durchschlag", "short": "FERDI", "role": "Sachbearbeitung · Schalter 3", "geduld": 36,
 "element_mods": {"fire": 1.5}, "status_immune": [], "symbol": "golem_paper",
 "deck": {"sdc_stempel": 2, "sdc_doppelstempel": 2, "sdc_formular_27b": 2, "sdc_ablehnung": 2, "sdc_kaeltespray": 2,
          "sdc_wiedervorlage": 2, "sdc_durchatmen": 2, "sdc_werbepflaster": 2, "sdc_umlaufmappe": 2, "sdc_gegengift": 2},
 "ai": {"type": "weighted", "actions": [
   {"skill": "skl_sdc_durchatmen", "weight": 6, "target": "self", "cond": {"self_hp_below": 0.5}},
   {"skill": "skl_sdc_wiedervorlage", "weight": 3, "target": "random"},
   {"skill": "skl_sdc_formular_27b", "weight": 2, "target": "random"}]},
 "first_win": {"cards": ["sdc_gegengift", "sdc_schlabbern"], "cosmetic": "sdk_ink_kopierblau"},
 "season_win": {"followers": 10}, "unlock_after": "", "lines": "ferdi"}
```

Das Beispiel kürzt `ai.actions` auf drei Einträge; im echten Datensatz hat **jede Karte des Gegnerdecks mindestens einen
Eintrag** (der Validator prüft das) — sonst spielte der Gegner sie nie und heftete ständig ab. Die Gewichte sind der Charakter
des Gegenübers, die Bedingungen (`self_hp_below`, `turn_mod` …) seine kleinen Pläne.

Weitere Dateien: `rules.json` (Konstanten, die vier Zustände `sts_sd_*`, die Pseudo-Einheit `pu_sd_durchsage`, das
Drehbuch des Lernduells), `lines.json` (M.O.D.-, Grafen- und Chat-Zeilen mit Tags `sd_*`, Kap. 4.5), `cosmetics.json`
(Präfix `sdk_`: Kartenrücken, Stempelfarben, Tischunterlagen, Titel), `awards.json` (Präfix `sda_`: Dienstauszeichnungen).

---

## 3. Gegner & Kampagne im Amt

### 3.1 Übersicht

Alle Gegner sind **Geschöpfe der Kulisse** „Amt für Etagenwesen“ (09 Kap. 3.1: Wartemarken, Formular-Golems, Stempel) —
keine Karikaturen echter Menschen. Jede:r bringt **genau eine neue Regel** mit.

| Gegner | Rolle | Geduld | Wunder Punkt (× 1,5) | Nicht zuständig (× 0,5) | Neue Regel | Frei ab |
|---|---|---|---|---|---|---|
| **Ferdi Durchschlag** | Sachbearbeiter:in in Ausbildung | 36 | Eilt | — | Wunder Punkt | Lernduell |
| **Graf Mopsula** (Übung) | Beistand, diesmal gegenüber | 40 | — | Eiskalt | Nicht zuständig | Lernduell |
| **Ulla Umlauf** | Abteilungsleiter:in | 50 | Eiskalt | Stempel | Immunität (Wiedervorlage prallt ab) | Sieg gegen Ferdi |
| **Der Stempelmeister** | Endgegner, Zimmer 8.08 | 50 | Rohrpost | Eilt | Phasen + Durchsage | Sieg gegen Ulla |

Alle haben Tempo 10 (SD-14). Auf den Wartenummern-Zetteln stehen Kurznamen mit höchstens 7 Zeichen (FERDI, GRAF, ULLA,
MEISTER; Feld `short`, Kap. 4.3).

### 3.2 Ferdi Durchschlag — Sachbearbeiter:in in Ausbildung

Ein freundlicher **Formular-Golem** aus Durchschlagpapier mit Büroklammer-Gelenken, erster Tag an Schalter 3 („Ich habe noch
keine Stempelfarbe. Ich habe einen Stift.“). Er ist der **Azubi des Revier-Bosses „Der Sachbearbeiter“** (09 Kap. 3.1) —
das trennt die beiden Figuren sauber (der Revier-Boss sitzt nie am Kartentisch) und gibt einen Running Gag („Mein Chef sagt,
ich soll Sie aufhalten. Mit Papier.“).

- **Deck:** je 2 × Stempel, Doppelstempel, Formular 27b, Ablehnungsbescheid, Kältespray, Wiedervorlage, Tief durchatmen,
  Werbepflaster, Umlaufmappe, Gegengift-Gurgler.
- **Spielweise:** bunt gemischt, heilt unter 50 % Geduld bevorzugt, spielt gern Wiedervorlagen („Das müssen wir wieder
  vorlegen.“). Im Lernduell: Drehbuch (Kap. 1.10).
- **Witz:** Wird er von „Eilt“ getroffen, wellt sich sein Papier („Bitte nicht knicken!“). Bei einer Niederlage stempelt er
  sich selbst ein „Erledigt“ auf die Stirn.

### 3.3 Ulla Umlauf — Abteilungsleiter:in

Ein **Aktenschrank auf vier Beinen** mit Schubladen-Mund und Lesebrille; spricht in Rundschreiben („Gemäß Umlauf 12/4 …“).
Gründlich, nie gemein, liest wirklich alles.

- **Neue Regel — Immunität:** Wiedervorlagen prallen ab („Ich lege mir nichts selbst vor.“, Popup „ABGEPRALLT“; Engine:
  `status_immune`). Die Kabelpeitsche macht trotzdem ihren Ärger.
- **Zuständigkeiten:** für **Stempel nicht zuständig** („Einfache Stempel? Andere Abteilung.“), **Eiskalt** ist ihr wunder
  Punkt („Ablehnungen nimmt sie persönlich. Sie lehnt lieber selbst ab.“).
- **Deck:** je 2 × Kleingedrucktes, Leinen-Fallstrick, Ablehnungsbescheid, Formular 27b, Wiedervorlage, Erste Hilfe,
  Heiliges Schlabbern, Doppelstempel, Frostniesen, Gegengift-Gurgler.
- **Spielweise (plant):** bei jeder vierten eigenen Karte bevorzugt sie den Leinen-Fallstrick (Dienst nach Vorschrift,
  `turn_mod [4, 0]`), sonst gern Kleingedrucktes, unter 40 % Geduld heilt sie; ansonsten arbeitet sie ihren Stapel ab.
  (SD2: 40 statt 50 % und Heilkarten mit kleinem Gewicht — sonst lag die Startmappe unter ihrem Band, U-14.)

### 3.4 Der Stempelmeister — Endgegner

Eine hohe Gestalt im grauen Kittel, deren Kopf ein **Stempelkarussell** mit zwölf Stempeln ist; er spricht nur in
Bescheid-Formeln („Bescheid. Bescheid. BESCHEID.“). Er empfängt in **Zimmer 8.08**. Für ihn gelten **dieselben Regeln wie
für alle** (SD-14: Tempo 10, keine Endgegner-Ausnahmen der Engine) — schwer machen ihn seine Phasen, die Durchsage, der
Feierabend-Eilvermerk und der Große Amtsstempel.

- **Zuständigkeiten:** Rohrpost ist sein wunder Punkt („Er hasst Unterbrechungen.“), für Eilt ist er nicht zuständig („Bei
  mir eilt nichts. Nie.“).
- **Deck:** je 2 × Formular 27b, Ablehnungsbescheid, Doppelstempel, Wiedervorlage, Leinen-Fallstrick, Kleingedrucktes,
  Tief durchatmen, Stempel; je 1 × Großer Amtsstempel, Wuchtschlag, Kältespray, Umlaufmappe.
- **Startwerte aus dem Review:** Mit Geduld 72, Tempo 12 und je 2 × Großem Amtsstempel, Wuchtschlag und Kabelpeitsche gab es
  im Prototyp einen Sieg in 1 200 Duellen (auch mit passender Mappe nur 0,3 %). Mit den Werten oben: Startmappe ≈ 4 %, Mappe
  aus dem, was man beim ersten Besuch besitzt, ≈ 50 %, volle Sammlung ≈ 63 % (Kap. 6.9).
- **Gemessen in SD2** (`SdAi` statt der Prototyp-Heuristik, Gewichte aus `opponents.json`, 1 000 Seeds): Startmappe 7,5 %,
  erster Besuch 46,8 %, volle Sammlung 83,1 %. Die volle Sammlung bleibt mit jeder geprüften Gewichtung über 65 % — das Band
  ist deshalb 70–90 % (U-15). Gewichte je Phase: 1 ausgewogen (Kleingedrucktes, Leinen-Fallstrick, Wiedervorlage vorn,
  Großer Amtsstempel 1), 2 Wiedervorlage und Tief durchatmen (unter 50 %) vorn, 3 Großer Amtsstempel und Wuchtschlag vorn.
- **Phasen** (`phases`, GDD §3.11; Phasenwechsel nach jedem Ärger, nie übersprungen):

| Phase | Geduld | `on_enter` | Spielweise | M.O.D. |
|---|---|---|---|---|
| 1 „Dienstbeginn“ | > 60 % | `say` `sd_boss_intro` | ausgewogen; Großer Amtsstempel selten | „Der Stempelmeister! Bitte erheben Sie sich. Nein, setzen Sie sich. Formular 1.“ |
| 2 „Durchsagen“ | > 25 % | `add_pseudo` `pu_sd_durchsage` (Start 50 Ticks), `say` `sd_boss_phase:2` | Wiedervorlagen bevorzugt — er schiebt Sie hinter die Durchsage | „Achtung, eine Durchsage: Ab jetzt wird durchgesagt.“ |
| 3 „Feierabend naht“ | ≤ 25 % | `status_self` `sts_sd_eilvermerk` (99 Züge), `say` `sd_boss_phase:3` | Großer Amtsstempel und Wuchtschlag bevorzugt | „Er will nach Hause. Er wird schneller. Und gefährlicher.“ |

  In der Engine `ai.type "phased"` mit den Aktionen in `phases[].actions` (Validator-Regel 6). **Konter:** Der
  Leinen-Fallstrick hebt den Feierabend-Eilvermerk auf (Dienst nach Vorschrift und Eilvermerk schließen sich aus) — danach
  ist er wieder normal schnell. Der Graf sagt es beim ersten Mal in einer Fußnote.
- **Die Durchsage** (`pu_sd_durchsage`, Pseudo-Einheit wie der Zug der Rattenkönigin): ein grauer Zettel mit Lautsprecher in
  der Wartenummern-Anzeige. Wenn ihre Nummer kommt: **4 Ärger** (Engine: 8 % der vollen Geduld), **mit Abheften 2**; danach
  wieder **6 Werktage** (100 Ticks) Pause. Steht sie an **zweiter** Stelle der Anzeige, warnt M.O.D. („Achtung, gleich eine
  Durchsage! Wer abheftet, hört nur die Hälfte.“) und der Zettel blinkt (≤ 2 Hz). Die Durchsage kann man nicht treffen; sie
  verliert jeden Gleichstand.
- **Witz:** Bei jedem Phasenwechsel dreht sich das Karussell lauter; bei seiner Niederlage stempelt er Ihnen ehrfürchtig ein
  „BEWILLIGT“ in Gold auf die Karte — die Trophäe Großer Amtsstempel.

### 3.5 Graf Mopsula — Übungsduell

Der Graf setzt sich zum Üben gegenüber. **Gegnerhand offen** ist hier Standard („Ich spiele mit offenen Karten. Ehrensache.
Fußnote 2: Und weil ich sonst verliere.“) — das Übungsduell ist die Lernstrecke für Deckbau und Zeit-Karten.

- **Zuständigkeit:** für Eiskalt nicht zuständig („Doppelter Unterpelz, Kolleg:in.“).
- **Deck:** je 2 × Adelsflamme, Frostniesen, Heiliges Schlabbern, Gräfliches Gutachten, Bellen in Stereo, Doppelstempel,
  Stempel, Tief durchatmen, Kleingedrucktes, Wiedervorlage.
- **Spielweise:** Eilvermerk zuerst, dann Adelsflamme und Bellen; heilt sich unter 50 %. Er kommentiert jeden eigenen Zug
  mit einer Fußnote — doziert, nie herablassend.

### 3.6 Spielweise der Gegner (KI) und Auto

**Gegner:** Die Spielweise ist eine normale `ai`-Tabelle der Engine (gewichtete Aktionen, Bedingungen `self_hp_below`,
`turn_mod` usw., Zielregeln `random`/`self`). Weil `EnemyAI.choose` heute schon nur **benutzbare** Fähigkeiten zieht
(`state.usable_skills(actor)`) und das Duell die Hand als Fähigkeitenliste setzt (Kap. 6.5), wählt die KI automatisch **nur
aus ihrer Hand** — ohne eine Zeile Engine-Code. Bleibt nach dem Filtern nichts übrig, liefert `EnemyAI` den Grundangriff;
das Duell macht daraus **Abheften** (abgelegt wird die Handkarte mit dem kleinsten Gewicht, bei Gleichstand die linke).
Der KI-Würfel ist der Engine-Strom `ai`, je Zug neu abgeleitet — Replays rechnen dieselben Züge (GDD §3.11, 05 CR-2).
Gegner sehen Ihre Hand nicht; sie schummeln nicht.

**Für Sie** gibt es zwei Ratgeber:

| Ratgeber | Regel | Wofür |
|---|---|---|
| `AutoPolicy` (Engine, unverändert) | Durchsage vor dem eigenen nächsten Zug → Abheften; unter 35 % Geduld → Heilkarte; sonst die Karte mit dem meisten Ärger, ohne auf Werktage zu achten (der Grundangriff rechnet mit Stärke 1 nur ½ Ärger, jede Ärger-Karte schlägt ihn); sonst Abheften | Harness-Profil „einfach“ (Untergrenze, Kap. 6.9), Rückfall |
| `SdAi.suggest` (neu, rein) | wertet jede Handkarte als **Ärger bzw. Geduld je Werktag** plus Tempo-Wert (Vorschau: Wie viele Nummern bin ich vor dem Gegenüber?), Abheften vor einer Durchsage, Zuständigkeiten, Heilung erst bei Bedarf | Tipp des Grafen, „Der Graf übernimmt“, Harness-Profil „gut“ |

Beide sind deterministisch und würfeln nicht.

### 3.7 Kampagne im Amt: Etage 8

Das Stempelduell **gehört** auf Etage 8 der Kulisse „Amt für Etagenwesen“ (Etagen 7–9, Stufen-Band 25–28, 5 Tage im
Kalender, 09 Kap. 2.4/3.1):

- **Ort:** Die Safe Rooms der Etagen 7–9 sind als **Wartezimmer** gestaltet (Stuhlreihen, Nummernanzeige, Gummibaum). Auf
  **Etage 8** steht dort **Schalter 3** mit Wartemarken-Spender; im Safe-Room-Menü wird die Zeile „Mopsula“ auf Etage 8 zu
  **„Mopsula | Schalter 3“** (zwei halbe Knöpfe wie „Automat | Ausrüstung“, GDD §14.7 — so passt das Menü weiter über den
  Chat-Ticker). „Schalter 3“ öffnet die Schalterhalle (Kap. 4.7) per `Router.push`.
- **Warum im Wartezimmer:** Dort ist man sicher, die Etagen-Uhr steht im Safe Room ohnehin (Am Stück), und ein Duell bleibt
  eine Pause vom Dungeon — nie ein Grund, Zeit zu verlieren. Im Kalender-Tempo läuft die Staffel-Uhr weiter (09 Kap. 9.1);
  ein fälliger Einsturz wartet wie nach einem Kampf bis zum Duellende plus 2 Minuten (09 Kap. 2.5).
- **Vorgeschmack:** Auf Etage 7 hängen Plakate („STEMPELDUELL — Etage 8, Schalter 3. Bitte Nummer ziehen.“), Ferdi verteilt
  dort im Wartezimmer Wartemarken (eine Zeile, kein Duell). Beim ersten Betreten eines Wartezimmers auf Etage 8 sagt M.O.D. die
  Ein-Satz-Erklärung (Kap. 0.4). Keine Tutorial-Karte in der Erkundung.
- **Leiter:** Auf Etage 8 sind dieselben Gegner wie im Freien Spiel frei (Freischaltung ist Konto-Sache, Kap. 5.2); neu sind
  die **Staffel-Belohnungen** (Kap. 5.3) und ab ST1-F die **KI-Kandidat:innen** (Kap. 3.8).
- **Ein-Regel-Fahrplan:** Für die Staffel ist das Stempelduell keine neue Regel (09 Kap. 0.6), sondern ein Angebot zum
  Entdecken — wer es ignoriert, verliert nichts.
- **Nicht in Event-Läufen** (SHOWRUN, 05): dort gibt es keinen Schalter 3 und keine Duelle.

### 3.8 Später: KI-Kandidat:innen als Gegner (SD3, mit 09 ST1-F)

Bis zu zwei KI-Kandidat:innen sitzen nach 09 Kap. 4.3 im Safe Room. Auf Etage 8 bietet eine von ihnen ein Duell an („Lust
auf ein Stempelduell? Mein Antrag liegt eh auf Wiedervorlage.“). Ihr Deck kommt aus einer **Vorlage je Profil**
(`opponents.json → templates`), die Geduld ist 45, der Name stammt aus dem KI-Namenskatalog (nur Anzeige, nie im Hash):

| Profil (09 Kap. 4.4) | Deck-Vorlage | Spielweise |
|---|---|---|
| Statist:in | Startmappe | wie Ferdi |
| Rival:in | viel Ärger, Wiedervorlagen | angriffslustig; sagt den Spielstand vorher und nachher an („3 zu 2 für mich. Noch.“) |
| Helfer:in | Heilung, Eilvermerke | defensiv; schenkt nach einer Niederlage eine Fußnote |
| Händler:in | ausgewogen | rechnet laut („Das war ein schlechtes Geschäft für Sie.“) |
| Pechvogel | Zeit-Karten, Kleingedrucktes | chaotisch; heftet oft ab |

KI-Duelle bringen **keine Staffel-Belohnung**, nur eine Eilmeldung im Ticker („Eilmeldung: Bodo Bürste verliert im
Stempelduell. Er beantragt Revision.“, Tag `cast_sd_*`, höchstens eine je Staffel-Tag) und einmal je Profil einen Kartenrücken
fürs Konto. Gastauftritte, Bosskämpfe und Rangliste der Staffel bleiben unberührt (09 Kap. 4.5).

### 3.9 Ton, Witz und Leitplanken (inkl. IP)

**Worauf der Witz zielt:** Verfahren, Formulare, Wartenummern, Stempel, Zuständigkeiten, Dienstwege, Kleingedrucktes — also
das **System**, nie die Menschen, die in echten Ämtern arbeiten (06 L-3). Die Gegner sind Fantasiegeschöpfe mit Herz: Ferdi
ist liebenswert, Ulla gründlich und fair, der Stempelmeister erhaben; jede:r hat einen warmen Moment („heimlich
sentimental“, GDD §11.1).

**Verboten:** sexuelle Anspielungen, Körper-Witze, Spott über Berufe oder Personen, Namen echter Behörden oder Einrichtungen
(keine Ämter, Kassen oder Agenturen aus der echten Welt), Politik, Parteien, Nationalitäten als Pointe (06 L-7), Zitate aus
Filmen, Comics oder Büchern — ausdrücklich **kein „Passierschein A38“** (Asterix) und keine anderen bekannten
Bürokratie-Zitate. Die Formularnummern sind eigene (27b, 12/4, Zimmer 8.08 …).

**IP-Abstand:** Übernommen werden nur **allgemeine Kartenspiel-Konventionen** (Deck, Hand, Nachziehen, Ablage, Mischen,
Kopienlimit, Deckbau, goldener Rahmen für Besonderes). **Nicht** übernommen: Raster mit Zahlen an den Kartenkanten und
Umdrehen/Erobern von Karten (Triple Triad), Reihen, drei Runden und Passen (Gwent), Mana-Kristalle, Helden mit Heldenkraft,
Diener auf einem Spielbrett (Hearthstone), Kartenpackungen mit Seltenheitswürfeln (Gacha). Der Kern — Zeit statt Mana,
Wartenummern statt Brett — ist eigen. Die CTB-Zeitleiste ist eine allgemeine Mechanik; im Spiel heißt sie nie „CTB“.
**Keine DCC-Elemente** (keine Begriffe, Figuren, Spiele oder Szenen aus dem Buch; im Spiel „Kandidat:innen“, nie
„Crawler“). Der Name **„Stempelduell“** kommt auf die Prüfliste der Markenrecherche (04 §2.5) **[zu prüfen]**.

**Prüfung im Code:** Alle Texte aus `data/stempel/*.json` laufen durch `validators/ip_words.gd` (Regel 14 aus 02_TECH §4.5)
und eine kleine eigene Wortliste (echte Behördennamen, „A38“); M.O.D.-Zeilen ≤ 110 Zeichen, nur bekannte Platzhalter,
Glyphen-Regel F8 (Kap. 6.9).

---

## 4. Präsentation & UX

### 4.1 Entscheidung: 2D-Kartentisch im TV-Look

| Kriterium | 3D-Kampfbühne weiterverwenden (`scenes/battle/**`) | **2D-Kartentisch (gewählt)** |
|---|---|---|
| Aufwand | ≈ 6 100 Zeilen Bühne, Kamera, HUD, Player behalten **und** trotzdem eine neue Karten-Oberfläche bauen; Arena und Rigs mitpflegen | neue Oberfläche ≈ 2 000–2 500 Zeilen; alle 3D-Teile entfallen |
| Bild | zwei Figuren in einer Arena — passt zu Kampf, nicht zu „Schalter“ | Tisch, Schalter, Nummernanzeige, Stempel — das Amt *ist* das Bild |
| Mobil | 3D-Draw-Calls + HUD (Kampf-Budget 150 + 180) | nur Canvas, ≤ 120 UI-Draw-Calls, 0 3D (Kap. 6.10) |
| Touch | Befehlsmenü-Logik | Karten antippen und ziehen, große Ziele |
| Zukunft | R5b löscht die Bühne ohnehin | unabhängig vom Kampf-Code |

Der TV-Rahmen kommt aus vorhandenen Bausteinen: **ShowOverlay** (LIVE-Badge, Senderlogo-Ecke „STEMPELDUELL“, Chat-Ticker) in
einem neuen Overlay-Modus `duel`, die **ModDialog**-Box mit der M.O.D.-Drohne (64-px-SubViewport, außerhalb des Kampfs
erlaubt), ein **Studio-Hintergrund** im Stil von `broadcast_bg.gd` (reines `_draw`: Tinte, Lichtkegel in Magenta/Cyan,
dazu eine Nummernanzeige und eine Schalterkante) und gezeichnete **Symbole** für Figuren und Karten (`ui_icon.gd`/
`icon_mesh.gd`, wie die statischen Party-Symbole des Echtzeit-HUD, 03_ART §9.5) — **keine** Porträt-SubViewports.

### 4.2 Bildschirmaufbau

**Desktop / Gamepad, 1280 × 720:**

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ (o LIVE)  STEMPELDUELL · Etage 8 · Schalter 3                                     [Pfote] [Menü]   │ Overlay „duel“, Rand 24 px
│ ┌ WARTENUMMERN ──────────────────────────────────────────────────────────────────────────────────┐ │
│ │ JETZT 007 SIE ┃ SIE ┃ FERDI ┃ SIE ┃ FERDI ┃ SIE ┃ FERDI ┃ SIE ┃ FERDI ┃ … 10 Zettel            │ │ 64 px hoch
│ └────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│  ┌ [Golem] FERDI DURCHSCHLAG · Sachbearbeitung ─────────┐   Hand [5 Rücken]  Stapel 11             │
│  │ Geduld ████████████████░░░░░░  27 / 36               │   WUNDER PUNKT: [Flamme] Eilt            │ 80 px
│  │ Zustände: [Schnecke 2]                               │   Ablage 4 (antippbar)                   │
│  └──────────────────────────────────────────────────────┘                                          │
│  [M.O.D.-Box mit Drohne, max. 2 Zeilen]                     ┌ SCHALTER ────────────────────────┐   │
│                                                             │ zuletzt: „Formular 27b“  −9      │   │ 90 px
│                                                             └──────────────────────────────────┘   │
│  ┌ [Kopf] [Mops] ROBIN & DER GRAF ──────────────────────┐   [Fußnote des Grafen, wenn aktiv]       │
│  │ Geduld ██████████████████░░  44 / 50  [Eilvermerk 2] │                                          │ 64 px
│  └──────────────────────────────────────────────────────┘                                          │
│ ┌ ABLAGE ┐  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   ( STEMPELN )                                 │
│ │Abheften│  │  1  │ │  2  │ │  3  │ │  4  │ │  5  │   96 px rund                                   │ Hand 210 px
│ └────────┘  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘                                                │ (+24 beim Markieren)
│ Chat-Ticker: stempelfan99: FORMULAR 27b, LETS GO  ·  mitleserin: besser als alles, was ich abonn…  │ 22 px
└────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Höhenrechnung (720p): Rand 24 + Overlay 30 + Anzeige 64 + Gegner 80 + Schalter 90 + Sie 64 + Hand 210 + Ticker 22 + Abstände
≈ 650 px — passt mit Reserve für das Anheben einer markierten Karte. Breite: Ablage 120 + 5 × 150 + 4 × 12 + Knopf 96 + Ränder
≈ 1 060 px.

**Touch, Querformat 1600 × 720 (20:9) und breiter:** Karten 170 × 236 px als leichter Fächer am unteren Rand, Anzeige mit 8
größeren Zetteln (104 px breit, Text ≥ 20 px), „Ablage“ links und „STEMPELN“ rechts in Daumennähe (Linkshänder-Spiegelung in
den Optionen),
M.O.D.-Box oben rechts unter der Anzeige. Alle Ziele ≥ 88 px Trefferfläche, Abstände ≥ 12 px (`UiTheme.ensure_hit_area`).
Nur Querformat (GDD §14.8).

```text
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ (o LIVE) STEMPELDUELL                                               [Pfote]  [Menü]  │
│ ┃JETZT 007 SIE┃ SIE ┃ FERDI ┃ SIE ┃ FERDI ┃ SIE ┃ …  (8 Zettel)                      │
│ [Golem] FERDI  Geduld █████████░░░ 27/36  WP: Eilt                    [M.O.D.-Box]   │
│                 [ SCHALTER: zuletzt „Formular 27b“  −9 ]                             │
│ ROBIN & GRAF  Geduld ███████████░ 44/50  [Eilvermerk 2]                              │
│ ┌──────┐   ╭───╮╭───╮╭───╮╭───╮╭───╮                                  ╭──────────╮   │
│ │ABLAGE│   │ 1 ││ 2 ││ 3 ││ 4 ││ 5 │  (Fächer, ziehbar)               │ STEMPELN │   │
│ └──────┘   ╰───╯╰───╯╰───╯╰───╯╰───╯                                  ╰──────────╯   │
│ Chat-Ticker                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**Ergebnis-Panel** (Ebene 60, Goldrahmen wie das Abspann-Panel des Echtzeitkampfs): großer schräger Stempel „BEWILLIGT“
(rot) bzw. „ABGELEHNT“ (grau), darunter neue Karten (fliegen ins Album), Stempelheft-Feld, Dienstauszeichnungen, in der Staffel
die Staffel-Belohnung; Knöpfe **Revanche** (Fokus) · **Andere Mappe** · **Zurück**.

### 4.3 Die Wartenummern-Anzeige

- **Inhalt:** die nächsten Aufrufe aus `preview_order` (12 berechnet; Desktop zeigt 10, Touch 8). Jeder Zettel zeigt die
  Besitzer:in als **Form + Wort** („SIE“ im blauen Kreis, der Kurzname des Gegenübers in der roten Raute — höchstens 7
  Zeichen —, „DURCHSAGE“ im grauen Rechteck mit Lautsprecher) — farbenblind-sicher, nie nur Farbe.
- **Nummern:** Nur der aktuelle Zettel trägt eine Nummer: Er steht groß links mit „JETZT 007“ (3 Ziffern, Monospace,
  `UiTheme.font_mono()`; n = n-ter Aufruf, `BattleState.turn_count`, Pseudo-Züge zählen mit, Beginn bei 001); ein **Gong** und
  die Zeile „Nummer 007 — Sie sind dran.“ bzw. „Nummer 008 — Ferdi stempelt.“ rufen ihn auf. Künftige Zettel bleiben ohne
  Nummer, weil sich die Prognose nach jeder Karte des Gegenübers verschieben kann (Kap. 1.2) — eine Wartenummer, die
  umspringt, wäre keine.
- **Vorschau:** Ist eine Handkarte markiert, zeigt die Anzeige als **Geist-Zettel** (gestrichelter Rand mit ≥ 3 : 1 Kontrast,
  Füllung 50 %), wo Ihre nächste Nummer und die des Gegenübers nach dieser Karte landen — für Wiedervorlage, Eilvermerk und
  Dienst nach Vorschrift genau so wie für normale Karten (Probelauf, Kap. 6.5). Sicher ist der vorderste Teil (wer als
  Nächstes dran ist, Sie vor oder nach der nächsten Nummer des Gegenübers, die Durchsage); dahinter ist es eine Prognose.
  Beim Abheften-Knopf zeigt sie das Ergebnis des Abheftens.
- **Bewegung:** Zettel gleiten in 0,2 s an ihre neuen Plätze (wie die CTB-Leiste, 02_TECH §5.7); eine Wiedervorlage schubst
  den Zettel des Gegenübers sichtbar nach rechts, ein Eilvermerk zieht den eigenen nach links.
- **Ketten:** Ist dieselbe Seite drei- oder mehrmals hintereinander dran, verbindet eine Klammer die Zettel („3 × SIE“) — der
  schönste Moment des Spiels bekommt ein eigenes Bild und eine Chat-Zeile.

### 4.4 Ein Zug in Bildern (Tempo × 1)

| Zeit | Was man sieht und hört |
|---|---|
| 0,0 s | Gong, Zettel „JETZT 007 SIE“ leuchtet, Hand hebt sich leicht, Fokus auf der ersten Karte |
| Markieren | Karte hebt sich 24 px, Geist-Zettel in der Anzeige, Zahl auf der Karte wird zur echten Zahl („14 statt 9 · WUNDER PUNKT“), Geduld-Leiste des Gegenübers zeigt den Verlust als blasses Segment |
| Spielen | Karte fliegt in 0,25 s auf den Schalter, **Stempel-Wumms** (Skalierung 1,3 → 1,0 in 0,12 s, kleines Wackeln, abschaltbar), Tintenklecks |
| +0,35 s | Ärger-Zahl über der Gegner-Plakette (rot; Wunder Punkt gelb, nicht zuständig grau), Leiste läuft nach (0,5 s), Zustands-Symbol erscheint |
| +0,6 s | neue Karte gleitet vom Stapel in die Hand; Anzeige gleitet weiter |
| Gegenzug | 0,5 s „Ferdi überlegt“ (Stift kratzt), Karte erscheint verdeckt über seiner Hand, dreht sich, fliegt auf den Schalter — gleiche Folge |

Ein Gegnerzug dauert ≈ 1,5 s, mit Tempo × 2 ≈ 0,8 s. Die Engine-Ereignisse werden in der Reihenfolge der Engine gespielt
(02_TECH §5.3); was nicht ins Bild gehört (MP-Änderungen, Credits), wird ausgelassen.

### 4.5 M.O.D. als Moderatorin, der Graf als Beistand

M.O.D. moderiert das Duell als **Spieleshow in ihrer Show**: Intro mit Senderlogo, Kommentare zu besonderen Momenten, Finale.
Regeln: höchstens **eine M.O.D.-Zeile je drei Nummern** (Ausnahmen: Intro, Phasen, Durchsage-Warnung, Ende), jede Zeile
≤ 110 Zeichen, siezt die Kandidat:in, nennt den Grafen „unseren Herrn Grafen“ (GDD §11.1). Der Graf spricht in der Ich-Form
mit Fußnoten, Pseudolatein und Tierheim-Erinnerungen, nennt die Kandidat:in „Kolleg:in“, **kein** Pluralis Majestatis.
Chat-Zeilen (erfundene Nutzernamen) kommentieren Show-Karten, Ketten und Siege. Daten: `data/stempel/lines.json`, Tags
`sd_*`, Stimmen `mod`/`mopsula`/`chat` (Kap. 6.4). Beispiele:

| Tag | Stimme | Zeile |
|---|---|---|
| `sd_intro` | mod | „Willkommen bei STEMPELDUELL, der Spieleshow in meiner Show! Heute: Papier gegen Nerven.“ |
| `sd_first_card` | mod | „Eine Karte, ein Zug. Lange Formulare, lange Wartezeit. Wie im echten Leben, nur mit Kamera.“ |
| `sd_wiedervorlage` | mod | „Wiedervorlage! Die Nummer rutscht nach hinten. Das Publikum liebt Verzögerungen. Ich auch.“ |
| `sd_chain` | mod | „Dreimal hintereinander dran! Das nennt man bei uns ‚Programmplanung‘.“ |
| `sd_show_success` | mod | „Ein Stempel wie ein Donnerschlag! Das kommt in die Jahresrückschau.“ |
| `sd_show_fail` | mod | „Patzer am Schalter. Die Wiederholung läuft in Zeitlupe. In Dauerschleife.“ |
| `sd_durchsage_warn` | mod | „Achtung, gleich eine Durchsage! Wer abheftet, hört nur die Hälfte.“ |
| `sd_win` | mod | „Antrag bewilligt! Applaus vom Band — heute ausnahmsweise echt.“ |
| `sd_loss` | mod | „Antrag abgelehnt. Widerspruch ist zwecklos, Revanche nicht.“ |
| `sd_dienstschluss` | mod | „Dienstschluss! Ihr Antrag ist vertagt. Bitte ziehen Sie morgen eine neue Nummer.“ |
| `sd_hint:file` | mopsula | „Kolleg:in, ich rate zum Abheften. Fußnote 9: Wer abheftet, hat mehr vom Leben.“ |
| `sd_tie` | mopsula | „Fußnote 12: Bei Gleichstand geht die Kundschaft vor. Das Einzige, was ich an Ämtern mag.“ |
| `sd_tut:2` | mopsula | „Fußnote 1: Kurze Formulare, kurze Wartezeit. Zwinger 7 wusste das. Mein Antrag auf Decke nicht.“ |
| `sd_chat_show` | chat | „stempelfan99: SHOW-KARTE!!! mein puls“ |

Die Zeilen spricht ein kleiner **Duell-Ansager** (`scenes/stempel/sd_host.gd`) über `Events.mod_said` an ModDialog und
ShowOverlay — er nutzt **nicht** den `ModAnnouncer` der Kampagne, damit Kampagnen-Zeilen, Cooldowns und Prioritäten
unberührt bleiben. Zufall bei der Zeilenwahl ist reine Darstellung (eigener Anzeige-Zufall, nie im Hash).

### 4.6 Bedienung

**Touch:**

| Geste | Wirkung |
|---|---|
| Karte antippen | markieren (hebt sich, Vorschau) — **erneut antippen** oder „STEMPELN“ spielt sie |
| Karte nach oben auf den Schalter ziehen | spielen (Loslassen über dem Schalter-Feld, Ziehen ab 12 px; Tippen ≠ Ziehen wie 07 E19) |
| Karte auf „ABLAGE“ ziehen | mit dieser Karte abheften |
| „ABLAGE“ antippen | Abheften-Modus: „Welche Karte abheften?“ — Karte antippen, „Zurück“ bricht ab |
| Karte lang drücken (0,4 s) | Großansicht mit vollem Text; antippen schließt |
| Gegner-Plakette / Ablage-Zähler antippen | Akte des Gegenübers / gespielte Karten ansehen |
| Pfote | Fußnote des Grafen zur empfohlenen Karte. „Der Graf übernimmt“ schaltet man im Menü (Hilfen) — keine versteckte Geste, die aus Versehen auslöst |

**Tastatur und Maus:**

| Eingabe (Aktion) | Wirkung |
|---|---|
| ← / → (`ui_left`/`ui_right`) oder Ziffern 1–5 | Karte markieren |
| Enter / Leertaste / F (`ui_accept`, `action`) | markierte Karte spielen |
| X oder Rücktaste (`sd_file`, neu) | Abheften-Modus (dann Karte wählen, Enter; Esc bricht ab) |
| Tab oder M (`map`) | Großansicht der markierten Karte (mit Fußnote des Grafen, wenn sie die empfohlene ist) |
| Q / E (`tab_prev`/`tab_next`) | Fokusbereich wechseln: Hand → Wartenummern-Anzeige → Akte |
| T (`toggle_auto`) | „Der Graf übernimmt“ an/aus |
| R (`toggle_speed`) | Tempo × 1 / × 2 |
| Esc / P (`pause`) | Menü (Regeln, Hilfen, Antrag zurückziehen) |
| Maus | wie Touch: Klick markiert, Doppelklick oder Ziehen spielt |

**Gamepad:**

| Taste (Aktion) | Wirkung |
|---|---|
| Steuerkreuz / linker Stick ← → (`ui_left`/`ui_right`) | Karte markieren (der Fokus ist die Markierung, Vorschau läuft mit) |
| A (`ui_accept`) | spielen |
| X (`sd_file`, neu) | Abheften-Modus (A bestätigt, B bricht ab) |
| B (`ui_cancel`) | zurück (Abheften-Modus, Großansicht, Akte) |
| Select (`map`) | Großansicht der markierten Karte — „Karte“ im doppelten Sinn; bei der empfohlenen Karte steht dort die Fußnote des Grafen |
| LB / RB (`tab_prev`/`tab_next`) | Fokusbereich wechseln: Hand → Wartenummern-Anzeige → Akte des Gegenübers (Lesen, Steuerkreuz blättert) |
| Y (`toggle_auto`) | „Der Graf übernimmt“ an/aus (wie Auto im Kampf) |
| R3 (`toggle_speed`) | Tempo × 1 / × 2 |
| Start (`pause`) | Menü |

Die Tastenhinweise zeichnet `input_glyph.gd` passend zum Eingabeschema. Das Duell nutzt die vorhandenen Aktionen der
Input-Map mit ihrer gewohnten Bedeutung und braucht **eine neue Aktion** `sd_file` (Tastatur X und Rücktaste, Gamepad X;
additiv in `project.godot`, Kap. 7.3); die Ziffern 1–5 liest die Szene als Komfort direkt als Tasten — die Aktionen
`bar_1` … `bar_5` liegen auf dem Gamepad auf A/X/Y/B/RB und würden sonst mit „spielen“ kollidieren. Es gibt **kein
Zeitlimit** für einen Zug.

**Stand nach SD1 (07 E36, §7.7):** `project.godot` bindet Tab nicht mehr an `map` (Tab wählt in der Erkundung ein Ziel) und
Y nicht mehr an `toggle_auto` (das liegt am Pad auf Steuerkreuz oben). Die Tabellen oben setzen die alte Belegung voraus: Das
Duell ruft beim Betreten `CombatInput.apply_input_mode(false)` (Tab → `map`, Y → `toggle_auto`, Steuerkreuz oben aus) und
beim Verlassen `CombatInput.apply_for_game()` — oder liest Tab und Y in seiner Szene selbst. `toggle_speed` (R, R3) ist
weiter in der Input-Map, die Kampagne nutzt es seit SD1 nicht mehr (im Echtzeitkampf ist R das Partner-Spezial, eine eigene
Abfrage): frei für „Tempo × 1 / × 2“.

### 4.7 Menüs: Schalterhalle, Aktenschrank, Stempelalbum

**Einstieg:** Titel → **Extras** → **Stempelduell (Vorschau)** (der Titel bekommt eine Zeile „Extras“ zwischen „Event-Lauf“
und „Optionen“; Extras ist ein kleines Untermenü, das später auch Ruhmeshalle und Galerien aufnehmen kann) bzw. auf
Etage 8 „Schalter 3“ im Wartezimmer.

```text
┌ SCHALTERHALLE ───────────────────────────────────────────────────────────────┐
│  Bitte ziehen Sie eine Nummer.              Stempelheft: [S][S][ ]  (noch 1) │
│                                                                              │
│  ┌ WARTEMARKE ┐  ┌ WARTEMARKE ┐  ┌ WARTEMARKE ┐  ┌ WARTEMARKE ┐              │
│  │ Ferdi      │  │ Der Graf   │  │ Ulla Umlauf│  │ Stempel-   │              │
│  │ besiegt 3× │  │ Übung      │  │ NEU        │  │ meister    │              │
│  │            │  │            │  │            │  │ nach Ulla  │ (gesperrt)   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘              │
│                                                                              │
│  [ Aktenschrank (Mappe A) ]  [ Stempelalbum 14/24 ]  [ Regeln & Lernduell ]  │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Wartemarke wählen** → **Akte** des Gegenübers (Symbol, Geduld, Zuständigkeiten, neue Regel in einem Satz, was der erste
  Sieg bringt) → „Mappe wählen“ → Duell. Ein gesperrtes Gegenüber nennt den Weg dorthin („Erst nach einem Sieg gegen Ulla
  Umlauf.“).
- **Aktenschrank:** Kap. 2.6. **Stempelalbum:** Seiten je Herkunft (Amt, Kandidat:in, Graf, Gegenstände, Talente,
  Trophäen); fehlende Karten als Umriss mit dem Weg dorthin („Stempelheft: noch 2 Siege“, „Der Graf lernt Frostniesen“).
  Dazu das **Stempelheft** (Felder, die bei jedem Sieg gestempelt werden) und die Dienstauszeichnungen.
- **Regeln:** die fünf Sätze, ein Glossar (Geduld, Ärger, Werktag, Wartenummer, Abheften, Zustände, Formular-Arten,
  Zuständigkeiten, Show-Karten, Dienstschluss, „Kundschaft geht vor“), „Lernduell wiederholen“.

Alle Menüs sind fokus-navigierbar (02_TECH §10.2), erstes Element hat den Fokus, modale Panels sind deckend (03_ART §9.2).

### 4.8 Barrierefreiheit

- **Keine Zeitlimits**, keine Reaktionsaufgaben; das Spiel wartet immer auf Sie.
- **Farbe nie allein:** Formular-Arten mit Symbol und Wort, Seiten mit Form und Wort, Zahlen statt Farbbalken-Raten.
- **Lesbarkeit:** Text ≥ 16 px (`UiTheme.FONT_SIZE_SMALL`), auf Touch ≥ 20 px (Kap. 2.2); Großansicht 2 ×; Option
  **„Schriftgröße“ 100 / 125 / 150 %** (in der Sammlung gespeichert, Kap. 6.7) für Karten, Zettel, Plaketten und M.O.D.-Box —
  die Tischkarte zeigt dann nur Name, Werktage und Hauptwirkung; Glyphen-Regel F8 (alle Symbole gezeichnet).
- **Kontrast:** Text ≥ 4,5 : 1 gegen seinen Grund (WCAG AA), große Zahlen, Rahmen und der Geist-Zettel-Rand ≥ 3 : 1; die
  Rahmenfarbe einer Formular-Art ist nie die Textfarbe auf diesem Rahmen.
- **Bewegung:** „Animationen reduzieren“ (keine fliegenden Karten, kein Wackeln, Überblendungen), Tempo × 2; nichts blinkt
  schneller als 2 Hz.
- **Motorik:** alle Ziele ≥ 88 px, Spielen geht mit Tippen-Tippen statt Ziehen, Linkshänder-Spiegelung, vollständige
  Gamepad- und Tastaturbedienung; „Der Graf übernimmt“ für alle, die nur zuschauen wollen.
- **Verstehen:** fünf Sätze, eine neue Regel je Gegner, Tipp des Grafen mit Begründung, Gegnerhand offen zum Üben.
- **Ton:** jedes wichtige Ereignis ist auch sichtbar (Gong ↔ Zettel leuchtet, Durchsage ↔ Zettel blinkt + Zeile).
- **Bildschirmleser:** Die Engine bringt seit Godot 4.5 eine Anbindung an Bildschirmleser für Control-Knoten mit
  **[Umfang in 4.7.2 zu prüfen]**; wenn sie trägt, bekommen Karten, Zettel und Plaketten Beschreibungstexte
  („Formular 27b, Stempel, 3 Werktage, 9 Ärger“) — der Kartentisch ist ohnehin nur aus Control-Knoten gebaut.

### 4.9 Ton und Musik

Neue prozedurale Klänge in `sfx_synth.gd` (eigener Abschnitt): `sd_gong` (Ding-Dong der Nummernanzeige), `sd_stamp`
(dumpfer Stempel), `sd_card` (Papier), `sd_shuffle` (Mischen), `sd_durchsage` (Lautsprecher-Dreiklang), `sd_win` (kurze
Fanfare), `sd_lose` (Posaune, abwärts). Musik: eine leise **Wartezimmer-Schleife** (Fahrstuhlmusik-Parodie) aus der
vorhandenen Musik-Synthese; im Endgegner-Duell wird sie ab Phase 2 schneller.

---

## 5. Belohnungen & Ökonomie

### 5.1 Grundsätze

1. **Einbahnstraße:** Die Kampagne schaltet Karten frei; das Stempelduell gibt der Kampagne **nie Kampfkraft** — keine Werte,
   keine Ausrüstung, keine Verbrauchsgüter, **keine Credits, keine Boxen** (beides wird am Automaten bzw. aus dem Beute-Pool
   zu Ausrüstung und Tränken), keine EP, kein Ausgeruht, keine Talente (R-1; 09 S-20).
2. **Nichts käuflich** — keine Karten, keine Kosmetik, keine Mappenplätze, kein „Duell-Pass“ (04 §6.2, 09 S-24). Auch keine
   kaufbaren Kartenrücken, obwohl 04 kosmetische Käufe erlauben würde (F-7).
3. **Kein Zufall beim Belohnen:** keine Kartenpackungen, keine Seltenheiten, keine Boxen; jede Belohnung des Mini-Spiels
   steht vorher in der Akte bzw. im Stempelheft.
4. **Kein Einsatz:** Man setzt nie Credits oder Gegenstände; eine Niederlage kostet nichts (keine Glücksspiel-Anmutung).
5. **Einmal je Staffel:** Belohnungen, die einen Spielstand berühren, gibt es nur auf Etage 8 und je Gegner nur **einmal je
   Staffel** — kein Farmen.

### 5.2 Konto (bleibt, auch im Titel-Extras)

Was das Konto „Karriere“ (09 Kap. 2.8: Titel, Kosmetik, Ruhmeshalle, Konto-Erfolge) dazubekommt:

| Anlass | Belohnung |
|---|---|
| Lernduell beendet | Grundakte (12 Karten) + Startmappe, Kartenrücken „Durchschlag“ |
| erster Sieg gegen Ferdi | Gegengift-Gurgler, Heiliges Schlabbern, Stempelfarbe „Kopierblau“ |
| erster Sieg gegen den Grafen | Gräfliches Gutachten, Bellen in Stereo, Kartenrücken „Monokel“ |
| erster Sieg gegen Ulla | Leinen-Fallstrick, Kabelpeitsche, Tischunterlage „Umlaufmappe“ |
| erster Sieg gegen den Stempelmeister | Großer Amtsstempel, **Titel „Stempelmeister:in“**, Stempelfarbe „Gold“ |
| je 3 Siege (Stempelheft) | nächste Karte der festen Reihenfolge (Kap. 2.5), danach Kosmetik: Kartenrücken „Wartemarke“, „Rohrpost“, „Durchsage“, Tischunterlage „Gummibaum“ |
| Kampagne | Karten aus Fähigkeiten, Gegenständen, Talenten (Kap. 2.5) |
| Album vollständig | Titel „Vollständige Akte“, Kartenrücken „Goldschnitt“ |

**Dienstauszeichnungen** (Konto-Erfolge des Mini-Spiels, nur Kosmetik, getrennt von den 35 Kampagnen-Achievements, die
Lootboxen geben):

| ID | Name | Bedingung |
|---|---|---|
| `sda_tutorial` | Eingearbeitet | Lernduell beendet |
| `sda_first_win` | Erster Bescheid | erstes Duell gewonnen |
| `sda_chain` | Dreimal ich | dreimal hintereinander dran |
| `sda_no_file` | Ohne Ablage | gewonnen, ohne abzuheften |
| `sda_close` | Haarscharf bewilligt | mit höchstens 3 Geduld gewonnen |
| `sda_show_5` | Showtalent | 5 Show-Karten geglückt (insgesamt) |
| `sda_termin` | Termin, Termin, Termin | 3 Wiedervorlagen in einem Duell |
| `sda_durchsage` | Gut zugehört | eine Durchsage abgeheftet |
| `sda_amt` | Dienstweg komplett | Ferdi, Ulla und den Stempelmeister besiegt |
| `sda_graf` | Fußnote gelesen | den Grafen im Übungsduell besiegt |

### 5.3 Spielstand und Staffel (nur Etage 8)

| Gegner | Erster Sieg in dieser Staffel | Anzeige |
|---|---|---|
| Ferdi | **+10 Follower** („Der Chat hat zugesehen. Zehn Leute fanden Papier spannend.“) | Ergebnis-Panel, Toast |
| Ulla | **+15 Follower** | dto. |
| Stempelmeister | **+25 Follower** | dto., M.O.D. `sd_season_win` |
| Graf, KI-Kandidat:innen | — | — |

- **Höchstens 50 Follower** je Staffel aus dem Stempelduell — reine Show-Währung wie eine Regie-Notiz (+15, 06 §2.7) und wie
  die Wett-Follower (06 §4.8 Nr. 6); in Staffeln ohne Zuschauer-Geschenke (09 Kap. 10 Nr. 3) wirken Follower nur auf die
  Staffel-Quote (≈ +5). Bewusst **keine Credits und kein Fanpost-Paket** (Kap. 5.1, Review 2026-10-11) — damit entfällt auch
  jede Skalierung mit der Etage.
- Die Belohnung ist ein aufgezeichneter Command (`sd`, Kap. 6.8) — Spiel, `RunSim` und `Game.replay_log` rechnen sie gleich.
- Wer Etage 8 verpasst (Einsturz, Vorlauf), verliert nur diese kleine Belohnung; das Freie Spiel bleibt.
- **Ohne Staffel** gibt es Etage 8 nicht (die Kampagne wird zur privaten Staffel, 09 S-14); Event-Läufe haben kein Duell.

### 5.4 Was es nie gibt

Kampfwerte, Ausrüstung, Verbrauchsgüter, Credits, Boxen oder EP aus dem Duell; Boni der NOVA-Sammelkarten (06 §2.7) — die
**Stempelkarten sind eine eigene Sammlung** ohne Wirkung außerhalb des Mini-Spiels; Echtgeld, Zufallsinhalte, Einsätze;
Ranglisten mit Druck; Tagesbelohnungen, Serien („Streaks“), ablaufende Angebote.

### 5.5 Wohlbefinden

- Kein Grund, täglich zu spielen; nichts verfällt; Etage 8 belohnt einmal je Staffel und bleibt bis zum Einsturz.
- Ein Duell dauert 2–4 Minuten, ist jederzeit abbrechbar (gilt als aufgegeben, kostet nichts) und hat keine Uhr.
- M.O.D. spottet nie über Verlierer:innen; nach zwei Niederlagen in Folge bietet der Graf von sich aus einen Tipp zur Mappe an
  („Fußnote 14: Ulla ist für Stempel nicht zuständig. Ich sage das mit Liebe.“).
- Im Safe Room ist man sicher; ein Duell kostet keine Etagenzeit (Am Stück) und hält den Einsturz kurz auf (Kalender).

---

## 6. Technik

### 6.1 Was die Engine heute ist (Stand `62a6a95`)

| Teil | Dateien | Zeilen | Nach 07 R5b ohne dieses Dokument |
|---|---|---|---|
| CTB-Engine | `core/battle/{ctb_queue,battle_state,action_resolver,enemy_ai,auto_policy}.gd` | ≈ 2 300 | gelöscht |
| geteilte Basisklassen | `core/battle/{action_event,battle_setup,battle_result,battle_command,combatant,status_effect,hit_result,damage_calc}.gd`, `core/stats/*` | ≈ 1 350 | bleiben (07 §12.7, auch der Echtzeitkampf nutzt sie) — `battle_command.gd` steht in 07 §12.6 Schritt 3 zwar auf der Löschliste, aber `BattleCommand.Kind` ist das Vokabular von `ActionEvent.command` in `core/rt`, `core/show` und `scenes/combat` (CR-34) |
| Beuteregel | `BattleState.roll_drops` (die einzige Siegbeute-Regel, GDD §3.12) | — | wird von `core/rt/rt_result.gd` mitbenutzt — darf mit der Engine weder gelöscht noch umgezogen werden (SD1 Schritt 0) |
| Engine-Tests | `tests/test_m1_{fixture,stats,ctb,damage,status,ai,battle_flow,battle_snapshot}.gd` (≈ 86 Testfälle, eigener Mini-Datensatz, **unabhängig von `res://data`**) | ≈ 2 770 | ersetzt durch Echtzeit-Varianten |
| Hash | `StateHash.of_battle` / `battle_hash_input` (`core/live/state_hash.gd`) | — | gelöscht |
| Konstanten | `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN` | — | gelöscht |
| Datenfelder | CTB-Felder in `SkillDef`/`StatusDef`/`EnemyDef` und ihre Validator-Regeln (07 §4.11: `rank`, `cooldown`, `fail_effect.delay_pct`, `default_turns`, `tick_timing`, `tick_speed_mult`, `delay_on_apply`, `ai`/`phases[].actions`, `pseudo_units`) | — | gelöscht |
| CTB-Darstellung | `scenes/battle/**` (Bühne, Kamera, Player, HUD, Ergebnis) | ≈ 6 100 | gelöscht — **bleibt gelöscht** (Kap. 4.1) |

**Stand nach SD1 (07 R5b-2b):** die Engine in `core/stempel/ctb/` (Code unverändert bis auf das Herauslösen von
`roll_drops`); die geteilten Basisklassen in `core/battle` wie oben, `battle_command.gd` dabei; die Beuteregel
`BattleResult.roll_drops`; `test_m1_*` bleiben (dazu `test_sd_engine_golden`, `test_sd_boundaries`); `StateHash.of_battle`/
`battle_hash_input` und die Konstanten (Abschnitt „Stempelduell-Engine (10, SD1)“ in `Balance`) bleiben; die CTB-Felder
stehen in den Defs und als optionale Felder im Validator, die Kampagnen-Daten tragen sie nicht mehr; `scenes/battle/**` ist
gelöscht.

### 6.2 SD1: Extraktion aus der Kampagne (in 07 R5b)

07 §12.6 legt nach erfüllter Parität vier Commits fest: (1) Standard `realtime`, (2) **Daten backen** (HP × 4, `SaveCodec`
v2), (3) **CTB löschen**, (4) Doku. SD1 ersetzt Schritt 3 durch **Umziehen statt Löschen**; Schritte 1, 2 und 4 bleiben, wie
sie sind — die Kampagne wird vollständig echtzeitig, nur die Engine lebt als Mini-Spiel-Kern weiter.

| # | Schritt 3 neu (je ein Commit, in dieser Reihenfolge) | Prüfung |
|---|---|---|
| 0 | **Beuteregel herauslösen:** `BattleState.roll_drops` zieht unverändert nach `BattleResult.roll_drops` (geteilt und rein, `core/battle`; beide Kampfarten bauen ihr Ergebnis ohnehin mit `BattleResult` — `LootRoller` hinge am `GameState` und wäre eine Schicht zu hoch); `BattleState._build_result`, `core/rt/rt_result.gd`, `test_r1_rt_result` und `test_m2_loot` rufen sie dort auf. Nötig auch ohne dieses Dokument — 07s Löschliste bräche sonst den Echtzeitkampf | `test_m2_loot`, `test_r1_rt_result`, alle `test_m1_*` grün |
| 1 | `git mv core/battle/{ctb_queue,battle_state,action_resolver,enemy_ai,auto_policy}.gd core/stempel/ctb/` — **fünf** Dateien, **Klassennamen bleiben** (`BattleState`, `CTBQueue`, …), Verhalten bitgleich (keine `preload`-Pfade und keine `.uid`-Dateien betroffen, Stand heute). `battle_command.gd` **bleibt** in `core/battle` (geteilt, Kap. 6.1). `test_m1_stats` prüft im Ganzzahl-Lint die Ordner `core/stats` und `core/battle` und erwartet mehr als 15 Dateien — er bekommt `res://core/stempel/ctb` als dritten Ordner (eine Zeile) | `test_m0_compile_all`, alle `test_m1_*` grün |
| 2 | **Bleiben statt löschen:** `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN` (Abschnitt „# --- Stempelduell-Engine (10, SD1) ---“), `StateHash.of_battle`/`battle_hash_input`, die CTB-Felder in den Defs (samt `PseudoUnitDef` und der Tabelle `pseudo_units` in `GameData`), die optionalen Feld-Spezifikationen in `data_validator.gd` (dritter Vertrags-Durchgang, ohnehin mit R5b/ST0) **und die CTB-Laufzeitfelder der geteilten Klassen** (`Combatant.ctb_counter`, `defending`, `stunt_cooldown`, `used_once`, `own_turns`, `warned`, `pseudo_def`; `StatusEffect.turns_left`/`fresh`; die CTB-Typen von `ActionEvent`) | `test_m8_state_hash` (CTB-Teil), `test_m1_battle_snapshot` |
| 3 | **Kampagnendaten** verlieren die CTB-Felder wie geplant (gebacken, 07 §4.11 Spalte „Ab R5b“) — die Felder sind danach nur noch im **Regelbuch** des Stempelduells belegt | `test_r4_rt_data`, Validator grün |
| 4 | **Wie in 07 §12.6 gelöscht bzw. mit R5b überflüssig:** `scenes/battle/**`, `Router.start_battle`/`end_battle` + Swirl, `Events.battle_turn_started`, CTB-Pfade der Kampagne (`BattleBridge.make_setup`, CTB-Zweige in `RunSim`/`GameReplay`, `Show.take_pending_gift(battle)`/`_battle_party`), `ShowRules`-Profil `ctb`, `GameSettings.battle_speed`/`auto_battle_default`/`partner_auto`, CTB-Teile **aller** Kampagnen-Tests — 07 nennt `test_m5_*`, `test_m8_replay`, `test_m8_run_sim`, `test_06b/06c_balance`; heute nennen **27 weitere Dateien** unter `tests/` die Engine-Klassen im Code (u. a. `test_06a_hero`, `test_06b_talents`, `test_06c_*`, `test_08_*`, `test_m0_game`, `test_m2_*`, `test_m7_*`, `test_m8_command`/`gift_applier`/`integrity`/`receive_gift`/`sponsor_windows`, `capture_recipes.gd`; Liste per `grep -rlw` über die fünf Klassennamen). Nach dem Datenbacken prüfen sie ohnehin nichts Gültiges mehr | wie 07 §12.6 |
| 5 | **Neu:** `tests/test_sd_engine_golden.gd` (fester Kampf aus dem `test_m1`-Mini-Datensatz mit geskripteten Befehlen → eingefrorener `StateHash.of_battle` und Ereigniszahl; übernimmt den CTB-Teil von `test_m8_state_hash`) und `tests/test_sd_boundaries.gd` (Kap. 6.3: außer dem Stempelduell und seinen Tests nennt kein Code mehr die fünf Engine-Klassen) | beide grün |
| 6 | **Optional im selben Durchgang (ST0):** Command-Typ `sd` als Stub in `core/live/command.gd` mit Ablehnung `sd_unavailable` in `RunRules`/`RunSim`/`GameReplay` — spart SD3 einen eigenen Vertrags-Durchgang (Kap. 6.8, CR-36) | `test_m8_command` (jeder Typ hat einen Zweig) |

**Umgesetzt (07 R5b-2b, 2026-10-12, Branch `ptd/r5b2b`):** Zeile 0 `48eac82`, Zeile 1 `78efb98`, Zeile 2 `585188b`,
Zeile 4 `dcccac0`, Zeile 3 `8d4cee4`, Zeile 5 `04fbda5`; davor die 07-Schritte 1–2 (Standard `realtime` seit R5b-2a, Daten
backen `0aaf01b`, `SaveCodec` v2 `21fe9ab`). Abweichungen und Auslegungen:

- **(a) Zeile 4 vor Zeile 3:** Die CTB-Pfade und -Tests der Kampagne lasen die CTB-Felder der Daten, solange es sie gab; in
  dieser Reihenfolge blieb jeder Commit grün.
- **(b) Zeile 2:** Der `Balance`-Abschnitt „Stempelduell-Engine (10, SD1)“ sammelt alle Konstanten, die nur die Engine liest
  — neben `FLEE_*`, `DEFEND_MULT` und `STUNT_COOLDOWN` auch die MP des Verteidigens, `TAUNT_CHANCE`, `STUN_BOSS_MULT` und
  `SUMMON_CTR_FRAC` (Werte unverändert).
- **(c) Zeile 3:** Mit den Feldern gingen `learnset` in `party.json`/`classes.json` (die Leiste ist `rt.bar`, 07 §5.1), die
  drei Skills, die nur die CTB-KI der Etage-2-Platzhalter nannte (`skl_e_pose`, `skl_e_ram`, `skl_e_price_slam`), und die
  M.O.D.-Zeilen der CTB-Haken (`tutorial_stunt`, `boss_train_warning`); `PartyMember.skills` wird für ein neues Spiel nicht
  mehr gefüllt (gespeicherte Listen laden weiter). Die Achievements tragen ihre Echtzeit-Schwellen in `condition`/`desc`.
- **(d) Zeile 4:** Mit der CTB-Kampfszene gingen auch der Run-Log-Befehl `battle` (eine Begegnung braucht ihren `rt`-Block),
  die Boot-Argumente `--combat=` und `--goto=battle:` und die Laufzeit-Rückstellung von Tab/Y (07 E36). Zwei Shims halten den
  unerreichbaren CTB-Zweig von `scenes/exploration/exploration.gd` übersetzbar (dort nicht angefasst): `Game.make_battle_setup`
  liefert `null`, `Router.start_battle` tut nichts — beide nennen keine Engine-Klasse.
- **(e) Zeile 5:** Der Golden-Test friert **zwei** Kämpfe ein: einen regulären (verloren nach 35 Befehlen: Diebstahl und
  Flucht, Heilungen, Wiederbelebung, Stunts, Verteidigen) und die Königin als Boss (gewonnen nach 32: Phasenwechsel,
  Beschwörungen, der Zug als Pseudo-Einheit) — `StateHash.of_battle`, Ereigniszahl, Prüfsumme des Ereignisstroms und
  Ausgang. `test_sd_boundaries` prüft zusätzlich, dass ein alter CTB-Kampagnen-Log „ältere Version“ ist (Fixture
  `run_log_sim_v3_ctb.json`, aufgenommen von `2246c31`).
- **(f) Zeile 6** nicht in diesem Durchgang (ST0 bzw. SD3, CR-36).

Die fünf Engine-Dateien sind bis auf das Herauslösen von `roll_drops` unverändert; `test_m1_*` behalten Namen und Inhalt
(nur die Ordner-Zeile in `test_m1_stats`).

**Ergebnis:** Die Kampagne ist echtzeitig und CTB-frei (der Grenztest erzwingt es), die Engine ist mit allen ihren Tests
erhalten, und der Goldwert hält sie eingefroren: Eine spätere Änderung an geteilten Klassen (`Combatant`, `DamageCalc`,
`ActionEvent` …), die das CTB-Verhalten verschiebt, lässt `test_sd_engine_golden` scheitern — dann braucht es einen
Änderungsantrag und einen `SD_VERSION`-Sprung (Kap. 6.6). Aufwand ≈ 1–2 Personentage **zusätzlich** zu R5b Schritt 3 — das
Ersetzen der CTB-Teile der Kampagnen-Tests (Zeile 4) schuldet R5b ohnehin, ob gelöscht oder umgezogen wird.

**Warum die Testnamen bleiben:** `test_m1_*` behält Namen und Inhalt (einzige Ausnahme: die eine Ordner-Zeile in
`test_m1_stats`); der Eigentümer wechselt von „M1 (Kampf-Kern)“ zu „SD“. Nach R5b gibt es keinen anderen M1-Kern mehr (der
Echtzeitkern testet als `test_r1_*`), die Namen sind also eindeutig, und Umbenennen brächte nur Unruhe in Verweise.

### 6.3 Module und Schichten

```text
core/stempel/                       Modul SD (rein, RefCounted, keine Autoloads, kein SceneTree, keine Uhr)
  ctb/ctb_queue.gd                  CTBQueue        ┐
  ctb/battle_state.gd               BattleState     │ die CTB-Engine (SD1: umgezogen, Verhalten bitgleich;
  ctb/action_resolver.gd            ActionResolver  │ BattleCommand bleibt geteilt in core/battle)
  ctb/enemy_ai.gd                   EnemyAI         │
  ctb/auto_policy.gd                AutoPolicy      ┘
  sd_rulebook.gd                    SdRulebook      Regelbuch laden/prüfen, Engine-GameData bauen, rules_hash
  sd_card_def.gd, sd_opponent_def.gd SdCardDef, SdOpponentDef
  sd_setup.gd, sd_duel.gd, sd_event.gd  SdSetup, SdDuel (Adapter um BattleState), SdEvent
  sd_ai.gd                          SdAi            Tipp/Auto (suggest), Ablegewahl beim Abheften
  sd_log.gd                         SdLog           Duell-Log, Replay, version_status
  sd_collection.gd                  SdCollection    Konto-Sammlung (Besitz, Mappen, Stempelheft, Kosmetik)
  sd_rules.gd                       SdRules         Kampagnen-Anbindung (Command sd, Belohnung) — SD3
  validators/sd_validator.gd        (privat)        Schema, Referenzen, Deckregeln, Texte (ip_words), Zeilen
data/stempel/                       cards.json, opponents.json, rules.json, lines.json, cosmetics.json, awards.json
scenes/stempel/                     stempel_hall.tscn/.gd (Schalterhalle), sd_table.tscn/.gd (Duell), sd_board.gd
                                    (Wartenummern), sd_card_view.gd, sd_hand.gd, sd_plate.gd, sd_host.gd (Ansager),
                                    sd_tutorial.gd, sd_deck_builder.tscn/.gd, sd_album.tscn/.gd, sd_results.gd,
                                    sd_icons.gd, sd_style.gd (privat, ohne class_name)
scenes/title/extras_menu.tscn/.gd   Untermenü „Extras“
tests/test_sd_*.gd                  Kap. 6.9
```

**Schichtregel** (ergänzt 02_TECH §0.4): `core/data`, `core/stats`, `core/battle` (geteilt) ← `core/stempel/ctb` ←
`core/stempel` ← `scenes/stempel`. `core/stempel` darf außerdem `SeedUtil`, `CanonicalJson`, `StateHash` und `FixedMath`
nutzen; `core/live` (`RunRules`, `RunSim`) und `autoload/game.gd`/`game_replay.gd` dürfen **nur `SdRules`** aufrufen.
Einzige Ausnahme ist `core/live/state_hash.gd`, das `of_battle`/`battle_hash_input` behält (Kap. 6.2). `test_sd_boundaries`
prüft per Textsuche über **Code-Zeilen ohne Kommentare** (heute erwähnen u. a. `gift.gd`, `gift_applier.gd`, `talents.gd`
und `rt_gift.gd` die Engine in Kommentaren), dass die fünf Engine-Klassen außerhalb von `core/stempel/**`,
`scenes/stempel/**`, `core/live/state_hash.gd`, `tests/test_m1_*` und `tests/test_sd_*` nicht vorkommen. Grün wird er erst nach
SD1 Schritt 0 und 4 (Kap. 6.2) — grün seit 07 R5b-2b.

### 6.4 Regelbuch: Daten → Engine

`SdRulebook.load_dir("res://data/stempel")` liest die Dateien, prüft sie mit `validators/sd_validator.gd` und baut die
**Engine-Daten** über die vorhandene Schnittstelle `GameData.load_from_dicts` (02_TECH §4.5; dieselbe, mit der die
`test_m1`-Tests ihren Mini-Datensatz laden):

| Regelbuch | Engine-Tabelle | Umwandlung |
|---|---|---|
| Karte `sdc_x` | `skills` → `skl_sdc_x` | `skill`-Block; `name` = die ID (Anzeigenamen nur aus dem Regelbuch); `user "any"` (beide Seiten), `mp_cost 0`; Heilkarten mit Ziel `single_ally` (1 gegen 1 = man selbst — so erkennt `AutoPolicy` sie als Heilung), Eilvermerke und Umlaufmappe mit `self` |
| Grundangriff | `skills` → `skl_sd_none` | **formal gültiger Grundangriff**: `category "attack"`, `damage_type`/`element "physical"`, `target "single_enemy"`, `power 100`, `rank 3` — sonst lehnt `DataValidator._check_attack_skill` (Regeln 5/6, laufen auch in `load_from_dicts`) jeden Gegner ab. `attack_skill` beider Seiten, **wird nie ausgeführt**: Das Duell macht aus `ATTACK` immer Abheften |
| Zustand `sts_sd_*` | `statuses` | wie GDD §3.9 (`delay_on_apply`, `tick_speed_mult`; Kleingedrucktes `tick_pct −1` + `tick_min 2` = fest 2) |
| Gegner `sdo_x` | `enemies` → `enm_sdo_x` | `name` = die ID; `stats {hp: geduld, spd: 10, str/mag/def/res: 1, mp/lck: 0}`, `element_mods`, `status_immune`, `ai` (Phasen-Gegner: `ai.type "phased"` + `phases[].actions`), `phases`; **`boss` immer `false`** (SD-14); Pflichtfelder (`model`, `explore`, `exp 0`, `credits 0`) füllt der Konverter |
| Durchsage | `pseudo_units` → `pu_sd_durchsage` | `{"fixed_pct_maxhp": 8, "element": "none", "target": "all_party"}`, `ctr_after 100`, `warn_at 2`, `warn_tag "sd_durchsage_warn"` |

- **Kein Kampagnen-`DB`:** Die Engine-Daten sind eine eigene `GameData`-Instanz; das Regelbuch liegt in einem
  **Unterordner**, `DB.data_hash()` liest nur `res://data/*.json` — Kartenänderungen verschieben also keine Kampagnen-Hashes.
- **Regeln 7–9** des `DataValidator` (Inhaltsmengen, Zeilen-Pflicht) laufen bei `load_from_dicts` nicht; ihre Entsprechungen
  prüft `sd_validator.gd`: jede `say`-/`warn_tag`-Referenz hat eine Zeile in `lines.json`, jedes Gegnerdeck erfüllt die
  Deckregeln, Karten-IDs und Freischaltquellen existieren (Kampagnen-IDs gegen `DB`), Texte bestehen `ip_words.gd`, Zeilen
  ≤ 110 Zeichen.
- **`rules_hash`** = SHA-256 über `CanonicalJson` der **Mechanik** (`skill`-Blöcke, Gegnerwerte, Decks, `ai`, `phases`,
  Zustände, Pseudo-Einheit, Konstanten aus `rules.json`) plus `SdDuel.SD_VERSION` — **ohne** Namen, Sprüche, Zeilen und
  Kosmetik, damit Textkorrekturen keine Replays ungültig machen. Aus demselben Grund trägt die Engine IDs statt Namen:
  `StateHash.battle_hash_input` lässt nur die Namen der Party weg, der `display_name` des Gegenübers stünde sonst im
  Duell-Hash.
- **Prototyp (Review 2026-10-11):** So umgewandelt lädt das ganze Regelbuch (24 Karten, 4 Gegner, 4 Zustände, Durchsage)
  über `load_from_dicts` ohne Fehler und ohne Warnung.
- **Umgesetzt (SD2-A):** wie in der Tabelle, dazu der Lernduell-Gegner `enm_sd_lernduell` (U-9). `SdRulebook.load_dir()`
  sammelt alle Fehler (Validator, dann `load_from_dicts`) in `errors`; nur ein fehlerfreies Regelbuch hat einen `rules_hash`
  (Umfang: U-3). `SdRulebook.shared()` lädt einmal je Sitzung; mit der Kampagnen-`GameData` prüft `load_dir(dir, DB.data)`
  bzw. `campaign_problems()` zusätzlich die Kampagnen-IDs der Freischaltungen (in `test_sd_rulebook` gegen die echten Daten).

### 6.5 `SdDuel`: der Adapter um `BattleState`

```gdscript
class_name SdDuel extends RefCounted
## One Stempelduell (10 §1): an unchanged BattleState (CTB engine) plus decks, hands and discard piles. Deterministic:
## same SdSetup + same moves → same events and the same hash(). No autoloads, no SceneTree, no clock.
const SD_VERSION: int = 1
const DECK_SIZE: int = 20
const HAND_SIZE: int = 5
const DIENSTSCHLUSS: int = 80                       # last ticket number (BattleState.turn_count)
enum Side { PLAYER, OPPONENT }
enum Result { RUNNING, WON, LOST, ADJOURNED, FORFEIT }
var setup: SdSetup                                  # seed, opponent_id, player_deck, tutorial, rules_hash
var battle: BattleState
var decks: Array[PackedStringArray] = []            # [player, opponent], index 0 = top of the pile
var hands: Array[PackedStringArray] = []
var discards: Array[PackedStringArray] = []
var shuffles: PackedInt32Array = [0, 0]             # per side; RNG stream "sd_deck"
var result: SdDuel.Result = Result.RUNNING
func _init(p_setup: SdSetup, p_book: SdRulebook) -> void
func start() -> Array[SdEvent]                      # shuffle + draw 5 each, then battle.start()
func side_to_move() -> int                          # Side of battle.current_actor(), -1 when finished
func legal_moves() -> Array[Dictionary]             # {"op": "play" | "file", "slot": 0..4}; "forfeit" always (player)
func validate(move: Dictionary) -> String           # "" or reason (English, for logs)
func preview(move: Dictionary) -> Dictionary        # pure dry run on a copy: {"order", "deltas"}; show cards: {}
func submit(move: Dictionary) -> Array[SdEvent]     # the side to move (player input, AI move or auto move)
func ai_move() -> Dictionary                        # opponent: EnemyAI on the synced hand; player: SdAi.suggest
func is_finished() -> bool
func to_dict() -> Dictionary                        # float-free snapshot incl. battle.to_dict()
static func from_dict(d: Dictionary, p_book: SdRulebook) -> SdDuel
func hash() -> String                               # SHA-256 over {"b": StateHash.battle_hash_input(battle), "sd": …}
```

**Umgesetzt (SD2-B) — Abweichungen von der Skizze:** `hash()` heißt `state_hash()` (02_TECH §13.1: kein Name einer
eingebauten Funktion); Deckgröße, Hand, Kopien, Geduld, Tempo und Dienstschluss sind keine Konstanten der Klasse, sondern
stehen in `rules.json → constants` (`book.constant("dienstschluss")`, im `rules_hash`, U-1). `start()` startet nur ein
Setup ohne `SdSetup.problem()` (anderer `rules_hash`, unbekannter Gegner, Deckregeln). `preview(move)` liefert
`{"order", "geduld", "delta", "weak", "resist", "immune", "blocked", "ends"}` — `order` sind die nächsten 12 Nummern als
Combatant-IDs vom Ziehenden an (alles hinter der nächsten Nummer des Gegenübers ist Prognose), `blocked` die Zustände, die
nicht greifen (Wiedervorlage „nicht doppelt“, Immunität); Show-Karten, Aufgeben und illegale Züge: `{}`. `ai_move()` gibt
es, dazu getrennt `opponent_move()` (EnemyAI auf der Hand, Notlösung U-8) und `auto_policy_move()` (Harness „einfach“).
Lesezugriff für Tisch und Ansager: `ticket()` (JETZT-Nummer = `turn_count`), `order(n)`, `side_of(id)`, `combatant(side)`,
`geduld`/`max_geduld(side)`, `hand(side)`, `chain()` (Nummern in Folge), `dienstschluss_near()` (ab Nummer 60),
`forced_move()`/`lessons_now()` (Lernduell), `summary()` (Ergebnis-Panel, `SdCollection.record_duel`). Reihenfolge der
Ereignisse eines Zugs: U-5.

**So spricht das Duell mit der Engine** — ohne eine Zeile Engine-Code zu ändern:

1. **Aufbau:** `BattleSetup` mit `party = [Combatant "p0"]` (Geduld 50, SPD 10, `attack_skill "skl_sd_none"`, ohne
   PartyMemberDef, ohne Anzeigenamen), `enemy_ids = ["enm_sdo_x"]`, `seed`, `advantage` `NORMAL` (Lernduell `PREEMPTIVE`),
   `tutorial`, `enemy_dmg_mult` (Lernduell 0,5), `can_flee false`, `items {}`. Danach mischt das Duell beide Decks
   (Fisher-Yates mit `SeedUtil.derive(seed, "sd_deck", Seite × 1000 + k)`, nur `randi_range`), zieht je 5 und ruft
   `battle.start()`.
2. **Hand = Fähigkeitenliste:** Vor jeder Prüfung und jeder KI-Wahl setzt das Duell beim Akteur `skills` = die Nicht-Show-
   Karten seiner Hand (als `skl_sdc_*`, ohne Doppelte) und `stunts` = die Show-Karten. `available_commands`, `validate` und
   `EnemyAI` (das nur `usable_skills` zieht) sehen dadurch genau die Hand. Beide Listen sind Teil des Combatant-Snapshots.
3. **Zug:** `play slot i` → `BattleCommand.skill`/`stunt` mit automatischem Ziel (Gegenüber bzw. man selbst) →
   `battle.submit()`; `file slot i` → `BattleCommand.defend`. Danach Karte auf die Ablage, nachziehen (leerer Stapel →
   Ablage mischen), bei der Umlaufmappe Hand tauschen; dann Dienstschluss prüfen.
4. **KI:** Für das Gegenüber liefert `battle.choose_ai_command()` die Wahl; `ATTACK` (die Notlösung von `EnemyAI`) wird zu
   `file` mit der Karte des kleinsten Gewichts. Für die Spieler:in (Auto, Tipp, Harness) liefert `SdAi.suggest` den Zug,
   im Harness-Profil „einfach“ `AutoPolicy`.
5. **Vorschau:** `preview` macht einen Probelauf auf `BattleState.from_dict(battle.to_dict(), data)` (CR-14-Schnappschuss, das
   Weiterspielen ist bitgleich) und liest `preview_order` und die Geduld-Änderungen; die Kopie wird verworfen. Weil Ärger,
   Heilung und Zeit-Effekte keinen Würfel brauchen, verrät der Probelauf nichts — Show-Karten bekommen keinen Probelauf.
   `preview_order` setzt für jede noch nicht gespielte Karte Rang 3 an; die Anzeige behandelt alles hinter der nächsten
   Nummer des Gegenübers als Prognose (Kap. 1.2, 4.3). Prototyp: In 40 Duellen änderte kein Probelauf (einer je Zug der
   Spieler:in) `StateHash.of_battle`.
6. **Ereignisse:** `SdEvent.kind` ∈ `ENGINE` (verpackt ein `ActionEvent`), `CARD_PLAYED`, `CARD_FILED`, `CARD_DRAWN` (beim
   Gegenüber ohne Karten-ID), `RESHUFFLED`, `HAND_REFRESHED`, `DUEL_END`. Die Darstellung spielt nur Ereignisse ab
   (Brief §6b.2) und liest den Zustand erst danach.
7. **Ende:** `battle.is_finished()` (Geduld 0) → `WON`/`LOST`; Nummer 80 erreicht → `ADJOURNED` (Dienstschluss, Kap. 1.8);
   `forfeit` → `FORFEIT`.

Das Duell sendet **keine** Kampf-Signale (`battle_started`, `battle_ended`, `combat_*`) — Show, Achievements, Musik und
Marotten der Kampagne merken vom Duell nichts.

### 6.6 Determinismus und Replay

- **Regeln für `core/stempel/**`** wie für `core/**` (Brief §6b, 05 §3.3): nur Ganzzahlen, kein globaler Zufall, keine Uhr;
  `test_m8_no_global_rng` deckt den Ordner automatisch ab.
- **Zufallsströme:** Engine `ctb` (Startnummern), `action` (je Zug; Show-Würfel), `ai` (Gegnerwahl); Duell `sd_deck`
  (Mischen). Tipp, Auto, Ablegewahl und Vorschau würfeln nicht. Neue Seed-Zwecke in `SeedUtil`: `sd`, `sd_deck`.
- **Seed eines Duells:** im Freien Spiel `SeedUtil.derive(collection.seed, "sd", collection.n)` (Konto-Seed einmal zufällig
  erzeugt, Zähler vor dem Duell gespeichert); auf Etage 8 `RunRules.next_seed(state, "sd")` beim `start` (Kap. 6.8). Ein
  Neustart würfelt also nie dasselbe Duell neu, um in die Karten zu schauen.
- **Duell-Log (`SdLog`):** nur die Eingaben der Spieler:in — die KI wird beim Nachspielen neu gerechnet (wie im CTB, 05 CR-2).

```json
{"v": 1, "sd_version": 1, "rh": "<rules_hash>", "seed": "1234567", "opp": "sdo_ulla", "tut": false,
 "deck": ["sdc_stempel", "sdc_stempel", "…20 Karten…"],
 "moves": [{"op": "play", "slot": 2}, {"op": "file", "slot": 4}, {"op": "play", "slot": 0, "a": true}],
 "res": "won"}
```

  `a: true` markiert Auto-Züge (nur Statistik). Namen, Persona und Kosmetik stehen nie im Log.
- **Replay:** `SdLog.replay(book) -> {"ok", "hash", "result", "error", "mismatch_at"}` spielt bitgenau nach; ein Zug, der
  nicht legal ist, oder ein anderes Ergebnis als `res` ist ein Fehler.
  **Umgesetzt (SD2-B)** mit dem zusätzlichen Feld `"h"` = `state_hash()` am Ende: `replay` erkennt damit auch einen
  gefälschten Zug, der das Ergebnis nicht ändert (ohne `"h"` prüft es nur das Ergebnis). Ebenfalls Fehler: Züge nach dem
  Ende, ein Log, das vor dem Ende aufhört, und ein Setup mit Problem (`bad setup`, z. B. 3 × Großer Amtsstempel). Das Ergebnis
  trägt zusätzlich `"version"`.
- **Versionen:** `SdLog.version_status(log)` → `ok` | `old_version` | `new_version` | `other_rules` (anderer `rules_hash`).
  Logs einer anderen Version spielt der Kern nicht ab und zeigt sie als „ältere Version“ (wie `RunSim.version_status`).
  `SD_VERSION` steigt, wenn sich das Ergebnis eines Duells ändern kann (Duell-Regeln, umgezogene Engine, geteilte Klassen);
  in Staffeln nur zu Sendeterminen (09 V-1).
- **Schnappschuss und Hash:** `SdDuel.to_dict()` ist float-frei (Engine: `*_ppm`, RNG-Zustände als Dezimal-Strings);
  `SdDuel.hash()` nutzt `StateHash.battle_hash_input` (ohne Anzeigenamen, 08 CR-20) plus Decks, Hände, Ablagen, Misch-Zähler
  und Ergebnis.

### 6.7 Speichern

| Was | Wo | Inhalt | Wann |
|---|---|---|---|
| **Konto-Sammlung** | `user://stempel/collection.json` über einen neuen Abschnitt in `autoload/save.gd` (`load_sd_collection()`, `save_sd_collection(d)`, atomar über `_atomic_write`) | `{"v": 1, "seed", "n", "owned": [IDs], "decks": {"a": [20], "b": [], "c": []}, "active": "a", "beaten": {opp: Siege}, "heft": int, "cosmetics": {"back", "ink", "mat", "owned"}, "awards": [IDs], "options": {"speed", "reduce_motion", "hints", "open_hand", "left_handed", "text_size"}, "tutorial": bool, "campaign_seen": [Quell-IDs]}` | vor jedem Duell (Seed-Zähler), nach jedem Duell, nach jeder Mappen- oder Kosmetik-Änderung |
| **Staffel** (SD3) | `GameState.flags["sd"]` im Spielstand (Save v2, keine Formatänderung) | `{"open": {"opp", "seed", "deck"}, "won": [opp-IDs]}` | wie jeder aufgezeichnete Command (09 Kap. 9.1: Journal, Speichern nach Kampf/Safe Room) |
| Duell-Logs | optional `user://stempel/replays/` (letzte 10) | `SdLog` | nur für Fehlerberichte und eine spätere „Wiederholung“ |

- **Kaputte Datei:** wie bei den Bestenlisten → leere Sammlung mit Toast „Stempelakte neu angelegt“; die Grundakte kommt
  über „Lernduell“ wieder (Kampagnen-Freischaltungen werden beim nächsten Öffnen neu gelesen).
- **Umgesetzt (SD2-B)** als reines `SdCollection.to_dict()`/`from_dict(v, book)`; die Datei schreibt erst der Abschnitt in
  `autoload/save.gd` (nicht Teil von SD2-A/B). Abweichungen vom Format oben: `cosmetics` hat auch den Platz `title`; neu
  `"stats": {"duels", "wins", "show_ok", "loss_streak"}` (Showtalent zählt über alle Duelle, der Mappen-Tipp nach zwei
  Niederlagen, Kap. 5.5); `seed` als Dezimal-String. Unbekannte IDs fallen beim Laden weg; kein Objekt, eine andere Version
  oder falsche Listentypen → leere Sammlung mit `was_reset = true` (der Bildschirm zeigt den Toast). Den Konto-Seed würfelt
  der Aufrufer einmal (`SdCollection.create(seed)`), der Kern hat keinen Zufall.
- **Privatsphäre:** Die Sammlung enthält nur Katalog-IDs und Zahlen — keine Namen, keine Persona-Angaben (08 P-1, D-2);
  „Kandidat:in löschen“ (08) lässt sie unberührt. Geräteübergreifend erst mit dem Konto-Dienst (F-10).
- **Kein Speichern im Duell:** Ein Spielstand enthält nie ein laufendes Duell; im Freien Spiel ist ein abgebrochenes Duell
  einfach vorbei (der Seed-Zähler ist schon weiter).

### 6.8 Kampagnen-Anbindung (SD3): Command `sd`

Auf Etage 8 berührt das Duell den Spielstand (Belohnung), also läuft es über **einen aufgezeichneten Command** mit zwei
Operationen — das Muster von `encounter` (07 §10.5):

```json
{"t": "sd", "v": 1, "op": "start", "opp": "sdo_ulla", "deck": ["…20 Karten…"], "rh": "<rules_hash>"}
{"t": "sd", "v": 1, "op": "end", "moves": [{"op": "play", "slot": 2}], "res": "won"}
```

| Schritt | Regel (`SdRules`, rein, von `Game`, `RunSim` und `GameReplay` gleich aufgerufen) |
|---|---|
| `start` prüfen | Etage 8 mit Kulisse `thm_amt`, Ort Wartezimmer (Szenenlogik Grad A wie `secret`, 06 §2.7), kein offenes Duell, Gegner bekannt, Deck erfüllt die Deckregeln (der **Besitz** ist Konto-Sache und wird nicht geprüft), `rh` = aktueller `rules_hash` |
| `start` anwenden | `flags.sd.open = {opp, seed: RunRules.next_seed(state, "sd"), deck}` — der Seed ist verbraucht |
| `end` prüfen | ein Duell ist offen; das Nachspielen von `open` + `moves` ergibt `res` |
| `end` anwenden | `open` löschen; bei `won` und Gegner nicht in `flags.sd.won`: Belohnung (Kap. 5.3), Gegner eintragen |
| andere Commands | Ein offenes Duell schließt als **aufgegeben**, sobald ein **eigener** Command der Spieler:in kommt, der nicht `sd` ist (Raum wechseln, Safe Room verlassen, kaufen … — im Duell-Bildschirm unmöglich, also nur nach einem Abbruch), sowie am Replay-Ende (wie „ein anderer Command beendet den Kampf“, 07 §10.5). **Externe Eingänge** (`clock`, `gift`, `twist`, `sponsor_window`) lassen es offen. So endet ein Duell, das die App beim Absturz offen ließ, beim nächsten eigenen Command — ohne Haken im Journal (09 V-3) |
| Ablehnungsgründe | `sd_unavailable` (bis SD3), `not_floor_8`, `not_in_waiting_room`, `duel_open`, `no_duel`, `bad_deck`, `unknown_opponent`, `other_rules`, `result_mismatch` |

- **Das Duell hängt nicht vom Spielstand ab** (eigene Daten, eigener Seed, eigene Hände). Uhr, Geschenke und Twists wirken
  deshalb während eines offenen Duells wie in jedem Safe Room auf den Spielstand, ohne das Duell zu berühren; das Duell
  selbst kennt keine Geschenke. Staffeln sind ohnehin standardmäßig ohne Geschenke (09 Kap. 10 Nr. 3), und im ausgehängten
  Wartezimmer laufen keine Leerlauf-Ticks (02_TECH §9.2).
- **Einsturz:** Ist ein Duell offen, wartet ein fälliger Einsturz bis `end` plus 2 Minuten — dieselbe Regel wie nach einem
  Kampf (09 Kap. 2.5), in `SeasonRules` um „oder Duell“ ergänzt (CR-36).
- **Hash:** `flags.sd` ist Teil von `StateHash.of` (Flags werden gehasht) und erscheint erst mit dem ersten Duell — alte
  Golden-Hashes bleiben gleich.
- KI-Duelle (Kap. 3.8) nutzen denselben Command mit `"opp": "sdo_cast", "cast": <Platz>`; das Regelbuch baut das Gegenüber
  aus dem Profil des Platzes (`CastSim`, 09 Kap. 4.2), Name nur Anzeige.

### 6.9 Tests

| Test | Phase | Prüft |
|---|---|---|
| `test_m1_*` (8 Dateien) | SD1 (bleiben) | die Engine wie bisher: Tick-System, Vorschau, Formeln, Zustände, KI, Kampfablauf, Schnappschuss (`test_m1_stats`: Lint-Ordner + `core/stempel/ctb`) |
| `test_sd_engine_golden` | SD1 (umgesetzt) | zwei feste Engine-Kämpfe (regulär und Boss, Kap. 6.2 „Umgesetzt“ (e)) → eingefrorener `StateHash.of_battle`, Ereigniszahl, Prüfsumme der Ereignisse und Ausgang; zweimal gleich, Befehle über JSON nachgespielt (dazu der CTB-Teil aus `test_m8_state_hash`: Schnappschuss → `from_dict` → gleicher Hash); Änderung nur mit Begründung im Commit |
| `test_sd_boundaries` | SD1 (umgesetzt) | die fünf Engine-Klassen kommen in Code-Zeilen (ohne Kommentare) nur in `core/stempel/**`, `scenes/stempel/**`, `core/live/state_hash.gd` und den SD-/M1-Tests vor; die Dateien liegen in `core/stempel/ctb/`, `scenes/battle/` bleibt gelöscht; `BattleState.roll_drops` gibt es nicht mehr; ein alter CTB-Kampagnen-Log ist in beiden Verifiern, Bestenliste und Lobby „ältere Version“ |
| `test_sd_rulebook` | SD2 (umgesetzt, 9 Tests) | Daten gültig (Validator positiv/negativ), Konverter → gültige `GameData` ohne Fehler und Warnung (Grundangriff formal gültig, Engine-Namen = IDs, kein `boss`), `rules_hash` stabil und textunabhängig, Gegnerdecks regelkonform und jede ihrer Karten mit `ai`-Eintrag, Show-Karten mit `cooldown 0`, Freischaltquellen existieren, Texte (IP-Wörter, 110 Zeichen, Platzhalter, Glyphen F8, Kurznamen ≤ 7 Zeichen) |
| `test_sd_duel` | SD2 (umgesetzt, 15 Tests) | Hand 5, Nachziehen, Mischen bei leerem Stapel, Umlaufmappe, Abheften (halber Ärger, Tausch, 2 WT), jede Karte des Regelbuchs gegen ihre gedruckte Wirkung, Zustände in **Nummern** (Kap. 1.6), Wiedervorlage nicht doppelt, Zuständigkeiten, Immunität, Show-Karten (Chance, Patzer), Durchsage (Warnung, Abheften halbiert), Phasen, Leinen-Fallstrick hebt den Feierabend-Eilvermerk auf, Gleichstand „Kundschaft geht vor“, Dienstschluss = vertagt, Aufgeben, Lernduell (Geduld ≥ 1, Drehbuch) |
| `test_sd_ai` | SD2 (umgesetzt, 5 Tests) | Gegner spielen nur aus der Hand, Notlösung → Abheften mit der richtigen Karte, Profile (Bedingungen, `turn_mod`), `SdAi.suggest` und `AutoPolicy` liefern nur legale Züge, beide würfelfrei |
| `test_sd_replay` | SD2 (umgesetzt, 6 Tests) | `SdLog.replay` bitgenau (Hash, Ergebnis), gefälschte Züge/Ergebnisse → Fehler, `version_status`, Schnappschuss → `from_dict` → identisches Weiterspielen, Vorschau ändert den Hash nicht (1 000 Aufrufe) |
| `test_sd_golden` | SD2 (umgesetzt, 3 Tests) | festes Duell mit ≈ 40 geskripteten Zügen → fester Hash und Ereigniszahl |
| `test_sd_balance` | SD2 (umgesetzt, 2 Tests) | Harness (CI 50 Seeds je Gegner und Bot-Profil, nachts 1 000): Bänder unten |
| `test_sd_collection` | SD2 (umgesetzt, 8 Tests) | Rundlauf, kaputte Datei → leer, Deckregeln, Freischaltungen (Gegner, Stempelheft, Kampagne), Seed-Zähler vor dem Duell gespeichert, keine Namen in der Datei |
| `test_sd_ui` | SD2 | Szenen instanziieren, Fokus-Navigation, Trefferflächen ≥ 88 px und Abstände ≥ 12 px, keine Überlappung bei 1280 × 720, 1600 × 720, 1920 × 1080, 2400 × 1080 und mit Notch-Insets, Geist-Zettel, Tastatur-/Gamepad-/Touch-Zuordnung, Linkshänder-Spiegelung, statische Texte nach F8 |
| `test_sd_tutorial` | SD2 | sechs Lektionen in Reihenfolge, Überspringen, Wiederholen, Grundakte danach |
| `test_sd_campaign` | SD3 | Command `sd` in `Game` ≡ `RunSim` ≡ `GameReplay` (Hashes), Belohnung genau einmal je Gegner und Staffel, jeder Ablehnungsgrund, offenes Duell schließt beim nächsten eigenen Command und bleibt bei `clock`/`gift`/`twist` offen, Einsturz wartet bis Duellende + 2 min, Journal-Abbruch mitten im Duell → aufgegeben, alte Läufe ohne `sd` bitgleich |
| `test_sd_cast` | SD3 | KI-Gegner aus jedem Profil, deterministisch je Platz, keine Belohnung außer Kosmetik, Eilmeldung höchstens einmal je Tag |

**Balance-Bänder (Startwerte, Harness-Profile „gut“ = `SdAi.suggest`, „einfach“ = `AutoPolicy`, „Zufall“ = zufällige
Handkarte, nie Abheften; je mit Startmappe bzw. „passender“ Mappe) [zu messen]:**

| Gegner | „gut“, Startmappe | „gut“, passende Mappe | „einfach“, Startmappe | „Zufall“ | Nummern je Duell (Median) |
|---|---|---|---|---|---|
| Ferdi | ≥ 95 % | — | ≥ 85 % | ≥ 70 % | 14–24 |
| Graf (Übung) | 85–97 % | — | 15–40 % | 15–40 % | 24–34 |
| Ulla | 30–50 % | ≥ 80 % | ≤ 15 % | — | 28–40 |
| Stempelmeister | ≤ 10 % (Deckbau-Prüfung) | **70–90 %** (bis SD2 50–65 %, U-15; Besitz beim ersten Besuch: 40–55 %) | ≤ 10 % | — | 20–30 |

**Prototyp-Werte (Review 2026-10-11** — echte Engine, Heuristik statt `SdAi`, geschätzte KI-Gewichte, 200–300 Seeds je
Zelle): Ferdi 100 / 99 / 99,5 % („gut“ / „einfach“ / „Zufall“, 16 Nummern); Graf 97 / 20 / 25 % (28); Ulla 32 % mit der
Startmappe, 99 % passend, 2 % „einfach“ (36); Stempelmeister mit den Werten aus Kap. 3.4: 4 % Startmappe, 50 % beim ersten
Besuch, 63 % mit voller Sammlung, 0 % „einfach“ (24). Dienstschluss 0 %, erste Nummer ≤ 4 Punkte, in 61–93 % der Duelle
ist eine Seite mindestens dreimal hintereinander dran. `AutoPolicy` spielt stur die Karte mit dem meisten Ärger und übersieht
Werktage — als Modell für Anfänger:innen zu schwach, „einfach“ ist deshalb nur eine Untergrenze; der Pfoten-Tipp (Standard an)
soll auf „gut“-Niveau raten.

Dazu: Dienstschluss in < 1 % der Duelle, Unterschied der Siegquote mit und ohne erste Nummer ≤ 10 Punkte, keine Karte in
> 80 % der „gut“-Siegmappen (sonst ist sie zu stark), jede Karte in ≥ 5 % (sonst zu schwach).

**Gemessen in SD2-B (2026-10-12)** — `SdAi.suggest` („gut“), `AutoPolicy` („einfach“), zufällige Handkarte („Zufall“),
Gewichte aus `opponents.json`, Seeds `1000 + i × 7919`; 1 000 Seeds je Zelle (die CI rechnet die ersten 50):

| Gegner | Mappe | „gut“ | „einfach“ | „Zufall“ | Nummern (Median, „gut“) | Band | CI (50 Seeds, „gut“) |
|---|---|---|---|---|---|---|---|
| Ferdi | Startmappe | 100,0 % | 99,6 % | 99,4 % | 16 | ✓ | 100 % |
| Graf | Startmappe | 92,6 % | 24,4 % | 29,7 % | 30 | ✓ | 90 % |
| Ulla | Startmappe | 38,4 % | 11,6 % | — | 31 | ✓ | 40 % |
| Ulla | passend (`ulla_passend`) | 99,7 % | — | — | 21 | ✓ | 100 % |
| Stempelmeister | Startmappe | 7,5 % | 0,0 % | — | 23 | ✓ | 6 % |
| Stempelmeister | volle Sammlung (`meister_passend`) | 83,1 % | — | — | 15 | ✓ (70–90 %) | 94 % |
| Stempelmeister | erster Besuch (`meister_erster_besuch`) | 46,8 % | — | — | 18 | ✓ | 60 % |

Dienstschluss in 0 von 13 000 Duellen. Erste Nummer: in den „gut“-Zellen höchstens 9 Punkte Unterschied (Ulla, Startmappe:
42 zu 33 %), im Mittel 3 Punkte (CI: +6,1). Karten in den gewinnenden Zufallsmappen (CI: 25 Mappen × 4 Gegner, 65 Siege):
20–66 % — keine über 80 %, keine unter 5 % (Bahnsteig-Suplex 20 %, Leinen-Fallstrick 66 %).

- **Prüfung in der CI** (`test_sd_balance`): 50 Seeds je Zelle; eine Zelle besteht, wenn ihre Siegquote höchstens zwei
  Standardfehler (binomial, an der Bandgrenze) außerhalb des Bands liegt — bei 50 Seeds bis zu 14 Punkte, bei 1 000 Seeds
  ≈ 3. Mit `SD_BALANCE_SEEDS=1000` rechnet derselbe Test die 1 000 Seeds (≈ 6–7 min; ein nächtlicher Lauf ist noch nicht
  eingerichtet — CI-Dateien gehören nicht zu SD2-A/B). Die Medianwerte prüft er ohne Spielraum.
- **Karten-Anteile:** ausgewogene Zufallsmappen aus der vollen Sammlung — Karten-Arten in zufälliger Reihenfolge mit voller
  Kopienzahl, bis 20 voll sind (≈ 10 Arten je Mappe, Grundanteil ≈ 45 %). Ein „gut“-Duell je Gegner und Mappe; gezählt wird,
  in wie vielen gewinnenden Mappen eine Karte steckt. (Mappen aus ganz zufällig gezogenen Karten gewinnen fast immer und
  messen nur den Grundanteil.)
- **CI-Zeit** der sieben neuen Testdateien ≈ 33 s, davon `test_sd_balance` ≈ 22 s (Bänder ≈ 19 s, Karten-Anteile ≈ 3 s);
  zum Vergleich: `check.sh` lief vorher ≈ 407 s für 1 599 Tests.

**Playtest-Gate (SD2):** 5 Personen nach dem Lernduell — mindestens 4 erklären die Regel „lange Formulare, lange
Wartezeit“ in einem eigenen Satz und finden die Wartenummern-Anzeige ohne Hilfe; Spaß ≥ 4 von 5 im Median; niemand fühlt
sich zum Weiterspielen gedrängt.

### 6.10 Performance (mobil)

| Größe | Ziel | Begründung |
|---|---|---|
| 3D-Draw-Calls | **0** (+ M.O.D.-Drohne 64 px) | `Router.push` hängt die Szene darunter aus (02_TECH §9.2); keine Porträt-SubViewports |
| UI-Draw-Calls | **≤ 120** [zu messen] | Rahmen, Leisten und Symbole je Element als **ein** Dreiecks-Array (`icon_mesh.gd`), Labels ohne Outline auf dunklem Grund (Messregeln 02_TECH §12.1): Overlay ≈ 15, Anzeige ≈ 20, Plaketten ≈ 12, Schalter ≈ 6, Hand ≈ 30, Knöpfe ≈ 8, ModDialog ≈ 10 |
| FPS | 60 auf den Referenzgeräten (Adreno 610 / Mali-G57, Quality `low`), 30 im Compatibility-Fallback | nur Canvas, Tweens |
| Rechenzeit | Zug ≤ 2 ms, Vorschau (Probelauf) ≤ 3 ms je Fokuswechsel [zu messen] | Engine-Zug ist trivial; Schnappschuss-Kopie nur bei Fokuswechsel |
| Aufbau | Regelbuch ≤ 50 ms einmal je Sitzung, Tisch ≤ 300 ms | kleine JSON-Dateien, keine Meshes |
| Ruhe | kein `_process` im Leerlauf (`set_process(false)`), Animationen nur bei Ereignissen | Akku |
| Partikel | höchstens 1 `CPUParticles2D` (Tintenklecks, ≤ 24 Teilchen) — oder gezeichnete Kleckse | Budget 02_TECH §12.1 |

`tools/perf.sh` bekommt das Szenario `stempel` (Duell mit vollem Tisch, Durchsage aktiv); Ergebnisse in `PERFORMANCE.md`.

---

## 7. Umsetzung SD1–SD3 (= M1–M3 des Orchestrators)

### 7.1 Reihenfolge gegenüber 07 R5b und 09 ST

```text
07 R5b Schritt 1–2 (Standard realtime, Daten backen, Save v2)
   └─ R5b Schritt 3 = SD1 (Engine umziehen statt löschen) ── im selben Durchgang: 09 ST0 (+ Stub für Command sd)
        └─ R5b Schritt 4 (Doku) ── CR-34 … CR-38 dieses Dokuments eingearbeitet
SD2 (Mini-Spiel, Titel → Extras → Stempelduell (Vorschau))
   ├─ Entwicklung kann sofort beginnen: nur eigene Dateien, Engine-Klassen per class_name (der Umzug ändert keine Namen)
   └─ Merge nach SD1 (R5b/ST0); title.gd-Abschnitt mit ST1-H abstimmen (beide fügen Titelzeilen ein)
SD3 (Etage 8)
   ├─ nach 09 ST1-C (Etage 8 als Platzhalter-Etage der Kulisse „Amt“, themes.json thm_amt) und ST1-B (Staffel-Kern)
   ├─ KI-Gegner nach ST1-F (CastSim, Safe-Room-NPCs)
   └─ Feinschliff (Art, Ton) mit der Akt-2-Produktion der Kulisse Amt (04 Phase 4/5, 09 Kap. 3.5)
```

**Stand 2026-10-12:** 07 R5b Schritte 1–4 mit SD1 sind umgesetzt (07 §12.6 „Stand R5b-2b“); ST0 mit dem Stub `sd` steht
aus. SD2 kann beginnen. SD2-A/B (Regelbuch, Duell-Kern, Harness) sind umgesetzt (Kap. 7.3 „Stand SD2-A/B“); SD2-C … G
folgen.

**Warum so:** SD1 muss in R5b liegen, weil R5b sonst löscht, was SD2 braucht. SD2 hängt an keiner Staffel-Mechanik und
kann deshalb früh Spaß beweisen (Extras-Vorschau); SD3 braucht eine Etage 8, die es erst mit ST1-C gibt.

### 7.2 SD1 — Extraktion (Integrator, mit 07 R5b)

| | |
|---|---|
| **Inhalt** | Kap. 6.2: `roll_drops` nach `BattleResult`, Umzug der **fünf** Engine-Dateien nach `core/stempel/ctb/` (`battle_command.gd` bleibt geteilt), Konstanten/Felder/Hash bleiben, Kampagnendaten gebacken, CTB-Darstellung und Kampagnen-CTB-Pfade gelöscht, `test_sd_engine_golden`, `test_sd_boundaries`, optional Stub `sd` |
| **Dateien** | `core/battle/{battle_state,battle_result}.gd`, `core/rt/rt_result.gd`, `tests/{test_m2_loot,test_r1_rt_result}.gd` (`roll_drops`), `core/stempel/ctb/*.gd` (verschoben), `tests/test_m1_stats.gd` (eine Zeile), `core/stats/balance.gd` (Abschnitt bleibt), `core/live/state_hash.gd` (unverändert), `core/data/{game_data,data_validator}.gd` und `core/data/defs/*` (CTB-Felder, `PseudoUnitDef` und `pseudo_units` bleiben, im Validator optional), `tests/test_sd_engine_golden.gd`, `tests/test_sd_boundaries.gd`; mit Stub zusätzlich `core/live/command.gd`, `run_rules.gd`, `run_sim.gd`, `autoload/game_replay.gd` (je ein Zweig) |
| **Gate** | `check.sh` grün, `fullrun.sh --strategy=all` grün (07 §12.6), alle `test_m1_*` grün, Golden fest, Grenztest grün |
| **Aufwand** | ≈ 1–2 Personentage mit KI, **zusätzlich** zu R5b Schritt 3 (das Ersetzen der CTB-Teile von heute 27 weiteren Testdateien schuldet R5b in jedem Fall, Kap. 6.2 Zeile 4) |
| **Stand** | **umgesetzt** mit 07 R5b-2b (Kap. 6.2 „Umgesetzt“, ohne Stub `sd`). Gate erfüllt: `check.sh` grün (1 599 Tests, 0 fehlgeschlagen, 0 übersprungen, 0 Fehler; `AUTOPLAY: OK`), `fullrun.sh --strategy=all` grün, alle `test_m1_*` grün, Golden fest, Grenztest grün. Ersetzt wurden die CTB-Teile von 58 Kampagnen-Testdateien — mehr als die 27 von oben: dazu Tests, die den CTB-Kampf über `Game`, `RunSim`, den Befehl `battle` oder die CTB-Szene spielten |

### 7.3 SD2 — Mini-Spiel (eigener Agent „Stempelduell“)

| Paket | Inhalt | Aufwand [Schätzung, PT mit KI] |
|---|---|---|
| SD2-A Regelbuch | `data/stempel/*.json` (24 Karten, 4 Gegner, 4 Zustände, Durchsage, Drehbuch, ≈ 80 Zeilen, Kosmetik, Auszeichnungen), `SdRulebook`, Defs, `sd_validator.gd` | 3–4 |
| SD2-B Duell-Kern | `SdSetup`, `SdDuel`, `SdEvent`, `SdAi`, `SdLog`, `SdCollection` | 4–5 |
| SD2-C Kartentisch | `sd_table`, Wartenummern-Anzeige, Hand, Karten, Plaketten, Schalter, Ergebnis, Ansager, Animationen, Touch/Tastatur/Gamepad | 6–8 |
| SD2-D Menüs | Titel → Extras, Schalterhalle, Akte, Aktenschrank, Stempelalbum, Stempelheft, Regeln | 3–4 |
| SD2-E Lernduell | Drehbuch, Hinweiskarten, Grundakte | 2–3 |
| SD2-F Ton, Overlay | Klänge, Wartezimmer-Schleife, ShowOverlay-Modus `duel`, ModDialog-Lage | 1–2 |
| SD2-G Tests, Harness, Captures, Perf | Kap. 6.9/6.10, Capture-Rezepte `sd_table`, `sd_table_touch`, `sd_boss_durchsage`, `sd_deck_builder`, `sd_album`, `sd_results` | 3–4 |
| **Summe** | | **≈ 22–30 PT** |

**Stand nach SD1 — was SD2 vorfindet und braucht** (07 R5b-2b):

- **Engine:** `BattleState`, `CTBQueue`, `ActionResolver`, `EnemyAI`, `AutoPolicy` heißen wie bisher (`class_name`) und
  liegen in `core/stempel/ctb/`; `BattleCommand` und die übrigen Basistypen bleiben geteilt in `core/battle`. Eingefroren:
  Jede Verhaltensänderung lässt `test_sd_engine_golden` scheitern → Änderungsantrag, Begründung, `SD_VERSION`.
- **Regelbuch statt Kampagnen-Daten:** `data/*.json` trägt keine CTB-Felder mehr (kein `rank`, `cooldown`, `default_turns`,
  `tick_timing`, `ai`/`phases`, keine `pseudo_units`). Das Regelbuch liefert sie selbst; Defs und `DataValidator` nehmen sie
  als optionale Felder an. Vorbild für einen kleinen Engine-Datensatz über `GameData.load_from_dicts`: `Fx.tables()` in
  `tests/test_m1_fixture.gd`.
- **Grenze:** Engine-Klassen nur in `core/stempel/**`, `scenes/stempel/**` und `tests/test_sd_*` (dazu die Bestände
  `tests/test_m1_*` und `core/live/state_hash.gd`; sonst ist `test_sd_boundaries` rot) — der Titel-Abschnitt („Extras“) ruft nur `scenes/stempel/`.
- **Eingabe:** Tab und Y binden (Kap. 4.6 „Stand nach SD1“: `CombatInput.apply_input_mode(false)` beim Betreten,
  `CombatInput.apply_for_game()` beim Verlassen, oder selbst lesen); `toggle_speed` ist frei; `sd_file` additiv in
  `project.godot`.
- **Bildschirmwechsel:** `Router.push(…, Transition.FADE)` und `pop` (02_TECH §9.2); `Router.start_battle`/`end_battle`, der
  Swirl-Übergang und die Sfx-Id `swirl` gibt es nicht mehr (die Sfx-Id `defend` schon).
- **Hash und Versionen:** `StateHash.of_battle`/`battle_hash_input` bleiben für `SdDuel.hash()`; `RunSim.SIM_VERSION` ist 4
  (Kampagne), `SD_VERSION` zählt getrennt.
- **Show:** `ShowRules` kennt nur das Profil `rt`; das Duell sendet keine Kampf-Signale (Kap. 6.5) und speist die Show nicht.
- **Tests und Werkzeuge:** Die CTB-Balance-Tests der Kampagne sind gelöscht (`test_m7_balance`, `test_m7_show_balance`,
  `test_06c_balance`); das Duell misst mit `test_sd_balance` gegen eigene Bänder. `perf.sh` hat keinen Abschnitt `battle`
  mehr — SD2 ergänzt `stempel`. Die Bilder der CTB-Kampfszene (08–12, 18, 22, 28) liegen als Archiv in `docs/screenshots/`.

**Geteilte Dateien (je ein markierter Abschnitt `# --- Stempelduell (10, SD2) ---`, nur additiv):** `scenes/title/title.gd`
(Zeile „Extras“), `scenes/ui/show_overlay.gd` (Modus `duel`; `Events.overlay_mode_requested` dokumentiert ihn),
`autoload/save.gd` (Sammlungsdatei), `autoload/sfx_synth.gd` (Klänge), `project.godot` (eine Aktion `sd_file`, 02_TECH
§2.2), `core/data/seed_util.gd` (Kommentar: Zwecke `sd`, `sd_deck`), `tests/capture_recipes.gd` (Rezepte), `tools/perf.sh`
(Szenario), `README.md` (Extras, Dokument-Index). **Gate:** alle SD2-Tests grün, Balance-Bänder, Captures in 1280 × 720,
1600 × 720, 1920 × 1080 und 2400 × 1080 gesichtet, Perf-Ziele, Playtest-Gate (Kap. 6.9).

**Stand SD2-A/B (2026-10-12, Branch `ptd/sd2`)** — umgesetzt, rein und headless (kein Bildschirm, kein Menü, kein Ton,
kein Titel-Eintrag, kein Speicher-Haken; die Engine und alle geteilten Dateien sind unberührt):

| Paket | Dateien (relativ zu `game/`) |
|---|---|
| SD2-A Regelbuch | `data/stempel/{cards,opponents,rules,lines,cosmetics,awards}.json`; `core/stempel/sd_rulebook.gd` (`SdRulebook`: laden, prüfen, Engine-`GameData` über `load_from_dicts`, `rules_hash`), `sd_card_def.gd` (`SdCardDef`), `sd_opponent_def.gd` (`SdOpponentDef`), `validators/sd_validator.gd` (privat; der Kampagnen-`DataValidator` bekommt keine Regel) |
| SD2-B Duell-Kern | `core/stempel/sd_setup.gd` (`SdSetup`), `sd_duel.gd` (`SdDuel`), `sd_event.gd` (`SdEvent`), `sd_ai.gd` (`SdAi`), `sd_log.gd` (`SdLog`, `LOG_VERSION` 1; `SdDuel.SD_VERSION` 1, getrennt von `RunSim.SIM_VERSION`), `sd_collection.gd` (`SdCollection`) |
| Tests | `tests/test_sd_{rulebook,duel,ai,replay,golden,collection,balance}.gd` (48 Tests), `tests/test_sd_fixture.gd` (Helfer `Sx` + Selbsttest), `tests/fixtures/stempel/balance_decks.json` (Harness-Mappen „passend“ und „erster Besuch“) |

**Gate:** `tools/check.sh` (voll): 1 648 Tests, 0 fehlgeschlagen, 0 übersprungen, 0 Fehler in 450 s (vorher 1 599 Tests in
407 s), `AUTOPLAY: OK`, `check.sh: OK`; alle `test_sd_*` (57, davon 49 neu) und `test_m1_*` (86) grün,
`test_sd_engine_golden` und `test_sd_boundaries` unverändert grün; Balance: die 1 000-Seed-Werte liegen in allen Bändern,
die 50-Seed-Zellen der CI in ihren Bändern oder im Stichproben-Spielraum (Kap. 6.9). Offen bleiben SD2-C … G: Tisch,
Menüs, Lernduell-Bildschirme, Ton, Titel-Eintrag, Speicher-Haken, Captures, Perf und das Playtest-Gate.

**Entscheidungen beim Umsetzen** (U = Umsetzung; Startwerte bleiben Daten):

| Nr. | Thema | Entscheidung |
|---|---|---|
| U-1 | Konstanten, Namen | Deck 20, Hand 5, Kopien 2 (Show 1), Geduld 50, Tempo 10, Dienstschluss 80 (Hinweis ab 60), Lernduell-Ärger 50 %, 3 Mappen, eine Stempelheft-Belohnung je 3 Stempel stehen in `rules.json → constants` und damit im `rules_hash`; die Klassen halten keine Kopien. `SdDuel.state_hash()` statt `hash()` (02_TECH §13.1) |
| U-2 | Datenformat (Kap. 2.7) | jede Datei `{"schema": 1, "entries": […]}` (`rules.json`: Objekte). Karten: `campaign` (Kampagnen-IDs, Kap. 2.5) statt `unlock` — Grundakte, Stempelheft und Gegner-Belohnungen stehen dort, wo sie vergeben werden (`rules.json → grundakte`/`heft`/`rewards`, `opponents.json → first_win`); neu `form` (dreistellige Formularnummer, nur Deko), `hand: "refresh"` (Umlaufmappe), `owner` (Talentkarten: `kandidat`/`graf`); der `skill`-Block trägt nur Mechanik. Gegner: `first_win.cosmetics` ist eine Liste (der Stempelmeister gibt Titel und Stempelfarbe), dazu `akte`, `rule`, `open_hand` (Graf: an) |
| U-3 | `rules_hash` | SHA-256 über `{"sd_version", "engine": Engine-Tabellen, "duel": {Konstanten, Deckregeln je Karte (`max_copies`, `show`, `hand`), Gegnerdecks, Lernduell-Decks und Pflichtzüge}}`, jede Zahl als ppm-Ganzzahl (`CanonicalJson` nimmt keine Brüche: 1,5 → 1 500 000). Ohne Namen, Texte, Zeilen, Kosmetik, Auszeichnungen, Freischaltungen und Belohnungen. Ein Regelbuch mit Fehlern hat keinen `rules_hash` und startet kein Duell |
| U-4 | Mischen, Ziehen | Decks werden vor dem Mischen sortiert (die Reihenfolge der Mappe zählt nicht); eine gezogene Karte kommt rechts in die Hand, die übrigen behalten ihren Platz; die Ablage wird erst gemischt, wenn vom leeren Stapel gezogen werden muss; nach Bewilligt/Abgelehnt wird nicht mehr gezogen |
| U-5 | Ereignisse eines Zugs | `CARD_PLAYED`/`CARD_FILED` (Platz vor dem Zug) → Engine-Ereignisse der Aktion bis zum `TURN_END` des Akteurs → `HAND_REFRESHED` (Umlaufmappe) → je Karte `RESHUFFLED` (falls nötig) und `CARD_DRAWN` → Engine-Ereignisse der folgenden Nummern (Durchsage, Kleingedrucktes, `TURN_START`) → `DUEL_END`. Aus der Engine kommen auch der Phasenwechsel (`PHASE_CHANGE`), das Erscheinen der Durchsage (`SUMMON`) sowie Durchsage-Warnung und `say` (`MOD_LINE`, Text = Zeilen-Tag) |
| U-6 | Dienstschluss | Ist nach einem Zug Nummer 80 aufgerufen (`turn_count ≥ 80`), endet das Duell `ADJOURNED` — Nummer 80 wird nicht mehr bedient |
| U-7 | Aufgeben | ein Zug `{"op": "forfeit"}`, nur die Spieler:in und nur, wenn sie dran ist (die Züge des Gegenübers rechnet der Tisch sofort); steht im Log wie jeder Zug |
| U-8 | Notlösung des Gegenübers | Liefert `EnemyAI` den Grundangriff, heftet das Gegenüber die Handkarte mit dem kleinsten Gewicht ab — Gewicht = größtes Gewicht der Karte in der aktuellen Aktionsliste (Phase), Bedingungen nicht beachtet, ohne Eintrag 0; Gleichstand: links |
| U-9 | Lernduell | eigener Engine-Gegner `enm_sd_lernduell` (Ferdis Zuständigkeiten, **Geduld 26** statt 36, damit es kurz bleibt) mit dem Drehbuch als `ai` (`turn_mod [3, 0/1/2]`: Wiedervorlage, Formular 27b, Ablehnungsbescheid); feste Decks; Lektionen in `rules.json → tutorial.lessons` (`step`, `ticket`, `move`, `card`, `line`, `note`). An Nummern mit Pflichtzug (1 Stempel, 2 Formular 27b, 5 Abheften, 7 Adelsflamme) lässt `validate` nur diesen Zug zu; Tipp und Auto spielen ihn. Das Lernduell gibt keinen Heft-Stempel und zählt nicht als Sieg gegen Ferdi |
| U-10 | Zeilen (`lines.json`) | IDs `sdl_<Tag ohne sd_, „:“ → „_“>_<nn>`; Stimmen `mod`, `mopsula`, `chat`, `opp` (das Gegenüber; Tags `sd_opp_intro:`/`sd_opp_win:`/`sd_opp_lose:`/`sd_akte:` + Feld `lines`); Platzhalter `{opp}`, `{ticket}`, `{card}`, `{count}`, `{name}`; Pflicht-Tags prüft der Validator (Ansager, Gegner, Phasen, Durchsage-Warnung, Lektionen, Tipps `sd_hint:<Grund>` aus `SdAi.HINTS`) |
| U-11 | Ton und IP | geprüft werden **alle** Texte des Regelbuchs: `ip_words.gd`, eine eigene Wortliste (echte Behörden und Einrichtungen, „A38“, DCC-Begriffe), keine Königs- und Kronenmotive (auch außerhalb der Grafen-Zeilen), kein Pluralis Majestatis in der Grafenstimme, keine Glyphen ohne Schrift (F8), ≤ 110 Zeichen, Kurznamen ≤ 7 |
| U-12 | Kleingedrucktes | Der Zustand trägt das Element `poison` wie seine Karte (Formular-Art Papierkram): Der Tick-Ärger erscheint in der Farbe der Art; Zuständigkeiten ändern ihn nicht (fest 2), nur eine Immunität (Faktor 0) hielte den Zustand ab — keiner der vier Gegner hat eine |
| U-13 | Sammlung | `SdCollection` (Format Kap. 6.7 „Umgesetzt“): Lernduell → Grundakte, Startmappe als Mappe A, Kartenrücken „Durchschlag“; erster Sieg → `first_win`; jeder Sieg außerhalb des Lernduells ein Heft-Stempel, je 3 Stempel der nächste noch nicht besessene Eintrag der Heft-Reihenfolge; volles Album → `rewards.album`; Aufgeben zählt als Niederlage, Vertagt gar nicht. „Automatisch füllen“ wie Kap. 2.6 (Gleichstand: Reihenfolge in `cards.json`) |
| U-14 | Ulla | heilt erst unter 40 % Geduld (Erste Hilfe und Schlabbern Gewicht 3, Gegengift 2); mit dem ersten Entwurf (unter 50 %, Gewicht 8) lag die Startmappe bei 22–25 %, jetzt 38 % |
| U-15 | Band Stempelmeister | „passend“ (volle Sammlung) **70–90 %** statt 50–65 %: `SdAi` spielt stärker als die Prototyp-Heuristik, und die volle Sammlung (Großer Amtsstempel, Kaffee, Leinen-Fallstrick gegen den Feierabend-Eilvermerk) lag mit allen geprüften Gewichtungen bei ≈ 82–84 %. Startmappe (≤ 10 %) und erster Besuch (40–55 %) — die eigentliche Deckbau-Prüfung — halten ihre Bänder |
| U-16 | Balance in der CI | 50 Seeds je Zelle mit 2-σ-Spielraum, 1 000 Seeds über `SD_BALANCE_SEEDS`; Karten-Anteile über ausgewogene Zufallsmappen (Kap. 6.9) |

**Was SD2-C … F vorfinden:**

- **Tisch (SD2-C):** `SdRulebook.shared()` (einmal je Sitzung; `is_valid()`, sonst `errors`), `SdSetup.create(book, opp,
  mappe, seed)` bzw. `SdSetup.lernduell(book)`, `SdDuel.new(setup, book)`, `start()`. Ist die Spieler:in dran:
  `legal_moves()`/`validate(move)`, bei Fokuswechsel `preview(move)` (Geist-Zettel, Plaketten-Hinweise), dann `submit(move)`
  → `Array[SdEvent]` abspielen und erst danach den Zustand lesen; ist das Gegenüber dran: `submit(opponent_move())` (die
  Durchsage rechnet die Engine selbst). Pfote: `SdAi.suggest(duel)` → `{"op", "slot", "hint"}`, Fußnote aus
  `book.lines_for("sd_hint:" + hint)`. Anzeige: `order()`, `ticket()`, `dienstschluss_near()`, `chain()`,
  `geduld`/`max_geduld(side)`, `hand(side)` (Gegenhand nur offen zeigen, wenn `open_hand`), `combatant(side).statuses`
  (Plaketten aus `book.statuses[id]`: Name, Text, Farbe, Symbol), `book.durchsage` (Kurzname, Symbol, Text); Karten und
  Gegner: `book.card(id)`, `book.opponent(id)`.
- **Menüs (SD2-D):** `SdCollection.is_unlocked`, `deck_problem` (ein deutscher Satz fürs Aktenschrank-Banner), `auto_fill`,
  `set_deck`/`set_active`/`active_deck`, `equip`/`unequip`, `set_option`, `next_heft_reward`, `wants_deck_tip`,
  `apply_campaign(ids)` (die IDs liest der Bildschirm aus den Speicherplätzen); vor dem Duell `next_duel_seed()` und
  **speichern**, danach `record_duel(duel.summary(), book)` → `{"cards", "cosmetics", "awards", "heft"}` für die Toasts.
  Album: `book.card_ids`, `book.heft`, `book.cosmetics`, `book.awards`.
- **Lernduell (SD2-E):** je Nummer `lessons_now()` (Zeile `line`, Hinweiskarte `note`) und `forced_move()` (hervorgehobene
  Karte); andere Züge lehnt `validate` ab. „Ich kenne mich aus“: `SdCollection.complete_tutorial(book)`.
- **Ton und Overlay (SD2-F):** Klänge an `SdEvent.kind` und den Engine-Typen (`DAMAGE` mit `weak`/`resist`/`immune`,
  `STATUS_ADDED`/`STATUS_BLOCKED`, `STUNT_RESULT`, `MOD_LINE`); Zeilen über `book.lines_for(tag)` (Feld `voice`).
- **Speicher-Haken** (`autoload/save.gd`, eigener Abschnitt): `load_sd_collection()` = `SdCollection.from_dict(JSON, book)`
  (`was_reset` → Toast), `save_sd_collection(c.to_dict())` atomar; den Konto-Seed einmal außerhalb von `core/` würfeln
  (`SdCollection.create(seed)`). Der Titel-Eintrag „Extras“ ruft nur `scenes/stempel/`.

### 7.4 SD3 — Etage 8 (mit 09 ST1)

| Paket | Inhalt | Aufwand [PT] |
|---|---|---|
| SD3-A Kampagnen-Anbindung | `SdRules`, Command `sd` (Stub → echt) in `RunRules`/`RunSim`/`GameReplay`, `Game.sd_start/sd_end` (aufzeichnend), Belohnungen, `flags.sd` | 2–3 |
| SD3-B Wartezimmer | Safe-Room-Thema „Wartezimmer“ für Etagen 7–9 (`thm_amt`), Zeile „Mopsula \| Schalter 3“ auf Etage 8, Requisiten `counter`, `ticket_dispenser`, `number_display`, Plakate auf Etage 7, Ferdi-Zeile; die M.O.D.-Ansage beim ersten Wartezimmer auf Etage 8 kommt vom Duell-Ansager aus `data/stempel/lines.json` (gemerkt in der Konto-Sammlung) — keine Zeile in `mod_lines.json`, kein neues Tag-Präfix im eingefrorenen Validator | 1–2 |
| SD3-C KI-Gegner | Deck-Vorlagen je Profil, Angebot im Safe Room, `cast_sd_*`-Eilmeldungen (nach ST1-F) | 2–3 |
| SD3-D Tests | `test_sd_campaign`, `test_sd_cast`, Staffel-Harness ohne Duell bitgleich | 1 |
| **Summe** | | **≈ 6–9 PT** |

**Geteilte Dateien:** `core/live/{command,run_rules,run_sim}.gd`, `autoload/{game,game_replay}.gd` (Abschnitte),
`core/season/season_rules.gd` (Einsturz wartet auch auf ein offenes Duell, eine Bedingung), `scenes/safe_room/safe_room.gd`
(Menüzeile), `data/themes.json` / `floors.json` (Einträge der Kulisse, ST1-C schreibt sie, SD3 nur die Wartezimmer-Felder),
`data/mod_lines.json` (nur die `cast_sd_*`-Eilmeldungen unter dem schon registrierten Präfix `cast_`, 09 ST0).
**Gate:** `test_sd_campaign` grün, `Game.replay_log` ≡ live mit Duellen, Staffel-Harness unverändert, Bot spielt auf
Etage 8 ein Duell (optional).

### 7.5 Dateieigentum

| Datei / Bereich | Eigentum | Regel |
|---|---|---|
| `core/stempel/**`, `data/stempel/**`, `scenes/stempel/**`, `scenes/title/extras_menu.*`, `tests/test_sd_*` | **SD** (neu) | neu |
| `core/stempel/ctb/*.gd` | SD (ab SD1; vorher M1) | **eingefroren**: Änderungen nur per Änderungsantrag + Golden-Begründung + `SD_VERSION` |
| `tests/test_m1_*.gd` | SD (ab SD1) | Namen bleiben |
| `core/battle/{action_event,battle_setup,battle_result,battle_command,combatant,status_effect,hit_result,damage_calc}.gd`, `core/stats/*` | wie 07 §12.3 (R-Phasen) | geteilt; jede Änderung lässt `test_sd_engine_golden` laufen; CTB-Felder und -Typen darin entfernt nur ein Änderungsantrag (Kap. 6.2 Zeile 2) |
| `core/data/data_validator.gd` | Vertrags-Durchgänge | SD1 behält die CTB-Feld-Spezifikationen; keine neue Zeile für SD2 (das Regelbuch hat einen eigenen Validator) |
| `core/live/command.gd`, `run_rules.gd`, `run_sim.gd` | ST0 / M8 | Stub `sd` in ST0, Umsetzung SD3 in eigenem Abschnitt |
| `scenes/title/title.gd`, `scenes/ui/show_overlay.gd`, `autoload/save.gd`, `autoload/sfx_synth.gd`, `scenes/safe_room/safe_room.gd` | M6 / M2 / M0 (+ 06/07/09-Abschnitte) | je ein SD-Abschnitt, additiv |
| `project.godot` (`[input]`) | M0 / R3 | eine neue Aktion `sd_file`, additiv |
| `core/season/season_rules.gd` | 09 ST1-B | SD3: eine Bedingung „oder Duell offen“ beim Einsturz (CR-36) |
| `docs/10_MINISPIEL_STEMPELDUELL.md` | SD | — |

### 7.6 Änderungsanträge

| CR | Betrifft | Änderung | Wann |
|---|---|---|---|
| **CR-34** | `07` §12.6 (Schritt 3), §12.3 (Zeile `scenes/battle/**, core/battle/{…}`), §4.11 (Spalte „Ab R5b“), §12.7, §12.8 | Die **fünf** CTB-Engine-Dateien (`ctb_queue`, `battle_state`, `action_resolver`, `enemy_ai`, `auto_policy`) ziehen nach `core/stempel/ctb/` um statt gelöscht zu werden. **Korrektur an 07:** `battle_command.gd` bleibt geteilt (der Echtzeitkampf nutzt `BattleCommand.Kind`), `BattleState.roll_drops` zieht vorher nach `BattleResult` (`rt_result.gd` nutzt ihn) — beides bräche sonst auch 07s eigene Löschliste. `Balance.FLEE_*`, `DEFEND_MULT`, `STUNT_COOLDOWN`, `StateHash.of_battle`/`battle_hash_input`, die CTB-Felder der Defs (inkl. `PseudoUnitDef`/`pseudo_units`) samt optionaler Validator-Spezifikationen und die CTB-Laufzeitfelder der geteilten Klassen bleiben (die Kampagnendaten verlieren die Felder wie geplant, auch den Zug); R5b ersetzt die CTB-Teile **aller** Kampagnen-Tests (Kap. 6.2 Zeile 4); `test_m1_*` bleiben (`test_m1_stats`: ein Ordner mehr), neu `test_sd_engine_golden`, `test_sd_boundaries`; `scenes/battle/**` wird wie geplant gelöscht. Ein Hinweis in 07 §12.6 zeigt schon hierher | vor R5b |
| **CR-35** | `02_TECH` §0.4, §1.3, §1.6, §1.7, §2.2, §4.6, §5 | Modul **SD** mit Pfaden und Schichtregel (Kap. 6.3); §5 „Kampf-Kern (M1)“ wird „Stempelduell-Engine (CTB, SD)“ mit Verweis auf dieses Dokument; Testliste; Input-Aktion `sd_file`; Seed-Zwecke `sd`, `sd_deck` | mit R5b-Doku bzw. SD2 |
| **CR-36** | `09` §11.2 (ST0), §11.4, §2.5, §2.8 + S-20, §3.1/3.5 | Command-Typ `sd` als Stub im ST0-Durchgang (`sd_unavailable`), `flags.sd`; Einsturz wartet auch auf ein offenes Duell (+ 2 min, wie nach einem Kampf); in der Liste dessen, was Staffeln überdauert, zusätzlich die **Stempel-Sammlung** (Mini-Spiel, ohne Wirkung auf Kampf und Staffel); Wartezimmer als Safe-Room-Thema der Kulisse Amt (ST1-C), Schalter 3 auf Etage 8 (SD3); KI-Gegner als Haken in ST1-F | ST0 bzw. ST1-B/C/F |
| **CR-37** | `01_GDD` §14.1, §14.7; `06` §2.7 | Titelmenü-Zeile „Extras“; Safe-Room-Zeile „Mopsula \| Schalter 3“ nur auf Etage 8; Stempelkarten sind **keine** NOVA-Sammelkarten und tragen keine Boni | SD2 bzw. SD3 |
| **CR-38** | `03_ART` §9 + 09 CR-28 | Karten-Look (Rahmenfarben je Formular-Art, Goldrahmen, Kartengrößen), gezeichnete Symbole (Stempel, Sanduhr, Wartemarke, Lupe, Schnecke, Lautsprecher, Kapsel), Gegner-Symbole, Requisiten `counter`/`ticket_dispenser`/`number_display` für die Kulisse Amt | SD2 / SD3 |

Folgeänderungen: `README.md` (Extras; Dokument-Index — dort fehlen auch 08 und 09, vgl. die Folgeänderungen 08 F-9 und
09 Kap. 11.7 F-1), Screenshots nach SD2
(Kartentisch Desktop und Touch, Durchsage, Aktenschrank, Album, Ergebnis).

### 7.7 Risiken

| # | Risiko | W / A | Gegenmaßnahme | Frühindikator |
|---|---|---|---|---|
| S1 | Geteilte Klassen ändern sich mit dem Echtzeitkampf und verschieben das CTB-Verhalten | mittel / mittel | `test_sd_engine_golden` + `test_sd_golden` in CI, eingefrorene Engine-Dateien, `SD_VERSION` | Golden rot nach einem R-/ST-Merge |
| S2 | Das Spiel ist nicht spannend genug (zu viel Würfel oder zu wenig Entscheidung) | mittel / hoch | Zeit als einzige Ressource, Vorschau (sicherer Teil + Prognose), Harness-Bänder, Playtest-Gate vor dem Merge; im Prototyp liegt die Heuristik gegen Ulla 31 und gegen den Grafen 72 Punkte über Zufallsspiel — Können zählt | Playtest „Spaß“ < 4/5 |
| S3 | Kartentisch auf kleinen Telefonen überladen | mittel / mittel | 8 statt 10 Zettel, Fächer, Großansicht, Captures 1600 × 720 und 2400 × 1080 | Überlappung in `test_sd_ui` |
| S4 | Verwechslung mit dem Echtzeitkampf | niedrig / mittel | eigene Wörter (Geduld, Ärger, Werktag — nie HP, Schaden, Zug), eigener Bildschirm, keine Kampf-Signale | Playtest-Fragen |
| S5 | Sammel-Mühle | niedrig / mittel | feste Reihenfolge, ≈ 15–20 Siege für alles, keine Seltenheiten, Kampagne schaltet mit frei | Abbrüche vor Album 50 % |
| S6 | Name oder Bürokratie-Witz trifft Falsches | niedrig / hoch | Leitplanken Kap. 3.9, Wortliste im Validator, Markenrecherche, Distanz-Review | Review-Funde |
| S7 | Umfang wächst (mehr Karten, Modi, PvP) | mittel / mittel | SD2 fest auf 24 Karten + 4 Gegner; alles Weitere in Kap. 8 | neue Wünsche vor dem SD2-Gate |
| S8 | Startwerte und KI-Gewichte verfehlen die Bänder (der erste Entwurf des Endgegners war im Prototyp unschlagbar) | mittel / hoch | Regelbuch + Harness zuerst (SD2-A/B vor dem Tisch), Gewichte und Werte sind reine Daten, Bänder Kap. 6.9 in CI | Band rot in `test_sd_balance` |

---

## 8. Offene Fragen mit Empfehlung

| Nr. | Frage | Empfehlung |
|---|---|---|
| F-1 | Name: **„Stempelduell“** oder eine Alternative — **„Nummer bitte!“** (betont die Wartenummern) oder **„Formularfieber“** (betont das Kartensammeln)? | **„Stempelduell“** behalten: sagt in einem Wort, was passiert (Stempel + Duell), klingt nach Spieleshow und passt zum Titel „Stempelmeister:in“. „Nummer bitte!“ eignet sich als Untertitel der Wartenummern-Anzeige. Markenrecherche für den gewählten Namen [zu prüfen]. |
| F-2 | Bleibt „Extras → Stempelduell“, wenn es Etage 8 gibt? | **Ja**, als „Freies Spiel“ (der Zusatz „Vorschau“ entfällt): alle frei geschalteten Gegner, Album, Mappen — ohne Staffel-Belohnungen. Etage 8 bleibt der Ort mit Belohnung und KI-Gegnern. |
| F-3 | Etage 8 gehört zu **Akt 2** (Kaufinhalt, 09 CR-29). Gehört das Freie Spiel ins Grundspiel? | **Ja, ins Grundspiel** — als Vorgeschmack auf Akt 2 und weil es ohne Kampfkraft niemanden bevorzugt; die Staffel-Belohnungen gibt es nur mit Akt 2. Geschäftsentscheidung [festzulegen]. |
| F-4 | Darf das Gegenüber Show-Karten spielen? | **Nein.** Die Engine erlaubt Stunts nur der Party, und „Das Amt hat keinen Sinn für Show“ ist eine schöne, einfache Regel. Wenn Gegnerdecks später langweilig wirken: lieber neue Amt-Karten als Gegner-Stunts. |
| F-5 | Duo gegen Duo statt 1 gegen 1? | **Nein** für SD2/SD3: zwei Einheiten je Seite brächten Zielwahl, Kombos und doppelte Hände — doppelte Regeln. Nach dem Playtest neu bewerten; die Engine könnte es. |
| F-6 | Tagesregeln („Dienstanweisung des Tages“: z. B. „Heute Hand 4“, „Eilt-Karten +1 Ärger“) als Programmpunkt der Etagen 7–9 (09 Kap. 3.3)? | **Später, nach SD3**, nur als Daten in `rules.json` (Varianten mit eigenem `rules_hash`); bringt Abwechslung ohne neuen Code. |
| F-7 | Kaufbare Kartenrücken oder Stempelfarben (04 §6.2 erlaubt Kosmetik-Käufe)? | **Nein.** Ein Kartenspiel mit Shop riecht nach dem, was das Spiel verspottet; alles im Stempelduell wird erspielt. |
| F-8 | Duelle gegen Freund:innen? | **Kein Live-PvP.** Ab ST2 möglich: asynchrone „Geisterduelle“ gegen die Mappe und das KI-Profil einer Freundin und ein „Stempelduell der Woche“ mit festem Seed und Bestenliste — die Logs sind schon heute nachrechenbar (Kap. 6.6, 05). |
| F-9 | Eine Karte je **Vorleben** aus dem Casting (08), z. B. „Frische Brötchen“ für Bäcker:innen? | **Reizvoll, aber später**: 17 Vorleben = 17 Karten Inhaltsarbeit, und die Karte dürfte nur das Katalog-Vorleben kennen (Privatsphäre 08 P-1). Nach SD3 prüfen, gern als Kosmetik-Karte ohne Wirkung zuerst. |
| F-10 | Sammlung über Geräte hinweg? | Mit dem **Konto-Dienst aus 09 ST2**; bis dahin lokal (wie Titel und Kosmetik). |
| F-11 | Soll der Revier-Boss „Der Sachbearbeiter“ (09) selbst am Tisch sitzen? | **Nein.** Ferdi ist sein Azubi und erwähnt ihn; der Revier-Boss bleibt Gegner im Echtzeitkampf. So gibt es keine zwei „Sachbearbeiter“, und der Gag trägt über Etage 7–9. |
