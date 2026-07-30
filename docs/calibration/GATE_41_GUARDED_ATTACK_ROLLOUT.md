# Gate 41: Guarded Attack Rollout

Review date: 2026-07-30

Status: **IMPLEMENTED; PRODUCTION FLAG OFF**

`RallyRolloutPolicy.select_attack_source()` is the attack promotion boundary.
It selects `continuous_attack` only when rollout is explicitly requested and
Gate 40 certifies the candidate. A preflight check also proves the persistent
state can accept the contact before the selected assignment replaces legacy
choice.

`ENABLE_CONTINUOUS_ATTACK_EVENTS` remains `false`. The debug override is
available only after reception and setter contacts were both promoted.
Ordinary match resolution preserves official attack selection and targeting.
