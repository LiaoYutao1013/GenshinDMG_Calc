function talentTable = parseTalentFurina(skillFile, charName, version)
    % Parse Furina skill JSON into a flat talent table with raw secondary values.
    if nargin < 3 || strlength(string(version)) == 0
        version = 'L';
    else
        version = char(string(version));
    end
    charName = char(string(charName));

    txt = strtrim(fileread(skillFile));
    txt = regexprep(txt, '^var\s+.*?\=\s*', '');
    txt = regexprep(txt, ';\s*$', '');
    data = jsondecode(txt);

    if ~isfield(data, charName) || ~isfield(data.(charName).Ver, version)
        error('Unable to locate %s Ver%s in %s.', charName, version, skillFile);
    end

    skills = data.(charName).Ver.(version).BattleSkills;
    rows = table();
    for skillIndex = 1:numel(skills)
        skill = skills(skillIndex);
        skillName = string(skill.Name);
        for paramIndex = 1:numel(skill.ParamDesc)
            param = skill.ParamDesc(paramIndex);
            desc = string(param.Desc);
            levelList = string(param.ParamLevelList(:));

            [values, auxValues] = localParseLevelValues(levelList);
            scalingType = localResolveScalingType(desc);
            multiplier = localResolveMultiplier(desc);
            subType = localResolveSubType(skillName, desc);
            isDamage = localIsDamageOrHealing(desc, subType);

            row = table( ...
                skillName, desc, scalingType, multiplier, subType, isDamage, ...
                values(1), values(2), values(3), values(4), values(5), ...
                values(6), values(7), values(8), values(9), values(10), ...
                values(11), values(12), values(13), values(14), values(15), ...
                auxValues(1), auxValues(2), auxValues(3), auxValues(4), auxValues(5), ...
                auxValues(6), auxValues(7), auxValues(8), auxValues(9), auxValues(10), ...
                auxValues(11), auxValues(12), auxValues(13), auxValues(14), auxValues(15), ...
                string(levelList(min(1, numel(levelList)))), ...
                string(levelList(min(10, numel(levelList)))), ...
                string(levelList(min(15, numel(levelList)))), ...
                'VariableNames', { ...
                'Skill', 'Param', 'ScalingType', 'Multiplier', 'SubType', 'IsDamage', ...
                'Level1', 'Level2', 'Level3', 'Level4', 'Level5', ...
                'Level6', 'Level7', 'Level8', 'Level9', 'Level10', ...
                'Level11', 'Level12', 'Level13', 'Level14', 'Level15', ...
                'AuxLevel1', 'AuxLevel2', 'AuxLevel3', 'AuxLevel4', 'AuxLevel5', ...
                'AuxLevel6', 'AuxLevel7', 'AuxLevel8', 'AuxLevel9', 'AuxLevel10', ...
                'AuxLevel11', 'AuxLevel12', 'AuxLevel13', 'AuxLevel14', 'AuxLevel15', ...
                'RawLevel1', 'RawLevel10', 'RawLevel15'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end

    outputFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Furina', ...
        sprintf('talents_%s_Ver%s.csv', charName, version));
    writetable(rows, outputFile);
    if strcmpi(version, 'L')
        genericOutputFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Furina', ...
            sprintf('talents_%s.csv', charName));
        writetable(rows, genericOutputFile);
    end
    talentTable = rows;
end

function [values, auxValues] = localParseLevelValues(levelList)
    values = nan(1, 15);
    auxValues = nan(1, 15);
    for levelIndex = 1:min(15, numel(levelList))
        tokens = regexp(char(levelList(levelIndex)), '([\d\.]+)(%)?', 'tokens');
        if isempty(tokens)
            continue;
        end

        values(levelIndex) = localTokenToValue(tokens, 1);
        auxValues(levelIndex) = localTokenToValue(tokens, 2);
    end
end

function value = localTokenToValue(tokens, index)
    value = NaN;
    if numel(tokens) < index
        return;
    end

    num = str2double(tokens{index}{1});
    if isnan(num)
        return;
    end
    if numel(tokens{index}) > 1 && strcmp(tokens{index}{2}, '%')
        value = num / 100;
    else
        value = num;
    end
end

function scalingType = localResolveScalingType(desc)
    text = string(desc);
    if any(contains(text, ["Max HP", "HP"]))
        scalingType = "MaxHP";
    elseif any(contains(text, ["ATK"]))
        scalingType = "ATK";
    elseif any(contains(text, ["DEF"]))
        scalingType = "DEF";
    elseif any(contains(text, ["EM"]))
        scalingType = "EM";
    else
        scalingType = "None";
    end
end

function multiplier = localResolveMultiplier(desc)
    multiplier = 1;
    match = regexp(char(desc), '[xX](\d+)', 'tokens', 'once');
    if ~isempty(match)
        multiplier = str2double(match{1});
        if isnan(multiplier)
            multiplier = 1;
        end
    end
end

function subType = localResolveSubType(skillName, desc)
    subType = "";
    skillText = string(skillName);
    descText = string(desc);
    if ~any(contains(skillText, ["Salon Members", "沙龙", "侍者"]))
        return;
    end

    if any(contains(descText, ["Usher"]))
        subType = "Usher";
    elseif any(contains(descText, ["Chevalmarin"]))
        subType = "Chevalmarin";
    elseif any(contains(descText, ["Crabaletta"]))
        subType = "Crabaletta";
    elseif any(contains(descText, ["Singer"]))
        subType = "Singer";
    elseif any(contains(descText, ["Healing", "heal"]))
        subType = "Healing";
    end
end

function tf = localIsDamageOrHealing(desc, subType)
    text = string(desc);
    tf = any(contains(text, ["damage", "heal", "HP", "ATK"])) || strlength(subType) > 0;
end
