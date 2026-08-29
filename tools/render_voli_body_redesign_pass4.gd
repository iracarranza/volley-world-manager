extends "res://tools/render_voli_body_redesign_pass3.gd"
## Final correction for the body redesign contact sheet.
##
## The production muzzle's Ink child is a shell authored around the old convex
## sphere. Repointing that shell at a flat-front wedge puts its enlarged front
## cap in front of the coloured cap, so the entire snout front reads as a black
## open mouth. The study wedge is already a deliberate simple solid and needs no
## legacy spherical outline; hide that child instead. The actual StudyMouth
## remains the single thin bar placed by the base study on the muzzle front.

func _sync_ink_mesh(feature: MeshInstance3D) -> void:
	var ink := feature.get_node_or_null("Ink") as MeshInstance3D
	if ink != null:
		ink.visible = false
