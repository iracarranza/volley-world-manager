# P6-C2 — Beginner Project Ladder

Status: **PROPOSED** learning sequence
Keywords: roadmap, beginner projects, vertical slices, simulation migration

Complete projects in order. Each one teaches a concept needed by the next.

## Level 1: Read-only rally inspector

Display event sequence, type, actor, start/end positions, and trajectory duration after a rally. Learn Resources, Arrays, Dictionaries, and UI binding without changing simulation.

## Level 2: Fixed-seed scenario runner

Add a developer control for entering a seed and replaying it. Learn deterministic debugging and safe scene-to-manager calls.

## Level 3: Persistent reception laboratory

Build a test-only or developer-only view showing ball destination, player start positions, arrival estimates, and candidate reception opportunities. Do not replace live results yet.

## Level 4: Shadow simulation comparison

Run the legacy reception resolution and persistent reception model from the same inputs. Log differences without changing the official result. Learn integration and observability.

## Level 5: Live persistent reception

Use the new model for serve-to-reception, convert it to existing event records, and leave later contacts on the legacy resolver. This may require an adapter boundary or controlled hybrid resolver.

## Level 6: Second-contact opportunities

Generate normal and emergency setting options from pass flight and actual player state.

## Level 7: Attack approach and choice

Generate attack options from set timing, eligibility, approach state, familiarity, and opponent information.

## Level 8: User-facing decision explanations

Expose concise reasons for chosen, rejected, newly unlocked, and high-risk actions. Connect player development to visible tactical agency.
