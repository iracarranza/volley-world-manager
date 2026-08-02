# Rally Readiness and Outcome Calibration

Review date: 2026-08-01

Status: **READ-ONLY EVIDENCE; NOTHING GATED ON IT YET**

---

## Where this stands right now

Everything below this section is a chronological record of how the engine got
here, including attempts that were measured and reverted. Read this part for the
current state; read the rest for why a constant is what it is.

### Measured, on a generated population (400 rallies)

| metric | measured | SE | band | |
|---|---|---|---|---|
| side-out rate | 0.568 | 0.025 | 0.58 – 0.78 | 0.5 SE short |
| ace rate | 0.038 | 0.010 | 0.02 – 0.10 | ok |
| serve error rate | 0.140 | 0.017 | 0.08 – 0.20 | ok |
| kill rate | 0.499 | 0.025 | 0.38 – 0.60 | ok |
| attack error rate | 0.183 | 0.019 | 0.06 – 0.20 | ok |
| stuff rate | 0.054 | 0.011 | 0.03 – 0.14 | ok |
| block touch rate | 0.396 | 0.025 | 0.15 – 0.45 | ok |
| mean contacts | 5.86 | — | 4.0 – 9.0 | ok |

Seven of eight, with side-out half a standard error short of its floor.

**The sides are closer but not even.** `home_attack_share` is **0.632** at this
sample size (141 kills to 82), which is 4 standard errors from even and
therefore a real residual rather than noise. A 180-rally sweep read 0.567 and
was reported as "even"; that was an overstatement drawn from a sample with too
little power, and the larger measurement supersedes it. The first-ball set path
moved the imbalance from 0.871 to 0.632, which is most of it, not all of it.

Side-out sitting below its floor is likely the same fact seen from another
angle: the receiving team's first-ball attack is not advantaged enough over the
serving team's transition.

### The block and dig constants were checked and left alone

Re-derivation was attempted and found nothing to change. Every distribution the
block and dig govern -- stuff 0.054, block touch 0.396, kill 0.499, rally length
5.86 -- sits inside its band with standard errors an order of magnitude smaller
than the distance to either edge. Moving a constant would trade one in-band
value for another.

What the attempt did fix was the instrument. `ExecutionScaleCalibration`
modelled only a solo wall, and once blockers began reading the pass a second
blocker reached the lane often enough that its predicted block touch rate was
0.133 against a measured 0.428 -- three times out. A predictor that wrong is
worse than none, because a constant gets tuned against it. `block_values()` now
takes an assist and the tool reports a sealed double; the prediction is 0.390
against 0.396 measured.

### Settled

- Every contact resolves through **one** formula on **one** scale: execution is
  capability (normalised to a fraction of an ideal player) times opportunity (a
  product, because an act is only as good as the worst thing about it). The
  serve, the set, the swing, the block and the dig each had two or three copies
  before; each now has one.
- Flight timing is force-derived from distance and launch angle rather than
  read from a duration table.
- Capability constrains outcomes, never permission: a player may attempt
  anything, and `AttemptJudgment` decides whether they back off.
- Blockers read the pass rather than starting at set contact, so closing is a
  real physical question and a late block is genuinely late.
- Consistency is an attribute: execution spread narrows with composure and the
  technical rating governing the act.
- Sweeps run on a generated population. The hand-authored fixture leaves every
  attribute a role does not name at 50, and every calibration before this was
  measured on a squad of near-identical average players.

### Known broken, in priority order

1. **A residual home advantage of 0.632.** Down from 0.871, and the remaining
   difference has not been located. The set path, the target scan, familiarity,
   tempo demand and the overreach penalty are all mirrored now.
2. **Only the outside hitter registers in results.** A +15 hitter moves the home
   win rate by 3.7-5.4 SE. The setter now reads 2.7 SE on the downside -- the
   first non-hitter signal in the project -- but its two directions disagree,
   and the middle blocker, libero and opposite remain under 1 SE. Three
   execution-side hypotheses were tested and rejected. The measured cause is
   that those roles have large *decision* channels (0.19-0.32 of block quality
   for choosing a lane, 0.109 for choosing a hitter) and negligible execution
   ones (~0.02), and the engine gives decisions no outcome channel at all.
3. Side-out sits half a standard error below its band floor, probably as a
   consequence of 1.

### Symmetry is checked, with a caveat about its power

`home_attack_share` must stay within 0.12 of even. Both squads are drawn from
the same generator, so a persistent gap is an engine defect rather than a
difference between teams. Eight asymmetries were found in one session, each the
same defect -- the home team modelled fully, the opponent as a simplified
parallel implementation -- and each found by accident hours after it was
introduced.

**The check runs at 80 rallies to keep the suite quick, where the share carries
a standard error near 0.07.** It will catch a gross regression and will miss a
subtle one; the 0.632 residual above was found by a 400-rally sweep, not by this
check. Run `outcome_calibration()` directly at a larger sample before concluding
the sides are even.

### Tools

```
godot --headless --path . --script res://tools/run_execution_scale.gd     # ~8s
godot --headless --path . --script res://tools/run_role_sensitivity.gd    # ~4m
```

The first prints the attack, block and dig scales and the contest shares their
margins imply, without resolving a rally -- use it to set a constant. The second
is the readiness gate: whether an attribute change is visible in results at all.
`RallyReadinessReport` remains the authority on whether the assembled engine
plays like volleyball.

---

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

### Eighth pass: the opponent link, and why propagation was the wrong hypothesis

`_resolve_opponent_transition()` now takes the same `incoming_quality` the home
side does, fed from all three of its callers -- the opponent's dig of a home
swing, their serve reception, and their dig of a home continuation. Both
transition sets also now read the same five attributes through
`_transition_set_capability()`. They previously read different ones (this side
set_accuracy, court_vision, decision_making; the home side set_accuracy,
ball_control, composure), so a setter improved on one team's terms was not
improved on the other's -- and neither formula referenced `hand_control` or
`tempo_control` at all, so two of the four attributes a setter is built on
reached nothing after the first contact.

The link works. Unlike the home-only version, the sweep moved:

| | kill | side-out | contacts | attempts |
|---|---|---|---|---|
| home link only | 0.119 | 0.472 | 10.89 | 436 |
| both sides linked | **0.154** | **0.528** | 10.48 | 417 |

**And role sensitivity did not move at all.** Middle blocker, libero and setter
remain at 0.0-0.3 SE, with the setter now reading precisely the attributes the
test boosts.

That settles it: propagation was the wrong hypothesis, and the arithmetic says
why. A setter at +15 raises transition capability by about 0.108. Through the
ball-usability factor that is roughly +0.087 of set quality; through
`SET_OPPORTUNITY_WEIGHT` at 0.40 that is about +0.035 of the swing's opportunity
multiplier, and about **+0.021 of attack quality**. Attack execution carries
±0.10 of its own noise, the block contest ±0.13, the dig ±0.10.

**A +15 attribute change one contact upstream is worth a fifth of the noise on
the contact it feeds.** Every contact adds a fresh random term of similar size,
so any contribution more than one link from the terminal act is drowned before
it reaches the scoreboard. The hitter registers because their attributes enter
the terminating contact directly.

The fix is therefore not another link. It is that **per-contact noise is a flat
constant for every player**, so consistency is not an attribute. A great setter
and a poor one have identical variance; only their means differ, and the means
are separated by less than the shared noise. Making execution variance shrink
with the attributes that should govern it -- composure, the technical control
ratings -- is what would let a standout register through a chain, and it is the
mechanism behind "standout players should have a consistent high impact" rather
than a merely higher average one.

### Ninth pass: consistency as an attribute, and a third failed hypothesis

Every contact carried a flat execution spread -- the same noise for a
world-class player and a replacement-level one -- so consistency was not an
attribute. `_execution_spread()` now scales it by composure plus the technical
rating governing the act, with a floor share so nobody executes identically
twice. Applied at the swing, the dig, the block contest and all three sets.

A defect was found while wiring it. `_resolve_opponent_transition()` computes
its set quality **twice** -- once provisionally to estimate flight time, once
authoritatively after the hitter and contact point are known -- and the previous
pass moved only the first onto the shared model. The propagation link and the
aligned attribute list reached the estimate and never reached the ball. That
means the eighth pass's conclusion was drawn against a half-wired link.

With both computations on the model and consistency live:

| | side-out | kill | stuff | touch | contacts |
|---|---|---|---|---|---|
| before | 0.528 | 0.154 | 0.074 | 0.369 | 10.48 |
| after | **0.567** | 0.140 | 0.098 | **0.499** | **9.76** |

Side-out and rally length both moved toward their bands. Block touch left its
band, and the cause is known: symmetrising the block contest noise from
`(-0.14, +0.12)` to `±0.13` raised its mean by 0.01, and tighter spreads for
good blockers make their wins more reliable.

**Role sensitivity still did not move.** Middle blocker and setter rose from
0.2-0.3 SE to 0.8 SE, but with incoherent signs -- the setter reads −0.036 at
+15 and −0.021 at −15 -- which is noise presenting as a larger number, not
signal.

Three hypotheses have now been tested and rejected against the same measurement:
propagation of contact quality, the strength of the set-to-swing coupling, and
per-contact consistency. The arithmetic behind the third explains why it could
not have worked: a setter's own consistency narrows the setter's variance, but
the signal still has to survive the hitter's ±0.10 and the block's ±0.13, and
boosting the setter does nothing to either.

What is left is not a tuning question. **A setter's real value is decisions --
which hitter, which tempo, what the block is shown -- and this engine gives
those no outcome channel.** The play chooses the tempo, `_choose_opponent_attack`
picks the hitter by ratings, and the setter's attributes only nudge the quality
of a decision someone else made. The same is true of a middle blocker, whose
value is committing and reading rather than the height of their hands. Until a
decision made well beats a decision made badly, those roles cannot register, and
no execution-side change will make them.

### The arithmetic on a decision channel, checked before building it

Three execution-side hypotheses failed in a row, each after being built. This
one was measured first.

A decision channel is worth building only if the options differ. The gain from
choosing well is bounded by the spread between the best option and the average
one; a setter's judgement can only ever capture a fraction of that.

| axis | spread | vs the yardstick |
|---|---|---|
| **who to set** -- best hitter vs mean hitter, one team | **0.109** | 1.8x |
| **where to set** -- block quality at a sealed lane vs a beaten one | **0.258** | 4.2x |
| a setter's execution nudge, as tried three times | ~0.02 | 0.3x |

The yardstick is the hitter's own +15, which raises attack quality by **0.061**
and measured 5.8 SE. Both decision axes are larger than the change that is
already clearly visible; the execution nudge is a third of it, which is why
propagation, coupling strength and consistency all failed to move the number.

This also explains the middle blocker and the libero without needing separate
theories. A blocker's decision is whether to commit, and its payoff is the same
0.258 -- a sealed lane against a beaten one. A defender's decision is where to
stand, and the dig is steeply sensitive to arrival: 0.63 dug at an even margin
against 0.02 dug two tenths of a second late. **All three invisible roles have
large decision channels and negligible execution channels.**

One correction to the upper bound, which matters for how much of it is real. The
block re-forms around whichever lane is attacked, and the primary blocker is by
definition the one nearest it, so 0.258 is only realised when the ball goes
somewhere the blockers cannot reach within the set's flight time. That makes the
channel a function of tempo -- which is the same mechanism as a quick set
beating a block, and the reason a high ball into a formed block should feel
different from a quick one. The realised spread will be smaller than 0.258 and
larger than zero, and it is worth measuring on the real block geometry before
committing to a design.

### The realised spread, measured on the real block

Forming the actual opponent block against every lane a setter could choose, at
the flight time each lane implies:

| tempo | spread across lanes | openest lane | set flight |
|---|---|---|---|
| 0 (quick) | 0.380 | **0.058** | 0.23 s |
| 1 | 0.380 | **0.058** | 0.33 s |
| 2 | 0.385 | **0.058** | 0.48 s |
| 3 (high ball) | 0.419 | **0.093** | 0.69 s |

The realised spread is 0.38-0.42, **larger** than the 0.258 quoted as its own
upper bound. That is not a contradiction but a mislabel: 0.258 came from
`block_values()`, which evaluates a *solo* wall, and a real formation can add an
assist. It should have been described as a solo-wall figure, not a bound.

The number that matters is the other column. **The openest lane sits at 0.058,
which is the block-quality clamp floor** -- at every tempo there is a lane with
effectively no block on it at all. The lanes tested are 0.9 m from the nearest
blocker, which is a quarter of the distance a real middle covers on a high ball.

The cause is the closing window. `close_time` starts at **set contact**:

```gdscript
var close_time := maxf(set_flight_time, 0.0) + (1.0 - set_quality) * 0.10
```

Reaction costs about 0.23 s of that and `BLOCK_PLANT_SECONDS` another 0.26, so a
high ball's 0.69 s leaves roughly 0.24 s of actual movement, and a quick set
leaves none. From a standstill that is about 0.2 m of footwork. **The block
cannot cover one metre of net at any tempo.**

Real blockers do not start at set contact. They read the pass and the setter's
body and are already moving before the ball leaves the setter's hands; the set's
flight is the last part of their window, not all of it.

So the decision channel is large, but currently for the wrong reason: a setter
who could see the block's starting position would find an open lane every time,
because the block is very nearly static. Fixing the window's origin is a
prerequisite -- it will shrink this spread toward something a real setter has to
work for, and it is also what would give a middle blocker's commit decision the
leverage it should have. The spread should be re-measured afterwards, because
the number that justifies building a decision channel is the one measured
against a block that can actually move.

A smaller defect found alongside it: `_blocker_close_fraction()` reads
`live_positions` for its starting point, which is the *home* dictionary, so
opponent blockers are always placed from static rotation slots rather than where
the rally actually left them. Harmless today only because the two id ranges do
not overlap.

### The closing window fixed, and re-measured

Blockers now read the pass. `close_time` gains the pre-set window --
`second_contact_window + release_interval`, about 1.1 s -- of which a blocker
spends a share moving rather than waiting.

That share is not flat. During the pre-set window nobody knows where the set is
going, so a blocker who reads the pass and the setter's body moves early *and*
the right way, while one who does not has to wait for the release. A flat share
was tried first and gave every blocker the good version of that: 0.19 stuffs and
0.64 touched, with reading worth nothing. It now runs
`lerp(0.26, 0.72, read_quality)`.

**The realised lane spread, re-measured on the fixed block:**

| tempo | spread before | spread after | openest lane before | after |
|---|---|---|---|---|
| 0 (quick) | 0.380 | 0.317 | **0.058** | 0.201 |
| 2 | 0.385 | 0.194 | **0.058** | 0.324 |
| 3 (high ball) | 0.419 | 0.323 | **0.093** | 0.324 |

The openest lane is no longer empty -- it was at the block-quality clamp floor at
every tempo, and now carries a real block. The spread narrowed to 0.19-0.32, and
that is the honest number a decision channel has to be judged against. Against
the yardstick (a hitter's +15 is 0.061 of attack quality and measures 5.5 SE), a
setter capturing even a third of a 0.25 spread is still worth more than the
change that is already clearly visible. **The decision channel survives its own
re-measurement.**

**Rally outcomes.** Side-out and rally length entered their bands for the first
time in the project's history.

| | side-out | kill | atk err | stuff | touch | contacts | in band |
|---|---|---|---|---|---|---|---|
| before | 0.567 | 0.140 | 0.124 | 0.098 | 0.499 | 9.76 | 4 of 8 |
| after | 0.567 | 0.140 | 0.134 | 0.143 | **0.610** | **8.91** | 4 of 8 |

`BLOCK_ASSIST_SHARE` came down from 0.55 to 0.34 because doubles now actually
form -- it was set when they almost never did. The alternative was measured:
leaving it at 0.55 puts five metrics in band rather than four, including
side-out at 0.583, but fails the home stuff-block regression check. A failing
check disqualifies a better-looking table.

**Block touch at 0.610 is the outstanding regression.** The contest margins were
derived against a block that could not move; now that it can, they need
re-deriving, and that is a bounded piece of work with the harness rather than an
open question.

Role sensitivity moved but did not pass. The middle blocker reads +0.036 at +15
and -0.029 at -15 -- coherent signs for the first time, at 0.9 and 0.7 SE. The
role-boost list also changed: it now comes from
`VolleyballPlayer.POSITION_WEIGHTS`, the game's own definition of a role, rather
than four attributes chosen here. The previous list gave the middle blocker
nothing their *read* runs through, so a change meant to make reading matter
could not have registered however large it was.

### Block margins re-derived, the dig re-derived, and a hollow result

Re-deriving the margins against the mobile block (0.22 / 0.18 / 0.10) put block
touch in band at 0.273 -- and rallies went to 14.9 contacts on 600 swings for
109 terminal outcomes. The block outcome tally said why: the block was beaten on
72% of swings, and **82% of the swings that reached the floor were dug**. The
limiter had moved to the dig.

`DIG_ATTACKER_ADVANTAGE` went 0.09 to 0.20 and `DIG_SOLO_SHARE` 0.75 to 0.62. A
clean swing beating a set defence should not be the exception, and at 0.09 an
even contest was near a coin flip on a scale where the two sides sit at parity.

| | side-out | kill | atk err | stuff | touch | contacts | in band |
|---|---|---|---|---|---|---|---|
| before | 0.567 | 0.140 | 0.134 | 0.143 | 0.610 | 8.91 | 4 of 8 |
| after | 0.500 | **0.542** | 0.075 | 0.033 | 0.354 | **6.99** | 7 of 8 |

**Kill rate entered its band for the first time in the project**, and seven of
eight metrics sit inside their references.

### That 7 of 8 is hollow, and the reason matters more than the number

The terminal outcomes across the same 180 rallies:

```
kill 117    opponent_kill 13
```

**The home attack wins nine times as often as the opponent's.** The aggregate
distributions look like volleyball because one side is dominating, not because
the sport is balanced -- side-out at exactly 0.500 is the tell, and the role
sensitivity tool now reports a baseline home win rate of 0.779 where it read
0.407 an hour earlier. Every per-rally rate above should be read as the average
of a strong team and a weak one rather than as a description of the sport.

Making the attack finally win exposed this. While kills were 12% of swings, an
attack-side asymmetry was invisible; at 54% it dominates the match. The known
differences are all on the attack path: the home swing receives
`Familiarity.attack_geometry()` and an execution modifier that the opponent
swing never gets, and the two sides choose their targets through different
functions. The tempo demand and the overreach penalty were mirrored earlier in
this session; the familiarity terms were not.

One regression check fails with it -- opponent attacks no longer reach the
sample count a fixed seed window expects, which is the same imbalance seen from
another angle rather than a separate defect.

**Nothing here should be treated as a calibration result until the two sides are
symmetric.** The next task is to finish mirroring the attack path, not to tune
anything.

### Mirroring the attack path did not fix the asymmetry

Two differences were closed. `_choose_home_attack_target()` became
`_choose_attack_target()`, taking defender positions and a mirror flag, so the
opponent searches the floor for a gap through the same function instead of
picking a depth band at random. And the opponent swing now receives the
`Familiarity` geometry and execution terms the home swing always had.

| | side-out | kill | atk err | stuff | touch | contacts | in band |
|---|---|---|---|---|---|---|---|
| before mirror | 0.500 | 0.542 | 0.075 | 0.033 | 0.354 | 6.99 | 7 of 8 |
| after mirror | 0.539 | 0.522 | 0.079 | **0.016** | 0.237 | 7.28 | 6 of 8 |

**The asymmetry barely moved: 115 home kills against 17 opponent ones, from
117 against 13.** The sensitivity baseline came down from 0.779 to 0.707, so
some of it was real, but the great majority was not these two differences.

The remaining cause is structural rather than a constant, and it is now
identified. **The opponent has no first-ball set path at all.** A home
serve-receive set runs `SetterCapabilitySystem.evaluate()` -- tempo command
against pass quality, pass recovery, contact height against reach, approach
quality bought by arriving early. An opponent serve-receive set is resolved
through `_resolve_opponent_transition()`, the same function used for a scramble
three contacts into a rally, which subtracts `set_geometry.difficulty` and has
no capability model. Every opponent attack in the game is therefore built off a
transition set.

That is not a coefficient to mirror. It is a missing path, and building it is
the next task -- after which these numbers, and the role-sensitivity numbers,
become worth reading for the first time.

The failing regression check is the same imbalance from another angle: opponent
attacks are too rare for a fixed seed window to sample the count it expects.
Widening the window twice did not fix it, which is itself the evidence.

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
