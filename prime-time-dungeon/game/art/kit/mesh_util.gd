# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name MeshUtil extends RefCounted
## Low-poly primitives, merge with vertex colors, triangle count (02_TECH §8.2).


static func sphere(radius: float) -> SphereMesh:
	return null


static func capsule(radius: float, height: float) -> CapsuleMesh:
	return null


static func box(size: Vector3) -> BoxMesh:
	return null


static func cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	return null


## Each {"mesh": Mesh, "xform": Transform3D, "color": Color (sRGB), "emission": float = 0.0, "metal": float = 0.0}
## writes COLOR = sRGB albedo, UV2.x = emission mask, UV2.y = metal mask, CUSTOM0.xyz = smoothed normals.
static func merge(parts: Array[Dictionary]) -> ArrayMesh:
	return null


static func tri_count(mesh: Mesh) -> int:
	return 0
