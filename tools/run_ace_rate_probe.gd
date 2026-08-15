extends SceneTree

## How many serves are aces, by the region serving them?
##
##     godot --headless --path . --script res://tools/run_ace_rate_probe.gd
##
## Reported from watching: Bompasao and Loong Rali score an unreal number of
## aces, with pass quality under 15%, while the serve *speed* looks right. Two
## readings fit that -- serves too strong, or reception too weak -- and they
## want opposite fixes, so the rate gets counted before either is applied.
##
## The sport's own figure is the anchor: an ace rate around 5-7% of serves is
## normal at a high level and anything approaching double figures is a different
## game. Split by serving region because the report names two of the fourteen,
## and a rate that is high everywhere is a reception problem while a rate that
## is high in two places is those two regions' serve profiles.
##
## **First run, and two of the three columns are untrustworthy.** 3360 rallies:
## 8.6% overall, spanning 7.1% to 9.2%. Elevated against the sport's 5-7% but
## not by the margin "unreal" describes -- and it is high *everywhere*, so it is
## not those two regions. Eight of the fourteen come back at exactly 22 aces in
## 240, an identical count six ways over, which is not what fourteen different
## serve profiles produce: either `set_opponent_region` is not reaching the
## server here or the region does not touch the ace rate at all. That has to be
## settled before this table is read as a per-region finding.
##
## And `mean pass` is 0.000 in every row because no event carries a
## `pass_quality` key. The column is measuring nothing. Left in place, named,
## rather than quietly deleted, because the reported symptom was pass quality
## under 15% and the next pass needs to know that this instrument cannot see it.
func _initialize() -> void:
	var Regions := load("res://scripts/data/regions.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	var rows := {}
	var names: Array = Regions.opponent_names()
	for region in names:
		manager.seed_vertical_slice_data()
		if manager.has_method("set_opponent_region"):
			manager.set_opponent_region(region)
		var serves := 0
		var aces := 0
		var quality_total := 0.0
		var quality_count := 0
		for rally_seed in range(30000, 30240):
			## The opponent serves every rally here, so every serve counted
			## belongs to the region under test.
			manager.match_state.serving_home = false
			var result: Resource = manager.resolve_active_rally(rally_seed)
			if result == null:
				continue
			serves += 1
			if str(result.terminal_outcome) == "ace":
				aces += 1
			for event in result.events:
				if not event.metadata.has("pass_quality"):
					continue
				quality_total += float(event.metadata["pass_quality"])
				quality_count += 1
				break
		rows[region] = {
			"serves": serves, "aces": aces,
			"quality": quality_total / maxf(float(quality_count), 1.0),
		}

	print("%-18s %8s %7s %9s %12s" % [
		"serving region", "rallies", "aces", "ace rate", "mean pass"])
	var keys := rows.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return float(rows[a]["aces"]) / maxf(float(rows[a]["serves"]), 1.0) \
			> float(rows[b]["aces"]) / maxf(float(rows[b]["serves"]), 1.0))
	var total := 0
	var total_aces := 0
	for key in keys:
		var row: Dictionary = rows[key]
		total += int(row["serves"])
		total_aces += int(row["aces"])
		print("%-18s %8d %7d %8.1f%% %11.3f" % [
			key, int(row["serves"]), int(row["aces"]),
			100.0 * float(row["aces"]) / maxf(float(row["serves"]), 1.0),
			float(row["quality"]),
		])
	print("%-18s %8d %7d %8.1f%%" % [
		"all", total, total_aces,
		100.0 * float(total_aces) / maxf(float(total), 1.0)])
	manager.free()
	quit()
