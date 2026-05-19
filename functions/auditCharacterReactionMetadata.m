function audit = auditCharacterReactionMetadata(characterName, overrides, enemy)
    % Audit unified imported/generic simulator reaction metadata coverage.
    %
    % This helper intentionally uses the imported-character generic spec
    % builder so it can run across the whole roster without needing every
    % bespoke simulator to expose its internal action spec. The output is
    % therefore best used as a coverage scanner for:
    % - which actions still fall back to default ApplyGauge = 1U
    % - which actions still lack resolved ICD metadata
    % - which Lunaris attack entries were matched
    %
    % For handwritten high-precision simulators, this is a lower-bound
    % audit of metadata coverage, not a full truth audit of custom logic.
    initProjectPaths();
    if nargin < 2
        overrides = struct();
    end
    if nargin < 3 || isempty(enemy)
        enemy = struct( ...
            'Level', 90, ...
            'Res', 0.10, ...
            'DefReduct', 0, ...
            'ReactionMode', "Realistic", ...
            'AutoSupportAura', false);
    end

    cfg = getDefaultCharacterConfig(characterName, overrides);
    teamContext = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic"), enemy);

    simulatorName = "simulate" + string(cfg.Name) + "DPS";
    if exist(char(simulatorName), 'file') == 2
        try
            [~, ~, ~, ~, audit] = feval(char(simulatorName), ...
                cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, teamContext);
        catch
            [~, ~, ~, ~, audit] = simulateImportedCharacterDPS( ...
                cfg.Name, cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, teamContext);
        end
    else
        [~, ~, ~, ~, audit] = simulateImportedCharacterDPS( ...
            cfg.Name, cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, teamContext);
    end

    rows = table();
    if ~isempty(audit) && isfield(audit, 'Rows') && istable(audit.Rows)
        rows = audit.Rows;
    end

    if ~isempty(rows)
        rows.Character = repmat(string(cfg.Name), height(rows), 1);
        rows.Constellation = repmat(cfg.Constellation, height(rows), 1);
        rows.TalentLevel = repmat(cfg.TalentLevel, height(rows), 1);
        rows = movevars(rows, 'Character', 'Before', 1);
    end

    audit = struct( ...
        'Character', string(cfg.Name), ...
        'RotationFile', string(cfg.RotationFile), ...
        'Mode', "Realistic", ...
        'Rows', rows);
end
