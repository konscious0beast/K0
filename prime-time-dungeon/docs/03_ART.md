# PRIME TIME DUNGEON — Art Direction & Rendering-Pipeline (Option B)

> Verbindlich für alles Sichtbare im Vertical Slice. Grundlage: `00_BRIEF.md` (Option B = stilisiertes Low-Poly mit
> Toon-Shading). Code-Verträge (Dateinamen, Klassen, Signaturen, Uniform-Namen, Animationsnamen) stehen in
> **`02_TECH.md` §1.5 und §8** — dieses Dokument füllt sie mit Aussehen, Zahlen und verifiziertem Shader-Code.
> Alles wird **prozedural aus `PrimitiveMesh`es + Shadern** gebaut. Keine Texturen, keine externen Assets.
> Blender-glTF ersetzt später die Platzhalter **1:1** (Kap. 10).

**Verifikation (2026-10-07, Godot 4.7.2-stable):** Alle Shader und `MeshUtil` aus diesem Dokument wurden in einem
Wegwerf-Projekt (mit `untyped_declaration = 2`) gebaut und unter `xvfb-run` gerendert — **Compatibility**
(`--rendering-method gl_compatibility --rendering-driver opengl3`, Mesa llvmpipe) und **Mobile**
(`--rendering-method mobile --rendering-driver vulkan`, Mesa lavapipe). Ergebnis: 0 Shader-/Script-Fehler, 0 Warnungen,
Bilder in beiden Renderern deckungsgleich (Graustufen-Probe `#808080` vs. `#848484`, ≤ 3 %). Dabei gefundene und hier eingearbeitete Engine-Fakten:

| # | Befund (getestet) | Konsequenz |
|---|---|---|
| F1 | **Vertex-Farben:** Dieselben Mesh-Daten (Farbe linear gespeichert, 0.216) ergaben Compatibility `#363636`, Mobile `#848484` — Compatibility linearisiert `COLOR` selbst, Mobile nicht. Gilt auch für MultiMesh-Instanzfarben. | Mesh-Farben werden **sRGB** gespeichert; Shader konvertieren nur außerhalb Compatibility (`#if CURRENT_RENDERER == RENDERER_COMPATIBILITY`, Preprocessor-Define existiert in 4.7). |
| F2 | **Instance-Uniforms über `next_pass`:** gleiche Namen reichen nicht — die **Deklarationsreihenfolge** muss in beiden Shadern identisch sein, sonst Warnung „different indices … only the first one will display correctly“. | `toon` und `toon_outline` deklarieren `flash_amount, flash_color, highlight, dissolve` in genau dieser Reihenfolge. |
| F3 | glTF-Export/-Import von Godot schreibt/liest `COLOR_0` **ohne** Farbraumwandlung; Blender exportiert `COLOR_0` linear (glTF-Spezifikation). | Post-Import wandelt Vertex-Farben `linear_to_srgb()` (Kap. 10). |
| F4 | Statische Funktion namens `tr()` kollidiert mit `Object.tr()` (Parse-Fehler). | Hilfsfunktion heißt `MeshUtil.xform()`. |
| F5 | Große Boden-Boxen, die selbst Schatten werfen, versinken in Compatibility im Eigenschatten. | Raumgeometrie `cast_shadow = OFF` (wie 02_TECH §8.5). |

---

## Inhalt

1. Visuelle Säulen & Referenzen
2. Color Script (Master-, Zonen-, UI-Paletten)
3. Shader — verifizierter Code
4. Environment & Licht
5. Figuren aus Primitiven (Archetypen, Props, Besetzung, Animation)
6. Umgebungs-Kit
7. VFX
8. Kamerasprache
9. UI-Art-Direction (TV-Broadcast)
10. Asset-Upgrade-Pfad Blender → glTF
11. Performance-Budget (Mobile)
12. Abweichungen & Anträge an andere Dokumente

---

## 1. Visuelle Säulen & Referenzen

| # | Säule | Regel (messbar) |
|---|---|---|
| 1 | **Chibi-Proportionen** | Menschen: Kopf = **1/3 der Gesamthöhe** (Kai 1.75 m, Kopf-Ø 0.56 m + Haar). Tiere/Monster: Kopf ≥ 1/4 der Körperlänge. Hände/Füße 1.3× „realistisch“. Augen groß, auf 45–50 % Kopfhöhe. |
| 2 | **Dicke, lesbare Silhouetten** | Jede Figur ist als schwarze Silhouette auf 48 px Höhe (720p) erkennbar. Max. 3 Hauptformen pro Figur. Keine Teile dünner als 0.05 m außer Accessoires. |
| 3 | **Show-Licht vs. Dungeon-Schmutz** | Figuren: sauber, gesättigt (≥ 60 %), Rim-Light, Outline. Umgebung: entsättigt (≤ 45 %), dunkel, Schmutz + Schraffur im Schatten, Nebel. Ausnahme: Neon/Signale. |
| 4 | **Outline = lebendig oder interaktiv** | Inverted-Hull nur für Figuren, Gegner, Truhen, Safe-Room-Tür, Treppe, Automat, Speicher-Terminal. Wände/Böden **nie** (02_TECH: Umgebung ohne Outline). |
| 5 | **Die Show ist das UI** | TV-Übertragung: LIVE-Badge, Zuschauerzähler, Chat-Ticker, Sponsor-Bauchbinde; 12°-Schrägschnitte, Magenta/Gold/Cyan auf Tinte. |
| 6 | **Licht erzählt** | Natrium-Orange = Weg, Notausgang-Grün = Safe Room/Treppe, Magenta = NOVA/Show, Rot = Gefahr/Boss — in allen Zonen gleich. |

**Referenzen (beschreiben, nicht kopieren):** FF10/FF12-Gefühl = theatralische Kampfkamera mit Fahrten, sichtbare Zugreihenfolge,
warme Key-Lights gegen kühle, farbige Schatten. Toon = 3-stufige Cel-Ramp mit **violettem** Schatten, harte Rim-Kante, kleine runde
Glanzpunkte wie Vinyl-Spielzeug. Dungeon = verlassene U-Bahn, nasse Fliesen in Petrol, Natriumdampf, Graffiti-Magenta, Kanal-Grünstich.
TV = Live-Sport-Grafik + Reality-Bauchbinden + übertrieben fröhliche Teleshopping-Optik.

---

## 2. Color Script

### 2.1 Master-Palette (`Palette`, sRGB)

Die ersten sieben Werte sind die Konstanten aus 02_TECH §8.2 (unverändert). Die übrigen sind Art-Erweiterungen für `Palette`.

| Konstante | Hex | Verwendung |
|---|---|---|
| `INK` | `#140D1C` | Outline, UI-Dunkel, Übergangs-Schwarz, `default_clear_color`-Nähe |
| `NOVA_MAGENTA` | `#FF2E88` | NOVA SYNDIKAT, Show, Hype, Swirl-Splitter, Fokus-Akzent |
| `NOVA_CYAN` | `#22D3EE` | M.O.D., Hologramme, UI-Rahmen, Safe-Room-Technik |
| `HYPE_GOLD` | `#FFC93C` | Belohnung, Level-Up, Treppen-Licht, Highlight (Zielwahl) |
| `DANGER` | `#FF4D4D` | Gefahr, niedrige HP, Boss-Phase |
| `HEAL` | `#4ADE80` | Heilung, HP-Leiste |
| `MANA` | `#60A5FA` | MP |
| `LIVE_RED` | `#FF3B30` | LIVE-Badge, Signal-Rot |
| `SODIUM` | `#FF9A2E` | Natriumdampflampen |
| `EXIT_GREEN` | `#2BD66B` | Notausgang, Safe Room |
| `SHADE` | `#5A4E8C` | Toon-Schattentönung Figuren |
| `PAPER` | `#F5F0E6` | Weiß im Spiel und UI-Text (reines `#FFFFFF` nur für Hit-Flash) |
| `PANEL` | `#140D1C` @ 88 % | UI-Panels |

**Elementfarben** (VFX, Icons, Kanten beim Dissolve): `physical #F2EBDD`, `fire #FF6A2B` (Kern `#FFE08A`), `ice #7FD8FF` (Kern `#E6F8FF`),
`shock #F5E642` (Bogen `#9FE8FF`), `poison #7CC242`, `none`/Heilung `#6BFFB0`.
**Status** (GDD 3.9): poison `#7CC242`, stun `#F5D90A`, slow `#5B8DEF`, haste `#FF7A1A`, guard `#9AA7B8`, taunt `#E8455A`.
**Rarität** (GDD 9.4): common `#BFC5CC`, rare `#4AA8FF`, epic `#B05CFF`. **Lootbox-Tier:** bronze `#CD7F32`, silver `#C0C8D2`, gold `#FFC83D`, fan `#FF5FA2`.

### 2.2 Theme `metro` (Etage 1 „Die Unterstadt“) — Zonen-Paletten

Schlüssel = `FloorDef.palette`/`Palette.theme_palette()` (`floor, wall, accent, light, fog, ambient`) + Art-Schlüssel
(`shade` = `shade_color` der Umgebung, `rim` = Rim der Figuren in dieser Zone, `grout`, `key` = Sonnenfarbe, `neon2` = zweite Akzentfarbe).
Zuordnung GDD: U-Bahn-Gleise = Zone A `zone_platform` + D `zone_track9`, Kanalisation = B `zone_sewer`, Keller-Quartier = C `zone_cellar`.

| Zone / Bereich | floor | wall | accent | light (Raum-Omni) | fog | ambient | shade | rim | grout | key | neon2 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **A Bahnsteig** (Theme-Default `metro`) | `#3A3F4B` | `#1F5F66` | `#FF2E88` | `#FFD59E` | `#1A1430` | `#2A2440` | `#4A3E78` | `#FFD9A8` | `#1A1E24` | `#FFB866` | `#2BD66B` |
| **B Kanalisation** | `#24302C` | `#3B4A3F` | `#7CC242` | `#B8F0C8` | `#12302A` | `#1E3530` | `#2F4F5C` | `#C8FFD0` | `#18201C` | `#9FE0C0` | `#F5D90A` |
| **C Kellergewölbe** | `#3A2C24` | `#5A4A3E` | `#E23E9B` | `#FFD27A` | `#2A1A12` | `#3A2A22` | `#4A2E3E` | `#FFE2B8` | `#241A14` | `#FFC98A` | `#FF3B30` |
| **D Gleis 9** | `#2A2530` | `#2E2A38` | `#FF3B30` | `#C9B8FF` | `#1E1530` | `#261E38` | `#3E2E66` | `#C9B8FF` | `#16121C` | `#C9B8FF` | `#2BD66B` |
| **Safe Room** (alle drei) | `#4A3A40` | `#6A5A60` | `#FFC93C` | `#FFE2B8` | — | `#5A4860` | `#7A5E86` | `#FFF0D8` | `#2E242A` | `#FFE2B8` | `#22D3EE` |
| **Boss Hausmeister-Büro** | `#3C3A30` | `#5A5E50` | `#E8F0D8` | `#E8F0D8` | `#20201A` | `#34322A` | `#3A3A2A` | `#F0FFE0` (P3 `#FF6A5A`) | `#22201A` | `#E8F0D8` | `#FF3B30` |
| **Boss Thronsaal** | `#1E1A24` | `#241E30` | `#9A6BFF` | `#FFD27A` | `#1A1230` | `#221A38` | `#2A1F50` | `#9A6BFF` | `#120E18` | `#9A6BFF` | `#FFF2C8` |

Bahnsteigkante/Warnband überall `#F2C230`. Graffiti `#E23E9B`. Schienen `#A8B0B8`, Schwellen `#4A3A30`.

### 2.3 Theme `mall` (Etage 2, Stub „Passage Ewiger Rabatt“)

| floor | wall | accent | light | fog | ambient | shade | rim | grout | key | neon2 |
|---|---|---|---|---|---|---|---|---|---|---|
| `#9A9080` (entsättigtes Fliesen-Beige `#D9CBB0`) | `#2A3A44` | `#FF4FA0` | `#FFF0F5` | `#2A1A2A` | `#3A2A3A` | `#5A3A6A` | `#FFE0F0` | `#6E665A` | `#FFF0F5` | `#4FE6FF` (+ Schimmel `#C8E04A`) |

### 2.4 UI-Palette

| Token | Wert | Verwendung |
|---|---|---|
Basis sind die Konstanten von `UiTheme` (02_TECH §3.9); Art ergänzt nur LIVE/Party/Gegner/Disabled.

| Token | Wert | Verwendung |
|---|---|---|
| `C_BG` / `C_PANEL` | `#140D1C` / `#1F1430` @ 90 % | Hintergrund / Panels |
| `C_TEXT` / `C_TEXT_DIM` | `#F5F0FF` / `#B3A7C9` | Text (Kontrast auf Panel ≈ 15:1 / 7:1) |
| `C_ACCENT` | `#FF2E88` | Show-Elemente, Hype-Leiste Start, aktive Zeile (Balken) |
| `C_ACCENT_2` | `#22D3EE` | **Fokus** (3 px Rahmen, immer sichtbar), Panel-Rahmen 2 px |
| `C_GOLD` | `#FFC93C` | Hype-Leiste Ende, Belohnungen |
| `C_DANGER` / `C_OK` / `C_MANA` | `#FF4D4D` / `#4ADE80` / `#60A5FA` | HP niedrig (< 25 %) / HP / MP |
| `ui_live` | `#FF3B30` | LIVE-Badge |
| `ui_party` / `ui_enemy` | `#4AA8FF` / `#E8455A` | Zugreihenfolge-Rahmen (GDD 14.5) |
| `ui_disabled` | `#5A5266` | ausgegraute Befehle |

---

## 3. Shader — verifizierter Code

### 3.1 Übersicht (Dateien aus 02_TECH §1.5, Uniforms ⊇ 02_TECH §8.3)

| Datei | Typ | Zweck |
|---|---|---|
| `art/shaders/toon.gdshader` | spatial | Figuren & interaktive Props: 2/3-Band-Cel-Ramp, farbiger Schatten, Rim, Glanzpunkt, Emission (Vertex-Maske), Metall-Maske, Streifen, Wobble, Flash, Highlight, Dissolve |
| `art/shaders/toon_outline.gdshader` | spatial | Inverted Hull als `next_pass` von `toon` |
| `art/shaders/env_tiles.gdshader` | spatial | Umgebung: Welt-Fliesen, Fugen, Schmutz, 3 Bänder, Schraffur im Schatten, kein Outline, kein `discard` |
| `art/shaders/glow.gdshader` | spatial | Unshaded-Emissiv: Neonröhren, Treppen-Licht, Signallampen |
| `art/shaders/vfx_additive.gdshader` | spatial | Additive Billboard-Partikel ohne Textur (Punkt/Stern/Ring/Funke) |
| `art/shaders/hologram.gdshader` | spatial | M.O.D., Bildschirme, Sponsor-Logos, Schilde |
| `art/shaders/ui_swirl.gdshader` | canvas_item | Kampf-Swirl (Router) |
| `art/shaders/ui_tv_overlay.gdshader` | canvas_item | Scanlines, Vignette, Chromatische Aberration + Testbild „Sendeschluss“ |

**Vertex-Daten-Konvention** (geschrieben von `MeshUtil.merge()`, gelesen von `toon`/`env_tiles`/`toon_outline`):
`COLOR` = **sRGB**-Albedo (F1), `UV2.x` = Emissionsmaske (× `vertex_emission_energy` 3.0), `UV2.y` = Metallmaske
(+0.9 Glanz, doppelte Glanzpunktgröße), `CUSTOM0.xyz` = geglättete Normalen für den Hull.
Damit reicht **ein** Material pro Figur für Haut, Stoff, Metall und Leuchtteile.

**`Materials`-Optionen** (02_TECH §8.2) — Art-Belegung:

| Aufruf | Ergebnis |
|---|---|
| `Materials.toon_vc({"bands": 3, "rim": 0.45})` | Standard für **alle Figuren** (`spec_strength 0.25`, Outline `0.025`) |
| `Materials.toon_vc({"bands": 3, "rim": 0.45, "outline_width": 0.02})` | interaktive Props (Truhe, Tür, Automat, Treppe, Terminal) |
| `Materials.env({"tile_size": 2.0})` + Zonen-`shade`/`grout` | Raumgeometrie und Props (kein Outline) |
| `Materials.glow(color, 2.0)` | Neon, Augen-Leuchtteile mit eigenem Mesh |
| `Materials.vfx_additive(color)` | Partikel |
| Art-Zusatzschlüssel (Antrag, Kap. 12): `"wobble": float`, `"stripes": Dictionary`, `"rim_color": Color` | Schleim/Kabel/Schwänze, Rolltreppe, Boss-Rim |

Zonenwechsel: `EnvKit` baut jeden Raum mit der Palette seiner Zone; Figuren-Rim folgt der Zone über
`Materials`-Cache-Eintrag pro Zone (`rim_color` aus Palette-Schlüssel `rim`).

### 3.2 `toon.gdshader`

Bänder: Schatten **0.30** / Mitte **0.65** / Licht **1.0**, Schwellen `N·L` 0.02 und 0.42 (bei `bands = 2` eine Schwelle bei 0.15),
Kantenweichheit 0.025. Geschattete Pixel des Directional Lights fallen ins Schattenband. Omni-Lichter erzeugen **gestufte Lichtpfützen**
(Dämpfung in Dritteln) — gewollter Toon-Look. Rim liegt als Emission in `fragment()` (wirkt auch im dunkelsten Gang),
nicht auf nach unten zeigenden Flächen. Glanzpunkt wird wegen `specular_disabled` (Vertrag) in `DIFFUSE_LIGHT` addiert und durch
`ALBEDO` geteilt, damit er weiß bleibt.

```glsl
// PRIME TIME DUNGEON - Toon shader for actors and interactive props. Mobile + Compatibility.
// Contract uniforms (02_TECH 8.3) first, art extras below. Vertex data of kit meshes:
// COLOR = sRGB albedo, UV2.x = emission mask, UV2.y = metal mask, CUSTOM0.xyz = outline normals.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

// --- contract ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.5, 1.0);
uniform float bands : hint_range(2.0, 3.0, 1.0) = 2.0;       // 2 = shadow/lit, 3 = shadow/mid/lit
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_amount : hint_range(0.0, 4.0) = 0.25;       // rim intensity
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
// Instance uniforms: keep this exact order in toon_outline.gdshader (shared indices).
instance uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;  // target selection
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// --- art extras ---
group_uniforms cel;
uniform float band_shadow : hint_range(0.0, 1.0) = 0.30;
uniform float band_mid : hint_range(0.0, 1.0) = 0.65;
uniform float threshold_mid : hint_range(-1.0, 1.0) = 0.02;   // N.L shadow -> mid (bands = 3)
uniform float threshold_lit : hint_range(-1.0, 1.0) = 0.42;   // N.L mid -> lit (bands = 3), shadow -> lit (bands = 2: 0.15)
uniform float band_softness : hint_range(0.001, 0.2) = 0.025;
uniform float rim_width : hint_range(0.0, 1.0) = 0.22;
group_uniforms specular;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.25;
uniform float spec_size : hint_range(0.0, 1.0) = 0.10;
uniform float metal_spec_boost : hint_range(0.0, 2.0) = 0.9;  // added where UV2.y = 1
group_uniforms emission_extra;
uniform float vertex_emission_energy : hint_range(0.0, 16.0) = 3.0; // x UV2.x
uniform vec4 highlight_color : source_color = vec4(1.0, 0.79, 0.24, 1.0);
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.31, 0.63, 1.0);
group_uniforms stripes;
uniform vec4 stripe_color : source_color = vec4(0.95, 0.76, 0.19, 1.0);
uniform float stripe_mix : hint_range(0.0, 1.0) = 0.0;        // 0 = off
uniform float stripe_frequency = 6.0;                          // stripes per UV unit (UV.y)
uniform float stripe_duty : hint_range(0.0, 1.0) = 0.5;
uniform float stripe_scroll = 0.0;                             // stripes per second
group_uniforms wobble;
uniform float wobble_amount : hint_range(0.0, 0.2) = 0.0;     // meters, 0 = off
uniform float wobble_speed = 1.5;                              // Hz
group_uniforms;

varying vec3 v_obj_pos;

// Vertex colors are stored sRGB. Compatibility already hands them to the shader linearized,
// Mobile/Forward+ hand them over raw (tested 4.7.2) -> convert only there.
vec3 ptd_vertex_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
#endif
}

float ptd_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ptd_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(ptd_hash(i + vec3(0, 0, 0)), ptd_hash(i + vec3(1, 0, 0)), f.x),
	               mix(ptd_hash(i + vec3(0, 1, 0)), ptd_hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(ptd_hash(i + vec3(0, 0, 1)), ptd_hash(i + vec3(1, 0, 1)), f.x),
	               mix(ptd_hash(i + vec3(0, 1, 1)), ptd_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_obj_pos = VERTEX;
	if (wobble_amount > 0.0) {
		float w = sin(TIME * wobble_speed * TAU + VERTEX.y * 6.0 + VERTEX.x * 4.0);
		VERTEX += NORMAL * w * wobble_amount;
	}
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= ptd_vertex_albedo(COLOR.rgb);
	}
	float stripe = step(1.0 - stripe_duty, fract(UV.y * stripe_frequency + TIME * stripe_scroll));
	col = mix(col, stripe_color.rgb, stripe * stripe_mix);
	col = mix(col, flash_color.rgb, flash_amount);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;

	// Hard toon rim as emission (independent of lights), none on downward faces.
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width - 0.03, 1.0 - rim_width + 0.03, fres);
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	rim *= smoothstep(-0.5, 0.3, world_n.y);

	vec3 emi = emission_color.rgb * emission_energy;
	emi += col * UV2.x * vertex_emission_energy;
	emi += rim_color.rgb * rim * rim_amount;
	emi += flash_color.rgb * flash_amount * 0.8;
	emi += highlight_color.rgb * highlight * (0.25 + 0.15 * sin(TIME * 8.0)) * (0.4 + fres);
	if (dissolve > 0.0) {
		float n = ptd_noise(v_obj_pos * 7.0) * 0.7 + ptd_noise(v_obj_pos * 19.0) * 0.3;
		float cut = dissolve * 1.08 - 0.04;
		if (n < cut) {
			discard;
		}
		emi += dissolve_edge_color.rgb * (1.0 - smoothstep(0.0, 0.07, n - cut)) * 4.0;
	}
	EMISSION = emi;
}

float ptd_band(float x) {
	if (bands < 2.5) {
		return mix(band_shadow, 1.0, smoothstep(0.15 - band_softness, 0.15 + band_softness, x));
	}
	float b = mix(band_shadow, band_mid, smoothstep(threshold_mid - band_softness, threshold_mid + band_softness, x));
	return mix(b, 1.0, smoothstep(threshold_lit - band_softness, threshold_lit + band_softness, x));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float x = ndl;
	float intensity = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// ATTENUATION = shadow factor: shadowed pixels fall into the shadow band.
		x = min(ndl, mix(threshold_mid - 0.1, 1.0, ATTENUATION));
	} else {
		intensity = min(1.0, ceil(ATTENUATION * 3.0) / 3.0) * step(0.02, ATTENUATION); // stepped light pools
	}
	float b = ptd_band(x);
	float lit_w = smoothstep(threshold_mid - band_softness, threshold_lit + band_softness, x);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * b * mix(shade_color.rgb, vec3(1.0), lit_w) * intensity;

	float spec_amt = spec_strength + UV2.y * metal_spec_boost;
	if (spec_amt > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float size = spec_size * (1.0 + UV2.y);
		float s = smoothstep(1.0 - size - 0.01, 1.0 - size + 0.01, dot(NORMAL, h) * 0.5 + 0.5);
		// Added to DIFFUSE_LIGHT (specular_disabled per contract); divided by ALBEDO to stay white-ish.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * s * spec_amt * lit_w * intensity / max(ALBEDO, vec3(0.08));
	}
}
```

### 3.3 `toon_outline.gdshader`

Hull wächst im **Clip-Space** entlang der (geglätteten) Normalen. `outline_width` = Linienbreite in Metern **bei 6 m Kameradistanz**
(0.025 m ≈ 3.5 px bei 1080p/FOV 60); näher bleibt die Bildschirmbreite konstant (keine fetten Linien in Close-ups),
weiter weg wird sie bis 35 % dünner. Kamera-Zoom (FOV) skaliert die Linie mit. Ohne `CUSTOM0` (rohe `PrimitiveMesh`) Rückfall auf `NORMAL`.

```glsl
// PRIME TIME DUNGEON - Inverted-hull outline (next_pass of toon). Mobile + Compatibility.
// outline_width = world width (m) the line has at ref_distance (6 m); constant on screen up to
// that distance (no fat lines in close-ups), thinner beyond it. Grows in clip space.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;

// --- contract ---
uniform vec4 outline_color : source_color = vec4(0.078, 0.051, 0.11, 1.0);  // Palette.INK #140d1c
uniform float outline_width : hint_range(0.0, 0.2) = 0.025;
// Instance uniforms: SAME names AND SAME declaration order as toon.gdshader, otherwise Godot assigns
// different indices and only the first material shows the value (engine warning, tested 4.7.2).
instance uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0);      // extra
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;     // extra
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// --- art extras ---
uniform vec4 highlight_color : source_color = vec4(1.0, 0.79, 0.24, 1.0);
uniform float ref_distance = 6.0;
uniform float min_width_factor : hint_range(0.0, 1.0) = 0.35;
uniform bool use_custom0_normals = true;   // smoothed normals from MeshUtil.merge() in CUSTOM0.xyz

void vertex() {
	vec3 n = NORMAL;
	if (use_custom0_normals && dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01) {
		n = normalize(CUSTOM0.xyz);
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_n = normalize(MODELVIEW_NORMAL_MATRIX * n);
	vec2 dir_px = (PROJECTION_MATRIX * vec4(view_n, 0.0)).xy * VIEWPORT_SIZE;   // aspect-correct direction
	float len = length(dir_px);
	dir_px = len > 0.0001 ? dir_px / len : vec2(0.0);
	float w = outline_width * (1.0 + 0.6 * highlight);
	float ndc_h = w * PROJECTION_MATRIX[1][1] / ref_distance;                  // NDC height at ref distance
	float dist_factor = clamp(ref_distance / max(clip.w, 0.001), min_width_factor, 1.0);
	clip.xy += dir_px * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0) * ndc_h * dist_factor * clip.w;
	POSITION = clip;
}

void fragment() {
	if (dissolve > 0.6) {
		discard;
	}
	vec3 c = mix(outline_color.rgb, highlight_color.rgb * 1.5, highlight);
	ALBEDO = mix(c, flash_color.rgb, flash_amount);
}
```

### 3.4 `env_tiles.gdshader`

Planare Weltprojektion nach dominanter Normalenachse (Boden XZ, Wände XY/ZY), Fugen alle `tile_size` m, ±6 % Helligkeit je Kachel,
Schmutzflecken (Value-Noise) + Schmutzkante 0.6 m an Wänden, diagonale Bildschirm-Schraffur im Schattenband.

```glsl
// PRIME TIME DUNGEON - Environment: world-space tiles/grout/dirt, vertex color, 3 toon bands,
// screen-space hatching in shadow. No outline, no discard (early-Z on tile GPUs). Mobile + Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

// --- contract ---
uniform float tile_size = 2.0;                                  // m
uniform vec4 grout_color : source_color = vec4(0.10, 0.11, 0.14, 1.0);
uniform float grout_width : hint_range(0.0, 0.5) = 0.04;        // m
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.5, 1.0);
uniform float bands : hint_range(2.0, 3.0, 1.0) = 3.0;
uniform bool use_vertex_color = true;

// --- art extras ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 dirt_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform float dirt_height = 0.6;                                // m: grime creeping up walls
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.5;
uniform float hatch_spacing_px : hint_range(2.0, 24.0) = 6.0;
uniform float band_shadow : hint_range(0.0, 1.0) = 0.22;
uniform float band_mid : hint_range(0.0, 1.0) = 0.6;

varying vec3 v_world;
varying vec3 v_wnormal;

// Same rule as toon.gdshader: vertex colors are sRGB, Compatibility delivers them linearized.
vec3 ptd_vertex_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
#endif
}

float ptd_hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ptd_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ptd_hash2(i), ptd_hash2(i + vec2(1.0, 0.0)), f.x),
	           mix(ptd_hash2(i + vec2(0.0, 1.0)), ptd_hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= ptd_vertex_albedo(COLOR.rgb);
	}
	// Planar projection by dominant world normal axis.
	vec3 an = abs(v_wnormal);
	vec2 p = an.y > 0.5 ? v_world.xz : (an.x > an.z ? v_world.zy : v_world.xy);
	vec2 t = fract(p / tile_size) * tile_size;
	vec2 d = min(t, vec2(tile_size) - t);
	float grout = 1.0 - step(grout_width * 0.5, min(d.x, d.y));
	// per-tile brightness jitter (+-6 %)
	col *= 0.94 + 0.12 * ptd_hash2(floor(p / tile_size));
	col = mix(col, grout_color.rgb, grout);
	// dirt: noise blotches + grime near the floor on walls
	float n = ptd_vnoise(p * 1.3) * 0.6 + ptd_vnoise(p * 5.0) * 0.4;
	float grime = an.y > 0.5 ? 0.0 : 1.0 - smoothstep(0.0, dirt_height, v_world.y);
	float dirt = clamp(smoothstep(0.45, 0.85, n) + grime * 0.7, 0.0, 1.0) * dirt_amount;
	col = mix(col, dirt_color.rgb, dirt);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
}

float ptd_band(float x) {
	if (bands < 2.5) {
		return mix(band_shadow, 1.0, smoothstep(0.125, 0.175, x));
	}
	float b = mix(band_shadow, band_mid, smoothstep(-0.005, 0.045, x));
	return mix(b, 1.0, smoothstep(0.395, 0.445, x));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float x = ndl;
	float intensity = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		x = min(ndl, mix(-0.08, 1.0, ATTENUATION));
	} else {
		intensity = min(1.0, ceil(ATTENUATION * 3.0) / 3.0) * step(0.02, ATTENUATION);
	}
	float b = ptd_band(x);
	float shadow_w = 1.0 - smoothstep(-0.005, 0.045, x);
	float hatch = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing_px));
	b -= hatch * hatch_strength * shadow_w * band_shadow;
	vec3 tint = mix(shade_color.rgb, vec3(1.0), smoothstep(-0.005, 0.445, x));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * b * tint * intensity;
}
```

### 3.5 `glow.gdshader`

```glsl
// PRIME TIME DUNGEON - Unshaded emissive (neon tubes, stair glow, signal lamps). Mobile + Compatibility.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.18, 0.53, 1.0);
uniform float energy : hint_range(0.0, 16.0) = 2.0;          // > 1 feeds glow (hdr threshold 1.0)
uniform float pulse_speed = 0.0;                              // Hz, 0 = steady
uniform float flicker : hint_range(0.0, 1.0) = 0.0;           // extra: random dropouts (broken neon)

float ptd_rand(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	float p = pulse_speed > 0.0 ? 0.75 + 0.25 * sin(TIME * pulse_speed * TAU) : 1.0;
	float f = 1.0 - flicker * step(0.85, ptd_rand(floor(TIME * 12.0))) * 0.8;
	ALBEDO = color.rgb * energy * p * f;
}
```

### 3.6 `vfx_additive.gdshader`

Als `material` eines `QuadMesh` (Größe 1×1, Skalierung über Partikel), Mesh eines `CPUParticles3D`. Farbe = `color × COLOR` (Partikelfarbe/-verlauf).

```glsl
// PRIME TIME DUNGEON - Additive billboard particle sprite, texture-free. Mobile + Compatibility.
// Use as material of the QuadMesh of a CPUParticles3D. Final color = color * particle COLOR.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform int shape : hint_range(0, 3) = 0;                     // extra: 0 dot, 1 star, 2 ring, 3 spark
uniform float energy : hint_range(0.0, 8.0) = 2.0;            // extra

void vertex() {
	// Billboard keeping particle scale (like BaseMaterial3D BILLBOARD_PARTICLES).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float s = max(softness, 0.01);
	float a;
	if (shape == 1) {
		a = clamp(1.0 - (abs(p.x) * abs(p.y) * 18.0 + r * 0.9), 0.0, 1.0);
	} else if (shape == 2) {
		a = 1.0 - smoothstep(0.0, 0.25 * s, abs(r - 0.75));
	} else if (shape == 3) {
		a = (1.0 - smoothstep(0.0, 0.5 * s, abs(p.x))) * (1.0 - smoothstep(0.6, 1.0, abs(p.y)));
	} else {
		a = 1.0 - smoothstep(1.0 - s, 1.0, r);
	}
	ALBEDO = color.rgb * COLOR.rgb * energy * a * color.a * COLOR.a;
}
```

### 3.7 `hologram.gdshader`

```glsl
// PRIME TIME DUNGEON - Hologram (M.O.D., screens, sponsor logos, shields). Mobile + Compatibility.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// --- contract ---
uniform vec4 color : source_color = vec4(0.133, 0.827, 0.933, 1.0);   // Palette.NOVA_CYAN #22d3ee
uniform float scan_speed = 1.5;                                        // m/s
uniform float alpha : hint_range(0.0, 1.0) = 0.6;

// --- art extras ---
uniform float energy : hint_range(0.0, 8.0) = 1.6;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.0;
uniform float base_fill : hint_range(0.0, 1.0) = 0.25;              // face fill vs. edge glow
uniform float scanline_density = 60.0;                                // lines per meter (world Y)
uniform float flicker_hz = 9.0;
instance uniform float holo_glitch : hint_range(0.0, 1.0) = 0.0;
varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float g = step(0.5, fract(sin(floor(TIME * 20.0) * 12.9898 + VERTEX.y * 7.0) * 43758.5453));
	VERTEX.x += (g - 0.5) * 0.06 * holo_glitch;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);
	float scan = 0.55 + 0.45 * step(0.5, fract(v_world.y * scanline_density - TIME * scan_speed));
	float flick = 0.92 + 0.08 * sin(TIME * flicker_hz * TAU);
	ALBEDO = color.rgb * energy * alpha * (base_fill + fres) * scan * flick;
}
```

### 3.8 `ui_swirl.gdshader`

Router (02_TECH §9.3): Snapshot → `TextureRect` auf `CanvasLayer 100` mit diesem Material, `snapshot` = dieselbe Textur,
`aspect = size.x / size.y`, `progress` 0→1 in **0.7 s** (`TRANS_CUBIC`, `EASE_IN`), danach 0.3 s Fade.

```glsl
// PRIME TIME DUNGEON - Battle swirl (Router, CanvasLayer 100, TextureRect showing the snapshot).
// progress 0 -> 1 in 0.7 s. Mobile + Compatibility.
shader_type canvas_item;

// --- contract ---
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D snapshot : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.078, 0.051, 0.11, 1.0);    // Palette.INK

// --- art extras ---
uniform float twist = 9.0;                                             // radians at progress 1
uniform vec4 flash_color : source_color = vec4(1.0, 0.18, 0.53, 1.0); // NOVA_MAGENTA shards
uniform float aspect = 1.7778;                                         // set by Router: width / height

void fragment() {
	vec2 asp = vec2(aspect, 1.0);
	vec2 c = (UV - 0.5) * asp;
	float r = length(c);
	float ang = progress * progress * twist * (1.0 - smoothstep(0.0, 0.9, r));
	float s = sin(ang);
	float co = cos(ang);
	vec2 rc = vec2(co * c.x - s * c.y, s * c.x + co * c.y);
	vec2 uv = rc * (1.0 - 0.35 * progress) / asp + 0.5;
	vec3 col = texture(snapshot, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float shard = step(0.5, fract(atan(c.y, c.x) * 1.909859 + progress * 2.0));   // 12 segments
	col = mix(col, flash_color.rgb, shard * smoothstep(0.3, 0.6, progress) * 0.35);
	float edge = 1.7 - progress * 1.9;
	float iris = smoothstep(edge, edge + 0.05, r * 1.4);
	col = mix(col, tint.rgb, clamp(iris + smoothstep(0.85, 1.0, progress), 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
```

### 3.9 `ui_tv_overlay.gdshader`

Vollbild-`ColorRect` (`mouse_filter IGNORE`) im ShowOverlay (Layer 40). Quality `high`: `aberration 0.6`; `low`: `aberration 0.0`
(dann **kein** Bildschirm-Lesen im Shader-Pfad, nur Abdunkeln über Alpha). Game Over: `test_card` 0→1 in 0.2 s.

```glsl
// PRIME TIME DUNGEON - TV overlay (scanlines, vignette, chromatic aberration) + "Sendeschluss" test card.
// Fullscreen ColorRect in GlobalUi ShowOverlay (CanvasLayer 40). Mobile + Compatibility.
shader_type canvas_item;

// --- contract ---
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float aberration : hint_range(0.0, 4.0) = 0.6;               // px at 720p, 0 = no screen read

// --- art extras ---
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float test_card : hint_range(0.0, 1.0) = 0.0;                // 1 = Game Over test card
uniform float noise_amount : hint_range(0.0, 1.0) = 0.25;

float ptd_rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 ptd_card(vec2 uv) {
	int bar = int(floor(uv.x * 7.0));
	vec3 bars[7] = vec3[7](vec3(0.75, 0.75, 0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75),
		vec3(0.0, 0.75, 0.0), vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
	vec3 c = bars[clamp(bar, 0, 6)];
	if (uv.y > 0.67) {
		c = vec3(step(0.5, fract(uv.x * 4.0)) * 0.9 + 0.05);
	}
	float n = ptd_rand(floor(uv * vec2(320.0, 180.0)) + fract(TIME) * 91.0);
	return mix(c, vec3(n), noise_amount);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (aberration > 0.0) {
		vec2 off = (uv - 0.5) * aberration * SCREEN_PIXEL_SIZE * 2.0;
		col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
		a = 1.0;
	}
	float line = step(0.5, fract(FRAGCOORD.y * 0.5));
	float vig = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.3, 1.0))) * vignette;
	col = mix(col, vec3(0.0), line * scanline_alpha * a);
	col = mix(col, ptd_card(UV), test_card);
	a = max(a, test_card);
	// without aberration: draw only scanline + vignette darkening as alpha
	COLOR = vec4(col * (1.0 - vig), max(a, max(line * scanline_alpha, vig)));
}
```

### 3.10 Renderer-Regeln

| Regel | Grund |
|---|---|
| Vertex-/Instanzfarben sRGB speichern, Konvertierung nur per `CURRENT_RENDERER`-Weiche (F1) | sonst ist Compatibility doppelt linearisiert (dunkler, übersättigt) |
| Instance-Uniforms in `toon`/`toon_outline` in identischer Reihenfolge (F2) | geteilte Indizes |
| `light()` nutzt nur `NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ALBEDO, FRAGCOORD, UV2` | in beiden Renderern vorhanden (getestet) |
| Kein `hint_screen_texture`/`DEPTH_TEXTURE` in Spatial-Shadern; in Canvas-Shadern erlaubt (Overlay) | 02_TECH §8.1 + Kosten |
| Kein `discard` in `env_tiles` | Early-Z/HSR auf Tile-GPUs; `toon` enthält `discard` nur für Dissolve (wenige Figuren) |
| Keine Textur-Sampler in 3D-Shadern | keine Assets, kein Speicher |
| ≤ 4 Instance-Uniforms pro Shader (Limit 16) | Puffergröße |
| **Shader-Prewarm** in `Boot`: jedes `Materials`-Ergebnis 2 Frames hinter dem Logo auf einem Würfel rendern | Compatibility kompiliert beim ersten Draw → sonst Ruckler beim ersten Kampf |
| Raumgeometrie `cast_shadow = OFF` (F5) | Eigenschatten-Akne in Compatibility |

---

## 4. Environment & Licht

### 4.1 Feature-Verfügbarkeit (Godot 4.7; ClassDB + Rendertest)

| Feature | Mobile | Compatibility | Entscheidung |
|---|---|---|---|
| Tonemap Linear/Reinhard/Filmic/ACES/**AgX** | ja | ja (AgX gerendert) | **AgX** (Neon clippt ohne Farbstich) — Abweichung zu 02_TECH „filmic“, s. Kap. 12 |
| Glow | ja | ja (gerendert) | nur Quality `high` (02_TECH §3.4) |
| Fog Exponential/Depth, Height-Fog | ja | ja (gerendert) | Exponential, Height-Fog nur Kanalisation |
| Volumetric Fog, SSAO, SSIL, SSR, SDFGI | **nein** (Forward+ only) | **nein** | nie; Ersatz: Fog + additive Lichtkegel (`hologram` auf Kegel-Mesh) + Kontakt-Blob |
| Directional Shadow | ja | ja | Quality `high`; Mobile-Gerät `SHADOW_ORTHOGONAL`, sonst PSSM 2 Splits (02_TECH) |
| Omni/Spot-Schatten | — | — | projektweit aus (`positional_shadow/atlas_size = 0`, 02_TECH §2.1) |
| Lichter pro Objekt | 8 Omni + 8 Spot | `max_lights_per_object = 8` | Budget ≤ 4 aktiv in Reichweite (`high`), ≤ 2 (`low`) |
| `CPUParticles3D` / `GPUParticles3D` | ja / ja | ja / ja (beide gerendert) | **nur `CPUParticles3D`** (02_TECH §8.1) |

### 4.2 `EnvKit.make_environment(theme_id, palette, mode, quality)`

Gemeinsam: `BG_COLOR` = Palette `fog` × 0.6, `AMBIENT_SOURCE_COLOR` = Palette `ambient`, `REFLECTION_SOURCE_DISABLED`,
`TONE_MAPPER_AGX` (`tonemap_exposure` s. u.), `fog_enabled`, `FOG_MODE_EXPONENTIAL`, `fog_light_color` = Palette `fog`, `fog_sky_affect 0`.
Glow (nur `high`): `glow_levels/2 = 1, /3 = 1, /4 = 0.6`, Rest 0, `glow_intensity` s. u., `glow_bloom 0.05`, `glow_hdr_threshold 1.0`, `GLOW_BLEND_MODE_SCREEN`.

| mode | ambient_light_energy | fog_density | exposure | glow_intensity | Besonderheit |
|---|---|---|---|---|---|
| `&"explore"` | 0.80 | **0.030** (Kanal 0.050, `fog_height 0.4`, `fog_height_density 0.6`) | 1.00 | 0.8 | — |
| `&"battle"` | 0.90 | 0.020 | 1.05 | 1.0 | „Show-Licht“, s. 4.3 |
| `&"safe"` | 1.10 | 0.000 (aus) | 1.10 | 0.6 | warm, keine Schraffur (`hatch_strength 0`) |

Boss-Phasenwechsel: Ambient 0.25 s auf Palette `neon2`, danach zurück (Tween 0.6 s). Hausmeister P3: `ambient` dauerhaft `#5A1A18`.

### 4.3 Licht-Rigs

**Sonne (`EnvKit.make_sun`)** — einziges schattenwerfendes Licht, „Studio-Key“:

| mode | Farbe | Energie | Rotation | Schatten |
|---|---|---|---|---|
| explore | Palette `key` | 1.1 (Kanal 0.7, Keller 0.9) | `(-55, 35, 0)` | `high`: an, max. 30 m, `shadow_bias 0.03`, `normal_bias 1.0` |
| battle | Palette `key` | 1.25 | `(-50, -30, 0)` (von vorne-links auf die Party) | `high`: an, max. 20 m |
| safe | `#FFE2B8` | 1.2 | `(-60, 20, 0)` | `high`: an |

**Raumlicht** (02_TECH §8.5): pro Raum eine `OmniLight3D` (y 3.0, Reichweite 9, Energie 1.2, Distance-Fade 24/6 m), Farbe = Palette `light`.
**Neon-Akzente** (Art): pro Raum max. **1** zusätzliche Omni an einem Neon-Prop (Farbe `accent` oder `neon2`, Energie 2.0, Reichweite 5,
`light_specular 0`), nur Quality `high`. Jedes leuchtende Objekt hat zusätzlich emissive Geometrie (`glow`), damit es auch ohne Licht leuchtet.
**Kampf-Zusatz** (`high`): 2 SpotLights ohne Schatten `#FF2E88` / `#22D3EE`, Energie 3.0, Reichweite 14, Winkel 22°, von (±7, 6, 2)
auf die Arenamitte; schwenken 1.2 s über die Party bei Sponsor-Geschenk und Stunt-Erfolg. Figuren-Rim im Kampf × 1.3.
**Kontakt-Schatten** (nur Quality `low`, wenn keine Echtzeitschatten): Scheibe `MeshUtil.cylinder(r, r, 0.01)`, r = 0.6 × Figurbreite,
y 0.01, `Materials.toon(Palette.INK, {"outline": false, "rim": 0.0})`, `cast_shadow OFF`.

---

## 5. Figuren aus Primitiven

### 5.1 Konventionen (ergänzen 02_TECH §8.1)

| Punkt | Regel |
|---|---|
| Achsen | Meter, +Y oben, **Vorderseite −Z** (02_TECH). Rechte Hand = **+X**. Ursprung = Mitte zwischen den Füßen am Boden. |
| Aufbau | `CharacterRig` → benannte **Pivot-Node3D** → je Pivot ein `MeshInstance3D` (per `MeshUtil.merge()`), Material `Materials.toon_vc({"bands": 3, "rim": 0.45})`. Leuchtteile mit Puls (Display, Glühbirne, Boss-Augen) als **eigenes** Mesh im selben Pivot (eigene Instance-Uniforms). |
| Pivot-Namen | `Hips, Torso, Head, ArmL, ArmR, LegL, LegR, Tail, Body, WingL, WingR, JawLower, Leg0…Leg7, Keys, Crown` |
| Anker (`CharacterRig.anchor()`) | `head` (Kopfmitte), `center` (Rumpfmitte), `overhead` (0.25 m über Kopf), `hand_r`, `hand_l`, `feet` (Ursprung) — als leere Node3D unter dem jeweiligen Pivot |
| Notation | Pivot-Position in Rig-Koordinaten (scale 1), Teile relativ zum Pivot. `Sphere r`, `Capsule r/h` (h = Gesamthöhe), `Box x×y×z`, `Cyl rt/rb/h`, `Cone r/h`, `Torus ri/ro`, `Hemi r`, `Prism x×y×z`. Rotation in Grad (X, Y, Z). **E** = Emissionsmaske 1.0, **M** = Metallmaske 1.0. Farbslots aus `ModelSpec.colors`: `primary`, `secondary`, `accent`, `skin`, `eyes`. |
| Segmente (gemessen) | Sphere 10×6 = 140 Tris, Capsule 10×2 = 180, Cyl 8 = 48, Torus 10×5 = 100, Hemi = 80, Box = 12, Prism = 8. **Kleinteile r < 0.06 m:** Sphere 6×3 = 48, Capsule 6×1 = 72, Cyl 6 = 36. |
| Skalierung | `ModelSpec.scale` skaliert den **Rig-Root**; Rezepte sind für scale 1.0 angegeben. Höhen bei scale 1 (02_TECH): humanoid 1.75, pug 0.6, rodent 0.7, blob 0.9, insect 0.8, robot 1.5, brute 2.2, specter 1.6 m. |
| Cache | gleicher `ModelSpec` (base + scale + colors + props) → gleiche `ArrayMesh`-Instanzen aus `CharacterBuilder`-Cache. |

### 5.2 `MeshUtil` — verifiziert

```gdscript
class_name MeshUtil
extends RefCounted
## Low-poly primitives + merge into one ArrayMesh per rigid part (02_TECH 8.2).
## Vertex data written by merge(): COLOR = sRGB albedo (Godot convention, like glTF import), UV2.x = emission mask, UV2.y = metal mask,
## CUSTOM0.xyz = smoothed normals for the outline hull (toon_outline.gdshader).

const SPHERE_RADIAL: int = 10
const SPHERE_RINGS: int = 6
const CAPSULE_RADIAL: int = 10
const CAPSULE_RINGS: int = 2
const CYLINDER_RADIAL: int = 8
const SMALL_PART: float = 0.06   # parts smaller than this use the "small" segment counts


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var small: bool = radius < SMALL_PART
	m.radial_segments = 6 if small else SPHERE_RADIAL
	m.rings = 3 if small else SPHERE_RINGS
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	var small: bool = radius < SMALL_PART
	m.radial_segments = 6 if small else CAPSULE_RADIAL
	m.rings = 1 if small else CAPSULE_RINGS
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = 6 if maxf(top_radius, bottom_radius) < SMALL_PART else CYLINDER_RADIAL
	m.rings = 1
	return m


# --- art extras ---

static func cone(radius: float, height: float) -> CylinderMesh:
	return cylinder(0.0, radius, height)


static func hemisphere(radius: float) -> SphereMesh:
	var m := sphere(radius)
	m.is_hemisphere = true
	m.height = radius
	m.rings = 3
	return m


static func torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = 10
	m.ring_segments = 5
	return m


static func prism(size: Vector3, left_to_right: float = 0.5) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = left_to_right
	return m


static func xform(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl), pos)


## parts: [{"mesh": Mesh, "xform": Transform3D, "color": Color (sRGB), "emission": float = 0, "metal": float = 0}]
static func merge(parts: Array[Dictionary]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	for part: Dictionary in parts:
		var mesh: Mesh = part["mesh"]
		var t: Transform3D = part.get("xform", Transform3D.IDENTITY)
		var c: Color = part.get("color", Color.WHITE)
		var mask := Vector2(float(part.get("emission", 0.0)), float(part.get("metal", 0.0)))
		var nb: Basis = t.basis.inverse().transposed()
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
			var ix: Variant = arr[Mesh.ARRAY_INDEX]
			var base: int = verts.size()
			for i in v.size():
				verts.append(t * v[i])
				norms.append((nb * n[i]).normalized())
				cols.append(c)
				uvs.append((uv as PackedVector2Array)[i] if uv != null else Vector2.ZERO)
				uv2s.append(mask)
			if ix == null:
				for i in v.size():
					idx.append(base + i)
			else:
				for i: int in (ix as PackedInt32Array):
					idx.append(base + i)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = smoothed_normals(verts, norms)
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


## Averaged normals per position -> CUSTOM0 (RGBA float). Also used by the glTF post-import.
static func smoothed_normals(verts: PackedVector3Array, norms: PackedVector3Array) -> PackedFloat32Array:
	var acc: Dictionary = {}
	for i in verts.size():
		var k := Vector3i((verts[i] * 1000.0).round())
		acc[k] = (acc.get(k, Vector3.ZERO) as Vector3) + norms[i]
	var out := PackedFloat32Array()
	out.resize(verts.size() * 4)
	for i in verts.size():
		var sn: Vector3 = (acc[Vector3i((verts[i] * 1000.0).round())] as Vector3).normalized()
		out[i * 4] = sn.x
		out[i * 4 + 1] = sn.y
		out[i * 4 + 2] = sn.z
		out[i * 4 + 3] = 1.0
	return out


static func tri_count(mesh: Mesh) -> int:
	var total: int = 0
	for s in mesh.get_surface_count():
		var ix: int = mesh.surface_get_array_index_len(s)
		total += (ix if ix > 0 else mesh.surface_get_array_len(s)) / 3
	return total


## Flat-shaded icosahedron (M.O.D. core).
static func icosahedron(radius: float) -> ArrayMesh:
	var p: float = (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, p, 0), Vector3(1, p, 0), Vector3(-1, -p, 0), Vector3(1, -p, 0),
		Vector3(0, -1, p), Vector3(0, 1, p), Vector3(0, -1, -p), Vector3(0, 1, -p),
		Vector3(p, 0, -1), Vector3(p, 0, 1), Vector3(-p, 0, -1), Vector3(-p, 0, 1)]
	var f: PackedInt32Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2,
		10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, f.size(), 3):
		var a: Vector3 = v[f[i]].normalized() * radius
		var b: Vector3 = v[f[i + 2]].normalized() * radius
		var c: Vector3 = v[f[i + 1]].normalized() * radius
		var n: Vector3 = -(b - a).cross(c - a).normalized()
		for q: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(q)
	return st.commit()
```

Beispiel (Kopf des Archetyps `humanoid`):
```gdscript
var head_parts: Array[Dictionary] = [
	{"mesh": MeshUtil.sphere(0.28), "xform": MeshUtil.xform(Vector3(0, 0.26, 0)), "color": colors.skin},
	{"mesh": MeshUtil.sphere(0.30), "xform": MeshUtil.xform(Vector3(0, 0.36, 0.04), Vector3.ZERO, Vector3(1, 0.72, 1)), "color": colors.accent},
	{"mesh": MeshUtil.sphere(0.015), "xform": MeshUtil.xform(Vector3(-0.065, 0.07, -0.195)), "color": Color.WHITE, "emission": 1.0},
]
var head_mesh: ArrayMesh = MeshUtil.merge(head_parts)
```

### 5.3 Archetypen (`art/kit/archetypes.gd`, je `ModelSpec.base`)

#### `humanoid` — 1.75 m (Kai, Pendler)
Slots: primary = Oberteil, secondary = Hose, accent = Haare, skin, eyes. Gemessen: **2 040 Tris** inkl. Mopp, 7 Meshes.

| Pivot (Parent) | Pos | Teile |
|---|---|---|
| `Hips` | (0, 0.60, 0) | Box 0.50×0.12×0.36 · secondary |
| `Torso` (Hips) | (0, 0.60, 0) | Capsule 0.24/0.62 · (0,0.26,0) · primary; Kragen Torus 0.10/0.20 · (0,0.50,0.10) · (−70,0,0) · primary×0.8; Bauchtasche Box 0.30×0.12×0.03 · (0,0.10,−0.235) · primary×0.8; Namensschild Box 0.12×0.07×0.02 · (−0.12,0.38,−0.235) · `#F2F2EA`; Logo Sphere 0.035 · (0.11,0.38,−0.24) · `HYPE_GOLD` |
| `Head` (Torso) | (0, 1.12, 0) | Sphere 0.28 · (0,0.26,0) · skin; Haar Sphere 0.30 · (0,0.36,0.04) · Skal. (1,0.72,1) · accent; Pony Box 0.44×0.10×0.12 · (0,0.44,−0.20) · (−20,0,0) · accent; Augen 2× Capsule 0.035/0.11 · (±0.10,0.27,−0.255) · eyes; Mund Box 0.08×0.015×0.01 · (0,0.15,−0.275) · `#8A3B3B`; Ohren 2× Sphere 0.05 · (±0.28,0.25,0) · skin |
| `ArmL` / `ArmR` (Torso) | (∓0.32, 1.04, 0) | Capsule 0.085/0.48 · (0,−0.20,0) · primary; Hand Sphere 0.095 · (0,−0.46,0) · skin; Anker `hand_l`/`hand_r` (0,−0.46,0) |
| `LegL` / `LegR` (Hips) | (∓0.13, 0.55, 0) | Capsule 0.11/0.50 · (0,−0.22,0) · secondary; Schuh Box 0.18×0.12×0.28 · (0,−0.49,−0.04) · `#1F1F24`; Sohle Box 0.19×0.03×0.29 · (0,−0.545,−0.04) · `PAPER` |
| Anker | — | `head` (0,1.38,0), `center` (0,0.90,0), `overhead` (0,1.95,0) |

#### `pug` — 0.6 m (Graf Mopsula)
Slots: primary = Fell, secondary = Maske/Ohren, accent = Kleidung, eyes. Gemessen: **1 448 Tris** inkl. `cape` + `monocle`, 2 Meshes.

| Pivot | Pos | Teile |
|---|---|---|
| `Body` | (0, 0, 0) | Rumpf Capsule 0.17/0.52 · (0,0.27,0.02) · (90,0,0) · primary; Ringelschwanz Torus 0.025/0.06 · (0,0.42,0.25) · (0,0,90) · primary; 4 Beine Cyl 0.045/0.05/0.18 · (±0.10,0.09,−0.14) und (±0.10,0.09,0.18) · primary; Halsband Torus 0.13/0.165 · (0,0.40,−0.16) · (70,0,0) · `#6B3F22` |
| `Head` (Body) | (0, 0.44, −0.22) | Schädel Sphere 0.19 · Skal. (1.05,0.95,0.95) · primary; Maske Sphere 0.10 · (0,−0.04,−0.15) · Skal. (1.25,0.8,0.6) · secondary; Nase Sphere 0.03 · (0,0,−0.21) · `#111111`; Augen 2× Sphere 0.05 · (±0.08,0.05,−0.15) · eyes; Glanz 2× Sphere 0.015 **E** · (−0.065,0.07,−0.195), (0.095,0.07,−0.195) · `#FFFFFF`; Schlappohren 2× Sphere 0.07 · (±0.16,0.08,−0.02) · (0,0,±35) · Skal. (1,0.35,0.8) · secondary; Stirnfalten 2× Capsule 0.012/0.12 · (0,0.13,−0.13), (0,0.10,−0.15) · (0,0,90) · primary×0.85 |
| Anker | — | `head` (0,0.44,−0.22), `center` (0,0.27,0), `overhead` (0,0.85,−0.1), `hand_r` = Maul (0,0.38,−0.42) |

#### `rodent` — 0.7 m (Kanalratte, Rattenschamane, Rattengardist, Rattenkönigin)
Slots: primary = Fell, secondary = Ohren/Schwanz/Pfoten (rosa), accent = Kleidung, eyes (**E**). **Pose-Regel:** `scale < 1.0` → Vierbeiner, `scale ≥ 1.0` → aufrecht.

*Vierbeiner* (Tabelle für scale 0.8 ≙ 0.60 m Körperlänge; Werte im Rig durch 0.8 geteilt gespeichert):

| Pivot | Pos | Teile |
|---|---|---|
| `Body` | (0, 0.22, 0) | Capsule 0.16/0.60 · (90,0,0) · primary; Bauch Sphere 0.13 · (0,−0.05,−0.05) · Skal. (1,0.7,1.6) · primary×1.25; 4 Pfoten Sphere 0.05 · (±0.10,−0.17,±0.18) · secondary |
| `Head` (Body) | (0, 0.26, −0.30) | Sphere 0.14 · primary; Schnauze Cone 0.07/0.16 · (0,−0.03,−0.15) · (−90,0,0) · primary; Nase Sphere 0.025 · (0,−0.03,−0.24) · secondary; Ohren 2× Sphere 0.06 · (±0.09,0.11,0.02) · Skal. (1,1,0.35) · secondary; Augen 2× Sphere 0.025 **E** · (±0.06,0.04,−0.11) · eyes; Zähne Box 0.04×0.03×0.01 · (0,−0.07,−0.22) · `#F5F5F0` |
| `Tail` (Body) | (0, 0.20, 0.30) | 3 Cyl r 0.03 → 0.015, je h 0.20, Kette nach +Z mit je +20° (X) Biegung · secondary; Wobble-Material |

*Aufrecht* (scale 1.0 ≙ 0.70 m):

| Pivot | Pos | Teile |
|---|---|---|
| `Torso` | (0, 0.23, 0) | Capsule 0.14/0.47 · (0,0.16,0) · primary; Bauch Sphere 0.11 · (0,0.12,−0.06) · Skal. (1,1.3,0.7) · primary×1.25 |
| `Head` (Torso) | (0, 0.61, −0.03) | Sphere 0.12 · primary; Schnauze Cone 0.055/0.13 · (0,−0.02,−0.12) · (−90,0,0); Nase Sphere 0.02 · (0,−0.02,−0.19) · secondary; Ohren 2× Sphere 0.05 · (±0.07,0.09,0.02) · Skal. (1,1,0.35) · secondary; Augen 2× Sphere 0.02 **E** · (±0.05,0.03,−0.09) · eyes |
| `ArmL`/`ArmR` (Torso) | (∓0.15, 0.42, 0) | Capsule 0.035/0.25 · (0,−0.10,0) · primary; Pfote Sphere 0.04 · (0,−0.22,0) · secondary |
| `LegL`/`LegR` | (∓0.08, 0.12, 0) | Capsule 0.05/0.16 · (0,−0.05,0) · primary; Fuß Box 0.07×0.03×0.12 · (0,−0.11,−0.03) · secondary |
| `Tail` | (0, 0.10, 0.12) | 3 Cyl r 0.025 → 0.012, je h 0.16, nach +Z, je +25° (X) · secondary |

#### `blob` — 0.9 m (Kanalschleim)
Slots: primary = Körper, secondary = Müll, eyes. Opak (kein Alpha-Shader im Vertrag) — Transluzenz-Eindruck über `rim 1.0` in hellem primary und Wobble.

| Pivot | Teile |
|---|---|
| `Body` (0,0,0) | Sphere 0.45 · (0,0.36,0) · Skal. (1,0.8,1) · primary; Augen 2× Sphere 0.05 · (±0.10,0.50,−0.33) · `PAPER` + Pupillen 2× Sphere 0.025 · (±0.10,0.50,−0.37) · eyes; Dose Cyl 0.06/0.06/0.18 **M** · (0.22,0.60,0) · (0,0,60) · `#C0C0C0` (ragt oben heraus); Kiste Box 0.12×0.08×0.10 · (−0.25,0.55,0.12) · secondary |

Gemessen (Testmodell): 3 Teile, Wobble 0.03 m @ 1.5 Hz sichtbar, Squash & Stretch zusätzlich per Tween (5.6).

#### `insect` — 0.8 m (Kellerspinne; mit Prop `wings` fliegend)
Slots: primary = Körper, secondary = Muster, accent = Kieferklauen, eyes (**E**).

| Pivot | Pos | Teile |
|---|---|---|
| `Body` | (0, 0.45, 0) | Hinterleib Sphere 0.40 · (0,0.10,0.35) · primary; Muster 3× Sphere 0.08 · (0,0.48,0.35), (0,0.40,0.50), (0,0.30,0.62) · Skal. (1,0.3,1) · secondary; Kopf Sphere 0.22 · (0,0,−0.15) · primary; 6 Augen Sphere 0.035 **E** · (±0.06,0.08,−0.34), (±0.12,0.05,−0.30), (±0.04,0.13,−0.32) · eyes; Klauen 2× Cone 0.03/0.10 · (±0.05,−0.10,−0.33) · (−150,0,0) · accent |
| `Leg0…Leg7` | (±0.18, 0.45, −0.15 + 0.12·i), i = 0…3 | je ein Mesh: Oberteil Cyl 0.03/0.03/0.45 schräg 40° nach außen-oben, Unterteil Cyl 0.03/0.02/0.55 nach außen-unten · primary |

Mit `wings`: nur Leg0–Leg5, Körper schwebt +0.4 m.

#### `robot` — 1.5 m (Fahrscheinfresser; Automaten-Körper)

Slots: primary = Gehäuse, secondary = Dach/Füße, accent = Display (**E**, eigenes Mesh), eyes = Tasten.

| Pivot | Pos | Teile |
|---|---|---|
| `Body` | (0, 0, 0) | Gehäuse Box 0.75×1.50×0.50 · (0,0.75,0) · primary; Dach Box 0.80×0.07×0.55 · (0,1.535,0) · secondary; Füße 2× Box 0.21×0.05×0.42 · (±0.25,0.025,0) · `#1E1E1E`; Schlitz Box 0.25×0.025×0.02 · (0,0.875,−0.26) · `#1A1420`; 6 Tasten Box 0.05×0.05×0.02 · Raster 2×3 um (0.22,0.95,−0.26) · eyes; obere Zahnreihe 6× Cone 0.035/0.085 · (−0.25+0.1·k, 0.665, −0.33) · (180,0,0) · `#F5F5F0` |
| Display (Body) | — | Box 0.42×0.25×0.02 **E** · (0,1.125,−0.26) · accent — Flackern über `flash_amount` (Darstellungs-Zufall, nicht Kern-RNG) |
| `JawLower` (Body) | (0, 0.625, −0.25) | Kiefer Box 0.67×0.10×0.21 · (0,−0.05,−0.10) · primary; 6 Zähne Cone 0.035/0.085 · (−0.25+0.1·k, 0.03, −0.18) · `#F5F5F0` |

#### `brute` — 2.2 m (Der Hausmeister)
Slots: primary = Kittel, secondary = Hose, accent = Schnurrbart/Haare, skin, eyes (eigenes Mesh → P3-Glühen).

| Pivot | Pos | Teile |
|---|---|---|
| `Torso` | (0, 0.88, 0) | Kittel Capsule 0.40/1.47 · (0,0.40,0) · primary; Saum Cyl 0.43/0.45/0.22 · (0,−0.22,0) · primary×0.85; 4 Knöpfe Sphere 0.03 **M** · (0,0.15+0.18·k,−0.41) · `#D8DDE2`; Brusttasche Box 0.22×0.18×0.03 · (0.16,0.77,−0.39) · primary×0.85 + 3 Stifte Cyl 0.015/0.015/0.15 · (0.11/0.16/0.21, 0.87, −0.41) · `#2A5DB0`/`#C23B22`/`#1E1E1E` |
| `Head` (Torso) | (0, 1.80, −0.04) | Sphere 0.28 · skin; Nase Sphere 0.06 · (0,0,−0.27) · skin×0.85; Schnurrbart Box 0.26×0.06×0.07 · (0,−0.06,−0.25) · accent; Augen (eigenes Mesh) 2× Sphere 0.035 · (±0.095,0.06,−0.24) · eyes |
| `ArmL`/`ArmR` (Torso) | (∓0.55, 1.47, 0) | Capsule 0.12/0.88 · (0,−0.40,0) · primary; Hand Sphere 0.13 · (0,−0.84,0) · skin |
| `LegL`/`LegR` | (∓0.21, 0.51, 0) | Capsule 0.15/0.59 · (0,−0.22,0) · secondary; Schuh Box 0.26×0.13×0.37 · (0,−0.48,−0.06) · `#1E1E1E` |

#### `specter` — 1.6 m (Sprühgeist; schwebt)
Slots: primary = Körper, secondary = Kappe/Kopf, accent = Schweif, eyes (**E**).

| Pivot | Pos | Teile |
|---|---|---|
| `Body` | (0, 0.90, 0), schwebt ±0.15 m @ 0.6 Hz | Körper Cyl 0.30/0.10/1.00 · primary; Kopf Sphere 0.30 · (0,0.65,0) · secondary; Augen 2× Capsule 0.05/0.15 **E** · (±0.11,0.70,−0.27) · eyes; Brauen 2× Box 0.10×0.025×0.02 · (±0.11,0.82,−0.28) · (0,0,±20) · `#1A1420`; Mund Box 0.14×0.04×0.02 · (0,0.55,−0.29) · `#1A1420` |
| `ArmL`/`ArmR` | (∓0.32, 1.25, 0) | Capsule 0.06/0.40 · (0,−0.15,0) · (0,0,±20) · primary |
| Schweif | — | `CPUParticles3D` 6 Partikel, `vfx_additive` Punkt, Größe 0.35 m, Verlauf accent → secondary → transparent, Lebenszeit 0.8 s, Emission lokal (0,0.4,0.1) |

### 5.4 Props (`ModelSpec.props`, Vokabular 02_TECH §4.3)

| Prop | Anker | Aufbau (Referenz humanoid; für andere Bases × Rumpfbreite skaliert) |
|---|---|---|
| `cape` | Torso / Body | Box 0.55×0.85×0.04 · Rücken (0,0.30,0.27) · (6,0,0) · accent + Saum Box 0.57×0.05×0.05 · unten · `HYPE_GOLD` **M**. pug: Box 0.40×0.04×0.50 · (0,0.45,0.05) · (8,0,0) + Saum (0,0.45,0.29); rodent aufrecht: Umhang Cone 0.32/0.55 um den Torso |
| `crown` | head | 5 Cone 0.03/0.08 auf Torus 0.09/0.11, alles `HYPE_GOLD` **M**, auf Kopfoberkante |
| `monocle` | head (rechtes Auge) | Torus 0.05/0.065 **M** · `HYPE_GOLD` · Rot (90,0,0) + Kette Cyl 0.005/0.005/0.18 · `HYPE_GOLD` |
| `top_hat` | head | Cyl 0.16/0.16/0.25 + Krempe Cyl 0.24/0.24/0.02 · `#1A1420` + Band Cyl 0.165/0.165/0.04 · accent |
| `cap` | head | Hemi 0.29 · accent + Schirm Box 0.30×0.03×0.18 · vorn (−Z) |
| `bandana` | head | Torus 0.20/0.24 Skal. (1,0.4,1) um die Stirn · accent + Knoten Sphere 0.04 hinten |
| `apron` | Torso | Box 0.45×0.60×0.03 · vorn (0,0.10,−0.25) · accent + Träger Box 0.04×0.3×0.02 ×2 |
| `mop` | hand_r | Stiel Cyl 0.025/0.025/1.30 · (0,0.10,0) · (−70,0,0) · `#8A5A32`; Kopf Cyl 0.12/0.16/0.22 · (0,0.32,−0.60) · (−70,0,0) · `#D9D2B6` |
| `broom` | hand_r | Stiel Cyl 0.03/0.03/1.60 · `#8A5A32`; Bürste Box 0.60×0.12×0.17 · `#C9A227`; Borsten Box 0.57×0.08×0.15 · `#3B2A22` |
| `knife` | hand_r | Klinge Box 0.03×0.25×0.06 **M** · `#D8DDE2`; Griff Box 0.04×0.12×0.05 · `#3B2A22` |
| `staff` | hand_r | Cyl 0.025/0.025/1.00 · (0,0.20,0) · `#6B4A2E`; Glühbirne Sphere 0.08 **E** · (0,0.72,0) · accent (eigenes Mesh, Puls `flash_amount` 0.2–0.6 @ 1.5 Hz) |
| `key_ring` | Hüfte rechts (0.5·Breite, Hips, −0.2) | 12 Torus 0.03/0.06 **M** auf Bogen r 0.18 · `#C9A227`/`#A8B0B8` abwechselnd; eigener Pivot `Keys`, Klimpern ±8° (Z) @ 6 Hz |
| `glasses` | head | 2 Torus 0.05/0.06 · `#1A1420` + Steg Box 0.04×0.01×0.01 |
| `lamp_helmet` | head | Hemi 0.30 · `#F2C230` + Lampe Cyl 0.05/0.05/0.06 **E** · `#FFF2C8` vorn |
| `backpack` | Torso | Box 0.35×0.45×0.20 · Rücken · accent + 2 Gurte Box 0.04×0.4×0.02 |
| `mask` | head | Gasmaske: Cyl 0.08/0.10/0.10 · vorn · (−90,0,0) · `#3A3A44` + 2 Filter Cyl 0.04/0.04/0.06 · `#6B7B3A` |
| `wings` | Torso/Body | Pivots `WingL/WingR`: Box 0.50×0.02×0.25 · secondary, Flap ±50° (Z) @ 8 Hz |
| `antennae` | head | 2× Cyl 0.01/0.01/0.25 + Sphere 0.03 **E** · accent, Wobble |

### 5.5 Besetzung (Party & Gegner → `ModelSpec`)

„Signatur“ = Teile, die das GDD-Aussehen (01_GDD Kap. 5) vervollständigen und **neue Props** brauchen (Antrag an 02_TECH §4.3, Kap. 12).
Bis zur Aufnahme baut `archetypes.gd` den Fallback (Spalte „props“) — das Spiel ist damit vollständig, nur weniger spezifisch.

| ID | base | scale | colors (primary / secondary / accent / skin / eyes) | props | Signatur (neue Props) |
|---|---|---|---|---|---|
| `kai` | humanoid | 1.0 | `#3AA9A0` / `#2E3A57` / `#3B2A22` / `#E8B48F` / `#1A1420` | `mop` | — (Waffen-Optik: `wrench`, `axe`, `crowbar`) |
| `mopsula` | pug | 1.0 | `#D8B98A` / `#2A2024` / `#7B2CBF` / — / `#1A1420` | `cape`, `monocle` | Kronen-Halsband → `crown` am Hals |
| `kanalratte` | rodent | 0.8 | `#6B5B4E` / `#E88A9A` / — / — / `#FF3030` | — | — |
| `taubenschwarm` | insect | 0.4 | `#8C93A6` / `#5FA38E` / `#E0A040` / — / `#FF9A2E` | `wings` | neue **base** `swarm`: 5 Tauben (Sphere 0.12 Körper, Kopf 0.07 **M**, Schnabel Cone, Flügel) auf Orbit r 0.6 m, 1.2 rad/s |
| `pendler` | humanoid | 1.09 | `#4A4F5A` / `#4A4F5A` / `#B33A3A` / `#C9C2B8` / `#1A1420` | `glasses` | `newspaper_head` (Box 0.42×0.50×0.12 `#E8E4D8` + 4 Zeilen + Uhr-Scheibe **E**), `briefcase` (Box 0.40×0.30×0.10 `#5A3A22`) |
| `kanalschleim` | blob | 1.0 | `#6FBF4A` / `#D93B3B` / — / — / `#1A1420` | — | — |
| `rattenschamane` | rodent | 1.3 | `#5A4A40` / `#E88A9A` / `#3E2F5B` / — / `#FFE66B` | `staff`, `cape` | Kronkorken-Kette (6 Torus) → `bottlecap_chain` |
| `kabelsalat` | robot | 0.55 | `#CFCFCF` / `#1E1E1E` / `#9FE8FF` / — / `#9FE8FF` | `antennae` | `cable_tangle`: 8 Kabelketten à 4 Cyl 0.035, Farben `#1E1E1E`/`#D93B3B`/`#3B6FD9`, Wobble 0.05 (ein Mesh) |
| `kellerspinne` | insect | 1.0 | `#2B2B33` / `#C2453A` / `#C2453A` / — / `#FFB000` | — | — |
| `spruehgeist` | specter | 0.65 | `#E23E9B` / `#FFFFFF` / `#4AD9D9` / — / `#1A1420` | — | `spray_cap` (Hemi + Düse) |
| `rolltreppenkrabbe` | insect | 1.5 | `#8A8F96` / `#F2C230` / `#B84A2E` / — / `PAPER` | — | `escalator_back` (schräge Box 1.1×0.1×1.4, `stripes` scrollend `#F2C230`), `claws` (Pivots ClawL/R, Cone-Paar, Unterteil klappt 0→25°) |
| `rattengardist` | rodent | 2.0 | `#4D3F36` / `#E88A9A` / `#7A1F9E` / — / `#FF3030` | `knife`, `cap` | `helmet` (Hemi **M** + Spitze), `shield` (Box 0.5×0.65×0.06 **M** + Kronen-Wappen), `halberd` (Cyl 1.8 + Klinge **M**) |
| `fahrscheinfresser` | robot | 1.2 | `#2F6FB3` / `#24578C` / `#9AF2FF` / — / `PAPER` | — | — (robot ist bereits der Automat) |
| `boss_hausmeister` | brute | 1.36 | `#7C8A94` / `#3E4A55` / `#4A3A30` / `#D9A88A` / `#1A1420` | `cap`, `key_ring`, `broom` | — |
| `boss_rattenkoenigin` | rodent | 4.0 | `#3F3530` / `#E88A9A` / `#F2EEE6` / — / `#FF3030` | `crown`, `cape`, `staff` | `rat_king_tail` (6 Kettenschwänze mit Mini-Ratten, ein Wobble-Mesh), `ticket_crown` (10 Box-Fahrscheine `#F2E8C9`) |

Boss-Sonderwerte: Rattenkönigin-Material mit `rim_color #9A6BFF`, `rim 0.8`; Thron = `PropKit.build("wreck")` (Kap. 6.3), Königin sitzt
auf dem Wagendach (Rig-Root y +3.0). P3: `crown`-Mesh `flash_color #FF5A5A`, `flash_amount 0.8`; Zepter-Lampe (`staff`) wechselt jede
1.0 s `#FF3B30`/`#2BD66B`. Hausmeister P3: Augen-Mesh `flash_color #FF3B30`, `flash_amount 1.0`; Dampf `Vfx.spawn(&"smoke")` an beiden Ohren alle 0.8 s.

### 5.6 M.O.D. (Hologramm-Drohne, kein `CharacterRig`)

Gebaut in `scenes/ui/mod_dialog.gd` (SubViewport-Icon) und im Titel-Studio direkt aus `MeshUtil` + `hologram` (keine eigene Kit-Klasse):
Kern `MeshUtil.icosahedron(0.32)` (20 Tris, verifiziert) mit `hologram` (`color NOVA_CYAN`, `energy 1.6`); Linse Sphere 0.07 `hologram` `NOVA_MAGENTA` `energy 3`;
Ring Torus 0.42/0.46, Rot (70,0,0), `hologram` `NOVA_MAGENTA`, dreht 0.8 rad/s; Sprech-Kegel Cone 0.35/0.9 nach unten, `hologram` `alpha 0.15`.
Idle: Kern dreht 0.6 rad/s (Y) + 0.25 rad/s (X), Bob ±0.06 m @ 0.5 Hz. Erscheinen: Skal. 0→1 in 0.25 s (`TRANS_BACK`) + `holo_glitch` 1→0 in 0.15 s.
Sprechen: Puls 1.0→1.08→1.0 (0.08 s) je 2 Zeichen. Stimmung (`color`): neutral `NOVA_CYAN`, begeistert `NOVA_MAGENTA`, genervt `DANGER`, sentimental `HYPE_GOLD`.
Position Erkundung: Kai + (0.9, 2.3, 0.6) (kamera-seitig über der Schulter), Kampf: (−4, 4, 0). Kein Outline, kein Schatten.

### 5.7 Etage 2 (Stub, Theme `mall`)

| ID | base | Kurz |
|---|---|---|
| `schaufensterpuppe` | humanoid 1.0 | primary `#E8DCCB`, secondary `#E8DCCB`, kein Gesicht (eyes = skin), Gelenke Sphere 0.06; Pose eingefroren, ruckt 15° in 0.05 s, wenn außerhalb des Kamera-Frustums |
| `einkaufswagen_rudel` | robot 0.6 ×3 | Signatur `cart`: Gitterkorb aus 12 Cyl 0.01 **M** `#C0C6CC`, Griff `#E8455A`, Scheinwerfer-Augen Sphere 0.05 **E** `#FFF2C8` |
| `rabattschild` | brute 0.8 | primary `#FFFFFF`, accent `#E8455A`; Prozentzahl als `Label3D` 96 px `#E8455A`, Outline 12 `#FFFFFF` |

### 5.8 Prozedurale Animation (`CharacterRig`, Namen/Dauern aus 02_TECH §8.4)

Tweens auf Pivots (`create_tween().set_parallel()`), Loops über `_process`-Phase (Sinus), damit `set_locomotion()` die Kadenz an die
Geschwindigkeit koppelt. `impact` wird zum angegebenen Zeitpunkt emittiert; der Nahkampf-**Dash** zum Ziel ist Sache des `BattlePlayer`
(0.22 s hin, `TRANS_QUAD`/`EASE_IN`, bis 1.1 m vor das Ziel; zurück in `TURN_END` 0.15 s + 0.30 s Bogen 0.4 m hoch).

| Anim | Dauer (impact) | Bewegung (humanoid; andere Bases sinngemäß) |
|---|---|---|
| `idle` | Loop 1.6 s | Torso Skal. y 1.00↔1.03; Head Rot Z ±3°; Arme ±4° X gegenphasig. Kampf: Hips −0.05 m, Torso 8° vor, Arme −25° X |
| `walk` | Loop 0.8 s (Kadenz ∝ Tempo bis 5.5 m/s) | Beine ±25° X, Arme ∓20°, Hips-Bob 0.03 m bei doppelter Frequenz (|sin|), Lean 6° |
| `run` | Loop 0.5 s | Beine ±35°, Arme ∓30°, Bob 0.05 m, Lean 12° |
| `attack` | 0.55 s (0.30) | Ausholen ArmR −140° X in 0.18 s → Schlag auf +40° X in 0.12 s → **impact** → Hitstop 0.06 s → zurück 0.19 s |
| `cast` | 0.80 s (0.55) | Arme −160° X in 0.25 s; `flash_color` = Elementfarbe, `flash_amount` 0→0.35 pulsierend 6 Hz; `Vfx.spawn(&"magic")` am Boden; Stoß nach vorn |
| `item` | 0.60 s (0.35) | ArmL −90° X, Item-Würfel (Box 0.12, Itemfarbe) erscheint an `hand_l`, `Vfx.spawn(&"sparkle")`, ArmL zurück |
| `stunt` | 1.20 s (0.80) | Sprung 1.2 m (0.3 s), Rolle 360° X (0.35 s), Landung + Kamera-Trauma 0.5. Mopsula: Drehung 720° Y mit Umhang-Flattern |
| `hit` | 0.35 s | `flash(Color.WHITE, 0.12)`; Knockback 0.15 m (+Z lokal) in 0.08 s, zurück 0.2 s; Head −15° X |
| `defend` | Loop 1.2 s | Arme gekreuzt (−100° X, ±30° Z), Skal. 0.95; Hex-Schild (Cyl 0.6/0.6/0.02, `hologram` `NOVA_CYAN`) pulsiert Alpha 0.4↔0.7 |
| `die` | 0.70 s | Party: Fall Rot X +85° (`TRANS_BOUNCE`), `overhead`-Sterne. Gegner: `flash(DANGER, 0.1)`, sinkt 0.1 m, `set_dissolve(0→1)` über 0.6 s, Kantenfarbe = Element des Todesstoßes |
| `victory` | Loop 1.0 s | Kai: ArmR −170° X + Hüpfer 0.2 m; Mopsula: 360° Y in 0.5 s, dann Sitz (Body 20° X) |

`set_highlight(true)`: Instance `highlight` 1.0 auf allen Meshes → Outline `HYPE_GOLD` ×1.6 breit, goldener Fresnel-Puls 8 Hz.
Gegner-Eigenbewegungen (Ratte Hoppel-Bob 4 Hz, Schwarm-Orbit, Spinnen-Gang mit gegenphasigen Bein-Gruppen {L0,R1,L2,R3}/{R0,L1,R2,L3}
Yaw ±18° @ 3 Hz, Krabben-Scheren alle 1.2 s, Automaten-Kiefer 0→35° in 0.12 s, Schleim Squash 1.5 Hz ±8 %, Specter-Schweben)
laufen als `idle`/`walk`-Varianten im Archetyp.

---

## 6. Umgebungs-Kit

### 6.1 Raster & Raum (02_TECH §7.3/§8.5 maßgeblich)

| Maß | Wert |
|---|---|
| Raum (`EnvKit.ROOM_SIZE`) | **16 × 16 m** (das GDD nennt 12-m-Zellen; der Code-Vertrag gilt, Kap. 12) |
| Kit-Raster | **2 m** (8 × 8 Kacheln pro Raum = `env_tiles.tile_size`) |
| Wandhöhe / -stärke | 3.5 m / 0.5 m |
| Tür | 4.0 m breit, mittig, Sturz auf 3.0 m |
| Freihaltezone | Kreis r 5 m + 3 m vor jeder Tür — Props nur im Randstreifen |
| Decke | keine; hängende Elemente (Lampen, Rohre, Kabel) auf 3.0–3.4 m, darüber Fog/Hintergrund |
| Merge | **Geometrie** (Boden + Wände + Sockel + Pfeiler) = 1 Mesh, **Props** = 1 Mesh pro Raum, beide `Materials.env()`, `cast_shadow OFF`; interaktive Objekte (Truhe, Tür, Treppe, Automat, Terminal) einzeln mit Outline |

`RoomSpec.variant` 0–3 wählt die Wand-Dekoration, `RoomSpec.seed` die Prop-Streuung (nur dieser Seed, 02_TECH).

### 6.2 Wand- und Bodenmodule (Teile des Geometrie-Merges)

| Teil | Aufbau | Farbe |
|---|---|---|
| Boden | Box 16×0.2×16 · y −0.1 (Fliesen via `env_tiles`) | `floor` |
| Wandsegment 2 m | Box 2.0×3.5×0.5; Sockel Box 2.0×0.3×0.6 (Palette `wall` × 0.7); Abschlussleiste Box 2.0×0.12×0.55 | `wall` |
| Pfeiler (Ecken) | Box 0.7×3.5×0.7 + Kapitell Box 0.9×0.3×0.9; Zone A: Cyl 0.35 + Warnband Cyl 0.36 h 0.3 auf 1.0 m `#F2C230` | `wall` × 0.8 |
| Türrahmen | 2× Box 0.5×3.0×0.6 + Sturz Box 5.0×0.5×0.6 | `#3A3A44` |
| Varianten (`variant`) | 0 = schlicht; 1 = Poster (Box 1.2×1.6×0.03 **E** 0.6 in `accent`, 2 je Raum); 2 = Rohre (2 Cyl 0.12 waagrecht auf 0.8/3.0 m, `#8A4B2A`); 3 = Graffiti (3 schräge Box-Streifen 0.05 **E** 0.4 `#E23E9B`) + Risse (Wandsegment ±4° verkippt) |
| Zone A Gleisrand | Bahnsteigkante Box 16×0.05×0.6 `#F2C230` an der Seite ohne Tür; dahinter Gleisbett −1.0 m mit Schienen Box 0.08×0.15×16 **M** (Spur 1.435 m) + Schwellen Box 2.4×0.12×0.25 alle 0.67 m |
| Zone B | Wasserrinne Box 2×0.05×16 · y −0.15 · `#1E4A40` mit `glow` 0.3 (Schimmer) |

### 6.3 Props (`PropKit.IDS`)

| ID | Aufbau | Farbe | Outline |
|---|---|---|---|
| `chest` (`ChestProp`) | Box 0.9×0.45×0.6 + Deckel-Pivot (Hinterkante) Box 0.92×0.15×0.62 + 4 Eckbeschläge Box 0.08 **M** `#CD7F32`; `open()`: Deckel 0→−110° X in 0.5 s (`TRANS_BACK`), `Vfx.spawn(&"chest_open")` | `#8A5A32` | ja |
| `stairs_down` | 10 Stufen Box 4.0×0.25×0.5 (je −0.25 y, −0.5 z), Kanten-Streifen Box 4.0×0.03×0.06 `#F2C230`; Geländer Cyl 0.04 **M**; Lichtsäule Cyl 1.6/1.6/6.0 ohne Kappen `hologram` `HYPE_GOLD` `alpha 0.15`; `Label3D` „↓ ETAGE 2“ | `#6E6A72` | ja |
| `safe_door` | Rahmen + 2 Schiebeflügel Box 2.0×2.8×0.15 (je 1.9 m seitwärts in 0.5 s), Leuchtstreifen Box 0.1 **E** `EXIT_GREEN`, `Label3D` „SAFE ROOM“ | `#4A5A60` | ja |
| `vending_machine` | Box 1.0×1.9×0.8 `#C2185B`; Fenster Box 0.6×1.1×0.02 **E** 0.8 `#FFE9B0`; 4×3 Produkte Box 0.1 bunt; Münzschlitz **E** `NOVA_CYAN`; Kopfschild Box 1.0×0.25×0.1 **E** `NOVA_MAGENTA` + `Label3D` „AUTOMAT“ (bewusst anders als der blaue Fahrscheinfresser) | | ja |
| `save_terminal` | Konsole Box 0.6×1.1×0.5 `#3A3A44` + Pult Box 0.6×0.05×0.4 (−30° X) mit Display **E** `NOVA_CYAN` + Mini-Ikosaeder 0.1 `hologram` | | ja |
| `couch` | Sockel Box 2.0×0.45×0.9; Lehne Box 2.0×0.6×0.25 hinten; Armlehnen 2× Box 0.25×0.6×0.9; Kissen 2× Capsule 0.12/0.9 liegend; Decke Box 0.6×0.03×0.9 `#3AA9A0` | `#7A3B5A` | nein |
| `crate` | Box 0.8³ (± 0.2 je Seed) + 2 Latten Box 0.84×0.1×0.84 `#6B4A2E`; Yaw ±15°, Stapel ≤ 3 | `#8A5A32` | nein |
| `barrel` | Cyl 0.30/0.30/0.90 + 2 Reifen Torus 0.29/0.33 **M**; Giftfass `#F2C230` + Deckel **E** `#7CC242` | `#3E6B4A` | nein |
| `bench` | Sitz Box 1.8×0.08×0.45 + Lehne Box 1.8×0.4×0.06 + 2 Füße Box **M** | `#2F6FB3` | nein |
| `pillar` | freistehend: Cyl 0.35/0.35/3.5 + Warnband | `wall` | nein |
| `lamp` | Natriumdampf: Mast Cyl 0.05/3.0 **M** + Kopf Box 0.5×0.15×0.25 + Leuchtfläche Box **E** `SODIUM` (oder Hängelampe Kabel + Hemi **E** `#FFD27A`) | `#3A3A44` | nein |
| `trash_bin` | Cyl 0.25/0.22/0.8 + Deckel Hemi `#2A2530` | `#3E6B4A` | nein |
| `turnstile` | Box 0.3×1.0×0.8 **M** + 3 Arme Cyl 0.02/0.4 **M**, Display **E** `EXIT_GREEN`/`LIVE_RED` | `#8A8F96` | nein |
| `poster` | Box 1.2×1.6×0.03 **E** 0.6 + Rahmen Box | `accent` | nein |
| `camera_drone` | Body Box 0.5×0.15×0.5 `#1A1420` + 4 Rotoren Cyl 0.12/0.12/0.02 (40 rad/s) + Schutzringe Torus 0.12/0.14 + Linse Sphere 0.06 **E** `LIVE_RED` (blinkt 1 Hz) | | nein |
| `billboard` | Sponsor-Tafel 3.0×1.2×0.1 mit `hologram`-Fläche + `Label3D` Sponsorname, Rahmen Box **M** | Sponsorfarbe | nein |
| `rail` | Gleisstück 2 m: 2 Schienen Box 0.08×0.15×2.0 **M** · x ±0.72 + 3 Schwellen Box 2.4×0.12×0.25 + Schotter Box 3.2×0.2×2.0 `#3B3436` | `#A8B0B8` | nein |
| `wreck` | Entgleister Wagen: Box 8.0×3.0×3.0 · (0,1.9,0) · (0,0,12) `#8A8F96`, Dach Box 8.2×0.3×3.1 `#6E6A72`, 6 Fenster Box 1.0×0.8×0.02 **E** `#FFD27A`, Frontstreifen `#F2C230`, 4 Räder Cyl 0.4/0.4/0.2 `#2A2530` (Thron der Rattenkönigin) | | nein |
| `pipe` | Cyl 0.15 (oder 0.25)/2.0 + Muffen Cyl 0.18 + Knie Sphere + Ventil Torus 0.08/0.12 `#C23B22` | `#8A4B2A` | nein |

Safe Room (`EnvKit.build_safe_room`, 12 × 10 m): Thema je Ort — Kiosk 24/7 (Theke Box 2.4×1.0×0.6 `#C23B22`, Zeitungsständer),
Pumpenhaus (2 Pumpen Cyl 0.6/1.6 `#3E6B4A`, Manometer **E**), Stellwerk (8 Hebel Cyl rot/blau, Gleisplan-Holo 2×1 m). Immer: `vending_machine`,
`save_terminal`, `couch`, Lootbox-Regal (Box 1.6×1.2×0.4 `#5A4A3E`), TV-Wand (Box 1.2×0.75×0.12, Bildschirm-Mesh zeigt Hype-Farbe per `flash_color`).

### 6.4 Kollision

Wie 02_TECH: Layer 1 `world` (Boden-Box + eine `BoxShape3D` pro durchgehendem Wandlauf, max. 2 pro Kante wegen Tür + große Props),
2 `player`, 3 `enemy`, 4 `interact`. Art-Regel: Kollisionsformen sind **immer** Boxen/Zylinder der Rezeptmaße, nie Trimesh;
hängende Deko ohne Kollision; Kamera-`SpringArm3D` nur gegen Layer 1.

---

## 7. VFX (`Vfx.KINDS`, nur `CPUParticles3D`)

Partikel = `QuadMesh` + `vfx_additive`. `Vfx.spawn()` hält pro Kind einen Pool von 4 Instanzen (`restart()` statt Neubau).
Darstellungs-Zufall (Jitter) darf `randf()` nutzen (02_TECH §0), nie den Kern-RNG.

| Kind | Aufbau | Partikel | Dauer |
|---|---|---|---|
| `hit` | one_shot, explosiveness 1, Spread 70°, v 4–7 m/s, g −6, Größe 0.08–0.16, `shape 3` `#FFF2C8`; Ring-Quad `shape 2` Skal. 0→1.2 m in 0.12 s; Hitstop 0.06 s | 14 | 0.30 s |
| `crit` | wie `hit` + 24 Sterne `shape 1` `HYPE_GOLD`; Kamera-Trauma 0.35; Vollbild-Flash `PAPER` 30 % 0.05 s | 38 | 0.40 s |
| `slash` | 3 gestreckte Funken-Quads (1.2×0.08 m) im Bogen, `PAPER` → transparent | 3 | 0.30 s |
| `bite` | 2 Reihen à 4 Dreiecks-Funken (`shape 3`) schnappen zusammen | 8 | 0.30 s |
| `magic` | Bodenring `shape 2` 1.5 m in Elementfarbe + 12 aufsteigende Punkte | 13 | 0.60 s |
| `fire` | 18 Punkte aufwärts 1.5–3 m/s, Farbverlauf `#FFE08A`→`#FF6A2B`→`#7A1F1F`/α 0; Licht-Blitz: Raum-Omni +2.0 für 0.3 s (kein neues Licht) | 18 | 0.60 s |
| `ice` | 12 Splitter: Mesh `PrismMesh 0.08×0.25×0.08` + `hologram` `#7FD8FF`, radial 2–3 m/s; Frost-Ring Cyl 1.0/1.0/0.02 `hologram` Skal. 0→1 | 12 | 0.60 s |
| `shock` | 3 Zickzack-Bolzen aus je 6 Box 0.03×0.3 `glow` `#F5E642` energy 4, alle 0.05 s neu gejittert (6×); + 10 Funken `#9FE8FF` | 10 | 0.30 s |
| `toxic` | 16 Ring-Blasen `#7CC242`, aufwärts 0.5–1 m/s | 16 | 1.00 s |
| `light` / `dark` | 20 Sterne `PAPER` spiralförmig / 20 Punkte `#3E2E66` einwärts | 20 | 0.80 s |
| `heal` | 20 Sterne `#6BFFB0`, `tangential_accel 3` (Spirale); Ziel-`flash(#6BFFB0)` | 20 | 0.80 s |
| `buff` / `debuff` | 2 Ringe aufsteigend (Status-Farbe) / absteigend | 12 | 0.70 s |
| `ko` | `DANGER`-Ring + 3 Sterne kreisen am `overhead` | 6 | 1.00 s |
| `levelup` | Gold-Säule Cyl 0.6/0.6/3.0 ohne Kappen `hologram` `HYPE_GOLD`, Skal. y 0→1 in 0.25 s (`TRANS_BACK`); 32 Sterne; `Label3D` „LEVEL UP!“ | 32 | 1.50 s |
| `sponsor` | Drohnen-Drop, s. 7.2 | 40 | 1.50 s |
| `confetti` | 40 Box-Partikel (Mesh `BoxMesh 0.04` mit `Materials.toon_vc({"outline": false})`, Farbe über Partikelfarbe) in `NOVA_MAGENTA`/`HYPE_GOLD`/`NOVA_CYAN`/`EXIT_GREEN`, g −4, Drehung | 40 | 1.20 s |
| `smoke` | 10 Punkte `#E8E8E8` α 0.4, Größe 0.2→0.6, v 1.2 m/s aufwärts | 10 | 1.00 s |
| `sparkle` | 8 Sterne `PAPER` | 8 | 0.50 s |
| `stairs_glow` | 12 Punkte `HYPE_GOLD` steigen in der Lichtsäule (Loop-Variante, `one_shot false`) | 12 | Loop |
| `chest_open` | 24 Sterne in Rarität-/Tierfarbe + Ring | 25 | 0.80 s |

Budget: ≤ 400 Partikel gleichzeitig, ≤ 6 aktive Emitter. Status-Loops (am Anker `overhead`, vom BattlePlayer gesetzt):
poison 3 Blasen, stun 3 Prism-Sterne `#F5D90A` kreisen r 0.25 @ 2 rad/s, slow Torus 0.35/0.40 `hologram` `#5B8DEF` am Boden,
haste 2 Prism-Chevrons `#FF7A1A`, guard Hex-Schild `#9AA7B8` α 0.15, taunt Cone 0.08/0.2 `#E8455A` hüpft 0.1 m @ 2 Hz.

### 7.1 Schadenszahlen (`Vfx.damage_number`, Stile aus 02_TECH)

`Label3D`, `billboard ENABLED`, `no_depth_test true`, `pixel_size 0.004`, `font_size 64`, `outline_size 12`, `outline_modulate INK`, `render_priority 10`.
Pop: Skal. 0.4 → 1.25 (0.08 s) → 1.0 (0.10 s); steigt **0.8 m in 0.8 s** (`EASE_OUT`), Fade-out letzte 0.25 s; mehrere am selben Ziel +0.25 m versetzt.

| style | Farbe | Größe | Zusatz |
|---|---|---|---|
| `damage` | `#FFFFFF` | 64 | — |
| `weak` | `#FFE14D` | 72 | darüber „SCHWACHSTELLE!“ 40 px |
| `crit` | `#FF9A2E` | 88 | 8° Schräglage |
| `heal` | `#6BFF8A` | 64 | „+“ |
| `mp` | `MANA` | 56 | „+ MP“ |
| `resist` | `#9AA0A6` | 56 | „RESISTENT“ / „IMMUN“ (`PAPER`) |
| `miss` | `#9C93AD` | 48 | „DANEBEN“ |
| `status` | Statusfarbe | 48 | Statusname |

### 7.2 Sponsor-Drop, Lootbox, Übergänge

**Sponsor-Drop (1.5 s, überspringbar):** `camera_drone` fliegt von (8, 6, 4) per Bézier nach (0, 3, 1) in 0.6 s; Paket Box 0.4 in Sponsorfarbe
+ Kreuzband `PAPER` an Fallschirm (Hemi 0.4 `PAPER`) fällt 0.5 s; Landung: `confetti` + `billboard`-Holo 1.0 s.
Sponsorfarben: Glückwasser `#4FC3F7`, KRAWUMM `#FF7A1A`, Panzerkeks `#C99A5B`, Sorgenfrei `#2BD66B`, NovaNet `#FF2E88`, Brutzel-Burger `#E8455A`, DoomScroll+ `#B05CFF`.

**Lootbox (Safe Room, GDD 9.4):** Bronze = Box 0.5×0.4×0.4 `#8A5A32` + Beschläge **M** `#CD7F32`; Silber = Box **M** `#C0C8D2`; Gold = Box **M** `#FFC83D` mit `vertex_emission` 0.3;
Fan = Box `#FF5FA2` + Schleife `PAPER` + Herz (2 Sphere + Cone). Tap 1/2/3: Rütteln ±6° (0.15 s), Punch 1.08, Licht in Tierfarbe 1 → 2.5 → 4 (ab Tap 2 in Raritätsfarbe des besten Wurfs).
Öffnen: Deckel −110° in 0.2 s, `chest_open` (48 Sterne), Karten (Box 0.5×0.7×0.02 mit Rand in Raritätsfarbe **E** 0.6) im Bogen 0.4 s je Karte, Rot Y 180°→0°.

**Übergänge:** Erkundung → Kampf = Pink-Flash 20 % 0.05 s, `ui_swirl` 0.7 s, 0.3 s Fade, Kamera startet `establishing`.
Kampf → Erkundung / Safe Room = Fade 0.25 s nach `INK`. Etagenkollaps = Trauma 0.6 + Deckenputz (30 Box-Brocken) + Weißblitz + Testbild.
Game Over = `ui_tv_overlay.test_card` 0→1 in 0.2 s, Buttons nach 1.5 s.

---

## 8. Kamerasprache

### 8.1 Erkundung (`scenes/exploration/camera_rig.gd`, Werte 02_TECH §7.3)

`SpringArm3D` **7.0 m**, Pitch **−38°** (−65…−15), FOV **60**, Kollisionsmaske `world`, Stick-Yaw 2.6 rad/s. Art-Zusätze:
- Pivot auf Kai + 1.4 m, Follow-Lerp 10/s; `SpringArm3D.shape = SphereShape3D(0.25)`, `margin 0.25`.
- Schwung-Kick: FOV 60→57→60 in 0.15 s. Gegner bemerkt Kai: Armlänge 7.0→6.3→7.0 in 0.4 s.
- Bei Kollision Arm sofort kürzen (keine Clipping-Frames), Rückkehr mit 4 m/s.
- Safe Room: feste Kamera am Anker `&"camera"` (FOV 50), kein Orbit.

### 8.2 Kampf-Bühne (`battle_stage.gd`)

Arena = `EnvKit.build_battle_arena()` (Bühne r 9 m). Party blickt −Z, Gegner +Z.

| Slot | Position |
|---|---|
| Party 0 / 1 (Kai / Mopsula) | (−1.3, 0, 3.0) / (1.3, 0, 3.2) |
| 1 Gegner | (0, 0, −3.0) |
| 2 Gegner | (−1.4, 0, −3.0), (1.4, 0, −3.0) |
| 3 Gegner | (−2.4, 0, −2.6), (0, 0, −3.4), (2.4, 0, −2.6) |
| 4 Gegner | (−3.0, 0, −2.4), (−1.0, 0, −3.4), (1.0, 0, −3.4), (3.0, 0, −2.4) |
| Boss | (0, 0, −4.5); Rattenkönigin auf `wreck` (0, 3.0, −6.0), Party dann z +4.0 |

### 8.3 Shots (`battle_camera.gd`: `shot(name, ctx)`)

Übergang **Cut** oder **Blend** (Tween Position + Blickpunkt + FOV, `TRANS_SINE`, `EASE_IN_OUT`).

| Shot | Position | Blickpunkt | FOV | Dauer / Bewegung | Übergang |
|---|---|---|---|---|---|
| `establishing` (BATTLE_START) | (6.5, 4.2, 9.0) → (4.5, 3.4, 8.0) | (0, 0.9, −0.5) | 50 | Dolly **1.2 s** | Cut nach Swirl |
| `boss_intro` | (0, 2.0, −12) hinter dem Boss → `establishing` | Boss-Kopf | 40→50 | Kranfahrt **2.5 s**, Namensbanner | Cut |
| `command` (Akteur A) | A + (0.9·s, 1.75, 2.3), s = +1 Kai, −1 Mopsula | Gegnermitte + (0, 0.9, 0) | 48 | ±0.03 m Atem-Drift | Blend 0.35 s |
| `target_select` | wie `command` | Ziel + (0, 1.0, 0) | 44 | Blickpunkt-Blend je Zielwechsel | Blend 0.2 s |
| `action_side` (Nahkampf) | (7.0·side, 2.2, 0.0) | Mitte Akteur–Ziel + (0, 1.0, 0) | 45 | folgt Dash | Cut |
| `skill_closeup` | A + A.forward·1.6 + (0.35, 0.9·Höhe, 0) | `head`-Anker von A | 32 | Push-in 0.2 m in 0.55 s (bis `impact`) | Cut |
| `skill_release` | Ziel + (2.5, 2.0, 4.5); Flächen-Skill: `establishing` | Ziel + (0, 0.9, 0) | 50 | statisch | Cut bei `impact` |
| `enemy_turn` | Gegner + (−1.2, 2.0, −2.6) | Party-Mitte + (0, 0.9, 0) | 50 | 0.6 s halten | Blend 0.3 s |
| `stunt` | Orbit um A, r 3.0, h 1.5, 90° in 1.2 s | A + (0, 1.0, 0) | 40 | — | Cut |
| `sponsor_drop` | (3.0, 2.5, 6.0) | Drohne | 50 | folgt | Blend 0.3 s |
| `victory` | Orbit um (0, 0, 3.1): r 3.8, h 1.3, 210°→150° in 3.0 s | Party-Mitte + (0, 0.9, 0) | 40 | dann Ergebnis-Panel | Cut |
| `defeat` | Push-in 0.5 m in 1.5 s auf KO-Figur | KO-Figur | 45 | — | Blend 0.5 s |

**Kamera-Trauma:** Offset `0.25 m × trauma²` (Rauschen 18 Hz), Roll `3° × trauma²`, Abbau 1.5/s. Treffer 0.2, Krit 0.35, Stunt 0.5, Zug 0.6, Phasenwechsel 0.4.
Optionsmenü „Kamera-Wackeln“ 0–100 %. Kampftempo × 2 / Autoplay: Shot-Dauern × 0.5, `skill_closeup` entfällt.

---

## 9. UI-Art-Direction (TV-Broadcast)

### 9.1 Grundform

Referenz **1280 × 720**, `canvas_items` + `expand`, Layout nur über Anker/Container, Wurzel `SafeAreaContainer` (02_TECH §10.4).
Panels mit **12° Schrägschnitt** außen (`StyleBoxFlat.skew = Vector2(0.21, 0)` für Bauchbinden), `bg_color C_PANEL`, `border_width 2` `C_ACCENT_2` @ 60 %,
`corner_radius 0`, `content_margin 12/8`, Schatten 4 px `#000000` @ 50 %. Fokus: `border_width 3` `C_ACCENT_2` + Pfeil links (pulsiert Alpha 0.6↔1 @ 2 Hz).
Bewegung: Panels gleiten 16 px + Fade in 0.18 s (`TRANS_CUBIC`, `EASE_OUT`); Zähler zählen hoch (Zuschauer 0.6 s, Follower 1.0 s).
Ein Theme für alles: `UiTheme.get_theme()` (`scenes/ui/theme/ui_theme.gd`, M0); die Werte dieses Kapitels sind die Art-Vorgaben dafür.

### 9.2 Broadcast-Elemente

| Element | Position (720p) | Look |
|---|---|---|
| LIVE-Badge | oben links (16, 16), 80×30 | Pille `LIVE_RED`, Punkt ● pulsiert 1 Hz, „LIVE“ 20 px fett `PAPER` |
| Zuschauer | rechts daneben | Augen-Icon (`Polygon2D`) + Zahl 22 px Monospace, Tausenderpunkt; Anstieg kurz `HEAL`, Abfall `DANGER` (0.4 s) |
| Follower | darunter | „♥ 1.234“ 16 px `C_TEXT_DIM` |
| Timer | oben Mitte | 38 px Monospace in Schrägbox; < 5:00 `SODIUM`, < 1:00 `LIVE_RED` + Puls 2 Hz (1.0↔1.08) |
| Hype-Leiste | oben rechts, 320×14 | Verlauf `NOVA_MAGENTA`→`HYPE_GOLD`, Rauten-Marker 50/75/100, Glanzlicht läuft 0.3 s bei Anstieg |
| Chat-Ticker | unten, Höhe 22 | `C_PANEL` 70 %, Text 15 px, 80 px/s, Nutzernamen in Akzentfarben |
| Sponsor-Bauchbinde | links unten über Ticker, 480×64 | Zeile 1 Sponsorname 24 px auf Sponsorfarbe, Zeile 2 Slogan 15 px auf `C_PANEL`; rein 0.25 s, steht 2.5 s, raus 0.2 s |
| M.O.D.-Textbox | unten Mitte, 740×108 | Rahmen `NOVA_CYAN`, Ikosaeder-Icon (SubViewport 64×64), Text 19 px, 45 Zeichen/s |
| REC-Ecken (Erkundung) | 4 Ecken | L-Winkel 28 px, 2 px `PAPER` @ 35 % |

Kampf-UI (GDD 14.5, auf 720p umgerechnet × 2/3): Befehlsmenü 240×280 unten links (Zeilen 42 px, aktive Zeile + 4 px Magenta-Balken);
Zugreihenfolge rechts (Eintrag 1: 64 px, weitere 42 px; Porträts = einmal pro `ModelSpec` gerenderte Köpfe, SubViewport 128², gecacht;
Rahmen `ui_party`/`ui_enemy`, Zug grau, Geist 50 %); Party-Panels 254×74 (HP-Leiste 8 px mit nachlaufendem `DANGER`-Segment 0.5 s, MP 6 px);
Element-Icons als `Polygon2D` (Tropfen, Hex-Stern, Zickzack, Blase, Faust) in Elementfarbe.

### 9.3 Schriften

| Rolle | Jetzt (ohne Dateien) | Später (OFL-Datei in `res://scenes/ui/theme/fonts/`, Standardschrift bleibt Glyphen-Fallback) |
|---|---|---|
| Fließtext, Menüs | Godot-Standardschrift (UiTheme, Umlaute vorhanden) | **Inter** |
| Überschriften / Bauchbinden | Standardschrift + `FontVariation.variation_embolden 0.5` (UiTheme) | **Anton** oder **Barlow Condensed** |
| Zahlen / Timer / Zuschauer | `SystemFont` mit `font_names = ["Consolas", "Roboto Mono", "DejaVu Sans Mono", "monospace"]`, Fallback Standardschrift (Antrag A9) | **JetBrains Mono** |
| Schadenszahlen / „LEVEL UP!“ | Standardschrift + `variation_embolden 1.0`, Outline 12–16 `INK` | **Lilita One** |

Größen (720p, UiTheme): Text 22, klein 16, Header 30, Titel 56; Ticker 15, Timer 38. Minimum 15 px.

### 9.4 Touch

Sichtbare Größen aus 02_TECH §10.3 (Stick r 90, `interact` 96, `attack` 80, `map`/`pause` 64 px; `UiTheme.MIN_TOUCH 64`). Art-Regel: **Trefferfläche ≥ 88 px**
(720p-Referenz ≙ 48 dp auf einem 6,1″-Phone im Querformat: 720 px / 2,56″ = 281 px/″ → 0,3″ = 85 px) — kleinere Buttons bekommen
unsichtbaren Rand bis 88 px, Abstand zwischen Trefferflächen ≥ 12 px. Stil: Stick-Ring `PAPER` @ 25 %, Knopf @ 60 %; Aktions-Buttons rund
`NOVA_MAGENTA` @ 80 % mit `PAPER`-Icon; Kampf-Befehle als Buttons ≥ 200×64 sichtbar / 88 hoch Treffer.

---

## 10. Asset-Upgrade-Pfad Blender → glTF 2.0

Ziel: ein `.glb` ersetzt einen Archetyp/Prop **ohne Code-Änderung**: Daten setzen `ModelSpec.gltf = "res://art/models/characters/<name>.glb"`
(02_TECH §8.4); `CharacterBuilder` verpackt das Modell in eine `CharacterRig`-Unterklasse mit derselben API.

| Bereich | Konvention |
|---|---|
| Einheiten | Metric, Unit Scale 1.0. Zielhöhen = Archetyp-Höhen (5.1) × `scale`. |
| Achsen | Godot-Vorderseite **−Z** ⇒ in Blender blickt die Figur nach **+Y** (Rückansicht Ctrl+Numpad 1 zeigt das Gesicht). Export „+Y Up“. |
| Ursprung | Mitte zwischen den Füßen, Z = 0; Transforms angewendet. |
| Struktur | Starr segmentiert: Objekte heißen wie die Pivots (`Hips`, `Torso`, `Head`, `ArmL`, …), Origin im Gelenk, Hierarchie wie 5.3. Mit Armature: Bone-Namen = Pivot-Namen. Anker als Empties `anchor_head`, `anchor_center`, `anchor_overhead`, `anchor_hand_r`, `anchor_hand_l`, `anchor_feet`. |
| Farben | Color Attribute (Face Corner) als einzige Farbquelle, Exporter „Use Vertex Color: Active“ → `COLOR_0` (linear). **Post-Import wandelt `linear_to_srgb()`** (F3), danach gilt dieselbe Shader-Konvention wie beim Kit. |
| Emission/Metall | 2. UV-Map **„EmitMetal“** (U = Emission, V = Metall, 0/1) → `TEXCOORD_1` = `UV2`. |
| Outline | Post-Import schreibt `CUSTOM0` via `MeshUtil.smoothed_normals()` — keine Blender-Arbeit. |
| Materialien | Beliebige Namen; Post-Import ersetzt **alle** durch `Materials.toon_vc({"bands": 3, "rim": 0.45})` (Figuren) bzw. `Materials.env()` (Umgebung). Leuchtteile mit Puls als eigenes Objekt mit Suffix `_glow`. |
| Shading | Auto Smooth 40°; Polycount nach Kap. 11. |
| Animationen | Actions exakt `idle, walk, run, attack, cast, hit, die, victory, defend, stunt, item` (02_TECH `CharacterRig.ANIMS`), 30 fps, Längen = Dauern aus 5.8. Loop-Flag setzt der Post-Import nach `CharacterRig.LOOPING`. Walk-Zyklus = 1.6 m Weg, Run-Zyklus = 2.75 m. |
| Impact-Frame | glTF kann keine Methodenspuren → `res://art/models/characters/<name>.anim.json` `{"attack": 0.30, "cast": 0.55, "stunt": 0.80, "item": 0.35}`; Post-Import fügt die Methodenspur `emit_impact()` ein (02_TECH §8.4). |
| Umgebung | Je Prop ein `.glb` `res://art/models/props/<prop_id>.glb` mit Maßen aus 6.3, Kollision über Import-Suffix `-colonly` (Boxen). `PropKit` nimmt das Modell, wenn vorhanden. |
| Post-Import | `res://art/kit/ptd_post_import.gd` (`@tool extends EditorScenePostImport`): Farben → sRGB, `CUSTOM0` backen, Materialien ersetzen, Loops, Methodenspur, `cast_shadow` nach 4.3. In den Import-Einstellungen jedes `.glb` eingetragen. |

---

## 11. Performance-Budget (Mobile)

Ziel: Mittelklasse 2022 (Adreno 619 / Mali-G57), Quality `low` (Default Mobile, 02_TECH §3.4: Skalierung 0.7, kein MSAA/Schatten/Glow) **60 FPS**;
Quality `high` (0.85, MSAA 2×, Schatten, Glow) **≥ 45 FPS**. Fallback Compatibility (Web/alt) 30 FPS.

| Kategorie | Budget | Stand (gemessen) |
|---|---|---|
| Tris Held | ≤ 2 500 (Hull rendert sie ein 2. Mal) | Kai 2 040, Mopsula 1 448 |
| Tris Gegner | ≤ 1 500 (Schwarm gesamt) | Rezepte aus 5.3 liegen bei 600–1 400 |
| Tris Boss | ≤ 4 000 (+ `wreck` ≤ 600) | — |
| Tris pro Raum | Geometrie ≤ 1 500, Props ≤ 2 500 | Wände = Boxen (12 Tris) |
| Tris sichtbar gesamt | ≤ 120 000 inkl. Hulls und Schattenpass | — |
| Meshes pro Figur | Held ≤ 8, Gegner ≤ 6, Boss ≤ 10 | Kai 7, Mopsula 2 |
| Draw Calls Erkundung | ≤ 150 | Raum = 2 Draws (Geometrie + Props) + Interaktives; ~9 Räume sichtbar |
| Draw Calls Kampf | ≤ 150 | 2 Helden ≈ 18 + 4 Gegner ≈ 40 (je ×2 Outline enthalten) + Arena 10 + VFX/UI 30 |
| Materialien | ≤ 24 Instanzen aus dem `Materials`-Cache | Vertex-Farben statt Material pro Farbe |
| Lichter | 1 Sonne (Schatten nur `high`) + ≤ 4 (`high`) / 2 (`low`) Omni in Reichweite | 02_TECH |
| Partikel | ≤ 400 gleichzeitig, ≤ 6 Emitter, One-Shot ≤ 48 | — |
| `Label3D` | ≤ 12 gleichzeitig (gepoolt) | — |
| Overdraw | Additive Flächen ≤ 25 % des Bildes | Lichtsäulen `alpha ≤ 0.15` |
| Bauzeit | Etage komplett ≤ 150 ms hinter dem Lade-Fade (Mesh-Cache) | — |

Messen: DebugOverlay (Layer 90) zeigt `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, FPS.
`tests/test_m4_art_kit.gd` prüft Tri-Budgets über `MeshUtil.tri_count()`. Screenshot-Prüfung in beiden Renderern:
Compatibility `--rendering-driver opengl3`; Mobile lokal mit Mesa-lavapipe (`VK_ICD_FILENAMES=<lvp_icd.json>`), Log darf kein `SHADER ERROR` und keine
„different indices“-Warnung enthalten.

---

## 12. Abweichungen & Anträge an andere Dokumente

| # | Thema | Stand | Entscheidung / Antrag |
|---|---|---|---|
| A1 | Tonemapper | 02_TECH §8.5: „filmic tonemap“ | **AgX** (Art-Entscheidung: gesättigtes Neon ohne Farbkippen; in beiden Renderern gerendert). `make_environment()` setzt `TONE_MAPPER_AGX`. |
| A2 | Vertex-Farbraum | 02_TECH: „Vertex-Colors“ ohne Farbraum | sRGB speichern + Shader-Weiche (F1); Post-Import linear→sRGB (F3). |
| A3 | Instance-Uniform-Reihenfolge | 02_TECH §8.3 listet `toon_outline` nur `flash_amount`, `dissolve` | `toon_outline` deklariert zusätzlich `flash_color`, `highlight` **zwischen** beiden, damit die Reihenfolge mit `toon` übereinstimmt (F2). |
| A4 | Raumgröße | GDD 1.3: Zellen 12 m; 02_TECH: `ROOM_SIZE 16` | Art folgt dem Code-Vertrag (16 m); GDD-Text bei Gelegenheit angleichen. |
| A5 | Erkundungskamera | GDD 2.2 (6 m, −22°, FOV 65) vs. 02_TECH §7.3 (7 m, −38°, FOV 60) | Art folgt 02_TECH. |
| A6 | Neue Props/Base (02_TECH §4.3 `MODEL_PROPS`/`MODEL_BASES`) | — | Antrag: Base `swarm`; Props `newspaper_head`, `briefcase`, `bottlecap_chain`, `cable_tangle`, `spray_cap`, `escalator_back`, `claws`, `helmet`, `shield`, `halberd`, `rat_king_tail`, `ticket_crown`, `wrench`, `axe`, `crowbar`, `cart`. Bis dahin Fallbacks aus 5.5. |
| A7 | `Materials`-Optionen | 02_TECH §8.2 | Antrag: Zusatzschlüssel `"wobble"`, `"stripes"`, `"rim_color"`, `"spec"`. |
| A8 | Ausrüstungs-Optik | — | Antrag: `items.json → visual {"props_add": [...], "colors": {...}}` optional; Darstellung mischt es vor `CharacterBuilder.build()` in den `ModelSpec`. |
| A9 | Monospace-Zahlen, Touch-Trefferfläche | `UiTheme` hat nur die Standardschrift; `MIN_TOUCH 64` | Antrag: `UiTheme` ergänzt `FONT_MONO` (SystemFont, s. 9.3) und Trefferflächen-Rand bis 88 px (9.4). |
