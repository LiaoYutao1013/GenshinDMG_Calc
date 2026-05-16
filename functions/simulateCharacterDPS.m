function result = simulateCharacterDPS(memberCfg, enemy, teamContext)
    % Unified single-character dispatch entry used by both standalone
    % analysis scripts and the team simulator.
    initProjectPaths();

    if nargin < 3 || isempty(teamContext)
        teamContext = struct('RotationDuration', 20);
    end

    name = lower(strtrim(char(string(memberCfg.Name))));
    compiledBuild = compileArtifactSetBonuses(memberCfg.Name, memberCfg.Build, teamContext);
    if nargin >= 3 && ~isempty(teamContext)
        memberCfg.EnemyState = createEnemyState(enemy, teamContext, getCharacterElement(memberCfg.Name));
    elseif ~isfield(memberCfg, 'EnemyState') || isempty(memberCfg.EnemyState)
        memberCfg.EnemyState = createEnemyState(enemy, teamContext, getCharacterElement(memberCfg.Name));
    end
    memberTeamContext = teamContext;
    memberTeamContext = localApplyElementSpecificTeamBonuses(memberTeamContext, memberCfg.Name);
    memberTeamContext.EnemyState = memberCfg.EnemyState;

    switch name
        case 'skirk'
            [totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'escoffier'
            [totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'arlecchino'
            [totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'furina'
            [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'columbina'
            [totalDMG, dps, breakdown, rotationTime] = simulateColumbinaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'chasca'
            [totalDMG, dps, breakdown, rotationTime] = simulateChascaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lauma'
            [totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'ineffa'
            [totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'linnea'
            [totalDMG, dps, breakdown, rotationTime] = simulateLinneaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nilou'
            [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nefer'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'flins'
            [totalDMG, dps, breakdown, rotationTime] = simulateFlinsDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'zibai'
            [totalDMG, dps, breakdown, rotationTime] = simulateZibaiDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'mualani'
            [totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'mavuika'
            [totalDMG, dps, breakdown, rotationTime] = simulateMavuikaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'citlali'
            [totalDMG, dps, breakdown, rotationTime] = simulateCitlaliDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'xilonen'
            [totalDMG, dps, breakdown, rotationTime] = simulateXilonenDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'neuvillette'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeuvilletteDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'chevreuse'
            [totalDMG, dps, breakdown, rotationTime] = simulateChevreuseDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'iansan'
            [totalDMG, dps, breakdown, rotationTime] = simulateIansanDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'varesa'
            [totalDMG, dps, breakdown, rotationTime] = simulateVaresaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'durin'
            [totalDMG, dps, breakdown, rotationTime] = simulateDurinDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nicole'
            [totalDMG, dps, breakdown, rotationTime] = simulateNicoleDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case {'kamisatoayaka', 'ayaka'}
            [totalDMG, dps, breakdown, rotationTime] = simulateKamisatoAyakaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'jean'
            [totalDMG, dps, breakdown, rotationTime] = simulateJeanDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lisa'
            [totalDMG, dps, breakdown, rotationTime] = simulateLisaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'barbara'
            [totalDMG, dps, breakdown, rotationTime] = simulateBarbaraDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'kaeya'
            [totalDMG, dps, breakdown, rotationTime] = simulateKaeyaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'diluc'
            [totalDMG, dps, breakdown, rotationTime] = simulateDilucDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'razor'
            [totalDMG, dps, breakdown, rotationTime] = simulateRazorDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'amber'
            [totalDMG, dps, breakdown, rotationTime] = simulateAmberDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'venti'
            [totalDMG, dps, breakdown, rotationTime] = simulateVentiDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'xiangling'
            [totalDMG, dps, breakdown, rotationTime] = simulateXianglingDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'hutao'
            [totalDMG, dps, breakdown, rotationTime] = simulateHutaoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'charlotte'
            [totalDMG, dps, breakdown, rotationTime] = simulateCharlotteDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'wriothesley'
            [totalDMG, dps, breakdown, rotationTime] = simulateWriothesleyDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'freminet'
            [totalDMG, dps, breakdown, rotationTime] = simulateFreminetDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lyney'
            [totalDMG, dps, breakdown, rotationTime] = simulateLyneyDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lynette'
            [totalDMG, dps, breakdown, rotationTime] = simulateLynetteDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'baizhu'
            [totalDMG, dps, breakdown, rotationTime] = simulateBaizhuDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'kaveh'
            [totalDMG, dps, breakdown, rotationTime] = simulateKavehDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'mika'
            [totalDMG, dps, breakdown, rotationTime] = simulateMikaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'dehya'
            [totalDMG, dps, breakdown, rotationTime] = simulateDehyaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'alhaitham'
            [totalDMG, dps, breakdown, rotationTime] = simulateAlhaithamDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'yaoyao'
            [totalDMG, dps, breakdown, rotationTime] = simulateYaoyaoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'faruzan'
            [totalDMG, dps, breakdown, rotationTime] = simulateFaruzanDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'wanderer'
            [totalDMG, dps, breakdown, rotationTime] = simulateWandererDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'layla'
            [totalDMG, dps, breakdown, rotationTime] = simulateLaylaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nahida'
            [totalDMG, dps, breakdown, rotationTime] = simulateNahidaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'candace'
            [totalDMG, dps, breakdown, rotationTime] = simulateCandaceDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'cyno'
            [totalDMG, dps, breakdown, rotationTime] = simulateCynoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'dori'
            [totalDMG, dps, breakdown, rotationTime] = simulateDoriDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'collei'
            [totalDMG, dps, breakdown, rotationTime] = simulateColleiDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'tighnari'
            [totalDMG, dps, breakdown, rotationTime] = simulateTighnariDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case {'kamisatoayato', 'ayato'}
            [totalDMG, dps, breakdown, rotationTime] = simulateKamisatoAyatoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case {'kukishinobu', 'shinobu'}
            [totalDMG, dps, breakdown, rotationTime] = simulateKukiShinobuDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'yunjin'
            [totalDMG, dps, breakdown, rotationTime] = simulateYunJinDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'shenhe'
            [totalDMG, dps, breakdown, rotationTime] = simulateShenheDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'yelan'
            [totalDMG, dps, breakdown, rotationTime] = simulateYelanDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case {'shikanoinheizou', 'heizou'}
            [totalDMG, dps, breakdown, rotationTime] = simulateShikanoinHeizouDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case {'yaemiko', 'yae'}
            [totalDMG, dps, breakdown, rotationTime] = simulateYaeMikoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case {'aratakiitto', 'itto'}
            [totalDMG, dps, breakdown, rotationTime] = simulateAratakiIttoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'gorou'
            [totalDMG, dps, breakdown, rotationTime] = simulateGorouDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'xianyun'
            [totalDMG, dps, breakdown, rotationTime] = simulateXianyunDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'navia'
            [totalDMG, dps, breakdown, rotationTime] = simulateNaviaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'gaming'
            [totalDMG, dps, breakdown, rotationTime] = simulateGamingDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'chiori'
            [totalDMG, dps, breakdown, rotationTime] = simulateChioriDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'sigewinne'
            [totalDMG, dps, breakdown, rotationTime] = simulateSigewinneDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'clorinde'
            [totalDMG, dps, breakdown, rotationTime] = simulateClorindeDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'emilie'
            [totalDMG, dps, breakdown, rotationTime] = simulateEmilieDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'kachina'
            [totalDMG, dps, breakdown, rotationTime] = simulateKachinaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'kinich'
            [totalDMG, dps, breakdown, rotationTime] = simulateKinichDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'sethos'
            [totalDMG, dps, breakdown, rotationTime] = simulateSethosDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'ororon'
            [totalDMG, dps, breakdown, rotationTime] = simulateOroronDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'mizuki'
            [totalDMG, dps, breakdown, rotationTime] = simulateMizukiDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'ifa'
            [totalDMG, dps, breakdown, rotationTime] = simulateIfaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'dahlia'
            [totalDMG, dps, breakdown, rotationTime] = simulateDahliaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'aino'
            [totalDMG, dps, breakdown, rotationTime] = simulateAinoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'jahoda'
            [totalDMG, dps, breakdown, rotationTime] = simulateJahodaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'illuga'
            [totalDMG, dps, breakdown, rotationTime] = simulateIllugaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'varka'
            [totalDMG, dps, breakdown, rotationTime] = simulateVarkaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lohen'
            [totalDMG, dps, breakdown, rotationTime] = simulateLohenDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'prune'
            [totalDMG, dps, breakdown, rotationTime] = simulatePruneDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lanyan'
            [totalDMG, dps, breakdown, rotationTime] = simulateLanYanDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        otherwise
            error('No simulator registered for %s', memberCfg.Name);
    end

    result = struct( ...
        'Name', string(memberCfg.Name), ...
        'DisplayName', string(memberCfg.DisplayName), ...
        'TotalDMG', totalDMG, ...
        'DPS', dps, ...
        'RotationTime', rotationTime, ...
        'Breakdown', breakdown);
end

function teamContext = localApplyElementSpecificTeamBonuses(teamContext, characterName)
    % 大多数角色模拟器当前只读取 teamContext.AllDMGBonus。
    % 为了让元素专属团队增伤在不重写全部角色公式的前提下立即生效，
    % 这里按角色元素把对应的共享增伤统一折算进成员视角的 AllDMGBonus。
    if isempty(teamContext)
        return;
    end

    element = lower(char(string(getCharacterElement(characterName))));
    elementBonus = 0;
    switch element
        case 'pyro'
            elementBonus = getFieldOrDefault(teamContext, 'PyroDMGBonus', 0);
        case 'hydro'
            elementBonus = getFieldOrDefault(teamContext, 'HydroDMGBonus', 0);
        case 'cryo'
            elementBonus = getFieldOrDefault(teamContext, 'CryoDMGBonus', 0);
        case 'electro'
            elementBonus = getFieldOrDefault(teamContext, 'ElectroDMGBonus', 0);
        case 'anemo'
            elementBonus = getFieldOrDefault(teamContext, 'AnemoDMGBonus', 0);
        case 'geo'
            elementBonus = getFieldOrDefault(teamContext, 'GeoDMGBonus', 0);
        case 'dendro'
            elementBonus = getFieldOrDefault(teamContext, 'DendroDMGBonus', 0);
    end

    teamContext.ElementSpecificDMGBonus = elementBonus;
    teamContext.AllDMGBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + elementBonus;
end
