# Does attacking scale differently from defending?

Date: 2026-08-06
Measured at: `67dcd04`.

A design claim was put to the engine, and this is the engine's answer. Six
propositions, measured separately. **Two hold, one holds for the wrong reason,
and three do not hold at all** — including the one the whole tactical
vocabulary of blocking is built on.

The claim, as stated:

> Blocking and receiving are antagonistic on both sides — blockers naturally
> more capable of getting touches, receivers naturally more capable of picking
> up funneled and read spikes, when each action is of equal quality. Attacking
> scales at a different rate to defending, due to defending's nature as a 6
> versus 1 activity. A poor attack is close to always defended neatly; an
> average attack faced with average defense loses more than it wins; but an
> above average or outstanding attack can pierce blocks, blow up defenders, and
> kill rate skyrockets when this threshold is met. A superior defense can exist,
> but that superiority is derived from all defending parties reaching this
> threshold collectively — much harder than one standout performance.

---

## The measurement

`tools/run_attack_scaling_probe.gd`. Six careers × 60 rallies × both serving
sides, generated rosters, Balanced identity. Every home swing bucketed by its
own `attack_quality` and classified into one **mutually exclusive** outcome.

Whether the block got a hand on the ball is an outcome in its own right rather
than a flag on the others: a funnelled ball the floor then picks up and a
funnelled ball that still lands are different events, and folding either into
"dug" or "kill" hides exactly the trade being asked about.

| attack quality | n | error | stuff | touch→dug | touch→kill | clean→dug | clean→kill | any touch |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.00–0.10 | 183 | 0.180 | 0.022 | 0.005 | 0.016 | 0.639 | 0.137 | 0.044 |
| 0.10–0.20 | 91 | 0.187 | 0.011 | 0.000 | 0.000 | 0.681 | 0.121 | 0.011 |
| 0.20–0.30 | 32 | 0.000 | 0.031 | 0.000 | 0.000 | 0.625 | 0.344 | 0.031 |
| 0.30–0.40 | 36 | 0.083 | 0.028 | 0.000 | 0.000 | 0.028 | 0.861 | 0.028 |
| 0.40–0.50 | 29 | 0.000 | 0.103 | 0.000 | 0.103 | 0.000 | 0.793 | 0.207 |
| 0.50–0.60 | 10 | 0.000 | 0.100 | 0.000 | 0.000 | 0.000 | 0.900 | 0.100 |

### A false result this probe produced first

The first run classified errors from `event.success`, which for an ATTACK event
is `attack_quality >= 0.25` — a threshold on the very axis being bucketed. It
produced a beautiful, clean, entirely circular cliff: 100% errors below 0.20,
94% kills above 0.30. The real error flag is `metadata.attack_missed`. Recorded
because the false table was more persuasive than the true one.

---

## Proposition by proposition

### 1. Antagonism at equal quality — **does not hold**

The block gets a hand on the ball on 1–21% of swings, and it touches *least* on
the balls it should find easiest: 0.011 at quality 0.10–0.20. There is no
regime in which the wall is the more likely of the two to intervene; the floor
is, everywhere, by an order of magnitude.

The second half fails harder. **`touch→dug` is 0.000 in five of six buckets and
0.005 in the sixth. Across 381 swings, "the block deflects it and the floor
recovers" happens once.**

That sequence is not a detail. `_block_intent_margins` defines a whole `Funnel`
intent whose stated purpose is that "the block is not trying to end the rally,
it is trying to slow the ball down and put it somewhere the floor is already
standing", and it widens the touch band by 0.09 to do it. That intent produces
one event in 381 swings. The tactical choice exists, is selectable, is
documented, and has no consequence.

Where the block does touch, the ball is *more* likely to still land than to be
recovered — `touch→kill` 0.016 and 0.103 against `touch→dug` 0.005 and 0.000.
The claimed advantage runs backwards.

### 2. Attacking scales differently from defending — **does not hold, by construction**

Both contests are linear margin comparisons:

```gdscript
# _dig_contest
defense_quality + noise > attack_quality + DIG_ATTACKER_ADVANTAGE   # 0.20

# _contest_block
block_quality + noise > attack_quality + BLOCK_STUFF_MARGIN         # 0.34
```

Attack and defence enter with equal and opposite weight. The response curve is
the noise distribution's CDF in both directions — symmetric by definition.
Whatever asymmetry appears in the table comes from where the two quality
distributions happen to sit relative to each other, not from either side
scaling differently. There is no term anywhere that makes attacking convex.

### 3. A poor attack is close to always defended neatly — **holds**

Below 0.20 quality: dug 64–68%, killed 12–14%. Comfortably.

The caveat is that 18% are *errors* rather than defended — the swing never
reaches the defence at all — so "defended neatly" is really "defended neatly or
missed the court", roughly 4:1.

### 4. An average attack loses more than it wins — **holds, for a worrying reason**

At the median swing it loses heavily: kill 0.153 against dug 0.644.

But the median swing is in the **0.00–0.10** bucket. **183 of 381 home swings —
48% — are below 0.10 attack quality**, and 72% are below 0.30. The proposition
is satisfied because almost every swing in the engine is a bad one, not because
an average swing meets a stiff defence. That distribution is its own defect and
is probably upstream of the low kill rate the reference bands keep flagging.

### 5. Kill rate skyrockets past a threshold — **holds, but as a sigmoid, not a design**

Kill rate by bucket: 0.153, 0.121, 0.344, **0.861**, 0.897, 0.900. There is a
sharp knee between 0.20–0.30 and 0.30–0.40 — a 2.5× jump inside one 0.1-wide
band.

So the *shape* is right and the threshold is real. But it is not the modelled
convexity the claim describes; it is the transition region of a step function
on a linear margin, and its width is set by `DIG_EXECUTION_NOISE = 0.10`
rather than by anything about attacking. It is also very sharp — sharper than
the sport, where kill rate rises steeply but not from 34% to 86% across one
tenth of the quality scale.

Reading 2 and 5 together: **the engine produces the right curve for the wrong
reason.** That matters because the reason determines what happens when anything
moves. Widen the noise and the threshold softens; shift a margin constant and
the whole knee slides. Nothing holds it where it is.

### 6. Superior defence is collective — **does not hold**

`_defense_terms(defender, reach_margin, read_bonus, posture_penalty,
support_count)` scores **one** defender: the claimant. Every other defender on
the court enters through `support_count`, worth `min(count * 0.03, 0.09)` — a
9% ceiling on the entire rest of the team. The constant governing the result is
named `DIG_SOLO_SHARE`.

So the floor defence is a 1-versus-1 contest with a nudge. There is no
collective threshold, no weakest-link term, and no way for six defenders each
reaching a standard to produce something one standout could not. The "6 versus
1" framing in the claim is exactly inverted: the model resolves defence as 1
versus 1.

---

## One more thing the table shows

**Stuff rate rises with attack quality** — 0.022, 0.011, 0.031, 0.028, 0.103,
0.100. A better swing is *more* likely to be stuffed. That is backwards on its
face, and the likely cause is that attack quality and block formation share an
upstream input: a good pass produces both a good swing and a set the blockers
read. It means `stuff_rate` cannot be read as "how good the block is" without
controlling for the pass, and no probe currently does.

---

## What would have to change

In rough order of how much they buy:

1. **Make the block-to-floor handoff exist.** A funnelled or touched ball
   should be a materially different proposition for the defence than a clean
   one — slower, higher, and landing where the block sent it. At one event in
   381 the Funnel intent is decoration, and it is half of what makes blocking
   a decision rather than a dice roll.
2. **Make defence collective.** A seam is a property of two defenders, not one.
   Until the resolver can see more than the claimant, "our defence is good" can
   only ever mean "our best digger is good".
3. **Decide whether the convexity is meant to be real.** If attacking is
   supposed to scale differently, that needs a term, not an accident of where
   two distributions sit. If it is not, then §5's knee is a calibration
   artifact that will move the next time anything upstream does.
4. **Explain the attack-quality distribution.** Half of all swings below 0.10
   is upstream of most of the numbers in this file.


---

# Addendum: how often do the signature moves decide a point?

Measured 2026-08-07 at `ecb51c0`. `tools/run_signature_move_probe.gd`, same
fixture: six careers × 60 rallies × both serving sides, 381 home swings.

`SignatureMoveModel` defines the two ways a swing beats a block it has
physically met — **Block Crush** (the power route: struck harder than the hands
can absorb) and **High Hands** (the accuracy route: placed on the outside edge
of the hands, within a 2.6° aim tolerance). The design intent put to them is
that they appear occasionally for a B-tier hitter, can be depended on by an A,
and are expected regularly from an S.

## What actually happens

| attacking tier | swings | block_crush | high_hands | signature share |
| --- | ---: | ---: | ---: | ---: |
| S | 4 | 0 | 0 | 0.000 |
| A | 9 | 0 | 0 | 0.000 |
| B | 304 | **0** | **2** | 0.007 |
| C | 64 | 0 | 0 | 0.000 |

**Block Crush fires zero times in 381 swings. High Hands fires twice**, both
from B-tier hitters. The intended progression is not weak — it is absent, and
the one tier it does appear in is the wrong one.

Raw outcome tallies, all tiers pooled: `in` 310, `out` 15, `stuff` 11, `tool`
4, `touch` 1, `high_hands` 2, `block_crush` 0.

## Three independent causes, none of them the move model

### 1. The swing almost never meets the block

`resolve_contact` only runs when `block_kind` is `tool` or `stuff` — the ball
has to have hit hands. **310 of 381 swings (81%) resolve as `in`: the block was
never physically met.** Total contacts of any kind: 16, or 4.2%.

So the two moves get roughly sixteen opportunities in three hundred and
eighty-one swings, and converted two of them. This is the same root as the
funnel finding above and as `block_touch_rate` sitting at 0.046 against a band
floor of 0.15. **Everything conditional on the block touching the ball is
starved by the same upstream fact.** Fix that and both findings move together.

### 2. The charge threshold sits in the tail of its own distribution

`charge = capability × 0.55 + confidence × 0.25 + flow × 0.20`. At neutral
confidence and flow those contribute 0.225, so with `AVAILABILITY_THRESHOLD =
0.62` a player needs **capability ≥ 0.7182** for the move to be available at
all. Measured across the 48 players in six generated rosters:

| capability | min | p50 | p90 | max | clearing 0.7182 |
| --- | ---: | ---: | ---: | ---: | ---: |
| crush | 0.390 | 0.668 | 0.761 | 0.784 | 12 / 48 (25%) |
| high_hands | 0.430 | 0.719 | 0.859 | 0.964 | 24 / 48 (50%) |

Crush is gated at roughly the 75th percentile, and **the best crush capability
in six full rosters is 0.784** — giving a charge of 0.656 against a 0.62
threshold, 0.036 of headroom. Nobody is ever comfortably able to do it; the
strongest hitter in the world is marginal. That is the signature defect class
again, and this instance is worse than most: the threshold is not merely inside
the distribution, it is near its ceiling.

High Hands clears twice as often and still fires twice, which confirms cause 1
dominates — availability is not the binding constraint when there is nothing to
be available *for*.

### 3. There is no A or S sample to observe the progression with

Attacking grade across all 48 generated players: **B 31, C 11, A 3, S 2, D 1.**

Four S-tier and nine A-tier *swings* in the entire measurement. Even a
correctly tuned model could not show a B/A/S progression on this population,
and more to the point a player would rarely have an A or S hitter to see it
with. Whether that distribution is intended is a generation question, not a
move question, but it bounds anything stated in tiers.

## What this means for the intent

The B-occasionally / A-dependably / S-regularly progression is reachable, but
not by touching `SignatureMoveModel` — its internals are fine and its two
routes are keyed to genuinely different attributes, which is the hard part.
Three separate things gate it, in order of how much they cost:

1. **The block has to touch the ball.** At 4.2% contact there is nothing to
   crush or tool. This is one fix shared with the funnel finding above.
2. **Re-seat the charge threshold against the measured capability
   distribution.** Crush at p75 with a population ceiling of 0.784 means "elite"
   and "barely able" are the same player. Either lower the threshold or widen
   what capability can reach.
3. **Decide whether 5 of 48 players being A-or-better attackers is intended.**
   Tier-stated design targets are unobservable below some supply of tiers.

## A correction

The first attempt at this probe added `geometric_outcome` to the ATTACK event
metadata on the reasoning that the resolver computed the signature outcome and
the curator dropped it. **It was already there** — three sites, already
published. The compiler caught the duplicate key. The attribution was never
missing; only a probe that read it was.
