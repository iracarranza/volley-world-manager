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

### A defect this exposed

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
