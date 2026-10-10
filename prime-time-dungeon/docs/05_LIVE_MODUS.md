# PRIME TIME DUNGEON — Live-Modus „SHOWRUN“

> Grundlage: `00_BRIEF.md` (verbindlich, insb. Kap. 5 „Entscheidung Zuschauer-Geschenke“ und Kap. 6b „SHOWRUN“),
> `01_GDD.md` (Show-System Kap. 7, Achievements Kap. 8, Lootboxen Kap. 9, Etagen-Timer Kap. 2.9).
> `02_TECH.md` (verbindlicher Technik-Vertrag; letzter Abgleich 2026-10-10, Branch `ptd/final-a`) ist berücksichtigt: Kap. 11 verwendet dessen Namen
> (`SeedUtil`, `GameState`, `FloorRun`, `BattleState`, `BattleCommand`, `ActionEvent`, `SponsorSystem`, `Show`, Modul-/Testkonventionen).
> Was 02_TECH für SHOWRUN noch fehlt, steht als **Änderungsantrag** in Kap. 11.6 (gemäß 02_TECH §0.2 werden fremde
> APIs nicht eigenmächtig geändert, sondern im Vertrag beantragt).
>
> Konventionen: Fließtext Deutsch; IDs, Pfade, JSON-Keys, Signal- und Methodennamen Englisch.
> **[zu prüfen]** markiert reale Fakten (Gesetze, Plattformregeln, Dienste, Preise), die vor einer Entscheidung von
> Fachleuten (Recht, Steuern, Plattform-Support) verifiziert werden müssen. Nichts davon ist Rechtsberatung.
> Alle Zahlen (Preise, Limits, Kosten) sind **Startwerte/Schätzungen** für Planung und Playtests.
>
> Überarbeitet nach Review (Recht/Spielerschutz und Netcode/Determinismus): neue Leitplanken L11–L15, Seed-Klassen online,
> eine Simulationsuhr in Ticks, Ganzzahl-Kern, `RunSim` im Slice, Änderungsanträge CR-11 … CR-14.
>
> **Überarbeitet nach Nutzerentscheidung 2026-10-08** (Brief Kap. 5/6b): **(1)** Echtgeld von Zuschauer:innen fließt nur an
> Spiel/Betreiber, nie an Spieler:innen oder Streamer:innen — Creator-Beteiligung **gestrichen** (Kap. 8.8), Twitch Bits (B)
> nur noch **kostenlose Interaktion**, der **eigene Shop (C: Web-Shop + App-Store-IAP)** ist der primäre Echtgeld-Weg (Kap. 2,
> 6, 8, 9, 12; L11 neu). **(2)** Zuschauer:innen helfen nur begrenzt oft zu bestimmten Zeiten: **Sponsor-Fenster** (Kap. 6.13,
> L16; umgesetzt als `SponsorWindows`, CR-15).

---

## Inhalt

0. Leitplanken auf einen Blick
1. Modus-Übersicht SHOWRUN
2. Ausbau-Stufen S0–S5
3. Architektur
4. Netzwerk-Protokoll
5. Zuschauer / Spectating
6. Zuschauer-Interaktion (Votes, Geschenke, Sponsorkisten, Sponsor-Fenster)
7. Beweisbar faire Würfel (Provably Fair)
8. Monetarisierung & Zahlungsfluss (C: eigener Shop — primär; B: Twitch nur kostenlos)
9. Rechts- & Compliance-Checkliste
10. Datenmodelle
11. Was JETZT im Vertical Slice gebaut wird (S0 + Hooks)
12. Risiken & offene Fragen

---

## 0. Leitplanken auf einen Blick

Diese Leitplanken setzen die Nutzerentscheidungen aus Brief Kap. 5 um (2026-10-07; verschärft bzw. ergänzt 2026-10-08: L11, L16). Sie sind **nicht verhandelbar**, solange der Brief
nicht geändert wird. Jede Zeile nennt, wo sie technisch erzwungen wird.

| # | Leitplanke | Erzwungen durch |
|---|---|---|
| L1 | **Veröffentlichte Wahrscheinlichkeiten** pro Kiste, pro Wurf, pro Item — vor dem Kauf sichtbar. **Preis der Kiste** in Echtgeld (C: Web-Shop und App-Store). **Inhalte haben keinen Geldwert und werden nie in Echtgeld bewertet** — keine Euro-Werte für Items oder Credits auf Odds-Seite, im Shop oder in der Extension | Shop-UI (Web/App), Twitch-Extension-UI (nur Odds/Anzeige), öffentliche Odds-Seite (aus denselben Daten wie der Server generiert), `tables_hash` im Commit (Kap. 7) |
| L2 | **Pity-Garantie** (Käufer-Pity: spätestens jede 10. bezahlte Kiste mit epischem Wurf); Pity-Stand nur **auf Abruf** (Kaufhistorie/Spielerschutz-Center), nie als Kaufanreiz im Kauf-Flow | Gift-Service, verifizierbar über das Gift-Log (Kap. 6.8, 7) |
| L3 | **Lauf-gebundene Inhalte**: alles aus Geschenken verfällt mit Laufende; kein Handel, keine Übertragung, keine Auszahlung | Live-Läufe nutzen einen **frischen Lauf-Zustand** aus einem Preset, der nie in Kampagnen-Spielstände übergeht (Kap. 6.9) |
| L4 | **Caps pro Spieler/Lauf** mit **abnehmender Wirkung**; Kisten-Kauf gesperrt, sobald die Wirkung unter `chest_min_effect_pm` fällt (dann nur nicht-zufällige Geschenke) | `GiftPolicy` im Kern + Reservierung im Gift-Service vor dem Kauf (Kap. 6.10) |
| L5 | **Pur-Liga** ohne jegliche Zuschauer-Geschenke und ohne spielrelevante Votes | Liga-Wahl vor dem Lauf, Server lehnt Gifts ab (Kap. 1.5) |
| L6 | **Alter:** Käufer:innen **18+ für alle Echtgeld-Geschenke** (zufällig und nicht-zufällig, bis ein Gutachten anderes erlaubt); **Empfang** bezahlter Zufallskisten nur durch altersverifizierte Spieler:innen ab 18 (alle anderen fest `free_only`); Kisten-Kaufknöpfe nur für eingeloggte, altersverifizierte Konten | Account-/Wallet-Service, Kauf-Flow, Extension/Web-Viewer, `gift_accept`-Prüfung (Kap. 6.11, 8.9) |
| L7 | **Geo-Positivliste** für Zufallskisten: Kauf und Empfang nur in Ländern mit **positivem schriftlichem Gutachten**; Belgien und Niederlande ausdrücklich gesperrt **[zu prüfen]**; Land nicht feststellbar = gesperrt | Geo-Policy-Tabelle im Backend (Standard: verboten), Prüfung bei Kauf **und** Zustellung (Kap. 8.9) |
| L8 | **Nachprüfbare Server-Würfel** (Provably Fair): Commit vor dem Event (gebunden an Seed, Tabellen, Regeln, Daten), Seed danach; `client_seed` in **jedem** Kaufkanal (Web-Shop, App-IAP); **lückenloses** Gift-Log inkl. erstatteter Würfe | Fairness-Service, Commit-Reveal (Kap. 7) |
| L9 | **Kein Selbst-Beschenken**: Spieler kaufen sich selbst nichts Zufälliges (Brief Kap. 5) | Gift-Service: `buyer_account ≠ target_account`, Verknüpfungsprüfung (Zahlungsmittel, Gerät — Rechtsgrundlage **[zu prüfen]**, Kap. 9) |
| L10 | **Rechtsprüfung vor Launch** von S3/S5 ist Pflicht; für S2 eine Prüfung von Jugendschutz, DSA, DSGVO (Zuschauerdaten) und Twitch-Extension-Richtlinien | Exit-Kriterien S2, S3 und S5 (Kap. 2) |
| L11 | **Erlös nur an Spiel/Betreiber (Nutzerentscheidung 2026-10-08):** Echtgeld aus Zuschauer-Geschenken fließt **ausschließlich** an den Betreiber — nie an Spieler:innen (Crawler), nie an Streamer:innen; keine Auszahlung, keine Beteiligung (Creator-Beteiligung **gestrichen**, Kap. 8.8), kein Kaufkanal, dessen Erlös an Dritte geht (Twitch Bits → nur kostenlose Interaktion, Kap. 8.4). *Früher:* „kein Erlösfluss an Empfänger:innen aus Zufallskisten“ — durch die Entscheidung verschärft auf **alle** Geschenke | Ledger (keine Konten/Transaktionsarten für Auszahlungen an Personen, Kap. 8.3/10.3), Gift-Service (Kaufkanäle nur Web-Shop/App-IAP, Kap. 6.4), Kap. 8.4/8.8 |
| L12 | **Keine Glücksspiel-Optik**: keine Near-Miss-Effekte, keine künstliche Verzögerung, keine Slot-/Walzen-Optik, Ergebnis sofort sichtbar; nutzerseitig neutrale Begriffe („nachprüfbare Zufallsziehung“ statt „Provably Fair“/„Würfel“); öffentlicher Feed zeigt Stufe und (optional) Absender, **keine Inhalte** | Darstellung (Kap. 6.4), Feed (Kap. 4.6), Texte (Kap. 6.12) |
| L13 | **Kein Kaufdruck**: Dank-Zeilen unabhängig vom Preis, kein Spott über günstige/kostenlose Unterstützung, kein Pity-Countdown, Absendername standardmäßig anonym, keine Kaufaufrufe an Minderjährige | M.O.D.-Zeilen (6.12), Gift-Schema (`anon: true`), Creator-Richtlinien (Kap. 5.4) |
| L14 | **Echtgeld nur mit Server-Autorität**: Läufe, die bezahlte Geschenke empfangen, werden immer auf dem Dedicated Server simuliert; Umsatz wird erst bei serverseitig bestätigter Zustellung realisiert | Allokator, Gift-Service, Ledger (Kap. 2 S3, 6.4) |
| L15 | **Kein Token-Verfall** (mind. bis zur rechtlichen Klärung); **Erstattung des Restguthabens** bei Einstellung des Dienstes oder Kontolöschung | Wallet-Service, AGB (Kap. 8.2) |
| L16 | **Sponsor-Fenster (Nutzerentscheidung 2026-10-08):** Zuschauer:innen helfen **nur begrenzt oft zu bestimmten Zeiten** — externe Geschenke (außer kosmetischem `cheer`) nur in einem offenen Fenster (periodisch, Safe Room, Boss-Countdown), mit begrenzten Plätzen je Fenster und 1 Geschenk je Zuschauer:in und Fenster; **kein Kaufdruck durch die Fenster** (kein Countdown im Kauf-Flow, keine „nur noch X Plätze“-Werbung, keine M.O.D.-Kaufaufrufe, L13) | `RunSim`/`SponsorWindows` (Fahrplan in Ticks, Zustand im Hash), `GiftPolicy.check` (autoritativ, Kap. 3), Gift-Service (Platz-Reservierung bei der Quote, Kap. 6.4), Kap. 6.13 |

**Verhältnis zu GDD Kap. 9 („Kein Echtgeld … nirgends“):** Die im Spiel verdienten **Lootboxen** (Bronze/Silber/Gold/Fan
aus Achievements, Bossen, Meilensteinen) bleiben **unkäuflich** — in Kampagne **und** Live-Modus. Die hier beschriebenen
**Sponsorkisten** sind ein **separates System**, das ausschließlich im Live-Modus existiert, nur von Zuschauer:innen an
andere Spieler:innen verschenkt werden kann und lauf-gebunden ist. Der Fußzeilen-Text aus GDD 9.4 bleibt korrekt; im
Live-Modus ergänzt um: „Sponsorkisten von Zuschauer:innen: Wahrscheinlichkeiten unter *Odds-Link*.“ → GDD Kap. 9 sollte
einen Querverweis auf dieses Dokument erhalten (offener Punkt Kap. 12).

---

## 1. Modus-Übersicht SHOWRUN

### 1.1 Begriffe

| Begriff | ID-Präfix | Bedeutung |
|---|---|---|
| **Event** | `evt_` | Eine Sendung: Regeln, Quest, Etage, Zeitplan, Seed-Politik. Daten in `events.json` (Kap. 10.1). |
| **Fenster** (Window) | `win_` | Ein konkretes Zeitfenster eines Events (open/close). Ein Event kann mehrere rotierende Fenster haben. |
| **Lauf** (Run) | `run_` | Ein Versuch eines Solo-Spielers oder Teams innerhalb eines Fensters. Hat ein Run-Log (Kap. 10.6). |
| **Instanz** | `inst_` | Laufzeitobjekt auf dem Server, das genau einen Lauf simuliert (S4+). |
| **Team** | `team_` | 1–4 Spieler:innen, die gemeinsam einen Lauf spielen. Solo = Team der Größe 1. |
| **Liga** | `show` / `pur` | Wertungsklasse. Vor Laufstart gewählt, danach fix. |
| **Sponsorkiste** | — | Zuschauer-Geschenk mit Zufallsinhalt (Kap. 6.6). Nicht zu verwechseln mit Lootboxen (GDD 9). |
| **Sponsor-Token** | `ST` | Interne Kauf-Einheit des eigenen Shops (Variante C). |
| **Applaus** | `AP` | Kostenlose Fan-Währung, verdient durch Zuschauen (S2+). Kein Echtgeldwert, nicht kaufbar. |
| **Sponsor-Fenster** | `sw_` | Zeitspanne **innerhalb eines Laufs**, in der Zuschauer:innen helfen dürfen (Kap. 6.13): periodisch, im Safe Room, als Boss-Countdown. Nicht zu verwechseln mit dem **Fenster** eines Events (`win_`, Sendetermin). IDs `sw_<n>` je Lauf fortlaufend. |

### 1.2 Event-Kalender & Zeitfenster

**Event-Typen**

| Typ | `kind` | Ab Stufe | Zeitfenster | Versuche | Seed-Politik |
|---|---|---|---|---|---|
| Offline-Event-Lauf | `offline` | S0 | keins (immer offen) | unbegrenzt | `fixed` (Seed steht in den Daten) |
| Tagesquote | `daily` | S1 | 00:00–24:00 UTC | 1 gewerteter + beliebig Training | `commit_reveal` (Reveal am Folgetag) |
| Wochenshow | `weekly` | S1 | Mo 00:00 – So 23:59 UTC | 3 gewertete, bester zählt | `commit_reveal` |
| Live-Sendung | `live_show` | S2 (solo), S4 (Koop) | 90 min, 3 rotierende Fenster | 1 gewerteter pro Event | `commit_reveal` je Fenster |
| Großevent | `special` | S5 | angekündigter Termin, 1–3 Fenster | 1 gewerteter | `commit_reveal` |

**Zustände eines Fensters** (Server-Wahrheit, Clients bekommen sie per `event_window_changed`):

```
scheduled → announced (Commit + Odds + Regeln veröffentlicht, ≥ 24 h vorher)
          → open (Seed-abgeleitete Lauf-Daten werden ausgegeben, Einstieg möglich)
          → last_entry (kein neuer Laufstart mehr)
          → closing (laufende Läufe bekommen „Sendeschluss“-Countdown)
          → closed (alle Läufe beendet/abgebrochen, Wertung vorläufig)
          → revealed (Server-Seed veröffentlicht, Verifikation möglich, Wertung endgültig nach Replay-Prüfung)
          → archived (Replays/Bestenliste dauerhaft, Seed frei als „Wiederholung“ spielbar, ungewertet)
```

**Rotierende Fenster für Zeitzonen** (Beispiel „Samstagabend-Show“, alle Zeiten UTC; Ortszeiten bei Sommerzeit
abweichend, Backend rechnet nur in UTC):

| Fenster | `window_id` | open (UTC) | close (UTC) | Zielgruppe (Ortszeit ca.) |
|---|---|---|---|---|
| Europa | `eu` | Sa 19:00 | Sa 20:30 | 20:00–21:30 MEZ |
| Amerika | `am` | So 01:00 | So 02:30 | Sa 20:00 EST / 17:00 PST |
| Asien/Pazifik | `apac` | So 10:00 | So 11:30 | 19:00 JST / 21:00 AEDT |

- Jedes Fenster hat **eigenen Server-Seed und eigenen Commit** (verhindert, dass frühe Fenster späteren die Karte verraten).
- Bestenliste **pro Fenster** (direkt vergleichbar: gleicher Seed) + **Event-Gesamtwertung** nach **Perzentil im eigenen
  Fenster** (fair trotz unterschiedlicher Seeds). Ein Account darf pro Event nur in **einem** Fenster gewertet spielen.

**Spät-Einstieg & Sendeschluss**

| Regel | Wert / Formel |
|---|---|
| Lauf-Wanduhr-Limit | `rules.max_run_wall_sec` (Standard 2 700 s = 45 min) |
| Letzter Einstieg | `last_entry_at = close_at − max_run_wall_sec` (Standard). Option `late_entry: "none"` = nur in den ersten 10 min |
| Spät-Einsteiger | Keine Strafe (eigene Laufzeit zählt), Markierung `late_entry` in der Bestenliste (rein informativ) |
| Koop-Nachrücker | Nur Lobby oder Safe Room, nur solange `floor_timer_left ≥ 50 %`; Lauf erhält Flag `roster_changed` |
| `closing` | 5 min vor `close_at`: M.O.D.-Ansage `live_closing`, Countdown im HUD |
| Hartes Ende | Bei `close_at + 120 s` werden alle Läufe beendet: Ergebnis = aktueller Quest-Fortschritt, Ursache `window_closed` |

**Timer-Modi** (Feld `rules.timer_mode`):

| Modus | Verhalten | Einsatz |
|---|---|---|
| `explore_only` | wie GDD 2.9: Etagen-Timer läuft nur in Erkundung | Solo-Events (S0–S3), Kampagnen-nah |
| `realtime` | Etagen-Timer läuft immer (auch in Kampf, Safe Room, Menüs), Kämpfe haben Zug-Timer | Koop (S4+), Live-Sendungen mit vielen Teams: alle Teams haben dieselbe Wanduhr → spannender für Zuschauer |

Im `realtime`-Modus: Pausemenü pausiert nichts (Hinweis „LIVE — keine Pause“), Safe Room heilt weiterhin, Zug-Timer
im Kampf `rules.turn_timeout_sec` (Standard 20 s, Ablauf → `defend`). Startwert des Etagen-Timers in `realtime`:
`rules.floor_timer_sec` (Standard 2 100 s = 35 min, weil Kämpfe mitzählen).

### 1.3 Quest-Typen (als Daten)

Eine Quest ist ein Dictionary `{ "type": String, "params": Dictionary, "label_key": String }`. Mehrere Quests werden
mit `all_of` / `sequence` kombiniert. Ausgewertet von `QuestTracker` (Kern, Kap. 11) **ausschließlich über Kern-Events**
(dieselben Payloads wie GDD 8), dadurch deterministisch und im Replay identisch.

| `type` | Ab | `params` (Beispiel) | Erfüllt wenn | Fortschritt (0–1) |
|---|---|---|---|---|
| `reach_stairs` | S0 | `{ "floor": 1 }` | Event `floor_completed` mit `floor == params.floor` | Anteil erkundeter Zonen (A–D) × 0.9 |
| `defeat_boss` | S0 | `{ "boss_id": "boss_hausmeister" }` | Event `boss_defeated` mit passender `boss_id` | 1 − Boss-HP-Anteil beim besten Versuch (0 wenn nie begegnet) |
| `bounty` | S0 | `{ "enemy_id": "kanalratte", "count": 12 }` | Zähler `enemy_killed` mit `enemy_id` ≥ `count` | Zähler / `count` |
| `hype_peak` | S0 | `{ "metric": "viewers_target_peak", "target": 5000 }` (E1-Peak 3 000–5 500, GDD 13) | Metrik erreicht Zielwert (`viewers_target_peak`, `followers_gained_run`, `hype_100_count` — neue `StatIds`, CR-13) | Metrik / Ziel |
| `pacifist` | S0 | `{ "max_battles": 3, "then": { "type": "reach_stairs", "params": { "floor": 1 } } }` | Unterquest erfüllt UND Kämpfe ≤ `max_battles` (Bosse zählen mit) | Fortschritt der Unterquest; 0 sobald Limit überschritten |
| `achievement_hunt` | S0 | `{ "ids": ["ach_overkill", "ach_combo_first", "ach_close_call", "ach_stunt_first"], "min": 3 }` | ≥ `min` der gelisteten Achievements im Lauf erhalten | erhalten / `min` |
| `collect` | S1 | `{ "item_id": "item_golden_ticket", "count": 7, "spawn": { "chests": 5, "drops": 4 } }` | Quest-Items im Inventar ≥ `count` (Platzierung aus Seed-Stream `quest`) | Anzahl / `count` |
| `rescue` | S4 | `{ "npc_id": "npc_brettschneider", "from": "zone_b", "to": "safe_room_c" }` | NPC lebend im Ziel (NPC folgt wie Mopsula, kann KO gehen) | Weganteil |
| `all_of` | S0 | `{ "quests": [ … ] }` | alle Unterquests erfüllt | Mittelwert |
| `sequence` | S1 | `{ "steps": [ … ] }` | Schritte in Reihenfolge erfüllt | (erledigte + Fortschritt aktueller) / Anzahl |

Beispiel (Live-Sendung „Gleis-9-Räumung“):

```json
{
  "type": "all_of",
  "label_key": "quest_gleis9_clearance",
  "params": {
    "quests": [
      { "type": "defeat_boss", "params": { "boss_id": "enm_boss_rattenkoenigin" } },
      { "type": "achievement_hunt", "params": { "ids": ["ach_overkill", "ach_combo_first", "ach_close_call"], "min": 2 } }
    ]
  }
}
```

### 1.4 Spielformen: Solo, Koop (2–4), Parallel-Teams

| Form | Ab | Party | Steuerung | Besonderheiten |
|---|---|---|---|---|
| **Solo** | S0 | Kai + Graf Mopsula (wie Kampagne) | eine Person | Party-Stand aus `rules.party_preset` (Level, Ausrüstung) — **nicht** aus dem Kampagnen-Spielstand |
| **Koop 2** | S4 | Kai + Mopsula | Person A steuert Kai, Person B steuert **Mopsula** | Mopsula wird in Erkundung frei steuerbar (statt NavigationAgent-Folgen); im Kampf befehligt jede Person ihre Einheit |
| **Koop 3–4** | S4 (Inhalt nötig) | Kai + Mopsula + 1–2 weitere Kandidat:innen | je Person 1 Figur | benötigt spielbare Zusatzfiguren → Klassen aus `classes.json` (GDD 12) als Vorlage; **Inhaltsarbeit, nicht im Slice** |
| **Parallel-Teams** | S2 (solo), S4 (Koop) | beliebig viele Teams, je eigene Instanz | — | keine direkte Interaktion; gleiche Etage (Seed), Spoiler-Schutz per Fog-of-War im Zuschauerstrom + Symmetrie-Varianten an der I/O-Grenze (Kap. 5.3); gemeinsame Bestenliste und gemeinsamer Zuschauer-„Senderwechsel“ |

**Koop-Kampfregeln (CTB) — Entscheidung: pro Team immer genau ein Kampf.**
- Löst ein Teammitglied einen Kampf aus, werden **alle** Teammitglieder hineingezogen — in beiden Timer-Modi
  (Darstellung: „Regie-Schnitt“, Figuren erscheinen in der Kampfarena). Es gibt keine parallelen Kämpfe eines Teams und
  keine Erkundung während eines Kampfes. Damit bleibt `BattleSetup.items` (Kopie des Team-Inventars, Rückfluss über
  `item_delta`/`credits_delta` nach Kampfende) konsistent: niemand kann gleichzeitig dasselbe Inventar nutzen
  (`menu_use_item`, `vendor_buy` sind während eines Kampfes für das ganze Team gesperrt; der Server serialisiert alle
  Team-Inventar-Commands ohnehin in Tick-Reihenfolge).
- Die Party im Kampf ist immer die vollständige Team-Party (Kai + Mopsula [+ Zusatzfiguren]); eine „Party ohne Mopsula“
  gibt es nicht. Getrennte oder verbindungslose Mitglieder kämpfen per Autopilot (Kap. 3.6).
- Nachzügler (Reconnect, Koop-Nachrücker) treten an einer **Zuggrenze** bei: `ctr = base_delay` (voller Zug), max. bis zum 3. Party-Zug
  (`battle_join`, Kap. 4.5).
- Jede Person befehligt nur eigene Einheiten; Zug-Timer `turn_timeout_sec` (in Ticks umgerechnet, Kap. 3.2); Ablauf → `defend` (Hype-Malus „Langweilig“ gilt).
- Hype/Zuschauer sind **pro Team** (eine Sendung), Follower-Gewinn wird gleich verteilt. Weil es pro Team nur einen Kampf
  gibt, genügt ein `ShowRules`-Kontext je Team-Instanz; der Server-Kern führt ihn trotzdem je `battle_id` (Vorbereitung für
  eine spätere Variante mit parallelen Kämpfen).
- Kampfbeute: Credits geteilt (gleich, Rest an Auslöser), Items gehen in ein **Team-Inventar** (keine Verteilungs-Streitereien).
- *Spätere Option (nicht geplant):* mehrere parallele Kämpfe eines Teams nur mit Inventar-Escrow beim Kampfstart (Items
  wandern in ein Kampf-Escrow, Rückbuchung nach Kampfende), `ShowRules` pro `battle_id` und eigenem `BattleSetup` für
  Teil-Parties — erst nach eigener Design- und Netcode-Prüfung.

**Ghost-Interaktion zwischen Parallel-Teams (optional, S4):** „Gedenktafeln“ an Stellen, wo andere Teams im selben
Fenster gescheitert sind (Daten nur aus bereits **verzögerten** Zuschauer-Daten, Kap. 5.2) — Atmosphäre, kein Gameplay.

### 1.5 Wertung & Bestenlisten

**Punkteformel** (Standard, überschreibbar in `events.json → scoring`; nur Ganzzahlen):

```text
quest_pts   = completed ? scoring.complete : floor(scoring.progress_max * progress)        # 10000 / 5000
time_pts    = completed ? floor_timer_left_sec * scoring.per_sec_left : 0                 # 5 je Sekunde
show_pts    = min(followers_gained, scoring.follower_cap) * scoring.per_follower          # Cap 3000, ×1
ach_pts     = achievements_in_run * scoring.per_achievement                               # 100
ko_pen      = party_kos * scoring.per_ko                                                  # −150
score       = quest_pts + time_pts + show_pts + ach_pts + ko_pen
```

Tie-Break: `score` absteigend → `run_wall_ms` aufsteigend → `finished_at` aufsteigend. Beide Werte sind **serverseitig**:
`run_wall_ms` = Zeitraum zwischen vom Server ausgestelltem Run-Start-Ticket und Server-Eingang des Run-Logs (Async) bzw.
Instanz-Start/-Ende (Server-Sim), gedeckelt auf `max_run_wall_sec`; `finished_at` = Server-Eingangszeitpunkt. Client-gemessene
Zeiten gehen nie in die Wertung ein. `floor_timer_left_sec` ist in Grad A (Kap. 3.3) clientgemeldet → Wertung bis Grad B nur
„vorläufig/plausibilitätsgeprüft“ (Kap. 2, S1).

**Zwei Ligen:**

| | **Show-Liga** (`show`) | **Pur-Liga** (`pur`) |
|---|---|---|
| Zuschauer-Geschenke (bezahlt & kostenlos) | erlaubt (mit Caps, Kap. 6.10, nur in Sponsor-Fenstern, Kap. 6.13) | **gesperrt** (Server lehnt ab, Shop zeigt „Pur-Liga — keine Geschenke“; keine Sponsor-Fenster) |
| Votes | alle (auch spielrelevante Twists) | nur kosmetische Votes |
| Zuschauen, Applaus/Cheers | ja | ja (rein kosmetisch) |
| System-Sponsor-Geschenke (Hype-Schwellen, GDD 7.4) | ja | **ja** (Teil des Grundspiels, nicht von Zuschauern) |
| Kennzeichnung | Lauf mit ≥ 1 bezahltem Geschenk: Flag `sponsored`, Badge **„gesponsert“** + Anzeige Geschenk-Last | — |
| Rang-Belohnungen | Läufe **ohne** bezahlte Geschenke: Show-Titel (Kap. 1.6); Läufe mit `sponsored`: **nur Teilnahme-Plakette** | Titel **und** kosmetische Rang-Belohnungen |
| Wahl | **bewusstes Opt-in** vor jedem Lauf (auch für Streamer:innen, kein Standard); bezahlte Zufallskisten nur für altersverifizierte Spieler:innen ab 18 (L6, Kap. 6.11) | **Standard für alle** |

**Bestenlisten** (`board_id = <event_id>|<window_id>|<league>|<mode>`, Kap. 10.4): pro Fenster, pro Event (Perzentil),
Freunde, Region (aus Fenster, nicht aus Geo-IP). Einträge sind bis zur **Replay-Verifikation** „vorläufig“ (Kap. 3.7).
Annullierung bei: Verifikationsfehler, nachgewiesener Absprache-Betrug (z. B. gestohlene Zahlungsmittel für Geschenke an
Freund:innen), Ban.

### 1.6 Belohnungen nach dem Event

Grundsatz: **Nichts, was man (direkt oder indirekt) kaufen kann, wirkt dauerhaft.** Event-Belohnungen landen im
**Live-Profil** (`profile.live`), nie im Kampagnen-Spielstand. Daraus folgt verbindlich: **Läufe mit Flag `sponsored`
(≥ 1 bezahltes Geschenk) erhalten ausschließlich die Teilnahme-Plakette.** Quest-Kosmetik, Rang-/Perzentil-Titel,
Live-Follower und „Publikumsliebling“ gibt es nur für Läufe ohne bezahlte Geschenke (Pur-Liga oder Show-Liga ohne
`sponsored`). So kann eine bezahlte Kiste (z. B. `item_hype_megaphone` → Follower, Quest-Erfüllung) keine dauerhafte
Belohnung auslösen [Bedeutung für die Glücksspiel-Einordnung „kein Gewinn/kein Vermögenswert“ **zu prüfen**, Kap. 9].
Umgesetzt im Feld `rewards` (Kap. 10.1: `sponsored_runs: "participation_only"`).

| Belohnung | Bedingung | Liga | Wirkung |
|---|---|---|---|
| Sendeplakette (Teilnahme) | Lauf gestartet | beide (auch `sponsored`) | Profil-Abzeichen mit Event-Name |
| Quest-Kosmetik (z. B. Mopsula-Hut „Gleis-9-Zylinder“) | Quest erfüllt, Lauf **nicht** `sponsored` | beide | Kosmetik (Live-Modus und, rein optisch, Kampagne) |
| Perzentil-Titel „Top 1 % / 10 % / 50 %“ | Rang im Fenster, Lauf **nicht** `sponsored` | **Pur**: Titel + Profilrahmen; **Show**: nur Titel mit Zusatz „(Show)“ | rein kosmetisch |
| **Live-Follower** (`profile.live.followers`) | `followers_gained_run` des Laufs, Cap 2 000 pro Event, Lauf **nicht** `sponsored` | beide | eigener Zähler, schaltet Profilrahmen/Studio-Deko frei; **kein Transfer** zu Kampagnen-Followern (die Lootbox-Meilensteine auslösen, GDD 7.7) |
| Publikumsliebling | meistgesehener Lauf des Fensters, Lauf **nicht** `sponsored` | Show | Titel |

Ausgeschlossen: Items, Credits, Lootboxen, EXP, Kampagnen-Follower, alles mit Gameplay-Wirkung, alles Handelbare.

---

## 2. Ausbau-Stufen S0–S5

| Stufe | Kern-Lieferung | Server | Echtgeld | Abhängigkeiten |
|---|---|---|---|---|
| **S0** | Offline-Event-Lauf (fester Seed, Timer, Quest, lokale Bestenliste) | keiner | nein | Vertical Slice |
| **S1** | Async Tages-/Wochen-Seeds, Online-Bestenliste, Replays | Backend + Replay-Verifier | nein | Accounts, deterministische Erkundung (Grad B für gewertete Listen) |
| **S2** | Live-Zuschauen, Votes, kostenlose Fan-Währung | + Spectator-Pipeline | nein | Event-Stream, Delay, Prüfung Jugendschutz/DSA/DSGVO |
| **S3** | Echtgeld-Geschenke über den **eigenen Web-Shop (C)**, nur in Sponsor-Fenstern; Twitch-Extension nur kostenlos | + Shop-API, MoR/PSP, Ledger, Fairness-Service, Server-Sim (Solo), Spielerschutz-Center, EBS (gratis) | **ja (C Web)** | **Rechtsprüfung**, MoR/PSP-Eignung, Grad B, Altersverifikation |
| **S4** | Koop 2–4 auf Dedicated Server | + Godot-Headless-Flotte | (C) | Netcode, Koop-Inhalte |
| **S5** | Große geplante Live-Events + **App-Store-IAP (C mobil)** | + IAP-Belegprüfung, Skalierung | **ja (C Web + App)** | **Rechtsprüfung** Store-Regeln, Steuern |

*Stufen-Umbau nach Entscheidung 2026-10-08:* S3 hieß „Echtgeld-Geschenke via Twitch Bits“ und S5 „+ eigener Shop“. Weil
Bits-Erlöse nach unserem Kenntnisstand an die Broadcaster:in gehen **[zu prüfen]** — unvereinbar mit „Echtgeld nur an den
Betreiber“ (L11) —, ist der eigene Shop vorgezogen (S3 Web, S5 App) und B nur noch kostenlose Interaktion. Bits mit
Spielwirkung kämen nur in Frage, wenn ein Erlösmodell für Entwickler existiert, das L11 erfüllt **[zu prüfen]** — dann als
eigene, neu zu prüfende Stufe.

### S0 — Offline-Event-Lauf (Teil des Vertical Slice)
Umfang: Titelmenü-Eintrag „Event-Lauf“, Event aus `res://data/events.json` (fester Seed, Quest, `timer_mode: explore_only`),
Party-Preset, Quest-HUD, Ergebnis-Bildschirm mit Punkteaufschlüsselung, lokale Bestenliste (Top 10 je Event,
`user://leaderboards/<event_id>.json`), Run-Log-Aufzeichnung + Wiedergabe (headless), alle System-Sponsor-Geschenke über
das Gift-Format (Kap. 6.5).
**Exit-Kriterien** (Stand 2026-10-10; abgehakt = durch die genannten Tests belegt):
- [ ] Event-Lauf von Titel bis Ergebnis spielbar (Tastatur/Gamepad), Quest-Typen `reach_stairs`, `defeat_boss`, `bounty`, `hype_peak`, `pacifist`, `achievement_hunt`, `all_of` in Tests grün.
  *Teilweise:* alle Quest-Typen grün in `test_m8_quest_tracker.gd`; Lobby, Ergebnis-Screen und Fokus-Navigation in
  `test_m6_menus.gd` (`test_event_lobby_lists_offline_events`, `test_run_result_shows_breakdown_and_total`) und
  `test_m6_ui_scenes.gd`; Event-Lauf über die `Game`-Fassade in `test_m8_replay.gd::test_game_event_run_replays_through_the_facade`.
  **Offen:** ein automatisierter Durchlauf Titel → Event-Lauf → Ergebnis mit den echten Screens (der Full-Run-Bot spielt
  nur die Kampagne) und ein Handtest mit Gamepad.
- [ ] **Replay-Gleichheit (Grad A, Kap. 3.3):** 20 aufgezeichnete Bot-Läufe (Autoplay) ergeben bei Wiedergabe exakt denselben `state_hash` (Kämpfe, Beute, Show-Werte, Quest, Punkte).
  *Teilweise:* der Full-Run-Bot prüft bei jedem Safe-Room-Besuch `Game.replay_log` ≡ Live-`StateHash` und leere `errors`
  (CI: 3 Strategien je Lauf, 02_TECH §11.4.1); `test_m8_replay.gd` (Bot-Lauf bitgenau, gleicher Seed → gleicher Hash).
  **Offen:** die Serie von 20 Läufen mit Event-Quest und Punkten als eigener Gate-Schritt.
- [x] Lint-Test: kein `randf()`, `randi()`, `randomize()`, `Time.`, `OS.get_ticks` in `res://core/` (Kap. 11.4) —
  `test_m8_no_global_rng.gd` (ohne Ausnahmen, inkl. der Gleitkomma-Funktionen aus CR-12).
- [ ] **Plattform-Matrix** (Pflicht, auch für S1/S4 und vor jedem `sim_version`-Bump): Linux x86-64 (Referenz = späterer
  Server/Verifier) gegen Windows x64, Android arm64, iOS bzw. macOS arm64 (Apple Silicon) und Web (wasm) — je mindestens
  **20 Bot-Läufe** mit identischem `final_hash` und identischen Checkpoint-Hashes. CI headless mit mindestens einem
  **arm64-Runner** (z. B. Linux arm64); Mobile über Device-Farm oder dokumentiertes manuelles Gate.
  **Offen:** bisher läuft nur Linux x86-64 (lokal und CI); es gibt weder arm64-Runner noch Geräte-Läufe.
- [x] `RunSim` (dünne Variante, CR-6) treibt den Bot-Lauf **ohne Autoloads**; `test_m8_replay` läuft headless gegen `RunSim` —
  `test_m8_replay.gd::test_bot_run_replays_bit_for_bit`, `test_m8_run_sim.gd`.
- [x] Lokale Bestenliste übersteht Neustart; korrupte Datei → wird verworfen, Spiel läuft weiter —
  `test_m8_leaderboard.gd` (`test_persistence_through_save`, `test_corrupt_data_gives_an_empty_board`).

### S1 — Async Seeds, Online-Bestenliste, Replays
Umfang: Accounts (Gast + Plattform-Login), Event-Kalender vom Server, Tagesquote/Wochenshow mit Commit-Reveal-Seeds,
Upload Run-Log nach Laufende, **serverseitige Replay-Verifikation** (Godot headless, nur `core/`), Online-Bestenlisten,
Replays ansehen (Download Run-Log → lokale Wiedergabe), Wiederholungs-Modus nach Reveal.
**Festlegung:** **Grad B** (Kap. 3.3) ist Voraussetzung für **gewertete** Online-Bestenlisten und für jede Echtgeld-Stufe.
Solange nur Grad A existiert, laufen S1-Bestenlisten als **„plausibilitätsgeprüft/ungewertet“** (Kennzeichnung in UI und
`verified: "plausible"`), weil Begegnungs-Vorteil, Truhenreihenfolge und verbrauchte Zeit in Grad A clientgemeldet sind.
**Exit-Kriterien:**
- [ ] Verifier lehnt 100 % einer Suite manipulierter Logs ab (geänderte Befehle, Zeitsprünge, falscher `data_hash`,
  nicht-monotone `cmd_id`); **mit Grad B** zusätzlich unmögliche Bewegungen (Eingabe-Frames, Kap. 3.3). Ohne Grad B ist
  dieses Kriterium nur für die Plausibilitätsregeln erfüllbar → Liste bleibt ungewertet.
- [ ] Verifier-Budget auf Basis einer **Messung im Slice** festgelegt (Benchmark `ExploreSim` 45 000 Ticks headless + Kämpfe);
  Planwert **≤ 10 s CPU pro 25-min-Lauf** (1 vCPU). Warteschlange ≤ 5 min bei 1 000 Uploads/h → bei 10 s/Lauf ≈ 2,8 vCPU
  Dauerlast, also **≥ 4 vCPU** Verifier-Pool (mit Spitzenpuffer 6–8).
- [ ] 0 Desyncs in 1 000 Bot-Läufen zwischen Client-Ergebnis und Verifier, über die Plattform-Matrix (S0).
- [ ] Datenschutz: Verarbeitungsverzeichnis, Datenschutzerklärung, Löschkonzept (Kap. 9) — **[zu prüfen]** durch Fachperson.
- [ ] Replay-Größe ≤ 100 KB (gzip) für einen 25-min-Lauf.

### S2 — Live-Zuschauen, Votes, kostenlose Fan-Währung
Umfang: Client streamt Lauf-Events live an die Spectator-Pipeline (Client-Simulation, Server verifiziert danach),
Delay 15–30 s, In-Game-Zuschauermodus + Web-Viewer, Votes (Twists, Kap. 6.2), Applaus (AP) + kostenlose Fan-Pakete
über `Show.receive_gift` (Quelle `fan`), Moderation (Namensfilter, Melden). Fan-Pakete sind **optisch klar** von bezahlten
Sponsorkisten getrennt (eigene Form/Farbe „Applaus-Paket“, kein Kisten-Modell, kein Stufen-Schema).
Client-Sim-Modus: Gratis-Gifts tragen `deliver_by_tick` (Kap. 6.5); der Verifier lehnt Läufe ab, die ein Gift nicht bis dahin
anwenden oder es weglassen.
**Exit-Kriterien:**
- [ ] 500 gleichzeitige Zuschauer auf einem Lauf, Ende-zu-Ende-Verzögerung = konfiguriertes Delay ± 2 s.
- [ ] Lasttest Gateway ausdrücklich mit **einem großen Einzellauf (5 000 Zuschauer)**, nicht nur vielen kleinen; Frames
  einmal pro Lauf vorkodiert (Kap. 4.1).
- [ ] Vote-Ergebnis kommt bei ≥ 99 % der Votes innerhalb von 5 s nach Vote-Ende im Spiel an.
- [ ] Fan-Pakete erscheinen im Replay identisch (Gift ist Teil des Run-Logs); Verifier prüft `deliver_by_tick`.
- [ ] Pur-Liga-Läufe: Server lehnt 100 % der Gifts ab (Test).
- [ ] **Rechts-/Jugendschutz-Prüfung S2** liegt schriftlich vor: Jugendschutz (USK/IARC-Angaben inkl. Votes, Fan-Pakete,
  Interaktionsrisiken), DSA (Melde-/Abhilfeverfahren, Moderation), DSGVO für Zuschauerdaten (auch Minderjähriger),
  Twitch-Extension-Richtlinien **[zu prüfen]**.

### S3 — Echtgeld-Geschenke über den eigenen Web-Shop (C)
*Bis 2026-10-08 hieß diese Stufe „Echtgeld-Geschenke via Twitch Bits“ — **gestrichen per Entscheidung 2026-10-08**: Bits-Erlöse
gehen nach unserem Kenntnisstand an die Broadcaster:in **[zu prüfen]**, Echtgeld darf aber nur an den Betreiber fließen (L11).*
Umfang: **Web-Shop** mit Sponsor-Token und Euro-Direktkauf über Merchant of Record/PSP (Kap. 8.5), Shop-API, Ledger,
Fairness-Service (Commit-Reveal für Kisten), Odds-Seite, Käufer-Pity, Caps, **Sponsor-Fenster** (Kap. 6.13: Quote nur bei offenem
Fenster, Platz-Reservierung), Geo-Policy (Positivliste), Altersnachweis-Kopplung, **Spielerschutz-Center** (Limits in EUR,
Selbstsperre, Kaufhistorie, „heute/Monat ausgegeben“) am altersverifizierten PTD-Konto. Die **Twitch-Extension** (Overlay/Panel)
bietet nur **kostenlose** Funktionen: Votes, Applaus/Fan-Pakete, Anzeige des Sponsor-Fensters und der Odds; ein Hinweis bzw.
Link auf den Web-Shop nur, soweit die Twitch-Richtlinien das erlauben **[zu prüfen]**. Erlös ausschließlich an den Betreiber.
**Regel (L14):** Läufe, die bezahlte Geschenke empfangen können, werden **immer auf dem Dedicated Server** simuliert
(Server-Kern aus S4 vorziehen, ohne Koop). Client-Simulation + Verifikation ist für Echtgeld **nicht** zulässig, weil der
Client sonst Zeitpunkt und Anwendung der Kiste bestimmt — **und die Sponsor-Fenster** (Kap. 6.13). Voraussetzung: Grad B (Kap. 3.3).
**Exit-Kriterien:**
- [ ] **Schriftliche Rechtsprüfung** für alle Länder der Positivliste liegt vor; Geo-Policy schaltet **genau diese** Länder
  frei (Kap. 8.9, 9). (Die frühere Gutachtenfrage „Erlösfluss an Empfänger:in“ entfällt durch L11 — es gibt keinen.)
- [ ] MoR/PSP schriftlich geeignet für virtuelle Währung, Zufallsinhalte, Geschenke an Dritte und Geo-Sperren **[zu prüfen]**.
- [ ] Twitch-Extension-Review für die **kostenlosen** Funktionen bestanden; Richtlinie zu Hinweisen auf externe Käufe geklärt
  **[zu prüfen]**.
- [ ] **Kein Kisten-Kauf ohne aktive Limits:** Ausgabelimits (EUR), Selbstsperre, Kaufhistorie und Anzeige
  „heute/Monat ausgegeben“ sind live, an die verifizierte Identität gekoppelt (konto-übergreifend) und durch Tests belegt.
- [ ] Altersverifikation (18+) für Käufer:innen **und** Empfänger:innen bezahlter Zufallskisten aktiv; offene Frage 12.2-#6 entschieden.
- [ ] Ledger: tägliche Abstimmung gegen PSP/MoR-Berichte ohne Differenz über 14 Tage Beta; **keine** Konten oder
  Transaktionsarten für Auszahlungen an Personen (L11, Kap. 10.3).
- [ ] Verifikationswerkzeug reproduziert 100 % der Kisten eines Beta-Events nach Reveal, **inkl. erstatteter/nicht
  zugestellter Würfe**, und meldet keine Nonce-Lücken.
- [ ] `client_seed` wird in **jedem** Kaufkanal bereits beim Quote übertragen (Kap. 6.4) — sonst darf der Kanal nicht als
  „nachprüfbar“ beworben werden.
- [ ] **Sponsor-Fenster:** Quote nur bei offenem Fenster mit freiem Platz (sonst `E_WINDOW_CLOSED`/`E_WINDOW_FULL` mit
  `next_window_in_sec`), Reservierung hält bis zur Zustellung (Gnadenfrist `grace_sec`), Instanz und Verifier lehnen Geschenke
  außerhalb ab — durch automatisierte Tests belegt; Kauf-Flow ohne Countdown-/Knappheitsdruck (L16, R15) geprüft.
- [ ] Caps/Limits/Geo-Sperre durch automatisierte Tests + manuellen Pen-Test belegt.
- [ ] Externer Audit (Kap. 7.7) inkl. Fehlerpfade (Erstattung, Timeout, Cap-Kollision, Fenster-Ende während der Zahlung) abgeschlossen.

### S4 — Koop 2–4 mit Dedicated Server
Umfang: Godot-headless-Server (Kap. 3.2), Matchmaking/Lobbys, Positions-Sync, CTB-Lockstep, Reconnect, Koop-Regeln
(Kap. 1.4), `realtime`-Timer, Symmetrie-Varianten für Parallel-Teams, Koop-Inhalte (Zusatzfiguren) für 3–4.
**Exit-Kriterien:**
- [ ] 4 Spieler bei 150 ms RTT / 2 % Paketverlust spielbar (Playtest-Bewertung ≥ 4/5) — **gemessen mit WebSocket und mit
  dem unzuverlässigen Kanal (ENet/UDP bzw. WebRTC DataChannel) im direkten Vergleich** (Kap. 4.1).
- [ ] 0 Desyncs in 10 000 simulierten Koop-Kämpfen (Bot-Clients), wobei Bot-Clients über die **Plattform-Matrix** (S0)
  verteilt laufen — insbesondere Linux-x64-Server gegen ARM-Clients (Android/iOS/Apple Silicon).
- [ ] Reconnect mitten im Kampf über `resync_state{battle_snapshot, battle_log_tail}` (CR-14) getestet: Snapshot →
  `from_dict` → gleicher `StateHash.of_battle`.
- [ ] Wiederanlauf einer Instanz nach Prozess-Crash aus Run-Log + Checkpoint in einem neuen Prozess (Kap. 3.9) getestet.
- [ ] Reconnect innerhalb 120 s gelingt in ≥ 99 % der Testfälle ohne Zustandsverlust.
- [ ] Server-Tick-Budget: p99 < 5 ms pro Instanz-Tick bei Ziel-Packungsdichte (Kap. 3.9).

### S5 — Große geplante Live-Events + App-Store-IAP (C mobil)
Umfang: Event-Ankündigung mit Anmeldung, vorab hochskalierte Flotte, CDN-Segment-Auslieferung für Zuschauer,
**In-App-Kauf über App Store / Google Play** als zweiter Kanal des eigenen Shops (Kap. 8.5; Belegprüfung nur serverseitig),
Erstattungen/Chargebacks kanalübergreifend, Spielerschutz-Center um IAP-Käufe erweitert (EUR-Limits, Verlauf, Selbstsperre
gelten kanalübergreifend), Kaufprozess nach Verbraucherrecht (Kap. 6.4, 9). Twitch Bits bleiben kostenlose Interaktion —
**außer** es wird ein Bits-Erlösmodell für Entwickler nachgewiesen, das L11 erfüllt **[zu prüfen]**; das wäre eine eigene,
neu zu prüfende Stufe. ~~Später Creator-Beteiligung~~ — **gestrichen per Entscheidung 2026-10-08** (Kap. 8.8).
**Exit-Kriterien:**
- [ ] Lasttest: 10 000 gleichzeitige Spieler:innen, 100 000 Zuschauer:innen, Fehlerquote < 0.1 %.
- [ ] **Rechtsprüfung IAP** (Store-Regeln für Geschenke an andere Nutzer:innen und Odds-Offenlegung, Verbraucherrecht, Steuern,
  Glücksspiel, Jugendschutz) liegt schriftlich vor **[zu prüfen]**.
- [ ] Ledger-Abstimmung gegen PSP/MoR- und App-Store-Auszahlungsberichte monatlich ohne ungeklärte Differenz.
- [ ] Chargeback-Quote im Beta-Monat < 0.5 % (Schwelle **[zu prüfen]** je PSP).

---

## 3. Architektur

### 3.1 Überblick

```
                         ┌──────────────────────── Backend ─────────────────────────┐
 Spieler-Client ──WSS──► │ Game-Gateway ─► Instanz-Allokator ─► Godot-Headless-Flotte │
 (Godot)        ◄──────  │                                   (n Instanzen/Prozess)    │
                         │ Nakama: Accounts, Events, Bestenlisten, Matchmaking, IAP   │
                         │ Fairness-Service (Seed-Tresor, Commit/Reveal)              │
                         │ Gift-Service ─► Ledger-Service (Postgres, doppelte Buchf.) │
                         │ Replay-Verifier (Godot headless, Batch)                    │
                         │ Pub/Sub (NATS JetStream) ─► Delay-Puffer ─► WS-Gateways ──┼──► Zuschauer (Web/In-Game)
                         │                                         └► CDN-Segmente ─┼──► Großevents
                         │ Twitch EBS ◄──────────────────────────────────────────────┼──── Twitch-Extension (gratis)
                         │ Shop-API ◄── Webhooks ── MoR/PSP                           │◄─── Web-Shop/App-IAP (C)
                         └─────────────────────────────────────────────────────────────┘
```

### 3.2 Autoritativer Dedicated Server (Godot headless)

- **Ein Lauf = eine Instanz** (`FloorInstance`, logisch). Physisch hostet ein Godot-Prozess (`--headless`, Hauptszene
  `res://server/server_main.tscn`) **mehrere Instanzen** (`instances_per_process`, Start 1, Ziel 20–50 nach Messung).
  Möglich, weil die Simulation in `core/` als `RefCounted` ohne Szenen läuft (Brief Kap. 5) — der Server lädt **keine**
  Darstellungsszenen, keine Shader, keine Meshes.
- **Eine Simulationsuhr (normativ):** `SIM_HZ = 30`, **1 Tick = 1/30 s, ganzzahlig**. Alle zeitabhängigen Spielregeln
  rechnen in Ticks: Etagen-Timer (`time_left_ticks`, CR-3), Hype-Drift, Zuschauer-Ziel-Neuberechnung, Pazifist-Zählung
  (`max_seconds_without_battle` aus Ticks), Vote-Intervalle, Mindestabstand Geschenke, Encounter-Sperren, Zug-Timeouts
  (`deadline_tick`), Hartes Ende. Millisekunden/Sekunden werden **nur für die Anzeige** abgeleitet. Grad B rechnet mit
  30 Hz **unabhängig** von `physics_ticks_per_second = 60` (02_TECH §2); die 60-Hz-Physik ist reine Darstellung.
  - `timer_mode: explore_only`: Der Lauf-Tick `k` zählt Erkundungs-Ticks **und Leerlauf-Ticks im Safe Room** (seit den
    Sponsor-Fenstern, Kap. 6.13: das Safe-Room-Fenster ist auf 90 s begrenzt — in Ticks); der Etagen-Timer, Hype-Zerfall,
    Pazifist-Zählung und Streuner laufen **nur** auf Erkundungs-Ticks. Im Kampf steht `k`; Kampf-Commands tragen den `k` ihres
    Kampfes (Timer steht) plus Aktionsindex `n`.
  - `timer_mode: realtime`: `k` zählt **Wanduhr-Ticks** (auch in Kampf, Safe Room, Menüs); **jedes** Command, auch jedes
    Kampf-Command, trägt den echten Sim-Tick, an dem es angewendet wurde → Timerstand, Zug-Timeouts und Hartes Ende sind
    im Replay rekonstruierbar.
- **Gleicher Code überall:** Client (Offline/S0), Server (S4), Replay-Verifier (S1) und Spectator-Client nutzen dieselben
  Kern-Klassen (`BattleState`, `GameState`, `SponsorSystem`, `LootRoller`, 02_TECH). **Schon im Slice** (Brief 6b: „ohne
  Umbau“) liegt die Orchestrierung in der autoload-freien Klasse `RunSim` (`core/live/run_sim.gd`, CR-6, dünne Variante):
  `RunSim` hält den `GameState` und tickt alle zeitabhängigen Regeln über `func step(ticks: int)` (`FloorRun`-Timer,
  `ShowModel`-Drift/`viewers_target`, Pazifist-Zählung, Timer-Warnungen) und nimmt Commands über `func apply(cmd)` an.
  `Game` und `Show` werden zu **Fassaden**: Sie akkumulieren Frame-`delta` in ganze Ticks, rufen `RunSim.step` auf und
  reichen Ergebnisse als Signale weiter. Damit laufen Verifier und mehrere Server-Instanzen pro Prozess ohne Umbau.
  Unterschied nur in der **Befehlsquelle** (lokale Eingabe, Netzwerk, Log) und der **Seed-Quelle**.
- **Prozessrollen** über Kommandozeile: `-- --role=server|verifier|client`.

### 3.3 Determinismus-Vertrag (Anforderungen an `core/`, mit 02_TECH abzustimmen)

1. **Seed-Streams statt globaler RNG:** Jede Zufallsquelle bekommt einen `RandomNumberGenerator` aus
   `SeedUtil.make_rng(SeedUtil.derive(base, purpose, index))` (02_TECH §4.6; offline `base = GameState.seed`, das im
   Event-Lauf aus `seed_policy` stammt). Zusätzliche Zwecke für SHOWRUN: `"action"`, `"quest"`, `"event"`, `"gift"`, `"loot"`.
   **Sicherheitshinweis (normativ):** `SeedUtil.mix` maskiert mit `& 0x7FFFFFFF` — von jedem Basis-Seed wirken nur **31 Bit**.
   Alle `SeedUtil`-Ableitungen gelten deshalb als **öffentlich** und mit ~2^31 Versuchen in Sekunden brute-force-bar. Wer
   einen abgeleiteten Seed oder ein daraus generiertes Ergebnis (z. B. das Layout) sieht, kann den Basis-Seed und damit
   **alle** daraus abgeleiteten Ströme (`battle`, `lootbox`, `chest`, `show`, `shop` …) rekonstruieren. Online sind
   `SeedUtil`-Ableitungen daher **nie** geheimhaltungsrelevant.
2. **Zwei Seed-Klassen online (normativ, Protokoll Kap. 4.5, Ableitungen Kap. 7.3):**
   - **Öffentlich:** nur `layout_seed`. Daraus wird **ausschließlich** das Layout generiert (`DungeonGenerator`: Zellen,
     Türen, Truhen-**Positionen**, Gegnergruppen-Platzierung). Der Client bekommt ihn bei `run_start`.
   - **Geheim (Server):** alle spielrelevanten Würfe — Truhen-**Inhalte**, Lootboxen, Drops, Show/Sponsor-Wahl,
     Kampf-Setup (CTB-Startwerte), Kampfaktionen, Quest-Spawns — kommen online aus
     `u48(HMAC(server_seed, "<zweck>|" + scope + "|" + index))` (Kap. 7.3). Der Server schickt **das Ergebnis oder den
     Seed erst bei Auflösung** (z. B. `ev chest_opened{contents}`, `battle_start{ctr}`, `act{action_seed}`).
     Dafür braucht der Kern einen vom Layout getrennten Loot-Seed: `FloorRun.loot_seed ≠ FloorRun.seed` (CR-11, **umgesetzt**:
     `Game.open_chest` und `RunSim` würfeln Truhen mit `SeedUtil.derive(floor_run.loot_seed, "chest", k)`; `floor_run.seed` ist
     der öffentliche Layout-Seed). Offen für S1+: der Inhalt **prozeduraler** Holztruhen wird noch bei der Generierung aus dem
     Layout-Seed gewürfelt (`derive(floor_seed, "chest_table", k)`, 02_TECH §7.2 Schritt 9) — vor Online-Etagen beim Öffnen aus
     `loot_seed` würfeln.
   - **Pro-Aktion-Seeds im Kampf:** Vor jeder Kampfaktion (Party **und** Gegner, inkl. KI-Entscheidung) wird `BattleState.rng`
     neu gesetzt: `rng.seed = SeedUtil.derive(setup.seed, "action", action_n)` offline (CR-2); online liefert der Server
     `action_seed` erst bei Auflösung der Aktion (Kap. 3.4).
   - **Grenze:** In Modi mit **Client-Simulation** (S0 offline, S1 async, S2) kennt der Client zwangsläufig alle Seeds
     seines Laufs → dort gibt es **keinen** Vorhersage-Schutz. Akzeptiert, weil dort kein Echtgeld fließt und gewertete
     Listen Grad B + Verifier voraussetzen; Echtgeld nur mit Server-Simulation (L14).
3. **Erkundung — zwei Ausbaugrade:**
   - **Grad A (S0, passt zu 02_TECH §7.3):** Bewegung bleibt in der Szene (`CharacterBody3D`, Godot-Physik). Ins Run-Log
     gehen die **spielrelevanten Ergebnisse** der Erkundung als Commands: `encounter` (Encounter, Gruppe, Vorteil),
     `interact` (Truhe/Tür/Treppe/Event), `room_enter` (Zelle), `time` (verbrauchte Erkundungszeit in ganzen Ticks).
     Replays reproduzieren damit **Zustand, Kämpfe, Beute, Show und Punkte** exakt, die Laufwege nur als optionale
     Positionsproben (2 Hz, Darstellung). Reicht für S0 und für S1-Plausibilitätsprüfung, ist aber **nicht cheat-fest**.
   - **Grad B (für S4-Serverautorität, cheat-feste S1-Bestenlisten und jede Echtgeld-Stufe):** Bewegung, Gegner-Wahrnehmung,
     Patrouillen und Kampfauslösung laufen im Kern (`core/dungeon/explore_sim.gd`) mit 30 Hz auf Raster-Kollision (Räume +
     Wand-AABBs, Figuren als Kreise); die Szene stellt nur dar. Godot-Physik (Jolt, 02_TECH §2) ist plattformübergreifend
     nicht garantiert deterministisch **[zu prüfen für 4.7, aber nicht darauf bauen]**. **Zahlendarstellung (normativ):
     Festkomma.** Positionen als `int` in **Millimetern**, Geschwindigkeit in mm/Tick (Gehen 5.0 m/s = 167 mm/Tick, Sprint
     7.5 m/s = 250 mm/Tick, 02_TECH §7.3), Richtungen über eine **256-Stufen-Yaw-Tabelle** (Ganzzahl-Sin/Cos × 1024 in
     `core/util/det_math.gd`), Distanzvergleiche **quadratisch in `int`** (kein `sqrt`), Sichtkegel 120° über
     Ganzzahl-Skalarprodukt gegen `cos(60°) × 1024`, Kollisionsauflösung Kreis gegen AABB mit **fester Achsreihenfolge**
     (erst X, dann Z), Kontakt per **Segment-gegen-Kreis** (swept) statt Punktprüfung. **Keine `Vector2`/`Vector3`-Typen
     im Sim-Pfad** (in GDScript `real_t` = float32, Engine-Methoden wie `length()`, `normalized()`, `rotated()`, `angle_to()`
     laufen als C++ mit möglicher FMA-Kontraktion und libm-Trigonometrie). Die Szene konvertiert nur für die Darstellung nach
     `Vector3`. **Pflicht-Golden-Tests:** z. B. 10 000 Ticks feste Bot-Eingaben → fester Positions-Hash, auf der
     Plattform-Matrix (Kap. 2, S0). Entscheidung, ab wann Grad B kommt: offene Frage 12.2-#2.
   - **Echtzeitkampf (`07_ECHTZEITKAMPF.md`, Entscheidung 2026-10-10):** Die Kampfbewegung ist **Grad A mit festen
     Plausibilitätsgrenzen**. Die gesteuerte Figur bewegt sich in der Szene; ins Run-Log gehen Positionsproben `move_sample`
     mit Kampf-Tick `ct` (Schwellen und Koppelnavigation, 07 §3.5.1). `RtSim` prüft jede Probe: Verschiebung höchstens
     Lauftempo × Δ plus ein kleines, langsam nachfüllendes Toleranzbudget (600 mm, 3 mm je Tick), sonst `POS_CORRECTED`
     (07 §3.5.2). Gegner, KI-Partner, Status und Schaden rechnet nur `RtSim` (Ganzzahlen, 30 Ticks/s). **Grad B im Kampf:**
     Der Befehl `move_input` (Richtung als `int8` je Achse + Laufen) ist reserviert; damit bewegt der Server später auch die
     Spielerfiguren im requisitenfreien Kampf-Set (Kreis, Türgassen, Sperrflächen — ohne Physik, 07 §10.8). Bis dahin sind
     Echtzeit-Bestenlisten „plausibilitätsgeprüft“ (07 §10.7).
4. **Eingaben quantisiert:** Bewegungsvektor als `int8` (−127…127) je Achse, Kamera-Yaw als `uint8` (256 Stufen) — Yaw ist
   spielrelevant (GDD 15: Schaufensterpuppe bewegt sich nur, wenn Kai wegschaut), Buttons als Bitmaske.
5. **Zahlen-Regeln (normativ):** Spielrelevante Pfade in `core/` nutzen **nur Ganzzahl-Arithmetik und Ganzzahl-Zufall**.
   Begründung: Auch „harmlose“ Float-Operationen sind plattformübergreifend nicht sicher — `pow`/`exp`/`sin`/`cos`/`atan2`
   kommen aus der jeweiligen libm (glibc, MSVC, Apple, Bionic, Emscripten können im letzten ulp abweichen), und
   engine-interne Hilfen wie `rng.randf_range` rechnen in float32 (`randf()*(to-from)+from`) und können auf ARM64 mit
   FMA-Kontraktion anders runden als auf x86-64 (Godot-Buildflags **[zu prüfen]**); ein seltener Kippfall vor `roundi` führt
   dann zum Desync zwischen Linux-Server und Android/iOS/Apple-Silicon-Client. Konkret (CR-12):
   - Schadensvarianz 0.9–1.1 (GDD §3.7 / 02_TECH §5.9) als `rng.randi_range(900, 1100)` in Promille, Heilvarianz 0.95–1.05
     als `randi_range(950, 1050)` statt `randf_range(…)` — **umgesetzt** (M1).
   - CTB-Startwert NORMAL `base_delay × [0.5, 1.0]` (GDD §2.4 / 02_TECH §5.5) als
     `FixedMath.div_round(base_delay × rng.randi_range(500, 1000), 1000)` (Ganzzahl-Division) — **umgesetzt** (M1).
     (Die früher hier genannten Spannen 920–1080 bzw. 700–1000 waren Entwurfszahlen; maßgeblich sind GDD/02_TECH.)
   - Truhen-Offsets als Ganzzahl in Zentimetern (`rng.randi_range(-400, 400)`) statt `randf_range(−4.0, 4.0)` (02_TECH §7.2)
     — **umgesetzt**; ebenso die Etagen-Event-Chancen in Basispunkten (`randi_range(0, 9999) < roundi(p × 10000)`, §7.4).
   - EXP-Kurve als **vorberechnete Tabelle** in `data/party.json` (oder `balance.json`) statt `pow(level, 1.7)` (02_TECH `Progression.exp_to_next`).
   - Lint-Test `test_m8_no_global_rng` prüft zusätzlich `pow(`, `exp(`, `sin(`, `cos(`, `atan2(`, `randf`, `randfn`, `lerp(`
     in `core/`; Ausnahmen nur per Whitelist-Kommentar (`# det-ok: <Grund>`) für reine Anzeige-Hilfen.
   Darstellung darf alles. Die Zuschauer-Glättung (`exp(-delta/1.5)`, GDD 7.2) und das Zuschauer-Rauschen (`_fx_rng`) sind
   reine Anzeige; spielrelevant ist nur `viewers_target` (rauschfreie Ganzzahl-Formel `ShowModel.viewers_for` ohne Noise).
   Quest, Score und Hash nutzen nie die angezeigten (verrauschten) Zuschauer.
6. **Keine Zeit, keine Reihenfolge-Zufälle:** Kein `Time`/`OS.get_ticks*` in `core/`; Iteration über Dictionaries nur über
   sortierte Schlüssel, wo die Reihenfolge das Ergebnis beeinflusst.
7. **Daten-Hash:** `DB.data_hash()` = SHA-256 über kanonisches JSON aller `res://data/*.json`. Steht im Run-Log-Header,
   Server und Verifier lehnen fremde Hashes ab (`E_DATA_HASH`).
8. **Zustands-Hash:** `StateHash.of(GameState)` = SHA-256 über kanonische Serialisierung des Lauf-Zustands (ohne Anzeigefelder); nach jedem Kampf,
   jeder Etagen-Bilanz und alle 300 Ticks im Log vermerkt (Checkpoints für schnelle Desync-Erkennung).
   **Kampf-Hash:** `StateHash.of(GameState)` deckt einen laufenden Kampf nicht ab (`BattleState` ist eigener Zustand, erst
   `BattleBridge.apply_result` schreibt zurück). Daher `StateHash.of_battle(state: BattleState)` = SHA-256 über
   `CanonicalJson` von `BattleState.to_dict()` inkl. CTB-Zähler, Status-Effekte, `items`, `action_n` und RNG-`state` (CR-14).
9. **Kanonisches JSON (normativ):** Alles, was gehasht oder signiert wird (`tables_hash`, `rules_hash`, `data_hash`,
   `RunLog.digest()`, `run_log_hash`, Gift-`sig`, Zustands-Hashes), folgt einem **Profil von RFC 8785 (JCS)** mit
   Einschränkungen: nur Ganzzahlen im Bereich ±2^53, Strings, Bools, `null`, Arrays, Objekte — **keine** nicht-ganzzahligen
   Zahlen (deshalb `effect_pm: int` statt `effect_mult: float`, Kap. 6.5). Schlüssel nur ASCII, nach Codepunkt sortiert;
   Strings UTF-8 **ohne** `\u`-Escapes außer für Steuerzeichen U+0000–U+001F (dort `\uXXXX` klein-hex bzw. die Kurzformen
   `\b \f \n \r \t`), `"` und `\` escaped, `/` **nicht** escaped; keine Leerzeichen. Weil Godot `JSON.parse` alle Zahlen als
   Float liefert (02_TECH §4.1), normalisiert `CanonicalJson` ganzzahlige Floats zu `int` und **lehnt** nicht-ganzzahlige
   Zahlen in gehashten Strukturen ab. Gemeinsame Testvektoren (Godot `test_m8_canonical_json`, Python, JS, Go) mit
   identischem SHA-256 sind Pflicht.

### 3.4 CTB im Netz: Befehls-Lockstep mit Pro-Aktion-Seed

> **Hinweis (07):** Dieses Kapitel gilt für den CTB-Kampf, der bis R5 hinter dem Schalter `combat_mode` bleibt. Der
> Echtzeitkampf ersetzt den Zug-Lockstep durch Befehle mit Kampf-Tick `ct`, Tick-Grenzen für Geschenke und Kampf-Prüfpunkte
> (`07_ECHTZEITKAMPF.md` §9.2, §10); dieses Kapitel wird mit R5b umgestellt.

Kämpfe sind rundenbasiert → es werden **nur Befehle** übertragen, nie Ergebnisse:

```
Server                                   Clients (Team)               Zuschauer (verzögert)
battle_start{battle_id, units, ctr0, hash} ───────────►  BattleState aufbauen
turn{actor:"p0", owner:"p_A", deadline}    ───────────►  UI für Person A aktiv
            ◄──────── cmd{battle, kind:"skill", actor_id:"p0", skill_id:"kai_heavy_swing", target_ids:["e2"]}  (nur von p_A akzeptiert)
validate → resolve(cmd, action_seed) → state_hash
act{n:7, cmd, action_seed, hash}          ───────────►  resolve(cmd, action_seed) lokal → ActionEvents abspielen,
                                                          eigenen Hash mit hash vergleichen
                                                          ─────────────────────────────►  dieselbe Nachricht nach Delay
```

- **Hash-Definition:** `battle_start.state_hash` = `StateHash.of_battle` des frisch aufgebauten `BattleState` (vor Aktion 0);
  `act.state_hash` = `StateHash.of_battle` **nach** Auflösung der Aktion `n` (Kap. 3.3 Nr. 8, CR-14).
- Gegnerzüge: Server schickt `act` mit dem von der KI gewählten Befehl (KI läuft mit demselben `action_seed`).
- **Desync:** Hash-Abweichung → Client sendet `resync`, Server antwortet mit `resync_state`. Im Kampf:
  `resync_state{battle_snapshot, battle_log_tail, state_hash}` mit `battle_snapshot = BattleState.to_dict()` (CR-14); der
  Client baut per `BattleState.from_dict` auf, prüft `of_battle == state_hash` und spielt `battle_log_tail` (alle `act` nach
  dem Snapshot) nach. Gleicher Pfad für Reconnect mitten im Kampf (Kap. 3.6).
- **Zug-Timer:** `turn_timeout_sec`; bei Ablauf erzeugt der Server `defend` für die Einheit (gekennzeichnet `auto: true`).
- **Bandbreite:** ~60–120 B je Aktion, ~150–300 Aktionen pro Etage → vernachlässigbar.
- Sponsor-Geschenke im Kampf werden an der nächsten **Zuggrenze** als eigenes `act` mit `cmd.t = "gift"` eingespielt
  (wie GDD 7.4, kostet keine Ticks).

### 3.5 Erkundung: Positions-Synchronisation

| Größe | Wert | Begründung |
|---|---|---|
| Server-Simulation | 30 Hz (unabhängig von `physics_ticks_per_second = 60`) | Werte aus 02_TECH §7.3: Kontakt ≤ 1.2 m, Gehen 5.0 m/s (0.167 m/Tick), Sprint 7.5 m/s (0.25 m/Tick). Ausreichend, weil `ExploreSim` Kontakt per **Segment-gegen-Kreis** (swept) prüft — auch bei zwei sich entgegen sprintenden Figuren (0.5 m/Tick Relativbewegung) wird kein Kontakt übersprungen |
| Eingaben Client→Server | 15 Pakete/s, je 2 Eingabe-Frames | Redundanz (nur auf dem **unzuverlässigen** Kanal, Kap. 4.1): jedes Paket wiederholt die letzten 4 unbestätigten Frames |
| Tick-Wahl des Clients | Zielvorlauf `server_tick + RTT/2 + 2 Ticks` | Uhren-Sync über `ping`/`pong` (gleitender Mittelwert); Eingabepuffer auf dem Server 2–6 Ticks; zu späte Frames → verworfen, letzte Eingabe wird wiederholt |
| Snapshots Server→Spieler | 15 Hz, Delta gegen letzten bestätigten Snapshot | Interest-Radius 40 m (≈ 2–3 Räume à 16 m, 02_TECH §7.3) |
| Snapshots → Zuschauer | 5 Hz (Keyframe alle 10 s) | Zuschauer interpolieren 400 ms |
| Eigene Figur | Client-Vorhersage + Abgleich (Reconciliation) bei Abweichung > 0.25 m | Laufgefühl wie offline |
| Andere Spieler | Interpolation 100 ms hinter Server | — |
| Gegner-Symbole | Patrouillen sind deterministisch aus Seed+Tick → Client sagt sie voraus; Server sendet nur Zustandswechsel (`ALERT`, `CHASE`, `RETURN`) + Korrekturen | spart ~70 % Snapshot-Daten |
| Interaktionen (Truhe, Event, Treppe) | diskreter Befehl `cmd{t:"interact", obj}` → Server prüft Abstand ≤ 1.5 m + 120°-Kegel | Anti-Cheat |

### 3.6 Reconnect

| Situation | Verhalten |
|---|---|
| Verbindung weg | Server hält den Platz `reconnect_grace_sec = 120`. Client versucht mit Backoff 1, 2, 4, 8, 8 … s mit `reconnect_token`. |
| Erkundung, Koop | Figur wird „Funkloch“-Geist (nicht kollidierbar, Gegner ignorieren sie), steht still. |
| Kampf, Koop | Autopilot: `defend`; Heil-Item nur, wenn ein Verbündeter < 25 % HP (einfache Regel, deterministisch). |
| Solo | Instanz pausiert Etagen-Timer, max. **180 s Summe pro Lauf** (= 5 400 Ticks; Missbrauchsschutz gegen „Denkpausen“); Fenster-Wanduhr läuft weiter. |
| Wiederkehr | `hello{reconnect_token}` → `resync{last_tick, state_hash, last_cmd_id}` → `resync_state{snapshot, log_tail, last_cmd_id}` (gzip ~20–50 KB) bzw. im Kampf `resync_state{battle_snapshot, battle_log_tail, …}` (Kap. 3.4) → Client spult vor, Zuschauer sehen „Signal wiederhergestellt“. Commands mit `cmd_id ≤ last_cmd_id` sendet der Client nicht erneut; Duplikate verwirft der Server ohnehin (Kap. 4.2). |
| Prozess-Crash (Server) | Allokator startet die Instanz in einem neuen Prozess aus Run-Log + letztem Checkpoint neu (Wiedergabe bis zum letzten bestätigten Command); Clients durchlaufen denselben Reconnect-Pfad. Etagen-Timer pausiert währenddessen (zählt nicht gegen die 180 s). Zugesagte, noch nicht angewendete bezahlte Geschenke bleiben im Gift-Service reserviert und werden nach Wiederanlauf zugestellt. |
| Grace abgelaufen | Solo: Lauf endet (Ursache `disconnect`), Wertung = Fortschritt. Koop: Figur bleibt KO-Geist, Team spielt weiter; Rückkehr bis Laufende möglich (Join an Zuggrenze/Safe Room). |

### 3.7 Anti-Cheat

1. **Server validiert jeden Befehl:** Ist der Absender Besitzer der Einheit? Ist sie am Zug? Kennt sie den Skill
   (`unlock_level`), reicht MP, ist Stunt-Cooldown 0, ist Ziel gültig (`target`-Typ, lebt), ist Item im (Team-)Inventar,
   ist Flucht erlaubt (nicht gegen Bosse)? Ungültig → `err{E_INVALID_CMD}`, Befehl verworfen, Zähler für Auffälligkeiten.
   Im Echtzeitkampf prüft `RtSim.submit` Schema und statische Bedingungen, der Kampf-Tick die dynamischen (GCD, MP,
   Reichweite, Abklingzeit, Trinkpause; 07 §3.4).
2. **Bewegung:** Server simuliert aus Eingaben, nicht aus gemeldeten Positionen. Eingabe-Frames mit Tick in der Zukunft
   (> 6 Ticks) oder zu viele Frames pro Sekunde → verworfen.
   Im Echtzeitkampf gilt bis Grad B: Positionsproben mit festen Plausibilitätsgrenzen in `RtSim`, `POS_CORRECTED` zählt der
   Verifier, Ausreißer-Statistik ohne Ablehnung (07 §3.5.2, §10.7); mit Grad B sendet der Client `move_input` statt Proben.
3. **Clients senden nie Ergebnisse** (keinen Schaden, keine Beute, keine Punkte). Punkte berechnet der Server/Verifier.
4. **Async (S1–S2 ohne Server-Instanz; Echtgeld nie ohne Server-Instanz, L14):** Run-Log wird serverseitig neu simuliert; nur der Verifier schreibt Bestenlisten.
   Plausibilitätsregeln zusätzlich (z. B. Eingabe-Entropie bei Bot-Verdacht, Mindestzeit pro Kampf).
5. **Vorhersage-Schutz (nur Server-Sim-Modi):** Clients kennen nur `layout_seed`, aus dem ausschließlich das Layout entsteht;
   alle spielrelevanten Würfe kommen aus HMAC über den geheimen `server_seed` und erreichen den Client erst bei Auflösung
   (Kap. 3.3 Nr. 1–2, 7.3). `SeedUtil`-Ableitungen gelten als öffentlich (31 Bit, brute-force-bar). In Client-Sim-Modi
   (S0–S2) gibt es keinen Vorhersage-Schutz.
5a. **Idempotenz:** Jedes C→S-`cmd` trägt eine pro Lauf monotone `cmd_id`; Duplikate werden verworfen (Kap. 4.2); der
   Verifier prüft Monotonie im Run-Log.
6. **Rate-Limits** pro Verbindung (Befehle, Votes, Gifts) und **Konto-Bindung** (eine aktive Sitzung pro Account und Event).
7. **Client-Integrität** (Obfuskation, Prüfsummen) nur als Zusatz — nie Grundlage einer Entscheidung.

### 3.8 Backend-Optionen

| Kriterium | **Nakama** (Heroic Labs) | **Supabase** | **Eigenbau** (Go/TS + Postgres + NATS/Redis) |
|---|---|---|---|
| Lizenz / Hosting | Open Source (Apache-2.0 **[zu prüfen]**), selbst gehostet oder Heroic Cloud | Open Source, meist gehostet (Supabase Cloud) | eigen |
| Accounts & Login (Gerät, Steam, Apple, Google, Twitch) | eingebaut (Custom-Auth für Twitch-OAuth möglich **[zu prüfen]**) | Auth mit OAuth-Anbietern (Twitch-Provider **[zu prüfen]**) | selbst bauen |
| Bestenlisten / Turniere mit Zeitfenstern | **eingebaut** (Leaderboards, Tournaments mit Reset/Dauer) | selbst bauen (SQL) | selbst bauen |
| Matchmaking / Lobbys / Parties | eingebaut | nein | selbst bauen |
| Echtzeit-Kanäle | eingebaut (Socket, Chat, Status) | Realtime (Broadcast/Presence; Grenzen bei hohen Raten **[zu prüfen]**) | NATS/WS selbst |
| IAP-Belegprüfung Apple/Google | eingebaut (aktueller Stand StoreKit 2 / Play Billing **[zu prüfen]**) | nein (Edge Function selbst) | selbst |
| Eignung als Ledger | möglich, aber nicht spezialisiert | **gut** (Postgres-Transaktionen, Constraints) | **gut** (volle Kontrolle) |
| Godot-Client | offizielles `nakama-godot` (Kompatibilität mit 4.7 **[zu prüfen]**) | Community-SDKs **[zu prüfen]** / REST | REST/WS selbst |
| Game-Server-Flotte | Integrationen (Fleet-Manager-Schnittstelle, Anbieter **[zu prüfen]**) | nein | selbst / Agones |
| Aufwand bis S1 | mittel (Betrieb, Lernkurve Go/TS-Runtime) | gering | hoch |
| Lock-in-Risiko | gering (OSS, selbst hostbar) | gering–mittel | keins |

**Empfehlung: Hybrid.**
- **Nakama (selbst gehostet, Postgres)** ab S1 für Accounts, Event-Kalender (Turniere), Bestenlisten, Freunde,
  Matchmaking (S4) und IAP-Prüfung (S5). Spart am meisten Eigenbau genau dort, wo SHOWRUN Standardfunktionen braucht.
- **Eigene kleine Dienste** (eine Sprache, z. B. Go oder TypeScript) für das, was kein Standard abdeckt und **streng**
  sein muss: Ledger-Service (eigene Postgres-Datenbank, Kap. 8.3), Gift-Service, Fairness-Service (Seed-Tresor),
  Twitch-EBS, Spectator-Gateway + Delay-Puffer, Instanz-Allokator.
- **Supabase** ist die Alternative, falls S1 ohne Ops-Kapazität schnell live gehen soll; Migration zu Nakama vor S4
  einplanen (Bestenlisten-/Account-Daten exportierbar).

### 3.9 Hosting, Skalierung, Kosten (grobe Schätzungen)

**Flotte:**
- S1–S3: Verifier und Solo-Server (ab S3 **Pflicht** für Läufe mit bezahlten Geschenken, L14) als Prozess-Pool auf 1–2 VMs; einfacher Allokator (Redis-Liste freier Plätze).
- S4: Instanz-Allokator verteilt Teams auf Prozesse (Bin-Packing nach CPU-Last); Prozess-Neustart nur ohne aktive Instanzen.
- S5: **Agones** (Kubernetes) oder ein Managed-Anbieter für Game-Server **[zu prüfen: Verfügbarkeit/Preise aktueller
  Anbieter]**. Geplante Events → **Vorab-Skalierung** 30 min vor `open` anhand der Anmeldungen (+30 % Puffer).
- Regionen: EU (Frankfurt/Falkenstein/Helsinki), US-Ost, Asien (Tokio/Singapur) passend zu den rotierenden Fenstern;
  ein Fenster läuft primär in „seiner“ Region.

**Kapazitäts-Annahme (in S4 messen!):** Kern-Simulation einer Etage (≤ 4 Spieler, ~20 Gegnersymbole, 30 Hz) ≈ 0.2–0.5 ms
pro Tick in GDScript → 6–15 ms CPU pro Sekunde → **30–50 Instanzen pro vCPU** (konservativ), Speicher ~10–30 MB pro
Instanz + ~100 MB pro Prozess.

**Instanzen pro Spieler:** mit Solo-Anteil `p_solo` als Parameter: `instanzen ≈ spieler × (p_solo + (1 − p_solo) / ø_teamgröße_koop)`.
Planwert `p_solo = 0.7`, ø Koop-Team 2.5 → 1 000 Spieler ≈ **820 Instanzen** (Spanne 700–1 000; Solo ist Standard, Pur-Liga
für alle, Koop 3–4 braucht Zusatzinhalte). Das ist etwa das **2- bis 3-Fache** der früheren Annahme „Teams à ~3“.

**Prozess-Packung:** `instances_per_process` wird an einer **Messung** festgemacht (Start 1; Ziel 20–50 nur, wenn p99-Tick-Budget
hält). Weil GDScript single-threaded läuft und ein Prozess-Crash alle Instanzen des Prozesses beendet, gilt für Läufe mit
**bezahlten Geschenken** eine niedrigere Obergrenze von **10 Instanzen pro Prozess**. Wiederanlauf nach Crash aus Run-Log +
Checkpoint in einem neuen Prozess (Kap. 3.6).

| Posten | Annahme | Größenordnung **[Preise zu prüfen]** |
|---|---|---|
| S1 Backend (Nakama + Postgres + Verifier) | 2 VMs à 4 vCPU/8 GB, Objektspeicher Replays | 50–200 €/Monat |
| S2 Spectator-Pipeline | NATS + 2 WS-Gateways, ≤ 2 000 Zuschauer gleichzeitig | +50–150 €/Monat + Traffic |
| S3 Shop-API/Ledger/Fairness (+ EBS gratis) | klein, hochverfügbar (2× je Dienst) | +50–100 €/Monat |
| S3/S5 Rechtsprüfung | mehrere Länder, Glücksspiel + Verbraucherrecht + Steuern | einmalig 10 000–40 000 € **(reine Schätzung)** |
| S4 Game-Server | 1 000 gleichzeitige Spieler ≈ 700–1 000 Instanzen (`p_solo` 0.7) ≈ 20–35 vCPU | Budget-Hoster ~150–400 €/Monat dauerhaft; Hyperscaler ~1–2.50 €/h für Event-Spitzen |
| S5 Großevent 2 h | 10 000 Spieler (~7 000–10 000 Instanzen ≈ 200–350 vCPU) | ~150–450 € Rechenzeit pro Event |
| S5 Zuschauer-Traffic | 100 000 Zuschauer × ~20 kbit/s ≈ 2 Gbit/s × 2 h ≈ 1.8 TB | ~20–150 € pro Event via CDN (stark anbieterabhängig) |
| Zahlungsabwicklung C | MoR/PSP-Gebühr | ~5–10 % vom Umsatz (MoR) bzw. ~1.5–3 % + Fixbetrag (PSP) **[zu prüfen]** |

---

## 4. Netzwerk-Protokoll

### 4.1 Transport & Kodierung

| Kanal | Transport | Kodierung |
|---|---|---|
| Spieler ↔ Game-Server: **zuverlässig** (Lobby, `cmd`, Kampf-Lockstep, `gift`, `ev`, `timer`, Reconnect) | **WebSocket über TLS** (`wss://`), Godot `WebSocketPeer` — funktioniert nativ **und** im Web-Export | JSON (UTF-8); ab Protokoll 1.1 Binär für große Nachrichten |
| Spieler ↔ Game-Server: **unzuverlässig** (nur Erkundung im Koop: `in`, `snap`) | nativ **ENet/UDP** (Godot `ENetConnection`, unreliable/unsequenced Kanal); Web **WebRTC DataChannel** (unreliable/unordered, Godot `WebRTCPeerConnection`; nativ nur mit dem webrtc-native-GDExtension **[zu prüfen für 4.7]**) | Binär (Kap. 4.7) |
| Zuschauer ← Gateway | WebSocket (`wss://`), bei Großevents zusätzlich HTTP-Segmente über CDN | Frames **einmal pro Lauf vorkodiert** (binär, Protokoll 1.1) und vorkomprimiert als Binary-Frame mit eigener gzip/zstd-Kapselung; **`permessage-deflate` aus** (alternativ nur mit `no_context_takeover`) |
| Spieler/Zuschauer ↔ Backend (REST) | HTTPS | JSON |

**Warum zwei Kanäle für Koop-Erkundung:** WebSocket läuft über TCP (zuverlässig, geordnet). Bei Paketverlust staut jede
Retransmission (RTO ≥ ~200 ms) alle folgenden Eingaben und Snapshots (Head-of-Line-Blocking); Frame-Redundanz bringt über
TCP nichts. Deshalb ist der unzuverlässige Kanal **von Anfang an** eingeplant; die Frame-Redundanz (Kap. 3.5) gilt nur
dort. Solo-Server-Sim (S3) und Kampf-Lockstep laufen auch nur über WebSocket. Fällt der unzuverlässige Kanal aus (Firewall),
fällt der Client auf `in`/`snap` über WebSocket zurück (schlechteres Spielgefühl, aber funktionsfähig). Der S4-Playtest misst
beide Varianten gegeneinander (Kap. 2).
**Zuschauer-Kompression:** `permessage-deflate` komprimiert pro Verbindung mit eigenem Kontext — 10 000 Zuschauer desselben
Laufs bedeuten 10 000-fache Kompression desselben Frames und je Verbindung Speicher für den Kontext (Größenordnung
zweistellige KB **[zu prüfen]**). Deshalb Vorkodierung pro Lauf (s. o.).
Eigene Nachrichtenschicht statt Godot-RPCs: versionierbar, sprachunabhängig (Gateway/Verifier), testbar.

### 4.2 Umschlag (Envelope)

```json
{ "v": "1.0", "type": "cmd", "seq": 118, "ack": 342, "tick": 5120, "body": { } }
```

| Feld | Typ | Bedeutung |
|---|---|---|
| `v` | String `major.minor` | Protokollversion |
| `type` | String | Nachrichtentyp (Tabellen unten) |
| `seq` | int | fortlaufend pro Richtung und Verbindung (Transport-Ebene; beginnt nach Reconnect neu) |
| `ack` | int | höchste empfangene `seq` der Gegenseite |
| `tick` | int | Sim-Tick, auf den sich die Nachricht bezieht (Server-Tick bei S→C) |
| `body` | Dictionary | Inhalt |

**Idempotenz über Reconnects:** `seq`/`ack` sichern nur eine Verbindung. Jedes C→S-`cmd` trägt zusätzlich eine
clientseitige, **pro Lauf und Spieler:in monotone `cmd_id`** (int, ab 1). Der Server führt je `run_id` + `player_id` die
höchste angewandte `cmd_id`, verwirft Duplikate (`cmd_id ≤ last_cmd_id`) und bestätigt jedes `cmd` mit
`ack_cmd{cmd_id, result}` (`result` ∈ `ok` \| `duplicate` \| `rejected:<code>`). `resync_state` enthält `last_cmd_id`.
Die `cmd_id` steht auch im Run-Log (Kap. 10.6); der Verifier prüft strikte Monotonie. Kampf-Commands behalten zusätzlich `n`.

### 4.3 Versionierung

- **Major** unterschiedlich → Verbindung abgelehnt (`E_PROTO`), Client zeigt „Update nötig“.
- **Minor** additiv: neue Felder/Typen; unbekannte Felder und unbekannte `type`s werden ignoriert (und geloggt).
- Zusätzlich müssen **`data_hash`** (Spieldaten) und **`sim_version`** (Kern-Logik, manuell hochgezählt bei Regeländerungen)
  übereinstimmen — sonst `E_DATA_HASH`. Grund: Lockstep setzt identische Regeln voraus.
- Run-Logs speichern `proto`, `sim_version`, `data_hash`, `game_version`. Der Verifier hält **alte Kern-Versionen** vor,
  solange deren Replays angezeigt werden sollen (Archiv-Builds pro `sim_version`).

### 4.4 Client → Server

| `type` | Wann | `body` |
|---|---|---|
| `hello` | nach Verbindungsaufbau | `{ "token", "client_version", "sim_version", "data_hash", "platform", "locale", "reconnect_token"? }` |
| `lobby_join` | Matchmaking / Team-Lobby | `{ "event_id", "window_id", "team_id"?, "invite"? }` |
| `ready_state` | Lobby | `{ "ready": bool, "role": "kai" \| "mopsula" \| <class_id> }` |
| `join` | Lobby → Instanz | `{ "ticket", "run_id", "team_id", "league": "show" \| "pur", "gift_accept": "all" \| "free_only" \| "ask" \| "none" }` (Server erzwingt `free_only`, wenn keine Altersverifikation 18+ vorliegt; `none` in Pur-Liga) |
| `ready` | Etage geladen | `{}` |
| `in` | Erkundung, 15 Hz (unzuverlässiger Kanal, Kap. 4.1) | `{ "f": [[tick, mx, mz, yaw, btn], …] }` (int8, int8, uint8, Bitmaske) |
| `cmd` | diskrete Aktion | `{ "cmd_id": int, "cmd": Command }` (Kap. 4.2, 10.6, z. B. `interact`, `battle`, `menu_use_item`, `equip`, `vendor_buy`, `descend`) |
| `gift_reply` | nur bei `gift_accept = "ask"` | `{ "gift_id", "accept": bool }` (Antwort auf `gift_offer`) |
| `resync` | Desync / Reconnect | `{ "last_tick", "state_hash", "last_cmd_id" }` |
| `ping` | 1 Hz | `{ "c": client_ms }` |
| `leave` | Abbruch | `{ "reason" }` |

### 4.5 Server → Client

| `type` | Inhalt |
|---|---|
| `welcome` | `{ "session_id", "server_tick", "sim_hz": 30, "snap_hz": 15, "reconnect_token", "v" }` |
| `run_start` | `{ "run_id", "event_id", "window_id", "layout_seed", "sym", "quest", "rules", "roster", "start_tick", "party_preset" }` |
| `lobby_state` | `{ "event_id", "window_id", "phase": "forming" \| "countdown" \| "starting", "starts_at"? }` |
| `team_roster` | `{ "team_id", "members": [{ "player_id", "display_name", "role", "connected": bool }], "roster_changed": bool }` |
| `ready_state` | `{ "player_id", "ready": bool }` (Broadcast an das Team) |
| `snap` | `{ "tick", "ack_in", "ents": [[id, x, y, z, yaw, anim, flags], …] }` (JSON 1.0; Binär 1.1, Kap. 4.7; unzuverlässiger Kanal) |
| `ev` | `{ "tick", "events": [ExploreEvent, …] }` (Schema `ExploreEvent`, Kap. 11.2 bzw. 02_TECH §7.1) z. B. `chest_opened{contents}`, `enemy_state`, `event_choice`, `achievement`, `hype` |
| `ack_cmd` | `{ "cmd_id", "result" }` (Kap. 4.2) |
| `battle_start` | `{ "battle_id", "n0", "group_id", "encounter_type", "units", "ctr", "state_hash" }` — `ctr` (CTB-Startwerte) kommt vom Server, `state_hash` = `of_battle` vor Aktion 0 |
| `battle_join` | `{ "battle_id", "unit", "ctr" }` — Nachzügler an der Zuggrenze (Kap. 1.4) |
| `turn` | `{ "battle_id", "actor", "owner", "deadline_tick" }` |
| `act` | `{ "battle_id", "n", "cmd", "action_seed", "auto": bool, "state_hash" }` |
| `battle_end` | `{ "battle_id", "result_hash" }` (`result_hash` = SHA-256 über kanonisches `BattleResult`) |
| `gift_offer` | `{ "gift_id", "preview": { "kind", "tier", "sender" }, "expires_tick" }` — nur bei `gift_accept = "ask"` (10 s = 300 Ticks) |
| `gift` | `{ "gift": Gift }` (Kap. 6.5) — wird vom Client-Kern an demselben Tick angewendet wie vom Server |
| `sponsor_window` | `{ "phase": "opened" \| "updated" \| "closed", "window": SponsorWindows.window_view, "reason"?, "next_in_sec" }` (Kap. 6.13) — derselbe Zustand, den Instanz-Kern und Verifier aus den Ticks ableiten; der Client-Kern rechnet ihn selbst nach |
| `vote` | `{ "vote_id", "phase": "open" \| "result", "options", "result"? , "apply_tick"? }` |
| `twist` | `{ "id", "vote_id", "apply_tick" }` — Anwendung des Vote-Ergebnisses (externer Eingang, Run-Log `{"t":"twist"}`) |
| `timer` | `{ "floor_timer_left_ticks", "window_close_at", "phase" }` (alle 5 s + bei Änderungen; Anzeige rechnet in mm:ss um) |
| `quest` | `{ "progress": float, "complete": bool, "detail" }` (`progress` nur Anzeige; Wertung rechnet ganzzahlig, Kap. 1.5) |
| `run_end` | `{ "cause", "summary", "score", "breakdown", "replay_id", "verified": "pending" \| "ok" }` |
| `resync_state` | `{ "snapshot", "log_tail", "state_hash", "last_cmd_id" }` bzw. im Kampf zusätzlich `{ "battle_snapshot", "battle_log_tail" }` (Kap. 3.4) |
| `err` | `{ "code", "msg", "ref_seq"? }` |
| `pong` | `{ "c", "s": server_ms }` |

**Fehlercodes:** `E_PROTO`, `E_DATA_HASH`, `E_AUTH`, `E_EVENT_WINDOW_CLOSED` (Sendefenster des Events zu, `join`; hieß bis
2026-10-08 `E_WINDOW_CLOSED`), `E_INSTANCE_FULL`, `E_NOT_YOUR_TURN`, `E_INVALID_CMD`, `E_RATE_LIMIT`, `E_DESYNC`,
`E_LEAGUE_NO_GIFTS`, `E_GIFT_CAP`, `E_GEO`, `E_AGE`, `E_SPEND_LIMIT`, `E_SELF_EXCLUDED`, `E_CHEST_BLOCKED`
(Wirkungsschwelle), **Sponsor-Fenster (Kap. 6.13):** `E_WINDOW_CLOSED` (kein Fenster offen), `E_WINDOW_FULL` (alle Plätze
belegt/reserviert), `E_WINDOW_SENDER_LIMIT` (diese:r Zuschauer:in hat im Fenster schon geschenkt) — jeweils mit
`next_window_in_sec`, damit Shop/Overlay anzeigen, wann das nächste Fenster öffnet; `E_INTERNAL`.
Abbildung der Kern-Gründe von `Show.receive_gift` (Kap. 6.5): `league_pur` → `E_LEAGUE_NO_GIFTS`, `cap_reached` →
`E_GIFT_CAP`, `chest_blocked` → `E_CHEST_BLOCKED`, `window_closed` / `window_full` / `window_sender_limit` →
`E_WINDOW_CLOSED` / `E_WINDOW_FULL` / `E_WINDOW_SENDER_LIMIT` (`SponsorWindows.protocol_code`).

### 4.6 Zuschauer-Stream (Gateway → Zuschauer; Zuschauer → Gateway)

| Richtung | `type` | Inhalt |
|---|---|---|
| Z → G | `spec_join` | `{ "run_id" }` oder `{ "channel": "<twitch_login>" }` |
| G → Z | `spec_key` | Keyframe alle 10 s: Zuschauer-Zustand (Positionen, HP, Hype, Quest, Timer, Inventar-Kurzfassung) **mit Fog-of-War**: nur Zellen, die das beobachtete Team bereits besucht hat (Kap. 5.3) |
| G → Z | `spec_snap` | 5 Hz Positions-Delta (Gegner nur in besuchten/sichtbaren Zellen) |
| G → Z | `spec_ev` | Erkundungs-Events, `battle_start`, `act` (inkl. `action_seed` — erlaubt, weil verzögert), `gift` (für Zuschauer ohne `roll`/`sender_ref`) |
| G → Z | `spec_vote` | `{ "vote_id", "phase": "open" \| "tally" \| "close", "options", "tally"?, "ends_at" }` |
| G → Z | `spec_feed` | Geschenk-Feed: Absendername (nur bei Opt-in, sonst „Anonym“) + Geschenkart/Kistenstufe — **keine Inhalte**, keine exakten Zeitstempel, keine `gift_id`/Log-ID (L12, Kap. 7.5). Inhalte höchstens aggregiert („heute 120 Sponsorkisten, davon 9 % mit epischem Inhalt“) |
| G → Z | `spec_board` | Live-Rangliste des Fensters (alle 15 s) |
| G → Z | `spec_window` | Sponsor-Fenster des beobachteten Laufs (Kap. 6.13): `{ "open": bool, "closes_in_sec"?, "slots_free"?, "next_in_sec"? }` — **unverzögert** (Server-Zeit), damit Kauf-/Geschenk-Oberflächen den echten Zustand zeigen; **ohne** Art/Bezug des Fensters (`kind`/`ref` würden z. B. „Team steht vor dem Boss“ 30 s vor dem Bild verraten, Ghosting); Art und Overlay-Badge kommen mit dem verzögerten Strom |
| G → Z | `spec_end` | `{ "summary", "replay_id" }` |
| Z → G | `vote` | `{ "vote_id", "option" }` (1 Stimme je Account/Twitch-ID, letzte zählt) |
| Z → G | `cheer` | `{ "kind": "confetti" \| "applause" \| "boo" }` (kosmetisch, rate-limitiert 1/5 s) |

Geschenke laufen **nicht** über den Zuschauer-WebSocket, sondern über die Shop-REST-API (Kap. 6.4; kostenlose Fan-Pakete aus
der Twitch-Extension über den EBS) — Zahlungen
brauchen Idempotenz und Belege.

### 4.7 Binärformat `snap` (Protokoll 1.1)

```
u8  msg_type = 0x10
u32 tick
u32 ack_in           (letzter verarbeiteter Eingabe-Tick; u32 reicht bei 30 Hz > 4 Jahre — u16 würde nach ~36 min
                      überlaufen, kürzer als max_run_wall_sec)
u8  count
count × {
  u16 entity_id
  i16 x   (Einheit 5 cm, Bereich ±1 638 m)
  i16 y
  i16 z
  u8  yaw (256 Stufen)
  u8  anim_state
  u8  flags (bit0 sneaking, bit1 ghost, bit2 in_battle, bit3 invuln, …)
}                     = 12 Byte pro Entität
```

### 4.8 Beispiele

Verbindungsaufbau:

```json
{"v":"1.0","type":"hello","seq":1,"ack":0,"tick":0,"body":{"token":"nk_eyJhbGciOi…","client_version":"0.9.3","sim_version":7,"data_hash":"3f9a…c1","platform":"windows","locale":"de"}}
{"v":"1.0","type":"welcome","seq":1,"ack":1,"tick":0,"body":{"session_id":"s_8Q2","server_tick":0,"sim_hz":30,"snap_hz":15,"reconnect_token":"rt_5kd…","v":"1.0"}}
```

Kampfbefehl und Lockstep-Antwort:

```json
{"v":"1.0","type":"cmd","seq":118,"ack":342,"tick":5120,"body":{"cmd_id":412,"cmd":{"t":"battle","battle_id":"b4","n":7,"kind":"skill","actor_id":"p0","skill_id":"kai_heavy_swing","item_id":"","target_ids":["e2"]}}}
{"v":"1.0","type":"act","seq":343,"ack":118,"tick":5121,"body":{"battle_id":"b4","n":7,"cmd":{"t":"battle","battle_id":"b4","n":7,"kind":"skill","actor_id":"p0","skill_id":"kai_heavy_swing","item_id":"","target_ids":["e2"]},"action_seed":91827364512,"auto":false,"state_hash":"a1c0…9e"}}
```

Geschenk-Zustellung (gleiches Format für Spieler und, verzögert, Zuschauer):

```json
{"v":"1.0","type":"gift","seq":344,"ack":118,"tick":5130,"body":{"gift":{"schema":1,"gift_id":"g_01JB7Q3M0F5W8V2TQK4N6H8R9S","source":"shop","kind":"chest","tier":"silver","amount":0,"sponsor_id":"","sender":{"display_name":"","anon":true,"sender_ref":"b_7f3a9c0d1e2f"},"message_key":"gift_msg_go_team","target":{"player_id":"p_A","run_id":"run_2Kx"},"event_id":"evt_2026w45_sat","window_id":"eu","league":"show","load_half":4,"effect_pm":769,"roll":{"commit":"3613e6c5…d64a","client_seed":"c0ffee4200000017","nonce":17,"log_id":"l_9f2c41d07ab3e655","table_id":"gift_f1","tables_hash":"5e2d…07","rolls":2,"guarantee":"rare","pity_forced":""},"contents":[{"rarity":"common","item_id":"item_ice_spray","qty":1},{"rarity":"rare","item_id":"item_brutzel_burger","qty":2}],"run_bound":true,"deliver_by_tick":0,"issued_at":"2026-11-07T19:42:05Z","sponsor_window":"sw_3","sig":"hmac-sha256:5b1e…"}}}
```

(Werte entsprechen dem Testvektor Kap. 7.4: Silber-Kiste, Last L = 2 → `effect_pm = 769` → 2 Würfe. Absender standardmäßig
anonym, L13. `sponsor_window` = das bei der Quote reservierte Sponsor-Fenster (Kap. 6.13). Für Zuschauer wird das Gift ohne
`roll`/`sender_ref` weitergegeben.)

Zuschauer-Vote:

```json
{"type":"spec_vote","body":{"vote_id":"v_12","phase":"open","options":["tw_lights_out","tw_double_trouble","tw_mopsula_monologue"],"ends_at":"2026-11-07T19:44:30Z"}}
{"type":"vote","body":{"vote_id":"v_12","option":"tw_double_trouble"}}
```

---

## 5. Zuschauer / Spectating

### 5.1 Event-Stream-Fan-out

```
Instanz (Server) bzw. Client (S2) ──► Pub/Sub-Thema run.<run_id>  (NATS JetStream, 10 min Aufbewahrung)
                                          │
                                          ├─► Delay-Puffer (hält Nachrichten bis now − delay; erzeugt Keyframes)
                                          │       └─► Thema spec.<run_id>
                                          │                 ├─► WS-Gateway 1..n ──► Zuschauer (je ≤ 10 000 Verbindungen)
                                          │                 └─► Segmentierer (S5) ──► 2-s-Segmente (gzip) ──► CDN ──► Zuschauer
                                          ├─► Replay-Schreiber (Run-Log → Objektspeicher)
                                          └─► Ranglisten-Aggregator (Live-Board des Fensters)
```

- WS-Gateways sind zustandslos bis auf Abos; Skalierung horizontal hinter einem Load-Balancer.
- **CDN-Segmente** (ab S5): Weil 15–30 s Verzögerung ohnehin gewollt sind, wird der Datenstrom wie HLS in 2-s-Segmente
  (`/live/<run_id>/<n>.jsonl.gz` + `index.json`) geschnitten und über CDN ausgeliefert — skaliert billig auf 100 000+.
  Votes und Cheers gehen weiterhin per WS/REST.

### 5.2 Verzögerung

| Kontext | Delay | Grund |
|---|---|---|
| Show-/Pur-Liga mit Parallel-Teams | **30 s** | Ghosting verhindern (Kartenwissen, Treppenposition, Bosszustand) |
| Solo-Live ohne Wettbewerb (Training) | 15 s | flüssiger für Chat-Interaktion |
| Eigener Stream der Spieler:in (OBS) | Sache der Streamer:in; Empfehlung ≥ 30 s bei Wettbewerb | Twitch-Stream-Delay-Einstellung **[zu prüfen: verfügbare Stufen]** |
| Nach `closed` | 0 s (Replay) | — |

Votes und Geschenke berücksichtigen den Delay: Zuschauer sehen den Stand von vor `delay` Sekunden. Vote-Fenster werden
deshalb in **Zuschauerzeit** geöffnet und das Ergebnis frühestens bei `close + 5 s` (Server-Zeit) angewendet; die M.O.D.
kündigt den Twist 10 s vorher an. Geschenke kommen beim Spieler „früher“ an, als Zuschauer sie im Feed sehen — Feed zeigt
die Zustellung bei Erreichen im verzögerten Strom (konsistentes Bild für Zuschauer). **Sponsor-Fenster** (Kap. 6.13) gelten in
Server-Zeit: Ob ein Geschenk angenommen wird, entscheidet der Zustand der Instanz, nicht das verzögerte Bild — deshalb kommt der
Fensterzustand für Kauf-/Geschenk-Oberflächen unverzögert per `spec_window` (Kap. 4.6), das Overlay im Bild zeigt den Stand von
vor `delay` Sekunden; die Gnadenfrist (`grace_sec`) deckt Reservierungen in den letzten Sekunden eines Fensters ab.

### 5.3 Spoiler-Schutz für Parallel-Teams: Fog-of-War (+ Symmetrie als Zusatz)

Alle Teams eines Fensters spielen denselben Seed (fairer Vergleich). Der **eigentliche Spoiler-Schutz ist Fog-of-War im
Zuschauerstrom:** `spec_key`/`spec_snap`/Taktik-Ansicht zeigen nur Zellen, die das beobachtete Team **bereits besucht** hat;
Treppe, Boss und Truhen erscheinen erst, wenn das Team sie gefunden hat. Wer einem anderen Team zusieht, lernt also nur, was
dieses Team (30 s früher) schon wusste — nicht die ganze Karte. Ergänzend: Etagen-Layout erst bei `open` ausgeliefert.

**Symmetrie-Varianten (nur Zusatz-Obfuskation):** Jedes Team bekommt eine Raster-Symmetrie (02_TECH §7:
`DungeonGenerator` auf `w × h`-Raster): bei quadratischem Raster 8 Varianten (Drehung 0/90/180/270°, jeweils gespiegelt oder
nicht — Diedergruppe D4), bei nicht-quadratischem 4: `sym = u48(HMAC(server_seed, "sym|" + team_id)) mod n_sym` (Kap. 7.3).
Allein schützt das wenig: Der Start liegt kanonisch immer bei `(w/2, h−1)`, wer eine (verzögerte) Karte eines anderen Teams
sieht, findet die Transformation unter höchstens 8 Kandidaten sofort. Deshalb gilt:
- **Kanonisch simulieren (normativ):** Kern, Server und Verifier rechnen **immer im untransformierten Raum**. `sym` wird nur an
  der **I/O-Grenze** angewendet: Eingaben (`mx`, `mz`, `yaw`) des Clients werden invers transformiert, Snapshots, `ev` und
  Zuschauer-Daten werden transformiert ausgegeben. Damit laufen alle Laufzeit-Tie-Breaks (Patrouillen-Startrichtung,
  Nachbar-Reihenfolge N/E/S/W, Kollisionsauflösung X-vor-Z, „kleinstes y, dann x“) für alle Teams identisch → Weglängen,
  Begegnungen und Ergebnisse sind **exakt** gleich. (Die frühere Variante „Symmetrie nach der Generierung auf `FloorLayout`
  anwenden“ ist verworfen, weil die Tie-Breaks dann in transformierten Koordinaten laufen.)
- Der Client stellt die transformierte Welt dar; das Run-Log enthält kanonische Eingaben + `sym` im Header.

### 5.4 Zuschauer-Clients

| Client | Ab | Technik | Funktionen |
|---|---|---|---|
| **In-Game-Zuschauermodus** | S2 | Godot-Client, spielt `spec_*` über dieselben Darstellungsszenen ab (Events-Abspieler, Brief 6b.2) | freie/verfolgende Kamera, Senderwechsel zwischen Läufen, Votes, Cheers, Geschenke (Link zum Shop) — nur bei offenem Sponsor-Fenster, sonst „Nächstes Fenster in m:ss“ |
| **Web-Viewer** | S2 | Godot-**Web-Export** mit `gl_compatibility` (Brief: alle Shader kompatibel); Option ohne Threads, um COOP/COEP-Header-Anforderungen zu vermeiden **[zu prüfen für 4.7]** | wie In-Game, reduzierte Effekte; Fallback „Taktik-Ansicht“ (2D-Karte in HTML/Canvas) für schwache Geräte |
| **Twitch-Extension** | S2 (Votes), S3 (Sponsor-Fenster-Anzeige) | HTML/JS-Overlay bzw. Panel (keine Godot-Engine im Overlay) | Minikarte (Fog-of-War), HP/Hype/Timer/Quest, Votes, Applaus, Sponsor-Fenster (offen/zu, nächstes), Odds-Ansicht, Gift-Feed (ohne Inhalte); **keine Bits-Produkte und keine Kaufknöpfe** (Entscheidung 2026-10-08, Kap. 8.4); ein Hinweis auf den Web-Shop nur, soweit die Twitch-Richtlinien das erlauben **[zu prüfen]**, und nie als Kaufaufruf |
| **OBS-Browser-Quelle** | S2 | gleiche Web-Overlay-Seite mit `?mode=obs` | für Streamer:innen auf beliebigen Plattformen (YouTube, Kick …) |
| **YouTube** | S5 | keine Bits-ähnliche Extension-Schnittstelle bekannt **[zu prüfen]** → Begleit-Webseite (Votes/Geschenke über eigenen Shop C) + OBS-Overlay | Super-Chat-Kopplung an Zufallsinhalte **nicht** planen **[Richtlinien zu prüfen]** |

**Minderjährige im Publikum:** Twitch erlaubt Nutzer:innen nach unserem Kenntnisstand ab 13 Jahren **[zu prüfen]**; Zuschauerschaften
enthalten also Kinder und Jugendliche. Deshalb gilt in **allen** Zuschauer-Clients (In-Game, Web-Viewer, Extension, OBS-Overlay):
Kaufknöpfe für Geschenke (zufällig und nicht-zufällig) nur für eingeloggte, altersverifizierte (18+) Konten; keine
Kaufaufforderungen in UI-Texten, M.O.D.-Zeilen oder Overlays („Jetzt Kiste schicken!“ o. Ä.).
**Creator-Richtlinien / AGB für Streamer:innen** (Pflicht vor Freischaltung von Geschenken im Kanal; Streamer:innen erhalten
**keine** Beteiligung an Geschenken, Entscheidung 2026-10-08): keine direkten
Kaufaufrufe an das Publikum (Risiko direkter Kaufaufforderung an Kinder, UWG Anhang Nr. 28 **[zu prüfen]**), Kennzeichnung
„Zuschauer-Geschenke mit Zufallsinhalt aktiv — Wahrscheinlichkeiten: *Odds-Link*“ im Overlay, Einhaltung der
Twitch-Richtlinien zu Glücksspiel-ähnlichen Inhalten **[zu prüfen]**; Verstöße → Geschenke im Kanal deaktiviert.

### 5.5 Replays aus Seed + Befehls-Log

- Ein Replay ist das **Run-Log** (Kap. 10.6): Header (Event, Seeds, Versionen, Hashes) + Eingabe-Frames (lauflängenkodiert)
  + Befehle + externe Eingänge (Gifts, Twists) + Checkpoint-Hashes. Bei Live-Läufen zusätzlich die `action_seed`s
  (nach Reveal auch aus dem Server-Seed ableitbar).
- Größe: 25 min × 30 Hz = 45 000 Eingabe-Frames; nur Änderungen gespeichert (~25 %) × 6 B ≈ 70 KB, gzip ≈ 20–40 KB;
  Kampfbefehle ~10 KB. **≈ 30–60 KB pro Lauf.**
- Wiedergabe: lokal im Client (Spulen über Checkpoints, 1×/2×/8×), im Web-Viewer, und serverseitig für Highlights.
- Archiv: Replays der Top 100 pro Fenster dauerhaft, übrige 90 Tage (Speicherregel im Löschkonzept).

### 5.6 Bandbreiten-Schätzung

| Strom | Rechnung | Ergebnis |
|---|---|---|
| Spieler hoch (Eingaben) | 15 Pakete/s × (~30 B Nutzlast + ~50 B WS/TLS/TCP-Overhead) | ~10 kbit/s |
| Spieler runter (Snapshots) | 15 Hz × (≤ 12 Entitäten im Interest-Radius × 12 B + 8 B) ≈ 2.3 KB/s + Events | ~20–30 kbit/s (binär), ~60–90 kbit/s (JSON 1.0) |
| Zuschauer (pro Lauf) | 5 Hz × ~150 B (Delta) + Events ~200 B/s + Keyframe 2 KB/10 s | ~6–10 kbit/s binär, ~15–25 kbit/s JSON+deflate |
| Server-Ausgang pro Instanz (4 Spieler) | 4 × 30 kbit/s + Pub/Sub-Strom 10 kbit/s | ~130 kbit/s |

### 5.7 Skalierungs-Schätzung

| Stufe | Gleichzeitige Läufe | Zuschauer gesamt | größter Einzel-Lauf | Auslieferung |
|---|---|---|---|---|
| S2 | 50–200 | ≤ 2 000 | ≤ 500 | 2 WS-Gateways |
| S3 | 200–1 000 | ≤ 10 000 | ≤ 5 000 (Streamer) | 3–5 WS-Gateways |
| S5 | 3 000–5 000 | ≤ 100 000 | ≤ 30 000 | WS + CDN-Segmente |

Faustwert: ein WS-Gateway (4 vCPU) bedient ~10 000 Verbindungen à 20 kbit/s (= 200 Mbit/s) **[in S2 messen]** — gilt nur
mit **einmal pro Lauf vorkodierten** und vorkomprimierten Frames (Kap. 4.1); mit `permessage-deflate` je Verbindung wäre der
Wert deutlich niedriger. Lasttest mit einem großen Einzellauf (5 000 Zuschauer, Kap. 2 S2).

---

## 6. Zuschauer-Interaktion

### 6.1 Kostenlose Fan-Währung „Applaus“ (AP, ab S2)

| Regel | Wert |
|---|---|
| Verdienen | +1 AP pro voller Minute Zuschauen (angemeldet, Tab sichtbar), +5 AP pro abgegebener Stimme (max. 10 Stimmen/Event) |
| Obergrenze | 120 AP pro Event, Kontostand max. 300 AP |
| Ausgeben | Cheers (0 AP, kosmetisch, jederzeit), **Fan-Paket** (30 AP, Gift `source: "fan"`, `kind: "fan_pack"`; wie jede Hilfe nur in einem offenen **Sponsor-Fenster**, Kap. 6.13), Zuschauer-Kosmetik (Avatar-Rahmen im Feed) |
| Kaufbar | **nein**, nie. Kein Umtausch Token ↔ AP. Seit 2026-10-08 auch der Weg für Twitch-Zuschauer:innen (B = kostenlose Interaktion: Votes + Applaus, Kap. 8.4) |
| Verfall | AP verfallen 30 Tage nach Erwerb (keine Wertaufbewahrung, kein Geldwert). |

### 6.2 Votes (Twists)

**Was abgestimmt wird** (Daten `res://data/twists.json`, je Event Auswahl in `events.json → votes.pool`):

| ID | Name | Wirkung | Spielrelevant | Dauer |
|---|---|---|---|---|
| `tw_lights_out` | Stromausfall | Sichtweite Gegner −50 %, Spieler-Sicht reduziert (Vignette) | ja | 60 s Erkundung |
| `tw_double_trouble` | Doppelte Quote | Nächster Kampf: +1 Gegner (aus Gruppen-Pool der Zone), EXP/Credits ×1.5 | ja | 1 Kampf |
| `tw_rat_rain` | Rattenregen | Spawnt 1 Streuner-Gruppe außerhalb der Sichtweite | ja | einmalig |
| `tw_sponsor_rush` | Werbeblock | Nächste Hype-Schwelle gibt 2 System-Geschenke statt 1 (zählt gegen Max. pro Kampf) | ja | 1 Kampf |
| `tw_fog_of_fame` | Ruhmesnebel | Zerfall des Hype in Erkundung pausiert | ja | 90 s |
| `tw_boss_mood` | Bosslaune | Vor Bosskampf: Publikum wählt eine von 2 Boss-Varianten (`aggressive`: +10 % STR, EXP ×1.2 / `vain`: −10 % SPD, Hype-Gewinne ×1.2) | ja | 1 Kampf |
| `tw_mopsula_monologue` | Mopsula-Monolog | Mopsula hält eine (Show-)Rede, M.O.D. kommentiert | **nein** | 10 s |
| `tw_costume` | Kostümwahl | Mopsula-Kostüm für den Rest des Laufs | **nein** | Lauf |
| `tw_mod_mood` | M.O.D.-Laune | M.O.D.-Sprüche-Satz `snarky`/`sweet` | **nein** | 5 min |

**Takt & Regeln:**
- Ein Vote öffnet alle `votes.interval_sec` (Standard 240 s) **Erkundungszeit**, nie während Kampf/Safe Room/Cutscene.
- Dauer `votes.duration_sec` 45 s (Zuschauerzeit), 3 Optionen (zufällig aus Pool, Stream `event`), Gleichstand → Option mit
  kleinerem Index (deterministisch).
- Max. 1 aktiver spielrelevanter Twist gleichzeitig; Mindestabstand 60 s zwischen Ende eines Twists und Beginn des nächsten.
- **Eine Stimme pro Konto**, ungewichtet. **Keine bezahlten Stimmen**, keine Stimm-Booster.
- Pur-Liga: nur Twists mit `gameplay: false`. Spieler:in kann spielrelevante Votes nicht ablehnen (Teil der Show-Liga-Regeln),
  aber Show-Liga ist Opt-in.
- Twist-Anwendung ist ein externer Eingang im Run-Log (`{"t":"twist","id":…,"vote_id":…}`) → Replay-identisch.

### 6.3 Geschenk-Arten

| `kind` | Inhalt | Zufall | Quellen (`source`) | Preis | Sponsor-Fenster (Kap. 6.13) |
|---|---|---|---|---|---|
| `sponsor_buff` | Ein System-Sponsor aus GDD 7.4 (`sponsor_id`) | nein (bei `system`: Auswahl per Show-RNG wie GDD) | `system`, `shop` | 150 ST | nötig (außer `system`) |
| `gold` | Credits (`amount`: 100 oder 250) | nein | `shop` | 50 ST je 100 Credits | nötig |
| `chest` | Sponsorkiste Bronze/Silber/Gold | **ja** | `shop` | Kap. 6.6 | nötig |
| `fan_pack` | 1 Wurf aus Pool `common` + Hype +5 | ja (nur `common`) | `fan` | 30 AP | nötig |
| `cheer` | Konfetti/Applaus-Effekt, Chat-Zeile | nein | `fan`, `shop`, `bits` (reserviert) | 0 AP (kostenlos) | **nicht** nötig (kosmetisch, `exempt_kinds`) |

`source` ∈ `system` (Hype-Schwelle, im Kern erzeugt), `fan` (AP), `shop` (eigener Shop: Web und App-Store-IAP), `dev`
(Test/QA, nur Debug-Builds), `bits` (**reserviert**, derzeit keine Quelle: Bits-Geschenke mit Spielwirkung bzw. gegen Bits sind
**gestrichen per Entscheidung 2026-10-08**, Kap. 8.4; der Kern kennt den Wert weiter, damit ein späteres, L11-konformes
Bits-Erlösmodell **[zu prüfen]** keinen Schemabruch braucht — die Event-Regeln führen ihn nicht in `rules.gifts.sources`).
Die Spalte „Quellen“ ist verbindlich: `Gift.validate` lehnt jede andere Kombination ab (`Gift.KIND_SOURCES`); `bits` darf
ausschließlich das kosmetische `cheer` tragen, nie ein Geschenk mit Spielwirkung. `dev` darf jede Art senden, wird aber in
Event-Läufen nur angenommen, wenn die Event-Regeln `dev` in `rules.gifts.sources` nennen (Kap. 10.1).

### 6.4 Gift-Flow Ende-zu-Ende

```
 Zuschauer:in (eigener Shop C: Web-Shop, ab S5 App-Store-IAP) — eingeloggt, PTD-Konto, Altersstatus 18+ (L6)
 (Twitch-Extension B: nur kostenlose Votes/Applaus — Entscheidung 2026-10-08, L11; Fan-Pakete laufen ab Schritt 5 gleich)
   1. wählt Ziel (Lauf/Spieler:in) + Geschenk → Client fragt GET /gifts/quote {target, kind, tier, client_seed}
      client_seed: Pflicht in JEDEM Kaufkanal (Web, App), genau 16 Hex-Zeichen (Kap. 7.2)
      Gift-Service prüft VORAB: Event-Fenster offen, **Sponsor-Fenster des Ziels offen und Platz frei, Käufer:in hat in
      diesem Fenster noch nicht geschenkt** (Kap. 6.13; sonst E_WINDOW_CLOSED / E_WINDOW_FULL / E_WINDOW_SENDER_LIMIT
      mit next_window_in_sec — die Oberfläche zeigt, wann das nächste Fenster öffnet), Ziel in Show-Liga,
      Ziel-Altersstatus + gift_accept, Caps & Last & Wirkungsschwelle (Kap. 6.10), Käufer-Alter/Geo (Positivliste)/
      Limits/Selbstsperre, kein Selbstgeschenk, Restlaufzeit ≥ min_interval_sec + 120 s
      → vergibt nonce (fortlaufend je Käufer:in & Event, ab hier verbraucht, lückenlos) und RESERVIERT den Zustellplatz
        EXKLUSIV bis zur Zustellung (zählt sofort gegen Caps/Mindestabstand **und gegen die Plätze des Sponsor-Fensters**;
        parallele Quotes können ihn nicht belegen)
      → Antwort: { quote_id, price, rolls, effect_pm, odds_url, expires_in: 60, sponsor_window, substitute_rule }
        (sponsor_window = ID des reservierten Fensters; der Platz hält über das Fensterende hinaus bis zur Gnadenfrist
        grace_sec, Standard 15 s — Zahlung und Zustellung müssen in dieser Zeit erfolgen, sonst Erstattung/kein Kauf)
      → bei gift_accept = "ask": gift_offer an die Spieler:in VOR der Zahlung (10 s); erst nach Annahme ist die Quote
        bezahlbar; Ablauf = Ablehnung (Kap. 6.11) → keine Zahlung, kein Wurf
   2. Bestätigungsdialog (vor der Zahlung, Kap. 9 „Kaufprozess“): aktuelle Wurfzahl („Sie erhalten 1 statt 4 Würfe“ bei
      verminderter Wirkung), Kisten-Kennzahlen für genau diese Wurfzahl, Odds-Link, Hinweis auf Ausgaben „heute/Monat“;
      **kein** Countdown und keine „nur noch X Plätze“-Anzeige im Kauf-Flow (L16: der Platz ist ja schon reserviert);
      Button „zahlungspflichtig bestellen“ + Zustimmung zum sofortigen Beginn der Leistung **[zu prüfen]**
   3. Kauf
      Web: POST /gifts {quote_id}  → Ledger: Wallet → Escrow (atomar, idempotent über quote_id); Bestätigungs-Mail
         (dauerhafter Datenträger) mit Pflichtinformationen
      App (S5): Store-Kauf → signierter Beleg → Shop-API prüft serverseitig (Kap. 8.5) → wie Web weiter mit 4.
      (B: Bits-Kauf — gestrichen per Entscheidung 2026-10-08; früher useBits → EBS → Ledger-Memo, Kap. 8.4)
   4. Erst JETZT (Zahlung bestätigt, Platz exklusiv reserviert, Zustellung verbindlich) würfelt der Gift-Service:
      gift_id (ULID, intern), log_id (Zufalls-ID ohne Zeitbezug, öffentlich, Kap. 7.5), pity_forced aus den Zählern
      → Fairness-Service: roll_key = HMAC(server_seed, …) → contents (Kap. 7.4) → signiertes Gift-Dictionary
      → gift_log-Eintrag mit Status "rolled" (jede Wurfberechnung wird geloggt, auch spätere Erstattungen)
   5. Zustellung an die Instanz (immer Server-Sim bei Echtgeld, L14) über Game-Gateway
      (Gratis-Gifts im Client-Sim-Modus S2: an den Client, mit deliver_by_tick)
   6. Instanz: Show.receive_gift(gift) → Gift.validate + GiftPolicy (zweite, autoritative Prüfung inkl. Sponsor-Fenster des
      Stempels gift.sponsor_window; wegen exklusiver Reservierung + Gnadenfrist im Normalfall immer erfolgreich) → Run-Log-
      Eintrag {"t":"gift"} → Kern wendet an der nächsten sicheren Grenze an (Erkundung: sofort; Kampf: nächste Zuggrenze —
      im Kampf öffnet kein Fenster, ein vorher geöffnetes bleibt eingefroren offen; Safe Room: sofort)
      → Ereignis gift_delivered → Darstellung: Sponsor-Drohne, Inhalt SOFORT sichtbar (keine Spannungsanimation, keine
        künstliche Verzögerung, kein Near-Miss, L12) + M.O.D.-Zeile (neutral, L13)
   7. Instanz bestätigt (ack, serverseitig) → Gift-Service → gift_log-Status "delivered" → Ledger: Escrow → verbraucht
      (Umsatz realisiert, Kap. 8.3). Kein Umsatz auf Basis eines Client-Acks.
      Zuschauer-Feed (verzögert) zeigt Geschenkart/Stufe + Absender nur bei Opt-in, keine Inhalte (L12);
      Käufer:in erhält Beleg (log_id, commit, client_seed, nonce, rolls, contents) + Kaufhistorie-Eintrag
   Fehlerpfad: Zustellung trotz Reservierung nicht möglich (Lauf endet vorzeitig: Tod/Abbruch/Disconnect; Spieler:in lehnt
      ab; Instanz-Ausfall ohne Wiederanlauf)
      → gift_log-Status "refunded" bzw. "substituted" mit Grund — der Wurf bleibt im Log und ist nach Reveal nachrechenbar
      → Escrow → Wallet zurück (vollständig) bzw. Erstattung über PSP/Store (App)
```

**Reservierung statt nachträglicher Ablehnung:** Gründe, die nach Kenntnis des Wurfs entstehen könnten (Cap durch
Parallel-Gifts, Mindestabstand, Timeout, **volles oder geschlossenes Sponsor-Fenster**), werden **vor** dem Würfeln durch die
exklusive Reservierung ausgeschlossen. Was
danach noch scheitern kann (Laufende, Ablehnung, Ausfall), wird mit Status geloggt; `verify_fair.py` meldet Erstattungsquoten
je Rarität (Kap. 7.6) — eine selektive Nichtzustellung epischer Würfe wäre damit sichtbar.

**Reihenfolge-Garantie:** Gifts an denselben Lauf werden strikt nach Reservierungs-Reihenfolge (= `gift_id`, ULID, zeitlich
sortiert) angewendet; der Server ist einziger Schreiber. **Idempotenz:** dieselbe `gift_id` wird nie zweimal angewendet
(`Show.receive_gift` liefert dann `{"ok": false, "reason": "duplicate"}`).

### 6.5 Gift-Dictionary-Schema (exakt, `schema: 1`)

Dieses Dictionary ist das **einzige** Geschenkformat — für System-, Fan- und Shop-Geschenke (Bits: reserviert, Kap. 6.3). `Show.receive_gift(gift: Dictionary)`
nimmt genau dieses Format; der Kern wendet genau dieses Format an (`GiftApplier` außerhalb von Kämpfen, `BattleState.apply_gift` im Kampf, Kap. 11).

| Feld | Typ | Pflicht | Regeln |
|---|---|---|---|
| `schema` | int | ja | `1` |
| `gift_id` | String | ja | ULID mit Präfix `g_` (System: `g_sys_<battle_n>_<k>` deterministisch); eindeutig je Lauf |
| `source` | String | ja | `system` \| `fan` \| `bits` (reserviert, nur `cheer` — Kap. 6.3) \| `shop` \| `dev`; erlaubte Kombination mit `kind` laut Tabelle Kap. 6.3 |
| `kind` | String | ja | `sponsor_buff` \| `gold` \| `chest` \| `fan_pack` \| `cheer` |
| `tier` | String | bei `chest` | `bronze` \| `silver` \| `gold`, sonst `""` |
| `amount` | int | bei `gold` | Credits **vor** Wirkungsfaktor (100 \| 250), sonst `0` |
| `sponsor_id` | String | bei `sponsor_buff` | ID aus `sponsors.json` (z. B. `sp_gluckwasser`), sonst `""` |
| `sender` | Dictionary | ja | `{ "display_name": String (≤ 24, gefiltert), "anon": bool, "sender_ref": String }`; **Standard `anon: true`, `display_name: ""`** — Namensnennung nur per Opt-in der Käufer:in (L13); `system`: `{ "display_name": "", "anon": true, "sender_ref": "" }`. `sender_ref` = pseudonymer Käufer-Schlüssel je Event (Kap. 7.5), Format **`b_` + 12 Zeichen `[0-9a-f]`**, Pflicht bei den Käufer-Quellen `fan`/`bits`/`shop` (die Caps je Käufer:in hängen daran), wird nie an Zuschauer ausgeliefert |
| `message_key` | String | ja | **nur vordefinierte** Botschaften (`gift_msg_*` in `mod_lines.json`), `""` erlaubt. **Kein Freitext** (Moderation/DSA) |
| `target` | Dictionary | ja | `{ "player_id": String, "run_id": String }` (S0 offline: `player_id: "local"`) |
| `event_id` | String | ja | `""` außerhalb von Events |
| `window_id` | String | ja | `""` offline |
| `league` | String | ja | `show` \| `pur` — Gift mit `source ≠ system` und `league = pur` ist ungültig |
| `effect_pm` | int | ja | vom Gift-Service berechneter Wirkungsfaktor in **Promille** (Kap. 6.10), `1000` bei `system`; dazu Pflichtfeld `load_half: int` = Lastbasis bei Reservierung (alle **vorher reservierten** externen Geschenke). Kern prüft `effect_pm == effect_pm(load_half)` exakt **und** `load_half ≥` Summe der bereits angewendeten Lasten; sonst `effect_mismatch`. Ersetzt das frühere `effect_mult: float` (keine Floats in signierten Strukturen, Kap. 3.3 Nr. 9) |
| `roll` | Dictionary | bei Zufall | `{ "commit": hex, "client_seed": hex16, "nonce": int, "log_id": String, "table_id": String, "tables_hash": hex, "rolls": int, "guarantee": "" \| "rare" \| "epic", "pity_forced": "" \| "rare" \| "epic" }`; `client_seed` = **genau 16 Zeichen `[0-9a-f]`** (kein Freitext); `log_id` = `l_` + 16 Hex-Zeichen CSPRNG ohne Zeitbezug (Kap. 7.5); bei `system`/offline: `{ "seed_stream": "show", "nonce": int, … }` |
| `contents` | Array | bei Zufall | Ergebnis vom Server: `[{ "rarity": String, "item_id": String, "qty": int }]` bzw. `{ "rarity", "credits": int }`; `qty` 1–9, `credits` 1–1000; `fan_pack` höchstens ein `common`-Eintrag; unbekannte `item_id` → `invalid_schema`. Offline/System leer → Kern würfelt selbst aus Seed-Stream |
| `run_bound` | bool | ja | immer `true` (Validierung schlägt sonst fehl) |
| `sponsor_window` | String | nein | `""` oder `sw_<n>`: Sponsor-Fenster, dessen Platz das Geschenk hält (Kap. 6.13) — gestempelt vom Gift-Service bei der Reservierung bzw. von `Show.receive_gift` bei der Annahme; steht im Run-Log. Ein gestempeltes Geschenk wird bis `grace_sec` nach dem Fensterende noch angenommen, ein ungestempeltes nur bei offenem Fenster. `system`-Geschenke: nie |
| `deliver_by_tick` | int | ja | `0` = keine Frist (Server-Sim). Im Client-Sim-Modus (nur Gratis-Gifts, S2): vom Gift-Service gestempelte Frist (Server-Tick-Schätzung + Toleranz); der Verifier lehnt Läufe ab, deren Log das Gift nicht bis dahin anwendet oder es fehlen lässt |
| `issued_at` | String | ja | ISO-8601 UTC (nur Anzeige/Audit; **nie** in Kern-Logik verwendet); offline `""` |
| `sig` | String | ab S3 | `"hmac-sha256:" + hex` über kanonisches JSON (Kap. 3.3 Nr. 9) ohne `sig`, Schlüssel = Service-Schlüssel des Gift-Service. **Zweck:** schützt das Run-Log gegen eingeschleuste Gifts; geprüft **serverseitig** (Instanz, Verifier) mit `Crypto.hmac_digest` (in Godot 4 vorhanden). **Keine** clientseitige Prüfung (ein Schlüssel im Client ist kein Geheimnis; im Client-Sim-Modus wäre sie ohnehin nutzlos). Falls Clients später doch prüfen sollen: ECDSA P-256 oder RSA über `Crypto.verify` (EC-Unterstützung in 4.7 **[zu prüfen]**); Ed25519 nur per GDExtension |

Rückgabe von `Show.receive_gift(gift: Dictionary) -> Dictionary`:
`{ "ok": bool, "reason": String, "gift_id": String, "apply": "now" | "queued" }`. `reason` ∈ `""`, `invalid_schema`,
`duplicate`, `league_pur`, `not_accepting`, `cap_reached`, `run_not_active`, `effect_mismatch`, `bad_signature`,
`chest_blocked` (Wirkungsschwelle, Kap. 6.10), `deadline_missed` (Client-Sim, `deliver_by_tick`), `window_closed`,
`window_full`, `window_sender_limit` (Sponsor-Fenster, Kap. 6.13 → `E_WINDOW_*`, Kap. 4.5), `wrong_target` (Geschenk nennt
einen anderen Lauf, Spieler, Event oder ein anderes Fenster, Kap. 6.9), `too_soon` (Mindestabstand, Kap. 6.10). Vor
`GiftPolicy.check` prüft `GiftPolicy.refusal` Duplikat und unbekannte Inhalte. Prüfreihenfolge in `GiftPolicy.check`:
Liga (bei mehreren Ligen ohne Lauf-Liga `not_accepting`) → Lauf-Bindung → Annahme/Quelle → Frist → Wirkungsfaktor →
Mindestabstand → Caps → Kistenschwelle → **Sponsor-Fenster zuletzt** (ein `window_*`-Grund heißt also „alles andere passt,
nächstes Fenster abwarten“).

### 6.6 Sponsorkisten: Stufen & Preise

| Stufe | `tier` | Würfe (bei Wirkung 100 %) | Garantie | Preis Shop (C) | Direktkauf (C) |
|---|---|---|---|---|---|
| Bronze-Sponsorkiste | `bronze` | 2 | — | 100 ST | 0,99 € |
| Silber-Sponsorkiste | `silver` | 3 | ≥ 1× `rare` oder besser | 300 ST | 2,99 € |
| Gold-Sponsorkiste | `gold` | 4 | ≥ 1× `epic` | 800 ST | 7,99 € |

~~Preis Bits (B): 100 / 300 / 800 Bits~~ — **gestrichen per Entscheidung 2026-10-08** (keine Echtgeld-Geschenke über Bits,
Kap. 8.4). App-Store-Preise (S5) folgen den Preisstufen der Stores, dieselben Würfe/Odds **[Preisstufen zu prüfen]**.

**Sponsor-Token-Pakete (C):** 100 ST = 0,99 € · 500 ST = 4,99 € · 1 000 ST = 9,99 € · 2 000 ST = 19,99 € — **keine
Bonus-Token** bei größeren Paketen (Transparenz). Das 100-ST-Paket und der **Direktkauf einzelner Kisten in Euro ohne Token**
vermeiden einen erzwungenen Vorab-Kauf von Guthaben (von den Verbraucherbehörden bei virtuellen Währungen kritisiert
**[CPC-Grundsätze zu prüfen, Kap. 9]**). Preise der Kisten überall auch in Echtgeld („300 ST = 2,99 €“ — Preis der Kiste,
**nie** ein Euro-Wert für Inhalte, L1). Wallet-Obergrenze 5 000 ST.

### 6.7 Drop-Tabellen, Gewichte, Odds-Anzeige

Seltenheits-Gewichte pro Wurf (identisch zu GDD 9.2, damit Spieler:innen die Werte kennen):

| Stufe | common | rare | epic |
|---|---|---|---|
| bronze | 80 | 18 | 2 |
| silver | 55 | 38 | 7 |
| gold | 25 | 55 | 20 |

Pool `gift_f1` (nur Inhalte, die es auf Etage 1 auch regulär gibt; Gewichte je Rarität summieren auf 100):

| Rarität | Eintrag | Gewicht | P/Wurf Bronze | P/Wurf Silber | P/Wurf Gold |
|---|---|---|---|---|---|
| common | 40 Credits | 30 | 24.00 % | 16.50 % | 7.50 % |
| common | `item_bandage` ×2 | 25 | 20.00 % | 13.75 % | 6.25 % |
| common | `item_energy_krawumm` | 20 | 16.00 % | 11.00 % | 5.00 % |
| common | `item_ice_spray` | 15 | 12.00 % | 8.25 % | 3.75 % |
| common | `item_molotov` | 10 | 8.00 % | 5.50 % | 2.50 % |
| rare | `item_brutzel_burger` ×2 | 30 | 5.40 % | 11.40 % | 16.50 % |
| rare | `item_smelling_salts` | 25 | 4.50 % | 9.50 % | 13.75 % |
| rare | `item_hype_megaphone` | 20 | 3.60 % | 7.60 % | 11.00 % |
| rare | `item_smoke` | 15 | 2.70 % | 5.70 % | 8.25 % |
| rare | 150 Credits | 10 | 1.80 % | 3.80 % | 5.50 % |
| epic | `item_elixir` | 40 | 0.80 % | 2.80 % | 8.00 % |
| epic | `wpn_fire_axe` | 20 | 0.40 % | 1.40 % | 4.00 % |
| epic | `acc_sneakers` | 20 | 0.40 % | 1.40 % | 4.00 % |
| epic | 400 Credits | 20 | 0.40 % | 1.40 % | 4.00 % |

Kisten-Kennzahlen (Referenz bei Wirkung 100 %, ohne Pity): Bronze — mind. 1× rare+ 36.0 %, mind. 1× epic 3.96 %;
Silber — mind. 1× rare+ 100 % (Garantie), mind. 1× epic 22.2 %; Gold — mind. 1× epic 100 % (Garantie).
Die Kennzahlen werden **immer für die aktuelle Wurfzahl** berechnet und angezeigt (z. B. Silber mit 2 Würfen: mind. 1× rare+
100 %, mind. 1× epic = 0.07 + 0.38 × 0.07 + 0.55 × 7/45 ≈ 18.2 %); Generator rechnet sie aus `gift_tables.json` und dem
Garantie-Algorithmus (Kap. 7.4).

**Odds-Anzeige (Pflicht vor jedem Kauf):** Tabelle wie oben (pro Wurf + Kisten-Kennzahlen **für die aktuelle Wurfzahl**),
**aktuelle Wurfanzahl beim gewählten Ziel** (wegen Wirkungsfaktor; bei Minderung ausdrücklich „Sie erhalten 2 statt 3
Würfe“ mit Bestätigung, Kap. 6.4), Link zur öffentlichen Odds-Seite und zum Commit des Fensters. **Nicht** im Kauf-Flow: der
Pity-Stand (kein „noch 4 Kisten bis garantiert episch“, kein Countdown-Text) — er ist nur auf Abruf in Kaufhistorie bzw.
Spielerschutz-Center sichtbar (L2). **Keine Euro-Werte für Inhalte** (L1). Nutzerseitige Begriffe neutral („Ziehung“,
„nachprüfbare Zufallsziehung“), kein Casino-Vokabular (L12). Die Anzeige wird aus derselben Datei (`gift_tables.json`, Hash
im Commit) generiert, die der Server zum Würfeln nutzt — keine manuell gepflegte Kopie. Ausrüstungs-Duplikate werden wie in
GDD 9.3 zu Credits.

### 6.8 Pity-Regeln

| Regel | Wert | Bezug | Verifizierbar |
|---|---|---|---|
| Käufer-Pity rare | Nach **3** bezahlten Kisten in Folge ohne rare+ ist der **erste Wurf** der nächsten Kiste fest `rare` (feste Rarität statt „rare oder besser“ — einfacher nachprüfbar; die übrigen Würfe bleiben normal) | pro Käufer:in, **dauerhaft** (kein Reset nach Zeitraum), über alle Ziele und Events | ja (eigene Belege; Gift-Log je Event) |
| Käufer-Pity epic | Nach **9** bezahlten Kisten in Folge ohne epic ist der erste Wurf der 10. Kiste `epic` | dito | ja |
| Zähler-Reset | **nur** durch Treffer der jeweiligen Rarität (auch zufällig) → Zähler auf 0; kein zeitlicher Reset | — | ja |
| Sichtbarkeit | Pity-Stand **nur auf Abruf** in Kaufhistorie/Spielerschutz-Center, nie im Kauf-Flow, kein Countdown-Text, keine Push-Hinweise | — | — |
| Fan-Pakete | keine Pity (kein Geld) | — | — |
| Kampagnen-Lootboxen | unverändert GDD 9.3 (eigene Zähler im Spielstand) | — | — |

Begründung „Käufer-Pity“ statt „Spieler-Pity“: Geschützt werden soll die zahlende Person — als **Obergrenze für Pech**,
nicht als Kaufanreiz. Deshalb weder Anzeige im Kauf-Flow noch ein zeitlicher Reset: Ein Monats-Reset würde vor Monatsende
Kaufdruck erzeugen („Zähler verfällt“), eine Countdown-Anzeige wirkt als Sunk-Cost-/Dringlichkeits-Mechanismus (Dark
Pattern; CPC-Grundsätze, DSA Art. 25 **[zu prüfen]**). Der Gift-Service bestimmt `pity_forced` **vor** dem Wurf aus den
Zählern; das Feld steht im Gift-Dictionary und im öffentlichen Log.

### 6.9 Lauf-Bindung (L3)

- Live-Läufe starten **immer** aus `rules.party_preset` (Level, Ausrüstung, Inventar, Credits) in einem eigenen
  `GameState` (Slot 0, 02_TECH §3.6: wird nie geschrieben) — nie aus einem Kampagnen-Slot und nie zurück in einen.
- Gift-Inhalte werden zusätzlich in `GameState.flags["live"]["gift_items"]` gezählt (Statistik; `Inventory` kennt nur Mengen,
  02_TECH §6.1); zum Laufende wird der gesamte Lauf-Zustand verworfen.
- **Lauf-Zähler `GameState.flags["live"]`** (Teil des Zustands-Hashes; geschrieben vom Kern, gelesen von `GiftPolicy.check`):
  `league`, `gift_rules` (RunSim beim Laufstart aus `rules.leagues`/`rules.gifts`); `gift_ids` (jede angewendete externe
  Gift-ID, Duplikatschutz — `GiftPolicy.remember`); `load_half`, `external`, `chests`, `gold_chests`,
  `per_sender {sender_ref: n}`, `last_delivery_tick` (`GiftPolicy.note_applied`: bucht **jede** Anwendung genau einmal —
  außerhalb des Kampfes über `GiftApplier.apply`, im Kampf beim Ausgeben durch `Show.take_pending_gift` bzw. in RunSim über
  `GiftApplier.note_battle_gift`; der Duplikatschutz liegt allein bei `gift_ids`); `gift_items {item_id: n}`;
  optional `gift_accept` (Kap. 6.11). Externe Geschenke werden bei der **Anwendung** erneut geprüft (Show
  `application_refusal` ≡ `RunSim.gift_refusal`, beide über `GiftPolicy.refusal`), damit Live-Lauf und Verifier dieselben
  Geschenke annehmen.
- **Bindung an genau einen Lauf:** Der Kern vergleicht `target.run_id`, `target.player_id`, `window_id` und `event_id` des
  Geschenks mit der Lauf-Identität aus dem Run-Log-Header (`run_id`, `player_id` — S0: `"local"` —, `window_id`, `event_id`,
  Kap. 10.6). Jede bekannte, abweichende Angabe → `wrong_target`; ein Geschenk für ein Event passt nie in einen
  Kampagnen-Lauf. Bei Events mit mehreren Ligen muss der Lauf eine Liga gewählt haben (sonst `not_accepting`), und der
  Header nennt sie (`league`).
  Übrig bleiben nur Statistik, Replay, Bestenlisten-Eintrag, Profil-Belohnungen (Kap. 1.6).
- Koop: Gift-Inhalte gehen in das **Team-Inventar** des Ziels (eine Sendung, ein Inventar, Kap. 1.4). Eine Übergabe an
  andere Teams/Läufe ist technisch ausgeschlossen (verschiedene Instanzen, kein Fallenlassen/Handeln zwischen Instanzen).
- Keine Auszahlung, kein Rücktausch in Token/AP, keine Marktplätze, keine Account-Übertragung von Inhalten; Echtgeld fließt nur
  an den Betreiber, nie an Spieler:innen oder Streamer:innen (L11).

### 6.10 Caps & abnehmende Wirkung (L4)

**Geschenk-Last** eines Ziels im Lauf, **ganzzahlig in Halbpunkten** (`load_half: int`) = Summe der Gewichte aller bereits
**zugestellten oder exklusiv reservierten externen** Geschenke (`source ≠ system`): `cheer` 0 · `gold` 1 je 100 Credits ·
`fan_pack` 2 · `sponsor_buff` 2 · `bronze` 2 · `silver` 4 · `gold`-Kiste 8. (Anzeige: `L = load_half / 2`.)

**Wirkungsfaktor (normativ, nur Ganzzahlen, Integer-Division `//` = Abrunden bei nicht-negativen Operanden):**

```text
effect_pm(load_half) = 1000000 // (1000 + effect_k_pm * load_half)      # effect_k_pm = 75 (≙ 0.15 je Lastpunkt L)
rolls                = max(1, (base_rolls * effect_pm + 500) // 1000)   # kaufmännisch gerundet, sprachunabhängig
credits              = (amount * effect_pm + 500) // 1000
```

| L (`load_half`) | 0 (0) | 2 (4) | 4 (8) | 6 (12) | 8 (16) | 12 (24) | 16 (32) | 24 (48, Cap) |
|---|---|---|---|---|---|---|---|---|
| `effect_pm` | 1000 | 769 | 625 | 526 | 454 | 357 | 294 | 217 |

Grund für die Ganzzahl-Form: Bei L = 4 ergab die frühere Float-Formel für eine Gold-Kiste `4 × 0.625 = 2.5` — Godot `roundi`
rundet auf 3, Python `round()` auf 2; das öffentliche Prüfverfahren wäre sprachabhängig gewesen. Jetzt: `(4 × 625 + 500) // 1000 = 3`
überall. `verify_fair.py` rechnet `rolls` aus `load_half` nach (Testvektor Kap. 7.4).
Maßgeblich ist die Last aller **vor** diesem Geschenk reservierten Geschenke (`load_half` steht im Gift und im Log). Fällt ein
früher reserviertes Geschenk aus (Erstattung), bleibt die Lastbasis späterer Geschenke unverändert — jede Kiste behält genau
die beim Kauf angezeigte und bestätigte Wurfzahl; die Abweichung ist im Log nachvollziehbar.

**Anwendung des Faktors:**

| Art | Formel |
|---|---|
| `chest` | `rolls` wie oben; Garantie bleibt (auf dem letzten Wurf); Gewichte bleiben unverändert (veröffentlichte Odds gelten pro Wurf immer). **Kauf gesperrt**, wenn `effect_pm < rules.gifts.chest_min_effect_pm` (Standard 500, d. h. ab L ≥ 7) — dann nur noch nicht-zufällige Geschenke bzw. `cheer` (`E_CHEST_BLOCKED`). Ist `rolls < base_rolls`, muss die Käufer:in das im Quote-Dialog ausdrücklich bestätigen („Sie erhalten 2 statt 3 Würfe“) |
| `gold` | `credits` wie oben |
| `sponsor_buff` | Heilung/MP in % × `effect_pm` / 1000 (Ganzzahl); Status-Dauer `max(1, (3 * effect_pm + 500) // 1000)` Züge |
| `fan_pack` | Wurf unverändert, Hype-Bonus `(5 * effect_pm + 500) // 1000` |

Warum Sperre statt Preisstaffel: Kistenpreise sind fest (Shop-Preise, App-Store-Preisstufen), eine Preisskalierung mit
`effect_pm` wäre intransparent bzw. im Store nicht abbildbar. Mit der Schwelle zahlt niemand den vollen Preis für einen Bruchteil (z. B. früher: Gold-Kiste bei L = 24 → 1 Wurf
statt 4); innerhalb der Schwelle wird die Minderung offengelegt und bestätigt **[Verbraucherrecht/Preistransparenz zu prüfen]**.

**Harte Caps** (Show-Liga-Standard, in `events.json → rules.gifts`):

| Cap | Wert |
|---|---|
| Geschenk-Last pro Ziel und Lauf | `load_half ≤ 48` (L ≤ 24; danach nur noch `cheer`) |
| Kisten-Kauf | nur solange `effect_pm ≥ chest_min_effect_pm` (Standard 500) |
| Externe Geschenke pro Ziel und Lauf | 16 |
| Kisten pro Ziel und Lauf | 8, davon max. 2 Gold-Kisten (praktisch begrenzt meist schon die Wirkungsschwelle) |
| Mindestabstand zwischen zwei Zustellungen an ein Ziel | 45 s = 1 350 Ticks Lauf-Zeit (Warteschlange, Reihenfolge nach Reservierung). Auch der Kern prüft ihn (`too_soon`: `tick − last_delivery_tick < min_interval_sec × 30`) für Service-Geschenke (`fan`/`shop`/`bits`); ausgenommen `cheer`, `system` und `dev`. Im Kampf hält `Show` ein solches Geschenk zurück, bis der Abstand erfüllt ist |
| Verkaufsschluss | kein Verkauf, wenn die Restlaufzeit des Ziels (Fenster bzw. `max_run_wall_sec`) < `min_interval_sec` × (Warteschlangenlänge + 1) + 120 s Puffer |
| Geschenke pro Kampf | externe max. 1; **gesamt** inkl. System-Geschenke max. `SponsorSystem.MAX_GIFTS_PER_BATTLE` / `MAX_GIFTS_PER_BOSS_BATTLE` (02_TECH §6.1: 1 / 2; GDD 7.4 nennt 2 / 3 — Abgleich offen) — überzählige warten bis Kampfende |
| Pro Käufer:in → gleiches Ziel und Event | max. 5 Geschenke |
| **Sponsor-Fenster** (Kap. 6.13) | Geschenke nur bei offenem Fenster; je Fenster `slots_per_player` Plätze (3) je Ziel; je Zuschauer:in `per_viewer` (1) Geschenk je Fenster; `cheer` ausgenommen |
| Pro Käufer:in Ausgaben | Kap. 8.9 (EUR-Limits, an die verifizierte Identität gekoppelt) |

Caps werden **zweimal** geprüft: im Gift-Service vor dem Kauf (**exklusive Reservierung** des Zustellplatzes bis zur
Zustellung, damit niemand für ein abgelehntes Geschenk bezahlt und parallele Käufe nicht kollidieren) und im Kern bei der
Anwendung (autoritativ; wegen der Reservierung im Normalfall deckungsgleich). Eine Kollision paralleler Käufe nach dem Würfeln
ist damit ausgeschlossen; verbleibende Fehlerfälle siehe Kap. 6.4.

### 6.11 Annahme & Opt-out für Spieler:innen

| Einstellung (`gift_accept`) | Verhalten | Standard |
|---|---|---|
| `all` | alle Geschenke automatisch | Show-Liga, **nur** altersverifiziert 18+ |
| `free_only` | nur `fan_pack`/`cheer` und nicht-zufällige Geschenke (`gold`, `sponsor_buff`) | Show-Liga ohne Altersverifikation 18+ (**fest**, nicht änderbar) |
| `ask` | jedes Geschenk erscheint **vor der Zahlung** 10 s (300 Ticks) als Karte „Annehmen / Ablehnen“ (Gamepad: LB/RB, `gift_offer`, Kap. 4.5). **Ablaufen = ablehnen** für `kind: chest` (keine Zahlung, kein Wurf); Annahme per Zeitablauf höchstens für nicht-zufällige Geschenke | Option, nur altersverifiziert 18+ |
| `none` | keine externen Geschenke (Cheers weiterhin sichtbar) | **Pur-Liga (fest)** |

**Alter der Empfänger:innen (L6, normativ bis zum Gutachten):** Die Show-Liga mit `gift_accept` ≠ `free_only`/`none` steht
**nur altersverifizierten Spieler:innen ab 18** offen. Alle anderen (Alter unbekannt oder < 18) erhalten in der Show-Liga
**fest** `free_only` — **keine** Elternfreigabe, bis ein Gutachten etwas anderes erlaubt. Erhoben wird nur das Ergebnis
„18+ verifiziert“ (gleiches Verfahren wie für Käufer:innen, Kap. 8.9). Die Show-Liga ist für alle — auch Streamer:innen —
eine bewusste Opt-in-Entscheidung vor jedem Lauf, nie Standard (Kap. 1.5). Der Server erzwingt das beim `join` und der
Gift-Service bei der Quote.

Zusätzlich: Absender blockieren (Liste je Spieler:in), „Geschenkpause“ für 10 min (Streamer-Hotkey).
Abgelehnte Geschenke: bei `ask` vor der Zahlung → keine Kosten; nach Zahlung (Laufende/Ausfall) Erstattung an Käufer:in
(Kap. 8.6). (Die frühere Ersatzleistung für Bits entfällt mit Kap. 8.4.)

### 6.12 M.O.D.-Zeilen (neue Keys in `mod_lines.json`)

**Regeln für alle Geschenk-Zeilen (L13, normativ):** Dank-Zeilen sind **unabhängig von Kistenstufe und Preis** (ein Key
`gift_received` für alle bezahlten und kostenlosen Geschenke, Varianten nur zufällig aus `_fx_rng`, nie nach Stufe);
**kein Spott** über günstige oder kostenlose Unterstützung; **keine Steigerung** von Spektakel, Konfetti oder Lautstärke mit
dem Preis; keine Kaufaufforderung („Schickt mehr!“). Die Satire richtet sich gegen **NOVA SYNDIKAT** und die Show-Maschinerie,
nie gegen Zuschauer:innen. `{sender}` ist standardmäßig „ein anonymer Fan“ (Namensnennung nur per Opt-in).

| Key | Platzhalter | Beispiel |
|---|---|---|
| `gift_received` | `{sender}` | „Ein Paket von {sender}. NOVA SYNDIKAT verbucht das als ‚organische Zuschauerbindung‘. Wir nennen es nett.“ |
| `gift_received` (Variante) | `{sender}` | „Lieferung von {sender}! Die Rechtsabteilung prüft noch, ob Freundlichkeit lizenzpflichtig ist.“ |
| `gift_received_anon` | — | „Ein anonymer Fan schickt Grüße. Die Marketingabteilung ist neidisch auf so viel Zurückhaltung.“ |
| `gift_received_credits` | `{amount}` | „{amount} Credits. NOVA SYNDIKAT behält sich vor, darauf irgendwann eine Gebühr zu erfinden.“ |
| `gift_diminished` | `{pct}` | „Wirkung dieses Geschenks: {pct} Prozent. Das Regelwerk will es so. Ich habe das Regelwerk nicht geschrieben. Leider.“ |
| `gift_capped` | — | „Geschenk-Kontingent für diesen Lauf erreicht. Das Publikum bleibt trotzdem das Beste an dieser Sendung.“ |
| `gift_declined` | — | „Abgelehnt. Kandidat:innen dürfen das. Steht auf Seite 412 der Teilnahmebedingungen, gleich neben ‚Überleben‘.“ |
| `fan_pack_received` | `{sender}` | „Ein Applaus-Paket von {sender}. Echte Begeisterung — die Aktionäre wissen nicht, wie man die bilanziert.“ |
| `live_closing` | `{min}` | „Noch {min} Minuten bis Sendeschluss. Danach geht hier das Licht aus. Und die Etage.“ |
| `vote_open` | — | „Das Publikum entscheidet! Demokratie, aber mit Werbeunterbrechung.“ |
| `sponsor_window_open` | `{seconds}`, `{count}` | „Sponsor-Fenster offen: {seconds} Sekunden, {count} Plätze. NOVA SYNDIKAT nennt das Bürgerbeteiligung.“ (Variante: „… Helfen ist freiwillig, Zuschauen zählt genauso. Nur Zugluft ist Pflicht.“) |
| `sponsor_window_open:safe_room` | `{seconds}` | „Werbepause mit Sponsor-Fenster, {seconds} Sekunden lang. Wer nur zuschaut, macht auch alles richtig.“ |
| `sponsor_window_open:boss` | `{seconds}` | „Boss-Countdown! Das Sponsor-Fenster ist {seconds} Sekunden offen. Danach zählt nur noch Können. Und Glück.“ |
| `sponsor_window_closed` | — | „Sponsor-Fenster zu. Die Regie nennt das Programmstruktur. Ich nenne es: Durchzug verhindern.“ |
| `sponsor_window_full` | `{count}` | „Alle {count} Plätze im Sponsor-Fenster belegt. Danke – auch dem stillen Publikum. Das zählt hier am meisten.“ |
| `twist_applied_<id>` | — | je Twist eine Zeile |

`gift_msg_*` (vordefinierte Absender-Botschaften, z. B. `gift_msg_go_team` „Weiter so!“, `gift_msg_for_mopsula` „Für den Grafen!“).
Sponsor-Fenster-Zeilen (Kap. 6.13) spricht M.O.D. nur in Event-/Live-Läufen, die Zuschauer-Geschenke annehmen; sie nennen Zeit
und Plätze als Programminformation, nie einen Preis, nie einen Kaufaufruf, nie „schnell, nur noch …“ (L13, L16). In der
Kampagne bleibt es beim dezenten Hinweis im Overlay.

### 6.13 Sponsor-Fenster (Nutzerentscheidung 2026-10-08, L16)

> Entscheidung (2), Brief Kap. 5: „Zuschauer:innen können **nur begrenzt oft** und **nur zu bestimmten Zeiten** helfen.“

**Idee:** Hilfe kommt wie ein Werbeblock — zu festen Programmpunkten, mit wenigen Plätzen. Das begrenzt die Spielwirkung
zusätzlich zu den Caps (Kap. 6.10), macht Hilfe zum Show-Moment statt zum Dauerstrom und gibt Spieler:innen planbare Phasen
ohne Eingriffe von außen.

**Fensterarten** (höchstens **ein** offenes Fenster; Werte = Standard für Kampagne/Offline und jedes Event ohne eigene Angabe):

| Art (`kind`) | öffnet | offen | Plätze | Bemerkung |
|---|---|---|---|---|
| `periodic` | alle `periodic.every_sec` = **300 s Erkundungszeit** (das erste nach `first_sec` = 300 s) | `open_sec` = **60 s** | 3 | fällig, während ein anderes Fenster offen ist → entfällt (der Countdown startet neu) |
| `safe_room` | beim **Betreten eines Safe Rooms** (je Safe Room und Etage einmal, `once_per_room`) | solange drinnen, höchstens `max_sec` = **90 s** | 3 | ersetzt ein offenes Fenster (`superseded`); Verlassen schließt (`left`) |
| `boss` („**Boss-Countdown**“) | beim **ersten** Betreten des Quartier- bzw. Etagenboss-Raums | `countdown_sec` = **45 s** | 3 | ersetzt ein offenes Fenster; beginnt der Bosskampf vorher, bleibt der Rest eingefroren offen (s. u.) |
| `dev` | QA-Command `{"t": "sponsor_window", "op": "dev_open", "sec", "slots"}` (Debug-Overlay F5, Tests) | ≤ 600 s | ≤ 16 | nur mit `dev_open: true` (Kampagne/Offline); Live-Events müssen `false` setzen (EventDef prüft das), Server nehmen den Command nie von Clients an |

**Uhr (normativ, deterministisch):** Alles in Lauf-Ticks (`RunSim`, Kap. 3.2), Ganzzahlen, keine Uhrzeit. Ein offenes Fenster
zählt auf **jedem** Lauf-Tick herunter, der periodische Countdown nur auf **Erkundungs**-Ticks. Im Safe Room laufen
**Leerlauf-Ticks** (Lauf-Uhr ja, Etagen-Timer/Hype-Zerfall/Streuner nein), damit „höchstens 90 s“ in Ticks gilt und
Replay/Verifier es nachrechnen. **Im Kampf steht die Lauf-Uhr** (`explore_only`): Es öffnet und schließt kein Fenster, der
Countdown pausiert; ein **vor** dem Kampf geöffnetes Fenster bleibt mit seiner Restzeit offen — darin angenommene Geschenke
warten wie bisher bis zur nächsten Zuggrenze (max. 1 externes je Kampf, Kap. 6.10), weitere bis zum Kampfende. Ein
Etagenwechsel schließt (`floor`) und startet den Countdown neu. (`realtime`, S4: die Lauf-Uhr ist die Wanduhr, Fenster liefen
auch im Kampf — vor S4 festlegen, Kap. 12.2.)

**Plätze und Limits** (zusätzlich zu allen Caps aus Kap. 6.10):
- `slots_per_player` (3) Plätze je Fenster und Ziel, **wer zuerst kommt** — der Gift-Service reserviert bei der Quote
  (Kap. 6.4); in der Instanz halten angenommene, noch auf eine Zuggrenze wartende Geschenke ihren Platz.
- `per_viewer` (1) Geschenk je Zuschauer:in (`sender_ref`) und Fenster; unbekannter Absender (`""`, nur `dev`) ohne dieses Limit.
- `exempt_kinds` (`cheer`): kosmetisch, braucht kein Fenster, belegt keinen Platz. System-Geschenke (Hype-Schwellen, GDD 7.4)
  gehören zum Grundspiel und sind nie betroffen.
- Gnadenfrist `grace_sec` (15 s): Ein mit `sponsor_window` gestempeltes Geschenk (Reservierung bei der Quote) wird bis 15 s
  nach dem Fensterende noch angenommen — nur in die Plätze **seines** Fensters. Ungestempelte nur bei offenem Fenster.

**Ablehnung** (Instanz-Kern und Gift-Service mit derselben Regel; Kern-Grund → Protokollcode, Kap. 4.5):

| Lage | Grund (`Show.receive_gift`) | Code |
|---|---|---|
| kein Fenster offen (bzw. Stempel weder offen noch in der Gnadenfrist) | `window_closed` | `E_WINDOW_CLOSED` |
| alle Plätze belegt oder reserviert | `window_full` | `E_WINDOW_FULL` |
| diese:r Zuschauer:in hat in diesem Fenster schon geschenkt | `window_sender_limit` | `E_WINDOW_SENDER_LIMIT` |

Jede Ablehnung trägt `next_window_in_sec` (nächstes periodisches Fenster in Erkundungszeit; pausiert in Kampf und Safe Room,
deshalb als „ca.“ anzeigen). Shop, Extension und Overlay **zeigen**, wann das nächste Fenster öffnet — sie werben nicht damit.

**Server-Autorität (Kap. 3):** Der Fensterzustand gehört zum Lauf (`GameState.flags["live"]["sponsor"]`: `seq`, `next_in`,
`open`, `last` (Gnadenfrist), `rooms`, `exempt`; im `StateHash` und im Save) und wird nur vom Kern geschrieben. Die Instanz
(S3+) entscheidet; der Gift-Service fragt den Zustand an und reserviert; der Verifier rechnet Fenster aus Ticks und Commands
nach und meldet Geschenke außerhalb (`RunSim.replay` → `errors`, Kap. 3.7). Client-Sim (S0–S2): nur Gratis-Geschenke, Grenzen
von Grad A wie bisher.

**Ablauf im Kern** (Slice, Modul M8, CR-15): `SponsorWindows` (Regeln, Fahrplan, Prüfung, Buchung) · `RunSim` (Uhr = Schritt 5
jedes Ticks; Auslöser `floor`, Erstbesuch `room` einer Boss-Zelle, `safe_room`, `safe_room_exit`, `sponsor_window`) ·
`GiftPolicy.check` (Fenster **zuletzt**) · `GiftPolicy.note_applied` (Platz buchen bei Anwendung). `Game` ruft dieselben
`RunSim.sponsor_*()` aus seinen aufzeichnenden Methoden und sendet `Events.sponsor_window_opened(window)` /
`sponsor_window_closed(id, reason)` (Gründe `time`, `left`, `superseded`, `floor`); `Show.receive_gift` (einziger Eingang)
stempelt angenommene Geschenke mit `sponsor_window` und sendet beim Buchen `sponsor_window_updated(window)`.

**Darstellung:** TV-Badge am rechten Ende des Laufbands: in Event-/Live-Läufen mit Geschenken „**SPONSOR-FENSTER OFFEN · 0:45 ·
2/3 Plätze**“ (Gold-Plakette), „… VOLL …“, geschlossen „**Nächstes Fenster in 3:12**“; in der Kampagne dieselbe Information als
dezente Zeile ohne Plakette und ohne M.O.D.-Zeilen; Pur-Liga ohne Badge (es gibt dort keine Fenster). M.O.D.-Zeilen Kap. 6.12.
Ansicht: `docs/screenshots/overlay_sponsor_window.png` (`check.sh --shot res://scenes/ui/show_overlay.tscn`, Demo-Werte).

**Daten** (`events.json → rules.sponsor_windows`, Kap. 10.1; Ganzzahlen/Bools, fehlende Schlüssel = Standard, geht in `rules_hash`):

```json
"sponsor_windows": { "enabled": true, "slots_per_player": 3, "per_viewer": 1, "grace_sec": 15, "exempt_kinds": ["cheer"],
  "periodic": { "enabled": true, "first_sec": 300, "every_sec": 300, "open_sec": 60 },
  "safe_room": { "enabled": true, "max_sec": 90, "once_per_room": true },
  "boss": { "enabled": true, "countdown_sec": 45 }, "dev_open": false }
```

Fenster laufen nur, wenn der Lauf Zuschauer-Geschenke überhaupt annimmt (`enabled`, `rules.gifts.enabled`, nicht Pur-Liga);
die Offline-Events des Slice (Pur-Liga) haben deshalb keine, die Kampagne die Standardwerte (QA-Geschenke per Debug-Overlay).

**Spielerschutz (L13, L16):** Countdown + knappe Plätze können als künstliche Dringlichkeit wirken (CPC-Grundsätze, DSA
Art. 25 **[zu prüfen]**, R15). Deshalb: Restzeit und Plätze nur als Programminformation im Overlay; **im Kauf-Flow** weder
Countdown noch „nur noch X Plätze“ (der Platz ist dort schon reserviert); keine Push-/Chat-Hinweise „Fenster offen“; M.O.D.-Zeilen
ohne Kaufbezug; kostenlose Fan-Pakete nutzen dieselben Fenster (ein Fenster ist kein Kaufmoment); Limits/Selbstsperre unverändert.
Koop (S4): Plätze je Spieler:in (`slots_per_player`), Fenster je Team (eine Sendung) — bei S4 festlegen.

---

## 7. Beweisbar faire Würfel (Provably Fair)

### 7.1 Ziel & Bedrohungsmodell

*Begriffe:* „Provably Fair“, „Würfel“, „Wurf“ sind **interne** Fachbegriffe dieses Dokuments. Nutzerseitig heißt das Verfahren
„nachprüfbare Zufallsziehung“, ein Wurf „Ziehung“ (L12).

Nachweisbar machen, dass (a) die Wahrscheinlichkeiten und Regeln vor dem Event feststanden, (b) der Betreiber Ergebnisse
einzelner Kisten nach unserem Verfahren nicht nachträglich wählen kann **[durch externen Audit zu prüfen, Kap. 7.7]** — **sofern** der `server_seed` bis zum Reveal geheim
bleibt und die Zustellung vor dem Würfeln verbindlich ist (s. u.) — und (c) jeder Wurf aus öffentlichen Daten nachrechenbar ist.

**Bedrohungen und Gegenmaßnahmen:**

| Bedrohung | Gegenmaßnahme | Restrisiko (offen benennen, Kap. 7.7) |
|---|---|---|
| Betreiber sucht vor dem Event einen „günstigen“ Server-Seed | Commit ≥ 24 h vorher; Ergebnis hängt zusätzlich vom `client_seed` ab, den der Server vorher nicht kennt | — |
| **Selektive Nichtzustellung**: Server kennt das Ergebnis vor der Zustellung und erstattet unliebsame (z. B. epische) Würfe | Würfeln **erst nach** Zahlung **und** exklusiver Reservierung (Zustellung verbindlich, Kap. 6.4); `nonce` beim Quote vergeben und lückenlos; Gift-Log enthält **jede** Wurfberechnung mit Status (`delivered`, `refunded`, `substituted`); `verify_fair.py` meldet Nonce-Lücken und Erstattungsquoten je Rarität | verbleibende Fehlerpfade (Laufende, Ausfall) — sichtbar über Statistik |
| **Insider/Leck**: Wer `server_seed` vor dem Reveal kennt, kann bei frei wählbarem `client_seed` offline Seeds durchprobieren, bis „episch“ kommt | `server_seed` nur im HSM/KMS; Zugriff nur über Vier-Augen-Prinzip mit Audit-Log; Gift-Service erhält nur `roll_key`-Berechnungen über eine Schnittstelle, nie den Seed selbst; Rate-Limit + Anomalie-Erkennung (auffällige Epic-Quote je `sender_ref`) | nicht vollständig ausschließbar — offen benennen |
| Betreiber unterschlägt Käufe ganz | Belege an Käufer:innen, Abgleich im Log, externer Audit | — |
| Kanal ohne `client_seed` (früher: Bits — Kanal gestrichen 2026-10-08) | `client_seed` in jedem Kaufkanal Pflicht (Quote; Web-Shop, App-IAP) | ein neuer Kanal ohne `client_seed` ist **nicht** vollständig nachprüfbar (Kap. 7.7) |

### 7.2 Ablauf (Commit-Reveal)

| Zeitpunkt | Aktion | Öffentlich |
|---|---|---|
| ≥ 24 h vor `open` | Fairness-Service erzeugt `server_seed` (32 Byte CSPRNG) je Fenster im HSM/KMS **[Anbieter zu prüfen]**; Zugriff nur Vier-Augen + Audit-Log | Ankündigungsdatei mit `commit` (v2, Kap. 7.3), `event_id`, `window_id`, `gift_tables.json` + `tables_hash`, Regeln + `rules_hash`, `data_hash`, `sim_version` — zusätzlich **mit Zeitstempel archiviert** (öffentliches Git-Repo oder Transparenz-Log) |
| `open` | `layout_seed` je Fenster wird aus `server_seed` abgeleitet und ausgegeben (alle übrigen Seeds bleiben geheim, Kap. 3.3) | `layout_seed` |
| Quote | Käufer-Client schickt `client_seed` (**genau 16 Hex-Zeichen**, Standard: 8 Byte CSPRNG; in den Einstellungen änderbar, aber nur als Hex — kein Freitext); Server vergibt `nonce` (lückenlos) | — |
| Kauf + Reservierung | Wurf, Zustellung | Beleg an Käufer:in: `log_id`, `commit`, `client_seed`, `nonce`, `rolls`, `contents` |
| `closed` + Replays verifiziert (≤ 24 h) | `server_seed` veröffentlicht, Gift-Log (pseudonymisiert, **vollständig** inkl. erstatteter Würfe) veröffentlicht | `server_seed`, `gift_log.jsonl`, Liste `run_id → sym` |

### 7.3 Ableitungen (alle HMAC-SHA256, Schlüssel = `server_seed` als 32 Rohbytes, Nachricht UTF-8)

```text
tables_hash       = hex(SHA256(canonical_json(gift_tables)))        # JCS-Profil Kap. 3.3 Nr. 9, nur Ganzzahlen
rules_hash        = hex(SHA256(canonical_json(event.rules)))         # inkl. rules.gifts (Caps, effect_k_pm, chest_min_effect_pm) + pity-Parameter
commit            = hex(SHA256("PTD-COMMIT-v2|" + event_id + "|" + window_id + "|" + tables_hash + "|" + rules_hash
                               + "|" + data_hash + "|" + str(sim_version) + "|" + hex(server_seed)))
u48(bytes)        = Ganzzahl aus den ersten 6 Bytes, big-endian       # 0 … 2^48−1, passt verlustfrei in GDScript-int
layout_seed       = u48(HMAC(server_seed, "layout|" + event_id + "|" + window_id))   # ÖFFENTLICH ab open, nur für das Layout
sym(team)         = u48(HMAC(server_seed, "sym|" + team_id)) mod n_sym      # n_sym = 8 (quadratisch) bzw. 4
loot_key(window)  = HMAC(server_seed, "loot|" + event_id + "|" + window_id)       # GEHEIM; gleich für alle Teams des Fensters
loot_seed(p, i)   = u48(HMAC(loot_key, p + "|" + str(i)))     # p ∈ {"chest", "drop", "lootbox", "quest", "shop"}, i = Index
run_key(run)      = HMAC(server_seed, "runkey|" + run_id)                          # GEHEIM; je Lauf
run_stream(p, i)  = u48(HMAC(run_key, p + "|" + str(i)))      # p ∈ {"show", "battle", "event"} (Sponsor-Wahl, Kampf-Setup/CTB, Votes)
combat_key(run)   = HMAC(server_seed, "combat|" + run_id)
action_seed       = u48(HMAC(combat_key, str(battle_n) + "|" + str(action_n)))
roll_key(gift)    = HMAC(server_seed, "gift|" + event_id + "|" + window_id + "|" + sender_ref + "|" + client_seed + "|" + str(nonce))
draw(i, stage)    = u48(HMAC(roll_key, "draw|" + str(i) + "|" + stage))     # stage ∈ {"rarity", "item"}
```

**Seed-Klassen online** (Kap. 3.3 Nr. 2): Nur `layout_seed` ist öffentlich und speist ausschließlich den `DungeonGenerator`.
Truhen-Inhalte, Drops, Lootboxen, Quest-Spawns (`loot_seed`, für alle Teams eines Fensters gleich → vergleichbar),
Sponsor-Wahl, Kampf-Setup, Votes (`run_stream`) und Kampfaktionen (`action_seed`) kommen aus geheimen HMAC-Ableitungen; der
Server liefert Ergebnis bzw. Seed erst bei Auflösung. Spiel-Instanzen erhalten nur die abgeleiteten Schlüssel ihres Fensters
bzw. Laufs (`loot_key`, `run_key`, `combat_key`), **nie** `server_seed`; `roll_key` berechnet ausschließlich der
Fairness-Service. Offline (S0) gibt es keinen Server-Seed: `GameState.seed = seed_policy.run_seed`, alles über `SeedUtil`
(öffentlich), `action_seed = SeedUtil.derive(setup.seed, "action", action_n)`, `loot_seed = SeedUtil.derive(run_seed, "loot", floor)`
(CR-11). Hinweis: `SeedUtil` nutzt `String.hash()` und 31-Bit-Masken — innerhalb einer Godot-Version deterministisch, aber
nicht sprachübergreifend nachrechenbar und brute-force-bar; deshalb nutzt das öffentliche Prüfverfahren ausschließlich HMAC-SHA256.

### 7.4 Wurf-Algorithmus (portabel, ohne Godot-RNG)

Bewusst **nicht** Godots `RandomNumberGenerator`, damit das Prüfwerkzeug in Python/JavaScript bitgenau nachrechnen kann.

```text
pick(weights, u):  W = sum(weights); r = u mod W; laufende Summe c; erstes j mit r < c   # Bias ≤ W / 2^48, vernachlässigbar
RARITIES = ["common", "rare", "epic"]                       # feste Reihenfolge
roll_chest(roll_key, tier, rolls, guarantee, pity_forced):
  best = -1
  for i in 0 … rolls-1:
    u = draw(i, "rarity")
    if i == 0 and pity_forced != "":            r = index(pity_forced)
    elif i == rolls-1 and guarantee != "" and best < index(guarantee):
                                                r = pick(weights[tier] mit 0 für Raritäten < guarantee, u)
    else:                                       r = pick(weights[tier], u)
    best = max(best, r)
    item = pool[RARITIES[r]][ pick(pool-Gewichte in Array-Reihenfolge, draw(i, "item")) ]
    → contents[i] = { rarity, item_id|credits, qty }
```

**Wurfanzahl (normativ, Teil des Prüfverfahrens):** `rolls = max(1, (base_rolls * effect_pm + 500) // 1000)` mit
`effect_pm = 1000000 // (1000 + effect_k_pm * load_half)` (Kap. 6.10). Der Verifier rechnet `rolls` aus dem im Log
stehenden `load_half` nach.

**Testvektor** (geht als `tests/test_m8_fair_roll.gd` und als Selbsttest in `tools/verify_fair.py` ein; mit Python
`hmac`/`hashlib` nachgerechnet):

```text
server_seed = 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
event_id = "evt_2026w45_sat", window_id = "eu"
commit v2 (Test-Eingaben: tables_hash = "11"×32, rules_hash = "22"×32, data_hash = "33"×32, sim_version = 7)
         = 3613e6c5f82810dc73d6629a2864df33cdfdbd3e96f980122126bcfd821fd64a
(Regression, alte Formel v1 nur zum Abgleich: 740bcddc1c8043f2a50c7382b803889b94fdefad79af284cbcb27fe0c272111c)
layout_seed = 266222357384372
loot_seed("chest", 3) = 64833286715105
sym("t_01") = 2, sym("t_02") = 1
roll_key(sender_ref "b_7f3a9c", client_seed "c0ffee4200000017", nonce 17)   (Testvektor: kurzer Platzhalter; echte sender_ref = "b_" + 12 Hex, Kap. 7.5)
         = 25e3afcc14e3ccde26f918e41da45f508541add54dac4594c3718b0987c26992
draw(0, "rarity") = 255368109740746   (mod 100 = 46 → common bei Silber)
Silber-Kiste, 3 Würfe, Garantie rare, ohne Pity, Pool gift_f1:
  [common item_ice_spray, common 40 Credits, rare item_hype_megaphone]   (Garantie greift auf Wurf 3)
Silber-Kiste, L = 2 (load_half 4) → effect_pm 769 → 2 Würfe, Garantie greift auf Wurf 2 (eingeschränkte Gewichte [0, 38, 7]):
  [common item_ice_spray, rare item_brutzel_burger ×2]               (= Beispiel-Gift in Kap. 4.8)
Gold-Kiste, 4 Würfe, Garantie epic:
  [rare item_smoke, rare item_brutzel_burger ×2, epic acc_sneakers, epic 400 Credits]
Gold-Kiste, L = 4 (load_half 8) → effect_pm 625 → (4 × 625 + 500) // 1000 = 3 Würfe (Python round(2.5) = 2 wäre FALSCH):
  [rare item_smoke, rare item_brutzel_burger ×2, epic acc_sneakers]  (Garantie greift auf Wurf 3)
Bronze-Kiste, 2 Würfe:
  [common item_ice_spray, common 40 Credits]
```

### 7.5 Veröffentlichung & Datenschutz

- `gift_log.jsonl` je Fenster, **eine Zeile pro Wurfberechnung** (vollständig, auch erstattete/ersetzte): `log_id, status,
  status_reason, sender_ref, client_seed, nonce, tier, load_half, rolls, guarantee, pity_forced, table_id, contents`.
  `status` ∈ `delivered` \| `refunded` \| `substituted`. **Kein** Name, keine Konto-ID, **keine `gift_id`** (die ULID enthält
  einen Zeitstempel) und keine Zeitangaben; Zeilen sind nach `log_id` (Zufall) sortiert, nicht nach Zeit.
- `log_id` = `l_` + 16 Hex-Zeichen CSPRNG ohne Zeitbezug; die Zuordnung `gift_id ↔ log_id` bleibt intern (Ledger/Support).
- `client_seed` ist auf **genau 16 Hex-Zeichen** beschränkt (kein Freitext → keine Namen, Beleidigungen oder
  personenbezogenen Daten im öffentlichen Log).
- Der Live-Feed zeigt keine Inhalte und keine exakten Zeitpunkte, Absendernamen nur per Opt-in (Kap. 4.6) → Feed-Einträge
  und Log-Zeilen sind nicht direkt über ID oder Zeit verknüpfbar.
- `sender_ref = "b_" + hex(HMAC(pepper_event, account_id))[0:12]` — pro Event neu gepfeffert → Käufer:innen sind über
  Events hinweg **erschwert verknüpfbar** (nicht ausgeschlossen, z. B. über Kaufmuster); die eigene `sender_ref` steht im
  persönlichen Beleg. **[DSGVO-Bewertung der Pseudonymisierung zu prüfen; DSFA nach Art. 35 DSGVO zu prüfen, Kap. 9]**.
- Pity-Nachweis: Weil das Log je `sender_ref` nach `nonce` ordnbar ist, kann jede Person ihre eigene Pity-Kette nachrechnen.
  Die dauerhafte Pity-Kette über Events hinweg ist nur für die betroffene Person selbst prüfbar (eigene Belege).

### 7.6 Verifikations-Werkzeug

| Werkzeug | Ab | Funktion |
|---|---|---|
| `tools/verify_fair.py` | S3 | Python, nur Standardbibliothek. `verify_fair.py --commit <hex> --seed <hex> --event <id> --window <id> --tables gift_tables.json --log gift_log.jsonl --announce ankuendigung.json [--receipt mein_beleg.json]` → prüft Commit v2 (alle Felder: `tables_hash`, `rules_hash`, `data_hash`, `sim_version`), rechnet `effect_pm`/`rolls` aus `load_half` und jede Kiste nach, meldet **Nonce-Lücken** je `sender_ref` und **Erstattungsquoten je Rarität** (Auffälligkeit, wenn erstattete Würfe überdurchschnittlich oft episch sind), Exit-Code ≠ 0 bei Fehler; `--selftest` prüft den Testvektor |
| In-Game „Fairness prüfen“ | S3 | Menü im Live-Profil: lädt Commit/Seed/Log, nutzt `FairRoll` aus `core/` → zeigt je eigenem Beleg „bestätigt“ |
| Web-Prüfseite | S3 | JavaScript (WebCrypto HMAC-SHA256), gleicher Algorithmus, Beleg per Datei/Einfügen |
| Replay-Verifikation | S1 | Nach Reveal kann jede:r ein Live-Replay inkl. `action_seed`s gegen `combat_key` prüfen |

### 7.7 Grenzen (offen kommunizieren)

Provably Fair beweist die **Ableitung**, nicht die Angemessenheit der Odds, und schützt nicht vor einem Betreiber, der
Käufe unterschlägt. Offen zu benennen (Odds-Seite, FAQ):
- **Insider-/Leck-Risiko:** Wer den `server_seed` vor dem Reveal kennt (Insider, Leck), könnte mit frei gewähltem
  `client_seed` Ergebnisse offline vorausberechnen. Gegenmaßnahmen (HSM/KMS, Vier-Augen, Audit-Log, Anomalie-Erkennung)
  senken, aber beseitigen das Risiko nicht.
- **Selektionsrisiko über Fehlerpfade:** Nach dem Würfeln kann eine Zustellung noch scheitern (Laufende, Ausfall). Diese
  Fälle stehen mit Status im Log; Erstattungsquoten je Rarität sind öffentlich prüfbar.
- **Neue Kaufkanäle** (z. B. App-IAP, S5): Solange ein Kanal den `client_seed` nicht ab der Quote überträgt und im Beleg
  ausgibt, ist er **nicht vollständig** nachprüfbar und darf nicht als „nachprüfbar fair“ beworben werden (Kap. 9,
  Werbeaussagen). (Früher für Variante B formuliert — Bits-Geschenke sind seit 2026-10-08 gestrichen.)
Daher zusätzlich: Belege an Käufer:innen und **externer Audit** der Tabellen, der Implementierung **und der Fehlerpfade**
(Erstattung, Timeout, Reservierungs-Kollision, Instanz-Ausfall) vor S3 **[Anbieter/Format zu prüfen]**.

---

## 8. Monetarisierung & Zahlungsfluss

### 8.1 Überblick

**Grundsatz (Nutzerentscheidung 2026-10-08, L11):** Echtgeld von Zuschauer:innen fließt **ausschließlich an Spiel/Betreiber** —
nie an die Spielerin/den Spieler (Crawler), nie an Streamer:innen. Daraus folgt:

| | **C: Eigener Shop (Sponsor-Token / Direktkauf)** — **primär** | **B: Twitch** — **nur kostenlos** |
|---|---|---|
| Ab | S3 (Web-Shop), S5 (App-Store-IAP) | S2 (Votes), S3 (Anzeige Sponsor-Fenster) |
| Wer | Zuschauer:innen mit PTD-Account (Web, später App) | Twitch-Zuschauer:innen im Kanal einer streamenden Person |
| Was | bezahlte Geschenke (`gold`, `sponsor_buff`, `chest`) in Sponsor-Fenstern (Kap. 6.13) | Votes, Applaus (AP) + Fan-Pakete, Anzeige von Odds/Feed/Sponsor-Fenster — **keine Bits-Produkte** |
| Erlös an | **uns** (abzüglich MoR/PSP- bzw. Store-Gebühren, Steuern) | — (kein Echtgeld). *Bits-Erlöse gingen nach unserem Kenntnisstand an die Broadcaster:in* **[zu prüfen]** *— unvereinbar mit L11; deshalb ist das frühere Bits-Geschenkmodell gestrichen* |
| Vertragspartner:in der Käufer:in | wir bzw. MoR (Kap. 8.5); im App-Store der Store als Wiederverkäufer **[zu prüfen]** | — |
| Zufallskisten | ja, mit allen Leitplanken | — |
| Altersnachweis, Limits, Selbstsperre | im Account (Kap. 8.9) | — (kostenlose Interaktion; Jugendschutz/DSA/DSGVO wie S2) |
| Erstattung | durch uns + MoR/PSP bzw. Store (Kap. 8.6) | — |

Folgerung: **C ist das (einzige) Echtgeld-Modell**, B der Reichweiten- und Streamer-Motor **ohne Geld**. Ein Bits-Geschenk mit
Spielwirkung käme nur in Frage, wenn es ein Erlösmodell gibt, bei dem der Erlös an uns (Entwickler) geht und die
Broadcaster:in nichts erhält **[zu prüfen: Twitch-Monetarisierungsregeln für Extensions]** — dann als eigene Stufe mit neuer
Rechtsprüfung. Basis-Monetarisierung laut Brief (Premium-Kauf/Unlock) bleibt unverändert.

### 8.2 Sponsor-Token & Wallet

- 1 ST ≈ 0,01 € Kaufwert; nur in Paketen (Kap. 6.6); **nicht übertragbar**, **nicht auszahlbar**, **nicht in AP tauschbar**.
- Wallet-Obergrenze 5 000 ST (begrenzt gespeicherten Wert, AML/E-Geld-Risiko **[zu prüfen]**).
- **Verfall: keiner** (Leitplanke L15) — mindestens bis zur rechtlichen Klärung. Hintergrund: Die regelmäßige Verjährung
  beträgt in Deutschland 3 Jahre, kürzere Verfallsklauseln in AGB gelten bei Gutscheinen oft als unwirksam **[zu prüfen]**.
  Falls ein Verfall später zulässig und gewollt ist: frühestens nach 3 Jahren ab Kauf, mit Vorab-Hinweis.
- **Restguthaben bei Einstellung des Dienstes oder Kontolöschung wird erstattet** (Leitplanke L15, nicht nur AGB-Frage);
  Erstattung zum Kaufwert des jeweiligen Pakets (FIFO, Kap. 8.3) auf das ursprüngliche Zahlungsmittel bzw. per Überweisung;
  Ankündigung der Einstellung ≥ 90 Tage vorher, Verkaufsstopp ab Ankündigung. Ausgestaltung in den AGB **[zu prüfen]**.

### 8.3 Ledger (doppelte Buchführung)

**Grundsätze:** Append-only (keine Updates/Deletes), jede Transaktion (`tx_id`) ist **je Währung ausgeglichen**
(Σ Soll = Σ Haben), Korrekturen nur als Storno-Transaktion, Salden werden aus Buchungen abgeleitet (materialisierte
Sichten nur als Cache), Idempotenz-Schlüssel je externem Ereignis (PSP-Event-ID, Twitch-Transaktions-ID, `quote_id`),
eigene Postgres-Datenbank, Constraint-Prüfung in der Datenbank, tägliche Abstimmung gegen Anbieter-Berichte.

**Währungen:** `EUR` (Cent), `ST` (Token). (~~`BITS` als Memo~~ — gestrichen 2026-10-08, keine Bits-Geschenke.)
**Keine Konten und keine Transaktionsarten für Auszahlungen oder Beteiligungen an Personen** (L11): Erlöse landen nur auf
`revenue:*`; die früher geplanten `liability:creator_payable:*` / `creator_accrual` / `creator_payout` sind gestrichen (Kap. 8.8).

**Konten** (Schema `<klasse>:<name>[:<id>]`):

| Konto | Klasse | Bedeutung |
|---|---|---|
| `asset:psp_clearing:<psp>` | Aktiv | Forderung gegen PSP/MoR bis zur Auszahlung |
| `asset:bank` | Aktiv | Bankkonto |
| `liability:vat_payable:<land>` | Passiv | geschuldete USt (nur ohne MoR) |
| `liability:deferred_revenue:tokens` | Passiv | Gegenwert verkaufter, noch nicht verbrauchter Token |
| `revenue:gifts` | Ertrag | realisierter Umsatz bei Zustellung |
| `expense:psp_fees`, `expense:chargeback_loss`, `expense:chargeback_fee` | Aufwand | — |
| `user:<id>:wallet` | Token-Konto (ST) | Guthaben der Person |
| `escrow:gift:<gift_id>` | Token-Konto (ST) | reservierte Token bis Zustellung |
| `system:token_mint` / `system:token_burn` | Token-Gegenkonten | Ausgabe / Verbrauch |
| ~~`memo:bits:<channel>`~~ | — | gestrichen 2026-10-08 (keine Bits-Geschenke) |

**Beispiel-Buchungen** (Paket 1 000 ST für 9,99 € inkl. 19 % USt, ohne MoR — mit MoR entfällt die USt-Zeile, der
MoR rechnet netto ab **[Buchungslogik mit Steuerberatung festlegen]**):

| tx | Konto | Soll | Haben | Währung |
|---|---|---|---|---|
| `token_purchase` | `asset:psp_clearing:psp1` | 999 | | EUR |
| | `liability:vat_payable:DE` | | 160 | EUR |
| | `liability:deferred_revenue:tokens` | | 839 | EUR |
| | `system:token_mint` | 1 000 | | ST |
| | `user:u_123:wallet` | | 1 000 | ST |
| `gift_reserve` (Silber) | `user:u_123:wallet` | 300 | | ST |
| | `escrow:gift:g_01JB…` | | 300 | ST |
| `gift_deliver` | `escrow:gift:g_01JB…` | 300 | | ST |
| | `system:token_burn` | | 300 | ST |
| | `liability:deferred_revenue:tokens` | 252 | | EUR |
| | `revenue:gifts` | | 252 | EUR |
| `gift_release` (nicht zustellbar) | `escrow:gift:g_…` | 300 | | ST |
| | `user:u_123:wallet` | | 300 | ST |

Umsatzrealisierung je Token: `deferred_revenue_per_st` des **Kaufpakets** (FIFO über Pakete, Restcent-Ausgleich je Paket).
Ob USt beim Token-Kauf oder bei Einlösung entsteht (Einzweck-/Mehrzweck-Gutschein, EU-Gutscheinrichtlinie) **[zu prüfen]**.

### 8.4 Variante B: Twitch — nur kostenlose Interaktion

**Entscheidung 2026-10-08 (L11):** Über Twitch fließt **kein** Echtgeld in Geschenke. Die Twitch-Extension (EBS + Overlay/Panel)
bietet Votes (Kap. 6.2), Applaus/Fan-Pakete (Kap. 6.1, `source: "fan"`), Odds, Gift-Feed und die Anzeige des Sponsor-Fensters
(`spec_window`, Kap. 4.6). Auth über Twitch-Ext-Helper (JWT mit opaker Nutzer-ID, Kanal-ID) → EBS; Fan-Pakete gehen wie jedes
Geschenk durch Sponsor-Fenster und Caps. Ein Hinweis auf den eigenen Web-Shop nur, soweit die Twitch-Richtlinien das
erlauben **[zu prüfen]**, und nie als Kaufaufruf (L13).

**Gestrichen per Entscheidung 2026-10-08** (Kurzfassung des früheren Plans, nur als Historie): Bits-SKUs (`gift_bronze_100`,
`gift_silver_300`, `gift_gold_800`, `gift_credits_50`, `gift_buff_150`) über `useBits`, Transaktionsbeleg → EBS → Ledger-Memo →
Gift-Service; Zufallskisten an die Broadcaster:in gesperrt; Ersatzleistung (Cheer + Fan-Kosmetik) für nicht zustellbare
Bits-Geschenke. Grund: Bits-Erlöse gehen nach unserem Kenntnisstand an die Broadcaster:in **[zu prüfen]** — bei Streamer-Läufen
oft die beschenkte Person selbst — und widersprechen damit „Echtgeld nur an den Betreiber“.

**Offen [zu prüfen]:** Gibt es ein Erlösmodell für Extension-Entwickler (Bits-Anteil o. Ä.), bei dem der Erlös **nicht** an die
Broadcaster:in geht? Nur dann wäre eine Bits-Variante überhaupt denkbar — als eigene Stufe mit Rechtsprüfung, allen
Leitplanken (inkl. `client_seed`, Limits in Bits, Altersnachweis über das verknüpfte PTD-Konto) und Sponsor-Fenstern.

### 8.5 Variante C: Eigener Shop (primär; S3 Web, S5 App)

**Web (S3):** Konto → Altersnachweis (18+, für alle Echtgeld-Geschenke) → Limits aktiv → Paketkauf bzw. Direktkauf einer Kiste über **Merchant of Record** (übernimmt USt/Verkaufssteuer
weltweit, Rechnungen, viele Zahlarten, Chargebacks) — Kandidaten z. B. Paddle, Xsolla, FastSpring **[Eignung für virtuelle
Währung/Zufallsinhalte und Geo-Sperren zu prüfen; manche MoR schließen Glücksspiel-nahe Produkte aus]**; Alternative PSP
(Stripe/Adyen) + eigene Steuerabwicklung (EU-OSS) **[zu prüfen]**. Gutschrift **nur** per signiertem Webhook (Signaturprüfung,
Idempotenz über Event-ID), nie per Client-Rückkehr-URL.

**Mobile (S5, zweiter Kanal von C):** Digitale Güter in Apps → In-App-Kauf über App Store / Google Play **[Store-Regeln für
Geschenke an andere Nutzer:innen und Odds-Offenlegung zu prüfen]**. Erlös an uns (abzüglich Store-Provision); keine
Weitergabe an Spieler:innen/Streamer:innen (L11). Belegprüfung **nur serverseitig**:
- Apple: signierte Transaktion (JWS) prüfen (Zertifikatskette), Abgleich über App Store Server API, Erstattungen über
  App Store Server Notifications (V2) → Storno-Buchung **[aktuelle API-Versionen zu prüfen]**.
- Google: Kauf-Token per Play Developer API prüfen, Consumable **konsumieren**, Real-time Developer Notifications (Pub/Sub)
  und Voided-Purchases-Abfrage für Erstattungen **[zu prüfen]**.
- Idempotenz über `transactionId` bzw. `orderId`; Gutschrift erst nach erfolgreicher Prüfung.
Bis zur schriftlichen Klärung der Store-Regeln: Mobile-Apps **ohne** Kaufoberfläche für Geschenke (nur Zuschauen/Votes);
Hinweise auf externe Käufe nur im Rahmen der jeweils gültigen Store-Regeln **[zu prüfen]**. Danach ist IAP der mobile Teil des
primären Echtgeld-Wegs (Exit-Kriterium S5).

### 8.6 Erstattungen & Chargebacks

| Fall | Behandlung |
|---|---|
| Geschenk nicht zustellbar / abgelehnt (auch: Sponsor-Fenster samt Gnadenfrist vorbei, bevor die Zahlung bestätigt war) | automatische Rückbuchung Escrow → Wallet bzw. Erstattung über PSP/Store. (Ersatzregel für Bits — gestrichen mit Kap. 8.4) |
| Widerruf Token-Paket (EU), Token **unverbraucht** | Erstattung möglich, solange nicht durch ausdrückliche Zustimmung zum sofortigen Beginn erloschen **[Rechtslage zu prüfen]**; Token-Storno + EUR-Storno |
| Erstattung/Chargeback, Token **teilweise verbraucht** | unverbrauchte Token stornieren; verbrauchter Anteil → `expense:chargeback_loss`; Wallet darf negativ werden; Konto: **Kaufsperre** bis Ausgleich; Wiederholung → Sperre/Ban |
| Kiste **bereits geöffnet** | Inhalte sind lauf-gebunden und meist schon verbraucht/verfallen → **keine Rücknahme beim beschenkten Spieler** (unbeteiligte Dritte, laufende Sendung). Läuft der Lauf noch und ist die Kiste **noch nicht zugestellt**: Zustellung stornieren. |
| Bestenliste nach Chargeback | Show-Liga-Eintrag bleibt (Geschenke sind Teil der Show). **Ausnahme Betrug** (z. B. gestohlene Karte, Absprache zur Rang-Manipulation): Eintrag annulliert, Konten gesperrt, Fall dokumentiert. |
| Mobile-Erstattung (Apple/Google) | per Server-Notification → wie Chargeback |

### 8.7 Steuern (Planungshinweise, alles **[zu prüfen mit Steuerberatung]**)

- Digitale Leistungen an Verbraucher:innen in der EU: USt am Ort der Kundschaft, Abwicklung über OSS — entfällt für uns
  weitgehend mit MoR.
- Token: Einordnung als Einzweck- oder Mehrzweck-Gutschein bestimmt den USt-Zeitpunkt.
- USA: Verkaufssteuer je Bundesstaat (Nexus) — MoR empfohlen.
- ~~Bits-Erlöse an Broadcaster~~ — entfällt (keine Bits-Geschenke, Kap. 8.4).
- ~~Creator-Beteiligungen → DAC7, US-Steuerformulare~~ — entfällt (gestrichen, Kap. 8.8): Wir zahlen nichts an Personen aus;
  ob uns DAC7 dann überhaupt betrifft, kurz bestätigen lassen **[zu prüfen]**.
- App-Store-IAP (S5): Stores agieren je nach Land als Verkäufer/Kommissionär — USt-Behandlung je Store **[zu prüfen]**.

### 8.8 ~~Creator-Beteiligung~~ — gestrichen per Entscheidung 2026-10-08

Geplant war (nach S5, nur nach Gutachten): X % des C-Umsatzes aus nicht-zufälligen Geschenken an Streamer:innen, über lizenzierte
Auszahlungsdienstleister mit KYC, gedeckelt und überwacht (Ledger `liability:creator_payable`, `creator_accrual`,
`creator_payout`). **Gestrichen**, weil Echtgeld von Zuschauer:innen nach der Nutzerentscheidung 2026-10-08 nie an Spieler:innen
oder Streamer:innen fließt (L11). Damit entfallen auch die Fragen nach Finanztransfer/ZAG, KYC, Auszahlungsdeckeln und
Kollusion über Strohleute (Kap. 9). Streamer:innen bleiben Reichweiten-Partner:innen ohne Erlösbeteiligung an Geschenken
(Keys, Presskit, Streamer-Modus — 04 Kap. 7.2).

### 8.9 Spielerschutz: Alter, Limits, Geo

| Maßnahme | Regel |
|---|---|
| Alter Käufer:innen | **18+ für alle Echtgeld-Geschenke** (zufällig und nicht-zufällig, alle Kanäle), bis ein Gutachten anderes erlaubt; eine niedrigere Grenze (z. B. 16+ für nicht-zufällige Geschenke) ist nur eine **[zu prüfende]** Option (Kap. 9). Nachweis über Altersverifikations-Dienst oder MoR/PSP-Verfahren **[Anbieter zu prüfen]**; gespeichert wird nur das Ergebnis „18+ verifiziert“ |
| Alter Empfänger:innen | bezahlte Zufallskisten nur an altersverifizierte Spieler:innen ab 18; alle anderen fest `free_only` (Kap. 6.11) |
| Bindung an die Person | Limits, Selbstsperre und Abkühlung hängen an der **altersverifizierten Identität** (Verifikations-Referenz), nicht am einzelnen Konto → gelten **konto-übergreifend** (Mehrfachkonten) |
| Ausgabelimits (ab S3) | **EUR**, ein Budget für alle Kanäle von C (Web-Shop, App-IAP): Standard 20 €/Tag, 100 €/Monat **[Werte zu prüfen]**. Anzeige „heute/Monat ausgegeben“ (je Kanal + gesamt) im Bestätigungsdialog. **Kein Kisten-Kauf ohne aktive Limits.** Senken sofort; Erhöhen nur nach 7 Tagen Wartezeit, erneuter Bestätigung und Hinweis auf Hilfsangebote (Beratungsstellen **[zu prüfen]**), Obergrenze 250 €/Monat **[zu prüfen]**. (Bits-Limits — gestrichen mit Kap. 8.4.) |
| Selbstsperre | 24 h / 7 Tage / 30 Tage / dauerhaft, sofort wirksam, Aufhebung erst nach Ablauf; gilt für alle Kanäle und Konten der Person |
| Kauf-Abkühlung | Nach 3 Kisten-Käufen in 10 min: Hinweis + 5 min Wartezeit; nach 6 Kisten-Käufen am Tag: 1 h Wartezeit **[Werte zu prüfen]** |
| Sitzungs-Hinweise | Regelmäßig (z. B. alle 30 min bzw. nach jedem 3. Kauf) neutraler Hinweis „Sie haben in dieser Sitzung X ausgegeben“ (EUR) mit Link auf Limits/Selbstsperre |
| Sponsor-Fenster (L16) | Hilfe nur in Fenstern mit wenigen Plätzen (Kap. 6.13) — begrenzt zusätzlich die Zahl möglicher Käufe je Lauf; **ohne** Dringlichkeitsdarstellung im Kauf-Flow |
| Transparenz | Kaufhistorie mit allen Inhalten, Pity-Stand auf Abruf, Export (DSGVO) — ab S3 im Spielerschutz-Center |
| Geo-Policy | **Positivliste (Standard: verboten)** für `chests_buy`/`chests_receive`: Tabelle `geo_policy` im Backend: Land → `{ chests_buy, chests_receive, gifts_buy, shop, opinion_ref }`. Zufallskisten nur in Ländern mit **positivem schriftlichem Gutachten** (`opinion_ref` Pflicht); die Länder des S3-Gutachtens sind genau die freigeschalteten. **Ausdrücklich gesperrt:** Belgien, Niederlande **[zu prüfen]**. Ermittlung: Rechnungsland (Web), Store-Land (App), IP-Geolokalisierung (alle), Land des PTD-Kontos — bei Widerspruch oder VPN-/Proxy-Verdacht gilt die **strengste** Regel; **Land nicht feststellbar = gesperrt**. Nicht-zufällige Geschenke (`gifts_buy`) separat bewerten |
| Kein Selbstgeschenk | Konto, Zahlungsmittel-Fingerprint, Geräte-ID dürfen nicht mit Ziel übereinstimmen; Teammitglieder dürfen eigenem Team nichts Zufälliges schenken. Fingerprinting nur mit geprüfter Rechtsgrundlage, nur **gehashte** Merkmale, begrenzte Speicherdauer, Information in der Datenschutzerklärung (Kap. 9) |

---

## 9. Rechts- & Compliance-Checkliste

Alle Einträge: **Status „zu prüfen“** bis eine schriftliche Prüfung vorliegt. Die Spalte „Risiko“ beschreibt unsere
Einschätzung der Fragestellung, **keine** Rechtsauskunft.
**Vereinfachung durch die Entscheidung 2026-10-08 (L11):** Es fließt kein Echtgeld an Personen (keine Auszahlung, keine
Creator-Beteiligung, keine Bits-Geschenke) — die Zeilen zu Erlösfluss an Empfänger:innen, Bits, Ersatzleistung, Auszahlung/KYC
und ZAG-Finanztransfer schrumpfen auf die verbleibende Frage oder entfallen (unten markiert).

| Thema | Risiko | Maßnahme (geplant) | Status |
|---|---|---|---|
| Lootboxen **Belgien** | Bezahlte Zufallsinhalte werden dort nach unserem Kenntnisstand als Glücksspiel eingestuft (Gaming Commission, 2018) **[zu prüfen]** | **Sperrliste**: Kauf **und** Empfang von Zufallskisten gesperrt; nicht-zufällige Geschenke separat bewerten | zu prüfen |
| Lootboxen **Niederlande** | Rechtsprechung/Regulierung nach unserem Kenntnisstand im Wandel (Kansspelautoriteit; Urteil Raad van State 2022; Verbotsdebatte) **[zu prüfen]** | **Sperrliste** (Kauf und Empfang), Aufhebung nur nach positivem Länder-Gutachten | zu prüfen |
| **Geo-Policy allgemein** | Twitch-Zuschauer:innen kommen weltweit; Einzelverbote (Negativliste) wären zu riskant | **Positivliste** (Kap. 8.9): Kisten nur in Ländern mit positivem schriftlichem Gutachten; Gutachten-Länder = freigeschaltete Länder; Land nicht feststellbar = gesperrt; VPN/Widerspruch → strengste Regel | zu prüfen |
| **Besonderheit Fremd-Kauf** | Käufer:in erhält selbst nichts; Kiste nützt Dritten → Einordnung als Glücksspiel/Lotterie/Gewinnspiel könnte anders ausfallen als bei klassischen Lootboxen | explizite Frage im Gutachten; seit 2026-10-08 ohne Erlösfluss an die Empfänger:in (L11), das stützt das Argument „kein Gewinn/kein Vermögenswert“ | zu prüfen |
| ~~Erlösfluss an Empfänger:in (Bits/Creator-Anteil)~~ | **Entschieden 2026-10-08 (L11):** Echtgeld fließt nur an den Betreiber — keine Bits-Geschenke (Bits-Erlöse gingen nach Kenntnisstand an die Broadcaster:in **[zu prüfen]**), keine Creator-Beteiligung. Die frühere Blocker-Frage „Erlösfluss an die Empfänger:in“ entfällt | Restfrage nur, falls je eine Bits-Variante kommen soll: Gibt es ein Erlösmodell für Entwickler ohne Anteil der Broadcaster:in **[zu prüfen]**? | entschieden (Restfrage zu prüfen) |
| **Deutschland** Glücksspielrecht (GlüStV 2021) | Glücksspiel setzt u. a. Entgelt + Zufall + Gewinn (Vermögenswert) voraus **[zu prüfen]**; Argument „kein Vermögenswert“ durch Lauf-Bindung/keine Auszahlung. Euro-Werte für Inhalte oder dauerhafte Belohnungen aus bezahlten Inhalten würden das Argument schwächen | Gutachten; Lauf-Bindung, kein Handel, keine Auszahlung strikt umsetzen; **keine Euro-Bewertung von Inhalten** (L1); gesponserte Läufe nur Teilnahme-Plakette (Kap. 1.6) | zu prüfen |
| **Deutschland** Jugendschutz (JuSchG seit 2021, USK) | Kaufmöglichkeiten/Zufallsmechaniken und Interaktionsrisiken (§ 10b JuSchG **[zu prüfen]**) können Alterskennzeichen und Deskriptoren beeinflussen; IARC-Fragebogen für Stores; glücksspielnahe Darstellung (Live-Öffnung, Casino-Vokabular) kann die Einstufung negativ beeinflussen | USK-/IARC-Angaben korrekt; Altersgrenze Käufer 18+; Präsentationsregeln L12 | zu prüfen |
| **Zuschauerschaft mit Minderjährigen / Kaufappelle** | Twitch erlaubt nach unserem Kenntnisstand Nutzer:innen ab 13 **[zu prüfen]**; Kaufangebote für Zufallsinhalte und Kaufaufrufe (Streamer:in, M.O.D.) erreichen Kinder → Risiko direkter Kaufaufforderung an Kinder (UWG Anhang Nr. 28 **[zu prüfen]**), JuSchG-Interaktionsrisiken | Kaufknöpfe nur für altersverifizierte 18+-Konten (Kap. 5.4); keine Kaufaufrufe in UI/M.O.D.; Creator-Richtlinien/AGB (keine Kaufaufrufe, Kennzeichnung, Twitch-Glücksspielrichtlinie **[zu prüfen]**) | zu prüfen |
| **Alter Empfänger:innen / Geschäftsfähigkeit** | Minderjährige sind beschränkt geschäftsfähig (§§ 106 ff. BGB, Taschengeldparagraf § 110 **[zu prüfen]**); USA: COPPA (< 13) **[zu prüfen]**; länderspezifisch | Bis zum Gutachten: **18+ für alle Echtgeld-Geschenke** (Käufer:innen) und für den Empfang bezahlter Zufallskisten. **Option [zu prüfen]:** 16+ für nicht-zufällige Geschenke mit/ohne Elterneinwilligung, je Land | zu prüfen |
| **Vereinigtes Königreich** | Lootboxen ohne Auszahlung nach unserem Kenntnisstand bisher nicht als Glücksspiel reguliert **[zu prüfen]**; Branchen-Selbstverpflichtungen (u. a. Odds, Kaufbeschränkung Minderjährige) **[Stand zu prüfen]** | Selbstverpflichtungen erfüllen (Odds, Altersgrenze, Ausgabekontrollen); Freischaltung nur nach Gutachten (Positivliste) | zu prüfen |
| **USA** (Bund/Bundesstaaten) | Einzelstaatliche Gesetzesinitiativen; FTC-Verfahren zu Lootboxen/Dark Patterns bei Minderjährigen; COPPA (< 13) **[jeweils zu prüfen]** | keine Käufe < 18, keine Datenerhebung < 13 ohne Einwilligung; **Preis der Kiste in Echtgeld, Inhalte ohne Geldwert** (L1) | zu prüfen |
| Weitere Länder (z. B. Australien-Klassifizierung, Südkorea-Odds-Pflicht, China) | Altersfreigaben/Offenlegungspflichten für bezahlte Zufallsinhalte **[zu prüfen]** | **gesperrt**, solange kein positives Gutachten vorliegt (Positivliste) | zu prüfen |
| **App-Store-IAP (Teil des primären Wegs C, S5)** | Apple/Google verlangen nach unserem Kenntnisstand Offenlegung von Wahrscheinlichkeiten vor Kauf bei Lootbox-artigen Käufen **[zu prüfen]**; Regeln für **Geschenke an andere Nutzer:innen** und für Hinweise auf externe Käufe **[zu prüfen]** | Odds-Anzeige (Kap. 6.7) in allen Clients; bis zur schriftlichen Klärung kein Mobile-Kauf (Exit S5) | zu prüfen |
| **Twitch-Extension** (nur kostenlos) | Extension-Review für Votes/Applaus/Anzeigen; Glücksspiel-ähnliche Stream-Inhalte (Kisten werden live geöffnet, auch ohne Bits); Hinweise auf externe Käufe (eigener Shop) **[zu prüfen]** | schriftliche Klärung mit Twitch; ohne Freigabe kein Shop-Hinweis in der Extension. (Bits für Zufallsinhalte — entfällt, Kap. 8.4) | zu prüfen |
| ~~Vertragspartner & Ersatzregel bei Bits~~ | **entfällt** (keine Bits-Geschenke seit 2026-10-08) | — | entfällt |
| **Altersverifikation** | Selbstauskunft reicht ggf. nicht; Verfahren muss datensparsam sein | Dienstleister/MoR-Verfahren, nur Ergebnis „18+“ speichern | zu prüfen |
| **Ausgabelimits / Spielerschutz** | Erwartung von Behörden/Selbstverpflichtungen; Reputationsrisiko; Umgehung über Mehrfachkonten | Limits (EUR, alle Kanäle von C), Selbstsperre, Historie, Sitzungs-Hinweise, an die verifizierte Identität gebunden, ab S3 (Kap. 8.9) | zu prüfen |
| **Kaufprozess / Pflichtinformationen** | Button-Lösung („zahlungspflichtig bestellen“, § 312j BGB **[zu prüfen]**), vorvertragliche Pflichtinformationen, Bestätigung auf dauerhaftem Datenträger, Einordnung als Vertrag zugunsten Dritter (Beschenkte:r) **[zu prüfen]**, Widerruf auch für die **Kisten-Bestellung** selbst (nicht nur Token-Pakete), Preistransparenz bei verminderter Wirkung | Bestellfluss Kap. 6.4 (Button-Text, Zustimmung zum sofortigen Beginn, Bestätigungs-Mail, Wurfzahl-Bestätigung); 100-ST-Paket und Euro-Direktkauf ohne Token-Vorabkauf (Kap. 6.6) | zu prüfen |
| **EU-Verbraucherrecht: Widerruf digitale Inhalte** | Widerrufsrecht erlischt nach unserem Kenntnisstand nur bei ausdrücklicher Zustimmung + Bestätigung der Kenntnis (Verbraucherrechte-RL; Rechtsstand seit 2022 **[zu prüfen]**) | Checkbox im Kauf, Bestätigungs-Mail, Widerruf unverbrauchter Token | zu prüfen |
| **EU: virtuelle Währungen in Spielen** | Behördliche Grundsätze (CPC-Netzwerk, nach unserem Kenntnisstand 2024 **[Stand und Inhalt zu prüfen]**) u. a. Preisangabe in Echtgeld, keine verschleiernden Paketgrößen, kein erzwungener Vorab-Kauf | Echtgeld-Anzeige des Kistenpreises, Pakete ohne Bonus, 100-ST-Paket, Direktkauf | zu prüfen |
| **Dark Patterns / Kaufdruck** | Pity-Countdown, Monats-Reset, preisabhängiges Lob, Beschämung günstiger Geschenke, Namensnennung im öffentlichen Feed — Risiken nach CPC-Grundsätzen und DSA Art. 25 **[zu prüfen]**, besonders bei minderjährigem Publikum | L2, L12, L13: Pity nur auf Abruf, kein Zeit-Reset, neutrale M.O.D.-Zeilen, `anon: true` als Standard, Feed ohne Inhalte | zu prüfen |
| **Dringlichkeit durch Sponsor-Fenster** (neu 2026-10-08) | Zeitlich begrenzte Fenster mit knappen Plätzen (Countdown „0:45 · 2/3 Plätze“) können als künstliche Verknappung/Dringlichkeit gelten (CPC-Grundsätze, UWG, DSA Art. 25 **[zu prüfen]**), zumal vor minderjährigem Publikum | L16 / Kap. 6.13: Countdown und Plätze nur als Programminformation im Overlay; im Kauf-Flow kein Countdown, keine „nur noch X“-Hinweise (Platz bei der Quote reserviert); keine Push-/Chat-Aufrufe; Fan-Pakete (kostenlos) nutzen dieselben Fenster; Limits/Selbstsperre unverändert | zu prüfen |
| **Werbeaussagen zu Fairness/Odds (UWG)** | Werbung mit „beweisbar fair“ wäre irreführend, wenn ein Kanal (z. B. ein neuer Kanal ohne `client_seed`) die Eigenschaft nicht erfüllt (UWG § 5 **[zu prüfen]**) | Aussagen nur für tatsächlich erfüllte Kanäle; Grenzen offen benennen (Kap. 7.7); neutrale Begriffe (L12) | zu prüfen |
| **DSA / Moderation** | Nutzernamen, Gift-Absendernamen, Chat/Cheers; Melde- und Abhilfeverfahren, Begründungen, Minderjährigenschutz | **kein Freitext** in Geschenken (auch `client_seed` nur Hex), Namensfilter + Melden + Sperren, Transparenzangaben je Plattformgröße | zu prüfen |
| **DSGVO** — Accounts | Rechtsgrundlagen, Speicherfristen, Auftragsverarbeitung (Hosting, MoR, Altersverifikation), Drittlandtransfer | Verarbeitungsverzeichnis, AVVs, Löschkonzept, Datenschutzerklärung | zu prüfen |
| **DSGVO** — Zuschauer-Daten | Zuschauerzahlen, Votes, Twitch-IDs (opak), IP für Geo-Sperre; Zuschauer:innen auch minderjährig | Datensparsamkeit: Votes nur aggregiert speichern, IP nur flüchtig, pseudonyme Logs (Kap. 7.5) | zu prüfen |
| **DSGVO — Datenschutz-Folgenabschätzung** | Öffentliche Gift-Logs, Pseudonymisierung (`sender_ref`, „erschwert verknüpfbar“), Altersverifikation, Fingerprinting, Profilbildung über Kaufverhalten (Spielerschutz) | DSFA nach Art. 35 DSGVO **[Erforderlichkeit zu prüfen]** vor S3 | zu prüfen |
| **Betrugs-/Verknüpfungsprüfung (Fingerprinting)** | Selbstgeschenk-Prüfung per Geräte-ID und Zahlungsmittel-Fingerprint (L9) braucht eine Rechtsgrundlage: Endgerätezugriff nach § 25 TDDDG, Art. 6 DSGVO **[zu prüfen]** | Rechtsgrundlage festlegen, nur gehashte Merkmale, kurze Speicherdauer, Information in der Datenschutzerklärung, ggf. DSFA | zu prüfen |
| **Geldwäsche / Zahlungsdiensteaufsicht / E-Geld** | Gespeicherter Wert (ST-Wallet), Geschenke zwischen Personen. **Deutlich einfacher seit 2026-10-08:** keine Auszahlungen an Personen, keine Creator-Beteiligung, keine Weiterleitung von Geldern an Dritte (L11) | **Verbleibende Gutachtenfragen [zu prüfen]:** (1) Fällt die ST-Wallet unter die E-Geld-Ausnahme „begrenztes Netz“? (2) Welche Struktur mit MoR vermeidet eigene Erlaubnispflichten? (3) GwG-Pflichten (Verpflichteteneigenschaft, Verdachtsmeldung)? ~~(Creator-Beteiligung als Finanztransfergeschäft/ZAG, KYC für Auszahlungen)~~ — **entfällt**. Maßnahmen: keine Auszahlung, kein Handel, keine P2P-Token-Übertragung, Wallet-Obergrenze, Erstattung nur auf das ursprüngliche Zahlungsmittel | zu prüfen |
| **Gewinnspiele / Preise** | Echtgeld- oder Sachpreise bei Bestenlisten können Gewinnspiel-/Lotterierecht berühren | Belohnungen nur kosmetisch (Kap. 1.6); Sachpreise nur nach Prüfung | zu prüfen |
| **Werbung / Kennzeichnung** | Fiktive Satire-Sponsoren: voraussichtlich geringes Risiko, Marken-/Parodieprüfung (Ähnlichkeit zu realen Marken) **[zu prüfen]**; echte Kooperationen kennzeichnungspflichtig | echte Sponsoren nie als In-Game-Satire-Marke, Kennzeichnung | zu prüfen |
| **AGB / Nutzungsbedingungen** | Token-Bedingungen, Lauf-Bindung, Sperren, Einstellung des Dienstes | AGB-Entwurf mit Anwalt | zu prüfen |
| **Steuern** | USt/OSS, US-Sales-Tax, Gutschein-Einordnung, App-Store-USt; ~~DAC7 für Creator-Auszahlungen~~ (entfällt, keine Auszahlungen) | MoR, Steuerberatung (Kap. 8.7) | zu prüfen |

---

## 10. Datenmodelle

### 10.1 `res://data/events.json` (S0 lokal; ab S1 vom Server, gleiches Schema)

```json
{
  "schema": 1,
  "events": [
    {
      "id": "evt_offline_gleis9",
      "kind": "offline",
      "name_key": "evt_offline_gleis9_name",
      "floor": 1,
      "windows": [],
      "seed_policy": { "type": "fixed", "run_seed": 424242 },
      "quest": {
        "type": "all_of", "label_key": "quest_gleis9_clearance",
        "params": { "quests": [
          { "type": "defeat_boss", "params": { "boss_id": "enm_boss_rattenkoenigin" } },
          { "type": "achievement_hunt", "params": { "ids": ["ach_overkill", "ach_combo_first", "ach_close_call"], "min": 2 } }
        ] }
      },
      "rules": {
        "mode": "solo",
        "leagues": ["pur"],
        "timer_mode": "explore_only",
        "floor_timer_sec": 1200,
        "max_run_wall_sec": 0,
        "party_preset": "preset_f1_l1",
        "difficulty": "prime_time",
        "attempts": { "ranked": 0, "practice": true },
        "gifts": { "enabled": false }
      },
      "votes": { "enabled": false },
      "scoring": { "complete": 10000, "progress_max": 5000, "per_sec_left": 5, "per_follower": 1, "follower_cap": 3000, "per_achievement": 100, "per_ko": -150 },
      "rewards": { "participation": "badge_gleis9", "quest": "cos_mop_top_hat_gleis9" }
    },
    {
      "id": "evt_2026w45_sat",
      "kind": "live_show",
      "name_key": "evt_saturday_show_name",
      "floor": 1,
      "windows": [
        { "id": "eu",   "open_at": "2026-11-07T19:00:00Z", "close_at": "2026-11-07T20:30:00Z", "region": "eu" },
        { "id": "am",   "open_at": "2026-11-08T01:00:00Z", "close_at": "2026-11-08T02:30:00Z", "region": "us_east" },
        { "id": "apac", "open_at": "2026-11-08T10:00:00Z", "close_at": "2026-11-08T11:30:00Z", "region": "ap_tokyo" }
      ],
      "late_entry": "until_last_entry",
      "seed_policy": { "type": "commit_reveal", "commit_version": 2, "commits": { "eu": "3613e6c5…d64a", "am": "…", "apac": "…" }, "tables_hash": "5e2d…07", "rules_hash": "9c41…e2" },
      "quest": { "type": "reach_stairs", "label_key": "quest_reach_stairs", "params": { "floor": 1 } },
      "rules": {
        "mode": "coop", "team_size": [1, 4],
        "leagues": ["show", "pur"],
        "timer_mode": "realtime",
        "floor_timer_sec": 2100,
        "turn_timeout_sec": 20,
        "coop_join_radius_m": 15,
        "max_run_wall_sec": 2700,
        "party_preset": "preset_f1_l3",
        "attempts": { "ranked": 1, "practice": false },
        "spectate": { "delay_sec": 30 },
        "gifts": {
          "enabled": true,
          "sources": ["fan", "shop"],
          "load_cap_half": 48, "max_external": 16, "max_chests": 8, "max_gold_chests": 2,
          "min_interval_sec": 45, "sale_close_buffer_sec": 120, "max_per_battle": 1, "per_buyer_per_target": 5,
          "load_weights_half": { "cheer": 0, "gold_per_100": 1, "fan_pack": 2, "sponsor_buff": 2, "bronze": 2, "silver": 4, "gold": 8 },
          "effect_k_pm": 75,
          "chest_min_effect_pm": 500,
          "ask_timeout_sec": 10,
          "table_id": "gift_f1"
        },
        "sponsor_windows": {
          "enabled": true, "slots_per_player": 3, "per_viewer": 1, "grace_sec": 15, "exempt_kinds": ["cheer"],
          "periodic": { "enabled": true, "first_sec": 300, "every_sec": 300, "open_sec": 60 },
          "safe_room": { "enabled": true, "max_sec": 90, "once_per_room": true },
          "boss": { "enabled": true, "countdown_sec": 45 },
          "dev_open": false
        }
      },
      "votes": { "enabled": true, "interval_sec": 240, "duration_sec": 45, "options": 3,
                 "pool": ["tw_lights_out", "tw_double_trouble", "tw_rat_rain", "tw_sponsor_rush", "tw_mopsula_monologue", "tw_costume"] },
      "scoring": { "complete": 10000, "progress_max": 5000, "per_sec_left": 5, "per_follower": 1, "follower_cap": 3000, "per_achievement": 100, "per_ko": -150 },
      "rewards": { "participation": "badge_sat_show", "quest": "cos_mop_bowtie_prime", "percentile_titles": [1, 10, 50], "live_follower_cap": 2000, "sponsored_runs": "participation_only" }
    }
  ]
}
```

| Feld | Typ | Regeln |
|---|---|---|
| `id` | String | `evt_` + `[a-z0-9_]+`, eindeutig |
| `kind` | String | `offline` \| `daily` \| `weekly` \| `live_show` \| `special` |
| `floor` | int | Etage (1 im Slice) |
| `windows[]` | Array | `open_at`/`close_at` ISO-8601 **UTC**, `close_at > open_at`, Fenster überlappen nicht; leer = immer offen (nur `offline`) |
| `late_entry` | String | `until_last_entry` \| `first_10_min` \| `none` |
| `seed_policy.type` | String | `fixed` (nur `offline`, mit `run_seed: int`) \| `daily_derived` (nur Training) \| `commit_reveal` (mit `commits` je Fenster) |
| `quest` | Dictionary | Kap. 1.3 |
| `rules.mode` | String | `solo` \| `coop` |
| `rules.leagues` | Array | Teilmenge von `show`, `pur`; `offline` nur `pur`. Bei mehreren Ligen wählt der Lauf eine (`Game.start_event_run(id, league)`), sie steht im Log-Header (Kap. 10.6) |
| `rules.timer_mode` | String | `explore_only` \| `realtime` |
| `rules.difficulty` | String | `prime_time` (einziger Wert in S0): Event-Läufe spielen immer die Schwierigkeit `prime`; `Game.set_difficulty` wirkt nur in der Kampagne, ein `difficulty`-Command im Log eines Event-Laufs wird abgelehnt (`RunRules.command_refusal`), ein Header mit anderer Schwierigkeit ist ein Verifier-Fehler (Kap. 11.4) |
| `rules.party_preset` | String | ID in `res://data/party_presets.json` (neu, Kap. 11) |
| `rules.gifts` | Dictionary | Caps/Gewichte Kap. 6.10, **nur Ganzzahlen** (Lasten in Halbpunkten, Faktoren in Promille); `enabled: false` in S0; `sources` (Array) ⊆ `fan`, `shop`, `dev` (`bits` reserviert, seit 2026-10-08 nicht angeboten; `dev` = QA nur in `offline`-Events; `EventDef.validate` meldet Verstöße). Ohne `sources` nimmt ein Event-Lauf `fan`/`shop` an, aber nie `dev` (`GiftPolicy.check`). `rules` geht vollständig in `rules_hash` und damit in den Commit ein (Kap. 7.3) |
| `rules.sponsor_windows` | Dictionary | Sponsor-Fenster (Kap. 6.13): `enabled`, `slots_per_player`, `per_viewer`, `grace_sec`, `exempt_kinds` (⊆ Geschenk-Arten), `periodic {enabled, first_sec, every_sec, open_sec}`, `safe_room {enabled, max_sec, once_per_room}`, `boss {enabled, countdown_sec}`, `dev_open` — nur Ganzzahlen ≥ 1 (`grace_sec` ≥ 0) und Bools, unbekannte Schlüssel sind Fehler (`SponsorWindows.validate_rules`); fehlende Schlüssel = Standard (`SponsorWindows.DEFAULT_RULES`, auch für Kampagne/Offline); `dev_open` muss außer bei `offline` explizit `false` sein |
| `votes` | Dictionary | Kap. 6.2 |
| `scoring` | Dictionary | Kap. 1.5, nur Ganzzahlen |
| `rewards` | Dictionary | nur kosmetische IDs/Titel; `sponsored_runs` ∈ `participation_only` (einziger zulässiger Wert, Kap. 1.6) |

Zeitprüfung im Kern ohne Uhr: `EventDef.window_state(now_unix: int) -> String` bekommt die Zeit **übergeben** (Brief: kein
`Time` in `core/`). Offline übergibt die Darstellung `Time.get_unix_time_from_system()`; Tests übergeben feste Werte.

### 10.2 Gift-Schema

Siehe Kap. 6.5 (normativ; inkl. optionalem Stempel `sponsor_window`, Kap. 6.13). Zusätzlich `res://data/gift_tables.json`:

```json
{
  "schema": 1,
  "tiers": {
    "bronze": { "rolls": 2, "guarantee": "",     "weights": [80, 18, 2] },
    "silver": { "rolls": 3, "guarantee": "rare", "weights": [55, 38, 7] },
    "gold":   { "rolls": 4, "guarantee": "epic", "weights": [25, 55, 20] }
  },
  "rarities": ["common", "rare", "epic"],
  "pools": {
    "gift_f1": {
      "common": [ { "credits": 40, "w": 30 }, { "item_id": "item_bandage", "qty": 2, "w": 25 }, { "item_id": "item_energy_krawumm", "qty": 1, "w": 20 }, { "item_id": "item_ice_spray", "qty": 1, "w": 15 }, { "item_id": "item_molotov", "qty": 1, "w": 10 } ],
      "rare":   [ { "item_id": "item_brutzel_burger", "qty": 2, "w": 30 }, { "item_id": "item_smelling_salts", "qty": 1, "w": 25 }, { "item_id": "item_hype_megaphone", "qty": 1, "w": 20 }, { "item_id": "item_smoke", "qty": 1, "w": 15 }, { "credits": 150, "w": 10 } ],
      "epic":   [ { "item_id": "item_elixir", "qty": 1, "w": 40 }, { "item_id": "wpn_fire_axe", "qty": 1, "w": 20 }, { "item_id": "acc_sneakers", "qty": 1, "w": 20 }, { "credits": 400, "w": 20 } ]
    }
  },
  "pity": { "buyer_rare": 3, "buyer_epic": 9, "period": "permanent" },
  "fan_pack": { "pool": "gift_f1", "rarity": "common", "rolls": 1 }
}
```

### 10.3 Ledger-Eintrag

```json
{
  "entry_id": "le_01JB7Q4ZK3",
  "tx_id": "tx_01JB7Q4ZK0",
  "tx_type": "gift_deliver",
  "account": "escrow:gift:g_01JB7Q3M0F5W8V2TQK4N6H8R9S",
  "side": "debit",
  "amount_minor": 300,
  "currency": "ST",
  "created_at": "2026-11-07T19:42:06.214Z",
  "ref": { "gift_id": "g_01JB7Q3M0F5W8V2TQK4N6H8R9S", "event_id": "evt_2026w45_sat", "order_id": "", "psp_event_id": "", "twitch_txn_id": "" },
  "actor": "svc:gift",
  "idempotency_key": "deliver:g_01JB7Q3M0F5W8V2TQK4N6H8R9S",
  "reverses": ""
}
```

| Feld | Regeln |
|---|---|
| `tx_type` | `token_purchase` \| `gift_reserve` \| `gift_deliver` \| `gift_release` \| `refund` \| `chargeback` \| `chargeback_fee` \| `adjustment` — ~~`bits_gift_memo`, `creator_accrual`, `creator_payout`~~ **gestrichen per Entscheidung 2026-10-08** (keine Bits-Geschenke, keine Auszahlung/Beteiligung an Personen, L11; die Datenbank lehnt diese Typen per Constraint ab) |
| `side` / `amount_minor` | `debit`/`credit`, `amount_minor > 0` (Ganzzahl, Cent bzw. Token) |
| Invariante | Für jede `tx_id` und `currency`: Σ debit = Σ credit (DB-Constraint per Trigger bei Commit) |
| `reverses` | bei Storno die `tx_id` der Ursprungstransaktion |
| `idempotency_key` | eindeutig (Unique-Index) |

### 10.4 Bestenlisten-Eintrag

```json
{
  "schema": 1,
  "board_id": "evt_2026w45_sat|eu|show|coop",
  "event_id": "evt_2026w45_sat",
  "window_id": "eu",
  "league": "show",
  "mode": "coop",
  "run_id": "run_2Kx",
  "team_id": "t_01",
  "players": [ { "player_id": "p_A", "display_name": "Kai_der_Pfleger", "role": "kai" }, { "player_id": "p_B", "display_name": "MopsMagie", "role": "mopsula" } ],
  "score": 17340,
  "breakdown": { "quest": 10000, "time": 4140, "show": 2600, "achievements": 900, "ko": -300 },
  "quest_complete": true,
  "floor_timer_left_sec": 828,
  "run_wall_ms": 2210450,
  "gifts": { "external_count": 6, "load_half": 19, "paid": true },
  "flags": ["sponsored", "late_entry"],
  "replay_id": "rp_9d2…",
  "run_log_hash": "c47e…aa",
  "data_hash": "3f9a…c1",
  "sim_version": 7,
  "client_version": "0.9.3",
  "verified": "ok",
  "finished_at": "2026-11-07T19:58:31Z"
}
```

`verified` ∈ `pending` \| `plausible` (Grad A, ungewertet, Kap. 2 S1) \| `ok` \| `failed` \| `annulled`.
`run_wall_ms` und `finished_at` sind serverseitig ermittelt (Kap. 1.5). Läufe mit `flags` ∋ `sponsored` erhalten nur die
Teilnahme-Plakette (Kap. 1.6). Rang wird beim Lesen berechnet (Tie-Break Kap. 1.5).
S0 lokal: gleiches Schema, `league: "pur"`, `verified: "local"`, `players[0].player_id: "local"`; `run_id`/`replay_id` =
`run_id` des Log-Headers, `run_log_hash` = `RunLog.digest()`, `data_hash` = `DB.data_hash()` (SHA-256 über alle Dateien in
`res://data/`), dazu `difficulty`, `sim_version`, `client_version`, `finished_at`; `Game.finish_run` gibt den Eintrag in
`summary["entry"]` zurück. **Lokale Bestenlisten und Replays** (`user://leaderboards/`, `user://replays/`) sind normales,
editierbares JSON: Sie werden nie hochgeladen und nie als vertrauenswürdig behandelt (gewertet wird erst serverseitig ab S1).
Event-Läufe werden nie in einen Spielstand-Slot gespeichert (02_TECH §3.6).

### 10.5 Twist-Definition (`res://data/twists.json`)

```json
[ { "id": "tw_lights_out", "name_key": "tw_lights_out_name", "gameplay": true, "scope": "explore", "duration_sec": 60,
    "effect": { "enemy_sight_mult": 0.5, "player_vignette": 0.6 }, "mod_line": "twist_applied_tw_lights_out" } ]
```

### 10.6 Run-Log und Command

```json
{
  "header": {
    "schema": 1, "game_version": "0.9.3", "sim_version": 7, "proto": "1.0", "data_hash": "3f9a…c1",
    "event_id": "evt_offline_gleis9", "window_id": "", "run_id": "run_local_0007", "league": "pur", "mode": "solo",
    "run_seed": 424242, "sym": 0, "party_preset": "preset_f1_l1", "sim_hz": 30, "timer_mode": "explore_only"
  },
  "frames": [],
  "pos": [ [0, 0, 0, 0], [15, 210, 0, -180] ],
  "cmds": [
    { "k": 300,  "id": 1, "c": { "t": "time", "ticks": 300 } },
    { "k": 395,  "id": 2, "c": { "t": "room_enter", "cell": [4, 6], "first": true } },
    { "k": 410,  "id": 3, "c": { "t": "interact", "obj": "f1_c3" } },
    { "k": 980,  "id": 4, "c": { "t": "encounter", "encounter_id": "enc_f1_rats", "group_id": "f1_g2", "advantage": 1 } },
    { "k": 980,  "id": 5, "c": { "t": "battle", "n": 0, "kind": "attack", "actor_id": "p0", "skill_id": "", "item_id": "", "target_ids": ["e1"] } },
    { "k": 980,  "id": 0, "c": { "t": "gift", "gift": { "schema": 1, "gift_id": "g_dev_0001", "source": "dev", "sponsor_window": "sw_2", "…": "…" } } },
    { "k": 1200, "id": 6, "c": { "t": "sponsor_window", "op": "dev_open", "sec": 60, "slots": 3 } }
  ],
  "checkpoints": [ { "k": 300, "h": "9b1e…" }, { "k": 1300, "h": "0c7a…" } ],
  "result": { "cause": "floor_completed", "score": 14210, "final_hash": "77d2…" }
}
```

- **Header im Slice** (`Game._make_run_log`): `schema`, `seed`, `slot`, `player_name`, `mode`, `difficulty`, `game_version`,
  `sim_hz`, `sim_version` (`RunSim.SIM_VERSION`) und die **Lauf-Identität** `event_id`, `run_id` (je Versuch eindeutig,
  `RunLog.local_run_id(seed)` = `run_local_<seed>_<8 hex>`), `player_id` (S0 `"local"`), `window_id` (`""` offline), `league`.
  Gegen die Identität prüft der Kern die Lauf-Bindung von Geschenken (Kap. 6.9); die Verifier prüfen bei Katalog-Events
  festen Seed, Schwierigkeit `prime` und Liga (Kap. 11.4). Das Beispiel oben zeigt das Ziel-Format ab S1.
- `k` = Sim-Tick (30 Hz, eine Simulationsuhr, Kap. 3.2), **normativ je Timer-Modus:**
  - `explore_only`: `k` zählt Erkundungs-Ticks und — seit den Sponsor-Fenstern (Kap. 6.13) — **Leerlauf-Ticks im Safe Room**
    (nur die Fenster-Uhr läuft, der Etagen-Timer nicht; welcher Tick welcher ist, folgt aus `floor_run.location`, also aus den
    Commands `safe_room`/`safe_room_exit`); der Etagen-Timer steht im Kampf, daher tragen Kampf-Commands den `k`
    ihres `encounter` und werden über `n` geordnet. Zug-Timeouts gibt es in diesem Modus nicht.
  - `realtime`: `k` zählt **Wanduhr-Ticks** ab Laufstart (Kampf, Safe Room, Menüs eingeschlossen); **jedes** Command, auch
    jedes Kampf-Command und jedes `auto: true`-Timeout-`defend`, trägt den echten Tick seiner Anwendung → Timerstand nach
    einem Kampf, Zug-Timeouts (`deadline_tick`) und Hartes Ende sind im Replay rekonstruierbar.
- `id` = `cmd_id` (Kap. 4.2), pro Lauf und Spieler:in strikt monoton ab 1; externe Eingänge (`gift`, `twist`) und
  Server-Commands tragen `id: 0`. Koop: zusätzlich `"p": player_id`. Der Verifier prüft Monotonie. Im Slice vergibt
  `Game.record` die IDs (02_TECH §3.4: `gift`/`twist` → 0, alles andere fortlaufend ab 1 je `RunLog`).
- `frames`: **Grad B** (Kap. 3.3) — lauflängenkodierte Eingaben `[tick, mx, mz, yaw, buttons]`; im Slice (Grad A) leer.
- `pos`: **Grad A** — Positionsproben `[tick, x_dm, y_dm, z_dm]` (Dezimeter, 2 Hz, nur Darstellung/Replay-Ansicht).
- `cmds[].c` = Command. Typen (`t`): Erkundungs-Ergebnisse `time`, `room_enter`, `interact`, `encounter`, `descend`;
  Kampf `battle` (Felder = `BattleCommand`, 02_TECH §5.4, plus Aktionsindex `n`); Menüs `menu_use_item`, `equip`, `unequip`,
  `vendor_buy`, `vendor_sell`, `rest`, `lootbox_open`, `event_choice`; **externe Eingänge** `gift`, `twist`; QA
  `sponsor_window {op: "dev_open", sec, slots}` (Kap. 6.13; nur wo `rules.sponsor_windows.dev_open`). Sponsor-Fenster selbst
  stehen **nicht** im Log — sie folgen deterministisch aus Ticks und Commands (`floor`, `room` einer Boss-Zelle, `safe_room`,
  `safe_room_exit`); externe Geschenke tragen den Stempel `sponsor_window`, den Replay und Verifier gegen den nachgerechneten
  Zustand prüfen.
- System-Geschenke (Hype-Schwellen) stehen **nicht** im Log — sie entstehen deterministisch aus dem Show-RNG
  (`Game.next_seed("show")`), laufen aber ebenfalls durch `Show.receive_gift()` (Kap. 11.3). Externe Geschenke werden bei ihrer
  **Anwendung** aufgezeichnet (im Kampf in `take_pending_gift`, sonst sofort), nicht beim Empfang — nur so kann das Replay sie an
  derselben `_play`-Grenze einspeisen (02_TECH §3.5).
- Live (S4): zusätzlich `action_seeds: [[battle_n, action_n, seed], …]` bis zum Reveal; danach ableitbar.

---

## 11. Was JETZT im Vertical Slice gebaut wird (S0 + Hooks)

> Abgestimmt auf `02_TECH.md` (Stand des Abgleichs: 2026-10-10, Branch `ptd/final-a`; bei Abweichungen gelten Namen und
> Signaturen von 02_TECH §7.1). Grundsatz: Der Slice baut S0 vollständig und legt für S1–S5 nur
> **Hooks** an, die heute schon testbar sind. Neue Dateien gehören einem neuen Modul **M8 „Live-Hooks“** (Ordner
> `core/live/`, Tests `tests/test_m8_*.gd`). Änderungen an Dateien anderer Module sind als Änderungsanträge **CR-1 … CR-14**
> in Kap. 11.6 formuliert (02_TECH §0.2) und inzwischen alle umgesetzt. Alles in `core/live/` ist `RefCounted`, statisch typisiert, ohne Autoloads,
> ohne SceneTree, ohne `Time`, Zufall nur per übergebenem `RandomNumberGenerator` (02_TECH §0.4).

### 11.1 Daten

| Datei | Besitzer | Inhalt im Slice |
|---|---|---|
| `data/events.json` | M7 (Inhalt), M8 (Schema/Loader) | 1–2 Offline-Events (`evt_offline_gleis9` wie Kap. 10.1, optional `evt_offline_pacifist`). Geladen von `EventCatalog` (M8), **nicht** von `GameData` — die 13 Tabellen aus `GameData.TABLES` (02_TECH §1.4) bleiben unverändert (CR-9). |
| `data/mod_lines.json` | M7 | neue, **optionale** Tags `event_run_start`, `event_quest_progress`, `event_quest_complete`, `event_result`, `gift_received`, `gift_received:credits`, `gift_received:anon` (Fallback-Mechanik `a:b → a` aus 02_TECH §6.1; **keine** Varianten je Kistenstufe, L13) — CR-9; dazu die Zeilen aus Kap. 6.12 (`gift_diminished`, `gift_capped`, `gift_declined`, `fan_pack_received`, `live_closing`, `vote_open`) mit den Platzhaltern `{sender}`, `{amount}`, `{pct}`, `{min}` (`DataValidator.TEXT_PLACEHOLDERS`, optionale Präfixe `gift_`/`fan_pack_`/`live_`/`vote_`/`twist_applied_`) |
| `Progression.EXP_TABLE` (`core/progression/progression.gd`) | M2 | EXP-Tabelle als Ganzzahl-Konstante je Level (GDD §4.3; ersetzt `pow`, CR-12) — keine Datei in `data/` |
| `tests/fixtures/live/gift_tables.json` | M8 | **Hook:** Schema Kap. 10.2; im Slice nur von `FairRoll`-Tests gelesen (kein Eintrag in `data/`) |
| Party-Preset | — | S0 unterstützt nur `rules.party_preset: "new_game"` (= `GameState.create_new`, 02_TECH §6.1); `party_presets.json` kommt mit S2 |
| `twists.json`, `party_presets.json` | — | **nicht** im Slice |

### 11.2 Kern (`res://core/live/`, Modul M8)

| Datei | `class_name` | Öffentliche API |
|---|---|---|
| `core/live/canonical_json.gd` | `CanonicalJson` | `static func stringify(v: Variant) -> String` (JCS-Profil Kap. 3.3 Nr. 9: Schlüssel ASCII, nach Codepunkt sortiert, keine Leerzeichen, ganzzahlige Floats → `int`, nicht-ganzzahlige Zahlen → Fehler, Escape-Regeln wie spezifiziert) · `static func sha256_hex(v: Variant) -> String` · `static var last_error: String` (statisch, damit die statischen Funktionen ihn setzen können; Aufrufer lesen `CanonicalJson.last_error`, `""` = letzter Aufruf ok) |
| `core/live/run_sim.gd` | `RunSim` | **Dünne Variante im Slice (CR-6), umgesetzt** — Signaturen und Tick-Reihenfolge normativ in 02_TECH §7.1: `func _init(p_data: GameData, p_state: GameState, p_rules: Dictionary, p_identity: Dictionary = {})` (Lauf-Identität `run_id`/`event_id`/`player_id`/`window_id`/`league` aus dem Log-Header, `identity_of`) · `func step(n: int) -> Array[ExploreEvent]` (je Tick: Etagen-Timer `FloorRun.tick_timer`, Pazifist-Sekunden, Hype-Abkühlung über `ShowModel.decay_step` alle `HYPE_DECAY_TICKS`, Streuner, Sponsor-Fenster; Leerlauf-Ticks im Safe Room nur Sponsor-Fenster) · `func apply(cmd: Dictionary) -> Array[ExploreEvent]` (prüft zuerst `command_refusal`, abgelehnte Commands → `rejected_cmds`) · `func tick() -> int` · `func command_refusal(c) -> String` / `func gift_refusal(g) -> String` · `static func replay(p_data, p_log, p_rules = {}, p_quest = {}, p_ledger = []) -> Dictionary` (`{"final_hash", "result", "mismatch_at", "errors"}`, Kap. 11.4) · `static func header_errors(h, def, rules)` · `const SIM_VERSION` · keine Autoloads, kein SceneTree |
| `core/live/command.gd` | `Command` | `static func validate(d: Dictionary) -> String` (Schema je `t`: Pflichtfelder, Typen, Wertebereiche, `flag`-Schlüssel nur aus `FLAG_KEYS`; `""` = gültig) · `const TYPES: PackedStringArray` |
| `core/live/run_rules.gd` | `RunRules` | Die gemeinsamen Spielregeln der aufgezeichneten Nicht-Kampf-Commands, die `Game` (live) und `RunSim` (Verifier) beide aufrufen: `start_floor`, `visit_room`, `open_chest`, `open_lootbox`, `open_gate`, `apply_floor_event`, `enter_safe_room`/`leave_safe_room`, `mark_scene_seen`, `lower_difficulty`, `next_seed` · `static func command_refusal(state, data, rules, c, floor_done, scene_ctx) -> String` (Legalität für Verifier: nach `descend` nur noch die nächste Etage, Etagen nur der Reihe nach, Schwierigkeit nur in der Kampagne, Szenen nur im Safe Room mit erfüllter Bedingung) — 02_TECH §7.1 |
| `core/dungeon/explore_event.gd` (Modul **M3**, 02_TECH §1.3) | `ExploreEvent` | `enum Type { ROOM_ENTERED, CHEST_OPENED, ENCOUNTER, ENEMY_STATE, EVENT_CHOICE, GATE_OPENED, ACHIEVEMENT, HYPE, TIMER_SECOND, TIMER_WARNING, TIMER_EXPIRED, EXPLORE_TICK, STRAY_DUE, GIFT_DELIVERED, FLOOR_COMPLETED, SPONSOR_WINDOW_OPENED, SPONSOR_WINDOW_CLOSED }` (17 Werte; die letzten beiden aus CR-15) · `const TYPE_NAMES` (serialisierte Namen, Index = Typ) · `var type: Type` · `var tick: int` · `var data: Dictionary` · `static func make(type, tick, data)` · `func to_dict() -> Dictionary` · `static func from_dict(d: Dictionary) -> ExploreEvent` — Brief 6b.2 („Ereignisse raus“) für die Erkundung; maßgeblich ist 02_TECH §7.1 |
| `core/live/run_log.gd` | `RunLog` | `var header: Dictionary` · `func add_cmd(tick: int, cmd: Dictionary, cmd_id: int = 0) -> void` · `func add_pos(tick: int, pos: Vector3) -> void` (2 Hz, Grad A) · `func add_checkpoint(tick: int, p_hash: String) -> void` · `func cmds() -> Array[Dictionary]` · `func to_dict() -> Dictionary` · `static func from_dict(d: Dictionary) -> RunLog` · `func digest() -> String` |
| `core/live/state_hash.gd` | `StateHash` | `static func of(state: GameState) -> String` — SHA-256 über `CanonicalJson` von `state.to_dict()` **ohne** Anzeige-/Metafelder (`play_time_sec`, `show.viewers`, `slot` — `Save.save_slot` verschiebt den aktiven Slot) · `static func of_battle(state: BattleState) -> String` (CR-14) |
| `core/live/event_def.gd` | `EventDef` | `static func from_dict(d: Dictionary) -> EventDef` · `func validate() -> PackedStringArray` · `func window_state(now_unix: int) -> StringName` (`&"always"`, `&"scheduled"`, `&"open"`, `&"last_entry"`, `&"closing"`, `&"closed"`) · `func can_start(now_unix: int) -> bool` · `func run_seed() -> int` (nur `fixed`) |
| `core/live/event_catalog.gd` | `EventCatalog` | `func load_file(path: String) -> bool` · `func get_event(id: String) -> EventDef` · `func all() -> Array[EventDef]` · `var errors: PackedStringArray` |
| `core/live/quest_tracker.gd` | `QuestTracker` | `static func from_def(q: Dictionary) -> QuestTracker` · `func on_event(ev: Dictionary) -> bool` (true = Fortschritt geändert) · `func progress() -> float` · `func is_complete() -> bool` · `func to_dict() -> Dictionary` · `static func from_dict(d: Dictionary) -> QuestTracker`. Quest-Events (normalisiert, erzeugt vom Adapter in `Game`, CR-4): `{"type": "enemy_killed", "enemy_id"}`, `{"type": "boss_defeated", "boss_id"}`, `{"type": "battle_started"}`, `{"type": "floor_completed", "floor"}`, `{"type": "achievement", "id"}`, `{"type": "metric", "name", "value": int}` — `name` ∈ `viewers_target_peak`, `followers_gained_run`, `hype_100_count` (nur deterministische Ganzzahl-Größen, nie verrauschte Anzeige-Zuschauer; CR-13). S0-Typen: `reach_stairs`, `defeat_boss`, `bounty`, `hype_peak`, `pacifist`, `achievement_hunt`, `all_of` |
| `core/live/score_calc.gd` | `ScoreCalc` | `static func score(summary: Dictionary, scoring: Dictionary) -> Dictionary` → `{ "score": int, "breakdown": Dictionary }` |
| `core/live/leaderboard.gd` | `Leaderboard` | `func add(entry: Dictionary) -> int` (Rang, 1-basiert; Top 10 bleiben) · `func top(n: int) -> Array[Dictionary]` · `static func is_better(a: Dictionary, b: Dictionary) -> bool` · `func to_dict() -> Dictionary` · `static func from_dict(d: Dictionary) -> Leaderboard` (korrupt → leer) |
| `core/live/gift.gd` | `Gift` | `static func validate(g: Dictionary) -> String` (Reason-Codes Kap. 6.5, `""` = gültig; prüft u. a. `effect_pm: int`, `client_seed` = 16 Hex-Zeichen, `anon`-Standard, keine Floats) · `static func make_system(sponsor_id: String, battle_n: int, k: int) -> Dictionary` · `static func make_dev(kind: String, tier: String, amount: int, sender_ref: String = "") -> Dictionary` · `static func is_external(g) -> bool`; prüft außerdem `sender_ref` (`^b_[0-9a-f]{12}$`, Pflicht für Käufer-Quellen), Art je Quelle (`KIND_SOURCES`: `bits` nur `cheer`) und Inhaltsgrenzen (`MAX_CONTENT_QTY` 9, `MAX_CONTENT_CREDITS` 1000) |
| `core/live/gift_policy.gd` | `GiftPolicy` | `static func effect_pm(load_half: int, k_pm: int = 75) -> int` · `static func load_weight_half(g: Dictionary, weights_half: Dictionary) -> int` · `static func rolls_for(base_rolls: int, effect_pm: int) -> int` · `static func scale(value: int, effect_pm: int) -> int` (`(value * effect_pm + 500) / 1000`) · `static func chest_allowed(load_half: int, rules: Dictionary) -> bool` · `static func check(run: Dictionary, g: Dictionary, rules: Dictionary) -> String` (`run` = Gift-Zähler des Laufs aus `GameState.flags["live"]`, ergänzt um `tick` und Lauf-Identität) · `static func refusal(state, data, g, rules, extra) -> String` (DIE Anwendungsprüfung von Show und `RunSim.gift_refusal`: Duplikat, unbekannte Inhalte, dann `check`) · `static func remember(state, gift_id)` · `static func note_applied(run, g, rules, tick = -1)` (bucht jedes angewandte externe Geschenk genau einmal) · `run_league` · `can_deliver_in_battle` — ausschließlich Ganzzahlen (Kap. 6.10) |
| `core/live/sponsor_windows.gd` | `SponsorWindows` | **Sponsor-Fenster (CR-15, Kap. 6.13):** `const DEFAULT_RULES` · `static func rules_of(rules) -> Dictionary` · `static func active(st, rules) -> bool` · `static func ensure(st, rules) -> Dictionary` · `static func tick(st, rules, explore: bool) -> Array[Dictionary]` · `on_floor` · `on_safe_room_enter(st, rules, room_id)` · `on_safe_room_exit` · `on_room(st, rules, kind)` · `dev_open(st, rules, sec, slots)` / `dev_allowed` · `static func check(run, g) -> String` (`window_closed` \| `window_full` \| `window_sender_limit`, Reservierungen `run["sw_pending"]`) · `static func book(run, g)` · `window_for(run, g)` · `view(st, rules)` / `window_view(w)` · `validate_rules(cfg)` · `protocol_code(reason)` — Zustand `flags["live"]["sponsor"]`, nur Ganzzahlen |
| `core/live/gift_applier.gd` | `GiftApplier` | `static func apply(state: GameState, data: GameData, g: Dictionary, rng: RandomNumberGenerator, tick: int = -1) -> Array[LootReward]` — Anwendung **außerhalb** von Kämpfen (`gold`, `chest`, `fan_pack`, `sponsor_buff` als Heilung/MP/Item laut `SponsorDef.gift`; Ausrüstungs-Duplikate → Credits über `ItemDef.duplicate_credits`) · `static func note_battle_gift(state, g, events, tick = -1)` / `count_battle_items` (Buchung eines im Kampf angewandten Geschenks); im Kampf wendet `BattleState.apply_gift` an (CR-2) und rechnet Duplikate gleich um |
| `core/live/fair_roll.gd` | `FairRoll` | **Hook (nur Tests):** `static func hmac(key: PackedByteArray, msg: String) -> PackedByteArray` (`Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, msg.to_utf8_buffer())`) · `static func u48(b: PackedByteArray) -> int` · `static func commit(server_seed: PackedByteArray, event_id: String, window_id: String, tables_hash: String, rules_hash: String, data_hash: String, sim_version: int) -> String` (v2) · `static func layout_seed(server_seed: PackedByteArray, event_id: String, window_id: String) -> int` · `static func roll_key(server_seed: PackedByteArray, event_id: String, window_id: String, sender_ref: String, client_seed: String, nonce: int) -> PackedByteArray` · `static func roll_chest(roll_key: PackedByteArray, tier: Dictionary, pool: Dictionary, rolls: int, pity_forced: String) -> Array[Dictionary]` |

Bewusst **nicht** im Slice: `ExploreSim` (Grad B, Kap. 3.3 — aber Benchmark-Prototyp für das Verifier-Budget, Kap. 2 S1),
der volle Server-Ausbau von `RunSim` (mehrere Instanzen, Netzwerk-Befehlsquelle), Netzwerk, Accounts, Votes, Echtgeld.
`RunSim` selbst ist in der dünnen Variante **im** Slice (Kap. 3.2).

### 11.3 Autoloads, Signale, Szenen (über Änderungsanträge)

| Ort (Besitzer) | Änderung im Slice |
|---|---|
| `Events` (M0) | neue Signale: `run_started(event_id: String, league: String)`, `run_finished(summary: Dictionary)`, `quest_progress(progress: float)`, `quest_completed()`, `gift_received(gift: Dictionary)`, `gift_rejected(gift_id: String, reason: String)` (CR-1); `sponsor_window_opened(window: Dictionary)`, `sponsor_window_closed(window_id: String, reason: String)`, `sponsor_window_updated(window: Dictionary)` (CR-15) |
| `Game` (M0) | `var mode: StringName = &"campaign"` (`&"event_offline"`) · `var run_log: RunLog` · `var quest: QuestTracker` · `func start_event_run(event_id: String, p_league: String = "") -> void` (Seed aus `EventDef.run_seed()`, `GameState.create_new`, Liga im Log-Header, Slot 0 → Event-Läufe werden nie in Spielstand-Slots gespeichert) · `func accepts_gifts() -> bool` · `func gift_context() -> Dictionary` (Tick + Lauf-Identität für `GiftPolicy.refusal`) · `func can_lower_difficulty() -> bool` (nur Kampagne) · `func record(cmd: Dictionary) -> void` · `func finish_run(cause: StringName) -> Dictionary` (Summary inkl. `party_kos`, `followers_gained_run`, `achievements_in_run`, `quest_progress_ppm` → `ScoreCalc` → `Leaderboard` → `sim.close(cause, {"score"})` → `Save`) · `func event_rules() -> Dictionary` · `func adopt_loaded_state(st, log)` (Save.load_slot) · die Live-Uhr schreibt Checkpoints in `run_log` (`sim.run_log`; alle 300 Ticks, nach Kämpfen/Abstieg) · Quest-Adapter zusätzlich `zones`/`boss_hp` · `func replay_log(p_log: RunLog, until_tick: int = -1) -> Dictionary` (`{"final_hash", "result", "mismatch_at", "errors"}`; treibt dieselben Funktionen wie die Szenen, ohne Szenen; Motor im privaten Helfer `autoload/game_replay.gd`; Vertrag Kap. 11.4) · **Fassade über `RunSim`** (CR-6): `_process` akkumuliert Frame-`delta` in ganze Ticks (1/30 s) und ruft `RunSim.step(n)`; Timer in ganzen **Ticks** (`time_left_ticks`) + `time`-Commands (CR-3, CR-4); Ergebnisse von `RunSim` werden als Signale weitergereicht. Kampagne zeichnet ebenfalls auf (Brief 6b.3, hilft bei Bug-Reports). |
| `Show` (M2) | **`func receive_gift(gift: Dictionary) -> Dictionary`** — einziger Eingang für **alle** Geschenke: `Gift.validate` → `GiftPolicy.check` → im Kampf (`Game.in_battle`) Warteschlange bzw. sofort `GiftApplier` (Erkundung); bei `source ≠ "system"` `Game.record({"t": "gift", "gift": gift})` im Moment der **Anwendung** (02_TECH §3.5) · `func take_pending_gift() -> Dictionary` ersetzt `take_sponsor_gift() -> String`: zuerst wartende externe Geschenke, sonst System-Auswahl per `SponsorSystem.pick` → `Gift.make_system(id, …)` → **ebenfalls durch `receive_gift()`** → Rückgabe (leer = nichts) · zwei RNGs: `_rng` (Spiellogik, nur Sponsor-Auswahl) und `_fx_rng` (Chat, Zuschauer-Rauschen, M.O.D.-Zeilenwahl — nicht deterministisch relevant) · wartende externe Geschenke werden bei der **Anwendung** erneut geprüft (`application_refusal`: Duplikat, `GiftPolicy.check` mit Lauf-Zählern + Tick; Kampf-Limit `rules.gifts.max_per_battle`) und im Kampf beim Ausgeben (`take_pending_gift`) genau einmal gebucht; `abort_battle()` für vorzeitig beendete Kämpfe · **Fassade**: Hype-Abkühlung (`ShowModel.decay_step`) und Pazifist-Zählung rechnet `RunSim.step` in Ticks; die Zuschauerzahl leitet `ShowModel.viewers_for` rauschfrei aus Hype und Followern ab; `Show._process` macht nur noch Anzeige (Glättung, Rauschen, Chat-Takt) (CR-5, CR-6) · Annahme und Ausgabe prüfen beide `GiftPolicy.refusal` (Kap. 6.10); im Kampf wartet ein Service-Geschenk, solange `too_soon` gilt |
| `scenes/battle/battle_controller.gd` (M5) | nach `hud.request_command` bzw. `choose_ai_command`: `Game.record({"t": "battle", …, "auto": not player_chosen})`; in `_play`: `var g := Show.take_pending_gift()` → `state.apply_gift(g)` → `Show.note_battle_gift(g, events)` (zählt die Geschenk-Items; die Lauf-Zähler bucht `take_pending_gift` genau einmal, wie RunSim über `GiftApplier.note_battle_gift`) (CR-7) |
| `Save` (M2) | `func load_leaderboard(event_id: String) -> Dictionary` / `func save_leaderboard(event_id: String, d: Dictionary) -> Error` → `user://leaderboards/<event_id>.json` (atomar wie Slots); `func save_replay(p_log: RunLog) -> Error` → `user://replays/<run_id>.json`, max. 20 Dateien (CR-8) |
| `scenes/title/title.gd` (M6) | Menüeintrag **„Event-Lauf“** zwischen „Laden“ und „Einstellungen“ (CR-10) |
| `scenes/ui/event_lobby.tscn` + `.gd` (M6) | Event-Karte: Name, Quest-Text, Regeln (Timer, „Pur-Liga“), lokale Top 10, Start |
| `scenes/ui/exploration_hud.gd` (M6) | Quest-Zeile unter dem Timer mit Fortschrittsbalken (nur `Game.mode == &"event_offline"`) |
| `scenes/ui/run_result.tscn` + `.gd` (M6) | Punkteaufschlüsselung (Kap. 1.5), Rang, „Nochmal“, „Zum Titel“; „Replay ansehen“ erst ab S1 |
| `scenes/ui/debug_overlay.gd` (M6) | nur Debug-Build: Taste/Knopf „Test-Geschenk“ (F4) → `Show.receive_gift(Gift.make_dev("chest", "bronze", 0, <neue Test-Zuschauer:in>))` — respektiert die Sponsor-Fenster (Ablehnung mit Grund und „nächstes in m:ss“); „Fenster öffnen“ (F5) → `Game.open_dev_sponsor_window(60, 3)` (aufgezeichnet, CR-15) |
| Sponsor-Fenster (CR-15) | `Game`: Auslöser in `start_floor`/`visit_room`/`enter_safe_room`/`leave_safe_room`, `open_dev_sponsor_window`, `sponsor_window()`, `safe_room_clock` + `is_idle_ticking()` (Leerlauf-Ticks), `replay_log(p_log, until_tick)`; `Show`: Fensterprüfung in `receive_gift` (über `GiftPolicy.check`), Stempel, `sponsor_presentation()`, `sponsor_window_view()`, M.O.D.-Zeilen (nur live); `ShowOverlay`: Badge im Laufband; `SafeRoomScene` setzt `Game.safe_room_clock`; `mod_lines.json` + `DataValidator`-Präfix `sponsor_window_` |

### 11.4 Tests (`res://tests/`, Runner aus 02_TECH §11.1, `tools/check.sh --tests-only`)

| Datei | Prüft |
|---|---|
| `test_m8_canonical_json.gd` | Schlüsselreihenfolge, Ganzzahl-Formatierung, verschachtelte Arrays, Unicode/Steuerzeichen-Escapes, `/` unescaped, nicht-ganzzahlige Zahl → Fehler, `JSON.parse`-Rundlauf stabil; feste SHA-256-Referenzwerte, **identisch** mit den Python-/JS-/Go-Testvektoren (`tests/fixtures/live/canonical_vectors.json`) |
| `test_m8_run_log.gd` | `to_dict`/`from_dict`-Rundlauf, `digest()` stabil, Commands bleiben in Tick-Reihenfolge, `cmd_id` strikt monoton (Duplikat → abgelehnt) |
| `test_m8_command.gd` | `Command.validate` je `t` (Pflichtfelder, Typen, unbekannter Typ → Fehler, `flag`-Schlüssel nur aus `FLAG_KEYS`); jeder Typ aus `Command.TYPES` hat einen Zweig in `RunSim.apply` **und** im Replay-Motor von `Game.replay_log`; `ExploreEvent`-Rundlauf `to_dict`/`from_dict` |
| `test_m8_run_sim.gd` | `RunSim` ohne Autoloads: `step(n)` zieht Timer in Ticks ab, Hype-Abkühlung (`ShowModel.decay_step`), Pazifist-Zählung und Streuner deterministisch; `step(1)` × n ≡ `step(n)` |
| `test_m8_integrity.gd` | Verifier gegen gefälschte Logs: Schwierigkeit nur in der Kampagne und Header-Prüfung (fester Seed, `prime`, Liga), regelwidrige Etagen-/Szenen-Commands, Geschenke nach `descend`, Vertrag von `Game.replay_log` (`errors`), Liga-Bindung bei mehreren Ligen, `wrong_target` und Ledger-Abgleich (eingeschleust/fehlend/verspätet), Mindestabstand `too_soon`, eindeutige `run_id`s und Bestenlisten-Eintrag |
| `test_m8_no_global_rng.gd` | durchsucht `res://core/**/*.gd` nach `randf(`, `randi(`, `randomize(`, `randf_range(`/`randi_range(` ohne Objekt-Präfix, `Time.`, `OS.get_ticks` **sowie** `pow(`, `exp(`, `sin(`, `cos(`, `atan2(`, `randf` (auch mit Objekt-Präfix), `randfn`, `lerp(` → Fehler mit Datei:Zeile; Ausnahmen nur mit Whitelist-Kommentar `# det-ok: <Grund>` (Kap. 3.3 Nr. 5) |
| `test_m8_event_def.gd` | `window_state` mit festen Unix-Zeiten (vor/zwischen/nach Fenstern, `last_entry`, `closing`, `always`); Validierungsfehler (überlappende Fenster, `fixed` ohne Seed, unbekannter Quest-Typ) |
| `test_m8_quest_tracker.gd` | jeder S0-Quest-Typ mit festen synthetischen Event-Folgen (erfüllt / nicht erfüllt / Fortschritt); `hype_peak` nur über `viewers_target_peak`/`followers_gained_run`/`hype_100_count` (verrauschte Anzeige-Zuschauer ändern nichts); `pacifist` scheitert beim 4. Kampf; `all_of` = Mittelwert; Rundlauf `to_dict`/`from_dict` |
| `test_m8_score_calc.gd` | Beispielrechnung Kap. 10.4 (17 340), unvollständige Quest, Tie-Break-Reihenfolge |
| `test_m8_leaderboard.gd` | Einfügen, Top 10, Sortierung, Persistenz-Rundlauf, korrupte Daten → leer |
| `test_m8_gift.gd` | Pflichtfelder, `run_bound = false` → ungültig, `league = "pur"` + `source ≠ "system"` → `league_pur`, Duplikat → `duplicate`, `make_system` erzeugt gültiges Gift |
| `test_m8_gift_policy.gd` | `effect_pm`-Tabelle Kap. 6.10 **exakt** (1000/769/625/526/454/357/294/217), `rolls_for` inkl. Gold bei L = 4 → 3, `chest_allowed` (Schwelle 500 → gesperrt ab `load_half` 14), Caps (`load_half` 48, 16 Geschenke, 8 Kisten, 2 Gold-Kisten, 1 extern pro Kampf), jede Lieferung genau einmal gebucht, Mindestabstand, Lauf-Bindung |
| `test_m8_gift_applier.gd` | Bronze-Dev-Kiste fügt Items hinzu und zählt sie in `flags["live"]["gift_items"]`; `gold` × Wirkungsfaktor; Ausrüstungs-Duplikat → Credits; dieselbe Kiste ergibt im und außerhalb des Kampfs dasselbe Inventar, dieselben Credits und dieselben `gift_items` |
| `test_m8_fair_roll.gd` | **Testvektor Kap. 7.4 bitgenau** (Commit v2, `layout_seed`, `loot_seed`, `sym`, `roll_key`, `draw`, Silber 3/2 Würfe, Gold 4/3 Würfe, Bronze); Verteilung 100 000 Bronze-Würfe innerhalb ±0.5 %-Punkte der Tabelle |
| `test_m8_replay.gd` | **headless gegen `RunSim`, ohne Autoloads** (testet denselben Code, den Verifier/Server ausführen): Bot-Event-Lauf mit `auto_battle` und `force_encounter`-Äquivalent über Commands → Replay → gleicher `final_hash`; zweiter Lauf gleicher Seed → gleicher Hash; manipulierter Command → `mismatch_at ≥ 0`. Zusätzlich ein dünner Integrationstest über die `Game`-Fassade (lädt per `load()` nach `process_frame`, 02_TECH §11) |
| `test_m8_receive_gift.gd` | System-Geschenk aus `take_pending_gift` läuft durch `receive_gift` und erscheint **nicht** im Log; Dev-Geschenk erscheint im Log; Pur-Liga lehnt Dev-Geschenk ab |
| `test_m8_sponsor_windows.gd` | Sponsor-Fenster (Kap. 6.13): Standardwerte; periodischer Fahrplan in Erkundungs-Ticks (Tick 9000 auf, 10800 zu); `step(1)` × n ≡ `step(n)`; Kampf friert Fenster und Countdown ein, kein Fenster öffnet im Kampf; Plätze (wer zuerst kommt), Pro-Zuschauer-Limit (datengetrieben), Reservierungen wartender Geschenke; Gründe/Codes `window_closed`/`window_full`/`window_sender_limit` → `E_WINDOW_*`; `cheer` ausgenommen; Gnadenfrist gestempelter Geschenke; Safe-Room-Fenster mit Leerlauf-Ticks (Timer steht, ≤ 90 s, einmal je Raum, Verlassen schließt); Boss-Countdown (45 s, ersetzt offenes Fenster, nur Erstbesuch); Etagenwechsel; Pur-Liga/ausgeschaltet ohne Fenster; QA-Fenster nur wo erlaubt; Regel-Validierung (auch `EventDef`); **Replay-Gleichheit** (`RunSim.replay`, Checkpoints) und gefälschtes Geschenk außerhalb eines Fensters → `errors`; Integration: `Show.receive_gift` außerhalb/innerhalb, Signale, Stempel im Log, `Game.replay_log` ≡ live, Reservierungen im Kampf, Leerlauf-Ticks über `Game._process`, Boss-Countdown über `Game.visit_room`, M.O.D.-Zeilen nur live (L13-Wortprüfung), Overlay-Badge-Texte, Debug-Werkzeug |

**Verifier-Vertrag (beide Replays).** `RunSim.replay(data, log, rules = {}, quest = {}, ledger = [])` (Kern-Lauf, Server/Verifier)
und `Game.replay_log(log, until_tick = -1)` (kompletter Live-Lauf inkl. Show-Fassade) liefern
`{"final_hash", "result", "mismatch_at", "errors"}`. Ein Log gilt nur als bestätigt, wenn `mismatch_at == -1` **und** `errors`
leer ist. `errors` sammelt: `RunLog.validate()` und abgelehnte Log-Einträge; Header-Fehler von Katalog-Events
(`RunSim.header_errors`: nicht der feste Seed des Events, Schwierigkeit ≠ `prime`, Liga nicht in `rules.leagues`); jeden Command,
den `RunRules.command_refusal` bzw. die Kampfprüfung (`BattleState.validate`) ablehnt; jedes Geschenk, das die Kernprüfung
ablehnt (`GiftPolicy.refusal`, u. a. `wrong_target`, `too_soon`, Fenster); bei `RunSim.replay` mit `ledger` zusätzlich den
Abgleich mit dem Geschenk-Ledger (eingeschleust, fehlend, nach `deliver_by_tick`). Der Full-Run-Bot bricht bei nicht leerem
`errors` ab (02_TECH §11.4.1).

### 11.5 Definition of Done (Slice-Anteil SHOWRUN)

- Alle Tests aus 11.4 grün in `tools/check.sh`; bestehende Modultests (02_TECH §11.5) bleiben grün.
- Exit-Kriterien S0 (Kap. 2) erfüllt.
- Autoplay (02_TECH §11.4) unverändert grün; optionaler zusätzlicher Autoplay-Schritt `event_run` erst nach Integration.
- Keine Echtgeld-, Netzwerk- oder Account-Funktion im Slice.

### 11.6 Änderungsanträge an `02_TECH.md`

| CR | Betrifft (Besitzer) | Änderung | Grund |
|---|---|---|---|
| CR-1 | `autoload/events.gd` (M0) | Signale aus 11.3 ergänzen | Quest-HUD, Ergebnis, Gift-Darstellung |
| CR-2 | `core/battle/battle_state.gd` (M1) | (a) vor jeder Aktion `rng.seed = SeedUtil.derive(setup.seed, "action", action_n)`; `var action_n: int`; optional `func set_action_seed_source(c: Callable)` für S4 · (b) `func apply_gift(g: Dictionary) -> Array[ActionEvent]` (`sponsor_buff` → bisheriges `apply_sponsor_gift`, `gold` → neues `ActionEvent.Type.CREDITS_GAINED` (`value` = Betrag), `chest`/`fan_pack` → `ITEM_GAINED` je Item-Inhalt bzw. `CREDITS_GAINED` je Credits-Inhalt; erst nach Kampfende übernommen über `item_delta` bzw. neues **`BattleResult.credits_delta: int`**) | Vorhersage-Schutz online (Kap. 3.4), ein Geschenkweg; Credits im Kampf sind heute nicht abbildbar |
| CR-3 | `core/progression/floor_run.gd` (M2), `autoload/game.gd` (M0) | **Umgesetzt.** `time_left` als **ganze Ticks** (`FloorRun.time_left_ticks: int`, 1 Tick = 1/30 s, Kap. 3.2); `FloorRun.tick_timer(n, warnings)` zieht ab (aufgerufen von `RunSim.step`); `Game._process` akkumuliert nur Frame-`delta` in ganze Ticks; Warnungen/Expire in Ticks; Millisekunden nur für die Anzeige | Eine Simulationsuhr; Replay-Gleichheit des Timers |
| CR-4 | `autoload/game.gd` (M0) | **Umgesetzt.** API aus 11.3; Aufzeichnung an den bestehenden Stellen (`make_battle_setup` → `encounter`, `open_lootbox`, Shop, Ausrüsten, Ruhe, `complete_floor` → `descend`); Quest-Adapter (Signale/`ActionEvent`-KOs → Quest-Events) | Brief 6b.3 (Run-Log), 6b.5 (Quest) |
| CR-5 | `autoload/show.gd` (M2), `core/show/show_model.gd` (M2) | **Umgesetzt.** `receive_gift`, `take_pending_gift` (ersetzt `take_sponsor_gift`), RNG-Trennung `_rng`/`_fx_rng`; die spielrelevante Zeitregel der Erkundung ist die Hype-Abkühlung `ShowModel.decay_step(hype)` (alle `ShowModel.HYPE_DECAY_TICKS` Ticks 10 % des Überschusses über `HYPE_EXPLORE_FLOOR` 25, mind. 1), aufgerufen von `RunSim.step`; Zuschauer leitet `ShowModel.viewers_for` ohne eigenen Zustand aus Hype/Followern ab (kein `viewers_target`, keine Drift-Funktion); `Show._process` nur noch Anzeige | Brief 6b.4; Determinismus (Chat-Zeilen dürfen den Sponsor-RNG nicht verschieben) |
| CR-6 | neu `core/live/run_sim.gd` (M8), `autoload/game.gd` + `autoload/show.gd` (M0/M2) — **dünne Variante im Slice** | **Umgesetzt.** `RunSim` (RefCounted) hält `GameState`, `step(n) -> Array[ExploreEvent]` tickt alle zeitabhängigen Regeln (`FloorRun.tick_timer`, Pazifist-Sekunden, `ShowModel.decay_step`, Streuner, Sponsor-Fenster), `apply(cmd) -> Array[ExploreEvent]` nimmt Commands an (gemeinsame Regeln in `RunRules`); `Game`/`Show` sind Fassaden. Voller Server-Ausbau (mehrere Instanzen, Netzwerkquelle) S1/S4 | Brief 6b („ohne Umbau“), Kap. 3.2; `test_m8_replay` ohne Autoloads |
| CR-7 | `scenes/battle/battle_controller.gd` (M5) | Commands aufzeichnen; `take_pending_gift` + `apply_gift` statt `take_sponsor_gift` + `apply_sponsor_gift` | Run-Log, ein Geschenkweg |
| CR-8 | `autoload/save.gd` (M2) | Bestenlisten-/Replay-Dateien (11.3) | lokale Bestenliste S0 |
| CR-9 | `core/data/data_validator.gd` (M0), `data/` (M7) | neue `mod_lines`-Tags als optional; `events.json` außerhalb von `GameData` (eigener Loader `EventCatalog`) | die 13 Tabellen aus `GameData.TABLES` bleiben stabil |
| CR-10 | `scenes/title/title.gd`, neue UI-Szenen (M6) | Menüeintrag + `event_lobby`, `run_result`, Quest-Zeile im HUD | Einstieg S0 |
| CR-11 | `core/progression/floor_run.gd` (M2), `Game.open_chest` (M0), `RunSim` (M8), `core/data/seed_util.gd`-Doku (M0) | **Umgesetzt** (prozedurale Holztruhen-Inhalte noch aus dem Layout-Seed, Kap. 3.3 Nr. 2). Neues Feld **`FloorRun.loot_seed: int`** (≠ `seed`); Truhen würfeln mit `SeedUtil.derive(floor_run.loot_seed, "chest", k)` statt `floor_run.seed`; offline `loot_seed = SeedUtil.derive(run_seed, "loot", floor)`, online vom Server (geheim, Ergebnis per `ev chest_opened{contents}`); Doku-Hinweis in §4.6: `SeedUtil` ist 31-Bit und gilt als öffentlich | Vorhersage-Schutz (Kap. 3.3 Nr. 1–2): Layout-Seed verrät sonst jeden Truheninhalt |
| CR-12 | `core/battle/damage_calc.gd`, `core/battle/ctb_queue.gd` bzw. `battle_state.gd` (M1), `core/progression/progression.gd` (M2), `DungeonGenerator`/`FloorEvent` (M3), `data/` (M7) | Nur Ganzzahl-Zufall/-Arithmetik in spielrelevanten Pfaden: Varianz `randi_range(900, 1100)` ‰ (GDD 0.9–1.1), CTB-Start `base_delay × randi_range(500, 1000)` ‰ (GDD 0.5–1.0), Truhen-Offsets in cm-`int`, Event-Chancen in Basispunkten, EXP-Kurve als Tabelle statt `pow`; Lint-Erweiterung (Kap. 3.3 Nr. 5, 11.4) — **umgesetzt**, `test_m8_no_global_rng` ohne Ausnahmen | Plattformübergreifender Determinismus (ARM64/FMA, libm) |
| CR-13 | `core/show/stat_ids.gd` (M2), `core/data/data_validator.gd` (M0) | Neue `StatIds`: `viewers_target_peak` (Max, aus rauschfreiem `ShowModel.viewers_for`), `followers_gained_run` (Summe), `hype_100_count` (Zähler) — **integriert** (02_TECH §6.3: Show pflegt sie vor dem jeweiligen Signal; §3.4: der Quest-Adapter in `Game` sendet daraus `{"type": "metric", …}`) | Deterministische Quest-Metriken (Kap. 1.3) |
| CR-14 | `core/battle/battle_state.gd`, `combatant.gd`, `ctb_queue.gd`, `status_effect.gd` (M1), `core/live/state_hash.gd` (M8) | `to_dict()`/`from_dict()` für `BattleState` inkl. CTB-Zähler, Status, `items`, `action_n`, RNG-`state` (und für `Combatant`, `CTBQueue`, `StatusEffect`); `StateHash.of_battle`; Test `test_m1_battle_snapshot` (Snapshot → `from_dict` → gleicher Hash, Weiterspielen identisch) | Lockstep-Hash, Resync/Reconnect im Kampf (Kap. 3.4, 3.6) |
| CR-15 | neu `core/live/sponsor_windows.gd` (M8); `run_sim.gd`, `gift_policy.gd`, `gift.gd`, `command.gd`, `event_def.gd` (M8); `core/dungeon/explore_event.gd` (M3); `autoload/events.gd`, `game.gd` (M0), `show.gd` (M2); `scenes/ui/show_overlay.gd`, `debug_overlay.gd`, `scenes/safe_room/safe_room.gd` (M6); `scenes/boot/fullrun.gd`; `core/data/data_validator.gd` + `data/mod_lines.json` (M0/M7) | **Umgesetzt (2026-10-08).** Sponsor-Fenster nach Kap. 6.13: Fahrplan in Ticks (RunSim Schritt 5, Leerlauf-Ticks im Safe Room), Auslöser in den aufzeichnenden Game-Methoden, Prüfung zuletzt in `GiftPolicy.check`, Buchung in `note_applied`, Stempel `sponsor_window`, Command `sponsor_window`, `ExploreEvent.SPONSOR_WINDOW_OPENED/CLOSED`, drei Signale, Overlay-Badge, M.O.D.-Zeilen, Debug-Werkzeug; `Game.replay_log(p_log, until_tick)` für Replay-Prüfungen im Safe Room | Nutzerentscheidung 2026-10-08 (2), Server-Autorität |
| — | 02_TECH §1 / §11.5 | Modul **M8 „Live-Hooks“** mit Dateien aus 11.2 und Tests aus 11.4 aufnehmen | Ordnung der Zuständigkeiten |

---


## 12. Risiken & offene Fragen

### 12.1 Risiken

| # | Risiko | Wahrscheinl. | Auswirkung | Gegenmaßnahme |
|---|---|---|---|---|
| R1 | **Rechtslage** macht Echtgeld-Zufallskisten in wichtigen Märkten unzulässig oder teuer (Lizenzen, Altersprüfung) | mittel–hoch | hoch | Rechtsprüfung **vor** S3-Entwicklung der Bezahlteile; Architektur trennt `kind: chest` sauber → Fallback „nur nicht-zufällige Geschenke“ ohne Umbau |
| R2 | **Twitch** untersagt Zufallsinhalte bzw. Glücksspiel-ähnliche Stream-Inhalte oder Shop-Hinweise in der Extension; ~~Bits-Erlöse an die Broadcaster:in~~ — seit 2026-10-08 kein Bits-Geschenk mehr (L11) | mittel | mittel (B ist nur noch Reichweite) | frühe schriftliche Anfrage zur kostenlosen Extension und zu Shop-Hinweisen; ohne Freigabe Extension nur mit Votes/Applaus; Erlös kommt ausschließlich aus C |
| R3 | **Determinismus der Erkundung** zu teuer (Physik/Navigation aus der Szene in den Kern ziehen) | mittel | hoch (S1-Verifikation, Replays) | früh im Slice entscheiden (11.2 `ExploreSim`); Notlösung: Erkundung serverautoritativ ohne Replay-Verifikation, Replays mit Positionsproben |
| R4 | **Pay-to-win-Wahrnehmung** / Shitstorm („Gacha-Satire verkauft Gacha“) | mittel | hoch (Marke) | Pur-Liga als Standard, Odds/Fairness offen, abnehmende Wirkung, Satire-Ton der M.O.D. offen selbstironisch; Community-Beta |
| R5 | **Kollusion/Betrug**: gestohlene Zahlungsmittel für Geschenke an Freund:innen, Bestenlisten-Manipulation | mittel | mittel | Caps, Käufer-Limits, Kein-Selbstgeschenk-Prüfung, Chargeback-Sperren, Annullierung |
| R6 | **Ghosting** bei Parallel-Teams trotz Delay (Discord-Absprachen) | hoch | mittel | Fog-of-War im Zuschauerstrom (nur Besuchtes sichtbar), 30 s Delay, Symmetrie als Zusatz, Pur-Liga-Wertung als „offizielle“; akzeptiertes Restrisiko |
| R7 | **GDScript-Performance** auf dem Server unzureichend | niedrig–mittel | mittel (Kosten) | früh messen (S1-Verifier liefert Daten); Hotspots in C++-GDExtension auslagern, ohne Determinismus zu brechen |
| R8 | **Kostenexplosion** Zuschauer-Traffic bei viralen Events | niedrig | mittel | CDN-Segmente, Qualitätsstufen (Taktik-Ansicht), Zuschauer-Cap pro Lauf im WS-Pfad |
| R9 | **Betriebsaufwand** (Ledger, Zahlungen, Moderation, Support) übersteigt Team-Kapazität | hoch | hoch | MoR statt eigener Steuerabwicklung, Managed-Dienste wo möglich, Stufen erst nach Exit-Kriterien |
| R10 | **Datenschutz-Verstöße** (Gift-Logs, Twitch-IDs, IP-Geo) | niedrig–mittel | hoch | Datensparsamkeit, Pseudonymisierung, DSGVO-Prüfung (Kap. 9) |
| R11 | **Desyncs** zwischen Client-Kern und Server-Kern nach Updates | mittel | mittel | `sim_version`/`data_hash`-Pflicht, Checkpoint-Hashes, Archiv-Builds für alte Replays |
| R12 | **Plattform-Desyncs** (ARM64 vs. x86-64: FMA-Kontraktion, libm-Abweichungen, float32-`Vector*`) | mittel | hoch (Echtgeld, Koop) | Ganzzahl-/Festkomma-Kern (Kap. 3.3 Nr. 3/5, CR-12), Lint-Test, Plattform-Matrix mit arm64-Runner vor jedem `sim_version`-Bump |
| R13 | **Vorhersage/Leck** geheimer Seeds (31-Bit-`SeedUtil`, Insider mit `server_seed`) | mittel | hoch | Seed-Klassen online (Kap. 3.3 Nr. 2), HSM/KMS + Vier-Augen, Anomalie-Erkennung, offene Kommunikation (Kap. 7.7) |
| R14 | **Minderjährige** im Publikum und als Empfänger:innen; Kaufappelle durch Streamer:innen | hoch | hoch (Recht, Marke) | Kaufknöpfe nur 18+, Empfang bezahlter Kisten nur 18+, Creator-Richtlinien, neutrale M.O.D.-Zeilen (L6, L13); Streamer:innen ohne Erlösbeteiligung (L11) — weniger Anreiz zu Kaufappellen |
| R15 | **Sponsor-Fenster erzeugen Dringlichkeit** (Countdown + knappe Plätze ≈ künstliche Verknappung, Dark Pattern) | mittel | hoch (Recht, Marke) | L16 / Kap. 6.13: Countdown nur als Programminformation, im Kauf-Flow weder Countdown noch Knappheit (Platz reserviert), keine Push-/Chat-Aufrufe, M.O.D. ohne Kaufbezug, Fan-Pakete nutzen dieselben Fenster; Rechtsprüfung (Kap. 9 „Dringlichkeit“) |
| R16 | **Fenster frustrieren oder verraten zu viel**: Zuschauer:innen wollen außerhalb helfen (Abbrüche, Support), ein unverzögerter Fensterzustand verrät Fortschritt (Boss-Countdown = „steht vor dem Boss“) an Parallel-Teams | mittel | mittel | Overlay/Shop zeigen „Nächstes Fenster in …“; Fan-Pakete und Cheers als Wartezeit-Interaktion (Cheers jederzeit); `spec_window` unverzögert, aber ohne Art/Bezug (Kap. 4.6); Fensterwerte per `events.json` justierbar, in Playtests messen |

### 12.2 Offene Fragen / Entscheidungen

1. **Geschenk-Eingang (Brief 6b.4):** Vorschlag (Kap. 11.3, CR-5): **alle** Geschenke laufen durch
   `Show.receive_gift()`, auch die System-Geschenke der Hype-Schwellen (`take_pending_gift` → `receive_gift`); nur
   externe Geschenke werden geloggt, System-Geschenke sind aus dem Show-RNG reproduzierbar. **Bestätigen.**
2. **Erkundung im Kern (Kap. 3.3 Nr. 3):** Slice mit Grad A (Ergebnis-Commands, Bewegung in der Szene). **Festgelegt:** Grad B
   (Festkomma, Kap. 3.3) ist Voraussetzung für gewertete S1-Bestenlisten, S3 (Echtgeld) und S4. Offen bleibt nur der
   Zeitpunkt: Vorschlag = Benchmark-Prototyp im Slice (Verifier-Budget), Umsetzung vor S1-Wertung. → Entscheidung in `02_TECH.md`.
3. **Koop 3–4:** Welche zusätzlichen spielbaren Figuren? (Inhalt + Balancing; GDD-Erweiterung nötig.)
4. ~~**B oder C zuerst?**~~ — **entschieden 2026-10-08:** C (eigener Shop) ist der Echtgeld-Weg (S3 Web, S5 App-IAP), B nur
   kostenlose Interaktion (L11). Offen bleibt nur: Gibt es ein Bits-Erlösmodell für Entwickler, bei dem die Broadcaster:in nichts
   erhält **[zu prüfen]**? Ohne das kommt Bits nie für Geschenke in Frage.
5. **Echtgeld-Geschenke vor Dedicated Server?** Empfehlung: Server-Simulation für Solo bereits in S3 (Kap. 2). Zustimmung?
6. **[S3-Blocker] Empfang durch Minderjährige:** Dürfen Spieler:innen unter 18 überhaupt bezahlte Zufallskisten empfangen?
   Vorläufige Regel (Kap. 6.11, L6): **nein** — Show-Liga mit bezahlten Zufallskisten nur für altersverifizierte Spieler:innen
   ab 18, alle anderen fest `free_only`, **keine** Elternfreigabe, bis ein Gutachten etwas anderes sagt. Rechtlich klären.
7. **Pity-Zeitraum:** Festgelegt: **dauerhaft** ohne zeitlichen Reset (Kap. 6.8; ein Monats-Reset erzeugt Kaufdruck). Bestätigen.
8. **Preise & Limits:** Startwerte (Kap. 6.6, 6.10, 8.9) mit Markt-/Rechtsprüfung bestätigen.
9. **Live-Follower:** Separater Profilzähler, **nur aus Läufen ohne bezahlte Geschenke** (Kap. 1.6). Reicht das, oder ganz
   ohne Follower-Belohnung (maximale Trennung)?
10. **GDD Kap. 9 anpassen:** Querverweis auf Sponsorkisten (Kap. 0) und Live-Fußzeilentext ergänzen.
11. **Backend:** Nakama-Selbstbetrieb ab S1 (Empfehlung) oder Supabase-Schnellstart mit späterer Migration?
12. **Signaturen:** Festgelegt: HMAC-SHA256 mit Service-Schlüssel, **nur serverseitig** geprüft (Instanz, Verifier; Kap. 6.5).
    Offen nur, falls Clients je prüfen sollen: ECDSA P-256/RSA über `Crypto.verify` (EC in 4.7 **[zu prüfen]**), Ed25519 nur per GDExtension.
13. ~~**Zuschauer-Cheers gegen Bits**~~ — entfällt mit der Entscheidung 2026-10-08 (Cheers sind kostenlos, Kap. 6.3).
14. **Koop-Kämpfe:** Festgelegt: pro Team genau ein Kampf, alle werden hineingezogen (Kap. 1.4). Bestätigen; parallele Kämpfe
    nur als spätere Option mit Inventar-Escrow.
15. **`RunSim` im Slice (CR-6, dünne Variante):** Zustimmung von M0/M2 nötig, weil `Game`/`Show` zu Fassaden werden.
16. **Unzuverlässiger Kanal (ENet/WebRTC)** von Anfang an für Koop-Erkundung (Kap. 4.1): webrtc-native-GDExtension für 4.7
    verfügbar **[zu prüfen]**?
17. **Sponsor-Fenster — Feinabstimmung (Kap. 6.13):** Standardwerte (300 s / 60 s, Safe Room ≤ 90 s, Boss-Countdown 45 s,
    3 Plätze, 1 je Zuschauer:in, Gnadenfrist 15 s) per Playtest bestätigen. Offen: (a) Gelten die Fenster auch für kostenlose
    Fan-Pakete (umgesetzt: ja, nur `cheer` ist ausgenommen)? (b) Soll der Boss-Countdown bei erneutem Betreten eines Boss-Raums
    (Boss noch nicht besiegt) wieder öffnen (umgesetzt: nur beim Erstbesuch)? (c) `realtime`-Modus (S4): laufen Fenster im Kampf
    weiter? (d) Koop: Plätze je Spieler:in oder je Team? (e) Kampagne: Fenster nur als dezenter Hinweis (umgesetzt) oder dort
    ganz ausblenden, solange es keine echten Zuschauer gibt?
18. **Dringlichkeit (R15):** Reicht die Darstellung ohne Countdown im Kauf-Flow, oder soll auch das Overlay nur „offen/zu“
    ohne Sekunden zeigen? → mit der Rechtsprüfung klären.
