extends SceneTree

## Gate D and the rally, measured on the same terms.
##
## Two calibration surfaces that disagree are worse than one, because a constant
## chosen from either is chosen from a chain nobody has shown the game runs. The
## harness reports block involvement of 5.8% of swings at 1.00 m of contact depth;
## the rally reports 37.8% of blocks *formed* touching the ball at a median depth
## of 1.32 m. Those are different denominators, so the gap is not the ratio it
## looks like -- and the harness has the better-staged wall of the two, so it
## should if anything be blocking more, not less.
##
## So this states the rally's numbers the way the harness states its own: per
## swing, not per block formed. It also reports the three inputs most likely to
## explain a gap, because the harness fixes all of them and the rally does not:
##
##   contact depth      the harness sweeps it; the rally distributes it
##   contact height     the harness contacts at full jumping reach every time,
##                      the rally scales the leap by the approach's jump
##                      multiplier, and a lower contact is a more blockable ball
##   wall size          the harness always builds one or two blockers, the rally
##                      builds none at all on some swings
##
## Run:
##   godot --headless --path . --script res://tools/run_gate_d_reconcile.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")
const PromotionScript := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const ROSTER_SEEDS: Array[int] = [900006, 901006, 902006, 903006]
const RALLIES: int = 150


func _initialize() -> void:
	var swings := 0
	var blocks_formed := 0
	var blocks_touching := 0
	var stuffs := 0
	var depths: Array = []
	var jumps: Array = []
	var heights: Array = []
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
				var pending := false
				for raw_event in result.events:
					var event := raw_event as RallyEvent
					if event == null:
						continue
					if event.event_type == RallyEventScript.EventType.ATTACK \
							and str(event.metadata.get("side", "")) == "opponent":
						swings += 1
						pending = true
						depths.append(absf(
							CourtConstants.NET_Y - event.start_position.y
						) * CourtConstants.COURT_LENGTH_METERS)
						var jump := float(
							event.metadata.get("jump_multiplier", 1.0)
						)
						jumps.append(jump)
						var hitter: Resource = _player(
							manager.opponent_team.players, int(event.actor_id)
						)
						if hitter != null:
							heights.append(
								PromotionScript.contact_height_meters(hitter, jump)
							)
						continue
					if event.event_type != RallyEventScript.EventType.BLOCK \
							or str(event.metadata.get("side", "")) != "home" \
							or not pending:
						continue
					pending = false
					blocks_formed += 1
					var outcome := str(event.metadata.get("outcome", "miss"))
					if outcome != "miss":
						blocks_touching += 1
					if outcome == "stuff":
						stuffs += 1
		manager.free()

	print("Gate D vs the rally -- %d rosters x %d rallies x 2 serving sides"
		% [ROSTER_SEEDS.size(), RALLIES])
	print("")
	print("opponent swings                       %d" % swings)
	print("blocks formed                         %d  (%.1f%% of swings)" % [
		blocks_formed, _pct(blocks_formed, swings)])
	print("blocks touching the ball              %d" % blocks_touching)
	print("")
	print("block involvement, per block formed   %.1f%%"
		% _pct(blocks_touching, blocks_formed))
	print("block involvement, PER SWING          %.1f%%   <- the harness's terms"
		% _pct(blocks_touching, swings))
	print("stuff, per swing                      %.1f%%" % _pct(stuffs, swings))
	print("")
	_report("contact depth, metres off the net", depths)
	_report("jump multiplier", jumps)
	_report("contact height, metres", heights)
	print("")
	print("The harness contacts at a jump multiplier of 1.0 on every sample. If")
	print("the rally's is materially below that, the harness is measuring a")
	print("higher, less blockable ball than the game ever produces, and its mix")
	print("cannot be compared to the game's until it stops.")
	quit()


func _player(players: Array, player_id: int) -> Resource:
	for raw in players:
		var player: Resource = raw as Resource
		if player != null and int(player.id) == player_id:
			return player
	return null


func _pct(part: int, whole: int) -> float:
	if whole <= 0:
		return 0.0
	return float(part) / float(whole) * 100.0


func _report(label: String, samples: Array) -> void:
	if samples.is_empty():
		print("%-38s (no samples)" % label)
		return
	samples.sort()
	print("%-38s p10 %5.2f  p50 %5.2f  p90 %5.2f  (n=%d)" % [
		label, _percentile(samples, 0.10), _percentile(samples, 0.50),
		_percentile(samples, 0.90), samples.size(),
	])


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
