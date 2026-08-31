extends Node

## What a face is actually made of, and where each piece sits.
##
##   xvfb-run -a godot --path . res://tools/facecheck.tscn
##
## Built while adding the pupil, and kept because it is what caught the failure.
## The pupil existed, was the right size and was invisible: `SURFACE_LIFT` is in
## head radii and moved its centre 3.9 mm forward, while the eye it had to clear
## is 19.4 mm deep -- so it sat entirely inside the eye. Nothing about the render
## said which of "not built", "wrong colour" and "behind something" it was, and
## this is the difference between those three.

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BODY_TYPES: Array[String] = [
	"Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi",
]


func _ready() -> void:
	for body_type in BODY_TYPES:
		var actor: Node3D = ACTOR.instantiate()
		add_child(actor)
		actor.configure(1, true, "Probe", "Right", {
			"height_cm": 186.0, "body_type": body_type,
		})
		await get_tree().process_frame
		var head := actor.get_node_or_null("BodyPivot/Head")
		var face := head.get_node_or_null("Face") if head != null else null
		if face == null:
			print("%-8s no Face node" % body_type)
		else:
			for child in face.get_children():
				var mesh_node := child as MeshInstance3D
				if mesh_node == null or mesh_node.mesh == null:
					continue
				print("%-8s %-10s pos=%s size=%s" % [
					body_type, child.name, mesh_node.position,
					mesh_node.mesh.get_aabb().size,
				])
		actor.queue_free()
	print("\nz is forward-negative: a mark clears the one behind it by moving")
	print("further negative than that one's own front face reaches.")
	get_tree().quit()
