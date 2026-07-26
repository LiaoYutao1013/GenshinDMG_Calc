function macro = getCharacterRotationMacro(characterName, role, archetypeInfo)
    % Canonical action packages used by team planning before token-level search.
    if nargin < 2 || isempty(role)
        role = "";
    end
    if nargin < 3 || isempty(archetypeInfo)
        archetypeInfo = struct(); %#ok<NASGU>
    end

    macro = struct( ...
        'Defined', false, ...
        'Tokens', {cell(0, 1)}, ...
        'Provides', strings(0, 1), ...
        'Requires', strings(0, 1), ...
        'SetupPriority', 50);
    name = lower(string(characterName));
    role = string(role);

    switch name
        case "skirk"
            if role == "Carry" || role == "Driver"
                macro.Defined = true;
                macro.Tokens = {'E'; 'ExQ'; 'N1'; 'N2'; 'N3'; 'N4'; 'N5'; ...
                    'N1'; 'N2'; 'N3'; 'N4'; 'N5'; 'Charge'};
                macro.Requires = ["DamageBonus"; "CryoSupport"];
                macro.SetupPriority = 100;
            end
        case "furina"
            if role ~= "Carry"
                macro.Defined = true;
                macro.Tokens = {'Q'; 'E'};
                macro.Provides = ["DamageBonus"; "HydroAura"];
                macro.SetupPriority = 10;
            end
        case "escoffier"
            if role ~= "Carry"
                macro.Defined = true;
                macro.Tokens = {'E'; 'Q'};
                macro.Provides = "CryoSupport";
                macro.SetupPriority = 20;
            end
        case "citlali"
            if role ~= "Carry"
                macro.Defined = true;
                macro.Tokens = {'E'; 'Q'};
                macro.Provides = ["CryoSupport"; "Shield"];
                macro.SetupPriority = 30;
            end
    end
end
