function catalog = getLunarisArtifactCatalog()
    % 读取项目内缓存的 Lunaris 圣遗物目录。
    % GUI 展示层、图标层与套装注册表统一从这里取本地数据，
    % 避免运行时再访问网络接口。
    persistent cachedCatalog cachedPath cachedStamp

    root = localProjectRoot();
    indexPath = fullfile(root, 'data', 'lunaris', 'artifacts', 'index.json');
    if exist(indexPath, 'file') ~= 2
        catalog = struct('Version', "", 'GeneratedAt', "", 'Artifacts', []);
        return;
    end

    fileInfo = dir(indexPath);
    fileStamp = "";
    if ~isempty(fileInfo)
        fileStamp = string(sprintf('%s_%d', fileInfo.date, fileInfo.bytes));
    end

    if ~isempty(cachedCatalog) && isequal(cachedPath, string(indexPath)) && isequal(cachedStamp, fileStamp)
        catalog = cachedCatalog;
        return;
    end

    rawText = fileread(indexPath);
    if ~isempty(rawText) && double(rawText(1)) == 65279
        rawText = rawText(2:end);
    end
    parsed = jsondecode(rawText);
    if ~isfield(parsed, 'Artifacts')
        parsed.Artifacts = [];
    end

    cachedCatalog = parsed;
    cachedPath = string(indexPath);
    cachedStamp = fileStamp;
    catalog = parsed;
end

function root = localProjectRoot()
    thisFile = mfilename('fullpath');
    root = fileparts(fileparts(thisFile));
end
