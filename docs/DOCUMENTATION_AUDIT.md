# Documentation Consistency Audit

Scope: high-value design/implementation authority around volleyball intelligence, scouting, training, traits, signatures, planning and current backlog. This is a conservative audit: it records contradictions/staleness rather than rewriting historical reasoning that documents intentionally preserve.

Post-integration status (2026-08-25): canonical M9 is integrated and certifies
39/39 selectable tactical families. The management-intelligence census was
rechecked against those seams; no management-intelligence implementation was
added. The real Match View presentation integration changes appearance and
framing only. It does not implement the Play Designer or the tiered signature
vocabulary.

## Findings

### 1. Historical implementation prose is easy to mistake for current state

**Severity: high.**

Several design records intentionally preserve the argument that motivated later work.

Examples:

- `SETTER_DECISION.md` now says shared option decision is live, while retaining the old premise that nobody chooses who attacks.
- `SCOUTING.md` contains an older "beliefs have no owner" gap, while `docs/BACKLOG.md` later records beliefs-with-owner as closed.

Action: `docs/DESIGN_AUTHORITY_INDEX.md` now records the precedence rule: explicit status headers and later closure records outrank preserved historical paragraphs.

### 2. `familiarity` is overloaded terminology

**Severity: high.**

At least four distinct quantities/concepts use familiarity-like language:

- position familiarity;
- general pair familiarity;
- situation familiarity/read from exposure;
- designed tactical comfort/learned preference.

They have different owners and clocks. New architecture prose should qualify the noun every time.

### 3. `Focus` is now overloaded

**Severity: medium.**

`TACTICS_AND_TRAINING.md` uses focus for attribute-training allocation. `SIGNATURE_VOCABULARY.md` uses Focus for a Tier-1 match state.

This is not necessarily a player-facing conflict because the contexts differ, but implementation identifiers should be explicit (`training_focus` vs signature/state Focus). Do not create a generic `focus` field shared by both.

### 4. Pair familiarity is not the designed tempo relationship

**Severity: high.**

`PairFamiliarity` is live and general. `TACTICS_AND_TRAINING.md` specifically says tempo comfort belongs to a hitter–setter pair. Treating the existing general number as the full tempo model would silently collapse two facts.

### 5. System-fit and learned preference remain unresolved in implementation

**Severity: high.**

The design is clear that rating-derived bands should be layered with learned offsets. The learned layer is not yet live. Any UI that describes current system familiarity must distinguish natural fit from trained comfort.

### 6. Signature terminology changed materially

**Severity: high.**

The new signature design distinguishes capability, vocabulary and manifestation, and introduces tiers. Older code/presentation language such as `surge` predates this model. Do not infer design semantics from implementation names.

### 7. Traits, signatures and style can easily become duplicate truth

**Severity: high.**

The corpus already has the correct separation, but future implementation is at risk:

- trait = behavioral pull/unusual persistent fact;
- signature vocabulary = unusual solution possessed;
- style = derived description;
- attribute = competence.

A census is required before migrating old rare traits into signature vocabulary.

### 8. Match adaptation and recruitment scouting both use "scouting" language

**Severity: medium.**

Recruitment scouting is staff-mediated belief uncertainty. Match adaptation is athlete exposure/read. They should not share one confidence store or freshness model.

### 9. The Play Designer depends on state that does not yet exist

**Severity: high.**

The new interface is compatible with the existing design only if it compiles into learned-preference asks. Building the drawing surface before that substrate would create presentation-owned tactical truth.

### 10. Backlog status is useful but branch-relative

**Severity: medium.**

`docs/BACKLOG.md` explicitly names an older measured commit and says items are not in `main`. On long-lived feature branches, some entries can already be closed. Treat backlog statements as dated status evidence, not timeless truth. Reconcile after milestone merges.

## Conservative corrections made by this audit

Rather than rewriting source design records, this pass added:

- `docs/DESIGN_AUTHORITY_INDEX.md` — ownership and terminology;
- `docs/implementation/management_intelligence_census/` — current design-to-code map;
- `docs/implementation/TRAINING_PLAY_DESIGNER_SEAMS.md` — dependency map;
- `docs/implementation/SIGNATURE_VOCABULARY_RECONCILIATION.md` — old/new signature semantic bridge.

## Deferred cleanup

Do not mass-edit the large historical design files solely for wording consistency. Their preserved reasoning is useful. A later documentation maintenance pass can add compact status banners/cross-links once M9 is integrated and the target branch is stable.

M9's integration satisfies the first condition, so focused banners/cross-links
have now been added to the affected implementation packets. A mass historical
rewrite remains deferred.
