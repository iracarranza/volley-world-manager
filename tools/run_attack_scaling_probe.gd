extends SceneTree

## How an attack's outcome responds to its own quality.
##
## Tests a design claim that the engine has never been measured against:
## attacking is supposed to scale *differently* from defending, so that a poor
## swing is almost always defended, an average swing loses more than it wins,
## and an above-average one pierces the block and the floor with kill rate
## climbing sharply past a threshold. A linear margin contest cannot produce
## that shape; a convex one can. This says which the engine has.
##
##   godot --headless --path . --script res://tools/run_attack_scaling_probe.gd

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const ExecutionScaleModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)

const SAMPLES := 60
const CAREER_SEEDS := [
	"North Window", "Glass Harbor", "Second Tempo",
	"Quiet Hands", "Golden Rotation", "Long Road Home",
]
const BUCKET := 0.10


func _initialize() -> void:
	var buckets := {}
	for career_name in CAREER_SEEDS:
		var seed_value := absi(hash("%s|identity-calibration" % career_name))
		for serving_home in [true, false]:
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			manager.team.apply_identity("Balanced")
			ExecutionScaleModel.apply_generated_attributes(manager.players, seed_value)
			ExecutionScaleModel.apply_generated_attributes(
				manager.opponent_team.players, seed_value
			)
			manager.match_state.serving_home = serving_home
			for index in range(SAMPLES):
				var result: Resource = manager.resolve_active_rally(seed_value + index)
				if result != null:
					_classify(result, buckets)
	## Mutually exclusive and exhaustive. Whether the block got a hand on the
	## ball is the quantity the antagonism claim is actually about, so it is an
	## outcome in its own right rather than a flag hung off the others: a
	## funnelled ball the floor then picks up and a funnelled ball that still
	## lands are different events, and lumping either into "dug" or "kill"
	## hides exactly the trade being asked about.
	print("%9s %6s %7s %7s %8s %8s %8s %8s %8s" % [
		"quality", "n", "error", "stuff", "tch>dug", "tch>kill",
		"cln>dug", "cln>kill", "anytouch",
	])
	var keys: Array = buckets.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = buckets[key]
		var n := float(b["n"])
		if n < 8.0:
			continue
		var any_touch := float(b["stuffed"]) + float(b["touch_dug"]) \
			+ float(b["touch_kill"])
		print("%4.2f-%4.2f %6d %7.3f %7.3f %8.3f %8.3f %8.3f %8.3f %8.3f" % [
			float(key) * BUCKET, float(key) * BUCKET + BUCKET, int(n),
			float(b["error"]) / n, float(b["stuffed"]) / n,
			float(b["touch_dug"]) / n, float(b["touch_kill"]) / n,
			float(b["clean_dug"]) / n, float(b["clean_kill"]) / n,
			any_touch / n,
		])
	quit(0)


## One swing, classified by what happened to it. Walks forward from the ATTACK
## event rather than reading the rally's terminal outcome, because a rally has
## many swings and only the last one owns its ending.
func _classify(result: Resource, buckets: Dictionary) -> void:
	var events: Array = result.events
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventModel.EventType.ATTACK:
			continue
		if str(event.metadata.get("side", "")) != "home":
			continue
		var quality := float(event.quality)
		var key := int(floor(quality / BUCKET))
		if not buckets.has(key):
			buckets[key] = {
				"n": 0.0, "error": 0.0, "stuffed": 0.0, "touch_dug": 0.0,
				"touch_kill": 0.0, "clean_dug": 0.0, "clean_kill": 0.0,
			}
		var bucket: Dictionary = buckets[key]
		bucket["n"] = float(bucket["n"]) + 1.0
		## `event.success` is NOT an error flag -- for an ATTACK it is
		## `attack_quality >= 0.25`, a threshold on the very axis being bucketed
		## here. Reading it as "the swing went out" makes the measurement
		## circular and produced a clean, entirely false cliff at 0.30 on the
		## first run. The real signal is `attack_missed`.
		if bool(event.metadata.get("attack_missed", false)):
			bucket["error"] = float(bucket["error"]) + 1.0
			continue
		var dug := false
		var touched := false
		var stuffed := false
		for ahead in range(index + 1, events.size()):
			var later: Resource = events[ahead]
			var later_type := int(later.event_type)
			if later_type == RallyEventModel.EventType.ATTACK:
				break
			if later_type == RallyEventModel.EventType.BLOCK:
				var block_outcome := str(later.metadata.get("outcome", "miss"))
				if block_outcome == "stuff":
					stuffed = true
					break
				if block_outcome in ["touch", "funnel"]:
					touched = true
			if later_type == RallyEventModel.EventType.DIG:
				dug = bool(later.success)
				break
		var outcome := "stuffed"
		if not stuffed:
			if touched:
				outcome = "touch_dug" if dug else "touch_kill"
			else:
				outcome = "clean_dug" if dug else "clean_kill"
		bucket[outcome] = float(bucket[outcome]) + 1.0
