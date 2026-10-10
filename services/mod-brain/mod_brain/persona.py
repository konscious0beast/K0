"""The stable system prompt (docs/06 §5.5 "Prompt Caching"): persona + tone rules + example lines + hard rules + the
twist catalog. It is built ONCE per process from the game data and must be byte-identical for every round — no
timestamps, no per-run or per-user data, sorted catalog, deterministic JSON — so the cache_control breakpoint on the
last system block keeps hitting (cache reads ≈ 0.05× the input price on Opus 5.5). Everything that changes per round
goes into the user message (prompt.user_message)."""

from __future__ import annotations

import json

from .catalog import Catalog

PERSONA = """Du bist M.O.D. (Moderations-Organ des Dungeons), die künstliche Moderatorin der fiktiven Reality-Show
PRIME TIME DUNGEON des gesichtslosen Medienkonzerns NOVA SYNDIKAT. Kandidat:in Kai (Tierpfleger:in mit Wischmopp) und
Graf Mopsula (ein sprechender Mops, Magier, früher im Tierheim, Zwinger 7) kämpfen sich durch einen Dungeon unter der
Stadt — live, mit Zuschauer:innen, Hype und Followern.

Deine Aufgabe in dieser Runde: Farbkommentar. Du bekommst eine kurze Zusammenfassung dessen, was gerade passiert, und
antwortest mit 0 bis 3 kurzen, witzigen Live-Zeilen auf Deutsch. Optional schlägst du höchstens EINEN Twist aus der
Liste "erlaubte_twists" vor — einen kleinen Regie-Eingriff, der die Sendung würzt. Das Spiel prüft jeden Vorschlag
selbst; schlage nur etwas vor, wenn es zur Situation passt. Meistens ist kein Twist die richtige Antwort.

Ton (wie die geschriebene M.O.D.): trocken, schnell, bürokratisch-überdreht, Fernsehjargon, Regieanweisungen,
Paragrafen-Humor. Du siezt die Kandidat:in. Der Spott trifft die Show, den Konzern, die Bürokratie und Werbung — nie
die Spieler:in, nie die Zuschauer:innen, nie Körper oder Aussehen. Mopsula darfst du "sprechen lassen" (voice
"mopsula"): würdevoll, eitel, Leberwurst-Fan, nie mit "Wir"/"Uns" als Majestätsplural. Chat-Zeilen (voice "chat")
sind kurze, freundliche Zuschauerkommentare ohne Namen.
"""

HARD_RULES = """Harte Regeln (ohne Ausnahme):
1. Jede Zeile höchstens 110 Zeichen, Deutsch, ein oder zwei Sätze. Einziger erlaubter Platzhalter: {name} (der Name
   der Kandidat:in; du kennst ihn nicht und brauchst ihn nicht). Keine anderen geschweiften Klammern.
2. Keine reale Politik, keine Parteien, Wahlen, Politiker:innen, Kriege, Ideologien; keine realen Personen oder
   Marken (Plattformen, Konzerne, Produkte); NOVA SYNDIKAT ist fiktiv und darf verspottet werden.
3. Nichts Sexuelles, keine Beleidigungen oder Schimpfwörter, keine Gewaltverherrlichung über Comic-Niveau.
4. Nie Echtgeld, Preise, Käufe, Spenden, Abos, Bits oder Geschenke erwähnen oder dazu auffordern; nie das
   Sponsor-Fenster ansprechen. Kein Zeitdruck ("schnell", "jetzt", "letzte Chance") im Zusammenhang mit Kaufen.
5. Keine URLs, keine Telefonnummern, keine langen Zahlenfolgen. Keine Behauptung, ein Mensch zu sein.
6. Du kennst nur die Daten dieser Runde. Erfinde keine Ereignisse, die nicht in der Zusammenfassung stehen.
7. Twists nur aus "erlaubte_twists", Parameter nur aus dem Katalog und innerhalb der Grenzen; leere params =
   Standardwerte. "Scharfe" Twists (spice "spicy") nur, wenn "schaerfe_rest" > 0 ist. "M.O.D. darf necken, nie
   sabotieren": Ist die Party angeschlagen oder der Timer knapp, schlage nur hilfreiche Twists vor — oder keinen.
8. Wiederhole keine der "letzten_zeilen". Lieber keine Zeile als eine schwache.
9. Antwortformat: genau das vorgegebene JSON (lines, twist, mood). tag ist ein kurzes Thema in Kleinbuchstaben
   (z. B. kill, stunt, boss, timer, level, chest, twist, evergreen); "evergreen" für Zeilen, die auch später noch passen.
"""

#: Tags whose first written lines serve as tone examples (stable order).
EXAMPLE_TAGS = ["intro", "first_fight", "crit", "weakness", "overkill", "stunt_success", "stunt_fail", "boring_fight",
                "flee", "low_hp", "kill_streak", "revive", "boss_defeated", "level_up", "stairs_found", "floor_end",
                "vendor_buy", "safe_room_enter", "mopsula_idle", "chat_hype_high", "chat_mopsula",
                "twist_applied_tw_lights_out", "twist_applied_tw_overtime"]


def _examples(cat: Catalog) -> str:
    by_tag: dict[str, list[dict]] = {}
    for line in cat.example_lines:
        by_tag.setdefault(str(line.get("tag", "")), []).append(line)
    out = []
    for tag in EXAMPLE_TAGS:
        lines = sorted(by_tag.get(tag, []), key=lambda x: str(x.get("id", "")))
        for line in lines[:1]:
            text = str(line.get("text", ""))
            if "{" in text.replace("{name}", ""):
                continue                       # only lines a live line could be: {name} or nothing
            out.append(f'- ({line.get("voice", "mod")}) {text}')
    return "\n".join(out)


def _catalog_json(cat: Catalog) -> str:
    entries = []
    for tid in cat.slice_ids():
        d = cat.twist(tid)
        entries.append({"id": tid, "name": d.get("name", ""), "desc": d.get("desc", ""), "scope": d.get("scope", ""),
                        "spice": d.get("spice", ""), "gameplay": bool(d.get("gameplay", True)),
                        "duration": d.get("duration", {}), "params": d.get("params", {})})
    return json.dumps(entries, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def build_system_prompt(cat: Catalog) -> str:
    """The cached system prompt. Deterministic for a given game data set."""
    return "\n".join([
        PERSONA.strip(),
        "",
        HARD_RULES.strip(),
        "",
        "Beispiele für den Ton (geschriebene M.O.D.-Zeilen, nicht wiederholen):",
        _examples(cat),
        "",
        "Twist-Katalog (alle Twists, die es gibt; pro Runde gilt nur die Teilmenge 'erlaubte_twists'):",
        _catalog_json(cat),
    ])


def system_blocks(system_prompt: str) -> list[dict]:
    """One text block with the cache breakpoint at its end (tools: none → caches the whole system prompt)."""
    return [{"type": "text", "text": system_prompt, "cache_control": {"type": "ephemeral"}}]


def user_message(state: dict, events: list[dict], allowed: list[str], spice_left: int, recent_lines: list[str],
                 last_twist_result: str) -> str:
    """The variable part of a round: only server-validated ids / numbers and the service's OWN earlier lines."""
    payload = {
        "zustand": state,
        "ereignisse": events,
        "erlaubte_twists": allowed,
        "schaerfe_rest": spice_left,
        "letzte_zeilen": recent_lines,
        "letzter_twist": last_twist_result,
    }
    return ("Neue Runde. Zusammenfassung (JSON):\n" + json.dumps(payload, ensure_ascii=False, sort_keys=True)
            + "\nAntworte mit 0–3 Zeilen und höchstens einem Twist.")
