# M9 latent tactical field audit

Measured at canonical M9 `78eb4614fa12057581919c571dc3081cb9e242ea`.

## `DefensivePlan.block_intent`

| Leg | Evidence | Finding |
|---|---|---|
| Runtime/UI writer | Repository-wide assignment search finds only `DefensivePlan.load_dict()`, test fixtures, and `run_block_band_probe.gd` | No production manager/UI writer |
| Default/runtime population | `DefensivePlan.block_intent = "Balanced"`; generated plans do not change it | Ordinary runtime is stuck at `Balanced` |
| Persistence | `to_dict()` writes and `load_dict()` restores `Seal/Balanced/Funnel` | Old/external saves can supply a non-default value |
| Consumer | `RallySimulator._block_intent_margins()` and geometric promotion paths | Materially shifts stuff/touch/funnel bands and is published on block events |
| Documentation defect | Model/backlog prose called it a coach/clipboard choice | Claim exceeded production ownership and is corrected in the canonical packet/model comments |

Disposition: **live-but-unowned compatibility state; excluded from the player-selectable M9 census**. Existing design authority supports the manager choosing the blocking problem—strategy, lane/spatial responsibility, block-floor relationship and established broad hands preference—while the Voli should likely choose a momentary seal/funnel/control solution from tactics, read, attributes, traits, timing, position and rally state. Physics remains the result owner. M9 does not add a dropdown or invent a new Voli decision subsystem; that ownership/design decision remains explicit debt.

## `OffensivePlay.fallback_lane`

| Leg | Evidence | Finding |
|---|---|---|
| Runtime/UI writer | Only `OffensivePlay.from_dict()` assigns it | No runtime writer or selectable control |
| Persistence | `to_dict()/from_dict()` preserve it, default `Left Pin` | Save-schema compatibility exists |
| Validation | `PlayValidator` checks that the string is a legal lane | Syntax validation only |
| Live read | Repository-wide field search finds no simulation read | No gameplay consequence |
| Name collision | `ShadowAttackSystem._fallback_lane(slot)` derives a lane from rotation slot | Unrelated helper; it never reads `OffensivePlay.fallback_lane` |

Disposition: **serialized/validated but unread compatibility-only schema; excluded from the player-selectable census**. It creates no false player agency because no UI exposes it. Removal/migration can be considered with a future save-schema cleanup, but M9 does not manufacture fallback behavior.

## Anti-fabrication conclusion

Neither field is promoted to `CAUSAL`. The 39-row census remains limited to actual selectable controls whose meanings are established and whose decision/physical paths are certified.
