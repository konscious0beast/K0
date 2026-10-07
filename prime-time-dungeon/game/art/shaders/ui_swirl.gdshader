// PRIME TIME DUNGEON - Battle swirl (Router, CanvasLayer 100, TextureRect showing the snapshot). 03_ART 3.8.
// progress 0 -> 1 in 0.7 s. Mobile + Compatibility.
shader_type canvas_item;

// --- contract ---
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D snapshot : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.078, 0.051, 0.11, 1.0);    // Palette.INK

// --- art extras ---
uniform float twist = 9.0;                                             // radians at progress 1
uniform vec4 flash_color : source_color = vec4(1.0, 0.18, 0.53, 1.0); // NOVA_MAGENTA shards
uniform float aspect = 1.7778;                                         // set by Router: width / height

void fragment() {
	vec2 asp = vec2(aspect, 1.0);
	vec2 c = (UV - 0.5) * asp;
	float r = length(c);
	float ang = progress * progress * twist * (1.0 - smoothstep(0.0, 0.9, r));
	float s = sin(ang);
	float co = cos(ang);
	vec2 rc = vec2(co * c.x - s * c.y, s * c.x + co * c.y);
	vec2 uv = rc * (1.0 - 0.35 * progress) / asp + 0.5;
	vec3 col = texture(snapshot, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float shard = step(0.5, fract(atan(c.y, c.x) * 1.909859 + progress * 2.0));   // 12 segments
	col = mix(col, flash_color.rgb, shard * smoothstep(0.3, 0.6, progress) * 0.35);
	float edge = 1.7 - progress * 1.9;
	float iris = smoothstep(edge, edge + 0.05, r * 1.4);
	col = mix(col, tint.rgb, clamp(iris + smoothstep(0.85, 1.0, progress), 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
