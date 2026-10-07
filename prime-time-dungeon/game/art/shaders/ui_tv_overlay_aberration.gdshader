// PRIME TIME DUNGEON - TV overlay, quality HIGH: reads the screen for chromatic aberration, plus scanlines,
// vignette and "Sendeschluss" test card. Same uniforms as ui_tv_overlay.gdshader (+ screen_tex). Mobile + Compatibility.
// 03_ART 3.9 / F7 (request A10): the only canvas shader that declares a screen sampler.
shader_type canvas_item;

// --- contract (02_TECH 8.3) ---
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float aberration : hint_range(0.0, 4.0) = 0.6;               // px at 720p

// --- art extras ---
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float test_card : hint_range(0.0, 1.0) = 0.0;
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
	vec2 off = (uv - 0.5) * aberration * SCREEN_PIXEL_SIZE * 2.0;
	vec3 col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	float line = step(0.5, fract(FRAGCOORD.y * 0.5));
	float vig = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.3, 1.0))) * vignette;
	col *= (1.0 - line * scanline_alpha) * (1.0 - vig);
	col = mix(col, ptd_card(UV), test_card);
	COLOR = vec4(col, 1.0);
}
