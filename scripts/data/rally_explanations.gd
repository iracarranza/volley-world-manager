class_name RallyExplanations
extends RefCounted

## Player-facing rally dialogue is centralized here for manual editing.
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
	"ace": "SERVICE ACE! {server} takes one for themself.",
	"serve_error": "And it's a service error from {server}.",
	"kill": "... and back to {hitter}, who finishes it neatly.",
	"blocked": "... but {opponent_blocker}'s block is there!!",
	"attack_error": "... but {hitter}'s attack isn't where they wanted it.",
	"opponent_attack_error": "... and {hitter}'s attack goes just wide!",
	"transition_loss": "... and {opponent}'s transition shines through!",
	"counter_block": "... but {team} is waiting with a block!",
	"opponent_kill": "... and {opponent} turns it back on them!",
	"long_rally_win": "... but {team} is just too stable, and they finish it off.",
	"long_rally_loss": "... but {opponent} holds on just long enough to win the point.",
}

## Keyed by explanation key, which is not always the terminal outcome -- see
## `RallySimulator._finish`'s `explanation_key`.
##
## **Serve outcomes are split by direction.** `ace` and `serve_error` each fire
## from both benches, so one string per outcome had to stay neutral about who
## just won the point. `ace`/`ace_conceded` and
## `serve_error`/`opponent_serve_error` let the line say it.
const EXPLANATIONS := {
	"ace": "{server}'s serving pressure overwhelmed the reception before the offense could develop.",
	"ace_conceded": "... but {opponent} has made too much of a mess, and the point is lost.",
	"serve_error": "It's a wild serve from {server} -- point to {opponent}.",
	"opponent_serve_error": "{server} pursued too much pressure and could not place the serve in court.",
	"kill_called": "Classic from {setter} -- that's the offense we know from them. Nothing {opponent} could do.",
	"kill_improvised": "A bit messy from {team}, but {setter} found a chance and took it!",
	"kill_default": "{hitter} withstood the pressure from {opponent} -- clean and cool execution.",
	"blocked": "{hitter} had nowhere to go with that one -- classy block from {opponent}.",
	"attack_error": "Looks like {setter} demanded a bit too much of {hitter} there. Point to {opponent}.",
	"opponent_attack_error": "... but {hitter} got lost in the transition play and couldn't stay inbounds.",
	## Unreachable: no `_finish` call emits `transition_loss`. Kept so the table
	## still describes the outcome vocabulary, but nothing renders this.
	"transition_loss": "An excellent read from {opponent}!! And the finish to match.",
	"counter_block": "{opponent} handled that well, but {blocker} read it excellently and shut down the attack.",
	"opponent_kill": "{opponent} handled that well -- {hitter}'s swing did nothing to shut their attack down.",
	"long_rally_win": "The defense recovered after {hitter}'s first swing and created a second scoring opportunity.",
	"long_rally_loss": "It was solid defense from {team}, but just too much quality from {opponent}.",
}

## Rendered by `main.gd` as a `• ` bullet list in append order, not as running
## commentary -- the leading and trailing ellipses below read as a sequence and
## do not currently get one.
const FACTOR_LINES := {
	"good_pass": "Good from {receiver} ... {setter} with options ...",
	"poor_pass": "And it's a rough one from {receiver} ... {setter} will have to work for this one ...",
	"play_followed": "... {setter} follows the plan ...",
	"play_abandoned": "... {setter} finds {hitter} ...",
	"fast_tempo": "Too much tempo on the attack -- {team} couldn't execute.",
	"strong_block": "{opponent}'s block didn't leave {hitter} with much to work with.",
	"strong_defense": "{opponent}'s defense was just too quick.",
	"attack_control": "{hitter} kept their eyes up and found the floor.",
	"default_offense": "No play was active; the setter used the default T3 outside ball.",
	"opponent_adapted": "The opponent recognized a repeated lane or tempo and formed earlier.",
	"defense_assignment_fit": "The saved defensive responsibility matched the attack target.",
	"defense_assignment_stretch": "A defender had to leave the saved responsibility to reach the ball.",
	"block_touch": "A partial block touch slowed the attack and gave floor defense more time.",
	"block_funnel": "The block shaped the attack toward the saved floor-defense structure.",
	"seam_conflict": "Equal-priority passers hesitated over ownership at the reception seam.",
	"attack_recycled": "Attack coverage controlled a block deflection and kept the rally alive.",
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
