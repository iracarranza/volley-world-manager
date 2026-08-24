# The block's realised contact

`CONTACT_AND_BALL_FLIGHT.md` §5 asks that a realised contact be one point: the
incoming segment ends at it, the outgoing segment begins at it, and its actor,
position and height are the ones that were physically true. This pass makes the
block say that.

## The premise this started from was half wrong, and the half that was wrong is
## worth stating first

The goal was written from the M8 visual pass and read: *`_contest_block` can
declare contact from attack x block quality without proving ball x body
feasibility.*

**On the production path that is false.** `ENABLE_GEOMETRIC_ATTACK` is `true`,
and `_geometric_promotion` overwrites `block_outcome` on every swing, so the
outcome comes from `AttackResolutionModel._block_contact` — which is a real
intersection test:

```gdscript
if height_at_net > reach:      over = true;   continue
if edge_gap < 0.0:             around = true; continue
```

Height against reach, lateral against half width, with the jump's phase folded
into the reach and the arm state folded into the edge. Quality creates no
contact there and never did. `_contest_block`'s three margins still compute, and
`rally_simulator.gd:366` already records that nothing reads them — changing them
produces byte-identical rallies.

So there was no quality-to-contact fallback to remove, and this pass built no
parallel block physics. What it did was stop the proof being thrown away.

## What was actually wrong: the proof and the claim were on different events

`_block_contact` names the hand, the height and the crossing. Every one of them
stopped at the promotion seam. Measured over 300 rallies, 236 attack-to-block
pairs, 97 proven contacts
(`docs/review/block_authority/BEFORE_block_contact_authority.txt`):

```
-- which event carries the proof, over 236 pairs --
fact                                 ATTACK    BLOCK
kind                                    236        0
crossing                                  0      128
depth                                    97        0
reaches                                 236        0
```

The BLOCK event — the one that names an actor, publishes a contact position and
authors the outgoing ball — carried none of it. It was built from two things
that survived the seam instead:

| the event said | where it came from | what was true |
|---|---|---|
| actor | the formation's **primary** blocker, by close fraction | the hand the ball met, by centrality |
| position x | the **hitter's** contact x | the ball's crossing at the tape |
| height | nothing; playback used the blocker's **jumping reach** | the proven intersection height |

Each of the three was measurably wrong:

- **Position**: mean 0.278 m from the crossing, worst 0.784 m, and further than a
  blocker's own hand is wide on 17.4% of contacts. Home only — the opponent's
  block event published no crossing at all, so 51 of 97 contacts could not even
  be checked.
- **Actor**: 35 of 97 contacts, **36.1%**, met a hand other than the primary.
  `_block_contact`'s own note records fixing exactly this inside itself, at 32%
  of two-blocker contacts, and could not fix it for the event.
- **Height**: on solo walls the proven contact height is 2.448 m to 3.107 m, mean
  2.773 m. Nothing published it, and playback drew the ball at the top of the
  blocker's jump — a fact about the body standing in for a fact about the ball.

This is the repository's most-logged fault in a new place: a value computed and
dropped at a seam. `geometric_attack_promotion.gd:282` names it, about a
different key, in this same file.

## The repair

Three keys carried the whole way, and nothing else changed about how a block is
decided:

- `block_contact_actor_id` — the hand `_block_contact` proved.
- `block_contact_height_meters` — the intersection height, present only when a
  hand met the ball.
- `ball_height_at_net_meters` — how high the ball was at the tape whoever did or
  did not touch it. New, because a beaten wall left presentation with nothing at
  all; this belongs to the flight rather than to the contest.

Then the three BLOCK event sites — first ball, home block, continuation — build
their actor and position from those, through two shared helpers
(`_block_contact_point`, `_block_contact_blocker`) rather than three copies. The
same point is the swing's truncation and the deflection's origin, so the incoming
and outgoing legs meet at it by construction. A stuffed ball's landing follows
the contact too: it comes down under the hands that stuffed it, not under the
hitter.

The formation's primary is untouched. It still owns the wall — the close
percentages, the coverage segments, the deflection, and the exclusion of both
bodies from the floor shape. Only the contact is re-attributed, and the event
publishes `block_wall_primary_id` and `block_wall_assist_id` beside it so the
difference is readable rather than asserted.

**Fallback preserved.** With `ENABLE_GEOMETRIC_ATTACK` shut there is no crossing
to read, and the legacy contest stages its wall on the hitter's lane by
construction — so the hitter's x is then the best available statement rather than
a wrong one, and it remains the fallback.

## Two consumer defects fell out, and both were live

**`_carry_trajectory` was suppressing every block, not the beaten ones.**
`match_screen.gd:527` tests `block_contact_kind` to decide whether a block
deflection is drawn. That key was on the ATTACK event and not on the BLOCK event
— 0 of 236 — so the test read an absent key, found the empty string, and
suppressed the carry on all 236 blocks including the 97 that touched the ball. It
now reads what it was always written to read.

**Presentation drew the block at the blocker's reach.** `contact_height`'s BLOCK
arm returned `block_contact_from_reach(jumping_reach)`. That is the snap-to-hands
the goal asked about: a swing that cleared a wall by half a metre was drawn
arriving in the hands it had just beaten. It reads the published height now.

The comment at `ball_presentation.gd:48` explains that a struck ball's far end
was derived from its launch *because* the reach was the wrong number. That reason
is gone for the block, so where the next contact states the ball's height, the
statement wins and the re-derivation yields.

**One trap on the way, recorded because it is the same defect in a new place.**
Accepting `ball_height_at_net_meters` for a *beaten* block ended 60 of 151 attack
legs hanging at the tape, worst 3.612 m above the floor — the ball-teleports-down
witness again. The net height is true of the ball, but the leg into a beaten
block does not *end* there; it carries on. The test is whether the drawn leg
stops at this contact, which for a block is exactly whether a hand met the ball.

## Measured

Outcome mix, 700 rallies both serving sides, before against after. Rallies do
resolve differently — the deflection leaves from the crossing now — and every
governed band still holds. Recorded as observation, not fitted:

| | before | after | band |
|---|---|---|---|
| contacts per rally | 4.827 | 4.807 | advisory |
| kill rate | 0.611 | 0.610 | advisory |
| dig rate | 0.407 | 0.412 | 0.35–0.55 |
| stuff rate | 0.108 | 0.108 | 0.08–0.14 |
| serve error | 0.181 | 0.181 | 0.12–0.20 |
| block touch rate | 0.822 | 0.818 | — |
| swing balance | 0.921 | 0.932 | near 1.00 |
| ace rate | 0.010 | 0.010 | 0.05–0.09 |
| reception quality | 0.434 | 0.434 | — |

Contact authority, same 300 rallies as the BEFORE artefact:

```
  legs measured           97          (was 46 — the opponent could not be measured)
  mean |gap|              0.000 m     (was 0.278)
  worst |gap|             0.000 m     (was 0.784)
  gap wider than a hand   0 (0.0%)    (was 8, 17.4%)
  contacts with no crossing published: 0 of 97   (was 51)

  contacts publishing a proven hand   97 of 97
  event actor disagrees with it       0
  proven hand outside this wall       0
  ball met a hand other than primary  35 (36.1%)
```

Drawn continuity, 180 rallies:

```
block seams, split by whether a hand met the ball
  the ball was met         72 legs, 0 break
  the ball went past       60 legs, 60 break
```

Every block that touched the ball is now seamless, both sides. BLOCK/home mean
seam 1.914 → 1.567 m and BLOCK/opponent 1.217 → 1.028 m are the row averages,
and the split above is why they are not zero: the 60 remaining are blocks that
touched nothing, where the leg into the event does not end at the event, so the
probe is scoring a transition that is not a seam. Total seam jumps 378 → 309, and
the worst is no longer a block.

## The gates

`_test_block_contact_is_an_intersection` drives `_block_contact` directly:
reachable; beaten over; beaten around, with the edge miss reported negative;
beaten both ways at once; a two-blocker wall where only one hand can reach;
a two-blocker wall where both can and the ball meets the central one rather than
the taller; stuff, touch and tool by the two quantities that cut them; a
descending hand tooled where a locked one touches; and source-state immutability.

**Two fixtures worth naming for what they taught.** There is no *below* miss to
write: a ball too low to clear the tape never reaches the wall, so `over` and
`around` are the only two ways past and the model names exactly those. And the
both-ways fixture had to be rewritten — the height test comes first and
`continue`s, so a blocker too short to reach never gets as far as the lateral
test and can only ever report `over`. The assertion caught that in its own
fixture, which is the assertion doing its job.

`_test_block_event_publishes_the_contact_it_proved` reads live rallies, both
serving sides, off published metadata only — a gate that re-ran the resolver to
check the resolver would be checking nothing. It asserts contact-iff-a-hand in
both directions, the actor equal to the proven hand, the hand inside the wall the
event holds, the position equal to the crossing, a height on every contact, the
swing's drawn end and the contact as one point, and the contact stamped after the
swing it met.

Not duplicated, because they were already gated: funnel and the intent-versus-
outcome verdict (`_test_block_verdict_separates_intent_from_outcome`), lineage
and one-ball-per-contact (the B6 chain and `run_canonical_sideout.gd`), and the
block rollout boundary (Gates 44–49).

## The suite

**2,156 checks pass, 0 fail** at the committed state. Seventeen checks were
written this pass and the delta cannot be attributed: `CLAUDE.md` recorded 2,139
at `413eee5` and the M8 pass that followed never updated it, so the predecessor
is either 2,139 (seventeen written, seventeen gained, no sampling population
moved) or the 2,141 that pass measured and left only in a transcript (two gates
drew fewer, the population moved). Those readings say opposite things and neither
can be chosen now. The population question was settled by the balance probe
instead, which is what it is for.

One check failed on the way and the failure was the fixture's, not the engine's
-- see *The gates* above.

## What this leaves

**FD-006 is narrowed, not closed, and the remaining scope is exact.** The ball's
height at the moment it is touched now has an owner for one family: the block,
because the resolver reads its own flight at the tape to decide reachability.
Every other family's `contact_height` is still a *body* measurement — a reach, a
platform, a hip — standing in for a fact about the ball, which is why
RECEPTION still breaks 144 of 145 legs at 0.34–0.39 m and SET 105 of 151. That
substitution is §5's open item and is simulation work.

**FD-007 is narrowed by measurement rather than repaired.** Its block half was
never the pose — `_carry_trajectory` already had the right test and was reading a
key nobody sent. The pose question remains: a blocker who could not reach still
jumps, so suppressing the pose would replace one false statement with another,
and the honest repair is a distinct reaching-and-missing pose. The dig half is
untouched.
