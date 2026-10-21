# PRIME TIME DUNGEON — Sprachen und Inhaltspakete (Englisch, Pakete, Mechanik-Baukasten)

> **Grundlage:** Auftrag des Orchestrators vom **2026-10-13**. Das Team möchte die Engine der Rechteinhaberseite einer
> bekannten Buchreihe als Lizenz-Pitch zeigen. Das öffentliche Repository darf dabei nie fremde IP enthalten. Deshalb
> bekommt die Engine zwei allgemeine Fähigkeiten, die auch PTD selbst nützen: **Englisch als zweite Sprache** und
> **Inhaltspakete aus reinen Daten**. Welche Reihe gemeint ist, steht bewusst nirgends in diesem Dokument; es spricht
> von „lizenzierten Inhaltspaketen“, „Partner-Inhalten“ und „Pitch-Builds“.
>
> **Rahmen des Orchestrators (verbindlich, hier nicht neu verhandelt):**
> (O-1) **Eigene IP öffentlich.** Dieses Repository bleibt PTDs eigene IP. Fremde oder lizenzierte Inhalte gibt es nur
> als **Inhaltspaket** in einem getrennten, privaten Repository; das öffentliche Repository enthält den Mechanismus,
> PTDs eigene Inhalte und keine fremden Namen, Texte oder Figuren.
> (O-2) **Pakete sind Daten, Texte und Art-Parameter — keine Skripte.** Braucht ein Paket neue Mechanik, kommt sie als
> allgemeiner, über Daten konfigurierter Baustein der Engine (Kap. 4 „Mechanik-Baukasten“), den auch PTD-Inhalte nutzen.
> (O-3) **Englisch als zweite Sprache.** Deutsch bleibt Quelle und Rückfall; PTD bekommt eine vollständige englische
> Fassung (international nützlich; Pitch-Builds sind englisch).
> (O-4) **Ein Paket je Build.** Aktivierung zur Build-Zeit (Export-Feature-Tag, z. B. `pack_<id>`) und in Debug-Builds
> über das Argument `--pack=<id>`; kein Paketwechsel in einem laufenden Release-Build.
> (O-5) **Determinismus.** Die Sprache wirkt nie auf die Simulation (Replays sind über Sprachen hinweg gleich). Ein
> Paket ändert Daten; deshalb gehen Paket-ID und Paket-Inhalts-Hash in `DB.data_hash`, den Run-Log-Kopf und die
> Spielstände; Replays, Spielstände und Bestenlisten gelten je Paket, mit klaren Ablehnungen bei Abweichung.
> (O-6) **IP-Firewall.** `validators/ip_words.gd` prüft weiter alle Grundinhalte; ein Paket mit erklärtem Lizenzblock
> ist nur für seine eigenen Texte ausgenommen; die öffentliche CI schlägt fehl, wenn je ein Paket mit fremden Inhalten
> in dieses Repository gelangt — ohne fremde Begriffe an neuen Stellen aufzulisten.
>
> Alles Weitere sind Detailentscheidungen dieses Dokuments (**SP-1 … SP-22**, Kap. 0.3). O-1 setzt 04 §2.4 Schritt 6 (a)
> um („nichts wird infiziert: getrennte Codebasis, getrennte Texte“). Bedingungen und Schritte des Lizenzpfads in 04
> §2.4 bleiben unberührt: Dieses Dokument baut Fähigkeiten, keinen Pitch.
>
> **Abgestimmt auf** `00_BRIEF.md` (Kap. 4 „Sprache“, Vorrangklausel), `01_GDD.md` (§11.1 M.O.D.-Ton, §14 UX),
> `02_TECH.md` (§0.4 Schichten, §1 Dateibaum, §3.3 `DB`, §4.1 Texte als deutscher Quelltext, §4.5 Validierung, §6.4
> Save-Format, §11 Tests, §12.3 Export, §12.4 CI, §13 Konventionen), `03_ART.md` (§5.3–5.5 Figuren-Baukasten, F8
> Glyphen), `04_STRATEGIE_ROADMAP.md` (§2.2–2.5 IP, Distanz-Review, E2), `05_LIVE_MODUS.md` (Determinismus,
> Bestenlisten, `data_hash`), `06` (§0.3 IP-Hinweis, L-1 … L-7, §5.9 Filter), `07_ECHTZEITKAMPF.md` (§3.3 Tick-Ablauf,
> §4.9 Gegner-Schema, §12.10 Änderungsanträge), `08_CASTING.md` (§1.2 Wortform, §4.4 Platzhalter, P-1), `09_STAFFELN.md`
> (§1.1 Glossar, §1.2 Sprachregel, §3.1 Kulissen, §3.4 Boss-Baukasten, §11.4 Dateieigentum) und
> `10_MINISPIEL_STEMPELDUELL.md` (Regelbuch, eigener `rules_hash`). Code-Stand: `main` @ `cffb177` (07 R1–R5b, 08 K0–K3,
> 09 ST0 und ST1-A … G mit Recall, 10 SD2 gelandet; 09 ST1-H Staffel-UI und ST1-I Harness laufen parallel).
>
> **Status:** Design-Vertrag für die Pakete **P1, L1–L5, A1, MB1–MB8 und PB** (Kap. 5). Für Sprachen, Inhaltspakete und
> den Mechanik-Baukasten gilt dieses Dokument im Rang von `02_TECH`; was davon den Echtzeitkampf berührt, wird erst über
> den Änderungsantrag **CR-39** an `07` verbindlich (Kap. 4.11). Die Vorrangklausel des Briefs bleibt unberührt. Es
> ändert keinen Code; es nennt zu jeder Aussage über den Code Datei und Funktion (Stand `cffb177`).
>
> **Stand 11-P1 (2026-10-13, Branch `ptd/p1`):** Der Paket-Lader ist umgesetzt (Kap. 5.3 „Stand 11-P1“, 02_TECH §0.9):
> `PackDef`, `PackLoader` und die Paketregeln, der Vertrags-Durchgang 11-P1, `DB.pack`, Aufzeichnungen und Ablehnungen,
> die Fehlerkarte beim Start, das Beispielpaket „Testbild“ (ohne PO-Dateien, die kommen mit L1) und die IP-Firewall
> Schichten 1 und 2 in der Variante F-20. Ohne Paket bleibt alles bitgleich: `DB.data_hash()` vor und nach P1
> `6c17e6ce…3ec3`, `fullrun.sh` mit gleichen Ereigniszeilen und Statistiken (bis auf den Münzwurf der Darstellung in
> `mod_tags`, Kap. 5.3).
>
> **Stand 11-L1 (2026-10-13, Branch `ptd/l1`):** Die i18n-Infrastruktur ist umgesetzt (Kap. 5.4 „Stand 11-L1“:
> Prüfergebnisse P-1 … P-6, Entscheidungen L1-1 … L1-15; 02_TECH §0.4, §13.1): `Tx`, `LocaleLoader` mit eigenem
> PO-Leser (der strenge Parser `PoFile` nur für Werkzeuge und Tests), `game/locale/` mit den vier POT-Vorlagen
> (2 577 msgids) und leeren englischen PO-Dateien, Einstellung „Sprache / Language“ (nur im Titelmenü änderbar; mit
> Paket nur dessen Sprachen), `--lang`, automatische Übersetzung aus, Extraktor und `tools/i18n.sh`, Lint mit `PENDING`
> (911 Funde in 91 Dateien) und die PO-Dateien von „Testbild“ (Paket-PO über der Basis-PO, dieselben Regeln). Deutsch
> bleibt bitgleich; Englisch ändert bis L2/L3 nur Zahlen-, Zeit- und Datumsformate.
>
> **Stand 11-A1 (2026-10-18, Branch `ptd/a1`):** Die Art-Kit-Erweiterungen sind umgesetzt (Kap. 4.10 „Stand 11-A1“,
> 03_ART §5.3–5.5): die Basis `cat` (Stand und Sitz, Stil `fur` kurz/lang und `pattern` in fünf Mustern, 1 152–1 444
> Tris in 3 Meshes), die Props `tiara`, `sunglasses`, `bathrobe`, `sandals`, `shorts`, `jacket`, die Look-Art `wear`
> („ohne“, „Jacke“), der Vertrags-Durchgang 11-A1 und PTDs Regeln 1–4 im Validator. Jede bestehende Figur baut
> bitgleich; die Full-Runs zeigen dieselben Ereigniszeilen wie `main`; `DB.data_hash()` ändert sich nur durch
> `looks.json`.
>
> **Namen:** Der Orchestrator nennt die Mechaniken M1–M8. Weil „M0–M8“ die Module aus 02_TECH sind (M1 ist der
> CTB-Kern, M8 das Live-Modul), heißen sie hier **MB1–MB8** (Mechanik-Baukasten), gleicher Inhalt. Die übrigen
> Paketnamen bleiben: **P1** (Paket-Lader), **L1–L5** (Sprachen), **A1** (Art-Kit), **PB** (Paket-Build). Die
> Stimmregeln aus 06 heißen hier immer „06 L-1 … L-7“ (mit Bindestrich), die Pakete „L1 … L5“ (ohne). Andere Dokumente
> zitieren die Pakete mit Präfix: „11-P1“, „11-L2“.
>
> **Konventionen:** **[zu prüfen]** = Annahme, die vor der Umsetzung geprüft werden muss (meist Godot-API oder Recht);
> **[zu messen]** = Zahl aus Schätzung, das Paket misst sie. „PT“ = Personentage mit KI-Unterstützung. Englische
> Begriffe stehen in Kapitel 2 und als Beispiele; für deutsche Spielertexte gelten weiter PTD-Begriffe und die
> Sprachregel aus 09 Kap. 1.2 („Etage“, „Stufe“, „Kandidat:in“).

## Inhalt

0. Kurzfassung (fünf Sätze, warum zwei Fähigkeiten, Entscheidungen SP-1 … SP-22, bewusst nicht drin)
1. Sprachen (Bestand, Format, was übersetzt wird, Datenfelder, Platzhalter und Plural, Wortform, Zahlen und Daten, Länge
   und Schrift, Einstellung und Boot, Determinismus, Werkzeuge, Tests, Filter und M.O.D. live)
2. Englisches Glossar und Stimme (Regeln, Glossar in vier Teilen, riskanteste Begriffe, M.O.D., Mopsula, Beispiele)
3. Inhaltspakete (Grundsatz, Ordner, `pack.json`, Overlays und Zusammenführen, Validierung, Texte, Art, Aktivierung,
   Determinismus und Aufzeichnungen, Grenzen, Versionen, IP-Firewall, privates Repository, Beispielpaket „Testbild“)
4. Mechanik-Baukasten (Grundsätze, MB1–MB8, Art-Kit A1, Änderungsantrag CR-39)
5. Umsetzung (Reihenfolge, Pakete mit Aufwand, Einzelheiten, Gates, Tests, Dateieigentum, Folgeänderungen)
6. Risiken und offene Fragen mit Empfehlung

---

## 0. Kurzfassung

### 0.1 In fünf Sätzen

1. PTD bekommt **Englisch** als zweite Sprache: Deutsch bleibt Quelltext, Englisch kommt als **gettext-PO** dazu, und
   jede Anzeige läuft über einen kleinen Helfer `Tx` statt über verstreute `tr()`-Aufrufe.
2. Ein **Inhaltspaket** ist ein Ordner aus JSON-Overlays, PO-Dateien und Art-Parametern, der vor der Validierung in die
   Rohtabellen gemischt wird — keine Skripte, keine Szenen, keine Shader.
3. Ein Build trägt **höchstens ein Paket**; Paket-ID und Inhalts-Hash stehen in `data_hash`, Run-Log und Spielstand, und
   ohne Paket bleibt jeder Hash, jedes Replay und jede deutsche Ausgabe **bitgleich** zu heute.
4. Fremde Inhalte leben nur in einem **privaten Paket-Repository**; im öffentlichen sorgen eine Ordner-Whitelist, die
   Ausnahme-Regel in `ip_words` und **geheime Fingerabdrücke** dafür, dass die CI jedes fremde Paket abweist.
5. Neue Mechaniken für Pakete kommen als **IP-neutrale Bausteine** (Aasfresser, Teilung, Bahnen-Boss, Umgebungssieg,
   Spawner, Ort als Gegner, Wurf-Sprengsätze, Gesprächsboss) über den Antrag **CR-39** an 07 — und jeder hat einen
   PTD-Einsatz.

### 0.2 Warum zwei Fähigkeiten statt eines Pitch-Branches

Ein Pitch-Branch mit fremden Namen im öffentlichen Repository wäre der schnellste Weg — und verletzt O-1 schon beim
ersten Commit. Ein privater Fork der ganzen Engine wäre sauber, driftet aber ab: Jede Korrektur müsste zweimal landen.
Inhaltspakete trennen dagegen **Mechanismus** (öffentlich, getestet, von PTD selbst genutzt) und **Inhalt** (privat).
Die Engine ist dafür schon gut vorbereitet: Alle Spielinhalte sind Daten (`GameData.TABLES`, 23 Tabellen, `core/data/
game_data.gd`), alle Texte sind deutscher Quelltext mit „msgid = deutscher Text“ (02_TECH §4.1), und der Kern sieht nur
IDs (08 P-1; `StateHash.EXCLUDED_KEYS` und `display_name` bleiben aus Hashes, `core/live/state_hash.gd`). Was fehlt, ist
der Weg, Daten von außen kontrolliert zu ändern, und die zweite Sprache. Beides nützt PTD unabhängig vom Pitch: Englisch
für Store, Presse und Playtests, Pakete für Events, Saisons, Testinhalte und Varianten ohne Code.

### 0.3 Entscheidungen

Herkunft: **O** = Rahmen des Orchestrators, **D** = Detailentscheidung dieses Dokuments.

| Nr. | Thema | Entscheidung | Herkunft | Kap. |
|---|---|---|---|---|
| SP-1 | Format | **gettext-PO, msgid = deutscher Quelltext** (bestätigt 02_TECH §4.1). Keine deutsche PO-Datei; Englisch in `locale/en/<domain>.po`; je Sprache wird beim Start **eine** zusammengeführte Übersetzung gebaut | O · D | 1.2 |
| SP-2 | Kontexte | `msgctxt` = Tabellenname für Datentexte (`items`, `skills` …); `<tabelle>:<id>` nur für echte Homonyme (Liste `locale/contexts.json`, z. B. `sts_taunt`/`sts_taunted`, beide „Provoziert“); Codetexte ohne Kontext, außer sie sind mehrdeutig | D | 1.5 |
| SP-3 | Helfer | Ein Helfer **`Tx`** (`core/data/tx.gd`) für Text, Plural, Datentext und Zahlenformat; **automatische Übersetzung der Controls global aus** (sonst übersetzt Godot englische Ausgaben ein zweites Mal: „Gift“ ist das deutsche msgid des Elements Gift) | D | 1.2, 1.9 |
| SP-4 | Kern | Der Kern übersetzt nie in Zustand, Befehle, Logs oder Hashes; er gibt IDs, Tags oder deutsche msgids aus. Anzeige-Funktionen im Kern (z. B. `SleepText`) sind reine Darstellung und bekommen Sprache und Format von außen | O · D | 1.10 |
| SP-5 | Sprachwahl | Zeile **„Sprache / Language“** mit *Automatisch / Deutsch / English*; Schlüssel `[game] language`; Automatisch = Deutsch bei deutscher Systemsprache, sonst Englisch; nur im Titelmenü änderbar; `--lang=<code>` für flüchtige Läufe (Standard dort `de`) | D | 1.9 |
| SP-6 | Englisch | **US-Englisch**: „1,700“, „1.5“, „36%“, „8:00 PM“, „Mon, Oct 12“, Anführungszeichen “…” | D | 1.7 |
| SP-7 | Wortform | Englisch braucht keine Wortform: „contestant“, neutrale Berufsbezeichnungen, kein „he/she“ über die Persona (notfalls singular *they*). Die Casting-Zeile „Wortform“ ist auf Englisch ausgeblendet; `form` bleibt gespeichert | D | 1.6 |
| SP-8 | Werkzeuge | Extraktor in GDScript (Code-Literale, Szenen-Texte, Datenfelder) → `locale/pot/*.pot`; Merge mit GNU `msgmerge`; Abdeckungsbericht; Lint gegen deutsche Literale außerhalb von `Tx` (Ausnahme `# no-i18n:`) | D | 1.11 |
| SP-9 | Platzhalter | Benannte Platzhalter `{…}` ab zwei Argumenten; Platzhalter der Übersetzung ⊆ Platzhalter des msgid (Englisch darf `{cand}` weglassen); Zahlen werden vor dem Einsetzen mit `Tx` formatiert | D | 1.5 |
| SP-10 | Glossar | Englisches Glossar mit IP-Abstandsprüfung je Begriff und englischer Sprachregel („Floor“, „Level“, „contestant“; nie die Leitbegriffe bekannter Werke des Genres) | O · D | 2 |
| SP-11 | Pakete | Pakete sind nur Daten: `game/packs/<id>/` mit `pack.json`, `data/*.json` (Overlays), `locale/<lang>.po`, `art.json`; keine Skripte, Szenen, Shader oder Binärdateien | O · D | 3.1–3.2 |
| SP-12 | Zusammenführen | `PackLoader.merge` wirkt auf die Rohtabellen **vor** `GameData._load`: deaktivieren → patchen (JSON Merge Patch je ID) → hinzufügen; danach der `DataValidator` mit unveränderten Regeln plus Paketregeln; Herkunft je Eintrag geht an `ip_words` | O · D | 3.4–3.5 |
| SP-13 | Art | `art.json` = Patches der ModelSpecs (Farben, Basis, Props, Skala); nicht im Paket-Hash, weil Modelle nur Darstellung sind; Daten-Overlays dürfen `model` nicht anfassen | O · D | 3.7 |
| SP-14 | Aufzeichnung | `pack_hash` = SHA-256 über `pack.json` + Daten-Overlays; `data_hash` hängt `pack:<id>:<hash>` an; Run-Log-Kopf `pack`, `pack_version`, `pack_hash` **nur mit Paket**; Spielstand-Block `pack`; Nutzerdaten unter `user://packs/<id>/`; Ablehnungen `other_pack`, `other_pack_version`, `pack_engine`, `pack_invalid`, `pack_ambiguous`, `pack_missing` | O · D | 3.9 |
| SP-15 | Aktivierung | Feature-Tag `pack_<id>`; `--pack=<id>` nur in Debug-Builds; ein Paket je Lauf; Grund-Exporte schließen `packs/*` aus | O · D | 3.8 |
| SP-16 | Versionen | `pack_schema` (Engine-Konstante `PackLoader.PACK_SCHEMA`), Spielversions-Bereich in `pack.json`, gepinnter Engine-Commit für den privaten Build; Prüfung beim Start | D | 3.11 |
| SP-17 | IP-Firewall | Drei technische Schichten und ein Ablauf: Ordner-Whitelist + `.gitignore`; `ip_words`-Ausnahme nur für die IP-Abstandslisten und nur für lizenzierte Herkunft; **HMAC-Fingerabdrücke** fremder Begriffe mit geheimem Schlüssel, dazu eine Baseline für Bestand | O · D | 3.12 |
| SP-18 | Privates Repo | Eine dokumentierte CI-Vorlage (Kap. 3.13), nicht aktiv in diesem Repository | O | 3.13 |
| SP-19 | Beispielpaket | **„Testbild“** aus PTDs eigenen Inhalten (benennt die Rattenkönigin um, färbt Mopsula um, zwei Zeilen, ein Look, Overrides auf Deutsch und Englisch); läuft in CI | O · D | 3.14 |
| SP-20 | Mechanik | **MB1–MB8** als Felder im Schema `enemies.json → rt` bzw. `items.json → rt` und als Phasen-Op; neue Laufzeitfelder werden **nur geschrieben, wenn gesetzt** — ohne Daten bleibt jeder Kampf bitgleich; Umsetzung über **CR-39 a–h** | O · D | 4 |
| SP-21 | Art-Kit | **A1**: Basis `cat` (Vierbeiner neben `pug`), Props `tiara`, `sunglasses`, `bathrobe`, `sandals`, `shorts`, `jacket`, Look-Art `wear`; PTD-Grundinhalte behalten ihre Regeln (keine Krone, kein Diadem an Mopsula; keine Katze als Party-Figur) | O · D | 4.10 |
| SP-22 | Reihenfolge | **P1 ∥ L1 → L3 ∥ L2 → L4** bis zum Meilenstein **EN-1** (englischer Build mit „Testbild“); Staffel-UI erst nach ST1-H/ST1-I; PB nach P1; A1 und MB unabhängig | O · D | 5.1 |

### 0.4 Bewusst nicht drin

- **Kein Schlüsselsystem** (`UI_TITLE_START`): deutsche Texte bleiben lesbar im Code und in den Daten (02_TECH §4.1).
- **Keine dritte Sprache** in dieser Runde; das Format trägt sie (eine weitere `locale/<code>/`), Kapitel 1.7 und 1.8
  nennen, was sie bräuchte.
- **Kein Paketwechsel zur Laufzeit** und kein Paket-Menü (O-4); keine Pakete aus dem Internet, keine Mods in Release-
  Builds.
- **Keine Skripte, Szenen, Shader, Ressourcen oder Binärdateien in Paketen** (O-2); Texturen, Modelle und Klänge eines
  Pakets sind eine spätere Stufe (F-6).
- **Keine Übersetzung im Kern**, kein übersetzter Text in Spielständen, Replays oder Bestenlisten (O-5).
- **Keine Sprachausgabe** (M.O.D. spricht in Untertiteln, 01_GDD §11.1).
- **Keine fremden Begriffe**, auch nicht als „verbotene Wörter“ im öffentlichen Code (Kap. 3.12).

---

## 1. Sprachen (i18n)

### 1.1 Bestand im Code (Stand `cffb177`)

| Thema | Heute | Fundstelle |
|---|---|---|
| Projekt | `[internationalization] locale/fallback="de"`, sonst nichts — keine Übersetzungsdateien, kein `locale/`-Ordner | `game/project.godot` |
| Konvention | Texte sind deutscher Quelltext, Anzeige über `tr(text)`, „gettext-Stil, spätere EN-Übersetzung per `.po`, kein Key-System“ | 02_TECH §4.1; 00_BRIEF Kap. 4 „Sprache“ |
| Helfer | `UiUtil.tr_text(s)` = `TranslationServer.translate(s)`; `format_line()` = `glyph_safe(tr_text(text).format(ctx))`; `member_name()` = `tr_text(def.title) + " " + name` | `scenes/ui/ui_util.gd` |
| Aufrufe | rund 80 `tr(` in 11 Dateien (40 davon in `scenes/exploration/event_interactable.gd`), 62 `tr_text(`, 20 `TranslationServer.translate(` (Kampf-UI, `explore_target.gd`), **0** `tr_n(`, **0** Textfelder in den 54 Szenen-Dateien (alle UI wird im Code gebaut) | `grep` über `game/` ohne `tests/` |
| Konstante Namen | `RARITY_NAMES`, `ELEMENT_NAMES`, `STAT_NAMES`, `STAT_SHORT` („STÄ“, „ABW“, „TMP“, „GLÜ“), `SLOT_NAMES`, `TYPE_NAMES`, `CATEGORY_NAMES`, `TARGET_NAMES` | `scenes/ui/ui_util.gd` |
| Zahlen | `fmt_int` → „12.345“, `fmt_signed`, `fmt_pct` → „36,0 %“; insgesamt sieben Stellen mit `replace(".", ",")` (`combat_style.gd:112`, `settings_menu.gd:329`, `menu_base.gd:145/147`, `ui_util.gd:84`, `explore_target.gd:261`, `skills_menu.gd:119`) | `scenes/ui/*` |
| Zeit und Datum | `SleepText`: `duration()`/`_unit(n, one, many)` (Plural von Hand), `short()` („1 T 20 Std.“), `clock_label` („Mo 20:00“), `date_label` („Mo 12.10.“), `_when_words` („heute um“, „morgen um“), `num()`, `_quoted()` („…“) | `core/season/sleep_text.gd` |
| Sprachwahl | Zyklus „Sprache“ mit nur „Deutsch“, gesperrt (`lang.disabled = true`) | `scenes/ui/settings_menu.gd` `_build()`, Z. 211–213 |
| Einstellungen | `FILE_VERSION 2`, Abschnitte audio, game, display, input, live, combat, season — **kein** Sprachfeld | `autoload/game_settings.gd` `load_from_disk()`/`save_to_disk()` |
| M.O.D.-Zeilen | `ModAnnouncer.pick()` wählt mit Rückfallkette, Abklingzeit und Gewicht über Shows Effekt-RNG; `format()` = `line.text.format(ctx)` **ohne** Übersetzung | `core/show/mod_announcer.gd` |
| Persona | `PersonaText.CANDIDATE` (f „Kandidatin“, m „Kandidat“, n „Kandidat:in“), `job()` mit den Formen n/f/m aus `origins.json`, `club()` = „Ihr“/„Ihre“ + Text nach `club.g`; `MAX_LEN`, `LINE_MAX 110` | `core/show/persona_text.gd` |
| Live-M.O.D. | `ModLiveSummary` schreibt fest `"lang": "de"`; der Dienst erlaubt nur `Literal["de"]`; `ModLineFilter` weist nicht-deutsche Zeilen ab (Stoppwort-Quoten aus `mod_filter.json`) | `core/show/mod_live_summary.gd`, `services/mod-brain/mod_brain/schema.py`, `core/show/mod_line_filter.gd` |
| Kern-Texte | Anzeige-Texte als Ereignis-`text`: „Erstschlag!“, „Hinterhalt!“ (`RtSim.start`), „Sendezeit überzogen!“; in der eingefrorenen Stempel-Engine „Präventivschlag!“ | `core/rt/rt_sim.gd`, `core/stempel/ctb/battle_state.gd` |

**Textmenge (gemessen):**

| Bereich | Texte | Wörter |
|---|---|---|
| `mod_lines.json` | 688 | 7 171 |
| `skills.json` (Name + Beschreibung) | 380 | 1 710 |
| `talents.json` | 336 | 1 484 |
| `origins.json` (alle Unterlisten) | 503 | 885 |
| `items.json` | 102 | 510 |
| übrige 17 Tabellen | ≈ 655 | ≈ 2 820 |
| **Summe `data/*.json`** | **≈ 2 664** (≈ 2 481 verschieden) | **≈ 14 580** |
| `data/stempel/*.json` | — | ≈ 1 380 |
| Code, spielerseitig | ≈ 1 100–1 500 Literale | ≈ 5 400–6 500 |
| Code, Entwickler und Logs | ≈ 1 000 Literale (Validator-Meldungen, `push_warning`, Debug) | bleibt |
| Besetzungsnamen `cast.json → names` | 384 | bleiben (Kap. 1.6) |

Die rund 2 300 textartigen Literale des Codes verteilen sich auf `core/data` 462 (fast nur Validator- und
Entwicklermeldungen), `scenes/ui` 406, `core/live` 224, `scenes/stempel` 206, `core/stempel` 166, `scenes/boot` 165 und
den Rest. Spielerseitig sind davon etwa die Hälfte bis zwei Drittel. Insgesamt sind **rund 22 000 Wörter** zu
übersetzen.

### 1.2 Format: gettext-PO mit deutschem Quelltext (SP-1)

| Kriterium | gettext-PO (msgid = deutscher Text) | Schlüssel-CSV (`KEY,de,en`) |
|---|---|---|
| Godot 4.7 | lädt `.po` als `Translation`; `tr(msg, ctx)`, `tr_n(msg, plural, n, ctx)`, `TranslationServer.translate(_plural)` | importiert CSV zu `.translation`-Dateien je Sprache; Kontext und Plural nur über Zusatzspalten (nicht mehr geprüft: Entscheidung PO, Kap. 5.4 P-6) |
| Bestand | passt zu 02_TECH §4.1 und zu allen heutigen `tr()`-Aufrufen; Daten bleiben unverändert | jeder Text bräuchte einen Schlüssel: 2 664 Datentexte und ≈ 1 300 Codetexte umbauen, Daten unlesbar |
| Werkzeuge | Industriestandard: `msgmerge`, `msgfmt --check`, Poedit, Weblate, Crowdin; Übersetzerkommentare (`#.`), Fundstellen (`#:`), `fuzzy`-Markierung | Tabellenkalkulation; keine Fundstellen, kein „fuzzy“ |
| Merges | eine Datei je Sprache und Bereich, Einträge unabhängig; Konflikte selten und lokal | alle Sprachen in einer Zeile: zwei Übersetzer:innen kollidieren in derselben Zeile |
| Mehrdeutige Wörter | `msgctxt` | eigener Schlüssel je Bedeutung (der Vorteil von Schlüsseln) |
| Plural | `msgid_plural` + `msgstr[n]` mit Pluralregel je Sprache | — |
| Platzhalter | im Text sichtbar, prüfbar gegen msgid | im Text sichtbar |
| Review | Diff zeigt deutschen Quelltext und Übersetzung nebeneinander | Diff zeigt Schlüssel |
| Schwäche | Ändert sich der deutsche Text, ändert sich das msgid: `msgmerge` macht den alten Eintrag „fuzzy“ | Schlüssel bleibt, Übersetzung veraltet unbemerkt |

**Entscheidung:** PO. Die Schwäche ist gewollt: Ein geänderter deutscher Text muss neu übersetzt werden, und „fuzzy“
macht das sichtbar. Es gibt **keine** `de.po` — Deutsch ist das msgid selbst, und ohne Eintrag zeigt Godot das msgid.

**Ablage:** `game/locale/en/<domain>.po` mit den Domänen `ui` (Code und Szenen), `data` (alle `data/*.json` außer
M.O.D.-Zeilen), `mod_lines` (`mod_lines.json` und `scenes.json`, die Sprechtexte) und `stempel` (`data/stempel/*.json`
und `scenes/stempel/**`). Vier Dateien statt einer halten Merges klein und erlauben paralleles Übersetzen (L3). Die
Vorlagen liegen in `game/locale/pot/<domain>.pot`, erzeugt vom Extraktor (Kap. 1.11), nie von Hand bearbeitet.

**Laden:** `LocaleLoader` (`core/data/locale_loader.gd`, neu) parst die PO-Dateien selbst (msgctxt, msgid,
msgid_plural, msgstr[n], `fuzzy`) und baut **eine** `Translation` je Sprache: erst die Basis-PO, dann die PO des aktiven
Pakets (überschreibt einzelne Einträge, Kap. 3.6). Grund für den eigenen Parser: Die Reihenfolge, in der der
`TranslationServer` mehrere Übersetzungen derselben Sprache befragt, ist nicht dokumentiert (mit genau einer
`Translation` je Sprache spielt sie keine Rolle, Kap. 5.4 P-1), und ein reiner Parser ist ohne Szenenbaum testbar.
`fuzzy`-Einträge gelten wie bei `msgfmt` als fehlend. Die gebaute
`Translation` wird beim `TranslationServer` angemeldet (`add_translation`, `set_locale`), damit bestehende `tr()`- und
`tr_text()`-Aufrufe während der Umstellung (L2) weiter funktionieren. Plural wählt `Tx` selbst aus der Tabelle
(Deutsch und Englisch: Form 0 für n = 1, sonst Form 1), unabhängig von der Pluralbehandlung einer selbst gebauten
`Translation` (`Translation.add_plural_message` gibt es in 4.7.2, `TranslationPO` nicht; Kap. 5.4 P-2). Messziel:
Laden ≤ 50 ms auf dem Referenz-Telefon **[zu messen, L4; Desktop: Kap. 5.4 P-5]**; sonst wird die zusammengeführte
Tabelle beim Export vorkompiliert.

**Der Helfer `Tx`** (`core/data/tx.gd`, `class_name Tx`, statisch, ohne Abhängigkeit von Autoloads):

```gdscript
class_name Tx extends RefCounted
## Every player-facing text goes through Tx (11 §1.2). msgid = the German source text; "" context = none.
static func t(msgid: String, ctx: String = "") -> String            # translated text (msgid if missing)
static func n(msgid: String, plural: String, count: int, ctx: String = "") -> String   # plural form
static func data(table: String, id: String, text: String) -> String # ctx = table, or "table:id" (contexts.json)
static func m(msgid: String) -> String                             # marker only: returns msgid unchanged (core texts)
static func lang() -> String                                       # "de" | "en"
static func fmt_int(v: int) -> String                              # de "12.345", en "12,345"
static func fmt_signed(v: int) -> String                           # "+12" / "-3" / "0" (L1-1)
static func fmt_dec(v_pm: int, decimals: int = 1) -> String        # per-mille input: de "1,5", en "1.5"
static func fmt_pct(p_pm: int, decimals: int = 1) -> String        # de "36,0 %", en "36.0%"
static func fmt_clock(minutes: int) -> String                      # de "20:00", en "8:00 PM"
static func fmt_weekday(wd: int) -> String                         # de "Mo", en "Mon"
static func fmt_date(day: int, month: int) -> String               # de "12.10.", en "Oct 12"
static func fmt_duration(sec: int) -> String                       # de "1 T 20 Std.", en "1 d 20 h"
static func quote(s: String) -> String                             # de „s“, en “s”
```

Zahlen kommen als Ganzzahlen bzw. Promille herein (Kern-Regel 02_TECH §13: keine Floats in der Logik); nur die Anzeige
erzeugt Dezimaltrenner. Ohne geladene Übersetzung gibt `Tx` das msgid und die deutschen Formate zurück — genau die
heutige Ausgabe (Gate „deutsch bitgleich“, Kap. 5.9).

**Automatische Übersetzung aus (SP-3):** Godot übersetzt `Label.text`, `Button.text` und Tooltips standardmäßig selbst
(`Node.auto_translate_mode`, vererbt vom Wurzelknoten). Mit `Tx` sind die Texte schon übersetzt; eine zweite Übersetzung
wäre falsch, sobald ein englischer Text zufällig einem deutschen msgid gleicht — „Gift“ (englisch für „Geschenk“, 05)
würde zu „Poison“, weil `UiUtil.ELEMENT_NAMES["poison"]` das msgid „Gift“ hat. `Game._ready()` setzt deshalb
`get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`; eigene Fenster und Popups erben es
(geprüft: alle Fenster, Popups und Tooltips im Baum; dazu `root_node_auto_translate=false` in `project.godot`, Kap. 5.4
P-3). Übersetzt wird nur, was durch `Tx` geht.

### 1.3 Was übersetzt wird — und was nicht

| Übersetzt (spielerseitig) | Nicht übersetzt |
|---|---|
| alle Texte, die Spieler:innen im Spiel lesen: Menüs, HUD, Toasts, Dialoge, M.O.D.- und Chat-Zeilen, Szenen, Tutorial, Ergebnisse, Credits, Benachrichtigungen des Systems (09 §2.9), Stempelduell | Entwickler- und Logtexte: `push_warning`/`push_error`, Validator-Meldungen (`DataValidator`, `RtCheck`, `SdRulebook`), Test-Ausgaben, Debug-Overlays, Kommandozeilen-Hilfe |
| Datentexte der spielerseitigen Felder (Kap. 1.4) | IDs, Tags, Schlüssel, Bedingungen (`condition`), Platzhalternamen, Farbwerte, Pfade |
| Fehlermeldungen, die Spieler:innen sehen (Spielstand neuer als das Spiel, Paket fehlerhaft, Speichern gescheitert) | Begründungs-Codes in Befehlen und Ablehnungen (`sd_unavailable`, `other_pack` …) — die Anzeige übersetzt den Code |
| Exporte für Spieler:innen (Sendeplan als `.ics`, 09 §2.4) in der eingestellten Sprache | Spielstände, Replays, Run-Logs, Bestenlisten-Einträge, Journale (enthalten keine Anzeigetexte; Ausnahme siehe Namen, Kap. 1.6) |
| Store- und Paketnamen in `pack.json` (`name`), Lizenz-Credits | Eigennamen der Besetzung (`cast.json → names`) und Namen, die Spieler:innen eintippen |
| Fenstertitel `config/name` „Prime Time Dungeon“ | Spieltitel und Logo-Schriftzug (bleiben „PRIME TIME DUNGEON“, F-13) |

**Regel für Entwicklertexte:** Sie bleiben, wie sie sind (Code und Kommentare englisch, Validator-Meldungen gemischt).
Der Lint (Kap. 1.12) unterscheidet sie an der Funktion: Literale in `push_warning`, `push_error`, `print`,
`printerr`, `assert` und in den Fehlerlisten der Validatoren gelten als Entwicklertext; alles in UI-Bauteilen (`label`,
`button`, `toast`, `.text =`, `.tooltip_text =`) als Spielertext.

### 1.4 Datenfelder je Tabelle

Übersetzt werden genau die folgenden Felder (Spalte 2); alles andere in den Tabellen ist ID, Zahl, Enum oder Bedingung.
Der Kontext ist der Tabellenname (SP-2), bei Unterlisten `tabelle.unterliste`.

| Tabelle | Spielerseitige Felder | Hinweise |
|---|---|---|
| `statuses` | `name` | Homonym: `sts_taunt`/`sts_taunted` (beide „Provoziert“) → Kontext `statuses:sts_taunt` usw.; englisch *Taunting* / *Taunted* |
| `skills` | `name`, `desc` | Namen stehen in der Kampfleiste (07 §4.1): englisch nicht länger als deutsch |
| `items` | `name`, `desc` | |
| `classes` | `name`, `desc` | `:in`-Formen werden neutral („Track Runner“) |
| `party` | `name`, `title` | „Graf“ ist `title` von Mopsula → *Count* |
| `enemies` | `name`; `pseudo_units[].name` | drei Schichtleiterinnen teilen einen Namen: ein Eintrag |
| `floors` | `name`, `zones[].name`, `zones[].safe.name`, `layout.zones[].name`, `layout.safe_rooms[].name`, `quest.label` | „Etage 1 – Die Unterstadt“ → *Floor 1 – The Underground* |
| `lootboxes` | `name` | Requisitenkisten-Umbenennung (04 E2) zuerst im Deutschen, F-2 |
| `achievements` | `name`, `desc` | Bedingungen bleiben |
| `sponsors` | `name`, `slogan` | Marken-Fantasienamen: Markenprüfung der englischen Namen (Kap. 2.5) |
| `milestones` | `title` | |
| `mod_lines` | `text` | eigene Domäne `mod_lines`; Kontext `mod_lines` + Übersetzerkommentar mit Tag, Stimme und Zeichenlimit |
| `scenes` | `name`, `lines[].text` | Domäne `mod_lines` |
| `talents` | `name`, `desc` | |
| `species` | `name`, `desc` | |
| `marotten` | `name`, `desc` | |
| `twists` | `name`, `desc` | |
| `origins` | `entries[].name`, `role.{n,f,m}`, `jobs[].{n,f,m}`, `flavor`; `hobbies[].name`, `hobbies[].club.text`; `traits[].name`, `rivals[].name`, `brands[].name`, `gags[].name` | englisch nur **eine** Form je Beruf (Kap. 1.6); `keywords` sind keine Texte, sondern Suchstämme: englische Stämme in `locale/en/keywords.json` |
| `looks` | `name` | |
| `seasons` | `name` | |
| `professions` | `entries[].name`, `recipes[].name`, `materials[].name`, `nodes[].name` | |
| `cast` | `entries[].name` (Profile „Statist:in“ …) | **nicht** `names[]` (Eigennamen, Kap. 1.6) |
| `themes` | `name`, `program[].name` | |
| `events.json` | heute Schlüssel `name_key`/`label_key` mit deutschen Rückfällen in `scenes/ui/event_info.gd` `NAME_KEYS` | Umstellung auf deutsche Textfelder (F-17); bis dahin trägt `event_info.gd` die msgids |
| `data/stempel/*` | Karten, Gegner, Zustände, Zeilen, Kosmetik, Auszeichnungen, Regeltexte von `rules.json` | eigene Domäne `stempel`; Kurznamen ≤ 7 Zeichen auch englisch (10) |
| `mod_filter.json` | — (Filterlisten, kein Anzeigetext) | englische Listen kommen dazu (Kap. 1.13) |

**Zeilen mit Zahlen** in Daten (z. B. „Heilt 180 HP“) bleiben Zahlen im Text: Der Übersetzer überträgt die Zahl. Ein
Test vergleicht die Ziffernfolgen von msgid und msgstr (Kap. 1.12), damit eine Balance-Änderung in den Daten nicht in
der Übersetzung veraltet: Ändert sich die Zahl, ändert sich das msgid und der Eintrag wird „fuzzy“.

### 1.5 Platzhalter, Plural, Kontexte (SP-2, SP-9)

**Platzhalter:** Heute gibt es zwei Arten. Datentexte nutzen benannte Platzhalter (`DataValidator.TEXT_PLACEHOLDERS`:
`{name}`, `{floor}`, `{level}`, `{enemy}`, `{item}`, `{achievement}`, `{viewers}`, `{followers}`, `{sponsor}`,
`{count}`, `{member}`, `{seconds}`, `{sender}`, `{amount}`, `{pct}`, `{min}` und die Persona-Platzhalter `{cand}`,
`{job}`, `{hobby}`, `{club}`, `{trait}`, `{rival}`, `{brand}`, `{job_text}`); Codetexte nutzen oft `%s`/`%d`. Regeln:

1. Ab **zwei** Argumenten benannte Platzhalter (`"{name} hat {count} Fans"`), weil Englisch die Reihenfolge ändert.
   L2 stellt `%`-Formate mit mehreren Argumenten um; ein Argument darf `%s`/`%d` bleiben.
2. Die Platzhalter einer Übersetzung sind eine **Teilmenge** der Platzhalter des msgid. Englisch darf `{cand}`
   weglassen (Kap. 1.6), nie einen neuen erfinden. `test_11_po_rules` prüft beides.
3. Zahlen werden **vor** dem Einsetzen formatiert (`Tx.fmt_int`), nie im Text: `ctx["viewers"] = Tx.fmt_int(v)`.
   `ModAnnouncer.format()` wandelt heute ganzzahlige Floats in Ints und setzt sie roh ein — L2b lässt `Show._full_ctx`
   die Zahlen-Platzhalter vorformatieren.
4. Platzhalternamen werden nie übersetzt; `{floor}` bleibt `{floor}`.

**Plural:** Es gibt heute keinen `tr_n`-Aufruf; Plurale stehen von Hand im Code (`SleepText._unit(n, one, many)`) oder
werden umgangen. Regel: Code mit einer Mengenangabe nutzt `Tx.n("{count} Kampf", "{count} Kämpfe", n)`. **Datentexte
haben keine Pluralformen** — die Daten-JSON kennt nur einen Text. Datenzeilen mit `{count}` werden deshalb
**zahlneutral** geschrieben („Kämpfe bisher: {count}“), deutsch wie englisch (F-16); `test_11_po_rules` warnt bei
`{count}` direkt vor einem Substantiv.

**Kontexte:** Gleiches deutsches Wort, verschiedene Bedeutung, braucht verschiedene msgids — sonst gibt es nur eine
Übersetzung. Für Daten ist der Kontext immer der Tabellenname (`items`: „Gift“ als Gegenstand wäre etwas anderes als
`ui`: „Gift“ als Element). Echte Homonyme innerhalb einer Tabelle stehen in `locale/contexts.json`
(`{"statuses": ["sts_taunt", "sts_taunted"]}`) und bekommen `<tabelle>:<id>`. Codetexte haben keinen Kontext, außer der
Extraktor findet dasselbe msgid in zwei Bedeutungen; dann setzt L2 `Tx.t("Stand", "season")`. Ein Bericht des Extraktors
listet alle msgids, die in mehreren Domänen oder Tabellen vorkommen, zur Prüfung.

**Übersetzerkommentare:** Der Extraktor schreibt zu jedem Eintrag Fundstelle (`#: data/items.json:itm_potion.name`),
Zeichenlimit (`#. max 32`), bei Zeilen Tag und Stimme (`#. tag boss_intro:enm_boss_hausmeister, voice mod`) und die
Platzhalter mit Beispielwert (`#. {cand} = Kandidatin|Kandidat|Kandidat:in`).

### 1.6 Wortform, Anrede und Namen im Englischen (SP-7)

**Deutsch heute:** Die Persona hat eine Wortform `form` (`f`/`m`/`n`, 08 §1.2), die nur die Formen von `{cand}` und
`{job}` wählt (`PersonaText.cand(form)`, `PersonaText.job()` aus `origins.json → jobs[].{n,f,m}`); M.O.D. siezt immer,
ohne „Frau/Herr“. `club()` wählt „Ihr“ oder „Ihre“ nach dem grammatischen Geschlecht des Clubs (`hobbies[].club.g`).
Mopsula duzt Kai („Kolleg:in. Setz dich.“).

**Englisch:**

| Thema | Regel |
|---|---|
| `{cand}` | immer **„contestant“** (kein *contestantess*); in vielen Zeilen entfällt `{cand}` ganz, weil „Contestant Alex“ steif klingt — erlaubt (Platzhalter-Teilmenge, Kap. 1.5) |
| `{job}` | eine neutrale Berufsbezeichnung je Eintrag (*animal keeper*, *firefighter*, *police officer*); die n/f/m-Formen der Daten werden englisch **eine** Übersetzung: Der Extraktor legt für `jobs[].f` und `jobs[].m` Einträge mit Kommentar „same as n“ an, die Übersetzung ist dreimal dieselbe |
| `{club}` | „your {club}“ ist im Code ein ganzer Satz: `club()` baut heute „Ihr “ + Text; L2 macht daraus `Tx.t("Ihr {club}")`/`Tx.t("Ihre {club}")`, beide englisch „your {club}“ |
| Pronomen | Zeilen über die Persona vermeiden „he/she“; wo nötig singular *they* („They came here to win.“). Gilt für M.O.D., Mopsula und Chat |
| Anrede | Englisch kennt kein Sie/Du. M.O.D.s Distanz entsteht über Wortwahl (*Contestant*, *dear viewers*, Paragrafen), Mopsulas Nähe über Anreden wie *my dear colleague* (Kap. 2.7/2.8) |
| Wortform-Wahl | Auf Englisch ausgeblendet (Casting-Seite 1, 08 §1.2): Sie ändert dort nichts. `form` bleibt im Profil gespeichert; wer auf Deutsch wechselt, sieht die gespeicherte Form (Standard `n`) |
| Namen der Besetzung | **Nicht übersetzt.** `cast.json → names` (384 Namen mit Form) wird beim Staffelstart gemischt und als `roster_text` („name\|form\|…“) in den gehashten Staffelblock geschrieben (`core/season/cast_model.gd`, `cast_member.gd`) — ein übersetzter Name änderte den Zustand. Die Namen sind international genug; einzelne Anzeige-Anpassungen gingen nur über die Anzeige (F-3) |
| Eingetippte Namen | bleiben, wie sie sind (`PersonaText.check_name`); englische Filterlisten siehe Kap. 1.13 |

### 1.7 Zahlen, Zeiten, Daten (SP-6)

| Format | Deutsch (heute, bleibt) | Englisch (US) | `Tx` |
|---|---|---|---|
| Ganzzahl | 12.345 | 12,345 | `fmt_int` |
| mit Vorzeichen | +12 / -3 / 0 (wie heute, L1-1) | +12 / -3 / 0 | `fmt_signed` |
| Dezimal | 1,5 | 1.5 | `fmt_dec` |
| Prozent | 36,0 % | 36.0% | `fmt_pct` |
| Uhrzeit | 20:00 | 8:00 PM | `fmt_clock` |
| Wochentag | Mo | Mon | `fmt_weekday` |
| Datum | 12.10. | Oct 12 | `fmt_date` |
| Dauer | 1 T 20 Std. | 1 d 20 h | `fmt_duration` |
| Countdown | 04:59 (`UiUtil.fmt_time`) | 04:59 | unverändert |
| Anführungszeichen | „…“ | “…” | `quote` |
| Gedankenstrich | – (Halbgeviert mit Leerzeichen) | — (Geviert ohne Leerzeichen) | in der Übersetzung |

Die Formate stehen in `locale/formats.json` (`{"de": {"thousands": ".", "decimal": ",", "pct": " %", "clock": "24h",
…}, "en": {…}}`), damit eine dritte Sprache nur Daten braucht. Kalenderdaten (Sendeplan, Login-Bilanz, 09 §5.4) kommen
als Tageszahlen aus dem Kern und werden erst in der Anzeige formatiert; der `.ics`-Export bleibt im ISO-Format.
`SleepText` (Kern, Anzeige-Helfer) bekommt die Format-Funktionen als Parameter bzw. ruft `Tx` — `Tx` liegt in
`core/data` und hängt nur von `locale/` ab, die Schichtregel (02_TECH §0.4) bleibt gewahrt.

### 1.8 Textlänge, Layout und Schrift

- **Länge:** Englisch ist im Mittel 10–30 % **kürzer** als Deutsch; einzelne Wörter werden länger („Etage“ → *Floor*,
  aber „Fähigkeiten“ → *Abilities*). Kritisch sind feste Felder: Leisten-Kurznamen, Party-Rahmen, Stufen-Plakette,
  Stempelkarten (Kurznamen ≤ 7 Zeichen, 10), Tabs, Chips.
- **Limits:** Alle Längenregeln der Validatoren gelten für die Übersetzung genauso — `MAX_TEXT_LEN 110` und
  `PersonaText.effective_length` (Platzhalter zählen mit ihrer Höchstlänge aus `PersonaText.MAX_LEN`), Namen 28, Formen
  24, Eigenschaften 16, Labels 24, Flavor 90 (`validators/origins.gd`), Talentnamen 32, Kulissennamen 40.
  `test_11_po_rules` prüft jede Übersetzung gegen das Limit ihres Felds (aus dem Übersetzerkommentar `#. max N`).
- **Layout:** Alle Bildschirme bauen sich im Code mit Containern auf (keine festen Pixel-Texte in Szenen), umbrechen und
  kürzen mit Ellipse (`UiUtil`). Englische Captures bei 1280 × 720 und im Telefonformat 2400 × 1080 mit `--touch`
  prüfen Überläufe (Kap. 1.12). `STAT_SHORT` englisch: STR, MAG, DEF, RES, SPD, LCK.
- **Schrift:** Englisch braucht keine neuen Glyphen außer “ ” ‘ ’ und —; `UiUtil.missing_glyphs`/`glyph_safe` (03_ART
  F8) laufen im Test über jede Übersetzung. Eine dritte Sprache mit anderen Schriftsystemen bräuchte Ersatzschriften
  (nicht in dieser Runde).

### 1.9 Spracheinstellung und Boot-Reihenfolge (SP-5)

**Einstellung:** `GameSettings` bekommt `language: String = "auto"` im Abschnitt `[game]` (`FILE_VERSION` bleibt 2: ein
fehlender Schlüssel liest sich als `auto`). Das Optionsmenü ersetzt den gesperrten Zyklus (`settings_menu.gd`
`_build()`, Z. 211–213) durch **„Sprache / Language“** mit *Automatisch / Deutsch / English* — die Zeile ist
zweisprachig, damit sie in der falschen Sprache auffindbar bleibt. *Automatisch* nimmt Deutsch, wenn
`OS.get_locale_language()` „de“ ist, sonst Englisch. Die Liste der Sprachen (Code und Eigenname je Sprache) steht in
`locale/languages.json`; ein Paket kann sie nur einschränken (`pack.json → languages`).

**Wann wechseln:** Die Sprache ist **nur im Titelmenü** änderbar (Optionen vom Titel aus); im Pausemenü ist die Zeile
sichtbar, aber gesperrt mit dem Hinweis „Im Titelmenü änderbar“. Grund: Viele Bildschirme bauen Texte einmal beim
Öffnen; ein Wechsel mitten im Lauf hinterließe gemischte Texte. Nach dem Wechsel baut der Titel sich neu auf
(`Router.goto(SCENE_TITLE)`), sonst nichts.

**Flüchtige Läufe:** `--lang=<code>` setzt die Sprache für Capture, Autoplay, Fullrun und Tests, ohne die Einstellung
zu speichern; ohne Argument nutzen flüchtige Läufe **Deutsch**, damit Captures und Tests unabhängig von der
Systemsprache des Rechners bleiben (`Game._detect_ephemeral()` erkennt sie schon).

**Boot-Reihenfolge:**

1. `DB._init()` lädt die Daten — mit Paket (Kap. 3.8) — und kennt danach `DB.pack`.
2. `Game._init()` lädt `settings.cfg` (oder nimmt bei flüchtigen Läufen die Standards) und ruft
   `LocaleLoader.apply(sprache, DB.pack)`: PO-Dateien lesen, Paket-PO darüberlegen, `Translation` anmelden,
   `TranslationServer.set_locale`. Die Sprache steht damit fest, **bevor** die erste Szene existiert.
3. `Game._ready()` schaltet die automatische Übersetzung am Wurzelknoten aus (SP-3) und ruft wie heute
   `apply_settings()`.
4. `boot.gd` `_build_logo()` zeigt die Bootkarte schon übersetzt („NOVA SYNDIKAT“ / „präsentiert“ sind msgids; die
   Umbenennung „NOVA MEDIENGRUPPE“ aus 04 E2 ist F-2).

`Game` ist der richtige Ort, weil `DB` vor `Game` lädt (Autoload-Reihenfolge Events, DB, Game, Show, Save, Router, Sfx;
`project.godot`) und die Einstellungen dort gelesen werden. Fehlt eine PO-Datei, bleibt es bei Deutsch, mit einer
Warnung im Log und — in Builds, die als englisch ausgeliefert werden — einem roten Gate in der CI (Kap. 5.9).

### 1.10 Determinismus über Sprachen (O-5, SP-4)

Die Sprache darf nie den Spielzustand berühren. Heute gilt das schon weitgehend; die Umsetzung hält es fest:

| Stelle | Warum sprachneutral | Regel ab L1 |
|---|---|---|
| Simulation | Läuft nur auf aufgezeichneten Ticks und Befehlen (`Game.record`, `RunLog`); Texte stehen in keinem Befehl | Befehle tragen IDs und Codes, nie Text (bestehende Regel 06 L-6) |
| Lesezeit | Blockierende Dialoge halten die Uhr an (`Game.is_timer_ticking()` verlangt `_blocking_dialogs == 0`); die Haltezeit der M.O.D.-Box hängt an der Zeichenzahl (`scenes/ui/mod_dialog.gd` `_read_time(chars)`), unter Autoplay ist sie fest | Längere englische Zeilen ändern Wanduhr, nie Ticks; die Bots lesen nie Text |
| Zeilenwahl | `ModAnnouncer.pick()` zieht mit Shows Effekt-RNG (`_fx_rng`), nicht mit dem Spiel-RNG | Die Wahl hängt an Tags und IDs, nie am Text; Englisch hat dieselben Zeilen-IDs |
| Hashes | `StateHash.EXCLUDED_KEYS` (play_time_sec, slot, player_name), `display_name` wird aus `of_rt` entfernt; `Combatant.model` steht in keinem Snapshot | Kein übersetzter Text in Snapshots; `Tx` liegt außerhalb jeder Hash-Funktion |
| Ereignisse | Kern-Ereignisse tragen Tags oder deutsche msgids („Erstschlag!“) | Die Anzeige übersetzt `ev.text` mit `Tx.t`; der Kern markiert seine msgids mit `Tx.m()` (nur Markierung, gibt den Text unverändert zurück) |
| Besetzung | Namen stehen gehasht im Staffelblock | nie übersetzt (Kap. 1.6) |
| Freitext im Casting | `PersonaRules.map_text()` ordnet Freitext über `keywords` einem Vorleben zu; gespeichert und aufgezeichnet wird die **ID** | Englische Suchstämme (`locale/en/keywords.json`) ändern nur den Vorschlag, nie ein Replay |

**Prüfung:** `test_11_lang_determinism` spielt dieselben Befehlsfolgen (Erkundung, Echtzeitkampf, Staffel-Tag,
Stempelduell) mit `de` und `en` und vergleicht `StateHash` und Ereignisfolgen ohne `text`. Der Fullrun läuft in der CI
zusätzlich mit `--lang=en`; seine Zeilen „FULLRUN: stats {…}“ und „FULLRUN: OK …“ müssen mit dem deutschen Lauf
übereinstimmen (Gate, Kap. 5.9). Ein Replay, das auf Deutsch aufgezeichnet wurde, läuft auf Englisch bitgleich.

### 1.11 Werkzeuge: Extraktor, Merge, Abdeckung (SP-8)

**`tools/i18n.sh`** (Shell, ruft Godot headless und GNU gettext):

| Befehl | Wirkung |
|---|---|
| `i18n.sh extract` | Extraktor (`game/tests/tools/i18n/extractor.gd` über `i18n_tool.gd`, headless) schreibt `locale/pot/{ui,data,mod_lines,stempel}.pot` |
| `i18n.sh merge` | `msgmerge --update --backup=none --no-wrap --previous locale/en/<d>.po locale/pot/<d>.pot` je Domäne (Reihenfolge der POT, L1-8); neue Einträge leer, geänderte „fuzzy“ (mit dem alten msgid als `#|`), entfallene als `#~`; eine fehlende PO legt `msginit` an |
| `i18n.sh stats [--pack=<dir>]` | Abdeckung je Domäne und Tabelle: übersetzt / fuzzy / leer, Wörter offen; mit Paket zusätzlich die Basis-msgids, die Namen enthalten, die das Paket umbenennt (Kap. 3.6; Stand 11-L1: der Name ohne führenden Artikel, gleich in welcher Schreibung; Texte, die das Paket selbst patcht, zählen nicht) |
| `i18n.sh check` | `msgfmt --check-format --check-header`, Platzhalter-, Längen-, Ziffern- und Glyphen-Regeln (dieselben wie `test_11_po_rules`), POT aktuell (Extraktor-Lauf ohne Diff), PO mit ihrer POT gemischt |
| `i18n.sh lint [--file=res://…]` | (Stand 11-L1) die Funde von `test_11_literals` je Datei als `PENDING`-Tabelle zum Einfügen; mit `--file` die Zeilen einer Datei |

**Extraktor:** Drei Quellen, jede mit Fundstelle:

1. **Code:** Literale in `Tx.t("…")`, `Tx.n("…", "…", …)`, `Tx.m("…")` und — während L2 — `tr("…")`, `tr_text("…")`,
   `TranslationServer.translate("…")` in `scenes/`, `autoload/`, `core/`, `art/`. Der Literal-Parser aus `test_09_terms`
   (`literals(source)`, Kommentare übersprungen, dreifache Anführungszeichen) wird wiederverwendet. Nicht-literale
   Argumente meldet er als Fund „dynamisch“ (die Daten sind dann die Quelle).
2. **Szenen:** Textfelder (`text`, `tooltip_text`, `placeholder_text`, `title`, `dialog_text` — dieselbe Liste wie
   `test_09_terms.SCENE_TEXT_PROPS`) aller `.tscn`/`.tres`; heute leer, damit es leer bleibt oder erfasst wird.
3. **Daten:** die Felder aus Kap. 1.4, gelesen über `GameData` (normalisiert) bzw. `SdRulebook`, mit Kontext und Limit.

Der Extraktor sortiert stabil (Domäne, Datei, Fundstelle), damit POT-Diffs klein bleiben, und schreibt keine Zeitstempel
in den Kopf. Die POT-Dateien sind eingecheckt; `i18n.sh check` in der CI schlägt fehl, wenn sie veraltet sind.

**Ablauf für Übersetzer:innen:** `extract` → `merge` → `en/*.po` bearbeiten (Poedit oder Editor; KI-Entwurf mit
Glossar aus Kapitel 2 als Vorgabe) → `check` → Review (Kap. 5.7). Konflikte in PO-Dateien löst man durch erneutes
`merge` nach dem Zusammenführen.

### 1.12 Tests (Sprachen)

| Test | Prüft |
|---|---|
| `test_11_po` | Parser von `LocaleLoader`: msgctxt, Plural, Fortsetzungszeilen, Escapes, `fuzzy`, Kommentare; Rundreise mit `msgfmt`-geprüften Beispielen |
| `test_11_locale` | Spracheinstellung (auto/de/en, OS-Sprache simuliert), `--lang`, Boot-Reihenfolge (Übersetzung steht vor der ersten Szene), Rückfall bei fehlender Datei, Paket-PO überschreibt Basis-PO |
| `test_11_tx_format` | alle `Tx.fmt_*` in beiden Sprachen; Deutsch identisch zu `UiUtil.fmt_int`, `fmt_pct` und `SleepText` heute |
| `test_11_po_rules` | je Eintrag in `locale/en/*.po`: Platzhalter ⊆ msgid, Längenlimit, gleiche Ziffernfolgen, keine fehlenden Glyphen, kein `{count}` vor einem Substantiv; Abdeckung (Bericht; Gate in englisch ausgelieferten Builds: 100 % ohne „fuzzy“) |
| `test_11_literals` | Lint: deutsche Literale (Umlaut, ß, „ oder ein Wort aus einer kleinen deutschen Stoppwortliste) in UI-Code außerhalb von `Tx`, Entwicklerfunktionen und `# no-i18n:`-Zeilen; mit Liste `PENDING` je Datei (schrumpft nur), wie `test_09_terms` |
| `test_11_terms_en` | englische Sprachregel (Kap. 2.1) über alle msgstr: keine „Lv“/„Lvl“, nie das Teilnehmerwort aus 09 S-12, „Floor“ nie vor `{level}`, „Level“ nie vor `{floor}`, Glossar-Pflichtbegriffe |
| `test_11_lang_determinism` | Kap. 1.10 |
| Capture-Rezepte | Titel, Optionen, Casting, Erkundungs-HUD, Safe Room, Pausemenü, Kampf-HUD, Ergebnisse, Stempelduell-Tisch, Staffel-Lobby (nach ST1-H) — je `--lang=en` bei 1280 × 720 und 2400 × 1080 `--touch`; die Bilder gehen in L4 durch die Sichtprüfung |

Die bestehenden ≈ 25 Testdateien, die deutsche UI-Texte wörtlich prüfen, bleiben deutsch (flüchtige Läufe sind
deutsch, Kap. 1.9). Englische Erwartungen stehen nur in den neuen `test_11_*`.

### 1.13 Filter und M.O.D. live auf Englisch

- **`mod_filter.json`** (geteilt von `ModLineFilter` und dem Dienst `services/mod-brain`, 06 §5.9) prüft heute nur
  deutsche Zeilen: Die Sprachprüfung weist englische Zeilen ab, und die Sperrlisten (Politik, Sexuelles, Beleidigungen,
  Gewalt, echte Marken, IP-Abstand, Herkunft) sind deutsch. Mit L5 bekommt die Datei je Liste einen Sprachschlüssel
  (`blocked.politics.en` …) und die Sprachprüfung einen Parameter „erwartete Sprache“. Die englischen Listen schreibt
  das Moderationsteam (06 §5.9) **[zu prüfen]**.
- **Casting-Freitext und Namen** (`PersonaText.check_name`, `check_free_text`, `REASONS`, `EXTRA_POLITICS`) prüfen mit
  denselben Listen; auf Englisch braucht das Casting die englischen Listen **vor** dem ersten englischen Build mit
  Casting (L2a hängt daran).
- **M.O.D. live (06-D):** `ModLiveSummary` sendet `"lang": "de"`, der Dienst kennt nur `de`. L5 macht daraus die
  eingestellte Sprache und erweitert `schema.py` um `en` samt englischem Prompt und Filter. Bis dahin ist M.O.D. live
  auf Englisch **aus** (die geschriebenen Zeilen laufen weiter).

---

## 2. Englisches Glossar und Stimme (SP-10)

### 2.1 Regeln für englische Spielertexte

1. **„Floor“** nur für Etagen („Floor 3“). Nie „Level“ oder „Stage“ für eine Etage; „F3“ nur in Dokumenten.
   Redewendungen wie *has the floor* bleiben erlaubt — das Wortspiel passt zur Show.
2. **„Level“** nur für die Stufe einer Figur oder eines Gegners („Level 12“). Nie „Lv“, „LV“ oder „Lvl“; in engen
   Anzeigen die runde Stufen-Plakette (nur Zahl, `scenes/ui/level_badge.gd`) mit Tooltip „Level 12“.
3. **„contestant“** für Kandidat:innen. Das Teilnehmerwort, das 09 S-12 und `test_09_terms` im Deutschen sperren, ist
   auch englisch gesperrt — in jeder Form.
4. **„Rank“** für Ränge (Berufe, Talente), **„League 1 / Duo League“** für die Liga-Stufen (09 §1.2 Nr. 3).
5. **M.O.D.** heißt „M.O.D.“ oder „your host“ — nie eine Bezeichnung als System oder KI des Dungeons (04 §2.3).
6. **TV-Sprache** für die Struktur (Season, Episode, Broadcast Schedule, Dress Rehearsal, Callback, Teardown, With a
   Net), **Büro- und Logistiksprache** für Kulissen — nie Struktur- oder Rangbegriffe aus Büchern oder Spielen.
7. **IP-Abstand:** Kein Begriff, der der Leitbegriff eines bekannten Werks dieses Genres ist. Die Glossar-Spalte
   „IP-Abstand“ prüft jeden Begriff; im Zweifel gewinnt das TV-, Büro- oder Logistikwort. Abgelehnte Übersetzungen
   beschreibt dieses Dokument nur, statt sie zu nennen. Dazu PTDs eigene Regeln: keine Unterwäsche-, Hosen-, Fuß- oder
   Barfuß-Wörter rund um die Liga (06 §0.3), keine Königs- und Kronenwörter für Mopsula (04 §2.3), keine Herkunft als
   Pointe.
8. **Schreibweise:** US-Englisch (*armor*, *color*, *center*); Namen von Systemen, Orten und Bossen in Title Case,
   Fließtext in Satzschreibung; „&“ nur in festen Regeltexten („no armor & no accessory“).

`test_11_terms_en` prüft die Regeln 1–3 mechanisch (Kap. 1.12) und wendet die Listen aus `ip_words` (`general_word`,
`mopsula_word`) samt englischen Gegenstücken der PTD-eigenen Wörter (Barfuß, Schuh, Unterwäsche; Königswörter für
Mopsula) auf jede Übersetzung an. Begriffe fremder Werke stehen **nicht** im Test, sondern nur als Fingerabdrücke
(Kap. 3.12).

### 2.2 Glossar: Show, Staffel, Produktion

IP-Abstand: **–** = Alltagswort, **niedrig**, **mittel**, **hoch** (wörtliche Übersetzung läge nah an einem bekannten
Werk; Wahl bewusst anders).

| Deutsch | Englisch | IP-Abstand / Hinweis |
|---|---|---|
| Kandidat:in, Kandidat:innen | contestant(s) | **hoch** — gesperrtes Teilnehmerwort (Regel 3) |
| Staffel · Folge · Sendeplan | Season · Episode · Broadcast Schedule | – |
| Auf Sendung · Vorlauf | On Air · Up Next | – |
| Generalprobe | Dress Rehearsal | – |
| Einsturz („wird abgebaut“) | Teardown („gets torn down“) | **hoch** — das wörtliche Wort benennt die Kernmechanik einer Buchstruktur, die 04 §2.3 als „hoch“ einstuft; der Kulissenabbau bleibt TV-Sprache |
| Rettung (durch die Regie) | Rescue (by the Production) | – |
| Mit Netz · Ohne Netz | With a Net · Without a Net | – (Untertitel im Menü: „Normal“ · „Hardcore“) |
| Weiße Weste · Noch dabei | Clean Record · Still Standing | – |
| Studiogast | Studio Guest | – |
| Besetzung · Schläfer · Aussteigen | Cast · Sleeper · Drop Out | – |
| Sendepause | Hiatus | – |
| Kalender · Am Stück | Calendar · Binge | – |
| Tagesprogramm · Programmpunkt · Programmtür | Daily Lineup · Segment · Segment Door | – |
| Kulisse | Set | – (der Kampfring heißt in Spielertexten „ring“, nicht „set“) |
| Regie · Regie-Notiz · Regie-Eingriff · Regie-Crashkurs | the Production · Production Note · Production Twist · Production Crash Course | – |
| Recall | **Callback** | – („Recall“ ist im Deutschen ein Castingshow-Scheinanglizismus; englisch heißt die zweite Castingrunde *callback*) |
| Casting · Vorleben · Vorleben-Vorsprung | Casting · Day Job · Day-Job Head Start | – |
| Quote · Zuschauer · Follower · Hype | Ratings · Viewers · Followers · Hype | – |
| Sponsor-Fenster · Werbepause · Show-Wetten | Sponsor Window · Commercial Break · Show Bets | – |
| Achievement | Achievement | – (Gattungsbegriff, 04 §2.2) |
| Safe Room | Safe Room | niedrig (Gattungsbegriff, 04 §2.3 „behalten“) |
| M.O.D. (Mediale Omnipräsente Direktorin) | M.O.D. (Media Omnipresent Director), *she* | **hoch** — nie als System oder KI des Dungeons bezeichnet (Regel 5) |
| NOVA SYNDIKAT | **NOVA Media Group**, kurz NOVA | **hoch** — das englische Wort für „Syndikat“ ist eine zentrale Instanz eines bekannten Werks (04 §2.3, E2: deutsch „NOVA MEDIENGRUPPE“, F-2) |
| Senderzentrale (Hub, 06 §7) | Network HQ | – |
| DUNGEON PRIME TIME (die Show) · PRIME TIME DUNGEON (das Spiel) | unverändert | Markenrecherche 04 §2.5 |

### 2.3 Glossar: Etagen, Orte und Bosse

| Deutsch | Englisch | IP-Abstand / Hinweis |
|---|---|---|
| Etage | Floor | – (Regel 1) |
| Treppe | Stairs | mittel — immer „Stairs“, kein anderes Treppenwort für den Ausgang einer Etage |
| Revier-Boss (früher Quartier-Boss) | **Turf Boss** | **hoch** — kein englisches Wort für einen Verwaltungsbezirk vor „Boss“: Diese Boss-Hierarchie nennt 04 §2.3 typisch für ein bekanntes Werk |
| Etagenboss | **Headliner** | **hoch** — die wörtliche Übersetzung ist Leitbegriff mehrerer bekannter Werke des Genres; „Headliner“ ist TV-Sprache und sagt, wer der Star der Etage ist |
| Großes Finale | Grand Finale | – |
| Show-Boss (goldgerahmte Elite, 06 §2.6) | **Showstopper** | niedrig |
| Etage 1 – Die Unterstadt | Floor 1 – **The Underground** | **hoch** — die wörtliche Übersetzung ist der Name der Hauptstadt eines bekannten Online-Rollenspiels; „The Underground“ ist U-Bahn und Unterwelt zugleich |
| Gleis 9 | **Track 9** | mittel — das andere englische Wort für „Gleis“ mit einer Zahl erinnert an einen berühmten Bahnsteig einer Jugendbuchreihe |
| Die Rattenkönigin von Gleis 9 | The Rat Queen of Track 9 | mittel — der Plural ist Titel einer bekannten Fantasy-Comicreihe; Ersatz „The Rodent Queen of Track 9“ liegt bereit **[Distanz-Review]** |
| Der Hausmeister | The Janitor | – |
| Kiosk 24/7 · Pumpenhaus · Stellwerk | Kiosk 24/7 · Pump House · Signal Tower | – |
| Bahnsteig Nord · Thronsaal | North Platform · Throne Room | – (der Thron gehört der Rattenkönigin, nie Mopsula) |
| Passage Ewiger Rabatt | Eternal Sale Arcade | – |
| Die Filialleiterin im Dauerlächeln · Der Ausverkauf | The Store Manager with the Permanent Smile · The Clearance Sale | – |
| Der Fundus · Die Requisiteurin · Die Garderobe | The Prop Vault · The Prop Master · The Wardrobe | – |
| Das Paketzentrum · Die Schichtleiterin · Der Paketberg | The Parcel Hub · The Shift Supervisor · The Parcel Mountain | – |
| Amt für Etagenwesen · Der Sachbearbeiter · Der Nummernautomat | Bureau of Floor Affairs · The Caseworker · The Ticket Dispenser | – |
| Erlebnisbad Chlorado · Die Bademeisterin · Die Wellenmaschine | Chlorado Water Park · The Lifeguard · The Wave Machine | – |
| Rechenzentrum „Wolke 7“ · Der Admin · Der Kabelkrake | “Cloud Nine” Data Center · The Admin · The Cable Kraken | – |
| Das Hauptstudio · Die Aufnahmeleitung · Die Sendeleitung | The Main Studio · **The Stage Manager** · The Head of Broadcasting | – („Stage Manager“ statt der TV-Berufsbezeichnung mit „Floor“, Regel 1) |

### 2.4 Glossar: Figuren, Kampf, Fortschritt

| Deutsch | Englisch | IP-Abstand / Hinweis |
|---|---|---|
| Graf Mopsula · der Graf | **Count Mopsula** · the Count | mittel — Wortspiel auf einen gemeinfreien Vampirgrafen; eine bekannte Zeichentrickfigur nutzt dasselbe Muster mit einem anderen Tier. Im Deutschen gleich nah, also keine Sprachfrage, aber Teil der Markenrecherche „Graf Mopsula“ (04 §2.5). Keine Königs-, Kronen- oder Thronwörter in seinen Texten |
| Kai | Kai | – |
| Stufe · Stufen-Plakette · „NEUE STUFE!“ | Level · level badge · “LEVEL UP!” | – (Regel 2) |
| EP · HP · MP | XP · HP · MP | – |
| Klasse · Spezies · Spezialisierung | Class · Species · Specialization | – |
| Talent · Talentreihe · Talentbaum · Talent-Show | Talent · Talent Row · Talent Tree · Talent Show | – |
| Fähigkeit · Fähigkeitenbuch · Aktionsleiste | Ability · Ability Book · Action Bar | – |
| Rang · Beruf (Haupt-, Nebenberuf) · Güte | Rank · Profession (main, side) · Grade | – |
| Ausgeruht · Aufholjagd · Stufen-Band · Deckel · Überstunden | Well-Rested · Catch-Up · Level Band · Cap · Overtime | – |
| Partner-Spezial · SHOW · FINALE · Bellen | Partner Special · SHOW · FINALE · Bark | – |
| Marotten (M.O.D.s Vorlieben) | Whims | – |
| Unterhosen-Liga · Liga 1 · Duo-Liga | **Travel-Light League** · League 1 · Duo League | **sehr hoch** — jede wörtliche Fassung mit Unterwäsche, Hose (britisch *pants*!) oder Füßen trifft das Erkennungsbild einer bekannten Hauptfigur (06 §0.3). Der englische Name folgt dem vorbereiteten deutschen Ersatz „Leichtgepäck-Liga“ (06 §0.3 Nr. 6); Regeltext „no armor & no accessory“ |
| Leichtfüßig (Liga-Status) | **Nimble** | hoch — die wörtliche Fassung enthält *foot* (06 §0.3 Nr. 2) |
| Fanclub | Fan Club | – |
| Zustände: Vergiftet · Betäubt · Verlangsamt · Turbo · Gepanzert · Überrumpelt · Erholung · Brennt · Ermahnt · Schwindelig · Feierabend! · Sporenkur | Poisoned · Stunned · Slowed · Turbo · Guarded · Dazed · Regenerating · Burning · Admonished · Dizzy · Quitting Time! · Spore Treatment | – |
| Provoziert (`sts_taunt`) · Provoziert (`sts_taunted`) | Taunting · Taunted | – (Homonym, Kontext `statuses:<id>`, SP-2) |
| Klassen: Abrissbirne · Gleisläufer:in · Schrott-Tüftler:in · Showrunner:in | Wrecking Ball · Track Runner · Scrap Tinkerer · Showrunner | – |
| Klassen Mopsula: Erzmagister · Medicus honoris causa · Fluchgraf · Zeremonienmeister | Archmagister · Medicus honoris causa · Count of Curses · Master of Ceremonies | – |
| Spezies: Original-Verpackung · Kachelgolem · Neonfalter · Pilzling · Teilautomat | **Mint in Box** · Tile Golem · Neon Moth · Shroomling · Half-Automaton | – (Bauchbinde „ORIGINAL“ → „MINT IN BOX“) |
| Spezies Mopsula: Glutmops · Spukmops · Flattermops | Ember Pug · Spook Pug · Flutter Pug | – |

### 2.5 Glossar: Beute, Wirtschaft, Mini-Spiel

| Deutsch | Englisch | IP-Abstand / Hinweis |
|---|---|---|
| Lootbox (allgemein) | crate | mittel — „loot box“ ist zudem regulatorisch belegt (04 §2.6) |
| Bronze-, Silber-, Gold-Box | **Bronze / Silver / Gold Prop Crate** | **hoch** — Medaillenstufe + „Box“ liegt nah an den Belohnungsboxen eines bekannten Werks (04 §2.3); deutsch zuerst „Requisitenkiste“ (04 E2, F-2) |
| Fanpost-Paket | **Fan Mail Parcel** | **sehr hoch** — die wörtliche Übersetzung des früheren Namens ist ein Leitbegriff (04 §2.3); `ip_words.ALL_WORDS` sperrt ihre Schreibungen schon heute, `test_11_terms_en` wendet die Liste auf jede Übersetzung an |
| Credits · Händler:in · Verkaufsautomat | Credits · Trader · Vending Machine | – |
| Sponsoren (Fantasiemarken) | englische Fantasienamen, z. B. „KRAWUMM Energy“ bleibt | niedrig — jeder englische Name durch die Liste echter Marken (06 §5.9) und eine Markensuche **[zu prüfen]** |
| Stempelduell | **Stamp Duel** | niedrig — Markenrecherche wie für den deutschen Namen (10 F-1) |
| Geduld · Ärger · Werktag · Bearbeitungszeit | Patience · Annoyance · Business Day · Processing Time | – |
| Abheften · Wartenummer · Wartenummern-Anzeige | File Away · Ticket Number · Now Serving board | – |
| Durchsage · Schalter 3 · Schalterhalle · Aktenschrank | Announcement · Counter 3 · Service Hall · Filing Cabinet | – |
| Stempelalbum · Stempelheft · Dienstauszeichnung | Stamp Album · Stamp Booklet · Service Award | – |
| Lernduell · Sachbearbeiter:in · Abteilungsleiter:in · Der Stempelmeister | Practice Duel · Clerk · Department Head · The Stamp Master | – |
| sprechende Namen (Ferdi Durchschlag, Ulla Umlauf) | als Wortspiel übertragen, nicht wörtlich | – (L3 schlägt vor, L4 entscheidet) |

### 2.6 Die riskantesten Begriffe

| # | Deutsch | Gefahr der naheliegenden Übersetzung (beschrieben) | Wahl |
|---|---|---|---|
| 1 | Fanpost-Paket | wörtliche Übersetzung des früheren Namens = Leitbegriff eines bekannten Werks | Fan Mail Parcel |
| 2 | Unterhosen-Liga | Unterwäsche, Hose, Füße = Erkennungsbild einer bekannten Hauptfigur | Travel-Light League (+ Nimble) |
| 3 | Kandidat:in | das in 09 S-12 gesperrte Teilnehmerwort | contestant |
| 4 | Revier-Boss | Verwaltungsbezirk + Boss = Boss-Hierarchie eines bekannten Werks | Turf Boss |
| 5 | Etagenboss | wörtliche Übersetzung = Leitbegriff mehrerer bekannter Werke | Headliner |
| 6 | Einsturz | das wörtliche Wort = Kernmechanik einer Buchstruktur | Teardown |
| 7 | Bronze/Silber/Gold-Box | Medaille + Box | Prop Crate |
| 8 | NOVA SYNDIKAT | das englische Wort für Syndikat | NOVA Media Group |
| 9 | M.O.D. | Bezeichnung als System oder KI | M.O.D. / your host |
| 10 | Die Unterstadt | Hauptstadt eines bekannten Online-Rollenspiels | The Underground |
| 11 | Gleis 9 | berühmter Bahnsteig einer Jugendbuchreihe | Track 9 |
| 12 | Graf Mopsula | Königswörter; Namensmuster einer Zeichentrickfigur | Count Mopsula, ohne Königswörter |

Alle zwölf gehen als Zeilen in das Distanz-Review (04 §2.3) — englisch wie deutsch.

### 2.7 Stimme: M.O.D. auf Englisch

M.O.D. ist auf Englisch eine **US-Network-Moderatorin**: glatt, gut gelaunt, schneidend; sie liebt Quoten, Paragrafen
und Werbepausen und redet Kandidat:innen förmlich an („Contestant“, „you“), das Publikum warm („dear viewers“,
„galaxy“). Die Regeln aus 06 gelten unverändert und werden für Englisch konkret:

| Regel (06) | Englisch konkret |
|---|---|
| L-1 In einem Satz erklärbar | Jede Ein-Satz-Erklärung ≤ 110 Zeichen, zwei HUD-Zeilen; Beispiele Kap. 2.9 |
| L-2 Eine neue Regel pro Etage | unverändert — die Übersetzung fügt keine Erklärung hinzu, die es deutsch nicht gibt |
| L-3 Witz mit Ziel | Spott trifft Konzern, Show-Maschinerie, Bürokratie („House Rule §3, Dress Code“) — nie Spieler:innen, Publikum oder Körper; **nicht sexuell**, kein Bodyshaming; keine Doppeldeutigkeiten, die es erst im Englischen gibt (L4 liest jede Zeile darauf) |
| L-4 / L-5 | keine Kaufaufforderung, keine Dringlichkeit („Act now!“), kein Echtgeld-Bezug — die englischen Listen `money`, `purchase`, `urgency` (Kap. 1.13) |
| L-6 Deterministischer Kern | Kap. 1.10 |
| L-7 Politik raus | keine echten Parteien, Wahlen, Politiker:innen, Kriege, Ideologien — englisch auch keine Kulturkampf-Schlagworte und keine US- oder UK-Tagespolitik in Anspielungen |
| Keine Stereotype | keine Herkunft als Pointe, **keine Akzent-Imitation** (weder für M.O.D. noch für Mopsula), keine Witze über Berufe als Personen (10) |
| Keine echten Marken | auch keine echten Sender, Shows oder Moderator:innen als Anspielung mit Namen |
| Eigene Sprüche | keine Catchphrases bekannter Moderator:innen und keine Zitate aus Werken des Genres; die Sprüche sind PTDs eigene |

**Übersetzen heißt umschreiben:** Ein deutsches Wortspiel wird nicht wörtlich übertragen, sondern durch einen
englischen Witz auf **dasselbe Ziel** ersetzt; Länge, Tag, Stimme und Platzhalter bleiben.

### 2.8 Stimme: Graf Mopsula auf Englisch

- **Ich-Form, belehrend, gelehrt:** Fußnoten („Footnote 4: …“), pseudolateinische Formeln („Scandalum maximum“),
  Mitternachts- und Grafenpathos, Leberwurst als Leitmotiv (*liverwurst*), die Fehde mit der Rattenkönigin („an
  impostor of the lowest order“).
- **Kein Pluralis Majestatis** (04 §2.3): Er sagt „I“, nie das königliche „we“. Die deutsche Regex-Prüfung
  (`PersonaText.ROYAL_PLURAL`) lässt sich nicht übertragen, weil „we“ im Englischen alltäglich ist; L4 prüft im
  Voice-Pass, `test_11_terms_en` nur feste Wendungen.
- **Keine Königswörter:** *majesty*, *highness*, *royal*, *throne*, *crown*, *king* stehen nie in seinen Texten
  (englisches Gegenstück zu `ip_words.MOPSULA_WORDS`, gleiche Erkennung „Texte für, von oder über Mopsula“).
- **Hund, nicht Katze** (04 §2.3): *pug*, *snout*, *paws* sind erlaubt; Katzenwörter für ihn nie.
- **Kein Akzent:** Mopsula ist kein „deutscher Graf“ mit gebrochenem Englisch; sein Humor kommt aus Pedanterie, nicht
  aus Herkunft.
- Er duzt Kai deutsch; englisch zeigt sich die Nähe in Anreden („my dear colleague“, „young apprentice“).

### 2.9 Beispiele (Deutsch → Englisch)

| Stimme | Deutsch (Daten heute) | Englisch (Vorschlag, ≤ 110 Zeichen) |
|---|---|---|
| M.O.D. `intro` | „Guten Abend, Galaxis! Willkommen bei DUNGEON PRIME TIME — der Show, die Ihren Planeten gekostet hat!“ | “Good evening, galaxy! Welcome to DUNGEON PRIME TIME — the show that cost you your planet!” |
| M.O.D. `floor_start` | „Etage {floor}! Neuer Countdown, neue Monster, gleiche Gage: keine.“ | “Floor {floor}! New countdown, new monsters, same fee: zero.” |
| M.O.D. `death` | „Sendeschluss. {name} und der Graf sind gefallen. Wiederholung um 3 Uhr nachts.“ | “Off the air. {name} and the Count have fallen. Rerun at 3 a.m.” |
| M.O.D. Fanpost | „Ein Fanpost-Paket! Ihre Fans haben zusammengelegt. Ein paar haben Glitzer reingetan. Sorry.“ | “A Fan Mail Parcel! Your fans chipped in. Some of them added glitter. Sorry.” |
| M.O.D. `low_hp` | „Ihre HP sind niedrig! Die Quote ist hoch! Ein Dilemma!“ | “Your HP is low! The ratings are high! What a dilemma!” |
| Mopsula | „Dieser Automat führt keine Leberwurst. Scandalum maximum.“ | “This vending machine stocks no liverwurst. Scandalum maximum.” |
| Mopsula | „Ich ruhe. Fußnote 4: Weltuntergänge bitte schriftlich einreichen. Und nicht vor Mitternacht.“ | “I am resting. Footnote 4: please submit apocalypses in writing. And not before midnight.” |
| Mopsula | „Meine Damen und Herren, Ratten und Restposten: Der Graf hat das Wort.“ | “Ladies and gentlemen, rats and remainders: the Count has the floor.” |
| Mopsula, Persona | „Fußnote 4: Auch {cand} {name} braucht Ruhe. Ich bewache solange die Leberwurst.“ | “Footnote 4: even {name} needs rest. Meanwhile, I shall guard the liverwurst.” (ohne `{cand}`, Kap. 1.6) |

**Ein-Satz-Erklärungen (06 L-1), englisch:**

| System | Englisch (≤ 110 Zeichen) |
|---|---|
| Staffel | “Welcome to Season 37! Every floor gets torn down right on schedule. More punctual than any train.” |
| Generalprobe | “Floor 1 is the dress rehearsal. Failing is still allowed. From Floor 2 on, the cameras are rolling for real.” |
| Einsturz | “This floor gets torn down in two days. Be somewhere else by then. Ideally lower.” |
| Liga | “No armor & no accessory: harder, but the audience loves courage.” |
| Stempelduell | “Stamp Duel at Counter 3! Long forms, long waits. Whoever loses patience first, loses.” |
| Recall | “Callback! Who do you want to be? And what do you want to be good at?” |
| Liga-Einstieg (`liga_enter:1`) | “Contestant with no armor & no accessory. House Rule §3, Dress Code, says no. The ratings say YES.” |

Die Beispiele sind Vorschläge für L3; endgültig entscheidet der Voice-Pass in L4 (Kap. 5.7).

---

## 3. Inhaltspakete

### 3.1 Grundsatz und Abgrenzung

Ein **Inhaltspaket** ist ein Ordner, der für genau einen Build PTDs Inhalte verändert: Namen und Texte, Gegner,
Gegenstände, Zeilen, Etagen-Daten, Looks, Übersetzungen und Figuren-Parameter. Es wird einmal beim Start in die
Rohtabellen gemischt; danach ist es von Grunddaten nicht zu unterscheiden. Engine-Code und Grunddaten bleiben unberührt.

**Wer Pakete nutzt:**

1. **Lizenzierte Pakete** in privaten Repositories (Pitch-Builds; O-1).
2. **PTDs eigene Pakete** im öffentlichen Repository: das Testpaket „Testbild“ (Kap. 3.14), später zum Beispiel
   Messe- oder Demo-Builds, Saison-Specials und Textvarianten — überall, wo heute ein Branch mit geänderten Daten nötig
   wäre.
3. **Keine** Nutzer-Mods in Release-Builds (O-4); ein Mod-Weg wäre eine eigene Entscheidung (F-11).

### 3.2 Ordner

```text
game/packs/
  .gitignore                    # ignoriert alles außer der Whitelist (Kap. 3.12)
  PUBLIC_PACKS                  # eine ID je Zeile; heute: testbild
  PRIVATE_PACKS                 # F-20: private Pakete, nur solange das Repository privat ist; heute leer
  ip_firewall.json              # HMAC-Fingerabdrücke (Kap. 3.12)
  ip_firewall_baseline.json     # akzeptierter Bestand (Kap. 3.12)
  testbild/
    pack.json                   # Steckbrief (Kap. 3.3)
    data/<tabelle>.json         # Overlays, nur für berührte Tabellen (Kap. 3.4)
    locale/<sprache>.po         # Übersetzungen und Overrides (Kap. 3.6)
    art.json                    # Figuren-Parameter (Kap. 3.7)
    README.md                   # Zweck, Inhalt, Ansprechpartner (wird nicht exportiert)
```

Ein privates Paket hat dieselbe Form; sein Repository enthält zusätzlich `ip_terms.txt` (Kap. 3.12) und den Workflow
aus Kap. 3.13. Erlaubte Dateiendungen im Paketordner: `.json`, `.po`, `.md`, `.txt`. Alles andere ist ein Fehler
(Kap. 3.10).

### 3.3 `pack.json`

```json
{
  "pack_schema": 1,
  "id": "testbild",
  "name": "Testbild",
  "version": "1.0.0",
  "engine": {"min": "0.3.0", "max": "0.4.*", "commit": ""},
  "source_lang": "de",
  "languages": ["de", "en"],
  "default_lang": "de",
  "licence": null,
  "touches": {
    "enemies": {"patch": ["name"]},
    "mod_lines": {"patch": ["text"], "disable": true},
    "looks": {"add": true}
  },
  "art": "art.json"
}
```

| Feld | Regel |
|---|---|
| `pack_schema` | = `PackLoader.PACK_SCHEMA` (heute 1); anderes Schema → `pack_engine` |
| `id` | `^[a-z][a-z0-9_]{2,23}$`, nicht `base`; gleich dem Ordnernamen; Feature-Tag `pack_<id>` |
| `name` | Anzeigename (Fenstertitel, Credits); Text in `source_lang`, übersetzbar über die Paket-PO |
| `version` | SemVer `MAJOR.MINOR.PATCH`; steht im Run-Log-Kopf und im Spielstand |
| `engine.min` / `engine.max` | Bereich der Spielversion (`application/config/version`, heute `0.3.0`); `max` darf mit `.*` enden |
| `engine.commit` | 40 Hex-Zeichen des öffentlichen Commits, gegen den das private Repository baut; leer bei öffentlichen Paketen |
| `source_lang` | `de` oder `en`: die Sprache der Texte in den Overlays (Kap. 3.6) |
| `languages` / `default_lang` | Sprachen des Builds (⊆ `locale/languages.json`); `default_lang` gilt, wenn „Automatisch“ keine davon trifft |
| `licence` | `null` (eigene Inhalte) oder Block `{"holder", "contract", "scope": ["pitch"\|"demo"\|"release"], "valid_until", "credits": [Zeilen], "notice"}`; mit Block gelten die Ausnahmen aus Kap. 3.12, und die Credits zeigen `credits` |
| `touches` | Fußabdruck je Tabelle: welche Operationen (`patch` mit Feldliste, `add`, `disable`) das Paket nutzt. Der Lader lehnt alles außerhalb ab; Prüfer:innen sehen auf einen Blick, was das Paket ändert |
| `art` | `"art.json"` oder `""` |
| `tone_exceptions` | optional: Liste `{"ref": "<tabelle>:<id>.<feld>", "list": "<sperrliste>", "reason": "…"}` geprüfter Fehlalarme der Sperrlisten (Kap. 3.5, F-7); jede Ausnahme braucht ein Review |

### 3.4 Daten-Overlays und Zusammenführen (SP-12)

**Format** `packs/<id>/data/<tabelle>.json` — eine Datei je berührter Tabelle aus `GameData.TABLES`:

```json
{
  "schema": 1,
  "disable": ["<id>", "…"],
  "patch": {"enm_boss_rattenkoenigin": {"name": "Die Testbild-Königin von Gleis 9"}},
  "add": [{"id": "lk_outfit_testbild", "kind": "outfit", "name": "Testbild-Streifen",
           "colors": {"primary": "#F2F2F2", "secondary": "#1A1A1A"}}],
  "sub": {"hobbies": {"patch": {}, "add": [], "disable": []}},
  "top": {}
}
```

**Reihenfolge** (`PackLoader.merge(raw, pack)`, Tabellen in `GameData.TABLES`-Reihenfolge, deterministisch und
unabhängig von der Reihenfolge der Dateien auf der Platte):

1. **`disable`** entfernt Einträge nach ID. Nicht erlaubt für geschützte IDs: `kai`, `mopsula` (der Code nennt sie,
   etwa in `HeroRules.HEROES` und `DB.LOOK_MEMBER`), die Pflicht-Boxen `DataValidator.REQUIRED_BOXES` und Etage 1.
2. **`patch`** wendet je ID einen **JSON Merge Patch** (RFC 7386) an, in sortierter ID-Reihenfolge: Objekte werden
   rekursiv gemischt, Listen und Werte ersetzt, `null` löscht den Schlüssel (dann greift der Standard der
   Normalisierung). Das Ziel muss existieren. Eingebettete Listen (z. B. `floors → encounters`) ersetzt ein Patch
   ganz.
3. **`add`** hängt neue Einträge in Dateireihenfolge an; ihre IDs müssen neu sein und dem ID-Muster der Tabelle folgen
   (02_TECH §4.2). Ein vorhandenes Ziel ist ein Fehler („patch verwenden“).
4. **`sub`** wendet dieselben drei Operationen auf Unterlisten mit IDs an: `origins` (`hobbies`, `traits`, `rivals`,
   `brands`, `gags`, `greetings`, `plans`), `professions` (`recipes`, `materials`, `nodes`), `enemies`
   (`pseudo_units`), `cast` (`entries`).
5. **`top`** ist ein Merge Patch auf die übrigen Schlüssel der obersten Ebene (`party.start`, `party.exp_table`,
   `lootboxes.pools`, `lootboxes.pity`, `origins.canon`, `cast.names` — Listen werden ganz ersetzt).
6. **`rt_balance.json`** (optional, `GameData.RT_BALANCE_FILE`, Form `{"schema": 1, "values": {…}}` wie die Grunddatei):
   Das Overlay `{"schema": 1, "values": {…}}` wirkt als Merge Patch auf `values`.

**Verboten in Overlays:** das Feld `model` (Figuren gehören in `art.json`, Kap. 3.7), Tabellen außerhalb von
`GameData.TABLES` und `rt_balance.json`, jede Operation außerhalb von `touches`.

**Herkunft:** `merge` liefert neben den gemischten Rohtabellen `owned` — je Tabelle die hinzugefügten IDs und je
gepatchter ID die gesetzten Feldpfade. Die Validierung nutzt sie für die Ausnahmen aus Kap. 3.12. Fehler haben die Form
`pack[<id>].<tabelle>[<eintrag>].<feld>: <meldung>`.

**API** (`core/data/pack_loader.gd`, `class_name PackLoader`, rein, ohne Autoloads):

```gdscript
class_name PackLoader extends RefCounted
const ROOT: String = "res://packs"
const PACK_SCHEMA: int = 1
const ID_RE: String = "^[a-z][a-z0-9_]{2,23}$"
## {"id": "" | <id>, "error": "" | "pack_ambiguous" | "pack_missing"} — feature tags first, --pack=<id> only in debug.
static func active_id(user_args: PackedStringArray, debug: bool) -> Dictionary
## pack.json, file list, overlays and art.json; the errors stay inside the PackDef.
static func read(root: String, id: String) -> PackDef
static func compat(pack: PackDef, game_version: String) -> String     # "" | "pack_engine"
## {"raw": Dictionary, "owned": Dictionary, "errors": PackedStringArray}
static func merge(raw: Dictionary, pack: PackDef) -> Dictionary
static func content_hash(pack: PackDef) -> String                     # SHA-256 over pack.json + overlays (11 §3.9)
```

`GameData.load_dir(dir, pack: PackDef = null)` liest wie heute die Tabellen und `rt_balance.json`, ruft bei einem Paket
`PackLoader.merge` und reicht das Ergebnis in `_load(raw, dir, true, read_errors)` weiter; `GameData` bekommt
`pack_id`, `pack_version` und `pack_hash` (leer ohne Paket). `GameData.load_from_tables(raw, source)` bleibt der Weg für
Tests, die gemischte Tabellen direkt prüfen.

### 3.5 Validierung

1. **`PackLoader.read`:** Schema von `pack.json`, erlaubte Dateien, Schema der Overlays und von `art.json`, Sprachen
   (zu jeder Sprache außer `source_lang` gibt es `locale/<sprache>.po`).
2. **`PackLoader.merge`:** Ziele vorhanden, neue IDs frei, geschützte IDs, `touches`.
3. **`DataValidator.validate`** auf den gemischten Rohtabellen — **alle** Regeln wie für Grunddaten: Schemas, globale
   Eindeutigkeit der IDs, Referenzen, Pflicht-Tags der M.O.D.-Zeilen, `RtCheck`, die Unter-Validatoren, `IpWords` mit
   Herkunft (Kap. 3.12). Der Validator ändert sich nur um den Herkunfts-Parameter (Vertrags-Durchgang 11-P1, Kap. 5.3).
4. **Paketregeln** (`core/data/validators/pack.gd`, neu, im Stil der übrigen Unter-Validatoren): PO-Regeln wie
   `test_11_po_rules` für die Paket-PO; die Sperrlisten aus `mod_filter.json` (Politik, Sexuelles, Beleidigungen,
   Gewalt, echte Marken, Herkunft — ohne die Sprachprüfung) über alle Texte des Pakets als **Regel**, auch für
   lizenzierte Pakete; geprüfte Fehlalarme stehen begründet in `pack.json → tone_exceptions` (F-7). Englische
   Paket-Texte prüfen die englischen Listen aus L5, bis dahin das Review. Mit Lizenzblock zusätzlich: `credits` nicht
   leer, `valid_until` beim Export in der Zukunft (zur Laufzeit nur eine Warnung).
5. **Ergebnis:** Fehler setzen `DB.ok = false`, stehen in `DB.data.errors` und werden wie heute von `DB._init()` als
   `push_error` gemeldet (damit `check.sh` sie sieht). Ein Build mit Paket startet dann **nicht** mit Grunddaten,
   sondern zeigt einen Fehlerbildschirm („Inhaltspaket fehlerhaft“ + die ersten fünf Meldungen) — ein Pitch-Build ohne
   sein Paket wäre irreführender als ein klarer Fehler.

### 3.6 Texte und Übersetzungen eines Pakets

- **Quellsprache:** Die Texte in den Overlays sind msgids in `source_lang`. Ein Paket mit Partner-Inhalten darf
  englischen Quelltext haben (`source_lang: "en"`); dann braucht es für Deutsch eine `locale/de.po`. Der Mechanismus
  ist derselbe: Fehlt eine Übersetzung, zeigt `Tx` das msgid.
- **Vorrang:** **Paket-PO > Basis-PO > msgid.** `LocaleLoader` legt die Einträge der Paket-PO über die der Basis.
- **Overrides:** Eine Paket-PO darf jeden Basis-Eintrag überschreiben — auch deutsche Codetexte per `locale/de.po`
  (msgid deutsch → msgstr deutsch). So benennt ein Paket Figuren auch in Codetexten um, ohne Code: Rund 130 Literale
  im Code nennen heute Kai, Mopsula, den Grafen, M.O.D. oder NOVA (am häufigsten in `scenes/safe_room/safe_room.gd`,
  `scenes/title/name_entry.gd`, `scenes/title/intro.gd`, `scenes/exploration/exploration.gd`).
- **Namensprüfung:** `i18n.sh stats --pack=<ordner>` listet alle Basis-msgids, die einen Namen enthalten, den das Paket
  per `patch` geändert hat, und die die Paket-PO nicht überschreibt — als Warnung, damit kein alter Name stehen bleibt.
- **Regel für L2:** Sätze bleiben ganze msgids (kein `"Graf " + name`), damit Overrides möglich sind.
- **Sprachen:** Die Sprachwahl zeigt nur die Sprachen des Pakets; `pack.json → name` wird über die Paket-PO übersetzt.

### 3.7 Art-Parameter (`art.json`, SP-13)

```json
{
  "schema": 1,
  "models": {
    "mopsula": {"colors": {"primary": "#3C6EA5", "secondary": "#F2EBDD"}},
    "enm_boss_rattenkoenigin": {"colors": {"accent": "#FFFFFF"}, "scale": 1.1}
  }
}
```

- `models` ist nach IDs aus `party` und `enemies` geschlüsselt; jeder Wert ist ein Merge Patch auf das rohe Feld
  `model` (`DataValidator.SPEC_MODEL`) und wird **vor** der Validierung angewendet, also mit allen Modellregeln geprüft
  (`MODEL_BASES`, `MODEL_PROPS`, `MODEL_POSES`, `MODEL_COLOR_KEYS`, Stil nur für `humanoid` — seit 11-A1 auch `cat`,
  `MODEL_STYLES` —, und `CharacterBuilder.supported_bases()`/`supported_props()` müssen dieselben Listen haben).
- Erlaubt: `base`, `props`, `colors`, `scale`, `pose`, `style`, `gltf` (`""` oder ein vorhandener Pfad der Grunddaten)
  — Figuren aus dem Baukasten (03_ART §5.3–5.5), mit A1 auch die Katzen-Basis und die neuen Props (Kap. 4.10).
- Neue Persona-Looks sind Daten (`looks.json`-Overlay, `add`), keine Art-Parameter.
- Etagen-Farben stehen schon in den Daten (`floors → zones[].palette`, `DataValidator.PALETTE_KEYS`) und sind per
  Overlay änderbar. UI-Farben nicht: `Palette` und `UiTheme` sind Konstanten (F-18).
- **Warum nicht im Paket-Hash:** Modelle erreichen nie Zustand oder Snapshots — `Combatant.model` ist reine
  Durchreiche für die Darstellung, `DB.party_model()` die einzige Quelle für Party-Figuren, die Hashes kennen kein
  Modell. Zwei Builds, die sich nur in `art.json` unterscheiden, spielen dieselben Replays. Damit das so bleibt,
  dürfen Overlays `model` nicht anfassen.

### 3.8 Aktivierung (O-4, SP-15)

1. **Release-Builds:** `PackLoader.active_id` listet `res://packs/` und prüft für jeden Ordner `OS.has_feature("pack_"
   + id)`. Genau ein Treffer → dieses Paket; mehrere → `pack_ambiguous`; keiner → Grundspiel. `--pack` wird ignoriert
   (Warnung im Log).
2. **Debug-Builds** (`OS.is_debug_build()`, also Editor, Tests und Debug-Exporte): `--pack=<id>` aus
   `OS.get_cmdline_user_args()` aktiviert ein Paket, wenn kein Feature-Tag gesetzt ist (sonst `pack_ambiguous`); fehlt
   der Ordner → `pack_missing`.
3. **`DB._init()`** fragt `PackLoader.active_id(...)` und lädt `data.load_dir("res://data", pack)`; `DB.pack` hält die
   `PackDef` (oder `null`). Kein späterer Wechsel.
4. **Grund-Exporte** schließen `packs/*` aus (`export_presets.cfg` → `exclude_filter`, PB); „Testbild“ gelangt nie in
   einen Grund-Build.
5. **Paket-Exporte** baut `tools/pack_export.sh <paketordner> <preset> <ziel>` in einer temporären Kopie des Projekts
   (wie `tools/check.sh`): Paket nach `game/packs/<id>/` kopieren; im Preset `custom_features="pack_<id>"`,
   `include_filter` um `packs/<id>/*` und `locale/*` ergänzt, andere Pakete ausgeschlossen; in `project.godot`
   `config/name` aus `pack.json → name` und `custom_user_dir_name="PrimeTimeDungeon-<id>"`; dann `--export-release`.
   Die Dateien im Repository bleiben unberührt.
6. **Getrennte Nutzerdaten:** Ein Paket-Export hat seinen eigenen Nutzerordner. In Debug-Läufen mit `--pack` setzt
   `Save` `save_dir = "user://packs/<id>/saves"`; weil `Save._data_root()` der Elternordner von `save_dir` ist, ziehen
   Bestenlisten, Replays, Persona, Karriere (`career.json`) und die Stempel-Sammlung automatisch mit.

### 3.9 Determinismus und Aufzeichnungen (O-5, SP-14)

| Stelle | Ohne Paket (bleibt bitgleich) | Mit Paket |
|---|---|---|
| `pack_hash` | — | SHA-256 über `pack.json` und `data/*.json` des Pakets (`pfad:sha256`, sortiert, mit „\|“ verbunden); **nicht** `art.json` und PO (Darstellung) |
| `DB.data_hash()` | SHA-256 über `name:sha256(datei)` aller `res://data/*.json` (ohne Unterordner wie `data/stempel/`), sortiert, mit „\|“ verbunden, zwischengespeichert | dieselbe Liste + Element `pack:<id>:<pack_hash>` |
| Run-Log-Kopf (`Game._make_run_log`, `Save._make_run_log`) | schema, seed, slot, mode, difficulty, game_version, sim_hz, sim_version, event_id, run_id, player_id, window_id, league (bzw. die Felder des Spielstand-Logs) | **zusätzlich** `pack`, `pack_version`, `pack_hash` — nur mit Paket, damit Kopf und `RunLog.digest()` ohne Paket gleich bleiben |
| Spielstand (`SaveCodec.encode`) | format, version, game_version, saved_at_unix, summary, state | zusätzlich `pack: {id, version, hash}`; `SaveCodec.VERSION` bleibt 2 (fehlender Block = kein Paket) |
| Bestenlisten-Eintrag (`Game`, um Z. 996–1006) | trägt `data_hash` schon | zusätzlich `pack` |
| Nutzerdaten | `user://saves`, `user://leaderboards`, `user://replays` … | eigener Nutzerordner (Export) bzw. `user://packs/<id>/` (Debug) |

**Ablehnungen** (Codes sind Daten, die Anzeige übersetzt sie):

| Code | Wann | Wirkung |
|---|---|---|
| `other_pack` | Log, Spielstand oder Eintrag mit anderer Paket-ID — auch „mit Paket“ gegen „ohne“ | Replay abgelehnt (`RunSim.header_errors`); Spielstand nicht ladbar, der Slot nennt das Paket; Bestenlisten-Eintrag ausgeblendet |
| `other_pack_version` | gleiche ID, anderer `pack_hash` | Replay abgelehnt; Bestenlisten-Eintrag gekennzeichnet wie „ältere Version“ (`RunSim.version_status`, `Leaderboard.version_status`); Spielstand lädt über `migrate` + `_sanitize` mit Hinweis „Das Inhaltspaket wurde aktualisiert“ (wie nach einem Spiel-Update) |
| `pack_engine` | `pack_schema` oder Spielversion passen nicht | Fehlerbildschirm beim Start |
| `pack_invalid` | Validierung gescheitert | Fehlerbildschirm mit den ersten Meldungen |
| `pack_ambiguous` | mehr als ein Paket aktiviert | Fehlerbildschirm |
| `pack_missing` | `--pack=<id>` ohne Ordner (Debug) | Fehlerbildschirm |

**Wichtig für Spielstände:** `SaveCodec.decode` läuft heute `migrate` → `validate` → `_sanitize`, und `_sanitize`
entfernt unbekannte IDs **stillschweigend**. Ein Spielstand eines Pakets, geladen ohne das Paket, verlöre so leise
dessen Gegenstände und Fortschritt. Die Paketprüfung steht deshalb **vor** `_sanitize`, als erster Schritt nach dem
Lesen des Kopfs, und lehnt `other_pack` ab (Meldung wie `SaveCodec.MSG_NEWER`).

**Was sich nicht ändert:** `StateHash`, `RunSim.SIM_VERSION`, Ereignisse, Replay-Format. Ein Paket ändert nur Daten —
die Simulation bleibt dieselbe Funktion, nur mit anderen Eingaben. Events (`events.json`) und das Stempelduell
(`data/stempel`, eigener `rules_hash`, 10 §6.6) sind nicht patchbar; ihre Wertungen trennen sich trotzdem, weil
Bestenlisten am `data_hash` hängen.

### 3.10 Was ein Paket nicht kann — und warum

| Nicht erlaubt | Warum | Stattdessen |
|---|---|---|
| GDScript, C#, GDExtension | Fremder Code im Build: Sicherheit, Determinismus und Review wären nicht mehr zu garantieren; O-2 | Mechanik-Baukasten (Kap. 4): Bausteine in der Engine, über Daten gesteuert |
| Szenen (`.tscn`), Ressourcen (`.tres`/`.res`) | können Skripte und beliebige Knoten enthalten; Szenenaufbau ist Code | Daten in Tabellen; UI baut die Engine |
| Shader | GPU-Code; Budgets (02_TECH §12.1) und Renderer-Unterschiede (§12.2) | Farben und Material-Parameter der Modelle |
| Texturen, glTF, Audio, Schriften | in v1 nicht: Lizenzklärung je Datei, Größe, Import-Pipeline (03_ART §10) | spätere Stufe (F-6) |
| Projekteinstellungen, Input-Map, Autoloads | Engine-Vertrag | — |
| neue Vokabulare (Zustands-Flags, Phasen-Ops, Telegraph-Anker) | Validator-Vertrag; Werte ohne Code wären wirkungslos | Engine-Release mit Vertrags-Durchgang (MB) |
| neue Tabellen, `events.json`, `data/stempel/*`, `mod_filter.json` | Events haben eigenen Katalog und `rules_hash`; das Regelbuch des Stempelduells eigenen Validator und Hash (10 §6.4); Filter sind Schutzlisten, die kein Paket lockern darf | spätere Paket-Schema-Version, wenn nötig |
| Netzwerk, Konten, Telemetrie | nicht Teil eines Inhaltspakets | — |

### 3.11 Versionen und Kompatibilität (SP-16)

- **`PackLoader.PACK_SCHEMA`** steigt nur, wenn sich das Format von `pack.json` oder der Overlays inkompatibel ändert;
  der Lader nimmt genau sein Schema an.
- **Datenvertrag:** Neue Felder bekommen Standards (Normalisierung, 02_TECH §4.1), alte Pakete bleiben gültig.
  Umbenannte oder entfernte Felder melden Validator-Fehler — die private CI fängt sie vor jedem Build.
- **Spielversion:** `engine.min`/`max` gegen `application/config/version`; außerhalb → `pack_engine`.
- **Gepinnter Commit:** Das private Repository baut gegen `engine.commit`. Eine neue Engine-Version heißt dort: Commit
  anheben, CI grün, dann bauen.
- **Kennzeichnung:** Änderungen am Datenvertrag stehen im `CHANGELOG` mit dem Präfix „[Pakete]“ — die Liste, die
  Paketpflegende vor dem Anheben lesen.

### 3.12 IP-Firewall (O-6, SP-17)

**Ziel:** Kein Paket mit fremden Inhalten gelangt in dieses Repository — und wenn doch, schlägt die öffentliche CI
fehl. Ohne dass dafür fremde Begriffe im öffentlichen Repository stehen. (Wird das Repository privat, gilt F-20: das
Paket darf dann hier liegen, und die Schichten schützen die Grund-Builds statt des Repositorys.)

**Schicht 1 — Struktur** (`test_11_ip_firewall`, `tools/ip_firewall.sh structure`; ohne Geheimnis, läuft überall):

- Jeder Ordner unter `game/packs/` steht in `game/packs/PUBLIC_PACKS`.
- Jede `pack.json` im Repository hat `"licence": null`. Einzige Ausnahme: Test-Fixtures unter
  `game/tests/fixtures/packs/`, deren Lizenzblock als `holder` die feste Zeichenkette `"TEST – kein Rechteinhaber"`
  trägt (für den Test der Ausnahme-Regel).
- Keine `pack.json` außerhalb dieser beiden Orte.
- `game/packs/.gitignore` (`/*`, `!/.gitignore`, `!/PUBLIC_PACKS`, `!/ip_firewall*.json`, `!/testbild/`) verhindert,
  dass ein hineinkopiertes privates Paket versehentlich mit `git add` landet; `git add -f` fängt die CI.
- **Variante F-20 (umgesetzt mit 11-P1):** Ein Ordner darf statt in `PUBLIC_PACKS` in `game/packs/PRIVATE_PACKS` stehen;
  einen Lizenzblock trägt dann nur eine `pack.json` mit einer ID aus `PRIVATE_PACKS`. `test_11_ip_firewall` lässt
  `PRIVATE_PACKS` nur zu, solange `PTD_REPO_VISIBILITY` nicht `public` ist (die CI setzt die Variable aus
  `github.event.repository.private`, PB); `.gitignore` öffnet zusätzlich `!/PRIVATE_PACKS`.

Weil jedes lizenzierte Paket einen Lizenzblock trägt, fällt es an Schicht 1 — unabhängig von seinem Inhalt.

**Schicht 2 — Texte** (`IpWords.check` mit Herkunft):

| Text | `ALL_WORDS`, `MOPSULA_WORDS` (IP-Abstand) | `ORIGIN_WORDS` (Herkunft als Pointe) | Ton (06 L-3, L-7) |
|---|---|---|---|
| Grunddaten | geprüft | geprüft | Review; Filter-Stichprobe (`test_06d_mod_voice`: < 1 % Treffer) |
| Paket ohne Lizenz (z. B. „Testbild“) | geprüft | geprüft | Sperrlisten als Regel (Kap. 3.5) |
| Paket mit Lizenz, eigene Einträge und gesetzte Felder (`owned`) | **ausgenommen** | geprüft | Sperrlisten als Regel (Kap. 3.5) |

Die Mopsula-Regel erkennt heute „Texte für, von oder über Mopsula“ an Namen und Einträgen (`ip_words.gd`
`_entry_for_mopsula`, `MOPSULA_NAME_RE`). Hat ein lizenziertes Paket den Eintrag `mopsula` umgestaltet, ist er nicht
mehr Mopsula; die Ausnahme gilt dann auch für ihn. Dieselbe Ausnahme gilt für die Art-Regeln aus A1 (Kap. 4.10).
Ton-Ausnahmen für Partner-Inhalte gibt es nicht pauschal (F-7).

**Schicht 3 — Fingerabdrücke** (`tools/ip_firewall.sh scan`, neuer CI-Schritt in `ptd-check.yml`, Job `check`):

1. Das **private** Repository führt `ip_terms.txt`: unterscheidende Namen, Orte, Wortschöpfungen und Wendungen des
   lizenzierten Werks, je Zeile 1–4 Wörter; Alltagswörter nur als Wendung.
2. `ip_firewall.sh fingerprints ip_terms.txt` normalisiert jeden Eintrag (Unicode NFKC, Kleinschreibung, ä → ae usw.
   wie `PersonaRules.normalize_text`, Satzzeichen → Leerzeichen), bildet **HMAC-SHA-256** mit dem geheimen Schlüssel
   `PTD_IP_FIREWALL_KEY`, kürzt auf 32 Hex-Zeichen (128 Bit), sortiert und schreibt
   `{"schema": 1, "key_id": "k1", "fingerprints": […]}`.
3. Eine Maintainerin übernimmt die Datei als `game/packs/ip_firewall.json` ins öffentliche Repository — nur Hex-Werte.
   Ohne Schlüssel verrät sie nichts, auch nicht, um welches Werk es geht (reine Hashes ließen sich durch Raten
   bekannter Begriffe prüfen, HMAC nicht).
4. Die öffentliche CI (Secret `PTD_IP_FIREWALL_KEY`) liest alle versionierten Textdateien (`git ls-files`:
   `.gd .json .po .pot .md .tscn .tres .cfg .yml .txt`), normalisiert gleich, bildet Wort-N-Gramme der Länge 1–4,
   berechnet je N-Gramm den HMAC und vergleicht mit der Liste. Jeder Treffer außerhalb der Baseline lässt den Schritt
   fehlschlagen und nennt **Datei und Zeile**, nie den Begriff.
5. **Baseline** `game/packs/ip_firewall_baseline.json` (`{pfad: {fingerabdruck: höchstzahl}}`) erlaubt bekannte,
   geprüfte Vorkommen im Bestand — etwa Dokumente, die den IP-Abstand mit Namen begründen, oder den Test der
   Sprachregel aus 09. Sie wird mit `ip_firewall.sh baseline` erzeugt, im Review geprüft und darf nur schrumpfen;
   jedes neue Vorkommen braucht eine bewusste, begründete Änderung.
6. **Forks und Läufe ohne Secret** überspringen den Schritt mit Hinweis in der Zusammenfassung; der Schutz greift auf
   dem Haupt-Repository. Leckt der Schlüssel, wird er gewechselt (`key_id`) und die Liste neu erzeugt.

**Schicht 4 — Ablauf:** Das private Repository hat das öffentliche nie als Push-Ziel; ein Paket ist nie ein Submodul
des öffentlichen Repositorys; Änderungen unter `game/packs/` brauchen ein Review; die private CI prüft mit den eigenen
Fingerabdrücken, dass ihr Paket **Treffer erzeugt** — der Beweis, dass die Liste wirkt.

### 3.13 Das private Paket-Repository (CI-Vorlage, SP-18)

Aufbau des privaten Repositorys: `pack/` (der Paketordner), `ip_terms.txt`, `.github/workflows/pack-build.yml`,
`README.md` (Ansprechpartner, Lizenzstand, Verteiler). Die Vorlage steht **nur hier** und wird in diesem Repository
nicht als Workflow angelegt. Sie nutzt dieselben Schritte wie der öffentliche Job `export` (Godot und Vorlagen gegen
`SHA512-SUMS.txt` geprüft) und die Werkzeuge aus PB:

```yaml
# .github/workflows/pack-build.yml — template from docs/11 §3.13; lives only in a PRIVATE pack repository.
name: pack-build
on:
  push:
    branches: [main]
  workflow_dispatch: {}
env:
  GODOT_VERSION: "4.7.2"
  ENGINE_REPO: "<owner>/<public engine repository>"
jobs:
  build:
    if: github.event.repository.private          # a copy in a public repository does nothing
    runs-on: ubuntu-24.04
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
        with:
          path: pack-repo
      - name: Pinned engine commit from pack.json
        id: pin
        run: echo "commit=$(jq -r .engine.commit pack-repo/pack/pack.json)" >> "$GITHUB_OUTPUT"
      - uses: actions/checkout@v4
        with:
          repository: ${{ env.ENGINE_REPO }}
          ref: ${{ steps.pin.outputs.commit }}
          path: engine
          token: ${{ secrets.ENGINE_READ_TOKEN || github.token }}
      - name: System deps
        run: sudo apt-get update && sudo apt-get install -y xvfb libgl1 libglx-mesa0 libgl1-mesa-dri unzip jq gettext
      - name: Godot + templates (verified against SHA512-SUMS.txt)
        run: |
          mkdir -p ~/godot && cd ~/godot
          base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
          editor="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
          tpz="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
          for f in SHA512-SUMS.txt "$editor.zip" "$tpz"; do curl -fsSL -o "$f" "$base/$f"; done
          sha512sum -c --ignore-missing SHA512-SUMS.txt
          unzip -q "$editor.zip" && mv "$editor" godot && chmod +x godot
          templates="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
          mkdir -p "$templates" && unzip -q "$tpz" -d tpl && mv tpl/templates/* "$templates/"
      - name: Fingerprints of the licensed terms (the term list never leaves this repository)
        env:
          PTD_IP_FIREWALL_KEY: ${{ secrets.PTD_IP_FIREWALL_KEY }}
        run: |
          engine/prime-time-dungeon/tools/ip_firewall.sh fingerprints pack-repo/ip_terms.txt > ip_firewall.json
          engine/prime-time-dungeon/tools/ip_firewall.sh expect-hits ip_firewall.json pack-repo/pack
      - name: Pack check (merge, validation, PACK_SAFE tests, smoke, English captures)
        run: GODOT=~/godot/godot engine/prime-time-dungeon/tools/pack_check.sh pack-repo/pack --lang=en --shots=shots
      - name: Export macOS + Windows
        run: |
          for p in macOS Windows; do
            GODOT=~/godot/godot engine/prime-time-dungeon/tools/pack_export.sh pack-repo/pack "$p" build
          done
      - uses: actions/upload-artifact@v4
        with:
          name: pitch-macOS
          path: build/macos/
          retention-days: 14
          if-no-files-found: error
      - uses: actions/upload-artifact@v4
        with:
          name: pitch-Windows
          path: build/windows/
          retention-days: 14
          if-no-files-found: error
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: pitch-shots
          path: shots/
          retention-days: 14
      - uses: actions/upload-artifact@v4
        with:
          name: ip-firewall-fingerprints
          path: ip_firewall.json
          retention-days: 14
```

Anmerkungen: Der macOS-Build ist wie im öffentlichen Job ad-hoc signiert (README Kap. 4); Notarisierung bräuchte die
Apple-Schritte (02_TECH §12.4) und ist für Pitch-Builds nicht nötig. Artefakte bleiben privat und 14 Tage liegen; die
Weitergabe an die Rechteinhaberseite folgt 04 §2.4 (NDA vor Build). Der Schlüssel `PTD_IP_FIREWALL_KEY` ist in beiden
Repositories derselbe; `ENGINE_READ_TOKEN` braucht es nur, wenn die Engine nicht öffentlich ist.

### 3.14 Beispielpaket „Testbild“ (SP-19)

Ein kleines Paket aus PTDs **eigenen** Inhalten, das jede Paket-Funktion einmal benutzt und in der CI läuft:

| Datei | Inhalt | prüft |
|---|---|---|
| `pack.json` | wie Kap. 3.3, `licence: null` | Schema, `touches`, Sprachen |
| `data/enemies.json` | `patch` `enm_boss_rattenkoenigin` → `name` „Die Testbild-Königin von Gleis 9“ | Patch, Herkunft, `ip_words` ohne Ausnahme |
| `data/mod_lines.json` | `patch` einer der beiden Zeilen mit Tag `boss_intro:enm_boss_rattenkoenigin` (neuer Text mit Testbild-Witz); `disable` einer der drei `chat_bark`-Zeilen | Patch von Zeilen, Disable, Pflicht-Tags bleiben erfüllt |
| `data/looks.json` | `add` `lk_outfit_testbild` „Testbild-Streifen“ (Kleidungsfarben in Testbild-Grau) | Add mit neuer ID |
| `art.json` | Mopsula in den Testbild-Farben (nur `colors`) | Art-Patch über `DB.party_model()`, nicht im Hash |
| `locale/en.po` | englische Texte der drei neuen msgids **und** ein Override eines Basis-Eintrags (der Untertitel des Titelbildschirms) | Vorrang Paket-PO > Basis-PO |
| `locale/de.po` | ein deutscher Override eines Codetexts (Bootkarte: „präsentiert“ → „präsentiert im Testbild“) | Override deutscher Codetexte |
| `README.md` | Zweck: Test- und Anschauungspaket | — |

`test_11_pack_testbild` lädt Grunddaten und Paket und prüft: neuer Bossname, gepatchte und fehlende Zeile, neuer Look,
Mopsulas Farben, `data_hash` ≠ Grund-Hash und enthält `pack:testbild:<hash>`, Run-Log-Kopf und Spielstand-Block,
Ablehnungen (`other_pack` beim Laden eines Testbild-Spielstands ohne Paket, `other_pack_version` nach einer Änderung im
Overlay), englischer Bossname über die Paket-PO und der Override. Ohne Paket ist alles wie vorher (Hash gleich dem
heutigen). `tools/pack_check.sh game/packs/testbild` läuft in der öffentlichen CI.

---

## 4. Mechanik-Baukasten (SP-20)

### 4.1 Grundsätze

Pakete bringen keine Skripte (O-2). Was ein Partner-Inhalt an Mechanik braucht, wird ein **allgemeiner Baustein** des
Echtzeitkampfs (`core/rt`), gesteuert über Felder in `enemies.json → rt` bzw. `items.json → rt` oder über eine
Phasen-Op — wie die vorhandenen Bausteine `RtRule`, Phasen mit `on_enter`-Ops (`RtBoss.run_ops`: `say`, `status_self`,
`summon`, `fixed_damage_self`, `set`, `clear_zones`, `telegraph`), Telegraphen mit Ankern (`RtTele.create`: `self`,
`target_pos`, `each_enemy`, `random`, `lane`), `kill_adds`, `dash` (`RtTele._impact`), Beschwörungen
(`RtBoss.summon`) und Flucht (`RtBoss.escape`). Für jeden Baustein gilt:

1. **IP-neutral und mit PTD-Einsatz:** Jeder Baustein bekommt einen Gegner oder Gegenstand aus PTDs eigenen Kulissen
   (09 §3.1) und erweitert den Boss-Baukasten aus 09 §3.4 („Katalog von Mechaniken“).
2. **Deterministisch:** Ganzzahlen, Zentimeter, Ticks, Promille; Reihenfolge nach Einheiten-Nummer (07 §3.3);
   Zufall nur aus dem Kampf-Strom der Sim.
3. **Bitgleich ohne Daten:** Neue Felder sind optional; neue Laufzeitfelder von `RtUnit` und `RtSim` werden **nur
   geschrieben, wenn gesetzt** (sonst ändert `RtUnit.snapshot()`, das `RT_FIELDS` immer schreibt, jeden Hash). Neue
   Ereignis-Typen kommen ans **Ende** von `ActionEvent.Type`. Alle Goldens bleiben ohne die neuen Daten gleich.
4. **Lesbar:** Jeder Baustein hat einen Telegraphen oder ein HUD-Zeichen und einen Hinweis-Text (`RtVocab.HINT_IDS`)
   für das erste Auftreten (06 L-1).
5. **Eigentum:** `core/rt/**` und `scenes/combat/**` gehören den R-Phasen von 07 (09 §11.4). Deshalb ist der
   Code-Teil jedes Bausteins ein Punkt des Änderungsantrags **CR-39** (Kap. 4.11); die neuen Vokabulare
   (`core/data/validators/rt_vocab.gd`, `rt.gd`) kommen in einem Vertrags-Durchgang (11-MB).

| Baustein | Kurz | Daten | `core/rt` | CR-39 |
|---|---|---|---|---|
| MB1 | Aasfresser mit Lebenszyklus | `enemies → rt.scavenger` | ja | a |
| MB2 | Teilung beim Tod, Quelle abschaltbar | `enemies → rt.split` | ja | b |
| MB3 | Bahnen-Boss mit Anlauf | `enemies → rt.track`, Telegraph `lane` | ja | c |
| MB4 | Umgebungssieg | `enemies → rt.hazard_only`, Skill `rt.hazard`, `encounters[].rt.hazards` | ja | d |
| MB5 | Spawner, die von Toden leben | `enemies → rt.feed` | ja | e |
| MB6 | Ort als Gegner | `enemies → rt.set_piece`, Teile mit `rt.spot` | ja | f |
| MB7 | Wurf-Sprengsätze | `items → rt.throw` | ja | g |
| MB8 | Gesprächsboss | Phasen-Op `prompt`, `enemies → rt.talk`, Befehl `combat_choice` | ja | h |

### 4.2 MB1 — Aasfresser mit Lebenszyklus

| | |
|---|---|
| Idee | Kleine Gegner fressen **Überreste** (K.O. gegangene Gegner samt deren Beute) und wachsen dabei. Wer sie lässt, kämpft am Ende gegen große Aasfresser — oder verliert Beute. |
| Daten | `rt.scavenger: {"seek_cm": 900, "eat_ms": 2000, "grow": [{"hp_pm": 1300, "dmg_pm": 1150, "scale_pm": 1150}, …], "max_meals": 3, "at_max": "escape" \| "morph", "morph_to": "<enemy id>"}`; Bedingung `remains_min {"n"}` für `RtRule.cond` (z. B. ein Boss ruft Aasfresser, sobald zwei Überreste liegen) |
| Regeln | Geht ein **Gegner** K.O. (Schritte 2–6), entsteht ein Überrest `r<n>` an seiner Position (Party-Figuren hinterlassen nie einen). Schritt 7: Ein Aasfresser ohne Kanal sucht den nächsten Überrest in `seek_cm` (Abstand, bei Gleichstand kleinere Nummer) und setzt ihn als Bewegungsziel; in Reichweite beginnt er einen **Fresskanal** `eat_ms` (unterbrechbar wie ein Zauber). Kanalende (Schritt 6): Überrest weg, `meals + 1`, Stufe aus `grow` (Max-HP und aktuelle HP um denselben Betrag, `dmg_pm`), Ereignisse `REMAINS_EATEN`, `GROWN`. Bei `max_meals`: `escape` (verlässt den Kampf mit seiner Beute, `RtBoss.escape`) oder `morph` (wird `morph_to`, HP-Anteil bleibt). Stirbt ein Aasfresser, fällt **alles Gefressene** wieder an die Beute des Kampfs |
| Telegraph / HUD | Überreste als kleine Marke am Boden; Fresskanal mit Kanalbalken „frisst …“; Wachstum als Skalierung (`scale_pm`, nur Darstellung); Hinweis `scavenger`: „Die Kehrasseln fressen Ihre Beute — erst die Asseln!“ |
| Balance | Fressen dauert 2 s und ist unterbrechbar: Wer aufpasst, verliert nichts. 3 Mahlzeiten × 1,3 = 2,2-fache HP. Aasfresser sind schwach (≈ 40 % eines normalen Gegners) und zählen zur Gruppe; Beute geht nur verloren, wenn sie **entkommen** |
| PTD-Einsatz | **Kehrasseln** der NOVA-Reinigungskolonne (Paketzentrum, Hauptstudio): „Die Reinigung kommt pünktlich. Leider auch für Ihre Beute.“ |
| Code (CR-39 a) | `RtSim`: Liste der Überreste (nur im Snapshot, wenn nicht leer), Nummernzähler; `RtUnit`: `meals` (nur geschrieben, wenn > 0); `Damage.ko`: Überrest anlegen; `RtRules`: Suchen und Fressen; `rt_result.gd`: Beute der Gefressenen; Ereignisse `REMAINS_ADDED`, `REMAINS_EATEN`, `GROWN`; HUD und Puppen in `scenes/combat` |

### 4.3 MB2 — Teilung beim Tod, mit abschaltbarer Quelle

| | |
|---|---|
| Idee | Ein Gegner zerfällt beim K.O. in kleinere Kopien — solange eine **Quelle** im Raum arbeitet. Wer zuerst die Quelle ausschaltet, kämpft nur gegen das Original. |
| Daten | `rt.split: {"into": "<enemy id>", "count": 2, "max_gen": 2, "needs": "<enemy id>" \| "", "hp_pm": 500}` |
| Regeln | Ein K.O. in den Schritten 2–6 merkt die Teilung vor; **Schritt 10, vor der Ende-Prüfung**: je vorgemerktem K.O. `count` Einheiten `into` an seiner Position (wie `RtBoss.summon` mit `near`, Formation um den Ort), Generation + 1, nur bis `max_gen` und nur, wenn eine Einheit `needs` lebt und nicht unter einem Zustand mit `no_act` steht. `MAX_ENEMIES` (`RtBalance`, heute 6) begrenzt; was nicht passt, entfällt in Einheiten-Reihenfolge. Teilstücke sind Beschwörungen (`is_summon`: keine EP, keine Beute). Weil die Teilung vor der Ende-Prüfung liegt, endet kein Kampf, während noch Teilstücke entstehen |
| Telegraph / HUD | Die Quelle zeigt eine Linie zu allen Teilern („Kopierer aktiv“); beim K.O. die Bauchbinde „Durchschlag!“; Hinweis `split`: „Erst den Kopierer ausschalten — sonst wird es mehr.“ |
| Balance | `max_gen 2`: aus einem Original höchstens 1 + 2 + 4 = 7 Einheiten, mit abgeschalteter Quelle 1. Die Quelle ist ortsfest (`stationary`), hat mittlere HP und lässt sich betäuben (`no_act` schaltet sie ab, solange er wirkt) |
| PTD-Einsatz | **Formular-Golems** im Amt für Etagenwesen (Etagen 7–9) und **der Kopierer** als Quelle: „Formular in dreifacher Ausfertigung. Mindestens.“ |
| Code (CR-39 b) | `RtSim` Schritt 10 (Teilungen vor `VICTORY`-Prüfung), `RtUnit.gen` (nur geschrieben, wenn > 0), Ereignis `SPLIT`; Link-Linie im HUD |

### 4.4 MB3 — Bahnen-Boss mit Anlauf

| | |
|---|---|
| Idee | Ein großer Boss bewegt sich nur auf **Bahnen** und hat einen einzigen Angriff: den **Anlauf** über eine Bahn. Gepanzert, bis er gegen ein Hindernis kracht — man besiegt ihn, indem man den Raum benutzt. |
| Daten | `rt.track: {"lanes": [z_cm, …], "buffers": [[x_cm, z_cm], …], "armor_pm": 200, "crash": {"status": "sts_dizzy", "ms": 4000, "self_dmg_pm": 80}}`; der Anlauf ist eine Telegraph-Fähigkeit mit Form `line`, Anker `lane` und `dash` (beides gibt es: `RtTele.create`, `RtTele._impact`) |
| Regeln | Heute wechselt der Anker `lane` die Bahnen reihum (`RtSim.next_lane`). **Neu:** mit `rt.track` wählt der Boss die Bahn, auf der sein Ziel steht (bei Gleichstand die kleinere Bahnnummer). Einschlag (Schritt 4): Treffer wie heute, dann `dash` ans Bahnende; liegt dort ein **Prellbock** (`buffers`, Abstand ≤ Radius), kracht er: Zustand `crash.status` für `crash.ms`, Eigenschaden `self_dmg_pm` der Max-HP. Außerhalb des Zustands nimmt er nur `armor_pm` des Schadens |
| Telegraph / HUD | Die ganze Bahn leuchtet als Linie (vorhandene Telegraph-Darstellung); Prellböcke als feste Requisiten; beim Krachen Bauchbinde „Volltreffer — der Koloss ist benommen!“; Hinweis `track`: „Locken Sie ihn vor einen Prellbock und weichen Sie im letzten Moment aus.“ |
| Balance | Anlauf alle 6–8 s, Warnzeit wie andere Telegraphen (`RtTele.warn_ticks`, im Vorabendprogramm länger); Zustand 4 s; ≈ 4–6 Krach-Fenster bis zum Sieg. Ohne Prellbock-Nutzung ist der Kampf möglich, aber lang (Panzer 20 %) — Enrage (`enrage`) begrenzt ihn |
| PTD-Einsatz | **Der Rollcontainer-Koloss** (Arbeitstitel), Show-Boss in der Sortierhalle des Paketzentrums (Etage 5), Förderbänder als Bahnen, Laderampen als Prellböcke — die große Ausgabe des `enm_rollcontainer` „Rollcontainer-Rudel“ |
| Code (CR-39 c) | `RtTele.create` (Bahnwahl nach Ziel mit `rt.track`), `RtTele._impact` (Krachen am Bahnende), `Damage` (Panzer), Prellböcke als Hindernisse in `RtGeo` (`geo.blockers` gibt es) |

### 4.5 MB4 — Umgebungssieg

| | |
|---|---|
| Idee | Ein übermächtiger Gegner, dem Waffen nichts anhaben. Man kann ihn nur in eine **Gefahr der Umgebung** locken. Keine EP — aber Show. |
| Daten | Gegner `rt.hazard_only: true` (nimmt nur Schaden von Fähigkeiten mit `rt.hazard`), `rt.give_up_ms` (Sicherung); im Encounter `encounters[].rt.hazards: [{"skill": "<skl id>", "every_ms": 6000, "first_ms": 3000}]` — eine **Kulissen-Einheit** (unsichtbar, nicht anwählbar, ortsfest) wirkt die Gefahr als Telegraph mit Anker `self`/`random`/`lane`; `exp: 0` am Gegner |
| Regeln | Die Gefahr trifft **alle** Einheiten in der Fläche (Party, Gegner, den Übermächtigen) — wie heute schon `kill_adds` eigene Beschwörungen trifft („train kills“, `RtTele._impact`). Der Übermächtige verfolgt das Bedrohungsziel (`auto_target`), also lockt die Party ihn. Trifft ihn die Gefahr, verlässt er den Kampf (`escape`) oder fällt (je nach `hazard`-Wirkung). Nach `give_up_ms` gibt er auf und geht (Kampfende ohne Niederlage) — niemand bleibt in einem unlösbaren Kampf stecken |
| Telegraph / HUD | Gefahrenzonen dauerhaft markiert, vor dem Auslösen ein Telegraph mit der normalen Warnzeit; Lebensbalken des Übermächtigen als „∞“ mit Schloss; Hinweis `hazard`: „Nicht kämpfen. Hinführen.“ |
| Balance | Die Gefahr trifft auch die Party mit vollem Schaden — Timing ist die Aufgabe. Belohnung: Show (Hype, ein Achievement), keine EP (`exp: 0`) |
| PTD-Einsatz | **Der Kontrolleur** in der Unterstadt: unbesiegbar, verfolgt alle ohne Fahrschein; man lockt ihn zwischen die schließenden Zugtüren — „Nächster Halt: woanders.“ |
| Code (CR-39 d) | Kulissen-Einheit in `RtSetup` aus `encounters[].rt.hazards`; `Damage` filtert für `hazard_only`; Sicherung in Schritt 10; Lebensbalken-Darstellung im HUD |

### 4.6 MB5 — Spawner, die von Toden leben

| | |
|---|---|
| Idee | Ein ortsfester Gegner sammelt **Punkte**, wenn in seiner Nähe jemand K.O. geht, und ruft bei genug Punkten Verstärkung. Wer weit weg kämpft oder den Spawner zuerst ausschaltet, hat Ruhe. |
| Daten | `rt.feed: {"radius_cm": 600, "per_ko": 1, "party_ko": 3, "at": 4, "summon": "<enemy id>", "count": 2, "reset": true, "max": 3}` |
| Regeln | Jedes K.O. (Schritte 2–6) im Radius zählt `per_ko` (Gegner) bzw. `party_ko` (Party); Schritt 10: bei `at` Punkten `count` × `summon` (`near`), Zähler zurück (`reset`), höchstens `max` Mal. Ein toter Spawner zählt nichts |
| Telegraph / HUD | Ring um den Spawner (dauerhaft, wie eine Zone ohne Wirkung), Zähler „Quote 3/4“ über ihm; Hinweis `feed`: „Jede Niederlage in der Nähe bringt ihm Quote. Kämpfen Sie woanders.“ |
| Balance | `at 4`, `count 2`, `max 3`: höchstens sechs zusätzliche Einheiten; Party-K.O. zählen dreifach, damit Fehler sich rächen, aber nicht endlos |
| PTD-Einsatz | **Quoten-Spawner** im Hauptstudio (Applausmaschine mit Publikumstribüne): „Die Quote steigt — Nachschub aus dem Publikum!“ |
| Code (CR-39 e) | `RtUnit.feed_pts`/`feed_n` (nur geschrieben, wenn > 0); Zählung in `Damage.ko`, Beschwörung in Schritt 10 über `RtBoss.summon` |

### 4.7 MB6 — Ein Ort als Gegner

| | |
|---|---|
| Idee | Der **Raum selbst** greift an: Klappen springen auf, Fächer schießen, ein Scanner sucht. Man besiegt ihn, indem man seine **Teile** zerstört. |
| Daten | Kern `rt.set_piece: {"invisible": true, "untargetable": true, "parts": ["<enemy id>", …], "dies_with_parts": 2}`; Teile mit `rt.spot: [x_cm, z_cm]` (feste Position am Rand, ortsfest, anwählbar, eigene `rules`); Bedingung `parts_below {"n"}` für Phasen des Kerns |
| Regeln | `RtSetup` stellt Kern und Teile aus dem Encounter auf; der Kern steht unsichtbar und nicht anwählbar in der Ringmitte und wirkt Telegraphen (Anker `random`, `lane` oder an einem Teil). Fallen genug Teile (`dies_with_parts`: höchstens so viele dürfen stehen bleiben), geht der Kern in Schritt 10 K.O. → `VICTORY`. Phasen des Kerns schalten über `parts_below` |
| Telegraph / HUD | Teile mit Namensschild und Leiste; der Kern als Bossleiste oben („Die Abholstation“) mit Teilezähler; Hinweis `set_piece`: „Der Raum greift an. Zerlegen Sie ihn Fach für Fach.“ |
| Balance | 4–6 Teile, je ≈ 60 % eines normalen Gegners; Kern-Phasen wechseln die Angriffsart, wenn Teile fallen |
| PTD-Einsatz | **Die Abholstation** im Paketzentrum — ein Paketschrank, dessen Fächer aufspringen. Nicht „Packstation“: Das ist ein eingetragenes Markenwort eines echten Logistikunternehmens (06 §5.9: keine echten Marken) **[Markenprüfung]**; Arbeitstitel daher „Abholstation“ oder „Paketschrank“ |
| Code (CR-39 f) | `RtUnit.invisible`, `spot` (nur geschrieben, wenn gesetzt); `RtSim.targetable` beachtet `untargetable`; Ende-Prüfung für `set_piece`; Puppen ohne Modell für den Kern |

### 4.8 MB7 — Wurf-Sprengsätze

| | |
|---|---|
| Idee | Ein Gegenstand, den man **wirft**: Er landet, zischt (Zündschnur) und explodiert in einer Fläche — die auch die eigene Party trifft, wenn sie danebensteht. |
| Daten | `items → rt.throw: {"fuse_ms": 1500, "radius_cm": 250, "power": 120, "pct_maxhp": 0, "status": "", "ff_pm": 500, "ff_lethal": false}`; Wurfweite aus `rt.range_cm` |
| Regeln | Befehl `combat_item` (Schritt 1b, vorhanden) mit Zielpunkt; der Wurf legt einen Telegraphen (Kreis, `radius_cm`) mit Einschlag `c + fuse` an — **Seite BEIDE** (neu: heute trifft ein Telegraph nur die Seite `RtTelegraph.side`, mit `kill_adds` zusätzlich die Beschwörungen des Werfers). Einschlag (Schritt 4): Gegner voller Schaden, Party-Mitglieder `ff_pm` davon; mit `ff_lethal: false` bleibt eine Party-Figur bei mindestens 1 HP. Im **Vorabendprogramm** (`difficulty == &"vorabend"`, 09 §7.4) kein Eigenschaden |
| Telegraph / HUD | Kreis in einer eigenen Farbe für „trifft alle“ (Kontrast nach 07 §7.8), Zündschnur-Countdown am Wurfgegenstand; Hinweis `throw`: „Werfen, dann weg da. Konfetti kennt keine Freunde.“ |
| Balance | Stark gegen Gruppen; der Eigenschaden macht Position zur Entscheidung. Verbrauchsgut mit Gegenstands-Abklingzeit wie andere (`RtSim.item_cd_left`) |
| PTD-Einsatz | **Konfetti-Böller**: Schaden + „Überrumpelt“ (`sts_dazed`), Show-Bonus wie Gegenstände mit Tag `show` |
| Code (CR-39 g) | `RtTelegraph.side` mit Wert „beide“, `RtTele._impact` (Treffer beider Seiten, Eigenschaden-Regel), Gegenstandsweg in `Ability`, Zielpunkt im HUD (Maus, Gamepad, Touch wie Bodenziele) |

### 4.9 MB8 — Gesprächsboss

| | |
|---|---|
| Idee | Ein Boss, den man auch **ohne Kampf** besiegt: Im richtigen Moment stellt die Regie eine Frage, und wer richtig antwortet — mit M.O.D. als Souffleuse im Ohr —, bringt ihn Schritt für Schritt von der Bühne. |
| Daten | Phasen-Op `prompt: {"id": "p1", "choices": ["c1", "c2", "c3"], "right": "c2", "timeout_ms": 8000, "auto": "c1", "right_ops": [Op, …], "wrong_ops": [Op, …]}`; Boss `rt.talk: {"needed": 3}`; Texte als M.O.D.-Zeilen mit Tags `prompt:<boss>:<id>` (Frage), `prompt:<boss>:<id>:<choice>` (Antworten), `prompt_hint:<boss>:<id>` (Souffleuse) — Daten, also übersetzbar |
| Regeln | Die Op erzeugt ein Ereignis `PROMPT`; der `CombatDirector` hält die Sim an wie bei Hinweiskarten (07 E21) und zeigt eine Wahlkarte. Die Wahl wird als **neuer Befehl** `combat_choice {"ct", "prompt", "choice"}` aufgezeichnet (wie `combat_hint`) und in Schritt 1b angewendet: richtig → `talk + 1` und `right_ops` (z. B. Boss betäubt), falsch → `wrong_ops` (z. B. Boss gestärkt). Läuft die Karte ab (Wanduhr, Sim steht), zeichnet der Director `auto` auf. Erreicht `talk` den Wert `needed`, endet der Kampf in Schritt 10 als Sieg mit Kennzeichen `talked` (volle Beute, eigenes Achievement). Kämpfen bleibt möglich |
| Telegraph / HUD | Wahlkarte mit drei Antworten (Tastatur, Gamepad, Touch), M.O.D.-Hinweis darunter; Zähler „Überzeugt 1/3“ an der Bossleiste; Hinweis `talk`: „Manche Gäste gehen freiwillig. Fragen Sie richtig.“ |
| Balance | Drei richtige Antworten ≈ ein Drittel der Kampfzeit; falsche Antworten machen den Kampf härter, nie unmöglich. Bots wählen nach Profil (immer richtig / zufällig aus dem Bot-Strom) |
| PTD-Einsatz | Show-Boss **„Der Dauergast“** auf dem Talkshow-Set im Hauptstudio: ein Promi, der das Sofa nicht verlässt. Passt zur Marotte „Friedliche Runde“ |
| Code (CR-39 h) | `RtVocab.RT_PHASE_OPS` += `prompt`, `COMMAND_TYPES` += `combat_choice`; `RtBoss.run_ops`, `RtSim.submit`/Schritt 1b, `BattleResult` (Kennzeichen `talked`), `RunSim`/`GameReplay` (Befehl), `CombatDirector` (Pause, Karte) |

### 4.10 A1 — Art-Kit-Erweiterungen (SP-21)

Allgemeine Bausteine für den Figuren-Baukasten (03_ART §5.3–5.5), IP-neutral, für Pakete und eigene Inhalte:

| Baustein | Beschreibung | Budget |
|---|---|---|
| Basis **`cat`** | Vierbeiner (Katze) neben `pug`; Posen `quadruped` (Stand, Sitz) über `CharacterBuilder.resolve_pose`; Farbslots primary (Fell), secondary (Zeichnung), accent, eyes; Sockel Kopf, Hals, Rücken, Schwanzspitze; `NOMINAL_HEIGHT` ≈ 0,5 m | ≤ 1 600 Tris, ≤ 3 Meshes (Mops heute 1 448 Tris, 2 Meshes) **[zu messen]** |
| Prop **`tiara`** | Diadem für Kopf-Sockel (`humanoid`, `pug`, `cat`) | ≤ 150 Tris |
| Prop **`sunglasses`** | Sonnenbrille wie `glasses` (+212 Tris), dunkle Gläser | ≤ 220 Tris |
| Prop **`bathrobe`** | Bademantel über dem Torso (`humanoid`), Gürtel | ≤ 300 Tris |
| Prop **`sandals`** | Sandalen (`humanoid`) | ≤ 120 Tris |
| Prop **`shorts`** | kurze Hose als Variante der Beinsegmente (`humanoid`) | ≤ 200 Tris |
| Prop **`jacket`** | Jacke über dem Torso (`humanoid`), Kragen | ≤ 300 Tris |
| Look-Art **`wear`** | neue Art in `looks.json` und `PersonaLook.KINDS`: eine Kleidungs-Option, die ein Prop setzt (wie heute `glasses` ein Prop schaltet) | Persona im schlimmsten Fall ≤ 3 000 Tris, 7 MeshInstances (CR-22); `wear` und Brille notfalls exklusiv **[zu messen]** |

**Vertrag:** `MODEL_BASES` += `cat`, `MODEL_PROPS` += die sechs Props (`core/data/data_validator.gd`, Vertrags-Durchgang
11-A1); `Archetypes.BASES`/`PROPS`, `NOMINAL_HEIGHT`, `DEFAULT_COLORS`; `CharacterBuilder.supported_bases()`/
`supported_props()` müssen gleich bleiben (Test vorhanden); `PersonaLook.KINDS` += `wear`. Alles additiv, keine
bestehende Figur ändert sich.

**PTDs eigene Regeln bleiben** (Validator, Herkunft „Grunddaten“ und Pakete ohne Lizenz):

1. Mopsula trägt nie `crown`, `ticket_crown` oder `tiara` (`validators/species.gd` `MOPSULA_FORBIDDEN_PROPS` += `tiara`;
   04 §2.3: keine Kronen-Motive an Mopsula).
2. Keine Party-Figur und kein Begleiter mit Basis `cat` (04 §2.3: Hund statt Katze); Katzen nur als Gegner oder
   Nebenfiguren.
3. Kai und die Persona tragen in Grundinhalten weder `shorts` noch `bathrobe` noch `sandals`; `sandals` nutzen
   Grundinhalte gar nicht (06 §0.3: keine Liga-Optik für Kai, keine Fuß-Bezüge in Rigs).
4. Lizenzierte Pakete sind für ihre eigenen Einträge ausgenommen (Kap. 3.12, Schicht 2).

**Tests:** `test_11_art_kit` (jede neue Basis und jedes Prop baut, bleibt im Budget, `supported_*` = Validator-Listen,
Regeln 1–3 als Validator-Fälle); Einträge in `art/gallery/character_gallery.tscn` und ein Capture.

**Stand 11-A1 (2026-10-18, Branch `ptd/a1`) — umgesetzt** (03_ART §5.3–5.5): `art/kit/archetypes.gd` (Basis `cat`, die
sechs Props, `STYLES`), `character_builder.gd` (`supported_styles()`, Stil je Basis in `normalize` und im Mesh-Cache,
`resolve_pose` für `cat`), `character_rig.gd` (Familie `quad`, Schwanzschwingen, Kopfdrehen), `persona_look.gd` (`KINDS`
+= `wear`), neu `core/data/validators/art_kit.gd` (Regeln 1–4), `data_validator.gd` (Vertrags-Durchgang 11-A1),
`validators/looks.gd` (Art `wear`), `validators/species.gd` (`tiara`, Lizenz-Ausnahme), `data/looks.json` („ohne“,
„Jacke“), die Fixtures `data_min`/`rt_min` (Kanon `wear`), `art/gallery/character_gallery.gd` mit den Szenen
`cat_gallery.tscn` und `kit_gallery.tscn` (jede Seite auch aus `character_gallery.tscn` über `params {"page": …}`),
`tests/test_11_art_kit.gd` (18 Tests), `locale/pot/data.pot` und `en/data.po` (der Name „Jacke“), die Captures 140–149.

*Vertrag (additiv):* `MODEL_BASES` += `cat`; `MODEL_PROPS` += `tiara`, `sunglasses`, `bathrobe`, `sandals`, `shorts`,
`jacket`; neu `MODEL_CAT_FURS`, `MODEL_CAT_PATTERNS` und `MODEL_STYLES` (die Stil-Schlüssel je Basis: `humanoid`
hair/beard, `cat` fur/pattern; jede andere Basis ohne Stil — die Prüfung `_check_model_style` nimmt die Schlüssel der
Basis); `Archetypes.BASES`/`PROPS`/`NOMINAL_HEIGHT` (`cat` 0,5 m)/`DEFAULT_COLORS`;
`CharacterBuilder.supported_bases()`/`supported_props()`/`supported_styles()` gleich den Validator-Listen
(`test_m4_art_kit`, `test_11_art_kit`); `PersonaLook.KINDS` += `wear`. **Jede bestehende Figur baut bitgleich:** alle
Modelle aus `party`/`enemies` und dem Cast-Blatt, jede alte Basis × jedes alte Prop und alle alten Props zugleich haben
dieselben Tris, Meshes und Vertex-Daten (Positionen, Farben, Indizes) wie `main` (Vergleich über 393 Figuren).

*Katze* (Tris je Stil; Stand und Sitz haben dieselbe Summe; immer 3 Meshes `Body`, `Head`, `Tail`; Budget 1 600 / 3,
dazu jede Variante im Gegner-Budget 1 500; Höhe stehend 0,52 / 0,53 m, sitzend 0,57 / 0,53 m):

| `fur` \ `pattern` | `solid` | `tabby` | `tortie` | `bicolor` | `calico` |
|---|---:|---:|---:|---:|---:|
| `short` | 1 152 | 1 304 | 1 292 | 1 248 | 1 324 |
| `long` | 1 272 | 1 424 | 1 412 | 1 368 | **1 444** |

Props kommen dazu (Diadem +120, Sonnenbrille +188, Mantel +140/+160, Sandalen +96); die Budgets der Datenmodelle prüft
`test_m4_art_kit` für jeden Gegner und jede Party-Figur der Daten — eine Katze als Gegner mit Sonnenbrille braucht die
kurze Felllänge und ein schlichtes Muster (`short solid` + `sunglasses` 1 340).

*Props* (die Teile des Props / netto an Kai, gemessen an Kai, einer zweiten Menschfigur, Mops und Katze; alle in
vorhandene Meshes gemergt, kein neues MeshInstance):

| Prop | Basen (Sockel) | Tris Teile / netto | Budget |
|---|---|---:|---:|
| `tiara` | humanoid (auf dem Haaransatz), pug, cat (`head`) | 120 / +120 | 150 |
| `sunglasses` | humanoid, cat und jede Basis mit `eyes` | 188 / +188 | 220 |
| `bathrobe` | humanoid (ersetzt Hemd-Details und Hüft-Box, 148) | 164 / +16 | 300 |
| `jacket` | humanoid (ersetzt die Hemd-Details, 136) | 160 / +24 | 300 |
| `shorts` | humanoid (ersetzt die Hosenbein-Kapseln, 360) | 112 / −248 | 200 |
| `sandals` | humanoid (ersetzt Schuhe und Sohlen, 48) | 96 / +48 | 120 |

Andere Basen bekommen einfache Rückfälle (03_ART §5.4): Mantel um den Rumpf eines Vierbeiners (Rahmen `flags.torso` von
cat, pug, rodent; `jacket` +140, `bathrobe` +160 mit Gürtel), Ring um das Rumpfende (`shorts` +20), Sohle und Riemen
unter jeder Pfote (`flags.feet`; `sandals` +96), bei brute an Schenkeln und Stiefeln, sonst am Sockel `body`.

*Persona (`wear`, CR-22):* Kanon 2 492 Tris / 7 MeshInstances; Jacke 2 516; schlimmster Fall der Grunddaten `curls` +
`stubble` + Brille + Jacke **2 964**, über alle `wear`-Stile (auch Paket-Optionen) `curls` + `stubble` + Brille +
`sandals` **2 988** — immer genau 7 MeshInstances (`test_11_art_kit` baut alle 9 × 4 × 2 × 5 Kombinationen). `wear` und
Brille kombinieren frei; eine Exklusivität ist nicht nötig.

*Katzen-Optionen (Stil-Erweiterung):* `fur` ist `short` oder `long` (Perser-Typ: Rumpf r 0,122, Halskrause,
Wangenflausch, flacheres Gesicht, runde Augen, kleine Ohren weit außen, buschiger Schwanz, dicke Beine und Keulen),
`pattern` ist `solid`, `tabby` (vier Streifen über den Rücken bis zur Flankenmitte, Schwanzringe, „M“ auf der Stirn),
`tortie` (Flecken auf dunklem Grund), `bicolor` (Latz, Bauch, Pfoten, Schnauze, Blesse, Halskrause, Schwanzspitze) oder
`calico` (Flecken in secondary und accent auf hellem Grund) — alles Vertex-Farben auf wenigen Formen, keine Textur. Die
Optionen stehen an **einer** Stelle, `Archetypes.STYLES` (= `CAT_FURS`, `CAT_PATTERNS`; der erste Wert ist der
Standard), gespiegelt in `DataValidator.MODEL_STYLES` und abfragbar über `CharacterBuilder.supported_styles()["cat"]`;
ein späteres Paket bildet darauf ein Spielerprofil ab (Fellfarben über die Slots primary, secondary, accent, eyes).

*Regeln* (`validators/art_kit.gd`, nach `IpWords.check`; Herkunft „Grunddaten“ und Pakete ohne Lizenz): (1) Mopsula
trägt nie `crown`, `ticket_crown` oder `tiara` — sein Partymodell dort, die Spezies-Looks für ihn in `species.gd`
(`MOPSULA_FORBIDDEN_PROPS` += `tiara`); (2) keine Party-Figur und kein Begleiter mit Basis `cat`; (3) Kai trägt weder
`shorts` noch `bathrobe` noch `sandals` — nicht am Partymodell, nicht über einen Spezies-Look für ihn, nicht als
Persona-Look (`wear`) —, und `sandals` nutzen Grundinhalte gar nicht (Party, Gegner, Spezies); (4) ein Paket mit
Lizenzblock ist für die Einträge, die es hinzufügt, und die Felder, die es setzt, ausgenommen (`PackLoader.owned_paths`;
die Pfade aus `art.json` als `model.…`), auch für die Kronen-Regel der Spezies. `test_11_art_kit` prüft 1–3 als
Validator-Fälle und 4 von Ende zu Ende (ein Paket, dessen `art.json` Mopsula zur Katze mit Diadem macht und der
Kanalratte Sandalen gibt und dessen Looks-Overlay „Kurze Hose“ hinzufügt: mit Lizenz ausgenommen, ohne Lizenz die vier
Fehler).

*Entscheidungen und Abweichungen:*

- **A1-1 Sitzen ist `"upright"`.** Kap. 4.10 nennt die Posen „`quadruped` (Stand, Sitz)“; `resolve_pose` liefert zwei
  Werte: `"auto"`/`"quadruped"` → `&"quadruped"` (Stand), `"upright"` → `&"upright"` (Sitz). Die Rig-Familie bleibt in
  beiden `quad`.
- **A1-2 Stil je Basis.** `ModelSpec.style` war nur für `humanoid`; jetzt gilt `MODEL_STYLES` (Kap. 3.7 „Stil nur für
  `humanoid`“ entsprechend erweitert). Eine Basis ohne Eintrag hat keinen Stil, ein unbekannter Schlüssel ist ein
  Fehler.
- **A1-3 `wear` ist eine optionale Art.** Persona-Datei (`PersonaProfile.LOOK_KINDS`) und Casting (`persona_casting.gd`)
  tragen weiter die sechs Arten von 08 §6.1; ein Look ohne `wear` trägt die Kanon-Option, und `PersonaLook.ids()` nennt
  `wear` nur, wenn der Look die Art setzt (`OPTIONAL_KINDS`). Damit bleiben die Casting-Zeile des Full-Run-Bots, die
  Persona-Dateien und `test_08_avatar_kit` unverändert. Die Casting-Zeile „Kleidung“ kommt mit einem Casting-Paket (08).
- **A1-4 Grunddaten-Optionen:** „ohne“ (Kanon) und „Jacke“ — Bademantel, kurze Hose und Sandalen nie (Regel 3). Kais
  Partymodell darf höchstens ein `wear`-Prop tragen (ein Look setzt eins; sonst könnte der Kanon ihn nicht unverändert
  lassen).
- **A1-5 Kleidung ersetzt Teile.** Jacke und Bademantel kleiden Torso und Ärmel ein und decken die Hemd-Details (Kragen,
  Bauchtasche, Namensschild, Logo), die kurze Hose ersetzt die Hosenbein-Kapsel, die Sandale den Schuh — daher netto
  wenig oder weniger Tris; das Budget gilt für die Teile des Props (beides im Test). Der Bademantel geht der Jacke vor.
- **A1-6 Regel 3 gilt auch für Spezies-Looks für Kai** (`for` leer oder mit `kai`): `model_hint.props_add` ist ein Look
  für ihn.
- **A1-7 Regel 4 gilt auch für die bestehende Kronen-Regel der Spezies** (Kap. 3.12: dieselbe Ausnahme für die
  Art-Regeln).
- **A1-8 Die Katze steht nicht in `CharacterBuilder.ENEMY_BASES`** (kein Gefahren-Saum von Haus aus), weil sie auch
  Nebenfigur sein darf — wie `humanoid`.
- **A1-9 Das Diadem am Mops** ist gebaut und getestet, steht aber in keiner Capture: ein Mops mit Diadem läse sich als
  Graf Mopsula mit Kronen-Motiv (04 §2.3).
- **A1-10 Galerie-Beschriftungen** nennen die Vokabular-Werte (`short · tabby`), wie die Seiten `bases` und `props`; die
  Kleidung trägt eine Ersatzfigur, nie Kai.
- **A1-11 Die Höhe 0,5 m ± 10 % gilt für den Stand;** sitzend ragt der Kopf der kurzhaarigen Katze höher (0,57 m).

*Gates* (2026-10-18, auf der geteilten 4-Kern-Maschine bei Last 6–14): `tools/check.sh` grün — 1 951 Tests (18 neu), 0
Fehler, 0 übersprungen, Testlauf 1 393 s, gesamt 24 min 27 s, Smoke `AUTOPLAY: OK`; `test_11_literals` grün.
`tools/fullrun.sh --strategy=all`, `--hero=mopsula`, `--liga=1` und `--liga=2` → `fullrun.sh: OK`, gegenüber `main`
(`ac5d15c`) dieselben `FULLRUN: OK`-Zeilen, dieselben Ereigniszeilen (118/118/118/115, 115, 118, 112) und dieselben
Statistiken bis auf den bekannten Münzwurf der Darstellung in `mod_tags` (Kap. 5.3, „Stand 11-P1“). `tools/perf.sh
--only=explore,combat` → `PERF: OK` auf `main` und `ptd/a1` mit denselben Draw Calls in jeder Zeile (Etage max 203, Ø
154, 3D 112, UI 94; Kampf 154/182/169) und denselben Materialien; die Primitive schwanken wie zwischen zwei Läufen
desselben Builds um ±25 (Partikel). `tools/i18n.sh check` grün (`data.pot` 1 538 msgids, „Jacke“ neu). `DB.data_hash()`
ohne Paket: `main` `6c17e6ce623efbb3c584eae1d121c2c04077752084786f7d776507098e593ec3` → `ptd/a1`
`12b0014edbeed5183a7d85a2b38bb26dee4ed8c42e174ae7a4c1b35e4edfa528` (nur `looks.json`: die zwei `wear`-Optionen; neue
Bestenlisten-Wertung wie bei jeder Datenänderung); kein `SIM_VERSION`-Sprung, kein Zustand und keine Aufzeichnung sieht
ein Modell.

*Captures* (`tools/check.sh --shot`, 1280 × 720): 140 `cat_gallery.tscn` (jedes Muster, beide Felllängen, Stand und
Sitz), 141 `view: close` (Ohren, Schnurrhaarpolster, Nase, Augen, die Schwanzlocke), 142 `view: game` (Katzen neben Kai
und Graf Mopsula aus der Erkundungskamera: Arm 7 m, −38°, FOV 60), 143 `view: fur` (kurz und lang nebeneinander), 144
`view: sit`, 145 `view: patterns`, 146 `kit_gallery.tscn` (jedes Prop an einer passenden Basis), 147 `view: close`
(Jacke, Bademantel mit Sandalen, kurze Hose, Sandalen), 148 `view: heads` (Diadem und Sonnenbrille an Mensch und Katze),
149 `view: persona` (Kai Kanon, mit „Jacke“ und der schwerste Look der Grunddaten mit den gemessenen Tris).

*Offen nach 11-A1:*

- **08 / Casting:** eine Zeile „Kleidung“ (`persona_casting.gd`, `PersonaProfile.LOOK_KINDS` += `wear`); dann nennt auch
  die Casting-Zeile des Full-Run-Bots die Art, und die Zufalls-Persona zieht sie (ändert die Ereigniszeilen — eigener
  Durchgang). „Sonnenbrille als Persona-Option“ (Kap. 5.8) ebenso: ein Brillen-Stil ändert die Casting-Optionen und die
  Ziehungen.
- **02_TECH §4.3/§8.4** (Vokabular-Zeilen `MODEL_BASES`, `MODEL_PROPS`, `MODEL_STYLES`, Test-Zeile `test_11_art_kit`)
  und die README-Bildtabelle (140–149) — Folgeänderung für den Integrator; beide Dateien ändert gerade ST1-I.
- Ein Katzen-Gegner in Inhalten (Pakete, Kap. 4.10 „Katzen nur als Gegner oder Nebenfiguren“); Kleidung als
  Ausrüstungs-Optik bleibt A8.

### 4.11 Änderungsantrag CR-39 an 07

CR-39 bündelt den Code-Teil der Bausteine. Jeder Punkt ist **ohne die neuen Daten bitgleich** (neue Felder nur
geschrieben, wenn gesetzt; neue Ereignis-Typen am Ende; `test_r1_rt_golden`, `test_r1_rt_tick_order` und die übrigen
`test_r*` unverändert) und wird einzeln umgesetzt, wenn ein Inhalt ihn braucht. Die Vokabulare kommen im
Vertrags-Durchgang 11-MB.

| Nr. | Baustein | Dateien | Änderung | Wer |
|---|---|---|---|---|
| CR-39 a | MB1 Aasfresser | `core/rt/rt_sim.gd`, `rt_unit.gd`, `rt_rules.gd`, `rt_damage.gd`, `rt_result.gd`; `scenes/combat` | Überreste, Fresskanal, Wachstum, Rückgabe der Beute; Ereignisse `REMAINS_ADDED`, `REMAINS_EATEN`, `GROWN`; Bedingung `remains_min` | Eigentum `core/rt` + HUD |
| CR-39 b | MB2 Teilung | `rt_sim.gd` (Schritt 10), `rt_unit.gd`, `rt_boss.gd` | vorgemerkte Teilungen vor der Ende-Prüfung, Quelle `needs`, `gen`; Ereignis `SPLIT` | Eigentum `core/rt` |
| CR-39 c | MB3 Bahnen-Boss | `rt_tele.gd` (`create`, `_impact`), `rt_damage.gd`, `rt_geo.gd` | Bahnwahl nach Ziel, Krachen am Prellbock, Panzer außerhalb des Zustands | Eigentum `core/rt` |
| CR-39 d | MB4 Umgebungssieg | `rt_setup.gd`, `rt_sim.gd`, `rt_damage.gd`; `core/progression/battle_bridge.gd`; `scenes/combat` | Kulissen-Einheit aus `encounters[].rt.hazards`, `hazard_only`-Filter, `give_up_ms` | Eigentum `core/rt` + 07 R1b |
| CR-39 e | MB5 Spawner | `rt_unit.gd`, `rt_damage.gd`, `rt_sim.gd` | Punkte bei K.O. im Radius, Beschwörung in Schritt 10 | Eigentum `core/rt` |
| CR-39 f | MB6 Ort als Gegner | `rt_setup.gd`, `rt_unit.gd`, `rt_sim.gd` (`targetable`, Ende), `scenes/combat` (Puppe ohne Modell, Bossleiste) | Kern und Teile, `parts_below` | Eigentum `core/rt` + HUD |
| CR-39 g | MB7 Wurf | `rt_telegraph.gd` (Seite „beide“), `rt_tele.gd`, `rt_ability.gd`; `scenes/combat` (Zielpunkt) | Wurf mit Zündschnur, Treffer beider Seiten, Eigenschaden-Regel, Vorabendprogramm ohne | Eigentum `core/rt` + HUD |
| CR-39 h | MB8 Gesprächsboss | `rt_boss.gd` (`run_ops`), `rt_sim.gd` (`submit`), `rt_command.gd`, `rt_result.gd`; `core/live/run_sim.gd`, `autoload/game_replay.gd`; `scenes/combat/combat_director.gd` | Op `prompt`, Befehl `combat_choice`, Ergebnis-Kennzeichen `talked`, Pause und Wahlkarte | Eigentum `core/rt`, M8, HUD |
| CR-39 i | Sprache im Kampf (L2c) | `scenes/combat/**`; `core/rt/rt_sim.gd` (`start`, Ende-Prüfung) | Kampf-HUD-Texte über `Tx` (Leisten, Rahmen, Ergebnisse, Bauchbinden, Hinweiskarten); die Anzeige-Texte „Erstschlag!“, „Hinterhalt!“, „Sendezeit überzogen!“ im Kern mit `Tx.m()` markieren (Text unverändert, bitgleich) | Eigentum `scenes/combat` (R3) und `core/rt` |

---

## 5. Umsetzung

### 5.1 Reihenfolge (SP-22)

```text
          ┌─ P1 Paket-Lader + Aufzeichnung (6–8) ───────────► PB Paket-Build (3–5) ──────┐
 sofort ──┤                                                                              │
          └─ L1 i18n (7–9) ─┬─► L3 Datentexte EN (10–14, parallel je Tabelle) ───────────┤
                            ├─► L2 a, b, d, f Codetexte (11–15) ─────────────────────────┼─► L4 QA (4–6) ─► EN-1
                            ├─► L2 c Kampf-HUD (2–3, nach Freigabe CR-39 i) ─────────────┤
                            └─► L2 e Staffel- und Event-UI (2–3, nach ST1-H/ST1-I) ──────┘
 unabhängig: A1 Art-Kit (3–4) · MB1–MB8 über CR-39 a–h (20–28, je nach Inhalt) · L5 M.O.D. live EN (2–3, nach L4)
```

**Schnellster Weg zu einem spielbaren englischen Build mit Beispielpaket (Meilenstein EN-1):**

1. **P1 und L1 parallel**, sofort (zwei Agenten). P1 berührt `core/data`, `autoload/db.gd`, Run-Log, Spielstände; L1
   `core/data/tx.gd`, `locale/`, Einstellungen, Boot. Beide sind ohne Paket bzw. auf Deutsch bitgleich.
2. Sobald der Extraktor aus L1 die Daten-POT schreibt (Mitte L1): **L3** beginnt mit den Datentexten (dritter Agent),
   Tabellengruppe für Tabellengruppe.
3. Nach L1: **L2** bereichsweise (a → b → d → f; c, sobald CR-39 i freigegeben ist; e nach ST1-H/ST1-I). Nach P1:
   **PB**.
4. **L4**, sobald L2 a–d, f und L3 stehen: Glossar-Review, Captures, Voice-Pass, Korrekturen. **EN-1** = englischer
   Build mit „Testbild“, exportiert über `pack_export.sh` — ohne die Staffel-UI, falls L2e noch wartet.

Aufwand EN-1 (P1, L1, L2 ohne e, L3, L4, PB): **43–60 PT**. Kritischer Pfad L1 → L2 → L4: 24–33 PT, mit L2 auf zwei
Agenten verteilt ≈ 18–25 PT. Mit zwei bis drei parallelen Agenten ≈ **5–6 Kalenderwochen** **[Schätzung]**.

### 5.2 Paketübersicht

| Paket | Inhalt | Wichtigste Dateien | Abhängig von | Aufwand (PT) |
|---|---|---|---|---|
| **P1** | Paket-Lader, Merge mit Herkunft, Paketregeln, `data_hash`, Run-Log-Kopf, Spielstand-Block, Ablehnungen, Nutzerdaten je Paket, Fehlerbildschirm, Testbild-Daten | neu `core/data/pack_loader.gd`, `pack_def.gd`, `validators/pack.gd`, `game/packs/*`; geändert `game_data.gd`, `data_validator.gd`, `validators/ip_words.gd`, `autoload/db.gd`, `game.gd`, `save.gd`, `core/progression/save_codec.gd`, `core/live/run_sim.gd`, `leaderboard.gd`, `scenes/boot/boot.gd` | — | 6–8 |
| **L1** | `Tx`, `LocaleLoader`, `locale/`, Spracheinstellung und Menüzeile, Boot-Reihenfolge, Auto-Übersetzung aus, Extraktor, `i18n.sh`, Lint mit `PENDING`, Formate | neu `core/data/tx.gd`, `locale_loader.gd`, `game/locale/*`, `tools/i18n.sh`, `tests/tools/i18n/*`; geändert `autoload/game.gd`, `game_settings.gd`, `scenes/ui/settings_menu.gd`, `ui_util.gd`, `export_presets.cfg` | — | 7–9 |
| **L2** | Codetexte über `Tx`: **a** Titel, Menüs, Casting 3–4 · **b** Erkundungs-HUD, Safe Room, Interaktionen, Toasts, Show 4–5 · **c** Kampf-HUD (CR-39 i) 2–3 · **d** Stempelduell 2–3 · **e** Staffel- und Event-UI 2–3 · **f** Anzeige-Texte im Kern 2–3 | `scenes/title`, `scenes/ui`, `scenes/exploration`, `scenes/safe_room`, `autoload/show.gd`, `scenes/combat`, `scenes/stempel`, `core/season/sleep_text.gd`, `core/show/persona_text.gd` … | L1 (c: CR-39 i; e: ST1-H, ST1-I) | 15–21 |
| **L3** | Englische Datentexte: `mod_lines` + `scenes` 4–5 · `skills` 1–1,5 · `talents` 1–1,5 · `origins` + `keywords.json` 0,5–1 · übrige große Tabellen 1–1,5 · kleine Tabellen 0,5 · Stempelduell 1 · Codetexte aus L2 1,5–2 | nur `game/locale/en/*.po`, `locale/en/keywords.json` | L1 (Extraktor) | 10–14 |
| **L4** | Englische QA: Glossar- und Distanz-Review, Captures, Voice-Pass, Korrekturen, Playtest | `locale/en/*`, Captures | L2, L3 | 4–6 (+ externes Lektorat) |
| **L5** | M.O.D. live auf Englisch: Filterlisten je Sprache, `ModLineFilter` mit erwarteter Sprache, `ModLiveSummary`, Dienst (`schema.py`, Prompt, Tests) | `data/mod_filter.json`, `core/show/mod_line_filter.gd`, `mod_live_summary.gd`, `services/mod-brain/**` | L4 | 2–3 |
| **A1** | Katzen-Basis, sechs Props, Look-Art `wear`, Regeln, Galerie | `art/kit/archetypes.gd`, `character_builder.gd`, `persona_look.gd`, `core/data/data_validator.gd` (11-A1), `validators/species.gd`, `data/looks.json` | — | 3–4 |
| **MB1–MB8** | Bausteine aus Kap. 4: MB1 3–4 · MB2 2–3 · MB3 3–4 · MB4 2–3 · MB5 1–2 · MB6 4–5 · MB7 2–3 · MB8 3–4 | `core/rt/**`, `scenes/combat/**` (CR-39 a–h), `rt_vocab.gd`/`rt.gd` (11-MB) | Freigabe CR-39 durch 07 | 20–28 |
| **PB** | `pack_check.sh`, `pack_export.sh`, `ip_firewall.sh`, Ausschluss `packs/*` in Grund-Exporten, CI-Schritte, `--pack` im Testlauf mit `PACK_SAFE` | `tools/*`, `export_presets.cfg`, `.github/workflows/ptd-check.yml`, `tests/run_tests.gd` | P1 | 3–5 |

Summen: englischer Weg (P1, L1, L2, L3, L4, PB) **45–63 PT**; alles zusammen **70–98 PT**.

### 5.3 P1 — Paket-Lader und Aufzeichnung (kann sofort starten)

1. **Vertrags-Durchgang 11-P1** (Integrator, additiv): `GameData.load_dir(dir, pack = null)` und die Felder `pack_id`,
   `pack_version`, `pack_hash`; `DataValidator.validate(raw, strict, read_errors, provenance = {})`;
   `IpWords.check(v, provenance)`. Ohne Paket ist `provenance` leer und alles wie heute.
2. `PackDef`, `PackLoader.read`, `merge`, `content_hash`, `compat`, `active_id` — rein, mit `test_11_pack_loader`.
3. `DB._init()` mit aktivem Paket; `DB.data_hash()` mit Paket-Element; `DB.pack`.
4. Aufzeichnungen: Run-Log-Kopf (`Game._make_run_log`, `Save._make_run_log`), Bestenlisten-Eintrag, Spielstand-Block
   (`SaveCodec.encode`), Prüfung vor `_sanitize` (`SaveCodec.decode`), `RunSim.header_errors`/`version_status`,
   `Leaderboard.version_status`; Nutzerdaten je Paket (`Save.save_dir`).
5. Fehlerbildschirm beim Start (`scenes/boot/boot.gd`: statt `route()` eine Fehlerkarte mit den Meldungen).
6. „Testbild“ (Daten, `art.json`; die PO-Dateien kommen mit L1) und `test_11_pack_testbild`, `test_11_pack_records`,
   `test_11_ip_firewall` (Schicht 1).

**Gate:** `check.sh` grün; Fullrun bitgleich; `DB.data_hash()` ohne Paket gleich dem Wert vor P1; Testbild lädt.

**Stand 11-P1 (2026-10-13, Branch `ptd/p1`) — umgesetzt** (Einzelheiten 02_TECH §0.9): (1) Vertrags-Durchgang:
`GameData.load_dir(dir, pack)` mit `pack_id`, `pack_version`, `pack_hash` und den Helfern `pack_fields()` (Kopf,
Eintrag) und `pack_record()` (Spielstand-Block); `DataValidator.validate(…, provenance)` (Feld `provenance`) und
`IpWords.check(v, provenance)` — ohne Paket ist die Herkunft leer und jede Regel wie vorher. (2) `PackDef`, `PackLoader`
(`active_id`, `read`, `compat`, `merge` mit `owned`, `content_hash`; dazu `load_data` für `DB._init`, `merge_patch`,
`patch_paths`, `owned_paths`/`covers`, `provenance`, `debug_save_dir`, `hash_element`, `licence_notes`) und
`validators/pack.gd` (Sperrlisten über alle Texte des Pakets, `tone_exceptions`, Credits eines Lizenzblocks). (3)
`DB.pack`, `pack_via`, `pack_error`, `pack_messages`; `DB.data_hash()` hängt `pack:<id>:<hash>` an, wenn `DB.data` ein
Paket trägt (`DB.data_hash_input()`). (4) Run-Log-Kopf (`Game`, `Save`), Bestenlisten-Eintrag und Spielstand-Block nur
mit Paket; die Paketprüfung in `SaveCodec.decode` vor `migrate`/`validate`/`_sanitize`; `other_pack` ohne Rückfall auf
`.bak`, der Slot nennt das Paket (`Save.slot_summary` → `refusal`, `pack`; Slot-Liste); `other_pack_version` lädt mit
dem Hinweis `SaveCodec.MSG_PACK_UPDATED`; `RunSim.replay`, `Game.replay_log`, `RunSim.header_errors`/`version_status`
und `Leaderboard.version_status` mit den Daten des Builds; Debug-Läufe mit `--pack` unter `user://packs/<id>/`. (5) Die
Fehlerkarte in `boot.gd` statt `route()`. (6) „Testbild“ unter `game/packs/testbild/` (Daten, `art.json`, README),
`PUBLIC_PACKS`, `PRIVATE_PACKS` (leer), `.gitignore`; Tests `test_11_pack_loader`, `test_11_pack_testbild` (ohne PO),
`test_11_pack_records`, `test_11_ip_firewall` (Schichten 1 und 2, F-20), zusammen 47 Tests. **Gate:** `check.sh` grün;
`DB.data_hash()` ohne Paket vor und nach P1
`6c17e6ce623efbb3c584eae1d121c2c04077752084786f7d776507098e593ec3`; `fullrun.sh` (`--strategy=all`, `--hero=mopsula`,
`--liga=1`, `--liga=2`) mit denselben Ereigniszeilen und Statistiken wie `main` — bis auf einen Münzwurf der Darstellung
in `mod_tags`: Ob M.O.D. im Safe Room die Hobby-Variante von `persona_safe_room` sagt, entscheidet `Show._fx_rng`
(`randomize()`, `VARIANT_CHANCE` 0,5); er wechselt auch zwischen zwei Läufen desselben Builds. Ein Debug-Lauf mit `--pack=testbild`
startet bis zum Titel (auch der Autoplay-Smoke), die Königin heißt dort „Die Testbild-Königin von Gleis 9“, und ein
Testbild-Spielstand lädt ohne das Paket nicht (`other_pack`).

**Abweichungen von diesem Dokument:**

- „Testbild“ nennt bis L1 nur `languages: ["de"]` (`read` verlangt zu jeder weiteren Sprache ihre PO-Datei). Der Look
  heißt „Testbildstreifen“: Namen von Looks haben höchstens 16 Zeichen, „Testbild-Streifen“ hat 17.
- `active_id` liefert zusätzlich `via` (`feature`/`arg`), `ids` und `note` und nimmt optional `root` und `features` (ein
  Prädikat statt `OS.has_feature`, damit Tests Export-Tags simulieren). Ein Feature-Tag und `--pack` mit **demselben**
  Paket sind nicht mehrdeutig.
- Der Bestenlisten-Eintrag trägt wie der Kopf `pack`, `pack_version` und `pack_hash` — ohne den Hash ließe sich
  `other_pack_version` nicht erkennen.
- Die Versionsprüfungen bekommen das Paket über ein optionales `data: GameData` (ohne: genau die Prüfung von vorher); die
  Paketprüfung geht der `sim_version` vor. `test_08_k0_contract` pinnt die neuen Signaturen.
- `sub` kennt für `cast` keine Liste: `entries` ist die Tabelle selbst, `names` tragen keine IDs (über `top`).
- Ein mehrdeutiges oder fehlendes Paket lädt die Grunddaten, damit die Autoloads starten — mit `DB.ok = false`,
  `push_error` und Fehlerkarte, nie mit einem Start. `valid_until` warnt zur Laufzeit über `DB`
  (`PackLoader.licence_notes`; der Kern hat keine Uhr), die Prüfung beim Export bleibt PB.
- Schicht 1 in der Variante F-20: Jeder Ordner steht in `PUBLIC_PACKS` oder `PRIVATE_PACKS`, ein Lizenzblock nur für eine
  ID aus `PRIVATE_PACKS` (und die Test-Fixtures); mit `PTD_REPO_VISIBILITY=public` muss `PRIVATE_PACKS` leer sein.
- `Save` setzt den Ordner je Paket in `_ready()` (02_TECH §2.3: Autoloads lesen einander erst dort), nicht in `_init()`.
- Die Paketregeln lesen als Texte zusätzlich `label`, `flavor` und die Formen `n`/`f`/`m` von `role` und `jobs` (Kap. 1.4).

**Offen nach 11-P1:**

- **L1:** die PO-Dateien von „Testbild“ (`locale/en.po`, `locale/de.po`, dann `languages: ["de", "en"]`), die PO-Regeln in
  `validators/pack.gd`, `LocaleLoader.apply(…, DB.pack)`, `PackLoader.LANGUAGES` → `locale/languages.json` und die
  englischen Teile von `test_11_pack_testbild` — erledigt mit 11-L1 (Kap. 5.4 „Stand 11-L1“, L1-14, L1-15).
- **PB:** `pack_check.sh` (ein hineinkopiertes Paket muss in `PUBLIC_PACKS`/`PRIVATE_PACKS` stehen, sonst schlägt
  `test_11_ip_firewall` an — oder der Lauf nimmt nur `PACK_SAFE`-Tests), `pack_export.sh`, `ip_firewall.sh` (die
  Struktur über das ganze Repository statt nur `res://`; Schicht 3), `exclude_filter` `packs/*`, die CI mit
  `PTD_REPO_VISIBILITY`; ob `DirAccess` `res://packs` in einem exportierten PCK listet **[zu prüfen]**.
- **Anzeige:** `EventInfo.version_tag` (`scenes/ui/event_info.gd`, Eigentum L2e/ST1-H) soll
  `Leaderboard.version_status(e, DB.data)` fragen (ausblenden bei `other_pack`, „ältere Version“ bei
  `other_pack_version`); bis dahin trennen die Nutzerordner je Paket die Bestenlisten.
- **L2:** die Ablehnungs- und Fehlertexte über `Tx` (`SaveCodec.MSG_OTHER_PACK`, `MSG_PACK_UPDATED`, `boot.gd`
  `PACK_ERROR_TEXTS`, die Slot-Liste).
- **A1:** Die Art-Regeln finden die Herkunft in `DataValidator.provenance`; die Pfade aus `art.json` stehen als
  `model.…` in `owned`.
- **12 (KS, CR-48):** Ein neuer Block in `pack.json` (etwa `drehbuch`, 12 §7.2) kommt als Schlüssel in
  `PackLoader.MANIFEST_KEYS` plus Feld in `PackDef`; bis dahin ist jeder unbekannte Schlüssel ein Fehler.
- **Folgeänderungen außerhalb von 02_TECH** (Kap. 5.12): `00_BRIEF` Kap. 6 (`packs/`), `05` (Wertungen je Paket), `04`
  §2.4 und `CHANGELOG` („[Pakete]“ ab der ersten Änderung am Datenvertrag).

### 5.4 L1 — i18n-Infrastruktur (kann sofort starten)

1. `Tx` mit Formaten (`locale/formats.json`) und `test_11_tx_format`; `UiUtil.fmt_int`, `fmt_signed`, `fmt_pct` und
   `tr_text` delegieren an `Tx` — deutsche Ausgabe identisch.
2. `LocaleLoader` mit eigenem PO-Parser, `test_11_po`, `test_11_locale`; `locale/languages.json`, `contexts.json`.
3. Einstellung `language`, Menüzeile „Sprache / Language“, Boot-Reihenfolge (Kap. 1.9), `--lang`, Auto-Übersetzung aus.
4. Extraktor, `i18n.sh extract|merge|stats|check`, die vier POT-Dateien, leere `locale/en/*.po`.
5. `test_11_literals` mit `PENDING` (Ausgangszählung je Datei), `test_11_po_rules`, `test_11_lang_determinism`.
6. `export_presets.cfg`: `include_filter` um `locale/*` ergänzen (PO als Datei lesbar; **[zu prüfen]**, ob Godot `.po`
   ohnehin als Ressource exportiert). — Geprüft: Godot 4.7.2 exportiert `locale/*.json` und `locale/en/*.po` mit
   `all_resources` ohnehin als Rohdateien; kein Filter nötig, die Voreinstellungen bleiben unverändert (P-4).

**Gate:** `check.sh` grün; alle deutschen Tests unverändert; Fullrun bitgleich; Start + ≤ 50 ms; `i18n.sh check` grün.

**Stand 11-L1 (2026-10-13, Branch `ptd/l1`, mit 11-P1 zusammengeführt) — umgesetzt** (02_TECH §0.4, §1, §2.1, §3.4,
§11.5, §12.3, §13.1; README §6–8): neu `core/data/tx.gd` (`Tx`), `core/data/locale_loader.gd` (`LocaleLoader`),
`core/data/po_file.gd` (`PoFile`: der strenge Parser und der Schreiber für Werkzeuge und Tests, nicht auf dem
Startweg, L1-13), `core/data/validators/po.gd` (die PO-Regeln, L1-14), `game/locale/` (`languages.json`,
`formats.json`, `contexts.json`, `pot/{ui,data,mod_lines,stempel}.pot`, `en/{ui,data,mod_lines,stempel}.po` — leer,
mit Kopf), `tools/i18n.sh` (`extract`, `merge`, `stats`, `check`, `lint`), `tests/tools/i18n/` (`gd_literals.gd` — der
Literal-Scanner nach den Regeln von `test_09_terms`, `extractor.gd`, `literal_lint.gd`, `i18n_tool.gd`), die Tests
`test_11_tx_format`, `test_11_po`, `test_11_locale`, `test_11_po_rules`, `test_11_literals`,
`test_11_lang_determinism` mit Fixtures unter `tests/fixtures/locale/`; je ein Abschnitt „Sprachen (11-L1)“ in
`autoload/game.gd` (`apply_language()` am Ende von `_init`, die Wurzel ohne automatische Übersetzung in `_ready`),
`game_settings.gd` (`[game] language`), `scenes/ui/settings_menu.gd` (Zeile „Sprache / Language“, Signal
`language_changed`, `focus_row`), `scenes/title/title.gd` (ein Wechsel baut den Titel neu auf und öffnet die Optionen
wieder); `ui_util.gd` (`fmt_int`, `fmt_signed`, `fmt_pct`, `tr_text` delegieren an `Tx`), `project.godot`
(`internationalization/rendering/root_node_auto_translate=false`), `tools/fullrun.sh` (`--lang`). Aus der offenen
Liste von 11-P1: die PO-Dateien von „Testbild“ (`packs/testbild/locale/en.po`, `de.po`; `languages: ["de", "en"]`),
die Paket-PO über der Basis-PO aus `DB.pack` (`PackDef.root`), die PO-Regeln in `validators/pack.gd`,
`PackLoader` liest die Sprachen aus `locale/languages.json`, die englischen Teile von `test_11_pack_testbild`; dafür
gehen die beiden Texte, die „Testbild“ überschreibt, über `Tx.t` (`boot.gd`: „präsentiert“, `title.gd`: „Eine Sendung
des NOVA SYNDIKAT“). `export_presets.cfg` bleibt unverändert (P-4); kein `SIM_VERSION`-Sprung, kein Hash ändert sich.

*Was ein Build zeigt:* Titel → Optionen → „Sprache / Language“ mit *Automatisch / Deutsch / English* (mit einem Paket
nur dessen Sprachen). Ein Wechsel lädt den Katalog sofort, baut den Titel in der neuen Sprache neu auf und öffnet die
Optionen wieder auf derselben Zeile; im Pausemenü steht die Zeile gesperrt mit „Im Titelmenü änderbar“. Bis L2/L3 sind
die Basis-Kataloge leer: Englisch ändert nur die Formate (Zahlen „12,345“, Prozent „36.0%“), jeder Text bleibt das
deutsche msgid. `--lang=en` gilt für einen Lauf und wird nie gespeichert; Tests, Capture, Autoplay und Full-Run-Bot
spielen ohne `--lang` Deutsch. Ein Debug-Lauf mit `--pack=testbild` zeigt auf Deutsch (`--lang=de`) auf der
Bootkarte „präsentiert im Testbild“, auf Englisch (`--lang=en`) unter dem Logo „A NOVA Media Group test broadcast“;
die englischen Namen des Pakets (Bossname, Ansage, Look) stehen im Katalog und erscheinen, sobald L2 deren Anzeige über
`Tx.data` führt.

**API** (Kap. 1.2 mit den Ergänzungen aus L1-2):

```gdscript
Tx.t(msgid, ctx = "")   Tx.n(msgid, plural, count, ctx = "")   Tx.data(table, id, text)   Tx.data_ctx(table, id)
Tx.m(msgid)   Tx.lang()   Tx.plural_index(count)
Tx.fmt_int(v)   Tx.fmt_signed(v)   Tx.fmt_dec(v_pm, decimals = 1)   Tx.fmt_pct(p_pm, decimals = 1)
Tx.fmt_float(v, decimals = 1)   Tx.fmt_pct_f(ratio, decimals = 1)   Tx.fmt_clock(minutes)   Tx.fmt_weekday(wd)
Tx.fmt_date(day, month)   Tx.fmt_wday_date(wd, day, month)   Tx.fmt_duration(sec)   Tx.quote(s)
Tx.use_language(code, catalog, plurals)   Tx.formats_of(code)          # LocaleLoader, Tests, Werkzeuge
LocaleLoader.languages()  codes()  is_language(code)  source_lang()  language_name(code)  setting_values(allowed = [])
LocaleLoader.arg_language(user_args)
LocaleLoader.resolve(setting, user_args, ephemeral, os_language, allowed = [], fallback = "") -> String
LocaleLoader.build(lang, pack_dir = "", root = ROOT) -> {lang, translation, plurals, count, files, missing, errors}
LocaleLoader.apply(lang, pack_dir = "", root = ROOT) -> Dictionary   # build(), anmelden, set_locale, Tx
LocaleLoader.pack_dir(pack: PackDef)  pack_languages(pack)  pack_default_lang(pack)   # DB.pack (11-P1)
LocaleLoader.read_messages(text, into = null, plurals = {})  unescape(body, source, line, errors)
PoFile.parse(text, source = "po", meta = false)  messages(po)  po_string(s)  po_field(keyword, s)   # Werkzeuge, Tests
PoRules (validators/po.gd): check_text(text, source, limits = {})  check_pack_po(text, source, lang, limits)
                            base_limits(pot_dir)  pack_po_files(packs_root)  entry_errors(…)  missing_glyphs(text)
Game.apply_language(from_menu = false) -> String
```

**Prüfergebnisse** (die **[zu prüfen]** aus Kap. 1.2 und 5.4, mit Godot 4.7.2):

| Nr. | Frage | Ergebnis |
|---|---|---|
| P-1 | Reihenfolge mehrerer `Translation` derselben Sprache im `TranslationServer` | spielt keine Rolle: `LocaleLoader` meldet je Sprache genau **eine** zusammengeführte `Translation` an (Basis-PO, darüber die Paket-PO) und entfernt vorher die vorige; `TranslationServer.find_translations("en")` liefert eine. |
| P-2 | `Translation.add_plural_message` in 4.7 | vorhanden (`add_plural_message(src, forms, ctx)`, `get_plural_message`); eine Klasse `TranslationPO` gibt es in 4.7.2 **nicht**. `Tx.n` wählt die Form selbst (Tabelle `plurals`, Regel `one_other` aus `formats.json`); die `Translation` trägt die Formen zusätzlich für `tr_n()`. |
| P-3 | Popups außerhalb des Wurzelbaums (SP-3) | Alles im Baum erbt `AUTO_TRANSLATE_MODE_DISABLED` von der Wurzel: `CanvasLayer`, `SubViewport`, `Window`, `AcceptDialog`/`ConfirmationDialog` (Text und Knöpfe), `PopupMenu` (auch das von `OptionButton`/`MenuButton`), `PopupPanel`, `TabBar` und das Tooltip-Popup (internes Kind). Knoten außerhalb des Baums melden `can_auto_translate() == true`, werden aber nie gezeichnet; beim Eintreten erben sie. Übersetzen würde nur ein ausdrückliches `AUTO_TRANSLATE_MODE_ALWAYS` (kommt im Code nicht vor). Gesichert in `test_11_locale`. Nebenwirkung: Der Fenstertitel wird nicht mehr automatisch übersetzt — er bleibt „Prime Time Dungeon“ (F-13). |
| P-4 | Exportiert Godot `.po` ohne `include_filter`? | **Ja**: `export_filter="all_resources"` nimmt in 4.7.2 die Nicht-Ressourcen-Dateien des Projekts als Rohdateien mit — geprüft mit `--export-pack` (Linux) und dem eingehängten Paket: `locale/*.json` und `locale/en/*.po` sind über `FileAccess` lesbar, `locale/pot/*.pot` fehlt (gewollt). `export_presets.cfg` bleibt unverändert (`test_perf_platform` prüft die Filter wörtlich); `test_11_locale` sichert, dass keine Voreinstellung `locale/` ausschließt. Nebenbefund (02_TECH §12.3 vermerkt ihn): Die Begründung des `include_filter="data/*.json"` — JSON fehle sonst — trifft auf 4.7.2 nicht mehr zu; der Filter bleibt als Absicherung. |
| P-5 | Ladezeit (Messziel ≤ 50 ms auf dem Telefon) | Desktop, 4 Kerne unter Last 9–16: die vier leeren englischen PO-Dateien ≈ 8–43 ms Wandzeit (meist ≈ 11–23 ms; CPU-Zeit 3–8 ms), mit der PO von „Testbild“ 8–12 ms; der volle Katalog (alle msgids synthetisch übersetzt) ≈ 28 ms (Last 9) bis ≈ 56 ms (Last 12) — Godots eigener PO-Lader brauchte für dieselben Dateien ≈ 70 ms. Deutsch ohne Paket-PO liest keine Datei. Telefon **[zu messen, L4]**; Rückfall bleibt der vorkompilierte Katalog beim Export. |
| P-6 | CSV in 4.7 (Kontext, Plural) | nicht geprüft — mit der Entscheidung für PO (SP-1) ohne Belang. |

**Entscheidungen 11-L1** (Auslegungen und Abweichungen):

| Nr. | Thema | Entscheidung | Kap. |
|---|---|---|---|
| L1-1 | `fmt_signed` | „+12“ / „-3“ / „0“: Null ohne Zeichen und ASCII-Minus wie `UiUtil.fmt_signed` vor L1 (Gate „deutsch bitgleich“); „±0“ und „−3“ aus Kap. 1.7 wären eine sichtbare Änderung der deutschen Ausgabe. | 1.2, 1.7 |
| L1-2 | API-Ergänzungen | `fmt_float` und `fmt_pct_f` (Anzeige-Floats, die es heute gibt: `UiUtil.fmt_pct` und die sieben `replace(".", ",")`, die L2 umstellt), `fmt_wday_date` („Mo 12.10.“ / „Mon, Oct 12“), `data_ctx`, `plural_index`, `formats_of`, `use_language`. Fehlt `formats.json`, gelten die deutschen Formate aus `Tx.FORMATS_DE` — die deutsche Ausgabe hängt an keiner Datei. | 1.2, 1.7 |
| L1-3 | Fehlende Dateien | Fehlen **alle** Basis-PO einer Sprache, bleibt der Lauf deutsch (Warnung); fehlt eine, fehlen nur deren Texte (Warnung). Der Laufzeit-Leser (`read_messages`, zwei native RegEx-Durchgänge, dann nur die übersetzten Einträge) überspringt fehlerhafte Zeilen still — die Regeln prüfen `PoFile.parse` in `i18n.sh check` und `test_11_po_rules`; `test_11_po` hält beide Leser gleich. Eine Zeile „[LocaleLoader] en: 4 PO files, … messages (… ms)“ meldet jedes Laden mit Dateien; Deutsch ohne Paket-PO liest keine Datei und schreibt nichts. | 1.9 |
| L1-4 | „Automatisch“ | die Systemsprache, wenn sie eine der Sprachen aus `languages.json` ist, sonst Englisch (Kap. 1.9 verallgemeinert für eine dritte Sprache). Gespeichert wird `auto`, `de` oder `en`; ein unbekannter Wert gilt als `auto`. Flüchtige Läufe ohne `--lang`: Deutsch; ein unbekannter `--lang`-Code: Deutsch mit Warnung. | 1.9 |
| L1-5 | Wechsel im Titel | Der Katalog wechselt sofort (`Game.apply_language(true)`), der Titel baut sich über `Router.goto(SCENE_TITLE, {"options": "language"})` neu auf und öffnet die Optionen wieder auf der Zeile — kein Neustart. | 1.9 |
| L1-6 | Lint | `tr("…")` und `tr_text("…")` gelten noch nicht als `Tx` (L2 stellt sie um). Ausnahmen je Datei (Validatoren, `RtCheck`, Galerien, Debug-Overlay, die Bots, die eingefrorene CTB-Engine, die Sprach-Maschinerie) und je Zeile (`# no-i18n: <Grund>`); ein einzelnes Zeichen ist kein Text. | 1.12 |
| L1-7 | Extraktor | Datentexte aus den JSON-Dateien selbst statt über `GameData` (die Normalisierung fügt keine Texte hinzu; das msgid ist der geschriebene Text); Kontexte nach Kap. 1.4, Stempelduell-Daten mit `stempel.<datei>`; Code unter `core/stempel/**` gehört zur Domäne `stempel`. Übersetzerkommentare `#.` mit `max N` (Limits aus den Validator-Konstanten; Fähigkeitsnamen: höchstens so lang wie deutsch), Tag und Stimme der Sprechzeilen und der Bedeutung der Platzhalter; Fundstellen `#:` als `<datei>:<id>.<feld>` bzw. `<skript>:<zeile>`; `%`-msgids des Codes tragen `#, c-format`, damit `msgfmt --check-format` die Platzhalter prüft. Szenentexte: heute keine. | 1.4, 1.11 |
| L1-8 | Aktualität | „POT aktuell“ und „PO gemischt“ prüft nur `i18n.sh check` (braucht GNU gettext), nicht `check.sh`: Sonst bräche jeder parallele Branch mit neuen Texten `check.sh`, bevor er `extract` lief. `merge` behält die Reihenfolge der POT (der Extraktor sortiert schon stabil) statt `--sort-by-file`. | 1.11 |
| L1-9 | Determinismus-Test | `test_11_lang_determinism` spielt eine Kampagne (Safe Room, Echtzeitkampf auf Autopilot, Lootbox, Rast), eine Staffel-Nacht (`sleep`, Sendepause, 30 h `away`; von `RunSim` aufgezeichnet, über `Game.replay_log` nachgespielt) und das Golden-Stempelduell auf Deutsch und mit vollem englischem Katalog (jedes msgid der vier POT übersetzt, englische Formate): gleicher `StateHash`, gleiches Run-Log (ohne die zufällige `run_id`), gleiche Kampfereignisse ohne `text`, gleiches Duell; ein deutsches Run-Log spielt englisch auf denselben Hash. | 1.10 |
| L1-10 | Nicht in L1 | `test_11_terms_en` und die Capture-Rezepte `en_*` kommen mit L3/L4 — ohne englische Texte gibt es nichts zu prüfen. | 1.12, 5.10 |
| L1-11 | Layout | Die Locale selbst verschiebt kein Layout: Labels mit Umbruch brechen deutsche Texte unter `set_locale("en")` genauso um wie unter `"de"` (Zeilenzahl und Mindestgröße gleich, headless geprüft). Bis L3 ändert `--lang=en` also nur die Zahlen; die englischen Captures (L4) prüfen erst die Übersetzungen. | 1.8 |
| L1-12 | Laufzeit-Texte aus 12 | Staffel-Skripte des KI-Showrunners (12) kommen zur Laufzeit schon in der Zielsprache: Sie laufen an `Tx.t` vorbei und haben keine msgids; nicht jeder angezeigte Text steht in einer POT. | 1.11 |
| L1-13 | Startzeit | Was L1 einem deutschen Start hinzufügt, ist fast nur Kompilierzeit: `Tx` und `LocaleLoader` (Sprachwahl, Aufbau, Laufzeit-Leser); `apply("de")` liest keine Datei. Deshalb liegen der strenge Parser und der Schreiber in `PoFile` (nur Werkzeuge und Tests) — das senkt die Kompilierzeit von `LocaleLoader` um ≈ 40 %. Die Uhr der Log-Zeile steht in `Game.apply_language`, nicht im Kern (`test_m8_no_global_rng`: keine Uhr unter `core/`). Messwerte unten. | 1.2, 5.9 |
| L1-14 | Regeln der Paket-PO | Die PO-Regeln (`core/data/validators/po.gd`, vorher `tests/tools/i18n/po_rules.gd`) laufen beim Laden eines Pakets für jede `locale/<sprache>.po` (`validators/pack.gd`, Kap. 3.5 Nr. 4): Ein Verstoß macht das Paket ungültig (Fehlerkarte), dazu muss die Sprache im Kopf dem Dateinamen entsprechen. Die Grenzen der Basis-Einträge, die ein Override ersetzt, kennen nur die POT-Dateien (nicht im Export): `test_11_po_rules` und `i18n.sh check` (dort auch `msgfmt` über die Paket-PO) prüfen sie zusätzlich. Im Kern prüft `PoRules.missing_glyphs` den Standard-Font selbst — der Kern darf `scenes/ui/ui_util.gd` nicht laden. | 3.5, 3.6 |
| L1-15 | Sprachen eines Pakets | `pack.json → languages` begrenzt die Optionszeile (`setting_values(allowed)`) und die Wahl (`resolve`, außerhalb gilt `default_lang`); `PackLoader` prüft die Codes gegen `locale/languages.json` statt gegen eine eigene Liste. Die Overrides von „Testbild“ wirken nur, wo die Anzeige `Tx` fragt: Deshalb gehen die Bootkarte „präsentiert“ und der Untertitel des Titels schon jetzt über `Tx.t` (`PENDING` je −1); der Rest der Codetexte folgt mit L2. | 1.9, 3.6, 3.14 |

**Messwerte** (Box mit 4 Kernen, parallel ausgelastet von anderen Agenten; Spannen statt Einzelwerte):

- `tools/check.sh` (voll, nach dem Merge von 11-P1): **grün** — 1 933 Tests bestanden, 0 fehlgeschlagen, Testlauf
  1 033 s, mit Import und Smoke 1 091 s Wandzeit (Last ≈ 6–9). Zwei Läufe davor unter höherer Last scheiterten nicht an
  L1: einmal am Zeitbudget von `test_09_zone_generator` und am Rundungs-Flake von `test_m2_show` (siehe „Offen“),
  einmal am 1 200-s-Limit des Testlaufs. `tools/i18n.sh check` grün (Basis-PO und die PO von „Testbild“).
- Fullrun (`--strategy=all`, `--hero=mopsula`, `--liga=1`, `--liga=2`) gegen `main` vor P1 (`a8c48a5`) und nach P1
  (`0514cf5`): jeweils `fullrun.sh: OK`, dieselben Zeilen „FULLRUN: OK …“ (thorough `floor_time=320 battles=20
  frames=16739`, rush `427/22/23926`, dawdle `313/21/29733`, Mopsula `375/20/16389`, Liga 1 `374/23/20744`, Liga 2
  `319/20/16695`) und dieselben Ereigniszeilen (118, 130, 123, 115, 115, 124, 112); `--strategy=all --lang=en` gibt
  dieselben Zeilen wie der deutsche Lauf (auch alle Ereigniszeilen). Die Zeilen „FULLRUN: stats“ sind bis auf den
  Münzwurf der Darstellung in `mod_tags` gleich
  (ob M.O.D. im Safe Room die Hobby-Variante von `persona_safe_room` sagt, entscheidet `Show._fx_rng` nach
  `randomize()`): Er wechselt auch zwischen zwei Läufen desselben Builds (`main` gegen `main` geprüft; derselbe Befund
  wie in „Stand 11-P1“). Verglichen mit diesem einen Feld normalisiert.
- Start (Box unter Last 8–16, Spannen über abwechselnde Läufe): `tools/perf.sh --only=startup` (Xvfb, je 2 Läufe):
  `main` Start bis Hauptschleife 4,6–8,8 s, Titel interaktiv 17,9–28,9 s; `ptd/l1` 9,4–12,5 s bzw. 26,0–40,8 s. Der
  Boot-Timer allein (je 6 Läufe `main` / L1 deutsch / L1 englisch): Hauptschleife 5,7–10,7 / 7,2–12,6 / 4,9–11,7 s,
  Titel 11,7–18,4 / 14,3–27,6 / 12,5–21,7 s — Englisch (mehr Arbeit) liegt unter Deutsch: Das Rauschen ist größer als
  die ganze Messgröße. Genauer: die CPU-Zeit eines Headless-Starts (je 9 Läufe) `main` 4,98–5,33 s, L1 deutsch
  4,99–5,61 s, L1 englisch 4,94–5,79 s (Minima +14 ms bzw. −36 ms), und im Prozess gemessen (Thread-CPU-Zeit, 21
  Wiederholungen, Last ≈ 7) das, was L1 einem Start hinzufügt: `Tx` kompilieren 8–12 ms, `LocaleLoader` 20–24 ms (vor
  der Abspaltung von `PoFile` 32–43 ms), `apply("de")` < 0,1 ms, `apply("en")` mit den vier leeren PO 3–8 ms.
  **Deutsch ≈ +30–35 ms CPU unter Last, Englisch ≈ +8 ms mehr — innerhalb von +50 ms;** mit vollem Katalog P-5.
- Extraktor: `ui` 70, `data` 1 537, `mod_lines` 728, `stempel` 242 msgids (zusammen 2 577, noch keine Pluralformen);
  89 dynamische Aufrufe (`tr(def.name)`, `tr_text(…)` mit Variablen; die Daten sind ihre Quelle, L2 stellt sie auf
  `Tx.data` um), 34 msgids in mehreren Domänen oder Kontexten. „Testbild“: `en.po` 4 Einträge (drei Paket-Texte, ein
  Override), `de.po` 1 Override; `i18n.sh stats --pack=game/packs/testbild` (Namensprüfung, Kap. 3.6) warnt bei zwei
  Basis-Texten, die die alte Königin noch nennen (Quest-Ziel „Besiege die Rattenkönigin von Gleis 9.“ und die
  beibehaltene Bossansage) — das Paket lässt sie als Beispiel der Warnung stehen.
- `PENDING`: 911 Funde in 91 Dateien (mit den Texten, die 11-P1 brachte: `save_codec.gd` 3, `boot.gd` 6,
  `slot_select.gd` 16) — `scenes/ui` 347, `scenes/stempel` 181, `scenes/title` 96, `core/season` 78, `scenes/combat`
  67, `scenes/exploration` 43, `scenes/safe_room` 36, `core/show` 34, der Rest 29.

**Offen** (für die Folgepakete):

- **Merges nach L1:** Pakete, die vor L1 begonnen haben (09 ST1-H, ST1-I), bringen deutsche Spielertexte ohne `Tx`
  mit, und `test_11_literals` meldet ihre Dateien. Beim Merge trägt der Integrator sie mit den Zahlen von
  `tools/i18n.sh lint` in `PENDING` ein (oder hüllt die Texte in `Tx.t`) und lässt `i18n.sh extract` und `merge`
  laufen — so geschehen mit den Texten von 11-P1. Arbeit, die nach L1 beginnt, schreibt Spielertexte gleich mit
  `Tx.t` (02_TECH §13.1).
- **L2:** Namens-Tabellen in Konstanten (`UiUtil.ELEMENT_NAMES`, `SaveCodec.MSG_*`, `boot.gd` `PACK_ERROR_TEXTS` u. a.)
  werden `static var X := {"common": Tx.m("Gewöhnlich")}` (markiert für den Extraktor), übersetzt erst in der Anzeige
  mit `Tx.t`; die 89 dynamischen Aufrufe gehen auf `Tx.data(table, id, text)` — erst dann zeigt das Spiel die
  englischen Namen von „Testbild“; `pack.json → name` über die Paket-PO (Kap. 3.6, z. B. Kontext `pack`);
  `events.json` (F-17).
- **PB:** CI-Schritte `tools/i18n.sh check` (braucht `apt-get install gettext`) und `fullrun.sh --strategy=all
  --lang=en` mit Vergleich der Zeilen „FULLRUN: stats“ und „FULLRUN: OK“ gegen den deutschen Lauf — mit dem
  Münzwurf in `mod_tags` normalisiert, oder M6/M2 setzen `Show._fx_rng` im Full-Run-Bot auf einen festen Seed (dann
  sind die Zeilen bitgleich).
- **Befunde für andere Pakete** (beim Gate gesehen, nicht durch L1):
  `test_m2_show.test_show_battle_events_signals_and_lines` schlägt selten fehl — der Test rückt `Show._now` um genau
  `RT_LINE_GAP_SEC` vor, und liegt `_now` knapp unter einer Zweierpotenz (im vollen Lauf ≈ 506–512 s), rundet
  `(_now + 6) − _now` unter 6,0, und die Zeile fällt weg (Abhilfe im Test: `+ RT_LINE_GAP_SEC + 0.01`);
  `test_09_zone_generator` prüft die längste Bauzeit gegen 250 ms und scheitert unter Last; die volle Testsuite
  braucht unter Last 1 170–1 250 s, `check.sh` erlaubt 1 200 s.
- **Vor EN-1 (erster englischer Build):** „Automatisch“ zeigt auf englischen Systemen bis L3 deutsche Texte mit
  englischen Formaten.
- **L4:** Ladezeit auf dem Referenz-Telefon (P-5); wenn nötig ein `user://`-Cache oder der beim Export vorkompilierte
  Katalog.

### 5.5 L2 — Codetexte bereichsweise

Je Bereich dieselben Handgriffe: Literale in `Tx.t`/`Tx.n`, `%`-Formate mit mehreren Argumenten auf benannte
Platzhalter, Zahlen über `Tx.fmt_*` (die sieben `replace(".", ",")` verschwinden), Sätze als ganze msgids (Kap. 3.6),
`i18n.sh extract`, `PENDING` der Dateien des Bereichs auf 0. Jeder Bereich ist ein eigener Branch und landet, wenn
seine Eigentümer-Phase ruhig ist:

| Teil | Bereich | Eigentum (Absprache) | wartet auf |
|---|---|---|---|
| L2a | `scenes/title/**` (Titel, Casting, Namenseingabe, Intro, Credits), Menüs in `scenes/ui/**` (Optionen, Pause, Party, Fähigkeiten, Inventar, Bestiarium) | M6, 08 | — |
| L2b | `scenes/exploration/**`, `scenes/safe_room/**`, `autoload/show.gd`, HUD und Toasts in `scenes/ui/**` | M3, M2, M6 | — |
| L2c | `scenes/combat/**` (Leisten, Rahmen, Ergebnisse, Bauchbinden, Hinweiskarten) + Markierungen in `core/rt` | R3 (07) | CR-39 i |
| L2d | `scenes/stempel/**`, Anzeige-Texte in `core/stempel/**` (ohne die eingefrorene Engine `core/stempel/ctb/`) | SD (10) | — |
| L2e | Staffel- und Event-UI (Lobby, Sendeplan, Abmelde-Dialog, Login-Bilanz, `event_info.gd`) | 09 ST1-H, M8 | ST1-H und ST1-I gelandet |
| L2f | Anzeige-Texte im Kern: `SleepText`, `PersonaText` (`club`, `cand`), `RunSim.OLD_VERSION_TAG`, `SaveCodec.MSG_NEWER`, `Save.MSG_SEASON_OVER`, Kern-Ereignistexte (`Tx.m`) | ST1-B/G, 08, M2, M8 | — |

„Präventivschlag!“ in `core/stempel/ctb/battle_state.gd` (`TEXT_PREEMPTIVE`) bleibt unberührt — eingefrorene Engine mit
Golden-Test (10 §7.5); die Anzeige des Stempelduells übersetzt das Ereignis.

### 5.6 L3 — Englische Datentexte

Ablauf je Tabellengruppe: KI-Entwurf mit Glossar (Kap. 2) und Stimmregeln (Kap. 2.7/2.8) als Vorgabe → `i18n.sh check`
→ Review in L4. Jede Gruppe ist ein eigener Branch, der **nur** `locale/en/<domäne>.po` (und `keywords.json`) ändert;
so arbeiten bis zu drei Agenten parallel ohne Konflikte. Reihenfolge nach Sichtbarkeit: Etage 1 zuerst (Zeilen bis
Etage 1, Gegner, Gegenstände, Achievements), dann Staffel-Inhalte, dann das Stempelduell. Ziel: 100 % übersetzt,
0 „fuzzy“.

### 5.7 L4 — Englische QA (und L5)

1. **Glossar- und Distanz-Review** der Zeilen aus Kap. 2.6 und aller Eigennamen (04 §2.3), mit Markensuche für
   Sponsoren- und Ortsnamen **[zu prüfen]**.
2. **Captures** englisch bei 1280 × 720 und 2400 × 1080 `--touch` (Kap. 1.12), Sichtprüfung auf Überläufe und deutsche
   Reste; Pseudo-Lokalisierung (`--lang=xx`: jedes msgstr als „[!! … !!]“, 30 % länger) als Suchhilfe.
3. **Voice-Pass** durch eine englischsprachige Lektorin bzw. einen Lektor (extern): M.O.D., Mopsula, Chat,
   Ein-Satz-Erklärungen; Prüfliste aus Kap. 2.7.
4. **Playtest** mit drei bis fünf englischsprachigen Personen (Etage 1, Casting, ein Stempelduell).
5. **L5** (optional, danach): M.O.D. live auf Englisch mit freigegebenen Filterlisten (Kap. 1.13).

### 5.8 PB, A1, MB

- **PB:** `tools/pack_check.sh <paketordner> [--lang=en] [--shots=<ordner>]` — temporäre Projektkopie wie `check.sh`,
  Paket hinein, Import, `run_tests.gd --pack=<id>` (dort laufen nur Testdateien mit `const PACK_SAFE := true`, weil die
  übrigen deutsche Grunddaten wörtlich prüfen), Autoplay-Smoke mit `--pack`, optional Captures; `tools/pack_export.sh`
  (Kap. 3.8); `tools/ip_firewall.sh structure|scan|fingerprints|baseline|expect-hits` (Kap. 3.12);
  `export_presets.cfg` `exclude_filter` += `packs/*`; in `ptd-check.yml` die Schritte „Pack check (testbild)“ und
  „IP firewall“. Die private Vorlage bleibt in Kap. 3.13.
- **A1:** wie Kap. 4.10; unabhängig, auch für PTD (Katzen-Gegner, Sonnenbrille als Persona-Option). Umgesetzt (Kap. 4.10
  „Stand 11-A1“).
- **MB:** je Baustein erst, wenn ein Inhalt ihn braucht und 07 den Punkt aus CR-39 freigegeben hat; mit dem
  PTD-Einsatz aus Kap. 4 als erstem Inhalt. Der Vertrags-Durchgang 11-MB bringt die Vokabulare des Bausteins mit.

### 5.9 Gates

| Gate | Pakete | Kriterium |
|---|---|---|
| `check.sh` | alle | grün (Import, Tests, Smoke) |
| **Bitgleich ohne Paket, auf Deutsch** | P1, L1, L2, A1, MB, PB | `tools/fullrun.sh --strategy=all` liefert dieselben Zeilen „FULLRUN: stats {…}“ und „FULLRUN: OK …“ wie vor dem Paket; `DB.data_hash()` ohne Paket unverändert; `test_r1_rt_golden`, `test_sd_engine_golden`, `test_sd_golden` grün |
| **Sprache neutral** | ab L1 | `fullrun.sh --strategy=all --lang=en` liefert dieselben Zeilen wie der deutsche Lauf; `test_11_lang_determinism` grün |
| Paket | P1, PB | `pack_check.sh game/packs/testbild` grün |
| Start | L1, P1 | Startzeit + ≤ 50 ms gegenüber vorher (`tools/perf.sh`); L1 gemessen (Kap. 5.4 „Stand 11-L1“) |
| Übersetzung | L3, L4 | `i18n.sh check` grün; Builds, die als englisch ausgeliefert werden: 100 % übersetzt, 0 „fuzzy“ |
| Layout | L4 | englische Captures ohne Überlauf (Sichtprüfung), Längenregeln in `test_11_po_rules` grün |
| IP | L4, PB | Distanz-Review der englischen Begriffe abgeschlossen; `ip_firewall.sh scan` grün |

### 5.10 Tests (neu)

| Test | Paket | Kurz |
|---|---|---|
| `test_11_po`, `test_11_locale`, `test_11_tx_format`, `test_11_po_rules`, `test_11_literals`, `test_11_terms_en`, `test_11_lang_determinism` | L1 (Regeln wachsen mit L2/L3) | Kap. 1.12 |
| `test_11_pack_loader` | P1 | `read`, `merge` (Reihenfolge, Merge Patch, Fehler, geschützte IDs, `touches`, Herkunft), `content_hash`, `compat`, `active_id` (Feature-Tag simuliert, Debug und Release) |
| `test_11_pack_testbild` | P1 (+ L1 für die PO) | Kap. 3.14 |
| `test_11_pack_records` | P1 | `data_hash`, Run-Log-Kopf, Spielstand-Block, alle Ablehnungen, Prüfung vor `_sanitize`, Nutzerdaten-Pfade; ohne Paket gleiche Köpfe und Digests |
| `test_11_ip_firewall` | P1, PB | Schicht 1 (Whitelist, Lizenzblock, Orte); Schicht 2 mit Fixture-Paket (Lizenz-Ausnahme nur für IP-Abstand, nie für Ton); Schicht 3 mit Testschlüssel und Testbegriffen aus PTD-eigenen Wörtern |
| `test_11_art_kit` | A1 | Kap. 4.10 |
| `test_11_mb1_scavenger` … `test_11_mb8_talk` | MB1–MB8 | je Baustein: Regeln, Reihenfolge im Tick, Ereignisse, Determinismus (zwei Läufe gleich), Bitgleichheit ohne Daten |
| Capture-Rezepte `en_*` | L1–L4 | Kap. 1.12 |

### 5.11 Dateieigentum

| Datei / Bereich | Eigentum | Regel |
|---|---|---|
| `core/data/tx.gd`, `locale_loader.gd`, `pack_loader.gd`, `pack_def.gd`, `validators/pack.gd`, `game/locale/**`, `game/packs/**`, `tools/i18n.sh`, `pack_check.sh`, `pack_export.sh`, `ip_firewall.sh`, `tests/test_11_*`, `tests/tools/i18n/**` | **11** (neu) | neu |
| `core/data/game_data.gd`, `data_validator.gd`, `validators/ip_words.gd`, `validators/species.gd`, `validators/rt_vocab.gd`, `validators/rt.gd` | Vertrags-Durchgänge | 11-P1, 11-A1, 11-MB — additiv |
| `autoload/db.gd`, `game.gd`, `save.gd`, `game_settings.gd`; `core/progression/save_codec.gd`; `core/live/run_sim.gd`, `leaderboard.gd` | M0 / M2 / M8 (+ Abschnitte aus 05–10) | je ein Abschnitt 11, additiv, ohne Paket bitgleich |
| `scenes/ui/**`, `scenes/title/**`, `scenes/exploration/**`, `scenes/safe_room/**`, `scenes/stempel/**` | M6 / M3 / 08 / SD | L2: nur Texte über `Tx`, kein Umbau |
| `scenes/combat/**`, `core/rt/**` | R-Phasen (07) | nur über CR-39 |
| Staffel-UI (ST1-H) und Harness (ST1-I) | 09 ST1-H, ST1-I | L2e erst nach deren Landung; 11 fasst ihre Dateien vorher nicht an |
| `art/kit/**`, `data/looks.json` | M4 / 08 | A1 additiv |
| `data/mod_filter.json`, `core/show/mod_line_filter.gd`, `mod_live_summary.gd`, `services/mod-brain/**` | 06-D | L5 |
| `export_presets.cfg`, `.github/workflows/ptd-check.yml` | M0 | PB additiv |
| `docs/11_SPRACHEN_UND_INHALTSPAKETE.md` | 11 | — |

### 5.12 Änderungsanträge und Folgeänderungen

- **CR-39** an `07` (Kap. 4.11); ein Hinweis-Absatz steht seit diesem Dokument in 07 §12.10.
- **Vertrags-Durchgänge** 11-P1, 11-A1, 11-MB (02_TECH §0; die laufende Nummer vergibt der Integrator).
- **Verweise** (mit diesem Dokument eingetragen): `00_BRIEF` Kap. 4 „Sprache“ und Vorrangklausel, `02_TECH` §4.1 und
  §4.5, `README.md` (Dokumente, Ordnerbaum), `07` §12.10.
- **Folgeänderungen, wenn die Pakete landen** (ohne CR-Nummer, wie 10 Kap. 7.6):

| Dokument | Stelle | Änderung | mit |
|---|---|---|---|
| `02_TECH` | §0.4, §1, §3.3, §6.4, §11, §12.3, §12.4, §13.1 | Schicht von `Tx`, `LocaleLoader`, `PackLoader`; Dateibaum `locale/`, `packs/`, Werkzeuge; `DB.pack`; Spielstand-Block `pack`; Tests; Export-Filter; CI-Schritte; Regel „Spielertexte nur über `Tx`“ | P1, L1, PB |
| `00_BRIEF` | Kap. 6 (Ordner) | `locale/`, `packs/` | L1, P1 |
| `03_ART` | §5.3–5.5 | Basis `cat`, sechs Props, Look-Art `wear`, Budgets | A1 |
| `04` | §2.3, E2, §2.4 | englische Zeilen des Distanz-Reviews (Kap. 2.6); Umbenennungen; Verweis auf das Paketmodell (O-1) | L4, P1 |
| `05` | Bestenlisten | Wertungen je Paket (`data_hash` + `pack`) | P1 |
| `06` | L-1 … L-7, §5.9 | gelten englisch (Kap. 2.7); Filterlisten je Sprache | L4, L5 |
| `08` | §1.2, §4.4 | Wortform-Zeile englisch ausgeblendet; Platzhalter-Längen englisch; englische Filter für Namen und Freitext | L2a |
| `09` | §1.2 | englische Sprachregel (Kap. 2.1) | L4 |
| `10` | Regelbuch, Kurznamen | Domäne `stempel`; Kurznamen ≤ 7 Zeichen auch englisch | L2d, L3 |
| `README.md` | Start und Werkzeuge | `--lang`, `--pack`, `i18n.sh`, `pack_check.sh`, `pack_export.sh` | L1, PB |
| `CHANGELOG.md` | — | Präfix „[Pakete]“ für Änderungen am Datenvertrag | P1 |

---

## 6. Risiken und offene Fragen

### 6.1 Risiken

| # | Risiko | W / A | Gegenmaßnahme | Frühindikator |
|---|---|---|---|---|
| R1 | Versteckte deutsche Texte (zusammengesetzte Strings, dynamische Texte, Debug-Wege, die doch Spieler:innen sehen) | hoch / mittel | Lint mit `PENDING`, Extraktor meldet „dynamisch“, englische Captures aller Bildschirme, Pseudo-Lokalisierung | deutsche Wörter in englischen Captures |
| R2 | Englischer Humor zündet nicht, Zeilen klingen übersetzt | mittel / hoch | umschreiben statt übersetzen (Kap. 2.7), externes Lektorat, Playtest | „lustig“-Wertung im Playtest unter der deutschen |
| R3 | IP-Nähe, die erst im Englischen entsteht | mittel / hoch | Glossar mit Abstandsspalte, Distanz-Review, Fingerabdrücke | Review-Funde |
| R4 | Übersetzter Text gerät in Zustand, Befehl oder Hash | niedrig / hoch | SP-4, `Tx` außerhalb aller Hash-Wege, `test_11_lang_determinism`, Fullrun englisch = deutsch | Fullrun-Zeilen unterscheiden sich |
| R5 | Paket und Engine driften auseinander | mittel / mittel | gepinnter Commit, `pack_schema`, Standards im Datenvertrag, „[Pakete]“ im CHANGELOG, private CI | private CI rot nach Commit-Anhebung |
| R6 | Fremde Inhalte gelangen ins öffentliche Repository | niedrig / sehr hoch | vier Schichten (Kap. 3.12) | Schicht-1-Fund, Fingerabdruck-Treffer |
| R7 | Merge-Konflikte in PO-Dateien | mittel / niedrig | Domänen-Dateien, sortierte Ausgabe, `merge` nach dem Zusammenführen, L3 je Tabellengruppe | Konflikte je Merge |
| R8 | Layout bricht (lange Wörter, Telefon) | mittel / mittel | Container-Layouts, Ellipsen, Längenlimits im Test, zwei Capture-Formate | Überläufe in Captures |
| R9 | PO-Laden kostet Startzeit auf dem Telefon | niedrig / mittel | eigener Parser, Messung, Vorkompilieren beim Export als Rückfall | Start + > 50 ms |
| R10 | L2 dauert länger als geschätzt (≈ 1 300 Literale) | hoch / mittel | L2a als Probe messen, bereichsweise Branches, Puffer | L2a > 4 PT |
| R11 | Parallele Pakete fügen neue deutsche Texte ohne `Tx` hinzu | hoch / niedrig | Lint, `PENDING` schrumpft nur, Regel in 02_TECH §13.1 | wachsende Lint-Zählung |
| R12 | Mechanik-Bausteine verschieben bestehende Kämpfe | mittel / hoch | „nur geschrieben, wenn gesetzt“, Ereignisse am Ende, CR-39 einzeln, Goldens als Gate | Golden rot ohne neue Daten |
| R13 | Die Rechteinhaberseite erwartet mehr als Daten (eigene Grafik, Musik, Mechanik) | mittel / mittel | Baukasten (Kap. 4), Paket-Schema 2 für Dateien (F-6), Kap. 3.10 offen im Pitch-Material | Wünsche außerhalb von Kap. 3.10 |
| R14 | Ein Lizenzblock wird benutzt, um Regeln zu umgehen | niedrig / mittel | Lizenzblöcke nie im öffentlichen Repository (Schicht 1); Ausnahme nur für die IP-Abstandslisten, nie für Ton | Review-Fund |

### 6.2 Offene Fragen mit Empfehlung

| Nr. | Frage | Empfehlung |
|---|---|---|
| F-1 | US- oder britisches Englisch? | **US** (größter Markt, Store-Standard); britische Leser:innen verstehen es, und britische Doppeldeutigkeiten wie *pants* meidet das Glossar ohnehin. |
| F-2 | Die deutschen Umbenennungen aus 04 E2 („Requisitenkiste“, „NOVA MEDIENGRUPPE“) jetzt mitziehen? | **Ja, vor L3** — sonst übersetzt L3 Namen, die sich danach ändern; es sind reine Textänderungen (04 §2.3). Entscheidung bei Nutzer:in bzw. Orchestrator (04 E2). |
| F-3 | Besetzungsnamen anpassen? | **Nein.** Sie stehen gehasht im Staffelblock. Wirkt ein Name englisch unglücklich, hilft nur ein Anzeige-Override (PO, Kontext `cast:name`) ohne Wirkung auf den Zustand. |
| F-4 | Sprachwechsel auch im Pausemenü? | **Nein**, nur im Titelmenü (Kap. 1.9). Neu prüfen, wenn alle Bildschirme Texte bei Bedarf neu aufbauen. |
| F-5 | Deutscher Name der Unterhosen-Liga? | **Nicht Sache dieses Dokuments:** Pitch-Builds sind englisch („Travel-Light League“). Der deutsche Name bleibt beim Distanz-Review (06 §0.3 Nr. 6); dessen Ersatz „Leichtgepäck-Liga“ entspricht der englischen Wahl. |
| F-6 | Binärdateien (Texturen, glTF, Audio) in Paketen? | **Später** als Paket-Schema 2 mit Lizenz je Datei, Größenbudget und Import im privaten Build. Für einen Pitch reichen Baukasten-Figuren mit Farben und Props. |
| F-7 | Ton-Ausnahmen für Partner-Inhalte (derberer Humor der Vorlage)? | **Keine pauschale Ausnahme.** Geprüfte Einzelausnahmen als Liste im Paket (`tone_exceptions` mit Begründung), freigegeben im Review; Politik und Sexuelles bleiben gesperrt. |
| F-8 | Wann M.O.D. live auf Englisch (L5)? | **Nach L4** und erst mit freigegebenen englischen Filterlisten; bis dahin ist live auf Englisch aus. |
| F-9 | Extraktor in GDScript oder mit Python-Werkzeugen? | **GDScript** — läuft headless mit Godot, nutzt `GameData` und den Literal-Parser aus `test_09_terms`; `msgmerge`/`msgfmt` (GNU gettext) nur für Merge und Prüfung. |
| F-10 | Übersetzungsablauf? | **KI-Entwurf mit Glossar und Stimmregeln, dann externes Lektorat** (≈ 22 000 Wörter Review) **[Kosten zu prüfen]**; eine Übersetzungsplattform erst mit einer dritten Sprache. |
| F-11 | Pakete aus dem Netz, Nutzer-Mods? | **Nein** (O-4). Ein Mod-Weg wäre eine eigene Entscheidung mit eigenen Sicherheitsfragen. |
| F-12 | Store-Texte, Presse-Kit, Trailer-Untertitel? | Außerhalb dieses Dokuments; **dieselbe Glossar-Pflicht** (Kap. 2) gilt. |
| F-13 | Spieltitel übersetzen? | **Nein** — „PRIME TIME DUNGEON“ ist schon englisch; die Markenrecherche aus 04 §2.5 bleibt. |
| F-14 | „Packstation“ als Anzeigename des Orts-Gegners? | **Nein**, Markenwort eines echten Unternehmens: „Abholstation“ oder „Paketschrank“ (Kap. 4.7) **[Markenprüfung]**. |
| F-15 | Wo stehen Lizenz-Credits? | In den Credits (`scenes/title/credits.gd`) als Block aus `pack.json → licence.credits`; auf der Bootkarte nur, wenn der Vertrag es verlangt. Den Text liefert die Partnerseite. |
| F-16 | Zahlen in Datenzeilen mit Pluralformen? | **Zahlneutral formulieren** (Kap. 1.5); ein Pluralfeld in den Daten erst, wenn eine Sprache es zwingend braucht. |
| F-17 | `events.json` mit `name_key`/`label_key`? | **Auf deutsche Textfelder umstellen** wie alle anderen Tabellen (02_TECH §4.1); bis dahin sind die Rückfalltexte in `event_info.gd` `NAME_KEYS` die msgids. |
| F-18 | UI-Farben (`Palette`, `UiTheme`) je Paket? | **Nicht in v1** (Konstanten). Verlangt eine Partnerseite es, kommt `ui_palette` in `art.json` mit einem eigenen Vertrags-Durchgang. |
| F-19 | 04 und 06 und der Sprachtest aus 09 nennen das Werk, von dem PTD Abstand hält. Neutralisieren? | **Lassen.** Die Nennungen sind beschreibend, kein fremder Inhalt, und begründen den Abstand; die Baseline der Firewall erfasst sie. Vor einem öffentlichen Auftritt prüft das Anwalts-Memo (04 §2.3) die Formulierungen. |
| F-20 | Was gilt, wenn **dieses Repository privat** wird (Wunsch der Nutzer:in, 2026-10-13)? | **Dann darf ein lizenziertes Paket hier liegen** (`game/packs/<id>/`, eigener Branch), und die Firewall schützt die **Builds** statt des Repositorys: Grund-Exporte schließen `packs/*` aus (PB), `ip_words` prüft weiter alle Grundinhalte (PTD bleibt veröffentlichbar), Schicht 1 erlaubt Ordner aus einer Liste `PRIVATE_PACKS` nur, solange die CI `github.event.repository.private` meldet (wird das Repository wieder öffentlich, schlägt sie fehl), Schicht 3 (HMAC) entfällt, solange es privat ist. Das CI-Minutenbudget privater Repositorys verlangt dann sparsamere Läufe (PB). |
