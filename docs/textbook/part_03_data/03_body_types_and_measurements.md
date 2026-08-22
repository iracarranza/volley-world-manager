# 03 — Body Types and Physical Measurements

Status: **VERIFIED**

VWM does not treat a player as a point with a speed rating. Physical interactions increasingly depend on the relationship between **body dimensions, movement state, contact height, and ball geometry**.

The key separation is:

```text
body measurements
→ what geometry the athlete physically has

physical/technical attributes
→ how strongly/quickly/accurately they can use it
```

## Body type is morphology, not ability

`VolleyballPlayer.body_type` is categorical and deliberately excluded from `ABILITY_ATTRIBUTES`.

A body type can affect proportions/appearance and derived geometry without being scored as “better.”

This prevents the game from quietly making one morphology a higher overall rating merely because it has a different frame.

## Measured player fields

Important physical data includes:

- `height_cm`;
- `mass_kg`;
- `wingspan_cm`;
- `stride_length_m`;
- dominant hand;
- body-type proportions.

These use real-world-ish units where practical. That makes relationships auditable.

A wingspan measured in centimetres can contribute to standing reach; stride length in metres can contribute to locomotion. A second independent “long arms coefficient” would duplicate the same fact.

## Derived reach

The architecture prefers deriving touch/reach from the body rather than storing unrelated endpoints.

Conceptually:

```text
height/body proportions
+ wingspan
→ standing/shoulder/arm geometry

jump capacity
→ elevation above standing reach
```

This lets different bodies reach the same ball for different reasons.

## Body centre versus contact point

One important rally migration corrected an old simplification: the player's body position was effectively placed on the ball/contact destination.

But a platform contact happens **in front of the body**.

The corrected relation uses existing shoulder/arm geometry:

```text
arm_length = standing_reach - shoulder_height
vertical_drop = shoulder_height - contact_height
horizontal_offset = sqrt(arm_length² - vertical_drop²)
```

within the physically meaningful range.

So a thigh/waist/chest platform contact can place the body behind the ball by a derived reach offset rather than by an authored “stand 0.6 m away” constant.

This is M3 of the rally roadmap.

## Why the shoulder anchor mattered

The project already had universal body ratios including a shoulder-height relation. Cross-checking the independently derived arm length against the existing skeleton data produced close agreement.

That kind of cross-check is valuable because it asks:

> do two independently authored representations of the same body fact agree?

It is stronger than adding another tuning parameter to make the output look plausible.

## Locomotion also uses morphology

`LocomotionModel` uses stride/cadence/mass relationships rather than one universal “rating → top speed” curve.

A player's build can therefore create tradeoffs:

- longer stride;
- different cadence/turnover;
- mass cost;
- different movement modes.

This is still a simplified game model, not biomechanics. The point is that the simplification is expressed in physically interpretable terms.

## Contact height is action-specific

Reception, dig, overhead play, block and attack do not all occur at the same body height.

The physical architecture therefore carries a contact family's actual contact height into geometry instead of using a trajectory endpoint as a proxy.

A contact height should answer “where does this body meet the ball?” not “where does the ball eventually go?”

## Facing and preparation

`RallyPlayerState` also carries facing/body state. M2 removed a fake `readiness` scalar and made preparation state more explicit.

Movement forms such as approach/transition can establish route-facing; other forms preserve facing. A deferred locomotion relation remains where the project lacks evidence for the exact cost of opening/turning.

This illustrates an important rule:

> represent a known state explicitly; do not invent a magnitude merely because a later calculation could use one.

## Presentation body versus simulation body

`PlayerActor3D` renders a detailed posed body for the match/sticker pipeline. It can consume player proportions and contact state.

But the visual rig is **not** the simulation's physical authority.

```text
simulation body/contact model
→ decides physical state
→ event/state data
→ PlayerActor3D draws it
```

Changing an arm pose should not increase contact reach unless the simulation model independently changes.

## Units matter

When reading physical code, annotate units mentally:

```text
height_cm            centimetres
stride_length_m      metres
velocity             usually m/s in physical flight/movement layers
angles               degrees or radians depending on API
normalized court XY  dimensionless court coordinates in some older/UI layers
```

Never assume two floats are compatible because both are `float`.

The T3 documentation audit is a recent example: values had been described inconsistently as angular units even though the producer measured spatial error in metres. The correction was documentation, not physics.

## Safe change checklist

If changing body geometry:

1. identify the physical quantity and unit;
2. find whether it is stored or derived already;
3. avoid a second representation of the same fact;
4. test multiple body builds/heights;
5. test boundary contact heights;
6. verify simulation and presentation agree without presentation becoming authority;
7. document any genuinely authored abstraction.

## Reading exercise

Trace one player's height/wingspan from `VolleyballPlayer` into:

- body-type/derived reach code;
- a rally contact geometry consumer;
- `PlayerActor3D`/sticker rendering.

Mark which path is authoritative for simulation and which is presentation.

## Source trail

- `scripts/models/volleyball_player.gd`
- `scripts/data/body_type_models.gd`
- `scripts/simulation/locomotion_model.gd`
- `scripts/models/rally_player_state.gd`
- `scenes/components/player_actor_3d.gd`
- `docs/review/BODY_CENTRE_SCOPE.md`
- `docs/review/BODY_CENTRE_PROMOTION.md`
- `docs/design/LOCOMOTION_AND_GENERATION.md`

Next: how those player facts are generated, capped, and developed over time.