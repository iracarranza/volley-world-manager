class_name BlockVerdict
extends RefCounted

## Did the block do what it set out to do?
##
## **Not the same question as whether the ball got past.** A funnel that sends
## the swing into a waiting digger has done exactly what it meant to do, and
## drawing that as a broken shield says the opposite of what happened. What
## breaks a shield is a block that meant to *stop* the ball and was wrong about
## where it was going.
##
## This is a separate question from how the swing went, and the two answers do
## not have to agree. A hitter can flare over a block that stays plain -- a good
## swing against a sound block is a good swing, not a blocker's failure -- and a
## block can shatter on a swing that was nothing special, because what shattered
## it was the read rather than the power. Each side's mark is computed from its
## own objective and neither reads the other's.
##
## ## The three facts it takes, and where they come from
##
## | fact | source | means |
## |---|---|---|
## | `intent` | `DefensivePlan.block_intent` | Seal, Balanced or Funnel -- what the wall was *for* |
## | `outcome` | the contest's own band | stuff, touch, funnel or miss |
## | `hands` | `_block_hands_intent` | kill, soft or neutral -- what this blocker went up to do |
## | `miss_reason` | the geometric resolver | over the top, around the edge, or both |
##
## `hands` is the one that carries the user-facing sentence. A blocker with kill
## hands went up to stop the ball; one with soft hands went up to slow it. Being
## beaten means opposite things to the two of them.
##
## ## Measured before it was written
##
## `tools/run_block_verdict_probe.gd` over 246 block events from 240 rallies:
##
## | outcome / hands / miss reason | share |
## |---|---|
## | miss / kill / around | 10.2% |
## | miss / kill / over | 7.7% |
## | miss / kill / over and around | 6.5% |
## | stuff / kill | 6.9% |
## | touch / kill | 13.4% |
##
## So the break lands on **16.7%** of blocks -- kill hands beaten around the
## edge, with or without also being beaten over the top. About one block in six,
## which is a handful of loud moments a set rather than a permanent state.
##
## Beaten purely **over the top** is 7.7% and stays plain, which is the second
## half of the rule: being out-jumped is not a misread. A blocker who was in
## exactly the right place and got hit over is not the voli whose shield should
## come apart.


## Which way a block was beaten counts as *beaten on the course*.
##
## `around` is a positioning answer -- the ball went somewhere the hands were
## not -- and `over` is a reach one. They want opposite fixes, which is why the
## resolver publishes them separately, and only the first is a wrong read.
const COURSE_MISS: String = "around"

## What a blocker went up to do. Absent on the legacy contest path, which is
## 34.6% of blocks, so it has to default to the answer that claims least.
const HANDS_TO_STOP: String = "kill"


## What this block earned, as a cogniticon variant.
static func of(
	intent: String, outcome: String, hands: String, miss_reason: String
) -> String:
	## **A stuff is a stuff whatever the plan said.** Putting the ball down is
	## the loudest thing a wall can do and no intent makes it less so.
	if outcome == "stuff":
		return "ascendant"
	## **A funnel that funnelled did its job.** This is the case that started the
	## rule: the ball goes past the hands *on purpose*, into the shape the
	## defence is already standing in. Under an outcome-only rule it would draw
	## as a failure, which is the opposite of what the wall achieved.
	if intent == "Funnel" and (outcome == "funnel" or outcome == "touch"):
		return "ascendant"
	## And the mirror: a wall that meant to seal and only managed to channel did
	## not do what it set out to. Not broken -- it still shaped the ball -- but
	## not a success either.
	if outcome == "miss" and hands == HANDS_TO_STOP \
			and miss_reason.contains(COURSE_MISS):
		return "broken"
	return "plain"


## The affect a blocker reads this verdict with, in the cue vocabulary.
##
## Stated here rather than in the compiler so the mapping from *what happened* to
## *what a voli feels about it* is in one place, next to the judgement it
## follows from. `affect` reaches two things -- the variant and the grade colour
## -- and having it derived twice is how those two would drift apart.
static func affect_for(verdict: String) -> StringName:
	match verdict:
		"ascendant":
			return &"confident"
		"broken":
			return &"upset"
	return &"neutral"
