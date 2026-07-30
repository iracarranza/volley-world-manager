# Gate 29: Guarded Reception Rollout

Review date: 2026-07-30

Status: **IMPLEMENTED; PRODUCTION FLAG OFF**

`RallyRolloutPolicy` now contains a real activation branch. It selects
`continuous_reception` only when rollout is explicitly requested and Gate 28
certifies the candidate. Otherwise it returns the complete official event list
with an explicit fallback reason.

`ENABLE_CONTINUOUS_RECEPTION_EVENTS` remains `false`. Ordinary match resolution
therefore preserves the production-off behavior established by Gate 15.

The 600-serve disabled batch selected official events 100%, preserved official
identity 100%, and reported zero invalid samples.
