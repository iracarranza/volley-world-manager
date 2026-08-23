extends "res://scenes/components/signature_surge_3d.gd"

## Pixel-certification corrections for the two release silhouettes that remained
## ambiguous after the action-specific pass: Foresight was mostly hidden behind
## the actor, while Monster Block wrapped the head like a cage. Preserve the
## shared gather and all other move profiles; only move these two releases into
## the action plane the camera/player can actually read.


func _release_spec(index: int, strength: float) -> Dictionary:
	if _move == "foresight":
		var angle := TAU * float(index) / float(streams.size())
		var direction := Vector3(cos(angle), 0.10, sin(angle) * 0.34).normalized()
		return {
			"position": Vector3(0.0, contact_anchor_meters, 0.22) + direction * 0.30,
			"direction": direction,
			"length": lerpf(0.30, 0.46, strength),
			"width": 0.72,
		}
	if _move == "monster_block":
		var lane := float(index) - 2.5
		return {
			"position": Vector3(
				lane * 0.22,
				contact_anchor_meters - 0.15 + float(index % 2) * 0.20,
				0.24,
			),
			"direction": Vector3.UP,
			"length": lerpf(0.58, 0.92, strength),
			"width": 0.72,
		}
	return super._release_spec(index, strength)


func _draw_contact_shape(
	release: float, release_peak: float, fade: float, strength: float,
	colour: Color, accent: Color,
) -> void:
	if _move not in ["foresight", "monster_block"]:
		super._draw_contact_shape(release, release_peak, fade, strength, colour, accent)
		return

	for index in _contact_rings.size():
		var ring := _contact_rings[index]
		if _move == "foresight":
			## Three concentric reticle rings sit just camera-side of the setting
			## hands; previously they were behind the torso and reduced to two bars.
			ring.position = Vector3(0.0, contact_anchor_meters + 0.03, 0.24 + float(index) * 0.035)
			ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			var s := lerpf(0.20 + float(index) * 0.06, 0.48 + float(index) * 0.14, release)
			ring.scale = Vector3.ONE * s
			_set_alpha(
				ring, accent if index != 1 else colour,
				release_peak * fade * strength * (0.92 - float(index) * 0.14),
			)
		else:
			## One broad vertical hoop plus six upright release strokes = a wall.
			## The other hoops are suppressed; three overlapping circles around
			## the head were a cage, not a block.
			if index > 0:
				_set_alpha(ring, colour, 0.0)
				continue
			ring.position = Vector3(0.0, contact_anchor_meters - 0.02, 0.25)
			ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			var s := lerpf(0.28, 0.86, release)
			ring.scale = Vector3(s * 1.65, s * 0.72, 0.62)
			_set_alpha(ring, accent, release_peak * fade * strength * 0.78)
