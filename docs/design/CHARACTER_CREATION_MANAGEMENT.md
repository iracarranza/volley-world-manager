# Character creation — 05 MANAGEMENT

This is a focused addendum to `docs/design/CHARACTER_CREATION.md` and the broader character-creation addenda. It records the settled direction for `05 — MANAGEMENT` and the interaction grammar it introduces. Fold it into the main character-creation spec on the next consolidation pass.

# Purpose

`05 — MANAGEMENT` should answer a different question from VOLLEYBALL and CLUB:

> **How do you want to manage?**

It does not define tactics, biography, club resources, or a permanent personality class. It defines three starting management tendencies that may seed defaults and expectations, while later behavior remains authoritative.

The section should stay compact: three dimensions only. Richness should come from the precision of the controls and their downstream consequences, not from long explanatory prose or nested questionnaires.

# Interaction grammar

Do not force the three-card questionnaire pattern onto every creation step merely for visual consistency.

Use controls that match the kind of thing being chosen:

- **Distinct alternatives** → cards.
- **Continuous tendencies** → stepped controls.
- **Places** → map/list navigation.
- **Existing institutions/opportunities** → factual profiles.
- **Appearance** → direct editor.

`02 — VOLLEYBALL` remains especially suited to three distinct answer cards because its options are different tactical decisions, not points on one continuum.

`05 — MANAGEMENT` is different. Its three dimensions are continuous tendencies, so each should use a five-position stepped control rather than three categorical cards or branching submenus.

The five positions do not need five authored archetypes. Internally they may simply represent values such as `0 / .25 / .5 / .75 / 1`. The UI should name the two endpoints and the midpoint; intermediate steps mean `leans toward` rather than creating separate manager classes.

This gives meaningful granularity without combinatorial branching.

# 05A — Structure and autonomy

Question:

> **How much structure do you give your volis?**

Control:

```text
Defined roles
●────●────●────●────●
                  Player-led decisions

            Guided freedom
```

Meaning:

- **Defined roles** — stronger expectation that players follow assigned responsibilities and established solutions.
- **Guided freedom** — a clear framework with room for situational interpretation.
- **Player-led decisions** — greater expectation that volis use their own judgment within the team's overall approach.

This is where tactical freedom/player autonomy belongs. It should not be folded back into the six VOLLEYBALL questions.

Possible downstream systems include role interpretation, coaching language, development expectations, player reactions to repeated overrides, and how much situational discretion the team is normally given. These effects should be concrete and revisable rather than hidden global bonuses.

# 05B — Squad construction

Question:

> **What kind of squad do you want to build?**

Control:

```text
Specialists
●────●────●────●────●
                  Versatile players

            Role flexibility
```

Meaning:

- **Specialists** — greater preference for players with clearly defined, role-specific strengths.
- **Role flexibility** — preference for useful adjacent-role coverage without requiring broad utility from everyone.
- **Versatile players** — greater preference for broad role coverage and adaptability.

This is the correct home for the specialists-versatility dimension that was removed from VOLLEYBALL.

Possible downstream systems include recruitment recommendations, scouting filters, retraining suggestions, bench construction, substitution options, contract valuation, and how the club's roster identity develops over time.

Again, this is a preference, not a stat modifier and not an immutable club archetype.

# 05C — Responsibility and delegation

Question:

> **How much do you keep in your own hands?**

Control:

```text
Manager-led
●────●────●────●────●
                  Delegated

        Shared responsibility
```

Meaning:

- **Manager-led** — the manager retains more day-to-day sporting and institutional decisions; staff primarily advise.
- **Shared responsibility** — manager and staff divide responsibility more evenly.
- **Delegated** — department leads and trusted staff are expected to own more operational work.

This dimension should seed the later responsibilities system, not replace it.

# Responsibilities belong in-game

The expanded responsibilities menu should appear only after the player has actually taken a job or founded the club.

Character creation defines **preference**. The live club screen defines **assignment**.

This distinction matters because responsibility depends on the institution that actually exists. A manager cannot meaningfully delegate medical decisions to a medical department that does not exist, and a Bare-start founding route may legitimately force a delegation-minded manager to retain more tasks at first.

The in-game responsibilities system may include granular assignments such as:

- training schedule;
- individual development;
- recruitment shortlists;
- scouting assignments;
- contract discussions;
- staff hiring;
- medical return-to-play;
- housing/accommodation issues;
- food and player-support operations;
- media;
- scheduling/travel;
- academy liaison and other institutional responsibilities where modeled.

Example live configuration:

```text
RESPONSIBILITIES

Training schedule          Manager
Individual development     Assistant coach
Recruitment shortlists     Scout
Contract discussions       Manager
Medical return-to-play     Medical staff
Accommodation issues       Operations
Media                      Manager
```

The 05C value may preconfigure these defaults where valid:

- Manager-led starts with more manager-owned responsibilities.
- Shared starts with a mixed distribution.
- Delegated starts with more responsibility assigned to competent existing staff.

The player may change the assignments immediately. Do not make the creation choice a permanent restriction.

General rule:

> **05 defines preference. The club screen defines assignment.**

# Behavior outweighs declaration

All three MANAGEMENT choices establish starting tendencies, defaults, recommendations and perhaps early expectations. They must not become permanent personality tags that override play.

A manager who selects Player-led decisions but repeatedly intervenes should eventually be understood through those interventions. A manager who selects Delegated but personally takes back every responsibility should not remain permanently classified by the creation choice.

Likewise, a player who initially prefers Specialists can later build a highly versatile squad.

The world should respond to what the manager actually does over time.

# Presentation

Unlike VOLLEYBALL, MANAGEMENT does not require three rendered tactical demonstrations for every choice. These dimensions are institutional/managerial rather than single-rally decisions.

The section can present all three tendencies in a compact, deliberate layout or give each one its own page if pacing benefits from it. Either way, keep explanatory text short and concrete.

Example summary:

```text
05 — MANAGEMENT

HOW DO YOU WANT TO MANAGE?

Structure
Defined ───────── Guided ───────── Player-led
                       ●

Squad building
Specialists ───── Flexible ───── Versatile
              ●

Responsibility
Manager-led ───── Shared ───── Delegated
                              ●
```

A suitable player-owned confirmation is:

> **Yup, that's how I'll manage.**

# Settled scope

The section is considered structurally settled at three dimensions:

1. structure ↔ player autonomy;
2. specialists ↔ versatility;
3. manager-led ↔ delegated responsibility.

The exact implementation effects, intermediate numeric values, and downstream thresholds can be tuned later without reopening the creation-flow structure.
