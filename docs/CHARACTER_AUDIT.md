# Character Audit

## Overview

This document tracks the current simulator roster status after auditing the
`functions`, `analysis`, `data`, and local Lunaris metadata files.

The project currently has a stable unified chain:

- Single-character entry: `functions/simulateCharacterDPS.m`
- Team entry: `functions/simulateTeamDPS.m`
- Team context builder: `functions/buildTeamContext.m`
- GUI registry source: `functions/app/getCharacterRegistry.m`

## Current Status

The previously flagged import batch is already fully wired into the unified
dispatcher, default-config registry, analysis entry set, and GUI registry:

- `Sethos`
- `Ororon`
- `Ifa`
- `Dahlia`
- `Aino`
- `Jahoda`
- `Illuga`
- `Varka`
- `LanYan`

Audit against the current local roster shows that all imported character
folders under `data/` now have matching:

- `functions/<Character>/simulate<Character>DPS.m`
- `functions/<Character>/customArtifact_<Character>.m`
- `analysis/main<Character>Full.m`
- unified dispatch wiring in `simulateCharacterDPS.m`
- default-config wiring in `getDefaultCharacterConfig.m`

## Remaining Structural Gaps

- No remaining missing character-folder or unified-entry gaps were found in
  the current local roster audit.
- `Furina` previously used legacy localized data filenames. Canonical
  `characters_Furina.csv` and `talents_Furina.csv` are now expected to
  coexist with the older exports for compatibility.

## Remaining Work

- Continue second-pass precision calibration for simple-wrapper characters,
  prioritizing `Sethos`, `Ororon`, and the rest of the recently imported
  batch.
- Continue real `ApplyGauge` / `ICD` / reaction-regression validation after
  per-character refinements.
- Continue team-timeline and off-field trigger convergence against the
  unified simulator path.

## Notes

- `Lan Yan` uses project key `LanYan` but local avatar metadata key
  `Lanyan`, so registry/GUI code must preserve the alias mapping.
- `Ororon` currently maps to avatar key `Olorun` in local Lunaris metadata.
- Local Lunaris metadata is now sufficient for base roster registration,
  portrait/icon lookup, weapon/element typing, and most attack metadata
  lookups used by the unified simulator.
