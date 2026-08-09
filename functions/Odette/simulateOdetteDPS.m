function [totalDMG, dps, breakdown, rotationTime, audit] = simulateOdetteDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Odette: solo dance DoT, dance moves, and Stellar-Conduct variants.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Odette', 'rotation_Odette.txt');
    end
    if nargin < 4 || isempty(talentLevel), talentLevel = 10; end
    if nargin < 5 || isempty(constellation), constellation = 0; end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Odette', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    skillLevel = talentLevel + 3 * double(constellation >= 3);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    stellarReady = logical(getFieldOrDefault(teamContext, 'StellarConductEnabled', false));
    meltReady = getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1;
    stellarBonus = getFieldOrDefault(teamContext, 'StellarConductTaggedDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'StellarConductBonus', 0);
    c2ATK = 0.28 * double(constellation >= 2);

    actions = struct();
    actions.E = localCryoAction('Skill', skillLevel, 'SkillDMG', 'SkillDMGBonus', 1, meltReady, 'Adagio cast');
    actions.E.PostSetSkillActiveTime = 20;
    actions.Dot = localCryoAction('Skill', skillLevel, 'CodaatDawnsTollingDoT', 'SkillDMGBonus', 4, meltReady, 'Coda DoT');
    actions.Dot.HitTimeline = 5 * ones(1, 4);
    actions.Dot.SkillWindowATKBonus = c2ATK;
    actions.Plume = localCryoAction('Skill', skillLevel, 'PlumeDanceMoveDMG', 'SkillDMGBonus', 1, meltReady, 'Plume dance');
    actions.Plume.SkillWindowATKBonus = c2ATK;
    actions.Wing = localCryoAction('Skill', skillLevel, 'WingDanceMoveDMG', 'SkillDMGBonus', 1, meltReady, 'Wing dance');
    actions.Wing.SkillWindowATKBonus = c2ATK;
    actions.Q = localCryoAction('Burst', burstLevel, 'SlashDMG', 'BurstDMGBonus', 1, meltReady, 'Bluebird Finale slash');
    actions.Q.HitCount = 2;
    actions.Q.PostSetBurstActiveTime = 20;
    actions.Q.SkillWindowATKBonus = c2ATK;
    actions.QFinal = localCryoAction('Burst', burstLevel, 'FinalSlashDMG', 'BurstDMGBonus', 1, meltReady, 'Bluebird Finale final slash');
    actions.QFinal.SkillWindowATKBonus = c2ATK;
    if stellarReady
        actions.DotStellar = localCryoAction('Skill', skillLevel, 'CodaatDawnsTollingStellarConductStellarSwirlDMG', 'SkillDMGBonus', 1, false, 'Stellar-Conduct Coda');
        actions.DotStellar.BaseActionDamageBonus = stellarBonus;
        actions.DotStellar.SkillWindowATKBonus = c2ATK;
        actions.PlumeStellar = localCryoAction('Skill', skillLevel, 'PlumeDanceMoveStellarConductStellarSwirlDMG', 'SkillDMGBonus', 1, false, 'Stellar-Conduct Plume');
        actions.PlumeStellar.BaseActionDamageBonus = stellarBonus;
        actions.PlumeStellar.SkillWindowATKBonus = c2ATK;
        actions.WingStellar = localCryoAction('Skill', skillLevel, 'WingDanceMoveStellarConductStellarSwirlDMG', 'SkillDMGBonus', 1, false, 'Stellar-Conduct Wing');
        actions.WingStellar.BaseActionDamageBonus = stellarBonus;
        actions.WingStellar.SkillWindowATKBonus = c2ATK;
    end
    if constellation >= 1
        actions.C1 = localCryoAction('Skill', skillLevel, 'SkillDMG', 'SkillDMGBonus', 1, false, 'C1 dance finale');
        actions.C1.MVOverride = 3.0 + 1.5 * double(stellarReady);
        actions.C1.SkillWindowATKBonus = c2ATK;
    end

    rotation = {'E', 'Q', 'Dot', 'Plume', 'Wing', 'QFinal'};
    if stellarReady, rotation = {'E', 'Q', 'Dot', 'DotStellar', 'Plume', 'PlumeStellar', 'Wing', 'WingStellar', 'QFinal'}; end
    if constellation >= 1, rotation{end + 1} = 'C1'; end
    spec = struct('Element', "Cryo", 'ScalingMode', "ATK", 'PreferredAmplifyAura', "Pyro", ...
        'DefaultActionTime', 0.65, 'DefaultRotation', {rotation}, ...
        'ActionTimeMap', struct('E', 0.75, 'Q', 0.85, 'QFinal', 0.25, 'Dot', 20, 'DotStellar', 0.01, 'Plume', 0.35, 'PlumeStellar', 0.01, 'Wing', 0.35, 'WingStellar', 0.01, 'C1', 0.01), 'Actions', actions);
    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS('Odette', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function action = localCryoAction(group, level, param, field, hitCount, meltReady, note)
    action = struct('TalentGroup', group, 'TalentLevelOverride', level, 'Param', param, 'DamageField', field, ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1, 'HitCount', hitCount, 'ApplyGauge', 1, ...
        'AllowAmplify', double(meltReady), 'PreferredAmplifyAura', "Pyro", 'Note', note);
end
