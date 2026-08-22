# 02 — Roster, Scouting, Recruitment, and Offers

Status: **VERIFIED CORE / SOME PRODUCT DIRECTIONS EVOLVING**

Recruitment joins three distinct layers:

```text
world player truth
→ scouting information available to manager
→ roster/offer decision
→ persistent transfer to managed team
```

Keeping those layers separate is what makes uncertainty and discovery possible.

## The world population is real career state

At career creation, VWM generates a persistent world population. The transfer pool is drawn from that population rather than being an unrelated reroll each time the market opens.

That means a recruit can have a continuous biography/region/ability profile before and after the player notices them.

The large world population lives in a sidecar save and is loaded lazily because ordinary journal/match screens do not need thousands of off-roster players.

## Transfer pool is a view, not the whole world

`CareerState.transfer_pool` / ID persistence represent the currently surfaced market subset.

Conceptually:

```text
world population
→ market/scouting availability rules
→ transfer pool
```

Do not treat “not in transfer_pool” as “does not exist.”

## Scouting confidence is information quality

Scouting should not modify the underlying player's true attributes to create uncertainty.

Instead:

```text
true VolleyballPlayer
+ scout quality / observation history
→ manager-facing estimate/range/confidence
```

`weeks_observed` exists on the player as part of the observation relationship/history, while career scouting marks persist the manager's notes/intent toward prospects.

The exact scouting model can evolve, but truth versus knowledge should remain separate.

## Staff matters

Career creation now assigns staff rather than leaving every club with an accidentally empty scouting staff. A club with no scout remains a valid state that should produce poor information rather than a crash or magical certainty.

Staff capability/familiarity belongs to the management-information layer; it should not alter the prospect's actual reception rating.

## Scouting marks are persistent manager intent

`CareerState.scouting_marks` stores what the manager has decided about a prospect—watch/sign/seen enough style states depending on the current UI/system vocabulary.

This belongs in career state because a note that vanishes when a screen closes is not a career decision.

## Recruitment offers

Offer data is represented separately (`RecruitOffer` and related systems/data). That is useful because:

```text
player
≠ offer
```

One prospect can receive different financial/role/contract terms without modifying their identity Resource.

An offer should carry the proposal; acceptance logic should compare that proposal to player/club/world factors.

## Signing changes ownership, not identity

When a player joins the managed club, the important transition is where that existing `VolleyballPlayer` belongs/is referenced.

Do not regenerate the player “as a roster player.”

Their:

- attributes;
- potential ceilings;
- biography/home region;
- body;
- observation history where semantically appropriate;

should remain the same person.

## Roster decision reaches match availability

Managed players become candidates for lineup/lock-in and training regimens. Selection determines who enters a match; the rally engine then consumes the same player Resources.

This gives a causal management chain:

```text
scout player
→ sign player
→ train/develop player
→ select player
→ player's real attributes/body/tendencies enter rally
```

## Reputation, ability and value are different

A prospect's reputation can affect market attention/value without being part of ability scoring.

Potential can affect long-term value without making the current player stronger.

Scouting confidence affects what the manager knows without changing either.

These distinctions are what make recruitment judgement possible.

## UI should expose uncertainty honestly

If a scout only knows a range, display a range/confidence rather than reading the true underlying ceiling and cosmetically blurring it.

If a player has not been observed, the UI can state that uncertainty directly.

Presentation must not become the hidden information model.

## Safe extension: a new scouting factor

Suppose staff familiarity with a region should improve scouting.

Do not increase prospects' true ratings.

Instead:

1. identify the scouting estimate/confidence calculation;
2. add region-familiarity information there;
3. keep true player data unchanged;
4. verify higher familiarity narrows/improves the manager's information monotonically;
5. save familiarity where its long-term owner already lives;
6. test the same prospect under controlled scout states.

## Reading exercise

Trace one transfer-pool player from:

```text
WorldPopulation generation
→ CareerManager transfer pool
→ scouting screen/report
→ scouting mark/offer
→ managed roster
→ lock-in candidate
```

At each step label whether you are looking at **truth**, **manager knowledge**, or **manager decision**.

## Source trail

- `scripts/managers/career_manager.gd`
- `scripts/systems/world_population.gd`
- scouting systems under `scripts/systems/`
- `scripts/data/recruit_offer.gd`
- `scripts/models/volleyball_player.gd`
- `scripts/models/career_state.gd`
- `docs/design/SCOUTING.md`
- `docs/design/RECRUITMENT_AND_THE_OFFER.md`
- `docs/design/PLAYER_STYLE_SCOUTING_AND_TRAITS.md`

Next: training—the main current system for turning long-term management intent into changed player/team capability.