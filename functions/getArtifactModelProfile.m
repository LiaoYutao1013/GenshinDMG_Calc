function profile = getArtifactModelProfile(characterName, build)
    % 返回角色默认圣遗物分件规划与条件化套装假设。
    % 这份 profile 只负责“默认 build 的自动迁移与编译口径”，不替代玩家手动改件。
    if nargin < 2
        build = struct();
    end

    element = getCharacterElement(characterName);
    profile = struct( ...
        'EnablePieceModel', true, ...
        'ApplySetBonuses', false, ...
        'LegacyTotalsIncludeSetBonuses', false, ...
        'SandsMainStat', "AtkBonus", ...
        'GobletMainStat', localDefaultGoblet(element), ...
        'CircletMainStat', "CritRate", ...
        'OffPieceSlot', "Goblet", ...
        'AssumeOffFieldSkill', false, ...
        'AssumeBondOfLifeStacks', 0, ...
        'AssumeMarechausseeStacks', 0, ...
        'AssumeObsidianActive', false, ...
        'AssumeNightsoulBlessing', false, ...
        'AssumeCryoAura', false, ...
        'AssumeFrozen', false, ...
        'AssumeHuskStacks', 0, ...
        'AssumeMoonPhase', 1, ...
        'AssumeNymphStacks', 0);

    switch lower(char(string(characterName)))
        case 'arlecchino'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "PyroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeBondOfLifeStacks = 3;

        case 'furina'
            profile.SandsMainStat = "HPBonus";
            profile.GobletMainStat = "HydroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeOffFieldSkill = true;

        case 'neuvillette'
            profile.SandsMainStat = "HPBonus";
            profile.GobletMainStat = "HydroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeMarechausseeStacks = 3;

        case 'skirk'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "CryoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeCryoAura = true;
            profile.AssumeFrozen = true;

        case 'escoffier'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "CryoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeOffFieldSkill = true;

        case 'citlali'
            profile.SandsMainStat = "EM";
            profile.GobletMainStat = "CryoDMGBonus";
            profile.CircletMainStat = "EM";
            profile.ApplySetBonuses = true;

        case 'lauma'
            profile.SandsMainStat = "EM";
            profile.GobletMainStat = "DendroDMGBonus";
            profile.CircletMainStat = "EM";
            profile.ApplySetBonuses = true;

        case 'nefer'
            profile.SandsMainStat = "EM";
            profile.GobletMainStat = "DendroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'xilonen'
            profile.SandsMainStat = "DEFBonus";
            profile.GobletMainStat = "GeoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeHuskStacks = 4;
            profile.AssumeNightsoulBlessing = true;

        case 'zibai'
            profile.SandsMainStat = "DEFBonus";
            profile.GobletMainStat = "GeoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeHuskStacks = 4;

        case 'linnea'
            profile.SandsMainStat = "DEFBonus";
            profile.GobletMainStat = "GeoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeHuskStacks = 4;

        case 'nicole'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "PyroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeOffFieldSkill = true;

        case 'nilou'
            profile.SandsMainStat = "HPBonus";
            profile.GobletMainStat = "HydroDMGBonus";
            profile.CircletMainStat = "HPBonus";

        case 'chasca'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "AnemoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeNightsoulBlessing = true;
            profile.AssumeObsidianActive = true;

        case 'chevreuse'
            profile.SandsMainStat = "HPBonus";
            profile.GobletMainStat = "PyroDMGBonus";
            profile.CircletMainStat = "HealingBonus";

        case 'iansan'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "ElectroDMGBonus";
            profile.CircletMainStat = "CritRate";

        case 'ineffa'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "ElectroDMGBonus";
            profile.CircletMainStat = "CritRate";

        case 'flins'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "ElectroDMGBonus";
            profile.CircletMainStat = "CritRate";

        case 'mavuika'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "PyroDMGBonus";
            profile.CircletMainStat = "CritRate";

        case 'mualani'
            profile.SandsMainStat = "HPBonus";
            profile.GobletMainStat = "HydroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeNightsoulBlessing = true;
            profile.AssumeObsidianActive = true;
            profile.AssumeNymphStacks = 3;

        case 'varesa'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "ElectroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeNightsoulBlessing = true;
            profile.AssumeObsidianActive = true;

        case 'durin'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "PyroDMGBonus";
            profile.CircletMainStat = "CritRate";

        case 'xianyun'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "AnemoDMGBonus";
            profile.CircletMainStat = "AtkBonus";
            profile.ApplySetBonuses = true;

        case 'navia'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "GeoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'gaming'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "PyroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'chiori'
            profile.SandsMainStat = "DEFBonus";
            profile.GobletMainStat = "GeoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeHuskStacks = 4;

        case 'sigewinne'
            profile.SandsMainStat = "HPBonus";
            profile.GobletMainStat = "HydroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'clorinde'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "ElectroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'emilie'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "DendroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'kachina'
            profile.SandsMainStat = "DEFBonus";
            profile.GobletMainStat = "GeoDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;

        case 'kinich'
            profile.SandsMainStat = "AtkBonus";
            profile.GobletMainStat = "DendroDMGBonus";
            profile.CircletMainStat = "CritRate";
            profile.ApplySetBonuses = true;
            profile.AssumeNightsoulBlessing = true;
            profile.AssumeObsidianActive = true;
    end

    if getFieldOrDefault(build, 'HealingBonus', 0) >= 0.30 ...
            && getFieldOrDefault(build, 'CritRate', 0) < 0.45
        profile.CircletMainStat = "HealingBonus";
    end
end

function goblet = localDefaultGoblet(element)
    switch lower(char(string(element)))
        case 'pyro'
            goblet = "PyroDMGBonus";
        case 'hydro'
            goblet = "HydroDMGBonus";
        case 'cryo'
            goblet = "CryoDMGBonus";
        case 'electro'
            goblet = "ElectroDMGBonus";
        case 'anemo'
            goblet = "AnemoDMGBonus";
        case 'geo'
            goblet = "GeoDMGBonus";
        case 'dendro'
            goblet = "DendroDMGBonus";
        otherwise
            goblet = "AtkBonus";
    end
end
