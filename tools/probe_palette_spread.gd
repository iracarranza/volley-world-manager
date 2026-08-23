extends SceneTree
const B := preload("res://scripts/data/body_type_models.gd")
func _initialize() -> void:
	for family_raw in ["Simi", "Feli"]:
		var family: String = str(family_raw)
		var counts := {}
		for i in range(1000):
			var pid: int = 41000 + i
			var sil: Dictionary = B.silhouette(family, pid, {})
			var skin: Color = sil.get("skin", Color.BLACK)
			var k := skin.to_html(false)
			counts[k] = int(counts.get(k, 0)) + 1
		var parts: Array[String] = []
		var keys: Array = counts.keys()
		keys.sort()
		for k in keys:
			parts.append("%s:%d" % [str(k), int(counts[k])])
		print("%-5s %d colourways over 1000 ids -> %s" % [
			family, counts.size(), ", ".join(parts)])
	quit()
