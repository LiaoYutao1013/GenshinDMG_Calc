function teamContext = buildTeamContext(members, rotationDuration, sharedBuffs)
    if nargin < 2 || isempty(rotationDuration)
        rotationDuration = 20;
    end
    if nargin < 3 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end

    memberCount = numel(members);
    memberNames = strings(1, memberCount);
    memberElements = strings(1, memberCount);
    memberConstellations = zeros(1, memberCount);

    for i = 1:memberCount
        memberNames(i) = string(members{i}.Name);
        memberElements(i) = localGetElement(memberNames(i));
        memberConstellations(i) = getFieldOrDefault(members{i}, 'Constellation', 0);
    end

    hydroMask = memberElements == "Hydro";
    cryoMask = memberElements == "Cryo";
    hydroCryoCount = sum(hydroMask | cryoMask);

    allDMGBonus = getFieldOrDefault(sharedBuffs, 'AllDMGBonus', 0);
    allDMGBonus = allDMGBonus + getFieldOrDefault(sharedBuffs, 'ApproxFurinaBonus', 0) * double(any(memberNames == "Furina"));
    if any(memberNames == "Furina") && ~isfield(sharedBuffs, 'ApproxFurinaBonus')
        allDMGBonus = allDMGBonus + 0.60;
    end

    hydroResShred = getFieldOrDefault(sharedBuffs, 'HydroResShred', 0);
    cryoResShred = getFieldOrDefault(sharedBuffs, 'CryoResShred', 0);
    pyroResShred = getFieldOrDefault(sharedBuffs, 'PyroResShred', 0);
    cryoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'CryoCritDMGBonus', 0);

    if any(memberNames == "Escoffier")
        resSchedule = [0, 0.05, 0.10, 0.15, 0.55];
        resBonus = resSchedule(min(hydroCryoCount, 4) + 1);
        hydroResShred = hydroResShred + resBonus;
        cryoResShred = cryoResShred + resBonus;

        escoffierIndex = find(memberNames == "Escoffier", 1, 'first');
        if ~isempty(escoffierIndex) && memberConstellations(escoffierIndex) >= 1 && memberCount == 4 && hydroCryoCount == 4
            cryoCritDMGBonus = cryoCritDMGBonus + 0.60;
        end
    end

    hydroCount = sum(hydroMask);
    cryoCount = sum(cryoMask);
    hasSkirk = any(memberNames == "Skirk");

    teamContext = struct( ...
        'MemberNames', memberNames, ...
        'MemberElements', memberElements, ...
        'RotationDuration', rotationDuration, ...
        'AllDMGBonus', allDMGBonus, ...
        'FlatATK', getFieldOrDefault(sharedBuffs, 'FlatATK', 0), ...
        'ATKBonus', getFieldOrDefault(sharedBuffs, 'ATKBonus', 0), ...
        'HydroResShred', hydroResShred, ...
        'CryoResShred', cryoResShred, ...
        'PyroResShred', pyroResShred, ...
        'CryoCritDMGBonus', cryoCritDMGBonus, ...
        'HydroCryoCount', hydroCryoCount, ...
        'SkirkSkillLevelBonus', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1 && hydroCryoCount == memberCount), ...
        'SkirkDeathCrossingStacks', double(hasSkirk) * min(3, hydroCount + max(cryoCount - 1, 0)), ...
        'SkirkVoidRifts', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1) * 3 ...
    );
end

function element = localGetElement(name)
    switch lower(char(name))
        case 'skirk'
            element = "Cryo";
        case 'escoffier'
            element = "Cryo";
        case 'arlecchino'
            element = "Pyro";
        case 'furina'
            element = "Hydro";
        otherwise
            element = "Physical";
    end
end
