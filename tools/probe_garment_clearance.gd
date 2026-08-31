extends Node

## Does a garment shell clear the outline of the limb inside it?
##
##   xvfb-run -a godot --path . res://tools/garment_clearance.tscn
##
## The dashing reported under the sleeve, above the shorts and at the neckline
## has the signature of two nearly-coincident surfaces, and there is a reason to
## expect one here: `_add_garments` sizes every shell as a *multiple* of the limb
## radius (sleeve 1.30, shorts 1.28) while `_ink_node` grows the limb's hull by a
## fixed 0.018 m. A proportional clearance and an absolute grow only agree at one
## radius, so a thin limb closes the gap and a thick one opens it.
##
## Reported per body type because that is the axis the two disagree on: the same
## 1.30 multiplier buys 0.026 m on an Ursi arm and half that on an Avi's.

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const ACTOR_SCRIPT := preload("res://scenes/components/player_actor_3d.gd")
const BODY_TYPES: Array[String] = [
	"Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi",
]
## Each garment, the bone it hangs on, and the mesh it is supposed to cover.
const GARMENTS: Array = [
	["SleeveRight", "BodyPivot/RightArm", "BodyPivot/RightArm/Mesh"],
	["SleeveLeft", "BodyPivot/LeftArm", "BodyPivot/LeftArm/Mesh"],
	["ShortsLegRight", "BodyPivot/RightLeg", "BodyPivot/RightLeg/Mesh"],
	["ShortsLegLeft", "BodyPivot/LeftLeg", "BodyPivot/LeftLeg/Mesh"],
]


func _ready() -> void:
	print("%-8s %-16s %8s %8s %8s %9s %9s   %s" % [
		"body", "garment", "limb r", "hull", "limb+ink", "shell in", "clear",
		"verdict",
	])
	for body_type in BODY_TYPES:
		var actor: Node3D = ACTOR.instantiate()
		add_child(actor)
		actor.configure(1, true, "Probe", "Right", {
			"height_cm": 186.0, "mass_kg": 82.0, "wingspan_cm": 191.0,
			"body_type": body_type,
		})
		await get_tree().process_frame
		_garments(actor, body_type)
		_collar(actor, body_type)
		actor.queue_free()
	print("\nclear = shell's narrow radius - (limb radius + the limb's ink hull).")
	print("Below zero the limb's outline is outside the garment and renders")
	print("through it; within a millimetre or two the two surfaces are parallel")
	print("and coincident, which is the dash.")
	get_tree().quit()


func _garments(actor: Node3D, body_type: String) -> void:
	for entry in GARMENTS:
		var bone := actor.get_node_or_null(NodePath(str(entry[1])))
		if bone == null:
			continue
		var shell := bone.get_node_or_null(NodePath(str(entry[0]))) as MeshInstance3D
		var limb := actor.get_node_or_null(NodePath(str(entry[2]))) as MeshInstance3D
		if shell == null or limb == null or shell.mesh == null or limb.mesh == null:
			continue
		## The limb across the band this shell covers, against the shell at its
		## narrowest -- that is the pair that touches first. Banded because a
		## limb is a lathe with a dome at the shoulder: its widest point is not
		## necessarily under the sleeve, and comparing against it would overstate
		## the interference everywhere the sleeve sits below the dome.
		var hull: float = ACTOR_SCRIPT._ink_weight_for(limb)
		var shell_r := _radius(shell, false)
		var band := _shell_band(shell, limb)
		var limb_r := _limb_radius_in_band(limb, band)
		var clear := shell_r - (limb_r + hull)
		print("%-8s %-16s %8.4f %8.3f %8.4f %9.4f %9.4f   %s" % [
			body_type, str(entry[0]), limb_r, hull, limb_r + hull, shell_r,
			clear, _verdict(clear),
		])


## The span of the limb's own mesh that this shell sits over, as a y range in the
## limb mesh's space.
func _shell_band(shell: MeshInstance3D, limb: MeshInstance3D) -> Vector2:
	var aabb := shell.mesh.get_aabb()
	var into_limb := limb.global_transform.affine_inverse() * shell.global_transform
	var lowest := INF
	var highest := -INF
	for index in 8:
		var corner: Vector3 = into_limb * aabb.get_endpoint(index)
		lowest = minf(lowest, corner.y)
		highest = maxf(highest, corner.y)
	return Vector2(lowest, highest)


## How far the limb's surface reaches from its own axis, over that band only.
##
## Walked vertex by vertex because the limb is lathed rather than primitive:
## `BodyTypeModels._limb_mesh` builds an `ArrayMesh` with a dome at each end, so
## neither an AABB nor a `top_radius` describes its width at a given height.
func _limb_radius_in_band(limb: MeshInstance3D, band: Vector2) -> float:
	var scale := limb.global_transform.basis.get_scale().x
	var arrays := limb.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var widest := 0.0
	for vertex in vertices:
		if vertex.y < band.x or vertex.y > band.y:
			continue
		widest = maxf(widest, Vector2(vertex.x, vertex.z).length())
	return widest * scale


## One end of a tapered cylinder, in metres of court.
##
## Read off the mesh resource rather than off its AABB. A flared shell's AABB is
## the *hem* at both ends -- `size.x` is twice the larger radius, whichever end
## that is -- so an earlier version of this probe compared every sleeve at its
## widest against the arm at its widest and understated the interference by the
## whole flare. The pair that touches first is the shell's narrow end against the
## limb's wide one, and only the resource says which is which.
func _radius(mesh_instance: MeshInstance3D, widest: bool) -> float:
	var cylinder := mesh_instance.mesh as CylinderMesh
	var scale := mesh_instance.global_transform.basis.get_scale().x
	if cylinder == null:
		return mesh_instance.mesh.get_aabb().size.x * 0.5 * scale
	return (
		maxf(cylinder.top_radius, cylinder.bottom_radius) if widest
		else minf(cylinder.top_radius, cylinder.bottom_radius)
	) * scale


## The collar is the neckline case, and it is a different pair: a ring sunk into
## the torso's top rather than a tube around a limb.
func _collar(actor: Node3D, body_type: String) -> void:
	var collar := actor.get_node_or_null("BodyPivot/Collar") as MeshInstance3D
	var torso := actor.get_node_or_null("BodyPivot/Torso") as MeshInstance3D
	if collar == null or torso == null or collar.mesh == null or torso.mesh == null:
		return
	var torso_top := _world_top(torso)
	var torso_hull: float = ACTOR_SCRIPT._ink_weight_for(torso)
	var collar_top := _world_top(collar)
	var clear := collar_top - (torso_top + torso_hull)
	print("%-8s %-16s %8.4f %8.3f %8.4f %9.4f %9.4f   %s" % [
		body_type, "Collar/top", torso_top, torso_hull, torso_top + torso_hull,
		collar_top, clear, _verdict(clear),
	])


## The highest point this mesh reaches on the court, same units as the hull.
func _world_top(mesh_instance: MeshInstance3D) -> float:
	var aabb := mesh_instance.mesh.get_aabb()
	var highest := -INF
	for index in 8:
		highest = maxf(
			highest,
			(mesh_instance.global_transform * aabb.get_endpoint(index)).y,
		)
	return highest


func _verdict(clear: float) -> String:
	if clear < 0.0:
		return "OUTLINE THROUGH GARMENT"
	if clear < 0.004:
		return "coincident"
	return ""
