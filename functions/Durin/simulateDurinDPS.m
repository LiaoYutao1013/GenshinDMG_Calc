function [totalDMG, dps, breakdown, rotationTime] = simulateDurinDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 杜林高精度近似模拟器。
    % 建模重点：
    % 1. 战技后的净化/黯蚀双形态切换；
    % 2. 爆发根据当前形态切换为白焰龙或暗蚀龙；
    % 3. 处理原粹聚变层数、关键命座与反应优先级。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Durin', 'rotation_Durin.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Durin', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Durin');
    base = readtable(fullfile(dataFolder, 'characters_Durin.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Durin.csv'));
    actions = localResolveRotation(seqFile, teamContext);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    critRate = min(1, getFieldOrDefault(build, 'CritRate', 0));
    critDMG = getFieldOrDefault(build, 'CritDMG', 0) + 0.20 * double(constellation >= 6);
    pyroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'PyroResShred', 0);
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', createEnemyState(enemy, teamContext, "Pyro"));

    % state 追踪当前变身形态、龙持续时间、聚变层与命座窗口。
    state = struct( ...
        'Mode', "Confirmation", ...
        'ModeTime', 0, ...
        'DragonMode', "", ...
        'DragonTime', 0, ...
        'FusionStacks', 0, ...
        'CycleStacks', 0, ...
        'C2Time', 0, ...
        'WhiteDefShredTime', 0 ...
    );

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions.Tokens)
        action = actions.Tokens{i};
        actionTime = localActionTime(action);
        enemyState = advanceEnemyStateTime(enemyState, actionTime, "Pyro", teamContext);
        dmg = 0;
        note = "";
        extraRows = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
            'VariableNames', {'Action', 'Damage', 'Note'});

        switch action
            case 'E'
                % 战技本体用于进入本轮炼成状态，伤害在后续分支中结算。
                state.ModeTime = 30.0;
                note = "Essential transmutation entered";

            case 'Confirm'
                % 净化分支更偏后台支援，结算一段火伤后切换为白焰路线。
                mv = getTalentValue(talent, 'Skill', 'ConfirmATK', localSkillTalentLevel(talentLevel, constellation));
                dmg = localPyroDamage(atk, mv, build, teamContext, enemy, pyroResShred, ...
                    getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG, 0, 0);
                state.Mode = "Confirmation";
                state.ModeTime = 30.0;
                note = "Transmutation: confirmation";

            case 'Deny'
                % 黯蚀分支按三段连击处理，若队伍具备水/冰则优先走蒸发/融化。
                denyHits = [ ...
                    getTalentValue(talent, 'Skill', 'Deny1ATK', localSkillTalentLevel(talentLevel, constellation)), ...
                    getTalentValue(talent, 'Skill', 'Deny2ATK', localSkillTalentLevel(talentLevel, constellation)), ...
                    getTalentValue(talent, 'Skill', 'Deny3ATK', localSkillTalentLevel(talentLevel, constellation))];
                for hitIndex = 1:numel(denyHits)
                    [hitDMG, state, enemyState, reactionName] = localResolvedPyroAttack( ...
                        atk, denyHits(hitIndex), build, teamContext, enemy, pyroResShred, ...
                        getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG, em, state, enemyState, ...
                        false, constellation, getTalentValue(talent, 'Passive', 'DarkAmp', talentLevel), true);
                    dmg = dmg + hitDMG;
                    extraRows = [extraRows; {string(sprintf('Deny%d', hitIndex)), hitDMG, localReactionRowNote("Dark transmutation hit", reactionName)}]; %#ok<AGROW>
                end
                state.Mode = "Denial";
                state.ModeTime = 30.0;
                note = "Transmutation: denial";

            case 'Q'
                if state.Mode == "Denial"
                    [dmg, extraRows, state] = localResolveDarkBurst( ...
                        atk, em, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, extraRows, critRate, critDMG, enemyState);
                    enemyState = state.EnemyState;
                    state = rmfield(state, 'EnemyState');
                    note = "Principle of Darkness";
                else
                    [dmg, extraRows, state] = localResolveWhiteBurst( ...
                        atk, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, extraRows, critRate, critDMG);
                    note = "Principle of Purity";
                end

            case 'WhiteTick'
                if state.DragonTime > 0 && state.DragonMode == "White"
                    [dmg, state] = localResolveDragonTick( ...
                        atk, em, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, "White", critRate, critDMG, enemyState);
                    enemyState = state.EnemyState;
                    state = rmfield(state, 'EnemyState');
                    note = sprintf('White dragon follow-up, stacks=%.1f', state.FusionStacks);
                else
                    note = "White dragon inactive";
                end

            case 'DarkTick'
                if state.DragonTime > 0 && state.DragonMode == "Dark"
                    [dmg, state] = localResolveDragonTick( ...
                        atk, em, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, "Dark", critRate, critDMG, enemyState);
                    enemyState = state.EnemyState;
                    state = rmfield(state, 'EnemyState');
                    note = sprintf('Dark dragon follow-up, stacks=%.1f', state.FusionStacks);
                else
                    note = "Dark dragon inactive";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        if ~isempty(extraRows)
            breakdown = [breakdown; extraRows]; %#ok<AGROW>
        end
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;
end

function actions = localResolveRotation(seqFile, teamContext)
    rawTokens = readRotationTokens(seqFile);
    mode = string(getFieldOrDefault(teamContext, 'DurinPreferredMode', "White"));
    if isempty(rawTokens)
        rawTokens = {'AUTO'};
    end

    if numel(rawTokens) == 1 && strcmpi(rawTokens{1}, 'AUTO')
        if strcmpi(mode, 'Dark')
            tokens = [{'E', 'Deny', 'Q'}, repmat({'DarkTick'}, 1, 9)];
        else
            tokens = [{'E', 'Confirm', 'Q'}, repmat({'WhiteTick'}, 1, 10)];
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

function [dmg, rows, state] = localResolveWhiteBurst(atk, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, rows, critRate, critDMG)
    burstLevel = localBurstTalentLevel(talentLevel, constellation);
    burstHits = [ ...
        getTalentValue(talent, 'Burst', 'White1ATK', burstLevel), ...
        getTalentValue(talent, 'Burst', 'White2ATK', burstLevel), ...
        getTalentValue(talent, 'Burst', 'White3ATK', burstLevel)];
    dmg = 0;
    for hitIndex = 1:numel(burstHits)
        hitDMG = localPyroDamage(atk, burstHits(hitIndex), build, teamContext, enemy, pyroResShred, ...
            getFieldOrDefault(build, 'BurstDMGBonus', 0) + getTalentValue(talent, 'Constellation', 'C4BurstBonus', talentLevel) * double(constellation >= 4), ...
            critRate, critDMG, 0, 0);
        dmg = dmg + hitDMG;
        rows = [rows; {string(sprintf('WhiteBurst%d', hitIndex)), hitDMG, "White burst hit"}]; %#ok<AGROW>
    end

    state.DragonMode = "White";
    state.DragonTime = 20.0;
    state.FusionStacks = 10.0;
    state.CycleStacks = 20.0 * double(constellation >= 1);
    if constellation >= 2 && getFieldOrDefault(teamContext, 'DurinWhiteSupportReady', false)
        state.C2Time = 6.0;
    end
    if constellation >= 6
        state.WhiteDefShredTime = getTalentValue(talent, 'Constellation', 'C6WhiteDefReduct', talentLevel) * 0 + 10.0;
    end
end

function [dmg, rows, state] = localResolveDarkBurst(atk, em, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, rows, critRate, critDMG, enemyState)
    burstLevel = localBurstTalentLevel(talentLevel, constellation);
    state.DragonMode = "Dark";
    state.DragonTime = 20.0;
    state.FusionStacks = 10.0;
    state.CycleStacks = 20.0 * double(constellation >= 1);
    if constellation >= 2 && getFieldOrDefault(teamContext, 'DurinDarkAmpReady', false)
        state.C2Time = 6.0;
    end

    darkHits = [ ...
        getTalentValue(talent, 'Burst', 'Dark1ATK', burstLevel), ...
        getTalentValue(talent, 'Burst', 'Dark2ATK', burstLevel), ...
        getTalentValue(talent, 'Burst', 'Dark3ATK', burstLevel)];
    dmg = 0;
    for hitIndex = 1:numel(darkHits)
        [hitDMG, state, enemyState, reactionName] = localResolvedPyroAttack( ...
            atk, darkHits(hitIndex), build, teamContext, enemy, pyroResShred, ...
            getFieldOrDefault(build, 'BurstDMGBonus', 0) + getTalentValue(talent, 'Constellation', 'C4BurstBonus', talentLevel) * double(constellation >= 4), ...
            critRate, critDMG, em, state, enemyState, true, constellation, ...
            getTalentValue(talent, 'Passive', 'DarkAmp', talentLevel), true);
        dmg = dmg + hitDMG;
        rows = [rows; {string(sprintf('DarkBurst%d', hitIndex)), hitDMG, localReactionRowNote("Dark burst hit", reactionName)}]; %#ok<AGROW>
    end
    state.EnemyState = enemyState;
end

function [dmg, state] = localResolveDragonTick(atk, em, build, enemy, teamContext, pyroResShred, talent, talentLevel, constellation, state, mode, critRate, critDMG, enemyState)
    burstLevel = localBurstTalentLevel(talentLevel, constellation);
    if strcmpi(mode, 'Dark')
        mv = getTalentValue(talent, 'Burst', 'DarkDragonATK', burstLevel);
        [dmg, state, enemyState, ~] = localResolvedPyroAttack( ...
            atk, mv, build, teamContext, enemy, pyroResShred, ...
            getFieldOrDefault(build, 'BurstDMGBonus', 0), critRate, critDMG, em, state, enemyState, ...
            true, constellation, getTalentValue(talent, 'Passive', 'DarkAmp', talentLevel), true);
    else
        mv = getTalentValue(talent, 'Burst', 'WhiteDragonATK', burstLevel);
        fusionBonus = localFusionBonus(atk, state);
        extraBonus = getFieldOrDefault(build, 'BurstDMGBonus', 0) + fusionBonus ...
            + getTalentValue(talent, 'Passive', 'C2Bonus', talentLevel) * double(state.C2Time > 0);
        defReduct = getTalentValue(talent, 'Constellation', 'C6WhiteDefReduct', talentLevel) * double(constellation >= 6 && state.WhiteDefShredTime > 0);
        dmg = localPyroDamage(atk, mv, build, teamContext, enemy, pyroResShred, extraBonus, critRate, critDMG, 0, defReduct);
        state = localConsumeFusion(state, 1, constellation);
        if constellation >= 6
            state.WhiteDefShredTime = 10.0;
        end
    end
    state.EnemyState = enemyState;
end

function [dmg, state, enemyState, reactionName] = localResolvedPyroAttack(atk, mv, build, teamContext, enemy, pyroResShred, extraBonus, critRate, critDMG, em, state, enemyState, darkMode, constellation, darkPassiveBonus, allowReaction)
    % 统一处理杜林火伤段，必要时附加蒸发/融化与命座平伤。
    bonus = extraBonus + localFusionBonus(atk, state) * double(isstruct(state) && isfield(state, 'FusionStacks'));
    if isstruct(state) && isfield(state, 'C2Time')
        bonus = bonus + 0.50 * double(state.C2Time > 0 && darkMode);
    end

    flatMV = 0;
    if darkMode && isstruct(state) && isfield(state, 'CycleStacks') && state.CycleStacks > 0
        flatMV = 1.50;
        state.CycleStacks = max(0, state.CycleStacks - localExpectedConsumption(2, constellation >= 4));
    end

    defIgnore = 0.40 * double(darkMode && constellation >= 6);
    reactionName = "";
    if allowReaction && localHasDarkReaction(teamContext)
        baseDMG = localPyroDamage(atk, mv + flatMV, build, teamContext, enemy, pyroResShred, bonus, critRate, critDMG, defIgnore, 0);
        [reactionMult, enemyState, reaction] = getAmplifyingReactionMultiplier( ...
            enemyState, "Pyro", em, teamContext, 1.0, 0, darkPassiveBonus);
        dmg = baseDMG * reactionMult;
        reactionName = reaction.Name;
    else
        dmg = localPyroDamage(atk, mv + flatMV, build, teamContext, enemy, pyroResShred, bonus, critRate, critDMG, defIgnore, 0);
    end

    if isstruct(state) && isfield(state, 'FusionStacks') && state.FusionStacks > 0
        state = localConsumeFusion(state, 1, constellation);
    end
end

function dmg = localPyroDamage(atk, mv, build, teamContext, enemy, pyroResShred, extraBonus, critRate, critDMG, extraDefIgnore, extraDefReduct)
    localEnemy = enemy;
    localEnemy.DefIgnore = getFieldOrDefault(enemy, 'DefIgnore', 0) + extraDefIgnore;
    localEnemy.DefReduct = getFieldOrDefault(enemy, 'DefReduct', 0) + extraDefReduct;
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmgBonus = 1 + getFieldOrDefault(build, 'PyroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
    dmg = atk * mv * dmgBonus * critMult * calcDamageMultiplier(90, localEnemy, pyroResShred);
end

function bonus = localFusionBonus(atk, state)
    if ~isfield(state, 'FusionStacks') || state.FusionStacks <= 0
        bonus = 0;
        return;
    end
    bonus = min(0.75, 0.0003 * atk);
end

function state = localConsumeFusion(state, baseCost, constellation)
    state.FusionStacks = max(0, state.FusionStacks - localExpectedConsumption(baseCost, constellation >= 4));
end

function cost = localExpectedConsumption(baseCost, hasC4)
    if hasC4
        cost = 0.70 * baseCost;
    else
        cost = baseCost;
    end
end

function tf = localHasDarkReaction(teamContext)
    tf = getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1 || getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1;
end

function state = localAdvanceState(state, actionTime)
    % 推进双形态窗口、龙持续与命座增益时间。
    state.ModeTime = max(0, state.ModeTime - actionTime);
    state.DragonTime = max(0, state.DragonTime - actionTime);
    state.C2Time = max(0, state.C2Time - actionTime);
    state.WhiteDefShredTime = max(0, state.WhiteDefShredTime - actionTime);
    if state.ModeTime <= 0
        state.Mode = "Confirmation";
    end
    if state.DragonTime <= 0
        state.DragonMode = "";
    end
end

function note = localReactionRowNote(baseNote, reactionName)
    if reactionName == ""
        note = baseNote;
    else
        note = sprintf('%s, %s', baseNote, lower(char(reactionName)));
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.25;
        case 'Confirm'
            actionTime = 0.70;
        case 'Deny'
            actionTime = 0.90;
        case 'Q'
            actionTime = 1.20;
        case 'WhiteTick'
            actionTime = 1.80;
        case 'DarkTick'
            actionTime = 1.90;
        otherwise
            actionTime = 0.50;
    end
end
