function [totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Simplified Nefer simulator tracking Shadow Dance uptime, Verdant Dew
    % consumption, Veil stacks, and Lunar-Bloom follow-up damage.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Nefer', 'rotation_Nefer.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Nefer', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Nefer');
    base = readtable(fullfile(dataFolder, 'characters_Nefer.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Nefer.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    baseEM = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    dendroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'DendroResShred', 0);
    directMult = calcDamageMultiplier(90, enemy, dendroResShred);
    lunarBloomEnabled = getFieldOrDefault(teamContext, 'LunarBloomEnabled', false);
    if ~lunarBloomEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0 && getFieldOrDefault(teamContext, 'DendroCount', 0) <= 1
        lunarBloomEnabled = true;
    end

    totalDMG = 0;
    rotationTime = 0;
    verdantDew = 0;
    veilStacks = 0;
    phantasmCount = 0;
    maxVeilStacks = 3 + 2 * double(constellation >= 2);
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        note = "";
        dmg = 0;

        switch action
            case 'E'
                currentEM = baseEM + 200 * double(constellation >= 2 && veilStacks >= maxVeilStacks);
                critMult = localCritMultiplier(build, constellation, veilStacks, maxVeilStacks);
                dmg = (currentEM * getTalentValue(talent, 'Skill', 'CastEM', talentLevel) + atk * 0.60) ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * critMult * calcDamageMultiplier(90, enemy, dendroResShred + 0.20 * double(constellation >= 4));
                verdantDew = min(4, verdantDew + 2 + double(constellation >= 1));
                note = sprintf('Shadow Dance active, dew=%d', verdantDew);

            case 'Phantasm'
                if verdantDew > 0
                    phantasmCount = phantasmCount + 1;
                    veilStacks = min(maxVeilStacks, veilStacks + 1);
                    currentEM = baseEM + 200 * double(constellation >= 2 && veilStacks >= maxVeilStacks);
                    critMult = localCritMultiplier(build, constellation, veilStacks, maxVeilStacks);
                    skillEM = getTalentValue(talent, 'Skill', 'PhantasmEM', talentLevel);
                    skillATK = getTalentValue(talent, 'Skill', 'PhantasmATK', talentLevel);
                    dmg = (currentEM * skillEM + atk * skillATK) * (1 + 0.08 * veilStacks) ...
                        * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * critMult * calcDamageMultiplier(90, enemy, dendroResShred + 0.20 * double(constellation >= 4));
                    verdantDew = verdantDew - 1;
                    note = sprintf('Consumed dew, veil=%d', veilStacks);

                    if constellation >= 6 && mod(phantasmCount, 2) == 0
                        extraDMG = calcReactionDamage(900 + 0.25 * currentEM, currentEM, enemy, dendroResShred, ...
                            1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0), ...
                            max(0.10, getFieldOrDefault(teamContext, 'ReactionCritRate', 0.10)), ...
                            max(0.20, getFieldOrDefault(teamContext, 'ReactionCritDMG', 0.20)));
                        totalDMG = totalDMG + extraDMG;
                        breakdown = [breakdown; {string("C6Afterimage"), extraDMG, "Extra afterimage bloom"}]; %#ok<AGROW>
                    end
                else
                    note = "No Verdant Dew available";
                end

            case 'Q'
                currentEM = baseEM + 200 * double(constellation >= 2 && veilStacks >= maxVeilStacks);
                critMult = localCritMultiplier(build, constellation, veilStacks, maxVeilStacks);
                dmg = currentEM * getTalentValue(talent, 'Burst', 'CastEM', talentLevel) ...
                    * (1 + veilStacks * getTalentValue(talent, 'Burst', 'VeilBonus', talentLevel)) ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * critMult * calcDamageMultiplier(90, enemy, dendroResShred + 0.20 * double(constellation >= 4));
                verdantDew = min(4, verdantDew + 1 + double(constellation >= 4));
                note = sprintf('Burst cast, dew=%d, veil=%d', verdantDew, veilStacks);

            case 'LunarBloom'
                if lunarBloomEnabled
                    currentEM = baseEM + 200 * double(constellation >= 2 && veilStacks >= maxVeilStacks);
                    baseReaction = getTalentValue(talent, 'Reaction', 'LunarBloomBase', talentLevel) ...
                        + getTalentValue(talent, 'Passive', 'C1EMBonus', talentLevel) * currentEM * double(constellation >= 1);
                    reactionBonus = 1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0) + 0.15 * double(constellation >= 6);
                    dmg = calcReactionDamage(baseReaction, currentEM, enemy, dendroResShred + 0.20 * double(constellation >= 4), ...
                        reactionBonus, max(0.10, getFieldOrDefault(teamContext, 'ReactionCritRate', 0.10)), ...
                        max(0.20, getFieldOrDefault(teamContext, 'ReactionCritDMG', 0.20)));
                    note = "Lunar-Bloom burst";
                else
                    note = "No Hydro/Dendro partner for Lunar-Bloom";
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

function critMult = localCritMultiplier(build, constellation, veilStacks, maxVeilStacks)
    critRate = getFieldOrDefault(build, 'CritRate', 0);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
    if constellation >= 2 && veilStacks >= maxVeilStacks
        critDMG = critDMG + 0.40;
    end
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
end

function dmgBonus = localDendroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'DendroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'Phantasm'
            actionTime = 0.80;
        case 'Q'
            actionTime = 1.20;
        case 'LunarBloom'
            actionTime = 1.25;
        otherwise
            actionTime = 0.55;
    end
end
