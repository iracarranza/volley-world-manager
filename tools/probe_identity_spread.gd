extends SceneTree

## How much of the identity budget actually varies across ids the world hands out.
## Data only -- no rendering. Answers whether a squad can look like a squad.

const B := preload("res://scripts/data/body_type_models.gd")
const FAMILIES := ["Feli", "Cani", "Avi", "Ursi", "Simi", "Vegi"]


func _initialize() -> void:
	for stride in [1, 7]:
		print("=== ids stepping by %d, 300 samples per family ===" % stride)
		print("%-6s %-34s %s" % ["family", "coat spread", "skin / produce spread"])
		for family_raw in FAMILIES:
			var family: String = str(family_raw)
			var marks := {}
			var skins := {}
			var produce := {}
			for i in range(300):
				var pid: int = 41000 + i * int(stride)
				var m := str(B.marking_for(family, pid))
				marks[m] = int(marks.get(m, 0)) + 1
				var sil: Dictionary = B.silhouette(family, pid, {})
				var skin: Color = sil.get("skin", Color.BLACK)
				skins[skin.to_html(false)] = true
				produce[str(sil.get("produce", "-"))] = true
			var parts: Array[String] = []
			for k in marks:
				parts.append("%s:%d" % [k, int(marks[k])])
			parts.sort()
			print("%-6s %-34s %d skins, %d produce" % [
				family, ", ".join(parts), skins.size(), produce.size(),
			])
		print("")
	quit()
