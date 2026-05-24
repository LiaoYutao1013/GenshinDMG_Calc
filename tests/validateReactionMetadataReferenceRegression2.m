function validateReactionMetadataReferenceRegression2()
    initProjectPaths();

    referenceCases = {
        struct('Name', "Freminet", 'ExpectedActions', ["Frost", "BFrost", "Thorn"]), ...
        struct('Name', "Kaveh", 'ExpectedActions', ["Q", "Core", "E"]), ...
        struct('Name', "Alhaitham", 'ExpectedActions', ["E", "Mirror3", "QMirror"])
    };

    for caseIndex = 1:numel(referenceCases)
        caseSpec = referenceCases{caseIndex};
        audit = auditCharacterReactionMetadata(caseSpec.Name);
        rows = audit.Rows;
        fallbackRows = rows(rows.ApplyGaugeFallback | rows.ICDFallback, :);

        assert(~isempty(rows), ...
            sprintf('%s audit should produce at least one action row.', caseSpec.Name));
        assert(isempty(fallbackRows), ...
            sprintf('%s audit should resolve ApplyGauge and ICD metadata without fallback rows.', caseSpec.Name));

        actualActions = unique(string(rows.Action), 'stable');
        for actionIndex = 1:numel(caseSpec.ExpectedActions)
            expectedAction = caseSpec.ExpectedActions(actionIndex);
            assert(any(strcmp(actualActions, expectedAction)), ...
                sprintf('%s audit should include the %s action.', caseSpec.Name, expectedAction));
        end
    end

    disp('validateReactionMetadataReferenceRegression2 passed');
end
