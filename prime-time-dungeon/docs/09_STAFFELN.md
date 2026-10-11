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
> Die Details sind delegiert (Maßstab: gute UX, Spaß, Witz, Abwechslung — ein **simples, sofort verständliches** Konzept).
> Die Rahmenentscheidungen des Orchestrators (der Nutzerin/dem Nutzer mitgeteilt) stehen in Kap. 0.3 (Zeilen mit **R**); alles
> Weitere sind Detailentscheidungen dieses Dokuments.
>
> **Abgestimmt auf** `00_BRIEF.md` (verbindlich), `01_GDD.md` (§2.8/2.9 Treppe und Timer, §4 Party, §12 Klassen/Spezies,
> §13 Bänder, §14 UX), `02_TECH.md` (§3.4 Commands, §4 Daten, §6.4 Spielstand, §7 Dungeon), `04_STRATEGIE_ROADMAP.md`
> (Kap. 1.4, 2.2/2.3 IP, 3 Roadmap, 6.2 Regeln), `05_LIVE_MODUS.md` (Kap. 1–3, 6.13, 10), `06_PROGRESSION_MAROTTEN_KI_ADMIN.md`
> (§0.5/0.6, §2.2–2.4, §3, §4, §5, §7), `07_ECHTZEITKAMPF.md` (§1, §2.6/2.7/2.10, §4, §5, §9.5/9.6, §10.8, §12) und
> `08_CASTING.md` (§1–§4, §7, §8, §10). Code-Stand: `claude/prime-time-dungeon` @ `b9d278a` (06 A–D integriert; 07 R1a und
> 08 K0 als ein Vertrags-Durchgang gelandet, `SIM_VERSION` 2; R1b ff. und K1 ff. offen).
>
> **Status:** verbindlicher Vertrag für die Staffel-Phasen **ST1–ST3** (Kap. 11). Die Einordnung in die Vorrangklausel des
> Briefs beantragt CR-25: `00_BRIEF` > `07` (alles Kampfrelevante) > **`09`** (Staffel, Sendeplan, Tod und Modi, Stufen,
> Talente, Berufe, Schläfer, KI-Besetzung) > `06` > `08` > `01_GDD` / `02_TECH` / `03_ART` / `05_LIVE_MODUS` > `04`.
> Wo dieses Dokument bestehende Regeln ersetzt, steht es als Änderungsantrag (CR-25 … CR-33, Kap. 11.7).
>
> **Namen der Phasen:** Der Orchestrator nennt sie S1–S3. Weil „S0–S5“ schon die SHOWRUN-Stufen (05) und „S0–S3“ die
> KI-Stufen (06 §5.12) sind, heißen sie hier **ST1–ST3** (Staffel-Phasen) — gleicher Inhalt, keine Verwechslung.
>
> **Konventionen:** Prosa Deutsch; IDs, Pfade (relativ zu `prime-time-dungeon/game/` = `res://`), JSON-Keys, Signal- und
> Methodennamen Englisch. **[zu prüfen]** = reale Fakten (Recht, Preise, Plattformregeln), **[Schätzung]** = Planwert,
> **[zu messen]** = Zielwert, den ein Gate misst. Alle Zahlen sind Startwerte für Simulation und Playtests.

---

## Inhalt

0. Kurzfassung (Spieler:innen-Sätze, Entscheidungen S-1 …, Ein-Satz-Erklärungen)
1. Begriffe (Glossar, Sprachregel, Text-Prüfung)
2. Staffel-Ablauf (Arten, Start, Sendeplan, Einsturz, Treppenregel, Ende, Belohnungen, was bleibt)
3. Etagen 1–18 (Tabelle, Inhalte, Pensum, Skalierung, Bestand, Generator)
4. KI-Kandidat:innen (Populationsmodell, Verkörperung, Profile, Fairness, M.O.D.)
5. Schläfer und Ausloggen (Regeln, Ausgeruht, Streifen, Login-Bilanz, Aufzeichnung)
6. Andere Spieler:innen (Erlaubtes, kein PvP gegen Schläfer, Arenen, Schutz, Chat)
7. Tod und Modi (Mit Netz, Ohne Netz, Strafen, Vorabendprogramm)
8. Fertigkeiten wie in WoW (Stufen, Fähigkeitenbuch, Talentbaum, Berufe, Vorleben, Migration)
9. Technik (ST1 offline, ST2 Staffel-Server, ST3 Echtzeit, Anti-Cheat, Datenschutz, Kosten)
10. Live-Modus, Show und Monetarisierung im Staffel-Kontext
11. Umsetzung (Reihenfolge, ST0–ST3, Dateieigentum, Tests, Änderungsanträge, Aufwand, Risiken)
12. Offene Fragen mit Empfehlung

---

## 0. Kurzfassung

### 0.1 Für Spieler:innen in fünf Sätzen

1. Eine **Staffel** ist eine Fernsehstaffel mit bis zu **18 Etagen** in **12 Wochen**: Jede Etage hat einen festen
   Einsturztermin — die erste nach 2 Tagen, die zweite nach 3, die dritte nach 4 und ab Etage 4 je 5 Tage.
2. Wer schneller ist, darf **eine Etage vorauslaufen**; wer beim Einsturz noch oben steht, wird von der Regie gerettet und
   zahlt dafür — oder ist in der Staffel **„Ohne Netz“** raus und schaut ab dann als Studiogast zu.
3. Sie können **jederzeit ausloggen**: Im Safe Room schlafen Sie sicher und werden **ausgeruht** (doppelte Kampf-EP beim
   nächsten Spielen); im Gang kommen vielleicht Monster vorbei, und Ihre Figur wehrt sich allein.
4. **Auf Etage 3** wählen Sie Spezies und Klasse; Fähigkeiten kommen auf festen **Stufen**, Talente wählen Sie in einem
   **Talentbaum**, und **Berufe** steigen durch Benutzen — Ihr Vorleben aus dem Casting bringt einen Vorsprung mit.
5. Freie Plätze der **100 Kandidat:innen** spielt der Computer: Sie treffen KI-Kandidat:innen, die helfen, handeln,
   drängeln und Schlagzeilen machen — und niemand greift eine schlafende Figur an.

**Was gegenüber der Idee anders ist (und warum), in einem Absatz:** Mit „2, 3, 4 … Tage“ bis Etage 18 wären es 2 + 3 + … + 19
= **189 Tage (≈ 6 Monate)** — doppelt so lang wie die gewünschten 2–3 Monate. Deshalb wächst die Dauer bis 5 Tage und bleibt
dann: 2 + 3 + 4 + 15 × 5 = **84 Tage = 12 Wochen**. Was die Idee „Beruf ab Ebene 3“ nennt, heißt im Spiel **Klasse**; das
Wort **Beruf** bekommen die WoW-artigen Handwerke, und der echte Job aus dem Casting heißt **Vorleben** (Kap. 1).

### 0.2 Antwort auf die Frage „macht Sinn?“

Ja. Die Idee passt genau zur Prämisse (Show mit Etagen-Countdown) und macht aus dem Einzelspieler-Lauf ein Format, das man
über Wochen begleitet — wie eine Serie. Damit es einfach bleibt, gilt überall dieselbe Handvoll Regeln: **ein Sendeplan,
eine Treppenregel, eine Einsturzregel, eine Schlafregel, eine Todesregel**. Alles andere (Talente, Berufe, KI-Besetzung)
hängt daran, ohne neue Ausnahmen zu brauchen.

### 0.3 Entscheidungen

Herkunft: **R** = Rahmen des Orchestrators (verbindlich vorgegeben), **D** = Detailentscheidung dieses Dokuments.

| Nr. | Thema | Entscheidung | Herkunft | Kap. |
|---|---|---|---|---|
| S-1 | Begriffe | **Vorleben** = echter Job aus dem Casting (08) → realistischer Vorsprung in Berufen; **Klasse** = Wahl auf Etage 3 zusammen mit der Spezies → Kampffähigkeiten; **Berufe** = Handwerke wie in WoW (2 Hauptberufe + Kochen und Erste Hilfe), Wert steigt durch Benutzen. In UI und Texten heißt die Etage immer **Etage** und die Figurenstufe immer **Stufe** — nie „Level“, „Lv“ oder „Ebene“. | R | 1 |
| S-2 | Staffel | Ein Zyklus = **eine Staffel**: höchstens 18 Etagen, Dauer 2/3/4/5 Tage, danach je 5 Tage → **84 Tage**. Jede Etage hat einen festen Einsturztermin; wer fertig ist, darf früher absteigen. | R | 2.4 |
| S-3 | Treppenregel | **Höchstens eine Etage Vorlauf**: Die Treppe führt nur auf die Etage direkt unter der Etage, die gerade „auf Sendung“ ist. Folge: Die ganze Besetzung ist immer auf zwei benachbarten Etagen. | D | 2.6 |
| S-4 | Einsturz | **Mit Netz** (Normal): die Regie rettet — Rettungsgebühr (−30 % Credits, −10 % Follower), keine Etagen-Bilanz, weiße Weste weg. **Ohne Netz** (Hardcore, ein Leben wie im Buch): raus → Studiogast mit eigenem Titel. | R | 2.5, 7 |
| S-5 | Tod | Mit Netz: Wiederbelebung im zuletzt besuchten Safe Room der Etage, −10 % Credits, weiße Weste weg. Ohne Netz: endgültig. | R | 7 |
| S-6 | Besetzung | **100 Plätze** je Staffel (einstellbar 20–100). Start jederzeit, sobald die Mindestzahl Menschen da ist (privat 1, Freunde 2, öffentlich 10); freie Plätze spielt die **KI** (abstraktes Populationsmodell, in der Nähe der Spieler:in als NPC mit der 07-KI). Viele Staffeln laufen parallel. | R | 2.2, 4 |
| S-7 | Ausloggen | Überall außerhalb des Kampfes; die Figur bleibt als **Schläfer**. Safe Room = sicher + **Ausgeruht**; im Gang kommen bis zu 3 Streifen, gegen die die Figur mit ihrer Taktik kämpft; Ergebnis beim nächsten Login („Während Sie schliefen …“), deterministisch und aufgezeichnet. | R | 5 |
| S-8 | Andere Spieler:innen | sehen, bewachen, heilen, wecken, handeln mit Schläfern — **nie angreifen**; PvP nur als Opt-in in **Show-Arenen**; ein späteres Opt-in-Regelwerk „Kopfgeld“ bleibt möglich. | R | 6 |
| S-9 | Fertigkeiten wie WoW | Fähigkeiten auf **festen Stufen** mit Vorschau „ab Stufe X“, kein Zufall; **Talentbaum** mit Reihen (je Reihe 1 aus 3), je Klasse mit zwei **Spezialisierungen**; die Talent-Show bleibt als TV-Präsentation; **Berufe** 1–300 mit Farben orange/gelb/grün/grau, Ausbildung im Safe Room, Rezepte. | R | 8 |
| S-10 | Vorleben | Vorsprung **50** im Beruf des Vorlebens und **25** im Beruf des Hobbys (gleicher Beruf: 75) **ersetzt die Starttalente aus 08** (CR-33). Privatsphäre, Persona-Command und Erzählstrang aus 08 bleiben. | R | 8.6 |
| S-11 | Phasen | **ST1** Offline-Staffel-Prototyp (ohne Server) → **ST2** Online-Staffeln asynchron → **ST3** Echtzeit-Präsenz. Der Echtzeitkampf (07 R1b–R5b) kommt zuerst; ST1 beginnt nach 07 R3. | R | 11 |
| S-12 | IP | Mechaniken (Etagen, Einsturz, Mitkandidat:innen, Spezies/Klasse auf Etage 3) sind frei; Namen, Begriffe, Figuren, Texte bleiben eigen. Im Spiel heißen Teilnehmende **Kandidat:innen**, nie „Crawler“. | R | 1.2, 11.7 |
| S-13 | Tempo | **Kalender** (online und privat: 1 Staffel-Tag = 24 h) oder **Am Stück** (nur private Offline-Staffeln: 1 Staffel-Tag = **10 min Erkundungszeit**, die Uhr läuft wie heute nur in der Erkundung — Etage 1 = 20:00 wie im Slice). Dazu ein Zeitraffer nur in Debug-Builds. | D | 2.1 |
| S-14 | Kampagne | Die bisherige Kampagne **wird zur privaten Staffel**: ein Regelwerk für alles, kein zweites Fortschrittssystem. SHOWRUN-Event-Läufe (05) bleiben ein eigener Modus ohne Staffel. | D | 2.1 |
| S-15 | Speichern | **Dauerspeicherstand**: Die Staffel speichert laufend, es gibt kein Zurückladen. Grundsatz **„Wer geht, wird zur KI“**: Ausloggen, Funkloch, Absturz — die Figur kämpft einen laufenden Kampf mit ihrer Taktik zu Ende und schläft danach. | D | 5.1 |
| S-16 | Stufen | **Höchststufe 50** (erreicht auf Etage 16), je Etage ein **Stufen-Band** mit **Deckel**; darunter **Aufholjagd** (EP × 2); Ausgeruht und Aufholjagd zusammen höchstens × 2. | D | 8.2 |
| S-17 | Fähigkeiten | **Fähigkeitenbuch**; die Leiste bleibt 4 + SHOW + Trank (07). Klassenfähigkeiten sind Varianten der Leistenplätze: beim Recall, dann auf Stufe 12/17/22/27/32, Rang II–IV auf 37/42/47. Merkregel ab Stufe 12: **Endet die Stufe auf 2 oder 7, gibt es eine Fähigkeit (ab 37 einen Rang); endet sie auf 0 oder 5, eine Talentreihe.** | D | 8.3 |
| S-18 | Talente | Reihen auf Stufe 3/5/7/9 (**Grundreihen** aus den heutigen 24 Talenten), 15/25/35/45 (**Klassenreihen**), 20/30/40/50 (**Figurenreihen**); je Reihe 1 aus 3, im Safe Room jederzeit kostenlos umwählbar. Ersetzt das Zufallsangebot „1 aus 2“ (06 §2.2). | D | 8.4 |
| S-19 | Berufe | Hauptberufe (höchstens 2): **Schrottsammeln, Pilzkunde, Ausschlachten** (Sammeln) und **Requisite, Labor, Kostüm** (Handwerk); Nebenberufe für alle: **Kochen, Erste Hilfe**. Ab Etage 2. Nur die Kandidat:in hat Berufe („Der Graf lässt arbeiten“). | D | 8.5 |
| S-20 | Was bleibt | Über Staffeln bleiben nur **Titel, Kosmetik, Ruhmeshalle und Konto-Erfolge** — nie Kampfkraft, Stufe, Ausrüstung, Credits oder Berufswerte. | D | 2.8 |
| S-21 | Etagen 4–18 | Fünf **Kulissen** × drei Etagen, prozedural; je Etage ein **wiederkehrender Revier-Boss** (Treppenschlüssel, eskaliert über die drei Etagen), je Kulisse ein großer **Etagenboss** auf ihrer letzten Etage, je Etage ein optionaler Show-Boss. | D | 3 |
| S-22 | Einstieg | Neue Kandidat:innen steigen **nur vor dem Start** ein (Lobby); öffentliche Staffeln starten laufend, sobald genug Leute warten. | D | 2.2 |
| S-23 | Versionen | Eine Staffel läuft auf **einer festen Regelversion** (`sim_version` + `data_hash`); Regeländerungen kommen zum Staffelwechsel, laufende Staffeln bekommen nur regelneutrale Fehlerkorrekturen. | D | 9.1 |
| S-24 | Geld | 05/06 bleiben: Echtgeld nur an den Betreiber, Zuschauer-Hilfe nur in Sponsor-Fenstern, Pur-Liga. **Nichts an einer Staffel ist käuflich** — keine Rettung, keine EP, kein Ausgeruht, kein Platz, kein Leben. | R/D | 10 |

### 0.4 Ein-Satz-Erklärungen (UX-Vertrag, 06 L-1)

| System | Ein Satz (so sagt es M.O.D. beim ersten Mal, sinngemäß) | Erstes Auftreten |
|---|---|---|
| Staffel | „Willkommen in Staffel 37! Achtzehn Etagen, zwölf Wochen, und jede Etage stürzt pünktlich ein.“ | Intro |
| Einsturz | „Diese Etage stürzt in zwei Tagen ein. Seien Sie dann woanders. Am besten tiefer.“ | Etage 1, Tutorial-Ende |
| Vorlauf | „Fertig? Dann dürfen Sie eine Etage vorgehen. Weiter baut die Regie noch nicht.“ | erste Treppe |
| Rettung | „Gerettet! Die Rechnung kommt mit der Post. Eigentlich sofort.“ | erster Einsturz (Mit Netz) |
| Ohne Netz | „Ein Leben. Keine Rettung. Das Publikum liebt das. Sie hoffentlich auch.“ | Staffelwahl |
| Ausloggen / Schläfer | „Sie gehen? Ihre Figur bleibt. Im Safe Room schläft sie sicher — im Gang eher nicht.“ | erstes Ausloggen |
| Ausgeruht | „Ausgeruht! Die nächsten Kämpfe bringen doppelte Erfahrung. Schönheitsschlaf zahlt sich aus.“ | erster Login nach Safe-Room-Schlaf |
| Aufholjagd | „Sie hängen hinterher. Bis Sie aufgeholt haben, zählt jede Erfahrung doppelt.“ | erstmals unter dem Band |
| Talentbaum | „Talent-Show! Eine neue Reihe, drei Talente, eins nehmen Sie. Umentscheiden dürfen Sie im Safe Room.“ | Stufe 3 (Etage 1) |
| Fähigkeitenbuch | „Neue Fähigkeit! Legen Sie sie im Fähigkeitenbuch auf die Leiste.“ | erste neue Fähigkeit |
| Recall | „Recall! Wer wollen Sie sein? Und was wollen Sie können?“ (06 §0.5, 08 C-16) | Etage 3, Safe Room |
| Berufe | „Das Gewerke-Büro sucht Leute. Zwei Hauptberufe, dazu Kochen und Erste Hilfe für alle.“ | Etage 2, 1. Safe Room |
| Vorleben-Vorsprung | „Ihr Vorleben zählt: Was Sie draußen konnten, können Sie hier ein bisschen schon.“ | Etage 2, Gewerke-Büro |
| KI-Kandidat:innen | „Sie sind nicht allein. Die anderen Kandidat:innen auch nicht. Einige sind sogar nett.“ | Etage 1, erste Eilmeldung |
| Weiße Weste | „Noch nie gerettet, noch nie gestorben: weiße Weste. Davon gibt es nicht mehr viele.“ | Etage 2, Zähler |

**06 L-2 bleibt erfüllt:** Etage 1 bringt keine neue Spielregel dazu. Der Einsturz ist der bisherige Countdown in anderem
Takt, Schläfer und Ausgeruht erklären sich beim ersten Ausloggen (Systemregel, keine Etagenregel), KI-Kandidat:innen
erscheinen auf Etage 1 nur als Eilmeldungen im vorhandenen Chat-Ticker. Der Kandidatenzähler im HUD kommt mit Etage 2,
die Berufe ersetzen dort die Fanclubs (CR-31), der Recall bleibt auf Etage 3.

### 0.5 Bewusst nicht drin

Auktionshaus; Angeln und weitere Nebenberufe; Haltbarkeit und Reparatur; Talentpunkte zum Verteilen (es gibt nur Reihen);
Ränge einzelner Fähigkeiten (nur drei Rang-Stufen je Klasse); Doppelklasse; Späteinstieg in laufende Staffeln; mehr als
eine laufende Online-Staffel je Konto; PvP in der Welt; Angriffe auf Schläfer; käufliche Rettungen, EP oder Leben; Fanclubs
vor Etage 4 (CR-31); Gäste der KI im Bosskampf; frei laufende KI-Kandidat:innen vor ST3.

---

## 1. Begriffe

### 1.1 Glossar

| Begriff (UI) | Bedeutung | Nutzerwort | Code / ID |
|---|---|---|---|
| **Staffel** | Ein Spielzyklus: bis zu 18 Etagen, fester Sendeplan, eine Besetzung. „Staffel 37“ = laufende Nummer der Instanz. | Spielzyklus | `ssn_` (Vorlage), `SeasonState` |
| **Folge** | TV-Wort für eine Etage der Staffel („Staffel 37 · Folge 5“), nur auf der Kandidatenkarte (08 §1.4) und in M.O.D.-Ansagen. | — | — |
| **Sendeplan** | Tabelle der Einsturztermine aller Etagen (Kap. 2.4). | — | `SeasonClock` |
| **Etage** | Ein Stockwerk des Dungeons (1–18). Immer „Etage“. | Ebene | `floor_index` |
| **Auf Sendung** | Die Etage, deren Einsturz als nächster kommt. | — | `on_air_floor` |
| **Vorlauf** | Die Etage direkt darunter; sie ist schon offen (Kap. 2.6). | — | `open_floor_max` |
| **Einsturz** | Das Ende einer Etage zu ihrem Termin. Wer dann noch dort ist, wird gerettet (Mit Netz) oder ist raus (Ohne Netz). | — | `collapse` |
| **Rettung** | Regie holt eine Figur beim Einsturz auf die nächste Etage — gegen Gebühr (Kap. 2.5). | — | `rescue` |
| **Stufe** | Erfahrungsstufe einer Figur (1–50). Immer „Stufe“. | Level | `level` |
| **Stufen-Band / Deckel** | Stufen, für die eine Etage gebaut ist; der Deckel ist das Bandende (Kap. 8.2). | — | `LevelBand` |
| **Aufholjagd** | EP × 2, solange die Stufe unter dem Band der Etage liegt. | — | `catch_up` |
| **Ausgeruht** | Vorrat aus Safe-Room-Schlaf; verdoppelt Kampf-EP, bis er verbraucht ist. | Erholung | `rested` |
| **Vorleben** | Der echte Job aus dem Casting (08 Bildschirm 2/3, bisher „Beruf“). Bringt einen Berufs-Vorsprung. | Beruf (im Casting) | `org_*`, `occ_*` |
| **Spezies** | Wer man ab Etage 3 ist (06 §3.2). | Spezies | `spc_*` |
| **Klasse** | Was man ab Etage 3 kann: Rolle und Kampffähigkeiten (06 §3.3 nannte sie „Spezialisierung“). | Beruf ab Ebene 3 | `cls_*` |
| **Spezialisierung** | Einer der zwei Äste im Talentbaum einer Klasse (z. B. „Bollwerk“ und „Abrissunternehmen“). | — | `spec` an Talenten |
| **Recall** | Die Runde auf Etage 3, in der Spezies und Klasse gewählt werden (08 C-16). | — | Command `casting` |
| **Fähigkeit** | Etwas für die Kampfleiste (07 §4). | Skill | `skl_*` |
| **Talent / Talentreihe** | Passiver Bonus; je Reihe wählt man eines von drei (Kap. 8.4). | Skill | `tal_*` |
| **Beruf** | Handwerk wie in WoW: Haupt- oder Nebenberuf, Wert 1–300 (Kap. 8.5). | — | `job_*` |
| **Kandidat:in** | Jede:r Teilnehmende der Staffel, Mensch oder KI. | Crawler | `cast` |
| **Besetzung** | Alle Kandidat:innen einer Staffel (100 Plätze). | — | `CastSim` |
| **Schläfer** | Eine ausgeloggte Figur, die in der Welt bleibt. | — | `sleeper` |
| **Weiße Weste** | Nie gerettet und nie gestorben (nur Mit Netz). | — | `vest` |
| **Mit Netz / Ohne Netz** | Staffelart Normal / Hardcore. | Normal / Hardcore | `mode`: `normal` / `hardcore` |
| **Studiogast** | Wer in „Ohne Netz“ ausgeschieden ist: schaut zu, kommentiert mit Schnellsätzen. | — | `spectator` |
| **Kalender / Am Stück** | Tempo der Staffel-Uhr (Kap. 2.1). | — | `tempo`: `calendar` / `binge` |
| **Kulisse** | Thema einer oder dreier Etagen (Kap. 3). | — | `thm_*` |

### 1.2 Sprachregel für UI, Daten und Zeilen

1. **„Stufe“** für Figurenstufen und Gegnerstufen („Stufe 12“, „ab Stufe 15“). Nie „Level“, „Lv“, „LV“. In engen Anzeigen
   (Party-Rahmen, Plakette, Namensschild) steht nur die **Zahl in einer runden Stufen-Plakette**; der Tooltip sagt „Stufe 12“.
2. **„Etage“** für Stockwerke („Etage 3“). Nie „Level“ oder „Ebene“. „E3“ nur in Dokumenten.
3. **„Rang“** für Rangstufen von Talenten (bis zur Migration) und Berufen („Rang: Assistenz“); **„Liga 1 / Duo-Liga“** statt
   „Stufe 1 / Stufe 2“ der Unterhosen-Liga (Code `liga_tier` bleibt).
4. **„Kandidat:in“** statt „Crawler“; **„Klasse“** statt „Spezialisierung“ für `cls_*`; **„Vorleben“** statt „Beruf“ im Casting.
5. Bezeichner im Code bleiben englisch (`level`, `LEVEL_CAP`, `floor_index`); die Regel gilt für alles, was Spieler:innen lesen.
6. **Lint-Test** `test_09_terms`: durchsucht `data/*.json` (`name`, `desc`, `text`) und Stringliterale in `scenes/**/*.gd`
   nach `\bLevel\b`, `\bLv\b`, `\bLV\b`, `\bEbene\b`, `\bCrawler\b` (Wortgrenzen, Groß-/Kleinschreibung beachtet — Schlüssel
   wie `"level"` und Platzhalter wie `{level}` bleiben erlaubt) und schlägt fehl — Ausnahmen nur per Kommentar
   `# terms-ok: <Grund>` (z. B. Debug-Overlay).

**Fundstellen heute** (Stand `b9d278a`; Umsetzung in ST1-A, Dateieigentum Kap. 11.4):

| Datei | Heute | Neu |
|---|---|---|
| `scenes/ui/party_menu.gd:76` | `"Lv %d"` | Stufen-Plakette (Zahl), Tooltip `"Stufe %d"` |
| `scenes/ui/party_menu.gd:122` | `"Spezies & Klasse: Casting ab Etage 3"` | `"Spezies & Klasse: beim Recall auf Etage 3"` |
| `scenes/ui/party_menu.gd:142` | `"noch keine (ab Level 3)"` | `"erste Talentreihe ab Stufe 3"` |
| `scenes/ui/bestiary_menu.gd:85` | `"Lv %d  ·  besiegt: %d"` | `"Stufe %d  ·  besiegt: %d"` |
| `scenes/ui/bets_menu.gd:132, :139` | `"Stufe 1 … Stufe 2 (Duo-Liga)"` | `"Liga 1 … Duo-Liga"` |
| `scenes/ui/talent_show.gd:145` | `"Neue Wahl ab dem nächsten ungeraden Level (3, 5, 7, 9)."` | `"Nächste Talentreihe ab Stufe %d."` |
| `scenes/ui/talent_show.gd:157` | `"%s  ·  Level %d"` | `"%s  ·  Stufe %d"` |
| `scenes/ui/talent_show.gd:253, :255` | `"Stufe %d von %d"` (Talentrang) | entfällt mit dem Talentbaum (bis dahin `"Rang %d von %d"`) |
| `scenes/ui/exploration_hud.gd:688` | `"Lv %d"` | Stufen-Plakette |
| `scenes/ui/skills_menu.gd:82, :155` | `"ab Lv %d"`, `"Wird mit Level %d gelernt."` | `"ab Stufe %d"`, `"Ab Stufe %d."` |
| `scenes/title/slot_select.gd:219` | `"Level %d"` | `"Stufe %d"` (dazu `"Staffel · Tag %d"`) |
| `scenes/battle/ui/battle_results.gd:276, :497, :503` | `"Lv %d"` | CTB, entfällt mit 07 R5b; bis dahin `"Stufe %d"` |
| `data/achievements.json:216` | „Bring die Spielfigur auf Level 5.“ | „Bring die Spielfigur auf Stufe 5.“ |
| `data/mod_lines.json:996` | „Level up! Sie sind jetzt {level}% weniger verzichtbar.“ | „Stufenaufstieg! Sie sind jetzt {level}% weniger verzichtbar.“ |
| `data/mod_lines.json:1588` | „Level fünf. Sie sind jetzt offiziell schwer zu ersetzen.“ | „Stufe fünf. Sie sind jetzt offiziell schwer zu ersetzen.“ |
| `README.md:51` | „Ab Level 3 bringt jedes ungerade Level …“ | „Ab Stufe 3 bringt jede ungerade Stufe …“ (Inhalt mit F-1) |
| `docs/00_BRIEF.md:21, :64` | „Etagen („Level“)“, „Level/EXP … Fähigkeiten nach Level“ | „Etagen“, „Stufe/EP … Fähigkeiten nach Stufe“ (CR-25) |
| `docs/00_BRIEF.md:23, :25` | „die System-KI“, „ein Mensch wie alle Crawler“ | „die Show-KI“, „ein Mensch wie alle Kandidat:innen“ (CR-25; wörtliche Zitate bleiben) |
| `docs/01_GDD.md` §4, §4.7, §13, §14; `06` §0.1 Nr. 3, §2.2, §2.3; `02_TECH` §6.5 | „Level“ für Figurenstufen | „Stufe“ (CR-26, CR-27, CR-31) |

Die Ursache der Verwechslung, die die Idee anspricht, steht so im Party-Menü nebeneinander: „Casting ab **Etage** 3“ und
„Talente … ab **Level** 3“. Mit der Regel heißt es „Recall auf Etage 3“ und „Talentreihe ab Stufe 3“.

---

## 2. Staffel-Ablauf

### 2.1 Staffelarten und Tempo

| Art | Wer | Tempo | Mindestbesetzung (Menschen) | Phase |
|---|---|---|---|---|
| **Privat** | Sie allein, Rest KI; offline | **Kalender** (wie im Fernsehen) oder **Am Stück** | 1 | ST1 |
| **Freunde** | 2–100 eingeladene Menschen, Rest KI | Kalender | 2 | ST2 |
| **Öffentlich** | Warteschlange, Rest KI | Kalender | 10 (einstellbar) | ST2 |

| Tempo | Staffel-Uhr | Einsturz | Schläfer / Ausgeruht | Wofür |
|---|---|---|---|---|
| **Kalender** | 1 Staffel-Tag = 24 h echte Zeit; die Uhr läuft immer, auch ausgeloggt | zur **Sendezeit** der Staffel (privat wählbar, Standard 20:00 Ortszeit; online je Staffel fest in UTC) | ja | online; privat für Serienfans |
| **Am Stück** | 1 Staffel-Tag = **10 min Erkundungszeit**; die Uhr steht in Kampf, Safe Room, Menüs, Dialogen (wie GDD §2.9) | zu denselben Terminen des Sendeplans, gerechnet in Erkundungszeit: Sendezeit je Etage 20/30/40, ab Etage 4 je 50 min (Etage 1 = heutiger 20:00-Timer) | nein (die Welt wartet) | Offline-Spiel in eigenem Tempo; Barrierefreiheit |
| **Zeitraffer** | Kalender × Faktor (z. B. 1 min = 1 Tag) | wie Kalender | ja | nur Debug-Builds und Harness |

**Warum „Am Stück“:** Ein Premium-Spiel darf niemanden zum Warten zwingen (04 §6.2 Nr. 3). „Am Stück“ ist zugleich die
heutige Kampagne: Etage 1 hat dort genau ihre 20:00, die Bänder aus GDD §13 gelten unverändert. Damit wird die Kampagne zur
privaten Staffel (S-14), und der Vertical Slice bleibt gültig.

### 2.2 Lobby und Start

- **Privat:** „Neue Staffel“ im Titel → Tempo, Staffelart (Mit Netz / Ohne Netz), Sendezeit (nur Kalender) → Figurenwahl →
  Casting (08) → Intro → Etage 1. Die drei Speicherplätze sind drei private Staffeln.
- **Freunde (ST2):** Die Gastgeber:in legt die Staffel an und lädt ein; **„Staffel starten“** geht, sobald die Mindestzahl
  (2) da ist. Die Gastgeber:in wählt Sendezeit und Staffelart.
- **Öffentlich (ST2):** Eine Warteschlange je Region und Staffelart. Sobald **10** Menschen warten, beginnt der Countdown
  „Gleich geht's los“ (15 min); bis dahin können weitere dazukommen (höchstens 100). Danach öffnet sofort die nächste
  Warteschlange.
- **Einstieg nur vor dem Start** (S-22). Wer später kommt, nimmt die nächste Staffel — es starten laufend welche.
- **Je Konto höchstens eine laufende Online-Staffel**; private Staffeln liegen lokal in den drei Plätzen.
- Beim Start bekommt die Staffel einen Seed, eine Nummer („Staffel 37“), ihre feste Regelversion (S-23) und die KI-Besetzung
  für die freien Plätze (Kap. 4).

### 2.3 Besetzung

- **100 Plätze** (Vorlage `ssn_standard`; einstellbar 20–100). Menschen nehmen Plätze, die übrigen bekommen
  KI-Kandidat:innen.
- Der **Kandidatenzähler** zeigt Mit Netz „**Weiße Weste: 41/100**“ und Ohne Netz „**Noch dabei: 41/100**“ (HUD ab Etage 2
  neben dem LIVE-Badge, vorher nur im Pausemenü-Reiter „Staffel“).
- KI-Kandidat:innen folgen denselben Regeln wie Menschen (Treppe, Einsturz, Tod) und sind überall als **KI** gekennzeichnet.

### 2.4 Sendeplan

Dauer je Etage: 2, 3, 4, dann je 5 Tage. „Offen ab“ = ab wann die Etage als Vorlauf betretbar ist (Kap. 2.6).

| Etage | Dauer | Auf Sendung (Tag) | Einsturz am Ende von Tag | Offen ab Tag | Am Stück (Erkundungszeit) | Stufen-Band |
|---|---|---|---|---|---|---|
| 1 | 2 | 0–2 | 2 | 0 | 20 min | 1–7 |
| 2 | 3 | 2–5 | 5 | 0 | 30 min | 7–10 |
| 3 | 4 | 5–9 | 9 | 2 | 40 min | 10–13 |
| 4 | 5 | 9–14 | 14 | 5 | 50 min | 13–16 |
| 5 | 5 | 14–19 | 19 | 9 | 50 min | 16–19 |
| 6 | 5 | 19–24 | 24 | 14 | 50 min | 19–22 |
| 7 | 5 | 24–29 | 29 | 19 | 50 min | 22–25 |
| 8 | 5 | 29–34 | 34 | 24 | 50 min | 25–28 |
| 9 | 5 | 34–39 | 39 | 29 | 50 min | 28–31 |
| 10 | 5 | 39–44 | 44 | 34 | 50 min | 31–34 |
| 11 | 5 | 44–49 | 49 | 39 | 50 min | 34–37 |
| 12 | 5 | 49–54 | 54 | 44 | 50 min | 37–40 |
| 13 | 5 | 54–59 | 59 | 49 | 50 min | 40–43 |
| 14 | 5 | 59–64 | 64 | 54 | 50 min | 43–46 |
| 15 | 5 | 64–69 | 69 | 59 | 50 min | 46–49 |
| 16 | 5 | 69–74 | 74 | 64 | 50 min | 49–50 |
| 17 | 5 | 74–79 | 79 | 69 | 50 min | 50 |
| 18 | 5 | 79–84 | **84** | 74 | 50 min | 50 (Finale) |

- **Summe:** 84 Tage = 12 Wochen ≈ 2,8 Monate (Wunsch: 2–3 Monate). Am Stück: 840 min = 14 h Erkundungszeit, mit Kämpfen,
  Safe Rooms und Menüs ≈ 25–30 h Spielzeit **[Schätzung]**.
- Die Variante der Idee (+1 Tag je Etage bis 19) ergäbe **189 Tage ≈ 6 Monate** — deshalb der Deckel bei 5 Tagen.
- **Kürzere Formate** schneiden den Plan nach Etage N ab: 6 Etagen = 24 Tage, 9 = 39, 12 = 54 Tage. So wächst das Format mit
  dem Inhalt (Roadmap, CR-29), ohne dass sich eine Regel ändert. „Höchstens 18“ (Idee) ist damit wörtlich erfüllt.
- **Tag 0** beginnt zur Sendezeit des Starttags (wer früher startet, spielt schon im „Vorprogramm“); alle Einstürze liegen
  auf der Sendezeit — so passieren sie abends, nie nachts.

### 2.5 Einsturz

1. Zum Termin der Etage, die **auf Sendung** ist, stürzt sie ein. Wer dort steht (eingeloggt oder als Schläfer), ist betroffen;
   wer schon im Vorlauf ist, nicht.
2. **Im Kampf** wartet der Einsturz bis zum Kampfende (die Sim kennt keine Uhr, 07 §2.10; fair und deterministisch).
3. **Mit Netz → Rettung:** 3-s-Einsturzszene (GDD §2.9) → die Figur steht im ersten Safe Room der neuen Etage auf Sendung.
   Gebühr: **−30 % Credits, −10 % Follower**; die Etagen-Bilanz der eingestürzten Etage entfällt (keine Abschluss-EP, kein
   Bilanz-Bonus); **weiße Weste weg**. Liegt die Stufe danach unter dem Band, greift die Aufholjagd (Kap. 8.2).
4. **Ohne Netz → raus:** Einsturzszene → Sendeschluss-Bild (GDD §14.6) mit Titel „Verschüttet auf Etage N“ → **Studiogast**
   (Kap. 7.2).
5. **Warnungen:** HUD 1 h, 10 min, 1 min vorher (Kalender) bzw. 10:00/5:00/1:00 Restzeit (Am Stück, wie heute); dazu die
   Benachrichtigungen aus Kap. 2.9.
6. Wer vor dem Einsturz die Treppe genommen hat, bekommt die **Etagen-Bilanz** wie heute (GDD §2.8) plus Abschluss-EP
   (Kap. 8.2).

### 2.6 Treppenregel: höchstens eine Etage Vorlauf

**Regel in einem Satz:** Die Treppe führt nur eine Etage tiefer als die Etage, die gerade auf Sendung ist.

- Auf Sendung ist Etage N. Wer N geschafft hat (Treppe offen, Revier-Boss besiegt, Kap. 3.2), darf sofort auf **N+1**. Dort
  zeigt die Treppe nach N+2 bis zum Einsturz von N: „**Etage N+2: Kulissen im Aufbau — öffnet in 1 T 6 Std.**“ (M.O.D.:
  „Die Regie baut immer nur eine Etage im Voraus. Sparmaßnahme.“)
- Stürzt N ein, ist N+1 auf Sendung, und die Treppe nach N+2 öffnet.

**Begründung:**

| Ziel | Wie die Regel es erfüllt |
|---|---|
| Schnelle warten nicht wochenlang | Höchstens die Restdauer einer Etage (≤ 5 Tage), und auch dann nie untätig: Sie spielen schon die nächste Etage (Vorlauf), haben Optionales (Etagenboss, Show-Boss, Geheimnisse, Berufe, Vorlieben, Pechvogel-Hilfe) und sammeln Ausgeruht. Am Stück wartet man höchstens Minuten Erkundungszeit. |
| Langsame sind nie hoffnungslos hinten | Niemand ist hinter der Etage auf Sendung: Der Einsturz rettet nach vorn (Mit Netz). Aufholjagd (EP × 2 unter dem Band) und Ausgeruht holen die Stufen schnell auf. |
| Die Besetzung bleibt zusammen | Alle stehen immer auf **zwei benachbarten Etagen** — wichtig für gemeinsame TV-Momente (der Recall auf Etage 3 liegt für alle in derselben Woche, das Finale ebenso), für Ranglisten und für ST3 (volle Etagen-Instanzen statt leerer). |
| Kein Davonleveln | Zusammen mit dem Stufen-Deckel je Etage (Kap. 8.2) kann niemand den Inhalt der nächsten Etage überrollen. |
| Einfach | Eine Zahl („eine Etage voraus“), eine sichtbare Anzeige an der Treppe. |

### 2.7 Staffelende, Finale, Wertung, Titel

- Auf **Etage 18** gibt es keine Treppe, sondern das **Große Finale** (Etagenboss „Die Sendeleitung“, Kap. 3.1). Wer es vor dem
  Einsturz an Tag 84 besiegt, hat die Staffel **geschafft**: Abspann, Staffel-Bilanz, Titel „Finalist:in“. Danach ist man
  Studiogast der restlichen Staffel (Kap. 7.2), ohne Titelverlust.
- **Tag 84:** Einsturz von Etage 18 = Staffelende für alle. Wer noch lebt, aber das Finale nicht geschafft hat: „Bis zum Ende
  dabei“. Die Figur wandert in die **Ruhmeshalle** (ansehen, nicht weiterspielen).
- **Staffel-Quote** (Rangliste, Ganzzahlen, Startwerte): Etagen per Treppe × 1 000 + Revier-Bosse × 200 + Etagenbosse × 500 +
  Finale 3 000 + Achievements × 50 + ⌊min(Follower, 20 000) / 10⌋ − Rettungen × 500 − Tode × 200. Gleichstand: früheres
  Finale, dann früherer letzter Abstieg.
- **Titel** (nur Menschen; die Rangliste zeigt KI-Kandidat:innen mit Kennzeichnung, Titel gehen nach der Menschen-Rangfolge):

| Titel | Bedingung |
|---|---|
| Finalist:in der Staffel N | Großes Finale besiegt |
| Weiße Weste | Finale ohne Rettung und ohne Tod (Mit Netz) |
| Überlebende:r — Ohne Netz | Finale in einer Staffel „Ohne Netz“ |
| Erstbesteiger:in Etage N | erster Mensch der Staffel auf Etage N (für N = 3, 6, 9, 12, 15, 18) |
| Quotenkönig:in / Platz 2 / Platz 3 | Staffel-Quote, Menschen-Rangfolge |
| Legende: <Beruf> | Beruf auf 300 |
| Studiogast, verschüttet / gefallen auf Etage N | Ohne Netz ausgeschieden (Erinnerungskarte in der Ruhmeshalle) |

- Belohnungen sind **nur kosmetisch** (Kostüme für Kandidat:in und Graf, Kartenrahmen, Studio-Deko); die Liste wächst mit
  den Staffeln.

### 2.8 Was zurückgesetzt wird und was bleibt

| Bleibt (Konto, „Karriere“) | Neu je Staffel |
|---|---|
| Titel, Kosmetik, Kartenrahmen, Ruhmeshalle (alle früheren Figuren), Konto-Erfolge, freigeschaltete Looks (08 K2), Einstellungen; die Kandidatenkarte darf wiederverwendet werden („Gleiche Karte wie letzte Staffel?“) | Stufe, Ausrüstung, Inventar, Credits, Lootboxen, Berufe und Rezepte, Talente, Spezies, Klasse, Follower, Etagen, Zähler |

**Grundsatz:** Was eine Staffel überdauert, ist nie Kampfkraft. Neue Kandidat:innen treten fair gegen Erfahrene an.

### 2.9 Benachrichtigungen

| Anlass | Wann | Kanal (ST1 / ab ST2) |
|---|---|---|
| Einsturz droht (Sie stehen auf der Etage auf Sendung und haben die Treppe nicht genommen) | 24 h und 3 h vorher (Mit Netz); 24 h, 3 h und 30 min vorher (Ohne Netz) | lokale Benachrichtigung / Push |
| Neue Etage offen (Sie warten im Vorlauf) | beim Öffnen | dto. |
| Ausgeruht voll | einmal, optional | dto. |
| Ihr Schläfer hat gekämpft | ab ST2 sofort (Server); ST1 erst beim Login | — / Push |
| Geweckt / bewacht von jemandem | ab ST3 | Push |

Regeln: **Opt-in** beim ersten Ausloggen („Sollen wir Sie vor dem Einsturz wecken?“); höchstens 3 je Tag; Ruhezeit 22–8 Uhr
Ortszeit (eine Warnung, die hineinfiele, kommt um 21:59; bei der Standard-Sendezeit 20:00 passiert das nie, öffentliche
Staffeln gibt es je Region mit passender Sendezeit); neutrale Texte ohne Schuld- oder Verlustdrohung („Etage 5 stürzt morgen
um 20 Uhr ein.“); jederzeit abschaltbar. Desktop ohne Systemmitteilungen zeigt die Warnung im Titel und in der
Login-Bilanz. Lokale Benachrichtigungen unter Android/iOS mit Godot 4.7 **[Plugin zu prüfen]**.

---

## 3. Etagen 1–18

### 3.1 Übersicht

| Etage | Kulisse | Tage je Etage | Stufen-Band | Räume (Viertel) | Safe Rooms | Revier-Boss (Pflicht, trägt den Treppenschlüssel) | Etagenboss (optional) | Stand |
|---|---|---|---|---|---|---|---|---|
| 1 | **Die Unterstadt** (U-Bahn) | 2 | 1–7 | 31 (4, handgebaut) | 3 | Der Hausmeister | Die Rattenkönigin von Gleis 9 | gebaut |
| 2 | **Passage Ewiger Rabatt** (Einkaufspassage) | 3 | 7–10 | 18–24 (2) | 2–3 | Die Filialleiterin im Dauerlächeln (Idee GDD §15) | Der Ausverkauf (Idee GDD §15) | Stub: 3 Gegner, Daten `floor_2`, Entwurf 07 §6.8 |
| 3 | **Der Fundus** (Requisiten- und Kostümlager des Senders; **Recall**) | 4 | 10–13 | 26–32 (3) | 3 | Die Requisiteurin | Die Garderobe | neu |
| 4–6 | **Das Paketzentrum** (Förderbänder, „Zustellversuch gescheitert“) | 5 | 13–16 · 16–19 · 19–22 | 36–48 (3–4) | 3–4 | Die Schichtleiterin (wiederkehrend) | E6: Der Paketberg | neu |
| 7–9 | **Amt für Etagenwesen** (Wartemarken, Formular-Golems, Stempel) | 5 | 22–25 · 25–28 · 28–31 | 36–48 (3–4) | 3–4 | Der Sachbearbeiter (wiederkehrend) | E9: Der Nummernautomat | neu |
| 10–12 | **Erlebnisbad Chlorado** (Rutschen, Chlornebel, Wellenbecken) | 5 | 31–34 · 34–37 · 37–40 | 36–48 (3–4) | 3–4 | Die Bademeisterin (wiederkehrend) | E12: Die Wellenmaschine | neu |
| 13–15 | **Rechenzentrum „Wolke 7“** (Serverracks, Kühlung, Kabel) | 5 | 40–43 · 43–46 · 46–49 | 36–48 (3–4) | 3–4 | Der Admin (wiederkehrend) | E15: Der Kabelkrake | neu |
| 16–18 | **Das Hauptstudio** (NOVA-Kulissen, Kameras, Maske, Regie) | 5 | 49–50 · 50 · 50 | 36–48 (3–4) | 3–4 | Die Aufnahmeleitung (wiederkehrend) | E18: **Die Sendeleitung** (Großes Finale, Pflicht für den Staffelsieg) | neu |

Einsturztermine und Am-Stück-Zeiten: Sendeplan Kap. 2.4.

Alle Namen sind Arbeitstitel **[Namens- und Markenrecherche zu prüfen, 04 Kap. 2.5]**; keine Kulisse übernimmt Themen oder
Reihenfolge der Buchetagen (04 Kap. 2.2). Die Satire zielt wie bisher auf TV, Werbung, Logistik und Bürokratie (06 L-3/L-7).
„Senderzentrale“ bleibt der Name des späteren Hubs (06 §7), deshalb heißt die letzte Kulisse „Hauptstudio“.

### 3.2 Bausteine jeder Etage

| Baustein | Regel |
|---|---|
| **Treppe** | Hinter einem Tor; den **Treppenschlüssel** trägt der Revier-Boss (wie `key_master` auf Etage 1). Öffnet nur bis zur Vorlauf-Grenze (Kap. 2.6). Etage 18 hat keine Treppe: Der Schlüssel öffnet dort das Finalstudio mit dem Großen Finale. |
| **Revier-Boss** (Anzeigename nach 04 E2; bis zur Entscheidung „Quartier-Boss“) | Pflicht. Je Kulisse **eine wiederkehrende Figur**, die mit jeder Etage eine Phase oder Mechanik dazulernt („Die Schichtleiterin ist zurück. Mit Hubwagen.“) — eine Figur, drei Kämpfe, wenig Modellbau. |
| **Etagenboss** | Optional, große Beute; auf Etage 1, 2, 3 und auf der letzten Etage jeder Kulisse (6, 9, 12, 15, 18). |
| **Show-Boss** | Optional, je Etage einer (goldgerahmte Elite-Gruppe mit einer Zusatzregel, 06 §2.6, 07 E26) — nur Daten. |
| **Viertel** | 3–4 Zonen mit eigener Palette, eigenem Gegnerpool, einem Safe Room je Viertel und einer **Gefahr** für Schläfer (ruhig/unruhig/gefährlich, Kap. 5.3). |
| **Nachschub** | Besiegte Gruppen kehren nach **einem Staffel-Tag** zurück (Kalender 24 h, Am Stück 10 min Erkundungszeit); Streuner wie heute (GDD §2.7). |
| **Fundstellen** | Je Viertel 4–6 Schrotthaufen bzw. Pilzbeete (Berufe, Kap. 8.5); Rückkehr nach einem Staffel-Tag. |
| **Events, Geheimnisse** | Etagen-Events aus dem Pool der Kulisse (vorhandene Typen, GDD §2.6), dazu ein **Pechvogel**-Event (Kap. 4.3); 1–3 Kulissenwände und Regie-Notizen (06 §2.7). |
| **Vorlieben** | M.O.D.s Vorlieben (06 §4): Kalender **je Staffel-Tag** neu, Am Stück je Etage (wie heute). |

### 3.3 Pensum: wie viel Spielzeit eine Etage erwartet

| Etage | Pflichtweg (Treppe + Revier-Boss) | Vollständig (alles, inkl. Etagenboss) | Kalender: Minuten je Tag für den Pflichtweg |
|---|---|---|---|
| 1 | ≈ 20 min | 25–30 min | 10 |
| 2 | ≈ 30 min | 40–50 min | 10 |
| 3 | ≈ 45 min | 60–75 min | 12 |
| 4–18 | ≈ 60 min | 90–120 min | 12 |

- **Gelegenheitsspiel mit 1 h am Tag ist bequem:** Eine 5-Tage-Etage bietet 5 h für 1–2 h Inhalt. Schon **20 min am Tag**
  reichen für den Pflichtweg; wer zwei Tage aussetzt, holt mit Ausgeruht und Aufholjagd auf.
- **Vielspieler:innen** schaffen Etage und Vorlauf in 1–2 Tagen; danach zählen Optionales, Berufe und (ab ST3) andere
  Spieler:innen. Mehr Stufen gibt es dafür nicht (Deckel), aber Credits („Überstunden“, Kap. 8.2), Material und Quote.
- Messung im Staffel-Harness (Kap. 11.6): Pflichtweg E4–E18 60–75 min, vollständig 90–120 min **[zu messen]**.

### 3.4 Skalierung von Gegnern, Beute und Bossen

- **Gegnerstufe:** Jede Gegnergruppe einer Etage hat eine Stufe im Band der Etage (Pflichtweg Bandmitte, Nebenwege bis
  Bandende + 1, Elite + 2). Werte wachsen über eine **Stufen-Tabelle** `enemy_level_pm[stufe]` in `data/rt_balance.json`
  (Ganzzahl-Promille, 07 §3.16): Grundwerte des Gegnertyps × Tabellenwert. Ein Gegnertyp funktioniert so auf drei Etagen.
- **Farben wie in WoW** am Namensschild: grau (≥ 6 Stufen unter Ihnen, 0 EP), grün (3–5 darunter), gelb (±2), orange (3–4
  darüber), rot (≥ 5 darüber, „Achtung“).
- **Beute:** Ausrüstung hat eine **Gegenstandsstufe** (= Bandmitte der Etage) und eine Seltenheit (Ramsch grau, gewöhnlich
  weiß, selten blau, episch lila; 06 §2.3). Werte aus Vorlagen je Platz und Figur × Gegenstandsstufe; Credits, Lootboxen
  und Kisten skalieren mit der Etage.
- **Bosse:** Revier-Bosse kommen aus einem **Boss-Baukasten**: Grundfigur + Phasen aus einem Katalog von Mechaniken (Adds,
  Telegraph-Welle, unterbrechenswerter Zauber, Schild, weiches Enrage; alles vorhandene 07-Bausteine `RtRule`/`phases`),
  je Auftritt eine Mechanik mehr. Etagenbosse sind handgebaut (07 §6.6/§6.7 als Muster).

### 3.5 Was es gibt und was gebaut werden muss

| Baustein | Heute | ST1 (Prototyp, Platzhalter erlaubt) | Produktion (Phase 4/5, 04) |
|---|---|---|---|
| Etage 1 | komplett | unverändert (Am Stück = heute) | Art-Upgrade |
| Etage 2 | Daten-Stub, 3 Gegner, Boss-Ideen | spielbar mit Platzhalter-Gegnern, Revier- und Etagenboss aus dem Baukasten | 8 Gegner, 2 Bosse |
| Etagen 3–18 | — | prozedural (Kap. 3.6), Kulissen als Palette + **Platzhalter-Familien** (umgefärbte E1/E2-Gegner mit Stufen-Skalierung), Revier-Bosse aus dem Baukasten, Etagenbosse als skalierte Platzhalter | 6 Kulissen × 8 Gegner, 6 wiederkehrende Revier-Bosse, 6 Etagenbosse, Musik, Events |
| Gegner-Skalierung | feste Werte je Typ | Stufen-Tabelle, Farben | Feinschliff je Kulisse |
| Beute-Skalierung | Etage-1-Tabellen | Vorlagen × Gegenstandsstufe, 6 Material-Stufen | Sets, Namen |
| Generator | Baum auf Raster, ≤ 3 Safe Rooms, 1 Revier-Boss | Generator v2 (Kap. 3.6) | Kulissen-Raumteile (03_ART) |

Ein Etagen-Template nach 04 R1 (8–10 Gegner, 2 Bosse) gilt jetzt **je Kulisse**, nicht je Etage — das hält 18 Etagen bei
8 Kulissen im Rahmen.

### 3.6 Prozedurale Generierung (Generator v2)

Der vorhandene `DungeonGenerator` (Baum auf Raster, deterministisch aus `floor_seed`, Wiederholversuche, Validierung) bleibt
für Etage 2 und wird für Etagen 3–18 erweitert (`core/dungeon/zone_generator.gd`, gerufen für `FloorDef` mit `zones`):

1. **Viertel nacheinander wachsen lassen:** Viertel k wächst mit dem heutigen Baumverfahren aus einer Anschlusszelle von
   Viertel k−1 (Raster 10×10 bis 13×13, je Viertel 10–14 Räume).
2. **Schleifen:** je Viertel 1–2 zusätzliche Türen zwischen benachbarten Zellen desselben Viertels (für mehrstündiges
   Erkunden; Abstand ≥ 4 Zellwechsel im Baum, damit Schleifen Wege abkürzen).
3. **Inhalt:** Treppe im letzten Viertel (tiefste Zelle), Tor davor mit Schlüssel des Revier-Bosses (Raum auf dem Pfad, wie
   `QB_PATH_FRAC`), Etagenboss an einer Sackgasse neben der Treppe, je Viertel ein Safe Room nahe dem Eingang, Show-Boss in
   einem Seitenviertel, Gruppen nach Tiefe gewichtet, Kisten, Fundstellen, Events aus dem Kulissen-Pool, 1–3 Kulissenwände.
4. **Gefahr je Viertel:** erstes Viertel ruhig, mittlere unruhig, das Viertel mit Treppe/Bossen gefährlich.
5. **Prüfregeln** wie heute (`FloorLayout.validate`) plus: jedes Viertel erreichbar, jede Fundstelle erreichbar, Pflichtweg
   Start → Revier-Boss → Treppe ohne Etagenboss, Safe Room in jedem Viertel.
6. **Leistung:** 36–48 Räume statt 31 — Bau der Erkundung nur für das aktuelle und die angrenzenden Viertel
   (Viertel-Streaming), Budgets 02_TECH §12.1 / `PERFORMANCE.md` **[zu messen]**.

Daten: `data/themes.json` (Präfix `thm_`: Palette, Gegnerpool je Viertel, Revier-Boss, Etagenboss, Event- und
Fundstellen-Pool, Musik) und je Etage ein Eintrag in `floors.json` mit `theme`, `variant` (1–3), `level_band`, `zones`,
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
| Zustand | Etage, Stufe, Fortschritt, Weste, Rettungen, Tode, raus | Sim |

**Takt:** je **Staffel-Stunde** ein Schritt für alle (Kalender: echte Stunde; Am Stück: 25 s Erkundungszeit). Je Schritt:
Fortschritt auf der Etage nach `pace` × `skill` × Etagenschwere; bei 100 % Abstieg (wenn die Treppenregel es erlaubt); Stufe
folgt dem Band; Todeswurf je Schritt nach Können und Etage (Mit Netz: Wiederbelebung, Weste weg; Ohne Netz: raus);
Einsturz wie für Menschen. Zufall nur aus `SeedUtil.derive(season_seed, "cast", index, hour)` — deterministisch,
wiederholbar, ohne Wanduhr. Kosten: 99 × 2 016 Stunden ≈ 200 000 kleine Schritte je Staffel — vernachlässigbar.

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
| **Gastauftritt** | Eine **Helfer:in** begleitet die Party für **3 Kämpfe** als zusätzliche Einheit `p2` (mit einer dritten Begleitfigur nach 06 §2.5: `p3`) mit der 07-Partner-KI (Taktik „Unterstützen“), nie im Bosskampf | Kosten: ein Gefallen (Pechvogel gerettet) oder Credits; Werte aus Klassenvorlage × Stufe (CR-32) |
| **Pechvogel** | Etagen-Event `candidate_in_need`: eine KI-Kandidat:in steckt in einem Kampf fest; helfen = normaler Kampf mit ihr als Gast | Belohnung: Follower + ein Gefallen; Absage hat keine Strafe |
| **Rival:in** | Vor der Tür des Revier-Bosses steht die Rival:in der Persona (08 §4.6) oder eine Rival:in aus dem Modell: Zeile vor dem Kampf, Zeitvergleich danach („Sie waren 4 Minuten schneller. Ich bin entsetzt.“) | rein erzählerisch, kein Wettkampf um Beute |
| **Händler:in** | Im Safe Room: kauft Hergestelltes, verkauft Material und Rezepte der Kulisse | Preise aus dem Automaten (`shop.gd`), Bestand je Tag |
| **Ab ST3** | KI-Kandidat:innen laufen sichtbar durch geteilte Etagen und kämpfen dort mit der 07-KI | Server-Sim (Kap. 9.3) |

### 4.4 Profile in einem Satz

- **Statist:in:** füllt Zähler und Ticker, taucht gelegentlich im Safe Room auf.
- **Rival:in:** ist immer knapp vor oder hinter Ihnen und sagt es.
- **Helfer:in:** kommt auf Wunsch für drei Kämpfe mit.
- **Händler:in:** kauft und verkauft im Safe Room.
- **Pechvogel:** braucht Hilfe — und erinnert sich daran.

### 4.5 Fairness

1. Gleiche Regeln, sichtbare Kennzeichnung (4.1).
2. Titel und Belohnungen nur nach der **Menschen-Rangfolge**; KI-Plätze stehen nur zur Unterhaltung in der Liste.
3. KI-Kandidat:innen beeinflussen nie Würfe, Beute, Bosse oder Einstürze der Menschen; Gastauftritte sind freiwillig und
   nie im Bosskampf (Boss-Bänder aus 07 §11 bleiben gültig).
4. Ihr Erfolg ist kalibriert (4.2), nicht geschönt: Sie sterben und scheitern sichtbar, damit der Zähler etwas bedeutet.

### 4.6 M.O.D., Eilmeldungen, Zähler

- Das Modell erzeugt **Ereignisse** (`CastEvent`: Abstieg, Erstbesteigung, Tod, Rettung, Ausscheiden, Etagenboss besiegt,
  Rekord). Daraus werden **Eilmeldungen** im Chat-Ticker und als M.O.D.-Zeile (Präfix `cast_`), höchstens **eine je 10 min
  Spielzeit**, nie im Kampf, wichtige zuerst („Eilmeldung: Bodo Bürste ist raus. Er wollte einen Rabattschild-Golem
  streicheln.“). Geschriebene Zeilen mit Platzhaltern `{cand}` `{floor}`; die KI (06 §5) darf später nur Varianten liefern.
- **Kandidatenzähler** (Kap. 2.3) und im Pausemenü-Reiter **„Staffel“**: Sendeplan, Rangliste, Ticker der letzten 24 h.
- Bei Ihrem Login fasst die Login-Bilanz die drei wichtigsten Meldungen zusammen (Kap. 5.4).

---

## 5. Schläfer und Ausloggen

### 5.1 Regeln

1. **Ausloggen geht überall außerhalb eines Kampfes** (Pausemenü „Ausloggen“, im Safe Room „Ausloggen | Weiter“). Die Figur
   bleibt als **Schläfer** genau dort.
2. **Wer geht, wird zur KI:** Ein Funkloch oder ein Absturz gilt als Ausloggen, im Kalender-Tempo auch mehr als **10 min
   Pause oder Hintergrund**. Ein laufender Kampf wird mit der eingestellten Taktik zu Ende gespielt (07 Autopilot, beide
   Einheiten KI; nach einem Absturz beim nächsten Start aus Spielstand und Run-Log), danach schläft die Figur.
3. **Dauerspeicherstand:** Jede Zustandsänderung wird gesichert (S-15); es gibt kein Zurückladen eines älteren Stands.
4. **Am Stück** steht die Uhr, solange niemand spielt: Ausloggen ist dort immer sicher, es gibt weder Streifen noch
   Ausgeruht.
5. **Vor dem Ausloggen** zeigt ein Dialog, was passiert: „Safe Room: sicher, Sie werden ausgeruht.“ oder „Gang (unruhig):
   bis zu 3 Streifen, Ihre Figur wehrt sich mit Taktik ‚Unterstützen‘. Nächster Safe Room: 2 Räume.“ — Knöpfe **„Hier
   schlafen“** und **„Zurück“**. Ohne Netz zusätzlich: „Hier können Sie sterben.“

### 5.2 Safe Room: sicher und ausgeruht

- Im Safe Room greift nichts an. Pro **voller Stunde** als Schläfer (Kalender) wächst der Vorrat **Ausgeruht** um **5 % der EP
  der aktuellen Stufe** bis höchstens **150 %** (1,5 Stufen; voll nach 30 h).
- **Wirkung:** Jede Kampf-EP zählt doppelt (Bonus = min(Grund-EP, Vorrat), Vorrat sinkt um den Bonus). Abschluss-, Event- und
  Berufs-EP verdoppelt Ausgeruht nicht.
- **Anzeige:** blauer Abschnitt auf der EP-Leiste, „Zzz“ am Party-Rahmen, Zeile in der Login-Bilanz.
- **Warum so:** Ausgeruht hilft genau denen, die wenig Zeit haben — sie holen mit wenigen Kämpfen auf (WoW-Prinzip „Gasthaus“).

### 5.3 Im Gang schlafen: Streifen

| Viertel-Gefahr | Wurf | Chance je Wurf | Kämpfe je Abwesenheit |
|---|---|---|---|
| ruhig | je angefangene 4 h, der erste nach 30 min | 15 % | höchstens 3 |
| unruhig | dto. | 35 % | höchstens 3 |
| gefährlich | dto. | 60 % | höchstens 3 |

- **Gegner:** eine reguläre Gruppe aus dem Pool des Viertels auf Etagenstufe — nie Bosse, nie Elite.
- **Kampf:** `RtSim` headless (07), beide Figuren KI mit ihrer **eingestellten Taktik und ihren Schaltern**, Start-HP und -MP nach
  der Regeneration seit dem Einschlafen (07 §2.7 auf die verstrichene Zeit gerechnet — meist voll).
- **Notfall-Rückzug:** Fällt die Party unter **25 % der Summe der Max-HP**, hält der Auflöser die Sim an und würfelt die
  Flucht (Taktik „Vorsichtig“ 80 %, sonst 60 %). Gelingt sie, endet der Kampf ohne Beute; misslingt sie, läuft der Kampf zu
  Ende.
- **Sieg:** normale EP (ohne Ausgeruht) und Beute; **Niederlage:** Todesregel (Kap. 7). Es gibt keine Kämpfe in
  Bossräumen, Safe Rooms und auf der Treppenzelle.
- **Absicht:** Draußen schlafen ist meist gut ausgegangen, manchmal einträglich, selten tödlich — und Ohne Netz eine echte
  Entscheidung. Drinnen schlafen ist sicher und bringt Ausgeruht.

### 5.4 „Während Sie schliefen …“ (Login-Bilanz)

Ein Bildschirm vor dem Weiterspielen, jederzeit überspringbar, höchstens sieben Zeilen:

```text
WÄHREND SIE SCHLIEFEN …                          (3 Tage 4 Stunden, Gang „Rohrgang“, unruhig)
• 2 Streifen kamen vorbei: 2 Siege (+1 840 EP, 120 Credits, Kabelrest ×2)
• Ausgeruht: — (nur im Safe Room)
• Etage 6 ist jetzt auf Sendung · Einsturz in 1 T 20 Std. · Ihre Treppe ist offen
• Eilmeldung: Kira Katzenjammer ist auf Etage 7 — als Erste.
• Eilmeldung: 3 Kandidat:innen weniger mit weißer Weste (noch 44).
[Weiter]
```

Bei einem Einsturz während der Abwesenheit steht die Rettung bzw. der Sendeschluss **zuerst**, mit klarer Sprache („Etage 5
ist eingestürzt. Die Regie hat Sie gerettet: −30 % Credits.“).

### 5.5 Deterministisch und aufgezeichnet

- **Offline (ST1):** Beim Login entsteht genau ein aufgezeichnetes Command `{"t": "away", "sec": N}` (Abwesenheit in
  Staffel-Sekunden, aus der lokalen Uhr). Der Kern geht die Abwesenheit **Staffel-Stunde für Staffel-Stunde** durch: Besetzung,
  fällige Streifen-Würfe und -Kämpfe (`SleepResolver`, Zufall `SeedUtil.derive(seed, "sleep", n)`), fälliger Einsturz (eine
  Rettung setzt die Figur in einen Safe Room — ab da wächst Ausgeruht, und es kommen keine Streifen mehr), Regeneration und
  Ausgeruht. Replay und Verifier kommen mit demselben Command zum selben Hash.
- **Uhr:** Die Staffel-Uhr ist **monoton**: Läuft die Gerätezeit rückwärts, steht die Staffel, bis die Zeit wieder aufholt;
  ein Sprung nach vorn ist nur verstrichene Zeit (wer vorspult, verkürzt die eigene Etage). Die letzte gesehene Zeit steht im
  Spielstand.
- **Online (ST2):** Der Server führt die Uhr. Er stellt `clock`- und `away`-Commands mit Signatur aus; Streifen-Kämpfe rechnet
  er beim Einsturz, bei einem Weckruf oder beim Login (nachträglich, gleiche Regeln) und schickt das Ergebnis mit.
- **Echtzeit (ST3):** Schläfer sind Server-Entitäten; Streifen laufen wirklich vorbei, andere sehen den Kampf und können
  helfen (Kap. 6).

### 5.6 Benachrichtigungen

Einsturz-Warnungen, „neue Etage offen“ und (ab ST2) „Ihr Schläfer hat gekämpft“ nach Kap. 2.9 — Opt-in beim ersten
Ausloggen, höchstens 3 am Tag, nie in der Ruhezeit.

---

## 6. Andere Spieler:innen

### 6.1 Was geht — je Phase

| Handlung | ST1 (offline) | ST2 (asynchron) | ST3 (Echtzeit) |
|---|---|---|---|
| Andere sehen | KI im Safe Room | Liste, Rangliste, Ticker, Zuschauen (05 S2, Verzögerung) | in der Welt (geteilte Etage) |
| Schläfer sehen | — | — | ja, mit „Zzz“ |
| Schläfer **bewachen** | — | — | Wer in der Nähe steht, kämpft gegen eine kommende Streife mit; der Schläfer kämpft als KI mit |
| Schläfer **heilen** | — | — | Heilfähigkeit oder -gegenstand auf den Schläfer |
| Schläfer **wecken** | — | Freund:innen: Weckruf als Benachrichtigung (1× je Tag und Paar) | dto., plus „Kaffee hinstellen“ (+5 % Ausgeruht, 1× je Tag) |
| **Handeln** | KI-Händler:innen | Postfach mit Gegenständen und Credits (Treuhand, Kap. 9.2) | Postfach und direkter Tausch |
| Gemeinsam spielen | — | — | Koop 2–4 (07 §10.8), Bossräume je Gruppe instanziert |
| **Angreifen** | — | — | **nur in Show-Arenen, Opt-in** |

### 6.2 Kein PvP gegen Schläfer — Arenen und später „Kopfgeld“

- **Empfehlung (verbindlich bis zur Nutzerentscheidung):** Schläfer kann niemand angreifen, bestehlen oder blockieren. PvP gibt
  es nur freiwillig in **Show-Arenen** (ein Arena-Raum je Etage am ersten Safe Room, ST3): Duell 1:1 oder 2:2, ohne Verlust
  von Ausrüstung oder Stufe, mit Zuschauer:innen, Arena-Rangliste und kosmetischen Belohnungen.
- **Offen für härteres PvP:** Die Regel steckt in einem Feld der Staffelvorlage `rules.pvp` ∈ `off` | `arena` (Standard) |
  `bounty`. Ein späteres Opt-in-Regelwerk **„Kopfgeld“** (eigene Staffelvorlage, nur Menschen, die zustimmen; PvP außerhalb von
  Safe Rooms; wer angreift, bekommt ein sichtbares Kopfgeld) ist ohne Umbau möglich — **nie** gegen Schläfer, nie in
  öffentlichen „Mit Netz“-Staffeln. Entscheidung, falls gewünscht: offene Frage F-6.

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
  Etage**; dort volle Heilung (wie jeder Safe Room). Gebühr **−10 % Credits**, weiße Weste weg. Besiegte Gruppen bleiben
  besiegt; ein Boss, gegen den man verloren hat, steht wieder mit voller Kraft da (wie nach einer Flucht, 07 §2.5), und beim
  nächsten Betreten öffnet einmal das Comeback-Fenster (06 §6 Nr. 3).
- **Einsturz:** Rettung nach Kap. 2.5.
- Es gibt **kein Game Over** und kein „Letzten Spielstand laden“ mehr (GDD §14.6 gilt nur noch Ohne Netz und für Event-Läufe).

### 7.2 Ohne Netz (Hardcore, „ein Leben“)

- **Eigene Staffeln:** Alle Kandidat:innen einer Ohne-Netz-Staffel spielen Ohne Netz; Wechsel gibt es nicht. Verfügbar für
  alle, mit Bestätigung („Ein Leben. Ernsthaft?“).
- **Tod oder Einsturz = raus.** Sendeschluss-Bild mit Titel „Gefallen auf Etage N“ bzw. „Verschüttet auf Etage N“.
- **Studiogast:** Wer raus ist, schaut der Staffel bis zum Ende zu — offline (ST1) als Zeitraffer der Besetzung bis zum
  Finale, online (ST2+) als Zuschauer:in mit Senderwechsel (05 S2, Verzögerung), darf in Zuschauer-Abstimmungen mitwählen und
  im Staffel-Ticker mit **Schnellsätzen** kommentieren („Studiogast Jana: ‚Das hätte ich anders gemacht.‘“). Titel und
  Erinnerungskarte bleiben in der Ruhmeshalle. Eine neue Staffel kann man jederzeit beginnen.

### 7.3 Übersicht der Strafen

| Ereignis | Mit Netz | Ohne Netz |
|---|---|---|
| Tod | zuletzt besuchter Safe Room der Etage, −10 % Credits, Weste weg | raus (Studiogast) |
| Einsturz | Rettung auf die Etage auf Sendung, −30 % Credits, −10 % Follower, keine Etagen-Bilanz, Weste weg | raus (Studiogast) |
| Tod als Schläfer | wie Tod | raus |
| Absturz/Funkloch im Kampf | Autopilot kämpft zu Ende, Ergebnis gilt | dto. |

### 7.4 Vorabendprogramm

Die leichte Einstellung (GDD §2.9: Gegnerschaden × 0,75, EP × 1,2) gibt es nur in **privaten** Staffeln; Am Stück zusätzlich
15 statt 10 min Erkundungszeit je Staffel-Tag. Online-Staffeln teilen eine Uhr und ein Regelwerk — dort gibt es sie nicht.

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

### 8.2 Stufen

- **Höchststufe 50** (`Balance.LEVEL_CAP` 10 → 50; erreicht auf Etage 16). Etage 17 und 18 sind die **Finalwochen**: Dort
  zählen Ausrüstung, Talente, Berufe und Können.
- **EP-Tabelle** `exp_table` (Stufe 1–49) als vorberechnete Ganzzahl-Tabelle in `data/party.json` (05 §3.3 Nr. 5): Stufen 1–9
  unverändert (GDD §4.3), danach dieselbe Kurve fortgesetzt (offline erzeugt), feinjustiert durch den Staffel-Harness.
- **EP-Quellen** (Anteile einer Stufe bei Gegnern auf Bandstufe, Startwerte): reguläre Gruppe 4 %, Show-Boss 15 %, Revier-Boss
  25 %, Etagenboss 50 %, Etagen-Abschluss per Treppe 50 %, Etagen-Event 5 %, Beruf (je Steigerungspunkt) 0,2 %. Pflichtweg ≈ 1,8
  Stufen, vollständig ≈ 3 Stufen — genau ein Band.
- **Stufen-Band und Deckel:** Jede Etage hat ein Band (Tabelle Kap. 2.4). Die Stufe steigt nie über das **Bandende der Etage,
  auf der Sie stehen**. Darüber werden EP zu **„Überstunden“: 10 % der EP als Credits**.
- **Aufholjagd:** Liegt Ihre Stufe unter dem Bandanfang Ihrer Etage, zählen **alle EP doppelt**. Zusammen mit Ausgeruht
  bleibt es bei × 2 (der Ruhevorrat wird dann nicht verbraucht).
- **Gegnerfarben** (Kap. 3.4): grau 0 %, grün 50 %, gelb 100 %, orange 120 %, rot 140 % der EP.
- **Stufenaufstieg:** Werte wie GDD §4.1 (HP/MP steigen um die Differenz); Bänder ab Etage 3 heben Wachstum und Gegnerwerte
  gemeinsam (Harness).

### 8.3 Fähigkeitenbuch

- **Ein Buch je Figur** (Pausemenü „Fähigkeiten“, heute `skills_menu.gd`): je Leistenplatz (1 Haupt, 2 Schutz/Heilung,
  3 Kontrolle, 4 Fläche, SHOW) die gelernten Fähigkeiten hell, kommende gedimmt mit **„ab Stufe X“**; vor dem Recall ein Reiter
  **„Klassen-Vorschau“** mit den Fähigkeiten aller vier Klassen der Figur.
- **Die Leiste bleibt 07:** 4 Fähigkeiten + SHOW + Trank. Neue Fähigkeiten sind **Varianten** eines Platzes; die Belegung
  wählt man außerhalb des Kampfes (07 §4.1, `PartyMember.rt_loadout`). Neu Gelerntes meldet ein Banner („Neue Fähigkeit:
  Betonschuhe — im Fähigkeitenbuch auf die Leiste legen“).
- **Figurenfähigkeiten** (Stufe 1–9): die heutigen Leisten aus 07 §4.2/§4.3 unverändert.
- **Klassenfähigkeiten** (ab dem Recall): **beim Recall** die Signatur, dann auf **Stufe 12, 17, 22, 27, 32** je eine; auf
  **37, 42, 47 Rang II, III, IV** (alle Klassenfähigkeiten +10 % Kraft je Rang). Merkregel ab Stufe 12: Endet die Stufe auf
  **2 oder 7**, gibt es eine Fähigkeit (ab 37 einen Rang); endet sie auf **0 oder 5**, eine Talentreihe. Davor gelten die
  Figurenleisten (Stufe 1–9) und die Grundreihen (3/5/7/9).
- **Beispiel Abrissbirne** (`cls_kai_wrecker`; IDs der ersten zwei stehen schon in `classes.json`):

| Wann | Fähigkeit | Platz | Wirkung (Startentwurf) |
|---|---|---|---|
| Recall | Abrissbirne (`skl_kai_wrecking_ball`) | 1 V | starker Einzeltreffer, 220 physisch, Bedrohung × 3 |
| Stufe 12 | Betonschuhe (`skl_kai_concrete_boots`) | 3 V | unterbricht, `sts_slow` 6 s |
| Stufe 17 | Bauzaun | 2 V | Spott + `sts_guard` 8 s auf sich |
| Stufe 22 | Presslufthammer | 4 V | Kanal 2 s, Fläche, Schock |
| Stufe 27 | Sprengung! | SHOW V | Stunt mit Fläche, Risiko wie SHOW |
| Stufe 32 | Statik-Gutachten | 2 V | −30 % erlittener Schaden 8 s |
| Stufe 37/42/47 | Rang II/III/IV | — | Klassenfähigkeiten +10 % Kraft je Rang |

Datenform: `classes.json` → `rt.bar` (dasselbe Schema wie `party.json` → `rt.bar`, 07 §4.8) und Rang-Stufen als `skill_pm`
mit Quelle `class:<id>` (CR-32). 8 Klassen × 6 Fähigkeiten = 48 neue Fähigkeiten; ST1 darf Platzhalter (Varianten
vorhandener Fähigkeiten mit anderen Zahlen) nutzen.

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
- **Kein Zufall mehr:** Das Angebot „1 aus 2“ (06 §2.2) entfällt. Ränge (`max_rank` 2) gehen in einen Wert auf (Wischtechnik
  STR +2 statt 2 × +1); dafür erweitert der Talent-Validator die Bereiche der Arten (z. B. `stat_pct` bis 100 ‰,
  `crit_add_pm` bis 60, `post_battle_mp_pm` bis 100) und kennt die neue Art `rt_mod` (Operationen aus 07 `MOD_OPS`, CR-31/32).
- **Klassenwechsel** (06 §3.6, „Umschulung“ 1× je Etage) setzt die Klassenreihen frei; die Grund- und Figurenreihen bleiben.
- **Grundreihen** (aus den vorhandenen Talenten, Werte zusammengefasst):

| Stufe | Kai: links | Kai: Mitte | Kai: rechts | Graf: links | Graf: Mitte | Graf: rechts |
|---|---|---|---|---|---|---|
| 3 | Wischtechnik (STR +2) | Nachtschicht-Kondition (HP +10 %) | Dicke Haut (DEF +2) | Mitternachtsformel (MAG +2) | Leberwurst-Diät (HP +10 %) | Hoher Kragen (RES +2) |
| 5 | Fester Griff (Krit +6 %) | Glückspfote (LCK +1, Krit +2 %) | Hausverstand (RES +1) | Nachtaktiv (MP +10 %) | Zwinger 7 überlebt (LCK +2) | Monokel-Fokus (SPD +1) |
| 7 | Erster Eindruck (Erstschlag +15 %) | Weit ausholen (Feldschlag +25 %) | Automatenkaffee (+10 % MaxMP nach Siegen) | Taktgefühl (SHOW × 1,2) | Bellen in Stereo (+25 %) | Schwer vermittelbar (Bellen −30 % Abklingzeit) |
| 9 | Bissfest (Gift × 0,75) | Kamera 3 kennt mich (Herz) | Liga-Routine (Liga: DEF +5 %) | Doppelter Unterpelz (Eis × 0,75) | Körbchen-Nickerchen (+10 % MaxMP nach Siegen) | Liga-Gelassenheit (Liga: RES +5 %) |

- **Spezialisierungen** (zwei je Klasse, Arbeitstitel): Abrissbirne — *Bollwerk* (Tank) / *Abrissunternehmen* (Schaden);
  Gleisläufer:in — *Schnellzug* (Tempo) / *Weichensteller:in* (Kontrolle); Schrott-Tüftler:in — *Bastelbude* (Gegenstände) /
  *Kurzschluss* (Elemente); Showrunner:in — *Publikumsmagnet* (Hype) / *Stuntdouble* (Stunts); Hofmagier — *Feuerwerk* (Feuer)
  / *Gewitterzelle* (Schock); Leibarzt Seiner Hoheit — *Notaufnahme* (Einzelheilung) / *Kurkonzert* (Flächenheilung);
  Fluchgraf — *Fluchkanzlei* (Schwächen) / *Spukschloss* (Dauerschaden); Diva — *Primadonna* (Verstärkung) / *Skandal* (Show).
  Wer überwiegend links oder rechts wählt, bekommt die Spezialisierung als Plakette — es gibt **keine** Pflicht und keine
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
| **Schrottsammeln** | `job_scrap` | Sammeln | Schrotthaufen, Kabelschächte, Automatenwracks durchsuchen (2 s) | Metall, Kabel, Bauteile |
| **Pilzkunde** | `job_shrooms` | Sammeln | Pilzbeete, Moos, Kanalkresse ernten (2 s; führt der Graf, „erschnüffelt“ er sie) | Pilze, Kräuter |
| **Ausschlachten** | `job_salvage` | Sammeln | automatisch nach jedem Sieg (keine eigene Handlung) | Federn, Panzerplatten, Stoffreste, Schleim |
| **Requisite** | `job_props` | Handwerk | Waffen und Accessoires bauen und aufwerten; Gadgets (Nebelmaschine, Megafon) | aus Schrott |
| **Labor** | `job_lab` | Handwerk | Tränke, Elixiere, Sprays und Würfe (Kältespray, Grillanzünder-Cocktail) | aus Pilzen und Schleim |
| **Kostüm** | `job_costume` | Handwerk | Rüstungen (Kleidung für Kai, Pullover und Umhänge für den Grafen) | aus Stoff und Federn |
| **Kochen** | `job_cooking` | Nebenberuf | Essen: Heilung außerhalb des Kampfes + **„Satt“** (+5 % Max-HP und -MP, 30 Spielminuten) | aus Zutaten (Beute, Pilze, Automat) |
| **Erste Hilfe** | `job_first_aid` | Nebenberuf | Pflaster, Verbände, Gegengift (Trank-Platz, 07 §4.5) | aus Stoffresten |

- **Wer:** Berufe hat nur die **Kandidat:in** (Party-ID `kai`) — „Der Graf lässt arbeiten.“ Sammeln geht, egal wer führt.
- **Ab Etage 2:** Im ersten Safe Room öffnet das **Gewerke-Büro** (Safe-Room-Menü „Automat | Berufe“, Kap. 9.1). Dort lernt,
  verlernt (Wert weg) und steigert man Rang; Hergestelltes entsteht nur im Safe Room.
- **Wert 1–300**, vier **Ränge**: Praktikum bis 75 (sofort), Assistenz bis 150 (ab Stufe 13), Leitung bis 225 (ab Stufe 25),
  Legende bis 300 (ab Stufe 37); Rangaufstieg kostet Credits.
- **Material-Stufen:** M1 Etage 1–3 (Wert 1–50), M2 4–6 (51–100), M3 7–9 (101–150), M4 10–12 (151–200), M5 13–15 (201–250),
  M6 16–18 (251–300). Fundstellen und Rezepte tragen ihre Anforderung R.
- **Farben** (Rezept oder Fundstelle mit Anforderung R): **orange** R … R+24 (Steigerung sicher), **gelb** R+25 … R+49 (75 %),
  **grün** R+50 … R+74 (25 %), **grau** ab R+75 (keine). Steigerung +1, Würfe aus `SeedUtil.derive(seed, "job", n)`.
- **Rezepte:** beim Gewerke-Büro (Credits), als Beute (Bosse, Kisten) und je Vorleben die Praktikum-Rezepte gratis. Etwa 3–5
  Rezepte je Beruf und Material-Stufe, aus Vorlagen gestuft (Pflaster M1 … M6); ST1 baut M1–M3.
- **Wirtschaft:** Der Automat kauft Hergestelltes an (Credits-Quelle mit Tagesdeckel), Händler:innen der KI ebenso;
  Meisterstücke am Ende jeder Material-Stufe sind die beste Ausrüstung außerhalb von Bossbeute. Hergestelltes ist
  **staffelgebunden** und kann nicht in Echtgeld getauscht werden (Kap. 10).

### 8.6 Vorleben-Vorsprung

**Regel:** Der Beruf des Vorlebens startet mit **50**, der Beruf des Hobbys mit **25**; sind es derselbe Beruf, mit **75**. Die
**Status-Kacheln** (Schule, Ausbildung & Studium · Selbstständig · Ruhestand · Familie & Sorgearbeit · Neuorientierung) und
Allrounder:in haben keinen eigenen Beruf: Der Vorsprung kommt ganz aus dem Hobby (**75**) — so wird niemand über seinen Status
in eine Schublade gesteckt (08 H-2). Fehlt eine Zuordnung („Anderes …“ ohne Treffer), geht ihr Anteil an den anderen Beruf;
fehlen beide, gilt der Kanon (**Erste Hilfe 50, Kochen 25**). So bekommt jede:r genau **75 Punkte**. Der Vorsprung gilt, sobald
der Beruf gelernt ist (Nebenberufe ab Etage 2 automatisch); höchstens 75 = Ende des Praktikums. Das Gewerke-Büro zeigt Berufe
mit Vorsprung oben („Ihr Vorleben: Requisite 50“).

| Vorleben (`org_*`) | Beruf | Zeile (Beispiel, Humor-Leitplanken 08 §4.9) |
|---|---|---|
| Tierpflege (`org_animals`) — **Kanon** | Erste Hilfe | „Sie haben schon Pfoten verbunden. Jetzt sind es eben Ihre eigenen.“ |
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
| Status-Kacheln (`org_school`, `org_selfemployed`, `org_retired`, `org_family`, `org_reorient`) und Allrounder:in (`org_allround`) | Beruf des Hobbys, 75 | — |

| Hobby (`hob_*`) | Beruf | | Hobby | Beruf |
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

**Kanon-Kai** („Rest automatisch“): Erste Hilfe 50, Kochen 25 — passend zu Kais Fähigkeit „Erste Hilfe (Tierarzt-Edition)“.
**Fairness:** Jede:r bekommt denselben Vorsprung (75 Punkte), nur in einem anderen Beruf; Event-Läufe haben weiter keine
Persona (08 C-13).

### 8.7 Migration

| Heute | Neu | Regel |
|---|---|---|
| Talent-Show „1 aus 2“ auf ungeraden Stufen ab 3 (06 §2.2, Code 06-B) | Grundreihen auf 3/5/7/9 (je 1 aus 3) | Alte Wahlen werden zurückgesetzt, jede erreichte Reihe ist offen; M.O.D.: „Neuer Talentbaum — bitte neu wählen. Kostenlos. Diesmal.“ |
| Talent-Reset per Gegenstand (06 §3.6) | Umwählen im Safe Room, kostenlos | Gegenstand „Neuanfang-Vertrag“ entfällt |
| Starttalente `tal_org_*`, 1 aus 2, einmal tauschbar (08 §3; Kern-Pfad seit K0) | Vorleben-Vorsprung (8.6) | **CR-33** — vor 08 K1 entscheiden, sonst baut K1 Inhalte, die sofort wieder gehen; der ruhende K0-Pfad geht in ST0 |
| Command `persona` v1 (`talent`, `bias`, `swap`) | v2 `{"t": "persona", "v": 2, "jobs": {"job_first_aid": 50, "job_cooking": 25}, "bias": [...]}` | Prüfung: 1–2 Einträge, Werte ∈ {25, 50, 75}, Summe = 75, IDs aus `jobs.json`; Event-Lauf → `event_run` (wie 08) |
| `Balance.LEVEL_CAP = 10`, EP-Formel | 50, Tabelle | Spielstände unter Stufe 10 unverändert |
| Kampagnen-Spielstand (Etage, `time_left_ticks`) | private Staffel Am Stück | Staffel-Uhr = Etagenzeit + verbrauchte Zeit; Speichern im Safe Room wird zum Dauerspeicherstand |

---

## 9. Technik

### 9.1 ST1: Offline-Staffel (ohne Server)

**Neue Module** (`core/season/`, rein, `RefCounted`, ohne Szenen und Autoloads, Ganzzahlen, Zufall nur `SeedUtil`):

| Datei | Klasse | Aufgabe |
|---|---|---|
| `season_def.gd` | `SeasonDef` | Staffelvorlage aus `data/seasons.json` (`ssn_`: Etagenzahl, Dauern, Besetzung, Mindestzahlen, `mode`, `rules.pvp`, Sendezeit) |
| `season_state.gd` | `SeasonState` | im `GameState`: Vorlage, Nummer, Tempo, Modus, `sec` (Staffel-Sekunden), letzte gesehene Uhrzeit (nur offline, nicht gehasht), erledigte Einstürze, Rettungen, Tode, Weste, raus, Erstbesteigungen |
| `season_clock.gd` | `SeasonClock` | rein: Einsturztermine, Etage auf Sendung, Vorlauf-Grenze, Restzeit, Am-Stück-Umrechnung (10 min = 1 Tag) |
| `season_rules.gd` | `SeasonRules` | Treppenregel, Einsturz, Rettung, Tod, Staffel-Quote, Titel |
| `level_band.gd` | `LevelBand` | Band, Deckel, Aufholjagd, Ausgeruht, Gegnerfarben, EP-Faktoren |
| `cast_sim.gd`, `cast_member.gd`, `cast_event.gd` | `CastSim`, … | Populationsmodell, Ereignisse, Rangliste |
| `sleep_resolver.gd` | `SleepResolver` | `away`: Reihenfolge Kap. 5.5, Streifen über `RtSim` headless (Autopilot) |

Dazu `core/progression/jobs.gd` (`Jobs`), `talent_tree.gd` (`TalentTree`, ersetzt die Angebotslogik in `talents.gd`),
`ability_book.gd` (`AbilityBook`, Leisten aus `party.json` + `classes.json`), `core/dungeon/zone_generator.gd` (Kap. 3.6),
Defs in `core/data/defs/` (`season_def`, `job_def`, `recipe_def`, `theme_def`) und Validatoren in
`core/data/validators/{seasons,jobs,cast,themes}.gd`.

**Daten:** `seasons.json` (`ssn_standard`, `ssn_ohne_netz`, `ssn_kurz6` für Tests und frühe Formate, `ssn_dev`), `jobs.json`
(`job_`, `rcp_` Rezepte, `mat_` Material, `nod_` Fundstellen), `cast.json` (Namen, Profile, Zeilen-Tags), `themes.json`
(`thm_`), `floors.json` Etagen 3–18, `talents.json` (Felder `row`, `col`, `tree`, `spec`), `classes.json` (`rt.bar`,
Rang-Stufen), `party.json` (`exp_table`), `rt_balance.json` (`enemy_level_pm`). Präfixe `ssn_` und `job_` sind seit 06 §7
reserviert.

**Staffel-Uhr im Kern:**

- **Am Stück:** `RunSim` zählt wie heute Erkundungs-Ticks; die Staffel-Uhr ist daraus abgeleitet (18 000 Ticks = 1 Staffel-Tag);
  `FloorRun.time_left_ticks` wird zur Restzeit bis zum Einsturz der Etage. Keine neuen Commands.
- **Kalender:** Die Uhr wird **von außen gestellt** — der Client zeichnet je **60 s** Wanduhrzeit `{"t": "clock", "sec": 60}`
  auf (Zeitraffer: Vielfaches), nach Abwesenheit `{"t": "away", "sec": N}`. Der Kern wendet beide nur außerhalb des Kampfes
  an einer Tick-Grenze an; Kampfzeit reicht der Client nach `end_combat` gesammelt nach — die Uhr läuft also weiter, und ein
  fälliger Einsturz wartet von selbst bis zum Kampfende. RunSim-Ticks stellen die Kalender-Uhr nicht.
- **Neue Commands** (alle über aufzeichnende `Game`-Methoden, Prüfung in `RunRules`, 02_TECH §3.4):

| `t` | Form | Bemerkung |
|---|---|---|
| `season` | `{"t": "season", "v": 1, "def", "tempo", "mode", "cast", "number"}` | einmal vor `floor`/`hero`/`persona` |
| `clock` | `{"t": "clock", "sec"}` | Kalender; ab ST2 mit Server-Signatur `sig` |
| `away` | `{"t": "away", "sec"}` | Kalender; Login nach Abwesenheit |
| `talent` v2 | `{"t": "talent", "v": 2, "member", "row", "id"}` | ersetzt die 06-B-Form; nur im Safe Room |
| `job` | `{"t": "job", "op": "learn" \| "unlearn" \| "rank", "id"}` | Gewerke-Büro |
| `gather` | `{"t": "gather", "node"}` | Fundstelle (Szenenlogik Grad A wie `secret`, 06 §2.7) |
| `craft` | `{"t": "craft", "recipe", "n"}` | nur im Safe Room |
| `cast` | `{"t": "cast", "op": "hire" \| "trade" \| "help", "who", "item"?}` | KI-Kandidat:innen |
| `persona` v2 | Kap. 8.7 | CR-33 |

- **Zustand und Hash:** `GameState.season` (alles außer der lokalen Uhrzeit), `PartyMember.rested`, `jobs`, `job_head`,
  Talentreihen, Besetzung (`CastSim`-Zustand) gehen in `StateHash.of` — additiv, nur wenn vom Standard abweichend (wie 07 §10.4),
  damit alte Golden-Hashes gelten.
- **Speichern:** Dauerspeicherstand nach jedem Kampf, bei jedem Safe-Room-Besuch, beim Etagenwechsel, beim Ausloggen und
  spätestens alle 60 s (atomar wie heute); dazwischen hält das Run-Log den Rest (Absturz → Spielstand + Log). Die drei Plätze
  sind drei private Staffeln. Kein „Speichern“-Knopf mehr; das Safe-Room-Menü wird zu „Lootboxen · Automat | Berufe · Figur
  wechseln | Ausrüstung · Mopsula · Ausloggen | Weiter“ (fünf Zeilen, GDD §14.7; „Berufe“ ab Etage 2). Am Stück behält die
  Gnadenfrist beim Laden (3:00, GDD §2.9); im Kalender-Tempo gibt es keine.
- **Replay:** Run-Log je Sitzung, verankert am Spielstand (`start_state`/`start_hash`, 05/08 wie heute); `clock` und `away` sind
  Einträge des Logs. Ein ganzer Staffel-Replay ist die Kette der Sitzungs-Logs.
- **Version (S-23):** Der `season`-Eintrag trägt `sim_version` und `data_hash`. Ein App-Update übernimmt eine laufende private
  Staffel beim nächsten Etagenwechsel (neuer Anker); Online-Staffeln laufen auf ihrer Version zu Ende. Sitzungs-Logs einer
  anderen Version spielt der Kern wie seit K0 nicht ab, sondern zeigt sie als „ältere Version“ (`RunSim.version_status`).
- **Ausloggen-Ablauf:** Pausemenü „Ausloggen“ → Dialog (Kap. 5.1) → Speichern → Titel. Login: `away` → Login-Bilanz → Welt.

### 9.2 ST2: Staffel-Server (asynchron)

```text
 Client (Godot)  ──HTTPS/WSS──►  Staffel-Dienst  ──► Postgres (Konten-Pseudonyme, Staffeln, Besetzung, Postfach, Ranglisten)
   spielt seine Etage lokal        │  Uhr, Lobby, Start, signierte clock/away-Tickets
   (Grad A), lädt Sitzungs-Logs    ├─► Godot headless `--role=season`: CastSim je Staffel (stündlich), Schläfer-Streifen
   hoch                            ├─► Verifier-Pool (05 S1): rechnet jedes Sitzungs-Log nach, schreibt Ranglisten
                                   ├─► Nakama (05 §3.8): Plattform-Login, Freunde, Bestenlisten
                                   └─► Zuschauer-Pipeline (05 §5, S2): Senderwechsel je Staffel, 30 s Verzögerung, Fog-of-War
```

- **Autoritative Uhr:** Der Server stellt `clock`/`away`-Tickets aus (`{sec, season, seq, sig}`); der Verifier lehnt Logs mit
  fremden oder fehlenden Tickets ab. Online-Staffeln brauchen eine Verbindung.
- **Gemeinsame Besetzung:** Menschen und KI stehen in einer Liste; die KI rechnet nur der Server; Eilmeldungen kommen als
  Ereignisse an den Client.
- **Postfach/Tausch als Treuhand:** Wer etwas verschickt, gibt es mit einem aufgezeichneten Command ab; der Server bucht es in
  eine Treuhand und liefert es als externen Eingang (wie ein Geschenk, 05 §6.5) — kein Duplizieren, nachrechenbar.
- **Ranglisten:** pro Staffel und je Staffelart, „plausibilitätsgeprüft“, bis Grad B kommt (05 §3.3).
- **Sponsor-Fenster und Live-Modus:** Kap. 10.

### 9.3 ST3: Echtzeit-Präsenz

- **Etagen-Instanzen („Schauplätze“):** Je Staffel und Etage Shards mit bis zu **24 Menschen** plus KI und Schläfern;
  Freund:innen und Gruppen landen im selben Shard. Weil die Besetzung immer auf zwei benachbarten Etagen steht (Kap. 2.6),
  sind die Shards voll.
- **Server-Sim:** Godot headless `--role=shard` mit `RunSim` + Erkundung **Grad B** (`core/dungeon/explore_sim.gd`, 05 §3.3) +
  `RtSim` mit `move_input` (07 §10.8). Interessenradius 40 m, 15-Hz-Schnappschüsse (05 §3.5).
- **Koop 2–4** nach 07 §10.8; Bossräume und Arenen je Gruppe instanziert; Schläfer und Streifen sind Server-Entitäten.
- **Arenen:** Party gegen Party in `RtSim` (Änderungsantrag an 07 zur gegebenen Zeit: zweite Spieler-Seite).
- **Transport** wie 05 §4.1: zuverlässig über WebSocket/TLS (Befehle, Ereignisse, Postfach), unzuverlässig über ENet bzw.
  WebRTC (Eingaben, Schnappschüsse); Wiederverbinden nach 05 §3.6 — während der Gnadenfrist kämpft die Figur als KI weiter
  („Wer geht, wird zur KI“).
- **Persistenz:** Shards halten nur Laufzeit; Spielstände, Schläfer-Positionen und Postfach liegen im Staffel-Dienst
  (Postgres), Run-Logs im Objektspeicher (05 §5.5).

### 9.4 Anti-Cheat

| Phase | Risiko | Maßnahme |
|---|---|---|
| ST1 | Gerätezeit verstellen | monotone Uhr; Vorspulen verkürzt nur die eigene Etage; Rückspulen friert ein |
| ST1 | Absturz erzwingen, um einen Kampf zu wiederholen | „Wer geht, wird zur KI“: der Kampf wird beim nächsten Start zu Ende gerechnet |
| ST2 | manipulierte Sitzungs-Logs | Verifier (05 S1), signierte Uhr-Tickets, Ranglisten nur nach Prüfung |
| ST2 | Duplizieren über das Postfach | Treuhand, Abgabe als Command, Zustellung als externer Eingang |
| ST2/ST3 | Bots, Echtgeldhandel | Tageslimits, Wartezeit für neue Konten, Melden; kein Auszahlungsweg (05 L11) |
| ST3 | Bewegung, Treffer | Server-Autorität Grad B, Plausibilität, Lag-Ausgleich (07 §10.8) |

### 9.5 Datenschutz (DSGVO)

- **Persona bleibt lokal** (08 P-1, D-2): Server sehen nur Katalog-IDs, die im Spiel wirken (Berufs-Vorsprung, `bias`), nie Name,
  Vorleben-Text oder Hobby. Andere sehen **nie** Ihre Berufswerte — nur, was Sie herstellen oder anbieten.
- **Konto:** Plattform-Login, pseudonyme Konto-ID, moderierter Anzeigename; Staffel-Daten unter dem Pseudonym; Löschung des
  Kontos entfernt laufende Figuren und anonymisiert die Ruhmeshalle („ehemalige:r Kandidat:in“) **[zu prüfen]**.
- **Benachrichtigungen** nur mit Einwilligung (Kap. 2.9), Push-Token getrennt vom Spielzustand.
- **Chat und Meldungen:** Speicherfrist, Zweck, Rechtsgrundlage in der Datenschutzerklärung **[zu prüfen]**; Minderjährige nur
  mit Schnellsätzen (Kap. 6.4).
- Verarbeitungsverzeichnis, Löschkonzept und Datenschutz-Folgenabschätzung vor dem ST2-Außentest **[zu prüfen]**.

### 9.6 Kosten **[Schätzung, Preise zu prüfen]**

| Posten | Annahme | Größenordnung |
|---|---|---|
| ST1 | offline | 0 € Betrieb |
| ST2 Staffel-Dienst + Postgres + Nakama | 1 000–5 000 täglich Spielende | 100–300 €/Monat (05 §3.9: S1-Backend 50–200 €) |
| ST2 Verifier | 1 Sitzung/Tag à ≈ 20 s CPU → 5 000 Sitzungen ≈ 28 CPU-h/Tag | ≈ 2–4 vCPU Dauerlast, im Posten oben enthalten bis ≈ 5 000 |
| ST2 Besetzungs-Sim | 99 KI × 24 Schritte/Tag je Staffel | vernachlässigbar |
| ST3 Shards | 1 000 gleichzeitige Menschen ≈ 40–60 Shards; 2–5 ms je Tick und Shard **[zu messen]** | ≈ 10–20 vCPU ≈ 150–400 €/Monat (Budget-Hoster), plus Verkehr |
| Moderation | ab ST2 Freitext | Personal oder Dienstleister — der größere Posten **[zu prüfen]** |

---

## 10. Live-Modus, Show und Monetarisierung im Staffel-Kontext

1. **Die Regeln aus 05/06 gelten unverändert:** Echtgeld von Zuschauer:innen nur an den Betreiber (L11), Hilfe nur in
   Sponsor-Fenstern (L16, 05 §6.13), Caps und Pity (L2/L4), Altersgrenze (L6), Geo-Positivliste (L7), Pur-Liga ohne Geschenke
   (L5), keine Echtgeld-Zufallsinhalte für Spieler:innen (Brief Kap. 5).
2. **Staffeln sind standardmäßig Pur:** öffentliche Ranglisten-Staffeln und alle „Ohne Netz“-Staffeln nehmen keine
   Zuschauer-Geschenke an. **Show-Staffeln** (Opt-in bei der Anlage, frühestens mit 05 S3 und nach Rechtsprüfung) nehmen sie in
   Sponsor-Fenstern an; Figuren mit bezahlten Geschenken tragen „gesponsert“ und erhalten nur die Teilnahme-Plakette (05 §1.6).
3. **Lauf-Bindung (L3) in der Staffel = Etagen-Bindung:** Geschenk-Inhalte wirken sofort oder verfallen mit dem Einsturz bzw.
   Abstieg der Etage; sie lassen sich weder verschicken, herstellen noch verkaufen.
4. **Fenster nur, wenn jemand spielt:** Schläfer bekommen keine Fenster und keine Geschenke; im Kampf öffnet keines (07 §2.10).
5. **Zuschauen:** Senderwechsel zwischen Kandidat:innen einer Staffel (05 S2), 30 s Verzögerung, Fog-of-War; Studiogäste
   (Kap. 7.2) sind privilegierte Zuschauer:innen mit Schnellsätzen.
6. **M.O.D. live** (06 §5) bleibt optional; Eilmeldungen sind geschriebene Zeilen, die KI liefert höchstens Varianten.
7. **Nichts an einer Staffel ist käuflich** (S-24): keine Rettung, kein Leben, keine EP, kein Ausgeruht, kein
   Berufs-Vorsprung, kein früherer Abstieg, kein Platz in einer Staffel. Geschäftsmodell wie 04 §6: Premium + Kosmetik; ob
   Online-Staffeln einen eigenen Kostenbeitrag brauchen, entscheidet das ST2-Gate (offene Frage F-9). Der Kalender ist **keine
   Wartezeit-Mechanik** im Sinne von 04 §6.2 Nr. 3: Nichts lässt sich kaufen, es gibt immer etwas zu spielen, und offline gibt es
   „Am Stück“.

---

## 11. Umsetzung

### 11.1 Reihenfolge

```text
07 R1a + 08 K0 (gelandet, b9d278a) → R1b-I1 → R2, R3 → R1b-I2/I3 → R4, R5a → R5b      08 K1 erst nach CR-33
                                                         │
                     nach R3:  ST0 (Vertrag) → ST1-A, ST1-B (Kern), ST1-D, ST1-E, ST1-F, ST1-H (eigene Dateien)
                     nach R4:  ST1-C (Etagen, Daten)
                     nach R5b: ST1-B (Einbau in RunSim/Game/Save), ST1-G, ST1-I → ST1-Gate
                                                         │
                     ST2 (mit 05 S1-Infrastruktur: Konten, Verifier) → ST2-Gate → ST3 (mit 05 S4: Dedicated Server)
```

Der Echtzeitkampf ist das Fundament (Klassenfähigkeiten, Gastauftritte, Schläfer-Kämpfe laufen alle in `RtSim`); deshalb kein
ST1-Paket vor 07 R3, keine Etagen-Daten vor R4 (dessen `rt`-Blöcke und Validator) und kein Einbau in Spielstand, RunSim oder
Full-Run vor R5b (Save v2, CTB-Entfernung). Was vorher entsteht, ist reiner Kern mit eigenen Tests.

### 11.2 ST0 — Vertrags-Commit (Integrator, nach 07 R3)

Wie 06 Schritt 0 und 07 R1a: **eine** Person legt alle Änderungen an geteilten Dateien als Felder, Stubs und Hook-Zeilen an;
danach schreibt jedes ST1-Paket nur eigene Dateien. Neue Stub-Dateien beginnen mit
`# STUB(ST0) — owned by 09-ST1-<X>. Replace completely, keep the public API.`

1. `core/live/command.gd`: `TYPES` += `season`, `clock`, `away`, `job`, `gather`, `craft`, `cast`; `talent` v2 und `persona` v2
   (mit 08 abgestimmt, CR-33).
2. `core/progression/game_state.gd` (`season`), `party_member.gd` (`rested`, `jobs`, `job_head`, Talentreihen), `floor_run.gd`
   (Fundstellen, Nachschub-Uhren) — additiv mit Standardwerten. Der ruhende Starttalent-Pfad aus K0 geht in einem Zug (CR-33):
   `origin_talent` und seine Leser in `talents.gd`, `hero_rules.gd`, `persona_rules.gd`, `save_codec.gd`, `command.gd`,
   `game_data.gd`, `validators/origins.gd` und `data_validator.gd`; Fixtures ohne `tal_org_`-Einträge; `test_08_k0_contract`
   wird angepasst.
3. `core/data/game_data.gd`, `autoload/db.gd`: Tabellen `seasons`, `jobs`, `cast`, `themes`, Getter.
4. `core/data/data_validator.gd` (eingefroren): **dritter Vertrags-Durchgang** — Tabellen, Präfixe `ssn_`/`job_`/`rcp_`/`mat_`/
   `nod_`/`thm_`, Hook-Zeilen für die vier neuen Validatoren, Tag-Präfixe `cast_`, `season_`, `job_`, `sleep_`.
5. `core/live/state_hash.gd`: neue Felder (additiv); `core/live/run_sim.gd`: `SIM_VERSION` + 1 (**genau einmal**; R1a + K0
   haben 1 → 2 gesetzt), vorher und nachher die Plattform-Matrix (`tools/platform_matrix.sh`, 05 Kap. 2); Zweige für die
   neuen Commands als Stubs.
6. `autoload/game.gd`: Fassaden `start_season`, `season_clock`, `season_away`, `pick_talent_row`, `job_learn`, `gather`, `craft`,
   `cast_action`, `logout` (Stubs).
7. Stubs aller `core/season/*`-Klassen, `jobs.gd`, `talent_tree.gd`, `ability_book.gd`, `zone_generator.gd`, Validatoren.
8. Daten minimal (je ein Eintrag), Fixtures `tests/fixtures/season_min/`; `mod_lines.json` Anker `mod_ssn_anchor_01` am
   Dateiende hinter dem K-Block.
9. Gate: `check.sh` und `fullrun.sh --strategy=all` grün, Verhalten unverändert; `test_09_st0_contract` prüft die Signaturen.

### 11.3 ST1-Pakete

| Paket | Inhalt | Startet | Aufwand **[Schätzung, Personentage mit KI]** |
|---|---|---|---|
| **ST0** Vertrag | Kap. 11.2 (Integrator) | nach R3 | 2–3 |
| **ST1-A** Begriffe | Text-Prüfung Kap. 1.2, Lint `test_09_terms`, Party-Menü-Zeilen, Liga-Texte | nach ST0 | 1–2 |
| **ST1-B** Staffel-Kern | `SeasonDef/State/Clock/Rules`, Tempo, Sendeplan, Treppenregel, Einsturz, Rettung, Tod, Ohne Netz, Staffel-Quote, Titel, `clock`, Hash; Einbau in `RunSim`/`Game`/`Save` (Dauerspeicherstand, Migration der Kampagne) | Kern nach ST0, Einbau nach R5b | 8–10 |
| **ST1-C** Etagen | Generator v2, `themes.json`, Etagen 2–18 (Platzhalter), Stufen-Tabelle der Gegner, Beute-Stufen, Boss-Baukasten, Nachschub, Viertel-Streaming | nach R4 | 12–16 |
| **ST1-D** Stufen, Fähigkeiten, Talente | EP-Tabelle 1–50, Band/Deckel/Aufholjagd/Farben, Fähigkeitenbuch, Klassenleisten (Platzhalter), Talentbaum + Migration + Talent-Show als Reihen-Präsentation | nach ST0 (Leisten nach R3) | 10–12 |
| **ST1-E** Berufe | `jobs.json` (M1–M3), Gewerke-Büro, Sammeln, Ausschlachten, Herstellen, Farben, Ränge, Vorsprung (Spalte `job` aus 08 K1, CR-33) | nach ST0 | 8–10 |
| **ST1-F** KI-Besetzung | `CastSim`, Ereignisse, Eilmeldungen, Zähler, Rangliste, Safe-Room-NPCs, Gastauftritt, Pechvogel-Event, Namenskatalog | nach ST0 | 7–9 |
| **ST1-G** Schläfer | Ausloggen-Dialog, `away`, `SleepResolver`, Ausgeruht, Login-Bilanz, Autopilot nach Absturz, lokale Benachrichtigungen | nach R5b | 5–7 |
| **ST1-H** Staffel-UI | „Neue Staffel“, Pausemenü-Reiter „Staffel“ (Sendeplan, Rangliste, Ticker), Einsturz-Anzeige, Staffel-Bilanz und Finale, Ruhmeshalle | nach ST0 | 6–8 |
| **ST1-I** Harness | Staffel-Harness (84 Tage Zeitraffer headless, Bot + Besetzung), Bänder, Pensum, Kalibrierung der KI | nach R5b | 5–7 |
| **Summe** | | | **≈ 64–84 PT ≈ 3–4 Monate** für eine Person mit KI |

Nicht enthalten: echte Inhalte der Kulissen (Gegner, Bosse, Musik, Raumteile, Talent- und Rezepttexte) — Produktion nach 04
Phase 4/5, Richtwert eine Kulisse je 8–10 Wochen Team (04 KPI Phase 3) **[Schätzung]**.

### 11.4 Dateieigentum gegenüber 07 und 08

| Datei / Bereich | Eigentum heute (06/07/08) | 09 | Regel |
|---|---|---|---|
| `core/season/**`, `core/progression/{jobs,talent_tree,ability_book}.gd`, `core/dungeon/zone_generator.gd`, Validatoren `seasons/jobs/cast/themes`, `data/{seasons,jobs,cast,themes}.json`, `scenes/ui/season_*`, `wake_summary.*`, `logout_dialog.*`, `jobs_menu.*`, `talent_tree.*`, `hall_of_fame.*`, `scenes/title/season_setup.*`, `tests/test_09_*` | neu | ST0 Stubs → ST1-Pakete | neu |
| `command.gd`, `game_state.gd`, `party_member.gd`, `floor_run.gd`, `state_hash.gd`, `game_data.gd`, `db.gd`, `data_validator.gd` | Schritt 0, R1a, K0 | **nur ST0** | additiv, Abschnitt `# --- Staffeln (09, ST0) ---` |
| `run_sim.gd`, `game.gd`, `save.gd`, `game_replay.gd`, `save_codec.gd` | D, R1b, R5a, R5b, K0/K1 | ST0 Stubs → ST1-B (Uhr), ST1-G (Schlaf) **nach R5b** | eigene Abschnitte |
| `talents.gd`, `talent_show.gd`, `party_menu.gd` | 06 B, K0/K1 (Tausch-UI entfällt mit CR-33) | ST1-D | Abschnitt; Angebotslogik wird ersetzt |
| Starttalent-Pfad aus K0 (`origin_talent` und Leser, Kap. 11.2 Nr. 2) | K0, K1 (`persona_rules.gd`) | **nur ST0**: entfernt in einem Zug (CR-33) | ein Commit, Verhalten unverändert |
| `skills_menu.gd` (Fähigkeiten-Menü) | R3 | ST1-D nach R3 | Abschnitt „Buch und Vorschau“ |
| `dungeon_generator.gd` | Bestand (M3) | ST1-C: eine Weiche auf `zone_generator.gd` | eine Zeile |
| `floors.json` | A, C, R4 (`encounters[].rt`) | ST1-C: neue Einträge `floor_3` … `floor_18`, `floor_2` vervollständigt | eigene Einträge, R4 schreibt nur `rt` |
| `skills.json`, `items.json`, `enemies.json`, `party.json`, `rt_balance.json` | R4 (`rt`-Blöcke, Werte) | ST1-C/D: neue Einträge, `exp_table`, `enemy_level_pm` | additiv nach R4; Werte-Eigentum bleibt R4 für Etage 1 |
| `classes.json`, `species.json` | 06 B (Daten), Validator-Regeln für `rt` R4 (CR-32 a) | ST1-D: `rt.bar`, Rang-Stufen, Klassenleisten | additiv |
| `talents.json` | 06 B, K1 (Text) | ST1-D: `row`/`col`/`tree`/`spec`, neue Einträge | additiv |
| `origins.json` | K0 (minimal), K1 | Spalte `job` in K1 als reine Daten, Referenzprüfung ab ST0 (CR-33) | K1 schreibt, ST0 prüft |
| `mod_lines.json` | Anker A–D, R1a/R4, K | Block hinter `mod_ssn_anchor_01` | Blöcke |
| `exploration.gd`, `exploration_hud.gd`, `show_overlay.gd`, `safe_room*.gd`, `settings_menu.gd`, `title_screen.gd` | A, C, R2, R3, K | ST1-G/H je ein Abschnitt | Abschnitte |
| `scenes/boot/fullrun.gd`, `tools/fullrun.sh` | Schritt 0, R5b, K0 | ST1-I: `--season=ssn_kurz6 --tempo=binge` | Abschnitt nach R5b |
| `core/rt/**`, `scenes/combat/**` | R-Phasen | **nie**; Gast-Einheit, Klassenleisten und `talent:`-Quelle als CR-32 an R1b/R4 | Änderungsantrag |

### 11.5 ST2 und ST3

| Phase | Pakete | Gate (weiter, wenn …) | Aufwand **[Schätzung]** |
|---|---|---|---|
| **ST2** | Staffel-Dienst (Lobby, Start, Uhr-Tickets), Besetzung auf dem Server, Upload und Prüfung der Sitzungs-Logs (05 S1-Verifier), Postfach/Treuhand, Ranglisten, Freunde-Staffeln, Benachrichtigungen (Push), Zuschauen (05 S2), Moderation (Schnellsätze, Melden), Datenschutz-Paket, Betrieb | 0 Abweichungen zwischen Client und Verifier in 1 000 Sitzungen über die Plattform-Matrix (05 Kap. 2); Postfach-Dupe-Tests; 4-Wochen-Beta-Staffel (Kurzformat) mit ≥ 60 % der Menschen bis Etage 6; Datenschutzprüfung; Kosten je Spielenden gemessen | 4–6 Monate, 2–3 Personen |
| **ST3** | Shard-Server (Grad B Erkundung + Kampf), Präsenz und Interessenradius, Koop 2–4, sichtbare Schläfer (bewachen, heilen, wecken, Kaffee), Arenen (PvP opt-in), Freitext-Chat ab 16, Skalierung | 05 S4-Kriterien; 24 Menschen je Shard mit p99-Tick < 5 ms **[zu messen]**; Koop-Playtest ≥ 4/5; Meldungen je 1 000 Spielstunden unter Schwelle **[festzulegen]** | 8–12 Monate, 3–5 Personen |

### 11.6 Tests und Gates (ST1)

| Test | Prüft |
|---|---|
| `test_09_season_clock` | Sendeplan (2/3/4/5…, 84), Etage auf Sendung, Vorlauf-Grenze, Am-Stück-Umrechnung (Etage 1 = 20:00), kürzere Formate, monotone Uhr |
| `test_09_stairs_collapse` | Treppenregel an jeder Grenze; Einsturz eingeloggt, als Schläfer, im Kampf (wartet); Rettung mit Gebühr; Ohne Netz raus; Etagen-Bilanz nur per Treppe |
| `test_09_death_modes` | Tod Mit Netz (Safe Room, −10 %, Weste), Ohne Netz (Studiogast), Tod als Schläfer |
| `test_09_level_band` | EP-Tabelle, Deckel, Überstunden, Aufholjagd, Ausgeruht (Aufbau, Deckel 150 %, Verbrauch, × 2 gesamt), Farben |
| `test_09_sleep` | `away` deterministisch (gleicher Zustand + Dauer → gleicher Hash), Streifen-Würfe, Notfall-Rückzug, keine Kämpfe im Safe Room/Bossraum, Am Stück ohne Streifen |
| `test_09_cast_sim` | Determinismus je Seed, Kalibrierungs-Bänder (Kap. 4.2) über 200 Seeds, Ereignisse, Zähler, Kennzeichnung, Gastauftritt nie im Bosskampf |
| `test_09_jobs` | Lernen (≤ 2 Hauptberufe), Ränge, Farben und Chancen, Sammeln, Ausschlachten, Herstellen nur im Safe Room, Vorsprung aus `persona` v2 |
| `test_09_talent_tree` | Reihen, Umwählen nur im Safe Room, Migration 06-B, Deckel bei Stufe 10 (06) und 50 (Kap. 8.4), Klassenwechsel |
| `test_09_ability_book` | Freischaltung auf festen Stufen, Vorschau, Klassenleisten über `rt.bar`, Rang II–IV |
| `test_09_replay` | Sitzung mit `season`/`clock`/`away`/`job`/`craft`/`talent` v2 → `RunSim.replay` und `Game.replay_log` hash-gleich; manipulierte Uhr-Commands → Fehler |
| `test_09_terms` | Sprachregel (Kap. 1.2) |
| `test_09_zone_generator` | 200 Seeds je Etage 3–18 erfüllen die Prüfregeln (Kap. 3.6), deterministisch |

**ST1-Gate:** alle Tests grün; Staffel-Harness (`tools/season_harness.sh --format=18 --tempo=calendar --speed=dev`) — Bot
`typical` erreicht Etage 18 Mit Netz in ≥ 80 % der Seeds, Median-Stufe beim Abstieg im Band ± 1, Pensum je Etage in den
Bändern Kap. 3.3; Am-Stück-Etage-1 hält alle GDD-§13-Bänder (Slice unverändert); Playtest n ≥ 5 (Dev-Build mit Zeitraffer):
≥ 4 von 5 erklären Einsturz, Vorlauf und Schläfer in einem Satz richtig, niemand fühlt sich „zum Warten gezwungen“.

### 11.7 Änderungsanträge

| CR | Betrifft | Änderung | Wann |
|---|---|---|---|
| **CR-25** | `00_BRIEF` | Entscheidungsblock „Staffeln“ mit dem Wortlaut der Nutzeridee 2026-10-11 und den Entscheidungen S-1 … S-12 in Kurzform; Vorrang `09` nach `07`; Kap. 1 „Etagen („Level“)“ → „Etagen“, Einsturz Mit Netz/Ohne Netz statt „Game Over“, „die System-KI“ → „die Show-KI“, „Crawler“ → „Kandidat:innen“ (wörtliche Zitate bleiben); Kap. 2 Säule 3 („Eine Sitzung 15–60 min; eine Etage über Tage — oder am Stück“); Kap. 3 Schleife mit Ausloggen; Kap. 4 Zeilen Etagen-Timer (Sendeplan), Speichern (Dauerspeicherstand, Ausloggen überall), Progression (Stufe 50, Fähigkeitenbuch, Talentbaum, Berufe), Casting (Vorleben), Game Over; Kap. 6b Nr. 4: Uhr-Commands als externer Eingang | vor ST0 |
| **CR-26** | `01_GDD` | Sprachregel „Stufe/Etage“ im ganzen Dokument; §2.8/2.9 Treppe und Timer → Sendeplan (Am Stück = heutige Zahlen, Etage 2 30:00); §4.1 Höchststufe 50, §4.3 Tabelle; §4.7 Talent-Show → Grundreihen; §12 Klassenleisten, Talentbäume; §13 Bänder je Etage; §14.2 „Neue Staffel“; §14.4 Pausemenü „Staffel“, „Ausloggen“; §14.6 Game Over nur Ohne Netz/Event; §14.7 Safe-Room-Menü; §15 Etage 2 | mit ST1 |
| **CR-27** | `02_TECH` | Modul `core/season`, Dateibaum und Eigentum; neue Tabellen und Präfixe; Commands Kap. 9.1; Felder in `GameState`/`PartyMember`/`FloorRun`; Spielstand (Dauerspeicherstand, Staffel-Block, Migration Kampagne → private Staffel); `StateHash`-Abdeckung; Versions-Bindung je Staffel; `FloorDef` mit `theme`/`variant`/`level_band`/`zones`; `exp_table` | ST0 |
| **CR-28** | `03_ART` | Paletten der Kulissen 3–8; Requisiten für Fundstellen und Gewerke-Büro; Schläfer-Optik („Zzz“, Schlafsack); KI-Kandidat:innen aus dem Persona-Kit (08 K2) statt eigener Rigs; Stufen-Plakette; Raumteile je Kulisse (Produktion) | ST1-C/H |
| **CR-29** | `04_STRATEGIE_ROADMAP` | **Namenskonflikt:** Inhaltspakete heißen „Akt 1–3“ (Akt 1 = Etagen 1–6, Akt 2 = 7–12, Akt 3 = 13–18) statt „Staffel 1/2“; Staffel-Format wächst mit: EA Kurzstaffel 6 Etagen (24 Tage), 1.0 12 Etagen (54 Tage), Akt 3 volle Staffel (84 Tage); Kap. 1.2/1.4/1.5 „20-Minuten-Etagen“ → „Folgen à 20–60 min, als Staffel über Wochen oder am Stück“; Kap. 2.3 neue Zeile (unten); Kap. 3 Phasen ST1–ST3 in der Roadmap; Kap. 6.2 Nr. 3 Klarstellung (Kalender ist keine Wartezeit-Mechanik, Kap. 10 Nr. 7); Kap. 9 Risiken R13–R20 (Kap. 11.8); Kap. 11 E5 ersetzt | vor ST0 |
| **CR-30** | `05_LIVE_MODUS` | SHOWRUN bleibt eigener Modus; Staffeln nutzen dessen Bausteine: Konten und Verifier (S1), Zuschauen (S2), Sponsor-Fenster (S3); Lauf-Bindung L3 in Staffeln = Etagen-Bindung; Staffeln standardmäßig Pur; Ranglisten je Staffel; Uhr-Tickets in Kap. 4; Hinweis: Staffel-Phasen heißen ST1–ST3 | mit ST2 |
| **CR-31** | `06` | §0.1 Nr. 3, §0.5, §2.2: Talentbaum statt „1 aus 2“, der Absatz „Starttalent der Kandidat:in“ (CR-21) entfällt mit CR-33; §0.6: Etage 2 bekommt Berufe statt Fanclubs (Fanclubs ab Etage 4 oder als spätere Spielergilden); §2.3 Höchststufe 50 und Bänder (schließt O-2); §3: „Spezialisierung“ heißt „Klasse“, Spezialisierungen = Äste des Talentbaums; §3.6 Talent-Reset kostenlos im Safe Room; §4: Vorlieben im Kalender je Staffel-Tag, Liga-Texte „Liga 1/Duo-Liga“; §7: Staffeln, Berufe (statt „Nebenjobs“), PvP = Arenen opt-in | mit ST1-D |
| **CR-32** | `07` | (a) `classes.json` → `rt.bar` (Schema wie `party.json`), `RtSim.bar()` vereint Figur- und Klassenleiste; (b) `RtMods`-Quellen `talent:<id>` und `class:<id>`, Reihenfolge Ausrüstung → Spezies → Klasse → Talente → Show-Boss → Twists; Talent-Art `rt_mod` mit Operationen aus `MOD_OPS`; (c) Gast-Einheit `p2` aus Klassenvorlage × Stufe (Partner-KI „Unterstützen“, kein Partner-Spezial, nie im Bosskampf); (d) Stufen-Skalierung `enemy_level_pm`, Höchststufe 50 (MP-/HP-Formeln §4.2/§4.3 bis 50 prüfen); (e) Hinweis ohne Sim-Änderung: Schläfer- und Absturz-Kämpfe nutzen `RtSim` headless mit beiden Einheiten auf Autopilot, der `SleepResolver` liest nur (Halt unter 25 % Party-HP für den Fluchtwurf); (f) Ergänzung §2.10: im Kalender-Tempo zählt Kampfzeit zur Staffel-Uhr (nach `end_combat` nachgereicht), ein fälliger Einsturz wartet bis dahin; (g) mit CR-33 entfallen der Harness `--persona` und das nächtliche Persona-Gate (§12.4), §12.9 Nr. 16/17 (Persona-Namen im Kampf) bleiben | (a)–(c) und (g) vor R4, Rest mit ST1 |
| **CR-33** | `08` — **dringend, vor 08 K1** (K0 ist mit 07 R1a gelandet) | „Beruf“ im Casting heißt **„Vorleben“** (Bildschirm 2/3, Overlay „VORLEBEN WÄHLEN“, Zeilen „Vorleben und Hobby …“; IDs `org_*`/`occ_*` bleiben); die **17 Starttalente `tal_org_*` entfallen** und werden durch den Vorsprung aus Kap. 8.6 ersetzt (`origins.json` und `hobbies[]` bekommen in K1 die Spalte `job` als reine Daten — Präfix `job_` ist reserviert, die Referenzprüfung kommt mit ST0). **K1 schrumpft:** keine Starttalent-Daten, kein Tausch in der ersten Talent-Show, kein `test_08_origin_talents`/`_balance`, kein Persona-Balance-Gate; `PersonaRules.check` nimmt bis ST0 `"talent": ""` an (Persona ohne Kampfwirkung, `bias` wirkt). **ST0** ersetzt `persona` v1 durch v2 (Kap. 8.7) und entfernt im selben `SIM_VERSION`-Sprung den ruhenden K0-Pfad (`PartyMember.origin_talent`, Starttalent-Zweig in `Talents.has_any`/`_effects`, `origin_field_range_pm`, `tal_org_`-Prüfung in `Command.validate`; Kap. 9 Zeile R5b: Save v2 ohne `origin_talent`). Karte 3/3 zeigt ab ST1-E „Vorsprung: Erste Hilfe 50 · Kochen 25“ (vorher keine Zeile); Stempel „STAFFEL N · FOLGE M“ mit echter Staffelnummer; **bleiben:** Datenschutz (P-1, P-2, D-1 … D-14), Persona-Datei, `bias`, Erzählstrang, KI-Casting, Avatar-Editor | Text vor K1, Code in K1 und ST0 |

**Distanz-Notiz für 04 Kap. 2.3** (neue Zeile, zur Übernahme mit CR-29):

| Element | Nähe | Vorschlag |
|---|---|---|
| **Staffel-Struktur** (Etagen mit Einsturztermin über Wochen, Spezies und Klasse auf Etage 3, Zähler der verbliebenen Mitkandidat:innen, Ausloggen in der Welt) | **mittel** — jede Mechanik ist frei, die Summe erinnert an das Buch | Ausdruck konsequent eigen: TV-Sprache (Staffel, Folge, Sendeplan, Recall, Vorlauf, „Kulissen im Aufbau“), Rettung durch die Regie (Mit Netz), „Ohne Netz“ statt Buch-Begriffen; im Spiel **Kandidat:innen**, nie „Crawler“; Zähler „Weiße Weste“/„Noch dabei“; keine Etagenthemen, -reihenfolge, Figuren, Titel oder Ränge des Buchs; M.O.D. statt „System-KI“, kein „World Dungeon“; Marketing nennt die Staffel-Struktur nicht als Buch-Bezug |

**Folgeänderungen:** F-1 `README.md` (Status: Talentbaum, Staffel-Modus, Begriffe); F-2 Screenshots nach ST1-H
(Sendeplan, Login-Bilanz, Talentbaum, Gewerke-Büro); F-3 Testnamen mit „Staffel“ im Sinn von „Etagen-Simulation“
(`test_m7_show_balance`, `test_06c_balance`, GDD §13) in Texten zu „Etagen-Simulation“; F-4 `PERFORMANCE.md` mit
Viertel-Streaming.

### 11.8 Risiken

| # | Risiko | W / A | Gegenmaßnahme | Frühindikator |
|---|---|---|---|---|
| R13 | **Inhaltsmenge** für 18 Etagen | hoch / hoch | Kulissen × 3, wiederkehrende Revier-Bosse, Boss-Baukasten, Platzhalter-Familien, Formate 6 → 12 → 18 | Kulisse > 10 Wochen |
| R14 | **Kalender-Bindung** bricht ab (Leute kommen nicht wieder) | mittel / hoch | Ausgeruht, Aufholjagd, Rettung, Benachrichtigungen, 20 min/Tag reichen; offline „Am Stück“ | Beta: < 60 % erreichen Etage 6 |
| R15 | **Überforderung** durch neue Systeme | mittel / hoch | 06 L-1/L-2, Einführung über Etagen (E1 nichts Neues, E2 Berufe, E3 Recall), Ein-Satz-Tabelle | Playtest < 4/5 Verständnis |
| R16 | **Tod als Schläfer** (Ohne Netz) fühlt sich unfair an | mittel / mittel | klare Warnung, Gefahr je Viertel sichtbar, Notfall-Rückzug, Safe Rooms nah; nur Ohne Netz endgültig | Abbrüche nach Schläfer-Tod |
| R17 | **Determinismus über 84 Tage** | mittel / hoch | Versions-Bindung je Staffel, Anker je Sitzung, Uhr als Command, Plattform-Matrix vor jedem Sprung | Desync im Harness |
| R18 | **Server- und Moderationskosten** (ST2/ST3) | mittel / hoch | Gates mit Messung, Schnellsätze als Standard, Arenen statt Welt-PvP | Kosten je Spielenden über Plan |
| R19 | **KI-Besetzung wirkt künstlich** | mittel / mittel | Kalibrierung an echten Daten, Profile mit Gedächtnis (Pechvogel), Rival:in aus dem Casting, ehrliche Kennzeichnung | Playtest: „Ticker ist egal“ |
| R20 | **IP-Summe** wirkt wie Buch-Kopie | mittel / hoch | Distanz-Notiz 11.7, eigene Begriffe, Distanz-Review vor jedem öffentlichen Auftritt | Community-Kommentare |

---

## 12. Offene Fragen mit Empfehlung

| Nr. | Frage | Empfehlung |
|---|---|---|
| F-1 | Eine oder zwei Etagen Vorlauf? | **Eine.** Zwei würden die Besetzung auf drei Etagen verteilen und den Deckel weniger wirksam machen; Warten bleibt auch mit einer Etage kurz (≤ 5 Tage, nie untätig). |
| F-2 | „Am Stück“ für Online-Staffeln? | **Nein** — eine Uhr für alle ist der Kern des gemeinsamen Erlebens; Am Stück nur privat/offline. |
| F-3 | Können Schläfer Ohne Netz wirklich sterben? | **Ja** (Wunsch der Idee), mit Warnung, Notfall-Rückzug und sichtbarer Gefahr; Mit Netz ist es nur ein Rücksetzer. |
| F-4 | Höchststufe 50 oder 60? | **50**: runde Zahl, Bänder von 3 Stufen je Etage gehen auf, zwei Finalwochen auf Höchststufe. |
| F-5 | Mindestbesetzung öffentlicher Staffeln | **10** Menschen, einstellbar; bei wenig Andrang automatisch 5 nach 24 h Wartezeit **[nach ST2-Beta festlegen]**. |
| F-6 | Härteres PvP („Kopfgeld“)? | Erst nach ST3 und nur als eigene Opt-in-Staffelvorlage; nie gegen Schläfer, nie in öffentlichen Mit-Netz-Staffeln. |
| F-7 | Angeln oder weitere Nebenberufe? | Später („Kanalangeln“ wäre lustig), nicht in ST1/ST2. |
| F-8 | Bleiben Berufswerte über Staffeln? | **Nein** (S-20) — sonst wären neue Kandidat:innen dauerhaft im Nachteil; nur Titel „Legende: <Beruf>“ bleibt. |
| F-9 | Wer bezahlt Online-Staffeln? | Premium + Kosmetik wie 04 §6; ein eigener Beitrag nur, wenn das ST2-Gate es mit Zahlen begründet, und nie mit Spielwirkung **[Geschäftsentscheidung]**. |
| F-10 | Einstieg in laufende Staffeln? | **Nein** in V1 (S-22); falls Wartezeiten zu lang werden: Freunde dürfen in den ersten 48 h einen KI-Platz übernehmen. |
| F-11 | Hat in ST3 jede:r einen eigenen Grafen? | In ST1/ST2 hat jede:r „seinen“ Grafen in der eigenen Instanz. Für ST3 Empfehlung: Begleiter anderer erscheinen als **lizenzierte Mops-Doubles** mit eigenem Namen und Fell („NOVA hat den Publikumsliebling vervielfältigt. Das Original sind natürlich Sie.“) — Satire statt Logikbruch. |
| F-12 | KI-Kandidat:innen in Bosskämpfen? | **Nein** — Boss-Bänder (07 §11) bleiben verlässlich. |
| F-13 | Benachrichtigungen per E-Mail? | Nur als wöchentliche Zusammenfassung, Opt-in, ab ST2. |
| F-14 | Fanclubs (06 §2.4) noch nötig? | Ab Etage 4 als kleine NPC-Aufträge oder direkt als spätere Spielergilden (ST3) — Entscheidung mit dem Etage-4-Design. |
