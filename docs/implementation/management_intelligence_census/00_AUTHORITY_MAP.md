# Management Intelligence Census — Authority Map

Baseline: M8 line plus documentation commits through `SIGNATURE_VOCABULARY.md`. This packet audits the management-intelligence systems that sit around, but are not the M9 tactical-causality implementation itself.

## Classification

- **LIVE** — authoritative data, producer and meaningful consumer exist.
- **PARTIAL** — meaningful implementation exists but the designed causal loop is incomplete.
- **DATA_ONLY** — authoritative-looking state/model exists without the designed gameplay consumer.
- **UI_ONLY** — presentation/control exists without the designed underlying causal state.
- **ABSENT** — designed concept has no meaningful implementation found.
- **STALE_DOC** — documentation describes a state known to have been superseded.
- **UNKNOWN** — evidence available in this audit was insufficient; do not infer absence.

## Load-bearing authority split

| Concept | Intended authority | Current evidence | State |
|---|---|---|---|
| Player capability | `VolleyballPlayer` ratings/body | broad 1–100 physical/technical/mental model live | LIVE |
| Behavioral individuality | traits + temperament fields | `traits`, ego, aggression, work rate etc. exist; complete junction coverage not proven here | PARTIAL |
| Match confidence | `VolleyballPlayer.match_confidence` | explicit point-to-point state; setter decision consumes it | LIVE |
| Team match flow | team/match state | setter decision explicitly consumes it | LIVE |
| Situation exposure/read | `situation_experience` + `FamiliaritySystem` | `record_exposure`, `familiarity`, `read_modifier` live | LIVE |
| Position familiarity | `position_familiarity` | initialization, training and execution modifier live | LIVE |
| Pair familiarity | `PairFamiliarity` table | growth/decay/seed/query live; exact use in every intended decision not proven | PARTIAL |
| Learned tactical preferences | coordinate/tempo/locus/posture offsets | design explicitly says not built; current `SystemFitProfile` remains rating-derived | ABSENT |
| Match-training demonstration | live training appointment | design explicitly says not built | ABSENT |
| Play Designer | high-level authoring interface decomposing into trainables | newly specified; no implementation | ABSENT |
| Tactical plan decomposition/fit | planner -> asks -> comfort score | planner exists; decomposition/fit explicitly not built in design record | PARTIAL |
| Recruitment scouting fog | `ScoutingSystem` view over truth | deterministic uncertainty reduction and per-channel knowability live | LIVE |
| Per-scout belief ownership | scout-specific estimate/confidence | backlog states beliefs-with-owner landed | LIVE |
| Scouting freshness | time since observation widens uncertainty | design/backlog says still open | ABSENT |
| Scouting geography | scout regional knowledge/network/freshness | designed, staff fields exist, consumer not established | DATA_ONLY |
| Scout report record | persistent past claims so judgment can be evaluated | designed; no live evidence found | ABSENT |
| Derived player style | interpretation from attributes/traits/tactics/evidence | design authority exists; complete derivation/UI not established | PARTIAL |
| Signature vocabulary | capability + vocabulary + state/context | design authority only; current signature implementation predates tier model | PARTIAL |

## Core rule

Do not create a generic `adaptation`, `intelligence`, `style`, `play_familiarity`, or `signature_power` value to summarize this layer. The existing design deliberately distributes cognition across quantities with different natural owners and timescales.

## Timescales

1. **Contact/rally:** perception, feasibility, decision, physical execution.
2. **Point-to-point:** match confidence and team match flow.
3. **Within match / repeated exposure:** situation experience, scouting/read of repeated geometry.
4. **Across matches:** pair familiarity and evidence accumulation.
5. **Training:** position familiarity now; learned tactical preferences and pair-specific tempo comfort later.
6. **Recruitment knowledge:** scout belief/confidence/freshness.
7. **Career:** ratings, traits, vocabulary, development and long-term evidence.

These are intentionally not one system.

## Primary finding

The project is not missing a design for cognition/adaptation. It is missing several bridges between already-live pieces:

- exposure exists, but the complete concentration/adaptation sweep remains unfinished;
- pair familiarity exists, but the designed **tempo-specific hitter–setter relationship** is richer than one general pair number;
- tactical planner and rating-derived system-fit exist, but learned preferences and planner-to-drill decomposition do not;
- scouting uncertainty is unusually mature, while freshness, geography, report history and some discovery channels remain open;
- style language is designed as derived evidence, not a causal archetype, but the full derivation surface is not yet proven live.

The correct next work is therefore seam completion, not invention of a new cognition subsystem.