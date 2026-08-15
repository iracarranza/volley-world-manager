# Traits

> Attributes describe competence. Traits describe individuality. Tactics
> describe what the coach wants. The simulation becomes interesting when those
> three things reinforce or conflict with one another.

## The crux: deviation and reinforcement

The point of a trait is not that it nudges a weight. It is that **a voli and
their instructions can disagree, and the disagreement is resolved by who that
voli is.**

The worked example, which is the whole design:

- The tactic says *watch cross*. The voli gravitates to line.
- At a critical read they go line anyway.
- With poor court vision and anticipation, they went line because they always go
  line, and the ball was cross. It costs the set.
- With excellent anticipation, they went line because line was *actually what
  was happening*, and the tactic was wrong. It saves the set.

And the inverse, which matters just as much: when the trait agrees with the
instruction, the requested behaviour becomes especially natural and reliable.
That is what makes a young, underdeveloped outside with unreadable potential
worth starting — they fit, and fitting is worth attribute points you do not
have yet.

This is tension at the individual level, and **nothing in the game currently
produces it.** Every voli today executes the tactic to the limit of their
numbers. The only variation between two volis is how well they do what they were
told.

### Why this is not "a weight in a decision"

An earlier draft of this document classified most traits as *bias a choice —
change a weight at a decision site*. That is too weak and it loses the design.
A weight makes a voli go line 60% of the time instead of 40%; it does not make
going line *right or wrong depending on who they are*.

The mechanism that produces the example is:

1. **The trait decides whether the voli deviates** from the instruction at this
   junction. Probabilistic, magnitude from the trait.
2. **The read attributes decide what the deviation is made of.** An *informed*
   deviation is a choice made against the situation as it actually is — the voli
   saw something. An *uninformed* deviation is made against the situation as
   they assumed it. Same action, different information behind it.
3. **The outcome falls out of that**, with no bonus and no penalty anywhere. A
   voli who reads well and follows their instinct is right more often than the
   tactic; a voli who reads badly and follows their instinct is wrong more often
   than the tactic. Neither needed a modifier.

That third point is what makes this cheap to balance and impossible to
degenerate. There is no "deviation bonus" to tune. There is one existing
quantity — how well this voli reads — deciding whether their individuality is an
asset or a liability.

**Reinforcement uses machinery that already exists.** `SystemFitProfile` already
carries `in_system_bonus`, described in its own comment as *being on your mark
should tilt marginal actions, not manufacture quality*. A voli whose trait
agrees with the instruction at a junction is, precisely, in system on that
junction. The reinforcement half needs no new concept at all.

### The engine already has this mechanism, once, at the wrong altitude

`rally_simulator.gd` computes:

```
follow_threshold = 0.22 + decision_making * 0.35 + tactical_discipline * 0.18
result.play_was_followed = active_play != null
    and result.reception_quality >= 0.42
    and rng.randf() < follow_threshold
```

That is *the called play was abandoned* — deviation from instruction, gated by
attributes, already in the resolver and already reported as a key factor. What
it lacks is everything that would make it interesting: it is one roll for the
whole team, it has no individual flavour, and abandoning is neutral-to-bad
rather than being right when the voli who abandoned could see something.

The serve has a second instance — `serve_decision.changed_target` — where the
server reconsiders the called target mid-action.

So the pattern is established and endorsed by the codebase. **Traits are that
pattern, per voli, at every junction, with the outcome decided by the reader
rather than by a penalty.**

### Where the junctions are

Each of these is a place the tactic states a preference and a voli could
disagree with it. All five exist in code today.

| junction | the instruction | the code |
|---|---|---|
| defensive read | watch cross / line, defensive depth | `_read_error_meters`, `DefensivePlan`, the `defensive_depth` fit profile |
| serve target | zone called by the plan | `defensive_plan.serve_target`, `serve_decision.changed_target` |
| set distribution and tempo | which hitter, how fast | `_tempo_call`, `_choose_assignment`, `follow_threshold` |
| attack shot | line / cut / tool against the block | the swing decision and `decisiveness` |
| block commitment | commit to the strong hitter or read | `ShadowBlockSystem`, the `block_engagement_distance` fit profile |

## The four kinds of trait

Internally distinct, presented to the player under one heading.

| kind | what it is | what it may do |
|---|---|---|
| **Behavioural** | probabilistic preference | biases decisions; may deviate from or reinforce the instruction at a junction. **Never bypasses the decision model** |
| **Physical** | unusual morphology or a persistent physical characteristic | changes what the body can do, and is a *label on the body*, not a second copy of it |
| **Rare** | an exceptional capability, or a tendency strong enough to be one | **may expand what actions are possible, or alter the constraints on them** |
| **Restricted** | a capability with an explicit eligibility condition | as rare, but only when the condition holds — e.g. maintaining offensive tempo on an emergency set is only meaningful for a *non-setter* |

The line that matters: **behavioural traits influence the existing decision
model; rare traits may change what the model is choosing between.** That is the
one place a trait is allowed to be more than a bias, and it is licensed by
rarity.

## Rare traits: the strength is the point

An earlier draft treated "a capability that is too strong makes a voli
mandatory" as a defect to be tuned away. That was wrong. Making a voli worth
building around **is the intended effect**, and rarity is what licenses it:

> "I could build a whole team around this voli if only they were a little
> better."
>
> "I really need to prepare for this voli's behaviour."

Their job is to *distort normal valuation* — to make a manager consider a voli
whose attributes do not justify the slot, and to make an opponent plan around
one voli.

### What "rare" has to mean numerically

Measured against the world as it is generated today: `DEFAULT_POPULATION_SIZE`
is 4,000 volis spanning ages 15–38, and one birth cohort is **260**.

"A few in a generation of hundreds" therefore reads as roughly **2–4 per cohort,
about 1%**, giving on the order of 70 living rare-trait holders in a 4,000-voli
world at any time — across every region, every age and every position.

Two consequences that have to be built in rather than hoped for:

- **Not guaranteed to land on a voli who can use it.** A rare attacking
  capability on a libero, or on a voli who never develops, is not a bug — it is
  most of what makes the rare ones feel like discoveries rather than rewards.
  Rare traits must be assigned **independently of quality**, not as a bonus on
  elite prospects.
- **Restricted traits are the exception to that**, by definition. Their
  eligibility condition is part of the trait: a non-setter who can hold a play's
  tempo on an emergency set is only that trait when they are a non-setter.

Both of those are generation rules, and both are the kind of rate that has to be
measured after the fact rather than assumed — a 1% draw that quietly becomes 4%
because it was rolled per position rather than per voli is the same class of
error as a threshold outside its distribution.

## What the player is supposed to get from reading them

Not a rating. A reason to look twice:

> "This voli has huge arms despite being short, and their jump capacity is
> extreme — they might make a strange middle and fill the hole in my roster."
>
> "This voli can attack without an approach? I have been struggling to keep
> hitters in rhythm against Ĭspayk; maybe they are the answer."

Both of those are **unconventional fit** — an unusual combination of attributes,
tendencies, capabilities and morphology, and a manager deciding how it could fit
or reshape their system. The trait list's job is to make that combination
visible; the tactical system's job is to make it pay off.

## Corrections to the previous draft of this document

Three things were wrong and one was right for the wrong reason.

### "Some of these are attributes that already exist" — mostly wrong

The reasoning was that a trait duplicating a modelled quantity creates a second
source of truth. That reasoning is sound and the conclusion drawn from it was
not, because **the trait was never the quantity.**

`primary_serve_style` already contains `"Sky Ball"` and `"Hybrid"`. That is what
a voli *uses*. The trait is what they *reach for when the instruction says
otherwise* — a server told to hit a hard zone-5 ball who floats a sky ball at a
critical point is a decision-bias trait operating on a junction that exists
(`changed_target`), and it is not the enum. Both can be true with no duplication:
the enum is capability, the trait is pull.

Restored to the list on that basis: **sky ball, hybrid, and every other entry
whose "duplicate" is a capability rather than a preference.**

### Body traits — the mechanism was right, the framing was too quiet

"Derive the label from the body, do not stamp the body from the trait" still
holds: generation owns the centimetres and the trait is a label on an outlier of
a distribution that already exists. But the previous draft filed that under
things to *drop*, and your own example is the argument against it — *"huge arms
despite being short"* is exactly a physical trait, and it is one of the two
things you want a manager to notice. It is a **Physical trait**, first class,
surfaced prominently. The rule only governs which direction the data flows.

### Rare traits — see above. The strength is the design, not a balance problem

What survives from the previous draft is only that they are a **different kind
of thing** with a **separate budget**, which your own taxonomy says too. The
prescription to weaken them is withdrawn.

### What was right

- The `*` convention — a trait describes what a voli **attempts**, never what
  they **achieve**; the outcome stays with the attribute that already governs it.
  This is the same principle as the deviation model: traits choose, attributes
  resolve.
- Polar pairs are one signed axis, and the "gravitates to line / short / deep /
  cross / cut" family is one weighting rather than five flags — now with a
  sharper reason, since the deviation model needs *a direction to deviate in*,
  and that is a single vector.
- "Jump sets when fatigued" is the fatigue model being visible, which you
  identified first.
- **Two of the four traits that exist today are read and never generated.**
  `Early Riser` and `Night Owl` shift the training window in
  `daily_schedule_system` for a trait no voli can have. Still the first thing to
  fix, and still the reason the registry has to come before the content.
- The four starred receiving techniques need **one** mechanism between them: the
  engine already classifies how strained a contact was (`contact_posture`,
  `contact_recovery`); what is missing is which technique a voli reaches for
  inside that classification. Under the deviation model this gets better, not
  worse — technique choice is a junction like any other.

## The list

Kinds: **B** behavioural · **P** physical · **R** rare · **X** restricted.
Status: **wire** the read site exists · **junction** needs a deviation hook at a
junction that exists · **new** needs a mechanism · **waits** needs an unbuilt
system.

### General / physical

| trait | kind | notes | status |
|---|---|---|---|
| unnaturally short / long arms | P | label on an outlier of generated limb proportion; feeds reach and block reach | wire |
| unnaturally short / long legs | P | same, and it moves `stride_length_m`, which is already the approach fit's ideal | wire |
| gets stretched rarely | P | injury/rehab; `REHAB_BLOCKS` exists in the day model | waits |
| allergies | P | food and care; **three data, never one field** -- reality, the voli's belief, the club's belief. Reality drives nourishment, belief drives morale. `ACCOMMODATIONS_AND_CARE.md` §2 | waits on the catalogue |
| gets winded easily | P | label on a `stamina` outlier — the number stays in `FatigueModel`, the label is what the manager reads | wire |
| recovers stamina between sets and rallies | R | rally-fatigue accrual and `stamina_fatigue_scale` | wire |

### Behavioural / off-court

All **B**, all outside the rally, and together they are the voli side of the
club preference model in `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §3.

| trait | notes | status |
|---|---|---|
| wakes up early / late | `TRAIT_WINDOW_SHIFT` — read site exists, has never fired | wire |
| overeats / undereats | food blocks, condition | waits |
| gets homesick often / rarely | `home_region` vs `club_region` already distinguished | waits |
| hypochondriac / doesn't report symptoms | no injury model | waits |
| needs to socialise often / rarely | club social time | waits |
| changes tactics easily / slowly | `adaptability` drives every fit `tolerance`; this is the trait that governs *how fast a voli stops deviating* from a new instruction | wire |

That last one is worth calling out: it is the meta-trait of this whole system.
It decides how long a voli's individuality argues with a tactic before the two
settle.

### Serving

| trait | kind | junction | status |
|---|---|---|---|
| reaches for a sky ball | B | `serve_decision.changed_target` / mode | junction |
| reaches for a hybrid | B | same | junction |
| aims short ↔ endline | B | one signed axis on serve target | junction |

### Receiving

| trait | kind | junction | status |
|---|---|---|---|
| gravitates line / short / deep / cross / cut | B | the defensive read — **the worked example, and the first one to build** | junction |
| *tomahawk / *pancake / *one arm / *rolling | B | technique choice inside the posture the engine already names | new (one mechanism, four traits) |
| takes overlapping receives often / rarely | B | `seam_conflict`, `claim_margin` | junction |
| moves before read often / rarely | B | `_read_error_meters` already models going early to the wrong place | junction |
| keeps form while unbalanced | R | removes the `off-axis` posture penalty | wire |
| chases down tools, wipes, bombas | R | off-ball chase; only the second-contact chase exists | waits |

### Blocking

| trait | kind | junction | status |
|---|---|---|---|
| looks for stuff ↔ soft touch | B | one signed axis on block outcome intent | junction |
| shows and closes | B | `block_engagement_distance` fit ideal | wire |
| commits to the strong hitter often / rarely | B | `ShadowBlockSystem` coordinated read — a deviation here is the block equivalent of the worked example | junction |
| jumps again after a decoy | R | needs landing and re-jump | new |
| jumps with arms spread | B | width against penetration — a real trade-off the block model does not make yet | new |
| completely guesses | R | the wrong-read machinery exists and is calibrated | wire |

### Attacking

| trait | kind | junction | status |
|---|---|---|---|
| looks for line / cut / tool | B | one weighting; `tooling` is already an attribute | junction |
| forces the chosen shot when challenged | B | `decisiveness` and the swing-under-pressure path both exist | junction |
| jumps as a decoy | B | the block read that would be fooled exists; the decoy jump does not | new (small) |
| can attack with no approach | R | an approach fit ideal near zero with a wide tolerance **is** this, with no new code | wire |
| *attacks from outside the court | R | the court boundary does not constrain attack geometry | new |

### Setting

The largest group and the one where deviation bites hardest, because the setter
is where the tactic is most specific — *"a voli might be everything you need as
a setter, but disagree with the tempo you want or the hitter you want fed."*

| trait | kind | junction | status |
|---|---|---|---|
| sets tempo slower / faster than the tactic | B | `_tempo_call`; the identity tempo shift is the same shape at team level | junction |
| loves to set outside / middle / opposite / pipe | B | one weighting over `CourtConstants.LANES` — **the hitter-distribution disagreement, named** | junction |
| challenges blockers often / rarely | B | setter decision against the read | junction |
| *sets close to the pins | B | lane target within `LANE_ZONE`, which already has x ranges | junction |
| attacks on two often / rarely | B | geometry exists, the option does not | new (small) |
| resorts to underhand often / rarely | B | `SetterCapabilitySystem` already picks hands / jump / platform by contact height | junction |
| delegates to the backup setter often / rarely | B | `_second_contact_setter`, `_spatial_setter_choice` already choose | junction |
| joins the attack often / rarely | B | setter as hitter | new (small) |
| sets very high third tempos | R | set height already derives from tempo | wire |
| sets zero tempos | R | tempo 0 exists in `CourtConstants.TEMPOS`; the gate is capability | wire |
| *sets overpasses one-handed | R | overpasses are not modelled | new |
| holds a play's tempo on an emergency set | **X** | emergency setters exist and are penalised; this removes the penalty, **for a non-setter only** | wire |

## Order

1. **Make traits a type.** A registry: id, kind, the junction or site it acts on,
   a signed magnitude, and any eligibility condition. Plus a test that fails when
   a registered trait is read by nothing — the thing that would have caught
   `Early Riser`. Everything else depends on this and it is small.
2. **Build the deviation hook**, once, generically: at a junction, a trait may
   propose an alternative to the instruction; whether the voli deviates is the
   trait, whether the deviation is informed is their read. Promote
   `play_was_followed` into it rather than leaving a second mechanism beside it.
3. **The defensive read first** — the worked example, the most watched phase, and
   the junction where a right-for-the-right-reason deviation is most legible from
   the stands.
4. **Reinforcement**, through `in_system_bonus`, at the same junctions. Cheap,
   and it is the half that justifies starting the young outside who fits.
5. **Rare traits as a separate budget**, assigned independently of quality, with
   the assignment rate measured against the cohort after generation rather than
   assumed from the roll.
6. **Physical traits as labels on outliers**, which is what makes the "huge arms
   despite being short" read possible.
7. **The receiving technique layer** — four traits, one mechanism.
8. **The remaining junctions**, each measured against the distribution of the
   quantity it acts on before its magnitude is chosen.
9. **The off-court behavioural group last, with the club design**, where it stops
   being flavour and becomes why a voli picks you.

## Not decided here

- How many traits a voli carries. One or two behavioural is the stated shape;
  the exact distribution should be chosen after the registry exists and measured
  against a generated world rather than guessed.
- Whether traits are stated or discovered. `SCOUTING.md` argues that rare traits
  in particular should be *discovered only when demonstrated* — a different
  epistemology from a narrowing estimate, and one that fits both the scouting
  ladder and the whiteboard's show-don't-tell rule.
