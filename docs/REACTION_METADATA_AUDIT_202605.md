# Reaction Metadata Audit 2026-05

## Purpose

This note documents the current audit path used to calibrate:

- `ApplyGauge`
- `ICDRule`
- `ICDGroup`
- Lunaris attack-table matching coverage

The project now supports two reaction modes:

- `Approximate`
  - keeps legacy auto support-aura behavior
  - preserves older single-character result expectations
- `Realistic`
  - disables automatic support-aura synthesis
  - requires explicit enemy initial aura or explicit elemental hits
  - should be used for reaction-engine precision work

## Current Entry Points

1. `functions/createEnemyState.m`
   - now stores `ReactionMode`
   - only enables `AutoSupportAura` by default in `Approximate`

2. `functions/buildTeamContext.m`
   - accepts `SharedBuffs.ReactionMode`
   - injects the same mode into the initial enemy state

3. `functions/resolveReactionForHit.m`
   - only forces `PreferredAura` / support aura in `Approximate`

4. `functions/simulateSimpleCharacterDPS.m`
   - now records audit metadata for each action:
     - `ApplyGauge`
     - `ApplyGaugeSource`
     - `ICDRule`
     - `ICDSource`
     - matched Lunaris attack name / damage param

5. `functions/auditCharacterReactionMetadata.m`
   - standalone audit helper
   - runs in `Realistic` mode
   - returns per-action coverage rows

## How To Audit

Example:

```matlab
audit = auditCharacterReactionMetadata('Xiangling');
audit.Rows
```

Recommended filters:

```matlab
rows = audit.Rows;
rows(rows.ApplyGaugeFallback | rows.ICDFallback, :)
```

Interpretation:

- `ApplyGaugeSource = "explicit"`
  - action script set a manual gauge
- `ApplyGaugeSource = "metadata"`
  - gauge resolved from local Lunaris attack metadata
- `ApplyGaugeSource = "fallback"`
  - still using generic fallback logic

- `ICDSource = "explicit"`
  - action script set a manual ICD rule/group
- `ICDSource = "metadata"`
  - ICD resolved from Lunaris metadata
- `ICDSource = "fallback"`
  - no resolved ICD metadata

## Known Limitation

`auditCharacterReactionMetadata` currently audits through the unified
imported/generic spec path so it can run across the whole roster without
requiring every bespoke simulator to expose its internal action spec.

That means:

- it is reliable for finding missing metadata coverage
- it is not yet a full truth audit of every bespoke high-precision script

For characters with custom simulators, the next precision pass should add
character-local action audits where needed after the trunk metadata gaps are
reduced.
