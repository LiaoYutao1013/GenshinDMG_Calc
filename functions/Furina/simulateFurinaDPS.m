function [totalDMG, dps, breakdown, rotationTime, audit] = simulateFurinaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Furina explicit Arkhe / Salon script with approximation.
    % Arkhe mode swaps, Salon member attacks, Singer heals, burst, and C6
    % infusions are modeled as separate stateful actions.
    % Remaining approximation: party HP drift, fanfare gain, and Salon ramp
    % still use scripted team-size heuristics instead of full team timelines.
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
        'Fanfare', 150 * double(constellation >= 1), ...
        'FanfareCap', 300 + 100 * double(constellation >= 1), ...
        'OverflowFanfare', 0, ...
        'C6Time', 0, ...
        'C6HitsLeft', 0, ...
        'ThornCooldown', 0);

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
                note = "Switched to Pneuma";

            case 'SWITCHOUSIA'
                state.ArkheMode = "Ousia";
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
                state.Fanfare = min(state.FanfareCap, 150 + 75 * double(constellation >= 1));
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
        state = localAdvanceState(state, actionTime);
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

    gainMultiplier = 1 + 2.5 * double(state.FanfareCap > 300);
    effectiveGain = gainAmount * gainMultiplier;
    cappedGain = min(state.FanfareCap - state.Fanfare, effectiveGain);
    state.Fanfare = min(state.FanfareCap, state.Fanfare + effectiveGain);
    if state.FanfareCap > 300
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

function state = localAdvanceState(state, actionTime)
    state.SalonTime = max(0, state.SalonTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    state.C6Time = max(0, state.C6Time - actionTime);
    state.ThornCooldown = max(0, state.ThornCooldown - actionTime);
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
