extends SceneTree

## Does the built kit match the written design spec?
##
## The specs were written as proportions -- "pinstripes ~1.5% of torso width on
## ~7% spacing", "a band ~22% of torso height centred at ~60%" -- and a
## proportion is checkable. This turns each numeric claim into a measurement
## against the marks actually authored, so "does it match" stops being a matter
## of looking at a small tile and deciding.
##
## Reference dimensions are the body the sheets were reviewed on: a heavy Feli,
## torso radius 0.308 and torso height 0.915, so chest width is 0.616.

const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")

const CHEST: float = 0.616
const TORSO: float = 0.915

## claim, measured value, target, tolerance
var _rows: Array = []


func _initialize() -> void:
	_landavol()
	_pawa()
	_speddigh()
	_bloc()
	_xervu()
	_taktika()
	_ispayk()
	_feynt()
	_loong()
	_bompacao()
	_rhen()
	_kutre()
	print("%-34s %9s %9s  %s" % ["claim", "built", "spec", ""])
	var off := 0
	for row in _rows:
		var built := float(row[1])
		var target := float(row[2])
		var tol := float(row[3])
		var ok := absf(built - target) <= tol
		if not ok:
			off += 1
		print("%-34s %9.3f %9.3f  %s" % [
			str(row[0]), built, target, "ok" if ok else "OFF",
		])
	print("")
	print("%d of %d numeric claims off spec" % [off, _rows.size()])
	quit()


func _add(claim: String, built: float, target: float, tol: float) -> void:
	_rows.append([claim, built, target, tol])


func _front(region: String) -> Array:
	var out: Array = []
	for mark in RegionalKitsScript.marks_for(region):
		if Vector3(mark[1]).z >= 0.0:
			out.append(mark)
	return out


func _landavol() -> void:
	var m := _front("Landavol")
	_add("landavol placket width %", Vector3(m[0][0]).x / CHEST, 0.167, 0.03)
	_add("landavol placket height %", Vector3(m[0][0]).y / TORSO, 0.15, 0.04)


func _pawa() -> void:
	var m := _front("Pāwa Hitō")
	_add("pāwa panel width %", Vector3(m[0][0]).x / CHEST, 0.25, 0.04)


func _speddigh() -> void:
	var m := _front("Spëddigh")
	var size := Vector3(m[0][0])
	_add("spëddigh tick height %", size.y / TORSO, 0.04, 0.012)
	_add("spëddigh tick aspect h:w", size.y / size.x, 3.0, 0.6)


func _bloc() -> void:
	var m := _front("Blôc du Larg")
	var size := Vector3(m[0][0])
	var pitch := absf(Vector3(m[1][1]).x - Vector3(m[0][1]).x)
	_add("blôc stripe width %", size.x / CHEST, 0.015, 0.008)
	_add("blôc stripe pitch %", pitch / CHEST, 0.07, 0.025)


func _xervu() -> void:
	var widths: Array = []
	for mark in _front("Xérvu"):
		widths.append(Vector3(mark[0]).x / CHEST)
	widths.sort()
	_add("xérvu thinnest stroke %", float(widths[0]), 0.01, 0.008)
	_add("xérvu widest stroke %", float(widths[widths.size() - 1]), 0.04, 0.012)


func _taktika() -> void:
	var m := _front("Taktikã")
	_add("taktikã top rule span %", Vector3(m[0][0]).x / CHEST, 0.70, 0.10)
	_add(
		"taktikã top rule height %",
		(Vector3(m[0][1]).y + TORSO * 0.5) / TORSO, 0.60, 0.06,
	)
	_add("taktikã line width %", Vector3(m[0][0]).x / CHEST, 0.70, 0.10)


func _ispayk() -> void:
	var m := _front("Ĭspayk")
	_add("ĭspayk band height %", Vector3(m[0][0]).y / TORSO, 0.22, 0.04)
	_add(
		"ĭspayk band centre %",
		(Vector3(m[0][1]).y + TORSO * 0.5) / TORSO, 0.60, 0.05,
	)


func _feynt() -> void:
	var longest := 0.0
	var angles: Array = []
	for mark in _front("Tãul ys Feynt"):
		longest = maxf(longest, Vector3(mark[0]).y)
		if mark.size() > 2:
			angles.append(absf(float(mark[2])))
	angles.sort()
	_add("feynt longest mark % of torso", longest / TORSO, 0.28, 0.04)
	_add("feynt shallowest angle", float(angles[0]), 18.0, 4.0)
	_add("feynt steepest angle", float(angles[angles.size() - 1]), 24.0, 5.0)


func _loong() -> void:
	var m := _front("Lo-ong Ralī")
	var torso_lines := 0
	var longest := 0.0
	for mark in m:
		if mark.size() < 4 or str(mark[3]) == "torso":
			torso_lines += 1
			longest = maxf(longest, Vector3(mark[0]).y)
	_add("lo-ong torso line count", float(torso_lines), 2.0, 1.0)
	_add("lo-ong line % of torso", longest / TORSO, 0.88, 0.06)


func _bompacao() -> void:
	var m := _front("Bompaçao")
	_add("bompaçao band height %", Vector3(m[0][0]).y / TORSO, 0.25, 0.04)
	_add(
		"bompaçao band centre %",
		(Vector3(m[0][1]).y + TORSO * 0.5) / TORSO, 0.40, 0.05,
	)
	## The selected third pass carries the platform onto sleeves and shorts. Each
	## limb entry appears twice in `_front` because it is authored once for each
	## physical limb; four entries beyond the torso ring is therefore the spec.
	_add("bompaçao limb marks", float(m.size() - 1), 4.0, 0.0)


func _rhen() -> void:
	var angles: Array = []
	for mark in _front("Rhėn Tempaol"):
		if mark.size() > 2 and (mark.size() < 4 or str(mark[3]) == "torso"):
			angles.append(float(mark[2]))
	## The spec says steep at the shoulder and flattening as the fan spreads --
	## so the outermost line carries the largest angle and it falls inward.
	_add("rhėn outermost angle", float(angles[0]), 30.0, 6.0)
	_add(
		"rhėn fan flattens inward (1 = yes)",
		1.0 if float(angles[0]) > float(angles[angles.size() - 1]) else 0.0,
		1.0, 0.0,
	)


func _kutre() -> void:
	var m := _front("Kutré Lyn")
	var stem := Vector3(m[0][1])
	var stem_size := Vector3(m[0][0])
	var split := stem.y - stem_size.y * 0.5
	_add("kutré split height %", (split + TORSO * 0.5) / TORSO, 0.65, 0.06)
	_add("kutré branch angle", absf(float(m[1][2])), 45.0, 7.0)
