# PRIME TIME DUNGEON — Staffeln: Sendeplan, Besetzung, Schläfer und Fertigkeiten

> **Grundlage:** Nutzeridee vom **2026-10-11**, Wortlaut:
> „die neue spezies und beruf ab ebene 3, nicht dem 3ten level. wie in der geschichte zu dungeon crawler carl halt. ebenso:
> können wir einbauen, dass zb jeweils ein spielzyklus gestartet wird, der maximal 18 ebenen zulässt und ca 2-3 monate
> dauert? so ein wenig, wie in dem Buch. die erste ebene dauert dann 2 Tage - die zweite 3 - die dritte 4 etc. Den zyklus
> kann man jederzeit starten sobald man eine mindestanzahl an crawlern hat. sonst werden diese an den Computer gegeben, der
> die restlichen crawler selbst simuliert und steuert. der crawler kann jederzeit ausloggen. Bleibt dann aber da als spieler
> stehen und ist der situation ausgeliefert, wo er ausgeloggt wird. d.h. im dungeon kommen dann monster und andere spieler
> ggfs vorbei. am besten daher im saferoom, wenn man erholung und sicherheit will. etc. macht sinn? wie würdest du das ganze
> umsetzen? Die skills sollten realistisch vergeben werden. Wie in den typischen Spielen, wie world of warcraft.“
>
> Die Details sind delegiert (Maßstab: gute UX, Spaß, Witz, Abwechslung, Wohlbefinden — ein **simples, sofort
> verständliches** Konzept). Die Rahmenentscheidungen des Orchestrators (der Nutzerin/dem Nutzer mitgeteilt) stehen in
> Kap. 0.3 (Zeilen mit **R**), die verbindlichen Entscheidungen nach dem Review in Kap. 0.4 (**V-1 … V-19**); alles Weitere
> sind Detailentscheidungen dieses Dokuments.
>
> **Abgestimmt auf** `00_BRIEF.md` (verbindlich), `01_GDD.md` (§2.7–2.9 Streuner, Treppe und Timer, §4 Party, §12
> Klassen/Spezies, §13 Bänder, §14 UX), `02_TECH.md` (§3.4 Commands, §4 Daten, §6.4 Spielstand, §7 Dungeon),
> `04_STRATEGIE_ROADMAP.md` (Kap. 1.4, 2.2/2.3 IP, 3 Roadmap, 6 Geld), `05_LIVE_MODUS.md` (Kap. 1–3, 4.3, 6.13, 10),
> `06_PROGRESSION_MAROTTEN_KI_ADMIN.md` (§0.5/0.6, §2.2–2.4, §3, §4, §5, §7), `07_ECHTZEITKAMPF.md` (§1, §2.6/2.7/2.10, §4,
> §5, §9.5/9.6, §10.8, §12) und `08_CASTING.md` (§1–§4, §7, §8, §10). Code-Stand: `claude/prime-time-dungeon` @ `dff0345`
> (06 A–D integriert; 07 R1a und 08 K0 als ein Vertrags-Durchgang gelandet, `SIM_VERSION` 2; Polish-/IP-Pass gelandet:
> Mopsulas Klassen heißen Erzmagister, Medicus honoris causa und Zeremonienmeister, `validators/ip_words.gd` sperrt
> Königsmotive für Mopsula sowie „Fan-Box“, „Feinripp“ und Fuß-Wörter in jedem Text; R1b ff. und K1 ff. offen).
>
> **Status:** verbindlicher Vertrag für die Staffel-Phasen **ST1–ST3** (Kap. 11). Die Einordnung in die Vorrangklausel des
> Briefs beantragt CR-25: `00_BRIEF` > `07` (alles Kampfrelevante) > **`09`** (Staffel, Sendeplan, Tod und Modi, Stufen,
> Talente, Berufe, Schläfer, KI-Besetzung) > `06` > `08` > `01_GDD` / `02_TECH` / `03_ART` / `05_LIVE_MODUS` > `04`.
> Wo dieses Dokument bestehende Regeln ersetzt, steht es als Änderungsantrag (CR-25 … CR-33, Kap. 11.7). Ein unabhängiges
> Review (2026-10-11) fand 19 Punkte; alle sind eingearbeitet (Kap. 0.4).
>
> **Stand ST0 (2026-10-12, Branch `ptd/st0`):** Der Vertrags-Durchgang ST0 ist umgesetzt (Kap. 11.2 „Stand ST0“, 02_TECH
> §0.8): Commands, Felder, Tabellen, Stubs und Haken stehen, alle hinter `state.season != null`; keine Staffel kann starten,
> jeder heutige Lauf bleibt bitgleich (kein `SIM_VERSION`-Sprung, Save v2 additiv). CR-25, CR-27, CR-29 und der Code-Teil
> von CR-33 sind eingearbeitet. Die ST1-Pakete schreiben ab jetzt nur ihre eigenen Dateien und Abschnitte (Kap. 11.4).
>
> **Namen der Phasen:** Der Orchestrator nennt sie S1–S3. Weil „S0–S5“ schon die SHOWRUN-Stufen (05) und „S0–S3“ die
> KI-Stufen (06 §5.12) sind, heißen sie hier **ST1–ST3** (Staffel-Phasen) — gleicher Inhalt, keine Verwechslung.
>
> **Konventionen:** Prosa Deutsch; IDs, Pfade (relativ zu `prime-time-dungeon/game/` = `res://`), JSON-Keys, Signal- und
> Methodennamen Englisch. **[zu prüfen]** = reale Fakten (Recht, Preise, Plattformregeln), **[Schätzung]** = Planwert,
> **[zu messen]** = Zielwert, den ein Gate misst. Alle Zahlen sind Startwerte für Simulation und Playtests.

---

## Inhalt

0. Kurzfassung (Spieler:innen-Sätze, Entscheidungen S-1 …, Entscheidungen nach Review V-1 …, Ein-Satz-Erklärungen,
   Einführungsfahrplan)
1. Begriffe (Glossar, Sprachregel, Text-Prüfung)
2. Staffel-Ablauf (Arten, Formate, Tempo, Start, Sendeplan, Einsturz, Treppenregel, Ende, Titel, was bleibt, Pausen)
3. Etagen 1–18 (Tabelle, Bausteine, Pensum und Tagesprogramm, Skalierung, Aufwand, Generator)
4. KI-Kandidat:innen (Populationsmodell, Verkörperung, Profile, Fairness, M.O.D.)
5. Schläfer und Ausloggen (Regeln, Ausgeruht, Begegnungen, Login-Bilanz, Aufzeichnung)
6. Andere Spieler:innen (Erlaubtes, kein PvP gegen Schläfer, Arenen, Schutz, Chat)
7. Tod und Modi (Mit Netz, Ohne Netz, Generalprobe, Strafen, Vorabendprogramm)
8. Fertigkeiten wie in WoW (Stufen, Aufholen, Fähigkeitenbuch, Talentbaum, Berufe, Vorleben, Migration)
9. Technik (ST1 offline mit Journal und Versionen, ST2 Staffel-Server, ST3 Echtzeit, Anti-Cheat, Datenschutz, Kosten)
10. Live-Modus, Show und Geld im Staffel-Kontext
11. Umsetzung (Reihenfolge, ST0–ST3, Dateieigentum, Tests, Änderungsanträge, Aufwand, Risiken)
12. Offene Fragen mit Empfehlung

---

## 0. Kurzfassung

### 0.1 Für Spieler:innen in fünf Sätzen

1. Eine **Staffel** ist eine Fernsehstaffel mit **6, 12 oder 18 Etagen** (je nachdem, welche Inhalte Sie besitzen): Jede
   Etage hat einen festen Einsturztermin — die erste nach 2 Tagen, die zweite nach 3, die dritte nach 4, danach je 5 Tage.
2. Die ersten drei Etagen sind sofort offen, ab Etage 4 dürfen Sie **eine Etage vorauslaufen**; wer beim Einsturz noch oben
   steht, wird von der Regie gerettet (Gebühr höchstens einmal pro Woche) — oder ist in einer Staffel **„Ohne Netz“** ab
   Etage 2 raus und schaut als Studiogast zu.
3. Sie können **jederzeit ausloggen**: Im Safe Room schlafen Sie sicher und werden **ausgeruht** (doppelte Kampf-EP beim
   nächsten Spielen); im Gang kommen vielleicht Monster oder andere Kandidat:innen vorbei, und Ihre Figur handelt mit der
   Taktik, die Sie beim Ausloggen wählen.
4. **Auf Etage 3** wählen Sie Spezies und Klasse; Fähigkeiten kommen auf festen **Stufen**, Talente wählen Sie in einem
   **Talentbaum**, und **Berufe** steigen durch Benutzen — Ihr Vorleben aus dem Casting bringt einen Vorsprung mit.
5. Freie Plätze der **100 Kandidat:innen** spielt der Computer: Sie treffen KI-Kandidat:innen, die helfen, handeln,
   drängeln und Schlagzeilen machen — und keine Kandidat:in greift eine schlafende Figur an.

**Was gegenüber der Idee anders ist (und warum), in einem Absatz:** Mit „2, 3, 4 … Tage“ bis Etage 18 wären es 2 + 3 + … + 19
= **189 Tage (≈ 6 Monate)** — doppelt so lang wie die gewünschten 2–3 Monate. Deshalb wächst die Dauer bis 5 Tage und bleibt
dann: 2 + 3 + 4 + 15 × 5 = **84 Tage = 12 Wochen** für das größte Format. Was die Idee „Beruf ab Ebene 3“ nennt, heißt im Spiel
**Klasse**; das Wort **Beruf** bekommen die WoW-artigen Handwerke, und der echte Job aus dem Casting heißt **Vorleben**
(Kap. 1). Zwei Abmilderungen: Etage 1 ist eine **Generalprobe** ohne Verluste, und Kandidat:innen greifen Schläfer nicht an —
„ausgeliefert“ ist man Monstern und dem Pech der anderen; ein härteres Regelwerk bleibt wählbar (F-6).

### 0.2 Antwort auf die Frage „macht Sinn?“

Ja. Die Idee passt genau zur Prämisse (Show mit Etagen-Countdown) und macht aus dem Einzelspieler-Lauf ein Format, das man
über Wochen begleitet — wie eine Serie. Damit es einfach bleibt, gilt überall dieselbe Handvoll Regeln: **ein Sendeplan,
eine Treppenregel, eine Einsturzregel, eine Schlafregel, eine Todesregel**. Alles andere (Talente, Berufe, KI-Besetzung)
hängt daran, ohne neue Ausnahmen zu brauchen.

### 0.3 Entscheidungen

Herkunft: **R** = Rahmen des Orchestrators (verbindlich vorgegeben), **D** = Detailentscheidung dieses Dokuments, **V-n** =
durch die Entscheidung n nach dem Review geändert (Kap. 0.4).

| Nr. | Thema | Entscheidung | Herkunft | Kap. |
|---|---|---|---|---|
| S-1 | Begriffe | **Vorleben** = echter Job aus dem Casting (08) → Vorsprung in einem Beruf; **Klasse** = Wahl auf Etage 3 zusammen mit der Spezies → Kampffähigkeiten; **Berufe** = Handwerke wie in WoW (2 Hauptberufe + Kochen und Erste Hilfe), Wert steigt durch Benutzen. In UI und Texten heißt die Etage immer **Etage** und die Figurenstufe immer **Stufe** — nie „Level“, „Lv“ oder „Ebene“; „Stufe“ gibt es nur für Figuren und Gegner, Material hat eine **Güte**. | R · V-6 | 1 |
| S-2 | Staffel | Ein Zyklus = **eine Staffel** im Format **6, 12 oder 18 Etagen**; Dauer 2/3/4 Tage, danach je 5 Tage → **24, 54 oder 84 Tage**. Jede Etage hat einen festen Einsturztermin; wer fertig ist, darf früher absteigen. | R · V-14 | 2.1, 2.4 |
| S-3 | Treppenregel | Etagen 1–3 sind vom Start an offen; **ab Etage 4 höchstens eine Etage Vorlauf**: Die Treppe führt nur auf die Etage direkt unter der Etage, die gerade „auf Sendung“ ist. Am Stück gibt es keine Grenze. | D · V-2, V-6 | 2.6 |
| S-4 | Einsturz | **Mit Netz** (Normal): die Regie rettet — Rettungsgebühr (−30 % Credits, −10 % Follower), aber **höchstens eine Gebühr je 7 Tage** (Rettung oder Sanitäter) und für Schläfer im Safe Room gar keine; keine Etagen-Bilanz, weiße Weste weg. **Ohne Netz** (Hardcore, ein Leben wie im Buch): raus → Studiogast. **Etage 1 ist die Generalprobe:** dort kostet nichts die Weste oder das Leben. | R · V-7, V-9 | 2.5, 7 |
| S-5 | Tod | Mit Netz: Wiederbelebung im zuletzt besuchten Safe Room der Etage (sonst am Etageneingang), −10 % Credits (zählt zur Wochen-Gebühr), weiße Weste weg. Ohne Netz: endgültig (ab Etage 2). | R · V-7, V-16 | 7 |
| S-6 | Besetzung | **100 Plätze** je Staffel (einstellbar 20–100). Start jederzeit, sobald die Mindestzahl Menschen da ist (privat 1, Freunde 2, öffentlich 10); freie Plätze spielt die **KI** (abstraktes Populationsmodell, in der Nähe der Spieler:in als NPC mit der 07-KI). Viele Staffeln laufen parallel; je Konto gleichzeitig höchstens **eine öffentliche und eine Freunde-Staffel**. | R · V-18 | 2.2, 4 |
| S-7 | Ausloggen | Überall außerhalb des Kampfes; die Figur bleibt als **Schläfer**. Safe Room = sicher + **Ausgeruht**; im Gang bis zu 3 **Begegnungen** (Streifen oder KI-Kandidat:innen), die Figur handelt mit der Taktik aus dem Ausloggen-Dialog; Ergebnis beim nächsten Login („Während Sie schliefen …“), deterministisch und aufgezeichnet. | R · V-10 | 5 |
| S-8 | Andere Spieler:innen | sehen, bewachen, heilen, wecken, handeln mit Schläfern — **nie angreifen**; PvP nur als Opt-in in **Show-Arenen**; ein späteres Opt-in-Regelwerk „Kopfgeld“ bleibt möglich (F-6). | R | 6 |
| S-9 | Fertigkeiten wie WoW | Fähigkeiten auf **festen Stufen** mit Vorschau „ab Stufe X“, kein Zufall; **Talentbaum** mit Reihen (je Reihe 1 aus 3), je Klasse mit zwei **Spezialisierungen**; die Talent-Show bleibt als TV-Präsentation; **Berufe** 1–300 mit Farben orange/gelb/grün/grau, Ausbildung im Safe Room, Rezepte. | R | 8 |
| S-10 | Vorleben | Das Vorleben bringt **+50 in einem Beruf** (Kanon-Kai und Status-Kacheln wählen ihn beim ersten Gewerke-Büro frei), das Hobby schenkt ein **Hobby-Rezept**; das **ersetzt die Starttalente aus 08** (CR-33). Privatsphäre, Persona-Command und Erzählstrang aus 08 bleiben. | R · V-19 | 8.6 |
| S-11 | Phasen | **ST1** Offline-Staffel-Prototyp (ohne Server) → **ST2** Online-Staffeln asynchron → **ST3** Echtzeit-Präsenz. Der Echtzeitkampf (07 R1b–R5b) kommt zuerst; reine ST1-Module ab 07 R3, der Einbau mit R5b. | R · V-4 | 11 |
| S-12 | IP | Jede Mechanik (Etagen, Einsturz, Mitkandidat:innen, Spezies/Klasse auf Etage 3) ist frei, **die Summe ist nah am Buch (Nähe „hoch“)**: Namen, Begriffe, Figuren, Texte bleiben eigen, das Anwalts-Memo prüft die Staffel-Struktur vor jeder öffentlichen Erwähnung, Marketing wirbt nicht mit „18 Etagen“. Im Spiel heißen Teilnehmende **Kandidat:innen**, nie „Crawler“. | R · V-15 | 1.2, 11.7 |
| S-13 | Tempo | **Kalender** (Standard; 1 Staffel-Tag = 24 h) oder **Am Stück** (nur privat: jede Etage hat einen eigenen Countdown, der beim Betreten startet — 20/30/40, dann je 50 min Erkundungszeit; keine Vorlauf-Grenze, die Besetzung folgt Ihnen). In der ersten Staffel bietet M.O.D. „Am Stück“ nach der Klassenwahl an. Zeitraffer nur in Debug-Builds. | D · V-2, V-6 | 2.1 |
| S-14 | Kampagne | Die bisherige Kampagne **wird zur privaten Staffel**. Jede Regel dieses Dokuments gilt nur mit `state.season != null`; SHOWRUN-Event-Läufe (05) bleiben ein eigener Modus ohne Staffel **mit ihren bisherigen Regeln** (Countdown, Game Over); den Talentbaum nutzen sie wie Staffeln (V-20: ein Talentsystem für alles). | D · V-4 | 2.1, 9.1 |
| S-15 | Speichern | **Dauerspeicherstand mit Command-Journal** je Platz; es gibt kein Zurückladen. Grundsatz **„Wer geht, wird zur KI“**: Ausloggen, Absturz, beendete App — ein offener Kampf wird beim nächsten Start vom Kampfanfang an per Autopilot entschieden, danach schläft die Figur. | D · V-3 | 5.1, 9.1 |
| S-16 | Stufen | **Höchststufe 50** (erreicht auf Etage 16), je Etage ein **Stufen-Band** mit **Deckel**; darunter **Aufholjagd** (EP × 2, ein ganzes Band darunter × 3); bei Rettung und Login hebt der **Regie-Crashkurs** auf Bandanfang − 2. Ausgeruht zählt nicht zusätzlich. | D · V-8 | 8.2 |
| S-17 | Fähigkeiten | **Fähigkeitenbuch**; die Leiste bleibt 4 + SHOW + Trank (07). Klassenfähigkeiten sind Varianten der Leistenplätze: beim Recall, dann auf Stufe 12/17/22/27/32, Rang II–IV auf 37/42/47. Merkregel ab Stufe 12: **Endet die Stufe auf 2 oder 7, gibt es eine Fähigkeit (ab 37 einen Rang); endet sie auf 0 oder 5, eine Talentreihe.** | D | 8.3 |
| S-18 | Talente | Reihen auf Stufe 3/5/7/9 (**Grundreihen** aus den heutigen 24 Talenten), 15/25/35/45 (**Klassenreihen**), 20/30/40/50 (**Figurenreihen**); je Reihe 1 aus 3, im Safe Room jederzeit kostenlos umwählbar. Ersetzt das Zufallsangebot „1 aus 2“ (06 §2.2) überall, auch in Event-Läufen (V-20). | D | 8.4 |
| S-19 | Berufe | Hauptberufe (höchstens 2): **Schrottsammeln, Pilzkunde, Ausschlachten** (Sammeln) und **Requisite, Labor, Kostüm** (Handwerk); Nebenberufe für alle: **Kochen, Erste Hilfe**. Ab Etage 2, IDs `prf_*`. Nur die Kandidat:in hat Berufe („Der Graf lässt arbeiten“). | D · V-16 | 8.5 |
| S-20 | Was bleibt | Über Staffeln bleiben nur **Titel, Kosmetik, Ruhmeshalle, Konto-Erfolge** und die Freischaltung „Ohne Netz“ — nie Kampfkraft, Stufe, Ausrüstung, Credits oder Berufswerte. | D | 2.8 |
| S-21 | Etagen 4–18 | Fünf **Kulissen** × drei Etagen, prozedural; je Etage ein **wiederkehrender Revier-Boss** (Treppenschlüssel, eskaliert über die drei Etagen), je Kulisse ein großer **Etagenboss** auf ihrer letzten Etage, je Etage ein optionaler Show-Boss und ein **Tagesprogramm** (je Staffel-Tag ein neuer Programmpunkt). | D · V-5 | 3 |
| S-22 | Einstieg | Die erste Staffel startet mit **einem Knopf „Sendung starten“** (privat, Mit Netz, Standardwerte). Neue Kandidat:innen steigen nur vor dem Start ein; in Freunde-Staffeln dürfen Eingeladene in den ersten 48 h einen KI-Platz übernehmen (auch den Platz einer ausgestiegenen Person). **Aussteigen** gibt den Platz an die KI („übernommen“). | D · V-6, V-18 | 2.2 |
| S-23 | Versionen | Regel- und Datenänderungen kommen nur zu festen **Sendeterminen**; öffentliche Staffeln starten in Wellen danach und enden vor dem nächsten; dazwischen nur **hash-neutrale** Patches (die CI spielt die Logs jeder Live-Version nach). Rückfall: Datenstand je Staffel und archivierte Verifier. | D · V-1 | 9.1 |
| S-24 | Geld | Das **Format kommt aus dem Kauf**: Grundspiel 6 Etagen, Akt 2 bis 12, Akt 3 bis 18; Staffeln werden je Format zusammengestellt, nie gemischt. **In einer Staffel ist für Kandidat:innen nichts käuflich.** Staffeln sind standardmäßig ohne Zuschauer-Geschenke; Opt-in-Show-Staffeln folgen den Sponsor-Fenster-Regeln aus 05/06 (Geld nur an den Betreiber). | R/D · V-14 | 10 |

### 0.4 Entscheidungen nach Review (2026-10-11)

Ein unabhängiges Review fand 19 Punkte (2 blockierend, 13 schwer, 4 leicht). Der Orchestrator hat sie entschieden
(verbindlich, Details delegiert; Maßstab UX, Spaß, Witz, ein einfaches Konzept, Wohlbefinden).

| Nr. | Befund | Entscheidung | Kap. |
|---|---|---|---|
| V-1 | 05 §4.3 verlangt gleiche `sim_version`/`data_hash`; Staffeln sollten trotzdem auf ihrer Version zu Ende laufen | Regel- und Datenänderungen nur zu **Sendeterminen**; öffentliche Staffeln starten in Wellen danach; Patches mitten in einer Staffel nur hash-neutral (CI spielt die Logs jeder Live-Version nach); Datenstand je Staffel und archivierte Verifier nur als Rückfall; CR-30 | 9.1, 11.7 |
| V-2 | „Am Stück“ mit globaler Uhr und Treppenregel hieß: Wer schnell ist, wartet, indem er herumläuft | Countdown **je Etage ab Betreten** (wie heute), keine Vorlauf-Grenze, die Besetzung folgt der Spieler:in, keine Gnadenfrist beim Fortsetzen; Etage 1 behält ihre Streuner; GDD §13 neu messen | 2.1, 4.2, 9.1 |
| V-3 | „Dauerspeicherstand“ ohne Journal: Ein Absturz verlor alles seit dem letzten Speichern | **Command-Journal** je Platz (append-only, „Begegnung gestartet“ zuerst geschrieben); ein offener Kampf wird beim Neustart vom Anfang an per Autopilot entschieden; Test „App im Kampf beendet“ | 5.1, 9.1, 11.6 |
| V-4 | Neue Regeln hätten R4-Messungen und alte Hashes verschoben | Jede Regel hängt an `state.season != null`; `SIM_VERSION` steigt, wenn die Staffel Standard wird; ST0 geht mit 07 R5b (Save v2); ST1-D nach R4 (oder R4 misst mit dem Baum); CR-32 (a)–(c) nur Schema-Haken; Event-Läufe behalten ihre Regeln | 9.1, 11.1, 11.2 |
| V-5 | Ein Kalendertag bot zu wenig Neues; 04 §3.5 („1 Etage / 8–10 Wochen“) wurde still zu „1 Kulisse“ | **Tagesprogramm** (je Staffel-Tag ein Programmpunkt, bleibt bis zum Einsturz); Aufwand je Etage ehrlich; ST1-Gate nur Mechanik plus Echtzeit-Tagebuchstudie (6 Etagen, 24 Tage, ≥ 10 Personen); CR-29 | 3.3, 3.5, 11.6 |
| V-6 | Zu viele Entscheidungen und Begriffe am Anfang | Erste Staffel = ein Knopf **„Sendung starten“**; Tempo erst nach der Klassenwahl; eine neue Regel je Etage; Etagen 1–3 ohne Vorlauf-Grenze (Klassenwahl am ersten Abend); Gegnerfarbe plus Stufendifferenz als Zahl; „Güte“ statt „Material-Stufe“ | 0.6, 2.2, 2.6, 3.4, 8.5 |
| V-7 | Der Hausmeister (≈ 20 % Niederlage beim ersten Versuch) kostete am ersten Abend Weste oder Staffel | Etage 1 = **Generalprobe** (keine Weste verloren, niemand scheidet aus); „Ohne Netz“ erst nach der ersten Klassenwahl oder einer beendeten Staffel; Studiogäste und Finalist:innen dürfen sofort neu einsteigen | 2.2, 7 |
| V-8 | Abwesenheit: Gebühren summierten sich, Rückkehr zehn Stufen unter den Gegnern | **Regie-Crashkurs** bei Rettung und Login auf Bandanfang − 2 mit **Aufholpaket**; Aufholjagd × 3 ab einem ganzen Band Rückstand; Harness-Profile „20 min/Tag“, „2 Wochen weg“, „nur Wochenende“ mit Bändern | 8.2, 11.6 |
| V-9 | Wohlbefinden | Schläfer im Safe Room werden gratis getragen; höchstens eine Gebühr je Woche (Rettung oder Sanitäter); Tägliches sammelt sich 4 Tage; Schläfer-Meldungen nur als eine Tageszusammenfassung, standardmäßig aus; **Sendepause** bis 14 Tage (privat); `.ics`-Export; Kap. 10 Nr. 7 ehrlich | 2.4, 2.5, 2.9, 10 |
| V-10 | In ST1 kamen beim Schlafen keine „anderen Spieler“ vorbei | Der `SleepResolver` würfelt auch **KI-Begegnungen** (Wache, vorbeigezogene Streife, Zettel, Angebot); die Schlaf-Taktik wählt der Ausloggen-Dialog; getestete Todesraten je Gefahr; F-6 bleibt offen | 5.1, 5.3, 12 |
| V-11 | Ranglisten-Titel in Staffeln voller KI | Ranglisten-Titel nur in **geprüften öffentlichen Staffeln mit ≥ 10 Menschen**; privat und unter Freund:innen nur Abschluss-Titel mit Zusatz „privat“; private Ranglisten zählen alle 100 Plätze | 2.7, 4.5 |
| V-12 | ST2 hatte zwei Schreiber (Client und Server) | **Ein Schreiber:** der Server hält den kanonischen Zustand, indem er gestreamte Command-Pakete nachrechnet; Resync nach 05 §3.6; Besetzung und Ereignisse als aufgezeichnete externe Eingänge; 120 s Gnadenfrist (ein Tunnel ist kein Ausloggen) | 9.2 |
| V-13 | ST3-Shards liefen rund um die Uhr; Kosten mit vollen Shards gerechnet | Ein Shard läuft nur, solange ein Mensch auf der Etage ist; alles andere abstrakt wie in ST2; KI nur nahe Menschen verkörpert; Kosten mit der Gleichzeitigkeit je Staffel neu geschätzt | 9.3, 9.6 |
| V-14 | Bezahlte Etagen (04 §6.1) gegen „nichts käuflich“ | **Format nach Kauf**, nie gemischt: Basis 6 Etagen (≈ 3,5 Wochen), Akt 2 12, Akt 3 18 Etagen (12 Wochen); in der Staffel nichts käuflich; ohne Geschenke außer in Opt-in-Show-Staffeln; S-24 neu, CR-29 | 2.1, 10, 11.7 |
| V-15 | IP-Nähe „mittel“ war zu freundlich | Nähe **„hoch“**; Anwalts-Memo (04 §2.3) deckt die Staffel-Struktur vor jeder Erwähnung; kein Marketing mit „18 Etagen“ (18 bleibt größtes Format, weil die Idee es nennt); Klassennamen vom Polish-Pass; Ast „Primadonna“ → „Protokoll“; „Mit Netz/Ohne Netz“ bleiben | 8.4, 11.7, 11.8 |
| V-16 | Fehlende CRs und Fakten | CRs an 07 §2.6, 05 §4.3, GDD §2.7/§13/§12.2, 02_TECH §4.4.4; „Gleiche Karte wie letzte Staffel?“ gestrichen (08 C-2); `learnset` in `classes.json` ist leer (Skill-IDs nur Doku-Beispiele); Berufs-IDs `prf_*` statt `job_*`; Tod ohne besuchten Safe Room → Etageneingang | 2.8, 7.1, 8.3, 8.5, 11.7 |
| V-17 | Zeitmodell | Alle Einsturztermine beim Start als **UTC-Zeitpunkte** (Sendezeit in Ortszeit des Starts; Zeitumstellung dokumentiert); Uhrsprünge über 7 Tage mit Rückfrage gekappt; **Tag 0 = nächste Sendezeit**; 2 min Frist nach einem Kampf über den Einsturz hinaus | 2.4, 2.5, 5.5 |
| V-18 | Aussteigen und Konto-Grenzen | **Aussteigen** gibt den Platz an die KI („übernommen“); je Konto eine öffentliche und eine Freunde-Staffel; die 48-h-Übernahme (F-10) gilt auch für Plätze Ausgestiegener | 2.2 |
| V-19 | Vorsprung 75 füllte das Praktikum, nichts blieb zum Steigern | **+50 in einem Beruf** (Zuordnung; Kanon-Kai und Status-Kacheln wählen frei beim ersten Gewerke-Büro); das Hobby schenkt ein Rezept statt Punkten; bis 75 bleibt Platz | 8.6 |
| V-20 | Zwei Talentsysteme (Baum in Staffeln, „1 aus 2“ in Event-Läufen) hätten doppelten Code und doppelte Balance bedeutet (Orchestrator, 2026-10-11) | **Ein Talentsystem für alles:** der Talentbaum gilt in Staffeln **und** in Event-Läufen; Event-Läufe binden ihn wie alle Regeln über `rules_hash`/Version (es gibt noch keine veröffentlichten Event-Läufe, also nichts zu bewahren). Die 06-B-Zufallswahl entfällt mit ST1-D | 8.4, 9.1, CR-31 |

### 0.5 Ein-Satz-Erklärungen (UX-Vertrag, 06 L-1)

| System | Ein Satz (so sagt es M.O.D. beim ersten Mal, sinngemäß) | Erstes Auftreten |
|---|---|---|
| Staffel | „Willkommen in Staffel 37! Jede Etage stürzt pünktlich ein. Pünktlicher als jeder Zug.“ | Intro |
| Generalprobe | „Etage 1 ist die Generalprobe. Hier dürfen Sie noch scheitern. Ab Etage 2 läuft die Kamera wirklich.“ | Intro |
| Einsturz | „Diese Etage stürzt in zwei Tagen ein. Seien Sie dann woanders. Am besten tiefer.“ | Etage 1, Tutorial-Ende |
| Tagesprogramm | „Neu im Programm: Auf dieser Etage gibt es heute etwas Neues. Es bleibt bis zum Einsturz.“ | Etage 1, erster neuer Programmpunkt |
| Weiße Weste | „Noch nie gerettet, noch nie gestorben: weiße Weste. Davon gibt es nicht mehr viele.“ | Etage 2, Zähler |
| Berufe | „Das Gewerke-Büro sucht Leute. Zwei Hauptberufe, dazu Kochen und Erste Hilfe für alle.“ | Etage 2, 1. Safe Room |
| Vorleben-Vorsprung | „Ihr Vorleben zählt: Was Sie draußen konnten, können Sie hier ein bisschen schon.“ | Etage 2, Gewerke-Büro |
| Recall | „Recall! Wer wollen Sie sein? Und was wollen Sie können?“ (06 §0.5, 08 C-16) | Etage 3, Safe Room |
| Tempo | „Sie sind schnell. Weiter wie im Fernsehen — oder am Stück, ganz ohne Warten?“ | nach der Klassenwahl (privat) |
| Vorlauf | „Fertig? Eine Etage dürfen Sie vorgehen. Weiter baut die Regie noch nicht.“ | Treppe nach Etage 4, solange sie gesperrt ist |
| Rettung | „Gerettet! Die Rechnung kommt mit der Post. Eigentlich sofort.“ | erster Einsturz (Mit Netz) |
| Ohne Netz | „Ein Leben. Keine Rettung. Das Publikum liebt das. Sie hoffentlich auch.“ | Freischaltung nach der ersten Klassenwahl |
| Ausloggen / Schläfer | „Sie gehen? Ihre Figur bleibt. Im Safe Room schläft sie sicher — im Gang eher nicht.“ | erstes Ausloggen |
| Ausgeruht | „Ausgeruht! Die nächsten Kämpfe bringen doppelte Erfahrung. Schönheitsschlaf zahlt sich aus.“ | erster Login nach Safe-Room-Schlaf |
| Aufholjagd | „Sie hängen hinterher. Bis Sie aufgeholt haben, zählt jede Erfahrung doppelt.“ | erstmals unter dem Band |
| Regie-Crashkurs | „Regie-Crashkurs! Wir haben Sie über Nacht nachgeschult. Das Aufholpaket liegt bei.“ | erste Rückkehr weit unter dem Band |
| Talentbaum | „Talent-Show! Eine neue Reihe, drei Talente, eins nehmen Sie. Umentscheiden dürfen Sie im Safe Room.“ | Stufe 3 (Etage 1) |
| Fähigkeitenbuch | „Neue Fähigkeit! Legen Sie sie im Fähigkeitenbuch auf die Leiste.“ | erste neue Fähigkeit |
| KI-Kandidat:innen | „Sie sind nicht allein. Die anderen Kandidat:innen auch nicht. Einige sind sogar nett.“ | Etage 1, erste Eilmeldung |

### 0.6 Einführungsfahrplan (eine neue Regel je Etage, 06 L-2)

| Etage | Neue Regel (genau eine) | Nur zum Entdecken (keine Regel, keine Tutorial-Zeile) |
|---|---|---|
| 1 | keine — Generalprobe; der Einsturztermin ist der bisherige Countdown im Staffel-Takt, die Talent-Show bleibt die von heute (drei Karten statt zwei) | Tagesprogramm, Eilmeldungen der KI-Kandidat:innen; Ausloggen erklärt sich beim ersten Ausloggen |
| 2 | **Weiße Weste** (Zähler im HUD) | Gewerke-Büro mit Berufen und Vorleben-Vorsprung |
| 3 | **Recall:** Spezies und Klasse (06 §3) | danach das Tempo-Angebot (privat) |
| 4 | **Vorlauf:** höchstens eine Etage voraus (die erste gesperrte Treppe ist die nach Etage 4) | Klassenreihen im Talentbaum (ab Stufe 15) |

06 §0.6 bleibt sonst gültig (Vorlieben, Regie-Twists); Fanclubs rücken nach CR-31 hinter Etage 4.

### 0.7 Bewusst nicht drin

Auktionshaus; Angeln und weitere Nebenberufe; Haltbarkeit und Reparatur; Talentpunkte zum Verteilen (es gibt nur Reihen);
Ränge einzelner Fähigkeiten (nur drei Ränge je Klasse); Doppelklasse; Späteinstieg in laufende öffentliche Staffeln; mehr
als eine öffentliche und eine Freunde-Staffel je Konto; gemischte Formate in einer Staffel; „Gleiche Karte wie letzte
Staffel?“ (08 C-2: jedes neue Spiel beginnt leer); PvP in der Welt; Angriffe von Kandidat:innen auf Schläfer; käufliche
Rettungen, EP oder Leben; Fanclubs vor Etage 4 (CR-31); Gäste der KI im Bosskampf; frei laufende KI-Kandidat:innen vor ST3;
Werbung mit „18 Etagen“.

---

## 1. Begriffe

### 1.1 Glossar

| Begriff (UI) | Bedeutung | Nutzerwort | Code / ID |
|---|---|---|---|
| **Staffel** | Ein Spielzyklus: 6, 12 oder 18 Etagen, fester Sendeplan, eine Besetzung. „Staffel 37“ = laufende Nummer der Instanz. | Spielzyklus | `ssn_` (Vorlage), `SeasonState` |
| **Folge** | TV-Wort für eine Etage der Staffel („Staffel 37 · Folge 5“), nur auf der Kandidatenkarte (08 §1.4) und in M.O.D.-Ansagen. | — | — |
| **Sendeplan** | Tabelle der Einsturztermine aller Etagen (Kap. 2.4), als `.ics` exportierbar. | — | `SeasonClock` |
| **Etage** | Ein Stockwerk des Dungeons (1–18). Immer „Etage“. | Ebene | `floor_index` |
| **Generalprobe** | Etage 1: Tod und Einsturz kosten dort weder Weste noch Leben (Kap. 7.3). | — | — |
| **Auf Sendung** | Die Etage, deren Einsturz als nächster kommt. | — | `on_air_floor` |
| **Vorlauf** | Ab Etage 4 die Etage direkt unter der Etage auf Sendung; sie ist schon offen (Kap. 2.6). | — | `open_floor_max` |
| **Einsturz** | Das Ende einer Etage zu ihrem Termin. Wer dann noch dort ist, wird gerettet (Mit Netz) oder ist raus (Ohne Netz). | — | `collapse` |
| **Rettung** | Regie holt eine Figur beim Einsturz auf die nächste Etage — Gebühr höchstens einmal je 7 Tage, Schläfer im Safe Room gratis (Kap. 2.5). | — | `rescue` |
| **Tagesprogramm** | Je Staffel-Tag ein neuer Programmpunkt auf jeder offenen Etage, bleibt bis zum Einsturz (Kap. 3.3). | — | `daily` |
| **Stufe** | Erfahrungsstufe einer Figur oder eines Gegners (1–50). Immer „Stufe“ — und für nichts anderes. | Level | `level` |
| **Stufen-Band / Deckel** | Stufen, für die eine Etage gebaut ist; der Deckel ist das Bandende (Kap. 8.2). | — | `LevelBand` |
| **Aufholjagd** | EP × 2 unter dem Band der Etage, × 3 ab einem ganzen Band darunter. | — | `catch_up` |
| **Regie-Crashkurs** | Hebt bei Rettung und Login auf Bandanfang − 2, dazu ein Aufholpaket (Kap. 8.2). | — | `crash_course` |
| **Ausgeruht** | Vorrat aus Safe-Room-Schlaf; verdoppelt Kampf-EP, bis er verbraucht ist. | Erholung | `rested` |
| **Sendepause** | Private Staffel anhalten, bis 14 Tage (Kap. 2.9). | — | `season` `op: "pause"` |
| **Vorleben** | Der echte Job aus dem Casting (08 Bildschirm 2/3, bisher „Beruf“). Bringt einen Berufs-Vorsprung. | Beruf (im Casting) | `org_*`, `occ_*` |
| **Spezies** | Wer man ab Etage 3 ist (06 §3.2). | Spezies | `spc_*` |
| **Klasse** | Was man ab Etage 3 kann: Rolle und Kampffähigkeiten (06 §3.3 nannte sie „Spezialisierung“). | Beruf ab Ebene 3 | `cls_*` |
| **Spezialisierung** | Einer der zwei Äste im Talentbaum einer Klasse (z. B. „Bollwerk“ und „Abrissunternehmen“). | — | `spec` an Talenten |
| **Recall** | Die Runde auf Etage 3, in der Spezies und Klasse gewählt werden (08 C-16). | — | Command `casting` |
| **Fähigkeit** | Etwas für die Kampfleiste (07 §4). | Skill | `skl_*` |
| **Talent / Talentreihe** | Passiver Bonus; je Reihe wählt man eines von drei (Kap. 8.4). | Skill | `tal_*` |
| **Beruf** | Handwerk wie in WoW: Haupt- oder Nebenberuf, Wert 1–300 (Kap. 8.5). | — | `prf_*` |
| **Güte** | Qualität von Material und Rezepten, 1–6, eine je Kulisse (Kap. 8.5). | — | `grade` |
| **Kandidat:in** | Jede:r Teilnehmende der Staffel, Mensch oder KI. | Crawler | `cast` |
| **Besetzung** | Alle Kandidat:innen einer Staffel (100 Plätze). | — | `CastSim` |
| **Schläfer** | Eine ausgeloggte Figur, die in der Welt bleibt. | — | `sleeper` |
| **Aussteigen** | Eine Online-Staffel verlassen; die KI übernimmt den Platz („übernommen“, Kap. 2.2). | — | `season` `op: "leave"` |
| **Weiße Weste** | Nie gerettet und nie gestorben (nur Mit Netz). | — | `vest` |
| **Mit Netz / Ohne Netz** | Staffelart Normal / Hardcore. | Normal / Hardcore | `mode`: `normal` / `hardcore` |
| **Studiogast** | Wer in „Ohne Netz“ ausgeschieden ist: schaut zu, kommentiert mit Schnellsätzen. | — | `spectator` |
| **Kalender / Am Stück** | Tempo: Kalender-Uhr für alle oder Countdown je Etage (Kap. 2.1). | — | `tempo`: `calendar` / `binge` |
| **Kulisse** | Thema einer oder dreier Etagen (Kap. 3). | — | `thm_*` |

### 1.2 Sprachregel für UI, Daten und Zeilen

1. **„Stufe“** nur für Figuren- und Gegnerstufen („Stufe 12“, „ab Stufe 15“). Nie „Level“, „Lv“, „LV“. In engen Anzeigen
   (Party-Rahmen, Plakette, Namensschild) steht nur die **Zahl in einer runden Stufen-Plakette**; der Tooltip sagt „Stufe 12“.
   Material und Rezepte haben eine **Güte**, Ausrüstung zeigt keine Stufe (nur Werte und Seltenheit).
2. **„Etage“** für Stockwerke („Etage 3“). Nie „Level“ oder „Ebene“. „E3“ nur in Dokumenten.
3. **„Rang“** für Berufe („Rang: Assistenz“) und bis zur Migration für Talente (heute schon `"Rang %d/%d"`); **„Liga 1 /
   Duo-Liga“** statt „Stufe 1 / Stufe 2“ der Unterhosen-Liga (Code `liga_tier` bleibt).
4. **„Kandidat:in“** statt „Crawler“; **„Klasse“** statt „Spezialisierung“ für `cls_*`; **„Vorleben“** statt „Beruf“ im
   Casting.
5. Bezeichner im Code bleiben englisch (`level`, `LEVEL_CAP`, `floor_index`); die Regel gilt für alles, was Spieler:innen
   lesen.
6. **Lint-Test** `test_09_terms`: durchsucht `data/*.json` (`name`, `desc`, `text`) und Stringliterale in `scenes/**/*.gd`
   nach `\bLevel\b`, `\bLv\b`, `\bLV\b`, `\bEbene\b`, `\bCrawler\b` (Wortgrenzen, Groß-/Kleinschreibung beachtet — Schlüssel
   wie `"level"` und Platzhalter wie `{level}` bleiben erlaubt) und schlägt fehl — Ausnahmen nur per Kommentar
   `# terms-ok: <Grund>` (z. B. Debug-Overlay).

**Fundstellen heute** (Stand `dff0345`; Umsetzung in ST1-A, Dateieigentum Kap. 11.4): `test_09_terms` findet die „Level“- und
„Lv“-Stellen selbst, deshalb keine Zeilenliste mehr. Betroffen sind `party_menu.gd` (`"Lv %d"`, „Casting ab Etage 3“, „noch
keine (ab Level 3)“), `talent_show.gd`, `skills_menu.gd`, `exploration_hud.gd`, `bestiary_menu.gd`, `slot_select.gd`,
`bets_menu.gd` („Stufe 1 … Stufe 2 (Duo-Liga)“ → „Liga 1 … Duo-Liga“), `battle_results.gd` (CTB, entfällt mit 07 R5b),
`achievements.json:216`, `mod_lines.json:996` und `:1588`, `README.md:51`, dazu `00_BRIEF` (CR-25) sowie GDD, 06 und 02_TECH
(CR-26, CR-27, CR-31). Ersatz: `"Lv %d"` → Stufen-Plakette mit Tooltip `"Stufe %d"`, sonst „Level“ → „Stufe“.

Die Ursache der Verwechslung, die die Idee anspricht, steht so im Party-Menü nebeneinander: „Casting ab **Etage** 3“ und
„Talente … ab **Level** 3“. Mit der Regel heißt es „Recall auf Etage 3“ und „Talentreihe ab Stufe 3“.

---

## 2. Staffel-Ablauf

### 2.1 Staffelarten, Formate und Tempo

| Art | Wer | Tempo | Mindestbesetzung (Menschen) | Phase |
|---|---|---|---|---|
| **Privat** | Sie allein, Rest KI; offline | **Kalender** (Standard) oder **Am Stück** | 1 | ST1 |
| **Freunde** | 2–100 eingeladene Menschen, Rest KI | Kalender | 2 | ST2 |
| **Öffentlich** | Warteschlange je Region, Format und Staffelart, Rest KI | Kalender | 10 (einstellbar) | ST2 |

**Formate (V-14):** Das Format einer Staffel folgt aus dem gekauften Inhalt; jede Staffel hat genau eines. Freunde- und
öffentliche Staffeln stellen nur Menschen zusammen, die dieses Format besitzen — nie gemischt. Privat wählen Sie jedes eigene
Format; Standard ist das größte.

| Format | Inhalt | Etagen | Kalender | Am Stück (Summe der Countdowns) | Großes Finale |
|---|---|---|---|---|---|
| **Basis** | Grundspiel (Akt 1) | 1–6 | 24 Tage ≈ 3,5 Wochen | 4 h Erkundungszeit (≈ 7–9 h Spielzeit) | Etage 6: Der Paketberg |
| **Akt 2** | Erweiterung | 1–12 | 54 Tage ≈ 8 Wochen | 9 h (≈ 16–19 h) | Etage 12: Die Wellenmaschine |
| **Akt 3** | Erweiterung | 1–18 | 84 Tage = 12 Wochen | 14 h (≈ 25–30 h) | Etage 18: Die Sendeleitung |

Spielzeiten Am Stück mit Kämpfen, Safe Rooms und Menüs **[Schätzung]**.

| Tempo | Uhr | Einsturz | Vorlauf | Schläfer / Ausgeruht | Wofür |
|---|---|---|---|---|---|
| **Kalender** | 1 Staffel-Tag = 24 h echte Zeit; die Uhr läuft immer, auch ausgeloggt | zu festen Terminen zur **Sendezeit** (privat wählbar, Standard 20:00 Ortszeit; online je Staffel fest) | Etagen 1–3 sofort offen, ab Etage 4 eine Etage (Kap. 2.6) | ja | Standard; online immer |
| **Am Stück** | jede Etage hat einen **Countdown**, der beim Betreten startet (Etage 1 nach dem Tutorial-Kampf, wie heute) und nur in der Erkundung läuft (GDD §2.9): 20/30/40, ab Etage 4 je 50 min | bei 0:00 | keine Grenze | nein (die Welt wartet) | privat, in eigenem Tempo; Barrierefreiheit |
| **Zeitraffer** | Kalender × Faktor (z. B. 1 min = 1 Tag) | wie Kalender | wie Kalender | ja | nur Debug-Builds und Harness |

**Am Stück im Detail (V-2):** keine Gnadenfrist beim Fortsetzen (der Dauerspeicherstand setzt den Countdown fort, wo er
stand; die 3:00 aus GDD §2.9 gelten in Staffeln nicht); Etage 1 behält ihre Streuner-Spawner (GDD §2.7); die Besetzung folgt
Ihnen (Kap. 4.2); Nachschub und Fundstellen kehren nach 10 min Erkundungszeit zurück; jede Etage bringt beim Betreten einen
Programmpunkt mit (Kap. 3.3). Am Stück ist zugleich die heutige Kampagne: Etage 1 hat dort ihre 20:00 wie im Slice; die
Bänder aus GDD §13 werden mit der Generalprobe (statt Game Over) neu gemessen (CR-26).

**Tempo-Wahl (V-6):** Die erste Staffel startet im Kalender. Nach der Klassenwahl auf Etage 3 bietet M.O.D. einmal an, privat
**Am Stück** weiterzuspielen (der Countdown der aktuellen Etage startet dann neu); später geht der Wechsel im
Pausemenü-Reiter „Staffel“ — nur in diese Richtung. Jede weitere private Staffel wählt das Tempo beim Anlegen. Warum es „Am
Stück“ gibt: Ein Premium-Spiel darf niemanden zum Warten zwingen (04 §6.2 Nr. 3; ehrlich dazu Kap. 10 Nr. 7).

### 2.2 Start, Lobby, Aussteigen

- **Die erste Staffel (V-6):** Im Titel steht ein Knopf **„Sendung starten“** → Figurenwahl → Casting (08) → Intro → Etage 1.
  Alles andere hat Standardwerte: privat, Mit Netz, Kalender, Sendezeit 20:00, größtes eigenes Format. Weil Etage 1–3 sofort
  offen sind, kann der Recall schon am ersten Abend kommen (≈ 1–1,5 h).
- **Jede weitere Staffel:** „Neue Staffel“ → Art (privat / Freunde / öffentlich), Format, Mit Netz oder Ohne Netz, Tempo
  und Sendezeit (privat) → Figurenwahl → Casting → Intro. Die drei Speicherplätze sind drei private Staffeln.
- **„Ohne Netz“** ist frei nach der ersten Klassenwahl (Recall) oder einer beendeten Staffel (V-7).
- **Freunde (ST2):** Die Gastgeber:in legt die Staffel an, wählt Format (das alle besitzen), Staffelart und Sendezeit und lädt
  ein; **„Staffel starten“** geht ab 2 Menschen. In den **ersten 48 h** dürfen Eingeladene einen KI-Platz übernehmen — auch den
  einer ausgestiegenen Person (V-18).
- **Öffentlich (ST2):** Eine Warteschlange je Region, Format und Staffelart. Sobald **10** Menschen warten, beginnt der
  Countdown „Gleich geht's los“ (15 min); bis dahin können weitere dazukommen (höchstens 100). Öffentliche Staffeln starten in
  Wellen nach jedem Sendetermin (Kap. 9.1).
- **Einstieg sonst nur vor dem Start** (S-22). Wer später kommt, nimmt die nächste Staffel.
- **Je Konto gleichzeitig höchstens eine öffentliche und eine Freunde-Staffel**; private Staffeln liegen lokal in den drei
  Plätzen. Wer ausgeschieden (Studiogast) oder fertig (Finalist:in) ist, darf sofort eine neue beginnen (V-7).
- **Aussteigen** (Reiter „Staffel“, mit Bestätigung): Online übernimmt die KI den Platz, sichtbar als **„übernommen“**; die
  Figur geht in die Ruhmeshalle („ausgestiegen auf Etage N“). Privat heißt der Knopf „Staffel beenden“ und gibt den
  Speicherplatz frei (V-18).
- Beim Start bekommt die Staffel einen Seed, eine Nummer („Staffel 37“), ihre feste Regelversion (S-23), alle Einsturztermine
  als UTC-Zeitpunkte (Kap. 2.4) und die KI-Besetzung für die freien Plätze (Kap. 4).

### 2.3 Besetzung

- **100 Plätze** (einstellbar 20–100). Menschen nehmen Plätze, die übrigen bekommen KI-Kandidat:innen; Plätze Ausgestiegener
  spielt die KI weiter („übernommen“).
- Der **Kandidatenzähler** zeigt Mit Netz „**Weiße Weste: 41/100**“ und Ohne Netz „**Noch dabei: 41/100**“ (HUD ab Etage 2
  neben dem LIVE-Badge, vorher nur im Pausemenü-Reiter „Staffel“).
- KI-Kandidat:innen folgen denselben Regeln wie Menschen (Treppe, Einsturz, Tod, Generalprobe) und sind überall als **KI**
  gekennzeichnet.

### 2.4 Sendeplan

Dauer je Etage: 2, 3, 4, dann je 5 Tage. **Tag n** = n × 24 h nach Tag 0, immer zur Sendezeit. „Offen ab“ = ab wann die
Etage betretbar ist (Kap. 2.6).

| Etage | Dauer | Auf Sendung (Tag) | Einsturz (Tag) | Offen ab Tag | Am Stück (Countdown) | Stufen-Band |
|---|---|---|---|---|---|---|
| 1 | 2 | 0–2 | 2 | 0 | 20 min | 1–7 |
| 2 | 3 | 2–5 | 5 | 0 | 30 min | 7–10 |
| 3 | 4 | 5–9 | 9 | 0 | 40 min | 10–13 |
| 4 | 5 | 9–14 | 14 | 5 | 50 min | 13–16 |
| 5 | 5 | 14–19 | 19 | 9 | 50 min | 16–19 |
| 6 | 5 | 19–24 | **24** (Ende Basis) | 14 | 50 min | 19–22 |
| 7 | 5 | 24–29 | 29 | 19 | 50 min | 22–25 |
| 8 | 5 | 29–34 | 34 | 24 | 50 min | 25–28 |
| 9 | 5 | 34–39 | 39 | 29 | 50 min | 28–31 |
| 10 | 5 | 39–44 | 44 | 34 | 50 min | 31–34 |
| 11 | 5 | 44–49 | 49 | 39 | 50 min | 34–37 |
| 12 | 5 | 49–54 | **54** (Ende Akt 2) | 44 | 50 min | 37–40 |
| 13 | 5 | 54–59 | 59 | 49 | 50 min | 40–43 |
| 14 | 5 | 59–64 | 64 | 54 | 50 min | 43–46 |
| 15 | 5 | 64–69 | 69 | 59 | 50 min | 46–49 |
| 16 | 5 | 69–74 | 74 | 64 | 50 min | 49–50 |
| 17 | 5 | 74–79 | 79 | 69 | 50 min | 50 |
| 18 | 5 | 79–84 | **84** (Ende Akt 3) | 74 | 50 min | 50 (Finale) |

- **Summe:** 24, 54 oder 84 Tage; warum die Dauer bei 5 Tagen bleibt (sonst 189 Tage), steht in Kap. 0.1. „Höchstens 18“
  (Idee) ist wörtlich erfüllt.
- **Tag 0 ist die nächste Sendezeit nach dem Start (V-17);** bis dahin läuft das „Vorprogramm“, Etage 1 ist schon offen. So
  hat Etage 1 immer volle zwei Tage, und alle Einstürze liegen auf der Sendezeit — abends, nie nachts.
- **Termine in UTC (V-17):** Der `season`-Command speichert beim Start alle Einsturztermine als UTC-Zeitpunkte, gerechnet aus
  der Sendezeit in der Ortszeit des Starts. Nach einer Zeitumstellung liegen sie eine Stunde verschoben (Start im Winter mit
  20:00 → im Sommer 21:00; umgekehrt 19:00); Sendeplan und Warnungen zeigen immer die echte Ortszeit. Online legt der Server
  die Sendezeit je Staffel und Region fest.
- **Kalender-Datei (V-9):** Der Reiter „Staffel“ exportiert den Sendeplan als `.ics` (lokal erzeugt, Einsturz- und
  Öffnungstermine); nach einer Sendepause bietet er die neue Datei an.

### 2.5 Einsturz

1. Zum Termin der Etage, die **auf Sendung** ist, stürzt sie ein. Wer dort steht (eingeloggt oder als Schläfer), ist betroffen;
   wer schon tiefer ist, nicht.
2. **Im Kampf** wartet der Einsturz bis zum Kampfende (die Sim kennt keine Uhr, 07 §2.10); danach bleiben **2 Minuten**
   („Die Regie wartet. Kurz.“) bis zum Einsturz (V-17). Am Stück steht der Countdown im Kampf ohnehin.
3. **Mit Netz → Rettung:** 3-s-Einsturzszene (GDD §2.9) → die Figur steht im ersten Safe Room der nächsten Etage.
   Gebühr **−30 % Credits, −10 % Follower** — aber **höchstens eine Gebühr je 7 Tage** (Rettung oder Sanitäter, Kap. 7.1),
   und **gratis für Schläfer im Safe Room** (die Regie trägt sie hinüber, V-9). Die Etagen-Bilanz der eingestürzten Etage
   entfällt (keine Abschluss-EP, kein Bilanz-Bonus); **weiße Weste weg**. Danach greift, falls nötig, der Regie-Crashkurs
   (Kap. 8.2).
4. **Ohne Netz → raus** (ab Etage 2): Einsturzszene → Sendeschluss-Bild (GDD §14.6) mit Titel „Verschüttet auf Etage N“ →
   **Studiogast** (Kap. 7.2).
5. **Etage 1 (Generalprobe):** Einsturz = Rettung ohne Gebühr und ohne Westenverlust, auch Ohne Netz (Kap. 7.3).
6. **Warnungen:** HUD 1 h, 10 min, 1 min vorher (Kalender) bzw. 10:00/5:00/1:00 Restzeit (Am Stück, wie heute); dazu die
   Benachrichtigungen aus Kap. 2.9.
7. Wer vor dem Einsturz die Treppe genommen hat, bekommt die **Etagen-Bilanz** wie heute (GDD §2.8) plus Abschluss-EP
   (Kap. 8.2).

### 2.6 Treppenregel: ab Etage 4 höchstens eine Etage Vorlauf

**Regel in einem Satz:** Etage 1–3 sind vom Start an offen; ab Etage 4 führt die Treppe nur eine Etage tiefer als die Etage,
die gerade auf Sendung ist.

- Die Treppe nach Etage M (ab M = 4) öffnet, sobald Etage M − 1 auf Sendung ist. Bis dahin zeigt sie: „**Etage M: Kulissen
  im Aufbau — öffnet in 1 T 6 Std.**“ (M.O.D.: „Die Regie baut immer nur eine Etage im Voraus. Sparmaßnahme.“)
- Ab Etage 4 steht also niemand mehr als eine Etage unter der Etage auf Sendung; stürzt diese ein, öffnet die nächste Treppe.
- **Am Stück** gibt es keine Grenze: Jede Etage hat ihren eigenen Countdown.
- **Warum Etage 1–3 offen sind (V-6):** Wer am ersten Abend Lust hat, schafft Etage 1 und 2 und wählt beim Recall auf Etage 3
  noch am selben Abend Spezies und Klasse. Die erste gesperrte Treppe ist die nach Etage 4 — genau dort bietet M.O.D. privat
  „Am Stück“ an (Kap. 2.1).

**Begründung:**

| Ziel | Wie die Regel es erfüllt |
|---|---|
| Schnelle warten nicht wochenlang | Höchstens die Restdauer einer Etage (≤ 5 Tage), und nie untätig: Vorlauf-Etage, Tagesprogramm, Optionales (Etagenboss, Show-Boss, Geheimnisse, Berufe, Pechvogel-Hilfe), Ausgeruht — oder privat Am Stück. |
| Langsame sind nie hoffnungslos hinten | Niemand ist hinter der Etage auf Sendung: Der Einsturz rettet nach vorn (Mit Netz). Crashkurs, Aufholjagd und Ausgeruht holen die Stufen schnell auf. |
| Die Besetzung bleibt zusammen | Ab Tag 5 (Etage 3 auf Sendung) stehen alle auf **zwei benachbarten Etagen** — für gemeinsame TV-Momente, Ranglisten und ST3. |
| Kein Davonleveln | Zusammen mit dem Stufen-Deckel je Etage (Kap. 8.2) überrollt niemand die nächste Etage. |
| Einfach | Eine Zahl („eine Etage voraus“), eine sichtbare Anzeige an der Treppe. |

### 2.7 Staffelende, Finale, Wertung, Titel

- Auf der letzten Etage des Formats (6, 12 oder 18) gibt es keine Treppe, sondern das **Große Finale** gegen deren Etagenboss
  (Tabelle Kap. 2.1). Wer es vor dem letzten Einsturz besiegt, hat die Staffel **geschafft**: Abspann, Staffel-Bilanz, Titel
  „Finalist:in“. Danach ist man Studiogast der restlichen Staffel (Kap. 7.2), ohne Titelverlust, und darf eine neue beginnen.
- **Letzter Einsturz** = Staffelende für alle. Wer noch lebt, aber das Finale nicht geschafft hat: „Bis zum Ende dabei“. Die
  Figur wandert in die **Ruhmeshalle** (ansehen, nicht weiterspielen).
- **Staffel-Quote** (Rangliste, Ganzzahlen, Startwerte): Etagen per Treppe × 1 000 + Revier-Bosse × 200 + Etagenbosse × 500 +
  Finale 3 000 + Achievements × 50 + ⌊min(Follower, 20 000) / 10⌋ − Rettungen × 500 − Tode × 200 (Etage 1 zählt nicht mit).
  Gleichstand: früheres Finale, dann früherer letzter Abstieg.
- **Ranglisten (V-11):** Öffentlich zählt die Menschen-Rangfolge (KI-Plätze stehen gekennzeichnet zur Unterhaltung dabei);
  privat zählt die Rangliste alle 100 Plätze, KI eingeschlossen („Platz 12 von 100“).
- **Titel** (nur Menschen, nur kosmetisch):

| Titel | Bedingung | Wo |
|---|---|---|
| Finalist:in der Staffel N | Großes Finale besiegt | überall; privat und unter Freund:innen mit Zusatz „privat“ |
| Weiße Weste | Finale ohne Rettung und ohne Tod (Mit Netz) | dto. |
| Überlebende:r — Ohne Netz | Finale in einer Staffel „Ohne Netz“ | dto. |
| Legende: <Beruf> | Beruf auf 300 | dto. |
| Studiogast, verschüttet / gefallen auf Etage N | Ohne Netz ausgeschieden (Erinnerungskarte in der Ruhmeshalle) | dto. |
| Erstbesteiger:in Etage N | erster Mensch der Staffel auf Etage N (N = 3, 6, 9, 12, 15, 18) | nur geprüfte öffentliche Staffeln mit ≥ 10 Menschen |
| Quotenkönig:in / Platz 2 / Platz 3 | Staffel-Quote, Menschen-Rangfolge | dto. |

- Belohnungen sind **nur kosmetisch** (Kostüme für Kandidat:in und Graf, Kartenrahmen, Studio-Deko); „geprüft“ heißt: der
  Verifier hat alle Sitzungen der Staffel nachgerechnet (Kap. 9.2).

### 2.8 Was zurückgesetzt wird und was bleibt

| Bleibt (Konto, „Karriere“) | Neu je Staffel |
|---|---|
| Titel, Kosmetik, Kartenrahmen, Ruhmeshalle (alle früheren Figuren), Konto-Erfolge, freigeschaltete Looks (08 K2), Einstellungen, die Freischaltung „Ohne Netz“ | Stufe, Ausrüstung, Inventar, Credits, Lootboxen, Berufe und Rezepte, Talente, Spezies, Klasse, Follower, Etagen, Zähler — und die Kandidatenkarte: jede Staffel beginnt mit einem leeren Casting (08 C-2, keine „Letzte Karte“) |

**Grundsatz:** Was eine Staffel überdauert, ist nie Kampfkraft. Neue Kandidat:innen treten fair gegen Erfahrene an.

### 2.9 Benachrichtigungen und Pausen

| Anlass | Wann | Kanal (ST1 / ab ST2) |
|---|---|---|
| Einsturz droht (Sie stehen auf der Etage auf Sendung und haben die Treppe nicht genommen) | 24 h und 3 h vorher (Mit Netz); 24 h, 3 h und 30 min vorher (Ohne Netz) | lokale Benachrichtigung / Push |
| Neue Etage offen (Sie warten im Vorlauf) | beim Öffnen | dto. |
| **Tageszusammenfassung:** was Ihr Schläfer erlebt hat, Ausgeruht voll, Weckrufe, die wichtigsten Eilmeldungen | einmal täglich zur Sendezeit, **standardmäßig aus** | ST1 nur beim Login / Push |

Regeln: **Opt-in** beim ersten Ausloggen („Sollen wir Sie vor dem Einsturz wecken?“); höchstens 3 je Tag; Ruhezeit 22–8 Uhr
Ortszeit (eine Warnung, die hineinfiele, kommt um 21:59; bei der Standard-Sendezeit passiert das nie); neutrale Texte ohne
Schuld- oder Verlustdrohung („Etage 5 stürzt morgen um 20 Uhr ein.“); jederzeit abschaltbar. Desktop ohne Systemmitteilungen
zeigt die Warnung im Titel und in der Login-Bilanz. Lokale Benachrichtigungen unter Android/iOS mit Godot 4.7 **[Plugin zu
prüfen]**.

**Pausen und Tägliches (V-9):**

- **Sendepause** (nur privat): Reiter „Staffel“ → „Sendepause“, bis zu **14 Tage** je Staffel, am Stück oder in Teilen; die
  Uhr steht, alle offenen Termine verschieben sich. Online gibt es keine Pause — dort tragen das Gratis-Tragen im Safe Room,
  die Wochen-Gebühr und der Crashkurs.
- **Tägliches sammelt sich an:** Was je Staffel-Tag nachkommt (Fundstellen, Händler-Bestand, Ankauf-Deckel des Automaten),
  lädt bis zu **4 Tage** nach — wer zwei Tage fehlt, findet zwei Portionen vor. Programmpunkte bleiben ohnehin bis zum
  Einsturz (Kap. 3.3).
- **Lange Abwesenheit offline:** Über 7 Tage zählen nach einer Rückfrage nur 7 Tage, der Rest wird Sendepause (Kap. 5.5).

---

## 3. Etagen 1–18

### 3.1 Übersicht

| Etage | Kulisse | Tage je Etage | Stufen-Band | Räume (Viertel) | Safe Rooms | Revier-Boss (Pflicht, trägt den Treppenschlüssel) | Etagenboss (optional; Großes Finale auf der letzten Etage des Formats) | Stand |
|---|---|---|---|---|---|---|---|---|
| 1 | **Die Unterstadt** (U-Bahn; Generalprobe) | 2 | 1–7 | 31 (4, handgebaut) | 3 | Der Hausmeister | Die Rattenkönigin von Gleis 9 | gebaut |
| 2 | **Passage Ewiger Rabatt** (Einkaufspassage) | 3 | 7–10 | 18–24 (2) | 2–3 | Die Filialleiterin im Dauerlächeln (Idee GDD §15) | Der Ausverkauf (Idee GDD §15) | Stub: 3 Gegner, Daten `floor_2`, Entwurf 07 §6.8 |
| 3 | **Der Fundus** (Requisiten- und Kostümlager des Senders; **Recall**) | 4 | 10–13 | 26–32 (3) | 3 | Die Requisiteurin | Die Garderobe | neu |
| 4–6 | **Das Paketzentrum** (Förderbänder, „Zustellversuch gescheitert“) | 5 | 13–16 · 16–19 · 19–22 | 36–48 (3–4) | 3–4 | Die Schichtleiterin (wiederkehrend) | E6: Der Paketberg (Finale Basis) | neu |
| 7–9 | **Amt für Etagenwesen** (Wartemarken, Formular-Golems, Stempel) | 5 | 22–25 · 25–28 · 28–31 | 36–48 (3–4) | 3–4 | Der Sachbearbeiter (wiederkehrend) | E9: Der Nummernautomat | neu |
| 10–12 | **Erlebnisbad Chlorado** (Rutschen, Chlornebel, Wellenbecken) | 5 | 31–34 · 34–37 · 37–40 | 36–48 (3–4) | 3–4 | Die Bademeisterin (wiederkehrend) | E12: Die Wellenmaschine (Finale Akt 2) | neu |
| 13–15 | **Rechenzentrum „Wolke 7“** (Serverracks, Kühlung, Kabel) | 5 | 40–43 · 43–46 · 46–49 | 36–48 (3–4) | 3–4 | Der Admin (wiederkehrend) | E15: Der Kabelkrake | neu |
| 16–18 | **Das Hauptstudio** (NOVA-Kulissen, Kameras, Maske, Regie) | 5 | 49–50 · 50 · 50 | 36–48 (3–4) | 3–4 | Die Aufnahmeleitung (wiederkehrend) | E18: **Die Sendeleitung** (Finale Akt 3) | neu |

Einsturztermine und Am-Stück-Zeiten: Sendeplan Kap. 2.4.

Alle Namen sind Arbeitstitel **[Namens- und Markenrecherche zu prüfen, 04 Kap. 2.5]**; keine Kulisse übernimmt Themen oder
Reihenfolge der Buchetagen (04 Kap. 2.2). Die Satire zielt wie bisher auf TV, Werbung, Logistik und Bürokratie (06 L-3/L-7).
„Senderzentrale“ bleibt der Name des späteren Hubs (06 §7), deshalb heißt die letzte Kulisse „Hauptstudio“.

### 3.2 Bausteine jeder Etage

| Baustein | Regel |
|---|---|
| **Treppe** | Hinter einem Tor; den **Treppenschlüssel** trägt der Revier-Boss (wie `key_master` auf Etage 1). Öffnet ab Etage 4 nur bis zur Vorlauf-Grenze (Kap. 2.6). Die letzte Etage des Formats hat keine Treppe: Der Schlüssel öffnet dort das Finalstudio. |
| **Revier-Boss** (Anzeigename nach 04 E2; bis zur Entscheidung „Quartier-Boss“) | Pflicht. Je Kulisse **eine wiederkehrende Figur**, die mit jeder Etage eine Phase oder Mechanik dazulernt („Die Schichtleiterin ist zurück. Mit Hubwagen.“) — eine Figur, drei Kämpfe, wenig Modellbau. |
| **Etagenboss** | Optional, große Beute; auf Etage 1, 2, 3 und auf der letzten Etage jeder Kulisse (6, 9, 12, 15, 18). Auf der letzten Etage des Formats ist er das Große Finale (Pflicht für den Staffelsieg). |
| **Show-Boss** | Optional, je Etage einer (goldgerahmte Elite-Gruppe mit einer Zusatzregel, 06 §2.6, 07 E26) — nur Daten. |
| **Viertel** | 3–4 Zonen mit eigener Palette, eigenem Gegnerpool, einem Safe Room je Viertel und einer **Gefahr** für Schläfer (ruhig/unruhig/gefährlich, Kap. 5.3). |
| **Nachschub** | Besiegte Gruppen kehren nach **einem Staffel-Tag** zurück (Am Stück nach 10 min Erkundungszeit); Etage 1 behält ihre Streuner wie heute (GDD §2.7). |
| **Fundstellen** | Je Viertel 4–6 Schrotthaufen bzw. Pilzbeete (Berufe, Kap. 8.5); je Staffel-Tag eine Ladung, bis zu 4 gesammelt (Am Stück: nach 10 min). |
| **Events, Geheimnisse** | Etagen-Events aus dem Pool der Kulisse (vorhandene Typen, GDD §2.6), dazu ein **Pechvogel**-Event (Kap. 4.3); 1–3 Kulissenwände und Regie-Notizen (06 §2.7). |
| **Vorlieben** | M.O.D.s Vorlieben (06 §4): eine je Etage wie heute; weitere kommen als Programmpunkte dazu. |
| **Tagesprogramm** | Kap. 3.3. |

### 3.3 Pensum und Tagesprogramm

**Tagesprogramm (V-5):** Zu jeder Sendezeit bekommt jede offene Etage einen neuen **Programmpunkt**, höchstens fünf je Etage;
jeder bleibt bis zu ihrem Einsturz. Ein Programmpunkt ist ein **Event-Raum** (eine bisher verschlossene Tür), eine
**Show-Boss-Variante** (neue Zusatzregel) oder eine **weitere Vorliebe**. Wer zwei Tage fehlt, findet zwei neue Punkte vor;
nichts verfällt vor dem Einsturz. Die ersten fünf Tage, in denen eine Etage offen ist, sind meist ihre Vorlauf-Tage — genau
dann sind die Schnellen dort; die Langsameren finden später alles beisammen. Am Stück bringt jede Etage beim Betreten einen
Punkt mit. Auswahl deterministisch aus dem Pool der Kulisse (`SeedUtil.derive(season_seed, "daily", floor, day)`), Marker
„NEU“ auf der Karte und im Reiter „Staffel“.

| Etage | Pflichtweg (Treppe + Revier-Boss) | Vollständig (alles, inkl. Etagenboss) | Tagesprogramm | Kalender: Minuten je Tag für den Pflichtweg |
|---|---|---|---|---|
| 1 | ≈ 20 min | 25–30 min | 2 Punkte à 5–10 min | 10 |
| 2 | ≈ 30 min | 40–50 min | 5 Punkte | 10 |
| 3 | ≈ 45 min | 60–75 min | 5 Punkte | 12 |
| 4–18 | ≈ 60 min | 90–120 min | 5 Punkte | 12 |

- **Gelegenheitsspiel mit 1 h am Tag ist bequem:** Eine 5-Tage-Etage bietet 5 h für 2–3 h Inhalt. Schon **20 min am Tag**
  reichen für den Pflichtweg; wer fehlt, holt mit Crashkurs, Aufholjagd und Ausgeruht auf.
- **Vielspieler:innen** schaffen Etage und Vorlauf in 1–2 Tagen; danach bringt jeder Tag neue Programmpunkte, dazu
  Optionales, Berufe und (ab ST3) andere Spieler:innen. Mehr Stufen gibt es dafür nicht (Deckel), aber Credits
  („Überstunden“, Kap. 8.2), Material und Quote.
- **Ehrlich:** Wer im Kalender täglich deutlich mehr als eine Stunde spielen will, findet ab dem dritten Tag einer Etage nur
  noch Programmpunkte und Optionales. Dafür gibt es privat „Am Stück“.
- Messung im Staffel-Harness (Kap. 11.6): Pflichtweg E4–E18 60–75 min, vollständig 90–120 min **[zu messen]**.

### 3.4 Skalierung von Gegnern, Beute und Bossen

- **Gegnerstufe:** Jede Gegnergruppe einer Etage hat eine Stufe im Band der Etage (Pflichtweg Bandmitte, Nebenwege bis
  Bandende + 1, Elite + 2). Werte wachsen über eine **Stufen-Tabelle** `enemy_level_pm[stufe]` in `data/rt_balance.json`
  (Ganzzahl-Promille, 07 §3.16): Grundwerte des Gegnertyps × Tabellenwert. Ein Gegnertyp funktioniert so auf drei Etagen.
- **Farbe und Zahl wie in WoW, farbenblind-sicher (V-6):** Das Namensschild zeigt die Stufen-Plakette, daneben die
  **Differenz als Zahl** („+3“, „−4“) und die Farbe: grau (≥ 6 Stufen unter Ihnen, 0 EP), grün (3–5 darunter), gelb (±2),
  orange (3–4 darüber), rot (≥ 5 darüber, mit Warnsymbol „Achtung“). Die Zahl trägt die Information, die Farbe hilft nur.
- **Beute:** Ausrüstung skaliert intern mit der Bandmitte der Etage (`item_level`, nicht angezeigt — die UI zeigt Werte und
  Seltenheit: Ramsch grau, gewöhnlich weiß, selten blau, episch lila; 06 §2.3). Werte aus Vorlagen je Platz und Figur ×
  `item_level`; Credits, Lootboxen und Kisten skalieren mit der Etage.
- **Bosse:** Revier-Bosse kommen aus einem **Boss-Baukasten**: Grundfigur + Phasen aus einem Katalog von Mechaniken (Adds,
  Telegraph-Welle, unterbrechenswerter Zauber, Schild, weiches Enrage; alles vorhandene 07-Bausteine `RtRule`/`phases`),
  je Auftritt eine Mechanik mehr. Etagenbosse sind handgebaut (07 §6.6/§6.7 als Muster).

### 3.5 Was es gibt, was gebaut werden muss, was es kostet

| Baustein | Heute | ST1 (Prototyp, Platzhalter erlaubt) | Produktion (Phase 4/5, 04) |
|---|---|---|---|
| Etage 1 | komplett | unverändert (Am Stück = heute, Generalprobe statt Game Over) | Art-Upgrade |
| Etage 2 | Daten-Stub, 3 Gegner, Boss-Ideen | spielbar mit Platzhalter-Gegnern, Revier- und Etagenboss aus dem Baukasten | 8 Gegner, 2 Bosse |
| Etagen 3–18 | — | prozedural (Kap. 3.6), Kulissen als Palette + **Platzhalter-Familien** (umgefärbte E1/E2-Gegner mit Stufen-Skalierung), Revier-Bosse aus dem Baukasten, Etagenbosse als skalierte Platzhalter, Tagesprogramm aus vorhandenen Event-Typen | 6 Kulissen × 8 Gegner, 6 wiederkehrende Revier-Bosse, 6 Etagenbosse, Musik, Events, Programmpunkte |
| Gegner-Skalierung | feste Werte je Typ | Stufen-Tabelle, Farbe + Differenz | Feinschliff je Kulisse |
| Beute-Skalierung | Etage-1-Tabellen | Vorlagen × `item_level`, Material in 6 Güten | Sets, Namen |
| Generator | Baum auf Raster, ≤ 3 Safe Rooms, 1 Revier-Boss | Generator v2 (Kap. 3.6) | Kulissen-Raumteile (03_ART) |

**Aufwand ehrlich (V-5):** 04 §3.5 plant einen Content-Durchsatz von **einer Etage je 8–10 Wochen** (Team, handgebaut wie
Etage 1). Diese Zahl gilt weiter — für jede Etage mit eigener Kulisse und für die erste Etage jeder neuen Kulisse. Nur die
zweite und dritte Etage einer Kulisse werden billiger (gleiche Gegner, wiederkehrender Revier-Boss, gleiche Raumteile; neu
sind eine Boss-Phase, die Etagenboss-Arbeit auf der dritten, Programmpunkte, Zeilen, Balancing):

| Paket | Etagen | Aufwand Team **[Schätzung]** |
|---|---|---|
| je Kulisse à 3 Etagen | erste Etage 8–10 Wochen, jede weitere 3–4 Wochen | 14–18 Wochen ≈ 5–6 Wochen je Etage |
| Basis (Akt 1) | 2 und 3 (je eine eigene Kulisse), 4–6 (Paketzentrum) | 8–10 + 8–10 + 14–18 = 30–38 Wochen |
| Akt 2 | 7–9, 10–12 | 28–36 Wochen |
| Akt 3 | 13–15, 16–18 | 28–36 Wochen |
| Tagesprogramm | ≈ 12 Punkte je Kulisse (Daten, Zeilen, Event-Räume aus vorhandenen Typen) | in den Zahlen oben enthalten, ≈ 2 Wochen je Kulisse |

Etage 2–18 kosten damit ≈ 86–110 Team-Wochen statt 136–170 bei 8–10 Wochen je Etage. Die 3–4 Wochen je Varianten-Etage sind
unbewiesen; Beweis ist Etage 5 (Paketzentrum) in ≤ 4 Wochen, sonst gilt 04 §3.5 auch für sie (CR-29).

### 3.6 Prozedurale Generierung (Generator v2)

Der vorhandene `DungeonGenerator` (Baum auf Raster, deterministisch aus `floor_seed`, Wiederholversuche, Validierung) bleibt
für Etage 2 und wird für Etagen 3–18 erweitert (`core/dungeon/zone_generator.gd`, gerufen für `FloorDef` mit `zones`):

1. **Viertel nacheinander wachsen lassen:** Viertel k wächst mit dem heutigen Baumverfahren aus einer Anschlusszelle von
   Viertel k−1 (Raster 10×10 bis 13×13, je Viertel 10–14 Räume).
2. **Schleifen:** je Viertel 1–2 zusätzliche Türen zwischen benachbarten Zellen desselben Viertels (für mehrstündiges
   Erkunden; Abstand ≥ 4 Zellwechsel im Baum, damit Schleifen Wege abkürzen).
3. **Inhalt:** Treppe im letzten Viertel (tiefste Zelle), Tor davor mit Schlüssel des Revier-Bosses (Raum auf dem Pfad, wie
   `QB_PATH_FRAC`), Etagenboss an einer Sackgasse neben der Treppe, je Viertel ein Safe Room nahe dem Eingang, Show-Boss in
   einem Seitenviertel, Gruppen nach Tiefe gewichtet, Kisten, Fundstellen, Events aus dem Kulissen-Pool, 1–3 Kulissenwände,
   **bis zu fünf verschlossene Türen für Programmpunkte** (Event-Räume, in Seitenvierteln).
4. **Gefahr je Viertel:** erstes Viertel ruhig, mittlere unruhig, das Viertel mit Treppe/Bossen gefährlich.
5. **Prüfregeln** wie heute (`FloorLayout.validate`) plus: jedes Viertel erreichbar, jede Fundstelle erreichbar, Pflichtweg
   Start → Revier-Boss → Treppe ohne Etagenboss, Safe Room in jedem Viertel.
6. **Leistung:** 36–48 Räume statt 31 — Bau der Erkundung nur für das aktuelle und die angrenzenden Viertel
   (Viertel-Streaming), Budgets 02_TECH §12.1 / `PERFORMANCE.md` **[zu messen]**.

Daten: `data/themes.json` (Präfix `thm_`: Palette, Gegnerpool je Viertel, Revier-Boss, Etagenboss, Event-, Fundstellen- und
Programmpunkt-Pool, Musik) und je Etage ein Eintrag in `floors.json` mit `theme`, `variant` (1–3), `level_band`, `zones`,
`rooms`, `safe_rooms` (bis 4) — Schema-Erweiterung CR-27.

---

## 4. KI-Kandidat:innen

### 4.1 Grundsatz

**KI-Kandidat:innen spielen nach denselben Regeln** (Treppe, Einsturz, Tod, Rettung, Ranglisten) und sind **immer als KI
gekennzeichnet** (Plakette „KI“ in Zähler, Rangliste, Ticker und an ihrer Figur). Sie nehmen Menschen nichts weg: keine
gemeinsamen Beute- oder Fundstellen, keine Angriffe, keine Bosse, die vorher „weg“ sind.

### 4.2 Populationsmodell (abstrakt, den größten Teil der Zeit)

Jede KI-Kandidat:in ist ein kleiner Datensatz in `CastSim` (`core/season/cast_sim.gd`), geführt im Spielzustand:

| Feld | Werte | Herkunft |
|---|---|---|
| Name, Wortform | aus einem KI-Namenskatalog (≥ 300 erfundene, alliterierende Namen ohne Herkunfts- oder Altersmerkmale, Stil wie 08 §4.6) **[Register-Abgleich zu prüfen]** | Staffel-Seed |
| Vorleben, Hobby | aus dem 08-Katalog | Staffel-Seed |
| Können `skill` | 20–95 (Dreieck, Mitte 55) | Staffel-Seed |
| Tempo `pace` | 0,3–3,0 Spielstunden je Tag | Staffel-Seed |
| Profil | Statist:in 50 %, Rival:in 15 %, Helfer:in 15 %, Händler:in 10 %, Pechvogel 10 % | Staffel-Seed |
| Spezies, Klasse | beim Recall nach Gewichten aus Kais Spezies und Klassen (KI-Kandidat:innen sind Menschen ohne sprechenden Mops — „Nur Sie haben einen Grafen.“) | Würfel beim Recall |
| Zustand | Etage, Stufe, Fortschritt, Weste, Rettungen, Tode, raus, „übernommen“ | Sim |

**Takt:** Im Kalender je **Staffel-Stunde** ein Schritt für alle. **Am Stück folgt die Besetzung Ihnen (V-2):** ein Schritt
je 25 s Ihrer Erkundungszeit, keine KI-Kandidat:in ist mehr als eine Etage vor Ihnen, und wenn Sie absteigen, rechnet das
Modell Ihre bisherige Etage für alle zu Ende. Je Schritt: Fortschritt auf der Etage nach `pace` × `skill` × Etagenschwere; bei
100 % Abstieg (wenn die Treppenregel es erlaubt); Stufe folgt dem Band; Todeswurf je Schritt nach Können und Etage (Mit Netz:
Wiederbelebung, Weste weg; Ohne Netz: raus; Etage 1: Generalprobe); Einsturz wie für Menschen. Plätze Ausgestiegener spielt
das Modell mit Können 55 weiter. Zufall nur aus `SeedUtil.derive(season_seed, "cast", index, hour)` — deterministisch,
wiederholbar, ohne Wanduhr. Kosten: 99 × 2 016 Stunden ≈ 200 000 kleine Schritte je Akt-3-Staffel — vernachlässigbar.

**Kalibrierung (Startwerte, ab ST2 an echten Menschen-Daten nachgestellt):**

| Kennzahl | Mit Netz | Ohne Netz |
|---|---|---|
| weiße Weste bzw. noch dabei nach Etage 3 / 9 / Finale | ≈ 70 % / 40 % / 20–25 % | ≈ 80 % / 45 % / 15–25 % |
| Finale geschafft | 35–45 % | 15–25 % |
| Erste KI auf Etage N vor dem ersten Menschen | in ≈ 50 % der Fälle | dto. |

### 4.3 Verkörperung (in der Nähe der Spieler:in)

ST1/ST2 verkörpern KI-Kandidat:innen nur an festen Stellen — robust und ohne Wegfindung durch die ganze Etage:

| Wo | Was passiert | Regel |
|---|---|---|
| **Safe Room** | Bis zu 2 KI-Kandidat:innen, die laut Modell gerade auf dieser Etage sind, sitzen im Safe Room: eine Zeile, Ranglistenplatz, je nach Profil Handel oder Gastauftritt | Auswahl aus dem Modell, deterministisch je Besuch |
| **Gastauftritt** | Eine **Helfer:in** begleitet die Party für **3 Kämpfe** als zusätzliche Einheit `p2` (mit einer dritten Begleitfigur nach 06 §2.5: `p3`) mit der 07-Partner-KI (Taktik „Unterstützen“), nie im Bosskampf | Kosten: ein Gefallen (Pechvogel gerettet) oder Credits; Werte aus Klassenvorlage × Stufe (CR-32 c: Schema-Haken vor R4, Wirkung mit ST1-F) |
| **Pechvogel** | Etagen-Event `candidate_in_need`: eine KI-Kandidat:in steckt in einem Kampf fest; helfen = normaler Kampf mit ihr als Gast | Belohnung: Follower + ein Gefallen; Absage hat keine Strafe |
| **Rival:in** | Vor der Tür des Revier-Bosses steht die Rival:in der Persona (08 §4.6) oder eine Rival:in aus dem Modell: Zeile vor dem Kampf, Zeitvergleich danach („Sie waren 4 Minuten schneller. Ich bin entsetzt.“) | rein erzählerisch, kein Wettkampf um Beute |
| **Händler:in** | Im Safe Room: kauft Hergestelltes, verkauft Material und Rezepte der Kulisse | Preise aus dem Automaten (`shop.gd`), Bestand je Tag (sammelt sich 4 Tage) |
| **Im Schlaf** | Begegnungen im Gang (Kap. 5.3) | `SleepResolver`, deterministisch |
| **Ab ST3** | KI-Kandidat:innen laufen sichtbar durch geteilte Etagen und kämpfen dort mit der 07-KI — nur in der Nähe von Menschen | Server-Sim (Kap. 9.3) |

### 4.4 Profile in einem Satz

- **Statist:in:** füllt Zähler und Ticker, taucht gelegentlich im Safe Room auf.
- **Rival:in:** ist immer knapp vor oder hinter Ihnen, sagt es — und hinterlässt Schläfern Zettel.
- **Helfer:in:** kommt auf Wunsch für drei Kämpfe mit und hält manchmal Wache, wenn Sie schlafen.
- **Händler:in:** kauft und verkauft im Safe Room und legt Schläfern Angebote hin.
- **Pechvogel:** braucht Hilfe, erinnert sich daran — und zieht manchmal eine Streife an Ihrem Schlafplatz vorbei.

### 4.5 Fairness

1. Gleiche Regeln, sichtbare Kennzeichnung (4.1).
2. Titel nach Kap. 2.7 (V-11): Ranglisten-Titel nur nach der **Menschen-Rangfolge** geprüfter öffentlicher Staffeln mit
   ≥ 10 Menschen; privat zählt die Rangliste alle 100 Plätze, vergibt aber nur Abschluss-Titel.
3. KI-Kandidat:innen beeinflussen nie Würfe, Beute, Bosse oder Einstürze der Menschen; Gastauftritte sind freiwillig und
   nie im Bosskampf (Boss-Bänder aus 07 §11 bleiben gültig).
4. Ihr Erfolg ist kalibriert (4.2), nicht geschönt: Sie sterben und scheitern sichtbar, damit der Zähler etwas bedeutet.

### 4.6 M.O.D., Eilmeldungen, Zähler

- Das Modell erzeugt **Ereignisse** (`CastEvent`: Abstieg, Erstbesteigung, Tod, Rettung, Ausscheiden, Aussteigen,
  Etagenboss besiegt, Rekord). Daraus werden **Eilmeldungen** im Chat-Ticker und als M.O.D.-Zeile (Präfix `cast_`),
  höchstens **eine je 10 min Spielzeit**, nie im Kampf, wichtige zuerst („Eilmeldung: Bodo Bürste ist raus. Er wollte einen
  Rabattschild-Golem streicheln.“). Geschriebene Zeilen mit Platzhaltern `{cand}` `{floor}`; die KI (06 §5) darf später nur
  Varianten liefern.
- **Kandidatenzähler** (Kap. 2.3) und im Pausemenü-Reiter **„Staffel“**: Sendeplan, Tagesprogramm, Rangliste, Ticker der
  letzten 24 h.
- Bei Ihrem Login fasst die Login-Bilanz die wichtigsten Meldungen zusammen (Kap. 5.4).

---

## 5. Schläfer und Ausloggen

### 5.1 Regeln

1. **Ausloggen geht überall außerhalb eines Kampfes** (Pausemenü „Ausloggen“, im Safe Room „Ausloggen | Weiter“). Die Figur
   bleibt als **Schläfer** genau dort.
2. **Wer geht, wird zur KI:** Ein Absturz oder eine beendete App gilt als Ausloggen, im Kalender-Tempo auch mehr als
   **10 min Pause oder Hintergrund**. Ein offener Kampf wird beim nächsten Start **vom Kampfanfang an** mit Autopilot
   entschieden (Journal, Kap. 9.1), danach schläft die Figur. Online ist ein kurzer Verbindungsabbruch kein Ausloggen:
   120 s Gnadenfrist (Kap. 9.2).
3. **Dauerspeicherstand:** Jede Zustandsänderung ist gesichert (S-15); es gibt kein Zurückladen eines älteren Stands.
4. **Am Stück** steht die Uhr, solange niemand spielt: Ausloggen ist dort immer sicher, es gibt weder Begegnungen noch
   Ausgeruht.
5. **Vor dem Ausloggen** zeigt ein Dialog, was passiert, und **wählt die Schlaf-Taktik (V-10):** „Safe Room: sicher, Sie
   werden ausgeruht.“ oder „Gang (unruhig): bis zu 3 Begegnungen. Ihre Figur schläft [Vorsichtig] [Unterstützen]
   [Angriff]. Nächster Safe Room: 2 Räume.“ — Knöpfe **„Hier schlafen“** und **„Zurück“**. Standard ist „Vorsichtig“ (07 §5.2:
   flieht am ehesten, nutzt Tränke). Ohne Netz zusätzlich: „Hier können Sie sterben.“

### 5.2 Safe Room: sicher und ausgeruht

- Im Safe Room greift nichts an. Pro **voller Stunde** als Schläfer (Kalender) wächst der Vorrat **Ausgeruht** um **5 % der EP
  der aktuellen Stufe** bis höchstens **150 %** (1,5 Stufen; voll nach 30 h).
- **Wirkung:** Jede Kampf-EP zählt doppelt (Bonus = min(Grund-EP, Vorrat), Vorrat sinkt um den Bonus). Abschluss-, Event- und
  Berufs-EP verdoppelt Ausgeruht nicht.
- **Einsturz im Schlaf:** Die Regie trägt Sie gratis hinüber (Kap. 2.5); Sie schlafen im ersten Safe Room der neuen Etage
  weiter.
- **Anzeige:** blauer Abschnitt auf der EP-Leiste, „Zzz“ am Party-Rahmen, Zeile in der Login-Bilanz.
- **Warum so:** Ausgeruht hilft genau denen, die wenig Zeit haben — sie holen mit wenigen Kämpfen auf (WoW-Prinzip „Gasthaus“).

### 5.3 Im Gang schlafen: Begegnungen

| Viertel-Gefahr | Wurf | Chance je Wurf | Begegnungen je Abwesenheit | Ohne Netz: Todesrate je Nacht (8 h), Testband |
|---|---|---|---|---|
| ruhig | je angefangene 4 h, der erste nach 30 min | 15 % | höchstens 3 | < 0,5 % |
| unruhig | dto. | 35 % | höchstens 3 | 1–2 % |
| gefährlich | dto. | 60 % | höchstens 3 | 3–6 % |

Eine Begegnung ist (Würfel aus `SeedUtil.derive(seed, "sleep", n)`) zu 70 % eine **Streife** — eine reguläre Gruppe aus dem
Pool des Viertels auf Etagenstufe, nie Boss, nie Elite — und zu 30 % eine **KI-Kandidat:in**, die laut Modell gerade auf der
Etage ist (V-10):

| Profil | Was sie tut |
|---|---|
| Helfer:in | **hält Wache:** Die nächste Streife dieser Abwesenheit kämpft gegen Sie beide (Gast `p2`, 07-Partner-KI). |
| Pechvogel | **zieht eine Streife vorbei:** sofort ein Kampf, die Gruppe eine Stufe höher („Entschuldigung! Die wollten zu mir.“). |
| Rival:in | **hinterlässt einen Zettel:** eine Zeile in der Login-Bilanz („Sie schnarchen in Stereo. Ich bin trotzdem vor Ihnen.“). |
| Händler:in | **legt ein Angebot hin:** beim Login kaufen oder liegen lassen. |
| Statist:in | geht vorbei (eine Ticker-Zeile). |

- **Kampf:** `RtSim` headless (07), beide Figuren KI mit der **im Dialog gewählten Taktik** und ihren Schaltern, Start-HP und
  -MP nach der Regeneration seit dem Einschlafen (07 §2.7 auf die verstrichene Zeit gerechnet — meist voll).
- **Notfall-Rückzug:** Fällt die Party unter **25 % der Summe der Max-HP**, hält der Auflöser die Sim an und würfelt die
  Flucht (Taktik „Vorsichtig“ 80 %, sonst 60 %). Gelingt sie, endet der Kampf ohne Beute; misslingt sie, läuft der Kampf zu
  Ende.
- **Sieg:** normale EP (ohne Ausgeruht) und Beute; **Niederlage:** Todesregel (Kap. 7; auf Etage 1 die Generalprobe). Es gibt
  keine Begegnungen in Bossräumen, Safe Rooms und auf der Treppenzelle.
- **Testbänder (V-10):** `test_09_sleep` misst die Todesrate Ohne Netz für eine Nacht (8 h) über 1 000 Seeds je Gefahr mit
  bandtypischer Ausrüstung und Taktik „Vorsichtig“; Chancen, Rückzug und Gruppenwahl werden auf die Bänder der Tabelle
  eingestellt.
- **Absicht:** Draußen schlafen geht meist gut aus, manchmal einträglich, selten tödlich — und ist Ohne Netz eine echte
  Entscheidung. Drinnen schlafen ist sicher und bringt Ausgeruht. „Ausgeliefert“ (Idee) ist man Monstern und dem Pech der
  anderen; Kandidat:innen greifen nie an (F-6).

### 5.4 „Während Sie schliefen …“ (Login-Bilanz)

Ein Bildschirm vor dem Weiterspielen, jederzeit überspringbar, höchstens sieben Zeilen:

```text
WÄHREND SIE SCHLIEFEN …                    (3 Tage 4 Stunden, Gang „Rohrgang“, unruhig, Taktik „Vorsichtig“)
• Etage 5 ist eingestürzt. Die Regie hat Sie gerettet: −30 % Credits, −10 % Follower (nächste Gebühr frühestens Mo 20:00)
• 2 Begegnungen: Hanne Hammerschlag (KI) hielt Wache — 1 Streife besiegt (+1 840 EP, 120 Credits, Kabelrest ×2)
• Regie-Crashkurs: Stufe 16 → 17, das Aufholpaket liegt im Inventar
• Etage 6 ist auf Sendung · Einsturz in 1 T 20 Std. · neu im Programm: 2 Punkte
• Eilmeldung: Kira Katzenjammer ist auf Etage 7 — als Erste.
[Weiter]
```

Bei einem Einsturz während der Abwesenheit steht die Rettung bzw. der Sendeschluss **zuerst**, mit klarer Sprache.

### 5.5 Deterministisch und aufgezeichnet

- **Offline (ST1):** Beim Login entsteht genau ein aufgezeichnetes Command `{"t": "away", "sec": N}` (Abwesenheit in
  Staffel-Sekunden, aus der lokalen Uhr). Der Kern geht die Abwesenheit **Staffel-Stunde für Staffel-Stunde** durch: Besetzung,
  fällige Begegnungen (`SleepResolver`), fälliger Einsturz (eine Rettung setzt die Figur in einen Safe Room — ab da wächst
  Ausgeruht, und es kommen keine Begegnungen mehr), Regeneration, Ausgeruht, Tägliches, Tagesprogramm, zuletzt der
  Crashkurs. Replay und Verifier kommen mit demselben Command zum selben Hash.
- **Uhr (V-17):** Die Staffel-Uhr ist **monoton**: Läuft die Gerätezeit rückwärts, steht die Staffel, bis die Zeit wieder
  aufholt; ein Sprung nach vorn ist verstrichene Zeit (wer vorspult, verkürzt die eigene Etage). **Sprünge über 7 Tage**
  fragen nach („Sie waren 23 Tage weg?“): bestätigt zählen höchstens 7 Tage, der Rest wird Sendepause (die Termine
  verschieben sich, `season` `op: "pause"`); verneint zählt nichts. Die letzte gesehene Zeit steht im Spielstand.
- **Online (ST2):** Der Server führt die Uhr und den kanonischen Zustand (Kap. 9.2); Begegnungen rechnet er beim Einsturz,
  bei einem Weckruf oder beim Login (nachträglich, gleiche Regeln) und schickt das Ergebnis als externen Eingang.
- **Echtzeit (ST3):** Schläfer sind Server-Entitäten, solange auf ihrer Etage ein Shard läuft; Streifen laufen dann wirklich
  vorbei, andere sehen den Kampf und können helfen (Kap. 6). Sonst gilt die abstrakte Rechnung aus ST2.

### 5.6 Benachrichtigungen

Einsturz-Warnungen und „neue Etage offen“ nach Kap. 2.9; alles über Schläfer (Begegnungen, Weckrufe, Ausgeruht voll) kommt
gebündelt in der **Tageszusammenfassung**, standardmäßig aus (V-9).

---

## 6. Andere Spieler:innen

### 6.1 Was geht — je Phase

| Handlung | ST1 (offline) | ST2 (asynchron) | ST3 (Echtzeit) |
|---|---|---|---|
| Andere sehen | KI im Safe Room und als Begegnung im Schlaf | Liste, Rangliste, Ticker, Zuschauen (05 S2, Verzögerung) | in der Welt (geteilte Etage) |
| Schläfer sehen | — | — | ja, mit „Zzz“ |
| Schläfer **bewachen** | KI-Helfer:in (Kap. 5.3) | — | Wer in der Nähe steht, kämpft gegen eine kommende Streife mit; der Schläfer kämpft als KI mit |
| Schläfer **heilen** | — | — | Heilfähigkeit oder -gegenstand auf den Schläfer |
| Schläfer **wecken** | — | Freund:innen: Weckruf (1× je Tag und Paar), zugestellt in der Tageszusammenfassung | dto., plus „Kaffee hinstellen“ (+5 % Ausgeruht, 1× je Tag) |
| **Handeln** | KI-Händler:innen | Postfach mit Gegenständen und Credits (Treuhand, Kap. 9.2) | Postfach und direkter Tausch |
| Gemeinsam spielen | — | — | Koop 2–4 (07 §10.8), Bossräume je Gruppe instanziert |
| **Angreifen** | — | — | **nur in Show-Arenen, Opt-in** |

### 6.2 Kein PvP gegen Schläfer — Arenen und später „Kopfgeld“

- **Empfehlung (verbindlich bis zur Nutzerentscheidung):** Schläfer kann niemand angreifen, bestehlen oder blockieren. PvP gibt
  es nur freiwillig in **Show-Arenen** (ein Arena-Raum je Etage am ersten Safe Room, ST3): Duell 1:1 oder 2:2, ohne Verlust
  von Ausrüstung oder Stufe, mit Zuschauer:innen, Arena-Rangliste und kosmetischen Belohnungen.
- **Das mildert die Idee ab:** „ausgeliefert … andere spieler ggfs vorbei“ gilt hier für Monster und für das Pech der
  KI-Kandidat:innen, nicht für Angriffe. Die Nutzerin/der Nutzer wurde dazu gefragt und kann ein härteres Regelwerk wählen
  (F-6).
- **Offen für härteres PvP:** Die Regel steckt in einem Feld der Staffelvorlage `rules.pvp` ∈ `off` | `arena` (Standard) |
  `bounty`. Ein späteres Opt-in-Regelwerk **„Kopfgeld“** (eigene Staffelvorlage, nur Menschen, die zustimmen; PvP außerhalb von
  Safe Rooms; wer angreift, bekommt ein sichtbares Kopfgeld) ist ohne Umbau möglich — nie in öffentlichen „Mit
  Netz“-Staffeln.

### 6.3 Schutz vor Störenfrieden

- **Persönliche Beute und Fundstellen** (jede:r sieht und bekommt eigene; kein Wegschnappen), **keine Kollision** zwischen
  Spielerfiguren, **Bossräume je Gruppe** (keine Kill-Diebe), Gastauftritte nur auf Einladung.
- Postfach: Tageslimits, neue Konten erst nach 24 h Spielzeit, Meldefunktion; kein Echtgeld-Gegenwert (Kap. 10).
- Wecken und Kaffee: Begrenzung je Tag und Paar, Sperrliste.

### 6.4 Chat und Moderation (ST2/ST3)

- **Schnellsätze** (vorgefertigt, übersetzt, sicher) sind Standard und für alle unter 16 die einzige Form.
- **Freitext** ab 16 als Opt-in: Wortlisten aus `mod_filter.json` (06 §5.9), Längen- und Ratenlimit, Melden, Stummschalten,
  Blockieren; Meldungen mit Begründung und Abhilfe nach DSA **[zu prüfen]**; Chat-Protokolle 30 Tage für Moderation
  **[Speicherfrist zu prüfen]**.
- Öffentliche Namen nur als moderierte Konto-Anzeigenamen — nie Persona-Daten (08 D-10).
- Keine Sprachchats.

---

## 7. Tod und Modi

### 7.1 Mit Netz (Normal)

- **Tod** (alle Party-Einheiten K.O.): Die Regie-Sanitäter bringen die Party in den **zuletzt besuchten Safe Room dieser
  Etage** — war sie dort noch in keinem, an den **Etageneingang** (V-16); dort volle Heilung. Gebühr **−10 % Credits** (es gilt
  die Wochen-Gebühr aus Kap. 2.5: höchstens eine Gebühr je 7 Tage), weiße Weste weg. Besiegte Gruppen bleiben besiegt; ein
  Boss, gegen den man verloren hat, steht wieder mit voller Kraft da (wie nach einer Flucht, 07 §2.5), und beim nächsten
  Betreten öffnet einmal das Comeback-Fenster (06 §6 Nr. 3).
- **Einsturz:** Rettung nach Kap. 2.5.
- Es gibt **kein Game Over** und kein „Letzten Spielstand laden“ mehr (GDD §14.6 gilt nur noch Ohne Netz und für Event-Läufe;
  07 §2.6 per CR-32 h).

### 7.2 Ohne Netz (Hardcore, „ein Leben“)

- **Eigene Staffeln:** Alle Kandidat:innen einer Ohne-Netz-Staffel spielen Ohne Netz; Wechsel gibt es nicht. **Freigeschaltet
  nach der ersten Klassenwahl oder einer beendeten Staffel** (V-7), dann mit Bestätigung („Ein Leben. Ernsthaft?“).
- **Tod oder Einsturz = raus — ab Etage 2.** Sendeschluss-Bild mit Titel „Gefallen auf Etage N“ bzw. „Verschüttet auf Etage N“.
- **Studiogast:** Wer raus ist, schaut der Staffel bis zum Ende zu — offline (ST1) als Zeitraffer der Besetzung bis zum
  Finale, online (ST2+) als Zuschauer:in mit Senderwechsel (05 S2, Verzögerung), darf in Zuschauer-Abstimmungen mitwählen und
  im Staffel-Ticker mit **Schnellsätzen** kommentieren („Studiogast Jana: ‚Das hätte ich anders gemacht.‘“). Titel und
  Erinnerungskarte bleiben in der Ruhmeshalle. Eine neue Staffel kann man sofort beginnen (Kap. 2.2).

### 7.3 Übersicht der Strafen

| Ereignis | Etage 1 — Generalprobe (alle Staffeln, V-7) | Mit Netz | Ohne Netz (ab Etage 2) |
|---|---|---|---|
| Tod | Safe Room bzw. Etageneingang, keine Gebühr, Weste bleibt | zuletzt besuchter Safe Room der Etage (sonst Etageneingang), −10 % Credits, Weste weg | raus (Studiogast) |
| Einsturz | Rettung ohne Gebühr, Weste bleibt; die Etagen-Bilanz entfällt | Rettung auf die nächste Etage, −30 % Credits, −10 % Follower; Schläfer im Safe Room gratis; keine Etagen-Bilanz, Weste weg | raus (Studiogast) |
| Gebühren | keine | **höchstens eine je 7 Tage** — Rettung oder Sanitäter, was zuerst kommt | — |
| Tod als Schläfer | wie Tod | wie Tod | raus |
| Absturz / beendete App im Kampf | Autopilot entscheidet den Kampf vom Anfang an, das Ergebnis gilt | dto. | dto. |

**Warum die Generalprobe:** Der Hausmeister ist mit ≈ 20 % Niederlagen beim ersten Versuch gebaut (GDD §13, 07 §11.1).
Ohne Generalprobe verlöre jede fünfte Erstspieler:in am ersten Abend die Weste — oder Ohne Netz die Staffel.

### 7.4 Vorabendprogramm

Die leichte Einstellung (GDD §2.9: Gegnerschaden × 0,75, EP × 1,2) gibt es nur in **privaten** Staffeln; Am Stück zusätzlich
Countdown × 1,5. Online-Staffeln teilen eine Uhr und ein Regelwerk — dort gibt es sie nicht.

---

## 8. Fertigkeiten wie in WoW

### 8.1 Überblick

| Säule | Wie man sie bekommt | Kein Zufall, weil … |
|---|---|---|
| **Stufen** | EP aus Kämpfen, Bossen, Etagenabschluss, Events, Berufen | feste Tabelle, Bänder je Etage |
| **Fähigkeiten** | automatisch auf festen Stufen (Figur, ab Etage 3 Klasse) | Fähigkeitenbuch zeigt „ab Stufe X“ |
| **Talente** | je Talentreihe eins von drei, frei gewählt | feste Reihen, kein Angebot aus dem Zufall |
| **Berufe** | lernen beim Gewerke-Büro, Wert steigt durch Benutzen | Farben zeigen die Chance; Würfe nur für die Steigerung |
| **Vorleben** | einmal beim Casting | Vorsprung nach Tabelle |

### 8.2 Stufen und Aufholen

- **Höchststufe 50** (`Balance.LEVEL_CAP` 10 → 50 in Staffeln; erreicht auf Etage 16; das Format Basis endet bei Stufe 22,
  Akt 2 bei 40). Etage 17 und 18 sind die **Finalwochen**: Dort zählen Ausrüstung, Talente, Berufe und Können.
- **EP-Tabelle** `exp_table` (Stufe 1–49) als vorberechnete Ganzzahl-Tabelle in `data/party.json` (05 §3.3 Nr. 5): Stufen 1–9
  unverändert (GDD §4.3), danach dieselbe Kurve fortgesetzt (offline erzeugt), feinjustiert durch den Staffel-Harness.
- **EP-Quellen** (Anteile einer Stufe bei Gegnern auf Bandstufe, Startwerte): reguläre Gruppe 4 %, Show-Boss 15 %, Revier-Boss
  25 %, Etagenboss 50 %, Etagen-Abschluss per Treppe 50 %, Etagen-Event 5 %, Beruf (je Steigerungspunkt) 0,2 %.
  Pflichtweg ≈ 1,8 Stufen, vollständig ≈ 3 Stufen — genau ein Band.
- **Stufen-Band und Deckel:** Jede Etage hat ein Band (Tabelle Kap. 2.4). Die Stufe steigt nie über das **Bandende der Etage,
  auf der Sie stehen**. Darüber werden EP zu **„Überstunden“: 10 % der EP als Credits**.
- **Aufholjagd (V-8):** Liegt Ihre Stufe unter dem Bandanfang Ihrer Etage, zählen **alle EP doppelt**; liegt sie ein ganzes
  Band (3 Stufen) oder mehr darunter, **dreifach**. Ausgeruht zählt nicht zusätzlich: Es gilt der höhere Faktor, und der
  Ruhevorrat wird dann nicht verbraucht.
- **Regie-Crashkurs (V-8):** Bei jeder Rettung und jedem Login hebt die Regie eine Figur, die unter **Bandanfang − 2** ihrer
  Etage liegt, genau dorthin (EP auf den Stufenanfang). M.O.D. überreicht dazu das **Aufholpaket**: für jeden Ausrüstungsplatz,
  auf dem Schlechteres liegt, ein gewöhnliches Teil der Etage, dazu drei Tränke. Kein Titel, keine Quote, keine Credits — nur
  der Anschluss. Gilt für Menschen und KI gleich.
- **Gegnerfarben** (Kap. 3.4): grau 0 %, grün 50 %, gelb 100 %, orange 120 %, rot 140 % der EP.
- **Stufenaufstieg:** Werte wie GDD §4.1 (HP/MP steigen um die Differenz); Bänder ab Etage 3 heben Wachstum und Gegnerwerte
  gemeinsam (Harness).

### 8.3 Fähigkeitenbuch

- **Ein Buch je Figur** (Pausemenü „Fähigkeiten“, heute `skills_menu.gd`): je Leistenplatz (1 Haupt, 2 Schutz/Heilung,
  3 Kontrolle, 4 Fläche, SHOW) die gelernten Fähigkeiten hell, kommende gedimmt mit **„ab Stufe X“**; vor dem Recall ein Reiter
  **„Klassen-Vorschau“** mit den Fähigkeiten aller vier Klassen der Figur.
- **Die Leiste bleibt 07:** 4 Fähigkeiten + SHOW + Trank. Neue Fähigkeiten sind **Varianten** eines Platzes; die Belegung
  wählt man außerhalb des Kampfes (07 §4.1, `PartyMember.rt_loadout`). Neu Gelerntes meldet ein Banner („Neue Fähigkeit:
  Schnellbeton — im Fähigkeitenbuch auf die Leiste legen“).
- **Figurenfähigkeiten** (Stufe 1–9): die heutigen Leisten aus 07 §4.2/§4.3 unverändert.
- **Klassenfähigkeiten** (ab dem Recall): **beim Recall** die Signatur, dann auf **Stufe 12, 17, 22, 27, 32** je eine; auf
  **37, 42, 47 Rang II, III, IV** (alle Klassenfähigkeiten +10 % Kraft je Rang). Merkregel ab Stufe 12: Endet die Stufe auf
  **2 oder 7**, gibt es eine Fähigkeit (ab 37 einen Rang); endet sie auf **0 oder 5**, eine Talentreihe. Davor gelten die
  Figurenleisten (Stufe 1–9) und die Grundreihen (3/5/7/9).
- **Stand der Daten (V-16):** Die `learnset`-Listen in `classes.json` sind heute **leer**. GDD §12.2 und 02_TECH §4.4.4 nennen
  als Doku-Beispiel `skl_kai_wrecking_ball` und `skl_kai_concrete_boots` auf Stufe 11 und 13; beides ersetzt diese Tabelle
  (CR-26, CR-27). „Betonschuhe“ wird zu „Schnellbeton“, weil die Wortliste in `ip_words.gd` Schuh-Wörter in jedem Text sperrt.
- **Beispiel Abrissbirne** (`cls_kai_wrecker`, Entwurf):

| Wann | Fähigkeit | Platz | Wirkung (Startentwurf) |
|---|---|---|---|
| Recall | Abrissbirne (`skl_kai_wrecking_ball`) | 1 V | starker Einzeltreffer, 220 physisch, Bedrohung × 3 |
| Stufe 12 | Schnellbeton (`skl_kai_quick_concrete`) | 3 V | unterbricht, `sts_slow` 6 s |
| Stufe 17 | Bauzaun | 2 V | Spott + `sts_guard` 8 s auf sich |
| Stufe 22 | Presslufthammer | 4 V | Kanal 2 s, Fläche, Schock |
| Stufe 27 | Sprengung! | SHOW V | Stunt mit Fläche, Risiko wie SHOW |
| Stufe 32 | Statik-Gutachten | 2 V | −30 % erlittener Schaden 8 s |
| Stufe 37/42/47 | Rang II/III/IV | — | Klassenfähigkeiten +10 % Kraft je Rang |

Datenform: `classes.json` → `rt.bar` (dasselbe Schema wie `party.json` → `rt.bar`, 07 §4.8) und Ränge als `skill_pm` mit
Quelle `class:<id>` (CR-32 a/b: vor R4 nur Schema-Haken). 8 Klassen × 6 Fähigkeiten = 48 neue Fähigkeiten; ST1 darf
Platzhalter (Varianten vorhandener Fähigkeiten mit anderen Zahlen) nutzen.

### 8.4 Talentbaum

**Regel in einem Satz:** Auf festen Stufen öffnet eine Talentreihe mit drei Talenten; Sie nehmen eines und dürfen im Safe Room
jederzeit kostenlos umwählen.

| Reihen | Stufen | Inhalt | Anzahl |
|---|---|---|---|
| **Grundreihen** (je Figur) | 3, 5, 7, 9 | die heutigen 24 Talente (06 §2.2), je Figur vier Reihen × drei | 24 (vorhanden) |
| **Klassenreihen** (je Klasse) | 15, 25, 35, 45 | Spalte links = Spezialisierung A, Mitte = Show/Allround, rechts = Spezialisierung B | 8 × 12 = 96 |
| **Figurenreihen** (je Figur, für alle ihre Klassen) | 20, 30, 40, 50 | Angriff / Show / Schutz | 2 × 12 = 24 |

- **Talent-Show = TV-Präsentation:** Öffnet eine Reihe, zeigt das Kampfergebnis den Chip „TALENT-SHOW BEREIT“; im Safe Room
  stellt die Talent-Show (goldener Knopf, wie heute) die drei Karten der Reihe vor, M.O.D. kommentiert als Jury. Umwählen
  geht später ohne Show im **Talentbaum** (Pausemenü → Party, nur im Safe Room).
- **Kein Zufall mehr (überall, V-20):** Das Angebot „1 aus 2“ (06 §2.2) entfällt überall (V-20); Event-Läufe sind über `rules_hash`/Version gebunden. Ränge
  (`max_rank` 2) gehen in einen Wert auf (Wischtechnik STR +2 statt 2 × +1); dafür erweitert der Talent-Validator die Bereiche
  der Arten (z. B. `stat_pct` bis 100 ‰, `crit_add_pm` bis 60, `post_battle_mp_pm` bis 100) und kennt die neue Art `rt_mod`
  (Operationen aus 07 `MOD_OPS`, CR-31/32).
- **Klassenwechsel** (06 §3.6, „Umschulung“ 1× je Etage) setzt die Klassenreihen frei; die Grund- und Figurenreihen bleiben.
- **Grundreihen** (aus den vorhandenen Talenten, Werte zusammengefasst):

| Stufe | Kai: links | Kai: Mitte | Kai: rechts | Graf: links | Graf: Mitte | Graf: rechts |
|---|---|---|---|---|---|---|
| 3 | Wischtechnik (STR +2) | Nachtschicht-Kondition (HP +10 %) | Dicke Haut (DEF +2) | Mitternachtsformel (MAG +2) | Leberwurst-Diät (HP +10 %) | Hoher Kragen (RES +2) |
| 5 | Fester Griff (Krit +6 %) | Glückspfote (LCK +1, Krit +2 %) | Hausverstand (RES +1) | Nachtaktiv (MP +10 %) | Zwinger 7 überlebt (LCK +2) | Monokel-Fokus (SPD +1) |
| 7 | Erster Eindruck (Erstschlag +15 %) | Weit ausholen (Feldschlag +25 %) | Automatenkaffee (+10 % MaxMP nach Siegen) | Taktgefühl (SHOW × 1,2) | Bellen in Stereo (+25 %) | Schwer vermittelbar (Bellen −30 % Abklingzeit) |
| 9 | Bissfest (Gift × 0,75) | Kamera 3 kennt mich (Herz) | Liga-Routine (Liga: DEF +5 %) | Doppelter Unterpelz (Eis × 0,75) | Körbchen-Nickerchen (+10 % MaxMP nach Siegen) | Liga-Gelassenheit (Liga: RES +5 %) |

- **Spezialisierungen** (zwei je Klasse, Arbeitstitel; Klassennamen nach dem Polish-Pass, V-15): Abrissbirne — *Bollwerk*
  (Tank) / *Abrissunternehmen* (Schaden); Gleisläufer:in — *Schnellzug* (Tempo) / *Weichensteller:in* (Kontrolle);
  Schrott-Tüftler:in — *Bastelbude* (Gegenstände) / *Kurzschluss* (Elemente); Showrunner:in — *Publikumsmagnet* (Hype) /
  *Stuntdouble* (Stunts); Erzmagister — *Feuerwerk* (Feuer) / *Gewitterzelle* (Schock); Medicus honoris causa —
  *Notaufnahme* (Einzelheilung) / *Kurkonzert* (Flächenheilung); Fluchgraf — *Fluchkanzlei* (Schwächen) / *Spukschloss*
  (Dauerschaden); Zeremonienmeister — *Protokoll* (Verstärkung; vormals „Primadonna“) / *Mitternachtsgala* (Show). Wer
  überwiegend links oder rechts wählt, bekommt die Spezialisierung als Plakette — es gibt **keine** Pflicht und keine
  gesperrten Talente.
- **Beispiel Klassenreihen Abrissbirne** (Wirkungen nur über vorhandene Talent-Arten und `RtMods`-Operationen, 07 §9.5):

| Stufe | links: Bollwerk | Mitte: Show | rechts: Abrissunternehmen |
|---|---|---|---|
| 15 | Fugenkitt: Spott-Abklingzeit −20 % (`skill_pm` `cooldown`) | Baustellenradio: gelungene SHOW gibt 10 MP (`on show_success`) | Vorschlaghammer: Wuchtschlag und Abrissbirne +15 % Kraft (`skill_pm` `power`) |
| 25 | Bauzaun-Profi: erster erlittener Treffer je Kampf −30 % (`first_hit_taken_pm`) | Richtfest: jeder besiegte Gegner heilt 3 % HP (`on kill`) | Sprengsatz: Rundumfeger +20 % Kraft |
| 35 | Statiker:in: DEF +5 % (`stat_pct`) | Bauabnahme: Unterbrechen gibt 5 MP (`on interrupt`) | Akkord: alle Abklingzeiten −10 % (`skill_pm` `*`) |
| 45 | Tragende Wand: −10 % erlittener Schaden (`dmg_taken_pm` 900) | Publikumsliebling: SHOW-Erfolg × 1,1 (`stunt_window_pm`) | Abrissbirne XXL: Signatur +25 % Kraft |

- **Deckel (Test, Startwerte):** Summe aller Talentboni je Kampfwert bei Stufe 50 ≤ +30 %, Krit ≤ +120 ‰, Schaden aus
  `skill_pm`/`dmg_dealt_pm` ≤ +40 %, erlittener Schaden ≥ −25 % — für **jede** Wahlfolge (erschöpfend wie `test_06b_balance`;
  bei 12 Reihen × 3 = 531 441 Folgen je Klasse, in CI auf die Spitzen je Reihe reduziert). Bei Stufe 10 gilt weiter der
  06-Deckel (+15 %).

### 8.5 Berufe

**Regel in einem Satz:** Zwei Hauptberufe nach Wahl, dazu Kochen und Erste Hilfe für alle; der Wert steigt, wenn Sie den Beruf
benutzen — die Farbe zeigt, wie wahrscheinlich.

| Beruf | ID | Art | Was man tut | Was dabei herauskommt |
|---|---|---|---|---|
| **Schrottsammeln** | `prf_scrap` | Sammeln | Schrotthaufen, Kabelschächte, Automatenwracks durchsuchen (2 s) | Metall, Kabel, Bauteile |
| **Pilzkunde** | `prf_shrooms` | Sammeln | Pilzbeete, Moos, Kanalkresse ernten (2 s; führt der Graf, „erschnüffelt“ er sie) | Pilze, Kräuter |
| **Ausschlachten** | `prf_salvage` | Sammeln | automatisch nach jedem Sieg (keine eigene Handlung) | Federn, Panzerplatten, Stoffreste, Schleim |
| **Requisite** | `prf_props` | Handwerk | Waffen und Accessoires bauen und aufwerten; Gadgets (Nebelmaschine, Megafon) | aus Schrott |
| **Labor** | `prf_lab` | Handwerk | Tränke, Elixiere, Sprays und Würfe (Kältespray, Grillanzünder-Cocktail) | aus Pilzen und Schleim |
| **Kostüm** | `prf_costume` | Handwerk | Rüstungen (Kleidung für Kai, Pullover und Umhänge für den Grafen) | aus Stoff und Federn |
| **Kochen** | `prf_cooking` | Nebenberuf | Essen: Heilung außerhalb des Kampfes + **„Satt“** (+5 % Max-HP und -MP, 30 Spielminuten) | aus Zutaten (Beute, Pilze, Automat) |
| **Erste Hilfe** | `prf_first_aid` | Nebenberuf | Pflaster, Verbände, Gegengift (Trank-Platz, 07 §4.5) | aus Stoffresten |

- **IDs (V-16):** `prf_` statt des in 06 §7 reservierten `job_` — so verwechselt niemand Berufe mit dem Casting-Platzhalter
  `{job}` (08 §4.4). Der Command heißt `prof`, die Datei `professions.json`.
- **Wer:** Berufe hat nur die **Kandidat:in** (Party-ID `kai`) — „Der Graf lässt arbeiten.“ Sammeln geht, egal wer führt.
- **Ab Etage 2:** Im ersten Safe Room öffnet das **Gewerke-Büro** (Safe-Room-Menü „Automat | Berufe“, Kap. 9.1). Dort lernt,
  verlernt (Wert weg) und steigert man Rang; Hergestelltes entsteht nur im Safe Room.
- **Wert 1–300**, vier **Ränge**: Praktikum bis 75 (sofort), Assistenz bis 150 (ab Stufe 13), Leitung bis 225 (ab Stufe 25),
  Legende bis 300 (ab Stufe 37); Rangaufstieg kostet Credits.
- **Güte (V-6):** Material, Fundstellen und Rezepte haben eine Güte 1–6, eine je Kulisse: Güte 1 Etage 1–3 (Wert 1–50),
  2 Etage 4–6 (51–100), 3 Etage 7–9 (101–150), 4 Etage 10–12 (151–200), 5 Etage 13–15 (201–250), 6 Etage 16–18 (251–300).
  Jede Fundstelle und jedes Rezept trägt seine Anforderung R.
- **Farben** (Rezept oder Fundstelle mit Anforderung R): **orange** R … R+24 (Steigerung sicher), **gelb** R+25 … R+49 (75 %),
  **grün** R+50 … R+74 (25 %), **grau** ab R+75 (keine). Steigerung +1, Würfe aus `SeedUtil.derive(seed, "prof", n)`.
- **Rezepte:** beim Gewerke-Büro (Credits), als Beute (Bosse, Kisten) und das **Hobby-Rezept** gratis (Kap. 8.6). Etwa 3–5
  Rezepte je Beruf und Güte, aus Vorlagen abgeleitet (Pflaster Güte 1 … 6); ST1 baut Güte 1–3.
- **Wirtschaft:** Der Automat kauft Hergestelltes an (Credits-Quelle mit Tagesdeckel, der sich bis 4 Tage ansammelt),
  Händler:innen der KI ebenso; Meisterstücke am Ende jeder Güte sind die beste Ausrüstung außerhalb von Bossbeute.
  Hergestelltes ist **staffelgebunden** und kann nicht in Echtgeld getauscht werden (Kap. 10).

### 8.6 Vorleben-Vorsprung

**Regel (V-19):** Das Vorleben bringt **+50 in einem Beruf** (Tabelle). Kanon-Kai („Rest automatisch“), die **Status-Kacheln**
(Schule, Ausbildung & Studium · Selbstständig · Ruhestand · Familie & Sorgearbeit · Neuorientierung), Allrounder:in und
„Anderes …“ ohne Treffer wählen den Beruf beim ersten Besuch im Gewerke-Büro frei — so wird niemand über seinen Status in eine
Schublade gesteckt (08 H-2). Das **Hobby** schenkt das **Hobby-Rezept** seines Berufs (zweite Tabelle; sonst kostet es beim
Gewerke-Büro Credits). So bekommt jede:r dasselbe: **+50 und ein Rezept**. Der Vorsprung gilt, sobald der Beruf gelernt ist
(Nebenberufe ab Etage 2 automatisch); bis zum Ende des Praktikums (75) bleiben 25 Punkte zum Steigern. Das Gewerke-Büro zeigt
den Beruf mit Vorsprung oben („Ihr Vorleben: Requisite +50“).

| Vorleben (`org_*`) | Beruf | Zeile (Beispiel, Humor-Leitplanken 08 §4.9) |
|---|---|---|
| Tierpflege (`org_animals`) | Erste Hilfe | „Sie haben schon Pfoten verbunden. Jetzt sind es eben Ihre eigenen.“ |
| Pflege & Medizin (`org_care`) | Erste Hilfe | „Wundversorgung ist Ihr Alltag.“ |
| Bildung & Erziehung (`org_teach`) | Erste Hilfe | „Erste-Hilfe-Kurs: im Job Pflicht, hier Gold wert.“ |
| Küche & Gastronomie (`org_kitchen`) | Kochen | „Sie können kochen. Wirklich kochen.“ |
| Handwerk & Technik (`org_craft`) | Requisite | „Was Sie bauen, hält.“ |
| Medien & Marketing (`org_media`) | Requisite | „Sie wissen, was vor der Kamera gut aussieht.“ |
| Produktion & Industrie (`org_industry`) | Requisite | „Metall biegen ist Ihr Handwerk.“ |
| Büro, Finanzen & Verwaltung (`org_office`) | Labor | „Formeln sind Formeln.“ |
| Forschung & Labor (`org_science`) | Labor | „Sie wissen, was man nicht mischt.“ |
| Kunst, Musik & Bühne (`org_stage`) | Kostüm | „Die Garderobe ist Ihr zweites Zuhause.“ |
| Recht & Justiz (`org_law`) | Kostüm | „Sie tragen beruflich Robe.“ |
| Friseur & Kosmetik (`org_beauty`) | Kostüm | „Maske und Frisur — die halbe Kostümabteilung.“ |
| IT & Digitales (`org_it`) | Schrottsammeln | „Sie erkennen jede brauchbare Platine.“ |
| Verkehr & Logistik (`org_transport`) | Schrottsammeln | „Sie kennen jeden Tunnel und jedes Ersatzteillager.“ |
| Reinigung & Hausmeisterei (`org_cleaning`) | Schrottsammeln | „Sie kennen jeden Keller — und was darin liegt.“ |
| Natur & Landwirtschaft (`org_nature`) | Pilzkunde | „Sie kennen jedes Gewächs. Auch die leuchtenden.“ |
| Handel & Verkauf (`org_sales`) | Ausschlachten | „Sie sehen sofort, was etwas wert ist.“ |
| Sicherheit & Rettung (`org_rescue`) | Ausschlachten | „Rettungsschere und Brechstange sind Ihnen vertraut.“ |
| Status-Kacheln (`org_school`, `org_selfemployed`, `org_retired`, `org_family`, `org_reorient`), Allrounder:in (`org_allround`), Kanon-Kai | frei beim ersten Gewerke-Büro | „Suchen Sie sich etwas aus. Talent ist hier Verhandlungssache.“ |

| Hobby (`hob_*`) | Hobby-Rezept aus | | Hobby | Hobby-Rezept aus |
|---|---|---|---|---|
| Kochen & Backen | Kochen | | Tanzen | Kostüm |
| Tiere — **Kanon** | Kochen („Futter zubereiten zählt hier als Kochen.“) | | Fotografieren & Filmen | Requisite |
| Videospiele | Schrottsammeln („Sie looten alles, was glitzert.“) | | Social Media | Kostüm |
| Sport & Fitness | Erste Hilfe | | Wandern & Draußen | Pilzkunde |
| Musik | Requisite | | Ehrenamt | Erste Hilfe |
| Lesen | Labor | | Brett- & Kartenspiele | Labor („Rezepte sind auch nur Regeln.“) |
| Garten & Pflanzen | Pilzkunde | | Krimis & Rätsel | Ausschlachten („Sie wissen, wo man sucht.“) |
| Heimwerken & Basteln | Requisite | | Technik & Elektronik | Schrottsammeln |
| Reisen | Kostüm („Drei Outfits aus einem Handgepäck.“) | | | |

Jeder Beruf hat genau ein Hobby-Rezept (`hobby_recipe` in `professions.json`, Güte 1, z. B. Kochen: „Kantinen-Eintopf à la
Zwinger 7“). **Kanon-Kai** bekommt das Kochen-Rezept (Hobby Tiere) und wählt den +50-Beruf frei; M.O.D. empfiehlt Erste Hilfe
(passend zu Kais Fähigkeit „Erste Hilfe (Tierarzt-Edition)“). **Fairness:** Jede:r bekommt denselben Vorsprung, nur in einem
anderen Beruf; Event-Läufe haben weiter keine Persona (08 C-13).

### 8.7 Migration

| Heute | Neu | Regel |
|---|---|---|
| Talent-Show „1 aus 2“ auf ungeraden Stufen ab 3 (06 §2.2, Code 06-B) | in Staffeln Grundreihen auf 3/5/7/9 (je 1 aus 3) | Alte Wahlen werden zurückgesetzt, jede erreichte Reihe ist offen; M.O.D.: „Neuer Talentbaum — bitte neu wählen. Kostenlos. Diesmal.“ Gilt auch ohne Staffel (V-20). |
| Talent-Reset per Gegenstand (06 §3.6) | Umwählen im Safe Room, kostenlos | Gegenstand „Neuanfang-Vertrag“ entfällt in Staffeln |
| Starttalente `tal_org_*`, 1 aus 2, einmal tauschbar (08 §3; Kern-Pfad seit K0) | Vorleben-Vorsprung (8.6) | **CR-33** — vor 08 K1 entscheiden, sonst baut K1 Inhalte, die sofort wieder gehen; der ruhende K0-Pfad geht in ST0 (hash-neutral, weil `talent` seit K1 leer ist) |
| Command `persona` v1 (`talent`, `bias`, `swap`) | v2 `{"t": "persona", "v": 2, "prof": "prf_first_aid", "recipe": "rcp_cooking_hobby", "bias": [...]}` | `prof` ist ein Beruf aus `professions.json` oder leer (= freie Wahl beim Gewerke-Büro, Command `prof` `op: "head"`), `recipe` ein `hobby_recipe` oder leer; keine Hobby- oder Vorleben-ID im Command (08 D-2); v1 bleibt für alte Logs lesbar; Event-Lauf → `event_run` (wie 08) |
| `Balance.LEVEL_CAP = 10`, EP-Formel | in Staffeln 50, Tabelle | Läufe ohne Staffel und Spielstände unter Stufe 10 unverändert |
| Kampagnen-Spielstand (Etage, `time_left_ticks`) | private Staffel Am Stück | beim Laden ab dem `SIM_VERSION`-Sprung (Kap. 11.1): Countdown der Etage = Restzeit, neuer Anker; Speichern wird Dauerspeicherstand mit Journal |

---

## 9. Technik

### 9.1 ST1: Offline-Staffel (ohne Server)

**Schalter (V-4):** Jede Regel dieses Dokuments hängt an `state.season != null`. Läufe ohne Staffel — SHOWRUN-Event-Läufe,
alte Spielstände bis zur Migration, alle heutigen Golden-Hashes — bleiben bitgleich und behalten ihre Regeln (Countdown mit
Gnadenfrist, Game Over, Stufe ≤ 10). Einzige Ausnahme: Mit ST1-D ersetzt der Talentbaum „1 aus 2“ auch dort (V-20, eigener
Versionssprung der Event-Regeln).

**Neue Module** (`core/season/`, rein, `RefCounted`, ohne Szenen und Autoloads, Ganzzahlen, Zufall nur `SeedUtil`):

| Datei | Klasse | Aufgabe |
|---|---|---|
| `season_def.gd` | `SeasonDef` | Staffelvorlage aus `data/seasons.json` (`ssn_`: Format, Dauern, Besetzung, Mindestzahlen, `rules.pvp`, Sendezeit) |
| `season_state.gd` | `SeasonState` | im `GameState`: Vorlage, Format, Nummer, Tempo, Modus, Staffel-Uhr `utc`, `collapse_utc`, letzte gesehene Uhrzeit (nur offline, nicht gehasht), Pausen, erledigte Einstürze, Rettungen und letzte Gebühr, Tode, Weste, raus, Erstbesteigungen, Schlaf-Taktik, Programmpunkte |
| `season_clock.gd` | `SeasonClock` | rein: Tag 0, Einsturztermine (UTC), Etage auf Sendung, Vorlauf-Grenze ab Etage 4, Restzeit, Pausen, Am-Stück-Countdowns je Etage |
| `season_rules.gd` | `SeasonRules` | Treppenregel, Einsturz, Rettung (Wochen-Gebühr, Gratis-Tragen), Generalprobe, Tod, Ohne-Netz-Freischaltung, Tagesprogramm, Tägliches (4 Tage), Staffel-Quote, Titel |
| `level_band.gd` | `LevelBand` | Band, Deckel, Aufholjagd (× 2/× 3), Crashkurs, Ausgeruht, Gegnerfarben, EP-Faktoren |
| `cast_sim.gd`, `cast_member.gd`, `cast_event.gd` | `CastSim`, … | Populationsmodell (Kalender oder „folgt“), Ereignisse, Rangliste, „übernommen“ |
| `sleep_resolver.gd` | `SleepResolver` | `away`: Reihenfolge Kap. 5.5, Begegnungen (Streifen und KI) über `RtSim` headless (Autopilot) |

Dazu `core/live/command_journal.gd` (`CommandJournal`, Zeilen schreiben und lesen, offenen Kampf finden),
`core/progression/professions.gd` (`Professions`), `talent_tree.gd` (`TalentTree`, ersetzt in Staffeln die Angebotslogik in
`talents.gd`), `ability_book.gd` (`AbilityBook`, Leisten aus `party.json` + `classes.json`), `core/dungeon/zone_generator.gd`
(Kap. 3.6), Defs in `core/data/defs/` (`season_def`, `profession_def`, `recipe_def`, `theme_def`) und Validatoren in
`core/data/validators/{seasons,professions,cast,themes}.gd`.

**Daten:** `seasons.json` (`ssn_basis`, `ssn_akt2`, `ssn_akt3`, `ssn_dev`), `professions.json` (`prf_` Berufe, `rcp_` Rezepte
mit `hobby_recipe`, `mat_` Material, `nod_` Fundstellen), `cast.json` (Namen, Profile, Zeilen-Tags), `themes.json` (`thm_` mit
Programmpunkt-Pool), `floors.json` Etagen 3–18, `talents.json` (Felder `row`, `col`, `tree`, `spec`), `classes.json` (`rt.bar`,
Ränge), `party.json` (`exp_table`), `rt_balance.json` (`enemy_level_pm`). `ssn_` ist seit 06 §7 reserviert; `prf_` ist neu,
das dort reservierte `job_` wird frei (CR-27, CR-31).

**Staffel-Uhr im Kern:**

- **Am Stück:** kein Kalender. `FloorRun.time_left_ticks` ist der Countdown der Etage (Spalte „Am Stück“ × 1 800 Ticks je
  Minute), Start beim Betreten (Etage 1 nach dem Tutorial-Kampf) — wie heute; `TIMER_GRACE_ON_LOAD` (`Save.GRACE_SECONDS`) gilt
  in Staffeln nicht. Keine neuen Commands außer dem Wechsel `season` `op: "tempo"`.
- **Kalender:** Die Uhr wird **von außen gestellt** — der Client zeichnet je **60 s** Wanduhrzeit `{"t": "clock", "sec": 60}`
  auf (Zeitraffer: Vielfaches), nach Abwesenheit `{"t": "away", "sec": N}`. Der Kern wendet beide nur außerhalb des Kampfes
  an einer Tick-Grenze an; Kampfzeit reicht der Client nach `end_combat` gesammelt nach — die Uhr läuft also weiter, und ein
  fälliger Einsturz wartet von selbst bis zum Kampfende (dann 2 min, Kap. 2.5). RunSim-Ticks stellen die Kalender-Uhr nicht.
- **Termine (V-17):** `season` trägt `day0_utc` und `collapse_utc` (alle Einsturztermine, beim Start aus der Sendezeit in
  Ortszeit berechnet); die Staffel-Uhr `utc` wächst nur über `clock`/`away`; `op: "pause"` verschiebt alle offenen Termine.
- **Neue Commands** (alle über aufzeichnende `Game`-Methoden, Prüfung in `RunRules`, 02_TECH §3.4):

| `t` | Form | Bemerkung |
|---|---|---|
| `season` | `{"t": "season", "v": 1, "op": "start", "def", "format", "tempo", "mode", "number", "day0_utc", "collapse_utc", "cast"}`; weitere `op`: `"tempo"` (Kalender → Am Stück, privat), `"pause"` (`sec`, `why`: `user` höchstens 14 Tage je Staffel \| `clamp` nach einem Uhrsprung), `"leave"` (Aussteigen) | `start` einmal vor `floor`/`hero`/`persona` |
| `clock` | `{"t": "clock", "sec"}` | Kalender; ab ST2 Server-Ticket mit `sig` und externen Eingängen (Kap. 9.2) |
| `away` | `{"t": "away", "sec"}` | Kalender; Login nach Abwesenheit, offline höchstens 7 Tage (Rest als `pause` `clamp`) |
| `sleep` | `{"t": "sleep", "tactic"}` | Ausloggen; `careful` \| `support` \| `attack` (07 §5.2) |
| `talent` v2 | `{"t": "talent", "v": 2, "member", "row", "id"}` | in Staffeln statt der 06-B-Form; nur im Safe Room |
| `prof` | `{"t": "prof", "op": "learn" \| "unlearn" \| "rank" \| "head", "id"}` | Gewerke-Büro; `head` = freie Wahl des +50-Berufs (einmal) |
| `gather` | `{"t": "gather", "node"}` | Fundstelle (Szenenlogik Grad A wie `secret`, 06 §2.7) |
| `craft` | `{"t": "craft", "recipe", "n"}` | nur im Safe Room |
| `cast` | `{"t": "cast", "op": "hire" \| "trade" \| "help", "who", "item"?}` | KI-Kandidat:innen |
| `persona` v2 | Kap. 8.7 | CR-33 |

- **Zustand und Hash:** `GameState.season` (alles außer der lokalen Uhrzeit), `PartyMember.rested`, `professions`,
  `prof_head`, Talentreihen, Besetzung (`CastSim`-Zustand) gehen in `StateHash.of` — additiv, nur wenn vom Standard abweichend
  (wie 07 §10.4), damit alte Golden-Hashes gelten.
- **Speichern und Journal (V-3):** Der Spielstand wird (atomar wie heute) nach jedem Kampf, bei jedem Safe-Room-Besuch, beim
  Etagenwechsel, beim Ausloggen und spätestens alle 60 s geschrieben. Dazwischen hält ein **append-only Command-Journal** je
  Platz (`user://saves/slot_N.journal`) jeden aufgezeichneten Command: eine Zeile, geschrieben und geflusht, **bevor** der
  Command wirkt; der nächste Spielstand leert das Journal. Ein Kampf schreibt seinen `encounter`-Eintrag („Begegnung
  gestartet“) als Erstes. Beim Start: Spielstand laden, Journal nachspielen (eine abgerissene letzte Zeile wird verworfen);
  endet es in einem offenen Kampf, **entscheidet der Autopilot den Kampf vom Anfang an** (gleicher Seed, beide Einheiten KI,
  die bis dahin gemachten Eingaben zählen nicht) — wer die App im Kampf beendet, gewinnt nichts und verliert nichts außer der
  eigenen Steuerung. Kein „Speichern“-Knopf mehr; das Safe-Room-Menü wird zu „Lootboxen · Automat | Berufe · Figur wechseln |
  Ausrüstung · Mopsula · Ausloggen | Weiter“ (fünf Zeilen, GDD §14.7; „Berufe“ ab Etage 2).
- **Replay:** Run-Log je Sitzung, verankert am Spielstand (`start_state`/`start_hash`, 05/08 wie heute); `clock`, `away` und
  `sleep` sind Einträge des Logs. Ein ganzer Staffel-Replay ist die Kette der Sitzungs-Logs.
- **Versionen (V-1, V-4):** Der `season`-Eintrag trägt `sim_version` und `data_hash`. Privat übernimmt ein App-Update eine
  laufende Staffel beim nächsten Etagenwechsel (neuer Anker). Online gilt: Regel- und Datenänderungen erscheinen nur zu festen
  **Sendeterminen** (Releases, Takt **[festzulegen]**); öffentliche Staffeln starten in **Wellen** nach jedem Sendetermin und
  nur so, dass sie vor dem nächsten enden; dazwischen gibt es nur **hash-neutrale** Patches — die CI spielt die gespeicherten
  Logs jeder live laufenden Version nach und verlangt gleiche Hashes. **Rückfall**, falls eine Staffel doch über einen
  Sendetermin läuft: Datenstand je Staffel (Schnappschuss zum `data_hash`) und archivierte Verifier-Builds je `sim_version`
  (05 §4.3); Freunde-Staffeln wechseln dann am nächsten Einsturz gemeinsam auf die neue Version (neuer Anker). Logs einer
  anderen Version spielt der Kern wie seit K0 nicht ab, sondern zeigt sie als „ältere Version“ (`RunSim.version_status`).
  `SIM_VERSION` steigt erst, wenn die Staffel Standard wird (Kap. 11.1).
- **Ausloggen-Ablauf:** Pausemenü „Ausloggen“ → Dialog mit Taktik (Kap. 5.1) → `sleep` → Speichern → Titel. Login: `away` →
  Login-Bilanz → Welt.

### 9.2 ST2: Staffel-Server (asynchron)

```text
 Client (Godot)  ──HTTPS/WSS──►  Staffel-Dienst  ──► Postgres (Konten-Pseudonyme, Staffeln, Besetzung, Postfach, Ranglisten)
   spielt lokal (Grad A),          │  Lobby, Start, Uhr-Tickets, kanonischer Zustand je Figur
   streamt Command-Pakete          ├─► Godot headless `--role=season`: rechnet Pakete nach, CastSim, Schläfer, Einstürze
                                   ├─► Verifier-Pool (05 S1): prüft Sitzungs-Logs, schreibt Ranglisten
                                   ├─► Nakama (05 §3.8): Plattform-Login, Freunde, Bestenlisten
                                   └─► Zuschauer-Pipeline (05 §5, S2): Senderwechsel je Staffel, 30 s Verzögerung, Fog-of-War
```

- **Ein Schreiber (V-12):** Den kanonischen Zustand jeder Figur hält der Staffel-Dienst. Der Client spielt lokal und streamt
  seine Commands in Paketen (spätestens alle 10 s und an jeder Grenze: Kampfende, Etagenwechsel, Ausloggen); der Dienst rechnet
  jedes Paket nach und bestätigt den Hash. Was der Server erzeugt — Uhr, Einsturz, Besetzung und Eilmeldungen,
  Schläfer-Begegnungen, Postfach —, reist als **aufgezeichneter externer Eingang** mit dem nächsten Uhr-Ticket
  (`{sec, season, seq, sig, inputs}`) und gilt an dessen Tick-Grenze (wie ein Geschenk, 05 §6.5). Weicht ein Hash ab, holt
  der Client den Stand per Resync (05 §3.6: Schnappschuss + Log-Ende). Der Verifier lehnt Logs mit fremden oder fehlenden
  Tickets ab.
- **Verbindung weg:** 120 s Gnadenfrist (`reconnect_grace_sec`, 05 §3.6) — ein Tunnel ist kein Ausloggen; die Figur steht
  still (im Kampf: Autopilot), danach schläft sie mit der zuletzt gewählten Taktik. Online-Staffeln brauchen eine Verbindung.
- **Postfach/Tausch als Treuhand:** Wer etwas verschickt, gibt es mit einem aufgezeichneten Command ab; der Server bucht es in
  eine Treuhand und liefert es als externen Eingang — kein Duplizieren, nachrechenbar.
- **Ranglisten:** pro Staffel und je Staffelart, „plausibilitätsgeprüft“, bis Grad B kommt (05 §3.3); Ranglisten-Titel erst
  nach der Prüfung aller Sitzungen (Kap. 2.7).
- **Sponsor-Fenster und Live-Modus:** Kap. 10.

### 9.3 ST3: Echtzeit-Präsenz

- **Shards nur bei Menschen (V-13):** Je Staffel und Etage läuft ein Shard **nur, solange mindestens ein Mensch auf dieser
  Etage eingeloggt ist** (bis 24 Menschen je Shard; Freund:innen und Gruppen landen im selben). Ohne Menschen rechnet der
  Staffel-Dienst alles abstrakt wie in ST2 (Besetzung, Schläfer-Begegnungen, Einstürze). KI-Kandidat:innen werden nur in der
  Nähe von Menschen verkörpert, Schläfer nur, solange ihr Shard läuft. Übergaben abstrakt ↔ Shard geschehen an Tick-Grenzen
  und ändern keinen Hash.
- **Server-Sim:** Godot headless `--role=shard` mit `RunSim` + Erkundung **Grad B** (`core/dungeon/explore_sim.gd`, 05 §3.3) +
  `RtSim` mit `move_input` (07 §10.8). Interessenradius 40 m, 15-Hz-Schnappschüsse (05 §3.5).
- **Koop 2–4** nach 07 §10.8; Bossräume und Arenen je Gruppe instanziert; Schläfer und Streifen sind Shard-Entitäten.
- **Arenen:** Party gegen Party in `RtSim` (Änderungsantrag an 07 zur gegebenen Zeit: zweite Spieler-Seite).
- **Transport** wie 05 §4.1: zuverlässig über WebSocket/TLS (Befehle, Ereignisse, Postfach), unzuverlässig über ENet bzw.
  WebRTC (Eingaben, Schnappschüsse); Wiederverbinden nach 05 §3.6 — während der 120 s kämpft die Figur als KI weiter.
- **Persistenz:** Shards halten nur Laufzeit; Spielstände, Schläfer-Positionen und Postfach liegen im Staffel-Dienst
  (Postgres), Run-Logs im Objektspeicher (05 §5.5).

### 9.4 Anti-Cheat

| Phase | Risiko | Maßnahme |
|---|---|---|
| ST1 | Gerätezeit verstellen | monotone Uhr; Vorspulen verkürzt nur die eigene Etage; Sprünge über 7 Tage mit Rückfrage gekappt; Rückspulen friert ein |
| ST1 | App im Kampf beenden, um ihn zu wiederholen | Journal: der Kampf wird beim nächsten Start vom Anfang an per Autopilot entschieden |
| ST2 | manipulierte Sitzungs-Logs | ein Schreiber: der Server rechnet jedes Paket nach; signierte Uhr-Tickets; Ranglisten nur nach Prüfung |
| ST2 | Duplizieren über das Postfach | Treuhand, Abgabe als Command, Zustellung als externer Eingang |
| ST2/ST3 | Bots, Echtgeldhandel | Tageslimits, Wartezeit für neue Konten, Melden; kein Auszahlungsweg (05 L11) |
| ST3 | Bewegung, Treffer | Server-Autorität Grad B, Plausibilität, Lag-Ausgleich (07 §10.8) |

### 9.5 Datenschutz (DSGVO)

- **Persona bleibt lokal** (08 P-1, D-2): Server sehen nur Katalog-IDs, die im Spiel wirken (Vorsprung-Beruf, Hobby-Rezept,
  `bias`), nie Name, Vorleben-Text oder Hobby. Andere sehen **nie** Ihre Berufswerte — nur, was Sie herstellen oder anbieten.
- **Konto:** Plattform-Login, pseudonyme Konto-ID, moderierter Anzeigename; Staffel-Daten unter dem Pseudonym; Löschung des
  Kontos lässt laufende Figuren von der KI übernehmen („übernommen“) und anonymisiert die Ruhmeshalle („ehemalige:r
  Kandidat:in“) **[zu prüfen]**.
- **Benachrichtigungen** nur mit Einwilligung (Kap. 2.9), Push-Token getrennt vom Spielzustand; die `.ics`-Datei entsteht
  lokal und enthält nur Etagen und Termine.
- **Chat und Meldungen:** Speicherfrist, Zweck, Rechtsgrundlage in der Datenschutzerklärung **[zu prüfen]**; Minderjährige nur
  mit Schnellsätzen (Kap. 6.4).
- Verarbeitungsverzeichnis, Löschkonzept und Datenschutz-Folgenabschätzung vor dem ST2-Außentest **[zu prüfen]**.

### 9.6 Kosten **[Schätzung, Preise zu prüfen]**

| Posten | Annahme | Größenordnung |
|---|---|---|
| ST1 | offline | 0 € Betrieb |
| ST2 Staffel-Dienst + Postgres + Nakama | 1 000–5 000 täglich Spielende | 100–300 €/Monat (05 §3.9: S1-Backend 50–200 €) |
| ST2 Nachrechnen (ein Schreiber) | jede Sitzung einmal, ≈ 20 s CPU → 5 000 Sitzungen ≈ 28 CPU-h/Tag, abends Spitzen × 3 | ≈ 2–4 vCPU Dauerlast, Spitze 6–12 vCPU **[zu messen]** |
| ST2 Besetzungs-Sim | 99 KI × 24 Schritte/Tag je Staffel | vernachlässigbar |
| ST3 Shards (V-13) | Shard nur mit Menschen auf der Etage. Annahme: öffentliche Staffel ≈ 40 Menschen, abends ≈ 25 % gleichzeitig = 10, auf 2 Etagen → ≈ 5 Menschen je Shard; 1 000 gleichzeitige Menschen ≈ 200 Shards; 1–3 ms je Tick bei 30 Hz **[zu messen]** | ≈ 10–25 vCPU und 20–40 GB RAM (ein Prozess je Shard; mehrere Shards je Prozess sparen Speicher) ≈ 250–700 €/Monat (Budget-Hoster) **[zu prüfen]**, plus Verkehr — je weniger Menschen je Shard, desto teurer je Mensch |
| Moderation | ab ST2 Freitext | Personal oder Dienstleister — der größere Posten **[zu prüfen]** |

---

## 10. Live-Modus, Show und Geld im Staffel-Kontext

1. **Die Regeln aus 05/06 gelten unverändert:** Echtgeld von Zuschauer:innen nur an den Betreiber (L11), Hilfe nur in
   Sponsor-Fenstern (L16, 05 §6.13), Caps und Pity (L2/L4), Altersgrenze (L6), Geo-Positivliste (L7), Pur-Liga ohne Geschenke
   (L5), keine Echtgeld-Zufallsinhalte für Spieler:innen (Brief Kap. 5).
2. **Format nach Kauf, nie gemischt — und in der Staffel nichts käuflich (V-14):** Das Grundspiel bringt Basis-Staffeln
   (6 Etagen, ≈ 3,5 Wochen), die Erweiterungen Akt 2 und Akt 3 bringen 12 und 18 Etagen (bis 12 Wochen); Freunde- und
   öffentliche Staffeln stellen nur Menschen mit diesem Format zusammen. Geld berührt die Staffel nur beim Kauf vorher, nie
   darin: keine Rettung, kein Leben, keine EP, kein Ausgeruht, kein Vorsprung, kein früherer Abstieg, kein Platz.
3. **Staffeln sind standardmäßig ohne Geschenke:** Keine Staffel nimmt Zuschauer-Geschenke an, außer **Show-Staffeln**
   (Opt-in bei der Anlage, frühestens mit 05 S3 und nach Rechtsprüfung): Sie nehmen sie in Sponsor-Fenstern nach 05/06 an,
   Geld nur an den Betreiber; Figuren mit bezahlten Geschenken tragen „gesponsert“ und erhalten nur die Teilnahme-Plakette
   (05 §1.6).
4. **Lauf-Bindung (L3) in der Staffel = Etagen-Bindung:** Geschenk-Inhalte wirken sofort oder verfallen mit dem Einsturz bzw.
   Abstieg der Etage; sie lassen sich weder verschicken, herstellen noch verkaufen.
5. **Fenster nur, wenn jemand spielt:** Schläfer bekommen keine Fenster und keine Geschenke; im Kampf öffnet keines (07 §2.10).
6. **Zuschauen und M.O.D. live:** Senderwechsel zwischen Kandidat:innen einer Staffel (05 S2), 30 s Verzögerung,
   Fog-of-War; Studiogäste (Kap. 7.2) sind privilegierte Zuschauer:innen mit Schnellsätzen. M.O.D. live (06 §5) bleibt
   optional; Eilmeldungen sind geschriebene Zeilen, die KI liefert höchstens Varianten.
7. **Der Kalender ist eine Wartezeit — ehrlich gesagt (V-9):** Er bremst Schnelle bewusst, weil eine Staffel ein gemeinsamer
   Rhythmus ist. 04 §6.2 Nr. 3 schließt Wartezeit-Mechaniken aus; gemeint sind solche, die Warten verkaufen (Energie,
   Freikaufen). Dieser Kalender verkauft nichts: Nichts verkürzt ihn gegen Geld, Tägliches verfällt nicht (4 Tage),
   Programmpunkte bleiben bis zum Einsturz, privat gibt es „Am Stück“ und die Sendepause, online das Gratis-Tragen, die
   Wochen-Gebühr und den Crashkurs. Weil das eine Auslegung ist, schreibt CR-29 sie ausdrücklich in 04 §6.2 Nr. 3. Ob
   Online-Staffeln einen eigenen Betriebsbeitrag brauchen, entscheidet das ST2-Gate (F-9).

---

## 11. Umsetzung

### 11.1 Reihenfolge

```text
07 R1a + 08 K0 (gelandet) → R1b-I1 → R2, R3 → R1b-I2/I3 → R4, R5a → R5b          08 K1 erst nach CR-33
                                                     │
     nach R3:   reine ST1-Module in eigenen Dateien: ST1-A (Texte), ST1-B, ST1-E, ST1-F, ST1-H (gegen Fixtures)
     nach R4:   ST1-C (Etagen, Daten), Merge von ST1-D (Talentbaum; Kern ab R3, oder R4 misst mit dem Baum)
     mit R5b:   ST0 (geteilte Dateien, ein Durchgang mit Save v2)
     nach ST0:  ST1-B Einbau, ST1-G, ST1-I → ST1-Gate → „Sendung starten“ wird Standard (SIM_VERSION + 1)
                                                     │
     ST2 (mit 05 S1-Infrastruktur: Konten, Verifier) → ST2-Gate → ST3 (mit 05 S4: Dedicated Server)
```

Der Echtzeitkampf ist das Fundament (Klassenfähigkeiten, Gastauftritte, Schlaf-Kämpfe laufen alle in `RtSim`); deshalb kein
ST1-Paket vor 07 R3, kein Talentbaum-Merge vor R4 (R4 misst die Boss-Bänder mit den heutigen Talenten — oder mit dem Baum,
wenn ST1-D vorher fertig ist) und keine geteilte Datei vor R5b (V-4). Bis zum ST1-Gate gibt es Staffeln nur in Debug-Builds
und im Harness; weil alles an `state.season != null` hängt, bleiben bis dahin alle Läufe bitgleich. Der einzige
`SIM_VERSION`-Sprung kommt, wenn „Sendung starten“ die Kampagne ersetzt — mit Plattform-Matrix davor und danach
(`tools/platform_matrix.sh`, 05 Kap. 2).

### 11.2 ST0 — Vertrags-Durchgang (Integrator, gemeinsam mit 07 R5b)

Wie 06 Schritt 0 und 07 R1a: **eine** Person legt alle Änderungen an geteilten Dateien als Felder, Stubs und Hook-Zeilen an —
hier im selben Durchgang wie R5b, damit der Spielstand nur einmal sein Format wechselt (Save v2 mit Staffel-Block). Danach
schreibt jedes ST1-Paket nur eigene Dateien. Neue Stub-Dateien beginnen mit
`# STUB(ST0) — owned by 09-ST1-<X>. Replace completely, keep the public API.`

1. `core/live/command.gd`: `TYPES` += `season`, `clock`, `away`, `sleep`, `prof`, `gather`, `craft`, `cast`; `talent` v2 und
   `persona` v2 (mit 08 abgestimmt, CR-33; v1 bleibt lesbar).
2. `core/progression/game_state.gd` (`season`), `party_member.gd` (`rested`, `professions`, `prof_head`, Talentreihen),
   `floor_run.gd` (Fundstellen, Nachschub-Uhren, Programmpunkte) — additiv mit Standardwerten. Der ruhende Starttalent-Pfad aus
   K0 geht in einem Zug (CR-33): `origin_talent` und seine Leser in `talents.gd`, `hero_rules.gd`, `persona_rules.gd`,
   `save_codec.gd`, `command.gd`, `game_data.gd`, `validators/origins.gd` und `data_validator.gd`; Fixtures ohne
   `tal_org_`-Einträge; dazu `PersonaRules.offer/swap_command/can_swap`, `PersonaText.plain_line`,
   `PersonaProfile.talent/offer` und das Flag `flags.persona.swapped`; `test_08_k0_contract` wird angepasst. Hash-neutral,
   weil `talent` seit K1 leer ist.
3. `core/data/game_data.gd`, `autoload/db.gd`: Tabellen `seasons`, `professions`, `cast`, `themes`, Getter.
4. `core/data/data_validator.gd` (eingefroren): **dritter Vertrags-Durchgang** — Tabellen, Präfixe `ssn_`/`prf_`/`rcp_`/
   `mat_`/`nod_`/`thm_`, Hook-Zeilen für die vier neuen Validatoren, Tag-Präfixe `cast_`, `season_`, `prof_`, `sleep_`,
   `daily_`.
5. `core/live/state_hash.gd`: neue Felder (additiv); `core/live/run_sim.gd`: Zweige für die neuen Commands als Stubs, alle
   hinter `state.season != null`. **Kein** `SIM_VERSION`-Sprung in ST0 (der kommt mit der Umstellung, Kap. 11.1).
6. `autoload/save.gd`, `core/progression/save_codec.gd`: Staffel-Block in Save v2 (mit R5b) und die Journal-Haken
   (`journal_append`, `journal_replay`) als Stubs.
7. `autoload/game.gd`: Fassaden `start_season`, `season_op`, `season_clock`, `season_away`, `logout`, `pick_talent_row`,
   `prof_action`, `gather`, `craft`, `cast_action` (Stubs).
8. Stubs nur für Klassen, die geteilte Dateien referenzieren und noch nicht existieren (was reine ST1-Pakete schon gebaut
   haben, bleibt).
9. Daten minimal (je ein Eintrag), Fixtures `tests/fixtures/season_min/`; `mod_lines.json` Anker `mod_ssn_anchor_01` am
   Dateiende hinter dem K-Block.
10. Gate: `check.sh` und `fullrun.sh --strategy=all` grün, Verhalten unverändert; `test_09_st0_contract` prüft die Signaturen.

**Stand ST0 (2026-10-12, Branch `ptd/st0`) — umgesetzt** (Einzelheiten 02_TECH §0.8): (Vorlauf) die CTB-Reste der Erkundung
aus 07 §12.6 entfernt; (2) der K0-Starttalent-Pfad in einem Commit, hash-neutral; (3, 4, 9) Tabellen `seasons`,
`professions`, `cast`, `themes` mit Gettern, der dritte Durchgang des `DataValidator`, minimale Daten, Fixtures
`tests/fixtures/season_min/`, Anker `mod_ssn_anchor_01`; (2, 5, 6) `GameState.season`, die Felder von `PartyMember` und
`FloorRun`, `StateHash` (ohne die lokale Wanduhr), Save v2 mit Staffel-Block (additiv, keine Version 3) und die
Journal-Haken als Stubs; (1, 5, 7, 8) die Commands mit `talent` v2 und `persona` v2 (das Casting zeichnet v2 auf, v1 bleibt
lesbar), `RunRules.season_refusal`/`apply_season`, je ein Zweig in `RunSim` und `GameReplay`, der Stub `sd` mit
`sd_unavailable` (10 Kap. 6.8), die `Game`-Fassaden und die Stub-Klassen `SeasonState`, `SeasonRules` (ST1-B),
`SleepResolver` (ST1-G), `CastSim` (ST1-F), `TalentTree` (ST1-D), `Professions` (ST1-E); (10) `test_09_st0_contract`.
Gate: `check.sh` grün, `fullrun.sh` (`--strategy=all`, `--hero=mopsula`, `--liga=1`, `--liga=2`) mit gleichen Ereigniszeilen
und Statistiken wie vor ST0. **Abweichungen:** alle acht Berufe statt eines Eintrags (die `prof`-Spalte der `origins.json`
nennt alle acht); Tag-Präfix `ssn_` zusätzlich (der Anker braucht nach der Id-Regel `mod_<tag>_<nn>` den Tag
`ssn_anchor`); `sleep` liegt bei `SeasonRules` (ST1-B laut Kap. 11.3), `away` bei `SleepResolver`; ohne Hobby bleibt das
Hobby-Rezept leer (Kap. 8.6: es kostet dann Credits). **Offen:** Die neuen Felder der Bestandstabellen (`floors.json`
`variant`/`level_band`/`zones`, `talents.json` `row`/`col`/`tree`/`spec`, `party.json` `exp_table`) kennt der eingefrorene
`DataValidator` noch nicht, `enemy_level_pm` nicht `RtBalance` — Nr. 4 nennt sie für ST0 nicht; sie kommen per
Änderungsantrag mit ST1-C/D (02_TECH §0.8).

### 11.3 ST1-Pakete

| Paket | Inhalt | Startet | Aufwand **[Schätzung, Personentage mit KI]** |
|---|---|---|---|
| **ST0** Vertrag | Kap. 11.2 (Integrator) | mit R5b | 2–3 |
| **ST1-A** Begriffe | Text-Prüfung Kap. 1.2, Lint `test_09_terms`, Party-Menü-Zeilen, Liga-Texte | nach R3 | 1–2 |
| **ST1-B** Staffel-Kern | `SeasonDef/State/Clock/Rules`, Formate, Tempo (Kalender, Am Stück je Etage), Sendeplan in UTC, Treppenregel ab Etage 4, Einsturz, Generalprobe, Rettung, Tod, Ohne Netz, Tagesprogramm, Quote, Titel, `season`/`clock`/`sleep`, Hash, **Journal**; Einbau in `RunSim`/`Game`/`Save` (Dauerspeicherstand, Migration der Kampagne) | Kern nach R3, Einbau nach ST0 | 9–11 |
| **ST1-C** Etagen | Generator v2, `themes.json` mit Programmpunkt-Pools, Etagen 2–18 (Platzhalter), Stufen-Tabelle der Gegner, Beute-Skalierung, Boss-Baukasten, Nachschub, Viertel-Streaming | nach R4 | 12–16 |
| **ST1-D** Stufen, Fähigkeiten, Talente | EP-Tabelle 1–50, Band/Deckel/Aufholjagd/Crashkurs/Farben, Fähigkeitenbuch, Klassenleisten (Platzhalter), Talentbaum + Migration + Talent-Show als Reihen-Präsentation | Kern nach R3, Merge nach R4 | 10–12 |
| **ST1-E** Berufe | `professions.json` (Güte 1–3), Gewerke-Büro, Sammeln, Ausschlachten, Herstellen, Farben, Ränge, Vorsprung +50 und Hobby-Rezept (Spalte `prof` aus 08 K1, CR-33) | nach R3 | 8–10 |
| **ST1-F** KI-Besetzung | `CastSim` (Kalender und „folgt“), Ereignisse, Eilmeldungen, Zähler, Rangliste, Safe-Room-NPCs, Gastauftritt, Pechvogel-Event, Namenskatalog | nach R3 | 7–9 |
| **ST1-G** Schläfer | Ausloggen-Dialog mit Taktik, `away`, `SleepResolver` mit KI-Begegnungen und Todesraten-Bändern, Ausgeruht, Login-Bilanz, Tageszusammenfassung, Sendepause, Uhrsprung-Rückfrage, lokale Benachrichtigungen | nach ST0 | 6–8 |
| **ST1-H** Staffel-UI | „Sendung starten“, „Neue Staffel“, Reiter „Staffel“ (Sendeplan, `.ics`, Tagesprogramm, Rangliste, Ticker, Aussteigen), Einsturz-Anzeige, Tempo-Angebot, Staffel-Bilanz und Finale, Ruhmeshalle | nach R3 | 7–9 |
| **ST1-I** Harness | Staffel-Harness (Formate 6/12/18, Zeitraffer headless, Bot + Besetzung), Profile Kap. 11.6, Pensum, Kalibrierung der KI | nach ST0 | 6–8 |
| **Summe** | | | **≈ 68–88 PT ≈ 3,5–4,5 Monate** für eine Person mit KI, dazu 24 Kalendertage Tagebuchstudie |

Nicht enthalten: echte Inhalte der Kulissen (Gegner, Bosse, Musik, Raumteile, Programmpunkte, Talent- und Rezepttexte) —
Produktion nach 04 Phase 4/5, ehrlich geschätzt in Kap. 3.5 (eine Etage je 8–10 Wochen Team für jede neue Kulisse, 3–4 Wochen
je weitere Etage einer Kulisse, Letzteres erst nach Beweis) **[Schätzung]**.

### 11.4 Dateieigentum gegenüber 07 und 08

| Datei / Bereich | Eigentum heute (06/07/08) | 09 | Regel |
|---|---|---|---|
| `core/season/**`, `core/live/command_journal.gd`, `core/progression/{professions,talent_tree,ability_book}.gd`, `core/dungeon/zone_generator.gd`, Validatoren `seasons/professions/cast/themes`, `data/{seasons,professions,cast,themes}.json`, `scenes/ui/season_*`, `wake_summary.*`, `logout_dialog.*`, `prof_menu.*`, `talent_tree.*`, `hall_of_fame.*`, `scenes/title/season_setup.*`, `tests/test_09_*` | neu | ST1-Pakete (reine Module ab R3) | neu |
| `command.gd`, `game_state.gd`, `party_member.gd`, `floor_run.gd`, `state_hash.gd`, `game_data.gd`, `db.gd`, `data_validator.gd` | Schritt 0, R1a, K0 | **nur ST0** (mit R5b) | additiv, Abschnitt `# --- Staffeln (09, ST0) ---` |
| `run_sim.gd`, `game.gd`, `save.gd`, `game_replay.gd`, `save_codec.gd` | D, R1b, R5a, R5b, K0/K1 | ST0 (mit R5b: Save v2, Journal-Haken) → ST1-B (Uhr, Journal), ST1-G (Schlaf) | eigene Abschnitte |
| `talents.gd`, `talent_show.gd`, `party_menu.gd` | 06 B, K0/K1 (Tausch-UI entfällt mit CR-33) | ST1-D, Merge nach R4 | Abschnitt; die Angebotslogik bleibt für Läufe ohne Staffel |
| Starttalent-Pfad aus K0 (`origin_talent` und Leser, Kap. 11.2 Nr. 2) | K0, K1 (`persona_rules.gd`) | **nur ST0**: entfernt in einem Zug (CR-33) | ein Commit, Verhalten unverändert |
| `skills_menu.gd` (Fähigkeiten-Menü) | R3 | ST1-D nach R3 | Abschnitt „Buch und Vorschau“ |
| `dungeon_generator.gd` | Bestand (M3) | ST1-C: eine Weiche auf `zone_generator.gd` | eine Zeile |
| `floors.json` | A, C, R4 (`encounters[].rt`) | ST1-C: neue Einträge `floor_3` … `floor_18`, `floor_2` vervollständigt | eigene Einträge, R4 schreibt nur `rt` |
| `skills.json`, `items.json`, `enemies.json`, `party.json`, `rt_balance.json` | R4 (`rt`-Blöcke, Werte) | ST1-C/D: neue Einträge, `exp_table`, `enemy_level_pm` | additiv nach R4; Werte-Eigentum bleibt R4 für Etage 1 |
| `classes.json`, `species.json` | 06 B (Daten), Validator-Regeln für `rt` R4 (CR-32 a) | ST1-D: `rt.bar`, Ränge, Klassenleisten | additiv |
| `talents.json` | 06 B, K1 (Text) | ST1-D: `row`/`col`/`tree`/`spec`, neue Einträge | additiv |
| `origins.json` | K0 (minimal), K1 | Spalte `prof` in K1 als reine Daten, Referenzprüfung ab ST0 (CR-33) | K1 schreibt, ST0 prüft |
| `mod_lines.json` | Anker A–D, R1a/R4, K | Block hinter `mod_ssn_anchor_01` | Blöcke |
| `exploration.gd`, `exploration_hud.gd`, `show_overlay.gd`, `safe_room*.gd`, `settings_menu.gd`, `title_screen.gd` | A, C, R2, R3, K | ST1-G/H je ein Abschnitt | Abschnitte |
| `scenes/boot/fullrun.gd`, `tools/fullrun.sh` | Schritt 0, R5b, K0 | ST1-I: `--season=ssn_basis --tempo=binge` | Abschnitt nach R5b |
| `core/rt/**`, `scenes/combat/**` | R-Phasen | **nie**; Gast-Einheit, Klassenleisten und `talent:`-Quelle nur als Schema-Haken CR-32 (a)–(c) an R1b/R4 | Änderungsantrag |

### 11.5 ST2 und ST3

| Phase | Pakete | Gate (weiter, wenn …) | Aufwand **[Schätzung]** |
|---|---|---|---|
| **ST2** | Staffel-Dienst (Lobby, Start, Uhr-Tickets mit externen Eingängen, kanonischer Zustand durch Nachrechnen), Besetzung auf dem Server, Resync, Postfach/Treuhand, Ranglisten, Freunde-Staffeln, Sendetermine mit CI-Nachspielen, Benachrichtigungen (Push), Zuschauen (05 S2), Moderation (Schnellsätze, Melden), Datenschutz-Paket, Betrieb | 0 Abweichungen zwischen Client und Nachrechnung in 1 000 Sitzungen über die Plattform-Matrix (05 Kap. 2); Resync-Tests (Tunnel unter 120 s ohne Schlaf, darüber Schlaf); Postfach-Dupe-Tests; CI spielt alle Live-Versionen grün nach; 4-Wochen-Beta-Staffel (Format Basis) mit ≥ 60 % der Menschen bis Etage 6; Datenschutzprüfung; Kosten je Spielenden gemessen | 4–6 Monate, 2–3 Personen |
| **ST3** | Shard-Server (Grad B Erkundung + Kampf), Start und Ende der Shards mit den Menschen, Übergabe abstrakt ↔ Shard, Präsenz und Interessenradius, Koop 2–4, sichtbare Schläfer (bewachen, heilen, wecken, Kaffee), Arenen (PvP opt-in), Freitext-Chat ab 16, Skalierung | 05 S4-Kriterien; 24 Menschen je Shard mit p99-Tick < 5 ms **[zu messen]**; Shard-Start < 5 s, Übergaben ohne Hash-Abweichung; Koop-Playtest ≥ 4/5; Meldungen je 1 000 Spielstunden unter Schwelle **[festzulegen]**; Kosten je gleichzeitigem Menschen gemessen | 8–12 Monate, 3–5 Personen |

### 11.6 Tests und Gates (ST1)

| Test | Prüft |
|---|---|
| `test_09_season_clock` | Sendeplan (2/3/4/5…, Formate 24/54/84), Tag 0 = nächste Sendezeit, UTC-Termine und Zeitumstellung, Etage auf Sendung, Vorlauf ab Etage 4, Am-Stück-Countdown je Etage (Etage 1 = 20:00, keine Gnadenfrist), monotone Uhr, Sprung über 7 Tage, Sendepause, Tagesprogramm-Takt (höchstens 5, bleibt bis zum Einsturz) |
| `test_09_stairs_collapse` | Treppenregel an jeder Grenze (Etage 1–3 offen); Einsturz eingeloggt, als Schläfer, im Kampf (wartet, dann 2 min); höchstens eine Gebühr je 7 Tage (Rettung oder Sanitäter), Schläfer im Safe Room gratis; Generalprobe; Ohne Netz raus; Etagen-Bilanz nur per Treppe |
| `test_09_death_modes` | Tod Mit Netz (Safe Room oder Etageneingang, −10 %, Weste), Ohne Netz (Studiogast ab Etage 2), Generalprobe, Tod als Schläfer, Freischaltung „Ohne Netz“ |
| `test_09_level_band` | EP-Tabelle, Deckel, Überstunden, Aufholjagd × 2/× 3, Crashkurs und Aufholpaket, Ausgeruht (Aufbau, Deckel 150 %, Verbrauch, höherer Faktor gilt), Farbe und Differenz |
| `test_09_sleep` | `away` deterministisch (gleicher Zustand + Dauer → gleicher Hash), Begegnungen (Streifen und alle KI-Profile), Taktik aus `sleep`, Notfall-Rückzug, keine Begegnungen im Safe Room/Bossraum, Am Stück ohne Begegnungen, **Todesraten Ohne Netz je Nacht in den Bändern** (1 000 Seeds je Gefahr) |
| `test_09_journal` | App „beendet“ an jedem zehnten Tick eines Kampfs → nach dem Neustart dasselbe Ergebnis wie der Autopilot-Lauf vom Kampfanfang; Journal nach dem Spielstand leer; abgerissene letzte Zeile verworfen |
| `test_09_cast_sim` | Determinismus je Seed, Kalibrierungs-Bänder (Kap. 4.2) über 200 Seeds, Am Stück folgt die Besetzung, „übernommen“, Ereignisse, Zähler, Kennzeichnung, Gastauftritt nie im Bosskampf |
| `test_09_professions` | Lernen (≤ 2 Hauptberufe), Ränge, Farben und Chancen, Sammeln, Ausschlachten, Herstellen nur im Safe Room, Vorsprung +50 (fest oder frei gewählt) und Hobby-Rezept aus `persona` v2, Tägliches sammelt sich 4 Tage |
| `test_09_talent_tree` | Reihen, Umwählen nur im Safe Room, Migration 06-B, Deckel bei Stufe 10 (06) und 50 (Kap. 8.4), Klassenwechsel; Event-Lauf nutzt denselben Baum (V-20) |
| `test_09_ability_book` | Freischaltung auf festen Stufen, Vorschau, Klassenleisten über `rt.bar`, Rang II–IV |
| `test_09_replay` | Sitzung mit `season`/`clock`/`away`/`sleep`/`prof`/`craft`/`talent` v2 → `RunSim.replay` und `Game.replay_log` hash-gleich; manipulierte Uhr-Commands → Fehler; Läufe ohne Staffel bitgleich zu den Golden-Hashes |
| `test_09_terms` | Sprachregel (Kap. 1.2) |
| `test_09_zone_generator` | 200 Seeds je Etage 3–18 erfüllen die Prüfregeln (Kap. 3.6), deterministisch |

**ST1-Gate — nur Mechanik (V-5):** Alle Tests grün; Am-Stück-Etage 1 in den neu gemessenen GDD-§13-Bändern; Staffel-Harness
(`tools/season_harness.sh --format=18 --tempo=calendar --speed=dev`) mit diesen Profilen (V-8):

| Profil | Spielt | Muss erreichen **[Startbänder, zu messen]** |
|---|---|---|
| `typical` | 45–60 min an jedem Tag | Finale Mit Netz in ≥ 80 % der Seeds; Median-Stufe beim Abstieg im Band ± 1; Pensum je Etage in den Bändern Kap. 3.3 |
| `20 min/Tag` | 20 min an jedem Tag | ≥ 90 % der Etagen per Treppe; Stufe beim Abstieg ≥ Bandanfang − 1 |
| `nur Wochenende` | Samstag und Sonntag je 90 min | Stufe nach jedem Login ≥ Bandanfang − 2; ≥ 50 % der Etagen per Treppe; Credits am Staffelende ≥ 50 % von `typical` |
| `2 Wochen weg` | wie `typical`, Tage 30–44 abwesend | nach der Rückkehr binnen 2 Sitzungen im Band; Finale in ≥ 60 % der Seeds |

**Echtzeit-Tagebuchstudie (V-5):** Eine Basis-Staffel (6 Etagen, 24 Tage) in echter Zeit mit **≥ 10 Tester:innen** und einer
täglichen Zwei-Minuten-Notiz. Bestanden, wenn ≥ 8 von 10 Einsturz, Vorlauf und Schläfer in einem Satz richtig erklären,
≥ 7 von 10 bis zum Staffelende dabeibleiben (gerettet zählt) und höchstens 2 von 10 sich „zum Warten oder Einloggen gedrängt“
fühlen **[Schwellen festzulegen]**. Inhalte dürfen Platzhalter sein — die Studie misst den Rhythmus, nicht die Kulissen.

### 11.7 Änderungsanträge

| CR | Betrifft | Änderung | Wann |
|---|---|---|---|
| **CR-25** (**eingearbeitet mit ST0**) | `00_BRIEF` | Entscheidungsblock „Staffeln“ mit dem Wortlaut der Nutzeridee 2026-10-11 und den Entscheidungen S-1 … S-12 in Kurzform (Formate 6/12/18, Generalprobe); Vorrang `09` nach `07`; Kap. 1 „Etagen („Level“)“ → „Etagen“, Einsturz Mit Netz/Ohne Netz statt „Game Over“, „die System-KI“ → „die Show-KI“, „Crawler“ → „Kandidat:innen“ (wörtliche Zitate bleiben); Kap. 2 Säule 3 („Eine Sitzung 15–60 min; eine Etage über Tage — oder am Stück“); Kap. 3 Schleife mit Ausloggen; Kap. 4 Zeilen Etagen-Timer (Sendeplan), Speichern (Dauerspeicherstand mit Journal, Ausloggen überall), Progression (Stufe 50, Fähigkeitenbuch, Talentbaum, Berufe), Casting (Vorleben), Game Over (nur Ohne Netz und Event-Läufe); Kap. 6b Nr. 4: Uhr-Commands als externer Eingang | vor ST0 |
| **CR-26** | `01_GDD` | Sprachregel „Stufe/Etage“ im ganzen Dokument; **§2.7 Streuner bleiben auf Etage 1** (beide Tempi, V-2); §2.8/2.9 Treppe und Timer → Sendeplan (Am Stück = Countdown je Etage wie heute, Etage 2 30:00), keine Gnadenfrist beim Laden in Staffeln; §4.1 Höchststufe 50, §4.3 Tabelle; §4.7 Talent-Show → Grundreihen (in Staffeln); **§12.2 Klassenfähigkeiten** über `rt.bar` beim Recall und auf Stufe 12/17/22/27/32 statt `learnset` 11/13, Beispiel `skl_kai_concrete_boots` → `skl_kai_quick_concrete` (V-16); §12 Talentbäume; **§13 Bänder je Etage, Etage 1 neu gemessen** mit Generalprobe statt Game Over; §14.2 „Sendung starten“/„Neue Staffel“; §14.4 Pausemenü „Staffel“, „Ausloggen“; §14.6 Game Over nur Ohne Netz/Event; §14.7 Safe-Room-Menü; §15 Etage 2 | mit ST1 |
| **CR-27** (**eingearbeitet mit ST0**, 02_TECH §0.8) | `02_TECH` | Modul `core/season`, `CommandJournal`, Dateibaum und Eigentum; neue Tabellen und Präfixe (`prf_` statt des reservierten `job_`); Commands Kap. 9.1; Felder in `GameState`/`PartyMember`/`FloorRun`; Spielstand (Dauerspeicherstand mit Journal, Staffel-Block in Save v2, Migration Kampagne → private Staffel); `StateHash`-Abdeckung; Schalter `state.season != null`; Versions-Bindung und Sendetermine; **§4.4.4** Klassenfähigkeiten wie CR-26 (V-16); `FloorDef` mit `theme`/`variant`/`level_band`/`zones`; `exp_table` | ST0 |
| **CR-28** | `03_ART` | Paletten der Kulissen 3–8; Requisiten für Fundstellen und Gewerke-Büro; Schläfer-Optik („Zzz“, Schlafsack); KI-Kandidat:innen aus dem Persona-Kit (08 K2) statt eigener Rigs; Stufen-Plakette mit Differenz-Zahl (farbenblind-sicher); Marker „NEU“ für Programmpunkte; Raumteile je Kulisse (Produktion) | ST1-C/H |
| **CR-29** (**eingearbeitet mit ST0**) | `04_STRATEGIE_ROADMAP` | **Namenskonflikt:** Inhaltspakete heißen „Akt 1–3“ (Akt 1 = Etagen 1–6, Akt 2 = 7–12, Akt 3 = 13–18) statt „Staffel 1/2“. **Formate nach Kauf (V-14):** Grundspiel = Basis-Staffel (6 Etagen, 24 Tage), Erweiterung Akt 2 = 12 Etagen (54 Tage), Akt 3 = 18 Etagen (84 Tage); Staffeln je Format, nie gemischt; in der Staffel nichts käuflich; §6.1 „Staffel 1 komplett“ und „Staffel 2 (Etagen 7–9)“ → „Akt 1“, „Akt 2 (Etagen 7–12)“, „Akt 3 (Etagen 13–18)“. **§6.2 Nr. 3:** „Wartezeit-Mechanik“ heißt: Warten wird verkauft; der Kalender ist eine Wartezeit, verkauft aber nichts (Kap. 10 Nr. 7). **§3.5 (V-5):** Die KPI „1 Etage / 8–10 Wochen“ bleibt für jede neue Kulisse; Varianten-Etagen 3–4 Wochen erst nach Beweis (Kap. 3.5). **Kap. 2.3 (V-15):** neue Zeile (unten, Nähe hoch); das Anwalts-Memo deckt die Staffel-Struktur vor jeder öffentlichen Erwähnung; Marketing ohne „18 Etagen“. Kap. 1.2/1.4/1.5 „20-Minuten-Etagen“ → „Folgen à 20–60 min, als Staffel über Wochen oder am Stück“; Kap. 3 Phasen ST1–ST3; Kap. 9 Risiken R13–R20 (Kap. 11.8); Kap. 11 E5 ersetzt | vor ST0 |
| **CR-30** | `05_LIVE_MODUS` | SHOWRUN bleibt eigener Modus mit eigenen Regeln; Staffeln nutzen dessen Bausteine: Konten und Verifier (S1), Zuschauen (S2), Sponsor-Fenster (S3, nur Show-Staffeln). **§4.3 Versionen (V-1):** Regel- und Datenänderungen nur zu Sendeterminen; öffentliche Staffeln starten in Wellen danach und enden vor dem nächsten; dazwischen nur hash-neutrale Patches, die CI spielt die gespeicherten Logs jeder Live-Version nach; Rückfall Datenstand je Staffel (`data_hash`-Schnappschuss) und archivierte Verifier-Builds je `sim_version`; Freunde-Staffeln wechseln am nächsten Einsturz gemeinsam. **§3.6 (V-12):** `reconnect_grace_sec` 120 gilt in Staffeln (ein Tunnel ist kein Ausloggen); der Resync stellt den kanonischen Zustand des Staffel-Dienstes her. L3 = Etagen-Bindung; Staffeln ohne Geschenke außer Show-Staffeln; Ranglisten je Staffel; Uhr-Tickets mit externen Eingängen in Kap. 4; Hinweis: Staffel-Phasen heißen ST1–ST3 | §4.3 vor der ST2-Beta, Rest mit ST2 |
| **CR-31** | `06` | §0.1 Nr. 3, §0.5, §2.2: Talentbaum statt „1 aus 2“ überall (V-20), der Absatz „Starttalent der Kandidat:in“ (CR-21) entfällt mit CR-33; §0.6: Etage 2 bekommt Berufe statt Fanclubs (Fanclubs ab Etage 4 oder als spätere Spielergilden), Einführungsfahrplan der Staffel (Kap. 0.6); §2.3 Höchststufe 50 und Bänder (schließt O-2); §3: „Spezialisierung“ heißt „Klasse“, Spezialisierungen = Äste des Talentbaums; §3.6 Talent-Reset kostenlos im Safe Room; §4: weitere Vorlieben als Programmpunkte, Liga-Texte „Liga 1/Duo-Liga“; §7: Staffeln, Berufe (statt „Nebenjobs“; Präfix `prf_`, `job_` wird frei), PvP = Arenen opt-in | mit ST1-D |
| **CR-32** | `07` | (a)–(c) **nur Schema-Haken vor R4**, ohne Wirkung — R4 misst, was gilt (V-4): (a) `classes.json` darf `rt.bar` tragen (Schema wie `party.json`, der Validator kennt das Feld, leer erlaubt); (b) `RtMods`-Quellen `talent:<id>` und `class:<id>` (Reihenfolge Ausrüstung → Spezies → Klasse → Talente → Show-Boss → Twists) und die Talent-Art `rt_mod` mit Operationen aus `MOD_OPS` im Vokabular; (c) `RtSetup` kennt eine optionale Gast-Einheit `p2` (Klassenvorlage × Stufe, Partner-KI „Unterstützen“, kein Partner-Spezial, nie im Bosskampf). Die Wirkung kommt mit ST1-D/ST1-F, nur mit `state.season != null`. (d) Stufen-Skalierung `enemy_level_pm`, Höchststufe 50 (MP-/HP-Formeln §4.2/§4.3 bis 50 prüfen); (e) Hinweis ohne Sim-Änderung: Schlaf-, Journal- und Absturz-Kämpfe nutzen `RtSim` headless mit beiden Einheiten auf Autopilot, der `SleepResolver` liest nur (Halt unter 25 % Party-HP für den Fluchtwurf); (f) §2.10: im Kalender-Tempo zählt Kampfzeit zur Staffel-Uhr (nach `end_combat` nachgereicht), ein fälliger Einsturz wartet bis Kampfende + 2 min; (g) mit CR-33 entfallen der Harness `--persona` und das nächtliche Persona-Gate (§12.4), §12.9 Nr. 16/17 (Persona-Namen im Kampf) bleiben; (h) **§2.6 Niederlage (V-16):** in Staffeln gilt die Todesregel aus 09 Kap. 7 (Mit Netz Safe Room oder Etageneingang, Ohne Netz raus, Etage 1 Generalprobe) statt Sendeschluss mit Neuladen; ohne Staffel unverändert | (a)–(c) und (g) vor R4, Rest mit ST1 |
| **CR-33** | `08` — **dringend, vor 08 K1** (K0 ist mit 07 R1a gelandet) | „Beruf“ im Casting heißt **„Vorleben“** (Bildschirm 2/3, Overlay „VORLEBEN WÄHLEN“, Zeilen „Vorleben und Hobby …“; IDs `org_*`/`occ_*` und der Platzhalter `{job}` bleiben); die **17 Starttalente `tal_org_*` entfallen** und werden durch den Vorsprung aus Kap. 8.6 ersetzt (+50 in einem Beruf, Hobby-Rezept; `origins.json` und `hobbies[]` bekommen in K1 die Spalte `prof` mit `prf_`-IDs als reine Daten — Status-Kacheln und Allrounder:in leer; die Referenzprüfung kommt mit ST0). **K1 schrumpft:** keine Starttalent-Daten, kein Tausch in der ersten Talent-Show, kein `test_08_origin_talents`/`_balance`, kein Persona-Balance-Gate; `PersonaRules.check` nimmt bis ST0 `"talent": ""` an (Persona ohne Kampfwirkung, `bias` wirkt). **ST0** führt `persona` v2 ein (Kap. 8.7; v1 bleibt lesbar) und entfernt im Durchgang mit 07 R5b den ruhenden K0-Pfad (`PartyMember.origin_talent`, Starttalent-Zweig in `Talents.has_any`/`_effects`, `origin_field_range_pm`, `tal_org_`-Prüfung in `Command.validate`) — hash-neutral, Save v2 ohne `origin_talent`. Karte 3/3 zeigt ab ST1-E „Vorsprung: Erste Hilfe +50 · Hobby-Rezept: Kochen“ (vorher keine Zeile); Stempel „STAFFEL N · FOLGE M“ mit echter Staffelnummer; keine „Letzte Karte“, auch nicht über Staffeln (C-2 bleibt); **bleiben:** Datenschutz (P-1, P-2, D-1 … D-14), Persona-Datei, `bias`, Erzählstrang, KI-Casting, Avatar-Editor | **Text in 08 eingearbeitet (2026-10-11)**; Code in K1 und ST0 (**ST0-Teil umgesetzt 2026-10-12**) |

**Distanz-Notiz für 04 Kap. 2.3** (neue Zeile, zur Übernahme mit CR-29):

| Element | Nähe | Vorschlag |
|---|---|---|
| **Staffel-Struktur** (Etagen mit Einsturztermin über Wochen, bis zu 18 Etagen, Spezies und Klasse auf Etage 3, Zähler der verbliebenen Mitkandidat:innen, Ausloggen in der Welt) | **hoch** (V-15) — jede Mechanik ist frei, aber die Summe ist die Struktur des Buchs | Ausdruck konsequent eigen: TV-Sprache (Staffel, Folge, Sendeplan, Generalprobe, Recall, Vorlauf, „Kulissen im Aufbau“, Tagesprogramm), Rettung durch die Regie (Mit Netz), „Ohne Netz“ statt Buch-Begriffen; im Spiel **Kandidat:innen**, nie „Crawler“; Zähler „Weiße Weste“/„Noch dabei“; keine Etagenthemen, -reihenfolge, Figuren, Titel oder Ränge des Buchs; M.O.D. statt „System-KI“, kein „World Dungeon“. **Das Anwalts-Memo aus 04 §2.3 prüft die Staffel-Struktur, bevor sie irgendwo öffentlich erwähnt wird [zu prüfen].** Marketing nennt weder „18 Etagen“ noch die Staffel-Struktur als Hook oder Buch-Bezug; 18 bleibt das größte Format, weil die Idee es nennt. |

**Folgeänderungen:** F-1 `README.md` (Status: Talentbaum, Staffel-Modus, Begriffe); F-2 Screenshots nach ST1-H
(Sendeplan, Login-Bilanz, Talentbaum, Gewerke-Büro, Tagesprogramm); F-3 Testnamen mit „Staffel“ im Sinn von
„Etagen-Simulation“ (`test_m7_show_balance`, `test_06c_balance`, GDD §13) in Texten zu „Etagen-Simulation“; F-4
`PERFORMANCE.md` mit Viertel-Streaming.

### 11.8 Risiken

| # | Risiko | W / A | Gegenmaßnahme | Frühindikator |
|---|---|---|---|---|
| R13 | **Inhaltsmenge** für bis zu 18 Etagen | hoch / hoch | Kulissen × 3, wiederkehrende Revier-Bosse, Boss-Baukasten, Platzhalter-Familien, Formate nach Kauf 6 → 12 → 18, ehrlicher Aufwand (Kap. 3.5) | Varianten-Etage (Etage 5) > 4 Wochen |
| R14 | **Kalender-Bindung** bricht ab (Leute kommen nicht wieder) | mittel / hoch | Tagesprogramm, Gratis-Tragen, Wochen-Gebühr, Crashkurs, Tägliches 4 Tage, Sendepause, 20 min/Tag reichen; privat „Am Stück“ | Tagebuchstudie: < 7 von 10 bis zum Ende; Beta: < 60 % erreichen Etage 6 |
| R15 | **Überforderung** durch neue Systeme | mittel / hoch | „Sendung starten“ mit Standardwerten, eine neue Regel je Etage (Kap. 0.6), Ein-Satz-Tabelle | Tagebuchstudie: < 8 von 10 erklären die Regeln |
| R16 | **Tod als Schläfer** (Ohne Netz) fühlt sich unfair an | mittel / mittel | klare Warnung, Taktik im Dialog, Gefahr je Viertel sichtbar, Notfall-Rückzug, getestete Todesraten, Safe Rooms nah; nur Ohne Netz endgültig | Abbrüche nach Schläfer-Tod |
| R17 | **Determinismus über bis zu 84 Tage** | mittel / hoch | Sendetermine, hash-neutrale Patches mit CI-Nachspielen, Anker je Sitzung, Journal, Uhr als Command, Plattform-Matrix vor jedem Sprung | Desync im Harness |
| R18 | **Server- und Moderationskosten** (ST2/ST3) | mittel / hoch | Gates mit Messung, ein Schreiber, Shards nur mit Menschen, Schnellsätze als Standard, Arenen statt Welt-PvP | Kosten je Spielenden über Plan |
| R19 | **KI-Besetzung wirkt künstlich** | mittel / mittel | Kalibrierung an echten Daten, Profile mit Gedächtnis (Pechvogel), Begegnungen im Schlaf, Rival:in aus dem Casting, ehrliche Kennzeichnung | Playtest: „Ticker ist egal“ |
| R20 | **IP-Summe** wirkt wie Buch-Kopie | **hoch** / hoch | Distanz-Notiz 11.7, Anwalts-Memo vor jeder Erwähnung, eigene Begriffe, kein „18 Etagen“ im Marketing, Distanz-Review vor jedem öffentlichen Auftritt | Community-Kommentare |

---

## 12. Offene Fragen mit Empfehlung

| Nr. | Frage | Empfehlung |
|---|---|---|
| F-1 | Eine oder zwei Etagen Vorlauf? | **Eine**, ab Etage 4. Zwei würden die Besetzung auf drei Etagen verteilen und den Deckel weniger wirksam machen; Warten bleibt kurz (≤ 5 Tage, nie untätig, privat „Am Stück“). |
| F-2 | „Am Stück“ für Online-Staffeln? | **Nein** — eine Uhr für alle ist der Kern des gemeinsamen Erlebens; Am Stück nur privat/offline. |
| F-3 | Können Schläfer Ohne Netz wirklich sterben? | **Ja** (Wunsch der Idee), mit Warnung, Taktik-Wahl, Notfall-Rückzug, sichtbarer Gefahr und getesteten Todesraten (Kap. 5.3); auf Etage 1 nicht (Generalprobe). Mit Netz ist es nur ein Rücksetzer. |
| F-4 | Höchststufe 50 oder 60? | **50**: runde Zahl, Bänder von 3 Stufen je Etage gehen auf, zwei Finalwochen auf Höchststufe. |
| F-5 | Mindestbesetzung öffentlicher Staffeln | **10** Menschen, einstellbar (zugleich die Grenze für Ranglisten-Titel); bei wenig Andrang automatisch 5 nach 24 h Wartezeit, dann ohne Ranglisten-Titel **[nach ST2-Beta festlegen]**. |
| F-6 | Härteres PvP („Kopfgeld“), Schläfer angreifbar? | **Offen bei der Nutzerin/dem Nutzer.** Die Idee sagt „ausgeliefert … andere spieler ggfs vorbei“; diese Fassung mildert das ab (Kandidat:innen greifen Schläfer nie an; ausgeliefert ist man Monstern und dem Pech der KI). Empfehlung: so lassen; wer es härter will, bekommt nach ST3 die Opt-in-Vorlage „Kopfgeld“ — auf Wunsch auch mit Angriffen auf Schläfer, dann nur in eigenen Staffeln dieser Vorlage, nie in öffentlichen „Mit Netz“-Staffeln. |
| F-7 | Angeln oder weitere Nebenberufe? | Später („Kanalangeln“ wäre lustig), nicht in ST1/ST2. |
| F-8 | Bleiben Berufswerte über Staffeln? | **Nein** (S-20) — sonst wären neue Kandidat:innen dauerhaft im Nachteil; nur Titel „Legende: <Beruf>“ bleibt. |
| F-9 | Wer bezahlt Online-Staffeln? | Formate kommen aus dem Kauf (S-24); ein eigener Betriebsbeitrag nur, wenn das ST2-Gate ihn mit Zahlen begründet, und nie mit Spielwirkung **[Geschäftsentscheidung]**. |
| F-10 | Einstieg in laufende Staffeln? | **Entschieden (V-18):** nur in Freunde-Staffeln, in den ersten 48 h, auch auf Plätze Ausgestiegener; öffentlich nie. |
| F-11 | Hat in ST3 jede:r einen eigenen Grafen? | In ST1/ST2 hat jede:r „seinen“ Grafen in der eigenen Instanz. Für ST3 Empfehlung: Begleiter anderer erscheinen als **lizenzierte Mops-Doubles** mit eigenem Namen und Fell („NOVA hat den Grafen in Lizenz vervielfältigt. Ihrer ist das Original — er hat die meisten Fußnoten.“) — Satire statt Logikbruch. |
| F-12 | KI-Kandidat:innen in Bosskämpfen? | **Nein** — Boss-Bänder (07 §11) bleiben verlässlich. |
| F-13 | Benachrichtigungen per E-Mail? | Nur als wöchentliche Zusammenfassung, Opt-in, ab ST2. |
| F-14 | Fanclubs (06 §2.4) noch nötig? | Ab Etage 4 als kleine NPC-Aufträge oder direkt als spätere Spielergilden (ST3) — Entscheidung mit dem Etage-4-Design. |
