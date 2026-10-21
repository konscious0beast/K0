// PRIME TIME DUNGEON - Unshaded emissive (neon tubes, stair glow, signal lamps). Mobile + Compatibility (03_ART 3.5).
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
