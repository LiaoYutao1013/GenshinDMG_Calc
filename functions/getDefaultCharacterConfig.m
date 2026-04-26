function cfg = getDefaultCharacterConfig(name, overrides)
    % 根据角色名生成统一默认配置。
    % 返回结构统一包含角色名、显示名、命座、天赋等级、默认构筑和
    % 默认轮转文件，是单人模拟和配队模拟共同使用的配置入口。
    initProjectPaths();
    if nargin < 2
        overrides = struct();
    end

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    key = lower(strtrim(char(string(name))));

    % 所有可用角色都在这里集中注册，统一维护默认轮转和默认构筑。
    switch key
        case {'skirk'}
            cfg = struct('Name', 'Skirk', 'DisplayName', "Skirk", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Skirk(), 'RotationFile', fullfile(projectRoot, 'data', 'Skirk', 'rotation_Skirk.txt'));
        case {'escoffier'}
            cfg = struct('Name', 'Escoffier', 'DisplayName', "Escoffier", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Escoffier(), 'RotationFile', fullfile(projectRoot, 'data', 'Escoffier', 'rotation_Escoffier.txt'));
        case {'arlecchino'}
            cfg = struct('Name', 'Arlecchino', 'DisplayName', "Arlecchino", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Arlecchino(), 'RotationFile', fullfile(projectRoot, 'data', 'Arlecchino', 'rotation_Arlecchino.txt'));
        case {'furina'}
            furinaBuild = readtable(fullfile(projectRoot, 'data', 'Furina', 'artifacts_Furina.csv'));
            cfg = struct('Name', 'Furina', 'DisplayName', "Furina", 'TalentLevel', 10, 'Constellation', 6, ...
                'Build', table2struct(furinaBuild(1, :)), 'RotationFile', fullfile(projectRoot, 'data', 'Furina', 'rotation_Furina.txt'));
        case {'lauma', '菈乌玛'}
            cfg = struct('Name', 'Lauma', 'DisplayName', "菈乌玛", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Lauma(), 'RotationFile', fullfile(projectRoot, 'data', 'Lauma', 'rotation_Lauma.txt'));
        case {'ineffa', '伊涅芙'}
            cfg = struct('Name', 'Ineffa', 'DisplayName', "伊涅芙", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Ineffa(), 'RotationFile', fullfile(projectRoot, 'data', 'Ineffa', 'rotation_Ineffa.txt'));
        case {'linnea', 'linnia', '莉奈娅'}
            cfg = struct('Name', 'Linnea', 'DisplayName', "莉奈娅", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Linnea(), 'RotationFile', fullfile(projectRoot, 'data', 'Linnea', 'rotation_Linnea.txt'));
        case {'nilou', '妮露'}
            cfg = struct('Name', 'Nilou', 'DisplayName', "妮露", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Nilou(), 'RotationFile', fullfile(projectRoot, 'data', 'Nilou', 'rotation_Nilou.txt'));
        case {'nefer', '奈芙尔'}
            cfg = struct('Name', 'Nefer', 'DisplayName', "奈芙尔", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Nefer(), 'RotationFile', fullfile(projectRoot, 'data', 'Nefer', 'rotation_Nefer.txt'));
        case {'flins', '菲林斯'}
            cfg = struct('Name', 'Flins', 'DisplayName', "菲林斯", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Flins(), 'RotationFile', fullfile(projectRoot, 'data', 'Flins', 'rotation_Flins.txt'));
        case {'zibai', '兹白'}
            cfg = struct('Name', 'Zibai', 'DisplayName', "兹白", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Zibai(), 'RotationFile', fullfile(projectRoot, 'data', 'Zibai', 'rotation_Zibai.txt'));
        case {'mualani', '玛拉妮'}
            cfg = struct('Name', 'Mualani', 'DisplayName', "玛拉妮", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Mualani(), 'RotationFile', fullfile(projectRoot, 'data', 'Mualani', 'rotation_Mualani.txt'));
        case {'mavuika', '玛薇卡'}
            cfg = struct('Name', 'Mavuika', 'DisplayName', "玛薇卡", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Mavuika(), 'RotationFile', fullfile(projectRoot, 'data', 'Mavuika', 'rotation_Mavuika.txt'));
        case {'citlali', '茜特菈莉'}
            cfg = struct('Name', 'Citlali', 'DisplayName', "茜特菈莉", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Citlali(), 'RotationFile', fullfile(projectRoot, 'data', 'Citlali', 'rotation_Citlali.txt'));
        case {'xilonen', '希诺宁'}
            cfg = struct('Name', 'Xilonen', 'DisplayName', "希诺宁", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Xilonen(), 'RotationFile', fullfile(projectRoot, 'data', 'Xilonen', 'rotation_Xilonen.txt'));
        case {'neuvillette', '那维莱特'}
            cfg = struct('Name', 'Neuvillette', 'DisplayName', "那维莱特", 'TalentLevel', 10, 'Constellation', 0, ...
                'Build', customArtifact_Neuvillette(), 'RotationFile', fullfile(projectRoot, 'data', 'Neuvillette', 'rotation_Neuvillette.txt'));
        otherwise
            error('Unsupported character in unified entry: %s', name);
    end

    cfg = localApplyConfigOverrides(cfg, overrides);
end

function cfg = localApplyConfigOverrides(cfg, overrides)
    % 将调用方提供的覆盖项合并到默认配置上。
    if isempty(overrides)
        return;
    end

    if isfield(overrides, 'Build')
        % Build 子结构单独合并，避免整体替换掉默认构筑的其余字段。
        cfg.Build = applyStructOverrides(cfg.Build, overrides.Build);
        overrides = rmfield(overrides, 'Build');
    end

    if isfield(overrides, 'Name')
        % Name 由默认配置确定，覆盖阶段不允许再修改角色身份。
        overrides = rmfield(overrides, 'Name');
    end

    cfg = applyStructOverrides(cfg, overrides);
end
