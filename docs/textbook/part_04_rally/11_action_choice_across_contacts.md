# 11 — Action Choice Across Team Contacts

Status: **PARTIALLY IMPLEMENTED + PROPOSED TARGET**

The long-term action-space rule is simple:

> **team contact number is context, not action type.**

The common receive → set → attack sequence should emerge because it is usually good volleyball—not because the engine translates contact 1/2/3 directly into those three event labels.

## What exists today

The current overpass system already proves part of this architecture:

```text
opponent first team contact
→ controlled first contact OR emergency first contact OR attack
```

That is real implemented decision structure.

The full cross-contact vocabulary below is **not** all implemented yet.

## Contact one target

Eventually first contact should be able to represent, where legal/physical:

- controlled reception/dig;
- emergency keep-alive;
- direct attack on one;
- set/distribution on one.

Set-on-one specifically requires generalizing the current set contact form so it no longer inherits second-contact assumptions.

## Contact two target

Second contact should eventually support:

- conventional set;
- emergency/non-setter set;
- setter dump;
- attack on two by another eligible player;
- attack-look → set / fake-spike distribution;
- emergency control when structure is broken.

The existence of an attack option on contact #2 does not mean every player should choose it often. Player ability, temperament, tactics, block/defence state and information should make conventional setting dominant in ordinary circumstances.

## Contact three target

Third contact can include:

- full attack;
- existing attack variations such as tip/roll/downball where appropriate;
- deliberate controlled free-ball return;
- emergency save-over.

A safe return should be a chosen action, not an “attack failure” disguised with a soft animation.

## Emergency contact family

The simulator does not need a unique physics engine for every named save:

- one-arm stab;
- pancake;
- high-hands emergency save;
- foot contact;
- diving keep-alive.

Many can share an emergency semantic intent—**keep the ball alive if physically possible**—while posture/contact geometry determines what form is feasible.

Named moves can remain presentation/classification unless they require genuinely different physical constraints.

## Block-touch continuation

A playable block touch should eventually produce an ordinary live ball on the blocking side, without consuming a team contact.

The next actor—including the blocker—then competes for contact #1 based on physical/legal responsibility.

This avoids outcome labels like `recycle` silently pre-authoring the next owner.

## Net rebounds

Net contact is not always terminal.

Future all-contact flight authority should distinguish:

```text
ball hits net and dies/faults
ball rebounds legally on same side
ball clips tape and crosses legally
```

The resulting ball should feed the same opportunity/action machinery rather than a canned next event.

## Jousts

A joust is a simultaneous opposing-ball interaction near the net.

It cannot be represented honestly if the engine must choose “attack happened first, block happened second” before resolving both bodies' contact.

M6 should define the interaction authority; this is not part of the current M5 overpass task.

## Deception is later than action availability

It is possible to implement:

```text
setter may set OR dump
```

before implementing the full perceptual benefit of hiding that choice until late.

Late commitment needs continuous preparation/action timelines:

```text
same visible preparation
→ several actions remain plausible
→ opponent must commit before knowing final choice
```

That belongs mainly to M7/M9.

## Why this architecture is valuable

Once action type is separated from contact number, broken plays become natural:

```text
setter digs first ball
→ libero/other player sets second
→ hitter attacks third
```

or:

```text
free ball arrives high at front row
→ hitter attacks on one
```

No special rally script needs to recognize the whole sequence by name.

## Design boundary: choice versus contact form

A “set” contains at least two concepts:

1. **intent/action** — distribute ball to an attacker;
2. **physical contact form** — hands/overhead/other technique.

The current event/resolver often bundles those because ordinary second contact uses both together.

M6 will need to tease them apart enough that an overhead first contact or attack-look set can use honest contact physics without inheriting unrelated second-contact bookkeeping.

## Rules must prune the space

A generalized action chooser does not mean every action is available everywhere.

Pipeline:

```text
candidate action vocabulary
→ volleyball legality
→ physical feasibility
→ information/decision
→ execution
```

A libero/back-row restriction can remove attack options; a compromised body can remove overhead/attack form; lack of time can reduce the player to emergency control.

## Avoid a universal action-score soup

It may be tempting to put every action into one table with arbitrary weights.

Share common factors where they are semantically common, but allow action families to have meaningful decision logic.

The goal is one **causal architecture**, not necessarily one giant formula.

## Safe future implementation sequence

For each new action:

1. define semantic intent;
2. define legal constraints;
3. map to existing/new physical contact form;
4. expose physical opportunity;
5. choose using available information/tactics/player tendencies;
6. execute into one outgoing ball;
7. continue from that ball;
8. add presentation/event label afterward.

## Reading exercise

Open `docs/design/RALLY_ACTION_SPACE.md` and classify every listed action/interaction as:

- current implemented authority;
- M6 action-space/interaction work;
- M7 continuous/deception work;
- M9 tactical-expression proof.

Then identify which existing contact resolver could likely be reused for each future action.

## Source trail

- `docs/design/RALLY_ACTION_SPACE.md`
- `scripts/simulation/overpass_action_system.gd`
- `scripts/simulation/rally_decision_system.gd`
- current set/attack/platform systems

Next: the roadmap that sequences these architectural changes without pretending milestone numbers are hard implementation walls.