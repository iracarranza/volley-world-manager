extends SceneTree

## Are the three feature axes actually three axes?
##
## The first squad sheet came back with ears, muzzle and build moving in lockstep
## -- every `small` voli was also `short` and also `heavy`. Three separate hash
## strings were supposed to prevent exactly that, so either the strings were not
## separate enough or the instrument reading them was wrong.
##
## It was the modulus. Godot's `String.hash` is djb2 and 33 is congruent to 1
## modulo any power of two, so a four-entry table indexed by `hash(s) % 4` reads
## nothing but the character sum of the id -- a per-axis constant offset on one
## shared number. The retained arms below are the evidence: both the
## prefix-varying and the suffix-varying four-entry forms draw 4 of 27, so the
## string was never the variable, and the production five-entry table is what
## separates them.

const BodyTypes := preload("res://scripts/data/body_type_models.gd")

const SAMPLE: int = 4000
const AXES: Array[String] = ["ears", "muzzle", "build"]

## The broken shape, kept at its own size so the finding stays reproducible when
## the production table changes again.
const FOUR_ENTRY := {
	"ears": ["standard", "standard", "small", "tall"],
	"muzzle": ["standard", "standard", "short", "long"],
	"build": ["standard", "standard", "light", "heavy"],
}


func _initialize() -> void:
	var ok := true
	_measure("four entries, prefix-varying   hash(\"axis:id\")",
		func(axis: String, id: int) -> String:
			return _four(axis, hash("%s:%d" % [axis, id])))
	_measure("four entries, suffix-varying   hash(\"id:feature:axis\")",
		func(axis: String, id: int) -> String:
			return _four(axis, hash("%d:feature:%s" % [id, axis])))
	var combos := _measure("production                     BodyTypes.feature_for",
		func(axis: String, id: int) -> String:
			return BodyTypes.feature_for(axis, id))
	## The gate. Twenty-seven is every combination the table can express; below
	## about twenty over four thousand ids the axes are not independent and the
	## sheet that follows is showing one axis three times.
	if combos < 27:
		push_error("Feature axes are not independent: %d of 27 shapes" % combos)
		ok = false
	print("")
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _four(axis: String, raw: int) -> String:
	var options: Array = FOUR_ENTRY[axis]
	return str(options[absi(raw) % options.size()])


## Two readings. Per-axis counts say each axis draws its own values in the right
## proportion -- which the broken form also passes, because a lockstep axis is
## still individually well distributed, and is precisely why the per-axis view is
## the wrong instrument for this question. The joint count is the one that tells.
func _measure(label: String, pick: Callable) -> int:
	print(label)
	var per_axis := {}
	var joint := {}
	for axis in AXES:
		per_axis[axis] = {}
	for slot in range(SAMPLE):
		var player_id := 1000 + slot
		var combo: Array[String] = []
		for axis in AXES:
			var value: String = pick.call(axis, player_id)
			combo.append(value)
			per_axis[axis][value] = int(per_axis[axis].get(value, 0)) + 1
		var key := "/".join(combo)
		joint[key] = int(joint.get(key, 0)) + 1
	for axis in AXES:
		var counts: Dictionary = per_axis[axis]
		var parts: Array[String] = []
		for value in BodyTypes.feature_options(axis):
			parts.append("%s %d" % [value, int(counts.get(value, 0))])
		print("  %-7s %s" % [axis, "  ".join(parts)])
	print("  distinct shape combinations: %d of 27" % joint.size())
	print("")
	return joint.size()
