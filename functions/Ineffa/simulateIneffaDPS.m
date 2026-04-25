function [totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Simplified Ineffa simulator centered on summoned strikes, burst
    % re-synchronization, and Lunar-Charged follow-up damage.
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
    lunarChargedEnabled = getFieldOrDefault(teamContext, 'LunarChargedEnabled', false);
    if ~lunarChargedEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0
        lunarChargedEnabled = true;
    end

    totalDMG = 0;
    rotationTime = 0;
    tickCount = 0;
    totalShield = 0;
    tickBonus = 1;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        note = "";
        dmg = 0;

        switch action
            case 'E'
                mv = getTalentValue(talent, 'Skill', 'Cast', talentLevel);
                dmg = atk * mv * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * critMult * electroMult;
                totalShield = totalShield + atk * getTalentValue(talent, 'Shield', 'Ratio', talentLevel);
                note = "Summon deployed";

            case 'Tick'
                tickCount = tickCount + 1;
                mv = getTalentValue(talent, 'Skill', 'Birgitta', talentLevel);
                dmg = atk * mv * tickBonus * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * critMult * electroMult;
                note = sprintf('Summon strike #%d', tickCount);

                if lunarChargedEnabled
                    reactionBonus = 1 + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0);
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

            case 'Q'
                mv = getTalentValue(talent, 'Burst', 'Cast', talentLevel);
                dmg = atk * mv * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * critMult * electroMult;
                note = "Thundercloud reset";
                tickBonus = 1 + 0.20 * double(constellation >= 4);

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
        rotationTime = rotationTime + localActionTime(action);
    end

    if totalShield > 0
        breakdown = [breakdown; {string("Shield"), totalShield, "Shield strength snapshot"}]; %#ok<AGROW>
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localElectroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'ElectroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
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
