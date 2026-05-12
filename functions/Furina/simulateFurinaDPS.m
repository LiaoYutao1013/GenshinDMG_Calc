function [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Furina simulator with explicit arkhe, Salon state, fanfare, and C6
    % windows. The same implementation is reused by standalone and team
    % entries through the unified dispatcher.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Furina', 'rotation_Furina.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Furina', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Furina');
    base = readtable(fullfile(dataFolder, 'characters_芙宁娜.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Furina_VerL.csv'));
    actions = readRotationTokens(seqFile);

    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    hydroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'HydroResShred', 0);
    hydroMult = calcDamageMultiplier(90, enemy, hydroResShred);

    initialFanfare = 150 * double(constellation >= 1);
    initialFanfareCap = 300 + 100 * double(constellation >= 1);

    state = struct( ...
        'ArkheMode', "Ousia", ...
        'SalonTime', 0, ...
        'SalonTicks', 0, ...
        'SingerTicks', 0, ...
        'BurstTime', 0, ...
        'Fanfare', initialFanfare, ...
        'FanfareCap', initialFanfareCap, ...
        'OverflowFanfare', 0, ...
        'C6Time', 0, ...
        'C6HitsLeft', 0, ...
        'C6HealTime', 0, ...
        'ThornCooldown', 0, ...
        'SkillCastCount', 0 ...
    );

    totalDMG = 0;
    totalHeal = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        dmg = 0;
        heal = 0;
        note = "";

        switch action
            case 'E'
                state.SkillCastCount = state.SkillCastCount + 1;
                state.SalonTime = 30.0;
                state.SalonTicks = 0;
                state.SingerTicks = 0;
                foamMV = getTalentValue(talent, '孤心沙龙', '荒性泡沫伤害', localSkillTalentLevel(talentLevel, constellation));
                dmg = localDirectDamage(maxHP, foamMV, localHydroBonus(build, teamContext, state, getFieldOrDefault(build, 'SkillDMGBonus', 0)), build, state, hydroMult);
                note = "Salon deployed";

                if constellation >= 6
                    state.C6Time = 10.0;
                    state.C6HitsLeft = 6;
                    note = "Salon deployed, C6 active";
                end

            case 'SwitchPneuma'
                state.ArkheMode = "Pneuma";
                note = "Switched to Pneuma";

            case 'SwitchOusia'
                state.ArkheMode = "Ousia";
                note = "Switched to Ousia";

            case {'N1', 'N2', 'N3', 'N4'}
                [normalMV, normalNote] = localNormalMV(talent, action, talentLevel);
                extraBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
                dmg = localDirectDamage(maxHP, normalMV, localHydroBonus(build, teamContext, state, extraBonus), build, state, hydroMult);
                note = normalNote;

                if state.C6HitsLeft > 0 && state.C6Time > 0
                    [c6DMG, c6Heal, c6Note, state] = localResolveC6Hit(build, teamContext, talent, state, maxHP, hydroMult, action);
                    dmg = dmg + c6DMG;
                    heal = heal + c6Heal;
                    note = strtrim(note + " " + c6Note);
                end

                if state.ThornCooldown <= 0
                    thornMV = getTalentValue(talent, '独舞之邀', '灵息之刺/流涌之刃伤害', talentLevel);
                    thornDMG = localDirectDamage(maxHP, thornMV, localHydroBonus(build, teamContext, state, 0), build, state, hydroMult);
                    totalDMG = totalDMG + thornDMG;
                    thornTag = "Ousia thorn";
                    if state.ArkheMode == "Pneuma"
                        thornTag = "Pneuma blade";
                    end
                    breakdown = [breakdown; {string("Arkhe"), thornDMG, thornTag}]; %#ok<AGROW>
                    state.ThornCooldown = 6.0;
                end

            case 'Heavy'
                heavyMV = getTalentValue(talent, '独舞之邀', '重击伤害', talentLevel);
                dmg = localDirectDamage(maxHP, heavyMV, localHydroBonus(build, teamContext, state, getFieldOrDefault(build, 'NormalDMGBonus', 0)), build, state, hydroMult);
                note = "Charged attack";

                if state.C6HitsLeft > 0 && state.C6Time > 0
                    [c6DMG, c6Heal, c6Note, state] = localResolveC6Hit(build, teamContext, talent, state, maxHP, hydroMult, action);
                    dmg = dmg + c6DMG;
                    heal = heal + c6Heal;
                    note = strtrim(note + " " + c6Note);
                end

            case 'Plunge'
                plungeMV = getTalentValue(talent, '独舞之邀', '低空/高空坠地冲击伤害', talentLevel);
                dmg = localDirectDamage(maxHP, plungeMV, localHydroBonus(build, teamContext, state, getFieldOrDefault(build, 'NormalDMGBonus', 0)), build, state, hydroMult);
                note = "Plunging attack";

                if state.C6HitsLeft > 0 && state.C6Time > 0
                    [c6DMG, c6Heal, c6Note, state] = localResolveC6Hit(build, teamContext, talent, state, maxHP, hydroMult, action);
                    dmg = dmg + c6DMG;
                    heal = heal + c6Heal;
                    note = strtrim(note + " " + c6Note);
                end

            case {'Usher', 'Cheval', 'Crab'}
                if state.SalonTime > 0 && state.ArkheMode == "Ousia"
                    state.SalonTicks = state.SalonTicks + 1;
                    [salonMV, subtypeName] = localSalonMV(talent, action, localSkillTalentLevel(talentLevel, constellation));
                    hpPartyAbove50 = max(1, getFieldOrDefault(teamContext, 'MemberCount', 4));
                    salonAmp = [1.00, 1.10, 1.20, 1.30, 1.40];
                    partyIndex = min(hpPartyAbove50, 4) + 1;
                    hpPassiveBonus = min(0.28, max(0, maxHP - 30000) / 1000 * 0.007);
                    tickRamp = 1 + 0.03 * max(0, state.SalonTicks - 1);
                    dmg = localDirectDamage(maxHP, salonMV, localHydroBonus(build, teamContext, state, getFieldOrDefault(build, 'SkillDMGBonus', 0) + hpPassiveBonus), ...
                        build, state, hydroMult) * salonAmp(partyIndex) * tickRamp;
                    note = sprintf('%s hit #%d', subtypeName, state.SalonTicks);
                    state = localGainFanfare(state, 14 + 3 * double(constellation >= 2));
                else
                    note = "No Ousia Salon members active";
                end

            case 'Singer'
                if state.SalonTime > 0 && state.ArkheMode == "Pneuma"
                    state.SingerTicks = state.SingerTicks + 1;
                    [healRate, healFlat] = localSingerHeal(talent, talentLevel);
                    intervalBonus = min(0.16, max(0, maxHP - 30000) / 1000 * 0.004);
                    heal = (maxHP * healRate + healFlat) * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
                    heal = heal * (1 + intervalBonus * 0.50);
                    note = sprintf('Singer heal #%d', state.SingerTicks);
                    state = localGainFanfare(state, 18 + 4 * double(constellation >= 2));
                else
                    note = "No Pneuma Singer active";
                end

            case 'Q'
                qMV = getTalentValue(talent, '万众狂欢', '技能伤害', localBurstTalentLevel(talentLevel, constellation));
                dmg = localDirectDamage(maxHP, qMV, localHydroBonus(build, teamContext, state, getFieldOrDefault(build, 'BurstDMGBonus', 0)), build, state, hydroMult);
                state.BurstTime = 18.0;
                state.Fanfare = min(state.FanfareCap, initialFanfare + 75 * double(constellation >= 1));
                if constellation >= 1
                    state.Fanfare = min(state.FanfareCap, 150);
                end
                state.OverflowFanfare = 0;
                note = sprintf('Burst active, fanfare=%d', round(state.Fanfare));

            case 'Drain'
                % Synthetic action for rotations that want to model extra HP
                % fluctuation from teammates during burst uptime.
                if state.BurstTime > 0
                    gainAmount = 36 + 16 * double(constellation >= 2);
                    state = localGainFanfare(state, gainAmount);
                    note = sprintf('Fanfare manually increased to %.0f', state.Fanfare);
                else
                    note = "Burst inactive";
                end

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        totalHeal = totalHeal + heal;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        if heal > 0
            breakdown = [breakdown; {string(action + "_Heal"), heal, "Healing"}]; %#ok<AGROW>
        end
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    if totalHeal > 0
        breakdown = [breakdown; {string("Heal"), totalHeal, "Total healing"}]; %#ok<AGROW>
    end
    dps = totalDMG / rotationTime;
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function [mv, note] = localNormalMV(talent, action, talentLevel)
    switch action
        case 'N1'
            mv = getTalentValue(talent, '独舞之邀', '一段伤害', talentLevel);
        case 'N2'
            mv = getTalentValue(talent, '独舞之邀', '二段伤害', talentLevel);
        case 'N3'
            mv = getTalentValue(talent, '独舞之邀', '三段伤害', talentLevel);
        otherwise
            mv = getTalentValue(talent, '独舞之邀', '四段伤害', talentLevel);
    end
    note = "Normal attack";
end

function [mv, subtypeName] = localSalonMV(talent, action, talentLevel)
    switch action
        case 'Usher'
            mv = getTalentValue(talent, '孤心沙龙', '乌瑟勋爵伤害', talentLevel);
            subtypeName = "Usher";
        case 'Cheval'
            mv = getTalentValue(talent, '孤心沙龙', '海薇玛夫人伤害', talentLevel);
            subtypeName = "Chevalmarin";
        otherwise
            mv = getTalentValue(talent, '孤心沙龙', '谢贝蕾妲小姐伤害', talentLevel);
            subtypeName = "Crabaletta";
    end
end

function [healRate, healFlat] = localSingerHeal(talent, talentLevel)
    healRate = getTalentValue(talent, '孤心沙龙', '众水的歌者治疗量', talentLevel);
    healFlat = 1016.9728 * double(talentLevel >= 10) + 0 * double(talentLevel < 10);
end

function [dmg, heal, note, state] = localResolveC6Hit(build, teamContext, talent, state, maxHP, hydroMult, action)
    state.C6HitsLeft = max(0, state.C6HitsLeft - 1);
    extraBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
    baseC6MV = 0.18;
    if strcmp(action, 'Plunge')
        extraBonus = extraBonus + 0.10;
    end

    if state.ArkheMode == "Ousia"
        heal = maxHP * 0.04;
        dmg = localDirectDamage(maxHP, baseC6MV, localHydroBonus(build, teamContext, state, extraBonus), build, state, hydroMult);
        note = "C6 Ousia infusion";
    else
        heal = 0;
        dmg = localDirectDamage(maxHP, baseC6MV + 0.25, localHydroBonus(build, teamContext, state, extraBonus), build, state, hydroMult);
        state = localGainFanfare(state, 8);
        note = "C6 Pneuma infusion";
    end
end

function state = localGainFanfare(state, gainAmount)
    if state.BurstTime <= 0
        return;
    end

    gainMultiplier = 1 + 2.5 * double(state.FanfareCap > 300);
    effectiveGain = gainAmount * gainMultiplier;
    cappedGain = min(state.FanfareCap - state.Fanfare, effectiveGain);
    state.Fanfare = min(state.FanfareCap, state.Fanfare + effectiveGain);

    if state.FanfareCap > 300
        state.OverflowFanfare = min(400, state.OverflowFanfare + max(0, effectiveGain - max(cappedGain, 0)));
    end
end

function dmg = localDirectDamage(maxHP, mv, hydroBonus, build, state, hydroMult)
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(build, 'CritRate', 0), getFieldOrDefault(build, 'CritDMG', 0));
    dmg = maxHP * mv * hydroBonus * critMult * hydroMult;
    if state.Fanfare > 0
        dmg = dmg * (1 + localFanfareDamageBonus(state));
    end
end

function bonus = localHydroBonus(build, teamContext, state, extraBonus)
    baseBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0) + getFieldOrDefault(teamContext, 'SharedAllDMGBonus', 0) + extraBonus;
    if state.Fanfare > 0
        baseBonus = baseBonus + localFanfareDamageBonus(state);
    end
    if state.FanfareCap > 300 && state.OverflowFanfare > 0
        baseBonus = baseBonus + min(1.40, state.OverflowFanfare * 0.0035);
    end
    bonus = baseBonus;
end

function bonus = localFanfareDamageBonus(state)
    if state.BurstTime <= 0
        bonus = 0;
        return;
    end

    if state.FanfareCap > 300
        perPoint = 0.0025;
    end
    bonus = state.Fanfare * perPoint;
end

function state = localAdvanceState(state, actionTime)
    state.SalonTime = max(0, state.SalonTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    state.C6Time = max(0, state.C6Time - actionTime);
    state.C6HealTime = max(0, state.C6HealTime - actionTime);
    state.ThornCooldown = max(0, state.ThornCooldown - actionTime);

    if state.BurstTime <= 0
        state.Fanfare = 0;
        state.OverflowFanfare = 0;
    end
    if state.C6Time <= 0
        state.C6HitsLeft = 0;
    end
    if state.SalonTime <= 0
        state.SalonTicks = 0;
        state.SingerTicks = 0;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case {'SwitchPneuma', 'SwitchOusia'}
            actionTime = 0.25;
        case 'N1'
            actionTime = 0.35;
        case 'N2'
            actionTime = 0.40;
        case 'N3'
            actionTime = 0.52;
        case 'N4'
            actionTime = 0.60;
        case 'Heavy'
            actionTime = 0.75;
        case 'Plunge'
            actionTime = 0.95;
        case {'Usher', 'Cheval', 'Crab'}
            actionTime = 1.45;
        case 'Singer'
            actionTime = 1.80;
        case 'Q'
            actionTime = 1.20;
        case 'Drain'
            actionTime = 0.50;
        otherwise
            actionTime = 0.50;
    end
end
