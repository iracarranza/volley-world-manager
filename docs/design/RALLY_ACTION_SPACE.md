# Rally action space

This document records the architectural target for **what a player may choose to do with a live ball**. It is intentionally about action semantics, not tuning, animation, or outcome rates.

The governing rule is:

```text
ball arrives
→ legal actions
→ physically feasible actions
→ perception / responsibility / intent
→ action choice
→ attribute-driven execution
→ one authoritative outgoing ball
→ free flight / interaction / next contact
```

A team-contact number is context. It is **not** an action type.

The ordinary receive → set → attack pattern should be common because it is good volleyball, not because contact 1, 2, and 3 are hard-wired to those event labels.

## Current authority

The current rally architecture already demonstrates part of this separation:

- an overpass is the opponent's **ordinary first team contact**;
- that first contact may be an attack, controlled first contact, or emergency first contact;
- there is no fixed attack-over-control priority;
- physics determines which actions are available, while attributes, tactics, role, positioning, perception, body state, and contact quality determine which viable action is chosen and how well it is executed;
- an overhead/set-like first contact is temporarily excluded because the current `SET` resolver inherits second-contact semantics. It must not be admitted by mislabeling it as a set.

This is the first production-facing proof that `team_contact_number` and action type can be separated cleanly.

## Deferred action families

These are **design requirements for later milestones**, not instructions to implement them during the current M4/M5 integration.

### Contact one

A legal/physical first-contact action space must eventually be able to represent:

- controlled reception / dig;
- emergency keep-alive;
- direct attack on one, including legitimate overpass kills and aggressively played free balls;
- set on one when a first contact can honestly distribute directly to an attacker.

The last item requires generalizing the contact form currently called `SET` so it does not assume second-contact hitter selection, intent, or contact count.

### Contact two

Second contact must not imply `SET`.

Eventually viable choices include:

- conventional set;
- emergency/non-setter set;
- setter dump;
- attack on two by another eligible player;
- attack-look → set, including the unconventional fake-spike / second-ball distribution action;
- emergency control when the first ball has left no honest attacking/distribution option.

The underlying action choice can exist before deception is modeled. The **deception value** of preserving multiple plausible actions until late commitment belongs with continuous action/perception work in M7/M9.

### Contact three

Third contact should allow:

- full attack;
- tip/roll/downball as attack selections where those are already part of attack choice;
- deliberate controlled return / free ball when preserving the rally is preferable to forcing an attack;
- emergency save-over when no structured option remains.

A safe return is an action choice, not an `attack_error` with a friendly animation.

## Interactions that break simple ownership

### Block touch continuation

A block touch does not consume one of the blocking team's three contacts, and the blocker may legally make the next team contact. Therefore a nonterminal block touch must eventually become an ordinary live ball that the next responsibility/action layer resolves.

`stuff`, `tool`, `recycle`, and `touch` may describe interaction results, but they must not guarantee the next owner or continuation unless the resulting ball itself justifies it.

### Joust / simultaneous opposing contact

A joust is not attack-vs-block with one side preselected as owner. Two opposing bodies contest the same ball at the net and the resulting ball/ownership must emerge from the simultaneous interaction and legality.

This is a distinct interaction authority problem and belongs in the all-contact consistency work, not as an overpass special case.

### Live net rebound

Net contact is not always terminal. A pass, attack, block interaction, or emergency ball may contact the net and remain playable.

Future free-flight authority therefore needs to distinguish:

- terminal net fault / ball that cannot continue;
- legal live rebound remaining on the same side;
- tape interaction crossing to the other side where rules allow continuation.

Do not model these as predetermined next-event labels.

## Emergency actions

The simulator does not need a separate biomechanics engine for every named save. The design requirement is a sufficiently expressive emergency action family whose physical form can vary with contact geometry/posture.

Examples include one-arm stabs, pancakes, high-hand saves, diving contacts, and legal foot contacts. Their shared semantic intent is often simply **keep the ball alive somewhere useful if possible**.

This distinction matters especially for future coverage selection: survival can be a legitimate decision objective without requiring a coverage-only flight constant.

## Milestone ownership

### M5 — free flight / interception

M5 establishes that a ball exists independently of the event somebody hoped would happen next. It should not grow into the complete action-space rewrite.

### M6 — all-contact consistency + action semantics

M6 should audit every family against the common causal rubric and expose remaining places where contact number still dictates action type. Its design scope includes:

- generalizing first/second/third-contact action eligibility;
- set-on-one / attack-on-one;
- dumps and other attacks on two;
- safe third-ball returns;
- nonterminal block-touch continuation;
- joust authority;
- live net rebounds;
- legality that materially determines action availability.

M6 does **not** need every deception cue or polished animation to close.

### M7 — continuous actions and late commitment

M7 gives action choice a time dimension: setters/hitters/blockers/defenders act while the ball is still flying, preparation persists across event boundaries, and one preparation can leave several future actions plausible.

This is where the simulator can honestly support patterns such as jump-set vs dump, swing vs second-ball set, and other late-commitment ambiguity without opponents receiving impossible foreknowledge.

### M9 — tactical expression

M9 should prove that manager/player tendencies alter those choices in visible, interpretable ways rather than by directly changing outcome coefficients.

## Non-goals

Do not use this document to justify:

- implementing all rare volleyball edge cases immediately;
- adding named-move bonuses;
- making physics infer tactical intent;
- making intent widen physical feasibility;
- assigning an outcome before the outgoing ball exists;
- creating separate physics constants for every action label.

The purpose is structural: future actions should fit the same architecture without another event-chain rewrite.
