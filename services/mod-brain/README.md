# mod-brain — der KI-Admin hinter „M.O.D. live“

Referenzdienst für **docs/06 Kap. 5** (Paket D, Stufe S0/S1): M.O.D. kommentiert live mit Claude und schlägt
höchstens **einen** kleinen Regie-Eingriff („Twist“) aus einem festen Katalog vor. Das Spiel bleibt der Chef:
jeder Vorschlag läuft im Spiel noch einmal durch `TwistApplier` (dieselben Regeln, deterministisch, aufgezeichnet),
jede Zeile noch einmal durch denselben Inhaltsfilter.

**Standard ist AUS.** Ohne diesen Dienst spricht die geschriebene M.O.D. wie immer, und ab Etage 2 greift die
Offline-**Regie** (`RegieDirector`) ein — ohne KI, ohne Netz, ohne Kosten. „M.O.D. live“ ersetzt nur zwei Schichten:
*welcher* Twist und *welcher* Spruch.

```
Spiel (hält NIE einen API-Schlüssel)                       mod-brain (dieser Dienst)
ModLiveLink ── alle 40 s Lauf-Uhr ──► POST /v1/mod/turn ─► Token prüfen ─► Konto-Deckel ─► Schema/IDs prüfen
  ModLiveSummary: nur IDs + Zahlen                         ─► Claude (Structured Output, gecachter System-Prompt)
  ◄── {lines[0–3], twist|null, mood} ◄────────────────────── ◄── Sicherheitsfilter ◄── Twist-Regeln (wie im Spiel)
Show.say_external (Filter, nur in Sendepausen, Label „KI live“)   Fehler/Timeout/Refusal ⇒ leere Runde (Skript spricht)
Game.apply_twist (nur Modus „Kommentar + Regie“, aufgezeichnet)
```

## Start (lokal)

```bash
cd services/mod-brain
python3 -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
python -m pytest -q                     # alle Tests mit gemocktem Client — es wird nie die echte API gerufen

# Demo ohne Schlüssel und ohne Kosten (feste Beispielzeilen, kein Claude-Aufruf):
MOD_BRAIN_DEMO=1 MOD_BRAIN_DEV_MODE=1 uvicorn mod_brain.app:app --port 8787

# Echt (Schlüssel aus dem Secret-Store bzw. `ant auth login`, NIE ins Repo):
export ANTHROPIC_API_KEY=…              # oder ANTHROPIC_AUTH_TOKEN / ant-Profil
export MOD_BRAIN_TOKEN_SECRET=…         # aus dem Secret-Store
MOD_BRAIN_DEV_MODE=1 uvicorn mod_brain.app:app --port 8787
```

Spiel verbinden (nur Debug-Builds): `godot --path prime-time-dungeon/game -- --mod-live-url=http://127.0.0.1:8787`
(optional `--mod-live=lines_twists` für „Kommentar + Regie“). Danach erscheint in den Optionen die Zeile
„M.O.D. live (Beta)“: **Aus · Kommentar · Kommentar + Regie**. Im Debug-Overlay (F3) zeigt „M.O.D.live“ Status und
Runden; F6 löst einen Test-Twist aus, F7 eine Test-Zeile über denselben Weg wie die KI.

## Konfiguration (Umgebung)

| Variable | Standard | Bedeutung |
|---|---|---|
| `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` | – | liest das offizielle SDK selbst (alternativ `ant auth login`); **nie im Repo, nie im Spiel** |
| `MOD_BRAIN_MODEL` | `claude-opus-5-5` | Modell beider Routen |
| `MOD_BRAIN_MODEL_LINES` / `MOD_BRAIN_MODEL_DIRECTOR` | – | Modell je Route (`lines` = Kampagne, `director` = Live-Sendung) |
| `MOD_BRAIN_EFFORT` / `MOD_BRAIN_EFFORT_DIRECTOR` | `low` / `low` | `output_config.effort` (Opus 5.5 denkt immer adaptiv; Standard dort wäre `medium`) |
| `MOD_BRAIN_FALLBACKS` | `1` | serverseitige Fallbacks `fallbacks: "default"` (Beta `server-side-fallback-2026-07-01`; nicht bei Haiku 5.5) |
| `MOD_BRAIN_TOKEN_SECRET` | – | HMAC-Schlüssel der Sitzungs-Token (Pflicht; im Dev-Modus zufällig je Prozess) |
| `MOD_BRAIN_DEV_MODE` | `0` | nimmt Plattform-Tickets `dev` an — nur von `127.0.0.1`/`::1` |
| `MOD_BRAIN_MONTHLY_BUDGET_USD` | `50` | Monatsbudget; 80 % Warnung, 100 % automatischer Not-Aus (nur leere Runden) |
| `MOD_BRAIN_RATE_PER_HOUR` / `_PER_DAY` / `MOD_BRAIN_BURST_PER_MIN` | 90 / 400 / 3 | Deckel je Konto-Pseudonym |
| `MOD_BRAIN_KILL_SWITCH` | `0` | Not-Aus: jede Runde leer |
| `MOD_BRAIN_DEMO` | `0` | feste Offline-Zeilen statt Claude (Entwicklung, Smoke-Test) |
| `MOD_BRAIN_DATA_DIR` | `../../prime-time-dungeon/game/data` | Spieldaten: Twist-Katalog, IDs, Filterlisten |
| `MOD_BRAIN_COST_LOG` | – | JSONL-Kostenlog je Runde (`run_ref`, Konto-Pseudonym, Tokens, USD) |

## Endpunkte

| Methode | Pfad | |
|---|---|---|
| GET | `/healthz` | `{"ok", "kill_switch", "budget_exhausted"}` |
| POST | `/v1/auth/token` | `{"platform", "ticket", "run_ref"}` → `{"token", "expires_in"}` — nur gegen Plattform-Auth (S1: `dev` im Dev-Modus; Steam-Ticket-Prüfung **[zu prüfen]**) |
| POST | `/v1/mod/turn` | Bearer-Token, Anfrage ≤ 8 KB (Schema 1, docs/06 §5.4) → `{"lines", "twist", "mood"}` |
| POST | `/v1/mod/director` | wie oben, Route `director` (eine Regie je Live-Sendung, 1 Retry, 8 s) |

Fehler: 400 (Schema, unbekannte ID, Freitext), 401 (Token), 413 (> 8 KB), 429 (Deckel). Ein scheiternder
Claude-Aufruf ist **kein** Fehler, sondern eine leere Runde (200).

## Claude-Nutzung

- Offizielles Python-SDK `anthropic` (≥ 1.13, `pyproject.toml`), Aufruf über `messages.parse(...,
  output_format=ModTurnOut)` → Structured Output (`output_config.format`, JSON-Schema mit
  `additionalProperties: false`), `thinking: {"type": "adaptive"}`, `output_config.effort = "low"`.
- **Prompt Caching:** System-Prompt = Persona + Tonregeln + Beispielzeilen + harte Regeln + Twist-Katalog, einmal je
  Prozess gebaut, **byte-identisch** (sortiertes JSON, keine Zeitstempel, nichts pro Lauf), `cache_control:
  {"type": "ephemeral"}` am letzten System-Block. Alles Variable steht in der einen User-Nachricht der Runde.
  Kontrolle: `usage.cache_read_input_tokens` (im Kostenlog).
- **Zustandslos:** je Runde 1 System + 1 User-Nachricht; Kontinuität über den serverseitigen Zeilenpuffer je `run_ref`.
- Route `lines`: Deadline 4 s, `max_retries=0` (sicher unter dem Client-Timeout von 6 s). `stop_reason == "refusal"`,
  Timeout, Netzfehler, ungültige Ausgabe ⇒ leere Runde.

## Sicherheit & Datenschutz

- **Kein Client-String erreicht den Prompt.** Die Anfrage enthält nur Zahlen in Bereichen und IDs/Enums, die gegen
  die Spieldaten geprüft werden (Gegner, Erfolge, Twists, Party, Ereignistypen); Unbekanntes ⇒ 400. Frühere Zeilen
  kommen nur aus dem **eigenen** Ringpuffer (letzte 6 je `run_ref`, TTL 2 h); der Client schickt höchstens deren IDs.
- **Kein Spielername** (nur der Platzhalter `{name}`, den das Spiel einsetzt), keine Konto-/Geräte-/IP-Daten im
  Prompt; `run_ref` ist ein Zufallspseudonym je Lauf, Konten erscheinen nur als HMAC-Pseudonym.
- **Inhaltsfilter** (`safety.py` = `ModLineFilter` im Spiel, gemeinsame Testfälle `tests/fixtures/live/
  line_filter_cases.json`): Länge ≤ 110, nur `{name}`, keine URLs/Ziffernfolgen, Sperrlisten Politik/Sexuelles/
  Beleidigungen/Gewalt/reale Marken, Echtgeld/Spenden, **Kaufdruck nur bei Ko-Vorkommen** (Dringlichkeit + Kaufbezug:
  „Schnellschnitt!“ bleibt, „Schnell, Sponsor-Fenster!“ fliegt), Sprachprüfung Deutsch. Fehlalarmquote auf den
  geschriebenen M.O.D.-Zeilen < 1 % (Test). Die Wortlisten in `game/data/mod_filter.json` sind ein Startbestand; die
  Produktivlisten pflegt die Moderation **[zu prüfen]**.
- **Twists:** nur aus `data/twists.json` (20 Einträge, 11 mit Wirkung im Slice), Parameter in festen Grenzen,
  Schnittmenge aus Katalog ∩ Spiel-Hinweis ∩ Regeln (nie auf Etage 1, nie im Kampf, ≤ 1 „scharfer“ je Etage, nie bei
  schwacher Party / knappem Timer), höchstens ein Vorschlag je 90 s. Das Spiel prüft identisch nach
  (`tests/fixtures/live/twist_cases.json`, GDScript **und** pytest).
- Sichtbarkeit: KI-Zeilen tragen im Spiel das Label „M.O.D. · KI live“ (Offenlegung, z. B. Steam-Regeln für live
  generierte Inhalte **[zu prüfen]**).

## Kosten **[zu prüfen]**

Annahmen je Runde: ~4 000 System-Tokens aus dem Cache, ~900 variable Eingabe-, ~350 Ausgabe-Tokens (inkl. Denken bei
`low`); **≤ 90 Runden/h** (Takt 40 s = Obergrenze, kein Mittelwert). Preise Stand Skill-Referenz 2026-10-06:

| Modell | Eingabe / Ausgabe / Cache-Lesen je 1 M | ≈ je Runde | ≈ je Spielstunde |
|---|---|---|---|
| `claude-opus-5-5` (Standard) | $4 / $20 / $0.20 | ≈ $0.011 | ≈ $1.0–1.2 |
| `claude-sonnet-5-5` | $2 / $10 / $0.20 | ≈ $0.006 | ≈ $0.55–0.65 |
| `claude-haiku-5-5` | $0.10 / $0.50 / ≈ $0.01 | ≈ $0.0003 | ≈ $0.03 |

Einordnung (docs/06 §5.11): Für die Kampagne pro Spieler:in ist Opus dauerhaft zu teuer — dort bleibt die Offline-Regie
Standard, „M.O.D. live“ ist Opt-in (Beta, Streamer:innen), realistisch mit Sonnet/Haiku auf der Route `lines`.
Für **Live-Sendungen** reicht **eine** KI-Regie je Sendung (Opus ≈ $2–3 pro 90 Minuten, unabhängig von der
Zuschauerzahl). Die Entscheidung fällt im S1-Modellvergleich:

```bash
python tools/model_eval.py --rounds 100 --models claude-opus-5-5 claude-sonnet-5-5 claude-haiku-5-5
```

(ruft die **echte** API, nicht im CI; misst Latenz Median/p95, Kosten je Runde/Stunde, Filtertreffer und schreibt die
Zeilen für die blinde Bewertung der Humor-Redaktion.)

## Dateien

`mod_brain/app.py` (HTTP), `brain.py` (eine Runde), `persona.py` (System-Prompt), `schema.py` (Protokoll),
`safety.py` (Filter), `catalog.py` (Spieldaten + Twist-Regeln), `rate_limit.py`, `budget.py`, `auth.py`,
`line_store.py`, `config.py`, `demo.py`; `tests/` (pytest, gemockter Client); `tools/model_eval.py`.
