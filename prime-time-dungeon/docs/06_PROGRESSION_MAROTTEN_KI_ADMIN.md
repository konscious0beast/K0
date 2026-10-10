# PRIME TIME DUNGEON — Progression, M.O.D.-Marotten & KI-Admin

> Grundlage: Nutzervision vom **2026-10-10** (Wortlaut sinngemäß in Kap. 0.1; Freigabe: „nach bester Abwägung handeln, mit Blick auf
> eine möglichst gute User Experience, mit Spaß, Witz und Abwechslung, aber mit simplem, sofort verständlichem Spielkonzept“).
> Abgestimmt auf `00_BRIEF.md` (verbindlich), `01_GDD.md` (Progression Kap. 4, Show Kap. 7, Achievements Kap. 8, M.O.D. Kap. 11,
> Klassen Kap. 12, Balancing Kap. 13), `02_TECH.md` (Verträge, §3.4 Aufzeichnungsregel, §4 Daten, §13 Konventionen),
> `04_STRATEGIE_ROADMAP.md` (IP Kap. 2, Phasen Kap. 3) und `05_LIVE_MODUS.md` (Sponsor-Fenster Kap. 6.13, Votes/Twists Kap. 6.2).
>
> **Status:** Planungs- und Entscheidungsdokument für den nächsten Umsetzungsdurchgang (Pakete A–D, Kap. 8). Es **ergänzt**
> GDD/TECH/05; wo es ihnen widerspricht, gilt bis zur Einarbeitung dieses Dokument für die genannten Punkte (Liste Kap. 8.7).
> Der Brief bleibt vorrangig. **Rangfolge** (Vorrang-Klausel des Briefs, 2026-10-10): `00_BRIEF` > `07_ECHTZEITKAMPF` (alles
> Kampfrelevante) > **`06`** (neue Systeme) > `01_GDD` / `02_TECH` / `03_ART` / `05` (je nach Thema) > `04`.
>
> Konventionen: Prosa Deutsch; IDs, Pfade, JSON-Keys, Signal-/Methodennamen Englisch. **[zu prüfen]** = reale Fakten (Preise,
> Plattformregeln, Recht), vor einer Entscheidung zu verifizieren. Alle Zahlen sind **Startwerte** für Simulation und Playtests.

---

## Inhalt

0. Kurzfassung & Leitlinien
1. Spielfigur wählen (Kai oder Graf Mopsula)
2. Charakterentwicklung (Stats, Talente, Fähigkeiten, Gilden, Gruppen, Bosse, Erkunden)
3. Ab Etage 3: Spezies & erste Spezialisierung
4. M.O.D.-Marotten & Show-Wetten (inkl. Unterhosen-Liga)
5. KI-Admin „M.O.D. live“
6. Entscheidungen zu den fünf offenen Sponsor-Fenster-Fragen
7. WoW-Perspektive
8. Umsetzung JETZT: Pakete A–D
9. Risiken & offene Punkte

---

## 0. Kurzfassung & Leitlinien

### 0.1 Die Vision in 12 Sätzen

1. Man startet **immer als Duo** — **Kai** (Mensch, Tierpfleger:in, Wischmopp) und **Graf Mopsula** (sprechender Mops, Magier) —
   und wählt beim neuen Spiel, **wen man steuert**. Der/die andere folgt in der Erkundung; im Kampf befehligt man standardmäßig
   beide; wer mag, schaltet in den Optionen „Partner automatisch“ ein.
2. Jede Figur hat eine eigene **Feldfähigkeit**: Kai schlägt (Präventivschlag), Mopsula **bellt** (Gegner erschrecken, vorbeischleichen).
   Beides öffnet außerdem rissige **Kulissenwände** (Geheimnisse, Abkürzungen).
3. Ab **Level 3** gibt es auf jedem zweiten Level ein **Talent** (1 von 2) — gesammelt gewählt in der **Talent-Show** im Safe Room,
   nie als Unterbrechung nach dem Kampf. Talente sind klein, lesbar, witzig und oft **Verhaltens**-Boni („Bellen in Stereo: +25 % Reichweite“).
4. **Ab Etage 3** findet im Safe Room das **Casting** statt: Spezies wählen (4 für Kai, 3 für Mopsula, oder „Original bleiben“) und
   die erste **Spezialisierung** (die vorhandenen 4 Klassen je Figur). Ab hier wird das Spiel deutlich vielfältiger.
5. Ab Etage 2 kommen **Fanclubs** (Gilden in der Spielwelt), eine **3. Begleitfigur**, mehr **Show-Bosse** und **Geheimnisse**; eine
   kleine Kostprobe (Kulissenwände, Regie-Notizen, ein goldgerahmter Show-Boss) liegt schon auf Etage 1.
6. M.O.D. hat **Marotten**: Pro Etage verkündet sie 1–2 **Vorlieben** („M.O.D. mag heute: Nur der Mopp“). Wer sie bedient,
   bekommt Hype, Follower und ein Fanpost-Paket — **nie Pflicht, nie Strafe**.
7. Immer verfügbar ist die **Unterhosen-Liga** (Arbeitstitel): Regeltext **„ohne Rüstung & ohne Accessoire“** — schwerer, aber vom
   Publikum geliebt. Stufe 2 **„Duo-Liga“** (beide Figuren) ist die ultimative Spielweise mit eigener Achievement-Kette.
8. **KI-generierte Kommentare sind machbar** — als serverseitiger Dienst „mod-brain“ mit Claude, ohne API-Schlüssel im Spiel,
   mit Sicherheitsfilter, Kostendeckel und Skript-Fallback. Dass M.O.D. das Spiel **leicht verändert**, erlebt jede:r ab Etage 2
   über die **Regie** — offline, aus dem Seed, mit geschriebenen Zeilen; die KI ersetzt später nur Auswahl und Sprüche. Eingriffe
   kommen immer aus einem **festen Katalog** begrenzter **Twists**, die der deterministische Kern prüft und aufzeichnet.
9. Die KI ist **Farbkommentar**, nicht Story: Story-Beats, Regeln und Tutorials bleiben geschriebene Zeilen (zuverlässig, geprüft).
10. **Politisches bleibt draußen**: NOVA bleibt ein gesichtsloser Medienkonzern; die Satire zielt auf TV, Werbung und Bürokratie,
    nie auf reale Politik, Parteien oder Personen.
11. Die offenen **Sponsor-Fenster-Fragen** sind entschieden (Kap. 6): kein Sekunden-Countdown im Overlay, Fan-Pakete
    fensterpflichtig, Boss-Countdown öffnet nach einer Niederlage einmal neu, Plätze je Spieler:in im Koop, Twitch nur kostenlos.
12. Die Systeme sind so gebaut, dass später ein **WoW-artiger Ausbau** (Hub, Spielergilden, Raids, Staffeln, Berufe) auf unserer
    eigenen Geschichte möglich ist — ohne den Slice heute damit zu belasten.

### 0.2 Leitlinien (gelten für jedes neue System)

| # | Leitlinie | Konkret |
|---|---|---|
| L-1 | **In einem Satz erklärbar** | Jedes System hat eine Ein-Satz-Erklärung (Tabelle 0.5), die M.O.D. beim ersten Auftreten in ≤ 2 HUD-Zeilen sagt. Was nicht in einen Satz passt, wird vereinfacht oder verschoben. |
| L-2 | **Eine neue Regel pro Etage** | Progressive Einführung (Tabelle 0.6). Etage 1 bleibt der Lernraum: Kampf, Show **plus genau drei Neuheiten** — Figurenwahl, Bellen, **eine** Vorliebe. Alles andere ist entweder Option ohne Tutorial-Zeile, optionale Entdeckung ohne neue Regel, oder kommt erst am Etagenende. Der Code erzwingt den Fahrplan, wo es um Regeln geht (`min_floor` für Twists, Marotten, Fanclubs). |
| L-3 | **Witz mit Ziel** | Spott trifft Konzern, Show-Maschinerie, Bürokratie („§ 3 Kleiderordnung“) — nie Spieler:innen, Zuschauer:innen oder Körper. Unterhosen-Humor = Slapstick und Paragrafen, **nicht** sexuell, kein Bodyshaming. |
| L-4 | **Abwechslung wird belohnt, nie erzwungen** | Marotten, Liga, Talente belohnen verschiedene Spielweisen. Wer sie ignoriert, verliert nichts. |
| L-5 | **Fair by design** | Nichts davon ist kaufbar. Zuschauer-Hilfe nur in Sponsor-Fenstern (Brief Kap. 5). KI-Twists nur aus Whitelist, mit Fairness-Budget. |
| L-6 | **Deterministischer Kern** | Alles, was Spielzustand ändert, ist ein aufgezeichnetes Command (`Game.record`), `Game.replay_log` bleibt äquivalent; Zufall nur über `SeedUtil`, Ganzzahl-/Promille-Arithmetik im Kern (02_TECH §13, 05 Kap. 3.3). |
| L-7 | **Politik raus** | Keine realen Parteien, Politiker:innen, Wahlen, Kriege, Ideologien — weder in geschriebenen Zeilen noch in KI-Ausgaben (Filter Kap. 5.9). Leichte Konzern-/TV-Satire bleibt (Markenkern, 04 Kap. 1.4). |

### 0.3 IP-Hinweis (freundlich, aber verbindlich)

Du hast in deiner Nachricht **„Carl & Donut“** geschrieben — das sind die Hauptfiguren aus *Dungeon Crawler Carl*. Die übernehmen
wir **nicht**: Figuren, Namen, Biografien und Running Gags sind geschützt bzw. machen uns erkennbar zum Abklatsch (Brief Kap. 1,
04 Kap. 2.2). **Unser Duo ist Kai & Graf Mopsula** — und die *Mechanik* „man startet als Duo und wählt, wen man steuert“ ist frei
und wird umgesetzt (Kap. 1).

Zwei weitere Wünsche sind ebenfalls DCC-Erkennungsmerkmale und werden deshalb **in eigener Form** umgesetzt:

| Wunsch | DCC-Element | Unsere eigene Umsetzung |
|---|---|---|
| „Carls Strategie: barfuß und ohne Hose“ | Charakterzug und Erkennungsbild der DCC-Hauptfigur | **Unterhosen-Liga** (Arbeitstitel, Kap. 4.3): eine **optionale Challenge-Kategorie** der Show (wie Speedrun-Kategorien), für **jede** gesteuerte Figur, eingeführt als M.O.D.-Wette mit Paragrafen-Humor. Spielerseitig heißt die Regel immer **„ohne Rüstung & ohne Accessoire“** — **keine** Fuß-/Barfuß-Bezüge in Namen, Zeilen, Rigs oder Achievements. Kai ist **nicht** „die Figur ohne Hose“ — es ist eine Spielweise, kein Wesenszug. |
| „Die KI hat Fetische“ | Die DCC-System-KI hat eine bekannte Fuß-Vorliebe | **Keine** Fuß-Vorliebe, nichts Sexuelles. Unsere M.O.D. hat wechselnde, harmlose **Marotten/Vorlieben** (Wischmopps, Stil, Ruhe, Second-Hand …), Kap. 4. |

**Distanz-Review (04 Kap. 2.3):** „Unterhosen-Liga“ kommt als zusätzliche Zeile in die Prüfliste. **Nähe: hoch** — die
Kombination aus Erkennungsbild der DCC-Hauptfigur (barfuß, Boxershorts), einer KI-Moderation, die genau das belohnt, und einer
Belohnungs-Box liegt nah am Original. Die **Mechanik bleibt** (sie ist frei und vom Nutzer gewünscht), die Rahmung wird verbindlich:

1. Spielerseitiger Regeltext überall **„ohne Rüstung & ohne Accessoire“** (HUD, Menüs, Zeilen, Store-Texte).
2. **Keine Fuß-/Barfuß-Bezüge** in Namen, Zeilen, Rigs, Achievements (kein „barfuß-Rig“, kein „Kalte Füße“, kein „ohne Schuhe“).
3. **Keine Liga-Optik von Kai** in Key Art, Trailer, Store-Seite oder Kapsel-Bildern; Marketing zeigt höchstens den HUD-Chip.
4. Belohnungstexte in neuem Inhalt sagen **„Fanpost-Paket“** (04 Kap. 2.3/E2; ID `box_fan` bleibt), nie „Fan-Box“.
5. Kein Liga-Fanclub (der frühere „Club der Kurzen Hosen“ entfällt, Kap. 2.4).
6. Name „Unterhosen-Liga“ ist **Arbeitstitel**; Entscheidung im Distanz-Review (Exit Phase 2). Ersatzname „Leichtgepäck-Liga“
   liegt bereit — Umbenennung ist reine Textänderung, die IDs `mar_unterhose`/`liga_*` sind neutral.

Ebenfalls in die Prüfliste: die **Mopsula-Talentnamen** (Kap. 2.2) — Maßstab 04 Kap. 2.3 („Tierheim-Biografie, keine Show-/
Wettbewerbs-Vergangenheit“): keine Zuchtbuch-, Stammbaum-, Hofknicks-, „Blaues Blut“- oder Publikumsliebling-Motive.

### 0.4 WoW-Perspektive in einem Absatz

Ziel ist **„MMO-lite auf eigener Geschichte“** als *Option* nach 1.0 — nicht im Slice. Alles in diesem Dokument ist so geschnitten,
dass es dorthin wachsen kann: Spezies + Spezialisierung + Talente ergeben Rollen (Tank/Heiler/Schaden), Fanclubs werden später
Spielergilden, Bosse werden zu Raids („Großproduktionen“) mehrerer Teams, Etagen-Staffeln zu Seasons, Safe Rooms zur Hub-Stadt
„Senderzentrale“. Der deterministische Kern, Commands, Run-Log und Server-Autorität (05) sind die technische Grundlage. Details Kap. 7.

### 0.5 Ein-Satz-Erklärungen (UX-Vertrag)

| System | Ein Satz (so sagt es M.O.D. beim ersten Mal, sinngemäß) | Erstes Auftreten |
|---|---|---|
| Figurenwahl | „Wen steuern Sie? Der/die andere kommt mit — ob er/sie will oder nicht.“ | Neues Spiel |
| Feldfähigkeit | „Kai haut zu, der Graf bellt. Beides beeindruckt Monster.“ | Tutorial (B1) |
| Partner automatisch | (keine Tutorial-Zeile; Hilfetext im Optionsmenü: „Ihr Partner kämpft von selbst.“) | nur Optionen |
| Talent-Show | „Talent-Show! Wählen Sie je Figur eines von zwei Talenten. Das andere bekommt jemand anderes. Nie.“ | E1, Safe Room 2 (erste offene Wahl ab L3) |
| Vorlieben (Marotten) | „Ich mag heute etwas Bestimmtes. Tun Sie es, und ich mag Sie.“ | nach dem Tutorial-Kampf (E1) |
| Unterhosen-Liga | „Ohne Rüstung & ohne Accessoire: schwerer, aber das Publikum liebt Mut.“ | Etagen-Bilanz E1 (Hinweis, einmalig) |
| Fanclubs | „Treten Sie einem Fanclub bei. Fans geben Aufgaben, Fans geben Boni.“ | E2, 1. Safe Room |
| Regie-Twists | „Die Regie greift ein. Kurz, begrenzt, meistens zu Ihren Gunsten.“ | E2 (Regie, skriptiert); KI nur bei „M.O.D. live“ |
| Casting | „Wer wollen Sie sein? Und was wollen Sie können? Die Jury bin ich.“ | E3, 1. Safe Room |

### 0.6 Einführungsfahrplan (eine neue Regel pro Etage)

| Etage | Neue Regel(n) | Zum Entdecken (keine neue Regel, kein Tutorial) | Am Etagenende | Bleibt bewusst weg |
|---|---|---|---|---|
| 1 | Figurenwahl, Bellen, **1** Vorliebe | 1–2 Kulissenwände, 3 Regie-Notizen, 1 goldgerahmter Show-Boss (optional) | Talent-Show (ab SR2, sobald L3 erreicht), Liga-Hinweis in der Etagen-Bilanz | Gilden, Spezies, Twists, Partner-Tutorial |
| 2 | **2** Vorlieben, Fanclubs, **Regie-Twists** (skriptiert) | 3. Begleitfigur (rekrutierbar), mehr Kulissenwände, Sammelkarten | — | Spezies |
| 3 | **Casting**: Spezies + Spezialisierung; Level-Cap steigt | — | — | — |
| 4+ | Show-Bosse mit eigenen Regeln, Fanclub-Ränge 3–5 | Sammelkarten-Album | — | — |

**HUD-Budget E1:** Zu Hype, Followern, Timer, Sponsor-Badge kommt genau **ein** neuer kompakter **Show-Chip** (Vorliebe + Herzen,
bei aktiver Liga mit Liga-Stufe; Kap. 4.7). Keine weiteren neuen HUD-Zeilen auf E1.

---

## 1. Spielfigur wählen (Kai oder Graf Mopsula)

### 1.1 Ablauf „Neues Spiel“ (ersetzt GDD §14.2 Schritt 2)

1. Slot wählen (unverändert).
2. **Figurenwahl** (neu, `scenes/title/hero_select.tscn`): zwei große Karten nebeneinander, erste hat Fokus.
   - **Kai** — „Tierpfleger:in. Wischmopp. Haut zu.“ · Feld: *Feldschlag* · Rolle: Nahkampf/Tank
   - **Graf Mopsula** — „Mops. Magier. Schwer vermittelbar.“ · Feld: *Bellen* · Rolle: Magie/Heilung
   Unter jeder Karte eine animierte Vorschau (Rig im Idle) und eine Zeile „Du kannst im Safe Room jederzeit wechseln.“
3. Name eingeben — es ist **immer Kais Name** (Spielername, `{name}`). Hat man Mopsula gewählt, lautet die Überschrift
   „Wie heißt Unser:e Begleiter:in?“ (Mopsula-Stimme, Pluralis Majestatis) statt „Wie heißt du?“ — bewusst **keine**
   Haustier-befiehlt-Diener:in-Dynamik (04 Kap. 2.3).
4. Modus (Prime Time / Vorabendprogramm, unverändert) → Intro (B0) mit Zusatzzeile `hero_pick:<id>`.

### 1.2 Erkundung

| Regel | Wert |
|---|---|
| Gesteuerte Figur (`GameState.hero`) | `"kai"` (Standard) oder `"mopsula"` |
| Laufen / Schleichen / Beschleunigung | **identisch** für beide (5.5 / 2.5 m/s, GDD §2.1) — Timer-Balancing bleibt unverändert |
| Kollision | Kai `CapsuleShape3D` r 0.4 / h 1.7 m; Mopsula r 0.35 / h 0.9 m |
| Kamera | unverändert (Pivot 1.4 m über der Figur, GDD §2.2); keine neue Kamera-Abstimmung |
| Begleiter:in | die andere Figur folgt (heutiger `CompanionFollower`, verallgemeinert auf „Partner folgt Held:in“), Zielabstand 1.8 m, Teleport > 10 m |
| Interagieren | beide können alles (Truhen, Tore, Events, Treppe). Mopsula öffnet Truhen „mit der Schnauze“ (eigene Prompt-Texte, gleiche Regeln) |

### 1.3 Feldfähigkeiten (Aktion `action`, wenn kein Interactable im Prompt-Radius liegt)

| | **Kai: Feldschlag** (unverändert, GDD §2.1/§2.4) | **Mopsula: Bellen** (neu) |
|---|---|---|
| Form | Bogen 100°, 1.8 m, 0.45 s, Cooldown 0.6 s | Kegel **120°**, **4.0 m**, Dauer 0.4 s, Cooldown **3.0 s** (`EncounterRules.BARK_*`) |
| Wirkung | Treffer auf Symbol → **Kampf**, Präventivschlag nach GDD §2.4 | Symbole im Kegel mit Sichtlinie werden **„verdutzt“** (neuer Zustand `DAZED`, 2.5 s): stehen still, Sterne/„?!“, sehen und hören nichts. **Startet nie einen Kampf.** |
| Kontakt danach | — | Kontakt mit einem `DAZED`-Symbol = **Präventivschlag aus jeder Richtung** |
| Grenzen | — | Jede Gruppe höchstens 1× je 15 s verdutzbar (`DAZE_IMMUNE_SEC`), danach Rückkehr in den vorigen Zustand (bei Sichtkontakt `ALERT`). Bosse: keine Wirkung. Fahrscheinfresser: „zuckt nur“ (Prompt-Witz, keine Wirkung). |
| Spielweise | aggressiv: Kämpfe sauber eröffnen | trickreich: **vorbeischleichen** (Pazifismus, Kap. 4) oder Präventivschläge von vorn |
| Optik/Ton | Wischmopp-Bogen (vorhanden) | Feldschlag-Bogen-Mesh in Mopsula-Violett + 2 Schallwellen-Ringe; `Sfx` `bark` |

Bellen ist wie der Feldschlag **Szenenlogik (Grad A)**: aufgezeichnet wird nur das Ergebnis (`encounter {adv}`), nicht die Bewegung.

### 1.4 Kampf

- **Standard:** Man befehligt **beide** Figuren (wie heute). Das Party-Panel der gesteuerten Figur trägt einen Stern-Marker.
- **Option „Partner automatisch“** (`GameSettings.partner_auto`, nur im Optionsmenü, **ohne** Tutorial- oder M.O.D.-Zeile; Standard aus): Züge der **nicht** gesteuerten Figur
  wählt `AutoPolicy` (nie Stunt, nie Flucht, 02_TECH §5.8). Aufgezeichnet wie heute `{"t": "battle", "cmd", "auto": true}` →
  Replay unverändert deterministisch. Der bestehende Voll-Auto-Schalter (`toggle_auto`) bleibt und hat Vorrang.
- Koop (05 S4): „Partner automatisch“ ist genau der spätere Fall „die zweite Person fehlt“ — gleiche Regel.

### 1.5 Story & M.O.D. reagieren

| Moment | Tag (optional-Präfix `hero_`) | Beispiel (≤ 110 Zeichen) |
|---|---|---|
| Intro nach der Wahl | `hero_pick:kai` | „Kandidat:in {name} übernimmt. Der Graf assistiert. Unter Protest, aber in HD.“ |
| | `hero_pick:mopsula` | „Der Graf hat die Fernbedienung an sich genommen. {name} darf folgen. Die Quote jubelt.“ |
| Wechsel im Safe Room | `hero_switch:kai` | „Rollentausch! {name} führt wieder. Der Graf nennt es ‚wohlverdiente Siesta‘.“ |
| | `hero_switch:mopsula` | „Rollentausch! Der Graf führt. Bitte Abstand halten, er bellt in Stereo.“ |
| Bellen (Chat) | `chat_bark` | „WUFF IN HD“ · „der graf hat gesprochen“ · „ich hab mich auch erschrocken“ |

Die Mopsula-Szenen (GDD §10.2) bleiben unverändert — sie sind Dialoge zwischen beiden und funktionieren mit jeder Wahl.

### 1.6 Wechsel

Im **Safe-Room-Menü** neuer Eintrag **„Figur wechseln“** (zwischen „Ausrüstung“ und „Mopsula“). Wechsel nur im Safe Room
(Erkundung bleibt lesbar, kein Wechsel-Spam). Kosten: keine.

### 1.7 Daten & Determinismus

- `GameState.hero: String = "kai"` (in `to_dict`/`from_dict`, Default für alte Spielstände `"kai"` → kein Save-Versionssprung).
- Command `{"t": "hero", "id": "kai" | "mopsula"}` über `Game.set_hero(id)`; `Game.new_game(…, hero)` zeichnet die Wahl als
  erstes Command nach `floor` auf. Event-Läufe: Wahl in der Event-Lobby (optional, sonst `kai`).
- **Zwei Prüfungen, ein Command:** `HeroRules.check_initial(state, hero_id)` erlaubt die Wahl nur **vor** dem ersten
  Erkundungs-Tick und vor der ersten Begegnung des Laufs (Gründe `"" | "unknown_hero" | "run_started"`);
  `HeroRules.check_set` (Safe Room) gilt für jeden späteren Wechsel. Replay und Verifier wählen die Prüfung nach demselben
  Kriterium (Lauf schon gestartet?) → das Start-Command besteht die Prüfung im Replay identisch. Test: Replay eines Laufs, der
  als Mopsula beginnt, ergibt denselben Hash.
- `hero` fließt in den `StateHash` und in Marotten (Unterhosen-Liga bezieht sich auf die gesteuerte Figur, Kap. 4.3).

---

## 2. Charakterentwicklung

### 2.1 Überblick: Fortschritt auf mehreren Achsen

| Achse | Spielgefühl | Slice (jetzt) | Später |
|---|---|---|---|
| **Stats** (HP, MP, STR, MAG, DEF, RES, SPD, LCK) | sichtbar wachsen | wie GDD §4 | Level-Cap je Etage anheben (2.3) |
| **Talente** | jedes 2. Level eine Entscheidung | **Paket B**: 1 aus 2 ab L3, gesammelt in der Talent-Show; 12 je Figur (⅓ Verhaltens-Talente) | Talent-Reset, seltene Talente aus Show-Bossen |
| **Fähigkeiten** | neue Werkzeuge | Lernsets wie GDD §4.5/4.6 | Klassen-Skills L11–L17 (GDD §12) |
| **Ausrüstung** | Beute, Ausprobieren | 3 Slots wie GDD §6 | Tiers, Set-Boni, „Ramsch“-Seltenheit (graue Items à la WoW, M.O.D. liebt sie) |
| **Spezies + Spezialisierung** | Identität, Rolle | **Paket B**: Datenmodell + Regeln + Tests | Casting-UI auf Etage 3, Optik je Spezies (03_ART) |
| **Fanclubs (Gilden)** | Zugehörigkeit, Aufträge | — | ab Etage 2 (2.4) |
| **Gruppe** | „wir werden mehr“ | Duo | 3. Begleitfigur ab E2, Koop 2–4 (05 S4) |
| **Bosse** | Höhepunkte | 2 je Etage + **1 optionaler Show-Boss auf E1** (Paket C) | weitere Show-Bosse (Elite), Raids (Kap. 7) |
| **Erkunden** | Neugier lohnt sich | Truhen, Events + **E1-Kostprobe**: 1–2 Kulissenwände, 3 Regie-Notizen (Paket A) | mehr Geheimnisse, Sammelkarten, Wiederholungen (2.7) |
| **Show-Wetten** | Spielweise variieren | **Paket C** | Fanclub-Wetten, Saison-Wetten |

### 2.2 Talentwahl (Paket B)

**Regel in einem Satz:** Ab Level 3 verdient jede Figur auf jedem zweiten Level eine Talentwahl; in der **Talent-Show** im Safe
Room wählt man je offener Wahl **eines von zwei** Talenten.

| Regel | Wert |
|---|---|
| Wann | Level-ups auf **ungerade Level ab L3** (L3, L5, L7, L9 → im Slice mit Cap 10 **4 Wahlen je Figur**; spätere Caps setzen das fort: L11, L13 …) |
| Wo | **Talent-Show** im Safe-Room-Menü (ein Bildschirm, alle offenen Wahlen beider Figuren nacheinander). Erstes Auftreten auf E1 in **Safe Room 2** „Pumpenhaus“ (oder später, sobald L3 erreicht ist) — nie als Unterbrechung nach einem Kampf |
| Angebot | 2 verschiedene Talente aus dem Pool der Figur (`for` enthält die Figur, `min_level ≤ Level`, Rang < `max_rank`), gewichtet ohne Zurücklegen; Zufall `SeedUtil.derive(state.seed, "talent:" + member_id, level)` → **Neuladen ändert das Angebot nicht**, kein Angebot muss aufgezeichnet werden |
| Wahl | `Game.pick_talent(member_id, talent_id)` → Command `{"t": "talent", "member", "id"}`; gültig nur für das Angebot des ältesten offenen Levels und nur im Safe Room (`not_in_safe_room`) |
| Später wählen | erlaubt: offene Wahlen stehen in `PartyMember.talent_pending` (Level-Liste). Hinweis nur als kleiner Chip „Talent bereit“ in den Kampfergebnissen und als Badge „!“ am Safe-Room-Eintrag „Talent-Show“ bzw. im Pausemenü (Party). **Nichts blockiert den Spielfluss.** |
| Stapeln | Talente mit `max_rank` 2 können erneut angeboten werden (Rang +1) |
| Autoplay/Bot | wählt deterministisch das erste Angebot beim nächsten Safe-Room-Besuch (Full-Run-Bot, Kap. 8) |
| Umfang (Band) | Werte-Talente **+3–5 % je Rang** auf **eine** Größe (`max_rank` ≤ 2); Summe aller Talentboni je Kampfwert bis L10 **≤ +15 %** (Test in Paket B). Verhaltens-Talente ändern Feldfähigkeit, Stunt, Präventivschlag, Marotten oder Liga — keine reinen Zahlenbumps |

**Wirkungsarten** (`TALENT_KINDS`, alles Ganzzahl/Promille; im Slice nur diese, alle an **bestehenden** Stellen angewendet):

| `kind` | Felder | Angewendet in | Typ |
|---|---|---|---|
| `stat_flat` | `stat`, `value` (1..3) | `Progression.total_stats` | Wert |
| `stat_pct` | `stat`, `pm` (30..50) | `Progression.total_stats` (nach Ausrüstung, vor Klasse/Spezies) | Wert |
| `crit_add_pm` | `pm` (10..30) | `BattleBridge.make_setup` (Krit-Bonus des Combatants) | Wert |
| `element_pm` | `element`, `pm` (700..1000 = Schadensfaktor) | `BattleBridge.make_setup` (`element_mods`) | Wert |
| `post_battle_mp_pm` | `pm` (30..50) | `BattleBridge.apply_result` („Werbepause-Regeneration“ +x ‰ MaxMP) | Wert |
| `field_range_pm` | `pm` (1000..1500) | Feldschlag-/Bellen-Reichweite (`EncounterRules`, Szenenlogik Grad A — aufgezeichnet wird nur das Ergebnis) | Verhalten |
| `field_cd_pm` | `pm` (500..1000) | Feldfähigkeits-Cooldown (`EncounterRules`) | Verhalten |
| `preemptive_dmg_pm` | `pm` (1000..1200) | `BattleBridge.make_setup` (Schaden der ersten Runde nach Präventivschlag) | Verhalten |
| `stunt_window_pm` | `pm` (1000..1250) | Stunt-Zeitfenster (Stunt-Auswertung in `ActionResolver`, `STUNT_RESULT`) | Verhalten |
| `marotte_heart` | `per_floor` (1) | `MarottenRules` (Paket C): 1× je Etage ein Zusatz-Herz für die erste getroffene Vorliebe | Verhalten |
| `liga_stat_pct` | `stat`, `pm` (30..50) | `Progression.total_stats`, nur wenn `MarottenRules.liga_tier(state) ≥ 1` | Verhalten |
| `hype_gain_pm` / `follower_pm` | `pm` | `GameState.hype_gain_pm` / `follower_pm` (Promille-Produkt) — **im Slice-Pool nicht verwendet**, Vokabular für später | Wert |

**Pool Kai (12)** — `tal_kai_*` (8 Werte, 4 Verhalten):

| ID | Name | Wirkung | `max_rank` |
|---|---|---|---|
| `tal_kai_wischtechnik` | Wischtechnik | STR +1 | 2 |
| `tal_kai_dicke_haut` | Dicke Haut (tierheimgeprüft) | DEF +1 | 2 |
| `tal_kai_nachtschicht` | Nachtschicht-Kondition | HP +5 % | 2 |
| `tal_kai_hausverstand` | Hausverstand | RES +1 | 1 |
| `tal_kai_glueckspfote` | Glückspfote | LCK +1 und Krit +2 % | 1 |
| `tal_kai_fester_griff` | Fester Griff | Krit +3 % | 2 |
| `tal_kai_bissfest` | Bissfest | Gift-Schaden ×0.75 | 1 |
| `tal_kai_kaffee` | Automatenkaffee | +5 % MaxMP nach jedem Kampf | 2 |
| `tal_kai_weit_ausholen` | Weit ausholen | Feldschlag-Reichweite +25 % (öffnet Kulissenwände aus sicherer Distanz) | 1 |
| `tal_kai_erster_eindruck` | Erster Eindruck | Präventivschlag: Schaden der ersten Runde +15 % | 1 |
| `tal_kai_kamera3` | Kamera 3 kennt mich | 1× je Etage: +1 Herz für die erste getroffene Vorliebe | 1 |
| `tal_kai_liga_routine` | Liga-Routine | in der Liga: DEF +5 % („Ohne Rüstung & ohne Accessoire? Routine. …“) | 1 |

**Pool Mopsula (12)** — `tal_mop_*` (8 Werte, 4 Verhalten; Motive aus **unserem** Kanon: Tierheim, Mops-Alltag,
Grafen-/Vampir-Manieren, Fehde mit der Rattenkönigin — **keine** Majestäts-/Königs-Motive, Orchestrator-Entscheidung
2026-10-10, Validator `MOPSULA_FORBIDDEN_WORDS`):

| ID | Name | Wirkung | `max_rank` |
|---|---|---|---|
| `tal_mop_mitternachtsformel` | Mitternachtsformel („Um Mitternacht gelernt, nie vergessen.“) | MAG +1 | 2 |
| `tal_mop_koerbchen` | Körbchen-Nickerchen | +5 % MaxMP nach jedem Kampf | 2 |
| `tal_mop_hoher_kragen` | Hoher Kragen | RES +1 | 2 |
| `tal_mop_leberwurst` | Leberwurst-Diät | HP +5 % | 2 |
| `tal_mop_monokel` | Monokel-Fokus | SPD +1 (selten: `weight` 1) | 1 |
| `tal_mop_zwinger7` | Zwinger 7 überlebt | LCK +2 | 1 |
| `tal_mop_nachtaktiv` | Nachtaktiv | MP +5 % | 2 |
| `tal_mop_unterpelz` | Doppelter Unterpelz | Eis-Schaden ×0.75 | 1 |
| `tal_mop_stereo` | Bellen in Stereo | Bellen-Reichweite +25 % | 1 |
| `tal_mop_schwer_vermittelbar` | Schwer vermittelbar | Bellen-Cooldown −30 % („lässt sich nicht abwimmeln“) | 1 |
| `tal_mop_taktgefuehl` | Taktgefühl | Stunt-Erfolgschance ×1.2 (vor Boss-Abzug und Obergrenze) | 1 |
| `tal_mop_liga_gelassen` | Liga-Gelassenheit | in der Liga: RES +5 % („Ohne Rüstung & ohne Accessoire bleibt der Graf gelassen …“) | 1 |

> **Stand Paket B (umgesetzt, `data/talents.json`):** Die Tabellen oben sind die gebauten Werte. Gegenüber dem Entwurf kleiner
> (STR/MAG +1 statt +2, DEF/RES/LCK als flache Punkte, Mopsulas Tempo-Talent selten und `max_rank` 1), damit das Band „≤ +15 %
> je Kampfwert bei L10“ für **jede** Wahlfolge hält und die Boss-Quoten im ±5-Punkte-Band bleiben (Messung Kap. 8.3).
> Alle Talente haben `weight` 2, nur Monokel-Fokus 1. **IP-Distanz (Orchestrator-Entscheidung 2026-10-10, verbindlich):**
> Spielen ohne Rüstung ist eine **Spielweise**, nie ein Wesenszug; keine Majestäts-Motive für Mopsula. Deshalb umbenannt
> (Wirkungen unverändert): `tal_kai_abgehaertet` → `tal_kai_liga_routine`, `tal_mop_wuerde` → `tal_mop_liga_gelassen`,
> `tal_mop_pluralis` → `tal_mop_mitternachtsformel`, `tal_mop_schnarchen` → `tal_mop_koerbchen`,
> `tal_mop_dramatische_pause` → `tal_mop_taktgefuehl`; Kartentexte bis 90 Zeichen (zwei Zeilen).

**UI „Talent-Show“** (`scenes/ui/talent_show.tscn`, aufgerufen aus dem Safe-Room-Menü): je offene Wahl zwei Karten (Name, ein
Satz, Zahl grün bzw. Verhaltens-Icon, Icon nach `kind`) + „Später“; nach der letzten Wahl zurück ins Safe-Room-Menü.
Fokus-navigierbar, Touch-Trefferflächen ≥ 88 px (02_TECH §10). M.O.D.-Tag `talent_show_open` beim ersten Mal (Ein-Satz-Erklärung,
Tabelle 0.5), danach `talent_pick` („Neues Talent! Die Regie nennt es Entwicklung. Ich nenne es: mehr Material.“), Variante
`talent_pick:mopsula` („Der Graf lernt dazu. Er bestreitet, dass es etwas zu lernen gab.“).

**Schema `talents.json` (`TalentDef`, Präfix `tal_`):**

```json
{"schema": 1, "entries": [
 {"id": "tal_mop_stereo", "name": "Bellen in Stereo", "desc": "Das Bellen reicht ein Viertel weiter.",
  "for": ["mopsula"], "max_rank": 1, "weight": 2, "min_level": 3, "icon": "field",
  "effects": [{"kind": "field_range_pm", "pm": 1250}]}
]}
```

Felder: `id` ✓, `name` ✓, `desc` (≤ 60 Zeichen, eine Kartenzeile), `for` ✓ (Party-IDs), `max_rank` 1..2 (1), `weight` 1..10 (1),
`min_level` 3..99 (3), `icon` ∈ `TALENT_ICONS` (`hp`, `mp`, `atk`, `mag`, `def`, `res`, `spd`, `lck`, `crit`, `element`, `show`,
`field`, `stunt`, `liga`), `effects` ✓ (1..3 Einträge, `kind` ∈ `TALENT_KINDS`, Felder und Bereiche je Art wie oben, alle Ganzzahlen).

### 2.3 Fähigkeiten, Ausrüstung, Level-Cap

- Fähigkeiten bleiben **lernset-basiert** (lesbar: „mit Level 6 lernst du X“). Klassen bringen ab L11 je 4 Skills (GDD §12).
- **Level-Cap je Etage** (Vorschlag, mit Etage 3 festzurren): E1–2: 10 · E3: 13 · E4: 15 · E5: 17 · E6: 20 (Staffelfinale).
  Das hält die EXP-Kurve (GDD §4.3) je Etage lesbar und gibt jeder Etage Level-ups für die Talentwahl.
- Ausrüstung später: Tiers je Etage, **Set-Boni** (2 Teile eines Sponsors), **„Ramsch“** als vierte Seltenheit (grau, nur zum
  Verkaufen — und für die Marotte „Second-Hand-Schick“).

### 2.4 Fanclubs (Gilden in der Spielwelt) — ab Etage 2, nicht im Slice

**Ein Satz:** Im ersten Safe Room von Etage 2 tritt man **einem** Fanclub bei; er stellt pro Etage drei Aufträge und gibt Ränge mit
kleinen Boni.

| ID | Fanclub | Thema/Witz | Rang-Bonus (Beispiel) | Typische Aufträge |
|---|---|---|---|---|
| `gld_flohmarkt` | **Flohmarkt-Freundeskreis** | Fans von M.O.D.s Launen, Ramsch-Couture | Wetten-Hype +5 % je Rang | Show-Wetten gewinnen, mit `common`-Ausrüstung siegen |
| `gld_hausordnung` | **Hausordnung e. V.** | Bürokratie-Satire, Stempel, Paragrafen | DEF +2 % je Rang | „Ordnungswidrigkeiten ahnden“ (Gegner eines Typs) |
| `gld_mopsianer` | **Die Mopsianer** | Mopsula-Fanclub | Mopsula MAG +2 % je Rang | Kills durch Mopsula, Bellen |
| `gld_nachtschicht` | **Nachtschicht-Stammtisch** | Tierheim-Kolleg:innen | Heilung +3 % je Rang | Truhen, Events, Herrn Brettschneider helfen |

Regeln: Mitgliedschaft je Spielstand, Wechsel im Fanclub-Büro (Safe Room) gegen Ruf-Verlust; Aufträge nutzen die vorhandenen
Quest-Typen (`bounty`, `achievement_hunt`, `pacifist` …, 05 Kap. 1.3) → **keine neue Auswertelogik**. Ränge 1–5 durch Fanpunkte;
Belohnungen kosmetisch + kleine Boni. **MMO-Haken:** dieselben Datenstrukturen (`guild_id`, `rank`, Auftragsbrett) tragen später
echte Spielergilden (Kap. 7).

### 2.5 Gruppe

- **3. Begleitfigur ab Etage 2:** **Herr Brettschneider** (der verirrte Kandidat aus dem Telefonzellen-Event, GDD §2.6) schließt
  sich an, wenn man ihm auf Etage 1 geholfen hat (Flag aus `fev_lost_candidate`); sonst trifft man auf Etage 2 eine Ersatzfigur.
  Kampf-Slot 2, standardmäßig `AutoPolicy` („Gast:in“), auf Wunsch steuerbar. Belohnt Freundlichkeit rückwirkend — guter Story-Haken.
- **Koop 2–4:** wie 05 Kap. 1.4 (S4): Person A Kai, Person B Mopsula, C/D Begleitfiguren/Spezialisierungen.

### 2.6 Bosse

- Je Etage weiterhin **Revier-Boss** (Pflicht) + **Etagenboss** (optional, GDD §1.4).
- **Show-Bosse**: seltene, von M.O.D. angekündigte **Elite-Varianten** regulärer Gegner („Sonderausgabe!“) mit **einer**
  Zusatzregel, Belohnung Fanpost-Paket (ab E2 zusätzlich Sammelkarte). Optional, sichtbar auf der Karte (goldener Rahmen), nie im Weg.
  - **E1-Kostprobe:** **Orchestrator-Entscheidung 2026-10-10 — nicht im CTB, sondern direkt im Echtzeitkampf
    (`07_ECHTZEITKAMPF.md`, Phase R4; keine Wegwerf-CTB-Inhalte, Kap. 8.8).** Geplant war (Paket C):
    genau **ein** Show-Boss `enc_e1_showboss` „Kanalratten-Gala“ in Zone B (abseits des Pflichtwegs):
    Gruppe der Zone als Elite (+20 % HP/STR), Zusatzregel **„Hausordnung verschärft“**: jeder 3. Gegnerzug belegt das Ziel mit
    `sts_slow` (vorhandener Status, 1 Zug). Belohnung: 1 Fanpost-Paket (`box_fan`) + M.O.D.-Zeile `showboss_won`. Ansage beim
    Betreten der Zone (`showboss_spotted`), keine Tutorial-Zeile — die Regel steht auf der Kampf-Bauchbinde.
  - Ab E2/E4 weitere Show-Bosse mit eigenen Regeln (Tabelle 0.6).
- **Raids** später (Kap. 7).

### 2.7 Erkunden — Raum lassen trotz Countdown

Damit Erkunden sich trotz Etagen-Timer lohnt, zahlt jedes Geheimnis **auch in Zeit oder dauerhaften Werten** zurück:

| Element | Wirkung | Ab |
|---|---|---|
| **Kulissenwände** | rissige Wände (sichtbare Risse + Staub-Partikel): Feldschlag **oder** Bellen öffnet sie → versteckte Räume, oft **Abkürzungen** (Zeitgewinn). Gibt dem Bellen einen zweiten Zweck | **E1** (1–2, Paket A); mehr ab E2 |
| **Regie-Notizen** | versteckte Post-its mit Backstage-Witzen von M.O.D. (Easter Eggs), je +15 Follower; Zähler „Regie-Notizen 1/3“ in der Etagen-Bilanz | **E1** (3, Paket A); mehr ab E2 |
| **Show-Boss** | optionale goldgerahmte Elite-Gruppe mit einer Zusatzregel (2.6) | **E1** (1, Paket C) |
| **Sammelkarten** („NOVA-Sammelkarten“) | 1 je Gegnertyp + Sonderkarten, versteckt oder als seltener Drop; Album im Pausemenü; vollständige Etagen-Seite → Titel + kleine dauerhafte Boni (z. B. +1 % Schaden gegen diesen Typ) | E2 |
| **Optionale Räume** | hinter Schlüsseln/Events, mit Show-Bossen oder Fanclub-Aufträgen | E2 |

**E1-Kostprobe konkret (Paket A, Daten in `floors.json → layout.secrets`):**

| ID | Art | Ort (GDD §1 Zonen) | Öffnet mit | Ergebnis |
|---|---|---|---|---|
| `sec_e1_wall_sewer` | Kulissenwand | Zone B, Wand zwischen zwei Kanalzellen | Feldschlag oder Bellen | Abkürzung B → C, spart ≈ 25–35 s Laufweg (im Bot gemessen) + 1 Regie-Notiz dahinter |
| `sec_e1_wall_track` | Kulissenwand (optional, wenn das Layout es erlaubt) | Zone D, Nische vor dem Stellwerk | Feldschlag oder Bellen | kleiner Raum mit Truhe (Bronze) |
| `sec_e1_note_1..3` | Regie-Notiz | A (Kiosk-Rückseite), B (hinter `sec_e1_wall_sewer`), C (Kellergewölbe) | Interagieren | +15 Follower, M.O.D.-Zeile `secret_note:<n>` |

Öffnen und Einsammeln ändern Spielzustand → Command `{"t": "secret", "id"}` über `Game.open_secret(id)` (Wächter: Held:in in
Reichweite ist Szenenlogik Grad A, aufgezeichnet wird das Ergebnis — wie `encounter`). Zustand `GameState.flags["secrets"]`
(IDs), im Hash und im Save; Minimap zeigt geöffnete Wände.
| **Wiederholungen** | abgeschlossene Etagen im späteren Hub ohne Countdown-Tod erneut spielbar (halbe Belohnungen) — für Sammler:innen | Phase 5 |
| Timer-Modus „entspannt“ | bereits in 04 Kap. 3.6 geplant (Barrierefreiheit) | Phase 4 |

### 2.8 Jetzt vs. später (Zusammenfassung)

| Jetzt (Pakete A–D) | Später |
|---|---|
| Figurenwahl, Bellen, Partner automatisch (Option), E1-Kulissenwände + Regie-Notizen (A) | Rollentausch-Achievements, Mopsula-Kamera-Feinschliff |
| Talent-Show komplett inkl. UI (B) | Talent-Reset, seltene Talente |
| Spezies/Spezialisierung: Datenmodell, Validierung, Regeln, Tests (B) | Casting-UI, Optik, Etage 3 |
| Marotten, Show-Wetten, Unterhosen-Liga, Achievements, E1-Show-Boss (C) | Fanclub-Wetten, Liga-Optik (nur Kostüm-Details der Figuren, **kein** Fuß-/Barfuß-Rig, nie in Key Art) |
| KI-Admin: Schnittstelle, Twist-Katalog, Applier, **Regie (offline, ab E2)**, Referenz-Dienst (D) | Live-Betrieb, Votes, Live-Events (S1–S3) |
| — | Fanclubs, 3. Figur, weitere Show-Bosse und Geheimnisse, Sammelkarten (Phase 3/4) |

---

## 3. Ab Etage 3: Spezies & erste Spezialisierung

### 3.1 Regeln

- Im **ersten Safe Room von Etage 3** öffnet das **Casting** (M.O.D. als Jury, GDD §12.1). Jede Figur wählt
  **(1) Spezies** („Wer bist du?“) und **(2) Spezialisierung** („Was kannst du?“) — zwei Schritte, je ein Bildschirm.
- **„Original bleiben“** ist immer eine vollwertige Wahl (Spezies `spc_original`) — niemand muss sich verwandeln.
- Spezies = **Werte-Charakter + 1 Passiv + Optik**; Spezialisierung = **Rolle + Skills** (vorhandene `classes.json`, 4 je Figur).
  Jede Kombination ist erlaubt; die UI zeigt **Empfehlungen** („passt gut zu …“), keine versteckten Synergien.
- Reihenfolge der Werte: `stat(L)` (GDD §4.1) **+ Ausrüstung + Talente** → **× Klasse** (`stat_mult`) → **× Spezies** (`stat_mult`),
  jeweils Promille, „round half up“, wie heute in `Progression.total_stats`.

### 3.2 Spezies (eigene IP)

**Gemeinsam (beide Figuren):**

| ID | Name | `stat_mult` | Passiv | Optik |
|---|---|---|---|---|
| `spc_original` | **Original-Verpackung** | — | `pas_authentic`: Follower +10 % („Das Publikum liebt Echtes.“) | unverändert; Bauchbinde „ORIGINAL“ beim Kampfstart |

**Kai (4):**

| ID | Name | `stat_mult` | Passiv | Optik-Haken | Empfohlen |
|---|---|---|---|---|---|
| `spc_kai_kachelgolem` | **Kachelgolem** | HP 1.15, DEF 1.15, SPD 0.90 | `pas_grout`: erster erlittener Treffer je Kampf −30 % („Fugenfest“) | Haut aus U-Bahn-Fliesen mit Fugen, Petrol/Weiß | Abrissbirne |
| `spc_kai_neonfalter` | **Neonfalter** | SPD 1.10, LCK 1.15, DEF 0.90 | `pas_lightdrunk`: Krit +10 %, solange Hype ≥ 70 („lichtbetrunken“) | staubige Flügel (`wings`), Fühler (`antennae`), leuchtende Augen | Gleisläufer:in, Showrunner:in |
| `spc_kai_pilzling` | **Pilzling** | HP 1.10, RES 1.10, SPD 0.95 | `pas_spores`: gift-immun; heilt 3 % MaxHP zu Zugbeginn | Pilzhut statt Haaren, Sporenwölkchen beim Laufen | Abrissbirne, Showrunner:in |
| `spc_kai_teilautomat` | **Teilautomat** | MAG 1.10, DEF 1.05, LCK 0.95 | `pas_coin_slot`: Verbrauchsitems wirken +25 % | Brust mit Münzschlitz + Leuchtfront (Kiosk-Automat-Look) | Schrott-Tüftler:in |

**Graf Mopsula (3):**

| ID | Name | `stat_mult` | Passiv | Optik-Haken | Empfohlen |
|---|---|---|---|---|---|
| `spc_mop_glutmops` | **Glutmops** | MAG 1.15, RES 0.95 | `pas_ember`: Feuer-Skills +15 % | Glut in den Falten, Rauchwölkchen beim Niesen | Hofmagier |
| `spc_mop_spukmops` | **Spukmops** | SPD 1.10, LCK 1.10, HP 0.90 | `pas_see_through`: erster gegnerischer Treffer je Kampf −50 % | halbtransparent, schwebt 5 cm (Hologramm-Material) | Fluchgraf, Diva |
| `spc_mop_flattermops` | **Flattermops** | SPD 1.15, DEF 0.95 | `pas_court_flight`: startet jeden Kampf mit `haste` (1 Zug); Bellen-Reichweite +50 % | winzige Flügel (`wings`, Maßstab 0.4), Monokel bleibt | Leibarzt, Diva |

Hinweis IP/Ton: Keine Spezies aus DCC; die Namen spielen mit **unserer** Welt (U-Bahn-Fliesen, Kiosk-Automat, Food-Court-Pilze,
Neonreklame). **Kein Kronen-Motiv an Mopsula** (04 Kap. 2.3) gilt auch für alle Spezies-Optiken.

### 3.3 Spezialisierung = vorhandene Klassen

`cls_kai_wrecker` Abrissbirne · `cls_kai_runner` Gleisläufer:in · `cls_kai_tinker` Schrott-Tüftler:in · `cls_kai_showrunner`
Showrunner:in · `cls_mop_archmage` Hofmagier · `cls_mop_physician` Leibarzt Seiner Hoheit · `cls_mop_hexer` Fluchgraf ·
`cls_mop_diva` Diva (GDD §12.3, unverändert). Eine **zweite Spezialisierung** (Doppelklasse) ist als Staffelfinale-Belohnung (E6)
vorgemerkt.

### 3.4 Datenmodell (Paket B, jetzt)

`data/species.json` (`SpeciesDef`, Präfix `spc_`, Schema bewusst eine Teilmenge von `ClassDef`, damit `Progression` denselben
Code nutzt):

```json
{"schema": 1, "entries": [
 {"id": "spc_kai_kachelgolem", "name": "Kachelgolem", "desc": "Fliesen statt Haut. Steht, fällt selten.",
  "for": ["kai"], "min_floor": 3,
  "stat_mult": {"hp": 1.15, "def": 1.15, "spd": 0.90}, "growth_add": {},
  "passive": {"id": "pas_grout", "params": {"first_hit_taken_pm": 700}},
  "recommended_classes": ["cls_kai_wrecker"],
  "model_hint": {"props_add": [], "colors": {"primary": "#2f8f9a", "secondary": "#e8eef0"}}}
]}
```

| Feld | Typ / Default | Regel |
|---|---|---|
| `id`, `name` | ✓ | `spc_` |
| `desc` | `""` | ≤ 60 Zeichen |
| `for` | `[]` = alle | Party-IDs |
| `min_floor` | 3 | 1..99 |
| `stat_mult` | `{}` | 0.5..2.0 je Stat (wie `ClassDef`) |
| `growth_add` | `{}` | 0..20 |
| `passive` | ✓ | `{id: pas_…, params: {}}` — **im Slice validiert, nicht ausgewertet** (wie Klassen-Passiva, GDD §12.2) |
| `recommended_classes` | `[]` | Referenzen auf `cls_` |
| `model_hint` | `{}` | `props_add` ⊂ `MODEL_PROPS`, `colors` Hex — Optik folgt mit 03_ART |

Laufzeit: `PartyMember.species_id: String = ""` (`""` ≙ `spc_original`), `PartyMember.class_id` (vorhanden). Kern-API
`Casting` (`core/progression/casting.gd`, statisch, ohne UI):

```gdscript
static func options(state: GameState, data: GameData, member_id: String) -> Dictionary   # {"species": [...], "classes": [...]}
static func check(state: GameState, data: GameData, member_id: String, species_id: String, class_id: String) -> String
	# "" | "floor_too_low" | "not_for_member" | "unknown_species" | "unknown_class" | "locked" | "not_in_safe_room"
static func choose(state: GameState, data: GameData, member_id: String, species_id: String, class_id: String) -> bool
```

`Game.choose_casting(member, species, class)` → Command `{"t": "casting", "member", "species", "class"}`.

### 3.5 Casting-Ablauf (UX, später mit Etage 3)

1. Betreten des Safe Rooms: M.O.D. `casting_open` („Willkommen zum Casting! Wer wollen Sie sein? Wählen Sie weise. Oder telegen.“).
2. Bildschirm „Wer bist du?“: Karten der Spezies (Rig-Vorschau dreht sich, Werte-Balken mit +/−, Passiv in einem Satz).
3. Bildschirm „Was kannst du?“: Karten der 4 Spezialisierungen, Empfehlungen markiert.
4. Bestätigen → Jury-Kommentar zur Kombination (Tag `casting_combo:<spc>:<cls>`, Fallback `casting_combo`), z. B. Kachelgolem +
   Abrissbirne: „Ein Bauprojekt auf zwei Beinen. Die Statik nickt.“
5. Danach Mopsula (bzw. die andere Figur) — gleiche Schritte.

### 3.6 Umentscheiden (Re-Spec)

| Was | Regel | Begründung |
|---|---|---|
| Spezies | frei änderbar, **solange man den Casting-Safe-Room nicht verlassen hat**; danach fest („Vertrag ist Vertrag“) | Identität soll zählen; Ausprobieren ist im Raum möglich |
| Spezialisierung | **1× pro Etage kostenlos** im ersten Safe Room der Etage („Umschulung“); ersetzt GDD §12.1 „kein Wechsel“ | Experimentieren macht Spaß (WoW-Respec), ohne Dauer-Hin-und-Her |
| Talente | beim Casting einmal kostenlos zurücksetzbar; später per seltenem Item „Neuanfang-Vertrag“ (Gold-Box) | Fehlwahlen auf E1–2 nicht bestrafen |

Alle drei sind aufgezeichnete Commands (`casting`, später `respec`, `talent_reset`).

### 3.7 Jetzt gebaut (Paket B)

`species.json` mit 8 Einträgen, `SpeciesDef`, Validator-Regeln, `PartyMember.species_id`, Werte-Anwendung in `Progression`,
`Casting.check/choose` + Command + Tests. **Kein** Casting-UI, keine Spezies-Optik, Passiva nur validiert.

**Stand: umgesetzt** (Paket B, 2026-10-10; Details Kap. 8.3 „Stand“). Die Re-Spec-Regeln für Spezies und Spezialisierung
(Tabelle 3.6) stehen in `Casting.check`; Buchführung in `PartyMember.casting {floor, visit, class_floor, class_visit}`. Die erste
Casting-Wahl einer Figur geht in **jedem** Safe Room einer Etage ≥ 3 (wer den ersten auslässt, verpasst nichts). Talent-Reset
(Zeile 3 der Tabelle) folgt mit der Casting-UI.

---

## 4. M.O.D.-Marotten & Show-Wetten

### 4.1 Prinzip in drei Sätzen

1. Zu Beginn jeder Etage verkündet M.O.D. ihre **Vorlieben** (Etage 1: eine, ab Etage 2: zwei) — deterministisch aus dem Seed.
2. Jeder gewonnene Kampf (bzw. jede Erkundungsphase), der eine Vorliebe erfüllt, füllt ein **Herz** (♥) und bringt Hype; drei Herzen =
   **Wette gewonnen** → Fanpost-Paket + Follower.
3. Daneben gilt immer die **Unterhosen-Liga**: wer ohne Rüstung & ohne Accessoire spielt, bekommt dauerhaft mehr Hype und Follower.

### 4.2 Ablauf je Etage

| Schritt | Regel |
|---|---|
| Auswahl | `Marotten.announce(state, data, floor_index)`: Pool = Einträge mit `rotation: true` und `min_floor ≤ Etage`; Etage 1 nur `starter: true`; Anzahl 1 (E1) bzw. 2 (ab E2); möglichst keine Wiederholung der Vorliebe(n) der Vor-Etage; Zufall `SeedUtil.derive(state.seed, "marotte", floor_index)`. Ergebnis in `ShowState.marotten.active`. **Nicht aufgezeichnet** — folgt aus Seed + `floor`-Command |
| Ansage | M.O.D. `marotte_announce:<id>` nach dem Start des Countdowns (E1: nach dem Tutorial-Kampf, GDD B2), sonst bei `floor_start` |
| Treffer | Auswertung beim Kampfende (Sieg) bzw. beim passenden Trigger, Bedingung über `ConditionExpr` (Kap. 4.6); je Kampf zählt jede Vorliebe höchstens 1× |
| Wette gewonnen | bei `goal` Treffern (Standard 3): Belohnung (4.5), M.O.D. `marotte_won:<id>`, Zähler `s.bets_won` +1, Trigger `show_bet` |
| Etagenende | nicht gewonnene Wetten verfallen **ohne** Abzug; M.O.D. höchstens eine Schmoll-Zeile (`marotte_missed`) |

### 4.3 Unterhosen-Liga (immer verfügbar, `mar_unterhose`)

**Regel (spielerseitig, überall gleich formuliert): „ohne Rüstung & ohne Accessoire“** — auf unsere drei Slots (GDD §6, keine
neuen Slots, keine Save-Migration): **Rüstungs-Slot leer** und **Accessoire-Slot leer**. Das Accessoire ist bewusst der ganze
Slot (Gasmaske, Fan-Schal, Glücks-Fahrschein, Ansteck-Mikro, Schlüsselbund, Rattenkrone, Gummistiefel, Turnschuhe) — die Regel
nennt deshalb nie Schuhe oder Füße. Die **Waffe ist erlaubt**.

**Lesbarkeit:** Das Ausrüstungsmenü zeigt bei jeder Figur eine Zeile „Liga: aktiv“ bzw. „Liga blockiert durch: Gasmaske“
(`MarottenRules.liga_blockers(state, member_id) -> PackedStringArray`, Item-Namen aus den belegten Slots).

| Stufe | Bedingung (zu Kampfbeginn geprüft, gilt den ganzen Kampf) | Hype-Gewinne | Follower (Bonus je Etage gedeckelt) | Show-Chip-Zusatz |
|---|---|---|---|---|
| 0 | sonst | ×1.0 | ×1.0 | — |
| **1 „Unterhosen-Liga“** | **gesteuerte Figur** (`GameState.hero`): `armor == ""` **und** `accessory == ""` | **×1.05** (Plan ×1.25, Paket C ×1.20) | **×1.10, höchstens +60 je Etage** (Plan ×1.20, Paket C ×1.15 ohne Deckel) | „LIGA ×1,05“ |
| **2 „Duo-Liga“** (ultimativ) | **beide** Figuren: `armor == ""` und `accessory == ""` | **×1.20** (Plan ×1.50, Paket C ×1.40) | **×1.35, höchstens +180 je Etage** (Plan ×1.40, Paket C ohne Deckel) | „DUO-LIGA ×1,2“ |

*Paket C (gemessen):* Mit den Planwerten lag die Duo-Liga-Staffel bei 2 096 Followern am Ende von E1 (Band 4.10: ≤ 2 000) —
die Faktoren wurden deshalb auf 1,2/1,15 bzw. 1,4/1,35 gesenkt (Daten `marotten.json`, Band als Test `test_06c_balance`).

*Integration Runde 4 (Kap. 8.8 I-8, Messung Kap. 8.4 „Stand Runde 4“):* **Deckel auf den Liga-Follower-Bonus je Etage**
(`reward.tiers[].floor_follower_cap`, optional, 0..2 000): Nach jedem gewonnenen Liga-Kampf bucht
`MarottenRules.take_liga_followers`, was der Follower-Faktor hinzufügt (Follower mit − ohne Faktor), und zahlt es nur bis zum
Deckel der Stufe dieses Kampfes aus; beide Stufen füllen dieselbe Etagensumme `ShowState.marotten.liga.followers` (gespeichert,
im Hash, `Game.replay_log`-gleich), die nächste Etage beginnt bei 0. Hype-Faktor, Liga-Achievements und Mut-Paket bleiben
ungedeckelt. Der Pausemenü-Tab „Show“ nennt Faktoren, Deckel und den Rest der Etage („noch +N Follower“). Kleinere
Hype-Faktoren, weil Hype-Gewinne ganzzahlig gerundet werden (Kap. 8.0 Nr. 4): ab ×1,25 wird jedes +2 (Abwechslung,
Schwachstelle, Combo, Skill-Kill) zu +3 — die Duo-Liga lag damit im Bot bei Hype-Ende ~79 und bis zu 11 Geschenken; ×1,2 hebt
erst Gewinne ab +3 an, ×1,05 erst ab +10 (Stufe 1 ist beim Hype fast neutral, ihr Lohn sind Follower-Bonus, Kette und
Mut-Paket).

Die Multiplikatoren wirken auf die **Kampagnen-Show-Währung**; in gewerteten Event-Läufen zählen sie nicht in die Punkte (4.8 Nr. 4).

- **Schwerer, aber belohnt:** weniger DEF/RES (z. B. Kai L5 ohne Kanalarbeiter-Kombi: DEF 15 statt 24). Ausgleich ist
  thematisch: mehr Hype ⇒ Sponsoren-Schwellen 70/85/100 werden öfter erreicht ⇒ mehr System-Geschenke (Limits GDD §7.4 bleiben).
  „Das Publikum liebt Mut — und Sponsoren lieben das Publikum.“
- **Etagen-Bonus:** Wurden alle (≥ 3) gewonnenen Kämpfe einer Etage in Stufe ≥ 1 bestritten → 1 Fanpost-Paket („Mut-Paket“) bei
  der Etagen-Bilanz; alle (≥ 5) in Stufe 2 → zusätzlich Achievement `ach_duo_floor`.
- **Keine Strafe beim Wiederanziehen:** Stufe sinkt einfach (Zeile `liga_leave`, einmal je Etage).
- **Mopsula als gesteuerte Figur:** ohne Pulli/Umhang und ohne Accessoire → Stufe 1 (`liga_enter:1:mopsula`).
- **Einführung:** Der Hinweis `liga_hint` kommt einmalig in der **Etagen-Bilanz von E1** (nicht im ersten Safe Room) — bis dahin
  ist die Liga nur im Pausemenü-Tab „Show“ beschrieben. Wer sie vorher selbst entdeckt, bekommt trotzdem `liga_enter:*`.

**Achievement-Kette „Liga“** (neu, Trigger `show_bet`, Kap. 4.6; Belohnungen nach GDD §8):

| ID | Name | Bedingung | Box | Hidden |
|---|---|---|---|---|
| `ach_ul_first` | Luftig | `e.kind == "liga" && e.event == "battle" && e.tier >= 1` | bronze | — |
| `ach_ul_boss` | Frische Brise im Revier | `e.kind == "liga" && e.event == "battle" && e.tier >= 1 && e.is_boss == true` | silver | — |
| `ach_duo_first` | Doppel-Feinripp | `e.kind == "liga" && e.event == "battle" && e.tier == 2` | silver | — |
| `ach_duo_floor` | Eine Etage Feinripp | `e.kind == "liga" && e.event == "floor" && e.floor_tier == 2 && e.battles >= 5` | gold | — |
| `ach_duo_flawless` | Ohne Kratzer, mit Wischmopp | `e.kind == "liga" && e.event == "battle" && e.tier == 2 && e.is_floor_boss == true && e.party_kos == 0` | gold | ✓ |
| `ach_bets_5` | M.O.D.s Liebling | `e.kind == "marotte" && e.event == "won" && s.bets_won == 5` | silver | — |

**M.O.D.-Zeilen Liga** (Präfix `liga_`, nicht sexuell, keine Nacktheits-Andeutung — **Unterwäsche bleibt immer an** —,
keine Fuß-Bezüge; Paragrafen-/Imbiss-Humor):

| Tag | Zeile |
|---|---|
| `liga_hint` (Etagen-Bilanz E1, einmalig) | „Übrigens: Wer ohne Rüstung und ohne Accessoire kämpft, kriegt bei mir Bonuspunkte. Ich sage das nur.“ |
| `liga_enter:1` | „Kandidat:in ohne Rüstung, ohne Accessoire. § 3 Kleiderordnung sagt nein, die Quote sagt JA.“ |
| `liga_enter:1:mopsula` | „Der Graf trägt heute: Würde. Und sein Fell. Das Publikum ist entzückt.“ |
| `liga_enter:2` | „Einmal Doppel-Feinripp, bitte. Mit scharf? Nein, mit Wischmopp.“ |
| `liga_win` | „Gewonnen. Im Feinripp. Ich reiche die Szene beim Preis für Zivilcourage ein.“ |
| `liga_floor` | „Eine ganze Etage im Doppel-Feinripp. Die Rechtsabteilung prüft, ob das legal ist. Es ist legendär.“ |
| `liga_leave` | „Rüstung wieder an? Verständlich. Die Zuschauer:innen seufzen leise.“ |

### 4.4 Die rotierenden Marotten (11)

Alle Bedingungen sind **maschinenprüfbar** über den Kontext `show_bet`-/`marotte_battle`-Payload (Kap. 4.6); `e.won == true`
ist bei Kampf-Marotten implizit (nur Siege werden ausgewertet).

| ID | HUD-Name („M.O.D. mag heute: …“) | Trigger / Bedingung | Starter (E1) | Ansage (`marotte_announce:<id>`) | Treffer (`marotte_hit:<id>`) |
|---|---|---|---|---|---|
| `mar_mop_only` | **Nur der Mopp** | Kampf: `e.kai_weapon == "itm_wpn_mop"` | ✓ | „Ich habe heute eine Schwäche für Wischmopps. Fragen Sie nicht. Wischen Sie.“ | „Mit dem Mopp! Ich bekomme Gänsehaut. Ich habe keine Haut.“ |
| `mar_graf_finale` | **Der Graf hat das letzte Wort** | Kampf: `e.last_kill_member == "mopsula"` | ✓ | „Heute will ich den Grafen glänzen sehen. Den letzten Treffer, bitte. Mit Etikette.“ | „Der Graf beendet es. Mit einem Niesen. Zeitlos.“ |
| `mar_variety` | **Stilnote** | Kampf: `e.distinct_actions >= 4` | ✓ | „Heute zählt Stil. Vier verschiedene Aktionen in einem Kampf, und ich vergebe Herzchen.“ | „Abwechslung! Die Jury zückt die Zehn.“ |
| `mar_sneaky` | **Schleichwerbung** (Paket C; „Leise Sohle“ ist schon `ach_preemptive_3` und streift die Fuß-Regel 0.3) | Kampf: `e.encounter_type == "preemptive"` | ✓ | „Ich mag heute Überraschungen. Von hinten. Oder mit Gebell. Hauptsache zuerst.“ | „Erwischt, bevor sie es merkten. Ich liebe Pünktlichkeit.“ |
| `mar_pacifist` | **Friedliche Runde** | `explore_zone`: `e.zones_since_battle >= 3` (3 Räume/Zonen-Zellen erstmals betreten ohne Kampf dazwischen) | — | „Heute mag ich es ruhig. Drei neue Räume ohne Prügelei, und ich werde sentimental.“ | „Drei Räume Frieden. Die Werbekunden sind nervös. Ich bin gerührt.“ |
| `mar_secondhand` | **Second-Hand-Schick** | Kampf: `e.equip_all_common == true` (alle belegten Slots beider Figuren `common`) | — | „Meine Laune heute: Flohmarkt. Nur gewöhnliche Ausrüstung, bitte. Vintage ist Quote.“ | „Gewonnen in Ramsch-Couture. Die Modeabteilung weint vor Glück.“ |
| `mar_speed` | **Schnellschnitt** | Kampf: `e.party_turns <= 3 && e.is_boss == false` | — | „Ich habe heute wenig Sendezeit. Kämpfe in höchstens drei Zügen, und ich liebe Sie.“ | „Zack, fertig! So schnell schneidet nicht mal mein Praktikant.“ |
| `mar_stunt` | **Akrobatik-Abend** | Kampf: `e.stunts_success >= 1` | — | „Heute Abend: Akrobatik! Ein gelungener Stunt pro Kampf, und ich bin Ihr Fan.“ | „Gelandet! Ich habe die Zeitlupe schon dreimal angesehen.“ |
| `mar_bio` | **Bio-Siegel** | Kampf: `e.items_used == 0 && e.gifts == 0` | — | „Heute bin ich auf Natur. Keine Items, keine Sponsoren. Ja, ich höre mich selbst.“ | „Ohne Zusatzstoffe gewonnen. Ich verleihe Ihnen das Siegel ‚garantiert ungesponsert‘.“ |
| `mar_brave` | **Kein Schritt zurück** | Kampf: `e.defends == 0 && e.flee_attempts == 0` | — | „Heute mag ich Mut. Kein Verteidigen, kein Weglaufen. Nur nach vorn.“ | „Nicht einen Schritt zurück! Die Versicherung hat aufgelegt.“ |
| `mar_gourmet` | **Schwachstellen-Gourmet** (Paket C: passt in 28 Zeichen) | Kampf: `e.weakness_hits >= 3` | — | „Ich habe Appetit auf Schwachstellen. Drei pro Kampf, serviert mit Stil.“ | „Genau da, wo es wehtut. Drei Gänge, null Mitleid.“ |

Sonderzeilen: `marotte_won:<id>` (Fallback `marotte_won`: „Wette gewonnen! Sie haben verstanden, was ich mag. Das ist mir fast
unheimlich.“), `marotte_missed` („Meine Vorliebe blieb unerfüllt. Ich trage es mit Fassung. Und Statistik.“).

**`mar_pacifist` genau:** Der Zähler `zones_since_battle` (in `ShowState.marotten`, im Save und Hash) steigt nur beim **ersten
Betreten** einer noch nicht besuchten Raumzelle (vorhandenes Quest-Detail `zones`, RunSim `zones_event`) — also nur bei Bewegung
mit laufendem Timer; Safe Rooms, Menüs, Pausen und Stillstand zählen nie. Kampfbeginn setzt ihn auf 0. Treffer bei `>= 3`, danach
**Latch**: Zähler auf 0, nächster Treffer frühestens nach drei weiteren neuen Räumen. Belohnt wird Umgehen per Bellen/Schleichen,
nicht Warten. Test: Speichern/Laden mitten in einer Periode setzt den Zähler korrekt fort.

### 4.5 Belohnungen (Startwerte)

| Ereignis | Belohnung |
|---|---|
| Treffer (♥) | Hype **+6** (× `hype_gain_pm`), Follower dieses Kampfes **×1.15** (`follower_pm` 1150); Herz-Animation + Treffer-Zeile |
| Wette gewonnen (3 ♥) | **1 Fanpost-Paket** (`box_fan` → `pending_lootboxes`), Follower **+30**, Hype +5, Zähler `s.bets_won` +1 |
| Liga-Etagenbonus | 1 Fanpost-Paket (siehe 4.3) |
| Obergrenze | ≤ 3 Boxen je Etage aus Show-Wetten (2 Wetten + Liga; auf E1 nur 1 Wette + Liga, dazu 1 aus dem optionalen Show-Boss) — GDD §13 Lootbox-Band wird auf **15–22** erweitert (Paket C) |

Alle Werte stehen in `marotten.json` (`reward`) und sind per Balancing änderbar.

### 4.6 Bedingungen & Kontext (maschinenprüfbar)

Neuer Auswertungskontext **`marotte_battle`** (gebaut von `MarottenRules.battle_context(state, data, result, tally)` aus
`BattleResult` + einer Kampf-Strichliste. Die Strichliste führt ein `MarottenTracker` (`core/show`, `RefCounted`, **nur** diese
Aufgabe) aus dem `ActionEvent`-Strom des Kampfes — überall dort, wo ein Kampf läuft (Spiel und `RunSim`/Verifier); Ablage in
`ShowState.marotten.tally`, damit sie Save und Replay übersteht. Auswertung und Belohnungen sind statisch in `MarottenRules` →
Spiel, `RunSim` und Verifier rechnen dasselbe, ohne `Show`-Autoload) — Schlüssel:

`won, hero, party_turns, items_used, gifts, defends, flee_attempts, distinct_actions, stunts_success, weakness_hits,
min_party_hp_pct, party_kos, last_kill_member, encounter_type, is_boss, is_floor_boss, boss_id, kai_weapon, equip_all_common,
hero_armor_empty, hero_acc_empty, party_armor_empty, party_acc_empty, liga_tier`

Bedingungen nutzen die vorhandene Grammatik (`ConditionExpr`, 02_TECH §4.4.9: `e.`/`s.`/`f.`, `== != >= <= > <`, `&&`). Der
Validator prüft `e.`-Schlüssel gegen diese Liste (bzw. gegen die `explore_zone`-Payload `zones_since_battle, zone, floor`).

Neuer Achievement-Trigger **`show_bet`** (Payload): `kind ("liga" | "marotte"), event ("battle" | "floor" | "won"), id, tier,
floor_tier, battles, is_boss, is_floor_boss, boss_id, party_kos, floor`. Neue `StatIds`: `bets_won`, `liga_battles`.

### 4.7 HUD & Menüs

- **Ein Show-Chip** (TV-Overlay, Erkundung + Kampf, unter der Hype-Leiste, 18 px): Vorlieben und Liga in **einem** kompakten
  Element, z. B. **„♥ Nur der Mopp ●●○“** — auf E1 genau eine Vorliebe; ab E2 wechseln zwei Vorlieben alle 4 s im selben Chip
  (oder Kurzform „♥ 2/3 · 0/3“ auf schmalen Bildschirmen). Ist die Liga aktiv, hängt der Chip „· LIGA ×1,05“ bzw. „· DUO-LIGA ×1,2“
  an (Hype-Faktor aus den Daten, Kap. 4.3; Magenta/Gelb). Gewonnene Wette: Eintrag golden mit Haken. Abschaltbar: Optionen → „Show-Wetten anzeigen“. **Keine** zweite
  HUD-Zeile, **kein** separates Liga-Badge.
- **Kampfende:** Herz fliegt aus dem Ergebnis-Panel in den Show-Chip; Toast „♥ M.O.D. gefällt das (+6 Hype)“.
- **Pausemenü-Tab „Show“:** aktive Vorlieben mit Bedingung im Klartext, Fortschritt, Liga-Stufe mit Regeltext („ohne Rüstung &
  ohne Accessoire“) und Blockern je Figur, bisher gewonnene Wetten.

### 4.8 Fairness-Regeln (verbindlich)

1. **Sichtbar und freiwillig:** Vorlieben werden angesagt und angezeigt; es gibt keinen versteckten Zwang, keine Menü-Sperre.
2. **Nie Pflicht, nie Strafe:** Ignorieren kostet nichts (kein Hype-Abzug, keine schlechteren Drops). M.O.D. schmollt höchstens
   einmal je Etage.
3. **Keine Paywall:** Nichts davon ist kaufbar, nichts hängt an Zuschauer-Geschenken; `mar_bio` belohnt sogar den Verzicht.
4. **Gleich für alle, nie Pflicht für die Bestenliste:** Die Auswahl folgt aus dem Seed — in Event-Läufen (auch Pur-Liga) haben
   alle dieselben Vorlieben (abschaltbar per `rules.marotten.enabled`). **Entscheidung (Option a):** In gewerteten Event-Läufen
   zählen Liga-, Marotten- und Talent-Multiplikatoren sowie die Wett-Follower (+30) **nicht** in die Wertung — `show_pts`
   (05 Kap. 1.5) rechnet mit `followers_gained_base` (Follower ohne Liga/Marotten/Talente/Twists; Ausrüstungs-`show_mods` zählen
   wie bisher). Achievements mit Trigger `show_bet` zählen nicht in `ach_pts`. Liga und Wetten sind damit reine
   **Kampagnen-Show-Währung**; im Event sind sie Spaß und Kommentar, nie Ranglisten-Pflicht. `rules.marotten.enabled` und
   `rules.liga.enabled` sind Teil von `rules_hash` (Test: Änderung ⇒ anderer Hash). Die Alternative (b) — Liga als angekündigte
   Risiko-Regel mit eigener Board-Variante — bleibt für spätere Event-Formate offen.
5. **Lesbar:** jede Bedingung in einem Satz im Menü; keine Bedingung braucht Wissen, das das Spiel nicht zeigt.
6. **Gedeckelt:** Belohnungen in Show-Währung (Hype, Follower, Fanpost-Paket), höchstens 3 Boxen je Etage; keine Stat-Boni, die
   Kampf-Balancing kippen.
7. **Keine Kollision mit Twists:** Twists ändern nie Marotten-Bedingungen; Twist-Effekte (z. B. `tw_double_credits`) zählen nicht
   als Item oder Geschenk (`mar_bio` bleibt erfüllbar). Twists wirken ohnehin erst ab E2 (Kap. 5.7).
8. **Barrierefrei:** Liga und Wetten gelten im Vorabendprogramm genauso; Anzeige abschaltbar.

### 4.9 Datenmodell `marotten.json` (`MarotteDef`, Präfix `mar_`)

```json
{"schema": 1, "entries": [
 {"id": "mar_mop_only", "name": "Nur der Mopp", "desc": "Gewinne Kämpfe, während Kai den Wischmopp trägt.",
  "kind": "battle", "trigger": "marotte_battle", "condition": "e.kai_weapon == \"itm_wpn_mop\"",
  "goal": 3, "rotation": true, "starter": true, "min_floor": 1, "weight": 2,
  "reward": {"hit_hype": 6, "hit_follower_pm": 1150, "won_box": "box_fan", "won_followers": 30, "won_hype": 5},
  "mod_tag": "mar_mop_only"},
 {"id": "mar_unterhose", "name": "Unterhosen-Liga", "desc": "Ohne Rüstung & ohne Accessoire kämpfen.",
  "kind": "liga", "trigger": "marotte_battle", "condition": "e.liga_tier >= 1",
  "goal": 0, "rotation": false, "starter": false, "min_floor": 1, "weight": 1,
  "reward": {"tiers": [{"tier": 1, "hype_pm": 1200, "follower_pm": 1150}, {"tier": 2, "hype_pm": 1400, "follower_pm": 1350}],
             "floor_box": "box_fan"},
  "mod_tag": "liga"}
]}
```

`kind` ∈ `battle | explore | liga`; `trigger` ∈ `marotte_battle | explore_zone`; Texte `name` ≤ 28 Zeichen (HUD), `desc` ≤ 80.
Der Validator lehnt in `name`/`desc` aller Marotten sowie in `liga_*`-Zeilen Fuß-Wörter ab (`barfuß`, `Schuh`, `Füße`, `Socke`;
Distanz-Regel 0.3).

### 4.10 Balancing-Ziele (in Paket C per Simulation messen, Band als Test)

| Kennzahl | Ziel |
|---|---|
| Gewonnene Wetten je Etage (Erstspieler:in, ohne gezieltes Spielen) | 0–1 von 2 |
| … bei gezieltem Spielen | 2 von 2 |
| Liga Stufe 1: Niederlage 1. Versuch Hausmeister / Königin | ≤ 40 % / ≤ 55 % (heute ~20 % / ~35 %) |
| Liga Stufe 2: dto. | ≤ 55 % / ≤ 70 % — „ultimativ“, aber schaffbar |
| Lootboxen je Etage | 15–22 (bisher 15–20) |
| Follower Ende E1 bei Liga-Durchlauf | ≤ 2 000 (Rückkopplung bleibt gedämpft, GDD §7.2) |

---

## 5. KI-Admin „M.O.D. live“

### 5.1 Machbarkeit & Aufwand — kurze Antwort

**Ja, machbar — mit Leitplanken.** Der Aufwand liegt weniger im Code (Referenz-Dienst + Spiel-Schnittstelle ≈ 1–2 Wochen inkl.
Tests) als im **Betrieb**: Kosten pro Spielstunde, Latenz, Inhaltssicherheit, Datenschutz und Humor-Qualität. Deshalb gestuft
(Kap. 5.12): Heute bleibt die geschriebene M.O.D. die Basis; die KI kommt als **optionaler Farbkommentar** und als **Regie mit
begrenzten Eingriffen** dazu. Ein sehr günstiger Zwischenschritt ist die **„KI-Redaktion“** (S0.5): Claude schreibt offline neue
Spruch-Entwürfe, Menschen kuratieren sie in `mod_lines.json` — mehr Abwechslung ohne Laufzeitkosten und ohne Risiko.

**„M.O.D. verändert das Spiel leicht“ erlebt jede:r — auch ohne KI.** Ab Etage 2 greift in der Kampagne die **Regie** ein
(`RegieDirector`, Kap. 5.7a): offline, aus dem Seed, mit einfachen Faustregeln („Timer knapp → Nachspielzeit“, „Party angeschlagen →
nur hilfreiche Twists“) und geschriebenen Zeilen. Sie nutzt denselben Twist-Katalog, denselben `TwistApplier` und dasselbe
aufgezeichnete Command wie später die KI. Die KI ersetzt dann nur zwei Schichten: **welcher** Twist (Auswahl) und **welcher Spruch**
(Zeilen). Wer „M.O.D. live“ nie einschaltet, verpasst also keinen Eingriff, nur die improvisierten Sprüche.

### 5.2 Was die KI darf — und was nicht

| Darf | Darf nicht |
|---|---|
| Live-Kommentare zu dem, was gerade passiert (Kampf-Highlights, Liga, Wetten, Timer, Rekorde) | Story-Beats, Tutorials, Regeltexte, Achievement-Texte ersetzen (bleiben geschrieben) |
| Einen **Twist** aus dem Katalog vorschlagen (Kap. 5.6), mit Parametern **innerhalb der Grenzen** | Zufallsergebnisse bestimmen (Würfe kommen immer aus `SeedUtil`), Items/Credits frei vergeben, Spielstände ändern |
| Stimmung wählen (`snarky`/`sweet`/`neutral`) | Spieler:innen zu Käufen, Spenden oder Geschenken auffordern; Echtgeld erwähnen |
| Mopsula oder den Chat „sprechen lassen“ (Stimme `mopsula`/`chat`) | reale Personen, Marken, Politik, sexuelle Inhalte, Beleidigungen |

Merksatz für Persona und Filter: **„M.O.D. darf necken, nie sabotieren.“**

### 5.3 Architektur

```text
 Godot-Client (hält NIE einen API-Schlüssel)
 ┌──────────────────────────────────────────────────────────────────────────────────────────┐
 │ Events (Signale) ──► ModLiveLink (Node, Kind von Game; sammelt kompakte Ereignisse,       │
 │                       Takt 40 s Lauf-Uhr; Höhepunkt zieht vor, min. 20 s; ≤ 90 Runden/h)  │
 │                         │ ModLiveSummary.build(state) (rein, ohne Namen/Freitext)          │
 │                         ▼                                                                  │
 │                ModVoiceProvider  ◄── ScriptedModVoice (Standard: nichts/Skript)            │
 │                         │        ◄── RemoteModVoice (HTTPS, nur wenn aktiviert)            │
 │                         │        ◄── MockModVoice (Tests)                                  │
 │   lines[] ◄─────────────┤                                                                  │
 │   Show.say_external() ──► Filter, niedrigste Priorität ──► ModDialog / Ticker (Anzeige)    │
 │   twist  ◄──────────────┘                                                                  │
 │   Game.apply_twist() ──► TwistApplier.validate ──► record {"t":"twist"} ──► apply (Kern)   │
 └──────────────────────────────────────────────────────────────────────────────────────────┘
                     │ POST /v1/mod/turn  (Sitzungs-Token aus Plattform-Auth, ≤ 8 KB)
                     ▼
 mod-brain (Server, Python, services/mod-brain)
   Token ─► Konto-/Budget-Deckel ─► Schema-Prüfung ─► Rate-Limit ─► Prompt (System: Persona + Regeln + Twist-Katalog [gecacht];
   User: Zustandszusammenfassung + Ereignisse) ─► Claude (structured output) ─► Sicherheitsfilter
   ─► Twist-Validierung (gleiche Regeln wie der Kern) ─► {"lines": [...], "twist": {...} | null}
   Fehler/Timeout/Refusal/Filtertreffer ─► {"lines": [], "twist": null}  (Spiel spricht Skript-Zeilen)
```

### 5.4 Protokoll (Schema 1)

**Anfrage** `POST /v1/mod/turn`:

```json
{"schema": 1, "req_id": "r_000123", "run_ref": "pseudonym-hash", "lang": "de",
 "state": {"floor": 2, "timer_sec": 750, "hype": 64, "viewers_k": 4, "hero": "kai", "liga_tier": 1,
           "party": [{"id": "kai", "lvl": 5, "hp_pct": 72, "spc": "", "cls": ""}, {"id": "mopsula", "lvl": 5, "hp_pct": 40}],
           "bets": [{"id": "mar_mop_only", "hits": 2, "goal": 3}], "phase": "explore"},
 "events": [{"t": "kill", "enemy": "enm_kanalratte", "by": "stunt"}, {"t": "achievement", "id": "ach_stunt_first"}],
 "recent_line_ids": ["l_9f2c01", "l_9f2c02"],
 "allowed_twists_hint": ["tw_lights_out", "tw_overtime"], "spice_left_hint": 1, "last_twist_result": "applied"}
```

**Eingabe-Regeln (verbindlich):** Kein vom Client gelieferter **String** gelangt in den Prompt. Jedes Feld ist entweder eine Zahl
in einem Bereich oder eine ID/ein Enum, das der Dienst gegen den Katalog (`GameData`-Export: Gegner, Achievements, Twists,
Marotten, Party-IDs, Ereignistypen, `last_twist_result` ∈ `"" | "applied" | <Ablehnungsgrund>`) prüft; Unbekanntes → Anfrage
abgelehnt (`400`), nicht „bereinigt“. **Bisherige Zeilen** speichert der **Dienst** selbst je `run_ref` (Ringpuffer der letzten 6
von ihm ausgegebenen Zeilen, TTL 2 h); der Client schickt höchstens die vom Dienst vergebenen `recent_line_ids` (nur zur
Zuordnung, nie als Text). `allowed_twists_hint` und `spice_left_hint` sind **Hinweise**: Der Dienst bildet die Schnittmenge mit
dem Katalog und seinen eigenen Regeln (`min_floor`, Quelle, Schärfe-Budget aus dem eigenen Lauf-Zähler je `run_ref`); der Kern
prüft jeden Vorschlag ohnehin erneut (`TwistApplier.validate`).

**Antwort** (structured output, JSON-Schema mit `additionalProperties: false`):

```json
{"lines": [{"text": "Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.", "tag": "live:stunt", "voice": "mod"}],
 "twist": {"id": "tw_overtime", "params": {"seconds": 60}},
 "mood": "snarky"}
```

`lines` 0–3, `text` ≤ 110 Zeichen, einziger erlaubter Platzhalter `{name}` (der Client setzt den Namen ein — der Dienst kennt ihn
nie), `voice` ∈ `mod | mopsula | chat`, `twist` nur aus der serverseitig gebildeten Schnittmenge, `mood` ∈ `snarky | sweet | neutral`.
Der Dienst ergänzt jede Zeile um eine `line_id` (für `recent_line_ids`). Längen- und Wertebereiche prüft zusätzlich der
Post-Filter (Schema-Constraints allein reichen nicht).

### 5.5 mod-brain: Modell und API-Nutzung

| Punkt | Festlegung |
|---|---|
| SDK | offizielles Python-SDK `anthropic` (Version bei Umsetzung pinnen) |
| Modell (Standard) | **`claude-opus-5-5`** (Konfig `MOD_BRAIN_MODEL`) |
| Denken | adaptiv (bei Opus 5.5 immer an — `thinking` weglassen; `disabled`/`budget_tokens` sind dort ein 400) |
| Effort | **`low`** für Kommentar-Runden (`output_config.effort`), konfigurierbar je Route (`lines` / `director`); Opus-5.5-Standard wäre `medium`, daher explizit setzen |
| Ausgabeformat | **Structured Outputs** über `output_config.format` (`type: json_schema`, Schema aus dem Pydantic-Modell) bzw. `client.messages.parse(...)`; keine Prefills |
| Prompt Caching | System-Prompt = Persona + Tonregeln (GDD §11.1) + ~20 Beispielzeilen + harte Regeln + Twist-Katalog (≈ 3–6 k Tokens, über dem Mindestpräfix von 512 Tokens für Opus 5.5) mit `cache_control: {"type": "ephemeral"}` am letzten System-Block; **byte-stabil** (keine Zeitstempel, sortierter Katalog); alles Variable nur in der User-Nachricht. Kontrolle über `usage.cache_read_input_tokens` |
| TTL | Standard 5 min (Runden alle ≤ 40 s halten den Cache warm); 1 h nur für Live-Sendungen mit Vorab-Aufwärmen |
| Zustandslos | jede Runde = 1 System + 1 User-Nachricht (keine wachsende Konversation, keine wiederverwendeten Thinking-Blöcke); Kontinuität über den serverseitigen Zeilen-Ringpuffer je `run_ref` + `state` |
| Refusal | `stop_reason == "refusal"` immer vor dem Lesen von `content` prüfen; serverseitiger Fallback `fallbacks: "default"` (Beta `server-side-fallback-2026-07-01`) eingeschaltet; verweigert die ganze Kette → leere Runde (Skript übernimmt) |
| Fehler & Deadline | Route `lines`: **Deadline 4 s, keine Retries** (`max_retries=0`, `timeout=4.0`) — bleibt sicher unter dem Client-Timeout von 6 s; Route `director` (Live-Sendungen): 1 Retry, Deadline 8 s. Danach leere Runde |

Skizze (bei Umsetzung gegen die SDK-Doku prüfen, Paket D):

```python
response = client.beta.messages.create(
    model=cfg.model,                                   # "claude-opus-5-5"
    max_tokens=4000,
    betas=["server-side-fallback-2026-07-01"],
    fallbacks="default",
    system=[{"type": "text", "text": PERSONA_RULES_CATALOG, "cache_control": {"type": "ephemeral"}}],
    messages=[{"role": "user", "content": turn_json}],    # nur Zustand + Ereignisse, kein Freitext von Menschen
    output_config={"effort": cfg.effort, "format": {"type": "json_schema", "schema": MOD_TURN_SCHEMA}},
)
if response.stop_reason == "refusal":
    return EMPTY_TURN
```

**Die Modellwahl je Route bleibt Betreiberentscheidung — aber auf Daten:** Für die Route `lines` macht die Kostenrechnung
(Kap. 5.11) in der Kampagne realistisch nur `claude-sonnet-5-5` oder `claude-haiku-5-5` tragfähig; Opus 5.5 denkt immer mit und
ist für einen Median < 3 s eher knapp. Deshalb ist ein **Vergleich Opus 5.5 / Sonnet 5.5 / Haiku 5.5 auf der Route `lines`**
Teil des S1-Gates (gleiche 100 Runden je Modell, blind bewertet: Humor-Score, Latenz Median/p95, Kosten je Stunde, Filter-Treffer).
Wechsel nur über `MOD_BRAIN_MODEL` (je Route), Persona bleibt. `claude-opus-5-5` bleibt Standard für die Route `director` in
Live-Sendungen (eine Regie je Sendung).

### 5.6 Twist-Katalog `data/twists.json` (`TwistDef`, Präfix `tw_`)

Gemeinsamer Katalog für **KI-Regie, Zuschauer-Votes (05 Kap. 6.2), feste Event-Fahrpläne und QA**. Er ersetzt die Skizze in 05
Kap. 10.5 (Format jetzt nach 02_TECH §4.1: `{"schema": 1, "entries": [...]}`, Texte in `name`). Spalte „Slice“ = in Paket D
mit Wirkung umgesetzt; übrige Einträge sind validiert, aber `slice: false` → `TwistApplier` lehnt sie ab (`not_in_slice`).

| ID | Name | Bereich | Wirkung (Grenzen) | Dauer | Schärfe | Slice |
|---|---|---|---|---|---|---|
| `tw_lights_out` | Stromausfall | explore | Gegner-Sicht `enemy_sight_pm` 500 (400–700) + Vignette | 60 s (30–90) | neutral | ✓ |
| `tw_quiet_please` | Ruhe im Studio | explore | Gegner-Gehör `enemy_hear_pm` 500 (400–700) | 60 s (30–90) | hilfreich | ✓ |
| `tw_fog_of_fame` | Ruhmesnebel (05) | explore | Hype-Zerfall pausiert | 90 s (30–90) | hilfreich | ✓ |
| `tw_confetti_gravity` | Konfetti-Gravitation | explore | Konfetti fällt nach oben (FX) + Hype-Zerfall pausiert | 45 s (20–60) | hilfreich | ✓ |
| `tw_double_credits` | Doppel-Credits | explore | Credits aus Truhen/Kämpfen ×2 (`credits_pm` 1500–2000), Deckel +200 Cr | 60 s (30–60) | hilfreich | ✓ |
| `tw_overtime` | Nachspielzeit | instant | Etagen-Timer +`seconds` (30–60), **1× je Etage** | — | hilfreich | ✓ |
| `tw_happy_hour` | Happy Hour | safe_room | Automatenpreise −`pct` (10–25 %) beim nächsten Safe-Room-Besuch | 1 Besuch | hilfreich | ✓ |
| `tw_rat_rain` | Rattenregen (05) | instant | 1 Streuner-Gruppe aus dem Zonenpool, außer Sicht (Regeln GDD §2.7) | — | scharf | ✓ |
| `tw_party_hats` | Partyhüte für Gegner | battle | nächste 2 Kämpfe: Hype-Gewinne ×1.2 (1.1–1.3); Hut-Optik folgt (03_ART) | 2 Kämpfe | hilfreich | ✓ |
| `tw_mopsula_moderates` | Mopsula moderiert | presentation | M.O.D.-Zeilen erscheinen in Mopsula-Stimme | 180 s | — | ✓ |
| `tw_mopsula_monologue` | Mopsula-Monolog (05) | presentation | 2–3 Mopsula-Zeilen | 10 s | — | ✓ |
| `tw_mod_mood` | M.O.D.-Laune (05) | presentation | Spruchsatz `snarky`/`sweet` | 300 s | — | später |
| `tw_costume` | Kostümwahl (05) | presentation | Mopsula-Kostüm für den Lauf | Lauf | — | später |
| `tw_trap_or_treasure` | Falle oder Schatz | room | nächster Raum: Mystery-Kiste; Ausgang per Zuschauer-Abstimmung (S2) bzw. Seed-Münzwurf | — | scharf | später |
| `tw_mirror_room` | Spiegel-Raum | battle | nächster Kampf: Schwächen ↔ Resistenzen getauscht | 1 Kampf | neutral | später |
| `tw_elite_guest` | Stargast | battle | nächste reguläre Gruppe Elite (+20 % HP/STR), EXP/Credits ×2, Bronze-Box | 1 Kampf | scharf | später |
| `tw_double_trouble` | Doppelte Quote (05) | battle | +1 Gegner, EXP/Credits ×1.5 | 1 Kampf | scharf | später |
| `tw_sponsor_rush` | Werbeblock (05) | battle | nächste Hype-Schwelle 2 System-Geschenke (Limits gelten) | 1 Kampf | hilfreich | später |
| `tw_boss_mood` | Bosslaune (05) | boss | Variante `aggressive`/`vain` (nur per Vote) | 1 Kampf | neutral | später |
| `tw_marotte_flash` | Laune der Regie | explore | Treffer der aktiven Vorlieben zählen doppelt | 180 s | hilfreich | später |

**Schema:**

```json
{"id": "tw_lights_out", "name": "Stromausfall", "desc": "Gegner sehen schlechter. Sie auch.",
 "gameplay": true, "scope": "explore", "spice": "neutral", "slice": true, "once_per_floor": false,
 "duration": {"unit": "sec", "default": 60, "min": 30, "max": 90},
 "params": {"enemy_sight_pm": {"default": 500, "min": 400, "max": 700}},
 "sources": ["regie", "mod_brain", "vote", "schedule", "dev"], "mod_tag": "twist_applied_tw_lights_out"}
```

`scope` ∈ `explore | instant | battle | safe_room | presentation | room | boss`; `spice` ∈ `helpful | neutral | spicy | none`;
`duration.unit` ∈ `sec | battles | visits | run | none`; alle Zahlen ganzzahlig. M.O.D.-Zeilen `twist_applied_<id>` (Präfix existiert):

| Twist | Zeile |
|---|---|
| `tw_lights_out` | „Stromausfall! Sparmaßnahme der Regie. Die Monster sehen auch nichts. Fair, oder?“ |
| `tw_quiet_please` | „Ruhe im Studio! Die Monster hören jetzt schlechter. Flüstern Sie trotzdem, es ist höflich.“ |
| `tw_fog_of_fame` | „Ruhmesnebel! Das Publikum vergisst gerade nichts. Nutzen Sie das.“ |
| `tw_confetti_gravity` | „Konfetti-Gravitation! Es schneit nach oben. Die Physikabteilung ist im Urlaub.“ |
| `tw_double_credits` | „Doppel-Credits für eine Minute! Danach ist die Inflation wieder normal.“ |
| `tw_overtime` | „Nachspielzeit! Eine Minute extra. Ich bin heute großzügig. Notieren Sie das.“ |
| `tw_happy_hour` | „Happy Hour am Automaten! Zwanzig Prozent Rabatt. Der Automat weint leise.“ |
| `tw_rat_rain` | „Rattenregen! Ein Lieferant hatte zu viel Lagerbestand. Ich konnte nicht Nein sagen.“ |
| `tw_party_hats` | „Partyhüte für alle Monster! Die nächsten zwei Kämpfe sind offiziell eine Feier.“ |
| `tw_mopsula_moderates` | „Ich mache Pause. Der Graf moderiert. Möge die Sendung das überleben.“ |
| `tw_mopsula_monologue` | „Der Graf hat um das Wort gebeten. Ich habe es ihm gegeben. Ich bereue es schon.“ |

### 5.7 Twist-Regeln (Kern = Autorität, Dienst prüft identisch)

| Regel | Wert |
|---|---|
| Quelle | `src` ∈ `regie` (offline-Regie der Kampagne, 5.7a), `mod_brain` (KI), `vote` (S2), `schedule` (Event-Fahrplan), `dev` (QA, Debug F6) — je Lauf über `rules.twists.sources` freigegeben |
| Ab Etage | `rules.twists.min_floor` (Standard **2**); darunter lehnt `TwistApplier.validate` mit `floor_too_low` ab — für **alle** Quellen, auch `dev` außer im Debug-Override. Damit erzwingt der Code den Fahrplan 0.6 |
| Gleichzeitig | max. **1** aktiver spielrelevanter Twist; Präsentations-Twists dürfen parallel laufen |
| Abstand | ≥ **90 s** Erkundungszeit zwischen Ende und nächstem spielrelevanten Twist |
| Je Etage | ≤ **4** spielrelevante Twists, davon ≤ **1** `spicy` („Schärfe-Budget“, an den Dienst als `spice_left`) |
| Nie nach unten treten | `spicy` nur, wenn Party-HP im Schnitt ≥ 50 %, Timer ≥ 180 s, nicht im/neben einem Boss-Raum |
| Zeitpunkt | Anwendung nur in der Erkundung an einer Tick-Grenze (nie im Kampf, nie in Dialogen/Menüs); Kampf-Twists wirken ab dem **nächsten** Kampf, Safe-Room-Twists beim **nächsten** Besuch |
| Zufall | Twists mit Zufall (z. B. Rattenregen-Zelle) würfeln mit `SeedUtil.derive(floor_run.loot_seed, "twist", n)` — **die KI wählt WAS, nie das Ergebnis** |
| Aufzeichnung | externes Command **ein Schema für alle Quellen**: `{"t": "twist", "twist": {"schema": 1, "id", "n", "src", "params", "duration", "tick", "req"?, "vote_id"?}}` — `tick` = Erkundungs-Tick der Anwendung (Pflicht), `req` nur bei `mod_brain`, `vote_id` nur bei `vote`; `cmd_id` 0 (wie `gift`, 02_TECH §3.4), aufgezeichnet bei der **Anwendung**. Der Verifier prüft dieselben Regeln (manipulierte Twists → Fehler) |
| Replay-Reihenfolge | `Game.replay_log`/`RunSim` wenden ein `twist`-Command **genau bei `tick`** an: Steht es im Log vor den Zeit-Commands, die bis `tick` laufen, wird es gepuffert und beim Erreichen von `tick` angewendet (nach der Tick-Auswertung, wie live). Ist `tick` beim Lesen schon überschritten → Replay-Abweichung `twist_tick_passed` (Lauf ungültig). Der Puffer liegt seit der Integration (Runde 4) **im Zustand** (`flags.twist_buffer`, gespeichert, nicht gehasht): ein wartender Twist übersteht Speichern → Laden und wird im nächsten Log-Segment nach der Restwartezeit angewendet; am Log-Ende noch wartende Twists sind kein Fehler mehr (`result.twists_waiting`). Tests: Twist regulär, Twist im Log zu früh einsortiert (gleicher Hash), Twist zu spät (Abweichung), Puffer über Speichern/Laden (`test_06d_twist_save`) |
| Zustand | `GameState.flags["live"]["twist"]` = `{n, active: [{id, n, until_tick \| battles_left \| visits_left, params}], last_end_tick, floor, floor_count, floor_spicy, once}` — im Hash und im Save |
| Ablauf | `RunSim.step` zählt Laufzeit-Twists auf Erkundungs-Ticks herunter (`ExploreEvent` `TWIST_ENDED` → `Events.twist_ended`); Kampf-/Besuchs-Twists zählen bei `apply_battle_result` / `enter_safe_room` herunter |
| **Pur-Liga** | **keine** spielrelevanten Twists (nur `gameplay: false`), keine KI-Twists |
| **Gewertete Event-Läufe (Show-Liga)** | KI-Twists **aus**; stattdessen optional **fester Fahrplan** in `events.json → rules.twists.schedule: [{tick, id, params}]` (für alle gleich, Teil von `rules_hash`); die KI liefert dort nur Sprüche |
| Kampagne | ab E2 **Regie** (`src: "regie"`, Standard an; Optionen → „Regie-Eingriffe“ zum Abschalten). Steht „M.O.D. live“ auf **„Kommentar + Regie“** (Opt-in), wählt die KI statt der Regie (`src: "mod_brain"`); fällt sie aus, übernimmt wieder die Regie |

Ablehnungsgründe (`TwistApplier.validate`): `unknown_twist`, `not_in_slice`, `source_not_allowed`, `floor_too_low`, `league_pur`,
`params_out_of_range`, `busy`, `cooldown`, `floor_cap`, `spice_budget`, `party_weak`, `timer_low`, `wrong_phase`, `once_per_floor`,
`tick_mismatch`. Gemeinsame Testfälle in `tests/fixtures/live/twist_cases.json` (inkl. `floor_too_low`) werden **vom
GDScript-Test und von pytest** gelesen → beide Seiten entscheiden nachweislich gleich.

### 5.7a Regie (offline, ab Etage 2)

**Ein Satz:** Ab Etage 2 greift M.O.D.s Regie ein paar Mal pro Etage ein — kurz, angesagt, meist hilfreich.

| Regel | Wert |
|---|---|
| Klasse | `core/live/regie_director.gd` (`RegieDirector`, statisch, rein; Paket D) |
| Entscheidungspunkte | alle **120 s Erkundungszeit** (Tick-genau, nur Erkundung, Timer läuft) prüft `RegieDirector.decide(state, data, rules, now_tick)`; Ergebnis `{}` oder ein Twist-Vorschlag |
| Auswahl | Kandidaten = `TwistApplier.allowed_now(…)` mit `src: "regie"`, gefiltert durch Faustregeln: Timer < 180 s → nur `tw_overtime` (falls noch frei); Party-HP im Schnitt < 50 % → nur `helpful`; sonst gewichteter Zug aus den Slice-Twists. Eingriffswahrscheinlichkeit je Punkt 35 % (Startwert). Zufall ausschließlich `SeedUtil.derive(state.seed, "regie", floor_index, decision_n)` |
| Grenzen | dieselben wie 5.7 (1 aktiv, 90 s Abstand, ≤ 4 je Etage, ≤ 1 `spicy`); zusätzlich Regie ≤ **3** je Etage |
| Aufzeichnung | wie jeder Twist: `{"t": "twist", "twist": {…, "src": "regie", "tick"}}` — so bleibt die KI später ein reiner Austausch der Auswahl |
| Zeilen | geschriebene `twist_applied_<id>`-Zeilen (Block D) + eine Ansage `regie_cut_in` („Die Regie greift ein!“) |
| Aus | Pur-Liga, gewertete Event-Läufe (dort nur `schedule`), Einstellung „Regie-Eingriffe: aus“ |

### 5.8 Latenz & Fallback

- Das Spiel **wartet nie** auf die KI. Story-, Regel- und Pflichtzeilen kommen immer aus dem Skript (`Show.say`).
- KI-Zeilen füllen **Sendepausen**: frühestens 8 s nach der letzten M.O.D.-Zeile, niedrigste Priorität (unter `ModAnnouncer`-Rang
  „Rest“), nie während `death`/`boss_*`/`timer_*`.
- Server-Deadline 4 s ohne Retry (Route `lines`), Client-Timeout 6 s je Runde; Antworten, die älter als 12 s (Lauf-Uhr) sind,
  werden verworfen (außer `tag: "live:evergreen"`). Twist-Vorschläge gelten bis 20 s nach der Runde und werden bei der Anwendung
  **neu** geprüft.
- Zielwerte (messen in S1, je Modell im Vergleich 5.5): Median < 3 s, p95 < 4 s je Runde **[zu prüfen]** — für Opus 5.5 (denkt
  immer) eher optimistisch. Status über `Events.mod_live_status`
  (`off` / `ok` / `degraded`); bei 3 Fehlern in Folge pausiert der Link 5 min (Skript spricht weiter, niemand merkt es).
  Als Fehler zählt alles außer einer 2xx-Antwort mit gültigem JSON-Objekt (also auch 429, 413, 5xx und Fehler-JSON);
  das Sitzungs-Token ist an `run_ref` gebunden und wird bei jedem neuen Lauf (neues Spiel, Laden) verworfen
  (Integration Runde 4).

### 5.9 Inhaltssicherheit

1. **Persona-Regeln** im System-Prompt: fiktive Moderatorin; siezt Kai; Ton nach GDD §11.1; Zielscheibe Show/Konzern/Bürokratie;
   verboten: reale Politik/Parteien/Personen/Marken, sexuelle Inhalte, Beleidigungen/Slurs, Gewaltverherrlichung über Comic-Niveau,
   Kauf-/Spendenaufrufe, Echtgeld, persönliche Daten, Behauptung ein Mensch zu sein.
2. **Eingabe-Hygiene:** **Kein vom Client gelieferter String erreicht den Prompt.** In den Prompt gelangen nur katalog-geprüfte
   IDs/Enums und Zahlen in Bereichen (5.4) sowie die vom **Dienst selbst** gespeicherten letzten Zeilen je `run_ref` — kein
   Freitext von Spieler:innen oder Zuschauer:innen (keine Namen, kein Chat), keine vom Client zurückgeschickten Zeilen. Ein
   manipulierter Client kann so weder Anweisungen einschleusen noch „die KI des Spiels“ zu Ausfällen provozieren. Zuschauer-Einfluss
   später nur als aggregierte Zahlen (Stimmen, Applaus).
3. **Post-Filter** (Dienst **und** Client `Show.say_external`): Länge ≤ 110, nur `{name}` als Platzhalter, keine URLs/Ziffernfolgen
   wie Telefonnummern. **Harte Sperrliste nur** für Slurs, sexuelle Begriffe und Politik-Begriffe/Namen (Einzelwort-Treffer).
   **Kaufdruck als Phrasen-/Ko-Vorkommens-Regel:** verworfen wird eine Zeile nur, wenn ein Dringlichkeitswort („schnell“,
   „nur noch“, „letzte Chance“, „jetzt“) **zusammen** mit einem Kaufbezug („Sponsor“, „Geschenk“, „Kauf“/„kauf“, „Fenster“, „Spende“,
   „Bits“, „€“) vorkommt; Kaufbezugs-Wörter mit Geldbezug („€“, „Bits“, „spende“, „kauf“) sind auch allein gesperrt (L13/L16).
   „Schnellschnitt!“ oder „nur noch zwei Räume“ bleiben erlaubt. **Sprachprüfung Deutsch:** ≥ 25 % der Wörter aus einer deutschen
   Stoppwortliste (≈ 200 Einträge) **und** ≤ 10 % aus einer englischen; Zeilen < 4 Wörter sind ausgenommen. Treffer → Zeile
   verworfen und je Regel gezählt; die **Fehlalarmquote** wird in S1 an 300 Stichproben-Zeilen gemessen (Ziel < 1 %, Teil des
   S1-Gates neben „Filter-Treffer < 2 %“).
4. **L13/L16 (05):** Die KI erwähnt Sponsor-Fenster, Geschenke und Preise **nie**; Dank für Geschenke bleibt bei den geschriebenen,
   preisunabhängigen Zeilen.
5. **Not-Aus:** Server-Flag schaltet alle KI-Antworten auf leer; Stichproben-Review (Humor-Redaktion) wöchentlich in S1–S3.
6. **Plattformen:** Steam verlangt die Offenlegung von live generierten KI-Inhalten und Schutzmaßnahmen **[zu prüfen]**;
   Altersfreigabe-Ziel USK/PEGI 12 (04 Kap. 1.3) bleibt Maßstab für den Filter.

### 5.10 Datenschutz & Sicherheit

- **Keine personenbezogenen Daten im Prompt:** kein Spielername (nur `{name}`), keine Account-, Geräte- oder IP-Daten;
  `run_ref` ist ein zufälliges Pseudonym je Lauf.
- **Schlüssel nur serverseitig** (`ANTHROPIC_API_KEY` aus dem Secret-Store).
- **Wer stellt das Sitzungs-Token aus?** Ein Token-Endpunkt von mod-brain, **nur gegen Plattform-Authentifizierung**: Steam
  (Session-Ticket, serverseitig über die Steam-Web-API geprüft **[zu prüfen]**), Konsolen-/Mobile-Äquivalent bzw. Konto-Login des
  eigenen Shops. Das Token (≤ 30 min, signiert mit `MOD_BRAIN_TOKEN_SECRET`) trägt eine pseudonyme Konto-ID (Hash, nie die
  Plattform-ID im Klartext) und `run_ref`. Ohne gültige Plattform-Auth kein Token → wer den Ablauf aus dem Client extrahiert,
  kann ohne eigenes, gültiges Konto kein Budget verbrennen. S1 Dev: nur `localhost`/Staging mit Dev-Token aus der Umgebung.
- **Deckel (eine Zahl für alles):** Takt **40 s**, Höhepunkte ziehen vor (min. 20 s Abstand), **≤ 90 Runden/h je Konto** (Token-
  Bucket, Burst 3/min) und **≤ 400 Runden/Tag je Konto** [Startwerte]; 1 Twist/90 s. Anfragegröße ≤ 8 KB, striktes Schema.
- **Globales Monatsbudget** (`MOD_BRAIN_MONTHLY_BUDGET_USD`) mit **automatischem Not-Aus**: Bei 80 % Warnung an den Betrieb, bei
  100 % liefert der Dienst nur noch leere Runden (Skript übernimmt, Status `degraded`) bis zum Monatswechsel oder manueller Freigabe.
- **Kosten-Log je `run_ref`** (Eingabe-/Cache-/Ausgabe-Tokens × Preis) und je Konto-Pseudonym → Auswertung „Kosten je Spielstunde“
  real statt geschätzt (S1-Gate).
- Logs: pseudonymisiert, Aufbewahrung 14 Tage (S1), für Missbrauchs- und Qualitätsanalyse; Datenschutzerklärung nennt die
  Verarbeitung (nur bei Opt-in) **[DSGVO-Prüfung vor S1-Außentest, zu prüfen]**.

### 5.11 Kosten je Spielstunde **[zu prüfen]**

Annahmen je Runde: System 4 000 Tokens aus dem Cache, 900 variable Eingabe-Tokens, 350 Ausgabe-Tokens (inkl. Denken bei `low`);
**90 Runden/h** — identisch mit Takt (40 s) und Konto-Deckel (5.10), also eine **Obergrenze**, kein Mittelwert; ~4
Cache-Schreibvorgänge/h (Start, Pausen > 5 min). Preise: Stand Skill-Referenz 2026-10-06, vor einer Budgetentscheidung prüfen.

| Modell | Preis Eingabe / Ausgabe / Cache-Lesen je 1 M | ≈ je Runde | **≈ je Spielstunde** |
|---|---|---|---|
| `claude-opus-5-5` (Standard) | $4 / $20 / $0.20 | $0.011 | **≈ $1.0–1.2** |
| `claude-sonnet-5-5` | $2 / $10 / $0.20 | $0.006 | ≈ $0.55–0.65 |
| `claude-haiku-5-5` | $0.10 / $0.50 / (≈ $0.01) | $0.0003 | ≈ $0.03 |

**Einordnung:** Bei einem Premium-Spiel (19,99 €, ~20 h Spielzeit) wären Opus-Kommentare **pro Spieler:in** dauerhaft zu teuer
(≈ $20+ je Kopf). Deshalb:

- **Kampagne:** Standard bleibt Skript + **Regie offline** (5.7a, keine Laufzeitkosten) + KI-Redaktion offline. „M.O.D. live“ ist
  Opt-in (Beta, Streamer:innen); realistisch nur mit Sonnet/Haiku auf der Route `lines` — Entscheidung nach dem S1-Modellvergleich.
- **Live-Sendungen (SHOWRUN):** **eine** KI-Regie je Sendung, nicht je Zuschauer:in → Opus ≈ $2–3 pro 90-min-Sendung, unabhängig von
  der Zuschauerzahl. Hier passt das Standardmodell am besten.
- **KI-Redaktion (S0.5):** Entwürfe per Batch-API (−50 %) — Cent-Beträge je 100 Zeilen.

### 5.12 Stufen

| Stufe | Inhalt | Gate (weiter, wenn …) |
|---|---|---|
| **S0 (jetzt)** | Skript-M.O.D. wie heute; `ScriptedModVoice` als Standard-Provider; Twist-Katalog + `TwistApplier` + **`RegieDirector`** offline nutzbar (Regie ab E2, Debug F6, Tests, Event-Fahrplan); Referenz-Dienst mit gemocktem Client getestet | Pakete A–D grün |
| **S0.5** | **KI-Redaktion**: Claude erzeugt Spruch-Entwürfe je Tag (Batch), Humor-Redaktion wählt aus → `mod_lines.json` | ≥ 30 % der Entwürfe „sendefähig“ laut Redaktion |
| **S1** | KI-Zeilen über `mod-brain` (Staging), nur Dev-/Debug-Builds, Einstellung „M.O.D. live: Kommentar“; Token nur gegen Plattform-Auth, Budget-Not-Aus aktiv | **Modellvergleich** Opus 5.5 / Sonnet 5.5 / Haiku 5.5 auf `lines` (je 100 Runden blind: Humor-Score, Latenz, Kosten); für das gewählte Modell: Median-Latenz < 3 s, Filter-Treffer < 2 %, Fehlalarmquote des Filters < 1 %, Redaktion bewertet ≥ 60 % „lustig oder passend“, Kosten je Stunde aus dem `run_ref`-Log gemessen |
| **S2** | KI-Twists (Kampagne Opt-in „Kommentar + Regie“), Streamer-Modus; Votes nutzen denselben Katalog (05 S2) | 0 Replay-Abweichungen in 1 000 Bot-Läufen mit Twists, Playtest: Twists als „fair“ bewertet (≥ 70 %) |
| **S3** | Live-Events mit Publikum: eine KI-Regie je Sendung, kombiniert mit Votes (05 S2/S3); Zuschauer-Input nur aggregiert | Rechts-/Plattformprüfung (Offenlegung, Jugendschutz), Moderations-Prozess steht |

---

## 6. Entscheidungen zu den fünf offenen Sponsor-Fenster-Fragen (05 Kap. 12.2 Nr. 17/18)

> **Stand Paket C (2026-10-10): alle fünf umgesetzt bzw. dokumentiert** — 1 Overlay/Zeilen ohne Sekunden, 2 geprüft (Fan-Pakete
> fensterpflichtig, Cheers nie), 3 Comeback-Fenster im Kern (`boss.comeback`), 4 `SponsorWindows.team_slots` + Regeltext 05 Kap. 6.13
> (Umsetzung im Kern mit S4), 5 Regeltext + Test (`bits` nie Geschenkquelle). 05 Kap. 1.5/6.12/6.13/12.2 nachgezogen.

| # | Frage | **Entscheidung** | Begründung |
|---|---|---|---|
| 1 | Overlay mit Sekunden-Countdown? | **Nein.** Offen: **„SPONSOR-FENSTER OFFEN“** + Platz-Symbole (●●○ = 2 von 3 belegt), voll: „SPONSOR-FENSTER VOLL — danke!“, zu: **„Nächstes Fenster in ~3 Min.“** (aufgerundete Minuten; < 60 s: „in Kürze“; „~“, weil Kampf/Safe Room pausieren). Keine Dringlichkeitswörter („schnell“, „nur noch“, „letzte Chance“). M.O.D.-Zeilen `sponsor_window_open*` ohne `{seconds}`/`{count}`. **Kauf-Flow zeigt nie Timer oder Knappheit** (Platz ist bei der Quote reserviert). Kern rechnet weiter in Ticks — nur die Darstellung ändert sich. | Countdown + knappe Plätze wirken als künstliche Dringlichkeit (R15, L16; Dark-Pattern-Regeln wie DSA Art. 25 **[zu prüfen]**). Die Information „offen/zu/voll/wann ungefähr“ reicht zum Planen und ist einfacher zu lesen. Schließt 05 Nr. 18. |
| 2 | Kostenlose Fan-Pakete auch fensterpflichtig? | **Ja** (wie umgesetzt). **Cheers sind immer kostenlos und nie fensterpflichtig.** | Ein Fenster ist ein Programmpunkt, kein Kaufmoment; gleiche Regeln für bezahlt und gratis verhindern „zahlen, um das Fenster zu umgehen“ und Gratis-Spam. Cheers bleiben der jederzeitige Ausdruck von Unterstützung. |
| 3 | Boss-Countdown nach verlorenem Versuch neu? | **Ja, einmal** („**Comeback-Fenster**“, 45 s, gleiche Plätze), solange der Boss unbesiegt ist; höchstens 1× je Boss und Etage. Kampagne: `Save.record_game_over` vermerkt eine Boss-Niederlage im Slot (`flags.live.sponsor.comeback`), das Fenster öffnet beim nächsten Betreten des Boss-Raums auch dann, wenn der geladene Stand den Raum schon als besucht führt. Läufe, die nach einer Niederlage weitergehen (S2+ `rules.continue_on_defeat`), nutzen dieselbe Markierung im laufenden Zustand. M.O.D. (nur live): `sponsor_window_open:boss_comeback` ohne Kaufbezug. | Das Comeback ist der stärkste TV-Moment; einmalig, damit es nicht farmbar ist. Deterministisch, weil die Markierung Teil des Zustands ist. |
| 4 | Koop: Plätze je Spieler:in oder je Team? | **Fenster je Team (eine Sendung), Plätze je Spieler:in** (`slots_per_player` = 3 je Person und Fenster); `per_viewer` = 1 Geschenk je Zuschauer:in **je Fenster und Team**. | Fair zwischen Teammitgliedern (der/die bekannteste Streamer:in belegt nicht alle Plätze), Caps je Spieler:in (L4) bleiben gültig; eine Zuschauer:in kann nicht alle vier beschenken. Wird mit S4 umgesetzt. |
| 5 | Twitch Bits? | **Nur kostenlose Interaktion** (Votes, Applaus); **Echtgeld ausschließlich über den eigenen Shop** (Web + App-IAP). | Brief-Entscheidung (1) 2026-10-08 / L11: Bits-Erlöse gehen nach Kenntnisstand an die Broadcaster:in **[zu prüfen]**. Schließt 05 Nr. 4/13 endgültig. |

Kampagne ohne echte Zuschauer (05 Nr. 17e): Der dezente Hinweis bleibt (wie umgesetzt), ebenfalls ohne Sekunden.
`realtime`-Modus (Nr. 17c) bleibt bis S4 offen.

---

## 7. WoW-Perspektive (MMO-lite auf eigener Geschichte)

**Grundsatz:** Erst Spaß im Slice beweisen (Gate Phase 2, 04 Kap. 3.4), dann ausbauen. MMO-lite ist eine **Option nach 1.0**
mit eigenem Gate — kein heutiger Umfang. Was wir heute bauen, verbaut den Weg nicht, sondern bereitet ihn vor.

| Baustein | WoW-Entsprechung | Unsere Form | Phase (04) | Baut auf |
|---|---|---|---|---|
| Rollen | Klassen/Specs | Spezies + Spezialisierung + Talente → Tank/Heiler/Schaden/Show | Phase 4 (E3) | Kap. 2–3, `classes.json`, `species.json`, `talents.json` |
| Gilden | Gilden | NPC-Fanclubs → später **Spielergilden** (gleiche Daten: `gld_`, Rang, Auftragsbrett) | Phase 4 (NPC), Phase 7 (Spieler) | 2.4, Quest-Typen 05 |
| Gruppe | Party | Duo → 3. Figur → Koop 2–4 | Phase 4 / S4 | 2.5, 05 Kap. 1.4 |
| Hub | Hauptstadt | **„Senderzentrale“**: Safe-Room-Stadt zwischen Etagen (Casting-Büro, Fanclub-Häuser, Händler, Trophäenraum, Wiederholungen) | Phase 5 | Safe-Room-Kit |
| Raids | Raids | **„Großproduktionen“**: 2 Teams à 4 gegen Etagenboss-Varianten, Server-Instanz | nach S4 | 05 Server-Autorität, Lockstep |
| Seasons | Seasons | **Staffeln** (04: Staffel 1 = E1–6, Staffel 2 = E7–9) + saisonale Ranglisten/Kosmetik | Phase 7 | SHOWRUN S1 |
| Berufe | Professions | **Nebenjobs**: Requisite (Ausrüstung aufwerten), Catering (Verbrauchsitems), Maske (Kosmetik), Technik (Gadgets) | Phase 5 | Item-Daten, Shop |
| PvP | Arena | nur **„Quotenduell“** (asynchrones Punkte-Rennen auf gleichem Seed), kein direktes PvP | S1+ | Bestenlisten |
| Weltereignisse | World Events | Live-Sendungen mit KI-Regie + Votes | S3 | Kap. 5, 05 |

**Neue ID-Präfixe reserviert:** `gld_` (Fanclubs/Gilden), `job_` (Nebenjobs), `ssn_` (Staffeln/Seasons), `raid_` (Großproduktionen).

**Ergänzung für 04 Kap. 3 (Roadmap):** Phase 3 — Talente/Spezies-UI-Prototyp; Phase 4 — Casting (E3), Fanclubs (E2), 3. Figur,
Show-Bosse, Sammelkarten; Phase 5 — Senderzentrale, Nebenjobs light, 2. Spezialisierung (E6); Phase 7 — Spielergilden, Staffel-
Ranglisten; **Option „PRIME TIME ONLINE“** nach 1.0 mit Gate: S4 stabil (0 Desyncs), Server-Kostenmodell je Spieler:in, Finanzierung
für Live-Betrieb, ≥ 85 % positive Reviews. Leitplanken bleiben: kein Pay-to-Win, keine gekauften Zufallsinhalte für Spieler:innen.

---

## 8. Umsetzung JETZT: Pakete A–D

### 8.0 Reihenfolge & Konfliktvermeidung

**Schritt 0 — Vertrags-Commit (Integrator, sequenziell vor A–D, ≈ ½ Tag).** Wie die Stub-Phase in 02_TECH §0.2 legt **eine** Person
alle Änderungen an gemeinsam genutzten Dateien als fertige, dünne Fassaden bzw. Stubs an. Danach ändert jedes Paket nur noch
**eigene** Dateien (Tabelle 8.1). Neue Stub-Dateien beginnen mit `# STUB(06-0) — owned by 06-<A|B|C|D>. Replace completely, keep the
public API.` Grün-Kriterium Schritt 0: `tools/check.sh` grün, `tools/fullrun.sh --strategy=all` grün (Verhalten unverändert).

Inhalt von Schritt 0:

1. **`autoload/events.gd`** — vier Signal-Blöcke (je Paket ein kommentierter Block, Emitter-Tabelle 02_TECH §3.2 ergänzt;
   `test_m0_autoloads` aktualisiert):
   ```gdscript
   # --- Hero & field abilities (06 §1, package A) ---------------------------------
   signal hero_changed(hero_id: String)
   signal field_ability_used(hero_id: String, ability: StringName, hits: int)   # &"strike" | &"bark"
   signal secret_opened(secret_id: String)                                       # Kulissenwand / Regie-Notiz
   # --- Talents & casting (06 §2/§3, package B) ----------------------------------
   signal talent_pending(member_id: String, level: int)
   signal talent_picked(member_id: String, talent_id: String)
   # --- Show bets / Marotten / Liga (06 §4, package C) ----------------------------
   signal marotten_announced(ids: PackedStringArray)
   signal marotte_progress(marotte_id: String, hits: int, goal: int)
   signal marotte_won(marotte_id: String)
   signal liga_changed(tier: int)
   signal show_boss_spotted(encounter_id: String)
   # --- KI-Admin (06 §5, package D) -------------------------------------------------
   signal twist_applied(twist: Dictionary)
   signal twist_ended(twist_id: String)
   signal mod_live_status(status: StringName)                                   # &"off" | &"ok" | &"degraded"
   ```
2. **`core/live/command.gd`** — `TYPES` += `"hero"`, `"talent"`, `"casting"`, `"secret"`, `"twist"` (Twist wird vom Hook zum echten
   Typ; `EXTERNAL` bleibt `["gift", "twist"]`); Feldprüfung: `hero {id}`, `talent {member, id}`, `casting {member, species, class}`,
   `secret {id}`, `twist {twist: Dictionary}` mit Pflichtschlüsseln `schema, id, n, src, params, duration, tick` (optional `req`,
   `vote_id`; Kap. 5.7). Replay-Puffer für `twist` bis `tick`, Abweichung `twist_tick_passed`.
3. **`autoload/game.gd`** — fertige Fassaden (Rumpf: Wächter → `record` → Kern-Klasse → Signal) und die Replay-Zweige:
   `new_game(…, hero: String = "kai")` (prüft `HeroRules.check_initial`), `set_hero(id) -> bool` (prüft `check_set`),
   `pick_talent(member_id, talent_id) -> bool`, `choose_casting(member_id, species_id, class_id) -> bool`,
   `open_secret(secret_id) -> bool`, `apply_twist(twist: Dictionary) -> String` (Grund, `""` = angewendet; setzt `tick` selbst),
   `twist_effect_pm(key: String, default_pm: int) -> int`; Aufrufe `TwistApplier.on_battle_end(state)` und
   `MarottenRules.on_battle_end(state, data, result, tally)` (Stub `{}`) in `apply_battle_result`, `MarottenRules.on_zone(…)` am
   Erkundungs-Tick, `RegieDirector.decide(…)` alle 120 s Erkundungszeit (Stub `{}`), `TwistApplier.on_safe_room(state)` in
   `enter_safe_room`, Twist-Effekt in `open_chest` (Credits). `ModLiveLink` wird in `_ready` nur angelegt, wenn
   `settings.mod_live != &"off"` und nicht ephemer.
4. **Zustand** (alle additiv, Defaults beim Laden → **kein Save-Versionssprung**, `SaveCodec.VERSION` bleibt 1; feste Hash-Erwartungen
   in Tests werden in Schritt 0 nachgezogen):
   `GameState.hero: String = "kai"` · `PartyMember.talents: Dictionary` (id → Rang), `talent_pending: PackedInt32Array`,
   `species_id: String = ""` · `ShowState.marotten: Dictionary = {}` (aktive Vorlieben, Herzen, `zones_since_battle`, `tally`,
   Basis-Follower-Zähler `followers_gained_base`) · Twist-/Comeback-Zustand unter `flags["live"]`, Geheimnisse unter
   `flags["secrets"]` (kein Feld).
   **Multiplikatoren als Ganzzahl-Promille (festgelegt):** neu `GameState.hype_gain_pm(data) -> int` und `follower_pm(data) -> int`
   = Promille-Produkt aus Ausrüstungs-`show_mods` (beim Laden einmal `roundi(x * 1000)`), `Talents.hype_pm/follower_pm(state, data)`,
   `MarottenRules.liga_pm(state, data, &"hype"|&"follower")` und `TwistApplier.effect_pm(state, "hype_gain_pm", 1000)`; jeder
   Schritt `(a * b + 500) / 1000` (round half up). Alle Faktoren sind **statisch und rein** und lesen nur `GameState`/`ShowState`
   — kein Zugriff auf Autoload-Instanzen, daher identisch in `RunSim`/Verifier. Die bisherigen `hype_gain_mult/follower_mult`
   (`game_state.gd`, `float`) bleiben als dünne Hülle `float(…_pm(data)) / 1000.0` für vorhandene Aufrufer; Schritt 0 stellt die
   Kern-Aufrufer auf die Promille-Variante um. Test: mit heutigen Daten identische Hype-/Follower-Werte wie vorher.
   **Umgesetzt (Paket B + Integration, Stand B-9):** `hype_gain_pm`/`follower_pm` mit Talenten; das Ausrüstungsprodukt wird
   wie bisher einmal am Ende gerundet (`roundi(Produkt × 1000)`, bit-gleich zu vorher), `hype_gain_mult/follower_mult` bleiben
   reine Ausrüstungs-Floats (Anzeige, `BattleSetup.show_mods`); Show nutzt nur die Promille-Werte. C/D hängen
   `liga_pm`/`effect_pm` als weitere `(a × b + 500) / 1000`-Schritte an.
5. **`autoload/game_settings.gd`** — `partner_auto: bool = false` (`game/partner_auto`), `show_bets_hud: bool = true`
   (`game/show_bets_hud`), `regie_twists: bool = true` (`game/regie_twists`), `mod_live: StringName = &"off"` (`live/mod_live`:
   `off | lines | lines_twists`), `mod_live_url: String = ""` (`live/mod_live_url`, nur Debug-Builds/Kommandozeile `--mod-live-url=`).
6. **`autoload/show.gd`** — nur Darstellung: Marotten-/Liga-Ergebnisse kommen als Dictionaries aus dem Kern (Signale
   `marotte_progress`, `marotte_won`, `liga_changed`) und werden zu Zeilen/Toasts (Rumpf C); `ActionEvent`s des laufenden Kampfes
   gehen an den Kern-`MarottenTracker` (Strichliste, Stub no-op). Funktion `say_external(text: String, voice: StringName,
   tag: String) -> bool` (Stub `false`).
7. **Daten & Validierung** — `GameData.TABLES` += `"talents"`, `"species"`, `"marotten"`, `"twists"` (13 → 17), Def-Klassen
   `TalentDef`, `SpeciesDef`, `MarotteDef`, `TwistDef` (Stubs mit allen Feldern), Getter (`talent()`, `species_def()`, `marotte()`,
   `twist()`, `all_*`) + `DB`-Fassade. **Validator aufgeteilt:** `data_validator.gd` ruft je Tabelle eine eigene Datei
   `core/data/validators/{talents,species,marotten,twists,secrets,show_boss}.gd` (statisch `check(data, errors)`, Stub leer) — jedes
   Paket ändert nur seine Datei, `data_validator.gd` danach niemand mehr. Im Gerüst: ID-Regexe `^tal_…`, `^spc_…`, `^mar_…`, `^tw_…`,
   `^sec_…`, `ACH_TRIGGERS` += `"show_bet"` (+ Payload-Schlüssel), `STAT_IDS` += `bets_won`, `liga_battles`,
   `OPTIONAL_MOD_TAG_PREFIXES` += `"hero_"`, `"talent_"`, `"casting_"`, `"marotte_"`, `"liga_"`, `"mod_live_"`, `"regie_"`,
   `"showboss_"` (`chat_bark` ist über das vorhandene Präfix `chat_` bereits erlaubt). Minimal gültige
   `data/{talents,species,marotten,twists}.json` (je 1 Eintrag) + `tests/fixtures/data_min/*.json`; in `floors.json` (E1) ein leeres
   `layout.secrets: []` (Besitz A) und ein Platzhalter-Eintrag `enc_e1_showboss` mit `show_boss: {}` (Besitz C) als getrennte Blöcke.
8. **`data/mod_lines.json`** — je Paket **ein Anker-Eintrag** an getrennten Stellen (`mod_hero_pick_kai_01` hinter den `intro`-Zeilen,
   `mod_talent_pick_01` hinter `level_up`, `mod_marotte_won_01` hinter `achievement_generic`; für D ein **neuer Block am heutigen
   Dateiende** mit `mod_twist_applied_tw_overtime_01` — weit weg von den `sponsor_window_*`-Zeilen, die C umschreibt). **Jedes Paket
   fügt seine Zeilen als Block direkt hinter seinem Anker ein — nie hinter fremde Blöcke.**
9. **Twist-Effekt-Hooks** (Einzeiler, Stub liefert neutral): `scenes/exploration/enemy_actor.gd` (Sicht/Gehör ×
   `Game.twist_effect_pm("enemy_sight_pm"/"enemy_hear_pm", 1000)`), `core/progression/battle_bridge.gd` (`apply_result`: Credits),
   `core/progression/shop.gd` (Preis), `core/live/run_sim.gd` (Aufruf `TwistApplier.tick` + Hype-Zerfall-Pause).
10. **`scenes/boot/fullrun.gd` + `tools/fullrun.sh`** — Argumente `--hero=kai|mopsula` und `--liga=0|1|2` werden geparst und an drei
    leere Hook-Funktionen übergeben (`_apply_hero_choice`, `_apply_liga_strategy`, `_pick_pending_talents`), je Paket gefüllt.
11. **Stub-Klassen:** `core/progression/hero_rules.gd`, `core/dungeon/secrets.gd` (A), `core/progression/talents.gd`,
    `core/progression/casting.gd` (B), `core/show/marotten_tracker.gd`, `core/show/marotten_rules.gd`, `core/battle/show_boss_rules.gd`
    (C; Hook-Zeile `ShowBossRules.apply(setup, encounter)` in `BattleBridge.make_setup`), `core/live/twist_applier.gd`,
    `core/live/regie_director.gd`, `core/show/mod_live_summary.gd`,
    `autoload/mod_voice/{mod_voice_provider,scripted_mod_voice,remote_mod_voice,mod_live_link}.gd` (D).
12. **UI-Andockpunkte für fremde Pakete** (damit niemand in fremde Szenen schreibt):
    - `scenes/ui/settings_menu.gd` (Besitz A): fertige Zeilen „Show-Wetten anzeigen“ (C), „Regie-Eingriffe“ und „M.O.D. live“ (D),
      direkt an `GameSettings` gebunden — C/D ändern nur Texte/Hilfetexte per Änderungsantrag, nie den Code.
    - `scenes/battle/ui/battle_results.gd` (Besitz B): Signal `results_shown(result: BattleResult)` und leerer Slot
      `show_slot: Control`; C hängt `scenes/ui/bets_results_fx.gd` (Herz-Flug, Toast) dort an.
    - `scenes/ui/pause_menu.gd` (Besitz C): `register_badge_provider(tab: StringName, provider: Callable)`; B registriert den
      „!“-Badge für offene Talente, ohne die Datei zu ändern.
    - `scenes/safe_room/safe_room.gd` (Besitz A): Menüeinträge „Figur wechseln“ (A) und „Talent-Show“ (B, öffnet
      `scenes/ui/talent_show.tscn`, Stub-Szene im Besitz B).
    - `scenes/ui/equipment_menu.gd` (Besitz C): leere Zeile `liga_line: Label` für „Liga blockiert durch: …“.
13. **Docs:** 02_TECH erhält Änderungsanträge **CR-16 (A) … CR-19 (D)** mit Verweis auf dieses Kapitel.

**Danach** arbeiten A–D parallel. Braucht ein Paket eine Änderung an einer Datei eines anderen Pakets oder an einer Schritt-0-Fassade,
geht das als Änderungsantrag an den Integrator (02_TECH §0.2), nicht als eigener Edit. **Merge-Reihenfolge** A → B → C → D (keine
harten Abhängigkeiten; nach jedem Merge Gate 8.6).

### 8.1 Dateibesitz nach Schritt 0

| Datei / Bereich | Schritt 0 | A | B | C | D |
|---|---|---|---|---|---|
| `autoload/events.gd`, `core/live/command.gd`, `autoload/game.gd`, `autoload/game_settings.gd` | ✎ | — | — | — | — |
| `core/progression/game_state.gd`, `party_member.gd`, `core/show/show_state.gd`, `core/data/game_data.gd`, `autoload/db.gd` | ✎ | — | — | — | — |
| `core/data/data_validator.gd` | ✎ Gerüst (danach eingefroren) | — | — | — | — |
| `core/data/validators/*.gd` | ✎ Stubs | `secrets.gd` | `talents.gd`, `species.gd` | `marotten.gd`, `show_boss.gd` | `twists.gd` |
| `autoload/show.gd` | ✎ Hooks | — | — | Rumpf Marotten-/Liga-Darstellung | Rumpf `say_external` |
| `data/mod_lines.json` | ✎ Anker | Block A | Block B | Block C + Umschreiben `sponsor_window_*` | Block D (eigener Block am Ende) |
| `data/floors.json` (E1) | ✎ Platzhalter | `layout.secrets` | — | Eintrag `enc_e1_showboss` | — |
| `scenes/boot/fullrun.gd`, `tools/fullrun.sh` | ✎ Hooks | `_apply_hero_choice` | `_pick_pending_talents` | `_apply_liga_strategy` | — |
| `scenes/exploration/enemy_actor.gd` | ✎ Twist-Zeile | Zustand `DAZED` | — | — | — |
| `core/progression/battle_bridge.gd` | ✎ Twist-Zeile, Show-Boss-Hook | — | Talent-Krit/Element/MP/Präventiv | — | — |
| `core/progression/progression.gd` | — | — | ✎ Talente/Spezies in `total_stats`, `talent_pending` (ungerade Level ab L3) | — | — |
| `core/live/run_sim.gd`, `core/progression/shop.gd` | ✎ Hooks | — | — | — | Rumpf (Twist-Ticks, Replay-Puffer) |
| `scenes/ui/settings_menu.gd` | ✎ Zeilen für C/D | ✎ (Rest, Schalter „Partner automatisch“) | — | — | — |
| `scenes/battle/ui/battle_results.gd` | ✎ Signal + Slot | — | ✎ (Chip „Talent bereit“) | `bets_results_fx.gd` am Slot | — |
| `scenes/ui/pause_menu.gd` | ✎ Badge-Provider | — | registriert Provider | ✎ (Tab „Show“) | — |
| `scenes/safe_room/safe_room.gd` | ✎ Menüeinträge | ✎ (Rest) | `talent_show.tscn/.gd` | — | — |
| `core/live/sponsor_windows.gd`, `core/live/score_calc.gd`, `autoload/save.gd`, `scenes/ui/show_overlay.gd`, `scenes/ui/equipment_menu.gd`, `core/battle/show_boss_rules.gd` | — | — | — | ✎ | — |
| `data/achievements.json`, `core/show/stat_ids.gd`, `tests/test_m7_data_content.gd` (Anzahl 29 → 35) | `stat_ids` ✎ | — | — | ✎ | — |
| Szenen Titel/Erkundung/Kampf-Steuerung/Touch, `core/dungeon/secrets.gd` | — | ✎ | — | — | — |
| `scenes/ui/party_menu.gd`, `core/battle/action_resolver.gd` | — | — | ✎ | — | — |
| `core/live/regie_director.gd`, `scenes/ui/debug_overlay.gd`, `scenes/ui/global_ui.gd`, `.github/workflows/ptd-check.yml`, `services/**` | — | — | — | — | ✎ |

### 8.2 Paket A — Heldenwahl, Bellen, Partner automatisch, E1-Geheimnisse

**Ziel:** Kap. 1 vollständig spielbar; E1-Kostprobe Erkunden (Kap. 2.7: 1–2 Kulissenwände, 3 Regie-Notizen); Timer-Balancing
unverändert (Abkürzung ist Bonus, nicht Pflicht).

| Art | Dateien |
|---|---|
| Neu | `core/progression/hero_rules.gd` (`HeroRules`), `core/dungeon/secrets.gd` (`Secrets`: `check_open`, `open`, Wirkung Abkürzung/Notiz), `scenes/title/hero_select.tscn` + `.gd`, `scenes/exploration/scenery_wall.gd` (rissige Wand, Szenenlogik), `tests/test_06a_hero.gd`, `tests/test_06a_bark.gd`, `tests/test_06a_partner_auto.gd`, `tests/test_06a_secrets.gd` |
| Geändert (eigen) | `scenes/title/title_flow.gd` (Ablauf Slot → Figur → Name → Modus), `scenes/title/name_entry.gd` (Überschrift je Figur), `scenes/exploration/exploration.gd` (Held:in/Partner-Spawn, Kulissenwände/Notizen aus `layout.secrets`), `player_controller.gd` (Rig + Kapsel je Figur, Aktion Feldschlag/Bellen, trifft auch Kulissenwände), `companion_follower.gd` (folgt der Held:in), `encounter_rules.gd` (`BARK_*`, `DAZE_*`, Vorteilsregel, Talent-Faktoren Reichweite/Cooldown über `Talents`), `enemy_actor.gd` (Zustand `DAZED`), `minimap.gd` (geöffnete Wände), `scenes/safe_room/safe_room.gd` (Rumpf „Figur wechseln“), `scenes/battle/battle_controller.gd` (Partner automatisch), `scenes/battle/ui/party_panel.gd` (Stern-Marker), `scenes/ui/settings_menu.gd` (Schalter „Partner automatisch“, ohne Tutorial-Zeile), `scenes/ui/touch_controls.gd` (Aktions-Icon Faust/Schallwelle), `validators/secrets.gd`, `floors.json → layout.secrets`, Block A in `mod_lines.json` (inkl. `secret_note:<n>`), Hook `_apply_hero_choice` in `fullrun.gd` |

**APIs:**

```gdscript
class_name HeroRules extends RefCounted
const HEROES: PackedStringArray = ["kai", "mopsula"]
static func check_initial(state: GameState, hero_id: String) -> String   # "" | "unknown_hero" | "run_started"
static func check_set(state: GameState, hero_id: String) -> String   # "" | "unknown_hero" | "not_in_safe_room" | "same"
static func set_hero(state: GameState, hero_id: String) -> bool
static func partner_of(state: GameState) -> String
static func field_ability(hero_id: String) -> StringName              # &"strike" | &"bark"

# scenes/exploration/encounter_rules.gd (pure, testable)
const BARK_RANGE: float = 4.0
const BARK_ARC_DEG: float = 120.0
const BARK_COOLDOWN: float = 3.0
const DAZE_SEC: float = 2.5
const DAZE_IMMUNE_SEC: float = 15.0
static func bark_hits(origin: Vector3, forward: Vector3, target: Vector3) -> bool
static func advantage_for_contact(state_name: StringName, dot_back: float) -> int   # DAZED → BattleSetup.Advantage.PREEMPTIVE
```

**Tests (Minimum):** Neues Spiel mit `hero` Default/Mopsula; `check_initial` nur vor dem ersten Erkundungs-Tick/der ersten Begegnung;
`set_hero` nur im Safe Room; Command-Aufzeichnung + `Game.replay_log` ergibt denselben Hash mit `hero`-Commands, **auch für einen
Lauf, der als Mopsula beginnt**; alter Spielstand ohne `hero` → `"kai"`; Kulissenwand öffnet mit Feldschlag und mit Bellen, nicht
mit Interagieren, `secret`-Command + Replay = gleicher Hash, Abkürzung im Bot gemessen (Zeitgewinn ≥ 20 s), Notizen geben je
+15 Follower genau einmal, Save-Rundlauf von `flags.secrets`; Bellen-Geometrie (Kegel, Reichweite, Sichtlinie)
und Vorteilsregel (`DAZED` → `PREEMPTIVE` aus jeder Richtung), Immunität 15 s, Bosse unbeeinflusst; Szenentest: Erkundung mit
Held:in Mopsula spawnt das Mops-Rig als Spielerkörper, Kai folgt; Kampf mit `partner_auto`: Partner-Befehle `auto: true`,
Held:innen-Befehle manuell; Hero-Select-Szene: Default-Fokus, Touch-Trefferflächen.

**DoD:** `tools/check.sh` grün; `tools/fullrun.sh --strategy=all` grün; zusätzlich `--hero=mopsula` (Seeds 1–3) erreicht die Treppe;
`tools/perf.sh` ohne Budget-Überschreitung; Screenshots `hero_select`, Erkundung als Mopsula, Kulissenwand vor/nach dem Öffnen;
GDD §1 (E1-Geheimnisse), §2.1/§14.2 und 03_ART (Bellen-VFX, Riss-Wand) nachgezogen.

**Stand Paket A (2026-10-10, Branch `ptd/feat-hero`):** Kap. 1 **umgesetzt** — Figurenwahl (Slot → Figur → Name → Modus → Intro mit
`hero_pick:<id>`), Held:in-Steuerung in der Erkundung (Rig + Kapsel je Figur, Partner folgt), Bellen/`DAZED` mit Vorteilsregel,
„Partner automatisch“, „Figur wechseln“ im Safe Room, M.O.D.-/Chat-Block A, `hero`-Command inkl. `RunSim`/Replay, Save ohne
Versionssprung, Bot `--hero=mopsula` (in `--strategy=all`). Verträge: 02_TECH CR-16 (§0.5), GDD §2.1/§2.4/§10.1/§11.3/§14.2/§14.4/
§14.5/§14.7/§14.8, 03_ART Kap. 7 + A16. Abweichungen (bewusst): Party-Panel markiert die Held:in mit einer Pille **„DU“** (und den
automatischen Partner mit **„AUTO“**) statt eines Sterns — lesbarer auf Touch; die Startwahl wird **immer** aufgezeichnet (auch
`kai`), damit jeder Lauf-Log die Wahl explizit trägt; die Event-Lobby bietet noch keine Wahl (`start_event_run(…, hero_id)` ist
vorbereitet, Default `kai`); Bosse/Fahrscheinfresser „zucken nur“ mit „…“-Blase; die Safe-Room-Liste wurde für sieben Einträge
umgebaut (einzeiliger Kopf, „Speichern | Weiter“ nebeneinander, Status als Banner oben). Ohne Schritt 0 umgesetzt: die geteilten
Dateien tragen kleine, markierte Blöcke (`# 06 package A`).
**E1-Geheimnisse (zweiter Commit) umgesetzt:** `core/dungeon/secrets.gd` (`Secrets`), `core/data/validators/secrets.gd`,
`scenes/exploration/scenery_wall.gd` + `note_interactable.gd`, `layout.secrets` (1 Kulissenwand `sec_e1_wall_sewer` B(5,3)↔C(5,2),
3 Regie-Notizen), Command `secret {id}` / `Game.open_secret`, Signal `secret_opened`, Minimap (stehende Wand = Wand), Etagen-Bilanz
„Regie-Notizen n/3“, Bot-Ziele `wall`/`note` + Abkürzungs-Messung, `tests/test_06a_secrets.gd`. Abweichungen: **nur eine** Wand —
`sec_e1_wall_track` (Nische mit Truhe) bräuchte eine neue Zelle und damit eine neue E1-Karte; Notiz 2 hängt hinter der Wand und
erscheint erst, wenn sie fällt (der Fund gehört zur Wand); Regie-Notizen sind Notizständer mit Post-it statt Post-its an Wänden
(Offsets ≤ 4,5 m halten die Randstreifen frei). **Zeitgewinn im Bot gemessen: ≈ 6 s** (1 Durchquerung, 2 Zellwechsel à 3,1 s) statt
der geschätzten 25–35 s: auf der kompakten E1-Karte spart eine Wand höchstens 2 Zellwechsel je Richtung, und nur solange
`gate_lever` zu ist (der Hebel scheitert in 40 %). Das Ziel „≥ 20 s“ braucht eine Wand an einem längeren Umweg (neue Zelle/Karte, E2).
Ansichten: `docs/screenshots/19_hero_select.png`, `20_explore_mopsula_bark.png`, `21_safe_room_hero_switch.png`,
`22_battle_partner_auto.png`, `23_secret_wall.png`, `24_secret_wall_falls.png`, `25_regie_notiz.png` (Recipes
`hero_mopsula_<zone>`, `bark_<zone>`, `safe_hero_switch`, `battle_partner_auto`, `secret_wall|open|note` in
`tests/capture_recipes.gd`).

**Integration A × B (Runde 2, Branch `ptd/int-06`):** (1) **Feld-Talente** verdrahtet: `HeroRules.field_mods(state, data)` liefert
`field_range_pm`/`field_cd_pm` aus den Talenten der **führenden** Figur (die Talente der folgenden Figur ruhen — „Wirkt, wenn …
die Gruppe anführt.“); `ExplorationScene` setzt sie beim Aufbau und bei jedem `on_resume` (`PlayerController.set_field_mods`);
`EncounterRules.scale_pm` rechnet in ganzen Milli-Einheiten mit Rundung (a · pm + 500) / 1000 (1000 = bitgleich): „Weit ausholen“
→ Feldschlag 2,25 m (auch gegen Kulissenwände), „Bellen in Stereo“ → Bellen 5,0 m (Kegel-FX skaliert), „Schwer vermittelbar“ →
Bellen-Cooldown 2,1 s. Nicht aufgezeichnet (Szenenlogik), Replays sehen das ausgelöste `encounter`/`secret`. Die Talent-Show-Karte
sagt bei der führenden Figur „Wirkt sofort: … führt die Gruppe an.“ (2) **Safe-Room-Menü** in fünf Zeilen — Lootboxen ·
[Automat | Ausrüstung] · Figur wechseln · Mopsula · [Speichern | Weiter] —, jeder Eintrag 64 px sichtbar in 88 px Trefferfläche
(02_TECH §10.2 Regel 5): passt bei 1280×720 und im Handy-Touch-Layout (1600×720) über den Chat-Ticker, „Weiter“ ohne Scrollen.
Der TALENT-SHOW-Knopf (B-2) sitzt jetzt **oben rechts** auf Höhe des ersten Eintrags: unten rechts verdeckte ihn der rechtsbündige
M.O.D.-Kasten, der bei jedem Besuch und nach „Figur wechseln“ spricht. Recipe `safe_hero_talents`, Ansicht
`docs/screenshots/26_safe_room_hero_talents_phone.png`. (3) **Held:in × Talente:** Angebote, Wahlen und Wirkungen hängen am
Mitglied, nie an der gesteuerten Figur; „Partner automatisch“ spielt den Partner mit AutoPolicy auf dem Combatant **mit** seinen
Talenten (Werte, Krit, Element, `talent_mods`). Bekannte CTB-Grenze bis R5 (Orchestrator-Entscheidung, Kap. 8.8): AutoPolicy
stuntet nie — „Taktgefühl“ hilft nur, wenn Graf Mopsula gesteuert wird. Tests: `tests/test_06ab_hero_talents.gd` (je Held:in ein
Integrationstest).

### 8.3 Paket B — Talent-Show + Spezies/Spezialisierung (Datenmodell)

**Ziel:** Talent-Show spielbar (Kap. 2.2: ungerade Level ab L3, gesammelt im Safe Room); Spezies/Casting als geprüftes Datenmodell
(Kap. 3.4/3.6), ohne Casting-UI.

| Art | Dateien |
|---|---|
| Neu | `core/progression/talents.gd` (`Talents`), `core/progression/casting.gd` (`Casting`), Defs `core/data/defs/talent_def.gd`, `species_def.gd` (Rumpf), `data/talents.json` (24: je Figur 8 Werte + 4 Verhalten), `data/species.json` (8), `scenes/ui/talent_show.tscn` + `.gd`, `tests/test_06b_talents.gd`, `tests/test_06b_species.gd`, `tests/test_06b_balance.gd` |
| Geändert (eigen) | `validators/talents.gd`, `validators/species.gd` (Vokabulare `TALENT_KINDS`, `TALENT_ICONS`, Bereiche je `kind`), `progression.gd` (Talente + Spezies in `total_stats` inkl. `liga_stat_pct`; `talent_pending` auf ungeraden Leveln ab L3), `battle_bridge.gd` (Krit/Element/MP/Präventiv-Talente), `core/battle/action_resolver.gd` (Stunt-Fenster-Faktor), `scenes/battle/ui/battle_results.gd` (Chip „Talent bereit“, keine Wahl dort), Badge-Provider für `pause_menu`, `scenes/ui/party_menu.gd` (Talente + offene Wahl ansehen), Block B in `mod_lines.json` (`talent_show_open`, `talent_pick*`), Hook `_pick_pending_talents` (Bot wählt beim nächsten Safe-Room-Besuch) |

**APIs:**

```gdscript
class_name Talents extends RefCounted
const OFFER_SIZE: int = 2
static func offer(state: GameState, data: GameData, member_id: String, level: int) -> PackedStringArray
static func check_pick(state: GameState, data: GameData, member_id: String, talent_id: String) -> String
	# "" | "no_pending" | "not_offered" | "max_rank" | "unknown_talent"
static func pick(state: GameState, data: GameData, member_id: String, talent_id: String) -> bool
static func stat_bonus(member: PartyMember, data: GameData, stat_index: int, base: int) -> int   # flat + pct (pm)
static func crit_add_pm(member: PartyMember, data: GameData) -> int
static func element_pm(member: PartyMember, data: GameData, element: String) -> int             # 1000 = neutral
static func post_battle_mp_pm(member: PartyMember, data: GameData) -> int
static func field_range_pm(member: PartyMember, data: GameData) -> int                          # 1000 = neutral
static func field_cd_pm(member: PartyMember, data: GameData) -> int
static func preemptive_dmg_pm(member: PartyMember, data: GameData) -> int
static func stunt_window_pm(member: PartyMember, data: GameData) -> int
static func marotte_bonus_hearts(state: GameState, data: GameData) -> int                       # per floor, read by MarottenRules
static func hype_pm(state: GameState, data: GameData) -> int                                     # product over party, 1000 = neutral
static func follower_pm(state: GameState, data: GameData) -> int
static func pending_levels(member: PartyMember) -> PackedInt32Array                              # odd levels >= 3 not yet picked
```

`Casting` wie Kap. 3.4. Gewichteter Zug ohne Zurücklegen nur mit `rng.randi_range` (Ganzzahl), Reihenfolge der Kandidaten nach ID
sortiert (deterministisch).

**Tests (Minimum):** offene Wahlen nur auf L3/L5/L7/L9 (nicht auf L2/L4 …); Wahl nur im Safe Room; Angebot deterministisch (gleicher
Seed/Level → gleiche 2 IDs; anderer Level → anders), nie doppelt, respektiert `for`/`min_level`/`max_rank`; Wahl nur aus dem Angebot
des ältesten offenen Levels; Wirkungen je `kind` (Stat-Rechnung exakt in Promille, Krit, Element, MP nach Kampf, Reichweite/
Cooldown, Präventiv-Schaden, Stunt-Fenster, Zusatz-Herz 1× je Etage, Liga-Stat nur bei `liga_tier ≥ 1`); Validator lehnt Werte
außerhalb der Bereiche je `kind` ab; Save-Rundlauf inkl. alter Stände ohne Felder; Replay mit
`talent`-Commands = gleicher Hash; Validator: 24 Talente (12/12), 8 Spezies, Fehlerfälle (unbekannter `kind`, Bereich, Referenz);
`Casting.check` je Grund (Etage < 3, falsche Figur, nicht im Safe Room, gesperrt); Spezies × Klasse in `total_stats`;
**Balance-Band:** Hausmeister-/Königin-Niederlagequote mit Bot-Talentwahl (erstes Angebot) innerhalb ±5 Punkte der heutigen Werte
(GDD §13); **Summe der Talentboni bei L10 ≤ +15 % je Kampfwert** für **jede** mögliche Wahlfolge (erschöpfend über alle
Angebotsfolgen der 4 Wahlen je Figur geprüft); Anteil Verhaltens-Talente je Pool ≥ ⅓.

**DoD:** Gate 8.6; `fullrun --strategy=all` mit Talentwahl im Bot grün; GDD §4 (Talente, Talent-Show), §12 (Spezies, Re-Spec) und
02_TECH §4.4 (Schemas) nachgezogen; Screenshot `talent_show`.

**Stand Paket B: umgesetzt (2026-10-10).** Gebaut wie oben; Verträge in 02_TECH §1.3/§1.6/§3.2–3.4/§4.2/§4.4.15–16/§4.5/§6.1/
§6.4/§6.5/§9.5/§11.4.1, Spielregeln in GDD §4.1/§4.7/§12.1/§12.4/§13/§14.5/§14.7/§16.2. Tests: `test_06b_talents.gd`, `test_06b_species.gd`,
`test_06b_balance.gd`, `test_06b_talent_show.gd`. Screenshots `docs/screenshots/talent_show.png`, `safe_talents_menu.png`,
`talents_party.png`. Entscheidungen und Abweichungen vom Entwurf:

| # | Entwurf | Gebaut | Grund |
|---|---|---|---|
| B-1 | `PartyMember.talent_pending` (gespeicherte Level-Liste) | offene Wahlen **abgeleitet**: ungerade Level ≥ 3 bis zum Level minus Σ Ränge (`Talents.pending_levels`) | kein zweiter Zustand, der auseinanderlaufen kann; alte Spielstände und `StateHash` bleiben byte-gleich (neue Felder nur, wenn gesetzt) |
| B-2 | Menüeintrag „Talent-Show“ mit „!“-Badge in der Safe-Room-Spalte | **goldener Knopf „TALENT-SHOW“ + „n Talentwahlen offen“** unten rechts, nur solange eine Wahl offen ist; die Menüspalte bleibt bei 6 Einträgen; Pausemenü → Party zeigt „n Wahl(en) offen“. Integration A × B: oben rechts auf Höhe des ersten Eintrags (unten rechts spricht der M.O.D.-Kasten), Menü in 5 Zeilen mit 88-px-Trefferflächen | ein 7. Eintrag schob „Weiter“ aus dem Bild (720p); der Knopf ist auffälliger, verschwindet von selbst und kollidiert nicht mit Paket A („Figur wechseln“) |
| B-3 | Liga-Talente wirken bei `MarottenRules.liga_tier(state) ≥ 1` | wirken, solange **diese Figur** weder Rüstung noch Accessoire trägt (`Talents.liga_dressed`) | Paket C (`MarottenRules`) existiert noch nicht; die Regel „ohne Rüstung & ohne Accessoire“ ist je Figur sofort verständlich. Paket C darf auf `liga_tier` umstellen (eine Funktion) |
| B-4 | Werte-Talente +3–5 % je Rang | STR/MAG/DEF/RES/LCK/SPD als **flache Punkte** (+1/+2), HP/MP/Liga als +5 % | bei L10 sind DEF/RES/LCK ~10–30 Punkte; +5 % wäre 0–1 Punkt (unlesbar) oder durch Rundung sprunghaft. Erschöpfender Test (L10, ohne Ausrüstung): Kai höchstens +15 HP auf 145, +3 DEF auf 22; Mopsula +10 HP auf 96, +3 RES auf 25, +2 LCK auf 18 — alle ≤ +15 % |
| B-5 | `stunt_window_pm` = Stunt-Zeitfenster | Faktor auf die **Stunt-Erfolgschance** vor Boss-Abzug und Obergrenze (`BattleState.stunt_chance`, GDD §3.6) | die Stunts haben im Slice kein Zeitfenster (Erfolg ist eine Chance); Kartentext „Stunts gelingen 20 % öfter“ |
| B-6 | Krit/Element/Präventiv in `BattleBridge.make_setup` | Krit/Element in `Progression.to_combatant` (wie die Ausrüstung), Präventiv als `Combatant.talent_mods` → `ActionResolver` (nur erster eigener Zug nach Präventivschlag) | ein Ort für alle Combatant-Werte; Replays und M7-Simulation nutzen denselben Weg |
| B-7 | — | eine Wahl hebt MaxHP/MaxMP-Zuwachs sofort auf HP/MP (wie ein Level-up, `Progression.follow_max_vitals`) | sonst wirkt „HP +5 %“ erst nach der nächsten Heilung |
| B-8 | `field_range_pm`, `field_cd_pm`, `marotte_heart` | Werte und APIs da (`Talents.field_range_pm/field_cd_pm/marotte_bonus_hearts`), **Auswertung** folgt mit Paket A (Feldfähigkeit) bzw. C (`MarottenRules`); Feldfähigkeit umgesetzt in der Integration A × B (`HeroRules.field_mods`, Talente der führenden Figur), `marotte_heart` in der Integration B × C (`MarottenRules`: erstes Herz der Etage +1, Kap. 8.8) | Besitzgrenzen 8.1; die Karte sagt „Wirkt, wenn … die Gruppe anführt.“ |
| B-9 | `hype_gain_pm`/`follower_pm` | im Kern verdrahtet als **Ganzzahl-Promille** (`GameState.hype_gain_pm/follower_pm` = Ausrüstung, einmal `roundi(x × 1000)`, × `Talents.hype_pm/follower_pm`, je Schritt `(a × b + 500) / 1000`; Show nutzt nur diese; `hype_gain_mult/follower_mult` bleiben reine Ausrüstungs-Floats), im Pool **nicht** verwendet | Kap. 4.8 Nr. 4: Event-Wertung ohne Talent-Multiplikatoren bleibt trivial erfüllt |
| B-10 | Talent-Reset beim Casting | noch nicht gebaut | kommt mit der Casting-UI (Etage 3) |
| B-11 | Verifier: `Talents.pick`/`Casting.choose` prüfen selbst (ein gefälschtes Command ändert nichts, der Hash weicht ab) | Integration (Merge mit dem Final-Review): die Legalität steht zusätzlich in `RunRules.command_refusal` — ein gefälschtes `talent`/`casting` ist für `RunSim.replay` **und** `Game.replay_log` ein Fehler in `errors` | gleicher Vertrag wie alle übrigen Commands (05 §11.4, `test_m8_integrity`) |

**Balance-Messung (Paket B):** Bot-Wahl „erstes Angebot“, gepaarte Kämpfe (gleiche Seeds, mit/ohne Talente, Geschenke wie im Spiel):
Hausmeister +0,3 Punkte, Königin +3,7 Punkte Siegquote auf 300 Kämpfen (Band ±5); nach den IP-Umbenennungen (Integration 1b,
neue ID-Reihenfolge → andere Angebote, Werte gleich) −1,0 / +4,3 Punkte. Ein erster Pool (STR/MAG +2, Tempo-Talent
`max_rank` 2) lag bei der Königin bei +5,3 Punkten (600 Kämpfe) und wurde deshalb gesenkt. Full-Run-Bot: 6 Wahlen je Lauf
(L3/L5/L7 beider Figuren), alle drei Strategien grün.

### 8.4 Paket C — Marotten, Show-Wetten, Unterhosen-Liga, E1-Show-Boss, Sponsor-Fenster-Entscheidungen

**Ziel:** Kap. 4 spielbar inkl. Show-Chip und Achievements; E1-Show-Boss (Kap. 2.6); Kap. 6 Entscheidungen 1–3 umgesetzt (4/5 sind
Doku/Regeln).

| Art | Dateien |
|---|---|
| Neu | `core/show/marotten_tracker.gd` (`MarottenTracker`: **nur** Kampf-Strichliste aus `ActionEvent`s, Ablage in `ShowState.marotten.tally`), `core/show/marotten_rules.gd` (`MarottenRules`: alles Übrige, statisch und rein), `core/battle/show_boss_rules.gd` (`ShowBossRules`), Def `marotte_def.gd` (Rumpf), `data/marotten.json` (12), `scenes/ui/bets_menu.gd` (Pausemenü-Tab „Show“), `scenes/ui/bets_results_fx.gd` (Herz-Flug am Slot von `battle_results`), `tests/test_06c_marotten.gd`, `tests/test_06c_liga.gd`, `tests/test_06c_show_boss.gd`, `tests/test_06c_sponsor_display.gd`, `tests/test_06c_balance.gd`, `tests/test_06c_event_score.gd` |
| Geändert (eigen) | `validators/marotten.gd` (Bedingungen parsen, `e.`-Schlüssel gegen Kontext 4.6, Fuß-Wörter-Sperre), `validators/show_boss.gd`, Marotten-Darstellung in `show.gd`, `data/achievements.json` (+6, Kap. 4.3), `tests/test_m7_data_content.gd` (29 → 35), `scenes/ui/show_overlay.gd` (**ein Show-Chip** mit Vorliebe/Herzen/Liga, **Sponsor-Badge ohne Sekunden**), `scenes/ui/pause_menu.gd` (Tab), `scenes/ui/equipment_menu.gd` („Liga blockiert durch: …“), `floors.json → enc_e1_showboss`, `core/live/sponsor_windows.gd` (Comeback-Fenster), `core/live/score_calc.gd` (`show_pts` aus `followers_gained_base`, `show_bet`-Achievements ohne `ach_pts`), `autoload/save.gd` (`record_game_over` vermerkt Boss-Niederlage), `tests/test_m8_sponsor_windows.gd` (Badge-Texte, Comeback), Block C + Umschreiben `sponsor_window_open*` in `mod_lines.json` (inkl. `showboss_*`, Liga-Hinweis in der Etagen-Bilanz), Hook `_apply_liga_strategy` |

**APIs:**

```gdscript
class_name MarottenRules extends RefCounted   # static, pure: reads only GameState/ShowState + GameData
static func announce(state: GameState, data: GameData, floor_index: int) -> PackedStringArray
static func on_floor(state: GameState, data: GameData, floor_index: int) -> Dictionary            # {"announce": ids}
static func liga_tier(state: GameState) -> int                          # 0 | 1 | 2 (equipment snapshot, hero-aware)
static func liga_pm(state: GameState, data: GameData, what: StringName) -> int                    # &"hype" | &"follower", 1000 = neutral
static func liga_blockers(state: GameState, member_id: String) -> PackedStringArray               # item ids in armor/accessory
static func battle_context(state: GameState, data: GameData, result: BattleResult, tally: Dictionary) -> Dictionary
static func on_battle_end(state: GameState, data: GameData, result: BattleResult, tally: Dictionary) -> Dictionary
	# applies to ShowState.marotten and returns
	# {"hits": [ids], "won": [ids], "hype": int, "follower_pm": int, "boxes": [box_ids], "followers": int, "show_bet": [payloads]}
static func on_zone(state: GameState, data: GameData, payload: Dictionary) -> Dictionary          # mar_pacifist (latch)

class_name MarottenTracker extends RefCounted  # per-battle tally only; instance per running battle (game and RunSim)
func begin(state: GameState) -> void                                                              # tally = {} in ShowState.marotten
func on_battle_event(state: GameState, e: ActionEvent) -> void                                    # defends, distinct actions, last kill …

class_name ShowBossRules extends RefCounted
static func apply(setup: BattleSetup, encounter: Dictionary) -> void                               # elite +20 % HP/STR, extra AI action
```

Die Auswertung ist reine Reaktion auf aufgezeichnete Commands und deterministische Kern-Ereignisse → **nicht** aufgezeichnet,
im Replay identisch (wie Achievements); `RunSim`/Verifier rufen dieselben statischen Funktionen auf. Der Show-Boss nutzt die
vorhandene Gegner-KI (`ai.actions` mit `cond`), die `ShowBossRules.apply` beim Setup um eine `sts_slow`-Aktion „jeder 3. Zug“
ergänzt; reicht die `cond`-Grammatik dafür nicht, geht ein Zugzähler-Schlüssel als Änderungsantrag an den Integrator.

**Sponsor-Fenster (Kap. 6):** `ShowOverlay`-Texte nach Entscheidung 1 (Kampagne dezent, live Plakette); `SponsorWindows.on_room`
öffnet nach vermerkter Boss-Niederlage einmal neu (`kind: "boss"`, `comeback: true`); Regel-Schlüssel `boss.comeback` (Standard 1,
Validierung 0..1); M.O.D.-Zeilen ohne `{seconds}`/`{count}` plus `sponsor_window_open:boss_comeback`; L13-Wortprüfung im Test
**für `sponsor_window_*`-Zeilen und Overlay-Texte** erweitert um „schnell“, „nur noch“, „letzte Chance“ (für übrige geschriebene
Zeilen gilt die Ko-Vorkommens-Regel aus Kap. 5.9, damit z. B. `marotte_hit:mar_speed` „Schnellschnitt“ sagen darf).

**Tests (Minimum):** Ansage deterministisch je Seed/Etage, E1 nur Starter, keine Wiederholung zur Vor-Etage wo möglich; jede der
11 Bedingungen mit synthetischem Kontext (trifft/trifft nicht); höchstens 1 Treffer je Vorliebe und Kampf; 3 Treffer → Box,
Follower, Zähler, Trigger `show_bet`; `mar_pacifist`: zählt nur neue Räume, Kampf setzt zurück, Latch, Safe Room/Pause zählen nicht,
**Speichern/Laden mitten in der Periode**; Strichliste übersteht Save/Load (`ShowState.marotten.tally`) und ist in `RunSim` gleich;
Liga-Stufen 0/1/2 je Held:in und Ausrüstung, `liga_blockers` nennt z. B. die Gasmaske, Multiplikatoren im **Promille**-Produkt
`hype_gain_pm`/`follower_pm`; Achievement-Kette (alle 6 erreichbar, Bedingungen parsen); Replay mit Liga-Kämpfen = gleicher Hash;
**Event-Wertung:** `show_pts` mit und ohne Liga/Wetten gleich, `show_bet`-Achievements ohne `ach_pts`, `rules.marotten.enabled`/
`rules.liga.enabled` ändern `rules_hash`; Show-Boss: Elite-Werte, Slow jeder 3. Zug, Belohnung genau 1 Fanpost-Paket, optional
(Bot erreicht die Treppe auch ohne ihn); Validator: Fuß-Wörter in `liga_*`/Marotten-Texten werden abgelehnt; Overlay-Texte (keine Ziffern
mit Doppelpunkt im Badge, „~“-Minuten, „in Kürze“); Comeback-Fenster genau einmal; **Balance-Band** Kap. 4.10 per Simulation
(100 Seeds, Liga 1 und 2).

**DoD:** Gate 8.6; `fullrun --strategy=all` grün, zusätzlich `--liga=1` und `--liga=2` (Seeds 1–3) mit gemessenen Quoten in GDD §13;
GDD §7/§8/§11/§13, 05 Kap. 1.5 (Wertung Option a), 6.13 (Darstellung) + Kap. 12.2 (Nr. 17/18 geschlossen) nachgezogen; Screenshots
Overlay mit Show-Chip (ohne/mit Liga), Ausrüstungsmenü mit Liga-Blocker, Show-Boss-Bauchbinde, Sponsor-Badge neu.

#### Stand Paket C (umgesetzt 2026-10-10, Branch `ptd/feat-quirks`)

**Gebaut:** `data/marotten.json` (11 rotierende Vorlieben + `mar_unterhose`), `MarotteDef`, privater Validator-Helfer
`core/data/validators/marotten.gd` (Schema, Kontext-Schlüssel, Pflicht-Zeilen, Fuß-Wörter-Sperre), `MarottenRules` (statisch,
rein: Auswahl je Seed/Etage, Liga-Stufe/-Faktoren, Kontext, Herzen, Wetten, Etagen-Bonus, `show_bet`), `MarottenTracker`
(Strichliste je Kampf), `ShowState.marotten` (Save + Hash), `StatIds` `bets_won`/`liga_battles`, Trigger `show_bet`, 6 Achievements
(Kette **„Ohne alles“**), 37 M.O.D.-Zeilen (`marotte_*`, `liga_*`) + `sponsor_window_open:boss_comeback`, Show-Chip im Overlay,
Pausemenü-Tab „Show“ (`bets_menu.gd`), Liga-Zeile im Ausrüstungsmenü, Zeile „Show“ im Kampfergebnis, Toasts, Optionen-Schalter
„Show-Wetten anzeigen“, Full-Run-Bot `--liga=1|2`; Sponsor-Fenster-Entscheidungen 1–5 (Kap. 6). Tests: `test_06c_marotten`,
`test_06c_liga`, `test_06c_sponsor_display`, `test_06c_balance` (+ angepasste M0/M2/M6/M7/M8-Tests).

**Bewusste Abweichungen vom Plan oben:**

1. **Strichliste flüchtig** (`MarottenTracker` in `Show`, wie `ShowRules`) statt `ShowState.marotten.tally`: Gespeichert wird nie
   im Kampf, und `RunSim`/Verifier rechnen keine Show-Reaktionen (wie bei den Achievements). Die Auswertung ist trotzdem
   replay-sicher: Reaktion auf aufgezeichnete Commands, `Game.replay_log` ergibt denselben `StateHash` (Tests mit Wetten und
   Liga-Kämpfen). Weil Event-Läufe nichts auszahlen (Nr. 2), braucht der Verifier die Wetten nicht.
2. **Event-Wertung Option a ohne `followers_gained_base`:** In Läufen mit Event-Regeln wenden `Show`/`MarottenRules` keine
   Faktoren an, zahlen keine Boxen/Follower/Hype und feuern keinen `show_bet` — `show_pts`/`ach_pts` sind dadurch unabhängig von
   Liga und Wetten; `score_calc.gd` bleibt unverändert. Anzeige und Zählung laufen weiter (Spaß und Kommentar);
   `rules.marotten.enabled`/`rules.liga.enabled` (`{"enabled": bool}`) im `rules_hash`.
3. **Liga-Faktoren gesenkt** (Kap. 4.3): ×1,2/×1,15 und ×1,4/×1,35 (Integration Runde 4: ×1,05/×1,1 und ×1,2/×1,35 mit
   Deckel des Follower-Bonus je Etage +60/+180, Kap. 8.8 I-8).
4. **Namen:** `mar_sneaky` „Schleichwerbung“, `mar_gourmet` „Schwachstellen-Gourmet“, `ach_ul_first` „Einmal ohne alles“,
   `ach_duo_flawless` „Ohne Kratzer, ohne Rüstung“; die Kette heißt „Ohne alles“. Regeltext der Liga überall „ohne Rüstung & ohne
   Accessoire“; der Validator lehnt Fuß-/Schuh-Wörter in Marotten-Texten und `liga_*`/`marotte_*`-Zeilen ab.
5. **`mar_pacifist`** ab E2 (`min_floor` 2): zählt über `Game.visit_room` → `Show.on_room_visited` nur Erstbesuche bei laufendem
   Countdown, keine Safe-Room-Zellen; Kampfbeginn setzt 0, Latch nach dem Treffer; der Zähler steht in `ShowState.marotten.zones`.
6. **Show-Chip:** in der Erkundung unter der Minimap-Spalte (rechts oben ist dort frei), im Kampf unter der Hype-Leiste;
   erst sichtbar, wenn der Countdown läuft (E1: nach dem Tutorial — eine neue Sache nach der anderen, 0.6).
7. **Kampfende-Feedback:** Zeile „Show“ im Ergebnis-Panel (Herzen + Liga-Stufe) und Toasts statt eines eigenen Herz-Flug-FX
   (`bets_results_fx.gd` entfällt); der Chip blendet sich aus, solange das Ergebnis-Panel steht (es reicht mit Level-ups bis
   unter die Hype-Leiste).
8. **Ansage:** `marotte_announce:<id>` direkt nach `floor_start` in derselben Tick-Warteschlange (E1 nach dem Tutorial-Kampf);
   `marotte_announce`, `marotte_won` und `liga_hint` stehen in `ModAnnouncer.ALWAYS_SAID_TAGS` (gehen nie im Prioritätsfenster unter).
9. **Full-Run-Bot `--liga`** statt Hook `_apply_liga_strategy`: `equip_best` lässt Rüstung/Accessoire der gesteuerten Figur (1)
   bzw. beider (2) leer; die Story-Beat-Prüfung verlangt die Ansage der Vorliebe mit laufendem Countdown und bei `--liga` mindestens
   einen Liga-Sieg.
10. **E1-Show-Boss (Kap. 2.6, `enc_e1_showboss`, `ShowBossRules`, `test_06c_show_boss`) zurückgestellt:** berührt `floors.json`
    (Layout Zone B, Besitz Paket A) und die Gegner-KI-Grammatik; Folgeaufgabe nach dem Merge von A. Ohne ihn bringt E1
    höchstens 2 Show-Boxen (Wette + Mut-Paket) statt 3. **Orchestrator-Entscheidung 2026-10-10:** er wird nicht im CTB
    nachgebaut, sondern direkt im Echtzeitkampf (07, Phase R4) — keine Wegwerf-CTB-Inhalte (Kap. 8.8).
11. **Optionen-Schalter** „Show-Wetten anzeigen“ als `GameSettings.show_bets_hud` (`display/show_bets_hud`, Standard an) — kleine,
    markierte Änderung in `game_settings.gd`/`settings_menu.gd`.

**Gemessen** (`test_06c_balance`, echtes `Show` im Kampf-Loop; Ziele Kap. 4.10):

| Kennzahl | Ziel | Ergebnis |
|---|---|---|
| Boss-Niederlage 1. Versuch, Liga 1 (Hausmeister / Königin, 100 Seeds, Geschenke) | ≤ 40 % / ≤ 55 % | 26 % / 42 % |
| dto. Liga 2 | ≤ 55 % / ≤ 70 % | 37 % / 57 % |
| Follower Ende E1 (Staffel, Median 8 Seeds): ohne Liga / Liga 1 / Liga 2 | Liga ≤ 2 000 | 1 357 / 1 630 / 1 855 |
| Lootboxen E1: ohne Liga / Liga 1 / Liga 2 | 15–22 | 20 / 23 / 21,5 (Liga-Läufe dürfen bis 28: Mut-Paket + Kette) |
| Gewonnene Wetten E1 ohne gezieltes Spielen | 0–1 | höchstens 1 |

**Full-Run-Bot im echten Spiel** (`tools/fullrun.sh --pace=human --liga=0|1|2`, Strategie *thorough* — der Bot nimmt alle Gruppen,
Kisten und Events mit —, Seeds 1–3, Median [Min–Max]):

| Kennzahl | ohne Liga | Liga 1 | Liga 2 (Duo) |
|---|---|---|---|
| Follower Ende E1 | 1 562 [1 445–1 615] | 1 928 [1 521–2 005] | **2 299** [2 271–2 866] |
| Zuschauer-Peak | 5 165 | 5 696 | 5 933 |
| Hype Kampfstart / -ende (Median regulär) | 37 / 60,5 | 37 / 64 | 41 / 75 |
| Lootboxen | 20 | 23 | 24 |
| Liga-Siege / gewonnene Wetten | 0 / 1 | 18 / 1 | 17 / 1 |
| Boss-Niederlage 1. Versuch Hausmeister · Königin | 0/3 · 0/3 | 0/3 · 1/3 | 0/3 · 2/3 |
| Liga-Achievements | — | `ach_ul_first`, `ach_ul_boss` (3/3) | + `ach_duo_first`, `ach_duo_floor` (3/3) |
| Etagenzeit | 11:17 | 10:59 | 11:10 |

Takt `fast` (Gate-Läufe, ohne Pausen): Liga 1 Follower 1 995–2 247, Liga 2 2 577–3 186, alle `FULLRUN: OK`.

**Bewertung:** Der Band-Test (Simulation) hält ≤ 2 000. Der Bot im echten Spiel liegt — wie schon ohne Liga (+15 % gegenüber der
Simulation, weil er alles mitnimmt) — darüber, in der Duo-Liga deutlich. Treiber ist weniger der Follower-Faktor als die
Dramaturgie: Liga-Kämpfe dauern länger und enden öfter knapp → mehr Hype (Kampfende 75 statt 60) → mehr Zuschauer und Geschenke.
Ein Gegenversuch mit kleineren Faktoren (×1,15/×1,1 und ×1,25/×1,15) änderte die Duo-Liga nicht messbar (2 362 [1 944–2 452])
und machte Liga 1 unattraktiv (1 447, unter der Referenz). **Entscheidung:** Faktoren bleiben (×1,2/×1,15, ×1,4/×1,35); der
Duo-Liga-Durchlauf erreicht den Meilenstein 2 000 (Gold-Box, GDD §7.7 „nur mit Top-Spiel“) — gewollt als Belohnung der
ultimativen Spielweise. Playtest-Punkt: die Rückkopplung auf E2 (Zuschauer +0,5 je Follower) beobachten; falls nötig einen Deckel
auf den Liga-Follower-Bonus je Etage statt kleinerer Faktoren.

**Stand Runde 4** (Integration, Kap. 8.8 I-7/I-8: Bellen ≠ Anschleichen; Faktoren ×1,05/×1,1 und ×1,2/×1,35, Deckel des
Liga-Follower-Bonus +60/+180 je Etage). Der Bot zählt Lootboxen und Geschenke jetzt eindeutig aus dem Zustand
(`lootboxes_opened` + offene Boxen, `sponsor_gifts`) — die alte Signal-Zählung übersah Boss-/Event-Boxen und zählte nach einem
Game-Over-Neuladen doppelt.

| Simulation (`test_06c_balance`) | Ziel | Paket C | Runde 4 |
|---|---|---|---|
| Boss-Niederlage 1. Versuch Liga 1 (Hausmeister / Königin, 100 Seeds) | ≤ 40 % / ≤ 55 % | 26 % / 42 % | 27 % / 47 % (Graf Mopsula gesteuert 28 % / 35 %; ohne Liga 17 % / 29 %) |
| dto. Liga 2 | ≤ 55 % / ≤ 70 % | 37 % / 57 % | 40 % / 56 % |
| Follower Ende E1 (Staffel, Median 8 Seeds): ohne / Liga 1 / Liga 2 | ≤ 2 000; Duo > Liga 1 > ohne | 1 357 / 1 630 / 1 855 | 1 357 / 1 449 / 1 512 |
| Lootboxen E1: ohne / Liga 1 / Liga 2 | 15–22 (Liga ≤ 28) | 20 / 23 / 21,5 | 20 / 21,5 / 21 |

| Full-Run-Bot `human`, *thorough*, Median Seeds 1–3 (Seeds 1–8) | Ziel Runde 4 | Kai: ohne / Liga 1 / Duo | Graf Mopsula: ohne / Liga 1 / Duo |
|---|---|---|---|
| Follower Ende E1 | ohne 1 200–1 500; Liga 1 ≤ 1 800; Duo ≤ 2 000 und ≥ +25 % | 1 495 (1 456) / 1 759 (1 822) / **2 336** (2 064) | **1 582** (1 579) / 1 525 (1 588) / **2 304** (2 222) |
| … Runde 3 (vorher) | | 1 495 / 1 905 / 2 689 | 1 751 / 2 061 / 2 942 |
| Zuschauer-Peak | ≤ 6 500 | 4 710 / 5 451 / 6 171 | 5 136 / 4 836 / 5 920 |
| Hype Kampfende (Median regulär) | ≤ 75 | 59 / 64,5 / 65 | 61 / 62 / 67 |
| Sponsor-Geschenke | ≤ 9 | 5 / 6 / 7 | 4 / 5 / 7 |
| Lootboxen (eindeutig) | ≤ 28 | 20 / 25 / 28 | 22 / 22 / **29** |
| Achievements | ohne 12–16 | 16 / 19 / 21 | **18** / 16 / 21 |
| Liga-Follower-Bonus (gedeckelt) | +60 / +180 | — / 60 / 180 | — / 60 / 180 |

Takt `fast` (Seeds 1–3, alle `FULLRUN: OK`): Follower ohne / Liga 1 / Duo — Kai 2 017 / 2 227 / 2 569, Graf Mopsula
2 191 / 1 951 / 2 637 (Runde 3: 2 017 / 2 189 / 3 517 und 2 154 / 2 527 / 3 058).

**Bewertung Runde 4:** Liga 1, Hype, Geschenke und Zuschauer liegen im Ziel; Lootboxen am Rand (die 29. Box der Mopsula-Duo-
Läufe ist die Gold-Box des Meilensteins 2 000). **Offen:** (1) Duo-Liga-Follower über 2 000. Den Abstand zu „ohne Liga“ machen
vor allem die Kette (mit „Ohne Kratzer, ohne Rüstung“ +260) und die Königin: der Bot kämpft nach einem Game Over weiter, bis er
sie besiegt, die Staffel-Simulation spielt ohne Wiederholung und verliert sie in 6 von 8 Duo-Staffeln — dort hält erst der
gedeckelte Follower-Bonus die Duo-Liga über Liga 1 („zahlt am meisten“, Kap. 4.10), und der Bot bekommt dieselben +180. Kleinere
Deckel bringen den Bot näher an 2 000, lassen die Simulation aber unter oder knapp über Liga 1 fallen (Duo-Deckel 120 / 130 /
150: 1 405 / 1 419 / 1 449 gegen Liga 1 1 414 / 1 428 / 1 428). Ein Hype-Faktor ab ×1,25 rundet jedes +2 zu +3 (Bot:
Hype-Ende ~79, bis 11 Geschenke) — daher ×1,2. (2) Graf
Mopsula ohne Liga über dem Band (Seeds 1–8: 1 579 Follower / 17 Achievements): die Wette kommt nicht mehr aus dem Bellen
(I-7, Runde 3: 1 751), der Rest ist das Bellen selbst — 4–5 Bell-Eröffnungen je Lauf (Party zuerst) → weniger HP-Verlust, mehr
Hype bei den Bossen, `ach_viewers_5000` in 5 von 8 Läufen (Kai 2 von 8). Die Duo-Mediane der Seeds 1–3 schwanken um ±300 (eine
Königin-Chance, Bot-Jitter bei `time_scale` 5); Seeds 1–8 sind belastbarer.

### 8.5 Paket D — KI-Admin: Schnittstelle, Twists, Referenz-Dienst

**Ziel:** Kap. 5 Stufe S0: Provider-Schnittstelle (Standard skriptiert, Remote deaktiviert), Twist-Katalog + deterministischer
Applier mit 11 wirksamen Twists, **Regie offline ab E2** (Kap. 5.7a), Referenz-Dienst mit Tests, gemocktem Client, Token-Ausgabe
gegen (gemockte) Plattform-Auth und Budget-Not-Aus. **Kein** Live-Betrieb, keine Schlüssel im Repo.

| Art | Dateien |
|---|---|
| Neu (Spiel) | `core/live/twist_applier.gd` (`TwistApplier`), `core/live/regie_director.gd` (`RegieDirector`), Def `twist_def.gd` (Rumpf), `data/twists.json` (20), `core/show/mod_live_summary.gd` (`ModLiveSummary`, rein), `autoload/mod_voice/mod_voice_provider.gd` (`ModVoiceProvider`), `scripted_mod_voice.gd` (`ScriptedModVoice`), `remote_mod_voice.gd` (`RemoteModVoice`, `HTTPRequest`, standardmäßig aus), `mod_live_link.gd` (Node, kein `class_name`), `scenes/ui/twist_fx.gd` (Vignette/Konfetti, Kind von GlobalUi), `tests/fixtures/live/twist_cases.json`, `tests/fixtures/live/mock_mod_voice.gd`, `tests/test_06d_twists.gd`, `tests/test_06d_mod_voice.gd` |
| Neu (Dienst) | `services/mod-brain/` — `README.md`, `pyproject.toml`, `mod_brain/{app,brain,persona,schema,safety,catalog,rate_limit,budget,auth,line_store,config}.py`, `tools/model_eval.py` (S1-Modellvergleich, nicht im CI), `tests/{test_schema,test_safety,test_rate_limit,test_budget,test_auth,test_line_store,test_brain_mocked,test_catalog_sync}.py`, `.gitignore` (`.env`) |
| Geändert (eigen) | `validators/twists.gd` (inkl. `rules.twists.min_floor`), Rumpf `say_external` in `show.gd`, `run_sim.gd` (Twist-Ticks, Replay-Puffer bis `tick`, Rattenregen über `STRAY_DUE`-Pfad, Zerfall-Pause), `shop.gd` (Preis-Hook-Rumpf), `scenes/ui/debug_overlay.gd` (F6 Test-Twist, F7 Test-Zeile), `scenes/ui/global_ui.gd` (`twist_fx`), `.github/workflows/ptd-check.yml` (Job `mod-brain-tests`: `pip install -e services/mod-brain[dev]` + `pytest`), Block D in `mod_lines.json` (`twist_applied_*`, `mod_live_*`) |

**APIs (Spiel):**

```gdscript
class_name TwistApplier extends RefCounted
static func validate(state: GameState, data: GameData, twist: Dictionary, rules: Dictionary, now_tick: int, in_battle: bool) -> String
static func apply(state: GameState, data: GameData, twist: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]   # ExploreEvents
static func tick(state: GameState, data: GameData, explore: bool) -> Array[Dictionary]                                    # expiry
static func on_battle_end(state: GameState) -> void
static func on_safe_room(state: GameState) -> void
static func effect_pm(state: GameState, key: String, default_pm: int) -> int
static func allowed_now(state: GameState, data: GameData, rules: Dictionary, now_tick: int, in_battle: bool) -> PackedStringArray

class_name RegieDirector extends RefCounted
const DECISION_EVERY_SEC: int = 120
static func decide(state: GameState, data: GameData, rules: Dictionary, now_tick: int) -> Dictionary  # {} | twist (src "regie")

class_name ModVoiceProvider extends RefCounted
signal turn_ready(req_id: String, lines: Array, twist: Dictionary)     # lines: Array[{"text", "tag", "voice"}]
signal status_changed(status: StringName)
func kind() -> StringName                                               # &"scripted" | &"remote" | &"mock"
func is_available() -> bool
func request_turn(batch: Dictionary) -> String                          # req_id; result via turn_ready (may be immediate)
func cancel(req_id: String) -> void
```

`Show.say_external(text, voice, tag) -> bool`: Filter (Länge, nur `{name}`, Mini-Sperrliste), niedrigste Priorität, 8 s Abstand,
sendet `Events.mod_said(text, voice, "live:" + tag, false)`; **nicht** aufgezeichnet (Präsentation). Twists laufen ausschließlich
über `Game.apply_twist` (aufgezeichnet).

**Tests (Minimum):** Katalog validiert (20 Einträge, Grenzen, `slice`-Flags); `validate` je Ablehnungsgrund inkl. `floor_too_low`
(E1); gemeinsame Fälle `twist_cases.json` (GDScript und pytest gleich); `apply`/`tick` je Slice-Twist (Wirkung, Dauer in Ticks,
`once_per_floor`, Schärfe-Budget); Aufzeichnung mit `cmd_id` 0 und `tick`, **Replay-Gleichheit** inkl. Twists; Twist im Log vor
seinem `tick` einsortiert → gepuffert, gleicher Hash; Twist mit überschrittenem `tick` → `twist_tick_passed`; manipulierter Twist im
Log → Replay meldet Abweichung; `RegieDirector`: deterministisch je Seed, nie auf E1, ≤ 3 je Etage, Timer < 180 s → nur
`tw_overtime`, schwache Party → nur `helpful`, aus in Pur-Liga/Events/bei `regie_twists = false`; ein Regie-Lauf auf dem E2-Stub
im Bot replayt hash-gleich; Pur-Liga lehnt spielrelevante Twists ab; fester Event-Fahrplan wirkt ohne Command identisch; `MockModVoice`: Zeilen
landen gefiltert im Dialog, zu lange/verbotene/veraltete Zeilen werden verworfen, Twist-Vorschlag läuft durch `apply_twist`;
`RemoteModVoice` ohne URL → `is_available() == false`, kein Netzwerkzugriff in Tests. Python: Schema (zu lange Zeile, falsche
Stimme, unbekannter Twist, **unbekannte ID/Freitext in einem Client-Feld → 400**), Sicherheitsfilter (Politik-, Slur-Beispiele;
Kaufdruck nur bei Ko-Vorkommen — „Schnellschnitt!“ bleibt, „Schnell, Sponsor-Fenster!“ fliegt; Sprachprüfung), Zeilen-Ringpuffer je
`run_ref` (der Prompt enthält nur serverseitig gespeicherte Zeilen, nie Client-Strings), Hinweis-Felder werden mit dem Katalog
geschnitten, Rate-Limit (90/h, 400/Tag je Konto), Token nur mit gültiger (gemockter) Plattform-Auth, Budget-Not-Aus liefert leere
Runden, Kosten-Log je `run_ref`; gemockter Client prüft die Anfrageform (Modell aus `MOD_BRAIN_MODEL` je Route,
`output_config.effort == "low"`, JSON-Schema-Format, `cache_control` am letzten System-Block, System-Prompt byte-identisch über zwei
Runden, kein Spielername im Prompt, Route `lines` mit `max_retries=0`/`timeout=4.0`), Refusal/Timeout/ungültiges JSON → leere Runde.

**DoD:** Gate 8.6; `pytest` im CI grün; `services/mod-brain/README.md` erklärt Start (`uvicorn mod_brain.app:app --port 8787`),
Konfiguration (`ANTHROPIC_API_KEY` aus dem Secret-Store, `MOD_BRAIN_MODEL` je Route, `MOD_BRAIN_EFFORT`, `MOD_BRAIN_TOKEN_SECRET`,
`MOD_BRAIN_MONTHLY_BUDGET_USD`, Konto-Deckel), Kosten,
Sicherheitsregeln und die Verbindung aus dem Spiel (`--mod-live-url=http://127.0.0.1:8787`, nur Debug-Builds); **keine Secrets im
Repo**; 05 Kap. 4.5 (Nachricht `twist`), 6.2, 10.5, 10.6 (Run-Log), 11.1 und 02_TECH §3.4 (Command `twist` mit `tick`) nachgezogen.

#### 8.5a Stand Paket D (umgesetzt 2026-10-10, Branch `ptd/feat-modai`)

**Erledigt:** Stufe S0 vollständig. Spiel: `data/twists.json` (20 Einträge, 11 wirksam) + `TwistDef` + privater Validator `validators/twists.gd` (Integration: `TwistCheck`-Preload statt `class_name TwistValidator`),
`TwistApplier` (Regeln, Wirkungen, Ablauf), `RegieDirector` (Offline-Regie ab E2), Command `twist` mit `tick` und Replay-Puffer
in `Game.replay_log` und `RunSim`, `Game.apply_twist` / `twist_effect_pm` / `dev_random_twist`, Wirkungs-Hooks (Gegner-Sicht/-Gehör
in `enemy_actor.gd`, Credits in `BattleBridge`/Truhen, Hype-Zerfall in `RunSim`, Kampf-Hype in `Show`, Preise in
`Shop.price_for`), `ModVoiceProvider` + `ScriptedModVoice` (Standard) + `RemoteModVoice` (aus ohne URL) + `ModLiveLink`,
`ModLiveSummary`, `ModLineFilter` + `data/mod_filter.json`, `Show.say_external`, `TwistFx` (Chip/Vignette/Konfetti), Automat
mit „HAPPY HOUR −x %“, Optionen „Regie-Eingriffe (ab Etage 2)“ und (nur Debug + URL) „M.O.D. live (Beta)“, Debug F6/F7, Block D
in `mod_lines.json` (39 Zeilen). Dienst: `services/mod-brain/` (FastAPI, offizielles `anthropic`-SDK, Structured Outputs über
`messages.parse`, adaptives Denken mit `effort: "low"`, gecachter System-Prompt, serverseitige Twist-Prüfung mit denselben
Regeln, Sicherheitsfilter, Rate-Limit, Budget-Not-Aus, HMAC-Token, Demo-Modus `MOD_BRAIN_DEMO=1` ohne Schlüssel). Tests:
`test_06d_twists.gd` (30), `test_06d_mod_voice.gd` (13), pytest (70, gemockter Client, nie die echte API); CI-Job
`mod-brain-tests`. Doku: 02_TECH §1, §3.2/§3.4/§3.5, §4.2/§4.4.18/§4.5, §7.1, §9.4, §12.4; 01_GDD §11.4/§14.3/§14.4; 05 Kap. 4.5,
6.2, 10.5, 10.6, 11.1.

Ansichten (`check.sh --shot … --recipe=twist_lights|twist_confetti|twist_live` auf `exploration.tscn`, `--recipe=safe_happy` auf
`safe_room.tscn`, Quelle jeweils `dev` = Chip „TEST“): `docs/screenshots/twist_lights_out.png`, `twist_confetti.png`,
`twist_mod_live_line.png` (Sprecher „M.O.D. · KI live“), `twist_happy_hour_vending.png`.

**Entscheidungen / Abweichungen vom Plan oben** (Code ist maßgeblich, 02_TECH nachgezogen):

1. **API-Feinschliff:** `TwistApplier.apply(state, data, twist, layout)` liefert `Array[ExploreEvent]` (kein `rng`-Parameter: der
   Rattenregen würfelt mit `SeedUtil.derive(loot_seed, "twist", n)`), `tick(…, explore, now_tick)`, `on_safe_room` ist in
   `on_safe_room_enter`/`_exit` geteilt (Happy Hour gilt **während** des nächsten Besuchs und endet beim Verlassen),
   `validate`/`allowed_now`/`decide` nehmen optional das Layout (freie Streuner-Zone), `allowed_now` die Quelle.
2. **Zwei zusätzliche Ablehnungsgründe:** `sequence_mismatch` (`n` ≠ nächste Nummer — manipulierte/duplizierte Twists im Log) und
   `no_target` (Rattenregen ohne freie Zone). Replay-Ebene: `twist_tick_passed`, `run_not_active`.
3. **Puffer-Zeitpunkt:** ein gepufferter Twist wird nach der Auswertung von Tick `tick` angewendet (vor `tick + 1`) — genau wie
   live, wo `apply_twist` zwischen zwei Ticks mit `tick = sim.tick()` läuft.
4. **Zustand** `flags.live.twist` = `{n, floor, floor_count, floor_spicy, floor_regie, once, end_at, active: [{id, n, src, params,
   unit, left, …}]}` — eine Restgröße `left` je Einheit statt `until_tick`/`battles_left`/`visits_left`; erst beim ersten Twist
   angelegt (Läufe ohne Twists behalten ihren Hash, alle bisherigen Replays bleiben gültig).
5. **Regie-Seed:** `SeedUtil.derive(state.seed, "regie", etage × 1000 + k)` (`derive` hat einen Index).
6. **`min_floor` 2 gilt für alle Quellen;** `dev` nur mit `dev_any_floor` (Kampagne an, Events aus) auch auf E1 — damit QA auf E1
   testen kann. Event-Läufe: Quellen nur `schedule`/`dev`, Regie aus (`EVENT_OVERRIDES`).
7. **„Nicht neben einem Boss-Raum“** (scharfe Twists) prüft der Kern noch **nicht**: er kennt den aktuellen Raum nicht (aufgezeichnet
   wird nur der Erstbesuch). Der einzige scharfe Slice-Twist (Rattenregen) erscheint außer Sicht in einer Streuner-Zone, nie im
   Boss-Raum; die Regel bekommt einen eigenen Kontext-Schlüssel, sobald Raumwechsel aufgezeichnet werden (S1).
8. **Live-Zeilen:** `say_external` nutzt den vollen Filter (`ModLineFilter`, identisch zu `safety.py`, gemeinsame Fälle), zeigt
   „M.O.D. · KI live“ im Sprecher-Reiter, nie in Bosskämpfen. Die Sprachprüfung ist bewusst grob (Stoppwort-Anteile) und lässt
   alle geschriebenen Zeilen bis auf < 1 % durch (Test); Wortlisten sind Saatlisten **[zu prüfen: Moderation]**.
9. **Dienst:** `max_retries=0`, `timeout=4.0` auf der Route `lines` (Spieler wartet nie, nächste Runde kommt), serverseitige
   Fallbacks (Beta-Header) außer bei Haiku; eine verweigerte, abgelaufene oder ungültige Antwort ist eine leere Runde (HTTP 200),
   nie ein Fehler im Spiel. Kostenrechnung in `budget.py` und README **[zu prüfen]** gegen die aktuelle Preisliste.

### 8.6 Gemeinsames Gate (nach Schritt 0 und nach jedem Merge)

```bash
GODOT=/tmp/claude-0/-home-user-K0/a07182b1-7945-59c9-b394-3f6520382165/scratchpad/godot/godot tools/check.sh
GODOT=… tools/fullrun.sh --strategy=all
GODOT=… tools/perf.sh            # nur wenn Szenen/Erkundung geändert wurden (A, C-Overlay, D-twist_fx)
```

Konventionen (02_TECH §13): statische Typisierung, voll qualifizierte Enums (`BattleSetup.Advantage.PREEMPTIVE`), keine Autoload- oder
`class_name`-Bezeichner in `-s`-Skripten (dort `load()` nach `process_frame`), handgeschriebene `.tscn`, im Kern kein globales
`randf`/`randi`/`Time` (Lint `test_m8_no_global_rng`), Ganzzahl-/Promille-Arithmetik, jede Zustandsänderung von außen über eine
aufzeichnende `Game`-Methode. Alle bisherigen ~806 Tests bleiben grün; jedes Paket bringt eigene Tests mit (Richtwert je 25–60).

### 8.7 Folgeänderungen an bestehenden Dokumenten

| Dokument | Änderung | Paket |
|---|---|---|
| `00_BRIEF` Kap. 4 | Zeile „Progression“: Talentwahl, Spezies ab E3; Zeile „Show-System“: Show-Wetten/Liga; Kap. 6b: KI-Admin als optionaler Eingang (Twist = externes Command) — **Brief-Änderung bewusst, mit Verweis auf dieses Dokument** | Integrator |
| `01_GDD` | §1 (E1: Kulissenwände, Regie-Notizen, Show-Boss), §2.1 (Held:in, Bellen), §4 (Talent-Show, ungerade Level ab L3), §7 (Liga-/Wetten-Hype, Show-Chip), §8 (+6 Achievements), §11 (neue Tags), §12.1 (Re-Spec ersetzt „kein Wechsel“), §13 (Lootbox-Band 15–22, Liga-Quoten), §14.2 (Ablauf Neues Spiel) | A/B/C |
| `02_TECH` | §3.2 Signale, §3.4 Commands `hero/talent/casting/secret/twist` (Twist mit `tick`, Replay-Puffer), §4.2 Präfixe `tal_/spc_/mar_/tw_/sec_` (+ reservierte `gld_/job_/ssn_/raid_`), §4.3 Vokabulare, §4.4 Schemas, §4.5 Tabellen 17 + `validators/`-Aufteilung, §6.3 Trigger `show_bet` + StatIds, Promille-API `hype_gain_pm/follower_pm`; CR-16…CR-19 | 0/A–D |
| `03_ART` | Bellen-VFX, Mopsula als Spielerkörper, Riss-Wand/Regie-Notiz, Show-Boss-Goldrahmen, Liga-Optik (später; **kein** Fuß-/Barfuß-Rig, nie in Key Art), Spezies-Optik (später), Partyhut-Prop (später) | A/C (+ später) |
| `04_STRATEGIE` | Kap. 2.3 Distanz-Review + „Unterhosen-Liga“ (**Nähe hoch**, Maßnahmen 0.3 Nr. 1–6) + Mopsula-Talentnamen (Kap. 2.2); Marketing-Regel „keine Liga-Optik von Kai in Key Art/Trailer/Store“; Kap. 3 Roadmap-Ergänzungen (Kap. 7); Kap. 11 erledigte Entscheidungen | Integrator |
| `05_LIVE_MODUS` | **Kap. 1.5** Wertung: `show_pts` aus `followers_gained_base`, `show_bet`-Achievements ohne `ach_pts`, `rules.marotten`/`rules.liga` in `rules_hash` (4.8 Nr. 4, Option a); **Kap. 4.5** Nachricht `twist` → `{id, src, params, tick, vote_id?}` (`apply_tick` heißt jetzt `tick`); Kap. 6.2 Twist-Katalog → `twists.json` dieses Dokuments, Twist-Command-Schema; Kap. 6.13 Darstellung ohne Sekunden, Comeback-Fenster; Kap. 10.5 Schema; **Kap. 10.6** Run-Log: `twist` mit `tick`, Puffer-/Abweichungsregel; Kap. 11.1 `twists.json` jetzt im Slice; Kap. 12.2 Nr. 4/13/17/18 geschlossen | C/D |


### 8.8 Integrationsstand & Orchestrator-Entscheidungen (Branch `ptd/int-06`)

| Runde | Inhalt | Stand |
|---|---|---|
| 1 / 1b | Paket B mit den Review-Fixes von `main`; Talent-Legalität in `RunRules.command_refusal`; IP-Umbenennungen; Show-Faktoren als Ganzzahl-Promille; Replay-Prüfung nach dem Laden (Anker) | gemergt |
| 2 | Paket A; Feld-Talente → Feldfähigkeiten (`HeroRules.field_mods`); Safe-Room-Menü in 5 Zeilen mit 88-px-Trefferflächen, TALENT-SHOW oben rechts; Held:in × Talente (`test_06ab_hero_talents`) | gemergt |
| 3 | `main` (07_ECHTZEITKAMPF, Brief-Vorrang); Paket C; Liga-Talente ← Liga-Stufe; „Kamera 3 kennt mich“ → Herzen; Screenshots von C als 27/28 | gemergt |
| 4 | `main` (07-Konsistenz); `regie_`-Präfix gehört Paket D (A's Regie-Notiz-Zeilen → `secret_note:<n>`, Spieltext bleibt „Regie-Notiz“); Paket D (KI-Admin, Twists, Regie offline, M.O.D. live) mit Hype-Kette in Ganzzahl-Promille, Twist-Ablehnung über `RunRules` in beiden Prüfern, Replay-Puffer im Zustand (I-10) und RemoteModVoice-Fixes (I-11); Bellen ≠ Anschleichen (I-7); Liga-Ökonomie mit Deckel je Etage (I-8); CTB-Grenze + R4-Ziel (I-9) | gemergt |

| # | Entscheidung (Orchestrator, 2026-10-10) | Umsetzung / Folge |
|---|---|---|
| I-1 | **Kein E1-Show-Boss im CTB.** Der von Paket C zurückgestellte Show-Boss (Kap. 2.6) wird direkt im Echtzeitkampf gebaut (`07_ECHTZEITKAMPF.md`, Phase R4, Entscheidung E26). | keine Wegwerf-CTB-Inhalte; GDD §1 vermerkt es; E1 bringt bis dahin höchstens 2 Show-Boxen (Wette + Mut-Paket) |
| I-2 | **Bekannte CTB-Grenze bis R5:** ein automatischer Partner („Partner automatisch“, Kap. 1.4) stuntet nie (AutoPolicy) — „Taktgefühl“ hilft im CTB nur, wenn Graf Mopsula gesteuert wird. Im Echtzeitkampf nutzt auch die KI SHOW, dort wirkt es (07 E27: `tal_mop_taktgefuehl` über `RtUnit.stunt_pm`). | nur hier vermerkt, **kein UI-Text** |
| I-3 | **Liga-Stufe = einzige Quelle** für die Liga-Talente (`tal_kai_liga_routine`, `tal_mop_liga_gelassen`): `MarottenRules.in_liga` — die gesteuerte Figur ab Stufe 1, die andere nur in der Duo-Liga (Stufe 2); nie im Tutorial-Kampf, nie bei `rules.liga.enabled = false`. | `BattleBridge.make_setup` (Kampfwerte, Regeln des Laufs), `UiUtil.member_stats`, Talent-Show-Vorschau; `Talents.liga_dressed` entfällt; `liga_stat_pct` nur für Kampfwerte (nie HP/MP, Validator); Ganzzahl-Promille; Tests `test_06abc_liga_talents` |
| I-4 | **„Kamera 3 kennt mich“** (`marotte_heart`) wirkt in C's Herz-Logik: das erste Herz einer Etage zählt doppelt (Party-Summe, einmal je Etage, bis zum Ziel), für beide Held:innen, auch in Event-Läufen (zählen ja, zahlen nicht); Toast „Talent: Extra-Herz …“. | `MarottenRules._bonus_hearts`, `ShowState.marotten["bonus"]` (Save + Hash, `Game.replay_log`-gleich; Runde 4: `ShowState.marotten_dict` behält den Marker — vorher fiel er beim Speichern weg, nach dem Laden kam das Extra-Herz auf derselben Etage erneut; Test `test_06abc_liga_talents`) |
| I-5 | **Gesteuerte Figur:** die Liga-Stufe liest `GameState.hero` (Paket A) direkt. | `MarottenRules.hero_of`; Tests für Kai und Graf Mopsula |
| I-6 | **IP:** Kai und Graf Mopsula; keine Kronen-/Majestäts-/Königsmotive für Mopsula; ohne Rüstung zu spielen ist ein Spielstil, nie ein Charakterzug; der allgemeine „Wir/Uns“-Stil des Grafen bekommt einen eigenen Stimm-Durchgang nach allen vier Paketen. | Liste der Stellen im Integrationsbericht |
| I-7 | **Bellen ist kein Anschleichen.** Ein Präventivschlag aus Graf Mopsulas Bellen (die Gruppe ist benommen und wird von jeder Seite erwischt) zählt nicht für „Schleichwerbung“ (`mar_sneaky`) oder andere Schleich-Vorlieben und nicht für „Leise Sohle“ (`ach_preemptive_3`), sondern als eigener Zähler `bark_openers`; im Kampf bleibt er ein Präventivschlag (Party zuerst, Hype +3, „Erster Eindruck“). | `BattleSetup.opener` / `BattleResult.opener` = `"bark"` (im `encounter`-Command als `opener`, nur bei `adv` 1 — Logs ohne Bellen bleiben bytegleich), `encounter_type` `"bark"` in `Show` und `MarottenRules`, `exploration.gd._opener`; Test `test_06ac_bark_opener` |
| I-8 | **Liga-Ökonomie: sichtbar belohnt, aber begrenzt.** Faktoren Stufe 1 Hype ×1,05 / Follower ×1,1, Stufe 2 ×1,2 / ×1,35; **Deckel auf den Liga-Follower-Bonus je Etage** +60 / +180 (Kap. 4.3). Die Duo-Liga zahlt am meisten auch in der Simulation ohne Wiederholungen (Kap. 4.10), Messung und verbleibende Abweichungen Kap. 8.4 „Stand Runde 4“. | `floor_follower_cap` in `marotten.json` (Validator optional 0..2 000), `MarottenRules.liga_floor_cap` / `take_liga_followers` / `liga_followers_left`, `ShowState.marotten.liga.followers`, Tab „Show“ nennt Deckel und Rest; Tests `test_06c_liga_cap`, `test_06c_liga`, `test_06c_balance` |
| I-9 | **CTB-Grenze bis R5:** Ist Graf Mopsula gesteuert, legt in Liga 1 nur der Graf Rüstung und Accessoire ab, Kai kämpft voll ausgerüstet. Mit Hype ×1,2 war Liga 1 dann im CTB kaum schwerer als ohne Liga (Boss-Niederlage 1. Versuch Hausmeister/Königin 19 %/35 % gegen 17 %/29 %); mit ×1,05 (I-8) 28 %/35 % (+11/+6 Punkte; Kai gesteuert 27 %/47 %). Für den CTB akzeptiert (vorläufig bis R5). **R4-Ziel (07, Echtzeitkampf):** „Liga 1 muss für beide Held:innen messbar schwerer sein als Liga 0 (≥ +5 Punkte Boss-Niederlage im 1. Versuch).“ | Messung im Harness von `test_06c_balance` (100 Seeds, Geschenke) mit Liga-Stufe 1 auf der gesteuerten Figur; 07 übernimmt das Ziel in den R4-Harness |
| I-10 | **Twists × Speichern/Replay (Paket D):** Der Replay-Puffer (ein Twist-Command vor seinem Tick einsortiert) liegt im Zustand (`GameState.flags.twist_buffer`, gespeichert, nicht gehasht, `RunSim.step` macht ihn fällig); Ablehnung zentral in `RunRules.twist_refusal` (Live-Eingang und beide Prüfer), abgelehnte Commands nennen ihre ID (`RunRules.refused_id`); Hype-Kette Ganzzahl-Promille: Ausrüstung × Talente → Liga → Partyhüte-Twist, je Schritt halb aufgerundet; der Twist-Validator ist privat (`validators/twists.gd`, Kap. 8.0 Nr. 7). | Tests `test_06d_twist_save`, `test_06d_twists` |
| I-11 | **RemoteModVoice:** Ein neuer Lauf oder ein Laden (`run_ref` ändert sich) verwirft das Sitzungs-Token und eine laufende Anfrage; gesund ist nur eine 2xx-Antwort mit JSON-Objekt ohne `error`/`detail` — 429/413/5xx und Fehler-JSON zählen als Fehler, damit greifen die 3-Fehler-Pause und die Rückgabe an die Regie. | `RemoteModVoice.healthy_body`; Tests in `test_06d_mod_voice` |

---

## 9. Risiken & offene Punkte

| # | Risiko / Frage | Gegenmaßnahme / Vorschlag |
|---|---|---|
| R-1 | **Zu viele Systeme** überfordern Neue | Einführungsfahrplan 0.6 (E1 = genau drei Neuheiten, ein Show-Chip), Ein-Satz-Regel L-1, Playtest-KPI „versteht das System ohne Erklärung“ ≥ 3 von 5 je neuem System. **Eigener E1-KPI:** Erstspieler:innen (n ≥ 5) können nach Etage 1 Figurenwahl, Bellen und die Vorliebe des Tages in einem Satz erklären (≥ 4 von 5) und nennen ungefragt **keine** Überforderung; HUD-Elemente auf E1 ≤ heutiger Stand + 1 |
| R-2 | Liga zu stark/zu schwach | Bänder Kap. 4.10 als Test; Multiplikatoren in Daten |
| R-3 | KI-Humor fade oder daneben | S0.5 Redaktion zuerst, S1-Gate mit Redaktionsbewertung und Modellvergleich, Not-Aus |
| R-4 | KI-Kosten pro Spieler:in, Missbrauch des Budgets | Kap. 5.10/5.11: Token nur gegen Plattform-Auth, Konto-Deckel 90/h + 400/Tag, Monatsbudget mit Not-Aus, Kosten-Log je `run_ref`; Opt-in, Sendungs-Regie statt Einzel-Regie, Modellwahl je Route nach S1-Vergleich |
| R-5 | Nähe zu DCC (Unterhosen-Gag) — **hoch** | Kap. 0.3 Maßnahmen 1–6 (Regeltext „ohne Rüstung & ohne Accessoire“, keine Fuß-Bezüge, keine Liga-Optik im Marketing, „Fanpost-Paket“, kein Liga-Fanclub, Arbeitstitel mit Ersatzname); Mopsula-Talente aus eigenem Kanon; Distanz-Review vor Exit Phase 2 |
| R-6 | Twists stören Fairness in Wertungen | KI-Twists in gewerteten Läufen aus; Fahrplan für alle gleich; Pur-Liga ohne Twists |
| R-7 | Merge-Konflikte bei paralleler Arbeit | Schritt 0, Besitz-Tabelle 8.1, Anker-Blöcke in `mod_lines.json` |
| R-8 | Prompt-Injection/Provokation über manipulierte Clients | Kap. 5.4/5.9: kein Client-String im Prompt, Zeilen-Puffer serverseitig, IDs katalog-geprüft |
| R-9 | Liga/Wetten werden Ranglisten-Pflicht | Kap. 4.8 Nr. 4: Option (a), Event-Wertung ohne Liga-/Marotten-/Talent-Multiplikatoren |
| O-1 | Herr Brettschneider als 3. Figur oder neue Figur? | Vorschlag Brettschneider (Story-Rückbezug); Entscheidung mit Etage-2-Design |
| O-2 | Level-Cap-Plan je Etage | mit Etage 3 festlegen (Kap. 2.3) |
| O-3 | Fanclub-Namen | Vorschläge Kap. 2.4; Humor-Redaktion |
