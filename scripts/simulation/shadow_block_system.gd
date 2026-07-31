class_name ShadowBlockSystem
extends RefCounted

## Gates 44 and 45: the attack-to-block observation and coordination slice.
##
## Starts from the authoritative shadow-attack flight and player state only at
## the resolver boundary (the point ShadowAttackSystem already resolved a
## hypothetical home attack). From there each opponent front-row blocker forms
## an independent, decision-safe hypothesis: a perceived setter cue, a
## progressively-refined read of the set flight, and a degraded cue about the
## hitter's approach load. Commitments are chosen from that perceived picture
## alone.
##
## Gate 45 adds a second pass. Every blocker then observes their teammates'
## *body* cues -- where a teammate appears to be driving, and whether they look
## committed at all -- and may revise their own tentative commitment before
## anything is graded. A blocker never sees a teammate's private hypothesis,
## confidence, or implied zone; only what a defender could actually see across
## the net, degraded by the observer's own reading ability.
##
## Only afterward, at resolution time, is the final commitment compared against
## the authoritative contact position -- to grade it, never to inform it. This
## system never mutates the source RallyState and never promotes into an
## official BLOCK event; it is shadow-only evidence for later gates.

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

const CLOSING_COMMITMENTS: Array[String] = [
	"commit_middle", "close_left", "close_right", "assist",
]

## When coordination reveals that nobody else is covering the zone this blocker
## reads, responsibility falls to them and the confidence bar drops. Someone has
## to take the swing; hesitating because the read was thin is worse than
## committing on it.
const UNCOVERED_ZONE_THRESHOLD_RELIEF: float = 0.18

## Confidence a blocker needs before committing, as a function of reading skill.
## The sharpest reader in the model commits at SHARPEST; the dullest needs
## DULLEST.
const DECISIVE_THRESHOLD_SHARPEST: float = 0.28
const DECISIVE_THRESHOLD_DULLEST: float = 0.62

## The bar above which holding a reachable read counts as hesitation. It is the
## sharpest reader's threshold, not the holder's own: a blocker only ever holds
## when confidence sits below their personal bar, so grading against that bar
## could never fire at all. Measuring against the best decisiveness the model
## can produce makes hesitation mean something real and non-arbitrary -- "the
## sharpest reader in the league would have gone on this, and you did not."
const HESITATION_CONFIDENCE: float = DECISIVE_THRESHOLD_SHARPEST

## Rotation slots whose home zone a blocker can name from public rotation
## knowledge alone. Used so a blocker can tell "my teammate is driving into the
## zone they already own" from "my teammate is travelling to help".
const SLOT_HOME_ZONE := {2: "right", 3: "middle", 4: "left"}


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

	## Pass one: every blocker reads the play alone, with no knowledge of what
	## any teammate has decided.
	var front_row_ids := state.opponent_lineup.front_row_player_ids()
	var tentative: Array[Dictionary] = []
	var actors_by_id := {}
	for blocker_id in front_row_ids:
		var blocker_actor := state.player_state(&"opponent", blocker_id)
		if blocker_actor == null or blocker_actor.player == null:
			continue
		actors_by_id[blocker_id] = blocker_actor
		var teammate_slots: Array[int] = []
		for other_id in front_row_ids:
			if other_id != blocker_id:
				var other_actor := state.player_state(&"opponent", other_id)
				if other_actor != null:
					teammate_slots.append(other_actor.rotation_slot)
		tentative.append(_evaluate_blocker(
			state, blocker_actor, setter_actor, set_flight, hitter_response,
			block_strategy, teammate_slots, true_contact_position, true_contact_time,
			block_contact_height, seed_value,
		))

	## Pass two: coordination. Every revision reads the same pass-one snapshot,
	## so the outcome does not depend on the order blockers are visited.
	var blockers: Array[Dictionary] = []
	var coordination_changes := 0
	for entry in tentative:
		var coordinated := _coordinate_blocker(
			state, entry, tentative, actors_by_id, true_contact_position,
			true_contact_time, block_contact_height, seed_value,
		)
		if bool(coordinated.get("coordination_changed", false)):
			coordination_changes += 1
		blockers.append(coordinated)

	var roles := _resolve_roles(blockers)

	## Disagreement is measured on the tentative reads: it is the thing
	## coordination exists to resolve, so measuring it after the fact would
	## always report agreement and prove nothing.
	var tentative_zones := {}
	for entry in tentative:
		var zone := str(entry.get("observation", {}).get("perceived_commitment_zone", ""))
		if zone != "":
			tentative_zones[zone] = true
	var final_zones := {}
	for blocker in blockers:
		var zone := str(blocker.get("implied_zone", ""))
		if zone != "":
			final_zones[zone] = true

	return {
		"available": true,
		"shadow_only": true,
		"hitter_id": hitter_id,
		"attack_contact_position": true_contact_position,
		"attack_contact_time": true_contact_time,
		"block_strategy": block_strategy,
		"block_contact_height_meters": block_contact_height,
		"blockers": blockers,
		"primary_id": int(roles.get("primary_id", -1)),
		"assist_id": int(roles.get("assist_id", -1)),
		"closer_count": int(roles.get("closer_count", 0)),
		"solo_close": int(roles.get("closer_count", 0)) == 1,
		"coordinated_assist": int(roles.get("closer_count", 0)) >= 2,
		"tentative_commitments_agree": tentative_zones.size() <= 1,
		"coordinated_commitments_agree": final_zones.size() <= 1,
		"coordination_changes": coordination_changes,
		"source_state_unchanged": source_fingerprint == _state_fingerprint(state),
	}


## Pass one. Produces one blocker's independent, pre-coordination hypothesis,
## already graded against truth so a solo read can be audited on its own. Gate
## 45 keeps these values under `tentative_*` after coordination revises them.
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

	## How far this blocker would have to travel to meet the swing they think
	## they see. Measured against the *perceived* attack point, so it is known
	## before a commitment is chosen and never smuggles truth into the decision.
	var engagement := _block_engagement_fit(
		blocker_actor, Vector2(perceived_x_late, CourtConstants.NET_Y)
	)

	var decision := _choose_commitment(
		perceived_x_late, confidence_late, own_zone_x, block_strategy, reading,
		engagement,
	)
	var commitment := StringName(decision.get("commitment", &"hold_read"))
	var target_x := float(decision.get("target_x", own_zone_x))
	var implied_zone := str(decision.get("implied_zone", ""))
	var decisive_threshold := float(decision.get("decisive_threshold", 0.5))

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
		"perceived_engagement_distance_meters": float(engagement.get("distance_meters", 0.0)),
		"perceived_engagement_fit": float(engagement.get("fit", 0.0)),
		"perceived_engagement_in_system": bool(engagement.get("in_system", false)),
		"perceived_commitment_zone": implied_zone,
		"decision_uses_authoritative_truth": false,
	}

	var graded := _grade_commitment(
		state, blocker_actor, commitment, target_x,
		true_contact_position, true_contact_time, contact_height_meters,
		confidence_late, decisive_threshold, _zone_for_x(perceived_x_late),
	)

	var result := {
		"blocker_id": blocker_id,
		"rotation_slot": blocker_actor.rotation_slot,
		"observation": observation,
		"observation_fingerprint": _dict_fingerprint(observation),
		"commitment": String(commitment),
		"commitment_target_x": target_x,
		"implied_zone": implied_zone,
		"decisive_threshold": decisive_threshold,
		"confidence_late": confidence_late,
		"reading_quality": reading,
		"perceived_attack_x": perceived_x_late,
		"own_zone_x": own_zone_x,
		"block_engagement_ideal_meters": float(engagement.get("ideal_meters", 0.0)),
		"block_engagement_distance_meters": float(engagement.get("distance_meters", 0.0)),
		"block_engagement_fit": float(engagement.get("fit", 0.0)),
		"block_engagement_in_system": bool(engagement.get("in_system", false)),
		"decision_uses_authoritative_truth": false,
	}
	result.merge(graded)
	result["commitment_fingerprint"] = _dict_fingerprint(result)
	return result


## Pass two. Revises one blocker's tentative commitment from what they can see
## their teammates doing. `tentative` is the pass-one snapshot for every
## blocker, so all revisions are simultaneous and order-independent.
static func _coordinate_blocker(
	state: RallyState,
	own: Dictionary,
	tentative: Array[Dictionary],
	actors_by_id: Dictionary,
	true_contact_position: Vector2,
	true_contact_time: float,
	contact_height_meters: float,
	seed_value: int,
) -> Dictionary:
	var blocker_id := int(own.get("blocker_id", -1))
	var blocker_actor := actors_by_id.get(blocker_id) as RallyPlayerState
	var reading := float(own.get("reading_quality", 0.0))
	var cues := _observe_teammate_cues(tentative, blocker_id, reading, seed_value)

	var revision := _coordinate_commitment(own, cues)
	var result := own.duplicate(true)
	var observation: Dictionary = result.get("observation", {})
	observation["perceived_teammate_cues"] = cues
	result["observation"] = observation
	result["observation_fingerprint"] = _dict_fingerprint(observation)

	## Keep the solo read as evidence; the top-level keys always describe the
	## decision the blocker actually leaves with.
	result["tentative_commitment"] = str(own.get("commitment", ""))
	result["tentative_commitment_target_x"] = float(own.get("commitment_target_x", 0.0))
	result["tentative_implied_zone"] = str(own.get("implied_zone", ""))
	result["tentative_wrong_read"] = bool(own.get("wrong_read", false))
	result["coordination_changed"] = bool(revision.get("changed", false))
	result["coordination_reason"] = str(revision.get("reason", "no change"))

	if not bool(revision.get("changed", false)):
		result["commitment_fingerprint"] = _dict_fingerprint(result)
		return result

	var commitment := StringName(revision.get("commitment", &"hold_read"))
	var target_x := float(revision.get("target_x", own.get("commitment_target_x", 0.5)))
	result["commitment"] = String(commitment)
	result["commitment_target_x"] = target_x
	result["implied_zone"] = str(revision.get("implied_zone", ""))
	if blocker_actor != null:
		var engagement := _block_engagement_fit(
			blocker_actor, Vector2(target_x, CourtConstants.NET_Y)
		)
		result["block_engagement_distance_meters"] = float(engagement.get("distance_meters", 0.0))
		result["block_engagement_fit"] = float(engagement.get("fit", 0.0))
		result["block_engagement_in_system"] = bool(engagement.get("in_system", false))
		result.merge(_grade_commitment(
			state, blocker_actor, commitment, target_x,
			true_contact_position, true_contact_time, contact_height_meters,
			float(own.get("confidence_late", 0.0)),
			float(own.get("decisive_threshold", 0.5)),
			_zone_for_x(float(own.get("perceived_attack_x", 0.5))),
		), true)
	result["commitment_fingerprint"] = _dict_fingerprint(result)
	return result


## What one blocker can actually see their teammates doing. Deliberately narrow:
## the direction a teammate appears to be driving, and whether they look
## committed at all. A teammate's confidence, implied zone, engagement fit, and
## every graded field stay private -- those are not visible across a court.
static func _observe_teammate_cues(
	tentative: Array[Dictionary],
	observer_id: int,
	observer_reading: float,
	seed_value: int,
) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	for raw_other in tentative:
		var other: Dictionary = raw_other
		var other_id := int(other.get("blocker_id", -1))
		if other_id == observer_id:
			continue
		var other_slot := int(other.get("rotation_slot", -1))
		var visibly_driving := str(other.get("commitment", "")) in CLOSING_COMMITMENTS
		var error := _position_error(
			lerpf(0.90, 0.06, observer_reading),
			seed_value + other_id * 617 + observer_id * 29,
		)
		var perceived_x := clampf(
			float(other.get("commitment_target_x", 0.5)) + error.x, 0.0, 1.0
		)
		cues.append({
			"teammate_slot": other_slot,
			"teammate_home_zone": str(SLOT_HOME_ZONE.get(other_slot, "")),
			"perceived_movement_zone": _zone_for_x(perceived_x),
			"perceived_committed": visibly_driving,
			"cue_confidence": observer_reading,
		})
	cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("teammate_slot", -1)) < int(b.get("teammate_slot", -1))
	)
	return cues


## The coordination rules. Every branch reads only this blocker's own
## (perceived) picture plus the teammate body cues above.
static func _coordinate_commitment(
	own: Dictionary,
	cues: Array[Dictionary],
) -> Dictionary:
	var commitment := str(own.get("commitment", ""))
	var own_zone := _zone_for_x(float(own.get("own_zone_x", 0.5)))
	var perceived_x := float(own.get("perceived_attack_x", 0.5))
	var perceived_zone := _zone_for_x(perceived_x)
	var confidence := float(own.get("confidence_late", 0.0))
	var threshold := float(own.get("decisive_threshold", 0.5))

	var covered_zones := {}
	var any_teammate_committed := false
	for raw_cue in cues:
		var cue: Dictionary = raw_cue
		if bool(cue.get("perceived_committed", false)):
			any_teammate_committed = true
			covered_zones[str(cue.get("perceived_movement_zone", ""))] = true
	var perceived_zone_covered := covered_zones.has(perceived_zone)

	## Nobody appears to be taking the swing this blocker reads. Responsibility
	## falls to them, so the confidence bar drops -- a thin read is still better
	## than an unblocked hitter.
	if commitment == "hold_read" and not perceived_zone_covered \
			and confidence >= threshold - UNCOVERED_ZONE_THRESHOLD_RELIEF:
		if perceived_zone == own_zone:
			return {
				"changed": true, "implied_zone": own_zone,
				"commitment": _own_zone_commitment(own_zone),
				"target_x": float(own.get("own_zone_x", 0.5)),
				"reason": "stepped up: own zone uncovered",
			}
		if absf(perceived_x - float(own.get("own_zone_x", 0.5))) <= ASSIST_TRAVEL_GAP:
			return {
				"changed": true, "commitment": "assist", "target_x": perceived_x,
				"implied_zone": perceived_zone,
				"reason": "stepped up: read zone uncovered",
			}

	## Committed to defending home while the read says the swing is going
	## somewhere nobody has covered. Leaving an uncontested zone to hold a zone
	## the ball is not coming to is the worse of the two mistakes.
	if commitment == _own_zone_commitment(own_zone) and perceived_zone != own_zone \
			and not perceived_zone_covered and confidence >= threshold \
			and absf(perceived_x - float(own.get("own_zone_x", 0.5))) <= ASSIST_TRAVEL_GAP:
		return {
			"changed": true, "commitment": "assist", "target_x": perceived_x,
			"implied_zone": perceived_zone,
			"reason": "released home zone: read zone uncovered",
		}

	## Released entirely, but no teammate looks committed anywhere. Someone has
	## to contest the swing.
	if commitment == "release" and not any_teammate_committed \
			and absf(perceived_x - float(own.get("own_zone_x", 0.5))) <= ASSIST_TRAVEL_GAP:
		return {
			"changed": true, "commitment": "assist", "target_x": perceived_x,
			"implied_zone": perceived_zone,
			"reason": "re-engaged: no teammate committed",
		}

	## The characteristic block coordination: a teammate is closing the zone they
	## own, this blocker reads the same zone and can travel to it, so they join
	## and make it a double block instead of standing in a zone the ball is not
	## coming to. This is the move that turns two independent reads into one
	## block.
	if commitment in ["hold_read", "release"] and perceived_zone != own_zone \
			and absf(perceived_x - float(own.get("own_zone_x", 0.5))) <= ASSIST_TRAVEL_GAP:
		for raw_cue in cues:
			var join_cue: Dictionary = raw_cue
			if bool(join_cue.get("perceived_committed", false)) \
					and str(join_cue.get("perceived_movement_zone", "")) == perceived_zone:
				return {
					"changed": true, "commitment": "assist", "target_x": perceived_x,
					"implied_zone": perceived_zone,
					"reason": "joined: closing with the zone owner",
				}

	## Travelling to help a seam that already has two bodies converging on it
	## while a zone this blocker could still reach is left with nobody. A third
	## blocker on one swing is worth less than a body on the open one.
	if commitment == "assist":
		var committed_on_target := 0
		for raw_cue in cues:
			var cue: Dictionary = raw_cue
			if bool(cue.get("perceived_committed", false)) \
					and str(cue.get("perceived_movement_zone", "")) == perceived_zone:
				committed_on_target += 1
		if committed_on_target >= 2:
			return {
				"changed": true, "commitment": _own_zone_commitment(own_zone),
				"target_x": float(own.get("own_zone_x", 0.5)),
				"implied_zone": own_zone,
				"reason": "declined third body: held own zone instead",
			}

	return {"changed": false, "reason": "no change"}


static func _own_zone_commitment(own_zone: String) -> String:
	if own_zone == "middle":
		return "commit_middle"
	return "close_left" if own_zone == "left" else "close_right"


## Resolves primary and assist from the coordinated commitments alone. Gate 44
## ranked closers by how near their target landed to the authoritative contact,
## which graded a read rather than describing a block; roles now come from who
## owns the zone they are closing and who arrives with more margin.
static func _resolve_roles(blockers: Array[Dictionary]) -> Dictionary:
	var closers: Array[Dictionary] = []
	for blocker in blockers:
		if str(blocker.get("commitment", "")) in CLOSING_COMMITMENTS \
				and bool(blocker.get("commitment_reachable", false)):
			closers.append(blocker)
	closers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_owner := str(a.get("implied_zone", "")) == _zone_for_x(
			float(a.get("own_zone_x", 0.5))
		)
		var b_owner := str(b.get("implied_zone", "")) == _zone_for_x(
			float(b.get("own_zone_x", 0.5))
		)
		if a_owner != b_owner:
			return a_owner
		var a_margin := float(a.get("commitment_arrival_margin", -99.0))
		var b_margin := float(b.get("commitment_arrival_margin", -99.0))
		if not is_equal_approx(a_margin, b_margin):
			return a_margin > b_margin
		return int(a.get("blocker_id", -1)) < int(b.get("blocker_id", -1))
	)
	return {
		"primary_id": int(closers[0].get("blocker_id", -1)) if not closers.is_empty() else -1,
		"assist_id": int(closers[1].get("blocker_id", -1)) if closers.size() > 1 else -1,
		"closer_count": closers.size(),
	}


## Grades one fixed commitment against authoritative contact truth. Called only
## after a commitment has been chosen, never before.
static func _grade_commitment(
	state: RallyState,
	blocker_actor: RallyPlayerState,
	commitment: StringName,
	target_x: float,
	true_contact_position: Vector2,
	true_contact_time: float,
	contact_height_meters: float,
	confidence_late: float,
	decisive_threshold: float,
	perceived_zone: String,
) -> Dictionary:
	var priority := 0.5
	var simulation_time := state.simulation_time if state != null else 0.0
	var commitment_opportunity := RallyMovementSystem.evaluate_opportunity(
		blocker_actor, &"block", Vector2(target_x, CourtConstants.NET_Y),
		true_contact_time, simulation_time, priority, contact_height_meters, true,
	)
	var true_opportunity := RallyMovementSystem.evaluate_opportunity(
		blocker_actor, &"block", Vector2(true_contact_position.x, CourtConstants.NET_Y),
		true_contact_time, simulation_time, priority, contact_height_meters, true,
	)
	var true_zone := _zone_for_x(true_contact_position.x)
	var committed := String(commitment) in CLOSING_COMMITMENTS
	var implied_zone := _zone_for_x(target_x) if committed else ""
	return {
		"commitment_reachable": bool(commitment_opportunity.reachable),
		"commitment_arrival_margin": commitment_opportunity.arrival_margin,
		"commitment_requires_jump": commitment_opportunity.requires_jump,
		"commitment_takeoff_time_seconds": commitment_opportunity.takeoff_time_seconds,
		"commitment_maximum_contact_height_meters": \
			commitment_opportunity.maximum_contact_height_meters,
		"direction_change_delay_seconds": commitment_opportunity.direction_change_delay_seconds,
		"maximum_speed_mps": commitment_opportunity.maximum_speed_mps,
		"true_contact_x": true_contact_position.x,
		"true_zone": true_zone,
		"true_reachable": bool(true_opportunity.reachable),
		"true_arrival_margin": true_opportunity.arrival_margin,
		"true_requires_jump": true_opportunity.requires_jump,
		## A misread is a perception failure: this blocker believed the swing was
		## coming from somewhere it was not, and committed on that belief.
		"wrong_read": committed and perceived_zone != "" and perceived_zone != true_zone,
		## Where the body actually ended up. This can be off target even after a
		## correct read, when coordination deliberately sent the blocker
		## elsewhere -- that is a tactical choice, not a misread, and the two
		## must stay separately countable.
		"commitment_off_target": committed and implied_zone != true_zone,
		## Hesitation is specifically failing to pull the trigger on a read that
		## was already good enough, measured against the absolute
		## HESITATION_CONFIDENCE bar rather than this blocker's own threshold.
		## A `release` is a deliberate decision to leave the block, not a
		## failure to decide, so it never counts here.
		"hesitated": String(commitment) == "hold_read" \
			and confidence_late >= HESITATION_CONFIDENCE \
			and bool(true_opportunity.reachable),
	}


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


## Scores the distance this blocker would have to close against their own
## `block_engagement_distance` SystemFitProfile -- how late they naturally hold
## before committing the closing burst. A blocker asked to engage from well
## outside that band is out of system and needs a firmer read before pulling the
## trigger; one on their natural mark can commit slightly sooner.
static func _block_engagement_fit(
	blocker_actor: RallyPlayerState,
	target: Vector2,
) -> Dictionary:
	var distance := RallyKinematics.court_delta_meters(
		blocker_actor.position, target
	).length()
	var profile := blocker_actor.player.system_fit(
		VolleyballPlayer.SYSTEM_FIT_BLOCK_ENGAGEMENT
	)
	if profile == null:
		return {
			"distance_meters": distance, "ideal_meters": 0.0,
			"fit": 0.0, "in_system": false, "bonus_multiplier": 1.0,
		}
	var evaluation := profile.evaluate(
		distance, blocker_actor.player.system_fit_tolerance_scale()
	)
	return {
		"distance_meters": distance,
		"ideal_meters": profile.ideal_value,
		"fit": float(evaluation.get("fit", 0.0)),
		"in_system": bool(evaluation.get("in_system", false)),
		"bonus_multiplier": float(evaluation.get("bonus_multiplier", 1.0)),
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
	engagement: Dictionary = {},
) -> Dictionary:
	var own_zone := _zone_for_x(own_zone_x)
	var perceived_zone := _zone_for_x(perceived_x_late)
	## Reading skill sets the bar; landing on this blocker's natural engagement
	## distance eases it, because a close they have made a thousand times needs
	## less confirmation than one from an unfamiliar range.
	var decisive_threshold := lerpf(
		DECISIVE_THRESHOLD_DULLEST, DECISIVE_THRESHOLD_SHARPEST, reading
	)
	if bool(engagement.get("in_system", false)):
		decisive_threshold /= maxf(float(engagement.get("bonus_multiplier", 1.0)), 1.0)

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
	if state == null:
		return ""
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
