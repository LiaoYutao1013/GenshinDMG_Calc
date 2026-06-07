function [totalDMG, dps, breakdown, rotationTime, audit] = simulateFischlDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Fischl explicit summon / Oz / burst refresh script with AUTO follow-up inference.
    % Summon impact, Oz turret shots, burst impact, and Oz refresh shots are
    % modeled as separate actions with explicit gauge and ICD data.
    % Remaining approximation: pure standalone AUTO mode without team
    % timeline data still cannot know how often A4 and C6 follow-ups are
    % triggered, so only team-timeline-backed AUTO sims infer them.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Fischl', 'rotation_Fischl.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Fischl', 'Constellation', constellation, 'Build', build)}, 20, struct(), enemy);
    end

    aggravateReady = getFieldOrDefault(teamContext, 'DendroCount', 0) >= 1;
    summonExtraAtk = 2.00 * double(constellation >= 2);
    burstExtraAtk = 2.22 * double(constellation >= 4);
    a4RetributionAtkWeight = 0.80; % Passive A4: Undone Be Thy Sinful Hex.
    jointAttackAtkWeight = 0.30 * double(constellation >= 6); % C6: Evernight Raven.
    ozHitTimeline = ones(1, 10);

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SummoningDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'AllowCatalyze', double(aggravateReady), ...
        'FlatDirectATKWeight', summonExtraAtk, ...
        'LunarisAttackName', "Ability_Skill_S_CrowSummon", ...
        'LunarisDamageParam', "AS_Fischl_ProudSkill_32_P2_SummonAttack", ...
        'ApplyGauge', 1.0, 'ICDGroup', "Fischl_Oz", 'ICDRule', "4 hits / 5s", ...
        'Note', "Nightrider summon hit");
    actions.Oz = struct('TalentGroup', "Skill", 'Param', "OzsATKDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'HitCount', numel(ozHitTimeline), ...
        'HitTimeline', ozHitTimeline, 'AllowCatalyze', double(aggravateReady), ...
        'LunarisAttackName', "Skill_S_Crow_AutoAttack_Hit_01", ...
        'LunarisDamageParam', "AS_Fischl_ProudSkill_32_Damage_AttackRatio", ...
        'ApplyGauge', 1.0, 'ICDGroup', "Fischl_Oz", 'ICDRule', "4 hits / 5s", ...
        'Note', "Oz turret shots");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "FallingThunderDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'AllowCatalyze', double(aggravateReady), ...
        'FlatDirectATKWeight', burstExtraAtk, ...
        'LunarisAttackName', "Ability_Skill_E_CrowQueen", ...
        'LunarisDamageParam', "AS_Fischl_Talent_334_OnceDamage_AttackRatio", ...
        'ApplyGauge', 2.0, 'ICDGroup', "Fischl_Oz", 'ICDRule', "4 hits / 5s", ...
        'Note', "Midnight Phantasmagoria impact");
    actions.QOz = struct('TalentGroup', "Skill", 'Param', "OzsATKDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'HitCount', numel(ozHitTimeline), ...
        'HitTimeline', ozHitTimeline, 'AllowCatalyze', double(aggravateReady), ...
        'LunarisAttackName', "Skill_S_Crow_AutoAttack_Hit_01", ...
        'LunarisDamageParam', "AS_Fischl_ProudSkill_32_Damage_AttackRatio", ...
        'ApplyGauge', 1.0, 'ICDGroup', "Fischl_Oz", 'ICDRule', "4 hits / 5s", ...
        'Note', "Oz shots after burst refresh");
    actions.OzJointAttack = struct('TalentGroup', "Skill", 'Param', "OzsATKDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'MVOverride', 0, 'FlatDirectATKWeight', jointAttackAtkWeight, ...
        'AllowCatalyze', double(aggravateReady), ...
        'LunarisAttackName', "Talent_D_Crow_NormalAttack_01", ...
        'LunarisDamageParam', "AS_Fischl_Talent_336_AttackRatio_AssistAttack", ...
        'ApplyGauge', 1.0, 'ICDGroup', "Fischl_Oz", 'ICDRule', "4 hits / 5s", ...
        'Note', "C6 Oz coordinated attack");
    actions.OzA4Retribution = struct('TalentGroup', "Skill", 'Param', "OzsATKDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'MVOverride', 0, 'FlatDirectATKWeight', a4RetributionAtkWeight, ...
        'AllowCatalyze', double(aggravateReady), ...
        'LunarisAttackName', "Talent_ElementReactionAttackThunder_Hit", ...
        'LunarisDamageParam', "AS_Fischl_ProudSkill_22_ElementReactionAttack_AttackRatio", ...
        'ApplyGauge', 1.0, 'ICDGroup', "Fischl_Oz", 'ICDRule', "4 hits / 5s", ...
        'Note', "A4 Thundering Retribution");

    spec = struct( ...
        'Element', "Electro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.80, ...
        'DefaultRotation', {{'E', 'Oz', 'Q', 'QOz'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'Oz', 10.00, 'Q', 1.10, 'QOz', 10.00, ...
            'OzJointAttack', 0.05, 'OzA4Retribution', 0.05), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Fischl', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);

    autoFollowUpPlan = localResolveAutoFollowUpPlan(seqFile, teamContext, constellation);
    if autoFollowUpPlan.Enabled
        [extraDamage, extraBreakdown, extraAuditRows] = localResolveAutoFollowUpRows( ...
            build, enemy, talentLevel, constellation, teamContext, spec, autoFollowUpPlan);
        if extraDamage > 0
            totalDMG = totalDMG + extraDamage;
            dps = totalDMG / max(rotationTime, 1e-6);
        end
        if ~isempty(extraBreakdown)
            breakdown = [breakdown; extraBreakdown]; %#ok<AGROW>
        end
        if isstruct(audit) && isfield(audit, 'Rows') && ~isempty(extraAuditRows)
            if isempty(audit.Rows)
                audit.Rows = extraAuditRows;
            else
                audit.Rows = [audit.Rows; extraAuditRows]; %#ok<AGROW>
            end
        end
    end
end

function plan = localResolveAutoFollowUpPlan(seqFile, teamContext, constellation)
    plan = struct( ...
        'Enabled', false, ...
        'C6Count', 0, ...
        'A4Count', 0, ...
        'Source', "");

    actions = {};
    if strlength(string(seqFile)) > 0 && exist(char(string(seqFile)), 'file') == 2
        actions = readRotationTokens(char(string(seqFile)));
    end

    if ~isempty(actions)
        actionNames = upper(string(actions(:)));
        hasExplicitFollowUps = any(actionNames == "OZJOINTATTACK" | actionNames == "OZA4RETRIBUTION");
        autoMode = numel(actionNames) == 1 && actionNames(1) == "AUTO";
        if hasExplicitFollowUps || ~autoMode
            return;
        end
    end

    memberTimeline = getFieldOrDefault(teamContext, 'MemberTimelineSummary', table());
    if isempty(memberTimeline) || ~istable(memberTimeline) || height(memberTimeline) == 0
        return;
    end

    row = memberTimeline(string(memberTimeline.Character) == "Fischl", :);
    if isempty(row)
        return;
    end

    plan.C6Count = max(0, round(double(getFieldOrDefault(row, 'ActionTriggeredBackgroundCount', 0)))) ...
        * double(constellation >= 6);
    plan.A4Count = max(0, round(double(getFieldOrDefault(row, 'ReactionTriggeredBackgroundCount', 0))));
    plan.Enabled = plan.C6Count > 0 || plan.A4Count > 0;
    if plan.Enabled
        plan.Source = "team timeline";
    end
end

function [extraDamage, extraBreakdown, extraAuditRows] = localResolveAutoFollowUpRows( ...
        build, enemy, talentLevel, constellation, teamContext, spec, plan)
    extraDamage = 0;
    extraBreakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});
    extraAuditRows = table();

    followUpList = { ...
        struct('Action', "OzJointAttack", 'Count', plan.C6Count, 'OutputAction', "OzJointAttackAuto"), ...
        struct('Action', "OzA4Retribution", 'Count', plan.A4Count, 'OutputAction', "OzA4RetributionAuto")};

    for index = 1:numel(followUpList)
        followUp = followUpList{index};
        if followUp.Count <= 0
            continue;
        end

        singleSpec = spec;
        singleSpec.DefaultRotation = {{char(followUp.Action)}};
        [singleDamage, ~, singleBreakdown, ~, singleAudit] = simulateSimpleCharacterDPS( ...
            'Fischl', build, enemy, "", talentLevel, constellation, teamContext, singleSpec);
        if isempty(singleBreakdown) || height(singleBreakdown) == 0
            continue;
        end

        scaledDamage = singleDamage * followUp.Count;
        note = string(singleBreakdown.Note(1)) + " (auto x" + string(followUp.Count) + " via " + string(plan.Source) + ")";
        extraDamage = extraDamage + scaledDamage;
        extraBreakdown = [extraBreakdown; {followUp.OutputAction, scaledDamage, note}]; %#ok<AGROW>

        if isstruct(singleAudit) && isfield(singleAudit, 'Rows') && ~isempty(singleAudit.Rows)
            auditRow = singleAudit.Rows(1, :);
            auditRow.Action = followUp.OutputAction;
            if isempty(extraAuditRows)
                extraAuditRows = auditRow;
            else
                extraAuditRows = [extraAuditRows; auditRow]; %#ok<AGROW>
            end
        end
    end
end
