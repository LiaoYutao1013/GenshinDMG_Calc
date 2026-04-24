function [totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Arlecchino', 'rotation_Arlecchino.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Arlecchino', 'Constellation', constellation)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Arlecchino');
    base = readtable(fullfile(dataFolder, 'characters_Arlecchino.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Arlecchino.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + build.WeaponATK) * (1 + build.AtkBonus + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + build.FlatATK + getFieldOrDefault(teamContext, 'FlatATK', 0);
    pyroDamageMult = calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'PyroResShred', 0));

    totalDMG = 0;
    rotationTime = 0;
    bond = 0;
    debtApplied = false;
    debtReady = false;
    c6Active = false;

    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        note = "";
        dmg = 0;
        [critRate, critDMG] = localCritState(build, constellation, c6Active);
        critMult = calcExpectedCritMultiplier(critRate, critDMG);

        switch action
            case 'E'
                mv = getTalentValue(talent, 'Skill', 'Spike', talentLevel);
                dmg = atk * mv * localPyroBonus(build, teamContext, build.SkillDMGBonus) * critMult * pyroDamageMult;
                debtApplied = true;
                debtReady = constellation >= 2;
                c6Active = constellation >= 6;
                note = "万相化灰，施加血偿勒令";

            case 'DebtTick'
                if debtApplied
                    mv = getTalentValue(talent, 'Skill', 'DebtTick', talentLevel);
                    dmg = atk * mv * localPyroBonus(build, teamContext, build.SkillDMGBonus) * critMult * pyroDamageMult;
                    debtReady = true;
                    note = "血偿勒令成熟";
                else
                    note = "无可结算血偿";
                end

            case 'Charge'
                if debtApplied
                    if debtReady
                        bond = min(1.30, 1.45);
                        note = "重击回收血偿勒令，获得130%生命之契";
                    else
                        bond = min(0.65, 1.45);
                        note = "提前回收血偿勒令，获得65%生命之契";
                    end
                    debtApplied = false;
                    debtReady = false;

                    if constellation >= 2
                        bloodfireDMG = atk * 9.0 * localPyroBonus(build, teamContext, build.SkillDMGBonus) * critMult * pyroDamageMult;
                        totalDMG = totalDMG + bloodfireDMG;
                        breakdown = [breakdown; {string("C2Bloodfire"), bloodfireDMG, "厄月将升，血火灼灼"}]; %#ok<AGROW>
                    end
                else
                    note = "无可回收血偿";
                end

            case {'N1', 'N2', 'N3', 'N4A', 'N4B', 'N5', 'N6'}
                mv = getTalentValue(talent, 'Normal', action, talentLevel);
                if bond >= 0.30
                    masqueBonus = getTalentValue(talent, 'Skill', 'MasqueBonus', talentLevel);
                    if constellation >= 1
                        masqueBonus = masqueBonus * 2.0;
                    end
                    extraMV = masqueBonus * bond;
                    dmg = atk * (mv + extraMV) * localPyroBonus(build, teamContext, build.NormalDMGBonus) * critMult * pyroDamageMult;
                    note = sprintf('赤死之宴，当前生命之契 %.1f%%', bond * 100);
                    bond = bond * (1 - 0.075);
                else
                    dmg = atk * mv * critMult * pyroDamageMult;
                    note = "未激活赤死之宴";
                end

            case 'Q'
                mv = getTalentValue(talent, 'Burst', 'Cast', talentLevel);
                dmg = atk * mv * localPyroBonus(build, teamContext, build.BurstDMGBonus) * critMult * pyroDamageMult;
                if constellation >= 6
                    dmg = dmg + atk * (7.0 * bond) * localPyroBonus(build, teamContext, build.BurstDMGBonus) * critMult * pyroDamageMult;
                    note = "C6 追加厄月伤害";
                else
                    note = "元素爆发";
                end
                bond = 0;
                debtApplied = false;
                debtReady = false;

            otherwise
                note = "未识别动作";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + localActionTime(action);
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localPyroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + build.PyroDMGBonus + 0.40 + build.BurstDMGBonus * 0 + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
end

function [critRate, critDMG] = localCritState(build, constellation, c6Active)
    critRate = build.CritRate;
    critDMG = build.CritDMG;
    if constellation >= 6 && c6Active
        critRate = critRate + 0.10;
        critDMG = critDMG + 0.70;
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'DebtTick'
            actionTime = 5.00;
        case 'Charge'
            actionTime = 0.60;
        case 'N1'
            actionTime = 0.30;
        case 'N2'
            actionTime = 0.35;
        case 'N3'
            actionTime = 0.45;
        case {'N4A', 'N4B'}
            actionTime = 0.25;
        case 'N5'
            actionTime = 0.50;
        case 'N6'
            actionTime = 0.60;
        case 'Q'
            actionTime = 1.20;
        otherwise
            actionTime = 0.40;
    end
end
