# Team identity and philosophy

What a club believes about volleyball, how that belief reaches the court, and
why it must never be a buff.

`TeamPrinciples` is built and this document does **not** propose replacing it.
It proposes naming the layer `TeamPrinciples` occupies, so the layers above and
below it stop being written into the same seven floats.

---

## 0. What exists today

`scripts/models/team_principles.gd` carries seven normalised axes —
`decisiveness`, `pin_focus`, `tempo_variation`, `emotional_expression`,
`serve_aggression`, `transition_commitment`, `block_commitment` — six presets
(Balanced, Technical, Physical, Defensive, Fast Tempo, Development), a
description per preset, and `alignment_distance` / `alignment_percent` for
comparing two sets.

They are read by the rally simulator on both sides of the net, and
`REGIONAL_DIFFERENTIATION_SPEC.md` and `PRINCIPLE_PRICING.md` cover how they
are priced and how a region expresses them.

**This is layer 3 below, and it is the right layer to have built first**, because
it is the only one that could be validated against a rally. Nothing here asks
for those fields to be renamed or re-tuned.

---

## 1. Seven layers, and only one of them is implemented

| | layer | asks | status |
|---|---|---|---|
| 1 | **club culture** | what kind of institution are we? | not built |
| 2 | **team philosophy** | how do we believe volleyball is won here? | not built |
| 3 | **tactical principles** | what patterns express that belief? | **`TeamPrinciples`** |
| 4 | **individual personality** | how does each voli read it? | partly — traits, ego, aggression, leadership exist |
| 5 | **athletic reality** | what can these bodies actually do? | built — attributes, morphology, fatigue |
| 6 | **match behaviour** | what does the team truly look like? | built — the rally |
| 7 | **external reputation** | what does everyone else say we are? | not built |

**Club culture (1) is long-lived** and survives roster and coaching turnover:
communal, severe, developmental, experimental, individualistic, patient,
demanding. It is a property of the institution, not of the current twelve.

**Team philosophy (2) is the sporting idea** — the readable, nameable belief
that a sports story would put on a banner. Working examples, not canonical
names:

> *Nothing Dies* · *One More Ball* · *Everyone Is an Option* · *Take the Net
> Away* · *First Contact, First Blood* · *Break Shape*

The gap that matters is between 2 and 3. A philosophy is a *sentence a person
would say*; principles are *the seven numbers that make a rally come out that
way*. Today the sentence is a preset name doing double duty, which is why
"Development" is both a coaching stance and a tempo setting.

---

## 2. Philosophy is tactical gravity, never a buff

**Hard rule.** A philosophy is not `Tenacity: digging +10%`. It does not touch
an attribute, a success rate or a coefficient.

What it biases:

- which options get prioritised when several are available
- which mistakes are tolerated and which are not
- what players expect *from each other*
- what they prepare for before the ball arrives
- what training keeps returning to
- which improvisations feel legitimate
- what gets celebrated, and what is unacceptable

**Reality overrules it, and that is not a failure of the philosophy.** A team
that believes in fast multi-option offence still gets a terrible pass, and a
terrible pass still forces a high outside ball. The belief did not evaporate;
the situation outranked it. A philosophy that could not be overruled would be a
buff wearing a name.

This is also the reason it must not become a fit meter. **Do not build a
numeric "culture fit" or "philosophy fit" percentage.** `alignment_percent`
exists to compare two *principle sets* — a real question with a real answer —
and that is a different thing from scoring a person against a belief. See §5.

---

## 3. Declared, lived, and external

Three identities, and they are allowed to disagree.

| | |
|---|---|
| **declared ideal** | what the manager and the club say they want to be |
| **lived identity** | what training, recruitment, tactical choice and repeated match behaviour have actually made true |
| **external reputation** | what opponents, scouts, supporters and media think you are |

> Declared: *"We play fearless attacking volleyball."*
> Lived: *"We serve aggressively and go conservative under pressure."*
> External: *"They're dangerous until you extend the rally."*

**The disagreement is the material, not an error state.** It is where a season
gets a story: a club discovering it is not what it says it is, a reputation that
lags a rebuild by two years, an opponent preparing for the team you used to be.

---

## 4. It has to be earned

Avoid:

```
select identity → the team now IS that identity
```

Prefer:

```
declared philosophy
  → training emphasis
    → tactical choices
      → recruitment
        → repeated match behaviour
          → how each voli reads it
            → lived identity
```

An identity can strengthen, drift, fracture or turn over across eras. A tactic
that keeps working becomes *what this club does*. A generation of volis can
reshape a philosophy they inherited. Nobody has to author any of that: it falls
out of the loop above if the loop is real.

---

## 5. Personality interprets; it does not match

The most important rule here, and the easiest one to get wrong.

**Never:**

```
aggressive voli + aggressive philosophy = good fit
aggressive voli + patient philosophy   = bad fit
```

That is a scalar with a costume on. Ask instead: **how does this person read
it?**

Philosophy: **One More Ball**

| | reads it as |
|---|---|
| ambitious | *every extra contact is another chance for me to win it* |
| egotistical attacker | *they keep it alive so I can finish* |
| experimental | *surviving buys time to try something* |
| conservative | *don't force it — hold the structure* |
| impatient | *why are we waiting for them to make the mistake?* |

All five **register** against the philosophy. None of them is a mismatch. Two
very different people can embody the same belief for opposite reasons, and that
is better drama and better simulation than either agreeing with it.

The philosophy has become a **social object** the squad has relationships to —
which is `CLUB_LIFE.md`'s register, and where the conflict material lives.
Contradiction is desirable.

---

## 6. The validation rule: visible without the label

The test that keeps this from becoming lore.

> Hide the club name, the identity label and the philosophy text. Watch ten
> rallies. Can a volleyball-literate observer say *"this team is trying to do
> something specific"*?

What each should visibly produce:

**Nothing Dies** — a disciplined defensive base; attack coverage that is
actually there; emergency contacts that stay playable; patient transition;
people rebuilding shape quickly after chaos.

**Everyone Is an Option** — several real approach threats; off-ball hitters
genuinely participating; a setter who keeps options alive rather than deciding
early; blockers forced to wait and read.

**First Contact, First Blood** — aggressive serving with the error rate that
implies; immediate transition aggression; a visible preference for short
rallies.

**If the philosophy is only legible from its UI label, it is lore rather than
simulation.** This is the same standard `VOLLEYBALL_FIDELITY.md` applies to the
rally generally, pointed at identity.

---

## 7. Outside the match

A philosophy that only exists on court is half-built. It acquires material
culture: chants, supporter language, uniforms, architecture, training rituals,
food traditions, sayings, rival mockery, club legends, inherited tactical
diagrams, recruiting stereotypes, media nicknames.

**None of it should be free-floating flavour.** Each should be downstream of the
region, the club's history, its actual behaviour, or specific people who have
been there. See `docs/world/STYLE_AND_SETTING.md` for the world-facing half —
including the rule that a media nickname must describe something the simulation
genuinely does.

---

## 8. Where this sits

**Not the current build priority.** `docs/BACKLOG.md` has volleyball fidelity as
the primary track; this document is design capture so the model exists when the
work starts.

When it does start, the cheapest useful first step is **separating the sentence
from the seven numbers** — a philosophy that names a preset rather than being
one — because that alone makes layers 1, 2 and 7 addressable without touching a
field the rally reads.

Read alongside: `TACTICS_AND_TRAINING.md` (how a belief becomes a drill),
`CLUB_LIFE.md` §1b (how disagreement becomes conflict),
`REGIONAL_IDENTITY_OVER_A_MATCH.md` (how a region's identity already survives a
match), `VOLLEYBALL_FIDELITY.md` (the visibility standard).
