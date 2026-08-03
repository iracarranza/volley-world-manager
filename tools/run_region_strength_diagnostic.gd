extends SceneTree

## Measures positional prime/depth strength from several generated worlds.
## Run with:
##   godot --headless --path . --script res://tools/run_region_strength_diagnostic.gd


func _initialize() -> void:
	var totals := {}
	var minimums := {}
	var maximums := {}
	for seed_value in [4242, 99991, 17331, 28003, 44119, 55291]:
		var population := VolleyballWorldPopulation.generate(seed_value, 1200)
		var strengths := VolleyballSixnetLeague.calculate_region_strengths(population)
		print("seed %d: %s" % [seed_value, _ordered_line(strengths)])
		for region_name in strengths:
			var value := float(strengths[region_name])
			totals[region_name] = float(totals.get(region_name, 0.0)) + value
			minimums[region_name] = minf(float(minimums.get(region_name, value)), value)
			maximums[region_name] = maxf(float(maximums.get(region_name, value)), value)
	print("\nsix-world averages:")
	var ranked: Array = totals.keys()
	ranked.sort_custom(func(a, b): return float(totals[a]) > float(totals[b]))
	for region_name in ranked:
		print("  %-18s %.2f  (%.2f-%.2f)" % [
			region_name, float(totals[region_name]) / 6.0,
			float(minimums[region_name]), float(maximums[region_name]),
		])
	quit(0)


func _ordered_line(strengths: Dictionary) -> String:
	var ranked: Array = strengths.keys()
	ranked.sort_custom(func(a, b): return float(strengths[a]) > float(strengths[b]))
	var parts: Array[String] = []
	for region_name in ranked:
		parts.append("%s %.1f" % [region_name, float(strengths[region_name])])
	return ", ".join(parts)
