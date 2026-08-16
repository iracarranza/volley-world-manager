extends SceneTree

## Nodes 3 and 4 of the forward walk: does set quality sit downstream of the
## realized contact, and does the second contact terminate in ONE set?
##
##     godot --headless --path . --script res://tools/run_set_generation_probe.gd
##
## Target chain:
##
##     REALIZED PASS
##     -> who is responsible for the second contact          (certified, 41a57b6)
##     -> intended hitter                                    (certified, 1a12946)
##     -> required setter movement from the actual pass      (certified, 1a12946)
##     -> physical feasibility of a valid setting contact     <- gates 1, 2, 4
##     -> set execution quality                               <- gates 3, 5
##     -> ONE authoritative outgoing set                      <- gate 6
##
## The order matters and is the thing under test: feasibility is resolved
## *before* execution quality, and execution quality may shape the ball but must
## not move the body, extend the clock, or re-choose the hitter.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const GeometricAttackPromotionModel := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const FIRST_SEED: int = 78000
const SEED_COUNT: int = 300

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

## The value `_jump_set_decision` guards on, and which its own comment calls
## unmeasured. Gate 4 exists to put a distribution behind it.
const JUMP_SET_STABLE_APPROACH_MPS: float = 1.9
const JUMP_SET_LOAD_SECONDS: float = 0.34

const SLOT_IDS := {1: 501, 2: 502, 3: 503, 4: 504, 5: 505, 6: 506}
const SETTER_ID: int = 502
const PASS_TARGET := Vector2(0.56, 0.68)


func _initialize() -> void:
	_gate_one_two()
	_gate_four_fixture()
	_gate_five()
	_census()
	quit()


## ------------------------------------------------------------------ fixtures


func _setter(overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = SETTER_ID
	player.display_name = "Setter"
	player.position_role = "Setter"
	for attribute in [
		"set_accuracy", "set_balance", "set_stability", "tempo_control",
		"hand_control", "set_disguise", "unpredictability", "ball_control",
		"decision_making", "court_vision", "composure", "acceleration",
		"lateral_speed", "transition_speed", "stamina", "work_rate",
		"jump_reach", "explosiveness",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


func _simulator() -> Object:
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 2718
	return simulator


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## ------------------------------------------------------------- gates 1 and 2
##
## Gate 1: same pass, setter nearer vs farther. Required movement changes, the
## contact circumstances respond, and **set quality cannot make the setter
## arrive** -- which is demonstrated by ordering rather than asserted, since the
## arrival margin is an input to the capability read and the capability read is
## an input to quality, never the reverse.
##
## Gate 2: same setter and start, faster vs slower pass. The ball's own duration
## is the movement budget, and no independent timer overrides it.
func _gate_one_two() -> void:
	var simulator := _simulator()
	var setter := _setter()

	print("=".repeat(78))
	print("GATE 1 -- same pass, setter nearer vs farther")
	print("=".repeat(78))
	print("  Pass held: target (0.56, 0.68), flight 1.20 s, apex 2.95 m.")
	print("  %-11s %-10s %-11s %-9s %-11s %-24s" % [
		"start_dist", "travel_s", "margin_s", "closing", "posture", "reason",
	])
	for offset in [0.0, 0.04, 0.10, 0.20, 0.34, 0.50]:
		var start := PASS_TARGET + Vector2(float(offset) * 0.6, float(offset))
		var distance := _metres(start, PASS_TARGET)
		var travel: float = simulator._movement_time(
			setter, start, PASS_TARGET, "transition"
		)
		var margin := 1.20 - travel
		var jump: Dictionary = simulator._jump_set_decision(
			setter, 2.95, margin, distance, travel
		)
		print("  %-11.4f %-10.4f %-11.4f %-9.4f %-11s %-24s" % [
			distance, travel, margin, float(jump.closing_speed_mps),
			"jump" if bool(jump.jumping) else "standing", str(jump.reason),
		])
	print("  -> travel and margin must respond to distance; posture must follow")
	print("     the margin and the closing speed, not the set's quality.")

	print("\n" + "=".repeat(78))
	print("GATE 2 -- same setter and start, faster vs slower pass")
	print("=".repeat(78))
	print("  Start held 2.14 m from the contact; only the pass's flight moves.")
	print("  %-11s %-10s %-11s %-9s %-11s %-24s" % [
		"flight_s", "travel_s", "margin_s", "closing", "posture", "reason",
	])
	var fixed_start := PASS_TARGET + Vector2(0.06, 0.10)
	var fixed_distance := _metres(fixed_start, PASS_TARGET)
	var fixed_travel: float = simulator._movement_time(
		setter, fixed_start, PASS_TARGET, "transition"
	)
	for flight in [0.35, 0.55, 0.80, 1.10, 1.60, 2.20]:
		var margin := float(flight) - fixed_travel
		var jump: Dictionary = simulator._jump_set_decision(
			setter, 2.95, margin, fixed_distance, fixed_travel
		)
		print("  %-11.2f %-10.4f %-11.4f %-9.4f %-11s %-24s" % [
			flight, fixed_travel, margin, float(jump.closing_speed_mps),
			"jump" if bool(jump.jumping) else "standing", str(jump.reason),
		])
	print("  -> travel is constant (the body did not change); the margin moves")
	print("     only because the ball did. That is the ball as the rally clock.")


## ------------------------------------------------------------------- gate 4
##
## Jump-set stability, driven directly.
##
## The distinction the design asks for: a stable reachable pass may be jumped,
## and a pass requiring substantial forward rescue movement must not become an
## ordinary jump set merely because a leaping body's reach intersects the ball.
##
## Both rows below have **the same arrival margin**. Only the run that produced
## it differs -- one setter stood and waited, the other covered ground. If the
## posture is the same in both, the model is reading time alone and the
## distinction does not exist.
func _gate_four_fixture() -> void:
	print("\n" + "=".repeat(78))
	print("GATE 4 -- jump-set stability: same margin, different run")
	print("=".repeat(78))
	var simulator := _simulator()
	var setter := _setter()
	print("  Pass apex 2.95 m (above the standing release) in every row.")
	print("  %-22s %-9s %-10s %-9s %-10s %-26s" % [
		"case", "travel_m", "travel_s", "margin_s", "posture", "reason",
	])
	var cases := [
		{"name": "stood and waited", "metres": 0.15, "seconds": 0.30, "margin": 0.90},
		{"name": "short shuffle", "metres": 0.55, "seconds": 0.50, "margin": 0.90},
		{"name": "brisk two steps", "metres": 1.40, "seconds": 0.85, "margin": 0.90},
		{"name": "covered ground", "metres": 4.20, "seconds": 1.50, "margin": 0.90},
		{"name": "sprinted in", "metres": 7.00, "seconds": 1.90, "margin": 0.90},
		{"name": "sprinted, no time", "metres": 7.00, "seconds": 1.90, "margin": 0.10},
	]
	for entry in cases:
		var jump: Dictionary = simulator._jump_set_decision(
			setter, 2.95, float(entry.margin),
			float(entry.metres), float(entry.seconds),
		)
		print("  %-22s %-9.2f %-10.2f %-9.2f %-10s %-26s" % [
			str(entry.name), float(entry.metres), float(entry.seconds),
			float(entry.margin), "jump" if bool(jump.jumping) else "standing",
			str(jump.reason),
		])
	print("  -> identical margins, so any change is the run and nothing else.")

	print("\n  And the pass that never rose to the hands, which is a different")
	print("  failure from a rushed one and must be named differently:")
	print("  %-14s %-10s %-26s" % ["pass apex", "posture", "reason"])
	var standing_height: float = GeometricAttackPromotionModel \
		.set_contact_height_meters(setter)
	for apex in [1.60, 2.00, standing_height - 0.05, standing_height + 0.05, 3.20]:
		var jump: Dictionary = simulator._jump_set_decision(
			setter, apex, 0.90, 0.15, 0.30
		)
		print("  %-14.4f %-10s %-26s" % [
			apex, "jump" if bool(jump.jumping) else "standing", str(jump.reason),
		])
	print("  standing release height = %.4f m" % standing_height)


## ------------------------------------------------------------------- gate 5
##
## Set height and distance. A longer or higher ball must consume something the
## architecture already models rather than being free.
##
## Two existing channels are swept: `_set_geometry`'s difficulty, which enters
## set quality, and `_delivered_point`'s scatter, which is where the ball
## actually lands. Nothing new is introduced -- the question is whether the
## quantities already there respond.
func _gate_five() -> void:
	print("\n" + "=".repeat(78))
	print("GATE 5 -- set height and distance are not free")
	print("=".repeat(78))
	var simulator := _simulator()
	var setter := _setter()
	var steady := _setter({"set_balance": 95, "set_stability": 95})

	print("\n  DISTANCE -> geometric difficulty (enters set quality)")
	print("  %-13s %-14s %-16s %-16s" % [
		"distance_m", "difficulty", "difficulty(steady)", "delta",
	])
	for target_x in [0.52, 0.42, 0.30, 0.18, 0.06]:
		var target := Vector2(target_x, 0.58)
		var ordinary: Dictionary = simulator._set_geometry(
			setter, Vector2(0.66, 0.72), PASS_TARGET, target, PASS_TARGET
		)
		var capable: Dictionary = simulator._set_geometry(
			steady, Vector2(0.66, 0.72), PASS_TARGET, target, PASS_TARGET
		)
		print("  %-13.4f %-14.5f %-16.5f %-16.5f" % [
			float(ordinary.distance_meters), float(ordinary.difficulty),
			float(capable.difficulty),
			float(ordinary.difficulty) - float(capable.difficulty),
		])
	print("  -> difficulty rises with distance and a steadier setter pays less,")
	print("     which is the existing physical capability participating.")

	print("\n  DISTANCE AND HEIGHT -> delivery scatter (where the ball lands)")
	print("  %-13s %-11s %-16s %-16s" % [
		"distance_m", "apex_m", "spread_q0.35", "spread_q0.85",
	])
	for entry in [
		{"distance": 1.5, "apex": 1.2}, {"distance": 4.0, "apex": 1.2},
		{"distance": 7.5, "apex": 1.2}, {"distance": 4.0, "apex": 2.6},
		{"distance": 4.0, "apex": 4.0},
	]:
		var low := _scatter(
			simulator, 0.35, float(entry.distance), float(entry.apex)
		)
		var high := _scatter(
			simulator, 0.85, float(entry.distance), float(entry.apex)
		)
		print("  %-13.2f %-11.2f %-16.5f %-16.5f" % [
			float(entry.distance), float(entry.apex), low, high,
		])
	print("  -> spread grows with both distance and apex, and shrinks with")
	print("     execution quality. A higher rescue ball is bought, not given.")


## Mean displacement from the aim over a seed sweep, which is what
## `_delivered_point`'s stdev arguments actually produce. Averaged rather than
## sampled once, because a single draw of a Gaussian says nothing.
func _scatter(
	simulator: Object, quality: float, distance: float, apex: float
) -> float:
	var intended := Vector2(0.24, 0.60)
	var total := 0.0
	var samples := 400
	for index in range(samples):
		simulator.rally_seed = 6000 + index
		simulator.rng = RandomNumberGenerator.new()
		simulator.rng.seed = 6000 + index
		var delivered: Vector2 = simulator._delivered_point(
			intended, quality, 0.62, 0.10, 0.44, 0.94, distance, apex
		)
		total += _metres(delivered, intended)
	return total / float(samples)


## ------------------------------------------------------------------ census
##
## Gates 3 and 6 in situ, plus the distribution behind gate 4's threshold.
func _census() -> void:
	print("\n" + "=".repeat(78))
	print("CENSUS -- %d isolated rallies per serving side" % SEED_COUNT)
	print("=".repeat(78))
	var sets := 0
	var postures := {}
	var reasons := {}
	var closing: Array[float] = []
	var quality_total := 0.0
	var margin_total := 0.0
	var distance_total := 0.0
	var emergency := 0
	var failed_sets := 0
	var downgraded := 0
	var chain := {
		"pass_into_set": 0, "pass_into_set_ok": 0,
		"set_into_attack": 0, "set_into_attack_ok": 0,
	}
	var outcomes := {}
	var home_points := 0
	var rallies := 0
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			rallies += 1
			if rally != null:
				var outcome := str(rally.terminal_outcome)
				outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
				if bool(rally.home_team_won):
					home_points += 1
				## **The last ball anybody published**, walked forward in event
				## order, so the identity is between adjacent contacts rather
				## than between two events that merely exist.
				##
				## Not "the last RECEPTION": a transition set is fed by a dig,
				## and comparing it against a serve reception from earlier in the
				## same rally measures the probe rather than the engine. The
				## first draft did exactly that and reported 468/586.
				var last_pass := {}
				var last_set := {}
				for event in rally.events:
					var kind := int(event.event_type)
					if kind == RallyEventScript.EventType.SET:
						sets += 1
						var metadata: Dictionary = event.metadata
						if not bool(event.success):
							failed_sets += 1
						quality_total += float(event.quality)
						margin_total += float(metadata.get("arrival_margin", 0.0))
						distance_total += float(
							metadata.get("set_distance_meters", 0.0)
						)
						if bool(metadata.get("emergency_setter", false)):
							emergency += 1
						var posture := str(metadata.get("set_posture", "?"))
						postures[posture] = int(postures.get(posture, 0)) + 1
						var reason := str(metadata.get("set_posture_reason", "?"))
						reasons[reason] = int(reasons.get(reason, 0)) + 1
						if metadata.has("set_closing_speed_mps"):
							closing.append(
								float(metadata.set_closing_speed_mps)
							)
						var capability: Dictionary = metadata.get(
							"setter_capability", {}
						)
						if bool(capability.get("tempo_downgraded", false)):
							downgraded += 1
						## ONE BALL, first half: the set was resolved against the
						## pass the reception published.
						var incoming := Dictionary(
							metadata.get("incoming_trajectory",
								metadata.get("incoming_pass_trajectory", {}))
						)
						if not last_pass.is_empty() and not incoming.is_empty():
							chain["pass_into_set"] = \
								int(chain.pass_into_set) + 1
							if _same_ball(last_pass, incoming):
								chain["pass_into_set_ok"] = \
									int(chain.pass_into_set_ok) + 1
						last_set = Dictionary(
							metadata.get("outgoing_trajectory", {})
						)
						last_pass = last_set
					elif kind == RallyEventScript.EventType.ATTACK:
						## ONE BALL, second half: the swing was resolved against
						## the set the setter published.
						var attack_incoming := Dictionary(
							event.metadata.get("incoming_trajectory", {})
						)
						if not last_set.is_empty() and not attack_incoming.is_empty():
							chain["set_into_attack"] = \
								int(chain.set_into_attack) + 1
							if _same_ball(last_set, attack_incoming):
								chain["set_into_attack_ok"] = \
									int(chain.set_into_attack_ok) + 1
						last_pass = Dictionary(
							event.metadata.get("outgoing_trajectory", last_pass)
						)
					else:
						## Every other contact that publishes a ball -- the
						## reception, the dig, a block deflection -- becomes the
						## thing the next set has to be resolved against.
						var published := Dictionary(
							event.metadata.get("outgoing_trajectory", {})
						)
						if not published.is_empty():
							last_pass = published
			manager.free()

	var total := maxf(float(sets), 1.0)
	print("  sets %d over %d rallies" % [sets, rallies])
	print("      mean quality %.4f, mean arrival margin %.4f s, mean set distance %.4f m"
		% [quality_total / total, margin_total / total, distance_total / total])
	print("      emergency second contacts %d (%.4f)" % [
		emergency, float(emergency) / total,
	])
	print("      sets marked unsuccessful %d (%.4f)" % [
		failed_sets, float(failed_sets) / total,
	])
	print("      tempo downgraded by capability %d (%.4f)  <- feasibility" % [
		downgraded, float(downgraded) / total,
	])

	print("\n  POSTURE")
	var posture_names: Array = postures.keys()
	posture_names.sort()
	for name in posture_names:
		print("      %-14s %-6d %.4f" % [
			name, int(postures[name]), float(postures[name]) / total,
		])
	print("      why not a jump:")
	var reason_names: Array = reasons.keys()
	reason_names.sort()
	for name in reason_names:
		print("      %-30s %-6d %.4f" % [
			name, int(reasons[name]), float(reasons[name]) / total,
		])

	print("\n  CLOSING SPEED -- the distribution behind JUMP_SET_STABLE_APPROACH_MPS")
	if closing.is_empty():
		print("      NOT PUBLISHED -- the threshold cannot be audited")
	else:
		closing.sort()
		var over := 0
		for value in closing:
			if value > JUMP_SET_STABLE_APPROACH_MPS:
				over += 1
		print("      n %d   min %.4f  p05 %.4f  median %.4f  p95 %.4f  max %.4f" % [
			closing.size(), closing[0],
			closing[int(floor(closing.size() * 0.05))],
			closing[int(floor(closing.size() * 0.50))],
			closing[int(floor(closing.size() * 0.95))],
			closing[closing.size() - 1],
		])
		print("      threshold %.2f m/s sits above %.4f of the distribution" % [
			JUMP_SET_STABLE_APPROACH_MPS,
			1.0 - float(over) / maxf(float(closing.size()), 1.0),
		])
		print("      -> a threshold outside its own distribution does nothing,")
		print("         and does nothing silently. This is the check for that.")

	print("\n  ONE BALL -- does each contact consume the previous one?")
	print("      reception's pass == the set's incoming     %d / %d" % [
		int(chain.pass_into_set_ok), int(chain.pass_into_set),
	])
	print("      setter's set     == the attack's incoming   %d / %d" % [
		int(chain.set_into_attack_ok), int(chain.set_into_attack),
	])

	print("\n  RALLY OUTCOMES  (regression observation, never a target)")
	print("      home points %d of %d (%.4f)" % [
		home_points, rallies, float(home_points) / maxf(float(rallies), 1.0),
	])
	var outcome_names: Array = outcomes.keys()
	outcome_names.sort()
	for name in outcome_names:
		print("      %-28s %-5d %.4f" % [
			name, int(outcomes[name]), float(outcomes[name]) / maxf(float(rallies), 1.0),
		])


## Identity by endpoints and duration rather than by dictionary equality, since
## a trajectory carries stamped launch state a consumer may extend.
func _same_ball(first: Dictionary, second: Dictionary) -> bool:
	return Vector2(first.get("start_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("start_position", Vector2.ONE))
		) and Vector2(first.get("end_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("end_position", Vector2.ONE))
		) and is_equal_approx(
			float(first.get("duration", -1.0)), float(second.get("duration", -2.0))
		)
