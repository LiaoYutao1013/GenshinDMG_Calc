function bonus = getArtifactSetBonusContribution(characterName, build, teamContext)
    % 根据角色当前穿戴的圣遗物套装，返回会直接写回面板的套装增益。
    % 这里仅处理“角色自身可直接消费”的数值收益；
    % 需要写入队伍共享上下文或敌人抗性的效果，由 getArtifactTeamBuffs 处理。
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end

    bonus = localEmptyStatStruct();
    setPieces = localCollectSetPieces(build);
    setNames = fieldnames(setPieces);

    for i = 1:numel(setNames)
        setId = string(setNames{i});
        pieces = min(5, setPieces.(setNames{i}));
        if pieces >= 2
            bonus = localAddStatStruct(bonus, localTwoPieceBonus(setId, characterName, build));
        end
        if pieces >= 4 && logical(getFieldOrDefault(build, 'ArtifactSet4Active', 1))
            bonus = localAddStatStruct(bonus, localFourPieceBonus(setId, characterName, build, teamContext));
        end
    end
end

function setPieces = localCollectSetPieces(build)
    slots = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    setPieces = struct();

    for i = 1:numel(slots)
        fieldName = sprintf('Artifact%sSet', slots{i});
        setId = string(getFieldOrDefault(build, fieldName, ""));
        if strlength(setId) == 0 || setId == "None"
            continue;
        end
        key = matlab.lang.makeValidName(char(setId));
        if ~isfield(setPieces, key)
            setPieces.(key) = 0;
        end
        setPieces.(key) = setPieces.(key) + 1;
    end

    if isempty(fieldnames(setPieces))
        legacyEntries = { ...
            char(string(getFieldOrDefault(build, 'ArtifactSet1', 'None'))), getFieldOrDefault(build, 'ArtifactSet1Pieces', 0); ...
            char(string(getFieldOrDefault(build, 'ArtifactSet2', 'None'))), getFieldOrDefault(build, 'ArtifactSet2Pieces', 0)};
        for i = 1:size(legacyEntries, 1)
            setId = string(legacyEntries{i, 1});
            pieces = legacyEntries{i, 2};
            if setId == "None" || pieces <= 0
                continue;
            end
            key = matlab.lang.makeValidName(char(setId));
            if ~isfield(setPieces, key)
                setPieces.(key) = 0;
            end
            setPieces.(key) = setPieces.(key) + pieces;
        end
    end
end

function bonus = localTwoPieceBonus(setId, characterName, build)
    bonus = localEmptyStatStruct();
    element = getCharacterElement(characterName);

    switch lower(char(setId))
        case {'atk18', 'fragmentofharmonicwhimsy', 'gladiatorsfinale', 'shimenawasreminiscence', ...
                'resolutionofsojourner', 'braveheart', 'nighttimewhispersintheechoingwoods', 'unfinishedreverie', 'adaycarvedfromrisingwinds', ...
                'disenchantmentindeepshadow', 'scarletproof', 'heartofthefurnace'}
            bonus.AtkBonus = 0.18;

        case {'hp20', 'tenacityofthemillelith', 'vourukashasglow'}
            bonus.HPBonus = 0.20;

        case 'defenderswill'
            bonus.DEFBonus = 0.30;

        case {'em80', 'wandererstroupe', 'gildeddreams', 'instructor', 'flowerofparadiselost', ...
                'nightoftheskysunveiling', 'aubadeofmorningstarandmoon'}
            bonus.EM = 80;

        case {'er20', 'emblemofseveredfate', 'silkenmoonsserenade', 'celestialgift', 'theexile', 'scholar'}
            bonus.ER = 0.20;

        case {'healing15', 'songofdayspast', 'oceanhuedclam', 'maidenbeloved'}
            bonus.HealingBonus = 0.15;

        case 'travelingdoctor'
            % Traveling Doctor 2pc increases incoming healing rather than healing output.
            % The current damage simulator does not consume incoming-healing fields,
            % so keep this set as a no-op instead of incorrectly inflating healers.

        case {'pyro15', 'crimsonwitchofflames'}
            bonus.PyroDMGBonus = 0.15;

        case {'hydro15', 'heartofdepth', 'nymphsdream'}
            bonus.HydroDMGBonus = 0.15;

        case {'cryo15', 'blizzardstrayer', 'glacierandsnowfield', 'finaleofthedeepgalleries'}
            bonus.CryoDMGBonus = 0.15;

        case {'electro15', 'thunderingfury'}
            bonus.ElectroDMGBonus = 0.15;

        case {'anemo15', 'viridescentvenerer', 'desertpavilionchronicle'}
            bonus.AnemoDMGBonus = 0.15;

        case {'geo15', 'archaicpetra'}
            bonus.GeoDMGBonus = 0.15;

        case {'dendro15', 'deepwoodmemories'}
            bonus.DendroDMGBonus = 0.15;

        case 'berserker'
            bonus.CritRate = 0.12;

        case 'martialartist'
            bonus.NormalDMGBonus = 0.15;
            bonus.ChargeDMGBonus = 0.15;
            bonus.ChargedDMGBonus = 0.15;

        case 'gambler'
            bonus.SkillDMGBonus = 0.20;

        case 'adventurer'
            bonus.FlatHP = 1000;

        case 'luckydog'
            bonus.FlatDEF = 100;

        case 'bloodstainedchivalry'
            bonus.PhysicalDMGBonus = 0.25;

        case 'retracingbolide'
            bonus.ShieldBonus = 0.35;

        case 'paleflame'
            bonus.PhysicalDMGBonus = 0.25;

        case 'goldentroupe'
            bonus.SkillDMGBonus = 0.20;

        case 'marechausseehunter'
            bonus.NormalDMGBonus = 0.15;
            bonus.ChargeDMGBonus = 0.15;
            bonus.ChargedDMGBonus = 0.15;

        case 'obsidiancodex'
            if localIsNightsoulDamageWindow(build)
                bonus = localAddCommonActionBonus(bonus, 0.15);
            end

        case 'noblesseoblige'
            bonus.BurstDMGBonus = 0.20;

        case 'huskofopulentdreams'
            bonus.DEFBonus = 0.30;

        case 'longnightsoath'
            bonus.PlungeDMGBonus = 0.25;

        otherwise
            bonus = localAddElementBonus(bonus, element, 0);
    end
end

function bonus = localFourPieceBonus(setId, characterName, build, teamContext)
    bonus = localEmptyStatStruct();

    switch lower(char(setId))
        case 'goldentroupe'
            bonus.SkillDMGBonus = 0.25;
            if logical(getFieldOrDefault(build, 'ArtifactAssumeOffFieldSkill', localIsMostlyOffFieldSkillUser(characterName)))
                bonus.SkillDMGBonus = bonus.SkillDMGBonus + 0.25;
            end

        case 'resolutionofsojourner'
            bonus.CritRate = bonus.CritRate + 0.30 * double(localUsesChargedAttacks(characterName));

        case 'braveheart'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeTargetHighHP', true))
                bonus = localAddCommonActionBonus(bonus, 0.30);
            end

        case 'berserker'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeLowHP', true))
                bonus.CritRate = bonus.CritRate + 0.24;
            end

        case 'martialartist'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeSkillCastRecently', true))
                bonus.NormalDMGBonus = bonus.NormalDMGBonus + 0.25;
                bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + 0.25;
                bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + 0.25;
            end

        case 'marechausseehunter'
            stackCount = min(3, max(0, getFieldOrDefault(build, 'ArtifactAssumeMarechausseeStacks', 3)));
            bonus.CritRate = 0.12 * stackCount;

        case 'fragmentofharmonicwhimsy'
            stackCount = max(0, getFieldOrDefault(build, 'ArtifactAssumeBondOfLifeStacks', double(localUsesBondOfLife(characterName))));
            stackCount = max(stackCount, double(localUsesBondOfLife(characterName)));
            bonus = localAddCommonActionBonus(bonus, 0.18 * max(1, stackCount));

        case 'obsidiancodex'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeObsidianActive', false))
                bonus.CritRate = 0.40;
            end

        case 'blizzardstrayer'
            cryoAura = logical(getFieldOrDefault(build, 'ArtifactAssumeCryoAura', false));
            frozen = logical(getFieldOrDefault(build, 'ArtifactAssumeFrozen', false)) ...
                || getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1;
            if cryoAura || frozen
                bonus.CritRate = bonus.CritRate + 0.20;
            end
            if frozen
                bonus.CritRate = bonus.CritRate + 0.20;
            end

        case 'thundersoother'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeElectroAura', true))
                bonus = localAddCommonActionBonus(bonus, 0.35);
            end

        case 'lavawalker'
            if logical(getFieldOrDefault(build, 'ArtifactAssumePyroAura', true))
                bonus = localAddCommonActionBonus(bonus, 0.35);
            end

        case 'heartofdepth'
            bonus.NormalDMGBonus = 0.30;
            bonus.ChargeDMGBonus = 0.30;
            bonus.ChargedDMGBonus = 0.30;

        case 'huskofopulentdreams'
            stackCount = min(4, max(0, getFieldOrDefault(build, 'ArtifactAssumeHuskStacks', 0)));
            bonus.DEFBonus = 0.06 * stackCount;
            bonus.GeoDMGBonus = 0.06 * stackCount;

        case 'wandererstroupe'
            if localUsesCatalystOrBow(characterName)
                bonus.ChargeDMGBonus = 0.35;
                bonus.ChargedDMGBonus = 0.35;
            end

        case 'gladiatorsfinale'
            if localUsesMeleeWeapon(characterName)
                bonus.NormalDMGBonus = 0.35;
            end

        case 'glacierandsnowfield'
            bonus.CryoDMGBonus = bonus.CryoDMGBonus + 0.30;

        case 'bloodstainedchivalry'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeDefeatTriggered', false))
                bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + 0.50;
                bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + 0.50;
            end

        case 'retracingbolide'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeShielded', true))
                bonus.NormalDMGBonus = bonus.NormalDMGBonus + 0.40;
                bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + 0.40;
                bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + 0.40;
            end

        case 'paleflame'
            stackCount = min(2, max(0, getFieldOrDefault(build, 'ArtifactAssumePaleFlameStacks', 2)));
            bonus.AtkBonus = bonus.AtkBonus + 0.09 * stackCount;
            if stackCount >= 2
                bonus.PhysicalDMGBonus = bonus.PhysicalDMGBonus + 0.25;
            end

        case 'shimenawasreminiscence'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeShimenawaActive', true))
                bonus.NormalDMGBonus = bonus.NormalDMGBonus + 0.50;
                bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + 0.50;
                bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + 0.50;
                bonus.PlungeDMGBonus = bonus.PlungeDMGBonus + 0.50;
            end

        case 'emblemofseveredfate'
            er = getFieldOrDefault(build, 'ER', 1.0);
            bonus.BurstDMGBonus = bonus.BurstDMGBonus + min(0.75, 0.25 * er);

        case 'gildeddreams'
            memberElements = string(getFieldOrDefault(teamContext, 'MemberElements', strings(1, 0)));
            selfElement = getCharacterElement(characterName);
            validMask = strlength(memberElements) > 0;
            memberElements = memberElements(validMask);
            sameElementCount = sum(strcmpi(cellstr(memberElements.'), char(selfElement)));
            otherMemberCount = max(0, numel(memberElements) - 1);
            sameElementOtherCount = max(0, sameElementCount - 1);
            diffElementCount = max(0, otherMemberCount - sameElementOtherCount);
            bonus.AtkBonus = bonus.AtkBonus + min(0.42, 0.14 * sameElementOtherCount);
            bonus.EM = bonus.EM + min(150, 50 * diffElementCount);

        case 'crimsonwitchofflames'
            bonus.ReactionDMGBonus = bonus.ReactionDMGBonus + 0.15;
            stackCount = min(3, max(0, getFieldOrDefault(build, 'ArtifactAssumeCrimsonWitchStacks', 1)));
            bonus.PyroDMGBonus = bonus.PyroDMGBonus + 0.075 * stackCount;

        case 'thunderingfury'
            bonus.ReactionDMGBonus = bonus.ReactionDMGBonus + 0.40;
            bonus.LunarChargedBonus = bonus.LunarChargedBonus + 0.20;

        case 'flowerofparadiselost'
            stackCount = min(4, max(0, getFieldOrDefault(build, 'ArtifactAssumeFlowerStacks', 4)));
            bonus.ReactionDMGBonus = bonus.ReactionDMGBonus + 0.40 + 0.25 * stackCount;

        case 'nymphsdream'
            stackCount = min(3, max(0, getFieldOrDefault(build, 'ArtifactAssumeNymphStacks', localDefaultNymphStacks(characterName))));
            atkBonusByStack = [0.00, 0.07, 0.16, 0.25];
            hydroBonusByStack = [0.00, 0.04, 0.09, 0.15];
            bonus.AtkBonus = bonus.AtkBonus + atkBonusByStack(stackCount + 1);
            bonus.HydroDMGBonus = bonus.HydroDMGBonus + hydroBonusByStack(stackCount + 1);

        case 'vourukashasglow'
            bonus.SkillDMGBonus = bonus.SkillDMGBonus + 0.10;
            bonus.BurstDMGBonus = bonus.BurstDMGBonus + 0.10;
            stackCount = min(5, max(0, getFieldOrDefault(build, 'ArtifactAssumeVourukashaStacks', 0)));
            amp = 0.08 * stackCount;
            bonus.SkillDMGBonus = bonus.SkillDMGBonus + amp;
            bonus.BurstDMGBonus = bonus.BurstDMGBonus + amp;

        case 'vermillionhereafter'
            hpDropStacks = min(4, max(0, getFieldOrDefault(build, 'ArtifactAssumeVermillionHPDropStacks', 4)));
            bonus.AtkBonus = bonus.AtkBonus + 0.08 + 0.10 * hpDropStacks;

        case 'echoesofanoffering'
            procRate = max(0, min(1, getFieldOrDefault(build, 'ArtifactAssumeEchoesProcRate', 0.36)));
            bonus.NormalDMGBonus = bonus.NormalDMGBonus + 0.70 * procRate;

        case 'desertpavilionchronicle'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeDesertPavilionActive', true))
                bonus.NormalDMGBonus = bonus.NormalDMGBonus + 0.40;
                bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + 0.40;
                bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + 0.40;
                bonus.PlungeDMGBonus = bonus.PlungeDMGBonus + 0.40;
            end

        case 'nighttimewhispersintheechoingwoods'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeCrystallizeShield', true)) ...
                    || logical(getFieldOrDefault(teamContext, 'GeoReactionReady', false)) ...
                    || logical(getFieldOrDefault(teamContext, 'LunarCrystallizeEnabled', false))
                bonus.GeoDMGBonus = bonus.GeoDMGBonus + 0.50;
            else
                bonus.GeoDMGBonus = bonus.GeoDMGBonus + 0.20;
            end

        case 'unfinishedreverie'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeBurningNearby', false)) ...
                    || (getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1 && getFieldOrDefault(teamContext, 'DendroCount', 0) >= 1)
                bonus = localAddCommonActionBonus(bonus, 0.50);
            end

        case 'longnightsoath'
            stackCount = min(5, max(0, getFieldOrDefault(build, 'ArtifactAssumeLongNightStacks', 5)));
            bonus.PlungeDMGBonus = bonus.PlungeDMGBonus + 0.15 * stackCount;

        case 'finaleofthedeepgalleries'
            zeroEnergy = logical(getFieldOrDefault(build, 'ArtifactAssumeZeroEnergy', true));
            burstMode = logical(getFieldOrDefault(build, 'ArtifactAssumeDeepGalleryBurstMode', false));
            if zeroEnergy
                if burstMode
                    bonus.BurstDMGBonus = bonus.BurstDMGBonus + 0.60;
                else
                    bonus.NormalDMGBonus = bonus.NormalDMGBonus + 0.60;
                end
            end

        case 'adaycarvedfromrisingwinds'
            bonus.AtkBonus = bonus.AtkBonus + 0.25;
            if logical(getFieldOrDefault(build, 'ArtifactAssumeWitchHomeworkComplete', false))
                bonus.CritRate = bonus.CritRate + 0.20;
            end

        case 'disenchantmentindeepshadow'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeTargetSuperconducted', false))
                bonus.CritRate = bonus.CritRate + 0.16;
            end

        case 'scarletproof'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeStellarSwirlActive', false))
                bonus.CritRate = bonus.CritRate + 0.16;
                bonus.StellarSwirlBonus = bonus.StellarSwirlBonus + 0.40;
            end

        case 'heartofthefurnace'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeStellarGlimmerActive', false))
                bonus.AtkBonus = bonus.AtkBonus + 0.12;
            end

        otherwise
            % 复杂或尚未显式建模的 4 件套，在 registry 中保留展示信息，
            % 这里先不对角色面板做错误近似。
    end
end

function bonus = localAddCommonActionBonus(bonus, value)
    bonus.NormalDMGBonus = bonus.NormalDMGBonus + value;
    bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + value;
    bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + value;
    bonus.PlungeDMGBonus = bonus.PlungeDMGBonus + value;
    bonus.SkillDMGBonus = bonus.SkillDMGBonus + value;
    bonus.BurstDMGBonus = bonus.BurstDMGBonus + value;
end

function bonus = localAddElementBonus(bonus, element, value)
    switch lower(char(string(element)))
        case 'pyro'
            bonus.PyroDMGBonus = bonus.PyroDMGBonus + value;
        case 'hydro'
            bonus.HydroDMGBonus = bonus.HydroDMGBonus + value;
        case 'cryo'
            bonus.CryoDMGBonus = bonus.CryoDMGBonus + value;
        case 'electro'
            bonus.ElectroDMGBonus = bonus.ElectroDMGBonus + value;
        case 'anemo'
            bonus.AnemoDMGBonus = bonus.AnemoDMGBonus + value;
        case 'geo'
            bonus.GeoDMGBonus = bonus.GeoDMGBonus + value;
        case 'dendro'
            bonus.DendroDMGBonus = bonus.DendroDMGBonus + value;
    end
end

function merged = localAddStatStruct(merged, incoming)
    fields = fieldnames(incoming);
    for i = 1:numel(fields)
        fieldName = fields{i};
        merged.(fieldName) = getFieldOrDefault(merged, fieldName, 0) + getFieldOrDefault(incoming, fieldName, 0);
    end
end

function tf = localUsesBondOfLife(characterName)
    tf = any(strcmpi(char(string(characterName)), {'Arlecchino'}));
end

function tf = localIsNightsoulDamageWindow(build)
    tf = logical(getFieldOrDefault(build, 'ArtifactAssumeNightsoulBlessing', false)) ...
        || logical(getFieldOrDefault(build, 'ArtifactAssumeObsidianActive', false));
end

function stackCount = localDefaultNymphStacks(characterName)
    switch lower(char(string(characterName)))
        case {'columbina', 'mualani', 'neuvillette'}
            stackCount = 3;
        otherwise
            stackCount = 0;
    end
end

function tf = localUsesChargedAttacks(characterName)
    tf = localUsesCatalystOrBow(characterName);
end

function tf = localIsMostlyOffFieldSkillUser(characterName)
    tf = any(strcmpi(char(string(characterName)), { ...
        'Furina', 'Escoffier', 'Citlali', 'Chevreuse', 'Iansan', ...
        'Nicole', 'Lauma', 'Linnea', 'Nefer', 'Flins', 'Zibai', 'Xianyun'}));
end

function tf = localUsesCatalystOrBow(characterName)
    switch lower(char(string(characterName)))
        case {'chasca', 'citlali', 'lauma', 'linnea', 'mualani', 'nefer', ...
                'neuvillette', 'nicole', 'varesa', 'xianyun'}
            tf = true;
        otherwise
            tf = false;
    end
end

function tf = localUsesMeleeWeapon(characterName)
    switch lower(char(string(characterName)))
        case {'arlecchino', 'durin', 'escoffier', 'flins', 'furina', 'iansan', ...
                'ineffa', 'mavuika', 'nilou', 'skirk', 'xilonen', 'zibai', ...
                'chevreuse'}
            tf = true;
        otherwise
            tf = false;
    end
end

function stats = localEmptyStatStruct()
    stats = struct( ...
        'AtkBonus', 0, ...
        'FlatATK', 0, ...
        'HPBonus', 0, ...
        'FlatHP', 0, ...
        'DEFBonus', 0, ...
        'FlatDEF', 0, ...
        'ER', 0, ...
        'EM', 0, ...
        'CritRate', 0, ...
        'CritDMG', 0, ...
        'PhysicalDMGBonus', 0, ...
        'PyroDMGBonus', 0, ...
        'HydroDMGBonus', 0, ...
        'CryoDMGBonus', 0, ...
        'ElectroDMGBonus', 0, ...
        'AnemoDMGBonus', 0, ...
        'GeoDMGBonus', 0, ...
        'DendroDMGBonus', 0, ...
        'NormalDMGBonus', 0, ...
        'ChargeDMGBonus', 0, ...
        'ChargedDMGBonus', 0, ...
        'PlungeDMGBonus', 0, ...
        'SkillDMGBonus', 0, ...
        'BurstDMGBonus', 0, ...
        'HealingBonus', 0, ...
        'ReactionDMGBonus', 0, ...
        'ShieldBonus', 0, ...
        'LunarChargedBonus', 0, ...
        'StellarSwirlBonus', 0, ...
        'ResShred', 0);
end
