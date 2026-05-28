function [multiplier, enemyState, reaction] = getAmplifyingReactionMultiplier( ...
        enemyState, triggerElement, em, teamContext, gaugeUnits, deltaTime, reactionBonus)
    % Resolve one elemental hit against the current enemy aura state and
    % return the amplifying multiplier for this hit.
    if nargin < 3 || isempty(em)
        em = 0;
    end
    if nargin < 4 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 5 || isempty(gaugeUnits)
        gaugeUnits = 1.0;
    end
    if nargin < 6 || isempty(deltaTime)
        deltaTime = 0;
    end
    if nargin < 7 || isempty(reactionBonus)
        reactionBonus = 0;
    end

    if isempty(enemyState)
        enemyState = createEnemyState(struct(), teamContext, triggerElement);
    end

    [enemyState, reaction] = applyElementalHitToEnemy( ...
        enemyState, triggerElement, gaugeUnits, teamContext, deltaTime);
    multiplier = 1.0;
    if reaction.IsAmplifying
        multiplier = reaction.AmplifyMultiplier;
    end
end
