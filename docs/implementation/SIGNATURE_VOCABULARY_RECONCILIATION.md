# Signature Vocabulary — Reconciliation Notes

Authority: `docs/design/SIGNATURE_VOCABULARY.md` for the new tier/vocabulary model. Existing rally/signature code remains implementation reality until deliberately migrated.

Post-presentation status: the real Match View now integrates fixture venues,
regional kits, a score bug, wrapped commentary, neutral announcers and camera
controls around authoritative rally playback. It does **not** migrate signature
vocabulary. Existing `SignatureMoveModel` / `SignatureSurge3D` paths remain the
legacy capability/manifestation/effect implementation and must not be relabeled
as tiered vocabulary without the census and ownership work below.

## Semantic migration

The older implementation/presentation term **surge** must not be interpreted as the design object. It is legacy naming for a manifestation/effect path.

New conceptual split:

1. **Capability** — attributes/body/state permit the underlying action.
2. **Vocabulary** — the Voli possesses the unusual solution.
3. **Manifestation** — current state + valid rally geometry make the vocabulary actionable/realized.
4. **Presentation** — downstream visual emphasis only.

## Tier 1 — States

- `Focus` — designed; mental execution stability, not extra knowledge.
- `Hustle` — designed; temporary overcoming of relevant fatigue-caused reductions for a legitimate urgent action, without deleting fatigue.
- remaining slots intentionally TBD.

## Tier 2 — Techniques

- `Pancake` — designed; forward/downward floor interception.
- `Rolling Receive` — designed; multi-directional moving contact + momentum dissipation through roll.
- all other role slots intentionally TBD.

Do not revive speculative techniques merely because earlier discussion named possibilities. Empty slots are design state.

## Tier 3 — High signatures

- `Foresight` — time/early commitment before decisive contact; can misread.
- `Heroics` — extreme reactive reach/recovery; narrow actionable window; denied state fabricates nothing.
- `Block Crush` — attacking force against meaningful blocking resistance.
- `High Hands` — attacking precision exploiting extreme block geometry.
- `Monster Block` — exceptional denial of attacking space.

## Existing trait-system overlap

Older trait design includes rare/restricted capabilities such as emergency setting, re-jumps and chase-down behavior. Do not automatically rename all rare traits as signatures.

Decision rule for later reconciliation:

- if it is an unusual persistent body fact -> trait;
- if it is a behavioral pull -> behavioral trait;
- if it is a learned/developed named volleyball solution with contextual manifestation -> signature vocabulary;
- if it is simply competence -> attribute;
- if it is only a player-facing description -> derived style.

Some existing rare traits may migrate categories, but that requires an explicit census rather than bulk conversion.

## Scouting implication

Signature vocabulary should support demonstration-gated knowledge: the Voli may possess a vocabulary entry before the manager/opponent has witnessed enough evidence to name it.

Do not expose hidden vocabulary merely because the data exists.

## Implementation debt

Before migrating code:

1. census current signature capability functions and state fields;
2. separate capability calculation from possession/vocabulary;
3. decide persistence/generation/development of vocabulary;
4. add vocabulary without changing ordinary underlying volleyball availability;
5. ensure manifestation uses authoritative action opportunities;
6. update VFX to read manifestation only;
7. add scouting/discovery later rather than conflating possession with knowledge.

No migration is performed by this reconciliation document.
