class_name MeshUtil extends RefCounted
## Low-poly primitives, merge with vertex colors, triangle count (02_TECH §8.2, 03_ART §5.2).
## Vertex data written by merge(): COLOR = sRGB albedo (Godot convention, like glTF import), UV2.x = emission mask,
## UV2.y = metal mask, CUSTOM0.xyz = smoothed normals for the outline hull (toon_outline.gdshader).
## Primitive vertex arrays are generated once per parameter set (CPU, PrimitiveMesh.get_mesh_arrays()) and cached;
## boxes are always derived from the unit box, so the cache stays small.

const SPHERE_RADIAL: int = 10
const SPHERE_RINGS: int = 6
const CAPSULE_RADIAL: int = 10
const CAPSULE_RINGS: int = 2
const CYLINDER_RADIAL: int = 8
const SMALL_PART: float = 0.06   # parts smaller than this use the "small" segment counts
const _ARRAY_CACHE_MAX: int = 2048

static var _arrays_cache: Dictionary = {}
static var _unit_box: BoxMesh = null


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var small: bool = radius < SMALL_PART
	m.radial_segments = 6 if small else SPHERE_RADIAL
	m.rings = 3 if small else SPHERE_RINGS
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	var small: bool = radius < SMALL_PART
	m.radial_segments = 6 if small else CAPSULE_RADIAL
	m.rings = 1 if small else CAPSULE_RINGS
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = 6 if maxf(top_radius, bottom_radius) < SMALL_PART else CYLINDER_RADIAL
	m.rings = 0
	if top_radius <= 0.0001:
		m.cap_top = false
	if bottom_radius <= 0.0001:
		m.cap_bottom = false
	return m


# --- art extras (03_ART §5.2) ---------------------------------------------------------------------------------------

static func cone(radius: float, height: float) -> CylinderMesh:
	return cylinder(0.0, radius, height)


static func hemisphere(radius: float) -> SphereMesh:
	var m := sphere(radius)
	m.is_hemisphere = true
	m.height = radius
	m.rings = 3
	return m


static func torus(inner_radius: float, outer_radius: float, rings: int = 10, ring_segments: int = 5) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = rings
	m.ring_segments = ring_segments
	return m


static func prism(size: Vector3, left_to_right: float = 0.5) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = left_to_right
	return m


## Open tube (cylinder without caps), e.g. light columns.
static func tube(radius: float, height: float, radial: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = radial
	m.rings = 0
	m.cap_top = false
	m.cap_bottom = false
	return m


## Scale along the part's OWN (rotated) axes: scaled_local, not scaled (03_ART F10).
static func xform(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)).scaled_local(scl), pos)


## Part dictionary shorthand: {"mesh", "xform", "color", "emission", "metal"}.
static func part(mesh: Mesh, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE,
		emission: float = 0.0, metal: float = 0.0) -> Dictionary:
	return {"mesh": mesh, "xform": xform(pos, rot_deg, scl), "color": color, "emission": emission, "metal": metal}


## parts: [{"mesh": Mesh, "xform": Transform3D, "color": Color (sRGB), "emission": float = 0, "metal": float = 0}]
## Writes COLOR = sRGB albedo, UV2.x = emission mask, UV2.y = metal mask, CUSTOM0.xyz = smoothed normals.
static func merge(parts: Array[Dictionary]) -> ArrayMesh:
	return _merge(parts, true)


## Same as merge() without CUSTOM0 (environment meshes never get an outline hull; saves the smoothing pass).
static func merge_no_hull(parts: Array[Dictionary]) -> ArrayMesh:
	return _merge(parts, false)


## Averaged normals per position -> CUSTOM0 (RGBA float). Also used by the glTF post-import.
static func smoothed_normals(verts: PackedVector3Array, norms: PackedVector3Array) -> PackedFloat32Array:
	var acc: Dictionary = {}
	var keys: Array[Vector3i] = []
	keys.resize(verts.size())
	for i in verts.size():
		var k := Vector3i((verts[i] * 1000.0).round())
		keys[i] = k
		acc[k] = (acc.get(k, Vector3.ZERO) as Vector3) + norms[i]
	var out := PackedFloat32Array()
	out.resize(verts.size() * 4)
	for i in verts.size():
		var sn: Vector3 = (acc[keys[i]] as Vector3).normalized()
		out[i * 4] = sn.x
		out[i * 4 + 1] = sn.y
		out[i * 4 + 2] = sn.z
		out[i * 4 + 3] = 1.0
	return out


static func tri_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total: int = 0
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var am: ArrayMesh = mesh
			var ix: int = am.surface_get_array_index_len(s)
			total += (ix if ix > 0 else am.surface_get_array_len(s)) / 3
		else:
			var arr: Array = _surface_arrays(mesh, s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				total += (idx as PackedInt32Array).size() / 3
			else:
				total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## Sum of tri_count() over all MeshInstance3D below `root` (inclusive); outline hulls are not meshes and not counted.
static func tri_count_tree(root: Node) -> int:
	var total: int = 0
	if root is MeshInstance3D:
		total += tri_count((root as MeshInstance3D).mesh)
	for c: Node in root.get_children():
		total += tri_count_tree(c)
	return total


## Flat-shaded icosahedron (M.O.D. core).
static func icosahedron(radius: float) -> ArrayMesh:
	var p: float = (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, p, 0), Vector3(1, p, 0), Vector3(-1, -p, 0), Vector3(1, -p, 0),
		Vector3(0, -1, p), Vector3(0, 1, p), Vector3(0, -1, -p), Vector3(0, 1, -p),
		Vector3(p, 0, -1), Vector3(p, 0, 1), Vector3(-p, 0, -1), Vector3(-p, 0, 1)]
	var f: PackedInt32Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2,
		10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, f.size(), 3):
		var a: Vector3 = v[f[i]].normalized() * radius
		var b: Vector3 = v[f[i + 2]].normalized() * radius
		var c: Vector3 = v[f[i + 1]].normalized() * radius
		var n: Vector3 = -(b - a).cross(c - a).normalized()
		for q: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.set_uv(Vector2(q.x, q.y) / maxf(radius, 0.001) * 0.5 + Vector2(0.5, 0.5))
			st.add_vertex(q)
	return st.commit()


static func clear_cache() -> void:
	_arrays_cache.clear()


# --- internals -------------------------------------------------------------------------------------------------------

static func _merge(parts: Array[Dictionary], with_hull: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	for p: Dictionary in parts:
		var mesh: Mesh = p.get("mesh", null)
		if mesh == null:
			continue
		var t: Transform3D = p.get("xform", Transform3D.IDENTITY)
		var c: Color = p.get("color", Color.WHITE)
		var mask := Vector2(float(p.get("emission", 0.0)), float(p.get("metal", 0.0)))
		if mesh is BoxMesh and (mesh as BoxMesh).subdivide_width == 0 and (mesh as BoxMesh).subdivide_height == 0 \
				and (mesh as BoxMesh).subdivide_depth == 0:
			# unit box scaled by the size → one cached array set for all boxes
			var sz: Vector3 = (mesh as BoxMesh).size
			t = t * Transform3D(Basis.from_scale(sz), Vector3.ZERO)
			if _unit_box == null:
				_unit_box = BoxMesh.new()
			mesh = _unit_box
		var det: float = t.basis.determinant()
		if absf(det) < 1e-9:
			continue
		var nb: Basis = t.basis.inverse().transposed()
		var nt := Transform3D(nb, Vector3.ZERO)
		var flip: bool = det < 0.0
		for s in mesh.get_surface_count():
			var arr: Array = _surface_arrays(mesh, s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var count: int = v.size()
			if count == 0:
				continue
			var base: int = verts.size()
			verts.append_array(t * v)
			var n_raw: Variant = arr[Mesh.ARRAY_NORMAL]
			var n2: PackedVector3Array
			if n_raw != null and (n_raw as PackedVector3Array).size() == count:
				n2 = nt * (n_raw as PackedVector3Array)
				for i in count:
					n2[i] = n2[i].normalized()
			else:
				n2 = PackedVector3Array()
				n2.resize(count)
				n2.fill(Vector3.UP)
			norms.append_array(n2)
			var cc := PackedColorArray()
			cc.resize(count)
			cc.fill(c)
			cols.append_array(cc)
			var uv_raw: Variant = arr[Mesh.ARRAY_TEX_UV]
			if uv_raw != null and (uv_raw as PackedVector2Array).size() == count:
				uvs.append_array(uv_raw as PackedVector2Array)
			else:
				var z := PackedVector2Array()
				z.resize(count)
				uvs.append_array(z)
			var m2 := PackedVector2Array()
			m2.resize(count)
			m2.fill(mask)
			uv2s.append_array(m2)
			var ix_raw: Variant = arr[Mesh.ARRAY_INDEX]
			var ix: PackedInt32Array
			if ix_raw != null and (ix_raw as PackedInt32Array).size() > 0:
				ix = (ix_raw as PackedInt32Array).duplicate()
			else:
				ix = PackedInt32Array()
				ix.resize(count)
				for i in count:
					ix[i] = i
			for i in ix.size():
				ix[i] += base
			if flip:
				for i in range(0, ix.size() - 2, 3):
					var tmp: int = ix[i + 1]
					ix[i + 1] = ix[i + 2]
					ix[i + 2] = tmp
			idx.append_array(ix)
	var out := ArrayMesh.new()
	if verts.is_empty():
		return out
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	if with_hull:
		arrays[Mesh.ARRAY_CUSTOM0] = smoothed_normals(verts, norms)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	else:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _surface_arrays(mesh: Mesh, s: int) -> Array:
	if mesh is PrimitiveMesh:
		var key: String = _prim_key(mesh as PrimitiveMesh)
		if key != "" and _arrays_cache.has(key):
			return _arrays_cache[key]
		var arr: Array = (mesh as PrimitiveMesh).get_mesh_arrays()
		if key != "":
			if _arrays_cache.size() >= _ARRAY_CACHE_MAX:
				_arrays_cache.clear()
			_arrays_cache[key] = arr
		return arr
	return mesh.surface_get_arrays(s)


static func _prim_key(m: PrimitiveMesh) -> String:
	if m.flip_faces:
		return ""
	if m is SphereMesh:
		var sm: SphereMesh = m
		return "S|%.4f|%.4f|%d|%d|%s" % [sm.radius, sm.height, sm.radial_segments, sm.rings, str(sm.is_hemisphere)]
	if m is CapsuleMesh:
		var cm: CapsuleMesh = m
		return "C|%.4f|%.4f|%d|%d" % [cm.radius, cm.height, cm.radial_segments, cm.rings]
	if m is CylinderMesh:
		var cy: CylinderMesh = m
		return "Y|%.4f|%.4f|%.4f|%d|%d|%s|%s" % [cy.top_radius, cy.bottom_radius, cy.height, cy.radial_segments,
			cy.rings, str(cy.cap_top), str(cy.cap_bottom)]
	if m is BoxMesh:
		var bm: BoxMesh = m
		return "B|%s|%d|%d|%d" % [str(bm.size), bm.subdivide_width, bm.subdivide_height, bm.subdivide_depth]
	if m is TorusMesh:
		var tm: TorusMesh = m
		return "T|%.4f|%.4f|%d|%d" % [tm.inner_radius, tm.outer_radius, tm.rings, tm.ring_segments]
	if m is PrismMesh:
		var pm: PrismMesh = m
		return "P|%s|%.4f" % [str(pm.size), pm.left_to_right]
	if m is QuadMesh:
		var qm: QuadMesh = m
		return "Q|%s|%d" % [str(qm.size), qm.orientation]
	return ""
