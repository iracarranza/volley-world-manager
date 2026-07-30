# Gate 21: Setter Ownership Handoff Audit

Review date: 2026-07-30

Status: **PASS; SHADOW ONLY**

## Purpose

Verify that second-contact ownership follows tactical intent but can transfer
when another eligible player owns a stronger action window.

## Fixtures

`SetterHandoffCalibration` runs paired seeds across all five serve styles:

1. `natural` checks ordinary ownership retention.
2. `forced_setter_first_contact` makes the active setter receive and verifies
   that the assigned emergency setter becomes the intended second-contact
   owner.
3. `forced_late_intended_setter` makes the intended setter slow and distant
   while an assigned alternate is prepared near the pass target. This forces
   the live handoff branch.

## Reproduction

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=8 --start-seed=210000 --setter-handoffs
```

## Measured result

- 37 usable outgoing passes across the three fixtures;
- zero invalid ownership selections;
- 100% emergency intent when the active setter took first contact;
- 10 of 10 forced-late samples transferred ownership;
- 100% of those handoffs selected a candidate whose score was at least as
  strong as the intended setter's;
- selected reachability in the forced-late fixture was 90%, compared with 20%
  for the intended setter.

The reasons were recorded as `intended setter arrived late` or
`alternate setter owned the stronger action window`. Official events were not
changed.
