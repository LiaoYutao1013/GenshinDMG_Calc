function [totalDMG, dps, breakdown, rotationTime] = simulateXilonenDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 希诺宁单角色模拟器。
    % 重点跟踪滑行状态、源音采样数和爆发后的强化窗口，使采样数
    % 变化真正反映到后续动作伤害中。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Xilonen', 'rotation_Xilonen.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Xilonen', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Xilonen');
    base = readtable(fullfile(dataFolder, 'characters_Xilonen.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Xilonen.csv'));
    actions = readRotationTokens(seqFile);

    defStat = base.BaseDEF(1) * (1 + getFieldOrDefault(build, 'DEFBonus', 0)) + getFieldOrDefault(build, 'FlatDEF', 0);
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    geoResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'GeoResShred', 0);
    geoMult = calcDamageMultiplier(90, enemy, geoResShred);

    % 采样数上限会受到队内元素种类近似影响，因此由 teamContext 提供。
    state = struct( ...
        'SkatingTime', 0, ...
        'SampleCount', 0, ...
        'MaxSamples', max(3, getFieldOrDefault(teamContext, 'XilonenSampleCount', 3)), ...
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
        dmg = 0;
        note = "";

        switch action
            case 'E'
                % 战技进入滑行状态，并一次性获得基础采样数。
                entryBonus = 1 + 0.05 * state.SampleCount;
                dmg = defStat * getTalentValue(talent, 'Skill', 'RollerDEF', talentLevel) * entryBonus ...
                    * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * geoMult;
                state.SkatingTime = 9.0;
                state.SampleCount = min(state.MaxSamples, 2 + double(constellation >= 1));
                note = sprintf('Skating state entered, samples=%d', state.SampleCount);

            case 'Source'
                if state.SkatingTime > 0
                    % 源音采样动作会继续累积样本，并按当前样本数增伤。
                    state.SampleCount = min(state.MaxSamples, state.SampleCount + 1);
                    sourceBonus = 1 + 0.08 * state.SampleCount + 0.10 * double(state.BurstTime > 0);
                    dmg = defStat * getTalentValue(talent, 'Skill', 'SourceDEF', talentLevel) * sourceBonus ...
                        * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * geoMult;
                    if constellation >= 2
                        dmg = dmg * 1.18;
                    end
                    note = sprintf('Source sample #%d', state.SampleCount);
                else
                    note = "Skating state expired";
                end

            case 'Q'
                % 爆发会提供治疗并开启后续强化窗口。
                burstBonus = 1 + 0.05 * state.SampleCount;
                dmg = defStat * getTalentValue(talent, 'Burst', 'CastDEF', talentLevel) * burstBonus ...
                    * localGeoBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * geoMult;
                healTotal = healTotal + defStat * getTalentValue(talent, 'Burst', 'HealDEF', talentLevel) ...
                    * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
                if constellation >= 6
                    dmg = dmg * 1.25;
                end
                state.BurstTime = 9.0;
                note = sprintf('Burst cast, samples=%d', state.SampleCount);

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
    % 统一处理希诺宁所有岩元素段伤的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'GeoDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进滑行和爆发强化窗口。
    state.SkatingTime = max(0, state.SkatingTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.65;
        case 'Source'
            actionTime = 1.55;
        case 'Q'
            actionTime = 1.15;
        otherwise
            actionTime = 0.50;
    end
end
