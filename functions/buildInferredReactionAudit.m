function audit = buildInferredReactionAudit(member, actions, teamContext, rotationFile, actionOverrides, archetypeInfo)
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 4
        rotationFile = "";
    end
    if nargin < 5 || isempty(actionOverrides)
        actionOverrides = struct();
    end
    if nargin < 6 || isempty(archetypeInfo)
        archetypeInfo = struct();
    end

    rows = localMakeEmptyAuditRows();
    actions = string(actions);
    actions = actions(:);
    if ~isempty(actions)
        actionCol = strings(numel(actions), 1);
        actionKeyCol = strings(numel(actions), 1);
        applyGaugeCol = nan(numel(actions), 1);
        applyGaugeSourceCol = strings(numel(actions), 1);
        icdRuleCol = strings(numel(actions), 1);
        icdSourceCol = strings(numel(actions), 1);
        lunarisAttackNameCol = strings(numel(actions), 1);
        lunarisDamageParamCol = strings(numel(actions), 1);
        applyGaugeFallbackCol = false(numel(actions), 1);
        icdFallbackCol = false(numel(actions), 1);

        for i = 1:numel(actions)
            action = actions(i);
            override = localResolveAuditOverride(actionOverrides, action);
            meta = inferActionCombatMetadata(member, action, archetypeInfo, teamContext);
            [applyGauge, applyGaugeSource, icdRule, icdSource] = localResolveAuditMetadata(meta, override);

            actionCol(i) = action;
            actionKeyCol(i) = string(getFieldOrDefault(override, 'ActionKey', action));
            applyGaugeCol(i) = applyGauge;
            applyGaugeSourceCol(i) = applyGaugeSource;
            icdRuleCol(i) = icdRule;
            icdSourceCol(i) = icdSource;
            lunarisAttackNameCol(i) = string(getFieldOrDefault(override, 'LunarisAttackName', ...
                getFieldOrDefault(meta, 'LunarisAttackName', "")));
            lunarisDamageParamCol(i) = string(getFieldOrDefault(override, 'LunarisDamageParam', ...
                getFieldOrDefault(meta, 'LunarisDamageParam', "")));
        end

        rows = table(actionCol, actionKeyCol, applyGaugeCol, applyGaugeSourceCol, ...
            icdRuleCol, icdSourceCol, lunarisAttackNameCol, lunarisDamageParamCol, ...
            applyGaugeFallbackCol, icdFallbackCol, ...
            'VariableNames', {'Action', 'ActionKey', 'ApplyGauge', 'ApplyGaugeSource', ...
            'ICDRule', 'ICDSource', 'LunarisAttackName', 'LunarisDamageParam', ...
            'ApplyGaugeFallback', 'ICDFallback'});
    end

    enemyState = localResolveAuditEnemyState(member, teamContext);
    audit = struct( ...
        'Character', string(getFieldOrDefault(member, 'Name', "")), ...
        'RotationFile', string(rotationFile), ...
        'TeamContextReactionMode', string(getFieldOrDefault(teamContext, 'ReactionMode', "")), ...
        'EnemyStateAutoSupportAura', logical(getFieldOrDefault(enemyState, 'AutoSupportAura', false)), ...
        'Rows', rows);
end

function override = localResolveAuditOverride(actionOverrides, action)
    override = struct();
    if ~isstruct(actionOverrides) || isempty(fieldnames(actionOverrides))
        return;
    end

    key = matlab.lang.makeValidName(lower(char(string(action))));
    if isfield(actionOverrides, key)
        override = actionOverrides.(key);
    end
end

function [applyGauge, applyGaugeSource, icdRule, icdSource] = localResolveAuditMetadata(meta, override)
    if nargin < 2 || isempty(override)
        override = struct();
    end

    explicitApplyGaugeSource = string(getFieldOrDefault(override, 'ApplyGaugeSource', ""));
    explicitICDSource = string(getFieldOrDefault(override, 'ICDSource', ""));
    explicitICDRule = string(getFieldOrDefault(override, 'ICDRule', ""));
    resolvedApplyGaugeSource = string(getFieldOrDefault(meta, 'ApplyGaugeSource', ""));
    resolvedICDSource = string(getFieldOrDefault(meta, 'ICDSource', ""));
    resolvedICDRule = string(getFieldOrDefault(meta, 'ICDRule', ""));

    forceReactionName = string(getFieldOrDefault(meta, 'ForceReactionName', ""));
    hitElement = string(getFieldOrDefault(meta, 'HitElement', ""));
    actionClass = string(getFieldOrDefault(meta, 'ActionClass', "Utility"));
    inferredGauge = double(getFieldOrDefault(meta, 'ApplyGauge', 0));
    canApplyAura = logical(getFieldOrDefault(meta, 'CanApplyAura', false));

    if strlength(explicitApplyGaugeSource) > 0
        applyGaugeSource = explicitApplyGaugeSource;
        if applyGaugeSource == "not_applicable" || applyGaugeSource == "pending_verification"
            applyGauge = nan;
        else
            applyGauge = double(getFieldOrDefault(override, 'ApplyGauge', inferredGauge));
        end
    elseif strlength(resolvedApplyGaugeSource) > 0
        applyGaugeSource = resolvedApplyGaugeSource;
        if applyGaugeSource == "not_applicable" || applyGaugeSource == "pending_verification"
            applyGauge = nan;
        else
            applyGauge = inferredGauge;
        end
    elseif strlength(forceReactionName) > 0 || actionClass == "Reaction"
        applyGauge = nan;
        applyGaugeSource = "not_applicable";
    elseif canApplyAura && inferredGauge > 0
        applyGauge = inferredGauge;
        applyGaugeSource = "inferred";
    elseif localIsElementalDamageElement(hitElement)
        applyGauge = nan;
        applyGaugeSource = "pending_verification";
    else
        applyGauge = nan;
        applyGaugeSource = "not_applicable";
    end

    if strlength(explicitICDSource) > 0
        icdSource = explicitICDSource;
    elseif strlength(resolvedICDSource) > 0
        icdSource = resolvedICDSource;
    elseif applyGaugeSource == "not_applicable"
        icdSource = "not_applicable";
    else
        icdSource = "pending_verification";
    end

    if strlength(explicitICDRule) > 0
        icdRule = explicitICDRule;
    elseif strlength(resolvedICDRule) > 0
        icdRule = resolvedICDRule;
    else
        icdRule = "";
    end
end

function tf = localIsElementalDamageElement(element)
    switch lower(char(string(element)))
        case {'pyro', 'hydro', 'cryo', 'electro', 'anemo', 'geo', 'dendro'}
            tf = true;
        otherwise
            tf = false;
    end
end

function rows = localMakeEmptyAuditRows()
    rows = table('Size', [0 10], ...
        'VariableTypes', {'string', 'string', 'double', 'string', 'string', 'string', 'string', 'string', 'logical', 'logical'}, ...
        'VariableNames', {'Action', 'ActionKey', 'ApplyGauge', 'ApplyGaugeSource', 'ICDRule', 'ICDSource', ...
        'LunarisAttackName', 'LunarisDamageParam', 'ApplyGaugeFallback', 'ICDFallback'});
end

function enemyState = localResolveAuditEnemyState(member, teamContext)
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', struct());
    if isstruct(enemyState) && ~isempty(fieldnames(enemyState))
        return;
    end

    enemy = struct('ReactionMode', string(getFieldOrDefault(teamContext, 'ReactionMode', "")));
    if isfield(teamContext, 'AutoSupportAura')
        enemy.AutoSupportAura = logical(getFieldOrDefault(teamContext, 'AutoSupportAura', false));
    end

    enemyState = createEnemyState(enemy, teamContext, string(getFieldOrDefault(member, 'Element', "")));
end
