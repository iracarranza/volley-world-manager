# P6-C2 — Beginner Project Ladder

Status: **HISTORICAL LEARNING SEQUENCE**, not the active roadmap
Keywords: roadmap, beginner projects, vertical slices, simulation migration

These exercises reconstruct the migration in a safe teaching order. Levels 1–7
already have implementations in the repository and should not be mistaken for
current project tasks. A learner may rebuild them in isolated tests. Active
development must follow the [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md).

## Level 1: Read-only rally inspector — implemented

Display event sequence, type, actor, start/end positions, and trajectory duration after a rally. Learn Resources, Arrays, Dictionaries, and UI binding without changing simulation.

## Level 2: Fixed-seed scenario runner — implemented

Add a developer control for entering a seed and replaying it. Learn deterministic debugging and safe scene-to-manager calls.

## Level 3: Persistent reception laboratory — implemented

Build a test-only or developer-only view showing ball destination, player start positions, arrival estimates, and candidate reception opportunities. Do not replace live results yet.

## Level 4: Shadow simulation comparison — implemented

Run the legacy reception resolution and persistent reception model from the same inputs. Log differences without changing the official result. Learn integration and observability.

## Level 5: Development-only live persistent reception — implemented

Use the new model for serve-to-reception, convert it to existing event records, and leave later contacts on the legacy resolver. This may require an adapter boundary or controlled hybrid resolver.

## Level 6: Second-contact opportunities — implemented

Generate normal and emergency setting options from pass flight and actual player state.

## Level 7: Attack approach and choice — implemented through Gate 43

Generate attack options from set timing, eligibility, approach state, familiarity, and opponent information.

## Level 8: User-facing decision explanations

Expose concise reasons for chosen, rejected, newly unlocked, and high-risk actions. Connect player development to visible tactical agency.

This remains future product work, but it is not the next engine gate. Block
observations and coordinated physical resolution must first produce trustworthy
decision evidence to explain.
