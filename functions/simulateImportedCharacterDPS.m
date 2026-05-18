function [totalDMG, dps, breakdown, rotationTime] = simulateImportedCharacterDPS(characterName, build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Generic simulator for imported characters that do not yet have a
    % bespoke high-precision implementation. It maps a compact default
    % rotation onto the unified spec-driven engine and keeps the character
    % inside the same team / GUI / reaction pipeline.
    if nargin < 4 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', 'data', char(string(characterName)), ...
            sprintf('rotation_%s.txt', char(string(characterName))));
    end
    if nargin < 5 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 6 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 7 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', char(string(characterName)), 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    meta = getCharacterRegistryEntry(characterName);
    spec = localBuildImportedSpec(characterName, meta, build, teamContext);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        char(string(characterName)), build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function spec = localBuildImportedSpec(characterName, meta, build, teamContext)
    element = string(meta.Element);
    if strlength(element) == 0
        element = getCharacterElement(characterName);
    end

    weaponType = string(meta.WeaponType);
    profile = getArtifactModelProfile(characterName, build);
    scalingMode = localResolveScalingMode(characterName, build, profile);
    damagePreference = localResolveDamagePreference(characterName, weaponType, build, profile);
    reactionFlags = localResolveReactionFlags(element, build, teamContext, damagePreference, scalingMode, characterName);

    actions = struct();
    actions.N1 = localMakeAction("Normal", "x1HitDMG", damagePreference.NormalField, damagePreference.NormalElement, reactionFlags, "Normal 1");
    actions.N2 = localMakeAction("Normal", "x2HitDMG", damagePreference.NormalField, damagePreference.NormalElement, reactionFlags, "Normal 2");
    actions.N3 = localMakeAction("Normal", "x3HitDMG", damagePreference.NormalField, damagePreference.NormalElement, reactionFlags, "Normal 3");
    actions.Charged = localMakeAction("Normal", localSelectFirstExistingParam(characterName, "Normal", ...
        ["ChargedAttackDMG", "ChargedAttackFinalDMG", "ChargedAttackLoopDMG", "ChargedAttack", "AimedShotChargeLevel1", "AimedShot"]), ...
        damagePreference.ChargedField, damagePreference.ChargedElement, reactionFlags, "Charged");
    actions.Plunge = localMakeAction("Normal", localSelectFirstExistingParam(characterName, "Normal", ...
        ["HighPlungeDMG", "LowHighPlungeDMG", "PlungeDMG"]), ...
        "PlungeDMGBonus", damagePreference.NormalElement, reactionFlags, "Plunge");
    actions.E = localMakeAction("Skill", localSelectFirstExistingParam(characterName, "Skill", ...
        ["SkillDMG", "ElementalSkillDMG", "DMG", "Stage1DMG", "SpiritOrbDMG"]), ...
        "SkillDMGBonus", element, reactionFlags, "Skill");
    actions.E2 = localMakeAction("Skill", localSelectFirstExistingParam(characterName, "Skill", ...
        ["Stage2DMG", "SecondaryDMG", "FollowUpDMG", "EnhancedSkillDMG"]), ...
        "SkillDMGBonus", element, reactionFlags, "Skill follow-up");
    actions.Q = localMakeAction("Burst", localSelectFirstExistingParam(characterName, "Burst", ...
        ["BurstDMG", "ElementalBurstDMG", "RitualDMG", "WaterBallDMG", "DuskBoltDMGIncrease"]), ...
        "BurstDMGBonus", element, reactionFlags, "Burst");
    actions.QLoop = localMakeAction("Burst", localSelectFirstExistingParam(characterName, "Burst", ...
        ["WaterBallDMG", "SoundwaveCollisionDMG", "DuskBoltDMGIncrease", "AdditionalDMG", "WaveDMG"]), ...
        "BurstDMGBonus", element, reactionFlags, "Burst follow-up");

    actionNames = fieldnames(actions);
    filteredActions = struct();
    for i = 1:numel(actionNames)
        action = actions.(actionNames{i});
        if strlength(string(action.Param)) == 0
            continue;
        end
        filteredActions.(actionNames{i}) = action;
    end
    if isempty(fieldnames(filteredActions))
        error('No usable talent parameters found for imported character %s.', characterName);
    end

    defaultRotation = localBuildDefaultRotation(filteredActions, weaponType, characterName);
    spec = struct( ...
        'Element', element, ...
        'ScalingMode', scalingMode, ...
        'DefaultActionTime', 0.75, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', localBuildActionTimeMap(weaponType), ...
        'Actions', filteredActions);
end

function action = localMakeAction(talentGroup, paramName, damageField, actionElement, reactionFlags, note)
    action = struct( ...
        'TalentGroup', string(talentGroup), ...
        'Param', string(paramName), ...
        'DamageField', string(damageField), ...
        'ActionElement', string(actionElement), ...
        'BaseMultiplier', 1.00, ...
        'AllowAmplify', logical(reactionFlags.AllowAmplify), ...
        'AllowCatalyze', logical(reactionFlags.AllowCatalyze), ...
        'AllowTransformative', logical(reactionFlags.AllowTransformative), ...
        'Note', string(note));
end

function defaultRotation = localBuildDefaultRotation(actions, weaponType, characterName)
    names = string(fieldnames(actions));
    has = @(name) any(names == string(name));

    defaultRotation = cell(1, 0);
    if has("E")
        defaultRotation{end + 1} = 'E'; %#ok<AGROW>
    end
    if has("E2") && ~localLooksLikeSupportOnly(characterName)
        defaultRotation{end + 1} = 'E2'; %#ok<AGROW>
    end
    if has("Q")
        defaultRotation{end + 1} = 'Q'; %#ok<AGROW>
    end
    if has("QLoop") && ~localLooksLikeSupportOnly(characterName)
        if localLooksLikeSustainedBurst(characterName)
            defaultRotation{end + 1} = 'QLoopx4'; %#ok<AGROW>
        else
            defaultRotation{end + 1} = 'QLoopx2'; %#ok<AGROW>
        end
    end

    switch lower(char(string(weaponType)))
        case 'bow'
            if has("Charged") && localPrefersChargedBow(characterName)
                defaultRotation{end + 1} = 'Chargedx2'; %#ok<AGROW>
            elseif has("N1")
                defaultRotation{end + 1} = 'N1'; %#ok<AGROW>
                if has("N2")
                    defaultRotation{end + 1} = 'N2'; %#ok<AGROW>
                end
            end
        case 'catalyst'
            if has("N1")
                defaultRotation{end + 1} = 'N1'; %#ok<AGROW>
            end
            if has("N2")
                defaultRotation{end + 1} = 'N2'; %#ok<AGROW>
            end
            if has("Charged") && ~localLooksLikeSupportOnly(characterName)
                defaultRotation{end + 1} = 'Charged'; %#ok<AGROW>
            end
        otherwise
            if has("N1")
                defaultRotation{end + 1} = 'N1'; %#ok<AGROW>
            end
            if has("N2")
                defaultRotation{end + 1} = 'N2'; %#ok<AGROW>
            end
            if has("N3")
                defaultRotation{end + 1} = 'N3'; %#ok<AGROW>
            end
            if has("Charged") && localPrefersChargedMelee(characterName)
                defaultRotation{end + 1} = 'Charged'; %#ok<AGROW>
            end
    end

    if isempty(defaultRotation)
        defaultRotation = cellstr(names(:));
    end
end

function map = localBuildActionTimeMap(weaponType)
    map = struct('N1', 0.38, 'N2', 0.42, 'N3', 0.50, 'Charged', 0.90, 'Plunge', 0.85, ...
        'E', 0.70, 'E2', 0.85, 'Q', 1.00, 'QLoop', 0.70);
    switch lower(char(string(weaponType)))
        case 'bow'
            map.N1 = 0.42;
            map.N2 = 0.48;
            map.N3 = 0.54;
            map.Charged = 1.10;
        case 'claymore'
            map.N1 = 0.52;
            map.N2 = 0.58;
            map.N3 = 0.66;
            map.Charged = 1.15;
        case 'catalyst'
            map.N1 = 0.36;
            map.N2 = 0.40;
            map.N3 = 0.46;
            map.Charged = 0.95;
        case 'pole'
            map.N1 = 0.34;
            map.N2 = 0.38;
            map.N3 = 0.46;
            map.Charged = 0.78;
    end
end

function scalingMode = localResolveScalingMode(characterName, build, profile)
    characterName = lower(char(string(characterName)));
    if contains(characterName, 'kokomi') || contains(characterName, 'nilou')
        scalingMode = "HP";
        return;
    end
    if contains(characterName, 'albedo') || contains(characterName, 'noelle') || contains(characterName, 'yunjin')
        scalingMode = "DEF";
        return;
    end
    if strcmpi(char(string(profile.SandsMainStat)), 'EM') || getFieldOrDefault(build, 'EM', 0) >= 180
        scalingMode = "EM";
        return;
    end
    if strcmpi(char(string(profile.SandsMainStat)), 'HPBonus')
        scalingMode = "HP";
        return;
    end
    if strcmpi(char(string(profile.SandsMainStat)), 'DEFBonus')
        scalingMode = "DEF";
        return;
    end
    scalingMode = "ATK";
end

function pref = localResolveDamagePreference(characterName, weaponType, build, profile)
    pref = struct( ...
        'NormalField', "NormalDMGBonus", ...
        'ChargedField', "ChargedDMGBonus", ...
        'NormalElement', getCharacterElement(characterName), ...
        'ChargedElement', getCharacterElement(characterName));

    role = lower(char(string(characterName)));
    element = lower(char(string(getCharacterElement(characterName))));
    if contains(role, 'eula') || contains(role, 'xinyan') || contains(role, 'razor')
        pref.NormalElement = "Physical";
        pref.ChargedElement = "Physical";
        return;
    end

    if strcmpi(char(string(profile.SandsMainStat)), 'HPBonus') && strcmp(element, 'hydro')
        pref.NormalElement = "Hydro";
        pref.ChargedElement = "Hydro";
    end

    if strcmpi(char(string(weaponType)), 'bow') && localPrefersPhysicalBow(role)
        pref.NormalElement = "Physical";
    end

    if contains(role, 'kokomi')
        pref.NormalElement = "Hydro";
        pref.ChargedElement = "Hydro";
    end

    elementBonusField = char(string(element) + "DMGBonus");
    if getFieldOrDefault(build, 'PhysicalDMGBonus', 0) > 0.40 ...
            && getFieldOrDefault(build, elementBonusField, 0) <= 0
        pref.NormalElement = "Physical";
        pref.ChargedElement = "Physical";
    end
end

function flags = localResolveReactionFlags(element, build, teamContext, damagePreference, scalingMode, characterName)
    flags = struct('AllowAmplify', false, 'AllowCatalyze', false, 'AllowTransformative', false);
    element = lower(char(string(element)));
    role = lower(char(string(characterName)));

    switch element
        case {'pyro', 'hydro', 'cryo'}
            flags.AllowAmplify = ~strcmpi(char(string(damagePreference.NormalElement)), 'Physical');
        case {'electro', 'dendro'}
            flags.AllowCatalyze = true;
        case {'anemo', 'geo'}
            flags.AllowTransformative = strcmpi(char(string(scalingMode)), 'EM') || getFieldOrDefault(build, 'EM', 0) >= 120;
    end

    if contains(role, 'sucrose') || contains(role, 'kazuha') || contains(role, 'sayu')
        flags.AllowTransformative = true;
    end
    if contains(role, 'tartaglia') || contains(role, 'yoimiya') || contains(role, 'yanfei')
        flags.AllowAmplify = true;
    end
    if any(strcmp(element, {'electro', 'dendro'})) && getFieldOrDefault(teamContext, 'DendroCount', 0) + getFieldOrDefault(teamContext, 'ElectroCount', 0) >= 2
        flags.AllowCatalyze = true;
    end
end

function paramName = localSelectFirstExistingParam(characterName, skillName, candidates)
    paramName = "";
    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    talentPath = fullfile(projectRoot, 'data', char(string(characterName)), ...
        sprintf('talents_%s.csv', char(string(characterName))));
    if exist(talentPath, 'file') ~= 2
        return;
    end

    talent = readtable(talentPath, 'TextType', 'string');
    skillMask = strcmpi(talent.Skill, string(skillName));
    if ~any(skillMask)
        return;
    end

    params = string(talent.Param(skillMask));
    for i = 1:numel(candidates)
        idx = find(strcmp(params, string(candidates(i))), 1, 'first');
        if ~isempty(idx)
            paramName = params(idx);
            return;
        end
    end

    % Fallback to the first non-meta parameter in the group.
    for i = 1:numel(params)
        token = lower(char(params(i)));
        if contains(token, 'stamina') || contains(token, 'duration') || contains(token, 'cooldown') || strcmp(token, 'cd') || contains(token, 'energycost')
            continue;
        end
        paramName = params(i);
        return;
    end
end

function tf = localLooksLikeSupportOnly(characterName)
    token = lower(char(string(characterName)));
    tf = any(strcmp(token, {'bennett', 'diona', 'gorou', 'kujousara', 'mona'}));
end

function tf = localLooksLikeSustainedBurst(characterName)
    token = lower(char(string(characterName)));
    tf = any(strcmp(token, {'beidou', 'xingqiu', 'fischl', 'raidenshogun', 'mona', 'tartaglia', 'sangonomiyakokomi'}));
end

function tf = localPrefersChargedBow(characterName)
    token = lower(char(string(characterName)));
    tf = any(strcmp(token, {'ganyu', 'tighnari', 'sethos', 'amber', 'lyney'}));
end

function tf = localPrefersChargedMelee(characterName)
    token = lower(char(string(characterName)));
    tf = any(strcmp(token, {'hutao', 'keqing', 'yanfei', 'ningguang', 'arlecchino'}));
end

function tf = localPrefersPhysicalBow(roleToken)
    tf = any(strcmp(roleToken, {'aloy'}));
end
