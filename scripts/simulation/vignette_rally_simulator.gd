class_name VignetteRallySimulator
extends RallySimulator

## Character creation is allowed to author the tactical problem and the
## opponent's information state, but not a second movement/ball system. This
## subclass supplies only the defensive plan the vignette asks the real resolver
## to play from. RallySimulator still owns positions reached, contact timing,
## trajectories, legality, block contact and continuation.
var vignette_opponent_plan: Resource = null

const Q1_A1_LEFT_FRONT := 104
const Q1_A2_MIDDLE := 103
const Q1_A3_RIGHT_FRONT := 102


func _opponent_defensive_plan(opponent_team: Resource) -> Resource:
	if vignette_opponent_plan != null:
		## Q1 Quick is a read-block problem, not a pin blocker cheating toward the
		## middle before H3 has released the ball. The restored gravity-true set
		## flight gives the wings enough real travel time that the generic neutral
		## bases can otherwise close a clean double, erasing the vignette's authored
		## information state. Keep A1/A3 honestly attached to their pin threats at
		## release and let the production movement model decide how much of the
		## close they can actually complete. No contact, ball, jump or wall result is
		## authored here.
		if str(vignette_opponent_plan.get("block_strategy")) == "Read Block":
			vignette_opponent_plan.call(
				"set_defender_position", Q1_A1_LEFT_FRONT, Vector2(0.90, 0.60)
			)
			vignette_opponent_plan.call(
				"set_defender_position", Q1_A2_MIDDLE, Vector2(0.50, 0.60)
			)
			vignette_opponent_plan.call(
				"set_defender_position", Q1_A3_RIGHT_FRONT, Vector2(0.10, 0.60)
			)
		return vignette_opponent_plan
	return super._opponent_defensive_plan(opponent_team)
