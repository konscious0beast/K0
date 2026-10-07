// STUB(M0) — owned by M4. Replace completely, keep the public API.
// Toon shading stub: all uniforms of 02_TECH §8.3. Instance uniform order is binding (same as toon_outline).
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = false;
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.5, 1.0);
uniform float bands = 2.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_amount = 0.25;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
instance uniform float flash_amount = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float highlight = 0.0;
instance uniform float dissolve = 0.0;

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = mix(base, flash_color.rgb, clamp(flash_amount, 0.0, 1.0));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount;
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * rim + vec3(highlight * 0.25);
	if (dissolve >= 0.999) {
		discard;
	}
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float steps = max(bands, 1.0);
	float banded = clamp(floor(ndl * steps + 0.5) / steps, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(shade_color.rgb, vec3(1.0), banded) * LIGHT_COLOR / PI;
}
