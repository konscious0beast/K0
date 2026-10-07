// STUB(M0) — owned by M4. Replace completely, keep the public API.
// M.O.D. hologram / screens stub.
shader_type spatial;
render_mode unshaded, blend_add;

uniform vec4 color : source_color = vec4(0.133, 0.827, 0.933, 1.0);
uniform float scan_speed = 1.5;
uniform float alpha = 0.6;

void fragment() {
	float scan = 0.75 + 0.25 * sin(UV.y * 80.0 - TIME * scan_speed * 6.0);
	ALBEDO = color.rgb * scan * alpha;
}
