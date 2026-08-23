class_name AttemptJudgment
extends RefCounted

## Whether a player recognises that what they are about to attempt is beyond
## them, and whether they take the safer option anyway.
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
##
## ## Two questions, not one -- corrected 2026-08-16
##
## This file used to answer one question with one weighted sum:
##
##     decision_making 0.50 + tactical_discipline 0.30 + composure 0.20
##
## `docs/design/PLATFORM_CONTACT.md` §14 establishes that `tactical_discipline`
## is a **blend weight between a voli's own disposition and an actual team call**
## -- the form `AttackPowerModel.aggression_from` already ships. Under that
## contract its presence here was wrong in three separate ways, and the third is
## the one that matters:
##
## 1. **No referent.** There is no team call in scope at any of the five sites
##    that reach this decision, so there is nothing for discipline to adhere
##    *to*.
## 2. **Capability use of a non-ability attribute.** Higher discipline made a
##    voli monotonically better at recognising their own limits, which is the
##    test `ATTRIBUTE_WIRING_AUDIT.md` §8.2 sets and the reason `aggression`,
##    `ego` and `leadership` are outside `ABILITY_ATTRIBUTES`.
## 3. **The sign was inverted.** At every one of the five sites the safer option
##    is *also* a departure from the called action -- the setter declining the
##    quick set, the blocker taking the soft block, the hitter rolling instead of
##    swinging. A disciplined voli should hold to the call *more*. This made them
##    abandon it more.
##
## The docstring's old line -- "a marginal one gets chanced by all but the most
## disciplined" -- shows where it came from: discipline read as *self-restraint*,
## a second meaning nothing else in the codebase uses and no attribute owns.
##
## So the question splits into the two it always was:
##
##     recognition   do I understand this is beyond me?        a capability
##     persistence   knowing that, do I go anyway?             temperament
##
## `tactical_discipline` appears in neither, and will belong to `persistence`
## only once a real team call reaches a contact. Inventing a call so the
## attribute has somewhere to live would be worse than leaving it out.

## Judgment threshold at a vanishing deficit, and at a hopeless one. Almost
## anyone recognises a ball hopelessly beyond them; a marginal one gets chanced
## by all but the most clear-eyed.
const CAUTIOUS_THRESHOLD: float = 0.85
const OBVIOUS_THRESHOLD: float = 0.25

## Deficit at which the overreach is considered obvious to anyone.
const OBVIOUS_DEFICIT: float = 0.40

## What recognition is made of.
##
## **Named rather than inline, and the ratio is inherited rather than measured.**
## These are the two surviving terms of the old three-term sum, at the weights
## they already had, renormalised so recognition still spans 0-1. Keeping the
## ratio is the smallest change that removes only the term which does not belong:
## the old model asserted that judging your own limit is about two and a half
## times a matter of decision-making as of composure, and this pass has no
## evidence for or against that. **Neither share is calibrated.** Both are
## reachable by name so a later pass can measure them.
const RECOGNITION_DECISION_SHARE: float = 0.50
const RECOGNITION_COMPOSURE_SHARE: float = 0.20

## How much temperament is allowed to move a recognised overreach.
##
## **Uncalibrated, and deliberately the weight `tactical_discipline` vacated.**
## Choosing a new number here would be authoring temperament's importance in the
## same pass that removed a term for being unjustified; reusing the vacated
## weight at least makes the substitution explicit and the arithmetic
## comparable.
##
## It is spent as a *signed deviation from neutral*, which is the pattern the
## serve already uses for `serve_aggression`:
##
##     serve_risk + (serve_aggression - 0.5) * 0.70
##
## That matters more than the magnitude. Centred, a voli at aggression 50 behaves
## exactly as the old model did with all attributes at 50, so this correction
## **re-attributes variation without moving the population's centre**. Any shift
## the measurements show is the removed term's correlation with the rest of the
## roster becoming visible -- not a rebalance.
const PERSISTENCE_SHARE: float = 0.30


## Does this player understand that the action is beyond what they can do
## cleanly?
##
## A capability, and the only one here. Composure is in it because the
## recognition has to happen under rally pressure rather than in the abstract.
static func recognition(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	return clampf((
		float(player.decision_making) * RECOGNITION_DECISION_SHARE
		+ float(player.composure) * RECOGNITION_COMPOSURE_SHARE
	) / (RECOGNITION_DECISION_SHARE + RECOGNITION_COMPOSURE_SHARE) / 100.0,
		0.0, 1.0)


## How strongly this player goes anyway.
##
## Temperament, not skill. `aggression` is already defined as how strongly a voli
## pursues terminal, high-commitment actions, and backing off is by definition a
## decision not to pursue one -- so this needs no new attribute and no new
## meaning for an existing one.
##
## It is deliberately *not* a blend of aggression and anything else. When a real
## team call reaches one of these contacts, `tactical_discipline` joins here as
## the weight between this disposition and that call, in the shape
## `AttackPowerModel.aggression_from` already uses. Until then there is nothing
## to blend with.
static func persistence(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.5
	return clampf(float(player.aggression) / 100.0, 0.0, 1.0)


## Does this player back off an attempt that sits `deficit` outside what they
## can do cleanly? A reckless player attempts regardless, which is the point.
static func backs_off(player: VolleyballPlayer, deficit: float) -> bool:
	if deficit <= 0.0:
		return false
	var threshold := lerpf(
		CAUTIOUS_THRESHOLD, OBVIOUS_THRESHOLD,
		clampf(deficit / OBVIOUS_DEFICIT, 0.0, 1.0),
	)
	## Recognition clears the bar; temperament raises or lowers how high the bar
	## effectively sits for this voli. Two questions, one comparison, and the
	## terms stay separately inspectable.
	return recognition(player) \
		- (persistence(player) - 0.5) * PERSISTENCE_SHARE >= threshold
