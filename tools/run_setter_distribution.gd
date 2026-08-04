extends SceneTree

## Does the ball go to the hitter worth setting?
##
## The first gate in `docs/design/SETTER_DECISION.md`, and the one that decides
## whether the rest of that document is worth building. Nobody in this engine
## chooses who attacks: the home hitter is `assignment.player_id` from the called
## play, the transition hitter is `_fallback_hitter`, and the opponent takes
## `best_hitter()`. So attacking investment has no delivery channel, and a
## roster built around one great hitter cannot feed them.
##
## This measures the claim rather than asserting it. One hitter is spiked by a
## known amount and the rest left ordinary; if set share does not rise with the
## spike, the premise holds and the decision function has something to fix. If
## it *does* rise, the premise is wrong and the design needs revisiting before
## anything gets written -- which is the outcome worth running this for.
##
## Run:
##   godot --headless --path . --script res://tools/run_setter_distribution.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

## How much better than their team-mates the spiked hitter is made. Several
## steps, because a slope needs more than two points and because a flat response
## at every step is a stronger statement than a flat response at one.
const SPIKES: Array[int] = [0, 10, 20, 30]

## The attributes a hitter is worth setting for. Raising these and nothing else
## keeps the change to *attacking* quality rather than making the player better
## at everything and confounding the reading.
const ATTACK_ATTRIBUTES: Array[String] = [
	"attack_power", "attack_accuracy", "shot_variety", "arm_speed",
]

const PAIRINGS: int = 4
const RALLIES: int = 90


func _initialize() -> void:
	print("Setter distribution: does set share follow hitter quality?")
	print("")
	var baseline_share := -1.0
	for spike in SPIKES:
		var totals := _sweep(spike)
		var share := float(totals.star_attacks) \
			/ maxf(float(totals.home_attacks), 1.0)
		var kill_share := float(totals.kills) \
			/ maxf(float(totals.kills + totals.opponent_kills), 1.0)
		if baseline_share < 0.0:
			baseline_share = share
		print("spike +%-3d star set share=%.3f (%d of %d home attacks)  delta=%+.3f  kill share=%.3f" % [
			spike, share, totals.star_attacks, totals.home_attacks,
			share - baseline_share, kill_share,
		])
	print("")
	print("A flat share column is the design document's premise confirmed: the")
	print("play calls the hitter, so a better hitter is set no more often than a")
	print("worse one and attacking investment cannot be concentrated.")
	quit()


## One roster configuration, swept across pairings and both serving assignments.
func _sweep(spike: int) -> Dictionary:
	var star_attacks := 0
	var home_attacks := 0
	var kills := 0
	var opponent_kills := 0
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			## Identical rosters on both sides, for the same reason the symmetry
			## gate uses them: anything that differs is then the thing under
			## test, not the draw.
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			var star := _spike_one_hitter(manager, spike)
			if star == null:
				manager.free()
				continue
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				match str(result.terminal_outcome):
					"kill": kills += 1
					"opponent_kill": opponent_kills += 1
				for raw_event in result.events:
					var event: Resource = raw_event
					if event.event_type != RallyEventScript.EventType.ATTACK:
						continue
					if str(event.metadata.get("side", "")) != "home":
						continue
					home_attacks += 1
					if event.actor_id == star.id:
						star_attacks += 1
			manager.free()
	return {
		"star_attacks": star_attacks, "home_attacks": home_attacks,
		"kills": kills, "opponent_kills": opponent_kills,
	}


## Raise one front-row attacker's attacking attributes and return them.
##
## An outside hitter rather than the best player on the roster, so the spike is
## a *choice a manager could make* -- develop this player, sign this player --
## rather than a relabelling of whoever was already strongest.
func _spike_one_hitter(manager: Object, spike: int) -> VolleyballPlayer:
	var star: VolleyballPlayer = null
	for player_resource in manager.players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player != null and str(player.position_code) == "OH1":
			star = player
			break
	if star == null or spike <= 0:
		return star
	for attribute in ATTACK_ATTRIBUTES:
		star.set(attribute, clampi(int(star.get(attribute)) + spike, 1, 99))
	return star
