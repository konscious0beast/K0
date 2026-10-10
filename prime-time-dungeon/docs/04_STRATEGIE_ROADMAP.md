# PRIME TIME DUNGEON — Strategie & Roadmap

> Grundlage: `00_BRIEF.md` (verbindlich, hat Vorrang), `01_GDD.md` (Inhalt/Balancing), `02_TECH.md` (Technik-Vertrag, Module M0–M7),
> `03_ART.md` (Option B: stilisiertes Low-Poly-Toon-3D, Upgrade-Pfad Blender → glTF), `05_LIVE_MODUS.md` (SHOWRUN, Stufen S0–S5).
>
> Zweck: **Wie aus diesem Repo ein veröffentlichtes Spiel wird** — Schritt für Schritt, mit Zahlen, Gates und Entscheidungen.
>
> Kennzeichnung:
> - **[zu prüfen]** = reale Fakten (Recht, Förderprogramme, Plattformregeln, Gebühren, Termine, Rechteinhaber), die vor einer
>   Entscheidung an der Originalquelle bzw. durch Fachleute (Anwalt, Steuerberatung, Förderberatung) verifiziert werden müssen.
>   Nichts in diesem Dokument ist Rechts- oder Steuerberatung.
> - **Schätzung** = Planungswerte (Budgets, Dauern, Wishlists). Sie sind bewusst konkret, damit man sie messen und korrigieren kann.
>
> Stand: 2026-10-10. Phase 0 abgeschlossen; Phase 1 (Grey-Box-Loop) und der technische Teil von Phase 2 (Etage 1 spielbar,
> SHOWRUN S0) sind gebaut; offen sind die Exit-Punkte von Phase 2 (Kap. 3.4, Stand in Kap. 10.1).

---

## Inhalt

1. Vision & Positionierung
2. IP- & Rechtsstrategie
3. Phasenplan 0–7 (Meilensteine, Lieferungen, Definition of Done)
4. Team- & Budget-Szenarien
5. Finanzierung
6. Monetarisierung & Preise
7. Marketing-Plan
8. Plattform-Strategie
9. Risiko-Register & KPIs
10. Wie ich (Claude) jetzt konkret vorgehe
11. Entscheidungen, die ich von dir brauche

---

## 0. Die Strategie in 12 Sätzen

1. Wir bauen **eine eigene IP**: ein rundenbasiertes 3D-Dungeon-RPG, in dem **Überleben und Unterhalten** zwei gleichwertige Ressourcen sind.
2. Das Repo liefert zuerst einen **spielbaren Vertical Slice (Etage 1)** mit prozeduraler Toon-Optik — gebaut von Claude in Modulen M0–M7, automatisch getestet.
3. Der Slice ist **kein Produkt**, sondern ein **Beweis**: Macht die Show-Mechanik Spaß? Tragen M.O.D. und Graf Mopsula? Wird gelacht?
4. Erst wenn externe Playtests das bestätigen (Gate Phase 2), investieren wir in Art-Upgrade, Firma, Förderung, Team.
5. **PC zuerst** (Steam Early Access, Steam Deck), **Mobile danach** (Android/iOS, Free-Demo + einmaliger Vollversions-Kauf).
6. **Premium-Modell**: Spieler:innen kaufen das Spiel — **nie Zufallsinhalte**, kein Pay-to-Win, keine Werbung, keine Energie.
7. Echtgeld-Zuschauergeschenke (Brief Kap. 5) sind ein **späteres Zusatzmodul** (Phase 7, SHOWRUN S3/S5) hinter einer **Rechtsprüfung** — der Business-Case hängt **nicht** daran.
   **Entscheidung 2026-10-08:** Echtgeld von Zuschauer:innen fließt **nur an Spiel/Betreiber**, nie an Spieler:innen oder
   Streamer:innen (keine Creator-Beteiligung); Echtgeld-Weg ist der **eigene Shop (Web + App-Store-IAP)**, Twitch nur kostenlose
   Interaktion. Geholfen werden darf nur in **Sponsor-Fenstern** (begrenzte Plätze, feste Zeitpunkte; 05 Kap. 6.13).
8. Inhaltlich: **Staffel 1 = Etagen 1–6** bis 1.0; **Staffel 2 = Etagen 7–9** als bezahlte Erweiterung nach 1.0.
9. Baseline-Szenario: **Solo + KI bis Ende Phase 2**, danach **kleines Team (4–5 Personen)**, finanziert aus Förderung + Publisher oder Crowdfunding.
10. Marketing beginnt mit der **Steam-Seite in Phase 3** und lebt von **15–30-Sekunden-Clips der Show-Mechanik** (M.O.D.-Sprüche, Stunts, Sponsor-Drops).
11. Rechtlich: DCC ist **Inspiration, keine Vorlage**. Vor dem ersten öffentlichen Auftritt machen wir ein **Distanz-Review** (Begriffe/Figuren) und eine **Markenrecherche** für den Titel.
12. Eine **DCC-Lizenz** ist eine Option, kein Plan: Anfrage frühestens mit polierter Demo und ≥ 10 000 Wishlists — und nur, wenn die eigene IP dadurch nicht blockiert wird.

---

## 1. Vision & Positionierung

### 1.1 One-Liner

> **„Überleb die Etage. Und sorg dafür, dass die Quote stimmt.“**
> Ein rundenbasiertes Dungeon-RPG als galaktische Reality-Show — mit einem arroganten sprechenden Mops und einer Moderations-KI, die deine Tode live kommentiert.

### 1.2 Elevator Pitch (30 Sekunden)

Ein Medienkonzern aus dem All hat die Erdoberfläche abgerissen, um Platz für seine Erfolgsshow zu schaffen. Du bist Kai,
Nachtschicht im Tierheim, und plötzlich **Kandidat:in in DUNGEON PRIME TIME** — mit Graf Mopsula, einem Mops, der sprechen
kann, sich für Hochadel hält und Feuer zaubert. Jede Etage hat einen **Countdown**; findest du die Treppe nicht, ist die Sendung
für dich vorbei. Kämpfe laufen **rundenbasiert mit sichtbarer Zugreihenfolge** — aber die Zuschauer:innen langweilen sich schnell:
Abwechslung, Stunts, knappe Siege und Combos treiben den **Hype** — und Hype bringt **Sponsor-Geschenke mitten im Kampf**.
Sicher spielen oder spektakulär spielen? Das ist jede Runde die Frage. Eine Etage = 20 Minuten. Perfekt für Feierabend, Steam Deck und Handy.

### 1.3 Zielgruppe

| Segment | Beschreibung | Was sie suchen | Wo wir sie erreichen | Gewicht |
|---|---|---|---|---|
| **Primär: „Feierabend-JRPGler“** | 25–40 Jahre, mit FF/Persona/Octopath aufgewachsen, wenig Zeit, Steam Deck/Handheld | taktische Rundenkämpfe, Charaktere mit Witz, kurze Sessions mit Fortschritt | Steam-Tags (Turn-Based Combat, JRPG, Dungeon Crawler), YouTube/Reddit-JRPG-Communities | 50 % |
| **Primär: LitRPG-/Progression-Fantasy-Leser:innen** | lesen/hören Serien mit Gamesystemen, Achievements, Loot-Ansagen | sichtbares System, Ansagen, Achievement-Humor, Satire | Reddit (r/litrpg, r/ProgressionFantasy), Hörbuch-/BookTok-nahe Creator | 25 % |
| **Sekundär: Roguelite-Spieler:innen** | Slay-the-Spire/Hades-Publikum | Run-Struktur, Seeds, Bestenlisten, Wiederspielwert | SHOWRUN-Event-Läufe, Tages-Seeds, Next Fest | 15 % |
| **Multiplikatoren: Streamer:innen & Zuschauer:innen** | Variety-Streamer:innen DE/EN mit 50–5 000 Zuschauer:innen | Inhalte, die Chat-Interaktion erzeugen | Streamer-Modus (Chat-Votes), Keys, Twitch-Kategorie | 10 % (aber Reichweiten-Hebel) |

Altersfreigabe-Ziel: **USK 12 / PEGI 12** (Comic-Gewalt, schwarzer Humor, kein Gore, keine Glücksspielmechanik für Spieler:innen). **[Einstufung zu prüfen]**

### 1.4 Vergleichstitel — was wir übernehmen, was nicht

| Titel | Übernehmen | Bewusst **nicht** übernehmen |
|---|---|---|
| **Final Fantasy X** | CTB mit sichtbarer Zugreihenfolge (Vorschau 10 Züge), Aktionen kosten unterschiedlich viel „Zeit“ | lineare Schlauchlevels, 60-h-Länge |
| **Final Fantasy XII** | sichtbare Gegner auf der Karte, Anlauf/Rücken entscheidet über Präventivschlag | Gambit-Komplexität, MMO-Weite |
| **Octopath Traveler** | **Starke Stil-Identität mit kleinem Asset-Budget** (bei uns: Toon + Outline + Licht-Kodierung statt HD-2D); Schwächen aufdecken als Belohnung | 8 getrennte Geschichten, langsames Pacing |
| **Persona 5** | **UI als Marke** (Schrägschnitte, harte Kanten, TV-Look), Bindungsszenen zwischen Kämpfen (Mopsula-Szenen im Safe Room), Zeitdruck als Struktur | 100-h-Kalender, Schul-Simulation |
| **Slay the Spire** | lesbare Gegner-Absichten (CTB-Vorschau), kurze Läufe, datengetriebenes Balancing, **Early Access mit Community-Feedback**, Tages-Seeds | Deckbau, Permadeath in der Kampagne |
| **Darkest Dungeon** | **Erzählerstimme als Markenzeichen** (bei uns M.O.D.), Risiko/Belohnung-Druck, Early-Access-Erfolgsweg | Frust-RNG, Stress-Grind, düsterer Grundton |
| **Hades** | Erzählung, die mit jedem Lauf weiterläuft; Figuren reagieren auf Ereignisse; EA als Entwicklungsmodell | Echtzeit-Action |
| **Spiele mit Zuschauer-Integration** (z. B. Dead Cells' Twitch-Modus, Choice Chamber) | Chat stimmt über Ereignisse ab → Streams werden zu Inhalten | Zuschauer-Macht, die Spieler:innen bestraft |

Positionierungs-Satz (intern): **„FF10-Kampf trifft Reality-TV-Satire — in 20-Minuten-Etagen.“**
Abgrenzung zu DCC-nahen Erwartungen: **europäische TV-Satire** (Teleshopping, Bürokratie, „Hausordnung § 7“, U-Bahn, Kiosk 24/7)
statt amerikanischer Reality-Ästhetik — das ist zugleich Markenkern und rechtlicher Abstand (Kap. 2).

### 1.5 USPs

| # | USP | Warum es zählt | Beleg im Slice |
|---|---|---|---|
| U1 | **Show-System: Unterhaltung ist eine Ressource** | Kein anderes Runden-RPG belohnt *Abwechslung* systematisch; jede Runde eine echte Entscheidung (sicher vs. spektakulär) | Hype-Tabelle GDD 7.3, Sponsor-Geschenke GDD 7.4 |
| U2 | **Stunts** | riskante Spezialaktionen mit großem Hype — Clip-Material | GDD 3.6 |
| U3 | **Die Show ist das UI** | sofort erkennbare Screenshots (LIVE-Badge, Zuschauerzahl, Chat-Ticker) | ShowOverlay, 03_ART Kap. 9 |
| U4 | **M.O.D.** — sarkastische Moderations-KI | Stimme der Marke, kommentiert Achievements, Loot, Tode | `mod_lines.json` |
| U5 | **Graf Mopsula** | Maskottchen, Publikumsliebling, Merch-fähig | GDD 1.2, Safe-Room-Szenen |
| U6 | **Countdown-Etagen (20–25 min)** | Druck + kurze Sessions → ideal für Deck/Handy | Etagen-Timer GDD 2.9 |
| U7 | **SHOWRUN** — gleiche Seeds, Live-Fenster, Bestenlisten, Zuschauer-Votes | Wiederspielwert + Streamer-Inhalte, eingebaut statt aufgesetzt | 05_LIVE_MODUS, S0 im Slice |
| U8 | **Fair by design** | Satire auf Gacha-Kultur, die selbst kein Gacha ist: keine gekauften Zufallsinhalte für Spieler:innen | Brief Kap. 5 |

---

## 2. IP- & Rechtsstrategie

### 2.1 Grundsatz

**Entscheidung:** PRIME TIME DUNGEON ist und bleibt **eigene IP**. Wir übernehmen aus *Dungeon Crawler Carl* (Matt Dinniman)
ausschließlich **Genre-Ideen**, keine Ausdrucksformen. Ideen, Genres und Spielmechaniken sind nach allgemeinem Verständnis
nicht urheberrechtlich geschützt — konkrete Texte, Figuren mit ihren individuellen Zügen, Handlungsverläufe, Namen (marken-/
titelrechtlich) und Logos schon. **[Abgrenzung im Einzelfall anwaltlich zu prüfen]**

### 2.2 Was sicher übernommen werden darf vs. was tabu ist

| Kategorie | **Erlaubt (Genre-Konvention)** | **Tabu** |
|---|---|---|
| Prämisse | Dungeon als Medienspektakel; Kandidat:innen; Zuschauer und Sponsoren; Zeitdruck pro Etage | DCC-Handlungsverlauf, DCC-Weltgeschichte, Reihenfolge/Themen der DCC-Etagen |
| Systeme | Achievements mit Kommentar, Kisten als Belohnung, Safe Rooms, Etagen-Bosse, Klassenwahl, sprechende System-KI | 1:1-Nachbau benannter DCC-Systeme oder Regeltexte |
| Figuren | Haustier-Begleiter, arrogante Figuren, Moderator-KI als Archetypen | DCC-Figuren, ihre Namen, Biografien, Erkennungsmerkmale, Dialoge, Running Gags |
| Text | eigener Humor, eigene Sprüche | jedes Zitat, auch kurze Catchphrases; Kapitel-/Buchtitel |
| Marke | „LitRPG“, „Dungeon Crawler“ (Gattungsbegriffe) als Genre-Beschreibung | „Dungeon Crawler Carl“, Logos, Cover-Stil, Schriftzüge in Store, Werbung, Tags, Keywords |
| Marketing | „für Fans von LitRPG und Reality-Satire“ | „inspiriert von DCC“ auf Steam-Seite, in Anzeigen oder Keywords (wirkt wie Anlehnung an fremde Bekanntheit) — in Interviews darf man die Inspiration ehrlich nennen |

### 2.3 Distanz-Review (Pflicht vor dem ersten öffentlichen Auftritt)

Einzelne Ideen sind frei — aber die **Summe** mehrerer DCC-naher Elemente kann den Eindruck eines Abklatschs erzeugen
(Reputationsrisiko, im schlimmsten Fall Ansprüche z. B. wegen Nachahmung **[zu prüfen]**). Die folgenden Elemente aus dem Brief
sind in der Summe nah dran. Der Brief bleibt für den Slice unverändert; das Review ist **Exit-Kriterium von Phase 2**.
Umbenennungen kosten dank datengetriebenem Design (`res://data/*.json`, `mod_lines.json`) **unter 1 Arbeitstag**.

| Element (Brief/GDD) | Nähe | Vorschlag (Entscheidung durch dich) |
|---|---|---|
| **Fan-Box** (Lootbox-Stufe) | „Fan Box“ ist ein bekannter DCC-Begriff | → **„Fanpost-Paket“** (ID `box_fan` bleibt) |
| Bronze/Silber/Gold-**Box** | Medaillen-Stufen sind generisch, in Kombination mit „Box“ nah | → **„Requisitenkiste Bronze/Silber/Gold“** (IDs `box_bronze`/`box_silver`/`box_gold` bleiben) |
| **Quartier-Boss** | Stadtviertel-Boss-Hierarchie ist DCC-typisch | → **„Revier-Boss“** (Entscheidung; passt zur Bürokratie-Satire). IDs bleiben: Boss `enm_boss_hausmeister`, Raum-Typ `RoomCell.Kind.QUARTER_BOSS`, Encounter `enc_f1_boss_hausmeister` |
| **NOVA SYNDIKAT** | „Syndicate“ ist in DCC eine zentrale Instanz | → **„NOVA MEDIENGRUPPE“** / Kurzform **„NOVA“** (Palette-Token `NOVA_MAGENTA`/`NOVA_CYAN` bleiben) |
| Graf Mopsula | eitles, adelsbewusstes Haustier, wird Magier, Publikumsliebling — als *Archetyp* frei, aber Kombination nah | **behalten**, aber konsequent eigen ausprägen: Hund statt Katze, Tierheim-Biografie („schwer vermittelbar“), Pluralis Majestatis, Adels-Fehde mit der Rattenkönigin; **keine** Show-/Wettbewerbs-Vergangenheit, **kein Kronen-Motiv an Mopsula** (siehe nächste Zeile) |
| Kronen an Mopsula (Item + Optik) | „adliges Haustier mit Krone“ ist DCC-Archetyp-nah | **bereits im Slice umgesetzt, bindend:** Waffe heißt `itm_wpn_collar_signet` „Siegel-Halsband“ (Werte unverändert MAG +11, MP +10; ersetzt das frühere „Kronen-Halsband“). Optik-Signatur: **goldene Siegel-Plakette am Halsband (Torus + Box, Metall-Material M)**, **kein** `crown`-Prop am Mopsula-Rig. `itm_acc_queen_crown` „Rattenkrone“ hat `equip_by: ["kai"]` — Mopsula kann sie nicht tragen. Die Krone der Rattenkönigin (`ticket_crown`) bleibt: Sie ist die Gegenspielerin, deren Adelsanspruch Mopsula verspottet. |
| Erdoberfläche wird „zurückgebaut“ | Prämissen-Idee, frei — aber prominent | **behalten**, in Marketing nicht als Haupt-Hook nutzen; Hook ist das Show-System |
| Safe Room | Gattungsbegriff in Spielen | behalten (In-World-Name je Raum: „Kiosk 24/7“, „Pumpenhaus“, „Stellwerk“) |

**Regel für den Slice:** Die Anzeigenamen „Fan-Box“, „NOVA SYNDIKAT“ und „Quartier-Boss“ bleiben in Brief, GDD und ART
vorerst stehen (der Brief ist bindend). Alle IDs sind bewusst **neutral** (`box_fan`, `enm_boss_hausmeister`, `RoomCell.Kind.QUARTER_BOSS`,
keine Marken-IDs, 01_GDD §16 ID-Anhang). Die Umbenennungen aus E2 sind damit **reine Textänderungen** in `name`/`text`
(`res://data/*.json`, `mod_lines.json`) plus Brief-/GDD-Fließtext — keine Code-, Schema- oder Spielstand-Migration.
Neue Inhalte ab Phase 2 verwenden in Dialogen und Store-Texten bereits die Ersatznamen, wenn E2 entschieden ist.

Ergebnis des Reviews: Liste umbenannter Texte (IDs unverändert) + kurzes Anwalts-Memo „IP-Abstand“ (Budget 1 500–3 000 €, **Schätzung**).

### 2.4 Optionaler Lizenzpfad (DCC)

**Bekannte Fakten (konservativ, Stand jeweils [zu prüfen]):**
- *Dungeon Crawler Carl* stammt von **Matt Dinniman**, erschien ursprünglich als Web-Serie und wurde über Hörbücher (Soundbooth Theater) und Neuauflagen bei einem großen Verlag sehr erfolgreich. **[Verlag/Rechtekette zu prüfen]**
- **Renegade Game Studios** hält eine **Tabletop-Lizenz** (Rollenspiel). **[Umfang zu prüfen]**
- Eine **TV-Adaption** ist öffentlich angekündigt und in Entwicklung. **[beteiligte Studios/Sender und Stand zu prüfen]**
- **Ob Videospielrechte bereits vergeben oder an den TV-Deal gebunden sind, ist unbekannt. [zu prüfen — entscheidend]**

**Entscheidung:** Der Lizenz-Track wird nur aktiviert, wenn **alle drei** Bedingungen erfüllt sind:
1. Phase 3 ist erreicht (Demo **mit Art-Upgrade**, nicht mit Primitiv-Optik),
2. ≥ **10 000 Wishlists** auf der Steam-Seite der eigenen IP,
3. Recherche ergibt, dass Videospielrechte überhaupt verfügbar sind.

**Vorgehen (Schritt für Schritt):**

| # | Schritt | Detail |
|---|---|---|
| 1 | Rechte-Recherche | offizielle Kontaktangaben des Autors (Website), Literaturagentur, Verlag; Branchenmeldungen zu Spielelizenzen **[zu prüfen]** |
| 2 | Kurzanfrage (Query) | **nur über Agentur/offiziellen Rechtekontakt**, nie per Social-DM oder Fan-Kanälen; 1 Seite: wer wir sind, Link zur eigenen Steam-Seite, Frage nach Verfügbarkeit von Game-Rechten. **Keine ungefragten Story-Ideen** (Autor:innen lehnen unverlangte Ideen meist ab, um Ideenklau-Vorwürfe zu vermeiden) |
| 3 | NDA | erst nach positiver Antwort; dann Build + Deck |
| 4 | Pitch-Paket | Deck (unten), 3-min-Gameplay-Video, spielbarer Build, Budget/Zeitplan, Vorschlag zur Werktreue und zu Freigabeprozessen |
| 5 | Konditionen | übliche Struktur: Vorschuss (Advance) + Umsatzbeteiligung, Freigaberechte, Laufzeit, Territorien, Plattformen **[Größenordnung mit Anwalt/Agent klären]** |
| 6 | Entscheidung | Lizenz nur, wenn (a) die eigene IP weiterentwickelt werden darf und nichts „infiziert“ wird (getrennte Codebasis-Branches, getrennte Texte), (b) Finanzierung des Lizenz-Projekts gesichert ist |

**Pitch-Deck (12 Folien):** 1 Titel + Key Art · 2 One-Liner & Fantasy · 3 Gameplay-Loop (Diagramm) · 4 Warum das Show-System die
Vorlage im Spiel *fühlbar* macht · 5 Kampf (GIF) · 6 Art-Stil · 7 Werktreue-Plan (wie Figuren/Ton geschützt werden, Freigaben) ·
8 Team & bisherige Ergebnisse (Wishlists, Playtest-KPIs, Next-Fest-Daten) · 9 Plattformen & Zeitplan · 10 Budget & Finanzierung ·
11 Geschäftsmodell (Premium, keine Lootboxen) · 12 Ask (was wir wollen, was wir bieten).

### 2.5 Markenrecherche für unseren Titel

**Risiko:** „PRIME“ ist als Markenbestandteil im Medien-/Gaming-Bereich stark besetzt (u. a. durch große Streaming-/Handels-
konzerne). Ein Konflikt mit „PRIME TIME DUNGEON“ ist möglich. **[zu prüfen]**

| Schritt | Wann | Wo | Kosten (**Schätzung**, Gebühren [zu prüfen]) |
|---|---|---|---|
| Eigen-Recherche Identität/Ähnlichkeit | Phase 2 | DPMAregister, EUIPO eSearch / TMview, WIPO Global Brand Database, USPTO; Steam/App-Store-Suche; Domains, Social-Handles | 0 € |
| Professionelle Ähnlichkeitsrecherche | Ende Phase 2 | Markenanwalt/Recherchedienst | 500–1 500 € |
| Anmeldung | Start Phase 3, **vor** Steam-Seite | EU-Marke (EUIPO) Klassen **9** (Software), **41** (Unterhaltung/Online-Spiele), optional **28**/**25** (Merch) | EUIPO-Grundgebühr ca. 850 € (1 Klasse), +50 € (2.), +150 € je weitere **[Stand prüfen]**; Anwalt 800–2 000 € |
| Weitere Titel/Marken | Phase 3 | „M.O.D.“ (schwach, beschreibend), **„Graf Mopsula“** (stark, Merch-relevant) | wie oben |

**Fallback-Titel** (falls „PRIME“ kollidiert), in dieser Reihenfolge: **„RATINGS DUNGEON“**, **„DUNGEON LIVE!“**, **„SENDESCHLUSS“** (DE-Marke, international schwächer).
Entscheidung über den finalen Titel: **spätestens bei Exit Phase 2**.

### 2.6 Lootbox-Regulierung & warum wir keine Echtgeld-Boxen an Spieler:innen verkaufen

| Markt/Regelwerk | Stand nach unserem Kenntnisstand | Folge für uns |
|---|---|---|
| **Belgien** | Bezahlte Lootboxen werden von der Glücksspielbehörde seit 2018 als Glücksspiel eingeordnet **[zu prüfen]** | Keine kaufbaren Zufallsinhalte; Live-Modus-Sponsorkisten dort geo-gesperrt (05 L7) |
| **Niederlande** | Behörde 2018 kritisch; Gerichtsurteil 2022 zugunsten eines Publishers; politische Verbotsdebatte **[zu prüfen]** | wie Belgien behandeln, bis Gutachten vorliegt |
| **Deutschland** | JuSchG-Novelle (2021): Alterskennzeichnung berücksichtigt „Nutzungsrisiken“ wie In-Game-Käufe und Lootboxen; USK wendet das seit 2023 an **[zu prüfen]** | Echtgeld-Zufall würde Freigabe/Zusatzhinweise verschlechtern → Zielgruppe schrumpft |
| **PEGI** | Zusatzhinweis „In-Game-Käufe (enthält zufällige Objekte)“ **[zu prüfen]** | wollen wir für das Grundspiel nicht |
| **Apple / Google** | Wahrscheinlichkeiten müssen vor dem Kauf offengelegt werden **[zu prüfen]** | betrifft uns nur in Phase 7 |
| **EU-Verbraucherschutz** | Grundsätze zu virtuellen Währungen (Preisangabe in Echtgeld, keine Verschleierung) **[zu prüfen]** | relevant nur für Sponsor-Token (05 Kap. 8) |

**Warum keine Echtgeld-Boxen für Spieler:innen (Brief Kap. 5, verbindlich):**
1. **Marke:** Das Spiel ist Satire auf Gacha-/Werbekultur. Selbst Gacha zu verkaufen zerstört die Pointe und die Glaubwürdigkeit.
2. **Recht:** Länder-Flickenteppich, Gutachten, Geo-Sperren, Altersprüfung — für ein Indie-Team Kosten ohne Gegenwert.
3. **Freigabe:** USK/PEGI-Zusatzhinweise und ggf. höhere Altersstufe → kleinere Zielgruppe, schlechtere Store-Platzierung.
4. **Plattform-Reviews:** Apple/Google prüfen Zufallskäufe streng; Steam-Reviews strafen Monetarisierung im Premium-Spiel ab.
5. **Design:** Lootboxen im Spiel sind **Belohnungen** (Achievements, Bosse) — ihr Wert entsteht durch Verdienen, nicht Kaufen.

**Abgrenzung zur Brief-Entscheidung „Zuschauer-Geschenke mit Echtgeld“:** Die Sponsorkisten des Live-Modus (05 Kap. 6/8) sind ein
**separates System** (nur Live-Modus, nur von Zuschauer:innen an andere, lauf-gebunden, Odds, Pity, Caps, 18+, Geo-Sperre, Pur-Liga).
Strategische Einordnung: **Phase 7, Stufe S3/S5, nur nach schriftlicher Rechtsprüfung** (05 L10). Kein Umsatz daraus ist im Budget eingeplant.
Seit der Entscheidung 2026-10-08 fließt dieser Umsatz ausschließlich an den Betreiber (eigener Shop C, 05 Kap. 8); eine
Creator-Beteiligung ist gestrichen, Twitch Bits tragen kein Echtgeld-Geschenk (nur kostenlose Votes/Applaus).

### 2.7 Weitere Rechtsbausteine (Checkliste)

| Thema | Wann | Maßnahme |
|---|---|---|
| Firmengründung | Start Phase 3 | **UG (haftungsbeschränkt)**, später GmbH; Voraussetzung für viele Förderungen und Publisher-Verträge **[zu prüfen]** |
| IP-Kette | ab erstem Freelancer | Verträge mit **ausschließlichen, zeitlich/räumlich unbeschränkten Nutzungsrechten** an Code, Art, Musik, Texten, Stimme (in DE ist Urheberrecht selbst nicht übertragbar, nur Nutzungsrechte) **[zu prüfen]**; alles bisher Erstellte per Vertrag in die Firma einbringen |
| KI-generierte Inhalte | laufend | Code/Tests/Tools KI-gestützt — ok. **Finale** Grafik, Musik, Stimmen von Menschen (Schutzfähigkeit KI-generierter Werke unsicher **[zu prüfen]**; Plattform-Offenlegung Kap. 8.3) |
| Open-Source-Lizenzen | laufend | Godot (MIT) → Lizenzhinweis in Credits/„Rechtliches“-Menü; jede weitere Bibliothek in `THIRD_PARTY.md` erfassen |
| Datenschutz | ab Phase 5 (Telemetrie/Accounts) | Slice/EA ohne Tracking; Opt-in-Crash-Reports; DSGVO-Paket erst mit SHOWRUN S1 (05 Kap. 9) |
| Impressum/AGB/Datenschutzerklärung | vor Steam-Seite bzw. Website | Website mit Impressum (DE-Pflicht), Datenschutzerklärung; AGB erst bei eigenem Shop |

---

## 3. Phasenplan 0–7

### 3.1 Übersicht (Baseline-Szenario B: Solo + KI bis Phase 2, danach Team 4–5)

| Phase | Name | Zeitraum (Baseline) | Dauer | Ergebnis (Meilenstein) |
|---|---|---|---|---|
| **0** | Konzept / Brief | Sep – Okt 2026 | ✔ erledigt | Docs 00–05 |
| **1** | Prototyp (Grey Box) | Okt – Nov 2026 | 2–4 Wochen | **M-P1:** durchlaufender Loop Erkunden ⇄ Kampf ⇄ Safe Room, `AUTOPLAY: OK` |
| **2** | Vertical Slice | Nov 2026 – Feb 2027 | 10–12 Wochen | **M-P2:** Etage 1 komplett, extern getestet, Go/No-Go |
| **3** | Pre-Production | Mär – Aug 2027 | 6 Monate | **M-P3:** Art-Upgrade, Pipeline, Steam-Seite, Finanzierung, Team |
| **4** | Production (bis EA) | Sep 2027 – Apr 2028 | 8 Monate | **M-P4:** Etagen 1–3 EA-fertig, Next-Fest-Demo |
| **5** | Early Access PC | Mai 2028 – Mai 2029 | 12 Monate | **M-P5:** Etagen 4–6, Klassen, **1.0 PC** |
| **6** | Mobile-Port & Launch | Nov 2028 – Aug 2029 | 9 Monate (parallel zu 5) | **M-P6:** Android + iOS Launch |
| **7** | Live-Ops / Updates | ab Mai 2028 fortlaufend | — | SHOWRUN S1–S5, Staffel 2 (Etagen 7–9) 2030 |

Termine mit Steam Next Fest (in der Regel Februar, Juni, Oktober) **[Termine je Jahr in Steamworks prüfen]**.
Dauer-Faktoren: Szenario A (Solo + KI durchgehend) **× 1,8**; Szenario C (Team 8–12) **× 0,7** bei größerem Umfang (Etagen 1–9 bis 1.0).

```
2026 Q4 | P1 ██ P2 ████
2027 Q1 | P2 ██ | P3 ██
2027 Q2 | P3 ██████
2027 Q3 | P3 ██ | P4 ████
2027 Q4 | P4 ██████
2028 Q1 | P4 ██████   (Demo Jan, Next Fest Feb)
2028 Q2 | P4 █ | EA-Launch Mai | P5 ████
2028 Q3 | P5 ██████   Update 1: Etage 4
2028 Q4 | P5 ██████   Update 2: Klassen + Etage 5 + Streamer-Modus | P6 Start
2029 Q1 | P5 ██████   Update 3: Etage 6 | P6 Soft-Launch Android
2029 Q2 | 1.0 PC (Mai) | P6 ████
2029 Q3 | P6 Launch Android + iOS | P7
2030    | P7: Staffel 2 (Etagen 7–9), SHOWRUN S2–S4
```

### 3.2 Phase 0 — Konzept / Brief ✔

| | |
|---|---|
| **Ergebnis** | `00_BRIEF.md` (verbindlich), `01_GDD.md`, `02_TECH.md`, `03_ART.md`, `04_STRATEGIE_ROADMAP.md`, `05_LIVE_MODUS.md`, `tools/check.sh` |
| **DoD** | Alle Systeme des Slice haben Zahlen, Datenfelder, Dateibesitzer; Architekturverträge (Autoloads, Ordner, Modul-APIs) festgelegt; Godot-APIs gegen 4.7.2 geprüft |
| **Erledigt** | Änderungsanträge CR-1…CR-15 aus 05 Kap. 11.6 sind in `02_TECH.md` eingearbeitet und umgesetzt (Schritt 1 in Kap. 10) |

### 3.3 Phase 1 — Prototyp (Grey Box) — 2–4 Wochen

**Ziel:** Beweisen, dass der Kern-Loop technisch durchläuft und der **CTB-Kampf mit Hype** sich gut anfühlt — Optik egal.

| Was wird gebaut | Details |
|---|---|
| M0 Fundament | `project.godot`, 7 Autoloads, `GameData` + Validator, `SeedUtil`, Test-Runner, Capture, UI-Theme, alle Stubs |
| M1 Kampf-Kern | CTB-Queue, Formeln, Status, KI, `ActionEvent`s — headless |
| M2 Show-Kern | Hype/Zuschauer/Follower, Sponsor-Trigger, Achievements, Loot, Save |
| M3 Erkundung | Etage 1 aus Raster + Seed, Spieler, Gegner-Symbole, Encounter |
| M5/M6 minimal | Kampf-HUD mit CTB-Leiste, Titel → Erkundung → Kampf → Safe Room |
| M4 | Primitiv-Platzhalter reichen (Kapseln/Boxen mit Toon-Shader) |

| | |
|---|---|
| **Deliverables** | Build (Linux/Windows), `tools/check.sh` grün, 7 Screenshots |
| **DoD / Exit** | (1) `AUTOPLAY: OK` (Schritte 1–7 aus 02_TECH §11.4). (2) M1: 100 Seeds Auto-vs-Auto terminieren < 200 Züge. (3) M3: 200 Seeds erfüllen Invarianten. (4) **5 Testpersonen** spielen 3 Kämpfe: Median „Kampf macht Spaß“ ≥ **3,5/5**, mindestens 3 von 5 verstehen ohne Erklärung, dass Abwechslung Hype bringt. |
| **Wer** | Du (Produkt-Entscheidungen, Testpersonen organisieren) + Claude (Code, Tests, Integration) |
| **KI-gestützt** | ~95 % des Codes, alle Tests, Datensätze, Balancing-Simulation |
| **Menschen nötig** | Spielgefühl beurteilen, Testpersonen, Entscheidungen bei Zielkonflikten |
| **Kosten** | ~0 € extern (KI-Abo **[Preis prüfen]**) |

### 3.4 Phase 2 — Vertical Slice (Ziel dieses Repos) — 10–12 Wochen

**Ziel:** Etage 1 **komplett und poliert** spielbar (Brief Kap. 7): Titel → Intro → Etage 1 → ≥ 3 Kämpfe → Achievements/Lootboxen →
Safe Room (Speichern, Automat) → Hausmeister → Treppe/Rattenkönigin → „Etage 2 folgt“. Plus SHOWRUN S0 (Offline-Event-Lauf).

| Was wird gebaut | Details |
|---|---|
| Alle Module M0–M7 vollständig | inkl. M4 Art-Kit (Toon, Outline, Rim, prozedurale Figuren, Umgebung, VFX), M6 alle UI-Szenen inkl. Touch-Layer, M7 alle Inhalte Etage 1 (10+1 Gegner, 2 Bosse, 29 Achievements, M.O.D.-Zeilen) |
| SHOWRUN-Hooks (M8) | Run-Log, Quest-Tracker, lokale Bestenliste, `Show.receive_gift` (05 Kap. 11) |
| Platzhalter-Audio | prozedurale SFX (`Sfx`), keine Musik nötig |
| Playtest-Paket | Build + Fragebogen + Telemetrie-frei (Beobachtung/Interview) |

| | |
|---|---|
| **Deliverables** | Slice-Build Windows/Linux (+ Android-Debug-APK), Gameplay-Video 2–3 min, 20 Screenshots, Playtest-Bericht, Distanz-Review (Kap. 2.3), Titel-Entscheidung (Kap. 2.5) |
| **DoD / Exit** | (1) Integrations-Checkliste 02_TECH §14 vollständig. (2) Performance-Budgets 02_TECH §12.1 auf PC (iGPU) und 1 Android-Mittelklassegerät. (3) **15 externe Testpersonen** (nicht Freunde/Familie, Zielgruppe): ≥ **70 %** erreichen den Hausmeister, Median-Spielzeit **22–28 min**, ≥ **60 %** „würde weiterspielen“ (Top-2-Box), ≥ **50 %** nennen ungefragt Show-System, M.O.D. oder Mopsula als Highlight, **0** Crashes in 20 Durchläufen. (4) Distanz-Review abgeschlossen. |
| **Go/No-Go** | **Go** wenn ≥ 3 der 4 Playtest-Zahlen erreicht. **Iterieren** (max. 6 Wochen) wenn 2. **Stop/Pivot** wenn ≤ 1 → Lessons Learned, Konzept überarbeiten, keine Investition in Phase 3. |
| **Wer** | Du + Claude; optional 1 Freelance-Testleiter:in (UX-Research) für die Playtests |
| **KI-gestützt** | Code, Tests, Inhalte als Entwurf (M.O.D.-Zeilen, Achievement-Texte), Balancing-Simulation (50 Seeds × alle Encounter) |
| **Menschen nötig** | **Humor-Redaktion** der M.O.D./Mopsula-Texte (du oder Autor:in), Playtests, Spielgefühl, Distanz-Review, Markenrecherche |
| **Kosten** | 0–3 000 € (Testpersonen-Gutscheine 15 × 20 €, Anwalt Markenvorprüfung, Android-Testgerät) |

### 3.5 Phase 3 — Pre-Production — 6 Monate

**Ziel:** Aus dem Slice eine **produktionsreife Maschine** machen: finale Optik-Richtung, Pipelines, Werkzeuge, Firma, Geld, Team, Steam-Seite.

| Arbeitspaket | Inhalt | Ergebnis |
|---|---|---|
| **Art-Upgrade** | Blender → glTF nach 03_ART Kap. 10: Kai, Mopsula, M.O.D., 6 Gegner Etage 1, Hausmeister; Post-Import-Skript; Key Art | Figuren **ersetzen Kit-Rezepte ohne Code-Änderung**; Steam-Kapselbilder |
| **Umgebungs-Upgrade** | Modulteile Etage 1 als `.glb` (Wände, Säulen, Props) | gleiche MultiMesh-Pipeline |
| **Audio** | Komponist:in: Haupt-Thema, Erkundung, Kampf, Boss, Safe Room (5 Tracks); SFX-Grundbibliothek | Musik-Bus, Ducking unter M.O.D. |
| **Tools** | (1) Etagen-Editor (Godot-`@tool`-Szene für `floors.json`), (2) Balancing-Simulator als CLI (`godot --headless -s tools/sim_balance.gd`) mit CSV-Ausgabe, (3) Text-Pipeline: alle Strings → CSV/PO für Übersetzung, (4) Crash-Report (Opt-in) | Content-Durchsatz 1 Etage / 8–10 Wochen |
| **Content-Prototypen** | Etage 2 (Grey Box, 3 Gegner, Boss „Der Ausverkauf“), Etage 3 mit **Klassenwahl** (Datenmodell steht bereits) | Beweis, dass die Pipeline skaliert |
| **Business** | UG gründen, Markenanmeldung, Förderanträge, Publisher-Pitches, Steam-Seite (Monat 1), Discord, Website | Finanzierung für Phase 4–5 gesichert |
| **Team** | Hiring nach Kap. 4 | Team ab Phase 4 vollständig |

| | |
|---|---|
| **Deliverables** | Slice v2 mit Art-Upgrade („Demo-Kandidat“), Steam-Seite live, Pitch-Deck, Trailer #1 (60–90 s), Produktionsplan Etagen 1–6 (Backlog mit Schätzungen), Finanzierungszusage(n) |
| **DoD / Exit** | (1) Art-Upgrade-Figuren laufen in **beiden** Renderern (mobile + gl_compatibility) innerhalb der Budgets 03_ART Kap. 11. (2) Etage 2 in Grey Box in **≤ 4 Wochen** gebaut (Pipeline-Beweis). (3) **≥ 3 000 Wishlists** 3 Monate nach Seitenstart. (4) Finanzierung für ≥ 12 Monate Team-Kosten zugesagt **oder** bewusste Entscheidung für Szenario A. (5) Markenanmeldung eingereicht. |
| **Wer** | Du (Produzent:in/Business), Claude (Tools, Code, Pipeline), Freelance: 3D-Character-Artist, Environment-Artist (Teilzeit), Komponist:in, Trailer-Cutter:in |
| **KI-gestützt** | Tools, Importskripte, Pitch-Texte (Entwurf), Förderantrags-Struktur, Datenmigration, Shader-Feinschliff |
| **Menschen nötig** | 3D-Modelle/Animation (final), Musik, Key Art, Business-Verhandlungen, Förderberatung, Anwalt |
| **Kosten (Baseline)** | 45 000–90 000 € (Kap. 4) |

### 3.6 Phase 4 — Production (bis Early Access) — 8 Monate

**Ziel:** **Etagen 1–3** in Release-Qualität + Meta-Systeme + Next-Fest-Demo → EA-Launch.

| Arbeitspaket | Inhalt |
|---|---|
| Inhalte | Etage 1 (final), Etage 2 „Passage Ewiger Rabatt“, Etage 3 (Thema in Phase 3 festgelegt) inkl. **Klassenwahl** (Safe-Room-Event „Casting“, **4 Klassen je Figur**, 8 Einträge in `classes.json` gemäß 02_TECH §4.4.4 / 01_GDD §12; dazu je Klasse 4 Skills L11–L17 als `skl_<kai|mop>_<name>` in `learnset`), je Etage: 8–10 Gegner, 1 Zwischenboss (Raum-Typ `RoomCell.Kind.QUARTER_BOSS`, Anzeigename nach E2 „Revier-Boss“), 1 Etagenboss, 25–30 Achievements, 3 Safe Rooms, 2 Mopsula-Szenen |
| Systeme | Klassen, Ausrüstungs-Tiers, Etagen-Bilanz, Optionen/Barrierefreiheit (Textgröße, Farbenblind-Paletten, Kampfgeschwindigkeit, Timer-Modus „entspannt“ ohne Countdown-Tod) |
| SHOWRUN | S0 poliert (Offline-Event-Läufe, 5 kuratierte Seeds), Vorbereitung S1 (Accounts **nicht** vor EA) |
| Lokalisierung | DE (Original) + **EN** (professionelle Übersetzung + Humor-Adaption, nicht wörtlich) |
| Audio | 12–15 Tracks, M.O.D. als „Blip-Stimme“ (gesprochene Silben-Synthese) + Text; volle Vertonung erst 1.0 |
| Steam | Demo (Etage 1) im Januar, **Next Fest** Februar, Store-Seite final, EA-FAQ |

| | |
|---|---|
| **Deliverables** | EA-Build 0.5 (Win/Linux, **Steam Deck verified-Ziel**), Demo, Trailer #2 (Gameplay), Pressekit, Roadmap-Grafik für die Steam-Seite |
| **DoD / Exit (EA-Readiness)** | (1) Etagen 1–3 durchspielbar, ~**3–4 h** Erstdurchlauf. (2) Crash-frei in 50 Bot-Läufen (Autoplay erweitert auf alle Etagen) und 20 menschlichen Läufen. (3) Demo-KPIs Next Fest: Median-Spielzeit ≥ **30 min**, ≥ **5 000** neue Wishlists während des Fests. (4) **≥ 15 000 Wishlists** vor Launch — **sonst Launch um 3 Monate verschieben** und Marketing nachschärfen. (5) Externer QA-Pass (Funktion + Kompatibilität: 3 GPUs, Steam Deck). |
| **Wer** | Team (Kap. 4): Lead Dev (Claude-gestützt), Gameplay/Content-Designer:in, 3D-Artist, Tech-Artist/Animator (Teilzeit), Autor:in (Teilzeit), Producer/Community (du) + Freelance Audio, Übersetzung, QA |
| **KI-gestützt** | Code, Tests, Content-Daten (Gegner-/Item-Tabellen nach Design-Vorgaben), Balancing-Läufe, Text-Entwürfe, Lokalisierungs-Vorprüfung (Länge, Platzhalter, Konsistenz) |
| **Menschen nötig** | Design-Entscheidungen, finale Texte & Witz, Art & Animation, Musik, Übersetzung, QA, Community |

### 3.7 Phase 5 — Early Access PC — 12 Monate

**Ziel:** Mit der Community zur 1.0. Update-Takt **alle 8–10 Wochen**, Hotfixes innerhalb 72 h.

| Update | Termin (Baseline) | Inhalt |
|---|---|---|
| EA-Launch 0.5 | Mai 2028 | Etagen 1–3, Klassen, SHOWRUN S0 |
| Update 1 (0.6) | Jul/Aug 2028 | **Etage 4**, Community-Wünsche (QoL), Balancing |
| Update 2 (0.7) | Okt/Nov 2028 | **Etage 5**, **Streamer-Modus lite** (Twitch-Chat-Votes lokal im Client, ohne eigenen Server, ohne Geld), SHOWRUN **S1** (Tages-Seed + Online-Bestenliste) |
| Update 3 (0.8) | Feb 2029 | **Etage 6** + Staffel-Finale, Vertonung M.O.D. (DE + EN) |
| 1.0 | Mai 2029 | Polish, 5 weitere Sprachen, Achievements Steam, Cloud-Saves, Preis 19,99 € |

| | |
|---|---|
| **DoD / Exit (1.0)** | (1) Etagen 1–6, ~**10–12 h** Erstdurchlauf. (2) Steam-Reviews ≥ **85 % positiv** (≥ 300 Reviews). (3) Refund-Quote < **8 %**. (4) Alle kritischen Bugs (Crash/Save-Verlust) = 0 offen. (5) Lokalisierung DE, EN, FR, ES, PT-BR, JA, ZH-Hans abgenommen (Native-Review). |
| **Wer** | Team wie Phase 4 + Community-Manager:in (Teilzeit), Sprecher:innen M.O.D. (DE/EN), Übersetzungsbüro |
| **KI-gestützt** | Bug-Triage aus Reports, Repro-Tests, Patch-Notes-Entwürfe, Balancing-Analyse aus Opt-in-Statistiken |
| **Menschen nötig** | Community-Kommunikation (Ton!), Priorisierung, Sprecher:innen, Native-Übersetzung |

### 3.8 Phase 6 — Mobile-Port & Launch — 9 Monate (parallel zu Phase 5)

| Schritt | Zeitraum | Inhalt |
|---|---|---|
| Tech-Port | Nov 2028 – Jan 2029 | Touch-UX final (virtueller Stick, Kampfmenü daumengerecht), Safe Areas, Akku/Temperatur (30-FPS-Modus), Speicherstände bei App-Wechsel, Store-SDKs (nur Kauf-Unlock), iOS-Export via Xcode |
| Soft-Launch | Feb – Apr 2029 | **Android** geschlossener/offener Test (Pflicht-Testphase für neue Entwicklerkonten **[zu prüfen]**), 2 Testmärkte; iOS TestFlight |
| Launch | Jul/Aug 2029 (nach PC 1.0) | Android + iOS weltweit, **Free-Demo (Etage 1 + Event-Lauf) + Vollversion 9,99 €** |

| | |
|---|---|
| **DoD / Exit** | (1) 60 FPS auf Zielgeräten (02_TECH §12.1), 30 FPS-Minimum im Compatibility-Fallback. (2) Crash-freie Sessions ≥ **99,5 %**. (3) Demo-D1-Retention ≥ **35 %**, Unlock-Conversion ≥ **5 %** der Demo-Installationen (Soft-Launch). (4) Store-Bewertung ≥ **4,3**. |
| **Wer** | Lead Dev + 1 Mobile-erfahrene:r Dev (Freelance, 4–6 Monate), QA mit Gerätepark (≥ 8 Geräte) |
| **KI-gestützt** | Touch-UI-Anpassungen, Performance-Analyse, Store-Texte (Entwurf), Screenshot-Automatisierung |
| **Menschen nötig** | Gerätetests in der Hand, Store-Assets, Store-Kommunikation, Datenschutzangaben |

### 3.9 Phase 7 — Live-Ops / Updates — ab EA fortlaufend

| Strang | Inhalt | Gate |
|---|---|---|
| **Staffel 2** | Etagen 7–9 als bezahlte Erweiterung (2030) | 1.0 ≥ 85 % positiv, Umsatz deckt ≥ 9 Monate Team |
| **SHOWRUN S2** | Live-Zuschauen, Votes, kostenlose Fan-Währung „Applaus“ | S1 stabil (0 Desyncs in 1 000 Bot-Läufen) |
| **SHOWRUN S3/S5** | Echtgeld-Zuschauergeschenke über den **eigenen Shop** (S3 Web-Shop, S5 App-Store-IAP), nur in Sponsor-Fenstern; Twitch nur kostenlos (Entscheidung 2026-10-08) | **schriftliche Rechtsprüfung** für alle Zielländer (05 L10), Store-Regeln für Geschenke an Dritte geklärt **[zu prüfen]**, Betriebsteam für Support/Zahlungen vorhanden |
| **SHOWRUN S4** | Koop 2–4 (Dedicated Server) | Netcode-Prototyp, Budget für Server-Betrieb |
| **Konsolen** | Switch 2 / PlayStation / Xbox — Godot-Konsolenports nur über spezialisierte Portierungspartner **[zu prüfen]** | 1.0-Erfolg, Publisher oder Porting-Partner trägt Kosten |
| **Saisonale Events** | Event-Läufe mit festen Seeds (S0/S1), kosmetische Belohnungen | Datenformat `events.json` |

### 3.10 KI-gestützt vs. Mensch — Gesamtsicht

| Bereich | KI (Claude) übernimmt | Mensch entscheidet/liefert |
|---|---|---|
| Code & Architektur | Implementierung, Refactoring, Tests, CI, Tools, Performance-Analyse | Architektur-Freigaben, Prioritäten |
| Game Design | Datentabellen, Balancing-Simulation, Varianten-Vorschläge | **Spielgefühl**, Schwierigkeit, Ton |
| Texte | Entwürfe, Konsistenzprüfung, Platzhalter, Längenprüfung für Lokalisierung | **finaler Witz**, Figurenstimme, Übersetzung |
| Art | prozedurale Platzhalter, Shader, Import-Pipeline, Budget-Checks | **finale Modelle, Animation, Key Art** |
| Audio | prozedurale Platzhalter-SFX | **Musik, Sprachaufnahmen, finale SFX** |
| QA | Headless-Tests, Autoplay-Bots, Screenshot-Vergleich | Spieltests, Gerätetests, Barrierefreiheit |
| Business | Entwürfe für Pitch, Förderanträge, Store-Texte | Verträge, Verhandlungen, Recht, Steuern |

**Entscheidung:** Keine KI-generierten Bilder, Musik oder Stimmen im ausgelieferten Spiel. Gründe: unsichere Schutzfähigkeit,
Community-Akzeptanz, Steam-Offenlegung, Qualität der Marke. KI-Code ist unkritisch und wird auf Steam wahrheitsgemäß angegeben, falls der Fragebogen es verlangt **[zu prüfen]**.

---

## 4. Team- & Budget-Szenarien

Alle Beträge sind **Schätzungen** in EUR, Personalkosten als **Arbeitgeber-Brutto** (Gehalt + ca. 21 % Lohnnebenkosten) bzw.
Freelance-Tagessätze; Lebenshaltung der Gründer:in nur in Szenario A separat ausgewiesen. Zeitraum: ab heute bis 1.0 PC.

### 4.1 Szenario A — Solo + KI (+ Freelancer)

| | |
|---|---|
| **Team** | 1 Person (du: Produzent:in, Design, Community) + Claude (Code/Tests/Tools) + Freelancer punktuell |
| **Zeit bis EA / 1.0** | **~24 Monate** bis EA (Etagen 1–3), **~40 Monate** bis 1.0 (Etagen 1–6) |
| **Umfang-Kürzung** | Mobile erst nach 1.0, M.O.D.-Vertonung nur EN oder Blip-Stimme, 3 statt 7 Sprachen zu 1.0, keine SHOWRUN-Serverstufen |

| Kostenposten | Betrag |
|---|---|
| KI-Abos/API (40 Monate) | 6 000–16 000 € **[Preise prüfen]** |
| 3D-Character/Env-Art (Freelance, Etagen 1–6) | 25 000–45 000 € |
| Musik (15 Tracks) + SFX | 8 000–16 000 € |
| Übersetzung EN + 2 Sprachen | 8 000–15 000 € |
| Recht (Marke, IP-Memo, Verträge), Steuerberatung | 6 000–12 000 € |
| Marketing (Trailer, Messen, Anzeigen-Tests) | 5 000–15 000 € |
| Hardware, Testgeräte, Gebühren (Steam, Stores) | 2 000–4 000 € |
| **Summe Cash** | **60 000–123 000 €** |
| Lebenshaltung Gründer:in (40 × 2 500 €) | +100 000 € |
| **Gesamt inkl. Lebenshaltung** | **~160 000–225 000 €** |

Risiko: Bus-Faktor 1, Burnout, langsame Content-Produktion. Geeignet, wenn keine Finanzierung zustande kommt.

### 4.2 Szenario B — Kleines Indie-Team (4–5) — **Baseline / Empfehlung**

| Rolle | FTE | Ab Phase | Monate (bis 1.0) |
|---|---|---|---|
| Producer/Creative Director (du) | 1,0 | 3 | 27 |
| Lead Developer (Godot, nutzt Claude intensiv) | 1,0 | 3 | 27 |
| Game/Content Designer:in (Kampf, Balancing, Etagen) | 1,0 | 3 (Mitte) | 24 |
| 3D-Artist (Figuren + Umgebung, Blender) | 1,0 | 3 | 27 |
| Tech-Artist/Animator:in | 0,5 | 4 | 20 |
| Autor:in/Narrative (Humor, M.O.D.) | 0,5 | 3 (Mitte) | 24 |
| Community/Marketing | 0,5 | 4 | 20 |
| Freelance: Musik, SFX, Sprecher:innen, Übersetzung, QA, Mobile-Dev | — | 3–6 | — |

| Kostenposten | Betrag |
|---|---|
| Personal (≈ 5,5 FTE-Ø × ~24 Monate × ~5 500 € AG-Brutto) | 600 000–750 000 € |
| Freelance (Musik 25k, Sprecher DE/EN 20k, Übersetzung 7 Sprachen 45k, QA 25k, Mobile-Dev 40k) | 120 000–170 000 € |
| Marketing (Trailer, Messen, PR, Anzeigen, Next Fest) | 50 000–90 000 € |
| Recht/Steuern/Gründung | 15 000–30 000 € |
| Software, Hardware, Gerätepark, Server (S1) | 15 000–30 000 € |
| Puffer 15 % | 120 000–160 000 € |
| **Summe bis 1.0 PC + Mobile** | **~0,9–1,2 Mio. €** |

Szenario B ist die **Baseline des Phasenplans** (Kap. 3.1).

### 4.3 Szenario C — Finanziertes Team (8–12)

| Rolle | FTE |
|---|---|
| Creative Director, Producer | 2 |
| Developer (Gameplay, Tools, Mobile, Online/Backend für SHOWRUN S1–S4) | 3–4 |
| Game Designer:innen (System, Content/Level) | 2 |
| 3D-Artists (Character, Environment), Tech-Artist, Animator:in | 3 |
| Narrative/Autor:in, Community/Marketing, QA | 2–3 (teilweise Teilzeit) |

| | |
|---|---|
| **Zeit** | EA nach ~**16 Monaten** mit Etagen 1–4, 1.0 nach ~**30 Monaten** mit **Etagen 1–9** + SHOWRUN S1/S2 + Mobile |
| **Personal** | 10 FTE × 28 Monate × ~6 000 € ≈ 1,7 Mio. € |
| **Extern + Marketing + Recht + Infrastruktur** | 0,6–0,9 Mio. € |
| **Summe inkl. 15 % Puffer** | **~2,6–3,0 Mio. €** |
| **Voraussetzung** | Publisher-Deal oder Investor + Bundesförderung; Studio-Strukturen (HR, Buchhaltung) |

### 4.4 Entscheidung

**Szenario B anstreben, Szenario A als Rückfallebene.** Entscheidungspunkt: **Ende Phase 3 (Aug 2027)** — liegt bis dahin keine
Finanzierung für ≥ 12 Monate Team vor, geht das Projekt in Szenario A mit gekürztem Umfang weiter (keine Abbruch-Entscheidung).
Szenario C nur, wenn ein Publisher/Investor es aktiv anbietet; wir bewerben uns nicht darauf.

---

## 5. Finanzierung

### 5.1 Finanzierungs-Mix Baseline (Ziel ~1,0 Mio. €)

| Quelle | Anteil | Betrag (**Schätzung**) | Zeitpunkt |
|---|---|---|---|
| Eigenleistung + Eigenmittel | 10 % | 100 000 € | laufend |
| Länderförderung (Prototyp/Produktion) | 15–20 % | 150 000–200 000 € | Antrag Phase 3 |
| Bundesförderung Games | 20–30 % | 200 000–300 000 € | Antrag Phase 3, sobald Fenster offen |
| Publisher (Vorschuss gegen Erlösbeteiligung) | 30–40 % | 300 000–400 000 € | Pitch Phase 3, Vertrag Ende Phase 3 |
| Crowdfunding (optional) | 5–10 % | 50 000–100 000 € | Ende Phase 3 / Anfang Phase 4 |
| EA-Umsätze (reinvestiert) | Rest | — | Phase 5 |

### 5.2 Deutsche Förderung — Überblick **[Stand prüfen]**

| Programm | Träger | Was gefördert wird (bisheriger Stand) | Hinweise **[alles zu prüfen]** |
|---|---|---|---|
| **Games-Förderung des Bundes** | Bund (Zuständigkeit nach Regierungswechsel ggf. neu verortet; Projektträger) | Prototypen und Produktionen; Zuschuss mit Förderquote, Eigenanteil nötig | Antragsfenster wurden in der Vergangenheit wegen Mittelausschöpfung zeitweise geschlossen; **Kulturtest**; Projekt darf vor Bewilligung meist **nicht begonnen** sein → Phase 3/4 als **neues Vorhaben** definieren; aktuelle Richtlinie, Höchstbeträge und Quoten prüfen |
| **FFF Bayern** (Games) | Bayern | Konzept, Prototyp, Produktion | Regionaleffekt (Ausgaben/Sitz in Bayern) |
| **Medienboard Berlin-Brandenburg** (Games) | Berlin/Brandenburg | Prototyp, Produktion | Sitz/Ausgaben in der Region |
| **MOIN Filmförderung Hamburg Schleswig-Holstein** (Games) | HH/SH | Prototyp, Content | Sitz/Ausgaben in der Region |
| **Film- und Medienstiftung NRW** (Games) | NRW | Konzept, Prototyp, Produktion | Sitz/Ausgaben in NRW |
| **MFG Baden-Württemberg** (Digital Content) | BW | Prototyp/Produktion digitaler Inhalte | Sitz in BW |
| Weitere Länder (z. B. HessenFilm, nordmedia, Mitteldeutsche Medienförderung) | jeweiliges Land | Games-Linien je nach Land | Verfügbarkeit prüfen |
| **Creative Europe MEDIA** (Video Games & Immersive Content) | EU | Entwicklung narrativer Spiele bis Prototyp/Demo | Anforderungen an Firmen-Historie/Track Record prüfen |
| Gründungshilfen (z. B. Gründungszuschuss, ERP-/KfW-Gründerkredite, EXIST für Hochschul-Ausgründungen) | Bund/Agentur für Arbeit/KfW | Lebenshaltung/Startkapital | Voraussetzungen individuell |

**Entscheidung:** Der **Firmensitz bestimmt die Landesförderung** — Gründung in dem Land, in dem du lebst; kein Umzug für Förderung.
Förderberatung (die Länderförderer bieten kostenlose Erstgespräche an **[zu prüfen]**) in **Monat 1 von Phase 3**.

### 5.3 Publisher

| | |
|---|---|
| **Wann** | Pitch ab Phase-3-Monat 3 (mit Art-Upgrade-Slice, Steam-Seite, ersten Wishlist-Daten) |
| **Wen** | Indie-Publisher mit RPG-/Humor-/Roguelite-Portfolio, EU-nah. Beispiele (Eignung/Status je **[zu prüfen]**): Assemble Entertainment, Headup, Raw Fury, Team17, Devolver Digital, Kwalee, Akupara Games |
| **Was wir wollen** | Vorschuss für Phase 4–5 (300–400 k€), Marketing/PR, QA, Lokalisierung, später Konsolen-Ports |
| **Was wir behalten** | **IP-Eigentum**, kreative Kontrolle, Mobile-Rechte verhandelbar, SHOWRUN-Online-Dienste |
| **Typische Konditionen** | Recoup des Vorschusses, danach Erlösteilung (oft im Bereich 50/50 bis 70/30 zugunsten Studio) **[marktüblich prüfen, Anwalt]** |
| **Rote Linien** | IP-Übertragung, Echtgeld-Zufallsmonetarisierung für Spieler:innen, unbegrenzte Laufzeit, Cross-Collateralization mit anderen Titeln |

### 5.4 Crowdfunding (Kickstarter/Backerkit)

**Entscheidung: nur mit Gate.** Kampagne startet **nur**, wenn: ≥ **8 000 Wishlists**, ≥ **2 000 Discord-Mitglieder**,
≥ **1 500 E-Mail-Abonnent:innen** vorab. Ziel 60 000 €, 30 Tage, Timing **Okt/Nov 2027** (Anfang Phase 4).

| Stufe (**Schätzung**) | Preis | Inhalt |
|---|---|---|
| Digital | 15 € | Spiel (Steam-Key bei EA) |
| Fan | 25 € | + Soundtrack + digitales Artbook |
| Name im Abspann | 40 € | + Name in „Zuschauer-Credits“ |
| M.O.D.-Spruch | 150 € | eigener Chat-Ticker-Spruch (redigiert, limitiert 100) |
| Gegner-Design | 750 € | Mitgestaltung eines Gegners (limitiert 10, Vertrag zu Rechten) |

Gebühren: Plattform ~5 % + Zahlungsabwicklung ~3–5 % **[Stand prüfen]**; physische Belohnungen **keine** (Logistik-Risiko).
Stretch Goals nur mit bereits geplanten Inhalten (keine Scope-Erweiterung durch Kampagne).

### 5.5 Steam Next Fest als Finanzierungs-Hebel

Next-Fest-Daten (Wishlists, Demo-Spielzeit) sind das stärkste Argument gegenüber Publishern und für Lizenzgespräche.
**Plan:** Demo (Etage 1, Art-Upgrade) im **Februar 2028** (Phase 4) — jedes Spiel kann nur **einmal** an einem Next Fest
teilnehmen **[Regel prüfen]**, deshalb nicht zu früh mit Primitiv-Optik.

---

## 6. Monetarisierung & Preise

### 6.1 Modell

| Plattform | Modell | Preis (**Planwert**) |
|---|---|---|
| **Steam EA** | Premium | **14,99 €** (EA-Käufer:innen erhalten alle Staffel-1-Updates) |
| **Steam 1.0** | Premium | **19,99 €**; Launch-Rabatt 10 % |
| **Demo (PC)** | kostenlos | Etage 1 + 1 Event-Lauf; Spielstand übertragbar |
| **Android/iOS** | Free-Demo + **einmaliger Vollversions-Kauf** | **9,99 €** (Staffel 1 komplett); keine Werbung, keine Energie, keine Verbrauchs-IAPs |
| **Staffel 2** (Etagen 7–9) | Erweiterung | PC 9,99 €, Mobile 6,99 € |
| **Soundtrack** | DLC | 4,99 € |
| **Supporter-Pack** | DLC (ab 1.0) | 6,99 € — digitales Artbook + **rein kosmetische** Outfits für Kai/Mopsula |

Regionale Preise nach Steam-Empfehlung; erster Rabatt frühestens **3 Monate** nach EA-Launch.

### 6.2 Regeln (verbindlich)

1. **Kein Pay-to-Win:** nichts Kaufbares wirkt auf Werte, Kämpfe, Bestenlisten.
2. **Keine Echtgeld-Zufallsinhalte für Spieler:innen** (Brief Kap. 5). Lootboxen werden nur **verdient**.
3. **Keine Werbung**, keine Energie-/Wartezeit-Mechaniken, keine Verbrauchs-Käufe.
4. **Kosmetik** ist der einzige zusätzliche Kaufinhalt neben Erweiterungen/Soundtrack.
5. **Zuschauer-Echtgeldgeschenke** (SHOWRUN S3/S5) nur nach Rechtsprüfung, nur im Live-Modus, mit allen Leitplanken L1–L16 aus 05 — als Zusatz, nicht als Geschäftsgrundlage.
6. **Erlös nur an den Betreiber** (Entscheidung 2026-10-08): keine Auszahlung, keine Beteiligung an Spieler:innen oder
   Streamer:innen (Creator-Beteiligung gestrichen); Kaufweg ist der eigene Shop (Web + App-Store-IAP), nicht Twitch Bits.

### 6.3 Umsatz-Szenarien (**Schätzung**, nur zur Einordnung)

| Annahme | Vorsichtig | Ziel | Gut |
|---|---|---|---|
| Wishlists bei EA-Launch | 15 000 | 25 000 | 50 000 |
| Verkäufe Jahr 1 (EA, Faustregel ~0,5–1,5 × Wishlists im ersten Jahr) | 10 000 | 30 000 | 75 000 |
| Ø Nettoerlös je Verkauf (nach Steam-Anteil 30 %, USt, Regionalpreisen, Rabatten) | ~8 € | ~8,5 € | ~9 € |
| **Netto Jahr 1 PC** | **80 000 €** | **255 000 €** | **675 000 €** |

Faustregeln aus der Indie-Szene sind keine Garantie **[Steam-Anteile: 30 % bis 10 Mio. USD, danach gestaffelt — prüfen]**.
Folge: Szenario B ist nur mit Förderung/Publisher tragfähig; die EA-Umsätze finanzieren Phase 5 teilweise, nicht das Projekt.

---

## 7. Marketing-Plan

### 7.1 Kernbotschaft & Content-Säulen

**Kernbotschaft:** „Das Rundenkampf-RPG, in dem die Zuschauer:innen mitentscheiden, ob du überlebst.“

| Säule | Format | Beispiel | Takt |
|---|---|---|---|
| **„M.O.D. kommentiert“** | 10–20 s vertikal (TikTok, Shorts, Reels) | Achievement „Mit 1 HP gewonnen“ + M.O.D.-Spruch + Zuschauerzahl springt | 2×/Woche ab Phase 3 |
| **„Stunt der Woche“** | 15–30 s | Stunt-Kill → Hype 100 → Sponsor-Drop mitten im Kampf | 1×/Woche |
| **Graf Mopsula** | Standbild/GIF + Zitat | „Wir sind not amused.“ | 1×/Woche |
| **Devlog** | 3–8 min YouTube / Steam-Ankündigung | prozedurale Optik → Blender-Upgrade, Balancing-Simulation | 1×/Monat |
| **SHOWRUN-Seeds** | Bestenlisten-Posts | „Tages-Seed: 3 % schafften den Hausmeister ohne KO“ | ab S1 |

Hinweis zur Kommunikation über KI-Entwicklung: **transparent, aber nicht im Vordergrund** — Botschaft „ein kleines Team, Werkzeuge
für Code, Menschen für Kunst/Text/Musik“.

### 7.2 Twitch-/Streamer-Integration (Show-Mechanik als Marketing-Motor)

| Stufe | Wann | Funktion | Technik | Geld |
|---|---|---|---|---|
| **Streamer-Modus lite** | EA Update 2 | Chat stimmt per Befehl (z. B. `!1 / !2`) über **Sponsor-Geschenke** ab: welches Geschenk beim nächsten Hype-Schwellenwert kommt, welcher Twist (Nebel, Doppel-Loot, Gegner-Buff); Chat-Namen erscheinen als In-Game-Sponsoren im Chat-Ticker | Client liest den Twitch-Chat direkt (OAuth des Streamers), **kein eigener Server**; Votes gehen über `Show.receive_gift()` (Quelle `fan`) | keins |
| **SHOWRUN S2** | nach 1.0 | Zuschauen mit Delay, Votes, Applaus-Fanpakete | Spectator-Pipeline (05) | keins |
| **SHOWRUN S3** | Phase 7, nach Rechtsprüfung | Twitch-Extension: Votes, Applaus, Sponsor-Fenster-Anzeige — **ohne Bits-Geschenke** (Bits-Erlöse gehen nach Kenntnisstand an Broadcaster:innen **[zu prüfen]**, widerspricht der Entscheidung 2026-10-08); Echtgeld-Geschenke nur über den eigenen Shop | Twitch-Extension + Web-Shop (C) | nur C (an den Betreiber) |

**Streamer-Programm:** ab Demo **200 Keys** an DE/EN-Streamer:innen (50–5 000 Zuschauer:innen, RPG/Variety), Streamer-Presskit
(Overlay-Hinweise, Spoiler-Policy, „Streamer-Modus aktivieren“-Anleitung), Musik **streaming-sicher** (Lizenzvertrag mit Komponist:in!).

### 7.3 Community

| Kanal | Start | Ziel bis EA |
|---|---|---|
| Discord | Phase 3, Monat 1 | 3 000 Mitglieder |
| E-Mail-Newsletter (Website) | Phase 3, Monat 1 | 3 000 Abonnent:innen |
| Steam-Seite + Ankündigungen | Phase 3, Monat 1 | 25 000 Wishlists |
| Reddit (r/JRPG, r/litrpg, r/IndieGaming, r/SteamDeck) | Phase 3 | Regeln je Subreddit beachten; DCC-Subreddits **nicht** bespielen (Abstand, Kap. 2.2) |
| Bluesky/X, TikTok, YouTube, Instagram | Phase 3 | je 1 Hauptkanal (TikTok + YouTube Shorts), Rest gespiegelt |

### 7.4 Wishlist-Ziele & Zeitplan

| Zeitpunkt | Maßnahme | Wishlist-Ziel (kumuliert) |
|---|---|---|
| Mär 2027 (Phase 3 M1) | Steam-Seite live, Ankündigungs-Trailer, Pressemitteilung DE/EN | 1 000 |
| Mai 2027 | Clip-Takt läuft, Devlog #1–2 | 2 000 |
| Aug 2027 | **gamescom** (Köln; z. B. Indie-Gemeinschaftsstand **[Teilnahme/Kosten prüfen]**), Trailer #1 | **3 000** (Gate Phase 3) |
| Okt/Nov 2027 | (optional) Kickstarter, Streamer-Previews | 8 000 |
| Jan 2028 | Demo öffentlich | 10 000 |
| Feb 2028 | **Steam Next Fest** | 15 000–18 000 |
| Mai 2028 | **EA-Launch** (Gate ≥ 15 000, Ziel 25 000) | 25 000 |
| Mai 2029 | 1.0 + Rabatt-Event, Presse-Welle 2 | Follower-Basis für Staffel 2 |

Weitere Termine: Deutscher Computerspielpreis (Einreichung prüfen), devcom/Indie-Arena-Formate, Steam-Themen-Festivals (RPG, Roguelike) **[Termine prüfen]**.

### 7.5 Budget Marketing (Baseline B, **Schätzung**)

Trailer 2 × 3 000–6 000 €, Messe 1 × 3 000–10 000 €, PR-Agentur für EA-Launch 8 000–15 000 €, bezahlte Anzeigen (nur Tests, CPW messen) 5 000–10 000 €,
Key Art 2 000–4 000 €, Keys/Streamer-Aktionen 0 €. **Summe 50 000–90 000 €.**

---

## 8. Plattform-Strategie

### 8.1 Reihenfolge

1. **PC/Steam** (Windows + Linux, Steam Deck) — EA Mai 2028, 1.0 Mai 2029. macOS mit 1.0 (Notarisierung nötig).
2. **Android + iOS** — Launch nach PC 1.0 (Jul/Aug 2029).
3. **GOG / itch.io** — zur 1.0 (DRM-frei; geringer Aufwand).
4. **Konsolen** — nur über Partner nach 1.0 (Kap. 3.9).

Begründung PC zuerst: EA-Kultur und Community-Feedback, Next Fest als Marketing-Plattform, kein Store-Review-Risiko, Steam Deck
deckt den „Handheld-Feierabend“ schon ab, Touch-UX kann reifen.

### 8.2 Technische Anforderungen (Ziele)

| | Minimum | Empfohlen |
|---|---|---|
| **PC OS** | Windows 10 64-bit, Ubuntu 22.04+ | Windows 11, SteamOS |
| **PC GPU** | OpenGL 3.3 (Compatibility-Fallback), z. B. Intel UHD 620 → 30 FPS 720p | Vulkan-fähig, iGPU der letzten 5 Jahre → 60 FPS 1080p |
| **PC RAM / Speicher** | 4 GB / 1 GB | 8 GB / 2 GB |
| **Steam Deck** | „Verified“-Ziel: 60 FPS, Gamepad-Glyphen, Textgröße ≥ 9 px bei 1280×800 **[Kriterien prüfen]** | — |
| **Android** | Android 10+, arm64, OpenGL ES 3.0 / Vulkan, 3 GB RAM (Adreno 610 / Mali-G57) | Android 12+, 4 GB |
| **iOS** | iPhone 11 / A13, aktuelle iOS-Version − 2 **[Mindestversion des Godot-4.7-Exports prüfen]** | iPhone 13+ |
| **Netz** | offline voll spielbar; SHOWRUN S1+ online optional | — |

Grundlagen: Renderer `mobile` + Pflicht-Fallback `gl_compatibility` (Brief Kap. 5), Budgets 02_TECH §12.1 / 03_ART Kap. 11.

### 8.3 Store-Anforderungen

| Thema | Steam | Google Play | Apple App Store |
|---|---|---|---|
| Gebühr | Steam Direct 100 USD je App (verrechenbar) **[prüfen]** | Entwicklerkonto einmalig 25 USD **[prüfen]** | Developer Program 99 USD/Jahr **[prüfen]** |
| Umsatzanteil | 30 % (gestaffelt ab hohen Umsätzen) | 15 % bis 1 Mio. USD/Jahr (Programm) **[prüfen]** | 15 % im Small Business Program **[prüfen]** |
| Altersfreigabe | Inhalts-Fragebogen; USK-Kennzeichen-Pflicht für reinen Steam-Vertrieb **[zu prüfen]** | IARC-Fragebogen (ergibt USK/PEGI/ESRB) | Apples eigener Alters-Fragebogen (Stufen wurden überarbeitet **[prüfen]**) |
| Datenschutz | Datenschutzerklärung bei Datenerhebung | **Data-Safety-Formular**, Datenschutz-URL | **Privacy Nutrition Label**, ggf. Privacy Manifest für bestimmte APIs **[prüfen]** |
| KI-Inhalte | **Offenlegung von KI-generierten Inhalten** im Content-Fragebogen **[Stand prüfen]** | — | — |
| Tests | — | neue persönliche Entwicklerkonten: geschlossener Test mit Mindestanzahl Tester:innen über Mindestdauer vor Produktion **[Zahlen prüfen]** | TestFlight, App Review |
| Technik | — | Ziel-API-Level-Pflicht (jährlich angehoben) **[aktuellen Wert prüfen]**, AAB-Format, 64-bit | Xcode-Build auf macOS, aktuelle SDK-Pflicht **[prüfen]** |
| Accounts (ab SHOWRUN S1) | — | Kontolöschung in App + Web-Link **[prüfen]** | Kontolöschung in der App; Login-Regeln bei Drittanbieter-Login **[prüfen]** |
| Zufallskäufe | n/a (gibt es nicht) | Odds-Offenlegung Pflicht | Odds-Offenlegung Pflicht |

**Konsequenz:** Solange wir **keine Accounts, kein Tracking, keine Werbung, keine Zufallskäufe** haben (bis inkl. 1.0 außer SHOWRUN S1-Online-Funktionen),
sind Datenschutz- und Store-Angaben minimal („keine Daten erhoben“ bzw. nur Opt-in-Crash-Reports). Jede neue Datenerhebung braucht vorher eine Datenschutz-Prüfung.

---

## 9. Risiko-Register & KPIs

### 9.1 Top-12-Risiken

Skala: Wahrscheinlichkeit (W) / Auswirkung (A) = niedrig · mittel · hoch.

| # | Risiko | W | A | Gegenmaßnahme | Frühindikator |
|---|---|---|---|---|---|
| R1 | **Scope Creep** — 6–9 Etagen sind zu viel Content | hoch | hoch | Staffel 1 = Etagen 1–6, Staffel 2 nach 1.0; Etagen-Template (8–10 Gegner, 2 Bosse, 25–30 Achievements) als Obergrenze; Pipeline-Beweis Phase 3 (Etage in ≤ 4 Wochen Grey Box) | Etage dauert > 10 Wochen |
| R2 | **Show-USP trägt nicht** (wird ignoriert oder nervt) | mittel | hoch | Gate Phase 1/2 mit harten Playtest-Zahlen; Hype-Werte datengetrieben (`Balance`), schnell änderbar | < 50 % nennen Show-System als Highlight |
| R3 | **Sichtbarkeit auf Steam** zu gering | hoch | hoch | Steam-Seite früh, Clip-Takt, Next Fest, Streamer-Modus; Launch-Gate 15 000 Wishlists | < 3 000 Wishlists nach 6 Monaten |
| R4 | **IP-Nähe zu DCC** (Abklatsch-Vorwurf, Ansprüche) | mittel | hoch | Distanz-Review + Anwalts-Memo vor Steam-Seite; keine DCC-Begriffe im Marketing; europäische Satire als Profil | Community-Kommentare „DCC-Kopie“ |
| R5 | **Markenkonflikt Titel** („PRIME“) | mittel | mittel | Recherche Phase 2, Anmeldung vor Steam-Seite, 3 Fallback-Titel | Widerspruch/Abmahnung |
| R6 | **Finanzierung bleibt aus** (Förderstopp, Publisher-Absagen) | mittel | hoch | Mix aus 4 Quellen; Szenario A als geordneter Rückfall; Fixkosten erst nach Zusage | 0 Zusagen bis Phase-3-Monat 5 |
| R7 | **Art-Upgrade zu teuer / Stilbruch** zwischen Kit und Blender-Modellen | mittel | hoch | 03_ART-Konventionen (gleiche Shader, Vertex-Colors, Pivots), ein Leit-Artist, Stil-Guide; Kit-Optik bleibt als Fallback lauffähig | Figur > 2 Wochen Aufwand |
| R8 | **Solo-Bus-Faktor / Burnout** | hoch (A) / mittel (B) | hoch | feste Arbeitszeiten, Phasen-Gates statt Dauersprint, Doku + Tests machen Übergabe möglich, KI für Routine | > 3 Wochen ohne Fortschritt |
| R9 | **Mobile-Performance / Touch-UX** bei 3D + Menüs | mittel | mittel | Budgets ab Slice gemessen, Android-Gerät ab Phase 2 im Test, 30-FPS-Modus, Touch-Layer von Anfang an | < 45 FPS auf Zielgerät |
| R10 | **Echtgeld-Zuschauergeschenke**: Recht/Plattform/Reputation | mittel | hoch | Phase 7, schriftliche Rechtsprüfung, Pur-Liga Standard, Leitplanken L1–L16, Erlös nur an den Betreiber, Hilfe nur in Sponsor-Fenstern; kein Budget davon abhängig | Gutachten negativ → Fallback „nur nicht-zufällig/kostenlos“ |
| R11 | **KI-Abhängigkeit**: Codequalität, Wartbarkeit, Offenlegung, Kosten | mittel | mittel | statische Typisierung, Modulverträge, Tests als Pflicht, Code-Reviews, menschliche Abnahme; keine KI-Assets im finalen Spiel | wachsende Bug-Rate pro Update |
| R12 | **Marktumfeld**: offizielles DCC-Spiel/TV-Start besetzt die Nische — oder Engine-/Store-Änderungen | mittel | mittel | Eigenes Profil (Show-System, europäische Satire); TV-Hype als Chance für das Genre nutzen, ohne DCC zu nennen; Godot-Version pro Phase einfrieren, Updates nur zwischen Phasen | Ankündigungen der Rechteinhaber |

### 9.2 KPIs je Phase

| Phase | KPI | Zielwert |
|---|---|---|
| **1** | `tools/check.sh` grün; Autoplay | 100 %; `AUTOPLAY: OK` |
| | Kampf-Spaß (5 Tester:innen) | Median ≥ 3,5/5 |
| **2** | Hausmeister erreicht (15 externe Tester:innen) | ≥ 70 % |
| | Median-Spielzeit Etage 1 | 22–28 min |
| | „Würde weiterspielen“ (Top-2-Box) | ≥ 60 % |
| | Ungefragte Nennung Show/M.O.D./Mopsula | ≥ 50 % |
| | Crashes in 20 Durchläufen | 0 |
| | Performance PC-iGPU / Android-Mittelklasse | 60 / ≥ 45 FPS |
| **3** | Wishlists nach 3 / 6 Monaten Steam-Seite | 2 000 / 3 000 |
| | Kapsel-Klickrate (Steam-Statistik, Impressions → Besuche) | ≥ 4 % **[Benchmark prüfen]** |
| | Discord / Newsletter | 500 / 800 |
| | Grey-Box-Etage Bauzeit | ≤ 4 Wochen |
| | Finanzierung | ≥ 12 Monate Team gesichert |
| **4** | Demo Median-Spielzeit | ≥ 30 min |
| | Wishlists durch Next Fest | + 5 000 |
| | Wishlists bei Launch | ≥ 15 000 (Ziel 25 000) |
| | Bot-Läufe crash-frei (alle Etagen) | 50/50 |
| **5** | Steam-Reviews positiv | ≥ 85 % |
| | Refund-Quote | < 8 % |
| | Median-Spielzeit (Steam) | ≥ 4 h |
| | Hotfix-Zeit kritischer Bugs | ≤ 72 h |
| | Verkäufe Jahr 1 | ≥ 30 000 |
| **6** | Crash-freie Sessions | ≥ 99,5 % |
| | Demo D1 / D7 Retention | ≥ 35 % / ≥ 15 % |
| | Unlock-Conversion | ≥ 5 % der Demo-Installationen |
| | Store-Bewertung | ≥ 4,3 |
| **7** | Teilnahme Event-Läufe (Anteil monatlich aktiver Spieler:innen) | ≥ 20 % |
| | Streamer-Modus-Nutzung (Sessions mit aktivem Modus) | ≥ 300/Monat |
| | Staffel-2-Kaufquote der 1.0-Besitzer:innen | ≥ 25 % |

---

## 10. Wie ich (Claude) jetzt konkret vorgehe

Ziel: **Vertical Slice (Phase 1 → 2)** in diesem Repo, nach dem Vertrag aus `02_TECH.md` §0 (Phasen A → B → C), mit automatischer
Verifikation vor jedem Push. Godot-Binary: 4.7.2-stable (lokal installiert; in CI per Workflow geladen).

### 10.1 Ablauf in Schritten

| # | Schritt | Was ich tue | Gate (muss grün sein, bevor es weitergeht) |
|---|---|---|---|
| **1** | **Docs konsolidieren** | Änderungsanträge CR-1…CR-10 aus 05 Kap. 11.6 in `02_TECH.md` einarbeiten (Signale, `receive_gift`, `time_left_ticks`, Modul M8); Widersprüche Brief ↔ GDD ↔ TECH ↔ ART ↔ LIVE auflisten und nach Brief-Vorrang auflösen | Keine offenen Widersprüche; Dateibesitz für **jede** Datei eindeutig (02_TECH §1) |
| **2** | **M0 Fundament** (Phase A, allein) | `project.godot` (§2), Input-Map, 7 Autoloads + `GameSettings`/`SfxSynth`, `GameData`/`DataValidator`/`JsonUtil`/`SeedUtil` + Defs, Test-Harness (`run_tests.gd`, `test_case.gd`, `capture.gd`), `UiTheme`, **Stubs aller Modul-Dateien** mit exakten Signaturen, minimale `data/*.json`, Fixtures, `export_presets.cfg`, CI-Workflow `ptd-check.yml` | `GODOT=<godot> tools/check.sh --tests-only` grün; `test_m0_compile_all` lädt jede Datei |
| **3** | **Module M1–M7 parallel** (Phase B) | Je Modul ein eigener Arbeitsstrang (Sub-Agent), der **nur seine Dateien** ersetzt: **M1** Kampf-Logik (CTB, Formeln, Status, KI, `ActionEvent`) · **M2** Show/Loot/Progression/Save · **M3** Dungeon-Generator + Erkundungsszene · **M4** Art-Kit (Shader, Figuren, Umgebung, VFX, Galerien) · **M5** Kampf-Darstellung (Bühne, Kamera, HUD, CTB-Leiste, Ergebnis) · **M6** UI & Meta-Szenen (Boot, Titel, Intro, Safe Room, Overlay, Menüs, Touch, Autoplay) · **M7** Datensätze Etage 1 (GDD-Zahlen) | Pro Modul: eigene Pflicht-Tests (02_TECH §11.5) grün mit `check.sh --tests-only`; **Diff-Prüfung**: keine Änderung an fremden Dateien (sonst Änderungsantrag) |
| **4** | **Zusammenführen** | Reihenfolge nach Abhängigkeit: **M7 → M1 → M2 → M3 → M4 → M5 → M6**; nach **jedem** Merge kompletter Testlauf | `check.sh --tests-only` nach jedem Merge grün |
| **5** | **Integration** (Phase C) | Echter Ablauf Boot → Titel → Intro → Erkundung → Kampf → Ergebnis → Safe Room → Boss → Treppe → Abspann; Router-Übergänge; Fehler an Modulgrenzen beheben (Fix in der Datei des besitzenden Moduls) | **= Meilenstein M-P1 (Grey-Box-Loop)**: `tools/check.sh` grün inkl. **`AUTOPLAY: OK`** (Schritte 1–7) |
| **6** | **SHOWRUN-Hooks (M8)** | `core/live/*` (RunLog, StateHash, EventCatalog, QuestTracker, ScoreCalc, Leaderboard, Gift, GiftPolicy, GiftApplier, FairRoll), Event-Lauf im Titel, lokale Bestenliste (05 Kap. 11) | `test_m8_*` grün; Lint „kein globales RNG/`Time` in `core/`“; Replay-Gleichheit gleicher Seed → gleicher Hash |
| **7** | **Automatische Verifikation** | (a) `tools/check.sh` (Import, alle Tests, Autoplay). (b) Screenshots aller 7 Szenen aus 02_TECH §12.4 per `check.sh --shot <scene> <png> 120 1280x720` im `gl_compatibility`-Renderer. (c) Ich **sehe mir jeden Screenshot an** und vergleiche mit 03_ART (Toon-Bänder, Outlines, Licht-Kodierung, TV-Overlay lesbar). (d) Balancing-Sanity M7: alle Etage-1-Encounter mit Startparty, 50 Seeds, ≥ 80 % Siegquote; Bosse mit Lv 4–6. (e) Determinismus: 2 Läufe gleicher Seed → gleicher `state_hash`. (f) Budget-Check: Tri-Zahlen der Kit-Figuren (M4-Tests), Draw Calls per `Performance`-Monitor in Capture-Läufen | alles grün, keine `ERR_RE`-Treffer, keine `SHADER ERROR` |
| **8** | **Review-Schleife** | Code-Review je Modul (Korrektheit, statische Typisierung, Verträge, Schichtregeln 02_TECH §0.4), Integrations-Checkliste 02_TECH §14 Punkt für Punkt, Docs-Abgleich (Code ↔ GDD-Zahlen); Funde beheben → zurück zu Schritt 7. **Maximal 3 Runden**; was danach offen ist, kommt als Liste zu dir | 0 offene Befunde der Schwere „Bug“; Rest dokumentiert |
| **9** | **Commit & Push** | Commits je Modul/Schritt mit klaren Nachrichten, Push auf den Arbeitszweig; CI-Workflow `ptd-check` muss dort grün laufen (Screenshots als Artefakt) | CI grün |
| **10** | **Übergabe an dich** | Kurzbericht: was läuft, Screenshots, bekannte Lücken, **Anleitung zum Selbstspielen** (Godot 4.7.2 öffnen → `prime-time-dungeon/game/project.godot` → F5; Tastatur/Gamepad-Belegung), Playtest-Fragebogen für Phase-2-Tests | — |

**Stand 2026-10-10** (Branch `ptd/final-a`):

| # | Stand |
|---|---|
| 1 | erledigt — CR-1…CR-15 eingearbeitet und umgesetzt; Dateibesitz in 02_TECH §1 (inkl. aller Tests, §1.7) |
| 2–4 | erledigt — M0–M7 implementiert und zusammengeführt, alle Stubs ersetzt (02_TECH §0.2) |
| 5 | erledigt — Meilenstein M-P1: `tools/check.sh` grün inkl. `AUTOPLAY: OK` |
| 6 | erledigt — SHOWRUN-Hooks M8 inkl. Sponsor-Fenster, Verifier (`RunSim.replay`, `Game.replay_log`) mit `errors`-Vertrag |
| 7 | erledigt — Tests (~830), Screenshots (`docs/screenshots/`), Full-Run-Bot in 3 Strategien, Performance-Probe `PERF: OK` (`docs/PERFORMANCE.md`), Balancing GDD §13 |
| 8 | erledigt — Review-Runden inkl. Abschluss-Review (core-logic, live-integrity, docs-truth, quality); Befunde behoben |
| 9 | erledigt — CI `ptd-check` (Import, Tests, Smoke, Full-Run, Screenshots, Exports) |
| 10 | teilweise — Anleitung zum Selbstspielen: `prime-time-dungeon/README.md`; offen: Playtest-Fragebogen |

**Offen für den Exit von Phase 2** (Kap. 3.4): 15 externe Playtests, Performance-Budgets auf PC-iGPU und einem echten
Android-Mittelklassegerät, Distanz-Review (E2), Titel-Entscheidung (E3), Gameplay-Video, Android-Debug-APK; dazu
sichtbare Ausrüstung (03_ART A8) und die Plattform-Matrix der Stufe S0 (05 Kap. 2).

### 10.2 Abhängigkeiten der Module (warum parallel möglich ist)

```
M0 (Fundament, Stubs, Verträge)
 ├── M1 Kampf-Logik ─────────┐
 ├── M2 Show/Loot/Prog/Save ─┤ (nutzt M1-Typen über Stubs)
 ├── M3 Dungeon + Erkundung ─┤ (nutzt M4-API über Stubs)
 ├── M4 Art-Kit ─────────────┤ (nur Godot + Def-Typen)
 ├── M5 Kampf-Darstellung ───┤ (treibt M1-Kern, nutzt M4)
 ├── M6 UI & Meta-Szenen ────┤ (nutzt Autoloads)
 └── M7 Daten-Inhalte ───────┘ (validiert durch M0-DataValidator)
                             ↓
                  Integration (M0-Leitung) → M8 SHOWRUN-Hooks → Verifikation → Review → Push
```

Weil M0 **alle** öffentlichen APIs als Stubs mit exakten Signaturen anlegt, kompiliert jedes Modul vom ersten Tag an gegen die
anderen — auch wenn deren Implementierung noch fehlt. Die Tests von M1/M2 nutzen eigene Mini-Fixtures (unabhängig von M7).

### 10.3 Was ich nicht allein kann (und wann ich dich brauche)

| Punkt | Wann |
|---|---|
| Spielgefühl beurteilen (Kampftempo, Witz der Texte, Kamera) | nach Schritt 5 und 10 |
| Test auf echtem Android-Gerät / mit Gamepad in der Hand | Phase 2 |
| Externe Playtests organisieren (15 Personen) | Phase 2 |
| Rechtliche Prüfungen (Distanz-Review, Marke) beauftragen | Ende Phase 2 |
| Entscheidungen aus Kap. 11 | bis Ende Phase 2 |

---

## 11. Entscheidungen, die ich von dir brauche

| # | Entscheidung | Mein Vorschlag | Bis wann |
|---|---|---|---|
| E1 | Szenario A/B/C | **B anstreben, A als Rückfall** (Kap. 4.4) | Start Phase 3 |
| E2 | Distanz-Review: Umbenennungen (Fan-Box → „Fanpost-Paket“, Quartier-Boss → „Revier-Boss“, NOVA SYNDIKAT → „NOVA MEDIENGRUPPE“, Box → „Requisitenkiste“) | Vorschläge aus Kap. 2.3 übernehmen; reine Textänderung in `name`/`text`, IDs (`box_fan`, `enm_boss_hausmeister`) bleiben. Mopsula-Kronenverzicht (`itm_wpn_collar_signet`, `acc_queen_crown` nur Kai) ist bereits umgesetzt | Exit Phase 2 |
| E3 | Finaler Titel | Markenrecherche „PRIME TIME DUNGEON“; Fallback „RATINGS DUNGEON“ | Exit Phase 2 |
| E4 | Firmenform & Sitz | UG (haftungsbeschränkt) am Wohnort | Start Phase 3 |
| E5 | Staffel-Schnitt | Staffel 1 = Etagen 1–6 (1.0), Staffel 2 = 7–9 (Erweiterung) | jetzt (Planungsgrundlage) |
| E6 | Kickstarter ja/nein | nur bei erfüllten Gates (Kap. 5.4) | Phase-3-Monat 5 |
| E7 | Lizenz-Track DCC | nur bei erfüllten drei Bedingungen (Kap. 2.4) | frühestens Ende Phase 3 |
| E8 | Echtgeld-Zuschauergeschenke | bleiben gewollt (Brief), aber **Phase 7 nach Rechtsprüfung**. **Entschieden 2026-10-08:** C (eigener Shop: Web + App-Store-IAP) ist der Echtgeld-Weg, Erlös nur an den Betreiber, B (Twitch Bits) nur kostenlose Interaktion; Hilfe nur in Sponsor-Fenstern (05 Kap. 6.13). Offen nur: gibt es ein Bits-Erlösmodell für Entwickler **[zu prüfen]**? | vor Planung von S3 |
