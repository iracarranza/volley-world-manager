extends SceneTree

## Can you see the construction against the shirt it is on?
##
## `trim_colour` is the kit lightened by a per-region amount, and lightening a
## near-black by 0.34 does not travel as far as lightening a mid teal by the
## same figure. The court gate measures a kit against the floor; nothing has
## ever measured a mark against its own kit, which is the contrast that decides
## whether the construction reads at all.

const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")


func _initialize() -> void:
	print("%-15s %-8s %-8s %6s %6s  %s" % [
		"region", "kit", "trim", "trim", "ratio", "reads",
	])
	var rows: Array = []
	for region_raw in RegionalKitsScript.KITS:
		var region: String = str(region_raw)
		var kit := RegionalKitsScript.kit_for(region)
		var trim := RegionalKitsScript.trim_colour(region)
		var lighter := maxf(kit.get_luminance(), trim.get_luminance())
		var darker := minf(kit.get_luminance(), trim.get_luminance())
		rows.append([region, kit, trim, (lighter + 0.05) / (darker + 0.05)])
	rows.sort_custom(func(a, b): return float(a[3]) < float(b[3]))
	for row in rows:
		print("%-15s %-8s %-8s %6.2f %6.2f  %s" % [
			str(row[0]), Color(row[1]).to_html(false), Color(row[2]).to_html(false),
			RegionalKitsScript.trim_for(str(row[0])), float(row[3]),
			"faint" if float(row[3]) < 1.6 else "clear",
		])
	quit()
