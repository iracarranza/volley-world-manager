class_name VerticalSliceRoster
extends RefCounted

## Hand-authored development fixture roster. Kept outside GameManager so the
## runtime coordinator does not also own hundreds of lines of seed data.
static func make_players(make_player: Callable) -> Array[VolleyballPlayer]:
	var players: Array[VolleyballPlayer] = []
	players.append(make_player.call(1, "Mira", "Setter", "S", {
		"set_accuracy": 86, "set_balance": 82, "set_stability": 84,
		"court_vision": 90, "decision_making": 84,
		## The brain of the squad: reads and runs the offence, serves for
		## placement rather than pace, and is not a terminal attacker.
		"tempo_control": 88, "hand_control": 86, "set_disguise": 79,
		"composure": 82, "tactical_discipline": 85, "leadership": 88,
		"adaptability": 76, "unpredictability": 74, "ego": 44,
		"serve_accuracy": 74, "serve_power": 58, "shot_variety": 46,
		"finesse": 72, "feinting": 66, "tooling": 40, "dig_control": 68,
		"acceleration": 74, "work_rate": 80, "arm_speed": 55,
		"attack_power": 42, "attack_accuracy": 55, "approach_timing": 62,
		"block_timing": 58, "lateral_speed": 76, "transition_speed": 78,
		"stamina": 80, "ball_control": 84, "anticipation": 80,
		"reception": 62, "age": 27, "professional_experience": 6,
		"potential": 74,
		"improvisation": 78, "height_cm": 185.0, "mass_kg": 77.0,
		"wingspan_cm": 188.0, "explosiveness": 73,
	}))
	players.append(make_player.call(2, "Tala", "Outside Hitter", "OH1", {
		"reception": 78, "attack_accuracy": 76, "approach_timing": 80,
		## The dependable six-rotation outside. Good at everything, best at
		## nothing, which is what makes the lane distribution a real question.
		"serve_accuracy": 76, "serve_power": 72, "shot_variety": 74,
		"finesse": 70, "feinting": 68, "tooling": 66, "composure": 76,
		"tactical_discipline": 72, "leadership": 68, "adaptability": 74,
		"unpredictability": 62, "ego": 58, "hand_control": 66,
		"tempo_control": 62, "set_disguise": 40, "dig_control": 74,
		"acceleration": 78, "work_rate": 82, "arm_speed": 74,
		"attack_power": 74, "block_timing": 68, "lateral_speed": 76,
		"transition_speed": 74, "stamina": 80, "ball_control": 76,
		"court_vision": 70, "anticipation": 74, "decision_making": 72,
		"improvisation": 66, "set_accuracy": 42, "set_balance": 46,
		"set_stability": 44, "age": 25, "professional_experience": 4,
		"potential": 79,
		"height_cm": 191.0, "mass_kg": 84.0, "wingspan_cm": 197.0,
		"explosiveness": 82, "reception_balance": 82, "reception_stability": 76,
	}))
	players.append(make_player.call(3, "Boro", "Middle Blocker", "M1", {
		"jump_reach": 88, "block_timing": 84, "approach_timing": 79,
		## Runs the quick, so the tempo attributes have to be there -- a middle
		## who cannot read tempo is a middle who never gets set.
		"tempo_control": 76, "serve_accuracy": 58, "serve_power": 66,
		"shot_variety": 52, "tooling": 70, "feinting": 48, "finesse": 44,
		"composure": 68, "tactical_discipline": 74, "leadership": 60,
		"adaptability": 62, "unpredictability": 48, "ego": 52,
		"hand_control": 52, "set_disguise": 30, "dig_control": 46,
		"acceleration": 80, "work_rate": 76, "arm_speed": 78,
		"attack_power": 80, "attack_accuracy": 66, "lateral_speed": 62,
		"transition_speed": 58, "stamina": 70, "ball_control": 52,
		"court_vision": 58, "anticipation": 66, "decision_making": 62,
		"improvisation": 48, "set_accuracy": 30, "set_balance": 38,
		"set_stability": 34, "age": 26, "professional_experience": 5,
		"potential": 72,
		"height_cm": 205.0, "mass_kg": 98.0, "wingspan_cm": 214.0,
		"explosiveness": 91,
	}))
	players.append(make_player.call(4, "Sena", "Opposite", "OP", {
		"attack_power": 91, "jump_reach": 86, "lateral_speed": 38,
		## The bomber, and priced like one: enormous serve and swing, thin
		## control and discipline. The one player who should be serving big.
		"serve_power": 90, "serve_accuracy": 62, "arm_speed": 88,
		"shot_variety": 66, "tooling": 74, "feinting": 54, "finesse": 48,
		"composure": 58, "tactical_discipline": 52, "leadership": 46,
		"adaptability": 48, "unpredictability": 70, "ego": 84,
		"hand_control": 50, "tempo_control": 54, "set_disguise": 28,
		"dig_control": 40, "acceleration": 62, "work_rate": 66,
		"attack_accuracy": 70, "approach_timing": 76, "block_timing": 72,
		"transition_speed": 60, "stamina": 68, "ball_control": 54,
		"court_vision": 60, "anticipation": 58, "decision_making": 56,
		"improvisation": 62, "set_accuracy": 32, "set_balance": 40,
		"set_stability": 36, "age": 28, "professional_experience": 8,
		"potential": 68,
		"height_cm": 199.0, "mass_kg": 99.0, "wingspan_cm": 207.0,
		"explosiveness": 86,
	}))
	players.append(make_player.call(5, "Ivo", "Outside Hitter", "OH2", {
		"transition_speed": 82, "attack_accuracy": 73, "court_vision": 76,
		## The crafty one. Wide repertoire and high adaptability, so shot
		## variety and feinting have somebody to belong to.
		"serve_accuracy": 70, "serve_power": 68, "shot_variety": 78,
		"finesse": 74, "feinting": 76, "tooling": 62, "composure": 70,
		"tactical_discipline": 76, "leadership": 58, "adaptability": 80,
		"unpredictability": 72, "ego": 54, "hand_control": 64,
		"tempo_control": 66, "set_disguise": 36, "dig_control": 70,
		"acceleration": 84, "work_rate": 78, "arm_speed": 70,
		"attack_power": 72, "approach_timing": 74, "block_timing": 64,
		"lateral_speed": 80, "stamina": 76, "ball_control": 78,
		"anticipation": 76, "decision_making": 78, "improvisation": 80,
		"set_accuracy": 48, "set_balance": 52, "set_stability": 50,
		"age": 24, "professional_experience": 3, "potential": 81,
		"height_cm": 195.0, "mass_kg": 90.0, "wingspan_cm": 200.0,
		"explosiveness": 76, "reception_balance": 72, "reception_stability": 80,
	}))
	players.append(make_player.call(6, "Nemi", "Libero", "L", {
		"reception": 92, "ball_control": 90, "anticipation": 88,
		"attack_power": 20, "height_cm": 176.0, "mass_kg": 69.0,
		## Floor defence made of one person. Everything that touches a dug ball
		## is high; everything that terminates one is not.
		"dig_control": 92, "composure": 86, "tactical_discipline": 84,
		"leadership": 72, "adaptability": 82, "unpredictability": 44,
		"ego": 38, "hand_control": 78, "tempo_control": 58,
		"serve_accuracy": 66, "serve_power": 40, "shot_variety": 30,
		"finesse": 66, "feinting": 34, "tooling": 22, "set_disguise": 44,
		"acceleration": 90, "work_rate": 88, "arm_speed": 48,
		"lateral_speed": 92, "transition_speed": 88, "stamina": 90,
		"court_vision": 84, "decision_making": 82, "improvisation": 74,
		"approach_timing": 40, "block_timing": 30, "attack_accuracy": 40,
		"set_accuracy": 60, "set_balance": 70, "set_stability": 68,
		"age": 29, "professional_experience": 9, "potential": 66,
		"wingspan_cm": 180.0, "explosiveness": 75,
		"reception_balance": 94, "reception_stability": 95,
	}))
	players.append(make_player.call(7, "Kiri", "Middle Blocker", "M2", {
		"jump_reach": 84, "block_timing": 79, "transition_speed": 74,
		## The second middle, deliberately a step behind Boro on every axis
		## that decides who gets set.
		"tempo_control": 70, "serve_accuracy": 54, "serve_power": 60,
		"shot_variety": 48, "tooling": 64, "feinting": 42, "finesse": 40,
		"composure": 62, "tactical_discipline": 66, "leadership": 50,
		"adaptability": 58, "unpredictability": 42, "ego": 48,
		"hand_control": 48, "set_disguise": 26, "dig_control": 44,
		"acceleration": 76, "work_rate": 72, "arm_speed": 72,
		"attack_power": 72, "attack_accuracy": 60, "lateral_speed": 58,
		"stamina": 66, "ball_control": 48, "court_vision": 54,
		"anticipation": 60, "decision_making": 58, "improvisation": 44,
		"set_accuracy": 28, "set_balance": 36, "set_stability": 32,
		"age": 23, "professional_experience": 2, "potential": 77,
		"height_cm": 201.0, "mass_kg": 92.0, "wingspan_cm": 208.0,
		"explosiveness": 82,
	}))
	players.append(make_player.call(8, "Rui", "Outside Hitter", "OH3", {
		"reception": 70, "attack_accuracy": 68, "stamina": 76,
		## The young one: adaptable and willing, not yet composed. The squad
		## needs somebody with room to grow for development to read as growth.
		"serve_accuracy": 60, "serve_power": 64, "shot_variety": 58,
		"finesse": 56, "feinting": 50, "tooling": 52, "composure": 54,
		"tactical_discipline": 58, "leadership": 42, "adaptability": 70,
		"unpredictability": 66, "ego": 62, "hand_control": 54,
		"tempo_control": 56, "set_disguise": 32, "dig_control": 62,
		"acceleration": 72, "work_rate": 74, "arm_speed": 66,
		"attack_power": 66, "approach_timing": 68, "block_timing": 60,
		"lateral_speed": 72, "transition_speed": 70, "ball_control": 68,
		"court_vision": 64, "anticipation": 66, "decision_making": 60,
		"improvisation": 62, "set_accuracy": 40, "set_balance": 44,
		"set_stability": 42, "age": 20, "professional_experience": 1,
		"potential": 88,
		"height_cm": 190.0, "mass_kg": 83.0, "wingspan_cm": 194.0,
		"explosiveness": 74,
	}))
	return players
