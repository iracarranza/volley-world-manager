extends SceneTree

## How big is a mark, really, and can one backdrop hold all of them?
##
##     godot --headless --path . --script res://tools/run_mark_extent_probe.gd
##
## The variant plate offered two ways for a rating colour to reach a cogniticon:
## recolour the ink, or seat the mark on a coloured disc. The disc option makes a
## claim it never states -- that one disc radius works for every family -- and
## the plate showed a blade whose hilt hung out the bottom of its disc while a
## shield sat comfortably inside the same circle.
##
## This measures that instead of eyeballing it: the ink bounding box of every
## mark in the vocabulary, and the radius a circle needs to contain it. If the
## required radii differ by much, "put it on a disc" is not one decision but one
## per family, and every future family owes a radius.
const Marks := preload("res://scripts/data/cogniticon_marks.gd")

## Anything above this is ink rather than the transparent ground. The marks
## composite a halo *under* the ink at 0.85 alpha, so a plain alpha test would
## measure the halo's outer edge -- which is 1.7px of spread wider than the mark
## on every side and is not what a backdrop has to contain.
const INK_ALPHA: float = 0.55


func _initialize() -> void:
	var rows: Array = []
	for dark in [true, false]:
		var textures := {}
		for key in Marks.blade_variant_textures(dark):
			textures["blade " + str(key).split("|")[1]] = Marks.blade_variant_textures(dark)[key]
		for key in Marks.shield_variant_textures(dark):
			textures["shield " + str(key).split("|")[1]] = Marks.shield_variant_textures(dark)[key]
		textures["commitment full"] = Marks.commitment(1.0, false, dark)
		textures["commitment broken"] = Marks.commitment(1.0, true, dark)
		textures["eye nominal"] = Marks.eye_at(1.0, dark)
		textures["eye shocked"] = Marks.eye_at(Marks.EYE_APERTURE_MAX, dark)
		if dark:
			var keys: Array = textures.keys()
			keys.sort()
			print("%-20s %6s %6s %8s %9s" % [
				"mark", "wide", "tall", "radius", "of canvas"])
			for key in keys:
				var box := _ink_box(textures[key])
				if box.size.x <= 0.0:
					print("%-20s %6s" % [key, "(empty)"])
					continue
				var radius := box.size.length() * 0.5
				print("%-20s %6.0f %6.0f %8.1f %8.0f%%" % [
					key, box.size.x, box.size.y, radius,
					radius / float(Marks.PIXELS) * 200.0,
				])
				rows.append({"key": key, "radius": radius})

	var smallest := 9999.0
	var largest := 0.0
	var small_key := ""
	var large_key := ""
	for row in rows:
		if float(row["radius"]) < smallest:
			smallest = float(row["radius"])
			small_key = str(row["key"])
		if float(row["radius"]) > largest:
			largest = float(row["radius"])
			large_key = str(row["key"])
	print("\nSmallest: %s at r=%.0f. Largest: %s at r=%.0f." % [
		small_key, smallest, large_key, largest])
	print("A single disc sized for the largest is %.0f%% wider than the smallest" % [
		(largest / maxf(smallest, 1.0) - 1.0) * 100.0])
	print("mark needs, so the same rating would read as two different weights.")
	quit()


## The tight box around every pixel whose alpha clears the halo.
func _ink_box(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < INK_ALPHA:
				continue
			min_point.x = minf(min_point.x, float(x))
			min_point.y = minf(min_point.y, float(y))
			max_point.x = maxf(max_point.x, float(x))
			max_point.y = maxf(max_point.y, float(y))
	if min_point.x > max_point.x:
		return Rect2()
	return Rect2(min_point, max_point - min_point)
