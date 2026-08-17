extends SceneTree

## M3, asked before anything is built: **where does the engine put the body when
## a voli plays the ball?**
##
##     godot --headless --path . --script res://tools/run_body_centre_probe.gd
##
## The milestone: "a voli's body location is distinct from the point where
## hands/platform contact the ball. Reach, wingspan, body type and net
## encroachment use one physical geometry instead of placing the sternum on the
## ball."
##
## So the first question is which families already draw that distinction and
## which place the sternum on the ball. Measured, not assumed -- three of this
## session's findings reversed on measurement.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const ContactEnvelopeModel := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	_where_the_body_lands()
	_what_reach_already_knows()
	_verdict()
	quit()


func _voli(overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = 601
	player.display_name = "Voli"
	for attribute in [
		"anticipation", "lateral_speed", "acceleration", "transition_speed",
		"stamina", "work_rate", "reception", "dig_control", "ball_control",
		"composure", "explosiveness",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## `_reached_point` is where every defensive journey ends, and what it returns is
## the body's new position. Driven across a range of trips with time to spare.
func _where_the_body_lands() -> void:
	print("=".repeat(78))
	print("WHERE THE BODY ENDS UP, RELATIVE TO THE BALL")
	print("=".repeat(78))
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 4242
	var start := Vector2(0.50, 0.86)
	print("  A defender with ample time, sent to a ball at a range of distances.\n")
	print("  %-10s %-14s %-18s %-14s" % [
		"trip m", "time s", "body-to-ball m", "on the ball?",
	])
	var on_the_ball := 0
	var rows := 0
	for trip in [0.4, 1.0, 2.0, 3.0, 4.5]:
		var target := start + Vector2(0.0, -float(trip) / COURT_LENGTH_METERS)
		var reached: Vector2 = simulator._reached_point(
			_voli(), start, target, 3.0, "lateral",
		)
		var gap := _metres(reached, target)
		rows += 1
		if gap < 0.0005:
			on_the_ball += 1
		print("  %-10.2f %-14.2f %-18.4f %-14s" % [
			float(trip), 3.0, gap, "YES" if gap < 0.0005 else "no",
		])
	print("\n  %d of %d trips end with the body centre exactly on the ball's" % [
		on_the_ball, rows,
	])
	print("  landing point -- to four decimal places, a distance of zero.")
	print("")
	print("  `_reached_point` returns `target` unchanged whenever the movement")
	print("  fits the available time and the read carried no shortfall. The")
	print("  shortfall term exists and is real, but it models a *wrong read*, not")
	print("  the geometry of standing beside a ball to play it.")


## And what the reach model already knows, so the milestone is not told to build
## what exists.
func _what_reach_already_knows() -> void:
	print("\n" + "=".repeat(78))
	print("WHAT THE REACH MODEL ALREADY DISTINGUISHES")
	print("=".repeat(78))
	print("  `_base_reach_meters` -- the platform envelope, by build and control:\n")
	print("  %-16s %-14s %-16s %-14s" % [
		"wingspan cm", "ball_control", "reception m", "dig m",
	])
	for wingspan in [175, 190, 205, 220]:
		for control in [30, 70]:
			var player := _voli({"ball_control": control})
			player.wingspan_cm = wingspan
			var arrival_reception: Dictionary = CoverageCalculator.evaluate_arrival(
				player, null, Vector2(0.5, 0.6), 1.20, "reception",
				Vector2(0.5, 0.7), 3.0,
			)
			var arrival_dig: Dictionary = CoverageCalculator.evaluate_arrival(
				player, null, Vector2(0.5, 0.6), 1.20, "dig_control",
				Vector2(0.5, 0.7), 3.0,
			)
			print("  %-16s %-14d %-16.4f %-14.4f" % [
				str(wingspan) if control == 30 else "", control,
				float(arrival_reception.get("base_reach_meters", 0.0)),
				float(arrival_dig.get("base_reach_meters", 0.0)),
			])
	print("\n  Wingspan is already in it, and so is control and the libero's")
	print("  role bonus. **This is a tolerance, not a stand-off.** It decides")
	print("  whether a ball is reachable from where the body is; it does not")
	print("  decide where the body goes.")

	print("\n  `ContactEnvelopeSystem._horizontal_reach` -- the same question")
	print("  asked of a live body, and it does vary with posture:\n")
	print("  %-16s %-18s" % ["body state", "horizontal reach m"])
	for state_name in ["BALANCED", "MOVING", "REACHING", "DIVING", "RECOVERING"]:
		var actor := RallyPlayerState.create(
			_voli(), &"home", 1, Vector2(0.5, 0.7)
		)
		actor.body_state = RallyPlayerState.BodyState[state_name]
		var envelope: Dictionary = ContactEnvelopeModel.evaluate(
			actor, &"receive", 1.00, 1.20, false,
		)
		print("  %-16s %-18.4f" % [
			state_name, float(envelope.get("horizontal_reach_meters", 0.0)),
		])


func _verdict() -> void:
	print("\n" + "=".repeat(78))
	print("VERDICT -- M3 is a real gap, and it is narrower than the milestone text")
	print("=".repeat(78))
	print("  Two reach figures exist and they differ by about three times, which")
	print("  looks like two models of one fact and is not. `PLATFORM_CONTACT.md`")
	print("  section 13.11 already rules on it: `ContactEnvelopeSystem` \"is not the")
	print("  feasible-launch envelope\" -- it answers \"can this body reach that")
	print("  contact point\", belongs to the body-state stage, and its own header")
	print("  calls it game-balance mappings rather than biomechanical measurement.")
	print("  `_base_reach_meters` is the claimant's reachability tolerance. They")
	print("  are not claimed to agree and their disagreement is not a defect.")
	print("")
	print("  Both take build into account, so neither is missing. What is missing")
	print("  is that **nothing spends them on placing the body**.")
	print("")
	print("  A defender who arrives in time is placed with their body centre")
	print("  exactly on the ball's landing point, and the reach models are then")
	print("  consulted to confirm they can reach a ball they are standing on.")
	print("  That is the sternum-on-the-ball the milestone names, and it is")
	print("  located in one function -- `_reached_point`'s `return target`.")
	print("")
	print("  What it needs before it can be closed is a physical relation nobody")
	print("  has measured: **where a body stands relative to a ball it intends to")
	print("  play**, per contact family. A platform pass is taken in front of the")
	print("  body and below the waist; an overhead set is taken above the")
	print("  forehead; a dig may be taken anywhere the arms reach. Those are")
	print("  different stand-off geometries and none of them is in this engine.")
	print("  Choosing one by eye is exactly what FAILURE_MODES section 0 forbids.")
