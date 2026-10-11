// PRIME TIME DUNGEON - cooldown / GCD sweep of the real-time action bar (07 §8.2, R3). ONE ShaderMaterial shared by
// every slot ColorRect of the bar (and the partner button); per slot only the instance uniforms differ, so all sweeps
// batch into one canvas draw call (measured in Compatibility and Mobile, 07 Anhang A3/A3b). The shader of 07 §8.2 with
// its two constants as material uniforms (shared by every slot; test_m0_compile_all wants material uniforms).
shader_type canvas_item;

instance uniform float cd_left = 0.0;    // 0..1 remaining cooldown (clockwise from 12 o'clock)
instance uniform float gcd_left = 0.0;   // 0..1 remaining GCD (thin outer ring)
uniform vec3 shade = vec3(0.05, 0.03, 0.08);       // the dark of the cooldown part
uniform float shade_alpha : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.x, -p.y);
	float t = (ang < 0.0 ? ang + 6.2831853 : ang) / 6.2831853;
	float dark = step(1.0 - cd_left, t) * step(0.0001, cd_left);
	float r = length(p);
	float ring = step(0.86, r) * step(r, 1.0) * step(1.0 - gcd_left, t) * step(0.0001, gcd_left);
	COLOR = vec4(mix(shade, vec3(1.0), ring), max(dark * shade_alpha, ring * 0.8));
}
