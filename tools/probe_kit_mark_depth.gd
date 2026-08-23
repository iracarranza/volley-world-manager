extends SceneTree

## Do a kit's construction marks actually sit on the shirt?
##
## `RegionalKits.MARKS` places every mark at torso-local z 0.112 and says that is
## "just clear of the torso's own surface". A kit mark is a child of the torso
## mesh, so that number has to clear the torso's *radius* -- and the radius is
## per body type, per build, and blended. Measured rather than trusted.

const BodyTypes := preload("res://scripts/data/body_type_models.gd")
const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")

const MARK_Z: float = 0.112


func _initialize() -> void:
	print("%-6s %-9s %8s %8s  %s" % ["body", "build", "radius", "mark_z", "verdict"])
	var buried := 0
	var total := 0
	for family in BodyTypes.MODELLED:
		for build in ["light", "standard", "heavy"]:
			var spec: Dictionary = BodyTypes.silhouette(family, 4242, {"build": build})
			if str(spec.get("torso_material", "kit")) != "kit":
				continue
			var radius := float(Dictionary(spec.get("torso", {})).get("radius", 0.0))
			total += 1
			var clear := MARK_Z > radius
			if not clear:
				buried += 1
			print("%-6s %-9s %8.3f %8.3f  %s" % [
				family, build, radius, MARK_Z,
				"on the shirt" if clear else "BURIED (%.3f m inside)" % (radius - MARK_Z),
			])
	print("")
	print("%d of %d kit-wearing bodies bury their construction marks" % [buried, total])
	quit()
