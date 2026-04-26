function [totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 奈芙尔单角色模拟器。
    % 核心状态包括影舞持续时间、青露数量、幕纱层数与爆发强化窗口，
    % 并据此决定幻影段伤和月绽放伤害的实际强度。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Nefer', 'rotation_Nefer.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Nefer', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Nefer');
    base = readtable(fullfile(dataFolder, 'characters_Nefer.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Nefer.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    baseEM = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    dendroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'DendroResShred', 0);
    % 单人模式下允许宽松启用月绽放，方便调试角色本体机制。
    lunarBloomEnabled = getFieldOrDefault(teamContext, 'LunarBloomEnabled', false);
    if ~lunarBloomEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0 && getFieldOrDefault(teamContext, 'DendroCount', 0) <= 1
        lunarBloomEnabled = true;
    end

    % 幕纱上限会随命座变化，因此单独提前算出。
    maxVeilStacks = 3 + 2 * double(constellation >= 2);
    state = struct( ...
        'ShadowDanceTime', 0, ...
        'VerdantDew', 0, ...
        'VeilStacks', 0, ...
        'BurstVeilTime', 0, ...
        'PhantasmCount', 0 ...
    );

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        note = "";
        dmg = 0;
        currentEM = localCurrentEM(baseEM, constellation, state.VeilStacks, maxVeilStacks);
        currentCritMult = localCritMultiplier(build, constellation, state.VeilStacks, maxVeilStacks);
        currentResShred = dendroResShred + 0.20 * double(constellation >= 4);
        directMult = calcDamageMultiplier(90, enemy, currentResShred);

        switch action
            case 'E'
                % 开启影舞，补充青露，并让后续幻影有可消耗资源。
                danceBonus = 1 + 0.10 * double(state.BurstVeilTime > 0);
                dmg = (currentEM * getTalentValue(talent, 'Skill', 'CastEM', talentLevel) + atk * 0.60) * danceBonus ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * currentCritMult * directMult;
                state.ShadowDanceTime = 10.0;
                state.VerdantDew = min(4, state.VerdantDew + 2 + double(constellation >= 1));
                note = sprintf('Shadow Dance active, dew=%d', state.VerdantDew);

            case 'Phantasm'
                if state.ShadowDanceTime > 0 && state.VerdantDew > 0
                    % 幻影会消耗青露、叠加幕纱，并在高命时生成额外月绽放。
                    state.PhantasmCount = state.PhantasmCount + 1;
                    state.VeilStacks = min(maxVeilStacks, state.VeilStacks + 1);
                    currentEM = localCurrentEM(baseEM, constellation, state.VeilStacks, maxVeilStacks);
                    currentCritMult = localCritMultiplier(build, constellation, state.VeilStacks, maxVeilStacks);
                    directMult = calcDamageMultiplier(90, enemy, currentResShred);
                    veilBonus = 1 + 0.08 * state.VeilStacks + 0.06 * double(state.BurstVeilTime > 0);
                    skillEM = getTalentValue(talent, 'Skill', 'PhantasmEM', talentLevel);
                    skillATK = getTalentValue(talent, 'Skill', 'PhantasmATK', talentLevel);
                    dmg = (currentEM * skillEM + atk * skillATK) * veilBonus ...
                        * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * currentCritMult * directMult;
                    state.VerdantDew = state.VerdantDew - 1;
                    note = sprintf('Consumed dew, veil=%d', state.VeilStacks);

                    if constellation >= 6 && mod(state.PhantasmCount, 2) == 0
                        extraDMG = calcReactionDamage(900 + 0.25 * currentEM, currentEM, enemy, currentResShred, ...
                            1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0), ...
                            max(0.10, getFieldOrDefault(teamContext, 'ReactionCritRate', 0.10)), ...
                            max(0.20, getFieldOrDefault(teamContext, 'ReactionCritDMG', 0.20)));
                        totalDMG = totalDMG + extraDMG;
                        breakdown = [breakdown; {string("C6Afterimage"), extraDMG, "Extra afterimage bloom"}]; %#ok<AGROW>
                    end
                elseif state.ShadowDanceTime <= 0
                    note = "Shadow Dance expired";
                else
                    note = "No Verdant Dew available";
                end

            case 'Q'
                % 爆发按当前幕纱层数增伤，并刷新后续强化窗口。
                burstBonus = 1 + state.VeilStacks * getTalentValue(talent, 'Burst', 'VeilBonus', talentLevel);
                dmg = currentEM * getTalentValue(talent, 'Burst', 'CastEM', talentLevel) * burstBonus ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * currentCritMult * directMult;
                state.VerdantDew = min(4, state.VerdantDew + 1 + double(constellation >= 4));
                state.BurstVeilTime = 10.0;
                note = sprintf('Burst cast, dew=%d, veil=%d', state.VerdantDew, state.VeilStacks);

            case 'LunarBloom'
                if lunarBloomEnabled
                    % 月绽放伤害同时受幕纱层数、爆发窗口和命座增益影响。
                    currentEM = localCurrentEM(baseEM, constellation, state.VeilStacks, maxVeilStacks);
                    baseReaction = getTalentValue(talent, 'Reaction', 'LunarBloomBase', talentLevel) ...
                        + getTalentValue(talent, 'Passive', 'C1EMBonus', talentLevel) * currentEM * double(constellation >= 1);
                    reactionBonus = 1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0) ...
                        + 0.05 * state.VeilStacks + 0.20 * double(state.BurstVeilTime > 0) + 0.15 * double(constellation >= 6);
                    dmg = calcReactionDamage(baseReaction, currentEM, enemy, currentResShred, reactionBonus, ...
                        max(0.10, getFieldOrDefault(teamContext, 'ReactionCritRate', 0.10)), ...
                        max(0.20, getFieldOrDefault(teamContext, 'ReactionCritDMG', 0.20)));
                    state.VeilStacks = max(0, state.VeilStacks - 1);
                    note = sprintf('Lunar-Bloom burst, veil=%d', state.VeilStacks);
                else
                    note = "No Hydro/Dendro partner for Lunar-Bloom";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    dps = totalDMG / max(rotationTime, 1);
end

function currentEM = localCurrentEM(baseEM, constellation, veilStacks, maxVeilStacks)
    % 奈芙尔的部分命座会在满幕纱时额外提高精通，因此集中在这里处理。
    currentEM = baseEM + 200 * double(constellation >= 2 && veilStacks >= maxVeilStacks);
end

function critMult = localCritMultiplier(build, constellation, veilStacks, maxVeilStacks)
    % 根据当前幕纱状态计算期望暴击乘区。
    critRate = getFieldOrDefault(build, 'CritRate', 0);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
    if constellation >= 2 && veilStacks >= maxVeilStacks
        critDMG = critDMG + 0.40;
    end
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
end

function dmgBonus = localDendroBonus(build, teamContext, extraBonus)
    % 统一处理奈芙尔所有草元素段伤的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'DendroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进影舞和爆发窗口时间。
    state.ShadowDanceTime = max(0, state.ShadowDanceTime - actionTime);
    state.BurstVeilTime = max(0, state.BurstVeilTime - actionTime);
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'Phantasm'
            actionTime = 0.80;
        case 'Q'
            actionTime = 1.20;
        case 'LunarBloom'
            actionTime = 1.25;
        otherwise
            actionTime = 0.55;
    end
end
