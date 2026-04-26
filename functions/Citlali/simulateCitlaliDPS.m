function [totalDMG, dps, breakdown, rotationTime] = simulateCitlaliDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 茜特菈莉单角色模拟器。
    % 该实现显式记录护盾持续、星体追击、爆发生成的头骨数量以及
    % 命座对这些辅助段伤的强化效果。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Citlali', 'rotation_Citlali.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Citlali', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Citlali');
    talent = readtable(fullfile(dataFolder, 'talents_Citlali.csv'));
    actions = readRotationTokens(seqFile);

    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    cryoResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'CryoResShred', 0);
    cryoMult = calcDamageMultiplier(90, enemy, cryoResShred);

    % state 保存所有与护盾和爆发窗口相关的状态。
    state = struct( ...
        'ShieldTime', 0, ...
        'ShieldStrength', 0, ...
        'StarCount', 0, ...
        'BurstTime', 0, ...
        'SkullCount', 0 ...
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
                % 战技只生成护盾快照，不直接造成伤害。
                state.ShieldStrength = em * getTalentValue(talent, 'Skill', 'ShieldEM', talentLevel);
                state.ShieldTime = 12.0;
                state.StarCount = 0;
                note = sprintf('Shield established, value=%.0f', state.ShieldStrength);

            case 'Star'
                if state.ShieldTime > 0
                    % 星体追击会随触发次数和爆发状态获得更高系数。
                    state.StarCount = state.StarCount + 1;
                    starBonus = 1 + 0.05 * max(0, state.StarCount - 1) + 0.12 * double(state.BurstTime > 0);
                    dmg = em * getTalentValue(talent, 'Skill', 'StarCryo', talentLevel) * starBonus ...
                        * localCryoBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * cryoMult;
                    if constellation >= 2
                        dmg = dmg * 1.20;
                    end
                    note = sprintf('Cryo support star #%d', state.StarCount);
                else
                    note = "Shield expired";
                end

            case 'Q'
                % 爆发开启后会预存头骨数量，供后续单独结算。
                dmg = em * getTalentValue(talent, 'Burst', 'CastEM', talentLevel) ...
                    * (1 + 0.10 * double(state.ShieldTime > 0)) ...
                    * localCryoBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * cryoMult;
                state.BurstTime = 10.0;
                state.SkullCount = state.SkullCount + 1 + double(constellation >= 4);
                note = sprintf('Burst cast, skulls=%d', state.SkullCount);

            case 'Skull'
                if state.SkullCount > 0
                    % 头骨段按当前剩余数量与护盾状态提高伤害。
                    skullBonus = 1 + 0.10 * state.SkullCount + 0.08 * double(state.ShieldTime > 0);
                    dmg = em * getTalentValue(talent, 'Burst', 'SkullEM', talentLevel) * skullBonus ...
                        * localCryoBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * cryoMult;
                    if constellation >= 6
                        dmg = dmg * 1.35;
                    end
                    note = sprintf('Burst skull detonation, remaining=%d', state.SkullCount - 1);
                    state.SkullCount = state.SkullCount - 1;
                else
                    note = "No stored skull";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if state.ShieldStrength > 0
        breakdown = [breakdown; {string("Shield"), state.ShieldStrength, "Shield snapshot"}]; %#ok<AGROW>
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localCryoBonus(build, teamContext, extraBonus)
    % 统一处理茜特菈莉所有冰元素段伤的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'CryoDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进护盾和爆发窗口时间。
    state.ShieldTime = max(0, state.ShieldTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    if state.ShieldTime <= 0
        state.StarCount = 0;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.55;
        case 'Star'
            actionTime = 1.70;
        case 'Q'
            actionTime = 1.15;
        case 'Skull'
            actionTime = 0.90;
        otherwise
            actionTime = 0.50;
    end
end
