function imagePath = getEquipmentBadge(kind, key, displayName, subLabel, cacheDir, accentColor)
    % 为 GUI 生成装备图标。
    % 优先级如下：
    % 1. 若能解析到真实图标资源，则下载并缓存真实图标；
    % 2. 若无法解析或下载失败，则回退到本地生成的 badge 图。
    if nargin < 5 || strlength(string(cacheDir)) == 0
        cacheDir = fullfile(tempdir, 'genshin_dmg_calc_equipment');
    end
    if exist(cacheDir, 'dir') ~= 7
        mkdir(cacheDir);
    end
    if nargin < 6 || isempty(accentColor)
        accentColor = [0.52 0.62 0.78];
    end

    safeKind = regexprep(char(string(kind)), '[^a-zA-Z0-9_-]', '_');
    safeKey = regexprep(char(string(key)), '[^a-zA-Z0-9_-]', '_');

    remoteIconPath = fullfile(cacheDir, sprintf('%s_%s_icon.png', safeKind, safeKey));
    failMarkerPath = fullfile(cacheDir, sprintf('%s_%s_icon.missing', safeKind, safeKey));
    badgePath = fullfile(cacheDir, sprintf('%s_%s_badge.png', safeKind, safeKey));

    if isfile(remoteIconPath)
        imagePath = remoteIconPath;
        return;
    end

    if ~isfile(failMarkerPath)
        remoteUrl = localResolveRemoteIconUrl(kind, key);
        if strlength(remoteUrl) > 0
            try
                websave(remoteIconPath, char(remoteUrl), weboptions('Timeout', 2));
            catch
                % 下载真实图标失败时，回退到本地 badge。
            end
        end

        if ~isfile(remoteIconPath)
            fid = fopen(failMarkerPath, 'w');
            if fid ~= -1
                fclose(fid);
            end
        end
    end

    if isfile(remoteIconPath)
        imagePath = remoteIconPath;
        return;
    end

    if isfile(badgePath)
        imagePath = badgePath;
        return;
    end

    localCreateBadge(badgePath, kind, displayName, subLabel, accentColor);
    imagePath = badgePath;
end

function remoteUrl = localResolveRemoteIconUrl(kind, key)
    switch lower(char(string(kind)))
        case 'artifact'
            remoteUrl = localResolveArtifactIconUrl(key);
        case 'weapon'
            remoteUrl = localResolveWeaponIconUrl(key);
        otherwise
            remoteUrl = "";
    end
end

function remoteUrl = localResolveArtifactIconUrl(setId)
    remoteUrl = "";
    registry = getArtifactSetRegistry();
    idx = find(string({registry.Id}) == string(setId), 1, 'first');
    if isempty(idx)
        return;
    end

    slug = string(registry(idx).ApiSlug);
    if strlength(slug) == 0
        return;
    end

    try
        apiUrl = sprintf('https://genshin-db-api.vercel.app/api/v5/artifacts?vh=1&query=%s', char(slug));
        payload = webread(apiUrl, weboptions('Timeout', 2));
        if isstruct(payload) && isfield(payload, 'images') && isfield(payload.images, 'flower')
            remoteUrl = string(payload.images.flower);
        end
    catch
        remoteUrl = "";
    end
end

function remoteUrl = localResolveWeaponIconUrl(weaponName)
    remoteUrl = "";
    iconKey = localLookupWeaponIconKey(weaponName);
    if strlength(iconKey) == 0
        return;
    end
    remoteUrl = "https://enka.network/ui/" + iconKey + ".png";
end

function iconKey = localLookupWeaponIconKey(weaponName)
    iconKey = "";
    persistent weaponIndex

    if isempty(weaponIndex)
        weaponIndex = localBuildWeaponIconIndex();
    end

    normalizedName = localNormalizeLookupKey(weaponName);
    names = string({weaponIndex.Name});
    normalizedNames = string({weaponIndex.NormalizedName});
    idx = find(normalizedNames == normalizedName, 1, 'first');
    if ~isempty(idx)
        iconKey = string(weaponIndex(idx).IconKey);
        return;
    end

    % 少量默认英文别名在本地武器表中不一定能精确匹配，这里补一个手工映射。
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

    thisFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(thisFolder));
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
