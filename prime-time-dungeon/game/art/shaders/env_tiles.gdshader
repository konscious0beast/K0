// PRIME TIME DUNGEON - Environment: world-space tiles/grout/dirt, vertex color, 3 toon bands,
// screen-space hatching in shadow. No outline, no discard (early-Z on tile GPUs). Mobile + Compatibility (03_ART 3.4).
// Art extras: UV2.x = emission mask (posters, neon strips, lamp faces, water shimmer), UV2.y = metal mask
// (rails, hoops, fittings: no grout/dirt, cool sheen). Both masks are written by MeshUtil.merge().
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

#include "res://art/shaders/ptd_color.gdshaderinc"

// --- contract ---
uniform float tile_size = 2.0;                                  // m
uniform vec4 grout_color : source_color = vec4(0.10, 0.11, 0.14, 1.0);
uniform float grout_width : hint_range(0.0, 0.5) = 0.04;        // m
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.5, 1.0);
uniform float bands : hint_range(2.0, 3.0, 1.0) = 3.0;
uniform bool use_vertex_color = true;

// --- art extras ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 dirt_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform float dirt_height = 0.6;                                // m: grime creeping up walls
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.5;
uniform float hatch_spacing_px : hint_range(2.0, 24.0) = 6.0;
uniform float band_shadow : hint_range(0.0, 1.0) = 0.22;
uniform float band_mid : hint_range(0.0, 1.0) = 0.6;
uniform float vertex_emission_energy : hint_range(0.0, 16.0) = 2.5;   // x UV2.x
uniform float metal_sheen : hint_range(0.0, 2.0) = 0.6;               // x UV2.y
uniform float center_clean : hint_range(0.0, 1.0) = 0.5;              // less floor dirt within ~5 m of the mesh origin
uniform float omni_step_soft : hint_range(0.0, 0.3) = 0.12;           // ramp width of the 3 omni light steps

varying vec3 v_world;
varying vec3 v_wnormal;
varying vec2 v_local_xz;

float ptd_hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ptd_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ptd_hash2(i), ptd_hash2(i + vec2(1.0, 0.0)), f.x),
	           mix(ptd_hash2(i + vec2(0.0, 1.0)), ptd_hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local_xz = VERTEX.xz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= ptd_vertex_albedo(COLOR.rgb);
	}
	float special = clamp(UV2.x + UV2.y, 0.0, 1.0);    // emissive / metal parts: no tiles, no grime
	vec3 col = base;
	// Planar projection by dominant world normal axis.
	vec3 an = abs(v_wnormal);
	vec2 p = an.y > 0.5 ? v_world.xz : (an.x > an.z ? v_world.zy : v_world.xy);
	vec2 t = fract(p / tile_size) * tile_size;
	vec2 d = min(t, vec2(tile_size) - t);
	float grout = (1.0 - step(grout_width * 0.5, min(d.x, d.y))) * (1.0 - special);
	// per-tile brightness jitter (+-6 %)
	col *= mix(0.94 + 0.12 * ptd_hash2(floor(p / tile_size)), 1.0, special);
	col = mix(col, grout_color.rgb, grout);
	// dirt: noise blotches + grime near the floor on walls
	float n = ptd_vnoise(p * 1.3) * 0.6 + ptd_vnoise(p * 5.0) * 0.4;
	float grime = an.y > 0.5 ? 0.0 : 1.0 - smoothstep(0.0, dirt_height, v_world.y);
	float dirt = clamp(smoothstep(0.45, 0.85, n) + grime * 0.7, 0.0, 1.0) * dirt_amount * (1.0 - special);
	// cleaner floor in the room's clear zone (rooms/arena are built around their origin): enemies read better
	if (an.y > 0.5) {
		dirt *= mix(1.0 - center_clean, 1.0, smoothstep(2.5, 6.0, length(v_local_xz)));
	}
	col = mix(col, dirt_color.rgb, dirt);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	EMISSION = base * UV2.x * vertex_emission_energy;
}

float ptd_band(float x) {
	if (bands < 2.5) {
		return mix(band_shadow, 1.0, smoothstep(0.125, 0.175, x));
	}
	float b = mix(band_shadow, band_mid, smoothstep(-0.005, 0.045, x));
	return mix(b, 1.0, smoothstep(0.395, 0.445, x));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float x = ndl;
	float intensity = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		x = min(ndl, mix(-0.08, 1.0, ATTENUATION));
	} else {
		// 3 toon steps like ceil(ATTENUATION * 3) / 3, but with short ramps and a soft final cutoff, so omni pools read
		// as light, not as hard-edged decals on walls and corners (03_ART §3.4, review M4)
		float a3 = ATTENUATION * 3.0;
		float stepped = (floor(a3) + smoothstep(0.0, max(omni_step_soft, 0.001), fract(a3))) / 3.0;
		intensity = min(1.0, stepped) * smoothstep(0.0, 0.08, ATTENUATION);
	}
	float b = ptd_band(x);
	float shadow_w = 1.0 - smoothstep(-0.005, 0.045, x);
	float hatch = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing_px));
	b -= hatch * hatch_strength * shadow_w * band_shadow;
	vec3 tint = mix(shade_color.rgb, vec3(1.0), smoothstep(-0.005, 0.445, x));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * b * tint * intensity;
	if (UV2.y > 0.0) {
		// cool hard sheen on metal fittings (rails, hoops)
		vec3 h = normalize(LIGHT + VIEW);
		float s = smoothstep(0.86, 0.88, dot(NORMAL, h) * 0.5 + 0.5);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * s * metal_sheen * UV2.y * intensity / max(ALBEDO, vec3(0.08));
	}
}
