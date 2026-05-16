# Character Audit

## Overview

This document tracks the current simulator roster status after auditing the
`functions`, `analysis`, `data`, and local Lunaris metadata files.

The project currently has a stable unified chain:

- Single-character entry: `functions/simulateCharacterDPS.m`
- Team entry: `functions/simulateTeamDPS.m`
- Team context builder: `functions/buildTeamContext.m`
- GUI registry source: `functions/app/getCharacterRegistry.m`

## Implemented Characters

The following characters currently have simulator folders, data folders, and
are already wired into the unified dispatcher/default-config chain:

- `Arlecchino`
- `Chasca`
- `Chevreuse`
- `Chiori`
- `Clorinde`
- `Citlali`
- `Columbina`
- `Durin`
- `Emilie`
- `Escoffier`
- `Flins`
- `Furina`
- `Gaming`
- `Iansan`
- `Ineffa`
- `Kachina`
- `Kinich`
- `Lauma`
- `Linnea`
- `Mavuika`
- `Mualani`
- `Navia`
- `Nefer`
- `Neuvillette`
- `Nicole`
- `Nilou`
- `Sigewinne`
- `Skirk`
- `Varesa`
- `Xianyun`
- `Xilonen`
- `Zibai`

## Not Yet Implemented

These characters already exist in the local avatar metadata, but do not yet
have full simulator folders plus unified entry wiring:

| Character | Project Key | Weapon | Element | Avatar Key | Lunaris Id |
| --- | --- | --- | --- | --- | --- |
| Sethos | `Sethos` | Bow | Electro | `Sethos` | `10000097` |
| Ororon | `Ororon` | Bow | Electro | `Olorun` | `10000105` |
| Ifa | `Ifa` | Catalyst | Anemo | `Ifa` | `10000113` |
| Dahlia | `Dahlia` | Sword | Hydro | `Dahlia` | `10000115` |
| Aino | `Aino` | Claymore | Hydro | `Aino` | `10000121` |
| Jahoda | `Jahoda` | Bow | Anemo | `Jahoda` | `10000124` |
| Illuga | `Illuga` | Pole | Geo | `Illuga` | `10000127` |
| Varka | `Varka` | Claymore | Anemo | `Varka` | `10000128` |
| Lan Yan | `LanYan` | Catalyst | Anemo | `Lanyan` | local alias |

## Current Gaps

For the not-yet-implemented list above, the project is still missing some or
all of the following:

- `functions/<Character>/simulate<Character>DPS.m`
- `functions/<Character>/customArtifact_<Character>.m`
- `data/<Character>/characters_<Character>.csv`
- `data/<Character>/talents_<Character>.csv`
- `data/<Character>/rotation_<Character>.txt`
- `analysis/main<Character>Full.m`
- `functions/getDefaultCharacterConfig.m` case
- `functions/simulateCharacterDPS.m` dispatch case

## Recommended Import Order

To reduce risk and keep team/GUI integration stable, the next import batches
should follow the order below:

1. `Sethos`, `Ororon`, `Ifa`, `Dahlia`
2. `Aino`, `Jahoda`, `Illuga`, `Varka`, `LanYan`

## Notes

- `Lan Yan` uses project key `LanYan` but local avatar metadata key
  `Lanyan`, so registry/GUI code must preserve the alias mapping.
- `Ororon` currently maps to avatar key `Olorun` in local Lunaris metadata.
- Local Lunaris metadata is sufficient for base roster registration,
  portrait/icon lookup, and weapon/element typing.
- A stable local JSON source for full talent multipliers, constellations, and
  weapon passive text has not yet been confirmed, so detailed simulator data
  still needs per-character modeling work.
