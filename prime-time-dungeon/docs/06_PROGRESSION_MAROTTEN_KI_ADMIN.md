# PRIME TIME DUNGEON — Progression, M.O.D.-Marotten & KI-Admin

> Grundlage: Nutzervision vom **2026-10-10** (Wortlaut sinngemäß in Kap. 0.1; Freigabe: „nach bester Abwägung handeln, mit Blick auf
> eine möglichst gute User Experience, mit Spaß, Witz und Abwechslung, aber mit simplem, sofort verständlichem Spielkonzept“).
> Abgestimmt auf `00_BRIEF.md` (verbindlich), `01_GDD.md` (Progression Kap. 4, Show Kap. 7, Achievements Kap. 8, M.O.D. Kap. 11,
> Klassen Kap. 12, Balancing Kap. 13), `02_TECH.md` (Verträge, §3.4 Aufzeichnungsregel, §4 Daten, §13 Konventionen),
> `04_STRATEGIE_ROADMAP.md` (IP Kap. 2, Phasen Kap. 3) und `05_LIVE_MODUS.md` (Sponsor-Fenster Kap. 6.13, Votes/Twists Kap. 6.2).
>
> **Status:** Planungs- und Entscheidungsdokument für den nächsten Umsetzungsdurchgang (Pakete A–D, Kap. 8). Es **ergänzt**
> GDD/TECH/05; wo es ihnen widerspricht, gilt bis zur Einarbeitung dieses Dokument für die genannten Punkte (Liste Kap. 8.7).
> Der Brief bleibt vorrangig. **Rangfolge:** `00_BRIEF` > `02_TECH` (APIs/Schemas) > **`06`** (neue Systeme) > `01_GDD` > `03_ART` > `04`/`05`.
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
   beide, auf Wunsch kämpft der Partner automatisch.
2. Jede Figur hat eine eigene **Feldfähigkeit**: Kai schlägt (Präventivschlag), Mopsula **bellt** (Gegner erschrecken, vorbeischleichen).
3. Bei jedem Level-up wählt man **1 von 2 Talenten** — kleine, lesbare, witzige Boni („Majestätisches Schnarchen: +15 % MP nach Kämpfen“).
4. **Ab Etage 3** findet im Safe Room das **Casting** statt: Spezies wählen (4 für Kai, 3 für Mopsula, oder „Original bleiben“) und
   die erste **Spezialisierung** (die vorhandenen 4 Klassen je Figur). Ab hier wird das Spiel deutlich vielfältiger.
5. Ab Etage 2 kommen **Fanclubs** (Gilden in der Spielwelt), eine **3. Begleitfigur**, **Show-Bosse** und **Geheimnisse** zum Erkunden.
6. M.O.D. hat **Marotten**: Pro Etage verkündet sie 1–2 **Vorlieben** („M.O.D. mag heute: Nur der Mopp“). Wer sie bedient,
   bekommt Hype, Follower und eine Fan-Box — **nie Pflicht, nie Strafe**.
7. Immer verfügbar ist die **Unterhosen-Liga**: ohne Rüstung und ohne Accessoire („ohne Hose, barfuß“) — schwerer, aber vom
   Publikum geliebt. Stufe 2 **„Ohne alles“** (beide Figuren) ist die ultimative Spielweise mit eigener Achievement-Kette.
8. **KI-generierte Kommentare sind machbar** — als serverseitiger Dienst „mod-brain“ mit Claude, ohne API-Schlüssel im Spiel,
   mit Sicherheitsfilter und Skript-Fallback. Die KI darf das Spiel **leicht** verändern, aber nur über einen **festen Katalog**
   begrenzter **Twists**, die der deterministische Kern prüft und aufzeichnet.
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
| L-2 | **Eine neue Regel pro Etage** | Progressive Einführung (Tabelle 0.6). Etage 1 bleibt der Lernraum: Kampf, Show, Talente, eine Vorliebe. |
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
| „Carls Strategie: barfuß und ohne Hose“ | Charakterzug der DCC-Hauptfigur | **Unterhosen-Liga** (Kap. 4.3): eine **optionale Challenge-Kategorie** der Show (wie Speedrun-Kategorien), für **jede** gesteuerte Figur, eingeführt als M.O.D.-Wette mit Paragrafen-Humor. Kai ist **nicht** „die Figur ohne Hose“ — es ist eine Spielweise, kein Wesenszug. |
| „Die KI hat Fetische“ | Die DCC-System-KI hat eine bekannte Fuß-Vorliebe | **Keine** Fuß-Vorliebe, nichts Sexuelles. Unsere M.O.D. hat wechselnde, harmlose **Marotten/Vorlieben** (Wischmopps, Stil, Ruhe, Second-Hand …), Kap. 4. |

**Distanz-Review (04 Kap. 2.3):** „Unterhosen-Liga“ wird als zusätzliche Zeile in die Prüfliste aufgenommen (Nähe: mittel;
Maßnahme: Kategorie-Rahmung, gilt für beide Figuren, kein Story-Bezug, Namensalternative „Leichtbekleidungs-Liga“ bereitgehalten —
Umbenennung ist reine Textänderung, die IDs `mar_unterhose`/`liga_*` sind neutral).

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
| Partner automatisch | „Auf Wunsch kämpft Ihr Partner von selbst. Er hält sich für besser darin.“ | Optionen / 1. Safe Room |
| Talentwahl | „Level-up! Wählen Sie eines von zwei Talenten. Das andere bekommt jemand anderes. Nie.“ | 1. Level-up |
| Vorlieben (Marotten) | „Ich mag heute etwas Bestimmtes. Tun Sie es, und ich mag Sie.“ | nach dem Tutorial-Kampf (E1) |
| Unterhosen-Liga | „Ohne Rüstung, ohne Schuhe: schwerer, aber das Publikum liebt Mut.“ | 1. Safe Room (Hinweis, einmalig) |
| Fanclubs | „Treten Sie einem Fanclub bei. Fans geben Aufgaben, Fans geben Boni.“ | E2, 1. Safe Room |
| Casting | „Wer wollen Sie sein? Und was wollen Sie können? Die Jury bin ich.“ | E3, 1. Safe Room |
| KI-Twists | „Die Regie greift ein. Kurz, begrenzt, meistens zu Ihren Gunsten.“ | nur bei aktivem „M.O.D. live“ |

### 0.6 Einführungsfahrplan (eine neue Regel pro Etage)

| Etage | Neu | Bleibt bewusst weg |
|---|---|---|
| 1 | Figurenwahl, Feldfähigkeiten, Talentwahl ab 1. Level-up, **1** Vorliebe, Liga-Hinweis im 1. Safe Room | Gilden, Spezies, KI-Twists |
| 2 | **2** Vorlieben, Fanclubs, 3. Begleitfigur (rekrutierbar), erste Geheimnisse („Kulissenwände“) | Spezies |
| 3 | **Casting**: Spezies + Spezialisierung; Level-Cap steigt | — |
| 4+ | Show-Bosse, Sammelkarten-Album, Fanclub-Ränge 3–5 | — |

---

## 1. Spielfigur wählen (Kai oder Graf Mopsula)

### 1.1 Ablauf „Neues Spiel“ (ersetzt GDD §14.2 Schritt 2)

1. Slot wählen (unverändert).
2. **Figurenwahl** (neu, `scenes/title/hero_select.tscn`): zwei große Karten nebeneinander, erste hat Fokus.
   - **Kai** — „Tierpfleger:in. Wischmopp. Haut zu.“ · Feld: *Feldschlag* · Rolle: Nahkampf/Tank
   - **Graf Mopsula** — „Mops. Magier. Publikumsliebling.“ · Feld: *Bellen* · Rolle: Magie/Heilung
   Unter jeder Karte eine animierte Vorschau (Rig im Idle) und eine Zeile „Du kannst im Safe Room jederzeit wechseln.“
3. Name eingeben — es ist **immer Kais Name** (Spielername, `{name}`). Hat man Mopsula gewählt, lautet die Überschrift
   „Wie heißt Unser:e Kammerdiener:in?“ (Mopsula-Stimme) statt „Wie heißt du?“.
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
- **Option „Partner automatisch“** (`GameSettings.partner_auto`, Optionen + Safe-Room-Menü): Züge der **nicht** gesteuerten Figur
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
- `hero` fließt in den `StateHash` und in Marotten (Unterhosen-Liga bezieht sich auf die gesteuerte Figur, Kap. 4.3).

---

## 2. Charakterentwicklung

### 2.1 Überblick: Fortschritt auf mehreren Achsen

| Achse | Spielgefühl | Slice (jetzt) | Später |
|---|---|---|---|
| **Stats** (HP, MP, STR, MAG, DEF, RES, SPD, LCK) | sichtbar wachsen | wie GDD §4 | Level-Cap je Etage anheben (2.3) |
| **Talente** | bei jedem Level-up eine Entscheidung | **Paket B**: 1 aus 2, 12 je Figur | Talent-Reset, seltene Talente aus Show-Bossen |
| **Fähigkeiten** | neue Werkzeuge | Lernsets wie GDD §4.5/4.6 | Klassen-Skills L11–L17 (GDD §12) |
| **Ausrüstung** | Beute, Ausprobieren | 3 Slots wie GDD §6 | Tiers, Set-Boni, „Ramsch“-Seltenheit (graue Items à la WoW, M.O.D. liebt sie) |
| **Spezies + Spezialisierung** | Identität, Rolle | **Paket B**: Datenmodell + Regeln + Tests | Casting-UI auf Etage 3, Optik je Spezies (03_ART) |
| **Fanclubs (Gilden)** | Zugehörigkeit, Aufträge | — | ab Etage 2 (2.4) |
| **Gruppe** | „wir werden mehr“ | Duo | 3. Begleitfigur ab E2, Koop 2–4 (05 S4) |
| **Bosse** | Höhepunkte | 2 je Etage | Show-Bosse (Elite), Raids (Kap. 7) |
| **Erkunden** | Neugier lohnt sich | Truhen, Events | Geheimnisse, Sammelkarten, Regie-Notizen, Wiederholungen (2.7) |
| **Show-Wetten** | Spielweise variieren | **Paket C** | Fanclub-Wetten, Saison-Wetten |

### 2.2 Talentwahl (Paket B)

**Regel in einem Satz:** Bei jedem Level-up einer Figur bietet die Show **zwei** Talente an; man wählt **eines**.

| Regel | Wert |
|---|---|
| Wann | jedes Level-up ab L2 (bis Cap 10 im Slice → **9 Wahlen je Figur**) |
| Angebot | 2 verschiedene Talente aus dem Pool der Figur (`for` enthält die Figur, `min_level ≤ Level`, Rang < `max_rank`), gewichtet ohne Zurücklegen; Zufall `SeedUtil.derive(state.seed, "talent:" + member_id, level)` → **Neuladen ändert das Angebot nicht**, kein Angebot muss aufgezeichnet werden |
| Wahl | `Game.pick_talent(member_id, talent_id)` → Command `{"t": "talent", "member", "id"}`; gültig nur für das Angebot des ältesten offenen Levels |
| Später wählen | erlaubt: offene Wahlen stehen in `PartyMember.talent_pending` (Level-Liste), Badge „!“ im Pausemenü (Party) und in den Kampfergebnissen. **Nichts blockiert den Spielfluss.** |
| Stapeln | Talente mit `max_rank` 2–3 können erneut angeboten werden (Rang +1) |
| Autoplay/Bot | wählt deterministisch das erste Angebot (Full-Run-Bot, Kap. 8) |
| Umfang | klein: ein Talent ≈ +3–5 % auf **eine** Größe; Summe bis L10 ≤ +15 % Kampfkraft (Balancing-Band, Paket B) |

**Wirkungsarten** (`TALENT_KINDS`, alles Ganzzahl/Promille; im Slice nur diese, alle an **bestehenden** zentralen Stellen angewendet):

| `kind` | Felder | Angewendet in |
|---|---|---|
| `stat_flat` | `stat`, `value` (1..20) | `Progression.total_stats` |
| `stat_pct` | `stat`, `pm` (10..200) | `Progression.total_stats` (nach Ausrüstung, vor Klasse/Spezies) |
| `crit_add_pm` | `pm` (5..100) | `BattleBridge.make_setup` (Krit-Bonus des Combatants) |
| `element_pm` | `element`, `pm` (500..1000 = Schadensfaktor) | `BattleBridge.make_setup` (`element_mods`) |
| `post_battle_mp_pm` | `pm` (10..300) | `BattleBridge.apply_result` („Werbepause-Regeneration“ +x ‰ MaxMP) |
| `hype_gain_pm` | `pm` (10..200) | `GameState.hype_gain_mult` (Produkt) |
| `follower_pm` | `pm` (10..200) | `GameState.follower_mult` (Produkt) |

**Pool Kai (12)** — `tal_kai_*`:

| ID | Name | Wirkung | `max_rank` |
|---|---|---|---|
| `tal_kai_wischtechnik` | Wischtechnik | STR +2 | 3 |
| `tal_kai_dicke_haut` | Dicke Haut (tierheimgeprüft) | DEF +8 % | 2 |
| `tal_kai_nachtschicht` | Nachtschicht-Kondition | HP +10 % | 2 |
| `tal_kai_glueckspfote` | Glückspfote | LCK +3 | 2 |
| `tal_kai_flinke_sohle` | Flinke Sohle | SPD +1 | 2 |
| `tal_kai_fester_griff` | Fester Griff | Krit +3 % | 2 |
| `tal_kai_bissfest` | Bissfest | Gift-Schaden ×0.75 | 1 |
| `tal_kai_gummisohlen` | Gummisohlen (innen) | Schock-Schaden ×0.8 | 1 |
| `tal_kai_kaffee` | Automatenkaffee | +10 % MaxMP nach jedem Kampf | 2 |
| `tal_kai_kamera3` | Kamera 3 kennt mich | Hype-Gewinne +5 % | 2 |
| `tal_kai_autogramm` | Autogrammstunde | Follower +5 % | 2 |
| `tal_kai_hausverstand` | Hausverstand | RES +8 % | 2 |

**Pool Mopsula (12)** — `tal_mop_*`:

| ID | Name | Wirkung | `max_rank` |
|---|---|---|---|
| `tal_mop_blaues_blut` | Blaues Blut | MAG +2 | 3 |
| `tal_mop_schnarchen` | Majestätisches Schnarchen | +15 % MaxMP nach jedem Kampf | 2 |
| `tal_mop_hermelin` | Hermelin-Haltung | RES +8 % | 2 |
| `tal_mop_leberwurst` | Leberwurst-Diät | HP +10 % | 2 |
| `tal_mop_monokel` | Monokel-Fokus | Krit +3 % | 2 |
| `tal_mop_zuchtbuch` | Zuchtbuch-Eintrag | LCK +3 | 2 |
| `tal_mop_hofknicks` | Hofknicks | Hype-Gewinne +5 % | 2 |
| `tal_mop_fanpost` | Fanpost-Flut | Follower +7 % | 2 |
| `tal_mop_winterfell` | Winterfell | Eis-Schaden ×0.75 | 1 |
| `tal_mop_feuerstolz` | Feuerstolz | Feuer-Schaden ×0.75 | 1 |
| `tal_mop_kurze_beine` | Kurze Beine, große Schritte | SPD +1 | 2 |
| `tal_mop_ahnenreihe` | Tiefe Ahnenreihe | MP +10 % | 2 |

**UI:** Nach den Kampfergebnissen erscheint bei Level-up „**LEVEL UP! Wähle ein Talent**“ mit zwei Karten (Name, ein Satz, Zahl
grün, Icon nach `kind`) + „Später“. Fokus-navigierbar, Touch-Trefferflächen ≥ 88 px (02_TECH §10). M.O.D.-Tag `talent_pick`
(„Neues Talent! Die Regie nennt es Entwicklung. Ich nenne es: mehr Material.“), Variante `talent_pick:mopsula` („Der Graf lernt
dazu. Er bestreitet, dass es etwas zu lernen gab.“).

**Schema `talents.json` (`TalentDef`, Präfix `tal_`):**

```json
{"schema": 1, "entries": [
 {"id": "tal_mop_schnarchen", "name": "Majestätisches Schnarchen", "desc": "Nach jedem Kampf ein Nickerchen: +15 % MP.",
  "for": ["mopsula"], "max_rank": 2, "weight": 3, "min_level": 2, "icon": "mp",
  "effects": [{"kind": "post_battle_mp_pm", "pm": 150}]}
]}
```

Felder: `id` ✓, `name` ✓, `desc` (≤ 60 Zeichen, eine Kartenzeile), `for` ✓ (Party-IDs), `max_rank` 1..3 (1), `weight` 1..10 (1),
`min_level` 2..99 (2), `icon` ∈ `TALENT_ICONS` (`hp`, `mp`, `atk`, `mag`, `def`, `res`, `spd`, `lck`, `crit`, `element`, `show`), `effects` ✓
(1..3 Einträge, `kind` ∈ `TALENT_KINDS`, Felder je Art wie oben, alle Ganzzahlen).

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
| `gld_kurze_hosen` | **Club der Kurzen Hosen** | Fans der Unterhosen-Liga | Liga-Hype zusätzlich +5 % je Rang | Kämpfe in der Liga gewinnen |
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
- **Show-Bosse** (ab E2/E4): seltene, von M.O.D. angekündigte **Elite-Varianten** regulärer Gegner („Sonderausgabe!“) mit einer
  Zusatzregel (z. B. „Hausordnung verschärft: jeder 3. Zug ein Strafzettel“), Belohnung Sammelkarte + Fan-Box. Optional, sichtbar
  auf der Karte (goldener Rahmen), nie im Weg.
- **Raids** später (Kap. 7).

### 2.7 Erkunden — Raum lassen trotz Countdown

Damit Erkunden sich trotz Etagen-Timer lohnt, zahlt jedes Geheimnis **auch in Zeit oder dauerhaften Werten** zurück:

| Element | Wirkung | Ab |
|---|---|---|
| **Kulissenwände** | rissige Wände: Feldschlag **oder** Bellen öffnet sie → versteckte Räume, oft **Abkürzungen** (Zeitgewinn) | E2 |
| **Sammelkarten** („NOVA-Sammelkarten“) | 1 je Gegnertyp + Sonderkarten, versteckt oder als seltener Drop; Album im Pausemenü; vollständige Etagen-Seite → Titel + kleine dauerhafte Boni (z. B. +1 % Schaden gegen diesen Typ) | E2 |
| **Regie-Notizen** | versteckte Post-its mit Backstage-Witzen von M.O.D. (Easter Eggs), je +Follower | E2 |
| **Optionale Räume** | hinter Schlüsseln/Events, mit Show-Bossen oder Fanclub-Aufträgen | E2 |
| **Wiederholungen** | abgeschlossene Etagen im späteren Hub ohne Countdown-Tod erneut spielbar (halbe Belohnungen) — für Sammler:innen | Phase 5 |
| Timer-Modus „entspannt“ | bereits in 04 Kap. 3.6 geplant (Barrierefreiheit) | Phase 4 |

### 2.8 Jetzt vs. später (Zusammenfassung)

| Jetzt (Pakete A–D) | Später |
|---|---|
| Figurenwahl, Bellen, Partner automatisch (A) | Rollentausch-Achievements, Mopsula-Kamera-Feinschliff |
| Talentwahl komplett inkl. UI (B) | Talent-Reset, seltene Talente |
| Spezies/Spezialisierung: Datenmodell, Validierung, Regeln, Tests (B) | Casting-UI, Optik, Etage 3 |
| Marotten, Show-Wetten, Unterhosen-Liga, Achievements (C) | Fanclub-Wetten, Liga-Optik (Pfoten-Boxershorts, barfuß-Rig) |
| KI-Admin: Schnittstelle, Twist-Katalog, Applier, Referenz-Dienst (D) | Live-Betrieb, Votes, Live-Events (S1–S3) |
| — | Fanclubs, 3. Figur, Show-Bosse, Geheimnisse, Sammelkarten (Phase 3/4) |

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

---

## 4. M.O.D.-Marotten & Show-Wetten

### 4.1 Prinzip in drei Sätzen

1. Zu Beginn jeder Etage verkündet M.O.D. ihre **Vorlieben** (Etage 1: eine, ab Etage 2: zwei) — deterministisch aus dem Seed.
2. Jeder gewonnene Kampf (bzw. jede Erkundungsphase), der eine Vorliebe erfüllt, füllt ein **Herz** (♥) und bringt Hype; drei Herzen =
   **Wette gewonnen** → Fan-Box + Follower.
3. Daneben gilt immer die **Unterhosen-Liga**: wer ohne Rüstung und Accessoire spielt, bekommt dauerhaft mehr Hype und Follower.

### 4.2 Ablauf je Etage

| Schritt | Regel |
|---|---|
| Auswahl | `Marotten.announce(state, data, floor_index)`: Pool = Einträge mit `rotation: true` und `min_floor ≤ Etage`; Etage 1 nur `starter: true`; Anzahl 1 (E1) bzw. 2 (ab E2); möglichst keine Wiederholung der Vorliebe(n) der Vor-Etage; Zufall `SeedUtil.derive(state.seed, "marotte", floor_index)`. Ergebnis in `ShowState.marotten.active`. **Nicht aufgezeichnet** — folgt aus Seed + `floor`-Command |
| Ansage | M.O.D. `marotte_announce:<id>` nach dem Start des Countdowns (E1: nach dem Tutorial-Kampf, GDD B2), sonst bei `floor_start` |
| Treffer | Auswertung beim Kampfende (Sieg) bzw. beim passenden Trigger, Bedingung über `ConditionExpr` (Kap. 4.6); je Kampf zählt jede Vorliebe höchstens 1× |
| Wette gewonnen | bei `goal` Treffern (Standard 3): Belohnung (4.5), M.O.D. `marotte_won:<id>`, Zähler `s.bets_won` +1, Trigger `show_bet` |
| Etagenende | nicht gewonnene Wetten verfallen **ohne** Abzug; M.O.D. höchstens eine Schmoll-Zeile (`marotte_missed`) |

### 4.3 Unterhosen-Liga (immer verfügbar, `mar_unterhose`)

**Mapping auf unsere drei Slots** (GDD §6, keine neuen Slots, keine Save-Migration): „ohne Hose“ = **Rüstungs-Slot leer**
(Kleidung ist bei uns Rüstung: Hoodie, Warnweste, Hundepulli …); „barfuß“ = **Accessoire-Slot leer** (Schuhwerk ist bei uns
Accessoire: Gummistiefel, Turnschuhe). Die **Waffe ist erlaubt** — Kai mit Wischmopp in Boxershorts ist das Bild.

| Stufe | Bedingung (zu Kampfbeginn geprüft, gilt den ganzen Kampf) | Hype-Gewinne | Follower | HUD-Badge |
|---|---|---|---|---|
| 0 | sonst | ×1.0 | ×1.0 | — |
| **1 „Unterhosen-Liga“** | **gesteuerte Figur** (`GameState.hero`): `armor == ""` **und** `accessory == ""` | **×1.25** | **×1.20** | „UNTERHOSEN-LIGA ×1,25“ |
| **2 „Ohne alles“** (ultimativ) | **beide** Figuren: `armor == ""` und `accessory == ""` | **×1.50** | **×1.40** | „OHNE ALLES ×1,5“ |

- **Schwerer, aber belohnt:** weniger DEF/RES (z. B. Kai L5 ohne Kanalarbeiter-Kombi: DEF 15 statt 24). Ausgleich ist
  thematisch: mehr Hype ⇒ Sponsoren-Schwellen 70/85/100 werden öfter erreicht ⇒ mehr System-Geschenke (Limits GDD §7.4 bleiben).
  „Das Publikum liebt Mut — und Sponsoren lieben das Publikum.“
- **Etagen-Bonus:** Wurden alle (≥ 3) gewonnenen Kämpfe einer Etage in Stufe ≥ 1 bestritten → 1 Fan-Box („Mut-Paket“) bei der
  Etagen-Bilanz; alle (≥ 5) in Stufe 2 → zusätzlich Achievement `ach_oa_floor`.
- **Keine Strafe beim Wiederanziehen:** Stufe sinkt einfach (Zeile `liga_leave`, einmal je Etage).
- **Mopsula als gesteuerte Figur:** ohne Pulli/Umhang und ohne Accessoire → Stufe 1 (`liga_enter:1:mopsula`).

**Achievement-Kette „Ohne alles“** (neu, Trigger `show_bet`, Kap. 4.6; Belohnungen nach GDD §8):

| ID | Name | Bedingung | Box | Hidden |
|---|---|---|---|---|
| `ach_ul_first` | Luftig | `e.kind == "liga" && e.event == "battle" && e.tier >= 1` | bronze | — |
| `ach_ul_boss` | Kalte Füße | `e.kind == "liga" && e.event == "battle" && e.tier >= 1 && e.is_boss == true` | silver | — |
| `ach_oa_first` | Ohne alles, bitte | `e.kind == "liga" && e.event == "battle" && e.tier == 2` | silver | — |
| `ach_oa_floor` | Einmal ohne alles | `e.kind == "liga" && e.event == "floor" && e.floor_tier == 2 && e.battles >= 5` | gold | — |
| `ach_oa_flawless` | Mit scharf | `e.kind == "liga" && e.event == "battle" && e.tier == 2 && e.is_floor_boss == true && e.party_kos == 0` | gold | ✓ |
| `ach_bets_5` | M.O.D.s Liebling | `e.kind == "marotte" && e.event == "won" && s.bets_won == 5` | silver | — |

**M.O.D.-Zeilen Liga** (Präfix `liga_`, nicht sexuell, Paragrafen-/Imbiss-Humor):

| Tag | Zeile |
|---|---|
| `liga_hint` (1. Safe Room, einmalig) | „Übrigens: Wer ohne Rüstung und ohne Schuhe kämpft, kriegt bei mir Bonuspunkte. Ich sage das nur.“ |
| `liga_enter:1` | „Kandidat:in ohne Hose und ohne Schuhe. § 3 Kleiderordnung sagt nein, die Quote sagt JA.“ |
| `liga_enter:1:mopsula` | „Der Graf trägt heute: Würde. Sonst nichts. Das Publikum ist entzückt.“ |
| `liga_enter:2` | „Einmal Kandidat:innen ohne alles, bitte. Mit scharf? Nein, mit Wischmopp.“ |
| `liga_win` | „Gewonnen. In Unterhose. Ich reiche die Szene beim Preis für Zivilcourage ein.“ |
| `liga_floor` | „Eine ganze Etage ohne alles. Die Rechtsabteilung prüft, ob das legal ist. Es ist legendär.“ |
| `liga_leave` | „Hose wieder an? Verständlich. Die Zuschauer:innen seufzen leise.“ |

### 4.4 Die rotierenden Marotten (11)

Alle Bedingungen sind **maschinenprüfbar** über den Kontext `show_bet`-/`marotte_battle`-Payload (Kap. 4.6); `e.won == true`
ist bei Kampf-Marotten implizit (nur Siege werden ausgewertet).

| ID | HUD-Name („M.O.D. mag heute: …“) | Trigger / Bedingung | Starter (E1) | Ansage (`marotte_announce:<id>`) | Treffer (`marotte_hit:<id>`) |
|---|---|---|---|---|---|
| `mar_mop_only` | **Nur der Mopp** | Kampf: `e.kai_weapon == "itm_wpn_mop"` | ✓ | „Ich habe heute eine Schwäche für Wischmopps. Fragen Sie nicht. Wischen Sie.“ | „Mit dem Mopp! Ich bekomme Gänsehaut. Ich habe keine Haut.“ |
| `mar_graf_finale` | **Der Graf hat das letzte Wort** | Kampf: `e.last_kill_member == "mopsula"` | ✓ | „Heute will ich den Grafen glänzen sehen. Den letzten Treffer, bitte. Mit Etikette.“ | „Der Graf beendet es. Mit einem Niesen. Zeitlos.“ |
| `mar_variety` | **Stilnote** | Kampf: `e.distinct_actions >= 4` | ✓ | „Heute zählt Stil. Vier verschiedene Aktionen in einem Kampf, und ich vergebe Herzchen.“ | „Abwechslung! Die Jury zückt die Zehn.“ |
| `mar_sneaky` | **Leise Sohle** | Kampf: `e.encounter_type == "preemptive"` | ✓ | „Ich mag heute Überraschungen. Von hinten. Oder mit Gebell. Hauptsache zuerst.“ | „Erwischt, bevor sie es merkten. Ich liebe Pünktlichkeit.“ |
| `mar_pacifist` | **Gewaltfreie Minuten** | `explore_tick`: `e.seconds_since_battle == 180` | — | „Heute mag ich es ruhig. Drei Minuten ohne Prügelei, und ich werde sentimental.“ | „Drei Minuten Frieden. Die Werbekunden sind nervös. Ich bin gerührt.“ |
| `mar_secondhand` | **Second-Hand-Schick** | Kampf: `e.equip_all_common == true` (alle belegten Slots beider Figuren `common`) | — | „Meine Laune heute: Flohmarkt. Nur gewöhnliche Ausrüstung, bitte. Vintage ist Quote.“ | „Gewonnen in Ramsch-Couture. Die Modeabteilung weint vor Glück.“ |
| `mar_speed` | **Schnellschnitt** | Kampf: `e.party_turns <= 3 && e.is_boss == false` | — | „Ich habe heute wenig Sendezeit. Kämpfe in höchstens drei Zügen, und ich liebe Sie.“ | „Zack, fertig! So schnell schneidet nicht mal mein Praktikant.“ |
| `mar_stunt` | **Akrobatik-Abend** | Kampf: `e.stunts_success >= 1` | — | „Heute Abend: Akrobatik! Ein gelungener Stunt pro Kampf, und ich bin Ihr Fan.“ | „Gelandet! Ich habe die Zeitlupe schon dreimal angesehen.“ |
| `mar_bio` | **Bio-Siegel** | Kampf: `e.items_used == 0 && e.gifts == 0` | — | „Heute bin ich auf Natur. Keine Items, keine Sponsoren. Ja, ich höre mich selbst.“ | „Ohne Zusatzstoffe gewonnen. Ich verleihe Ihnen das Siegel ‚garantiert ungesponsert‘.“ |
| `mar_brave` | **Kein Schritt zurück** | Kampf: `e.defends == 0 && e.flee_attempts == 0` | — | „Heute mag ich Mut. Kein Verteidigen, kein Weglaufen. Nur nach vorn.“ | „Nicht einen Schritt zurück! Die Versicherung hat aufgelegt.“ |
| `mar_gourmet` | **Schwachstellen-Feinschmecker:in** | Kampf: `e.weakness_hits >= 3` | — | „Ich habe Appetit auf Schwachstellen. Drei pro Kampf, serviert mit Stil.“ | „Genau da, wo es wehtut. Drei Gänge, null Mitleid.“ |

Sonderzeilen: `marotte_won:<id>` (Fallback `marotte_won`: „Wette gewonnen! Sie haben verstanden, was ich mag. Das ist mir fast
unheimlich.“), `marotte_missed` („Meine Vorliebe blieb unerfüllt. Ich trage es mit Fassung. Und Statistik.“).

### 4.5 Belohnungen (Startwerte)

| Ereignis | Belohnung |
|---|---|
| Treffer (♥) | Hype **+6** (× `hype_gain_mult`), Follower dieses Kampfes **×1.15** (`follower_pm` 1150); Herz-Animation + Treffer-Zeile |
| Wette gewonnen (3 ♥) | **1 Fan-Box** (`box_fan` → `pending_lootboxes`), Follower **+30**, Hype +5, Zähler `s.bets_won` +1 |
| Liga-Etagenbonus | 1 Fan-Box (siehe 4.3) |
| Obergrenze | ≤ 3 Boxen je Etage aus Show-Wetten (2 Wetten + Liga) — GDD §13 Lootbox-Band wird auf **15–22** erweitert (Paket C) |

Alle Werte stehen in `marotten.json` (`reward`) und sind per Balancing änderbar.

### 4.6 Bedingungen & Kontext (maschinenprüfbar)

Neuer Auswertungskontext **`marotte_battle`** (gebaut von `MarottenRules.battle_context(state, data, result, tally)` aus
`BattleResult` + einer Kampf-Strichliste, die `Show.on_battle_event` füllt) — Schlüssel:

`won, hero, party_turns, items_used, gifts, defends, flee_attempts, distinct_actions, stunts_success, weakness_hits,
min_party_hp_pct, party_kos, last_kill_member, encounter_type, is_boss, is_floor_boss, boss_id, kai_weapon, equip_all_common,
hero_armor_empty, hero_acc_empty, party_armor_empty, party_acc_empty, liga_tier`

Bedingungen nutzen die vorhandene Grammatik (`ConditionExpr`, 02_TECH §4.4.9: `e.`/`s.`/`f.`, `== != >= <= > <`, `&&`). Der
Validator prüft `e.`-Schlüssel gegen diese Liste (bzw. gegen die `explore_tick`-Payload).

Neuer Achievement-Trigger **`show_bet`** (Payload): `kind ("liga" | "marotte"), event ("battle" | "floor" | "won"), id, tier,
floor_tier, battles, is_boss, is_floor_boss, boss_id, party_kos, floor`. Neue `StatIds`: `bets_won`, `liga_battles`.

### 4.7 HUD & Menüs

- **TV-Overlay (Erkundung + Kampf):** unter der Hype-Leiste eine Zeile **„M.O.D. MAG HEUTE: Nur der Mopp ♥♥♡ · Stilnote ♡♡♡“**
  (max. 2 Einträge, 18 px, abschaltbar: Optionen → „Show-Wetten anzeigen“). Gewonnene Wette: Eintrag golden mit Haken.
- **Liga-Badge** neben „● LIVE“: „UNTERHOSEN-LIGA ×1,25“ bzw. „OHNE ALLES ×1,5“ (Magenta/Gelb), nur wenn aktiv.
- **Kampfende:** Herz fliegt aus dem Ergebnis-Panel in die HUD-Zeile; Toast „♥ M.O.D. gefällt das (+6 Hype)“.
- **Pausemenü-Tab „Show-Wetten“:** aktive Vorlieben mit Bedingung im Klartext, Fortschritt, Liga-Stufe mit Erklärung, bisher
  gewonnene Wetten.

### 4.8 Fairness-Regeln (verbindlich)

1. **Sichtbar und freiwillig:** Vorlieben werden angesagt und angezeigt; es gibt keinen versteckten Zwang, keine Menü-Sperre.
2. **Nie Pflicht, nie Strafe:** Ignorieren kostet nichts (kein Hype-Abzug, keine schlechteren Drops). M.O.D. schmollt höchstens
   einmal je Etage.
3. **Keine Paywall:** Nichts davon ist kaufbar, nichts hängt an Zuschauer-Geschenken; `mar_bio` belohnt sogar den Verzicht.
4. **Gleich für alle:** Die Auswahl folgt aus dem Seed — in Event-Läufen (auch Pur-Liga) haben alle dieselben Vorlieben
   (abschaltbar per `rules.marotten.enabled`).
5. **Lesbar:** jede Bedingung in einem Satz im Menü; keine Bedingung braucht Wissen, das das Spiel nicht zeigt.
6. **Gedeckelt:** Belohnungen in Show-Währung (Hype, Follower, Fan-Box), höchstens 3 Boxen je Etage; keine Stat-Boni, die
   Kampf-Balancing kippen.
7. **Barrierefrei:** Liga und Wetten gelten im Vorabendprogramm genauso; Anzeige abschaltbar.

### 4.9 Datenmodell `marotten.json` (`MarotteDef`, Präfix `mar_`)

```json
{"schema": 1, "entries": [
 {"id": "mar_mop_only", "name": "Nur der Mopp", "desc": "Gewinne Kämpfe, während Kai den Wischmopp trägt.",
  "kind": "battle", "trigger": "marotte_battle", "condition": "e.kai_weapon == \"itm_wpn_mop\"",
  "goal": 3, "rotation": true, "starter": true, "min_floor": 1, "weight": 2,
  "reward": {"hit_hype": 6, "hit_follower_pm": 1150, "won_box": "box_fan", "won_followers": 30, "won_hype": 5},
  "mod_tag": "mar_mop_only"},
 {"id": "mar_unterhose", "name": "Unterhosen-Liga", "desc": "Ohne Rüstung und ohne Accessoire kämpfen.",
  "kind": "liga", "trigger": "marotte_battle", "condition": "e.liga_tier >= 1",
  "goal": 0, "rotation": false, "starter": false, "min_floor": 1, "weight": 1,
  "reward": {"tiers": [{"tier": 1, "hype_pm": 1250, "follower_pm": 1200}, {"tier": 2, "hype_pm": 1500, "follower_pm": 1400}],
             "floor_box": "box_fan"},
  "mod_tag": "liga"}
]}
```

`kind` ∈ `battle | explore | liga`; `trigger` ∈ `marotte_battle | explore_tick`; Texte `name` ≤ 28 Zeichen (HUD), `desc` ≤ 80.

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
 │                       Takt 30 s Lauf-Uhr oder Höhepunkt, min. 10 s Abstand)               │
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
                     │ POST /v1/mod/turn  (kurzlebiges Sitzungs-Token, ≤ 8 KB)
                     ▼
 mod-brain (Server, Python, services/mod-brain)
   Schema-Prüfung ─► Rate-Limit ─► Prompt (System: Persona + Regeln + Twist-Katalog [gecacht];
   User: Zustandszusammenfassung + Ereignisse) ─► Claude (structured output) ─► Sicherheitsfilter
   ─► Twist-Validierung (gleiche Regeln wie der Kern) ─► {"lines": [...], "twist": {...} | null}
   Fehler/Timeout/Refusal/Filtertreffer ─► {"lines": [], "twist": null}  (Spiel spricht Skript-Zeilen)
```

### 5.4 Protokoll (Schema 1)

**Anfrage** `POST /v1/mod/turn`:

```json
{"schema": 1, "req_id": "r_000123", "run_ref": "pseudonym-hash", "lang": "de",
 "state": {"floor": 1, "timer": "12:30", "hype": 64, "viewers_k": 4, "hero": "kai", "liga_tier": 1,
           "party": [{"id": "kai", "lvl": 5, "hp_pct": 72, "spc": "", "cls": ""}, {"id": "mopsula", "lvl": 5, "hp_pct": 40}],
           "bets": [{"id": "mar_mop_only", "hits": 2, "goal": 3}], "phase": "explore"},
 "events": [{"t": "kill", "enemy": "enm_kanalratte", "by": "stunt"}, {"t": "achievement", "id": "ach_stunt_first"}],
 "recent_lines": ["…", "…"],
 "allowed_twists": ["tw_lights_out", "tw_overtime"], "spice_left": 1, "last_twist_result": ""}
```

**Antwort** (structured output, JSON-Schema mit `additionalProperties: false`):

```json
{"lines": [{"text": "Ein Stunt mit Wischmopp. Ich lasse das als Kunst durchgehen.", "tag": "live:stunt", "voice": "mod"}],
 "twist": {"id": "tw_overtime", "params": {"seconds": 60}},
 "mood": "snarky"}
```

`lines` 0–3, `text` ≤ 110 Zeichen, einziger erlaubter Platzhalter `{name}` (der Client setzt den Namen ein — der Dienst kennt ihn
nie), `voice` ∈ `mod | mopsula | chat`, `twist` nur aus `allowed_twists`, `mood` ∈ `snarky | sweet | neutral`. Längen- und
Wertebereiche prüft zusätzlich der Post-Filter (Schema-Constraints allein reichen nicht).

### 5.5 mod-brain: Modell und API-Nutzung

| Punkt | Festlegung |
|---|---|
| SDK | offizielles Python-SDK `anthropic` (Version bei Umsetzung pinnen) |
| Modell (Standard) | **`claude-opus-5-5`** (Konfig `MOD_BRAIN_MODEL`) |
| Denken | adaptiv (bei Opus 5.5 immer an — `thinking` weglassen; `disabled`/`budget_tokens` sind dort ein 400) |
| Effort | **`low`** für Kommentar-Runden (`output_config.effort`), konfigurierbar je Route (`lines` / `director`); Opus-5.5-Standard wäre `medium`, daher explizit setzen |
| Ausgabeformat | **Structured Outputs** über `output_config.format` (`type: json_schema`, Schema aus dem Pydantic-Modell) bzw. `client.messages.parse(...)`; keine Prefills |
| Prompt Caching | System-Prompt = Persona + Tonregeln (GDD §11.1) + ~20 Beispielzeilen + harte Regeln + Twist-Katalog (≈ 3–6 k Tokens, über dem Mindestpräfix von 512 Tokens für Opus 5.5) mit `cache_control: {"type": "ephemeral"}` am letzten System-Block; **byte-stabil** (keine Zeitstempel, sortierter Katalog); alles Variable nur in der User-Nachricht. Kontrolle über `usage.cache_read_input_tokens` |
| TTL | Standard 5 min (Runden alle ≤ 30 s halten den Cache warm); 1 h nur für Live-Sendungen mit Vorab-Aufwärmen |
| Zustandslos | jede Runde = 1 System + 1 User-Nachricht (keine wachsende Konversation, keine wiederverwendeten Thinking-Blöcke); Kontinuität über `recent_lines` + `state` |
| Refusal | `stop_reason == "refusal"` immer vor dem Lesen von `content` prüfen; serverseitiger Fallback `fallbacks: "default"` (Beta `server-side-fallback-2026-07-01`) eingeschaltet; verweigert die ganze Kette → leere Runde (Skript übernimmt) |
| Fehler | SDK-Retries (429/5xx) auf 1 begrenzt, Timeout 5 s je Runde; danach leere Runde |

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

**Günstigere Modelle sind eine Betreiber-Kostenentscheidung** je Route (`claude-sonnet-5-5`, `claude-haiku-5-5`): Wechsel nur über
`MOD_BRAIN_MODEL`, Persona bleibt; vorher Stichproben-Eval (Humor-Redaktion bewertet 50 Runden je Modell, Kap. 5.12 Gate).

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
 "sources": ["mod_brain", "vote", "schedule", "dev"], "mod_tag": "twist_applied_tw_lights_out"}
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
| Quelle | `src` ∈ `mod_brain` (KI), `vote` (S2), `schedule` (Event-Fahrplan), `dev` (QA, Debug F6) — je Lauf über `rules.twists.sources` freigegeben |
| Gleichzeitig | max. **1** aktiver spielrelevanter Twist; Präsentations-Twists dürfen parallel laufen |
| Abstand | ≥ **90 s** Erkundungszeit zwischen Ende und nächstem spielrelevanten Twist |
| Je Etage | ≤ **4** spielrelevante Twists, davon ≤ **1** `spicy` („Schärfe-Budget“, an den Dienst als `spice_left`) |
| Nie nach unten treten | `spicy` nur, wenn Party-HP im Schnitt ≥ 50 %, Timer ≥ 180 s, nicht im/neben einem Boss-Raum |
| Zeitpunkt | Anwendung nur in der Erkundung an einer Tick-Grenze (nie im Kampf, nie in Dialogen/Menüs); Kampf-Twists wirken ab dem **nächsten** Kampf, Safe-Room-Twists beim **nächsten** Besuch |
| Zufall | Twists mit Zufall (z. B. Rattenregen-Zelle) würfeln mit `SeedUtil.derive(floor_run.loot_seed, "twist", n)` — **die KI wählt WAS, nie das Ergebnis** |
| Aufzeichnung | externes Command `{"t": "twist", "twist": {"schema": 1, "id", "n", "src", "params", "duration", "req"}}`, `cmd_id` 0 (wie `gift`, 02_TECH §3.4), aufgezeichnet bei der **Anwendung** → `Game.replay_log` speist es identisch ein; der Verifier prüft dieselben Regeln (manipulierte Twists → Fehler) |
| Zustand | `GameState.flags["live"]["twist"]` = `{n, active: [{id, n, until_tick \| battles_left \| visits_left, params}], last_end_tick, floor, floor_count, floor_spicy, once}` — im Hash und im Save |
| Ablauf | `RunSim.step` zählt Laufzeit-Twists auf Erkundungs-Ticks herunter (`ExploreEvent` `TWIST_ENDED` → `Events.twist_ended`); Kampf-/Besuchs-Twists zählen bei `apply_battle_result` / `enter_safe_room` herunter |
| **Pur-Liga** | **keine** spielrelevanten Twists (nur `gameplay: false`), keine KI-Twists |
| **Gewertete Event-Läufe (Show-Liga)** | KI-Twists **aus**; stattdessen optional **fester Fahrplan** in `events.json → rules.twists.schedule: [{tick, id, params}]` (für alle gleich, Teil von `rules_hash`); die KI liefert dort nur Sprüche |
| Kampagne | KI-Twists nur, wenn „M.O.D. live“ auf **„Kommentar + Regie“** steht (Opt-in) |

Ablehnungsgründe (`TwistApplier.validate`): `unknown_twist`, `not_in_slice`, `source_not_allowed`, `league_pur`,
`params_out_of_range`, `busy`, `cooldown`, `floor_cap`, `spice_budget`, `party_weak`, `timer_low`, `wrong_phase`, `once_per_floor`.
Gemeinsame Testfälle in `tests/fixtures/live/twist_cases.json` werden **vom GDScript-Test und von pytest** gelesen → beide Seiten
entscheiden nachweislich gleich.

### 5.8 Latenz & Fallback

- Das Spiel **wartet nie** auf die KI. Story-, Regel- und Pflichtzeilen kommen immer aus dem Skript (`Show.say`).
- KI-Zeilen füllen **Sendepausen**: frühestens 8 s nach der letzten M.O.D.-Zeile, niedrigste Priorität (unter `ModAnnouncer`-Rang
  „Rest“), nie während `death`/`boss_*`/`timer_*`.
- Client-Timeout 6 s je Runde; Antworten, die älter als 12 s (Lauf-Uhr) sind, werden verworfen (außer `tag: "live:evergreen"`).
  Twist-Vorschläge gelten bis 20 s nach der Runde und werden bei der Anwendung **neu** geprüft.
- Zielwerte (messen in S1): Median < 3 s, p95 < 6 s je Runde bei Effort `low` **[zu prüfen]**. Status über `Events.mod_live_status`
  (`off` / `ok` / `degraded`); bei 3 Fehlern in Folge pausiert der Link 5 min (Skript spricht weiter, niemand merkt es).

### 5.9 Inhaltssicherheit

1. **Persona-Regeln** im System-Prompt: fiktive Moderatorin; siezt Kai; Ton nach GDD §11.1; Zielscheibe Show/Konzern/Bürokratie;
   verboten: reale Politik/Parteien/Personen/Marken, sexuelle Inhalte, Beleidigungen/Slurs, Gewaltverherrlichung über Comic-Niveau,
   Kauf-/Spendenaufrufe, Echtgeld, persönliche Daten, Behauptung ein Mensch zu sein.
2. **Eingabe-Hygiene:** In den Prompt gelangen nur Enum-IDs und Zahlen aus dem Spiel — **kein Freitext** von Spieler:innen oder
   Zuschauer:innen (keine Namen, kein Chat) → keine Prompt-Injection über Spielerdaten. Zuschauer-Einfluss später nur als
   aggregierte Zahlen (Stimmen, Applaus).
3. **Post-Filter** (Dienst **und** Client `Show.say_external`): Länge ≤ 110, nur `{name}` als Platzhalter, keine URLs/Ziffernfolgen
   wie Telefonnummern, Sperrliste (Slurs, sexuelle Begriffe, Politik-Begriffe/Namen, Kaufdruck-Wörter wie „kauf“, „spende“,
   „nur noch“, „schnell“, „Bits“, „€“), Sprache Deutsch. Treffer → Zeile verworfen und gezählt.
4. **L13/L16 (05):** Die KI erwähnt Sponsor-Fenster, Geschenke und Preise **nie**; Dank für Geschenke bleibt bei den geschriebenen,
   preisunabhängigen Zeilen.
5. **Not-Aus:** Server-Flag schaltet alle KI-Antworten auf leer; Stichproben-Review (Humor-Redaktion) wöchentlich in S1–S3.
6. **Plattformen:** Steam verlangt die Offenlegung von live generierten KI-Inhalten und Schutzmaßnahmen **[zu prüfen]**;
   Altersfreigabe-Ziel USK/PEGI 12 (04 Kap. 1.3) bleibt Maßstab für den Filter.

### 5.10 Datenschutz & Sicherheit

- **Keine personenbezogenen Daten im Prompt:** kein Spielername (nur `{name}`), keine Account-, Geräte- oder IP-Daten;
  `run_ref` ist ein zufälliges Pseudonym je Lauf.
- **Schlüssel nur serverseitig** (`ANTHROPIC_API_KEY` aus dem Secret-Store); der Client authentifiziert sich mit kurzlebigem
  Sitzungs-Token (S1 Dev: nur `localhost`/Staging mit Dev-Token aus der Umgebung).
- Rate-Limits je Token und IP (max. 4 Runden/min, 1 Twist/90 s), Anfragegröße ≤ 8 KB, striktes Schema.
- Logs: pseudonymisiert, Aufbewahrung 14 Tage (S1), für Missbrauchs- und Qualitätsanalyse; Datenschutzerklärung nennt die
  Verarbeitung (nur bei Opt-in) **[DSGVO-Prüfung vor S1-Außentest, zu prüfen]**.

### 5.11 Kosten je Spielstunde **[zu prüfen]**

Annahmen je Runde: System 4 000 Tokens aus dem Cache, 900 variable Eingabe-Tokens, 350 Ausgabe-Tokens (inkl. Denken bei `low`);
**90 Runden/h** (≈ alle 40 s); ~4 Cache-Schreibvorgänge/h (Start, Pausen > 5 min). Preise: Stand Skill-Referenz 2026-10-06,
vor einer Budgetentscheidung prüfen.

| Modell | Preis Eingabe / Ausgabe / Cache-Lesen je 1 M | ≈ je Runde | **≈ je Spielstunde** |
|---|---|---|---|
| `claude-opus-5-5` (Standard) | $4 / $20 / $0.20 | $0.011 | **≈ $1.0–1.2** |
| `claude-sonnet-5-5` | $2 / $10 / $0.20 | $0.006 | ≈ $0.55–0.65 |
| `claude-haiku-5-5` | $0.10 / $0.50 / (≈ $0.01) | $0.0003 | ≈ $0.03 |

**Einordnung:** Bei einem Premium-Spiel (19,99 €, ~20 h Spielzeit) wären Opus-Kommentare **pro Spieler:in** dauerhaft zu teuer
(≈ $20+ je Kopf). Deshalb:

- **Kampagne:** Standard bleibt Skript (+ KI-Redaktion offline). „M.O.D. live“ ist Opt-in (Beta, Streamer:innen); Modellwahl je
  Route ist Betreiberentscheidung.
- **Live-Sendungen (SHOWRUN):** **eine** KI-Regie je Sendung, nicht je Zuschauer:in → Opus ≈ $2–3 pro 90-min-Sendung, unabhängig von
  der Zuschauerzahl. Hier passt das Standardmodell am besten.
- **KI-Redaktion (S0.5):** Entwürfe per Batch-API (−50 %) — Cent-Beträge je 100 Zeilen.

### 5.12 Stufen

| Stufe | Inhalt | Gate (weiter, wenn …) |
|---|---|---|
| **S0 (jetzt)** | Skript-M.O.D. wie heute; `ScriptedModVoice` als Standard-Provider; Twist-Katalog + `TwistApplier` offline nutzbar (Debug F6, Tests, Event-Fahrplan); Referenz-Dienst mit gemocktem Client getestet | Pakete A–D grün |
| **S0.5** | **KI-Redaktion**: Claude erzeugt Spruch-Entwürfe je Tag (Batch), Humor-Redaktion wählt aus → `mod_lines.json` | ≥ 30 % der Entwürfe „sendefähig“ laut Redaktion |
| **S1** | KI-Zeilen über `mod-brain` (Staging), nur Dev-/Debug-Builds, Einstellung „M.O.D. live: Kommentar“ | Median-Latenz < 3 s, Filter-Treffer < 2 %, Redaktion bewertet ≥ 60 % von 100 Runden „lustig oder passend“, Kosten je Stunde gemessen |
| **S2** | KI-Twists (Kampagne Opt-in „Kommentar + Regie“), Streamer-Modus; Votes nutzen denselben Katalog (05 S2) | 0 Replay-Abweichungen in 1 000 Bot-Läufen mit Twists, Playtest: Twists als „fair“ bewertet (≥ 70 %) |
| **S3** | Live-Events mit Publikum: eine KI-Regie je Sendung, kombiniert mit Votes (05 S2/S3); Zuschauer-Input nur aggregiert | Rechts-/Plattformprüfung (Offenlegung, Jugendschutz), Moderations-Prozess steht |

---

## 6. Entscheidungen zu den fünf offenen Sponsor-Fenster-Fragen (05 Kap. 12.2 Nr. 17/18)

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
   # --- Talents & casting (06 §2/§3, package B) ----------------------------------
   signal talent_pending(member_id: String, level: int)
   signal talent_picked(member_id: String, talent_id: String)
   # --- Show bets / Marotten / Liga (06 §4, package C) ----------------------------
   signal marotten_announced(ids: PackedStringArray)
   signal marotte_progress(marotte_id: String, hits: int, goal: int)
   signal marotte_won(marotte_id: String)
   signal liga_changed(tier: int)
   # --- KI-Admin (06 §5, package D) -------------------------------------------------
   signal twist_applied(twist: Dictionary)
   signal twist_ended(twist_id: String)
   signal mod_live_status(status: StringName)                                   # &"off" | &"ok" | &"degraded"
   ```
2. **`core/live/command.gd`** — `TYPES` += `"hero"`, `"talent"`, `"casting"`, `"twist"` (Twist wird vom Hook zum echten Typ;
   `EXTERNAL` bleibt `["gift", "twist"]`); Feldprüfung: `hero {id}`, `talent {member, id}`, `casting {member, species, class}`,
   `twist {twist: Dictionary}`.
3. **`autoload/game.gd`** — fertige Fassaden (Rumpf: Wächter → `record` → Kern-Klasse → Signal) und die Replay-Zweige:
   `new_game(…, hero: String = "kai")`, `set_hero(id) -> bool`, `pick_talent(member_id, talent_id) -> bool`,
   `choose_casting(member_id, species_id, class_id) -> bool`, `apply_twist(twist: Dictionary) -> String` (Grund, `""` = angewendet),
   `twist_effect_pm(key: String, default_pm: int) -> int`; Aufrufe `TwistApplier.on_battle_end(state)` in `apply_battle_result`,
   `TwistApplier.on_safe_room(state)` in `enter_safe_room`, Twist-Effekt in `open_chest` (Credits). `ModLiveLink` wird in `_ready`
   nur angelegt, wenn `settings.mod_live != &"off"` und nicht ephemer.
4. **Zustand** (alle additiv, Defaults beim Laden → **kein Save-Versionssprung**, `SaveCodec.VERSION` bleibt 1; feste Hash-Erwartungen
   in Tests werden in Schritt 0 nachgezogen):
   `GameState.hero: String = "kai"` · `PartyMember.talents: Dictionary` (id → Rang), `talent_pending: PackedInt32Array`,
   `species_id: String = ""` · `ShowState.marotten: Dictionary = {}` · Twist-/Comeback-Zustand unter `flags["live"]` (kein Feld).
   `GameState.hype_gain_mult/follower_mult` multiplizieren zusätzlich `Talents.hype_pm/follower_pm`, `MarottenTracker.liga_hype_pm/
   liga_follower_pm` und `TwistApplier.effect_pm(state, "hype_gain_pm", 1000)` (Stubs: 1000).
5. **`autoload/game_settings.gd`** — `partner_auto: bool = false` (`game/partner_auto`), `show_bets_hud: bool = true`
   (`game/show_bets_hud`), `mod_live: StringName = &"off"` (`live/mod_live`: `off | lines | lines_twists`), `mod_live_url: String = ""`
   (`live/mod_live_url`, nur Debug-Builds/Kommandozeile `--mod-live-url=`).
6. **`autoload/show.gd`** — Hook-Aufrufe in ein `MarottenTracker`-Objekt (`start_floor`, `on_battle_event`, `end_battle`,
   `_on_explore_tick`; Rückgabe-Dictionary mit Belohnungen, Stub `{}`) und Funktion `say_external(text: String, voice: StringName,
   tag: String) -> bool` (Stub `false`).
7. **Daten & Validierung** — `GameData.TABLES` += `"talents"`, `"species"`, `"marotten"`, `"twists"` (13 → 17), Def-Klassen
   `TalentDef`, `SpeciesDef`, `MarotteDef`, `TwistDef` (Stubs mit allen Feldern), Getter (`talent()`, `species_def()`, `marotte()`,
   `twist()`, `all_*`) + `DB`-Fassade; `DataValidator`: ID-Regexe `^tal_…`, `^spc_…`, `^mar_…`, `^tw_…`, je eine leere Prüffunktion
   pro Tabelle (Besitz A–D, s. 8.1), `ACH_TRIGGERS` += `"show_bet"` (+ Payload-Schlüssel), `STAT_IDS` += `bets_won`, `liga_battles`,
   `OPTIONAL_MOD_TAG_PREFIXES` += `"hero_"`, `"talent_"`, `"casting_"`, `"marotte_"`, `"liga_"`, `"mod_live_"` (`chat_bark` ist über das vorhandene
   Präfix `chat_` bereits erlaubt). Minimal gültige `data/{talents,species,marotten,twists}.json` (je 1 Eintrag) + `tests/fixtures/data_min/*.json`.
8. **`data/mod_lines.json`** — je Paket **ein Anker-Eintrag** an getrennten Stellen (`mod_hero_pick_kai_01` hinter den `intro`-Zeilen,
   `mod_talent_pick_01` hinter `level_up`, `mod_marotte_won_01` hinter `achievement_generic`, `mod_twist_applied_tw_overtime_01` hinter
   den `sponsor_window_*`-Zeilen). **Jedes Paket fügt seine Zeilen als Block direkt hinter seinem Anker ein — nie am Dateiende.**
9. **Twist-Effekt-Hooks** (Einzeiler, Stub liefert neutral): `scenes/exploration/enemy_actor.gd` (Sicht/Gehör ×
   `Game.twist_effect_pm("enemy_sight_pm"/"enemy_hear_pm", 1000)`), `core/progression/battle_bridge.gd` (`apply_result`: Credits),
   `core/progression/shop.gd` (Preis), `core/live/run_sim.gd` (Aufruf `TwistApplier.tick` + Hype-Zerfall-Pause).
10. **`scenes/boot/fullrun.gd` + `tools/fullrun.sh`** — Argumente `--hero=kai|mopsula` und `--liga=0|1|2` werden geparst und an drei
    leere Hook-Funktionen übergeben (`_apply_hero_choice`, `_apply_liga_strategy`, `_pick_pending_talents`), je Paket gefüllt.
11. **Stub-Klassen:** `core/progression/hero_rules.gd` (A), `core/progression/talents.gd`, `core/progression/casting.gd` (B),
    `core/show/marotten_tracker.gd`, `core/show/marotten_rules.gd` (C), `core/live/twist_applier.gd`, `core/show/mod_live_summary.gd`,
    `autoload/mod_voice/{mod_voice_provider,scripted_mod_voice,remote_mod_voice,mod_live_link}.gd` (D).
12. **Docs:** 02_TECH erhält Änderungsanträge **CR-16 (A) … CR-19 (D)** mit Verweis auf dieses Kapitel.

**Danach** arbeiten A–D parallel. Braucht ein Paket eine Änderung an einer Datei eines anderen Pakets oder an einer Schritt-0-Fassade,
geht das als Änderungsantrag an den Integrator (02_TECH §0.2), nicht als eigener Edit. **Merge-Reihenfolge** A → B → C → D (keine
harten Abhängigkeiten; nach jedem Merge Gate 8.6).

### 8.1 Dateibesitz nach Schritt 0

| Datei / Bereich | Schritt 0 | A | B | C | D |
|---|---|---|---|---|---|
| `autoload/events.gd`, `core/live/command.gd`, `autoload/game.gd`, `autoload/game_settings.gd` | ✎ | — | — | — | — |
| `core/progression/game_state.gd`, `party_member.gd`, `core/show/show_state.gd`, `core/data/game_data.gd`, `autoload/db.gd` | ✎ | — | — | — | — |
| `core/data/data_validator.gd` | ✎ Gerüst | — | `_check_talents`, `_check_species` | `_check_marotten` | `_check_twists` |
| `autoload/show.gd` | ✎ Hooks | — | — | Rumpf der Marotten-Hooks + Belohnungsanwendung | Rumpf `say_external` |
| `data/mod_lines.json` | ✎ Anker | Block A | Block B | Block C + Umschreiben `sponsor_window_*` | Block D |
| `scenes/boot/fullrun.gd`, `tools/fullrun.sh` | ✎ Hooks | `_apply_hero_choice` | `_pick_pending_talents` | `_apply_liga_strategy` | — |
| `scenes/exploration/enemy_actor.gd` | ✎ Twist-Zeile | Zustand `DAZED` | — | — | — |
| `core/progression/battle_bridge.gd` | ✎ Twist-Zeile | — | Talent-Krit/Element/MP | — | — |
| `core/progression/progression.gd` | — | — | ✎ Talente/Spezies in `total_stats`, `talent_pending` bei Level-up | — | — |
| `core/live/run_sim.gd`, `core/progression/shop.gd` | ✎ Hooks | — | — | — | Rumpf (Twist-Ticks) |
| `core/live/sponsor_windows.gd`, `autoload/save.gd`, `scenes/ui/show_overlay.gd`, `scenes/ui/pause_menu.gd` | — | — | — | ✎ | — |
| `data/achievements.json`, `core/show/stat_ids.gd`, `tests/test_m7_data_content.gd` (Anzahl 29 → 35) | `stat_ids` ✎ | — | — | ✎ | — |
| Szenen Titel/Erkundung/Safe Room/Kampf-Steuerung/Settings/Touch | — | ✎ | — | — | — |
| `scenes/battle/ui/battle_results.gd`, `scenes/ui/party_menu.gd` | — | — | ✎ | — | — |
| `scenes/ui/debug_overlay.gd`, `scenes/ui/global_ui.gd`, `.github/workflows/ptd-check.yml`, `services/**` | — | — | — | — | ✎ |

### 8.2 Paket A — Heldenwahl, Bellen, Partner automatisch

**Ziel:** Kap. 1 vollständig spielbar; Timer-Balancing unverändert.

| Art | Dateien |
|---|---|
| Neu | `core/progression/hero_rules.gd` (`HeroRules`), `scenes/title/hero_select.tscn` + `.gd`, `tests/test_06a_hero.gd`, `tests/test_06a_bark.gd`, `tests/test_06a_partner_auto.gd` |
| Geändert (eigen) | `scenes/title/title_flow.gd` (Ablauf Slot → Figur → Name → Modus), `scenes/title/name_entry.gd` (Überschrift je Figur), `scenes/exploration/exploration.gd` (Held:in/Partner-Spawn), `player_controller.gd` (Rig + Kapsel je Figur, Aktion Feldschlag/Bellen), `companion_follower.gd` (folgt der Held:in), `encounter_rules.gd` (`BARK_*`, `DAZE_*`, Vorteilsregel), `enemy_actor.gd` (Zustand `DAZED`), `scenes/safe_room/safe_room.gd` (Menüeintrag „Figur wechseln“), `scenes/battle/battle_controller.gd` (Partner automatisch), `scenes/battle/ui/party_panel.gd` (Stern-Marker), `scenes/ui/settings_menu.gd` (Schalter), `scenes/ui/touch_controls.gd` (Aktions-Icon Faust/Schallwelle), Block A in `mod_lines.json`, Hook `_apply_hero_choice` in `fullrun.gd` |

**APIs:**

```gdscript
class_name HeroRules extends RefCounted
const HEROES: PackedStringArray = ["kai", "mopsula"]
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

**Tests (Minimum):** Neues Spiel mit `hero` Default/Mopsula; `set_hero` nur im Safe Room; Command-Aufzeichnung + `Game.replay_log`
ergibt denselben Hash mit `hero`-Commands; alter Spielstand ohne `hero` → `"kai"`; Bellen-Geometrie (Kegel, Reichweite, Sichtlinie)
und Vorteilsregel (`DAZED` → `PREEMPTIVE` aus jeder Richtung), Immunität 15 s, Bosse unbeeinflusst; Szenentest: Erkundung mit
Held:in Mopsula spawnt das Mops-Rig als Spielerkörper, Kai folgt; Kampf mit `partner_auto`: Partner-Befehle `auto: true`,
Held:innen-Befehle manuell; Hero-Select-Szene: Default-Fokus, Touch-Trefferflächen.

**DoD:** `tools/check.sh` grün; `tools/fullrun.sh --strategy=all` grün; zusätzlich `--hero=mopsula` (Seeds 1–3) erreicht die Treppe;
`tools/perf.sh` ohne Budget-Überschreitung; Screenshots `hero_select`, Erkundung als Mopsula; GDD §2.1/§14.2 und 03_ART (Bellen-VFX)
nachgezogen.

### 8.3 Paket B — Talentwahl + Spezies/Spezialisierung (Datenmodell)

**Ziel:** Talentwahl spielbar (Kap. 2.2); Spezies/Casting als geprüftes Datenmodell (Kap. 3.4/3.6), ohne Casting-UI.

| Art | Dateien |
|---|---|
| Neu | `core/progression/talents.gd` (`Talents`), `core/progression/casting.gd` (`Casting`), Defs `core/data/defs/talent_def.gd`, `species_def.gd` (Rumpf), `data/talents.json` (24), `data/species.json` (8), `scenes/ui/talent_pick.tscn` + `.gd`, `tests/test_06b_talents.gd`, `tests/test_06b_species.gd`, `tests/test_06b_balance.gd` |
| Geändert (eigen) | `data_validator.gd` (`_check_talents`, `_check_species`; Vokabulare `TALENT_KINDS`, `TALENT_ICONS`), `progression.gd` (Talente + Spezies in `total_stats`; `talent_pending` bei Level-up), `battle_bridge.gd` (Krit/Element/MP-Talente), `scenes/battle/ui/battle_results.gd` („Talent wählen (n)“), `scenes/ui/party_menu.gd` (Talente + offene Wahl), Block B in `mod_lines.json`, Hook `_pick_pending_talents` |

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
static func hype_pm(state: GameState, data: GameData) -> int                                     # product over party, 1000 = neutral
static func follower_pm(state: GameState, data: GameData) -> int
```

`Casting` wie Kap. 3.4. Gewichteter Zug ohne Zurücklegen nur mit `rng.randi_range` (Ganzzahl), Reihenfolge der Kandidaten nach ID
sortiert (deterministisch).

**Tests (Minimum):** Angebot deterministisch (gleicher Seed/Level → gleiche 2 IDs; anderer Level → anders), nie doppelt, respektiert
`for`/`min_level`/`max_rank`; Wahl nur aus dem Angebot des ältesten offenen Levels; Wirkungen je `kind` (Stat-Rechnung exakt in
Promille, Krit, Element, MP nach Kampf, Hype-/Follower-Produkt); Save-Rundlauf inkl. alter Stände ohne Felder; Replay mit
`talent`-Commands = gleicher Hash; Validator: 24 Talente (12/12), 8 Spezies, Fehlerfälle (unbekannter `kind`, Bereich, Referenz);
`Casting.check` je Grund (Etage < 3, falsche Figur, nicht im Safe Room, gesperrt); Spezies × Klasse in `total_stats`;
**Balance-Band:** Hausmeister-/Königin-Niederlagequote mit Bot-Talentwahl (erstes Angebot) innerhalb ±5 Punkte der heutigen Werte
(GDD §13), Summe der Talentboni bei L10 ≤ +15 % je Kampfwert.

**DoD:** Gate 8.6; `fullrun --strategy=all` mit Talentwahl im Bot grün; GDD §4 (Talente), §12 (Spezies, Re-Spec) und 02_TECH §4.4
(Schemas) nachgezogen; Screenshot `talent_pick`.

### 8.4 Paket C — Marotten, Show-Wetten, Unterhosen-Liga, Sponsor-Fenster-Entscheidungen

**Ziel:** Kap. 4 spielbar inkl. HUD und Achievements; Kap. 6 Entscheidungen 1–3 umgesetzt (4/5 sind Doku/Regeln).

| Art | Dateien |
|---|---|
| Neu | `core/show/marotten_tracker.gd` (`MarottenTracker`: Zustand in `ShowState.marotten`, Auswertung, Belohnungs-Rückgabe), `core/show/marotten_rules.gd` (`MarottenRules`: `announce`, `battle_context`, `liga_tier`), Def `marotte_def.gd` (Rumpf), `data/marotten.json` (12), `scenes/ui/bets_menu.gd` (Pausemenü-Tab), `tests/test_06c_marotten.gd`, `tests/test_06c_liga.gd`, `tests/test_06c_sponsor_display.gd`, `tests/test_06c_balance.gd` |
| Geändert (eigen) | `data_validator.gd` (`_check_marotten`: Bedingungen parsen, `e.`-Schlüssel gegen Kontext 4.6), Marotten-Bereich in `show.gd`, `data/achievements.json` (+6, Kap. 4.3), `tests/test_m7_data_content.gd` (29 → 35), `scenes/ui/show_overlay.gd` (Zeile „M.O.D. MAG HEUTE“, Liga-Badge, **Sponsor-Badge ohne Sekunden**), `scenes/ui/pause_menu.gd` (Tab), `core/live/sponsor_windows.gd` (Comeback-Fenster), `autoload/save.gd` (`record_game_over` vermerkt Boss-Niederlage), `tests/test_m8_sponsor_windows.gd` (Badge-Texte, Comeback), Block C + Umschreiben `sponsor_window_open*` in `mod_lines.json`, Hook `_apply_liga_strategy` |

**APIs:**

```gdscript
class_name MarottenRules extends RefCounted
static func announce(state: GameState, data: GameData, floor_index: int) -> PackedStringArray
static func liga_tier(state: GameState) -> int                          # 0 | 1 | 2 (equipment snapshot, hero-aware)
static func battle_context(state: GameState, data: GameData, result: BattleResult, tally: Dictionary) -> Dictionary

class_name MarottenTracker extends RefCounted
func on_floor(state: GameState, data: GameData, floor_index: int) -> Dictionary        # {"announce": ids, "lines": [...]}
func on_battle_event(e: ActionEvent) -> void                                          # tally: defends, distinct actions, last kill …
func on_battle_end(state: GameState, data: GameData, result: BattleResult) -> Dictionary
	# {"hits": [ids], "won": [ids], "hype": int, "follower_pm": int, "boxes": [box_ids], "followers": int, "show_bet": [payloads]}
func on_explore_tick(state: GameState, data: GameData, payload: Dictionary) -> Dictionary
func liga_hype_pm(state: GameState) -> int
func liga_follower_pm(state: GameState) -> int
```

Die Auswertung ist reine Reaktion auf aufgezeichnete Commands und deterministische Kern-Ereignisse → **nicht** aufgezeichnet,
im Replay identisch (wie Achievements).

**Sponsor-Fenster (Kap. 6):** `ShowOverlay`-Texte nach Entscheidung 1 (Kampagne dezent, live Plakette); `SponsorWindows.on_room`
öffnet nach vermerkter Boss-Niederlage einmal neu (`kind: "boss"`, `comeback: true`); Regel-Schlüssel `boss.comeback` (Standard 1,
Validierung 0..1); M.O.D.-Zeilen ohne `{seconds}`/`{count}` plus `sponsor_window_open:boss_comeback`; L13-Wortprüfung im Test
erweitert um „schnell“, „nur noch“, „letzte Chance“.

**Tests (Minimum):** Ansage deterministisch je Seed/Etage, E1 nur Starter, keine Wiederholung zur Vor-Etage wo möglich; jede der
11 Bedingungen mit synthetischem Kontext (trifft/trifft nicht); höchstens 1 Treffer je Vorliebe und Kampf; 3 Treffer → Box,
Follower, Zähler, Trigger `show_bet`; Liga-Stufen 0/1/2 je Held:in und Ausrüstung, Multiplikatoren im Hype-/Follower-Produkt;
Achievement-Kette (alle 6 erreichbar, Bedingungen parsen); Replay mit Liga-Kämpfen = gleicher Hash; Overlay-Texte (keine Ziffern
mit Doppelpunkt im Badge, „~“-Minuten, „in Kürze“); Comeback-Fenster genau einmal; **Balance-Band** Kap. 4.10 per Simulation
(100 Seeds, Liga 1 und 2).

**DoD:** Gate 8.6; `fullrun --strategy=all` grün, zusätzlich `--liga=1` und `--liga=2` (Seeds 1–3) mit gemessenen Quoten in GDD §13;
GDD §7/§8/§11/§13, 05 Kap. 6.13 (Darstellung) + Kap. 12.2 (Nr. 17/18 geschlossen) nachgezogen; Screenshots Overlay mit Wetten-Zeile,
Liga-Badge, Sponsor-Badge neu.

### 8.5 Paket D — KI-Admin: Schnittstelle, Twists, Referenz-Dienst

**Ziel:** Kap. 5 Stufe S0: Provider-Schnittstelle (Standard skriptiert, Remote deaktiviert), Twist-Katalog + deterministischer
Applier mit 11 wirksamen Twists, Referenz-Dienst mit Tests und gemocktem Client. **Kein** Live-Betrieb, keine Schlüssel im Repo.

| Art | Dateien |
|---|---|
| Neu (Spiel) | `core/live/twist_applier.gd` (`TwistApplier`), Def `twist_def.gd` (Rumpf), `data/twists.json` (20), `core/show/mod_live_summary.gd` (`ModLiveSummary`, rein), `autoload/mod_voice/mod_voice_provider.gd` (`ModVoiceProvider`), `scripted_mod_voice.gd` (`ScriptedModVoice`), `remote_mod_voice.gd` (`RemoteModVoice`, `HTTPRequest`, standardmäßig aus), `mod_live_link.gd` (Node, kein `class_name`), `scenes/ui/twist_fx.gd` (Vignette/Konfetti, Kind von GlobalUi), `tests/fixtures/live/twist_cases.json`, `tests/fixtures/live/mock_mod_voice.gd`, `tests/test_06d_twists.gd`, `tests/test_06d_mod_voice.gd` |
| Neu (Dienst) | `services/mod-brain/` — `README.md`, `pyproject.toml`, `mod_brain/{app,brain,persona,schema,safety,catalog,rate_limit,config}.py`, `tests/{test_schema,test_safety,test_rate_limit,test_brain_mocked,test_catalog_sync}.py`, `.gitignore` (`.env`) |
| Geändert (eigen) | `data_validator.gd` (`_check_twists`), Rumpf `say_external` in `show.gd`, `run_sim.gd` (Twist-Ticks, Rattenregen über `STRAY_DUE`-Pfad, Zerfall-Pause), `shop.gd` (Preis-Hook-Rumpf), `scenes/ui/debug_overlay.gd` (F6 Test-Twist, F7 Test-Zeile), `scenes/ui/global_ui.gd` (`twist_fx`), `.github/workflows/ptd-check.yml` (Job `mod-brain-tests`: `pip install -e services/mod-brain[dev]` + `pytest`), Block D in `mod_lines.json` (`twist_applied_*`, `mod_live_*`) |

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

**Tests (Minimum):** Katalog validiert (20 Einträge, Grenzen, `slice`-Flags); `validate` je Ablehnungsgrund; gemeinsame Fälle
`twist_cases.json` (GDScript und pytest gleich); `apply`/`tick` je Slice-Twist (Wirkung, Dauer in Ticks, `once_per_floor`,
Schärfe-Budget); Aufzeichnung mit `cmd_id` 0 und **Replay-Gleichheit** inkl. Twists; manipulierter Twist im Log → Replay meldet
Abweichung; Pur-Liga lehnt spielrelevante Twists ab; fester Event-Fahrplan wirkt ohne Command identisch; `MockModVoice`: Zeilen
landen gefiltert im Dialog, zu lange/verbotene/veraltete Zeilen werden verworfen, Twist-Vorschlag läuft durch `apply_twist`;
`RemoteModVoice` ohne URL → `is_available() == false`, kein Netzwerkzugriff in Tests. Python: Schema (zu lange Zeile, falsche
Stimme, unbekannter Twist), Sicherheitsfilter (Politik-, Kauf-, Slur-Beispiele), Rate-Limit, gemockter Client prüft die Anfrageform
(Modell `claude-opus-5-5`, `output_config.effort == "low"`, JSON-Schema-Format, `cache_control` am letzten System-Block, System-Prompt
byte-identisch über zwei Runden, kein Spielername im Prompt), Refusal/Timeout/ungültiges JSON → leere Runde.

**DoD:** Gate 8.6; `pytest` im CI grün; `services/mod-brain/README.md` erklärt Start (`uvicorn mod_brain.app:app --port 8787`),
Konfiguration (`ANTHROPIC_API_KEY` aus dem Secret-Store, `MOD_BRAIN_MODEL`, `MOD_BRAIN_EFFORT`, `MOD_BRAIN_TOKEN_SECRET`), Kosten,
Sicherheitsregeln und die Verbindung aus dem Spiel (`--mod-live-url=http://127.0.0.1:8787`, nur Debug-Builds); **keine Secrets im
Repo**; 05 Kap. 6.2/10.5/11.1 und 02_TECH §3.4 (Command `twist`) nachgezogen.

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
| `01_GDD` | §2.1 (Held:in, Bellen), §4 (Talente), §7 (Liga-/Wetten-Hype), §8 (+6 Achievements), §11 (neue Tags), §12.1 (Re-Spec ersetzt „kein Wechsel“), §13 (Lootbox-Band 15–22, Liga-Quoten), §14.2 (Ablauf Neues Spiel) | A/B/C |
| `02_TECH` | §3.2 Signale, §3.4 Commands `hero/talent/casting/twist`, §4.2 Präfixe `tal_/spc_/mar_/tw_` (+ reservierte `gld_/job_/ssn_/raid_`), §4.3 Vokabulare, §4.4 Schemas, §4.5 Tabellen 17, §6.3 Trigger `show_bet` + StatIds; CR-16…CR-19 | 0/A–D |
| `03_ART` | Bellen-VFX, Mopsula als Spielerkörper, Liga-Optik (später), Spezies-Optik (später), Partyhut-Prop (später) | A (+ später) |
| `04_STRATEGIE` | Kap. 2.3 Distanz-Review +„Unterhosen-Liga“; Kap. 3 Roadmap-Ergänzungen (Kap. 7); Kap. 11 erledigte Entscheidungen | Integrator |
| `05_LIVE_MODUS` | Kap. 6.2 Twist-Katalog → `twists.json` dieses Dokuments; Kap. 6.13 Darstellung ohne Sekunden, Comeback-Fenster; Kap. 10.5 Schema; Kap. 11.1 `twists.json` jetzt im Slice; Kap. 12.2 Nr. 4/13/17/18 geschlossen | C/D |

---

## 9. Risiken & offene Punkte

| # | Risiko / Frage | Gegenmaßnahme / Vorschlag |
|---|---|---|
| R-1 | **Zu viele Systeme** überfordern Neue | Einführungsfahrplan 0.6, Ein-Satz-Regel L-1, Playtest-KPI „versteht das System ohne Erklärung“ ≥ 3 von 5 je neuem System |
| R-2 | Liga zu stark/zu schwach | Bänder Kap. 4.10 als Test; Multiplikatoren in Daten |
| R-3 | KI-Humor fade oder daneben | S0.5 Redaktion zuerst, S1-Gate mit Redaktionsbewertung, Not-Aus |
| R-4 | KI-Kosten pro Spieler:in | Kap. 5.11: Opt-in, Sendungs-Regie statt Einzel-Regie, Modellwahl je Route |
| R-5 | Nähe zu DCC (Unterhosen-Gag) | Kap. 0.3 Rahmung + Distanz-Review; Namensalternative bereit |
| R-6 | Twists stören Fairness in Wertungen | KI-Twists in gewerteten Läufen aus; Fahrplan für alle gleich; Pur-Liga ohne Twists |
| R-7 | Merge-Konflikte bei paralleler Arbeit | Schritt 0, Besitz-Tabelle 8.1, Anker-Blöcke in `mod_lines.json` |
| O-1 | Herr Brettschneider als 3. Figur oder neue Figur? | Vorschlag Brettschneider (Story-Rückbezug); Entscheidung mit Etage-2-Design |
| O-2 | Level-Cap-Plan je Etage | mit Etage 3 festlegen (Kap. 2.3) |
| O-3 | Fanclub-Namen | Vorschläge Kap. 2.4; Humor-Redaktion |
