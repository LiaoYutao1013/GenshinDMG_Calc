function cfg = getDefaultCharacterConfig(name, overrides)
    % Unified default config registry for standalone and team entries.
    initProjectPaths();
    if nargin < 2
        overrides = struct();
    end

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    key = lower(strtrim(char(string(name))));

    switch key
        case {'skirk'}
            cfg = localBaseConfig('Skirk', customArtifact_Skirk(), fullfile(projectRoot, 'data', 'Skirk', 'rotation_Skirk.txt'));

        case {'escoffier'}
            cfg = localBaseConfig('Escoffier', customArtifact_Escoffier(), fullfile(projectRoot, 'data', 'Escoffier', 'rotation_Escoffier.txt'));

        case {'arlecchino'}
            cfg = localBaseConfig('Arlecchino', customArtifact_Arlecchino(), fullfile(projectRoot, 'data', 'Arlecchino', 'rotation_Arlecchino.txt'));

        case {'furina'}
            cfg = localBaseConfig('Furina', customArtifact_Furina(), fullfile(projectRoot, 'data', 'Furina', 'rotation_Furina.txt'));
            cfg.Constellation = 6;

        case {'columbina'}
            cfg = localBaseConfig('Columbina', customArtifact_Columbina(), fullfile(projectRoot, 'data', 'Columbina', 'rotation_Columbina.txt'));

        case {'chasca', 'qiasika'}
            cfg = localBaseConfig('Chasca', customArtifact_Chasca(), fullfile(projectRoot, 'data', 'Chasca', 'rotation_Chasca.txt'));

        case {'lauma'}
            cfg = localBaseConfig('Lauma', customArtifact_Lauma(), fullfile(projectRoot, 'data', 'Lauma', 'rotation_Lauma.txt'));

        case {'ineffa'}
            cfg = localBaseConfig('Ineffa', customArtifact_Ineffa(), fullfile(projectRoot, 'data', 'Ineffa', 'rotation_Ineffa.txt'));

        case {'linnea', 'linnia'}
            cfg = localBaseConfig('Linnea', customArtifact_Linnea(), fullfile(projectRoot, 'data', 'Linnea', 'rotation_Linnea.txt'));

        case {'nilou'}
            cfg = localBaseConfig('Nilou', customArtifact_Nilou(), fullfile(projectRoot, 'data', 'Nilou', 'rotation_Nilou.txt'));

        case {'nefer'}
            cfg = localBaseConfig('Nefer', customArtifact_Nefer(), fullfile(projectRoot, 'data', 'Nefer', 'rotation_Nefer.txt'));

        case {'flins'}
            cfg = localBaseConfig('Flins', customArtifact_Flins(), fullfile(projectRoot, 'data', 'Flins', 'rotation_Flins.txt'));

        case {'zibai'}
            cfg = localBaseConfig('Zibai', customArtifact_Zibai(), fullfile(projectRoot, 'data', 'Zibai', 'rotation_Zibai.txt'));

        case {'mualani'}
            cfg = localBaseConfig('Mualani', customArtifact_Mualani(), fullfile(projectRoot, 'data', 'Mualani', 'rotation_Mualani.txt'));

        case {'mavuika'}
            cfg = localBaseConfig('Mavuika', customArtifact_Mavuika(), fullfile(projectRoot, 'data', 'Mavuika', 'rotation_Mavuika.txt'));

        case {'citlali'}
            cfg = localBaseConfig('Citlali', customArtifact_Citlali(), fullfile(projectRoot, 'data', 'Citlali', 'rotation_Citlali.txt'));

        case {'xilonen'}
            cfg = localBaseConfig('Xilonen', customArtifact_Xilonen(), fullfile(projectRoot, 'data', 'Xilonen', 'rotation_Xilonen.txt'));

        case {'neuvillette'}
            cfg = localBaseConfig('Neuvillette', customArtifact_Neuvillette(), fullfile(projectRoot, 'data', 'Neuvillette', 'rotation_Neuvillette.txt'));

        case {'chevreuse'}
            cfg = localBaseConfig('Chevreuse', customArtifact_Chevreuse(), fullfile(projectRoot, 'data', 'Chevreuse', 'rotation_Chevreuse.txt'));

        case {'iansan'}
            cfg = localBaseConfig('Iansan', customArtifact_Iansan(), fullfile(projectRoot, 'data', 'Iansan', 'rotation_Iansan.txt'));

        case {'varesa'}
            cfg = localBaseConfig('Varesa', customArtifact_Varesa(), fullfile(projectRoot, 'data', 'Varesa', 'rotation_Varesa.txt'));

        case {'durin'}
            cfg = localBaseConfig('Durin', customArtifact_Durin(), fullfile(projectRoot, 'data', 'Durin', 'rotation_Durin.txt'));

        case {'nicole'}
            cfg = localBaseConfig('Nicole', customArtifact_Nicole(), fullfile(projectRoot, 'data', 'Nicole', 'rotation_Nicole.txt'));

        otherwise
            error('Unsupported character in unified entry: %s', name);
    end

    cfg = localApplyConfigOverrides(cfg, overrides);
    cfg.Build = materializeArtifactPieceModel(cfg.Name, cfg.Build, struct());
end

function cfg = localBaseConfig(displayName, build, rotationFile)
    build = materializeArtifactPieceModel(displayName, build, struct());
    cfg = struct( ...
        'Name', displayName, ...
        'DisplayName', string(displayName), ...
        'TalentLevel', 10, ...
        'Constellation', 0, ...
        'Build', build, ...
        'EnemyState', struct(), ...
        'RotationFile', rotationFile);
end

function cfg = localApplyConfigOverrides(cfg, overrides)
    if isempty(overrides)
        return;
    end

    if isfield(overrides, 'Build')
        cfg.Build = applyStructOverrides(cfg.Build, overrides.Build);
        overrides = rmfield(overrides, 'Build');
    end

    if isfield(overrides, 'Name')
        overrides = rmfield(overrides, 'Name');
    end

    cfg = applyStructOverrides(cfg, overrides);
end
