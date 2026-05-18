function resShred = getElementResShredValue(element, build, teamContext)
    % Return the effective resistance shred for the given damage element.
    if nargin < 2 || isempty(build)
        build = struct();
    end
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end

    resShred = getFieldOrDefault(build, 'ResShred', 0);
    switch lower(char(string(element)))
        case 'pyro'
            resShred = resShred + getFieldOrDefault(teamContext, 'PyroResShred', 0);
        case 'hydro'
            resShred = resShred + getFieldOrDefault(teamContext, 'HydroResShred', 0);
        case 'cryo'
            resShred = resShred + getFieldOrDefault(teamContext, 'CryoResShred', 0);
        case 'electro'
            resShred = resShred + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
        case 'anemo'
            resShred = resShred + getFieldOrDefault(teamContext, 'AnemoResShred', 0);
        case 'geo'
            resShred = resShred + getFieldOrDefault(teamContext, 'GeoResShred', 0);
        case 'dendro'
            resShred = resShred + getFieldOrDefault(teamContext, 'DendroResShred', 0);
        case 'physical'
            resShred = resShred + getFieldOrDefault(teamContext, 'PhysicalResShred', 0);
    end
end
