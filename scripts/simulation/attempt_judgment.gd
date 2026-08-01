class_name AttemptJudgment
extends RefCounted

## Whether a player recognises that what they are about to attempt is beyond
## them, and takes the safer option instead.
##
## **Capability is not permission.** Nothing in this engine may remove an action
## from a player because their attributes are too low for it. A player may try
## anything, for good reasons or bad -- the play called for it, they misread
## their own limits, they ran out of options, they gambled. What their
## attributes decide is not *whether* they can try but *how it goes*.
##
## That principle showed up first at the second contact and then at the third,
## and both places wanted the same two things: a read of the player's judgment,
## and a curve saying how likely that judgment is to catch an overreach of a
## given size. Keeping one copy means a hitter and a setter who share a
## temperament behave consistently, and that retuning the curve retunes the
## whole game rather than one contact.
##
## Deficits are expressed on a common 0-1-ish scale by their callers: 0 is
## inside capability, ~0.4 is a long way outside. `SetterCapabilitySystem`
## measures tempo command against pass quality; `ApproachMechanicsSystem`
## measures a swing against the run-up the hitter actually got.

## Judgment threshold at a vanishing deficit, and at a hopeless one. Almost
## anyone recognises a ball hopelessly beyond them; a marginal one gets chanced
## by all but the most disciplined.
const CAUTIOUS_THRESHOLD: float = 0.85
const OBVIOUS_THRESHOLD: float = 0.25

## Deficit at which the overreach is considered obvious to anyone.
const OBVIOUS_DEFICIT: float = 0.40


## How reliably this player recognises that an action is beyond them. Composure
## is in here because the recognition has to happen under rally pressure, not in
## the abstract.
static func judgment(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	return clampf((
		float(player.decision_making) * 0.50
		+ float(player.tactical_discipline) * 0.30
		+ float(player.composure) * 0.20
	) / 100.0, 0.0, 1.0)


## Does this player back off an attempt that sits `deficit` outside what they
## can do cleanly? A reckless player attempts regardless, which is the point.
static func backs_off(player: VolleyballPlayer, deficit: float) -> bool:
	if deficit <= 0.0:
		return false
	var threshold := lerpf(
		CAUTIOUS_THRESHOLD, OBVIOUS_THRESHOLD,
		clampf(deficit / OBVIOUS_DEFICIT, 0.0, 1.0),
	)
	return judgment(player) >= threshold
