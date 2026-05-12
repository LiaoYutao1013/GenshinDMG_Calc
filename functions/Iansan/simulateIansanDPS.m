function [totalDMG, dps, breakdown, rotationTime] = simulateIansanDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 伊安珊高精度近似模拟器。
    % 建模重点：
    % 1. 战技冲刺与印记投掷的前台动作；
    % 2. 爆发后的训练场/增幅窗口与协同落雷；
    % 3. 队伍中高移动或高站场节奏下的攻击辅助近似收益。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Iansan', 'rotation_Iansan.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Iansan', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Iansan');
    base = readtable(fullfile(dataFolder, 'characters_Iansan.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Iansan.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    critRate = min(1, getFieldOrDefault(build, 'CritRate', 0) + 0.10 * double(constellation >= 6));
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.40 * double(constellation >= 2);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    electroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
    electroMult = calcDamageMultiplier(90, enemy, electroResShred);

    lunarChargedEnabled = getFieldOrDefault(teamContext, 'LunarChargedEnabled', false);
    burstSupportBonus = getFieldOrDefault(teamContext, 'IansanBurstATKBonus', 0);

    % state 记录冲刺缓存、爆发持续与协同落雷次数。
    state = struct( ...
        'SprintReady', false, ...
        'BurstTime', 0, ...
        'CoachMarks', 0, ...
        'BoltCount', 0 ...
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
                % 战技起手造成一段雷伤，并准备后续位移/投掷衔接。
                mv = getTalentValue(talent, 'Skill', 'DashATK', localSkillTalentLevel(talentLevel, constellation));
                dmg = atk * mv * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * electroMult;
                state.SprintReady = true;
                state.CoachMarks = min(3, state.CoachMarks + 1);
                note = sprintf('Skill dash, marks=%d', state.CoachMarks);

            case 'Sprint'
                if state.SprintReady
                    mv = getTalentValue(talent, 'Skill', 'SprintATK', localSkillTalentLevel(talentLevel, constellation));
                    sprintBonus = 1 + 0.10 * state.CoachMarks + 0.10 * double(state.BurstTime > 0);
                    dmg = atk * mv * sprintBonus * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * electroMult;
                    if constellation >= 1
                        state.CoachMarks = min(4, state.CoachMarks + 1);
                    end
                    state.SprintReady = false;
                    note = sprintf('Follow-up sprint, marks=%d', state.CoachMarks);
                else
                    note = "No sprint follow-up prepared";
                end

            case 'Q'
                % 爆发视为启动团队训练场，个人伤害和后续协同落雷均获得加成。
                mv = getTalentValue(talent, 'Burst', 'CastATK', localBurstTalentLevel(talentLevel, constellation));
                burstBonus = 1 + 0.08 * state.CoachMarks + 0.25 * burstSupportBonus;
                dmg = atk * mv * burstBonus * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * electroMult;
                state.BurstTime = 12.0;
                state.BoltCount = 0;
                state.CoachMarks = min(5, state.CoachMarks + 1 + double(constellation >= 4));
                note = sprintf('Burst active, marks=%d', state.CoachMarks);

            case 'Bolt'
                if state.BurstTime > 0
                    state.BoltCount = state.BoltCount + 1;
                    mv = getTalentValue(talent, 'Burst', 'BoltATK', localBurstTalentLevel(talentLevel, constellation));
                    boltBonus = 1 + 0.10 * state.BoltCount + 0.06 * state.CoachMarks;
                    dmg = atk * mv * boltBonus * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * electroMult;
                    if lunarChargedEnabled
                        reactionDMG = calcReactionDamage(getTalentValue(talent, 'Reaction', 'LunarCharged', talentLevel), ...
                            em, enemy, electroResShred, 1 + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0), ...
                            critRate * 0.50, critDMG * 0.70);
                        totalDMG = totalDMG + reactionDMG;
                        breakdown = [breakdown; {string("LunarCharged"), reactionDMG, "Burst bolt triggered Lunar-Charged"}]; %#ok<AGROW>
                    end
                    note = sprintf('Burst bolt #%d', state.BoltCount);
                else
                    note = "Burst inactive";
                end

            case 'Throw'
                mv = getTalentValue(talent, 'Skill', 'ThrowATK', localSkillTalentLevel(talentLevel, constellation));
                throwBonus = 1 + 0.06 * state.CoachMarks + 0.12 * double(constellation >= 2);
                dmg = atk * mv * throwBonus * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * electroMult;
                note = "Mark throw";

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

function dmgBonus = localElectroBonus(build, teamContext, extraBonus)
    % 统一处理伊安珊雷伤段的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'ElectroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进爆发训练窗口。
    state.BurstTime = max(0, state.BurstTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.60;
        case 'Sprint'
            actionTime = 0.75;
        case 'Throw'
            actionTime = 0.70;
        case 'Q'
            actionTime = 1.10;
        case 'Bolt'
            actionTime = 1.20;
        otherwise
            actionTime = 0.50;
    end
end
