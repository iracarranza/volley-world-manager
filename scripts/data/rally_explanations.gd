class_name RallyExplanations
extends RefCounted

## Neutral result summaries and diagnostic factor labels are centralized here.
## Spoken contact/analyst commentary is selected separately by
## `RallyCommentaryRouter` from `RallyCommentaryLines`.
##
## **All three tables substitute now.** `headline()` and `factor()` used to
## return their string untouched, so a placeholder written into either one
## reached the screen as literal `{hitter}` text; only `explanation()` ever
## filled anything in. They all take the same values dictionary today, which is
## what lets a headline name the player it is about.
##
## Tokens: `{team}` `{opponent}` `{server}` `{receiver}` `{setter}` `{hitter}`
## `{blocker}` `{opponent_blocker}` `{play}`.
##
## **A line may only name a role the rally has actually reached.**
## `RallySimulator.narration` fills each token as its contact resolves, so
## `{blocker}` in a serve-error line has nothing to resolve against. An
## unmatched token is deliberately left in the string verbatim rather than
## blanked: a stray `{blocker}` on screen is a visible bug, and a silently empty
## one is a sentence with a hole in it that nobody notices.
##
## **`{blocker}` and `{opponent_blocker}` are separate on purpose.** Both sides
## block in the same rally, and a single key would let a later transition block
## overwrite the name of the blocker who stuffed the first swing -- the
## continuation path's `blocked` would then credit one of our own players with
## the opponent's stuff.

const HEADLINES := {
	"ace": "Service ace by {server}.",
	"serve_error": "Service error by {server}.",
	"kill": "Kill by {hitter}.",
	"blocked": "Block point by {opponent_blocker}.",
	"attack_error": "Attack error by {hitter}.",
	"opponent_attack_error": "Attack error by {hitter}.",
	"transition_loss": "Transition point for {opponent}.",
	"counter_block": "Block point for {team}.",
	"opponent_kill": "Kill for {opponent}.",
	"long_rally_win": "Long-rally point for {team}.",
	"long_rally_loss": "Long-rally point for {opponent}.",
}

## Keyed by explanation key, which is not always the terminal outcome -- see
## `RallySimulator._finish`'s `explanation_key`.
##
## **Serve outcomes are split by direction.** `ace` and `serve_error` each fire
## from both benches, so one string per outcome had to stay neutral about who
## just won the point. `ace`/`ace_conceded` and
## `serve_error`/`opponent_serve_error` let the line say it.
const EXPLANATIONS := {
	"ace": "The serve ended the rally before a controlled first contact.",
	"ace_conceded": "The reception did not control the serve.",
	"serve_error": "The serve did not enter the playable court.",
	"opponent_serve_error": "The serve did not enter the playable court.",
	"kill_called": "The selected offensive play was followed and produced the kill.",
	"kill_improvised": "The setter left the selected play and the attack still scored.",
	"kill_default": "The default offense produced the kill.",
	"blocked": "The opposing block ended the attack.",
	"attack_error": "The attack ended outside the playable court or at the net.",
	"opponent_attack_error": "The attack ended outside the playable court or at the net.",
	## Unreachable: no `_finish` call emits `transition_loss`. Kept so the table
	## still describes the outcome vocabulary, but nothing renders this.
	"transition_loss": "The opponent converted in transition.",
	"counter_block": "The home block ended the counterattack.",
	"opponent_kill": "The opponent converted the attack.",
	"long_rally_win": "The home team won after an extended exchange.",
	"long_rally_loss": "The opponent won after an extended exchange.",
}

## Rendered by `main.gd` as a `• ` bullet list in append order, not as running
## commentary -- the leading and trailing ellipses below read as a sequence and
## do not currently get one.
const FACTOR_LINES := {
	"good_pass": "Reception gave the setter full options.",
	"poor_pass": "Reception pulled the setter off target.",
	"play_followed": "Selected offensive play was followed.",
	"play_abandoned": "Selected offensive play was abandoned.",
	"fast_tempo": "Requested and achieved attack timing differed.",
	"strong_block": "Opponent block pressure reduced the attack window.",
	"strong_defense": "Opponent floor defense controlled the attack.",
	"attack_control": "Attack control produced a playable target.",
	"default_offense": "No offensive play was active.",
	"opponent_adapted": "Opponent formation incorporated a repeated lane or tempo.",
	"defense_assignment_fit": "Saved defensive responsibility matched the attack target.",
	"defense_assignment_stretch": "Defender moved outside the saved responsibility.",
	"block_touch": "Block touch slowed the attack before floor defense.",
	"block_funnel": "Block outcome shaped the attack toward the floor-defense structure.",
	"seam_conflict": "Equal-priority passers contested reception ownership.",
	"attack_recycled": "Attack coverage controlled the block deflection.",
}


static func fill(template: String, values: Dictionary) -> String:
	var filled := template
	for key in values:
		filled = filled.replace("{%s}" % str(key), str(values[key]))
	return filled


static func headline(outcome: String, values: Dictionary = {}) -> String:
	return fill(str(HEADLINES.get(outcome, "The rally ends.")), values)


static func explanation(outcome: String, values: Dictionary) -> String:
	return fill(
		str(EXPLANATIONS.get(outcome, "The point was decided by the final contact.")),
		values,
	)


static func factor(key: String, values: Dictionary = {}) -> String:
	return fill(str(FACTOR_LINES.get(key, key.capitalize())), values)
