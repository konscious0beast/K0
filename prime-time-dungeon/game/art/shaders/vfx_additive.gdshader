// PRIME TIME DUNGEON - Additive billboard particle sprite, texture-free. Mobile + Compatibility (03_ART 3.6).
// Use as material of the QuadMesh of a CPUParticles3D. Final color = color * particle COLOR (sRGB, F1).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://art/shaders/ptd_color.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform int shape : hint_range(0, 3) = 0;                     // extra: 0 dot, 1 star, 2 ring, 3 spark
uniform float energy : hint_range(0.0, 8.0) = 2.0;            // extra
uniform bool billboard = true;                                // extra: false = keep mesh orientation (slash arcs)

void vertex() {
	if (billboard) {
		// Billboard keeping particle scale (like BaseMaterial3D BILLBOARD_PARTICLES).
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float s = max(softness, 0.01);
	float a;
	if (shape == 1) {
		a = clamp(1.0 - (abs(p.x) * abs(p.y) * 18.0 + r * 0.9), 0.0, 1.0);
	} else if (shape == 2) {
		a = 1.0 - smoothstep(0.0, 0.25 * s, abs(r - 0.75));
	} else if (shape == 3) {
		a = (1.0 - smoothstep(0.0, 0.5 * s, abs(p.x))) * (1.0 - smoothstep(0.6, 1.0, abs(p.y)));
	} else {
		a = 1.0 - smoothstep(1.0 - s, 1.0, r);
	}
	ALBEDO = color.rgb * ptd_vertex_albedo(COLOR.rgb) * energy * a * color.a * COLOR.a;
}
