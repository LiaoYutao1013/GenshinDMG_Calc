function [totalDMG, dps, breakdown, rotationTime] = simulateFlinsDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Flins simulator. It tracks phantom lamp uptime, burst resonance
    % linking, and the Lunar-Charged ownership attached to recurring
    % phantom strikes.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Flins', 'rotation_Flins.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Flins', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Flins');
    base = readtable(fullfile(dataFolder, 'characters_Flins.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Flins.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    electroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
    electroMult = calcDamageMultiplier(90, enemy, electroResShred);
    lunarChargedEnabled = getFieldOrDefault(teamContext, 'LunarChargedEnabled', false) || getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1;

    state = struct( ...
        'LampTime', 0, ...
        'PhantomCount', 0, ...
        'ResonanceTime', 0 ...
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
                mv = getTalentValue(talent, 'Skill', 'Cast', talentLevel);
                dmg = atk * mv * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * electroMult;
                state.LampTime = 12.0;
                state.PhantomCount = 0;
                note = "Phantom lamp deployed";

            case 'Phantom'
                if state.LampTime > 0
                    state.PhantomCount = state.PhantomCount + 1;
                    mv = getTalentValue(talent, 'Skill', 'Phantom', talentLevel);
                    phantomBonus = 1 + 0.08 * state.PhantomCount + 0.15 * double(constellation >= 1);
                    dmg = atk * mv * phantomBonus ...
                        * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * electroMult;
                    note = sprintf('Phantom strike #%d', state.PhantomCount);
                    if state.ResonanceTime > 0
                        extraDMG = atk * getTalentValue(talent, 'Burst', 'Resonance', talentLevel) ...
                            * (1 + 0.05 * state.PhantomCount) ...
                            * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * electroMult;
                        totalDMG = totalDMG + extraDMG;
                        breakdown = [breakdown; {string("Resonance"), extraDMG, "Burst-linked resonance"}]; %#ok<AGROW>
                    end
                    if lunarChargedEnabled
                        reactionDMG = calcReactionDamage(getTalentValue(talent, 'Reaction', 'LunarCharged', talentLevel), ...
                            getFieldOrDefault(build, 'EM', 0), enemy, electroResShred, ...
                            1 + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0) + 0.05 * state.PhantomCount, ...
                            getFieldOrDefault(build, 'CritRate', 0) * 0.60, getFieldOrDefault(build, 'CritDMG', 0));
                        totalDMG = totalDMG + reactionDMG;
                        breakdown = [breakdown; {string("LunarCharged"), reactionDMG, "Triggered by phantom strike"}]; %#ok<AGROW>
                    end
                else
                    note = "Lamp expired";
                end

            case 'Q'
                mv = getTalentValue(talent, 'Burst', 'Cast', talentLevel);
                dmg = atk * mv * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * electroMult;
                state.ResonanceTime = 10.0;
                if constellation >= 2
                    dmg = dmg * 1.20;
                end
                note = "Burst enters resonance state";

            case {'N1', 'N2'}
                mv = getTalentValue(talent, 'Normal', action, talentLevel);
                dmg = atk * mv * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'NormalDMGBonus', 0)) * critMult * electroMult;
                if constellation >= 6 && strcmp(action, 'N2')
                    extraDMG = atk * 2.80 * localElectroBonus(build, teamContext, getFieldOrDefault(build, 'NormalDMGBonus', 0)) * critMult * electroMult;
                    totalDMG = totalDMG + extraDMG;
                    breakdown = [breakdown; {string("C6Volt"), extraDMG, "Extra arc after N2"}]; %#ok<AGROW>
                end
                note = "Normal attack";

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

function dmgBonus = localElectroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'ElectroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % Shared timer update for lamp and resonance uptime.
    state.LampTime = max(0, state.LampTime - actionTime);
    state.ResonanceTime = max(0, state.ResonanceTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.65;
        case 'Phantom'
            actionTime = 1.60;
        case 'Q'
            actionTime = 1.10;
        case {'N1', 'N2'}
            actionTime = 0.45;
        otherwise
            actionTime = 0.55;
    end
end
