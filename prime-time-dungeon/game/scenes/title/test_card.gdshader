// PRIME TIME DUNGEON - private M6 "Sendeschluss" test card (03_ART §3.9 look: colour bars + noise), used by
// scenes/title/game_over.gd. Same bars as ui_tv_overlay's test card; no screen read. Mobile + Compatibility.
shader_type canvas_item;

uniform float test_card : hint_range(0.0, 1.0) = 1.0;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.12;

float ptd_rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	int bar = int(floor(uv.x * 7.0));
	vec3 bars[7] = vec3[7](vec3(0.75, 0.75, 0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75),
		vec3(0.0, 0.75, 0.0), vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
	vec3 c = bars[clamp(bar, 0, 6)];
	if (uv.y > 0.67) {
		c = vec3(step(0.5, fract(uv.x * 4.0)) * 0.9 + 0.05);
	}
	if (uv.y > 0.6 && uv.y <= 0.67) {
		c = vec3(0.0, 0.0, 0.75) * step(0.5, fract(uv.x * 7.0 + 0.5)) + vec3(0.08);
	}
	float n = ptd_rand(floor(uv * vec2(320.0, 180.0)) + fract(TIME) * 91.0);
	c = mix(c, vec3(n), noise_amount);
	float line = step(0.5, fract(FRAGCOORD.y * 0.5));
	c *= 1.0 - line * scanline_alpha;
	vec2 p = uv - vec2(0.5);
	c *= 1.0 - smoothstep(0.4, 0.95, length(p * vec2(1.3, 1.0))) * 0.6;
	COLOR = vec4(c * 0.85, test_card);
}
