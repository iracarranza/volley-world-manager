class_name RallyExplanations
extends RefCounted

## Player-facing rally dialogue is centralized here for manual editing.
## Keep placeholders such as {hitter} and {play} intact when revising text.

const HEADLINES := {
	"ace": "Ace — the serve was never controlled.",
	"serve_error": "Service error gives away the point.",
	"kill": "Clean kill finishes the rally.",
	"blocked": "The block shuts down the attack.",
	"attack_error": "The attack misses the court.",
	"opponent_attack_error": "The opponent's attack misses the court.",
	"transition_loss": "The defense turns the attack into a counterattack point.",
	"counter_block": "The home block wins the transition exchange.",
	"opponent_kill": "The opponent converts in transition.",
	"long_rally_win": "The home team survives the transition and wins the rally.",
	"long_rally_loss": "The opponent outlasts the home defense.",
}

const EXPLANATIONS := {
	"ace": "{server}'s serving pressure overwhelmed the reception before the offense could develop.",
	"serve_error": "{server} pursued too much pressure and could not place the serve in court.",
	"kill_called": "{setter} stayed with {play}. The reception gave {hitter} a usable window, and the attack beat the block-defense shape.",
	"kill_improvised": "The pass pulled the offense away from {play}, but {setter} adapted and found {hitter} against a vulnerable defense.",
	"kill_default": "With no play called, {setter} sent a safe T3 ball to {hitter} at the nearest outside pin. The hitter converted the available opening.",
	"blocked": "The set left {hitter} facing an organized block. The attack window closed before the ball cleared the hands.",
	"attack_error": "{hitter} reached the planned lane, but the attack demand exceeded the available timing and control.",
	"opponent_attack_error": "{hitter} swung through the transition ball and could not keep it in the court.",
	"transition_loss": "The defense read {hitter}'s attack, controlled the dig, and converted the resulting counterattack.",
	"counter_block": "Following the opponent's controlled first contact, {blocker} tracked the counterattack and sealed the return at the net.",
	"opponent_kill": "The opponent controlled the first contact and converted before the home defense could reset.",
	"long_rally_win": "The defense recovered after {hitter}'s first swing and created a second scoring opportunity.",
	"long_rally_loss": "The defense extended the rally, but the opponent retained control through the final exchange.",
}

const FACTOR_LINES := {
	"good_pass": "Positive reception preserved the full offense.",
	"poor_pass": "Poor reception limited the setter's options.",
	"play_followed": "The setter followed the active play.",
	"play_abandoned": "The setter abandoned the active play after the pass.",
	"fast_tempo": "Fast tempo increased both separation and execution risk.",
	"strong_block": "Block timing reduced the available attack window.",
	"strong_defense": "Defensive anticipation covered the chosen target.",
	"attack_control": "Attack accuracy converted the available opening.",
	"default_offense": "No play was active; the setter used the default T3 outside ball.",
	"opponent_adapted": "The opponent recognized a repeated lane or tempo and formed earlier.",
	"defense_assignment_fit": "The saved defensive responsibility matched the attack target.",
	"defense_assignment_stretch": "A defender had to leave the saved responsibility to reach the ball.",
	"block_touch": "A partial block touch slowed the attack and gave floor defense more time.",
	"block_funnel": "The block shaped the attack toward the saved floor-defense structure.",
	"seam_conflict": "Equal-priority passers hesitated over ownership at the reception seam.",
	"attack_recycled": "Attack coverage controlled a block deflection and kept the rally alive.",
}


static func headline(outcome: String) -> String:
	return str(HEADLINES.get(outcome, "The rally ends."))


static func explanation(outcome: String, values: Dictionary) -> String:
	var template := str(EXPLANATIONS.get(outcome, "The point was decided by the final contact."))
	for key in values:
		template = template.replace("{%s}" % str(key), str(values[key]))
	return template


static func factor(key: String) -> String:
	return str(FACTOR_LINES.get(key, key.capitalize()))
