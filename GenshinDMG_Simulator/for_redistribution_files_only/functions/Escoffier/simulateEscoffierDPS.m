function [totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Escoffier simulator. Personal damage, summon damage, and healing are
    % all recorded here; team-side shred is prepared upstream.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Escoffier', 'rotation_Escoffier.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Escoffier', 'Constellation', constellation)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Escoffier');
    base = readtable(fullfile(dataFolder, 'characters_Escoffier.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Escoffier.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + build.WeaponATK) * (1 + build.AtkBonus + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + build.FlatATK + getFieldOrDefault(teamContext, 'FlatATK', 0);
    critDMG = build.CritDMG + getFieldOrDefault(teamContext, 'CryoCritDMGBonus', 0);
    critMult = calcExpectedCritMultiplier(build.CritRate, critDMG);
    damageMult = calcDamageMultiplier(90, enemy, build.ResShred + getFieldOrDefault(teamContext, 'CryoResShred', 0));

    totalDMG = 0;
    totalHeal = 0;
    rotationTime = 0;
    summonHits = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        note = "";
        dmg = 0;

        switch action
            case 'E'
                mv = getTalentValue(talent, 'Skill', 'Tap', talentLevel);
                dmg = atk * mv * (1 + build.CryoDMGBonus + build.SkillDMGBonus + getFieldOrDefault(teamContext, 'AllDMGBonus', 0)) ...
                    * critMult * damageMult;
                note = "低温烹饪";

            case 'Q'
                mv = getTalentValue(talent, 'Burst', 'Cast', talentLevel);
                dmg = atk * mv * (1 + build.CryoDMGBonus + build.BurstDMGBonus + getFieldOrDefault(teamContext, 'AllDMGBonus', 0)) ...
                    * critMult * damageMult;
                healRate = getTalentValue(talent, 'Burst', 'HealRate', talentLevel);
                healFlat = getTalentValue(talent, 'Burst', 'HealFlat', talentLevel);
                totalHeal = totalHeal + atk * healRate * (1 + build.HealingBonus) + healFlat;
                note = "元素爆发并治疗全队";

            case 'Summon'
                summonHits = summonHits + 1;
                mv = getTalentValue(talent, 'Skill', 'SummonHit', talentLevel);
                dmg = atk * mv * (1 + build.CryoDMGBonus + build.SkillDMGBonus + getFieldOrDefault(teamContext, 'AllDMGBonus', 0)) ...
                    * critMult * damageMult;
                note = sprintf('厨房机关后台攻击 #%d', summonHits);

            otherwise
                note = "未识别动作";
        end

        if constellation >= 2 && strcmp(action, 'Q')
            dmg = dmg * 1.15;
            note = strtrim(note + " C2");
        end
        if constellation >= 6 && strcmp(action, 'Summon')
            dmg = dmg * 1.40;
            note = strtrim(note + " C6");
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + localActionTime(action);
    end

    breakdown = [breakdown; {string("Heal"), totalHeal, "治疗量统计"}]; %#ok<AGROW>
    dps = totalDMG / max(rotationTime, 1);
end

function actionTime = localActionTime(action)
    % Scripted durations define Escoffier's standalone rotation length.
    switch action
        case 'E'
            actionTime = 0.60;
        case 'Q'
            actionTime = 1.10;
        case 'Summon'
            actionTime = 2.00;
        otherwise
            actionTime = 0.50;
    end
end
