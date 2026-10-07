// STUB(M0) — owned by M4. Replace completely, keep the public API.
// Battle swirl transition stub (Router): progress 0..1 twists the snapshot and fades to tint.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D snapshot : filter_linear;
uniform vec4 tint : source_color = vec4(0.078, 0.051, 0.11, 1.0);
uniform float aspect = 1.7778;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= aspect;
	float r = length(p);
	float a = atan(p.y, p.x) + progress * 6.0 * max(1.0 - r, 0.0);
	vec2 q = vec2(cos(a), sin(a)) * r;
	q.x /= aspect;
	vec4 c = texture(snapshot, q + vec2(0.5));
	COLOR = mix(c, tint, smoothstep(0.2, 1.0, progress));
}
