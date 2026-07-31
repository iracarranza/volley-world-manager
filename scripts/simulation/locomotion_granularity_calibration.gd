class_name LocomotionGranularityCalibration
extends RefCounted

## Answers one question with evidence rather than assertion: can stride and
## cadence serve as the granulated form of the engine's single speed curve?
##
## Method. For every generated player and every movement mode, take the speed
## `RallyMovementSystem.movement_profile()` produces today, and invert it
## against a realistic cadence to get the stride that speed implies. If the
## implied strides land inside the range human beings actually use for that kind
## of movement, the decomposition is sound and the current curve is a product of
## two plausible factors. If they land outside it, the current curve is
## internally inconsistent and adopting stride x cadence would change balance
## rather than merely re-express it.
##
## It also reports how much per-player spread stride would introduce, which is
## the thing that would leak into calibrations that pin movement ratings.

const MovementModel := preload("res://scripts/simulation/rally_movement_system.gd")
const LocomotionModelScript := preload("res://scripts/simulation/locomotion_model.gd")

## Ranges observed in human court movement, metres per step. A decomposition
## implying strides outside these is not describing the sport.
const PLAUSIBLE_STRIDE := {
	RallyPlayerState.MovementMode.LATERAL: [0.45, 1.00],
	RallyPlayerState.MovementMode.TRANSITION: [0.90, 2.00],
	RallyPlayerState.MovementMode.APPROACH: [0.55, 1.30],
	RallyPlayerState.MovementMode.BLOCK_CLOSE: [0.45, 1.10],
}


static func run(seed_count: int = 6, base_seed: int = 720000) -> Dictionary:
	var generator := load("res://scripts/systems/player_generator.gd")
	var players: Array = []
	for index in range(maxi(seed_count, 1)):
		var roster: Array = generator.generate_roster(
			"Landavol", "Club", base_seed + index * 131
		)
		for player in roster:
			players.append(player)
	if players.is_empty():
		return {"fixture_valid": false}

	var by_mode := {}
	var stride_values: Array[float] = []
	var stale_stride_players := 0
	for raw_player in players:
		var player: VolleyballPlayer = raw_player
		if player == null:
			continue
		## The stored attribute should equal the stride its own height implies.
		## Where it does not, stride is carrying no per-player information.
		if absf(player.stride_length_m - player.default_stride_length_m()) > 0.005:
			stale_stride_players += 1
		stride_values.append(player.default_stride_length_m())
		for mode in PLAUSIBLE_STRIDE:
			var actor := RallyPlayerState.create(player, &"home", -1, Vector2(0.5, 0.5))
			var profile: Dictionary = MovementModel.movement_profile(
				actor, Vector2(1.0, 0.0), mode
			)
			var current_speed := float(profile.get("maximum_speed", 0.0))
			var implied: float = LocomotionModelScript.implied_stride_meters(
				player, mode, current_speed
			)
			var decomposed: float = LocomotionModelScript.maximum_speed(player, mode)
			if not by_mode.has(mode):
				by_mode[mode] = {
					"implied": [], "current_speed": [], "decomposed_speed": [],
				}
			by_mode[mode]["implied"].append(implied)
			by_mode[mode]["current_speed"].append(current_speed)
			by_mode[mode]["decomposed_speed"].append(decomposed)
	return _summarize(by_mode, stride_values, stale_stride_players, players.size())


static func _summarize(
	by_mode: Dictionary,
	stride_values: Array[float],
	stale_stride_players: int,
	player_count: int,
) -> Dictionary:
	var modes := {}
	var all_plausible := true
	for mode in by_mode:
		var bucket: Dictionary = by_mode[mode]
		var implied: Array = bucket["implied"]
		var bounds: Array = PLAUSIBLE_STRIDE[mode]
		var low := float(bounds[0])
		var high := float(bounds[1])
		var inside := 0
		var total := 0.0
		var smallest := 99.0
		var largest := 0.0
		for value in implied:
			var stride := float(value)
			total += stride
			smallest = minf(smallest, stride)
			largest = maxf(largest, stride)
			if stride >= low and stride <= high:
				inside += 1
		var plausible_rate := float(inside) / maxf(float(implied.size()), 1.0)
		all_plausible = all_plausible and plausible_rate >= 0.90
		modes[RallyPlayerState.MovementMode.keys()[mode]] = {
			"sample_count": implied.size(),
			"mean_implied_stride_m": total / maxf(float(implied.size()), 1.0),
			"minimum_implied_stride_m": smallest,
			"maximum_implied_stride_m": largest,
			"plausible_low": low,
			"plausible_high": high,
			"within_plausible_rate": plausible_rate,
			"mean_current_speed_mps": _mean(bucket["current_speed"]),
			"mean_decomposed_speed_mps": _mean(bucket["decomposed_speed"]),
		}
	var stride_spread := 0.0
	if not stride_values.is_empty():
		var smallest_stride := 99.0
		var largest_stride := 0.0
		for value in stride_values:
			smallest_stride = minf(smallest_stride, value)
			largest_stride = maxf(largest_stride, value)
		stride_spread = largest_stride - smallest_stride
	return {
		"fixture_valid": true,
		"player_count": player_count,
		"by_mode": modes,
		"decomposition_plausible": all_plausible,
		## Spread of height-implied stride across the roster, in metres. This is
		## the per-player variation that would enter movement if stride were
		## wired in -- and therefore what would leak past a calibration that
		## pins the movement *ratings* but cannot pin physique.
		"height_implied_stride_spread_m": stride_spread,
		## Players whose stored stride disagrees with their own height.
		"stale_stride_player_count": stale_stride_players,
		"stale_stride_rate": float(stale_stride_players) / maxf(float(player_count), 1.0),
	}


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())
