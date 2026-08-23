extends SceneTree

## Is the tail's inner end buried, or is its cap showing on the back?
##
## A cylinder has two flat caps. The outer one is the tip and is meant to be
## seen; the inner one is a disc that should never appear, because a tail does
## not end in a lid partway up its owner's back. Whether it shows is decided by
## one question -- is that cap inside the torso's surface -- which is a distance
## comparison and not something to judge from a render.

const BodyTypes := preload("res://scripts/data/body_type_models.gd")


func _initialize() -> void:
	print("%-6s %9s %9s %9s %9s  %s" % [
		"body", "inner_y", "inner_z", "surf_z", "margin", "verdict",
	])
	for family in ["Feli", "Cani"]:
		var spec: Dictionary = BodyTypes.silhouette(family, 90210, {"build": "heavy"})
		var tail := {}
		for raw in Array(spec.get("extras", [])):
			if str(Dictionary(raw).get("name", "")) == "Tail":
				tail = Dictionary(raw)
		if tail.is_empty():
			continue
		var at: Vector3 = tail.position
		var height := float(tail.height)
		var pitch := deg_to_rad(Vector3(tail.rotation).x)
		## A cylinder runs along its own +/-Y. A rotation about X sends local
		## `(0, -1, 0)` to `(0, -cos, -sin)` -- **minus** sine, not plus. Signed
		## the other way first, which reported the tip as the root and put the
		## root 0.33 m behind a body it is actually buried 0.27 m inside. The
		## arithmetic was wrong in a way the verdict column stated confidently.
		var inner := at + Vector3(
			0.0, -height * 0.5 * cos(pitch), -height * 0.5 * sin(pitch)
		)
		var tip := at + Vector3(
			0.0, height * 0.5 * cos(pitch), height * 0.5 * sin(pitch)
		)
		## The torso's surface at that height, from the capsule profile the body
		## is actually built from.
		var torso: Dictionary = spec.get("torso", {})
		var torso_y := float(spec.get("torso_y", 1.1))
		var torso_height := float(torso.get("height", 0.9))
		var up := (inner.y - torso_y) / maxf(torso_height, 0.001)
		var surface := BodyTypes._torso_radius_at(torso, up)
		var margin := surface - absf(inner.z)
		print("%-6s %9.3f %9.3f %9.3f %9.3f  %s  tip z %.3f" % [
			family, inner.y, inner.z, surface, margin,
			"root buried" if margin > 0.0 else "ROOT CAP PROUD %.3f m" % -margin,
			tip.z,
		])
	quit()
