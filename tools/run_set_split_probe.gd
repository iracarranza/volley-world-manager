extends SceneTree

## Where does the second contact's asymmetry live?
##
##     godot --headless --path . --script res://tools/run_set_split_probe.gd
##
## `run_offence_split_probe` localised the swing gap to the set that fed it and
## then stopped, because it prints the set as one number. `_set_terms` is a sum
## of six named parts:
##
##     quality = capability * (1 - TRANSITION_BALL_WEIGHT * (1 - usable))
##             - tempo_demand - capability_penalty - geometry_difficulty
##             + arrival + familiarity
##
## and each of those wants a different repair. A gap in `capability` is the
## roster or the attribute list; in `usable` it is the pass; in
## `geometry_difficulty` it is where the setter stood and how far the ball had to
## be carried; in `arrival` it is the movement clock. Every one of them is
## already on the SET event as `set_terms`, so this reads rather than recomputes
## -- the numbers here are the ones the rally actually used.
##
## Split the same four ways as the offence probe, because a set off a pass and a
## set off a dig are different contacts and a side that plays mostly one of them
## would otherwise be compared against the other side's mix.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 350
const FIRST_SEED: int = 20000

const COLUMNS := ["home/pass", "home/dig", "opponent/pass", "opponent/dig"]
## `quality` first because it is the thing being explained; the rest in the
## order they appear in the formula, so a reader can add them up by eye.
const TERMS := [
	"quality", "capability", "usable", "pass",
	"tempo_demand", "capability_penalty", "geometry_difficulty",
	"height_difficulty", "arrival", "familiarity",
]
## Geometry's own inputs, so a gap in `geometry_difficulty` can be attributed
## further without a second run.
const GEOMETRY := [
	"set_distance_meters", "release_distance_meters",
	"body_orientation_fit", "movement_duration",
]
## `capability_penalty` is a sum of two unrelated charges -- overreaching a
## tempo, and contacting the ball outside the setter's reach -- so it is split
## here. They have different causes and different repairs, and the composite
## cannot say which one is firing.
const CAPABILITY := [
	"contact_height_meters", "standing_reach_meters", "maximum_reach_meters",
	"capability_deficit", "command", "approach_quality",
]
const REACH_STATES := ["standing", "jump", "platform", "beyond_reach"]


func _initialize() -> void:
	var sides := {}
	for column in COLUMNS:
		sides[column] = {"n": 0, "sums": {}}
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result != null:
				_collect(result, sides)
		manager.free()

	print("=== what each side's set is made of ===")
	print("")
	_print_roster_specification()
	print("")
	print("%-24s %12s %12s %12s %12s" % [
		"term", COLUMNS[0], COLUMNS[1], COLUMNS[2], COLUMNS[3],
	])
	for key in TERMS:
		_print_row(key, sides)
	print("")
	for key in GEOMETRY:
		_print_row(key, sides)
	print("")
	for key in CAPABILITY:
		_print_row(key, sides)
	for state in REACH_STATES:
		_print_row("reach:%s" % state, sides)
	print("")
	print("%-24s %12d %12d %12d %12d" % [
		"sets",
		int(sides[COLUMNS[0]].n), int(sides[COLUMNS[1]].n),
		int(sides[COLUMNS[2]].n), int(sides[COLUMNS[3]].n),
	])
	quit()


## Printed above every reading this probe takes, because the first run of it
## attributed a 0.855-against-0.595 setter gap to the engine and the engine had
## nothing to do with it.
##
## `command()` came out at exactly 0.500 for the opponent on both of its paths
## across 347 sets. An exactly constant number is never a model; it is a value
## nobody set. All three attributes `command()` reads -- tempo_control,
## hand_control, composure -- are sitting on `VolleyballPlayer`'s class default
## for every player on that side.
##
## So a side-versus-side reading of anything in this engine measures the roster
## before it measures the simulation, and the instrument has to say so. This is
## the §0 failure in its other direction: not a threshold outside its
## distribution, but a comparison whose two arms were never comparable.
func _print_roster_specification() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	var blank := VolleyballPlayer.new()
	for entry in [["home", manager.players], ["opponent", manager.opponent_team.players]]:
		var defaulted := 0
		var total := 0
		for raw in Array(entry[1]):
			var player: Object = raw
			for key in VolleyballPlayer.ABILITY_ATTRIBUTES:
				total += 1
				if int(player.get(key)) == int(blank.get(key)):
					defaulted += 1
		print("roster: %-9s %d of %d attributes never specified (%.0f%%)" % [
			str(entry[0]), defaulted, total,
			float(defaulted) / maxf(float(total), 1.0) * 100.0,
		])
	manager.free()


func _print_row(key: String, sides: Dictionary) -> void:
	print("%-24s %12.3f %12.3f %12.3f %12.3f" % [
		key,
		_mean(sides[COLUMNS[0]], key), _mean(sides[COLUMNS[1]], key),
		_mean(sides[COLUMNS[2]], key), _mean(sides[COLUMNS[3]], key),
	])


func _mean(bucket: Dictionary, key: String) -> float:
	return float(Dictionary(bucket.sums).get(key, 0.0)) \
		/ maxf(float(bucket.n), 1.0)


func _add(bucket: Dictionary, key: String, value: float) -> void:
	var sums: Dictionary = bucket.sums
	sums[key] = float(sums.get(key, 0.0)) + value


func _collect(result: Resource, sides: Dictionary) -> void:
	var fed_by := "pass"
	for raw_event in result.events:
		var event: Resource = raw_event
		match int(event.event_type):
			RallyEventScript.EventType.RECEPTION:
				fed_by = "pass"
			RallyEventScript.EventType.DIG:
				fed_by = "dig"
			RallyEventScript.EventType.SET:
				var metadata: Dictionary = event.metadata
				var side := "%s/%s" % [str(metadata.get("side", "")), fed_by]
				if not sides.has(side):
					continue
				var bucket: Dictionary = sides[side]
				bucket.n = int(bucket.n) + 1
				var terms: Dictionary = metadata.get("set_terms", {})
				for key in TERMS:
					if key == "height_difficulty":
						_add(bucket, key, float(metadata.get(key, 0.0)))
					else:
						_add(bucket, key, float(terms.get(key, 0.0)))
				for key in GEOMETRY:
					_add(bucket, key, float(metadata.get(key, 0.0)))
				var capability: Dictionary = metadata.get("setter_capability", {})
				for key in CAPABILITY:
					_add(bucket, key, float(capability.get(key, 0.0)))
				var reach_state := str(capability.get("reach_state", ""))
				for state in REACH_STATES:
					_add(bucket, "reach:%s" % state,
						1.0 if reach_state == state else 0.0)
