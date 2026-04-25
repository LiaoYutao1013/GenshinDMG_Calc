function [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Simplified Nilou simulator for Dance of Haftkarsvar, Hydro burst
    % damage, and Bountiful Core ownership in Bloom teams.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Nilou', 'rotation_Nilou.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Nilou', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Nilou');
    base = readtable(fullfile(dataFolder, 'characters_Nilou.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Nilou.csv'));
    actions = readRotationTokens(seqFile);

    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    hydroCritRate = getFieldOrDefault(build, 'CritRate', 0);
    hydroCritDMG = getFieldOrDefault(build, 'CritDMG', 0);
    if constellation >= 6
        hpUnits = max(0, (maxHP - 30000) / 1000);
        hydroCritRate = hydroCritRate + min(0.30, hpUnits * 0.006);
        hydroCritDMG = hydroCritDMG + min(0.60, hpUnits * 0.012);
    end
    hydroCritMult = calcExpectedCritMultiplier(hydroCritRate, hydroCritDMG);

    bountifulEnabled = getFieldOrDefault(teamContext, 'NilouPureBloomTeam', false);
    if ~bountifulEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) <= 1 && getFieldOrDefault(teamContext, 'DendroCount', 0) == 0
        bountifulEnabled = true;
    end

    hydroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'HydroResShred', 0) ...
        + 0.35 * double(constellation >= 2 && bountifulEnabled);
    dendroResShred = getFieldOrDefault(teamContext, 'DendroResShred', 0) + 0.35 * double(constellation >= 2 && bountifulEnabled);
    hydroMult = calcDamageMultiplier(90, enemy, hydroResShred);
    bloomBonus = 1 + min(4.0, max(0, maxHP - 30000) / 1000 * getTalentValue(talent, 'Passive', 'AeonsBonus', talentLevel));
    bloomBonus = bloomBonus * (1 + getFieldOrDefault(teamContext, 'NilouBloomBonus', 0));

    reactionCritRate = getFieldOrDefault(teamContext, 'ReactionCritRate', []);
    reactionCritDMG = getFieldOrDefault(teamContext, 'ReactionCritDMG', []);
    if ~getFieldOrDefault(teamContext, 'LunarBloomEnabled', false)
        reactionCritRate = [];
        reactionCritDMG = [];
    end

    totalDMG = 0;
    rotationTime = 0;
    burstBonusReady = false;
    auraTicks = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        note = "";
        dmg = 0;

        switch action
            case 'E'
                note = "Dance stance entered";

            case 'Dance1'
                mv = getTalentValue(talent, 'Skill', 'Dance1HP', talentLevel);
                dmg = maxHP * mv * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * hydroCritMult * hydroMult;
                note = "Sword dance step 1";

            case 'Dance2'
                mv = getTalentValue(talent, 'Skill', 'Dance2HP', talentLevel);
                dmg = maxHP * mv * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * hydroCritMult * hydroMult;
                note = "Sword dance step 2";

            case 'Dance3'
                mv = getTalentValue(talent, 'Skill', 'Dance3HP', talentLevel);
                dmg = maxHP * mv * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * hydroCritMult * hydroMult;
                burstBonusReady = constellation >= 4;
                note = "Golden Chalice state active";

            case 'Aura'
                auraTicks = auraTicks + 1;
                mv = getTalentValue(talent, 'Skill', 'AuraHP', talentLevel);
                dmg = maxHP * mv * (1 + 0.20 * double(constellation >= 1)) ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * hydroCritMult * hydroMult;
                note = sprintf('Tranquility aura tick #%d', auraTicks);

            case 'Q'
                castMV = getTalentValue(talent, 'Burst', 'CastHP', talentLevel);
                lotusMV = getTalentValue(talent, 'Burst', 'LotusHP', talentLevel);
                dmg = maxHP * (castMV + lotusMV) * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * hydroCritMult * hydroMult;
                if burstBonusReady
                    dmg = dmg * 1.50;
                end
                note = "Hydro burst";

            case 'Bloom'
                if bountifulEnabled
                    dmg = calcReactionDamage(getTalentValue(talent, 'Reaction', 'BountifulCore', talentLevel), ...
                        getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0), ...
                        enemy, dendroResShred, bloomBonus, reactionCritRate, reactionCritDMG);
                    if getFieldOrDefault(teamContext, 'LunarBloomEnabled', false)
                        note = "Lunar-Bloom-adjusted core";
                    else
                        note = "Bountiful Core";
                    end
                else
                    note = "No Hydro+Dendro-only team";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + localActionTime(action);
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localHydroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.35;
        case {'Dance1', 'Dance2', 'Dance3'}
            actionTime = 0.45;
        case 'Aura'
            actionTime = 1.60;
        case 'Q'
            actionTime = 1.10;
        case 'Bloom'
            actionTime = 1.25;
        otherwise
            actionTime = 0.50;
    end
end
