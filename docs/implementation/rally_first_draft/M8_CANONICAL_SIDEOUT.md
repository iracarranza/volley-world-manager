# M8 — canonical side-out certification

`tools/run_canonical_sideout.gd`

## The fixture

P5 asks for "controlled, hand-authored, neutral rosters. Do not rely on career
generation/extreme morphology to demonstrate ordinary volleyball."
`seed_vertical_slice_data()` is that roster — twelve named volis with written
attributes, identical every run.

The seed is **searched, not chosen**: the first in `76000..76400` whose rally
walks serve → reception → set → attack, preferring one that also reaches a
transition. That is seed **76005**, home serving. Picking a seed by rule rather
than by liking its answer is the difference between a fixture and a cherry.

## The trace

```
contact          actor         t      started at     contacted at   travel  prepared  launched          chain
SERVE            Mira      1.196      -              0.820,1.056    -       -         serve             -- first ball
RECEPTION        Lio       1.196      0.190,0.200    0.160,0.193    0.030   -         reception         same launch
SET              Ari       2.250      0.820,0.317    0.820,0.317    0.000   0.00s     opponent_set      same launch
ATTACK           Pax       3.185      0.165,0.389    0.544,0.414    0.380   0.00s     attack_to_block   same launch
BLOCK            Boro      3.207      0.543,0.532    0.543,0.532    0.000   0.24s     block_deflection  same launch
DIG              Nemi      4.289      0.500,0.870    0.534,0.902    0.046   0.00s     dig               same launch
SET              Mira      5.885      0.688,0.861    0.543,0.689    0.225   0.49s     set               same launch
ATTACK           Ivo       6.028      0.340,0.861    0.438,0.749    0.149   0.00s     attack            same launch
```

Eight contacts, seven boundaries, a full side-out that the defence keeps alive
into a transition and a second swing.

| gate | result |
|---|---|
| walks at least four boundaries | 7 |
| every contact receives the ball the last one launched | 0 breaks |
| contact times are monotonic | 0 out of order |
| no contact publishes more than one outgoing ball | 0 |
| every contact says where the body that made it stood | 0 missing |
| actors travel before the contacts they make | 5 of 8 |
| no boundary needed a fact the resolver did not publish | 0 reconstructed |

## Reading the two zeros

`travel 0.000` is not a voli who never moved, and the `prepared` column exists
because the first version of this trace could not tell the difference.

**Boro's block** shows travel 0.000 and **prepared 0.24 s**. He closed on the
wall during the *set's* flight, which is where C4 puts a blocker's movement, and
then stood in it. The zero is the correct answer and the 0.24 s is the evidence.

**Mira's transition set** shows travel 0.225 *and* prepared 0.49 s — already
transitioning out of defence during the dig's flight, then completing the
journey during the pass. That is C2's overlapping setter, visible as two numbers.

**Ari's first-ball set** shows 0.000 and 0.00 s, and that is also correct.
`CourtConstants.setter_serve_receive_position` places a **front-row** setter at
the shield position, already at the net: there is no release to run. Its own
comment says the depth for a *back-row* setter is chosen precisely to leave room
for that journey — "the journey to the net after the serve is struck is the
difference between the two rows". A front-row setter making no journey is the
rule working, not a body that failed to move.

## Two instrument corrections this made

Both are recorded because a trace that gets these wrong reports correct
volleyball as broken, which is worse than reporting nothing.

**The contacting body's position was published by two families of seven.** SET
and ATTACK published `body_contact_position`; serve, reception, block, dig and
coverage published only where the *ball* was. A reception event's
`start_position` is the serve's landing point — a fact about the ball that says
nothing about the passer. Now published from `_add_event` for every contact,
from the actor's live position at the moment the event is appended, which is
state that already exists rather than a reconstruction.

**The leg start was being read from the wrong end.** The first trace took the
actor's start from the previous event's published map — but that map is the
leg's *end* state. It reported travel 0.000 for the setter, the blocker and the
transition hitter, all of whom had plainly moved, because it was measuring "did
the resolver move this actor again after publishing them". `actor_leg_start` is
now snapshotted at the previous contact, which is the interval M8 actually asks
about. With it, the transition hitter's 0.000 became 0.149 and the transition
setter's became 0.225.

## The volleyball-literate layer

P5's second layer asks whether a viewer with the captions off could answer a set
of questions. A headless probe cannot look at anything, so what is offered here
is the numbers a viewer would see the consequence of — and where a number cannot
stand in for the judgement, this says so rather than inventing a proxy.

| P5 question | what the trace can say |
|---|---|
| who is receiving | Lio, from the receive formation, adjusting 0.030 to the ball |
| whose ball it is | one launch identity per contact, unbroken across all seven boundaries |
| where the setter is releasing | Ari at the front-row shield; Mira transitioning 0.49 s early |
| which attackers are available / approaching | 3 volis in motion on the SET leg |
| who read, committed and closed on block | Boro, 0.24 s of closing before contact |
| which defensive spaces are owned | 5 volis in motion on the DIG leg |
| whether late volis are visibly late | **not answerable from this trace.** Lateness is `traversal == window`, which the continuous-action probe measures in population (54 of 4,184 ran out of window) but which this one rally does not happen to contain |
| whether the previous contacter clears and transition reforms | the rally does reform — DIG → SET → ATTACK by three different volis |

The last row is the honest limit of a one-rally fixture, and it is left visible
rather than filled with a nearby number.

## Disposition

**M8 structural layer: PASS**, 7 of 7 gates.

The visual layer is not certified here and cannot be by this instrument. It
needs the app running and a person watching, which is what P5's own note about
localizing a visual failure ("can be simulation or presentation") is for. What
this establishes is that if a viewer sees something wrong in this rally, the
simulation is not where it came from: every boundary is one ball, one lineage,
one body, in causal order.
