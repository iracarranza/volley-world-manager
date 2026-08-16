# Fixed regional philosophies and club tactical variance

Design record. This document clarifies a world rule implicit in the club, transfer, academy, and Sixnet designs.

## 1. Regional philosophies do not drift into one another

The core regional volleyball philosophies are stable world identities.

Taktikã does not gradually become Pāwa because Pāwa wins repeatedly. Xérvu does not stop being Xérvyan because another serving model becomes fashionable. Blôc du Larg does not evolve out of patient block/floor volleyball because a different approach wins one generation.

The purpose of the regional system is that the world retains recognizable, persistent volleyball traditions over long saves.

What can change is:

- quality of the current generation;
- available player pool;
- coaching quality;
- club resources;
- tactical familiarity;
- execution;
- competitive results;
- club-level tactical interpretation;
- academy selection decisions.

The underlying regional answer to **how volleyball should be played** remains stable.

### Philosophy and expression are two layers, and only one of them is fixed

Added 2026-08-16, because §1 as written reads as forbidding something the world
already does and should keep doing.

| layer | what it is | may it drift? |
|---|---|---|
| **core philosophy** | the region's answer to how volleyball should be played — its `REGIONAL_PRINCIPLES` / `TeamPrinciples` identity | **never**, through ordinary neighbour influence |
| **expression** | what kinds of volis a generation is developed to be — specialty emphasis, body bias | **yes**, slowly |

A neighbouring or dominant region can change *what a generation is good at*
without changing *what the region believes volleyball is*. Blôc du Larg raising a
cohort with more reach than usual because Pāwa Hitō has been winning is still
patient block-and-floor volleyball, played by taller people.

**The implementation already draws the line in exactly this place**, which is why
nothing here changes code:

- `SixnetLeague._blend_specialty_toward()` writes only into
  `CareerState.region_overlay`, whose own contract is *"additive generation
  deltas… layered on top of `REGION_SPECIALTY`/`REGION_*_BIAS`, never replacing
  them"*;
- `player_generator.gd` consumes it as `REGION_SPECIALTY[region] + specialty_add`
  — an extension, with its own comment saying influence drift *"broadens what a
  region is good at, it never takes away what it already had"*;
- no path from `region_overlay` reaches `REGIONAL_PRINCIPLES`, `TeamPrinciples`,
  or anything the rally reads as identity.

So the drift that exists is expression drift, and §1's "philosophies do not drift
into one another" is true of the layer it is about.

### Minor regions resist, and resistance is not survival

`Regions.REGION_TRADITION_RESISTANCE` scales the threshold a neighbour's strength
gap must clear before it influences a minor region. Weak resistance means a minor
region's *current developmental expression* becomes heavily accented by its
connected major — a Kutré Lyn generation that increasingly looks Xérvyan in what
it is good at.

**It does not mean the minor region stops being itself.** Its philosophy is not
overwritten, its specialty list is not replaced, and there is no code path that
deletes a regional identity.

> **"Absorption" in this system means an accented generation, not an extinguished
> region.** Cultural extinction — a region losing its philosophy outright — is not
> designed, not implemented, and may not be inferred from the word "absorb" in
> older comments. It would need its own design pass that says so explicitly.

## 2. Zaitgaist is not an exception to the rule

Zaitgaist's permanent philosophy is the absence of a permanent borrowed content model:

> study what succeeded elsewhere, teach it, accumulate the consequences, and eventually attempt synthesis or reset.

Its copied tactical content changes by generation. Its meta-philosophy does not.

That is what makes Zaitgaist recognizable across decades even while successive Zaitgaister cohorts can have radically different formative tactical inheritances.

## 3. Clubs are the mutable layer

A club belongs institutionally to a region without being required to reproduce the regional tactic exactly.

A club can:

```text
REINFORCE
play a highly orthodox version of the regional philosophy

VARY
retain the regional logic but alter emphasis, tempo, risk, or role use

CONTRADICT
build a substantially different tactical identity
```

This tactical variance is not a threat to regional identity. It is one of the main purposes of the club layer.

The region remains the stable cultural/developmental pole. Clubs are where managers experiment with the people actually available to them.

## 4. Why unusual clubs are necessary for the transfer market

If every club simply reproduced its home region's canonical tactic, the labour market would tend toward a closed loop:

```text
region produces characteristic voli
        ↓
local club wants characteristic voli
        ↓
voli already understands local tactic
        ↓
voli stays local
```

Club tactical variance breaks that loop.

It creates destinations for:

- locally developed volis who do not fit the canonical regional pathway;
- foreign volis who find a familiar tactical environment abroad;
- specialists whose unusual strengths are underused by orthodox clubs;
- disgruntled bench/reserve volis seeking minutes;
- managers deliberately recruiting a capability the local pipeline rarely supplies.

The result is:

```text
REGIONAL DEVELOPMENT
creates characteristic populations

        +

INDIVIDUAL VARIANCE
creates imperfect local fits

        +

CLUB TACTICAL VARIANCE
creates different demands

        ↓

TRANSFER MARKET
odd people and odd clubs can find one another
```

## 5. Tactical familiarity is a transfer cost, not a nationality lock

A Spëddigh-raised middle can move to Taktikã because:

- the Taktikã club has a starting vacancy;
- their explosive closing solves a real roster problem;
- the manager is willing to retrain them;
- the club offers better competition, resources, or status;
- the voli needs minutes to strengthen an academy case;
- the club's actual tactic may be more compatible with them than a conventional Taktikã club would be.

Their formative inheritance can make the move harder without making it irrational or impossible.

Likewise, a Pāwa-born voli can find a Pāwa-like club tactic in Blôc du Larg and regard that club as tactically more familiar than an orthodox local alternative.

Therefore:

```text
HOME REGION
where the voli developed / representative eligibility

CLUB REGION
which institution employs them

CLUB TACTIC
what they are actually being asked to play
```

must remain separate.

## 6. Contrarian clubs are proving grounds

A tactically unusual club can give a locally awkward voli the opportunity to prove that their individual volleyball works.

Example:

```text
Blôc-born commit-heavy middle
        ↓
orthodox Blôc clubs prefer patient read blocking
        ↓
limited minutes / weak evidence
        ↓
contrarian Blôc club actually uses commit blocking
        ↓
voli starts and succeeds against strong quick offences
        ↓
Blôc academy now has evidence it cannot ignore
```

The same can happen abroad.

This is central to `ACADEMY_SELECTION_AND_PROOF.md`: the academy does not reward conformity. It rewards demonstrated representative value.

## 7. Regional strength and club tactical deviation

A club's results still count toward its home region's institutional/club ecosystem even when the club tactic is unusual.

A radically noncanonical Taktikã club that wins is still evidence that Taktikã contains a strong volleyball institution capable of recruiting, coaching, integrating, and winning with a roster.

It is **not** clean evidence that canonical Taktikã philosophy defeated the opponent.

This sharpens the distinction between club competition and the Sixnet:

```text
CLUB COMPETITION
messy evidence about the whole regional volleyball ecosystem
money + recruitment + imports + club tactics + managers + institutions

SIXNET
concentrated representative evidence
home-eligible talent + fixed regional philosophy + academy selection
```

Sixnet results are therefore the cleanest direct competitive evidence about a region's canonical philosophy itself.

## 8. Academy call-up pulls careers back toward the regional centre

A voli can spend years playing a noncanonical or foreign club system and still represent their home region.

Example:

```text
Taktikã-born voli

FORMATIVE INHERITANCE
Taktikã

CLUB CAREER
several years in a high-transition, Pāwa-like club

ACADEMY CALL
canonical Taktikã representative structure
```

They are not tactically blank, nor are they identical to a domestic voli who spent eight years in orthodox Taktikã clubs.

Academy preparation therefore matters: representative duty temporarily assembles dispersed careers around the region's permanent tactical centre.

A highly proven contrary specialist may still be selected and used in a deliberately distinct role if their demonstrated value justifies the integration cost.

## 9. World identity consequence

Fixed regional philosophies make long-save history legible.

The player can meaningfully say:

- Taktikã has had a weak generation;
- Blôc's clubs are unusually experimental this decade;
- Pāwa's best setter plays abroad;
- an Xérvu club has become famous for refusing the regional serving orthodoxy;
- Zaitgaist has six incompatible tactical generations in one academy pool.

Those stories work because the regions themselves remain stable reference points.

If the regional philosophies continuously drifted toward whatever currently won, the world would eventually erase the contrasts that make those statements meaningful.

## 10. Design rules

1. **Canonical regional philosophies are fixed world identities.**
2. **Do not evolve one region's tactic into another region's tactic because of results or fashion.**
3. **Zaitgaist's changing borrowed content is the expression of its fixed meta-philosophy, not regional drift.**
4. **Club tactics are mutable and may reinforce, vary, or contradict the home region.**
5. **Club tactical variance is a major engine of transfers and specialist careers.**
6. **Tactical familiarity changes the cost of a move, not whether the move is permitted or rational.**
7. **Club results contribute to the club region's ecosystem even when the club is tactically unconventional.**
8. **Sixnet academies return dispersed home-region talent toward the region's canonical philosophy while still allowing proven specialist exceptions.**
9. **Stable regions + mutable clubs + mobile volis is the intended world structure.**
