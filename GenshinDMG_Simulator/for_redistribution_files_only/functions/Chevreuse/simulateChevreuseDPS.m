function [totalDMG, dps, breakdown, rotationTime, audit] = simulateChevreuseDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Chevreuse support and damage windows with explicit overload gating.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Chevreuse', 'rotation_Chevreuse.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Chevreuse', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Chevreuse');
    base = readtable(fullfile(dataFolder, 'characters_Chevreuse.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Chevreuse.csv'), 'TextType', 'string');
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    critRate = min(1, getFieldOrDefault(build, 'CritRate', 0) + 0.10 * double(constellation >= 6));
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.20 * double(constellation >= 2);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    pyroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'PyroResShred', 0);
    pyroMult = calcDamageMultiplier(90, enemy, pyroResShred);

    overloadReady = getFieldOrDefault(teamContext, 'ChevreuseOverloadReady', false);
    overloadBonus = 1 + getFieldOrDefault(teamContext, 'OverloadBonus', 0);

    state = struct( ...
        'LoadedShotReady', false, ...
        'HealingTime', 0, ...
        'BurstTime', 0, ...
        'BurstStacks', 0);

    totalDMG = 0;
    totalHeal = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = char(string(actions{i}));
        actionTime = localActionTime(action);
        dmg = 0;
        heal = 0;
        note = "";

        switch action
            case 'E'
                mv = getTalentValue(talent, 'Skill', 'ShotATK', localSkillTalentLevel(talentLevel, constellation));
                skillBonus = 1 + 0.12 * double(overloadReady) + 0.06 * double(state.BurstTime > 0);
                dmg = atk * mv * skillBonus ...
                    * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * critMult * pyroMult;
                state.LoadedShotReady = true;
                state.HealingTime = 12.0;
                note = "Skill hit, loaded shot enabled";

            case 'LoadedShot'
                if state.LoadedShotReady
                    mv = getTalentValue(talent, 'Skill', 'LoadedShotATK', localSkillTalentLevel(talentLevel, constellation));
                    loadedBonus = 1 + 0.18 * double(overloadReady) + 0.10 * double(constellation >= 1) ...
                        + 0.06 * state.BurstStacks;
                    dmg = atk * mv * loadedBonus ...
                        * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * critMult * pyroMult;
                    state.LoadedShotReady = false;
                    note = "Special loaded shot";
                else
                    note = "No loaded shot prepared";
                end

            case 'Q'
                mv = getTalentValue(talent, 'Burst', 'GrenadeATK', localBurstTalentLevel(talentLevel, constellation));
                burstBonus = 1 + 0.10 * double(overloadReady) + 0.08 * double(constellation >= 4);
                dmg = atk * mv * burstBonus ...
                    * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * critMult * pyroMult;
                state.BurstTime = 12.0;
                state.BurstStacks = min(3, state.BurstStacks + 1 + double(constellation >= 4));
                note = sprintf('Burst cast, support stacks=%d', state.BurstStacks);

            case 'Grenade'
                if state.BurstTime > 0
                    mv = getTalentValue(talent, 'Burst', 'SecondaryGrenadeATK', localBurstTalentLevel(talentLevel, constellation));
                    grenadeBonus = 1 + 0.08 * state.BurstStacks + 0.12 * double(overloadReady);
                    dmg = atk * mv * grenadeBonus ...
                        * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                        * critMult * pyroMult;
                    if constellation >= 6
                        dmg = dmg * 1.25;
                    end
                    note = "Burst follow-up grenade";
                else
                    note = "Burst inactive";
                end

            case 'Heal'
                if state.HealingTime > 0
                    healRate = getTalentValue(talent, 'Heal', 'HealHP', talentLevel);
                    heal = maxHP * healRate * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
                    if constellation >= 6
                        heal = heal * 1.10;
                    end
                    note = "Skill-linked healing";
                else
                    note = "Healing window inactive";
                end

            case 'Overload'
                if overloadReady
                    baseReaction = getTalentValue(talent, 'Reaction', 'Overload', talentLevel);
                    dmg = calcReactionDamage(baseReaction, em, enemy, 0, overloadBonus, critRate * 0.40, critDMG * 0.60);
                    note = "Overload trigger";
                else
                    note = "Team does not satisfy overload setup";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        totalHeal = totalHeal + heal;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        if heal > 0
            breakdown = [breakdown; {string(action) + "_Heal", heal, "Healing"}]; %#ok<AGROW>
        end
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if totalHeal > 0
        breakdown = [breakdown; {string("Heal"), totalHeal, "Total healing"}]; %#ok<AGROW>
    end
    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;

    if nargout > 4
        auditOverrides = struct( ...
            'loadedshot', struct('ApplyGaugeSource', "not_applicable", 'ICDSource', "not_applicable"), ...
            'heal', struct('ApplyGaugeSource', "not_applicable", 'ICDSource', "not_applicable"));
        audit = buildInferredReactionAudit( ...
            struct('Name', "Chevreuse", 'Constellation', constellation, 'TalentLevel', talentLevel), ...
            actions, teamContext, seqFile, auditOverrides, struct('PrimaryArchetype', "Support"));
    else
        audit = struct();
    end
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function dmgBonus = localPyroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'PyroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    state.HealingTime = max(0, state.HealingTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    if state.BurstTime <= 0
        state.BurstStacks = 0;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'LoadedShot'
            actionTime = 0.85;
        case 'Q'
            actionTime = 1.15;
        case 'Grenade'
            actionTime = 0.90;
        case 'Heal'
            actionTime = 0.50;
        case 'Overload'
            actionTime = 0.70;
        otherwise
            actionTime = 0.50;
    end
end
