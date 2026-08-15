extends SceneTree

## How often the contact signatures actually decide a point, by hitter tier.
##
## `SignatureMoveModel` defines Block Crush (the power route) and High Hands
## (the accuracy route) as the two ways a swing beats a block it has physically
## met. Monster Block is the defending route through the same contact. The
## design intent is that hitter signatures appear occasionally for a B-tier hitter,
## can be depended on by an A, and are expected regularly from an S. This says
## what the engine currently does.
##
##   godot --headless --path . --script res://tools/run_signature_move_probe.gd

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const ExecutionScaleModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const AttributeProfilesModel := preload(
	"res://scripts/systems/attribute_profile_system.gd"
)

const SAMPLES := 60
const CAREER_SEEDS := [
	"North Window", "Glass Harbor", "Second Tempo",
	"Quiet Hands", "Golden Rotation", "Long Road Home",
]
const OUTCOMES := [
	"block_crush", "high_hands", "monster_block", "tool", "stuff", "touch", "in", "out",
]


func _initialize() -> void:
	var by_tier := {}
	var monster_timings: Array = []
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
			var tiers := {}
			for player in manager.players:
				tiers[player.id] = _tier(player)
			for index in range(SAMPLES):
				var result: Resource = manager.resolve_active_rally(seed_value + index)
				if result != null:
					_scan(result, tiers, by_tier, monster_timings)
	print("%6s %7s %12s %12s %10s %10s" % [
		"tier", "swings", "block_crush", "high_hands", "signature", "blank",
	])
	for tier in ["S", "A", "B", "C", "D"]:
		if not by_tier.has(tier):
			continue
		var b: Dictionary = by_tier[tier]
		var n := float(b["n"])
		if n < 5.0:
			continue
		var signature := float(b.get("block_crush", 0.0)) \
			+ float(b.get("high_hands", 0.0))
		print("%6s %7d %12.4f %12.4f %10.4f %10.4f" % [
			tier, int(n),
			float(b.get("block_crush", 0.0)) / n,
			float(b.get("high_hands", 0.0)) / n,
			signature / n,
			float(b.get("", 0.0)) / n,
		])
	print("\nraw outcome tallies by tier:")
	for tier in ["S", "A", "B", "C", "D"]:
		if not by_tier.has(tier):
			continue
		var b: Dictionary = by_tier[tier]
		var cells := PackedStringArray()
		for key in OUTCOMES:
			cells.append("%s=%d" % [key, int(b.get(key, 0.0))])
		print("  %s (n=%d): %s" % [tier, int(b["n"]), " ".join(cells)])
	print("\nMonster Block attempts: %d; successes: %d" % [
		_total(by_tier, "attempt:monster_block"),
		_total(by_tier, "monster_block"),
	])
	if not monster_timings.is_empty():
		monster_timings.sort()
		print("Contacted charged-blocker timing: min %.3f p50 %.3f p90 %.3f max %.3f" % [
			float(monster_timings[0]),
			float(monster_timings[int(monster_timings.size() * 0.50)]),
			float(monster_timings[int(monster_timings.size() * 0.90)]),
			float(monster_timings[-1]),
		])
	quit(0)


## The hitter's own attacking grade, which is the axis the design intent is
## stated on -- not their overall, since a great setter is not a B-tier hitter.
func _tier(player: Resource) -> String:
	var profile: Dictionary = AttributeProfilesModel.summary_profile(player)
	return AttributeProfilesModel.grade_tier(float(profile.get("Attacking", 50.0)))


func _scan(
	result: Resource,
	tiers: Dictionary,
	by_tier: Dictionary,
	monster_timings: Array,
) -> void:
	for event_resource in result.events:
		var event: Resource = event_resource
		if int(event.event_type) != RallyEventModel.EventType.ATTACK:
			continue
		if str(event.metadata.get("side", "")) != "home":
			continue
		var tier := str(tiers.get(int(event.actor_id), "?"))
		if not by_tier.has(tier):
			by_tier[tier] = {"n": 0.0}
		var bucket: Dictionary = by_tier[tier]
		bucket["n"] = float(bucket["n"]) + 1.0
		var outcome := str(event.metadata.get("geometric_outcome", ""))
		bucket[outcome] = float(bucket.get(outcome, 0.0)) + 1.0
		var move := str(event.metadata.get("signature_move", ""))
		if not move.is_empty():
			var move_key := "attempt:%s" % move
			bucket[move_key] = float(bucket.get(move_key, 0.0)) + 1.0
			if move == "monster_block":
				monster_timings.append(float(
					event.metadata.get("signature_timing_quality", 0.0)
				))


func _total(by_tier: Dictionary, key: String) -> int:
	var total := 0
	for tier in by_tier:
		total += int(Dictionary(by_tier[tier]).get(key, 0.0))
	return total
