class_name VolleyballMatchState
extends Resource

const MatchStatisticsModel := preload("res://scripts/models/match_statistics.gd")
const MatchFormatModel := preload("res://scripts/models/match_format.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

@export var home_score: int = 0
@export var opponent_score: int = 0
@export var home_sets: int = 0
@export var opponent_sets: int = 0
@export var serving_home: bool = false
@export_range(1, 6) var home_rotation: int = 1
@export_range(1, 6) var opponent_rotation: int = 1
@export var set_number: int = 1
@export var match_complete: bool = false
@export var home_timeouts_remaining: int = 2
@export var home_substitutions_used: int = 0
@export var substitution_pairs: Dictionary = {}
@export var substitution_history: Array[Dictionary] = []
@export var rally_history: Array[Dictionary] = []
## The last officially-recorded serve by side and server. Rally previews never
## write here, so resolving the same seed remains deterministic; `record_rally`
## advances this only after the point becomes part of the match.
@export var serve_history: Dictionary = {}
## Signed broadcast flow: positive favors home, negative favors the opponent.
## It is descriptive match state, not a hidden ability bonus by itself.
@export_range(-1.0, 1.0) var match_flow: float = 0.0
@export_range(-1.0, 1.0) var last_flow_shift: float = 0.0
@export var statistics: Resource = MatchStatisticsModel.new()
@export var match_format: Resource = MatchFormatModel.new()

## How much of the previous flow survives each point, and the band a single
## rally can contribute.
##
## Decay and impact are a matched pair, not two independent knobs: a team
## winning every rally at constant impact `i` settles at `i / (1 - decay)`, so
## moving one without the other silently rescales the whole meter.
##
## The original 0.72 with a [0.12, 0.50] band remembered a run for about two
## points -- 0.72 squared is 0.52, so half of any streak was gone by the second
## point after it and a 5-0 run was indistinguishable from a single point by the
## third. That is a recency signal, not momentum.
##
## 0.86 with a halved band stretches the half-life to roughly 4.6 points while
## landing on exactly the same steady-state range: 0.06/0.14 = 0.43 as before,
## and 0.25/0.14 = 1.79 as before, so the meter still tops out near 0.43 on a
## grinding run and still saturates on a sustained spectacular one.
const FLOW_DECAY: float = 0.86
const FLOW_IMPACT_MIN: float = 0.06
const FLOW_IMPACT_MAX: float = 0.25
## Margin past which a set stops being live no matter how late it is.
const LEVERAGE_DEAD_MARGIN: float = 8.0


func record_rally(result: Resource) -> Dictionary:
	if match_complete:
		return {"match_complete": true, "set_complete": false, "rotated": false}
	var home_won: bool = bool(result.home_team_won)
	_record_serve(result)
	var rotated := false
	var opponent_rotated := false
	if home_won:
		home_score += 1
		if not serving_home:
			serving_home = true
			home_rotation = posmod(home_rotation, 6) + 1
			rotated = true
	else:
		opponent_score += 1
		if serving_home:
			opponent_rotation = posmod(opponent_rotation, 6) + 1
			opponent_rotated = true
		serving_home = false
	statistics.record_rally(result)
	var prior_flow := match_flow
	var spectacle := rally_spectacle(result)
	var flow_impact := _flow_impact(
		spectacle, match_format.target_for_set(set_number)
	)
	match_flow = clampf(
		match_flow * FLOW_DECAY + (flow_impact if home_won else -flow_impact),
		-1.0, 1.0,
	)
	last_flow_shift = match_flow - prior_flow
	result.analysis["rally_spectacle"] = spectacle
	result.analysis["flow_impact"] = flow_impact
	result.analysis["flow_shift"] = last_flow_shift
	result.analysis["match_flow"] = match_flow
	rally_history.append({
		"set": set_number,
		"home_score": home_score,
		"opponent_score": opponent_score,
		"home_won": home_won,
		"outcome": str(result.terminal_outcome),
		"explanation": str(result.explanation),
		"spectacle": spectacle,
		"flow": match_flow,
		"flow_shift": last_flow_shift,
	})
	var target: int = match_format.target_for_set(set_number)
	var set_complete := (home_score >= target or opponent_score >= target) \
		and absi(home_score - opponent_score) >= int(match_format.win_by)
	if set_complete:
		if home_score > opponent_score:
			home_sets += 1
		else:
			opponent_sets += 1
		match_complete = home_sets >= match_format.sets_to_win() \
			or opponent_sets >= match_format.sets_to_win()
		if not match_complete:
			## A set carries emotional context into the next one without making a
			## previous 25-point run permanent.
			match_flow *= 0.25
			set_number += 1
			home_score = 0
			opponent_score = 0
			home_timeouts_remaining = 2
			home_substitutions_used = 0
			substitution_pairs.clear()
			substitution_history.clear()
	return {
		"match_complete": match_complete,
		"home_timeouts_remaining": home_timeouts_remaining,
		"home_substitutions_used": home_substitutions_used,
		"set_complete": set_complete,
		"rotated": rotated,
		"opponent_rotated": opponent_rotated,
	}


func flow_label() -> String:
	if absf(match_flow) < 0.10:
		return "Even"
	return "%s %+d" % [
		"Home" if match_flow > 0.0 else "Opponent",
		roundi(absf(match_flow) * 100.0),
	]


## How watchable a rally was, independent of when in the match it happened.
##
## This is deliberately separate from flow, because `flow_shift` cannot answer
## the question and no amount of retuning makes it able to. It saturates -- the
## same maximum-impact rally shifts flow by +0.50 from even and by +0.10 from
## +0.90, so a team's best volleyball scores lowest exactly while it is
## dominating. And it is reversal-dominated -- at +0.90 a routine sideout lost
## by the leader moves flow further than a spectacular rally won by them. Those
## are correct properties for a momentum meter and wrong ones for choosing what
## to show.
##
## Returns 0..1 and reads only the rally. Playback selection consumes this
## directly; flow consumes it as one term alongside leverage.
func rally_spectacle(result: Resource) -> float:
	var contacts := int(result.analysis.get("contacts", maxi(result.events.size() - 1, 0)))
	## Length is the most legible signal a viewer has -- a rally that keeps going
	## visibly keeps going. Capped so one freak exchange cannot swamp everything
	## else in the score.
	var endurance := minf(float(contacts) * 0.04, 0.34)
	## Peak execution, read from the events when they are present. The three
	## summary fields carry reception, set and attack only, so a serve is
	## structurally invisible to them -- and an ace is a near-zero-reception rally
	## by definition, so it scored its own brilliance as nothing. Measured at 0.34
	## mean spectacle against 0.58 for a routine stuff block before this looked at
	## the serve, which is the wrong way round for the most legible action in the
	## sport.
	var peak_quality := maxf(
		float(result.reception_quality),
		maxf(float(result.set_quality), float(result.attack_quality)),
	)
	## Skipping POINT, which is emitted at a hardcoded quality of 1.0 for every
	## rally ever played. Including it pinned peak at maximum everywhere and gave
	## a service error into the net the same execution score as an ace.
	for event in result.events:
		if int(event.event_type) == RallyEventModel.EventType.POINT:
			continue
		peak_quality = maxf(peak_quality, float(event.quality))
	var peak := peak_quality * 0.30
	## Terminal flourish. Errors score nothing on purpose: a rally that ends
	## because somebody missed is not a rally worth replaying, however tense the
	## score was. Named actions belong in this term once the action vocabulary
	## lands (docs/design/ACTION_VOCABULARY_DRAFT.md), at which point it becomes a
	## sum over the rally's named moments rather than a read of the final one --
	## which is what lets "huge dig into transition kill" outrank a flat ace.
	var flourish := 0.0
	match str(result.terminal_outcome):
		## An ace is a complete highlight inside a single contact and cannot earn
		## endurance, so it carries the largest flourish of any outcome. Everything
		## else has a rally to accumulate length and quality over.
		"ace":
			flourish = 0.30
		"blocked", "counter_block":
			flourish = 0.22
		"kill", "opponent_kill", "long_rally_win", "long_rally_loss":
			flourish = 0.10
	return clampf(endurance + peak + flourish, 0.0, 1.0)


## How much the point mattered, 0..1. Lateness alone is not leverage: the
## previous term read `max(score) / target`, which returns 1.0 at both 24-23 and
## 24-10 even though the second set is over. Closeness is the whole difference.
func _leverage(set_target: int) -> float:
	var lateness := clampf(
		float(maxi(home_score, opponent_score)) / float(maxi(set_target, 1)), 0.0, 1.0
	)
	var closeness := 1.0 - clampf(
		float(absi(home_score - opponent_score)) / LEVERAGE_DEAD_MARGIN, 0.0, 1.0
	)
	return lateness * closeness


## Spectacle and leverage weighted so the two extremes land exactly on the
## declared band: nothing notable in a dead set gives FLOW_IMPACT_MIN, a perfect
## rally at match point gives FLOW_IMPACT_MAX.
func _flow_impact(spectacle: float, set_target: int) -> float:
	return clampf(
		FLOW_IMPACT_MIN + spectacle * 0.15 + _leverage(set_target) * 0.04,
		FLOW_IMPACT_MIN, FLOW_IMPACT_MAX,
	)


func score_text() -> String:
	return "HOME %d  —  %d OPPONENT   ·   Sets %d–%d   ·   Set %d" % [
		home_score, opponent_score, home_sets, opponent_sets, set_number,
	]


func serve_context() -> Dictionary:
	return serve_history.duplicate(true)


func _record_serve(result: Resource) -> void:
	if result == null:
		return
	for raw_event in result.events:
		var event := raw_event as RallyEventModel
		if event == null or event.event_type != RallyEventModel.EventType.SERVE:
			continue
		var side := str(event.metadata.get("side", ""))
		var server_id := int(event.metadata.get("server_id", event.actor_id))
		if side.is_empty() or server_id < 0:
			return
		serve_history["%s:%d" % [side, server_id]] = {
			"target": str(event.metadata.get("target", "")),
			"aim_point": event.metadata.get("aim_point", event.end_position),
			"landing_point": event.end_position,
			"mode": str(event.metadata.get("serve_mode", "targeted")),
		}
		return


func to_dict() -> Dictionary:
	return {
		"home_score": home_score,
		"opponent_score": opponent_score,
		"home_sets": home_sets,
		"opponent_sets": opponent_sets,
		"serving_home": serving_home,
		"home_rotation": home_rotation,
		"opponent_rotation": opponent_rotation,
		"set_number": set_number,
		"match_complete": match_complete,
		"home_timeouts_remaining": home_timeouts_remaining,
		"home_substitutions_used": home_substitutions_used,
		"substitution_pairs": substitution_pairs.duplicate(true),
		"substitution_history": substitution_history.duplicate(true),
		"rally_history": rally_history.duplicate(true),
		"serve_history": serve_history.duplicate(true),
		"match_flow": match_flow,
		"last_flow_shift": last_flow_shift,
		"statistics": statistics.to_dict(),
		"match_format": match_format.to_dict(),
	}


func load_dict(data: Dictionary) -> void:
	home_score = int(data.get("home_score", 0))
	opponent_score = int(data.get("opponent_score", 0))
	home_sets = int(data.get("home_sets", 0))
	opponent_sets = int(data.get("opponent_sets", 0))
	serving_home = bool(data.get("serving_home", false))
	home_rotation = clampi(int(data.get("home_rotation", 1)), 1, 6)
	opponent_rotation = clampi(int(data.get("opponent_rotation", 1)), 1, 6)
	set_number = clampi(int(data.get("set_number", 1)), 1, 5)
	match_complete = bool(data.get("match_complete", false))
	home_timeouts_remaining = int(data.get("home_timeouts_remaining", 2))
	home_substitutions_used = int(data.get("home_substitutions_used", 0))
	substitution_pairs = data.get("substitution_pairs", {}).duplicate(true)
	substitution_history.assign(data.get("substitution_history", []))
	rally_history.assign(data.get("rally_history", []))
	serve_history = data.get("serve_history", {}).duplicate(true)
	match_flow = clampf(float(data.get("match_flow", 0.0)), -1.0, 1.0)
	last_flow_shift = clampf(float(data.get("last_flow_shift", 0.0)), -1.0, 1.0)
	statistics = MatchStatisticsModel.new()
	statistics.load_dict(data.get("statistics", {}))
	match_format = MatchFormatModel.from_dict(data.get("match_format", {
		"format_name": "Best of 5", "best_of_sets": 5,
		"regular_set_target": 25, "deciding_set_target": 15, "win_by": 2,
	}))
