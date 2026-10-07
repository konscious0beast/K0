// PRIME TIME DUNGEON - Inverted-hull outline (next_pass of toon). Mobile + Compatibility (03_ART 3.3).
// outline_width = world width (m) the line has at ref_distance (6 m); constant on screen up to
// that distance (no fat lines in close-ups), thinner beyond it. Grows in clip space.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;

// --- contract ---
uniform vec4 outline_color : source_color = vec4(0.078, 0.051, 0.11, 1.0);  // Palette.INK #140d1c
uniform float outline_width : hint_range(0.0, 0.2) = 0.025;
// Instance uniforms: SAME names AND SAME declaration order as toon.gdshader, otherwise Godot assigns
// different indices and only the first material shows the value (engine warning, tested 4.7.2).
instance uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0);      // extra
instance uniform float highlight : hint_range(0.0, 1.0) = 0.0;     // extra
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// --- art extras ---
uniform vec4 highlight_color : source_color = vec4(1.0, 0.79, 0.24, 1.0);
uniform float ref_distance = 6.0;
uniform float min_width_factor : hint_range(0.0, 1.0) = 0.35;
uniform bool use_custom0_normals = true;   // smoothed normals from MeshUtil.merge() in CUSTOM0.xyz

void vertex() {
	vec3 n = NORMAL;
	if (use_custom0_normals && dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01) {
		n = normalize(CUSTOM0.xyz);
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_n = normalize(MODELVIEW_NORMAL_MATRIX * n);
	vec2 dir_px = (PROJECTION_MATRIX * vec4(view_n, 0.0)).xy * VIEWPORT_SIZE;   // aspect-correct direction
	float len = length(dir_px);
	dir_px = len > 0.0001 ? dir_px / len : vec2(0.0);
	float w = outline_width * (1.0 + 0.6 * highlight);
	float ndc_h = w * abs(PROJECTION_MATRIX[1][1]) / ref_distance;             // NDC height at ref distance; [1][1] < 0 in Godot (Y flip)
	float dist_factor = clamp(ref_distance / max(clip.w, 0.001), min_width_factor, 1.0);
	clip.xy += dir_px * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0) * ndc_h * dist_factor * clip.w;
	POSITION = clip;
}

void fragment() {
	if (dissolve > 0.6) {
		discard;
	}
	vec3 c = mix(outline_color.rgb, highlight_color.rgb * 1.5, highlight);
	ALBEDO = mix(c, flash_color.rgb, flash_amount);
}
