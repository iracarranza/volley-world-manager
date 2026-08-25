# Match Adaptation — Design to Implementation

## Intended loop

Match adaptation is not a generic adaptive-AI modifier. It is an evidence loop:

`offense chooses -> repeated geometry creates exposure -> defenders learn -> read/position/commit changes -> offense prices the read -> setter/hitters choose again`

The physical resolver remains authoritative throughout.

## Live pieces

### Situation exposure

`VolleyballFamiliaritySystem.record_exposure()` writes tagged experience using individual `adaptability` and a regional read-rate term. `familiarity()` converts accumulated tagged experience into a bounded learned value. `read_modifier()` combines learned familiarity, scouting and mental attributes.

This is genuine stateful adaptation: the same Voli can become a better reader of a repeated situation without becoming a better athlete.

### Setter response

`SETTER_DECISION.md` records the shared option vocabulary as live. Setter option pricing includes a lane the block has learned, while `set_disguise` and `unpredictability` reduce the cost of readable patterns without turning choice into deterministic argmax.

### Pressure state

Team `match_flow` and setter `match_confidence` are consumed by the setter decision as a bounded desperation term. Career `satisfaction` is explicitly excluded from rally choice.

## Incomplete pieces

`SETTER_DECISION.md` explicitly leaves **concentration over a longer sample** unfinished. Match observation already prices a learned lane, but the full setter-distribution history and concentration calibration still need a dedicated sweep.

Therefore the adaptation loop is **PARTIAL but real**: its state, read consumer, and offensive counter-response exist; its long-sample behavioral proof is not complete.

## Census

| Link | State |
|---|---|
| Repeated situation is tagged | LIVE |
| Exposure accumulates per Voli | LIVE |
| Adaptability/regional tradition affect learning | LIVE |
| Familiarity affects read | LIVE |
| Read can influence setter option cost | LIVE |
| Match confidence affects setter preference | LIVE |
| Team flow affects setter preference | LIVE |
| Full setter target-distribution history | PARTIAL |
| Rising concentration -> measurably earlier/more committed defense | PARTIAL |
| Offense exploiting opponent adaptation | PARTIAL |
| Cross-match/season opponent scouting persistence | UNKNOWN |
| Human-facing explanation of what opponent learned | UNKNOWN |

## Required proof after M9

Do not implement another adaptation system. Instead run controlled traces proving the existing chain:

1. hold roster/attributes constant;
2. create repeated offensive concentration;
3. verify exposure population is non-zero and correctly attributed;
4. verify defender read terms rise;
5. verify defensive decision/position changes downstream;
6. verify setter option decomposition prices that change;
7. verify an unpredictable/disguised setter changes the response without deleting defensive knowledge;
8. verify both sides use equivalent semantics.

The desired result is not a target kill percentage. It is a demonstrated causal loop.