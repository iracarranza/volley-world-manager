# Rally first-draft debt ledger

This file is intentionally empty at specification authoring time. The implementation agent owns it during the first-draft run.

Do not pre-populate it with every item in `OUTSTANDING.md`. Record only failures/debt encountered or deliberately deferred while executing this packet.

## Entry template

```text
## FD-### — <short name>

Class: F0 / F1 / F2 / F3 / F4 / F5 / F6
Subsystem:
First observed at commit:
Reproduction command / fixture:
Expected semantic invariant:
Observed behavior:
Likely upstream owner:
Blocks later construction: yes / no
Why deferred:
Next diagnostic / repair:
Relevant existing spec/review:
```

## Rules

- F0/F1 are not normal deferred debt; if they appear here, explain why implementation could not continue.
- F2 should normally be resolved by migrating the obsolete assertion, not left here.
- F4/F5 are the main legitimate construction-time debt classes after M4 closes.
- Never relabel a missing authority decision/new authored magnitude (F6) as tuning debt.
- A failed named gate stays visibly failed until repaired or semantically replaced with an equivalent/stronger invariant.

## Post-draft clustering

When construction completes, group open entries under:

1. ball/contact authority
2. causality/timing
3. movement/actor continuity
4. responsibility/selection
5. attack/block interaction
6. home/opponent asymmetry
7. tactical wiring
8. presentation/reporting
9. calibration/balance

Repair clusters upstream-first rather than in test-file order.
