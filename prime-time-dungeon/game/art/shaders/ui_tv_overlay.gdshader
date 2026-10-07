// STUB(M0) — owned by M4. Replace completely, keep the public API.
// TV overlay stub: scanlines + vignette as darkening (does not read the screen).
shader_type canvas_item;

uniform float scanline_alpha = 0.08;
uniform float vignette = 0.35;
uniform float aberration = 0.6;

void fragment() {
	float scan = step(0.5, fract(FRAGCOORD.y * 0.5)) * scanline_alpha;
	vec2 p = UV - vec2(0.5);
	float vig = smoothstep(0.35, 0.85, length(p)) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(scan + vig + aberration * 0.0, 0.0, 1.0));
}
