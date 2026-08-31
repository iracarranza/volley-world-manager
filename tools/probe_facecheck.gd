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
			## The mouth against the eye, because the eye is the mark that reads
			## and the mouth is the one reported as too small. A ratio rather
			## than an absolute: heads differ in size across the six and the
			## question is legibility on each, not millimetres.
			var eye_h := 0.0
			var mouth := Vector3.ZERO
			for child in face.get_children():
				var mesh_node := child as MeshInstance3D
				if mesh_node == null or mesh_node.mesh == null:
					continue
				var box := mesh_node.mesh.get_aabb().size
				if str(child.name) == "EyeR":
					eye_h = box.y
				if str(child.name) == "Mouth":
					mouth = box
			print("%-8s mouth %6.4f wide %6.4f tall   eye tall %6.4f   mouth/eye %5.2f" % [
				body_type, mouth.x, mouth.y, eye_h,
				mouth.y / maxf(eye_h, 0.0001),
			])
		actor.queue_free()
	print("\nmouth/eye is the stroke's thickness against the eye's height. The")
	print("eye reads at roster distance, so it is the reference a mouth has to")
	print("hold its own against.")
	get_tree().quit()
