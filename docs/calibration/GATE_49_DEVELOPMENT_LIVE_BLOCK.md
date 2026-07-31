# Gate 49: Development-Only Promoted Block Contact

Review date: 2026-07-31

Status: **PASS; DEVELOPMENT FIXTURE ONLY; PRODUCTION FLAG OFF**

Gate 48 built the block selection boundary and deliberately held it shut, with
`activation_implemented` false because nothing existed behind it. Gate 49 builds
that something -- `LiveBlockIntegrator` -- and opens the branch. It closes the
block slice that began at Gate 44.

`ENABLE_CONTINUOUS_BLOCK_EVENTS` remains `false`. Promotion happens only when
`ALLOW_DEVELOPMENT_BLOCK_OVERRIDE` (now `true`), `OS.is_debug_build()`, and an
explicitly requested development fixture all hold -- and only on top of a
promoted attack.

## Why a promoted block requires a promoted attack

The shadow block system reads the *shadow* attack. If the official attack went
somewhere else, promoting a block computed against the shadow attack would put
blockers on a lane the official ball never travelled to -- a block of nothing.

So `block_rollout_requested` includes `using_live_attack`, extending the chain
discipline the earlier gates established: setter promotion requires a promoted
reception, attack requires a promoted setter, block requires a promoted attack.
Across a 400-seed sweep, 6 rallies satisfied the full chain and promoted; the
other 373 that reached the boundary fell back with `rollout_disabled`.

This is also why the selection boundary moved. Gate 48 evaluated
`select_block_source()` immediately after the shadow block, before the attack
rollout was known. Gate 49 moves it to the point of use, just before the
official block resolves, where `using_live_attack` is final.

## Three ways this differs from LiveAttackIntegrator

The architecture is copied; these three departures come from the sport.

**The blockers are opponents.** Every state lookup uses the opponent side, and
the policy takes the opponent lineup.

**A block touch is not a contact.** Rule 14.4.1: a block touch does not count as
one of the blocking team's three contacts. `RallyState.register_contact()` flips
possession and sets the counter to 1, which is right for an ordinary contact and
wrong for a block. `apply()` therefore registers the touch and then resets
`contact_number` and `ball.contact_count` to zero, so the blocking team still
has three contacts available. The regression suite asserts this directly.

**A promoted block cannot miss.** The Gate 47 audit certifies the primary
reaches the ball before the candidate is eligible at all, so `miss` is
unreachable in the promoted path by construction. Outcome narrows to a terminal
`stuff` or a `recycle` the attacking side must dig.

## How outcome is decided

From the audited candidate's own physical facts only -- closer count, arrival
margins, and whether the close required a jump. No RNG, no authoritative attack
truth, no perceived blocker state. A block is terminal only when two bodies got
there, over the net, with time to spare:

```
stuff  <- closer_count >= 2
          and primary_requires_jump
          and primary_arrival_margin >= 0.06s
          and assist_arrival_margin >= 0.0
recycle <- otherwise
```

Every promoted block in the observed sweep was a single-blocker `recycle`, which
means the terminal branch never fires in ordinary play. Rather than leave it as
unverified code, the suite drives it directly with a synthetic two-blocker
candidate and asserts the seal.

## Scope: contact and flight, not continuation

`apply()` promotes the block touch -- blocker positions, body states, recovery
windows, contact time, and the outgoing deflection flight -- and the simulator
overrides who blocked and what the outcome was. The coverage geometry and
everything after remain the legacy continuation, exactly as Gate 42 promoted the
hitter contact and left blocking on the legacy path.

## Verification

Five checks in `_test_gate_forty_nine_development_live_block`, on seed 300062 --
the same seed Gate 42 uses, necessarily, since the two fixtures share a chain:

1. the fixture promotes one audited block contact, and the emitted `BLOCK` event
   is marked `continuous_block` with the promoted primary as its actor;
2. the block touch leaves the contact counter at zero with the ball in flight;
3. the same seed promotes the same block twice -- primary, outcome, deflection
   target, and flight end time all identical;
4. ordinary (non-development) resolution of that same seed still produces an
   official block and never a promoted one;
5. a synthetic two-blocker candidate seals to a terminal `stuff`, and a
   candidate offered with no home attack in state is rejected by name.

Gate 48's forced-flag check was rewritten rather than deleted: it asserted the
boundary refuses to promote *because no activation existed*, which Gate 49 made
false on purpose. It now asserts the opposite contract -- an eligible candidate
with the flag forced on is selected, and official identity is surrendered when
it is.

Full suite: 390 checks passing (385 before this gate).
