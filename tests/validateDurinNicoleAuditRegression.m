function validateDurinNicoleAuditRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false);

    cases = { ...
        struct('Name', "Durin", 'ExpectedActions', ["E", "Confirm", "Q", "WhiteTick"]), ...
        struct('Name', "Nicole", 'ExpectedActions', ["E", "Q", "Projection", "Unity"])};

    for i = 1:numel(cases)
        caseSpec = cases{i};
        audit = auditCharacterReactionMetadata(caseSpec.Name, struct(), enemy);
        rows = audit.Rows;

        assert(~isempty(rows), sprintf('%s audit should produce action rows.', caseSpec.Name));
        assert(~any(rows.ApplyGaugeFallback | rows.ICDFallback), ...
            sprintf('%s audit should not contain generic fallback rows.', caseSpec.Name));

        actualActions = unique(string(rows.Action), 'stable');
        for actionIndex = 1:numel(caseSpec.ExpectedActions)
            expectedAction = caseSpec.ExpectedActions(actionIndex);
            assert(any(strcmp(actualActions, expectedAction)), ...
                sprintf('%s audit should include the %s action.', caseSpec.Name, expectedAction));
        end
    end

    disp('validateDurinNicoleAuditRegression passed');
end
