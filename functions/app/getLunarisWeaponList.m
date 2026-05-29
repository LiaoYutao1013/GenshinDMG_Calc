function [weaponList, version] = getLunarisWeaponList(projectRoot, forceRefresh)
    if nargin < 1 || strlength(string(projectRoot)) == 0
        projectRoot = localProjectRoot();
    else
        projectRoot = char(string(projectRoot));
    end
    if nargin < 2
        forceRefresh = false;
    end

    weaponList = struct();
    version = "";

    cacheDir = fullfile(projectRoot, 'data', 'lunaris', 'weapons');
    cachePath = fullfile(cacheDir, 'index.json');
    versionPath = fullfile(projectRoot, 'data', 'lunaris', 'version.json');

    if ~forceRefresh
        [weaponList, version] = localReadWeaponListCache(cachePath);
        if localHasWeaponList(weaponList)
            return;
        end
    end

    versions = localResolveLunarisVersions(versionPath, projectRoot);
    for i = 1:numel(versions)
        listUrl = "https://api.lunaris.moe/data/" + versions(i) + "/weaponlist.json";
        try
            remoteList = webread(char(listUrl), weboptions('Timeout', 10));
            weaponList = localNormalizeWeaponList(remoteList);
            version = versions(i);
            localWriteWeaponListCache(cachePath, weaponList, version);
            return;
        catch
        end
    end

    if ~localHasWeaponList(weaponList)
        [weaponList, version] = localReadWeaponListCache(cachePath);
    end
end

function weaponList = localNormalizeWeaponList(rawList)
    weaponList = struct();
    if ~isstruct(rawList)
        return;
    end

    keysList = fieldnames(rawList);
    for i = 1:numel(keysList)
        rawItem = rawList.(keysList{i});
        iconKey = string(getFieldOrDefault(rawItem, 'weaponIcon', getFieldOrDefault(rawItem, 'icon', "")));
        if strlength(iconKey) == 0
            continue;
        end

        item = struct( ...
            'enName', char(string(getFieldOrDefault(rawItem, 'enName', getFieldOrDefault(rawItem, 'name', iconKey)))), ...
            'weaponIcon', char(iconKey), ...
            'weaponType', char(string(getFieldOrDefault(rawItem, 'weaponType', ""))), ...
            'qualityType', char(string(getFieldOrDefault(rawItem, 'qualityType', ""))));
        weaponList.(keysList{i}) = item;
    end
end

function [weaponList, version] = localReadWeaponListCache(cachePath)
    weaponList = struct();
    version = "";
    if exist(cachePath, 'file') ~= 2
        return;
    end

    try
        cached = jsondecode(fileread(cachePath));
    catch
        return;
    end

    if isstruct(cached) && isfield(cached, 'Weapons')
        weaponList = cached.Weapons;
        if isfield(cached, 'Version')
            version = string(cached.Version);
        end
    else
        weaponList = cached;
    end
end

function localWriteWeaponListCache(cachePath, weaponList, version)
    cacheDir = fileparts(cachePath);
    if exist(cacheDir, 'dir') ~= 7
        mkdir(cacheDir);
    end

    payload = struct( ...
        'Version', char(string(version)), ...
        'GeneratedAt', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
        'Weapons', weaponList);

    fid = fopen(cachePath, 'w', 'n', 'UTF-8');
    if fid == -1
        return;
    end
    cleanup = onCleanup(@() fclose(fid));
    try
        fprintf(fid, '%s', jsonencode(payload));
    catch
    end
    clear cleanup;
end

function versions = localResolveLunarisVersions(versionPath, projectRoot)
    versions = strings(1, 0);

    try
        versionData = webread('https://api.lunaris.moe/data/version.json', weboptions('Timeout', 10));
        versions = [versions, localVersionsFromData(versionData)]; %#ok<AGROW>
        localWriteVersionCache(versionPath, versionData);
    catch
    end

    if exist(versionPath, 'file') == 2
        try
            versionData = jsondecode(fileread(versionPath));
            versions = [versions, localVersionsFromData(versionData)]; %#ok<AGROW>
        catch
        end
    end

    artifactIndexPath = fullfile(projectRoot, 'data', 'lunaris', 'artifacts', 'index.json');
    if exist(artifactIndexPath, 'file') == 2
        try
            artifactData = jsondecode(fileread(artifactIndexPath));
            versions(end + 1) = string(getFieldOrDefault(artifactData, 'Version', ""));
        catch
        end
    end

    versions = unique(versions(strlength(versions) > 0), 'stable');
end

function localWriteVersionCache(versionPath, versionData)
    versionDir = fileparts(versionPath);
    if exist(versionDir, 'dir') ~= 7
        mkdir(versionDir);
    end

    fid = fopen(versionPath, 'w', 'n', 'UTF-8');
    if fid == -1
        return;
    end
    cleanup = onCleanup(@() fclose(fid));
    try
        fprintf(fid, '%s', jsonencode(versionData));
    catch
    end
    clear cleanup;
end

function versions = localVersionsFromData(versionData)
    versions = strings(1, 0);
    if isstruct(versionData) || isobject(versionData)
        if isfield(versionData, 'version')
            versions(end + 1) = string(versionData.version);
        end
        if isfield(versionData, 'versions')
            versions = [versions, string(versionData.versions(:).')]; %#ok<AGROW>
        end
    end
end

function tf = localHasWeaponList(weaponList)
    tf = isstruct(weaponList) && ~isempty(fieldnames(weaponList));
end

function root = localProjectRoot()
    thisFolder = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(thisFolder));
end
