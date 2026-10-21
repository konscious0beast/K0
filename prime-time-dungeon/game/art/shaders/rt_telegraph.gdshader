// PRIME TIME DUNGEON - real-time telegraph / zone quad (07 §8.7, R2). One shared ShaderMaterial for the whole pool
// (TelegraphLayer): flat QuadMesh at y 0.04 m, depth test on, render_priority 1. Compatibility + Mobile (Decal is not
// drawn in Compatibility, 07 Anhang A1). The shape test, fill and set clipping are the text of 07 §8.7 (checked in
// both renderers, A2 / A13); additions: tg_pulse (edge pulse in the last 0.3 s), tg_stripe_speed (zones: slower
// stripes) and the material uniform `contrast` (07 §7.6 "Kontrast-Telegraphen": white 35 % fill, black stripes,
// double edge width).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// x = shape (0 circle, 1 cone, 2 ring, 3 line), y = fill progress 0..1, z = inner ratio (ring),
// w = cos(half angle) (cone)
instance uniform vec4 tg_params = vec4(0.0, 0.0, 0.0, -1.0);
instance uniform vec4 tg_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
instance uniform float tg_pulse = 0.0;         // 0..1: edge pulse amplitude (last 0.3 s before the impact)
instance uniform float tg_stripe_speed = 0.6;  // stripe scroll speed (zones 0.2)
uniform vec2 set_center = vec2(0.0);   // world XZ of the Set centre (one Set per combat: per material)
uniform float set_radius = 4.8;        // m: nothing is drawn outside the Set ring (07 §3.5.4)
uniform float contrast = 0.0;          // 1 = high-contrast telegraphs (GameSettings.telegraph_contrast)

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = tg_params.x;
	float prog = clamp(tg_params.y, 0.0, 1.0);
	float r = length(p);
	float inside = 0.0; float edge = 0.0; float fill = 0.0;
	float ew = 1.0 + contrast;             // edge width factor (contrast: double)
	if (shape < 0.5) {                      // circle
		inside = step(r, 1.0);
		edge = inside * smoothstep(1.0 - 0.10 * ew, 1.0 - 0.03 * ew, r);
		fill = inside * step(r, prog);
	} else if (shape < 1.5) {               // cone, apex at the quad centre, forward = -V
		vec2 d = normalize(p + vec2(0.0, 1e-5));
		float c = dot(d, vec2(0.0, -1.0));
		inside = step(r, 1.0) * step(tg_params.w, c);
		edge = inside * max(smoothstep(1.0 - 0.10 * ew, 1.0 - 0.03 * ew, r),
			1.0 - smoothstep(0.0, 0.04 * ew, c - tg_params.w));
		fill = inside * step(r, prog);
	} else if (shape < 2.5) {               // ring
		inside = step(r, 1.0) * step(tg_params.z, r);
		edge = inside * max(smoothstep(1.0 - 0.10 * ew, 1.0 - 0.03 * ew, r),
			1.0 - smoothstep(tg_params.z, tg_params.z + 0.04 * ew, r));
		fill = inside * step(r, tg_params.z + (1.0 - tg_params.z) * prog);
	} else {                                // line: whole quad, fills along -V
		inside = 1.0;
		edge = max(1.0 - smoothstep(0.0, 0.06 * ew, 1.0 - abs(p.x)), 1.0 - smoothstep(0.0, 0.03 * ew, 1.0 - abs(p.y)));
		fill = step(1.0 - UV.y, prog);
	}
	float stripes = step(0.5, fract((p.x + p.y) * 4.0 - TIME * tg_stripe_speed));
	float pulse = 1.0 + tg_pulse * 0.6 * sin(TIME * 25.0);
	float a = inside * (0.18 + 0.10 * stripes) + fill * 0.30 + edge * 0.85 * pulse;
	float in_set = step(distance(world_xz, set_center), set_radius);
	vec3 base = mix(tg_color.rgb, vec3(1.0), contrast * 0.65);
	vec3 col = mix(base, vec3(1.0), edge * 0.5);
	// contrast: black stripes on a white 35 % fill, the edge in the telegraph colour
	col = mix(col, vec3(0.0), contrast * inside * stripes * (1.0 - edge));
	col = mix(col, tg_color.rgb, contrast * edge);
	a = mix(a, max(a, inside * 0.35 + edge * 0.9), contrast);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.95) * tg_color.a * in_set;
}
