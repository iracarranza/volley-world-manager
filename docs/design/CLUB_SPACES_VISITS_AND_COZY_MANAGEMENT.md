# Club spaces, visits, information, transfers, and cozy management

Design record for the discussion beginning with parameterized regional office appearance and continuing through facility visits, information access, club/academy career structure implications, free agency, manager-to-manager interaction, and the cozy-game identity of VWM.

This document is intentionally comprehensive. It records not just the headline conclusions but the reasoning, distinctions, examples, and constraints that should govern later implementation.

## 1. Regional office appearance should vary inside a regional grammar

The 14-region office material matrix remains the canonical visual language. An office should not be one immutable preset per region, but neither should club-to-club variation dissolve into generic procedural randomness.

The intended structure is:

```text
regional architecture/material grammar
        +
club resources
        +
club character
        +
building age
        +
current condition
        +
occupant / institutional history
        ↓
individual office appearance
```

Each region therefore defines bounded parameter ranges rather than one exact look. Useful common dimensions include:

- value: light ↔ dark, without abandoning the regional hue/material family;
- saturation: muted ↔ rich;
- pattern strength: nearly invisible ↔ pronounced, without changing pattern type;
- pattern scale: fine ↔ broad;
- wear: new ↔ aged/repaired;
- finish: rough/matte ↔ smooth/polished.

Material-specific parameters can add variation where appropriate:

- timber: grain strength, plank width, board irregularity;
- stone: joint prominence, slab size/variation;
- plaster: mottling, patching, scoring visibility.

The crucial constraint is that **regions do not share identical slider ranges**. A'ace can vary, but even its roughest office should still read as manufactured, immaculate, and maintained. Ĭspayk can vary, but even its most cared-for office should still show age, repair, and material history rather than drifting toward A'ace.

This allows offices to differ in degree while preserving difference in kind.

### Wealth and prestige should not be the same visual variable

The system should make it possible for:

- an old prestigious club to have worn floors, expensive old furniture, and visible history;
- a newly rich club to have pristine but relatively generic replacements;
- a struggling club to preserve one beautiful inherited desk while cheaper repairs accumulate around it;
- a promoted club to retain an old building while conspicuously replacing a few pieces.

This makes physical spaces useful evidence about institutional history rather than a simple "facilities level" skin.

### Spaces can remember change

Promotion, financial crisis, new ownership, repairs, changing staff, and long-term wear can alter a space over time. Some objects should persist through those changes so the office does not visually reset every time a club improves or declines.

The broader principle is that the regional matrix supplies the language; each club becomes a different sentence written with it.

## 2. Leaving the office should matter, but the office remains the home interface

The player's office should remain the fastest place for ordinary management:

- correspondence;
- staff and squad planning;
- reports;
- scouting summaries;
- medical summaries;
- finances;
- match preparation;
- board/admin work;
- general club oversight.

Other locations should exist because **presence changes the quality and context of information**, not because menus are arbitrarily disabled at the desk.

Possible destinations include:

- training court;
- medical bay;
- staff rooms;
- player accommodation/common areas where appropriate;
- another club's office or training facility;
- arena or hosted competition venue;
- regional/federation/academy spaces.

Travel should usually be an intentional scene transition rather than literal corridor/car/walking simulation. The destination and the time spent there are the gameplay.

## 3. Information should have geography

A useful governing idea is:

> Information exists where it is produced, then travels toward the manager imperfectly and with delay.

The office is where information is aggregated. The training court, medical bay, another club, or arena is where some of that information is directly produced or observed.

A report should remain actionable. For example:

```text
Mara Venn — ankle issue
Status: doubtful
Estimated return: 1–2 weeks
Report received: yesterday
```

Visiting the medical bay does not unlock a hidden exact injury percentage. Instead it may reveal fresher or more contextual evidence:

- swelling has decreased since morning;
- the voli can now bear weight comfortably;
- tomorrow's jumping test is the decisive uncertainty;
- the voli feels more confident than the medical staff does;
- the specialist is worried about match load even if ordinary training is possible.

### Information quality has multiple dimensions

Information should be understood through at least:

```text
accuracy × completeness × freshness
```

A physio report may be highly accurate and complete but 36 hours old. A scout report may be medium-confidence, incomplete, and two days old. A manager's firsthand observation can be immediate but narrow and subjective.

That prevents "being there" from becoming omniscience. Specialists can remain more accurate than the player-manager in their own domains even when the manager is physically present.

### Staff quality is information infrastructure

A great physio, scout, analyst, assistant, or player-care staff member is valuable not only because they modify outcomes, but because they communicate well:

- reports arrive promptly;
- confidence and uncertainty are expressed appropriately;
- important distinctions are surfaced;
- noise is filtered;
- follow-up is requested when needed.

For example, a mediocre report might say:

> Expected availability: 5–12 days.

A stronger one might say:

> Likely available for modified training Thursday. Full jumping load remains uncertain; reassess Wednesday morning.

Good staff therefore reduce the need for the manager to personally inspect everything.

### Some things should be learnable mainly by being there

Training reports can summarize intensity, form, morale, and unit performance, but firsthand attendance may expose contextual evidence such as:

- an outside repeatedly yielding seam balls to the libero;
- a setter and opposite staying after a drill to work on timing;
- a middle visibly fading between repetitions;
- a reserve disengaging from the group;
- natural communication emerging between players despite modest formal familiarity;
- a coach repeatedly stopping one specific drill;
- a tactical pattern looking smoother than its score/statistical result implies.

These should be observations and events rather than mandatory hidden-stat reveals.

## 4. Managerial time should represent attention, not action-point optimization

A real danger is turning the game into:

```text
You have 6 hours.
Medical bay   -1
Training      -2
Scout match   -3
Visit club    -4
Missed action = lost reward
```

That would encourage optimization anxiety rather than a cozy managerial rhythm.

The intended constraint is simpler:

> You cannot personally be everywhere.

The office gives breadth. Presence gives depth.

The player should be deciding what deserves personal attention this week, not trying to harvest every available bonus before the calendar advances.

### Delegation must be safe normal play

Trusting a good physio to manage an ordinary injury, an analyst to summarize an opponent, or an assistant to supervise routine training should usually be fully viable.

Personal attendance should make sense when:

- the situation is unusually important;
- reports conflict;
- uncertainty is high;
- the manager is curious;
- a relationship matters;
- firsthand context is valuable.

Doing nothing personally should often be the correct decision.

### Most opportunities should persist or recur

Missing one ordinary training session or failing to visit another manager this week should not permanently close a superior path. Rare one-off moments can exist, but they should feel exceptional rather than being the default structure of the calendar.

Information differences should usually be gradients, not gates. The manager who stays home knows less firsthand; they should not suddenly become incapable of making competent decisions.

## 5. Club and academy are fundamentally different institutions

The settled structure is:

> **Club employs. Academy selects. Home region remains formative identity.**

A voli is always from a home region. That identity governs formative inheritance and representative eligibility and does not change when the voli transfers clubs.

A club is the everyday institution. It:

- recruits;
- employs;
- houses;
- feeds;
- trains;
- cares for;
- manages workload and daily life;
- competes week to week.

The academy is **not a youth setup**. It is a government-funded regional representative body that gathers the strongest eligible volis and prepares a squad for the Sixnet.

This means the existing use of "academy" in some older UI/encyclopedia material is semantically dangerous. Any legacy language implying "academy = young development club" needs a dedicated overhaul rather than piecemeal patches.

### Club competition is the proving ground for academy selection

Academy selection should not simply sort players by ability or conformity to regional ideals. Club volleyball supplies evidence:

- minutes;
- role;
- actual performance;
- opponent quality;
- consistency;
- specialist success;
- evidence that a particular contribution holds up in real matches.

A voli can build a representative case by becoming a near-perfect expression of the regional system or by proving that an unusual/specialist role solves a problem the canonical system does not solve as well.

No protected wildcard route is required. Unusual volis still have to prove that their difference produces representative value.

Academy selection is roster construction, not a leaderboard. Marginal squad value matters: a second-best duplicate may be less useful than a slightly weaker player who adds a distinct late-set, serving, blocking, defensive, or setting solution.

## 6. Free agents should exist

Club employment should be normal but not universal. Requiring every voli to be continuously contracted would make every signing a club-to-club transaction and remove an important career state.

Useful clubless states include:

- never-signed prospect;
- released voli;
- contract-expired voli;
- mutually separated voli;
- temporarily clubless established player.

Clublessness should not be an arbitrary punishment modifier. It already carries natural consequences in this world because clubs provide much more than wages:

- housing;
- food;
- care;
- high-level training;
- match exposure;
- performance evidence relevant to academy selection.

A clubless voli may return home, train independently, live in less ideal conditions, or become increasingly open to imperfect opportunities because remaining unsigned has real opportunity costs.

Most careers should still spend most of their time attached to clubs. Free agency is a meaningful transition state, not the default annual market.

## 7. Contracted transfers are three-party interactions

A free-agent signing and a contracted transfer should feel structurally different.

### Free agent

```text
recruiting manager / club
        ↓
voli
        ↓
Does this role, life, club, and environment appeal?
        ↓
agreement
```

### Contracted voli

```text
recruiting manager
      ↕
current manager / club
      ↕
voli
```

A contracted move therefore requires two successful negotiations:

1. the current club must be willing to release the voli on acceptable terms;
2. the voli must actually want to join the new club.

### The current manager should have reasons, not just a price

The other manager's willingness to discuss a move can depend on:

- squad importance;
- depth at the position;
- replacement difficulty;
- whether a replacement has already been identified;
- competitive relationship with the buyer;
- finances;
- contract status;
- relationship with the voli;
- current role/minutes;
- manager-to-manager trust.

Responses should expose roster logic where possible rather than becoming a pure bidding minigame.

Examples:

> Not available — only recognised setter behind the starter.

> Open to release — limited role this season; replacement identified.

> Would consider exchange — seeking middle-blocking depth.

That turns another club's roster into information worth understanding.

### The voli can disagree with both clubs

Possible situations include:

```text
You want the voli.
Current manager is happy to sell.
Voli dislikes the destination's role/lifestyle.
→ no move.
```

```text
You want the voli.
Voli strongly wants the move.
Current manager refuses.
→ tension may arise at the current club.
```

```text
Another club wants your reserve.
You would prefer to keep them.
The voli wants to leave for minutes/life fit.
→ retention becomes a real relationship problem.
```

Accommodation and club-life preferences make this much richer than salary alone.

## 8. Visiting other clubs should have many purposes beyond transfers

A club visit should be a **general information, relationship, and institutional-access action**. Transfer negotiations are only one possible downstream consequence.

### Observe training

A visit can reveal how another club actually operates:

- training intensity;
- drill structure;
- positional priorities;
- communication style;
- unusual tactical habits;
- who is trusted;
- who is being retrained;
- how abstract regional principles are taught in practice.

This provides causes behind outputs that a scout report may only summarize.

### Learn another manager

Repeated contact can make another manager's habits more legible:

- rotation tendency;
- appetite for youth/unknown players;
- treatment of stars and reserves;
- workload philosophy;
- tactical flexibility;
- tolerance for specialists;
- interpersonal style.

This should not collapse into one relationship score. Knowing someone better means their choices become more understandable and sometimes more predictable.

### Build professional relationships

Visits and ordinary professional contact can improve trust with:

- managers;
- assistants;
- analysts;
- physios;
- executives;
- coaches.

That trust can later support:

- more candid information;
- cooperation;
- friendlies;
- joint events;
- staff exchanges;
- transfer conversations;
- first calls when circumstances change.

Relationships should matter partly because they affect access, not because friendship simply grants a universal bonus.

### Arrange joint activity

Possible cooperative uses include:

- scrimmages;
- preseason camps;
- shared specialist sessions;
- coaching exchanges;
- analysis exchanges;
- medical/conditioning collaboration where appropriate;
- community or cultural events;
- invitational events.

### Scout institutions, not only players

A manager may want to understand whether another club is well run:

- accommodation quality;
- medical practice;
- player morale;
- staff organization;
- facility condition;
- training culture;
- relationship between executive investment and player care.

The physical environment itself can become evidence: lavish offices beside poor player facilities, overcrowded medical rooms, ancient but beautifully maintained halls, or modest academies bursting with activity.

### Learn regional volleyball firsthand

Visiting clubs in another region can reveal how its philosophy is reproduced through coaching and daily work, rather than reducing regional identity to match statistics or encyclopedia prose.

### Informal information can emerge socially

A visit may surface partial evidence about:

- staff departures;
- dissatisfaction;
- impending role changes;
- tactical shifts;
- facility problems;
- contract situations;
- internal priorities.

This information should remain social and incomplete rather than becoming omniscient espionage.

### Access should be asymmetric

Not every club should let the player see everything. Access can depend on:

- relationship;
- reputation;
- rivalry;
- timing;
- competitive context;
- stated purpose of visit.

A first visit might allow only:

```text
office meeting
public training
basic facility tour
```

A trusted relationship might later allow:

```text
closed training
staff conversation
specialist exchange
informal dinner
more candid institutional discussion
```

A rival immediately before an important match may refuse access entirely.

Thus **trust partly means access**.

## 9. Visits and relationships can drive knowledge diffusion

Clubs and regions should not exist as isolated tactical islands forever.

Ideas can move through:

- observation;
- staff movement;
- collaboration;
- scrimmages;
- repeated competition;
- manager relationships.

For example:

```text
Spëddigh club develops an unusual receive structure
        ↓
you visit / scrimmage / hire an assistant from there
        ↓
your staff learn parts of it
        ↓
you adapt it to your own regional context
        ↓
another club later copies your variation
```

This allows the world's volleyball culture to evolve while preserving underlying regional traditions.

## 10. Cozy identity must constrain the management design

The major risk in combining visits, information, recruitment, relationships, training, facilities, and a finite calendar is transforming VWM into stressful optimization work.

The difference between a rich cozy game and a task list is whether the player feels that **not doing something equals failure**.

VWM should therefore not imply that the player must:

- visit every club;
- attend every training session;
- inspect every injury personally;
- chase every possible signing;
- maximize every hour;
- win every competition to validate the save.

### The central fantasy should be broader than "be the best club"

A stronger framing is:

> **Build a volleyball place you care about, and see what becomes of the people and culture around it.**

Winning remains important and can be one major form of success, but it is not the only legitimate long-term objective.

Possible parallel aspirations include:

| Dimension | Possible long-term aspiration |
|---|---|
| Sporting | win competitions; develop a distinctive tactical identity |
| People | mentor careers; keep a beloved long-term squad; rescue overlooked volis |
| Club culture | create a particular way of living and training together |
| Facilities | improve and personalize the physical club |
| Relationships | build meaningful links with managers, staff, volis, and institutions |
| Regional | contribute players or ideas to the home region / Sixnet |
| Legacy | become known for a particular player type, tactic, care standard, or philosophy |
| History / collection | accumulate trophies, photos, shirts, gifts, records, and memorabilia |

"Best" is therefore plural.

### Players should be allowed not to care about some systems

A manager should be able to decide, explicitly or implicitly, that some areas are not personally interesting.

A lightweight priorities concept could let staff surface information in the domains the player values most while competently handling routine matters elsewhere. For example:

```text
Player wellbeing
Tactical experimentation
Aggressive recruitment
Club relationships
Development of overlooked volis
Commercial growth
```

This need not become a set of stat bonuses. Its main purpose is to keep the simulation broad underneath while presenting a smaller, more personal game to each player.

## 11. Slow noncompetitive accumulation should matter

Stardew-like coziness does not come from the absence of money or goals; it comes partly from having many enduring goals that are not all competitive optimization.

VWM equivalents can include:

- office personalization;
- persistent furniture and wear;
- framed lineups;
- signed balls;
- shirts from important matches;
- gifts from retiring volis or other managers;
- regional objects collected through travel;
- club photographs;
- tactical boards from memorable seasons;
- retired numbers;
- club records;
- facility decoration and improvement.

The club should gradually become visibly **your place**.

Relationships can similarly be rewards in themselves. A visit that ends with watching training and having dinner with another manager does not always need to produce `+7 Negotiation` or another explicit resource.

## 12. VWM does not need one final victory condition

Sixnet victory can be a major achievement without being the end-state or universal purpose of the save.

A club history can accumulate many different kinds of meaning:

```text
27 seasons
4 club championships
1 Sixnet-winning academy representative developed here
18 academy selections
6 one-club volis
3 managers who began as your assistants
known for defensive opposites
known for unusually low player turnover
known for excellent food
closest institutional relationship: Rhėn Tempaol North
longest-serving voli: Lía, 14 seasons
```

None of those needs to collapse into a final score.

A defeat, lost signing, departure, or failed qualification should be able to become part of the club's story rather than proof that the player handled the calendar incorrectly.

The underlying cozy rule is:

> **The player is not trying to consume every opportunity. They are choosing what kind of club life to cultivate.**

And for the time/location system specifically:

> **Presence creates texture, not mandatory efficiency.**

Going somewhere should offer a different experience — more personal, immediate, contextual, relational — rather than always being strictly superior to staying in the office.

## 13. Backlog: academy terminology and encyclopedia overhaul

The settled academy meaning conflicts with older language that treated academy as a youth-development starting route.

A dedicated overhaul should eventually:

- define academy early and explicitly as the regional elite representative institution;
- remove or rewrite legacy encyclopedia text that implies club youth-academy semantics;
- update career-start explanations;
- update region entries, especially major/minor distinctions;
- align UI labels, club/academy terminology, and Sixnet explanations;
- make clear that clubs develop/provide everyday careers while academies select representatives from proven eligible volis.

This should be treated as one terminology/world-model pass rather than scattered wording fixes.

## Summary design rules

1. Regional spaces vary within bounded material grammars rather than becoming palette swaps or procedural noise.
2. The office is the broad management hub; locations provide depth and context.
3. Information has accuracy, completeness, freshness, provenance, and geography.
4. Personal attendance provides context, not omniscience.
5. Staff quality should make delegation genuinely trustworthy.
6. Managerial time is attention, not an action-point economy.
7. Most opportunities recur; missing routine activity should rarely be permanent failure.
8. Club employs; academy selects; home region remains formative identity.
9. Free agents exist; contracted transfers require both club-to-club and club-to-voli agreement.
10. Other managers have roster and institutional motives, not merely asking prices.
11. Club visits serve observation, learning, relationships, cooperation, institutional scouting, and knowledge diffusion as well as recruitment.
12. Trust partly manifests as access.
13. Cozy is a mechanical constraint: optionality must not become mandatory optimization.
14. Success is plural and historical rather than one final leaderboard condition.
15. Presence creates texture, not mandatory efficiency.
