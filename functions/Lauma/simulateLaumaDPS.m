function [totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 菈乌玛单角色模拟器。
    % 重点跟踪圣域持续、露滴积累、古歌层数与月绽放资源转化过程，
    % 使其不再只是静态倍率乘算，而是具备轮转内资源推进逻辑。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Lauma', 'rotation_Lauma.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Lauma', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Lauma');
    base = readtable(fullfile(dataFolder, 'characters_Lauma.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Lauma.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    directCritMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    reactionCritRate = getFieldOrDefault(teamContext, 'ReactionCritRate', 0);
    reactionCritDMG = getFieldOrDefault(teamContext, 'ReactionCritDMG', 0);
    if reactionCritRate <= 0 && reactionCritDMG <= 0
        reactionCritRate = 0.10;
        reactionCritDMG = 0.20;
    end

    dendroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'DendroResShred', 0);
    directMult = calcDamageMultiplier(90, enemy, dendroResShred);
    % 如果 teamContext 没有提供完整队伍环境，单人模式下仍允许做一个
    % 宽松兜底，以便单独验证角色逻辑。
    lunarBloomEnabled = getFieldOrDefault(teamContext, 'LunarBloomEnabled', false);
    if ~lunarBloomEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0 && getFieldOrDefault(teamContext, 'DendroCount', 0) <= 1
        lunarBloomEnabled = true;
    end

    % state 统一存放所有会随轮转推进变化的状态。
    state = struct( ...
        'SanctuaryTime', 0, ...
        'SanctuaryHits', 0, ...
        'DewStacks', 0, ...
        'PaleHymnStacks', 0, ...
        'BurstChoirTime', 0 ...
    );

    totalDMG = 0;
    totalHeal = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        note = "";
        dmg = 0;

        switch action
            case 'E'
                % 开启圣域并立即获得初始露滴。
                castATK = getTalentValue(talent, 'Skill', 'CastATK', talentLevel);
                openingBonus = 1 + 0.10 * double(state.BurstChoirTime > 0);
                dmg = (atk * castATK + em * 0.40) * openingBonus ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * directCritMult * directMult;
                state.SanctuaryTime = 12.0;
                state.SanctuaryHits = 0;
                state.DewStacks = min(3, state.DewStacks + 2 + double(constellation >= 1));
                note = sprintf('Sanctuary deployed, dew=%d', state.DewStacks);

            case 'Sanctuary'
                if state.SanctuaryTime > 0
                    % 圣域脉冲会补充露滴、累计古歌层数，并在高命下触发额外月绽放。
                    state.SanctuaryHits = state.SanctuaryHits + 1;
                    hitATK = getTalentValue(talent, 'Skill', 'SanctuaryATK', talentLevel);
                    hitEM = getTalentValue(talent, 'Skill', 'SanctuaryEM', talentLevel);
                    pulseBonus = 1 + 0.08 * min(3, state.SanctuaryHits - 1) + 0.10 * double(state.BurstChoirTime > 0);
                    dmg = (atk * hitATK + em * hitEM) * pulseBonus ...
                        * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * directCritMult * directMult;
                    state.DewStacks = min(3, state.DewStacks + 1);
                    state.PaleHymnStacks = min(36, state.PaleHymnStacks + 2);
                    note = sprintf('Sanctuary pulse #%d, dew=%d, hymn=%d', state.SanctuaryHits, state.DewStacks, state.PaleHymnStacks);

                    if constellation >= 6 && mod(state.SanctuaryHits, 2) == 0
                        extraDMG = calcReactionDamage(900 + 0.40 * em, em, enemy, dendroResShred, ...
                            1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0), reactionCritRate, reactionCritDMG);
                        totalDMG = totalDMG + extraDMG;
                        breakdown = [breakdown; {string("C6Bloom"), extraDMG, "Extra Lunar-Bloom pulse"}]; %#ok<AGROW>
                    end
                else
                    note = "Sanctuary expired";
                end

            case 'HoldE'
                if state.DewStacks > 0
                    % 长按战技消耗全部露滴，换取更高爆发段与古歌层数。
                    consumed = state.DewStacks;
                    perDew = getTalentValue(talent, 'Skill', 'HoldPerDew', talentLevel);
                    holdBonus = 1 + 0.12 * (consumed - 1) + 0.25 * double(constellation >= 2);
                    dmg = (atk * 0.65 + em * perDew * consumed) * holdBonus ...
                        * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                        * directCritMult * directMult;
                    state.PaleHymnStacks = min(36, state.PaleHymnStacks + 6 * consumed + 6 * double(constellation >= 4));
                    state.DewStacks = 0;
                    note = sprintf('Consumed %d dew, hymn=%d', consumed, state.PaleHymnStacks);
                else
                    note = "No dew to consume";
                end

            case 'Q'
                % 爆发按当前古歌层数进一步增伤，并开启后续强化窗口。
                castATK = getTalentValue(talent, 'Burst', 'CastATK', talentLevel);
                hymnBurstBonus = 1 + 0.01 * state.PaleHymnStacks;
                dmg = (atk * castATK + em * 0.55) * hymnBurstBonus ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * directCritMult * directMult;
                state.PaleHymnStacks = min(36, state.PaleHymnStacks + 18 + 6 * double(constellation >= 2));
                state.BurstChoirTime = 10.0;
                note = sprintf('Burst active, hymn=%d', state.PaleHymnStacks);

            case 'LunarBloom'
                if lunarBloomEnabled
                    % 月绽放伤害同时受古歌层数、圣域状态和队伍额外增益影响。
                    baseReaction = getTalentValue(talent, 'Reaction', 'LunarBloomBase', talentLevel);
                    paleBonus = 1 + state.PaleHymnStacks * getTalentValue(talent, 'Burst', 'PaleHymnBonus', talentLevel);
                    sanctuaryBonus = 1 + 0.12 * double(state.SanctuaryTime > 0);
                    bonusMultiplier = paleBonus * sanctuaryBonus * (1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0));
                    if constellation >= 2
                        bonusMultiplier = bonusMultiplier * 1.20;
                    end
                    dmg = calcReactionDamage(baseReaction, em, enemy, dendroResShred, bonusMultiplier, reactionCritRate, reactionCritDMG);
                    state.PaleHymnStacks = max(0, state.PaleHymnStacks - 4);
                    note = sprintf('Lunar-Bloom, hymn=%d', state.PaleHymnStacks);

                    if constellation >= 1
                        totalHeal = totalHeal + 1200 + 0.60 * em;
                    end
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

    if totalHeal > 0
        breakdown = [breakdown; {string("Heal"), totalHeal, "C1 recovery"}]; %#ok<AGROW>
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localDendroBonus(build, teamContext, extraBonus)
    % 统一处理菈乌玛所有草伤段的增伤叠加。
    dmgBonus = 1 + getFieldOrDefault(build, 'DendroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function state = localAdvanceState(state, actionTime)
    % 推进圣域与爆发强化窗口，使状态衰减始终和动作时长同步。
    state.SanctuaryTime = max(0, state.SanctuaryTime - actionTime);
    state.BurstChoirTime = max(0, state.BurstChoirTime - actionTime);
    if state.SanctuaryTime <= 0
        state.SanctuaryHits = 0;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'Sanctuary'
            actionTime = 1.90;
        case 'HoldE'
            actionTime = 0.85;
        case 'Q'
            actionTime = 1.20;
        case 'LunarBloom'
            actionTime = 1.30;
        otherwise
            actionTime = 0.60;
    end
end
