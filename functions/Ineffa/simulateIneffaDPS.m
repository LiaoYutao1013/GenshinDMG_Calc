function [totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 伊涅芙单角色模拟器。
    % 该实现会跟踪召唤物持续、爆发刷新、护盾快照以及每次召唤物
    % 攻击附带的月感电追击伤害。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Ineffa', 'rotation_Ineffa.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Ineffa', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Ineffa');
    base = readtable(fullfile(dataFolder, 'characters_Ineffa.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Ineffa.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    electroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
    electroMult = calcDamageMultiplier(90, enemy, electroResShred);
    % teamContext 未给出完整环境时，单人模式也允许宽松启用月感电。
    lunarChargedEnabled = getFieldOrDefault(teamContext, 'LunarChargedEnabled', false);
    if ~lunarChargedEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0
        lunarChargedEnabled = true;
    end

    % state 保存召唤物、护盾和强化脉冲相关状态。
    state = struct( ...
        'SummonTime', 0, ...
        'TickCount', 0, ...
        'TickBonus', 1, ...
        'ShieldStrength', 0 ...
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
                % 战技召唤物开启后续 Tick，并记录护盾快照强度。
                dmg = atk * getTalentValue(talent, 'Skill', 'Cast', talentLevel) ...
                    * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * critMult * electroMult;
                state.SummonTime = 12.0;
                state.TickCount = 0;
                state.TickBonus = 1;
                state.ShieldStrength = atk * getTalentValue(talent, 'Shield', 'Ratio', talentLevel);
                note = sprintf('Summon deployed, shield=%.0f', state.ShieldStrength);

            case 'Tick'
                if state.SummonTime > 0
                    % 每次 Tick 都会按当前次数叠加少量系数，并可能触发月感电追击。
                    state.TickCount = state.TickCount + 1;
                    tickScale = 1 + 0.06 * max(0, state.TickCount - 1);
                    dmg = atk * getTalentValue(talent, 'Skill', 'Birgitta', talentLevel) * state.TickBonus * tickScale ...
                        * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * critMult * electroMult;
                    note = sprintf('Summon strike #%d', state.TickCount);

                    if lunarChargedEnabled
                        reactionBonus = 1 + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0) + 0.08 * double(state.TickBonus > 1);
                        if constellation >= 1
                            reactionBonus = reactionBonus + min(0.50, atk / 100 * 0.025);
                        end

                        reactionDMG = calcReactionDamage(getTalentValue(talent, 'Reaction', 'LunarCharged', talentLevel), ...
                            getFieldOrDefault(build, 'EM', 0) + 0.15 * atk, enemy, electroResShred, reactionBonus, ...
                            getFieldOrDefault(build, 'CritRate', 0) * 0.60, getFieldOrDefault(build, 'CritDMG', 0));
                        totalDMG = totalDMG + reactionDMG;
                        breakdown = [breakdown; {string("LunarCharged"), reactionDMG, "Coordinated Lunar-Charged hit"}]; %#ok<AGROW>
                    end

                    if constellation >= 6
                        extraMV = getTalentValue(talent, 'Burst', 'FollowUp', talentLevel);
                        extraDMG = atk * extraMV * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                            * critMult * electroMult;
                        totalDMG = totalDMG + extraDMG;
                        breakdown = [breakdown; {string("C6Pulse"), extraDMG, "Carrier Flow follow-up"}]; %#ok<AGROW>
                    end
                else
                    note = "Summon expired";
                end

            case 'Q'
                % 爆发会刷新或延长召唤物窗口，并强化之后的 Tick。
                dmg = atk * getTalentValue(talent, 'Burst', 'Cast', talentLevel) ...
                    * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * critMult * electroMult;
                note = "Thundercloud reset";
                state.SummonTime = max(state.SummonTime, 10.0);
                state.TickBonus = 1 + 0.20 * double(constellation >= 4);

                if constellation >= 2
                    extraDMG = atk * 3.00 * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                        * critMult * electroMult;
                    totalDMG = totalDMG + extraDMG;
                    breakdown = [breakdown; {string("C2Punishment"), extraDMG, "Burst-triggered AoE strike"}]; %#ok<AGROW>
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
        breakdown = [breakdown; {string("Shield"), state.ShieldStrength, "Shield strength snapshot"}]; %#ok<AGROW>
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localElectroBonus(build, teamContext, extraBonus)
    % 统一处理伊涅芙所有雷元素段伤的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'ElectroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进召唤物持续时间，使战技和爆发共享同一时钟。
    state.SummonTime = max(0, state.SummonTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.65;
        case 'Tick'
            actionTime = 1.80;
        case 'Q'
            actionTime = 1.15;
        otherwise
            actionTime = 0.50;
    end
end
