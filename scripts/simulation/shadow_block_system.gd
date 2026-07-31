class_name ShadowBlockSystem
extends RefCounted

## Gate 44: the attack-to-block observation slice.
##
## Starts from the authoritative shadow-attack flight and player state only at
## the resolver boundary (the point ShadowAttackSystem already resolved a
## hypothetical home attack). From there each opponent front-row blocker forms
## an independent, decision-safe hypothesis: a perceived setter cue, a
## progressively-refined read of the set flight, and a degraded cue about the
## hitter's approach load. Commitments are chosen from that perceived picture
## alone. Only afterward, at resolution time, is the chosen commitment compared
## against the authoritative contact position -- to grade it, never to inform
## it. This system never mutates the source RallyState and never promotes into
## an official BLOCK event; it is shadow-only evidence for later gates.

const ContactEnvelopeModel := preload("res://scripts/simulation/contact_envelope_system.gd")

## Early and late observation samples of the incoming set. A late sample is
## more accurate (more of the flight has been observed) without ever touching
## authoritative state -- it is still a read of a reconstructed BallFlight.
const READ_PROGRESS: Array[float] = [0.20, 0.85]
const BLOCK_FAMILIARITY: float = 0.30

const PIN_THRESHOLD_LOW: float = 0.34
const PIN_THRESHOLD_HIGH: float = 0.66
## Minimum gap between a blocker's home zone and the perceived attack zone
## before helping is no longer worth attempting; beyond this, release.
const ASSIST_TRAVEL_GAP: float = 0.40


static func evaluate(
	state: RallyState,
	shadow_attack: Dictionary,
	seed_value: int,
) -> Dictionary:
	if state == null or state.opponent_lineup == null or state.home_lineup == null:
		return {"available": false, "reason": "missing rally state or lineup"}
	if not bool(shadow_attack.get("available", false)):
		return {"available": false, "reason": "shadow attack unavailable"}
	var hitter_response: Dictionary = shadow_attack.get("hitter_response", {})
	if not bool(hitter_response.get("available", false)):
		return {"available": false, "reason": "shadow hitter response unavailable"}

	var source_fingerprint := _state_fingerprint(state)

	var hitter_id := int(hitter_response.get("player_id", -1))
	var true_contact_position := Vector2(hitter_response.get(
		"contact_position", Vector2(0.5, 0.6)
	))
	var true_contact_time := float(hitter_response.get("contact_time", state.simulation_time))
	var set_flight_dict: Dictionary = shadow_attack.get("set_flight", {})
	var set_flight := _reconstruct_set_flight(set_flight_dict)
	var block_contact_height := float(set_flight_dict.get("contact_height_meters", 2.55))

	var setter_id := int(shadow_attack.get("setter_id", -1))
	var setter_actor := state.player_state(&"home", setter_id)

	var block_strategy := str(state.opponent_plan.block_strategy) \
		if state.opponent_plan != null else "Read Block"

	var front_row_ids := state.opponent_lineup.front_row_player_ids()
	var blockers: Array[Dictionary] = []
	for blocker_id in front_row_ids:
		var blocker_actor := state.player_state(&"opponent", blocker_id)
		if blocker_actor == null or blocker_actor.player == null:
			continue
		var teammate_slots: Array[int] = []
		for other_id in front_row_ids:
			if other_id != blocker_id:
				var other_actor := state.player_state(&"opponent", other_id)
				if other_actor != null:
					teammate_slots.append(other_actor.rotation_slot)
		blockers.append(_evaluate_blocker(
			state, blocker_actor, setter_actor, set_flight, hitter_response,
			block_strategy, teammate_slots, true_contact_position, true_contact_time,
			block_contact_height, seed_value,
		))

	var closers: Array[Dictionary] = []
	for blocker in blockers:
		if str(blocker.get("commitment", "")) in [
			"commit_middle", "close_left", "close_right", "assist",
		] and bool(blocker.get("commitment_reachable", false)) \
				and not bool(blocker.get("wrong_read", true)):
			closers.append(blocker)
	closers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_gap := absf(float(a.get("commitment_target_x", 0.0)) - true_contact_position.x)
		var b_gap := absf(float(b.get("commitment_target_x", 0.0)) - true_contact_position.x)
		if is_equal_approx(a_gap, b_gap):
			return int(a.get("blocker_id", -1)) < int(b.get("blocker_id", -1))
		return a_gap < b_gap
	)
	var primary_id := int(closers[0].get("blocker_id", -1)) if not closers.is_empty() else -1
	var assist_id := int(closers[1].get("blocker_id", -1)) if closers.size() > 1 else -1

	var attempted_zones := {}
	for blocker in blockers:
		var implied_zone := str(blocker.get("observation", {}).get(
			"perceived_commitment_zone", ""
		))
		if implied_zone != "":
			attempted_zones[implied_zone] = true
	var commitments_agree := attempted_zones.size() <= 1

	return {
		"available": true,
		"shadow_only": true,
		"hitter_id": hitter_id,
		"attack_contact_position": true_contact_position,
		"attack_contact_time": true_contact_time,
		"block_strategy": block_strategy,
		"blockers": blockers,
		"primary_id": primary_id,
		"assist_id": assist_id,
		"solo_close": closers.size() == 1,
		"coordinated_assist": closers.size() >= 2,
		"commitments_agree": commitments_agree,
		"source_state_unchanged": source_fingerprint == _state_fingerprint(state),
	}


static func _evaluate_blocker(
	state: RallyState,
	blocker_actor: RallyPlayerState,
	setter_actor: RallyPlayerState,
	set_flight: BallFlight,
	hitter_response: Dictionary,
	block_strategy: String,
	teammate_slots: Array[int],
	true_contact_position: Vector2,
	true_contact_time: float,
	contact_height_meters: float,
	seed_value: int,
) -> Dictionary:
	var blocker_id := blocker_actor.player_id
	var reading := _reading_quality(blocker_actor.player)
	var own_zone_x := CourtConstants.slot_position(blocker_actor.rotation_slot).x

	## Cue 1: the attacking setter's position and body language, degraded by
	## the blocker's own reading ability -- never the setter's true position.
	var setter_error := _position_error(
		lerpf(1.35, 0.10, reading), seed_value + blocker_id * 7 + 11
	)
	var perceived_setter_position := (
		_clamp_point(setter_actor.position + setter_error)
		if setter_actor != null else Vector2(0.5, 0.24)
	)
	var setter_cue := _zone_for_x(perceived_setter_position.x)

	## Cue 2: a progressively-refined read of the incoming set flight. The
	## early sample is coarse; the late sample is sharper because more of the
	## flight has been observed -- both are reads of a reconstructed BallFlight
	## value object, never of authoritative RallyState.
	var estimates := BallReadSystem.estimate_sequence(
		set_flight, blocker_actor.player, BLOCK_FAMILIARITY, READ_PROGRESS,
		seed_value + blocker_id * 131,
	)
	var early_estimate: BallFlightEstimate = estimates[0] if estimates.size() > 0 else null
	var late_estimate: BallFlightEstimate = estimates[-1] if estimates.size() > 0 else null
	var perceived_x_early := float(
		early_estimate.perceived_destination.x if early_estimate != null else own_zone_x
	)
	var perceived_x_late := float(
		late_estimate.perceived_destination.x if late_estimate != null else own_zone_x
	)
	var confidence_early := float(early_estimate.confidence if early_estimate != null else 0.0)
	var confidence_late := float(late_estimate.confidence if late_estimate != null else 0.0)
	## How long after the set leaves the setter's hands this blocker recognizes
	## it -- reading-driven, independent of when the sample was taken. Lower is
	## earlier. This is the literal "recognizes earlier" evidence; confidence
	## alone cannot show it, since an elite reader can already be near-ceiling
	## on the very first sample.
	var recognition_delay_seconds := float(
		(late_estimate.recognition_time - set_flight.start_time)
		if late_estimate != null else 0.0
	)

	## Cue 3: a coarse, degraded read of the hitter's approach load. This is
	## the ApproachMechanicsSystem output already computed for the hitter,
	## exposed as an observable cue -- not as access to the hitter's decision.
	var hitter_cue := _hitter_approach_cue(
		hitter_response, reading, seed_value + blocker_id * 271 + 3,
	)

	var decision := _choose_commitment(
		perceived_x_late, confidence_late, own_zone_x, block_strategy, reading,
	)
	var commitment := StringName(decision.get("commitment", &"hold_read"))
	var target_x := float(decision.get("target_x", own_zone_x))

	var commitment_target := Vector2(target_x, CourtConstants.NET_Y)
	var priority := 0.5
	var commitment_opportunity := RallyMovementSystem.evaluate_opportunity(
		blocker_actor, &"block", commitment_target, true_contact_time,
		state.simulation_time, priority, contact_height_meters, true,
	)
	var true_target := Vector2(true_contact_position.x, CourtConstants.NET_Y)
	var true_opportunity := RallyMovementSystem.evaluate_opportunity(
		blocker_actor, &"block", true_target, true_contact_time,
		state.simulation_time, priority, contact_height_meters, true,
	)

	var true_zone := _zone_for_x(true_contact_position.x)
	var implied_zone := str(decision.get("implied_zone", ""))
	var committed := commitment in [&"commit_middle", &"close_left", &"close_right", &"assist"]
	var wrong_read := committed and implied_zone != true_zone
	var decisive_threshold := float(decision.get("decisive_threshold", 0.5))
	var hesitated := commitment == &"hold_read" \
		and confidence_late >= decisive_threshold \
		and bool(true_opportunity.reachable)

	var observation := {
		"observer_id": blocker_id,
		"side": "opponent",
		"own_rotation_slot": blocker_actor.rotation_slot,
		"known_teammate_slots": teammate_slots.duplicate(),
		"block_strategy_instruction": block_strategy,
		"perceived_setter_position": perceived_setter_position,
		"perceived_setter_cue": setter_cue,
		"perceived_set_destination_early": (
			early_estimate.perceived_destination if early_estimate != null else Vector2.ZERO
		),
		"perceived_set_destination_late": (
			late_estimate.perceived_destination if late_estimate != null else Vector2.ZERO
		),
		"confidence_early": confidence_early,
		"confidence_late": confidence_late,
		"recognition_delay_seconds": recognition_delay_seconds,
		"perceived_hitter_approach_cue": hitter_cue,
		"perceived_commitment_zone": implied_zone,
		"decision_uses_authoritative_truth": false,
	}

	var result := {
		"blocker_id": blocker_id,
		"rotation_slot": blocker_actor.rotation_slot,
		"observation": observation,
		"observation_fingerprint": _dict_fingerprint(observation),
		"commitment": String(commitment),
		"commitment_target_x": target_x,
		"commitment_reachable": bool(commitment_opportunity.reachable),
		"commitment_arrival_margin": commitment_opportunity.arrival_margin,
		"commitment_requires_jump": commitment_opportunity.requires_jump,
		"direction_change_delay_seconds": commitment_opportunity.direction_change_delay_seconds,
		"maximum_speed_mps": commitment_opportunity.maximum_speed_mps,
		"decision_uses_authoritative_truth": false,
		"true_contact_x": true_contact_position.x,
		"true_zone": true_zone,
		"true_reachable": bool(true_opportunity.reachable),
		"true_arrival_margin": true_opportunity.arrival_margin,
		"true_requires_jump": true_opportunity.requires_jump,
		"wrong_read": wrong_read,
		"hesitated": hesitated,
	}
	result["commitment_fingerprint"] = _dict_fingerprint(result)
	return result


## Rebuilds a BallFlight value object from ShadowAttackSystem's serialised
## `set_flight` dictionary. ShadowAttackSystem keeps the live BallFlight
## internal; reconstructing it here lets blockers read the same flight with
## BallReadSystem without changing already-calibrated attack code.
static func _reconstruct_set_flight(set_flight_dict: Dictionary) -> BallFlight:
	var signature_dict: Dictionary = set_flight_dict.get("signature", {})
	var signature := BallContactSignature.create(
		StringName(str(signature_dict.get("action_type", "set"))),
		float(signature_dict.get("speed_mps", 0.0)),
		float(signature_dict.get("horizontal_angle_degrees", 0.0)),
		float(signature_dict.get("vertical_angle_degrees", 0.0)),
		float(signature_dict.get("topspin_rps", 0.0)),
		float(signature_dict.get("sidespin_rps", 0.0)),
		float(signature_dict.get("flight_stability", 0.82)),
	)
	return BallFlight.create(
		Vector2(set_flight_dict.get("origin", Vector2(0.5, 0.6))),
		Vector2(set_flight_dict.get("destination", Vector2(0.5, 0.53))),
		float(set_flight_dict.get("start_time", 0.0)),
		float(set_flight_dict.get("duration", 0.48)),
		signature,
		float(set_flight_dict.get("contact_height_meters", 2.55)),
	)


static func _hitter_approach_cue(
	hitter_response: Dictionary,
	reading: float,
	seed_value: int,
) -> Dictionary:
	var resolved: Dictionary = hitter_response.get("resolved_approach", {})
	var true_quality := float(resolved.get("runup_quality", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := rng.randf_range(-1.0, 1.0) * lerpf(0.42, 0.05, reading)
	var perceived_quality := clampf(true_quality + noise, 0.0, 1.0)
	var load_cue := "minimal"
	if perceived_quality >= 0.66:
		load_cue = "loaded"
	elif perceived_quality >= 0.40:
		load_cue = "partial"
	return {
		"perceived_load_cue": load_cue,
		"perceived_quality": perceived_quality,
		"confidence": reading,
	}


## Chooses a commitment from perceived information alone. A tactical
## instruction (Commit Middle / Commit Pin) can override the read entirely --
## that is a called scheme, not a hypothesis. Otherwise the blocker only
## commits once their own confidence clears a reading-skill-scaled bar; sharper
## readers commit on thinner information without moving any faster.
static func _choose_commitment(
	perceived_x_late: float,
	confidence_late: float,
	own_zone_x: float,
	block_strategy: String,
	reading: float,
) -> Dictionary:
	var own_zone := _zone_for_x(own_zone_x)
	var perceived_zone := _zone_for_x(perceived_x_late)
	var decisive_threshold := lerpf(0.62, 0.28, reading)

	if block_strategy == "Commit Middle" and own_zone == "middle":
		return {
			"commitment": &"commit_middle", "target_x": own_zone_x,
			"implied_zone": "middle", "decisive_threshold": decisive_threshold,
		}
	if block_strategy == "Commit Pin" and own_zone != "middle":
		return {
			"commitment": (&"close_left" if own_zone == "left" else &"close_right"),
			"target_x": own_zone_x, "implied_zone": own_zone,
			"decisive_threshold": decisive_threshold,
		}
	if confidence_late < decisive_threshold:
		return {
			"commitment": &"hold_read",
			"target_x": lerpf(own_zone_x, perceived_x_late, 0.35),
			"implied_zone": "", "decisive_threshold": decisive_threshold,
		}
	if perceived_zone == own_zone:
		var commitment := &"commit_middle" if own_zone == "middle" else (
			&"close_left" if own_zone == "left" else &"close_right"
		)
		return {
			"commitment": commitment, "target_x": own_zone_x,
			"implied_zone": own_zone, "decisive_threshold": decisive_threshold,
		}
	if absf(perceived_x_late - own_zone_x) <= ASSIST_TRAVEL_GAP:
		return {
			"commitment": &"assist", "target_x": perceived_x_late,
			"implied_zone": perceived_zone, "decisive_threshold": decisive_threshold,
		}
	return {
		"commitment": &"release", "target_x": own_zone_x,
		"implied_zone": "", "decisive_threshold": decisive_threshold,
	}


static func _zone_for_x(x: float) -> String:
	if x <= PIN_THRESHOLD_LOW:
		return "left"
	if x >= PIN_THRESHOLD_HIGH:
		return "right"
	return "middle"


static func _reading_quality(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	return clampf((
		float(player.anticipation) * 0.32
		+ float(player.court_vision) * 0.24
		+ float(player.decision_making) * 0.18
		+ float(player.tactical_discipline) * 0.16
		+ float(player.composure) * 0.10
	) / 100.0, 0.0, 1.0)


static func _position_error(meters: float, seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var angle := rng.randf_range(-PI, PI)
	var magnitude := meters * rng.randf_range(0.25, 1.0)
	return Vector2(
		cos(angle) * magnitude / RallyKinematics.COURT_WIDTH_METERS,
		sin(angle) * magnitude / RallyKinematics.COURT_LENGTH_METERS,
	)


static func _clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))


static func _dict_fingerprint(value: Dictionary) -> String:
	var keys := value.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		if key in ["observation_fingerprint", "commitment_fingerprint"]:
			continue
		parts.append("%s=%s" % [str(key), str(value[key])])
	return "|".join(parts)


static func _state_fingerprint(state: RallyState) -> String:
	var parts: Array[String] = ["%.6f" % state.simulation_time]
	var home_ids: Array[int] = []
	for player_id in state.home_players:
		home_ids.append(int(player_id))
	home_ids.sort()
	for player_id in home_ids:
		var actor := state.home_players[player_id] as RallyPlayerState
		parts.append("h%d:%s:%s" % [player_id, str(actor.position), str(actor.velocity)])
	var opponent_ids: Array[int] = []
	for player_id in state.opponent_players:
		opponent_ids.append(int(player_id))
	opponent_ids.sort()
	for player_id in opponent_ids:
		var actor := state.opponent_players[player_id] as RallyPlayerState
		parts.append("o%d:%s:%s" % [player_id, str(actor.position), str(actor.velocity)])
	return "|".join(parts)
