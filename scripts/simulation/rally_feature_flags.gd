class_name RallyFeatureFlags
extends RefCounted

## Production rollout switches. Keep disabled until the corresponding
## calibration gate explicitly authorizes live use.
const ENABLE_CONTINUOUS_RECEPTION_EVENTS: bool = false
const ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_SETTER_EVENTS: bool = false
const ALLOW_DEVELOPMENT_SETTER_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_ATTACK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_ATTACK_OVERRIDE: bool = true
## Gate 48 added the selection boundary; Gate 49 added the promotion path
## behind an explicit development fixture and OS.is_debug_build().
const ENABLE_CONTINUOUS_BLOCK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_BLOCK_OVERRIDE: bool = true

## Gate E: the geometric attack. Where the other rollouts promote one *contact*,
## this one replaces how an attack is decided and resolved end to end -- course,
## power, swing, flight, block intersection and in/out.
##
## Open on all three attack paths: the home first ball, the opponent transition
## swing and the home continuation. Each one now takes its landing point, its
## in/out and its block result from a trajectory intersected against a wall
## rather than from a quality scalar against a threshold, and the opponent can
## miss a swing for the first time.
##
## Two things are deliberately still legacy behind this flag, because promoting
## them is a separate question from promoting the outcome. The drawn arc stays
## on `solve_launch_arc`, a ground-to-ground solver, while the resolver launches
## from three metres up -- handing it the resolver's elevation would draw spikes
## leaving the hand at a negative angle. And the serve still resolves through
## `_serve_execution`; the geometric serve flies alongside it and is recorded,
## but a serve is not an attack and gets its own gate.
##
## Production is still closed, and this is the gate refusing the promotion
## rather than the promotion being unfinished. Opened across all three paths,
## the symmetry estimator moves from 0.558 to 0.671 -- the home side wins two
## attacks for every one the opponent wins, against a 0.12 bound. The promotion
## did not create that tilt; it removed what was hiding it. The legacy path ends
## a large share of attacks at the block, and a ball that never reaches the
## floor never asks which side's floor defence is modelled better. Once the
## geometric swing puts those balls down, every rally runs through the home
## side's claimant search, arrival margins, posture reads and support counts on
## one side of the net and through `_choose_opponent_defender` and a flat dig
## contest on the other, and the difference between the two shows up as points.
##
## So the promotion waits on the floor defence, not on itself. Development
## builds run it today through `ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK`, which is
## where Gates 42, 48 and 49 each sat before their own production flip.
## OPEN FOR MANUAL TUNING, NOT BECAUSE IT PASSED.
##
## The symmetry gate rejects this at 0.636 against a 0.12 bound, measured on
## identical rosters over 709 kills. It is on because the outcomes it produces --
## balls landing where the geometry puts them, tools and block-crushes, an
## opponent that can miss -- have to be watched to be tuned, and the play path in
## `main.gd` passes no development flag, so nothing else reveals them.
##
## Turning it on here rather than passing `true` at the play site is deliberate:
## that argument also opens the Gate 42 live attack, the Gate 48/49 live block
## and continuous reception, and tuning against four systems moving at once is
## not tuning.
##
## Before this ships, `_pooled_home_attack_share` must come inside 0.12 on its
## own terms. Do not widen the bound to close this.
const ENABLE_GEOMETRIC_ATTACK: bool = true
const ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK: bool = true

## One attack shape for both sides of the net: one flight per ball, and one rule
## for choosing the shot.
##
## **The two move together or neither does.** Separately they pull in opposite
## directions, which is why the first attempt at each looked like a regression:
##
## The same ball is currently solved twice with two different launch angles. The
## drawn arc uses the hitter's own shot shape; the home defender's budget is
## re-solved through `_opponent_attack_type`, a *defensive* classifier whose "Short
## tip" branch covers everything landing inside y 0.80 -- most of the court. So most
## opponent swings are lobbed at 22-32 degrees for timing purposes and hit flat at
## 5-14 for drawing purposes, and the outcome disagrees with the picture.
##
## Unifying the flight alone makes the asymmetry *worse* -- home defenders go from
## 0.739 s to 0.832 s, because the arc it unifies on is the lobbed one. The lob is
## the second half of the defect: the opponent downgrades to a roll shot below a set
## quality of 0.38 and its first-ball sets have a median of 0.344, so it fires on
## more than half of their attacks and the opponent essentially never spikes. The
## home side has no such rule and swings at everything.
##
## So this flag carries both: `_compromised_shot_type` becomes the shared rule, and
## the defender's budget becomes the flight that was drawn. Together the opponent
## swings and the home defender is timing a swing rather than a lob.
##
## The block-intent gates could not judge either one until their sample was widened
## from 300 rallies of a single six to 1,200 across four rosters -- they separated by
## two or three counts out of fifty, and flipped on random re-sequencing alone.
##
## **Now they can, and the verdict is measured rather than suspected.** Against the
## wider sample the flight fix alone passes both block gates and moves the
## attack-symmetry ratchet 0.656 to 0.672; the pair together reverses the funnelling
## gate by five counts out of about two hundred, which is a genuine reversal. So the
## block's outcome bands genuinely need re-separating against an opponent that
## swings -- that is the remaining work, and it is now a known quantity instead of a
## suspicion. Do not widen a bound to close it.
const ENABLE_UNIFIED_ATTACK_SHAPE: bool = false
