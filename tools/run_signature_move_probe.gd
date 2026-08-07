extends SceneTree

## How often the two signature moves actually decide a point, by hitter tier.
##
## `SignatureMoveModel` defines Block Crush (the power route) and High Hands
## (the accuracy route) as the two ways a swing beats a block it has physically
## met. The design intent is that they appear occasionally for a B-tier hitter,
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
	"block_crush", "high_hands", "tool", "stuff", "touch", "in", "out",
]


func _initialize() -> void:
	var by_tier := {}
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
					_scan(result, tiers, by_tier)
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
	quit(0)


## The hitter's own attacking grade, which is the axis the design intent is
## stated on -- not their overall, since a great setter is not a B-tier hitter.
func _tier(player: Resource) -> String:
	var profile: Dictionary = AttributeProfilesModel.summary_profile(player)
	return AttributeProfilesModel.grade_tier(float(profile.get("Attacking", 50.0)))


func _scan(result: Resource, tiers: Dictionary, by_tier: Dictionary) -> void:
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
