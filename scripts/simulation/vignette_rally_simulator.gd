class_name VignetteRallySimulator
extends RallySimulator

## Character creation is allowed to author the tactical problem and the
## opponent's information state, but not a second movement/ball system. This
## subclass supplies only the defensive plan the vignette asks the real resolver
## to play from. RallySimulator still owns positions reached, contact timing,
## trajectories, legality, block contact and continuation.
var vignette_opponent_plan: Resource = null


func _opponent_defensive_plan(opponent_team: Resource) -> Resource:
	if vignette_opponent_plan != null:
		return vignette_opponent_plan
	return super._opponent_defensive_plan(opponent_team)
