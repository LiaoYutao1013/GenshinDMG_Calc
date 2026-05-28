function summary = generateImportedCharacterScaffolds(characterList, options)
    % 批量为“已有数据包、但尚未补齐函数包装层/分析入口”的角色生成脚手架。
    % 生成内容包括：
    % 1. functions/<Character>/customArtifact_<Character>.m
    % 2. functions/<Character>/simulate<Character>DPS.m
    % 3. analysis/main<Character>Full.m
    %
    % 这些文件当前都只是接入统一通用模拟器的薄包装层，目的是先把角色
    % 纳入当前工程的统一入口、GUI 和配队模拟主干。后续逐角色高精度细抠时，
    % 可以直接替换对应包装文件内部实现，而不影响外层调用方式。
    initProjectPaths();

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);

    if nargin < 1 || isempty(characterList)
        characterList = localDetectPendingCharacters(projectRoot);
    end
    if nargin < 2
        options = struct();
    end
    materializeArtifacts = logical(getFieldOrDefault(options, 'MaterializeArtifacts', false));
    characterList = string(characterList(:));

    rows = repmat(struct( ...
        'Character', "", ...
        'FunctionFolderCreated', false, ...
        'ArtifactWrapperCreated', false, ...
        'SimulatorWrapperCreated', false, ...
        'AnalysisEntryCreated', false, ...
        'ArtifactMaterialized', false, ...
        'Status', "", ...
        'Message', ""), numel(characterList), 1);

    for i = 1:numel(characterList)
        key = strtrim(characterList(i));
        rows(i).Character = key;
        try
            [rows(i).FunctionFolderCreated, rows(i).ArtifactWrapperCreated, rows(i).SimulatorWrapperCreated] = ...
                localEnsureFunctionScaffold(projectRoot, key);
            rows(i).AnalysisEntryCreated = localEnsureAnalysisEntry(projectRoot, key);

            % 是否顺带物化默认构筑文件由调用方决定。
            % 默认只补齐函数/分析脚手架，避免批量生成时反复触发武器表与
            % 分件模型构筑，导致整轮导入明显变慢。
            if materializeArtifacts
                buildGenericCharacterArtifact(key);
                rows(i).ArtifactMaterialized = true;
            end

            rows(i).Status = "ok";
            rows(i).Message = "scaffolded";
        catch ME
            rows(i).Status = "error";
            rows(i).Message = string(ME.message);
        end
    end

    summary = struct2table(rows);
end

function characterList = localDetectPendingCharacters(projectRoot)
    dataDir = fullfile(projectRoot, 'data');
    analysisDir = fullfile(projectRoot, 'analysis');
    functionsDir = fullfile(projectRoot, 'functions');

    entries = dir(dataDir);
    characterList = strings(0, 1);
    for i = 1:numel(entries)
        if ~entries(i).isdir
            continue;
        end

        key = string(entries(i).name);
        if startsWith(key, ".") || any(key == ["lunaris", "presets"])
            continue;
        end

        dataFolder = fullfile(entries(i).folder, entries(i).name);
        hasCharacterCsv = ~isempty(dir(fullfile(dataFolder, 'characters_*.csv')));
        if ~hasCharacterCsv
            continue;
        end

        functionFolder = fullfile(functionsDir, char(key));
        artifactWrapper = fullfile(functionFolder, sprintf('customArtifact_%s.m', char(key)));
        simulatorWrapper = fullfile(functionFolder, sprintf('simulate%sDPS.m', char(key)));
        analysisEntry = fullfile(analysisDir, sprintf('main%sFull.m', char(key)));

        if exist(artifactWrapper, 'file') ~= 2 || exist(simulatorWrapper, 'file') ~= 2 || exist(analysisEntry, 'file') ~= 2
            characterList(end + 1, 1) = key; %#ok<AGROW>
        end
    end
end

function [createdFolder, createdArtifactWrapper, createdSimulatorWrapper] = localEnsureFunctionScaffold(projectRoot, key)
    functionFolder = fullfile(projectRoot, 'functions', char(key));
    createdFolder = false;
    createdArtifactWrapper = false;
    createdSimulatorWrapper = false;

    if exist(functionFolder, 'dir') ~= 7
        mkdir(functionFolder);
        createdFolder = true;
    end

    artifactWrapper = fullfile(functionFolder, sprintf('customArtifact_%s.m', char(key)));
    if exist(artifactWrapper, 'file') ~= 2
        localWriteTextFile(artifactWrapper, localRenderArtifactWrapper(key));
        createdArtifactWrapper = true;
    end

    simulatorWrapper = fullfile(functionFolder, sprintf('simulate%sDPS.m', char(key)));
    if exist(simulatorWrapper, 'file') ~= 2
        localWriteTextFile(simulatorWrapper, localRenderSimulatorWrapper(key));
        createdSimulatorWrapper = true;
    end
end

function created = localEnsureAnalysisEntry(projectRoot, key)
    analysisPath = fullfile(projectRoot, 'analysis', sprintf('main%sFull.m', char(key)));
    created = false;
    if exist(analysisPath, 'file') == 2
        return;
    end

    localWriteTextFile(analysisPath, localRenderAnalysisScript(key));
    created = true;
end

function text = localRenderArtifactWrapper(key)
    text = sprintf([ ...
        'function build = customArtifact_%1$s()\n' ...
        '    %% 通用导入角色默认构筑包装器。\n' ...
        '    %% 当前先复用统一默认构筑生成器，后续逐角色高精度校准时可直接替换。\n' ...
        '    build = buildGenericCharacterArtifact(''%1$s'');\n' ...
        'end\n'], char(key));
end

function text = localRenderSimulatorWrapper(key)
    text = sprintf([ ...
        'function [totalDMG, dps, breakdown, rotationTime] = simulate%1$sDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)\n' ...
        '    %% 通用导入角色 DPS 包装器。\n' ...
        '    %% 当前先接入统一通用模拟主干，后续逐角色细抠后再替换为专用实现。\n' ...
        '    [totalDMG, dps, breakdown, rotationTime] = simulateImportedCharacterDPS( ...\n' ...
        '        ''%1$s'', build, enemy, seqFile, talentLevel, constellation, teamContext);\n' ...
        'end\n'], char(key));
end

function text = localRenderAnalysisScript(key)
    text = sprintf([ ...
        'clear; clc; close all;\n' ...
        'projectRoot = fileparts(fileparts(mfilename(''fullpath'')));\n' ...
        'addpath(genpath(fullfile(projectRoot, ''functions'')));\n' ...
        'initProjectPaths();\n' ...
        '\n' ...
        'enemy = struct(''Level'', 90, ''Res'', 0.10, ''DefReduct'', 0);\n' ...
        'constellation = 0;\n' ...
        'cfg = getDefaultCharacterConfig(''%1$s'', struct(''Constellation'', constellation));\n' ...
        '\n' ...
        '[totalDMG, dps, breakdown, rotationTime] = simulate%1$sDPS( ...\n' ...
        '    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);\n' ...
        '\n' ...
        'fprintf(''==================== %%s ====================\\n'', char(cfg.DisplayName));\n' ...
        'fprintf(''Constellation: C%%d\\n'', cfg.Constellation);\n' ...
        'fprintf(''Total Damage: %%.0f\\n'', totalDMG);\n' ...
        'fprintf(''DPS: %%.0f\\n'', dps);\n' ...
        'fprintf(''Rotation Time: %%.2f s\\n'', rotationTime);\n' ...
        'disp(breakdown);\n'], char(key));
end

function localWriteTextFile(filePath, text)
    fid = fopen(filePath, 'w');
    if fid == -1
        error('Unable to open file for write: %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', text);
end
