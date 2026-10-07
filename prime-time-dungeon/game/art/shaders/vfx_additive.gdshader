// STUB(M0) — owned by M4. Replace completely, keep the public API.
// Additive billboard particle stub.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float softness = 0.5;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = clamp(1.0 - length(p) * 2.0, 0.0, 1.0);
	float a = smoothstep(0.0, max(softness, 0.001), d);
	ALBEDO = color.rgb * COLOR.rgb * a * color.a;
}
