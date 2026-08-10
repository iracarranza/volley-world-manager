# The team attribute wheel

> "What functions is this team actually good at right now?"

Reviewed against what is built. The short version: the spec supersedes the wheel
that exists, the reason it supersedes it is sound, and about two thirds of the
hard part is already computable from state the game keeps.

## The spec

1. **Primary functional contribution.** Each axis names the players who normally
   provide that function; only their relevant attributes count. A libero's
   attacking does not lower Team Attack.
2. **Secondary contribution, asymmetric.** An unusually good non-contributor
   raises the axis. An irrelevant weakness does not lower it.
3. **Form-adjusted.** Underlying ability + role utilisation + tactical fit +
   form + context → current functional contribution.
4. **Two figures, not one.** Squad talent and current performance stay separate,
   so a wheel can say *we are better than this* or *this system is getting more
   out of them than it should*.
5. **Ghost outline** for the expected shape behind the current one; detail lives
   in drill-down, not on the visualisation.

## What exists now, and why it has to go

`AttributeProfiles.amplify_team_profile` takes the six starters, averages each
of six categories across all of them, and then multiplies each axis's deviation
from the team's own mean by `TEAM_WHEEL_AMPLIFICATION = 1.6`.

The averaging is exactly what §1 forbids — the libero is in the Attack mean.
And the amplification is worth looking at closely, because **it is a fix for a
symptom of the averaging**. Its own comment says so: *"A plain average of six
starters clusters every axis into a narrow band, so a squad with a genuine
attacking identity draws almost the same hexagon as a balanced one."* That is
true, and it is true *because* averaging six people over an axis only three of
them are responsible for drags every axis toward the roster mean.

So functional selection does not need amplification retuned — it removes the
cause. An Attack axis computed over three or four attackers has real spread in
it. **Recommendation: drop `TEAM_WHEEL_AMPLIFICATION` when the axes become
functional, and re-measure before deciding whether anything replaces it.**
Keeping both would stretch a spread that is now genuine, which is the failure
the amplification comment was written to avoid.

## The axis set has to change, and the spec's own rule is the proof

The rule is *each category identifies which players normally provide that
function*. Apply it to the current six:

| current axis | who normally provides it | passes? |
|---|---|---|
| Attacking | outsides, opposite, middles | yes |
| Defensive | three different groups doing three different jobs | no — it is three axes in a trench coat |
| Setting / Control | the setter | yes |
| **Physical** | everybody | **no — there is no primary contributor** |
| Serving | everybody who serves, which is everybody | borderline |
| **Mental / Tactical** | everybody | **no** |

Physical and Mental / Tactical cannot satisfy the rule at all. They are real
properties of a *person* and they are not functions a team performs. That is the
whole argument for the spec's axis set, and it is stronger than "these six are
nicer": the current six include two that the design principle cannot be applied
to.

The spec's six — Attack, Blocking, Serve, Serve Receive, Floor Defense, Setting
— all pass, and the split of Defensive into Blocking / Serve Receive / Floor
Defense is the correction of a bucket that currently mixes `reception`,
`block_timing` and `dig_control` as though one player's job covered all three.

### The decision this forces

`AttributeProfiles.CATEGORY_ATTRIBUTES` is one table, read by the roster wheel
and the team wheel alike. Under the spec they need different sets.

**Recommendation: two sets, named as two things.** A voli's own wheel keeps
Physical and Mental / Tactical, because those *are* facts about that voli. The
team wheel uses the functional six. Forcing one table to serve both makes one of
the two wheels wrong, and it will be the team one, because that is where the
design pressure is.

The cost is honest and small: one more table, and a rule that says which object
reads which. The cost of not doing it is a person's wheel that cannot show how
athletic they are.

## The grade scale is already broken, and I now have the measurement

**Correction to something I told you yesterday: I said no grade function existed
anywhere in the codebase. One does** — `AttributeProfiles.grade()`, with eight
bands from S at 96 down to C− at 50. What is wrong with it is worse than it not
existing, and it is the §0 pattern again.

Measured over 4,000 generated volis × 7 categories, 28,000 readings:

| grade | share |
|---|---|
| S | 0.03% |
| A | 0.09% |
| B+ | 0.31% |
| B | 2.10% |
| B− | 8.84% |
| C+ | 11.28% |
| C | 18.12% |
| C− | 16.00% |
| below C− | **43.23%** |

Four of the eight bands together describe **under half a percent** of the
population, and the single largest bucket is everything beneath the lowest named
band. An eight-band scale is functioning as a three-band scale with a decorative
tail. Every threshold sits above the distribution it acts on.

The fix is percentile-anchored bands rather than absolute ones, and the earlier
measurement work says they have to be cut **three ways**:

- **per axis**, because median Attacking is 57 and median Mental / Tactical is
  45 — one absolute scale reports a property of the generator as a property of
  the voli;
- **per scope**, because averaging collapses spread: individual Defensive runs
  39–68 across volis and 47.5–59.7 across random sixes, so player bands applied
  to a team make every team a C;
- **and now per aggregation**, because a functional axis is a mean over *three*
  contributors, not six, and will be wider than the six-mean figures I measured.
  **Those six-mean bands were measured for the wrong aggregation and must be
  re-measured once functional axes exist.** They are not usable as they stand.

## Talent versus current: nearly all of this is already computed

This is the part of the spec that sounds hardest and is closest to done. Every
term in *underlying + utilisation + fit + form + context* has something behind it
already:

| spec term | what carries it today | state |
|---|---|---|
| underlying ability | the attribute table and `summary_profile` | live |
| role utilisation | `position_familiarity`, and whether the tactic asks them to do the thing | live |
| tactical fit | `SystemFitProfile` — four axes, ideal + tolerance, read at five sites in the resolver | live |
| current form | `current_form` | live |
| confidence | `match_confidence` | live |
| fatigue | `player.fatigue` through `FatigueModel`, three stages | live |
| chemistry / context | `starting_identity_state`, cohesion, familiarity | live |

So **squad talent** is the profile with none of those applied, and **current
performance** is the profile with all of them applied. Two calls into the same
function with a flag, which is exactly the shape `summary_profile(player,
use_ceilings)` already has for potential.

That also means the gap between the two rings is not a new quantity. It is the
sum of things the simulation is already doing to those volis, made visible — and
a manager who sees the gap and drills into it lands on tactical fit and
familiarity, which is precisely where the answer is.

## The asymmetric bonus needs a shape, and it needs a guard

The rule *exceptional secondary ability raises the axis, irrelevant weakness
does not lower it* is right and it is also the one rule here that can quietly
inflate everything. Two constraints on any implementation:

**It must measure excess against the unit being helped, not against the world.**
A setter who blocks at 70 is a bonus to a blocking unit averaging 58 and is
nothing to one averaging 78. So the term is over `max(0, contributor − primary
mean)`, saturating, capped. The threshold and cap are exactly the sort of
constants that must be read off the measured distribution of that excess — which
cannot be measured until functional axes exist. Do not pick them first.

**Contributors are the six on court, not the squad.** If the bonus scans the
roster, signing a seventh good blocker raises Team Blocking while they sit on
the bench. For a *current* wheel the contributor set is the lineup. For a
*talent* wheel there is a real argument for the squad — depth is a talent — and
that is a second decision, not the same one.

## The three views, and the one that already works

The spec's internal / public / scout split maps onto architecture that is
already correct. `ScoutingSystem` is built on the rule that **the fog is a view,
never a copy** — nothing writes an estimate back onto a voli, and every function
is a pure transformation of the truth. `fogged_profile()` already takes a
profile dictionary and returns the club's version of it.

A fogged *team* profile is therefore almost free: compute the functional wheel,
run it through the same estimate. Which means the opponent's wheel on the
whiteboard is a solved problem the moment the wheel itself exists — and it
arrives with uncertainty attached rather than as a second, confident number.

## Against the whiteboard

The board's rule is *figures, not sentences*. Two rings on one wheel is a lot of
ink for one comparison, and the comparison is a single number: are we above or
below what we should be. Worth trying both:

- the ghost outline, as specced; or
- two figures — `Talent A− · Current B+` — with the wheel drawn once.

The second is cheaper, reads instantly, and does not ask the viewer to judge the
area between two hexagons. The first says *which axes* the gap lives on, which
the second cannot. Probably: two figures on the lock-in board where space is
tight and glanceable matters, the ghost outline in the journal's Team menu where
you are actually studying it.

## Order

1. **Re-cut the categories** into the functional six, as a second table beside
   the existing one rather than replacing it.
2. **Functional contribution** — primary contributors per axis, over the six on
   court. Delete `amplify_team_profile` and measure the spread before adding
   anything back.
3. **Re-measure the grade bands** against the new axes, per axis and per scope,
   and replace the absolute thresholds in `grade()`.
4. **Talent versus current** — the same profile with and without the five
   adjusters, all of which already exist.
5. **The asymmetric bonus**, with its threshold read off the distribution of
   excess that step 2 makes measurable.
6. **Drill-down**, which is just the contributor list the calculation already
   built, printed.
7. **The fogged team profile** for opponents, which is one call.
