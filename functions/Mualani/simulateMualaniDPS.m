function [totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 玛拉妮单角色模拟器。
    % 该实现显式建模冲浪姿态持续时间、动量层数、目标是否处于可吃
    % 额外收益的标记状态，以及队伍是否提供可近似维持的蒸发环境。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Mualani', 'rotation_Mualani.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Mualani', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Mualani');
    base = readtable(fullfile(dataFolder, 'characters_Mualani.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Mualani.csv'));
    actions = readRotationTokens(seqFile);

    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    critRate = getFieldOrDefault(build, 'CritRate', 0) + 0.20 * double(constellation >= 1);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.50 * double(constellation >= 6);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    hydroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'HydroResShred', 0);
    hydroMult = calcDamageMultiplier(90, enemy, hydroResShred);
    % 队伍有火角色时，近似视为玛拉妮轮转内具备蒸发环境。
    vapeReady = getFieldOrDefault(teamContext, 'VaporizeReady', false) || getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1;

    % state 保存姿态和终结段准备状态。
    state = struct( ...
        'SurfTime', 0, ...
        'WaveMomentum', 0, ...
        'MarkedTarget', false, ...
        'BiteCount', 0, ...
        'MissileLoaded', false ...
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
        reactionBonus = 1;
        if vapeReady
            reactionBonus = 1 + getTalentValue(talent, 'Reaction', 'VaporizeBonus', talentLevel);
        end

        switch action
            case 'E'
                % 战技进入冲浪姿态，并重置本轮咬击与导弹准备状态。
                entryBonus = 1 + 0.10 * double(state.SurfTime > 0);
                dmg = maxHP * getTalentValue(talent, 'Skill', 'SharkEntryHP', talentLevel) * entryBonus ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                state.SurfTime = 6.5;
                state.WaveMomentum = 1;
                state.MarkedTarget = true;
                state.BiteCount = 0;
                state.MissileLoaded = false;
                note = "Surf stance entered";

            case 'Bite'
                if state.SurfTime > 0
                    % 咬击会提升动量，并根据是否处于蒸发轮次额外加成。
                    state.BiteCount = state.BiteCount + 1;
                    state.WaveMomentum = min(3, state.WaveMomentum + 1);
                    biteBonus = 1 + 0.16 * state.WaveMomentum + 0.08 * double(state.MarkedTarget);
                    if constellation >= 2
                        biteBonus = biteBonus * 1.20;
                    end
                    if vapeReady && mod(state.BiteCount, 2) == 1
                        biteBonus = biteBonus * 1.15;
                        note = sprintf('Shark bite vaped, momentum=%d', state.WaveMomentum);
                    else
                        note = sprintf('Shark bite, momentum=%d', state.WaveMomentum);
                    end
                    dmg = maxHP * getTalentValue(talent, 'Skill', 'SharkBiteHP', talentLevel) * biteBonus * reactionBonus ...
                        * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                    state.MarkedTarget = false;
                    state.MissileLoaded = state.WaveMomentum >= 3;
                else
                    note = "Surf stance expired";
                end

            case 'Missile'
                if state.MissileLoaded || state.SurfTime > 0
                    % 导弹段按当前动量作为终结技结算，随后清空动量。
                    finisherMomentum = max(1, state.WaveMomentum);
                    missileBonus = 1 + 0.25 * finisherMomentum + 0.10 * double(vapeReady);
                    dmg = maxHP * getTalentValue(talent, 'Skill', 'MissileHP', talentLevel) * missileBonus * reactionBonus ...
                        * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                    note = sprintf('Missile finisher, momentum=%d', finisherMomentum);
                    state.WaveMomentum = 0;
                    state.MissileLoaded = false;
                    state.MarkedTarget = true;
                else
                    note = "No loaded missile";
                end

            case 'Q'
                % 爆发按当前姿态与标记状态吃到额外增益。
                burstBonus = 1 + 0.15 * double(state.SurfTime > 0) + 0.08 * double(state.MarkedTarget);
                dmg = maxHP * getTalentValue(talent, 'Burst', 'CastHP', talentLevel) * burstBonus * reactionBonus ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * hydroMult;
                state.MarkedTarget = true;
                note = "Burst cast";

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
    % 统一处理玛拉妮所有水伤段的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 冲浪姿态会随动作时间持续衰减；姿态结束后清空相关资源。
    state.SurfTime = max(0, state.SurfTime - actionTime);
    if state.SurfTime <= 0
        state.WaveMomentum = 0;
        state.MissileLoaded = false;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.35;
        case 'Bite'
            actionTime = 0.85;
        case 'Missile'
            actionTime = 1.00;
        case 'Q'
            actionTime = 1.10;
        otherwise
            actionTime = 0.50;
    end
end
