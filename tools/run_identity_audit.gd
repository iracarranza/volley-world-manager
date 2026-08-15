extends SceneTree

## Are the eight regional identities meaningfully distinct, or do some of them
## collapse onto each other? Reads REGIONAL_PRINCIPLES directly.

const Regions := preload("res://scripts/data/regions.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var table: Dictionary = Regions.REGIONAL_PRINCIPLES
	var names: Array = table.keys()
	names.sort()
	var axes: Array = [
		"decisiveness", "pin_focus", "tempo_variation", "emotional_expression",
		"serve_aggression", "transition_commitment", "block_commitment",
	]

	print("=== regional identity axes ===")
	var header := "%-14s" % "region"
	for axis in axes:
		header += " %6s" % str(axis).substr(0, 6)
	print(header)
	for region_name in names:
		var row := "%-14s" % str(region_name).substr(0, 14)
		for axis in axes:
			row += " %6.2f" % float(table[region_name][axis])
		print(row)

	print("\n=== per-axis spread (is the axis actually used?) ===")
	for axis in axes:
		var lowest := 2.0
		var highest := -1.0
		var low_name := ""
		var high_name := ""
		for region_name in names:
			var value := float(table[region_name][axis])
			if value < lowest:
				lowest = value
				low_name = str(region_name)
			if value > highest:
				highest = value
				high_name = str(region_name)
		print("  %-22s %.2f .. %.2f  (range %.2f)   low=%s  high=%s" % [
			axis, lowest, highest, highest - lowest, low_name, high_name,
		])

	print("\n=== pairwise distance (mean absolute difference across axes) ===")
	var pairs: Array = []
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var total := 0.0
			for axis in axes:
				total += absf(
					float(table[names[i]][axis]) - float(table[names[j]][axis])
				)
			pairs.append({
				"a": str(names[i]), "b": str(names[j]),
				"distance": total / float(axes.size()),
			})
	pairs.sort_custom(func(x, y): return float(x.distance) < float(y.distance))
	print("  closest six pairs (least differentiated):")
	for index in range(mini(6, pairs.size())):
		print("    %-14s vs %-14s  %.3f" % [
			pairs[index].a, pairs[index].b, pairs[index].distance,
		])
	print("  furthest three pairs:")
	for index in range(maxi(pairs.size() - 3, 0), pairs.size()):
		print("    %-14s vs %-14s  %.3f" % [
			pairs[index].a, pairs[index].b, pairs[index].distance,
		])
	var sum := 0.0
	for pair in pairs:
		sum += float(pair.distance)
	print("  mean pairwise distance: %.3f over %d pairs" % [
		sum / float(pairs.size()), pairs.size(),
	])

	## A region that is another region plus-or-minus nothing has no identity of
	## its own: every axis at or above another's means it is strictly contained.
	print("\n=== dominance check (one region containing another) ===")
	var found := false
	for i in range(names.size()):
		for j in range(names.size()):
			if i == j:
				continue
			var dominates := true
			var strictly := false
			for axis in axes:
				var a := float(table[names[i]][axis])
				var b := float(table[names[j]][axis])
				if a < b - 0.001:
					dominates = false
					break
				if a > b + 0.001:
					strictly = true
			if dominates and strictly:
				print("    %s dominates %s on every axis" % [names[i], names[j]])
				found = true
	if not found:
		print("    none -- every region is extreme on at least one axis")

	## The weaker failure: two regions whose top-two axes are the same.
	print("\n=== signature axis (each region's most extreme axis vs the mean) ===")
	for region_name in names:
		var best_axis := ""
		var best_gap := 0.0
		for axis in axes:
			var mean := 0.0
			for other in names:
				mean += float(table[other][axis])
			mean /= float(names.size())
			var gap := float(table[region_name][axis]) - mean
			if absf(gap) > absf(best_gap):
				best_gap = gap
				best_axis = str(axis)
		print("    %-14s %-22s %+.2f vs world mean" % [
			region_name, best_axis, best_gap,
		])

	quit()
	return true
