# Development Addendum 2026-05

## Purpose

This addendum records the latest maintenance-relevant changes after the
original `DEVELOPMENT.md` draft, without rewriting the older file in place.

## Reaction Engine Maintenance Notes

For the current unified elemental-reaction architecture, read:

- [ELEMENTAL_REACTION_ENGINE_ADDENDUM_202605.md](./ELEMENTAL_REACTION_ENGINE_ADDENDUM_202605.md)

That addendum reflects the latest landed state for:

- unified reaction dispatch
- timed reaction packet handling
- Lunaris attack metadata loading
- action-level gauge / ICD overrides
- the latest regression-covered generic simulators

## Practical Maintenance Rules

1. If a character action can be mapped to a local Lunaris attack entry, do
   that first instead of hand-writing a new reaction branch.
2. Only use manual `ApplyGauge / ICDRule / ICDGroup / StrikeType` overrides
   when Lunaris metadata cannot express the modeled action cleanly.
3. Keep reaction judgment centralized in `functions/resolveReactionForHit.m`.
4. Keep timed / delayed reaction advancement centralized in
   `functions/advanceEnemyStateTime.m`.
5. When touching old custom simulators that still call
   `advanceEnemyStateTime`, make sure they use the current two-output
   signature.

## Regression Habit

After changing generic reaction behavior, re-run at least a focused smoke
batch over:

- Dendro reaction characters
- Anemo swirl characters
- Vaporize / Melt characters

The current reference batch used in this round is based on:

- `Barbara`
- `Gaming`
- `Kaeya`
- `Nahida`
- `Freminet`
- `Jean`
- `Xiangling`
- `Kaveh`
- `Alhaitham`
- `Wanderer`
- `ShikanoinHeizou`
- `KamisatoAyato`
- `Hutao`
- `Diluc`
- `Tighnari`
- `Venti`
- `Wriothesley`
