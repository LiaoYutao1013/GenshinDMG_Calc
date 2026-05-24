function [totalDMG, dps, breakdown, rotationTime, audit] = simulateXianyunDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Xianyun simulator.
    % Focus:
    % 1. E Skyladder count and Driftcloud Wave scaling.
    % 2. Q cast damage, Starwicker follow-up, and burst healing.
    % 3. A1 plunge crit support plus A4/C2 plunge bonuses.
    % 4. C4 extra healing, C6 crit bonus, and post-burst E window.
    % 5. Weapon plunge bonus integration.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Xianyun', 'rotation_Xianyun.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Xianyun', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Xianyun');
    base = readtable(fullfile(dataFolder, 'characters_Xianyun.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Xianyun.csv'));
    actions = readRotationTokens(seqFile);

    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);

    critRate = min(1, getFieldOrDefault(build, 'CritRate', 0) + getFieldOrDefault(teamContext, 'PlungeCritRateBonus', 0));
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
    anemoResShred = getFieldOrDefault(build, 'ResShred', 0);
    anemoMult = calcDamageMultiplier(90, enemy, anemoResShred);

    state = struct( ...
        'BurstTime', 0, ...
        'StarwickerStacks', 0, ...
        'StormPinionStacks', 0, ...
        'CurrentSkyladders', 0, ...
        'C6WindowTime', 0, ...
        'C6UsesLeft', 0, ...
        'WeaponPlungeBonusTime', 0, ...
        'LastC4HealCooldown', 0);

    totalDMG = 0;
    totalHeal = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = string(actions{i});
        actionTime = localActionTime(action);
        dmg = 0;
        heal = 0;
        note = "";

        switch upper(char(action))
            case 'E'
                state.CurrentSkyladders = 1;
                note = "Entered Cloud Transmogrification";

            case 'SKYLADDER'
                if state.CurrentSkyladders > 0
                    state.CurrentSkyladders = min(3, state.CurrentSkyladders + 1);
                    mv = getTalentValue(talent, 'Skill', 'SkyladderATK', localSkillTalentLevel(talentLevel, constellation));
                    dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG);
                    note = sprintf('Skyladder x%d', state.CurrentSkyladders);
                else
                    note = "No cloud state";
                end

            case {'PLUNGE1', 'PLUNGE2', 'PLUNGE3', 'DRIFTCLOUDWAVE'}
                ladderCount = max(1, state.CurrentSkyladders);
                mvField = sprintf('Driftcloud%dATK', min(3, ladderCount));
                mv = getTalentValue(talent, 'Skill', mvField, localSkillTalentLevel(talentLevel, constellation));
                plungeBonus = getFieldOrDefault(build, 'PlungeDMGBonus', 0) + getFieldOrDefault(teamContext, 'PlungeDMGBonus', 0);
                [c6CritBonus, state] = localConsumeC6CritBonus(state, talent, talentLevel, constellation, ladderCount);
                localCritDMG = critDMG + c6CritBonus;
                dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, plungeBonus, critRate, localCritDMG);
                state.StormPinionStacks = min(4, state.StormPinionStacks + 1);
                state.CurrentSkyladders = 0;
                if state.BurstTime > 0
                    state.StarwickerStacks = max(0, state.StarwickerStacks - 1);
                end
                state.WeaponPlungeBonusTime = 20.0;
                note = sprintf('Driftcloud Wave after %d ladder(s)', ladderCount);
                if c6CritBonus > 0
                    note = localAppendNote(note, sprintf('C6 crit +%.0f%%', c6CritBonus * 100));
                end

                if constellation >= 4 && state.LastC4HealCooldown <= 0
                    healRate = localC4HealRate(talent, talentLevel, ladderCount);
                    heal = heal + atk * healRate * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
                    state.LastC4HealCooldown = 5.0;
                end

            case 'Q'
                mv = getTalentValue(talent, 'Burst', 'CastATK', localBurstTalentLevel(talentLevel, constellation));
                dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, getFieldOrDefault(build, 'BurstDMGBonus', 0), critRate, critDMG);
                heal = heal + localInitialHeal(atk, build, talent, talentLevel, constellation);
                state.BurstTime = getTalentValue(talent, 'Burst', 'Duration', talentLevel);
                state.StarwickerStacks = getTalentValue(talent, 'Burst', 'AdeptalAssistance', talentLevel);
                if constellation >= 6
                    state.C6WindowTime = 16.0;
                    state.C6UsesLeft = 8;
                end
                note = "Burst active";

            case 'STARWICKER'
                if state.BurstTime > 0 && state.StarwickerStacks > 0
                    mv = getTalentValue(talent, 'Burst', 'StarwickerATK', localBurstTalentLevel(talentLevel, constellation));
                    dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, getFieldOrDefault(build, 'BurstDMGBonus', 0), critRate, critDMG);
                    heal = heal + localTickHeal(atk, build, talent, talentLevel, constellation);
                    state.StarwickerStacks = max(0, state.StarwickerStacks - 1);
                    note = sprintf('Starwicker trigger, stacks=%d', state.StarwickerStacks);
                else
                    note = "Starwicker inactive";
                end

            case {'NA1', 'NA2', 'NA3', 'NA4'}
                mv = getTalentValue(talent, 'Normal', erase(char(action), 'NA') + "ATK", talentLevel); %#ok<CHARTEN>
                dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, getFieldOrDefault(build, 'NormalDMGBonus', 0), critRate, critDMG);
                note = "Normal attack";

            case 'CA'
                mv = getTalentValue(talent, 'Normal', 'ChargedATK', talentLevel);
                dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, getFieldOrDefault(build, 'ChargedDMGBonus', 0), critRate, critDMG);
                note = "Charged attack";

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        totalHeal = totalHeal + heal;
        breakdown = [breakdown; {action, dmg, note}]; %#ok<AGROW>
        if heal > 0
            breakdown = [breakdown; {action + "_Heal", heal, "Healing"}]; %#ok<AGROW>
        end
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if totalHeal > 0
        breakdown = [breakdown; {string("Heal"), totalHeal, "Total healing"}]; %#ok<AGROW>
    end
    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;

    if nargout > 4
        auditOverrides = struct( ...
            'e', struct('ApplyGaugeSource', "not_applicable", 'ICDSource', "not_applicable"));
        audit = buildInferredReactionAudit( ...
            struct('Name', "Xianyun", 'Constellation', constellation, 'TalentLevel', talentLevel), ...
            actions, teamContext, seqFile, auditOverrides, struct('PrimaryArchetype', "Plunge"));
    else
        audit = struct();
    end
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function dmg = localAnemoDamage(atk, mv, build, teamContext, anemoMult, extraBonus, critRate, critDMG)
    dmgBonus = 1 + getFieldOrDefault(build, 'AnemoDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
    dmg = atk * mv * dmgBonus * calcExpectedCritMultiplier(critRate, critDMG) * anemoMult;
end

function heal = localInitialHeal(atk, build, talent, talentLevel, constellation)
    atkRatio = getTalentValue(talent, 'Burst', 'InitialHealATK', localBurstTalentLevel(talentLevel, constellation));
    flatHeal = getTalentValue(talent, 'Burst', 'InitialHealFlat', localBurstTalentLevel(talentLevel, constellation));
    heal = (atk * atkRatio + flatHeal) * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
end

function heal = localTickHeal(atk, build, talent, talentLevel, constellation)
    atkRatio = getTalentValue(talent, 'Burst', 'TickHealATK', localBurstTalentLevel(talentLevel, constellation));
    flatHeal = getTalentValue(talent, 'Burst', 'TickHealFlat', localBurstTalentLevel(talentLevel, constellation));
    heal = (atk * atkRatio + flatHeal) * (1 + getFieldOrDefault(build, 'HealingBonus', 0));
end

function value = localC6CritBonus(talent, talentLevel, constellation, ladderCount)
    value = 0;
    if constellation < 6
        return;
    end
    switch min(3, ladderCount)
        case 1
            value = getTalentValue(talent, 'Constellation', 'C6CritDMG1', talentLevel);
        case 2
            value = getTalentValue(talent, 'Constellation', 'C6CritDMG2', talentLevel);
        otherwise
            value = getTalentValue(talent, 'Constellation', 'C6CritDMG3', talentLevel);
    end
end

function [value, state] = localConsumeC6CritBonus(state, talent, talentLevel, constellation, ladderCount)
    value = 0;
    if constellation < 6
        return;
    end
    if getFieldOrDefault(state, 'C6WindowTime', 0) <= 1e-9 || getFieldOrDefault(state, 'C6UsesLeft', 0) <= 0
        return;
    end
    value = localC6CritBonus(talent, talentLevel, constellation, ladderCount);
    if value > 0
        state.C6UsesLeft = max(0, state.C6UsesLeft - 1);
    end
end

function note = localAppendNote(baseNote, suffix)
    if strlength(string(baseNote)) == 0
        note = string(suffix);
    else
        note = string(baseNote) + ", " + string(suffix);
    end
end

function rate = localC4HealRate(talent, talentLevel, ladderCount)
    switch min(3, ladderCount)
        case 1
            rate = getTalentValue(talent, 'Constellation', 'C4HealAfter1', talentLevel);
        case 2
            rate = getTalentValue(talent, 'Constellation', 'C4HealAfter2', talentLevel);
        otherwise
            rate = getTalentValue(talent, 'Constellation', 'C4HealAfter3', talentLevel);
    end
end

function state = localAdvanceState(state, actionTime)
    state.BurstTime = max(0, state.BurstTime - actionTime);
    state.C6WindowTime = max(0, state.C6WindowTime - actionTime);
    state.WeaponPlungeBonusTime = max(0, state.WeaponPlungeBonusTime - actionTime);
    state.LastC4HealCooldown = max(0, state.LastC4HealCooldown - actionTime);
    if state.BurstTime <= 0
        state.StarwickerStacks = 0;
    end
    if state.C6WindowTime <= 0
        state.C6UsesLeft = 0;
    end
end

function actionTime = localActionTime(action)
    switch upper(char(action))
        case 'E'
            actionTime = 0.40;
        case 'SKYLADDER'
            actionTime = 0.45;
        case {'PLUNGE1', 'PLUNGE2', 'PLUNGE3', 'DRIFTCLOUDWAVE'}
            actionTime = 0.90;
        case 'Q'
            actionTime = 1.10;
        case 'STARWICKER'
            actionTime = 2.50;
        case {'NA1', 'NA2', 'NA3', 'NA4'}
            actionTime = 0.45;
        case 'CA'
            actionTime = 0.75;
        otherwise
            actionTime = 0.50;
    end
end
