extends "res://tools/run_visual_court_gallery_final.gd"

## Pixel-certification correction. The final terrain sheet and ArenaFloor shared
## nearly the same elevation under the central plateau, so the broadcast render
## exposed z-fighting as black triangular tears. The arena deck already owns the
## playable plateau; the landform only has to support it and continue seaward.
## Sink the terrain sheet clear of that surface without changing its silhouette.


func _terrace() -> void:
	super._terrace()
	var land := _extras.get_node_or_null("PawaCourtLandform") as MeshInstance3D
	if land != null:
		land.position.y -= 0.42
