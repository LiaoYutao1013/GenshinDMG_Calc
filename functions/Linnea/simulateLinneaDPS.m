function [totalDMG, dps, breakdown, rotationTime] = simulateLinneaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Linnea simulator. It models Lumi uptime, Field Catalog stack growth,
    % burst healing, and the heavy Crush finisher that spends stored stacks.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Linnea', 'rotation_Linnea.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Linnea', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Linnea');
    base = readtable(fullfile(dataFolder, 'characters_Linnea.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Linnea.csv'));
    actions = readRotationTokens(seqFile);

    defStat = base.BaseDEF(1) * (1 + getFieldOrDefault(build, 'DEFBonus', 0)) + getFieldOrDefault(build, 'FlatDEF', 0);
    if constellation >= 4
        defStat = defStat * 1.25;
    end

    geoCritDMG = getFieldOrDefault(build, 'CritDMG', 0) + getFieldOrDefault(teamContext, 'GeoCritDMGBonus', 0) ...
        + 0.40 * double(constellation >= 2);
    geoCritMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), geoCritDMG);
    geoResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'GeoResShred', 0);
    geoMult = calcDamageMultiplier(90, enemy, geoResShred);
    lunarCrystallizeEnabled = getFieldOrDefault(teamContext, 'LunarCrystallizeEnabled', false);
    if ~lunarCrystallizeEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0
        lunarCrystallizeEnabled = true;
    end

    state = struct( ...
        'LumiTime', 0, ...
        'LumiHits', 0, ...
        'FieldCatalogStacks', 0, ...
        'MaxFieldCatalog', 6 + 3 * double(constellation >= 6), ...
        'BurstTime', 0 ...
    );

    totalDMG = 0;
    healTotal = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        note = "";
        dmg = 0;

        switch action
            case 'E'
                dmg = defStat * getTalentValue(talent, 'Skill', 'CastDEF', talentLevel) ...
                    * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * geoCritMult * geoMult;
                state.LumiTime = 12.0;
                state.LumiHits = 0;
                state.FieldCatalogStacks = min(state.MaxFieldCatalog, state.FieldCatalogStacks + 2);
                note = sprintf('Lumi deployed, field catalog=%d', state.FieldCatalogStacks);

            case 'Lumi'
                if state.LumiTime > 0
                    state.LumiHits = state.LumiHits + 1;
                    state.FieldCatalogStacks = min(state.MaxFieldCatalog, state.FieldCatalogStacks + 1);
                    lumiBonus = 1 + 0.06 * state.LumiHits + 0.04 * state.FieldCatalogStacks;
                    dmg = defStat * getTalentValue(talent, 'Skill', 'LumiDEF', talentLevel) * lumiBonus ...
                        * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * geoCritMult * geoMult;
                    note = sprintf('Lumi strike #%d, field catalog=%d', state.LumiHits, state.FieldCatalogStacks);
                else
                    note = "Lumi expired";
                end

            case 'Harmony'
                if lunarCrystallizeEnabled
                    reactionBonus = 1 + getFieldOrDefault(teamContext, 'LunarCrystallizeBonus', 0) ...
                        + 0.05 * state.FieldCatalogStacks + 0.25 * double(constellation >= 6);
                    dmg = calcReactionDamage(getTalentValue(talent, 'Reaction', 'LunarCrystallize', talentLevel), ...
                        getFieldOrDefault(build, 'EM', 0), enemy, geoResShred, reactionBonus, ...
                        getFieldOrDefault(build, 'CritRate', 0), geoCritDMG);
                    note = sprintf('Lunar-Crystallize detonation, field catalog=%d', state.FieldCatalogStacks);
                else
                    note = "No Hydro aura for Lunar-Crystallize";
                end

            case 'Q'
                burstBonus = 1 + 0.04 * state.FieldCatalogStacks;
                dmg = defStat * getTalentValue(talent, 'Burst', 'CastDEF', talentLevel) * burstBonus ...
                    * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * geoCritMult * geoMult;
                healTotal = healTotal + defStat * getTalentValue(talent, 'Burst', 'HealDEF', talentLevel) ...
                    * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
                state.BurstTime = 10.0;
                state.FieldCatalogStacks = min(state.MaxFieldCatalog, state.FieldCatalogStacks + 2);
                note = sprintf('Burst cast, field catalog=%d', state.FieldCatalogStacks);

            case 'Crush'
                crushCritDMG = geoCritDMG + 1.50 * double(constellation >= 2);
                crushCritMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), crushCritDMG);
                mv = getTalentValue(talent, 'Skill', 'CrushDEF', talentLevel);
                spendBonus = 1 + 0.05 * state.FieldCatalogStacks + 0.10 * double(state.BurstTime > 0);
                dmg = defStat * mv * spendBonus ...
                    * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * crushCritMult * geoMult;

                if constellation >= 1 && state.FieldCatalogStacks > 0
                    stackBonus = defStat * getTalentValue(talent, 'Passive', 'FieldCatalogDEF', talentLevel) * state.FieldCatalogStacks;
                    if constellation >= 6
                        stackBonus = stackBonus * 1.50;
                    end
                    dmg = dmg + stackBonus;
                    note = sprintf('Consumed %d field catalog stacks', state.FieldCatalogStacks);
                    state.FieldCatalogStacks = 0;
                else
                    note = "Million-Ton Crush";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if healTotal > 0
        breakdown = [breakdown; {string("Heal"), healTotal, "Burst healing"}]; %#ok<AGROW>
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localGeoBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'GeoDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % Advance Lumi and burst windows so stack generation stays time-aware.
    state.LumiTime = max(0, state.LumiTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.80;
        case 'Lumi'
            actionTime = 1.70;
        case 'Harmony'
            actionTime = 1.20;
        case 'Q'
            actionTime = 1.25;
        case 'Crush'
            actionTime = 0.95;
        otherwise
            actionTime = 0.55;
    end
end
