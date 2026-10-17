class_name SmoothMesh
extends RefCounted

# Rounded building blocks for characters and pets. Nothing here uses BoxMesh, so every
# silhouette stays smooth. Shapes are added to a parent and returned for further tweaks.

const SEGMENTS := 32
const RINGS := 16


static func material(color: Color, emissive: bool = false, roughness: float = 0.5) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = roughness
	if emissive:
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = 1.5
	return surface


static func _place(parent: Node3D, mesh: Mesh, surface: Material, at: Vector3, euler_degrees: Vector3, scale_by: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	instance.position = at
	instance.rotation_degrees = euler_degrees
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


# A sphere stretched to the given radii. Good for bodies, heads, wings, and plates.
static func ellipsoid(parent: Node3D, radii: Vector3, color: Color, at: Vector3, emissive: bool = false, euler_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = SEGMENTS
	mesh.rings = RINGS
	return _place(parent, mesh, material(color, emissive), at, euler_degrees, radii)


static func sphere(parent: Node3D, radius: float, color: Color, at: Vector3, emissive: bool = false) -> MeshInstance3D:
	return ellipsoid(parent, Vector3.ONE * radius, color, at, emissive)


static func capsule(parent: Node3D, radius: float, height: float, color: Color, at: Vector3, emissive: bool = false, euler_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 24
	mesh.rings = 8
	return _place(parent, mesh, material(color, emissive), at, euler_degrees, Vector3.ONE)


# A pointed cone. The tip points up (+Y) before rotation.
static func cone(parent: Node3D, radius: float, height: float, color: Color, at: Vector3, emissive: bool = false, euler_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	return _place(parent, mesh, material(color, emissive), at, euler_degrees, Vector3.ONE)


static func ring(parent: Node3D, inner: float, outer: float, color: Color, at: Vector3, emissive: bool = false, euler_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 16
	return _place(parent, mesh, material(color, emissive), at, euler_degrees, Vector3.ONE)


static func pivot(parent: Node3D, at: Vector3, tag: String, value: float) -> Node3D:
	var node := Node3D.new()
	node.position = at
	node.set_meta(tag, value)
	parent.add_child(node)
	return node