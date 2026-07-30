# Gate 26: Setter Failure Taxonomy

Review date: 2026-07-30

Status: **PASS; DIAGNOSTIC**

`SetterFailureClassifier` assigns every selected second-contact response one
primary cause plus contributing causes: perception error, vertical access,
takeoff timing, body state, recognition delay, horizontal access, insufficient
movement time, or technical action unavailability.

Batch calibration now reports `setter_failure_causes`. In the 600-serve Gate 29
audit, 111 selected setters failed primarily for insufficient movement time and
50 for perception error; horizontal access accounted for only 9. This evidence
ruled out a global reach increase.
