function imagePath = getEquipmentBadge(kind, key, displayName, subLabel, cacheDir, accentColor)
    % 返回武器 / 圣遗物图标路径。
    % 资源策略改为项目内 art 目录优先：
    % 1. 优先使用 art/weapons 或 art/artifacts 中的真实素材；
    % 2. 若旧缓存目录已有素材，则迁移 / 复用；
    % 3. 本地不存在时才联网下载，并保存回 art；
    % 4. 仍失败时，再回退到本地生成的 badge。
    if nargin < 6 || isempty(accentColor)
        accentColor = [0.52 0.62 0.78];
    end

    [assetDir, legacyDir] = localResolveAssetDirs(kind, cacheDir);
    localEnsureDir(assetDir);
    localEnsureDir(legacyDir);

    [fileStem, remoteUrl] = localResolveRemoteAsset(kind, key);
    if strlength(fileStem) == 0
        fileStem = localSafeFileStem(key);
    end

    imagePath = fullfile(assetDir, char(fileStem + ".png"));
    legacyPath = fullfile(legacyDir, char(fileStem + ".png"));
    failMarkerPath = fullfile(assetDir, char(fileStem + ".missing"));
    badgePath = fullfile(assetDir, char(fileStem + "_badge.png"));

    if isfile(imagePath)
        return;
    end
    if legacyDir ~= string(assetDir) && isfile(legacyPath)
        copyfile(legacyPath, imagePath);
        if isfile(imagePath)
            return;
        end
    end

    if ~isfile(failMarkerPath) && strlength(remoteUrl) > 0
        try
            websave(imagePath, char(remoteUrl), weboptions('Timeout', 5));
        catch
            % 真实图标下载失败时，后续自动回退到本地 badge。
        end
        if ~isfile(imagePath)
            localWriteFailMarker(failMarkerPath);
        end
    end

    if isfile(imagePath)
        return;
    end
    if isfile(badgePath)
        imagePath = badgePath;
        return;
    end

    localCreateBadge(badgePath, kind, displayName, subLabel, accentColor);
    imagePath = badgePath;
end

function [assetDir, legacyDir] = localResolveAssetDirs(kind, cacheDir)
    projectRoot = localProjectRoot();
    folderName = localKindFolderName(kind);
    assetDir = string(fullfile(projectRoot, 'art', folderName));

    if nargin < 2 || strlength(string(cacheDir)) == 0
        legacyDir = assetDir;
        return;
    end

    rawDir = string(cacheDir);
    [~, folderTail] = fileparts(char(rawDir));
    if strcmpi(folderTail, 'art')
        legacyDir = string(fullfile(char(rawDir), folderName));
    else
        legacyDir = rawDir;
    end
end

function folderName = localKindFolderName(kind)
    switch lower(char(string(kind)))
        case 'artifact'
            folderName = 'artifacts';
        case 'weapon'
            folderName = 'weapons';
        otherwise
            folderName = 'misc';
    end
end

function [fileStem, remoteUrl] = localResolveRemoteAsset(kind, key)
    kind = lower(char(string(kind)));
    switch kind
        case 'artifact'
            [fileStem, remoteUrl] = localResolveArtifactAsset(key);
        case 'weapon'
            iconKey = localLookupWeaponIconKey(key);
            if strlength(iconKey) > 0
                fileStem = iconKey;
                remoteUrl = "https://enka.network/ui/" + iconKey + ".png";
            else
                fileStem = localSafeFileStem(key);
                remoteUrl = "";
            end
        otherwise
            fileStem = localSafeFileStem(key);
            remoteUrl = "";
    end
end

function [fileStem, remoteUrl] = localResolveArtifactAsset(setId)
    fileStem = localSafeFileStem(setId);
    remoteUrl = "";
    registry = getArtifactSetRegistry();
    idx = find(string({registry.Id}) == string(setId), 1, 'first');
    if isempty(idx)
        return;
    end

    iconKey = string(getFieldOrDefault(registry(idx), 'IconKey', ""));
    if strlength(iconKey) == 0
        return;
    end
    fileStem = iconKey;
    remoteUrl = "https://api.lunaris.moe/data/assets/artifacts/" + iconKey + ".png";
end

function iconKey = localLookupWeaponIconKey(weaponName)
    iconKey = "";
    persistent weaponIndex

    if isempty(weaponIndex)
        weaponIndex = localBuildWeaponIconIndex();
    end

    normalizedName = localNormalizeLookupKey(weaponName);
    normalizedNames = string({weaponIndex.NormalizedName});
    idx = find(normalizedNames == normalizedName, 1, 'first');
    if ~isempty(idx)
        iconKey = string(weaponIndex(idx).IconKey);
        return;
    end

    aliasEntries = { ...
        'craneechoingcall', 'UI_EquipIcon_Catalyst_MountainGale'; ...
        'cranesechoingcall', 'UI_EquipIcon_Catalyst_MountainGale'; ...
        'crane''sechoingcall', 'UI_EquipIcon_Catalyst_MountainGale'; ...
        'favoniuslance', 'UI_EquipIcon_Pole_Zephyrus'; ...
        'rightfulreward', 'UI_EquipIcon_Pole_Mechanic'; ...
        'keyofkhajnisut', 'UI_EquipIcon_Sword_Deshret'; ...
        'tomeoftheeternalflow', 'UI_EquipIcon_Catalyst_Iudex'; ...
        'silvershowerheartstrings', 'UI_EquipIcon_Sword_Regalis'; ...
        'angelosheptades', 'UI_EquipIcon_Catalyst_MountainGale' ...
    };
    for i = 1:size(aliasEntries, 1)
        if normalizedName == aliasEntries{i, 1}
            iconKey = string(aliasEntries{i, 2});
            return;
        end
    end
end

function index = localBuildWeaponIconIndex()
    index = struct('Name', {}, 'NormalizedName', {}, 'IconKey', {});

    projectRoot = localProjectRoot();
    jsPath = fullfile(projectRoot, 'data', 'WeaponExcelConfigData.js');
    if exist(jsPath, 'file') ~= 2
        return;
    end

    raw = fileread(jsPath);
    pattern = '"Name"\s*:\s*"([^"]+)"[\s\S]*?"Icons"\s*:\s*"([^"]+)"';
    tokens = regexp(raw, pattern, 'tokens');
    for i = 1:numel(tokens)
        name = string(tokens{i}{1});
        icon = string(tokens{i}{2});
        index(end + 1) = struct( ... %#ok<AGROW>
            'Name', name, ...
            'NormalizedName', localNormalizeLookupKey(name), ...
            'IconKey', icon);
    end
end

function normalized = localNormalizeLookupKey(text)
    normalized = lower(regexprep(char(string(text)), '[^a-zA-Z0-9\u4e00-\u9fa5]', ''));
    normalized = string(normalized);
end

function fileStem = localSafeFileStem(key)
    fileStem = string(regexprep(char(string(key)), '[\\/:*?"<>|]', '_'));
end

function localCreateBadge(imagePath, kind, displayName, subLabel, accentColor)
    width = 256;
    height = 256;
    try
        f = figure('Visible', 'off', 'Color', [0.08 0.11 0.16], 'Position', [100 100 width height]);
        ax = axes(f, 'Position', [0 0 1 1]);
        axis(ax, [0 1 0 1]);
        axis(ax, 'off');
        hold(ax, 'on');

        patch(ax, [0 1 1 0], [0 0 1 1], [0.10 0.12 0.18], 'EdgeColor', 'none');
        patch(ax, [0 1 1 0], [0.42 0.26 1 1], accentColor * 0.42 + 0.10, 'EdgeColor', 'none');
        rectangle(ax, 'Position', [0.06 0.06 0.88 0.88], 'Curvature', 0.08, ...
            'FaceColor', [0.98 0.98 0.99] * 0.10, ...
            'EdgeColor', accentColor * 0.85 + 0.15, ...
            'LineWidth', 4);

        text(ax, 0.50, 0.77, upper(localSymbol(kind)), ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 56, ...
            'FontWeight', 'bold', ...
            'Color', [0.98 0.95 0.90]);

        text(ax, 0.50, 0.48, char(localTrim(displayName, 16)), ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 18, ...
            'FontWeight', 'bold', ...
            'Color', [0.98 0.98 0.98]);

        if strlength(string(subLabel)) > 0
            text(ax, 0.50, 0.23, char(localTrim(subLabel, 22)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12, ...
                'Color', [0.92 0.92 0.94]);
        end

        exportgraphics(ax, imagePath, 'Resolution', 120);
        close(f);
    catch
        if exist('f', 'var') && isvalid(f)
            close(f);
        end
        localFallbackImage(imagePath, accentColor);
    end

    if ~isfile(imagePath)
        localFallbackImage(imagePath, accentColor);
    end
end

function symbol = localSymbol(kind)
    switch lower(char(string(kind)))
        case 'weapon'
            symbol = 'W';
        case 'artifact'
            symbol = 'A';
        otherwise
            symbol = 'E';
    end
end

function output = localTrim(inputText, maxLen)
    txt = char(string(inputText));
    if strlength(string(txt)) <= maxLen
        output = txt;
    else
        output = char(extractBefore(string(txt), maxLen) + ".");
    end
end

function localFallbackImage(imagePath, accentColor)
    width = 256;
    height = 256;
    img = uint8(zeros(height, width, 3));
    x = linspace(0, 1, width);
    y = linspace(0, 1, height).';
    xGrid = repmat(x, height, 1);
    yGrid = repmat(y, 1, width);
    img(:, :, 1) = uint8(40 + 120 * xGrid * accentColor(1));
    img(:, :, 2) = uint8(45 + 120 * yGrid * accentColor(2));
    img(:, :, 3) = uint8(55 + 110 * (1 - yGrid) * accentColor(3));
    imwrite(img, imagePath);
end

function root = localProjectRoot()
    thisFolder = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(thisFolder));
end

function localEnsureDir(dirPath)
    if exist(char(dirPath), 'dir') ~= 7
        mkdir(char(dirPath));
    end
end

function localWriteFailMarker(markerPath)
    fid = fopen(markerPath, 'w');
    if fid ~= -1
        fclose(fid);
    end
end
