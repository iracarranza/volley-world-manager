extends SceneTree

## How much of the block's placement error is the set being off the net.
##
## The crossing geometry is exact, not approximate:
##
##     crossing_x = contact.x + tan(bearing) * off_net_metres
##
## so a wall staged on the hitter's *contact* is wrong by `tan(bearing)` metres
## for every metre the hitter contacts away from the tape. A tight set costs
## almost nothing; a set two metres off the net at a thirty-degree bearing puts
## the ball 1.15 m from the hands, which is more than three blocker half-widths.
##
## This reports the off-net distribution and the displacement it produces, so the
## contribution can be read as a quantity rather than argued about. Pairs each
## home BLOCK with the opponent ATTACK it contested, whose start position is the
## contact.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_offnet_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

const ROSTER_SEEDS: Array[int] = [900006, 901006, 902006, 903006]
const RALLIES: int = 150


func _initialize() -> void:
	var off_nets: Array = []
	var displacements: Array = []
	## Off-net distance for the blocks that were beaten, against all of them.
	var beaten_off_nets: Array = []
	var touched_off_nets: Array = []
	for roster_seed in ROSTER_SEEDS:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
		ExecutionScale.apply_generated_attributes(
			manager.opponent_team.players, roster_seed
		)
		for serving_home in [true, false]:
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				var pending_contact := Vector2.ZERO
				var have_contact := false
				for raw_event in result.events:
					var event := raw_event as RallyEvent
					if event == null:
						continue
					if event.event_type == RallyEventScript.EventType.ATTACK \
							and str(event.metadata.get("side", "")) == "opponent":
						pending_contact = event.start_position
						have_contact = true
						continue
					if event.event_type != RallyEventScript.EventType.BLOCK \
							or str(event.metadata.get("side", "")) != "home" \
							or not have_contact:
						continue
					have_contact = false
					var off_net := absf(
						CourtConstants.NET_Y - pending_contact.y
					) * CourtConstants.COURT_LENGTH_METERS
					off_nets.append(off_net)
					if event.metadata.has("net_crossing_x"):
						displacements.append(absf(
							float(event.metadata["net_crossing_x"])
								- pending_contact.x
						) * CourtConstants.COURT_WIDTH_METERS)
					if str(event.metadata.get("outcome", "miss")) == "miss":
						beaten_off_nets.append(off_net)
					else:
						touched_off_nets.append(off_net)
		manager.free()

	print("Off-net contribution -- %d rosters x %d rallies x 2 serving sides"
		% [ROSTER_SEEDS.size(), RALLIES])
	print("")
	_report("how far off the tape the hitter contacted, metres", off_nets)
	_report("contact-to-crossing displacement, metres", displacements)
	print("")
	print("If the second table tracks the first, the wall's error is the set")
	print("being off the net rather than anything about the wall itself.")
	print("")
	_report("off-net, blocks that were beaten", beaten_off_nets)
	_report("off-net, blocks that touched the ball", touched_off_nets)
	print("")
	print("A gap between those two is the block failing specifically on deep")
	print("sets, which is the case a commit read cannot help with and a ball")
	print("read can.")
	quit()


func _report(label: String, samples: Array) -> void:
	if samples.is_empty():
		print("%-46s (no samples)" % label)
		return
	samples.sort()
	var total := 0.0
	for value in samples:
		total += float(value)
	print("%-46s p10 %5.2f  p50 %5.2f  p90 %5.2f  mean %5.2f  (n=%d)" % [
		label,
		_percentile(samples, 0.10), _percentile(samples, 0.50),
		_percentile(samples, 0.90), total / float(samples.size()),
		samples.size(),
	])


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
