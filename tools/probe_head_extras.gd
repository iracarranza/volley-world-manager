extends SceneTree

## What is actually attached near a Feli's head?
##
## The jointed drafts show four small skin-coloured spikes on one side of the
## skull. A tinting pass failed to colour them, which rules nothing in or out --
## so this lists every cosmetic the silhouette carries, with its parent and its
## distance from the head centre, and lets the table say what they are.

const BodyTypes := preload("res://scripts/data/body_type_models.gd")


func _initialize() -> void:
	for joints in [false, true]:
		BodyTypes.draw_joints = joints
		var spec: Dictionary = BodyTypes.silhouette("Feli", 90210, {
			"palette_index": 0, "marking": "tabby",
			"ears": "tall", "muzzle": "standard", "build": "heavy",
		})
		var head_y := float(spec.get("head_y", 1.74))
		var head_r := float(Dictionary(spec.get("head", {})).get("radius", 0.18))
		print("draw_joints=%s   head_y %.3f  head_radius %.3f" % [joints, head_y, head_r])
		print("  %-20s %-24s %8s %8s" % ["name", "parent", "radius", "d_head"])
		for raw in Array(spec.get("extras", [])):
			var part := Dictionary(raw)
			var at: Vector3 = part.get("position", Vector3.ZERO)
			## Only meaningful for parts hung on BodyPivot; a part on an arm node
			## is in that bone's space and its distance here would be a fiction.
			var on_body := str(part.get("parent", "")) == "BodyPivot"
			var d := (at - Vector3(0.0, head_y, 0.0)).length() if on_body else NAN
			print("  %-20s %-24s %8.3f %8s" % [
				str(part.get("name", "?")), str(part.get("parent", "?")),
				float(part.get("radius", 0.0)),
				"%.3f" % d if on_body else "-- (bone)",
			])
		print("")
	quit()
