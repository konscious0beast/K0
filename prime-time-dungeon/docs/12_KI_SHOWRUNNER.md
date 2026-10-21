# PRIME TIME DUNGEON — KI-Showrunner: das Staffel-Drehbuch

> **Grundlage:** Nutzerwunsch vom **2026-10-12**, Wortlaut:
> „Die Geschichte kann sich durchaus immer wieder ändern – also von Staffel zu Staffel. Die KI erzeugt das dann.“
>
> **Rahmen des Orchestrators (verbindlich, hier nicht neu verhandelt):** S-1 … S-7 in Kap. 0.3 — die KI schreibt Texte
> und wählt Kombinationen aus vorhandenen Bausteinen, nie Regeln; Ausgabe ist ein geprüftes JSON-„Staffel-Drehbuch“; es
> ist eine Eingabe der Staffel, kein Teil der Simulation, und wird mit ihr gespeichert; erzeugt wird nur im Dienst
> `mod-brain`, der Client hat einen Offline-Generator; persönliche Daten bleiben auf dem Gerät; Inhaltspakete können den
> KI-Teil kuratieren oder abschalten; geteilte Staffeln bekommen ein Drehbuch für alle.
>
> **Abgestimmt auf** `00_BRIEF.md` (Kap. 1, 4, 6b), `01_GDD.md` (§11.1 M.O.D.-Ton), `02_TECH.md` (Schichten, Seeds),
> `05_LIVE_MODUS.md` (§3.3 Determinismus, §4.3 Versionen, §10.6 externe Eingaben, §11.4 Verifier),
> `06_PROGRESSION_MAROTTEN_KI_ADMIN.md` (L-1 … L-7, Kap. 4 Vorlieben, Kap. 5 KI-Admin), `07_ECHTZEITKAMPF.md` (§2.9
> Boss-Intro, §9.3 Zeilen im Kampf), `08_CASTING.md` (Kap. 2 Privatsphäre, Kap. 4 Platzhalter und Beats, Kap. 5
> KI-Casting), `09_STAFFELN.md` (Kap. 1.2 Sprachregel, 2, 3.1–3.4, 4, 9, 11), `10_MINISPIEL_STEMPELDUELL.md` (Aufbau)
> und `11_SPRACHEN_UND_INHALTSPAKETE.md` (§1.2 `Tx` und PO, §1.10 Determinismus über Sprachen, §1.13 Filter auf
> Englisch, §2 englisches Glossar und Stimmen, §3 Inhaltspakete mit `pack.json`, Overlays, Herkunft, Lizenzblock und
> Aufzeichnung, §4 Mechanik-Baukasten MB1–MB8, F-20). Code-Stand: `ptd/doc12` @ `74c82d7` (09 ST0 und ST1-A … G
> gelandet, **ST1-H Staffel-UI und ST1-I Harness in Arbeit**, ST1-C2 offen; 11 nur als Dokument).
>
> **Status:** Design-Vertrag für die Pakete **KS0 … KS5** (Kap. 9). Für das Staffel-Drehbuch gilt dieses Dokument;
> andere Dokumente ändert es nur über die Änderungsanträge **CR-40 … CR-49** (Kap. 9.7). Vorrang bei Widersprüchen:
> `00_BRIEF` > 07 > 09 > 06 > 08 > **12** > 01/02/03/05 > 04; Sprachen und Inhaltspakete regelt 11 (im Rang von
> `02_TECH`), auch für das Drehbuch.
>
> **Namen:** Die Rahmen-Entscheidungen heißen hier **S-1 … S-7**; Entscheidungen aus 09 heißen deshalb immer „09 S-n“.
> Eigene Entscheidungen: **DR-n**, Prüfregeln **V-n**, Reparaturstufen **R-n**, Pakete **KS0 … KS5** (nicht K0 … K4 aus
> 08), Risiken **KR-n**, offene Fragen **F-n**; Pakete aus 11 mit Präfix („11-P1“, „11-L5“). Im Spiel heißt das System
> **„Drehbuch“**; „Showrunner“ ist nur der Arbeitstitel des Dokuments (für Spieler:innen ist „Showrunner:in“ eine
> Klasse, `data/classes.json`).
>
> **Konventionen:** Prosa Deutsch; IDs, Pfade (relativ zu `prime-time-dungeon/game/` = `res://`, Dienst-Pfade relativ zu
> `services/mod-brain/`), JSON-Keys, Klassen- und Methodennamen Englisch. Spielertexte folgen der Sprachregel aus 09
> Kap. 1.2 („Etage“, „Stufe“, „Kandidat:in“) und den Leitlinien L-1 … L-7 aus 06; M.O.D. siezt und nutzt keine Pronomen
> für die Kandidat:in (08 Kap. 4.4). Alle Zahlen sind **Startwerte**. **[zu prüfen]** = reale Fakten (Recht, Preise,
> Marken), **[zu messen]** = Zielwert, den ein Gate misst, **[Schätzung]** = Aufwand oder Kosten.

---

## Inhalt

0. Kurzfassung (fünf Sätze, Antwort auf den Wunsch, Rahmen S-1 … S-7, Entscheidungen DR-1 …, Ein-Satz-Erklärungen,
   bewusst nicht drin)
1. Begriffe
2. Was Spieler:innen erleben (was wechselt, was bleibt; zwei Beispiel-Drehbücher; wo man es sieht; Kennzeichnung)
3. Das Drehbuch als Datei (Aufbau, Felder, Plan, Platzhalter, Menü, Prüfregeln, Reparatur und Rückfall, Beispiel)
4. Erzeugung (Zeitpunkte, Dienst, Schnittstelle, Prompt, Ausgabeschema, Modell, Lektorat, Kosten, Caching, Moderation,
   Protokolle, Baukasten, Pilot)
5. Einbau ins Spiel (Module, Aufzeichnung, Plan im Kern, Zeilen, Bosse und Programm, Bildschirme, Replays und Verifier,
   Fehlerfälle)
6. Datenschutz
7. Inhaltspakete und kuratierter Modus
8. Geteilte Staffeln und Sprachen
9. Umsetzung (Abhängigkeiten, Pakete KS0 … KS5, Vertrag, Dateien, Tests, Gates, Änderungsanträge)
10. Risiken
11. Offene Fragen mit Empfehlung

---

## 0. Kurzfassung

### 0.1 Für Spieler:innen in fünf Sätzen

1. Jede Staffel hat ein **eigenes Drehbuch**: Titel, Geschichte, Folgen-Mottos, wiederkehrende Figuren, Beinamen der
   Bosse und M.O.D.s Laune wechseln von Staffel zu Staffel.
2. Geschrieben wird es von einer **KI in M.O.D.s Redaktion** — ohne Netz aus dem **Baukasten** der Redaktion; jede
   Ansicht sagt, wer geschrieben hat.
3. Das Drehbuch **wählt nur aus, was das Spiel schon kennt** (welche Programmpunkte kommen, welche Vorlieben M.O.D.
   bevorzugt, welcher Twist die Folge prägt) — Regeln, Werte und Belohnungen bleiben dieselben.
4. **Ihr Name und Ihre Kandidatenkarte bleiben auf dem Gerät**; persönliche Sprüche setzt das Spiel erst dort aus
   Platzhaltern zusammen.
5. Was das Drehbuch festlegt, **steht im Spielstand und gilt die ganze Staffel** — Wiederholungen und Bestenlisten
   rechnen so genau nach wie heute.

### 0.2 Die Antwort auf den Wunsch in einem Absatz

Ja: Von der zweiten Staffel an schreibt eine KI für jede Staffel eine neue Geschichte. Sie tut das **vor** der Sendung
und in einem festen Rahmen: Der Dienst `mod-brain` bekommt nur Kennungen (Format, Prämisse aus einem Katalog, Sprache,
Datenstand), schreibt ein Drehbuch nach festem Schema, ein zweiter Durchgang liest Korrektur, und das Gerät prüft es
noch einmal mit denselben Regeln wie die geschriebenen Zeilen des Spiels. Was das Drehbuch an Spielzustand berührt — die
Reihenfolge der Programmpunkte, eine leichte Gewichtung von M.O.D.s Vorlieben und Regie-Twists —, wird als externe
Eingabe aufgezeichnet wie die Staffel-Uhr; alles andere ist Text, den die Simulation nie liest. Ohne Netz, ohne
Einwilligung oder bei einem schlechten Ergebnis schreibt der **Baukasten** auf dem Gerät ein Drehbuch nach demselben
Schema; die erste Staffel eines Geräts ist ein handgeschriebener **Pilot**. So ändert sich die Geschichte von Staffel zu
Staffel, ohne dass ein Start je auf das Netz wartet oder eine KI an den Regeln dreht.

### 0.3 Rahmen des Orchestrators

Herkunft: **R** = Rahmen des Orchestrators (verbindlich), **D** = Detailentscheidung dieses Dokuments.

| Nr. | Thema | Entscheidung | Herkunft | Kap. |
|---|---|---|---|---|
| S-1 | Was die KI darf | Die KI **schreibt Texte und wählt Kombinationen, nie Regeln.** Sie wählt und benennt aus vorhandenen Bausteinen: Kulissen je Etage, Gegnerfamilien, Boss-Baukasten (09 Kap. 3.4) und Mechanik-Baukasten MB1–MB8 (11 Kap. 4), Programmpunkt-Pools, Event-Typen, Vorlieben (Marotten), Twists aus 06-D, Sponsoren, Erfolge. Sie schreibt Staffeltitel und Logline, M.O.D.s Stimmung und Bogen über die Wochen, ein kleines wiederkehrendes Ensemble benannter Figuren (Sponsor, Rival:in, Insider:in, Produktion, Gäste), je Etage ein Showformat und einen Twist aus einem festen Menü, Boss-Namen und -Intros, Event- und Programmpunkt-Texte, Namen und Texte von Auszeichnungen, Rückblicke und das Finale. Balance-Zahlen bleiben in den Daten. | R | 2, 3, 5 |
| S-2 | Ausgabe und Prüfung | Ausgabe ist ein JSON-**„Staffel-Drehbuch“** mit Schema; ein neuer Validator prüft Schema, Längen, Verweise auf vorhandene IDs, `validators/ip_words.gd`, die Sprachregel 09 Kap. 1.2, `data/mod_filter.json` und die Humorregeln 06 L-1 … L-7. Ungültiges wird repariert oder fällt zurück. | R | 3.7, 3.8 |
| S-3 | Determinismus | Das Drehbuch ist **eine Eingabe, kein Teil der Simulation**; es wird mit der Staffel gespeichert (Hash im Staffel-Zustand, Journal, Spielstände); Replays und beide Verifier bleiben exakt. Erzeugt wird bei „Neue Staffel“ (optional je Akt); jeder Teil wird bei Eintreffen aufgezeichnet. | R | 5.2, 5.7 |
| S-4 | Ort der Erzeugung | **Nur im Dienst `services/mod-brain`** (Python, Claude API); kein API-Schlüssel im Client; Zeitlimits, Wiederholungen und Kosten je Staffel; der Client blockiert nie einen Start auf das Netz; ein **Offline-Generator** (mit Seed, kuratierte Bausteine und Namenslisten wie `data/cast.json`) schreibt ein Drehbuch nach demselben Schema. | R | 4 |
| S-5 | Datenschutz | Persona-Daten bleiben auf dem Gerät; der Dienst bekommt höchstens grobe, ausdrücklich eingewilligte IDs (Vorleben, Hobby, Eigenschaft) — nie Freitext, Namen oder Fotos; persönliche Note per Platzhalter auf dem Gerät; Einwilligungszeile und Standard „aus“. | R | 6 |
| S-6 | Inhaltspakete | Pakete (11 Kap. 3) bringen Bausteine, Weltglossar und Stilbuch; ein Lizenzgeber kann den **kuratierten Modus** (KI wählt nur aus vorab freigegebenen Vorlagen und variiert leicht) oder „aus“ verlangen; der Schalter ist generisch, kein Fremd-Franchise wird genannt. | R | 7 |
| S-7 | Geteilte Staffeln | Der Server erzeugt **einmal für alle** Spieler:innen der Staffel (beide Sprachen, sobald Englisch existiert, 11). | R | 8 |

### 0.4 Entscheidungen dieses Dokuments

| Nr. | Thema | Entscheidung | Kap. |
|---|---|---|---|
| DR-1 | Pilot | Die **erste Staffel eines Geräts** spielt ein handgeschriebenes Drehbuch der Redaktion (`data/drehbuch/pilot.json`, „Drehbuch: Redaktion“) — ohne Netz, ohne Einwilligung, in bester Qualität. Ab der zweiten Staffel: KI, sonst Baukasten. | 4.13 |
| DR-2 | Generalprobe bleibt Kanon | Etage 1 bleibt unverändert (handgebaut, Kanon-Texte). Das Drehbuch beginnt mit dem **Vorspann** beim ersten Betreten von Etage 2; bis dahin steht im Reiter „Staffel“: „Die Redaktion schreibt noch.“ | 2.3, 5.4 |
| DR-3 | Drei Teile | **Teil 1** = Rahmen + Etagen 2–6, **Teil 2** = Etagen 7–12, **Teil 3** = Etagen 13–18. Jeder Teil wird einzeln aufgezeichnet, sobald er geprüft vorliegt, **spätestens bevor seine erste Etage betreten wird** — sonst bindet der Client den Baukasten-Teil (fehlt Teil 1, schreibt der Baukasten alle Teile, damit das Ensemble zusammenpasst). Ein Teil mit schon betretener Etage wird abgelehnt (`script_late`). | 4.1, 5.2 |
| DR-4 | Plan und Text getrennt | Der **Plan** (nur IDs) steht im Staffel-Zustand und im Hash; der **Text** liegt in einer eigenen Datei, sein SHA-256 (Satz-Hash) steht neben dem Plan. **Die Simulation liest nie Text.** | 3.3, 5.2 |
| DR-5 | Mottos | Ein Menü von **12 Folgen-Mottos** (Redaktion), jedes mit **zwei bevorzugten Vorlieben** und **zwei bis drei erlaubten Twists**. Der aufgezeichnete Plan trägt die Vorlieben-IDs selbst — die Simulation braucht keine neue Tabelle, `DB.data_hash()` ändert sich nicht. | 3.6, 5.3 |
| DR-6 | Twist der Folge | Die Offline-Regie wählt den Twist der Folge mit **dreifachem Gewicht**; Zeilen über ihn kommen nur, wenn er wirklich eintritt. Merksatz: **„Das Drehbuch verspricht nur, was eintritt.“** | 5.3, 5.4 |
| DR-7 | Programmpunkte | Das Drehbuch legt die **Reihenfolge** der fünf Programmpunkte je Etage aus dem Pool der Kulisse fest und gibt ihnen Sendungsnamen und Ansagen; Inhalt und Belohnung der Punkte bleiben. | 5.3, 5.5 |
| DR-8 | Rollen bleiben | Bosse behalten ihren Rollennamen („Die Schichtleiterin“); das Drehbuch gibt jeder **Figur einen Beinamen** (≤ 28 Zeichen), ein Motiv, Intro- und Siegeszeilen; Show-Boss-Gruppen bekommen einen Namen. Ganze Umbenennung später (F-4). | 5.5 |
| DR-9 | Namen und Marken aus Listen | Figuren-Namen kommen aus `data/drehbuch/names.json` (erfunden, alliterierend, getrennt von `cast.json` und den Rival:innen aus 08), der Hauptsponsor aus `data/drehbuch/brands.json`. **Die KI erfindet nie Namen oder Marken.** Die Rival:in erscheint nur als `{rival}` (08). | 3.6 |
| DR-10 | Prämissen | Ein Katalog von zunächst **12 Prämissen** (`prm_*`); das Gerät wählt mit dem Staffel-Seed und meidet die letzten drei; die KI erzählt die Prämisse aus. | 3.6, 4.4 |
| DR-11 | Ein Prüfer, zwei Seiten | Der Validator in GDScript ist maßgeblich; der Dienst prüft mit einer Python-Portierung vorab; beide teilen Fixtures (`tests/fixtures/drehbuch/cases.json`). Geflickt wird nur auf dem Gerät. | 3.7 |
| DR-12 | Lektorat | Ein **zweiter Modelldurchgang** prüft Ton, Stimmigkeit und Sicherheit gegen eine feste Liste, bevor ausgeliefert wird; danach höchstens **eine** Reparaturrunde. | 4.7 |
| DR-13 | Keine Behauptungen | Das Drehbuch behauptet nichts über die Kandidat:in, keine Regel, keine Zahl (**keine Ziffern im Freitext**). Wahre Hinweise nur über `{tip}`, den das Spiel aus dem Zustand füllt. | 3.4 |
| DR-14 | Erzählbudget | Höchstens **eine Drehbuch-Zeile je Haken**; Persona-Beats aus 08 haben Vorrang; **nie im Kampf** — einzige Ausnahme ist das Boss-Intro vor dem Kampf (07 §2.9). | 5.4 |
| DR-15 | Kennzeichnung | Überall, wo das Drehbuch erscheint, steht die Quelle („Drehbuch: KI / Baukasten / Redaktion / kuratiert“); KI-Zeilen tragen im Dialog ein **KI-Zeichen** (Standard an); jede Zeile lässt sich ausblenden und melden. | 2.4 |
| DR-16 | Stufen | **D0** offline (Pilot + Baukasten) → **D1** KI als Beta zum Einschalten → **D2** KI als Standard nach dem KS5-Gate → **D3** geteilte Staffeln (09 ST2). | 9.1 |
| DR-17 | Persönliche Note | Eigene Einwilligung **ab 16, Standard aus**: höchstens drei grobe IDs (Vorleben-Gruppe, Hobby, eine Eigenschaft), keine Speicherung nach dem Auftrag. Ohne sie ist das Drehbuch trotzdem persönlich — über Platzhalter. | 6 |
| DR-18 | IDs nie löschen | Menü-IDs (Mottos, Prämissen, Namen, Marken, Figuren) werden **stillgelegt, nie gelöscht oder neu vergeben** — alte Drehbücher bleiben lesbar. | 3.6 |
| DR-19 | Vorproduktion und Archiv | Nach einer Staffel kann der Client das nächste Drehbuch **per Batch** bestellen (halber Preis, bis 24 h); ein zu spät fertiges KI-Drehbuch wandert ins **Archiv** für die nächste Staffel. | 4.9 |
| DR-20 | Aufträge statt offener Verbindungen | Der Client gibt einen **Auftrag** ab und fragt nach; er wartet nie; Frist verpasst → Baukasten. | 4.3 |
| DR-21 | Sprache | Ein privates Drehbuch hat **eine** Sprache, festgelegt bei der Erzeugung; geteilte Staffeln haben **einen Plan, je Sprache einen Text und einen Hash über den ganzen Satz**. Aufgezeichnet werden nur Plan und Satz-Hash, nie eine Sprache: Die Anzeigesprache ändert nie, was im Spielstand steht (11 O-5). | 5.2, 8 |
| DR-22 | Kein Neu-Würfeln | Es gibt keinen Knopf „neues Drehbuch“: Das Drehbuch gehört zur Staffel wie ihr Seed. Wer es nicht mag, blendet KI-Zeilen aus oder schaltet die KI für die nächste Staffel ab. | 2.4 |
| DR-23 | Kostendeckel | Deckel je Auftrag, je Konto (3 am Tag, 10 im Monat) und je Monat (`MOD_BRAIN_SCRIPT_BUDGET_USD`); darüber schreibt der Baukasten — gekennzeichnet, ohne Fehlermeldung. | 4.10 |

### 0.5 Ein-Satz-Erklärungen (06 L-1)

| Begriff | Ein Satz (so sagt es das Spiel) |
|---|---|
| Drehbuch | „Jede Staffel erzählt eine eigene Geschichte — das Drehbuch legt Titel, Folgen und Figuren fest, nie die Regeln.“ |
| Folge | „Jede Etage ist eine Folge mit Titel, Motto und einem Twist, der in ihr öfter vorkommt.“ |
| Motto | „Das Motto der Folge verrät, welche Vorlieben M.O.D. diesmal öfter hat.“ |
| Twist der Folge | „Die Regie greift auf dieser Etage am liebsten zu diesem Twist — wenn sie eingreift.“ |
| Ensemble | „Diese Figuren begleiten die ganze Staffel; sie reden mit, entscheiden aber nichts.“ |
| Beiname | „So nennt die Redaktion den Boss in dieser Staffel — Kampf und Werte bleiben gleich.“ |
| Baukasten | „Ohne Netz schreibt die Redaktion das Drehbuch aus ihren eigenen Bausteinen.“ |
| Persönliche Note | „Mit Ihrer Erlaubnis darf die KI grob wissen, was Sie mögen — Ihr Name und Ihre Karte bleiben auf dem Gerät.“ |

### 0.6 Bewusst nicht drin

- **Keine neuen Regeln, Werte, Gegner, Beute oder Belohnungen** durch die KI; kein Plan-Feld, das eine Zahl trägt.
- **Keine KI im Kampf** und keine Live-Erzeugung während des Spielens (das bleibt „M.O.D. live“ aus 06 Kap. 5).
- **Kein Freitext von Spieler:innen** im Prompt — auch nicht mit Persönlicher Note (06 §5.9 Nr. 2 gilt ohne Ausnahme).
- **Keine KI-Bilder, -Stimmen oder -Musik**; das Drehbuch ist Text und eine Auswahl von IDs.
- **Keine erfundenen Personen- oder Markennamen**, keine echten Personen, Marken, Politik oder Fremd-Franchises.
- **Kein Neu-Würfeln** und kein kaufbares Drehbuch (F-15).
- **Keine Änderung an Etage 1, am Recall (Etage 3), an Tutorials, Regeltexten und Erfolgsbeschreibungen.**

---

## 1. Begriffe

| Begriff | Bedeutung |
|---|---|
| **Drehbuch** (Staffel-Drehbuch, `drb_…`) | Die Geschichte einer Staffel: ein JSON-Dokument je **Teil** mit Plan und Texten (Kap. 3). |
| **Teil** | Abschnitt des Drehbuchs: Teil 1 = Rahmen + Etagen 2–6, Teil 2 = 7–12, Teil 3 = 13–18. Ein Format 6 hat nur Teil 1. |
| **Rahmen** | Staffelweite Felder in Teil 1: Titel, Logline, Tagline, Hauptsponsor, Ensemble, Bogen, Figuren, Auszeichnungen, Vorspann. |
| **Plan** | Die IDs, die der Kern auswertet: Etagen-Definition, Motto, Vorlieben, Twist der Folge, Programmpunkt-Reihenfolge (Kap. 3.3). |
| **Drehbuch-Satz** | Plan eines Teils + dessen Texte in allen Sprachen (privat: eine); sein SHA-256 steht im Spielstand (Kap. 5.2). |
| **Folge** | Eine Etage ab 2 im Drehbuch: Titel, Motto, Twist der Folge, Texte, Rückblick, Ausblick. |
| **Motto** (`mot_*`) | Showformat der Folge aus dem Menü (Kochduell, Quizabend …) mit zwei Vorlieben und erlaubten Twists. |
| **Twist der Folge** | Ein Twist aus 06-D, den die Offline-Regie auf dieser Etage bevorzugt (Kap. 5.3). |
| **Ensemble** | 3–5 wiederkehrende Figuren: Produktion, Insider:in, 1–3 Ehrengäste; dazu Hauptsponsor und `{rival}`. |
| **Figur** (`fig_*`) | Ein Boss über seine Auftritte hinweg (die Schichtleiterin auf Etage 4–6 ist eine Figur). |
| **Beiname** | Staffel-Zusatz zum Rollennamen eines Bosses („Die Schichtleiterin — Frau Feierabend“). |
| **Prämisse** (`prm_*`) | Ausgangsidee aus dem Katalog („NOVA spart“), die das Gerät wählt und die KI ausformuliert. |
| **Menü** | Alles, woraus das Drehbuch wählen darf: IDs aus `data/*.json` und den Listen in `data/drehbuch/` (Kap. 3.6). |
| **Baukasten** (`DrehbuchKit`) | Der Offline-Generator auf dem Gerät: kuratierte Bausteine + Seed → Drehbuch nach demselben Schema (Kap. 4.12). |
| **Pilot** | Handgeschriebenes Drehbuch der ersten Staffel eines Geräts (DR-1). |
| **Lektorat** | Zweiter Modelldurchgang im Dienst: prüft und meldet, schreibt nicht neu (Kap. 4.7). |
| **Flicken** | Ersatz eines ungültigen Textfelds durch Baukasten-Text auf dem Gerät (R-3). |
| **Ersatztexte** | Baukasten-Texte zu einem vorhandenen Plan, wenn die Textdatei fehlt oder nicht passt (Kap. 5.8). |
| **Erzählbudget** | Höchstens eine Drehbuch-Zeile je Haken-Ereignis (DR-14). |
| **Persönliche Note** | Opt-in, mit dem bis zu drei grobe Persona-IDs den Dienst erreichen (Kap. 6.3). |
| **Quelle** (`src`) | `ai` · `offline` (Baukasten) · `pilot` · `curated` (kuratierter Modus) · `shared` (geteilte Staffel). |
| **Auftrag** (`job`) | Eine Bestellung beim Dienst für alle Teile einer Staffel (Kap. 4.3). |

---

## 2. Was Spieler:innen erleben

### 2.1 Was wechselt, was bleibt

| Wechselt von Staffel zu Staffel (Drehbuch) | Bleibt immer gleich (Spiel) |
|---|---|
| Staffeltitel, Logline, Tagline; Hauptsponsor der Präsentation mit Slogan | Regeln, Werte, Gegner, Beute, Belohnungen, Bosse samt Phasen und Mechanik |
| Ensemble: Produktion, Insider:in, 1–3 Ehrengäste mit Kurzbiografie und Zeilen; die Rival:in als `{rival}` | Kulissen und ihre Reihenfolge (09 Kap. 3.1), Sendeplan, Einsturztermine, Treppenregel |
| M.O.D.s Bogen: Stimmung je Folge (`snarky` / `sweet` / `neutral`) mit Notiz | M.O.D.s Persona, Stimme und Siezen; Graf Mopsula (Ich-Form, Fußnoten, ohne Königsmotive); NOVA; Kai |
| Je Etage ab 2: Folgentitel, Motto, Twist der Folge, Reihenfolge und Namen der Programmpunkte | Inhalt der Programmpunkte, Event-Typen und ihre Wirkung; Vorlieben-Regeln und Belohnungen |
| Beinamen, Motive, Intro- und Siegeszeilen der Bosse; Namen der Show-Boss-Gruppen | Rollennamen der Bosse, Banner-Layout, Kampfzeilen (`boss_phase`, alles im Kampf) |
| Event-Zeilen, Zwischenrufe, Ansagen der Programmpunkte, Namen und Zeilen der Auszeichnungen | Erfolge selbst: Name, Beschreibung, Bedingung, Belohnung (06 §5.2: Regeltexte bleiben geschrieben) |
| Rückblicke und Ausblicke je Folge, Finale-Text je Ergebnis, Abspann | Etage 1 (Generalprobe), Recall (Etage 3), Tutorials, Hilfetexte, Titel und Quote (09 Kap. 2.7) |
| — | Persona-Beats und Sendepläne aus 08; die KI-Besetzung mit ihren Namen (09 Kap. 4) |

### 2.2 Zwei Beispiel-Drehbücher für dasselbe Format

Beide Beispiele gelten für das Format **Basis (6 Etagen)**: Etage 1 Unterstadt (Generalprobe, Kanon), Etage 2 Passage
Ewiger Rabatt, Etage 3 Fundus (Recall), Etagen 4–6 Paketzentrum. Gleiche Etagen, gleiche Gegner, gleiche Bosse, gleiche
Werte — zwei Geschichten. Es sind **Beispiele für Ton und Spannweite, keine Inhalte**; Marken- und Namensprüfung **[zu
prüfen]**.

| Feld | **A — „Der große Ausverkauf“** (`prm_ausverkauf`) | **B — „Der Sparkurs“** (`prm_sparkurs`) |
|---|---|---|
| Logline | „NOVA hat die Sendung versteigert: Jede Folge gehört einer anderen Firma — und jede will ihre eigene Show.“ | „NOVA spart: weniger Licht, weniger Kulisse, weniger Gage. Nur die Show soll aussehen wie immer.“ |
| Tagline | „Alles muss raus. Nur Sie bleiben drin.“ | „Weniger ist weniger.“ |
| Hauptsponsor | **Preisrutsch** — „Heute billiger als gestern.“ | **Funzelfix** — „Licht für alle, die sparen müssen.“ |
| Produktion | **Petra Pausenzeichen** — „Produktionsleiterin. Verkauft jede Minute Sendezeit zweimal und merkt es nie.“ | **Konrad Kassenbuch** — „Controller mit Taschenlampe. Streicht alles, was leuchtet, außer der eigenen Lampe.“ |
| Insider:in | **Bert Bolzenschneider** — „Bühnentechniker. Kennt jede Falltür und flüstert gern.“ | **Lotte Lötzinn** — „Haustechnikerin. Repariert, was der Sparkurs kaputtspart.“ |
| Ehrengast | **Gerda Goldrand** (Etage 3) — „Auktionatorin. Versteigert alles, was nicht festgeschraubt ist.“ | **Wilma Windrose** (Etage 5) — „Wetterfee a. D. Sagt jetzt Pakete an statt Regen.“ |
| M.O.D.s Bogen (E2 → E6) | übermütig → gereizt → erschöpft → trotzig → gerührt | misstrauisch → sparsam → erfinderisch → müde → großzügig |
| Etage 2 | „Alles muss raus“ · Rabattschlacht · Doppel-Credits | „Licht aus, Rabatt an“ · Naturdoku · Stromausfall |
| Etage 3 | „Die große Anprobe“ · Talentabend · Konfetti-Gravitation | „Alles aus zweiter Hand“ · Retro-Abend · Mopsula-Monolog |
| Etage 4 | „Zustellung gescheitert“ · Inventur · Rattenregen | „Pakete ohne Porto“ · Heimwerker-Stunde · Ruhe im Studio |
| Etage 5 | „Die Retourenwoche“ · Rekordjagd · Partyhüte für Gegner | „Die Nachtschicht“ · Krimidinner · Ruhmesnebel |
| Etage 6 (Finale Basis) | „Der letzte Ladenschluss“ · Gala · Mopsula moderiert | „Die Gala ohne Budget“ · Talentabend · Konfetti-Gravitation |
| Beinamen (Figuren) | Filialleiterin „die Unverkäufliche“ · Ausverkauf „Restposten des Jahrhunderts“ · Requisiteurin „die Inventurliste“ · Garderobe „Anprobe ohne Ende“ · Schichtleiterin „Frau Feierabend“ · Paketberg „der Unverkaufte“ | Filialleiterin „die Stromsparerin“ · Ausverkauf „Restlicht“ · Requisiteurin „die Wiederverwerterin“ · Garderobe „Kleiderkammer“ · Schichtleiterin „die Sparschicht“ · Paketberg „Lager der guten Absichten“ |
| Bevorzugte Vorlieben (aus den Mottos) | Second-Hand-Schick, Schleichwerbung, Akrobatik-Abend, Stilnote, Schnellschnitt, Der Graf hat das letzte Wort | Friedliche Runde, Schleichwerbung, Nur der Mopp, Kein Schritt zurück, Akrobatik-Abend, Stilnote |
| Auszeichnung (Beispiel) | `ach_crit_3` → „Preissturz“ | `ach_events_all` → „Sparfuchs“ |

Ausgewählte Zeilen (Haken in Klammern, Kap. 5.4; Platzhalter füllt das Gerät):

| Haken | A — „Der große Ausverkauf“ | B — „Der Sparkurs“ |
|---|---|---|
| Vorspann (`drb_vorspann`) | „Die Generalprobe ist vorbei. Willkommen zu Staffel {season}: ‚Der große Ausverkauf‘ — alles muss raus!“ | „Willkommen zu Staffel {season}: ‚Der Sparkurs‘. NOVA spart am Licht, an der Kulisse — nur nicht an Ihnen.“ |
| Folgenstart E2 (`drb_floor:2`) | „Neue Folge: ‚Alles muss raus‘. Die Passage gehört heute Preisrutsch — jede Ecke trägt ein Preisschild.“ | „Neue Folge: ‚Licht aus, Rabatt an‘. Funzelfix leuchtet die Passage aus. Also: ein bisschen.“ |
| Insider:in, erster Safe Room (`drb_safe:2`) | „Bert Bolzenschneider flüstert: {tip}“ | „Lotte Lötzinn raunt: {tip}“ |
| Produktion (Zwischenruf) | „Petra Pausenzeichen lässt ausrichten: Die nächste Werbepause ist schon verkauft. Zweimal.“ | „Konrad Kassenbuch meldet: Der Applaus wird gekürzt. Bitte jubeln Sie ab heute nur halb so laut.“ |
| Graf Mopsula (Stimme `mopsula`) | „Fußnote neun: Ein Graf feilscht nicht. Ich nenne es Verhandlung — und ich gewinne sie.“ | „Ich habe das Budget der Staffel gelesen. Es war kurz. Fußnote eins: Ich bringe meine eigene Kerze mit.“ |
| Rival:in | „{rival} wurde in der Passage gesehen — mit einem Einkaufswagen voller Ausreden.“ | „{rival} spart auch: an Höflichkeit. Und an Anlauf.“ |
| Twist der Folge tritt ein (`drb_twist:2`) | „Doppel-Credits! Preisrutsch nennt es Rabatt. Die Buchhaltung nennt es ein Versehen.“ | „Stromausfall! Funzelfix übernimmt. Sehen Sie das Licht am Ende der Passage? Das ist der Notausgang.“ |
| Programmpunkt (`drb_programme:…`) | „Halle B öffnet: Die Nacht der roten Preisschilder. Alles muss raus, auch die Gegner.“ | „Heute im Programm: Lagerverkauf im Dunkeln. Funzelfix verteilt eine Kerze pro Halle.“ |
| Boss-Intro Filialleiterin (`boss_intro:enm_boss_filialleiterin`) | „Die Filialleiterin ist unverkäuflich, sagt sie. Heute prüft sie, ob {name} es auch ist.“ | „Die Filialleiterin hat das Licht abbestellt. Ihr Lächeln leuchtet trotzdem. Leider.“ |
| Rückblick E3 (Etagen-Bilanz) | „Der Fundus ist versteigert, Stück für Stück. Gerda Goldrand hat den letzten Kleiderbügel an sich selbst verkauft.“ | „Der Fundus ist recycelt: Aus drei alten Kulissen wurde eine neue. Das Publikum hat es nicht gemerkt. Fast.“ |
| Ausblick E2 → E3 | „Nächste Folge: Gerda Goldrand versteigert den Fundus — Stück für Stück, Kulisse für Kulisse.“ | „Nächste Folge: Alles aus zweiter Hand. Auch die Witze, sagt die Regie. Wir widersprechen.“ |
| Finale geschafft (`finale.finalist`) | „Der letzte Ladenschluss: Alles ist raus, nur {name} ist noch drin. Preisrutsch nennt das Kundenbindung.“ | „Die Gala ohne Budget ist vorbei — und {name} hat sie gewonnen. Konrad Kassenbuch hat geweint. Leise.“ |
| Abspann (`credits`) | „Alles muss raus — auch der Abspann. Gute Nacht aus dem Lager.“ | „Die Staffel war billig, das Gefühl nicht. Licht aus — diesmal mit Absicht.“ |
| Auszeichnung (`achievement:…`) | „Auszeichnung ‚Preissturz‘: So viele Volltreffer gab es nicht mal im Schlussverkauf.“ | „Auszeichnung ‚Sparfuchs‘: Alle Events der Etage, und kein Licht verschwendet.“ |

Was beide Beispiele zeigen: Der Ton ändert sich (A laut und überdreht, B trocken und leise), die Zielscheibe bleibt
dieselbe — der Konzern, die Show-Maschinerie, die Bürokratie (06 L-3). Keine Zeile behauptet etwas über die Kandidat:in,
keine nennt eine Zahl oder eine Regel; was wahr sein muss, liefert `{tip}` aus dem Spielzustand (DR-13). Die
Plan-Unterschiede sind spürbar, aber klein: andere Programmpunkte zuerst, andere Vorlieben öfter, ein anderer Twist
bevorzugt.

### 2.3 Wo man es sieht

| Ort | Was erscheint | Datei (Paket) | Wann |
|---|---|---|---|
| „Neue Staffel“ | Zeilen „Drehbuch: KI (Beta)“ bzw. „Drehbuch: Redaktion (Pilot)“ und „Persönliche Note: aus · Ihre Karte bleibt auf dem Gerät · [Ändern ›]“, je mit Ein-Satz-Erklärung | `scenes/title/season_setup.gd` (ST1-H, KS4) | vor dem Start |
| Slot-Liste, Titelbildschirm | Staffeltitel unter „Staffel N“ und die Quelle | `scenes/title/slot_select.gd` (KS4) | ab dem Vorspann |
| **Vorspann-Karte** | Staffel-Nummer und Titel, Logline, Tagline, „präsentiert von“ Hauptsponsor, Ensemble mit Rollen, Quelle; danach `drb_vorspann` | `scenes/ui/season_opening.*` (neu, KS4) | erstes Betreten von Etage 2, überspringbar |
| M.O.D.-Dialog | Drehbuch-Zeilen an festen Haken, KI-Zeichen neben dem Sprecher | `scenes/ui/mod_dialog.gd` (KS3/KS4) | ab Etage 2, nie im Kampf |
| Boss-Banner und -Intro | Beiname hinter dem Rollennamen, Intro-Zeile | `scenes/exploration/exploration.gd` (Banner-Name), Tag `boss_intro:<id>` | vor dem Bosskampf (07 §2.9) |
| Reiter „Staffel“ | Kopfzeile mit Staffeltitel; neues Segment **„Drehbuch“**: Logline, Ensemble, Folgen bis zur aktuellen mit Titel, Motto und Rückblick, nächste Folge nur mit Titel; Quelle, „Zeile melden“ | `scenes/ui/season_tab.gd`, `season_view.gd` (ST1-H, KS4) | immer in einer Staffel |
| Programm-Segment, Karte | Sendungsname des Programmpunkts statt des Datennamens, Marker „NEU“ wie bisher | `season_tab.gd`, Karte (KS4) | zur Sendezeit |
| Etagen-Bilanz | Folgentitel, Rückblick, Ausblick auf die nächste Folge | `scenes/ui/floor_summary.gd` (KS4) | Etagenende |
| Login-Bilanz | Rückblick der Folge, die im Schlaf zu Ende ging | Login-Bilanz (09 Kap. 5.4, KS4) | nach dem Login |
| Staffel-Bilanz | Finale-Text nach Ergebnis (`finalist`, `end`, `fallen`, `buried`, `left`), Abspann, Auszeichnungen unter ihren Staffelnamen | `scenes/ui/season_summary.gd` (ST1-H, KS4) | Staffelende |
| Ruhmeshalle | Staffeltitel und Quelle — ohne Namen (08 P-1) | `scenes/ui/hall_of_fame.gd`, `SeasonView.hall_entry` (ST1-H, KS4) | danach |
| Lobby geteilter Staffeln | Titel, Logline, Quelle | 09 ST2/ST3 | vor dem Beitritt |

Vorspann-Karte (Skizze, 1280 × 720; Captures in KS4):

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   STAFFEL 4 · NEUE FOLGEN                                    │
│                                   DER GROSSE AUSVERKAUF                                      │
│     NOVA hat die Sendung versteigert: Jede Folge gehört einer anderen Firma — und jede       │
│     will ihre eigene Show.                                   „Alles muss raus. Nur Sie       │
│                                                               bleiben drin.“                 │
│  Mit: Petra Pausenzeichen (Produktion) · Bert Bolzenschneider (Insider) · Gerda Goldrand     │
│  (Ehrengast) · präsentiert von Preisrutsch                                                   │
│  Drehbuch: KI · M.O.D.s Redaktion                                    [Weiter ›]  (A / Enter) │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Segment „Drehbuch“ im Reiter „Staffel“ (Skizze):

```text
┌ DREHBUCH ───────────────────────────────────────────────────────── Drehbuch: KI [Melden ›] ┐
│ Der große Ausverkauf — NOVA hat die Sendung versteigert …                                  │
│ Ensemble: Petra Pausenzeichen · Bert Bolzenschneider · Gerda Goldrand · Dr. Till Tupfer    │
│ E2  Alles muss raus        Rabattschlacht   ✓  „Die Passage hat geschlossen …“             │
│ E3  Die große Anprobe      Talentabend      ▶  läuft                                       │
│ E4  Zustellung gescheitert                     nächste Folge                               │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

Die Zeile „E4“ zeigt nur den Titel: Motto und Twist künftiger Folgen bleiben verborgen (keine Vorschau auf Zufall, den
es noch nicht gibt; Kap. 5.3).

### 2.4 Kennzeichnung und Kontrolle

- **Quelle immer sichtbar** (DR-15): „Drehbuch: KI“, „Drehbuch: Baukasten“, „Drehbuch: Redaktion“ (Pilot) oder
  „Drehbuch: kuratiert“ (Kap. 7) auf Vorspann-Karte, Reiter, Staffel-Bilanz, Slot und Ruhmeshalle. Ein geflicktes
  KI-Drehbuch bleibt „KI“; ein ganz ersetzter Teil heißt in seinen Folgen „Baukasten“.
- **KI-Zeichen an Zeilen:** Zeilen aus einem Drehbuch der Quelle `ai`, `curated` oder `shared` tragen im M.O.D.-Dialog
  ein kleines „KI“ neben dem Sprecher. Optionen → Staffel → „KI-Zeichen an Zeilen“ (Standard **an**) blendet nur dieses
  Zeichen aus, nie die Quellenangaben.
- **Ausblenden und melden:** Im Segment „Drehbuch“ stehen die letzten zehn Drehbuch-Zeilen mit „Ausblenden“ (ab sofort
  Ersatztext aus dem Baukasten, nur auf diesem Gerät) und „Melden“ (sendet Drehbuch-ID, Feldpfad und einen Grund aus
  einer Liste — nie Text, nie Persona; Kap. 4.10).
- **Abschalten:** Optionen → Staffel → „Drehbuch: KI | Baukasten“ gilt ab der nächsten Staffel; die laufende behält ihr
  Drehbuch (DR-22).
- **Recht:** Transparenzpflichten für KI-erzeugte Inhalte (KI-Verordnung Art. 50) und Offenlegungsregeln der Stores
  **[zu prüfen]**; Text der Store-Seiten in CR-47.

---

## 3. Das Drehbuch als Datei

### 3.1 Aufbau und Ablageorte

- **Ein Dokument je Teil.** Alle Teile einer Staffel tragen dieselbe ID `drb_<16 hex>` (vom Gerät vergeben:
  `CanonicalJson.sha256_hex([season_seed, slot, number])`, erste 16 Zeichen) und unterscheiden sich in `part`.
- **Gerät:** `user://saves/slot_N.drehbuch.json` (in `Save.save_dir`) hält die Dokumente der Staffel, dazu lokal
  ausgeblendete Feldpfade und gemeldete Zeilen (`{"v": 1, "id", "parts": {"1": {…}}, "hidden": [], "reported": []}`).
  Geschrieben wird atomar wie die Slots (`Save._atomic_write`), **bevor** der Teil aufgezeichnet wird; gelöscht wird sie
  mit dem Slot. Sie ist eine Darstellungsdatei neben dem Spielstand — kein Teil von `SaveCodec`, Hash oder Replay (11
  O-5: kein übersetzter oder angezeigter Text im Spielstand). Ein zu spät eingetroffenes KI-Drehbuch liegt in
  `<Save._data_root()>/drehbuch/archive.json` (höchstens ein Satz, mit `data_hash` und Format; DR-19) — mit einem Paket
  also automatisch unter dessen Nutzerordner (11 Kap. 3.8 Nr. 6).
- **Spiel-Daten:** `data/drehbuch/` mit `kit.json` (Menü und Baukasten-Bausteine), `names.json`, `brands.json`,
  `bible.json` (Weltbibel und Stilbuch für Dienst und Lektorat) und `pilot.json`. Der Unterordner liegt **außerhalb von
  `DB.data_hash()`** (wie `data/stempel/`, 10 Kap. 6), wird aber vom Sprach-Lint `test_09_terms` (`data/**/*.json`) und
  von einem eigenen Validator geprüft (Kap. 3.7). Pakete patchen ihn nicht wie Tabellen (11 Kap. 3.10), sondern bringen
  eigene Listen über den `drehbuch`-Block aus Kap. 7 mit (CR-48).
- **Dienst:** liest dieselben Dateien beim Deploy (Katalog je `data_hash` und `kit_v`, wie `catalog.py` heute) und
  speichert Aufträge höchstens 24 h (Kap. 4.10).

### 3.2 Felder

Längen in Zeichen nach der Längenregel (Kap. 3.5); „Anzahl“ prüft V-2. Jedes Objekt hat genau die genannten Schlüssel.

| Pfad | Typ | Grenze | Regel |
|---|---|---|---|
| `schema` | int | `1` | Version des Formats; ein neues Feld erhöht sie (Kap. 9.3) |
| `id`, `part`, `last` | str, int, bool | `drb_` + 16 hex; 1–3 | `last` = der Teil enthält die letzte Etage des Formats (dann Finale statt Akt-Ende) |
| `src`, `lang` | enum | `ai` · `offline` · `pilot` · `curated` · `shared`; `de` (später `en`, 11) | Quelle und Sprache (DR-21) |
| `data_hash`, `kit_v`, `format`, `premise` | str, int, int, str | — | müssen zum Auftrag und zur Staffel passen (V-5) |
| `season.title` | str | ≤ 40 | nur in Teil 1; Staffeltitel ohne „Staffel N“ |
| `season.logline`, `season.tagline` | str | ≤ 160, ≤ 60 | ohne Persona-Platzhalter |
| `season.sponsor` | obj | `brand` aus `brands.json`, `slogan` ≤ 60 | Hauptsponsor der Präsentation, ohne Spielwirkung |
| `season.cast[]` | obj, 3–5 | `role` (`producer` 1, `insider` 1, `guest` 1–3), `name` (`nm_*`), `bio` ≤ 90, `floors` (nur Gäste, Etagen des Teils 1) | Ensemble; Namen aus `names.json` (DR-9) |
| `season.awards[]` | obj, 6–10 | `ach` aus dem Auszeichnungs-Menü, `name` ≤ 32, `line` ≤ 110 | je `ach` höchstens einmal |
| `season.vorspann` | str | ≤ 110 | M.O.D.s erste Zeile nach der Vorspann-Karte |
| `figures.<fig>` | obj | `epithet` ≤ 28, `motive` ≤ 110 | genau die Figuren der Etagen des Teils |
| `plan.<floor>` | obj | Kap. 3.3 | genau die Etagen des Teils im Format |
| `floors.<n>.title`, `.motto_name` | str | ≤ 40, ≤ 24 | Folgentitel; Anzeigename des Mottos (darf das Menü-Wort variieren) |
| `floors.<n>.mood`, `.note` | enum, str | `snarky` · `sweet` · `neutral`; ≤ 90 | M.O.D.s Bogen (06 §5.2: Stimmung wählen) |
| `floors.<n>.open`, `.safe`, `.twist` | str | je ≤ 110 | Haken `drb_floor`, `drb_safe`, `drb_twist` (Kap. 5.4) |
| `floors.<n>.bosses.<enemy>` | obj | `intro[]` 1–2 × ≤ 110, `won` ≤ 110 | genau die Bosse der Etage aus `floors.json` (`quarter_boss`, `floor_boss`) |
| `floors.<n>.showboss` | obj | `name` ≤ 32, `line` ≤ 110 | Name der Show-Boss-Gruppe der Etage |
| `floors.<n>.programme[]` | obj | `id` wie im Plan, `name` ≤ 40, `line` ≤ 110 | ein Eintrag je Programmpunkt des Plans, gleiche Reihenfolge |
| `floors.<n>.events.<type>` | str | ≤ 110, 0–5 | nur Typen aus `FloorEvent.TYPES`, die auf der Etage vorkommen |
| `floors.<n>.lines[]` | obj, 4–10 | `who` (Kap. 3.4), `text` ≤ 110 | Zwischenrufe des Ensembles, M.O.D.s und des Grafen |
| `floors.<n>.recap`, `.cliff` | str | ≤ 200, ≤ 110 | Rückblick (erzählt die Folge, nicht die Leistung) und Ausblick |
| `end.cliff` | str | ≤ 110 | nur wenn `last == false`: Akt-Ende mit Ausblick auf den nächsten Teil |
| `end.finale.<result>`, `end.credits` | str | je ≤ 160; ≤ 80 | nur wenn `last == true`; `result` ∈ `finalist`, `end`, `fallen`, `buried`, `left` (`SeasonState.RESULTS`) |
| `meta` | obj | `model`, `created` (UTC), `review`, `repaired`, `patched[]`, `persona` (bool) | für Protokoll und Anzeige; Teil des Hashes |

Größe eines Teils **≤ 64 KB** (kanonisches JSON). Teil 1 eines Basis-Formats hat ≈ 120–160 Textfelder.

### 3.3 Der Plan — das Einzige, was der Kern liest

```json
"plan": {
  "2": {"def": "floor_2", "motto": "mot_rabattschlacht", "bias": ["mar_secondhand", "mar_sneaky"],
        "twist": "tw_double_credits",
        "programme": ["daily_passage_midnight_sale", "daily_passage_remnants", "daily_passage_window",
                      "daily_passage_survey", "daily_passage_wheel_shift"]},
  "3": {"def": "floor_3", "motto": "mot_talentabend", "bias": ["mar_stunt", "mar_variety"],
        "twist": "tw_confetti_gravity", "programme": ["…"]}
}
```

| Feld | Kern-Regel (`DrehbuchRules.refusal`, Ablehnung `script_plan`) | Wirkung (Kap. 5.3) |
|---|---|---|
| Schlüssel | genau die Etagen des Teils, die im Format liegen | — |
| `def` | heute nur die Standard-Etage (`floor_<n>`; ein Paket ändert ihre Daten, nicht ihre ID, 11 Kap. 3.4); Haken für spätere Etagen-Varianten (09 ST1-C2) | Wahl der Etagen-Definition |
| `motto` | String `mot_*`; der Kern prüft ihn nicht (Präsentation, aufgezeichnet für Bilanz und Replay) | keine |
| `bias` | 0–2 IDs aus `marotten.json`, je `min_floor` ≤ Etage, nicht `mar_unterhose` | +1 Ziehgewicht ab Etage 2 |
| `twist` | `""` oder eine ID aus dem Twist-Menü: `TwistApplier.IMPLEMENTED`, `slice`, Quelle `regie` erlaubt, nicht `tw_overtime` | Regie-Gewicht × 3 |
| `programme` | leer (= heutige Reihenfolge) oder `min(5, Pool)` verschiedene IDs aus `SeasonRules._programme_pool(floor)` | Reihenfolge der Tagesprogramm-Punkte |

Ob Motto, Vorlieben und Twist zusammenpassen, prüft der Drehbuch-Validator (V-6), nicht der Kern: Der Kern sichert nur,
dass jeder Plan **gültiges Spiel** ist — auch ein von Hand gebauter.

### 3.4 Sprecher und Platzhalter

`who` in `floors.<n>.lines[]`: `mod` (M.O.D.), `mopsula` (Graf Mopsula, eigene Stimme, Ich-Form), `producer`, `insider`,
`guest:<nm_id>` (nur auf den Etagen des Gasts), `rival` (Text enthält `{rival}`), `sponsor` (nennt den Hauptsponsor).
Alle Ensemble-Zeilen spricht **M.O.D.** (Stimme `mod`) und nennt die Figur im Satz („Bert Bolzenschneider flüstert: …“)
— so braucht der Dialog keinen neuen Sprecher.

| Platzhalter | Füllt (auf dem Gerät) | Höchstlänge | Erlaubt in |
|---|---|---|---|
| `{name}` | Name der Spielfigur bzw. „Kai“ (`Show._full_ctx`) | 12 | allen Zeilen außer Logline, Tagline, Titeln |
| `{cand}` | Wortform „Kandidatin / Kandidat / Kandidat:in“ (`PersonaText.ctx`) | 11 | allen Zeilen außer Titeln |
| `{rival}` | Rival:in aus der Persona (08 Kap. 4.4), sonst die des Kanon-Vorlebens | 24 | `who: rival`, `recap`, `cliff` |
| `{job}`, `{hobby}`, `{club}`, `{trait}` | Persona-Werte (08 Kap. 4.4) mit deren Rückfällen | 24, 24, 30, 16 | Zeilen ≤ 110; höchstens **einer** davon je Zeile; Grammatik nach 08 Kap. 4.4 |
| `{tip}` | wahrer Hinweis aus dem Zustand (Kap. 3.6, `DrehbuchText.tip`) | 70 | `safe`, `who: insider` |
| `{season}` | Nummer der Staffel | 3 | `vorspann`, `recap`, `end.*` |
| `{floor}` | aktuelle Etage | 2 | Zeilen ≤ 110 |

Nicht erlaubt: `{brand}` (die Persona-Marke aus 08 würde mit dem Hauptsponsor konkurrieren), `{job_text}` (Freitext, 08)
und alle übrigen Daten-Platzhalter. Personalisierung entsteht damit **nur auf dem Gerät**: Die KI schreibt „Sie sind
{job}? Dann kennen Sie das: Erst wird sortiert, dann diskutiert.“ — welches Vorleben das ist, erfährt sie nie (Kap. 6).

### 3.5 Längenregel und Zeichen

- **Längenregel** (08 Kap. 4.4, GDD §11.1): Rohtext + Σ (Höchstlänge − Länge des Platzhalters) ≤ Grenze des Felds. Für
  Zeilen ≤ 110 heißt das: Jede Zeile passt auch mit den längsten Werten in zwei HUD-Zeilen. Die Probe rendert zusätzlich
  mit den längsten echten Werten (`origins.json`, `names.json`, Tipp-Vorlagen).
- **Zeichen:** Unicode NFC; Buchstaben (mit Umlauten, ß und den Akzenten aus `names.json`), Leerzeichen und `. , ; : ! ?
  — – - ‚ ‘ „ “ ' ( ) … · & /`. Nicht erlaubt: **Ziffern**, Steuerzeichen, Emojis, `< > [ ] # @ _ \ |`, geschweifte
  Klammern außerhalb der Platzhalter, Adressen (`_re_url` aus `ModLineFilter`). Anführungszeichen deutsch („…“, ‚…‘).
- **Satzbau:** höchstens zwei Sätze je Zeile, kein Satz über 22 Wörter (Stilbuch; weich, V-15).

### 3.6 Menü und Listen

**Mottos** (`kit.json` → `mottos`; Startliste der Redaktion, IDs stabil nach DR-18):

| ID | Name | Bevorzugte Vorlieben (`bias`) | Erlaubte Twists | Stimmung |
|---|---|---|---|---|
| `mot_rabattschlacht` | Rabattschlacht | Second-Hand-Schick, Schleichwerbung | Doppel-Credits, Happy Hour | snarky |
| `mot_kochduell` | Kochduell | Schwachstellen-Gourmet, Bio-Siegel | Happy Hour, Partyhüte für Gegner | sweet |
| `mot_quizabend` | Quizabend | Der Graf hat das letzte Wort, Schwachstellen-Gourmet | Mopsula-Monolog, Stromausfall | neutral |
| `mot_heimwerker` | Heimwerker-Stunde | Nur der Mopp, Kein Schritt zurück | Ruhe im Studio, Happy Hour | neutral |
| `mot_talentabend` | Talentabend | Akrobatik-Abend, Stilnote | Konfetti-Gravitation, Partyhüte für Gegner | sweet |
| `mot_naturdoku` | Naturdoku | Friedliche Runde, Schleichwerbung | Ruhe im Studio, Stromausfall | neutral |
| `mot_krimidinner` | Krimidinner | Schleichwerbung, Kein Schritt zurück | Stromausfall, Ruhmesnebel, Rattenregen | snarky |
| `mot_wellness` | Wellness-Woche | Friedliche Runde, Bio-Siegel | Ruhmesnebel, Happy Hour | sweet |
| `mot_rekordjagd` | Rekordjagd | Schnellschnitt, Akrobatik-Abend | Partyhüte für Gegner, Doppel-Credits | snarky |
| `mot_gala` | Gala | Der Graf hat das letzte Wort, Stilnote | Mopsula moderiert, Konfetti-Gravitation | sweet |
| `mot_retro` | Retro-Abend | Second-Hand-Schick, Nur der Mopp | Mopsula-Monolog, Partyhüte für Gegner | neutral |
| `mot_inventur` | Inventur | Stilnote, Schnellschnitt | Doppel-Credits, Rattenregen | snarky |

**Prämissen** (`kit.json` → `premises`; je ein Satz, Zielscheibe Sender, Konzern, Bürokratie — 06 L-3, L-7):

| ID | Prämisse |
|---|---|
| `prm_ausverkauf` | NOVA versteigert die Sendung Folge für Folge an andere Firmen. |
| `prm_sparkurs` | NOVA spart an Licht, Kulisse und Gage — die Show soll aussehen wie immer. |
| `prm_jubilaeum` | Jubiläumsstaffel: NOVA feiert sich selbst, und alle müssen mitfeiern. |
| `prm_neustart` | Neues Logo, neue Senderfarbe, alte Probleme: NOVA erfindet die Show neu. |
| `prm_umzug` | Der Sender zieht um — mitten in der Staffel, Etage für Etage. |
| `prm_quotenpanik` | Die Quote sinkt; die Produktion probiert jede Woche ein neues Format. |
| `prm_konkurrenz` | Ein Konkurrenzsender kopiert die Show; NOVA kopiert zurück. |
| `prm_familienprogramm` | NOVA will ein Familienprogramm — im Dungeon. |
| `prm_pannen` | Technik, Requisite und Regie haben gleichzeitig Urlaub beantragt. |
| `prm_preisverleihung` | NOVA will einen Fernsehpreis und inszeniert jede Folge für die Jury. |
| `prm_tagung` | Der Konzern hält seine Jahrestagung im Studio ab; die Show läuft nebenher. |
| `prm_inventur` | Jede Kulisse wird gezählt, gestempelt und notfalls verschrottet. |

**Weitere Listen:**

- **Figuren** (`kit.json` → `figures`): `fig_*` → Boss-IDs und Kulisse; heute `fig_filialleiterin`, `fig_ausverkauf`,
  `fig_requisiteurin`, `fig_garderobe`, `fig_schichtleiterin` (`enm_boss_schichtleiterin_f4/f5/f6`), `fig_paketberg`;
  mit den Etagen 7–18 (09 ST1-C2) die Figuren aus 09 Kap. 3.1. Etage 1 hat keine Drehbuch-Figuren (DR-2).
- **Auszeichnungs-Menü** (`kit.json` → `awards`): nicht versteckte Erfolge, die nicht an Etage 1 gebunden sind — heute
  `ach_close_call`, `ach_overkill`, `ach_crit_3`, `ach_weakness_5`, `ach_combo_first`, `ach_preemptive_3`,
  `ach_ambush_won`, `ach_sponsor_first`, `ach_viewers_5000`, `ach_chests_10`, `ach_vendor_500`, `ach_lootbox_10`,
  `ach_events_all`, `ach_bets_5`, `ach_interrupt_10`, `ach_perfect_phase`. Erfolge gelten je Spielstand
  (`ShowState.achievements`), feuern also in jeder Staffel neu.
- **Tipps** (`kit.json` → `tips`): Vorlagen der Redaktion mit Bedingung auf dem Zustand (offener Programmpunkt, lebender
  Revier-Boss, unbesuchter Safe Room, Vorliebe der Etage, nahender Einsturz). `DrehbuchText.tip` nimmt die erste
  erfüllte Vorlage in fester Reihenfolge; ohne Treffer „Bleiben Sie neugierig.“ Damit ist jeder Hinweis wahr.
- **Namen** (`names.json`): ≥ 120 Einträge `{id: nm_*, name, form, roles}`, erfunden, alliterierend „Vorname Gegenstand“
  wie 08 Kap. 4.6, getrennt von den 384 Namen aus `cast.json` und den Rival:innen aus `origins.json` (Test);
  **[Register-Abgleich zu prüfen]**. Die Beispiele aus Kap. 2.2 sind heute in keiner Liste vergeben.
- **Marken** (`brands.json`): ≥ 30 erfundene Marken `{id: brd_*, name, sector}`, keine aus `real_brands`
  **[Markenrecherche zu prüfen]**; die mechanischen Sponsoren (`sponsors.json`) bleiben unberührt.

### 3.7 Prüfregeln

Maßgeblich ist `core/season/drehbuch_validator.gd` (`DrehbuchValidator.check(doc, ctx) -> Report`); der Dienst prüft mit
der Portierung `mod_brain/script_validator.py` vorab (DR-11). **Hart** = Feld oder Teil unbrauchbar (Reparatur Kap.
3.8), **weich** = gezählt und ins Lektorat, die Zeile bleibt.

| Nr. | Regel | Hart / weich | Quelle der Regel |
|---|---|---|---|
| V-1 | **Schema:** Typen, Pflichtfelder, keine unbekannten Schlüssel, Enums | hart (Teil) | Kap. 3.2 |
| V-2 | **Größe und Anzahl:** ≤ 64 KB, Ensemble 3–5, Auszeichnungen 6–10, Zeilen 4–10, Intros 1–2 | hart (Teil) | Kap. 3.2 |
| V-3 | **Zeichen:** NFC, erlaubte Zeichen, keine Ziffern, keine Adressen | hart (Feld) | Kap. 3.5 |
| V-4 | **Längen** mit Platzhalter-Höchstlängen und Probe mit echten Werten | hart (Feld) | Kap. 3.5 |
| V-5 | **Verweise:** jede ID existiert (`data/*.json` des `data_hash`, `data/drehbuch/*`), passt zur Etage (Bosse, Pool, Event-Typen, Figuren), zu Auftrag und Format; keine stillgelegte ID | hart (Teil) | Kap. 3.3, 3.6 |
| V-6 | **Plan-Regeln:** Kern-Regeln (Kap. 3.3) + `bias` = Vorlieben des Mottos, `twist` ∈ Twists des Mottos, kein Motto und kein Twist zweimal hintereinander, je Teil höchstens zweimal Doppel-Credits oder Happy Hour **[zu messen, Harness]** | hart (Teil) | Kap. 3.6, 5.3 |
| V-7 | **Platzhalter und Grammatik:** nur erlaubte Platzhalter am erlaubten Ort; ≤ 1 Persona-Platzhalter je Zeile; `{job}` nur prädikativ oder als Apposition, nie mit Artikel oder „von Beruf“; `{club}` nur als Subjekt; `{trait}` nur prädikativ; `{hobby}` ohne Artikel (08 Kap. 4.4, Regex-Prüfung) | hart (Feld) | 08 Kap. 4.4 |
| V-8 | **Sprachregel** 09 Kap. 1.2: kein „Level“, „Lv“, „Lvl“, „Ebene“ und kein anderes Wort der Verbotsliste von `test_09_terms` (dieselben Wortformen); „Kandidat:in/Kandidat:innen“ statt generischem „Kandidaten“; „Etage“, „Stufe“. Auf Englisch die Regeln aus 11 Kap. 2.1 (wie `test_11_terms_en`) | hart (Feld) | 09 Kap. 1.2, 11 Kap. 2.1 |
| V-9 | **IP-Wörter** aus `core/data/validators/ip_words.gd` (`general_word`): die Liste für den IP-Abstand und die Herkunftswörter, unverändert wie für alle Daten. In einem Build mit lizenziertem Paket sind nur die Begriffe aus dessen Glossar vom IP-Abstand ausgenommen, Herkunft und Ton nie (11 Kap. 3.12, Schicht 2) | hart (Feld) | 06 §0.3, 04 §2.3 |
| V-10 | **Filter** `ModLineFilter.check(text, lists, voice, persona_canon = false)` mit `data/mod_filter.json`: Politik, Sexuelles, Beleidigungen, Gewalt, echte Marken, IP-Abstand, Herkunft, Geld, Kaufdruck (Dringlichkeit + Kaufbezug), Sprachprüfung mit der erwarteten Sprache (11 Kap. 1.13, 11-L5). `tone_exceptions` eines Pakets gelten nie für Drehbuch-Texte | hart (Feld) | 06 §5.9 Nr. 3 |
| V-11 | **Graf Mopsula:** keine Königsmotive (`mopsula_word`) in Zeilen seiner Stimme oder über ihn; Zeilen mit `who: mopsula` in Ich-Form (ich/mich/mir/mein) | hart (Feld) | 06 §5.9, 00_BRIEF |
| V-12 | **Namen:** Personennamen nur aus dem eigenen Ensemble, `{rival}`, „M.O.D.“, „Graf Mopsula“, „Kai“; Marken nur der eigene Hauptsponsor und „NOVA“; zwei großgeschriebene Wörter, die wie ein Name aussehen und in keiner Liste stehen → weich | hart / weich | DR-9 |
| V-13 | **Keine Behauptungen:** Wörter für Regeln und Belohnungen („Schaden“, „Prozent“, „verdoppelt“, „Bonus“, „Belohnung“ …, Liste im Kit) und Aussagen über die Kandidat:in (Pronomen der dritten Person, Alter, Körper) | weich; Körper/Alter hart | DR-13, 06 L-3 |
| V-14 | **Wiederholung:** keine Zeile doppelt im Teil; Dreiwort-Folgen-Überlappung je Feld ≤ 40 % **[zu messen]**; Titel nicht gleich den letzten drei Staffeln des Geräts | weich; Doppelte hart | KR-2 |
| V-15 | **Lektorat:** Befunde des zweiten Durchgangs (`block` / `fix` / `note`, Kap. 4.7); Stilbuch-Regeln (Satzlänge) | `block` hart, sonst weich | DR-12 |
| V-16 | **Kuratiert:** im kuratierten Modus (Kap. 7) muss jeder Text einer freigegebenen Vorlage entsprechen (wörtlich oder mit erlaubten Lückenfüllern) | hart (Feld) | S-6 |
| V-17 | **Teilfolge:** Teil 2 und 3 nennen dieselbe Prämisse, denselben Hauptsponsor und dasselbe Ensemble wie Teil 1; Gäste nur mit neuen `floors` | hart (Teil) | DR-3 |

`DrehbuchValidator` nutzt dieselben Funktionen wie die Daten (`ip_words.gd`, `ModLineFilter`, die Wortformen aus
`test_09_terms`), damit ein KI-Text nie nach anderen Maßstäben geprüft wird als eine geschriebene Zeile. Der Bericht
trägt je Fund Regel, Feldpfad und Schwere; Zähler gehen ins technische Protokoll (Kap. 4.11), Texte nie.

### 3.8 Reparatur und Rückfall

```text
KI-Teil ─► R-1 Normalisieren (beide Seiten) ─► Prüfung im Dienst ─► Lektorat
            │                                      │ hart / block
            │                                      ▼
            │                       R-2 eine Reparaturrunde (nur betroffene Felder)
            ▼
Gerät: Prüfung (maßgeblich) ─► ok ─────────────────────────────────────────► aufzeichnen (Kap. 5.2)
            │ Feld hart
            ▼
       R-3 Flicken: Feld ← Baukasten-Text zum selben Plan ─► ≤ 20 % geflickt ─► aufzeichnen, meta.patched
            │ Teil hart (V-1, V-2, V-5, V-6, V-17) oder > 20 % geflickt
            ▼
       R-4 ganzer Teil aus dem Baukasten (Quelle offline) ─► aufzeichnen
            │ unmöglich (Test: nie)
            ▼
       R-5 kein Teil: Etagen spielen wie heute (Standard-Plan, Kanon-Texte)
```

| Stufe | Was | Wo | Spur |
|---|---|---|---|
| R-1 | NFC, typografische Anführungszeichen, `...` → `…`, Leerzeichen kürzen | Dienst und Gerät | keine |
| R-2 | **Eine** Modellrunde, nur die gemeldeten Felder mit den Befunden (`effort: low`) | Dienst | `meta.repaired` |
| R-3 | Feld durch Baukasten-Text desselben Slots ersetzen (deterministisch aus Seed und Plan) | Gerät | `meta.patched[]` |
| R-4 | Teil vollständig aus dem Baukasten, gleicher Seed | Gerät | `src: offline` |
| R-5 | kein Drehbuch-Teil; die Staffel verhält sich wie heute | Gerät | Protokoll |

Gemessen wird, wie oft jede Stufe greift (KS5-Gate: R-4 bei KI-Teilen ≤ 5 %, R-3 ≤ 3 % der Felder **[zu messen]**).

### 3.9 Beispiel (Ausschnitt, Teil 1 von „Der große Ausverkauf“)

```json
{
  "schema": 1, "id": "drb_3f9c2a71d0b44e18", "part": 1, "last": true, "src": "ai", "lang": "de",
  "data_hash": "…", "kit_v": 1, "format": 6, "premise": "prm_ausverkauf",
  "season": {
    "title": "Der große Ausverkauf",
    "logline": "NOVA hat die Sendung versteigert: Jede Folge gehört einer anderen Firma — und jede will …",
    "tagline": "Alles muss raus. Nur Sie bleiben drin.",
    "sponsor": {"brand": "brd_preisrutsch", "slogan": "Heute billiger als gestern."},
    "cast": [
      {"role": "producer", "name": "nm_petra_pausenzeichen", "bio": "Produktionsleiterin. Verkauft jede Minute …"},
      {"role": "insider", "name": "nm_bert_bolzenschneider", "bio": "Bühnentechniker. Kennt jede Falltür …"},
      {"role": "guest", "name": "nm_gerda_goldrand", "bio": "Auktionatorin. …", "floors": [3]}
    ],
    "awards": [{"ach": "ach_crit_3", "name": "Preissturz", "line": "Auszeichnung ‚Preissturz‘: …"}],
    "vorspann": "Die Generalprobe ist vorbei. Willkommen zu Staffel {season}: ‚Der große Ausverkauf‘ — alles muss raus!"
  },
  "figures": {"fig_filialleiterin": {"epithet": "die Unverkäufliche", "motive": "Will die Passage behalten …"}},
  "plan": {"2": {"def": "floor_2", "motto": "mot_rabattschlacht", "bias": ["mar_secondhand", "mar_sneaky"],
                 "twist": "tw_double_credits", "programme": ["daily_passage_midnight_sale", "…"]}},
  "floors": {"2": {
    "title": "Alles muss raus", "motto_name": "Rabattschlacht", "mood": "snarky", "note": "übermütig",
    "open": "Neue Folge: ‚Alles muss raus‘. Die Passage gehört heute Preisrutsch — jede Ecke trägt ein Preisschild.",
    "safe": "Bert Bolzenschneider flüstert: {tip}",
    "twist": "Doppel-Credits! Preisrutsch nennt es Rabatt. Die Buchhaltung nennt es ein Versehen.",
    "bosses": {"enm_boss_filialleiterin": {"intro": ["Die Filialleiterin ist unverkäuflich, sagt sie. …"],
                                           "won": "…"}},
    "showboss": {"name": "Die Kassenschlange", "line": "…"},
    "programme": [{"id": "daily_passage_midnight_sale", "name": "Die Nacht der roten Preisschilder", "line": "…"}],
    "events": {"photo_drone": "…", "broken_vending": "…"},
    "lines": [{"who": "mopsula", "text": "Fußnote neun: Ein Graf feilscht nicht. Ich nenne es Verhandlung — …"}],
    "recap": "Die Passage hat geschlossen. Preisrutsch zählt die Restposten, Petra Pausenzeichen zählt die Quote.",
    "cliff": "Nächste Folge: Gerda Goldrand versteigert den Fundus — Stück für Stück, Kulisse für Kulisse."
  }},
  "end": {"finale": {"finalist": "…", "end": "…", "fallen": "…", "buried": "…", "left": "…"}, "credits": "…"},
  "meta": {"model": "claude-opus-5-5", "created": "2026-10-20T19:02:11Z", "review": {"block": 0, "fix": 1, "note": 3},
           "repaired": true, "patched": [], "persona": false}
}
```

---

## 4. Erzeugung

### 4.1 Zeitpunkte

| Moment | Was passiert |
|---|---|
| „Neue Staffel“ (`season_setup.gd`, ST1-H) | Quelle steht fest: **Pilot** in der ersten Staffel des Geräts (Karriere-Zähler 0); sonst **KI**, wenn eingeschaltet (D1: Beta-Schalter, D2: Standard) und der Dienst gemeldet ist; sonst **Baukasten**. |
| Ende des Castings (Knopf „Sendung starten“ der Kandidatenkarte, 08), unmittelbar vor `Game.start_season` | Das Gerät wählt die Prämisse (Seed, meidet die letzten drei), vergibt die Drehbuch-ID, erzeugt **sofort alle Baukasten-Teile** (Rückfall liegt bereit) und gibt mit KI einen **Auftrag für alle Teile** des Formats ab. Es wartet nicht. |
| Generalprobe (Etage 1, Pflichtweg ≈ 20 min, 09 Kap. 3.3) | Der Dienst schreibt Teil 1 (≈ 3–5 min **[zu messen]**), danach Teil 2 und 3. Das Gerät fragt alle 20 s nach, prüft jeden fertigen Teil, flickt und **bindet ihn bei Eintreffen** (Kap. 5.2). |
| Frist Teil 1: bevor Etage 2 betreten werden kann | Liegt kein geprüfter KI-Teil vor, bindet das Gerät den Baukasten — für **alle** Teile der Staffel (das Ensemble muss zusammenpassen); ein später fertiger KI-Satz geht ins Archiv (DR-19). |
| Frist Teil 2 / 3: bevor Etage 7 / 13 betreten werden kann | In der Praxis längst gebunden; sonst Baukasten-Teil mit dem Rahmen aus Teil 1. |
| Staffelende (Staffel-Bilanz) | Mit KI: Angebot „Nächstes Drehbuch vorbereiten“ (Vorproduktion per Batch, Kap. 4.9). |

„Optional je Akt“ (S-3) ist vorbereitet: Teil 2 und 3 könnten erst beim Erreichen von Etage 6 bzw. 12 bestellt werden
und grobe Staffel-Fakten als IDs bekommen (Ergebnis-Bänder statt Zahlen). In D1/D2 bleibt es bei einem Auftrag zum Start
(F-9): einfacher, billiger, und kein Spielzustand verlässt das Gerät.

### 4.2 Ablauf im Dienst

```text
Client ── POST /v1/script/jobs (nur IDs) ──► Token prüfen (auth.py) ─► Ratenlimit (script_acc) ─► Not-Aus, Budget
                                                                             │
          ◄── 202 {job, eta_s} ─────────────────── Katalog für data_hash + kit_v vorhanden? (sonst 409)
                                                                             │
Worker: je Teil ─► Prompt (System aus dem Cache + Auftragsrahmen) ─► Modell (Streaming, JSON-Schema)
                    ─► refusal? max_tokens? ─► JSON lesen ─► R-1 ─► Prüfung (Python-Port) ─► Lektorat
                    ─► hart / block: eine Reparaturrunde ─► Prüfung ─► Teil ablegen (≤ 24 h) ─► nächster Teil
Client ── GET /v1/script/jobs/{job} ──► fertige Teile mit Bericht ─► Prüfung auf dem Gerät (maßgeblich) ─► binden
```

Die Teile laufen **nacheinander** im selben Auftrag: Teil 2 und 3 bekommen den Rahmen aus Teil 1 vom Dienst selbst
(nicht vom Client zurückgeschickt, 06 §5.9 Nr. 2) und lesen den System-Cache von Teil 1.

### 4.3 Schnittstelle

`POST /v1/script/jobs` — Antwort `202 {"job": "job_…", "eta_s": 240}`:

```json
{"v": 1, "job_ref": "rr_5c1e0a9b2d3f4e6a", "lang": "de", "data_hash": "…", "kit_v": 1, "format": 6,
 "parts": [1], "kind": "private", "route": "direct", "premise": "prm_ausverkauf",
 "avoid": {"premise": ["prm_sparkurs", "prm_umzug"], "names": ["nm_konrad_kassenbuch"], "brands": ["brd_funzelfix"],
           "mottos": []},
 "pack": "",
 "persona": null}
```

Mit Persönlicher Note (Kap. 6.3) steht statt `null`:
`{"consent": {"v": 1, "date": "2026-10-20"}, "org": "org_animals", "hob": "hob_…", "trt": "trt_…"}`.

`GET /v1/script/jobs/{job}`:

```json
{"job": "job_…", "status": "running",
 "parts": [{"part": 1, "status": "ok", "doc": {"…": "…"},
            "report": {"hard": 0, "soft": 2, "review": {"block": 0, "fix": 1, "note": 3},
                       "repaired": true, "ms": 214000}}]}
```

| Feld / Code | Regel |
|---|---|
| Authentifizierung | kurzlebiges Token wie „M.O.D. live“ (`auth.py`, `RemoteModVoice`), an `job_ref` gebunden; **kein API-Schlüssel im Client** (S-4) |
| Felder | nur Enums und IDs aus dem Katalog des `data_hash`; jeder andere String → `400`; unbekannte Felder → `400` |
| `kind` | `private` (Gerät) · `shared` (nur Staffel-Dienst, Server zu Server, Kap. 8) |
| `pack` | `""` im Grundspiel; sonst die Paket-ID (11 Kap. 3.3) — der öffentliche Dienst kennt keine Pakete und antwortet `409` (Kap. 7) |
| `route` | `direct` (Streaming, sofort) · `prebook` (Batch, Kap. 4.9) |
| Teil-Status | `ok` · `failed` (Fehler, Zeitlimit, ungültig nach Reparatur) · `refused` (Modell lehnt ab) · `over_budget` · `off` (Not-Aus) — alles außer `ok` heißt auf dem Gerät: Baukasten |
| `409` | `data_hash` oder `kit_v` unbekannt (Client älter oder neuer als der Dienst) |
| `413`, `429`, `503` | zu groß; Ratenlimit; Not-Aus oder Budget — der Client schreibt mit dem Baukasten, ohne Meldung |
| `DELETE /v1/script/jobs/{job}` | Abbruch (z. B. Widerruf der Persönlichen Note); Teile werden verworfen |
| `POST /v1/script/report` | `{id, part, path, reason}` mit `reason` ∈ `ton`, `falsch`, `wiederholung`, `unpassend`, `sonstiges` → `204`; nie Text |

### 4.4 Prompt-Aufbau

**System (statisch je `data_hash`, `kit_v` und Sprache; im Cache):**

1. **Rolle und harte Regeln:** „Sie schreiben das Staffel-Drehbuch einer fiktiven Dungeon-Spielshow …“ — Ausgabe nur
   nach Schema; nur IDs aus dem Menü; keine Ziffern, keine Regeln, keine Aussagen über die Kandidat:in; keine echten
   Personen, Marken, Politik oder Werke Dritter; M.O.D. siezt und nutzt keine Pronomen für die Kandidat:in; Graf Mopsula
   spricht in der Ich-Form, gelehrt, mit Fußnoten, ohne Königsmotive; Zielscheibe Sender, Konzern, Bürokratie (06 L-3,
   L-7); Sprachregel 09 Kap. 1.2; Platzhalter-Tabelle (Kap. 3.4) mit Grammatik aus 08 Kap. 4.4. Die Regeln stehen
   positiv formuliert und mit Begründung (Stilbuch), nicht als Liste von Verboten in Großbuchstaben.
2. **Weltbibel** (`bible.json`): NOVA SYNDIKAT, die Sendung, M.O.D. („Mediale Omnipräsente Direktorin“), Graf Mopsula,
   Kai und das Tierheim (00_BRIEF Kap. 1), die Kulissen mit Stimmung und Requisiten (09 Kap. 3.1), die Figuren mit Rolle
   und Verhalten — in eigenen Worten der Redaktion, ohne Bezug auf fremde Werke.
3. **Stilbuch:** Satzlänge, zwei Sätze je Zeile, Pointe am Ende; je Stimme fünf gute und drei schlechte Beispiele mit
   Begründung; Humor-Regeln H-1 … H-7 aus 08 und L-1 … L-7 aus 06.
4. **Menü:** Etagen des Formats mit Kulisse, Figuren und Bossen, Pools der Programmpunkte (ID + Datenname), Event-Typen
   (ein Satz Wirkung), Mottos, Twists (Name + ein Satz Wirkung, damit Texte stimmen), Auszeichnungs-Menü (Name +
   Beschreibung), Namen (ID, Name, Form, Rollen), Marken, Prämissen. Cache-Grenze (`cache_control`) am Ende dieses
   Blocks.

**Auftrag (variabel, klein):** Format, Teil, `last`, Prämisse (ID + Katalogsatz), Meide-Listen, Ziel-Stimmungsbogen der
Prämisse; für Teil 2 und 3 der Rahmen aus Teil 1; mit Persönlicher Note die **Katalognamen** der drei IDs
(„Vorleben-Gruppe: Tierpflege“) und die Anweisung, sie nur über Platzhalter zu nutzen (V-7, Kap. 6.3).

**Nie im Prompt:** Strings vom Client, Namen der Spieler:in, Seed, Geräte- oder Konto-Kennungen, Spielstand, frühere
Drehbücher des Geräts (nur deren IDs als Meide-Liste).

### 4.5 Ausgabeschema

- **Strukturierte Ausgabe** über `output_config.format` (`json_schema`); das Schema baut der Dienst je `data_hash`,
  `kit_v`, Sprache, Teil und `last` aus dem Katalog — mit `enum` für jede ID (Bosse, Pool, Event-Typen, Mottos, Twists,
  Namen, Marken, Auszeichnungen) und `additionalProperties: false` überall. Etagen und Bosse sind **feste
  Eigenschaften** des Teils, keine freien Schlüssel. Damit ist das Schema je Version konstant: einmal kompiliert, danach
  24 h im Schema-Cache.
- **Nicht im Schema** (von strukturierter Ausgabe nicht unterstützt: Stringlängen, Zahlenbereiche, Array-Grenzen) — das
  prüfen V-2 und V-4 selbst.
- Das Modell schreibt weder `id`, `src`, `meta` noch `data_hash`; der Dienst setzt sie. `bias` ergänzt der Dienst aus
  dem gewählten Motto (das Modell wählt Motto, Twist und Reihenfolge).

### 4.6 Modell und Parameter

| Parameter | Wert | Begründung |
|---|---|---|
| Modell | `claude-opus-5-5` (`MOD_BRAIN_MODEL_SCRIPT`, Standard = `MOD_BRAIN_MODEL`) | Standardmodell des Dienstes (`config.py`); Sonnet 5.5 oder Haiku 5.5 erst nach dem Vergleich in KS5 (F-5) |
| Denken | adaptiv | bei Opus 5.5 immer an; `disabled` oder ein Budget geben 400 |
| `effort` | `medium` für den Text, `low` für Lektorat und Reparatur (`MOD_BRAIN_EFFORT_SCRIPT`) | explizit gesetzt; höhere Stufe nur, wenn die Bewertung es zeigt |
| `max_tokens` | 32 000 | Teil 1 ≈ 12 k Ausgabe inkl. Denken **[zu messen]**, Puffer gegen Abbruch |
| Streaming | ja, `get_final_message()` | lange Ausgabe; schützt vor Verbindungsabbrüchen |
| Zeitlimit, Wiederholung | 300 s je Aufruf (`with_options(timeout=300, max_retries=1)`); Auftrag gesamt 15 min | danach Teil `failed` |
| Fallback | `fallbacks="default"` mit Beta `server-side-fallback-2026-07-01` wie `brain.py`; nicht bei Haiku 5.5, nicht im Batch | Ablehnungen der Klassifikatoren |
| `stop_reason` | **zuerst** prüfen: `refusal` → `refused`; `max_tokens` → `failed` | ein abgelehntes Ergebnis passt nicht zum Schema |
| Sampling | keine eigenen Werte | Standard des Modells |

Skizze (bei der Umsetzung gegen die SDK-Doku prüfen):

```python
# mod_brain/script_brain.py (Skizze)
FALLBACK_BETA = "server-side-fallback-2026-07-01"


def generate_part(self, job: PartJob) -> dict:
    c = self.client.with_options(timeout=300.0, max_retries=1)
    kwargs = dict(
        model=self.cfg.model_script,
        max_tokens=32000,
        system=self.prompt.system_blocks(job.catalog),   # Rolle, Weltbibel, Stilbuch, Menü; cache_control am Ende
        messages=[{"role": "user", "content": self.prompt.frame(job)}],
        thinking={"type": "adaptive"},
        output_config={"effort": self.cfg.effort_script,
                       "format": {"type": "json_schema", "schema": job.schema}},
    )
    if self.cfg.use_fallbacks(self.cfg.model_script):
        stream = c.beta.messages.stream(**kwargs, betas=[FALLBACK_BETA], fallbacks="default")
    else:
        stream = c.messages.stream(**kwargs)
    with stream as s:
        msg = s.get_final_message()
    if msg.stop_reason == "refusal":
        raise PartRefused(job.part)
    if msg.stop_reason == "max_tokens":
        raise PartTruncated(job.part)
    return json.loads(next(b.text for b in msg.content if b.type == "text"))
```

### 4.7 Lektorat und Reparaturrunde

- **Lektorat** (DR-12): gleiches Modell, `effort: low`, `messages.parse` mit einem festen Pydantic-Modell `Review`
  (`findings: [{path, rule, severity, reason}]`, `rule` ∈ `ton`, `stimmen`, `behauptung`, `stimmigkeit`, `sprache`,
  `sicherheit`, `ip`, `wiederholung`; `severity` ∈ `block`, `fix`, `note`). Eingabe: der Teil mit Platzhaltern, die
  Prüfliste und die Weltbibel (eigener Cache-Block).
- **Prüfliste:** (1) Zielscheibe Konzern, Show, Bürokratie — nie Spieler:innen, Zuschauer:innen, Körper, Herkunft oder
  echte Berufe als Pointe; (2) keine Aussage über die Kandidat:in, keine Regel, keine Zahl; (3) Stimmen: M.O.D. siezt,
  Mopsula Ich-Form und gelehrt, Ensemble über M.O.D.; (4) Stimmigkeit von Prämisse, Motto, Twist, Bogen und Teilen;
  (5) Sprachregel; (6) Sicherheit: Politik, Sexuelles, Gewalt über Comic-Niveau, Kaufaufrufe, echte Personen und Marken,
  Werke Dritter; (7) Floskeln und wiederholte Pointen.
- **Reparaturrunde** (R-2): nur bei harten Funden oder `block`/`fix`; ein Aufruf (`effort: low`) mit den betroffenen
  Feldern, den Befunden und einem **festen Patch-Schema** (`[{path, text}]`, Pfade gegen den Teil geprüft); danach
  Prüfung. Bleibt etwas hart, entscheidet das Gerät (R-3, R-4). Keine zweite Runde: Kosten und Zeit bleiben begrenzt.

### 4.8 Kosten je Staffel **[Schätzung]**

Annahmen je Teil: System ≈ 14 k Tokens aus dem Cache; Auftrag 1 k (Teil 1) bzw. 3,5 k (Teile 2/3 mit Rahmen); Ausgabe
inkl. Denken bei `medium` 12 k bzw. 9 k; Lektorat 10 k bzw. 7 k Eingabe und 0,8 k Ausgabe; Reparatur bei 30 % der Teile
mit 2 k bzw. 1,5 k Ein- und Ausgabe. Preise laut Skill-Referenz vom 2026-10-13 (vor einer Budgetentscheidung prüfen):
Opus 5.5 $4 / $20 je 1 M Tokens, Cache-Lesen $0.20, Cache-Schreiben (5 min) $5; Sonnet 5.5 $2 / $10, Lesen $0.20,
Schreiben $2.50; Haiku 5.5 $0.10 / $0.50; Batch −50 %. Die Spanne je Zelle = Cache gelesen bis Cache neu geschrieben.

| Format | Teile | Opus 5.5 direkt | Opus 5.5 Batch (Vorproduktion) | Sonnet 5.5 direkt | Haiku 5.5 direkt |
|---|---|---|---|---|---|
| Basis (6 Etagen) | 1 | **≈ $0.32–0.38** | ≈ $0.16–0.19 | ≈ $0.16–0.19 | ≈ $0.01 |
| Akt 2 (12 Etagen) | 2 | **≈ $0.57–0.64** | ≈ $0.29–0.32 | ≈ $0.29–0.32 | ≈ $0.015 |
| Akt 3 (18 Etagen) | 3 | **≈ $0.82–0.89** | ≈ $0.41–0.45 | ≈ $0.41–0.45 | ≈ $0.02 |
| je weitere Sprache (geteilt, Akt 3) | — | ≈ $0.49 | ≈ $0.25 | ≈ $0.24 | — |

**Einordnung:** Ein Akt-3-Drehbuch kostet mit Opus so viel wie ≈ 50 Minuten „M.O.D. live“ (06 §5.11: ≈ $1 je Stunde) und
gilt für 84 Kalendertage. Vier Akt-3-Staffeln im Jahr (Kalender) ≈ $3.50 je Spieler:in direkt, ≈ $1.75 mit
Vorproduktion; wer „Am Stück“ viele Staffeln spielt, stößt an den Deckel — bei einem Premium-Spiel (04) vertretbar, aber
nicht vernachlässigbar. Deshalb: Vorproduktion, wo möglich; Modellwahl nach dem KS5-Vergleich (F-5); Deckel nach DR-23
(pro Konto und Monat höchstens ≈ $9 bei zehn Akt-3-Aufträgen mit Opus). Eine geteilte Staffel kostet einmal
≈ $1.30–1.40 für alle (Akt 3, zwei Sprachen) — pro Kopf praktisch nichts.

**Latenz [zu messen]:** Teil 1 ≈ 3–5 min (Text 2–4 min, Lektorat und Reparatur ≈ 1 min); Frist ≥ 20 min (Generalprobe).
KS5-Gate: p95 ≤ 8 min, Anteil verpasster Fristen ≤ 2 %.

### 4.9 Caching, Vorproduktion, Archiv

- **Prompt-Cache:** Der System-Teil (≈ 14 k Tokens, Mindestgröße 512 weit überschritten) ist je `data_hash`, `kit_v` und
  Sprache gleich; Cache-Grenze am Ende des Menüs, 5-Minuten-Lebensdauer. Teil 2 und 3 lesen den Cache von Teil 1;
  bei Last lesen auch fremde Aufträge. Gemessen über `usage` (`cache_read_input_tokens`) im Kostenprotokoll.
- **Schema-Cache:** ein Schema je Version, Teil und `last` — kompiliert einmal, 24 h gültig.
- **Vorproduktion** (DR-19): Nach einer Staffel mit KI bietet die Staffel-Bilanz „Nächstes Drehbuch vorbereiten“ an
  (Standard an, F-16). Der Auftrag läuft mit `route: prebook` über die **Batch-API** (`custom_id` = Auftrag + Teil;
  strukturierte Ausgabe geht im Batch, `fallbacks` nicht — eine Ablehnung heißt dort Baukasten), Ergebnis meist < 1 h,
  spätestens 24 h. Das Gerät holt es beim nächsten Start ab und legt es ins Archiv. Passt bei „Neue Staffel“ Format oder
  `data_hash` nicht, wird es verworfen.
- **Archiv:** höchstens ein Satz auf dem Gerät (`<Save._data_root()>/drehbuch/archive.json`); ein zu spät fertiges
  KI-Drehbuch oder eine Vorproduktion wird bei der nächsten passenden Staffel benutzt, bevor ein neuer Auftrag entsteht.

### 4.10 Moderation, Not-Aus, Budget, Ratenlimit

- **Not-Aus:** `MOD_BRAIN_KILL_SWITCH` (alle KI) und neu `MOD_BRAIN_SCRIPT_OFF` (nur Drehbuch) → `503`, Baukasten.
- **Budget:** `MOD_BRAIN_SCRIPT_BUDGET_USD` (Monat) neben dem bestehenden `MOD_BRAIN_MONTHLY_BUDGET_USD`; Deckel je
  Auftrag `MOD_BRAIN_SCRIPT_JOB_USD` (Start $1.50 **[Schätzung]**) — wird er erreicht, bleiben die übrigen Teile
  `over_budget`.
- **Ratenlimit:** je `script_acc` (HMAC der Konto- bzw. Gerätekennung mit einem Dienst-Geheimnis, wie `cast_acc` in 08)
  3 Aufträge am Tag, 10 im Monat (DR-23); eigener Speicher, nie mit Inhalten verknüpft.
- **Meldungen:** `POST /v1/script/report` zählt je Drehbuch-ID und Feldpfad; die Redaktion sieht wöchentlich die Zähler
  und die Inhalte aus dem Inhaltsprotokoll (nur Aufträge ohne Persönliche Note) und pflegt daraus Negativbeispiele für
  Stilbuch und Lektorat. Ein Rückruf ausgelieferter Zeilen ist in D1/D2 nicht vorgesehen (F-12).
- **Stichproben:** In D1 und D2 prüft die Humor-Redaktion wöchentlich 20 zufällige Drehbücher (wie 06 §5.9 Nr. 5).

### 4.11 Protokolle

| Protokoll | Inhalt | Dauer | Nie darin |
|---|---|---|---|
| Technisch | Auftrag, Teile, Route, Modell, Tokens (Eingabe, Ausgabe, Cache), Kosten, Dauer, Zähler je Prüfregel und Lektorats-Schwere, Reparatur, Ergebnis-Code, `data_hash`, `kit_v`, Flag `persona` | 30 Tage | Texte, Persona-IDs, `script_acc`, IP-Adressen |
| Inhalte | ausgelieferte Teile (mit Platzhaltern) für Qualität und Meldungen | 30 Tage, **nur ohne Persönliche Note** | Persona-IDs, Konto-Bezug |
| Kosten | je Auftrag Kosten und Tokens, Monatssummen (`MOD_BRAIN_COST_LOG`) | 13 Monate | Inhalte |
| Auftragsspeicher | Teile bis zur Abholung | ≤ 24 h | — |

Aufbewahrung beim Modellanbieter nach Organisationseinstellung; Zero Data Retention anstreben **[zu prüfen]**.

### 4.12 Baukasten (Offline-Generator)

`core/season/drehbuch_kit.gd` (`DrehbuchKit`), rein und deterministisch aus `SeedUtil.derive(season_seed, "drehbuch",
part)`; Ganzzahl-Zufall wie im Kern, keine Uhr.

| Funktion | Zweck |
|---|---|
| `DrehbuchKit.part(seed, part, ctx, frame)` | ganzer Teil nach Schema; `frame` = Rahmen aus Teil 1 (für Teil 2/3) oder leer |
| `DrehbuchKit.texts_for(plan, seed, ctx, frame)` | **Ersatztexte** zu einem vorhandenen Plan (Kap. 5.8) |
| `DrehbuchKit.patch(doc, path, seed)` | **Flicken** eines Felds (R-3) |

Ablauf: Prämisse (vom Gerät) → Titel aus 3–5 Vorlagen der Prämisse → Hauptsponsor und Ensemble aus den Listen (meidet
die letzten drei Staffeln, wählt Namen nach Rolle) → je Etage Motto (kein Motto zweimal hintereinander, Stimmungsbogen
der Prämisse) → Twist aus den Twists des Mottos (Regel V-6) → `bias` des Mottos → Programm wie heute gemischt, aber
eindeutig über die Kulisse → Texte aus **Bausteinen**: Satzrahmen mit Generator-Lücken (`<titel>`, `<motto>`,
`<sponsor>`, `<produktion>`, `<insider>`, `<gast>`, `<figur>`, `<beiname>`, `<kulisse>`), die der Baukasten füllt;
Laufzeit-Platzhalter (`{name}`, `{tip}` …) bleiben stehen. Bausteine liegen in `kit.json → blocks`: je Motto
Folgenstart, Safe Room, Twist, Rückblick, Ausblick (je 3–5 Varianten), je Figur Beinamen (6), Motive (3), Intros (4),
Siegeszeilen (3), je Prämisse Titel, Logline, Tagline, Finale je Ergebnis (2), Abspann (3), je Event-Typ (4), je Twist
(3), je Programmpunkt zwei Namen, je Auszeichnung drei Namen. Umfang für Etagen 2–6 ≈ 1 500–2 000 kurze Texte
**[Schätzung]**.

Jede Baukasten-Ausgabe besteht den Validator (Test: 10 000 Seeds × Formate × Teile, null harte Funde) — der Baukasten
ist damit auch das Sicherheitsnetz für Flicken und Ersatztexte.

### 4.13 Pilot

`data/drehbuch/pilot.json`: ein Drehbuch der Redaktion für alle Teile (Teil 2 und 3, sobald die Etagen 7–18 Daten
haben), Quelle `pilot`, mit dem gleichen Validator und der Persona-Prüfmatrix aus 08 (`tests/tools/persona_matrix.gd`)
abgenommen. Es läuft in der **ersten Staffel jedes Geräts** (DR-1) und in Captures und Store-Material. Es darf länger
und feiner sein als ein KI-Drehbuch, hält aber dieselben Grenzen.

---

## 5. Einbau ins Spiel

### 5.1 Module und Schichten

| Datei (neu) | Schicht | Aufgabe |
|---|---|---|
| `core/season/drehbuch_rules.gd` (`DrehbuchRules`) | Kern, Simulation | `refusal`, `apply`, Plan-Zugriffe (`programme_of`, `twist_factor_pm`, `weight_add`, `floor_def_id`) — **die einzige Drehbuch-Datei, die `RunSim` und `GameReplay` ausführen** |
| `core/season/drehbuch.gd` (`Drehbuch`) | Kern, rein | Dokument lesen, normalisieren (R-1), hashen (`CanonicalJson.sha256_hex`), Zugriffe |
| `core/season/drehbuch_menu.gd` (`DrehbuchMenu`) | Kern, rein | Menü einer Staffel aus `GameData` + Kit; Export für den Dienst |
| `core/season/drehbuch_validator.gd` (`DrehbuchValidator`) | Kern, rein | V-1 … V-17 |
| `core/season/drehbuch_kit.gd` (`DrehbuchKit`) | Kern, rein | Baukasten, Flicken, Ersatztexte |
| `core/season/drehbuch_text.gd` (`DrehbuchText`) | Kern, rein (Präsentation) | Zeile je Haken, `{tip}`, Erzählbudget, Ersatz für ausgeblendete Zeilen |
| `autoload/drehbuch/drehbuch_link.gd` (`DrehbuchLink`) | Spiel (Node unter `Game`, kein neues Autoload) | Quelle wählen, Auftrag, Nachfragen, Prüfen, Flicken, Datei schreiben, Binden, Fristen |
| `autoload/drehbuch/remote_drehbuch.gd` (`RemoteDrehbuch`) | Netz | HTTP mit Token wie `RemoteModVoice`; ohne URL „nicht verfügbar“, kein Netz in Tests |
| `autoload/show_drehbuch.gd` (`ShowDrehbuch`) | Präsentation | Haken in `Show`, Zeilenquelle `drehbuch` am `ModAnnouncer`, KI-Zeichen |
| `scenes/ui/season_opening.*`, `scenes/ui/drehbuch_consent.*` | UI | Vorspann-Karte; Einwilligung Persönliche Note |

Alle `core/season/drehbuch*.gd` sind rein (keine Autoloads, kein `SceneTree`, keine Uhr) und fallen unter den RNG-Lint
des Kerns.

### 5.2 Aufzeichnung: der Befehl `script`

```json
{"t": "script", "v": 1, "part": 1, "id": "drb_3f9c2a71d0b44e18", "src": "ai",
 "hash": "<SHA-256 des Drehbuch-Satzes>", "plan": {"2": {"…": "…"}, "3": {"…": "…"}}}
```

Der **Drehbuch-Satz** eines Teils ist `{"plan": …, "docs": {"<lang>": <Teil-Dokument>, …}}` in kanonischem JSON
(`CanonicalJson.sha256_hex`): privat mit einer Sprache, in geteilten Staffeln mit allen. Der Befehl trägt **keine
Sprache** — so zeichnen eine deutsche und eine englische Spielerin derselben geteilten Staffel denselben Befehl auf, und
ein Sprachwechsel ändert nie, was im Spielstand steht (11 O-5, §1.10).

- **Eigener Typ, externe Eingabe:** `Command.TYPES` und `Command.EXTERNAL` bekommen `script` (Befehls-ID 0 wie `clock`,
  05 §10.6) — kein `season`-Op, weil `Command.EXTERNAL` nach Typ unterscheidet. Form-Prüfung `Command._script`;
  Regeln über `RunRules.season_refusal` → `DrehbuchRules.refusal`, Wirkung über `RunRules.apply_season` →
  `DrehbuchRules.apply` — dieselbe Regel für Live-Spiel, `RunSim.replay` und `Game.replay_log` (05 §11.4).
- **Ablehnungen:** `no_season` (wie heute), `script_part` (Teil passt nicht zum Format), `script_bound` (schon
  gebunden), `script_order` (Teil 2/3 ohne gebundenen Teil 1), `script_late` (eine Etage des Teils wurde schon betreten:
  `SeasonState.reached[f − 1] ≥ 0`), `script_plan` (Kap. 3.3), `script_hash` (kein 64-stelliges Hex).
- **Zustand:** `SeasonState.script = {"v": 1, "id", "parts": {"1": {"src", "hash", "plan"}}}` — **additiv** wie
  `sleeper`: geschrieben nur, wenn nicht leer; damit behalten Staffeln ohne Drehbuch JSON und Hash. Der Block ist
  gehasht (nicht in `UNHASHED_KEYS` / `StateHash.EXCLUDED_SEASON_KEYS`).
- **Reihenfolge beim Binden:** Textdatei atomar schreiben → Befehl aufzeichnen (`Game.record`, Journal
  `user://saves/slot_N.journal`) → Spielstand. Gebunden wird an der nächsten Tick-Grenze **außerhalb eines Kampfes** und
  nie im Replay (`Game.in_battle`, `Game.replaying`).
- **Bei Eintreffen binden, Fristen erzwingen:** `DrehbuchLink.bind_due(cmd)` läuft vor jedem Befehl, nach dem die
  Kandidat:in erstmals auf einer Etage eines ungebundenen Teils stehen könnte — `descend` auf diese Etage; `clock` und
  `away`, deren Zeitspanne den Einsturz der Etage davor erreicht (Rettung auf die nächste Etage, `SeasonRules._rescue`);
  das Ende des Am-Stück-Countdowns; Debug-Sprünge. Dann bindet sie den geprüften KI-Teil oder den Baukasten. Übersieht
  der Client einen Fall, fängt `script_late` ihn ab: Der Teil läuft ohne Drehbuch (R-5), nie falsch.
- **Spielstände und Laden:** Save v2 additiv; die Textdatei liegt neben dem Slot. Beim Laden bildet `Drehbuch` je Teil
  den Satz-Hash aus dem Plan im Zustand und den Texten der Datei und vergleicht ihn mit dem aufgezeichneten; fehlt die
  Datei oder passt der Hash nicht, zeigt das Spiel **Ersatztexte** zum gespeicherten Plan (Kap. 5.8). Der Plan selbst
  geht nie verloren: Er steht im Spielstand und im Journal.

### 5.3 Was der Plan im Kern ändert

| Stelle heute | Mit Drehbuch | Ohne Drehbuch |
|---|---|---|
| `SeasonRules.daily_id` (`core/season/season_rules.gd`): n-ter Punkt aus dem Pool der Kulisse in der Reihenfolge von `SeedUtil.derive(state.seed, "daily", floor)`; `_sync_daily` hängt ihn an `FloorRun.daily` (gehasht) und öffnet über `ZoneGenerator.open_programme_doors` Tür n | zuerst `DrehbuchRules.programme_of(state, floor)`: der n-te Eintrag des Plans | unverändert |
| `RegieDirector.decide` (`core/live/regie_director.gd`): erlaubte Twists, gezogen nach `maxi(1, def.weight)` | Gewicht × `DrehbuchRules.twist_factor_pm(state, floor, id)` / 1000 (3000 für den Twist der Folge, sonst 1000; Ganzzahl) | unverändert |
| `MarottenRules._draw_weight` (`core/show/marotten_rules.gd`): `maxi(1, def.weight) + PersonaRules.weight_add(…)` | `+ DrehbuchRules.weight_add(state, def.id, floor_index)` — +1 ab Etage 2 für die `bias` des Plans (wie `PersonaRules.BIAS_WEIGHT_ADD`) | unverändert |
| Etagen-Definition (`GameData.floor_def(index)`) | `DrehbuchRules.floor_def_id` — heute immer `floor_<n>`; Haken für spätere Etagen-Varianten (09 ST1-C2) | unverändert |

- Die **Regie** entscheidet nur live (`Game._regie_tick`, Einstellung „Regie-Eingriffe“, nicht mit „M.O.D. live“); ihre
  Wahl wird als `twist` aufgezeichnet (`Game.apply_twist`). Die Verifier spielen den aufgezeichneten Twist nach — das
  Gewicht ändert dort nichts, der Plan im Zustand hält die Live-Entscheidung trotzdem reproduzierbar. Ist die Regie aus,
  kommt der Twist der Folge nie, und das Drehbuch sagt nichts über ihn (DR-6).
- Die **Vorlieben** ziehen im Kern (sie entscheiden über Herzen und Show-Wetten) — deshalb steht `bias` im
  aufgezeichneten Plan, nicht nur das Motto.
- Der **Inhalt** der Programmpunkte (`fev_f<N>_p<n>`, `ZoneGenerator`) bleibt, wie er ist; nur welcher Punkt zuerst
  kommt und wie er heißt, ändert sich.
- **Balance:** Der Staffel-Harness (09 ST1-I) vergleicht Staffeln mit und ohne Drehbuch (Kap. 9.6); die Grenzen aus V-6
  sind Startwerte.

### 5.4 Zeilen: Namensraum `drb_`, Haken und Erzählbudget

- **Tag-Namensraum `drb_`** (registriert wie `cast_`, 02_TECH §0.8): `drb_vorspann`, `drb_floor:<n>`, `drb_safe:<n>`,
  `drb_twist:<n>`, `drb_programme:<daily_id>`, `drb_boss_won:<enemy>`, `drb_showboss:<n>`, `drb_event:<type>`,
  `drb_line:<n>`. Alle stehen in `ModAnnouncer.ALWAYS_SAID_PREFIXES` (eingereiht statt verdrängt) und
  `NO_COOLDOWN_PREFIXES` — wie `persona_` (08 K0).
- **Zeilenquellen:** `ModAnnouncer` bekommt benannte Quellen: `set_line_source(name, provider, mode)` mit `MIX` (das
  heutige Verhalten von `set_extra_lines`: Zeilen mit `EXTRA_WEIGHT` 2 neben den Daten-Zeilen) und `PREFER` (hat die
  Quelle passende Zeilen für den Tag, zählen nur diese). `set_extra_lines(p)` bleibt als `set_line_source("persona", p,
  MIX)` für 08 K3. Die Quelle `drehbuch` (`ShowDrehbuch.lines_for(tag)`) baut `ModLineDef`s mit IDs `drb:<pfad>` aus der
  Textdatei; „nie dieselbe Zeile zweimal hintereinander“ gilt unverändert.

| Moment | Tag heute | Drehbuch | Modus |
|---|---|---|---|
| Erstes Betreten von Etage 2 | `floor_start` | Vorspann-Karte, danach `drb_vorspann` | ersetzt |
| Erstes Betreten einer Etage ≥ 3 | `floor_start` | `drb_floor:<n>` (Folgentitel als Bauchbinde) | ersetzt |
| Erster Safe Room der Etage | `safe_room_enter` | `drb_safe:<n>` (oft Insider:in mit `{tip}`) | danach, eingereiht |
| Twist der Folge tritt ein | `twist_applied_<tw>` | `drb_twist:<n>` | ersetzt |
| Programmpunkt öffnet | `season_daily` | `drb_programme:<daily_id>` | ersetzt |
| Event | `event_<type>_<ausgang>` | `drb_event:<type>` | gemischt (`MIX`) |
| Boss-Intro (vor dem Kampf, 07 §2.9) | `boss_intro:<enemy>` | Intro aus `bosses.<enemy>.intro` | bevorzugt (`PREFER`) |
| Boss besiegt, zurück in der Erkundung | (`boss_defeated` im Ergebnis) | `drb_boss_won:<enemy>` | danach, eingereiht |
| Show-Boss gesichtet | `showboss_spotted` | `drb_showboss:<n>` mit dem Gruppennamen | ersetzt |
| Erfolg | `achievement:<ach>` | Zeile der Auszeichnung | bevorzugt (`PREFER`) |
| ruhige Momente der Erkundung | — | `drb_line:<n>` (Zwischenrufe aus `lines`) | eigener Takt |

- **Erzählbudget** (DR-14, `DrehbuchText.allow`): je Haken-Ereignis höchstens **eine** Drehbuch-Zeile. Plant der
  Sendeplan aus 08 am selben Haken einen Persona-Beat, kommt der Beat zuerst; die Drehbuch-Zeile rückt zum nächsten
  freien Haken der Etage oder entfällt. Zwischenrufe nur in der Erkundung, nach 90 s ohne M.O.D.-Zeile, höchstens einer
  je 3 min Spielzeit **[zu messen]**.
- **Kampf:** `ShowDrehbuch` liefert nichts, solange `Game.in_battle` gilt — einzige Ausnahme `boss_intro:*`, das vor dem
  Kampf läuft, während die Simulation steht (07 §2.9); `boss_phase` und alle Kampfzeilen bleiben geschrieben (CR-42).
- **Füllen:** wie Persona-Zeilen über `Show._full_ctx` und `UiUtil.format_line` (`PersonaText.ctx`, 08 Kap. 4.4); im
  Replay sagt `Show` wie heute nichts.
- **KI-Zeichen:** `mod_dialog.gd` zeigt „KI“ neben dem Sprecher, wenn die Zeile aus einem Drehbuch der Quelle `ai`,
  `curated` oder `shared` stammt und die Option an ist (Kap. 2.4).

### 5.5 Bosse, Show-Bosse, Events, Programmpunkte, Auszeichnungen

- **Banner:** `scenes/exploration/exploration.gd` baut heute `boss_name` aus `DB.enemy(boss_id).name` und gibt ihn an
  `CombatDirector.run_boss_intro`; mit Drehbuch steht dort „Rollenname — Beiname“, wenn beides ≤ 48 Zeichen hat
  **[zu messen in Captures]**, sonst nur der Rollenname. `combat_director.gd` bleibt unverändert.
- **Intro:** `boss_intro:<enemy>` bevorzugt die Drehbuch-Zeile (eine von 1–2), blockierend wie heute
  (`SUBTITLE_BLOCKING_TAGS`).
- **Figuren über mehrere Etagen:** Die Schichtleiterin trägt auf Etage 4–6 denselben Beinamen; Intros und Siegeszeilen
  sind je Etage eigene Texte („… ist zurück. Mit Hubwagen.“ bleibt als Daten-Zeile im Pool).
- **Show-Boss:** Name der Gruppe in `drb_showboss:<n>`; Regel-Banner `showboss_rule` bleibt geschrieben.
- **Events:** Drehbuch-Varianten mischen sich in `event_<type>_*` ein; Wirkung und Ausgang unverändert.
- **Programmpunkte:** Reiter und Karte zeigen den Sendungsnamen aus dem Drehbuch, den Datennamen (`themes.json`) als
  Tooltip; die Ansage ersetzt `season_daily`.
- **Auszeichnungen:** Der Erfolgs-Toast bleibt mit Name und Beschreibung aus `achievements.json` (06 §5.2); M.O.D. sagt
  die Drehbuch-Zeile; die Staffel-Bilanz listet gewonnene Auszeichnungen unter ihrem Staffelnamen mit dem Erfolg in
  Klammern.

### 5.6 Bildschirme und Bilanzen

- **Vorspann-Karte:** ausgelöst vom ersten `floor_start` auf Etage 2 (`SeasonState.reached[1]` frisch gesetzt), sobald
  die Erkundung steht; überspringbar; ohne gebundenes Drehbuch keine Karte.
- **Reiter „Staffel“:** Kopfzeile „Staffel 4 · Der große Ausverkauf“; Segment „Drehbuch“ (Kap. 2.3) im Bestand von
  ST1-H.
- **Etagen-Bilanz** (`FloorSummary`): Block „Folge“ mit Titel, Rückblick und dem Titel der nächsten Folge samt Ausblick.
- **Login-Bilanz:** Rückblicke der Folgen, die während des Schlafs endeten (höchstens zwei).
- **Staffel-Bilanz** (`season_summary.gd`): Finale-Text nach `SeasonState.result`, Abspann mit Quelle, Auszeichnungen.
- **Ruhmeshalle:** `SeasonView.hall_entry` bekommt `drb_title` und `drb_src` (Strings, keine Namen, keine Persona — 08
  P-1); ältere Einträge ohne diese Felder zeigen „Staffel N“ wie heute.

### 5.7 Replays und beide Verifier

- Laufprotokolle und Journal enthalten die `script`-Befehle mit Plan und Hash. `RunSim.replay` und `Game.replay_log`
  wenden denselben Plan über `RunRules.apply_season` an und kommen zum selben `StateHash` — **den Text brauchen sie
  nie**.
- Sichtbare Replays zeigen die Texte, wenn die Textdatei mit passendem Hash vorliegt, sonst Ersatztexte
  (gekennzeichnet).
- Der Server-Verifier (05 §11.4) prüft den Plan mit `DrehbuchRules.refusal` wie jeden Befehl; in geteilten Staffeln
  müssen Plan und Satz-Hash den signierten Werten der Staffel gleichen (Kap. 8.1).
- `test_11_lang_determinism` (11 §1.10) bekommt einen `script`-Befehl in seine Befehlsfolge: Deutsch und Englisch
  ergeben denselben `StateHash` (Kap. 9.5).
- `data_hash` und `sim_version` sind je Staffel gepinnt (09 V-1); V-5 verlangt den `data_hash` der Staffel. `kit_v`
  ändert die Simulation nie.
- **Ohne Drehbuch ist alles bit-gleich** zu heute (Gate Kap. 9.6).

### 5.8 Fehlerfälle

| Fall | Verhalten |
|---|---|
| Kein Netz beim Start | Baukasten liegt sofort bereit; der Auftrag wird nachgeholt, sobald das Gerät online ist und Teil 1 noch nicht gebunden ist |
| `409`, `429`, `503`, Teil `failed` / `refused` / `over_budget` / `off` | Baukasten, Quelle „Baukasten“, kein Fehlerdialog |
| Teil 1 nicht bis zur Frist geprüft | Baukasten für alle Teile; KI-Satz ins Archiv |
| Teil 2 / 3 nicht bis zur Frist | Baukasten-Teil mit dem Rahmen aus Teil 1 |
| Prüfung auf dem Gerät hart | R-3 / R-4 (Kap. 3.8) |
| Textdatei fehlt, defekt oder Hash falsch | Ersatztexte zum gespeicherten Plan; Plan bleibt |
| Sprachwechsel zwischen zwei Sitzungen (11 SP-5: nur im Titelmenü) | Ersatztexte des Baukastens über `Tx` in der neuen Sprache zum selben Plan; zurück → wieder das Drehbuch |
| Persönliche Note während eines Auftrags widerrufen | `DELETE` des Auftrags; neuer Auftrag ohne Persona, wenn die Frist reicht, sonst Baukasten |
| Spielstand von einem anderen Gerät ohne Textdatei | Ersatztexte; Plan und Hash gelten weiter |
| Zeile ausgeblendet | Ersatztext aus dem Baukasten für dieses Feld (nur lokal) |
| Bindung würde in einen Kampf fallen | wartet bis zur nächsten Tick-Grenze danach; Fristen werden vor dem auslösenden Befehl erzwungen |

### 5.9 Leistung

Kein Netz zur Laufzeit; Textdatei ≤ 3 × 64 KB, geladen beim Laden des Slots (< 5 ms **[zu messen]**); `ShowDrehbuch`
baut `ModLineDef`s je Tag beim ersten Bedarf und hält sie. Der Baukasten läuft einmal je Staffel und Teil (< 50 ms **[zu
messen]**, auch auf dem schwächsten Ziel-Telefon, 02_TECH §12.1).

---

## 6. Datenschutz

### 6.1 Grundsatz in drei Sätzen

1. **Standardmäßig verlässt keine persönliche Angabe das Gerät:** Der Dienst bekommt nur Staffel-Parameter und IDs aus
   dem Katalog, und das Gerät setzt `{name}`, `{rival}`, `{job}` und die übrigen Platzhalter erst bei der Anzeige aus
   der lokalen Persona-Datei ein.
2. Die **Persönliche Note** ist eine eigene Einwilligung ab 16 (Standard aus), mit der höchstens drei grobe IDs —
   Vorleben-Gruppe, Hobby, eine Eigenschaft — für einen einzigen Auftrag gesendet werden; nie Beruf, Name, Wortform,
   Freitext, Aussehen, Foto oder Geburtsjahr, und der Dienst behält sie nicht über den Auftrag hinaus und protokolliert
   solche Aufträge ohne Inhalt.
3. **Geteilte Staffeln nutzen nie Persona-Daten, gefüllte Texte verlassen nie das Gerät**, und der Kanarienvogel-Test
   aus 08 prüft das für Anfragen, Dateien, Protokolle und Replays.

### 6.2 Was den Dienst erreicht

| Angabe | Standard | mit Persönlicher Note | nie |
|---|---|---|---|
| Format, Teile, Sprache, `data_hash`, `kit_v`, Prämisse, Meide-Listen (IDs), Paket-ID | ✓ | ✓ | — |
| Token (kurzlebig, an den Auftrag gebunden); technisch die IP-Adresse der Verbindung | ✓ | ✓ | — |
| Vorleben-**Gruppe** (`org_*`, eine von 24) | — | ✓ | — |
| ein Hobby (`hob_*`) | — | ✓ | — |
| eine Eigenschaft (`trt_*`, die erste der gewählten) | — | ✓ | — |
| konkreter Beruf (`occ_*`), Name, Wortform (`f`/`m`/`n`), Freitext („Anderes …“, „Erzählen Sie mehr …“), Aussehen, Foto, Geburtsjahr, Rival:in, Verein, Spielstand, Seed, Geräte- oder Konto-ID | — | — | **nie** |

### 6.3 Persönliche Note

Einschalten nur über die Zeile in „Neue Staffel“ oder Optionen → Staffel; bei **jedem** Einschalten erscheint die
Einwilligung mit Geburtsjahr (wie 08 Kap. 5.2, D-5):

```text
┌──────────────────────────── PERSÖNLICHE NOTE (optional, ab 16) ──────────────────────────────┐
│ M.O.D.s KI-Redaktion schreibt das Drehbuch Ihrer Staffel etwas passender zu Ihrer Karte.     │
│ • Gesendet: höchstens drei Angaben als Auswahl — Vorleben-Gruppe, ein Hobby, eine            │
│   Eigenschaft. Nie Ihr Name, Ihr Beruf, Ihr freier Text, Ihr Aussehen, Ihr Geburtsjahr.      │
│ • Empfänger: unser Server und Anthropic als Anbieter des KI-Modells Claude                   │
│   [Region, AV-Vertrag: zu prüfen].                                                           │
│ • Speicherung: Unser Server löscht die Angaben spätestens 24 Stunden nach dem Auftrag und    │
│   protokolliert solche Aufträge ohne Inhalt. Anthropic kann Anfragen nach eigenen Regeln     │
│   befristet aufbewahren [Dauer, Zero Data Retention: zu prüfen].                             │
│ • Ohne Zustimmung bekommen Sie trotzdem ein eigenes Drehbuch; persönlich wird es dann auf    │
│   Ihrem Gerät.                                                                               │
│ • Widerruf jederzeit: Optionen → Staffel → Persönliche Note aus.                             │
│ Geburtsjahr: [ bitte wählen ▾ ]   (nur zur Altersprüfung, wird nicht gespeichert)            │
│ [Zustimmen und einschalten]                    [Abbrechen]                [Datenschutz ›]    │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Zeile in „Neue Staffel“ (Standard): **„Persönliche Note: aus · Ihre Karte bleibt auf dem Gerät · [Ändern ›]“**, darunter
der Satz aus Kap. 0.5.

- **Unter 16:** „Die Persönliche Note gibt es ab 16. Ihr Drehbuch funktioniert auch ohne.“ — gesperrt bis zum Neustart;
  meldet die Plattform ein Minderjährigen-Konto, wird sie gar nicht angeboten **[Plattform-Schnittstellen zu prüfen]**.
- **Gespeichert** wird lokal nur `{v, date}` der Einwilligung (`GameSettings`, Schlüssel `drb_note`); jede Anfrage trägt
  Version und Datum (Nachweis nach Art. 7 Abs. 1 DSGVO **[zu prüfen]**).
- **Der Dienst** lehnt `persona` ohne `consent` und bei `kind: shared` mit `400` ab, nutzt die IDs nur im Auftragsrahmen
  (Kap. 4.4), schreibt sie in kein Protokoll und löscht den Auftrag spätestens 24 h nach Anlage.
- **Keine Klartext-Spur:** Mit Persönlicher Note darf der Text die Namen der gesendeten IDs nicht wörtlich enthalten
  („Kochen & Backen“), nur Platzhalter (`{hobby}`) — Prüfung in Dienst und Gerät als Teil von V-7. So steht in der
  Textdatei nichts, was die Karte verrät; die Note wirkt über die **Auswahl** (Prämisse, Motto, welche Zeilen
  Platzhalter bekommen) und über passende Satzrahmen.
- **Widerruf** während eines laufenden Auftrags: `DELETE` des Auftrags (Kap. 5.8). „Kandidat:in löschen“ (08 D-7) löscht
  auch diese Einwilligung.

### 6.4 Auf dem Gerät

- Platzhalter füllt nur die Anzeige (`Show._full_ctx`, `UiUtil.format_line` mit `PersonaText.ctx`); die Textdatei, das
  Archiv, Laufprotokolle, Journal und Replays enthalten nur Platzhalter, Plan und Hashes.
- Die Ruhmeshalle speichert Titel und Quelle, keine Namen (08 P-1); Bestenlisten bleiben unberührt.
- Meldungen senden Drehbuch-ID, Teil, Feldpfad und Grund — nie Text, nie Persona.
- **Kanarienvogel** (08 Kap. 2.7 Nr. 6): `test_12_drehbuch_privacy` setzt einen unverwechselbaren Namen, Freitext und
  Look und prüft, dass keiner davon in einer Anfrage (mit und ohne Persönliche Note), in `slot_N.drehbuch.json`, im
  Archiv, im Journal, in einem Laufprotokoll oder in einer Meldung auftaucht.

### 6.5 Aufbewahrung und Löschen

| Ort | Inhalt | Dauer | Löschen |
|---|---|---|---|
| Gerät: `slot_N.drehbuch.json` | Drehbuch mit Platzhaltern, ausgeblendete Pfade | so lange wie der Slot | mit dem Slot (`Save.delete_slot`) |
| Gerät: Archiv | höchstens ein Drehbuch-Satz | bis zur Nutzung, längstens 30 Tage oder bis zum nächsten `data_hash` | automatisch; Optionen → Staffel → „Drehbuch-Archiv leeren“ |
| Gerät: Einwilligung | `{v, date}` | bis zum Widerruf | Widerruf, „Kandidat:in löschen“ |
| Dienst: Auftragsspeicher | Teile, ggf. Persona-IDs | ≤ 24 h | automatisch, `DELETE` |
| Dienst: Inhaltsprotokoll | ausgelieferte Teile, nur ohne Persönliche Note | 30 Tage | automatisch |
| Dienst: technisches und Kosten-Protokoll | Zähler, Kosten (Kap. 4.11) | 30 Tage bzw. 13 Monate | automatisch |
| Dienst: Ratenlimit | `script_acc` und Zähler | 31 Tage | automatisch |
| Modellanbieter | Anfragen | nach Organisationseinstellung **[zu prüfen]** | — |

### 6.6 Geteilte Staffeln

Der Staffel-Dienst sendet nie Persona-Daten (`kind: shared` lehnt `persona` ab). Persönlich wird ein geteiltes Drehbuch
nur auf jedem Gerät für sich, über dieselben Platzhalter — alle lesen denselben Text, jede:r mit dem eigenen Namen.

### 6.7 Prüfungen vor D1

Rechtsprüfung **[zu prüfen]**: DSGVO Art. 6/7/8 (Einwilligung, Minderjährige), Art. 13 (Informationen), Art. 28
(Auftragsverarbeitung), Art. 44 ff. (Drittland), Datenschutz-Folgenabschätzung; Transparenz nach KI-Verordnung Art. 50;
Store-Regeln für KI-Inhalte. Ohne positives Ergebnis bleibt es bei D0 (Pilot und Baukasten).

---

## 7. Inhaltspakete und kuratierter Modus

### 7.1 Ausgangslage aus 11

Ein Build trägt **höchstens ein Paket** (11 O-4), Pakete sind **nur Daten, Texte und Art-Parameter** (11 O-2), ihr
Inhalts-Hash geht in `DB.data_hash()` (11 O-5, §3.9) — damit trägt jedes Drehbuch über `data_hash` automatisch das Paket
in sich, und der Kern braucht für Pakete nichts Neues. Lizenzierte Pakete tragen einen Lizenzblock und leben in einem
privaten Repository; im öffentlichen sorgt die IP-Firewall dafür, dass keines hineingerät (11 O-1, O-6, §3.12). Dieses
Kapitel nennt kein fremdes Werk; was ein Lizenzgeber verlangt, ist Konfiguration.

### 7.2 Der Block `drehbuch` in `pack.json` (Vorschlag, CR-48)

```json
"drehbuch": {"mode": "kuratiert", "scope": "staffel", "files": "drehbuch/", "review": "abnahme", "languages": ["en"]}
```

| Feld | Werte | Regel |
|---|---|---|
| `mode` | `frei` · `kuratiert` · `aus` | Was die KI in diesem Build darf (Kap. 7.3) |
| `scope` | `inhalte` · `staffel` | `inhalte`: der Modus gilt für Texte über die Einträge des Pakets (Herkunft `owned`, 11 Kap. 3.4), sonst gilt `frei`; `staffel`: für das ganze Drehbuch |
| `files` | Ordner im Paket | `glossary.json` (Weltbegriffe, erlaubte Namen, Stimmen), `style.json` (Ton, Beispiele), `kit.json` (Bausteine, Mottos, Prämissen, Figuren des Pakets), `names.json`, `brands.json`, `approved.json` (Vorlagen für `kuratiert`), `forbidden.json` (zusätzliche Sperrwörter — nur strenger, nie lockerer) |
| `review` | `keine` · `stichprobe` · `abnahme` | Abnahme heißt: geteilte Staffeln erst nach Freigabe durch den Lizenzgeber (Kap. 8.1) |
| `languages` | ⊆ `pack.json → languages` | Sprachen, in denen die KI schreiben darf; sonst Baukasten |

**Standard ohne Block:** Pakete ohne Lizenz (wie „Testbild“) verhalten sich wie das Grundspiel (`frei`); Pakete **mit
Lizenzblock** sind `aus`, bis der Block etwas anderes erlaubt. Der Block ist additiv: `PACK_SCHEMA` bleibt 1, `touches`
bekommt den Eintrag `"drehbuch": true` (11 Kap. 3.3, 3.11).

### 7.3 Die drei Modi

| Modus | Was die KI darf | Ausgabe | Prüfung | Kennzeichnung |
|---|---|---|---|---|
| `frei` | wie im Grundspiel; Glossar und Stilbuch des Pakets stehen im System-Prompt | Schema aus Kap. 3 | V-1 … V-15, V-17 | „Drehbuch: KI“ |
| `kuratiert` | je Textfeld **eine freigegebene Vorlage wählen** und ihre Lücken aus erlaubten Listen füllen; kein freier Satz | je Feld `{"tpl": "<id>", "fill": {"<lücke>": "<listen-id>"}}`, alles `enum` im Schema; das Gerät rendert | zusätzlich V-16 | „Drehbuch: kuratiert“ |
| `aus` | nichts | Baukasten des Pakets (sonst des Grundspiels) | V-1 … V-17 | „Drehbuch: Baukasten“ |

„Leicht variieren“ (S-6) heißt im kuratierten Modus: Vorlage und Lückenfüller wählen, Reihenfolge und Zuordnung zu
Haken bestimmen — nie Wörter umstellen. Der Plan (Kap. 3.3) bleibt in allen Modi gleich frei.

### 7.4 Wo der Katalog eines Pakets liegt

- **Der öffentliche Dienst und dieses Repository enthalten keine Paket-Inhalte** (11 O-1, O-6). Der Grund-Dienst
  antwortet auf eine unbekannte Paket-ID mit `409`, der Client schreibt dann mit dem Baukasten.
- Ein lizenziertes Paket mit `frei` oder `kuratiert` braucht eine **eigene Dienst-Instanz**, deren Katalog (Glossar,
  Stilbuch, Bausteine, Vorlagen) aus dem privaten Paket-Repository kommt. Die Adresse steht in der Export-Konfiguration
  des Paket-Builds (`tools/pack_export.sh`, 11-PB), **nie in `pack.json`** — Netzwerk ist kein Paketinhalt (11 Kap.
  3.10). Ohne Adresse gilt `aus`.
- Wird dieses Repository privat (11 F-20), darf der Paket-Katalog des Dienstes neben dem Paket auf dessen Branch liegen;
  Grund-Builds und Grund-Dienst bleiben paketfrei.
- Erzeugte Drehbücher liegen nie im Repository (nur auf Geräten und im Protokoll der jeweiligen Dienst-Instanz); die
  HMAC-Fingerabdrücke (11 Kap. 3.12, Schicht 3) betreffen sie deshalb nicht. `forbidden.json` des Pakets wirkt in V-10
  und im Lektorat.

### 7.5 Plan, Version 2 (mit 09 ST1-C2 und 11 Kap. 4)

Sobald es die Daten gibt, darf der Plan mehr wählen — immer nur aus Daten im `data_hash` und mit Kern-Prüfung
(`script_plan`): je Viertel eine **Gegnerfamilie** aus den Platzhalter-Familien der Kulisse (09 Kap. 3.4), je Auftritt
einer wiederkehrenden Figur die **nächste Mechanik** aus dem Boss-Baukasten (09 Kap. 3.4) bzw. einen Baustein
**MB1–MB8** (11 Kap. 4), wo die Figur ihn in ihren Daten anbietet. Das ist `schema` 2 mit neuen Plan-Feldern; bis dahin
lehnt der Kern jedes unbekannte Plan-Feld ab. Die KI wählt dann eine Kombination — die Zahlen bleiben in den Daten
(S-1).

---

## 8. Geteilte Staffeln und Sprachen

### 8.1 Geteilte Staffeln (09 ST2, S-7)

- Der **Staffel-Dienst** bestellt je öffentlicher Staffel einen Auftrag `kind: shared` (Server zu Server, ohne Persona),
  sobald Format und `data_hash` feststehen — Tage vor dem Start, deshalb gern per Batch.
- **Abnahme:** Die Redaktion liest das Drehbuch vor der Freigabe (bei Paketen mit `review: abnahme` zusätzlich der
  Lizenzgeber); erst dann wird der Drehbuch-Satz signiert. Abnahme ist das Gate für D3.
- **Lieferung** im signierten Staffel-Ticket (09 ST2, 05): Plan, Satz-Hash und die Texte je Sprache. Die Clients
  zeichnen alle Teile mit `src: shared` gleich beim Start auf — alle Spieler:innen haben denselben Plan, Quote und
  Rangliste bleiben vergleichbar; Zuschauer:innen (05) sehen dieselben Texte.
- **Kosten:** einmal ≈ $0.82–0.89 (Akt 3, Opus) plus ≈ $0.49 je weiterer Sprache — pro Kopf vernachlässigbar, deshalb
  bleibt hier das Standardmodell.

### 8.2 Sprachen (11)

- **Private Drehbücher** entstehen in der beim Start eingestellten Sprache (`Tx.lang()`, 11 SP-5), wenn der Dienst sie
  beherrscht. **Englisch erst mit 11-L5:** Bis englische Filterlisten, die Sprachprüfung mit erwarteter Sprache und ein
  englischer Prompt freigegeben sind (11 Kap. 1.13), bekommen englische Staffeln Pilot und Baukasten — wie „M.O.D.
  live“, das auf Englisch bis dahin aus ist.
- Die KI **schreibt Englisch direkt**, nicht übersetzt, nach Glossar und Stimmen aus 11 Kap. 2 (M.O.D. 2.7, Graf Mopsula
  2.8; „contestant“, keine Wortform, 11 SP-7) — umschreiben statt übersetzen (11 R2).
- **Geteilte Staffeln:** Der deutsche Text ist die Vorlage, die englische Fassung schreibt das Modell nach demselben
  Plan mit eigenem englischem Lektorat; beide stehen im selben Drehbuch-Satz mit **einem** Hash (DR-21).
- **Pilot und Baukasten** haben deutschen Quelltext in `data/drehbuch/`; Englisch kommt über eine fünfte PO-Domäne
  `drehbuch` (CR-48: Extraktor, `msgctxt` je Baustein, Lücken `<…>` gelten in `test_11_po_rules` als Platzhalter). Der
  Baukasten liest seine Bausteine über `Tx` und bekommt die Sprache von außen (11 SP-4).
- **Längen und Prüfung:** V-4 nutzt die Höchstlängen der Platzhalter je Sprache (08 §4.4 englisch, 11 Folgeänderung),
  V-8 die englische Sprachregel, V-10 die englischen Listen.
- **Determinismus:** Der Befehl trägt keine Sprache (Kap. 5.2); `test_11_lang_determinism` bekommt einen
  `script`-Befehl.

---

## 9. Umsetzung

### 9.1 Reihenfolge und Abhängigkeiten

```text
ST1-H + ST1-I gelandet ─► KS0 Vertrag ─┬─► KS1 Schema, Prüfer, Baukasten, Pilot ─┬─► KS3 Einbau ─► KS4 UI ─► D0
                                       └─► KS2 Dienst mit Mocks ─────────────────┴──────────────► KS5 QA ─► D1, D2
09 ST2 Staffel-Dienst ─────────────────────────────────────────────────────────────────────────────────────► D3
11-P1 ─► Paket-Block (CR-48) · 11-L1/L3 ─► Baukasten englisch · 11-L5 ─► KI englisch · 09 ST1-C2 ─► Teile 2, 3
```

- **KS1 und KS2 laufen parallel** nach KS0 (zwei Agenten); der Python-Port des Prüfers folgt den Fixtures aus KS1.
- **KS4** fasst die Staffel-UI erst an, wenn ST1-H gelandet ist (deren Dateien, 09 Kap. 11.4); **KS0** braucht ST1-H und
  ST1-I, weil beide `game.gd`, `save.gd` und die Staffel-Ansichten berühren.
- **08 K3** nutzt dieselbe Zeilenquellen-API am `ModAnnouncer` — KS0 legt sie an und stimmt sie mit dem Eigentum aus 08
  ab.
- **Teile 2 und 3** brauchen die Etagen 7–18 in den Daten (09 ST1-C2); bis dahin schreibt der Dienst nur Teil 1.
- **Stufen:** **D0** = KS0, KS1, KS3, KS4 — jede Staffel hat schon ein eigenes Drehbuch aus Pilot und Baukasten, ohne
  Netz. **D1** = + KS2 und KS5-Teil 1: „KI-Drehbuch (Beta)“ zum Einschalten. **D2** = KS5-Gate bestanden: KI als
  Standard privater Staffeln (gekennzeichnet; Persönliche Note bleibt Opt-in). **D3** = mit 09 ST2.

### 9.2 Pakete

| Paket | Inhalt | Startet | Aufwand **[Schätzung, PT mit KI]** |
|---|---|---|---|
| **KS0** Vertrag | Kap. 9.3 (Integrator) | nach ST1-H und ST1-I | 2–3 |
| **KS1** Schema, Prüfer, Menü, Baukasten, Pilot | `drehbuch.gd`, `drehbuch_menu.gd`, `drehbuch_validator.gd` (V-1 … V-17), `drehbuch_kit.gd` (Baukasten, Flicken, Ersatztexte), `drehbuch_text.gd` (`{tip}`); `data/drehbuch/*` mit eigenem Validator; Fixtures `tests/fixtures/drehbuch/cases.json`; Menü-Export für den Dienst | nach KS0 | 10–13 (+ Redaktion 8–12: Bausteine, Pilot, Namen, Marken, Weltbibel, Stilbuch) |
| **KS2** Dienst | `script_brain.py`, `script_prompt.py`, `script_schema.py` (Schema-Bau je Version), `script_validator.py` (Port), `script_jobs.py` (Aufträge, 24 h), `script_review.py` (Lektorat, Reparatur), `script_batch.py` (Vorproduktion); Routen in `app.py`, Konfiguration, Budget, Ratenlimit, Not-Aus, Protokolle; `tools/script_eval.py`; Tests mit Mocks | nach KS0, parallel zu KS1 | 9–12 |
| **KS3** Einbau | `DrehbuchRules` mit Haken (Kap. 5.3), `DrehbuchLink` und `RemoteDrehbuch` (Quelle, Auftrag, Fristen, Binden, Archiv), `ShowDrehbuch` (Haken, Erzählbudget, Quellen), Textdatei und Ersatztexte, Banner-Name, Replay- und Verifier-Tests | nach KS1 | 10–13 |
| **KS4** Oberfläche | Zeilen in „Neue Staffel“, Einwilligung, Vorspann-Karte, Segment „Drehbuch“, Programmnamen, Etagen-, Login- und Staffel-Bilanz, Ruhmeshalle, Slot-Titel, KI-Zeichen, Ausblenden und Melden, Optionen; Captures | nach KS3 und ST1-H | 7–9 |
| **KS5** QA | Bewertungsbogen, Red-Team, Kosten- und Latenz-Messung, Vielfalt, Harness-Vergleich, Modellvergleich, Datenschutz-Abnahme (Kap. 9.6) | nach KS2–KS4 | 6–8 (+ Redaktion 3–4, externe Rechtsprüfung) |
| **Summe** | | | **≈ 44–58 PT ≈ 2,5–3,5 Monate** für eine Person mit KI; mit KS1 ∥ KS2 ≈ 7–9 Kalenderwochen; dazu Redaktion 11–16 PT |

Nicht enthalten: Bausteine und Pilot für Teil 2 und 3 (mit den Kulissen aus 09 ST1-C2, ≈ Redaktion 6–8 PT je Akt
**[Schätzung]**), Paket-Kataloge (Sache des jeweiligen Pakets), englische Bausteine (11-L3, ≈ 1–2 PT Übersetzung).

### 9.3 KS0-Vertrag

1. `core/live/command.gd`: `TYPES` und `EXTERNAL` += `script`; `SCRIPT_VERSION = 1`; Form-Prüfung `_script` (Teil 1–3,
   `drb_` + 16 hex, Quelle, 64-hex-Hash, Plan als Dictionary); Fälle in `test_m8_command`.
2. `core/live/run_rules.gd`: `season_refusal` und `apply_season` leiten `script` an `DrehbuchRules` (KS0: Stub, lehnt
   mit `script_unavailable` ab — wie die Stubs aus 09 ST0).
3. `core/season/season_state.gd`: Feld `script` (Dictionary), additiv in `to_dict`/`from_dict` wie `sleeper`;
   `StateHash` unverändert (kein neuer ausgenommener Schlüssel).
4. Neutrale Haken: `SeasonRules.daily_id`, `RegieDirector.decide`, `MarottenRules._draw_weight` fragen `DrehbuchRules`
   (ohne Plan: kein Eintrag, Faktor 1000, +0).
5. `core/show/mod_announcer.gd`: `set_line_source(name, provider, mode)` mit `MIX`/`PREFER`, `set_extra_lines` als
   Quelle `persona`; `drb_` in `ALWAYS_SAID_PREFIXES` und `NO_COOLDOWN_PREFIXES`; Tag-Präfix registriert (02_TECH §0.8).
6. `autoload/save.gd`: `drehbuch_path(slot)`, Schreiben/Lesen/Löschen mit dem Slot, Archiv unter `_data_root()`.
7. `autoload/game.gd`: Fassaden `season_script()` (nur lesen) und `bind_script(part)` (zeichnet `script` auf);
   `DrehbuchLink` als Kind-Node (Stub).
8. `data/drehbuch/` mit gültigen Stubs (`kit.json`, `names.json`, `brands.json`, `bible.json`) und erste Fixtures.
9. `tests/test_12_ks0_contract.gd`: Formen, Ablehnungen, additiver Zustand (JSON und Hash einer Staffel ohne Drehbuch
   unverändert), neutrale Haken, Quellen-API, Fixtures.

**Gate:** `check.sh` grün; Fullrun bitgleich; `test_09_replay`-Goldens unverändert.

### 9.4 Dateien und Eigentum

| Datei / Bereich | Eigentum | Regel |
|---|---|---|
| `core/season/drehbuch*.gd`, `autoload/drehbuch/**`, `autoload/show_drehbuch.gd`, `scenes/ui/season_opening.*`, `scenes/ui/drehbuch_consent.*`, `data/drehbuch/**`, `tests/test_12_*`, `tests/fixtures/drehbuch/**` | **KS** (neu) | neu |
| `core/live/command.gd`, `run_rules.gd`; `core/season/season_state.gd`, `season_rules.gd` | 09 ST0/ST1-B | KS0-Vertrag, additiv |
| `core/live/regie_director.gd`, `core/show/marotten_rules.gd` | 06-D, 06-C | KS0, je ein neutraler Haken |
| `core/show/mod_announcer.gd` | 08 K0 / 06 | KS0, Quellen-API (abgestimmt mit 08 K3) |
| `autoload/game.gd`, `save.gd`, `show.gd` | M0/M2 (+ Abschnitte 05–11) | je ein Abschnitt 12, additiv |
| `scenes/exploration/exploration.gd` | M3 | KS3: Banner-Name |
| `scenes/ui/mod_dialog.gd`, `floor_summary.gd`, `settings_menu.gd` | M6 | KS4: KI-Zeichen, Block „Folge“, Optionen |
| `scenes/title/season_setup.gd`, `slot_select.gd`; `scenes/ui/season_tab.gd`, `season_view.gd`, `season_summary.gd`, `hall_of_fame.gd`; Login-Bilanz | 09 ST1-H, ST1-G | KS4 erst nach Landung, je ein Abschnitt |
| `scenes/combat/**`, `core/rt/**` | R-Phasen (07) | **unverändert** |
| `services/mod-brain/mod_brain/script_*.py`, `tests/test_script_*.py`, `tools/script_eval.py` | **KS** (neu) | neu |
| `services/mod-brain/mod_brain/app.py`, `config.py`, `auth.py`, `budget.py`, `rate_limit.py`, `catalog.py`, `persona.py`, `README.md` | 06-D | KS2 additiv (CR-49) |
| `docs/12_KI_SHOWRUNNER.md` | 12 | — |

### 9.5 Tests

| Test | Paket | Prüft |
|---|---|---|
| `test_12_ks0_contract` | KS0 | Kap. 9.3 |
| `test_12_drehbuch_schema` | KS1 | Schema, Größe, Anzahl, unbekannte Schlüssel; alle Fixtures aus `cases.json` |
| `test_12_drehbuch_validator` | KS1 | jede Regel V-1 … V-17 mit Positiv- und Negativfall; Sprachregel, `ip_words`, Filter, Mopsula, Platzhalter-Grammatik, Ziffern, Längen mit Probe |
| `test_12_drehbuch_kit` | KS1 | 10 000 Seeds × Formate × Teile ohne harte Funde; gleicher Seed → gleiches Dokument; Ersatztexte zu fremden Plänen; Flicken; Vielfalt |
| `test_12_drehbuch_menu` | KS1 | Mottos verweisen auf vorhandene Vorlieben und Twists; Namen getrennt von `cast.json` und den Rival:innen; Marken nicht in `real_brands`; Auszeichnungen vorhanden und nicht versteckt; Figuren decken alle Bosse der Etagen 2–6 |
| `test_12_drehbuch_bind` | KS3 | alle Ablehnungen; `apply` → `SeasonState.script`; `daily_id`, Regie- und Vorlieben-Gewicht mit Plan; Hash nur mit Block; `RunSim.replay` = `Game.replay_log`; Journal-Rundreise; Laden ohne Textdatei → Ersatztexte; Fristen (`descend`, `clock`, `away`) |
| `test_12_drehbuch_lines` | KS3 | Quellen `MIX`/`PREFER`, `drb_`-Tags, Erzählbudget, nie im Kampf außer `boss_intro`, Füllen mit Kanon- und Zufalls-Persona, ≤ 110 Zeichen nach dem Füllen |
| `test_12_drehbuch_link` | KS3 | `DrehbuchLink` mit Mock-Dienst (kein Netz): Auftrag, Nachfragen, Zeitlimits → Baukasten, später Teil → Archiv, nie blockierend, `409`/`429`/`503` |
| `test_12_drehbuch_privacy` | KS3/KS4 | Kanarienvogel (Kap. 6.4); Persönliche Note nur mit Einwilligung; nur erlaubte IDs; Meldung ohne Text |
| `test_12_drehbuch_ui` | KS4 | Vorspann, Segment, Bilanzen, Ruhmeshalle ohne Namen, Quelle überall, KI-Zeichen-Option; Capture-Rezepte 1280 × 720 und 2400 × 1080 `--touch` |
| `test_script_schema.py` | KS2 | Anfrage- und Antwortmodelle; `400`, `409`, `413`; Schema-Bau je Version konstant |
| `test_script_validator.py` | KS2 | Port gegen dieselben Fixtures wie GDScript |
| `test_script_brain_mocked.py` | KS2 | gemockter Client: `refusal`, `max_tokens`, kaputtes JSON, Lektorats-Funde, Reparaturrunde, `fallbacks` nur ohne Haiku und ohne Batch, `effort` je Schritt |
| `test_script_jobs.py` | KS2 | Lebenslauf eines Auftrags, 24 h, `DELETE`, Wiederholung derselben Anfrage, Ratenlimit über `script_acc` |
| `test_script_isolation.py` | KS2 | kein Client-String im Prompt (jedes Feld mit Fremdtext → `400`), Persona nur mit Einwilligung und nie bei `shared`, keine Persona in Protokollen |
| `test_script_budget.py` | KS2 | Deckel je Auftrag, Monatsbudget, Not-Aus |
| `test_catalog_sync.py` (erweitert) | KS2 | Menü-Export des Spiels = Katalog des Dienstes (Twists, Vorlieben, Mottos, Prämissen, Namen, Marken, Pools, Figuren) |
| `test_08_persona_privacy`, `test_11_lang_determinism` (Folgeänderungen) | KS3 | Kanarienvogel um Drehbuch-Dateien erweitert; ein `script`-Befehl in der Sprachen-Befehlsfolge |

### 9.6 Gates

| Gate | Pakete | Kriterium |
|---|---|---|
| `check.sh` | alle | grün (Import, Tests, Smoke) |
| **Bitgleich ohne Staffel und ohne Drehbuch** | KS0, KS3 | `tools/fullrun.sh --strategy=all`, `--hero=mopsula`, `--liga=1` und `--liga=2` (Kampagne ohne Staffel) liefern dieselben Zeilen „FULLRUN: stats {…}“ und „FULLRUN: OK …“ wie vorher; Staffeln ohne Drehbuch behalten JSON und Hash; `test_09_replay`-Goldens und `test_r1_rt_golden` grün; `DB.data_hash()` unverändert |
| Nachrechenbar mit Drehbuch | KS3 | beide Verifier gleicher `StateHash`; Journal-Rundreise; Sprachwechsel ändert keinen Hash |
| Staffel-Harness | KS3, KS5 | `tools/season_harness.sh --gate` (09 ST1-I) ohne und mit Drehbuch (Baukasten-Pläne, 200 Seeds je Format): Pensum, Quote, Credits und Rettungen je Etage innerhalb ±5 % **[zu messen]** |
| Baukasten | KS1 | null harte Funde über 10 000 Seeds; Titel-Wiederholung ≤ 5 % über 200 Staffeln |
| Dienst | KS2 | `pytest` im CI-Job `mod-brain-tests` grün — **nur mit Mocks, kein Live-API-Aufruf in der CI**; Port besteht dieselben Fixtures |
| Qualität (KS5) | KS5 | **(a) Bewertung:** 60 Drehbücher (je Prämisse 5) durch die Redaktion, Noten 1–5 für Witz, Stimmigkeit, Stimmen, Ton, Abwechslung, Sprache — Mittel ≥ 4,0, kein Ton < 3, Pilot als Referenz; **(b) Red-Team:** 200 Aufträge mit allen Prämissen, Meide-Listen und Grenzfällen der Persönlichen Note — null harte Funde, die ein Gerät erreichen; **(c) Kosten:** gemessene Tokens ≤ Annahmen + 20 %; **(d) Latenz:** p95 Teil 1 ≤ 8 min, verpasste Fristen ≤ 2 %; **(e) Vielfalt:** Dreiwort-Überlappung zwischen Drehbüchern derselben Prämisse ≤ 30 %; **(f) Modellvergleich** Opus 5.5 / Sonnet 5.5 / Haiku 5.5 auf denselben 60 Aufträgen (`tools/script_eval.py`); **(g) Datenschutz:** Kanarienvogel grün, Rechtsprüfung abgeschlossen **[zu messen, zu prüfen]** |

Live-Aufrufe gibt es nur in `tools/script_eval.py` und im Red-Team, von Hand gestartet, mit eigenem Budget.

### 9.7 Änderungsanträge

| CR | Betrifft | Änderung | Wann |
|---|---|---|---|
| **CR-40** | `09` §3.3, §9.1, §2.7, Kap. 11.4 | Tagesprogramm-Reihenfolge darf aus dem Drehbuch-Plan kommen; Befehl `script` in der Liste der Staffel-Befehle; `SeasonState.script`; Vorspann ab Etage 2; Segment „Drehbuch“ im Reiter, Felder `drb_title`/`drb_src` der Ruhmeshalle; Dateieigentum | KS0, KS4 |
| **CR-41** | `06` §5.2, §5.7a, Kap. 4, §5.9, §5.12 | Ausnahme in „darf nicht“: Das Staffel-Drehbuch schreibt **vorab, geprüft und gekennzeichnet** Erzähltexte und Namen von Auszeichnungen (Tutorials, Regeltexte und Erfolgstexte bleiben geschrieben); Regie-Gewicht für den Twist der Folge; Vorlieben-Gewicht des Mottos; neue Route `/v1/script` ohne Client-Strings (Nr. 2 gilt ohne Ausnahme); Stufen D0–D3 neben S0–S3 | KS0 |
| **CR-42** | `07` §2.9, §9.3 | Das Boss-Intro (vor dem Kampf, Simulation steht) darf eine Drehbuch-Zeile sein; Banner-Name „Rollenname — Beiname“; alle Zeilen **im** Kampf bleiben geschrieben | KS3 |
| **CR-43** | `08` Kap. 4.3, 4.4, 5, 2.7 | Persönliche Note als eigene Einwilligung; Persona-Beats vor Drehbuch-Zeilen (Erzählbudget); Platzhalter in Drehbuch-Texten; `set_extra_lines` als Quelle `persona` der neuen Quellen-API; Kanarienvogel erweitert | KS0, KS3 |
| **CR-44** | `02_TECH` §0.4, §0.8, §1, §11 | Module aus Kap. 5.1, Tag-Präfix `drb_`, Seed-Zweck `drehbuch`, Dateibaum `data/drehbuch/`, Tests | KS0 |
| **CR-45** | `05` §10.6, §11.4; 09 ST2 | externe Eingabe `script` (Befehls-ID 0), Verifier-Regel, Lieferung im Staffel-Ticket, Zuschauer:innen | KS0, D3 |
| **CR-46** | `03_ART` §9 | Vorspann-Karte, KI-Zeichen, Banner mit Beiname, Segment „Drehbuch“ | KS4 |
| **CR-47** | `04` | Offenlegung KI-erzeugter Inhalte in Stores und Marketing, Kostenrahmen je Staffel, Rechtsprüfungen aus Kap. 6.7 | vor D1 |
| **CR-48** | `11` §3.3, §3.10, §1.2, §1.11 | optionaler Block `drehbuch` in `pack.json` (Kap. 7.2) mit Ordner `drehbuch/` im Paket und `touches`-Eintrag; Dienst-Adresse nur über die Export-Konfiguration (PB); fünfte PO-Domäne `drehbuch`, Lücken `<…>` als Platzhalter in `test_11_po_rules`; KI-Drehbuch englisch erst mit L5 | mit 11-P1 bzw. 11-L1 |
| **CR-49** | `services/mod-brain` (06-D) | Routen `/v1/script/*`, Konfiguration (`MOD_BRAIN_MODEL_SCRIPT`, `MOD_BRAIN_EFFORT_SCRIPT`, `MOD_BRAIN_SCRIPT_BUDGET_USD`, `MOD_BRAIN_SCRIPT_JOB_USD`, `MOD_BRAIN_SCRIPT_OFF`), README; `persona.py` erklärt M.O.D. heute als „Moderations-Organ des Dungeons“ — angleichen an 00_BRIEF („Mediale Omnipräsente Direktorin“), damit beide Routen eine Weltbibel teilen | KS2 |

Folgeänderungen ohne CR (mit diesem Dokument eingetragen): Verweise in `00_BRIEF` (Vorrangabsatz), `09` §3.3 und
`README.md` (Ordner, Dokumente). Mit D0: `CHANGELOG.md`.

---

## 10. Risiken

| # | Risiko | W / A | Gegenmaßnahme | Frühindikator |
|---|---|---|---|---|
| KR-1 | **Qualität schwankt** (flache Pointen, Floskeln, falscher Ton) | hoch / mittel | Stilbuch mit Beispielen, Lektorat, Bewertung als Gate, Pilot für den ersten Eindruck, Modellvergleich, wöchentliche Stichproben | Bewertung < 4,0; Meldungen „ton“ |
| KR-2 | **Wiederholung** über Staffeln | mittel / mittel | Prämissen-Katalog mit Meide-Liste, Meide-Listen für Namen und Marken, V-14, Vielfalts-Gate, Katalog wächst je Quartal | gleiche Titel oder Pointen in Stichproben |
| KR-3 | **Unsichere oder verletzende Ausgabe** | niedrig / sehr hoch | nur IDs im Prompt, Schema, zwei Prüfer, Lektorat, dieselben Filter wie für geschriebene Zeilen, Baukasten-Rückfall, Not-Aus, Meldeweg | Red-Team-Fund; Meldungen „unpassend“ |
| KR-4 | **Falsche Versprechen** (Text behauptet Regel, Zahl oder Ereignis) | mittel / mittel | DR-6, DR-13, `{tip}` aus dem Zustand, keine Ziffern, Haken nur bei echtem Ereignis | Meldungen „falsch“ |
| KR-5 | **Kosten** laufen davon | mittel / mittel | Deckel (DR-23), Vorproduktion, Modellwahl, Kostenprotokoll mit Alarm | Monatskosten über Plan |
| KR-6 | **Latenz oder Ausfall** des Dienstes | mittel / niedrig | Aufträge statt Warten, Fristen, Baukasten liegt sofort bereit, Archiv | verpasste Fristen > 2 % |
| KR-7 | **Datenschutz** | niedrig / hoch | ohne Persona als Standard, Opt-in ab 16, IDs statt Text, keine Speicherung, Kanarienvogel, Rechtsprüfung vor D1 | Kanarienvogel rot; Prüfungsfund |
| KR-8 | **Vertrauen** der Spieler:innen in KI-Inhalte | mittel / mittel | Kennzeichnung (DR-15), Pilot und Baukasten als gleichwertige Wege, Abschalten, Ausblenden, keine KI im Kampf, offene Store-Texte | Abschaltquote; Rezensionen |
| KR-9 | **IP-Nähe** (die KI greift Werke Dritter auf) | niedrig / hoch | Weltbibel in eigenen Worten, klare Regel im Prompt, `ip_words`, Lektorats-Regel `ip`, kuratierte Prämissen, Pakete nur nach 11 | Lektorats-Funde `ip` |
| KR-10 | **Determinismus oder Versionen** (ein Plan wirkt unbemerkt anders) | niedrig / hoch | Plan nur aus IDs, Kern-Prüfung, Satz-Hash, gepinnter `data_hash`, bitgleich ohne Drehbuch, beide Verifier im Test | Replay- oder Hash-Abweichung |
| KR-11 | **Balance** verschiebt sich durch Gewichte | mittel / mittel | kleine Gewichte, Twist-Budget (V-6), Harness-Gate | Harness außerhalb ±5 % |
| KR-12 | **Text passt nicht zur Welt** (Boss, Kulisse, Programmpunkt falsch beschrieben) | mittel / niedrig | Menü mit Ein-Satz-Beschreibungen, Lektorats-Regel `stimmigkeit`, Rollen bleiben, Captures | Meldungen „unpassend“ |
| KR-13 | **Abhängigkeiten** (ST1-H, ST1-I, 08 K3, 11, ST1-C2) | mittel / niedrig | KS0 erst nach ST1-H/I, Quellen-API abgestimmt, Paket- und Englisch-Teile hinter 11-P1/L5, Teile 2/3 hinter ST1-C2 | Merge-Konflikte; wartende Pakete |

---

## 11. Offene Fragen mit Empfehlung

| Nr. | Frage | Empfehlung |
|---|---|---|
| F-1 | Wie deutlich wird KI-Text gekennzeichnet? | **Quelle überall fest** (Vorspann, Reiter, Bilanz, Slot, Ruhmeshalle) und **KI-Zeichen an jeder Zeile**, standardmäßig an und abschaltbar; Store-Text nennt „KI-geschriebene Staffel-Drehbücher, vorab geprüft“. Wortlaut nach der Rechtsprüfung **[zu prüfen]**. |
| F-2 | KI als Standard (D2) oder immer Opt-in? | **D1 Opt-in-Beta, D2 Standard** nach dem KS5-Gate, weil ohne Persönliche Note nichts Persönliches gesendet wird; die erste Staffel bleibt der Pilot. Bewertung der IP-Adresse als Personenbezug und der Transparenzpflicht **[zu prüfen]**. |
| F-3 | Mehrere Piloten? | **Einer** zum Start; ein zweiter für Akt 2/3, sobald es die Etagen gibt. |
| F-4 | Bosse ganz umbenennen statt Beinamen? | **Nein in D1/D2.** Beinamen tragen die Staffel; Rollennamen halten Wiedererkennung, Modelle und 09 Kap. 3.1 stabil. Nach dem Playtest neu bewerten. |
| F-5 | Modell und `effort`? | **Opus 5.5, `medium`** in D1 als Qualitätsmaßstab; für D2 entscheidet der Vergleich: Sonnet 5.5, wenn es in der Bewertung höchstens 0,2 Punkte darunter liegt. Geteilte Staffeln immer mit dem Standardmodell. |
| F-6 | Lektorat mit kleinerem Modell? | Im Vergleich mitmessen; Haiku 5.5 nur, wenn es ≥ 95 % der Funde des großen Modells findet **[zu messen]**. |
| F-7 | Dürfen Spieler:innen die Prämisse wählen? | **Nein in D1/D2** (Überraschung, Vielfalt). Später „Prämisse wünschen“: drei Karten aus dem Katalog, nie Freitext. |
| F-8 | Welche Felder für die Persönliche Note? | **Vorleben-Gruppe, ein Hobby, eine Eigenschaft** — nicht mehr; nie Beruf oder Wortform. |
| F-9 | Reaktive Teile (Teil 2/3 kennen den Staffelverlauf)? | **Später**, nur als grobe Bänder (Quote-Band, Rettungen 0 / 1–2 / 3+), ohne Persona, nach Daten aus D2. |
| F-10 | Inhaltsprotokoll? | **30 Tage, nur ohne Persönliche Note**, Zugriff nur für die Redaktion; kürzer, wenn die Rechtsprüfung es verlangt. |
| F-11 | Drehbücher teilen (Freund:innen spielen das Drehbuch einer anderen Staffel)? | **Später mit 09 ST2:** ein privates Drehbuch ohne Persönliche Note wird Vorlage einer Freundesstaffel. |
| F-12 | Rückruf schlechter Zeilen nach der Auslieferung? | **D1/D2:** lokal ausblenden und melden. **Ab ST2:** signierte Rückrufliste (Drehbuch-ID + Feldpfad), die Clients beim Start holen — ersetzt nur Texte durch Ersatztexte, nie den Plan. |
| F-13 | Sprachwechsel mitten in der Staffel? | **Ersatztexte** zum selben Plan (Kap. 5.8); private Drehbücher werden nicht nachübersetzt (Kosten, Datenschutz). |
| F-14 | „M.O.D. live“ mit dem Drehbuch verbinden? | **Später:** „M.O.D. live“ bekommt die IDs des Plans (Motto, Twist der Folge) als Kontext — nie Texte vom Client (06 §5.9 Nr. 2). |
| F-15 | Wer trägt die Kosten — Preis, Abo, Kauf? | **Im Preis enthalten, mit Deckel**; kein Kauf je Drehbuch (06 L-5: nichts Käufliches, das Inhalte steuert). Geschäftsentscheidung in 04 **[festzulegen]**. |
| F-16 | Vorproduktion standardmäßig an? | **Ja** (halber Preis, sofort bereit), mit Satz in der Staffel-Bilanz und abschaltbar; ein ungenutztes Drehbuch verfällt nach 30 Tagen. |
