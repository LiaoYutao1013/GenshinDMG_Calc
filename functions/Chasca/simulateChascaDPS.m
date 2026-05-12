function [totalDMG, dps, breakdown, rotationTime] = simulateChascaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Chasca high-detail simulator.
    % Core modeling scope:
    % 1. Six-shell Multitarget Fire with LIFO firing order;
    % 2. Base conversion on shells 4/5/6 plus A1/C1 extra conversion on 3/2;
    % 3. Team-driven converted element selection and reaction priority;
    % 4. Burst follow-up, C2 AoE shell, C4 extra burst shell, and C6 crit state.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Chasca', 'rotation_Chasca.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Chasca', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Chasca');
    base = readtable(fullfile(dataFolder, 'characters_Chasca.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Chasca.csv'));
    actions = localResolveRotation(seqFile, constellation);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    conversionData = localResolveConversionData(teamContext);

    state = struct( ...
        'NightsoulTime', 0, ...
        'ShellsLoaded', 0, ...
        'BurstBuffTime', 0, ...
        'BurstWindowActive', false, ...
        'C6Ready', constellation >= 6, ...
        'ConversionData', conversionData, ...
        'RotationMode', string(actions.Mode));

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions.Tokens)
        action = actions.Tokens{i};
        actionTime = localActionTime(action, constellation);
        actionDMG = 0;
        note = "";
        extraRows = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
            'VariableNames', {'Action', 'Damage', 'Note'});

        switch action
            case 'E'
                skillLevel = localSkillTalentLevel(talentLevel, constellation);
                mv = getTalentValue(talent, 'Skill', 'TapATK', skillLevel);
                actionDMG = localDirectDamage('Anemo', atk, mv, build, teamContext, enemy, state, getFieldOrDefault(build, 'SkillDMGBonus', 0), constellation);
                state.NightsoulTime = getTalentValue(talent, 'Skill', 'NightsoulDuration', talentLevel);
                state.ShellsLoaded = getTalentValue(talent, 'Skill', 'NightsoulInit', talentLevel);
                note = sprintf('Nightsoul enter, shells=%d, converted=%s', state.ShellsLoaded, localJoinPool(state.ConversionData.MemberElements));

            case 'Charge4'
                if state.NightsoulTime > 0
                    state.ShellsLoaded = 6;
                    note = "Full six-shell charge";
                else
                    note = "Nightsoul inactive";
                end

            case 'Charge2'
                if state.NightsoulTime > 0
                    state.ShellsLoaded = max(state.ShellsLoaded, 2);
                    note = "Short charge";
                else
                    note = "Nightsoul inactive";
                end

            case 'Aimed'
                mv = getTalentValue(talent, 'Normal', 'AimedShotATK', talentLevel);
                actionDMG = localDirectDamage('Anemo', atk, mv, build, teamContext, enemy, state, getFieldOrDefault(build, 'ChargedDMGBonus', 0), constellation);
                note = "Aimed shot";

            case 'Multi'
                if state.NightsoulTime > 0 && state.ShellsLoaded >= 6
                    [actionDMG, note, extraRows, state] = localResolveMultitargetFire( ...
                        atk, em, build, enemy, teamContext, talent, talentLevel, constellation, state);
                else
                    note = "Multitarget Fire not ready";
                end

            case 'Burst'
                burstLevel = localBurstTalentLevel(talentLevel, constellation);
                mv = getTalentValue(talent, 'Burst', 'SoulReaperShellATK', burstLevel);
                actionDMG = localDirectDamage('Anemo', atk, mv, build, teamContext, enemy, state, getFieldOrDefault(build, 'BurstDMGBonus', 0), constellation);
                note = "Burst cast";

                if ~isempty(state.ConversionData.UniqueElements)
                    followMV = getTalentValue(talent, 'Burst', 'SpiritReinsRadiantShellATK', burstLevel);
                    burstElements = localResolveBurstConvertedElements(state.ConversionData);
                    [followDMG, followRows] = localResolveConvertedVolley( ...
                        atk, em, build, enemy, teamContext, state, followMV, burstElements, ...
                        getFieldOrDefault(build, 'BurstDMGBonus', 0), "BurstFollow", true, constellation);
                    actionDMG = actionDMG + followDMG;
                    extraRows = [extraRows; followRows]; %#ok<AGROW>
                end

                if constellation >= 2 && ~isempty(state.ConversionData.UniqueElements)
                    c2MV = getTalentValue(talent, 'Burst', 'C2SpiritReinsRadiantShellATK', burstLevel);
                    c2DMG = localAoeConvertedDamage(atk, c2MV, build, teamContext, enemy, state, state.ConversionData.UniqueElements{1}, getFieldOrDefault(build, 'BurstDMGBonus', 0), constellation);
                    actionDMG = actionDMG + c2DMG;
                    extraRows = [extraRows; {string("BurstC2"), c2DMG, "C2 burst spirit reins shell"}]; %#ok<AGROW>
                end

                state.BurstBuffTime = 15.0;
                state.BurstWindowActive = true;
                if constellation >= 6
                    state.C6Ready = true;
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + actionDMG;
        if ~isempty(extraRows)
            breakdown = [breakdown; extraRows]; %#ok<AGROW>
        end
        breakdown = [breakdown; {string(action), actionDMG, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;
end

function actions = localResolveRotation(seqFile, constellation)
    rawTokens = readRotationTokens(seqFile);
    mode = "Manual";
    if isempty(rawTokens)
        rawTokens = {'AUTO'};
    end

    if numel(rawTokens) == 1 && strcmpi(rawTokens{1}, 'AUTO')
        mode = "Auto";
        if constellation >= 6
            tokens = {'E', 'Charge4', 'Multi', 'Charge4', 'Multi', 'Charge4', 'Multi', 'Charge4', 'Multi'};
        else
            tokens = {'E', 'Charge4', 'Multi', 'Charge4', 'Multi', 'Charge4', 'Multi', 'Charge4', 'Multi', 'Burst'};
        end
    else
        tokens = rawTokens;
    end

    actions = struct('Tokens', {tokens}, 'Mode', mode);
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function [dmg, note, extraRows, state] = localResolveMultitargetFire(atk, em, build, enemy, teamContext, talent, talentLevel, constellation, state)
    shellPlan = localBuildMultitargetShellPlan(talent, state.ConversionData, constellation);
    fireOrder = numel(shellPlan):-1:1;
    chargedBonus = getFieldOrDefault(build, 'ChargedDMGBonus', 0);
    [dmg, extraRows, firedConvertedElements] = localResolveShellPlan( ...
        atk, em, build, enemy, teamContext, state, talent, talentLevel, shellPlan, fireOrder, chargedBonus, "MultiShell", constellation);

    note = sprintf('Multitarget Fire, converted EV %.2f', sum([shellPlan.ConvertedWeight]));

    if constellation >= 2 && ~isempty(firedConvertedElements)
        c2MV = getTalentValue(talent, 'Charged', 'C2SpiritReinsShellATK', talentLevel);
        c2Element = firedConvertedElements{1};
        c2DMG = localAoeConvertedDamage(atk, c2MV, build, teamContext, enemy, state, c2Element, chargedBonus, constellation);
        dmg = dmg + c2DMG;
        extraRows = [extraRows; {string("MultiC2"), c2DMG, sprintf('C2 AoE %s', c2Element)}]; %#ok<AGROW>
    end

    if constellation >= 4 && state.BurstWindowActive && ~isempty(state.ConversionData.UniqueElements)
        c4MV = getTalentValue(talent, 'Burst', 'C4SpiritReinsRadiantShellATK', localBurstTalentLevel(talentLevel, constellation));
        c4Elements = localResolveBurstConvertedElements(state.ConversionData);
        [c4DMG, c4Rows] = localResolveConvertedVolley( ...
            atk, em, build, enemy, teamContext, state, c4MV, c4Elements, ...
            chargedBonus, "MultiC4", true, constellation);
        dmg = dmg + c4DMG;
        extraRows = [extraRows; c4Rows]; %#ok<AGROW>
    end

    if constellation >= 6
        state.C6Ready = false;
    end
    state.ShellsLoaded = 0;
end

function shellPlan = localBuildMultitargetShellPlan(talent, conversionData, constellation)
    shellPlan = repmat(localShellDescriptor("Anemo", 0), 1, 6);
    if conversionData.EligibleCount <= 0
        return;
    end

    memberElements = conversionData.MemberElements;
    baseConvertedCount = min(3, numel(memberElements));
    for idx = 1:baseConvertedCount
        shellSlot = 7 - idx;
        shellPlan(shellSlot) = localShellDescriptor(string(memberElements{idx}), 1.0);
    end

    extraChance = localExtraConversionChance(conversionData.EligibleCount);
    shellPlan(3) = localShellDescriptor(string(conversionData.UniqueElements), extraChance);

    if constellation >= 1
        shellPlan(2) = localShellDescriptor(string(conversionData.UniqueElements), extraChance);
    end
end

function shell = localShellDescriptor(element, convertedWeight)
    shell = struct( ...
        'Element', string(element), ...
        'ConvertedWeight', convertedWeight, ...
        'Reaction', "");
end

function [dmg, rows, firedConvertedElements] = localResolveShellPlan(atk, em, build, enemy, teamContext, state, talent, talentLevel, shellPlan, fireOrder, extraBonus, tagPrefix, constellation)
    rows = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});
    dmg = 0;
    firedConvertedElements = {};
    convertedCountEV = sum([shellPlan.ConvertedWeight]);
    convertedA4Bonus = localA4Bonus(convertedCountEV);

    for i = 1:numel(fireOrder)
        shellIndex = fireOrder(i);
        shell = shellPlan(shellIndex);
        [shellDMG, hasConvertedContribution, representativeElement] = localExpectedShellDamage( ...
            atk, em, build, enemy, teamContext, state, talent, talentLevel, shell, convertedA4Bonus, extraBonus, constellation);
        dmg = dmg + shellDMG;
        rows = [rows; {string(sprintf('%s%d', tagPrefix, i)), shellDMG, localShellNote(shell)}]; %#ok<AGROW>
        if hasConvertedContribution
            firedConvertedElements{end + 1} = representativeElement; %#ok<AGROW>
        end
    end
end

function [dmg, hasConvertedContribution, representativeElement] = localExpectedShellDamage(atk, em, build, enemy, teamContext, state, talent, talentLevel, shell, convertedA4Bonus, extraBonus, constellation)
    convertedWeight = min(max(shell.ConvertedWeight, 0), 1);
    anemoMV = getTalentValue(talent, 'Charged', 'AnemoShellATK', talentLevel);
    convertedMV = getTalentValue(talent, 'Charged', 'ConvertedShellATK', talentLevel);
    anemoDMG = localDirectDamage('Anemo', atk, anemoMV, build, teamContext, enemy, state, extraBonus, constellation);
    representativeElement = 'Anemo';

    if convertedWeight <= 0
        dmg = anemoDMG;
        hasConvertedContribution = false;
        return;
    end

    convertedExtraBonus = extraBonus + convertedA4Bonus;
    options = cellstr(shell.Element);
    optionDMG = zeros(1, numel(options));
    for i = 1:numel(options)
        optionElement = options{i};
        reaction = localPreferredReaction(optionElement, teamContext);
        if reaction == "Vaporize"
            optionDMG(i) = localAmplifiedDamage(optionElement, atk, convertedMV, build, teamContext, enemy, state, convertedExtraBonus, 2.0, em, constellation);
        elseif reaction == "Melt"
            optionDMG(i) = localAmplifiedDamage(optionElement, atk, convertedMV, build, teamContext, enemy, state, convertedExtraBonus, 1.5, em, constellation);
        else
            optionDMG(i) = localDirectDamage(optionElement, atk, convertedMV, build, teamContext, enemy, state, convertedExtraBonus, constellation);
        end
    end
    convertedDMG = mean(optionDMG);
    representativeElement = options{1};

    dmg = convertedWeight * convertedDMG + (1 - convertedWeight) * anemoDMG;
    hasConvertedContribution = true;
end

function [dmg, rows] = localResolveConvertedVolley(atk, em, build, enemy, teamContext, state, mv, elements, extraBonus, tagPrefix, allowReaction, constellation)
    rows = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});
    dmg = 0;
    for i = 1:numel(elements)
        element = string(elements{i});
        if allowReaction
            reaction = localPreferredReaction(element, teamContext);
        else
            reaction = "";
        end

        if reaction == "Vaporize"
            shellDMG = localAmplifiedDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, 2.0, em, constellation);
        elseif reaction == "Melt"
            shellDMG = localAmplifiedDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, 1.5, em, constellation);
        else
            shellDMG = localDirectDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, constellation);
        end
        dmg = dmg + shellDMG;
        rows = [rows; {string(sprintf('%s%d', tagPrefix, i)), shellDMG, sprintf('%s shell', element)}]; %#ok<AGROW>
    end
end

function conversionData = localResolveConversionData(teamContext)
    memberElements = {};
    uniqueElements = {};
    orderedPairs = { ...
        'Pyro', getFieldOrDefault(teamContext, 'PyroCount', 0); ...
        'Hydro', getFieldOrDefault(teamContext, 'HydroCount', 0); ...
        'Cryo', getFieldOrDefault(teamContext, 'CryoCount', 0); ...
        'Electro', getFieldOrDefault(teamContext, 'ElectroCount', 0)};

    for i = 1:size(orderedPairs, 1)
        element = orderedPairs{i, 1};
        count = orderedPairs{i, 2};
        if count > 0
            uniqueElements{end + 1} = element; %#ok<AGROW>
            for k = 1:count
                memberElements{end + 1} = element; %#ok<AGROW>
            end
        end
    end

    conversionData = struct( ...
        'MemberElements', {memberElements}, ...
        'UniqueElements', {uniqueElements}, ...
        'EligibleCount', numel(memberElements), ...
        'UniqueCount', numel(uniqueElements));
end

function chance = localExtraConversionChance(eligibleCount)
    chance = min(1.0, max(0, eligibleCount / 3));
end

function burstElements = localResolveBurstConvertedElements(conversionData)
    burstElements = {};
    if conversionData.EligibleCount <= 0
        return;
    end

    guaranteedCount = min(6, 2 * conversionData.EligibleCount);
    for i = 1:guaranteedCount
        burstElements{end + 1} = conversionData.MemberElements{1 + mod(i - 1, numel(conversionData.MemberElements))}; %#ok<AGROW>
    end
end

function reaction = localPreferredReaction(element, teamContext)
    hasPyro = getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1;
    hasHydro = getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1;
    hasCryo = getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1;
    switch lower(char(element))
        case 'hydro'
            if hasPyro
                reaction = "Vaporize";
            else
                reaction = "";
            end
        case 'pyro'
            if hasCryo
                reaction = "Melt";
            elseif hasHydro
                reaction = "Vaporize";
            else
                reaction = "";
            end
        case 'cryo'
            if hasPyro
                reaction = "Melt";
            else
                reaction = "";
            end
        otherwise
            reaction = "";
    end
end

function bonus = localA4Bonus(convertedCountEV)
    if convertedCountEV >= 3
        bonus = 0.65;
    elseif convertedCountEV >= 2
        bonus = 0.35;
    elseif convertedCountEV >= 1
        bonus = 0.15;
    else
        bonus = 0;
    end
end

function text = localJoinPool(pool)
    if isempty(pool)
        text = 'None';
    else
        text = strjoin(string(pool), '/');
    end
end

function note = localShellNote(shell)
    if shell.ConvertedWeight <= 0
        note = "Anemo shell";
    elseif shell.ConvertedWeight >= 0.999
        note = sprintf('Converted %s shell', strjoin(cellstr(shell.Element), '/'));
    else
        note = sprintf('Expected %.0f%% %s conversion', shell.ConvertedWeight * 100, strjoin(cellstr(shell.Element), '/'));
    end
end

function dmg = localDirectDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, constellation)
    [critRate, critDMG] = localCritState(build, constellation, state);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmgBonus = localElementBonus(element, build, teamContext, state, extraBonus);
    resShred = localElementResShred(element, build, teamContext);
    dmg = atk * mv * dmgBonus * critMult * calcDamageMultiplier(90, enemy, resShred);
end

function dmg = localAmplifiedDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, reactionMultiplier, em, constellation)
    dmg = localDirectDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, constellation);
    ampBonus = 1 + 2.78 * em / (em + 1400);
    dmg = dmg * reactionMultiplier * ampBonus;
end

function dmg = localAoeConvertedDamage(atk, mv, build, teamContext, enemy, state, element, extraBonus, constellation)
    dmg = localDirectDamage(element, atk, mv, build, teamContext, enemy, state, extraBonus, constellation);
end

function [critRate, critDMG] = localCritState(build, constellation, state)
    critRate = getFieldOrDefault(build, 'CritRate', 0);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
    if constellation >= 6 && state.C6Ready
        critDMG = critDMG + 1.20;
    end
end

function dmgBonus = localElementBonus(element, build, teamContext, state, extraBonus)
    sharedBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', getFieldOrDefault(teamContext, 'SharedAllDMGBonus', 0));
    anemoFallback = getFieldOrDefault(build, 'AnemoDMGBonus', 0);

    switch lower(char(element))
        case 'anemo'
            elementBonus = getFieldOrDefault(build, 'AnemoDMGBonus', 0);
        case 'pyro'
            elementBonus = getFieldOrDefault(build, 'PyroDMGBonus', anemoFallback);
        case 'hydro'
            elementBonus = getFieldOrDefault(build, 'HydroDMGBonus', anemoFallback);
        case 'cryo'
            elementBonus = getFieldOrDefault(build, 'CryoDMGBonus', anemoFallback);
        case 'electro'
            elementBonus = getFieldOrDefault(build, 'ElectroDMGBonus', anemoFallback);
        otherwise
            elementBonus = 0;
    end

    dmgBonus = 1 + elementBonus + sharedBonus + extraBonus;
    if state.BurstBuffTime > 0
        dmgBonus = dmgBonus + 0.12;
    end
end

function resShred = localElementResShred(element, build, teamContext)
    resShred = getFieldOrDefault(build, 'ResShred', 0);
    switch lower(char(element))
        case 'pyro'
            resShred = resShred + getFieldOrDefault(teamContext, 'PyroResShred', 0);
        case 'hydro'
            resShred = resShred + getFieldOrDefault(teamContext, 'HydroResShred', 0);
        case 'cryo'
            resShred = resShred + getFieldOrDefault(teamContext, 'CryoResShred', 0);
        case 'electro'
            resShred = resShred + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
    end
end

function state = localAdvanceState(state, actionTime)
    state.NightsoulTime = max(0, state.NightsoulTime - actionTime);
    state.BurstBuffTime = max(0, state.BurstBuffTime - actionTime);
    if state.BurstBuffTime <= 0
        state.BurstWindowActive = false;
    end
    if state.NightsoulTime <= 0
        state.ShellsLoaded = 0;
    end
end

function actionTime = localActionTime(action, constellation)
    switch action
        case 'E'
            actionTime = 0.63;
        case 'Charge4'
            actionTime = 1.65 - 0.15 * double(constellation >= 6);
        case 'Charge2'
            actionTime = 0.55;
        case 'Aimed'
            actionTime = 0.72;
        case 'Multi'
            actionTime = 1.18;
        case 'Burst'
            actionTime = 1.20;
        otherwise
            actionTime = 0.50;
    end
end
