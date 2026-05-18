# Elemental Reaction Engine Addendum 2026-05

## Scope

This addendum records the latest landed changes after the initial
`ELEMENTAL_REACTION_ENGINE.md` draft, without modifying the older file's
legacy encoding-heavy body.

## Landed Changes

1. `Frozen`, `Shatter`, `Hyperbloom`, and `Burgeon` are now routed through
   the unified reaction entry in `functions/resolveReactionForHit.m`.
2. `functions/advanceEnemyStateTime.m` now returns `reactionPackets`, and
   those packets are consumed centrally by `resolveReactionForHit.m`.
3. Timed-reaction packets now preserve their own snapshots:
   - `ReactionBonus`
   - `ReactionCritRate`
   - `ReactionCritDMG`
   - `ReactionEMOverride`
   - `ReactionResShredOverride`
4. `functions/simulateSimpleCharacterDPS.m` now auto-loads local Lunaris
   attack metadata through `functions/loadLunarisAttackMetadata.m` and uses
   it to fill:
   - `ApplyGauge`
   - `ICDRule`
   - `ICDGroup`
   - `StrikeType`
5. The generic simulator now has standard action aliases so that common
   action keys such as `N1` to `N6`, `CA`, and `Plunge` can better match
   Lunaris attack names and damage params before falling back to defaults.
6. The generic simulator now supports explicit per-action overrides for:
   - `ApplyGauge`
   - `ICDRule`
   - `ICDGroup`
   - `StrikeType`
7. Legacy single-output call sites of `advanceEnemyStateTime` were updated
   to the new two-output signature so timed-reaction packets are no longer
   silently discarded.

## Characters Calibrated In This Round

The following characters were re-run after the unified reaction changes and
completed smoke/regression execution successfully:

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

## Precision Notes

The project is now past the "all elemental hits default to 1U" stage for a
meaningful subset of generic simulators, but precision is still mixed by
character and by action family.

Current practical status:

- Many skill and burst actions already resolve real Lunaris `gauge` and
  `icd_rule`.
- Several common normal/charged strings now resolve through generic aliases.
- Some actions still fall back to default `1U`, especially when the local
  Lunaris attack table does not expose a clean attack entry for the modeled
  action, or when the simulator compresses multiple in-game hits into one
  simplified action.

## Recommended Next Pass

1. Continue replacing remaining default `1U` actions with real
   per-character `ApplyGauge`.
2. Split more normal/charged/plunge strings into action-level ICD groups
   instead of relying only on the generic alias layer.
3. For already-regressed Dendro, Anemo, Vaporize, and Melt characters,
   continue per-character numeric calibration of:
   - hit counts
   - reaction ownership
   - timed reaction tick counts
   - aura order and aura consumption
