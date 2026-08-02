class_name RallyReadinessReport
extends RefCounted

## Two questions this engine could not previously answer, both read-only.
##
## 1. **Does it play like volleyball?** 471 regression checks verify mechanisms
##    in isolation -- that a formula is monotonic, that a trajectory chains, that
##    an attribute changes an option. None of them measure the assembled result.
##    A five-point attack table survived the entire test suite because no check
##    ever looked at where balls actually land. `outcome_calibration()` reports
##    the distributions a volleyball follower would recognise, against reference
##    bands, so a physics change can be judged by what it did to the sport.
##
## 2. **Is the persistent engine ready to replace the legacy one?** Four
##    production flags are off, and "should we turn them on" has been a judgement
##    call. Every rollout verdict already carries the audit that rejected its
##    candidate; nothing ever aggregated those reasons. `rollout_readiness()`
##    ranks them, turning the question into a list of named defects.
##
## Neither changes an outcome. Both drive the ordinary resolver and read what it
## produced.

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const ExecutionScaleModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)

## Which roster the sweeps measure.
##
## `fixture` is the hand-authored vertical slice, where every attribute a
## player's role does not name sits at the default 50. `generated` keeps that
## fixture's ids, positions, rotations and plays but replaces the ability
## attributes with a generated player's, which is the population a real league
## is built from. The reference bands describe the sport, so `generated` is what
## they should be judged against; `fixture` is kept because every other
## regression check in the suite runs on it.
const DEFAULT_POPULATION: StringName = &"generated"

## Approximate rates in elite indoor volleyball, used as tuning reference bands
## rather than as truth. They are wide on purpose: the point is to catch a
## distribution that is obviously not the sport, not to pin the engine to a
## particular league's season.
const REFERENCE_BANDS := {
	"side_out_rate": [0.58, 0.78],
	"ace_rate": [0.02, 0.10],
	"serve_error_rate": [0.08, 0.20],
	"kill_rate": [0.38, 0.60],
	"attack_error_rate": [0.06, 0.20],
	"stuff_rate": [0.03, 0.14],
	## Share of swings the block gets any hand on -- stuffed, touched back, or
	## deflected into defence. Added after a sweep found the block touching 82%
	## of all attacks: a rate nothing measured, because `stuff_rate` only ever
	## saw the swings the block ended outright, and every touch that recycled
	## the ball was invisible to it. Rally length was the only symptom.
	"block_touch_rate": [0.15, 0.45],
	"mean_contacts": [4.0, 9.0],
}

## The four rollout boundaries, and the shadow-summary key each records under.
const ROLLOUT_KEYS: Array[String] = [
	"reception_rollout", "setter_rollout", "attack_rollout", "block_rollout",
]

## The reason each audit emits when there was no candidate to examine at all.
##
## This distinction is the difference between a useful ranking and noise. When
## the shadow pipeline produces nothing, the audit reports *every* check as
## failed, so a naive tally shows fifteen reasons tied at the same count and
## implies fifteen defects where there is really only one: the candidate never
## existed. Rallies carrying these markers are counted separately and their
## other reasons discarded.
const ABSENCE_MARKERS := {
	"reception_rollout": "missing_reception_event",
	"setter_rollout": "setter_response_unavailable",
	"attack_rollout": "shadow_attack_unavailable",
	"block_rollout": "shadow_block_unavailable",
}


## Resolves `sample_count` rallies from each serving side and returns the raw
## per-rally records both reports are built from. Driving both serving sides
## matters: the shadow pipeline only runs on opponent serves, so a sweep that
## forgets to alternate silently measures half the engine.
static func _sweep(
	sample_count: int,
	base_seed: int,
	population: StringName = DEFAULT_POPULATION,
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for serving_home in [true, false]:
		var manager := GameManagerModel.new()
		manager.seed_vertical_slice_data()
		if population == &"generated":
			## Both sides, or the measurement compares a real squad against a
			## squad of clones and reads the difference as a balance finding.
			ExecutionScaleModel.apply_generated_attributes(
				manager.players, base_seed
			)
			ExecutionScaleModel.apply_generated_attributes(
				manager.opponent_team.players, base_seed + 5000
			)
		manager.match_state.serving_home = serving_home
		for index in range(maxi(sample_count, 1)):
			var result: Resource = manager.resolve_active_rally(base_seed + index)
			if result == null:
				continue
			var contacts := 0
			var attack_attempts := 0
			var block_outcomes := {}
			var block_closes: Array[float] = []
			var set_qualities: Array[float] = []
			var approach_fits: Array[float] = []
			var arrival_margins: Array[float] = []
			for event_resource in result.events:
				var event: Resource = event_resource
				if int(event.event_type) in [
					RallyEventModel.EventType.SERVE,
					RallyEventModel.EventType.RECEPTION,
					RallyEventModel.EventType.SET,
					RallyEventModel.EventType.ATTACK,
					RallyEventModel.EventType.BLOCK,
					RallyEventModel.EventType.DEFENSE,
				]:
					contacts += 1
				## Every swing records an ATTACK event before its outcome is
				## known, so this counts attempts -- including the swings that
				## get dug and keep the rally alive. Without them the attack
				## denominator is only the swings that ended a rally, which
				## makes the kill rate rise whenever errors and stuffs fall.
				if int(event.event_type) == RallyEventModel.EventType.ATTACK:
					attack_attempts += 1
				## A block that formed but never reached the ball still emits an
				## event, so the outcome tally is the only way to tell how often
				## the wall is actually in the way.
				if int(event.event_type) == RallyEventModel.EventType.BLOCK:
					var outcome := str(event.metadata.get("outcome", "miss"))
					block_outcomes[outcome] = int(
						block_outcomes.get(outcome, 0)
					) + 1
					## Both blockers, not just the primary. The primary is by
					## definition the one already nearest the attacked lane, so
					## it seals in most rallies and a saturation figure built on
					## it alone reads as a defect when it is geometry. The
					## assist is the blocker who has to travel, and whether the
					## wall closes is really a question about them.
					if event.metadata.has("primary_close"):
						block_closes.append(float(event.metadata["primary_close"]))
					if event.metadata.has("assist_close"):
						block_closes.append(float(event.metadata["assist_close"]))
				## The situation a swing was actually hit from. The execution
				## harness needs these to know what "typical" means; taken from
				## the flat fixture they described a rally nobody plays.
				if int(event.event_type) == RallyEventModel.EventType.SET:
					set_qualities.append(float(event.quality))
				if int(event.event_type) == RallyEventModel.EventType.ATTACK \
						and event.metadata.has("arrival_margin"):
					arrival_margins.append(float(event.metadata["arrival_margin"]))
					if event.metadata.has("approach_quality"):
						approach_fits.append(float(
							event.metadata["approach_quality"]
						))
			var trace: Dictionary = result.analysis.get("shadow_reception", {})
			records.append({
				"serving_home": serving_home,
				"outcome": str(result.terminal_outcome),
				"home_won": bool(result.home_team_won),
				"contacts": contacts,
				"attack_attempts": attack_attempts,
				"block_outcomes": block_outcomes,
				"block_closes": block_closes,
				"set_qualities": set_qualities,
				"approach_fits": approach_fits,
				"arrival_margins": arrival_margins,
				"shadow_summary": Dictionary(trace.get("summary", {})),
			})
	return records


## Does the assembled engine produce a volleyball match?
static func outcome_calibration(
	sample_count: int = 120,
	base_seed: int = 900000,
	population: StringName = DEFAULT_POPULATION,
) -> Dictionary:
	var records := _sweep(sample_count, base_seed, population)
	if records.is_empty():
		return {"fixture_valid": false}

	var outcomes := {}
	var contact_total := 0
	var serves := 0
	var aces := 0
	var serve_errors := 0
	var attacks := 0
	var terminal_attacks := 0
	var kills := 0
	var attack_errors := 0
	var stuffs := 0
	var receiving_team_won := 0
	var home_attack_wins := 0
	var opponent_attack_wins := 0
	var block_outcomes := {}
	var blocks_formed := 0
	var blocks_touching := 0
	var closes_sealed := 0
	var closes_measured := 0
	var set_qualities: Array = []
	var approach_fits: Array = []
	var arrival_margins: Array = []
	for record in records:
		for outcome_key in Dictionary(record["block_outcomes"]):
			var count := int(record["block_outcomes"][outcome_key])
			block_outcomes[outcome_key] = int(
				block_outcomes.get(outcome_key, 0)
			) + count
			blocks_formed += count
			## "miss" is the only outcome where no hand reaches the ball.
			if str(outcome_key) != "miss":
				blocks_touching += count
		set_qualities.append_array(Array(record["set_qualities"]))
		approach_fits.append_array(Array(record["approach_fits"]))
		arrival_margins.append_array(Array(record["arrival_margins"]))
		for close in Array(record["block_closes"]):
			closes_measured += 1
			if float(close) >= 0.995:
				closes_sealed += 1
		var outcome := str(record["outcome"])
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
		contact_total += int(record["contacts"])
		attacks += int(record["attack_attempts"])
		serves += 1
		match outcome:
			"ace":
				aces += 1
			"serve_error":
				serve_errors += 1
		## Terminal outcomes that resolve at a swing. `blocked` and
		## `counter_block` are the same event from the two sides. These are
		## scored against every attempt above, not against each other: the
		## sport's kill and hitting-error rates are per attempt, and a
		## terminal-only denominator makes each rate a function of the others.
		if outcome in ["kill", "opponent_kill", "attack_error", "blocked", "counter_block"]:
			terminal_attacks += 1
			match outcome:
				"kill", "opponent_kill":
					kills += 1
				"attack_error":
					attack_errors += 1
				"blocked", "counter_block":
					stuffs += 1
		## Which side's attack won the point. Every asymmetry found in this
		## engine has been the same defect -- the home team is modelled fully
		## and the opponent as a simplified parallel implementation -- and each
		## was found by accident, hours after it was introduced, because nothing
		## ever compared the two sides against each other.
		match outcome:
			"kill":
				home_attack_wins += 1
			"opponent_kill":
				opponent_attack_wins += 1
		## Side-out: the team that did not serve won the rally.
		var served_by_home := bool(record["serving_home"])
		if bool(record["home_won"]) != served_by_home:
			receiving_team_won += 1

	var measured := {
		"side_out_rate": float(receiving_team_won) / float(serves),
		"ace_rate": float(aces) / float(serves),
		"serve_error_rate": float(serve_errors) / float(serves),
		"kill_rate": float(kills) / maxf(float(attacks), 1.0),
		"attack_error_rate": float(attack_errors) / maxf(float(attacks), 1.0),
		"stuff_rate": float(stuffs) / maxf(float(attacks), 1.0),
		"block_touch_rate": float(blocks_touching) / maxf(float(attacks), 1.0),
		"mean_contacts": float(contact_total) / float(serves),
	}
	var within := {}
	var outside: Array[String] = []
	for metric in REFERENCE_BANDS:
		var band: Array = REFERENCE_BANDS[metric]
		var value := float(measured[metric])
		var inside := value >= float(band[0]) and value <= float(band[1])
		within[metric] = inside
		if not inside:
			outside.append("%s=%.3f outside [%.2f, %.2f]" % [
				metric, value, float(band[0]), float(band[1]),
			])
	return {
		"fixture_valid": true,
		"population": str(population),
		"rally_count": serves,
		"terminal_outcomes": outcomes,
		"attack_attempts": attacks,
		"terminal_attacks": terminal_attacks,
		"home_attack_wins": home_attack_wins,
		"opponent_attack_wins": opponent_attack_wins,
		## 0.5 is even. Above it the home side's attack is winning more, and
		## since both squads are drawn from the same generator on the generated
		## population, anything far from even is a defect in the engine rather
		## than a difference between the teams.
		"home_attack_share": float(home_attack_wins) / maxf(
			float(home_attack_wins + opponent_attack_wins), 1.0
		),
		"blocks_formed": blocks_formed,
		"block_outcomes": block_outcomes,
		## Share of formed blocks whose primary sealed the lane completely. A
		## value near 1.0 means closing is not being decided by anything: the
		## blocker always gets there, so tempo, distance and footspeed cannot
		## matter. That was true of every block in the engine until closing
		## started running through the shared traversal solver.
		"block_close_saturation": float(closes_sealed)
			/ maxf(float(closes_measured), 1.0),
		## What the rally actually hands a hitter, for the execution harness to
		## calibrate its named situations against instead of guessing them.
		"situation_inputs": {
			"set_quality": ExecutionScaleModel.summarise(set_qualities),
			"approach_fit": ExecutionScaleModel.summarise(approach_fits),
			"arrival_margin": ExecutionScaleModel.summarise(arrival_margins),
		},
		"measured": measured,
		"reference_bands": REFERENCE_BANDS.duplicate(true),
		"within_reference": within,
		"outside_reference": outside,
		"all_within_reference": outside.is_empty(),
	}


## What is actually stopping the persistent engine from taking over?
##
## Reads `candidate_audit.failure_reasons` rather than the verdict's own
## `fallback_reason`, because the latter collapses to "rollout_disabled" while
## the production flag is off and hides everything underneath it. The audit runs
## either way, so its reasons are available without touching a flag.
static func rollout_readiness(
	sample_count: int = 120,
	base_seed: int = 910000,
	population: StringName = DEFAULT_POPULATION,
) -> Dictionary:
	var records := _sweep(sample_count, base_seed, population)
	if records.is_empty():
		return {"fixture_valid": false}

	var by_boundary := {}
	for key in ROLLOUT_KEYS:
		by_boundary[key] = {
			"reached": 0, "eligible": 0, "no_candidate": 0, "blockers": {},
		}
	for record in records:
		var summary: Dictionary = record["shadow_summary"]
		if summary.is_empty():
			continue
		for key in ROLLOUT_KEYS:
			var verdict: Dictionary = summary.get(key, {})
			if verdict.is_empty():
				continue
			var bucket: Dictionary = by_boundary[key]
			bucket["reached"] = int(bucket["reached"]) + 1
			if bool(verdict.get("candidate_available", false)):
				bucket["eligible"] = int(bucket["eligible"]) + 1
				continue
			var audit: Dictionary = verdict.get("candidate_audit", {})
			var failures: Array = Array(audit.get("failure_reasons", []))
			if failures.is_empty():
				failures = ["unreported"]
			var reasons: Array[String] = []
			for raw_reason in failures:
				## Reasons carry an id suffix (`blocker_negative_delay:104`);
				## group by the kind of failure, not by which player hit it.
				reasons.append(str(raw_reason).get_slice(":", 0))
			if str(ABSENCE_MARKERS.get(key, "")) in reasons:
				bucket["no_candidate"] = int(bucket["no_candidate"]) + 1
				continue
			for reason in reasons:
				var blockers: Dictionary = bucket["blockers"]
				blockers[reason] = int(blockers.get(reason, 0)) + 1
	var summary_rows := {}
	for key in ROLLOUT_KEYS:
		var bucket: Dictionary = by_boundary[key]
		var reached := int(bucket["reached"])
		var absent := int(bucket["no_candidate"])
		var rejected := reached - absent - int(bucket["eligible"])
		summary_rows[key] = {
			"reached": reached,
			"eligible": int(bucket["eligible"]),
			"eligible_rate": float(bucket["eligible"]) / maxf(float(reached), 1.0),
			## No candidate was produced: nothing for the audit to judge.
			"no_candidate": absent,
			"no_candidate_rate": float(absent) / maxf(float(reached), 1.0),
			## A candidate existed and the audit turned it down. These are the
			## only rallies whose reasons mean anything.
			"rejected": rejected,
			"blockers": _ranked(Dictionary(bucket["blockers"])),
		}
	return {
		"fixture_valid": true,
		"rally_count": records.size(),
		"by_boundary": summary_rows,
		## Every production flag is expected to be off while this runs; the
		## report is evidence for a rollout decision, never a rollout.
		"production_flags_enabled": [
			RallyFeatureFlags.ENABLE_CONTINUOUS_RECEPTION_EVENTS,
			RallyFeatureFlags.ENABLE_CONTINUOUS_SETTER_EVENTS,
			RallyFeatureFlags.ENABLE_CONTINUOUS_ATTACK_EVENTS,
			RallyFeatureFlags.ENABLE_CONTINUOUS_BLOCK_EVENTS,
		],
	}


## Failure reasons, most frequent first.
static func _ranked(counts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for reason in counts:
		rows.append({"reason": str(reason), "count": int(counts[reason])})
	rows.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	return rows
