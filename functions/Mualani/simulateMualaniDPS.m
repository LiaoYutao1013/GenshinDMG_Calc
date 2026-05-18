function [totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Mualani standalone simulator with stance state and aura-aware vaporize checks.
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
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    vaporizeBonus = getTalentValue(talent, 'Reaction', 'VaporizeBonus', talentLevel);
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', createEnemyState(enemy, teamContext, "Hydro"));

    state = struct( ...
        'SurfTime', 0, ...
        'WaveMomentum', 0, ...
        'MarkedTarget', false, ...
        'BiteCount', 0, ...
        'MissileLoaded', false);

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        [enemyState, ~] = advanceEnemyStateTime(enemyState, actionTime, "Hydro", teamContext);
        dmg = 0;
        note = "";

        switch action
            case 'E'
                entryBonus = 1 + 0.10 * double(state.SurfTime > 0);
                baseDMG = maxHP * getTalentValue(talent, 'Skill', 'SharkEntryHP', talentLevel) * entryBonus ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                [dmg, enemyState, reactionName] = localApplyHydroReaction(baseDMG, enemyState, em, vaporizeBonus, teamContext);
                state.SurfTime = 6.5;
                state.WaveMomentum = 1;
                state.MarkedTarget = true;
                state.BiteCount = 0;
                state.MissileLoaded = false;
                note = localMergeReactionNote("Surf stance entered", reactionName);

            case 'Bite'
                if state.SurfTime > 0
                    state.BiteCount = state.BiteCount + 1;
                    state.WaveMomentum = min(3, state.WaveMomentum + 1);
                    biteBonus = 1 + 0.16 * state.WaveMomentum + 0.08 * double(state.MarkedTarget);
                    if constellation >= 2
                        biteBonus = biteBonus * 1.20;
                    end
                    baseDMG = maxHP * getTalentValue(talent, 'Skill', 'SharkBiteHP', talentLevel) * biteBonus ...
                        * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                    [dmg, enemyState, reactionName] = localApplyHydroReaction(baseDMG, enemyState, em, vaporizeBonus, teamContext);
                    if reactionName == "Vaporize" && mod(state.BiteCount, 2) == 1
                        dmg = dmg * 1.15;
                    end
                    note = localMergeReactionNote(sprintf('Shark bite, momentum=%d', state.WaveMomentum), reactionName);
                    state.MarkedTarget = false;
                    state.MissileLoaded = state.WaveMomentum >= 3;
                else
                    note = "Surf stance expired";
                end

            case 'Missile'
                if state.MissileLoaded || state.SurfTime > 0
                    finisherMomentum = max(1, state.WaveMomentum);
                    missileBonus = 1 + 0.25 * finisherMomentum + 0.10 * double(getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1);
                    baseDMG = maxHP * getTalentValue(talent, 'Skill', 'MissileHP', talentLevel) * missileBonus ...
                        * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) * critMult * hydroMult;
                    [dmg, enemyState, reactionName] = localApplyHydroReaction(baseDMG, enemyState, em, vaporizeBonus, teamContext);
                    note = localMergeReactionNote(sprintf('Missile finisher, momentum=%d', finisherMomentum), reactionName);
                    state.WaveMomentum = 0;
                    state.MissileLoaded = false;
                    state.MarkedTarget = true;
                else
                    note = "No loaded missile";
                end

            case 'Q'
                burstBonus = 1 + 0.15 * double(state.SurfTime > 0) + 0.08 * double(state.MarkedTarget);
                baseDMG = maxHP * getTalentValue(talent, 'Burst', 'CastHP', talentLevel) * burstBonus ...
                    * localHydroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) * critMult * hydroMult;
                [dmg, enemyState, reactionName] = localApplyHydroReaction(baseDMG, enemyState, em, vaporizeBonus, teamContext);
                state.MarkedTarget = true;
                note = localMergeReactionNote("Burst cast", reactionName);

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
    dmgBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function [dmg, enemyState, reactionName] = localApplyHydroReaction(baseDMG, enemyState, em, vaporizeBonus, teamContext)
    [reactionMultiplier, enemyState, reaction] = getAmplifyingReactionMultiplier( ...
        enemyState, "Hydro", em, teamContext, 1.0, 0, vaporizeBonus);
    dmg = baseDMG * reactionMultiplier;
    reactionName = reaction.Name;
end

function note = localMergeReactionNote(baseNote, reactionName)
    if reactionName == ""
        note = string(baseNote);
    else
        note = sprintf('%s, %s', baseNote, lower(char(reactionName)));
    end
end

function state = localAdvanceState(state, actionTime)
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
