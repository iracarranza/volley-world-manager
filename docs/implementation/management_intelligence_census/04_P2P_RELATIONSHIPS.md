# Player-to-Player Relationships — Setter/Hitter and Beyond

## What is live

`PairFamiliarity` is a real persistent relationship model rather than prose.

It is:

- keyed on an unordered pair;
- initialized above zero;
- grown by playing together;
- decayed when known pairs do not play together;
- seeded for established rosters;
- queryable as a pair value;
- summarized for a setter against reachable hitters;
- able to identify the weakest on-court pair.

This is meaningful infrastructure.

## What it currently means

The model describes **general knowledge of another Voli**, not yet the full designed match-training grain.

That distinction matters because `TACTICS_AND_TRAINING.md` says tempo comfort is specifically a **hitter–setter relationship**. A setter/hitter pair can know each other generally while still being inexperienced at a particular requested tempo/system behavior.

Therefore:

`general pair familiarity != tempo familiarity`

Do not overload the existing number until it means both.

## Recommended layered model

Preserve `PairFamiliarity` as a general relationship baseline.

Where training needs specificity, use a small relationship modifier rather than an uncontrolled matrix, for example conceptually:

`tempo comfort = hitter natural tempo band + learned tempo offset + setter-pair modifier`

The exact representation remains implementation work, but the ownership rule is clear: the relationship cannot live solely on the hitter or setter.

## Other pair-grain systems

The same design principle applies elsewhere:

- blocking posture belongs to the blocking pair;
- coverage/defensive loci may belong to rotation slots rather than personal pair chemistry;
- general social/club relationships, if later implemented, should not be silently reused as volleyball timing familiarity.

## Census

| Relationship concept | State |
|---|---|
| General pair familiarity | LIVE |
| Seed from plausible prior shared history | LIVE |
| Match growth/absence decay | LIVE |
| Setter-reach summary | LIVE |
| Weakest on-court pair query | LIVE |
| Setter decision causally using pair familiarity | PARTIAL/UNKNOWN |
| Tempo-specific hitter–setter comfort | ABSENT |
| Match-training modification of tempo pair comfort | ABSENT |
| Blocking-pair learned posture comfort | ABSENT |
| Human-facing connection visualization | PARTIAL/UNKNOWN |

## Design guard

Do not solve all interpersonal systems with one `chemistry` value. The project already has a more precise principle: **the grain follows the thing being learned.** General familiarity, setter tempo, blocking coordination, social affinity and tactical comfort are different facts even when the same two people are involved.