# Traits, Style and Decisions

## Authority

The established semantic split is:

- **Attributes:** competence/capability.
- **Traits/temperament:** individuality; what the Voli characteristically attempts or how strongly they hold a decision.
- **Tactics:** manager intent.
- **Familiarity/training:** learned comfort.
- **Style descriptions:** derived interpretation of what manifests.
- **Match evidence:** proof of what actually happened and worked.

Do not add an authoritative `play_style` archetype.

## Current evidence

`VolleyballPlayer` already contains several non-ability behavioral axes with explicit causal intent:

- `work_rate` — willingness to spend physical capacity;
- `ego` — how hard a decision is to change;
- `aggression` — commitment to terminal/violent solutions;
- `leadership` — affects others rather than own ability;
- `unpredictability` — distribution pattern readability;
- `match_confidence` — current match belief/state;
- `traits` — categorical individual facts/tendencies.

This is richer than a generic personality modifier and should stay distributed.

## Style descriptions

`PLAYER_STYLE_SCOUTING_AND_TRAITS.md` correctly defines labels such as `Commit blocker`, `Explosive closer`, `Quick-first`, `Pursuit defender` as **descriptions**, not causes.

A label may summarize attributes + traits + tactics + familiarity + evidence. It must never provide a hidden bonus.

The full player-facing derivation/discovery surface was not proven live in this audit, so classify it **PARTIAL**, not absent.

## Signature vocabulary interaction

The new signature model adds another distinct question:

- capability asks whether the underlying action is possible;
- traits ask what the Voli tends to attempt;
- signature vocabulary asks which unusual solutions the Voli has developed/possesses;
- state/context determines whether they manifest.

Do not put signatures into the style/archetype field, and do not treat possession as proof of frequent use.

## Audit targets after M9

1. Enumerate every decision junction that reads a behavioral trait/temperament.
2. Enumerate behavioral fields that are stored/generated but never consumed.
3. Verify tactic-versus-trait conflict can actually resolve differently for two similar Volis.
4. Verify high/low values are not accidentally treated as universally better where the design says they are temperament axes.
5. Verify derived style labels only claim behaviors for which simulator evidence exists.
6. Verify scouting uncertainty applies to behavioral/style knowledge at an appropriate timescale.

The major risk is not missing trait count. It is **stored personality that never reaches a decision junction**, which creates descriptive complexity without gameplay individuality.