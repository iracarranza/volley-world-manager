# Gate 25: Visible Contact Envelopes

Review date: 2026-07-30

Status: **IMPLEMENTED; MANUAL VISUAL REVIEW PENDING; SHADOW ONLY**

## Purpose

Expose the Gate 24 physical-access evidence on the debug court before changing
balance parameters. A developer can now distinguish movement lateness from a
horizontal reach miss or a vertical standing/jump constraint.

## Overlay contract

- `Contact envelopes` is a selectable shadow-debug layer and is visible by
  default in debug builds.
- The selected second-contact player's final projected position owns the
  metre-scaled horizontal envelope.
- A dashed segment connects that position to the authoritative outgoing-pass
  destination.
- The label reports horizontal reach, ball contact height, standing reach,
  maximum available height, and `STAND`, `JUMP`, or `LATE` access.
- Court geometry is visualization only. Every displayed value comes from the
  shadow response produced by `ContactEnvelopeSystem`.

## Safety boundary

This gate adds no tuning values and no rollout branch. Official rally events,
receiver ownership, setter ownership, and scoring remain unchanged.

## Next review

Use the normal, off-center setter, and setter-first-contact debug fixtures at
several fixed seeds. Record whether developing setters fail because of late
recognition, insufficient movement time, horizontal reach, vertical access, or
poor body state. Only then choose a narrow action-specific calibration; do not
increase global movement speed.
