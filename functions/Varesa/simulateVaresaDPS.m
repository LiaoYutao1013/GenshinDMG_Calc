function [totalDMG, dps, breakdown, rotationTime] = simulateVaresaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 瓦雷莎高精度近似模拟器。
    % 建模重点：
    % 1. 战技入场后的突进、腾跃与下落输出链；
    % 2. 明确处理弹丸/转化优先级为纯雷站场，不混入不确定元素转换；
    % 3. 命座对技能段、爆发终结段和暴击状态的强化。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Varesa', 'rotation_Varesa.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Varesa', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Varesa');
    base = readtable(fullfile(dataFolder, 'characters_Varesa.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Varesa.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    critRate = min(1, getFieldOrDefault(build, 'CritRate', 0) ...
        + getFieldOrDefault(teamContext, 'PlungeCritRateBonus', 0) ...
        + 0.15 * double(constellation >= 1) + 0.20 * double(constellation >= 6));
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.60 * double(constellation >= 6);
    electroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
    electroMult = calcDamageMultiplier(90, enemy, electroResShred);

    % state 记录疾冲状态、落击强化层数与爆发终结准备。
    state = struct( ...
        'RushTime', 0, ...
        'PlungeStacks', 0, ...
        'BurstTime', 0, ...
        'FinisherReady', false, ...
        'OrbCount', 0 ...
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
                % 战技进入高机动窗口，后续突进与下落会按层数成长。
                mv = getTalentValue(talent, 'Skill', 'RushATK', localSkillTalentLevel(talentLevel, constellation));
                dmg = localDirectDamage(atk, mv, build, teamContext, state, electroMult, ...
                    getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG);
                state.RushTime = 10.0;
                state.PlungeStacks = 1;
                state.OrbCount = min(3, state.OrbCount + 1);
                note = "Rush state entered";

            case 'Rush'
                if state.RushTime > 0
                    mv = getTalentValue(talent, 'Skill', 'ImpactATK', localSkillTalentLevel(talentLevel, constellation));
                    rushBonus = 1 + 0.10 * state.PlungeStacks + 0.08 * state.OrbCount;
                    if constellation >= 2
                        rushBonus = rushBonus * 1.18;
                    end
                    dmg = localDirectDamage(atk, mv * rushBonus, build, teamContext, state, electroMult, ...
                        getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG);
                    state.PlungeStacks = min(3 + double(constellation >= 1), state.PlungeStacks + 1);
                    note = sprintf('Rush impact, plunge stacks=%d', state.PlungeStacks);
                else
                    note = "Rush state expired";
                end

            case 'Leap'
                if state.RushTime > 0
                    mv = getTalentValue(talent, 'Skill', 'LeapATK', localSkillTalentLevel(talentLevel, constellation));
                    leapBonus = 1 + 0.12 * state.PlungeStacks;
                    dmg = localDirectDamage(atk, mv * leapBonus, build, teamContext, state, electroMult, ...
                        getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG);
                    note = "Launch upward";
                else
                    note = "Rush state expired";
                end

            case 'Plunge'
                % 站场核心输出段，随层数、命座与爆发窗口同时增强。
                if state.RushTime > 0 || state.BurstTime > 0
                    mv = getTalentValue(talent, 'Plunge', 'HighPlungeATK', talentLevel);
                    plungeBonus = 1 + 0.22 * state.PlungeStacks + 0.10 * double(state.BurstTime > 0);
                    if constellation >= 1
                        plungeBonus = plungeBonus + 0.15;
                    end
                    if constellation >= 6
                        plungeBonus = plungeBonus + 0.35;
                    end
                    plungeExtraBonus = getFieldOrDefault(build, 'PlungeDMGBonus', 0) ...
                        + getFieldOrDefault(teamContext, 'PlungeDMGBonus', 0);
                    dmg = localDirectDamage(atk, mv * plungeBonus, build, teamContext, state, electroMult, ...
                        plungeExtraBonus, critRate, critDMG);
                    dmg = dmg + getFieldOrDefault(teamContext, 'XianyunFlatPlungeBonus', 0);

                    if getFieldOrDefault(teamContext, 'ElectroChargedReady', false)
                        reactionDMG = calcReactionDamage(getTalentValue(talent, 'Reaction', 'ElectroCharged', talentLevel), ...
                            em, enemy, electroResShred, 1.10, critRate * 0.35, critDMG * 0.45);
                        totalDMG = totalDMG + reactionDMG;
                        breakdown = [breakdown; {string("ElectroCharged"), reactionDMG, "Electro-Charged splash from plunge"}]; %#ok<AGROW>
                    end
                    state.OrbCount = min(5, state.OrbCount + 1);
                    note = sprintf('Empowered plunge, orb count=%d', state.OrbCount);
                else
                    note = "No aerial window active";
                end

            case 'Q'
                % 爆发视为第二轮强化起点，并准备终结段。
                mv = getTalentValue(talent, 'Burst', 'CastATK', localBurstTalentLevel(talentLevel, constellation));
                burstBonus = 1 + 0.10 * state.OrbCount + 0.12 * state.PlungeStacks;
                dmg = localDirectDamage(atk, mv * burstBonus, build, teamContext, state, electroMult, ...
                    getFieldOrDefault(build, 'BurstDMGBonus', 0), critRate, critDMG);
                state.BurstTime = 10.0;
                state.FinisherReady = true;
                state.PlungeStacks = max(state.PlungeStacks, 2 + double(constellation >= 4));
                note = sprintf('Burst active, plunge stacks=%d', state.PlungeStacks);

            case 'Finisher'
                if state.FinisherReady
                    mv = getTalentValue(talent, 'Burst', 'FinisherATK', localBurstTalentLevel(talentLevel, constellation));
                    finisherBonus = 1 + 0.20 * state.OrbCount + 0.10 * state.PlungeStacks;
                    if constellation >= 2
                        finisherBonus = finisherBonus * 1.22;
                    end
                    if constellation >= 6
                        finisherBonus = finisherBonus * 1.35;
                    end
                    dmg = localDirectDamage(atk, mv * finisherBonus, build, teamContext, state, electroMult, ...
                        getFieldOrDefault(build, 'BurstDMGBonus', 0), critRate, critDMG);
                    state.FinisherReady = false;
                    state.BurstTime = 0;
                    state.RushTime = 0;
                    state.PlungeStacks = 0;
                    note = "Burst finisher";
                else
                    note = "No finisher prepared";
                end

            case {'N1', 'N2'}
                mv = getTalentValue(talent, 'Normal', action, talentLevel);
                normalBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0) + 0.05 * double(state.RushTime > 0);
                dmg = localDirectDamage(atk, mv, build, teamContext, state, electroMult, normalBonus, critRate, critDMG);
                note = "Normal attack";

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function dmg = localDirectDamage(atk, mv, build, teamContext, state, electroMult, extraBonus, critRate, critDMG)
    % 统一处理瓦雷莎雷伤段的期望伤害。
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmgBonus = 1 + getFieldOrDefault(build, 'ElectroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus ...
        + 0.06 * double(state.BurstTime > 0);
    dmg = atk * mv * dmgBonus * critMult * electroMult;
end

function state = localAdvanceState(state, actionTime)
    % 推进疾冲与爆发窗口。
    state.RushTime = max(0, state.RushTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    if state.RushTime <= 0 && state.BurstTime <= 0
        state.PlungeStacks = 0;
    end
    if state.BurstTime <= 0
        state.FinisherReady = false;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.55;
        case 'Rush'
            actionTime = 0.80;
        case 'Leap'
            actionTime = 0.55;
        case 'Plunge'
            actionTime = 0.95;
        case 'Q'
            actionTime = 1.15;
        case 'Finisher'
            actionTime = 1.00;
        case {'N1', 'N2'}
            actionTime = 0.45;
        otherwise
            actionTime = 0.50;
    end
end
