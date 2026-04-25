function [totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Simplified Lauma simulator focused on Sanctuary upkeep, dew
    % consumption, and Lunar-Bloom amplification.
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
    lunarBloomEnabled = getFieldOrDefault(teamContext, 'LunarBloomEnabled', false);
    if ~lunarBloomEnabled && getFieldOrDefault(teamContext, 'HydroCount', 0) == 0 && getFieldOrDefault(teamContext, 'DendroCount', 0) <= 1
        lunarBloomEnabled = true;
    end

    totalDMG = 0;
    rotationTime = 0;
    sanctuaryHits = 0;
    dewStacks = 0;
    paleHymnStacks = 0;
    totalHeal = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        note = "";
        dmg = 0;

        switch action
            case 'E'
                castATK = getTalentValue(talent, 'Skill', 'CastATK', talentLevel);
                dmg = (atk * castATK + em * 0.40) * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * directCritMult * directMult;
                dewStacks = min(3, dewStacks + 2 + double(constellation >= 1));
                note = sprintf('Sanctuary deployed, dew=%d', dewStacks);

            case 'Sanctuary'
                sanctuaryHits = sanctuaryHits + 1;
                hitATK = getTalentValue(talent, 'Skill', 'SanctuaryATK', talentLevel);
                hitEM = getTalentValue(talent, 'Skill', 'SanctuaryEM', talentLevel);
                dmg = (atk * hitATK + em * hitEM) * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * directCritMult * directMult;
                dewStacks = min(3, dewStacks + 1);
                note = sprintf('Sanctuary pulse #%d, dew=%d', sanctuaryHits, dewStacks);

                if constellation >= 6 && mod(sanctuaryHits, 2) == 0
                    extraDMG = calcReactionDamage(900 + 0.40 * em, em, enemy, dendroResShred, ...
                        1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0), reactionCritRate, reactionCritDMG);
                    totalDMG = totalDMG + extraDMG;
                    breakdown = [breakdown; {string("C6Bloom"), extraDMG, "Extra Lunar-Bloom pulse"}]; %#ok<AGROW>
                end

            case 'HoldE'
                consumed = max(1, dewStacks);
                perDew = getTalentValue(talent, 'Skill', 'HoldPerDew', talentLevel);
                dmg = (atk * 0.65 + em * perDew * consumed) ...
                    * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0)) ...
                    * directCritMult * directMult;
                paleHymnStacks = paleHymnStacks + 6 * consumed + 6 * double(constellation >= 4);
                dewStacks = 0;
                if constellation >= 2
                    dmg = dmg * 1.25;
                end
                note = sprintf('Consumed %d dew, hymn=%d', consumed, paleHymnStacks);

            case 'Q'
                castATK = getTalentValue(talent, 'Burst', 'CastATK', talentLevel);
                dmg = (atk * castATK + em * 0.55) * localDendroBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0)) ...
                    * directCritMult * directMult;
                paleHymnStacks = paleHymnStacks + 18 + 6 * double(constellation >= 2);
                note = sprintf('Burst active, hymn=%d', paleHymnStacks);

            case 'LunarBloom'
                if lunarBloomEnabled
                    baseReaction = getTalentValue(talent, 'Reaction', 'LunarBloomBase', talentLevel);
                    paleBonus = 1 + paleHymnStacks * getTalentValue(talent, 'Burst', 'PaleHymnBonus', talentLevel);
                    bonusMultiplier = paleBonus * (1 + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0));
                    if constellation >= 2
                        bonusMultiplier = bonusMultiplier * 1.20;
                    end
                    dmg = calcReactionDamage(baseReaction, em, enemy, dendroResShred, bonusMultiplier, reactionCritRate, reactionCritDMG);
                    paleHymnStacks = max(0, paleHymnStacks - 4);
                    note = sprintf('Lunar-Bloom, hymn=%d', paleHymnStacks);

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
        rotationTime = rotationTime + localActionTime(action);
    end

    if totalHeal > 0
        breakdown = [breakdown; {string("Heal"), totalHeal, "C1 recovery"}]; %#ok<AGROW>
    end

    dps = totalDMG / max(rotationTime, 1);
end

function dmgBonus = localDendroBonus(build, teamContext, extraBonus)
    dmgBonus = 1 + getFieldOrDefault(build, 'DendroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
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
