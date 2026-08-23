extends SceneTree

## Can a player tell their own squad apart?
##
## The question three passes of visual work have been aimed at, asked as a
## number rather than by looking at a sheet. A squad is twelve volis; two of them
## are *indistinguishable* if they share every axis a viewer can see -- family,
## produce, colourway, coat, and now the three shape axes. Anything else is a
## difference the eye has something to hold on to.
##
## Reported as collisions per squad rather than as a total look count, because a
## look count is a headline that never touches the thing that matters: ten
## thousand possible looks still collides constantly if the roster is small and
## the draw is lumpy. The birthday problem is the whole difficulty here.

const BodyTypes := preload("res://scripts/data/body_type_models.gd")

const SQUAD: int = 12
const SQUADS: int = 4000
const FAMILIES: Array[String] = ["Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi"]
const FEATURED: Array[String] = ["Feli", "Cani", "Ursi", "Simi"]


func _initialize() -> void:
	print("squad of %d, %d squads sampled" % [SQUAD, SQUADS])
	print("")
	print("%-34s %10s %10s %10s" % [
		"visible axes", "mean dupes", "clean sqds", "distinct",
	])
	_measure("family + colourway", ["palette"], FAMILIES)
	_measure("+ coat", ["palette", "coat"], FAMILIES)
	_measure("+ shape (ears/muzzle/build)", ["palette", "coat", "shape"], FAMILIES)
	## The row above barely moves, and the row count says why it cannot: 1,102
	## looks against 79 is a fourteen-fold gain that buys two percentage points
	## of clean squads, because four of the six families were not given axes and
	## a squad of twelve draws about eight of them. A total-look count is exactly
	## the headline this repository keeps being warned about -- it goes up
	## whatever happens and is not the quantity anyone experiences.
	##
	## So the same measurement again over the two families that actually got the
	## work, which is the only place it could have shown.
	print("")
	print("featured families only (Feli, Cani, Ursi, Simi)")
	_measure("family + colourway + coat", ["palette", "coat"], FEATURED)
	_measure("+ shape", ["palette", "coat", "shape"], FEATURED)
	quit()


## One voli's visible identity under a chosen set of axes. Family is always in
## it, because a Cani is never mistaken for an Avi whatever else matches.
func _fingerprint(player_id: int, axes: Array, pool: Array) -> String:
	var family: String = str(pool[absi(hash("%d:family" % player_id)) % pool.size()])
	var produce := BodyTypes.produce_for(player_id) if family == "Vegi" else ""
	var parts: Array[String] = [family, produce]
	var palette_key := BodyTypes.palette_key(family, produce)
	if axes.has("palette"):
		## The index, not the colour: two palettes could in principle carry the
		## same skin and the viewer would not be able to tell them apart, so the
		## honest fingerprint is what is drawn.
		var palette: Dictionary = BodyTypes.palette_for(palette_key, player_id)
		parts.append(Color(palette.get("skin", Color.BLACK)).to_html(false))
	if axes.has("coat"):
		parts.append(BodyTypes.marking_for(palette_key, player_id))
	if axes.has("shape"):
		var features: Dictionary = BodyTypes.chosen_features(family, player_id, {})
		## Empty for the four families with no axes yet, which is the point of
		## reporting this alongside the other two rows rather than on its own:
		## the gain here is two families' worth, not six.
		for axis in ["ears", "muzzle", "build"]:
			parts.append(str(features.get(axis, "-")))
	return "|".join(parts)


func _measure(label: String, axes: Array, pool: Array) -> void:
	var total_dupes := 0
	var clean := 0
	var all_looks := {}
	for squad_index in range(SQUADS):
		var seen := {}
		var dupes := 0
		for slot in range(SQUAD):
			var player_id := 500000 + squad_index * SQUAD + slot
			var key := _fingerprint(player_id, axes, pool)
			all_looks[key] = true
			if seen.has(key):
				dupes += 1
			seen[key] = true
		total_dupes += dupes
		if dupes == 0:
			clean += 1
	print("%-34s %10.2f %9.0f%% %10d" % [
		label,
		float(total_dupes) / float(SQUADS),
		100.0 * float(clean) / float(SQUADS),
		all_looks.size(),
	])
