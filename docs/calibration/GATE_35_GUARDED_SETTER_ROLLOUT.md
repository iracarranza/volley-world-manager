# Gate 35: Guarded Setter Rollout

Review date: 2026-07-30

Status: **IMPLEMENTED; PRODUCTION FLAG OFF**

`RallyRolloutPolicy.select_setter_source()` is the only setter promotion
boundary. It selects `continuous_setter` only when rollout is explicitly
requested and Gate 34 certifies the candidate. Otherwise it preserves the
official path and records a named fallback reason.

`ENABLE_CONTINUOUS_SETTER_EVENTS` remains `false`. Ordinary match resolution
therefore cannot promote a shadow setter candidate. Debug development fixtures
may opt in through `ALLOW_DEVELOPMENT_SETTER_OVERRIDE` only after a continuous
reception has already been applied.
