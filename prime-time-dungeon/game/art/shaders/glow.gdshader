// STUB(M0) — owned by M4. Replace completely, keep the public API.
// Unshaded emissive stub (neon, stairs glow).
shader_type spatial;
render_mode unshaded;

uniform vec4 color : source_color = vec4(1.0, 0.18, 0.53, 1.0);
uniform float energy = 2.0;
uniform float pulse_speed = 0.0;

void fragment() {
	float pulse = 1.0 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb * energy * pulse;
}
