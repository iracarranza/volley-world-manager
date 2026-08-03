# The action vocabulary and rally spectacle (draft)

Date: 2026-08-03
Status: the vocabulary below is **a draft, not implemented**. The spectacle
score and the flow rebalance described in the second half **are implemented**
(`scripts/models/match_state.gd`).

## The problem this solves

A rally is currently legible as a sequence of phases -- serve, reception, set,
attack, block, defense -- each carrying a quality float. A viewer can see that
something happened and can read a percentage, but cannot *name* what they saw.
The distinctions exist in the simulator; they are discarded at the point of
presentation.

The goal is a closed set of named actions, so that a viewer watching a rally
can say "he got tooled" or "she dug that off her shoelaces" rather than "the
block resolved at 0.61".

## The rule that generates the vocabulary

**A name is earned by the gap between what the situation demanded and what the
player delivered.** Not by outcome quality alone.

This gives four quadrants, and only two of them get names:

| | delivered well | delivered badly |
| --- | --- | --- |
| **hard ball** | **named -- the highlight** | unnamed (expected) |
| **easy ball** | unnamed (baseline) | **named -- the blunder** |

Both named quadrants matter. A vocabulary of only highlights makes every team
look brilliant; the blunder is what makes a weak player legible as weak. And
the two unnamed quadrants are not a gap in the design -- they are the silence
that lets the named ones register.

Difficulty is already computable everywhere it is needed:

- `arrival_margin` (`flight_time - travel_time`) -- negative means the defender
  arrived after the ball. Already computed in `_choose_opponent_defender`.
- incoming ball quality -- reception quality feeding a set, set quality feeding
  a swing, `BLOCK_DEFLECTION_CARRY` feeding a recycle.
- block state at contact -- `primary_close`, formation `quality`,
  `contact_depth_from_net`.

## Serve

| name | trigger | reads as |
| --- | --- | --- |
| **Ace** | serve lands, no reception contact or reception fails outright | already an outcome; needs surfacing, not deriving |
| **Service pressure** | reception succeeds but quality below the band that permits a full offence | *the named non-terminal good thing* -- the server wins the rally without ending it |
| **Missed serve** | serve error at low selected risk | blunder quadrant: an error while playing safe |

A serve error at *high* selected risk stays unnamed. It was the price of the
attempt, and naming it would punish aggression the design wants to encourage.

## Reception

| name | trigger | reads as |
| --- | --- | --- |
| **Platform dime** | quality high **and** `arrival_margin` small or negative | passed a ball they had no business reaching |
| **Scramble pass** | quality mid-low, `arrival_margin` clearly negative, rally continues | kept it alive, offence compromised |
| **Shank** | quality very low, `arrival_margin` comfortable | blunder: an easy ball butchered |

## Set

| name | trigger | reads as |
| --- | --- | --- |
| **Dime** | set quality high **and** resulting opponent block `primary_close` low | the killer-ball equivalent: the set is what isolated the hitter |
| **Save set** | set quality acceptable off a reception below the transition-ball threshold | made something out of nothing |
| **Telegraphed** | set quality fine but opponent block forms at full strength on the pin | blunder of choice rather than execution -- the set was clean and still wrong |

`Dime` is the most important entry in this table. It is the one name that
credits a player for a point they did not score, which is the whole reason
setters are interesting.

## Attack

| name | trigger | reads as |
| --- | --- | --- |
| **Tool off the block** | attack succeeds **and** block outcome was `touch`/`funnel` **and** ball lands in | the marquee attacking moment; currently invisible |
| **Cross-court bullet** | kill, `direction == "cross-court"`, high attack quality | |
| **Line shot** | kill, `direction == "line"` | |
| **Seam kill** | kill, `direction == "seam"` | |
| **Back-row bomb** | kill from a back-row contact depth | |
| **Roll shot / Tip** | existing `attack_type`, on a kill | off-speed as a *choice* that worked |
| **Swung into the block** | stuffed at low attack quality with the block already formed | blunder: hit into a wall that was visibly there |

`attack_type` already carries `Quick attack`, `Power swing`, `Line attack`,
`Roll shot`, `Tip`, `Emergency tip`, `Short tip`. That is intent. The vocabulary
above is outcome. Both are wanted -- intent explains the choice, outcome names
the result -- but only outcome should be surfaced as a moment.

## Block

This is where the vocabulary does the most work, because it is where the
current model throws away the most.

| name | trigger | reads as |
| --- | --- | --- |
| **Roof** | `stuff` outcome | terminal, rare, the signature block moment |
| **Soft block** | `touch` outcome **and** the defence subsequently digs it | *named, positive, non-terminal* -- the blocker created the dig |
| **Funnel** | `funnel` outcome and defence converts | block did its job by directing, not stopping |
| **Got tooled** | block contacts, attack lands in | the loser's half of "tool off the block" |
| **Beaten by tempo** | block fails to form, `primary_close` low, quick attack | names a *reason* rather than a failure |

**Soft block** is the entry that delivers what you asked for two messages ago --
a wider window for the block to matter without terminating the rally. It costs
no calibration change. The event already happens constantly; it is simply never
named, so a blocker who deflects twenty balls into easy digs currently reads as
having done nothing all match.

## Defense

| name | trigger | reads as |
| --- | --- | --- |
| **Sprawl dig** | dig succeeds with `arrival_margin` clearly negative | the slide-tackle equivalent -- the single most legible action in the sport |
| **Overhead dig** | dig succeeds on a high, hard ball at short range | |
| **Cover** | attack-coverage contact succeeds off a block touch | credits the player who kept a blocked ball alive |
| **Missed the easy one** | dig fails with `arrival_margin` comfortably positive | blunder |

`arrival_margin` already exists and is already negative on exactly the balls
that should read as desperate. This table is the cheapest one to build.

## Notability budget

Names are not free. If every contact carries one, the labels become texture and
we are back where we started.

Proposed rule: **at most two named actions per rally**, chosen by margin above
the naming threshold, plus the decisive action of the final point always being
eligible. A rally with nothing exceptional in it emits zero names and reads as
what it is -- competent volleyball.

Targets to gate in the test suite:

- share of rallies containing at least one named action: **40-60%**
- named actions per rally, mean: **~1**
- share of *points* whose decisive event carries a name: **high** (this is the
  one that encodes "named actions decide rallies")

The last two are different denominators on purpose. Named actions should be
**rare per contact and dominant per point**.

---

# Part two: spectacle, flow, and why they had to be split

The momentum system was originally proposed to solve playback selection --
deciding which rallies deserve 3D. It cannot do that job in the form it was
built, and this is structural rather than a tuning problem.

## `flow_shift` measures the wrong thing

Two properties of `new_flow = clamp(old_flow * decay ± impact, -1, 1)`, using
the pre-change 0.72 decay and [0.12, 0.50] impact band:

**It saturates.** At flow +0.90 a maximum-impact rally gives
`0.90×0.72 + 0.50 = 1.148` → clamps to 1.0, a shift of **+0.10**. The identical
rally from even flow shifts **+0.50**. A team's best volleyball scores lowest
exactly while it is dominating.

**It is reversal-dominated.** At flow +0.90 a *minimum*-impact rally lost by the
leader gives `0.648 − 0.12 = 0.528`, a shift of **−0.372** -- nearly four times
the spectacular rally above. A routine sideout outranks a twenty-contact
exchange whenever it breaks a streak.

Both are correct for a momentum meter. Both are wrong for choosing what to show.

## The split

`_flow_impact` now takes a spectacle score rather than computing one inline:

- `rally_spectacle(result) -> float` is **context-free**. Endurance (contacts),
  peak execution, and a terminal flourish. It reads only the rally. Playback
  selection consumes this.
- `_leverage(set_target) -> float` is **context-dependent** -- lateness ×
  closeness.
- `_flow_impact(spectacle, set_target)` combines them for the flow update.
  Confidence continues to read `flow_shift` and is unaffected.

### Two defects found by measuring rather than reasoning

Both were in the first implementation and are fixed:

1. **Aces scored below routine stuff blocks** (0.34 vs 0.58). The three summary
   quality fields on `RallyResult` are reception, set and attack -- a serve is
   structurally invisible to them, and an ace is by definition a near-zero
   reception rally, so it scored its own brilliance as nothing. Peak is now read
   across the rally's events.
2. **Reading events pinned every rally at maximum.** Every rally emits a POINT
   event at a hardcoded quality of 1.0, so a service error into the net scored
   the same execution as an ace. POINT is now skipped.

### Measured distribution, 825 rallies over 8 matches

| outcome | mean spectacle | share |
| --- | ---: | ---: |
| serve_error | 0.193 | 16.6% |
| attack_error | 0.379 | 15.5% |
| opponent_kill | 0.524 | 13.5% |
| ace | 0.560 | 4.4% |
| counter_block | 0.600 | 5.6% |
| kill | 0.609 | 10.9% |
| blocked | 0.654 | 33.6% |

Overall p50 0.573, p99 0.722, max 0.758.

**Two things are wrong with this and neither is the formula's fault.**

The ordering is sensible but `blocked` is simultaneously the highest-scoring
outcome *and* a third of all rallies, so a highlight reel built on this today
would be one-third block stuffs. That is the uncalibrated 39.4% stuff rate
showing through, not a spectacle defect.

The distribution is also bunched: 43.9% of rallies clear 0.60 but only 1.8%
clear 0.70, so there is a cliff rather than a usable knob between them. The
cause is that `flourish` currently has three discrete levels. Once the
vocabulary lands and flourish becomes a **sum over the rally's named moments**,
the top of the range spreads out and thresholds become selectable.

**Conclusion: playback thresholds cannot be finalised until the block rate is
calibrated and the vocabulary is in.** The score is correct and in place; the
inputs it reads are not yet ready to be thresholded.

## Flow rebalance

**Decay and impact are a matched pair.** A team winning every rally at constant
impact `i` settles at `i / (1 - decay)`, so changing one alone silently
rescales the meter. The old 0.72 gave momentum a half-life of about **two
points** -- 0.72² = 0.52, so a 5-0 run was indistinguishable from a single point
by the third point after. That is recency, not momentum.

Now 0.86 with a halved impact band. Half-life rises to ~4.6 points while the
steady-state range is unchanged: 0.06/0.14 = 0.43 exactly as 0.12/0.28 was, and
0.25/0.14 = 1.79 exactly as 0.50/0.28 was. The confidence coefficient moved
0.14 → 0.28 to absorb the halved shifts, so confidence moves exactly as far as
before and only flow's memory changed. A test pins the pairing.

## Leverage was mis-specified

`max(score) / target` returns 1.0 at both 24-23 and 24-10, treating a decided
set as maximally clutch. Leverage is now `lateness × closeness`, with closeness
falling to zero at an eight-point margin.

## Identity: Spëddigh contained Pāwa Hitō

Spëddigh was 0.85 tempo variation / 0.90 transition commitment against Pāwa's
0.50 / 0.88 -- strictly better on both defining axes, leaving Pāwa with no
dimension of its own. Two regions cannot be distinct when one contains the
other.

Spëddigh now takes the highest tempo variation in the world (0.90) and settles
for merely high transition (0.78); Pāwa takes the highest transition commitment
(0.94) and the lowest tempo variation of any attacking region (0.32). One is
unpredictable, the other relentless.

A related observation worth recording: the regions carry identity in **two
different systems**, and this is fine as long as it is deliberate. Xérvu
(serve_aggression 0.92) and Taktikã (emotional_expression 0.12) are principles
regions and are cleanly implemented. Ispayk is an *attribute* region -- its
power lives in the generator. Pāwa's stated identity, sustained high-stamina
attacking, is also an attribute story; stamina and work rate are not identity
axes at all. The fix above gives it a principles axis to own, but its real
distinction should continue to live in generation.

## Still open

- Momentum-to-highlight thresholds (blocked on block calibration).
- Grouping connected rallies into highlight sequences.
- Named actions feeding `flourish` as a sum.
- Different spectacle weights for solo/double/triple blocks.
- Forced playback for set points, match points and reversals.
- Momentum timeline or graph.

The fictional-rule proposals (golden ball, coach tokens, altered court,
short-handed play) are deliberately **not** treated here as a playback solution.
Forcing 3D on a special event solves selection by fiat rather than by
identifying quality, and each such rule invalidates the calibration baseline.
They should be judged as gameplay ideas on their own merit, separately.

One unmeasured risk: quality → `flow_impact` → `flow_shift` → confidence →
`execution_scale` → quality is a closed loop. Its gain is deliberately small
(0.02-0.06 against fatigue at 0.18) so it is probably harmless, but "probably"
on a feedback loop deserves one sweep.

## What this implies for the block calibration

Left open deliberately, but the vocabulary changes the question. See
`BLOCK_CONTEST_DIAGNOSIS_2026_08_03.md` for the measured baseline of 39.4%.

If a `Roof` is a named moment, it cannot also be the routine outcome of an
attack. But "deliberately blocky" survives intact by splitting block
*involvement* from block *termination*: touches and funnels stay common, so the
block is visibly present on every swing and shapes where the ball goes, while
the terminal stuff becomes rare enough to be worth watching.
