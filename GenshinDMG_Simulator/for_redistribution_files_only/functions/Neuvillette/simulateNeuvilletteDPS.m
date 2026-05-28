function [totalDMG, dps, breakdown, rotationTime] = simulateNeuvilletteDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 那维莱特单角色模拟器。
    % 这里重点建模：
    % 1. 源水之滴的生成与消耗；
    % 2. 古海孑遗层数在队伍上下文中的近似值；
    % 3. 重击水柱按消耗滴露数量变化的段数与倍率。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Neuvillette', 'rotation_Neuvillette.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Neuvillette', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Neuvillette');
    base = readtable(fullfile(dataFolder, 'characters_Neuvillette.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Neuvillette.csv'));
    actions = readRotationTokens(seqFile);

    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    critRate = getFieldOrDefault(build, 'CritRate', 0) + 0.14 * double(constellation >= 1);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.42 * double(constellation >= 6);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    hydroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'HydroResShred', 0);
    hydroMult = calcDamageMultiplier(90, enemy, hydroResShred);

    % 若 teamContext 已经预估出层数，则优先直接使用该值。
    state = struct( ...
        'SourcewaterDroplets', 0, ...
        'DraconicStacks', min(3, getFieldOrDefault(teamContext, 'NeuvilletteDraconicStacks', ...
            getFieldOrDefault(teamContext, 'PyroCount', 0) + getFieldOrDefault(teamContext, 'ElectroCount', 0) + getFieldOrDefault(teamContext, 'CryoCount', 0))), ...
        'PastDraconicTime', 0, ...
        'BeamCount', 0 ...
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
        stackBonus = 1 + state.DraconicStacks * getTalentValue(talent, 'Passive', 'DraconicStack', talentLevel);
        hydroBonus = localHydroBonus(build, teamContext, 0);

        switch action
            case 'E'
                % 战技生成 2 枚源水之滴，并刷新古海孑遗持续窗口。
                dmg = maxHP * getTalentValue(talent, 'Skill', 'SourcewaterHP', talentLevel) ...
                    * (1 + 0.10 * double(state.PastDraconicTime > 0)) ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                state.SourcewaterDroplets = min(3, state.SourcewaterDroplets + 2);
                state.PastDraconicTime = 30.0;
                note = sprintf('Skill cast, droplets=%d', state.SourcewaterDroplets);

            case 'Q'
                % 爆发生成更多滴露，供后续重击消耗。
                dmg = maxHP * getTalentValue(talent, 'Burst', 'CastHP', talentLevel) ...
                    * (1 + 0.12 * double(state.PastDraconicTime > 0)) ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * hydroMult;
                state.SourcewaterDroplets = min(3, state.SourcewaterDroplets + 3);
                state.PastDraconicTime = 30.0;
                note = sprintf('Burst cast, droplets=%d', state.SourcewaterDroplets);

            case 'Droplet'
                if state.SourcewaterDroplets > 0
                    % 滴露爆裂段只在有存量时才计入。
                    dmg = maxHP * getTalentValue(talent, 'Burst', 'DropletHP', talentLevel) ...
                        * (1 + 0.05 * state.SourcewaterDroplets) ...
                        * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                    note = sprintf('Droplet burst, stored=%d', state.SourcewaterDroplets);
                else
                    note = "No droplets available";
                end

            case 'Charge'
                % 重击至少按 1 枚滴露起算，避免无滴露时完全失效。
                consumed = max(1, state.SourcewaterDroplets);
                state.BeamCount = state.BeamCount + 1;
                beamTicks = 4 + consumed;
                beamDMG = maxHP * getTalentValue(talent, 'Charge', 'BeamHP', talentLevel) * beamTicks;
                finalDMG = maxHP * getTalentValue(talent, 'Charge', 'FinalWaveHP', talentLevel);
                chargeBonus = stackBonus * (1 + 0.10 * (consumed - 1) + getFieldOrDefault(teamContext, 'HydroBeamBonus', 0));
                dmg = (beamDMG + finalDMG) * chargeBonus ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'ChargeDMGBonus', 0)) * critMult * hydroMult;
                if constellation >= 2
                    dmg = dmg * 1.25;
                end
                if constellation >= 6 && state.BeamCount == 2
                    dmg = dmg * 1.20;
                    note = sprintf('Empowered second beam consumed %d droplets', consumed);
                else
                    note = sprintf('Charge beam consumed %d droplets', consumed);
                end
                state.SourcewaterDroplets = 0;

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
    % 统一处理那维莱特所有水伤段的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进古海孑遗持续时间，方便后续动作判断是否仍处于生效窗口。
    state.PastDraconicTime = max(0, state.PastDraconicTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.60;
        case 'Q'
            actionTime = 1.25;
        case 'Droplet'
            actionTime = 0.40;
        case 'Charge'
            actionTime = 3.00;
        otherwise
            actionTime = 0.55;
    end
end
