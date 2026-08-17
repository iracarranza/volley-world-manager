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

## M4 slice 3 + M5: the shared T1--T3 platform relation owns a successful
## controlled dig's launch, and free-flight interception owns what happens next.
## Production opened only after the paired rollout proved that the intended
## setter can miss, another viable voli can intercept en route, an uncontrolled
## ball reaches its physical terminal, and every played segment remains a prefix
## of the unchanged authoritative launch. Reception and coverage remain separate
## promotions; coverage still lacks its keep-alive decision preference.
const ENABLE_PHYSICAL_PLATFORM_DIG: bool = true
const ALLOW_DEVELOPMENT_PLATFORM_DIG_OVERRIDE: bool = true

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
## **Fix the ordering before turning this on.** On the home path
## `_compromised_shot_type` rewrites `hit_type` *after* `swing_deficit` has
## already been charged against the power swing and spent against
## `result.attack_quality` -- so a hitter who backs down to a roll still pays the
## overreach penalty for the swing they declined. The opponent path re-reads the
## shot before its deficit, so this asymmetry appears only here. Found by the
## stale-derivation sweep (`FAILURE_MODES.md` 15), not by a rally, because the
## flag is off and nothing exercises it.
##
## The `using_live_attack` rollout branch replaces `hit_type` at the same point
## and has the same problem.
const ENABLE_UNIFIED_ATTACK_SHAPE: bool = false

## Choose roll-against-swing on the set that was delivered, not on an estimate.
##
## `opponent_set_quality` is computed twice. The first reads
## `set_geometry.difficulty`, whose target is a placeholder `(0.50, 0.48)` because
## the contact does not exist yet; the second reads the resolved geometry once it
## does, and that is what the SET event stamps. Shot selection ran on the first.
##
## They are not close. The SET event reports a median of 0.755 while shot
## selection was reading about 0.344, and the result is that **97% of opponent
## attacks are rolls or tips -- three power swings in a hundred and twenty** --
## even though only 11% of their sets fall below the compromise threshold and
## their sets are *better* than the home side's (0.755 against 0.682).
##
## The thresholds were never the problem. The number fed to them was.
##
## This sits above most of the dig asymmetry measured in `docs/BACKLOG.md`. A
## side that rolls nearly every ball hands the other a slow lofted ball to read,
## which is 0.526 s of defensive flight against 0.339 s, which is the reach
## margin, the 56.4%-against-23.6% dig rate, the saturated identity gates and the
## symmetry ratchet.
##
## Who swings stays decided on the estimate -- that ordering is genuinely circular,
## since the contact sets the difficulty and the difficulty sets the shot. Only
## what the hitter does with the ball is re-read.
##
## **Off, and it does not work yet -- which is itself the finding.** Turned on, the
## opponent's mix goes from 3 power swings to 4 out of 120. If the delivered
## quality were the 0.755 the SET event reports, the gate would leave roughly four
## swings in five intact, so the quality this reads is *also* low.
##
## That means there are three numbers, not two. The estimate shot selection first
## reads, the resolved value recomputed before the SET event, and whatever the SET
## event's 0.755 median actually is -- because it is demonstrably not the second
## one. Re-attribute that 0.755 before going further: it is the only figure
## suggesting the opponent's sets are good, and every argument that the thresholds
## are correctly placed rests on it.
##
## One caveat on the machinery, which is sound and worth keeping either way. The
## improvisation draw is now taken unconditionally and gated afterwards, per the
## rule in FAILURE_MODES.md section 8. The original `set_quality < 0.38 or
## rng.randf() < ...` short-circuited, so the draw was skipped whenever the first
## clause held -- making draw counts depend on the branch. Fixing that is correct
## and it does re-sequence: one rally in three hundred changes shot type with this
## flag *off*.
const ENABLE_DELIVERED_SET_SHOT_CHOICE: bool = false

## One speed model for every player, in every subsystem.
##
## There are two live today and which one a player gets depends on which
## subsystem asks. `RallyMovementSystem` uses `LocomotionModel.maximum_speed()` --
## the stride x cadence decomposition. `ApproachMechanicsSystem` and
## `CoverageCalculator` use `legacy_maximum_speed()` against ceilings of 5.25 and
## 4.65 m/s, which the locomotion model itself records as disagreeing with its own
## 3.96 and 3.25.
##
## It is not a uniform offset, which is the part that matters. Measured across the
## vertical-slice roster, legacy over stride runs:
##
##   Sena   0.97x     Boro  1.07x     Tala  1.17x
##   Ivo    1.19x     Mira  1.32x     Nemi  1.33x
##
## So the two models **rank players differently**. Sena is slower under legacy and
## Nemi a third faster, meaning the same rally can disagree with itself about who
## is quicker depending on whether the question came from the approach or from the
## traversal. That is not a tuning difference, it is two answers to one question.
##
## It sits directly under this session's work. `_movement_time` times the hitter's
## run through the stride model while `ApproachMechanicsSystem` prepares that same
## hitter at a 5.25 m/s ceiling, so the contact-depth fix and the approach budget
## were reasoning about a player moving at two speeds. `CoverageCalculator` at
## 4.65 against 3.25 inflates defensive reach by up to 43%, which is upstream of
## the claimant search and the dig contest -- and therefore of the symmetry
## ratchet this repository has been chasing.
##
## `locomotion_model.gd` states the divergence out loud and calls unifying it "a
## deliberate rebalance, not a cleanup", which is exactly right and is why this is
## a flag rather than an edit.
##
## **Turned on, it improves the thing this repository has been chasing.** The
## attack-symmetry ratchet moves 0.652 to 0.641 -- the best it has read -- and the
## drift assertion passes. That is a real argument for landing it.
##
## **One thing blocks it, and it is a gap the unification exposed rather than
## created.** `maximum_speed()` is `stride x cadence`, and `cadence_hz` prices
## fatigue, effort and limb turnover but *not mass*. `legacy_maximum_speed`
## multiplied by `mass_factor()` explicitly. So unifying onto the stride model
## drops mass out of coverage entirely, and the gate asserting that greater mass
## slightly reduces movement-derived coverage fails outright. The identity gate on
## defensive attack goes with it.
##
## **That blocker is now closed.** `cadence_hz` prices mass, centred on the
## population so only the deviation is new, at a sensitivity solved against the
## gate that says a longer stride must still make the taller player faster --
## because mass grows with height too, and at full strength it cancelled the
## stride gain exactly, which would have made height buy nothing.
##
## With mass priced and this open: the ratchet reads **0.643 and the drift
## assertion passes**, and the mass-coverage gate passes. One blocker remains
## instead of two -- the gate asserting that a defensive attacking identity lowers
## both error risk and terminal pressure across six career seeds.
##
## **Measured, and it is not a regression -- the gate cannot resolve its own
## claim.** Both arms of the kill comparison sit at a 90% kill rate against a
## sport that runs 45-50%, and with this flag open they come out bit-identical:
##
##             defensive err   physical err   defensive kill   physical kill
##   flag off        0.0327         0.0383           0.8948          0.8971
##   flag on         0.0331         0.0327           0.9019          0.9019
##
## Off, the gate passes on margins of 0.0056 and 0.0023. On, the error clause
## inverts by 0.0004 and the kill clause has no margin at all. Two identities
## agreeing to four decimals is a metric with no headroom, not a property this
## switch removed.
##
## **Correction: the metric is not malformed.** An earlier reading of this called
## `home_kill_rate` a rally-level numerator over a swing-level denominator, and
## blamed `MAX_EXCHANGES`. Both were checked and both were wrong. All three attack
## events tag their side correctly, so the denominator counts every home swing,
## and the raw figures are 48 wins from 53 attempts -- a well-formed kills-per-swing
## ratio. The cap binds in 1.0% of rallies and explains nothing.
##
## What saturates it is the thing itself: **home swings kill 83-91% of the time**,
## against 46.5% measured on identically-seeded squads outside this harness. Part
## of that was the harness drawing its two rosters from different seeds, which is
## now fixed and moved the figure 0.906 to 0.830. The rest is the balance problem
## every flag in this file already names -- the median rally contains one swing,
## and the floor defence almost never keeps a ball alive.
##
## So this blocker is not a measurement to repair. It is the floor defence, which
## is the same blocker `ENABLE_GEOMETRIC_ATTACK` has recorded from the start. The
## gate saturates because the property it measures is genuinely lopsided, and no
## sample size rescues a 0.0004 margin on a quantity pinned near its ceiling.
const ENABLE_UNIFIED_SPEED_MODEL: bool = false

## Decide the block contest on when the blocker jumped, not only on how tall
## they are.
##
## `BLOCKER_REACH_EFFORT` is a flat 0.62 of every blocker's leap, and it stands
## for two different things at once: a block jump is taken from a standstill and
## is genuinely lower than a hitter's, *and* the blocker is somewhere on the way
## up or down when the ball arrives. Rolling the second into the first means
## `block_timing` -- an attribute every player carries, trainable, generated,
## shown on the profile wheel -- decides nothing whatever about whether a block
## stuffs, and a blocker who peaked early is modelled as identical to one who
## peaked on the ball.
##
## Timing is what separates a stuff from a tool. Arms at full extension and not
## yet falling present a surface angled down into the court; arms on the way down
## present the same surface tilted back off a shrinking height, which is what a
## hitter tools. `BlockJumpModel` returns both the height available and whether
## the arms are still rising, and the contact reads them separately.
##
## **Both aggregates are preserved, deliberately and by solving.** Adding a term
## and rebalancing the wall at the same time would leave no sweep able to
## separate them. `STANDING_JUMP_FRACTION` is solved so the mean phase reproduces
## the 0.62 Gate D calibrated (0.620 measured), and `REFERENCE_EFFECTIVENESS` so
## the stuff rate returns to its 12% target (12.2% measured) with block
## involvement unmoved at 43.3%. What is new is only the spread either side.
##
## Three attempts were needed to get that right and all three are recorded in
## `BlockJumpModel`, because each looked correct and was not: scaling off raw
## timing gave 18.9% stuff, dividing by relative effectiveness gave 15.8%, and
## centring on the arithmetic mean of effectiveness gave 16.2% because the
## mapping to the stuff rate is not linear.
##
## **Off because it costs elsewhere.** The attack-symmetry ratchet drifts 0.652 to
## 0.663, and the gate asserting that extreme hitter displacement reduces arrival
## and attack quality fails outright. The second is the informative one: a
## displaced hitter meets a wall whose timing now depends on a close fraction that
## displacement also moves, so the two are coupled in a way the flat reach hid.
## That coupling wants understanding before this ships, not a widened bound.
const ENABLE_BLOCK_JUMP_TIMING: bool = false

## Let the opponent hitter walk to their mark before the set is released.
##
## `_reachable_attack_contact` charges the hitter's entire journey -- transition
## position to attack contact -- against the set's flight time plus a 0.35 s
## grace, and hands back a contact part-way along the run when that is not
## enough. The home side does not work this way: `_approach_budget` splits the
## journey into a walk paid from `preparation_window_seconds` (the pass-to-release
## window) and a run-up paid from `set_flight_seconds`, precisely because
## charging both to one clock double-counts the walk. That correction was made on
## the home side and never made here.
##
## What the double-charge produces, measured over 552 opponent swings:
##
##   clamped short of the asked-for contact   541 of 552  (98%)
##   run the hitter had to make               6.12 m at p50 *and* p90 -- a constant
##   time that run takes                      0.90 s
##   set's hang time                          0.55 s
##   asked-for contact, off the net           3.60 m at p50
##   actual contact, off the net              5.48 m at p50, 6.90 m at p90
##
## An opponent swinging from 5.5 m off the net is swinging from their own
## baseline, and it is not a slow hitter -- the run is a fixed 6.12 m because
## they are never staged anywhere near the lane they are asked to attack from,
## and the clock they are given to cover it is half the clock they have.
##
## It is also the entire block placement error. The crossing geometry is
## `tan(bearing) * off_net_metres`, so a wall staged on the contact is wrong in
## proportion to this depth: blocks that touched the ball faced a p50 contact
## 1.77 m off the net, blocks that were beaten faced 5.51 m.
##
## **What it fixes, measured.** The pass-to-release window is 1.10 s, taking the
## budget from 0.90 s to 2.00 s against a 0.90 s run:
##
##   contact off the net, p50    5.48 m  ->  1.32 m   (a real front-row contact)
##   contact off the net, p90    6.90 m  ->  3.98 m   (a back-row pipe)
##   run the hitter must make    6.12 m  ->  0.72 m
##   run minus flight, p50       +0.36 s ->  +0.08 s
##
## And the block, which had been standing correctly relative to a contact that was
## wrong, starts meeting the ball: involvement goes from 10% to 43%, inside the
## documented 35-45% band, and the crossing bias collapses to roughly zero with no
## change to the wall at all.
##
## **The block-intent gates separate on this alone**, with no band touched:
##
##   intent    stuff   partials
##   Seal        121         64
##   Balanced    107         58
##   Funnel       72         74
##
## Monotone, and in the direction the gates ask for -- sealing ends more rallies at
## the net, funnelling gets a piece of more balls without ending them. The reach and
## width dials were never wrong. They were being swamped by a placement error that
## was really a contact-depth error.
##
## **Why it is nonetheless off.** It over-corrects the block, and an existing gate
## catches it: partial outcomes no longer outnumber terminal stuffs (263 against
## 269), and the stuff rate runs about 24.5% of blocks formed against Gate D's 12%
## target. That is not this change misbehaving -- it is Gate D's constants,
## `BLOCKER_REACH_EFFORT` and `STUFF_DEPTH_METERS`, having been calibrated against
## a contact depth of 5.5 m off the net that this change deletes. A calibration fit
## to a distribution that no longer exists has to be re-derived, and until it is,
## the over-blocking is also the most plausible reading of the symmetry ratchet
## moving 0.663 to 0.677: the home wall stops the opponent's attacks far more often
## than the sport allows.
##
## The back-row legality gate also drops to 13 observed attacks, because a hitter
## who can now reach the pin is chosen over one who cannot and the opponent's
## front-row share rises. That is the correct direction for the sport and a sample
## floor that needs re-setting, not a defect.
##
## **Re-checked after Gate D was re-derived and the power choice was taught about
## the tape.** Still blocked, and by the same gate: partial block outcomes still
## fail to outnumber terminal stuffs, at an unchanged 263 against 269, and the
## defensive-identity gate joins it. Reducing attack error at depth did not touch
## the stuff/touch split, which is consistent with what the reconciliation found
## -- the harness and the rally now agree on how often the block *touches* the
## ball (29.4% against 23.0% per swing at matched depth) and disagree only on how
## often a touch *ends* the rally (19.0% against 8.3%).
##
## So the remaining blocker is narrow and named: what turns a touch into a stuff.
## Not contact depth, not attack error, not wall placement -- all three are now
## measured and agree across both surfaces. Do not widen a bound to accommodate it.
const ENABLE_OPPONENT_APPROACH_WINDOW: bool = false

## Stage the block wall where the ball crosses the tape, not where the hitter jumps.
##
## OFF, AND THE SHAPE IS WRONG. Kept because the measurement behind it is worth
## having written down, and because the diagnostics it added are already earning
## their keep. Do not turn this on -- see the two findings below, either of which
## invalidates it on its own.
##
## `_block_wall_positions` has always been handed the hitter's contact x. That is
## where they leave the ground, not where the ball crosses: the geometry collapses
## to `displacement = tan(bearing) * off_net_metres`, so the wall is wrong by a
## metre for every metre of turn at a metre off the tape. Measured over 1,013 home
## blocks, every beaten wall was beaten toward court centre -- p10 +0.59 m, median
## +2.13 m, p90 +3.50 m. Against a 0.34 m half-width that is not a width that can
## be widened into a fix, and 90% of blocks never touched the ball at all.
##
## **First finding: this is a symptom.** The displacement is entirely explained by
## how far off the net the hitter contacts, and those contacts are not credible.
## Intended front-row contact is 0.36 m off the tape and back-row 3.60 m; the
## measured median is 5.41 m, mean 4.52 m, p90 6.74 m -- swings from the baseline.
## `_reachable_attack_contact` produces them, bisecting the hitter's run and
## handing them "wherever along that line they can reach" whenever they cannot
## make the pin inside the set flight plus a 0.35 s grace, which is almost always.
## The consequence is unambiguous: blocks that touched the ball faced a p50
## contact 1.77 m off the net, blocks that were beaten faced 5.51 m. The block
## works at a real contact depth and never works otherwise. Fixing the wall
## downstream of that would bake a compensation into the wall and then be wrong
## again once the contact depth is fixed.
##
## **Second finding: the dial is the wrong one.** How a block decides where to
## stand is a *system* -- commit (read the hitter), read (read the ball), spread
## (read the net section) -- and which shot it concedes once there is an *intent*
## (Seal/Balanced/Funnel, already on `DefensivePlan`). This flag pushed placement
## into the intent, which already had a job, and the two block-intent gates duly
## inverted rather than separated: with placement in the intent, Seal and Funnel
## stopped meaning line-versus-angle and started meaning nearer-or-further from
## where the ball actually goes, so whichever landed closer won every outcome
## column. Measured, with this on: Seal 14 stuffs / 15 partials, Funnel 23 / 9 --
## strong separation, backwards.
##
## Every wall in the engine today is a commit block, applied universally including
## against high outside sets where it is the wrong system. That is the more likely
## reading of Gate D's 41.5% terminal rate against a 12% target, and read blocking
## as the default is the fix. The replacement is a `block_system` on
## `DefensivePlan`, not a global modifier, with `read_quality` and
## `_blocker_read_quality` as its accuracy term and `BLOCK_SHOULDER_OFFSET` -- a
## frozen 0.095 today, which is why blocker separation measures exactly 0.855 m at
## p10, p50 and p90 alike -- finally varying under bunch versus spread.
##
const ENABLE_BLOCK_CROSSING_READ: bool = false

## Reception quality off a serve, computed one way for both sides of the net.
##
## The home side (opponent serving) has always summed reception 0.65 + ball_control
## 0.20 + composure 0.15 -- three attributes to 1.0. The opponent side (home serving)
## summed reception 0.58 + ball_control 0.24 -- two attributes to 0.82, composure
## never read at all, and with no penalty for the serving side's chosen risk the way
## the opponent's own formula charges the home server's. Measured across 629
## receptions on identical rosters: home reception quality averaged 0.606 against the
## opponent's 0.378 -- the largest single asymmetry measured in the engine, and
## upstream of the set-quality gap the histogram tool measures downstream of it
## (opponent set capability_penalty 0.297 against home's 0.132).
##
## `_reception_skill()` unifies the attribute weighting and a symmetric risk-pressure
## term closes the rest. Narrowing that gap alone -- with `ENABLE_UNIFIED_ATTACK_SHAPE`
## still off, so this is not the same lever -- moves the attack-symmetry ratchet from
## 0.656 to 0.684-0.686 and flips the defensive-identity gate
## (`home_attack_error_rate`/`home_kill_rate` for the Defensive identity, a
## comparison already documented as resolvable only at effect sizes down to 1.4%).
##
## Two independent, well-justified correctness fixes -- this one and
## `ENABLE_UNIFIED_ATTACK_SHAPE` -- push the same ratchet the same direction on their
## own. That convergence is itself evidence: better opponent sets let more of their
## attacks reach a real swing instead of a safe roll (`_choose_opponent_attack`
## downgrades below 0.38, and better reception raises how often that threshold is
## cleared), and the block those swings meet is the system Gate D already measured at
## 41.5% terminal against a 12% target. Improving reception does not create a new
## defect; it exercises an existing one more often.
##
## So this waits behind the same flag discipline: land it once the block's outcome
## bands are re-tuned for an opponent that swings, alongside `ENABLE_UNIFIED_ATTACK_SHAPE`.
## Do not widen the ratchet to close this.
const ENABLE_UNIFIED_RECEPTION_SKILL: bool = false


## Stop billing a hitter for lateness to a contact they were spared.
##
## `_reachable_contact` exists so a hitter who cannot make the ideal contact
## strikes the ball short of it instead of missing it: it pulls the contact back
## along their route to the point they reach as the ball arrives. Once it binds
## they are, by construction, on time. All three swings kept charging the
## pre-clamp arrival margin anyway, so the ball was moved to the hitter *and*
## the hitter was penalised for not reaching where it used to be.
##
## Measured, and it is the whole of the "opponent never spikes" story. Splitting
## the two independent shot downgrades apart (`tools/run_downgrade_attribution_probe.gd`)
## shows 119 opponent swings asked for a power family, 88 surviving the
## set-quality gate, and 3 surviving `AttemptJudgment.backs_off` -- so the gate
## that two earlier attempts went after costs 31 swings and the approach deficit
## costs 85. Itemising that deficit (`tools/run_backoff_terms_probe.gd`) puts
## 0.662 of its 0.958 mean on the stale arrival margin alone, which runs -0.461 s
## against the home side's +0.288 s.
##
## The two sides run identical code. Only this term binds on one of them, because
## only the opponent's hitter routinely fails to make the contact inside the set's
## flight -- and the clamp that fixes that is the same clamp whose result nobody
## re-read.
##
## FLAGGED, NOT BECAUSE IT IS DOUBTFUL BUT BECAUSE IT IS LARGE. Removing a term
## worth 0.662 of a 0.958 deficit will move the opponent from 3 power swings in
## 119 to most of them, and every downstream band -- the block's stuff/touch
## split, the dig rates that inherit opponent flight time, the attack-symmetry
## ratchet -- was calibrated against a side that rolled nearly every ball. Turn
## it on together with that re-tune, not before it.
const ENABLE_CLAMPED_ARRIVAL_MARGIN: bool = true


## Read the hitter's lane off the contact they actually struck.
##
## The second defect of the same shape as `ENABLE_CLAMPED_ARRIVAL_MARGIN`, from
## the same clamp. `opponent_lane` is derived from the contact the set aimed at;
## `_reachable_contact` then moves that contact, and the lane is never re-read.
## Everything it decides therefore points at a swing that did not happen -- the
## wall is restaged against the new contact but the old lane, familiarity accrues
## to the wrong lane, and the ball is resolved along the wrong natural course,
## which is the failure mode the lane fix itself was written to stop ("it sent
## right-side swings across the wrong diagonal and out").
##
## 36% of opponent swings, and 40 of those 43 are a single migration: Right Quick
## to Right Pin. A middle who cannot reach the quick is dragged back down their
## own approach, which runs outward, and arrives at the pin still labelled a
## quick. `tools/run_lane_drift_probe.gd`.
##
## FLAGGED because it moves the wall and the ball's course on a third of opponent
## swings, and both were calibrated with the drift present. Lands with the block
## outcome-band re-tune.
const ENABLE_CLAMPED_CONTACT_LANE: bool = true


## Let the home middle attack.
##
## The home offence was two hitters and a high ball. `_fallback_hitter` -- which
## runs on every ball the calibration fixture plays, because no play is ever
## called -- looked only for Outside Hitters, and `_fallback_assignment` chose a
## lane from which half of the court the hitter stood in, which can only ever
## produce a pin. Measured over 185 home swings: Left Pin 34, Right Pin 151, and
## not one quick or pipe.
##
## That is not a cosmetic gap. `_hit_type` reads "Quick attack" off the *lane*
## and never off the tempo, so no amount of tempo variation could have produced
## one; and because a quick is the only fast ball the home side has, every home
## attack flew for 0.520 s while every opponent attack flew for 0.826 s -- which
## `tools/run_reach_margin_probe.gd` shows is 73% of the dig asymmetry that three
## separate investigations went looking for in the defence.
##
## FLAGGED because it changes what the opponent's block and floor defence are
## asked to solve on every good pass, and both were calibrated against a side
## that only ever hit pins. Expect the attack-symmetry ratchet to move; measure
## before deciding which way is correct.
const ENABLE_HOME_MIDDLE_OFFENSE: bool = true


## Let the tempo call actually vary.
##
## Three separate gates decide whether a set is quick, and every one of them was
## set outside the distribution it cuts -- so none of them ever fired, and 91% of
## home swings came out at tempo 3 with none below 2.
##
##   `OPPONENT_QUICK_CALL_PASS` 0.68, against pass quality whose p90 is 0.567
##   home and 0.588 opponent. The quicken branch of `_tempo_call` has never run.
##   `tempo_variation >= 0.66`, against a preset table running 0.24 to 0.88 with
##   Balanced -- the default -- on exactly 0.50.
##   `commitment >= 0.66 / <= 0.34`, against blended presets that put three of
##   six identities between 0.42 and 0.51.
##
## The consequence is the degeneracy everything else in this branch traces back
## to. One tempo means one set flight, which means the opposing wall always has
## the same closing time, which means the block, the dig and the symmetry gates
## were all calibrated against a single repeated rally. And it means
## `tempo_control`, `set_disguise` and `tempo_variation` are attributes that
## cannot express themselves -- which is the opposite of what the attribute set
## exists for.
##
## FLAGGED, and it belongs with `ENABLE_HOME_MIDDLE_OFFENSE`: one adds the lane a
## quick needs, this adds the tempo. Neither is worth much alone.
const ENABLE_LIVE_TEMPO_CALL: bool = true


## Let the back row swing.
##
## The third in the sequence `ENABLE_HOME_MIDDLE_OFFENSE` and
## `ENABLE_LIVE_TEMPO_CALL` started: one added the lane a quick needs, one added
## the tempo, and this adds the only lane the home offence still could not
## produce. `_fallback_hitter` scanned front-row slots exclusively, so of the five
## lanes in `CourtConstants.LANES` the offence could reach four, and the missing
## one is the one that occupies a middle blocker and stops a three-hitter front
## being read as a three-hitter front.
##
## Everything downstream of the decision already existed and had for some time:
## `LANE_X` carries the pipe at 0.50, `lane_target` puts it behind the attack
## line at 0.66 rather than on the net, `_hit_type` names it "Pipe attack",
## `ApproachMechanicsSystem` gives that hit type a power-attack profile,
## `ShadowAttackSystem._fallback_lane` returns it for any back-row slot, and
## `PlayValidator` has required back-row hitters to use it since the plays were
## written. What was missing was a caller.
##
## Gated on the same pass quality the quick is. A hitter running from four metres
## behind the attack line needs the ball where they expected it, and a pipe off a
## scrambled pass is a free ball with extra steps.
const ENABLE_HOME_PIPE_OFFENSE: bool = true


## Let a hitter say how tight they want it, not just where along the net.
##
## The second axis of the placement rework, held behind its own flag because
## contact depth is the steepest response in the attack chain: net-error rate
## against depth measured 0.013 / 0.072 / 0.151 / 0.385 at 0.36 / 1.20 / 2.50 /
## 4.00 m in the isolated harness.
##
## **On.** A hitter says how tight they want it as well as where along the net,
## inside the depth range their lane allows.
##
## It took three readings to get here and the first two were wrong, which is
## worth recording because the errors were mine and both were measurement rather
## than mechanism.
##
## The first sweep read every rate as flat and called the axis inert. It was
## not: `_depth` scaled the hitter's stable seat by `1 - unpredictability`, so a
## nominal 3.20 m applied as +/-0.4 to +/-0.9 m against a squad running 42-74
## there -- and the least predictable hitters came out with the most rigidly
## central depth, which is backwards. `SET_DELIVERY_STDEV_WORST_M` lays +/-1.4 m
## of scatter over the top of that, and the summary pooled lanes, so the front
## lanes' half metre and the pipe's four swamped the signal. Per lane the
## delivered spans are 2.18 / 1.49 / 1.93 / 1.47 m, not one five-metre spread.
##
## The second reading blamed two gates on this axis:
## `continuation set and transition attack trajectories meet at one contact time`
## and `fast-tempo identity produces shorter rallies`. Neither was its fault.
## `LANE_ZONE`'s centres had moved the base depths -- pins 0.54 m to 0.825 m, the
## pipe 4.00 to 4.70 -- so the flag was one of *two* things changing behaviour.
## Instrumented over 200 seeds, the trajectory chain shows 24 continuations and
## zero breaks with this on; both gates pass once every zone is centred on the
## constant it replaced.
##
## The one real cost was back-row legality, and it wanted a fix rather than a
## bound: a zone edge cannot guarantee legality while the delivery scatters
## across it. `lane_delivery_min_y` puts the floor on the delivered point, where
## the rule applies.
##
## Held against identical zones:
##
##   tightness   net    stuff  err    kill
##   off         0.054  0.032  0.167  0.371
##   on          0.049  0.044  0.198  0.368
##
## And a finding that outlives the flag: with tightness off, Front Quick aims at
## its zone centre of 0.55 m and delivers a 5th percentile of 1.13 m. That is
## `_reachable_contact` pulling the ball back toward a hitter who cannot reach a
## tight set inside a tempo-1 flight, which means quick hitters routinely strike
## about a metre further off the net than the play intends. It is a question
## about whether the quick is runnable, and it is not this flag's.
const ENABLE_HITTER_TIGHTNESS: bool = true


## Pay the hitter for reading the pass, the way the blocker already is.
##
## `_form_home_block` gives every blocker `preset_window * preset_share` -- 26%
## to 72% of the pass-to-release window, scaled by how well they read it -- on
## top of the set's own flight. The hitter's clock was the set flight alone.
##
## So both sides read the same pass and only one was credited for it, which
## priced tempo backwards. Measured across the six identities, kill rate fell
## monotonically with tempo shift: 0.3774 for Defensive, which slows sets down,
## against 0.3239 for Physical, which speeds them up. Running quick cost the
## offence five points of kill rate, so no bench would ever call one -- the
## opposite of the sport, and the opposite of what the tempo work was for.
##
## The hitter's share is deliberately larger than the blocker's best. A hitter
## knows the play and leaves on the pass; a blocker is guessing until the set is
## up.
## **OFF, because wiring it correctly showed the reasoning behind it was wrong.**
##
## It was first reported inert because "the dictionary does not carry the key".
## That was wrong, and the way it was wrong is worth keeping: the edit that added
## the call had simply not applied -- one level of indentation off in the anchor
## -- so the function existed and nothing called it. The identical figures were
## explained with a data story instead of a single grep for the call site, which
## would have taken one command and said so immediately.
##
## Wired properly, the credit does arrive, and it makes the tempo pricing
## *worse*: Defensive moves 0.3774 to 0.3795 on kill rate and the other three
## identities do not move at all.
##
## The mechanism was misread. `preparation_time_seconds` is
## `set_contact_time - release_time`, so it is not a fixed pass-to-release period
## the two sides share -- it **grows with slower sets and is zero for quick ones**,
## which is why only the identity that slows sets down responded. Crediting the
## hitter with it therefore widens the advantage of the high ball rather than
## narrowing it.
##
## So the real asymmetry is not "the blocker is paid and the hitter is not". It is
## that the blocker's window is passed in as a *constant* while the hitter's is a
## quantity that shrinks to nothing exactly when tempo matters. That is the thing
## to fix, and it is a different fix from this one.
const ENABLE_HITTER_PRESET_WINDOW: bool = false


## Make the run-up point at the net.
##
## `approach_start_position` picks a start offset from a lane angle and then
## blends it toward wherever the hitter is standing, so the angle it solved for
## is discarded whenever the voli is out of position. The runway got the right
## *distance* and the wrong *direction*: a tempo-2 outside ran parallel to the
## tape and arrived sideways, which is visible in playback and was reported from
## it rather than found in a probe.
##
## The lateral leg is not negotiable -- they have to reach the pin -- so the depth
## gives instead, lengthening the runway until the angle is inside
## `MAX_APPROACH_ANGLE_DEGREES`. That keeps the destination and the shape, and it
## costs the hitter time, which is the honest price of being out of position.
const ENABLE_PERPENDICULAR_APPROACH: bool = true


## Time a set by how high it was put up, instead of by a ground-to-ground lob.
##
## **On, and the re-fit it was waiting for has landed.**
##
## A set is described by its height -- that is what a coach means by first tempo
## and what a high ball *is* -- so `_set_arc` solves the hang time from an apex
## through `BallFlightModel.duration_for_apex`. The launch-angle table it
## replaces could not express a set at all: at the six to ten degrees it calls a
## quick, the only ball that climbs the metre from a setter's hands to a
## hitter's over four metres is one struck at 26 m/s.
##
## It was held off for one pass because the new times are right and every
## approach constant in the engine had been fitted against set flights a third as
## long -- 0.65 s to 1.47 s against 0.23 s to 0.69 s. With real hang times every
## hitter reached every mark, home attack quality went to 1.000 and the opponent
## stopped swinging. That was never an argument for the wrong times; it was the
## floor defence being calibrated against them.
##
## Landed together with two things it cannot land without: the home defence now
## times the ball off the swing rather than off a lofted classifier, and
## `DIG_SOLO_SHARE` and `DIG_ATTACKER_ADVANTAGE` are re-fitted against the sport.
## Measured over 700 rallies, both serving sides:
##
##                        before    after   target
##     kill rate           0.542    0.481   0.45 - 0.50
##     dig rate            0.341    0.478   0.35 - 0.55
##     stuff rate          0.065    0.112   0.08 - 0.14
##     home kill rate      0.724    0.531
##     opponent kill rate  0.276    0.415
##     swing balance       0.681    0.767   near 1.00
##
## `tools/run_rally_balance_probe.gd` is that reading.
const ENABLE_SET_HEIGHT_TIMING: bool = true
