function imagePath = getPortraitForCharacter(characterName, cacheDir)
    % 返回角色头像路径。
    % 资源查找顺序调整为：
    % 1. 优先读取项目内 art/portraits 的本地素材；
    % 2. 若旧缓存目录中已有资源，则迁移 / 复用；
    % 3. 若本地不存在，再从 Lunaris 联网下载并保存回 art/portraits；
    % 4. 最后才生成占位图，避免 GUI 直接报错。
    projectRoot = localProjectRoot();
    localDir = fullfile(projectRoot, 'art', 'portraits');
    requestedDir = localNormalizePortraitDir(cacheDir, localDir);
    localEnsureDir(localDir);
    localEnsureDir(requestedDir);

    registry = getCharacterRegistry();
    keys = string({registry.Key});
    idx = find(keys == string(characterName), 1, 'first');
    avatarKey = string(characterName);
    displayName = string(characterName);
    if ~isempty(idx)
        avatarKey = string(registry(idx).AvatarKey);
        displayName = string(registry(idx).DisplayName);
    end

    fileBase = char(avatarKey);
    imagePath = fullfile(localDir, [fileBase '.png']);
    aliasImagePath = fullfile(localDir, [char(string(characterName)) '.png']);
    legacyPath = fullfile(requestedDir, [fileBase '.png']);
    failMarkerPath = fullfile(localDir, [fileBase '.missing']);
    placeholderPath = fullfile(localDir, [fileBase '_placeholder.png']);

    if isfile(imagePath)
        return;
    end
    if isfile(aliasImagePath)
        imagePath = aliasImagePath;
        return;
    end
    if isfile(placeholderPath)
        imagePath = placeholderPath;
        return;
    end
    if requestedDir ~= string(localDir) && isfile(legacyPath)
        copyfile(legacyPath, imagePath);
        if isfile(imagePath)
            return;
        end
    end
    if isfile(failMarkerPath)
        imagePath = localCreatePlaceholder(localDir, fileBase, displayName);
        return;
    end

    candidateUrls = localBuildAvatarCandidates(avatarKey);
    requestOptions = weboptions('Timeout', 5);
    for i = 1:numel(candidateUrls)
        try
            websave(imagePath, candidateUrls{i}, requestOptions);
            if isfile(imagePath)
                return;
            end
        catch
            % 联网下载失败时静默降级到下一个候选地址。
        end
    end

    localDeleteFailedDownloadSidecars(localDir, fileBase);
    localWriteFailMarker(failMarkerPath);
    imagePath = localCreatePlaceholder(localDir, fileBase, displayName);
end

function dirPath = localNormalizePortraitDir(cacheDir, defaultDir)
    if nargin < 1 || strlength(string(cacheDir)) == 0
        dirPath = string(defaultDir);
        return;
    end

    rawDir = string(cacheDir);
    [~, folderName] = fileparts(char(rawDir));
    if strcmpi(folderName, 'art')
        dirPath = fullfile(char(rawDir), 'portraits');
    else
        dirPath = rawDir;
    end
end

function urls = localBuildAvatarCandidates(avatarKey)
    avatarKey = string(avatarKey);
    baseUrl = "https://api.lunaris.moe/data/assets/";
    urls = { ...
        char(baseUrl + "avataricon/UI_AvatarIcon_" + avatarKey + ".png"), ...
        char(baseUrl + "avataricon/UI_AvatarIcon_" + avatarKey + ".webp"), ...
        char(baseUrl + "gachaicon/UI_Gacha_AvatarIcon_" + avatarKey + ".png"), ...
        char(baseUrl + "gachaicon/UI_Gacha_AvatarIcon_" + avatarKey + ".webp")};
end

function imagePath = localCreatePlaceholder(cacheDir, fileBase, displayName)
    imagePath = fullfile(cacheDir, [fileBase '_placeholder.png']);
    if isfile(imagePath)
        return;
    end

    width = 320;
    height = 420;
    img = uint8(zeros(height, width, 3));

    x = linspace(0, 1, width);
    y = linspace(0, 1, height).';
    xGrid = repmat(x, height, 1);
    yGrid = repmat(y, 1, width);
    img(:, :, 1) = uint8(35 + 80 * xGrid);
    img(:, :, 2) = uint8(55 + 90 * yGrid);
    img(:, :, 3) = uint8(90 + 70 * (1 - yGrid));

    cardMask = false(height, width);
    cardMask(25:end-25, 25:end-25) = true;
    for c = 1:3
        channel = img(:, :, c);
        channel(cardMask) = uint8(0.75 * double(channel(cardMask)) + 50);
        img(:, :, c) = channel;
    end

    imwrite(img, imagePath);

    try
        f = figure('Visible', 'off', 'Color', [0.10 0.13 0.19], 'Position', [100 100 width height]);
        ax = axes(f, 'Position', [0 0 1 1]);
        image(ax, img);
        axis(ax, 'image');
        axis(ax, 'off');
        hold(ax, 'on');
        rectangle(ax, 'Position', [24 24 width-48 height-48], 'Curvature', 0.06, ...
            'EdgeColor', [0.92 0.87 0.68], 'LineWidth', 3);
        text(ax, width / 2, 135, 'Portrait', ...
            'Color', [0.94 0.92 0.88], ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 28, ...
            'FontWeight', 'bold');
        text(ax, width / 2, 260, char(displayName), ...
            'Color', [0.98 0.96 0.93], ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 24, ...
            'FontWeight', 'bold');
        exportgraphics(ax, imagePath, 'Resolution', 120);
        close(f);
    catch
        if exist('f', 'var') && isvalid(f)
            close(f);
        end
    end
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

function localDeleteFailedDownloadSidecars(cacheDir, fileBase)
    sidecars = { ...
        fullfile(cacheDir, [fileBase '.png.html']), ...
        fullfile(cacheDir, [fileBase '.webp.html']), ...
        fullfile(cacheDir, [fileBase '.html'])};
    for i = 1:numel(sidecars)
        if isfile(sidecars{i})
            delete(sidecars{i});
        end
    end
end
