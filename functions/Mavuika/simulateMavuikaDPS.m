function [totalDMG, dps, breakdown, rotationTime] = simulateMavuikaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 玛薇卡单角色模拟器。
    % 重点跟踪战技领域持续、战意层数累积，以及爆发终结段如何
    % 结算当前战意与前序领域脉冲收益。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Mavuika', 'rotation_Mavuika.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Mavuika', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Mavuika');
    base = readtable(fullfile(dataFolder, 'characters_Mavuika.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Mavuika.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    critRate = getFieldOrDefault(build, 'CritRate', 0) + 0.10 * double(constellation >= 6);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.40 * double(constellation >= 1);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    pyroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'PyroResShred', 0);
    pyroMult = calcDamageMultiplier(90, enemy, pyroResShred);

    % state 保存领域、爆发和战意相关的全部时变状态。
    state = struct( ...
        'FieldTime', 0, ...
        'BurstTime', 0, ...
        'FightingSpirit', 0, ...
        'BlazeTicks', 0, ...
        'SunfallReady', false ...
    );

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        dmg = 0;
        note = "";

        switch action
            case 'E'
                % 战技开启领域，并提供初始战意。
                openingBonus = 1 + 0.10 * double(state.BurstTime > 0);
                dmg = atk * getTalentValue(talent, 'Skill', 'CastATK', talentLevel) * openingBonus ...
                    * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * pyroMult;
                state.FieldTime = 12.0;
                state.FightingSpirit = min(6, state.FightingSpirit + 2);
                state.BlazeTicks = 0;
                note = sprintf('Field opened, fighting spirit=%d', state.FightingSpirit);

            case 'Blaze'
                if state.FieldTime > 0
                    % 领域脉冲会随着触发次数和当前战意层数逐步增强。
                    state.BlazeTicks = state.BlazeTicks + 1;
                    blazeBonus = 1 + 0.10 * state.FightingSpirit + 0.05 * max(0, state.BlazeTicks - 1);
                    if constellation >= 2
                        blazeBonus = blazeBonus * 1.15;
                    end
                    dmg = atk * getTalentValue(talent, 'Skill', 'BlazeATK', talentLevel) * blazeBonus ...
                        * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * pyroMult;
                    state.FightingSpirit = min(6, state.FightingSpirit + 1);
                    note = sprintf('Field tick #%d, fighting spirit=%d', state.BlazeTicks, state.FightingSpirit);
                else
                    note = "Field expired";
                end

            case 'Q'
                % 爆发按当前战意层数增伤，并为后续终结段做准备。
                burstBonus = 1 + state.FightingSpirit * getTalentValue(talent, 'Burst', 'FightingSpirit', talentLevel);
                dmg = atk * getTalentValue(talent, 'Burst', 'CastATK', talentLevel) * burstBonus ...
                    * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * pyroMult;
                state.BurstTime = 8.0;
                state.SunfallReady = true;
                note = sprintf('Burst cast with spirit=%d', state.FightingSpirit);

            case 'Sunfall'
                if state.SunfallReady
                    % 终结段消耗当前战意并重置整套爆发状态。
                    finisherBonus = 1 + state.FightingSpirit * getTalentValue(talent, 'Burst', 'FightingSpirit', talentLevel) ...
                        + 0.04 * state.BlazeTicks;
                    dmg = atk * getTalentValue(talent, 'Burst', 'SunfallATK', talentLevel) * finisherBonus ...
                        * localPyroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * pyroMult;
                    if constellation >= 6
                        dmg = dmg * 1.30;
                    end
                    note = sprintf('Sunfall finisher with spirit=%d', state.FightingSpirit);
                    state.FightingSpirit = 0;
                    state.BurstTime = 0;
                    state.SunfallReady = false;
                else
                    note = "No burst finisher prepared";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localPyroBonus(build, teamContext, extraBonus)
    % 统一处理玛薇卡所有火元素段伤的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'PyroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进领域和爆发窗口时间。
    state.FieldTime = max(0, state.FieldTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    if state.BurstTime <= 0
        state.SunfallReady = false;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'Blaze'
            actionTime = 1.60;
        case 'Q'
            actionTime = 1.20;
        case 'Sunfall'
            actionTime = 0.95;
        otherwise
            actionTime = 0.55;
    end
end
