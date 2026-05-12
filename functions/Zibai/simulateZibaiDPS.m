function [totalDMG, dps, breakdown, rotationTime] = simulateZibaiDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 兹白单角色模拟器。
    % 重点跟踪泉场持续时间、蓄压层数、爆发后的额外窗口，以及这些
    % 状态如何共同影响月结晶与重击终结段。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Zibai', 'rotation_Zibai.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Zibai', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Zibai');
    base = readtable(fullfile(dataFolder, 'characters_Zibai.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Zibai.csv'));
    actions = readRotationTokens(seqFile);

    defStat = base.BaseDEF(1) * (1 + getFieldOrDefault(build, 'DEFBonus', 0)) + getFieldOrDefault(build, 'FlatDEF', 0);
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    geoResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'GeoResShred', 0);
    geoMult = calcDamageMultiplier(90, enemy, geoResShred);
    % 单人调试时，只要有宽松水元素环境假设，也允许启用月结晶。
    lunarCrystallizeEnabled = getFieldOrDefault(teamContext, 'LunarCrystallizeEnabled', false) || getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1;

    % state 保存泉场、蓄压和爆发强化状态。
    state = struct( ...
        'SpringTime', 0, ...
        'SpringHits', 0, ...
        'Pressure', 0, ...
        'BurstTime', 0 ...
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
                % 战技布置泉场，并给予初始蓄压。
                mv = getTalentValue(talent, 'Skill', 'CastDEF', talentLevel);
                dmg = defStat * mv * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * geoMult;
                state.SpringTime = 12.0;
                state.SpringHits = 0;
                state.Pressure = min(4, state.Pressure + 2);
                note = sprintf('Spring created, pressure=%d', state.Pressure);

            case 'Spring'
                if state.SpringTime > 0
                    % 泉场脉冲会继续攒压，并可能顺带触发月结晶。
                    state.SpringHits = state.SpringHits + 1;
                    mv = getTalentValue(talent, 'Skill', 'SpringDEF', talentLevel);
                    springBonus = 1 + 0.10 * state.Pressure + 0.05 * max(0, state.SpringHits - 1) + 0.08 * double(state.BurstTime > 0);
                    dmg = defStat * mv * springBonus ...
                        * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * geoMult;
                    state.Pressure = min(4, state.Pressure + 1);
                    if lunarCrystallizeEnabled
                        reactionDMG = calcReactionDamage(getTalentValue(talent, 'Reaction', 'LunarCrystallize', talentLevel), ...
                            getFieldOrDefault(build, 'EM', 0), enemy, geoResShred, ...
                            1 + getFieldOrDefault(teamContext, 'LunarCrystallizeBonus', 0) + 0.05 * state.Pressure, ...
                            getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
                        totalDMG = totalDMG + reactionDMG;
                        breakdown = [breakdown; {string("LunarCrystallize"), reactionDMG, "Triggered by spring pulse"}]; %#ok<AGROW>
                    end
                    note = sprintf('Spring pulse, pressure=%d', state.Pressure);
                else
                    note = "Spring field expired";
                end

            case 'Q'
                % 爆发本体结算一次，并开启后续强化窗口。
                mv = getTalentValue(talent, 'Burst', 'CastDEF', talentLevel);
                dmg = defStat * mv * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * geoMult;
                state.BurstTime = 10.0;
                if constellation >= 2
                    extraDMG = defStat * getTalentValue(talent, 'Burst', 'StonehoofDEF', talentLevel) ...
                        * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * geoMult;
                    totalDMG = totalDMG + extraDMG;
                    breakdown = [breakdown; {string("Stonehoof"), extraDMG, "C2 burst follow-up"}]; %#ok<AGROW>
                end
                note = "Burst cast";

            case 'Charge'
                if state.Pressure > 0
                    % 重击终结段会消耗当前全部蓄压。
                    mv = getTalentValue(talent, 'Skill', 'ChargeDEF', talentLevel);
                    finisherBonus = 1 + 0.18 * state.Pressure + 0.10 * double(state.BurstTime > 0);
                    dmg = defStat * mv * finisherBonus ...
                        * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * geoMult;
                    if constellation >= 6
                        dmg = dmg * 1.30;
                    end
                    note = sprintf('Charge consumes pressure=%d', state.Pressure);
                    state.Pressure = 0;
                else
                    note = "No spring pressure stored";
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

function dmgBonus = localGeoBonus(build, teamContext, extraBonus)
    % 统一处理兹白所有岩元素段伤的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'GeoDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进泉场与爆发窗口时间。
    state.SpringTime = max(0, state.SpringTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'Spring'
            actionTime = 1.70;
        case 'Q'
            actionTime = 1.20;
        case 'Charge'
            actionTime = 0.90;
        otherwise
            actionTime = 0.55;
    end
end
