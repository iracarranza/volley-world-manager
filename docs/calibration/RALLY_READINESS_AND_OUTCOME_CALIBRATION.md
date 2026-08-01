# Rally Readiness and Outcome Calibration

Review date: 2026-08-01

Status: **READ-ONLY EVIDENCE; NOTHING GATED ON IT YET**

`RallyReadinessReport` answers two questions the 476-check suite cannot. Every
existing check verifies a *mechanism* in isolation -- a formula is monotonic, a
trajectory chains, an attribute changes an option. None measures the assembled
result, which is why a five-point attack-target table survived the entire suite:
no check ever looked at where balls actually land.

Both entry points drive the ordinary resolver and read what it produced. Neither
changes an outcome, and neither enables a flag.

## 1. Does it play like volleyball?

`outcome_calibration()` over 180 rallies, both serving sides:

| Metric | Measured | Reference band | |
|---|---|---|---|
| side-out rate | 0.739 | 0.58 – 0.78 | ok |
| ace rate | **0.000** | 0.02 – 0.10 | outside |
| serve error rate | **0.022** | 0.08 – 0.20 | outside |
| kill rate | **0.828** | 0.38 – 0.60 | outside |
| attack error rate | **0.000** | 0.06 – 0.20 | outside |
| stuff rate | **0.172** | 0.03 – 0.14 | outside |
| mean contacts | **9.97** | 4.0 – 9.0 | outside |

The bands are approximate tuning references, deliberately wide, and should not
be read as truth. Four findings are unambiguous regardless of where exactly the
bands sit:

**There are no aces and no attack errors at all.** Not "few" -- zero across 180
rallies. Two entire terminal outcomes the resolver can produce never occur. Any
attribute intended to influence serving aggression or attacking risk currently
has nothing to express itself through at the point where it should matter most.

**The kill rate is 0.828.** Once a rally reaches a third contact, the attacking
team scores five times out of six. Combined with a zero attack-error rate, the
attack phase is close to deterministic: get to the swing and win the point.

**Serve errors are 2.2%.** Serving carries almost no risk, so serve aggression
is nearly free.

Together these describe an engine where offence is dominant and unforced error
does not exist. That is a balance finding, not a bug report, and it is the first
time the project has been able to state it.

`mean_contacts` counts resolved contact events rather than ball touches, so its
band is the least trustworthy row here; treat it as a rally-length trend rather
than a target.

## 2. Is the persistent engine ready to take over?

`rollout_readiness()` over 180 rallies. Only opponent serves reach the shadow
pipeline, so 87 rallies reach a boundary at all.

| Boundary | Eligible | No candidate | Rejected |
|---|---|---|---|
| reception | 12 (13.8%) | 75 (86.2%) | 0 |
| setter | 5 (5.7%) | 75 (86.2%) | 7 |
| attack | 4 (4.6%) | 75 (86.2%) | 8 |
| block | 12 (13.8%) | 75 (86.2%) | 0 |

**The binding constraint is candidate production, not candidate quality.** In
86% of rallies the shadow pipeline produces nothing for the audit to judge. Of
the rallies that do produce a candidate, the audits reject very few, and the
reasons are specific and physical rather than structural:

- setter: `no_shared_perceived_and_physical_action` (7),
  `setter_contact_unreachable` (5), `no_physically_executable_action` (5)
- attack: `selected_action_not_executable` (8), `attack_contact_unreachable` (7)
- reception and block: nothing rejected once a candidate exists

So the migration is not blocked by information-boundary violations, state
mutation, or trajectory contract failures -- the things the gate sequence spent
the most effort on. It is blocked by the shadow pipeline not producing a
candidate most of the time, and secondarily by a handful of reachability
failures where the chosen action cannot physically be executed.

**No flag should be turned on at these rates.** At 5-14% eligibility a flag
produces a bimodal match: most rallies resolved by the legacy engine, a minority
by the persistent one, with different ownership and timing rules. That is harder
to tune than either engine alone, because a tuning change lands on a shifting
fraction of rallies. Gate 14 separately measured receiver ownership agreement at
73.3%, so the minority that promoted would also frequently pick a different
receiver.

## A defect in the first version of this report

The initial implementation ranked every `failure_reason` it saw, and produced
fifteen reasons tied at exactly 75 for reception. That is the signature of an
audit with nothing to audit: when no candidate exists, every check fails at
once, and a naive tally reports one defect as fifteen.

`ABSENCE_MARKERS` now separates "no candidate was produced" from "a candidate
was produced and rejected", and only the latter contributes to the ranking. The
distinction is what turns the output from noise into the list above. A
regression check asserts no reason is ever counted more often than there were
candidates to reject, so the collapse cannot silently return.

## Using these

```gdscript
RallyReadinessReport.outcome_calibration(120, 900000)
RallyReadinessReport.rollout_readiness(120, 910000)
```

Both take a sample count and a base seed and are deterministic. The suite runs
each at a reduced sample count to keep the regression pass quick; run them
directly with larger samples before drawing a balance or rollout conclusion.


## First calibration pass: three changes, measured after each

| | side-out | ace | serve err | kill | atk err | stuff | contacts |
|---|---|---|---|---|---|---|---|
| baseline | 0.739 | **0.000** | 0.022 | **0.828** | **0.000** | 0.172 | 9.97 |
| 1. drop flat reception bonus | 0.744 | 0.006 | 0.022 | 0.811 | 0.000 | 0.189 | 10.20 |
| 2. normalise opponent serve weights | 0.728 | **0.028** | 0.022 | 0.806 | 0.000 | 0.194 | 10.11 |
| 3. block pressure on the swing | 0.672 | 0.028 | 0.022 | **0.767** | 0.000 | 0.233 | 11.21 |

**Aces now occur and sit in band.** Reception carried a flat `+ 0.30` that almost
exactly cancelled the best serve in the game, and the opponent serve weights
summed to 0.72 so an opponent server with every rating at 100 produced 0.72.
Removing the bonus and normalising the weights moved reception's floor from
0.387 to 0.112, with 10.7% of receptions now below the 0.18 ace threshold.

**Kill rate fell from 0.828 to 0.767** once the block a swing is hit into began
to pressure it. `_resolve_opponent_block()` was split into `_form_opponent_block()`
and `_contest_opponent_block()` so the formation -- which never needed the
attack's quality -- can be resolved before the swing is scored, and settled
against it afterwards with the same numbers.

### Attack errors remain unreachable, and the obvious fix overshoots

Attack execution sums 1.50 of positive weight: 0.75 of ratings, 0.50 of approach
fit, 0.25 of set quality. Normalising it by that total -- exactly the fix that
worked for the serve -- was tried and reverted. Attack quality fell below the
block's `contest > attack_quality - 0.30` funnel test on nearly every swing, so
almost every attack was touched into a continuation and rally length ran past
the exchange limit. The measured symptom was a tenfold slowdown of this sweep.

The two scales are coupled: the block's contest thresholds are written against
the current, inflated attack range. Re-deriving them together is the work; the
revert is recorded in the resolver at the site rather than left as a silent
near-miss.

## The kill rate was measuring the wrong thing

Every number above the line uses a broken denominator, and the correction
changes what the first calibration pass appeared to achieve.

`kill_rate`, `attack_error_rate` and `stuff_rate` were scored against *terminal*
attacks only -- the swings that ended a rally. A swing that got dug, and every
swing in a long rally except the last, was excluded from the denominator
entirely. That makes the three rates functions of each other rather than
independent measurements: when stuffs and errors fall, the kill rate rises even
if not one extra ball hit the floor. The reported jump from 0.767 to 0.842
across the block work was exactly that artefact.

The sport scores all three per *attempt*, and so does the report now. Every
swing records an ATTACK event before its outcome is known, so the attempt count
was already sitting in the event stream. A regression check asserts the attempt
count is never below the terminal count, so the denominator cannot quietly
collapse back.

Re-measured on both sides of the change, the correction rewrites the verdict:

| | side-out | ace | serve err | kill | atk err | stuff | contacts | attempts |
|---|---|---|---|---|---|---|---|---|
| before block work (terminal denominator) | 0.672 | 0.028 | 0.022 | 0.767 | 0.000 | 0.233 | 11.21 | -- |
| before block work (per attempt) | 0.672 | 0.028 | 0.022 | **0.294** | 0.000 | **0.089** | 11.21 | 425 |
| after block work (per attempt) | 0.633 | 0.028 | 0.022 | **0.296** | 0.000 | 0.055 | 12.26 | 469 |

The block work moved the kill rate by 0.002. It never was near 0.83; the stuff
rate never was above its band. Both readings were the denominator. What the
block work did do is real and separately measured -- block quality spread from a
0.04 interquartile band to 0.23, and `close_time` became a consequence of the
set's actual flight rather than a tempo lookup -- but it did not change the
balance of the sport, and the earlier table said it had.

## Second pass: one contest, and capability at the third contact

| | side-out | ace | serve err | kill | atk err | stuff | contacts | attempts |
|---|---|---|---|---|---|---|---|---|
| after block work | 0.633 | 0.028 | 0.022 | 0.296 | 0.000 | 0.055 | 12.26 | 469 |
| 4. one block contest | 0.656 | 0.028 | 0.022 | 0.339 | 0.000 | 0.054 | 11.29 | 425 |
| 5. capability at contact 3 | 0.594 | 0.028 | 0.022 | 0.316 | 0.000 | 0.072 | 11.38 | 431 |

**The opponent block was deciding its outcome three times.** The contest ran,
then a scouting adaptation re-ran it with its own stuff margin and its own
close threshold, then a flat 18-48% roll gave a beaten block another chance at a
hand touch -- a roll that duplicated the contest's own `funnel` band and, having
been written against a `primary_close` that was 99.5% saturated, fired near its
ceiling on nearly every swing. None of the three existed on the home side or on
the continuation path. Scouting now sharpens the formation before the contest,
the extra roll is gone, and the contest is the whole answer.

**Capability stopped removing options at the third contact.** A hitter whose
run-up had not unlocked power had their power swing silently rewritten into a
roll shot -- and because the substitute was always executable, no swing in the
game could be bad enough to be an error. The hitter's judgment now decides
whether to take the safer ball, and swinging anyway costs quality in proportion
to how far outside the approach it sits. `AttemptJudgment` holds the shared
read, so the setter's second contact and the hitter's third use one curve.

### What is actually keeping rallies alive

Measuring the block's outcome mix, which nothing had done:

| stuff | funnel | touch | miss |
|---|---|---|---|
| 31 | 142 | 211 | 47 |

**Only 11% of swings get past the block untouched.** `touch` and `funnel` both
recycle the ball to the attacking team's coverage, so four swings in five come
straight back and rallies run to 11.4 contacts against a 4-9 band. The margins
that produce this were set while chasing the stuff rate, with no view of the
touch and funnel shares -- the same blindness the terminal-denominator kill rate
came from.

The margins are not independently fixable, because `block_quality` and
`attack_quality` are not on a common scale: one sums 1.08 of weight, the other
1.50 against penalties, and they are compared with margins of 0.06. A margin
only means something once both are fractions of the same ideal.

### Third pass: a late block is now actually late

| | side-out | ace | serve err | kill | atk err | stuff | contacts |
|---|---|---|---|---|---|---|---|
| capability at contact 3 | 0.594 | 0.028 | 0.022 | 0.316 | 0.000 | 0.072 | 11.38 |
| 6. closing through the traversal solver | 0.656 | 0.028 | 0.022 | 0.369 | 0.000 | 0.021 | 11.37 |

`primary_close` resolved at **exactly 1.0 on every block in the game**, and had
done so through all of the work above. The earlier claim that unsaturating the
block spread its quality was true of the quality but not of the close: the
spread came from assists appearing, not from anyone failing to get there.

The cause was that the closing budget was `maximum_speed × available_time`. The
blocker left the ready stance already at top speed, never decelerated, and was
credited with shuffling right up to the instant of contact. A middle covering
three metres to the pin sealed it every time, so "late block" described nothing
and neither tempo nor footspeed could change an outcome at the net.

Closing now asks the shared traversal solver how long the move actually takes
from a standstill, and takes the block jump off the end of the window -- a
blocker still moving when the ball arrives has not blocked it. Closes now range
0.00-1.00 with a mean of 0.92, and the stuff rate fell below its band, which is
the honest consequence: the block was collecting stuffs it had not earned.

`block_touch_rate` and `block_close_saturation` are now reported, the first
against a band. A saturated close is exactly the kind of defect 477 mechanism
checks cannot see -- each asks whether a formula responds to its input, never
whether the input varies in play -- so a regression check fails when saturation
returns. Setting the arm reach to the full court width was confirmed to trip it.

### Fourth pass: the sweeps were measuring a squad of clones

`seed_vertical_slice_data()` sets only the attributes each player's role names;
every other one stays at `VolleyballPlayer`'s default of 50. Across the eight
fixture players, attack_accuracy runs 0.50/0.50/0.50/0.68/0.76 and block_timing
is 0.50 at every quartile. A generated population spreads those same attributes
0.61 to 0.94.

**Every outcome calibration in this project had therefore been measured on a
roster of near-identical average players**, which is why no sweep could ever
have answered the question of whether a standout hitter feels like one. The
sweeps now re-attribute both rosters from `PlayerGenerator` before measuring,
keeping every id, position, rotation and play intact. `fixture` remains
available because the rest of the suite runs on it.

The sweeps also record the situation a swing was actually hit from, which
immediately corrected an assumption: **the hitter is late at the median**, with
an arrival margin of −0.115 s and a quarter of swings more than half a second
late. The execution harness had assumed an on-time median, and every constant
sized against that came out wrong.

| | measured on generated population |
|---|---|
| set quality | min 0.124 · p25 0.476 · med 0.597 · p75 0.717 · max 0.945 |
| approach fit | min 0.207 · p25 0.354 · med 0.548 · p75 0.674 · max 0.736 |
| arrival margin | min −1.392 · p25 −0.365 · med −0.252 · p75 +0.255 |

### Fifth pass: the block, on a real population

| | side-out | ace | serve err | kill | atk err | stuff | touch | contacts |
|---|---|---|---|---|---|---|---|---|
| generated, before | 0.272 | 0.039 | 0.022 | 0.043 | 0.145 | **0.281** | **0.677** | 8.71 |
| generated, after | 0.306 | 0.039 | 0.022 | 0.048 | 0.097 | **0.067** | 0.459 | 14.42 |

Two structural defects, both invisible until the scales were printed side by
side. Closing was a **0.14 additive term** inside the block's contact skill, so
a blocker who reached a fifth of the lane still scored 84% of a sealed block --
making the close physical had changed the number and not the outcome. And a
solo block was weighted at **0.78 of a full wall**, so one blocker outscored a
typical swing. Closing now multiplies, and the assist closes part of what the
primary leaves open rather than adding a flat share, which makes beating one
blocker ordinary and a formed double the thing a hitter has to solve.

Stuff rate, attack errors, aces and close saturation are now all in band.

### The four-cell test that settled a failing check

The home stuff-block balance check read 0.379 against its 0.22 ceiling, and the
tempting move -- rerun it on a population where it passes -- is indistinguishable
from tuning until the rule is fixed in advance. So it was: measure home-block
and opponent-block stuff rates on both populations, and let the four cells
decide. Home high on both means a code asymmetry, home high only on the fixture
means the roster is the artefact, high everywhere means the block rebalance is
wrong and gets reverted.

| | home block stuff | opponent block stuff |
|---|---|---|
| fixture | **0.281** | 0.009 |
| generated | 0.061 | 0.068 |

Home high only on the fixture. The check moved to a generated roster with its
assertion untouched.

The fixture cell also exposed something real: home swings averaged 0.264 against
opponent swings at 0.360. Unifying the three execution formulas had left the
opponent as the only swing of the three paying neither a tempo demand nor an
overreach penalty -- a systematic edge to one side of the net with nothing
behind it. Both now apply. The opponent's back-off still cannot re-aim the shot,
because its target is chosen before the run-up is evaluated; that is the
remaining asymmetry and it is named at the site.

### The next binding constraint is the dig, and it is a fourth scale

Kill rate is 0.048 and rallies run to 14.4 contacts. 599 swings produced 127
terminal outcomes: the block no longer ends rallies, and nothing else does
either. The three dig contests -- home defence, opponent defence, continuation
-- are three more formulas with three more weight totals (0.96, 0.84, 0.86) and
three different offsets, all comparing a defender composite against an attack
quality that has just been rescaled. Defence strength sits near 0.61 against a
typical swing of 0.42, so almost everything is dug.

This is the same defect the block and the attack each had, in the one place it
has not yet been fixed. It was not part of the block work and is not fixed here.

### Sixth pass: the dig and the serve, and a readiness verdict

The dig carried three formulas -- home defence summing 0.96 of weight across
four attributes, the opponent's 0.84 across two, the continuation 0.86 across
three -- all compared against an attack quality on a fourth scale with three
different offsets. They are now one `_defense_execution()` of the same shape as
the swing: capability normalised to 1.0, opportunity as a product, and a single
`_dig_contest()` carrying one explicit attacker advantage instead of three
hidden random offsets. `DIG_SOLO_SHARE` says what `BLOCK_SOLO_SHARE` says on the
other side of the net: one defender is not a whole defence.

The serve error rate could not reach its band because it could not reach its
band. Both sites summed small offsets -- `0.025 + risk * 0.07 + aggression *
0.025 - consistency * 0.065 - style * 0.02` and a near-twin -- whose **maximum**
value was 0.12 at maximum aggression against a server of zero consistency. A
rate that cannot enter its own range is not a low rate, it is an absent
mechanism. A serve now misses when the server asks more of it than their control
supports.

| | side-out | ace | serve err | kill | atk err | stuff | touch | contacts |
|---|---|---|---|---|---|---|---|---|
| before dig work | 0.317 | 0.039 | **0.022** | 0.063 | 0.118 | 0.098 | **0.504** | 12.37 |
| after dig, serve, margins | 0.472 | 0.039 | **0.094** | 0.119 | 0.103 | 0.085 | **0.372** | 10.89 |

Six of eight metrics are in band. Kill rate and rally length are not, and both
say the same thing: swings still lose more often than they win.

### Can the engine feel a better player?

The readiness question for leaving the rally simulator is not whether every
metric is in band -- it is whether an attribute change is visible in results at
all. If it is not, a training system has nothing to move. Each starter in a role
was given +15 across the four attributes that role is built on, and the home win
rate measured over 140 rallies (standard error ≈ 0.042).

| change | home win rate | delta |
|---|---|---|
| baseline | 0.500 | — |
| Outside Hitter +15 | 0.729 | **+0.229** |
| Outside Hitter −15 | 0.293 | **−0.207** |
| Middle Blocker +15 | 0.514 | +0.014 |
| Setter +15 | 0.514 | +0.014 |
| Libero +15 | −0.007 | −0.007 |

**Partial pass.** The hitter registers strongly and symmetrically -- five
standard errors, and the two directions nearly mirror each other, which is what
a well-behaved response looks like. The middle blocker, the setter and the
libero are indistinguishable from noise.

The reason is structural rather than a tuning miss: **only the attack terminates
a rally.** Kills, attack errors and stuffs are all scored off the swing, so
every other role reaches the result only through attack quality, and that
channel is heavily damped. A +15 setter moves set quality by perhaps 0.10, which
moves the opportunity factor by 0.04, which moves attack quality by under 0.02
-- below the noise the swing already carries.

This is the finding that should shape what happens next, and it was worth
getting before building anything on top of the engine. A first measurement
using side-out rather than home win rate showed the hitter at +0.14 and
suggested the engine was less responsive than it is: boosting the home squad
helps them whether they serve or receive, so side-out counts the same effect
with each sign and the two nearly cancel.

### Seventh pass: propagation, and two negative results

Every non-terminal contact reset the rally to neutral. The transition set read
only the setter's own attributes, so a dig that barely stayed up produced
exactly the set a perfect one did, and a ball clawed off the block recycled at
full quality. That is why only the swing -- the contact that ends a rally --
had any measurable effect on who won it.

Three links were built. `_resolve_home_continuation()` now takes an
`incoming_quality`, the dig's own quality feeds it, and a block touch degrades
it further through `BLOCK_DEFLECTION_CARRY`. The transition set became
capability times what the arriving ball allowed, with command buying part of a
bad ball back so the gap between setters is widest when the ball is worst.

**Two of the three did not do what was predicted, and the measurements say so.**

*Link 3 was reverted.* Raising `SET_OPPORTUNITY_WEIGHT` from 0.40 to 0.58 -- so
that a shanked set no longer leaves 60% of the swing intact -- was meant to make
the setter visible. Measured, the setter moved from 0.5 SE to 0.5 SE: nothing.
It cost real attack quality, pushed attack errors from 0.103 to 0.182, put the
home stuff-block rate back over its ceiling, and broke three trajectory coverage
windows. A change that does not achieve its stated purpose and has a cost is not
a close call.

*Links 1 and 2 are wired and almost inert.* With the set weight back at 0.40 the
sweep returns **436 attempts, 134 terminal, 10.8889 contacts** -- identical to
the run before propagation existed, on every metric except block touch, which
differs by exactly one event in 180 rallies.

The reason is path frequency, not the links. `_resolve_home_continuation()` has
two callers: the home block-recycle coverage, and the home dig of an opponent
*transition* attack. When the opponent digs a home attack the rally goes to
`_resolve_opponent_transition()`, whose set quality has no propagation at all.
Most continuations live on that side, so the links were built on the rarer of
the two paths. The symmetric opponent link is the next thing to build, and until
it exists this work should be read as scaffolding rather than a result.

The rally-length improvement seen at set weight 0.58 (10.89 to 9.15 contacts)
came from that weight, not from propagation.

### Attack errors: the floor is structural, not the threshold

Attack quality measures min 0.321 and 5th percentile 0.383, against an error
threshold of 0.29. The distribution cannot reach the threshold, and moving the
threshold up to meet it would be picking an outcome rate directly.

The cause is that execution is composed **additively**: ratings contribute
roughly 0.75 before anything else happens, so a hitter's attributes put a floor
under every swing they take regardless of the set, the approach, or the block.
A great hitter off a terrible set with no run-up should produce a bad ball.
Making opportunity multiplicative rather than additive is what gives the
distribution a low tail -- and it is the same change that lets a standout hitter
stay dominant when the opportunity is good.

### A defect the first pass exposed

The ATTACK phase of the movement timing sweep measured 1.0565 before any of
this and 1.0608 after, against a band whose upper edge is 1.06 -- it had been
sitting on the boundary all along, contained rather than verified. Shifting the
rally mix toward continuations pushed it over.

One contributor was found and fixed: the opponent attack reported its *staged*
approach start paired with its *unstaged* travel time, so the hitter was
described covering a short leg at a long leg's pace. That is the same defect the
movement-fluidity work fixed on the home side. Correcting it moved ATTACK from
1.0832 to 1.0608 and the perceptible-disagreement rate from 3.7% to 1.5%. The
residual ~6% is now named in the regression check rather than hidden inside a
band that happened to contain it.
