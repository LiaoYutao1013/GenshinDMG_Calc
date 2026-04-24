function [totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Skirk', 'rotation_Skirk.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Skirk', 'Constellation', constellation)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Skirk');
    base = readtable(fullfile(dataFolder, 'characters_Skirk.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Skirk.csv'));
    actions = readRotationTokens(seqFile);

    critDMG = build.CritDMG + getFieldOrDefault(teamContext, 'CryoCritDMGBonus', 0);
    critMult = calcExpectedCritMultiplier(build.CritRate, critDMG);

    deathStacks = min(3, getFieldOrDefault(teamContext, 'SkirkDeathCrossingStacks', 0));
    deathNormal = [1.00, 1.10, 1.20, 1.70];
    deathBurst = [1.00, 1.05, 1.15, 1.60];
    c4Attack = [0.00, 0.10, 0.20, 0.40];

    c4Bonus = c4Attack(deathStacks + 1) * double(constellation >= 4);
    c2AttackBonus = 0;
    subtlety = 0;
    inMode = false;
    extinctionHits = 0;
    absorbedRifts = 0;
    havocSeverStacks = 0;
    totalDMG = 0;
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
                inMode = true;
                subtlety = 45 + 10 * double(constellation >= 2);
                note = "进入七相一闪";

            case 'ExQ'
                if ~inMode
                    note = "未处于七相一闪，跳过";
                else
                    absorbedRifts = min(3, getFieldOrDefault(teamContext, 'SkirkVoidRifts', 0));
                    bonusKey = sprintf('RiftBonus%d', absorbedRifts);
                    extinctionBonus = getTalentValue(talent, 'Extinction', bonusKey, talentLevel);
                    extinctionHits = 10;
                    subtlety = subtlety + 8 * absorbedRifts;
                    havocSeverStacks = havocSeverStacks + absorbedRifts * double(constellation >= 6);
                    c2AttackBonus = 0.70 * double(constellation >= 2);
                    note = sprintf('极恶技·尽，吸收%d个虚境裂隙，后续普攻增伤%.1f%%', absorbedRifts, extinctionBonus * 100);

                    if constellation >= 1 && absorbedRifts > 0
                        bladeMV = 5.0 * absorbedRifts;
                        bladeDMG = localAttackValue(build, base, teamContext, c4Bonus + c2AttackBonus) ...
                            * bladeMV * localCryoBonus(build, teamContext, 0) * critMult ...
                            * calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0)) ...
                            * deathNormal(deathStacks + 1);
                        totalDMG = totalDMG + bladeDMG;
                        breakdown = [breakdown; {string("C1Blade"), bladeDMG, "吸收裂隙后触发晶刃"}]; %#ok<AGROW>
                    end
                end

            case {'N1', 'N2', 'N3', 'N4', 'N5'}
                if ~inMode
                    note = "未处于七相一闪";
                else
                    talentParam = ['SevenPhase' action];
                    mv = getTalentValue(talent, 'Warp', talentParam, talentLevel);
                    dmgBonus = localCryoBonus(build, teamContext, build.NormalDMGBonus);
                    if extinctionHits > 0
                        extinctionKey = sprintf('RiftBonus%d', absorbedRifts);
                        dmgBonus = dmgBonus + getTalentValue(talent, 'Extinction', extinctionKey, talentLevel);
                        extinctionHits = extinctionHits - 1;
                        note = "极恶技·尽普攻增伤";
                    end

                    dmg = localAttackValue(build, base, teamContext, c4Bonus + c2AttackBonus) * mv ...
                        * dmgBonus * critMult ...
                        * calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0)) ...
                        * deathNormal(deathStacks + 1);

                    if constellation >= 6 && any(strcmp(action, {'N3', 'N5'})) && havocSeverStacks > 0
                        havocSeverStacks = havocSeverStacks - 1;
                        extraMV = 3 * 1.8;
                        extraDMG = localAttackValue(build, base, teamContext, c4Bonus + c2AttackBonus) * extraMV ...
                            * dmgBonus * critMult ...
                            * calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0)) ...
                            * deathNormal(deathStacks + 1);
                        totalDMG = totalDMG + extraDMG;
                        breakdown = [breakdown; {string("C6Sever"), extraDMG, "极恶技·斩"}]; %#ok<AGROW>
                    end
                end

            case 'Charge'
                if inMode
                    mv = getTalentValue(talent, 'Warp', 'SevenPhaseCharge', talentLevel);
                    dmg = localAttackValue(build, base, teamContext, c4Bonus + c2AttackBonus) * mv ...
                        * localCryoBonus(build, teamContext, build.NormalDMGBonus) * critMult ...
                        * calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0)) ...
                        * deathNormal(deathStacks + 1);
                else
                    note = "未处于七相一闪";
                end

            case 'Burst'
                countedPoints = min(max(subtlety - 50, 0), 12 + 10 * double(constellation >= 2));
                mv = 5 * getTalentValue(talent, 'Ruin', 'Slash', talentLevel) ...
                    + getTalentValue(talent, 'Ruin', 'FinalSlash', talentLevel) ...
                    + countedPoints * getTalentValue(talent, 'Ruin', 'SubtletyPerPoint', talentLevel);
                dmg = localAttackValue(build, base, teamContext, c4Bonus) * mv ...
                    * localCryoBonus(build, teamContext, build.BurstDMGBonus) * critMult ...
                    * calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0)) ...
                    * deathBurst(deathStacks + 1);
                note = sprintf('极恶技·灭，计入%.0f点额外蛇之狡谋', countedPoints);

                if constellation >= 6 && havocSeverStacks > 0
                    extraDMG = localAttackValue(build, base, teamContext, c4Bonus) * (7.5 * havocSeverStacks) ...
                        * localCryoBonus(build, teamContext, build.BurstDMGBonus) * critMult ...
                        * calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0)) ...
                        * deathBurst(deathStacks + 1);
                    totalDMG = totalDMG + extraDMG;
                    breakdown = [breakdown; {string("C6Burst"), extraDMG, "极恶技·斩爆发附伤"}]; %#ok<AGROW>
                    havocSeverStacks = 0;
                end

                inMode = false;
                subtlety = 0;
                extinctionHits = 0;
                c2AttackBonus = 0;

            otherwise
                note = "未识别动作";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;

        if inMode
            subtlety = max(0, subtlety - 6.667 * actionTime);
            if subtlety <= 0
                inMode = false;
                c2AttackBonus = 0;
            end
        end
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;
end

function atk = localAttackValue(build, base, teamContext, extraAtkBonus)
    totalBonus = build.AtkBonus + getFieldOrDefault(teamContext, 'ATKBonus', 0) + extraAtkBonus;
    atk = (base.BaseATK(1) + build.WeaponATK) * (1 + totalBonus) ...
        + build.FlatATK + getFieldOrDefault(teamContext, 'FlatATK', 0);
end

function dmgBonus = localCryoBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + build.CryoDMGBonus + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.40;
        case 'ExQ'
            actionTime = 0.65;
        case 'N1'
            actionTime = 0.35;
        case 'N2'
            actionTime = 0.40;
        case 'N3'
            actionTime = 0.55;
        case 'N4'
            actionTime = 0.55;
        case 'N5'
            actionTime = 0.70;
        case 'Charge'
            actionTime = 0.75;
        case 'Burst'
            actionTime = 1.30;
        otherwise
            actionTime = 0.50;
    end
end
