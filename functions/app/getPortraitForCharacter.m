function imagePath = getPortraitForCharacter(characterName, cacheDir)
    % 为 GUI 返回角色头像文件路径。
    % 优先使用本地缓存；若缓存不存在，则尝试从 enka.network 下载常见头像资源；
    % 若仍失败，则生成一个本地占位图，避免界面报错。
    if nargin < 2 || strlength(string(cacheDir)) == 0
        cacheDir = fullfile(tempdir, 'genshin_dmg_calc_portraits');
    end
    if ~exist(cacheDir, 'dir')
        mkdir(cacheDir);
    end

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
    pngPath = fullfile(cacheDir, [fileBase '.png']);
    if isfile(pngPath)
        imagePath = pngPath;
        return;
    end

    candidateUrls = localBuildAvatarCandidates(avatarKey);
    requestOptions = weboptions('Timeout', 4);
    for i = 1:numel(candidateUrls)
        try
            websave(pngPath, candidateUrls{i}, requestOptions);
            if isfile(pngPath)
                imagePath = pngPath;
                return;
            end
        catch
            % 网络或资源缺失时静默回退到下一个候选地址。
        end
    end

    imagePath = localCreatePlaceholder(cacheDir, fileBase, displayName);
end

function urls = localBuildAvatarCandidates(avatarKey)
    baseUrl = "https://enka.network/ui/";
    urls = { ...
        char(baseUrl + "UI_AvatarIcon_" + avatarKey + ".png"), ...
        char(baseUrl + "UI_Gacha_AvatarIcon_" + avatarKey + ".png"), ...
        char(baseUrl + "UI_Gacha_AvatarImg_" + avatarKey + ".png")};
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
        % 若当前 MATLAB 环境无法无头绘图，则保留基础渐变占位图。
        if exist('f', 'var') && isvalid(f)
            close(f);
        end
    end
end
