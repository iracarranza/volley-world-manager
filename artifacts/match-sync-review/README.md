# Match UI and playback synchronization review

These frames come from production `MatchScreen` playback of the deterministic
seed `970001`, with the same global UI styling pass used by `Application`.

- `match_controls.png` — player-facing Match Center indicator containers.
- `reception_flight.png` — reception output in flight toward the setter; the
  physical-time bar is partway through the resolved rally.
- `set_contact_seam.png` — the first set frame. The ball begins where the
  reception ended, at the setter's posed contact, without a hidden reset frame.

The renderer changes only presentation and inspection. It does not alter the
resolved rally, contact stamps, or ball trajectories.
