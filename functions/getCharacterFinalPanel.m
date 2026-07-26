function panel = getCharacterFinalPanel(characterName, build, teamContext)
% Return the pre-team final panel consumed by the DPS simulation.
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end
    compiled = compileArtifactSetBonuses(characterName, build, teamContext);
    base = localLoadBaseStats(characterName);
    panel = struct( ...
        'HP', base.BaseHP * (1 + getFieldOrDefault(compiled, 'HPBonus', 0)) + getFieldOrDefault(compiled, 'FlatHP', 0), ...
        'ATK', (base.BaseATK + getFieldOrDefault(compiled, 'WeaponATK', 0)) * (1 + getFieldOrDefault(compiled, 'AtkBonus', 0)) + getFieldOrDefault(compiled, 'FlatATK', 0), ...
        'DEF', base.BaseDEF * (1 + getFieldOrDefault(compiled, 'DEFBonus', 0)) + getFieldOrDefault(compiled, 'FlatDEF', 0), ...
        'EM', getFieldOrDefault(compiled, 'EM', 0), ...
        'ER', getFieldOrDefault(compiled, 'ER', 1), ...
        'CritRate', getFieldOrDefault(compiled, 'CritRate', 0), ...
        'CritDMG', getFieldOrDefault(compiled, 'CritDMG', 0), ...
        'ElementDMGBonus', localElementBonus(characterName, compiled), ...
        'Build', compiled);
end

function base = localLoadBaseStats(characterName)
    base = struct('BaseHP', 0, 'BaseATK', 0, 'BaseDEF', 0);
    root = fileparts(mfilename('fullpath'));
    files = dir(fullfile(root, '..', 'data', char(string(characterName)), 'characters_*.csv'));
    if isempty(files), return; end
    table = readtable(fullfile(files(1).folder, files(1).name), 'TextType', 'string');
    if isempty(table), return; end
    base.BaseHP = localCellNumber(table, 'BaseHP');
    base.BaseATK = localCellNumber(table, 'BaseATK');
    base.BaseDEF = localCellNumber(table, 'BaseDEF');
end

function value = localCellNumber(table, fieldName)
    value = 0;
    if ~ismember(fieldName, table.Properties.VariableNames), return; end
    raw = table.(fieldName)(1);
    if iscell(raw), raw = raw{1}; end
    if isstring(raw), raw = str2double(raw); end
    if isnumeric(raw) && isfinite(raw), value = double(raw); end
end

function value = localElementBonus(characterName, build)
    element = lower(char(string(getCharacterElement(characterName))));
    switch element
        case 'pyro', field = 'PyroDMGBonus';
        case 'hydro', field = 'HydroDMGBonus';
        case 'cryo', field = 'CryoDMGBonus';
        case 'electro', field = 'ElectroDMGBonus';
        case 'anemo', field = 'AnemoDMGBonus';
        case 'geo', field = 'GeoDMGBonus';
        case 'dendro', field = 'DendroDMGBonus';
        otherwise, field = 'PhysicalDMGBonus';
    end
    value = getFieldOrDefault(build, field, 0);
end
