extends SceneTree

## The squad table the render tool prints, without the render -- so a contact
## sheet can be relabelled after the fact without spending three minutes of
## rasterising to recover eight rows of text.

const BodyTypes := preload("res://scripts/data/body_type_models.gd")


func _initialize() -> void:
	for family in ["Feli", "Cani", "Ursi", "Simi"]:
		for slot in range(8):
			var player_id := 80200 + slot * 37
			var features: Dictionary = BodyTypes.chosen_features(family, player_id, {})
			print("%s,%d,%s,%s,%s,%s" % [
				family.to_lower(), slot,
				str(features.get("ears", "-")),
				str(features.get("muzzle", "-")),
				str(features.get("build", "-")),
				BodyTypes.marking_for(family, player_id),
			])
	quit()
