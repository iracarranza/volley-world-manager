extends SceneTree

## Does tempo actually cost the hitter time, and would the compromise branch fire?
##
## Step 2 of `docs/design/TEMPO_AND_APPROACH.md`, whose whole purpose is to answer
## that before any behaviour depends on it. Two questions, and they are separate:
##
## 1. **Does the set's flight time vary by tempo at all?** Tempo already drives the
##    set's launch angle -- 12-18 degrees at first tempo against 45-55 at third --
##    so the arc solver should already be producing a wide spread. If it is not, the
##    chain is broken at link 2 and nothing downstream can be built on it.
## 2. **Is the deficit ever positive?** `required - available`, where required is
##    the traversal to the hitter's ideal approach mark plus the run-up from it. If
##    the deficit is never positive the compromise branch is dead code. If it is
##    always positive the resolver is asking for arrivals nothing can meet, which is
##    the playback-sliding complaint stated as a number rather than a symptom.
##
## Run:
##   godot --headless --path . --script res://tools/run_approach_budget.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const TEMPOS: Array[int] = [1, 2, 3]


func _initialize() -> void:
	var by_tempo := {}
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for playbook_tempo in TEMPOS:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			## The home playbook is what decides the tempo of the ball the home
			## hitter gets, so it is the dial this sweep turns.
			_set_home_tempo(manager, playbook_tempo)
			manager.match_state.serving_home = false
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				for raw_event in result.events:
					var event := raw_event as RallyEvent
					if event == null \
							or event.event_type != RallyEventScript.EventType.ATTACK \
							or str(event.metadata.get("side", "")) != "home":
						continue
					var budget: Dictionary = event.metadata.get("approach_budget", {})
					if budget.is_empty():
						continue
					var tempo := int(budget.get("tempo", 0))
					var rows: Array = by_tempo.get(tempo, [])
					rows.append(budget)
					by_tempo[tempo] = rows
			manager.free()

	print("Approach budget by tempo -- %d pairings x %d rallies per tempo"
		% [PAIRINGS, RALLIES])
	print("")
	print("RUN-UP against the set's flight -- the tempo chain's own question")
	print("%-6s %8s %8s %8s %9s %8s" % [
		"tempo", "n", "flight", "run-up", "deficit", "short%"
	])
	for tempo in [0, 1, 2, 3]:
		var rows: Array = by_tempo.get(tempo, [])
		if rows.is_empty():
			continue
		var flight := 0.0
		var to_mark := 0.0
		var run_up := 0.0
		var window := 0.0
		var short_count := 0
		var walk_short := 0
		var missed_mark := 0
		var deficits: Array = []
		var walk_deficits: Array = []
		for row in rows:
			flight += float(row.get("available_seconds", 0.0))
			to_mark += float(row.get("to_mark_seconds", 0.0))
			run_up += float(row.get("run_up_seconds", 0.0))
			window += float(row.get("preparation_window_seconds", 0.0))
			var deficit := float(row.get("deficit_seconds", 0.0))
			deficits.append(deficit)
			if deficit > 0.0:
				short_count += 1
			var walk_deficit := float(row.get("preparation_deficit_seconds", 0.0))
			walk_deficits.append(walk_deficit)
			if walk_deficit > 0.0:
				walk_short += 1
			if not bool(row.get("reached_ideal_mark", true)):
				missed_mark += 1
		var n := float(rows.size())
		deficits.sort()
		walk_deficits.sort()
		print("%-6d %8d %8.3f %8.3f %9.3f %7.1f%%" % [
			tempo, rows.size(), flight / n, run_up / n,
			_percentile(deficits, 0.50), float(short_count) / n * 100.0,
		])
		print("       deficit p10 %+.3f  p50 %+.3f  p90 %+.3f" % [
			_percentile(deficits, 0.10), _percentile(deficits, 0.50),
			_percentile(deficits, 0.90),
		])
		## The other window, on its own terms. This is the one the approach model's
		## own arrival flag is about, so the two have to agree.
		print("       walk: window %.3f s  to mark %.3f s  deficit p50 %+.3f  short %.1f%%  missed mark %.1f%%" % [
			window / n, to_mark / n, _percentile(walk_deficits, 0.50),
			float(walk_short) / n * 100.0, float(missed_mark) / n * 100.0,
		])
	print("")
	print("Link 2 holds if `flight` widens across tempos. Step 4 is worth building")
	print("only if `short%` is neither 0 nor 100 -- a branch nobody enters is dead")
	print("code, and one everybody enters is not a compromise, it is the model.")
	print("")
	print("The two windows must never be added: the walk to the mark happens before")
	print("the setter touches the ball, so only the run-up competes with the flight.")
	quit()


## Install a play at the tempo being swept, for every rotation.
##
## The first version retempoed `saved_plays`, and the vertical slice has none: with
## no called play the resolver falls through to `_fallback_assignment`, whose tempo
## is **hardcoded to 3**. So all three arms of the sweep reported tempo 3, which is
## the exact failure the comment here was written to guard against -- and it is also
## a finding in its own right. Every calibration harness in this repository seeds
## the vertical slice, so **no tool has ever measured a first- or second-tempo
## rally**; the whole tempo system has been calibrated at one setting.
func _set_home_tempo(manager: Object, tempo: int) -> void:
	for rotation in range(1, 7):
		var play := OffensivePlay.new()
		play.play_name = "Tempo %d sweep" % tempo
		play.rotation_number = rotation
		play.context = "Serve Receive"
		for player_id in [4, 3]:
			var assignment := HitterAssignment.new()
			assignment.player_id = player_id
			assignment.start_position = CourtConstants.slot_position(player_id)
			assignment.lane = "Left Pin" if player_id == 4 else "Front Quick"
			assignment.tempo = tempo
			assignment.priority = 1 if player_id == 4 else 2
			play.assignments.append(assignment)
		play.primary_hitter_id = 4
		play.secondary_hitter_id = 3
		var saved: Dictionary = manager.save_offensive_play(play)
		var stored: OffensivePlay = saved.get("play") as OffensivePlay
		if stored != null:
			manager.call_play(stored.id)


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
