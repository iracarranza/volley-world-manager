extends SceneTree

## What is `RallyPlayerState.readiness`?
##
##     godot --headless --path . --script res://tools/run_readiness_audit.gd
##
## The policy defines it as physical preload for an immediate extension or
## takeoff -- not awareness, not facing, not responsibility, not speed. This
## probe asks the prior question: does the engine *have* such a quantity, or does
## it have a field named after one?
##
## Three layers, plus a census over live rallies:
##
##   1. every write to the field;
##   2. every read of it, evaluated at the value the field actually holds;
##   3. whether the states the policy nominates as its inputs already reach the
##      consequences the policy permits it to touch.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const ContactEnvelopeModel := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)
const SetterFailureClassifierModel := preload(
	"res://scripts/simulation/setter_failure_classifier.gd"
)


func _initialize() -> void:
	_layer_one_writes()
	_layer_two_reads()
	_layer_three_inputs()
	_census()
	_verdict()
	quit()


func _voli(overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = 801
	player.display_name = "Voli"
	for attribute in [
		"explosiveness", "anticipation", "lateral_speed", "acceleration",
		"transition_speed", "stamina", "work_rate", "composure",
		"approach_timing", "block_timing", "set_balance", "reception",
		"dig_control", "ball_control",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


## ------------------------------------------------------------------ layer 1
func _layer_one_writes() -> void:
	print("=".repeat(78))
	print("LAYER 1 -- every write to `readiness`")
	print("=".repeat(78))
	print("  Declared      rally_player_state.gd:46   `var readiness: float = 1.0`")
	print("  Copied        rally_player_state.gd      `copy.readiness = readiness`")
	print("  Assigned      -- nowhere --")
	print("")
	print("  A default and a snapshot propagating the default. No production")
	print("  path moves it, so the field holds 1.0 for every voli in every")
	print("  rally, always.")
	print("\n  The field is now gone. `RallyPlayerState` has no `readiness`, and")
	print("  this probe would fail to parse if it still read one -- which is the")
	print("  cheapest possible proof that no caller was left behind.")


## ------------------------------------------------------------------ layer 2
##
## Its three consumers, evaluated at the value the field holds.
func _layer_two_reads() -> void:
	print("\n" + "=".repeat(78))
	print("LAYER 2 -- every read, at the value the field actually held")
	print("=".repeat(78))
	print("  %-46s %-14s %-14s" % ["consumer", "at 1.0", "range if free"])
	print("  %-46s %-14s %-14s" % [
		"envelope: lerpf(1.18, 0.92, readiness)",
		"%.4f" % lerpf(1.18, 0.92, 1.0),
		"%.2f-%.2f" % [0.92, 1.18],
	])
	print("  %-46s %-14s %-14s" % [
		"envelope: accessible_jump * readiness",
		"x1.0000", "x0.00-1.00",
	])
	print("  %-46s %-14s %-14s" % [
		"classifier: readiness < 0.45", "never fires", "fires below 0.45",
	])
	print("\n  The first is a constant folded into every takeoff. The second is")
	print("  an identity. The third is a threshold at 0.45 acting on a")
	print("  distribution that is a single point at 1.0 -- FAILURE_MODES section 0,")
	print("  a knob that cannot reach its own stated range.\n")

	## And the classifier proves it: only balance can raise `body_state`.
	var base := {
		"true_reachable": false, "perceived_reachable": false,
		"vertical_margin_meters": 0.20, "contact_height_meters": 2.10,
		"standing_reach_meters": 2.30, "required_takeoff_time_seconds": 0.10,
		"final_available_time_seconds": 0.40,
		"first_decision_delay_seconds": 0.05,
		"time_remaining_after_first_decision_seconds": 0.50,
		"final_center_distance_deficit_meters": 0.0,
		"contact_reach_meters": 0.45,
	}
	print("  %-18s %-14s %-24s" % ["final_readiness", "final_balance", "causes"])
	for pair in [[1.0, 1.0], [0.20, 1.0], [1.0, 0.20], [0.20, 0.20]]:
		var candidate := base.duplicate()
		candidate["final_readiness"] = float(pair[0])
		candidate["final_balance"] = float(pair[1])
		var result: Dictionary = SetterFailureClassifierModel.classify(candidate)
		print("  %-18.2f %-14.2f %-24s" % [
			float(pair[0]), float(pair[1]),
			str(result.get("contributing_causes", [])),
		])
	print("\n  Row 2 is the one that mattered, and it now reads")
	print("  `technical_action_unavailable` rather than `body_state` -- because")
	print("  the readiness clause has been removed. Before removal it read")
	print("  `body_state`, on an input the engine could never produce. Rows 3 and")
	print("  4 are unchanged: balance was already doing all the work this cause")
	print("  ever did in a real rally.")


## ------------------------------------------------------------------ layer 3
##
## The policy's section 3 nominates BodyState, MovementMode, balance, recovery,
## landing and approach as readiness's inputs. Section 8 permits it two
## consequences. Do those inputs already reach those consequences?
func _layer_three_inputs() -> void:
	print("\n" + "=".repeat(78))
	print("LAYER 3 -- the inputs already reach the permitted consequences")
	print("=".repeat(78))
	var player := _voli()
	print("  (a) takeoff preparation time, by approach quality -- already live:\n")
	print("  %-18s %-16s" % ["runup_quality", "takeoff_time_s"])
	for quality in [0.0, 0.35, 0.70, 1.0]:
		var envelope: Dictionary = ContactEnvelopeModel.evaluate(
			_actor(RallyPlayerState.BodyState.BALANCED), &"attack", 3.10, 1.20,
			true, {"runup_quality": float(quality), "jump_multiplier": 1.0},
		)
		print("  %-18.2f %-16.4f" % [
			float(quality), float(envelope.get("required_takeoff_time_seconds", 0.0)),
		])
	print("\n  (b) accessible extension, by body state and balance -- already live:\n")
	print("  %-16s %-10s %-18s %-16s %-14s" % [
		"body_state", "balance", "horizontal_reach_m", "can_take_off", "jump_m",
	])
	for state_name in [
		"BALANCED", "MOVING", "REACHING", "AIRBORNE", "DIVING", "RECOVERING",
	]:
		var state: int = RallyPlayerState.BodyState[state_name]
		for balance in [1.0, 0.35]:
			var actor := _actor(state)
			actor.balance = float(balance)
			var envelope: Dictionary = ContactEnvelopeModel.evaluate(
				actor, &"attack", 3.10, 1.20, true,
			)
			var jump := float(envelope.get("maximum_contact_height_meters", 0.0)) \
				- float(envelope.get("standing_reach_meters", 0.0))
			print("  %-16s %-10.2f %-18.4f %-16s %-14.4f" % [
				state_name if balance > 0.9 else "", float(balance),
				float(envelope.get("horizontal_reach_meters", 0.0)),
				"yes" if jump > 0.001 else "NO", jump,
			])
	print("\n  Read the AIRBORNE rows. The posture table already believes an")
	print("  airborne body is compromised -- 0.82 against a balanced 1.0 -- and")
	print("  the takeoff gate still lets it leave the floor again. DIVING and")
	print("  RECOVERING are excluded by name; AIRBORNE is not.")


func _actor(state: RallyPlayerState.BodyState) -> RallyPlayerState:
	var actor := RallyPlayerState.create(_voli(), &"home", 1, Vector2(0.5, 0.8))
	actor.body_state = state
	return actor


## ---------------------------------------------------------------- publication
##
## And what the rally record says about it: nothing.
##
## This deliberately does *not* claim to be a census over resolved rallies. There
## is no population to take one from -- the field is on no event and in no
## metadata, so a sweep of rallies could only re-read the constructor. Saying so
## is the finding; dressing it up as a sample would be the wrong instrument
## measuring nothing.
func _census() -> void:
	print("\n" + "=".repeat(78))
	print("PUBLICATION -- what the rally record carries")
	print("=".repeat(78))
	print("  constructed value            1.0000, always, before removal")
	print("  RallyEvent metadata keys     none carried `readiness`")
	print("  published by the resolver    nowhere")
	print("")
	print("  The one place a readiness value reaches a report is")
	print("  `ShadowSetterResponseSystem`'s `final_readiness`, which reads")
	print("  `actor.readiness` off an actor nothing has written -- so the")
	print("  classifier downstream receives 1.0 by construction, not by")
	print("  measurement.")


func _verdict() -> void:
	print("\n" + "=".repeat(78))
	print("VERDICT")
	print("=".repeat(78))
	print("  `readiness` is inert. Nothing writes it, its two envelope consumers")
	print("  evaluate to a constant and an identity, and its classifier threshold")
	print("  cannot reach its own range.")
	print("")
	print("  Every input the policy nominates already reaches every consequence")
	print("  the policy permits, by a route that is physical rather than scalar:")
	print("  DIVING and RECOVERING gate takeoff directly, balance and body_state")
	print("  drive horizontal reach, and approach run-up quality drives both")
	print("  takeoff time and jump height. There is no consequence left for a")
	print("  separate preload scalar to own.")
	print("")
	print("  -> REMOVED, per policy section 10. And one genuine physical gap it")
	print("     was masking: AIRBORNE is missing from the takeoff exclusion.")
