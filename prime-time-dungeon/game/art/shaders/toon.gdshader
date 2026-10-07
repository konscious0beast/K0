// PRIME TIME DUNGEON - Toon shader for actors and interactive props. Mobile + Compatibility (03_ART 3.2).
// Contract uniforms (02_TECH 8.3) first, art extras below. Vertex data of kit meshes:
// COLOR = sRGB albedo, UV2.x = emission mask, UV2.y = metal mask, CUSTOM0.xyz = outline normals.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

#include "res://art/shaders/ptd_color.gdshaderinc"

// --- contract ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.5, 1.0);
uniform float bands : hint_range(2.0, 3.0, 1.0) = 2.0;       // 2 = shadow/lit, 3 = shadow/mid/lit
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_amount : hint_range(0.0, 4.0) = 0.25;       // rim intensity
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
// Instance uniforms: keep this exact order in toon_outline.gdshader (shared indices).
instance uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;  // target selection
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// --- art extras ---
group_uniforms cel;
uniform float band_shadow : hint_range(0.0, 1.0) = 0.30;
uniform float band_mid : hint_range(0.0, 1.0) = 0.65;
uniform float threshold_mid : hint_range(-1.0, 1.0) = 0.02;   // N.L shadow -> mid (bands = 3)
uniform float threshold_lit : hint_range(-1.0, 1.0) = 0.42;   // N.L mid -> lit (bands = 3), shadow -> lit (bands = 2: 0.15)
uniform float band_softness : hint_range(0.001, 0.2) = 0.025;
uniform float rim_width : hint_range(0.0, 1.0) = 0.22;
group_uniforms specular;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.25;
uniform float spec_size : hint_range(0.0, 1.0) = 0.10;
uniform float metal_spec_boost : hint_range(0.0, 2.0) = 0.9;  // added where UV2.y = 1
group_uniforms emission_extra;
uniform float vertex_emission_energy : hint_range(0.0, 16.0) = 3.0; // x UV2.x
uniform vec4 highlight_color : source_color = vec4(1.0, 0.79, 0.24, 1.0);
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.31, 0.63, 1.0);
group_uniforms stripes;
uniform vec4 stripe_color : source_color = vec4(0.95, 0.76, 0.19, 1.0);
uniform float stripe_mix : hint_range(0.0, 1.0) = 0.0;        // 0 = off
uniform float stripe_frequency = 6.0;                          // stripes per UV unit (UV.y)
uniform float stripe_duty : hint_range(0.0, 1.0) = 0.5;
uniform float stripe_scroll = 0.0;                             // stripes per second
group_uniforms wobble;
uniform float wobble_amount : hint_range(0.0, 0.2) = 0.0;     // meters, 0 = off
uniform float wobble_speed = 1.5;                              // Hz
group_uniforms;

varying vec3 v_obj_pos;

float ptd_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ptd_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(ptd_hash(i + vec3(0, 0, 0)), ptd_hash(i + vec3(1, 0, 0)), f.x),
	               mix(ptd_hash(i + vec3(0, 1, 0)), ptd_hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(ptd_hash(i + vec3(0, 0, 1)), ptd_hash(i + vec3(1, 0, 1)), f.x),
	               mix(ptd_hash(i + vec3(0, 1, 1)), ptd_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_obj_pos = VERTEX;
	if (wobble_amount > 0.0) {
		float w = sin(TIME * wobble_speed * TAU + VERTEX.y * 6.0 + VERTEX.x * 4.0);
		VERTEX += NORMAL * w * wobble_amount;
	}
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= ptd_vertex_albedo(COLOR.rgb);
	}
	float stripe = step(1.0 - stripe_duty, fract(UV.y * stripe_frequency + TIME * stripe_scroll));
	col = mix(col, stripe_color.rgb, stripe * stripe_mix);
	col = mix(col, flash_color.rgb, flash_amount);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;

	// Hard toon rim as emission (independent of lights), none on downward faces.
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width - 0.03, 1.0 - rim_width + 0.03, fres);
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	rim *= smoothstep(-0.5, 0.3, world_n.y);

	vec3 emi = emission_color.rgb * emission_energy;
	emi += col * UV2.x * vertex_emission_energy;
	emi += rim_color.rgb * rim * rim_amount;
	emi += flash_color.rgb * flash_amount * 0.8;
	emi += highlight_color.rgb * highlight * (0.25 + 0.15 * sin(TIME * 8.0)) * (0.4 + fres);
	if (dissolve > 0.0) {
		float n = ptd_noise(v_obj_pos * 7.0) * 0.7 + ptd_noise(v_obj_pos * 19.0) * 0.3;
		float cut = dissolve * 1.08 - 0.04;
		if (n < cut) {
			discard;
		}
		emi += dissolve_edge_color.rgb * (1.0 - smoothstep(0.0, 0.07, n - cut)) * 4.0;
	}
	EMISSION = emi;
}

float ptd_band(float x) {
	if (bands < 2.5) {
		return mix(band_shadow, 1.0, smoothstep(0.15 - band_softness, 0.15 + band_softness, x));
	}
	float b = mix(band_shadow, band_mid, smoothstep(threshold_mid - band_softness, threshold_mid + band_softness, x));
	return mix(b, 1.0, smoothstep(threshold_lit - band_softness, threshold_lit + band_softness, x));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float x = ndl;
	float intensity = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// ATTENUATION = shadow factor: shadowed pixels fall into the shadow band.
		x = min(ndl, mix(threshold_mid - 0.1, 1.0, ATTENUATION));
	} else {
		intensity = min(1.0, ceil(ATTENUATION * 3.0) / 3.0) * step(0.02, ATTENUATION); // stepped light pools
	}
	float b = ptd_band(x);
	float lit_w = smoothstep(threshold_mid - band_softness, threshold_lit + band_softness, x);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * b * mix(shade_color.rgb, vec3(1.0), lit_w) * intensity;

	float spec_amt = spec_strength + UV2.y * metal_spec_boost;
	if (spec_amt > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float size = spec_size * (1.0 + UV2.y);
		float s = smoothstep(1.0 - size - 0.01, 1.0 - size + 0.01, dot(NORMAL, h) * 0.5 + 0.5);
		// Added to DIFFUSE_LIGHT (specular_disabled per contract); divided by ALBEDO to stay white-ish.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * s * spec_amt * lit_w * intensity / max(ALBEDO, vec3(0.08));
	}
}
