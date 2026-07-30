# Gate 31: Player Observation Contract

Review date: 2026-07-30

Status: **PASS; SETTER SLICE**

`PlayerObservation` is the decision-safe input for second-contact ownership. It
contains perceived ball destination, arrival, height, confidence, recognition,
responsibility, perceived feasibility, and perceived actions. Authoritative
flight and contact facts remain outside the observation.

Setter candidates record a deterministic observation fingerprint. Foundation
tests prove that changing resolver-only reachability and arrival-margin truth
without changing the observation cannot change its selection score.

This gate establishes the boundary for the setter slice only. Attack, block,
and floor-defense decisions still require later observation migrations.
