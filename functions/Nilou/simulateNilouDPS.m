function [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 妮露单角色模拟器。
    % 该实现显式跟踪：
    % 1. 剑舞窗口是否仍可继续连段；
    % 2. 金杯状态与水环持续时间；
    % 3. 丰穰之核持有权近似储备；
    % 4. 高命座提供的爆发增益窗口。
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
    % 期望暴击乘区在进入动作循环前预先计算，便于后续复用。
    hydroCritMult = calcExpectedCritMultiplier(hydroCritRate, hydroCritDMG);

    % 纯水草队时启用丰穰之核；若是脱离队伍上下文的单人测试，则做
    % 一个宽松兜底，方便角色逻辑本地验证。
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

    % state 集中保存轮转推进中会变化的所有状态。
    state = struct( ...
        'DanceWindow', 0, ...
        'DanceStep', 0, ...
        'GoldenChaliceTime', 0, ...
        'AuraTime', 0, ...
        'AuraTicks', 0, ...
        'BloomStocks', 0, ...
        'BurstBonusTime', 0 ...
    );

    totalDMG = 0;
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
                % 元素战技开启舞步窗口，并预先给一些绽放准备量。
                state.DanceWindow = 8.0;
                state.DanceStep = 0;
                state.BloomStocks = min(2, state.BloomStocks + 1);
                note = "Dance stance opened";

            case 'Dance1'
                if state.DanceWindow > 0
                    % 舞步第 1 段：只在舞步窗口内有效。
                    state.DanceStep = 1;
                    mv = getTalentValue(talent, 'Skill', 'Dance1HP', talentLevel);
                    dmg = maxHP * mv * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * hydroCritMult * hydroMult;
                    state.BloomStocks = min(3, state.BloomStocks + 1);
                    note = sprintf('Sword dance step 1, bloom prep=%d', state.BloomStocks);
                else
                    note = "Dance window expired";
                end

            case 'Dance2'
                if state.DanceWindow > 0 && state.DanceStep >= 1
                    % 舞步第 2 段要求前一段已成功衔接。
                    state.DanceStep = 2;
                    mv = getTalentValue(talent, 'Skill', 'Dance2HP', talentLevel);
                    dmg = maxHP * mv * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * hydroCritMult * hydroMult;
                    state.BloomStocks = min(3, state.BloomStocks + 1);
                    note = sprintf('Sword dance step 2, bloom prep=%d', state.BloomStocks);
                else
                    note = "Dance sequence not ready";
                end

            case 'Dance3'
                if state.DanceWindow > 0 && state.DanceStep >= 2
                    % 第 3 段完成后正式进入金杯状态，并开启水环。
                    state.DanceStep = 3;
                    mv = getTalentValue(talent, 'Skill', 'Dance3HP', talentLevel);
                    dmg = maxHP * mv * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * hydroCritMult * hydroMult;
                    state.DanceWindow = 0;
                    state.GoldenChaliceTime = 30.0;
                    state.AuraTime = 12.0;
                    state.AuraTicks = 0;
                    state.BloomStocks = min(3, state.BloomStocks + 2);
                    state.BurstBonusTime = 8.0 * double(constellation >= 4);
                    note = sprintf('Golden Chalice active, aura=12.0 s, bloom prep=%d', state.BloomStocks);
                else
                    note = "Dance finisher not ready";
                end

            case 'Aura'
                if state.AuraTime > 0
                    % 水环脉冲随着触发次数略微递增，并持续积累绽放准备量。
                    state.AuraTicks = state.AuraTicks + 1;
                    mv = getTalentValue(talent, 'Skill', 'AuraHP', talentLevel);
                    pulseBonus = 1 + 0.05 * max(0, state.AuraTicks - 1) + 0.20 * double(constellation >= 1);
                    fieldBonus = 1 + 0.08 * double(state.GoldenChaliceTime > 0);
                    dmg = maxHP * mv * pulseBonus * fieldBonus ...
                        * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * hydroCritMult * hydroMult;
                    state.BloomStocks = min(3, state.BloomStocks + 1);
                    note = sprintf('Aura pulse #%d, bloom prep=%d', state.AuraTicks, state.BloomStocks);
                else
                    note = "Aura expired";
                end

            case 'Q'
                % 爆发吃到金杯与命座窗口的额外增益后统一结算。
                castMV = getTalentValue(talent, 'Burst', 'CastHP', talentLevel);
                lotusMV = getTalentValue(talent, 'Burst', 'LotusHP', talentLevel);
                burstBonus = 1 + 0.50 * double(state.BurstBonusTime > 0) + 0.10 * double(state.GoldenChaliceTime > 0);
                dmg = maxHP * (castMV + lotusMV) * burstBonus ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * hydroCritMult * hydroMult;
                if state.BurstBonusTime > 0
                    note = "Burst consumed C4 dance window";
                else
                    note = "Hydro burst";
                end
                state.BurstBonusTime = 0;

            case 'Bloom'
                if bountifulEnabled && state.GoldenChaliceTime > 0
                    % 丰穰之核伤害按当前储备的“持有权近似量”提高。
                    storedSeeds = max(1, state.BloomStocks);
                    ownershipBonus = 1 + 0.10 * (storedSeeds - 1) + 0.05 * double(state.AuraTime > 0);
                    dmg = calcReactionDamage( ...
                        getTalentValue(talent, 'Reaction', 'BountifulCore', talentLevel), ...
                        getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0), ...
                        enemy, dendroResShred, bloomBonus * ownershipBonus, reactionCritRate, reactionCritDMG);
                    state.BloomStocks = max(0, state.BloomStocks - 1);
                    if getFieldOrDefault(teamContext, 'LunarBloomEnabled', false)
                        note = sprintf('Lunar-Bloom adjusted core, bloom prep=%d', state.BloomStocks);
                    else
                        note = sprintf('Bountiful Core, bloom prep=%d', state.BloomStocks);
                    end
                elseif bountifulEnabled
                    note = "Golden Chalice inactive";
                else
                    note = "No Hydro+Dendro-only team";
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

function dmgBonus = localHydroBonus(build, teamContext, extraBonus)
    % 统一处理妮露所有水元素伤害的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 在每个动作后推进所有计时状态，保持状态衰减口径一致。
    state.DanceWindow = max(0, state.DanceWindow - actionTime);
    state.GoldenChaliceTime = max(0, state.GoldenChaliceTime - actionTime);
    state.AuraTime = max(0, state.AuraTime - actionTime);
    state.BurstBonusTime = max(0, state.BurstBonusTime - actionTime);

    if state.AuraTime <= 0
        state.AuraTicks = 0;
    end
    if state.DanceWindow <= 0
        state.DanceStep = 0;
    end
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
