# M3 promotion: the platform contact and the body are now different places

Run: 2026-08-17, from `5902056`. Instrument:
`tools/run_body_centre_probe.gd`.

`BODY_CENTRE_SCOPE.md` derived the missing relation and left it unconsumed. Its
first promotion attempt read `BallTrajectory.end_height_meters`, found the
serve's fictional 1.0 m default on every sampled arrival, and correctly reverted.
The promotion here does not settle that field's endpoint-vs-next-contact
semantics. It does not read the field at all.

## Authority

Every platform family already computes its contact height from the actual voli:

```gdscript
GeometricAttackPromotionModel.pass_contact_height_meters(voli)
```

Every arriving trajectory already publishes its launch point, so its court-space
incoming direction is `contact - start_position`. Those two existing facts are
now passed through all eight reception, dig and attack-coverage placement sites
to `_reached_point`. A full arrival calls `_body_behind_contact`, which consumes
`VolleyballPlayer.contact_offset_meters`; no stand-off constant, endpoint height,
presentation reconstruction or new body coefficient was added.

Partial journeys and read shortfalls deliberately keep their old stopping point.
Contact geometry is not permission to teleport a body the resolver said never
fully arrived.

## Before / after

The deterministic fixture sends one voli to five contacts from 0.4 to 4.5 m away
with ample time. Before promotion, **5 of 5** body centres ended exactly on the
ball. After promotion, **0 of 5** do: every body is **0.5220 m** behind contact,
exactly the offset derived from that voli's shoulder, standing reach, wingspan
and contact height.

The live-contact census also exposed why the promotion may not be applied to
every successful contact indiscriminately: successful defenders often play a
ball from within their existing reach without their centre completing the trip.
Those bodies remain at the end of the journey already resolved for them.

## Consequence, not target

On the canonical M4 census population (600 isolated rallies, seeds 23000–23299,
both serving sides), the outcome and event populations are byte-identical to the
recorded `5902056` baseline: 290 home points, 3,887 events, 785 platform contacts,
and every terminal count unchanged. That is an observation about this fixture,
not an outcome-equivalence requirement.

A second 240-rally fixed population moved one terminal from
`opponent_attack_error` to `kill`. The movement is explainable: the corrected
body position persists in `live_positions` and therefore changes a later journey
when the same voli acts again. It was recorded and not tuned away.

## Gates

`_test_platform_arrival_places_the_body_behind_contact` holds both directions:

1. a full arrival's body-to-ball distance equals the same voli's derived contact
   offset and lies behind the incoming ball;
2. a body with no usable time remains at its start rather than being snapped to
   the clean-contact position.

Full combined-worktree suite: **2,152 checks, no failures**. The M3 checkpoint
adds exactly two checks; three other checks in that count belong to the separate
local interface worktree.

## Verdict

**M3 is DONE for platform contacts.** Body centre and platform contact are
distinct under one body geometry, and the contact-family height—not an ambiguous
trajectory endpoint—owns the relation. Overhead set/attack/block geometry was
already represented by their own body-contact positions and is not reopened by
this promotion.
