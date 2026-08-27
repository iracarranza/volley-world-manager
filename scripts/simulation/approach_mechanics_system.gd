class_name ApproachMechanicsSystem
extends RefCounted

const FeatureFlags := preload("res://scripts/simulation/rally_feature_flags.gd")
const RallyPlayerState := preload("res://scripts/models/rally_player_state.gd")
const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")
const RallyMovementModel := preload("res://scripts/simulation/rally_movement_system.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

## What a run-up has to deliver before a hitter can swing at full power, and
## before the whole shot menu is open to them. Named because the requirement
## table below has to agree with the profile that reports them; two copies of
## `0.48` in one file is how the block ended up with three contests.
const POWER_ACCESS_QUALITY_IN_SYSTEM: float = 0.48
const POWER_ACCESS_QUALITY_OUT_OF_SYSTEM: float = 0.52
const POWER_ACCESS_SPEED_FRACTION: float = 0.42
const POWER_ACCESS_LATERAL_CONTROL: float = 0.42
const FULL_MENU_QUALITY_IN_SYSTEM: float = 0.61
const FULL_MENU_QUALITY_OUT_OF_SYSTEM: float = 0.66
const FULL_MENU_LATERAL_CONTROL: float = 0.56

## What each attack family demands of the hitter and of the approach they got
## into it.
##
## **Capability is not permission.** `available_attack_families()` reports what
## a hitter can do cleanly; `attack_family_deficit()` reports how far outside
## that an attempt sits. Nothing here removes a swing from a hitter -- a player
## may attempt anything, and their attributes decide how it goes, not whether
## they are allowed. The second contact learned this first; this is the third
## contact's version of the same rule.
const ATTACK_FAMILY_REQUIREMENTS := {
	## Always available. A hitter with nothing left can always roll one over.
	"controlled_roll": {},
	"tip": {"rating": "finesse", "rating_floor": 45.0},
	"placed_attack": {
		"rating": "attack_accuracy", "rating_floor": 48.0,
		"lateral_control": 0.36, "arrival_margin": -0.12,
	},
	"power_attack": {
		"rating": "attack_power", "rating_floor": 52.0,
		"power_access": true, "arrival_margin": -0.06,
	},
	"tool_block": {
		"rating": "tooling", "rating_floor": 58.0,
		"runup_quality": 0.46, "lateral_control": 0.48,
	},
}

## Which family a named hit type belongs to, so the simulator's shot vocabulary
## and this system's capability vocabulary stay in one mapping rather than in a
## membership test written out at each call site.
const HIT_TYPE_FAMILY := {
	"Quick attack": "power_attack",
	"Power swing": "power_attack",
	"Tempo swing": "power_attack",
	"Pipe attack": "power_attack",
	"High-ball swing": "power_attack",
	"Controlled roll": "controlled_roll",
	"Emergency tip": "tip",
	"Short tip": "tip",
	"Tool attempt": "tool_block",
}

## Seconds of lateness that count as one full unit of shortfall, so a timing
## deficit is comparable with a rating or run-up deficit.
const ARRIVAL_DEFICIT_SCALE: float = 0.50


## Creates a decision-safe transition snapshot. A hitter releases only after
## recognizing that their current ball responsibility is finished; tactical
## duties can deliberately keep them available longer.
static func prepare_for_attack(
	state: RallyState,
	actor: RallyPlayerState,
	assignment: Dictionary,
	first_contact_player_id: int,
	set_contact_time: float,
	side: StringName = &"home",
) -> Dictionary:
	if state == null or actor == null or actor.player == null:
		return {"available": false}
	var reading := _reading_quality(actor.player)
	var recognition_delay := lerpf(0.30, 0.07, reading)
	var duty_delay := 0.0
	var release_reason := "recognized teammate ownership"
	var assignment_duty := ""
	var zone_priority := 0
	## `home_plan` is keyed by player id, and only home players appear in it.
	## Consulting it for an opponent works today only because the two id ranges
	## happen not to overlap, which is an assumption nothing enforces. Gate the
	## lookup on side so the coincidence can never become a duty leak.
	if side == &"home" and state.home_plan != null:
		var duty: Resource = state.home_plan.assignment_for(actor.player_id)
		if duty != null:
			assignment_duty = str(duty.attack_coverage_responsibility)
			var second_duty := str(duty.second_contact_responsibility)
			if "emergency setter" in second_duty.to_lower():
				duty_delay += 0.12
				release_reason = "held for emergency second contact"
			if bool(duty.emergency_pursuit):
				duty_delay += 0.05
			if assignment_duty == "Release for transition":
				duty_delay -= 0.08
				release_reason = "explicit transition release"
		var zone: Resource = state.home_plan.zone_for(
			actor.player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone != null and bool(zone.enabled):
			zone_priority = int(zone.priority)
			duty_delay += float(zone_priority) * 0.025
	if actor.player_id == first_contact_player_id:
		duty_delay += 0.18
		release_reason = "completed first contact"
	var release_time := state.simulation_time + maxf(
		recognition_delay + duty_delay, 0.02
	)
	var target := Vector2(assignment.get("target", Vector2(0.5, 0.53)))
	var start := approach_start_position(
		target, str(assignment.get("lane", "Left Pin")), side, null,
		APPROACH_DEPTH, int(assignment.get("tempo", 3)),
	)
	## An authored start is a requested runway mark, not a teleport.  It replaces
	## the derived mark as movement intent; `project_toward` below still decides
	## how much of that request the live body can physically reach in time.
	var authored_start: Variant = assignment.get("authored_start_position", null)
	if authored_start is Vector2:
		start = Vector2(authored_start)
		if side == &"opponent":
			start.y = 1.0 - start.y
	var preparation_time := maxf(set_contact_time - release_time, 0.0)
	## Run *through* the approach mark, not to it. This is the leg that ends
	## where the run-up begins, so stopping dead on arrival makes every hitter
	## re-accelerate from rest into their own swing -- which is exactly what was
	## happening, and why 83% of attack contacts were placed beyond reach.
	var projection := RallyMovementModel.project_toward(
		actor, start, preparation_time, RallyPlayerState.MovementMode.TRANSITION,
		true,
	)
	var prepared := projection.get("actor") as RallyPlayerState
	if prepared != null:
		prepared.intent = &"prepare_attack"
		prepared.intent_target = start
	return {
		"available": prepared != null,
		"actor": prepared,
		"release_time": release_time,
		"release_reason": release_reason,
		"recognition_delay_seconds": recognition_delay,
		"duty_delay_seconds": duty_delay,
		"defensive_duty": assignment_duty,
		"zone_priority": zone_priority,
		## Playback must render where the hitter physically ended up, not where
		## they were trying to get to. When preparation time is short (tight
		## tempo, contested duty) these two positions diverge, and showing the
		## aspirational mark would draw a run-up the player never actually made.
		"approach_start_position": prepared.position if prepared != null else start,
		## The ideal mark this player was working toward. Kept separately for
		## scouting/debug overlays ("missed their spot by 0.4m") without ever
		## feeding it into anything that draws a court position.
		"approach_target_position": start,
		"authored_start_requested": authored_start is Vector2,
		"preparation_time_seconds": preparation_time,
		"preparation_distance_meters": float(projection.get("distance_meters", 0.0)),
		"reached_approach_start": bool(projection.get("reached_target", false)),
		"prepared_position": prepared.position if prepared != null else actor.position,
		"prepared_velocity_mps": prepared.velocity if prepared != null else actor.velocity,
		"decision_uses_authoritative_truth": false,
	}


## Resolves the run-up that is physically possible from the actor's current
## state. This profile is consumed by the contact envelope and action menu.
## The longest run-up anybody actually takes, in seconds.
##
## Three to four steps. Measured against the model's own numbers rather than
## picked: `LEGACY_APPROACH_CEILING_MPS` and the acceleration band above put a
## hitter at full approach speed inside a second, and a system-fit approach
## distance is two to three and a half metres, so a second covers the runway with
## something to spare. Generous on purpose -- the cap is there to stop hang time
## being converted into speed, not to make approaches fail.
const APPROACH_RUNUP_SECONDS: float = 1.10

## Tempo is the hitter's relationship to setter release, not a set-height menu.
##
## T0 is retained as the existing faster-than-first-tempo vocabulary: the
## hitter is already airborne when the setter releases. T1 is takeoff at
## release, T2 is release during the approach footwork, and T3 begins after the
## ball leaves the setter's hands. The values are progress through the hitter's
## own run-up at release; the run-up duration therefore remains individual.
const TEMPO_RELEASE_PROGRESS: Array[float] = [1.0, 1.0, 0.48, 0.0]
const TEMPO_RELATIONSHIPS: Array[String] = [
	"airborne before release",
	"takeoff with release",
	"approach in time with release",
	"approach after release",
]
## A true third-tempo approach waits until the set can be seen before starting.
const THIRD_TEMPO_START_DELAY_SECONDS: float = 0.08
## T0 separates itself from T1 by leaving the floor shortly before release.
const ZERO_TEMPO_TAKEOFF_LEAD_SECONDS: float = 0.08
## Time between the last ground impulse and hand contact. More explosive hitters
## reach the ball sooner, but nobody takes off and contacts on the same frame.
const TAKEOFF_TO_CONTACT_SLOW_SECONDS: float = 0.25
const TAKEOFF_TO_CONTACT_FAST_SECONDS: float = 0.18
## A setter miss is bounded in seconds around the hitter's expected window.
const TEMPO_RECOGNITION_ERROR_POOR_SECONDS: float = 0.18
const TEMPO_RECOGNITION_ERROR_ELITE_SECONDS: float = 0.025
const TEMPO_MINIMUM_FLIGHT_SECONDS: float = 0.10
const TEMPO_MAXIMUM_FLIGHT_SECONDS: float = 1.65
const FIRST_TEMPO_RELEASE_PROGRESS: float = 0.92
const SECOND_TEMPO_RELEASE_PROGRESS: float = 0.05


## The approach rhythm this hitter is offering the setter.
##
## There is deliberately no setter argument. The hitter owns when their steps
## happen; the setter's job is to recognize and meet that expectation in
## `coordinate_tempo`, not to manufacture the hitter's cadence from a label.
static func tempo_intent(
	hitter: VolleyballPlayer,
	tempo: int,
	runup_seconds: float,
) -> Dictionary:
	var index := clampi(tempo, 0, 3)
	var runup := clampf(runup_seconds, 0.0, APPROACH_RUNUP_SECONDS)
	var explosiveness := clampf(
		float(hitter.explosiveness) / 100.0 if hitter != null else 0.5,
		0.0, 1.0,
	)
	var repeatability := clampf(
		float(hitter.approach_timing) / 100.0 if hitter != null else 0.5,
		0.0, 1.0,
	)
	var release_progress := TEMPO_RELEASE_PROGRESS[index]
	var delay := THIRD_TEMPO_START_DELAY_SECONDS if index == 3 else 0.0
	var takeoff_offset := (1.0 - release_progress) * runup + delay
	if index == 0:
		takeoff_offset = -ZERO_TEMPO_TAKEOFF_LEAD_SECONDS
	var takeoff_to_contact := lerpf(
		TAKEOFF_TO_CONTACT_SLOW_SECONDS,
		TAKEOFF_TO_CONTACT_FAST_SECONDS,
		explosiveness,
	)
	return {
		"tempo": index,
		"relationship": TEMPO_RELATIONSHIPS[index],
		"hitter_led": true,
		"runup_seconds": runup,
		"release_progress": release_progress,
		"approach_start_delay_seconds": delay,
		"takeoff_offset_seconds": takeoff_offset,
		"takeoff_to_contact_seconds": takeoff_to_contact,
		"expected_flight_seconds": clampf(
			takeoff_offset + takeoff_to_contact,
			TEMPO_MINIMUM_FLIGHT_SECONDS, TEMPO_MAXIMUM_FLIGHT_SECONDS,
		),
		"hitter_repeatability": repeatability,
	}


## How the setter meets an individual hitter's offered rhythm.
##
## `natural_flight_seconds` is the old set-height answer. It has agency only
## when `tactic_strictness` is at the extreme end; ordinary systems ask the
## setter to meet the hitter. `signed_error` is supplied by the rally's stable
## seeded stream so this pure model remains replayable and directly testable.
static func coordinate_tempo(
	intent: Dictionary,
	setter: VolleyballPlayer,
	pair_familiarity: float,
	tactic_strictness: float,
	natural_flight_seconds: float,
	set_quality: float,
	signed_error: float,
) -> Dictionary:
	var setter_read := clampf((
		float(setter.tempo_control) * 0.42
			+ float(setter.court_vision) * 0.24
			+ float(setter.hand_control) * 0.20
			+ float(setter.decision_making) * 0.14
	) / 100.0, 0.0, 1.0) if setter != null else 0.0
	var familiarity := clampf(pair_familiarity, 0.0, 1.0)
	var repeatability := clampf(float(intent.get(
		"hitter_repeatability", 0.5
	)), 0.0, 1.0)
	var recognition := clampf(
		setter_read * 0.64 + familiarity * 0.22 + repeatability * 0.14,
		0.0, 1.0,
	)
	## Below 0.84 the tactic informs selection but does not seize the hitter's
	## feet. Only an exceptionally rigid, rehearsed system imposes the authored
	## set shape over the individual rhythm.
	var imposition := smoothstep(0.84, 0.98, clampf(tactic_strictness, 0.0, 1.0))
	var expected := float(intent.get("expected_flight_seconds", 0.6))
	var target := lerpf(expected, natural_flight_seconds, imposition)
	var error_band := lerpf(
		TEMPO_RECOGNITION_ERROR_POOR_SECONDS,
		TEMPO_RECOGNITION_ERROR_ELITE_SECONDS,
		recognition,
	) * lerpf(1.15, 0.72, clampf(set_quality, 0.0, 1.0))
	var error := clampf(signed_error, -1.0, 1.0) * error_band
	var delivered := clampf(
		target + error, TEMPO_MINIMUM_FLIGHT_SECONDS, TEMPO_MAXIMUM_FLIGHT_SECONDS
	)
	var result := intent.duplicate(true)
	result.merge({
		"setter_recognition": recognition,
		"pair_familiarity": familiarity,
		"tactic_strictness": tactic_strictness,
		"tactic_imposition": imposition,
		"natural_flight_seconds": natural_flight_seconds,
		"set_quality": set_quality,
		"coordination_signed_error": clampf(signed_error, -1.0, 1.0),
		"called_expected_flight_seconds": expected,
		"target_flight_seconds": target,
		"coordination_error_seconds": delivered - expected,
		"delivered_flight_seconds": delivered,
	}, true)
	return result


## Re-read the hitter at the instant the setter releases.
##
## A tactical T1 is an expectation, not permission to move the hitter's feet.
## If that hitter has completed only half of their runway at release, the ball
## they are offering is a T2. In an ordinary system the setter meets the time
## remaining in *that* approach; only the extreme `tactic_imposition` band keeps
## the authored set shape instead. The tactical call, the setter's recognised
## relationship and the relationship that actually happened are all retained,
## so a synchronization failure is observable without mislabelling a slow ball.
static func recognize_release_progress(
	coordinated: Dictionary,
	release_progress: float,
) -> Dictionary:
	var result := coordinated.duplicate(true)
	var progress := clampf(release_progress, 0.0, 1.0)
	var called_tempo := clampi(int(result.get("tempo", 3)), 0, 3)
	var actual_tempo := achieved_tempo(result, progress)
	var runup := maxf(float(result.get("runup_seconds", 0.0)), 0.0)
	var delay := THIRD_TEMPO_START_DELAY_SECONDS if actual_tempo == 3 else 0.0
	var takeoff_offset := (1.0 - progress) * runup + delay
	if actual_tempo == 0:
		takeoff_offset = -ZERO_TEMPO_TAKEOFF_LEAD_SECONDS
	var observed_expected := clampf(
		takeoff_offset + float(result.get("takeoff_to_contact_seconds", 0.22)),
		TEMPO_MINIMUM_FLIGHT_SECONDS, TEMPO_MAXIMUM_FLIGHT_SECONDS,
	)
	var imposition := clampf(float(result.get("tactic_imposition", 0.0)), 0.0, 1.0)
	var natural := float(result.get("natural_flight_seconds", observed_expected))
	var target := lerpf(observed_expected, natural, imposition)
	var recognition := clampf(float(result.get("setter_recognition", 0.0)), 0.0, 1.0)
	var quality := clampf(float(result.get("set_quality", 0.5)), 0.0, 1.0)
	var error_band := lerpf(
		TEMPO_RECOGNITION_ERROR_POOR_SECONDS,
		TEMPO_RECOGNITION_ERROR_ELITE_SECONDS,
		recognition,
	) * lerpf(1.15, 0.72, quality)
	var error := clampf(float(result.get(
		"coordination_signed_error", 0.0
	)), -1.0, 1.0) * error_band
	var delivered := clampf(
		target + error, TEMPO_MINIMUM_FLIGHT_SECONDS, TEMPO_MAXIMUM_FLIGHT_SECONDS
	)
	## Coordination error changes when the ball arrives, so it also changes the
	## takeoff that would physically meet that ball. Keeping the pre-error offset
	## here published two incompatible clocks: achieved T1 (takeoff at release),
	## a 0.122 s flight, and 0.197 s from takeoff to hand contact. Playback could
	## satisfy them only by accelerating the body. Reconcile the relationship
	## from the delivered flight while retaining the intended offset beside it.
	var intended_takeoff_offset := takeoff_offset
	var physical_takeoff_offset := delivered - float(result.get(
		"takeoff_to_contact_seconds", 0.22
	))
	if actual_tempo <= 1:
		actual_tempo = 0 if physical_takeoff_offset < -0.025 else 1
	result.merge({
		"requested_tempo": called_tempo,
		"requested_relationship": TEMPO_RELATIONSHIPS[called_tempo],
		"observed_release_progress": progress,
		"recognized_tempo": actual_tempo,
		"recognized_relationship": TEMPO_RELATIONSHIPS[actual_tempo],
		"approach_start_delay_seconds": delay,
		"intended_takeoff_offset_seconds": intended_takeoff_offset,
		"takeoff_offset_seconds": physical_takeoff_offset,
		"physical_takeoff_offset_seconds": physical_takeoff_offset,
		"expected_flight_seconds": observed_expected,
		"target_flight_seconds": target,
		"coordination_error_seconds": delivered - observed_expected,
		"delivered_flight_seconds": delivered,
		"achieved_tempo": actual_tempo,
		"achieved_relationship": TEMPO_RELATIONSHIPS[actual_tempo],
	}, true)
	return result


## How much of the intended pre-release footwork could actually happen after
## the hitter finished their prior responsibility and reached the runway.
static func achieved_release_progress(
	intent: Dictionary,
	preparation_window_seconds: float,
	to_mark_seconds: float,
) -> float:
	var intended := clampf(float(intent.get("release_progress", 0.0)), 0.0, 1.0)
	if intended <= 0.0:
		return 0.0
	var needed := float(intent.get("runup_seconds", 0.0)) * intended
	if needed <= 0.0001:
		return intended
	var spare := maxf(preparation_window_seconds - to_mark_seconds, 0.0)
	return intended * clampf(spare / needed, 0.0, 1.0)


static func release_position(
	approach_start: Vector2,
	contact: Vector2,
	release_progress: float,
) -> Vector2:
	return approach_start.lerp(contact, clampf(release_progress, 0.0, 1.0))


## What relationship actually happened, kept separate from what was called.
## A requested T1 whose hitter only completed half the runway before release is
## visibly and physically T2; preserving both labels is how the rally can say
## the tactic missed without redefining the tactic after the fact.
static func achieved_tempo(intent: Dictionary, release_progress: float) -> int:
	var progress := clampf(release_progress, 0.0, 1.0)
	var requested := clampi(int(intent.get("tempo", 3)), 0, 3)
	if requested == 0 and progress >= FIRST_TEMPO_RELEASE_PROGRESS:
		return 0
	if progress >= FIRST_TEMPO_RELEASE_PROGRESS:
		return 1
	if progress > SECOND_TEMPO_RELEASE_PROGRESS:
		return 2
	return 3


static func achieved_relationship(
	intent: Dictionary, release_progress: float
) -> String:
	return TEMPO_RELATIONSHIPS[achieved_tempo(intent, release_progress)]


static func evaluate_takeoff(
	actor: RallyPlayerState,
	target: Vector2,
	available_time: float,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {}
	var delta := RallyKinematicsModel.court_delta_meters(actor.position, target)
	var distance := delta.length()
	var direction := delta.normalized() if distance > 0.001 else actor.facing
	var lateral_share := absf(direction.x)
	var speed_rating := lerpf(
		float(actor.player.transition_speed),
		float(actor.player.lateral_speed), lateral_share * 0.65
	) / 100.0
	var fatigue_factor := LocomotionModel.fatigue_factor(actor.player)
	## One model or the other, never a blend. See
	## `RallyFeatureFlags.ENABLE_UNIFIED_SPEED_MODEL` -- the legacy ceiling here
	## disagrees with the stride model that times this same player's traversal,
	## and not by a constant factor.
	var maximum_speed := LocomotionModel.maximum_speed(
		actor.player, RallyPlayerState.MovementMode.APPROACH
	) if FeatureFlags.ENABLE_UNIFIED_SPEED_MODEL \
		else LocomotionModel.legacy_maximum_speed(
			actor.player, speed_rating, LocomotionModel.LEGACY_APPROACH_CEILING_MPS
		)
	var acceleration := lerpf(2.2, 6.8, float(actor.player.acceleration) / 100.0) \
		* fatigue_factor
	var alignment := 1.0
	if actor.facing.length_squared() > 0.001 and direction.length_squared() > 0.001:
		alignment = clampf((actor.facing.normalized().dot(direction) + 1.0) * 0.5, 0.0, 1.0)
	var turn_delay := lerpf(0.20, 0.02, alignment)
	## **A hitter does not run for the whole flight. They wait, then approach.**
	##
	## `run_time` was the entire available time, so every extra second of hang
	## time bought another second of running and `runway_completion` -- capacity
	## over distance -- saturated at 1.0 for everybody. That was harmless while a
	## set was solved as a ground-to-ground lob and hung for 0.23 s to 0.69 s. It
	## stopped being harmless the moment sets were timed by how high they were put
	## up: real hang times run 0.65 s to 1.47 s, so the run-up became roughly
	## three times easier, and three separate gates went quiet at once -- extreme
	## hitter displacement stopped costing position *or* quality, and transition
	## speed stopped changing when a hitter arrived, because everyone arrived.
	##
	## A three or four step approach is about a second, whatever the set does.
	## Beyond that a hitter is standing at the back of their runway watching the
	## ball, which is what waiting looks like and is not a source of speed. So the
	## window is capped and the surplus is spent standing still -- which is also
	## the honest reading of what a high ball buys an offence: not a faster
	## approach, but the certainty of getting to take one.
	var run_time := minf(
		maxf(available_time - turn_delay, 0.0), APPROACH_RUNUP_SECONDS
	)
	var start_speed := maxf(actor.velocity.dot(direction), 0.0)
	var ending_speed := minf(start_speed + acceleration * run_time, maximum_speed)
	var capacity := (start_speed + ending_speed) * 0.5 * run_time
	## Approach distance is scored against this player's own preferred run-up
	## rather than a league-wide constant. Middles want a compact approach, tall
	## long-strided outsides want a full runway, and both are correct.
	var approach_profile := actor.player.system_fit(
		VolleyballPlayer.SYSTEM_FIT_APPROACH_DISTANCE
	)
	var tolerance_scale := actor.player.system_fit_tolerance_scale()
	var distance_evaluation := {}
	if approach_profile != null:
		distance_evaluation = approach_profile.evaluate(distance, tolerance_scale)
	var distance_fit := float(distance_evaluation.get("fit", 0.0))
	var in_system := bool(distance_evaluation.get("in_system", false))
	var system_bonus := float(distance_evaluation.get("bonus_multiplier", 1.0))
	var speed_fraction := ending_speed / maxf(maximum_speed, 0.1)
	var timing := float(actor.player.approach_timing) / 100.0
	var lateral_control := clampf(
		lerpf(1.0, float(actor.player.lateral_speed) / 100.0, lateral_share)
		* lerpf(0.72, 1.0, alignment), 0.0, 1.0
	)
	var runway_completion := 1.0 if distance <= 0.05 else clampf(capacity / distance, 0.0, 1.0)
	## Distance fit carries real weight now (0.19, up from a token 0.09) because
	## it is player-specific: missing your own mark is a genuine execution error.
	var quality := clampf(
		speed_fraction * 0.24 + timing * 0.22 + alignment * 0.15
		+ lateral_control * 0.12 + distance_fit * 0.19
		+ actor.balance * 0.08, 0.0, 1.0
	) * lerpf(0.62, 1.0, runway_completion)
	## Landing inside the tight rhythm band is a discrete reward on top of the
	## continuous curve, and it eases the shot-menu gates: being in system can be
	## the difference between having the full menu available and not.
	quality = clampf(quality * system_bonus, 0.0, 1.0)
	var power_threshold := POWER_ACCESS_QUALITY_IN_SYSTEM if in_system \
		else POWER_ACCESS_QUALITY_OUT_OF_SYSTEM
	var menu_threshold := FULL_MENU_QUALITY_IN_SYSTEM if in_system \
		else FULL_MENU_QUALITY_OUT_OF_SYSTEM
	return {
		"approach_distance_meters": distance,
		"ideal_approach_distance_meters": approach_profile.ideal_value \
			if approach_profile != null else 0.0,
		"approach_distance_tolerance_meters": float(
			distance_evaluation.get("tolerance", 0.0)
		),
		"approach_distance_deviation_meters": float(
			distance_evaluation.get("signed_deviation", 0.0)
		),
		"approach_distance_fit": distance_fit,
		"approach_in_system": in_system,
		"approach_undershot": bool(distance_evaluation.get("undershot", false)),
		"approach_overshot": bool(distance_evaluation.get("overshot", false)),
		"system_fit_bonus": system_bonus,
		"available_run_time_seconds": run_time,
		"approach_speed_mps": ending_speed,
		"maximum_approach_speed_mps": maximum_speed,
		"approach_speed_fraction": speed_fraction,
		"approach_alignment": alignment,
		"lateral_share": lateral_share,
		"lateral_control": lateral_control,
		"runway_completion": runway_completion,
		"runup_quality": quality,
		## A compromised approach reduces how much of the player's rated jump is
		## available; it does not erase their standing two-foot jump.
		"jump_multiplier": lerpf(0.90, 1.08, quality),
		"balance_multiplier": lerpf(0.58, 1.04, quality * lateral_control),
		"power_access": quality >= power_threshold \
			and speed_fraction >= POWER_ACCESS_SPEED_FRACTION \
			and lateral_control >= POWER_ACCESS_LATERAL_CONTROL,
		"full_shot_menu": quality >= menu_threshold \
			and lateral_control >= FULL_MENU_LATERAL_CONTROL,
	}


## Where a hitter starts their run-up for a ball at `target`.
##
## The depth offset is signed by side and must be: a hitter approaches the net
## from behind it, and "behind" is +y for the home side and -y for the opponent.
## Taking the home offset for an opponent would place their approach mark across
## the net, inside home territory.
## Where a hitter starts their run-up, and therefore how diagonally they arrive.
##
## Single source of truth. `rally_simulator.gd` carried a second derivation of
## this and the two disagreed in *sign*: this one sent `Left Pin` to
## `target.x + 0.07`, which is *inward* of the contact, so pins ran inside-out.
## The simulator's copy sent them outward. This one is what
## `prepare_for_attack()` calls, so inside-out is what the engine actually did --
## backwards from the sport, where an outside hitter starts wide and runs in.
##
## The lateral offset is now derived from an explicit **angle** rather than
## stated as a fixed distance, so that changing the run-up's depth cannot
## silently change its direction. The old ±0.07 against a 0.11 depth was about
## seventeen degrees, pointed the wrong way; a real outside approach is around
## thirty, pointed outward.
##
## This direction is load-bearing beyond appearance. `evaluate_takeoff()` reads
## it: `lateral_share` blends transition speed toward lateral speed, alignment
## drives the turn delay, and carried momentum only counts along it. A hitter's
## available swing is centred on it too.
const APPROACH_ANGLE_MIDDLE_DEGREES: float = 8.0
const APPROACH_ANGLE_PIN_DEGREES: float = 30.0
## How long a run-up is, as a share of court length, at the slowest tempo.
##
## The angle already knew the difference between a middle and a pin -- 8 degrees
## against 30 -- but the *runway* was this one number for everybody, and tempo
## was not an argument at all. So a middle running a first-tempo quick backed off
## 2.52 m exactly like an outside hitter running a tempo-3 high ball, could not
## cover it inside the set's flight, and had the contact dragged back through
## their own approach: Front Quick aimed at 0.54 m off the net and delivered a
## median of 1.92 m.
##
## A quick is a two-step approach and a high ball is a four-step one. `_lane` sat
## unused in this function's signature for exactly this reason -- the shape was
## anticipated and never wired -- and tempo is the honest driver rather than
## lane, because it is what makes a shoot to the pin a different run from a high
## ball to the same place.
const APPROACH_DEPTH: float = 0.11
## The share of the full runway each tempo gets, indexed by tempo 0 to 3.
##
## A quick is a two-to-three step approach and a high ball is a four-step one --
## about 2.2 m against 3.3 m, a ratio near 0.67 -- so the fast end of this scale
## belongs in that neighbourhood and not lower. Swept against the kill-rate
## reference band of 0.38-0.60, over 300 rallies a step:
##
##   scale                       n    net    stuff  err    kill
##   0.42 / 0.55 / 0.78 / 1.0   164  0.061  0.043  0.134  0.646
##   0.58 / 0.70 / 0.86 / 1.0   169  0.065  0.047  0.154  0.544
##   0.72 / 0.82 / 0.92 / 1.0   181  0.055  0.033  0.149  0.459
##
## All three hold attack error and stuff inside their bands; the first puts kill
## above its band outright. The third is chosen because 0.72 is the ratio the
## footwork implies, and it lands mid-band as a consequence rather than as the
## reason -- 0.42 would be a one-metre run-up, which is not an approach.
const APPROACH_DEPTH_BY_TEMPO: Array[float] = [0.72, 0.82, 0.92, 1.0]


## The runway this tempo affords, as a share of court length.
static func approach_depth_for_tempo(tempo: int) -> float:
	return APPROACH_DEPTH * float(
		APPROACH_DEPTH_BY_TEMPO[clampi(tempo, 0, APPROACH_DEPTH_BY_TEMPO.size() - 1)]
	)

## How far off perpendicular a run-up may end up.
##
## The angle chosen up front is only a *starting* offset; the route blend can
## flatten it arbitrarily, and nothing checked the result. A real approach comes
## in between about 15 and 45 degrees off the net's perpendicular -- past that it
## stops being an approach and becomes a shuffle along the tape, which is what a
## tempo-2 outside was drawn doing.
const MAX_APPROACH_ANGLE_DEGREES: float = 42.0
## Wide enough to begin outside the sideline, because that is where an outside
## hitter's approach actually begins. Holding them on court capped the angle at
## exactly the pins that need it most.
const APPROACH_START_MIN_X: float = -0.10
const APPROACH_START_MAX_X: float = 1.10
## How much of the hitter's current position survives, so a player out of
## position is not teleported across the court to draw a textbook run-up.
## Applied to the base rather than to the finished offset -- folding it over the
## sum shrank every textbook approach by 22% even for a hitter already standing
## in the right place, which was never the point.
const APPROACH_ROUTE_BLEND: float = 0.78


static func approach_start_position(
	target: Vector2,
	_lane: String = "",
	side: StringName = &"home",
	current_position: Variant = null,
	depth: float = APPROACH_DEPTH,
	tempo: int = -1,
) -> Vector2:
	## Tempo shortens the runway when the caller knows it. Left optional rather
	## than required so a caller with no tempo to hand keeps the full run-up,
	## which is the behaviour this function had for every caller before.
	if tempo >= 0:
		depth = approach_depth_for_tempo(tempo)
	var pin_distance := absf(target.x - 0.50)
	var wideness := clampf(pin_distance / 0.38, 0.0, 1.0)
	var angle := lerpf(
		APPROACH_ANGLE_MIDDLE_DEGREES, APPROACH_ANGLE_PIN_DEGREES, wideness
	)
	var forward_meters := absf(depth) * CourtConstants.COURT_LENGTH_METERS
	var lateral_meters := forward_meters * tan(deg_to_rad(angle))
	var outward := signf(target.x - 0.50) * lateral_meters \
		/ CourtConstants.COURT_WIDTH_METERS
	var base_x := target.x
	if current_position is Vector2:
		base_x = lerpf(
			(current_position as Vector2).x, target.x, APPROACH_ROUTE_BLEND
		)
	var start_x := clampf(
		base_x + outward, APPROACH_START_MIN_X, APPROACH_START_MAX_X
	)
	## Run *into* the net, not along it.
	##
	## `APPROACH_ROUTE_BLEND` pulls the start toward wherever the hitter happens
	## to be standing, so a voli who is wide of their lane gets a start that is
	## barely ahead of the contact and mostly beside it. The angle computed above
	## is then thrown away: the runway solved for the right *distance* and the
	## wrong *direction*, and a tempo-2 outside came out running parallel to the
	## tape and arriving sideways.
	##
	## The lateral leg is not negotiable -- they do have to get to the pin -- so
	## the depth is what gives. Lengthening the runway until the angle is legal
	## keeps both the destination and the shape of the approach, and it costs the
	## hitter time, which is the honest price of being out of position.
	if FeatureFlags.ENABLE_PERPENDICULAR_APPROACH:
		var lateral_run := absf(target.x - start_x) * CourtConstants.COURT_WIDTH_METERS
		var forward_run := maxf(forward_meters, 0.01)
		if lateral_run / forward_run > tan(deg_to_rad(MAX_APPROACH_ANGLE_DEGREES)):
			forward_meters = lateral_run / tan(deg_to_rad(MAX_APPROACH_ANGLE_DEGREES))
			depth = forward_meters / CourtConstants.COURT_LENGTH_METERS
	if side == &"opponent":
		return Vector2(start_x, clampf(target.y - depth, 0.04, 0.46))
	return Vector2(start_x, clampf(target.y + depth, 0.54, 0.96))


## The families this hitter can execute cleanly off this approach. A family is
## available exactly when it carries no deficit, so this and
## `attack_family_deficit()` can never disagree about where the line is.
static func available_attack_families(
	player: VolleyballPlayer,
	profile: Dictionary,
	arrival_margin: float,
) -> Array[String]:
	var actions: Array[String] = []
	if player == null:
		return ["controlled_roll"]
	for family in ATTACK_FAMILY_REQUIREMENTS:
		if attack_family_deficit(player, profile, arrival_margin, str(family)) <= 0.0:
			actions.append(str(family))
	return actions


## The family a named hit type belongs to. Unknown names fall back to the roll
## shot, which demands nothing and therefore never invents a penalty.
static func attack_family_for_hit_type(hit_type: String) -> String:
	return str(HIT_TYPE_FAMILY.get(hit_type, "controlled_roll"))


## How far outside this hitter's clean capability an attempt at `family` sits,
## as a sum of normalised shortfalls. Zero means they can execute it; larger
## means they are reaching further past what the approach gave them.
##
## This never says no. It is the magnitude a caller feeds to
## `AttemptJudgment.backs_off()` and, if the hitter swings anyway, to the
## quality penalty the attempt carries.
static func attack_family_deficit(
	player: VolleyballPlayer,
	profile: Dictionary,
	arrival_margin: float,
	family: String,
) -> float:
	var terms := attack_family_deficit_terms(
		player, profile, arrival_margin, family
	)
	return float(terms.get("total", 0.0))


## The same shortfall, itemised.
##
## Kept as the single implementation with `attack_family_deficit()` reading its
## total, rather than a parallel diagnostic that recomputes the sum -- a second
## copy of this arithmetic would be free to drift from the one the game plays,
## and then a probe could report a term the swing never paid.
##
## Worth having because the total on its own is unattributable. The opponent
## backed off 71% of swings against the home side's 2%, and nothing published
## could say whether that was ratings, the run-up, or arriving late -- three
## fixes in entirely different files.
static func attack_family_deficit_terms(
	player: VolleyballPlayer,
	profile: Dictionary,
	arrival_margin: float,
	family: String,
) -> Dictionary:
	var terms := {
		"rating": 0.0, "lateral_control": 0.0, "runup_quality": 0.0,
		"arrival_margin": 0.0, "power_access": 0.0, "total": 0.0,
	}
	if player == null:
		return terms
	var requirement: Dictionary = ATTACK_FAMILY_REQUIREMENTS.get(family, {})
	if requirement.is_empty():
		return terms
	if requirement.has("rating"):
		terms["rating"] = maxf(
			float(requirement["rating_floor"])
			- float(player.get(str(requirement["rating"]))),
			0.0,
		) / 100.0
	if requirement.has("lateral_control"):
		terms["lateral_control"] = maxf(
			float(requirement["lateral_control"])
			- float(profile.get("lateral_control", 0.0)), 0.0
		)
	if requirement.has("runup_quality"):
		terms["runup_quality"] = maxf(
			float(requirement["runup_quality"])
			- float(profile.get("runup_quality", 0.0)), 0.0
		)
	if requirement.has("arrival_margin"):
		terms["arrival_margin"] = maxf(
			float(requirement["arrival_margin"]) - arrival_margin, 0.0
		) / ARRIVAL_DEFICIT_SCALE
	if bool(requirement.get("power_access", false)):
		terms["power_access"] = _power_access_deficit(profile)
	terms["total"] = float(terms["rating"]) + float(terms["lateral_control"]) \
		+ float(terms["runup_quality"]) + float(terms["arrival_margin"]) \
		+ float(terms["power_access"])
	return terms


## The run-up shortfall behind a failed `power_access`. The profile reports the
## verdict as a single boolean; an overreach needs to know by how much.
static func _power_access_deficit(profile: Dictionary) -> float:
	var quality_floor := POWER_ACCESS_QUALITY_IN_SYSTEM \
		if bool(profile.get("approach_in_system", false)) \
		else POWER_ACCESS_QUALITY_OUT_OF_SYSTEM
	return maxf(
		quality_floor - float(profile.get("runup_quality", 0.0)), 0.0
	) + maxf(
		POWER_ACCESS_SPEED_FRACTION
		- float(profile.get("approach_speed_fraction", 0.0)), 0.0
	) + maxf(
		POWER_ACCESS_LATERAL_CONTROL
		- float(profile.get("lateral_control", 0.0)), 0.0
	)


static func _reading_quality(player: VolleyballPlayer) -> float:
	return clampf((
		float(player.anticipation) * 0.38
		+ float(player.court_vision) * 0.32
		+ float(player.decision_making) * 0.20
		+ float(player.composure) * 0.10
	) / 100.0, 0.0, 1.0)
