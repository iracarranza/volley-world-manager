extends Node

## Which body parts are mostly outline?
##
##   xvfb-run -a godot --path . res://tools/body_ink_weight.tscn
##
## `_ink_node` grows an inverted hull outward on every side of a mesh: 0.018 m
## for the parts named in `INK_BODY_PARTS`, 0.030 m for everything else. That is
## deliberate -- cosmetics take the heavier line -- and it is also what the face
## fix found bursting through the head, where an eye 0.053 m across rendered at
## 0.113 m because the hull was bigger than the mark.
##
## No body part name is in `INK_BODY_PARTS`, so every ear, wing, muzzle, brow and
## blush takes the 0.030 m weight. This measures each part's thinnest dimension
## against the hull it carries, because that ratio is the whole question: below
## 1.0 the outline is larger than the thing it outlines.

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const ACTOR_SCRIPT := preload("res://scenes/components/player_actor_3d.gd")
const BODY_TYPES: Array[String] = [
	"Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi",
]
## Every name `body_type_models.gd` authors, and nothing else.
const BODY_PARTS: Array[String] = [
	"Stem", "Muzzle", "EarRight", "EarLeft", "Tail", "WingPrimaryRight",
	"WingPrimaryLeft", "WingCovertRight", "WingCovertLeft", "TailFeathers",
	"Nose", "Neck", "Hood", "Crest", "Collar", "Cap", "BrowRight", "BrowLeft",
	"Blush", "Beak",
]


func _ready() -> void:
	print("%-8s %-18s %9s %7s %7s   %s" % [
		"body", "part", "thinnest", "hull", "ratio", "verdict",
	])
	for body_type in BODY_TYPES:
		var actor: Node3D = ACTOR.instantiate()
		add_child(actor)
		actor.configure(1, true, "Probe", "Right", {
			"height_cm": 186.0, "mass_kg": 82.0, "wingspan_cm": 191.0,
			"body_type": body_type,
		})
		await get_tree().process_frame
		_walk(actor, body_type)
		actor.queue_free()
	print("\nratio = thinnest dimension / (hull * 2)")
	get_tree().quit()


func _walk(node: Node, body_type: String) -> void:
	for child in node.get_children():
		_walk(child, body_type)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if mesh_instance.name == "Ink":
		return
	if str(mesh_instance.get_meta("ink", "")) == "none":
		return
	## Only the parts the body models author. Shadow, focus ring and the
	## signature VFX are flat by design and `_ink_node` skips the first two by
	## identity, so measuring them says nothing about the bodies.
	if not str(mesh_instance.name) in BODY_PARTS:
		return
	## The *second* smallest dimension, not the smallest. A mark is meant to be
	## thin in one axis; what the face fix measured was an eye's width against
	## the hull, because that is the axis a viewer sees the outline eat into.
	var size := mesh_instance.mesh.get_aabb().size
	var axes := [size.x, size.y, size.z]
	axes.sort()
	var thinnest := float(axes[1])
	var hull: float = ACTOR_SCRIPT._ink_weight_for(mesh_instance)
	var ratio := thinnest / maxf(hull * 2.0, 0.0001)
	if ratio >= 2.0:
		return
	print("%-8s %-18s %9.4f %7.3f %7.2f   %s" % [
		body_type, str(mesh_instance.name), thinnest, hull, ratio,
		"MOSTLY OUTLINE" if ratio < 1.0 else "outline-heavy",
	])
