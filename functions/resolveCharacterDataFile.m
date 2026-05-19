function filePath = resolveCharacterDataFile(characterName, fileKind)
    % Resolve a character data file even when the exported filename does
    % not strictly match the canonical `kind_<Character>.ext` pattern.
    %
    % This is mainly used to tolerate legacy/manual datasets such as
    % Furina, where the localized CSV filename differs from the folder key.
    initProjectPaths();

    filePath = "";
    if nargin < 2 || strlength(string(characterName)) == 0
        return;
    end

    fileKind = lower(char(string(fileKind)));
    characterKey = string(regexprep(char(string(characterName)), '[^A-Za-z0-9]', ''));
    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    dataFolder = fullfile(projectRoot, 'data', char(characterKey));
    if exist(dataFolder, 'dir') ~= 7
        return;
    end

    [prefix, extension] = localResolveFilePattern(fileKind, characterKey);
    preferredPath = fullfile(dataFolder, sprintf('%s_%s%s', prefix, char(characterKey), extension));
    if exist(preferredPath, 'file') == 2
        filePath = string(preferredPath);
        return;
    end

    candidates = dir(fullfile(dataFolder, sprintf('%s_*%s', prefix, extension)));
    if isempty(candidates)
        return;
    end
    if numel(candidates) == 1
        filePath = string(fullfile(candidates(1).folder, candidates(1).name));
        return;
    end

    normalizedTarget = localNormalizeToken(characterKey);
    bestIndex = 1;
    bestScore = -inf;
    for i = 1:numel(candidates)
        candidateName = erase(string(candidates(i).name), string(prefix) + "_");
        candidateName = erase(candidateName, string(extension));
        normalizedCandidate = localNormalizeToken(candidateName);
        score = 0;
        if normalizedCandidate == normalizedTarget
            score = score + 10;
        elseif contains(normalizedCandidate, normalizedTarget) || contains(normalizedTarget, normalizedCandidate)
            score = score + 4;
        end
        if score > bestScore
            bestScore = score;
            bestIndex = i;
        end
    end

    filePath = string(fullfile(candidates(bestIndex).folder, candidates(bestIndex).name));
end

function [prefix, extension] = localResolveFilePattern(fileKind, characterKey)
    switch fileKind
        case 'characters'
            prefix = 'characters';
            extension = '.csv';
        case 'talents'
            prefix = 'talents';
            extension = '.csv';
        case 'artifacts'
            prefix = 'artifacts';
            extension = '.csv';
        case 'rotation'
            prefix = 'rotation';
            extension = '.txt';
        case 'lunaris'
            prefix = 'lunaris';
            extension = '.json';
        otherwise
            prefix = fileKind;
            extension = '.csv';
    end

    if strcmp(prefix, 'lunaris')
        extension = '.json';
    elseif strcmp(prefix, 'rotation')
        extension = '.txt';
    else
        extension = '.csv';
    end

    %#ok<NASGU>
    characterKey = characterKey;
end

function token = localNormalizeToken(value)
    token = string(lower(regexprep(char(string(value)), '[^a-z0-9]', '')));
end
