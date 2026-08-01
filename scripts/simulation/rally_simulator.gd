class_name RallySimulator
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyResultModel := preload("res://scripts/models/rally_result.gd")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
const CoverageModel := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const ShadowReceptionSystemModel := preload("res://scripts/simulation/shadow_reception_system.gd")
const RallyShadowComparisonModel := preload("res://scripts/simulation/rally_shadow_comparison.gd")
const RallyRolloutPolicyModel := preload("res://scripts/simulation/rally_rollout_policy.gd")
const RallyFeatureFlagsModel := preload("res://scripts/simulation/rally_feature_flags.gd")
const RallyStateBuilderModel := preload("res://scripts/simulation/rally_state_builder.gd")
const LiveReceptionIntegratorModel := preload(
	"res://scripts/simulation/live_reception_integrator.gd"
)
const LiveSetterIntegratorModel := preload(
	"res://scripts/simulation/live_setter_integrator.gd"
)
const ShadowAttackSystemModel := preload(
	"res://scripts/simulation/shadow_attack_system.gd"
)
const LiveAttackIntegratorModel := preload(
	"res://scripts/simulation/live_attack_integrator.gd"
)
const ApproachMechanicsModel := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)
const ShadowBlockSystemModel := preload(
	"res://scripts/simulation/shadow_block_system.gd"
)
const LiveBlockIntegratorModel := preload(
	"res://scripts/simulation/live_block_integrator.gd"
)
const RallyMovementSystemModel := preload(
	"res://scripts/simulation/rally_movement_system.gd"
)
const SetterCapabilityModel := preload(
	"res://scripts/simulation/setter_capability_system.gd"
)
const AttemptJudgmentModel := preload(
	"res://scripts/simulation/attempt_judgment.gd"
)
const RallyKinematicsModel := preload(
	"res://scripts/simulation/rally_kinematics.gd"
)
const MAX_EXCHANGES: int = 4

const OPPONENT_SERVE: float = 0.63
const OPPONENT_BLOCK: float = 0.61
const OPPONENT_DEFENSE: float = 0.58

## Fallbacks for a setter with no derived release profile. These are the
## midpoints of the bands `VolleyballPlayer.refresh_system_fit_profiles()`
## produces, so a profile-less setter behaves like an average one.
## Where the two blockers stand when a wall forms. A double block is two players
## shoulder to shoulder at the net, not two markers at one coordinate: playback
## had been placing each blocker at their own defensive court position, which for
## a block resolves both onto the attack lane and draws them stacked. Geometry is
## the resolver's to own, so the pair is recorded on the event.
const BLOCK_SHOULDER_OFFSET: float = 0.085
const BLOCK_NET_DEPTH: float = 0.032

## Lane a blocker covers with their arms without moving their feet.
const BLOCK_LATERAL_REACH_METERS: float = 0.45
## Loading and leaving the ground. A blocker still shuffling when the ball
## arrives has not blocked it, so this comes off the end of the closing window.
const BLOCK_PLANT_SECONDS: float = 0.26
## How late a blocker must be for the lane to be completely open.
const BLOCK_CLOSE_FAILURE_SECONDS: float = 0.45
## What a completely beaten blocker still contributes -- a hand in the air near
## the ball, not a wall. Zero would say a late blocker is not on the court.
const BLOCK_UNCLOSED_SHARE: float = 0.18

## One blocker against a hitter with the whole court is not most of a wall. At
## 0.78 a solo block outscored a typical swing, so the engine stuffed 28% of
## attacks and produced fifteen kills in three hundred and fifty swings.
const BLOCK_SOLO_SHARE: float = 0.62
## How much of what the primary left open a sealed assist covers.
const BLOCK_ASSIST_SHARE: float = 0.55

## How much a formed block takes off the swing hit into it. The primary carries
## most of it; a sealed assist adds the rest of the wall.
## Deliberately modest, because the block gets two bites: it lowers the swing
## here and then contests it. At 0.20/0.08 -- values set while the block was
## still saturated and therefore constant -- the two compounded into a 0.386
## stuff rate once closes actually varied.
const BLOCK_PRIMARY_PRESSURE: float = 0.06
const BLOCK_ASSIST_PRESSURE: float = 0.03

## What a hitter brings to a swing, as a fraction of an ideal one. These sum to
## 1.0 on purpose: a quality that is a fraction of an ideal can be compared with
## a block quality that is also a fraction of an ideal, and a margin of 0.06
## between them means something.
const ATTACK_ACCURACY_WEIGHT: float = 0.50
const ATTACK_POWER_WEIGHT: float = 0.32
const ATTACK_DECISION_WEIGHT: float = 0.18

## How much of the swing each dimension of the opportunity can take away. They
## multiply rather than add, because a swing is only as good as the worst thing
## about it.
const SET_OPPORTUNITY_WEIGHT: float = 0.40
const APPROACH_OPPORTUNITY_WEIGHT: float = 0.26
const TIMING_OPPORTUNITY_WEIGHT: float = 0.45

## Arriving this far behind the ball costs the whole timing dimension.
const LATE_ARRIVAL_SECONDS: float = 0.60

## Execution spread that is not attributable to anything modelled.
const ATTACK_EXECUTION_NOISE: float = 0.10

## A swing that kept less than this fraction of an ideal one does not land in.
## It is a boundary on the execution scale rather than a rate to hit, and it is
## reachable for the first time: the additive form floored attack quality at
## 0.321 against a threshold of 0.29, so no swing in the engine could ever be an
## error.
const ATTACK_ERROR_THRESHOLD: float = 0.24

## How decisively the block has to beat the swing for each outcome. A block that
## loses the airspace does not get a hand on the ball, so none of these is
## negative by much: at -0.06 and -0.24 the block touched 82% of all attacks and
## rallies never ended.
const BLOCK_STUFF_MARGIN: float = 0.14
const BLOCK_TOUCH_MARGIN: float = 0.06
const BLOCK_FUNNEL_MARGIN: float = -0.02

## How hard a swing attempted outside the approach's capability bites. Mirrors
## `SetterCapabilitySystem.OVERREACH_SEVERITY` at the second contact: a hitter a
## long way past what their run-up gave them does not merely hit worse, they put
## the ball out.
const ATTACK_OVERREACH_SEVERITY: float = 1.60

## Sum of the opponent serve-quality weights, used to normalise them.
const OPPONENT_SERVE_WEIGHT_TOTAL: float = 0.72

const DEFAULT_SET_RELEASE_SECONDS: float = 0.42
const DEFAULT_SET_RELEASE_TOLERANCE: float = 0.105
const MINIMUM_SET_RELEASE_SECONDS: float = 0.15
const MAXIMUM_SET_RELEASE_SECONDS: float = 0.75

var rng := RandomNumberGenerator.new()
var rally_clock: float = 0.0
var live_positions: Dictionary = {}
var opponent_live_positions: Dictionary = {}
var shadow_reception_trace: RallyTrace


func resolve(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	active_play: OffensivePlay,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int,
	development_continuous_reception: bool = false,
) -> Resource:
	rng.seed = seed_value
	rally_clock = 0.0
	shadow_reception_trace = null
	live_positions = _initial_home_positions(lineup, defensive_plan, not home_serving)
	opponent_live_positions = _initial_opponent_positions(opponent_team, home_serving)
	var result: Resource = RallyResultModel.new()
	result.initial_home_positions = live_positions.duplicate(true)
	result.initial_opponent_positions = opponent_live_positions.duplicate(true)
	result.active_play_name = active_play.play_name \
		if active_play != null else "Default T3 Outside"
	if home_serving:
		return _resolve_home_serve(
			result, players, lineup, opponent_team, defensive_plan
		)
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	var opponent_server := opponent_team.player_by_id(
		opponent_lineup.player_at_slot(1) if opponent_lineup != null else -1
	) as VolleyballPlayer
	if opponent_server == null:
		opponent_server = opponent_team.best_server() as VolleyballPlayer
	var server_name := opponent_server.display_name
	var setter := _player_by_id(players, lineup.active_setter_id())
	## Weights are relative importance and are normalised by their own total, so
	## this is a genuine 0-1 quality rather than one capped at the coefficient
	## sum. They previously added to 0.72, which meant an opponent server with
	## every rating at 100 produced 0.72 -- and since reception subtracts
	## `serve_quality * 0.48`, the most dangerous serve in the game could apply
	## only 0.35 of pressure. The home formula already spans the full range
	## because its tactical risk term makes up the remainder.
	var opponent_serve_weighted := _power_rating(opponent_server, "serve_power") * 0.28 \
		+ _rating(opponent_server, "serve_technique") * 0.13 \
		+ _rating(opponent_server, "serve_placement") * 0.07 \
		+ _rating(opponent_server, "serve_consistency") * 0.12 \
		+ _rating(opponent_server, "serve_aggression") * 0.04 \
		+ _serve_style_proficiency(opponent_server) * 0.08
	var serve_quality := clampf(
		opponent_serve_weighted / OPPONENT_SERVE_WEIGHT_TOTAL
		+ rng.randf_range(-0.18, 0.18), 0.05, 0.98
	)
	var opponent_risk := _rating(opponent_server, "serve_aggression")
	var serve_error_chance := clampf(0.025 + opponent_risk * 0.08 \
		- _rating(opponent_server, "serve_consistency") * 0.055 \
		- _serve_style_proficiency(opponent_server) * 0.02, 0.01, 0.15)
	var serve_error := rng.randf() < serve_error_chance
	var intended_target := str(opponent_team.tendencies.get("serve_target", "Zone 5"))
	var serve_landing := _serve_landing_point(
		intended_target, opponent_server, players, lineup, true
	)
	var serve_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(Vector2(0.80, 0.08), serve_landing),
		_serve_launch_angle_degrees(opponent_server, serve_quality),
	)
	var serve_time := float(serve_arc.duration_seconds)
	var serve_trajectory := _ball_trajectory(
		"serve", Vector2(0.80, 0.08), serve_landing, serve_time,
		float(serve_arc.apex_height_meters),
	)
	_add_event(result, RallyEventModel.EventType.SERVE, opponent_server.id, server_name,
		Vector2(0.80, 0.08), serve_landing, not serve_error, serve_quality,
		"%s serve" % opponent_server.primary_serve_style if not serve_error else "Serve misses",
		"%d%% pressure toward the receiver." % roundi(serve_quality * 100.0) \
		if not serve_error else "The serve does not enter the court.", {
			"side": "opponent", "target": intended_target,
			"server_id": opponent_server.id, "server_slot": 1,
			"serve_style": opponent_server.primary_serve_style,
			"flight_time": serve_time,
			"event_time": 0.0, "contact_time": serve_time,
			"outgoing_trajectory": serve_trajectory,
		})
	rally_clock = serve_time

	if serve_error:
		return _finish_serve_error(result, server_name)

	var reception_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		defensive_plan.zones_for(DefensiveZoneModel.ZoneType.SERVE_RECEIVE),
		serve_landing, serve_time, "reception",
	)
	var receiver := reception_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = _nearest_reception_player(players, lineup, defensive_plan, serve_landing)
	var receiver_zone: Resource = defensive_plan.zone_for(
		receiver.id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	) if defensive_plan != null and receiver != null else null
	shadow_reception_trace = ShadowReceptionSystemModel.evaluate(
		players, lineup, defensive_plan, opponent_team,
		opponent_server, opponent_server.primary_serve_style,
		serve_quality, serve_trajectory,
		receiver.id if receiver != null else -1,
		seed_value,
	)
	var shadow_summary: Dictionary = shadow_reception_trace.summary
	shadow_summary["rollout_entries"] = shadow_reception_trace.entries.duplicate(true)
	var rollout_requested := development_continuous_reception \
		and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE
	var reception_rollout := RallyRolloutPolicyModel.select_reception_source(
		result.events, shadow_summary, lineup, rollout_requested
	)
	var selected_live_reception: Dictionary = reception_rollout.get(
		"selected_reception", {}
	)
	var live_reception_integration: Dictionary = {}
	var live_state: RallyState = null
	if str(reception_rollout.get("selected_source", "official")) \
			== "continuous_reception":
		live_state = RallyStateBuilderModel.build(
			players, lineup, defensive_plan, opponent_team,
			active_play, false, seed_value
		)
		live_reception_integration = LiveReceptionIntegratorModel.apply(
			live_state, shadow_summary, selected_live_reception
		)
		if not bool(live_reception_integration.get("applied", false)):
			reception_rollout = RallyRolloutPolicyModel.select_reception_source(
				result.events, shadow_summary, lineup, false
			)
			selected_live_reception = {}
		else:
			shadow_summary["live_reception_integration"] = \
				live_reception_integration
			var canonical_serve_duration := maxf(
				float(shadow_summary.get("true_arrival_time", serve_time))
					- float(shadow_summary.get("flight_start_time", 0.0)),
				0.01,
			)
			var serve_event := result.events[0] as RallyEvent
			if serve_event != null:
				serve_event.metadata["flight_time"] = canonical_serve_duration
				serve_event.metadata["contact_time"] = float(shadow_summary.get(
					"true_arrival_time", canonical_serve_duration
				))
				serve_event.metadata["outgoing_trajectory"] = _ball_trajectory(
					"continuous_serve", serve_event.start_position,
					serve_event.end_position, canonical_serve_duration, 0.45,
					float(shadow_summary.get("flight_start_time", 0.0)),
				)
				serve_event.metadata["continuous_reception_timing"] = true
	var rollout_evidence := reception_rollout.duplicate(true)
	rollout_evidence.erase("selected_events")
	rollout_evidence.erase("selected_reception")
	shadow_summary["reception_rollout"] = rollout_evidence
	shadow_summary.erase("rollout_entries")
	shadow_reception_trace.summary = shadow_summary
	var using_live_reception := not selected_live_reception.is_empty() \
		and bool(live_reception_integration.get("applied", false))
	if using_live_reception:
		var live_receiver_id := int(selected_live_reception.get("actor_id", -1))
		var live_receiver := _player_by_id(players, live_receiver_id)
		if live_receiver != null:
			receiver = live_receiver
			receiver_arrived = true
	var arrival: Dictionary = reception_claim.get("arrival", {})
	if using_live_reception:
		arrival = live_reception_integration.get("arrival", {})
	var arrival_bonus := clampf(
		float(arrival.get("arrival_margin", -1.0)) * 0.07, -0.16, 0.12
	)
	var support_count := int(reception_claim.get("support_count", 0))
	var support_bonus := minf(float(support_count) * 0.025, 0.075)
	var seam_conflict := bool(reception_claim.get("seam_conflict", false))
	if using_live_reception:
		support_count = 0
		support_bonus = 0.0
		seam_conflict = false
	var seam_penalty := 0.09 if seam_conflict else 0.0
	var reception_base := _rating(receiver, "reception") * 0.65 \
		+ _rating(receiver, "ball_control") * 0.20 \
		+ _rating(receiver, "composure") * 0.15
	## No flat bonus. A `+ 0.30` term used to sit at the end of this sum and it
	## almost exactly cancelled the best serve in the game: serve pressure is
	## `serve_quality * 0.48` and serve quality never exceeded 0.645, so the most
	## dangerous serve possible subtracted 0.31 while every reception was handed
	## 0.30 back unconditionally. Reception quality never fell below 0.387 against
	## an ace threshold of 0.18, which is why the engine produced no aces at all.
	result.reception_quality = clampf(reception_base - serve_quality * 0.48 \
		- CoverageModel.reception_body_penalty(receiver, arrival, serve_quality) \
		+ arrival_bonus + support_bonus - seam_penalty \
		+ rng.randf_range(-0.14, 0.14),
		0.0, 1.0)
	if using_live_reception:
		result.reception_quality = clampf(float(selected_live_reception.get(
			"quality", 0.0
		)), 0.0, 1.0)
	if not receiver_arrived:
		result.reception_quality = minf(result.reception_quality, 0.12)
	var reception_success: bool = receiver_arrived \
		and float(result.reception_quality) >= 0.18
	var receiver_start: Vector2 = live_positions.get(receiver.id, serve_landing)
	var receiver_move_time := _movement_time(
		receiver, receiver_start, serve_landing, "lateral"
	)
	if using_live_reception:
		var live_metadata: Dictionary = selected_live_reception.get("metadata", {})
		receiver_start = Vector2(live_metadata.get(
			"movement_start", receiver_start
		))
		receiver_move_time = float(live_metadata.get(
			"movement_duration", receiver_move_time
		))
		live_positions[receiver.id] = Vector2(live_reception_integration.get(
			"receiver_center_position", serve_landing
		))
		rally_clock = float(live_reception_integration.get(
			"simulation_time", rally_clock
		))
	else:
		live_positions[receiver.id] = serve_landing
	var preferred_release: Vector2 = defensive_plan.setter_release_target(lineup.active_setter_id()) \
		if defensive_plan != null else Vector2(0.50, 0.60)
	var desired_pass_target: Vector2 = _desired_pass_target(preferred_release, serve_landing)
	var reception_pass := _reception_pass_result(
		receiver, receiver_start, serve_landing, desired_pass_target,
		Vector2(0.80, 0.08), serve_quality, arrival,
		float(result.reception_quality)
	)
	if using_live_reception:
		var selected_metadata: Dictionary = selected_live_reception.get(
			"metadata", {}
		)
		var selected_trajectory: Dictionary = selected_metadata.get(
			"outgoing_trajectory", {}
		)
		reception_pass = {
			"trajectory": selected_trajectory,
			"destination": Vector2(selected_trajectory.get(
				"end_position", desired_pass_target
			)),
			"body_alignment": 1.0,
			"platform_feasibility": float(arrival.get(
				"physical_feasibility", 1.0
			)),
			"contact_posture": str(Dictionary(shadow_summary.get(
				"shadow_decision", {}
			)).get("selected_action", "continuous reception")),
		}
	var pass_trajectory: Dictionary = reception_pass.trajectory
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		serve_landing, Vector2(reception_pass.destination), reception_success,
		result.reception_quality, "%s receives" % receiver.display_name,
		"%d%% reception quality. %s %s" % [
			roundi(float(result.reception_quality) * 100.0),
			_quality_phrase(float(result.reception_quality)),
			_arrival_phrase(arrival, receiver_arrived, support_count) \
			+ (" Equal-priority passers hesitated at the seam." if seam_conflict else ""),
		], {"side": "home", "landing": serve_landing,
			"planner_zone_center": Vector2(receiver_zone.center) \
				if receiver_zone != null else receiver_start,
			"planner_zone_radius_meters": float(receiver_zone.radius_meters) \
				if receiver_zone != null else 0.0,
			"planner_zone_priority": int(receiver_zone.priority) \
				if receiver_zone != null else 0,
			"flight_time": serve_time, "arrival": arrival,
			"support_count": support_count, "seam_conflict": seam_conflict,
			"claim_margin": float(reception_claim.get("claim_margin", 1.0)),
			"movement_start": receiver_start,
			"movement_target": serve_landing if receiver_arrived else receiver_start,
			"movement_duration": receiver_move_time,
			"event_time": rally_clock,
			"incoming_trajectory": serve_trajectory,
			"outgoing_trajectory": pass_trajectory,
			"body_alignment": reception_pass.body_alignment,
			"platform_feasibility": reception_pass.platform_feasibility,
			"contact_posture": reception_pass.contact_posture,
			"desired_pass_target": desired_pass_target,
			"setter_release_target": preferred_release,
			"actual_pass_target": reception_pass.destination,
			"continuous_reception": using_live_reception,
			"rollout_source": str(reception_rollout.get(
				"selected_source", "official"
			)),
			"persistent_state_update": live_reception_integration.duplicate(true) \
				if using_live_reception else {}})
	if seam_conflict:
		result.key_factors.append(ExplanationText.factor("seam_conflict"))
	if not reception_success:
		return _finish(result, "ace", false, receiver.id, {
			"server": server_name,
		})
	var setter_rollout_requested := using_live_reception \
		and development_continuous_reception and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_SETTER_OVERRIDE
	var setter_rollout := RallyRolloutPolicyModel.select_setter_source(
		shadow_summary, lineup, setter_rollout_requested
	)
	var selected_live_setter: Dictionary = setter_rollout.get(
		"selected_setter", {}
	)
	var live_setter_integration: Dictionary = {}
	if str(setter_rollout.get("selected_source", "official")) \
			== "continuous_setter":
		live_setter_integration = LiveSetterIntegratorModel.apply(
			live_state, selected_live_setter
		)
		if not bool(live_setter_integration.get("applied", false)):
			setter_rollout = RallyRolloutPolicyModel.select_setter_source(
				shadow_summary, lineup, false
			)
			selected_live_setter = {}
		else:
			shadow_summary["live_setter_integration"] = \
				live_setter_integration
	var setter_rollout_evidence := setter_rollout.duplicate(true)
	setter_rollout_evidence.erase("selected_setter")
	shadow_summary["setter_rollout"] = setter_rollout_evidence
	shadow_reception_trace.summary = shadow_summary
	var using_live_setter := not selected_live_setter.is_empty() \
		and bool(live_setter_integration.get("applied", false))
	var attack_state := live_state
	if attack_state == null:
		attack_state = RallyStateBuilderModel.build(
			players, lineup, defensive_plan, opponent_team,
			active_play, false, seed_value
		)
	var shadow_attack := ShadowAttackSystemModel.evaluate(
		attack_state,
		Dictionary(shadow_summary.get("shadow_setter_response", {})),
		receiver.id, seed_value + 1700003,
	)
	shadow_summary["shadow_attack"] = shadow_attack
	## Gate 44: shadow-only attack-to-block observation. Always evaluated
	## alongside the shadow attack it observes; never promoted into an
	## official BLOCK event and never gated by a rollout flag.
	shadow_summary["shadow_block"] = ShadowBlockSystemModel.evaluate(
		attack_state, shadow_attack, seed_value + 1900007,
	)
	var attack_rollout_requested := using_live_setter \
		and development_continuous_reception and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_ATTACK_OVERRIDE
	var attack_rollout := RallyRolloutPolicyModel.select_attack_source(
		shadow_summary, lineup, attack_rollout_requested
	)
	var selected_live_attack: Dictionary = attack_rollout.get(
		"selected_attack", {}
	)
	var attack_rollout_evidence := attack_rollout.duplicate(true)
	attack_rollout_evidence.erase("selected_attack")
	shadow_summary["attack_rollout"] = attack_rollout_evidence
	shadow_reception_trace.summary = shadow_summary
	var using_live_attack := not selected_live_attack.is_empty() \
		and str(attack_rollout.get("selected_source", "official")) \
			== "continuous_attack"
	if using_live_attack and not bool(LiveAttackIntegratorModel.validate(
		live_state, selected_live_attack
	).get("valid", false)):
		attack_rollout = RallyRolloutPolicyModel.select_attack_source(
			shadow_summary, lineup, false
		)
		selected_live_attack = {}
		using_live_attack = false
		attack_rollout_evidence = attack_rollout.duplicate(true)
		attack_rollout_evidence.erase("selected_attack")
		shadow_summary["attack_rollout"] = attack_rollout_evidence
		shadow_reception_trace.summary = shadow_summary
	var live_attack_integration: Dictionary = {}
	setter = _second_contact_setter(
		players, lineup, defensive_plan, receiver.id
	)
	var set_contact: Vector2 = reception_pass.destination
	var second_contact_window := float(pass_trajectory.get("duration", 0.68))
	var setter_choice := _spatial_setter_choice(
		players, lineup, defensive_plan, receiver.id, setter,
		set_contact, second_contact_window
	)
	setter = setter_choice.player as VolleyballPlayer
	var setter_start: Vector2 = setter_choice.start
	var setter_move_time := float(setter_choice.travel_time)
	var setter_arrival_margin := second_contact_window - setter_move_time
	if using_live_setter:
		var promoted_setter := _player_by_id(
			players, int(selected_live_setter.get("actor_id", -1))
		)
		if promoted_setter != null:
			setter = promoted_setter
		set_contact = Vector2(selected_live_setter.get(
			"contact_position", set_contact
		))
		setter_start = Vector2(selected_live_setter.get(
			"movement_start", setter_start
		))
		setter_move_time = float(selected_live_setter.get(
			"movement_duration", setter_move_time
		))
		setter_arrival_margin = float(selected_live_setter.get(
			"arrival_margin", setter_arrival_margin
		))
		second_contact_window = maxf(
			float(selected_live_setter.get("contact_time", rally_clock))
				- rally_clock,
			0.0,
		)
	## Playback draws support movement one ball-flight leg at a time. Without
	## this hint the setter is drawn as a generic support player during the
	## serve's flight, then snapped onto their real transition line once they
	## become the set's actor -- visible as running backwards. Staging the
	## target on the reception event lets that leg carry them to setter_start
	## directly, so the following leg starts where it already expects.
	var reception_event_for_staging := result.events[-1] as RallyEvent
	if reception_event_for_staging != null:
		reception_event_for_staging.metadata["staged_next_actor_id"] = setter.id
		reception_event_for_staging.metadata["staged_next_position"] = setter_start
	var emergency_setter := setter != null and setter.id != lineup.active_setter_id()

	var follow_threshold := 0.22 + _rating(setter, "decision_making") * 0.35 \
		+ _rating(setter, "tactical_discipline") * 0.18
	result.play_was_followed = active_play != null \
		and result.reception_quality >= 0.42 \
		and rng.randf() < follow_threshold
	var assignment := _choose_assignment(
		active_play, result.play_was_followed, players, lineup, setter.id
	)
	if using_live_attack:
		assignment = _assignment_from_dict(Dictionary(selected_live_attack.get(
			"assignment", {}
		)))
		## A player may attack after receiving, but cannot make the second and
		## third contacts consecutively. Reject an otherwise valid live candidate
		## if emergency setting made its assigned hitter the last toucher.
		if assignment != null and assignment.player_id == setter.id:
			using_live_attack = false
			selected_live_attack = {}
			attack_rollout_evidence["selected_source"] = "official"
			attack_rollout_evidence["fallback_reason"] = \
				"selected hitter made second contact"
			shadow_summary["attack_rollout"] = attack_rollout_evidence
			shadow_reception_trace.summary = shadow_summary
			assignment = _choose_assignment(
				active_play, false, players, lineup, setter.id
			)
	var hitter := _player_by_id(players, assignment.player_id) if assignment != null else null
	if hitter == null or hitter.id == setter.id:
		hitter = _fallback_hitter(players, lineup, setter.id)
		assignment = _fallback_assignment(hitter, lineup)
	if active_play == null:
		result.key_factors.append(ExplanationText.factor("default_offense"))
	else:
		result.key_factors.append(ExplanationText.factor(
			"play_followed" if result.play_was_followed else "play_abandoned"
		))
	result.key_factors.append(ExplanationText.factor(
		"good_pass" if result.reception_quality >= 0.58 else "poor_pass"
	))
	_add_event(result, RallyEventModel.EventType.SET_DECISION, setter.id, setter.display_name,
		Vector2(0.50, 0.67), Vector2(0.50, 0.60), true,
		result.reception_quality,
		"Emergency setter decision" if emergency_setter else "Setter decision",
		"Stays with %s." % result.active_play_name if result.play_was_followed \
		else ("Uses the default T3 ball to the nearest outside pin." \
		if active_play == null else "Moves to the safest available option."),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id,
			"event_time": rally_clock, "deadline": rally_clock + second_contact_window,
			"incoming_trajectory": pass_trajectory})

	## What this setter can do with the ball they are about to receive, and what
	## it costs them if they try for more. Nothing is forbidden here: a setter
	## may attempt a tempo beyond their command or reach for a ball above their
	## jump, and the penalty scales with how far outside they went.
	##
	## A setter who arrives early can take a short approach into a jump set,
	## which is exactly how they buy the height a sailing pass demands; one who
	## is still scrambling takes it flat-footed. Arrival margin is already the
	## measure of that, so it becomes the approach the jump gets.
	var setter_approach_quality := clampf(
		inverse_lerp(-0.25, 0.45, setter_arrival_margin), 0.0, 1.0
	)
	var setter_capability := SetterCapabilityModel.evaluate(
		setter, assignment.tempo, float(result.reception_quality),
		SetterCapabilityModel.pass_contact_height_meters(
			float(result.reception_quality), rng.randf()
		),
		setter_approach_quality,
	)
	var resolved_tempo := int(setter_capability.resolved_tempo)
	if bool(setter_capability.tempo_downgraded):
		assignment = _downgraded_assignment(assignment, resolved_tempo)
		result.key_factors.append(ExplanationText.factor("play_abandoned"))
	var tempo_demand := float(3 - resolved_tempo) * 0.055 \
		* lerpf(1.0, 0.65, _rating(setter, "tempo_control"))
	var set_target := CourtConstants.lane_target(assignment.lane)
	var set_geometry := _set_geometry(
		setter, setter_start, set_contact, set_target, preferred_release
	)
	## One number carrying both the overreach and the reach cost, so the severity
	## of attempting something beyond a setter lives with the model that decides
	## what "beyond" means rather than being restated here.
	var capability_penalty := float(setter_capability.quality_penalty)
	var set_base: float = _rating(setter, "set_accuracy") * 0.42 \
		+ _rating(setter, "court_vision") * 0.20 \
		+ _rating(setter, "hand_control") * 0.10 \
		+ _rating(setter, "tempo_control") * 0.08 \
		+ _rating(setter, "composure") * 0.10 \
		+ float(setter_capability.effective_pass_quality) * 0.28 - tempo_demand \
		- capability_penalty \
		+ clampf(setter_arrival_margin * 0.18, -0.42, 0.08) \
		- float(set_geometry.difficulty) + (Familiarity.execution_modifier(setter) - 1.0) * 0.16
	result.set_quality = clampf(set_base + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	var set_angle := _set_launch_angle_degrees(
		setter, assignment.tempo, float(result.set_quality)
	)
	var set_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_contact, set_target), set_angle
	)
	var set_flight_time: float = float(set_arc.duration_seconds)
	var release_profile := setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE)
	var release_interval := _release_interval(release_profile, float(result.set_quality))
	## The instant the ball leaves the setter's hands. The set flight, the SET
	## event, and the hitter's approach window are all timed from this one value.
	var set_contact_time := rally_clock + second_contact_window + release_interval
	var set_trajectory := _ball_trajectory(
		"set", set_contact, set_target, set_flight_time,
		float(set_arc.apex_height_meters),
		set_contact_time
	)
	if using_live_attack:
		set_trajectory = Dictionary(selected_live_attack.get(
			"set_trajectory", set_trajectory
		)).duplicate(true)
		set_flight_time = float(set_trajectory.get(
			"duration", set_flight_time
		))
	if using_live_setter:
		live_setter_integration["outgoing_set_state"] = \
			LiveSetterIntegratorModel.launch_set(
				live_state, set_trajectory, setter.id
			)
		shadow_summary["live_setter_integration"] = \
			live_setter_integration.duplicate(true)
		shadow_reception_trace.summary = shadow_summary
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		set_contact, set_target, result.set_quality >= 0.24,
		result.set_quality, "Set to %s" % assignment.lane,
		("T%d set for %s · %d%% accuracy." % [
			assignment.tempo, hitter.display_name,
			roundi(float(result.set_quality) * 100.0),
		]) + (" Emergency second-contact assignment activated." if emergency_setter else "")
		+ (" Arrived %.2fs before contact." % setter_arrival_margin
			if setter_arrival_margin >= 0.0 else
			" Arrived %.2fs late; set control was reduced." % absf(setter_arrival_margin)),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id, "movement_start": setter_start,
			"movement_duration": setter_move_time,
			"arrival_margin": setter_arrival_margin,
			"deadline": set_contact_time,
			"event_time": set_contact_time,
			"release_interval": release_interval,
			## Why this setter could run this ball and not another one. Carried
			## on the event so the limit is readable in the rally record rather
			## than only visible as a lower quality number.
			"setter_capability": setter_capability.duplicate(true),
			"incoming_trajectory": pass_trajectory,
			"outgoing_trajectory": set_trajectory,
			"set_distance_meters": set_geometry.distance_meters,
			"set_angle_degrees": set_geometry.angle_degrees,
			"release_distance_meters": set_geometry.release_distance_meters,
			"body_orientation_fit": set_geometry.body_orientation_fit,
			"set_balance": set_geometry.set_balance,
			"set_stability": set_geometry.set_stability})
	var set_event := result.events[-1] as RallyEvent
	if using_live_setter and set_event != null:
		set_event.metadata["continuous_setter"] = true
		set_event.metadata["setter_action"] = str(selected_live_setter.get(
			"selected_action", ""
		))
		set_event.metadata["persistent_state_update"] = \
			live_setter_integration.duplicate(true)
	live_positions[setter.id] = Vector2(live_setter_integration.get(
		"setter_center_position", set_contact
	)) if using_live_setter else set_contact
	rally_clock = set_contact_time
	if assignment.tempo <= 1:
		result.key_factors.append(ExplanationText.factor("fast_tempo"))

	var hitter_start: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	var hitter_move_time := _movement_time(
		hitter, hitter_start, set_target, "transition"
	)
	var hitter_arrival_margin := float(set_flight_time) - hitter_move_time
	var approach_preparation: Dictionary = {}
	var resolved_approach: Dictionary = {}
	if using_live_attack:
		hitter_start = Vector2(selected_live_attack.get(
			"source_position", hitter_start
		))
		hitter_move_time = maxf(float(selected_live_attack.get(
			"contact_time", rally_clock + set_flight_time
		)) - rally_clock, 0.0)
		hitter_arrival_margin = float(selected_live_attack.get(
			"arrival_margin", hitter_arrival_margin
		))
		approach_preparation = Dictionary(selected_live_attack.get(
			"transition_preparation", {}
		)).duplicate(true)
		resolved_approach = Dictionary(selected_live_attack.get(
			"resolved_approach", {}
		)).duplicate(true)
	else:
		var hitter_actor := attack_state.player_state(&"home", hitter.id) \
			if attack_state != null else null
		if hitter_actor != null:
			hitter_actor = hitter_actor.snapshot()
			hitter_actor.apply_position(hitter_start, hitter_actor.velocity)
			var assignment_data := {
				"player_id": assignment.player_id,
				"lane": assignment.lane,
				"tempo": assignment.tempo,
				"priority": assignment.priority,
				"target": set_target,
			}
			approach_preparation = ApproachMechanicsModel.prepare_for_attack(
				attack_state, hitter_actor, assignment_data, receiver.id, rally_clock
			)
			var prepared_actor := approach_preparation.get("actor") as RallyPlayerState
			approach_preparation.erase("actor")
			if prepared_actor != null:
				## Preparation relocates where this phase's run-up begins: the
				## travel to the staging mark already happened while the hitter
				## was released. The journey now drawn and timed is
				## staged mark -> approach start -> contact, so both the duration
				## and the arrival margin have to be recomputed. Leaving them
				## stale pairs a staged start with the unstaged duration, and
				## playback draws the short leg at the long leg's pace.
				hitter_start = prepared_actor.position
				hitter_move_time = _movement_time(
					hitter, hitter_start, set_target, "transition",
					Vector2(approach_preparation.get(
						"approach_start_position",
						_approach_start_position(set_target, hitter_start, false)
					)),
				)
				hitter_arrival_margin = float(set_flight_time) - hitter_move_time
				resolved_approach = ApproachMechanicsModel.evaluate_takeoff(
					prepared_actor, set_target, set_flight_time
				)
	## Same staging leg as the setter's: the hitter should already be at
	## hitter_start (their staged approach mark) by the time this set's flight
	## finishes, not shown getting there and running the approach in one motion.
	var set_event_for_staging := result.events[-1] as RallyEvent
	if set_event_for_staging != null:
		set_event_for_staging.metadata["staged_next_actor_id"] = hitter.id
		set_event_for_staging.metadata["staged_next_position"] = hitter_start
	var approach_fit := _approach_execution_fit(hitter, resolved_approach)
	## The block this swing is actually hit into. Attack quality had no opposing
	## term at all: it summed roughly 1.5 of positive coefficients against
	## penalties that rarely reached 0.2, so it never fell below 0.310 against an
	## error threshold of 0.29 and the engine produced no attack errors. Hitting
	## into a sealed block is the risk that was missing, and the block's
	## formation is knowable before the contest is settled.
	var opponent_block_formation := _form_opponent_block(
		opponent_team, set_target.x, assignment.tempo,
		float(result.set_quality), set_contact.x, set_flight_time,
	)
	## Scouting sharpens a block that has already formed, so it belongs to the
	## formation. It used to be applied *after* the contest, with its own stuff
	## margin, its own close threshold and its own recycle rule -- a second copy
	## of the contest, on one side of the net only. Folding it into the
	## formation's quality leaves exactly one place a block outcome is decided.
	var block_adaptation := _opponent_block_adaptation_bonus(
		opponent_team, assignment.lane, assignment.tempo
	)
	if block_adaptation > 0.0:
		opponent_block_formation["quality"] = clampf(
			float(opponent_block_formation.get("quality", 0.0)) + block_adaptation,
			0.05, 0.98,
		)
	opponent_block_formation["adaptation_bonus"] = block_adaptation
	var block_pressure := float(opponent_block_formation.get("primary_close", 0.0)) \
		* BLOCK_PRIMARY_PRESSURE \
		+ float(opponent_block_formation.get("assist_close", 0.0)) \
		* BLOCK_ASSIST_PRESSURE
	result.attack_quality = clampf(
		_attack_execution(
			hitter, float(result.set_quality), approach_fit, hitter_arrival_margin,
			tempo_demand, block_pressure,
			Familiarity.attack_geometry(hitter, assignment.lane)
			+ (Familiarity.execution_modifier(hitter) - 1.0) * 0.14,
		) + rng.randf_range(-ATTACK_EXECUTION_NOISE, ATTACK_EXECUTION_NOISE),
		0.0, 1.0,
	)
	var hit_type := _hit_type(assignment, hitter)
	var available_attacks := ApproachMechanicsModel.available_attack_families(
		hitter, resolved_approach, hitter_arrival_margin
	)
	## Capability is not permission at the third contact either.
	##
	## This used to silently rewrite a power swing into a roll shot whenever the
	## run-up had not unlocked power, so a hitter could never attempt more than
	## the approach gave them -- and because the substitute was always
	## executable, no swing in the game was ever bad enough to be an error. Now
	## the hitter's own judgment decides whether to take the safer ball, and
	## swinging anyway costs quality in proportion to how far outside their
	## approach the swing sits.
	var swing_deficit := ApproachMechanicsModel.attack_family_deficit(
		hitter, resolved_approach, hitter_arrival_margin,
		ApproachMechanicsModel.attack_family_for_hit_type(hit_type),
	)
	var swing_downgraded := AttemptJudgmentModel.backs_off(hitter, swing_deficit)
	if swing_downgraded:
		hit_type = "Controlled roll" if "controlled_roll" in available_attacks \
			else "Emergency tip"
		swing_deficit = ApproachMechanicsModel.attack_family_deficit(
			hitter, resolved_approach, hitter_arrival_margin,
			ApproachMechanicsModel.attack_family_for_hit_type(hit_type),
		)
	if swing_deficit > 0.0:
		result.attack_quality = clampf(
			float(result.attack_quality) - swing_deficit * ATTACK_OVERREACH_SEVERITY,
			0.0, 1.0,
		)
	var attack_choice := _choose_home_attack_target(
		hitter, assignment.lane, hit_type, opponent_team
	)
	if using_live_attack:
		result.attack_quality = clampf(float(selected_live_attack.get(
			"quality", result.attack_quality
		)), 0.0, 1.0)
		hit_type = str(selected_live_attack.get(
			"selected_action", hit_type
		)).replace("_", " ").capitalize()
		attack_choice = {
			"target": Vector2(selected_live_attack.get(
				"target", attack_choice.target
			)),
			"direction": str(selected_live_attack.get(
				"direction", attack_choice.direction
			)),
			"reason": str(selected_live_attack.get(
				"target_reason", "largest perceived gap"
			)),
		}
	var attack_target: Vector2 = attack_choice.target
	var approach_start := Vector2(approach_preparation.get(
		"approach_start_position",
		_approach_start_position(set_target, hitter_start, false)
	))
	var attack_angle := _attack_launch_angle_degrees(
		hitter, hit_type, float(result.attack_quality)
	)
	var attack_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_target, attack_target), attack_angle
	)
	var attack_flight := float(attack_arc.duration_seconds)
	var attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, attack_flight,
		float(attack_arc.apex_height_meters),
		rally_clock + set_flight_time
	)
	if using_live_attack:
		attack_trajectory = Dictionary(selected_live_attack.get(
			"attack_trajectory", attack_trajectory
		)).duplicate(true)
		attack_flight = float(attack_trajectory.get(
			"duration", attack_flight
		))
		live_attack_integration = LiveAttackIntegratorModel.apply(
			live_state, selected_live_attack
		)
		if not bool(live_attack_integration.get("applied", false)):
			using_live_attack = false
		else:
			shadow_summary["live_attack_integration"] = \
				live_attack_integration.duplicate(true)
			shadow_reception_trace.summary = shadow_summary
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, result.attack_quality >= 0.25,
		result.attack_quality, "%s: %s" % [hitter.display_name, hit_type],
		("%s from %s at T%d · %d%% contact quality." % [
			hit_type, assignment.lane, assignment.tempo,
			roundi(float(result.attack_quality) * 100.0),
		]) + (" Arrived %.2fs before the ball." % hitter_arrival_margin
			if hitter_arrival_margin >= 0.0 else
			" Arrived %.2fs late and lost the approach window." % absf(hitter_arrival_margin)),
		{"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			"attack_type": hit_type, "attack_direction": attack_choice.direction,
			"target_reason": attack_choice.reason, "movement_start": hitter_start,
			"approach_start_position": approach_start,
			"approach_target_position": Vector2(approach_preparation.get(
				"approach_target_position", approach_start
			)),
			"reached_approach_mark": bool(approach_preparation.get(
				"reached_approach_start", true
			)),
			"transition_preparation": approach_preparation.duplicate(true),
			"resolved_approach": resolved_approach.duplicate(true),
			"available_attack_actions": available_attacks.duplicate(),
			"approach_speed_mps": float(resolved_approach.get("approach_speed_mps", 0.0)),
			"approach_quality": float(resolved_approach.get("runup_quality", 0.0)),
			"approach_distance_meters": float(resolved_approach.get(
				"approach_distance_meters", 0.0
			)),
			"approach_in_system": bool(resolved_approach.get("approach_in_system", false)),
			"jump_multiplier": float(resolved_approach.get("jump_multiplier", 1.0)),
			"lateral_control": float(resolved_approach.get("lateral_control", 0.0)),
			"movement_duration": hitter_move_time,
			"arrival_margin": hitter_arrival_margin,
			"deadline": rally_clock + float(set_flight_time),
			"event_time": rally_clock + float(set_flight_time),
			"set_flight_time": float(set_flight_time),
			"incoming_trajectory": set_trajectory,
			"outgoing_trajectory": attack_trajectory})
	var live_attack_event := result.events[-1] as RallyEvent
	if using_live_attack and live_attack_event != null:
		live_attack_event.metadata["continuous_attack"] = true
		live_attack_event.metadata["observation_targeting"] = true
		live_attack_event.metadata["persistent_state_update"] = \
			live_attack_integration.duplicate(true)
	live_positions[hitter.id] = Vector2(live_attack_integration.get(
		"hitter_center_position", set_target
	)) if using_live_attack else set_target
	rally_clock += float(set_flight_time)
	if result.attack_quality < ATTACK_ERROR_THRESHOLD:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})

	## Gates 48 and 49: the guarded block selection boundary, evaluated at the
	## point of use so the promotion chain is definitively known. A block only
	## makes sense against the attack the blockers actually read, so promotion
	## requires the Gate 42 attack to have been promoted first -- otherwise the
	## shadow block closed on a lane the official ball never went to.
	var block_rollout_requested := using_live_attack \
		and development_continuous_reception and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_BLOCK_OVERRIDE
	var block_rollout := RallyRolloutPolicyModel.select_block_source(
		shadow_summary, opponent_team.current_lineup(), block_rollout_requested
	)
	var selected_live_block: Dictionary = block_rollout.get("selected_block", {})
	var using_live_block := not selected_live_block.is_empty() \
		and str(block_rollout.get("selected_source", "official")) == "continuous_block"
	if using_live_block and not bool(LiveBlockIntegratorModel.validate(
		live_state, selected_live_block
	).get("valid", false)):
		block_rollout = RallyRolloutPolicyModel.select_block_source(
			shadow_summary, opponent_team.current_lineup(), false
		)
		selected_live_block = {}
		using_live_block = false
	var block_rollout_evidence := block_rollout.duplicate(true)
	block_rollout_evidence.erase("selected_block")
	shadow_summary["block_rollout"] = block_rollout_evidence
	shadow_reception_trace.summary = shadow_summary

	# Resolve the block from the opponent's actual front-row geometry. A
	# roster-wide best blocker must not cover every pin regardless of distance.
	var block_resolution := _contest_block(
		opponent_block_formation, float(result.attack_quality)
	)

	var live_block_integration: Dictionary = {}
	if using_live_block:
		live_block_integration = LiveBlockIntegratorModel.apply(
			live_state, selected_live_block
		)
		if not bool(live_block_integration.get("applied", false)):
			using_live_block = false
			block_rollout_evidence["selected_source"] = "official"
			block_rollout_evidence["fallback_reason"] = str(
				live_block_integration.get("reason", "block integration failed")
			)
			shadow_summary["block_rollout"] = block_rollout_evidence
			shadow_reception_trace.summary = shadow_summary
		else:
			## The promoted contact replaces who blocked and what happened, but
			## not the coverage geometry the legacy resolver derived; that is
			## still the official continuation, exactly as Gate 42 left blocking
			## on the legacy path after promoting the attack.
			var promoted_primary := opponent_team.player_by_id(
				int(live_block_integration.get("primary_id", -1))
			) as VolleyballPlayer
			var promoted_assist := opponent_team.player_by_id(
				int(live_block_integration.get("assist_id", -1))
			) as VolleyballPlayer
			if promoted_primary != null:
				block_resolution["primary"] = promoted_primary
				block_resolution["assist"] = promoted_assist
				block_resolution["outcome"] = str(
					live_block_integration.get("outcome", "recycle")
				)
			shadow_summary["live_block_integration"] = \
				live_block_integration.duplicate(true)
			shadow_reception_trace.summary = shadow_summary
	var opponent_blocker := block_resolution.primary as VolleyballPlayer
	var assisting_blocker := block_resolution.assist as VolleyballPlayer
	var primary_close := float(block_resolution.primary_close)
	var assist_close := float(block_resolution.assist_close)
	var block_strength := float(block_resolution.quality)
	## Already folded into the formation's quality before the contest ran; read
	## back here only to explain the rally.
	var adaptation_bonus := float(block_resolution.get("adaptation_bonus", 0.0))
	if adaptation_bonus >= 0.035:
		result.key_factors.append(ExplanationText.factor("opponent_adapted"))
	## The contest is the whole answer. A flat 18-48% "beaten block still gets a
	## hand on it" roll used to run on top of it, on this side of the net only.
	## It duplicated the contest's own `funnel` band, and because it was written
	## against a `primary_close` that was 99.5% saturated it fired at close to
	## its ceiling on almost every swing -- two thirds of all attacks recycled
	## into a continuation and rallies never ended.
	var block_outcome := str(block_resolution.outcome)
	var blocked := block_outcome == "stuff"
	# A positional partial block is the same continuation class as the older
	# "recycle" result: the home attack-coverage unit must play the deflection.
	var recycled := block_outcome in ["recycle", "touch", "funnel"]
	var recycle_target := _attack_coverage_target(set_target, block_strength) \
		if recycled else Vector2(set_target.x, 0.50)
	var net_contact := Vector2(set_target.x, 0.50)
	var attack_event: Resource = result.events[-1]
	## A block that never touches the ball must not shorten the shot.
	##
	## This truncation used to be unconditional, so every attack resolved
	## against a block ended at the net -- about three percent of the court from
	## where it started. The spike was drawn barely moving, and the rest of the
	## distance arrived as the block's "deflection", which read as the ball
	## teleporting onto whoever dug it. Re-slicing is correct only when the
	## block actually intercepts; otherwise the shot keeps its full arc and
	## chains straight into the defence.
	var block_contacts_ball := blocked or recycled
	if block_contacts_ball:
		## Same shot as attack_trajectory above, re-sliced to where it actually
		## crosses the net rather than where it was originally headed -- same
		## launch angle, shorter distance, so duration/apex still fall out of
		## the geometry instead of being a separate hardcoded segment.
		var attack_to_block_arc := RallyKinematics.solve_launch_arc(
			RallyKinematics.court_distance_meters(set_target, net_contact), attack_angle
		)
		attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", set_target, net_contact,
			float(attack_to_block_arc.duration_seconds),
			float(attack_to_block_arc.apex_height_meters),
			float(attack_event.metadata.get("event_time", rally_clock))
		)
	var post_block_target := recycle_target if recycled else attack_target
	if blocked:
		post_block_target = Vector2(set_target.x, 0.57)
	## An untouched ball carries no deflection segment: the attack's own flight
	## already reaches the floor, and emitting a second overlapping path is what
	## made the ball appear twice in two places.
	var opponent_block_trajectory := _ball_trajectory(
		"block_deflection", net_contact, post_block_target,
		0.24 if recycled else 0.18, 0.35, rally_clock
	) if block_contacts_ball else {}
	var opponent_block_segments: Array[Dictionary] = block_resolution.coverage_segments
	var opponent_blocker_id := opponent_blocker.id if opponent_blocker != null else -1
	var opponent_blocker_name := opponent_blocker.display_name \
		if opponent_blocker != null else "Open block"
	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker_id,
		opponent_blocker_name,
		Vector2(set_target.x, 0.47), post_block_target, block_outcome != "miss",
		block_strength, "Block forms at %s" % assignment.lane,
		"%d%% close speed; the blockers seal the chosen lane.%s" % [
			roundi(block_strength * 100.0),
			" Scouting anticipated this pattern." if adaptation_bonus >= 0.035 else "",
		], {"side": "opponent", "lane": assignment.lane,
			"adaptation_bonus": adaptation_bonus, "outcome": block_outcome,
			"continuous_block": using_live_block,
			"deflection_target": post_block_target,
			"coverage_segments": opponent_block_segments,
			"primary_close": primary_close,
			"assist_close": assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			"primary_position": _block_wall_positions(
				set_target.x, true
			).primary_position,
			"assist_position": _block_wall_positions(
				set_target.x, true
			).assist_position,
			"setter_pull": block_resolution.setter_pull,
			"read_quality": block_resolution.read_quality,
			"event_time": rally_clock,
			"incoming_trajectory": attack_event.metadata.outgoing_trajectory,
			"outgoing_trajectory": opponent_block_trajectory})
	if blocked:
		result.key_factors.append(ExplanationText.factor("strong_block"))
		return _finish(result, "blocked", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	if recycled:
		var coverage_result := _resolve_attack_coverage(
			players, lineup, defensive_plan, hitter, recycle_target, block_strength
		)
		var coverer := coverage_result.get("player") as VolleyballPlayer
		var coverage_success := bool(coverage_result.get("success", false))
		var coverage_quality := float(coverage_result.get("quality", 0.0))
		var coverer_start: Vector2 = live_positions.get(
			coverer.id, recycle_target
		) if coverer != null else recycle_target
		var coverer_move_time := _movement_time(
			coverer, coverer_start, recycle_target, "lateral"
		) if coverer != null else 4.0
		if coverer != null:
			live_positions[coverer.id] = recycle_target
		var coverage_pass_target := recycle_target + Vector2(0.04, -0.05)
		_add_event(result, RallyEventModel.EventType.DEFENSE,
			coverer.id if coverer != null else -1,
			coverer.display_name if coverer != null else "Attack coverage",
			recycle_target, coverage_pass_target,
			coverage_success, coverage_quality,
			"%s covers the block touch" % (
				coverer.display_name if coverer != null else "Nobody"
			),
			"%d%% recycle control from the assigned attack-coverage shape." % roundi(
				coverage_quality * 100.0
			), {"side": "home", "coverage": "attack",
				"blocked_hitter_id": hitter.id,
				"movement_start": coverer_start,
				"movement_duration": coverer_move_time})
		if not coverage_success:
			return _finish(result, "blocked", false, hitter.id, {
				"hitter": hitter.display_name,
			})
		result.key_factors.append(ExplanationText.factor("attack_recycled"))
		return _resolve_home_continuation(
			result, players, lineup, coverer, coverage_pass_target,
			opponent_team, defensive_plan, 1,
		)

	var opponent_defense := _choose_opponent_defender(
		opponent_team, attack_target, attack_flight
	)
	var opponent_defender := opponent_defense.player as VolleyballPlayer
	var read_tags: Array[String] = ["hand:%s" % hitter.dominant_hand.to_lower(),
		"attack:%s" % str(attack_choice.direction).to_lower().replace("-", "_")]
	var read_modifier := Familiarity.read_modifier(
		opponent_defender, read_tags, float(opponent_team.scouting_confidence)
	)
	var floor_defense_bonus := _opponent_floor_defense_adaptation_bonus(
		opponent_team, assignment.lane
	)
	var defense_strength := clampf(
		_rating(opponent_defender, "reception") * 0.46
		+ _rating(opponent_defender, "anticipation") * 0.38
		+ clampf(float(opponent_defense.arrival_margin) * 0.08, -0.18, 0.10)
		+ read_modifier + floor_defense_bonus + rng.randf_range(-0.16, 0.16), 0.1, 0.9
	)
	Familiarity.record_exposure(opponent_defender, read_tags)
	var dug: bool = defense_strength > float(result.attack_quality) \
		+ rng.randf_range(-0.20, 0.12)
	var opponent_pass_target := attack_target + Vector2(0.04, -0.03)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id,
		opponent_defender.display_name,
		attack_target, opponent_pass_target, dug,
		defense_strength, "Defensive contact",
		"%s %s the %s attack after moving %.1fm.%s" % [
			opponent_defender.display_name, "controls" if dug else "cannot reach",
			str(attack_choice.direction), float(opponent_defense.distance_meters),
			" Scouting anticipated this lane." if floor_defense_bonus >= 0.035 else "",
		], {"side": "opponent", "movement_start": opponent_defense.start,
			"movement_duration": opponent_defense.travel_time,
			"arrival_margin": opponent_defense.arrival_margin,
			"attack_direction": attack_choice.direction,
			"adaptation_bonus": floor_defense_bonus})
	opponent_live_positions[opponent_defender.id] = attack_target
	if dug:
		result.key_factors.append(ExplanationText.factor("strong_defense"))
		return _resolve_opponent_transition(
			result, players, lineup, hitter, opponent_pass_target,
			opponent_team, defensive_plan, 1,
		)
	result.key_factors.append(ExplanationText.factor("attack_control"))
	var kill_key := "kill_default" if active_play == null else (
		"kill_called" if result.play_was_followed else "kill_improvised"
	)
	return _finish(result, "kill", true, hitter.id, {
		"setter": setter.display_name,
		"hitter": hitter.display_name,
		"play": result.active_play_name,
	}, kill_key)


func _resolve_home_serve(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
) -> Resource:
	var server := _best_home_server(players, lineup)
	var serve_risk := 0.5
	if defensive_plan != null:
		serve_risk = float(defensive_plan.serve_risk)
	var serve_quality := clampf(
		_power_rating(server, "serve_power") * 0.25
		+ _rating(server, "serve_technique") * 0.20
		+ _rating(server, "serve_placement") * 0.13
		+ _rating(server, "serve_consistency") * 0.14
		+ _serve_style_proficiency(server) * 0.13
		+ serve_risk * 0.15 + rng.randf_range(-0.14, 0.14), 0.05, 0.98
	)
	var error_chance := clampf(
		0.025 + serve_risk * 0.07 + _rating(server, "serve_aggression") * 0.025 \
		- _rating(server, "serve_consistency") * 0.065 \
		- _serve_style_proficiency(server) * 0.02,
		0.01, 0.14,
	)
	var serve_error := rng.randf() < error_chance
	var target_name := str(
		defensive_plan.serve_target if defensive_plan != null else "Zone 5"
	)
	var opponent_landing := _serve_landing_point(
		target_name, server, [], null, false
	)
	var serve_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(Vector2(0.82, 0.92), opponent_landing),
		_serve_launch_angle_degrees(server, serve_quality),
	)
	var serve_time := float(serve_arc.duration_seconds)
	_add_event(result, RallyEventModel.EventType.SERVE, server.id, server.display_name,
		Vector2(0.82, 0.92), opponent_landing, not serve_error,
		serve_quality, "%s serves" % server.display_name,
		"%s · %d%% pressure at %d%% selected risk." % [server.primary_serve_style,
			roundi(serve_quality * 100.0), roundi(serve_risk * 100.0),
		], {"side": "home", "target": target_name, "flight_time": serve_time,
			"server_id": server.id, "server_slot": 1,
			"serve_style": server.primary_serve_style,
			"outgoing_trajectory": _ball_trajectory(
				"serve", Vector2(0.82, 0.92), opponent_landing, serve_time,
				float(serve_arc.apex_height_meters),
			)})
	if serve_error:
		return _finish(result, "serve_error", false, server.id, {
			"server": server.display_name,
		})
	var opponent_coverage := _opponent_reception_coverage(opponent_team)
	var opponent_claim: Dictionary = CoverageModel.choose_claimant(
		opponent_coverage.players, opponent_coverage.zones,
		opponent_landing, serve_time, "reception",
	)
	var receiver := opponent_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = opponent_team.best_defender() as VolleyballPlayer
	var opponent_arrival: Dictionary = opponent_claim.get("arrival", {})
	var receiver_zone: Resource = opponent_coverage.zones.get(receiver.id) as Resource
	var receiver_start: Vector2 = opponent_live_positions.get(
		receiver.id,
		Vector2(receiver_zone.center) if receiver_zone != null \
		else opponent_team.court_position(receiver.id, "serve_receive"),
	)
	var receiver_move_time := _movement_time(
		receiver, receiver_start, opponent_landing, "lateral"
	)
	var support_count := int(opponent_claim.get("support_count", 0))
	var serve_receive_bonus := _opponent_serve_receive_adaptation_bonus(
		opponent_team, target_name
	)
	var reception_quality := clampf(
		_rating(receiver, "reception") * 0.58
		+ _rating(receiver, "ball_control") * 0.24
		- serve_quality * 0.44
		- CoverageModel.reception_body_penalty(receiver, opponent_arrival, serve_quality)
		+ clampf(float(opponent_arrival.get("arrival_margin", -1.0)) * 0.07, -0.16, 0.12)
		+ minf(float(support_count) * 0.025, 0.075)
		+ serve_receive_bonus + rng.randf_range(-0.12, 0.12),
		0.0, 1.0,
	)
	if not receiver_arrived:
		reception_quality = minf(reception_quality, 0.12)
	result.reception_quality = reception_quality
	var reception_success := receiver_arrived and reception_quality >= 0.18
	opponent_live_positions[receiver.id] = opponent_landing
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		opponent_landing, _opponent_setter_release_target(opponent_team),
		reception_success,
		reception_quality, "%s receives" % receiver.display_name,
		"Opponent reception quality: %d%%. %s%s" % [
			roundi(reception_quality * 100.0),
			_arrival_phrase(opponent_arrival, receiver_arrived, support_count),
			" Scouting anticipated this target." if serve_receive_bonus >= 0.035 else "",
		], {"side": "opponent", "landing": opponent_landing,
			"flight_time": serve_time, "arrival": opponent_arrival,
			"support_count": support_count, "adaptation_bonus": serve_receive_bonus,
			"movement_start": receiver_start,
			"movement_target": opponent_landing if receiver_arrived else receiver_start,
			"movement_duration": receiver_move_time})
	if not reception_success:
		return _finish(result, "ace", true, server.id, {"server": server.display_name})
	## The opponent setter releases to the same place a home setter would,
	## mirrored. This used to be the hardcoded court centre (0.50, 0.34), which
	## put the setter directly on top of whoever was covering the middle -- the
	## setter marker visibly vanished inside another opponent's during serve
	## receive -- and had them setting from a position no setter takes.
	var opponent_setter_release := _opponent_setter_release_target(opponent_team)
	return _resolve_opponent_transition(
		result, players, lineup, server, opponent_setter_release,
		opponent_team, defensive_plan, 1,
	)


func _resolve_opponent_transition(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	original_hitter: VolleyballPlayer,
	dig_position: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
) -> Resource:
	var opponent_setter := opponent_team.setter() as VolleyballPlayer
	var transition_penalty := float(exchange_number - 1) * 0.035
	## The pass destination is the setter's physical contact point. Keeping a
	## separate display-only setter coordinate made the ball originate away from
	## the marker and introduced a visible snap at every opponent set.
	var opponent_setter_position := dig_position
	var setter_start: Vector2 = opponent_live_positions.get(
		opponent_setter.id, opponent_team.court_position(opponent_setter.id, "transition")
	)
	var setter_move_time := _movement_time(
		opponent_setter, setter_start, opponent_setter_position, "lateral"
	)
	var set_geometry := _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		Vector2(0.50, 0.48), Vector2(0.50, 0.48)
	)
	var opponent_set_quality := clampf(
		_rating(opponent_setter, "set_accuracy") * 0.48
		+ _rating(opponent_setter, "court_vision") * 0.22
		+ _rating(opponent_setter, "decision_making") * 0.16
		+ 0.18 - float(set_geometry.difficulty) - transition_penalty
		+ rng.randf_range(-0.12, 0.12), 0.08, 0.94,
	)
	var opponent_tempo := int(opponent_team.tendencies.get("tempo", 2))
	## _choose_opponent_attack needs a flight-time estimate before the real set
	## target is known. Estimate it against the same placeholder target
	## set_geometry's first pass already uses above; the real distance-based
	## value is recomputed below once opponent_contact is final, mirroring how
	## opponent_set_quality is already computed twice in this function.
	var estimated_set_flight_time: float = float(RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(
			opponent_setter_position, Vector2(0.50, 0.48)
		),
		_set_launch_angle_degrees(opponent_setter, opponent_tempo, opponent_set_quality),
	).duration_seconds)
	var attack_choice := _choose_opponent_attack(
		opponent_team, opponent_setter, opponent_set_quality,
		_home_target_hint(defensive_plan), estimated_set_flight_time,
	)
	var opponent_hitter := attack_choice.player as VolleyballPlayer
	var opponent_contact: Vector2 = attack_choice.contact
	var home_target: Vector2 = attack_choice.target
	set_geometry = _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		opponent_contact, Vector2(0.50, 0.48)
	)
	opponent_set_quality = clampf(
		_rating(opponent_setter, "set_accuracy") * 0.48
		+ _rating(opponent_setter, "court_vision") * 0.22
		+ _rating(opponent_setter, "decision_making") * 0.16
		+ 0.18 - float(set_geometry.difficulty) - transition_penalty
		+ rng.randf_range(-0.12, 0.12), 0.08, 0.94,
	)
	var set_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_setter_position, opponent_contact),
		_set_launch_angle_degrees(opponent_setter, opponent_tempo, opponent_set_quality),
	)
	var set_flight_time: float = float(set_arc.duration_seconds)
	_add_event(result, RallyEventModel.EventType.SET, opponent_setter.id,
		opponent_setter.display_name,
		dig_position, opponent_contact, true, opponent_set_quality,
		"Opponent transition set · exchange %d" % exchange_number,
		"Contact 2 of 3 · %d%% set quality." % roundi(opponent_set_quality * 100.0),
		{"side": "opponent", "setter_position": opponent_setter_position,
			"movement_start": setter_start, "movement_duration": setter_move_time,
			"set_distance_meters": set_geometry.distance_meters,
			"set_angle_degrees": set_geometry.angle_degrees,
			"body_orientation_fit": set_geometry.body_orientation_fit,
			"outgoing_trajectory": _ball_trajectory(
				"opponent_set", opponent_setter_position, opponent_contact,
				set_flight_time, float(set_arc.apex_height_meters),
				rally_clock
			)})
	opponent_live_positions[opponent_setter.id] = opponent_setter_position
	## Provisional: recomputed below once preparation has staged the hitter.
	var hitter_arrival_margin: float = set_flight_time - float(attack_choice.travel_time)
	## The wall this swing is hit into, formed before it is scored -- the same
	## order the home attack uses. The opponent swing used to be
	## `attack_power * 0.62 + set_quality * 0.20 + 0.08`: a third execution scale,
	## with no approach term and no opposing block, compared against the same
	## contest and the same error threshold as the home side's.
	var home_block_formation := _form_home_block(
		players, lineup, defensive_plan, opponent_contact.x,
		opponent_tempo, opponent_set_quality,
		opponent_setter_position.x, set_flight_time,
	)
	var home_block_pressure := float(
		home_block_formation.get("primary_close", 0.0)
	) * BLOCK_PRIMARY_PRESSURE + float(
		home_block_formation.get("assist_close", 0.0)
	) * BLOCK_ASSIST_PRESSURE
	var opponent_attack_noise := rng.randf_range(
		-ATTACK_EXECUTION_NOISE, ATTACK_EXECUTION_NOISE
	)
	## Provisional: the run-up has not been evaluated yet, so this scores the
	## swing as if the approach were merely adequate. Recomputed below once the
	## real approach exists.
	var opponent_attack := clampf(
		_attack_execution(
			opponent_hitter, opponent_set_quality, 0.5, hitter_arrival_margin,
			0.0, home_block_pressure,
		) + opponent_attack_noise,
		0.0, 1.0,
	)
	## Gate 43, mirrored. The opponent hitter now has a causal approach instead
	## of a purely geometric mark: responsibility sets their release time, and
	## the resulting run-up changes approach speed, lateral control, usable jump,
	## and which attack families are physically available. Two things depended on
	## this being absent -- the shadow block was reading a hitter-approach cue
	## with nothing behind it, and 2D playback had no staged approach to draw,
	## which is why opponent spikes were unreadable.
	var opponent_state := RallyStateBuilderModel.build(
		players, lineup, defensive_plan, opponent_team, null, true,
		rng.seed + exchange_number * 2411,
	)
	opponent_state.simulation_time = maxf(rally_clock - 0.55, 0.0)
	var opponent_hitter_actor := opponent_state.player_state(
		&"opponent", opponent_hitter.id
	)
	if opponent_hitter_actor != null:
		opponent_hitter_actor.apply_position(
			Vector2(attack_choice.start), opponent_hitter_actor.velocity
		)
	var opponent_preparation := ApproachMechanicsModel.prepare_for_attack(
		opponent_state, opponent_hitter_actor,
		{
			"player_id": opponent_hitter.id,
			"lane": str(attack_choice.get("lane", "Left Pin")),
			"tempo": opponent_tempo,
			"target": opponent_contact,
		},
		opponent_setter.id, rally_clock + set_flight_time, &"opponent",
	)
	var opponent_prepared := opponent_preparation.get("actor") as RallyPlayerState
	opponent_preparation.erase("actor")
	var opponent_approach_start := _approach_start_position(
		opponent_contact, Vector2(attack_choice.start), true
	)
	if opponent_prepared != null:
		opponent_approach_start = opponent_prepared.position
	## Recompute over the route the hitter actually runs. `attack_choice` timed
	## the trip from where the hitter stood before preparation relocated them to
	## their approach mark, so reporting the staged start with the unstaged
	## duration describes them covering a short leg at a long leg's pace. This is
	## the same defect the movement-fluidity work fixed on the home side, and it
	## only surfaced here once block pressure made continuations common enough to
	## shift the ATTACK phase's timing ratio to 1.083.
	var opponent_move_time := _movement_time(
		opponent_hitter, opponent_approach_start, opponent_contact, "transition"
	)
	hitter_arrival_margin = set_flight_time - opponent_move_time
	var opponent_approach := ApproachMechanicsModel.evaluate_takeoff(
		opponent_prepared, opponent_contact, set_flight_time
	) if opponent_prepared != null else {}
	var opponent_attack_actions: Array[String] = \
		ApproachMechanicsModel.available_attack_families(
			opponent_hitter, opponent_approach, hitter_arrival_margin
		) if not opponent_approach.is_empty() else ([] as Array[String])
	## A run-up that never happened cannot lend its quality to the swing. This
	## is the same coupling Gate 43 gave the home side, and it now feeds the
	## same execution model rather than a bolt-on adjustment.
	if not opponent_approach.is_empty():
		opponent_attack = clampf(
			_attack_execution(
				opponent_hitter, opponent_set_quality,
				_approach_execution_fit(opponent_hitter, opponent_approach),
				hitter_arrival_margin, 0.0, home_block_pressure,
				(float(opponent_approach.get("jump_multiplier", 1.0)) - 1.0) * 0.18,
			) + opponent_attack_noise,
			0.0, 1.0,
		)
	## Let playback walk the hitter to their approach mark during the set,
	## instead of teleporting them into a swing when the attack event begins.
	var opponent_set_event := result.events[-1] as RallyEvent
	if opponent_set_event != null:
		opponent_set_event.metadata["staged_next_actor_id"] = opponent_hitter.id
		opponent_set_event.metadata["staged_next_position"] = opponent_approach_start

	## The swing's shape is solved only now, so the run-up that just adjusted
	## `opponent_attack` also shapes the arc it produces.
	var opponent_net_contact := Vector2(opponent_contact.x, 0.50)
	var opponent_attack_angle := _attack_launch_angle_degrees(
		opponent_hitter, str(attack_choice.attack_type), opponent_attack
	)
	## The full shot, to where it is actually aimed. `_contest_block()`
	## re-slices this to the net if the block touches it; truncating here
	## unconditionally made every opponent spike travel about three percent of
	## the court and the rest arrive as a "deflection".
	var opponent_attack_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_contact, home_target),
		opponent_attack_angle,
	)
	var opponent_attack_trajectory := _ball_trajectory(
		"attack", opponent_contact, home_target,
		float(opponent_attack_arc.duration_seconds),
		float(opponent_attack_arc.apex_height_meters),
		rally_clock + set_flight_time
	)
	_add_event(result, RallyEventModel.EventType.ATTACK, opponent_hitter.id,
		opponent_hitter.display_name,
		opponent_contact, home_target, true, opponent_attack,
		"Opponent transition swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %s toward %s at %d%% quality." % [
			str(attack_choice.attack_type), str(attack_choice.direction),
			roundi(opponent_attack * 100.0),
		],
		{"side": "opponent", "lane_x": opponent_contact.x,
			"attack_type": attack_choice.attack_type,
			"attack_direction": attack_choice.direction,
			"hitter_start": attack_choice.start,
			"hitter_travel_time": attack_choice.travel_time,
			"arrival_margin": hitter_arrival_margin,
			"movement_start": opponent_approach_start,
			"approach_start_position": opponent_approach_start,
			"approach_target_position": Vector2(opponent_preparation.get(
				"approach_target_position", opponent_approach_start
			)),
			"reached_approach_start": bool(opponent_preparation.get(
				"reached_approach_start", true
			)),
			"transition_preparation": opponent_preparation.duplicate(true),
			"resolved_approach": opponent_approach.duplicate(true),
			"available_attack_actions": opponent_attack_actions.duplicate(),
			"approach_speed_mps": float(opponent_approach.get("approach_speed_mps", 0.0)),
			"approach_quality": float(opponent_approach.get("runup_quality", 0.0)),
			"approach_distance_meters": float(opponent_approach.get(
				"approach_distance_meters", 0.0
			)),
			"approach_in_system": bool(opponent_approach.get("approach_in_system", false)),
			"jump_multiplier": float(opponent_approach.get("jump_multiplier", 1.0)),
			"lateral_control": float(opponent_approach.get("lateral_control", 0.0)),
			"event_time": rally_clock + set_flight_time,
			"launch_angle_degrees": opponent_attack_angle,
			"movement_duration": opponent_move_time,
			"outgoing_trajectory": opponent_attack_trajectory})
	var opponent_attack_event := result.events[-1] as RallyEvent
	opponent_live_positions[opponent_hitter.id] = opponent_contact
	var block_result := _contest_block(home_block_formation, opponent_attack)
	var blocker := block_result.primary as VolleyballPlayer
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var home_block := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	if blocker != null:
		live_positions[blocker.id] = Vector2(opponent_contact.x, 0.54)
	if assisting_blocker != null:
		live_positions[assisting_blocker.id] = Vector2(opponent_contact.x, 0.54)
	var deflection_target := home_target
	if block_outcome in ["touch", "funnel"]:
		deflection_target = _home_block_deflection_target(
			home_target, opponent_contact.x, home_block, block_outcome,
			str(defensive_plan.block_defense_relationship) if defensive_plan != null else "Balanced"
		)
	var home_block_target := Vector2(opponent_contact.x, 0.43) \
		if block_outcome == "stuff" else deflection_target
	## Same contract as the two home-attack block paths: only a block that
	## actually touches the ball shortens the shot or deflects it.
	var home_block_contacts := block_outcome != "miss"
	if home_block_contacts and opponent_attack_event != null:
		var opponent_flight: Dictionary = opponent_attack_event.metadata.get(
			"outgoing_trajectory", {}
		)
		var opponent_angle := float(opponent_attack_event.metadata.get(
			"launch_angle_degrees", 12.0
		))
		var opponent_start: Vector2 = Vector2(opponent_flight.get(
			"start_position", opponent_net_contact
		))
		var to_block_arc := RallyKinematics.solve_launch_arc(
			RallyKinematics.court_distance_meters(
				opponent_start, opponent_net_contact
			), opponent_angle,
		)
		opponent_attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", opponent_start, opponent_net_contact,
			float(to_block_arc.duration_seconds),
			float(to_block_arc.apex_height_meters),
			float(opponent_flight.get("start_time", rally_clock)),
		)
	var home_block_trajectory := _ball_trajectory(
		"block_deflection", opponent_net_contact, home_block_target,
		0.30 if block_outcome == "touch" else 0.22,
		0.42, rally_clock
	) if home_block_contacts else {}
	var assist_text := ""
	if assisting_blocker != null:
		assist_text = " %s assisted at %d%% close." % [
			assisting_blocker.display_name,
			roundi(float(block_result.assist_close) * 100.0),
		]
	var blocker_id := blocker.id if blocker != null else -1
	var assisting_blocker_id := assisting_blocker.id \
		if assisting_blocker != null else -1
	var floor_phase_positions := _home_floor_phase_positions(
		lineup, defensive_plan, opponent_contact.x,
		blocker_id, assisting_blocker_id
	)
	for raw_player_id in floor_phase_positions:
		live_positions[int(raw_player_id)] = Vector2(
			floor_phase_positions[raw_player_id]
		)
	if opponent_attack_event != null:
		opponent_attack_event.metadata["home_phase_targets"] = \
			floor_phase_positions.duplicate(true)
	var blocker_name := blocker.display_name if blocker != null else "No assigned blocker"
	_add_event(result, RallyEventModel.EventType.BLOCK, blocker_id, blocker_name,
		Vector2(opponent_contact.x, 0.53), Vector2(opponent_contact.x, 0.50),
		block_outcome != "miss", home_block,
		"%s · %s" % [blocker_name, block_outcome.capitalize()],
		"Primary close %d%%; block quality %d%%.%s" % [
			roundi(float(block_result.primary_close) * 100.0),
			roundi(home_block * 100.0), assist_text,
		], {"side": "home", "outcome": block_outcome,
			"home_phase_targets": floor_phase_positions.duplicate(true),
			"primary_close": block_result.primary_close,
			"assist_close": block_result.assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			"primary_position": _block_wall_positions(
				opponent_contact.x, false
			).primary_position,
			"assist_position": _block_wall_positions(
				opponent_contact.x, false
			).assist_position,
			"deflection_target": deflection_target,
			"coverage_segments": block_result.coverage_segments,
			"setter_pull": block_result.setter_pull,
			"read_quality": block_result.read_quality,
			"opponent_setter_position": opponent_setter_position,
			"event_time": rally_clock,
			"incoming_trajectory": opponent_attack_trajectory,
			"outgoing_trajectory": home_block_trajectory})
	if block_outcome == "stuff":
		return _finish(result, "counter_block", true, blocker_id, {
			"hitter": original_hitter.display_name,
			"blocker": blocker_name,
		})
	if block_outcome == "touch":
		result.key_factors.append(ExplanationText.factor("block_touch"))
		opponent_attack = maxf(opponent_attack - 0.10 - home_block * 0.05, 0.12)
		home_target = deflection_target
	elif block_outcome == "funnel":
		result.key_factors.append(ExplanationText.factor("block_funnel"))
		opponent_attack = maxf(opponent_attack - 0.035, 0.12)
		home_target = deflection_target
	var attack_type := _opponent_attack_type(home_target)
	var attack_time := float(RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_contact, home_target),
		_attack_launch_angle_degrees(opponent_hitter, attack_type, opponent_attack),
	).duration_seconds)
	if block_outcome == "touch":
		attack_time += 0.24
	elif block_outcome == "funnel":
		attack_time += 0.06
	var defense_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		_zones_at_phase_positions(
			defensive_plan.zones_for(DefensiveZoneModel.ZoneType.FLOOR_DEFENSE),
			floor_phase_positions,
		),
		home_target, attack_time, "reception",
	)
	var defender := defense_claim.get("player") as VolleyballPlayer
	var defender_arrived := defender != null
	if defender == null:
		defender = _nearest_floor_defender(players, lineup, defensive_plan, home_target)
	if defender == null:
		return _finish(result, "long_rally_loss", false, -1, {
			"hitter": original_hitter.display_name,
		})
	var defense_arrival: Dictionary = defense_claim.get("arrival", {})
	var support_count := int(defense_claim.get("support_count", 0))
	var responsibility_fit := _defensive_responsibility_fit(
		defensive_plan, defender.id, home_target, attack_type
	)
	var defense_quality := _rating(defender, "anticipation") * 0.34 \
		+ _rating(defender, "reception") * 0.28 \
		+ _rating(defender, "dig_control") * 0.16 \
		+ _rating(defender, "lateral_speed") * 0.18 \
		+ responsibility_fit \
		+ clampf(float(defense_arrival.get("arrival_margin", -1.0)) * 0.065, -0.16, 0.12) \
		+ minf(float(support_count) * 0.018, 0.054) \
		- CoverageModel.reception_body_penalty(defender, defense_arrival, opponent_attack) \
		+ rng.randf_range(-0.12, 0.12)
	if defensive_plan != null:
		if attack_type == "Short tip" and defensive_plan.short_ball_posture == "Compress Short":
			defense_quality += 0.08
		elif attack_type != "Short tip" and defensive_plan.short_ball_posture == "Compress Short":
			defense_quality -= 0.035
		if defensive_plan.defensive_depth == "Deep":
			defense_quality += -0.055 if attack_type == "Short tip" else 0.035
		elif defensive_plan.defensive_depth == "Shallow":
			defense_quality += 0.045 if attack_type == "Short tip" else -0.035
	if not defender_arrived:
		defense_quality = minf(defense_quality, 0.10)
	var defense_success: bool = defender_arrived \
		and defense_quality > opponent_attack - 0.12
	var defender_start: Vector2 = live_positions.get(
		defender.id, defensive_plan.defender_position(defender.id, home_target)
	)
	var defender_move_time := _movement_time(
		defender, defender_start, home_target, "lateral"
	)
	live_positions[defender.id] = home_target
	var defense_pass_target := home_target + Vector2(0.03, -0.04)
	_add_event(result, RallyEventModel.EventType.DEFENSE, defender.id, defender.display_name,
		home_target, defense_pass_target, defense_success,
		defense_quality, "%s defends" % defender.display_name,
		"%d%% defensive contact against a %d%% attack. %s %s" % [
			roundi(defense_quality * 100.0), roundi(opponent_attack * 100.0),
			_responsibility_phrase(defensive_plan, defender.id, attack_type),
			_arrival_phrase(defense_arrival, defender_arrived, support_count),
		], {"side": "home", "attack_type": attack_type,
			"planner_floor_center": Vector2(floor_phase_positions.get(
				defender.id, defender_start
			)),
			"home_phase_targets": floor_phase_positions.duplicate(true),
			"responsibility_fit": responsibility_fit,
			"flight_time": attack_time, "arrival": defense_arrival,
			"support_count": support_count,
			"movement_start": defender_start,
			"movement_duration": defender_move_time})
	result.key_factors.append(ExplanationText.factor(
		"defense_assignment_fit" if responsibility_fit >= 0.02 \
		else "defense_assignment_stretch"
	))
	if not defense_success:
		return _finish(result, "opponent_kill", false, -1, {
			"hitter": original_hitter.display_name,
		})
	if exchange_number >= MAX_EXCHANGES:
		var safety_win: bool = defense_quality + rng.randf_range(-0.18, 0.18) > 0.60
		return _finish(
			result,
			"long_rally_win" if safety_win else "long_rally_loss",
			safety_win,
			defender.id,
			{"hitter": original_hitter.display_name},
		)
	return _resolve_home_continuation(
		result, players, lineup, defender, defense_pass_target,
		opponent_team, defensive_plan, exchange_number,
	)


func _resolve_home_continuation(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defender: VolleyballPlayer,
	dig_position: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
) -> Resource:
	var setter := _second_contact_setter(
		players, lineup, defensive_plan, defender.id
	)
	# Preserve contact continuity: the transition set begins where the dig
	# actually finishes instead of teleporting the ball to center court.
	var set_contact := dig_position
	var second_contact_window := 0.68
	var setter_choice := _spatial_setter_choice(
		players, lineup, defensive_plan, defender.id, setter,
		set_contact, second_contact_window
	)
	setter = setter_choice.player as VolleyballPlayer
	var setter_start: Vector2 = setter_choice.start
	var setter_move_time := float(setter_choice.travel_time)
	var setter_arrival_margin := second_contact_window - setter_move_time
	var defense_event_for_staging := result.events[-1] as RallyEvent
	if defense_event_for_staging != null:
		defense_event_for_staging.metadata["staged_next_actor_id"] = setter.id
		defense_event_for_staging.metadata["staged_next_position"] = setter_start
	var emergency_setter := setter != null and setter.id != lineup.active_setter_id()
	var hitter := _fallback_hitter(players, lineup, setter.id)
	var assignment := _fallback_assignment(hitter, lineup)
	var exchange_penalty := float(exchange_number) * 0.04
	var set_quality := clampf(
		_rating(setter, "set_accuracy") * 0.52
		+ _rating(setter, "ball_control") * 0.22
		+ _rating(setter, "composure") * 0.16
		- exchange_penalty + clampf(setter_arrival_margin * 0.16, -0.38, 0.07) \
		+ rng.randf_range(-0.14, 0.14), 0.10, 0.92
	)
	var set_target := CourtConstants.lane_target(assignment.lane)
	var continuation_set_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_contact, set_target),
		_set_launch_angle_degrees(setter, assignment.tempo, set_quality),
	)
	var continuation_flight_time: float = float(continuation_set_arc.duration_seconds)
	var cont_release_profile := setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE)
	var cont_release_interval := _release_interval(cont_release_profile, set_quality)
	## The transition set leaves the setter's hands once they have travelled to
	## the dig, taken the ball, and released it. Every later contact in this
	## continuation is timed from that instant, mirroring the main set path --
	## without it the set flight would start after the attack flight it feeds.
	var cont_set_contact_time := rally_clock + second_contact_window + cont_release_interval
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		set_contact, set_target, set_quality >= 0.20, set_quality,
		("Emergency second-contact set" if emergency_setter else "Transition set") \
		+ " · exchange %d" % exchange_number,
		"Contact 2 of 3 after %s's dig · %d%% set quality." % [
			defender.display_name, roundi(set_quality * 100.0),
		], {"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": defender.id, "movement_start": setter_start,
			"movement_duration": setter_move_time,
			"arrival_margin": setter_arrival_margin,
			"flight_time": continuation_flight_time,
			"release_interval": cont_release_interval,
			"deadline": cont_set_contact_time,
			"event_time": cont_set_contact_time,
			"outgoing_trajectory": _ball_trajectory(
				"set", set_contact, set_target, continuation_flight_time,
				float(continuation_set_arc.apex_height_meters), cont_set_contact_time
			)})
	live_positions[setter.id] = set_contact
	var hitter_start: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	var transition_state := RallyStateBuilderModel.build(
		players, lineup, defensive_plan, opponent_team, null, true,
		rng.seed + exchange_number * 1009,
	)
	transition_state.simulation_time = maxf(rally_clock - 0.55, 0.0)
	for raw_player_id in transition_state.home_players:
		var phase_actor := transition_state.player_state(&"home", int(raw_player_id))
		if phase_actor != null:
			phase_actor.apply_position(Vector2(live_positions.get(
				int(raw_player_id), phase_actor.position
			)), phase_actor.velocity)
	var hitter_actor := transition_state.player_state(&"home", hitter.id)
	var continuation_assignment := {
		"player_id": hitter.id, "lane": assignment.lane,
		"tempo": assignment.tempo, "priority": assignment.priority,
		"target": set_target,
	}
	var transition_preparation := ApproachMechanicsModel.prepare_for_attack(
		transition_state, hitter_actor, continuation_assignment, defender.id,
		cont_set_contact_time,
	)
	var prepared_hitter := transition_preparation.get("actor") as RallyPlayerState
	transition_preparation.erase("actor")
	if prepared_hitter != null:
		hitter_start = prepared_hitter.position
	var hitter_move_time := _movement_time(
		hitter, hitter_start, set_target, "transition"
	)
	var hitter_arrival_margin := continuation_flight_time - hitter_move_time
	var set_event_for_staging := result.events[-1] as RallyEvent
	if set_event_for_staging != null:
		set_event_for_staging.metadata["staged_next_actor_id"] = hitter.id
		set_event_for_staging.metadata["staged_next_position"] = hitter_start
	var continuation_approach := ApproachMechanicsModel.evaluate_takeoff(
		prepared_hitter, set_target, continuation_flight_time
	) if prepared_hitter != null else {}
	var continuation_actions := ApproachMechanicsModel.available_attack_families(
		hitter, continuation_approach, hitter_arrival_margin
	)
	## The third copy of the execution scale, now the same model as the other
	## two. A transition swing is harder than one off a served ball, and
	## `exchange_penalty` is what carries that -- as a demand on the swing, the
	## same slot tempo occupies in the first-ball case.
	var attack_quality := clampf(
		_attack_execution(
			hitter, set_quality,
			_approach_execution_fit(hitter, continuation_approach),
			hitter_arrival_margin, exchange_penalty, 0.0,
		) + rng.randf_range(-ATTACK_EXECUTION_NOISE, ATTACK_EXECUTION_NOISE),
		0.0, 1.0,
	)
	var attack_target := Vector2(1.0 - set_target.x, rng.randf_range(0.12, 0.38))
	var continuation_approach_start := Vector2(transition_preparation.get(
		"approach_start_position",
		_approach_start_position(set_target, hitter_start, false)
	))
	## Same rule as the first-ball swing: capability shapes the outcome, it does
	## not remove the option.
	var continuation_hit_type := _hit_type(assignment, hitter)
	var continuation_deficit := ApproachMechanicsModel.attack_family_deficit(
		hitter, continuation_approach, hitter_arrival_margin,
		ApproachMechanicsModel.attack_family_for_hit_type(continuation_hit_type),
	)
	if AttemptJudgmentModel.backs_off(hitter, continuation_deficit):
		continuation_hit_type = "Controlled roll" \
			if "controlled_roll" in continuation_actions else "Emergency tip"
		continuation_deficit = ApproachMechanicsModel.attack_family_deficit(
			hitter, continuation_approach, hitter_arrival_margin,
			ApproachMechanicsModel.attack_family_for_hit_type(continuation_hit_type),
		)
	if continuation_deficit > 0.0:
		attack_quality = clampf(
			attack_quality - continuation_deficit * ATTACK_OVERREACH_SEVERITY,
			0.0, 1.0,
		)
	## One shot shape, used both for the full flight and -- if a block touches
	## it -- for the re-sliced leg to the net, so the two describe the same ball.
	var continuation_attack_angle := _attack_launch_angle_degrees(
		hitter, continuation_hit_type, attack_quality
	)
	var continuation_attack_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_target, attack_target),
		continuation_attack_angle,
	)
	var continuation_attack_flight: float = float(continuation_attack_arc.duration_seconds)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, attack_quality >= 0.25, attack_quality,
		"T3 outside swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %d%% attack quality." % roundi(attack_quality * 100.0),
		{"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			"attack_type": continuation_hit_type,
			"movement_start": hitter_start,
			"approach_start_position": continuation_approach_start,
			"approach_target_position": Vector2(transition_preparation.get(
				"approach_target_position", continuation_approach_start
			)),
			"reached_approach_mark": bool(transition_preparation.get(
				"reached_approach_start", true
			)),
			"transition_preparation": transition_preparation.duplicate(true),
			"resolved_approach": continuation_approach.duplicate(true),
			"available_attack_actions": continuation_actions.duplicate(),
			"approach_speed_mps": float(continuation_approach.get("approach_speed_mps", 0.0)),
			"approach_quality": float(continuation_approach.get("runup_quality", 0.0)),
			"approach_distance_meters": float(continuation_approach.get(
				"approach_distance_meters", 0.0
			)),
			"approach_in_system": bool(continuation_approach.get(
				"approach_in_system", false
			)),
			"jump_multiplier": float(continuation_approach.get("jump_multiplier", 1.0)),
			"lateral_control": float(continuation_approach.get("lateral_control", 0.0)),
			"movement_duration": hitter_move_time,
			"arrival_margin": hitter_arrival_margin,
			"set_flight_time": continuation_flight_time,
			"flight_time": continuation_attack_flight,
			"event_time": cont_set_contact_time + continuation_flight_time,
			"outgoing_trajectory": _ball_trajectory(
				"attack", set_target, attack_target, continuation_attack_flight,
				float(continuation_attack_arc.apex_height_meters),
				cont_set_contact_time + continuation_flight_time
			)})
	live_positions[hitter.id] = set_target
	## The continuation now owns a real timeline instead of stamping every
	## contact with the dig's clock: set contact, then the set flight, then the
	## attack. Later contacts read `rally_clock` and inherit it.
	rally_clock = cont_set_contact_time + continuation_flight_time
	if attack_quality < ATTACK_ERROR_THRESHOLD:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	var block_result := _resolve_opponent_block(
		opponent_team, set_target.x, assignment.tempo, set_quality,
		attack_quality, set_contact.x, continuation_flight_time
	)
	var opponent_blocker := block_result.primary as VolleyballPlayer
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var primary_close := float(block_result.primary_close)
	var assist_close := float(block_result.assist_close)
	var block_quality := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	var blocked := block_outcome == "stuff"
	## Same contract as the main attack path: a block only shortens the shot if
	## it actually touches it, and an untouched ball carries no deflection leg.
	## Without this the continuation attack flew its full arc *and* the block
	## emitted an overlapping path from the net, so the ball was described in
	## two places at once.
	var cont_block_contacts := blocked \
		or block_outcome in ["recycle", "touch", "funnel"]
	var cont_net_contact := Vector2(set_target.x, 0.50)
	var block_event_end := Vector2(set_target.x, 0.50) if not blocked \
		else Vector2(set_target.x, 0.47)
	if cont_block_contacts:
		var cont_attack_event: Resource = result.events[-1]
		var cont_to_block_arc := RallyKinematics.solve_launch_arc(
			RallyKinematics.court_distance_meters(set_target, cont_net_contact),
			continuation_attack_angle,
		)
		cont_attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", set_target, cont_net_contact,
			float(cont_to_block_arc.duration_seconds),
			float(cont_to_block_arc.apex_height_meters),
			cont_set_contact_time + continuation_flight_time,
		)
	var block_event_detail := "Primary close %d%%; block quality %d%%." % [
		roundi(primary_close * 100.0), roundi(block_quality * 100.0),
	]
	if assisting_blocker != null:
		block_event_detail += " %s assisted at %d%% close." % [
			assisting_blocker.display_name, roundi(assist_close * 100.0)
		]
	_add_event(result, RallyEventModel.EventType.BLOCK,
		opponent_blocker.id if opponent_blocker != null else -1,
		opponent_blocker.display_name if opponent_blocker != null else "Open block",
		Vector2(set_target.x, 0.47),
		block_event_end, blocked, block_quality,
		"Opponent block · exchange %d" % exchange_number,
		block_event_detail, {"side": "opponent", "outcome": block_outcome,
		"primary_close": primary_close, "assist_close": assist_close,
		"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
		"primary_position": _block_wall_positions(set_target.x, true).primary_position,
		"assist_position": _block_wall_positions(set_target.x, true).assist_position,
		"coverage_segments": block_result.coverage_segments,
		"setter_pull": block_result.setter_pull,
		"read_quality": block_result.read_quality,
		"event_time": rally_clock,
		"outgoing_trajectory": _ball_trajectory(
			"block_deflection", cont_net_contact, block_event_end,
			0.24, 0.42, rally_clock
		) if cont_block_contacts else {}})
	if blocked:
		return _finish(result, "blocked", false, hitter.id, {"hitter": hitter.display_name})
	var opponent_defender := opponent_team.best_defender() as VolleyballPlayer
	var defense_quality := _rating(opponent_defender, "reception") * 0.36 \
		+ _rating(opponent_defender, "dig_control") * 0.16 \
		+ _rating(opponent_defender, "anticipation") * 0.34 \
		+ rng.randf_range(-0.16, 0.16)
	var dug: bool = defense_quality > attack_quality + rng.randf_range(-0.18, 0.14)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id,
		opponent_defender.display_name, attack_target,
		attack_target + Vector2(0.04, -0.03), dug, defense_quality,
		"Opponent dig · exchange %d" % exchange_number,
		"Contact 1 of 3 · %d%% control." % roundi(defense_quality * 100.0))
	if not dug:
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": "Default T3 Outside",
		}, "kill_default")
	return _resolve_opponent_transition(
		result, players, lineup, hitter, attack_target,
		opponent_team, defensive_plan, exchange_number + 1,
	)


## The block that forms against this attack, before the swing is contested.
##
## Split out because attack quality needs to know what it is hitting into. The
## close fractions depend on the lane, the tempo and the set -- none of which
## need the attack's own quality -- so the formation can be resolved first and
## the contest settled afterwards with the same numbers, rather than the swing
## being scored against nothing and the block appearing only after the fact.
func _form_opponent_block(
	opponent_team: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	setter_x: float,
	set_flight_time: float,
) -> Dictionary:
	var lineup: RotationLineup = opponent_team.current_lineup() if opponent_team != null else null
	var front_blockers: Array[VolleyballPlayer] = []
	var setter_pull := {}
	if opponent_team == null or lineup == null:
		return {
			"primary": null, "assist": null, "primary_close": 0.0,
			"assist_close": 0.0, "quality": 0.0, "outcome": "miss",
			"coverage_segments": [], "setter_pull": setter_pull,
		}
	for player_id in lineup.front_row_player_ids():
		var player := opponent_team.player_by_id(player_id) as VolleyballPlayer
		if player != null:
			front_blockers.append(player)
			var slot_number := lineup.slot_for_player(player.id)
			var start: Vector2 = CourtConstants.slot_position(slot_number)
			var discipline := clampf(
				(_rating(player, "tactical_discipline") * 0.65
				+ _rating(player, "anticipation") * 0.35), 0.0, 1.0
			)
			var pull_weight := (1.0 - discipline) * 0.18
			var pulled_x := lerpf(start.x, setter_x, pull_weight)
			setter_pull[player.id] = absf(pulled_x - start.x)
	if front_blockers.is_empty():
		return {
			"primary": null, "assist": null, "primary_close": 0.0,
			"assist_close": 0.0, "quality": 0.0, "outcome": "miss",
			"coverage_segments": [], "setter_pull": setter_pull,
		}
	var primary: VolleyballPlayer
	var primary_distance := 1000.0
	for candidate in front_blockers:
		var slot_number := lineup.slot_for_player(candidate.id)
		var candidate_x := CourtConstants.slot_position(slot_number).x
		var distance := absf(candidate_x - attack_x)
		if distance < primary_distance:
			primary = candidate
			primary_distance = distance
	## How long the blockers actually have: the set's own flight time, which the
	## kinematics solver already produced from real distance and launch angle.
	##
	## This used to be `0.30 + tempo * 0.045 + (1 - set_quality) * 0.18` -- a
	## table that gave a middle blocker 0.30 s of movement to cover 2.9 m of net,
	## which is physically impossible, so double blocks formed in 1% of rallies
	## and tempo could not change the block. Flight time already encodes tempo: a
	## quick set lands in a fraction of the time a high ball takes, so the middle
	## closes on a high ball and does not on a quick one. That is the whole
	## tempo-versus-block dynamic, and it now falls out of the ball's own physics
	## rather than a constant.
	var close_time := maxf(set_flight_time, 0.0) \
		+ (1.0 - set_quality) * 0.10
	var read_total := 0.0
	for reader in front_blockers:
		read_total += _blocker_read_quality(reader, tempo, set_quality, setter_x)
	var read_quality := read_total / maxf(float(front_blockers.size()), 1.0)
	close_time += lerpf(-0.09, 0.09, read_quality)
	var primary_close := _blocker_close_fraction(
		primary, lineup, attack_x, close_time
	)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var close_fraction := _blocker_close_fraction(
			candidate, lineup, attack_x, close_time
		)
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	var block_quality := _block_wall_quality(primary_skill, assist_skill)
	return {
		"primary": primary,
		"assist": assist,
		"primary_close": primary_close,
		"assist_close": assist_close,
		"quality": block_quality,
		"coverage_segments": _home_block_segments(
			attack_x, primary, primary_close, assist, assist_close
		),
		"setter_pull": setter_pull,
		"read_quality": read_quality,
	}


## Settles a formed block against the swing that was actually hit at it. One
## copy, both sides of the net, every exchange.
func _contest_block(
	formation: Dictionary,
	attack_quality: float,
) -> Dictionary:
	var resolved := formation.duplicate(true)
	resolved["primary"] = formation.get("primary")
	resolved["assist"] = formation.get("assist")
	var block_quality := float(formation.get("quality", 0.0))
	var primary_close := float(formation.get("primary_close", 0.0))
	## A terminal stuff needs the block to clearly beat the swing and to have
	## sealed the lane, not merely to have edged it. These margins were set
	## against a block whose quality sat in a 0.04-wide band; once quality spread
	## across 0.43-0.77 the old +0.14 margin turned a third of all attacks into
	## stuff blocks.
	var contest := block_quality + rng.randf_range(-0.14, 0.12)
	var outcome := "miss"
	if contest > attack_quality + BLOCK_STUFF_MARGIN and primary_close >= 0.78:
		outcome = "stuff"
	elif contest > attack_quality + BLOCK_TOUCH_MARGIN:
		outcome = "touch"
	elif contest > attack_quality + BLOCK_FUNNEL_MARGIN:
		outcome = "funnel"
	resolved["outcome"] = outcome
	return resolved


## Formation and contest together, for callers that do not need to score an
## attack against the block first.
func _resolve_opponent_block(
	opponent_team: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	attack_quality: float,
	setter_x: float,
	set_flight_time: float,
) -> Dictionary:
	return _contest_block(
		_form_opponent_block(
			opponent_team, attack_x, tempo, set_quality, setter_x, set_flight_time
		),
		attack_quality,
	)


func _attack_coverage_target(set_target: Vector2, block_quality: float) -> Vector2:
	var spread := lerpf(0.14, 0.05, clampf(block_quality, 0.0, 1.0))
	return Vector2(
		clampf(set_target.x + rng.randf_range(-spread, spread), 0.08, 0.92),
		rng.randf_range(0.54, 0.70),
	)


## Search resolution for open-floor scanning. These are sample points for a
## search across the whole legal court, NOT a menu of permitted targets: the
## chosen point is continuously perturbed afterwards, so landing spots form a
## distribution over the floor rather than clustering on a handful of dots.
const ATTACK_SCAN_COLUMNS: int = 13
const ATTACK_SCAN_ROWS: int = 9
const ATTACK_COURT_MIN := Vector2(0.055, 0.055)
const ATTACK_COURT_MAX := Vector2(0.945, 0.445)

## Depth a shot family naturally wants, as a fraction from the net (0) to the
## endline (1). Power swings drive deep; rolls and tips die short.
const ATTACK_DEPTH_PREFERENCE := {
	"Power swing": 0.70,
	"Tempo swing": 0.60,
	"Quick attack": 0.52,
	"Pipe attack": 0.68,
	"High-ball swing": 0.62,
	"Controlled roll": 0.34,
	"Emergency tip": 0.20,
}


## Where this hitter aims, chosen continuously from the actual open floor.
##
## This used to pick from five fixed coordinates, so every attack in the game
## landed on one of five spots regardless of where the defence stood. The floor
## is now scanned properly: each sample is scored by how far it sits from the
## nearest defender, how naturally it fits the shot family being hit, and how
## far the hitter has to swing away from their approach line to reach it -- a
## sharp cross-court from a tight set is a harder ball than an easy line shot,
## and only a hitter with the accuracy and shot variety to attempt it should.
##
## The winning sample is then displaced by an aiming error that shrinks with
## `attack_accuracy`, so the resolved target is a continuous point that no
## table contains.
func _choose_home_attack_target(
	hitter: VolleyballPlayer,
	lane: String,
	hit_type: String,
	opponent_team: Resource,
) -> Dictionary:
	var contact := CourtConstants.lane_target(lane)
	var accuracy := _rating(hitter, "attack_accuracy")
	var variety := _rating(hitter, "shot_variety")
	var reading := _rating(hitter, "decision_making")

	var defenders: Array[Vector2] = []
	for defender_resource in opponent_team.on_court_players():
		var defender: VolleyballPlayer = defender_resource as VolleyballPlayer
		if defender == null:
			continue
		defenders.append(opponent_live_positions.get(
			defender.id, opponent_team.court_position(defender.id, "defense")
		))

	## How far off their natural line this hitter can credibly swing. A narrow
	## repertoire keeps them hitting where their approach already points.
	var swing_range := lerpf(0.22, 0.62, variety * 0.6 + accuracy * 0.4)
	var preferred_depth := float(ATTACK_DEPTH_PREFERENCE.get(hit_type, 0.6))

	var best_target := Vector2(
		clampf(1.0 - contact.x, ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x),
		lerpf(ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y, preferred_depth),
	)
	var best_score := -1.0e9
	for column in range(ATTACK_SCAN_COLUMNS):
		var x := lerpf(
			ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x,
			float(column) / float(ATTACK_SCAN_COLUMNS - 1)
		)
		if absf(x - contact.x) > swing_range:
			continue
		for row in range(ATTACK_SCAN_ROWS):
			var y := lerpf(
				ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y,
				float(row) / float(ATTACK_SCAN_ROWS - 1)
			)
			var candidate := Vector2(x, y)
			var nearest := 10.0
			for defender_position in defenders:
				nearest = minf(
					nearest,
					CoverageModel.court_distance_meters(defender_position, candidate)
				)
			var depth_fraction := inverse_lerp(
				ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y, y
			)
			var score := nearest 				- absf(depth_fraction - preferred_depth) * 3.2 				- absf(x - contact.x) * 1.6
			if score > best_score:
				best_score = score
				best_target = candidate

	## A hitter who reads the floor well finds the gap; one who does not commits
	## to their own line regardless of who is standing in it.
	var instinctive := Vector2(
		clampf(
			contact.x + (0.5 - contact.x) * 0.7,
			ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x
		),
		lerpf(ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y, preferred_depth),
	)
	var aim := best_target if rng.randf() < reading else instinctive

	## Aiming error, continuous and shrinking with accuracy. This is what makes
	## the resolved point one no table contains.
	var spread := lerpf(0.115, 0.022, accuracy)
	var target := Vector2(
		clampf(
			aim.x + rng.randf_range(-spread, spread),
			ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x
		),
		clampf(
			aim.y + rng.randf_range(-spread, spread) * 0.8,
			ATTACK_COURT_MIN.y, ATTACK_COURT_MAX.y
		),
	)
	return {
		"target": target,
		"direction": _attack_direction(contact.x, target),
		"reason": "open floor" if aim == best_target else "hit their own line",
	}


func _choose_opponent_defender(
	opponent_team: Resource,
	target: Vector2,
	flight_time: float,
) -> Dictionary:
	var best: VolleyballPlayer
	var best_score := -1000.0
	var best_data := {"start": target, "distance_meters": 99.0,
		"travel_time": 9.0, "arrival_margin": -9.0}
	for defender_resource in opponent_team.on_court_players():
		var defender: VolleyballPlayer = defender_resource as VolleyballPlayer
		if defender == null or str(defender.position_code) in ["S", "M1", "M2"]:
			continue
		var start: Vector2 = opponent_live_positions.get(
			defender.id, opponent_team.court_position(defender.id, "defense")
		)
		var mirrored_target := Vector2(target.x, target.y)
		var distance_meters := CoverageModel.court_distance_meters(start, mirrored_target)
		var travel_time := _movement_time(defender, start, mirrored_target, "lateral")
		var arrival_margin := flight_time - travel_time
		var score := arrival_margin * 0.58 + _rating(defender, "anticipation") * 0.25 \
			+ _rating(defender, "reception") * 0.17
		if score > best_score:
			best = defender
			best_score = score
			best_data = {"start": start, "distance_meters": distance_meters,
				"travel_time": travel_time, "arrival_margin": arrival_margin}
	best_data["player"] = best if best != null else opponent_team.best_defender()
	return best_data


func _choose_opponent_attack(
	opponent_team: Resource,
	setter: VolleyballPlayer,
	set_quality: float,
	open_target: Vector2,
	set_flight_time: float,
) -> Dictionary:
	var candidates: Array[Resource] = opponent_team.eligible_hitters(setter.id)
	if candidates.is_empty():
		candidates.append(opponent_team.best_hitter())
	var best: VolleyballPlayer
	var best_score := -1000.0
	for resource in candidates:
		var candidate: VolleyballPlayer = resource as VolleyballPlayer
		if candidate == null:
			continue
		var quick_demand := 0.13 if str(candidate.position_code).begins_with("M") else 0.0
		var candidate_contact_x := 0.50
		if str(candidate.position_code) in ["OH1", "OH2"]:
			candidate_contact_x = 0.18
		elif str(candidate.position_code) == "OP":
			candidate_contact_x = 0.82
		var candidate_start: Vector2 = opponent_live_positions.get(
			candidate.id, opponent_team.court_position(candidate.id, "transition")
		)
		var candidate_contact := Vector2(candidate_contact_x, 0.48)
		var candidate_travel := _movement_time(
			candidate, candidate_start, candidate_contact, "transition"
		)
		var lateness := maxf(candidate_travel - set_flight_time, 0.0)
		var option_score := _power_rating(candidate, "attack_power") * 0.42 \
			+ _rating(candidate, "attack_accuracy") * 0.24 \
			+ _rating(candidate, "approach_timing") * 0.18 \
			+ set_quality * 0.16 - quick_demand * (1.0 - set_quality) \
			- clampf(lateness / 1.2, 0.0, 1.0) * 0.12 \
			+ rng.randf_range(-0.12, 0.12)
		if option_score > best_score:
			best = candidate
			best_score = option_score
	var code := str(best.position_code)
	var contact_x := 0.50
	if code in ["OH1", "OH2"]:
		contact_x = 0.18
	elif code == "OP":
		contact_x = 0.82
	var start: Vector2 = opponent_live_positions.get(
		best.id, opponent_team.court_position(best.id, "transition")
	)
	var contact := Vector2(contact_x, 0.48)
	var travel_time := _movement_time(best, start, contact, "transition")
	var attack_type := "Quick attack" if code.begins_with("M") and set_quality >= 0.46 \
		else "Power swing"
	if set_quality < 0.38 or rng.randf() < 0.12 + _rating(best, "decision_making") * 0.08:
		attack_type = "Roll shot" if set_quality >= 0.30 else "Emergency tip"
	var target := open_target
	if attack_type in ["Roll shot", "Emergency tip"]:
		target.y = rng.randf_range(0.58, 0.72)
	else:
		target.y = rng.randf_range(0.80, 0.93)
	return {"player": best, "start": start, "contact": contact,
		"target": target, "travel_time": travel_time,
		"attack_type": attack_type, "direction": _attack_direction(contact_x, target)}


func _home_target_hint(defensive_plan: Resource) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(0.18, 0.86), Vector2(0.50, 0.84), Vector2(0.82, 0.86),
		Vector2(0.34, 0.66), Vector2(0.66, 0.66),
	]
	if defensive_plan == null:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var zones: Dictionary = defensive_plan.zones_for(DefensiveZoneModel.ZoneType.FLOOR_DEFENSE)
	var best := candidates[0]
	var best_gap := -1.0
	for target in candidates:
		var nearest := 10.0
		for player_id in zones:
			var zone: Resource = zones[player_id]
			if zone != null and bool(zone.enabled):
				nearest = minf(nearest, Vector2(zone.center).distance_to(target))
		if nearest > best_gap:
			best = target
			best_gap = nearest
	return best


func _attack_direction(contact_x: float, target: Vector2) -> String:
	if target.y < 0.76:
		return "short court"
	if absf(target.x - contact_x) <= 0.20:
		return "line"
	if absf(target.x - 0.50) <= 0.14:
		return "seam"
	return "cross-court"


func _initial_home_positions(
	lineup: RotationLineup,
	defensive_plan: Resource,
	receiving: bool,
) -> Dictionary:
	var positions := {}
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var position := CourtConstants.slot_position(slot_number)
		if defensive_plan != null:
			if receiving:
				var zone: Resource = defensive_plan.zone_for(
					player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
				)
				if zone != null:
					position = Vector2(zone.center)
			else:
				position = defensive_plan.defender_position(player_id, position)
		positions[player_id] = position
	return positions


func _initial_opponent_positions(
	opponent_team: Resource,
	receiving: bool,
) -> Dictionary:
	var positions := {}
	if opponent_team == null:
		return positions
	var reception_zones: Dictionary = {}
	if receiving:
		reception_zones = _opponent_reception_coverage(opponent_team).zones
	for player_resource in opponent_team.on_court_players():
		var player := player_resource as VolleyballPlayer
		if player == null:
			continue
		var position: Vector2 = opponent_team.court_position(player.id, "defense")
		var zone: Resource = reception_zones.get(player.id) as Resource
		if zone != null and bool(zone.enabled):
			position = Vector2(zone.center)
		positions[player.id] = position
	return positions


func _zones_at_phase_positions(
	source_zones: Dictionary,
	phase_positions: Dictionary,
) -> Dictionary:
	var zones := {}
	for raw_player_id in source_zones:
		var player_id := int(raw_player_id)
		var source: Resource = source_zones[raw_player_id] as Resource
		if source == null:
			continue
		var zone: Resource = DefensiveZoneModel.new()
		zone.player_id = player_id
		zone.zone_type = source.zone_type
		zone.center = phase_positions.get(player_id, Vector2(source.center))
		zone.radius_meters = source.radius_meters
		zone.priority = source.priority
		zone.enabled = source.enabled
		zones[player_id] = zone
	return zones


func _home_floor_phase_positions(
	lineup: RotationLineup,
	defensive_plan: Resource,
	attack_x: float,
	primary_blocker_id: int,
	assisting_blocker_id: int,
) -> Dictionary:
	var positions := {}
	if lineup == null:
		return positions
	var relationship := str(defensive_plan.block_defense_relationship) \
		if defensive_plan != null else "Balanced"
	var depth := str(defensive_plan.defensive_depth) \
		if defensive_plan != null else "Balanced"
	var short_posture := str(defensive_plan.short_ball_posture) \
		if defensive_plan != null else "Standard"
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id in [primary_blocker_id, assisting_blocker_id]:
			positions[player_id] = Vector2(attack_x, 0.54)
			continue
		var fallback := CourtConstants.slot_position(slot_number)
		var target: Vector2 = defensive_plan.defender_position(player_id, fallback) \
			if defensive_plan != null else fallback
		var zone: Resource = defensive_plan.zone_for(
			player_id, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
		) if defensive_plan != null else null
		if zone != null and bool(zone.enabled):
			target = Vector2(zone.center)
		var coverage_focus := 0.50
		if relationship == "Defend Line":
			coverage_focus = attack_x
		elif relationship == "Defend Cross":
			coverage_focus = 1.0 - attack_x
		var front_row := CourtConstants.is_front_row_slot(slot_number)
		target.x = lerpf(target.x, coverage_focus, 0.09 if front_row else 0.18)
		if depth == "Deep":
			target.y += 0.035
		elif depth == "Shallow":
			target.y -= 0.035
		if short_posture == "Compress Short":
			target.y = lerpf(target.y, 0.68, 0.18)
		var assignment: Resource = defensive_plan.assignment_for(player_id) \
			if defensive_plan != null else null
		if assignment != null \
				and "inside seam" in str(assignment.seam_responsibility).to_lower():
			target.x = lerpf(target.x, 0.50, 0.08)
		positions[player_id] = Vector2(
			clampf(target.x, 0.06, 0.94),
			clampf(target.y, 0.56, 0.96),
		)
	return positions


func _approach_start_position(
	contact_position: Vector2,
	current_position: Vector2,
	opponent_side: bool,
) -> Vector2:
	var local_contact := Vector2(
		contact_position.x, 1.0 - contact_position.y
	) if opponent_side else contact_position
	var local_current := Vector2(
		current_position.x, 1.0 - current_position.y
	) if opponent_side else current_position
	var pin_distance := absf(local_contact.x - 0.50)
	var approach_depth := 0.135 * lerpf(
		0.88, 1.12, clampf(pin_distance / 0.34, 0.0, 1.0)
	)
	var outward_offset := 0.0
	if local_contact.x < 0.35:
		outward_offset = -0.055
	elif local_contact.x > 0.65:
		outward_offset = 0.055
	var approach := Vector2(
		clampf(local_contact.x + outward_offset, 0.06, 0.94),
		clampf(local_contact.y + approach_depth, 0.56, 0.94),
	)
	## Do not send a hitter backward across the whole court merely to draw a
	## textbook approach. Preserve the resolved side of their current route.
	approach.x = lerpf(local_current.x, approach.x, 0.78)
	return Vector2(approach.x, 1.0 - approach.y) if opponent_side else approach


func _movement_time(
	player: VolleyballPlayer,
	start: Vector2,
	target: Vector2,
	movement_kind: String,
	waypoint: Variant = null,
) -> float:
	if player == null:
		return 4.0
	## One movement model. This used to carry its own constant-velocity formula
	## with a flat startup penalty, which disagreed with the kinematics every
	## reachability decision is built on -- and disagreed in opposite directions
	## by phase, because a flat penalty undercharges short traversals and
	## amortises away on long ones. It now asks the same model.
	var actor := RallyPlayerState.create(player, &"home", -1, start)
	var opening := RallyKinematicsModel.court_delta_meters(start, target)
	if opening.length() > 0.0001:
		## The resolver does not track facing at this point, and charging a full
		## reorientation the player may not need would reintroduce a second
		## disagreement. Face the route; the turn floor still applies.
		actor.facing = opening.normalized()
	return RallyMovementSystemModel.traversal_seconds(
		actor, target, _movement_mode_for_kind(movement_kind), waypoint
	)


static func _movement_mode_for_kind(
	movement_kind: String,
) -> RallyPlayerState.MovementMode:
	match movement_kind:
		"lateral":
			return RallyPlayerState.MovementMode.LATERAL
		"approach":
			return RallyPlayerState.MovementMode.APPROACH
	return RallyPlayerState.MovementMode.TRANSITION


## The two positions a block wall occupies, pressed to the net on the blocking
## team's own side. The assist closes inward from the middle of the court, so
## the wall extends toward centre rather than off the sideline.
static func _block_wall_positions(
	lane_x: float,
	opponent_side: bool,
) -> Dictionary:
	var wall_y := CourtConstants.NET_Y - BLOCK_NET_DEPTH if opponent_side \
		else CourtConstants.NET_Y + BLOCK_NET_DEPTH
	var inward := 1.0 if lane_x < 0.5 else -1.0
	return {
		"primary_position": Vector2(clampf(lane_x, 0.05, 0.95), wall_y),
		"assist_position": Vector2(
			clampf(lane_x + BLOCK_SHOULDER_OFFSET * inward, 0.05, 0.95), wall_y
		),
	}


## Where this opponent setter takes the ball in serve receive: the same release
## the home side uses, mirrored, rather than a fixed point in the middle of the
## court. Shared so the reception's pass target and the setter's own position
## cannot drift apart and leave the ball landing somewhere the setter is not.
static func _opponent_setter_release_target(opponent_team: Resource) -> Vector2:
	if opponent_team == null:
		return Vector2(0.62, 0.34)
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	if opponent_lineup == null:
		return Vector2(0.62, 0.34)
	return CourtConstants.mirror_to_opponent(
		CourtConstants.setter_serve_receive_position(
			opponent_lineup.slot_for_player(opponent_lineup.active_setter_id())
		)
	)


## Time between the ball reaching the setter's hands and leaving them.
##
## Both halves of the setter's `SYSTEM_FIT_SET_RELEASE` profile are consumed:
## `ideal_value` is their natural rhythm (quick setters release sooner) and
## `tolerance` is how far off it they can work. A clean ball goes out at the
## fast edge of that band and a mishandled one at the slow edge, so an
## adaptable setter genuinely varies tempo with the ball they get while a rigid
## one clusters on their ideal. The band belongs to the player, not to a tuned
## constant here.
static func _release_interval(profile: SystemFitProfile, set_quality: float) -> float:
	var ideal := profile.ideal_value if profile != null \
		else DEFAULT_SET_RELEASE_SECONDS
	var band := profile.tolerance if profile != null \
		else DEFAULT_SET_RELEASE_TOLERANCE
	return clampf(
		ideal + lerpf(band, -band, clampf(set_quality, 0.0, 1.0)),
		MINIMUM_SET_RELEASE_SECONDS, MAXIMUM_SET_RELEASE_SECONDS,
	)


func _ball_trajectory(
	kind: String,
	start: Vector2,
	end: Vector2,
	flight_time: float,
	apex_height: float,
	start_timestamp: float = -1.0,
) -> Dictionary:
	var timestamp := rally_clock if start_timestamp < 0.0 else start_timestamp
	var direction := end - start
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var curve_amount := clampf(direction.length() * 0.08, 0.0, 0.035)
	var control := start.lerp(end, 0.5) + perpendicular * curve_amount
	var trajectory: Resource = BallTrajectoryModel.create(
		kind, start, control, end, timestamp, flight_time, apex_height
	)
	return trajectory.to_dict()


func _desired_pass_target(release_target: Vector2, reception_contact: Vector2) -> Vector2:
	# A distant passer aims slightly higher/off the net to reduce overpass risk;
	# nearby passers can safely feed the setter's release point more directly.
	var distance_meters := Vector2(
		(reception_contact.x - release_target.x) * 9.0,
		(reception_contact.y - release_target.y) * 18.0,
	).length()
	var safety_offset := clampf((distance_meters - 4.0) * 0.006, 0.0, 0.045)
	return Vector2(release_target.x, clampf(release_target.y + safety_offset, 0.55, 0.70))


func _set_geometry(
	setter: VolleyballPlayer,
	setter_start: Vector2,
	contact: Vector2,
	target: Vector2,
	release_target: Vector2,
) -> Dictionary:
	var set_vector := Vector2((target.x - contact.x) * 9.0, (target.y - contact.y) * 18.0)
	var arrival_vector := Vector2(
		(contact.x - setter_start.x) * 9.0, (contact.y - setter_start.y) * 18.0
	)
	var distance_meters := set_vector.length()
	var release_distance := Vector2(
		(contact.x - release_target.x) * 9.0,
		(contact.y - release_target.y) * 18.0,
	).length()
	var angle_degrees := absf(rad_to_deg(set_vector.angle()))
	var orientation_fit := 1.0
	if arrival_vector.length() > 0.15 and set_vector.length() > 0.15:
		orientation_fit = clampf(
			(arrival_vector.normalized().dot(set_vector.normalized()) + 1.0) * 0.5,
			0.0, 1.0,
		)
	var net_distance_meters := absf(contact.y - CourtConstants.NET_Y) * 18.0
	var balance := _rating(setter, "set_balance")
	var stability := _rating(setter, "set_stability")
	var tight_risk := clampf((0.55 - net_distance_meters) * 0.10, 0.0, 0.055) \
		* lerpf(1.0, 0.55, stability)
	var distance_difficulty := maxf(distance_meters - 2.0, 0.0) * 0.012 \
		* lerpf(1.0, 0.68, stability)
	var orientation_difficulty := (1.0 - orientation_fit) * 0.10 \
		* lerpf(1.0, 0.48, balance)
	var difficulty := clampf(
		distance_difficulty
		+ release_distance * 0.020
		+ orientation_difficulty
		+ tight_risk,
		0.0, 0.28,
	)
	return {
		"distance_meters": distance_meters,
		"angle_degrees": angle_degrees,
		"release_distance_meters": release_distance,
		"body_orientation_fit": orientation_fit,
		"set_balance": balance,
		"set_stability": stability,
		"net_distance_meters": net_distance_meters,
		"difficulty": difficulty,
	}


func _reception_pass_result(
	receiver: VolleyballPlayer,
	start_position: Vector2,
	contact_position: Vector2,
	desired_target: Vector2,
	serve_origin: Vector2,
	serve_force: float,
	arrival: Dictionary,
	reception_quality: float,
) -> Dictionary:
	var movement_vector := contact_position - start_position
	var desired_vector := desired_target - contact_position
	var incoming_vector := contact_position - serve_origin
	var movement_direction := movement_vector.normalized() \
		if movement_vector.length() > 0.008 else desired_vector.normalized()
	var desired_direction := desired_vector.normalized()
	var incoming_direction := incoming_vector.normalized()
	var movement_alignment := clampf(
		(movement_direction.dot(desired_direction) + 1.0) * 0.5, 0.0, 1.0
	)
	var redirect_demand := clampf(
		absf(incoming_direction.angle_to(desired_direction)) / PI, 0.0, 1.0
	)
	var arrival_margin := float(arrival.get("arrival_margin", -0.5))
	var settle_factor := clampf((arrival_margin + 0.25) / 1.25, 0.0, 1.0)
	var edge_ratio := float(arrival.get("edge_ratio", 1.0))
	var body_alignment := clampf(
		movement_alignment * 0.42 + settle_factor * 0.38
		+ (1.0 - clampf(edge_ratio, 0.0, 1.2) / 1.2) * 0.20,
		0.0, 1.0,
	)
	var platform_feasibility := clampf(
		_rating(receiver, "reception") * 0.30
		+ _rating(receiver, "ball_control") * 0.18
		+ _rating(receiver, "reception_balance") * 0.15
		+ _rating(receiver, "reception_stability") * 0.14
		+ body_alignment * 0.18
		+ settle_factor * 0.12
		- redirect_demand * 0.08
		- serve_force * (1.0 - _rating(receiver, "reception_stability")) * 0.16,
		0.0, 1.0,
	)
	var execution := clampf(
		platform_feasibility * 0.66 + reception_quality * 0.34, 0.0, 1.0
	)
	var error_scale := pow(1.0 - execution, 1.35)
	var perpendicular := Vector2(-desired_direction.y, desired_direction.x)
	var directional_error := rng.randf_range(-0.30, 0.30) * error_scale
	var depth_error := rng.randf_range(-0.24, 0.24) * error_scale
	var destination := desired_target \
		+ perpendicular * directional_error + desired_direction * depth_error
	if execution < 0.18:
		destination += Vector2(
			rng.randf_range(-0.25, 0.25), rng.randf_range(-0.04, 0.18)
		)
	destination = Vector2(
		clampf(destination.x, 0.02, 0.98), clampf(destination.y, 0.51, 0.98)
	)
	var pass_distance := CoverageModel.court_distance_meters(
		contact_position, destination
	)
	var flight_time := clampf(
		0.38 + pass_distance / lerpf(5.2, 8.4, execution), 0.42, 1.25
	)
	var posture := "planted"
	if arrival_margin < 0.0:
		posture = "reaching"
	elif edge_ratio > 0.82:
		posture = "moving"
	elif body_alignment < 0.42:
		posture = "off-axis"
	return {
		"destination": destination,
		"body_alignment": body_alignment,
		"platform_feasibility": platform_feasibility,
		"contact_posture": posture,
		"trajectory": _ball_trajectory(
			"reception_pass", contact_position, destination,
			flight_time, lerpf(1.1, 2.8, execution), rally_clock
		),
	}


func _spatial_setter_choice(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	first_contact_player_id: int,
	preferred_setter: VolleyballPlayer,
	target: Vector2,
	available_time: float,
) -> Dictionary:
	var best := {"player": preferred_setter, "start": target, "travel_time": 4.0}
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null or candidate.id == first_contact_player_id:
			continue
		var start: Vector2 = live_positions.get(
			candidate.id, CourtConstants.slot_position(slot_number)
		)
		var travel_time := _movement_time(candidate, start, target, "transition")
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var duty := str(assignment.second_contact_responsibility) \
			if assignment != null else "No second-contact duty"
		var duty_bonus := 0.0
		match duty:
			"Primary emergency setter": duty_bonus = 0.34
			"Secondary emergency setter": duty_bonus = 0.18
			"Stay available to attack": duty_bonus = -0.16
			"No second-contact duty": duty_bonus = -0.24
		if candidate.id == lineup.active_setter_id():
			duty_bonus += 0.46
		elif candidate == preferred_setter:
			duty_bonus += 0.20
		var arrival_score := clampf((available_time - travel_time) / 1.2, -1.0, 1.0)
		var score := arrival_score * 0.52 \
			+ _rating(candidate, "set_accuracy") * 0.28 \
			+ _rating(candidate, "decision_making") * 0.12 + duty_bonus
		if score > best_score:
			best_score = score
			best = {"player": candidate, "start": start, "travel_time": travel_time}
	return best


func _second_contact_setter(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	first_contact_player_id: int,
) -> VolleyballPlayer:
	var regular_setter := _player_by_id(players, lineup.active_setter_id())
	if regular_setter != null and regular_setter.id != first_contact_player_id:
		return regular_setter
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null or candidate.id == first_contact_player_id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.second_contact_responsibility) \
			if assignment != null else "No second-contact duty"
		var responsibility_bonus := 0.0
		match responsibility:
			"Primary emergency setter":
				responsibility_bonus = 0.42
			"Secondary emergency setter":
				responsibility_bonus = 0.24
			"Stay available to attack":
				responsibility_bonus = -0.10
			"No second-contact duty":
				responsibility_bonus = -0.22
		var score := _rating(candidate, "set_accuracy") * 0.44 \
			+ _rating(candidate, "ball_control") * 0.28 \
			+ _rating(candidate, "decision_making") * 0.16 \
			+ responsibility_bonus
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _home_block_deflection_target(
	original_target: Vector2,
	attack_x: float,
	block_quality: float,
	outcome: String,
	relationship: String,
) -> Vector2:
	if outcome == "touch":
		return Vector2(
			clampf(attack_x + rng.randf_range(-0.16, 0.16), 0.08, 0.92),
			rng.randf_range(0.58, lerpf(0.82, 0.69, block_quality)),
		)
	var funnel_x := 0.50
	if relationship == "Defend Line":
		funnel_x = 0.35 if attack_x < 0.5 else 0.65
	elif relationship == "Defend Cross":
		funnel_x = 0.72 if attack_x < 0.5 else 0.28
	return Vector2(
		clampf(lerpf(original_target.x, funnel_x, 0.26), 0.08, 0.92),
		clampf(original_target.y + 0.02, 0.54, 0.94),
	)


func _resolve_attack_coverage(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	blocked_hitter: VolleyballPlayer,
	target: Vector2,
	block_quality: float,
) -> Dictionary:
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null or candidate.id == blocked_hitter.id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.attack_coverage_responsibility) \
			if assignment != null else "Cover nearest attacker"
		var start := CourtConstants.slot_position(slot_number)
		if defensive_plan != null:
			start = defensive_plan.defender_position(candidate.id, start)
		start = live_positions.get(candidate.id, start)
		var proximity := 1.0 - clampf(
			CoverageModel.court_distance_meters(start, target) / 9.0, 0.0, 1.0
		)
		var responsibility_bonus := 0.0
		match responsibility:
			"Cover nearest attacker":
				responsibility_bonus = proximity * 0.20
			"Cover assigned hitter":
				responsibility_bonus = 0.13
			"Take second contact":
				responsibility_bonus = 0.07
			"Release for transition":
				responsibility_bonus = -0.14
		var deflection_priority := int(assignment.deflection_priority) \
			if assignment != null else 1
		var score := proximity * 0.42 \
			+ _rating(candidate, "ball_control") * 0.24 \
			+ _rating(candidate, "anticipation") * 0.18 \
			+ responsibility_bonus + float(deflection_priority - 1) * 0.045
		if score > best_score:
			best = candidate
			best_score = score
	if best == null:
		return {"player": null, "quality": 0.0, "success": false}
	var quality := clampf(
		best_score - block_quality * 0.22 + rng.randf_range(-0.10, 0.10),
		0.0, 1.0,
	)
	return {"player": best, "quality": quality, "success": quality >= 0.32}


func _finish_serve_error(result: Resource, server_name: String) -> Resource:
	return _finish(result, "serve_error", true, -1, {"server": server_name})


func _finish(
	result: Resource,
	outcome: String,
	home_won: bool,
	decisive_actor_id: int,
	values: Dictionary,
	explanation_key: String = "",
) -> Resource:
	result.home_team_won = home_won
	result.terminal_outcome = outcome
	result.decisive_actor_id = decisive_actor_id
	var chosen_key := explanation_key if not explanation_key.is_empty() else outcome
	result.explanation = ExplanationText.explanation(chosen_key, values)
	var end_position := Vector2(0.5, 0.90) if home_won else Vector2(0.5, 0.12)
	_add_event(result, RallyEventModel.EventType.POINT, decisive_actor_id,
		"Home" if home_won else "Opponent", end_position, end_position,
		home_won, 1.0, ExplanationText.headline(outcome), result.explanation)
	result.analysis = _build_rally_analysis(result)
	if shadow_reception_trace != null:
		var existing_rollout: Dictionary = shadow_reception_trace.summary.get(
			"reception_rollout", {}
		)
		if str(existing_rollout.get("selected_source", "official")) == "official":
			existing_rollout["selected_event_count"] = result.events.size()
			existing_rollout["official_identity_preserved"] = true
			shadow_reception_trace.summary["reception_rollout"] = existing_rollout
		shadow_reception_trace.summary["serve_to_set_comparison"] = \
			RallyShadowComparisonModel.compare_serve_to_set(
				result.events, shadow_reception_trace.summary
			)
		if not shadow_reception_trace.summary.has("reception_rollout"):
			var rollout := RallyRolloutPolicyModel.select_reception_source(
				result.events, shadow_reception_trace.summary
			)
			rollout.erase("selected_events")
			rollout.erase("selected_reception")
			shadow_reception_trace.summary["reception_rollout"] = rollout
		result.analysis["shadow_reception"] = shadow_reception_trace.to_dict()
	_finalize_rally_timeline(result)
	return result


func _build_rally_analysis(result: Resource) -> Dictionary:
	var attack_types: Array[String] = []
	var directions: Array[String] = []
	var longest_movement := 0.0
	var lowest_arrival_margin := 99.0
	var blocker_read_values: Array[float] = []
	for event_resource in result.events:
		var event: Resource = event_resource
		if int(event.event_type) == RallyEventModel.EventType.ATTACK:
			var attack_type := str(event.metadata.get("attack_type", "Attack"))
			if attack_type not in attack_types:
				attack_types.append(attack_type)
			var direction := str(event.metadata.get("attack_direction", ""))
			if not direction.is_empty() and direction not in directions:
				directions.append(direction)
		longest_movement = maxf(longest_movement, float(event.metadata.get("movement_duration", 0.0)))
		if event.metadata.has("arrival_margin"):
			lowest_arrival_margin = minf(lowest_arrival_margin, float(event.metadata.arrival_margin))
		if event.metadata.has("read_quality"):
			blocker_read_values.append(float(event.metadata.read_quality))
	var average_read := -1.0
	if not blocker_read_values.is_empty():
		average_read = 0.0
		for value in blocker_read_values:
			average_read += value
		average_read /= blocker_read_values.size()
	return {"contacts": result.events.size() - 1,
		"attack_types": attack_types, "directions": directions,
		"longest_movement": longest_movement,
		"lowest_arrival_margin": lowest_arrival_margin if lowest_arrival_margin < 90.0 else 0.0,
		"average_block_read": average_read}


func _finalize_rally_timeline(result: Resource) -> void:
	_ensure_event_trajectories(result)
	var timeline := 0.0
	for event_resource in result.events:
		var event: Resource = event_resource
		var metadata: Dictionary = event.metadata
		var requested_time := float(metadata.get("event_time", timeline))
		timeline = maxf(timeline, requested_time)
		var movement_duration := float(metadata.get("movement_duration", 0.0))
		var flight_duration := float(metadata.get("flight_time", 0.0)) \
			if int(event.event_type) == RallyEventModel.EventType.SERVE else 0.0
		var trajectory_data: Dictionary = metadata.get("outgoing_trajectory", {})
		var trajectory_duration := float(trajectory_data.get("duration", 0.0))
		var default_duration := 0.12
		match int(event.event_type):
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				default_duration = 0.34
			RallyEventModel.EventType.SET:
				default_duration = 0.28
			RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK:
				default_duration = 0.24
			RallyEventModel.EventType.POINT:
				default_duration = 0.10
		var duration := maxf(
			default_duration,
			maxf(movement_duration, maxf(flight_duration, trajectory_duration))
		)
		metadata["event_time"] = timeline
		metadata["event_duration"] = duration
		event.metadata = metadata
		timeline += duration


func _ensure_event_trajectories(result: Resource) -> void:
	for event_index in range(result.events.size()):
		var event: Resource = result.events[event_index]
		if event.event_type == RallyEventModel.EventType.POINT \
				or event.metadata.has("outgoing_trajectory"):
			continue
		var start: Vector2 = event.start_position
		var end: Vector2 = event.end_position
		if event.event_type == RallyEventModel.EventType.BLOCK \
				and event.metadata.has("deflection_target"):
			end = Vector2(event.metadata.deflection_target)
		var flight_time := float(event.metadata.get("flight_time", 0.0))
		if flight_time <= 0.0:
			match int(event.event_type):
				RallyEventModel.EventType.SERVE: flight_time = 0.72
				RallyEventModel.EventType.RECEPTION: flight_time = 0.62
				RallyEventModel.EventType.SET: flight_time = 0.72
				RallyEventModel.EventType.ATTACK: flight_time = 0.42
				RallyEventModel.EventType.BLOCK: flight_time = 0.24
				RallyEventModel.EventType.DEFENSE: flight_time = 0.58
				_: continue
		var apex := 0.5
		match int(event.event_type):
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				apex = 1.8
			RallyEventModel.EventType.SET:
				apex = 2.4
		event.metadata["outgoing_trajectory"] = _ball_trajectory(
			event.type_name().to_lower(), start, end, flight_time, apex,
			float(event.metadata.get("event_time", 0.0))
		)


func _add_event(
	result: Resource,
	event_type: int,
	actor_id: int,
	actor_name: String,
	start: Vector2,
	end: Vector2,
	success: bool,
	quality: float,
	headline: String,
	detail: String,
	metadata: Dictionary = {},
) -> void:
	var event: Resource = RallyEventModel.new()
	event.sequence = result.events.size()
	event.event_type = event_type
	event.actor_id = actor_id
	event.actor_name = actor_name
	event.start_position = start
	event.end_position = end
	event.success = success
	event.quality = quality
	event.headline = headline
	event.detail = detail
	event.metadata = metadata.duplicate(true)
	result.events.append(event)


func _opponent_block_adaptation_bonus(
	opponent_team: Resource,
	lane: String,
	tempo: int,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 0.0
	if opponent_team.anticipated_lane() == lane:
		pattern_match += 0.65
	if opponent_team.anticipated_tempo() == tempo:
		pattern_match += 0.35
	return opponent_team.block_bonus() * pattern_match * 0.12


func _opponent_floor_defense_adaptation_bonus(
	opponent_team: Resource,
	lane: String,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 1.0 if opponent_team.anticipated_lane() == lane else 0.0
	return opponent_team.floor_defense_bonus() * pattern_match * 0.12


func _opponent_serve_receive_adaptation_bonus(
	opponent_team: Resource,
	target: String,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 1.0 if opponent_team.anticipated_serve_target() == target else 0.0
	return opponent_team.serve_receive_bonus() * pattern_match * 0.12


func _opponent_attack_type(target: Vector2) -> String:
	if target.y < 0.80:
		return "Short tip"
	if target.x < 0.38 or target.x > 0.62:
		return "Line attack"
	return "Seam attack"


func _defensive_responsibility_fit(
	defensive_plan: Resource,
	player_id: int,
	target: Vector2,
	attack_type: String,
) -> float:
	if defensive_plan == null:
		return 0.0
	var assignment: Resource = defensive_plan.assignment_for(player_id)
	if assignment == null:
		return -0.035
	var fit := 0.0
	if attack_type == "Short tip" and "Tip" in str(assignment.short_ball_responsibility):
		fit += 0.035 + float(assignment.short_ball_priority) * 0.015
	elif attack_type == "Seam attack" and "seam" in str(assignment.seam_responsibility).to_lower():
		fit += 0.045
	elif attack_type == "Line attack" and "Perimeter" in str(assignment.base_responsibility):
		fit += 0.035
	if defensive_plan.floor_system == "Perimeter" \
			and "Perimeter" in str(assignment.base_responsibility):
		fit += 0.015
	elif defensive_plan.floor_system == "Middle-Up" \
			and "Middle-up" in str(assignment.base_responsibility):
		fit += 0.02
	elif defensive_plan.floor_system == "Rotation Defense" \
			and "Rotation" in str(assignment.base_responsibility):
		fit += 0.02
	var base_position: Vector2 = defensive_plan.defender_position(player_id, target)
	fit += lerpf(-0.025, 0.025, 1.0 - clampf(base_position.distance_to(target), 0.0, 1.0))
	return clampf(fit, -0.04, 0.08)


func _responsibility_phrase(
	defensive_plan: Resource,
	player_id: int,
	attack_type: String,
) -> String:
	if defensive_plan == null:
		return "No saved responsibility shaped the contact."
	var assignment: Resource = defensive_plan.assignment_for(player_id)
	if assignment == null:
		return "The defender covered outside a saved responsibility."
	return "%s met the %s responsibility behind the %s." % [
		str(assignment.base_responsibility), attack_type.to_lower(),
		str(defensive_plan.block_strategy).to_lower(),
	]


func _choose_assignment(
	play: OffensivePlay,
	follow_play: bool,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int = -1,
) -> HitterAssignment:
	if play == null or play.assignments.is_empty():
		return null
	if follow_play:
		var primary := play.assignment_for_player(play.primary_hitter_id)
		if primary != null and primary.player_id != excluded_player_id:
			return primary
	var candidates: Array[HitterAssignment] = []
	for assignment in play.assignments:
		if assignment.player_id != excluded_player_id \
				and _player_by_id(players, assignment.player_id) != null \
				and lineup.slot_for_player(assignment.player_id) >= 0:
			candidates.append(assignment)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## A copy of the called assignment at a tempo the setter can actually run. The
## original play resource is left untouched: the offence still called what it
## called, and the record should show the call and the downgrade separately.
func _downgraded_assignment(
	assignment: HitterAssignment,
	tempo: int,
) -> HitterAssignment:
	if assignment == null:
		return assignment
	var adjusted := assignment.duplicate(true) as HitterAssignment
	adjusted.tempo = clampi(tempo, 0, 3)
	return adjusted


func _fallback_hitter(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int = -1,
) -> VolleyballPlayer:
	var outside_candidates: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and candidate.id != excluded_player_id \
				and candidate.position_role == "Outside Hitter" \
				and CourtConstants.is_front_row_slot(slot_number):
			outside_candidates.append(candidate)
	if not outside_candidates.is_empty():
		var nearest := outside_candidates[0]
		var nearest_distance := 10.0
		for candidate in outside_candidates:
			var slot_number := lineup.slot_for_player(candidate.id)
			var position := CourtConstants.slot_position(slot_number)
			var pin_x := 0.12 if position.x <= 0.5 else 0.88
			var distance := absf(position.x - pin_x)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
		return nearest
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		if player != null and player.id != excluded_player_id:
			return player
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null and player.id != excluded_player_id \
				and lineup.is_attack_eligible(player.id) \
				and player.position_role != "Libero":
			return player
	return null


func _best_blocker(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> VolleyballPlayer:
	var best: VolleyballPlayer
	var best_score := -1
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		if player == null:
			continue
		var score := player.block_timing + player.jump_reach
		if score > best_score:
			best = player
			best_score = score
	return best


## `set_flight_time` is the opponent set's own flight, for the same reason the
## opponent block uses it: it is how long home blockers actually have.
## The home wall as it forms, before the swing it will face is scored. Both
## sides now form first and contest afterwards, through the same
## `_contest_block()`: the home block used to carry its own copy of the margins,
## and when the opponent side was retuned the two immediately diverged -- the
## home block stuffed 36 attacks in a sweep where the opponent block stuffed
## none. A second copy of a contest is a second balance to maintain.
func _form_home_block(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	opponent_setter_x: float,
	set_flight_time: float,
) -> Dictionary:
	var front_blockers: Array[VolleyballPlayer] = []
	var setter_pull := {}
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		var assignment: Resource = defensive_plan.assignment_for(player_id) \
			if defensive_plan != null else null
		if player != null and (assignment == null or bool(assignment.block_participation)):
			front_blockers.append(player)
			var slot_number := lineup.slot_for_player(player.id)
			var start: Vector2 = live_positions.get(
				player.id, CourtConstants.slot_position(slot_number)
			)
			var discipline := clampf(
				(_rating(player, "tactical_discipline") * 0.65
				+ _rating(player, "anticipation") * 0.35), 0.0, 1.0
			)
			var pull_weight := (1.0 - discipline) * 0.18
			var pulled_x := lerpf(start.x, opponent_setter_x, pull_weight)
			setter_pull[player.id] = absf(pulled_x - start.x)
			live_positions[player.id] = Vector2(pulled_x, start.y)
	if front_blockers.is_empty():
		return {
			"primary": null, "assist": null, "primary_close": 0.0,
			"assist_close": 0.0, "quality": 0.0, "outcome": "miss",
			"coverage_segments": [], "setter_pull": setter_pull,
		}
	var primary: VolleyballPlayer
	var primary_distance := 1000.0
	for candidate in front_blockers:
		var slot_number := lineup.slot_for_player(candidate.id)
		var candidate_x := CourtConstants.slot_position(slot_number).x
		var distance := absf(candidate_x - attack_x)
		if distance < primary_distance:
			primary = candidate
			primary_distance = distance
	## How long the blockers actually have: the set's own flight time, which the
	## kinematics solver already produced from real distance and launch angle.
	##
	## This used to be `0.30 + tempo * 0.045 + (1 - set_quality) * 0.18` -- a
	## table that gave a middle blocker 0.30 s of movement to cover 2.9 m of net,
	## which is physically impossible, so double blocks formed in 1% of rallies
	## and tempo could not change the block. Flight time already encodes tempo: a
	## quick set lands in a fraction of the time a high ball takes, so the middle
	## closes on a high ball and does not on a quick one. That is the whole
	## tempo-versus-block dynamic, and it now falls out of the ball's own physics
	## rather than a constant.
	var close_time := maxf(set_flight_time, 0.0) \
		+ (1.0 - set_quality) * 0.10
	var read_total := 0.0
	for reader in front_blockers:
		read_total += _blocker_read_quality(reader, tempo, set_quality, opponent_setter_x)
	var read_quality := read_total / maxf(float(front_blockers.size()), 1.0)
	close_time += lerpf(-0.09, 0.09, read_quality)
	var strategy := str(defensive_plan.block_strategy) if defensive_plan != null \
		else "Read Block"
	var pin_attack := attack_x <= 0.34 or attack_x >= 0.66
	if strategy == "Commit Pin":
		close_time += 0.10 if pin_attack else -0.08
	elif strategy == "Commit Middle":
		close_time += 0.10 if not pin_attack else -0.09
	var primary_close := _blocker_close_fraction(
		primary, lineup, attack_x, close_time
	)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var close_fraction := _blocker_close_fraction(
			candidate, lineup, attack_x, close_time
		)
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	var block_quality := _block_wall_quality(primary_skill, assist_skill)
	return {
		"primary": primary,
		"assist": assist,
		"primary_close": primary_close,
		"assist_close": assist_close,
		"quality": block_quality,
		"outcome": "miss",
		"coverage_segments": _home_block_segments(
			attack_x, primary, primary_close, assist, assist_close
		),
		"setter_pull": setter_pull,
		"read_quality": read_quality,
	}


func _blocker_read_quality(
	blocker: VolleyballPlayer,
	tempo: int,
	set_quality: float,
	opponent_setter_x: float,
) -> float:
	var cue_clarity := (1.0 - set_quality) * 0.18 \
		+ absf(opponent_setter_x - 0.5) * 0.16 \
		+ float(clampi(tempo, 0, 3)) * 0.025
	return clampf(
		_rating(blocker, "anticipation") * 0.34
		+ _rating(blocker, "court_vision") * 0.25
		+ _rating(blocker, "decision_making") * 0.21
		+ _rating(blocker, "tactical_discipline") * 0.20
		+ cue_clarity - rng.randf_range(0.0, 0.08), 0.0, 1.0
	)


func _blocker_close_fraction(
	blocker: VolleyballPlayer,
	lineup: RotationLineup,
	attack_x: float,
	available_time: float,
) -> float:
	if blocker == null:
		return 0.0
	var slot_number := lineup.slot_for_player(blocker.id)
	var start_position: Vector2 = live_positions.get(
		blocker.id, CourtConstants.slot_position(slot_number)
	)
	var start_x := start_position.x
	var anticipation := _rating(blocker, "anticipation")
	var reaction_delay := lerpf(0.34, 0.12, anticipation)
	var movement_time := maxf(available_time - reaction_delay, 0.0)
	## Blocking closes through the shared locomotion model like every other
	## movement in the engine. It used to carry its own `lerpf(1.25, 4.40,
	## lateral_speed)` -- a fourth private copy of the speed curve -- so none of
	## the stride, cadence or limb-turnover work reached blocking at all. Side is
	## irrelevant here: `movement_profile()` reads the player, facing and
	## velocity, never which half of the court they stand on.
	var closing_actor := RallyPlayerState.create(
		blocker, &"home", slot_number, start_position
	)
	## A blocker covers some of the lane with their arms without moving their
	## feet, but nothing like the 0.72 m this used to grant. That constant
	## swamped the 0.135 s a slow tempo actually buys the block.
	var lane_delta := attack_x - start_x
	var footwork_x := start_x + signf(lane_delta) * maxf(
		absf(lane_delta) - BLOCK_LATERAL_REACH_METERS / 9.0, 0.0
	)
	## How long the close actually takes, through the shared model, from a
	## standstill.
	##
	## This used to be `maximum_speed * movement_time`: the blocker left the
	## ready stance already at top speed, never decelerated, and was credited
	## with shuffling until the instant of contact. Every close in the game
	## resolved at exactly 1.0 as a result -- a middle covered three metres to
	## the pin and sealed it every time, so "late block" described nothing.
	## Acceleration comes from the same traversal solver every other movement
	## uses, and the block jump has to be loaded before the ball arrives rather
	## than after it.
	var required_seconds := RallyMovementSystemModel.traversal_seconds(
		closing_actor,
		Vector2(footwork_x, start_position.y),
		RallyPlayerState.MovementMode.BLOCK_CLOSE,
	)
	var usable_time := maxf(movement_time - BLOCK_PLANT_SECONDS, 0.0)
	return clampf(
		1.0 - maxf(required_seconds - usable_time, 0.0) / BLOCK_CLOSE_FAILURE_SECONDS,
		0.0, 1.0,
	)


## How well this hitter's run-up served the swing, as a fraction of an ideal
## approach. Their own approach timing is part of it: the profile measures the
## run-up they produced, not how well they habitually produce one.
func _approach_execution_fit(
	hitter: VolleyballPlayer,
	approach_profile: Dictionary,
) -> float:
	return clampf(
		_rating(hitter, "approach_timing") * 0.24
		+ float(approach_profile.get("runup_quality", 0.5)) * 0.48
		+ float(approach_profile.get("lateral_control", 0.5)) * 0.16
		+ float(approach_profile.get("approach_speed_fraction", 0.5)) * 0.12,
		0.0, 1.0,
	)


## One swing, wherever in the rally it happens.
##
## The engine carried three copies of this. The home attack summed 1.50 of
## positive weight across ratings, approach and set quality; the opponent attack
## used `attack_power * 0.62 + set_quality * 0.20 + 0.08`; the continuation used
## a third set of weights again. All three were then compared against the same
## block contest and the same error threshold, which only made sense for one of
## them at a time.
##
## Capability is what the hitter brings, normalised to a fraction of an ideal
## hitter. Opportunity is what the rally handed them, and it is a **product**:
## a great hitter off a terrible set, with no run-up, arriving late, should put
## the ball in the stands. Summing those terms instead put roughly 0.75 of
## rating weight under every swing in the game, so attack quality never fell
## below 0.321 against a 0.29 error threshold and the engine produced no attack
## errors at all -- not few, none, across 180 rallies.
func _attack_execution(
	hitter: VolleyballPlayer,
	set_quality: float,
	approach_fit: float,
	arrival_margin: float,
	tempo_demand: float,
	block_pressure: float,
	familiarity_bonus: float = 0.0,
) -> float:
	if hitter == null:
		return 0.0
	var capability := clampf(
		_rating(hitter, "attack_accuracy") * ATTACK_ACCURACY_WEIGHT
		+ _power_rating(hitter, "attack_power") * ATTACK_POWER_WEIGHT
		+ _rating(hitter, "decision_making") * ATTACK_DECISION_WEIGHT
		+ familiarity_bonus,
		0.0, 1.0,
	)
	## Arriving early is worth nothing extra -- the ball still has to come down
	## -- so this saturates at the margin rather than rewarding it.
	var timing := clampf(
		(arrival_margin + LATE_ARRIVAL_SECONDS) / LATE_ARRIVAL_SECONDS, 0.0, 1.0
	)
	var opportunity := (
		1.0 - SET_OPPORTUNITY_WEIGHT * (1.0 - clampf(set_quality, 0.0, 1.0))
	) * (
		1.0 - APPROACH_OPPORTUNITY_WEIGHT * (1.0 - clampf(approach_fit, 0.0, 1.0))
	) * (
		1.0 - TIMING_OPPORTUNITY_WEIGHT * (1.0 - timing)
	) * (
		1.0 - clampf(tempo_demand, 0.0, 0.60)
	)
	return clampf(capability * opportunity - block_pressure, 0.0, 1.0)


## The wall two blockers make, from what each of them brings.
##
## Written out twice, once per side of the net, until this: `assist_close` was
## already inside `assist_skill` and was multiplied in again, which squared the
## assist's contribution and capped even a perfect unassisted blocker at 0.67.
##
## The assist closes part of what the primary leaves open rather than adding a
## flat share, so a second blocker matters most when the first is beaten and
## least when they already sealed it. That is the shape of a real double block,
## and it makes beating one blocker ordinary while a well-formed double is the
## thing a hitter genuinely has to solve.
func _block_wall_quality(primary_skill: float, assist_skill: float) -> float:
	var solo := clampf(primary_skill, 0.0, 1.0) * BLOCK_SOLO_SHARE
	return clampf(
		solo + (1.0 - solo) * clampf(assist_skill, 0.0, 1.0) * BLOCK_ASSIST_SHARE,
		0.05, 0.98,
	)


func _block_contact_skill(blocker: VolleyballPlayer, close_fraction: float) -> float:
	if blocker == null:
		return 0.0
	var technique := clampf(
		_rating(blocker, "block_timing") * 0.46
		+ _available_jump_rating(blocker) * 0.29
		+ _body_reach_rating(blocker) * 0.15
		+ _rating(blocker, "anticipation") * 0.10,
		0.0, 1.0,
	)
	## Closing multiplies the block rather than adding to it. As a 0.14 additive
	## term a blocker who reached only a fifth of the lane still scored 84% of a
	## sealed block's quality, so making the close physical changed the number
	## and not the outcome. A blocker who did not get there does not block.
	return clampf(
		technique * lerpf(BLOCK_UNCLOSED_SHARE, 1.0, clampf(close_fraction, 0.0, 1.0)),
		0.05, 0.98,
	)


func _block_coverage_segment(
	center_x: float,
	blocker: VolleyballPlayer,
	close_fraction: float,
	completeness: float,
) -> Dictionary:
	var wingspan_width := clampf(
		(blocker.wingspan_cm if blocker != null else 190.0) / 900.0,
		0.16, 0.27,
	)
	var effective_width := wingspan_width * lerpf(0.42, 1.0, close_fraction)
	return {
		"x_min": clampf(center_x - effective_width * 0.5, 0.02, 0.98),
		"x_max": clampf(center_x + effective_width * 0.5, 0.02, 0.98),
		"completeness": clampf(completeness * close_fraction, 0.0, 1.0),
	}


func _home_block_segments(
	attack_x: float,
	primary: VolleyballPlayer,
	primary_close: float,
	assist: VolleyballPlayer,
	assist_close: float,
) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	segments.append(_block_coverage_segment(
		attack_x, primary, primary_close, _block_contact_skill(primary, primary_close)
	))
	if assist != null:
		segments.append(_block_coverage_segment(
			attack_x, assist, assist_close,
			_block_contact_skill(assist, assist_close)
		))
	return segments


func _best_home_server(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> VolleyballPlayer:
	# Service ownership follows rotational zone 1. The server's attributes still
	# determine quality; the strongest server cannot replace the legal server.
	return _player_by_id(players, lineup.player_at_slot(1))


func _hit_type(assignment: HitterAssignment, hitter: VolleyballPlayer) -> String:
	if assignment.lane in ["Front Quick", "Right Quick"]:
		return "Quick attack"
	if assignment.lane == "Pipe":
		return "Pipe attack"
	if assignment.tempo == 3:
		return "High-ball swing"
	if hitter.attack_power >= 82:
		return "Power swing"
	return "Tempo swing"


func _fallback_assignment(hitter: VolleyballPlayer, lineup: RotationLineup) -> HitterAssignment:
	var assignment := HitterAssignment.new()
	assignment.player_id = hitter.id
	assignment.start_position = CourtConstants.slot_position(
		lineup.slot_for_player(hitter.id)
	)
	assignment.lane = "Left Pin" if assignment.start_position.x <= 0.5 \
		else "Right Pin"
	assignment.tempo = 3
	return assignment


func _assignment_from_dict(data: Dictionary) -> HitterAssignment:
	if data.is_empty():
		return null
	var assignment := HitterAssignment.new()
	assignment.player_id = int(data.get("player_id", -1))
	assignment.start_position = Vector2(data.get(
		"perceived_start_position", Vector2(0.5, 0.75)
	))
	assignment.lane = str(data.get("lane", "Left Pin"))
	assignment.tempo = clampi(int(data.get("tempo", 2)), 0, 3)
	assignment.priority = clampi(int(data.get("priority", 1)), 1, 6)
	assignment.is_decoy = false
	return assignment


func _lineup_players(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null:
			result.append(player)
	return result


func _serve_landing_point(
	target_name: String,
	server: VolleyballPlayer,
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	var home_y := 0.84 if landing_on_home_side else 0.16
	var short_y := 0.67 if landing_on_home_side else 0.33
	var intended := Vector2(0.20, home_y)
	match target_name:
		"Zone 1":
			intended = Vector2(0.80, home_y)
		"Short Middle":
			intended = Vector2(0.50, short_y)
		"Weak Passer":
			intended = _weak_passer_target(home_players, lineup, landing_on_home_side)
		_:
			intended = Vector2(0.20, home_y)
	var accuracy := _rating(server, "serve_placement")
	var deviation := lerpf(0.105, 0.018, accuracy)
	var min_y := 0.54 if landing_on_home_side else 0.04
	var max_y := 0.96 if landing_on_home_side else 0.46
	return Vector2(
		clampf(intended.x + rng.randf_range(-deviation, deviation), 0.06, 0.94),
		clampf(intended.y + rng.randf_range(-deviation * 0.65, deviation * 0.65), min_y, max_y),
	)


func _weak_passer_target(
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	if landing_on_home_side and lineup != null:
		var weakest: VolleyballPlayer = null
		var weakest_slot := 5
		for slot_number in [5, 6, 1]:
			var candidate: VolleyballPlayer
			for player_resource in home_players:
				var player := player_resource as VolleyballPlayer
				if player.id == lineup.player_at_slot(slot_number):
					candidate = player
					break
			if candidate != null and (weakest == null or candidate.reception < weakest.reception):
				weakest = candidate
				weakest_slot = slot_number
		return CourtConstants.slot_position(weakest_slot)
	return Vector2(0.78, 0.16)


## Intended shot shape for a serve: how lofted the launch is, by style. This is
## the free "tempo/force intent" input; RallyKinematics.solve_launch_arc()
## derives the resulting duration and apex from it and the real distance to
## the landing point, rather than either being chosen directly.
func _serve_launch_angle_degrees(server: VolleyballPlayer, serve_quality: float) -> float:
	var angle_min := 16.0
	var angle_max := 24.0
	match server.primary_serve_style:
		"Jump Topspin":
			angle_min = 10.0
			angle_max = 16.0
		"Hybrid":
			angle_min = 12.0
			angle_max = 18.0
		"Jump Float":
			angle_min = 14.0
			angle_max = 20.0
		"Sky Ball":
			angle_min = 55.0
			angle_max = 65.0
	return _jittered_launch_angle(
		angle_min, angle_max, _power_rating(server, "serve_power"), serve_quality
	)


func _serve_style_proficiency(server: VolleyballPlayer) -> float:
	var scores := server.serve_style_proficiencies
	if scores.is_empty():
		scores = AttributeProfiles.serve_style_proficiencies(server)
	return clampf(float(scores.get(server.primary_serve_style, 50)) / 100.0, 0.01, 1.0)


## Intended shot shape for a set, by tempo. `tempo` is already the real
## tactical input (chosen by the called offensive play, not hardcoded); this
## only changes what a tempo *means physically*, from a table lookup to a
## shape that a real distance is then flown at.
func _set_launch_angle_degrees(
	setter: VolleyballPlayer, tempo: int, set_quality: float
) -> float:
	var angle_min := 6.0
	var angle_max := 10.0
	match clampi(tempo, 0, 3):
		1:
			angle_min = 12.0
			angle_max = 18.0
		2:
			angle_min = 25.0
			angle_max = 35.0
		3:
			angle_min = 45.0
			angle_max = 55.0
	var touch := (_rating(setter, "tempo_control") + _rating(setter, "hand_control")) * 0.5
	return _jittered_launch_angle(angle_min, angle_max, touch, set_quality)


## Intended shot shape for an attack, by the hitter's chosen action. Covers
## both the home-side hit_type vocabulary (_hit_type()) and the opponent-side
## attack_type vocabulary (_opponent_attack_type()), since both currently feed
## the same trajectory construction.
func _attack_launch_angle_degrees(
	hitter: VolleyballPlayer, attack_type: String, attack_quality: float
) -> float:
	var angle_min := 8.0
	var angle_max := 12.0
	match attack_type:
		"Quick attack":
			angle_min = 5.0
			angle_max = 8.0
		"Power swing":
			angle_min = 6.0
			angle_max = 10.0
		"Pipe attack", "Line attack", "Seam attack":
			angle_min = 8.0
			angle_max = 14.0
		"High-ball swing":
			angle_min = 10.0
			angle_max = 16.0
		"Controlled roll", "Roll shot":
			angle_min = 20.0
			angle_max = 30.0
		"Emergency tip", "Short tip":
			angle_min = 22.0
			angle_max = 32.0
	return _jittered_launch_angle(
		angle_min, angle_max, _power_rating(hitter, "attack_power"), attack_quality
	)


## Shared shape for every launch-angle helper above: a better-executed shot
## (higher rating) reliably flattens toward the harder-to-defend end of its
## action's range; a worse-executed one (lower quality) drifts away from
## whatever was intended, within the same safe range. Skill changes which
## angle is chosen; contact quality changes how well that choice is executed
## -- neither ever escapes the range RallyKinematics.solve_launch_arc() was
## calibrated against.
func _jittered_launch_angle(
	angle_min: float, angle_max: float, skill: float, quality: float
) -> float:
	var intended := lerpf(angle_max, angle_min, clampf(skill, 0.0, 1.0))
	var jitter := (1.0 - clampf(quality, 0.0, 1.0)) * (angle_max - angle_min) * 0.4
	return clampf(intended + rng.randf_range(-jitter, jitter), angle_min, angle_max)


func _nearest_reception_player(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	landing_point: Vector2,
) -> VolleyballPlayer:
	var zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	)
	return _nearest_zone_player(
		_lineup_players(players, lineup), zones, landing_point, true
	)


func _nearest_floor_defender(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	landing_point: Vector2,
) -> VolleyballPlayer:
	var zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	)
	var pursuit_candidates: Array[VolleyballPlayer] = []
	for candidate in _lineup_players(players, lineup):
		var assignment: Resource = defensive_plan.assignment_for(candidate.id)
		if assignment == null or bool(assignment.emergency_pursuit):
			pursuit_candidates.append(candidate)
	return _nearest_zone_player(
		pursuit_candidates, zones, landing_point, true
	)


func _nearest_zone_player(
	candidates: Array[VolleyballPlayer],
	zones: Dictionary,
	landing_point: Vector2,
	require_enabled: bool,
) -> VolleyballPlayer:
	var nearest: VolleyballPlayer
	var nearest_distance := 1000.0
	for candidate in candidates:
		var zone: Resource = zones.get(candidate.id) as Resource
		if zone == null or (require_enabled and not bool(zone.enabled)):
			continue
		var distance := CoverageModel.court_distance_meters(zone.center, landing_point)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest == null and not candidates.is_empty():
		nearest = candidates[0]
	return nearest


func _opponent_reception_coverage(opponent_team: Resource) -> Dictionary:
	var passers: Array[VolleyballPlayer] = []
	var zones := {}
	var outside_index := 0
	for player_resource in opponent_team.on_court_players():
		var player := player_resource as VolleyballPlayer
		if player.position_role not in ["Outside Hitter", "Libero"]:
			continue
		var zone: Resource = DefensiveZoneModel.new()
		zone.player_id = player.id
		zone.zone_type = DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		zone.radius_meters = 3.2
		zone.priority = 2
		if player.position_role == "Libero":
			zone.center = Vector2(0.50, 0.13)
			## The libero's skill already influences the claim. A blanket priority
			## advantage made them cross the full court ahead of a nearby outside.
			zone.radius_meters = 2.7
		else:
			zone.center = Vector2(0.20 if outside_index == 0 else 0.80, 0.16)
			outside_index += 1
		passers.append(player)
		zones[player.id] = zone
	return {"players": passers, "zones": zones}


func _arrival_phrase(arrival: Dictionary, arrived: bool, support_count: int) -> String:
	if not arrived:
		return "No assigned player could arrive before the ball landed."
	return "Arrived with %.2f m to spare; %d nearby teammate%s supported the zone." % [
		float(arrival.get("arrival_margin", 0.0)), support_count,
		"" if support_count == 1 else "s",
	]


func _receiver(players: Array[VolleyballPlayer], lineup: RotationLineup) -> VolleyballPlayer:
	var best: VolleyballPlayer = null
	for slot_number in [5, 6, 1]:
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and (best == null or candidate.reception > best.reception):
			best = candidate
	return best


func _best_positioned_defender(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	target: Vector2,
) -> VolleyballPlayer:
	if defensive_plan == null:
		return _receiver(players, lineup)
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null:
			continue
		var position: Vector2 = defensive_plan.defender_position(
			candidate.id, CourtConstants.slot_position(slot_number)
		)
		var proximity := 1.0 - clampf(position.distance_to(target), 0.0, 1.0)
		var score := proximity * 100.0 + candidate.anticipation * 0.35 \
			+ candidate.lateral_speed * 0.20
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _player_by_id(players: Array[VolleyballPlayer], player_id: int) -> VolleyballPlayer:
	for player in players:
		if player.id == player_id:
			return player
	return null


func _rating(player: VolleyballPlayer, property_name: String) -> float:
	if player == null:
		return 0.5
	var raw_rating := float(player.get(property_name)) / 100.0
	return clampf(
		raw_rating * (1.0 - player.fatigue * 0.18) + player.current_form * 0.06,
		0.05, 1.0,
	)


func _power_rating(player: VolleyballPlayer, property_name: String) -> float:
	if property_name == "attack_power":
		return clampf(float(player.usable_attack_power()) / 100.0 \
			* (1.0 - player.fatigue * 0.18) + player.current_form * 0.06, 0.05, 1.0)
	var base := _rating(player, property_name)
	var mass_bonus := clampf((player.mass_kg - 82.0) / 48.0, -0.50, 1.0) * 0.07
	return clampf(base + mass_bonus, 0.05, 1.0)


func _available_jump_rating(player: VolleyballPlayer) -> float:
	var maximum_jump := _rating(player, "jump_reach")
	var jump_access := lerpf(0.62, 1.0, _rating(player, "explosiveness"))
	return clampf(maximum_jump * jump_access, 0.05, 1.0)


func _body_reach_rating(player: VolleyballPlayer) -> float:
	var standing_reach := inverse_lerp(200.0, 275.0, player.standing_reach_cm())
	var wingspan := inverse_lerp(160.0, 225.0, player.wingspan_cm)
	return clampf(standing_reach * 0.68 + wingspan * 0.32, 0.05, 1.0)


func _quality_phrase(quality: float) -> String:
	if quality >= 0.72:
		return "Perfect pass; every attacker remains available."
	if quality >= 0.48:
		return "Playable pass with multiple options."
	if quality >= 0.25:
		return "The setter is pulled off the net."
	return "The offense cannot control the first contact."
