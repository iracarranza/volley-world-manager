# Sixnet, Zaitgaist, and tactical coherence

Design record. This document consolidates the competition-structure, regional-strength, Zaitgaist, and tactical-familiarity discussion. It is descriptive design guidance, not a claim that every system below is implemented.

## 1. Competition ladder

The intended world structure is:

```text
REGIONAL PLAYER POOLS
        ↓
CLUB EMPLOYMENT + CLUB COMPETITION
        ↓
club results / player performance / club strength
        ↓
REGIONAL STRENGTH + REGIONAL STANDING
        ↓
SIXNET EIGHT QUALIFICATION
        ↓
regional academy selection
        ↓
lower qualifier + Sixnet championship six
```

Clubs are persistent institutions. They differ through accommodation, history, resources, vacancies, roster hierarchy, star treatment, role-player opportunities, bench/reserve depth, staff, tactics, and relationships.

Academies are not ordinary clubs. They are temporary representative selections for a region and should concentrate the region's volleyball identity more strongly than normal clubs do.

A voli is not employed by an academy. Academy duty is representative selection alongside their club career.

## 2. Regional strength is not Sixnet rank

Three concepts must stay separate.

### Regional strength

Regional strength asks: **how convincing is the whole case that this region is currently strong at volleyball?**

It should eventually draw from several independent sources rather than a single academy-CA scalar:

- number and quality of genuinely strong clubs;
- club results, especially interregional results;
- standout individual volis;
- positional breadth rather than several stars at one position;
- the quality of an ideal representative starting six;
- enough depth for roughly 6–10 substitutes/reserves, depending on the final academy format.

Different regional strength profiles should be possible. One region may have several excellent clubs and no transcendent star; another may have a spectacular starting six and weak depth; another may be unusually deep and tactically coherent.

Regional strength is an absolute/world-comparable quantity. It exists for every region, including regions outside the Sixnet.

### Sixnet rank/result

Sixnet placement says only what happened in the tournament.

The starting save intentionally gives A'ace the flagship 4th-place/upper position and Ĭspayk the flagship 8th-place/lower position. These are historical starting conditions, not permanent regional-strength claims.

A region can therefore be seventh in underlying regional strength while holding a better historical Sixnet slot, or be strong enough to challenge the Eight while currently outside it.

### Sixnet prestige

Recent Sixnet success supplies incumbency prestige without becoming physical or technical strength.

The intended role of prestige is to make the Sixnet open but not volatile:

- the six regions that actually reach the championship round robin earn a new participation/prestige benefit;
- the two qualifier eliminations do **not** earn that year's championship prestige benefit;
- old prestige decays rather than providing permanent entitlement.

Therefore 7th and 8th are not automatic relegation positions. They are **exposed positions**.

A region should normally lose a Sixnet place only when three things coincide:

1. its wider club/player ecosystem has weakened;
2. it performs poorly enough in the Sixnet to stop refreshing prestige;
3. an outside region massively overperforms and builds a genuinely stronger regional case.

A minor-region breakthrough should therefore feel historic rather than rotational.

## 3. Any region can enter the Sixnet

Major/minor is an economic and developmental tier, not an eligibility gate.

Minor regions generally have less funding, smaller player pools, fewer strong clubs, and less depth. These structural disadvantages make Sixnet qualification rare. They do not make it impossible.

The world should be capable of producing a story in which a minor region has an extraordinary generation, several strong club seasons, and a balanced representative group at exactly the moment an incumbent weakens.

## 4. Academy selection

Once qualifying regions are established, academy squads are drawn from eligible volis of that region.

Selection should not be a simple CA sort or a literal season-rating leaderboard.

A better shape is:

```text
regional eligibility
        ↓
season evidence / playing time / performance
        ↓
positional candidate pool
        ↓
academy role needs + regional tactical identity
        ↓
selected representative squad
```

Season performance establishes candidacy. The academy then attempts to build the strongest coherent representative team rather than merely selecting the highest statistical performers.

This creates meaningful selection disputes and makes club playing time consequential.

## 5. Zaitgaist: tactical memory, not one copied style

Zaitgaist's core identity remains unchanged: it has no stable native volleyball tradition and studies what has recently succeeded elsewhere.

The important correction is that **Zaitgaist should not simply overwrite one regional style with the next**.

The stronger identity is generational:

> Zaitgaist does not change styles. Successive Zaitgaister generations grow up under different styles.

Example:

```text
Sixnet champion: Xérvu
→ one developmental cohort learns Xérvyan assumptions

next champion: Pāwa Hitō
→ the next cohort learns Pāwa assumptions

next champion: Taktikã
→ the next cohort learns Taktikã assumptions
```

The older cohorts do not forget what they learned merely because the regional programme changes direction.

A mature Zaitgaist club or academy can therefore contain six generations of tactical inheritance at once.

This creates the region's central risk/reward curve:

```text
COPY
→ ACCUMULATE
→ CONTRADICT
→ SYNTHESIZE?

YES → exceptional tactical ceiling / breakthrough
NO  → incoherence / collapse / institutional reset
```

Accumulating tactical information is not free. Repeatedly changing developmental models destroys continuity and can leave the region with enormous knowledge but no shared language.

A successful Zaitgaist coach can sometimes build an elegant system in which different inherited traditions solve different parts of the game. A failed one gets highly talented volis making incompatible assumptions about timing, responsibility, risk, tempo, and coverage.

Zaitgaist should therefore produce newsworthy long-term cycles even when the human manager works elsewhere: successive borrowed generations, tactical conflict, attempted synthesis, breakthrough, or reset.

The manager does not necessarily need direct control over which region Zaitgaist copies. The more interesting player problem may be **what to do with the people this unstable institution produced**.

## 6. Tactical vocabulary

The current concepts need to be separated explicitly.

### Social cohesion

**Question:** Do these people trust and support one another?

Cohesion is emotional/social. It can influence confidence propagation, recovery from mistakes, interpersonal support, and related team dynamics.

A tactical change should not directly make friends stop trusting one another.

High cohesion and low tactical coherence must be possible.

### Formative tactical inheritance

**Question:** What volleyball did this voli learn to regard as normal while developing?

This should become a persistent per-voli concept, e.g. `formative_principles` or an equivalent saved tactical profile.

For ordinary regions, formative inheritance should generally resemble the region's contemporary developmental tradition.

For Zaitgaist, formative inheritance should reflect the external model dominant during that voli's developmental cohort.

This is a learned prior, not a personality preference and not a statement that the voli refuses other systems.

### Tactical alignment

**Question:** How similar is the current manager instruction/system to this voli's formative tactical prior?

Alignment is derived. It is not the same thing as familiarity.

A voli can be poorly aligned with a tactic but highly familiar with it after years of drilling.

Regional alignment can remain useful as a descriptive/UI quantity, but should not become a generic execution penalty by itself.

### Tactical familiarity

**Question:** How well does this voli know the current team system?

The current authoritative team-wide scalar is too coarse for the intended design.

Tactical familiarity should move toward a per-voli state and eventually, where useful, a phase/dimension-specific state. A server can be highly familiar with the serve plan while unfamiliar with a new block/defence relationship.

The existing team-wide tactical familiarity can remain as a derived UI summary.

Training should improve familiarity with what is actually being drilled. `adaptability` is a natural candidate to influence learning rate.

### Tactical discipline

**Question:** Given a real team call, how strongly does this voli adhere to it?

Discipline is not familiarity, intelligence, physical capability, or generic restraint.

A voli may fully understand an instruction and choose/deviate differently depending on discipline and decision-making.

### Decision-making

**Question:** Given the situation as understood, what action does the voli choose?

Decision-making operates after perception/understanding rather than replacing familiarity or adherence.

### Pair familiarity

**Question:** What do these two volis know about each other's timing and behaviour?

Pair familiarity can mitigate tactical-background differences. Two volis with very different formative assumptions may still coordinate extremely well after years together.

### Tactical coherence

**Question:** Do the relevant volis' interpretations fit together on this actual action?

Tactical coherence should usually be **derived locally**, not stored as one global penalty.

Examples:

- setter + middle coherence matters for a quick;
- primary + assist blocker coherence matters for a closing responsibility;
- blocker + floor defenders matter for funnel/seal relationships;
- unrelated tactical-background differences between a server and libero should not create an automatic penalty.

Do not implement `number_of_tactical_backgrounds -> global penalty`.

Different traditions should conflict only when their assumptions actually need to meet.

## 7. Intended causal chain

For an individual tactical decision:

```text
MANAGER CALL
    +
VOLI FORMATIVE PRIOR
    +
CURRENT-SYSTEM FAMILIARITY
        ↓
UNDERSTANDING / INTERPRETATION
        ↓
TACTICAL DISCIPLINE
        ↓
DECISION-MAKING IN CONTEXT
        ↓
PHYSICAL FEASIBILITY
        ↓
EXECUTION
```

For coordinated actions:

```text
VOLI A INTERPRETATION
        +
VOLI B INTERPRETATION
        +
PAIR FAMILIARITY
        ↓
LOCAL TACTICAL COHERENCE
        ↓
TIMING / RESPONSIBILITY / MOVEMENT
```

This preserves the broader rally-design rule: manager intent should change attempted decisions, not physics or outcome bands directly.

## 8. Why Zaitgaist should not need a special chaos modifier

Avoid special logic such as:

```text
if home_region == Zaitgaist:
    tactical_familiarity_penalty *= 2
```

If the underlying tactical-history model is expressive enough, Zaitgaist becomes extreme naturally because its player pool contains much wider tactical-prior variance than ordinary regions.

Its upside also emerges naturally: several traditions can be complementary if a coach places them in compatible responsibilities and drills the interactions well.

## 9. Long-term Zaitgaist institutional states

A useful future world-simulation layer may track whether Zaitgaist is in one of several broad institutional periods:

- adoption: a new successful external model becomes fashionable;
- accumulation: multiple cohorts coexist without complete synthesis;
- contradiction: tactical assumptions increasingly conflict;
- synthesis: clubs/academy find a coherent structure using several inherited traditions;
- reset: repeated failure causes the developmental establishment to abandon much of the accumulated doctrine and begin another cycle.

These states should produce world/news consequences before they become player-facing controls.

## 10. Implementation direction, not immediate scope

The likely architectural sequence is:

1. stop regional tactical distance from directly determining social cohesion;
2. document/retain the semantic separation above;
3. add persistent per-voli formative tactical inheritance;
4. make Zaitgaist cohort inheritance historical rather than one current overlay;
5. move authoritative tactical familiarity toward per-voli state;
6. keep the team tactical-familiarity number only as a derived summary;
7. wire familiarity/coherence into specific coordination decisions rather than generic quality;
8. use pair familiarity to mitigate divergent assumptions;
9. add Zaitgaist news/critical-mass/reset simulation once the underlying player/team semantics exist.

Do not treat this document as permission to interrupt the current rally-simulator causal redesign with a broad tactical-cohesion implementation pass. The concepts should be retained so later tactics and world systems use one vocabulary.

## 11. Open questions retained

- exact regional-strength weighting among club strength, interregional results, individual stars, representative prime, and depth;
- academy roster size / positional composition by competition format;
- exact Sixnet prestige award/decay values;
- whether Sixnet replacement uses one public standing calculation or a separate challenge comparison;
- how Zaitgaist decides its next developmental reference when the human is managing there;
- how formative tactical inheritance is represented without creating dozens of opaque player ratings;
- which rally interactions are sufficiently coordination-sensitive to consume local tactical coherence.
