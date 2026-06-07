function [totalDMG, dps, breakdown, rotationTime, audit] = simulateFurinaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Furina explicit Arkhe / Salon script with timeline-backed background ticks.
    % Arkhe mode swaps, companion windows, burst, and C6 infusions are
    % modeled as separate stateful actions while Salon/Singer activity can
    % be derived from the active duration window itself.
    % Remaining approximation: fanfare now prefers explicit team HP event
    % logs, but missing heal/self-HP event sources still fall back to
    % timeline rhythm heuristics.
    if nargin < 3 || isempty(seqFile)
        seqFile = char(resolveCharacterDataFile('Furina', 'rotation'));
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Furina', 'Constellation', constellation, 'Build', build)}, 20, struct(), enemy);
    end

    base = readtable(char(resolveCharacterDataFile('Furina', 'characters')));
    talent = readtable(char(localResolveFurinaTalentFile()), 'TextType', 'string');
    actions = localResolveRotation(seqFile);

    localTeamContext = localRemoveFurinaApprox(teamContext);
    timelineProfile = localResolveFurinaTimelineProfile(teamContext, constellation);
    companionTickMeta = localResolveFurinaCompanionTickMetadata( ...
        struct('Name', 'Furina', 'Constellation', constellation), localTeamContext);
    useExplicitCompanionActions = localUsesExplicitCompanionActions(actions);
    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(localTeamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(localTeamContext, 'FlatATK', 0);
    hydroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(localTeamContext, 'HydroResShred', 0);
    hydroMult = calcDamageMultiplier(90, enemy, hydroResShred);
    physicalResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(localTeamContext, 'PhysicalResShred', 0);
    physicalMult = calcDamageMultiplier(90, enemy, physicalResShred);

    state = struct( ...
        'ArkheMode', "Ousia", ...
        'SalonTime', 0, ...
        'SalonTicks', 0, ...
        'SingerTicks', 0, ...
        'BurstTime', 0, ...
        'Fanfare', 0, ...
        'FanfareCap', 300 + 100 * double(constellation >= 1), ...
        'OverflowFanfare', 0, ...
        'C6Time', 0, ...
        'C6HitsLeft', 0, ...
        'ThornCooldown', 0, ...
        'Constellation', constellation, ...
        'AutoCompanionEnabled', ~useExplicitCompanionActions, ...
        'NextCompanionTickDelay', inf, ...
        'OusiaFirstTickDelay', companionTickMeta.OusiaFirstTickDelay, ...
        'OusiaTickInterval', companionTickMeta.OusiaTickInterval, ...
        'PneumaFirstTickDelay', companionTickMeta.PneumaFirstTickDelay, ...
        'PneumaTickInterval', companionTickMeta.PneumaTickInterval, ...
        'TimelineProfile', timelineProfile);

    totalDMG = 0;
    totalHeal = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = string(actions{i});
        actionTime = localActionTime(action);
        dmg = 0;
        heal = 0;
        note = "";

        switch upper(char(action))
            case 'E'
                state.SalonTime = 30.0;
                state.SalonTicks = 0;
                state.SingerTicks = 0;
                state = localResetCompanionTickDelay(state, true);
                foamMV = localTalentRowValue(talent, 11, localSkillTalentLevel(talentLevel, constellation));
                dmg = localHPScaledDamage(maxHP, foamMV, "Hydro", build, localTeamContext, state, ...
                    getFieldOrDefault(build, 'SkillDMGBonus', 0), hydroMult);
                note = "Salon deployed";
                if constellation >= 6
                    state.C6Time = 10.0;
                    state.C6HitsLeft = 6;
                    note = "Salon deployed, C6 active";
                end

            case 'SWITCHPNEUMA'
                state.ArkheMode = "Pneuma";
                state = localResetCompanionTickDelay(state, true);
                note = "Switched to Pneuma";

            case 'SWITCHOUSIA'
                state.ArkheMode = "Ousia";
                state = localResetCompanionTickDelay(state, true);
                note = "Switched to Ousia";

            case {'N1', 'N2', 'N3', 'N4'}
                [normalMV, normalNote] = localNormalMV(talent, action, talentLevel);
                dmg = localATKScaledDamage(atk, normalMV, "Physical", build, localTeamContext, state, ...
                    getFieldOrDefault(build, 'NormalDMGBonus', 0), physicalMult);
                note = normalNote;
                if state.C6HitsLeft > 0 && state.C6Time > 0
                    [c6DMG, c6Heal, c6Note, state] = localResolveC6Hit(build, localTeamContext, state, maxHP, hydroMult, action);
                    dmg = dmg + c6DMG;
                    heal = heal + c6Heal;
                    note = strtrim(note + " " + c6Note);
                end
                if state.ThornCooldown <= 0
                    thornMV = localTalentRowValue(talent, 9, talentLevel);
                    thornDMG = localHPScaledDamage(maxHP, thornMV, "Hydro", build, localTeamContext, state, 0, hydroMult);
                    totalDMG = totalDMG + thornDMG;
                    breakdown = [breakdown; {string("Arkhe"), thornDMG, localArkheNote(state)}]; %#ok<AGROW>
                    state.ThornCooldown = 6.0;
                end

            case {'HEAVY', 'CA'}
                heavyMV = localTalentRowValue(talent, 5, talentLevel);
                dmg = localATKScaledDamage(atk, heavyMV, "Physical", build, localTeamContext, state, ...
                    getFieldOrDefault(build, 'NormalDMGBonus', 0), physicalMult);
                note = "Charged attack";
                if state.C6HitsLeft > 0 && state.C6Time > 0
                    [c6DMG, c6Heal, c6Note, state] = localResolveC6Hit(build, localTeamContext, state, maxHP, hydroMult, action);
                    dmg = dmg + c6DMG;
                    heal = heal + c6Heal;
                    note = strtrim(note + " " + c6Note);
                end

            case 'PLUNGE'
                plungeMV = localTalentRowValue(talent, 8, talentLevel);
                dmg = localATKScaledDamage(atk, plungeMV, "Physical", build, localTeamContext, state, ...
                    getFieldOrDefault(build, 'NormalDMGBonus', 0), physicalMult);
                note = "Plunging attack";
                if state.C6HitsLeft > 0 && state.C6Time > 0
                    [c6DMG, c6Heal, c6Note, state] = localResolveC6Hit(build, localTeamContext, state, maxHP, hydroMult, action);
                    dmg = dmg + c6DMG;
                    heal = heal + c6Heal;
                    note = strtrim(note + " " + c6Note);
                end

            case {'USHER', 'CHEVAL', 'CRAB'}
                if state.SalonTime > 0 && state.ArkheMode == "Ousia"
                    state.SalonTicks = state.SalonTicks + 1;
                    [salonMV, subtypeName] = localSalonMV(talent, action, localSkillTalentLevel(talentLevel, constellation));
                    salonAmp = [1.00, 1.10, 1.20, 1.30, 1.40];
                    partyIndex = min(max(1, getFieldOrDefault(localTeamContext, 'MemberCount', 4)), 4) + 1;
                    hpPassiveBonus = min(0.28, max(0, maxHP - 30000) / 1000 * 0.007);
                    tickRamp = 1 + 0.03 * max(0, state.SalonTicks - 1);
                    dmg = localHPScaledDamage(maxHP, salonMV, "Hydro", build, localTeamContext, state, ...
                        getFieldOrDefault(build, 'SkillDMGBonus', 0) + hpPassiveBonus, hydroMult) ...
                        * salonAmp(partyIndex) * tickRamp;
                    note = sprintf('%s hit #%d', subtypeName, state.SalonTicks);
                    state = localGainFanfare(state, 14 + 3 * double(constellation >= 2));
                else
                    note = "No Ousia Salon members active";
                end

            case 'SINGER'
                if state.SalonTime > 0 && state.ArkheMode == "Pneuma"
                    state.SingerTicks = state.SingerTicks + 1;
                    [healRate, healFlat] = localSingerHeal(talent, talentLevel);
                    intervalBonus = min(0.16, max(0, maxHP - 30000) / 1000 * 0.004);
                    heal = localHealingAmount(maxHP, healRate, healFlat, build, state);
                    heal = heal * (1 + intervalBonus * 0.50);
                    note = sprintf('Singer heal #%d', state.SingerTicks);
                    state = localGainFanfare(state, 18 + 4 * double(constellation >= 2));
                else
                    note = "No Pneuma Singer active";
                end

            case 'Q'
                qMV = localTalentRowValue(talent, 21, localBurstTalentLevel(talentLevel, constellation));
                dmg = localHPScaledDamage(maxHP, qMV, "Hydro", build, localTeamContext, state, ...
                    getFieldOrDefault(build, 'BurstDMGBonus', 0), hydroMult);
                state.BurstTime = 18.0;
                state.Fanfare = min(state.FanfareCap, 150 * double(constellation >= 1));
                state.OverflowFanfare = 0;
                note = sprintf('Burst active, fanfare=%d', round(state.Fanfare));

            case 'DRAIN'
                if state.BurstTime > 0
                    gainAmount = 36 + 16 * double(constellation >= 2);
                    state = localGainFanfare(state, gainAmount);
                    note = sprintf('Fanfare manually increased to %.0f', state.Fanfare);
                else
                    note = "Burst inactive";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        totalHeal = totalHeal + heal;
        breakdown = [breakdown; {action, dmg, note}]; %#ok<AGROW>
        if heal > 0
            breakdown = [breakdown; {action + "_Heal", heal, "Healing"}]; %#ok<AGROW>
        end
        rotationTime = rotationTime + actionTime;
        [state, backgroundBreakdown, backgroundDMG, backgroundHeal] = localAdvanceStateWithBackground( ...
            state, actionTime, build, localTeamContext, talent, talentLevel, maxHP, hydroMult);
        totalDMG = totalDMG + backgroundDMG;
        totalHeal = totalHeal + backgroundHeal;
        if ~isempty(backgroundBreakdown)
            breakdown = [breakdown; backgroundBreakdown]; %#ok<AGROW>
        end
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    if totalHeal > 0
        breakdown = [breakdown; {string("Heal"), totalHeal, "Total healing"}]; %#ok<AGROW>
    end

    dps = totalDMG / rotationTime;
    audit = buildInferredReactionAudit( ...
        struct('Name', "Furina", 'Constellation', constellation, 'TalentLevel', talentLevel), ...
        actions, localTeamContext, seqFile, struct(), struct('PrimaryArchetype', "Support"));
end

function actions = localResolveRotation(seqFile)
    actions = {};
    if strlength(string(seqFile)) > 0 && exist(char(string(seqFile)), 'file') == 2
        actions = readRotationTokens(char(string(seqFile)));
    end

    if isempty(actions)
        actions = {'Q', 'E', 'Usher', 'Cheval', 'Crab', 'N1', 'N2', 'N3', 'N4', 'Heavy'};
        return;
    end

    expanded = cell(0, 1);
    for i = 1:numel(actions)
        token = string(actions{i});
        switch lower(char(token))
            case 'normal'
                expanded = [expanded; {'N1'; 'N2'; 'N3'; 'N4'}]; %#ok<AGROW>
            case 'heavy'
                expanded = [expanded; {'Heavy'}]; %#ok<AGROW>
            otherwise
                expanded{end + 1, 1} = char(token); %#ok<AGROW>
        end
    end

    if isempty(expanded)
        actions = {'Q', 'E', 'Usher', 'Cheval', 'Crab', 'N1', 'N2', 'N3', 'N4', 'Heavy'};
    else
        actions = expanded;
    end
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function [mv, note] = localNormalMV(talent, action, talentLevel)
    switch upper(char(action))
        case 'N1'
            mv = localTalentRowValue(talent, 1, talentLevel);
        case 'N2'
            mv = localTalentRowValue(talent, 2, talentLevel);
        case 'N3'
            mv = localTalentRowValue(talent, 3, talentLevel);
        otherwise
            mv = localTalentRowValue(talent, 4, talentLevel);
    end
    note = "Normal attack";
end

function [mv, subtypeName] = localSalonMV(talent, action, talentLevel)
    switch upper(char(action))
        case 'USHER'
            mv = localTalentRowValue(talent, 13, talentLevel);
            subtypeName = "Usher";
        case 'CHEVAL'
            mv = localTalentRowValue(talent, 14, talentLevel);
            subtypeName = "Chevalmarin";
        otherwise
            mv = localTalentRowValue(talent, 15, talentLevel);
            subtypeName = "Crabaletta";
    end
end

function [healRate, healFlat] = localSingerHeal(talent, talentLevel)
    rowIndex = 19;
    healRate = localTalentRowValue(talent, rowIndex, talentLevel);
    healFlat = localTalentAuxValue(talent, rowIndex, talentLevel);
end

function [dmg, heal, note, state] = localResolveC6Hit(build, teamContext, state, maxHP, hydroMult, action)
    state.C6HitsLeft = max(0, state.C6HitsLeft - 1);
    extraBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
    baseC6MV = 0.18;
    if strcmpi(char(action), 'Plunge')
        extraBonus = extraBonus + 0.10;
    end

    if state.ArkheMode == "Ousia"
        heal = maxHP * 0.04;
        dmg = localHPScaledDamage(maxHP, baseC6MV, "Hydro", build, teamContext, state, extraBonus, hydroMult);
        note = "C6 Ousia infusion";
    else
        heal = 0;
        dmg = localHPScaledDamage(maxHP, baseC6MV + 0.25, "Hydro", build, teamContext, state, extraBonus, hydroMult);
        state = localGainFanfare(state, 8);
        note = "C6 Pneuma infusion";
    end
end

function state = localGainFanfare(state, gainAmount)
    if state.BurstTime <= 0
        return;
    end

    gainMultiplier = 1 + 2.5 * double(getFieldOrDefault(state, 'Constellation', 0) >= 2);
    effectiveGain = gainAmount * gainMultiplier;
    cappedGain = min(state.FanfareCap - state.Fanfare, effectiveGain);
    state.Fanfare = min(state.FanfareCap, state.Fanfare + effectiveGain);
    if getFieldOrDefault(state, 'Constellation', 0) >= 2
        state.OverflowFanfare = min(400, state.OverflowFanfare + max(0, effectiveGain - max(cappedGain, 0)));
    end
end

function dmg = localHPScaledDamage(maxHP, mv, element, build, teamContext, state, extraBonus, damageMult)
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    dmg = maxHP * mv ...
        * localDamageBonusMultiplier(element, build, teamContext, state, extraBonus) ...
        * critMult * damageMult;
end

function dmg = localATKScaledDamage(atk, mv, element, build, teamContext, state, extraBonus, damageMult)
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    dmg = atk * mv * localDamageBonusMultiplier(element, build, teamContext, state, extraBonus) ...
        * critMult * damageMult;
end

function bonus = localDamageBonusMultiplier(element, build, teamContext, state, extraBonus)
    bonus = 1 + localElementBonus(element, build, teamContext) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
    if state.Fanfare > 0
        bonus = bonus + localFanfareDamageBonus(state);
    end
    if state.FanfareCap > 300 && state.OverflowFanfare > 0
        bonus = bonus + min(1.40, state.OverflowFanfare * 0.0035);
    end
end

function bonus = localElementBonus(element, build, teamContext)
    switch lower(char(string(element)))
        case 'hydro'
            bonus = getFieldOrDefault(build, 'HydroDMGBonus', 0) + getFieldOrDefault(teamContext, 'HydroDMGBonus', 0);
        case 'physical'
            bonus = getFieldOrDefault(build, 'PhysicalDMGBonus', 0) + getFieldOrDefault(teamContext, 'PhysicalDMGBonus', 0);
        otherwise
            bonus = getFieldOrDefault(teamContext, sprintf('%sDMGBonus', char(string(element))), 0);
    end
end

function bonus = localFanfareDamageBonus(state)
    if state.BurstTime <= 0
        bonus = 0;
        return;
    end
    bonus = state.Fanfare * 0.0025;
end

function heal = localHealingAmount(maxHP, healRate, healFlat, build, state)
    heal = (maxHP * healRate + healFlat) ...
        * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
end

function note = localArkheNote(state)
    if state.ArkheMode == "Pneuma"
        note = "Pneuma blade";
    else
        note = "Ousia thorn";
    end
end

function teamContext = localRemoveFurinaApprox(teamContext)
    furinaApproxBonus = getFieldOrDefault(teamContext, 'ApproxFurinaBonus', 0);
    teamContext.AllDMGBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', 0) - furinaApproxBonus;
    teamContext.ApproxFurinaBonus = 0;
end

function tf = localUsesExplicitCompanionActions(actions)
    if isempty(actions)
        tf = false;
        return;
    end

    actionNames = upper(string(actions(:)));
    tf = any(actionNames == "USHER" | actionNames == "CHEVAL" ...
        | actionNames == "CRAB" | actionNames == "SINGER");
end

function profile = localResolveFurinaTimelineProfile(teamContext, constellation)
    memberCount = max(1, double(getFieldOrDefault(teamContext, 'MemberCount', 1)));
    rotationDuration = max(1e-6, double(getFieldOrDefault(teamContext, 'RotationDuration', 20)));
    profile = struct( ...
        'ActionDensity', min(1, 0.45 + 0.12 * max(0, memberCount - 1)), ...
        'SupportShare', min(1, 0.30 + 0.16 * max(0, memberCount - 1)), ...
        'FanfareCoverage', 0, ...
        'SalonCoverage', 0, ...
        'HealCoverage', 0, ...
        'DrainCoverage', 0, ...
        'LoopReadiness', 0.45 + 0.10 * double(memberCount >= 3), ...
        'SharedBonusTarget', max(0, double(getFieldOrDefault(teamContext, 'ApproxFurinaBonus', 0.20))), ...
        'TimelineDerived', false, ...
        'TeamRhythm', 0.50, ...
        'AutoSalonAmp', 1.10, ...
        'AutoSalonRamp', 0.03, ...
        'AutoSingerHealBonus', 0.05, ...
        'OusiaFanfareGain', 12 + 3 * double(constellation >= 2), ...
        'PneumaFanfareGain', 15 + 4 * double(constellation >= 2));

    timelineSummary = getFieldOrDefault(teamContext, 'TimelineSummary', struct());
    activeEffects = getFieldOrDefault(teamContext, 'ActiveEffectsTable', table());
    energySummary = getFieldOrDefault(teamContext, 'EnergySummary', table());
    memberTimeline = getFieldOrDefault(teamContext, 'MemberTimelineSummary', table());
    healthEvents = getFieldOrDefault(teamContext, 'HealthEventTable', table());

    if isstruct(timelineSummary) && ~isempty(fieldnames(timelineSummary))
        occupiedTime = double(getFieldOrDefault(timelineSummary, 'MemberOccupiedTime', 0));
        swapTime = double(getFieldOrDefault(timelineSummary, 'SwapTime', 0));
        profile.ActionDensity = min(1, max(0, (occupiedTime + swapTime) / rotationDuration));
    end

    if istable(activeEffects) && height(activeEffects) > 0
        profile.FanfareCoverage = localResolveEffectCoverage(activeEffects, "Fanfare", rotationDuration);
        profile.SalonCoverage = localResolveEffectCoverage(activeEffects, "SalonMembers", rotationDuration);
        profile.TimelineDerived = true;
    end

    if istable(healthEvents) && height(healthEvents) > 0
        [healthRhythm, drainCoverage, healCoverage, healthDerived] = ...
            localResolveHealthEventRhythm(healthEvents, rotationDuration, memberCount);
        if healthDerived
            profile.DrainCoverage = drainCoverage;
            profile.HealCoverage = healCoverage;
            profile.FanfareCoverage = max(profile.FanfareCoverage, max(drainCoverage, healCoverage));
            profile.SalonCoverage = max(profile.SalonCoverage, drainCoverage);
            profile.TeamRhythm = max(profile.TeamRhythm, healthRhythm);
            profile.TimelineDerived = true;
        end
    end

    if istable(memberTimeline) && height(memberTimeline) > 0
        furinaRow = memberTimeline(string(memberTimeline.Character) == "Furina", :);
        if ~isempty(furinaRow)
            backgroundTime = max(0, double(getFieldOrDefault(furinaRow, 'BackgroundEventTime', 0)));
            profile.SupportShare = min(1, max(backgroundTime / rotationDuration, profile.SalonCoverage));
            profile.TimelineDerived = true;
        end
    end

    if istable(energySummary) && height(energySummary) > 0
        furinaEnergy = energySummary(string(energySummary.Character) == "Furina", :);
        if ~isempty(furinaEnergy)
            profile.LoopReadiness = min(1, double(furinaEnergy.EndEnergy(1)) / max(1, double(furinaEnergy.BurstCost(1))));
            profile.TimelineDerived = true;
        end
    end

    sharedBonusScale = min(1, profile.SharedBonusTarget / max(0.75 + 0.15 * double(constellation >= 1), 1e-6));
    profile.TeamRhythm = min(1, max(profile.TeamRhythm, 0.30 ...
        + 0.18 * profile.ActionDensity ...
        + 0.14 * profile.SupportShare ...
        + 0.12 * profile.FanfareCoverage ...
        + 0.10 * profile.SalonCoverage ...
        + 0.10 * profile.HealCoverage ...
        + 0.10 * profile.DrainCoverage ...
        + 0.12 * profile.LoopReadiness ...
        + 0.14 * sharedBonusScale));
    profile.AutoSalonAmp = 1.00 + 0.40 * profile.TeamRhythm;
    profile.AutoSalonRamp = 0.02 + 0.02 * profile.TeamRhythm;
    profile.AutoSingerHealBonus = 0.04 + 0.08 * profile.TeamRhythm;
    profile.OusiaFanfareGain = 9 + 8 * profile.TeamRhythm + 3 * double(constellation >= 2);
    profile.PneumaFanfareGain = 11 + 10 * profile.TeamRhythm + 4 * double(constellation >= 2);
end

function [rhythm, drainCoverage, healCoverage, derived] = localResolveHealthEventRhythm( ...
        healthEvents, rotationDuration, memberCount)
    rhythm = 0;
    drainCoverage = 0;
    healCoverage = 0;
    derived = false;
    requiredColumns = ["Time", "EventKind", "TargetCount", "TotalUnits"];
    if ~istable(healthEvents) || height(healthEvents) == 0 ...
            || ~all(ismember(requiredColumns, string(healthEvents.Properties.VariableNames)))
        return;
    end

    drainRows = healthEvents(strcmpi(string(healthEvents.EventKind), "Drain"), :);
    healRows = healthEvents(strcmpi(string(healthEvents.EventKind), "Heal"), :);
    drainCoverage = localResolveHealthEventCoverage(drainRows, rotationDuration);
    healCoverage = localResolveHealthEventCoverage(healRows, rotationDuration);
    if drainCoverage <= 0 && healCoverage <= 0
        return;
    end

    totalUnits = sum(max(0, double(healthEvents.TotalUnits)));
    eventDensity = min(1, height(healthEvents) / max(1, round(rotationDuration / 1.5)));
    unitScale = min(1, totalUnits / max(1, 8 * double(max(1, memberCount))));
    rhythm = min(1, 0.28 + 0.30 * drainCoverage + 0.24 * healCoverage + 0.10 * eventDensity + 0.08 * unitScale);
    derived = true;
end

function coverage = localResolveHealthEventCoverage(eventRows, rotationDuration)
    coverage = 0;
    if isempty(eventRows) || ~istable(eventRows) || height(eventRows) == 0
        return;
    end

    times = double(eventRows.Time);
    totalUnits = max(0, double(eventRows.TotalUnits));
    targetCounts = max(0, double(eventRows.TargetCount));
    validMask = isfinite(times) & totalUnits > 0 & targetCounts > 0;
    if ~any(validMask)
        return;
    end
    coverage = min(1, sum(min(1, totalUnits(validMask))) / max(rotationDuration / 2, 1));
end

function coverage = localResolveEffectCoverage(activeEffects, effectTag, rotationDuration)
    coverage = 0;
    if isempty(activeEffects) || ~istable(activeEffects) || height(activeEffects) == 0
        return;
    end
    if ~ismember('EffectTag', activeEffects.Properties.VariableNames) ...
            || ~ismember('StartTime', activeEffects.Properties.VariableNames) ...
            || ~ismember('EndTime', activeEffects.Properties.VariableNames)
        return;
    end

    rows = activeEffects(string(activeEffects.EffectTag) == string(effectTag), :);
    if isempty(rows)
        return;
    end

    starts = double(rows.StartTime);
    ends = double(rows.EndTime);
    validMask = isfinite(starts) & isfinite(ends) & ends > starts;
    starts = starts(validMask);
    ends = ends(validMask);
    if isempty(starts)
        return;
    end

    intervals = sortrows([starts(:), ends(:)], [1 2]);
    covered = 0;
    currentStart = intervals(1, 1);
    currentEnd = intervals(1, 2);
    for i = 2:size(intervals, 1)
        nextStart = intervals(i, 1);
        nextEnd = intervals(i, 2);
        if nextStart <= currentEnd + 1e-9
            currentEnd = max(currentEnd, nextEnd);
        else
            covered = covered + max(0, currentEnd - currentStart);
            currentStart = nextStart;
            currentEnd = nextEnd;
        end
    end
    covered = covered + max(0, currentEnd - currentStart);
    coverage = min(1, covered / max(rotationDuration, 1e-6));
end

function meta = localResolveFurinaCompanionTickMetadata(member, teamContext)
    combatMeta = inferActionCombatMetadata(member, "E", getFieldOrDefault(teamContext, 'ArchetypeInfo', struct()), teamContext);
    ousiaInterval = max(0, double(getFieldOrDefault(combatMeta, 'EffectTickInterval', 0)));
    ousiaFirstDelay = max(0, double(getFieldOrDefault(combatMeta, 'EffectFirstTickDelay', ousiaInterval)));
    if ousiaInterval <= 0
        ousiaInterval = 2.40;
    end
    if ousiaFirstDelay <= 0
        ousiaFirstDelay = ousiaInterval;
    end

    pneumaInterval = localActionTime("SINGER");
    meta = struct( ...
        'OusiaFirstTickDelay', ousiaFirstDelay, ...
        'OusiaTickInterval', ousiaInterval, ...
        'PneumaFirstTickDelay', pneumaInterval, ...
        'PneumaTickInterval', pneumaInterval);
end

function state = localResetCompanionTickDelay(state, useFirstDelay)
    if nargin < 2
        useFirstDelay = false;
    end
    if ~logical(getFieldOrDefault(state, 'AutoCompanionEnabled', false)) || state.SalonTime <= 0
        state.NextCompanionTickDelay = inf;
        return;
    end

    if state.ArkheMode == "Pneuma"
        if useFirstDelay
            state.NextCompanionTickDelay = max(0, state.PneumaFirstTickDelay);
        else
            state.NextCompanionTickDelay = max(0, state.PneumaTickInterval);
        end
    else
        if useFirstDelay
            state.NextCompanionTickDelay = max(0, state.OusiaFirstTickDelay);
        else
            state.NextCompanionTickDelay = max(0, state.OusiaTickInterval);
        end
    end
end

function [state, backgroundBreakdown, totalDMG, totalHeal] = localAdvanceStateWithBackground( ...
        state, actionTime, build, teamContext, talent, talentLevel, maxHP, hydroMult)
    totalDMG = 0;
    totalHeal = 0;
    backgroundBreakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});
    remaining = max(0, actionTime);

    while remaining > 1e-9
        nextTickDelay = localResolveNextCompanionTickDelay(state);
        if ~isfinite(nextTickDelay) || nextTickDelay > remaining + 1e-9
            state = localStepFurinaState(state, remaining);
            remaining = 0;
            break;
        end

        if nextTickDelay > 0
            state = localStepFurinaState(state, nextTickDelay);
            remaining = remaining - nextTickDelay;
        end

        [state, tickAction, tickDamage, tickHeal, tickNote] = localResolveCompanionAutoTick( ...
            state, build, teamContext, talent, talentLevel, maxHP, hydroMult);
        if tickDamage > 0
            backgroundBreakdown = [backgroundBreakdown; {tickAction, tickDamage, tickNote}]; %#ok<AGROW>
            totalDMG = totalDMG + tickDamage;
        end
        if tickHeal > 0
            backgroundBreakdown = [backgroundBreakdown; {tickAction + "_Heal", tickHeal, "Healing"}]; %#ok<AGROW>
            totalHeal = totalHeal + tickHeal;
        end
        state = localResetCompanionTickDelay(state, false);
    end
end

function nextTickDelay = localResolveNextCompanionTickDelay(state)
    nextTickDelay = inf;
    if ~logical(getFieldOrDefault(state, 'AutoCompanionEnabled', false)) || state.SalonTime <= 0
        return;
    end
    nextTickDelay = max(0, double(getFieldOrDefault(state, 'NextCompanionTickDelay', inf)));
end

function [state, actionName, dmg, heal, note] = localResolveCompanionAutoTick( ...
        state, build, teamContext, talent, talentLevel, maxHP, hydroMult)
    actionName = "SalonTick";
    dmg = 0;
    heal = 0;
    note = "";
    if state.SalonTime <= 0
        return;
    end

    profile = getFieldOrDefault(state, 'TimelineProfile', struct());
    if state.ArkheMode == "Pneuma"
        state.SingerTicks = state.SingerTicks + 1;
        [healRate, healFlat] = localSingerHeal(talent, talentLevel);
        heal = localHealingAmount(maxHP, healRate, healFlat, build, state);
        heal = heal * (1 + getFieldOrDefault(profile, 'AutoSingerHealBonus', 0));
        state = localGainFanfare(state, getFieldOrDefault(profile, 'PneumaFanfareGain', 11));
        actionName = "SingerAuto";
        note = sprintf('Singer auto heal #%d', state.SingerTicks);
        return;
    end

    state.SalonTicks = state.SalonTicks + 1;
    [salonMV, subtypeName] = localAutoSalonMV(talent, talentLevel, state.SalonTicks, state.Constellation);
    hpPassiveBonus = min(0.28, max(0, maxHP - 30000) / 1000 * 0.007);
    tickRamp = 1 + getFieldOrDefault(profile, 'AutoSalonRamp', 0.03) * max(0, state.SalonTicks - 1);
    dmg = localHPScaledDamage(maxHP, salonMV, "Hydro", build, teamContext, state, ...
        getFieldOrDefault(build, 'SkillDMGBonus', 0) + hpPassiveBonus, hydroMult) ...
        * getFieldOrDefault(profile, 'AutoSalonAmp', 1.10) * tickRamp;
    state = localGainFanfare(state, getFieldOrDefault(profile, 'OusiaFanfareGain', 9));
    note = sprintf('%s auto hit #%d', subtypeName, state.SalonTicks);
end

function [mv, subtypeName] = localAutoSalonMV(talent, talentLevel, tickIndex, constellation)
    sequenceIndex = mod(max(0, tickIndex - 1), 3) + 1;
    switch sequenceIndex
        case 1
            [mv, subtypeName] = localSalonMV(talent, "USHER", localSkillTalentLevel(talentLevel, constellation));
        case 2
            [mv, subtypeName] = localSalonMV(talent, "CHEVAL", localSkillTalentLevel(talentLevel, constellation));
        otherwise
            [mv, subtypeName] = localSalonMV(talent, "CRAB", localSkillTalentLevel(talentLevel, constellation));
    end
end

function state = localStepFurinaState(state, actionTime)
    state.SalonTime = max(0, state.SalonTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    state.C6Time = max(0, state.C6Time - actionTime);
    state.ThornCooldown = max(0, state.ThornCooldown - actionTime);
    if logical(getFieldOrDefault(state, 'AutoCompanionEnabled', false)) && isfinite(state.NextCompanionTickDelay)
        state.NextCompanionTickDelay = max(0, state.NextCompanionTickDelay - actionTime);
    end
    if state.BurstTime <= 0
        state.Fanfare = 0;
        state.OverflowFanfare = 0;
    end
    if state.C6Time <= 0
        state.C6HitsLeft = 0;
    end
    if state.SalonTime <= 0
        state.SalonTicks = 0;
        state.SingerTicks = 0;
        state.NextCompanionTickDelay = inf;
    end
end

function actionTime = localActionTime(action)
    switch upper(char(action))
        case 'E'
            actionTime = 0.70;
        case {'SWITCHPNEUMA', 'SWITCHOUSIA'}
            actionTime = 0.25;
        case 'N1'
            actionTime = 0.35;
        case 'N2'
            actionTime = 0.40;
        case 'N3'
            actionTime = 0.52;
        case 'N4'
            actionTime = 0.60;
        case {'HEAVY', 'CA'}
            actionTime = 0.75;
        case 'PLUNGE'
            actionTime = 0.95;
        case {'USHER', 'CHEVAL', 'CRAB'}
            actionTime = 1.45;
        case 'SINGER'
            actionTime = 1.80;
        case 'Q'
            actionTime = 1.20;
        case 'DRAIN'
            actionTime = 0.50;
        otherwise
            actionTime = 0.50;
    end
end

function value = localTalentRowValue(talentTable, rowIndex, talentLevel)
    if rowIndex < 1 || rowIndex > height(talentTable)
        error('Invalid Furina talent row index: %d', rowIndex);
    end

    targetLevel = min(max(round(talentLevel), 1), 15);
    for level = targetLevel:-1:1
        levelName = sprintf('Level%d', level);
        if ismember(levelName, talentTable.Properties.VariableNames)
            candidate = talentTable.(levelName)(rowIndex);
            if isnumeric(candidate) && isfinite(candidate)
                value = candidate;
                return;
            end
        end
    end

    error('No numeric Furina talent value found for row %d.', rowIndex);
end

function value = localTalentAuxValue(talentTable, rowIndex, talentLevel)
    value = localReadLevelColumn(talentTable, rowIndex, talentLevel, 'AuxLevel');
    if isfinite(value)
        return;
    end

    rawField = localResolveRawLevelField(talentLevel);
    if ismember(rawField, talentTable.Properties.VariableNames)
        rawValue = string(talentTable.(rawField)(rowIndex));
        matches = regexp(char(rawValue), '(?<num>[\d\.]+)(?<pct>%?)', 'names');
        value = localResolveRawSecondaryValue(matches);
        if isfinite(value)
            return;
        end
    end

    value = 0;
end

function value = localReadLevelColumn(talentTable, rowIndex, talentLevel, prefix)
    value = NaN;
    targetLevel = min(max(round(talentLevel), 1), 15);
    for level = targetLevel:-1:1
        levelName = sprintf('%s%d', prefix, level);
        if ismember(levelName, talentTable.Properties.VariableNames)
            candidate = talentTable.(levelName)(rowIndex);
            if isnumeric(candidate) && isfinite(candidate)
                value = candidate;
                return;
            end
        end
    end
end

function fieldName = localResolveRawLevelField(talentLevel)
    clampedLevel = min(max(round(talentLevel), 1), 15);
    if clampedLevel >= 15
        fieldName = 'RawLevel15';
    elseif clampedLevel >= 10
        fieldName = 'RawLevel10';
    else
        fieldName = 'RawLevel1';
    end
end

function value = localResolveRawSecondaryValue(matches)
    value = NaN;
    if numel(matches) < 2
        return;
    end

    raw = str2double(matches(2).num);
    if isnan(raw)
        return;
    end
    if strcmp(matches(2).pct, '%')
        value = raw / 100;
    else
        value = raw;
    end
end

function filePath = localResolveFurinaTalentFile()
    preferred = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Furina', 'talents_Furina_VerL.csv');
    if exist(preferred, 'file') == 2
        filePath = string(preferred);
    else
        filePath = resolveCharacterDataFile('Furina', 'talents');
    end
end
