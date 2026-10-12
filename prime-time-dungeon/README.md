# PRIME TIME DUNGEON

3D-Dungeon-Crawler mit Reality-Show-Mechanik, gebaut in **Godot 4.7** (GDScript, statisch typisiert).
Dieses Verzeichnis enthält den **Vertical Slice von Etage 1**: Spiel (`game/`), Design- und Technik-Dokumente (`docs/`) und
Prüfwerkzeuge (`tools/`).

![Echtzeitkampf gegen die Rattenkönigin von Gleis 9](docs/screenshots/57_echtzeitkampf_koenigin_zug.png)

---

## 1. Was es ist

- **Prämisse:** Das Medienkonglomerat NOVA SYNDIKAT hat die Erdoberfläche „zurückgebaut“ und macht aus dem Dungeon darunter
  die Reality-Show **DUNGEON PRIME TIME**. Kai, Tierpfleger:in, und **Graf Mopsula**, ein sprechender Mops, der sich für
  einen Grafen und Gelehrten hält, kämpfen sich Etage für Etage nach unten. Jede Etage bricht nach einem Countdown
  zusammen. Moderiert wird alles von der sarkastischen System-KI **M.O.D.**
- **Look:** stilisiertes Low-Poly mit Toon-Shading (Option B). Figuren, Räume und Effekte entstehen prozedural aus Primitiven
  und Shadern, ohne externe Assets. glTF-Modelle aus Blender sollen die Platzhalter später 1:1 ersetzen (03_ART Kap. 10).
- **Spiel:** Echtzeit-Erkundung in 3D mit sichtbaren Gegnern (wie FF12) und **Echtzeitkämpfe direkt in der Welt**
  („WoW-light“, 07): Ziel wählen, der Auto-Angriff läuft, dazu vier Fähigkeiten, **SHOW**, Trank und Partner-Spezial; rote
  Bodenflächen kündigen Treffer an, denen man ausweicht. Der frühere Rundenkampf (CTB) lebt als Kern des optionalen
  Minispiels „Stempelduell“ weiter (`docs/10_MINISPIEL_STEMPELDUELL.md`).
- **Die Show ist das UI:** Zuschauer, Follower, Hype, Sponsor-Geschenke mitten im Kampf, Achievements, Lootboxen,
  M.O.D.-Kommentare und Graf-Mopsula-Szenen im Safe Room.
- **SHOWRUN-Kern (Live-Modus, Stufe S0):** Offline-Event-Läufe mit festem Seed, Quest und lokaler Bestenliste. Jeder Lauf
  wird als Befehls-Log aufgezeichnet und lässt sich deterministisch nachspielen (Run-Log, Replay, `StateHash`).
  Zuschauer-Geschenke kommen nur in **Sponsor-Fenstern** an (05_LIVE_MODUS Kap. 6.13).

**IP-Hinweis:** PRIME TIME DUNGEON ist eine eigenständige IP und nur vom Genre von *Dungeon Crawler Carl* (Matt Dinniman)
**inspiriert**. Namen, Figuren, Orte und Texte aus DCC werden nicht verwendet (00_BRIEF, 04 Kap. 2).

**Verbindliche Entscheidungen** (00_BRIEF Kap. 5):

- **Lootboxen werden nur im Spiel verdient und nie für Echtgeld verkauft.** Spieler:innen kaufen sich nichts Zufälliges.
- **Echtgeld von Zuschauer:innen fließt ausschließlich an das Spiel bzw. den Betreiber**, nie an Spieler:innen und nie an
  Streamer:innen.
- Zuschauer:innen können nur begrenzt oft und nur zu bestimmten Zeiten helfen (Sponsor-Fenster).
- Im Vertical Slice gibt es weder Netzwerk noch Echtgeld. Geschenke stammen aus dem Spiel selbst oder aus dem
  QA-Werkzeug (Debug-Build).

## 2. Status

*Stand: 2026-10-12, nach ST1-G (Schläfer und Ausloggen). Die genaue Version ergibt sich aus `git log -1` in diesem
Verzeichnis.*

**Läuft:**

- Etage 1 ist von Titel bis Abspann spielbar: Intro, Tutorial-Kampf und 14 weitere Gegnergruppen, Streuner, 5 Events,
  16 Truhen, 3 Safe Rooms (Heilen, Speichern, Automat, Lootboxen, Mopsula-Szenen), der Quartier-Boss **Der Hausmeister**
  und der Etagenboss **Die Rattenkönigin von Gleis 9**, danach Etagen-Bilanz, Autosave und Abspann.
- **Figurenwahl** (06 Paket A): Zu Beginn wählt man, wen man steuert — Kai (Feldschlag) oder Graf Mopsula (Bellen: verdutzt
  Gegnergruppen, die man dann von jeder Seite zuerst erwischt); die andere Figur folgt und kämpft als KI-Partner mit
  (Taktik und Partner-Spezial). „Figur wechseln“ im Safe Room, auf Etage 1 eine Kulissenwand und drei Regie-Notizen als
  Geheimnisse.
- **Talent-Show** (06 Paket B): Ab Stufe 3 bringt jede ungerade Stufe jeder Figur eine Talentwahl (1 aus 2, gewählt im
  Safe Room über den goldenen Knopf „TALENT-SHOW“). Feld-Talente wirken für die Figur, die gerade führt. Spezies und
  Klasse wählt man ab Etage 3 im **Recall** (nächster Punkt; `species.json`, `classes.json`, Command `casting`).
- **Recall** (06 §3.5; nur in Staffeln, die heute nur Debug-Builds starten, §6 `--season`): Im ersten Safe Room von
  Etage 3 öffnet die Show-Runde, in der M.O.D. Jury ist. Erst wählt die gesteuerte Figur, dann die andere eine
  **Spezies** („Wer bist du?“: Original-Verpackung oder eine von drei bzw. vier eigenen) und eine **Klasse** („Was kannst
  du?“: eine von vier). Jede Karte sagt ihre Wirkung in einem Satz; daneben die Werte vorher → nachher, die ersten
  Fähigkeiten der Klassenleiste und die Plaketten „EMPFOHLEN“ und „PASST ZU IHREM VORLEBEN“. Nach „Bestätigen“ liegt die
  Signatur der Klasse auf Slot 1, M.O.D. urteilt über das Paar, und die erste Klassenwahl schaltet „Ohne Netz“ frei.
  Umentscheiden geht, bis man den Safe Room verlässt; danach bleibt die Spezies, die Klasse wechselt man einmal je Etage
  im ersten Safe Room („Umschulung“). „Später“ wartet in jedem Safe Room der Etage (Knopf **RECALL**).
- **Casting** (08 K1): Nach der Figurenwahl drei Bildschirme — Name und Wortform, Vorleben / Hobby / Eigenschaften,
  Kandidatenkarte — oder „Rest automatisch“ (Esc / Start: die Kanon-Kandidat:in Kai in zwei Eingaben). Die Karte prägt
  M.O.D.s Zeilen (Intro-Bauchbinde, Rival:in, Sponsor, Running Gag, Grüße von zu Hause; nie im Kampf) und ab Etage 2 die
  Marotten-Gewichtung; Kampfwerte ändert sie nicht. Der Name steht nur in der Persona-Datei je Slot (`user://persona/`),
  nie im Spielstand, Replay oder in einer Bestenliste; „Kandidat:in löschen“ in den Optionen.
- **Echtzeitkampf** (07, Stand R5b-2b): Die Kampagne kämpft nur noch in Echtzeit „WoW-light“ direkt in der Welt; die
  Show-Zahlen liegen in den Bändern des GDD (07 E32: Hype, Sponsor-Geschenke, Follower, Zuschauer). Autoplay-Smoke und
  Full-Run-Bot prüfen ihn in CI. Die Daten tragen die Echtzeit-Werte (HP × 4); Spielstände von vor der Umstellung laden ins
  neue Format (Version 2) und spielen in Echtzeit weiter. **Der Rundenkampf (CTB) lebt im Minispiel „Stempelduell“ weiter:**
  Seine Engine liegt eingefroren in `game/core/stempel/ctb/` (Golden- und Grenztest); das Minispiel ist als Vorschau unter
  Titel → Extras spielbar (Abschnitt „Stempelduell“ unten, `docs/10_MINISPIEL_STEMPELDUELL.md`).
- **Kampf eröffnen** (07 E34–E37, Stand Pull): Außerhalb des Kampfes wählt man den Anführer einer Gruppe als Ziel und
  eröffnet mit einer Fähigkeit (Tastatur, Gamepad und Touch); von hinten, gegen eine ahnungslose oder angebellte Gruppe ist
  das ein Erstschlag — als Graf Mopsula reicht „bellen, dann 1“.
- **Staffeln: Stufen, Fähigkeiten und Talente wie in WoW** (09 Kap. 8, ST1-D; nur in Staffeln, die heute nur Debug-Builds
  starten, §6 `--season`): Stufen bis 50 nach fester Tabelle, je Etage ein Band mit Deckel (EXP darüber werden als
  „Überstunden“ zu Credits), Aufholjagd (EXP × 2/× 3 unter dem Band) und Regie-Crashkurs mit Aufholpaket bei einer
  Rettung; das Fähigkeitenbuch (Pause → Fähigkeiten) mit Klassenleisten ab dem Recall, Rängen II–IV und der
  „Klassen-Vorschau“ davor; der Talentbaum: je Reihe eines von drei Talenten (Stufe 3, 5, 7, 9, dann alle fünf Stufen bis
  50), vorgestellt von der Talent-Show, umgewählt kostenlos im Safe Room (Pause → Party → „Talentbaum“). Die Klassenleisten
  sind Platzhalter. In der Kampagne und in Event-Läufen bleibt die Talent-Show „1 aus 2“ (bis zum Umstieg, 09 V-20).
- Die Kampagne endet nach Etage 1: Wer abgestiegen ist, landet nach „Fortsetzen“ im Abspann. Die Etagen 2–6 gehören den
  **Staffeln** (09, Stand ST1-C1; nur Debug-Builds, `--season`, Abschnitt 6): die Passage Ewiger Rabatt, Der Fundus und
  Das Paketzentrum (Hallen 4–6) — prozedural in Vierteln (Generator v2) mit Schlüsseltor vor der Treppe, Revier- und
  Etagenbossen, einem Safe Room je Viertel und fünf Programmtüren, die das Tagesprogramm öffnet; die Gegner stehen auf
  den Stufen-Bändern der Etagen (7–10 auf Etage 2 bis 19–22 auf Etage 6) und geben die EP-Anteile der Staffel-Stufen.
  Eine Basis-Staffel läuft von Etage 1 bis zum Finale auf Etage 6.
- **Staffeln: Schläfer und Ausloggen** (09 Kap. 5, ST1-G; Debug-Builds, `--season`): Ausloggen geht überall außerhalb
  eines Kampfes (Pause → „Ausloggen“, im Safe Room „Ausloggen“). Der Dialog sagt, was passiert: im Safe Room sicher und
  „Ausgeruht“ (5 % einer Stufe je Stunde, bis 150 %: Kampf-EP zählen doppelt), im Gang bis zu drei Begegnungen je
  Abwesenheit — Streifen, manchmal aufgebracht, und KI-Kandidat:innen, die Wache halten, eine Streife vorbeiziehen,
  einen Zettel oder eine Probe hinlegen —, gekämpft auf Autopilot mit der gewählten Taktik und dem Notfall-Rückzug;
  Ohne Netz kann man dabei sterben (Todesraten je Nacht: ruhig unter 0,5 %, unruhig 1–2 %, gefährlich 3–6 %). Beim
  Laden folgt „Während Sie schliefen …“ (Titel und höchstens sechs Zeilen, ein Einsturz zuerst), auf Wunsch „Tag für
  Tag“; über 7 Tage erst eine Rückfrage. Am Stück steht die Uhr: Ausloggen ist dort immer sicher. Einsturz-Warnungen
  nur auf Wunsch (Desktop: im Fenstertitel, solange das Spiel offen ist).
- 3 Speicherslots (JSON in `user://saves/`), Einstellungen, Pausemenü, Touch-Steuerung.
- **M.O.D.-Marotten & Unterhosen-Liga** (06 Kap. 4): M.O.D. verrät je Etage, was sie heute mag (Show-Wetten mit Herzen,
  Fanpost-Paket bei drei Treffern); wer ohne Rüstung & ohne Accessoire kämpft, spielt in der Liga und bekommt mehr Hype und
  Follower. Show-Chip im Overlay, Pausemenü-Reiter „Show“, Achievement-Kette „Ohne alles“.
- SHOWRUN S0: 2 Offline-Events (`evt_offline_gleis9`, `evt_offline_pacifist`), Event-Lobby, Ergebnis-Screen, lokale Bestenliste,
  Replay-Prüfung.
- Qualitätssicherung: rund 1 800 automatische Tests (darunter Golden- und Grenztest der Stempelduell-Engine),
  Autoplay-Smoke-Test im Echtzeitkampf (`AUTOPLAY: OK`), Full-Run-Bot, der Etage 1 mit drei Strategien und als Graf Mopsula
  durchspielt, Balance-Harness des Echtzeitkampfs, Performance-Probe (`PERF: OK`) und der CI-Workflow `ptd-check`.

**Bekannte Lücken:**

- keine komponierte Musik und keine echten Sounds (nur prozedural erzeugte Platzhalter-Loops und -SFX), keine glTF-Modelle
- Ausrüstung ist an den Figuren nicht sichtbar (Antrag 03_ART A8)
- kein Netzwerk, kein Server, kein Echtgeld (SHOWRUN S1 und später)
- Plattform-Matrix der Stufe S0 noch nicht gemessen (05 Kap. 2), Budgets noch nicht auf einem echten Android-Gerät geprüft
- noch keine externen Playtests

## 3. Öffnen und starten

1. **Godot 4.7.x** (Standard-Build, nicht .NET) installieren. Getestet ist **4.7.2-stable**.
2. Im Projektmanager **Importieren** wählen und `prime-time-dungeon/game/project.godot` öffnen. Der erste Import dauert
   einen Moment, weil Godot die Shader und Ressourcen importiert.
3. **F5** startet die Hauptszene `res://scenes/boot/boot.tscn`. Nach der Karte „NOVA SYNDIKAT präsentiert“ kommt der Titel.

Renderer ist **Mobile** (Vulkan). Ohne Vulkan fällt Godot automatisch auf **Compatibility** (OpenGL 3) zurück. Alle Shader
funktionieren in beiden Renderern (02_TECH §2, §12.2).

Von der Kommandozeile aus dem Repo-Wurzelverzeichnis:

```bash
godot --path prime-time-dungeon/game                         # Spiel starten
godot --path prime-time-dungeon/game -- --goto=explore --seed=7   # mit Entwickler-Argumenten (Abschnitt 6)
```

Alles nach `--` sind Argumente für das Spiel (Abschnitt 6). Im Editor trägt man sie unter
**Projekt → Projekteinstellungen → Editor → Run → Main Run Args** ein (Einstellung `editor/run/main_run_args`;
falls sie fehlt, oben „Erweiterte Einstellungen“ einschalten).

## 4. Spielbare Builds

Fertige Builds baut die CI: Für jeden gepushten Tag `v*` (z. B. `v0.3.0`) oder `[build]`-Commit (siehe „Neuen Build auslösen“)
läuft im Workflow `ptd-check` nach dem Prüf-Job der Job `export` und legt vier Artefakte ab. Godot braucht man dafür nicht. Mit
einem bezahlten Apple-Developer-Account kommen zwei Jobs dazu (Abschnitt „Mit Apple-Entwicklerkonto“ unten): eine notarisierte
Mac-App und ein iPhone/iPad-Build in TestFlight.
Was in welchem Build neu ist, steht in [`CHANGELOG.md`](CHANGELOG.md).

| Artefakt | Inhalt | läuft auf |
|---|---|---|
| `PrimeTimeDungeon-<tag>-macOS` | `PrimeTimeDungeon.zip` mit `Prime Time Dungeon.app` (Universal-Binary, ad-hoc signiert) | macOS 13+ (Apple Silicon), macOS 11+ (Intel) |
| `PrimeTimeDungeon-<tag>-macOS-notarized` | wie oben, aber mit Developer ID signiert und notarisiert (nur mit Apple-Entwicklerkonto) | wie oben, startet ohne Gatekeeper-Warnung |
| `PrimeTimeDungeon-<tag>-iOS-Xcode` | Xcode-Projekt `PrimeTimeDungeon.xcodeproj` mit Engine und Spieldaten, noch unsigniert | iPhone XS/XR und neuer, iPad mit A12-Chip und neuer, iOS/iPadOS 15+ |
| `PrimeTimeDungeon-<tag>-iOS-TestFlight` | `PrimeTimeDungeon.ipa`, für den App Store signiert, derselbe Build wie in TestFlight (nur mit Apple-Entwicklerkonto) | wie oben, Installation nur über TestFlight |
| `PrimeTimeDungeon-<tag>-Windows` | `PrimeTimeDungeon.exe` | Windows 10/11, 64 Bit |
| `PrimeTimeDungeon-<tag>-Linux` | `PrimeTimeDungeon.x86_64` | Linux x86_64 |

**Herunterladen:** auf GitHub im Repository **Actions** → Workflow **ptd-check** → den Lauf des Tags öffnen. Die Zusammenfassung
des Laufs verlinkt die Artefakte, sonst stehen sie unten unter **Artifacts**. Herunterladen geht nur angemeldet; jedes Artefakt
kommt als ZIP. GitHub löscht Artefakte nach der Aufbewahrungsfrist des Repos (Standard 90 Tage). Geprüft ist der Export unter
Linux (Bundle-Aufbau, beide Architekturen, Signatur, vollständiges Xcode-Projekt); auf echter Apple-Hardware lief der Build noch
nicht.

**Mac**

1. `PrimeTimeDungeon-<tag>-macOS.zip` entpacken. Darin liegt `PrimeTimeDungeon.zip`: Godot packt die App selbst, damit die
   Programmdatei ausführbar bleibt. Auch diese Datei per Doppelklick entpacken und `Prime Time Dungeon.app` in **Programme** ziehen.
2. Erster Start: Die App ist nur ad-hoc signiert (keine Developer-ID, nicht notarisiert), deshalb blockiert Gatekeeper den ersten
   Start. Einmal freigeben, danach startet sie normal per Doppelklick (die notarisierte App aus
   `PrimeTimeDungeon-<tag>-macOS-notarized` braucht keine Freigabe):
   - **macOS 14 und älter:** Rechtsklick (Ctrl-Klick) auf die App → **Öffnen** → im Dialog noch einmal **Öffnen**.
   - **macOS 15 und neuer:** App per Doppelklick starten, die Meldung mit **Fertig** schließen, dann **Systemeinstellungen →
     Datenschutz & Sicherheit** → unten bei „Sicherheit“ **Dennoch öffnen** → mit dem Passwort bestätigen.
   - **Terminal (jede Version):** `xattr -dr com.apple.quarantine "/Applications/Prime Time Dungeon.app"` (Pfad anpassen, falls
     die App woanders liegt) entfernt die Download-Markierung. Das hilft auch, wenn macOS die App als „beschädigt“ meldet.
3. Gespielt wird mit Tastatur und Maus oder mit einem Gamepad (Abschnitt 5), Vollbild mit F11. Spielstände liegen in
   `~/Library/Application Support/PrimeTimeDungeon/`.

**iPhone und iPad (über Xcode, eine kostenlose Apple-ID reicht)**

Nötig sind ein Mac mit **Xcode 26.1 oder neuer** (kostenlos im App Store; die iOS-Engine von Godot 4.7.2 ist mit dem
iOS-26.1-SDK gebaut), eine Apple-ID und ein Kabel zum Gerät.

1. Apple-ID in Xcode eintragen: **Xcode → Settings → Accounts → +**. Dabei entsteht das „Personal Team“.
2. iPhone oder iPad per Kabel anschließen, entsperren und „Diesem Computer vertrauen“ bestätigen. Einmalig den
   **Entwicklermodus** einschalten: **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** → an → Neustart → bestätigen.
   Der Schalter erscheint erst, nachdem das Gerät einmal mit dem Mac und Xcode verbunden war.
3. `PrimeTimeDungeon-<tag>-iOS-Xcode.zip` entpacken und `PrimeTimeDungeon.xcodeproj` öffnen.
4. Links das Projekt **PrimeTimeDungeon** wählen → Target **PrimeTimeDungeon** → Reiter **Signing & Capabilities**:
   **Automatically manage signing** bleibt an, bei **Team** das eigene „… (Personal Team)“ wählen. Der Export trägt dort nur den
   Platzhalter `XXXXXXXXXX` ein, weil Godot eine Team-ID verlangt. Meldet Xcode, die Bundle-ID `org.primetimedungeon.game` sei
   nicht verfügbar, im selben Reiter eine eigene eintragen, z. B. `org.primetimedungeon.game.deinname`.
5. Oben in Xcode das Gerät als Ziel wählen und **Run** (▶ bzw. ⌘R). Der erste Build dauert ein paar Minuten, weil die Engine
   groß ist. Danach startet das Spiel auf dem Gerät.
6. Verweigert iOS den Start („nicht vertrauenswürdiger Entwickler“): **Einstellungen → Allgemein → VPN & Geräteverwaltung →**
   den Eintrag „Apple Development: …“ mit der eigenen Apple-ID → **Vertrauen**, dann das Spiel erneut starten.

Mit einer kostenlosen Apple-ID ist die Signatur **7 Tage** gültig. Danach startet die App nicht mehr: Gerät wieder anschließen
und in Xcode erneut **Run**, die Spielstände bleiben erhalten. Gespielt wird im Querformat mit **Touch**: schwebender Stick links,
runder Aktions-Button rechts, Pause oben rechts (Abschnitt 5). Ein Bluetooth-Gamepad sollte ebenfalls gehen, getestet ist das
nicht.

**Windows und Linux:** Unter Windows `PrimeTimeDungeon.exe` starten. SmartScreen warnt bei unsignierten Programmen: **Weitere
Informationen → Trotzdem ausführen**. Unter Linux `chmod +x PrimeTimeDungeon.x86_64 && ./PrimeTimeDungeon.x86_64`, denn
GitHub-Artefakte verlieren das Ausführrecht.

**Neuen Build auslösen:** Version in `game/project.godot` (`application/config/version`) und in den Presets anheben
(`test_perf_platform.gd` prüft, dass die angezeigten Versionen übereinstimmen), committen und den Tag pushen, z. B.
`git tag v0.3.0 && git push origin v0.3.0`. Zwischenstände ohne Tag: Beginnt die Nachricht des letzten Commits eines
Pushs mit `[build]`, baut die CI dieselben Artefakte (inklusive der Apple-Jobs) unter dem Namen
`PrimeTimeDungeon-build-<Laufnummer>-…`; das braucht etwa, wer nur auf einen Branch pushen darf. Lokal geht derselbe Export mit Godot 4.7.2 und installierten Exportvorlagen
(Editor: **Editor → Exportvorlagen verwalten**). Das iOS-Xcode-Projekt lässt sich auch unter Linux erzeugen:

```bash
cd prime-time-dungeon/game && mkdir -p ../build/macos ../build/ios
godot --headless --path . --import
godot --headless --path . --export-release "macOS" ../build/macos/PrimeTimeDungeon.zip
godot --headless --path . --export-release "iOS" ../build/ios/PrimeTimeDungeon.xcodeproj
```

### Mit Apple-Entwicklerkonto

Mit einem Account im Apple Developer Program (99 USD im Jahr) signiert die CI selbst: Job `apple-macos` signiert die Mac-App mit
der Developer ID und lässt sie von Apple notarisieren, Job `apple-ios-testflight` baut das Spiel für iPhone/iPad und lädt es nach
**TestFlight** hoch (ohne Kabel, ohne 7-Tage-Grenze; ein TestFlight-Build läuft 90 Tage). Zertifikate, Profil und API-Schlüssel
gibt es nur als GitHub-Secrets, nie im Repository. Die eingecheckten Presets behalten ihre Platzhalter; Team-ID, Bundle-ID und
Build-Nummer setzt die CI erst beim Export in eine Kopie ein (02_TECH §12.4).

Einmal anlegen, auf [developer.apple.com/account](https://developer.apple.com/account) bzw.
[appstoreconnect.apple.com](https://appstoreconnect.apple.com):

1. **Team-ID** ablesen: Account → Mitgliedschaftsdetails (10 Zeichen, z. B. `AB12CD34EF`).
2. **Bundle-ID** registrieren: Certificates, Identifiers & Profiles → Identifiers → **+** → App IDs → App, „Explicit“, z. B.
   `de.deinname.primetimedungeon`. Capabilities braucht das Spiel keine.
3. **App anlegen** in App Store Connect: Apps → **+** → Neue App, Plattform iOS, dieselbe Bundle-ID, SKU beliebig.
4. **Zwei Zertifikate** unter Certificates → **+**: „Apple Distribution“ und „Developer ID Application“ (Sub-CA „G2“; anlegen
   darf es nur der Account Holder). Die verlangte Zertifikatsanfrage erzeugt die Schlüsselbundverwaltung: *Zertifikatsassistent →
   Zertifikat einer Zertifizierungsinstanz anfordern*, „auf der Festplatte sichern“. Das geladene `.cer` per Doppelklick
   importieren, dann unter *Meine Zertifikate* mit Rechtsklick **exportieren** als `.p12` mit Passwort (Zertifikat samt privatem
   Schlüssel).
5. **Provisioning-Profil**: Profiles → **+** → Distribution → **App Store Connect**, App-ID aus 2, Zertifikat „Apple
   Distribution“ aus 4, `.mobileprovision` laden.
6. **API-Schlüssel**: App Store Connect → Benutzer und Zugriff → Integrationen → App Store Connect API → Team-Schlüssel → **+**,
   Zugriff **App-Manager**. `AuthKey_<Key-ID>.p8` lässt sich nur einmal laden; die Key-ID steht in der Liste, die Issuer-ID darüber.
7. Der Account Holder muss die aktuellen Vereinbarungen akzeptiert haben (App Store Connect → Geschäftlich), sonst lehnt Apple
   Uploads ab.

Dann auf GitHub im Repository unter **Settings → Secrets and variables → Actions** eintragen. Dateien als Base64, auf dem Mac mit
`base64 -i <Datei> | pbcopy` in die Zwischenablage:

| Name | Reiter | Inhalt |
|---|---|---|
| `APPLE_TEAM_ID` | Variables | Team-ID aus 1 |
| `APPLE_BUNDLE_ID` | Variables | Bundle-ID aus 2 (gilt für iOS und macOS) |
| `IOS_DIST_P12_BASE64`, `IOS_DIST_P12_PASSWORD` | Secrets | `.p12` „Apple Distribution“ aus 4 (Base64) und ihr Passwort |
| `IOS_PROFILE_BASE64` | Secrets | `.mobileprovision` aus 5 (Base64) |
| `MAC_DEVID_P12_BASE64`, `MAC_DEVID_P12_PASSWORD` | Secrets | `.p12` „Developer ID Application“ aus 4 (Base64) und ihr Passwort |
| `ASC_KEY_ID`, `ASC_ISSUER_ID` | Secrets | Key-ID und Issuer-ID aus 6 |
| `ASC_KEY_P8_BASE64` | Secrets | `AuthKey_<Key-ID>.p8` aus 6 (Base64) |

**Auslösen** wie jeden Build mit einem Tag oder einem `[build]`-Commit (oben, „Neuen Build auslösen“). Nach `check` laufen beide
Jobs neben `export`. Fehlt
etwas, überspringt die CI den Job und nennt in der Zusammenfassung des Laufs die fehlenden Namen (nie Werte); ohne die Mac-Secrets
läuft der iOS-Job trotzdem und umgekehrt. Die Build-Nummer ist `<Laufnummer>.<Versuch>` (TestFlight zeigt z. B. `0.3.0 (57.1)`),
jeder Upload hat damit eine höhere Nummer, ein „Re-run“ ergibt `57.2`.

**Wo die Builds landen:** Die Mac-App ist das Artefakt `PrimeTimeDungeon-<tag>-macOS-notarized` (bei einem `[build]`-Commit
`PrimeTimeDungeon-build-<Laufnummer>-macOS-notarized`; zweimal entpacken, nach
**Programme** ziehen, Doppelklick). Der iOS-Build erscheint nach Apples Verarbeitung (meist 5 bis 30 Minuten) in App Store Connect
→ Apps → Prime Time Dungeon → **TestFlight**. Dort interne Tester:innen (Mitglieder des App-Store-Connect-Teams) einer internen
Gruppe hinzufügen; sie bekommen eine Einladung und installieren das Spiel mit der App **TestFlight**. Externe Tester:innen
brauchen vorher eine Beta-Prüfung durch Apple. Die IPA im Artefakt `…-iOS-TestFlight` lässt sich nicht direkt installieren, aber
mit der Mac-App Transporter von Hand hochladen. Ohne CI geht der Upload auch in Xcode: bezahltes Team wählen, **Product →
Archive**, im Organizer **Distribute App → App Store Connect** (jeder Upload braucht eine höhere Build-Nummer).

**Typische Fehler** (stehen rot im jeweiligen Schritt des Jobs):

| Meldung | Abhilfe |
|---|---|
| Zusammenfassung „übersprungen, es fehlen …“ | genannte Secrets/Variablen anlegen, Namen exakt wie oben |
| „Import der .p12 gescheitert“ | Passwort falsch oder `.p12` ohne privaten Schlüssel: in der Schlüsselbundverwaltung unter *Meine Zertifikate* exportieren; eine mit OpenSSL 3 erzeugte `.p12` braucht `-legacy` |
| „keine gültige … Identität“ | falscher Zertifikatstyp (z. B. „Apple Development“ statt „Apple Distribution“) oder Zertifikat eines anderen Teams als `APPLE_TEAM_ID` |
| „… Development-, Ad-hoc- oder Enterprise-Profil“, „Profil gilt für …“, „enthält das Distributionszertifikat … nicht“ | Profil vom Typ „App Store Connect“ für genau diese Bundle-ID und dieses Zertifikat neu erzeugen (auch nach jeder Zertifikatserneuerung) |
| „Failed to generate JWT token … (259)“, „NOT_AUTHORIZED“, 401 | `ASC_KEY_P8_BASE64` muss die geladene `.p8` sein, Key-ID und Issuer-ID nicht vertauscht, Schlüssel nicht widerrufen, Rolle mindestens App-Manager |
| „No suitable application records were found“ | App fehlt in App Store Connect oder hat eine andere Bundle-ID als `APPLE_BUNDLE_ID` |
| „Redundant Binary Upload“, „bundle version must be higher“ | Build-Nummer schon vergeben (etwa durch einen Upload von Hand): neuen Tag pushen |
| „required agreement is missing or has expired“ | Vereinbarungen in App Store Connect akzeptieren (Account Holder) |
| Notarisierung „Invalid“ | Apples Log steht direkt darunter im Schritt (Liste „issues“); „Team is not yet configured for notarization“ betrifft neue Konten, dann den Apple-Support fragen |
| E-Mail von Apple „ITMS-…“ nach dem Upload | der Build ist in TestFlight als ungültig markiert: Ursache beheben, neuen Tag pushen |

Zertifikate und Profil laufen ab (Apple Distribution und Profil nach einem Jahr, Developer ID nach fünf Jahren): erneuern und als
Secrets neu eintragen. Bereits notarisierte Mac-Apps bleiben gültig, ihre Signatur trägt einen Zeitstempel. Geprüft sind die
beiden Jobs gegen Apples aktuelle Dokumentation und unter Linux mit Attrappen der Apple-Werkzeuge (02_TECH §12.4); der erste
echte Lauf mit den Secrets steht noch aus.

## 5. Steuerung

Tasten sind als physische Tasten belegt und funktionieren daher auch mit QWERTZ. Alle Menüs lassen sich mit Tastatur,
Gamepad und Touch bedienen (02_TECH §2.2, §10). Gekämpft wird in Echtzeit direkt in der Welt (07 §7).

| Aktion | Tastatur / Maus | Gamepad (SDL-Layout) | Touch |
|---|---|---|---|
| Bewegen | WASD oder Pfeiltasten | linker Stick | schwebender Stick in den linken 40 % des Bildschirms (im Kampf unten links) |
| Kamera drehen | Q / E, rechte Maustaste gedrückt ziehen | rechter Stick | auf der freien rechten Fläche ziehen |
| Kamera zoomen | Mausrad | – | zwei Finger (Pinch) |
| Schleichen (halten) | Shift | LT oder L3 | Stick nur wenig auslenken (≤ 60 %) |
| Aktion: Interagieren, Feldschlag (Kai) oder Bellen (Graf Mopsula) | F, Leertaste, Enter | A | runder Aktions-Button rechts |
| Ziel wählen (Erkundung): Anführer einer Gruppe im Raum | Tab / Shift+Tab, Linksklick auf den Gegner; Linksklick auf freien Boden = Ziel weg | RT; B = Ziel weg | Gegner antippen; freien Boden antippen = Ziel weg |
| Kampf eröffnen (Pull, mit Ziel) | 1–5: die Fähigkeit des Slots | A (Slot 1, wenn das Ziel in Reichweite ist), X / Y (Slot 2 / 3) | Aktions-Button (zeigt dann das Symbol von Slot 1) |
| Pause | Esc, P | Start | Pause-Button oben rechts |
| Karte | M | Back | Karten-Button |
| Menü-Reiter wechseln | Q / E, Bild↑ / Bild↓ | LB / RB | Reiter antippen |
| Bestätigen / Zurück | Enter, Leertaste / Esc | A / B | Button antippen |
| Kampf: Ziel wählen | Tab / Shift+Tab, Linksklick auf Gegner oder Namensplakette (auf einen Party-Rahmen: Verbündete) | RT / LT | Gegner antippen; Ziel-Button (halten: vorheriges Ziel) |
| Kampf: Angriff | läuft von selbst; F, Leertaste, Enter = „Angriff!“ (ohne Ziel auf den nächsten Gegner); V = Auto-Angriff an/aus | Steuerkreuz unten = Auto-Angriff an/aus | läuft von selbst |
| Kampf: Fähigkeiten (Slot 1–4) | 1–4 oder Klick auf den Slot | A, X, Y, B | großer Knopf (Slot 1) und der Bogen darum |
| Kampf: SHOW (riskant, das Publikum liebt es) | 5 | RB | goldener SHOW-Knopf |
| Kampf: Trank | 6; Rechtsklick auf den Slot = Gegenstandsrad | LB (0,4 s halten = Gegenstandsrad) | Trank-Knopf (halten = Gegenstandsrad) |
| Kampf: Partner-Spezial | R | Steuerkreuz links | Knopf neben dem Partner-Rahmen |
| Kampf: Partner-Taktik (ab Stufe 3) | G | Steuerkreuz rechts | Taktik-Chip |
| Kampf: Autopilot an/aus | T | Steuerkreuz oben | AUTOPILOT-Button |
| Kampf: Ausweichen | aus der roten Bodenfläche laufen, bevor sie voll ist | linker Stick | Stick |
| Vollbild | F11 | – | – |
| Debug-Overlay (nur Debug-Build) | F3 | – | – |
| QA: Test-Geschenk / Sponsor-Fenster öffnen (Debug-Build, Overlay offen) | F4 / F5 | – | Buttons im Overlay |
| Staffel: Talent-Show (eine von drei Karten je Reihe) | ←/→, Enter; Esc = später | Steuerkreuz / Stick, A; B = später | Karte antippen; „Später“ |
| Staffel: Talentbaum (Pause → Party → „Talentbaum“) | Pfeiltasten, Enter = wählen / umwählen (nur im Safe Room); Q / E = andere Figur; Esc = schließen | Steuerkreuz / Stick, A; LB / RB; B | Karte antippen; Figur-Reiter; „Schließen“ |
| Staffel: Ausloggen (Pause → „Ausloggen“; Safe Room → „Ausloggen“) | Pfeiltasten, Enter: Taktik, Sendepause −/+, „Hier schlafen“; Esc = zurück | Steuerkreuz / Stick, A; B = zurück | Taktik antippen, −/+, „Hier schlafen“ / „Zurück“ |
| Staffel: Login-Bilanz „Während Sie schliefen …“ | Enter = Weiter; „Tag für Tag“ (wenn eingeschaltet) | A | „Weiter“ antippen |
| Staffel: Recall (Etage 3, Safe Room; sonst Knopf „RECALL“) | ↑/↓ = Karte (rechts die Vorschau), Enter = wählen und weiter, → = zu „WEITER“; Maus: Zeigen = Vorschau, Klick = wählen; Esc = einen Schritt zurück (im ersten Schritt: „Später“) | Steuerkreuz / Stick, A; B = zurück / später | Karte antippen = Vorschau, nochmal antippen oder „WEITER“ = wählen; „Zurück“, „Später“ |
| Staffel: Recall bestätigen | Enter auf „BESTÄTIGEN“, dann „WEITER: <Figur>“ bzw. „FERTIG“ („Talentbaum“ auf der Schlussseite) | A | „BESTÄTIGEN“, „WEITER“, „FERTIG“ |

Interagieren hat Vorrang: Zeigt die Erkundung einen Prompt (Truhe, Tür, Event in 1,5 m vor der Figur), löst die
Aktionstaste die Interaktion aus, sonst den Feldschlag bzw. das Bellen. Einen Kampf eröffnet man selbst mit einem **Pull**:
den Anführer einer Gruppe als Ziel wählen — der Zielrahmen oben zeigt Abstand, was die Gruppe gerade tut und je Slot, ob die
Fähigkeit reicht — und eine Fähigkeit auf ihn wirken (Kai: Wuchtschlag aus der Nähe; Graf Mopsula: Adelsflamme aus bis zu
20 m). Ruht die Gruppe, patrouilliert sie, ist sie angebellt oder steht man hinter ihr, ist das ein **Erstschlag** (die
Gegner sind 3 s überrumpelt). Graf Mopsulas Bellen verdutzt eine Gruppe und macht ihren Anführer gleich zum Ziel: bellen,
dann 1 (Gamepad: A, dann A; Touch: zweimal der Aktions-Button) ist immer ein Erstschlag. Kais Feldschlag eröffnet einen Kampf
aus der Nähe ebenso. Geht ein Pull nicht (zu weit weg, zu wenig MP, eine Fähigkeit ohne Gegner-Ziel), steht der Grund kurz
unter dem Zielrahmen; im Safe Room und im Treppenraum eröffnet man keinen Kampf. Ein Kampf beginnt außerdem, wenn ein
verfolgender Gegner die Figur erreicht (von hinten: Hinterhalt) oder sie 4 s im selben Raum verfolgt, und an den Bossen.
Gesehen werden allein startet keinen Kampf (07 §2.2). Wer den Ring des Kampf-Sets durch eine Türgasse verlässt, flieht.

**Rundenkampf (CTB):** gibt es in der Kampagne nicht mehr. Spielstände aus der Zeit davor werden beim Laden auf das neue
Format umgestellt (Version 2) und spielen in Echtzeit weiter. Der Rundenkampf lebt als Minispiel „Stempelduell“ weiter
(`docs/10_MINISPIEL_STEMPELDUELL.md`); dessen Steuerung beschreibt das Minispiel selbst.

<!-- --- Stempelduell (10, SD2) --- -->
### Stempelduell (Titel → Extras → Stempelduell (Vorschau))

Das Minispiel aus [`docs/10_MINISPIEL_STEMPELDUELL.md`](docs/10_MINISPIEL_STEMPELDUELL.md) ist als Vorschau spielbar
(Stand SD2-C … F, Kap. 7.3; Etage 8 folgt mit SD3). Im Titel steht neben „Event-Lauf“ der Knopf **Extras**; dort öffnet
„Stempelduell (Vorschau)“ die **Schalterhalle**:

- **Wartemarken** der Gegenüber (Ferdi Durchschlag, Ulla Umlauf, der Stempelmeister; Graf Mopsula als Übungsduell) →
  **Akte**: Zuständigkeiten, die eine neue Regel, was der erste Sieg bringt, Mappe wählen, „Passend zur Akte“ (der Graf
  stellt eine Mappe zusammen und legt sie als Kopie in eine freie Mappe, sonst nach Rückfrage), Duell starten.
- **Aktenschrank:** drei Mappen à 20 Karten bauen (Filter, Kurve der Bearbeitungszeit, „Auffüllen“, „Aktiv setzen“);
  eine Mappe, die nicht geht, sagt in einem Satz, warum.
- **Stempelalbum:** Karten je Herkunft (fehlende als Umriss mit dem Weg dorthin), Stempelheft, Dienstauszeichnungen und
  Kosmetik zum Anlegen. Nichts zu kaufen, nichts gewürfelt.
- **Regeln:** fünf Sätze, Glossar, die Steuerung des aktuellen Eingabeschemas, „Lernduell wiederholen“.
- Beim ersten Besuch begrüßt eine Karte und bietet das **Lernduell** an: sechs Lektionen am Tisch, danach die Grundakte
  mit der Startmappe als Mappe A. „Ich kenne mich aus“ gibt die Grundakte sofort.

Die Sammlung liegt in einer eigenen Datei (`user://stempel/collection.json`: Katalog-IDs und Zahlen, keine Namen) und
bleibt beim Löschen eines Spielstands oder der Kandidat:in erhalten. Die Kampagne schaltet Karten nur frei: Die
Speicherplätze werden gelesen, nie geschrieben.

| Am Tisch | Tastatur / Maus | Gamepad | Touch |
|---|---|---|---|
| Karte markieren (Vorschau: Geist-Zettel auf der Anzeige, Balken der Plaketten) | ← / → oder 1–5; Klick | Steuerkreuz / linker Stick ← → | Karte antippen |
| Markierte Karte spielen | Enter, Leertaste, F; zweiter Klick, „STEMPELN“ oder auf den Schalter ziehen | A | erneut antippen, „STEMPELN“ oder auf den Schalter ziehen |
| Abheften (Karte tauschen, bald wieder dran) | X oder Rücktaste, dann Karte und Enter (Esc bricht ab) | X, dann Karte und A (B bricht ab) | „ABLAGE“, dann Karte — oder Karte auf „ABLAGE“ ziehen |
| Großansicht der markierten Karte | Tab oder M | Select | Karte lang drücken (0,4 s) |
| Bereich wechseln: Hand → Wartenummern → Akte | Q / E | LB / RB | Gegner-Plakette antippen: Akte |
| Fußnote des Grafen zur empfohlenen Karte | Pfote anklicken | Großansicht der empfohlenen Karte | Pfote antippen |
| „Der Graf übernimmt“ an / aus | T | Y | Menü → Hilfen |
| Tempo × 1 / × 2 | R | R3 | Menü → Hilfen |
| Menü: Weiter, Regeln, Hilfen, Antrag zurückziehen | Esc oder P | Start | Menü-Knopf oben rechts |

In der Schalterhalle und den Menüs gilt die übliche Steuerung (Enter / A / Antippen, Esc / B zurück). Im Aktenschrank und
im Album wechseln Q / E bzw. LB / RB die Mappe oder Seite. Im Aktenschrank legt Enter / A / Antippen eine Karte in die
Mappe (eine Zeile der Mappe nimmt sie wieder heraus), Tab, M, Y oder langes Drücken zeigt sie groß; im Album öffnet ein
Druck auf die Karte die Großansicht. Die Hilfen im Menü: Tipps des Grafen, „Der Graf übernimmt“, Gegnerhand offen, Tempo,
Animationen reduzieren, Linkshänder-Spiegelung, Schriftgröße 100 / 125 / 150 %.

Prüfen: die Tests `test_sd_*` (`tools/check.sh --tests-only --filter=test_sd_`), das Perf-Szenario
`tools/perf.sh --only=stempel` (10 §6.10) und die Capture-Rezepte `sd_table`, `sd_table_touch`, `sd_boss_durchsage`,
`sd_results`, `sd_deck_builder`, `sd_album` (dazu `sd_hall`, `sd_akte`, `sd_lernduell`, `sd_menu`, `sd_bigview`):

```bash
T=prime-time-dungeon/tools/check.sh; D=res://scenes/stempel
GODOT=… $T --shot $D/sd_table.tscn shot.png 20 2400x1080 --touch --recipe=sd_table_touch --params='{"opp":"sdo_ulla","mappe":"a","seed":7}'
GODOT=… $T --shot $D/sd_table.tscn shot.png 20 1280x720 --recipe=sd_boss_durchsage --params='{"opp":"sdo_meister","mappe":"a","seed":11}'
GODOT=… $T --shot $D/sd_deck_builder.tscn shot.png 20 1280x720 --recipe=sd_deck_builder --params='{"mappe":"b"}'
GODOT=… $T --shot $D/sd_album.tscn shot.png 20 1280x720 --recipe=sd_album --params='{"page":"graf"}'
```
<!-- --- end Stempelduell --- -->

## 6. Entwickler-Argumente

Argumente stehen nach `--` (CLI) bzw. in den Main Run Args (Editor). Quelle: `scenes/boot/boot.gd`, 02_TECH §11.4.

| Argument | Wirkung |
|---|---|
| `--seed=<int>` | Seed für „Neues Spiel“ und für die `--goto`-Ziele (sonst Standard-Spielstand) |
| `--goto=explore` | überspringt den Titel und startet die Erkundung von Etage 1 am Startpunkt |
| `--goto=safe_room` | wie `explore`, betritt danach den ersten Safe Room |
| `--goto=title` | Titel (Standard) |
| `--goto=credits` | Abspann |
| `--goto=lobby` | SHOWRUN-Event-Lobby |
| `--goto=game_over` | Game-Over-Screen (Grund: Timer) |
| `--autoplay` | Smoke-Test: spielt Titel → Neues Spiel → Erkundung → Kampf → Safe Room automatisch, schneller Zeitablauf, flüchtige Einstellungen, es werden keine Spielstände geschrieben; endet mit `AUTOPLAY: OK` und beendet das Spiel mit Exit-Code 0 |
| `--autoplay=full` | Full-Run-Bot: spielt Etage 1 von Titel bis Abspann (02_TECH §11.4.1), mit echten Spielständen in eigenem Verzeichnis |
| `--strategy=thorough\|rush\|dawdle\|typical` | Strategie des Full-Run-Bots: alles / nur Safe Rooms, Tore, Bosse / trödeln bis zum Etagenkollaps / typische:r Erstspieler:in |
| `--pace=fast\|human` | Takt des Full-Run-Bots: ohne Wartezeit oder mit dem Modell eines aufmerksamen Menschen |
| `--rt-profile=typical\|perfect\|sloppy` | Full-Run-Bot im Echtzeitkampf: Spielprofil der Person (07 §5.7, je Held:in) |
| `--season=<ssn-id>` | **nur Debug-Builds** (Staffeln, 09 §11.1, ST1-B): startet eine neue private Staffel der Vorlage (`ssn_basis` 6 Etagen / 24 Tage, `ssn_akt2` 12 / 54, `ssn_akt3` 18 / 84) und geht ohne Titel, Casting und Intro in die Erkundung von Etage 1. Tag 0 ist die nächste Sendezeit; die Einsturz-Termine stehen ab dann in UTC fest. Etage 1 ist die Generalprobe (ein verlorener Kampf kostet dort nichts: die Sanitäter bringen die Gruppe in den zuletzt betretenen Safe Room); ihre Treppe führt nach der Etagen-Bilanz auf die Etagen 2–6 (ST1-C1: Passage, Fundus, Paketzentrum). Etage 6 ist das Finale der Basis-Staffel: Der Sieg über ihren Etagenboss oder der letzte Einsturz beendet die Staffel; längere Formate enden nach Etage 6 mit dem Ende des Inhalts („Bis zum Ende dabei“, Abspann). Ohne `--slot` im ersten freien Slot (alle belegt: Slot 0, nie gespeichert); gespeichert wird automatisch (Dauerspeicherstand mit Journal). Die freien Plätze spielt die KI-Besetzung (99 KI-Kandidat:innen, ST1-F): ihre Erstbesteigungen, Einstürze und Rekorde meldet M.O.D. als Eilmeldung (höchstens eine je 10 min Spielzeit, nie im Kampf). Stufen und Talente (ST1-D): auf Etage 1 endet die Stufe am Deckel 7 (darüber Überstunden als Credits); die Grundreihen des Talentbaums öffnen auf Stufe 3, 5 und 7 (Talent-Show im Safe Room, umwählen in Pause → Party → „Talentbaum“), die Treppe gibt eine halbe Stufe, ein Etagen-Event 5 %; Klassenfähigkeiten, Ränge und Klassenreihen kommen mit dem Recall auf Etage 3: Er öffnet im ersten Safe Room der Etage von selbst (Spezies und Klasse beider Figuren, Abschnitt 2; danach liegt die Signatur der Klasse auf Slot 1, „Ohne Netz“ ist frei) — am schnellsten mit `--tempo=binge --floor=3` und dem ersten Safe Room. Schläfer (ST1-G): Pause → „Ausloggen“ legt die Figur schlafen und führt zum Titel; beim Laden des Slots wird die Abwesenheit gebucht (mit `--speed` × Zeitraffer) und „Während Sie schliefen …“ gezeigt; über 10 min geschlossen oder im Hintergrund gilt als Ausloggen |
| `--tempo=calendar\|binge` | mit `--season`: Kalender (Einsturz zu festen Terminen; die Uhr läuft in Erkundung und Safe Room, ein Uhr-Command je 60 s) oder Am Stück (Countdown je Etage: 20, 30, 40, 50 … min) |
| `--mode=net\|no_net` | mit `--season`: Mit Netz (Rettung, Sanitäter) oder Ohne Netz (ab Etage 2 ein Leben) — hier ohne Freischaltung |
| `--speed=<n>` | mit `--season`, Zeitraffer: Staffelsekunden je Sekunde Wanduhr (1–10080; `--speed=1440`: ein Tag je Minute) |
| `--slot=<1-3>`, `--hero=kai\|mopsula`, `--air=HH:MM` | mit `--season`: Spielstand-Slot, Held:in, eigene Sendezeit (Standard: die der Vorlage, 20:00 Ortszeit) |
| `--floor=<n>` | mit `--season` (ST1-C1): nimmt gleich nach dem Start die Treppen bis Etage n (aufgezeichnete Abstiege ohne Etagen-Bilanz; die Treppenregel gilt — Am Stück jede Etage, im Kalender zu Beginn bis Etage 3). Zum Ansehen der Etagen, nicht für die Balance: ohne Kämpfe hat die Gruppe nur die Abschluss-EP der Treppen (ST1-D; auf Etage n etwa Stufe n), weit unter dem Band der Etage |

Beispiel: `godot --path prime-time-dungeon/game -- --autoplay=full --strategy=typical --pace=human`
Staffel (Debug): `godot --path prime-time-dungeon/game -- --season=ssn_basis --tempo=calendar --speed=1440`
Etage 4 einer Staffel ansehen: `godot --path prime-time-dungeon/game -- --season=ssn_basis --tempo=binge --floor=4`
Recall ansehen: `godot --path prime-time-dungeon/game -- --season=ssn_basis --tempo=binge --floor=3`, dann in den Safe
Room des ersten Viertels (die Karte, M, zeigt ihn)

**Staffel-Bots (09 Kap. 11.6, ST1-I):** Zwei Werkzeuge spielen ganze Staffeln (Abschnitt 7). `tools/fullrun.sh
--season=ssn_basis` lässt den Full-Run-Bot in der Welt spielen: Start zu festem Tag 0 mit dem Lauf-Seed (reproduzierbar),
alle Etagen der Basis-Staffel mit derselben Wegplanung wie der Harness (Revier-Boss → Schlüssel → Tor → Treppe,
Programmtüren, Safe Room je Viertel), Recall auf Etage 3, Klassenfähigkeiten und Talentreihen, Finale; `--tempo=calendar`
spielt die Sitzungen eines Profils mit Ausloggen, Abwesenheit, Login und „Während Sie schliefen …“.
`tools/season_harness.sh` spielt dieselben Staffeln ohne Welt im Kern (RunSim, echte Echtzeitkämpfe, KI-Besetzung,
Schläfer) in etwa 1–2 min je Staffel und misst Pensum, Stufen gegen das Band, Bosse, Tode, Rettungen und Credits je
Etage gegen die Bänder des ST1-Gates (auf Format 6 skaliert; Formate 12/18 lehnt er bis ST1-C2 ab, Exit 3).

```bash
GODOT=… prime-time-dungeon/tools/fullrun.sh --season=ssn_basis --tempo=binge --strategy=thorough     # Am Stück, alles
GODOT=… prime-time-dungeon/tools/fullrun.sh --season=ssn_basis --tempo=calendar --sessions=20min     # Kalender
GODOT=… prime-time-dungeon/tools/season_harness.sh --gate --seeds=10 --jobs=2      # vier Profile, Mit/Ohne Netz
GODOT=… prime-time-dungeon/tools/season_harness.sh --tempo=binge --strategy=typical --seeds=10   # Pflichtweg Am Stück
```

Kämpfe beginnen in der Welt (`--goto=explore`); bestimmte Kämpfe stellen die Capture-Rezepte her (Abschnitt 10). Die
Argumente `--combat=ctb|realtime` und `--goto=battle:<enc_id>` gibt es seit R5b-2b nicht mehr (die Kampagne kämpft nur in
Echtzeit, die CTB-Kampfszene ist gelöscht).

## 7. Werkzeuge

Alle Skripte liegen in `tools/` und brauchen die Umgebungsvariable `GODOT=<Pfad zur Godot-4.7-Binary>` (Standard: `godot`
im `PATH`). `check.sh`, `fullrun.sh` und `perf.sh` arbeiten in einer **isolierten Temp-Kopie** des Projekts mit eigenem
`user://`: Mehrere Läufe können parallel laufen, und eigene Spielstände bleiben unberührt. `make_icons.sh` baut ebenfalls in
einer Temp-Kopie, schreibt die Icons aber nach `game/art/icons/` zurück. `--shot` und `perf.sh` brauchen `xvfb-run`
(außer `perf.sh --headless`).

| Skript | Zweck | Erfolg |
|---|---|---|
| `tools/check.sh` | Import, alle Tests, Autoplay-Smoke-Test (Titel → Neues Spiel → Erkundung → Echtzeitkampf → Safe Room) | letzte Zeile `check.sh: OK` |
| `tools/check.sh --tests-only [--filter=<teil>]` | Import und Tests (optional nur Testdateien, deren Name `<teil>` enthält) | `check.sh: OK` |
| `tools/check.sh --shot <res://szene.tscn> <out.png> [frames] [BxH] [--touch] [--recipe=<name>] [--params=<json>] [--no-global-ui]` | rendert eine Szene unter Xvfb (`xvfb-run` nötig) im Compatibility-Renderer und speichert ein PNG | `saved <pfad>` |
| `tools/fullrun.sh [--strategy=thorough\|rush\|dawdle\|typical\|all] [--hero=kai\|mopsula] [--seed=<int>] [--pace=fast\|human] [--liga=0\|1\|2] [--rt-profile=typical\|perfect\|sloppy] [--log-dir=<dir>]` | Full-Run-Bot headless mit festem 60-fps-Takt im Echtzeitkampf (07 §12.5): der `RtBotPlayer` spielt jeden Kampf als Person; `all` = thorough, rush und dawdle als Kai plus thorough als Graf Mopsula nach einem Import (wie in CI) | `fullrun.sh: OK` |
| `tools/fullrun.sh --season=<ssn-id> [--tempo=binge\|calendar] [--sessions=typical\|20min\|weekend\|away2w\|none] [--mode=net\|no_net] [--strategy=thorough\|typical\|rush\|auto] [--speed=<n>] [--floors=<n>] [--pace=…] [--seed=…]` | Full-Run-Bot in einer Staffel (09, ST1-I): alle Etagen des Formats, im Kalender mit Ausloggen und Login nach dem Profil; misst je Etage Minuten, Pflichtweg/vollständig, Stufen gegen das Band, Bosse, Tode, Rettungen, Credits (`FULLRUN: season {json}`) | `FULLRUN: OK season=…`, `fullrun.sh: OK` |
| `tools/season_harness.sh [--format=6] [--tempo=calendar\|binge] [--profile=typical\|20min\|weekend\|away2w\|all] [--mode=net\|no_net\|both] [--strategy=auto\|thorough\|typical\|rush] [--pace=human\|fast] [--seeds=10] [--first-seed=0] [--jobs=1] [--out=<datei.json>] [--runs] [--strict-bands]`, `--gate` | Staffel-Harness (09 §11.6, ST1-I): ganze Staffeln headless im Kern mit Bot, KI-Besetzung und Schläfern im Zeitraffer; Zeilen je Staffel, Zusammenfassung je Profil, `HARNESS-BAND`-Urteile gegen das ST1-Gate (Format 6); `--format=12\|18` → Exit 3 bis ST1-C2 | `season_harness.sh: OK`, Exit 0 |
| `tools/rt_balance.sh [--seeds=20] [--hero=kai\|mopsula\|both] [--liga=0\|1\|2\|all] [--profile=typical\|perfect\|sloppy\|all] [--strict-bands] [--out=<datei>]`, `--sequence`, `--perf`, `--nightly` | Balance-Harness des Echtzeitkampfs (07 §11.4): die Begegnungen von Etage 1 auf der echten Sim mit den Bot-Profilen, Urteile gegen die Bänder aus 07 §11.1; nachts 200 Seeds (CI-Job `nightly-balance`) | Tabelle mit `RT-BAND`-Zeilen, Exit 0 |
| `tools/perf.sh [--driver=opengl3\|vulkan] [--quality=high\|low] [--only=startup,explore,safe_room,combat,leak] [--cycles=20] [--out=<datei.md>] [--shots=<dir>] [--cells] [--headless]` | Performance-Probe unter Xvfb: Budget-Tabelle aus 02_TECH §12.1 (Draw Calls, Primitive, Lichter, Speicher, Ladezeiten), der Echtzeitkampf in der Welt (`combat`: regulär, zwei Gruppen, Königin) und Leak-Schleife über Szenenwechsel; Ergebnisse in `docs/PERFORMANCE.md` | `PERF: OK`, `perf.sh: exit 0` |
| `tools/make_icons.sh` | erzeugt die App-Icons (Android, iOS, macOS) und die iOS-Startbilder in `game/art/icons/` aus `game/icon.svg` neu | Zeilen `ICON: …`, Exit 0 |
| `tools/apple/release.sh <schritt>` | nur CI (macOS-Runner, Secrets): Schritte der Jobs `apple-macos` und `apple-ios-testflight`, Abschnitt 4 „Mit Apple-Entwicklerkonto“, 02_TECH §12.4 | Exit 0 |

**Exit-Codes:** `0` = bestanden. `1` = Fehler: Import, Test, Smoke-Test, Screenshot, Bot-Lauf, Budget-Überschreitung oder
Speicherwachstum. Jede Zeile mit `SCRIPT ERROR`, `Assertion failed`, `ERROR:` usw. zählt als Fehler, auch bei Exit 0 des
Godot-Prozesses. `2` = Aufruffehler (Godot-Binary nicht gefunden; bei `fullrun.sh` auch ein unbekanntes Argument). `3` =
`season_harness.sh` lehnt das Format ab (12/18 bis ST1-C2). Der Test-Runner wertet auch
übersprungene Tests als Fehler, sofern sie nicht ausdrücklich zugelassen sind. Zeitbudgets in Tests werden nur mit
`PTD_PERF_ASSERTS=1` geprüft (CI-Check-Job).

```bash
GODOT=~/godot/godot prime-time-dungeon/tools/check.sh
GODOT=~/godot/godot prime-time-dungeon/tools/fullrun.sh --strategy=all
GODOT=~/godot/godot prime-time-dungeon/tools/fullrun.sh --hero=mopsula --liga=2      # Graf Mopsula, Duo-Liga
```

## 8. Ordner

```
prime-time-dungeon/
├── README.md            diese Datei
├── CHANGELOG.md         was in welchem spielbaren Build neu ist
├── docs/                Design- und Technik-Dokumente (Abschnitt 9), docs/screenshots/
├── tools/               check.sh, fullrun.sh, season_harness.sh, perf.sh, make_icons.sh, apple/ (release.sh + Entitlements, nur CI)
└── game/                Godot-Projekt (= res://), project.godot, export_presets.cfg, icon.svg
    ├── autoload/        Events, DB, Game, Show, Save, Router, Sfx (+ private Helfer wie game_replay.gd)
    ├── core/            reine Logik (RefCounted, headless testbar, ohne Autoloads)
    │   ├── data/        GameData, Defs, DataValidator (+ validators/ je neuer Tabelle), SeedUtil, JsonUtil
    │   ├── stats/       StatBlock, Elemente, Balance-Konstanten, FixedMath
    │   ├── rt/          Echtzeitkampf: RtSim (30 Ticks/s), Fähigkeiten, Telegraphen, Partner- und Gegner-KI, RtMods
    │   ├── battle/      geteilte Kampf-Typen: Schadensformeln, Status, ActionEvent, BattleCommand, BattleResult (Beute)
    │   ├── stempel/     Minispiel „Stempelduell“ (10): ctb/ = die Engine des früheren Rundenkampfs, eingefroren
    │   ├── show/        ShowModel (Hype, Zuschauer, Follower), Achievements, Sponsoren, M.O.D.-Ansagen, Marotten/Liga
    │   ├── loot/        LootRoller (Lootboxen, Truhen, Pools)
    │   ├── progression/ GameState, FloorRun, Party, Inventar, EXP, Shop, BattleBridge, SaveCodec, Talents, Casting, HeroRules,
    │   │                Persona; Staffeln (09): EnemyLevels (ST1-C), TalentTree und AbilityBook (ST1-D), Professions
    │   │                (Stub aus ST0)
    │   ├── season/      Staffeln (09): SeasonClock, SeasonState, SeasonRules, CastSim (KI-Besetzung: CastModel, CastMember,
    │   │                CastEvent), LevelBand (Stufen, Band, Aufholjagd, ST1-D), SleepResolver — Stubs aus ST0, gefüllt von ST1
    │   ├── dungeon/     FloorLayout, DungeonGenerator, ZoneGenerator (Generator v2 der Staffeln), Spawns, Etagen-Events,
    │   │                ExploreEvent
    │   └── live/        SHOWRUN: RunLog, RunSim, RunRules, StateHash, Gift, GiftPolicy, Sponsor-Fenster, Quest, Bestenliste,
    │                    KI-Admin: TwistApplier (Twists), RegieDirector (Offline-Regie ab Etage 2)
    ├── data/            26 JSON-Dateien: 23 GameData-Tabellen (seit 09 ST0 auch seasons, professions, cast, themes) +
    │                    rt_balance.json + events.json (SHOWRUN-Events) + mod_filter.json (Filter für „M.O.D. live“)
    ├── art/             shaders/, materials/, kit/ (prozedurale Figuren, Räume, Props, VFX), gallery/, icons/
    ├── scenes/          boot/, title/, exploration/, combat/ (Echtzeitkampf: Director, HUD), safe_room/, ui/
    └── tests/           run_tests.gd, test_*.gd, lib/, fixtures/, perf/, tools/, capture.gd, capture_recipes.gd
```

Außerhalb dieses Verzeichnisses: der CI-Workflow `.github/workflows/ptd-check.yml` im Repo-Wurzelverzeichnis (Import,
Tests, Smoke-Test, Full-Run-Bot, Screenshots, spielbare Builds bei `v*`-Tags, mit Apple-Entwicklerkonto auch notarisierte Mac-App
und TestFlight, pytest des KI-Admin-Dienstes) und der optionale
Referenz-Dienst `services/mod-brain/` für „M.O.D. live“ (Python/FastAPI + Claude; Standard aus, eigenes README). Export-Ausgaben landen in `build/` bzw. `export/`; beide
Ordner stehen in `.gitignore`.

## 9. Dokumente

Bei Widersprüchen gilt die Rangfolge aus 00_BRIEF: **00_BRIEF > 07_ECHTZEITKAMPF (alles Kampfrelevante) > 06 (neue
Systeme) > 01_GDD / 02_TECH / 03_ART / 05 (je nach Thema) > 04**.

| Dokument | Inhalt |
|---|---|
| [`docs/00_BRIEF.md`](docs/00_BRIEF.md) | Leitentscheidungen, verbindlich: Prämisse, Design-Säulen, Systeme, Technik, Nutzerentscheidungen zu Echtgeld und Sponsor-Fenstern |
| [`docs/02_TECH.md`](docs/02_TECH.md) | Technik-Vertrag: Dateibaum und Modulbesitz, Autoloads, Datenschemas, APIs, Tests, Capture, Autoplay, Performance-Budgets, CI |
| [`docs/01_GDD.md`](docs/01_GDD.md) | Game Design: Regeln, Formeln, Inhalte und Zahlen von Etage 1, Balancing (Kap. 13) |
| [`docs/03_ART.md`](docs/03_ART.md) | Art Direction Option B: Farben, Shader, prozedurale Figuren und Umgebung, VFX, UI-Look |
| [`docs/04_STRATEGIE_ROADMAP.md`](docs/04_STRATEGIE_ROADMAP.md) | Strategie: Positionierung, IP und Recht, Phasenplan 0–7, Team, Finanzierung, Monetarisierung |
| [`docs/05_LIVE_MODUS.md`](docs/05_LIVE_MODUS.md) | Live-Modus SHOWRUN: Stufen S0–S5, Determinismus, Protokoll, Geschenke, Sponsor-Fenster, Wirtschaft, Recht |
| [`docs/06_PROGRESSION_MAROTTEN_KI_ADMIN.md`](docs/06_PROGRESSION_MAROTTEN_KI_ADMIN.md) | Neue Systeme in Paketen A–D: Figurenwahl (Paket A, umgesetzt), Talent-Show und Spezies (Paket B, umgesetzt), M.O.D.-Marotten, KI-Admin |
| [`docs/07_ECHTZEITKAMPF.md`](docs/07_ECHTZEITKAMPF.md) | Echtzeitkampf „WoW-light“ direkt in der Welt (ersetzt den CTB-Kampf, seit R5b-2b der einzige Kampf der Kampagne): Vertrag, Phasen R1–R5 |
| [`docs/08_CASTING.md`](docs/08_CASTING.md) | Casting: eigene Kandidat:in (Persona), Vorleben, persönlicher Erzählstrang, Aussehen; KI optional |
| [`docs/09_STAFFELN.md`](docs/09_STAFFELN.md) | Staffeln: Sendeplan bis Etage 18, KI-Besetzung, Schläfer und Ausloggen, Tod und Modi, Fertigkeiten (ST1–ST3) |
| [`docs/10_MINISPIEL_STEMPELDUELL.md`](docs/10_MINISPIEL_STEMPELDUELL.md) | Mini-Spiel „Stempelduell“: der CTB-Kampf als optionales Karten-Duell (Etage 8; bis dahin Titel → Extras → Vorschau), Umsetzung SD1–SD3 (SD1, die Engine-Auslagerung, ist umgesetzt) |
| [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md) | Messergebnisse der Performance-Probe gegen die Budgets aus 02_TECH §12.1 |

## 10. Screenshots

Alle Bilder stammen aus dem Spiel selbst (Compatibility-Renderer unter Xvfb, 1280 × 720; Bilder 59, 63, 70, 71, 78, 84,
98 und 99 im Handy-Format 2400 × 1080 und Bild 26 im Handy-Format 1600 × 720, alle mit Touch-Steuerung). Die
Staffel-Bilder 72–78 und 90–99 (Recall, Etage 3) zeigen eine Basis-Staffel, die mit `--season-floor` direkt auf die Etage
gestiegen ist (ohne Kämpfe: die Gruppe hat nur die Abschluss-EP der Treppen, Stufe 2 auf Etage 2 bis Stufe 6 auf Etage
6). Die Bilder 79–84 (09, ST1-G) zeigen das Ausloggen und den Login einer Kalender-Staffel: 79, 80 und 84 im Modus Ohne
Netz, 81 und 82 nach fünf Tagen Schlaf auf Etage 2 im Modus Mit Netz (die Etage stürzte dabei ein), 83 nach einem
Uhrsprung von 23 Tagen. Die Kampfbilder zeigen den Echtzeitkampf, seit R5b-2b den einzigen Kampf der Kampagne; die
Bilder des früheren Rundenkampfs (08–12, 18, 22, 28) liegen als Archiv in `docs/screenshots/` (die CTB-Kampfszene, die
sie erzeugte, ist gelöscht).

| | |
|---|---|
| ![Titel](docs/screenshots/01_title_menu.png) **01** Titelmenü | ![Intro](docs/screenshots/02_intro_mod_studio.png) **02** Intro im Studio von M.O.D. |
| ![U-Bahn-Gleise](docs/screenshots/03_explore_ubahn_gleise_enemy_group.png) **03** Erkundung, Zone U-Bahn-Gleise mit Gegnergruppe (rechts der Show-Chip) | ![Kanalisation](docs/screenshots/04_explore_kanalisation_enemy_group.png) **04** Erkundung, Zone Kanalisation mit Gegnergruppe |
| ![Keller](docs/screenshots/05_explore_keller_chest_prompt.png) **05** Zone Keller: Kai vor einer Truhe mit Prompt | ![Karte](docs/screenshots/06_explore_floor_map.png) **06** Etagenkarte |
| ![Pausemenü](docs/screenshots/07_pause_menu_equipment.png) **07** Pausemenü, Reiter Ausrüstung (mit Liga-Zeile) | ![Echtzeitkampf](docs/screenshots/54_echtzeitkampf_telegraph.png) **54** Echtzeitkampf in der Welt: Lichtring des Kampf-Sets, Aktionsleiste, rote Bodenwarnung |
| ![Rattenkönigin](docs/screenshots/57_echtzeitkampf_koenigin_zug.png) **57** Die Rattenkönigin von Gleis 9: der Zug fährt ein | ![Hausmeister](docs/screenshots/56_echtzeitkampf_hausmeister.png) **56** Der Hausmeister holt zum Schlüsselbund-Wurf aus |
| ![Show-Boss](docs/screenshots/55_echtzeitkampf_showboss.png) **55** Show-Boss „Kanalratten-Gala“ mit dem Rattenschamanen | ![Applaus](docs/screenshots/58_echtzeitkampf_applaus.png) **58** Sieg: Bauchbinde „Applaus!“ mit EXP, Credits und Beute |
| ![Mopsula](docs/screenshots/13_safe_room_mopsula_scene.png) **13** Safe Room: Szene mit Graf Mopsula | ![Lootbox](docs/screenshots/14_safe_room_lootbox_reveal_odds.png) **14** Lootbox-Öffnung mit veröffentlichten Wahrscheinlichkeiten |
| ![Event-Lobby](docs/screenshots/15_event_run_lobby.png) **15** SHOWRUN-Event-Lobby mit lokaler Bestenliste | ![Cast](docs/screenshots/16_gallery_cast_floor1.png) **16** Galerie: Besetzung von Etage 1 |
| ![VFX](docs/screenshots/17_gallery_vfx.png) **17** Galerie: Effekte | ![Handy](docs/screenshots/59_handy_echtzeitkampf_touch.png) **59** Handy-Format: Echtzeitkampf mit Touch-Steuerung |
| ![Figurenwahl](docs/screenshots/19_hero_select.png) **19** Figurenwahl: Kai oder Graf Mopsula (06 Paket A) | ![Bellen](docs/screenshots/20_explore_mopsula_bark.png) **20** Graf Mopsula führt und bellt eine Gruppe an |
| ![Figur wechseln](docs/screenshots/21_safe_room_hero_switch.png) **21** Safe Room nach „Figur wechseln“ | ![Hinweiskarte](docs/screenshots/60_echtzeitkampf_hinweis_unterbrechen.png) **60** Hinweiskarte beim ersten Mal: Unterbrechen (goldener Rand) |
| ![Kulissenwand](docs/screenshots/23_secret_wall.png) **23** Kulissenwand (E1-Geheimnis) | ![Wand fällt](docs/screenshots/24_secret_wall_falls.png) **24** Der Graf bellt die Kulissenwand um |
| ![Regie-Notiz](docs/screenshots/25_regie_notiz.png) **25** Regie-Notiz mit Prompt | ![Handy Safe Room](docs/screenshots/26_safe_room_hero_talents_phone.png) **26** Handy-Format: Safe Room mit TALENT-SHOW-Knopf und M.O.D.-Kasten |
| ![Show](docs/screenshots/27_pause_show_unterhosen_liga.png) **27** Pausemenü, Reiter Show: M.O.D.s Vorliebe und Unterhosen-Liga (06 Paket C) | ![Abspann](docs/screenshots/61_echtzeitkampf_boss_abspann.png) **61** Bosssieg: Abspann mit EXP, Stufenaufstieg, Talent-Hinweis und Beute |
| ![Ziel wählen](docs/screenshots/62_erkundung_pull_ziel.png) **62** Kampf eröffnen: Kai hat mit Tab einen Anführer als Ziel — Zielrahmen mit den Slots, Ring und Pfeil, Hinweis „1 · Angriff eröffnen“ | ![Handy Pull](docs/screenshots/63_handy_erkundung_pull_touch.png) **63** Handy-Format: Anführer angetippt, der Aktions-Button zeigt Slot 1 und eröffnet den Kampf |
| ![Bellen, dann 1](docs/screenshots/64_erkundung_bellen_erstschlag.png) **64** Graf Mopsula hat gebellt: Der verdutzte Anführer ist schon Ziel — „verdutzt · Erstschlag!“ | |
| ![Talent-Show Reihe](docs/screenshots/65_staffel_talent_show_reihe.png) **65** Staffel: Die Talent-Show stellt eine Klassenreihe vor — drei Karten, links und rechts die Zweige der Abrissbirne | ![Talentbaum](docs/screenshots/66_staffel_talentbaum.png) **66** Staffel: Talentbaum (Pause → Party), Wahlen in Gold, Reihe 25 offen, umwählen im Safe Room |
| ![Party Staffel](docs/screenshots/67_staffel_party_aufholjagd.png) **67** Staffel, Party-Seite: Aufholjagd und Ausgeruht (Kai), Deckel der Etage (Graf Mopsula), Reihen des Talentbaums, Knopf „Talentbaum“ | ![Fähigkeitenbuch](docs/screenshots/68_staffel_faehigkeitenbuch.png) **68** Staffel, Fähigkeitenbuch nach dem Recall: die Signatur der Abrissbirne belegt Slot 1 |
| ![Klassen-Vorschau](docs/screenshots/69_staffel_klassen_vorschau.png) **69** Staffel, vor dem Recall: Reiter „Klassen-Vorschau“ mit den Fähigkeiten der vier Klassen des Grafen | ![Handy Talentbaum](docs/screenshots/70_handy_staffel_talentbaum_touch.png) **70** Handy-Format mit Touch: Talentbaum (71: die Talent-Show) |
| ![Passage](docs/screenshots/72_staffel_passage_food_court.png) **72** Staffel, Etage 2 „Passage Ewiger Rabatt“: Food-Court mit einem Durchsage-Geist und einem verschlossenen Tor (09, ST1-C1) | ![Fundus](docs/screenshots/73_staffel_fundus_kostuemfundus.png) **73** Etage 3 „Der Fundus“: Viertel Kostümfundus mit einer Pappritter-Ratte |
| ![Paketzentrum](docs/screenshots/74_staffel_paketzentrum_sortierhalle.png) **74** Etage 4 „Das Paketzentrum“: Sortierhalle mit einer Paketkrabbe | ![Paketberg](docs/screenshots/75_staffel_paketberg_buehne.png) **75** Etage 6: Der Paketberg auf der Bühne seines Bossraums (Finale der Basis-Staffel) |
| ![Programmtür](docs/screenshots/76_staffel_programmtuer.png) **76** Programmtür: „Noch geschlossen — öffnet mit Programmpunkt 2“ | ![Karte](docs/screenshots/77_staffel_karte_viertel.png) **77** Karte von Etage 6: vier Viertel, Safe Room je Viertel, Programmtüren (eine offen), Schlüsseltor vor der Treppe, Revier- und Etagenboss |
| ![Handy Staffel](docs/screenshots/78_handy_staffel_paketzentrum_touch.png) **78** Handy-Format: das Paketzentrum mit Touch-Steuerung | |
| ![Ausloggen im Gang](docs/screenshots/79_staffel_ausloggen_gang.png) **79** Staffel: Ausloggen im Gang (Pause → Ausloggen) — Gefahr, Begegnungen, nächster Safe Room, Schlaftaktik, Sendepause, Einsturz-Wecker | ![Ausloggen im Safe Room](docs/screenshots/80_staffel_ausloggen_safe_room.png) **80** Ausloggen im Safe Room: „sicher, Sie werden ausgeruht“ |
| ![Login-Bilanz](docs/screenshots/81_staffel_login_bilanz.png) **81** Login-Bilanz „Während Sie schliefen …“: Rettung beim Einsturz, Begegnungen, Crashkurs, Ausgeruht, Sendeplan, ein Zettel aus der KI-Besetzung | ![Tag für Tag](docs/screenshots/82_staffel_tag_fuer_tag.png) **82** Tageszusammenfassung „Tag für Tag“ |
| ![Uhrsprung](docs/screenshots/83_staffel_login_frage.png) **83** Die Uhr sprang um mehr als 7 Tage: Der Login fragt zuerst nach | ![Handy Ausloggen](docs/screenshots/84_handy_staffel_ausloggen_touch.png) **84** Handy-Format mit Touch: Ausloggen im Gang |
| ![Recall Spezies](docs/screenshots/90_staffel_recall_spezies.png) **90** Recall auf Etage 3, Schritt 1 „Wer bist du?“: Kais Spezies-Karten, rechts Kachelgolem mit Werten vorher → nachher und der Jury | ![Recall Klasse](docs/screenshots/91_staffel_recall_klasse.png) **91** Schritt 2 „Was kannst du?“: Abrissbirne EMPFOHLEN und PASST ZU IHREM VORLEBEN, die ersten Klassenfähigkeiten |
| ![Recall Bestätigen](docs/screenshots/92_staffel_recall_bestaetigen.png) **92** Schritt 3: das Paar, die Signatur auf Slot 1, die Regeln fürs Umentscheiden | ![Recall Urteil](docs/screenshots/93_staffel_recall_urteil.png) **93** Die Jury urteilt: „Ein Bauprojekt auf zwei Beinen. Die Statik nickt.“ |
| ![Recall Graf](docs/screenshots/94_staffel_recall_mopsula.png) **94** Graf Mopsula ist dran: seine eigenen Spezies, Flattermops in der Vorschau | ![Recall fertig](docs/screenshots/95_staffel_recall_fertig.png) **95** Schlussseite: beide Rollen, Höchststufe 13, „NEU: OHNE NETZ“, Knopf „Talentbaum“ |
| ![Safe Room Recall](docs/screenshots/96_staffel_safe_room_recall.png) **96** Nach „Später“: der Knopf RECALL im Safe Room, M.O.D. sagt, wo die Wahl wartet | ![Party Recall](docs/screenshots/97_staffel_party_recall.png) **97** Pausemenü → Party nach dem Recall: Spezies und Klasse beider Figuren |
| ![Handy Recall](docs/screenshots/98_handy_staffel_recall_spezies_touch.png) **98** Handy-Format mit Touch: Recall, Spezies-Karten (99: Klassen) | |
| ![Casting 1/3](docs/screenshots/29_casting_1_wer_sind_sie.png) **29** Casting 1/3 „Wer sind Sie?“: Name, Wortform, Figur (08 K1) | ![Casting 2/3](docs/screenshots/30_casting_2_steckbrief.png) **30** Casting 2/3 „Steckbrief“: Vorleben, Hobby / Talent, Eigenschaften |
| ![Vorleben](docs/screenshots/31_casting_2_vorleben_overlay.png) **31** Overlay „Vorleben wählen“ mit „genauer“-Chips | ![Eigenschaften](docs/screenshots/32_casting_2_eigenschaften_overlay.png) **32** Overlay „Eigenschaften“ (0–3, leer erlaubt) |
| ![Kandidatenkarte](docs/screenshots/33_casting_3_kandidatenkarte.png) **33** Casting 3/3: Kandidatenkarte und Sendeformat | ![Tastatur](docs/screenshots/34_casting_bildschirmtastatur_akzente.png) **34** Bildschirmtastatur mit Akzenttasten |
| ![Handy](docs/screenshots/35_phone_casting_1_touch.png) **35** Handy-Format mit Touch, Casting 1/3 (36, 37: 2/3 und 3/3) | ![130 %](docs/screenshots/38_casting_1_text130.png) **38** Casting mit 130 % Text (39, 40: Overlay und Karte) |
| ![Karte im Pausemenü](docs/screenshots/41_pause_kandidatenkarte.png) **41** Pausemenü → Party → „Kandidatenkarte“ | ![Bauchbinde](docs/screenshots/42_intro_bauchbinde.png) **42** Intro: Bauchbinde der Kandidat:in und ihre `persona_intro`-Zeile |
| ![Talent-Show](docs/screenshots/talent_show.png) **Talent-Show** (06 Paket B): zwei Karten je Wahl | ![TALENT-SHOW](docs/screenshots/safe_talents_menu.png) **Safe Room** mit offener Talentwahl |
| ![Sponsor-Fenster](docs/screenshots/overlay_sponsor_window.png) **Overlay** Show-Overlay (Demo-Werte): Sponsor-Fenster offen mit Platz-Punkten, Show-Chip „M.O.D. mag heute“ mit Herzen und Liga-Stufe | ![Party](docs/screenshots/talents_party.png) **Party-Seite** mit Talenten und offener Wahl |

**Neu erzeugen:** `tools/check.sh --shot` rendert eine Szene. Zustände, die man nur durch Spielen erreicht, stellen die
Capture-Rezepte in `game/tests/capture_recipes.gd` her (02_TECH §11.3). Beispiele:

```bash
T=prime-time-dungeon/tools/check.sh
GODOT=… $T --shot res://scenes/title/title.tscn shot.png 120 1280x720
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=explore_platform   # 03 (sewer: 04)
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=prompt_cellar      # 05
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=bigmap             # 06
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=pause_equipment    # 07
E=res://scenes/exploration/exploration.tscn                                # Echtzeitkampf mit den echten Daten
GODOT=… $T --shot $E shot.png 30 1280x720 --recipe=rt_r4_regular                                           # 54
GODOT=… $T --shot $E shot.png 30 1280x720 --recipe=rt_r4_showboss                                          # 55
GODOT=… $T --shot $E shot.png 30 1280x720 --recipe=rt_r4_hausmeister                                       # 56
GODOT=… $T --shot $E shot.png 30 1280x720 --recipe=rt_r4_queen                                             # 57
GODOT=… $T --shot $E shot.png 30 1280x720 --recipe=rt_r4_results                                           # 58
GODOT=… $T --shot $E shot.png 30 2400x1080 --touch --recipe=rt_r4_regular                                  # 59
GODOT=… $T --shot $E shot.png 5 1280x720 --recipe=rt_hint                                                  # 60
GODOT=… $T --shot $E shot.png 5 1280x720 --recipe=rt_credits                                               # 61
GODOT=… $T --shot $E shot.png 5 1280x720 --recipe=pull_target_platform                                     # 62
GODOT=… $T --shot $E shot.png 5 2400x1080 --touch --recipe=pull_target_platform                            # 63
GODOT=… $T --shot $E shot.png 5 1280x720 --recipe=pull_bark_sewer                                          # 64
GODOT=… $T --shot $E shot.png 20 1280x720 --season-floor=2 --recipe=season_q1          # 72 (73: Etage 3, 74: Etage 4)
GODOT=… $T --shot $E shot.png 20 1280x720 --season-floor=6 --recipe=season_fb                              # 75
GODOT=… $T --shot $E shot.png 20 1280x720 --season-floor=2 --recipe=season_door                            # 76
GODOT=… $T --shot $E shot.png 20 1280x720 --season-floor=6 --recipe=season_map                             # 77
GODOT=… $T --shot $E shot.png 20 2400x1080 --touch --season-floor=4 --recipe=season_q1                     # 78
GODOT=… $T --shot $E shot.png 40 1280x720 --season-floor=3 --recipe=sleep_logout_corridor                 # 79
GODOT=… $T --shot $E shot.png 40 2400x1080 --touch --season-floor=3 --recipe=sleep_logout_corridor        # 84
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 40 1280x720 --recipe=sleep_logout_safe     # 80
W=res://scenes/ui/wake_summary.tscn                                        # 09 ST1-G: der Login nach dem Schlaf
GODOT=… $T --shot $W shot.png 40 1280x720 --recipe=sleep_wake                  # 81 (82: sleep_days, 83: sleep_question)
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_mopsula           # 13
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_lootbox_open      # 14
GODOT=… $T --shot res://scenes/ui/event_lobby.tscn shot.png 120 1280x720                                     # 15
GODOT=… $T --shot res://art/gallery/character_gallery.tscn shot.png 120 1280x720                             # 16
GODOT=… $T --shot res://art/gallery/vfx_gallery.tscn shot.png 120 1280x720                                   # 17
GODOT=… $T --shot res://scenes/ui/show_overlay.tscn shot.png 120 1280x720                                    # Overlay
GODOT=… $T --shot res://scenes/title/hero_select.tscn shot.png 60 1280x720                                  # 19
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=bark_platform      # 20
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_hero_switch       # 21
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=secret_wall        # 23 (24: secret_open, 25: secret_note)
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1600x720 --touch --recipe=safe_hero_talents  # 26
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 5 1280x720 --recipe=pause_show         # 27
GODOT=… $T --shot res://scenes/safe_room/safe_room.tscn shot.png 5 1280x720 --recipe=safe_talent_show       # Talent-Show
C=res://scenes/title/persona_casting.tscn                                  # 08 K1: Casting (Seite, Overlay, Beispiel-Persona)
GODOT=… $T --shot $C shot.png 60 1280x720 --params='{"page":2,"open":"origin","demo":true}'               # 31
GODOT=… $T --shot $C shot.png 60 2400x1080 --params='{"page":3,"demo":true}' --touch                      # 37
GODOT=… $T --shot $C shot.png 60 1280x720 --params='{"page":1,"open":"keyboard","demo":true}' --recipe=casting_accents  # 34
GODOT=… $T --shot res://scenes/exploration/exploration.tscn shot.png 30 1280x720 --recipe=pause_card      # 41
GODOT=… $T --shot res://scenes/title/intro.tscn shot.png 20 1280x720 --recipe=intro_card                 # 42
S=res://scenes/safe_room/safe_room.tscn                                    # 09 ST1-D: der Lauf wird eine Staffel
GODOT=… $T --shot $S shot.png 30 1280x720 --recipe=season_talent_show                                     # 65
GODOT=… $T --shot $S shot.png 30 1280x720 --recipe=season_talent_tree                                     # 66
GODOT=… $T --shot $S shot.png 30 1280x720 --recipe=season_party                                           # 67
GODOT=… $T --shot $S shot.png 30 1280x720 --recipe=season_skills                                          # 68
GODOT=… $T --shot $S shot.png 30 1280x720 --recipe=season_preview                                         # 69
GODOT=… $T --shot $S shot.png 30 2400x1080 --touch --recipe=season_talent_tree                           # 70 (71: season_talent_show)
R="--season-floor=3"                                                       # Recall: Basis-Staffel auf Etage 3
GODOT=… $T --shot $S shot.png 30 1280x720 $R --recipe=recall_species        # 90 (91–95: recall_class, recall_confirm,
                                                                           #  recall_judged, recall_mopsula, recall_done)
GODOT=… $T --shot $S shot.png 2 1280x720 $R --recipe=safe_recall                                          # 96
GODOT=… $T --shot $S shot.png 30 1280x720 $R --recipe=recall_party                                        # 97
GODOT=… $T --shot $S shot.png 30 2400x1080 --touch $R --recipe=recall_species                  # 98 (99: recall_class)
```

## 11. Nächste Schritte

Nach dem Phasenplan in 04 Kap. 3.4 fehlen für den Abschluss von Phase 2 (Meilenstein M-P2, Go/No-Go):

1. **15 externe Playtests** mit der Zielgruppe (nicht Freunde oder Familie). Zielwerte: ≥ 70 % erreichen den Hausmeister,
   Median-Spielzeit 22–28 min, ≥ 60 % „würde weiterspielen“, ≥ 50 % nennen ungefragt Show, M.O.D. oder Mopsula,
   0 Abstürze in 20 Durchläufen.
2. **Performance-Budgets auf echter Hardware** prüfen: PC mit iGPU und ein Android-Mittelklassegerät (02_TECH §12.1).
3. **Distanz-Review** (04 Kap. 2.3, Entscheidung E2) und **Titel-Entscheidung** mit Markenrecherche (Kap. 2.5, E3).
4. **Gameplay-Video** (2–3 min) und **Android-Debug-APK** für den Slice-Build.
5. **Sichtbare Ausrüstung** an den Figuren (03_ART Antrag A8).
6. **Plattform-Matrix für SHOWRUN S0** messen (05 Kap. 2): gleicher Seed und gleiche Befehle ergeben auf allen Zielplattformen
   denselben `StateHash`.
7. Danach **Phase 3 (Pre-Production)**: Art-Upgrade mit glTF-Pipeline, Steam-Seite, Finanzierung, Team (04 Kap. 3.5).
