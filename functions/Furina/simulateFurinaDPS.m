function [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS(build, enemy, seqFile, talentLevel, constellation)
% This simulator is driven by a plain-text action list so both standalone
% and team-level entries can reuse the same action mapping.
% Furina's rotation includes stance switches and non-damage support rows,
% so the breakdown keeps notes in addition to numeric damage.
% simulateFurinaDPS - 芙宁娜单角色循环伤害模拟

thisFolder = fileparts(mfilename('fullpath'));
dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Furina');

if nargin < 3 || isempty(seqFile)
    seqFile = fullfile(dataFolder, 'rotation_Furina.txt');
end
if nargin < 4 || isempty(talentLevel)
    talentLevel = 10;
end
if nargin < 5 || isempty(constellation)
    constellation = 0;
end

base = readtable(fullfile(dataFolder, 'characters_芙宁娜.csv'));
talent = readtable(fullfile(dataFolder, 'talents_Furina_VerL.csv'));

% Map compact rotation tokens to the exact talent rows used by the generic
% table lookup helper.
mapping = struct( ...
    'N1', struct('Skill', '独舞之邀', 'Param', '一段伤害'), ...
    'N2', struct('Skill', '独舞之邀', 'Param', '二段伤害'), ...
    'N3', struct('Skill', '独舞之邀', 'Param', '三段伤害'), ...
    'N4', struct('Skill', '独舞之邀', 'Param', '四段伤害'), ...
    'Heavy', struct('Skill', '独舞之邀', 'Param', '重击伤害'), ...
    'SwitchAr', struct('Skill', '独舞之邀', 'Param', '重击伤害', 'Mode', '荒性'), ...
    'SwitchMa', struct('Skill', '独舞之邀', 'Param', '重击伤害', 'Mode', '芒性'), ...
    'E', struct('Skill', '孤心沙龙', 'Param', '荒性泡沫伤害'), ...
    'Usher', struct('Skill', '孤心沙龙', 'Param', '乌瑟勋爵伤害'), ...
    'Chev', struct('Skill', '孤心沙龙', 'Param', '海薇玛夫人伤害'), ...
    'Crab', struct('Skill', '孤心沙龙', 'Param', '谢贝蕾妲小姐伤害'), ...
    'Singer', struct('Skill', '孤心沙龙', 'Param', '众水的歌者治疗量'), ...
    'Q', struct('Skill', '万众狂欢', 'Param', '技能伤害'), ...
    'Thorn', struct('Skill', '独舞之邀', 'Param', '灵息之刺/流涌之刃伤害'), ...
    'Plunge', struct('Skill', '独舞之邀', 'Param', '低空/高空坠地冲击伤害') ...
);

actions = readRotationTokens(seqFile);
rotationTime = 20;

% Precompute the rotation-wide multipliers once because most actions reuse them.
maxHP = base.BaseHP(1) * (1 + build.HPBonus) + 5000;
critMult = calcExpectedCritMultiplier(build.CritRate, build.CritDMG);
damageMult = calcDamageMultiplier(90, enemy, getFieldOrDefault(build, 'ResShred', 0));
hydroBonus = 1 + getFieldOrDefault(build, 'HydroDMGBonus', 0);
teamMult = max(1, getFieldOrDefault(build, 'TeamHPAbove50Mult', 1));

totalDMG = 0;
breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
    'VariableNames', {'Action', 'Damage', 'Note'});

currentMode = "荒性";
for i = 1:numel(actions)
    actKey = actions{i};
    if ~isfield(mapping, actKey)
        continue;
    end

    % Some tokens only mutate state or mark healing/support events, so
    % they are recorded in the breakdown but intentionally add no damage.
    info = mapping.(actKey);
    note = "";

    if strcmp(actKey, 'SwitchAr')
        currentMode = "荒性";
        breakdown = [breakdown; {string(actKey), 0, "切换至荒性"}]; %#ok<AGROW>
        continue;
    end
    if strcmp(actKey, 'SwitchMa')
        currentMode = "芒性";
        breakdown = [breakdown; {string(actKey), 0, "切换至芒性"}]; %#ok<AGROW>
        continue;
    end
    if strcmp(actKey, 'Singer')
        breakdown = [breakdown; {string(actKey), 0, "治疗动作，不计伤害"}]; %#ok<AGROW>
        continue;
    end

    mv = getTalentValue(talent, info.Skill, info.Param, talentLevel) * maxHP;
    dmg = mv * hydroBonus * critMult * damageMult;

    if any(strcmp(actKey, {'Usher', 'Chev', 'Crab'})) && currentMode == "荒性"
        dmg = dmg * teamMult;
        note = "沙龙成员";
    elseif any(strcmp(actKey, {'Usher', 'Chev', 'Crab'})) && currentMode == "芒性"
        dmg = 0;
        note = "芒性下不造成该段伤害";
    elseif strcmp(actKey, 'Q')
        note = "元素爆发";
    end

    if constellation >= 2
        dmg = dmg * 1.25;
        note = strtrim(note + " C2");
    end
    if constellation >= 6 && any(strcmp(actKey, {'N1', 'N2', 'N3', 'N4', 'Heavy', 'Plunge'}))
        dmg = dmg + maxHP * 0.40 * hydroBonus * critMult * damageMult;
        note = strtrim(note + " C6");
    end

    totalDMG = totalDMG + dmg;
    breakdown = [breakdown; {string(actKey), dmg, note}]; %#ok<AGROW>
end

dps = totalDMG / rotationTime;
end
