// PRIME TIME DUNGEON - TV overlay, quality LOW: scanlines + vignette as alpha darkening, "Sendeschluss" test card.
// No screen read (no hint_screen_texture -> no full-screen backbuffer copy, 03_ART F7). Fullscreen ColorRect in
// ShowOverlay (layer 40). The HIGH variant is ui_tv_overlay_aberration.gdshader (same uniforms).
shader_type canvas_item;

// --- contract (02_TECH 8.3) ---
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
// contract default (02_TECH 8.3); unused in LOW (see _aberration)
uniform float aberration : hint_range(0.0, 4.0) = 0.6;

// --- art extras ---
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
	float line = step(0.5, fract(FRAGCOORD.y * 0.5));
	float vig = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.3, 1.0))) * vignette;
	float dark = 1.0 - (1.0 - line * scanline_alpha) * (1.0 - vig);  // black with this alpha (= high variant)
	COLOR = vec4(ptd_card(UV) * test_card, max(dark, test_card));
}
