// STUB(M0) — owned by M4. Replace completely, keep the public API.
// Environment stub: world-space tiles/grout, vertex color, own light(), no outline.
shader_type spatial;

uniform float tile_size = 2.0;
uniform vec4 grout_color : source_color = vec4(0.1, 0.12, 0.14, 1.0);
uniform float grout_width = 0.04;
uniform float dirt_amount = 0.3;
uniform vec4 shade_color : source_color = vec4(0.29, 0.24, 0.47, 1.0);
uniform float bands = 3.0;
uniform bool use_vertex_color = true;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = use_vertex_color ? COLOR.rgb : vec3(0.6);
	vec2 cell = fract(world_pos.xz / max(tile_size, 0.01));
	float g = step(cell.x, grout_width) + step(cell.y, grout_width);
	ALBEDO = mix(base, grout_color.rgb, clamp(g, 0.0, 1.0)) * (1.0 - dirt_amount * 0.1);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float steps = max(bands, 1.0);
	float banded = clamp(floor(ndl * steps + 0.5) / steps, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(shade_color.rgb, vec3(1.0), banded) * LIGHT_COLOR / PI;
}
