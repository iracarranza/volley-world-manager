extends SceneTree

## Would the fourteen sheet colours pass the gate the current palette passes?
##
## `test_runner.gd` asserts every kit separates from the court floor by at least
## 1.6:1, and that 1.6 was measured rather than chosen -- the midtones it exists
## to catch score 1.09 to 1.12. A new palette is not a colour decision until it
## has been through the same instrument.

const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")

## As `match_court_3d.tscn` sets it, quoted the same way the gate quotes it.
const FLOOR := Color(0.7451, 0.5098, 0.3725)

const SHEET := {
	"Landavol": "35393A", "Spëddigh": "1F4E6B", "Pāwa Hitō": "26355C",
	"Blôc du Larg": "414055", "Xérvu": "3A2415", "Taktikã": "1E2124",
	"Ĭspayk": "0C4F52", "A'ace": "0B0F14",
	"Tãul ys Feynt": "2F4038", "Lo-ong Ralī": "3A2331", "Bompaçao": "3E4A47",
	"Rhėn Tempaol": "123F5A", "Kutré Lyn": "2B2B2D", "Zaitgaist": "3E464E",
}


func _initialize() -> void:
	print("%-15s %-9s %6s   %-9s %6s   %s" % [
		"region", "code", "ratio", "sheet", "ratio", "verdict",
	])
	var worst := 99.0
	var failed := 0
	for region_raw in RegionalKitsScript.KITS:
		var region: String = str(region_raw)
		var code := Color(RegionalKitsScript.KITS[region])
		var sheet := Color(str(SHEET[region]))
		var code_ratio := _ratio(code)
		var sheet_ratio := _ratio(sheet)
		var same := code.to_html(false).to_upper() == str(SHEET[region]).to_upper()
		worst = minf(worst, sheet_ratio)
		if sheet_ratio < 1.6:
			failed += 1
		print("%-15s %-9s %6.2f   %-9s %6.2f   %s" % [
			region, code.to_html(false), code_ratio,
			str(SHEET[region]).to_lower(), sheet_ratio,
			"unchanged" if same else "RECOLOURED",
		])
	print("")
	print("sheet palette: worst ratio %.2f, %d of 14 below the 1.6 gate" % [worst, failed])
	quit()


func _ratio(kit: Color) -> float:
	var lighter := maxf(kit.get_luminance(), FLOOR.get_luminance())
	var darker := minf(kit.get_luminance(), FLOOR.get_luminance())
	return (lighter + 0.05) / (darker + 0.05)
