function build = initializeEffectiveArtifactBuild(characterName, build, effectiveSubstatCount)
% Convert a legacy aggregate build to the effective-substat input model.
% Fixed values are captured once so later changes only replace artifact
% substats, never character ascension or weapon contributions.
    if nargin < 3 || isempty(effectiveSubstatCount)
        effectiveSubstatCount = getFieldOrDefault(build, 'ArtifactEffectiveSubstatCount', 30);
    end

    if ~isfield(build, 'ArtifactBase_AtkBonus')
        legacyBuild = build;
        legacyBuild = localRemoveEffectiveFields(legacyBuild);
        compiled = compileArtifactSetBonuses(characterName, legacyBuild, struct());
        for fieldName = localTrackedFields()
            fieldName = fieldName{1};
            build.(['ArtifactBase_' fieldName]) = getFieldOrDefault( ...
                compiled, ['ArtifactBaseline_' fieldName], 0);
        end
    end

    build.ArtifactEffectiveSubstatCount = localNormalizeCount(effectiveSubstatCount);
    build = optimizeEffectiveArtifactSubstats(characterName, build, struct());
end

function build = localRemoveEffectiveFields(build)
    names = fieldnames(build);
    remove = startsWith(names, 'ArtifactBase_') | strcmp(names, 'ArtifactEffectiveSubstatCount') ...
        | strcmp(names, 'ArtifactEffectiveSubstatAllocation') | strcmp(names, 'ArtifactEffectiveSubstatProfile');
    if any(remove)
        build = rmfield(build, names(remove));
    end
end

function count = localNormalizeCount(value)
    if isstring(value) || ischar(value)
        value = str2double(value);
    end
    count = double(value);
    if ~isscalar(count) || ~isfinite(count)
        count = 30;
    end
    count = max(0, min(45, round(count)));
end

function fields = localTrackedFields()
    fields = {'AtkBonus', 'FlatATK', 'HPBonus', 'FlatHP', 'DEFBonus', 'FlatDEF', ...
        'ER', 'EM', 'CritRate', 'CritDMG', 'PhysicalDMGBonus', ...
        'PyroDMGBonus', 'HydroDMGBonus', 'CryoDMGBonus', 'ElectroDMGBonus', ...
        'AnemoDMGBonus', 'GeoDMGBonus', 'DendroDMGBonus', 'LunarChargedBonus', ...
        'NormalDMGBonus', 'ChargeDMGBonus', 'ChargedDMGBonus', 'PlungeDMGBonus', ...
        'SkillDMGBonus', 'BurstDMGBonus', 'HealingBonus', 'ReactionDMGBonus', ...
        'ShieldBonus', 'ResShred'};
end
