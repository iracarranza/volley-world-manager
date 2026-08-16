# Player-facing style, scouting, and traits

Design record. This document connects `TRAITS.md`, `SCOUTING.md`, `ACADEMY_SELECTION_AND_PROOF.md`, and the tactical-familiarity design. It defines how the human manager learns what kind of volleyball a voli actually plays without creating a second hidden role/archetype system.

## 1. The player-facing problem

Volleyball does not naturally provide a Football-Manager-style vocabulary of dozens of formal positional roles.

A middle can be patient or commit-heavy, explosive or rangy, quick-first or decoy-heavy. A libero can be a canonical seam reader, an exceptional tool defender, a pursuit specialist, or some mixture. Those differences need to be legible to the manager.

Two bad solutions are:

```text
BAD A
make the manager infer every tendency from raw attributes

BAD B
invent formal classes such as
"Explosive Commit Blocking Middle"
"Patient Read Blocking Middle"
"Tool-Defence Libero"
```

A creates unnecessary decoding work. B creates a second class system and eventually a giant artificial volleyball-role taxonomy.

The preferred solution is:

> Position remains structural. Play style is communicated through compositional, evidence-based descriptions.

## 2. No new authoritative play-style field

Do not add:

```text
play_style = EXPLOSIVE_COMMIT_BLOCKER
```

The simulation already has the underlying sources of truth:

```text
ATTRIBUTES
what can the voli do?

TRAITS
what do they characteristically attempt,
what unusual physical facts or exceptional capabilities distinguish them?

TACTICS
what is the coach currently asking them to do?

TACTICAL INHERITANCE / FAMILIARITY
what do they understand as normal and what have they learned here?

MATCH EVIDENCE
what have they actually attempted and succeeded at against real opponents?
```

Player-facing style language is derived from those facts.

A phrase such as:

```text
Middle · Commit blocker · Explosive closer · Quick-first
```

is an interpretation, not another stored identity.

## 3. Traits and style descriptions are not competitors

`TRAITS.md` already establishes the core semantic separation:

> Attributes describe competence. Traits describe individuality. Tactics describe what the coach wants.

Style descriptions add one more player-facing question:

> What does this voli currently look like when those things manifest together?

Therefore:

### Attribute

Question: **How capable are they at something?**

Examples:

- block timing;
- lateral speed;
- explosiveness;
- reception;
- anticipation.

### Behavioural trait

Question: **What do they characteristically try to do when their own instinct matters?**

Examples already contemplated in `TRAITS.md`:

- commits to the strong hitter often / rarely;
- looks for stuff vs soft touch;
- shows and closes;
- gravitates toward a defensive direction;
- attacks line / cut / tool preferentially.

These are causal inputs to decisions, especially where the voli may reinforce or deviate from a team instruction.

### Physical / rare / restricted trait

Question: **What unusual body fact or exceptional capability distinguishes them?**

Examples:

- unusually long arms;
- re-jumps after a decoy;
- keeps form while unbalanced;
- chases down tools, wipes, or bombas;
- exceptional restricted emergency-setting capability.

Rare traits may expand the available action set or alter physical constraints. They should remain rare and important.

### Style description

Question: **How does this voli appear to play?**

Examples:

- Commit blocker;
- Patient reader;
- Explosive closer;
- Seam reader;
- Tool defender;
- Quick-first attacker;
- Tempo changer.

A style description does not cause behaviour. It summarizes observed behaviour and capability.

## 4. Derived labels prevent duplicate truth

Suppose a middle has:

```text
explosiveness        very high
lateral speed        very high
block timing         good
anticipation         good

behavioural tendency
commits to strong hitter often

match evidence
repeatedly arrives early enough to erase first-tempo attacks
```

A scout may summarize:

```text
Commit blocker
Explosive closer
```

But neither phrase is stored as an independent mechanic.

This matters because otherwise contradictions become impossible to resolve. A voli might possess a commit-heavy behavioural tendency while spending several years in a patient-read club system. Their observed play may become mostly patient because of tactical discipline, familiarity, and coaching while the underlying tendency still appears at particular junctions.

A derived scout description can say:

> Usually plays as a patient reader in the current system, but commits unusually early when the first tempo becomes dangerous.

An immutable archetype cannot represent that cleanly.

## 5. Style language should be compositional

Do not concatenate every difference into one formal role name.

Prefer a small number of independent descriptors.

Possible vocabulary families, only where the simulator actually has the corresponding behaviour/evidence:

### Blocking behaviour

- Patient reader
- Active reader
- Commit blocker
- Hybrid blocker
- Pin-focused
- Middle-focused

### Blocking function

- Explosive closer
- Wide-range blocker
- Seam controller
- Line controller
- Late-recovery blocker
- High-contact blocker

### Attacking behaviour

- Quick-first
- Slide threat
- High-ball outlet
- Tool-focused
- Power-first
- Placement-first
- Transition attacker

### Floor defence

- Seam reader
- Tool reader
- Pursuit defender
- Stable platform
- Emergency defender
- Short-ball hunter

### Setting

- Tempo changer
- Quick-heavy
- Pin-heavy
- Disguise-oriented
- Stable distributor
- Aggressive distributor

This vocabulary is not a content promise. Do not author a descriptor for a behaviour the rally simulator cannot actually observe.

## 6. The same style can be good or bad

A style label is not praise.

```text
Commit blocker
block timing A
closing speed A-
```

may describe a valuable specialist.

```text
Commit blocker
block timing C+
closing speed B
```

may describe someone who guesses too early and exposes the rest of the block.

Likewise, `Patient reader` can describe elite interpretation or simple indecision depending on attributes and evidence.

Therefore style labels must never carry hidden quality bonuses.

## 7. Scouting should reveal style progressively

The manager should not have to decode every voli from raw numbers, but neither should the full behavioural truth be known immediately.

The existing scouting principles apply:

- visible physical facts can be learned quickly;
- technical capability takes more observation;
- behavioural tendencies require repeated relevant situations;
- rare traits may only be discovered when demonstrated;
- scout confidence matters;
- different scouts may eventually disagree.

Example progression:

```text
FIRST LOOK
Middle
Athletic
Blocking approach unclear

SOME OBSERVATION
Middle
Explosive closer
Appears aggressive in the block

WELL SCOUTED
Middle
Commit blocker
Explosive closer
Quick-first attacker

Scout note:
Repeatedly leaves the read early to remove first tempo.
Less convincing when required to hold and close to the pin.

RARE DISCOVERY
Re-jumps after a decoy
```

The label gets more specific because the evidence gets better.

## 8. Three levels of managerial knowledge

A useful hierarchy is:

```text
ATTRIBUTES
What might this voli be capable of?

SCOUT INTERPRETATION
How does this voli appear to play?

MATCH EVIDENCE
What have they actually proven, in what contexts?
```

The player is not required to reverse-engineer `block_timing + anticipation + explosiveness` into a style name.

But a sophisticated manager can still see beyond the report:

- the scout calls them a commit blocker, but against which attackers did it work?
- the report says patient reader, but they begin leaving early against elite quicks;
- the second libero looks ordinary until tooling-heavy opponents appear;
- an accepted public label may be incomplete or wrong.

Scouting supplies vocabulary. Match observation supplies judgment.

## 9. Preferred behaviour, current behaviour, and capability are distinct

Avoid describing every style label as what the voli "likes" to do.

Separate:

```text
PREFERENCE / TENDENCY
what they naturally reach for

CURRENT ASSIGNMENT
what the manager asks

CURRENT OBSERVED STYLE
what actually manifests under those instructions

CAPABILITY
what they can physically/technically execute

PROVEN SPECIALISM
what they have repeatedly made work
```

A middle may naturally commit but successfully play a read-heavy club system. Another may rarely commit on their own but be exceptional at doing it when explicitly instructed. Another may prefer to commit and simply be bad at it.

The UI should not collapse those cases.

## 10. Suggested player-facing hierarchy

A detailed scouting/voli view can eventually present something like:

```text
KAREL VOSA
Middle

STYLE
Commit blocker
Explosive closer
Quick-first attacker

ATTRIBUTES
[fogged profile]

TENDENCIES
Commits to strong hitter often
Looks for stuff

DISTINCTIVE TRAITS
Re-jumps after a decoy

SCOUT READ
Most effective when allowed to commit against a dangerous first-tempo option.
Less convincing when asked to hold and close late.

CONFIDENCE
Confident
```

The compact surface can simply say:

```text
Middle · Commit blocker · Explosive closer · Quick-first
```

The expanded surface explains why.

Not every behavioural trait must be exposed immediately. The style summary can become legible before the scout has fully resolved the underlying cause.

## 11. Academy selection uses evidence, not labels

This document does not change `ACADEMY_SELECTION_AND_PROOF.md`.

A label such as `Commit blocker` does not create a specialist slot or academy bonus.

Instead the manager/selectors ask:

```text
What has this voli actually proven?
Against whom?
In what role?
How repeatably?
What would that contribution add to this academy squad?
```

A canonical Blôc seam-reading libero may earn the first libero place because years of club play prove that they consistently occupy the seams Blôc's patient block creates.

A second libero may earn a place by repeatedly solving tooling-heavy attacks that the canonical structure handles less well.

A commit-blocking middle may earn a place by repeatedly shutting down first-tempo offences.

None of those players is selected because their descriptor exists. The descriptor only helps the human understand the evidence.

## 12. Club tactics make style discovery meaningful

Mutable club tactics are essential to this system.

A voli who does not fit the dominant local regional philosophy can find a club that uses their tendencies productively, receive minutes, and establish a body of evidence. Foreign clubs can do the same.

Therefore:

```text
UNUSUAL VOLI
        ↓
finds compatible club / manager
        ↓
gets real role and minutes
        ↓
observed tendencies become legible
        ↓
specialism succeeds or fails against real opposition
        ↓
academy case strengthens or disappears
```

The club is not merely where the voli develops attributes. It is where their individual volleyball becomes observable and defensible.

## 13. Design rules

1. **Position is structural; style is descriptive.**
2. **Do not create a new authoritative play-style/archetype field.**
3. **Attributes describe competence.**
4. **Behavioural traits describe individual pulls at decision junctions.**
5. **Rare/physical traits describe exceptional capability or unusual physical facts.**
6. **Tactics describe what the manager asks.**
7. **Style descriptions summarize what manifests.**
8. **Match evidence establishes whether that style is actually valuable.**
9. **Scouting progressively improves the description rather than instantly revealing the truth.**
10. **Academy selection evaluates proven representative value, not style labels.**
11. **Compound phrases may be used freely in prose, news, commentary, and scout summaries, but they must decompose back to real data and evidence.**
12. **Never invent a descriptor for behaviour the simulator does not actually support.**
