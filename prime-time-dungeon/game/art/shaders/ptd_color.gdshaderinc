// PRIME TIME DUNGEON - shared color helpers (#include in toon, env_tiles, vfx_additive). 03_ART F1.
// Vertex/particle/MultiMesh colors are stored sRGB. Compatibility hands COLOR to the shader already
// linearized, Mobile/Forward+ hand it over raw (tested 4.7.2) -> convert only there.
vec3 ptd_vertex_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
#endif
}
