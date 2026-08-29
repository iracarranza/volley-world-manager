# Character creation — 04 club identity and 06 SIGNATURE

This focused addendum extends the settled `04 — CLUB` and `05 — MANAGEMENT` character-creation design. It records how founded-club visual identity should work, how existing-club identity differs, the two remaining open questions inside 04, and the final `06 — SIGNATURE` review/confirmation step. Fold it into `docs/design/CHARACTER_CREATION.md` on the next consolidation pass.

---

# 04F-5 — CLUB IDENTITY

`04F-5` should be understood as **club identity**, not merely club naming.

A founded club does not yet have an institutional identity, so this is the point where the player establishes its initial name and lightweight visual package. This belongs in CLUB because founding constitutes the institution. It does not belong in SIGNATURE, which should review the completed start rather than create another major gameplay-bearing choice.

## Name

Allow manual name entry plus regionally appropriate generated suggestions because HOME/WORK geography is already known.

The name is part of the institution, not the manager. Existing clubs keep their existing names.

## Generated visual package

After the club is named, generate a coherent lightweight identity package containing at minimum:

- primary colour;
- secondary colour;
- optional accent colour;
- crest;
- home kit;
- change/light kit.

Example presentation:

```text
VÅL NYR VC

PRIMARY       [colour]
SECONDARY     [colour]
ACCENT        [colour]

CREST         [generated crest]
HOME          [generated kit]
CHANGE        [generated kit]

[ Reroll identity ]
[ Customize ]
```

`Reroll identity` should regenerate the package coherently rather than rerolling unrelated components independently.

Do not make region deterministically assign club colours. Regional graphic traditions may exert a light influence where useful, but clubs need substantial independent visual identities. A region should not collapse into one colour palette or one crest family.

## Bounded customization

If the player chooses `Customize`, use a bounded editor rather than either extreme of accepting one random package or providing an unrestricted image editor.

Potential editable components:

### Colours

- primary;
- secondary;
- accent.

### Crest

- overall shape;
- central mark/symbol;
- division/pattern;
- border treatment;
- initials/name treatment where supported.

### Home kit

- base colour arrangement;
- trim/collar treatment;
- one major pattern family, such as plain, stripe, panel, band or sleeve treatment.

### Change kit

Use the same construction grammar while ensuring sufficient visual distinction from the home kit.

Shorts/socks or other garment elements should only become creation controls if they are visually meaningful in the actual match renderer.

The same identity parameters should drive every institutional appearance where practical: match kits, standings, office signage, competition UI, club pages and other club-facing surfaces. Avoid fake one-off creation art that is disconnected from the production renderer.

## Existing clubs

A manager taking an existing job inherits the institution's:

- name;
- crest;
- colours;
- kits;
- history.

Do not offer a club redesign during character creation merely because the player becomes manager.

A later rebrand may be possible if the game eventually models legitimate institutional processes such as a new kit cycle, crest modernization, anniversary design, board-approved rebrand or ownership change. That is a separate in-game club-history system, not a manager entitlement.

## 04F-5 revised flow

```text
04F-5 — CLUB IDENTITY
Name the club
        ↓
Generate coherent visual package
        ↓
[ Reroll identity ] / [ Customize ]
        ↓
Confirm identity
```

The `04F-6 — Founding review` then shows this finished identity alongside the club's factual sporting, institutional, VOLI LIFE, squad, staff and volleyball information.

---

# OPEN QUESTIONS IN 04

The rest of 04 is structurally settled enough to proceed, but **two questions remain intentionally open and must stay marked as unresolved** rather than being silently filled in during implementation.

## OPEN 04-1 — What does founding backing actually come from?

The current founding setup uses `Bare start / Modest backing / Strong backing` as a resource magnitude control. That is not yet a complete institutional design.

The source of backing may matter. Possible sources include civic/government support, private backing, member ownership, manager capital or another institutional arrangement. Different sources may create different obligations, restrictions, expectations, persistence or risk.

The unresolved design problem is therefore not merely `how much money?`, but:

> **Who or what is backing the club, and what does that support require in return?**

Do not implement `Strong backing` as a strictly dominant free-money option before this is resolved.

## OPEN 04-2 — How deep should the crest/kit generation grammar be?

The structural direction is settled:

- founded clubs receive a coherent generated identity;
- the player may reroll it;
- bounded customization is allowed;
- existing clubs are inherited rather than redesigned;
- the same parameters should feed production-facing club visuals.

What is **not** yet settled is the exact visual grammar and implementation scope:

- number and shape of crest templates;
- symbol/mark families;
- pattern/division families;
- typography/initial treatment;
- kit pattern families;
- colour-contrast/accessibility rules;
- how much regional visual influence exists;
- whether shorts/socks or other components are exposed;
- how procedural generation avoids repetitive or implausible combinations.

This should be designed as a reusable club-identity system rather than improvised inside character creation.

These are the two explicit unresolved questions for 04 at this stage.

---

# 06 — SIGNATURE

`06 — SIGNATURE` should be the shortest character-creation section.

It should not introduce another tactical, biographical, institutional or managerial axis. By this point the player has already defined who they are, their volleyball, their place, their club route and their management tendencies.

The purpose of 06 is:

> **review, personalize lightly, confirm, enter the world.**

## 06A — Final identity check

Show the manager and institution together.

For a founder:

```text
IRA CARRANZA
Founder / Manager

HOME
Bompaçao

WORK
Spëddigh

CLUB
Vål Nyr VC

[ manager preview ]
[ crest ]
[ home kit ] [ change kit ]
```

For an existing-club start, use `Manager` rather than `Founder / Manager` and display the inherited club identity.

This is a review surface. Do not reopen club creation controls here except through explicit edit navigation.

## 06B — Starting profile

Condense the meaningful creation choices into factual labels.

Example:

```text
BACKGROUND
Former analyst
Known

VOLLEYBALL
Quick attacks
Target reception
Read the attack
Attack in transition
Use what's available
Combination offense

MANAGEMENT
Structure         Guided
Squad building    Specialist-leaning
Responsibility    Shared
```

Do not synthesize this into authored personality prose such as `A thoughtful, flexible tactician.` The world should report the selected facts rather than tell the player what those facts emotionally or strategically mean.

If the game later needs compact save-file or encyclopedia shorthand, derive it from explicit labels rather than an invented personality sentence.

## 06C — Edit shortcuts

Allow direct return to earlier sections without requiring the player to walk backward through every page:

```text
[ Edit YOU ]
[ Edit VOLLEYBALL ]
[ Edit PLACE ]
[ Edit CLUB ]
[ Edit MANAGEMENT ]
```

Edits that invalidate later choices must be handled explicitly. For example, changing WORK region may invalidate a selected vacancy or founding site. Do not preserve impossible downstream selections silently.

## 06D — Optional non-mechanical details

SIGNATURE may contain lightweight optional presentation details if useful, such as:

- save name;
- preferred short club name where applicable;
- manager signature/mark;
- club motto.

These should be optional and non-mechanical. Do not use them to create another hidden personality or reputation system.

## 06E — Start the career

This is the final irreversible confirmation before entering the live world.

A plain functional action such as **Start career** is acceptable. A conversational player-owned action such as **I'm ready to begin.** or **Let's get to work.** is also valid under the established UI-voice rule.

The important constraint is that this action confirms an already-complete start rather than asking one final philosophy question.

## 06 flow summary

```text
06 — SIGNATURE
        ↓
FINAL IDENTITY
manager + region + role + club identity
        ↓
STARTING PROFILE
background + volleyball + management
        ↓
OPTIONAL LIGHT PERSONALIZATION
non-mechanical only
        ↓
EDIT SHORTCUTS
return directly to earlier sections if needed
        ↓
FINAL CONFIRMATION
[ Start career ]
        ↓
LIVE WORLD
```

# Character-creation interaction rule

The complete creation flow should not force one universal widget type onto every decision.

Use the interaction appropriate to the information being chosen:

- distinct alternatives → cards;
- continuous tendencies → stepped controls;
- places → map/list navigation;
- existing institutions/opportunities → factual profiles;
- appearance → direct editor;
- finalization → review and confirmation.

Consistency should come from the game's visual language, factual voice and causal rules rather than making every section a three-option questionnaire.
