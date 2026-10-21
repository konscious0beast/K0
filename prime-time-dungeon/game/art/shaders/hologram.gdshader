// PRIME TIME DUNGEON - Hologram (M.O.D., screens, sponsor logos, shields). Mobile + Compatibility (03_ART 3.7).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// --- contract ---
uniform vec4 color : source_color = vec4(0.133, 0.827, 0.933, 1.0);   // Palette.NOVA_CYAN #22d3ee
uniform float scan_speed = 1.5;                                        // m/s
uniform float alpha : hint_range(0.0, 1.0) = 0.6;

// --- art extras ---
uniform float energy : hint_range(0.0, 8.0) = 1.6;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.0;
uniform float base_fill : hint_range(0.0, 1.0) = 0.25;              // face fill vs. edge glow
uniform float scanline_density = 60.0;                                // lines per meter (world Y)
uniform float flicker_hz = 9.0;
instance uniform float holo_glitch : hint_range(0.0, 1.0) = 0.0;
varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float g = step(0.5, fract(sin(floor(TIME * 20.0) * 12.9898 + VERTEX.y * 7.0) * 43758.5453));
	VERTEX.x += (g - 0.5) * 0.06 * holo_glitch;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);
	float scan = 0.55 + 0.45 * step(0.5, fract(v_world.y * scanline_density - TIME * scan_speed));
	float flick = 0.92 + 0.08 * sin(TIME * flicker_hz * TAU);
	ALBEDO = color.rgb * energy * alpha * (base_fill + fres) * scan * flick;
}
