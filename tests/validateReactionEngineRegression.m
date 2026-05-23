function validateReactionEngineRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false);
    teamContext = struct('ReactionMode', "Realistic");
    build = struct('EM', 0, 'ReactionDMGBonus', 0);

    state = createEnemyState(enemy, teamContext, "");
    state = localApplyAuraOnly(state, "Hydro", 1.0, build, teamContext, enemy);
    electroCharged = resolveReactionForHit(state, localMakeHit("Electro", 1.0), build, teamContext, enemy, 0);
    assert(strcmpi(char(electroCharged.PrimaryReaction), 'ElectroCharged'), ...
        'Expected Electro-Charged to trigger from Electro on Hydro.');
    assert(localAuraGauge(electroCharged.EnemyState, "Hydro") > 0, ...
        'Hydro aura should remain after Electro-Charged.');
    assert(localAuraGauge(electroCharged.EnemyState, "Electro") > 0, ...
        'Electro aura should coexist after Electro-Charged.');

    state = createEnemyState(enemy, teamContext, "");
    state = localApplyAuraOnly(state, "Hydro", 1.0, build, teamContext, enemy);
    frozen = resolveReactionForHit(state, localMakeHit("Cryo", 1.0), build, teamContext, enemy, 0);
    assert(strcmpi(char(frozen.PrimaryReaction), 'Frozen'), ...
        'Expected Frozen to trigger from Cryo on Hydro.');
    assert(logical(frozen.EnemyState.Frozen.Active), 'Frozen state should become active.');
    frozenGaugeBefore = double(frozen.EnemyState.Frozen.Gauge);

    shatterHit = localMakeHit("Geo", 0);
    shatterHit.CanApplyAura = false;
    shatterHit.CanShatter = true;
    shatterHit.StrikeType = "Blunt";
    shatter = resolveReactionForHit(frozen.EnemyState, shatterHit, build, teamContext, enemy, 0);
    assert(any(strcmpi(cellstr(string(shatter.TriggeredReactions)), 'shatter')) ...
        || strcmpi(char(shatter.PrimaryReaction), 'Shatter'), ...
        'Expected Shatter to trigger on a Frozen target.');
    assert(double(shatter.EnemyState.Frozen.Gauge) < frozenGaugeBefore, ...
        'Shatter should consume Frozen gauge.');

    state = createEnemyState(enemy, teamContext, "");
    state = localApplyAuraOnly(state, "Dendro", 1.0, build, teamContext, enemy);
    bloom = resolveReactionForHit(state, localMakeHit("Hydro", 1.0), build, teamContext, enemy, 0);
    assert(strcmpi(char(bloom.PrimaryReaction), 'Bloom'), ...
        'Expected Bloom to trigger from Hydro on Dendro.');
    assert(numel(bloom.EnemyState.DendroCores) == 1, ...
        'Bloom should create one Dendro Core.');

    hyperbloom = resolveReactionForHit(bloom.EnemyState, localMakeHit("Electro", 1.0), build, teamContext, enemy, 0);
    assert(any(strcmpi(cellstr(string(hyperbloom.TriggeredReactions)), 'hyperbloom')) ...
        || strcmpi(char(hyperbloom.PrimaryReaction), 'Hyperbloom'), ...
        'Expected Hyperbloom to trigger from Electro on a Bloom core.');
    assert(isempty(hyperbloom.EnemyState.DendroCores), ...
        'Hyperbloom should consume the available Dendro Core.');

    [expiredState, packets] = advanceEnemyStateTime(bloom.EnemyState, 6.1, "", teamContext);
    packetNames = strings(0, 1);
    if ~isempty(packets)
        packetNames = string({packets.ReactionName}).';
    end
    assert(any(strcmpi(cellstr(packetNames), 'Bloom')), ...
        'A Dendro Core should explode into Bloom damage on timeout.');
    assert(isempty(expiredState.DendroCores), ...
        'Expired Dendro Cores should be removed from enemy state.');

    disp('validateReactionEngineRegression passed');
end

function state = localApplyAuraOnly(state, element, gauge, build, teamContext, enemy)
    hit = localMakeHit(element, gauge);
    hit.CanTriggerReaction = false;
    result = resolveReactionForHit(state, hit, build, teamContext, enemy, 0);
    state = result.EnemyState;
end

function hit = localMakeHit(element, gauge)
    hit = struct( ...
        'HitElement', string(element), ...
        'ApplyElement', string(element), ...
        'ApplyGauge', double(gauge), ...
        'CanApplyAura', double(gauge) > 0, ...
        'CanTriggerReaction', true, ...
        'AllowAmplify', true, ...
        'AllowCatalyze', true);
end

function gauge = localAuraGauge(enemyState, auraElement)
    gauge = 0;
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), char(string(auraElement)))
            gauge = max(gauge, double(enemyState.Auras(i).Gauge));
        end
    end
end
