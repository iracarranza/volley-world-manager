extends SceneTree

## Gate 0 of the simulation/playback authority handoff: what happens to the ten
## volis who are not playing the ball.
##
##     godot --headless --path . --script res://tools/run_offball_timing_baseline.gd
##
## `home_phase_targets` / `opponent_phase_targets` publish an off-ball
## destination and **no duration**. `match_screen._set_plan_target` writes
## `{start, target, protected}` with no `seconds`, so `_pace_plan` gives every
## one of these legs `max(metres / transition_speed, active_window)` -- the ball's
## flight, whatever the distance. This measures the gap between that and what the
## movement model says the journey actually takes, before change 5 gives these
## legs a duration of their own.
##
## **Reconstructs playback's bookkeeping rather than the resolver's.** Playback
## starts each leg from `match_court_3d.live_positions`, and because the current
## pacing always fills the window, that is the previous window's target. A
## player's first appearance in any phase map therefore has no known start and is
## counted as `unknown_start` instead of guessed at.
##
## **Entry velocity is taken as zero and that is a stated bias.** Off-ball legs
## publish no `movement_entry_velocity`, so `natural_s` here is a standing start.
## Real carried speed would shorten it, which means the "cannot complete" share
## below is an upper bound and the "stretched" share a lower one.
##
## **Half the contract already exists.** `_travel_intent` publishes
## `traversal_seconds` and `window_seconds` per off-ball player and seven call
## sites use it; `_uniform_intents` publishes `{intent, progress: 0.0}` and
## nothing else. Neither is read by playback. The `timed` / `untimed` split below
## is therefore the interesting column: it says how much of change 5 is a
## presentation change and how much is a missing simulation fact.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const ShadowMovementModel := preload("res://scripts/simulation/shadow_movement_system.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 150

const COURT_W: float = 9.0
const COURT_L: float = 18.0

## `match_screen.PLAUSIBLE_TOP_SPEED_MPS`, used where a profile carries no
## `transition_speed_mps`. Duplicated rather than imported because this probe
## must measure what playback does, including its fallback.
const PLAUSIBLE_TOP_SPEED_MPS: float = 7.0

## Below this a leg says nothing about pace, matching the 0.05 m floor
## `MovementTimingRatioCalibration` already uses.
const MINIMUM_LEG_METERS: float = 0.05


func _metres(from_position: Vector2, to_position: Vector2) -> float:
	var delta := to_position - from_position
	return Vector2(delta.x * COURT_W, delta.y * COURT_L).length()


func _profile_for(manager: Object, player_id: int) -> VolleyballPlayer:
	for player in manager.players:
		if int(player.id) == player_id:
			return player as VolleyballPlayer
	if manager.opponent_team != null:
		return manager.opponent_team.player_by_id(player_id) as VolleyballPlayer
	return null


func _initialize() -> void:
	var families := {}
	var totals := {
		"legs": 0, "unknown_start": 0, "too_short": 0, "unreachable": 0,
		"early": 0, "cannot_complete": 0, "stretched": 0, "at_pace": 0,
		"timed": 0, "untimed": 0, "stretched_new": 0, "at_pace_new": 0,
	}
	var rows: Array[String] = []
	rows.append(
		"seed|side|player|family|from->to|distance_m|window_s|natural_s"
		+ "|drawn_s|pace_ratio|completable|verdict"
	)
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var profiles: Dictionary = result.player_physical_profiles
			var events: Array = result.events
			var live := {}
			for index in range(events.size() - 1):
				var from_event: Resource = events[index]
				var to_event: Resource = events[index + 1]
				if from_event == null or to_event == null:
					continue
				var window := float(to_event.metadata.get("physical_time", -1.0)) \
					- float(from_event.metadata.get("physical_time", -1.0))
				var pair := "%s->%s" % [
					RallyEventScript.EventType.keys()[int(from_event.event_type)],
					RallyEventScript.EventType.keys()[int(to_event.event_type)],
				]
				for side in ["home", "opponent"]:
					var targets: Dictionary = to_event.metadata.get(
						"%s_phase_targets" % side, {}
					)
					var intents: Dictionary = to_event.metadata.get(
						"%s_phase_intents" % side, {}
					)
					for raw_player_id in targets:
						var player_id := int(raw_player_id)
						var target := Vector2(targets[raw_player_id])
						## The contact actor is not off-ball; its leg is the one
						## already measured in the verification pass.
						if player_id == int(to_event.actor_id):
							live[player_id] = target
							continue
						if not live.has(player_id):
							totals["unknown_start"] = int(totals.unknown_start) + 1
							live[player_id] = target
							continue
						var start: Vector2 = live[player_id]
						live[player_id] = target
						var distance := _metres(start, target)
						if distance < MINIMUM_LEG_METERS:
							totals["too_short"] = int(totals.too_short) + 1
							continue
						var profile := _profile_for(manager, player_id)
						if profile == null:
							continue
						var actor := RallyPlayerState.create(
							profile, StringName(side), -1, start
						)
						var opening := RallyKinematics.court_delta_meters(start, target)
						actor.facing = opening.normalized()
						var natural: float = ShadowMovementModel.natural_traversal_time(
							actor, target, RallyPlayerState.MovementMode.TRANSITION
						)
						if natural < 0.0:
							totals["unreachable"] = int(totals.unreachable) + 1
							continue
						var physical: Dictionary = profiles.get(player_id, {})
						var speed := maxf(float(physical.get(
							"transition_speed_mps", PLAUSIBLE_TOP_SPEED_MPS
						)), 0.01)
						var active_window := maxf(window, 0.0001)
						var drawn := maxf(distance / speed, active_window)
						var covered := _covered_within(actor, target, window)
						var completable := clampf(
							covered / maxf(distance, 0.0001), 0.0, 1.0
						)
						var verdict := "cannot_complete"
						if natural <= window:
							verdict = "early"
						totals["legs"] = int(totals.legs) + 1
						totals[verdict] = int(totals[verdict]) + 1
						var pace := natural / maxf(drawn, 0.0001)
						if pace < 0.9:
							totals["stretched"] = int(totals.stretched) + 1
						else:
							totals["at_pace"] = int(totals.at_pace) + 1
						var raw_intent = intents.get(raw_player_id, {})
						var intent_data: Dictionary = raw_intent \
							if raw_intent is Dictionary else {}
						var family := str(intent_data.get("intent", "unnamed"))
						var published := float(intent_data.get(
							"traversal_seconds", -1.0
						))
						if published >= 0.0:
							totals["timed"] = int(totals.timed) + 1
						else:
							totals["untimed"] = int(totals.untimed) + 1
						## What `_pace_plan` produces now that
						## `_apply_explicit_targets` carries the intent's own
						## clock. A leg whose intent publishes no traversal keeps
						## the window, which is the old rule exactly.
						var authored := published
						var intent_window := float(intent_data.get(
							"window_seconds", 0.0
						))
						if authored > 0.0 and intent_window > 0.0:
							authored = minf(authored, intent_window)
						var drawn_new := maxf(
							distance / speed,
							authored if authored > 0.0 else active_window,
						)
						var pace_new := natural / maxf(drawn_new, 0.0001)
						if pace_new < 0.9:
							totals["stretched_new"] = int(totals.stretched_new) + 1
						else:
							totals["at_pace_new"] = int(totals.at_pace_new) + 1
						var bucket: Dictionary = families.get(family, {
							"n": 0, "distance": 0.0, "window": 0.0,
							"natural": 0.0, "drawn": 0.0, "pace": 0.0,
							"completable": 0.0, "early": 0, "cannot": 0,
							"timed": 0, "published": 0.0,
							"pace_new": 0.0, "drawn_new": 0.0,
						})
						bucket["n"] = int(bucket.n) + 1
						bucket["distance"] = float(bucket.distance) + distance
						bucket["window"] = float(bucket.window) + window
						bucket["natural"] = float(bucket.natural) + natural
						bucket["drawn"] = float(bucket.drawn) + drawn
						bucket["pace"] = float(bucket.pace) + pace
						bucket["pace_new"] = float(bucket.pace_new) + pace_new
						bucket["drawn_new"] = float(bucket.drawn_new) + drawn_new
						bucket["completable"] = float(bucket.completable) + completable
						if verdict == "early":
							bucket["early"] = int(bucket.early) + 1
						else:
							bucket["cannot"] = int(bucket.cannot) + 1
						if published >= 0.0:
							bucket["timed"] = int(bucket.timed) + 1
							bucket["published"] = float(bucket.published) + published
						families[family] = bucket
						if rows.size() < 26 and distance > 1.5:
							rows.append(
								"%d|%s|%d|%s|%s|%.2f|%.3f|%.3f|%.3f|%.2f|%.2f|%s" % [
									seed_value, side, player_id, family, pair,
									distance, window, natural, drawn, pace,
									completable, verdict,
								]
							)
	for row in rows:
		print(row)
	print("--- totals")
	var tkeys: Array = totals.keys()
	tkeys.sort()
	for key in tkeys:
		print("%s|%d" % [key, int(totals[key])])
	print("--- by off-ball family")
	print("family|n|mean_distance_m|mean_window_s|mean_natural_s|mean_drawn_s"
		+ "|mean_pace_ratio|mean_completable|early|cannot_complete"
		+ "|timed|mean_published_s|mean_drawn_new_s|mean_pace_new")
	var keys: Array = families.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = families[key]
		var n := maxf(float(b.n), 1.0)
		var timed := maxf(float(b.timed), 1.0)
		print("%s|%d|%.2f|%.3f|%.3f|%.3f|%.2f|%.2f|%d|%d|%d|%.3f|%.3f|%.2f" % [
			key, int(b.n), float(b.distance) / n, float(b.window) / n,
			float(b.natural) / n, float(b.drawn) / n, float(b.pace) / n,
			float(b.completable) / n, int(b.early), int(b.cannot),
			int(b.timed), float(b.published) / timed,
			float(b.drawn_new) / n, float(b.pace_new) / n,
		])
	quit()


## How far the model actually carries this body inside the window it is given.
##
## The ratio `window / natural` would answer a different and easier question,
## because a traversal is not linear in time: the first tenth of a second buys
## very little ground and the last buys a full stride. Integrating for exactly
## the window and measuring the distance covered is the only reading that says
## what a viewer would see.
func _covered_within(
	actor: RallyPlayerState, target: Vector2, window: float
) -> float:
	if window <= 0.0:
		return 0.0
	var integration: Dictionary = ShadowMovementModel.integrate(
		actor, target, window, RallyPlayerState.MovementMode.TRANSITION
	)
	if not bool(integration.get("available", false)):
		return 0.0
	var trail: Array = integration.get("trail", [])
	if trail.size() < 2:
		return 0.0
	return _metres(Vector2(trail[0]), Vector2(trail[trail.size() - 1]))
