function imagePath = getEquipmentBadge(kind, key, displayName, subLabel, cacheDir, accentColor)
    % 生成并缓存用于 GUI 展示的装备图标卡片。
    % 当前工程里的武器和套装命名并不完全对应官方资源，因此这里采用
    % “本地生成徽章图标”的方式，确保所有条目都能稳定显示。
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
    imagePath = fullfile(cacheDir, sprintf('%s_%s.png', safeKind, safeKey));
    if isfile(imagePath)
        return;
    end

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
        output = [extractBefore(string(txt), maxLen) '.'];
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
