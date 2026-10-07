// STUB(M0) — owned by M4. Replace completely, keep the public API.
// Inverted-hull outline stub (next_pass of toon). Instance uniforms in the same order as toon.gdshader.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.078, 0.051, 0.11, 1.0);
uniform float outline_width = 0.025;
instance uniform float flash_amount = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float highlight = 0.0;
instance uniform float dissolve = 0.0;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = mix(outline_color.rgb, flash_color.rgb, clamp(flash_amount, 0.0, 1.0) * 0.5) + vec3(highlight * 0.1);
	if (dissolve >= 0.999) {
		discard;
	}
}
