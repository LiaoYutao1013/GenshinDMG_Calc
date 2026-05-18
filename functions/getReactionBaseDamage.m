function baseDamage = getReactionBaseDamage(reactionName, reactionLevel)
    % Return the level-scaled base damage used by standard reaction families.
    %
    % Notes:
    % 1. The current project assumes level-90 characters in almost every
    %    simulator, so level 90 uses the exact base scalar.
    % 2. Non-90 levels fall back to a smooth approximation to keep the
    %    interface extensible without blocking the current refactor.
    if nargin < 2 || isempty(reactionLevel)
        reactionLevel = 90;
    end

    reactionName = lower(char(string(reactionName)));
    baseScalar = localReactionLevelScalar(reactionLevel);

    switch reactionName
        case {'overload', 'overloaded'}
            coefficient = 4.0;
        case {'electrocharged', 'electro-charged'}
            coefficient = 2.4;
        case 'superconduct'
            coefficient = 1.0;
        case 'swirl'
            coefficient = 1.2;
        case 'shatter'
            coefficient = 3.0;
        case 'bloom'
            coefficient = 2.0;
        case {'burgeon', 'hyperbloom'}
            coefficient = 3.0;
        case 'burning'
            coefficient = 0.25;
        case 'aggravate'
            coefficient = 1.15;
        case 'spread'
            coefficient = 1.25;
        otherwise
            coefficient = 0;
    end

    baseDamage = baseScalar * coefficient;
end

function value = localReactionLevelScalar(level)
    level = double(level);
    if abs(level - 90) <= 1e-6
        value = 1446.853458;
        return;
    end

    % Smooth approximation used only when the caller explicitly requests a
    % non-90 level. The current simulator still defaults to level 90.
    value = 1446.853458 * (max(1, level) / 90) ^ 2;
end

